; list pipeline: square every element, keep the even results, sum them.
; l's idiom is the typed array, so the squaring, the even-mask, and the sum
; all run through the baked array kernels (one C loop each, no per-element
; closure): sq = d*d ; zero the odd squares with (1 - sq%2) ; net.
; checksum matches the link-list version (166616670000).
(: data (iota 10000)
 (bench "mapfilter" (\ _ (: sq (data * data) (net (sq * (1 - (sq % 2))))))))
