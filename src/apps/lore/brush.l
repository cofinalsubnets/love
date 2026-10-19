; brush -- a world built as the dark engine built one: space starts solid, an air brush (air
; 1) carves it and a solid brush (air 0) fills it again, each a convex solid, the later
; winning. a surface is drawn wherever air meets solid, facing the air, cut fine for the light
; baked into its corners.
; a plane is [n d], holding the points p with dot n p <= d. brush-prism's plan ps is [x z]
; either way round; brush-mirror's axis k is 0 x, 1 y, 2 z. brush-faces answers [ps n i]:
; corners, facing, and the brush index; brush-mesh's (look n b) answers (p \ [tex u v]). a brush
; 'open 1 has no top face, and one 'whole 1 is never cut on the grid.
(module (brush brush brush-box brush-prism brush-cut brush-cuts brush-move brush-mirror brush-medium brush-ray brush-mesh brush-chunks brush-faces)
(borrow 'view)                          ; min2 max2
(borrow 'vec)                           ; triples
(borrow 'mesh)
(:
 eps 1e-6
 (sub a b) [(a 0 - b 0) (a 1 - b 1) (a 2 - b 2)]
 (side pl p) (dot (pl 0) p - pl 1)        ; above 0 outside the plane's brush
 (plane n p) (: u (unit n) [u (dot u p)])
 ; --- polygons: lists of points going round, convex ---
 (cut-at a b sa sb) (: t (sa / (sa - sb)) (c+ a (c* t (sub b a))))
 ; ..the part on the plane's inside, and the part beyond it
 (split ps pl) (: n #ps
   (go i ins outs) (? (i = n) [(rev ins) (rev outs)]
     (: a (ps i) b (ps ((i + 1) % n)) sa (side pl a) sb (side pl b)
        ins2 (sa <= eps ? (a . ins) ins) outs2 (sa >= 0.0 - eps ? (a . outs) outs)
        (? ((sa < 0.0 - eps && sb > eps) || (sa > eps && sb < 0.0 - eps))
           (: x (cut-at a b sa sb) (go (i + 1) (x . ins2) (x . outs2)))
           (go (i + 1) ins2 outs2))))
   (go 0 () ()))
 (keep ps pl) (split ps pl 0)
 ; ..whether the plane passes through it, a point clear either side
 (crosses? ps pl) (any (p \ side pl p > 1e-5) ps && any (p \ side pl p < -1e-5) ps)
 (area ps) (: a <ps (go l s) (atom? >l ? s (go >l (c+ s (cross (sub <l a) (sub <>l a))))) (mag3 (go >ps [0.0 0.0 0.0])))
 (mag3 v) (sqrt (dot v v))
 (mid ps) (c* (1.0 / #ps) (foldl c+ [0.0 0.0 0.0] ps))
 ; --- brushes ---
 (box-of ps) [(foldl (\ a p [(min2 (a 0) (p 0)) (min2 (a 1) (p 1)) (min2 (a 2) (p 2))]) [1e9 1e9 1e9] ps)
              (foldl (\ a p [(max2 (a 0) (p 0)) (max2 (a 1) (p 1)) (max2 (a 2) (p 2))]) [-1e9 -1e9 -1e9] ps)]
 ; ..a face a plane: a wide square on it, cut by every other plane of the brush
 (face pls i) (: pl (pls i) n (pl 0) c (c* (pl 1) n)
   a (mag (n 1) < 0.9 ? [0.0 1.0 0.0] [1.0 0.0 0.0]) u (c* 1000.0 (unit (cross n a))) v (cross n u)
   sq [(c+ c (c+ u v)) (c+ c (c+ (c* -1.0 u) v)) (c+ c (c* -1.0 (c+ u v))) (c+ c (c+ u (c* -1.0 v)))]
   (foldl (\ ps j (j = i || #ps < 3 ? ps (keep ps (pls j)))) sq ^#pls))
 (brush air pls) (: fs (map (i \ face pls i) ^#pls) ok (filter (f \ #f >= 3 && area f > 1e-9) fs)
   bx (box-of (cats ok))
   {'air air 'planes pls 'faces fs 'lo (bx 0) 'hi (bx 1)})
 (brush-box air lo hi) (brush air [[[-1.0 0.0 0.0] (0.0 - lo 0)] [[1.0 0.0 0.0] (hi 0)] [[0.0 -1.0 0.0] (0.0 - lo 1)]
                                  [[0.0 1.0 0.0] (hi 1)] [[0.0 0.0 -1.0] (0.0 - lo 2)] [[0.0 0.0 1.0] (hi 2)]])
 ; ..each side of the plan a wall, its outside away from the plan's middle
 (brush-prism air y0 y1 ps) (: m (mid (map (p \ [(p 0) 0.0 (p 1)]) ps)) n #ps
   (wall i) (: a (ps i) b (ps ((i + 1) % n)) d [(b 0 - a 0) 0.0 (b 1 - a 1)] nn (unit [(d 2) 0.0 (0.0 - d 0)])
             q [(a 0) 0.0 (a 1)] o (dot nn (sub m q) > 0.0 ? (c* -1.0 nn) nn)
             (plane o q))
   (brush air (map wall ^n + [[[0.0 -1.0 0.0] (0.0 - y0)] [[0.0 1.0 0.0] y1]])))
 ; ..b less what lies across the plane through p q r from b's middle; brush-cuts each of cs's
 ; [p q r] so, every one from the middle of b as it was given
 (centre b) (mid (cats (filter (f \ #f >= 3) (b 'faces))))
 (away m p q r) (: n (unit (cross (sub q p) (sub r p))) (plane (dot n (sub m p) > 0.0 ? (c* -1.0 n) n) p))
 (brush-cut b p q r) (brush (b 'air) (b 'planes + [(away (centre b) p q r)]))
 (brush-cuts b cs) (: m (centre b) (brush (b 'air) (b 'planes + map (c \ away m (c 0) (c 1) (c 2)) cs)))
 (brush-move b d) (brush (b 'air) (map (pl \ [(pl 0) (pl 1 + dot (pl 0) d)]) (b 'planes)))
 (brush-mirror b k c) (: (fl v) (map (i \ i = k ? (0.0 - v i) (v i)) ^3)
   (brush (b 'air) (map (pl \ (: n (pl 0) [(fl n) (pl 1 - 2.0 * c * n k)])) (b 'planes))))
 ; --- the medium at a place: the last brush holding it says, and solid where none does ---
 (inside? b p) (all (pl \ side pl p <= 0.0) (b 'planes))
 (brush-medium bs p) (: (go l) (? (atom? l) 0 (inside? <l p) (<l 'air) (go >l)) (go (rev bs)))
 ; --- a ray from e along v: where it first comes out of the air, {'t 'p 'b 'n} -- how far,
 ;     the point, the brush that ends the air there and the face's facing toward the air --
 ;     or () where it never does ---
 ; ..the stretch t0 to t1 of the ray inside b, the planes it comes in and goes out by
 (span b e v) (: (go l t0 t1 n0 n1)
   (? (t1 < t0) ()
      (atom? l) [t0 t1 n0 n1]
      (: pl <l n (pl 0) a (pl 1 - dot n e) k (dot n v) t (a / (mag k < 1e-12 ? 1.0 k))
         (? (mag k < 1e-12) (a < 0.0 ? () (go >l t0 t1 n0 n1))
            (k > 0.0) (t < t1 ? (go >l t0 t n0 n) (go >l t0 t1 n0 n1))
            (t > t0 ? (go >l t t1 n n1) (go >l t0 t1 n0 n1)))))
   (go (b 'planes) -1e9 1e9 () ()))
 (brush-ray bs e v) (: ivs (filter two? (map (i \ (span (bs i) e v @ () () s (s 1 > 0.001 ? (i . s) ()))) ^#bs))
   (at t) (foldl (\ a q (q 1 <= t && t < q 2 ? q a)) () ivs)
   (med t) (at t @ () 0 q (bs (q 0) 'air))
   (go l) (? (atom? l) ()
             (med (<l + 1e-4) != 0) (go >l)
             (: t <l q (at (t + 1e-4)) a (at (t - 1e-4)) p (c+ e (c* t v))
                (? (two? q && two? (q 3)) {'t t 'p p 'b (q 0) 'n (q 3)}
                   (two? a && two? (a 4)) {'t t 'p p 'b (a 0) 'n (c* -1.0 (a 4))}
                   ())))
   (go (sort (filter (t \ t > 0.001) (cats (map (q \ [(q 1) (q 2)]) ivs))))))
 ; --- the surfaces: each face cut by the planes of the brushes it meets, a piece kept where
 ;     air meets solid and no later brush has a face on it, turned to the air; then cut on a
 ;     grid a cell wide, the same lines in every face so the edges meet ---
 (near? a b) (all (k \ a 'lo k - 0.01 <= b 'hi k && b 'lo k - 0.01 <= a 'hi k) ^3)
 (fbox f) (: bx (box-of f) {'lo (bx 0) 'hi (bx 1)})
 (on-face? b c n) (any (pl \ mag (mag (dot (pl 0) n) - 1.0) < 1e-6 && mag (side pl c) < 1e-4) (b 'planes)
                   && all (pl \ side pl c <= 1e-4) (b 'planes))
 (brush-faces bs) (: nb #bs
   (piece i b j) (: f (b 'faces j) n (b 'planes j 0) fb (fbox f)
     later (filter (k \ i < k && near? fb (bs k)) ^nb)
     others (filter (k \ k != i && near? fb (bs k)) ^nb)
     pls (cats (map (k \ bs k 'planes) others))
     ps (foldl (\ l pl (cats (map (p \ (crosses? p pl ? (filter (q \ #q >= 3 && area q > 1e-8) (split p pl)) [p])) l))) [f] pls)
     (cats (map (p \ (: c (mid p) fr (brush-medium bs (c+ c (c* 1e-3 n))) bk (brush-medium bs (c+ c (c* -1e-3 n)))
                      (fr = bk || any (k \ on-face? (bs k) c n) later ? () [[p (fr = 1 ? n (c* -1.0 n)) i]])))
                ps)))
   ; ..and a brush marked open has no top: the sky shows there
   (shut? b j) (!(peep b 'open 0) || b 'planes j 0 1 < 0.5)
   (cats (map (i \ (: b (bs i) (cats (map (j \ (#(b 'faces j) >= 3 && shut? b j ? (piece i b j) ())) ^#(b 'planes))))) ^nb)))
 ; ..each axis in turn, a strip cut off what is left at each line that crosses it
 (slab ps k cell) (: bx (box-of ps) lo (bx 0 k) hi (bx 1 k) n (map (m \ m = k ? 1.0 0.0) ^3)
   m0 (int (floor ((lo + 1e-5) / cell)) + 1) m1 (int (floor ((hi - 1e-5) / cell)))
   (ok q) (#q >= 3 && area q > 1e-8)
   (go p m acc) (? (m > m1 || cell * m >= hi - 1e-5) (ok p ? (p . acc) acc)
     (: s (split p [n (cell * m)]) (go (s 1) (m + 1) (ok (s 0) ? (s 0 . acc) acc))))
   (go ps m0 ()))
 (grid ps cell) (foldl (\ l k (cats (map (p \ slab p k cell) l))) [ps] ^3)
 ; ..or cut coarse and each piece again at half while (split? ps c) says it is too coarse,
 ; down to fine: every size a power of two of fine, so the lines are the fine grid's
 (grids ps c fine split?) (c <= fine ? (grid ps fine)
   (cats (map (p \ (split? p c ? (grids p (0.5 * c) fine split?) [p])) (grid ps c))))
 ; ..cell a number, or [coarse fine on]: (on face) the split? for that face's pieces
 (brush-mesh bs cell look) (mesh-join (brush-chunks bs cell look 1e9 ()))
 ; ..and in meshes a chunk each, the pieces k metres square in plan, and with them more
 ; meshes, each [p mesh], in the chunk p is in
 (brush-chunks bs cell look k more)
  (: fs (brush-faces bs)
     ; ..a brush marked whole goes uncut
     (cut ps b) (? (peep b 'whole 0) [ps] (charm? cell || gem? cell) (grid ps cell) (grids ps (cell 0) (cell 1) (cell 2 ps)))
     fine (charm? cell || gem? cell ? cell (cell 1))
     pcs (cats (map (f \ map (p \ [p (f 1) (f 2)]) (cut (f 0) (bs (f 2)))) fs))
     ; ..every corner, a millimetre a step, so a piece takes on its edges the corners of the
     ; finer pieces beside it, and no crack opens between them
     (key p) (: (r v) (int (floor (v * 1000.0 + 0.5))) ((r (p 0) * 4194304 + r (p 1)) * 4194304 + r (p 2)))
     seen (foldl (\ t pc (foldl (\ t p (pin t (key p) 1)) t (pc 0))) {} pcs)
     (on a b) (: d (sub b a)
       ts (cats (map (k \ (: lo (min2 (a k) (b k)) hi (max2 (a k) (b k))
                        (hi - lo < 1e-6 ? ()
                           (: m0 (int (floor (lo / fine)) + 1) m1 (int (floor ((hi - 1e-6) / fine)))
                              (map (m \ (fine * m - a k) / d k) (map (+ m0) ^(max2 0 (m1 - m0 + 1))))))))
                     ^3))
       hit (filter (t \ 1e-6 < t && t < 1.0 - 1e-6 && peep seen (key (c+ a (c* t d))) 0) ts)
       (map (t \ c+ a (c* t d)) (foldl (\ l t (any (u \ mag (u - t) < 1e-6) l ? l (l + [t]))) () (sort hit))))
     ; ..none within a piece a cell across, whose edges cross no line of the grid
     (edged ps) (: n #ps bx (box-of ps)
       (any (k \ bx 1 k - bx 0 k > fine + 1e-6) ^3 ? (cats (map (i \ (: a (ps i) b (ps ((i + 1) % n)) (a . on a b))) ^n)) ps))
     ; ..a piece of brush b's fanned from its first corner, or from its middle when its edges
     ; took on corners, turned to face n
     (vert lk n p) (lk p @ t [(p 0) (p 1) (p 2) (t 1) (t 2) (n 0) (n 1) (n 2) 1.0 1.0 1.0])
     (fan ps0 n b) (: ps (edged ps0) lk (look n b) tex (lk (mid ps0) 0)
       (one a b c) (dot (cross (sub (ps c) (ps a)) (sub (ps b) (ps a))) n > 0.0 ? [a b c tex] [a c b tex])
       (#ps = #ps0
        ? (mesh (map (vert lk n) ps) (map (i \ one 0 (i + 1) (i + 2)) ^(#ps - 2)))
          (: m #ps ps2 (ps + [(mid ps0)])
             (two a b) (dot (cross (sub (ps2 b) (ps2 m)) (sub (ps2 a) (ps2 m))) n > 0.0 ? [m a b tex] [m b a tex])
             (mesh (map (vert lk n) ps2) (map (i \ two i ((i + 1) % m)) ^m)))))
     (ck m) (show [(int (floor (m 0 / k))) (int (floor (m 2 / k)))])
     by (foldl (\ t pc (: q (ck (pc 0)) (pin t q (pc 1 . peep t q ())))) {}
               (map (pc \ [(mid (pc 0)) (fan (pc 0) (pc 1) (bs (pc 2)))]) pcs + more))
     (map (q \ mesh-join (rev (by q))) (sort (keys by)))))
) ; module brush
