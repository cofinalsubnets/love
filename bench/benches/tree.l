; binary-trees allocation/GC stress: build a perfect binary tree of depth D
; (2^D-1 internal nodes, leaves are nil) then traverse counting nodes. checksum
; = node count = 2^D-1. measures small-aggregate allocation + collector churn.
(: (mk d) (? (< d 1) 0 (cons (mk (- d 1)) (mk (- d 1))))
   (ck t) (? (twop t) (+ 1 (+ (ck (car t)) (ck (cdr t)))) 0)
 (bench "tree" (\ _ (ck (mk 16)))))
