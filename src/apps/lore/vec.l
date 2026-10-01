; vec -- triples whose parts are numbers or trays alike: a point, a direction or a colour
; for one pixel or for a whole screen of them, and the arithmetic of each. and the hash's
; value noise, eased between its lattice, for any texture a scene lays.
(module (vec sat sq mag frac c* cm c+ cmix dot unit cross lerp turn side vn)
(borrow 'view)                          ; the hash, min2 max2
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
               (lo + ez * (hi - lo))))
) ; module vec
