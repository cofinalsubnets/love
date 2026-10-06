; test/host/stones.l -- the canyon and the bowl, headless: the frame in both palettes, the
; rock where it should stand, the ring and its missing stone, the audience thrown each run,
; walking up the slot and into what stops it, and out of the mouth to the end.
; not in the corpus: a crew module. run: cat test/00-init.l test/host/stones.l | out/love

(borrow 'stones)   ; the artifact's module, warm from the tree
(borrow 'vec)
(borrow 'view)     ; pi, wrap

(: (count s n) (:- (go 0 0) (go i k) (i + #n <= #s ? (go (i + 1) (k + (n = snip s i (i + #n)))) k))
   (rows s) (1 + count s "\r\n")
   day0 (1.0 * 1790812800)                          ; 2026-10-01, midnight on the wall clock
   (at hr sd) (stones-new 80 48 [(day0 + hr * 3600.0) 3600] sd)
   (keys! st ks) (each ks (k \ (stones-step st k, stones-move st)))
   (ang b) (: x (b 0 + 1e-9) a (atan ((b 2 - zc) / x)) (x < 0.0 ? (a + pi) a)))

; --- the frame: half the pixel rows in cells, the same state the same frame, in the 256
; --- palette and in 24 bits; and the same again once kept, standing still
(: st (at 12.0 7) f (stones-frame st) f2 (stones-frame st)
   deep (stones-frame (pin (at 12.0 7) 'deep 1))
 (test (rows f = 24) (f = f2) (rows deep = 24) (f != deep)
       (has? f "38;5;") (has? deep "38;2;")))

; --- the rock: open air at the eye, and the sand under it; rock either side of the slot
; --- and over the bowl's rim, the bowl open down to its floor, the plain open past the mouth
(: st (at 12.0 7) x (st 'px)
 (test (0.3 < stones-field x eye-h 0.0) (stones-field x -0.1 0.0 < 0.0)
       (stones-field (x + 4.0) 1.0 0.0 < 0.0) (stones-field (x - 4.0) 1.0 0.0 < 0.0)
       (stones-field (slot-x 50.0) 1.0 50.0 > 0.0) (stones-field 0.0 1.0 zc > 0.0) (stones-field 0.0 -0.1 zc < 0.0)
       (stones-field (rim-r + 3.0) 9.0 zc < 0.0) (stones-field 20.0 1.0 (exit-z - 10.0) > 0.0)
       (stones-ground x 0.0 = 0.0) (stones-ground 0.0 zc = 0.0)
       (rows * row-h - 1.0 < stones-ground (floor-r + rows * row-w - 0.5) zc)))

; --- the blocks: the altar in the middle, the ring of seven round it -- every place of the
; --- octagon but the north-west -- and the audience on the rows, three to six of them,
; --- none in the slot's notch; the same run the same audience, another run another
(: bs (stones-blocks 7) al <bs ring (filter (b \ b 7 = 1 && sqrt (sq (b 0) + sq (b 2 - zc)) < 7.0) bs)
   aud (filter (b \ b 7 = 1 && 7.0 < sqrt (sq (b 0) + sq (b 2 - zc))) bs)
   (slot b) (int (wrap (ang b) / (pi / 4.0) + 8.5) % 8)
   places (sort (map slot ring))
   (on-row? b) (: g (stones-ground (b 0) (b 2)) (row-h - 0.1 <= g && g <= rows * row-h))
   (notch? b) (mag (wrap (ang b + pi / 2.0)) < 0.4)
   counts (map (sd \ #(stones-blocks sd) - 8) ^40)
 (test (al 7 = 0) (al 0 = 0.0) (al 2 = zc) (#ring = 7) (places = [0 1 2 4 5 6 7])
       (3 <= #aud) (#aud <= 6) (all on-row? aud) !(any notch? aud)
       (show (stones-blocks 7) = show bs) (show (stones-blocks 8) != show bs)
       (all (n \ 3 <= n && n <= 6) counts) (any (n \ n != 3) counts)))

; --- walking: k steps the way you face, j back, h and l turn; the slot's walls stop you
; --- and you slide along them; u and n tilt the look; the eye rides the ground
(: st (at 12.0 7) z0 (st 'pz) th0 (st 'th)
   _ (keys! st [107 107 107]) z1 (st 'pz)
   _ (keys! st [106]) z2 (st 'pz)
   _ (keys! st [108 108]) th1 (st 'th)
   st2 (pins (at 12.0 7) 'th (pi / 2.0)) _ (keys! st2 (map (i \ 107) ^200)) x2 (st2 'px)
   _ (keys! st (map (i \ 117) ^100)) up (st 'ph)
 (test (z0 < z1) (z2 < z1) (z0 < z2) (th0 < th1)
       (mag (x2 - slot-x (st2 'pz)) < 2.0) (stones-field x2 1.0 (st2 'pz) > 0.0)
       (up <= 1.45) (1.4 < up) (st 'py = eye-h)))

; --- up the rows in the bowl and down again, the eye with the ground; never up the bowl's
; --- wall past its last row; and the altar stands in the way
(: st (pins (at 12.0 7) 'px 0.0 'pz (zc + floor-r - 0.5) 'th 0.0 'py eye-h 'blocks [])
   _ (keys! st (map (i \ 107) ^600)) top (st 'py)
   ab (pins (at 12.0 7) 'px 0.0 'pz (zc - 3.0) 'th 0.0 'py eye-h)
   _ (keys! ab (map (i \ 107) ^100))
 (test (eye-h + (rows - 1) * row-h < top) (top < eye-h + rows * row-h + 0.5)
       (ab 'pz < zc - 0.5)))

; --- out: turned round and walked back out of the mouth, the run is done, and the keys
; --- do no more
(: st (pins (at 12.0 7) 'th pi)
   _ (keys! st (map (i \ 107) ^700)) z (st 'pz)
   _ (keys! st [107 107])
 (test (st 'done = 1) (z < exit-z) (st 'pz = z)))
