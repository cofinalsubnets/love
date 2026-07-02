# the sat kernels — a domain-specific compiler over asm/

`sat/flat.l` is the answer to a question: can the in-tree assembler carry a *domain-specific
compiler* — not a general codegen pass, but one app compiling its own hot loops? It can. The
CDCL SAT solver's three hot loops are hand-written in asm/ neutral IR, assembled **at
solver-build time, specialized to the instance** (section displacements baked as immediates,
one kernel set per `nvars`, cached), and installed through the `nif` seam — plus `fbva`,
the extended-resolution factoring pass (below). The result is SECOND in the reference-solver
field, behind only cadical: faster than kissat on every instance measured, fastest outright
on PHP(5) and PHP(6) (`bench/bench.html`, second table; `bench/satrace.sh` reproduces it).

the lineage: `sat/sat.l` is the readable tablet-based solver and stays the oracle —
`sat/flat.l` runs AFTER it (`cat sat/sat.l sat/flat.l | ai`) and gates differentially
against its DPLL baseline on every load. `make test_sat` runs the whole stack.

## the shape

State lives flat, laid out for `ldx`/`stx` (the authoritative layout comment is at the top
of `sat/flat.l`): one `fx` cask holds the header scalars (top/qhead/level/aru/wvu/vinc) and
the per-variable sections (trail, levels, reasons, watch heads, values, activities, phases,
a seen scratch); two growable casks hold the clause arena and the watch nodes. Literals are
encoded (`+v → 2v`, `-v → 2v+1`, so negation is xor 1); `val[v]` stores the *true encoded
literal itself* (0 = free), making lit-eval one load and one compare. VSIDS activities are
integers — the increment grows ×21/20 per conflict and everything shifts right 8 past 2²⁴,
so decay is a shift and ancient bumps fading to zero is the intended semantics.

Three kernels, each with an interpreted **twin** over the same memory:

* `bcp (fx ar wn)` — two-watched-literal propagation; returns the conflict cid or −1.
* `conf (fx ar wn confl)` — the *whole* conflict: 1-UIP absorption with inline activity
  bumps, self-subsumption minimization compacting the learnt clause in place in the arena,
  glue + backjump level in one pass, the trail pop with phase saving, the learnt commit
  with both watches, the asserting assignment; returns `(cid<<6)|glue`, −1 at level 0.
* `dec (fx)` — highest-activity free variable, saved-phase polarity, assign; 0 means SAT.

Lisp keeps only the cold path: restarts, learnt-DB reduction, and activity decay. The
caller pre-ensures arena room before `conf`; kernels never grow a cask. Reduction is by
**tombstone**: the worst-glue half (glue ≤ 3 immortal) gets its arena size word zeroed at
a level-0 restart, and the bcp walk unlinks a dead clause's watch nodes lazily on the
next visit — no arena compaction, no watch rebuild, so a reduction is O(learnts) lisp
(~1ms) instead of the ~11ms full rebuild it replaced. Dead slabs leak until the solve
ends; that's the price, and `fens`'s doubling keeps the growth geometric. The size-0
check runs FIRST in the walk — an empty scan range would otherwise read a dead clause's
two stale watch slots as a whole clause and fake a conflict. A full DB forces the
restart (reduction is only sound at level 0), tracked by an O(1) learnt counter.

## the kernel contract (reusable for any nif kernel)

* `(nif code interp src arity)` installs machine bytes as an applicable value. lvm ABI:
  g=rdi, Ip=rsi, Hp=rdx, Sp=rcx; params arrive TAGGED at `Sp[i]` in source order.
* Guards first, pushes second: a cask param is `test 1` (fixnum → deopt) then its ap word
  against `(apof (cask 1))` as a movabs immediate; its bytes sit at `[[v+8]+16]`. Because
  every deopt fires *before* any push, the machine sp is balanced on every path, which is
  what makes callee-saved registers (r3, r11–r14) usable with plain push/pop.
* Epilogue: tag the result (`shl 1; or 1`), store to `Sp[0]`, `Ip += 16`, jump — that lands
  on `lvm_ret` in the value cell. Deopt (arity ≥ 2): load `[Ip+8]` (the interp fallback),
  enter its body — the args are still on Sp, so the twin resumes seamlessly.
* The twin IS the spec, phase for phase, and three things at once: the deopt fallback (so
  native is never wrong), the portability path (arm64, or any image where the egg mopped
  `nif` — kernels build only under `(lit? nif)` and arch x64), and the differential oracle:
  the `fknob` box forces all twins, and the gate asserts kernels ≡ twins verdict for
  verdict on top of the 150-instance fuzz against DPLL.
* Specialization is cached (`fkers`, keyed by nvars) and costs ~30ms once per size. Time
  solves WARM — `satrace.sh` pre-warms `(fbcpk (php-vars h))` outside its clock, exactly as
  it already excludes interpreter warmup. (Every scoreboard before 2026-07-02 charged
  assembly to the solve; don't repeat that.)

## the numbers (warm, all shootout verdicts correct)

| ms | ai | minisat | picosat | kissat | cadical | glucose |
|---|---|---|---|---|---|---|
| PHP(5) | **1** | 4.0 | 2.8 | 3.7 | 4.6 | 4.4 |
| PHP(6) | **3** | 7.4 | 4.7 | 5.7 | 5.5 | 6.0 |
| PHP(7) | **11** | 40.1 | 26.0 | 18.2 | 8.6 | 42.8 |
| PHP(8) | **54** | 281 | 233 | 75.2 | 12.0 | 921 |

second in the whole field by net time (cadical 31, **ai 69**, kissat 103, picosat 266,
minisat 332, glucose 970) — faster than kissat on every instance, behind only cadical.

Where the journey started (interpreted tablet solver, 2026-07-01): ~45× slower than
minisat on PHP(7). The rungs: flatten the state (proves the layout, slower interpreted) →
bcp kernel (~10× over the twin) → learnt-DB reduction + minimization (kills the PHP(8)
superlinear bloat) → conf + dec kernels (the per-conflict path was ~90% of what remained)
→ warm timing + cadence tuning → fbva (131ms on PHP(8)) → restart/decay knob retune on
the factored profile (rarer restarts suit BVA'd pigeonhole: luby unit 100→400; validated
neutral on threshold random 3-SAT) → the tombstone reduce, which made a LEAN learnt DB
affordable (at 12k learnts the watch lists averaged ~140 nodes — 44 watch visits per
propagation; capping at 2000 was a wash before only because each full-rebuild reduction
cost ~11ms of interpreted lisp). Each rung was phase-profiled before it was built — the
clock-delta split of the driver loop (bcp / conf / cold path / dec) found every whale,
and an instrumented twin counting visit categories (satisfied-skip / slide / unit /
binary) sized this last one.

## the random rows (rnd100 / rnd150), and what they guard

`satrace.sh` also races random 3-SAT at the threshold (m = 4.26n, five fixed-seed
instances summed per row) — raw search with NO factorable structure, the standing guard
against tuning the solver into a pigeonhole specialist. The instances come from ai's own
explicit-state RNG (`seed`/`random`, reproducible), and ONE generator text feeds both the
DIMACS dump and ai's in-process lane, so every solver provably sees identical instances;
the verdict column carries the per-instance SAT/UNSAT signature, which matches across all
six solvers on every run — a free differential check against five references. The two
families pull opposite ways: cadical and kissat own PHP but their inprocessing machinery
costs them the small random instances (dead last there), where the light classics
(picosat 19/42ms, minisat 22/47) lead; ai places second on PHP and mid-field on random
(30/78), the most even spread in the table. NB the in-tree `gen-formula` (sat.l's fuzz
generator) is NOT a threshold generator: its LCG draws the literal sign from the low bit,
which strictly alternates, so its instances are structurally easy and satisfiable far past
the classic ratio — fine as a differential-fuzz driver (DPLL referees), useless for
difficulty calibration. The bench generator draws each (var, sign) independently from
xoshiro.

## the watcher-vector experiment (built, measured, kept out)

The full minisat watcher architecture — per-literal contiguous vector segments, blocking
literals, an in-watcher binary-clause lane, swap-remove slides, newest-first backward walk,
grow-by-clean-abort — was built, gated green, and measured against the intrusive-node
design, warm, both ways: nodes win everywhere here (PHP 4/42/980 vs 6/57/981; random 3-SAT
n=1000: 12–13ms vs 22ms). CDCL slide churn is constant and an O(1) node relink beats
vector growth machinery; a blocking literal only pays when a touched clause is *already*
satisfied, which conflict-storm propagation rarely grants. The spike survives with its
verdict in `doc/proto/sat-watcher-vectors.l` — a sound base if a blocker-friendly workload
(high satisfied-visit rates, e.g. large industrial SAT instances) ever shows up.

## fbva — the factoring pass, and how it was found

Ablating cadical itself (probe the binary, never trust a prior) located the pigeonhole
killer: with **every** technique disabled except `factor`, cadical solves PHP(8) in 14ms;
add `--no-factor` and it collapses to minisat-class. Factoring is **bounded variable
addition** — introduce a fresh variable to stand for shared clause structure — and adding
definitional variables is the *extended resolution* move: PHP has polynomial ER
refutations (Cook 1976) where plain resolution — and therefore ANY amount of clause
learning — is provably exponential (Haken 1985). Cadical doesn't search pigeonhole
faster; it re-encodes it into a proof system where the search is easy. (Beware the
ablation trap en route: single-flag ablations all read "no effect" because the ensemble
is redundant, and one invalid option — `--preprocessing=1` — produced 3ms "results" that
were the error path. Check exit codes.)

`fbva` (sat/flat.l) is the Manthey–Heule–Biere greedy: for a literal l, grow M_lit ×
M_cls with every (m | C\{l}) present, then a fresh x replaces |M_lit|·|M_cls| clauses
with |M_cls|+|M_lit|+1. Three details carried ALL the value, found by diffing our
factored output against cadical's (decoded from its binary DRAT proof — the added
definitional clauses are right there):
* **structured tiebreaks**: on symmetric instances every match count ties, and a
  hash-order pick yields ragged overlapping groups that HURT search (they slowed even
  cadical 2.5× when fed our early output). Max count, ties to the lowest literal →
  contiguous groups → the commander/AMO-tree structure. This one change took our PHP(8)
  from 2713ms to 120ms — the entire prize was in the tiebreak (the "structured" in
  structured reencoding).
* **complete definitions**: emit the reverse long clause (x | ¬m₁ | … | ¬mₖ) too, so
  x ↔ AND(M_lit) propagates both ways instead of leaving x free for CDCL to wander on.
* **no aux cascade**: factor the original structure only (`fbvac0`); re-factoring the
  definitional clauses tangles instead of laddering (measured ~9× worse).

Soundness rides the existing discipline: equisatisfiable both ways (resolving on x
recovers every original; a model extends by x := AND(M_lit)), models project by dropping
vars > nvars, and the whole differential gate — 150 fuzzed instances vs DPLL, #SAT ==
Lucas — flows through the pass since `fcdcl` runs it by default (`fbva0` pins it off).
`fmk` lays the solver out for a power-of-2 variable bucket so the kernel cache survives
BVA's varying variable counts (phantom vars are sound: never watched, decided dead last,
popped clean). Cost on unstructured instances: ~8µs/clause of intake, the floor of an
interpreted pass.

## what the remaining distance is

cadical (12ms) on PHP(8), against our 54. On our own factored instance cadical-sans-factor
needs 3433 conflicts to our ~4000, so the conflict-count gap is nearly closed; what's left
is per-conflict propagation cost (its ~6µs against our ~10) and a second factoring level:
cadical fed our factored output factors 16 MORE variables (a laddered commander hierarchy)
and drops to 1142 conflicts. Both of our naive attempts at depth — a free aux cascade, and
re-running the whole original-only pass on its own output — made search WORSE (973ms and
251ms respectively), so cadical's inprocessing-scheduled level-2 grouping is doing
something our one-shot greedy doesn't; that, chronological backtracking, and
stable/focused mode switching are the open solver-research rungs, all lisp cold-path
work now that the hot path is native.
