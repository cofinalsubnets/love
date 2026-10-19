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
