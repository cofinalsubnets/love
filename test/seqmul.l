; `*` extended as the multiplicative analog of `+` (ll.c g_mul_mx), dispatched
; through the same kind matrix. `*` is "repeated `+`": a sequence (string/symbol/
; list) times a scalar count n is n copies joined, just as (* 2 3) = 2+2+2. The
; count is L2-norm-coerced (int(abs c)); an array/non-number count is undefined
; (nil); sequence x sequence is undefined; a thread anywhere -> composition.
(: sm-i (\ x (? (symp x) (= x (intern (string x))) 0)))      ; interned symbol?
(assert
 ; --- numbers unchanged ---
 (= 6 (* 2 3))   (= 7.5 (* 3 2.5))
 (aall (= @(2 4 6) (* @(1 2 3) 2)))             ; array broadcast

 ; --- string repetition (commutative), empty, count coercion ---
 (= "ababab" (* "ab" 3))   (= "ababab" (* 3 "ab"))
 (= "" (* "ab" 0))   (strp (* "ab" 0))          ; 0 -> the empty string
 (= "abab" (* "ab" -2))                         ; count is |n|: 2 copies
 (= "abab" (* "ab" 2.9))                        ; float count -> int(abs) = 2
 (= "ababababab" (* "ab" ~(3 4)))              ; |3+4i| = 5 copies
 (= "xxx" (* "x" 3))

 ; --- symbol repetition: stays at the operand's own rank (no demotion) ---
 (= 'xyxy (* 'xy 2))   (sm-i (* 'xy 2))         ; interned -> interned
 (= "cdcd" (string (* $cd 2)))                  ; uninterned name repeats
 (nilp (sm-i (* $cd 2)))                        ; ... and stays uninterned

 ; --- list repetition ---
 (= '(1 2 1 2 1 2) (* '(1 2) 3))
 (= '(1 2 1 2) (* 2 '(1 2)))                    ; commutative
 (nilp (* '(1 2) 0))                            ; 0 copies of a list -> nil

 ; --- undefined cells -> nil ---
 (nilp (* "ab" "cd"))                           ; seq x seq
 (nilp (* 'a 'b))
 (nilp (* '(1) '(2)))
 (nilp (* "ab" @(1 2)))                         ; array is not a count
 (nilp (* @(1 2) "ab"))
 ; a map is a lookup-lambda, so it takes the thread (composition) rule, not nil:
 ; (* m g) x = (m (g x)); here m maps 5->10, g adds 4, so (1) -> g 5 -> m 10
 (= 10 ((* (put 5 10 (hashn 0)) (\ x (+ x 4))) 1))

 ; --- thread precedence: composition = Church mul ((* f g) x = f (g x)) ---
 (= 36 ((* (\ x (* x x)) (\ x (+ x 1))) 5))     ; sq(inc 5) = sq 6 = 36
 (= 26 ((* (\ x (+ x 1)) 2) 5))                 ; (inc (2 5)) = inc 25 = 26

 ; --- the semiring tie: s*n == s + s + … (n times). NB +/* are binary, so the
 ;     n-fold sum must be nested explicitly (over-applying a string indexes it) ---
 (= (* "ab" 3) (+ "ab" (+ "ab" "ab")))
 (= (* '(1) 3) (+ '(1) (+ '(1) '(1)))))
