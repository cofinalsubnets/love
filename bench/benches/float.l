; mandelbrot escape counts over a 64x64 grid -- pure f64 arithmetic with an
; integer checksum (sum of per-pixel iteration counts). only +,-,*,<= are used
; (no transcendentals) over exactly representable constants, so every language,
; including ll's boxed-float path, agrees bit-for-bit. exercises the float
; tower rather than the integer/evaluator path.
(: (mand cx cy zx zy it)
    (? (&& (< it 100) (<= (+ (* zx zx) (* zy zy)) 4.0))
       (mand cx cy (+ (- (* zx zx) (* zy zy)) cx) (+ (* (* 2.0 zx) zy) cy) (+ it 1))
       it)
   (col px py acc) (? (< py 64)
                      (col px (+ py 1) (+ acc (mand (+ -2.0 (* px 0.046875)) (+ -1.5 (* py 0.046875)) 0.0 0.0 0)))
                      acc)
   (grid px acc) (? (< px 64) (grid (+ px 1) (+ acc (col px 0 0))) acc)
 (bench "float" (\ _ (grid 0 0))))
