; merge sort N pseudo-random ints (a MINSTD LCG, double-safe so every language makes the same
; sequence), then an order-dependent rolling hash of the sorted list as the checksum.
(: (lcg x)        (16807 * x % 2147483647)
   (genl x n)     (n < 1 ? 0 (: nx (lcg x) (nx . genl nx (n - 1))))
   (hsh acc l)    (atom? l ? acc (hsh ((acc * 31 + <l) % 1000000007) >l))
   (sort-run n)   (hsh 0 (sort (genl 1 n)))
 (bench "sort" (_ \ sort-run 5000)))
