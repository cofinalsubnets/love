;; closure / higher-order stress (see bench/benches/closure.l). checksum = sum 3i.
(load-file "lib/bench.clj")
(def N 100000)
(defn twice [f] (fn [x] (f (f x))))
(defn adder [i] (fn [x] (+ x i)))
(bench "closure"
  (fn []
    (loop [i 0 s 0]
      (if (< i N) (recur (inc i) (+ s ((twice (adder i)) i))) s))))
