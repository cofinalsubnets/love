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
  (all (x \ (3 <= (slop-sand g x) <= 9)) ^80)))  ; and a beach of three to nine rows behind it

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
  (5 = road-width g 20)                          ; out in the field it is a track
  (road-width g 20 < road-width g (near + 3))    ; nearer the sand it fans
  (road-width g (near + 3) < road-width g (near + 2))
  (46 = <(slop-turf g 20 rx))                    ; and you are always on bare dirt
  (all (w \ (brown? (slop-turf g w (slop-road g w)))) (map (i \ (i + 2)) ^30))))

; --- the ladder: one press a square until the shore is about a screen out ---
; the gap is read off the shore at the road's own column, so setting it means finding
; the world row that has it -- the road crosses a wavy line and a gap can be skipped
(: g (slop-new 23 80 (wheel 11))
   (row-at gp) (: (go w) (? (w < -70) ()
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
  (1 = at 66) (1 = at 20)                        ; beyond it, a square is a square
  (2 = at 10)
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
  (89 = g 'span)                                 ; the walk you are given
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
  (81 = slop-gap g)))                            ; seven rows closer, and a bay's worth more

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
  (82 = r 0)                                     ; eighty-two squares from the line
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
  (all (p \ (p = 151)) (col 0))                  ; 151 presses for 89 squares, every seed
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
   _ (drive g (h \ ((h 'wtop) < -67)))
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

; --- the skin drifts with the ground: the same phase over a scrolled world is a
; different picture, and it is the picture the unscrolled world had one row up ---
(: g (slop-new 23 80 (wheel 11))
   _ (drive g (h \ ((h 'wtop) < -67)))
   t0 (g 't)
   k0 (peep ((g 'field) t0 (g 'wtop)) [0 0] 0)         ; the skin's top-left cell, where we are
   k1 (peep ((g 'field) t0 ((g 'wtop) + 1)) [0 0] 0)   ; ..and one row of drift along
   k2 (peep ((g 'field) t0 (g 'wtop)) [1 0] 0)         ; the cell below it, undrifted
 (test
  !(k0 = k1)                                     ; a scroll moves the skin
  (|(k1 - k2) < 0.000001)))                      ; by exactly one row of it

; --- the flood: the end is slop over the whole screen and nothing else ---
(: g (slop-new 23 80 (wheel 11))
   f (slop-flood g 1.0)
 (test
  (string? f)
  (has? f "\e[H")
  (has? f "\e[48;5;")                            ; slop
  !(has? f "\e[38;5;34m") !(has? f "\e[38;5;94m")    ; no grass, no road
  !(has? f "\e[38;5;180m") !(has? f "@") !(has? f "~")  ; no sand, no you, no surf
  (has? f "to go")                               ; the bar is the one thing left standing
  !((slop-flood g 1.0) = (slop-flood g 2.0))))   ; and it runs: a phase is a picture

; a row with no slop in it is the same string every time, so it is painted once and
; kept; a row the shore cuts is laid fresh every frame, because the shimmer moves
(: g (slop-new 23 80 (wheel 11))
   f1 (slop-frame g)
   f2 (slop-frame g)
   kept (tally (keys (g 'rows)))
   _ (drive g (h \ ((h 'wtop) < -67)))
   _ (slop-frame g)
   cut (tally (filter (w \ (w <= (g 'wetto))) (keys (g 'rows))))
 (test (f1 = f2) (0 < kept) (0 = cut)))

; --- the song: gwen's tidal line, note for note, and a tempo the walk drags on ---
;   chunk 4 (|- n 5) . jux rev . arp "pinkyup down"
;     $ n "e'min'7 e'maj'7 d'min'7 d'maj'7"
; tidal's '7 is the count of notes, so each triad runs out through the octaves until
; it has seven: e minor is 4 7 11 16 19 23 28. pinkyup sounds the top after each of
; the others (twelve notes), down just falls (seven), and jux rev doubles the lot.
(: tune (slop-tune ())
   ; harp by VALUE, not spliced: the gate wants prel's rev above, and a borrow
   ; would hand it the pattern one
   qi (cite 'harp 'qi)  evv (cite 'harp 'evv)  onset? (cite 'harp 'onset?)
   (notes c) (map (x \ peep (evv x) 'note 'none) (filter onset? (tune (qi c) (qi (c + 1)))))
   c0 (notes 0) c2 (notes 2)
   one (take 38 c0)                              ; one channel of it; jux rev is the other
 (test
  (76 = tally c0)                                ; 12 + 12 + 7 + 7, twice over
  (76 = tally c2)
  ; cycle 0 drops its FIRST quarter five semitones -- that is chunk 4 (|- n 5)
  ('(-1 23 2 23 6 23 11 23 14 23 18 23) = take 12 one)
  ; the second quarter is e major, pinkyup, untouched
  ('(4 28 8 28 11 28 16 28 20 28 23 28) = take 12 (drop 12 one))
  ; the third and fourth fall: d minor then d major
  ('(26 21 17 14 9 5 2) = take 7 (drop 24 one))
  ('(26 21 18 14 9 6 2) = take 7 (drop 31 one))
  ; cycle 2 leaves the first two alone and drops the THIRD
  ('(4 28 7 28 11 28 16 28 19 28 23 28) = take 12 c2)
  ('(21 16 12 9 4 0 -3) = take 7 (drop 24 c2))
  ; a sine, and a note that rings a third of a second
  ("sin" = peep (evv (cap (filter onset? (tune (qi 0) (qi 1))))) 's 'none)))

; the tempo falls with the cost, but only to a third: a twentieth of a tempo is none
(: g (slop-new 23 80 (wheel 11))
   (row-at gp) (: (go w) (? (w < -70) ()
                            (: q (w - slop-shore g (slop-road g w))
                             (? (q = gp) w (go (w - 1)))))
                  (go 22))
   (sp gp) (: w (row-at gp) (? (charm? w) (: _ (pin g 'w w) (slop-song-speed g)) 'none))
 (test
  (1.0 = sp 66) (1.0 = sp 20)                    ; out in the field it runs at tempo
  (sp 1 < sp 10) (sp 10 < sp 20)                 ; and drags all the way in
  (0.3 <= sp 1 <= 0.4)))                         ; ..to a third of it, and no further

; and the waveform thickens with it: a clean sine at the start, a square at the shore,
; and half way over at the knee. linear in the GAP either side of the knee, not in the
; cost -- the cost is a reciprocal, so a dial linear in it spends nineteen of the
; twenty-one squares reaching half way and does the rest inside the last one.
(: g (slop-new 23 80 (wheel 11))
   (row-at gp) (: (go w) (? (w < -70) ()
                            (: q (w - slop-shore g (slop-road g w))
                             (? (q = gp) w (go (w - 1)))))
                  (go 22))
   (ed gp) (: w (row-at gp) (? (charm? w) (: _ (pin g 'w w) (slop-song-edge g)) 'none))
 (test
  (0.0 = ed 66) (0.0 = ed 50)                    ; the whole first screen is a clean sine
  (0.0 = ed (g 'gmin))                           ; the ramp starts at the volume's floor
  (1.0 = ed 1)                                   ; and lands square exactly at the slop
  (ed (g 'gmin) < ed 20)                         ; hardening the whole way between
  (ed 20 < ed 10) (ed 10 < ed 5) (ed 5 < ed 1)
  (all (gp \ (0.0 <= ed gp <= 1.0)) [66 50 20 10 5 1])))

; --- the volume over the four stretches of the walk ---
; a screen of grass to fall quiet over, a stretch to stay quiet across, the half screen
; of scroll before the sand shows to come back up in, and the whole approach at full.
; the rise is keyed to the rows of scroll still owed before the beach shows, not to a
; gap, so it lands on the sand appearing exactly rather than near it.
(: g (slop-new 23 80 (wheel 11))
   (walk-to p) (: (go _) (? (g 'over) () (p g) () (slop-key g 107, go ())) (go ()))
   v0 (slop-song-vol g)                          ; the first frame
   _ (walk-to (h \ ((slop-gap h) <= (h 'gmin))))
   vmin (slop-song-vol g)                        ; the bottom of the dip
   emin (slop-song-edge g)
   _ (walk-to (h \ (((h 'wtop) - (h 'bt)) <= ((h 'r) // 2))))
   vhalf (slop-song-vol g)                       ; half a screen of scroll short of the sand
   _ (walk-to (h \ ((h 'wtop) <= (h 'bt))))
   vsand (slop-song-vol g)                       ; the sand on the screen
   esand (slop-song-edge g)
 (test
  (1.0 = v0)                                     ; full at the first frame
  (vmin <= 0.07)                                 ; almost silent a screen in
  (0.0 = emin)                                   ; ..which is where the waveform starts to turn
  (|(vhalf - vmin) < 0.0001)                     ; still there half a screen out from the sand
  (0.99 <= vsand)                                ; and back to full the moment it shows
  ; the waveform has barely started by then: the ramp is squared, so its knee sits
  ; toward the square end and the sine holds most of the way down the beach
  (0.12 <= esand <= 0.45)
  (esand < 1.0)))

; the dip falls smoothly and never goes under the floor, and every point of the walk is
; between the floor and full
(: g (slop-new 23 80 (wheel 11))
   vs (: (go acc) (? (g 'over) (rev acc)
                     (: _ (slop-key g 107) (go ((slop-song-vol g) . acc))))
         (go ()))
   (rising? l) (l @- 1 (a . b . r) (? (b < a) 0 (rising? (b . r))))
   (falling? l) (l @- 1 (a . b . r) (? (a < b) 0 (falling? (b . r))))
 (test
  (all (v \ (0.06 <= v <= 1.0)) vs)              ; nothing under the floor, nothing over full
  (0 < tally (filter (v \ (v <= 0.07)) vs))      ; there is a quiet stretch
  (0 < tally (filter (v \ (0.99 <= v)) vs))      ; and a loud one
  (falling? (take 20 vs))                        ; it only falls at the start
  (rising? (rev (take 20 (rev vs))))))         ; and only rises at the end

; the dial itself: play.l's i-sin at one end, its i-sqr at the other, and the triangle
; between them -- in three STEPS, not a slide, because a crossfade builds both of its
; shapes and a voice is paid for by the operation (a/rove/slop.l says the numbers). the
; three share a phase -- a square built on the half of the period has the sine's sign --
; so a step lands on the same side of zero as the one before it rather than against it,
; which is the law worth holding here whether they cross or jump.
(: twopi 6.283185307179586
   (w ph m) (slop-song-wave ph 1.0 m)            ; f of 1, so the phase IS the argument
   (near a b) (|(a - b) < 0.000001)
   phs [0.0 0.125 0.25 0.375 0.5 0.625 0.75 0.875]
 (test
  ; m 0 is i-sin, note for note; m 1 is i-sqr
  (all (p \ (near (w p 0.0) (sin (p * twopi)))) phs)
  (all (p \ (near (w p 1.0) (? (p < 0.5) 1.0 -1.0))) phs)
  ; they share a sign the whole way round, which is what lets the blend cross rather
  ; than cancel. to a tolerance: sin of pi is not zero, it is -1.2e-16, and the square
  ; has already flipped there
  (all (p \ (-0.000001 <= ((w p 0.0) * (w p 1.0)))) phs)
  ; half way is the triangle, in phase with both -- zero rising at the period's start,
  ; one at a quarter, minus one at three. play.l's own i-tri is a quarter period behind,
  ; and a triangle out of phase would cancel against the sine rather than cross with it.
  (near (w 0.0 0.5) 0.0) (near (w 0.25 0.5) 1.0)
  (near (w 0.5 0.5) 0.0) (near (w 0.75 0.5) -1.0)
  (near (w 0.125 0.5) 0.5)                       ; straight between the corners
  ; a step, not a slide: a quarter turn is the shape its third of the dial names, whole
  ; -- the sine below a third, the triangle to two thirds, the square above
  (all (p \ (near (w p 0.25) (w p 0.0))) phs)
  (all (p \ (near (w p 0.6) (w p 0.5))) phs)
  (all (p \ (near (w p 0.75) (w p 1.0))) phs)
  ; ..and the steps really are three different shapes, not one repeated
  !(near (w 0.125 0.0) (w 0.125 0.5)) !(near (w 0.125 0.5) (w 0.125 1.0))
  ; and nothing anywhere on the dial leaves the rails
  (all (p \ (all (m \ (-1.0001 <= (w p m) <= 1.0001)) [0.0 0.25 0.5 0.75 1.0])) phs)))

; the voices go out a port, so a jug plays the part of the card: real PCM, not silence
(: tune (slop-tune ())
   ; harp by VALUE, not spliced: the gate wants prel's rev above, and a borrow
   ; would hand it the pattern one
   qi (cite 'harp 'qi)  evv (cite 'harp 'evv)  onset? (cite 'harp 'onset?)
   j (jug 0)
   s (slop-song-new tune j)
   (feed n) (? (0 < n) (: _ (slop-song-feed s 1.0 0.0 1.0) (feed (n - 1))))
   _ (feed 10)
   pcm (slurp j)
   (samp i) (: v ((peep pcm (i * 2) 0) + ((peep pcm ((i * 2) + 1) 0) << 8))
             (? (v > 32767) (v - 65536) v))
   n (#pcm // 2)
   peak (foldl (\ a i (: v |(samp i) (a < v ? v a))) 0 ^n)
 (test
  ((40 * ((love-arch = 'wasm ? 16000 48000) // 30)) = #pcm)   ; ten chunks, a thirtieth of a second at the seat's rate
  (0 < peak)                                     ; something sounded
  (peak < 32768)                                 ; and it did not clip
  (0 < tally (s 'vs))                            ; voices are live
  (0 < s 'cyc)))                                 ; and a cycle has been scheduled

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

; a voice's kind is laid once and kept, and a chunk inside it is a cut of that: the same
; values the long way lays, and the same tray the second time it is asked for
(: f 391.99543598174927
   venv (cite 'play 'venv)
   w (song-wave-of 7 f 0.5 0.34 16000)
   w2 (song-wave-of 7 f 0.5 0.34 16000)
   pad ((#w - 5442) // 2)                          ; the silence either end
   ix ((iota 533) + 1200)
   st 1000
   c (snip w (200 + pad) (733 + pad))
   t ((ix - st) * (1.0 / 16000))
   long (slop-song-wave t f 0.5 * venv t 0.34 * (t < 0.34))
   ; ..and the chunk it starts in is a cut too, silent before the onset
   ix0 ((iota 533) + 700)
   c0 (snip w (700 - st + pad) (700 - st + pad + 533))
   t0 ((ix0 - st) * (1.0 / 16000))
   tp0 (t0 * (t0 > 0.0))
   long0 (slop-song-wave tp0 f 0.5 * venv tp0 0.34 * (t0 < 0.34))
 (test (tray? w) (5442 < #w) (= w w2) (533 = #c) (= c long) (0.0 = peep w 0 0) (= c0 long0)))

; the bar stops a column short of the screen
(: g (slop-new 10 20 (wheel 3))
   rows (split "\r\n" (slop-frame g))
 (test (19 = #(slop-bar-fit g)) ((slop-bar-fit g + "\e[K") = last rows)))

; a frame gives way to a low ring only on a seat with a yield, and never on a beat that
; took a key, nor a fourth beat running; with no yield it is always due
(test (frame-due? 0 0 0 0) !(frame-due? 4000 100 0 0) (frame-due? 4000 100 1 0)
      (frame-due? 4000 100 0 4) !(frame-due? 4000 100 0 3) (frame-due? 4000 4000 0 0))

; a wooden sign stands a cell off the road a third of a screen in, on the turf row it
; is on and on no other cell of it, and the row is laid with it
(: g (slop-new 21 40 (wheel 3))
   sg (slop-post g)
   x <sg w <>sg
   row ((split "\r\n" (slop-frame g)) w)                 ; on the screen from the start
   (has? s p) (: n #p (go i) (? (i + n > #s) 0 (snip s i (i + n) = p) 1 (go (i + 1))) (go 0))
 (test (7 = w) (2 < |(x - slop-road g w)) ('("¶" 137) = slop-turf g w x)
       !('("¶" 137) = slop-turf g w (x + 1)) !('("¶" 137) = slop-turf g (w + 1) x)
       (has? row "¶")))
