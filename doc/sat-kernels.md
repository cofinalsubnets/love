# the sat kernels — a domain-specific compiler over asm/

`sat/flat.l` is the answer to a question: can the in-tree assembler carry a *domain-specific
compiler* — not a general codegen pass, but one app compiling its own hot loops? It can. The
CDCL SAT solver's three hot loops are hand-written in asm/ neutral IR, assembled **at
solver-build time, specialized to the instance** (section displacements baked as immediates,
one kernel set per `nvars`, cached), and installed through the `nif` seam. The result runs
with the reference C solvers: fastest in the field on PHP(5) and PHP(6), within ~10% of
minisat on PHP(7), ahead of glucose on PHP(8) and on net time (`bench/bench.html`, second
table; `bench/satrace.sh` reproduces it).

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

Lisp keeps only the cold path: restarts, learnt-DB reduction (worst-glue half dies at a
level-0 restart, glue ≤ 3 immortal, survivors compact by `pour`), and activity decay. The
caller pre-ensures arena room before `conf`; kernels never grow a cask.

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
| PHP(5) | **1.0** | 4.4 | 2.8 | 3.8 | 5.1 | 4.2 |
| PHP(6) | **4.0** | 8.0 | 5.3 | 6.7 | 5.6 | 6.6 |
| PHP(7) | 45–56 | 41.6 | 28.1 | 19.0 | 8.9 | 43.3 |
| PHP(8) | 882–888 | 283 | 234 | 75.8 | 13.3 | 928 |

Where the journey started (interpreted tablet solver, 2026-07-01): ~45× slower than
minisat on PHP(7). The rungs: flatten the state (proves the layout, slower interpreted) →
bcp kernel (~10× over the twin) → learnt-DB reduction + minimization (kills the PHP(8)
superlinear bloat) → conf + dec kernels (the per-conflict path was ~90% of what remained)
→ warm timing + cadence tuning. Each rung was phase-profiled before it was built — the
clock-delta split of the driver loop (bcp / conf / cold path / dec) found every whale.

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

## what the remaining distance is

Look at cadical's column: 5.6 → 8.9 → 13.3ms while every other solver goes exponential.
That is not execution speed — its inprocessing *dissolves* pigeonhole structure instead of
searching through it. The engine here is done; the spread that remains is solver research,
in rough order of leverage: inprocessing (vivification, bounded variable elimination,
subsumption), recursive learnt-clause minimization (ours is one-level self-subsumption),
finer clause-DB management (activity/tier-based deletion vs glue-halving at restarts), and
restart/phase policy. All of it would live in the lisp cold path — which is exactly where
that kind of logic belongs now that the hot path is native.
