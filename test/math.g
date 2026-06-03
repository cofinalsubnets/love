; transcendentals + sqrt + pow + pi.
; host uses libm; precision is ~1 ulp so identities don't need a slop band
; except where two errors compound (e.g. (sin pi) is ~1e-16, not exactly 0).

(: (close? a b eps) (< (- (? (< a b) (- b a) (- a b)) 0) eps)
   (close a b)       (close? a b 1e-12)
   (very-close a b)  (close? a b 1e-15)

   (assert
    ; --- pi from boot.g, basic identities ---
    (= 1.0 (cos 0))
    (= 0.0 (sin 0))
    (= -1.0 (cos pi))
    (close 0 (sin pi))
    (very-close 1.0 (sin (/ pi 2)))
    (very-close 0 (cos (/ pi 2)))

    ; --- pythagorean identity ---
    (close 1.0 (+ (* (sin 1.234) (sin 1.234))
                  (* (cos 1.234) (cos 1.234))))
    (close 1.0 (+ (* (sin (- 0 0.7)) (sin (- 0 0.7)))
                  (* (cos (- 0 0.7)) (cos (- 0 0.7)))))

    ; --- tan = sin/cos ---
    (close (tan 0.5) (/ (sin 0.5) (cos 0.5)))

    ; --- atan inverse of tan in (-pi/2, pi/2) ---
    (close 0.7 (atan (tan 0.7)))

    ; --- atan2 quadrants ---
    (very-close 0.0 (atan2 0 1))
    (very-close (/ pi 2) (atan2 1 0))
    (very-close pi (atan2 0 -1))
    (very-close (- 0 (/ pi 2)) (atan2 -1 0))
    (very-close (/ pi 4) (atan2 1 1))

    ; --- sqrt ---
    (= 0.0 (sqrt 0))
    (= 1.0 (sqrt 1))
    (= 2.0 (sqrt 4))
    (close 1.414213562373095 (sqrt 2))
    ; (sqrt (* x x)) ~ x for x > 0
    (close 7.5 (sqrt (* 7.5 7.5)))

    ; --- exp / log inverse ---
    (close 1.0 (exp 0))
    (close 2.718281828459045 (exp 1))
    (close 0 (log 1))
    (close 1.0 (log (exp 1)))
    (close 5.5 (log (exp 5.5)))

    ; --- pow ---
    (= 1.0 (pow 2 0))
    (= 2.0 (pow 2 1))
    (= 1024.0 (pow 2 10))
    (close 0.5 (pow 2 -1))
    (close 1.414213562373095 (pow 2 0.5))

    ; --- accepts fixnum args (promoted to float) ---
    (flop (sin 0))
    (flop (sqrt 4))
    (flop (pow 2 3))

    ; --- non-numeric arg → nil ---
    ; (nil counts as numeric — it's putnum(0).)
    (nilp (sin "x"))
    (nilp (sqrt '(1 2)))
    (nilp (pow "a" 1))
    (nilp (atan2 "x" 1))

    ; --- generic over bignums: the operand widens full-magnitude (g_big_to_flo),
    ;     exactly as a scalar bignum already fed the scalar pow ---
    (= 1125899906842624.0 (sqrt 1267650600228229401496703205376))  ; sqrt(2^100) = 2^50
    (flop (pow 1267650600228229401496703205376 2))
    (< 1e300 (pow 2 100000000000000000000))                        ; huge bignum exp -> inf

    ; --- pow / atan2 elementwise over arrays (numpy broadcast); result is f64 ---
    (= f64 (atype (pow (arrl i32 '(2) '(2 3)) 2)))                  ; always a float array
    (aall (= (pow (arrl f64 '(3) '(1 2 3)) 2) (arrl f64 '(3) '(1 4 9))))  ; array ^ scalar
    (aall (= (pow 2 (arrl f64 '(3) '(1 2 3))) (arrl f64 '(3) '(2 4 8))))  ; scalar ^ array
    (aall (= (pow (arrl f64 '(3) '(1 2 3)) (arrl f64 '(3) '(2 2 2)))      ; array ^ array
             (arrl f64 '(3) '(1 4 9))))
    (close 1.570796326794897 (get 0 1 (atan2 (arrl f64 '(2) '(1 1))      ; atan2(1,0) = pi/2
                                              (arrl f64 '(2) '(1 0)))))
    (nilp (pow (arrl f64 '(2) '(1 2)) "x"))                         ; array vs non-number -> nil

    ; --- bignum meets array (arithmetic): the array wins, the bignum demotes to
    ;     the array's element form -- full magnitude in a float array, low bits in
    ;     an int array (modular, so it wraps: 2^64 + 5 contributes 5). Comparison
    ;     against a bignum stays magnitude-exact -- see test/bignum.g ---
    (aall (= (+ (arrl i64 '(2) '(1 2)) 18446744073709551621)        ; 2^64 + 5 -> low word 5
             (arrl i64 '(2) '(6 7))))
    (< 1e19 (get 0 0 (+ (arrl f64 '(2) '(0 0)) 18446744073709551616)))))  ; 2^64 full magnitude
