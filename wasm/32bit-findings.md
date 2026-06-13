# 32-bit / wasm port: findings

The wasm shim (`host.c`) is a 32-bit, browser-hosted build of love. Running the
full test corpus against it (`make test_wasm`: love.js under node, the same `$t`
the native gate eats) surfaced the differences below.

## Platform facts (gated in the corpus on `w64`, expected)

The 32-bit word makes love a genuinely different numeric/host platform; these
asserts are correctly skipped on wasm and still run on the 64-bit hosted builds
(native, kernel):

- **Fixnums are ~30-bit** (the tag boundary is 2^30, vs ~2^62), so the wide-int
  "box" and the bignum thresholds shift down. (`box.l`, `matrix.l`, `arith.l`,
  `objarr.l`, `CLAUDE.l`)
- **Reals are f32** (`g_flo_t = float`, the boxed real is one word): `1e308`/
  `1e300` overflow to `inf`, and `sin`/`cos`/`log`/`pow` carry ~1e-7 error
  (`powf`/`sinf`, not glibc). (`arith.l`, `complex.l`, `math.l` -- the last via a
  platform-dependent `close`/`very-close` epsilon)
- **No filesystem, subprocess, or environment** in the browser host. (`io.l`'s
  real-file round-trip, `run.l`'s `run`/`getenv`)

`fix-max`/`fix-min` are exposed from the core (`g_ini_0`) so the corpus can gate
on the real boundary instead of a baked-in 64-bit literal; the single predicate
is `w64 = (< (32 2) fix-max)` (true on the full 64-bit hosted builds).

## Real bugs (to fix; gated meanwhile)

1. **`rand-next` truncates the 64-bit RNG on a 32-bit word.** The xoshiro256++
   state is a *word-int* tuple -- 256 bits on a 64-bit word, only 128 on a 32-bit
   one -- and the output is cut to the word (`(cap (rand-next (rng-seed 1)))` is
   `788775579` on wasm vs `1136543726722859675` native). So the stream diverges
   from every other target and `random.l`'s "same sequence on every target" pins
   fail. Fix: carry the RNG state/output in fixed 64-bit limbs, word-size
   independent. (`random.l` skipped on wasm.)

2. **`io.l`'s real-file path OOMs on the wasm host.** The shim stubs fd-backed
   ports (reads return EOF, writes go to the out buffer); the `open`/`fputs`/
   `fgetc` round-trip then attempts a ~4 GB allocation and throws "memory access
   out of bounds" instead of failing cleanly. Fix: make the stubbed / failed-open
   path safe (bounded). (The file block is gated; in-memory `sip` ports still run
   on wasm.)

3. **`help-log` not recorded on the wasm host.** After `(scare 'deliberate
   'data)`, `(peep help-log 1 0)` is `0` on wasm but `1` on the hosted builds --
   the deliberate scare's observation isn't logged. Root cause not yet isolated.
   (`help.l` line gated.)

## Not a bug

The f32 reals and ~30-bit fixnums are *by design* on a 32-bit port (the boxed
fixnum/float must fit in one word). They are platform facts, not defects -- the
page just shows single-precision numerics. Widening the 32-bit float box to f64
would be a deep core change (it breaks the "`g_flo_t` is pointer-width" invariant
across boxing, arrays, complex, and the `data.h` shape slots) and is out of scope.
