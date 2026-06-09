; closure / higher-order-function stress: per i, build the closure (adder i) and
; the closure (twice (adder i)), then apply -- twice(f) = \x f(f x), so
; (twice (adder i)) i = i + 2i = 3i. checksum = sum of 3i over 0..N-1. allocates
; 2 closures per iteration, exercising ll's curried-unary-function model.
(: twice (\ f (\ x (f (f x))))
   adder (\ i (\ x (+ x i)))
   (hof i acc) (? (< i 100000) (hof (+ i 1) (+ acc ((twice (adder i)) i))) acc)
 (bench "closure" (\ _ (hof 0 0))))
