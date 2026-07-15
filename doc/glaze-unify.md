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

natjit covers two lanes today:

| lane            | auto-ev            | natjit (hook)                    |
|-----------------|--------------------|----------------------------------|
| leaf + n-ary    | qual→jitir, qualn→jitnir | ✅ via `coreir`/`assemble`, deopt→`e` |
| captured leaf   | qualc→jitnir(flatc)| ✅ (compiles over the frame `ps = (init (cup s))`, imps included) |
| counted loop    | loopinfo→njit-loop | ✅ njit-loop with `e` as deopt   |
| float leaf      | qualfr→jitfr       | ✅ qualfr gate → jitfrx with `e` as deopt |
| n-var loop      | loopinfo-n→njit-loop-n | ❌ pending                    |
| group/grid/cask | autogroup(autonat(twolow(castbuild))) | ❌ pending          |

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

### 2. n-var loop (`loopinfo-n` → `njit-loop-n`)

The `(\ n ((: (go v0..vk) (? T (go U..) R)) I0..Ik))` shape — up to 3 loop vars
with arbitrary update exprs (iterative fib/tak: i,a,b with updates b and a+b).
`njit-loop-n` already exists and is called by auto-ev; the port mirrors the
counted-loop lane already on the hook. **The tax:** `njit-loop-n`'s cf-deopt
closure currently falls to `(base-ev lam)` on the post-overflow / non-canonical
path (auto.l ~line 145). To ride the hook it needs the same deopt-target
parameterization `njit-loop` got — thread `e` through cf-deopt so the overflow
path re-enters the bytecode twin, not the interpreter-over-source.

### 3. groups / grids / casks (`autogroup(autonat(twolow(castbuild)))`)

The fall-through lane: mutually-recursive arith GROUP (fib/tak/primes), float
GRID nest (autonat/jitfgridn, x86-only SSE2), string-builder CASK (castbuild,
x86-only cask-fill), complex-grid lowering (twolow). This is the hardest port —
it's a source→source rewrite chain that ENDS in `(base-ev <rewritten>)`, which on
the hook would re-enter `ala`. Options, cheapest first:

* **(a) leave it to auto-ev.** natjit handles the leaves and loops; the group
  chain stays behind the ev-rebind. Since group bodies are top-level named-lets
  (whole-body), they ARE handed to `ev` and auto-ev catches them — the hook's
  extra reach (embedded closures) rarely lands a whole mutually-recursive group.
  This may be the right long-run split, not a gap.
* **(b) port with an `e`-deopt.** Give the group lane the same treatment: after
  the rewrite, glaze the group but keep `e` as the deopt for the OUTER closure.
  Needs the rewrite chain to expose a deopt seam that isn't `(base-ev source)`.
* **(c) arch note:** grids and casks are x86-only regardless; on arm64 this lane
  already falls to the interpreter (autogroup lowers everything reducible to the
  integer group, so fib/tak/primes still glaze there).

Recommendation: ship (a) as the stated design, revisit (b) only if profiling
shows embedded groups are hot.

## the cache

auto-ev memoizes: `(memo e (\ l ...))` keys the compile by the source form, so
re-eval of the same lambda SITE reuses the compiled code. natjit does NOT memo —
it compiles fresh per `ala` call, i.e. per closure INSTANTIATION. Many
intermediate closures are built at runtime; a fresh compile each time is the
cost.

The question is measurement-first (per the plan): **measure the impact of not
caching before adding a cache.** A leaf compile is cheap; if the hot closures are
built once, the cache buys little. If a closure site is instantiated in a loop,
the cache is the win.

The blocker if we DO cache the native VALUE: spec.l:117,
`!(id? (\ x (+ x 1)) (\ x (+ x 1)))` — two evaluations of the same lambda are
distinct objects. A cache that returns the SAME native cell for the same source
would make them `id?`-equal, violating the law. The decision already taken: **it
is not a strict correctness need for distinct evaluations of one lambda
expression to be distinct objects — leave id?-distinctness unspecified if the
cache is the only thing it blocks.** So the cache step is:

1. measure not-caching (get the number first).
2. if it pays, add a compile cache keyed by source form (share the code bytes; a
   cache that shares the whole cell is fine under the relaxation).
3. relax spec.l:117 to drop the `!(id? …)` half for glazed leaves — keep the `=`
   half (they stay structurally equal), document the carve-out.

## sequence

1. ~~**float leaf**~~ — LANDED (`8a88dfb9`).
2. **n-var loop** — thread `e` through cf-deopt, then port (mirrors counted loop).
3. **measure the cache** — number first; add + relax spec only if it pays.
4. **groups/grids/casks** — ship option (a) (leave to auto-ev) as the design;
   port (option b) only if embedded groups profile hot.
5. **retire auto-ev's redundant coverage** — once natjit matches a lane, the
   ev-rebind no longer needs to carry it. Keep `base-ev` in the module book (the
   pure interpreter, and the AI_NO_GLAZE fallback); shrink the ev-rebind to
   whatever natjit deliberately leaves it (the group chain, under option a).

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
