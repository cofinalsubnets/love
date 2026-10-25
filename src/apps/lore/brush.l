; brush -- a world built as the dark engine built one: space starts solid, an air brush (air
; 1) carves it and a solid brush (air 0) fills it again, each a convex solid, the later
; winning. a surface is drawn wherever air meets solid, facing the air, cut fine for the light
; baked into its corners.
; a plane is [n d], holding the points p with dot n p <= d. brush-prism's plan ps is [x z]
; either way round; brush-mirror's axis k is 0 x, 1 y, 2 z. brush-faces answers [ps n i]:
; corners, facing, and the brush index; brush-mesh's (look n b) answers [tex U V], a corner
; p's texels U and V each dotted with [x y z 1]. a brush 'open 1 has no top face, one
; 'sheer 1 no walls, and one 'whole 1 is never cut on the grid. brush-land's is solid under a
; sheet through rows of points, as a drape lies, and has no faces: its sheet is drawn apart.
(module (brush brush brush-box brush-land land-y brush-prism brush-cut brush-cuts brush-move brush-mirror brush-medium brush-ray brush-mesh brush-chunks chunks-kept brush-faces)
(borrow 'view)                          ; min2 max2
(borrow 'vec)                           ; triples
(borrow 'mesh)
(:
 (side pl p) (dot (pl 0) p - pl 1)        ; above 0 outside the plane's brush
 (plane n p) (: u (unit n) [u (dot u p)])
 ; --- polygons: lists of points going round, convex, cut by poly-keep, -carve and -grid ---
 (area ps) (: a <ps (go l s) (atom? >l ? s (go >l (c+ s (cross (c- <l a) (c- <>l a))))) (mag3 (go >ps [0.0 0.0 0.0])))
 (mag3 v) (sqrt (dot v v))
 (mid ps) (c* (1.0 / #ps) (foldl c+ [0.0 0.0 0.0] ps))
 ; --- brushes ---
 (box-of ps) [(foldl (\ a p [(min2 (a 0) (p 0)) (min2 (a 1) (p 1)) (min2 (a 2) (p 2))]) [1e9 1e9 1e9] ps)
              (foldl (\ a p [(max2 (a 0) (p 0)) (max2 (a 1) (p 1)) (max2 (a 2) (p 2))]) [-1e9 -1e9 -1e9] ps)]
 ; ..the point nearest all the planes, a box's middle: the square a face starts as is laid
 ; round it, so a brush far off is as whole as one near
 (anchor pls) (: (row k) (foldl (\ a pl (c+ a (c* (pl 0 k) (pl 0)))) [0.0 0.0 0.0] pls)
   a (row 0) b (row 1) c (row 2) r (foldl (\ s pl (c+ s (c* (pl 1) (pl 0)))) [0.0 0.0 0.0] pls)
   bc (cross b c) dt (dot a bc)
   (abs dt < 1e-9 ? [0.0 0.0 0.0] (c* (1.0 / dt) [(dot r bc) (dot a (cross r c)) (dot a (cross b r))])))
 ; ..a face a plane: a wide square on it, cut by every other plane of the brush
 (face pls i) (: pl (pls i) n (pl 0) m (anchor pls) c (c+ m (c* (pl 1 - dot n m) n))
   a (mag (n 1) < 0.9 ? [0.0 1.0 0.0] [1.0 0.0 0.0]) u (c* 1000.0 (unit (cross n a))) v (cross n u)
   sq [(c+ c (c+ u v)) (c+ c (c+ (c* -1.0 u) v)) (c+ c (c* -1.0 (c+ u v))) (c+ c (c+ u (c* -1.0 v)))]
   (poly-keep sq (map (j \ pls j) (filter (j \ j != i) ^#pls))))
 (brush air pls) (: fs (map (i \ face pls i) ^#pls) ok (filter (f \ #f >= 3 && area f > 1e-9) fs)
   bx (box-of (cats ok))
   {'air air 'planes pls 'faces fs 'lo (bx 0) 'hi (bx 1)})
 (brush-box air lo hi) (brush air [[[-1.0 0.0 0.0] (0.0 - lo 0)] [[1.0 0.0 0.0] (hi 0)] [[0.0 -1.0 0.0] (0.0 - lo 1)]
                                  [[0.0 1.0 0.0] (hi 1)] [[0.0 0.0 -1.0] (0.0 - lo 2)] [[0.0 0.0 1.0] (hi 2)]])
 ; ..each side of the plan a wall, its outside away from the plan's middle
 (brush-prism air y0 y1 ps) (: m (mid (map (p \ [(p 0) 0.0 (p 1)]) ps)) n #ps
   (wall i) (: a (ps i) b (ps ((i + 1) % n)) d [(b 0 - a 0) 0.0 (b 1 - a 1)] nn (unit [(d 2) 0.0 (0.0 - d 0)])
             q [(a 0) 0.0 (a 1)] o (dot nn (c- m q) > 0.0 ? (c* -1.0 nn) nn)
             (plane o q))
   (brush air (map wall ^n + [[[0.0 -1.0 0.0] (0.0 - y0)] [[0.0 1.0 0.0] y1]])))
 ; ..b less what lies across the plane through p q r from b's middle; brush-cuts each of cs's
 ; [p q r] so, every one from the middle of b as it was given
 (centre b) (mid (cats (filter (f \ #f >= 3) (b 'faces))))
 (away m p q r) (: n (unit (cross (c- q p) (c- r p))) (plane (dot n (c- m p) > 0.0 ? (c* -1.0 n) n) p))
 (brush-cut b p q r) (brush (b 'air) (b 'planes + [(away (centre b) p q r)]))
 (brush-cuts b cs) (: m (centre b) (brush (b 'air) (b 'planes + map (c \ away m (c 0) (c 1) (c 2)) cs)))
 (brush-move b d) (brush (b 'air) (map (pl \ [(pl 0) (pl 1 + dot (pl 0) d)]) (b 'planes)))
 (brush-mirror b k c) (: (fl v) (map (i \ i = k ? (0.0 - v i) (v i)) ^3)
   (brush (b 'air) (map (pl \ (: n (pl 0) [(fl n) (pl 1 - 2.0 * c * n k)])) (b 'planes))))
 ; ..land: each four neighbours of the rows two triangles, as a drape's, kept by the cells
 ; land-g wide their plans cross, so a height is found among a few
 land-g 2.0
 (cell x z) ((floor (x / land-g) + 4096) * 8192 + floor (z / land-g) + 4096)
 (brush-land rows) (: R #rows C #<rows (at r c) (rows r c)
   ts (cats (map (r \ cats (map (c \ [[(at r c) (at r (c + 1)) (at (r + 1) (c + 1))] [(at r c) (at (r + 1) (c + 1)) (at (r + 1) c)]]) ^(C - 1))) ^(R - 1)))
   tt (foldl (\ t q (pin t #t q)) {} ts)
   (cells q) (: x0 (floor (min2 (q 0 0) (min2 (q 1 0) (q 2 0)) / land-g)) x1 (floor (max2 (q 0 0) (max2 (q 1 0) (q 2 0)) / land-g))
                z0 (floor (min2 (q 0 2) (min2 (q 1 2) (q 2 2)) / land-g)) z1 (floor (max2 (q 0 2) (max2 (q 1 2) (q 2 2)) / land-g))
                (cats (map (i \ map (j \ (x0 + i + 4096) * 8192 + z0 + j + 4096) ^(z1 - z0 + 1)) ^(x1 - x0 + 1))))
   hs (foldl (\ t i (foldl (\ t k (pin t k (i . peep t k ()))) t (cells (tt i)))) {} ^#ts)
   ps (cats rows) bx (box-of ps)
   {'air 0 'planes () 'faces () 'land {'tris tt 'cells hs} 'lo [(bx 0 0) -1000.0 (bx 0 2)] 'hi (bx 1) 'low (bx 0 1)})
 ; ..the land's height at x z, and its facing there, or () off it
 (land-at L x z) (: tt (L 'tris)
   (on i) (: q (tt i) a (q 0) b (q 1) c (q 2) d ((b 2 - c 2) * (a 0 - c 0) + (c 0 - b 0) * (a 2 - c 2))
     (? (mag d < 1e-12) ()
        (: u (((b 2 - c 2) * (x - c 0) + (c 0 - b 0) * (z - c 2)) / d) v (((c 2 - a 2) * (x - c 0) + (a 0 - c 0) * (z - c 2)) / d) w (1.0 - u - v)
           (u >= -1e-9 && v >= -1e-9 && w >= -1e-9 ? [(u * a 1 + v * b 1 + w * c 1) (unit (cross (c- c a) (c- b a)) @ n (n 1 < 0.0 ? (c* -1.0 n) n))] ()))))
   (go l) (? (atom? l) () (on <l @ () (go >l) h h))
   (go (peep (L 'cells) (cell x z) ())))
 (land-y b x z) (land-at (b 'land) x z @ () () h (h 0))
 ; --- the medium at a place: the last brush holding it says, and solid where none does ---
 (inside? b p) (peep b 'land () @ () (all (pl \ side pl p <= 0.0) (b 'planes)) L (land-at L (p 0) (p 2) @ () 0 h (p 1 <= h 0)))
 (brush-medium bs p) (: (go l) (? (atom? l) 0 (inside? <l p) (<l 'air) (go >l)) (go (rev bs)))
 ; --- a ray from e along v: where it first comes out of the air, {'t 'p 'b 'n} -- how far,
 ;     the point, the brush that ends the air there and the face's facing toward the air --
 ;     or () where it never does ---
 ; ..the stretch t0 to t1 of the ray inside b, the planes it comes in and goes out by; under
 ; land, straight up or down as it is, else found in steps and halved down to a hair
 (span b e v) (peep b 'land () @ () (plane-span b e v) L (land-span L e v))
 (land-span L e v) (: (hy t) (land-at L (e 0 + t * v 0) (e 2 + t * v 2)) (under t) (hy t @ () 0 h (e 1 + t * v 1 <= h 0))
   (? (mag (v 0) + mag (v 2) < 1e-9)
      (hy 0.0 @ () ()
       h (: y (h 0) n (h 1) in (e 1 <= y)
           (? (mag (v 1) < 1e-12) (in ? [-1e9 1e9 () ()] ())
              (v 1 < 0.0) (in ? [-1e9 1e9 () ()] [((e 1 - y) / (0.0 - v 1)) 1e9 n ()])
              (in ? [-1e9 ((y - e 1) / v 1) () n] ()))))
      (: dt (0.5 / sqrt (v 0 * v 0 + v 2 * v 2 + v 1 * v 1)) n (int (80.0 / (dt * sqrt (dot v v))))
         (cross0 a b) (foldl (\ q _ (: m (0.5 * (q 0 + q 1)) (under m = under (q 0) ? [m (q 1)] [(q 0) m]))) [a b] ^20 @ q (q 1))
         (go i) (? (i >= n) () (under (i * dt) != under ((i + 1) * dt) ? (cross0 (i * dt) ((i + 1) * dt)) (go (i + 1))))
         i0 (under 0.0)
         t (go 0)
         (? (t = ()) (i0 ? [-1e9 1e9 () ()] ())
            (: h (hy t) nn (h = () ? [0.0 1.0 0.0] (h 1)) (i0 ? [-1e9 t () nn] [t 1e9 nn ()]))))))
 (plane-span b e v) (: (go l t0 t1 n0 n1)
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
 (fbox f) (: bx (box-of f) {'lo (bx 0) 'hi (bx 1)})
 (on-face? b c n) (any (pl \ mag (mag (dot (pl 0) n) - 1.0) < 1e-6 && mag (side pl c) < 1e-4) (b 'planes)
                   && all (pl \ side pl c <= 1e-4) (b 'planes))
 (brush-faces bs) (faces-kept bs () ())
 ; ..a list as a tablet by place, read in a step
 (tab l) (foldl (\ t x (pin t #t x)) {} l)
 ; ..and with a keeper kp: {'kept (k f) ..} answers what a key k (a list of what it was
 ; made of) was before, else (f ()),
 ; so a face whose brush and the brushes near it are as they were is not worked again
 (keep kp kf f) (? (tablet? kp) ((kp 'kept) (kf ()) f) (f ()))
 ; ..and (kp 'tick), where kp has one, told as the making goes: what it is at and how far
 (ticker kp) (: t (tablet? kp ? (peep kp 'tick ()) ()) (w \ p \ (t @ () () f (f w p))))
 ; ..and a brush marked open has no top: the sky shows there; one sheer no walls
 (shut? b j) (: n (b 'planes j 0 1) ((!(peep b 'open 0) || n < 0.5) && (!(peep b 'sheer 0) || mag n >= 0.5)))
 ; ..only the faces want holds [i j] of, where it is a tablet
 (faces-kept bs kp want) (: nb #bs bt (tab bs) tick (ticker kp)
   ; ..the brushes near a box, all weighed at once: each axis's ends as a tray
   (ends f k) (gem-tray [nb] (map (b \ 1.0 * b f k) bs)) L (map (ends 'lo) ^3) H (map (ends 'hi) ^3)
   (near fb) (: lo (fb 'lo) hi (fb 'hi)
     (on k) ((H k >= lo k - 0.01) * (L k - 0.01 <= hi k)) I (iota (on 0 * on 1 * on 2))
     (map (j \ peep I j 0) ^#I))
   ; ..and the medium there, of only those: a brush holding a place a hair off the face is
   ; near it
   (medium ks p) (: (go l) (? (atom? l) 0 (inside? (bt <l) p) (bt <l 'air) (go >l)) (go (rev ks)))
   ; ..a brush as a key says it, its planes all a face's pieces hang on, by number
   ft (tablet? kp ? (tab (map (b \ (kp 'id) [(b 'planes) (b 'air) (peep b 'open 0) (peep b 'sheer 0)]) bs)) ())
   ; ..of a brush, the planes whose faces reach plane pl: only those draw a line on it
   (meets c pl) (cats (map (k \ (: g (c 'faces k) s (map (side pl) g)
                                  (#g >= 3 && foldl min2 1e9 s <= 1e-6 && foldl max2 -1e9 s >= -1e-6 ? [(c 'planes k)] ())))
                           ^#(c 'planes)))
   (piece i b j) (: f (b 'faces j) n (b 'planes j 0) fb (fbox f) ks (near fb)
     (rel k) (? (k < i) -1 (k > i) 1 0)
     (key _) ['face j (ft i) (map (k \ [(rel k) (ft k)]) ks)]
     ky (tablet? kp ? (key ()) ()) fi (tablet? kp ? ((kp 'id) ky) ())
     qs (keep kp (_ \ ky) (_ \ (: later (filter (k \ i < k) ks)
                            others (filter (k \ k != i) ks)
                            pls (cats (map (k \ meets (bt k) (b 'planes j)) others))
                            ps (poly-carve f pls)
                            (cats (map (p \ (: c (mid p) fr (medium ks (c+ c (c* 1e-3 n))) bk (medium ks (c+ c (c* -1e-3 n)))
                                             (fr = bk || any (k \ on-face? (bt k) c n) later ? () [[p (fr = 1 ? n (c* -1.0 n))]])))
                                       ps)))))
     (map (m \ (: q (qs m) (tablet? kp ? [(q 0) (q 1) i [fi m] j] [(q 0) (q 1) i]))) ^#qs))
   (ok? i j) (!(tablet? want) || peep want [i j] 0 > 0)
   (cats (map (i \ (: b (bt i) _ (tick 'faces (i / nb)) (cats (map (j \ (#(b 'faces j) >= 3 && shut? b j && ok? i j ? (piece i b j) ())) ^#(b 'planes))))) ^nb)))
 ; ..or cut coarse and each piece again at half while (split? ps c) says it is too coarse,
 ; down to fine: every size a power of two of fine, so the lines are the fine grid's
 (grids ps c fine split?) (c <= fine ? (poly-grid ps fine)
   (cats (map (p \ (split? p c ? (grids p (0.5 * c) fine split?) [p])) (poly-grid ps c))))
 ; ..a mesh packed (mesh-pack's), and a mesh's or a pack's part, as poly-weave joins them
 (weave ps) (: w (poly-weave ps) {'n (w 0) 'cols (w 1) 'tris (w 2)})
 (part m) [(gem-tray [(11 * #(m 0))] (map (x \ 1.0 * x) (cats (m 0)))) (star-tray [(4 * #(m 1))] (cats (m 1)))]
 (pack-part pk) [(lace (pk 'cols)) (pk 'tris)]
 ; ..cell a number, or [coarse fine on]: (on face) the split? for that face's pieces; packed
 (brush-mesh bs cell look) (weave (map pack-part (brush-chunks bs cell look 1e9 ())))
 ; ..and packed a chunk each, the pieces k metres square in plan, and with them more
 ; meshes, each [p mesh], in the chunk p is in
 (brush-chunks bs cell look k more) (map (c \ (c 1) ()) (chunks-kept bs cell look k (map (m \ [(m 0) (m 1) ()]) more) ()))
 ; ..each [key (_ \ pack)], more's each [p mesh key], kept by kp as faces-kept keeps: what a face
 ; is cut to by its corners, its brush's whole and (kp 'reach face) the light on it; its
 ; triangles by that, its facing, (kp 'look b) and the cuts of the faces beside it, whose
 ; corners its edges take; a chunk's key its faces' triangles', its pack made on asking. (kp
 ; 'id k) a number for key k, the same while it is kept
 (chunks-kept bs cell look k more kp)
  (: bt (tab bs) nb #bs prev (tablet? kp ? (kp 'prev) ()) tick (ticker kp)
     (col m) [(int (floor (m 0 / k))) (int (floor (m 2 / k)))] (ck m) (show (col m))
     ; ..the faces as their brushes give them, and their boxes as trays
     rf (cats (map (i \ (: b (bt i) (cats (map (j \ (#(b 'faces j) >= 3 && shut? b j ? [[i j (box-of (b 'faces j))]] ())) ^#(b 'planes))))) ^nb))
     nr #rf RT (tab rf) (rends s a) (gem-tray [nr] (map (r \ 1.0 * r 2 s a) rf)) RL (map (rends 0) ^3) RH (map (rends 1) ^3)
     ; ..those whose box comes within s of box x, as a mask
     (near-box x s) (: (on a) ((RH a >= x 0 a - s) * (RL a - s <= x 1 a)) (on 0 * on 1 * on 2))
     (any-of m bxs s) (foldl (\ m x (max m (near-box x s))) m bxs) none (RL 0 * 0.0)
     (marked m) (: I (iota (m > 0.5)) (map (j \ peep I j 0) ^#I))
     ; ..what an edit touched, where the scene before is known: the brushes not as they were,
     ; and the lamps not, (kp 'hot) each [p r]; the faces their pieces and cuts hang on, those
     ; beside them, and the chunks any of those are in, or more's are not as they were
     BI (tablet? kp ? (tab (map (i \ (tick 'edits (i / nb), (kp 'bkey) (bt i))) ^nb)) ())
     bst (tablet? kp ? (map (i \ [(BI i) (bt i 'lo) (bt i 'hi)]) ^nb) ())
     ids (foldl (\ t q (pin t (q 0) 1)) {} bst) oids (foldl (\ t q (pin t (q 0) 1)) {} (peep prev 'b ()))
     cb (map (q \ [(q 1) (q 2)]) (filter (q \ peep oids (q 0) 0 = 0) bst + filter (q \ peep ids (q 0) 0 = 0) (peep prev 'b ())))
     (hot-mask h) (: lo (map (a \ h 0 a - h 1) ^3) hi (map (a \ h 0 a + h 1) ^3) (near-box [lo hi] 0.0))
     cdm (foldl (\ m h (max m (hot-mask h))) (any-of none cb 0.02) (tablet? kp ? (kp 'hot) ()))
     cdi (marked cdm) fdm (any-of cdm (map (j \ RT j 2) cdi) 1e-3) fdi (marked fdm)
     (cols x) (: a (col (x 0)) b (col (x 1)) (cats (map (u \ map (v \ show [(a 0 + u) (a 1 + v)]) ^(b 1 - a 1 + 1)) ^(b 0 - a 0 + 1))))
     mby (foldl (\ t m (: q (ck (m 0)) (pin t q ((m 2) . peep t q ())))) {} more)
     om (peep prev 'more {})
     dq (foldl (\ t q (pin t q 1)) {} (cats (map (j \ cols (RT j 2)) fdi) + cats (map cols cb)
                                          + filter (q \ peep mby q () != peep om q ()) (keys mby + keys om)))
     ; ..the faces in a touched chunk, for their triangles, and those beside them, for their corners
     ai (filter (j \ any (q \ peep dq q 0) (cols (RT j 2))) ^nr)
     bi (marked (any-of none (map (j \ RT j 2) ai) 1e-3))
     want (tablet? prev ? (foldl (\ t j (pin t [(RT j 0) (RT j 1)] 1)) (foldl (\ t j (pin t [(RT j 0) (RT j 1)] 2)) {} bi) ai) ())
     fs (faces-kept bs kp want) nf #fs FT (tab fs)
     (mine? f) (!(tablet? want) || peep want [(f 2) (f 4)] 0 = 1)
     (fresh? q) (!(tablet? prev) || peep dq q 0)
     ; ..a brush marked whole goes uncut
     (cut ps b) (? (peep b 'whole 0) [ps] (charm? cell || gem? cell) (poly-grid ps cell) (grids ps (cell 0) (cell 1) (cell 2 ps)))
     cks (tablet? kp ? (tab (map (f \ ['cut (f 3) (peep (bt (f 2)) 'whole 0) ((kp 'reach) (f 0))]) fs)) ())
     CI (tablet? kp ? (tab (map (i \ (kp 'id) (cks i)) ^nf)) ())
     LI (tablet? kp ? (tab (map (b \ (kp 'id) ((kp 'look) b)) bs)) ())
     pcf (map (i \ (: f (FT i) _ (tick 'cuts (i / nf)) (map (p \ [p (f 1) (f 2)]) (keep kp (_ \ cks i) (_ \ cut (f 0) (bt (f 2))))))) ^nf) PT (tab pcf)
     pcs (cats pcf)
     ; ..every corner, so a piece takes on its edges the corners of the pieces beside it,
     ; and no crack opens between them; a face's pieces fanned so, turned to face it
     seen (poly-seen (map (pc \ pc 0) pcs))
     ; ..the faces beside each, all weighed at once as the brushes near a face are
     (fends s k) (gem-tray [nf] (map (q \ 1.0 * box-of (q 0) s k) fs))
     FL (tablet? kp ? (map (fends 0) ^3) ()) FH (tablet? kp ? (map (fends 1) ^3) ())
     ; ..weighed among the faces of the brushes near each's own, as those are found
     nb #bs (bends f k) (gem-tray [nb] (map (b \ 1.0 * b f k) bs)) BL (tablet? kp ? (map (bends 'lo) ^3) ()) BH (tablet? kp ? (map (bends 'hi) ^3) ())
     BF (foldl (\ t i (: b (FT i 2) (pin t b (i . peep t b ())))) {} (rev ^nf))
     (among b) (: _ (tick 'sides (b / nb)) lo (bt b 'lo) hi (bt b 'hi) (on k) ((BH k >= lo k - 0.02) * (BL k - 0.02 <= hi k)) I (iota (on 0 * on 1 * on 2))
       cs (cats (map (j \ peep BF (peep I j 0) ()) ^#I)) T (floor (gem-tray [#cs] (map (c \ 1.0 * c) cs)))
       [(tab cs) (map (k \ peep (FL k) T 0.0) ^3) (map (k \ peep (FH k) T 0.0) ^3)])
     AM (tablet? kp ? (tab (map among ^nb)) ())
     (beside i) (: a (AM (FT i 2)) bx (box-of (FT i 0)) (on k) ((a 2 k >= bx 0 k - 1e-3) * (a 1 k - 1e-3 <= bx 1 k))
       I (iota (on 0 * on 1 * on 2)) (map (j \ CI (a 0 (peep I j 0))) ^#I))
     fks (tablet? kp ? (tab (map (i \ (: f (FT i) _ (tick 'sides (i / nf)) ['fan (CI i) (beside i) (LI (f 2))])) ^nf)) ())
     fid (tablet? kp ? (tab (map (i \ (kp 'id) (fks i)) ^nf)) ())
     items (cats (map (i \ (? (tick 'fans (i / nf), !(mine? (FT i))) ()
                              (: ms (keep kp (_ \ fks i) (_ \ (: f (FT i) (poly-fans (map (pc \ pc 0) (PT i)) (f 1) (look (f 1) (bt (f 2))) seen))))
                                 id (tablet? kp ? (fid i) ())
                                 (map (m \ [(m 0) (m 1) id]) ms))))
                      ^nf))
     by (foldl (\ t pc (: _ (tick 'chunks ()) q (ck (pc 0)) (fresh? q ? (pin t q (pc . peep t q ())) t))) {} (items + map (m \ [(m 0) (part (m 1)) (m 2)]) more))
     made (map (q \ (: its (rev (by q)) ky [q (map (x \ x 2) its)]
                       [q ky (_ \ weave (map (x \ x 1) its))]))
               (keys by))
     ; ..and the chunks no edit touched, as they were
     oc (peep prev 'chunks {}) kept (map (q \ [q (oc q) (_ \ ())]) (filter (q \ !(fresh? q)) (keys oc)))
     all (sort (made + kept))
     _ (tablet? kp ? ((kp 'stash) {'b bst 'chunks (foldl (\ t c (pin t (c 0) (c 1))) {} all) 'more mby}))
     (map (c \ [(c 1) (c 2)]) all)))
) ; module brush
