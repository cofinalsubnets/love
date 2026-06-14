# jit — the `(call ...)` trampoline and the `(forge ...)` loader

The floor under a love JIT: a nif that jumps into machine code stored in a
`buf` and runs it natively, and a loader that puts the bytes somewhere they can
run on either target.

```
(call b x)        ; jump into buf b's bytes, arg x, fixnum result
(forge src)       ; an EXECUTABLE buf holding a copy of src's bytes
```

`call` jumps into the bytes of buf `b`, passing `x` as the sole argument and
wrapping the returned machine word as a fixnum. The calling convention is the
platform C ABI — SysV AMD64 puts the argument in `%rdi` and takes the result in
`%rax`; AArch64 uses `x0` for both. The bytes inside `b` are entirely the
caller's responsibility: an ill-formed body is a hard crash, by design. A
non-buf argument runs nothing and returns nothing (`0`).

`forge` is how you get a `call`-able buf that works on **both** targets. The
portable idiom is `(call (forge bytes) x)`:

- **Host** — the Linux malloc heap is mapped no-execute, so a raw
  `(call <heap buf> ...)` SIGSEGVs on the jump. `forge` copies the bytes into a
  **W^X code arena** instead: `mmap` a page-rounded region read/write, write a
  `g_str` header + the bytes, `mprotect` it to read+execute, and never write it
  again. Writable *xor* executable is honored throughout, so hardened systems
  that forbid RWX still run it. The arena lives outside the GC pool — the
  returned buf is an ordinary buf whose backing-string pointer the collector
  leaves untouched (`gcp`'s out-of-pool short-circuit) — and a finalizer
  `munmap`s the region when the buf is collected (mirrors `io_close`).
- **Kernel** — the HHDM is already executable (the finding below), so `forge`
  is just a heap-buf copy; the bytes run in place.

`src` may be a string or a buf; a non-byte value or an empty one forges to `0`.

Both nifs live in `love.c` — search `lvm_call` and `lvm_forge`; each is three
lines of wiring (a forward-decl in the `lvm_t` block, the body, one nif-table
entry). The host arena helpers (`code_maplen`, `code_unmap`) sit just above
`lvm_forge` under `#if __STDC_HOSTED__`, so the freestanding kernel never sees
`mmap`.

## The finding: the kernel substrate is *just* this trampoline

`jit/probe.l` builds a buf holding six AMD64 bytes —

```
B8 2A 00 00 00   mov eax, 42      ; imm32 little-endian
C3               ret
```

— then `(call b 0)` and prints the result. Run on the **kernel** target under
qemu it returns the immediate exactly (verified at 42 and at 12345). So Limine
maps the HHDM — which backs the kernel heap, hence every `buf` — **without the
NX bit**: kernel data memory is already executable. No page-table work, no
`mprotect`: a love JIT is just love emitting bytes into a `buf` and calling it.

The **host** is the opposite: Linux maps the malloc heap no-execute, so a raw
`(call <heap buf> ...)` SIGSEGVs on the jump. `(forge ...)` lifts exactly that
limitation (the W^X arena above), so executing real bytes is no longer
kernel-only — `out/host/love jit/forge.l` runs the same immediates plus an
argument-echo natively on an x86_64 host, no qemu. The corpus test
(`test/jit.l`) still stays architecture-neutral — x86_64 opcodes would crash an
aarch64 or wasm host — so it covers the guards and that `forge` round-trips
bytes into a buf; the real execution lives in the two standalone files
(`jit/forge.l` on the host, `jit/probe.l` on the kernel).

## The first kernel — `jit/kernel.l`

A real (small) JIT, codegen and all written in love: a fixnum `(\ x <arith>)`
over `+ - * // % < <= > >= =` compiled to x86_64 and run via `(call (forge bytes)
x)`. The whole backend is love emitting bytes into a buf — a recognizer
(`arithp`), a recursive emitter (`x` re-derived from `%rdi` each use; binops via
the machine stack), and a driver that returns a native closure or, on any
non-match, the ordinary `(ev lam)` interpreter compile. `//`/`%` use `idiv`
(truncate-toward-zero quotient, dividend-signed remainder — exactly love's
convention); comparisons use `setcc`+`movzx` → `0`/`1`.

The ABI quirk and its fix: `(call ...)` passes the arg as its **raw tagged** word
(`putfix X = 2X+1`) and re-tags the result, so the kernel untags on entry
(`sar`, signed) and computes on the raw integer. love fixnums **auto-widen to
bignum** but native int64 **wraps**, so the kernel carries an **overflow guard**:
`seto r9b ; or r8b,r9b` after every op makes `r8` a *branchless sticky* OF flag
(no forward jumps to backpatch), and the epilogue folds in a fixnum-range check.
There's no error channel through `call`'s fixnum return, so the result encodes one
bit — **`2R` (even) on success, `1` (odd) on bail** — and the love wrapper reads
the low bit: odd → fall back to the interpreter (exact, incl. bignums). This
costs one bit of range (native covers `R ∈ [-2^61, 2^61)`; past that it bails to
the VM). **Division by zero bails the same way** — love's `(// 5 0)` is the float
`ieee-inf` and `(% 5 0)` is `0.0`, which a native int kernel can't produce, so
`//`/`%` mark the sticky flag on a zero divisor (and force a safe divisor to dodge
`#DE`) and let the interpreter return the float. The kernel **never returns a
wrong answer** — verified against the interpreter on success *and* overflow/
div-by-zero cases:

```sh
out/host/love jit/kernel.l        # x86_64 host: every line "==", then ALL PASS
```

This is roadmap **step 2**. The kernel takes a single-param `(\ p <arith>)` with
any param name (`p` is re-derived from `%rdi` on each use, so its spelling is
irrelevant to the codegen).

## The automatic hook — `jit/auto.l`

Makes a qualifying `(\ p <arith>)` go native with **no explicit `(jit …)` call** —
defining a lambda the normal way, or passing one to a higher-order function, just
goes fast. Load it after the kernel:

```sh
out/host/love -l jit/kernel.l jit/auto.l   # kernel ALL PASS, then the hook demo, ALL PASS
```

The seam is the **global `ev`**. The repl and the cli/`g_evals_` loader compile
each form via the late-bound `(ev 'ev form)` — the symbol `ev` is evaluated fresh
every time — so redefining the global `ev` is picked up immediately. The new `ev`
is `(\ form (base-ev (jit-walk form)))`: a source→source pass that rewrites every
qualifying `(\ p <arith>)` into `(\ <forged native closure>)` (a quote of the
closure value), then hands the result to the real compiler. The forge happens
once, at compile time, per lambda expression. `jit-walk` is **conservative about
the reader's code/data split** — it leaves quote (`(\ d)`, one operand),
quasiquote (`(qq …)`), and macro-defs (`(:: …)`) verbatim, so it can never corrupt
data, while still walking application/`:`/`?` subforms and lambda bodies (so a
`(\ p arith)` in argument position — the HOF case — is caught). Verified: ordinary
code and quoted data pass through untouched.

**Why this is a runtime redefinition, not a compiler change.** The production hook
belongs in `opfix` (which already has the exact code/data traversal), guarded by
`born` (a forged buf is a host `mmap` address — it can **never** be baked into the
egg) and target arch (x86_64 only; the VM stays the portable fallback, since wasm
can't execute forged bytes and each arch needs its own codegen). That's a compiler
change needing a full re-gate; redefining `ev` at runtime demonstrates the exact
behavior with **zero risk to the bootstrap**. Known gaps (safe — they only miss
coverage, never miscompile): lambdas inside quasiquote-unquotes or unexpanded
macro args aren't reached. Standalone x86_64, kept out of the gate corpus.

## Reproducing the probe (x86_64 + qemu)

```sh
make host                                  # builds love0 + the bake tools
cp jit/probe.l out/lib/ktests.l            # make the probe the whole K_TEST corpus
out/host/love0 -l love/prelude.l tools/lcatv.l out/lib/ktests.l > out/lib/ktests.h
touch out/lib/ktests.l out/lib/ktests.h
make -s K_TEST=1 out/free/love-x86_64-test.iso
qemu-system-x86_64 -m 256M -M q35 -serial stdio -display none -no-reboot \
  -drive if=pflash,unit=0,format=raw,file=out/dl/edk2-ovmf/ovmf-code-x86_64.fd,readonly=on \
  -cdrom out/free/love-x86_64-test.iso \
  -device isa-debug-exit,iobase=0xf4,iosize=0x04
# expect:  JIT-PROBE-START / JIT-PROBE-RESULT=42 / JIT-PROBE-END
# then restore the real corpus:  make out/lib/ktests.h   (or rm it; the next build re-bakes)
```

`probe.l` ends in `(exit 0)`, which the kernel routes to qemu's isa-debug-exit.

## Caveats / TODO

- **Always `forge` before you `call` on the host.** A bare `(call <heap buf>
  ...)` of real code still faults — the NX heap is unchanged. `forge` is the
  only host-safe way to obtain executable bytes; the arena it returns is W^X
  and freed by a finalizer, so no `mprotect` juggling or leaks on the caller.
- **AArch64 cache.** `lvm_call` omits the I-cache flush AArch64 needs after
  `forge` writes code (`__builtin___clear_cache(base, base+len)` before the
  first `call`). Correct on x86_64 only until that is added — and on AArch64 the
  flush belongs in `forge` (where the bytes are written), not `call`.
- **The contract across `call`.** The argument arrives as its *raw tagged* love
  word (`putfix A`) and the result is re-tagged (`putfix r`), so an identity
  body double-tags; `jit/forge.l`'s third demo shifts right by one to cancel the
  incoming tag and echo the love argument cleanly. A real codegen untags at the
  boundary. Keep what crosses `call` to unboxed machine words: no allocation, no
  heap pointers held inside — that is what keeps the JIT GC-safe.
- **No verification.** This is the raw trampoline plus a safe loader — no
  semantics, no proof that the bytes mean the love they claim to. A *verified*
  JIT is a separate, much larger effort (and the place love's in-tree prover
  could eventually earn its keep).
