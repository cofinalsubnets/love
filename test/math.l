; transcendentals + sqrt + pow + pi.
; host uses libm; precision is ~1 ulp so identities don't need a slop band
; except where two errors compound (e.g. (sin pi) is ~1e-16, not exactly 0).

(: (close? a b eps) (< (- (? (< a b) (- b a) (- a b)) 0) eps)
   (close a b)       (close? a b (? w64 1e-12 1e-5))   ; f32 reals (wasm) need a looser eps
   (very-close a b)  (close? a b (? w64 1e-15 1e-5))

   (assert
    ; --- pi from boot.l, basic identities ---
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

    ; --- atan inverse of tan in (-pi/2, pi/2); tan is now (/ (sin x) (cos x)) ---
    (close 0.7 (arg ~(1 (/ (sin 0.7) (cos 0.7)))))

    ; --- atan2 quadrants ---
    (very-close 0.0 (arg ~(1 0)))
    (very-close (/ pi 2) (arg ~(0 1)))
    (very-close pi (arg ~(-1 0)))
    (very-close (- 0 (/ pi 2)) (arg ~(0 -1)))
    (very-close (/ pi 4) (arg ~(1 1)))

    ; --- sqrt ---
    (= 0.0 ((/ 1 2) 0))
    (= 1.0 ((/ 1 2) 1))
    (= 2.0 ((/ 1 2) 4))
    (close 1.414213562373095 ((/ 1 2) 2))
    ; (sqrt (* x x)) ~ x for x > 0
    (close 7.5 ((/ 1 2) (* 7.5 7.5)))

    ; --- exp / log inverse ---
    (close 1.0 (0 e))
    (close 2.718281828459045 (1 e))
    (close 0 (log 1))
    (close 1.0 (log (1 e)))
    (close 5.5 (log (5.5 e)))

    ; --- pow ---
    (= 1.0 (pow 2 0))
    (= 2.0 (pow 2 1))
    (= 1024.0 (pow 2 10))
    (close 0.5 (pow 2 -1))
    (close 1.414213562373095 (pow 2 0.5))

    ; --- accepts fixnum args (promoted to float) ---
    (flop (sin 0))
    (flop ((/ 1 2) 4))
    (flop (pow 2 3))

    ; --- non-numeric arg → nil ---
    ; (nil counts as numeric — it's putnum(0).)
    (nilp (sin "x"))
    (nilp (pow "a" 1))
    (nilp (plex "x" 1))      ; plex of a non-number -> nil (so (arg (plex 1 "x")) folds to 0)

    ; --- generic over bignums: the operand widens full-magnitude (g_big_to_flo),
    ;     exactly as a scalar bignum already fed the scalar pow ---
    (= 1125899906842624.0 ((/ 1 2) 1267650600228229401496703205376))  ; sqrt(2^100) = 2^50
    (flop (pow 1267650600228229401496703205376 2))
    (? w64 (< 1e300 (pow 2 100000000000000000000)) 1)              ; f64 only -- 1e300 is inf in f32

    ; --- pow / atan2 elementwise over arrays (numpy broadcast); result is r ---
    (= r (atype (pow (arr z '(2) '(2 3)) 2)))                  ; always a float array
    (aall (= (pow (arr r '(3) '(1 2 3)) 2) (arr r '(3) '(1 4 9))))  ; array ^ scalar
    (aall (= (pow 2 (arr r '(3) '(1 2 3))) (arr r '(3) '(2 4 8))))  ; scalar ^ array
    (aall (= (pow (arr r '(3) '(1 2 3)) (arr r '(3) '(2 2 2)))      ; array ^ array
             (arr r '(3) '(1 4 9))))
    (close 1.570796326794897 (peep (arg ~((arr r '(2) '(1 0)) (arr r '(2) '(1 1)))) 1 0))
    (nilp (pow (arr r '(2) '(1 2)) "x"))                         ; array vs non-number -> nil

    ; --- bignum meets array (arithmetic): the array wins, the bignum demotes to
    ;     the array's element form -- full magnitude in a float array, low bits in
    ;     an int array (modular, so it wraps: 2^64 + 5 contributes 5). Comparison
    ;     against a bignum stays magnitude-exact -- see test/bignum.l ---
    (aall (= (+ (arr z '(2) '(1 2)) 18446744073709551621)        ; 2^64 + 5 -> low word 5
             (arr z '(2) '(6 7))))
    (< 1e19 (peep (+ (arr r '(2) '(0 0)) 18446744073709551616) 0 0))))  ; 2^64 full magnitude
