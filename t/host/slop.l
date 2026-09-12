; --- t/host/slop.l: the slop, headless ---
; not in the t/*.l corpus (it loads a crew module). the game is pure love, so
; everything but the tty runner gates here: the fresh map, the cost ladder and the
; rate that rides it, a press banked and a square spent, the helm refusing all but
; forward, the two kinds of square either side of the climb line, the ground as a
; function of where it is, and the frame. slop-run is ink's swim loop over exactly
; these, and t/host/tty.l plays the shimmer on a pty.
;   cat t/00-init.l t/host/slop.l | b/love

(borrow 'slop)   ; the artifact's module, warm from the tree

(: (find h n i) (? (i + tally n < 1 + tally h)
                  (? (n = snip h i (i + tally n)) 1 (find h n (i + 1)))
                  0)
   (has? h n) (find h n 0)
   ; press k until the game says otherwise; answers the presses spent
   (drive g p) (: (go n) (? (g 'over) n (p g) n (slop-key g 107, go (n + 1))) (go 0))
   at-line (h \ (slop-sy h) <= (h 'climb)))

; --- the fresh map: slop on the skyline, you on the road at the foot ---
(: g (slop-new 23 80 (wheel 11))
 (test
  (2 = g 'brim)                                  ; three rows of slop, no more
  (22 = slop-sy g)                               ; you stand on the last row
  (0 = g 'wtop)                                  ; nothing has scrolled
  (15 = g 'climb)                                ; the climb line, a third of the way up
  (20 = g 'span)                                 ; the gap you are given
  (20 = slop-gap g)                              ; all of it still to go
  (0 = g 'spent)
  !(g 'over)))

; --- the ladder: a square costs ceil(span / gap), so one press far off and span
; of them at the brim; rate is its reciprocal, and it only ever falls ---
(: g (slop-new 23 80 (wheel 11))
   (put-gap gp) (pin g 'w (gp + (g 'brim) + (g 'wtop)))
   (at gp) (: _ (put-gap gp) (slop-cost g))
   (rate-at gp) (: _ (put-gap gp) (slop-rate g))
   costs (map (gp \ at gp) (rev ^21))            ; gap 20 down to 0
   (rising? l) (l @- 1 (a . b . r) (? (b < a) 0 (rising? (b . r))))
 (test
  (1 = at 20)                                    ; the first square is one press
  (20 = at 1)                                    ; the last is the whole walk over again
  (rising? costs)                                ; cost never falls as you close
  (1.0 = rate-at 20)
  (rate-at 1 < rate-at 20)                       ; and the rate falls with it
  (0 < rate-at 1)))                              ; but never to a standstill

; --- a press is banked, and a bankful is spent on a square ---
(: g (slop-new 23 80 (wheel 11))
   _ (slop-push g)                               ; gap 20, cost 1: one press, one square
   y1 (slop-sy g)
   _ (slop-push g)                               ; gap 19, cost 2: banked, no square yet
   y2 (slop-sy g) p2 (g 'push)
   _ (slop-push g)
   y3 (slop-sy g) p3 (g 'push)
 (test
  (21 = y1) (21 = y2) (20 = y3)
  (1 = p2) (0 = p3)                              ; the bank empties into the square
  (3 = g 'spent)))                               ; every press is counted

; --- the helm: only forward moves you, and q or esc steps off the map ---
(: g (slop-new 23 80 (wheel 11))
   _ (slop-key g 106)                            ; j -- back the way you came
   back (slop-sy g)
   _ (slop-key g 108)                            ; l -- sideways
   side (slop-sy g)
   _ (slop-key g 122)                            ; z -- no steer at all
   none (slop-sy g)
   _ (slop-key g -8)                             ; the up arrow is forward
   fwd (slop-sy g)
   _ (slop-key g 113)
 (test
  (22 = back) (22 = side) (22 = none)            ; nothing but forward carries you
  (21 = fwd)
  (1 = g 'spent)                                 ; and nothing but forward is spent
  ('fled = g 'over)
  (has? (slop-bar g) "turn back")))

; --- an ended game is closed: further keys neither move you nor spend ---
(: g (slop-new 23 80 (wheel 11))
   _ (slop-key g 27)
   _ (slop-key g 107)
 (test ('fled = g 'over) (22 = slop-sy g) (0 = g 'spent)))

; --- below the climb line every square is yours: you rise, and nothing else moves ---
(: g (slop-new 23 80 (wheel 11))
   n (drive g at-line)
 (test
  (15 = slop-sy g)                               ; you walked up to the line
  (13 = n)                                       ; 1+2+2+2+2+2+2 presses for seven squares
  (2 = g 'brim)                                  ; the slop has not stirred
  (0 = g 'wtop)                                  ; and nothing has scrolled
  (13 = slop-gap g)))

; --- at the line a square is one of two things, and the gap closes either way ---
; yours: you rise a row and the world holds still. the slop's: the world scrolls under
; you -- wtop down one, you where you were -- and the slop takes the row you would have
; had. thirteen of them close the last thirteen rows.
(: g (slop-new 23 80 (wheel 11))
   _ (drive g at-line)
   (lawful? h) (: y0 (slop-sy h) b0 (h 'brim) t0 (h 'wtop) gap0 (slop-gap h)
                  _ (slop-step h)
                  mine (((slop-sy h) = (y0 - 1)) && ((h 'brim) = b0) && ((h 'wtop) = t0))
                  slop (((slop-sy h) = y0) && ((h 'brim) = (b0 + 1)) && ((h 'wtop) = (t0 - 1)))
                (? (mine || slop) ((slop-gap h) = (gap0 - 1)) 0))
   (steps n ok) (? (g 'over) [n ok] (: k (lawful? g) (steps (n + 1) (ok && k))))
   r (steps 0 1)
 (test
  (13 = r 0)                                     ; thirteen squares from the line
  (r 1)                                          ; every one of them lawful
  ('taken = g 'over)
  (2 < g 'brim)                                  ; the slop came down for some of them
  (g 'wtop < 0)                                  ; ..and the ground scrolled with it
  ((slop-sy g) = (g 'brim))))                    ; you end level with the brim -- in it

; --- the whole walk: the press count is the ladder's sum, and it does not vary ---
(: (run st) (: g (slop-new 23 80 st)
               (go n) (? (g 'over) [n (g 'brim) (slop-sy g)] (slop-key g 107, go (n + 1)))
               (go 0))
   runs (map (i \ run (wheel (100 + i))) ^12)
   brims (map (r \ r 1) runs)
   press (map (r \ r 0) runs)
   mid (23 // 2)                                 ; 11: the middle row of the screen
 (test
  (all (p \ (p = 80)) press)                     ; 80 presses for 20 squares, every seed
  (all (r \ ((r 1) = (r 2))) runs)               ; you end level with the brim -- in it
  (all (b \ (2 < b < 22)) brims)                 ; the slop never reaches the foot
  (mid < ((net brims) / 12.0))))                 ; ..and on the whole lands past the middle

; --- the ground is a function of where it is, so a scroll costs nothing ---
(: g (slop-new 23 80 (wheel 11))
   r0 (slop-road g -7)
   t0 (slop-turf g -7 3)
   _ (drive g (h \ ((h 'wtop) < -2)))            ; walk far enough to scroll
   ws (map (i \ (i - 40)) ^120)
 (test
  (0 > g 'wtop)                                  ; the ground did scroll
  (r0 = slop-road g -7)                          ; the road at a world row is that row's
  (t0 = slop-turf g -7 3)                        ; and so is the ground beside it
  !((slop-road g 0) = (slop-road g 8))           ; ..but it does wander
  (all (w \ (1 < (slop-road g w) < 78)) ws)      ; and never off the width
  ; the narrowest screen the runner will hand over is 20 columns, and the road
  ; wanders five either way with a shoulder on each side
  (: n (slop-new 23 20 (wheel 11))
   (all (w \ (0 < (slop-road n w) < 19)) ws))))

; a turf cell is a glyph and a pen: grass, a shrub, or the road's bare dirt
(: g (slop-new 23 80 (wheel 11))
   cells (map (x \ slop-turf g 4 x) ^80)
   road (slop-road g 4)
 (test
  (all (c \ ((<c = 46) || (<c = 34) || (<c = 35))) cells)      ; . " or # and nothing else
  (all (c \ (21 < <>c < 138)) cells)                           ; and a pen out of the two ramps
  (46 = <(slop-turf g 4 road))                                 ; the road is bare dirt
  (all (d \ (93 < <>(slop-turf g 4 (road + d)) < 138)) '(-1 0 1))   ; three columns of brown
  (all (w \ (46 = <(slop-turf g w (slop-road g w)))) ^40)))    ; and it is road all the way up

; --- the frame: slop on the skyline, ground under it, you on the road ---
(: g (slop-new 23 80 (wheel 11))
   _ (slop-tick g)
   f (slop-frame g)
 (test
  (string? f)
  (has? f "\e[H")                                ; home, then the whole screen
  (has? f "\e[48;5;220m" || has? f "\e[48;5;199m" || has? f "\e[48;5;217m")  ; the slop's pens
  (has? f "\e[38;5;94m" || has? f "\e[38;5;130m" || has? f "\e[38;5;137m")   ; the road's dirt
  (has? f "\e[38;5;34m" || has? f "\e[38;5;28m" || has? f "\e[38;5;71m")     ; and the grass
  (has? f "\e[38;5;231m") (has? f "@")           ; you, white, on the road
  (has? f "\"")                                  ; a tuft of it
  (has? f "\e[K") (has? f "\r\n")
  (has? f "press 1 for a square")
  (has? f "20 to go")))

; a ground row is the same string every time, so it is painted once and kept
(: g (slop-new 23 80 (wheel 11))
   f1 (slop-frame g)
   f2 (slop-frame g)
 (test (f1 = f2) (0 < tally (keys (g 'rows)))))

; a run of equal cells is one pen, not one per cell: the smooth field is mostly runs
(: g (slop-new 12 24 (wheel 11))
   f (slop-frame g)
   (pens s i n) (? (i + 5 < #s) (pens s (i + 1) (n + (? (has? (snip s i (i + 5)) "[48;5") 1 0))) n)
 (test (pens f 0 0 < 3 * 24)))                   ; 3 slop rows, well under a pen a cell

; --- the clock slows with the walk: the same beat buys less phase further in ---
(: g (slop-new 23 80 (wheel 11))
   t0 (g 't)
   _ (slop-tick g)
   far (g 't - t0)
   _ (pin g 'w (1 + (g 'brim) + (g 'wtop)))      ; one square short of the brim
   t1 (g 't)
   _ (slop-tick g)
   near (g 't - t1)
 (test
  (0.0 < near) (near < far)
  (|(far - 20.0 * near) < 0.000001)))            ; exactly the rate, span to one

(test_fin ())
(puts "slop: ok")
