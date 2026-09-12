; slop -- rove's second game: the walk into a thing that will not let you arrive.
;
; a road through grass, and somewhere ahead of it a shore. the slop lies beyond that
; shore -- ink's skin (ink-field) under a gold-pink-yellow ramp -- but at the first
; frame it is well above the top and there is nothing to see but field. you
; stand on the road at the foot and the only steer that answers is forward.
;
; every square you pay for carries you one world row forward. below the climb line, a
; third of the way up, the row is yours and you rise on the screen. at it or above, one
; square in ten is still yours and the other nine scroll the ground down under you --
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
; slop in it is painted once and kept by world row.
;
; run: love slop
; the game is pure love -- slop-new, slop-key, slop-tick and slop-frame are state in
; and state out, gated headless by t/host/slop.l; only slop-run ties the tty (raw /
; tty / cue?, over i/posix.c), so slop never joins the corpus. ink lends the skin and
; the palette, rove the helm and the die.
(module (slop slop-run slop-main slop-new slop-sy slop-gap slop-cost slop-rate
         slop-step slop-push slop-key slop-tick slop-frame slop-bar slop-road slop-turf
         slop-shore slop-sand slop-wet?)
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
 ; past the climb line one square in ten is your own step; the other nine scroll, and
 ; that ratio is what lands the shore on you just past the middle of the screen
 own-odds 10

 ; --- the lie of the land: sines across the columns, a hash within them ---
 ; two multiply-shift rounds masked to 32 bits, for the grass
 lim 4294967296
 (mix a) (: h ((a * 2654435761) % lim)
            h2 ((h ^ (h >> 15)) * 2246822519 % lim)
            (h2 ^ (h2 >> 13)))
 (dice w x k) ((mix ((w * 374761393) + (x * 668265263) + 1)) % k)
 ; the road wanders on two sines a screen and a few screens long -- so it bends where
 ; you can see it, never repeats, and never leaves the width
 (slop-road g w) (: mid ((g 'c) // 2)
                    (mid + int ((3.0 * sin (w * 0.21)) + (2.0 * sin (w * 0.063)))))
 ; the shoreline and the depth of beach behind it: two sines each, wavy the way the road
 ; is wavy. the amplitude-times-frequency sum is what matters -- keep it under one row a
 ; column and the quantized edge steps one row at a time and reads as a coast; let it
 ; over and the edge drops two rows at once and the whole thing reads as a skyline.
 ; here the shore is 0.61 and the sand 0.42.
 (shore-wave x) (int ((3.0 * sin (x * 0.17)) + (1.8 * sin (x * 0.058))))
 (sand-deep x) (4 + int ((1.5 * sin (x * 0.23)) + (0.9 * sin (x * 0.081))))
 ; the mean shoreline: half a screen and a little more above the first frame's top, but
 ; never nearer than the deepest beach the columns actually laid, so the opening screen
 ; is field and nothing else on a short terminal too
 (shore0 r top) (: v ((0 - (r // 2)) - 4) w (0 - (1 + top)) (v < w ? v w))

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
 (slop-turf g w x)
  (: h (dice w x 120)
     s ((slop-shore g x) + slop-sand g x)        ; this column's last row of beach
   (? (w <= s) [46 (sand-pens (h % 4))]
      (: rx (slop-road g w)
         d (w - ((slop-shore g rx) + slop-sand g rx))    ; rows of grass the road has left
         hw (? (d < 0) 4 (d < 4) (4 - d) 1)
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
     g {'r r 'c c 'wtop 0 'w (r - 1) 'shore0 sh0 'shores shores 'sands sands
        'wetto wetto 'climb ((r - 1) - (r // 3)) 'drag (r - 3)
        'push 0 'spent 0 't 0.0 'msg "" 'over 0
        'sb {st} 'rows {} 'field (ink-field r c)}
   (pin g 'span (slop-gap g), g))

 ; where you stand on the screen, and the rows between you and the slop at your own
 ; column. a square costs ceil(drag / gap), so it is one press until the shore is about
 ; a screen out and a screen's worth for the last one; rate is squares per press.
 (slop-sy g) ((g 'w) - (g 'wtop))
 (slop-gap g) ((g 'w) - slop-shore g (slop-road g (g 'w)))
 (slop-cost g) (: gap (slop-gap g) (gap < 1 ? (g 'drag) (((g 'drag) + gap - 1) // gap)))
 (slop-rate g) (1.0 / slop-cost g)

 ; one square forward. you always cross a world row; what differs is who the row on the
 ; screen goes to. below the climb line it is yours and you rise; at it or above it is
 ; mostly not, and then the ground scrolls under you instead and the shore comes on.
 (slop-step g)
  (: own (? ((slop-sy g) > (g 'climb)) 1 (0 = roll (g 'sb) own-odds))
     seen ((g 'wtop) <= (g 'wetto))              ; is any of it on the screen yet?
     _ (pin g 'w ((g 'w) - 1))
     _ (? own (pin g 'msg "a square")
              (pins g 'wtop ((g 'wtop) - 1)
                      'msg (seen ? "the slop comes on" "you walk on")))
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

 ; --- the frame ----------------------------------------------------------------
 ; a row below the shoreline's lowest reach is all ground, so it is painted once and
 ; kept by world row; only the row you stand on and the rows the shore cuts are laid
 ; fresh. a pen goes out only where it changes, so a row is a handful of runs.
 (turf-line g w px)
  (: j (jug 0)
     (go x f) (? (x < (g 'c))
                 (: cell (slop-turf g w x)
                    gl (? (x = px) 64 <cell)
                    hue (? (x = px) 231 <>cell)
                    _ (? (hue = f) () (say j (esc + "[38;5;" + show hue + "m")))
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
               _ (? wet () (say j (esc + "[0m")))
               _ (? (wet && (n = p)) () (say j (pal n)))
               _ (say j (? (x = px) sunk (w = slop-shore g x) surf " "))
             (go (x + 1) 1 n -1))
            (: cell (slop-turf g w x)
               gl (? (x = px) 64 <cell)
               hue (? (x = px) 231 <>cell)
               _ (? wet (say j (esc + "[0m")) ())
               _ (? (hue = f) () (say j (esc + "[38;5;" + show hue + "m")))
               _ (say j (string gl))
             (go (x + 1) 0 -1 hue)))
         ())
     _ (go 0 0 -1 -1)
   (slurp j))

 (slop-frame g) (:
   j (jug 0) r (g 'r) wtop (g 'wtop) wetto (g 'wetto) fld (g 'field)
   k (((fld (g 't) + 4.001) * 2.9) // 1)
   sy (slop-sy g) px (slop-road g (g 'w))
   ; where the shore has closed over you, a dark mark is all that says so
   sunk (esc + "[38;5;52m@" + esc + "[39m")
   (line i) (: w (wtop + i) me (? (i = sy) px -1)
             (? (wetto < w) (turf-row g w me) (wet-line g w i k me sunk)))
   (lines i) (i < r ? (say j (line i + esc + "[0m" + esc + "[K\r\n"), lines (i + 1)))
   _ (say j (esc + "[H"))
   _ (lines 0)
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
