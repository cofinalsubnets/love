;; mutable hash-table throughput (see bench/benches/hash.l). checksum = N*N.
(import sys)
(sys.path.insert 0 "lib")
(import bench [bench])
(setv N 10000)
(defn work []
  (setv h {})
  (for [i (range N)] (setv (get h (+ (* 97 i) 1)) i))
  (setv a 0)
  (for [i (range N)] (setv a (+ a (get h (+ (* 97 i) 1)))))
  (for [i (range N)]
    (setv k (+ (* 97 i) 1))
    (setv (get h k) (+ (get h k) 1)))
  (for [i (range N)] (setv a (+ a (get h (+ (* 97 i) 1)))))
  a)
(bench "hash" (fn [] (work)))
