; test/host/brush.l -- src/apps/lore/brush.l: media (the later brush wins), the faces where air
; meets solid, turned to the air, none twice; the mesh cut on one grid
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
   alone (brush-faces [room])
   prism (brush-prism 0 0.0 2.0 [[0.0 0.0] [2.0 0.0] [1.0 2.0]])
   moved (brush-move col [1.0 0.0 0.0]) flip (brush-mirror col 0 2.0)
   ; a doorway between two rooms: its sides drawn, no face across it
   r2 (brush-box 1 [0.0 0.0 4.2] [4.0 3.0 8.0]) dw (brush-box 1 [1.5 0.0 3.98] [2.5 2.0 4.22])
   two (brush-faces [room r2 dw])
   (across? f) (: c (c* (1.0 / #(f 0)) (foldl c+ [0.0 0.0 0.0] (f 0)))
                  (1.5 < c 0 < 2.5 && c 1 < 2.0 && 3.99 < c 2 < 4.21 && mag (f 1 2) > 0.9))
   ; air half filled by a solid sharing three sides: five of the air's faces and the solid's top
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
       (total (brush-faces [room col]) > total alone)
       !(any (f \ (: c (c* (1.0 / #(f 0)) (foldl c+ [0.0 0.0 0.0] (f 0))) (mag (c 0) < 1e-6 && 1.5 < c 2 < 2.0))) (brush-faces [room col]))
       !(any across? two) (any (f \ mag (f 1 0) > 0.9 && 3.98 < (f 0 0 2) < 4.22) two)
       (#(brush-faces [a1 s1]) = 6) (any (f \ f 1 = [0.0 0.0 1.0]) (brush-faces [a1 s1]))
       ; each face knows its brush
       (all (f \ f 2 = 0) alone) (any (f \ f 2 = 1) (brush-faces [room col]))
       ; 80 metre squares, two triangles each
       (#(mesh0 1) = 2 * 80)))
;; a band cut from a box along both its sides, each side judged from the box's middle
(: sky (brush-box 1 [0.0 0.0 0.0] [20.0 20.0 2.0])
   band (brush-cuts (brush-box 0 [10.0 9.7 0.0] [14.5 12.7 1.0])
                    [[[14.5 9.18 0.0] [14.5 9.18 1.0] [10.0 11.78 0.0]] [[14.5 10.1 0.0] [14.5 10.1 1.0] [10.0 12.7 0.0]]])
   (m p) (brush-medium [sky band] p)
 (test (m [12.25 10.94 0.5] = 0) (m [12.25 12.0 0.5] = 1) (m [12.25 10.0 0.5] = 1) (m [14.3 10.0 0.5] = 0) (m [10.3 12.3 0.5] = 0)))
;; a ray: out of a room's air at its wall, facing back in; a solid column in the way ends
; the air first, its face toward the ray; from inside the solid, the air it comes out into
; ends at the wall
(: rr (brush-box 1 [0.0 0.0 0.0] [4.0 3.0 4.0]) rc (brush-box 0 [1.0 0.0 1.0] [2.0 3.0 2.0])
   h (brush-ray [rr] [2.0 1.5 2.0] [1.0 0.0 0.0]) h2 (brush-ray [rr rc] [3.5 1.5 1.5] [-1.0 0.0 0.0])
 (test (h 't = 2.0) (h 'b = 0) (h 'n = [-1.0 0.0 0.0]) (h 'p = [4.0 1.5 2.0])
       (h2 'b = 1) (h2 't = 1.5) (h2 'n = [1.0 0.0 0.0]) (brush-ray [rr rc] [1.5 1.5 1.5] [1.0 0.0 0.0] 't = 2.5) (brush-ray [] [1.5 1.5 1.5] [1.0 0.0 0.0] = ())))
(test_fin ())
(puts "brush: ok\n")
