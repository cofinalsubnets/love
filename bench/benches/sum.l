; build the list 1..100000 then fold-sum it -- allocation + traversal.
; checksum = 100000*100001/2 = 5000050000.
(: (sumf l) (foldl + 0 l)
 (bench "sum" (\ _ (sumf (iota1 100000)))))
