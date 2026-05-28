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
    (nilp (atan2 "x" 1))))
