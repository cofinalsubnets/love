# Unifying the analysis & rewrite layers

Status: in progress (2026-06-30). Step 1 landed + `dechurch` ("rule #1") landed; steps 2–4
pending. Probe the binary before trusting any claim here — the passes it describes are live
and `make test` green.

Landed so far:
- `dechurch` (commit `3fcdc9ec`) — the canary peephole, below. `(N f x)` with a function
  operand → `f^N(x)` at compile time, so idiomatic church (`(2 (+ i) i)`) glazes instead of
  riding `num-ap`/interp.
- **Step 1** (commit `9cf27181`) — `smfix` + `ho-fix` factored onto ONE shared
  monotone-fixpoint harness, `monofix info st step size` in emit.l (the shared glaze layer).
  Proves "one driver, many lattices" on already-sound code. Pure refactor, gate green.

## Why

The compiler grew a dozen analysis/rewrite passes that compose correctly but **re-derive the
same facts independently**, and two principled substrates (`kinds.l` abstract domain,
`datalog.l` rewrite engine) were built and parked. Every new optimization (the `ho-fix`
higher-order analysis, `dechurch` church-numeral lowering) is another hand-rolled peephole
re-deriving purity/arity/arrow-ness instead of consulting a shared analysis. This doc maps the
terrain and proposes consolidating onto **one analysis pass + one fixpoint harness + one rewrite
engine**.

This is a multi-session core refactor. The risk is the shared abstract interpretation (a wrong
product-lattice on a self-hosting compiler is a wrong answer *everywhere*), so the sequencing
below validates each idea on code that already works before extending it.

## The map

PRINCIPLED (sound fixpoints / abstract analysis — keep the algorithms):
- `ale:propagate` (ev.l) — mutual-recursion capture fixpoint.
- `autospec`/`mix`, `loopclose`/finite-differences, `defoliate`/forest fusion — the wired
  glaze passes whose standalone specs live in `doc/proto/{mix,close,forest}.l`.
- `grpfix` (int/value type fixpoint), `smfix` (string/map/cask param fixpoint, emit.l),
  `ho-fix` (higher-order fixpoint, auto.l).

AD-HOC STRUCTURAL PEEPHOLES: `opfix`, `boxfix`, `wx`/`wxc`/`cflip`, `fold`, `fold-consts`,
`debool`, `delet`, `lift`, `plift`, the recognizers (`exprp`/`qual`/`groupok?`/`vok?`/`cok?`/
`loopinfo`), `dehof`'s `ho-lamb?` gate, `dechurch`.

PARKED (the genuinely-unwired substrates):
- `doc/proto/kinds.l` — a real abstract-domain kind lattice with a seminaive fixpoint AND
  devirt (skip the generic NxN dispatch on proven-numeric sites). Only `warn-kinds` (prel.l)
  shipped — a single forward pass, no fixpoint, no devirt: a linter.
- `doc/proto/datalog.l` — guarded relational rewriting on `unify`. Only `unify`/`walk`/`reify`
  landed in prel; the rewrite/saturation half is unused.
- `doc/proto/cfinite.l` — would supersede `close.l` (matrix-power closed form for linear-state
  loops like fib/pell, not just polynomial). Separate product call.

Note: the proto files are mostly the *specs* of wired passes, not dead code. The fat is
INTERNAL to the live passes, plus the two parked substrates.

## The actual fat — re-derived facts, not redundant passes

| fact | re-derivations | where |
|---|---|---|
| purity | ~4 | `feels:pureset`; `cprop:pure-head?/allp/pbody?`; `dcheap?` (debool+delet); `uses-head?/roalloc` (plift+delet) |
| arity | ~4 | `feels:opof`; `cprop` param-count; `ale:farof`; `ana:falook` |
| constant-ness | ~4 (≈identical) | `feels:cval`; `cprop:propk?`; `wxc:cst`; `fold-consts` |
| occurrence / free-vars | 7+ | `occurs?`; `dcount`; `cprop:fvs`; `ale` inline ref-detection |
| substitution | 5 engines | `dsub`; `subst-sym`; `subst-call`; `bsub`; prel `rewrite` |
| beta reduction | 3 | `cprop:beta`; `dsimp`; `mix` |
| monotone fixpoint | 4 harnesses | `ale:propagate`; `gfix`; `smfix`; `ho-fix` |

## Proposal — three shared substrates

**(A) One analysis pass — wire `kinds.l` as a PRODUCT lattice.** Each node carries
`(value-kind · purity · arrow/HO · constant-ness · string/map/cask-ness)`. Run kinds.l's
seminaive fixpoint once → a per-node fact table. Then:
- `warn-kinds`, `ho-fix`, `smfix`, `grpfix`'s int/value typing become **projections**.
- `dcheap?`/`propk?`/`cval`/`pure-head?`/`occurs?` become **table queries**, not walks.
- New win: **devirt** — the dispatch-table skip on proven-numeric sites that `warn-kinds`
  never delivered.

**(B) One fixpoint harness.** `ale:propagate` + `gfix` + `smfix` + `ho-fix` are the same
monotone-ascending shape with different measures (`tally`/`sm-size`/`ho-sz`). One worklist
driver parameterized by lattice (A), run **interleaved** — strictly *more precise* (string-ness,
HO-ness, int/value typing cross-inform), not just less code.

**(C) One rewrite engine — wire `datalog.l`'s guarded rewriting.** `debool`, `dechurch`,
`dehof`-inline, `fold-consts`, `delet`, `defoliate` are all *guarded rewrite rules* whose guard
is a query against (A). As a rule-set, `dsub`/`subst-sym`/`subst-call`/`bsub`/`cprop:beta`/
`dsimp`/`mix`-substitution collapse to one substitution + normalization.

What collapses out: ~4 purity + ~4 arity + ~4 constant detectors → 1 each; 5 substitutions → 1;
3 betas → 1; 4 fixpoints → 1 harness; `warn-kinds` → the real lattice; parallel
`groupok?`/`vok?`/`cok?` → one call-arg typechecker over the type lattice.

DON'T touch: the IR/codegen lanes (`cggir`, the float grids, `loopcode`) — downstream of all
analysis, orthogonal.

## Sequencing (de-risked — no big-bang)

1. **Merge `ho-fix` + `smfix` into one fixpoint harness.** ✅ DONE (`9cf27181`): the shared
   `monofix info st step size` lives in emit.l; both fixpoints are now projections. Both
   already sound and the right shape — proved "one driver, many lattices" with zero new
   analysis risk. Pure refactor. NEXT: fold `gfix`/`grpfix` and `ale:propagate` onto it too
   (they cross file/layer boundaries — `ale:propagate` is in ev.l, the interpreter layer, so a
   truly-shared driver may want to live lower than emit.l).
2. **Add a fact table; move the QUERY sites** (`dcheap?`/`propk?`/`cval`) to read it — pass by
   pass, each contained, gate-checked.
3. **Extend the lattice to the real `kinds.l` abstract interpretation + devirt** (the
   high-value, high-risk step), with the harness from (1) as its engine.
4. **Rewrite engine (C):** start with trivial peepholes (`debool`, `dechurch`, `fold-consts`)
   as rules; leave `loopclose`/`mix` algorithms intact but consulting (A).
5. Delete dead duplicate helpers as each is orphaned.

## `dechurch` (the canary)

Sound prototype validated: `(2 (+ i) i)` → `(+ i (+ i i))` (3i), `(3 ..)` → 4i, `(2 dbl 5)` →
20; `(2 i)`/`(2 5)` correctly NOT expanded (power, not compose — disambiguated by
"operand is a function": a lambda or a partial of a dyadic op). As a peephole it's ~15 lines; in
(C) it's ONE rule `(N f) → compose^N f` guarded by `arrow(f)`. Recommendation: land it now as
the peephole (real win — makes idiomatic `(2 (+ i) i)` go native, where today church is opaque
to the glaze and stays interpreted ~15-25 ms/it), tagged "rule #1" for (C).

Caveat church can't otherwise glaze: every church application dispatches through the lisp
`num-ap` closure (`lvm_numap` → `numap_drive` → closure). `dechurch` sidesteps that by lowering
the literal-numeral case to arithmetic at compile time; a variable count still goes through
`num-ap` (cached compose-combinators, prel.l, ~2-3.7x over the old per-call thread rebuild).
</content>
</invoke>
