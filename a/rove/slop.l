; slop -- rove's second game: the walk into a thing that will not let you arrive.
;
; the top of the map is slop, a solid region shimmering on ink's skin (ink-field)
; under a gold-pink-yellow ramp; the bottom is bare, and you stand on its last row.
; the only steer that answers is forward. far off, a press is a square; closer in a
; square costs ceil(span / gap) presses, so the last one costs as many presses as the
; whole walk began with -- and the slop's own clock is scaled by that same rate, so as
; you slow it slows with you. reaching the brim ends it.
;
; run: love slop
; the game is pure love -- slop-new, slop-key, slop-tick and slop-frame are state in
; and state out, gated headless by t/host/slop.l; only slop-run ties the tty (raw /
; tty / cue?, over i/posix.c), so slop never joins the corpus. ink lends the skin and
; the palette, rove the helm.
(module (slop slop-run slop-main slop-new slop-gap slop-cost slop-rate slop-push
         slop-key slop-tick slop-frame slop-bar)
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

 ; a fresh game on an r by c screen: the slop takes the top half, you stand on the
 ; bottom row in the middle column, and span is the walk you are given
 (slop-new r c) (: brim (r // 2 - 1)    ; the slop's last row
                   y (r - 1)
                  {'r r 'c c 'brim brim 'x (c // 2) 'y y 'span (y - brim)
                   'push 0 'spent 0 't 0.0 'msg "" 'over 0
                   'field (ink-field (brim + 1) c)})

 ; the walk's arithmetic: gap squares left, a square costs ceil(span / gap), so the
 ; first is one press and the last is span of them. rate is squares per press, and
 ; the slop's clock rides it.
 (slop-gap g) (g 'y - g 'brim)
 (slop-cost g) (: gap (slop-gap g) (gap < 1 ? (g 'span) ((g 'span + gap - 1) // gap)))
 (slop-rate g) (1.0 / slop-cost g)

 ; one press of forward effort: bank it, and spend a bankful on a square
 (slop-push g) (: n (g 'push + 1)
                  _ (pin g 'spent (g 'spent + 1))
                  (? (n < slop-cost g) (pins g 'push n 'msg "")
                     (: _ (pins g 'push 0 'y (g 'y - 1))
                      (g 'y <= g 'brim ? (pins g 'over 'taken 'msg "the slop has you")
                                         (pin g 'msg "a square")))))

 ; the helm is rove's: forward is any steer that climbs, and nothing else moves you.
 ; q or esc steps back off the map
 (slop-key g k) (: mv (steer k)
                   (? (g 'over) g
                      (k @ (113 || 27) 1 0) (pin g 'over 'fled)
                      !(two? mv) g
                      (<>mv < 0) (slop-push g)
                      (pin g 'msg "only forward")))

 ; one beat of the slop's own clock, scaled by how fast you are still moving
 (slop-tick g) (pin g 't (g 't + beat * slop-rate g))

 ; --- the frame: the slop's rows on ink's skin, the bare rows under them ---
 ; the skin quantizes onto the ramp's 24; a pen goes out only where the band changes,
 ; so a smooth row is a handful of runs. a bare row is cleared to the line's end, and
 ; you are the one glyph on it
 (slop-frame g) (:
   j (jug 0) c (g 'c) brim (g 'brim) fld (g 'field)
   k (((fld (g 't) + 4.001) * 2.9) // 1)
   ; a slop cell is bare unless you went under at it -- the brim row is painted over
   ; you, and sunk is the only mark left that says where
   sunk (esc + "[38;5;52m@" + esc + "[39m")
   (row i q p) (q < c ? (: n (int (peep k [i q] 0))
                         (n = p ? () (say j (pal n)),
                          say j (i = g 'y && q = g 'x ? sunk " "),
                          row i (q + 1) n)))
   (slops i) (i <= brim ? (row i 0 -1, say j (esc + "[0m\r\n"), slops (i + 1)))
   you (esc + "[38;5;231m" + edpad "" (g 'x) " " + "@" + esc + "[0m")
   (bares i) (i < g 'r ? (say j ((i = g 'y ? you "") + esc + "[K\r\n"), bares (i + 1)))
   _ (say j (esc + "[H"))
   _ (slops 0)
   _ (bares (brim + 1))
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
             g (slop-new r c)
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
