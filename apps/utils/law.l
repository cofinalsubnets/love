; apps/utils/law.l -- the myers laws, held by assertion: the two projections (the script
; spells both sides), MINIMALITY against an O(nm) LCS oracle (dcost = n + m - 2*lcs), and
; a seeded fuzz over both. reads the leaked globals from apps/utils/diff.l (concatenate:
; `cat test/00-init.l apps/utils/diff.l apps/utils/law.l | ai`, the `make test_utils` gate).

; --- the classic: Myers' own worked example, D = 5 ---
(: A '(a b c a b b a) B '(c b a b a c) s (myers A B)
   (assert
      (= (dold s) A) (= (dnew s) B)                         ; the script spells both sides
      (= (dcost s) 5)))                                     ; the paper's shortest path

; --- the edges: empties, equal, disjoint, a lone keep ---
(: s1 (myers () '(1 2)) s2 (myers '(1 2) ()) s3 (myers '(1 2 3) '(1 2 3)) s4 (myers '(1 2) '(3 4))
   (assert
      (! (myers () ()))                                     ; nothing to nothing is nothing
      (= (dnew s1) '(1 2)) (! (dold s1)) (= (dcost s1) 2)   ; all adds
      (= (dold s2) '(1 2)) (! (dnew s2)) (= (dcost s2) 2)   ; all dels
      (= (dold s3) '(1 2 3)) (= (dnew s3) '(1 2 3)) (= (dcost s3) 0)   ; equal: all keeps
      (= (dcost s4) 4)                                      ; disjoint: total replacement
      (= (myers '(1) '(1)) '((keep 1)))
      (= (dcost (myers '(a) '(b))) 2)
      (= (dcost (myers '(x a b c) '(a b c y))) 2)))         ; one del + one add around the shared run

; --- the oracle + the seeded fuzz: dcost must equal n + m - 2*lcs on random lists, and
; the projections must spell the inputs back -- minimal AND valid, every draw ---
(: (lcslen a b)
    (: ax (dindex a) bx (dindex b) n (tally a) m (tally b)
       t (tablet 0)
       (get i j) (? (|| (< i 1) (< j 1)) 0 (peep t (+ (* i 4096) j) 0))
       (goj i j) (? (< m j) ()
                    (: v (? (= (ax (- i 1)) (bx (- j 1))) (+ 1 (get (- i 1) (- j 1)))
                            (: u (get (- i 1) j) w (get i (- j 1)) (? (< u w) w u)))
                       _ (pin t (+ (* i 4096) j) v)
                       (goj i (+ j 1))))
       (goi i) (? (< n i) (get n m) (: _ (goj i 1) (goi (+ i 1))))
       (goi 1))
   (rlist i st acc) (? (< i 1) (L acc st)                   ; a random list over the alphabet 1..4; answers (list state)
                       (: r (random st 4) (rlist (- i 1) (cup r) (link (+ 1 (cap r)) acc))))
   (fz i st)
    (? (< i 1) 'ok
       (: r1 (random st 8) r2 (random (cup r1) 8)
          la (rlist (cap r1) (cup r2) ())
          lb (rlist (cap r2) (caup la) ())
          a (cap la) b (cap lb)
          s (myers a b)
          ok (&& (= (dold s) a) (= (dnew s) b)
                 (= (dcost s) (- (+ (tally a) (tally b)) (* 2 (lcslen a b)))))
          (? ok (fz (- i 1) (caup lb)) (L 'broke a b))))
   r (fz 100 (seed 7))
   (assert (= r 'ok)))

(say err "apps/utils/law: myers diff -- projections + minimality (lcs oracle) + seeded fuzz ok
")
