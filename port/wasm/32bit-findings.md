# 32-bit / wasm port: findings

The wasm shim (`host.c`) is a 32-bit, browser-hosted build of love. Running the
full test corpus against it (`make test_wasm`: love.js under node, the same `$t`
the native gate eats) surfaced the differences below.

## Platform facts (gated in the corpus on `wint`, expected)

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

`max-charm`/`min-charm` are exposed from the core (`g_ini_0`) so the corpus can gate
on the real boundary instead of a baked-in 64-bit literal; the single predicate
is `wint = (< (32 2) max-charm)` (true on the full 64-bit hosted builds).

## Fixed

- **A function pointer is a small table index, and an odd one IS a charm.** c0's
  saturated-call peephole (`ana_ap`, core/ev.c) read a quoted operator as a nif's
  code table -- `[1].ap == lvm_ret0` -- which on a native word can never hold of a
  payload, and on wasm holds whenever `lvm_ret0`'s slot is `2k+1` and the quoted value
  (a chain, a lambda, a partial) carries the charm `k` there. p1's letrec then compiled
  wrong, its `seal-hook` never ran, and the egg trapped applying the unsealed hook. Which
  slot `lvm_ret0` gets depends on link order, so any change to host.c flipped it. Now the
  peephole asks for a static table (`!in_data && !in_heap`) before reading one.
- **A `'string'` through ccall rides the wasm stack.** an eval of a frame (rove's 2K,
  ink's 5K, more when several accumulate) through `cwrap('ai_eval', .., ['string'])`
  overflowed it -- "memory access out of bounds" anywhere in the VM, intermittently,
  as the stack's tenant varied. every eval now marshals through the heap (test.mjs
  had learned this for the corpus; repl.js and screen.mjs follow).
- **A scare in a task with no help installed is a runaway, not an end.** rove's
  runner scares at its tail (`;; missing g`, its own bug); under the page's `hear` that
  prints and lands, under no help the task drew frames forever. the gate installs
  the page's handler before an app boots.
- **`#0` is the number 0, not a box.** the page driver's `qbox #0` idiom pinned into a
  charm, silently; the boxes are tablets (port/wasm/web.l).
- **test.mjs had lost its `import` of the module** and the gate's paths still spelled
  the pre-move `wasm/` directory: test_wasm had not run since the tree move.

- **`turn` truncated the 64-bit RNG on a 32-bit word.** The state was
  always 256 bits (raw-byte limbs, a C/8-byte array on a 32-bit word), but the
  *output* was masked with `fix_max` -- word-dependent (2^62-1 native, 2^30-1
  wasm) -- so the draw was cut to ~30 bits and the stream diverged from every
  other target. Fixed by masking to a fixed 62 bits and canonicalizing through
  `g_big_canon`: the same integer on every target (a fixnum on a 64-bit word, a
  bignum on a 32-bit one). A second site fell out of the same root -- the
  prel `rng-set` validator hard-coded the state's atype as `z`, so it
  *rejected* a valid wasm seed (C-typed) and silently clock-seeded; it now
  compares against a fresh seed's own type. `random.l` runs on wasm again,
  cross-target pins included; only the state's atype stays platform-visible
  (`z` on a 64-bit word, `c` on a 32-bit one).

- **`io.l`'s real-file path OOMed on the wasm host.** `open`/`close` are
  frontend nifs the wasm host doesn't install, so on wasm `open` is a missing
  name that resolves to a non-port; the `slurp` loop then called `(get <non-
  port>)`, which *echoed its argument* instead of signalling EOF, so the loop
  spun and grew a list until it threw "memory access out of bounds". Fixed at
  the root: `get` on a non-port now returns `-1` (EOF) -- a read of an empty
  stream -- so a read-until-`-1` loop is bounded on every target (`io.l` pins
  this directly; the real-file roundtrip stays gated, since wasm has no FS).

- **A deliberate scare's `help-log` entry was inflated on the wasm host** (the
  observed symptom was `(peep help-log 1 0)` reading `0` when expected `1`).
  Root cause: `exit` is a frontend nif the wasm host didn't install, and
  `report` (the assert harness) mentions `(exit 1)` in its unrun fail branch.
  A closure captures its free globals at creation, so the missing `exit`
  raised `(scare 'missing 'exit)` at every assert's define -- an extra s=1
  observation that pushed the count past 1. Fixed by installing `exit` in the
  wasm host (`host.c`), like the native (`main.c`) and kernel (`kmain.c`)
  frontends do. `help.l`'s pin runs on wasm again. (During the hunt, `lvm_scare`
  was also brought in line with its siblings `lvm_freev`/`lvm_missing` --
  `Have(6)` not `Have(1)`, so `g_raise`'s `avail>=5` guard can't silently drop a
  scare's help under heap pressure; latent, not the cause here.)

- **The frontend-nif divergence is closed at the core.** `exit` (and `open`/
  `close`/`run`/`getenv`) were installed per-frontend, so a frontend could
  silently omit one and leave a missing-name landmine -- exactly how the wasm
  host diverged. The core now installs safe nil-returning defaults for all five
  (`love.c` `frontend_defaults`); a frontend's own `g_defn` still overrides
  (the book is last-write-wins), but a forgotten one inherits a clean nil
  instead of a missing name. Verified on wasm (the names resolve to nil, and
  help.l passes from the core default alone with the host override removed) and
  on the kernel (gates green; it overrides only `exit`, defaults cover the
  rest). The mechanism is the book, not weak C symbols: the frontend aps are
  `static`, so they can't participate in weak/strong link override, and the
  book is love's own idiomatic override -- no linker semantics to depend on.

## Not a bug

The f32 reals and ~30-bit fixnums are *by design* on a 32-bit port (the boxed
fixnum/float must fit in one word). They are platform facts, not defects -- the
page just shows single-precision numerics. Widening the 32-bit float box to f64
would be a deep core change (it breaks the "`g_flo_t` is pointer-width" invariant
across boxing, arrays, complex, and the `data.h` shape slots) and is out of scope.
