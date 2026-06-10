; merge sort N pseudo-random ints (a MINSTD LCG, double-safe so every language
; produces the identical sequence), then an order-dependent rolling hash of the
; sorted list as the checksum (verifies the ordering, not just the multiset).
; l uses the C `sort` (total order); other dialects use their built-in sort.
(: (lcg x)        (mod (* 16807 x) 2147483647)
   (genl x n)     (? (< n 1) 0 (: nx (lcg x) (cons nx (genl nx (- n 1)))))
   (hsh acc l)    (? (atomp l) acc (hsh (mod (+ (* acc 31) (cap l)) 1000000007) (cbp l)))
   (sort-run n)   (hsh 0 (sort (genl 1 n)))
 (bench "sort" (\ _ (sort-run 5000))))
