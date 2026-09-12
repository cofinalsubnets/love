; --- t/host/slop.l: the slop, headless ---
; not in the t/*.l corpus (it loads a crew module). the game is pure love, so
; everything but the tty runner gates here: the fresh map's halves, the cost ladder
; and the rate that rides it, a press banked and a square spent, the helm refusing
; everything but forward, the clock slowing with the walk, and the frame. slop-run is
; ink's swim loop over exactly these, and t/host/tty.l plays the shimmer on a pty.
;   cat t/00-init.l t/host/slop.l | b/love

(borrow 'slop)   ; the artifact's module, warm from the tree

(: (find h n i) (? (i + tally n < 1 + tally h)
                  (? (n = snip h i (i + tally n)) 1 (find h n (i + 1)))
                  0)
   (has? h n) (find h n 0))

; --- the map: the slop takes the top half, you stand on the bottom row ---
(: g (slop-new 23 80)
 (test
  (10 = g 'brim)                                 ; rows 0..10 are slop
  (22 = g 'y)                                    ; you are on the last row
  (40 = g 'x)                                    ; and the middle column
  (12 = g 'span)                                 ; the walk you are given
  (12 = slop-gap g)                              ; all of it still to go
  (0 = g 'spent)
  !(g 'over)))

; --- the ladder: a square costs ceil(span / gap), so one press far off and span
; of them at the brim; rate is its reciprocal, and it only ever falls ---
(: g (slop-new 23 80)
   (at gp) (: _ (pin g 'y (gp + g 'brim)) (slop-cost g))
   costs (map at (rev ^13))                      ; gap 12 down to 0
   (rising? l) (l @- 1 (a . b . r) (? (b < a) 0 (rising? (b . r))))
   (rates gp) (: _ (pin g 'y (gp + g 'brim)) (slop-rate g))
 (test
  (1 = at 12)                                    ; the first square is one press
  (12 = at 1)                                    ; the last is the whole walk over again
  (rising? costs)                                ; cost never falls as you close
  (1.0 = rates 12)
  (rates 1 < rates 12)                           ; and the rate falls with it
  (0 < rates 1)))                                ; but never to a standstill

; --- a press is banked, and a bankful is spent on a square ---
(: g (slop-new 23 80)
   _ (slop-push g)                               ; gap 12, cost 1: one press, one square
   y1 (g 'y)
   _ (slop-push g)                               ; gap 11, cost 2: banked, no square yet
   y2 (g 'y) p2 (g 'push)
   _ (slop-push g)
   y3 (g 'y) p3 (g 'push)
 (test
  (21 = y1) (21 = y2) (20 = y3)
  (1 = p2) (0 = p3)                              ; the bank empties into the square
  (3 = g 'spent)))                               ; every press is counted

; --- the helm: only forward moves you, and q or esc steps off the map ---
(: g (slop-new 23 80)
   _ (slop-key g 106)                            ; j -- back the way you came
   back (g 'y)
   _ (slop-key g 108)                            ; l -- sideways
   side (g 'y)
   _ (slop-key g 122)                            ; z -- no steer at all
   none (g 'y)
   _ (slop-key g -8)                             ; the up arrow is forward
   fwd (g 'y)
   _ (slop-key g 113)
 (test
  (22 = back) (22 = side) (22 = none)            ; nothing but forward carries you
  (21 = fwd)
  (1 = g 'spent)                                 ; and nothing but forward is spent
  ('fled = g 'over)
  (has? (slop-bar g) "turn back")))

; --- an ended game is closed: further keys neither move you nor spend ---
(: g (slop-new 23 80)
   _ (slop-key g 27)
   _ (slop-key g 107)
 (test ('fled = g 'over) (22 = g 'y) (0 = g 'spent)))

; --- the whole walk: forward until the slop has you, ~span * H(span) presses ---
(: g (slop-new 23 80)
   (walk n) (? (g 'over) n (slop-key g 107, walk (n + 1)))
   n (walk 0)
 (test
  ('taken = g 'over)
  (n = g 'spent)
  (g 'span < n)                                  ; the walk costs more than its squares
  (n < 4 * g 'span)                              ; and stays inside a playable ladder
  (g 'y <= g 'brim)                              ; you are in it
  (has? (slop-bar g) "the slop has you")))

; --- the clock slows with the walk: the same beat buys less phase further in ---
(: g (slop-new 23 80)
   t0 (g 't)
   _ (slop-tick g)
   far (g 't - t0)
   _ (pin g 'y (1 + g 'brim))                    ; one square short of the brim
   t1 (g 't)
   _ (slop-tick g)
   near (g 't - t1)
 (test
  (0.0 < near) (near < far)
  (|(far - 12.0 * near) < 0.000001)))            ; exactly the rate, span to one

; --- the frame: the slop's rows painted, the bare rows cleared, you on one of them ---
(: g (slop-new 12 24)
   _ (slop-tick g)
   f (slop-frame g)
 (test
  (string? f)
  (has? f "\e[H")                                ; home, then the whole screen
  (has? f "\e[48;5;220m" || has? f "\e[48;5;199m" || has? f "\e[48;5;217m")  ; the slop's own pens
  (has? f "\e[38;5;231m") (has? f "@")           ; and you, the one glyph below it
  (has? f "\e[K")                                ; a bare row is cleared to its end
  (has? f "\r\n")                                ; frames ride \r\n
  (has? f "press 1 for a square")
  (has? f "6 to go")))

; a run of equal cells is one pen, not one per cell: the smooth field is mostly runs
(: g (slop-new 12 24)
   f (slop-frame g)
   (pens s i n) (? (i + 5 < #s) (pens s (i + 1) (n + (? (has? (snip s i (i + 5)) "[48;5") 1 0))) n)
 (test (pens f 0 0 < 6 * 24)))                   ; 6 slop rows, well under a pen a cell

(test_fin ())
(puts "slop: ok")
