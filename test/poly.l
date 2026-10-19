; poly: convex polygons cut by planes. keep holds the inside, carve cuts only what a plane
; crosses and drops slivers, grid strips on every multiple of the cell, an uncut corner
; coming through as the word it was
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
; poly-fans: a face's pieces fanned, an edge taking on a corner some piece has where it crosses
; the fine grid -- then fanned from the middle -- each corner's texels U and V on [x y z 1]
(: py-sq [[0.0 0.0 0.0] [2.0 0.0 0.0] [2.0 2.0 0.0] [0.0 2.0 0.0]] py-b [[0.0 0.0 0.0] [1.0 0.0 0.0] [1.0 -1.0 0.0]]
   py-lk [7 [1.0 0.0 0.0 0.0] [0.0 1.0 0.0 0.0]] py-n [0.0 0.0 1.0]
   py-f (poly-fans [py-sq] py-n py-lk (poly-seen [py-sq py-b]) 1.0)
   py-h (poly-fans [py-sq] py-n py-lk (poly-seen [py-sq]) 1.0)
   py-fm (py-f 0 1) py-hm (py-h 0 1)
 (test (#py-f = 1) (py-f 0 0 = [1.0 1.0 0.0])
       (#(py-fm 0) = 6 && #(py-fm 1) = 5) (py-fm 0 1 = [1.0 0.0 0.0 1.0 0.0 0.0 0.0 1.0 1.0 1.0 1.0])
       (py-fm 0 5 = [1.0 1.0 0.0 1.0 1.0 0.0 0.0 1.0 1.0 1.0 1.0]) (py-fm 1 0 = [5 1 0 7])
       (#(py-hm 0) = 4 && py-hm 1 = [[0 2 1 7] [0 3 2 7]]) (py-hm 0 2 = [2.0 2.0 0.0 2.0 2.0 0.0 0.0 1.0 1.0 1.0 1.0])
       (poly-fans () py-n py-lk (poly-seen []) 1.0 = ())
       (poly-fans [py-sq] py-n py-lk "nope" 1.0 = ()) (poly-seen [[1]] = ())))
