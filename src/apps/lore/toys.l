; toys -- the stuffed toys a level lays about, made rather than modelled: (toy-mesh name) the
; toy's mesh, its nose toward z, the floor somewhere under it, or () where none is so named
(module (toys toy-mesh)
(borrow '(mesh vec))
(:
 ; a surface nu round by nv along, (f i j) each corner [x y z], (o i j p) the way out at p
 (skin nu nv f o col)
  (: vs (catmap (j \ map (i \ f i j + [0.0 0.0 0.0 0.0 0.0] + col) ^nu) ^(nv + 1))
     (at i j) (j * nu + i % nu)
     ts (catmap (k \ (: i (k % nu) j (k // nu) a (at i j) b (at (i + 1) j) c (at (i + 1) (j + 1)) d (at i (j + 1)) A (f i j)
                        (dot (cross (c- (f (i + 1) (j + 1)) A) (c- (f (i + 1) j) (f i (j + 1)))) (o i j A) < 0.0
                         ? [[a c b -1] [a d c -1]] [[a b c -1] [a c d -1]])))
                  ^(nu * nv))
     (mesh-normals (mesh vs ts)))
 (bead c r col) (skin 12 8 (\ i j (: o (tau * i / 12) a (pi * (j / 8 - 0.5)) (c+ c (c* r [(cos a * sin o) (sin a) (cos a * cos o)]))))
                     (\ i j p (c- p c)) col)
 ; ..the mouse: a pear round behind and pointed before, its belly flatter than its back, cupped
 ; ears grey inside and thin at the rim, bead eyes, a big round nose, a grey cord of a tail
 red [0.8 0.1 0.1] fawn [0.74 0.72 0.66] grey [0.5 0.48 0.47] dark [0.04 0.03 0.03] z0 -0.13 z1 0.2
 (cy t) (0.062 - 0.012 * t)
 (body t o) (: s (sin (pi * t ** 0.7)) b (0.13 * s) co (cos o)
   [(0.095 * s * sin o) (cy t + b * co * (co < 0.0 ? 0.62 1.0)) (z0 + (z1 - z0) * t)])
 (ear sg) (: P (body 0.58 (sg * 1.15)) N (unit [(sg * 0.8) 0.15 1.0]) U (unit (cross [0.0 1.0 0.0] N)) V0 (cross N U)
   V (V0 1 < 0.0 ? (c* -1.0 V0) V0) E (c- (c+ P (c* 0.024 V)) (c* 0.004 N))
   (pt i j side) (: g (tau * i / 16) r (j / 4)
     (c+ E (c+ (c* (0.045 * r * cos g) U) (c+ (c* (0.045 * r * sin g) V) (c* (side * 0.002 * (1.0 - r ** 4) - 0.01 * (1.0 - r * r)) N)))))
   (mesh-join [(skin 16 4 (\ i j (pt i j 1.0)) (\ i j p N) fawn) (skin 16 4 (\ i j (pt i j -1.0)) (\ i j p (c* -1.0 N)) red)]))
 (eye sg) (: P (body 0.8 (sg * 0.95)) w (unit [(P 0) (P 1 - cy 0.8) 0.0]) (bead (c- P (c* 0.004 w)) 0.013 dark))
 (tq u) (: f (0.9 * u) [(0.25 * (1.0 - cos f)) (0.008 + 0.03 * (1.0 - u) ** 3) (z0 + 0.015 - 0.25 * sin f)])
 (tp i j) (: u (j / 14) q (tq u) T (unit (c- (tq (u + 0.01)) q)) A (unit (cross T [0.0 1.0 0.0])) B (cross A T)
   g (tau * i / 8) r 0.008
   (c+ q (c+ (c* (r * cos g) A) (c* (r * sin g) B))))
 (mouse _) (mesh-join [(skin 24 24 (\ i j (body (j / 24) (tau * i / 24))) (\ i j p [(p 0) (p 1 - cy (j / 24)) 0.0]) red)
                       (ear 1.0) (ear -1.0) (eye 1.0) (eye -1.0) (bead [0.0 (cy 1.0) (z1 - 0.007)] 0.016 dark)
                       (skin 8 14 tp (\ i j p (c- p (tq (j / 14)))) grey) (bead (tq 1.0) 0.008 grey)])
 (toy-mesh name) (name @ 'mouse (mouse ()) _ ()))
) ; module toys
