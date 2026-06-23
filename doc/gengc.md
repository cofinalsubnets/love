# A generational nursery over the Cheney core

A **young generation** over ai's copying collector — a cheap *minor* that scavenges
only fresh allocation, leaving the tenured set untouched, with the full collection
demoted to a rare *major*. **Built (stage 3), AI_STAT-gated** — see "As built" below;
the rest of this study is the reasoning that led there, kept for the why.

A runnable ai model lives in [`doc/proto/gengc.l`](proto/gengc.l) — a world is
`(nur old rem roots next)`, and its asserts pin the invariants (most pointedly:
the write barrier is *necessary*, assert 3b). The measurement that justified
this lives in [`tools/gcstat.l`](../tools/gcstat.l), run on a `-DAI_STAT` host.

## Why

`tools/gcstat.l` measured ai's churn (gauge now reports `n_seen`/`n_evac`; see
the `gc:` commit). Interpreted, allocation-heavy workloads run **85–94% infant
mortality**, and the persistent live set is **recopied ~150× over a run** —
every full collection drags the same long-lived objects through to-space again.

A copying collector's per-collection cost is proportional to *survivors*, not
garbage; so high mortality is not wasted *copy* work — it is wasted *frequency*.
The waste is the **recopy of the tenured set on every cycle**. A nursery removes
exactly that: a minor copies only the young survivors; the old set is never
walked. Glaze/deforestation (`doc/proto/forest.l`) is the orthogonal attack — it
*avoids* allocating the intermediates; this *reaps* cheaply whatever still gets
allocated (the un-recognized churn: `mapchurn` 82%, `revbig` 90%).

## The one insight that makes it small

`gcp` (`ai.c:~1211`) forwards a word **only if it points inside `[p0, t0)`** —
the from-space bounds — and leaves every other word alone. So the minor collector
is *already written*: point `p0`/`t0` at the **nursery** instead of the whole
pool, and `gcp` copies young objects, leaves old objects in place (they fall
outside the bounds), and the same Cheney scan (`evac_*`) chases the promoted
objects' fields. The deltas to today's `gcg`:

1. the bump target is **old's `hp`** (promote by appending to old), not a fresh
   pool — there is no flip on a minor;
2. the root set gains the **remembered set** (old→young edges, below);
3. `p0`/`t0` are the nursery bounds, so old space is invisible to the scan.

A **major** is exactly today's `gcg`: `p0`/`t0` = the whole old pool, the
two-pool flip, `symbols_rebuild` + `run_finalizers` after the fixpoint.

## Generations are read from the address

ai objects are header-minimal — the "drop jitba's GC tag word" commit confirmed
a string carries no tag (its size derives from `len`). There is **no spare bit
for an age field**, and that is fine: a generation is read from the *address*.
`young?(p)` is a range test, `nursery_lo <= p < nursery_hi`. The model's
"is this addr a key in `nur`?" stands in for that range test.

## Pool layout

Today (one pool; core at base, heap up from `end`, stack down from the top):

```
[ core | old-heap →           …            ← stack ]
 base    end     hp                        sp    top
```

**Option A — a separate nursery (recommended for v1).** Old space stays the main
pool. A small nursery is its own region; allocation bumps there. A minor is `gcp`
with `p0`/`t0` = the nursery, bumping survivors past the main pool's `hp`:

```
main:     [ core | old-heap →      …      ← stack ]      ← roots + promotion target
nursery:  [ young →    … ]                               ← from-space of a minor
```

Clean: the nursery never holds the stack or core (always roots, always scanned);
the post-fixpoint phases (weak table, finalizers) stay major-only; `gcp` reuse is
near-verbatim. Cost: one extra region and a `Have` that checks the nursery, not
`sp`.

**Option B — an in-pool sliding nursery (throughput follow-up).** Carve the
nursery as the top of the heap, `young? = p >= nurbase` where `nurbase` is `hp`
at the last minor. No extra region, but promoting *down* onto a contiguous old
set needs care the two-pool flip gives for free in A. Defer.

## The write barrier

The barrier surface is **tiny**: the only in-place pointer mutation that can mint
an old→young edge is a value pinned into a map/box — `ai_mapput`
(`ai.c:~3927/3932`). Chains and arrays are immutable, casks hold bytes,
numbers/strings are GC leaves, `pull`/`mapdel` only remove. So the barrier is one
hot path: *when an old map takes a young value, remember the map.*

The remembered set stores the **map header** (stable identity), not the backing
or the slot — because `map_grow` (`ai.c:~3920`, and the sibling swap at `~4541`) swaps the backing
(`cell(m)[1].x = nb`), which is itself a header(old)→backing(young) edge created
*outside* `ai_mapput`. Two clean ways to keep that edge from escaping:

- **tenure map backings** (born old) — then `map_grow`'s `nb` is old, no edge; or
- remember the header and, on a minor, scan **header → current backing → slots**
  for young pointers (robust to a swapped backing).

Recommend: remember the header; a minor walks its live backing. (Belt-and-braces:
tenure backings too, since maps are tenured anyway — see below.)

### What the audit found: the compiler mutates old in place too

The "maps are the only mutable-pointer structure" premise holds for **execution**
but **not for the compiler**. Stage 2's audit (below) proved this empirically:
runtime pure compute (even heavy map mutation) produces *zero* unbarried old→young
edges, but the *compiler* mutates old objects in place by three routes a map
barrier can't see:

- **the reader** builds lists by set-tail (`ai.c:~3803` — `B(tail) = newcons`);
- **ev** builds continuation **threads** by `poke` (`lvm_poke`), and **c0** builds
  threads + mutates its `struct env` scope in place;
- the **task ring** splices a young yield/spawn snapshot into an existing node
  (`lvm_yield_sw`/`spawn`/`wait`).

So the v1 barrier is **two-part** (and this is what stage 2 ships):

1. a **remembered set** for the precise, hot, minor-friendly case — an old *map*
   (or task-ring node) taking a young value: `ai_mapput`, `map_grow`, `ai_mapdel`,
   the task splices → `gen_wb(src, p)` remembers `src` when it's old and `p` young;
2. a **dirty flag** for the compiler's in-place mutation — `lvm_poke`, the reader's
   set-tail, and **c0 via its entry** set `g->dirty` when they write an old cell.
   A collection with `dirty` set must be a **major**; clear → a minor is sound.
   Since execution never sets it, compute gets minors and *compile bursts* get a
   major to flush their edges (boot too, where c0 runs). This is far simpler than a
   poke-precise rem set or card marking, and exact: dirty ⟺ "an unbarriered old
   write happened since the last collection." See `doc/proto/gengc.l` for the model
   (a precise rem set; the dirty flag is the C answer to non-map mutation).

## Tenure-on-birth

Some kinds are born straight into old space, which dissolves the awkward minor-GC
interactions rather than handling them:

- **interned noms** → old. The weak intern table (`symbols_rebuild`, `ai.c:1012`)
  is rebuilt only at a major; a minor never sees it, so a freshly interned symbol
  surviving a minor needs no table fix-up. (A nom referenced only by the weak
  table is meant to die — that is the major's job.)
- **casks / ports / toasts** → old. Finalizers (`run_finalizers`, `ai.c:1032`)
  run only at a major; a born-old finalizable object never dies in a minor, so a
  minor needs no finalizer pass.
- **maps / boxes** → old. They are the *targets* of the barrier; keeping them old
  means the barrier's "old map" premise holds from birth, and backings tenure
  with them.

So the nursery holds the high-churn leaves the measurement implicated: chains,
the numeric boxes (`flo`/`wide`/`cplx`/`big`), and small arrays — exactly the
deforestation-intermediate population.

## What a minor scans (the win, measured)

Roots of a minor = stack + C roots (`g->root`) + core `v0..end` + the remembered
set. It does **not** walk old space. The model's assert (7): on 50 old + 1 young,
a minor scans **1**, a major **50**. That is the ~150× recopy from `gcstat.l`,
removed — the tenured set crosses to-space once (at its promoting minor) and then
sits, instead of being recopied every cycle.

The core "flops with the dust" (`gcg` leaves a forwarding pointer in the old
core's `ap`) **only on a major**. On a minor the core and stack stay put; only
the nursery moves.

## Sizing — a two-level `ai_please`

Today `ai_please` (`ai.c:1078`) grows/shrinks the *whole* pool on a
GC-time÷mutator-time ratio, keeping ≥¼ free. Generational splits the cost model:

- **nursery size** is tuned for *pause* and *promotion rate*: big enough that
  minors are infrequent, small enough that a minor stays cheap and most of the
  nursery is dead by the time it runs (the 85–94% mortality is the budget). A
  nursery sized to the L2/L3 the mutator churns through is the usual sweet spot.
- **major trigger** fires on old-space pressure (a promotion that won't fit, or
  old crossing a high-water fraction), and *only a major* runs today's
  grow/shrink-the-pool heuristic.

Keep the existing ratio logic for the major; add a flat nursery-full trigger for
the minor.

## Staging into C (each stage keeps `make test` green)

0. **instrumentation** — `n_seen`/`n_evac` in `gauge`. *(done)*
1. **the watermark + observability** — a `nursery` field (= `hp` after each
   collection; `[nursery, hp)` is young, `[end, nursery)` old), maintained in
   `gcg`, exposed as `gauge` `old`. No behaviour change (gate green, valgrind
   clean). The `young?` predicate lands with its first caller (stage 2) — an
   unused `static inline` is a `-Werror` failure here. *(done)*
2. **the barrier + audit** — `ai_young(p) = lamp(p) && nursery <= p < hp`; the
   two-part barrier above (rem set `gen_wb` for old maps/task-nodes + `dirty` flag
   for compiler mutation). `gen_audit` runs under `-DAI_STAT` when `dirty` is clear
   (a minor would fire) and does a **reachability DFS from the GC roots**, checking
   every reachable old object's young fields are remembered — dead/orphaned backings
   are never visited, so no false positives. RESULT: 0 unremembered edges across the
   full test corpus + benches; pure compute + map mutation 0 over many GCs. The
   barrier/flag/audit are AI_STAT-gated, so the normal build & `make test` are
   unchanged. *(done)*
3. **the real minor + the major pool** *(done; see "As built" below)* — the design
   inverted from Option A: the **minor pool** is the existing main pool (no allocation-path
   change), the **major pool** is a separate two-space region. A minor evacuates the minor
   pool into the major pool; a major is one **reachability** pass over {major ∪ minor} (no
   linear sweep). Both pools grow independently, on configurable initial sizes. Differential
   oracle: the whole test corpus runs **byte-identical** with minors, majors, and both
   grows firing; `make test` stays green (AI_STAT-gated). (The pools were called the
   *nursery* and the *elder* through stage 3; renamed to the **minor pool** / **major pool**.)
4. **tune / graduate** — (a) major-pool sizing: keep it small, grow by one step (not
   doubling), shrink when the live set collapses *(in progress)*; (b) runtime-pluggable
   sizing (today compile-time `ai_minor0` / `ai_major0`); (c) two-level pause/promotion
   heuristics; (d) lifting the minor out of AI_STAT into the kernel/host (a pool-backed rem
   set, since the kernel can't malloc).

## As built (stage 3)

The shipped shape differs from the sketch above, steered by what the binary and the
"() IS the core" archaeology actually showed. Two pools: the **minor pool** (was "nursery")
and the **major pool** (was "elder"), reaped by minor and major collections respectively.

- **Two pools, core/stack with the minor pool.** The minor pool is the main pool —
  `[core | heap→ … ←stack]`, allocations bump `hp` *unchanged*, the whole heap is young.
  The major pool (`major_pool`) is a separate two-space region holding only tenured heap.
  This is the opposite of Option A (which put old in the main pool) and needs **no**
  `Have`/`bump` surgery.
- **Minor** (`gen_minor`; `!dirty`, major pool has headroom): Cheney the minor pool → the
  major-pool active half (append), then `hp = end`. Roots ∪ the **rem set** (old→young
  edges) ∪ a strong scan of the weak intern map. The scan starts at the append point, so a
  minor never reads a dead or non-object word.
- **Major** (`gen_major`; `dirty`, or the major pool can't hold a worst-case promotion): one
  **reachability** Cheney over BOTH from-spaces — the major-pool active half and the minor
  pool (`gcp`'s second range) — into the major-pool spare half (or a fresh pair sized to
  *major-live + minor-young*), then rebuild symbols + run finalizers, flip, reset the minor
  pool. Reachability means dead objects (and their stale pointers) are simply never visited —
  the fix for the linear sweep that crashed on dead task-ring nodes.
- **Independent growth (decoupled).** The minor pool resizes on its own GC/mutator ratio
  (`gen_grow`, which moves core+stack — safe because **`()` is `ZeroPoint`, an out-of-pool
  const, not the core**; the old "() IS the core" + the `gcg` core-flop are vestigial). The
  major pool grows only at a major, far less often. Initial sizes are **configurable** like
  the custom allocator (`ai_minor0`/`ai_major0`): a Teensy picks small + accepts more GCs, a
  host picks roomy + boots in a few. *(Stage-4 note: the major pool currently only ever
  grows — `to_len` doubles and never shrinks — which floats garbage on churn workloads; the
  sizing heuristic addresses this.)*
- All of it is `AI_STAT`-gated; the normal build and the kernel are byte-for-byte
  unchanged. (Also: the GC's tagged-object kind was renamed `text` → `thread`.)

## Verification

The model's invariants (`doc/proto/gengc.l`, 19 asserts) are the spec the C must
meet — most importantly that the barrier is load-bearing (3b reproduces the bug a
missing barrier *is*). The GC-stress differential test is the runtime oracle. A
*verified* minor (a `gcp`-bounds argument in `rocq/`) is a much larger, separate
effort — the place ai's in-tree prover could eventually earn its keep, the same
caveat `ai/glaze/README.md` flags for a verified glaze.

## Not yet / open

- AArch64: a major already needs no I-cache work, but if a toast is ever
  *promoted* the W^X arena's finalizer must follow it (it does, via `run_finalizers`
  at the major); confirm a born-old toast never enters the minor pool in the first
  place.
- Inter-task: tasks share one pool; the remembered set is global. A per-task
  minor pool is a later question (tied to the kship/init direction).
- Large objects: a big array allocated young then promoted is copied twice
  (minor pool→major at its first minor). A size threshold for born-old large objects
  is the standard mitigation; measure before adding.
