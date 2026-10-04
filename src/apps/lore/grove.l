; grove -- a tree grown from a seed, and drawn: a honey locust's habit, its trunk leaning
; toward a point as it climbs and forking two ways two thirds up; each leader throws
; limbs, each limb twigs, and each twig the fronds of a leaf twice pinnate, spear-shaped.
; the trunk and leaders are cylinders, a 'segs list of [a b r] a metre long at most; the
; rest is points, shuffled so any first run of them is the crown thinned evenly.
;
; a scene draws a tree into its buffers -- 't the depth, 'r 'g 'b the colour, trays a
; screen wide -- through a camera tablet: 'e the eye, 'f 'r 'u its forward, right and up,
; 'w 'h 'foc the screen, 'dx 'dy 'dz each pixel's ray. the sun's map of the tree gives the
; shade it casts, on the tree and on the scene (grove-shade).
;
; (grove-new p) grows one; p is a tablet:
;   'seed     the dice                         'base   [x 0 z], where it stands
;   'toward   [x z] the way the trunk leans     'crown  the height leaves start at
;   'inside   p -> p, a point kept in bounds    'keep?  p -> 0 for a point not grown
; a scene's season rides on the tree: 'share how much of the crown is in leaf (1 unless
; said), the rest dropped; 'turn how far the leaves have gone from green to gold
(module (grove grove-new grove-sun grove-shade grove-wood! grove-leaves!)
(borrow 'view)
(borrow 'vec)
(:
 (rnd g) (: s ((g 's * 1103515245 + 12345) % 2147483648) (pin g 's s, s / 2147483648.0))
 (rr g lo hi) (lo + (hi - lo) * rnd g)
 ; d turned off by ang toward a thrown bearing round it
 (spread g d ang) (turn d (turn (side d) d (rr g 0.0 (2.0 * pi))) ang)
 (cat* ls) (foldl (acc \ l \ cat acc l) () ls)
 (grove-new p) (: g {'s (p 'seed % 2147483647 + 1)} segs {'n 0} pts {'n 0}
   inside (peep p 'inside (q \ q)) keep? (peep p 'keep? (q \ 1)) crown-y (peep p 'crown 0.0)
   (seg! a b r) (pins segs (segs 'n) [a b r] 'n (segs 'n + 1))
   (pt! q k sh ye ph) (keep? q ? (: n (pts 'n) (pins pts n [q k sh ye ph] 'n (n + 1))))
   (wob q) (c+ q [(rr g -0.08 0.08) 0.0 (rr g -0.08 0.08)])
   base (p 'base) tw (peep p 'toward [0.0 0.0])
   cdir (unit [(tw 0 - base 0) 0.0 (tw 1 - base 2)])
   hs (rr g 7.2 7.8) lean (rr g 1.7 2.3)
   (tp f) (c+ (c+ base (c* (lean * f * sqrt f) cdir)) [0.0 (hs * f) 0.0])
   tq (map (f \ (0.0 < f < 1.0 ? (wob (tp f)) (tp f))) [0.0 0.25 0.5 0.75 1.0])
   _ (each ^4 (i \ seg! (tq i) (tq (i + 1)) (0.24 - 0.07 * i / 4.0)))
   ; ..the fork's two ways splayed either side of upright, a little toward the lean
   top (tq 4) up0 (unit (c+ [0.0 1.0 0.0] (c* 0.2 cdir))) sd (side (unit (c+ (tq 4) (c* -1.0 (tq 3)))))
   ; a leaf: a rachis drooping off the twig, its leaflets in pairs, widest in the middle
   (leaf! q twd) (q 1 < crown-y ? () (: rd (unit (c+ (spread g twd (rr g 0.5 1.2)) [0.0 -0.35 0.0]))
                    sv (side rd) ll (rr g 0.18 0.3) sh (rr g 0.75 1.15) ye (sq (rnd g)) ph (rr g 0.0 (2.0 * pi))
                    (each ^5 (m \ (: u ((m + 0.5) / 5.0) c (c+ q (c* (ll * u) rd))
                                     wd (0.09 * sin (pi * u) * (1.0 - 0.3 * u))
                                     (pt! (c+ c (c* wd sv)) 2 sh ye ph,
                                      pt! (c+ c (c* (0.0 - wd) sv)) 2 sh ye ph))))))
   ; a twig: its wood as points, leaves along it and one at its tip
   (twig! o ld) (: td (unit (c+ (spread g ld (rr g 0.4 1.1)) [0.0 -0.15 0.0]))
                   tl (rr g 0.5 1.2) e (inside (c+ o (c* tl td)))
                   nw (int (tl / 0.04)) nl (int (tl / 0.09))
                   (each ^nw (q \ pt! (lerp o e (q / (1.0 * nw))) 1 1.0 0.0 0.0),
                    each ^nl (q \ leaf! (lerp o e ((q + 1.0) / (nl + 1.0))) td),
                    leaf! e td))
   ; a limb: wood, twigs along its outer two thirds, and smaller limbs off it, their wood
   ; as points
   (sub! o od) (: sd2 (unit (c+ (spread g od (rr g 0.4 0.9)) [0.0 0.1 0.0]))
                  se (inside (c+ o (c* (rr g 1.2 2.2) sd2)))
                  nw (int (sqrt (dot (c+ se (c* -1.0 o)) (c+ se (c* -1.0 o))) / 0.03))
                  (each ^nw (q \ pt! (lerp o se (q / (1.0 * nw))) 1 1.0 0.0 0.0),
                   each ^5 (j \ twig! (lerp o se (0.3 + 0.17 * j)) sd2)))
   (limb! o od) (: ld (unit (c+ (spread g od (rr g 0.8 1.4)) [0.0 0.25 0.0]))
                   le (inside (c+ o (c* (rr g 3.0 4.5) ld)))
                   nw (int (sqrt (dot (c+ le (c* -1.0 o)) (c+ le (c* -1.0 o))) / 0.025))
                   (each ^nw (q \ pt! (lerp o le (q / (1.0 * nw))) 1 1.0 0.0 0.0),
                    each ^6 (j \ twig! (lerp o le (0.3 + 0.14 * j)) ld),
                    sub! (lerp o le (rr g 0.3 0.45)) ld, sub! (lerp o le (rr g 0.5 0.65)) ld,
                    sub! (lerp o le (rr g 0.7 0.9)) ld))
   ; the two leaders, forking from the trunk's top, each in two pieces, with limbs
   (leader! sg) (: d (unit (turn up0 sd (sg * rr g 0.3 0.5)))
                   ln (rr g 5.0 6.0) m (c+ top (c* (ln * 0.5) d))
                   d2 (unit (c+ d [(rr g -0.1 0.1) 0.3 (rr g -0.1 0.1)]))
                   e (inside (c+ m (c* (ln * 0.5) d2)))
                   (seg! top m 0.14, seg! m e 0.09,
                    limb! (lerp top m 0.9) d, limb! (lerp m e 0.25) d2, limb! (lerp m e 0.5) d2,
                    limb! (lerp m e 0.75) d2, limb! e d2, limb! e d2))
   _ (leader! -1.0) _ (leader! 1.0)
   ; ..the points shuffled
   n (pts 'n) perm (map (q \ q 1) (sort (map (i \ [(rnd g) i]) ^n)))
   (col k) (gem-tray [n] (map (i \ pts i 0 k) perm))
   (fld k) (gem-tray [n] (map (i \ 1.0 * pts i k) perm))
   ; ..and the wood cut into pieces a metre long at most, so each one's box on the screen
   ; hugs it
   (cut s) (: a (s 0) b (s 1) r (s 2) ax (c+ b (c* -1.0 a)) k (int (sqrt (dot ax ax)) + 1)
              (map (i \ [(lerp a b (i / (1.0 * k))) (lerp a b ((i + 1) / (1.0 * k))) r]) ^k))
   sl (cat* (map (i \ cut (segs i)) ^(segs 'n)))
   ; the wood as rings of points, for the shadow the sun casts
   (rings s) (: a (s 0) b (s 1) r (s 2) ax (c+ b (c* -1.0 a)) l (sqrt (dot ax ax)) u (unit ax)
                p1 (side u) p2 (cross u p1) k (int (l / 0.1) + 1)
                (cat* (map (i \ (lerp a b (i / (1.0 * k))) @ c
                                  (map (j \ c+ c (c+ (c* (r * cos (j * 1.047)) p1) (c* (r * sin (j * 1.047)) p2))) ^6))
                           ^(k + 1))))
   wood (cat* (map rings sl)) nwd #wood
   X (col 0) Y (col 1) Z (col 2)
   cen [(net X / n) (net Y / n) (net Z / n)]
   R (sqrt (amax ((X - cen 0) * (X - cen 0) + (Y - cen 1) * (Y - cen 1) + (Z - cen 2) * (Z - cen 2))) + 0.5)
   (wc k) (gem-tray [nwd] (map (q \ q k) wood))
   {'segs sl 'base base 'x X 'y Y 'z Z 'kind (fld 1) 'shade (fld 2) 'yel (fld 3) 'ph (fld 4)
    'shx (wc 0) 'shy (wc 1) 'shz (wc 2) 'c cen 'R R 'cache {}})
 ; the sun's map of the tree: every point and the wood's rings seen down the sun, a
 ; texel keeping how far toward the sun the tree stands there; () while the sun is down
 smap-n 128
 (smap-new tr s) (s 1 <= 0.0 ? ()
   (: e1 (side s) e2 (cross e1 s) c (tr 'c) R (tr 'R) n smap-n on (in-leaf tr)
      (pix X Y Z) (: qx (X - c 0) qy (Y - c 1) qz (Z - c 2)
                     iu (floor (((qx * e1 0 + qy * e1 1 + qz * e1 2) / (2.0 * R) + 0.5) * n))
                     iv (floor (((qx * e2 0 + qy * e2 1 + qz * e2 2) / (2.0 * R) + 0.5) * n))
                     (over -1 ((0 <= iu) * (iu < n) * (0 <= iv) * (iv < n)) (iv * n + iu)))
      (depth X Y Z) (X * s 0 + Y * s 1 + Z * s 2)
      m0 (iota (n * n) * 0.0 - 1e9)
      m1 (pin m0 (over -1 on (pix (tr 'x) (tr 'y) (tr 'z))) (depth (tr 'x) (tr 'y) (tr 'z)))
      m2 (pin m1 (pix (tr 'shx) (tr 'shy) (tr 'shz)) (depth (tr 'shx) (tr 'shy) (tr 'shz)))
      {'map m2 'pix pix 'depth depth}))
 ; the sun's map and each point's share of the sun, kept on the tree until the sun has
 ; moved a step: [map share]. clear (X Y Z s) is how much of the sun the scene lets reach
 ; the points, before the tree's own shade
 ; which of the tree's points are on it: all the wood, and the leaves the season has kept
 (in-leaf tr) ((tr 'kind != 2.0) + (tr 'kind = 2.0) * (tr 'ph / (2.0 * pi) < peep tr 'share 1.0))
 (grove-sun tr s clear) (: k [(int (s 0 * 400.0) * 1000000 + int (s 1 * 400.0) * 1000 + int (s 2 * 400.0))
                              (int (peep tr 'share 1.0 * 200.0))]
   cc (tr 'cache)
   (k = cc 'key ? (cc 'sun)
      (: sm (smap-new tr s) X (tr 'x) Y (tr 'y) Z (tr 'z)
         c [sm (clear X Y Z s * (1.0 - grove-shade sm X Y Z))]
         (pins cc 'key k 'sun c, c))))
 ; how much of the sun the tree takes at the points X Y Z: some of it through the leaves
 (grove-shade sm X Y Z) (sm ? (0.8 * (sm 'depth X Y Z + 0.3 < peep (sm 'map) (sm 'pix X Y Z) -1e9)) 0.0)
 ; the wood drawn into the buffers: each cylinder tried only on the pixels of its box on
 ; the screen, kept where it is nearer than what is there. lt is sky's light
 (grove-wood! tr cam lt clear buf) (: e (cam 'e) f (cam 'f) rt (cam 'r) uv (cam 'u) w (cam 'w) h (cam 'h) foc (cam 'foc)
   s (lt 'sun) sm (grove-sun tr s clear 0)
   (rel q) (c+ q (c* -1.0 e))
   (proj q) (rel q @ v (dot v f @ z [(w / 2.0 + foc * dot v rt / z) (h / 2.0 - foc * dot v uv / z)]))
   (one sg) (: a0 (sg 0) b0 (sg 1) r (sg 2)
     za (dot (rel a0) f) zb (dot (rel b0) f)
     ((za < 0.1 && zb < 0.1) ? ()
      (: a (za < 0.1 ? (lerp a0 b0 ((0.1 - za) / (zb - za))) a0)
         b (zb < 0.1 ? (lerp b0 a0 ((0.1 - zb) / (za - zb))) b0)
         pa (proj a) pb (proj b) rp (r * foc / max2 0.1 (min2 za zb) + 1.5)
         x0 (max2 0 (flo (min2 (pa 0) (pb 0) - rp))) x1 (min2 (w - 1) (flo (max2 (pa 0) (pb 0) + rp)))
         y0 (max2 0 (flo (min2 (pa 1) (pb 1) - rp))) y1 (min2 (h - 1) (flo (max2 (pa 1) (pb 1) + rp)))
         bw (x1 - x0 + 1) bh (y1 - y0 + 1)
         ((bw <= 0 || bh <= 0) ? ()
          (: ii (iota (bw * bh)) idx ((y0 + ii // bw) * w + x0 + ii % bw)
             ddx (peep (cam 'dx) idx 0.0) ddy (peep (cam 'dy) idx 0.0) ddz (peep (cam 'dz) idx 0.0)
             ax (c+ b0 (c* -1.0 a0)) L (sqrt (dot ax ax)) u (unit ax)
             wv (rel a0 @ q (c* -1.0 q)) wu (dot wv u) W (c+ wv (c* (0.0 - wu) u))
             dd (ddx * u 0 + ddy * u 1 + ddz * u 2)
             Wd (ddx * W 0 + ddy * W 1 + ddz * W 2)
             A (max (1.0 - dd * dd) 1e-9) C (dot W W - r * r)
             disc (Wd * Wd - A * C)
             t ((0.0 - Wd - sqrt (max disc 0.0)) / A)
             sa (wu + t * dd)
             ; ..each piece runs on half its radius past either end, so a bend shows no gap
             hit ((0.0 < disc) * (0.0 < t) * (-0.5 * r <= sa) * (sa <= L + 0.5 * r) * (t < peep (buf 't) idx 1e9))
             i2 (over -1 hit idx)
             nx ((W 0 + t * (ddx - dd * u 0)) / r) ny ((W 1 + t * (ddy - dd * u 1)) / r) nz ((W 2 + t * (ddz - dd * u 2)) / r)
             X (e 0 + t * ddx) Y (e 1 + t * ddy) Z (e 2 + t * ddz)
             p1 (side u)
             fur (0.75 + 0.5 * frac (sin ((nx * p1 0 + ny * p1 1 + nz * p1 2) * 9.0 + sa * 3.0) * 4375.85))
             nds (max 0.0 (nx * s 0 + ny * s 1 + nz * s 2))
             lit (nds * clear X Y Z s * (1.0 - grove-shade sm X Y Z) * lt 'sunk)
             bark (c* fur [0.17 0.15 0.13])
             irr (c+ (c* 0.9 (lt 'amb)) (c* lit (lt 'sunc)))
             cl (cm bark irr)
             (pins buf 't (pin (buf 't) i2 t) 'r (pin (buf 'r) i2 (cl 0))
                       'g (pin (buf 'g) i2 (cl 1)) 'b (pin (buf 'b) i2 (cl 2))))))))
   (each (tr 'segs) one))
 ; the twigs and leaves drawn into the buffers, a point a pixel, kept where nearer; the
 ; leaves sway, darken deep in the crown and glow where the sun is behind them. only the
 ; first k of the shuffled points are drawn, k kept on the tree so the last frame drew
 ; about leaf-n of them to a pixel the crown took. t0 is the frame's clock
 leaf-n 4.0
 (grove-leaves! tr cam lt clear buf t0) (: e (cam 'e) f (cam 'f) rt (cam 'r) uv (cam 'u) w (cam 'w) h (cam 'h) foc (cam 'foc)
   s (lt 'sun) lc0 (grove-sun tr s clear 1)
   n #(tr 'x) cc (tr 'cache) k (min n (peep cc 'k n)) ik (iota k) (fk q) (peep (tr q) ik 0.0)
   lf (fk 'kind = 2.0) ph (fk 'ph) lc (peep lc0 ik 0.0)
   on ((1 - lf) + lf * (ph / (2.0 * pi) < peep tr 'share 1.0))
   sw (0.025 * sin (t0 * 0.13 + ph)) sw2 (0.02 * sin (t0 * 0.09 + ph * 1.7))
   X (fk 'x + lf * sw) Y (fk 'y) Z (fk 'z + lf * sw2)
   qx (X - e 0) qy (Y - e 1) qz (Z - e 2)
   zc (qx * f 0 + qy * f 1 + qz * f 2)
   zs (max zc 0.1)
   cx (floor (w / 2.0 + foc * (qx * rt 0 + qy * rt 1 + qz * rt 2) / zs))
   cy (floor (h / 2.0 - foc * (qx * uv 0 + qy * uv 1 + qz * uv 2) / zs))
   dist (sqrt (qx * qx + qy * qy + qz * qz))
   ok ((0.1 < zc) * (0 <= cx) * (cx < w) * (0 <= cy) * (cy < h))
   idx (over -1 ok (cy * w + cx))
   i2 (over -1 (on * (dist < peep (buf 't) idx 1e9)) idx)
   lit (lc * lt 'sunk)
   mu ((qx * s 0 + qy * s 1 + qz * s 2) / dist)
   glow (lf * lit * sq (sat ((mu - 0.2) / 0.8)))
   sh (fk 'shade)
   ; ..green, or gold as far as the season has turned it, the yellower leaves first
   yel (fk 'yel) gold (sat ((peep tr 'turn 0.0 - 0.4 * (1.0 - yel)) / 0.6))
   leafc (cmix (c+ (c* sh [0.2 0.34 0.09]) (c* yel [0.16 0.14 -0.02])) (c* sh [0.62 0.48 0.1]) gold)
   base (cmix [0.16 0.14 0.12] leafc lf)
   irr (c+ (c* 0.8 (lt 'amb)) (c* (0.6 * lit) (lt 'sunc)))
   cl (c+ (cm base irr) (c* glow [0.45 0.55 0.12]))
   ; ..and the next frame's k, by how many drawn points fell to a pixel they took, moved
   ; only by a quarter or more so a still view settles
   drawn (net (0 <= i2)) took (net (pin (iota (w * h) * 0) i2 1))
   k2 (max (min n 2000) (min n (int (k * leaf-n * max2 1 took / max2 1 drawn))))
   _ (k2 * 4 < k * 3 || k * 5 < k2 * 4 ? (pin cc 'k k2))
   (pins buf 't (pin (buf 't) i2 dist) 'r (pin (buf 'r) i2 (cl 0))
             'g (pin (buf 'g) i2 (cl 1)) 'b (pin (buf 'b) i2 (cl 2)))))
) ; module grove
