; triangular numbers via (sat (jot k)): jot 0 and jot 1 both sum to 0, so the row opens 0 0 1 3

(flip compose jot (map (compose sat jot)) @ tri               ; n -> the first n partial sums of jot
 (test
  ('(0 0 1 3 6 10 15 21 28 36 45 55) = (tri 12))     ; T(k-1); the double zero is the floor
  (0 = (sat (jot 0))) (0 = (sat (jot 1)))            ; () and (0): nothing == 0, both blue
  (1 = (sat (jot 2)))                                ; then 1, the first triangle, at k=2

  ('(0 1 3 6)  = (map (compose sat jot) (map (+ 1) (jot 4))))      ; from jot 1: a single zero
  ('(1 3 6 10) = (map (compose sat (compose jot (+ 2))) (jot 4)))))     ; from jot 2: 1 comes first
