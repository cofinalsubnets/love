; --- test/host/wade.l: the night river, headless ---
; not in the test/*.l corpus (it loads a crew module). the scene is pure love, so
; everything but the tty runner gates here: the frame's shape and pens, the moon
; turning with the player and hiding behind them, the banks repeating, a step and
; its ring, the helm's turns and tilts, the walk, the mirror keeping sky that is off
; the top of the screen, and the song into a jug.
;   cat test/00-init.l test/host/wade.l | out/love

(borrow 'wade)    ; the artifact's module, warm from the tree

(: (find h n i) (i + #n < 1 + #h ? (n = snip h i (i + #n) ? 1 (find h n (i + 1))) 0)
   (has? h n) (find h n 0)
   (count s n) (:- (go 0 0) (go i k) (i + #n <= #s ? (go (i + 1) (k + (n = snip s i (i + #n)))) k))
   (rows s) (1 + count s "\r\n")
   (pen? s n) (has? s ("38;5;" + show n + ";") || has? s (";48;5;" + show n + "m"))
   (moon th hz) (moon-at (pins (wade-new 80 48) 'th th 'hz hz)))

; --- the frame: 24 rows of 80 cells, the moon and its path, trees, water and bank ---
(: st (wade-new 80 48) f (wade-frame st)
   wide (wade-new 120 60) g (wade-frame wide)   ; a 120 by 30 terminal
 (test
  (rows f = 24) (count f "▀" = 1920)
  (rows g = 30) (count g "▀" = 3600) (pen? g 230) (pen? g 179) (pen? g 16)
  (wide 'hz = 30) (wide 'foc = 60.0) (wide 'cx = 60.0)
  (pen? f 230) (pen? f 179)                     ; the moon, and the moon in the water
  (pen? f 16) (pen? f 233) (pen? f 232)         ; a near tree, the water's grey, the bank
  (f = wade-frame st)                           ; the same state paints the same frame
  (st 'px = 0.0) (st 'pz = 0.0) (st 'th = 0.0) (st 'hz = 24) (st 'rings = ())))

; --- the moon turns with the player and is off the screen behind them ---
(: a (moon 0.0 24) b (moon 0.64 24) c (moon 3.0 24) d (moon 6.5 24)
   big (moon-at (pins (wade-new 160 48) 'th 0.0 'hz 24))
 (test
  (40.0 < a 0) (b 0 < a 0)                      ; ahead and to the right; a right turn brings it left
  (0.0 < a 2) (c 0 < -900.0)                    ; a radius; behind, far off the screen
  (abs (d 0 - (moon (6.5 - 6.283185307179793) 24) 0) < 0.001)
  (abs (big 0 - 2 * a 0) < 0.001) (abs (big 2 - 2 * a 2) < 0.001)))   ; twice the width, twice the moon

; --- the banks repeat: a whole loop down the river lays the same treeline to within
; --- float noise, though the swell rides the river's length and so the water differs
(: st (wade-new 80 48)
   (line st) (: tb (wade-tables st) (map (x \ [(peep (tb 'tops) x 0) (peep (tb 'bots) x 0)]) ^80))
   (same? a b) (80 = net (map (x \ (abs (a x 0 - b x 0) < 0.001 && abs (a x 1 - b x 1) < 0.001)) ^80))
   l0 (line st) f0 (wade-frame st)
   _ (pin st 'pz (loop * sp)) l1 (line st) f1 (wade-frame st)
   _ (pin st 'pz 7.0) l2 (line st)
   t0 (tree-of 3 1 0) t1 (tree-of (3 + loop) 1 0) t2 (tree-of 4 1 0)
 (test (same? l0 l1) (!(same? l0 l2)) (f0 != f1)
       (t0 'ht = t1 'ht) (t0 'wd = t1 'wd) (t1 'z - t0 'z = loop * sp)
       (t0 'ht != t2 'ht || t0 'wd != t2 'wd)
       (rw < t0 'x) ((tree-of 3 -1 0) 'x < 0.0 - rw)))

; --- a step: along the heading, kept in the river, and a ring, but not two at once ---
(: st (wade-new 80 48)
   _ (wade-step st 107)                         ; k: on
   z1 (st 'pz) n1 #(st 'rings)
   _ (wade-step st 107)
   n2 #(st 'rings)
   _ (pin st 't 10) _ (wade-step st -9)         ; down: back, six ticks on
   n3 #(st 'rings) z3 (st 'pz)
   _ (each '(20 30 40 50 60 70) (t \ (pin st 't t, wade-step st 107)))
   n4 #(st 'rings)
   _ (pins st 'th 1.5707963267948966 'px 0.0)
   _ (each '(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20) (i \ wade-step st 107))
 (test (abs (z1 - 0.35) < 0.001) (n1 = 1) (n2 = 1)
       (abs (z3 - 0.35) < 0.001) (n3 = 2) (n4 = 5)
       (abs (st 'px - (rw - 0.8)) < 0.001)))     ; facing the bank, a walk stops at its edge

; --- the helm: turns wrap, tilts clamp, space walks, the rest is nothing ---
(: st (wade-new 80 48)
   _ (wade-step st 108) th1 (st 'th)
   _ (wade-step st -1) th2 (st 'th)
   _ (each ^100 (i \ wade-step st 104)) th3 (st 'th)
   _ (each ^10 (i \ wade-step st 117)) hz1 (st 'hz)
   _ (each ^20 (i \ wade-step st 110)) hz2 (st 'hz)
   _ (wade-step st 32) w1 (st 'walk)
   _ (wade-step st 32) w2 (st 'walk)
   _ (wade-step st 120) _ (wade-step st 'tap) _ (wade-step st ())
 (test (abs (th1 - 0.08) < 0.001) (abs th2 < 0.001)
       (-3.15 < th3 < 3.15)
       (hz1 = 12) (hz2 = 36) (w1 = 1) (w2 = 0)
       (st 'pz = 0.0) (st 'rings = ())
       ; a resize keeps the horizon in proportion and within its bounds
       (: s2 (wade-size (wade-new 80 48) 100 40) (s2 'w = 100 && s2 'h = 80 && s2 'hz = 40 && s2 'foc = 50.0))
       (: s3 (wade-size (pins (wade-new 80 48) 'hz 12) 80 12) (s3 'h = 24 && s3 'hz = 6))))

; --- the mirror keeps the sky that is off the top: looking up, the moon's disc is past
; --- the screen's edge but its path is in the water; looking down, a full screen paints
(: st (wade-new 80 48) _ (pins st 'th 0.35 'hz 12) up (wade-frame st)
   _ (pin st 'hz 36) down (wade-frame st)
   sky (snip up 0 (find up "\r\n" 0))          ; the first row alone
 (test (rows up = 24) (rows down = 24)
       (pen? up 179)                            ; the path
       (!(pen? sky 187))                        ; ..and no sea on the top row: the disc is above it
       (pen? down 230) (pen? down 16)))

; --- the song: ten seconds into a jug, a chime now and then over a gong, never silent ---
(: j (jug 0) s (wade-song-new j (wheel 7))
   (feed n) (0 < n ? (wade-song-feed s, feed (n - 1)) s)
   _ (feed 300)
   out (slurp j)
   loud (net (map (i \ (out (i * 97) != 0 ? 1 0)) ^2000))   ; samples across the first second
   s2 (wade-song-new (jug 0) (wheel 7))
   _ (: (go n) (0 < n ? (wade-song-feed s2, go (n - 1))) (go 300))
 (test (#out = 4 * song-chunk * 300) (2 <= s 'struck <= 20) (0 < s 'gong)
       (#slendro = 5) (abs (slendro 4 - 9.6) < 0.001) (slendro 0 = 0.0)
       (100 < loud) (s 'struck = s2 'struck)))            ; ..and the same seed strikes the same

(test_fin (),
 puts "wade: ok -- the moon turns, the banks repeat, a step rings, the mirror keeps the sky, and the chimes sound\n")
