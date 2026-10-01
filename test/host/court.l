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

(test_fin ())
(puts "court: ok")
