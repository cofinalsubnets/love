; brush -- a world built as the dark engine built one: space starts solid, an air brush
; carves it open and a solid brush fills it again, each brush a convex solid and the later
; winning where they overlap. a surface is drawn wherever air meets solid, facing the air,
; cut fine for the light that is baked into its corners.
;
;   (brush air planes)             a brush from its planes, each [n d] -- the points p it
;                                  holds have dot n p <= d -- air 1 or solid 0
;   (brush-box air lo hi)          ..a box between corners lo and hi
;   (brush-prism air y0 y1 ps)     ..an upright prism, its floor plan ps [x z] going round
;                                  either way, its sides convex
;   (brush-cut b p q r)            b less what lies across the plane through p q r from
;                                  its middle
;   (brush-move b d) (brush-mirror b k c)  b moved by d; b reflected in the plane where
;                                  axis k (0 x, 1 y, 2 z) is c
;   (brush-medium bs p)            1 where p is air among the brushes bs, else 0
;   (brush-faces bs)               the surfaces, each [ps n i]: its corners, the way it
;                                  faces, and the brush it is a face of
;   (brush-mesh bs cell look)      the surfaces, as a mesh; (look n p b) the texture and
;                                  its texels [tex u v] at a place p of a surface facing n,
;                                  a face of brush b
(module (brush brush brush-box brush-prism brush-cut brush-move brush-mirror brush-medium brush-mesh brush-faces)
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
 (brush-cut b p q r) (: n (unit (cross (sub q p) (sub r p))) m (mid (cats (filter (f \ #f >= 3) (b 'faces))))
   o (dot n (sub m p) > 0.0 ? (c* -1.0 n) n)
   (brush (b 'air) (b 'planes + [(plane o p)])))
 (brush-move b d) (brush (b 'air) (map (pl \ [(pl 0) (pl 1 + dot (pl 0) d)]) (b 'planes)))
 (brush-mirror b k c) (: (fl v) (map (i \ i = k ? (0.0 - v i) (v i)) ^3)
   (brush (b 'air) (map (pl \ (: n (pl 0) [(fl n) (pl 1 - 2.0 * c * n k)])) (b 'planes))))
 ; --- the medium at a place: the last brush holding it says, and solid where none does ---
 (inside? b p) (all (pl \ side pl p <= 0.0) (b 'planes))
 (brush-medium bs p) (: (go l) (? (atom? l) 0 (inside? <l p) (<l 'air) (go >l)) (go (rev bs)))
 ; --- the surfaces: each face cut by the planes of the brushes it meets, each piece kept
 ;     where air is on one side and solid on the other and no later brush has a face on
 ;     it, turned to the air; then cut on a grid cell wide, so the light's corners are near
 ;     enough together, the same lines in every face so their edges meet ---
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
   (cats (map (i \ (: b (bs i) (cats (map (j \ (#(b 'faces j) >= 3 ? (piece i b j) ())) ^#(b 'planes))))) ^nb)))
 (grid ps cell) (: bx (box-of ps)
   (lines k) (: a (int (bx 0 k / cell) - 1) z (int (bx 1 k / cell) + 1)
     (map (i \ [(map (m \ m = k ? 1.0 0.0) ^3) (cell * (a + i))]) ^(z - a + 1)))
   pls (cats (map lines ^3))
   (foldl (\ l pl (cats (map (p \ (crosses? p pl ? (filter (q \ #q >= 3 && area q > 1e-8) (split p pl)) [p])) l))) [ps] pls))
 (brush-mesh bs cell look)
  (: fs (brush-faces bs)
     ; ..a piece of brush b's fanned from its first corner, turned to face n
     (fan ps n b) (: k (look n (mid ps) b) tex (k 0)
       vs (map (p \ (look n p b @ t [(p 0) (p 1) (p 2) (t 1) (t 2) (n 0) (n 1) (n 2) 1.0 1.0 1.0])) ps)
       (one a b c) (dot (cross (sub (ps c) (ps a)) (sub (ps b) (ps a))) n > 0.0 ? [a b c tex] [a c b tex])
       (mesh vs (map (i \ one 0 (i + 1) (i + 2)) ^(#ps - 2))))
     (mesh-join (cats (map (f \ map (p \ fan p (f 1) (bs (f 2))) (grid (f 0) cell)) fs)))))
) ; module brush
