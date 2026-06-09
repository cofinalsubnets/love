;; clojure benchmark harness -- mirrors bench/bench.l. (System/nanoTime) wall
;; clock; one line out: <name> <lang> <reps> <ms> <checksum> (println is
;; space-separated). label from BENCH_LANG (default "clojure").
(def bench-min-ms 200.0)
(def bench-lang (or (System/getenv "BENCH_LANG") "clojure"))
(defn bench [name work]
  (loop [reps 1]
    (let [t0  (System/nanoTime)
          chk (loop [i 0 c nil] (if (< i reps) (recur (inc i) (work)) c))
          ms  (/ (- (System/nanoTime) t0) 1e6)]
      (if (>= ms bench-min-ms)
        (println name bench-lang reps ms chk)
        (recur (* 2 reps))))))
