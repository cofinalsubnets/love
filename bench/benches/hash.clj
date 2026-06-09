;; Mutable hash-table throughput (see bench/benches/hash.l). Clojure's core maps
;; are persistent, so this uses java.util.HashMap for a true mutable table.
(load-file "lib/bench.clj")
(defn hash-run [n]
  (let [h (java.util.HashMap.)]
    (dotimes [i n] (.put h (+ (* 97 i) 1) i))
    (let [scan (fn [] (loop [i 0 a 0]
                        (if (< i n) (recur (inc i) (+ a (.get h (+ (* 97 i) 1)))) a)))
          a (scan)]
      (dotimes [i n]
        (let [k (+ (* 97 i) 1)]
          (.put h k (+ (.get h k) 1))))
      (+ a (scan)))))
(bench "hash" (fn [] (hash-run 10000)))
