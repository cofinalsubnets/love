; arithmetic, comparison, equality:
; - fixnum fast paths unchanged
; - mixed fixp/flop promotes to float
; - integer overflow promotes to a boxed wide int (see test/box.l)
; - /0 promotes to IEEE inf/-inf/NaN
; - non-numeric operands return nil

(assert
 ; --- fixnum fast path ---
 (= 3 (+ 1 2))
 (= -1 (- 1 2))
 (= 6 (* 2 3))
 (= 2.5 (/ 5 2))                    ; `/` true division: inexact -> float
 (= 2 (/ 4 2))                      ; exact -> stays integer
 (fixp (/ 4 2))
 (= 0.5 (/ 1 2))
 (= 2 (// 5 2))                     ; `//` truncating integer division
 (= -2 (// -5 2))                   ; truncates toward zero (not floor -3)
 (= 1 (% 5 2))

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
 !(fixp (* 2 2305843009213693952))   ; 2^62: now a box, not a fixnum
 !(flop (* 2 2305843009213693952))   ; ...and integer, not float
 (= 2305843009213693952 (/ (* 2 2305843009213693952) 2))           ; box / 2 demotes
 (= 2305843009213693952 (- (* 2 2305843009213693952) 2305843009213693952)) ; box - fix demotes
 (? w64 (fixp (- (* 2 2305843009213693952) 2305843009213693952)) 1) ; ...to a fixnum (64-bit: 2^61 is in range)
 (= (* 2 2305843009213693952) (* 2 2305843009213693952))           ; equal boxes compare =

 ; --- 1/0 promotes to IEEE inf / -inf; 0/0 collapses to 0 (NaN is gone) ---
 ; the result is a real, not a fixnum; inf is not equal to any finite value.
 (flop (/ 1 0))
 (flop (/ -1 0))
 (flop (/ 0 0))                 ; 0/0 is 0.0 -- a real zero, not NaN
 (flop (/ 1.0 0.0))
 !(= 0 (/ 1 0))
 (= 0 (/ 0 0))                  ; ... and equal to 0
 ; +inf is greater than every finite double we can write (f64 only -- a 32-bit
 ; port's f32 reals overflow 1e308 to inf, so the comparison is vacuous there)
 (? w64 (< 1e308 (/ 1 0)) 1)
 ; -inf is less than every finite double
 (? w64 (< (/ -1 0) -1e308) 1)
 ; 0/0 is 0, so it equals itself (NaN's non-reflexivity is gone)
 (= (/ 0 0) (/ 0 0))

 ; --- rem via fmod, works on floats and mixed ---
 (= 1.0 (% 7.0 2.0))
 (= 1 (% 7 2))
 (= 0.0 (% 7.5 2.5))
 (= -1.0 (% -7.0 2.0))
 ; % by zero is NaN (via fmod's identity), expressed as a real
 (flop (% 7 0))
 (flop (% 7.0 0.0))

 ; --- + is generic: string/list concat, order-preserving; - stays numeric (nil) ---
 (= "xB" (+ "x" 66))                ; str + num -> one byte at back (the byte law)
 (= "Bx" (+ 66 "x"))                ; num + str -> byte at front
 (= "xB" (+ "x" 66.0))              ; rep-blind: 66.0 IS 66
 (nilp (+ "x" 66.9))                ; ... but a non-integer is NOT a byte -> nil
 (nilp (+ "x" -66)) (nilp (+ "x" 256))   ; out of 0..255 -> nil
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
 !(= 3 4)
 !(= 3 3.5)
 (= 1.5 1.5)

 ; --- ordered comparison with promotion ---
 (< 1 2)
 (< 1 1.5)
 (< 1.5 2)
 (< 1.5 2.5)
 !(< 2 1)
 !(< 1.5 1.0)
 (<= 3 3.0)
 (<= 3.0 3)
 (> 2 1.5)
 (>= 3.0 3)

 ; --- comparison is a TOTAL ORDER over all values: a number sorts below any
 ;     string (number < string < sym < pair < lambda); full lattice in matrix.l ---
 (< 1 "a")
 !(< "a" 1))
