; poly: convex polygons cut by planes. keep holds the inside, carve cuts only what a plane
; crosses and drops slivers, grid strips on every multiple of the cell, an uncut corner
; coming through as the word it was
(borrow 'lore)
(: py-sq [[0.0 0.0 0.0] [2.0 0.0 0.0] [2.0 2.0 0.0] [0.0 2.0 0.0]]
   (py-x d) [[1.0 0.0 0.0] d] (py-y d) [[0.0 1.0 0.0] d]
   py-c (poly-carve py-sq [(py-x 1.0) (py-x 5.0) (py-y 1e-12)])
   py-g (poly-grid py-sq 1.0)
 (test (poly-keep py-sq [(py-x 1.0)] = [[0.0 0.0 0.0] [1.0 0.0 0.0] [1.0 2.0 0.0] [0.0 2.0 0.0]])
       (poly-keep py-sq [(py-x 1.0) (py-x -1.0) (py-y 1.0)] = ())
       (poly-keep py-sq () = py-sq)
       (<(poly-keep py-sq [(py-x 1.0)]) == <py-sq)
       (py-c = [[[0.0 0.0 0.0] [1.0 0.0 0.0] [1.0 2.0 0.0] [0.0 2.0 0.0]] [[1.0 0.0 0.0] [2.0 0.0 0.0] [2.0 2.0 0.0] [1.0 2.0 0.0]]])
       (poly-carve py-sq [(py-x 3.0)] = [py-sq])
       (#py-g = 4 && py-g 3 = [[0.0 0.0 0.0] [1.0 0.0 0.0] [1.0 1.0 0.0] [0.0 1.0 0.0]])
       (net (map (p \ #p) py-g) = 16)
       (poly-grid py-sq 4.0 = [py-sq])
       (poly-carve py-sq [(py-x 'a)] = ()) (poly-grid [[0.0 0.0]] 1.0 = ()) (poly-keep 3 () = ())))
; poly-fans: a face's pieces fanned, an edge taking on a corner some piece has on it -- then
; fanned from the middle -- each corner's texels U and V on [x y z 1], as
; trays poly-weave joins: 11 numbers a vertex, 4 a triangle
(: py-sq [[0.0 0.0 0.0] [2.0 0.0 0.0] [2.0 2.0 0.0] [0.0 2.0 0.0]] py-b [[0.0 0.0 0.0] [1.0 0.0 0.0] [1.0 -1.0 0.0]]
   py-lk [7 [1.0 0.0 0.0 0.0] [0.0 1.0 0.0 0.0]] py-n [0.0 0.0 1.0]
   py-f (poly-fans [py-sq] py-n py-lk (poly-seen [py-sq py-b]))
   py-h (poly-fans [py-sq] py-n py-lk (poly-seen [py-sq]))
   ; ..a corner off any grid, and a hair off the edge, which it does not take
   py-o (poly-fans [py-sq] py-n py-lk (poly-seen [py-sq [[0.37 0.0 0.0] [0.5 -1.0 0.0] [0.2 -1.0 0.0]] [[2.0 1.3 1e-4] [3.0 1.0 0.0] [3.0 2.0 0.0]]]))
   py-fm (py-f 0 1) py-hm (py-h 0 1)
   (py-at t w j) (map (k \ peep t (w * j + k) ()) ^w) (py-v m j) (py-at (m 0) 11 j) (py-t m j) (py-at (m 1) 4 j)
   py-w (poly-weave [py-hm py-fm])
 (test (#py-f = 1) (py-f 0 0 = [1.0 1.0 0.0])
       (#(py-fm 0) = 66 && #(py-fm 1) = 20) (py-v py-fm 1 = [1.0 0.0 0.0 1.0 0.0 0.0 0.0 1.0 1.0 1.0 1.0])
       (py-v py-fm 5 = [1.0 1.0 0.0 1.0 1.0 0.0 0.0 1.0 1.0 1.0 1.0]) (py-t py-fm 0 = [5 1 0 7])
       (#(py-hm 0) = 44 && py-t py-hm 0 = [0 2 1 7] && py-t py-hm 1 = [0 3 2 7]) (py-v py-hm 2 = [2.0 2.0 0.0 2.0 2.0 0.0 0.0 1.0 1.0 1.0 1.0])
       (#(py-o 0 1 0) = 66 && py-v (py-o 0 1) 1 = [0.37 0.0 0.0 0.37 0.0 0.0 0.0 1.0 1.0 1.0 1.0])
       (poly-fans () py-n py-lk (poly-seen []) = ())
       (poly-fans [py-sq] py-n py-lk "nope" = ()) (poly-seen [[1]] = ())
       ; woven: the columns end to end, the second part's triangles past the first's corners
       (py-w 0 = 10 && #(py-w 1) = 11) (py-at (py-w 1 0) 10 0 = [0.0 2.0 2.0 0.0 0.0 1.0 2.0 2.0 0.0 1.0])
       (py-at (py-w 2) 4 1 = [0 3 2 7] && py-at (py-w 2) 4 2 = [9 5 4 7])
       (poly-weave () @ [0 cs t] (#cs = 11 && #t = 0) _ 0) (poly-weave [[(gem-tray [10] ^10) (star-tray [4] ^4)]] = ())))
; poly-beside: each face's neighbours, the faces of brushes near its own whose boxes meet
; its box, brush by brush in order and face by face
(: (py-c3 bs) (map (k \ gem-tray [#bs] (map (b \ 1.0 * b k) bs)) ^3)
   py-fl (py-c3 [[5 0 0] [0 0 0] [0 0 0]]) py-fh (py-c3 [[6 1 1] [1 0 1] [1 1 0]])
   py-sb (poly-beside py-fl py-fh (star-tray [3] [1 0 0]) (star-tray [3] [12 10 11])
                      (py-c3 [[0 0 0] [5 0 0]]) (py-c3 [[1 1 1] [6 1 1]]))
 (test (py-sb = [[12] [10 11] [10 11]])
       (poly-beside py-fl py-fh (star-tray [3] [1 0 2]) (star-tray [3] ^3) (py-c3 [[0 0 0]]) (py-c3 [[1 1 1]]) = ())
       (poly-beside 1 2 3 4 5 6 = ())))
; lamp-open: the open air puts a point out, a solid buries it, a room carved in the solid
; brings it in, or standing up out of a land leaves it open; past, out of every brush but a
; land's box. lamp-near the brushes near a box, lamp-varies whether a face's light changes
(: (py-cube l h) [[[1.0 0.0 0.0] (h 0)] [[-1.0 0.0 0.0] (0 - l 0)] [[0.0 1.0 0.0] (h 1)]
                  [[0.0 -1.0 0.0] (0 - l 1)] [[0.0 0.0 1.0] (h 2)] [[0.0 0.0 -1.0] (0 - l 2)]]
   (py-br k l h) ([k (4 * #(py-cube l h))] + l + h + cats (map (q \ q 0 + [(q 1)]) (py-cube l h)))
   ; ..flat at 3 over 0 to 30, one cell of two triangles
   py-land ([4 28 0 -1000 0 30 3 30] + [3 40 0 0 1 1 0 2 1 0] + [0 3 0 30 3 0 30 3 30 0 3 0 30 3 30 0 3 30])
   (py-db bs) (: l (cats bs) (gem-tray [#l] (map (v \ 1.0 * v) l)))
   py-px (gem-tray [4] [1.0 3.0 20.0 3.0]) py-py (gem-tray [4] [5.0 2.0 5.0 3.8]) py-pz (gem-tray [4] [1.0 3.0 20.0 3.0])
   py-od (py-db [(py-br 2 [0 0 0] [10 10 10]) (py-br 0 [2 0 2] [4 4 4]) (py-br 1 [2.5 1 2.5] [3.5 3 3.5])])
   py-lo (lamp-open py-px py-py py-pz py-od) (py-ls w) (map (i \ w i) ^4)
   py-ll (lamp-open py-px py-py py-pz (py-db [(py-br 2 [0 0 0] [10 10 10]) py-land (py-br 1 [2 0 2] [4 4 4])]))
   (py-sq y) (gem-tray [12] [1.0 y 1.0 3.0 y 1.0 3.0 y 3.0 1.0 y 3.0])
 (test (py-ls (py-lo 0) = [1.0 0.0 0.0 1.0]) (py-ls (py-lo 1) = [0.0 0.0 0.0 1.0]) (py-ls (py-lo 2) = [0.0 0.0 1.0 0.0])
       (py-ls (py-ll 0) = [1.0 1.0 0.0 1.0]) (py-ls (py-ll 1) = [0.0 0.0 0.0 0.0]) (py-ls (py-ll 2) = [0.0 0.0 1.0 0.0])
       (lamp-open py-px py-py py-pz (gem-tray [3] [2.0 9.0 0.0]) = ()) (lamp-open 1 2 3 4 = ())
       (#(lamp-near py-od [3 3 3] [3 3 3]) = 96 && lamp-near py-od [3 3 3] [3 3 3] 0 = 10.0 && #(lamp-near py-od [20 0 20] [21 1 21]) = 0)
       (lamp-varies (py-sq 3.8) [0 0 0] 0.15 0.25 py-od = 1 && lamp-varies (py-sq 5.0) [0 0 0] 0.15 0.25 py-od = 0)
       (lamp-varies (py-sq 3.8) [0 0 0] 0.15 0.25 (lamp-near py-od [1 3.8 1] [3 3.8 3]) = 1)
       (lamp-varies 1 2 3 4 5 = ())))
