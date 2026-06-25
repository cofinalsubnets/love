# Glazing the data workloads — past the arithmetic kernel

The glaze (`ai/glaze/`) compiles ai closures to native code and wins ~12× where it
applies. It started as **arithmetic** only — scalar `+`/`-`/`*`/`…` over a fixnum
param, and counted/recursive integer loops. The two benches where ai trails the
field — **`hash`** and **`tree`** — are built from *heap operators* (`link`/`cap`/`cup`,
`pin`/`peep`) the emitter had no lowering for, so they ran interpreted while their
columns run compiled. This is the plan to extend the glaze's reach to the
allocation-free halves of those workloads, and an honest account of what that buys.

**Status — Stage A/B/C LANDED; D still a study.** The **chain lane** (Stage B,
2026-06-24, `3fff0157`): the `tree` traverse `ck` — `(two? t)`/`(cap t)`/`(cup t)`
over a cons spine — compiles to a native chain fold. The **map-read lane** (Stage C,
`8ec459ad`): `plift` hoists `hash`'s read-only `scan` out of its nested `:` into a
flat group fn, and the recognizer rewrites a map-valued `(peep h k d)` to `mpeep`,
which the emitter lays as a native open-addressed probe — so `hash`'s two `scan`
passes now glaze (383 → 252 ms/it on the full bench; the `ins`/`bump` writes stay
interpreted, Stage D). A later robustness fix (`delet` now inlines a pure value-let
*nested in a sub-expression*, not just at a body root — bottom-up, parity- and
effect-preserving) keeps the glaze from deopting on the natural "bind an
intermediate" loop idiom (a `(g i (: x v (+ x x)))` accumulator), turning a class of
deopt-*losses* into ~10× wins. Only the allocating halves remain: `tree`'s `mk` and
`hash`'s `ins`/`bump` (Stage D). The recognizer gate is also modelled and runnable in
[`doc/proto/glaze-data.l`](proto/glaze-data.l) (its asserts pin which bench bodies
cross which stage). The substrate this builds on is documented in
[`ai/glaze/README.md`](../ai/glaze/README.md); the measurements below were taken on
this host, 2026-06-24, via the [`bench/`](../bench/) harness.

## Why — the gap is interpreter-vs-compiler, not a defect

The benches where ai trails are exactly the ones it runs **interpreted**. The glaze
was prepended only for `float`/`fib`/`tak`/`primes`/`strscan`/`strcat`/`deforest`/
`polysum`/`closure` (`bench/run.sh`) — `tree` (Stage B) and `hash`'s read passes
(Stage C) have since joined it; `hash`'s writes, `sum`, `mapfilter`, `sort`, `bell`
still ride the tree-threaded interpreter, while
their columns are native compilers (chez, sbcl) and JITs (node/V8, luajit, pypy,
clojure/JVM). So those rows read "ai's interpreter vs everyone's compiler", and a
good threaded interpreter is the usual 2–10× off native:

| ms/it | ai | chez | sbcl | racket | node | luajit | pypy | python |
|---|---|---|---|---|---|---|---|---|
| `hash` | 3.13 | 1.60 | 1.18 | 2.57 | 1.29 | 1.84 | 0.94 | 7.68 |
| `tree` | 3.67 | 1.59 | 1.77 | 0.61 | 3.35 | 7.35 | 3.72 | 27.2 |

The A/B settled the diagnosis: *before* the chain lane, prepending the glaze to
`tree`/`hash` changed **nothing** (245→265 ms, 378→353 ms — the recognizers didn't
match), while the same glaze is **~12×** on `primes` (interpreted 15.25 → glazed
1.28 ms/it). The glaze is worth an order of magnitude on the code it owns; these two
just weren't in its grammar. **Stage B put `tree`'s traverse in the grammar**: the
full bench is now **3.68 → 2.43 ms/it (1.5×)** — the build half (`mk`) still
interpreted, the traverse (`ck`) native at **6.7×** in isolation. **Stage C since put
`hash`'s `scan` in the grammar** (the map-read lane: 383 → 252 ms/it); only its
`ins`/`bump` writes remain interpreted (Stage D).

### Where the interpreted time goes — dispatch, not GC, not hashing

Decomposed (us/it, this host):

- **`tree` depth-16 (65535 nodes):** `mk` build+alloc+gc **2550**, `ck` traverse
  (zero allocation) **1650**, `mk`+`ck` **4050**. Pure traversal is already **41%**
  of the bench. The generational collector is healthy (93% infant mortality, mostly
  *minor* collections — see [`doc/gengc.md`](gengc.md)), so copying is the smaller
  half; the cost is interpreted recursion over generic `cap`/`cup`/`two?`/`+`,
  ~25 ns/node.
- **`hash` N=10000:** insert (grows cap 4→16384, 12 doublings) **575**, scan
  (steady) **325**, bump (`peep`+`pin`) **850**. The table *growth* is the cheap
  part. The bulk is per-key interpreted key-math `(+ 1 (* 97 i))` + the nif call +
  generic `peep`/`pin`, ×40000 across four passes. The hash fn (`rot(x*mix)`,
  `ai.c:4508`), the 2-word open-addressed slots, and the `<3/4` load factor
  (`map_min_cap=4`, `ai.c:263`; `ai_mapput`, `ai.c:4307`) are already good — this is
  **dispatch**, not hashing.

So the alloc-avoidance machinery already in the tree does **not** apply here:
generational GC *reaps* the churn cheaply (built — and `tree`'s 93% mortality shows
it working), and deforestation ([`doc/proto/forest.l`](proto/forest.l)) *avoids*
intermediate lists — but `tree`/`hash` have no throwaway intermediates to fuse;
their allocation **is** the result. Only owning the loop, or cheapening dispatch,
can move these.

## The law that shapes the plan — own the loop

The glaze's hard-won result (`ai/glaze/README.md`, "What the experiment found"): **a
glaze wins only when it owns the loop.** A native arithmetic body called *per
element* from an interpreted loop measured ~25% **slower** — the call-boundary tax
(marshal in, the `eat` nif, decode out) beat interpreting a small body. Only the
loop-owning reduction won (~45×). A per-*node* native function called from an
interpreted tree recursion would lose by the same tax. The win requires owning the
whole iteration.

That points the plan straight at the **loops**, and specifically the
**allocation-free** ones first — they own the iteration *and* sidestep the one hard
problem (allocating from native code under a moving collector).

## The recognizer gate

The decision "can this body be glazed?" is a walk over its source for heap
operators. The model in [`doc/proto/glaze-data.l`](proto/glaze-data.l) makes it two
gates:

- `glaze-now?` — today's grammar: arithmetic/comparison/`?` and first-order
  group-calls only, **no** heap touch. Admits `fib`/`primes`; rejects all of
  `mk`/`ck`/`ins`/`scan`, naming the operator each needs (`link`; `two?`/`cap`/`cup`;
  `pin`; `peep`). Its yes-set is exactly the benches the glaze actually speeds up.
- `glaze-read?` — the extension: admit allocation-free chain/map **reads**
  (`cap`/`cup`/`two?`/`peep`), still reject the **allocators** (`link`/`pin`/`tablet`/…).
  This pulls `ck` and `scan` *in*; `mk` and `ins` stay out because they allocate.

The model asserts exactly that staging — `ck`/`scan` cross from now-rejected to
read-admitted; `mk`/`ins` remain the allocation frontier.

**What the build (Stage B) taught the model.** "No allocators" was necessary but
**not sufficient** for soundness. `(cap t)` returns the *tagged* stored word
(`putcharm(v)`), while the group compiler's body math runs on *untagged* ints — so a
chain word must never reach an arithmetic operand (`(+ (cap t) 0)` would read `15`
where `7` is meant). The real `groupok?` therefore carries a **chain-vs-int typing
discipline**: `cap`/`cup` and chain params are *chain-valued* and admissible only as
`two?`/`cap`/`cup` operands or a callee's chain slot — never `+`/`<`/… operands. `ck`
passes (its `cap`/`cup` feed only the recursive `ck`); `(+ (cap t) 0)` is rejected
and stays interpreted. `glaze-read?` above is the coverage gate; the typing is the
soundness gate the implementation added on top.

## The plan (staged; each stage measures against `ev` before baking)

Per the scalar-hook lesson, every kernel is benchmarked against the interpreter
*before* it is committed — a kernel that doesn't beat `ev` doesn't ship.

- **Stage A — recognizer. ✅ LANDED.** `ai/glaze/auto.l`'s `groupok?` now admits the
  `cap`/`cup`/`two?` chain fold (plus the chain-vs-int typing above). `lvm_chain`'s
  sentinel comes from `(apof (link 0 0))`, the same `apof` trick the string lane uses
  for `lvm_str`. (The `peep` probe loop — `scan` — waits on Stage C.)
- **Stage B — emit the `ck`-class kernel. ✅ LANDED.** A native chain fold:
  pointer-chase `cap`/`cup` over the cons spine (`[t+8]`/`[t+16]`, chain-guarded,
  deopting a non-chain), accumulate a fixnum. The direct generalization of the baked
  array reductions (`asum`/`aprod`) from a packed array to a linked spine.
  Allocation-free → no GC interaction. Chain params are a new ABI mode: raw-passed
  (no `sar`) but **unguarded** at entry — soundness comes from `two?` being total.
  **The memory-latency worry was wrong.** A Stage-0 probe (a hand-emitted `ck` kernel
  run on the real depth-16 tree) recovered **~11×**, in the band of the pure-arith
  loops — the traverse is **dispatch-bound, not L2-bound**. Through the real
  autogroup path: **1740 → 260 us/it (6.7×)** on the traverse, **3.68 → 2.43 ms/it
  (1.5×)** on the full bench, moving `tree` ahead of node/pypy/luajit into the
  chez/sbcl tier.
- **Stage C — emit the map read probe loop. ✅ LANDED (`8ec459ad`).** Inline `hash()`
  + the linear probe over the backing, accumulate. Allocation-free; the smaller
  absolute prize (scan ~325 us), but it proves "the glaze owns a map read". The
  free-var dependency below was resolved by **`plift`** (`43e29838`): unlike `ck`
  (whose `t` is a clean param), `hash`'s `scan`/`ins`/`bump` **captured `h` and `n`
  as free vars** of the enclosing `:`, not params — `plift` partial-lifts a read-only
  loop (`scan`) out of the nested `:` into a top-level `hash-run_scan(n h i acc)`, and
  the recognizer rewrites that fn's map-valued `(peep h k d)` to `mpeep`, which the
  emitter lays as the native probe (a map-param entry guard deopts a non-map). `ins`/
  `bump` write, so they stay interpreted (Stage D).
- **Stage D — frontier, defer.** Allocation under the collector (`tree`'s `mk`,
  `hash`'s `ins`). Native code that bumps `Hp` must keep the two-space/generational
  invariants — a GC mid-build forwards the half-built structure, and the write
  barrier fires on old→young stores (see [`doc/gengc.md`](gengc.md)). Two routes:
  1. **pre-reserve** one `Have` for a statically-bounded build (a `tree` depth is a
     literal → 65535 cells reserved up front, no GC inside the kernel) — works for
     `mk`, not for data-dependent growth+rehash like `ins`;
  2. **GC-cooperative native** (the kernel publishes roots / is interruptible at safe
     points) — the real method-JIT, a much larger effort.

  Recommend deferring D until B/C have paid.

## Honest ceiling

Stage B bears this out: `tree` moved a full tier (ahead of node/pypy/luajit) but
its **2.43 ms/it still trails chez 1.59 / racket 0.61** — the interpreted build half
(`mk`, 2550 us) is the floor, and Stage B can't touch it (it allocates → Stage D).
Even with B+C the allocation halves stay interpreted, so this alone does **not**
reach chez/racket. The deeper, orthogonal lever is the interpreter **dispatch**
itself — [`doc/proto/interp-spec.l`](proto/interp-spec.l) measured ~7× headroom in
interpretation overhead, and cheaper dispatch (or interpreter specialization) helps
*every* non-glazed bench (`closure`/`sum`/`sort`/…), not just these two. That is the
bigger program; this study scopes the glaze half.

There is also a "do nothing" option that is defensible: the cross-language table is
honest about measuring the abstraction — these rows correctly read as "interpreter
vs compiler," and the rows where ai shines (`fib`/`primes`/`float`/`deforest`) are
the ones it compiles. Closing the `hash`/`tree` gap is a *choice* to widen the
glaze, not a bug to fix.

## Verification

The recognizer model self-checks (`doc/proto/glaze-data.l`, all asserts green via
`out/host/ai doc/proto/glaze-data.l`). **Stage B's gate landed in `ai/glaze/auto.l`'s
own assert block** (run on every glaze load, and by `make test_glaze`): the depth-8
(255-node) chain fold glazes `==` interp and is `=`/`show`-transparent (`respec`,
de-Bruijn `show`), deopting to `ev` on any non-chain; and `(+ (cap t) 0)` is
*rejected* (chain word in an int slot → stays interpreted). When Stage C lands its
kernel joins the same block. A *verified* glaze — a proof that the emitted bytes mean
the ai they claim — remains the separate, larger effort `ai/glaze/README.md` flags
(the place ai's in-tree prover could earn its keep, the same caveat `doc/gengc.md`
raises for the pointer code).

## Not yet / open

- **Stage C — the `hash` scan read. ✅ LANDED** (`plift` `43e29838` + map-read lane
  `8ec459ad`); the `lift` free-var dependency was resolved by `plift`. Next frontier
  is Stage D (the `ins`/`bump` writes — allocation/growth under the moving collector).
- **Chain-guard redundancy (Stage B follow-on).** `ck`'s `cap`/`cup` always sit under
  a `(two? t)` that already proved `t` a chain, so their inline chain-guards are
  redundant — the 6.7× (vs the probe's 11×) is mostly that. A dataflow pass that
  trusts a `cap`/`cup` under a dominating `two?` would close most of the gap.
- **Interprocedural chain params.** `cmask` (and the gate's chain typing) is computed
  *directly* (a param used in `cap`/`cup`/`two?`), like `bufmask` — not the
  interprocedural fixpoint `smask` uses. A param that only *flows* into a sibling's
  chain slot (never touched by `cap`/`cup` itself) is therefore not handled; the gate
  rejects it (sound, just not covered). Fine for `ck` (singleton, direct use).
- **Stage D allocation under a moving collector** is the real work and is
  unscoped here beyond the two routes above; pre-reserved bounded builds are the
  tractable first cut.
- **AArch64 I-cache.** `ai/glaze/README.md` already flags the missing
  `__builtin___clear_cache` after a `toast` writes code; any data-loop kernel
  inherits that caveat until it lands.
- **Measure-before-bake.** The scalar-hook precedent means none of B–D is assumed to
  pay; each is a measurement. Stage B held to it: a hand-emitted probe kernel
  measured the ~11× ceiling *before* the recognizer/emitter were touched, and a
  kernel that doesn't beat `ev` is retracted to the substrate (as the original
  kernels/`opjit` hook were).
