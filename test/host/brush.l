; test/host/brush.l -- src/apps/lore/brush.l: the medium a place is in among air and solid
; brushes, the later winning; a box's faces, a prism's, a cut's slope; a brush moved and
; mirrored; the surfaces where air meets solid, turned to the air, none where a solid
; stands against a wall nor where two airs meet, none twice where two brushes share a
; plane; and the pieces cut fine on one grid, so their corners meet.
; not in the corpus: a crew module. run: cat test/00-init.l test/host/brush.l | out/love
(borrow 'brush)
(borrow 'vec)

(: room (brush-box 1 [0.0 0.0 0.0] [4.0 3.0 4.0])
   ; a pilaster against the west wall, and over it a buttress, its underside sloping out
   col (brush-box 0 [0.0 0.0 1.5] [0.3 3.0 2.0])
   but (brush-cut (brush-box 0 [0.0 2.0 1.5] [0.8 3.0 2.0]) [0.3 2.0 0.0] [0.8 3.0 0.0] [0.8 3.0 1.0])
   bs [room col but]
   (m p) (brush-medium bs p)
   (area ps) (: a <ps (go l s) (atom? >l ? s (go >l (c+ s (cross (c+ <l (c* -1.0 a)) (c+ <>l (c* -1.0 a)))))) (: v (go >ps [0.0 0.0 0.0]) (0.5 * sqrt (dot v v))))
   (total fs) (foldl (\ a f (a + area (f 0))) 0.0 fs)
   ; ..faces: the room alone, its six inside; with a second room through a wall
   alone (brush-faces [room])
   prism (brush-prism 0 0.0 2.0 [[0.0 0.0] [2.0 0.0] [1.0 2.0]])
   moved (brush-move col [1.0 0.0 0.0]) flip (brush-mirror col 0 2.0)
   ; ..two rooms a wall apart, a doorway through it: the doorway's sides drawn, no face
   ; across the doorway itself
   r2 (brush-box 1 [0.0 0.0 4.2] [4.0 3.0 8.0]) dw (brush-box 1 [1.5 0.0 3.98] [2.5 2.0 4.22])
   two (brush-faces [room r2 dw])
   (across? f) (: c (c* (1.0 / #(f 0)) (foldl c+ [0.0 0.0 0.0] (f 0)))
                  (1.5 < c 0 < 2.5 && c 1 < 2.0 && 3.99 < c 2 < 4.21 && mag (f 1 2) > 0.9))
   ; ..a box of air half filled by a solid sharing three of its sides: five faces of the
   ; air's and the solid's top, none twice
   a1 (brush-box 1 [0.0 0.0 0.0] [1.0 1.0 1.0]) s1 (brush-box 0 [0.0 0.0 0.0] [1.0 1.0 0.5])
   mesh0 (brush-mesh [room] 1.0 (\ n p b [-1 0.0 0.0]))
 (test (m [2.0 1.0 2.0] = 1) (m [5.0 1.0 2.0] = 0) (m [0.1 1.0 1.7] = 0) (m [0.5 2.9 1.7] = 0) (m [0.5 2.1 1.7] = 1)
       (m [0.7 2.2 1.7] = 1)
       (#alone = 6) (mag (total alone - 2.0 * (12.0 + 12.0 + 16.0)) < 1e-6)
       (all (f \ dot (f 1) (c+ [2.0 1.5 2.0] (c* -1.0 ((f 0) 0))) > 0.0) alone)
       (#(filter (f \ #f >= 3) (prism 'faces)) = 5)
       (brush-medium [prism] [1.0 1.0 0.5] = 0) (brush-medium [(brush-prism 1 0.0 2.0 [[0.0 0.0] [2.0 0.0] [1.0 2.0]])] [1.9 1.0 1.9] = 0)
       (brush-medium [(brush-box 1 [0.0 0.0 0.0] [9.0 9.0 9.0]) moved] [1.2 1.0 1.7] = 0)
       (brush-medium [(brush-box 1 [0.0 0.0 0.0] [9.0 9.0 9.0]) flip] [3.8 1.0 1.7] = 0)
       (brush-medium [(brush-box 1 [0.0 0.0 0.0] [9.0 9.0 9.0]) flip] [0.2 1.0 1.7] = 1)
       ; ..with the pilaster the room's west wall loses what it hides, and gains the column's faces
       (total (brush-faces [room col]) > total alone)
       !(any (f \ (: c (c* (1.0 / #(f 0)) (foldl c+ [0.0 0.0 0.0] (f 0))) (mag (c 0) < 1e-6 && 1.5 < c 2 < 2.0))) (brush-faces [room col]))
       !(any across? two) (any (f \ mag (f 1 0) > 0.9 && 3.98 < (f 0 0 2) < 4.22) two)
       (#(brush-faces [a1 s1]) = 6) (any (f \ f 1 = [0.0 0.0 1.0]) (brush-faces [a1 s1]))
       ; ..each face knows its brush: the room's walls its, the column's its
       (all (f \ f 2 = 0) alone) (any (f \ f 2 = 1) (brush-faces [room col]))
       ; ..a mesh, the faces cut a metre square: 80 squares, each fanned into two triangles
       (#(mesh0 1) = 2 * 80)))
(test_fin ())
(puts "brush: ok\n")
