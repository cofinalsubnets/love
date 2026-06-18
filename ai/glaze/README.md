# jit — the codegen backend (`ev` but faster), and the `(eat …)`/`(toast …)` trampoline

> **What this is.** The aim is **`ev` but faster**: a closure compiled to native
> machine code that is *indistinguishable from the interpreted closure* — applied by
> juxtaposition (`(f x)`, no verb), `=`/`show`-identical to its source, and **deopting
> to the interpreter on overflow** so it is never wrong, only faster. The bricks:
>
> - **`nat`** (nif, `ai.c`) — the install seam: emitted bytes → a TRANSPARENT
>   applicable native closure. Cell `[code, src, code, interp, lvm_ret, 0]`, value at
>   the 3rd word, so `value[-1]`=src (`fn_src`/printer/`salpha` → `=`/`show` see the
>   source) and `value[1]`=interp (the deopt fallback). W^X arena with a finalizer.
> - **`ai/glaze/emit.l`** — a love-level **x86-64 emitter**: compiles `(\ x E)` arithmetic
>   and a counted-sum loop `(\ n Σ_{i<n} body)` to native, with a `jno`+inline-deopt
>   guard on every `+`/`-`/`*` and on `putfix` (its `add rax,rax` overflow flag is
>   exactly the 62-bit fixnum boundary). x86-64 only; load with `-l ai/glaze/emit.l`.
>
> This realizes the law the earlier experiment found — *a glaze wins only when it owns
> the loop* — concretely: the counted-loop emitter owns the iteration end to end
> (~tens-of-× on in-range arithmetic loops; deopts out of range). It is the
> **generalization of the baked array kernels** (`asum`/`aprod`/…) to arbitrary
> scalar/control-flow loops that have no array to bake. **WIP** toward the *auto
> hook*: `ev` installing native for hot regions transparently, after which `nat` goes
> internal (mopped like `boxfix`/`wev`) and there is no user-facing verb at all.
>
> **The leaf substrate** below — `eat` (the curried `eat1`/`eat2`)/`toast` (nifs) + `ai/glaze/probe.l` (the
> kernel finding) — predates `nat`: a *leaf* trampoline (word→word, an opaque handle
> you `eat`) the convention-following `nat` supersedes. It stays as the fault-safe
> machine-code substrate and the kernel-RWX probe. The earlier scalar/array/fold
> kernels and the `opjit` hook are **gone**; their one fixed-code win (reduction
> reassociation) lives **baked in the C builtins**. (`git log` for the arc.)

A nif that jumps into native machine code and runs it, and a loader that bakes the
bytes into an opaque, executable handle — a **toast** — that runs on either target.

```
(eat 1 t x)       ; jump into toast t's code, one arg x, fixnum result
(eat 2 t x y)     ; ... two args (SysV %rdi/%rsi; AArch64 x0/x1)
(toast src)       ; bake src's bytes into an opaque, executable TOAST
```

`eat` jumps into the code of toast `t`, passing `x` as the sole argument (arity `1`
first) and wrapping the returned machine word as a fixnum. The calling convention is
the platform C ABI — SysV AMD64 puts the argument in `%rdi` and takes the result in
`%rax`; AArch64 uses `x0` for both. Only a **toast** is eatable — a plain `buf` (or
any non-toast) runs nothing and returns `0`. The code inside `t` is the caller's
responsibility, but an ill-formed body is no longer fatal on the host: the **fault
barrier** (below) catches the hardware fault and `eat` returns `0`.

`toast` bakes bytes into a callable handle that works on **both** targets; the idiom
is `(eat 1 (toast bytes) x)`. A toast is **opaque**: it answers `hotp` like any hot
but it is *not* a `buf` — its code can't be `peep`/`pin`/`blit`/`tally`'d as data (no
length, no byte access); only `eat` runs it. That keeps the executable region from
masquerading as a writable byte buffer.

- **Host** — the Linux malloc heap is mapped no-execute, so raw heap bytes can't be
  run. `toast` copies them into a **W^X code arena**: `mmap` a page-rounded region
  read/write, write a `g_str` header + the bytes, `mprotect` it to read+execute, and
  never write it again. Writable *xor* executable is honored throughout, so hardened
  systems that forbid RWX still run it. The arena lives outside the GC pool — the
  toast's backing-string pointer the collector leaves untouched (`gcp`'s out-of-pool
  short-circuit) — and a finalizer `munmap`s the region when the toast is collected
  (mirrors `io_close`).
- **Kernel** — the HHDM is already executable (the finding below), so `toast`
  is just a heap copy; the bytes run in place.

`src` may be a string or a buf; a non-byte value or an empty one toasts to `0`.

## The fault barrier — a bad body is survivable (host)

Running a toast's bytes is the one place love can be handed code that faults the CPU.
That used to be a hard crash; it no longer is. On the host a signal barrier
(`SIGSEGV`/`SIGILL`/`SIGBUS`/`SIGFPE` + `sigsetjmp`) turns a hardware fault into an
ordinary love condition:

- **`eat1`/`eat2`** wrap the native call in `eat_run` (`ai.c`, by `lvm_eat1`):
  a fault in the body is caught and `eat` returns `0` — the non-buf value — so a
  bad body is survivable like any other error, never a core dump. The native body
  never touches love state, so this recovery is unconditional.
- **`g_eval`** carries the same barrier over the whole VM run, so *any* in-eval
  hardware fault becomes a catchable `(scare 'fault <signal>)` delivered through
  `help` — transparent, up through object-array ops, `spin`, and `(ev …)`. In file
  mode that is a clean terminal scare instead of a core dump; interactively the
  fault recovers **per task** — the faulting ("burnt") task is unlinked from the
  scheduler ring and a live peer resumes, so a faulting repl line just fails and the
  session carries on (`^C` and cooperative scheduling intact).

Host-only: the freestanding kernel has no signal layer (its fault vectors are a
separate hookup), so there `eat` is still the raw trampoline. The one residual
unrecoverable corner is a fault *mid-GC or mid-ring-mutation*, where the heap itself
is inconsistent. See `call_run` / `g_eval` / `g_eval_fault_raise` in `ai.c`, and
the compile-gated `__fault` harness (`-DG_FAULT_TEST`).

Both nifs live in `ai.c` — search `lvm_call` and `lvm_toast`; each is a few
lines of wiring (a forward-decl in the `lvm_t` block, the body, one nif-table
entry; plus `toastp` and the `lvm_toasted` tag-ap). The host arena helpers
(`code_maplen`, `code_unmap`) sit just above `lvm_toast` under `#if __STDC_HOSTED__`,
so the freestanding kernel never sees `mmap`.

## The finding: the kernel substrate is *just* this trampoline

`ai/glaze/probe.l` builds a buf holding six AMD64 bytes —

```
B8 2A 00 00 00   mov eax, 42      ; imm32 little-endian
C3               ret
```

— then `(eat 1 (toast b) 0)` and prints the result. Run on the **kernel** target
under qemu it returns the immediate exactly (verified at 42 and at 12345). So Limine
maps the HHDM — which backs the kernel heap, hence every toast's copy — **without the
NX bit**: kernel data memory is already executable. No page-table work, no
`mprotect`: a love glaze on the kernel is just love emitting bytes and calling a toast
of them.

The **host** is the opposite: Linux maps the malloc heap no-execute, so raw heap
bytes can't be run. `toast` lifts exactly that limitation (the W^X arena above), so
`(eat 1 (toast bytes) x)` runs real bytes natively on an x86_64 host too, no qemu. The
corpus test (`test/glaze.l`) stays architecture-neutral — x86_64 opcodes would crash an
aarch64 or wasm host — so it covers the guards (non-callable → `0`) and the toast's
opacity (`hotp` but no `peep`/`tally`), not live execution; the kernel finding lives
in the standalone `ai/glaze/probe.l`.

## What the experiment found, and where it went

The full version generated x86_64/SSE in love and ran it via `(eat 1 (toast …) x)`:
a scalar `(\ p <arith>)` kernel, an automatic `ev`/`opfix` hook to apply it
transparently, and array kernels (`amap`/`areduce`/…) over `z`/`r`/`c` arrays. The
transparency was made exact (`=`-preserving via `respec`, de-Bruijn `show` intact).
Then the benchmark settled it:

| 5M ops | glaze | interpreter | |
|---|---|---|---|
| `x*x+1` (scalar hook) | ~290 ms | ~230 ms | glaze **~25% slower** |
| `sum x*x` (array fold) | ~10 ms | ~450 ms | glaze **~45× faster** |

A native *function* called from the interpreted loop pays a call-boundary tax
(`putfix` marshal, the `eat` nif, the result decode) heavier than interpreting a
small arithmetic body — there's no case where the scalar hook wins. **The glaze only
pays off when it owns the loop.** And the loops worth owning are the reductions —
whose speedup, once reassociation was recognized as sound (`*`/`+` are commutative
monoids), is just a multi-accumulator C loop the compiler schedules. So that win was
**baked into the builtins** (`asum`/`aprod`/`amax`/`amin`, ~3× and portable), and the
glaze scaffold — kernels, folds, the `opjit` hook, ~1200 lines — was retracted to the
substrate above.

## Reproducing the probe (x86_64 + qemu)

```sh
make host                                  # builds ai0 + the bake tools
cp ai/glaze/probe.l out/lib/ktests.l            # make the probe the whole K_TEST corpus
out/host/ai0 -l ai/prel.l tools/lcatv.l out/lib/ktests.l > out/lib/ktests.h
touch out/lib/ktests.l out/lib/ktests.h
make -s K_TEST=1 out/free/love-x86_64-test.iso
qemu-system-x86_64 -m 256M -M q35 -serial stdio -display none -no-reboot \
  -drive if=pflash,unit=0,format=raw,file=out/dl/edk2-ovmf/ovmf-code-x86_64.fd,readonly=on \
  -cdrom out/free/love-x86_64-test.iso \
  -device isa-debug-exit,iobase=0xf4,iosize=0x04
# expect:  glaze-PROBE-START / glaze-PROBE-RESULT=42 / glaze-PROBE-END
# then restore the real corpus:  make out/lib/ktests.h   (or rm it; the next build re-bakes)
```

`probe.l` ends in `(exit 0)`, which the kernel routes to qemu's isa-debug-exit.

## Caveats / TODO

- **Only a toast is callable.** `call` rejects a plain `buf` (→ `0`); you must
  `toast` the bytes first. On the host that is also the only way to get executable
  memory (the heap is NX); the W^X arena the toast wraps is freed by a finalizer.
- **AArch64 cache.** `lvm_call` omits the I-cache flush AArch64 needs after `toast`
  writes code (`__builtin___clear_cache(base, base+len)` before the first `call`).
  Correct on x86_64 only until that is added — and on AArch64 the flush belongs in
  `toast` (where the bytes are written), not `call`.
- **The contract across `call`.** The argument arrives as its *raw tagged* love word
  (`putfix A`) and the result is re-tagged (`putfix r`), so a codegen must untag at
  the boundary. Keep what crosses `call` to unboxed machine words: no allocation, no
  heap pointers held inside — that is what keeps the trampoline GC-safe.
- **No verification.** This is the raw trampoline plus a safe loader — no semantics,
  no proof that the bytes mean the love they claim to. A *verified* glaze is a separate,
  much larger effort (and the place love's in-tree prover could eventually earn its
  keep).
