; test/host/wade.l -- the night river, headless
; not in the corpus: a crew module. run: cat test/00-init.l test/host/00-host.l test/host/wade.l | out/love

(borrow 'wade)
(borrow 'view)
(borrow 'walk)
(: wade-kb (view-bind view-binds walk-binds))

(: (pen? s n) (has? s ("38;5;" + show n + ";") || has? s (";48;5;" + show n + "m"))
   (moon th hz) (moon-at (pins (wade-new 80 48) 'th th 'hz hz)))

; the frame
(: st (wade-new 80 48) f (wade-frame st)
   wide (wade-new 120 60) g (wade-frame wide)   ; a 120 by 30 terminal
 (test
  (h-rows f = 24) (h-count f "▀" <= 1920)             ; a cell a pixel pair, less any words over them
  (h-rows g = 30) (h-count g "▀" <= 3600) (pen? g 230) (pen? g 179) (pen? g 16)
  (wide 'hz = 30) (wide 'foc = 60.0) (wide 'cx = 60.0)
  (pen? f 230) (pen? f 179)                     ; the moon, and the moon in the water
  (pen? f 16) (pen? f 233) (pen? f 232)         ; a near tree, the water's grey, the bank
  (f = wade-frame st)
  (st 'px = 0.0) (st 'pz = 0.0) (st 'th = 0.0) (st 'hz = 24) (st 'rings = ())))

; the moon turns with the player
(: a (moon 0.0 24) b (moon 0.64 24) c (moon 3.0 24) d (moon 6.5 24)
   big (moon-at (pins (wade-new 160 48) 'th 0.0 'hz 24))
 (test
  (40.0 < a 0) (b 0 < a 0)                      ; ahead and to the right; a right turn brings it left
  (0.0 < a 2) (c 0 < -900.0)                    ; a radius; behind, far off the screen
  (abs (d 0 - (moon (6.5 - 6.283185307179793) 24) 0) < 0.001)
  (abs (big 0 - 2 * a 0) < 0.001) (abs (big 2 - 2 * a 2) < 0.001)))   ; twice the width, twice the moon

; ..and sets dead ahead into a lamp on a post in the water, nearer with every step
(: (at z) (moon-at (pins (wade-new 80 48) 'pz z))
   m0 (at 0.0) m1 (at arc-z) m2 (at (arc-z + morph-z)) m3 (at (lamp-z - 10.0))
   f1 (wade-frame (pins (wade-new 80 48) 'pz arc-z)) f3 (wade-frame (pins (wade-new 80 48) 'pz (lamp-z - 10.0)))
 (test (m1 0 = 40.0) (m1 1 = 24.0) (m1 4 = 0.0)                 ; the arc ends on the horizon, no post yet
       (m0 1 < m1 1) (m1 0 < m0 0) (m0 4 = 0.0)                  ; ..from high on the right
       (m2 2 < 1.0) (m2 2 < m1 2) (24.0 < m2 3) (0.0 < m2 4)     ; contracted into a lamp on a post into the water
       (m2 2 < m3 2) (m2 3 < m3 3) (m3 1 < m2 1)                 ; nearer: bigger, the foot deeper, the lamp higher
       (h-rows f1 = 24) (pen? f1 230) (pen? f1 179)                ; both paint, the lamp and its path
       (h-rows f3 = 24) (pen? f3 230) (pen? f3 179)))

; the banks repeat each loop, within float noise; the swell does not, so the water differs
(: st (wade-new 80 48)
   (line st) (wade-tables st @ tb (map (x \ [(peep (tb 'tops) x 0) (peep (tb 'bots) x 0)]) ^80))
   (same? a b) (80 = net (map (x \ (abs (a x 0 - b x 0) < 0.001 && abs (a x 1 - b x 1) < 0.001)) ^80))
   l0 (line st) f0 (wade-frame st)
   _ (pin st 'pz (loop * sp)) l1 (line st) f1 (wade-frame st)
   _ (pin st 'pz 7.0) l2 (line st)
   t0 (tree-of 3 1 0) t1 (tree-of (3 + loop) 1 0) t2 (tree-of 4 1 0)
 (test (same? l0 l1) !(same? l0 l2) (f0 != f1)
       (t0 'ht = t1 'ht) (t0 'wd = t1 'wd) (t1 'z - t0 'z = loop * sp)
       (t0 'ht != t2 'ht || t0 'wd != t2 'wd)
       (rw < t0 'x) (tree-of 3 -1 0 'x < 0.0 - rw)))

; a step: on down the river whichever way you face, never back; one ring at a time
(: st (wade-new 80 48)
   _ (wade-step st (wade-kb 107))                         ; k: on
   z1 (st 'pz) n1 #(st 'rings)
   _ (wade-step st (wade-kb 107))
   n2 #(st 'rings)
   _ (pin st 't 10, wade-step st (wade-kb -9), wade-step st (wade-kb 106))         ; down, j: nothing, six ticks on
   n3 #(st 'rings) z3 (st 'pz)
   _ (each '(20 30 40 50 60 70) (t \ (pin st 't t, wade-step st (wade-kb 107))))
   n4 #(st 'rings)
   (pins st 'th 1.5707963267948966 'px 0.0,
    each '(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20) (i \ wade-step st (wade-kb 107)),
    test (0.0 < z1) (n1 = 1) (n2 = 1)
         (abs (z3 - 2 * z1) < 0.001) (n3 = 1) (n4 = 5)   ; two steps on, and the back keys took none
         (st 'px = 0.0) (z3 < st 'pz)                    ; facing the bank, the wading is still down the river
         ; at the lamppost's foot the level is done: keys do nothing, and the settle eases
         ; the view to the aim by 1, the lamp dead ahead and pitched down to its reflection
         (: s (pins (wade-new 80 48) 'pz (lamp-z - 3.5) 'th 0.5 'hz 20) _ (wade-move s 1.0) z (s 'pz)
            _ (wade-step s (wade-kb 107), wade-step s (wade-kb 32), wade-move s 1.0, wade-step s (wade-kb 108), wade-step s (wade-kb 117))
            a (wade-aim s)
            _ (wade-settle s 0.0) t0 (s 'th) h0 (s 'hz)
            _ (wade-settle s 0.5) t5 (s 'th) h5 (s 'hz)
            (wade-settle s 1.0,
             (s 'done && abs (z - (lamp-z - lamp-near)) < 0.001 && s 'pz = z && s 'walk = 0
              && abs (t0 - 0.5) < 0.001 && h0 = 20
              && abs (a 0) < 0.001 && a 1 < 20
              && 0.0 < t5 < 0.5 && a 1 < h5 < 20
              && abs (s 'th - a 0) < 0.001 && s 'hz = a 1
              && !(wade-new 80 48 'done))))))

; the words: the first line shows between its two points, a cell per pixel pair
(: e (texts 0) a (e 0) b (e 1) txt (e 2)
   on (wade-frame (pins (wade-new 80 48) 'pz ((a + b) / 2.0))) off (wade-frame (pins (wade-new 80 48) 'pz b))
 (test (has? on txt) !(has? off txt) (h-count on "▀" = 1920 - #txt) (h-count off "▀" <= 1920)
       (elem txt (texts-at a)) (nelem txt (texts-at b))))

; the helm: turns stop at sixty degrees, tilts clamp, space walks
(: st (wade-new 80 48)
   _ (wade-step st (wade-kb 108)) th1 (st 'th)
   _ (wade-step st (wade-kb -1)) th2 (st 'th)
   _ (each ^100 (i \ wade-step st (wade-kb 104))) th3 (st 'th)
   _ (each ^10 (i \ wade-step st (wade-kb 117))) hz1 (st 'hz)
   _ (each ^20 (i \ wade-step st (wade-kb 110))) hz2 (st 'hz)
   _ (wade-step st (wade-kb 32)) w1 (st 'walk)
   _ (wade-step st (wade-kb 32)) w2 (st 'walk)
   (wade-step st (wade-kb 120), wade-step st 'tap, wade-step st (),
    test (0.0 < th1) (abs th2 < 0.001)
         (-1.05 < th3 < 0.0)                         ; a hundred left turns stop at sixty degrees
         (24 < hz1 <= 36) (12 <= hz2 < 24) (w1 = 1) (w2 = 0)   ; looking up drops the horizon
         (st 'pz = 0.0) (st 'rings = ())
         ; a resize keeps the horizon in proportion and within its bounds
         (wade-size (wade-new 80 48) 100 40 @ s2 (s2 'w = 100 && s2 'h = 80 && s2 'hz = 40 && s2 'foc = 50.0))
         (wade-size (pins (wade-new 80 48) 'hz 12) 80 12 @ s3 (s3 'h = 24 && s3 'hz = 6))))

; the mirror keeps the sky off the top: looking up, the disc is gone but its path stays
(: st (wade-new 80 48) _ (pins st 'th 0.5 'hz 8) up (wade-frame st)
   _ (pin st 'hz 36) down (wade-frame st)
   sky (snip up 0 (has? up "\r\n"))          ; the first row alone
 (test (h-rows up = 24) (h-rows down = 24)
       (pen? up 179)                            ; the path
       !(pen? sky 187)                        ; ..and no sea on the top row: the disc is above it
       (pen? down 230) (pen? down 16)))

; the song: ten seconds into a jug, never silent
(: j (jug 0) s (wade-song-new j (wheel 7))
   (feed n) (0 < n ? (wade-song-feed s, feed (n - 1)) s)
   _ (feed 300)
   out (slurp j)
   loud (net (map (i \ (out (i * 97) != 0 ? 1 0)) ^2000))   ; samples across the first second
   s2 (wade-song-new (jug 0) (wheel 7))
   ((: (go n) (0 < n ? (wade-song-feed s2, go (n - 1))) (go 300)),
    test (#out = 4 * song-chunk * 300) (2 <= s 'struck <= 20) (0 < s 'gong)
         (#slendro = 5) (abs (slendro 4 - 9.6) < 0.001) (slendro 0 = 0.0)
         (100 < loud) (s 'struck = s2 'struck)))            ; ..and the same seed strikes the same

(test_fin (),
 puts "wade: ok -- the moon turns, the banks repeat, a step rings, the mirror keeps the sky, the moon comes down to a lamppost, the words show on the way, and the chimes sound\n")
