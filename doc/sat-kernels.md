# the sat kernels — a domain-specific compiler over asm/

`sat/flat.l` is the answer to a question: can the in-tree assembler carry a *domain-specific
compiler* — not a general codegen pass, but one app compiling its own hot loops? It can. The
CDCL SAT solver's three hot loops are hand-written in asm/ neutral IR, assembled **at
solver-build time, specialized to the instance** (section displacements baked as immediates,
one kernel set per `nvars`, cached), and installed through the `nif` seam — plus `fbva`,
the extended-resolution factoring ladder, reason-side VSIDS bumping, and the rephase
wheel (below). The result is FIRST in the reference-solver field by net time across all
eleven rows — pigeonhole, threshold random 3-SAT, and real SATLIB instances including
the proven-UNSAT sets (ai 1618, picosat 2047, cadical 2216, kissat 3975): faster than
cadical outright on PHP(5–7), mid-field on the pure random rows (`bench/bench.html`,
second table; `bench/satrace.sh` reproduces it).

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
| PHP(5) | **1** | 3.9 | 2.6 | 3.6 | 4.6 | 4.0 |
| PHP(6) | **2** | 7.5 | 5.0 | 5.5 | 5.2 | 5.8 |
| PHP(7) | **4** | 38.5 | 25.7 | 17.3 | 8.2 | 39.9 |
| PHP(8) | 14 | 266 | 220 | 72.1 | 12.5 | 873 |

first on the pigeonhole net (ai 21, cadical 30.5): faster than cadical outright on
PHP(5–7), 1.5ms behind on PHP(8). first in the whole six-row field by net time
(**ai 156**, cadical 200, picosat 312, kissat 372, minisat 383, glucose 1013).

Where the journey started (interpreted tablet solver, 2026-07-01): ~45× slower than
minisat on PHP(7). The rungs: flatten the state (proves the layout, slower interpreted) →
bcp kernel (~10× over the twin) → learnt-DB reduction + minimization (kills the PHP(8)
superlinear bloat) → conf + dec kernels (the per-conflict path was ~90% of what remained)
→ warm timing + cadence tuning → fbva (131ms on PHP(8)) → restart/decay knob retune on
the factored profile (rarer restarts suit BVA'd pigeonhole: luby unit 100→400; validated
neutral on threshold random 3-SAT) → the tombstone reduce, which made a LEAN learnt DB
affordable (at 12k learnts the watch lists averaged ~140 nodes — 44 watch visits per
propagation; capping at 2000 was a wash before only because each full-rebuild reduction
cost ~11ms of interpreted lisp) → reason-side bumping + the fbva ladder (below), the
pair that closed the last 4× to cadical. Each rung was phase-profiled before it was
built — the clock-delta split of the driver loop (bcp / conf / cold path / dec) found
every whale, and an instrumented twin counting visit categories (satisfied-skip / slide
/ unit / binary) sized the tombstone one.

## reason-side bumping + the fbva ladder (the level-2 story)

Cadical fed our factored PHP(8) factors 16 MORE variables (a laddered commander
hierarchy) and needs only ~1150 conflicts to our ~4000 — so the obvious move was to
replicate its level-2 grouping. The decisive experiment said no: cadical's own
preprocessed formula (dumped via `cadical -c 0 -o`, factor applied, zero search) made
OUR search *worse* (7068 conflicts vs 3967 on our level-1), across the whole knob grid.
The deeper encoding is only better *for a search that can exploit it* — encoding and
heuristics are not separable here.

Which heuristic? Ablate cadical **search-side** on the fixed level-2 encoding
(`--no-factor` + one feature off at a time): `--shrink=0` +61% conflicts,
`--bumpreason=false` +34%, `--stabilize=false` +32% — an ensemble again, but with a
cheapest member. **Reason-side bumping** — every unseen variable in a learnt literal's
reason clause gets `act += vinc` — prototyped in the interpreted twin, then landed in
the conf kernel (phase 3b, between minimize and the seen-clear, where the analysis
marks are still live): PHP(8) drops 3967 → **1547** conflicts on our level-1 encoding
and 7068 → **1152** on cadical's level-2 — matching cadical's own count. One feature
was the entire lock: with it, deeper factoring flips from harmful to helpful, so
`fcdcl` now runs the **fbva ladder** — re-apply the pass on its own output with the
baseline lifted (level-1 aux become "original") while it keeps factoring, capped at 4
levels. An instance with nothing factorable exits after one pass, so the randoms pay
nothing. PHP(8): 1547 → 1408 conflicts; PHP(9) solves in ~34ms warm. The remaining
~20% of encoding quality (cadical's exact groups: contiguous commander merges where
our ladder picks mirrored definitions) is still on the table, as are shrink and
stable/focused alternation on the search side.

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

## the SATLIB rows — real instances, and what they taught

`satrace.sh` also races five rows of REAL benchmark-library instances (SATLIB, the
classic competition-era suite; downloaded once into `out/bench/satlib/`, rows skip
silently offline): uf100/uuf100 (uniform random 3-SAT at the transition, 10 satisfiable
/ 10 proven-unsatisfiable), uuf150 (5 UNSAT), uf250 (3 SAT), flat100 (3 graph
3-colorings). Two traps en route: SATLIB files end in a `%` footer that minisat and
cadical REJECT — the exit-code "solves" at 3ms were parse errors, and the signature
column (`?????`) is what caught it (strip the footer at fetch); and the file naming is
a literal `-0` separator (`uf100-010.cnf`, not `uf100-10.cnf`).

The rows immediately found two whales. flat100 ran 12–20× off the field — all of it
fbva intake: the solver finishes coloring instances in ~3ms with ~0 conflicts, while
the factoring pass paid two full sweeps (and a ladder pass) to find 6 incidental
variables in 300. Both loops now gate on SUBSTANTIAL growth (> nvars/16 fresh vars, one
sweep otherwise): flat100 167 → 45ms, php untouched. And uf250 (SAT instances) ran
seconds with wild per-instance variance — polarity luck, the classic case for
**rephasing**. Always-random rephasing just reshuffles the luck (one instance went
1.2s → 12s); the landed version is cadical's idea in miniature, a **policy wheel** —
random → invert → keep, every 4th restart, phases drawn from a seeded reproducible
stream — which keeps the escapes and dampens the reshuffle: uf250 4.2s → 1.1s, UNSAT
rows and php measurably untouched.

**shrink stayed out.** The all-UIP learnt-shrinking phase (cadical's biggest single
ablation, +61%) was built as a twin phase and measured: −7% conflicts on uuf150, −10%
on uuf100, +15% (worse) on factored php8. Inside cadical's ensemble it's the top
feature; on top of OUR reason-side bump it's a single-digit trade — not worth a kernel
phase. The spike survives with its verdict in `doc/proto/sat-shrink.l` (the stronger
recursive variant is the open follow-up).

## long runs: linear cap growth + the real compaction

uuf250-class instances (100k+-conflict runs) exposed two long-run diseases. The learnt
cap grew ×3/2 PER REDUCTION — geometric, so after thirty reductions the cap is
effectively infinite, the DB balloons, and bcp relives the pre-tombstone watch-list
disease: per-conflict cost degraded 9µs → ~78µs across one run. The cap now grows
LINEARLY (+500 per reduction): uuf250-01 101s → 31s. And the tombstone reducer leaks
dead slabs forever, so `fcompact` — the resurrected compacting reducer — now runs when
the arena top passes `fcmp0` words (1M default): live clauses into a fresh cask,
watches rebuilt (the wn arena's dead nodes leak too), learnt cids remapped, level-0
reasons zeroed. The tombstone write stashes the slab's true length at cid+1 (nothing
reads a dead clause's literals) so the compactor can walk the arena. 31s → 21s.

Two soundness lessons, both now permanently gated (a forced-fcmp0 differential battery
in the corpus, mirroring the forced-reduction one): the old "all-false cannot arise
(propagation was drained)" invariant is FALSE inside the compaction walk itself — a
fact it enqueues can falsify a later clause before bcp ever runs, and that is a
level-0 conflict, i.e. an UNSAT verdict (`s 'bad`), not a scare. And the first shipped
fcompact returned a bogus SAT on uuf250 through a chain worth remembering: a
misplaced closing paren restructured the `res` binding, the one-scope law made every
`res` read the missing condition (`;; missing res`, the always-on warn was the clue),
`(cap ())` flowed into `putw fx 4` as garbage, and the solver searched an empty arena
to a cheerful model. The differential gate at small scale passed throughout — the
compaction only fires past 1M words, hence the forced-threshold gate.

## what the remaining distance is

with the eleven-row net led outright (ai ~1700±100 by uf250's rephase luck, picosat
~2030, cadical ~2230, kissat ~4000), the remaining per-row gaps: picosat/minisat still
lead the small random rows (raw per-conflict engine cost), uuf250-class UNSAT randoms
run ~21s against cadical's ~0.2s (conflict-count class: search quality on long
unstructured refutations — stable/focused alternation and stronger minimization are
the known levers), and cadical keeps php8 by ~1.5ms. all lisp cold-path or
kernel-phase work; the architecture doesn't move.
