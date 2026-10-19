; test/host/slop.l -- the slop, headless; test/host/tty.l plays the runner.
; not in the corpus: it loads a crew module. run: cat test/00-init.l test/host/slop.l | out/love

(borrow 'slop)

; press k until the game says otherwise; answers the presses spent
(: (drive g p) (: (go n) (? (g 'over) n (p g) n (slop-key g 107, go (n + 1))) (go 0))
   at-line (h \ (slop-sy h) <= (h 'climb))
   ; the pens tell the three grounds apart: grass below 94, road within, sand above
   (brown? c) (93 < <>c < 138)
   (sandy? c) (138 < <>c)
   (road-width g w) #(filter brown? (map (x \ slop-turf g w x) ^(g 'c))))

; the first frame: a field, and nothing else on it
(: g (slop-new 23 80 (wheel 11))
   rows (map (i \ (g 'wtop) + i) ^23)
   xs ^80
   (dry? w) (all (x \ !(slop-wet? g w x)) xs)
   (green? w) (all (x \ (w > slop-shore g x + slop-sand g x)) xs)
   f (slop-frame g)
 (test
  (all dry? rows)
  (all green? rows)
  !(has? f "\e[48;5;")))

; the same on a short terminal, where the offset falls back on the beach actually laid
(: g (slop-new 11 40 (wheel 11))
   rows (map (i \ (g 'wtop) + i) ^11)
   top (foldl (a \ x \ (slop-shore g x + slop-sand g x @ v (a < v ? v a))) -99 ^40)
 (test
  (top < 0)
  (all (w \ (all (x \ !(slop-wet? g w x)) ^40)) rows)
  (all (w \ (all (x \ (w > slop-shore g x + slop-sand g x)) ^40)) rows)))

; the shoreline: wavy, one row a step; amplitude times frequency under a row a column keeps it so
(: g (slop-new 23 80 (wheel 11))
   xs ^79
   steps (map (x \ |(slop-shore g (x + 1) - slop-shore g x)) xs)
   shores (map (x \ slop-shore g x) ^80)
   srt (sort shores)
   (last l) <(rev l)
 (test
  (all (s \ (s <= 1)) steps)
  (0 < #(filter (s \ (s = 1)) steps))
  (2 < last srt - <srt)                      ; bays and headlands, not a straight line
  (all (x \ (0 < slop-sand g x)) ^80)))

; the ground: sand behind the line, grass in front, road through
(: g (slop-new 23 80 (wheel 11))
   x 30
   e (slop-shore g x)
   s (e + slop-sand g x)
 (test
  (slop-wet? g e x) !(slop-wet? g (e + 1) x)     ; the line is the slop's last row
  (sandy? (slop-turf g (e + 1) x))
  (sandy? (slop-turf g s x))                     ; and the beach's own last row
  !(sandy? (slop-turf g (s + 1) x))
  (charm? <(slop-turf g s x))))

; the road fans out as it reaches the sand
(: g (slop-new 23 80 (wheel 11))
   rx (slop-road g 20)
   near (slop-shore g rx + slop-sand g rx)
 (test
  (0 < road-width g 20)
  (road-width g 20 < road-width g (near + 3))
  (road-width g (near + 3) < road-width g (near + 2))
  (charm? <(slop-turf g 20 rx))
  (all (w \ (brown? (slop-turf g w (slop-road g w)))) (map (i \ (i + 2)) ^30))))

; the ladder: one press a square until the shore is about a screen out
; the gap is read at the road's column, so a gap can be skipped: find the row that has it
(: g (slop-new 23 80 (wheel 11))
   (row-at gp) (: (go w) (w < -70 ? () (w - slop-shore g (slop-road g w) @ q
                             (q = gp ? w (go (w - 1)))))
                  (go 22))
   ; a world row goes negative, so a miss is asked with charm?, never with ?
   (at gp) (row-at gp @ w (charm? w ? (pin g 'w w, slop-cost g) 'none))
   (rate-at gp) (row-at gp @ w (charm? w ? (pin g 'w w, slop-rate g) 'none))
   ladder (: (go w acc) (w < -13 ? (rev acc) (pin g 'w w, go (w - 1) (slop-cost g . acc)))
             (go 22 ()))
   (rising? l) (l @- 1 (a . b . r) (b < a ? 0 (rising? (b . r))))
 (test
  (0 < g 'drag)
  (1 = at 66) (1 = at 20)                        ; beyond it, a square is a square
  (1 < at 10 < at 1)
  (g 'drag = at 1)                               ; at the shore, the reach's worth of presses
  (rising? ladder)
  (1.0 = rate-at 20)
  (rate-at 1 < rate-at 20)
  (0 < rate-at 1)))

; a press is banked, and a bankful is spent on a square
(: g (slop-new 23 80 (wheel 11))
   y0 (slop-sy g)
   _ (slop-push g)
   y1 (slop-sy g)
   _ (slop-push g)
   y2 (slop-sy g)
 (test
  (0 < g 'span)
  (y1 = y0 - 1) (y2 = y1 - 1)                    ; far out, a press is a square
  (2 = g 'spent)))

; the helm: only forward moves you, and q or esc steps off the map
(: g (slop-new 23 80 (wheel 11))
   _ (slop-key g 106)
   back (slop-sy g)
   _ (slop-key g 108)
   side (slop-sy g)
   _ (slop-key g 122)
   none (slop-sy g)
   _ (slop-key g -8)
   fwd (slop-sy g)
   (slop-key g 113,
    test (22 = back) (22 = side) (22 = none)            ; nothing but forward carries you
         (21 = fwd)
         (1 = g 'spent)
         ('fled = g 'over)
         (has? (slop-bar g) "turn back")))

; an ended game is closed: further keys neither move you nor spend
(: g (slop-new 23 80 (wheel 11)) y0 (slop-sy g)
   (slop-key g 27,
    slop-key g 107,
    test ('fled = g 'over) (y0 = slop-sy g) (0 = g 'spent)))

; below the climb line every square is yours: you rise, nothing scrolls
(: g (slop-new 23 80 (wheel 11)) y0 (slop-sy g) gap0 (slop-gap g)
   n (drive g at-line)
 (test
  (slop-sy g < y0)
  (n = y0 - slop-sy g)
  (0 = g 'wtop)
  (slop-gap g < gap0)))

; at the line a square is yours (you rise) or the ground's (wtop scrolls down one); either way
; one world row, the gap closing by up to two and never back, a bay's mouth gaining none
(: g (slop-new 23 80 (wheel 11))
   _ (drive g at-line)
   (lawful? h) (: y0 (slop-sy h) t0 (h 'wtop) w0 (h 'w) gap0 (slop-gap h)
                  _ (slop-step h)
                  mine (slop-sy h = y0 - 1 && h 'wtop = t0)
                  slop (slop-sy h = y0 && h 'wtop = t0 - 1)
                (h 'w = w0 - 1 ? (mine || slop ? (gap0 - 2 <= slop-gap h <= gap0) 0) 0))
   (steps n ok) (g 'over ? [n ok] (lawful? g @ k (steps (n + 1) (ok && k))))
   r (steps 0 1)
 (test
  (0 < r 0)
  (r 1)
  ('taken = g 'over)
  (g 'wtop < -20)                                ; the ground scrolled most of the way
  (slop-wet? g (g 'w) (slop-road g (g 'w)))))

; the whole walk: the press count is the ladder's sum, and it does not vary
(: (run st) (: g (slop-new 23 80 st)
               sand {-1} shore {-1}
               (seen? h b p) (? (0 <= peep b () -1) ()
                                (p h) (pin b () (h 'spent)) ())
               (sandy-top? h) (h 'wtop @ w
                                 (any (x \ (w <= slop-shore h x + slop-sand h x)) ^80))
               (wet-top? h) (h 'wtop @ w (any (x \ slop-wet? h w x) ^80))
               (go n) (g 'over ? [n (slop-sy g) (peep sand () -1) (peep shore () -1)]
                       (seen? g sand sandy-top?,
                        seen? g shore wet-top?,
                        slop-key g 107, go (n + 1)))
               (go 0))
   runs (map (i \ run (wheel (300 + i))) ^12)
   (col j) (map (r \ r j) runs)
   mid (23 // 2)
 (test
  (all (= <(col 0)) (col 0))                     ; the same presses for the walk, every seed
  (all (b \ (2 < b < 22)) (col 1))               ; the shore never reaches the foot
  (mid < net (col 1) / 12.0)                 ; ..and on the whole lands past the middle
  (all (s \ (10 < s)) (col 2))                   ; the sand is a good walk away
  (all (r \ (r 2 < r 3)) runs)))             ; and the shore behind it, always after

; the ground is a function of where it is, so a scroll costs nothing
(: g (slop-new 23 80 (wheel 11))
   r0 (slop-road g -7)
   t0 (slop-turf g -7 3)
   e0 (slop-shore g 3)
   _ (drive g (h \ (h 'wtop < -8)))
   ws (map (i \ (i - 40)) ^120)
 (test
  (g 'wtop < -8)
  (r0 = slop-road g -7)
  (t0 = slop-turf g -7 3)
  (e0 = slop-shore g 3)
  !(slop-road g 0 = slop-road g 8)           ; ..though the road does wander
  (all (w \ (1 < slop-road g w < 78)) ws)      ; never off the width
  (slop-new 23 20 (wheel 11) @ n
   (all (w \ (0 < slop-road n w < 19)) ws))))

; a turf cell is a glyph and a pen: grass, a shrub, sand, or the road's bare dirt
(: g (slop-new 23 80 (wheel 11))
   cells (map (x \ slop-turf g 4 x) ^80)
 (test
  (all (c \ charm? <c) cells)
  (all (c \ (0 <= <>c < 256)) cells)))

; the frame at the shore
(: g (slop-new 23 80 (wheel 11))
   _ (drive g (h \ (h 'wtop < -67)))
   _ (slop-tick g)
   f (slop-frame g)
 (test
  (string? f)
  (has? f "\e[H")
  (has? f "\e[48;5;")
  (has? f "\e[38;5;231m") (has? f "@")
  (has? f "\e[K") (has? f "\r\n")
  (has? f "to go")))

; the skin drifts with the ground: a scroll shows what the unscrolled world had one row up
(: g (slop-new 23 80 (wheel 11))
   _ (drive g (h \ (h 'wtop < -67)))
   t0 (g 't)
   k0 (peep (g 'field t0 (g 'wtop)) [0 0] 0)           ; the skin's top-left half-cell
   k1 (peep (g 'field t0 (g 'wtop + 1)) [0 0] 0)     ; ..and one row of drift along
   k2 (peep (g 'field t0 (g 'wtop)) [2 0] 0)           ; a cell below it, undrifted
 (test
  !(k0 = k1)
  (|(k1 - k2) < 0.000001)))                      ; by exactly one row of it

; the flood: slop over the whole screen and nothing else
(: g (slop-new 23 80 (wheel 11))
   f (slop-flood g 1.0)
 (test
  (string? f)
  (has? f "\e[H")
  (has? f "\e[48;5;")
  !(has? f "@")
  !(slop-flood g 1.0 = slop-flood g 2.0)))   ; and it runs: a phase is a picture

; a dry row is painted once and kept; a row the shore cuts is laid fresh, the shimmer moves
(: g (slop-new 23 80 (wheel 11))
   f1 (slop-frame g)
   f2 (slop-frame g)
   kept #(keys (g 'rows))
   _ (drive g (h \ (h 'wtop < -67)))
   _ (slop-frame g)
   cut #(filter (w \ (w <= g 'wetto)) (keys (g 'rows)))
 (test (f1 = f2) (0 < kept) (0 = cut)))

; the song, this tidal line note for note:
;   chunk 4 (|- n 5) . jux rev . arp "pinkyup down"
;     $ n "e'min'7 e'maj'7 d'min'7 d'maj'7"
; '7 is the note count (e minor 4 7 11 16 19 23 28); pinkyup gives twelve, down seven
(: tune (slop-tune ())
   ; harp by value: a borrow would shadow prel's rev with the pattern one
   qi (cite 'harp 'qi)  evv (cite 'harp 'evv)  onset? (cite 'harp 'onset?)
   (notes c) (map (x \ peep (evv x) 'note 'none) (filter onset? (tune (qi c) (qi (c + 1)))))
   c0 (notes 0) c2 (notes 2)
   one (take 38 c0)                              ; one channel of it; jux rev is the other
 (test
  (76 = #c0)                                     ; 12 + 12 + 7 + 7, twice over
  (76 = #c2)
  ; cycle 0 drops its first quarter five semitones: chunk 4 (|- n 5)
  ('(-1 23 2 23 6 23 11 23 14 23 18 23) = take 12 one)
  ('(4 28 8 28 11 28 16 28 20 28 23 28) = take 12 (drop 12 one))
  ('(26 21 17 14 9 5 2) = take 7 (drop 24 one))
  ('(26 21 18 14 9 6 2) = take 7 (drop 31 one))
  ; cycle 2 leaves the first two alone and drops the third
  ('(4 28 7 28 11 28 16 28 19 28 23 28) = take 12 c2)
  ('(21 16 12 9 4 0 -3) = take 7 (drop 24 c2))
  ("sin" = peep (evv <(filter onset? (tune (qi 0) (qi 1)))) 's 'none)))

; the tempo falls with the cost, but only to a third
(: g (slop-new 23 80 (wheel 11))
   (row-at gp) (: (go w) (w < -70 ? () (w - slop-shore g (slop-road g w) @ q
                             (q = gp ? w (go (w - 1)))))
                  (go 22))
   (sp gp) (row-at gp @ w (charm? w ? (pin g 'w w, slop-song-speed g) 'none))
 (test
  (1.0 = sp 66) (1.0 = sp 20)
  (sp 1 < sp 10) (sp 10 < sp 20)
  (0.0 < sp 1)))

; the waveform: sine at the start, square at the shore; linear in the gap, not the cost,
; which is a reciprocal and would do it all inside the last square
(: g (slop-new 23 80 (wheel 11))
   (row-at gp) (: (go w) (w < -70 ? () (w - slop-shore g (slop-road g w) @ q
                             (q = gp ? w (go (w - 1)))))
                  (go 22))
   (ed gp) (row-at gp @ w (charm? w ? (pin g 'w w, slop-song-edge g) 'none))
 (test
  (0.0 = ed 66) (0.0 = ed 50)
  (0.0 = ed (g 'gmin))                           ; the ramp starts at the volume's floor
  (1.0 = ed 1)
  (ed (g 'gmin) < ed 20)
  (ed 20 < ed 10) (ed 10 < ed 5) (ed 5 < ed 1)
  (all (gp \ (0.0 <= ed gp <= 1.0)) [66 50 20 10 5 1])))

; the volume: falls over a screen, stays quiet, rises over the half screen before the sand;
; the rise is keyed to scroll owed, not a gap, so it lands exactly on the sand appearing
(: g (slop-new 23 80 (wheel 11))
   (walk-to p) (: (go _) (? (g 'over) () (p g) () (slop-key g 107, go ())) (go ()))
   v0 (slop-song-vol g)
   _ (walk-to (h \ (slop-gap h <= h 'gmin)))
   vmin (slop-song-vol g)
   emin (slop-song-edge g)
   _ (walk-to (h \ (h 'wtop - h 'bt <= h 'r // 2)))
   vhalf (slop-song-vol g)                       ; half a screen of scroll short of the sand
   _ (walk-to (h \ (h 'wtop <= h 'bt)))
   vsand (slop-song-vol g)
   esand (slop-song-edge g)
 (test
  (1.0 = v0)
  (vmin < 0.5)
  (0.0 = emin)                                   ; ..which is where the waveform starts to turn
  (|(vhalf - vmin) < 0.0001)                     ; still there half a screen out from the sand
  (vmin < vsand)
  ; the ramp is squared, so the sine holds most of the way down the beach
  (0.12 <= esand <= 0.45)
  (esand < 1.0)))

; the dip is smooth, every point of the walk between the floor and full
(: g (slop-new 23 80 (wheel 11))
   vs (: (go acc) (g 'over ? (rev acc) (slop-key g 107, go ((slop-song-vol g) . acc)))
         (go ()))
   (rising? l) (l @- 1 (a . b . r) (b < a ? 0 (rising? (b . r))))
   (falling? l) (l @- 1 (a . b . r) (a < b ? 0 (falling? (b . r))))
 (test
  (all (v \ (0.0 < v <= 1.0)) vs)
  (0 < #(filter (v \ (v < 0.5)) vs))
  (0 < #(filter (v \ (0.9 <= v)) vs))
  (falling? (take 20 vs))
  (rising? (rev (take 20 (rev vs))))))

; the dial: play.l's i-sin, a triangle, its i-sqr, in three steps (a crossfade costs both
; shapes); the three share a phase, so a step lands on the same side of zero
(: twopi 6.283185307179586
   (w ph m) (slop-song-wave ph 1.0 m)            ; f of 1: the phase is the argument
   (near a b) (|(a - b) < 0.000001)
   phs [0.0 0.125 0.25 0.375 0.5 0.625 0.75 0.875]
 (test
  ; m 0 is i-sin, note for note; m 1 is i-sqr
  (all (p \ (near (w p 0.0) (sin (p * twopi)))) phs)
  (all (p \ (near (w p 1.0) (p < 0.5 ? 1.0 -1.0))) phs)
  ; they share a sign, to a tolerance: sin of pi is -1.2e-16, and the square has flipped
  (all (p \ (-0.000001 <= w p 0.0 * w p 1.0)) phs)
  ; half way is the triangle in phase with both; play.l's i-tri is a quarter behind, which would cancel
  (near (w 0.0 0.5) 0.0) (near (w 0.25 0.5) 1.0)
  (near (w 0.5 0.5) 0.0) (near (w 0.75 0.5) -1.0)
  (near (w 0.125 0.5) 0.5)
  ; a step, not a slide: sine below a third, triangle to two thirds, square above
  (all (p \ (near (w p 0.25) (w p 0.0))) phs)
  (all (p \ (near (w p 0.6) (w p 0.5))) phs)
  (all (p \ (near (w p 0.75) (w p 1.0))) phs)
  !(near (w 0.125 0.0) (w 0.125 0.5)) !(near (w 0.125 0.5) (w 0.125 1.0))
  (all (p \ (all (m \ (-1.0001 <= w p m <= 1.0001)) [0.0 0.25 0.5 0.75 1.0])) phs)))

; the voices go out a port, so a jug plays the card: real pcm, not silence
(: tune (slop-tune ())
   ; harp by value, as above
   qi (cite 'harp 'qi)  evv (cite 'harp 'evv)  onset? (cite 'harp 'onset?)
   j (jug 0)
   s (slop-song-new tune j)
   (feed n) (0 < n ? (slop-song-feed s 1.0 0.0 1.0, feed (n - 1)))
   _ (feed 10)
   pcm (slurp j)
   (samp i) (peep pcm (i * 2) 0 + (peep pcm (i * 2 + 1) 0 << 8) @ v
             (v > 32767 ? (v - 65536) v))
   n (#pcm // 2)
   peak (foldl (a \ i \ (|(samp i) @ v (a < v ? v a))) 0 ^n)
 (test
  (40 * ((love-arch = 'wasm ? 16000 48000) // 30) = #pcm)   ; ten chunks of a thirtieth of a second
  (0 < peak)
  (peak < 32768)
  (0 < #(s 'vs))
  (0 < s 'cyc)))

; the clock slows with the walk: the same beat buys less phase further in
(: g (slop-new 23 80 (wheel 11))
   c0 (slop-cost g)
   t0 (g 't)
   _ (slop-tick g)
   far (g 't - t0)
   _ (drive g (h \ (19 < slop-cost h)))
   c1 (slop-cost g)
   t1 (g 't)
   _ (slop-tick g)
   near (g 't - t1)
 (test
  (1 = c0) (1 < c1)
  (0.0 < near) (near < far)
  (|(far * c0 - near * c1) < 0.000001)))     ; the beat divided by the cost, exactly

(test_fin ())
(puts "slop: ok")

; a voice's kind is laid once and kept, and a chunk is a cut of it, equal to the long way
(: f 391.99543598174927
   venv (cite 'play 'venv)
   w (song-wave-of 7 f 0.5 0.34 16000)
   w2 (song-wave-of 7 f 0.5 0.34 16000)
   pad ((#w - 5442) // 2)
   ix (iota 533 + 1200)
   st 1000
   c (snip w (200 + pad) (733 + pad))
   t ((ix - st) * (1.0 / 16000))
   long (slop-song-wave t f 0.5 * venv t 0.34 * (t < 0.34))
   ; ..and the chunk it starts in, silent before the onset
   ix0 (iota 533 + 700)
   c0 (snip w (700 - st + pad) (700 - st + pad + 533))
   t0 ((ix0 - st) * (1.0 / 16000))
   tp0 (t0 * (t0 > 0.0))
   long0 (slop-song-wave tp0 f 0.5 * venv tp0 0.34 * (t0 < 0.34))
 (test (tray? w) (5442 < #w) (aall (w = w2)) (533 = #c) (c = long) (0.0 = peep w 0 0) (c0 = long0)))

; the bar stops a column short of the screen
(: g (slop-new 10 20 (wheel 3))
   rows (split "\r\n" (slop-frame g))
 (test (19 = #(slop-bar-fit g)) (slop-bar-fit g + "\e[K" = last rows)))

; a frame yields to a low ring only with a yield, never on a beat that took a key nor a
; fourth running; with no yield it is always due
(test (frame-due? 0 0 0 0) !(frame-due? 4000 100 0 0) (frame-due? 4000 100 1 0)
      (frame-due? 4000 100 0 4) !(frame-due? 4000 100 0 3) (frame-due? 4000 4000 0 0))

; a wooden sign a cell off the road a third of a screen in, on its one cell and drawn
(: g (slop-new 21 40 (wheel 3))
   sg (slop-post g)
   x <sg w <>sg
   row (split "\r\n" (slop-frame g) w)
 (test (7 = w) (2 < |(x - slop-road g w)) ('("¶" 137) = slop-turf g w x)
       !('("¶" 137) = slop-turf g w (x + 1)) !('("¶" 137) = slop-turf g (w + 1) x)
       (has? row "¶")))
