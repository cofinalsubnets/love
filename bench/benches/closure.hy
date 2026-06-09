;; closure / higher-order stress (see bench/benches/closure.l). checksum = sum 3i.
(import sys)
(sys.path.insert 0 "lib")
(import bench [bench])
(setv twice (fn [f] (fn [x] (f (f x)))))
(setv adder (fn [i] (fn [x] (+ x i))))
(setv N 100000)
(defn work []
  (setv s 0)
  (for [i (range N)] (setv s (+ s ((twice (adder i)) i))))
  s)
(bench "closure" (fn [] (work)))
