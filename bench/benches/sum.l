; sum 0..N over a contiguous array, matched to sum.rs: build the tray (iota) and reduce it with net,
; both each rep. the array is materialized before net, so loopclose has nothing to close and the
; O(n) reduction runs. checksum = sum 0..100000 = 5000050000.
(: (work _) (: d (iota 100001) +d)
 (bench "sum" work))
