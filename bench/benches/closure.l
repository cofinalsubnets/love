; closure -- higher-order / closure-allocation stress. The closures ESCAPE into a list and are
; then applied THROUGH it, so no compiler can inline the call site -- which closure runs at
; `((cap fns) i)` is data-dependent (retrieved from the heap), so dechurch/loopclose/deforest all
; correctly decline and this measures REAL closure allocation + opaque application, not a folded
; loop. (The old inline `twice(adder(i))(i)` glazed away to O(1); that measured the optimizer, not
; closures.) checksum = sum of 3i for i<100000 = 14999850000.
(: twice (\ f (\ x (f (f x))))
   adder (\ i (\ x (+ x i)))
   N 100000
   (build i)           (? (< i N) (link (twice (adder i)) (build (+ i 1))) ())               ; N closures, heap-stored
   (apply-all fns i s)  (? (atom? fns) s (apply-all (cup fns) (+ i 1) (+ s ((cap fns) i))))    ; apply each to its index -> 3i
 (bench "closure" (\ _ (apply-all (build 0) 0 0))))
