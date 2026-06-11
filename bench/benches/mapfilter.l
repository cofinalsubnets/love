; list pipeline: square every element, keep the even results, sum them.
; the source list is built once; each iteration re-runs map/filter/fold.
(: (sq x) (* x x)  (evenp x) (= 0 (% x 2))  (sumf l) (foldl (+) 0 l)
   data (iota 10000)
 (bench "mapfilter" (\ _ (sumf (filter evenp (map sq data))))))
