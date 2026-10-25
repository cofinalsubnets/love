; bough -- a tree to climb, grown as a level loads: a tree of heaven from grove's kit, its
; trunk bare and near upright to a fork near 7 m, climbed as a ladder is; its wood kept
; inside a 2 m well from 3.8 to 4.7 m. its foot at 0 0 0.
;   (bough-solid seed)                 its trunk, [a b r] each piece: what a body climbs
;   (bough-mesh seed tex ts)           it drawn: its wood under texture tex, ts metres a
;                                      texel, and its leaves
(module (bough bough-solid bough-mesh)
(borrow 'vec)                           ; triples
(borrow 'mesh)                          ; the mesh it makes
(borrow 'view)                          ; min2, max2
(borrow 'grove)                         ; the tree of heaven
(:
 ; its habit: the trunk a little crooked to a fork near 7 m, and off the fork two limbs up,
 ; their heads, and long branches sweeping out, twigs and leaves at the ends
 (habit k) (: rr (k 'rr) spread (k 'spread) dir (k 'dir) seg! (k 'seg) branch! (k 'branch)
              head! (k 'head) spray! (k 'spray) sprig! (k 'sprig) tuft! (k 'tuft)
   hf (rr 6.6 7.4) top [(rr -0.15 0.15) hf (rr -0.15 0.15)]
   (tp f) [(f * top 0) (f * hf) (f * top 2)]
   tq (map (f \ (0.0 < f < 1.0 ? (c+ (tp f) [(rr -0.08 0.08) 0.0 (rr -0.08 0.08)]) (tp f))) [0.0 0.2 0.4 0.6 0.8 1.0])
   _ (each ^5 (i \ seg! (tq i) (tq (i + 1)) (0.3 - 0.12 * i / 5.0)))
   fk (tq 5)
   ; ..the fork: a long limb steep up off the lean, a short one up the other way
   cdir (unit [(top 0 + 0.01) 0.0 (top 2)]) lh [(0.0 - cdir 2) 0.0 (cdir 0)]
   up (branch! fk (unit (c+ (c+ [0.0 2.0 0.0] (c* 1.2 cdir)) (c* 0.8 lh))) (rr 3.2 3.8) 6 0.16 0.07 0.3 0.0)
   _ (head! up 4 (int (rr 10.0 13.99)))
   ot (branch! fk (unit (c+ (c+ [0.0 1.6 0.0] (c* -0.9 cdir)) (c* (rr -0.6 -0.2) lh))) (rr 2.6 3.2) 5 0.15 0.08 0.3 0.0)
   _ (head! ot 3 (int (rr 9.0 12.99)))
   ; ..and long ones sweeping out off both, twigs off them, leaves at every end
   (sweep b) (: o (lerp (b 2) (b 3) (rr 0.0 1.0)) d (unit (c+ (turn (unit (c+ lh (c* 0.3 cdir))) [0.0 1.0 0.0] (rr 0.0 tau)) [0.0 0.5 0.0]))
     sw (branch! o d (rr 2.6 3.8) 7 0.06 0.022 0.35 0.07)
     (each [2 3 3 4 4 5 5 6 6] (i \ (: d2 (unit (c+ (spread (dir (sw (i - 1)) (sw i)) (rr 0.5 1.1)) [0.0 -0.4 0.0]))
                                   tw (branch! (sw i) d2 (rr 0.4 1.0) 2 0.018 0.01 0.4 0.15)
                                   (tuft! (tw 2) (dir (tw 1) (tw 2))))),
      each ^7 (i \ sprig! (sw (i + 1)) (dir (sw i) (sw (i + 1)))),
      tuft! (sw 7) (dir (sw 6) (sw 7))))
   _ (each ^(int (rr 4.0 6.99)) (j \ sweep (j % 2 = 0 ? up ot)))
   fk)
 ; ..near the well's rim, wood kept inside it and leaves not grown outside
 (rim? p) (: m (max2 (max2 (p 0) (0.0 - p 0)) (max2 (p 2) (0.0 - p 2))) (3.8 < p 1 && p 1 < 4.7 && 0.85 < m && m < 1.9))
 (inside p) (rim? p ? [(max2 -0.85 (min2 0.85 (p 0))) (p 1) (max2 -0.85 (min2 0.85 (p 2)))] p)
 (grown seed) (grove-new {'seed seed 'base [0.0 0.0 0.0] 'habit habit 'crown 3.0 'inside inside 'keep? (p \ !(rim? p))})
 (bough-solid seed) (take 5 (grown seed 'segs))
 ; ..the crotch: in a box round the fork the thick wood as one surface, blended where it meets,
 ; sampled on a grid and meshed by surface nets; [the mesh, the box] or () for no wood there
 crotch-b 0.55 crotch-h 0.04 crotch-k 0.12
 (crotch tr tex ts) (: fk (tr 'fork) c [(fk 0) (fk 1 + 0.15) (fk 2)] b crotch-b h crotch-h n (int (2.0 * b / h) + 1)
   o (map (k \ c k - b) ^3) lo o hi (map (k \ c k + b) ^3)
   (near? s) (: r (s 2) (r >= 0.035 && all (k \ min2 (s 0 k) (s 1 k) - r < hi k && max2 (s 0 k) (s 1 k) + r > lo k) ^3))
   ws (filter near? (tr 'segs))
   (? (atom? ws) ()
      (: G (iota (n * n * n)) GX (G // (n * n)) GY (G // n % n) GZ (G % n) X (o 0 + h * GX) Y (o 1 + h * GY) Z (o 2 + h * GZ)
         (cap s) (: a (s 0) bb (s 1) bx (bb 0 - a 0) by (bb 1 - a 1) bz (bb 2 - a 2) l2 (max2 1e-12 (bx * bx + by * by + bz * bz))
           px (X - a 0) py (Y - a 1) pz (Z - a 2) t (max (min ((px * bx + py * by + pz * bz) / l2) 1.0) 0.0)
           dx (px - t * bx) dy (py - t * by) dz (pz - t * bz) (sqrt (dx * dx + dy * dy + dz * dz) - s 2))
         ; ..each limb's pieces joined plainly, so its joints keep its girth, the limbs blended
         k crotch-k L (map (r \ foldl min (cap <r) (map cap >r)) (runs ws))
         F (foldl (\ a d (: e (max (k - max (a - d) (d - a)) 0.0 / k) (min a d - e * e * k * 0.25))) <L >L)
         ; ..a point in each cell the surface crosses, at its crossings' mean, facing the slope
         (ix3 i j l) ((i * n + j) * n + l) m (n - 1)
         C (iota (m * m * m)) CI (C // (m * m)) CJ (C // m % m) CK (C % m) c0 (ix3 CI CJ CK)
         cpos [[0 0 0] [1 0 0] [0 1 0] [1 1 0] [0 0 1] [1 0 1] [0 1 1] [1 1 1]] offs (map (q \ ix3 (q 0) (q 1) (q 2)) cpos)
         ins (foldl (\ a f (a + (peep F (c0 + f) 1.0 < 0.0))) (C * 0) offs)
         act (iota ((ins > 0) * (ins < 8))) na #act ac (peep c0 act 0)
         edges [[0 1] [2 3] [4 5] [6 7] [0 2] [1 3] [4 6] [5 7] [0 4] [1 5] [2 6] [3 7]]
         sums (foldl (\ q e (: a (e 0) d (e 1) fa (peep F (ac + offs a) 0.0) fb (peep F (ac + offs d) 0.0)
                              w ((fa < 0.0) != (fb < 0.0)) t (fa / (fa - fb + 1e-12) * w)
                              [(q 0 + w * (cpos a 0 + t * (cpos d 0 - cpos a 0))) (q 1 + w * (cpos a 1 + t * (cpos d 1 - cpos a 1)))
                               (q 2 + w * (cpos a 2 + t * (cpos d 2 - cpos a 2))) (q 3 + w)]))
                     [(ac * 0.0) (ac * 0.0) (ac * 0.0) (ac * 0.0)] edges)
         VX (o 0 + h * (peep CI act 0 + sums 0 / sums 3)) VY (o 1 + h * (peep CJ act 0 + sums 1 / sums 3)) VZ (o 2 + h * (peep CK act 0 + sums 2 / sums 3))
         (gr f) (peep F (ac + f) 0.0)
         (slope j) (foldl (\ q p (q + (p j = 1 ? 1.0 -1.0) * gr (ix3 (p 0) (p 1) (p 2)))) (ac * 0.0) cpos)
         NX (slope 0) NY (slope 1) NZ (slope 2) NL (sqrt (NX * NX + NY * NY + NZ * NZ) + 1e-12)
         VI (pin ((C * 0) - 1) act (iota na)) (cell i j l) (peep VI ((i * m + j) * m + l) -1)
         ; ..a quad round each grid edge the surface crosses, its four cells' points, turned outward
         (quads ax) (: d (ax @ 0 [1 0 0] 1 [0 1 0] [0 0 1]) e1 (ax @ 0 [0 1 0] 1 [0 0 1] [1 0 0]) e2 (ax @ 0 [0 0 1] 1 [1 0 0] [0 1 0])
           w ((GX >= 1 - d 0) * (GX < n - 1 - d 0) * (GY >= 1 - d 1) * (GY < n - 1 - d 1) * (GZ >= 1 - d 2) * (GZ < n - 1 - d 2))
           g0 (F < 0.0) g1 (peep F (G + ix3 (d 0) (d 1) (d 2)) 1.0 < 0.0) E (iota (w * (g0 != g1)))
           i (peep GX E 0) j (peep GY E 0) l (peep GZ E 0) inn (peep g0 E 0)
           (cc u v) (cell (i - (1 - u) * e1 0 - (1 - v) * e2 0) (j - (1 - u) * e1 1 - (1 - v) * e2 1) (l - (1 - u) * e1 2 - (1 - v) * e2 2))
           qa (cc 0 0) qb (cc 1 0) qc (cc 1 1) qd (cc 0 1)
           (cats (map (q \ (: A (peep qa q -1) B (peep qb q -1) Cc (peep qc q -1) D (peep qd q -1)
                            (A < 0 || B < 0 || Cc < 0 || D < 0 ? () (peep inn q 0 ? [[A B Cc tex] [A Cc D tex]] [[A Cc B tex] [A D Cc tex]]))))
                      ^#E)))
         vs (map (q \ (: x (peep VX q 0.0) y (peep VY q 0.0) z (peep VZ q 0.0) l (peep NL q 1.0)
                       [x y z ((x - c 0 + z - c 2) / ts) (y / ts) (peep NX q 0.0 / l) (peep NY q 0.0 / l) (peep NZ q 0.0 / l) 1.0 1.0 1.0]))
                 ^na)
         [(mesh vs (quads 0 + quads 1 + quads 2)) [lo hi] ws])))
 ; ..a piece of wood less what is inside box q, a grid step short of its walls: the pieces
 ; left, none, one or two
 (outside s q) (: e (1.5 * crotch-h) lo (map (k \ q 0 k + e) ^3) hi (map (k \ q 1 k - e) ^3) a (s 0) b (s 1)
   (clip t0 t1 k) (: d (b k - a k)
     (? (max2 d (0.0 - d) < 1e-12) (lo k <= a k && a k <= hi k ? [t0 t1] [1.0 0.0])
        (: u ((lo k - a k) / d) v ((hi k - a k) / d) [(max2 t0 (min2 u v)) (min2 t1 (max2 u v))])))
   tt (foldl (\ t k (clip (t 0) (t 1) k)) [0.0 1.0] ^3) (at t) (lerp a b t)
   (tt 0 >= tt 1 ? [s] (filter two? [(tt 0 > 0.001 ? [a (at (tt 0)) (s 2)] ()) (tt 1 < 0.999 ? [(at (tt 1)) b (s 2)] ())])))
 ; ..a run of pieces end to end as one tube: a ring at each joint, its radius between the
 ; pieces', turned on from the last ring so it never twists, the texture laid on along the
 ; run; its ends run on a little so it meets what it grows from
 (sweep run tex ts) (: k #run r0 (run 0 2) n (r0 > 0.1 ? 12 (r0 > 0.03 ? 6 (r0 > 0.012 ? 4 3)))
   d0 (unit (c- (run 0 1) (run 0 0))) dl (unit (c- (run (k - 1) 1) (run (k - 1) 0)))
   ps ([(c- (run 0 0) (c* (0.8 * r0) d0))] + map (i \ run i 1) ^(k - 1) + [(c+ (run (k - 1) 1) (c* (0.8 * run (k - 1) 2) dl))])
   rs ([r0] + map (i \ 0.5 * (run i 2 + run (i + 1) 2)) ^(k - 1) + [(run (k - 1) 2)])
   m #ps
   ; ..where each ring faces: along the run there, the way to the next joint from the last
   (way i) (unit (c- (ps (min2 (m - 1) (i + 1))) (ps (max2 0 (i - 1)))))
   frames (foldl (\ fs i (: d (way i) e (two? fs ? (: p <fs (unit (c- p (c* (dot p d) d)))) (side d)) (e . fs))) () ^m)
   es (rev frames)
   ls (foldl (\ a i (a + [(a (i - 1) + sqrt (dot (c- (ps i) (ps (i - 1))) (c- (ps i) (ps (i - 1)))))])) [0.0] (drop 1 ^m))
   (ring i) (: p (ps i) d (way i) e1 (es i) e2 (cross d e1) r (rs i)
     (map (j \ (: an (tau * j / n) o (c+ (c* (cos an) e1) (c* (sin an) e2))
                 (c+ p (c* r o) + [(r0 * an / ts) (ls i / ts)] + o + [1.0 1.0 1.0]))) ^(n + 1)))
   (mesh (cats (map ring ^m))
         (cats (map (i \ cats (map (j \ (: a (i * (n + 1) + j) b (a + n + 1) [[a (a + 1) (b + 1) tex] [a (b + 1) b tex]])) ^n)) ^(m - 1)))))
 ; ..the pieces in runs: each on from the last where it starts at its end
 (runs ss) (rev (map rev (foldl (\ rs s (two? rs && s 0 = <rs 0 1 ? ((s . <rs) . >rs) ([s] . rs))) () ss)))
 ; ..the wood as runs of tube, the crotch's own cut back to its box, all turned to face out;
 ; and one leaflet in five, a little larger, both sides, each facing up so either side
 ; takes the light from above
 (bough-mesh seed tex ts) (: tr (grown seed) cr (crotch tr tex ts)
   (flip m) (mesh (m 0) (map (t \ [(t 0) (t 2) (t 1) (t 3)]) (m 1)))
   ss (atom? cr ? (tr 'segs) (cats (map (s \ elem s (cr 2) ? (outside s (cr 1)) [s]) (tr 'segs))))
   wood (flip (mesh-join ((atom? cr ? () [(cr 0)]) + map (r \ sweep r tex ts) (runs ss))))
   ix (iota ((tr 'kind = 2.0) * (iota #(tr 'kind) % 5 = 0))) n #ix (g q) (peep (tr q) ix 0.0) f 1.7
   P [(g 'x) (g 'y) (g 'z)] A [(f * g 'ax) (f * g 'ay) (f * g 'az)] W [(f * g 'sx) (f * g 'sy) (f * g 'sz)]
   (corner u s) (map (j \ P j + u * A j + s * W j) ^3) C [(corner -0.5 -1.0) (corner -0.5 1.0) (corner 0.5 0.0)]
   (e q j) (C q j - C 0 j) N0 [(e 2 1 * e 1 2 - e 2 2 * e 1 1) (e 2 2 * e 1 0 - e 2 0 * e 1 2) (e 2 0 * e 1 1 - e 2 1 * e 1 0)]
   up ((N0 1 >= 0.0) * 2.0 - 1.0) L (up / (sqrt (N0 0 * N0 0 + N0 1 * N0 1 + N0 2 * N0 2) + 1e-12)) N (map (j \ N0 j * L) ^3)
   sh (g 'shade) col [(0.24 * sh) (0.4 * sh) (0.13 * sh)]
   (vert i q) (: c (C q) (r T) (peep T i 0.0) [(r (c 0)) (r (c 1)) (r (c 2)) 0.0 0.0 (r (N 0)) (r (N 1)) (r (N 2)) (r (col 0)) (r (col 1)) (r (col 2))])
   leaves (mesh (map (t \ vert (t // 3) (t % 3)) ^(3 * n))
                (map (t \ (: o (3 * (t // 2)) (t % 2 = 0 ? [o (o + 1) (o + 2) -1] [o (o + 2) (o + 1) -1]))) ^(2 * n)))
   (mesh-join [wood leaves]))))
