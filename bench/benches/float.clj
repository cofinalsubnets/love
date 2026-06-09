;; mandelbrot escape counts over a 64x64 grid (see bench/benches/float.l).
(load-file "lib/bench.clj")
(defn mand [cx cy]
  (loop [zx 0.0 zy 0.0 it 0]
    (if (and (< it 100) (<= (+ (* zx zx) (* zy zy)) 4.0))
      (recur (+ (- (* zx zx) (* zy zy)) cx) (+ (* (* 2.0 zx) zy) cy) (inc it))
      it)))
(defn work []
  (reduce + (for [px (range 64) py (range 64)]
              (mand (+ -2.0 (* px 0.046875)) (+ -1.5 (* py 0.046875))))))
(bench "float" (fn [] (work)))
