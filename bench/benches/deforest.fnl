;; map/filter/fold list pipeline: sum the squares of the odd numbers in [0, N).
;; lua has no map/filter, so the idiom is a single loop over the range. checksum = 1333333330000.
(set package.path (.. "lib/?.lua;" package.path))
(local bench (require :bench))
(bench "deforest" (fn []
  (var s 0)
  (for [i 0 19999]
    (when (= (% i 2) 1) (set s (+ s (* i i)))))
  s))
