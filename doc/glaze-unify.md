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
| group/grid/cask | autogroup(autonat(twolow(castbuild))) | ⏸ stays with auto-ev by design (natjit declines; see §3) |

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

### 3. groups / grids / casks — DECIDED: option (a), stays with auto-ev

The fall-through lane: mutually-recursive arith GROUP (fib/tak/primes), float
GRID nest (autonat/jitfgridn, x86-only SSE2), string-builder CASK (castbuild,
x86-only cask-fill), complex-grid lowering (twolow). This is the hardest port —
it's a source→source rewrite chain that ENDS in `(base-ev <rewritten>)`, which on
the hook would re-enter `ala`.

**The two architectures don't compete here, and that's the whole reason (a) is
right, not a compromise.** A group is a top-level `:` named-let form — `(: (fib n)
(? …) (fib 25))` — binding one-or-more mutually-recursive defs and then calling
one. auto-ev's recognizers work on exactly that `:` form, and the form reaches
`ev` at the top-level file/REPL boundary (probed: the glaze-x86.l group tests all
invoke `(ev '(: (fib n) …))`). natjit, by contrast, fires on `ala` — individual
CLOSURE builds. Handed a group-shaped closure it DECLINES: its body is a `:`
(a bind-and-call), not leaf/loop grammar, so the hook falls straight to bytecode
(probed: building `(\ n (: (f k) … (f n)))` trips natjit 0 times). So groups land
with auto-ev by construction, and the hook never shadows them.

The remaining worry — an *embedded* group (a whole mutually-recursive group built
by `ala` deep inside another closure's body, never handed to `ev`) — is what a
ported group lane would buy. But that shape barely occurs: a group is a top-level
program/def structure, not the kind of single `(\ …)` you instantiate inside a hot
loop. Nothing in the corpus or the microbenches builds a fresh mutually-recursive
group per iteration. So the hook's extra reach (embedded closures) has nothing to
add over auto-ev's whole-body reach for the group family specifically.

Rejected alternatives:

* **(b) port with an `e`-deopt.** Give the group lane the hook treatment: after
  the rewrite, glaze the group but keep `e` as the OUTER closure's deopt. The
  rewrite chain ends in `(base-ev <rewritten>)`; to ride the hook it would need a
  deopt seam that isn't `(base-ev source)`. Real work, for a workload (embedded
  hot groups) that doesn't exist. Revisit ONLY if profiling ever surfaces one.
* **(c) arch note (informational, not a gap):** grids and casks are x86-only
  regardless; on arm64 this lane falls to the interpreter, except `autogroup`
  lowers everything reducible to the integer group, so fib/tak/primes still glaze
  there.

**Decision (revisable): ship (a).** The group/grid/cask family stays behind the
ev-rebind (auto-ev); natjit deliberately owns the leaf, captured-leaf, counted-
loop, float-leaf and n-var-loop lanes and declines the rest to bytecode. This is
the intended long-run split between the two architectures, not an unfinished port.

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
4. ~~**groups/grids/casks**~~ — DECIDED: ship option (a). The group/grid/cask
   family stays with auto-ev (whole-body reach); natjit declines it to bytecode.
   The intended split, not an unfinished port. See section 3 above.
5. **retire auto-ev's redundant coverage** (the only item left, and optional) —
   once natjit matches a lane, the ev-rebind no longer NEEDS to carry it. Keep
   `base-ev` in the module book (the pure interpreter, and the AI_NO_GLAZE
   fallback) and the group chain (option a); the redundant leaf/loop/float lanes
   in the ev-rebind could be trimmed, but they're harmless duplication — auto-ev
   memoizes and natjit declines nothing it should catch, so the two coexist
   without conflict. Trim only if the maintenance surface starts to bite.

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
