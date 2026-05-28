; arithmetic, comparison, equality:
; - fixnum fast paths unchanged
; - mixed nump/flop promotes to float
; - overflow on fixnum ops promotes to float
; - /0 returns nil in both type lanes
; - non-numeric operands return nil

(assert
 ; --- fixnum fast path ---
 (= 3 (+ 1 2))
 (= -1 (- 1 2))
 (= 6 (* 2 3))
 (= 2 (/ 5 2))
 (= 1 (% 5 2))

 ; --- mixed nump + flop promotes ---
 (= 3.5 (+ 1 2.5))
 (= 3.5 (+ 2.5 1))
 (= -1.5 (- 0 1.5))
 (= 1.0 (* 2 0.5))
 (= 0.5 (/ 1.0 2))
 (= 0.5 (/ 1 2.0))

 ; --- both float ---
 (= 4.0 (+ 1.5 2.5))
 (= 1.0 (- 1.5 0.5))
 (= 3.0 (* 1.5 2.0))
 (= 3.0 (/ 1.5 0.5))

 ; --- overflow promotes to float ---
 ; 1e19 > 2^62 (fixnum tag costs one bit), so the result must be a flo.
 (= 1e19 (* 10000000000 1000000000))
 (~ (nump (* 10000000000 1000000000)))

 ; --- /0 promotes to IEEE inf / -inf / NaN ---
 ; the result is a flo, not a fixnum; not equal to any finite value.
 (flop (/ 1 0))
 (flop (/ -1 0))
 (flop (/ 0 0))
 (flop (/ 1.0 0.0))
 (~ (= 0 (/ 1 0)))
 ; +inf is greater than every finite double we can write
 (< 1e308 (/ 1 0))
 ; -inf is less than every finite double
 (< (/ -1 0) -1e308)
 ; NaN compares unequal to itself
 (~ (= (/ 0 0) (/ 0 0)))

 ; --- rem via fmod, works on floats and mixed ---
 (= 1.0 (% 7.0 2.0))
 (= 1 (% 7 2))
 (= 0.0 (% 7.5 2.5))
 (= -1.0 (% -7.0 2.0))
 ; % by zero is NaN (via fmod's identity), expressed as a flo
 (flop (% 7 0))
 (flop (% 7.0 0.0))

 ; --- non-numeric operands → nil ---
 (nilp (+ "x" 1))
 (nilp (+ 1 "x"))
 (nilp (- "a" "b"))

 ; --- equality with promotion across nump/flop ---
 (= 3 3)
 (= 3 3.0)
 (= 3.0 3)
 (~ (= 3 4))
 (~ (= 3 3.5))
 (= 1.5 1.5)

 ; --- ordered comparison with promotion ---
 (< 1 2)
 (< 1 1.5)
 (< 1.5 2)
 (< 1.5 2.5)
 (~ (< 2 1))
 (~ (< 1.5 1.0))
 (<= 3 3.0)
 (<= 3.0 3)
 (> 2 1.5)
 (>= 3.0 3)

 ; --- non-numeric compare → nil ---
 (nilp (< "a" 1))
 (nilp (< 1 "a")))
