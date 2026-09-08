# plan: harp — tidal's cycles over the horn

**THE CLAIM: a pattern is a function from a span to events, and love is already the
language that says so.** Tidal Cycles is a Haskell DSL for live-coded music whose whole
model is one type — `Pattern a = Arc -> [Event a]` — plus a mini-notation for writing
sequences as strings. Everything famous about it (`fast`, `rev`, `every`, `jux`,
`bd(3,8)`) is a change of variable on that query. The horn arc landed PCM as a port on
both seats; harp is the other end of that wire: the thing that decides *what* to play.

Built, in a worktree, as a prototype:

* **`apps/harp/harp.l`** — module `harp`: exact cycle time, the pattern algebra, the
  mini-notation. Pure — no port, no clock, no card — so it rides the corpus on every
  seat and is gated by querying it.
* **`apps/harp/play.l`** — the voices and the verb: onsets become voices, voices are
  summed into PCM, PCM goes out the horn (`inle/horn.c`) or into a `.wav`.
* **`apps/harp/law.l`** — 82 laws; `make test_harp` (~2 s past a warm `host`). It lives
  beside the app rather than in `test/` because `test/*.l` IS the corpus glob, and a
  file there that says `(use 'harp)` scares every corpus run — apps/lux/law.l for the
  same reason.
* **`apps/harp/demo.l`** — harp as a library: five stacked patterns to a `.wav`.

```
love apps/harp/play.l -n 8 'bd*2 [~ sn], hh(5,8)'
love apps/harp/play.l -o beat.wav -c 0.6 'bd(3,8) , <cp ~ sn ~>'
love apps/harp/play.l -p 'bd(3,8,2)'
love apps/harp/play.l '(jux rev (hit (mini "bd sn hh cp")))'
```

## what love brought that Haskell had to build

* **currying and infix are the notation.** `(fast (qi 2))` is a pattern transform by
  partial application, so `every 3 (fast (qi 2)) p` needs no combinator plumbing —
  which is most of what a Haskell reader thinks Tidal's operator zoo is *for*.
* **trays are the synthesiser.** love's arrays are vectorised in C — `sin`, `exp`, `%`,
  the comparisons and the bit ops all run elementwise — so **a voice is a function from
  a tray of frame numbers to a tray of amplitudes**, written as one expression over
  `iota`. There is no per-sample love loop in the program, no oscillator state, and no
  buffer slicing: a note that begins mid-chunk is gated by `(t >= 0)`, which is a tray,
  so the same closure is correct in every chunk it touches. 48000 sines cost 4 ms.
* **the horn's backpressure is the clock.** `harp` never sleeps and never reads a
  timer: it writes PCM, the ring fills, the port answers 0, the task parks. Playing two
  cycles at 0.5 cps takes 4.5 s because the card took 4.5 s to want the bytes. That is
  the rung-0 contract of doc/misc/plan/horn.md doing the only job a sequencer needs.
* **`HORN=none` is a headless gate.** The sink keeps time and discards, so the timing
  law runs on a box with no card and in CI.

## what had to be got right

* **cycle time is the tree's own rationals, `1 /// 3`, never floats.** `fast 3` puts
  events at 1/3 and 2/3; a float `floor(2/3 * 3)` is 1, not 2, and the beat is silently
  dropped. Every combinator that reads *which cycle it is* (`slowcat`, `rev`, `every`,
  `squeeze`) queries through `cycles`, which cuts the span at the integers first.
  `///` carries `+ - * /` and `< <= =` exactly and over bignums, and `sort` orders
  them, so harp writes cycle arithmetic in plain infix and adds only the two things
  the coin does not have: `qfl` (floor — ⚠ `//` truncates toward zero) and `qnum`.
  Every time goes through `qi` because `qfl` and `qnum` take a coin apart with `load`
  and a bare integer has no parts to take.

  Writing harp found a real bug on the way through, now fixed in `love/arr.c`: `=`
  did not promote a ratio coin across the tower, so `(1 /// 1) = 1` was false while
  `(1 /// 1) <= 1` and `(1 /// 1) >= 1` were both true, and `sort [2 (1 /// 1) 0]`
  put the coin between 0 and 2 by value. `cmp_rank` seats a ratio coin in the number
  band, `<`/`<=`/`sort` all read it there, and `lvm_eq` enumerated every numeric kind
  except that one. The laws are in `test/newtype.l`.
* **whole vs part.** An event carries the span it logically occupies and the fragment
  this query saw. They differ when a query cuts an event, and the difference is the
  only thing that stops a two-cycle note being re-struck every cycle: a player takes
  the events where `part-begin = whole-begin`.
* **`?` needed a per-occurrence seed.** A step's pattern is degraded *before* it is
  squeezed into its slot, so every `?` in a sequence sees the same cycle-begin and they
  all agree. The mini-notation passes the `?`'s own cursor position as the seed.
* **randomness is keyed by place, not by call.** Asking for the same span twice must
  answer the same, or a live loop stutters and a re-render is a different piece.
* **the two number worlds do not meet, and that is load-bearing.** A `///` rational
  reaching a tray answers `()` — `+` takes the coin lane before the array lane
  (`lvm_addh`, love/ev.c) and the rational's method refuses a non-star operand. So
  there is exactly one crossing, `qnum` in `cyc-voices`, and nothing downstream of it
  holds a rational. A leak there would not be loud; it would be a silent tray of `()`
  and a voice that never sounds, which is why the render laws assert peaks and not
  just a header.

## the cost of using the tree's rationals rather than a hand-rolled pair

Measured, because it was the one reason not to. A coin `+` is ~22x a hand-rolled
`(n . d)` add (131 ms vs 6 ms for 40000). In context that is 64 cycles of the demo
stack — 2010 events — going from **20 ms to 130 ms**, against **3.3 s** of tray
synthesis for the same eight cycles rendered. The query is under 1% of a render
either way, and a live cycle's query is ~2 ms against a ~2 s cycle. The pair was
faster at exactly nothing that matters, and cost 25 lines and a vocabulary nobody
else in the tree speaks.

## the mini-notation, as implemented

```
bd sn            steps across one cycle      bd*2   n times as fast
[bd sn]          a subsequence in one step   bd/2   n times as slow
<bd sn>          one member per cycle        bd@3   this step takes 3 slots
bd, hh*4         stack                       bd!2   this step, twice over
~                a rest                      bd?    drop it half the time
bd _ _           extend the last step        bd?0.2 drop it a fifth of the time
bd(3,8)          euclidean                   bd(3,8,2)  euclidean, rotated
bd:3             a sample index
```

## the kit

Synthesised, not sampled — the tree has no sample library and a prototype should not
need one. `bd sn hh oh cp rim tom` as one closed-form expression each (the kick's phase
is the integral of `46 + 88e^(-34t)`, in closed form, because a per-sample oscillator
would need state and this does not), plus `sin saw sqr tri` taking `note`. The controls
`hit note n gain pan speed legato` merge as tablets, which is what makes `#` a set.

## a thing harp found and does not need: `///` over a tray

`(iota 4) + (1 /// 3)` answers `()`. Not a promotion, not a scare — a silent nil. The
mechanism is one branch: `lvm_addh` (love/ev.c) tests `coinp` on either operand and
routes to `lvm_add_coin` **before** num.c ever looks at whether an operand is a tray,
and the rational's `'+` guards its parts with `ok?` (a closed star) and answers `()`
for anything else. The array lane never gets a look.

The machinery for the other answer is already built. `obin_run` (love/arr.c) is the
object-array elementwise lane: it calls `tray_to_obj` to box a numeric tray into an
`ai_O` one and then runs the op per element — and it goes through `bshape`, so the
broadcast and conforming rules are the ones trays already have. An element of a boxed
tray is a closed star, which is exactly what `///`'s guard wants, so the guard would
not need loosening. `(iota 4) + (1 /// 3)` would answer `@((1/3) (4/3) (7/3) (10/3))`,
exactly.

⚠ **this is arc-shaped, not a one-liner**, and harp is not its caller. It is a change
to the coin-vs-array dispatch for *every* coin kind, not just rationals; `=` and `<`
go through a separate lane (`cmp3`, love/num.c); and a boxed tray allocates a coin per
element, so a 48000-frame tray of rationals is 48000 allocations — meaning the answer
to "should this be fast" is probably "no, and that is fine, it is the exact lane."
harp's own rationals are scalar cycle times and its trays are float audio; the two
never want to meet, and the boundary above is one function. Worth doing for the
language's sake — a silent `()` is a bad answer — but on its own branch, with its own
gate, and not folded into a music prototype.

## what is missing, in the order it would matter

1. **live.** The verb renders a fixed number of cycles. A REPL that re-reads the
   pattern between cycles and keeps playing is the actual Tidal experience, and the
   render loop is already cycle-at-a-time, so the change is a reader on `in` and a
   swap of `p` at the cycle line — not a rewrite.
2. **samples.** `hit "bd"` names a synth voice; naming a `.wav` on disk is the same
   dispatch with a file read behind it, and would bring `chop`, `striate` and `speed`
   as a resampler with it.
3. **the dist.** harp is in neither `crewfiles` nor `binnames`, so `(use 'harp)` only
   resolves from this tree. Both are one line each once it earns them.
4. **patterned arguments.** `bd*<2 3>` — Tidal takes a *pattern* where harp takes a
   number in `*`, `/`, `@`, `!` and the euclid triple. `appl` is already the shape that
   does it.
5. **inle.** Nothing here is hosted-only but the `.wav` sink and the environ read; the
   algebra and the voices are plain love and plain trays. `harp` on the kernel seat
   over `inle/hda.c` should be a gate, not a port.
