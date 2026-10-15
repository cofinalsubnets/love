; test/uuspllaw.l -- the splice license, proved forall states of uusplgen.l's terms
; the observation carries a trace: an effectful arg read twice doubles it unseen by value.
(test (elem 'vof (names ())) (two? (peep GLOB 'srun 0)) (two? (peep GLOB 'sp0call 0)))

; --- the license: the splice observes as the call, value and trace, forall states ---
(test
 (defq sl-lic-0
   (pi A hst (pi S hst (pi L hst (pi E hst (pi T hst
      (paths nat (stos (srun sp0bind A (smk S 0 L E T 0)))
                 (stos (srun sp0call A (smk S 0 L E T 0)))))))))
   (lam A (lam S (lam L (lam E (lam T (idpath (stos (srun sp0bind A (smk S 0 L E T 0))))))))))
 (defq sl-lic-1
   (pi A hst (pi S hst (pi L hst (pi E hst (pi T hst
      (paths nat (stos (srun sp1bind A (smk S 0 L E T 0)))
                 (stos (srun sp1call A (smk S 0 L E T 0)))))))))
   (lam A (lam S (lam L (lam E (lam T (idpath (stos (srun sp1bind A (smk S 0 L E T 0))))))))))
 (defq sl-lic-1t
   (pi A hst (pi S hst (pi L hst (pi E hst (pi T hst
      (paths nat (strn (srun sp1bind A (smk S 0 L E T 0)))
                 (strn (srun sp1call A (smk S 0 L E T 0)))))))))
   (lam A (lam S (lam L (lam E (lam T (idpath 1)))))))
 (defq sl-lic-1e
   (pi A hst (pi S hst (pi L hst (pi E hst (pi T hst
      (paths nat (strat 0 (srun sp1bind A (smk S 0 L E T 0))) (A 0)))))))
   (lam A (lam S (lam L (lam E (lam T (idpath (A 0)))))))))

; --- order: the arg's effect precedes the body's, call and splice alike ---
(test
 (defq sl-ord-bind
   (pi A hst (pi S hst (pi L hst (pi E hst (pi T hst
      (paths nat (strat 0 (srun sp3bind A (smk S 0 L E T 0))) (A 0)))))))
   (lam A (lam S (lam L (lam E (lam T (idpath (A 0))))))))
 (defq sl-ord-bind2
   (pi A hst (pi S hst (pi L hst (pi E hst (pi T hst
      (paths nat (strat 1 (srun sp3bind A (smk S 0 L E T 0))) 5))))))
   (lam A (lam S (lam L (lam E (lam T (idpath 5)))))))
 (defq sl-ord-call
   (pi A hst (pi S hst (pi L hst (pi E hst (pi T hst
      (paths nat (strat 0 (srun sp3call A (smk S 0 L E T 0))) (A 0)))))))
   (lam A (lam S (lam L (lam E (lam T (idpath (A 0)))))))))

; --- the flip: an effectful arg read twice keeps the value, doubles the trace ---
(test
 (defq sl-flip-value
   (pi A hst (pi S hst (pi L hst (pi E hst (pi T hst
      (paths nat (stos (srun sp2subst A (smk S 0 L E T 0)))
                 (stos (srun sp2bind A (smk S 0 L E T 0)))))))))
   (lam A (lam S (lam L (lam E (lam T (idpath (stos (srun sp2bind A (smk S 0 L E T 0))))))))))
 (defq sl-flip-bind
   (pi A hst (pi S hst (pi L hst (pi E hst (pi T hst
      (paths nat (strn (srun sp2bind A (smk S 0 L E T 0))) 1))))))
   (lam A (lam S (lam L (lam E (lam T (idpath 1)))))))
 (defq sl-flip-subst
   (pi A hst (pi S hst (pi L hst (pi E hst (pi T hst
      (paths nat (strn (srun sp2subst A (smk S 0 L E T 0))) 2))))))
   (lam A (lam S (lam L (lam E (lam T (idpath 2))))))))

; --- the pure face: an effect-free arg substitutes as the call, value and trace ---
(test
 (defq sl-sub-0
   (pi A hst (pi S hst (pi L hst (pi E hst (pi T hst
      (paths nat (stos (srun sp0subst A (smk S 0 L E T 0)))
                 (stos (srun sp0call A (smk S 0 L E T 0)))))))))
   (lam A (lam S (lam L (lam E (lam T (idpath (stos (srun sp0subst A (smk S 0 L E T 0))))))))))
 (defq sl-sub-0t
   (pi A hst (pi S hst (pi L hst (pi E hst (pi T hst
      (paths nat (strn (srun sp0subst A (smk S 0 L E T 0)))
                 (strn (srun sp0call A (smk S 0 L E T 0)))))))))
   (lam A (lam S (lam L (lam E (lam T (idpath (strn (srun sp0subst A (smk S 0 L E T 0))))))))))
 ; the read-once face: one effectful arg read once still observes as the call
 (defq sl-sub-1
   (pi A hst (pi S hst (pi L hst (pi E hst (pi T hst
      (paths nat (stos (srun sp1subst A (smk S 0 L E T 0)))
                 (stos (srun sp1call A (smk S 0 L E T 0)))))))))
   (lam A (lam S (lam L (lam E (lam T (idpath (stos (srun sp1subst A (smk S 0 L E T 0))))))))))
 (defq sl-sub-1t
   (pi A hst (pi S hst (pi L hst (pi E hst (pi T hst
      (paths nat (strn (srun sp1subst A (smk S 0 L E T 0)))
                 (strn (srun sp1call A (smk S 0 L E T 0)))))))))
   (lam A (lam S (lam L (lam E (lam T (idpath 1)))))))
 (defq sl-sub-1e
   (pi A hst (pi S hst (pi L hst (pi E hst (pi T hst
      (paths nat (strat 0 (srun sp1subst A (smk S 0 L E T 0))) (A 0)))))))
   (lam A (lam S (lam L (lam E (lam T (idpath (A 0)))))))))

; --- one source (y + 1): the stack splice meets the register de5bck, forall states ---
(test
 (defq sl-cross
   (pi v nat (pi A hst (pi S hst (pi L hst (pi E hst (pi T hst
      (pi R hst (pi F hst (pi K hst
        (paths nat
          (stos (srun sp0bind (hupd 0 v A) (smk S 0 L E T 0)))
          (mrg (drun de5bck (mmk (hupd 9 v R) F K 0)) 0)))))))))))
   (lam v (lam A (lam S (lam L (lam E (lam T (lam R (lam F (lam K
      (idpath (stos (srun sp0bind (hupd 0 v A) (smk S 0 L E T 0)))))))))))))))
