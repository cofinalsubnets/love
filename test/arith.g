; arithmetic, comparison, equality:
; - fixnum fast paths unchanged
; - mixed fixp/flop promotes to float
; - integer overflow promotes to a boxed wide int (see test/box.g)
; - /0 promotes to IEEE inf/-inf/NaN
; - non-numeric operands return nil

(assert
 ; --- fixnum fast path ---
 (= 3 (+ 1 2))
 (= -1 (- 1 2))
 (= 6 (* 2 3))
 (= 2 (/ 5 2))
 (= 1 (mod 5 2))

 ; --- mixed fixp + flop promotes ---
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

 ; --- integer overflow promotes to a boxed wide int (not a float) ---
 ; 2^61 is the largest power of two that's still a fixnum; doubling it
 ; overflows the 62-bit tag into a box that holds the exact integer
 ; (which then demotes back to a fixnum once it fits again).
 (~ (fixp (* 2 2305843009213693952)))   ; 2^62: now a box, not a fixnum
 (~ (flop (* 2 2305843009213693952)))   ; ...and integer, not float
 (= 2305843009213693952 (/ (* 2 2305843009213693952) 2))           ; box / 2 demotes
 (= 2305843009213693952 (- (* 2 2305843009213693952) 2305843009213693952)) ; box - fix demotes
 (fixp (- (* 2 2305843009213693952) 2305843009213693952))          ; ...to a fixnum
 (= (* 2 2305843009213693952) (* 2 2305843009213693952))           ; equal boxes compare =

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
 (= 1.0 (mod 7.0 2.0))
 (= 1 (mod 7 2))
 (= 0.0 (mod 7.5 2.5))
 (= -1.0 (mod -7.0 2.0))
 ; % by zero is NaN (via fmod's identity), expressed as a flo
 (flop (mod 7 0))
 (flop (mod 7.0 0.0))

 ; --- + is generic: string/list concat, order-preserving; - stays numeric (nil) ---
 (= "xB" (+ "x" 66))                ; str + num -> byte (floor|n| mod 256) at back
 (= "Bx" (+ 66 "x"))                ; num + str -> byte at front
 (= "xB" (+ "x" 66.9))              ; numeric coerced via floor(|n|)
 (= "abcd" (+ "ab" "cd"))           ; str + str -> concat
 (= '(1 2 3 4) (+ '(1 2) '(3 4)))   ; list + list -> append
 (= '("x" 1 2) (+ "x" '(1 2)))      ; str + list -> (X str list)
 (= '(1 2 "x") (+ '(1 2) "x"))      ; list + str -> (append list (list str))
 (= '(5 1 2) (+ 5 '(1 2)))          ; num + list -> X at front
 (= '(1 2 5) (+ '(1 2) 5))          ; list + num -> append at back
 (nilp (- "a" "b"))

 ; --- equality with promotion across fixp/flop ---
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
