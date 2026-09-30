; a map/filter/fold list pipeline: sum the squares mod p of the odd numbers in [0, N). naively it
; materializes three lists; the glaze's deforestation (src/love/boot/glaze.l defoliate) fuses it into
; one native counted loop. the `% p` keeps the body non-polynomial so loopclose declines: this is the
; fusion bench, and its sibling polysum (the square alone) is the closing bench.
; checksum = sum_{odd k < 20000} (k*k mod 1000003) = 4891344686 (< 2^53, exact in every language).
; across languages it measures the pipeline idiom's abstraction cost, not a fixed algorithm.
(: (work n) (foldl (+) 0 (map (x \ x * x % 1000003) (filter (x \ 1 = x % 2) (jot n))))
 (bench "deforest" (_ \ work 20000)))
