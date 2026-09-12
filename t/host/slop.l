; --- t/host/slop.l: the slop, headless ---
; not in the t/*.l corpus (it loads a crew module). the game is pure love, so
; everything but the tty runner gates here: the opening screen with nothing on it but
; field, the shoreline's shape and the beach behind it, the road opening onto the sand,
; the cost ladder and the rate that rides it, a press banked and a square spent, the
; helm refusing all but forward, the two kinds of square either side of the climb line,
; the ground as a function of where it is, and the frame. slop-run is ink's swim loop
; over exactly these, and t/host/tty.l plays the shimmer on a pty.
;   cat t/00-init.l t/host/slop.l | b/love

(borrow 'slop)   ; the artifact's module, warm from the tree

(: (find h n i) (? (i + tally n < 1 + tally h)
                  (? (n = snip h i (i + tally n)) 1 (find h n (i + 1)))
                  0)
   (has? h n) (find h n 0)
   ; press k until the game says otherwise; answers the presses spent
   (drive g p) (: (go n) (? (g 'over) n (p g) n (slop-key g 107, go (n + 1))) (go 0))
   at-line (h \ (slop-sy h) <= (h 'climb))
   ; the pens tell the three grounds apart: grass below 94, road within, sand above
   (brown? c) (93 < <>c < 138)
   (sandy? c) (138 < <>c)
   (road-width g w) (tally (filter brown? (map (x \ slop-turf g w x) ^(g 'c)))))

; --- the first frame: a field, and nothing else on it ---
(: g (slop-new 23 80 (wheel 11))
   rows (map (i \ (g 'wtop) + i) ^23)
   xs ^80
   (dry? w) (all (x \ !(slop-wet? g w x)) xs)
   (green? w) (all (x \ (w > ((slop-shore g x) + slop-sand g x))) xs)
   f (slop-frame g)
 (test
  (all dry? rows)                                ; no slop anywhere on the screen
  (all green? rows)                              ; and no sand either -- field to the top
  !(has? f "\e[48;5;")                           ; which the frame says too: no slop pen
  !(has? f "\e[38;5;180m")                       ; nor any sand
  (has? f "\e[38;5;94m" || has? f "\e[38;5;130m")             ; the road is there
  (has? f "\e[38;5;34m" || has? f "\e[38;5;71m")))            ; and the grass

; the same on a short terminal, where half a screen up would not have cleared the beach
; and the offset falls back on the beach the columns actually laid
(: g (slop-new 11 40 (wheel 11))
   rows (map (i \ (g 'wtop) + i) ^11)
   top (foldl (\ a x (: v ((slop-shore g x) + slop-sand g x) (a < v ? v a))) -99 ^40)
 (test
  (top < 0)                                      ; the whole beach is above the first row
  (all (w \ (all (x \ !(slop-wet? g w x)) ^40)) rows)
  (all (w \ (all (x \ (w > ((slop-shore g x) + slop-sand g x))) ^40)) rows)))

; --- the shoreline: wavy, and it steps one row at a time ---
; amplitude times frequency under one row a column is what keeps the quantized edge
; stepping singly; let it over and the edge drops two at once and reads as a skyline
(: g (slop-new 23 80 (wheel 11))
   xs ^79
   steps (map (x \ |((slop-shore g (x + 1)) - slop-shore g x)) xs)
   shores (map (x \ slop-shore g x) ^80)
   srt (sort shores)
   (last l) (cap (rev l))
 (test
  (all (s \ (s <= 1)) steps)                     ; never a two-row drop
  (0 < tally (filter (s \ (s = 1)) steps))       ; but it does move
  (2 < ((last srt) - cap srt))                   ; bays and headlands, not a straight line
  (all (x \ (2 <= (slop-sand g x) <= 6)) ^80)))  ; and a beach of two to six rows behind it

; --- the ground in three bands: sand behind the line, grass in front, road through ---
(: g (slop-new 23 80 (wheel 11))
   x 30
   e (slop-shore g x)
   s (e + slop-sand g x)
 (test
  (slop-wet? g e x) !(slop-wet? g (e + 1) x)     ; the line is the slop's last row
  (sandy? (slop-turf g (e + 1) x))               ; the row in front of it is beach
  (sandy? (slop-turf g s x))                     ; and so is the beach's own last row
  !(sandy? (slop-turf g (s + 1) x))              ; the row after that is not
  (46 = <(slop-turf g s x))))                    ; sand is bare ground

; the road opens out as it reaches the sand: three columns out in the field, wider at it
(: g (slop-new 23 80 (wheel 11))
   rx (slop-road g 20)
   near ((slop-shore g rx) + slop-sand g rx)     ; the beach's last row at the road
 (test
  (3 = road-width g 20)                          ; out in the field it is a track
  (road-width g 20 < road-width g (near + 2))    ; nearer the sand it fans
  (road-width g (near + 2) < road-width g (near + 1))
  (46 = <(slop-turf g 20 rx))                    ; and you are always on bare dirt
  (all (w \ (brown? (slop-turf g w (slop-road g w)))) (map (i \ (i + 2)) ^30))))

; --- the ladder: one press a square until the shore is about a screen out ---
; the gap is read off the shore at the road's own column, so setting it means finding
; the world row that has it -- the road crosses a wavy line and a gap can be skipped
(: g (slop-new 23 80 (wheel 11))
   (row-at gp) (: (go w) (? (w < -30) ()
                            (: q (w - slop-shore g (slop-road g w))
                             (? (q = gp) w (go (w - 1)))))
                  (go 22))
   ; a world row is a charm that goes negative, so a miss is asked with charm?, never
   ; with ? -- truth here is the sign, and every row past the start would read as a miss
   (at gp) (: w (row-at gp) (? (charm? w) (: _ (pin g 'w w) (slop-cost g)) 'none))
   (rate-at gp) (: w (row-at gp) (? (charm? w) (: _ (pin g 'w w) (slop-rate g)) 'none))
   ladder (: (go w acc) (? (w < -13) (rev acc)
                           (: _ (pin g 'w w) (go (w - 1) (slop-cost g . acc))))
             (go 22 ()))
   (rising? l) (l @- 1 (a . b . r) (? (b < a) 0 (rising? (b . r))))
 (test
  (20 = g 'drag)                                 ; the ladder's reach, about a screen
  (1 = at 30) (1 = at 20)                        ; beyond it, a square is a square
  (2 = at 10) (10 = at 2)
  (20 = at 1)                                    ; at the shore, a screen's worth of presses
  (rising? ladder)                               ; and it never falls as you close
  (1.0 = rate-at 20)
  (rate-at 1 < rate-at 20)
  (0 < rate-at 1)))

; --- a press is banked, and a bankful is spent on a square ---
(: g (slop-new 23 80 (wheel 11))
   _ (slop-push g)
   y1 (slop-sy g)
   _ (slop-push g)
   y2 (slop-sy g)
 (test
  (35 = g 'span)                                 ; the walk you are given
  (21 = y1) (20 = y2)                            ; far out, a press is a square
  (2 = g 'spent)))

; --- the helm: only forward moves you, and q or esc steps off the map ---
(: g (slop-new 23 80 (wheel 11))
   _ (slop-key g 106)
   back (slop-sy g)
   _ (slop-key g 108)
   side (slop-sy g)
   _ (slop-key g 122)
   none (slop-sy g)
   _ (slop-key g -8)
   fwd (slop-sy g)
   _ (slop-key g 113)
 (test
  (22 = back) (22 = side) (22 = none)            ; nothing but forward carries you
  (21 = fwd)
  (1 = g 'spent)
  ('fled = g 'over)
  (has? (slop-bar g) "turn back")))

; --- an ended game is closed: further keys neither move you nor spend ---
(: g (slop-new 23 80 (wheel 11))
   _ (slop-key g 27)
   _ (slop-key g 107)
 (test ('fled = g 'over) (22 = slop-sy g) (0 = g 'spent)))

; --- below the climb line every square is yours: you rise, nothing scrolls ---
(: g (slop-new 23 80 (wheel 11))
   n (drive g at-line)
 (test
  (15 = slop-sy g)                               ; you walked up to the line
  (7 = n)                                        ; seven squares at a press each
  (0 = g 'wtop)                                  ; and nothing has scrolled
  (27 = slop-gap g)))                            ; seven rows closer, and a bay's worth more

; --- at the line a square is one of two things, and the gap closes either way ---
; yours: you rise a row and the world holds still. not yours: the ground scrolls under
; you -- wtop down one, you where you were -- which is what walks the shore into view
; and then down the screen. either way you cross one world row, and the gap closes by
; one or two, never none for long and never back: the road meets a wavy line at an
; angle, so a square can gain a row on a headland and none across a bay's mouth.
(: g (slop-new 23 80 (wheel 11))
   _ (drive g at-line)
   (lawful? h) (: y0 (slop-sy h) t0 (h 'wtop) w0 (h 'w) gap0 (slop-gap h)
                  _ (slop-step h)
                  mine (((slop-sy h) = (y0 - 1)) && ((h 'wtop) = t0))
                  slop (((slop-sy h) = y0) && ((h 'wtop) = (t0 - 1)))
                (? ((h 'w) = (w0 - 1))
                   (? (mine || slop) ((gap0 - 2) <= (slop-gap h) <= gap0) 0)
                   0))
   (steps n ok) (? (g 'over) [n ok] (: k (lawful? g) (steps (n + 1) (ok && k))))
   r (steps 0 1)
 (test
  (29 = r 0)                                     ; twenty-nine squares from the line
  (r 1)                                          ; every one of them lawful
  ('taken = g 'over)
  (g 'wtop < -20)                                ; the ground scrolled most of the way
  (slop-wet? g (g 'w) (slop-road g (g 'w)))))    ; and the shore closed over you

; --- the whole walk: the press count is the ladder's sum, and it does not vary ---
(: (run st) (: g (slop-new 23 80 st)
               sand {-1} shore {-1}
               (seen? h b p) (? (0 <= peep b () -1) ()
                                (p h) (pin b () (h 'spent)) ())
               (sandy-top? h) (: w (h 'wtop)
                                 (any (x \ (w <= ((slop-shore h x) + slop-sand h x))) ^80))
               (wet-top? h) (: w (h 'wtop) (any (x \ slop-wet? h w x) ^80))
               (go n) (? (g 'over) [n (slop-sy g) (peep sand () -1) (peep shore () -1)]
                         (: _ (seen? g sand sandy-top?)
                            _ (seen? g shore wet-top?)
                          (slop-key g 107, go (n + 1))))
               (go 0))
   runs (map (i \ run (wheel (300 + i))) ^12)
   (col j) (map (r \ r j) runs)
   mid (23 // 2)                                 ; 11: the middle row of the screen
 (test
  (all (p \ (p = 98)) (col 0))                   ; 98 presses for 35 squares, every seed
  (all (b \ (2 < b < 22)) (col 1))               ; the shore never reaches the foot
  (mid < ((net (col 1)) / 12.0))                 ; ..and on the whole lands past the middle
  (all (s \ (10 < s)) (col 2))                   ; the sand is a good walk away
  (all (r \ ((r 2) < (r 3))) runs)))             ; and the shore behind it, always after

; --- the ground is a function of where it is, so a scroll costs nothing ---
(: g (slop-new 23 80 (wheel 11))
   r0 (slop-road g -7)
   t0 (slop-turf g -7 3)
   e0 (slop-shore g 3)
   _ (drive g (h \ ((h 'wtop) < -8)))
   ws (map (i \ (i - 40)) ^120)
 (test
  ((g 'wtop) < -8)                               ; the ground did scroll
  (r0 = slop-road g -7)                          ; the road at a world row is that row's
  (t0 = slop-turf g -7 3)                        ; the ground beside it likewise
  (e0 = slop-shore g 3)                          ; and the shore does not move at all
  !((slop-road g 0) = (slop-road g 8))           ; ..though the road does wander
  (all (w \ (1 < (slop-road g w) < 78)) ws)      ; never off the width
  (: n (slop-new 23 20 (wheel 11))               ; nor on the narrowest screen the runner hands over
   (all (w \ (0 < (slop-road n w) < 19)) ws))))

; a turf cell is a glyph and a pen: grass, a shrub, sand, or the road's bare dirt
(: g (slop-new 23 80 (wheel 11))
   cells (map (x \ slop-turf g 4 x) ^80)
 (test
  (all (c \ ((<c = 46) || (<c = 34) || (<c = 35))) cells)      ; . " or # and nothing else
  (all (c \ (21 < <>c < 224)) cells)))                         ; and a pen out of the three ramps

; --- the frame at the shore: slop, surf, sand, grass, and you on the road ---
(: g (slop-new 23 80 (wheel 11))
   _ (drive g (h \ ((h 'wtop) < -18)))
   _ (slop-tick g)
   f (slop-frame g)
 (test
  (string? f)
  (has? f "\e[H")
  (has? f "\e[48;5;220m" || has? f "\e[48;5;199m" || has? f "\e[48;5;217m")  ; the slop's pens
  (has? f "~")                                   ; surf along its front row
  (has? f "\e[38;5;180m" || has? f "\e[38;5;186m" || has? f "\e[38;5;223m")  ; the beach
  (has? f "\e[38;5;94m" || has? f "\e[38;5;130m" || has? f "\e[38;5;137m")   ; the road
  (has? f "\e[38;5;34m" || has? f "\e[38;5;71m")                            ; the grass
  (has? f "\e[38;5;231m") (has? f "@")           ; you, white, on it
  (has? f "\e[K") (has? f "\r\n")
  (has? f "to go")))

; a row with no slop in it is the same string every time, so it is painted once and
; kept; a row the shore cuts is laid fresh every frame, because the shimmer moves
(: g (slop-new 23 80 (wheel 11))
   f1 (slop-frame g)
   f2 (slop-frame g)
   kept (tally (keys (g 'rows)))
   _ (drive g (h \ ((h 'wtop) < -18)))
   _ (slop-frame g)
   cut (tally (filter (w \ (w <= (g 'wetto))) (keys (g 'rows))))
 (test (f1 = f2) (0 < kept) (0 = cut)))

; --- the clock slows with the walk: the same beat buys less phase further in ---
(: g (slop-new 23 80 (wheel 11))
   c0 (slop-cost g)
   t0 (g 't)
   _ (slop-tick g)
   far ((g 't) - t0)
   _ (drive g (h \ (19 < slop-cost h)))          ; walk up to the last square of all
   c1 (slop-cost g)
   t1 (g 't)
   _ (slop-tick g)
   near ((g 't) - t1)
 (test
  (1 = c0) (20 = c1)
  (0.0 < near) (near < far)
  (|((far * c0) - (near * c1)) < 0.000001)))     ; the beat divided by the cost, exactly

(test_fin ())
(puts "slop: ok")
