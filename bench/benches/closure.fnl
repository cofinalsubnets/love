;; closure / higher-order stress (see bench/benches/closure.l). checksum = sum 3i.
(set package.path (.. "lib/?.lua;" package.path))
(local bench (require :bench))
(fn twice [f] (fn [x] (f (f x))))
(fn adder [i] (fn [x] (+ x i)))
(local N 100000)
(bench "closure" (fn []
  (var s 0)
  (for [i 0 (- N 1)] (set s (+ s ((twice (adder i)) i))))
  s))
