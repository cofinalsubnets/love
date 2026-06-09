;; mandelbrot escape counts over a 64x64 grid (see bench/benches/float.l).
(import sys)
(sys.path.insert 0 "lib")
(import bench [bench])
(defn mand [cx cy]
  (setv zx 0.0 zy 0.0 it 0)
  (while (and (< it 100) (<= (+ (* zx zx) (* zy zy)) 4.0))
    (setv nzx (+ (- (* zx zx) (* zy zy)) cx))
    (setv nzy (+ (* (* 2.0 zx) zy) cy))
    (setv zx nzx zy nzy it (+ it 1)))
  it)
(defn work []
  (setv s 0)
  (for [px (range 64)]
    (for [py (range 64)]
      (setv s (+ s (mand (+ -2.0 (* px 0.046875)) (+ -1.5 (* py 0.046875)))))))
  s)
(bench "float" (fn [] (work)))
