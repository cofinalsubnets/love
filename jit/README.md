# jit — the `(call ...)` trampoline and the `(forge ...)` loader

> **The floor.** This was a larger experiment; it has been pulled back to its
> substrate and its one finding. The native scalar/array/fold kernels and the
> `opjit` compiler hook are **gone** — the scalar hook was a measured net loss, the
> array kernels had no caller, and the one real win they revealed (reduction
> reassociation) now lives **baked in the C builtins** `asum`/`aprod`/`amax`/`amin`,
> multi-accumulator and portable to every target. What's left is the live surface:
> `call`/`call2`/`forge` (nifs in `love.c`) and `jit/probe.l` (the kernel finding).
> The lesson, in one line: *a JIT wins only when it owns the loop, and the production
> form of a fixed-code win is baked C unlocked by a sound algebraic law — so the
> experiment's keeper is the finding, not the scaffold.* (`git log` for the arc.)
> The surface that remains is now **fault-safe** on the host — a bad forged body is
> a catchable love condition, not a crash (see *The fault barrier*, below).

A nif that jumps into machine code stored in a `buf` and runs it natively, and a
loader that puts the bytes somewhere they can run on either target.

```
(call b x)        ; jump into buf b's bytes, arg x, fixnum result
(call2 b x y)     ; ... two args (SysV %rdi/%rsi; AArch64 x0/x1)
(forge src)       ; an EXECUTABLE buf holding a copy of src's bytes
```

`call` jumps into the bytes of buf `b`, passing `x` as the sole argument and
wrapping the returned machine word as a fixnum. The calling convention is the
platform C ABI — SysV AMD64 puts the argument in `%rdi` and takes the result in
`%rax`; AArch64 uses `x0` for both. The bytes inside `b` are the caller's
responsibility, but an ill-formed body is no longer fatal on the host: the
**fault barrier** (below) catches the hardware fault and `call` returns `0` — the
same value a non-buf argument gives. A non-buf argument runs nothing and returns
`0`.

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

## The fault barrier — a bad body is survivable (host)

Running forged bytes is the one place love can be handed code that faults the CPU.
That used to be a hard crash; it no longer is. On the host a signal barrier
(`SIGSEGV`/`SIGILL`/`SIGBUS`/`SIGFPE` + `sigsetjmp`) turns a hardware fault into an
ordinary love condition:

- **`call`/`call2`** wrap the native call in `call_run` (`love.c`, by `lvm_call`):
  a fault in the body is caught and `call` returns `0` — the non-buf value — so a
  bad body is survivable like any other error, never a core dump. The native body
  never touches love state, so this recovery is unconditional.
- **`g_eval`** carries the same barrier over the whole VM run, so *any* in-eval
  hardware fault becomes a catchable `(scare 'fault <signal>)` delivered through
  `help` — transparent, up through object-array ops, `lamb`, and `(ev …)`. In file
  mode that is a clean terminal scare instead of a core dump; interactively the
  fault recovers **per task** — the faulting ("burnt") task is unlinked from the
  scheduler ring and a live peer resumes, so a faulting repl line just fails and the
  session carries on (`^C` and cooperative scheduling intact).

Host-only: the freestanding kernel has no signal layer (its fault vectors are a
separate hookup), so there `call` is still the raw trampoline. The one residual
unrecoverable corner is a fault *mid-GC or mid-ring-mutation*, where the heap itself
is inconsistent. See `call_run` / `g_eval` / `g_eval_fault_raise` in `love.c`, and
the compile-gated `__fault` harness (`-DG_FAULT_TEST`).

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
`mprotect`: a love JIT on the kernel is just love emitting bytes into a `buf`
and calling it.

The **host** is the opposite: Linux maps the malloc heap no-execute, so a raw
`(call <heap buf> ...)` SIGSEGVs on the jump. `(forge ...)` lifts exactly that
limitation (the W^X arena above), so `(call (forge bytes) x)` runs real bytes
natively on an x86_64 host too, no qemu. The corpus test (`test/jit.l`) stays
architecture-neutral — x86_64 opcodes would crash an aarch64 or wasm host — so
it covers the guards (`non-buf → 0`, `forge` round-trips bytes into a buf) and
not live execution; the kernel finding lives in the standalone `jit/probe.l`.

## What the experiment found, and where it went

The full version generated x86_64/SSE in love and ran it via `(call (forge …) x)`:
a scalar `(\ p <arith>)` kernel, an automatic `ev`/`opfix` hook to apply it
transparently, and array kernels (`amap`/`areduce`/…) over `z`/`r`/`c` arrays. The
transparency was made exact (`=`-preserving via `respec`, de-Bruijn `show` intact).
Then the benchmark settled it:

| 5M ops | JIT | interpreter | |
|---|---|---|---|
| `x*x+1` (scalar hook) | ~290 ms | ~230 ms | JIT **~25% slower** |
| `sum x*x` (array fold) | ~10 ms | ~450 ms | JIT **~45× faster** |

A native *function* called from the interpreted loop pays a call-boundary tax
(`putfix` marshal, the `call` nif, the result decode) heavier than interpreting a
small arithmetic body — there's no case where the scalar hook wins. **The JIT only
pays off when it owns the loop.** And the loops worth owning are the reductions —
whose speedup, once reassociation was recognized as sound (`*`/`+` are commutative
monoids), is just a multi-accumulator C loop the compiler schedules. So that win was
**baked into the builtins** (`asum`/`aprod`/`amax`/`amin`, ~3× and portable), and the
JIT scaffold — kernels, folds, the `opjit` hook, ~1200 lines — was retracted to the
substrate above.

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

- **Always `forge` before you `call` on the host.** A bare `(call <heap buf> ...)`
  of real code faults on the NX heap — now *caught* by the fault barrier (`call`
  returns `0`) rather than crashing, but it still won't run. `forge` is the only
  host-safe way to obtain executable bytes; the arena it returns is W^X and freed by
  a finalizer.
- **AArch64 cache.** `lvm_call` omits the I-cache flush AArch64 needs after `forge`
  writes code (`__builtin___clear_cache(base, base+len)` before the first `call`).
  Correct on x86_64 only until that is added — and on AArch64 the flush belongs in
  `forge` (where the bytes are written), not `call`.
- **The contract across `call`.** The argument arrives as its *raw tagged* love word
  (`putfix A`) and the result is re-tagged (`putfix r`), so a codegen must untag at
  the boundary. Keep what crosses `call` to unboxed machine words: no allocation, no
  heap pointers held inside — that is what keeps the trampoline GC-safe.
- **No verification.** This is the raw trampoline plus a safe loader — no semantics,
  no proof that the bytes mean the love they claim to. A *verified* JIT is a separate,
  much larger effort (and the place love's in-tree prover could eventually earn its
  keep).
