;; Bell numbers in base 36 (see bench/benches/bell.l) -- a bignum-tower stress.
(load-file "lib/bench.clj")
(def digits "0123456789abcdefghijklmnopqrstuvwxyz")
(def base (count digits))
(defn bell-run [limit]
  (let [facts (atom {}) bells (atom {})]
    (letfn [(fact [n]
              (or (@facts n)
                  (let [v (loop [x 1 m n] (if (> m 1) (recur (*' x m) (dec m)) x))]
                    (swap! facts assoc n v) v)))
            (choose [n k] (/ (fact n) (*' (fact k) (fact (- n k)))))
            (bell [n]
              (or (@bells n)
                  (let [r (if (< n 2) 1
                            (loop [k 0 a 0]
                              (if (< k n) (recur (inc k) (+' a (*' (choose (dec n) k) (bell k)))) a)))]
                    (swap! bells assoc n r) r)))
            (show [n]
              (loop [n n s ""]
                (if (> n 0)
                  (recur (quot n base) (str (.charAt digits (int (mod n base))) s))
                  s)))]
      (loop [i 0 total 0]
        (let [b (show (bell i))]
          (if (> (count b) limit) total (recur (inc i) (+ total (count b)))))))))
(bench "bell" (fn [] (bell-run 280)))
