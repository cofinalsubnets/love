;; mutable hash-table throughput (see bench/benches/hash.l). checksum = N*N.
(set package.path (.. "lib/?.lua;" package.path))
(local bench (require :bench))
(local N 10000)
(bench "hash" (fn []
  (local h {})
  (for [i 0 (- N 1)] (tset h (+ (* 97 i) 1) i))
  (var a 0)
  (for [i 0 (- N 1)] (set a (+ a (. h (+ (* 97 i) 1)))))
  (for [i 0 (- N 1)] (let [k (+ (* 97 i) 1)] (tset h k (+ (. h k) 1))))
  (for [i 0 (- N 1)] (set a (+ a (. h (+ (* 97 i) 1)))))
  a))
