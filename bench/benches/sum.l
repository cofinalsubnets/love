; build 0..100000 then sum it -- allocation + traversal.
; checksum = 100000*100001/2 = 5000050000 (sum 0..100000 = sum 1..100000).
; l's idiom is the typed array: iota fills the range into a z-array in one C
; loop (no cons spine), and asum reduces it in one C loop -- both halves of the
; bench, allocation and traversal, are now baked.
(: (sumf n) (asum (iota n))
 (bench "sum" (\ _ (sumf 100001))))
