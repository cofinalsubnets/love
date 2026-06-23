; polysum -- the LOOP-CLOSER showcase: the same odd-squares map/filter/fold pipeline as `deforest`, but
; with a PURE-POLYNOMIAL body, so ai's loop-closer (ai/glaze/auto.l loopclose, the doc/proto/close.l
; pass) collapses it to its CLOSED FORM -- O(1), independent of N. The odd filter is reparametrized
; (k = 2j+1) and the sum Σ_{j<N/2} (2j+1)^2 emitted as a closed polynomial in N (Newton-Gregory + the
; hockey-stick identity, exact integers). every OTHER language runs the O(n) pipeline -- this is the
; row where ai does what LLVM's scalar-evolution punts on (SCEV gives up on the data-dependent odd
; filter; close changes variable and solves it). the sibling `deforest` is the same shape with a `%` in
; the body that breaks the closed form, so it measures FUSION (O(n)) where this measures CLOSING (O(1)).
; checksum = sum_{odd k < 20000} k^2 = 1333333330000 (< 2^53, exact in every language).
(: (work n) (foldl (+) 0 (map (\ x (* x x)) (filter (\ x (= 1 (% x 2))) (jot n))))
 (bench "polysum" (\ _ (work 20000))))
