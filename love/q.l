; q -- rationals: an exact field as a coin over reduced (num den)
(module 'q
(: q (: (reduce n d)
         (0 = n ? [0 1]                           ; gcd out, sign on num, den > 0
          (: g (gcd (abs n) (abs d)) s (? (d < 0) -1 1)
           [(s * n // g) (s * d // g)]))
        (parts v) (two? v ? v [v 1])                          ; a bare star is n/1
        ; the domain test is the closed star (the fixpoint minus coins): star?
        ; is open now, and an open star as an (n d) component would drag gcd
        ; off the tower it terminates on -- a coin is never a coefficient.
        (nstar? v) ((nil? * coin?) v && v = +v)
        (ok? v) (nstar? v || (two? v && all nstar? v))
        c (coin 'q (z \ {'star 1 'net 'ratio                   ; a rational is a star; C truth by value
         '+ (\ a b (: x (load a) y (load b)                    ; (n1 d1) + (n2 d2)
             (? (ok? x && ok? y)
              (: p (parts x) r (parts y)
               (z (reduce (<p * <>r + <r * <>p) (<>p * <>r)))))))
         '* (\ a b (: x (load a) y (load b)                    ; (n1 d1) * (n2 d2)
             (? (ok? x && ok? y)
              (: p (parts x) r (parts y)
               (z (reduce (<p * <r) (<>p * <>r)))))))
         '- (\ a b (: x (load a) y (load b)                    ; (n1 d1) - (n2 d2)
             (? (ok? x && ok? y)
              (: p (parts x) r (parts y)
               (z (reduce (<p * <>r - <r * <>p) (<>p * <>r)))))))
         '/ (\ a b (: x (load a) y (load b)                    ; (n1 d1) / (n2 d2): invert and
             (? (ok? x && ok? y && <y != 0)                  ; multiply; by zero -> () (no inf in Q; cap of a bare star is itself)
              (: p (parts x) r (parts y)
               (z (reduce (<p * <>r) (<>p * <r)))))))}))
        (\ n (two? n ? (c (reduce <n <>n))                    ; (q (n d)) -- the show form
                       (c * reduce n)))))                     ; (q n d) -- the ergonomic curried form

) ; module q
