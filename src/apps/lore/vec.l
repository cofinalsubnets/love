; vec -- triples whose parts are numbers or trays alike: a point, a direction or a colour
; for one pixel or for a whole screen of them, and the arithmetic of each. and the hash's
; value noise, eased between its lattice, for any texture a scene lays; the dice a scene
; throws; and points as a camera tablet sees them ('e 'f 'r 'u the eye and its axes, 'w 'h 'foc).
(module (vec sat sq mag frac c* cm c+ cmix dot unit cross lerp turn side vn rnd rnd-new sight spot)
(borrow 'view)                          ; the hash, min2 max2 flo over
(:
 (sat v) (min 1.0 (max 0.0 v))
 (sq v) (v * v)
 (mag v) (max v (0.0 - v))              ; abs elementwise: abs of a tray is its norm
 (frac v) (v - floor v)
 (c* k a) [(k * a 0) (k * a 1) (k * a 2)]
 (cm a b) [(a 0 * b 0) (a 1 * b 1) (a 2 * b 2)]
 (c+ a b) [(a 0 + b 0) (a 1 + b 1) (a 2 + b 2)]
 (cmix a b m) [(a 0 + m * (b 0 - a 0)) (a 1 + m * (b 1 - a 1)) (a 2 + m * (b 2 - a 2))]
 (dot a b) (a 0 * b 0 + a 1 * b 1 + a 2 * b 2)
 (unit a) (c* (1.0 / sqrt (max2 1e-12 (dot a a))) a)
 (cross a b) [(a 1 * b 2 - a 2 * b 1) (a 2 * b 0 - a 0 * b 2) (a 0 * b 1 - a 1 * b 0)]
 (lerp a b f) (c+ a (c* f (c+ b (c* -1.0 a))))
 ; d turned by ang about the unit axis k, and a unit square to d
 (turn d k ang) (: c (cos ang) sn (sin ang)
                   (c+ (c+ (c* c d) (c* sn (cross k d))) (c* (dot k d * (1.0 - c)) k)))
 (side d) (unit (cross d (mag (d 1) < 0.95 ? [0.0 1.0 0.0] [1.0 0.0 0.0])))
 ; value noise: the hash on a lattice, eased between
 (vn x z s) (: ix (floor x) iz (floor z) ux (x - ix) uz (z - iz)
               ex (ux * ux * (3.0 - 2.0 * ux)) ez (uz * uz * (3.0 - 2.0 * uz))
               (h i k) (throw i k s 1024 / 1023.0)
               p (h ix iz) q (h (ix + 1) iz) r (h ix (iz + 1)) t (h (ix + 1) (iz + 1))
               lo (p + ex * (q - p)) hi (r + ex * (t - r))
               (lo + ez * (hi - lo)))
 ; the dice: an lcg on g's 's, each throw in [0 1)
 (rnd-new seed) {'s (seed % 2147483647 + 1)}
 (rnd g) (: s ((g 's * 1103515245 + 12345) % 2147483648) (pin g 's s, s / 2147483648.0))
 ; points X Y Z as [qx qy qz dist idx]: q from the eye, idx each one's pixel, -1 behind
 ; the near plane or off the screen
 (sight cam X Y Z) (: e (cam 'e) f (cam 'f) rt (cam 'r) uv (cam 'u) w (cam 'w) h (cam 'h) foc (cam 'foc)
   qx (X - e 0) qy (Y - e 1) qz (Z - e 2)
   zc (qx * f 0 + qy * f 1 + qz * f 2) zs (max zc 0.1)
   cx (floor (w / 2.0 + foc * (qx * rt 0 + qy * rt 1 + qz * rt 2) / zs))
   cy (floor (h / 2.0 - foc * (qx * uv 0 + qy * uv 1 + qz * uv 2) / zs))
   ok ((0.1 < zc) * (0 <= cx) * (cx < w) * (0 <= cy) * (cy < h))
   [qx qy qz (sqrt (qx * qx + qy * qy + qz * qz)) (over -1 ok (cy * w + cx))])
 ; the pixels of the screen's box round the points qs, pad pixels wider: a segment's end
 ; behind the eye cut back to the near plane, else all the screen when one is behind
 (spot qs pad cam) (: e (cam 'e) f (cam 'f) rt (cam 'r) uv (cam 'u) w (cam 'w) h (cam 'h) foc (cam 'foc)
   (z q) (dot (c+ q (c* -1.0 e)) f)
   (proj q) (c+ q (c* -1.0 e) @ v [(w / 2.0 + foc * dot v rt / z q) (h / 2.0 - foc * dot v uv / z q)])
   (box ps) (: xs (map (p \ p 0) ps) ys (map (p \ p 1) ps)
               x0 (max2 0 (flo (foldl min2 1e9 xs - pad))) x1 (min2 (w - 1) (flo (foldl max2 -1e9 xs + pad)))
               y0 (max2 0 (flo (foldl min2 1e9 ys - pad))) y1 (min2 (h - 1) (flo (foldl max2 -1e9 ys + pad)))
               bw (x1 - x0 + 1) bh (y1 - y0 + 1)
               ((bw <= 0 || bh <= 0) ? () (iota (bw * bh) @ ii ((y0 + ii // bw) * w + x0 + ii % bw))))
   zs (map z qs) nb #(filter (v \ v < 0.1) zs)
   (? (nb = #qs) ()
      (nb = 0) (box (map proj qs))
      (#qs = 2) (: a (qs 0) b (qs 1) za (zs 0) zb (zs 1)
                   (box [(proj (za < 0.1 ? (lerp a b ((0.1 - za) / (zb - za))) a))
                         (proj (zb < 0.1 ? (lerp b a ((0.1 - zb) / (za - zb))) b))]))
      (iota (w * h)))))
) ; module vec
