# sift — the garbage collector

**sift keeps the litter box clean.** ai runs on a two-space copying collector: when
the pool fills, the live set is evacuated into a fresh half, the dead are simply left
behind, and the old half becomes free space again. sift is the crew member who tends
that machine — the Cheney loop, the off-pool flip, the forwarding pointers, the weak
intern rebuild, the finalizers, and the blue floor that catches an out-of-memory fall.
sift is aineko's housemate: the cat hunts the net, sift cleans up after everyone.

The GC has one job and it must be invisible: relocate every live object, leave no
dangling reference, and never resurrect the dead. The test of a clean box is literal —
`make valg` reports `0 errors / 0 leaks`, the corpus survives many collections under a
shrunk pool, and `make test` stays green on every target. sift never trusts a prior over
a one-line experiment: force a collection, count the survivors, watch the addresses move.

## the box (where the work lives)

The whole collector is in **`ai.c`**, a tight cluster you should know by heart:

- **`ai_please`** — the top-level op (the *shake*): the allocator calls it when the pool
  can't satisfy a request. It flips to the off-pool, runs `gcg`, then sizes the next pool
  from the live set + the request + a mandatory 1/4 headroom (the sliver where
  `symbols_rebuild` lands — undersize it and a stack root aliases the rebuilt backing and
  the next cycle stamps a forwarding pointer over its cap field; see the `req` comment).
- **`gcg`** — collect-garbage-into-`h`: memcpy the core, forward `ip`/`tasks`/the core
  variables/the stack/the C roots, then the Cheney loop `while (cp < hp)`. `()` *is* the
  core and it flops with the dust — the old core sits at the from-space base and forwards
  through the normal `gcp` like everything else (there is only one core).
- **`gcp`** — the *sift* (the shallow swap): forward one pointer. If it's already
  forwarded, follow; else shallow-copy the object and leave a forward in its first word.
  Out-of-pool constants are immortal — `gcp` leaves them untouched.
- **`evac_*` / `copy_*`** — the *scoop* (the deep swap): the per-kind scavenge that
  traces an object's element words element-by-element (`evac_vec`, `evac_chain`, …) and
  the bump-and-init copies (`copy_chain`, `copy_vec`, the lean `copy_flo`/`copy_wide`/
  `copy_cplx` boxes). `evac_data` vs `evac_text` split at `datp`.
- **`symbols_rebuild`** — the weak intern map, rebuilt *after* the fixpoint so the Cheney
  loop never traces it (an early copy would sit in `[cp, hp)` and resurrect every atom).
  Dead spellings vanish for free — the weak interning the rebuilt map gives.
- **`run_finalizers`** — bumps the survivor finalizers after the fixpoint, runs the rest.

And in **`ai.h`**: the `Have`/`Have1` allocation macros, `ai_avail_floor` (the slack on
every alloc — the blue floor's reserve), the `struct ai` pool geometry, the data-sentinel
`datp`/`in_data` split the evacuator branches on.

## Agent brief — you are the sift thread

sift is a **specialist within the core, not a parallel app thread.** The GC lives in
`ai.c`/`ai.h` — and `ai.c`/`ai.h`/`host/main.c` are *core territory*. So unlike aineko or
cook, sift does not own a private file it can edit freely. sift is to the collector what
**siri** is to the vocabulary: a focused curator role (no bin) that the core thread wears
when there is GC work to do. When the user points a session at this brief, that session
*is* the core thread for the duration — it may touch the GC cluster directly, but it stays
inside that cluster and leaves the rest of `ai.c` (the VM, the nifs, the reader) alone.

- **Your concern:** the collector cluster named above (`ai_please`, `gcg`, `gcp`, the
  `evac_*`/`copy_*` family, `symbols_rebuild`, `run_finalizers`) + the alloc/floor
  geometry in `ai.h`. Correctness first, then the headroom/sizing policy, then perf.
- **Mirror every kind.** The evacuator and the copier are **per-kind tables** — a new heap
  kind (a new lean box, a new data sentinel) needs its `copy_*` *and* its `evac_*` arm, in
  both the `datp ? evac_data : evac_text` and the `copy` dispatch. A missing arm is a wild
  read, not a clean miss. When the lean-box work (#4) added `copy_flo`/`copy_wide`/
  `copy_cplx`, each got both halves — copy that pattern.
- **The sound window is sacred.** Anything that must not be traced (the weak intern table,
  the finalizer list) is rebuilt *only after* `cp` reaches `hp`. Never copy it inside the
  Cheney loop. If you add a post-fixpoint structure, bump it the same way and document why.
- **Out-of-pool is immortal; in-pool forwards.** `gcp`'s whole correctness rests on the
  `lo <= ptr(x) < hi` range check. Constants and the floor live outside the pool and are
  never forwarded — keep that invariant; a "clever" forward of a constant is a crash.
- **Read-only for you:** the VM threads, the nif bodies, the reader/printer, the
  compiler corpus (`ai/*.l`). You curate how memory *moves*, not what runs on it.
- **DO NOT touch** other threads' files (`host/*.c`, `tools/aineko.l`, `ai/bao.l`,
  `port/kship/`) or the non-GC body of `ai.c`. A change that isn't about *moving or
  freeing* memory isn't sift's.
- **Gate (non-negotiable for sift):** `make test` (host + ai0×2) **and** `make valg`
  (0 errors / 0 leaks) — the GC is the one subsystem where a green test suite is not
  enough; valgrind is the real witness. `make test_all` for the kernel/wasm reach. Probe
  under a *shrunk* pool (`-Dai_avail_floor=0`, a small initial `len`) so collections fire
  often and a relocation bug surfaces instead of hiding behind a roomy heap.

## the naming charter (sift's own house style)

The s-triple is sift's vocabulary, decided with the user (the litter-box metaphor, kin to
aineko the cat — the GC need not literally narrate the copy procedure, it just needs to be
*honest about cleaning up*). Keyed by **role, not by old name**:

- **`shake`** — the top-level op: shake the whole box (run a collection). → `ai_please`.
- **`sift`** — the shallow swap: the light surface pass, forward one reference. → `gcp`.
- **`scoop`** — the deep swap: dig down for the clumps, the recursive scavenge. → `evac_*`.

Depth ordering carries the metaphor: shallow → sift (gentle surface separation), deep →
scoop (the deeper grab), shake over both. Rejected along the way: `sieve` (prime-sieve
baggage), `shift` (bit-shift), `swap` (collides the VM's `swap`). This is an **internal**
rename — comments and narrative, and the static fn names if the user wants them moved;
it does not change the surface namespace. ⚠ Build note when you land it: match the old
fns to the three roles by **what they do**, not by a guessed 1:1 — the real fns are
`gcg`/`gcp`/`evac`/`copy`, and a couple of earlier guesses (`dust`/`sop`/`flop`) were
wrong (`flop` is *dual* — the GC comment-flip *and* the unrelated surface float predicate;
never conflate them). Read the code, then assign.

## roadmap

- **#14 — the OOM blue floor (the big one, GC-heavy, sift's headline task).** Today an
  allocation that can't be satisfied even after a collection is the bare scare. The floor
  catches it: reserve a band at the top of the pool so OOM *falls onto it* and raises
  `(scare 'oom len)` instead of dying — recovery that can't itself OOM because two-space
  leaves the off-pool free and the floor is pre-stashed. **Take option B** (a band above
  `g->len`: only the off-pool grows `+F`, alloc ×2, `gcg` band-memcpy — leaves the
  `topof`/stack geometry byte-identical, avoiding option A's ~15-site `topof` ripple).
  Settle the two pre-build decisions first (the ai0 `F==0` guard; the `born`-bag capture
  timing), then build against a `test/floor.l` that forces a *real* OOM, gated by valg.
  See the `blue-floor-oom-recovery` notes — it's prepped, banked, and lands alone.
- **the lean-box perf line (#4, mostly landed).** Floats/wides/complex left the vec
  machinery into lean 2-/3-word boxes with their own `copy_*`/`evac_*` — ~28% off the
  mandelbrot float bench (half the heap words). sift owns keeping those copy/evac arms
  honest as kinds shift, and watching the peak-heap stat (`AI_STAT`'s `max_heap`).
- **the pointer-tag study (`doc/tag.md`, `boot/tag.l`).** Tagging a kind into a
  reference's low bits to drop the header word ("ap IS cap") would change what `gcp`
  reads and how the evacuator recovers a kind — a representation change sift must vet
  before it touches the collector. Design-only today; sift is the reviewer of record.
- **the sizing policy.** `ai_please`'s grow/shrink hysteresis (the `v_lo`/`v_hi` GC-time
  ratio, the 1/4 headroom) is tuned by feel. If it ever thrashes, sift is who measures
  `n_gc`/`max_len` under load and re-derives the thresholds — with numbers, not vibes.
