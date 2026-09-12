; slop -- rove's second game: the walk into a thing that will not let you arrive.
;
; a road through grass, and slop on the skyline: three rows of it at the top, ink's
; skin (ink-field) under a gold-pink-yellow ramp. you stand on the road at the foot of
; the screen and the only steer that answers is forward. a square costs
; ceil(span / gap) presses, so the first is one and the last is the whole walk over
; again -- and the slop's own clock is scaled by that same rate, so it thickens as you
; do. past the climb line, a third of the way up, the square you paid for is mostly not
; yours: the world scrolls under you instead and the slop takes the row you would have
; had, so the two of you close on a meeting just past the middle of the screen.
;
; the ground is a pure function of where it is -- slop-turf hashes (world row, column)
; into grass and slop-road puts the path on two sines -- so scrolling costs nothing and
; the same road is there when it comes back. a painted row is cached by world row.
;
; run: love slop
; the game is pure love -- slop-new, slop-key, slop-tick and slop-frame are state in
; and state out, gated headless by t/host/slop.l; only slop-run ties the tty (raw /
; tty / cue?, over i/posix.c), so slop never joins the corpus. ink lends the skin and
; the palette, rove the helm and the die.
(module (slop slop-run slop-main slop-new slop-sy slop-gap slop-cost slop-rate
         slop-step slop-push slop-key slop-tick slop-frame slop-bar slop-road slop-turf)
(borrow 'ink)
(borrow 'rove)
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
 brim0 2                                ; the skyline: three rows of slop to begin with
 ; past the climb line one square in five is your own step; the other four are the
 ; slop's, and that ratio is what lands the two of you just past the middle
 own-odds 5

 ; --- the ground: a hash of where it is, so a scroll costs nothing ---
 ; two multiply-shift rounds, masked to 32 bits; the pens are xterm's 256
 lim 4294967296
 (mix a) (: h ((a * 2654435761) % lim)
            h2 ((h ^ (h >> 15)) * 2246822519 % lim)
            (h2 ^ (h2 >> 13)))
 (dice w x k) ((mix ((w * 374761393) + (x * 668265263) + 1)) % k)
 ; the road wanders on two sines a screen and a few screens long -- so it bends where
 ; you can see it, never repeats, and never leaves the width
 (slop-road g w) (: mid ((g 'c) // 2)
                    (mid + int ((3.0 * sin (w * 0.21)) + (2.0 * sin (w * 0.063)))))
 road-pens [94 130 137]                 ; dirt, three shades of it
 turf-pens [22 28 34 65 71]             ; grass, dark to bright
 ; one cell of ground: (glyph . pen). the grass is mostly tufts, with bare ground and
 ; a shrub here and there; the road is bare dots throughout, so the path reads as one
 (slop-turf g w x)
  (: d |(x - slop-road g w)
     h (dice w x 120)
   (? (d <= 1)  [46 (road-pens (h % 3))]
      (h < 9)   [35 (turf-pens (h % 2))]
      (h < 27)  [46 (turf-pens (h % 3))]
                [34 (turf-pens (2 + (h % 3)))]))

 ; --- the walk -----------------------------------------------------------------
 ; a fresh game on an r by c screen, from a seeded rng state: you stand on the road
 ; at the foot, the slop is the top few rows, and span is the gap you are given
 (slop-new r c st) {'r r 'c c 'wtop 0 'w (r - 1) 'brim brim0
                    'climb ((r - 1) - (r // 3)) 'span ((r - 1) - brim0)
                    'push 0 'spent 0 't 0.0 'msg "" 'over 0
                    'sb {st} 'rows {} 'field (ink-field r c)}

 ; where you stand on the screen, and how many rows of it are left between you and
 ; the slop. a square costs ceil(span / gap), so the first is one press and the last
 ; is span of them; rate is squares per press, and the slop's clock rides it.
 (slop-sy g) ((g 'w) - (g 'wtop))
 (slop-gap g) ((slop-sy g) - (g 'brim))
 (slop-cost g) (: gap (slop-gap g) (gap < 1 ? (g 'span) (((g 'span) + gap - 1) // gap)))
 (slop-rate g) (1.0 / slop-cost g)

 ; one square forward. you always cross a world row; what differs is who the row on
 ; the screen goes to. below the climb line it is yours and you rise; at it or above
 ; it is mostly the slop's, and then the world scrolls under you instead. either way
 ; the gap closes by one, and closing it to nothing ends the walk.
 (slop-step g)
  (: own (? ((slop-sy g) > (g 'climb)) 1 (0 = roll (g 'sb) own-odds))
     _ (pin g 'w ((g 'w) - 1))
     _ (? own (pin g 'msg "a square")
              (pins g 'wtop ((g 'wtop) - 1) 'brim ((g 'brim) + 1) 'msg "the slop comes on"))
   (slop-gap g < 1 ? (pins g 'over 'taken 'msg "the slop has you")))

 ; one press of forward effort: bank it, and spend a bankful on a square
 (slop-push g) (: n ((g 'push) + 1)
                  _ (pin g 'spent ((g 'spent) + 1))
                  (? (n < slop-cost g) (pins g 'push n 'msg "")
                     (pin g 'push 0, slop-step g)))

 ; the helm is rove's: forward is any steer that climbs, and nothing else moves you.
 ; q or esc steps back off the map
 (slop-key g k) (: mv (steer k)
                   (? (g 'over) g
                      (k @ (113 || 27) 1 0) (pin g 'over 'fled)
                      !(two? mv) g
                      (<>mv < 0) (slop-push g)
                      (pin g 'msg "only forward")))

 ; one beat of the slop's own clock, scaled by how fast you are still moving
 (slop-tick g) (pin g 't ((g 't) + (beat * slop-rate g)))

 ; --- the frame: slop on the skyline, the ground under it ---
 ; a ground row is the same string every time it is asked for, so it is painted once
 ; and kept by world row; only the row you stand on is laid fresh
 (turf-line g w px)
  (: j (jug 0)
     (go q p) (? (q < (g 'c))
                 (: cell (slop-turf g w q)
                    gl (? (q = px) 64 <cell)
                    hue (? (q = px) 231 <>cell)
                    _ (? (hue = p) () (say j (esc + "[38;5;" + show hue + "m")))
                    _ (say j (string gl))
                  (go (q + 1) hue))
                 ())
     _ (go 0 -1)
   (slurp j + esc + "[39m"))
 (turf-row g w px)
  (: hit (? (px < 0) (peep (g 'rows) w ()) ())
   (? (string? hit) hit
      (px < 0) (: s (turf-line g w -1) (pin (g 'rows) w s, s))
      (turf-line g w px)))

 ; the slop quantizes onto the ramp's 24; a pen goes out only where the band changes,
 ; so a smooth row is a handful of runs
 (slop-frame g) (:
   j (jug 0) c (g 'c) r (g 'r) brim (g 'brim) fld (g 'field)
   k (((fld (g 't) + 4.001) * 2.9) // 1)
   sy (slop-sy g) px (slop-road g (g 'w))
   ; the brim row is painted over you, so sunk is the only mark left that says where
   sunk (esc + "[38;5;52m@" + esc + "[39m")
   (row i q p) (q < c ? (: n (int (peep k [i q] 0))
                         (n = p ? () (say j (pal n)),
                          say j (i = sy && q = px ? sunk " "),
                          row i (q + 1) n)))
   (slops i) (i <= brim ? (row i 0 -1, say j (esc + "[0m\r\n"), slops (i + 1)))
   (lands i) (i < r ? (say j (turf-row g ((g 'wtop) + i) (i = sy ? px -1) + esc + "[K\r\n"),
                       lands (i + 1)))
   _ (say j (esc + "[H"))
   _ (slops 0)
   _ (lands (brim + 1))
   _ (say j (slop-bar g + esc + "[K"))
   (slurp j))

 (presses n) (show n + (n = 1 ? " press" " presses"))
 (slop-bar g) (? (g 'over = 'taken) ("the slop has you -- " + presses (g 'spent) + " spent")
                 (g 'over) ("you turn back -- " + presses (g 'spent) + " spent")
                 ("press " + show (slop-cost g) + " for a square  "
                  + show (slop-gap g) + " to go  "
                  + show (g 'spent) + " spent  "
                  + (g 'msg || "forward: k or up; q leaves")))

 ; --- slop on the tty: the shimmer's swim loop with the keys drained per frame ---
 ; stage would block on a key and the slop has to keep moving while you do not, so
 ; this polls the way ink does: drain what is waiting, tick, paint, rest a beat
 (slop-run _) (: ws (tty 1)
             r (two? ws && 7 < <ws ? (<ws - 1) 23)
             c (two? ws && 19 < <>ws ? <>ws 80)
             g (slop-new r c (wheel (clock 0)))
             (drain _) (cue? 0 ? (slop-key g (edkey in), drain ()))
             (swim _) (? (g 'over) ()
                         (: _ (drain ())
                            _ (g 'over ? () (slop-tick g))
                            (say out (slop-frame g), flush out, rest 33, swim ())))
             _ (raw 1)
             _ (say out (esc + "[?1049h" + esc + "[?25l" + esc + "[2J"))
             _ (swim ())
             _ (g 'over = 'taken ? (rest 1200))   ; the end holds its frame for a beat
             _ (say out (esc + "[0m" + esc + "[?25h" + esc + "[?1049l"))
             _ (flush out)
             _ (raw 0)
             (puts (g 'over @ 'taken ("the slop has you, " + presses (g 'spent) + " in")
                                     ("you turn back, " + presses (g 'spent) + " in")),
              0))
 slop-usage "usage: love slop   (no options; forward is k or up, q or esc leaves)"
 ; slop takes nothing: a word here is a mistake, and the game would swallow it
 (slop-main as) (? !(two? as) (slop-run ())
                    (say err ("slop: takes no arguments, not " + <as + "\n"), flush err, 2))
 _ (pins (cite 'verbs 'tab) 'slop (udoor 'slop slop-main slop-usage 1 1)))
) ; module slop
