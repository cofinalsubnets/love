; slop -- rove's second game: the walk into a thing that will not let you arrive.
;
; a road through grass, and somewhere ahead of it a shore. the slop lies beyond that
; shore -- ink's skin (ink-field) under a gold-pink-yellow ramp -- but at the first
; frame it is well above the top and there is nothing to see but field. you
; stand on the road at the foot and the only steer that answers is forward.
;
; every square you pay for carries you one world row forward. below the climb line, a
; third of the way up, the row is yours and you rise on the screen. at it or above, one
; square in twenty-seven is still yours and the rest scroll the ground down under you --
; which is what brings the shore into view, and then down the screen to meet you. the
; gap closes either way -- by one, or by two where the road meets a headland, or by
; none at all across the mouth of a bay. within a screen of the shore a square costs
; ceil(drag / gap) presses, so the last one costs a screen's worth, and the slop's own
; clock is scaled by that same rate: it thickens as you do.
;
; the ground is a pure function of where it is -- slop-turf hashes (world row, column)
; into grass, sand and road, slop-road puts the path on two sines, and the shoreline and
; the depth of beach behind it are two more, laid out per column at the start. so
; scrolling costs nothing and the same shore is there when it comes back. a row with no
; slop in it is painted once and kept by world row, and the skin is asked for at the
; world row on top rather than at zero, so it drifts with the ground under it.
;
; the song is harp's (a/harp): gwen's tidal line, arpeggiated chords over four cycles,
; scheduled a cycle at a time at whatever tempo the walk is down to -- so the music
; drags with everything else and no note's pitch bends. the card takes a chunk at the
; rate it plays one, which is what paces the frame loop when there is a card at all.
;
; run: love slop
; the game is pure love -- slop-new, slop-key, slop-tick and slop-frame are state in
; and state out, gated headless by t/host/slop.l; only slop-run ties the tty (raw /
; tty / cue?, over i/posix.c), so slop never joins the corpus. ink lends the skin and
; the palette, rove the helm and the die.
(module (slop slop-run slop-walk slop-main slop-new slop-sy slop-gap slop-cost slop-rate
         slop-step slop-push slop-key slop-tick slop-frame slop-flood slop-bar slop-bar-fit slop-road slop-turf slop-post
         slop-tune slop-song-speed slop-song-edge slop-song-vol slop-song-wave
         slop-song-new slop-song-feed song-wave-of frame-due?
         slop-shore slop-sand slop-wet?)
(borrow 'ink)
(borrow 'rove)
; harp is OPTIONAL the way posix is: the song wants its cycle algebra, the walk wants
; none of it, and a seat carrying no harp plays the game in silence. every name off it
; is spelled inside a lambda, so an absent one costs nothing until the song is asked
; for. play is harp's voice layer -- vnum, venv, mixdown and pack come off it, and the
; two ride the same roster. borrowing harp shadows prel's rev and every with the
; pattern ones, so the list reverse is lrev from here down.
(? (tablet? (cite 'harp)) (borrow 'harp) ())
(? (tablet? (cite 'play)) (borrow 'play) ())
; posix is OPTIONAL: the page's seat (i/wasm) links none of it, and this file runs
; there. ask before splicing -- an absent module is a scare, and the names below that
; want a tty go missing on that seat exactly as they did before there was a module.
(? (cite 'posix) (borrow 'posix) ())
(:
 ; the slop's 24: gold up through yellow and cream, over into pink, and back --
 ; the ends meet, so the shimmer never seams
 slop-ramp [220 226 227 228 229 230 224 218 217 211 212 206
            205 199 205 206 212 211 217 218 223 222 221 214]
 pal (ink-pal slop-ramp)
 esc (string 27)
 beat 0.06                              ; the phase one frame advances at full rate

 ; the sign the walk opens with when it is handed something -- a token, a purse, or
 ; both. a ~ takes the next value and a {brace} is the token's pen, the tower's own
 ; fill and fit doing the work, so these lines are the whole of it.
 sign-ttl  "is this still the tower?"
 sign-both '("with {~} in hand, and ~ pennies besides, one way forward remains")
 sign-tok  '("with {~} in hand, one way forward remains")
 sign-pnn  '("with ~ pennies in hand, one way forward remains")
 sign-rest '(""
             "forward  k   or up"
             "leave    q   or esc"
             ""
             "-- any key --")
 ; past the climb line one square in twenty-seven is your own step; the rest scroll,
 ; and that ratio is what lands the shore on you just past the middle of the screen. it
 ; goes with the length of the walk: you rise climb-minus-(contested/odds) rows, so a
 ; walk twice as long wants odds twice as long to meet in the same place.
 own-odds 27

 ; --- the lie of the land: sines across the columns, a hash within them ---
 ; the engine's mix, thrown for a world row and a column: the grass
 (dice w x k) ((mix ((w * 374761393) + (x * 668265263) + 1)) % k)
 ; the road wanders on two sines a screen and a few screens long -- so it bends where
 ; you can see it, never repeats, and never leaves the width
 (slop-road g w) (: mid (g 'c // 2)
                    (mid + int (3.0 * sin (w * 0.21) + 2.0 * sin (w * 0.063))))
 ; the shoreline and the depth of beach behind it: two sines each, wavy the way the road
 ; is wavy. the amplitude-times-frequency sum is what matters -- keep it under one row a
 ; column and the quantized edge steps one row at a time and reads as a coast; let it
 ; over and the edge drops two rows at once and the whole thing reads as a skyline.
 ; here the shore is 0.61 and the sand 0.42.
 (shore-wave x) (int (3.0 * sin (x * 0.17) + 1.8 * sin (x * 0.058)))
 (sand-deep x) (6 + int (2.2 * sin (x * 0.23) + 1.4 * sin (x * 0.081)))
 ; the mean shoreline: three screens above the first frame's top, which is what leaves
 ; the walk its grass -- two screens for the song to fall quiet over and one more to
 ; hold it there and come back up in. never nearer than the deepest beach the columns
 ; actually laid, so the opening screen is field and nothing else on a short terminal.
 (shore0 r top) (: v (-3 * r) w -(1 + top) (v < w ? v w))

 ; a shoreline row is a world row and world rows go negative, so these are tablets and
 ; not casks -- a cask holds bytes, and -15 in one reads back 241
 (slop-shore g x) (peep (g 'shores) x 0)         ; the slop's last world row at a column
 (slop-sand g x) (peep (g 'sands) x 0)           ; and the rows of beach in front of it
 (slop-wet? g w x) (w <= slop-shore g x)         ; is this cell slop?

 road-pens [94 130 137]                 ; dirt, three shades of it
 sand-pens [180 186 223 187]            ; and sand, four
 turf-pens [22 28 34 65 71]             ; grass, dark to bright
 ; one cell of ground: (glyph . pen). behind the shore is bare sand; in front of it
 ; grass, mostly tufts with a shrub here and there, and the road's bare dots through
 ; it. the road fans out over its last four rows, so the path opens onto the beach.
 ; a wooden sign a third of a screen in, a cell off the road's right edge: not on the
 ; way, so never reached and never read, and the slop takes it like any turf
 (slop-post g) (: w (g 'r // 3) [(slop-road g w + 4) w])
 (slop-turf g w x)
  (: h (dice w x 120)
     s ((slop-shore g x) + slop-sand g x)        ; this column's last row of beach
     sg (slop-post g)
   (? (w <= s) [46 (sand-pens (h % 4))]
      (x = <sg && w = <>sg) '("¶" 137)
      (: rx (slop-road g w)
         d (w - ((slop-shore g rx) + slop-sand g rx))    ; rows of grass the road has left
         hw (? (d < 0) 6 (d < 4) (6 - d) 2)              ; five columns wide, thirteen at the sand
       (? (|(x - rx) <= hw) [46 (road-pens (h % 3))]
          (h < 9)   [35 (turf-pens (h % 2))]
          (h < 27)  [46 (turf-pens (h % 3))]
                    [34 (turf-pens (2 + (h % 3)))]))))

 ; --- the walk -----------------------------------------------------------------
 ; a fresh game on an r by c screen, from a seeded rng state: you stand on the road at
 ; the foot of it, the shore is laid out column by column well above the top, and span
 ; is the gap you are given. wetto is the lowest row any slop reaches, so a row below
 ; it is all ground and can be kept.
 (slop-new r c st)
  (: waves {} sands {} shores {}
     _ (each ^c (x \ (pin waves x (shore-wave x), pin sands x (sand-deep x))))
     top (foldl (\ a x (: v ((peep waves x 0) + peep sands x 0) (a < v ? v a))) 0 ^c)
     sh0 (shore0 r top)
     _ (each ^c (x \ pin shores x (sh0 + peep waves x 0)))
     wetto (foldl (\ a x (: v (peep shores x 0) (a < v ? v a))) (sh0 - 9) ^c)
     climb (r - 1 - r // 3)
     ; the beach's nearest world row: the sand shows on the screen the moment wtop
     ; reaches it, which is a fact about the screen and not about your distance to the
     ; shore -- the song's rise is keyed to it rather than to a gap, and so is exact
     bt (sh0 + top)
     ; the gap the song starts coming back up at, half a screen of scroll short of the
     ; sand -- and the foot of the waveform's ramp, so the two move together. keyed off
     ; the same arithmetic the rise is: the screen's top reaches a row, and you stand
     ; climb rows below the top.
     gedge (top + climb + r // 2)
     g {'r r 'c c 'wtop 0 'w (r - 1) 'shore0 sh0 'shores shores 'sands sands
        'wetto wetto 'climb climb 'drag (r - 3) 'bt bt 'gedge gedge
        'push 0 'spent 0 't 0.0 'msg "" 'over 0
        'sb {st} 'rows {} 'field (ink-drift r c)}
     _ (pin g 'span (slop-gap g))
   ; the bottom of the dip, a screen and a third into the walk -- and the foot of the
   ; edge's ramp. a third nearer the start than the two screens the fall would take,
   ; which is what buys the quiet valley behind it its length
   (pin g 'gmin (g 'span - 4 * r // 3), g))

 ; where you stand on the screen, and the rows between you and the slop at your own
 ; column. a square costs ceil(drag / gap), so it is one press until the shore is about
 ; a screen out and a screen's worth for the last one; rate is squares per press.
 (slop-sy g) (g 'w - g 'wtop)
 (slop-gap g) (g 'w - slop-shore g (slop-road g (g 'w)))
 (slop-cost g) (: gap (slop-gap g) (gap < 1 ? (g 'drag) ((g 'drag + gap - 1) // gap)))
 (slop-rate g) (1.0 / slop-cost g)

 ; one square forward. you always cross a world row; what differs is who the row on the
 ; screen goes to. below the climb line it is yours and you rise; at it or above it is
 ; mostly not, and then the ground scrolls under you instead and the shore comes on.
 (slop-step g)
  (: own (slop-sy g > g 'climb ? 1 (0 = roll (g 'sb) own-odds))
     seen (g 'wtop <= g 'wetto)              ; is any of it on the screen yet?
     _ (pin g 'w (g 'w - 1))
     _ (? own (pin g 'msg "a square")
              (pins g 'wtop ((g 'wtop) - 1)
                      'msg (seen ? "the slop comes on" "you walk on")))
   (slop-gap g < 1 ? (pins g 'over 'taken 'msg "the slop has you")))

 ; one press of forward effort: bank it, and spend a bankful on a square
 (slop-push g) (: n ((g 'push) + 1)
                  _ (pin g 'spent ((g 'spent) + 1))
                  (n < slop-cost g ? (pins g 'push n 'msg "")
                     (pin g 'push 0, slop-step g)))

 ; the helm is rove's: forward is any steer that climbs, and nothing else moves you.
 ; q or esc steps back off the map. one way forward is one thing to tap, so a tap
 ; anywhere (cli's -12) is the step -- there is nowhere else on this map to mean.
 (slop-key g k) (: mv (steer (k = -12 ? 107 k))
                   (? (g 'over) g
                      (k @ (113 || 27) 1 0) (pin g 'over 'fled)
                      (one? mv) g
                      (<>mv < 0) (slop-push g)
                      (pin g 'msg "only forward")))

 ; one beat of the slop's own clock, scaled by how fast you are still moving
 (slop-tick g) (pin g 't ((g 't) + (beat * slop-rate g)))

 ; --- the frame ----------------------------------------------------------------
 ; a row below the shoreline's lowest reach is all ground, so it is painted once and
 ; kept by world row; only the row you stand on and the rows the shore cuts are laid
 ; fresh. a pen goes out only where it changes, so a row is a handful of runs.
 (turf-line g w px)
  (: j (jug 0)
     (go x f) (? (x < (g 'c))
                 (: cell (slop-turf g w x)
                    gl (x = px ? 64 <cell)
                    hue (x = px ? 231 <>cell)
                    _ (hue != f ? (say j (esc + "[38;5;" + show hue + "m")))
                    _ (say j (string gl))
                  (go (x + 1) hue))
                 ())
     _ (go 0 -1)
   (slurp j))
 (turf-row g w px)
  (: hit (? (px < 0) (peep (g 'rows) w ()) ())
   (? (string? hit) hit
      (px < 0) (: s (turf-line g w -1) (pin (g 'rows) w s, s))
      (turf-line g w px)))

 ; a row the shore cuts: slop cells take a background off the ramp, ground cells a
 ; glyph; a reset goes out at every crossing so neither bleeds into the other. the
 ; slop's front row wears surf, which is what tells a shore from a silhouette
 surf (esc + "[38;5;231m~" + esc + "[39m")
 (wet-line g w i k px sunk)
  (: j (jug 0)
     (go x wet p f)
      (? (x < (g 'c))
         (? (slop-wet? g w x)
            (: n (int (peep k [i x] 0))
               _ (!wet && say j (esc + "[0m"))
               _ (!wet || n != p ? (say j (pal n)))
               _ (say j (? (x = px) sunk (w = slop-shore g x) surf " "))
             (go (x + 1) 1 n -1))
            (: cell (slop-turf g w x)
               gl (x = px ? 64 <cell)
               hue (x = px ? 231 <>cell)
               _ (? wet (say j (esc + "[0m")) ())
               _ (hue != f ? (say j (esc + "[38;5;" + show hue + "m")))
               _ (say j (string gl))
             (go (x + 1) 0 -1 hue)))
         ())
     _ (go 0 0 -1 -1)
   (slurp j))

 ; the skin is asked for at the world row on the screen's top, not at row zero, so the
 ; slop drifts with the ground under it rather than sitting still against a moving shore
 (slop-skin g) (((g 'field (g 't) (g 'wtop) + 4.001) * 2.9) // 1)

 (slop-frame g) (:
   j (jug 0) r (g 'r) wtop (g 'wtop) wetto (g 'wetto)
   k (slop-skin g)
   sy (slop-sy g) px (slop-road g (g 'w))
   ; where the shore has closed over you, a dark mark is all that says so
   sunk (esc + "[38;5;52m@" + esc + "[39m")
   (line i) (: w (wtop + i) me (? (i = sy) px -1)
             (wetto < w ? (turf-row g w me) (wet-line g w i k me sunk)))
   (lines i) (i < r ? (say j (line i + esc + "[0m" + esc + "[K\r\n"), lines (i + 1)))
   _ (say j (esc + "[H"))
   _ (lines 0)
   _ (say j (slop-bar-fit g + esc + "[K"))
   (slurp j))

 ; the end: the shore closed over you, so the screen is slop and nothing else. no
 ; ground, no road, no you -- the bar under it is the only thing left standing.
 (slop-flood g t) (:
   j (jug 0) r (g 'r) c (g 'c)
   k (((g 'field t (g 'wtop) + 4.001) * 2.9) // 1)
   (row i q p) (q < c ? (: n (int (peep k [i q] 0))
                         (n != p && say j (pal n), say j " ", row i (q + 1) n)))
   (rows i) (i < r ? (row i 0 -1, say j (esc + "[0m" + esc + "[K\r\n"), rows (i + 1)))
   _ (say j (esc + "[H"))
   _ (rows 0)
   _ (say j (slop-bar-fit g + esc + "[K"))
   (slurp j))

 ; --- the song -----------------------------------------------------------------
 ; gwen's tidal line, note for note:
 ;   chunk 4 (|- n 5) . jux rev . arp "pinkyup down"
 ;     $ n "e'min'7 e'maj'7 d'min'7 d'maj'7" # s "notes" # sus 2
 ; tidal's `'7` is the count of notes, not a seventh: each triad is run out through
 ; the octaves until it has seven. harp has no arp and no chord names, so the four
 ; are written out and the two arp modes are list walks.
 chords [[4 7 11 16 19 23 28]           ; e minor
         [4 8 11 16 20 23 28]           ; e major
         [2 5 9 14 17 21 26]            ; d minor
         [2 6 9 14 18 21 26]]           ; d major
 ; pinkyup sounds the top note after each of the others; down just falls
 (pinkyup l) (:- (go 0 ()) top <(lrev l)
              (go k acc) (k + 1 < #l ? (go (k + 1) (top . l k . acc)) (lrev acc)))
 (arp-of q) (? (q < 2) pinkyup lrev)    ; "pinkyup down": the first half, then the second
 ; the tune, built on first use so a seat without harp never reaches these names.
 ; four quarters to the cycle and four cycles to the round, the k'th cycle dropping
 ; its k'th quarter five semitones -- which is what chunk 4 does. sine, because the
 ; piano it was written for is not the point; the notes are.
 (slop-tune _)
  (: (quarter q sh) (fastcat (map (v \ note (pure (v + sh))) (arp-of q (chords q))))
     (cyc k) (fastcat (map (q \ quarter q (q @ ^k -5 0)) ^4))
   (jux rev (pset (pset (slowcat (map cyc ^4)) (hit (pure "sin")))
                  (legato (pure 0.34)))))

 ; the song costs by rate: a note lives 0.34s whatever the rate, so its tray ops lay
 ; that many samples. 48k is what every card takes -- an HD-Audio HDMI port refuses
 ; 16k outright (ENODEV) -- but the wasm seat's page resamples any rate, and that
 ; seat is the slow one, so it plays at a third
 song-rate (love-arch = 'wasm ? 16000 48000)
 song-cps 0.55                          ; cycles a second at full speed
 song-chunk (song-rate // 30)           ; a frame's worth of frames, thirty a second
 song-gain 6500.0
 ; the wasm seat's ring is a second deep and its frames are the cost, so there a frame
 ; gives way while the song has run down to under a quarter of that: the song keeps
 ; time and the shimmer takes what is left -- but a beat that took a key shows it, and
 ; one beat in four is shown whatever the ring holds, so the walk is never still. a
 ; card's own ring is not known, so on every other seat a frame is always due
 song-yield (love-arch = 'wasm ? song-rate // 4 0)
 frame-skip 4
 (frame-due? yield lag keyed since) (!yield || keyed || frame-skip <= since || yield <= lag)
 ; the music slows with the walk -- but only to a third of tempo. slop-rate falls to a
 ; twentieth by the shore, and a twentieth of a tempo is not a tempo any more.
 (slop-song-speed g) (0.3 + 0.7 * slop-rate g)
 ; ..and it thickens with it: how far from a sine toward a square the voices are. the
 ; ramp runs the whole way from the bottom of the volume's dip to the slop itself, so
 ; the sound hardens over everything that happens after the song goes quiet. linear in
 ; the GAP and not in the cost -- the cost is a reciprocal of the gap, so a ramp linear
 ; in it would sit near a sine for the whole walk and turn square inside the last square.
 ; a smoothstep along the way, not a square and not a straight line: flat at both ends,
 ; so the sine holds while the ramp gets going and the square eases in rather than
 ; arriving. squared put all the change in the last stretch and read as a jump; straight
 ; put it evenly everywhere, including right at the two ends where it is most heard.
 ; the ramp's foot is where the song starts coming back, NOT the bottom of its dip: the
 ; valley between the two is nearly silent, and a waveform that turns there turns where
 ; nobody can hear it -- the volume would then return onto a sound already most of the
 ; way to a square, which is the jump this is meant to avoid.
 (slop-song-edge g)
  (: gap (slop-gap g) lo (g 'gedge)
     m (? (lo <= gap) 0.0
          (1 < gap) (: u ((lo - gap) * 1.0 / ((lo - 1) * 1.0))
                     (u * u * (3.0 - 2.0 * u)))
          1.0)
   (? (m < 0.0) 0.0 (1.0 < m) 1.0 m))

 ; the volume, over the four stretches of the walk: two screens of grass to fall quiet
 ; over, then a stretch to stay quiet across, then the half screen of scroll before the
 ; sand shows to come back up in, then the whole approach to the shore at full. the fall
 ; is a smoothstep, flat at both ends -- a plain parabola spent its first half dropping
 ; to a third and read as a cliff rather than a fade; the rise is a straight line over
 ; half the distance, which is what makes it abrupt beside the fall.
 ; the fall is keyed to the gap, which is how far there is left to walk; the rise to the
 ; rows of scroll still owed before the sand shows, which is when it is asked to happen.
 song-floor 0.06                        ; the bottom of the dip: not silence, near it
 (slop-song-vol g)
  (: gap (slop-gap g) sp (g 'span) lo (g 'gmin)
     d (g 'wtop - g 'bt)            ; rows of scroll still to come before the sand
     h (g 'r // 2)
     v (? (sp <= gap) 1.0
          (lo < gap) (: q (((gap - lo) * 1.0) / ((sp - lo) * 1.0))
                        s (q * q * (3.0 - (2.0 * q)))
                      (song-floor + (1.0 - song-floor) * s))
          (h <= d) song-floor
          (0 < d) (: u ((h - d) * 1.0 / (h * 1.0))
                   (song-floor + ((1.0 - song-floor) * u)))
          1.0)
   (? (v < song-floor) song-floor (1.0 < v) 1.0 v))

 ; a triangle IN PHASE with the sine: zero and rising at the period's start, one at a
 ; quarter, minus one at three. play.l's own i-tri starts at minus one, a quarter period
 ; behind -- nothing on its own and wrong in a blend, where the two would cancel toward
 ; the middle rather than cross. harp's i-sqr already shares the sine's sign.
 (song-tri u) (: v (u * 4.0)
                 (((u < 0.25) * v)
                  + (((u >= 0.25) * (u < 0.75)) * (2.0 - v))
                  + ((u >= 0.75) * (v - 4.0))))
 ; the dial, in three steps: sine, then triangle, then square. straight from a sine to a
 ; square is a wide jump and the triangle sits between them in harmonic content, so the
 ; waypoint stays -- it is the SLIDE between them that goes. a crossfade builds BOTH of
 ; its shapes and mixes them, and a voice here is paid for by the OPERATION rather than
 ; by the sample: each tray op lays a fresh chunk-long array, and the walk carries a
 ; dozen voices at once where the tower carries five. a crossfade costs the wasm seat
 ; about three quarters again what one plain shape does, measured at twenty voices a
 ; chunk. the hardening is what the dial says, and a step still says it.
 ; m is per-voice and scalar, so the arm is taken once and not per sample.
 (slop-song-wave tp f m)
  (? (m < 0.34) (sin (tp * tau * f))
     (m < 0.67) (song-tri (tp * f % 1.0))
     (: u (tp * f % 1.0) (((u < 0.5) * 2.0) - 1.0)))
 ; a voice is its note, its shape and how long it lasts, and from its onset every voice
 ; of a kind is the one waveform -- so each kind is laid once, the first time the walk
 ; meets it, and kept: a chunk of a voice is then a cut of it, one tray op, where the
 ; shape and the envelope again are twenty. a chunk of silence is laid at either end,
 ; so the chunk a voice starts in and the one it ends in are cuts too; a chunk that
 ; reaches past the silence is laid the long way, and is the same values either way
 song-waves {}
 (song-wave-of nt f m dur rate)
  (: k [nt (m < 0.34 ? 0 (m < 0.67 ? 1 2)) dur]
     w (song-waves k)
     (? (tray? w) w
        (: t (((iota (int (dur * rate) + 2 + 2 * song-chunk)) - song-chunk) * (1.0 / rate))
           tp (t * (t > 0.0))
           v (slop-song-wave tp f m * venv tp dur * (t < dur))
           _ (pin song-waves k v)
           v)))

 ; a voice m of the way along that dial, at the volume the dip puts there. built here
 ; rather than taken off harp's mkvoice because an instrument there is a name, and this
 ; one is a dial.
 (song-voice st v rate m vol)
  (: dur (vnum v 'legato 0.30)
     nt  (vnum v 'note (vnum v 'n 0))
     f   (261.6255653005986 * exp (nt * ln2-12))
     amp (vnum v 'gain 1.0 * vol)
     pn  (vnum v 'pan 0.5)
     end (st + (int (dur * rate)) + 2)
     w   (song-wave-of nt f m dur rate)
     ; no (t >= 0.0) gate: tp is already zero for every frame before the onset, and venv
     ; is zero at zero -- so the envelope has answered that question by the time a mask
     ; could ask it, and a mask is two more tray ops a voice a chunk
     fn  (\ ix (: k0 ((peep ix 0 0) - st + song-chunk) n #ix
                  (? (0 <= k0 && k0 + n <= #w) (snip w k0 (k0 + n))
                     (: t  ((ix - st) * (1.0 / rate))
                        tp (t * (t > 0.0))
                      (slop-song-wave tp f m * venv tp dur * (t < dur))))))
   [end fn (amp * (1.0 - pn)) (amp * pn)])
 (slop-song-new tune h) {'tune tune 'h h 'fpos 0 'cyc 0 'next 0 'vs ()}
 ; one cycle's onsets as voices, the cycle starting at frame st and spc frames long.
 ; each is kept as [start voice] rather than harp's bare voice: a whole cycle is
 ; scheduled at once and a voice that has not begun is silent but not free -- its
 ; closure still runs over every frame of the chunk -- so the mixdown wants the start
 ; to drop it by, and only the end is in the voice itself.
 (song-voices s c st spc m vol)
  (filter two?
          (map (\ x (: at (st + (int (spc * qnum (evwb x - qi c))))
                       v (song-voice at (evv x) song-rate m vol)
                     (two? v ? [at v])))
               (filter onset? ((s 'tune) (qi c) (qi (c + 1))))))
 ; one chunk out the horn. whole cycles are scheduled ahead of the write head at the
 ; speed in force when their turn comes, so a tempo change lands on a bar line and no
 ; note's pitch bends with it -- the onsets move, the oscillators do not.
 ; the write is also the clock: the card takes a chunk at the rate it plays one, so a
 ; frame loop that feeds it needs no rest of its own.
 (slop-song-feed s sp m vol)
  (: spc (int (song-rate / (song-cps * sp)))
     (fill _) (? ((s 'next) <= ((s 'fpos) + song-chunk))
                 (: _ (pin s 'vs (cat (s 'vs) (song-voices s (s 'cyc) (s 'next) spc m vol)))
                    _ (pins s 'cyc ((s 'cyc) + 1) 'next ((s 'next) + spc))
                  (fill ())))
     _ (fill ())
     base (s 'fpos)
     live (filter (p \ p 1 0 >= base) (s 'vs))       ; not finished
     now (filter (p \ p 0 < base + song-chunk) live) ; ..and already begun
     _ (pins s 'vs live 'fpos (base + song-chunk))
   (say (s 'h) (pack (mixdown (map (p \ p 1) now) base song-chunk) song-chunk song-gain)))

 (presses n) (show n + (n = 1 ? " press" " presses"))
 ; the bar stops a column short of the screen: a console that wraps at its edge would
 ; scroll the map for a bar that reached it
 (slop-bar-fit g) (snip (slop-bar g) 0 (g 'c - 1))
 (slop-bar g) (? (g 'over = 'taken) ("the slop has you -- " + presses (g 'spent) + " spent")
                 (g 'over) ("you turn back -- " + presses (g 'spent) + " spent")
                 (show (slop-gap g) + " to go  "
                  + show (g 'spent) + " spent  "
                  + (g 'msg || "forward: k or up; q leaves")))

 ; --- slop on the tty: the shimmer's swim loop with the keys drained per frame ---
 ; stage would block on a key and the slop has to keep moving while you do not, so
 ; this polls the way ink does: drain what is waiting, tick, paint, rest a beat.
 ; the walk takes the screen as it finds it -- raw and the alternate screen belong to
 ; whoever raised them, which is how the tower opens the slop on the screen its circle
 ; left standing -- and answers the game it played.
 ; what the walk was handed, said once before it starts.
 ; the last keys of the circle are not an answer to this box -- they were typed at a
 ; ring, and raw mode does not echo, so they are sitting in the queue when it goes up
 ; and would take it straight down again. so the box eats the queue for half a second
 ; before it will hear anything: what takes it down is typed AT it.
 sign-settle 500                                        ; ms the sign is deaf for
 (slop-sign g tk pn)
  (: both (tk && pn)
     vs (both ? [tk pn] (tk ? [tk] [pn]))
     rows (both ? sign-both (tk ? sign-tok sign-pnn))
     head (map (l \ fill l vs) rows)
     _ (say out (sign-over (slop-frame g) sign-ttl (head + sign-rest) 0 (g 'r) (g 'c)))
     _ (flush out)
     _ (settle sign-settle)
     (edkey in))

 (slop-walk tk pn) (: ws (tty 1)
             r (two? ws && 7 < <ws ? (<ws - 1) 23)
             c (two? ws && 19 < <>ws ? <>ws 80)
             g (slop-new r c (wheel (clock 0)))
             ; the song, if this seat has one: harp for the notes, a horn to put them
             ; out of. no harp or no card and the walk is silent, which is all it is.
             tune (? (tablet? (cite 'harp)) (slop-tune ()) ())
             hn (? tune (: r (horn song-rate 2) (? (nom? r) () r)) ())
             sng (? hn (slop-song-new tune hn) ())
             ; a chunk of song is a frame's worth and the card takes it at playing
             ; speed, so with a horn the music is the clock; without one, rest is
             (beat-out sp m vol) (? sng (slop-song-feed sng sp m vol) (rest 33))
             ; since is beats since the last frame
             (swim since) (? (g 'over) ()
                         (: keys (key-drain g repeat-gap (k \ slop-key g k))   ; a held key at the tower's pace
                            _ (g 'over ? () (slop-tick g))
                            due (!hn || frame-due? song-yield (horn-lag hn) (0 < keys) since)
                            _ (? due (say out (slop-frame g), flush out))
                            (beat-out (slop-song-speed g) (slop-song-edge g) (slop-song-vol g),
                             swim (due ? 0 (since + 1)))))
             _ (say out (esc + "[?25l"))
             _ (? (|| tk pn) (slop-sign g tk pn) ())
             _ (swim 0)
             ; taken: the slop closes over the whole screen and runs at full rate --
             ; no gap left to slow it -- for half a second before the stage is left
             ; the flood runs at full rate and so does the song under it: there is no
             ; gap left to slow either one
             ; the flood answers to nothing, but it still drains: a key pressed at it is
             ; a key that would otherwise be sitting in the queue when the shell reads
             (flood n t) (? (0 < n) (: _ (drain-keys ())
                                       _ (say out (slop-flood g t), flush out,
                                          beat-out 1.0 1.0 1.0)
                                     (flood (n - 1) (t + beat))))
             _ (g 'over = 'taken ? (flood 15 (g 't)))
             _ (? hn (: _ (flush hn) (close hn)) ())
             g)

 ; ..and the verb around it: the screen is raised here and put back here, and the
 ; walk between the two neither knows nor cares which door it came in by
 (slop-run tk pn) (: _ (raw 1)
                 _ (say out (esc + "[?1049h" + esc + "[2J"))
                 g (slop-walk tk pn)
                 _ (say out (esc + "[0m" + esc + "[?25h" + esc + "[?1049l"))
                 _ (flush out)
                 _ (drain-keys ())
                 _ (raw 0)
                 (puts (g 'over @ 'taken ("the slop has you, " + presses (g 'spent) + " in\n")
                                         ("you turn back, " + presses (g 'spent) + " in\n")),
                  0))
 slop-usage "usage: love slop [token] [pennies]   (what you bring; forward is k or up, q or esc leaves)"
 ; the two optional words, in either order: a number is pennies and anything else is
 ; the token. given either, the walk opens on a sign saying what you came in with.
 (digits? t) (: n #t
                (go i) (i >= n ? 1 (48 <= t i <= 57 && go (i + 1)))
                (0 < n && go 0))
 (num-of t) (:- (go 0 0) (go i a) (i >= #t ? a (go (i + 1) (a * 10 + t i - 48))))
 (slop-args as) (:- (go as () ()) (go l tk pn) (one? l ? [tk pn]
                 (: t <l (digits? t ? (go >l tk (num-of t)) (go >l t pn)))))
 (slop-main as) (2 < #as ? (say err ("slop: " + slop-usage + "\n"), flush err, 2)
                    (: p (slop-args as) (slop-run <p <>p)))
 _ (pins (cite 'verbs 'tab) 'slop (udoor 'slop slop-main slop-usage 1 1)))
) ; module slop
