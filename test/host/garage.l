; --- test/host/garage.l: the parking garage, headless ---
; not in the test/*.l corpus (it loads a crew module). the level is pure love, so
; everything but the tty runner gates here: the lay -- concrete round, pilasters and
; columns, the bays' lines, wrecks in some bays and never on the bed, the bed in
; through the east wall and out through the west -- the rats wandering the bare floor,
; a rat bumped, the walls and the wrecks holding, the way out west and not east, and
; the song into a jug, the tune's cycles pulled as the head reaches them.
;   cat test/00-init.l test/host/garage.l | out/love

(borrow 'garage)   ; the artifact's module, warm from the tree
(borrow 'rove)     ; dat, open?

(: (count s n) (:- (go 0 0) (go i k) (i + #n <= #s ? (go (i + 1) (k + (n = snip s i (i + #n)))) k))
   (rows s) (1 + count s "\r\n")
   (range a b) (map (+ a) ^(b - a))
   ; the cells of the bed you can walk to from where you stand, eight ways at a step
   (bed-reach g) (: d (g 'd) w (d 'w) h (d 'h) seen {}
                    (nbs i) (: x (i % w) y (i // w)
                               (filter (j \ 0 <= j)
                                       (map ([dx dy] \ (: nx (x + dx) ny (y + dy)
                                                         (0 <= nx < w && 0 <= ny < h && 5 = dat d nx ny ? (nx + w * ny) -1)))
                                            '((1 0) (-1 0) (0 1) (0 -1) (1 1) (-1 -1) (1 -1) (-1 1)))))
                    (go l) (l @- seen (i . u) (seen i ? (go u) (pin seen i 1, go (u + nbs i))))
                    (go [(g 'p 'x + w * g 'p 'y)])))

; --- the lay ---
(: g (garage-new 80 22 (wheel 5)) d (g 'd) w 80 h 22 p (g 'p)
   (t x y) (dat d x y)
   (has-tile? k) (any (i \ k = peep (d 't) i 0) ^(w * h))
   cars (d 'cars)
   f (garage-frame g) f2 (garage-frame g)
   reach (bed-reach g)
 (test (rows f = h + 2) (f = f2)
       (all (x \ 0 = t x 0 && 0 = t x (h - 1)) ^w)                    ; concrete along the top and the bottom
       (all (y \ elem (t 0 y) '(0 5) && elem (t (w - 1) y) '(0 5)) ^h)   ; ..and down the sides, but for the bed
       (any (y \ 5 = t 0 y) ^h) (any (y \ 5 = t (w - 1) y) ^h)         ; which breaks through both
       (has-tile? 2) (has-tile? 3) (has-tile? 4)                        ; columns, pilasters, lines
       ; ..and none of them, nor a wreck, in the zone the bed runs through
       (: z (d 'zone) (all (i \ !(elem (peep (d 't) i 0) '(2 4 6))) (range (w * <z) (w * <>z))))
       (all (i \ !(elem (peep (d 't) i 0) '(2 4 6))) (filter (i \ 5 = peep (d 't) i 0) ^(w * h)))
       (0 < #cars) (all (c \ all (cl \ 6 = peep (d 't) <cl 0) (car-cells c w)) cars)   ; wrecks whole, and not on the bed
       (all (c \ (bay-d * (bay-w - 1)) = #(car-cells c w)) cars)
       (p 'x = w - 1) (5 = t (p 'x) (p 'y))                            ; you start on the bed at the east wall
       (any (i \ 0 = i % w) (keys reach))                                ; ..and the bed runs through to the west wall
       (0 < #(g 'ms)) (all (m \ open? d (m 'x) (m 'y)) (g 'ms))         ; the rats, on bare cells
       (two? (g 'sign)) (garage-turn g 32, !(g 'sign))))

; --- the rats wander and stay on bare cells; one bumped has its say and nobody moves for it ---
(: g (garage-new 80 22 (wheel 5)) d (g 'd) w 80 p (g 'p)
   _ (garage-turn g 32)
   was (map (m \ [(m 'x) (m 'y)]) (g 'ms))
   _ (each ^30 (i \ garage-turn g '(1 0)))                              ; thirty turns at the east wall
   now (map (m \ [(m 'x) (m 'y)]) (g 'ms))
   r <(g 'ms) rx (r 'x) ry (r 'y)
   _ (pins p 'x (rx + 1) 'y ry)
   _ (garage-turn g '(-1 0))
 (test (was != now) (all (m \ open? d (m 'x) (m 'y)) (g 'ms))
       (0 < #(g 'msg)) (p 'x = rx + 1) (p 'y = ry) (!(g 'over))
       (string? (rat-interaction (g 'sb) r))))

; --- concrete holds and so does a wreck; west along the bed is the way out, east is not ---
(: g (garage-new 80 22 (wheel 5)) d (g 'd) w 80 h 22 p (g 'p)
   (t x y) (dat d x y)
   _ (garage-turn g 32)
   x0 (p 'x) y0 (p 'y)
   _ (garage-turn g '(1 0)) m1 (g 'msg) o1 (g 'over)                  ; east, off the map: no
   _ (pins p 'x 1 'y 0) _ (garage-turn g '(0 -1)) m2 (g 'msg)          ; into the top wall
   c <(d 'cars)
   _ (pins p 'x (c 'x - 1) 'y (c 'y)) _ (garage-turn g '(1 0)) m3 (g 'msg) x3 (p 'x)   ; into a wreck
   wy (<(filter (y \ 5 = t 0 y) ^h))
   _ (pins p 'x 0 'y wy) _ (garage-turn g '(-1 0))                      ; west, off the map along the bed
 (test (0 < #m1) (nil? o1) (0 < #m2) (0 < #m3) (x3 = c 'x - 1)
       ('west = g 'over)))

; --- a garage too small for a bay is laid without one, and without a car, and stands ---
(: g (garage-new 24 10 (wheel 5)) d (g 'd) w 24 h 10
   (t x y) (dat d x y)
 (test (rows (garage-frame g) = h + 2) (!(d 'cars))
       (all (i \ !(elem (peep (d 't) i 0) '(2 4 6))) ^(w * h))
       (any (y \ 5 = t 0 y) ^h) (any (y \ 5 = t (w - 1) y) ^h)
       (5 = t (g 'p 'x) (g 'p 'y))))

; --- the song: a chunk a feed, the tune's cycles pulled as the head reaches them and its
; voices sounding; no tune, and the same chunks are silence ---
(: j (jug 0) s (garage-song-new (garage-tune ()) j (wheel 7))
   spc (int (song-rate / song-cps))
   n (1 + spc // song-chunk)                              ; feeds enough to reach the second cycle
   _ (each ^n (i \ garage-song-feed s))
   out (slurp j)
   j2 (jug 0) s2 (garage-song-new () j2 (wheel 7))
   _ (each ^5 (i \ garage-song-feed s2))
   out2 (slurp j2)
 (test (#out = n * 4 * song-chunk) (any (i \ 0 != out i) ^#out)
       (2 = s 'cyc) (2 * spc = s 'next) (n * song-chunk = s 'fpos)
       (#out2 = 5 * 4 * song-chunk) (all (i \ 0 = out2 i) ^#out2) (0 = s2 'cyc)))

(test_fin (),
 puts "garage: ok -- the bed runs through, the rats wander, the wrecks and the walls hold, and west is the way\n")
