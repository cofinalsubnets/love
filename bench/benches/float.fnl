;; mandelbrot escape counts over a 64x64 grid (see bench/benches/float.l).
(set package.path (.. "lib/?.lua;" package.path))
(local bench (require :bench))
(fn mand [cx cy]
  (var zx 0.0) (var zy 0.0) (var it 0)
  (while (and (< it 100) (<= (+ (* zx zx) (* zy zy)) 4.0))
    (let [nzx (+ (- (* zx zx) (* zy zy)) cx)
          nzy (+ (* (* 2.0 zx) zy) cy)]
      (set zx nzx) (set zy nzy) (set it (+ it 1))))
  it)
(bench "float" (fn []
  (var s 0)
  (for [px 0 63]
    (for [py 0 63]
      (set s (+ s (mand (+ -2.0 (* px 0.046875)) (+ -1.5 (* py 0.046875)))))))
  s))
