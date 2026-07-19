# Unifying the analysis & rewrite layers

Status: in progress (2026-06-30). Step 1 landed + `dechurch` ("rule #1") landed; steps 2–4
pending. Probe the binary before trusting any claim here — the passes it describes are live
and `make test` green.

Landed so far:
- `dechurch` (commit `3fcdc9ec`) — the canary peephole, below. `(N f x)` with a function
  operand → `f^N(x)` at compile time, so idiomatic church (`(2 (+ i) i)`) glazes instead of
  riding `num-ap`/interp.
- **Step 1 — COMPLETE.** All four of the compiler's monotone fixpoints now run on one harness,
  `(monofix st step size)` in prel (below every consumer; survives the egg mop). Commits:
  `9cf27181` (`smfix` + `ho-fix`, the ascending fact-maps), `8e460f5d` (generalized to the
  whole-transformer form + folded `gfix`, the descending candidate-set), `950b1181` (the
  interpreter's in-place-mutating closure-capture fixpoint, via snapshot-before-step). One
  driver, four lattices: ascending/descending/mutating. Pure refactor throughout, gate green
  (2717×3, love0 included — it bootstraps through the capture code). This proves the harness leg
  of the plan end-to-end; steps 2–4 (fact table, kinds.l abstract interp, datalog.l rewrites)
  build on it.

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

**(B) One fixpoint harness.** ✅ the driver exists — `monofix` (prel) hosts all four
(`ale:propagate`/`gfix`/`smfix`/`ho-fix`), each a monotone chain with its own measure
(`capsize`/`tally`/`sm-size`/`ho-sz`), ascending or descending or mutating. What's still future:
running them **interleaved** over the shared lattice (A) — strictly *more precise* (string-ness,
HO-ness, int/value typing cross-inform), not just less code. Today they're still separate
passes that happen to share the engine.

**(C) One rewrite engine — wire `datalog.l`'s guarded rewriting. RETIRED (2026-06-30, decided
against).** The idea was to make `debool`/`dechurch`/`dehof`-inline/`fold-consts`/`delet`/
`defoliate` guarded rewrite rules over a unify engine. On inspection it doesn't pay off, for the
same reason warn-kinds and kinds.l-devirt didn't:
- There is no proliferation of uniform rewrites to engine-ify. The trivial peepholes a rule engine
  could subsume (`debool`/`dechurch`/`fold-consts`/parts of `delet`) total ~40 lines of clear
  structural code; the heavy passes (`loopclose` = finite differences, `autospec`/`mix` = partial
  eval, `defoliate` = deforestation) are ALGORITHMS, not pattern→template rewrites, and wouldn't
  fold into a rule table at all.
- The engine's machinery (a unify matcher + rule table + saturation/termination control) would
  EXCEED what it replaces — more code and more subtlety, i.e. added fat.
- Prior evidence it backfires: `ev.l` already had a unify-table rewrite (`cflip` via `firstr` over a
  `cflip-rules` global) and it BROKE the egg's self-compile — backed out for a direct structural
  rewrite (see ev.l's cflip comment). A unify-driven rewrite engine in the bootstrap compiler has
  bitten once.
`unify`/`walk` stay where they earn their keep: the live, tested **kanren** engine (`test/kanren.l`).
`dechurch` stands as the counter-proof — when a genuinely useful rewrite appears, it is ~15 clear
lines as a peephole, cheaper than the engine that would generalize it. (A unify+`monofix` engine
WOULD be coherent in the other direction — extending kanren toward full Datalog, a user-facing
feature — but that is a "want a Datalog" decision, not compiler plumbing.)

What collapses out: ~4 purity + ~4 arity + ~4 constant detectors → 1 each; 5 substitutions → 1;
3 betas → 1; 4 fixpoints → 1 harness; `warn-kinds` → the real lattice; parallel
`groupok?`/`vok?`/`cok?` → one call-arg typechecker over the type lattice.

DON'T touch: the IR/codegen lanes (`cggir`, the float grids, `loopcode`) — downstream of all
analysis, orthogonal.

## Sequencing (de-risked — no big-bang)

1. **Merge the fixpoints into one harness.** ✅ DONE — all four. `(monofix st step size)` lives
   in prel (below every consumer, survives the mop). `smfix`+`ho-fix` (`9cf27181`), then a
   generalization to the whole-transformer form + `gfix` (`8e460f5d`, the descending
   candidate-set), then `ale:propagate` (`950b1181`, the interpreter's in-place-mutating
   capture fixpoint, via measure-snapshot-before-step). One driver, four lattices
   (ascending/descending/mutating), proved with zero analysis risk on already-sound code. The
   one remaining int/value fixpoint, `grpfix`, is just `gfix`'s caller (already on monofix).
2. **Collapse the re-derived facts onto shared derivations, then a fact table.** Shared facts
   live in **prel** (chosen 2026-06-30, like `monofix` — prel additions aren't mopped, so no
   egg-mop-list growth). Done: **constant-ness** — one `kconst` (prel) returns `(1 . value)` for a
   constant form else `()`; feels' `cval`, cprop's `propk?`, wxc's `cst` are all projections of
   it (was 3 copies across 3 scopes). Gotcha learned: a prel helper must use only earlier-defined
   prel names — `&&`/`||` are macros defined late, so use nested `?` (a forward macro hangs the egg).

   **The table over-counted.** On close inspection the other rows do NOT flat-collapse like
   constant-ness did, so they were NOT forced:
   - *purity* is already layered on the shared `pureset` (`pure-head?`/`allp`/`pbody?` compose
     it — not copies); the glaze's `roalloc` is a different-policy denylist and `dcheap?` the
     stricter cheap-and-pure subset.
   - *arity* reads genuinely different sources — `opof` peeks a nif's C-struct, `farof`/`falook`
     walk the scope chain, the glaze counts param-lists.
   - *occurrence* — `occurs?`/`dcount` differ only as boolean-vs-count and unifying loses
     `occurs?`'s short-circuit (hot path); `fvs` is binder-aware (a different computation).
   The one genuine remaining flat-copy was a *combinator*, not a fact: `filter` was triplicated
   (prel `filter` + identical `afilter` in auto.l + `gfilt` in emit.l) — collapsed onto prel
   `filter` (`ace79465`). So substitution (`dsub`/`subst-sym`/`subst-call`/`bsub`/`rewrite`) is
   the same story: several are genuinely different (capture-avoiding `bsub`, call-rewrite
   `subst-call`, unify-based `rewrite`); only `subst-sym`≈`dsub` are near-equal (same scope).

   REMAINING on-track work: the per-node memoized fact table (query sites read it instead of
   re-walking — the real structural win), which naturally leads into step 3.
3. **Devirt / `kinds.l` abstract interpretation.** FINDING (2026-06-30, after removing
   `warn-kinds`): devirt — "skip the generic NxN dispatch when operands are provably numeric" — is
   ALREADY realized for the hot path by the glaze. The native group lane emits raw machine
   arithmetic (the devirtualized path itself), and the glaze already runs a purpose-built kind
   inference, `fty` (auto.l), to pick the int-vs-float lane. Crucially `fty` is NOT a clean
   projection of the kinds.l lattice: its `I/F/0` types encode CODEGEN SOUNDNESS, not pure kind —
   the `0`-reject for value-dependent int/int division, and `allsafe`'s "when is the param floated"
   (the 2^53 bignum-divergence guard) are float-lane concerns a generic lattice doesn't model.
   Forcing `fty` (or the recognizers) onto kinds.l would be fragile edits to load-bearing
   soundness logic for ~zero gain. A NEW kinds.l devirt would therefore only target the
   INTERPRETER's cold path — marginal: the C core already has a both-fixnum fast path, and every
   hot numeric loop is glazed. So **`kinds.l` stays parked** (it remains a documented spike) and
   devirt is considered DONE-by-the-glaze. `warn-kinds` (the only shipped consumer, a red-framed
   lint) was removed (`5c341c16`) rather than upgraded — see the philosophy note below.

   `warn-kinds` removal rationale: ai is fully generic and TOTAL — an undefined op combination
   returns `()` (the +/* unit, which VANISHES in a chain), so there is no "wrong kind". A lint
   that flags "this is `()`" frames in the RED in a green-framed language and presumes intent. Off
   by default, never earning its keep → trimmed.
4. **Rewrite engine (C): RETIRED** — decided against (see (C) above). Few distinct rewrites, engine
   machinery exceeds the payoff, and a prior unify-table rewrite broke the egg. Peepholes stay
   peepholes.
5. Delete dead duplicate helpers as each is orphaned.

## Outcome (2026-06-30)

The genuine wins landed: step 1 (one `monofix` for all 4 fixpoints), step 2 (constant-ness onto
`kconst`, the `filter` triplication collapsed), `dechurch`, and removing `warn-kinds`. The doc's
bigger ambitions — the fact table / kinds.l devirt (step 3) and the datalog rewrite engine (step 4)
— were found NOT to pay off on this codebase and were retired with rationale: the glaze already
devirtualizes the hot path with purpose-built soundness analyses, and there is no proliferation of
uniform rewrites to engine-ify. The honest negative results are part of the value. Reminder: this
doc is a plan/narrative — **only the binary is authoritative; probe it before trusting any claim here.**

## `dechurch` (the canary)

Sound prototype validated: `(2 (+ i) i)` → `(+ i (+ i i))` (3i), `(3 ..)` → 4i, `(2 dbl 5)` →
20; `(2 i)`/`(2 5)` correctly NOT expanded (power, not compose — disambiguated by
"operand is a function": a lambda or a partial of a dyadic op). LANDED as a ~15-line peephole
(`3fcdc9ec`); it would have been one rule in the (now-retired) engine (C), but ~15 clear lines is
cheaper than the engine — which is exactly the argument for retiring (C). The win — makes idiomatic
`(2 (+ i) i)` go native, where today church is opaque
to the glaze and stays interpreted ~15-25 ms/it), tagged "rule #1" for (C).

Caveat church can't otherwise glaze: every church application dispatches through the lisp
`num-ap` closure (`lvm_numap` → `numap_drive` → closure). `dechurch` sidesteps that by lowering
the literal-numeral case to arithmetic at compile time; a variable count still goes through
`num-ap` (cached compose-combinators, prel.l, ~2-3.7x over the old per-call thread rebuild).
</content>
</invoke>
