# glaze unification: native code for every closure we eval

The goal, stated plainly: **generate native code for every function we eval on
platforms that support it** — not just the form handed to `(ev '(\ ..))`, but
every closure `ala` builds, embedded in a fn or let body too. `ai/glaze/hook.l`
is that path (the `natjit` creation hook). This doc is the map from where it is
to full parity with `auto-ev`'s lane set, then past it.

## two architectures, one target

There are two ways the glaze can reach a closure:

* **auto-ev** (`ai/glaze/auto.l`) — rebinds the global `ev`. It sees only the
  form passed to `ev`, memoizes the compile keyed by that source, and routes it
  down a lane ladder (leaf / n-ary / closure / float / loop / group). This was
  the first design and carries the richest lane set. But an embedded `(\ ..)`
  inside a fn body is never handed to `ev` — `ala` builds it directly — so
  auto-ev never saw it.

* **natjit** (`ai/glaze/hook.l`) — installs `book['natjit]`, read by ev.l's
  `ala` on **every** closure built, top-level AND embedded. This is the reach
  auto-ev never had. A qualifying closure is native-backed AT CREATION and
  deopts into its own bytecode `e` on overflow / wrong kind — so native is
  never wrong, just faster.

natjit is the target architecture. auto-ev's lanes are the parts list; the work
is porting each lane onto the `ala` hook (which changes the deopt target and the
re-entry discipline, below), then retiring auto-ev's redundant coverage once
natjit matches it.

## the four invariants (every lane must keep them)

Ported to the hook, a lane inherits four constraints. They are why the
source-rewrite jit-walk (an older, abandoned design) wasn't safe and this is:

1. **transparent** — the native cell keeps `value[-1] = s` (the surface src), so
   `=` / `show` see the source; the enclosing closure's src is never rewritten.
2. **id?-distinct** — a fresh native cell per `ala` call, exactly like bytecode
   closures: `!(id? (\ x E) (\ x E))` holds (spec.l:117). See "the cache" below —
   this is the one invariant the shared-cache step deliberately revisits.
3. **macro-safe** — compile the SURFACE body `(last (cup s))` (post-opfix,
   pre-tag), so iop/apx tags never reach codegen; a macro/non-arith body simply
   fails the grammar and stays bytecode.
4. **no jit↔ev re-entry** — the deopt target is `e` ITSELF (the bytecode closure
   `ala` already built), passed as the native cell's interp slot. NOT `(ev s)` or
   `(base-ev s)`: re-interpreting `s` inside the hook would re-enter `ala` →
   natjit → … So natjit passes `e`. This is the single sharpest difference from
   auto-ev, which is free to deopt to `(base-ev l)` because it runs OUTSIDE `ala`.

Invariant 4 is the porting tax: every lane auto-ev deopts to `(base-ev l)` must,
on the hook, deopt to `e` instead. `njit-loop` already took the fix — its deopt
target is a parameter now (auto-ev passes `(base-ev l)`, natjit passes `e`), so
one lane serves both callers.

## where we are

natjit covers the leaf, captured-leaf, counted-loop, float-leaf and n-var-loop
lanes today; only the group/grid/cask fall-through remains with auto-ev:

| lane            | auto-ev            | natjit (hook)                    |
|-----------------|--------------------|----------------------------------|
| leaf + n-ary    | qual→jitir, qualn→jitnir | ✅ via `coreir`/`assemble`, deopt→`e` |
| captured leaf   | qualc→jitnir(flatc)| ✅ (compiles over the frame `ps = (init (cup s))`, imps included) |
| counted loop    | loopinfo→njit-loop | ✅ njit-loop with `e` as deopt   |
| float leaf      | qualfr→jitfr       | ✅ qualfr gate → jitfrx with `e` as deopt |
| n-var loop      | loopinfo-n→njit-loop-n | ✅ loopinfo-n gate → njit-loop-n with `e` threaded through cf-deopt |
| group/grid/cask | autogroup(autonat(twolow(castbuild))) | 🔶 flag-gated prototype (`AI_GROUP_GLAZE`): groups w/ flat + general tails (synthetic `__outer`) + church/HOF (via the `welow` feel-hook), ~4–9×; lift/fold-close + grids/casks open — see §3 |

Flag-gated alongside: the **partial-glaze bridge** (`AI_PARTIAL_GLAZE`) — when
the grammar has no recognizer for an op, splice an in-convention CALL to its C
body (`host/main.c ai_pg_dyad`, via the `pgaddr` nif). Off by default →
byte-identical. This is an orthogonal lever (grow the grammar op-by-op through C
bodies) rather than a lane to port, but it lives in the same emitter.

## the pending lanes

Each is a port of an auto-ev lane onto the hook, respecting invariant 4.

### 1. float leaf (`qualfr` → `jitfr`) — LANDED (`8a88dfb9`)

A `(\ x <fexpr>)` whose RESULT is a heap-boxed gem, over cgf's `+ - * /`. Sound
ONLY when the param is floated at first use (jitfr's precondition). On the hook:
`qualfr` gates the lane (between the integer leaf and the counted loop), compile
via `jitfr`, deopt to `e`. jitfr was split into a 2-arg public wrapper (bakes
`(ev lam)` — auto-ev + the glaze-x86 tests unchanged) over a deopt-parameterized
core `jitfrx` (the `njit-loop` precedent); natjit calls `jitfrx s 'x64 e`. One
param only (qualfr's shape) so a captured float leaf falls through to bytecode
for now. Only natjit's path is new (x86-host-only); auto-ev's float lane, incl.
arm64, rides the unchanged 2-arg jitfr.

### 2. n-var loop (`loopinfo-n` → `njit-loop-n`) — LANDED (`b172c80e`)

The `(\ n ((: (go v0..vk) (? T (go U..) R)) I0..Ik))` shape — up to 3 loop vars
with arbitrary update exprs (iterative fib/tak: i,a,b with updates b and a+b).
`njit-loop-n` already existed and was called by auto-ev; the port mirrors the
counted-loop lane. **The tax paid:** `cf-deopt` + `njit-loop-n` gained an
`interp` param (the `njit-loop` precedent); the internal else-branch `(base-ev
lam)` became `interp`. auto-ev's two call sites pass `(base-ev l)`; the hook
passes `e`, so the overflow path re-enters the bytecode twin, never
interpreter-over-source. The C-finite matrix-power closure `(\ n (cf-dot …))` is
itself bytecode under the hook — its body isn't leaf/loop grammar, so it never
re-enters `ala`, and needs no special handling.

### 3. groups / grids / casks — PROTOTYPE LANDED (flag-gated), full port open

The fall-through lane: mutually-recursive arith GROUP (fib/tak/primes), float
GRID nest (autonat/jitfgridn, x86-only SSE2), string-builder CASK (castbuild,
x86-only cask-fill), complex-grid lowering (twolow). This is the hardest port —
it's a source→source rewrite chain that ENDS in `(base-ev <rewritten>)`, which on
the hook would re-enter `ala`.

**An earlier draft here claimed "groups are top-level structures, leave them to
auto-ev" — that was wrong, and probing killed it.** Groups aren't restricted to
top level: a `:` named-let group is an expression, it nests anywhere, and
`autogroup` recurses arbitrarily deep into any form handed to `ev` (probed:
transformed at two lambda-layers down). So the boundary was never top-level vs
embedded.

The boundary that actually exists is **define-and-call-in-one-`ev`'d-form vs a
reusable closure.** Measured (fib(30)×3, host x86):

| shape                                             | ms   | vs interp |
|---------------------------------------------------|------|-----------|
| group defined AND called in one `ev`'d form       | 14   | **14×**   |
| group wrapped in a reusable `(\ m … (fib m))`, top-level def | 192  | ~1×       |
| same, built by a runtime factory                  | 181  | ~1×       |
| pure `base-ev` interpreter                        | 199  | 1×        |

The group glaze pays 14× ONLY for the define-and-immediately-call shape (the shape
every glaze-x86.l group test uses: `(ev '(: (fib n) … (fib 25)))`). Wrap the group
in a reusable `(\ m …)` closure — the natural way to write a reusable recursive
function — and it drops to interpreter speed, **top-level def and factory alike**.
auto-ev structurally can't fix this: it glazes the form it's handed, and it's never
handed the group-bearing closure's body as a callable-later unit.

That is exactly natjit's domain. natjit fires on `ala` — it SEES the `(\ m (: (fib
n) … (fib m)))` closure when it's built (probed: it currently DECLINES, body is a
`:` not leaf/loop grammar, `fires 0`). A ported group lane — recognize a
group-bearing closure body, compile it over the frame to a native call tree, deopt
to `e` — would native-back reusable recursive closures, closing the 14× gap that
auto-ev cannot reach. This is the strongest remaining case for the hook, not a
non-issue.

The tax (why it's the hardest port): the auto-ev group chain ends in `(base-ev
<rewritten>)`, which under the hook re-enters `ala`. To ride the hook it needs a
deopt seam that isn't `(base-ev source)` — the same `e`-deopt discipline the loop
and float lanes already took, applied to the group rewrite's output.

* **arch note (informational, not a gap):** grids and casks are x86-only
  regardless; on arm64 this lane falls to the interpreter, except `autogroup`
  lowers everything reducible to the integer group, so fib/tak/primes still glaze
  there.

**Status: PROTOTYPE LANDED, flag-gated (`f9b0f573`).** A first cut of the lane is in,
behind `AI_GROUP_GLAZE` (off by default → byte-identical). It native-backs a reusable
group closure at ala-build and measures **~8.8×** on fib (114ms→13ms), correct,
id-distinct; full gate green flag-off.

Two things the port took — both worth remembering:

* **The group machinery re-enters the evaluator.** Not just `base-ev`: `jitgroupir`
  ITSELF calls `(ev ..)` (emit.l) to build its deopt fallback `fb`. Calling any of
  them from inside the `natjit` hook re-enters `ala` mid-build and **segfaults** —
  the existing lanes never do (emit/assemble/nif are pure). Fix (the
  `njit-loop`/`jitfrx` precedent): a PURE, deopt-parameterized **`jitgroupirx`** that
  takes `e` directly; `jitgroupir` is now an identical wrapper. This is the real shape
  of "the `e`-deopt seam through the rewrite chain."
* **At `ala` the body is post-`feel`** — define-sugar `(fib n) B` is desugared to
  `fib (\ n B)`, so `anat-defs` yields `(name . lambda)`, not jitgroupir's
  `((name p..) . body)`. The lane converts it. (A top-level sim on the *sugared* form
  passes but the hook won't fire — the mismatch that cost a debugging round.)

**General tails landed** (extends the prototype). The tail no longer has to be
`(entry frame-params-in-order)`. Any tail expressible in the group grammar — `(+ 1 (fib m))`,
a computed/reordered arg `(fib (* m 2))`, tree recursion `(+ (fib (- m 1)) (fib (- m 2)))` —
rides through a **synthetic `__outer` entry** `((__outer . frame) . TAIL)` appended to the
group; `__outer` becomes the jitgroupirx entry, so the outer closure evaluates the tail then
dispatches. A flat tail still takes the direct path (entry = the real group fn, zero
indirection). Two guards make it sound: `opnd-ok?` rejects a tail with an operand-position leaf
that isn't a frame slot (a global read jgir can't compile → bytecode); `jgir-ok?` gates ops over
the augmented defs. Captured frees are frame IMPORTS (`ps = imports++args`), so a tail reading a
capture compiles fine; only a genuine global falls out. Measured **~9×** on `(+ 1 (fib m))`
(36ms→4ms at fib(30)), == interp through the 25! bignum deopt, id-distinct.

**Front-half landed (church + HOF) — as a SHARED `feel`-time lowering hook, not in the hook.**
The autogroup front-half is a source→source rewrite chain; running it *inside* the natjit hook
would re-enter the evaluator (`autospec`/`loopclose` call `base-ev`; `rewrite-bindings` calls
`jitgroupir`→`ev`). So instead the lowering lives one stage EARLIER and shared: ev.l's `:-`
(the per-form compile entry) reads a `book['welow]` hook before `opfix`, exactly like `ala`
reads `book['natjit]`. The glaze installs `welow` = `dehof-deep ∘ dechurch` — so a church-bearing
group (`(2 (+ 1) 0)` → `(+ 1 (+ 1 0))`) or a curried-HOF group (`dbl = (\ f (\ x (f (f x))))`
inlined) arrives at `ala` already FIRST-ORDER, and the existing group lane native-backs it. `welow`
= `dehof-deep ∘ dechurch` is now **baked pre-egg IN FULL** (both halves — a self-contained
`dechurch`/`dsimp` closure PLUS the `dehof`/`ho-*` fixpoint + `anat-defs`/`subst-sym`/`unpair`/`dehead`/
`dcount`, all prel-only since `monofix` is the shared harness — in ev.l's welow closure, flag-gated,
helpers captured so only `welow` leaks). So the **bootstrap self-compile lowers church AND HOF**, and
this is the **SOLE welow** — the ai/glaze/hook.l shadow (formerly the church+HOF layer) is REMOVED, no
drift. Measured
~4× (HOF g(200000): 16→4ms), == interp, id-distinct. Two corpus-safety guards were needed and the
whole corpus passes flag-on (3451): `dehof-deep` fires ONLY inside a **lambda-body group `:`** (never
a top-level `:` — those hold operator defs like infixop's `**`, which opfix must factor, and body-less
global-leak helpers); `dechurch` is whole-tree and universally safe. `lift`/`loopclose`/`autospec`
(deep-nest lifting, fold-closing, static-fold) are NOT ported — the last two call `base-ev`.

What the prototype does NOT yet do (the increments to a full port):

* **Coverage gap vs the full autogroup chain (AUDITED 2026-07-15)** — welow bakes `dechurch`+`dehof`;
  the full `autogroup` (auto.l) also runs `fold-consts`, `debool`, `defoliate`, `delet`, `lift`, `plift`
  (all pure), plus `autospec` + `loopclose` (both call `base-ev`, so UN-bakeable into welow). The pure
  ones are portable and would add real coverage — `delet` (a value-`:` in a group body), `defoliate`
  (map/filter→loop fusion), `debool` (only `min`/`max`/`abs`; `&&`/`||` are macros already lowered to
  `?`), `fold-consts`. `loopclose` is optimization-only (coverage-neutral — the loop is already native);
  `autospec` is niche (interp-over-static-data). BUT the measured payoff is small: welow's incremental
  `fires` on ordinary code is ≈0 (10 varied test files: 96 fires, identical flag-on/off) — the natjit
  leaf + counted-loop + n-var-loop lanes already own the common hot paths (loops, inline/bound/nested
  named-lets, so `lift`'s marginal value is small too). welow's real delta is concentrated on
  church/HOF/first-order-recursive-group micro-shapes. The uncovered shapes fall to bytecode SOUNDLY
  and at bytecode speed (no slowdown), so this is a not-urgent perf increment, not a default-on blocker.
* **Transparency — FIXED 2026-07-15 (`144880f6`)** — the native cell used to stamp the entry lambda
  (`(\ n …)` flat, or the synthetic `(\ frame.. TAIL)` general) as its src, not the whole outer
  `(\ m (: … ))`, so `=`/`show` against a bytecode outer could differ. `jitgroupirx` now takes a `src`
  param and the hook passes its outer `s` (the same src the leaf lane stamps); `(show group-closure)`
  == `(show bytecode-twin)`. Standalone `jitgroupir` keeps the entry-lambda fallback.
* **Capture-safety — FIXED 2026-07-15** — welow's `dsimp` used to beta via a naive `dsub`, which
  CAPTURED on a shadowing HOF form: `(\ q (: adder (\ i (\ q (+ i q))) ((adder q) 5)))` evaled 8 (interp)
  but 10 (welow-lowered). Since welow feeds the bytecode too (no deopt catches it), that was a hard
  default-on blocker. Fixed (`cf6b5234`) by replacing `dsub` with `dsubx`, an env-threaded
  capture-avoiding substitution that α-renames BOTH `\` params and `:` letrec binders — applied to both
  twins (`ev.l` welow + `auto.l` autospec/deforestation). Preceded by the core inliner's `bsub` fix
  (`d21e3a0e`), which made core `:` scoping consistently lexical so the lowering has a well-defined target.
* **arch note (informational, not a gap):** grids and casks are x86-only regardless;
  on arm64 this lane falls to the interpreter, except `autogroup` lowers everything
  reducible to the integer group, so fib/tak/primes still glaze there.

natjit owns the leaf, captured-leaf, counted-loop, float-leaf and n-var-loop lanes
outright; the group lane is in as a flag-gated prototype covering flat AND general tails. Capture-safety
and transparency are settled (fixed above), and the front-half coverage gap is audited (above) —
default-on-SAFE, the pure enablers being a not-urgent perf increment. So the last gate before deleting
the `AI_GROUP_GLAZE` flag is measuring the compile-time tax (welow walks every form twice, always).

## the cache — MEASURED, decided NO (`fires`-probe, host x86, baked image)

auto-ev memoizes: `(memo e (\ l ...))` keys the compile by the source form. natjit
does NOT memo. The plan was measurement-first: **measure the impact of not caching
before adding one.** Measured (the `fires` counter = natjit compiles):

| workload                                   | closure builds | natjit compiles |
|--------------------------------------------|----------------|-----------------|
| full boot (egg+prel+ev+bao+hook asserts)   | whole corpus   | **14** total    |
| 2000 **distinct** closed leaves via `ev`   | 2000           | 2000 (~0.16 ms) |
| **same** source × 2000 via `ev`            | 2000           | **1** (memo)    |
| same closed leaf × 2000 as a bare literal  | 2000           | **0** (hoisted) |
| capturing `(\ x (+ x i))` × 100000 in loop | 100000         | **0** (see below) |
| re-instantiating `(mk 5)` / `(id 9)`       | N              | **0** additional |

The redundant-recompile count a source-keyed cache would eliminate is **zero**.
An identical source never recompiles, because two mechanisms already prevent it:
(1) **closed-leaf constant-hoisting** — a closed qualifying leaf is built once as a
shared constant, reused on every eval; (2) **auto-ev's memo** on the `ev` path. The
only workload that drives many compiles is *distinct* sources (runtime metaprogramming
via `ev`), and those are all cache MISSES — a source-keyed cache can't help them.

And a capturing leaf like `(\ x (+ x i))` (with `i` a free var resolved through the
environment, not a frame slot) does not qualify for natjit's leaf grammar at all, so
it never fires — 100k iterations, 0 compiles. natjit only fires on closures whose
referenced vars are all frame slots, and those are built at their definition site,
once. Total compiles are **site-bounded, not iteration-bounded**.

**Decision (revisable): do not add the cache.** There is nothing to dedupe. A
consequence worth keeping: spec.l:117's `!(id? (\ x (+ x 1)) (\ x (+ x 1)))` stays
INTACT — no shared native cells, so id?-distinctness remains a real property, not a
carve-out. The earlier plan (relax spec.l:117 for a shared-cell cache) is moot. If a
future workload ever shows natjit compiles growing with iteration count (a hot site
rebuilt under a differing frame that still qualifies), re-measure and revisit — but
nothing in the current corpus or the microbenches exhibits it.

## sequence

1. ~~**float leaf**~~ — LANDED (`8a88dfb9`).
2. ~~**n-var loop**~~ — LANDED (`b172c80e`): `e` threaded through cf-deopt, ported.
3. ~~**measure the cache**~~ — MEASURED, decided NO (nothing to dedupe; hoisting +
   auto-ev memo already cover it; spec.l:117 stays intact). See "the cache" above.
4. **groups/grids/casks** — PROTOTYPE LANDED, flag-gated `AI_GROUP_GLAZE` (`f9b0f573`):
   the pure `jitgroupirx` (`e`-deopt, no internal `ev`) + a hook lane for flat
   direct-tail groups, ~8.8× on fib. **General tails LANDED** (synthetic `__outer`
   entry): `(+ 1 (fib m))`, computed/reordered args, tree recursion all glaze now
   (~9×), guarded by `opnd-ok?` + `jgir-ok?`, == interp through bignum deopt.
   **Front-half (church/HOF) LANDED** — but as a SHARED `feel`-time lowering hook
   (`book['welow]`, read by ev.l's `:-` before opfix, like `ala` reads `book['natjit]`),
   NOT in-hook (autospec/loopclose/rewrite-bindings re-enter the evaluator). `welow` =
   `dehof-deep ∘ dechurch`; church + curried-HOF groups arrive first-order and native-back, ~4×,
   whole corpus green flag-on (guards: `dehof-deep` only inside a lambda-body group `:`; body-less-`:`
   skip). **Phase 2 LANDED IN FULL** — `welow` = `dehof-deep ∘ dechurch` is now baked pre-egg in ev.l
   (BOTH halves: `dechurch`/`dsimp` + the `dehof`/`ho-*` fixpoint + anat-defs/subst-sym/unpair/dehead/
   dcount, all prel-only — `monofix` is the shared harness; helpers captured, only `welow` leaks, no mop
   entry), so the bootstrap self-compile lowers church AND HOF. It is the SOLE welow — the ai/glaze/hook.l
   shadow is REMOVED (no drift). Flag-off it is identity → the egg is byte-identical; flag-on the whole
   fresh bootstrap survives and runs (3451 green), and a direct probe confirms HOF fires (twice/adder
   inlined, == interp) — the bake is capability + self-consistency, exercised by any church/HOF form.
   Remaining: (i) lift/plift/fold-close (deep-nest + static-fold; autospec/loopclose need pure
   re-parameterization); (ii) full transparency. See section 3.
5. **retire auto-ev's redundant coverage** (optional, after 4) — once natjit
   matches a lane, the ev-rebind no longer NEEDS to carry it. Keep `base-ev` in the
   module book (the pure interpreter, and the AI_NO_GLAZE fallback); the redundant
   leaf/loop/float lanes in the ev-rebind are harmless duplication (auto-ev
   memoizes; natjit declines nothing it should catch), so trim only if the
   maintenance surface starts to bite.

## files

* `ai/glaze/hook.l` — the natjit hook (this doc's subject). x86-64 baked; the
  arm64 port follows once the lanes land (the emitter is already arch-parameterized).
* `ai/glaze/auto.l` — auto-ev, the lane parts list. `njit-loop` / `njit-loop-n` /
  `jitfr` / `qual*` / `loopinfo*` live here and are shared by both callers.
* `ai/glaze/emit.l` — the emitter (`coreir`, `jitir`, `jitnir`, `jitfr`, loopcode,
  the partial-glaze `pgbridge`).
* `host/main.c` — installs the hook (`glaze_hook`, x86-only guard) after the holo
  module boundary; the `pgaddr` nif for the partial bridge.
* related: [snapshot.md](snapshot.md) (the always-on baked JIT), [glaze-arm64.md](glaze-arm64.md)
  (the second target), [wake-storm.md](wake-storm.md) (the bake/native-cell hazard).
