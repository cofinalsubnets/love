# jit — the `(call ...)` trampoline and the `(forge ...)` loader

> **Status (retracted to the floor).** The JIT was an experiment; it's been pulled
> back to its substrate + its one finding. The native array/scalar kernels, folds,
> and the `opjit` opfix hook are **gone** — they were a measured net loss (scalar)
> or unused (kernels), and the one real win they revealed, **reduction
> reassociation, now lives baked in the C builtins** `asum`/`aprod`/`amax`/`amin`
> (multi-accumulator, portable to all targets — `git log` for the arc). What remains
> is the live surface below: `call`/`call2`/`forge` (nifs) and `probe.l` (the kernel
> finding). Sections past the substrate describe the retracted experiment, kept as a
> record. The lesson: *a JIT wins only when it owns the loop, and the production form
> of a fixed-code win is baked C unlocked by a sound algebraic law.*

The floor under a love JIT: a nif that jumps into machine code stored in a
`buf` and runs it natively, and a loader that puts the bytes somewhere they can
run on either target.

```
(call b x)        ; jump into buf b's bytes, arg x, fixnum result
(call2 b x y)     ; ... two args (SysV %rdi/%rsi; AArch64 x0/x1)
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

This is roadmap **step 2**. The kernel takes a **1- or 2-param** `(\ p <arith>)` /
`(\ p q <arith>)` with any param names — the params bind to the SysV argument
registers (1st→`%rdi`, 2nd→`%rsi`), each re-derived from its register on use, so
the spellings are irrelevant to the codegen. One param uses `call`, two use
`call2`; the overflow/bail protocol is identical, and the wrapper is curried so
`((f a) b)` works. `call2` is one more C nif (arity 3), the `lvm_call` pattern.

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
qualifying `(\ p <arith>)` / `(\ p q <arith>)` into `(\ <forged native closure>)`
(a quote of the closure value), then hands the result to the real compiler. The forge happens
once, at compile time, per lambda expression. `jit-walk` is **conservative about
the reader's code/data split** — it leaves quote (`(\ d)`, one operand),
quasiquote (`(qq …)`), and macro-defs (`(:: …)`) verbatim, so it can never corrupt
data, while still walking application/`:`/`?` subforms and lambda bodies (so a
`(\ p arith)` in argument position — the HOF case — is caught). Verified: ordinary
code and quoted data pass through untouched.

`auto.l` redefines `ev`, so it only reaches forms `ev` compiles directly. The
production version lives one level deeper, in the compiler itself:

## The production hook — `opfix` + `jit/opjit.l`

`opfix` (the operator-factoring pass both compilers run, `love/prelude.l`) now
ends with one extra step: after factoring, it applies `book['opjit]` if installed.

```lisp
(: (opfix x) (: r (op-core x) h (peep book 'opjit 0) (? (lamp h) (h r) r)))
```

This is **dormant in the shipped image** — `book['opjit]` is `0`, so `opfix` is
identical to the old pass and the bootstrap/gate are byte-for-byte unaffected.
`jit/opjit.l` is the x86_64 installer: it `(: opjit jit-walk)`s, and because a
top-level def lands in the `book` tablet (via `lvm_defglob`) — the same tablet
`opfix` captured at bake — `opfix`'s `(peep book 'opjit 0)` reads it, **even
though the global name `book` was pulled at birth**. From then on every form
compiled through `c0` *and* the self-hosted `wev` gets its qualifying lambdas
turned native — no `ev` redefinition, the compiler does it.

```sh
out/host/love -l jit/kernel.l jit/opjit.l   # 5 lambdas jitted via the hook, ALL PASS
```

Two subtleties this surfaced:
- **Re-entry.** `jit`'s VM fallback is `(ev lam)`, which now re-enters
  `opfix → opjit → jit-walk → jit → (ev lam) …` forever. A one-bit guard
  (`jguard`) makes `jit-walk` leave forms verbatim while inside a `jit`, so the
  fallback compiles the plain VM closure.
- **The `(f)==f` wrapper.** `opjit` runs *after* factoring, so it sees infix arith
  in prefix form (`(\ x (x * x))` → `(\ x ((* x x)))`) — and `op-core` wraps a
  factored expression as `((…))` (the empty-application identity). `arithp`/`emit`
  peel that single-element wrapper, so **infix arith inside lambdas jits too**.

## Why the always-on scalar hook was reverted (the benchmark)

An always-on self-install was built (`main.c`, `#ifdef __x86_64__`, ran
`jit/install.l` after the egg) and validated — the whole corpus passed through
opjit, `=` preserved, `make valg` clean. **Then a benchmark killed it.**

| 5M ops | JIT | interpreter | |
|---|---|---|---|
| `x*x+1` | ~290 ms | ~230 ms | JIT **~25% slower** |
| deg-4 poly | ~745 ms | ~660 ms | JIT **~12% slower** |
| `sum x*x` (`areduce`) | ~10 ms | ~450 ms | JIT **~45× faster** |

The scalar hook makes a native *function* still **called from the interpreted
loop**, and the call boundary — `putfix` to marshal the arg, the `call` nif, the
`(? (& v 1) (vm a) (// v 2))` decode — costs more than interpreting a 3–10-op
arithmetic body. The native arithmetic is nanoseconds; the wrapper around it
isn't. There's no case where it wins (an opjit'd closure is only ever called
*from* the interpreter), so it's a pure ~15–25% pessimization plus a compile-time
forge cost. **The JIT only pays off when it owns the loop** — the array kernels
run ~45× because `areduce`/`amap` cross the boundary once and stay native across
every iteration.

So the self-install was **reverted**: `opjit` stays dormant (`book['opjit] = 0`),
`jit/install.l` is an *opt-in* loader (`out/host/love -l jit/install.l …`), and
the shipping value is the explicit array kernels. The transparency machinery
below still holds (it's why the opt-in hook is correct), but the lesson is that a
transparent scalar JIT across the interpreter boundary isn't worth its tax.

Making the hook transparent took two fixes beyond re-entry and the `(f)==f`
wrapper:
- **`=` preservation (`respec`).** `eqv` is `fn_src`-based, so a native closure
  would break closure equality and the `1=(\ x x)` / `0=(\ _ 1)` bridges. `jit`
  builds the wrapper with the forged buf + VM fallback as *quoted constants* (no
  captures → not `fn_partialp`), then `(respec w lam)` overrides its stashed
  `\`-expr with the **original** source. Now a jitted closure `=` the interpreted
  one exactly, while running native.
- **Never rewrite a lambda body.** `jit-walk` only rewrites a *directly* qualifying
  lambda; any other `\`-form is left **entirely** (it does not recurse into the
  body). Rewriting a body would change the *enclosing* lambda's stashed `\`-expr,
  breaking its `show` (de Bruijn, e.g. `(\ x (\ x x))` → `(\ d0 (\ d1 d1))`) and
  its `=`. Lambdas in `:`/application bodies are still reached (those forms are
  walked); only lambdas literally nested in another lambda's body are skipped.

Known gaps (safe — only missed coverage, never miscompilation): lambdas literally
nested in another lambda's body, and lambdas inside quasiquote-unquotes or
unexpanded macro args. The kernel/wasm frontends don't self-install (host-only for
now); `jit/opjit.l` remains the explicit runtime installer (same logic).

## Array kernels — `amap` + `jit/array.l`

Roadmap **step 4**, and where a JIT pays the most: a packed `z`-array is already an
unboxed `int64` C buffer, so an elementwise `(\ x <arith>)` becomes pure register
arithmetic in a tight loop with no per-cell dispatch or boxing.

The contract is *simpler* than the scalar kernel. Two probed facts decide it:
**z-array cells are raw `int64`** (`tuple_get/put_int` read/write `((intptr_t*)p)[i]`
verbatim), and **z-array arithmetic wraps** at 64 bits (`a*a` on a big cell gives
the wrapped value, not the scalar path's exact bignum). So the kernel takes the
raw cell in `%rdi`, computes, returns the raw result in `%rax` — **no untag, no
overflow guard, no 2R encoding** — and a wrapping native kernel matches love's
elementwise ops *exactly, the wrap included*.

The `amap`/`amap2` nifs do the loop in C, where the tuple layout is known and
nothing allocates (so no GC moves the cell buffers mid-loop):

```
(amap    code in out)     ; out[i] = fn(in[i])          -- map, 1-arg kernel (cell in %rdi)
(amap2   code a b out)    ; out[i] = fn(a[i], b[i])     -- zipWith, 2-arg kernel (%rdi, %rsi)
(areduce code init in)    ; acc=init; acc=fn(acc,cell)  -- fold, 2-arg kernel (acc %rdi, cell %rsi)
```

`jit/array.l` is the codegen + drivers. `(ajit '(\ x <arith>))` forges a raw 1-arg
kernel → `(\ array → array)` over `amap`; `(ajit '(\ x y <arith>))` forges a raw
2-arg kernel → `(\ a b → array)` over `amap2`. `(afold '(\ acc x <arith>) seed)`
forges a 2-arg kernel → `(\ array → scalar)` over `areduce`. Map/zipWith let love
allocate the matching output array; the fold returns a scalar via `emit_int` (a
fixnum if it fits, else a wide-int box), so its wrap-and-box matches `asum`/`aprod`
exactly. Ops: `+ - *` and comparisons (`// %` deferred — `idiv` `#DE`s on a zero
cell). Verified equal to love's broadcast/reduction ops, wrap included:

```sh
out/host/love -l jit/kernel.l jit/array.l   # map + zipWith + reductions (sum/prod, incl. wide box & wrap) — ALL PASS
```

### Float arrays — `armap` + `jit/farray.l`

`r`-array cells are raw `f64`, and the SysV ABI passes/returns a `double` in
`%xmm0` (the same shape as the C math callbacks `lvm_vmap1` feeds for sin/cos), so
`armap` is `amap` with a `g_flo_t(*)(g_flo_t)` kernel. `jit/farray.l` emits SSE
scalar-double code: the cell is saved to `%xmm15` in the prologue and re-read on
each use of `x` (the float analogue of re-deriving from `%rdi`), binops use the
machine stack, integer literals convert with `cvtsi2sd`, and `+ - * /` are
`addsd`/`subsd`/`mulsd`/`divsd`. Float `/0` is `ieee-inf` (no `#DE`), so `/` is
safe; comparisons are omitted (they'd yield a `z` mask, not an `r`-array), and
float literals are deferred (they'd need their raw IEEE bits). `(rjit '(\ x
<arith>))` → `(\ r-array → r-array)`, verified bit-for-bit against love's
elementwise ops:

```sh
out/host/love -l jit/kernel.l jit/farray.l   # x+x, x*2, x/2, x*x-1, x/0→ieee-inf — ALL PASS
```

### Complex arrays — `acmap` + `jit/carray.l`

`c`-array cells are interleaved `(re,im)` f64 pairs, and the SysV ABI
passes/returns a two-double struct in `%xmm0` (re) / `%xmm1` (im), so `acmap` is
`amap` with a `struct g_c2(*)(struct g_c2)` kernel and a complex value lives in
`(%xmm0,%xmm1)`. `jit/carray.l` emits the SSE: the cell is saved to
`(%xmm14,%xmm15)`, binops use a 16-byte stack slot, integer literals become
`(k,0)` (`cvtsi2sd` + `pxor`), `+ -` are componentwise, `*` is `(ac−bd)+(ad+bc)i`,
and `/` is the conjugate-divide `((ac+bd)+(bc−ad)i)/(c²+d²)` (`%xmm4`–`%xmm7`
scratch; SSE `divsd` by a zero divisor is inf/nan, not `#DE`, so no crash).
`(cjit '(\ x <arith>))` → `(\ c-array → c-array)`, verified bit-for-bit against
love's complex broadcast ops — the multiply and divide included (`~(1 2)² =
~(-3 4)`; `x/x = ~1`; `x²/x` round-trips to `x`):

```sh
out/host/love -l jit/kernel.l jit/carray.l   # x+x, x*x, x-1, x*2, x*x+1, x/2, x/x, x*x/x — ALL PASS
```

**Float and complex literals** land via the `(fbits f)` nif — the raw IEEE-754 bit
pattern of a double as an integer (a wide-int box past the fixnum tag). The codegen
loads a constant with `mov rax, (fbits f) ; movq xmm0, rax`; bytes come from a
bit-op extractor (`leb64`, `& / >>`) so it works on the wide box and negative
patterns alike. So `(rjit '(\ x (* x 1.5)))`, `(\ x (* x -2.0))`, and
`(cjit '(\ x (* x ~(0 1))))` (multiply by *i* — `~(re im)` reads as `(plex re im)`
with real-literal components) all compile, bit-exact vs love.

**Float comparisons** yield a `z`-mask, so they need a different output type: the
`armapz` nif maps an `r`-array → a `z`-array with a `double→int` kernel (`comisd`
+ `setcc` → 0/1). `rjit` dispatches — a top-level comparison `(\ x (< x 2.0))`
compiles to a z-mask kernel over `armapz`; pure float arith stays `r`→`r` over
`armap`. Verified vs love: `(@(1.0 2.0 3.0) < 2.0)` → `@(1 0 0)` (a `z`-array).

Complex comparisons are still out (`<` on complex is nil in love — only `=`
applies, and it's componentwise; a separate case if ever wanted).

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
