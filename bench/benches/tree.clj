;; binary-trees allocation/GC stress (see bench/benches/tree.l). checksum = 2^D-1.
(load-file "lib/bench.clj")
(defn mk [d] (if (zero? d) nil [(mk (dec d)) (mk (dec d))]))
(defn ck [t] (if (nil? t) 0 (+ 1 (ck (t 0)) (ck (t 1)))))
(bench "tree" (fn [] (ck (mk 16))))
