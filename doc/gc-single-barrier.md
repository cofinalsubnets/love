# Retiring the dirty flag — collapsing the write barrier to one mechanism

Status: **plan / spike, not started.** Pick-up doc from the 2026-06-27 session.
Companion to [`doc/gengc.md`](gengc.md) (the generational design as shipped) and
[`rocq/gc.v`](../rocq/gc.v) (the soundness proof of the *model*).

## The goal

The shipped generational barrier is **two-part** (see `gengc.md` §"What the audit
found"):

1. a **precise remembered set** — `gen_wb(src, p)` records an old `src` that takes a
   young `p`. This is the "real mutation" leg: maps and task-ring nodes.
2. a **coarse dirty flag** — `gen_dirty(cell)` sets `g->dirty` when the *parser /
   compiler* mutates an old cell in place. `g->dirty` forces the next collection to be
   a **major** instead of a minor.

**Retire leg 2.** Make the remembered set the *sole* barrier mechanism. Two payoffs:

- **Runtime data reads stop forcing majors.** The reader's incremental `set-tail` is the
  steady-state trigger of `dirty`; once it's gone, plain `(read ...)` / REPL lines no
  longer downgrade minors to majors.
- **The proof covers the whole barrier.** `gc.v`'s `barrier_sound` models *exactly* the
  precise rem-set leg (`rem_complete` / `Seeds`). The dirty leg is **unmodeled**. Delete
  it and the shipped barrier == the proved barrier — no two-part proof extension needed.
  (The proof gates are green as of 2026-06-27: `make test_uugen test_uulean test_gc`,
  axiom-free.)

This is the alternative to last session's other option — *extending* `gc.v` to model the
dirty leg. Removing the leg is the cleaner trade: don't prove the hack, delete it.

## What the dirty flag actually does

It is **not** a second kind of barrier — it is "don't trust this minor." A major already
finds every live old→young edge by tracing from roots with no rem set at all (`ai.c:~1317`,
"this subsumes the dirty case"). The rem set exists only so a *minor* can skip walking old
space. So `dirty` just says: *an old cell was mutated by a route the rem set didn't
record, so a minor would be unsound here — do a major.*

Removing it therefore means one thing: **make the minor trustworthy at the three dirty
sites** — either by recording the edge precisely (`gen_wb`), or by never creating the edge.

## The sites (grep to confirm line numbers; they drift)

Precise leg — `gen_wb` def `ai.c:~1204`, call-sites:
- task ring splices `~2746 / ~2773 / ~2789`
- `map_grow` backing swap `~4356`; `ai_mapput` `~4367 / ~4376 / ~4377`; `ai_mapdel` `~4396`

Coarse leg — `gen_dirty` def `ai.c:~1207`, sets `g->dirty`; three call-sites:
- **reader set-tail** `~4140 / ~4145` — a young cons linked into a maybe-tenured list spine
  (the reader build loop is `~4135–4148`)
- **`lvm_poke`** `~2970` — a raw poke into a tenured thread (ev continuation build /
  recursive back-ref)
- **c0** `~1684` — the bootstrap compiler mutates its `struct env` + back-patches threads;
  sets `dirty` coarsely on entry. **Boot-only** — after the egg, runtime compile goes
  through self-hosted `ev` (the poke site), not c0.

Major decision `~1413` (`major = g->dirty || ...`); resets `~1425 / ~1471`.

## The insight

These are not mutations of live data — they are **construction writes** into a structure
that only became "old" because a minor happened to fire mid-build. The dirty flag is
conservative precisely because an incremental build can straddle a minor: the spine-so-far
tenures, then the next `set-tail` writes `B(old_tail) = young_newcons` = old→young.

**Initializing/young-only writes need no barrier.** Minors only care about **old→young**.
A *young* cell pointing at anything (young or old) is always safe. So if a structure is
built such that every pointer it holds points *backward in age*, generation drops out of
the analysis entirely.

## Session finding (2026-06-27) — Step 1 is RIGHT for the reader, WRONG for the poke

Tried Step 1 as written (convert all three `gen_dirty` sites to `gen_wb`). Result:

- **Reader set-tail → `gen_wb`: SOUND, landed.** Validated end-to-end — `make test` green
  (host+ai0, 2717×3), `gc.v` green, the differential oracle 2000/2000, and a read-heavy
  gauge probe shows minors now fire (`n_minor` > 0) with `rem_miss=0`, `rem_hi=41` (of 65536):
  the rem set stays complete and tiny. The reader was "the steady-state trigger of dirty";
  it no longer forces majors. This is the real Step-1 win.
- **`lvm_poke` → `gen_wb`: UNSOUND — hung the egg-warm.** A poke writes `cell(base)+idx` at an
  ARBITRARY index, but a minor reaches a remembered object only through `gen_scan_inplace`,
  which walks a thread **only up to its tag terminator**. A poke past that (ev's thread-build /
  recursive back-ref) leaves a young value the minor never sees → it drops the live object →
  corruption → infinite loop. `gen_dirty`'s forced **major** caught it (a major traces from
  roots, ignoring the rem set). So the precise rem-set is **not a drop-in** for the poke; it
  needs Step 3 (build the thread young + tenure its group atomically) or it keeps `dirty`.
- **c0 (boot) → kept `gen_dirty`.** Boot-only; ~21 in-place env/thread mutation sites across
  the compiler (see "how hard" below) — same terminator hazard, same atomic-tenure answer.

**End state of this pass:** reader on `gen_wb`; poke + c0 on `gen_dirty`. `dirty` is NOT
deleted — it is now purely COMPILATION's "force a major" knob (c0 at boot, ev's poke at
runtime-compile), never EXECUTION's. Every minor still runs only with `dirty` clear, so its
soundness rests solely on the rem set = exactly what `gc.v` proves. Deleting `dirty` entirely
is gated on Step 3 for BOTH the poke and c0, not the cheap swap Step 1 assumed.

### Step 1 (original plan, now amended by the finding above) — collapse to one mechanism

Convert the three `gen_dirty` calls to precise `gen_wb` (remember the old source), then
delete `g->dirty`, the `major |= dirty` clause (`~1413`), the resets (`~1425/~1471`), and
`gen_dirty` itself (`~1207`). **AMENDED:** this works for the reader only; the poke/c0 sites
write at arbitrary thread offsets the minor's inplace-scan can't reach, so they need Step 3,
not a `gen_wb` swap. `gen_dirty` stays for them.

- Result: the rem set is the only barrier; `gc.v`'s `barrier_sound` covers it end-to-end.
- This is the "poke-precise rem set" the author called more complex than the flag — but the
  extra complexity is *correctness-neutral* and the perf cost lands on compile/read bursts,
  not steady-state compute.
- **Measure the tradeoff the flag dodged:** rem-set traffic during a compile burst (every
  dirtied old cell becomes a rem-set entry). If the set gets large, a minor scanning it may
  approach the cost of the major the flag would have forced — in which case the flag was the
  right call for *those* sites and Step 2 (eliminate the reader's edges) is the better win.

### Step 2 — bulk-spine reader (the elegant + perf win)

Eliminate the reader's edges instead of recording them. **Build the spine last, in one bulk
allocation, so it is uniformly the youngest thing** → every spine pointer is young→{young,
old} → no barrier, no flag, generation drops out.

- **Streaming is resolved**, not just the simple case: across a resumable read suspension
  you hold the *elements* (which may freely tenure); at the close-paren you allocate the
  spine fresh and point it *at* them (young→old). The only way to mint old→young is to
  mutate an already-built spine cell, and bulk-at-end never does.
- **Nesting composes for free:** recursive descent closes inner lists first, so the outer
  spine (built last) is youngest and points at the inner spines (older-or-equal).
- **Bonus:** one nursery bump of N contiguous cells instead of N separate conses — faster
  and cache-friendly. This is *literally how `iota`/arrays already build* ("filled in one C
  loop, no link spine"); the list reader would just do the same for its spine.
- Implementation: stack-accumulate element values per open-paren frame, materialize the
  spine at the close-paren; drop `gen_dirty` at `~4140/~4145`. **The careful part** is the
  reader's frame/ctx machinery — each nested list has its own frame, and the build currently
  goes forward via `B(tail) = newcons`. Cost: you need the count, so it's stack-accumulate-
  then-materialize (or two-pass) rather than build-forward-with-mutation.
- (Even reversed-prepend accumulation — cons each new element onto the front of a young
  accumulator — is young→old-safe and barrier-free; bulk-at-end just also buys the
  contiguous fast spine.)

### Step 3 — the thread-builder and c0

- **c0 (`~1684`) is boot-only** and boot does majors anyway — its `dirty` can stay (harmless)
  or go; the first major flushes boot's edges regardless. Lowest priority.
- **`lvm_poke` thread-build (`~2970`)** is the remaining steady-state site after Step 2.
  Either keep a precise `gen_wb` on the poke (cheapest), or build the thread young and tenure
  the whole mutually-recursive group atomically ("close the group in the nursery, then
  promote"). The one genuinely-forward edge is **recursive back-patch** (a thread referring to
  a later-built part of itself) — that's the case any "build young, publish once" scheme has
  to handle, and the precise `gen_wb` is the safe fallback for it.

## Verification payoff

Once `dirty` is gone, the shipped barrier *is* `gc.v`'s modeled barrier:
`barrier_sound` + `minor_loses_only_if_barrier_incomplete` cover it with no extension. The
empirical bridges (`gen_audit` = 0 unremembered edges; the GC-stress differential oracle)
keep the C connected to the model exactly as today. Consider promoting `gen_audit` from
`-DAI_STAT`-only to an always-on gate assertion so `rem_complete` is checked continuously.

## Validation checklist

- [ ] `gen_audit` reports **0** unremembered edges across the corpus (already asserted under
      `-DAI_STAT`; this is the empirical `rem_complete`).
- [ ] `make test` green (host **and** ai0 — both reach the zz-fin "tests pass").
- [ ] GC-stress differential oracle: corpus runs byte-identical with minors firing.
- [ ] bench: no regression on read-heavy / compile-heavy paths; expect *fewer* forced majors.
- [ ] `gc.v` still green and now understood to cover the whole (single-mechanism) barrier.
- [ ] confirm no new old→young escapes via a targeted GC-stress over `read` of deep/nested/
      streamed input (the reader was the runtime trigger; prove it's gone).

## Anchors

- `ai.c`: `gen_wb ~1204`, `gen_dirty ~1207`, dirty rationale `~1182–1208`, "subsumes the
  dirty case" `~1317`, major decision `~1413`, resets `~1425/~1471`, c0 entry `~1684`,
  `lvm_poke ~2967–2970`, reader build `~4135–4148`, map barrier `~4356–4396`.
- [`rocq/gc.v`](../rocq/gc.v): `barrier_sound` (the theorem), `minor_loses_only_if_barrier_incomplete`
  (3b's converse), `rem_complete` (the hypothesis = what `gen_audit` checks), `Seeds` (the
  minor's roots).
- [`doc/gengc.md`](gengc.md): §"The write barrier", §"What the audit found: the compiler
  mutates old in place too" (the two-part rationale), §"Tenure-on-birth", §"Verification".
- [`doc/proto/gengc.l`](proto/gengc.l): the runnable model (19 asserts; **3b** = the
  barrier-is-necessary assert this whole thread orbits).

## TL;DR for next session

The dirty flag is a hack for the parser/compiler mutating chains in place. It's not a
barrier, it's "force a major because a minor can't be trusted here." Kill it in two moves:
**(1)** convert the 3 `gen_dirty` sites to precise `gen_wb` so the rem set is the only
mechanism (and `gc.v` already proves that); **(2)** make the reader build list spines in one
bulk allocation *last* so they're uniformly youngest (young→old only, no edge to record) —
which also makes reads faster and resolves the streaming case. c0 is boot-only; the ev
thread-builder keeps a precise `gen_wb` (or atomic-tenures its group). Validate with
`gen_audit` (0 misses) + the GC-stress oracle. End state: a single-mechanism barrier the
shipped code and the proof both describe.
