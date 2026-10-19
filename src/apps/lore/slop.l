; slop -- rove's second game: a road through grass toward a shore, the slop (slop-drift's
; skin) beyond it, that will not let you arrive. a square paid is a world row forward; above
; the climb line most scroll the ground instead, and near the shore a square costs
; ceil(drag / gap) presses, the slop's clock slowed alike. the ground is a pure function
; of place, so a row with no slop is painted once and kept by world row.
; slop-new/key/tick/frame are pure; only slop-walk touches the tty. other floors borrow the skin.
(module (slop slop-run slop-walk slop-main slop-new slop-sy slop-gap slop-cost slop-rate
         slop-step slop-push slop-key slop-tick slop-frame slop-flood slop-bar slop-bar-fit slop-road slop-turf slop-post
         slop-tune slop-song-speed slop-song-edge slop-song-vol slop-song-wave
         slop-song-new slop-song-feed song-wave-of frame-due?
         slop-shore slop-sand slop-wet? slop-drift slop-pal slop-ramp slop-ramp-pen slop-under slop-face)
(borrow 'rove)
; borrowing harp shadows prel's rev and every, so the list reverse here is lrev
(borrow 'harp)
(borrow 'play)
; posix is optional: the wasm build links none of it and runs this file. borrow, never
; splice: a spliced absent module scares, a borrowed one's tty names just go missing
(borrow 'posix)
(:
 ; the skin: four drifting sines (one a radial ripple) over an r by c grid, by tray
 ; broadcast. field(t dy) is a 2r by c tray, dy rows down: a cell's upper half at [2y x],
 ; lower at [2y+1 x], for a `▀`. cy doubles y so the ripple is round; values in [-4, 4]
 (slop-drift r c) (:
   ycol (star-tray [(2 * r) 1] ^(2 * r))
   xrow (star-tray [1 c] ^c)
   y2 (ycol * 0.5 + 0.25 + xrow * 0.0)
   x2 (ycol * 0.0 + xrow * 1.0)
   cx (x2 - c / 2.0)
   (field t dy) (: yy (y2 + dy * 1.0)
                   cy ((yy - r / 2.0) * 2.0)
                   rr (1 / 2 $ cx * cx + cy * cy)
                 (sin (x2 * 0.09 + t) +
                  sin (yy * 0.16 - t * 0.7) +
                  sin ((x2 + yy) * 0.06 + t * 0.4) +
                  sin (rr * 0.11 - t)))
   field)
 ; the skin read as ground, the floors' as well as slop's: a ramp's step at skin value v,
 ; its steps spread over [-span, span]
 (slop-ramp-pen rp span v) (: m (#rp - 1)
                              n (int ((v + span) * #rp / (2.0 * span)))
                              (rp (? (n < 0) 0 (m < n) m n)))
 ; the pen under what stands on cell (x y): its lower half's, pen taking a skin value
 (slop-under k pen x y) (pen (peep k [(2 * y + 1) x] 0.0))
 ; the skin at cell (x y) as a face, in either mode: gl () is a `▀`, the upper half's pen
 ; over the lower's; a glyph wears the lower half's pen alone
 (slop-face k pen x y gl)
  (gl = () ? ["▀" [(pen (peep k [(2 * y) x] 0.0)) (slop-under k pen x y)]]
     [gl (slop-under k pen x y)])
 ; a ramp pre-rendered as SGR pens, [foreground background] a step, so a frame is pure
 ; lookup; the cell is the caller's, which lets it collapse a run of equal cells
 (slop-pal rs) (: (pen b n) (string 27 + "[" + show b + ";5;" + show n + "m")
                  (dab t i l) (!l ? t (pin t i [(pen 38 <l) (pen 48 <l)], dab t (i + 1) >l))
                  (dab {} 0 rs))
 ; the slop's 24: gold up through yellow and cream, over into pink, and back --
 ; the ends meet, so the shimmer never seams
 slop-ramp [220 226 227 228 229 230 224 218 217 211 212 206
            205 199 205 206 212 211 217 218 223 222 221 214]
 pal (slop-pal slop-ramp)
 esc (string 27)
 beat 0.06                              ; the phase one frame advances at full rate

 ; the sign when handed a token, pennies or both: ~ takes the next value, {braces} the token's pen
 sign-ttl  "is this still the tower?"
 sign-both '("with {~} in hand, and ~ pennies besides, one way forward remains")
 sign-tok  '("with {~} in hand, one way forward remains")
 sign-pnn  '("with ~ pennies in hand, one way forward remains")
 sign-rest '(""
             "forward  k   or up"
             "leave    q   or esc"
             ""
             "-- any key --")
 ; past the climb line one square in own-odds is your own step, the rest scroll; tuned so
 ; the shore meets you just past mid-screen, and it scales with the walk's length
 own-odds 27

 ; --- the lie of the land: sines across the columns, a hash within them ---
 ; the engine's mix, thrown for a world row and a column: the grass
 (dice w x k) (mix (w * 374761393 + x * 668265263 + 1) % k)
 ; the road wanders on two sines a screen and a few screens long -- so it bends where
 ; you can see it, never repeats, and never leaves the width
 (slop-road g w) (g 'c // 2 @ mid
                    (mid + int (3.0 * sin (w * 0.21) + 2.0 * sin (w * 0.063))))
 ; the shoreline and the beach behind it, two sines each. keep the sum of amplitude
 ; times frequency under 1, so the edge steps a row a column and reads as a coast
 (shore-wave x) (int (3.0 * sin (x * 0.17) + 1.8 * sin (x * 0.058)))
 (sand-deep x) (6 + int (2.2 * sin (x * 0.23) + 1.4 * sin (x * 0.081)))
 ; the mean shoreline: three screens up -- two for the song to fall quiet, one to come
 ; back -- and never nearer than the deepest beach laid, so the first screen is all field
 (shore0 r top) (: v (-3 * r) w -(1 + top) (v < w ? v w))

 ; a shoreline row is a world row and world rows go negative, so these are tablets and
 ; not casks -- a cask holds bytes, and -15 in one reads back 241
 (slop-shore g x) (peep (g 'shores) x 0)         ; the slop's last world row at a column
 (slop-sand g x) (peep (g 'sands) x 0)           ; and the rows of beach in front of it
 (slop-wet? g w x) (w <= slop-shore g x)         ; is this cell slop?

 road-pens [94 130 137]                 ; dirt, three shades of it
 sand-pens [180 186 223 187]            ; and sand, four
 turf-pens [22 28 34 65 71]             ; grass, dark to bright
 ; one cell of ground, [glyph pen]: sand behind the shore, grass before it, the road
 ; fanning out over its last four rows. slop-post is a sign off the road, never reached
 (slop-post g) (g 'r // 3 @ w [(slop-road g w + 12) w])
 (slop-turf g w x)
  (: h (dice w x 120)
     s (slop-shore g x + slop-sand g x)          ; this column's last row of beach
     sg (slop-post g)
   (? (w <= s) [46 (sand-pens (h % 4))]
      (x = <sg && w = <>sg) '("¶" 137)
      (: rx (slop-road g w)
         d (w - (slop-shore g rx + slop-sand g rx))      ; rows of grass the road has left
         hw (? (d < 0) 6 (d < 4) (6 - d) 2)              ; five columns wide, thirteen at the sand
       (? (|(x - rx) <= hw) [46 (road-pens (h % 3))]
          (h < 9)   [35 (turf-pens (h % 2))]
          (h < 27)  [46 (turf-pens (h % 3))]
                    [34 (turf-pens (2 + h % 3))]))))

 ; --- the walk -----------------------------------------------------------------
 ; a fresh game on an r by c screen from a seeded rng state. span is the starting gap;
 ; wetto the lowest row any slop reaches, so rows below it are all ground and kept
 (slop-new r c st)
  (: waves {} sands {} shores {}
     _ (each ^c (x \ (pin waves x (shore-wave x), pin sands x (sand-deep x))))
     top (foldl (a \ x \ (peep waves x 0 + peep sands x 0 @ v (a < v ? v a))) 0 ^c)
     sh0 (shore0 r top)
     _ (each ^c (x \ pin shores x (sh0 + peep waves x 0)))
     wetto (foldl (a \ x \ (peep shores x 0 @ v (a < v ? v a))) (sh0 - 9) ^c)
     climb (r - 1 - r // 3)
     ; the beach's nearest world row: sand shows when wtop reaches it; the song's rise keys off it
     bt (sh0 + top)
     ; the gap where the song comes back, half a screen of scroll short of the sand, and
     ; the foot of the waveform's ramp
     gedge (top + climb + r // 2)
     g {'r r 'c c 'wtop 0 'w (r - 1) 'shore0 sh0 'shores shores 'sands sands
        'wetto wetto 'climb climb 'drag (r - 3) 'bt bt 'gedge gedge
        'push 0 'spent 0 't 0.0 'msg "" 'over 0
        'sb {st} 'rows {} 'field (slop-drift r c)}
     (pin g 'span (slop-gap g),
   ; the bottom of the volume's dip, a screen and a third into the walk
      (pin g 'gmin (g 'span - 4 * r // 3), g)))

 ; your screen row, and the gap to the slop at your column; rate is squares per press
 (slop-sy g) (g 'w - g 'wtop)
 (slop-gap g) (g 'w - slop-shore g (slop-road g (g 'w)))
 (slop-cost g) (slop-gap g @ gap (gap < 1 ? (g 'drag) ((g 'drag + gap - 1) // gap)))
 (slop-rate g) (1.0 / slop-cost g)

 ; one square forward, a world row: below the climb line you rise on the screen, at or
 ; above it the ground mostly scrolls instead
 (slop-step g)
  (: own (slop-sy g > g 'climb ? 1 (0 = roll (g 'sb) own-odds))
     seen (g 'wtop <= g 'wetto)              ; is any of it on the screen yet?
     (pin g 'w (g 'w - 1),
      own ? (pin g 'msg "a square")
            (pins g 'wtop (g 'wtop - 1)
                    'msg (seen ? "the slop comes on" "you walk on")),
      slop-gap g < 1 ? (pins g 'over 'taken 'msg "the slop has you")))

 ; one press of forward effort: bank it, and spend a bankful on a square
 (slop-push g) (g 'push + 1 @ n
                  (pin g 'spent (g 'spent + 1),
                   n < slop-cost g ? (pins g 'push n 'msg "")
                     (pin g 'push 0, slop-step g)))

 ; forward is any rove steer that climbs; a tap anywhere (cli's -12) is forward too
 (slop-key g k) (steer (k = -12 ? 107 k) @ mv
                   (? (g 'over) g
                      (k @ (113 || 27) 1 0) (pin g 'over 'fled)
                      (atom? mv) g
                      (<>mv < 0) (slop-push g)
                      (pin g 'msg "only forward")))

 ; one beat of the slop's own clock, scaled by how fast you are still moving
 (slop-tick g) (pin g 't (g 't + beat * slop-rate g))

 ; --- the frame ----------------------------------------------------------------
 ; an all-ground row is painted once and kept by world row; yours and the shore's are
 ; laid fresh. a pen goes out only where it changes
 (turf-line g w px)
  (: j (jug 0)
     (go x f) (x < g 'c ?
                 (: cell (slop-turf g w x)
                    gl (x = px ? 64 <cell)
                    hue (x = px ? 231 <>cell)
                    (hue != f ? (say j (esc + "[38;5;" + show hue + "m")),
                     say j (string gl),
                     go (x + 1) hue)))
     (go 0 -1,
      slurp j))
 (turf-row g w px)
  ((px < 0 ? (peep (g 'rows) w ())) @ hit
   (? (string? hit) hit
      (px < 0) (turf-line g w -1 @ s (pin (g 'rows) w s, s))
      (turf-line g w px)))

 ; a row the shore cuts: a reset at every crossing so neither side bleeds; the front
 ; row wears surf, which tells a shore from a silhouette
 surf (esc + "[38;5;231m~" + esc + "[39m")
 ; a slop cell is a `▀`, its upper half's step the pen and its lower's the ground; under
 ; surf, or you sunk, the lower half alone. pens go out only where they change: f and b
 ; are the steps in force, -1 for none, and a turf hue rides f as -2 - hue
 (wet-line g w i k px sunk)
  (: j (jug 0)
     (go x wet f b)
      (x < g 'c ?
         (slop-wet? g w x ?
            (: t (int (peep k [(2 * i) x] 0)) u (int (peep k [(2 * i + 1) x] 0))
               _ (wet ? 0 (say j (esc + "[0m")))
               f0 (wet ? f -1) b0 (wet ? b -1)
               (u = b0 ? 0 (say j (pal u 1)),
                x = px || w = slop-shore g x ?
                  (say j (x = px ? sunk surf), go (x + 1) 1 -1 u)
                  (t = f0 ? 0 (say j (pal t 0)), say j "▀", go (x + 1) 1 t u)))
            (: cell (slop-turf g w x)
               gl (x = px ? 64 <cell)
               hue (x = px ? 231 <>cell)
               _ (wet ? (say j (esc + "[0m")))
               f0 (wet ? -1 f)
               (-2 - hue = f0 ? 0 (say j (esc + "[38;5;" + show hue + "m")),
                say j (string gl),
                go (x + 1) 0 (-2 - hue) -1))))
     (go 0 0 -1 -1,
      slurp j))

 ; the skin sampled at the screen's top world row, so it scrolls with the ground
 (slop-skin g) ((g 'field (g 't) (g 'wtop) + 4.001) * 2.9 // 1)

 (slop-frame g) (:
   j (jug 0) r (g 'r) wtop (g 'wtop) wetto (g 'wetto)
   k (slop-skin g)
   sy (slop-sy g) px (slop-road g (g 'w))
   ; where the shore has closed over you, a dark mark is all that says so
   sunk (esc + "[38;5;52m@" + esc + "[39m")
   (line i) (: w (wtop + i) me (i = sy ? px -1)
             (wetto < w ? (turf-row g w me) (wet-line g w i k me sunk)))
   ; a line is painted to the screen's edge: an erase there would take its last cell
   (lines i) (i < r ? (say j (line i + esc + "[0m\r\n"), lines (i + 1)))
   (say j (esc + "[H"),
    lines 0,
    say j (slop-bar-fit g + esc + "[K"),
    slurp j))

 ; the end: the whole screen slop, the bar under it
 (slop-flood g t) (:
   j (jug 0) r (g 'r) c (g 'c)
   k ((g 'field t (g 'wtop) + 4.001) * 2.9 // 1)
   (row i q f b) (q < c ?
                    (: t (int (peep k [(2 * i) q] 0)) u (int (peep k [(2 * i + 1) q] 0))
                       (t = f ? 0 (say j (pal t 0)),
                        u = b ? 0 (say j (pal u 1)),
                        say j "▀",
                        row i (q + 1) t u)))
   (rows i) (i < r ? (row i 0 -1 -1, say j (esc + "[0m\r\n"), rows (i + 1)))
   (say j (esc + "[H"),
    rows 0,
    say j (slop-bar-fit g + esc + "[K"),
    slurp j))

 ; --- the song -----------------------------------------------------------------
 ; this tidal line, note for note:
 ;   chunk 4 (|- n 5) . jux rev . arp "pinkyup down"
 ;     $ n "e'min'7 e'maj'7 d'min'7 d'maj'7" # s "notes" # sus 2
 ; tidal's `'7` is seven notes, the triad run up the octaves; harp has no arp or chord names
 chords [[4 7 11 16 19 23 28]           ; e minor
         [4 8 11 16 20 23 28]           ; e major
         [2 5 9 14 17 21 26]            ; d minor
         [2 6 9 14 18 21 26]]           ; d major
 ; pinkyup sounds the top note after each of the others; down just falls
 (pinkyup l) (:- (go 0 ()) top <(lrev l)
              (go k acc) (k + 1 < #l ? (go (k + 1) (top . l k . acc)) (lrev acc)))
 (arp-of q) (q < 2 ? pinkyup lrev)      ; "pinkyup down": the first half, then the second
 ; four quarters a cycle, four cycles a round, the k'th cycle's k'th quarter down five
 ; semitones (chunk 4)
 (slop-tune _)
  (: (quarter q sh) (fastcat (map (v \ note (pure (v + sh))) (arp-of q (chords q))))
     (cyc k) (fastcat (map (q \ quarter q (q @ ^k -5 0)) ^4))
   (jux rev (pset (pset (slowcat (map cyc ^4)) (hit (pure "sin")))
                  (legato (pure 0.34)))))

 ; the cost goes with the rate. cards want 48k (an hda hdmi port refuses 16k); the wasm
 ; page resamples any rate and is the slow one, so it plays at a third
 song-rate (love-arch = 'wasm ? 16000 48000)
 song-cps 0.55                          ; cycles a second at full speed
 song-chunk (song-rate // 30)           ; a frame's worth of frames, thirty a second
 song-gain 6500.0
 ; on wasm a frame is skipped while under a quarter second of song is queued, unless a
 ; key came or frame-skip beats passed; elsewhere a frame is always due
 song-yield (love-arch = 'wasm ? song-rate // 4 0)
 frame-skip 4
 (frame-due? yield lag keyed since) (!yield || keyed || frame-skip <= since || yield <= lag)
 ; the music slows with the walk, but never under 0.3 of tempo
 (slop-song-speed g) (0.3 + 0.7 * slop-rate g)
 ; ..and hardens, sine toward square: a smoothstep in the gap (not the cost, its
 ; reciprocal) from gedge, where the song comes back, to the slop; a foot in the silent
 ; dip would turn the sound where nobody hears it
 (slop-song-edge g)
  (: gap (slop-gap g) lo (g 'gedge)
     m (? (lo <= gap) 0.0
          (1 < gap) ((lo - gap) * 1.0 / ((lo - 1) * 1.0) @ u
                     (u * u * (3.0 - 2.0 * u)))
          1.0)
   (? (m < 0.0) 0.0 (1.0 < m) 1.0 m))

 ; the volume: a smoothstep fall in the gap from span to gmin, quiet at song-floor, then
 ; a straight rise over the half screen of scroll before the sand shows, then full
 song-floor 0.06                        ; the bottom of the dip: not silence, near it
 (slop-song-vol g)
  (: gap (slop-gap g) sp (g 'span) lo (g 'gmin)
     d (g 'wtop - g 'bt)            ; rows of scroll still to come before the sand
     h (g 'r // 2)
     v (? (sp <= gap) 1.0
          (lo < gap) (: q ((gap - lo) * 1.0 / ((sp - lo) * 1.0))
                        s (q * q * (3.0 - 2.0 * q))
                      (song-floor + (1.0 - song-floor) * s))
          (h <= d) song-floor
          (0 < d) ((h - d) * 1.0 / (h * 1.0) @ u
                   (song-floor + (1.0 - song-floor) * u))
          1.0)
   (? (v < song-floor) song-floor (1.0 < v) 1.0 v))

 ; a triangle in phase with the sine (play.l's i-tri starts at -1, a quarter behind)
 (song-tri u) (u * 4.0 @ v
                 ((u < 0.25) * v
                  + ((u >= 0.25) * (u < 0.75)) * (2.0 - v)
                  + (u >= 0.75) * (v - 4.0)))
 ; the dial in three steps, sine, triangle, square: no crossfade, which would build both
 ; shapes in tray ops a voice a chunk. m is per voice, so the arm is taken once
 (slop-song-wave tp f m)
  (? (m < 0.34) (sin (tp * tau * f))
     (m < 0.67) (song-tri (tp * f % 1.0))
     (tp * f % 1.0 @ u ((u < 0.5) * 2.0 - 1.0)))
 ; a voice's waveform depends only on note, shape and length, so each is laid once and
 ; kept, padded a chunk of silence each end; a chunk is then one snip, else laid long
 song-waves {}
 (song-wave-of nt f m dur rate)
  (: k [nt (m < 0.34 ? 0 (m < 0.67 ? 1 2)) dur]
     w (song-waves k)
     (tray? w ? w
        (: t ((iota (int (dur * rate) + 2 + 2 * song-chunk) - song-chunk) * (1.0 / rate))
           tp (t * (t > 0.0))
           v (slop-song-wave tp f m * venv tp dur * (t < dur))
           (pin song-waves k v,
            v))))

 ; a voice m along the dial at volume vol; not mkvoice, whose instrument is a name
 (song-voice st v rate m vol)
  (: dur (vnum v 'legato 0.30)
     nt  (vnum v 'note (vnum v 'n 0))
     f   (261.6255653005986 * exp (nt * ln2-12))
     amp (vnum v 'gain 1.0 * vol)
     pn  (vnum v 'pan 0.5)
     end (st + int (dur * rate) + 2)
     w   (song-wave-of nt f m dur rate)
     ; no (t >= 0.0) mask: tp is zero before the onset and venv is zero at zero
     fn  (ix \ (: k0 (peep ix 0 0 - st + song-chunk) n #ix
                  (0 <= k0 && k0 + n <= #w ? (snip w k0 (k0 + n))
                     (: t  ((ix - st) * (1.0 / rate))
                        tp (t * (t > 0.0))
                      (slop-song-wave tp f m * venv tp dur * (t < dur))))))
   [end fn (amp * (1.0 - pn)) (amp * pn)])
 (slop-song-new tune h) {'tune tune 'h h 'fpos 0 'cyc 0 'next 0 'vs ()}
 ; one cycle's onsets as [start voice], cycle at frame st, spc frames long: the start
 ; lets the mixdown skip a voice not yet begun, which is silent but not free
 (song-voices s c st spc m vol)
  (filter two?
          (map (x \ (: at (st + int (spc * qnum (evwb x - qi c)))
                       v (song-voice at (evv x) song-rate m vol)
                     (two? v ? [at v])))
               (filter onset? (s 'tune (qi c) (qi (c + 1))))))
 ; one chunk out the horn. whole cycles are scheduled at the speed in force, so a tempo
 ; change lands on a bar line; the blocking write is the frame loop's clock
 (slop-song-feed s sp m vol)
  (: spc (int (song-rate / (song-cps * sp)))
     (fill _) (s 'next <= s 'fpos + song-chunk ?
                 (pin s 'vs (cat (s 'vs) (song-voices s (s 'cyc) (s 'next) spc m vol)),
                  (pins s 'cyc (s 'cyc + 1) 'next (s 'next + spc)),
                  fill ()))
     _ (fill ())
     (song-out s song-chunk song-gain))

 (presses n) (show n + (n = 1 ? " press" " presses"))
 ; the bar stops a column short of the screen: a console that wraps at its edge would
 ; scroll the map for a bar that reached it
 (slop-bar-fit g) (snip (slop-bar g) 0 (g 'c - 1))
 (slop-bar g) (? (g 'over = 'taken) ("the slop has you -- " + presses (g 'spent) + " spent")
                 (g 'over) ("you turn back -- " + presses (g 'spent) + " spent")
                 (show (slop-gap g) + " to go  "
                  + show (g 'spent) + " spent  "
                  + (g 'msg || "forward: k or up; q leaves")))

 ; --- slop on the tty: a poll loop, not stage, which would block on a key. the walk
 ; takes the screen as its caller raised it and answers the game it played ---
 ; the sign is deaf for sign-settle ms, so keys typed at the tower's ring do not close it
 sign-settle 500                                        ; ms the sign is deaf for
 (slop-sign g tk pn)
  (: both (tk && pn)
     vs (both ? [tk pn] (tk ? [tk] [pn]))
     rows (both ? sign-both (tk ? sign-tok sign-pnn))
     head (map (l \ fill l vs) rows)
     (say out (sign-over (slop-frame g) sign-ttl (head + sign-rest) 0 (g 'r) (g 'c)),
      flush out,
      settle sign-settle,
      edkey in))

 (slop-walk tk pn) (: ws (ttysize 7 19)
             r (<ws - 1) c <>ws
             g (slop-new r c (wheel (clock 0)))
             ; no card and the walk is silent
             tune (slop-tune ())
             hn (horn song-rate 2 @ r (nom? r ? () r))
             sng (hn ? (slop-song-new tune hn))
             ; with a horn the song's write is the clock; without one, rest is
             (beat-out sp m vol) (sng ? (slop-song-feed sng sp m vol) (rest 33))
             ; since is beats since the last frame
             (swim since) (g 'over ? ()
                         (: keys (key-drain g repeat-gap (k \ slop-key g k))   ; a held key at the tower's pace
                            _ (g 'over ? () (slop-tick g))
                            due (!hn || frame-due? song-yield (horn-lag hn) (0 < keys) since)
                            (due ? (say out (slop-frame g), flush out),
                             (beat-out (slop-song-speed g) (slop-song-edge g) (slop-song-vol g),
                              swim (due ? 0 (since + 1))))))
             _ (say out (esc + "[?25l"))
             _ (tk || pn ? (slop-sign g tk pn))
             _ (swim 0)
             ; taken: the flood runs at full rate, song too, for half a second; it drains
             ; keys so none are left queued for the shell
             (flood n t) (0 < n ? (drain-keys (),
                                   (say out (slop-flood g t), flush out,
                                    beat-out 1.0 1.0 1.0),
                                   flood (n - 1) (t + beat)))
             (g 'over = 'taken ? (flood 15 (g 't)),
              hn ? (flush hn, close hn),
              g))

 ; ..and the verb around it: the screen raised and put back here
 (slop-run tk pn) (: g (ttytake rove-modes, mind (_ \ slop-walk tk pn) () (_ \ (drain-keys (), ttygive rove-modes)))
                  (puts (g 'over @ 'taken ("the slop has you, " + presses (g 'spent) + " in\n")
                                          ("you turn back, " + presses (g 'spent) + " in\n")),
                   0))
 slop-usage "usage: love lore slop [token] [pennies]   (what you bring; forward is k or up, q or esc leaves)"
 ; the two optional words, either order: a number is pennies, anything else the token
 (slop-args as) (:- (go as () ()) (go l tk pn) (atom? l ? [tk pn]
                 (: t <l n (unum t) (charm? n ? (go >l tk n) (go >l t pn)))))
 (slop-main as) (2 < #as ? (say err ("slop: " + slop-usage + "\n"), flush err, 2)
                    (slop-args as @ p (slop-run <p <>p)))
 _ ((cite 'lore 'lore-enlist) 'slop (udoor 'slop slop-main slop-usage 1 1)))
) ; module slop
