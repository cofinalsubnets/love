;; map/filter/fold list pipeline: sum the squares of the odd numbers in [0, N).
;; the lazy range + intermediate seqs are realized INSIDE the timed work. checksum = 4891344686.
(load-file "lib/bench.clj")
(bench "deforest" (fn [] (reduce + (map #(mod (* % %) 1000003) (filter odd? (range 0 20000))))))
