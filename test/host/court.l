; test/host/court.l -- the courtyard, headless: the frame in both palettes, the sun by
; the hour, the low sun on the top of the wall it faces, walking, looking, and the clock.
; not in the corpus: a crew module. run: cat test/00-init.l test/host/court.l | out/love

(borrow 'court)   ; the artifact's module, warm from the tree

(: (count s n) (:- (go 0 0) (go i k) (i + #n <= #s ? (go (i + 1) (k + (n = snip s i (i + #n)))) k))
   (rows s) (1 + count s "\r\n")
   day0 (1.0 * 1790812800)                          ; 2026-10-01, midnight on the wall clock
   (at hr) (court-new 80 48 [(day0 + hr * 3600.0) 3600])
   (near? a b) (a - b @ d (d * d < 0.0001))
   (keys! st ks) (each ks (k \ court-step st k)))

; --- the frame: half the pixel rows in cells, the same state the same frame, in the 256
; --- palette and in 24 bits; the clock in the corner at the start and gone after
(: st (at 12.0) f (court-frame st) f2 (court-frame st)
   deep (court-frame (pin (at 12.0) 'deep 1))
   _ (pin st 't 100) quiet (court-frame st)
 (test (rows f = 24) (f = f2) (rows deep = 24) (f != deep)
       (has? f "38;5;") (has? deep "38;2;")
       (has? f (court-clock st)) !(has? quiet (court-clock st))))

; --- the sun: up by day and down by night, south at noon, east in the morning and west in
; --- the evening, a unit vector; summer's hour is taken off the wall clock
(: (sun hr) (court-sun (at hr)) n (sun 13.0) m (sun 8.0) e (sun 18.0) mid (sun 1.0)
   (len s) (s 0 * s 0 + s 1 * s 1 + s 2 * s 2)
 (test (0.0 < n 1) (mid 1 < 0.0) (m 1 < n 1) (e 1 < n 1)
       (n 2 < 0.0) (0.0 < m 0) (e 0 < 0.0)
       (near? (len n) 1.0) (near? (len e) 1.0)
       (sun 13.0 = court-sun (court-new 80 48 [(day0 + 12.0 * 3600.0) 0]))))

; --- the light: day at noon and none at midnight, the eye's gain up in the dark; and the
; --- low sun orange, the high sun near white
(: noon (court-light (at 13.0)) night (court-light (at 1.0)) low (court-light (at 17.6))
 (test (noon 'day = 1.0) (night 'day = 0.0) (noon 'expo < night 'expo)
       (0.0 < low 'sunk) (low 'sunc 2 < 0.5) (0.75 < noon 'sunc 2)))

; --- the low sun on the rim: an hour before sunset, looking up the east wall from across
; --- the yard, the top of the wall is warm and lit and its foot is not
(: st (pins (at 17.4) 'px (0.0 - yard-a + 0.5) 'pz 0.0 'th (pi / 2.0) 'ph 1.1)
   c (court-pens st) w (st 'w)
   ; the column down the middle: the rim's row is the first from the top that is wall
   (px k y) (peep (c k) (y * w + w // 2) 0.0)
   (warm? y) (px 2 y + 0.08 < px 0 y)
   top (foldl (a \ y \ (a < 0 && warm? y ? y a)) -1 ^(st 'h))
 (test (0 <= top) !(warm? (st 'h - 1))))

; --- walking: k steps the way you face, j back; h and l turn; the walls stop you; u and
; --- n tilt the look, never past straight up or down ---
(: st (at 12.0) z0 (st 'pz) th0 (st 'th)
   _ (keys! st [107 107 107]) z1 (st 'pz)
   _ (keys! st [106]) z2 (st 'pz)
   _ (keys! st [108 108]) th1 (st 'th)
   _ (keys! st (map (i \ 107) ^400)) far (st 'px)
   _ (keys! st (map (i \ 117) ^100)) up (st 'ph)
   _ (keys! st (map (i \ 110) ^100)) down (st 'ph)
 (test (z0 < z1) (z2 < z1) (z0 < z2) (th0 < th1)
       (near? far (yard-a - body-r)) (up <= 1.45) (1.4 < up) (-1.21 < down) (down < -1.1)))

; --- the time: ] and [ an hour on and back, t the pace, a frame its share of it ---
(: st (at 12.0) s0 (st 'sim)
   _ (keys! st [93 93 91]) s1 (st 'sim)
   _ (court-move st) s2 (st 'sim)
   _ (keys! st [116]) _ (court-move st) s3 (st 'sim)
   _ (keys! st [116 116]) _ (court-move st) s4 (st 'sim)
 (test (near? (s1 - s0) 3600.0) (near? (s2 - s1) (paces 0 / fps))
       (near? (s3 - s2) (paces 1 / fps)) (near? s4 s3)
       (court-clock st = "13:00")
       (court-now () @ n (two? n && 0.0 < n 0))))

; --- the battlements: the sun past the north wall's middle third, and stopped by a block
; --- over an outer third; a block's face high enough sees over the far one
(: s (unit [0.0 0.2 1.0]) b0 (0.0 - yard-b)
 (test (sun-clear 0.0 12.6 b0 s = 1) (sun-clear 2.5 12.6 b0 s = 0)
       (sun-clear 2.5 14.0 b0 s = 1) (sun-clear 2.5 12.6 b0 (unit [0.0 1.0 0.1]) = 1)
       (sun-clear 0.0 1.0 0.0 (unit [0.0 -0.1 1.0]) = 0)))

; --- the tree: the same seed the same tree; planted in the north-east quarter, leaning
; --- toward the middle, forked in the third floor, every leaf inside the walls below their
; --- tops, the crown from a metre under them (its fronds hanging lower) to well over;
; --- and drawn: the frame with it is not the frame without
(: t1 (tree-new 7) t2 (tree-new 7) t3 (tree-new 8) bs (t1 'base) segs (t1 'segs)
   fork (segs 3 1) n (#(t1 'x))
   (in? k lim) (aall (mag (t1 k) <= lim + 0.0001 + 99.0 * (wall-h <= t1 'y)))
   st (pins (at 12.0) 'px -2.0 'pz -3.5 'th 0.6 'ph 0.9)
   f1 (court-frame st) f2 (court-frame (pin st 'tree (tree-new 7 @ tr (pins tr 'segs () 'kind (tr 'kind * 0.0 - 1.0) 'x (tr 'x * 0.0 - 99.0)))))
 (test (show (t1 'segs) = show (t2 'segs)) (aall (t1 'x = t2 'x)) (show (t1 'segs) != show (t3 'segs))
       (0.0 < bs 0) (0.0 < bs 2) (mag (fork 0) < bs 0) (mag (fork 2) < bs 2)
       (7.0 < fork 1 < 8.0) (#segs = 8) (5000 < n)
       (in? 'x (yard-a - 0.1)) (in? 'z (yard-b - 0.1)) (aall (0.0 < t1 'y))
       (aall (0 < (t1 'kind != 2.0) + (wall-h - 1.4 <= t1 'y))) (wall-h + 2.0 < amax (t1 'y))
       (f1 != f2)))

; --- the trunk stands in the way: walking into it, the player stays a body's width off
(: st (at 12.0) bs (st 'tree 'base)
   _ (pins st 'px (bs 0) 'pz (bs 2 - 1.5) 'th 0.0)
   _ (keys! st (map (i \ 107) ^60))
 (test (0.55 < sqrt (sq (st 'px - bs 0) + sq (st 'pz - bs 2)))))

(test_fin ())
(puts "court: ok")
