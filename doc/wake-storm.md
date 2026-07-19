# the wake storm — the woken image runs uu ~100× slow, one fault per call

Status: **FIXED at the bake (same day).** The dump now REVERTS dead-native
cells: the absolute-pointer guard names any un-wakeable pointer (a refused
bake beats a storming binary), and `img_nif_interp` re-aims every reference
to a native (nif) cell at its bytecode twin — the interp deopt fallback the
cell already carries — so the husk rides as unreachable ballast and the
woken image runs the honest closure. One survivor existed (a natjit-backed
leaf pinned during the post-glaze boot evals); the revert is CLASS-wide, so
future survivors are handled or loudly refused, never storming. test/uu.l
through the woken image: >90s before, 0.49s after (faster than the fresh
egg, as the image intends); fib/member?/natjit-leaf lanes all healthy at
wake. `make test_wake` is GREEN and wired into test_all. Still open, now
optional hardening: making eat_run's fault recovery stick at RUNTIME (a
storm can in principle still arise from natives created and dangled by
other means; the bake lane is closed).

## the symptom

A **baked** binary (`love --bake`, i.e. `make host` / install / the 07:54 live
binary) runs uu checking ~100× slow: `test/uu.l` alone is **0.92s** on the
fresh-egg lane (`AI_NO_IMAGE=1`) and **>90s** through the woken image — same
binary, same file. Reproduces at HEAD before uu2l and before the day's prel
work (both exonerated by worktree builds); present at least since the uu
kernel joined the boot bake.

**No gate ever sees it**: the Makefile suppresses image auto-load for every
recipe (the corpus must time the fresh egg, not a stale image), so `make test`
and friends run the fresh-egg lane by construction. Only a DIRECT run — a
user at a repl, a script calling the installed `love` — wakes the image. That
is why it survived: green gates, storming users.

## the mechanism, as far as it is pinned

perf on the storming run: ~40% of cycles in `siglongjmp` + `sigprocmask`
(kernel side) — the **fault barrier**, a mask-restoring longjmp costing two
syscalls per trip — the rest ordinary interpreter ops (`lvm_cond`, `lvm_cup`,
`lvm_cap`...). So: **a recovered hardware fault per call**, then the work
happens interpreted anyway, and the next call faults again. Recovery never
sticks.

The only silent-recovery barrier is `eat_run` (love.c) — the wrapper around
running a TOAST's native code; a fault inside answers 0/deopt and the session
rides on. And the image is DESIGNED to carry no native artifacts: the bake
empties the glaze compile cache and `gen_major` drops transient native
closures, "natives JIT lazily on load". The evidence says one escapes the
sweep: **some cell reachable post-wake still holds a toast whose code pointer
aims into the bake process's dead W^X mmap** — every eat faults, the barrier
eats the fault, nobody re-points the cell.

What it is NOT (each killed by measurement):

- not the prel cap/cup commit, not uu2l, not the crew WIP — worktree builds
  at those states are green/fast; a scratch bake at pre-uu2l HEAD storms.
- not "the glaze is missing post-wake": fresh closures glaze fine in the
  woken lane (`fib 27` 1ms both lanes; a natjit leaf 79ms vs 41ms; the
  re-declared native `member?` 10ms vs 6ms — no storm on any of them).
- not the pulled `eat`/`toast`/`nif`/`book` noms (cosmetic: values folded).
- the longjmp caller resolves to static code near `lvm_cmp_ord` — statics
  are thin in the symtab, so read that as "a static in the eval/cmp/eat
  neighborhood", almost certainly `eat_run` itself.

Why uu is the loudest victim: checking is a per-call workload over tiny
steps (conv/vof/chk), so a per-call fault tax multiplies by millions.
Whatever the stale cell backs sits on the checker's hot path.

## fix shapes (history -- the bake-side revert below landed)

1. **Make recovery STICK** (small, love.c / the nif deopt seam): when
   `eat_run` reports a fault, re-point the faulting cell at its deopt
   target permanently (nif cells carry `e`, the bytecode entry, for exactly
   this). Converts any storm of this class into one fault + interp speed.
2. **Audit the bake** (small, host/image.c; the definitive tool): the dump
   already walks the heap to serialize — warn/fail on any reachable
   `toastp` cell. Names the survivor instantly and turns this whole bug
   class into a build error.
3. **Find the survivor** (forensics): with (2) in place this is free;
   without it, walk suspects — the auto.l re-declarations, hook.l's nif
   cells, holo/glaze book internals.

(1) and (2) together are a day-shaped job; (3) follows from (2).

## the gate

`make test_wake` (standalone, NOT in test_all yet — it is deliberately RED
today, pinning this bug): bakes a candidate COPY (`love.wake`, so the canonical
binary is untouched and ETXTBSY can't bite), runs test/uu.l through the woken
image with AI_NO_IMAGE explicitly unset, under a budget the storm cannot
meet (fresh lane ~1s, storm >90s, budget 60s). Wire it into test_all when
the storm fix lands — it is the missing "gates never wake the image" lane.

## durable lessons

- **The in-process summary clock starts at 00-init** — it cannot see boot
  or lane pathology, and a green "N tests pass in 10s" says nothing about
  wall time. Time the wall when a lane is in question.
- **Silence is a lane, not a proof**: every gate ran fresh-egg; the baked
  lane had zero coverage. A knob that make sets globally (AI_NO_IMAGE) is
  a lane split — each side needs at least one gate.
- Profile before theorizing: three plausible mechanisms (heat hooks,
  bake-time natives, bridge guards) died to one perf run + three
  micro-probes (fib / natjit leaf / member?).
