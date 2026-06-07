; step 7: complex arithmetic.
; - a complex is a rank-0 scalar (cplxp), the widest numeric tier: complex >
;   float > int/bignum. (C re im) builds one; `i` = (C 0 1) is the unit.
; - + - * / promote a real operand to (r, 0); % is undefined (-> nil).
; - sticky: never demotes to a real, even when im is 0 (eql-distinct keys).
; - unordered: < <= > >= on a complex -> nil. `=` IS defined and bridges to reals.
; - accessors re / im / conj / abs / arg; abs is type-aware.

(: (close? a b eps) (< (- (? (< a b) (- b a) (- a b)) 0) eps)
   (close a b)       (close? a b 1e-12)
   (cclose z w)      (? (close (re z) (re w)) (close (im z) (im w)) 0)
   B100 (** 2 100))

(assert
 ; --- printer: (C re im) constructor form, reads back by re-evaluation ---
 (= "(C 0.0 1.0)" (inspect i))
 (= "(C 2.0 3.0)" (inspect (C 2 3)))
 (= "(C 2.0 -3.0)" (inspect (C 2 -3)))
 (= "(C -1.0 -2.0)" (inspect (C -1 -2)))

 ; --- the defining identity, and that `=` bridges complex to a real ---
 (= (* i i) -1)                           ; i^2 = -1+0i, equal to the real -1
 (= (C 2 0) 2)                          ; cross-real equality (im 0)
 (= (C 2 0) 2.0)
 (= (+ 2 (* 3 i)) (C 2 3))              ; 2+3i built through the arith lanes

 ; --- sticky: a real-valued complex stays complex (distinct from the real) ---
 (cplxp (C 2 0))
 (cplxp i)
 (nilp (cplxp 5))
 (nilp (cplxp 5.0))

 ; --- componentwise add / sub; Gaussian mul; div by conjugate ---
 (= (+ (C 1 2) (C 3 4)) (C 4 6))
 (= (- (C 1 2) (C 3 4)) (C -2 -2))
 (= (* (C 1 2) (C 3 4)) (C -5 10))
 (cclose (/ (C 1 2) (C 3 4)) (C 0.44 0.08))
 (= (* (C 0 2) i) -2)                   ; 2i * i = -2 (real), via cross-real =

 ; --- accessors ---
 (= 2.0 (re (C 2 3)))
 (= 3.0 (im (C 2 3)))
 (= (conj (C 2 3)) (C 2 -3))
 (= 7 (re 7))                              ; re of a real is itself
 (nilp (im 7))                             ; im of a real is 0
 (= 5 (conj 5))                            ; conj of a real is itself

 ; --- abs: type-aware. complex -> float magnitude; real stays in its tier ---
 (= 5.0 (abs (C 3 4)))
 (= 13.0 (abs (C -5 12)))
 (= 5 (abs -5))   (nump (abs -5))          ; fixnum abs stays a fixnum
 (= 5 (abs 5))
 (= 5.5 (abs -5.5))                        ; float abs stays a float
 (= B100 (abs (- 0 B100)))                 ; bignum abs flips the sign, stays a bignum
 (= B100 (abs B100))

 ; --- arg: phase. complex via atan2; real -> 0 (>=0) or pi (<0) ---
 (close (/ pi 2) (arg i))
 (close 0 (arg (C 1 0)))
 (close pi (arg -1))
 (close 0 (arg 5))

 ; --- unordered: comparisons on a complex operand are nil ---
 (nilp (< i 1))   (nilp (> i 1))   (nilp (<= i 1))   (nilp (>= i 1))
 (nilp (< 1 i))   (nilp (<= (C 1 1) (C 2 2)))

 ; --- % is undefined on complex; sin/sqrt/atan2 stay real-domain (deferred) ---
 (nilp (mod i 2))
 (nilp (sin i))   (nilp (sqrt i))   (nilp (atan2 i 1))
 ; pow IS defined on complex: w^z = exp(z Log w). i^2 = -1, i^i = e^(-pi/2) (real)
 (close -1 (re (pow i 2)))   (close 0 (im (pow i 2)))
 (close 0.20787957635076193 (re (pow i i)))   (close 0 (im (pow i i)))

 ; --- truthiness: a complex zero is falsy, any nonzero part is truthy ---
 (nilp (C 0 0))
 (nilp (C 0 0.0))
 (? i -1 0)                                ; i is truthy
 (? (C 0 1) -1 0)
 (nilp (nilp i))

 ; --- complex meets bignum: the bignum narrows to double (floating domain) ---
 (cplxp (+ i B100))
 (= 1.0 (im (+ i B100)))                   ; imaginary part untouched
 (< 1e29 (re (+ i B100)))                  ; real part ~ 2^100

 ; --- complex as hash keys: eql-distinct from the equal real (sticky) ---
 (= 'hit (get 'miss (C 2 0) (put (C 2 0) 'hit (hashn 0))))
 (= 'miss (get 'miss 2 (put (C 2 0) 'hit (hashn 0))))   ; 2 and 2+0i are different keys
 (= 'iv (get 'miss i (put i 'iv (hashn 0)))))
