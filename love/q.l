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
        st {0 'q 7 1 6 2}                                       ; slot 7: a rational is a star;
                                                                ; slot 6 mode 2: C truth by VALUE
        ; the four methods land in one `pins` (the mutable-accumulator twin of {..}) -- but as a
        ; separate step, not folded into the literal above: a method names `st` back, and binding a
        ; die that references itself compiles here yet fails in the love0 lane ((q 1 2) + (q 1 3)
        ; came out unequal to (q 5 6)). bind the die, then pin onto it. 1 + / 2 * / 5 - / 8 /.
        _ (pins st
         1 (\ a b (: x (load a) y (load b)                  ; (n1 d1) + (n2 d2)
            (? (ok? x && ok? y)
             (: p (parts x) r (parts y)
              (coin st (reduce (<p * <>r + <r * <>p) (<>p * <>r)))))))
         2 (\ a b (: x (load a) y (load b)                  ; (n1 d1) * (n2 d2)
            (? (ok? x && ok? y)
             (: p (parts x) r (parts y)
              (coin st (reduce (<p * <r) (<>p * <>r)))))))
         5 (\ a b (: x (load a) y (load b)                  ; (n1 d1) - (n2 d2)
            (? (ok? x && ok? y)
             (: p (parts x) r (parts y)
              (coin st (reduce (<p * <>r - <r * <>p) (<>p * <>r)))))))
         8 (\ a b (: x (load a) y (load b)                  ; (n1 d1) / (n2 d2): invert and
            (? (ok? x && ok? y && <y != 0)                ; multiply; by zero -> () (no inf in Q; cap of a bare star is itself)
             (: p (parts x) r (parts y)
              (coin st (reduce (<p * <>r) (<>p * <r))))))))
        (\ n (two? n ? (coin st (reduce <n <>n))              ; (q (n d)) -- the show form
                       (coin st * reduce n)))))               ; (q n d) -- the ergonomic curried form

) ; module q
