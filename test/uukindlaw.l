; test/uukindlaw.l -- the kinds-lattice join laws, proved of the generated kjoin
; (test/uukind.l), exhaustively over the finite carrier uk-codes.
; guard: the kernel must load first; a locale-sorted glob would run these against none.
(test (elem 'vof (names ())))
(:
   (uk-jj a b) (vof 0 ['kjoin a b])                      ; kjoin a b, run in the kernel
   (uk-all f)  (foldl (acc \ x \ acc && f x) 1 uk-codes) ; forall over the carrier
   (uk-all2 f) (uk-all (a \ uk-all (b \ f a b)))
   (uk-all3 f) (uk-all (a \ uk-all (b \ uk-all (c \ f a b c))))
   ; codes read back by name, never by position in the carrier
   uk-bot (vof 0 'ukbot) uk-top (vof 0 'uktop)
   uk-str (vof 0 'ukstr) uk-charm (vof 0 'ukcharm))

(test
 ; --- a bounded join-semilattice, exhaustively over uk-codes ---
 (uk-all  (a \ uk-jj a a = a))                                            ; idempotent
 (uk-all2 (a \ b \ uk-jj a b = uk-jj b a))                                ; commutative
 (uk-all3 (a \ b \ c \ uk-jj (uk-jj a b) c = uk-jj a (uk-jj b c)))        ; associative
 (uk-all  (a \ (uk-jj uk-bot a = a) && (uk-jj a uk-bot = a)))             ; bot the identity
 (uk-all  (a \ (uk-jj uk-top a = uk-top) && (uk-jj a uk-top = uk-top)))   ; top absorbs
 ; --- str is incomparable: it joins any numeric up to top ---
 (vof 0 '(numq ukstr) = vof 0 'false)   ; str is not numeric
 (uk-jj uk-str uk-charm = uk-top))      ; str `join` charm = top, not str

; --- kinds.l's four driver cases as idpath lemmas, exported with the corpus ---
(test
 (defq kjoin-tier-wins  (paths nat (kjoin ukcharm ukcplx) ukcplx) (idpath ukcplx)) ; A. higher tier wins
 (defq kjoin-bot-unit   (paths nat (kjoin ukbot ukreal) ukreal)   (idpath ukreal)) ; B. bot is the unit
 (defq kjoin-top-cap    (paths nat (kjoin ukcplx uktop) uktop)    (idpath uktop))  ; C. top caps the spine
 (defq kjoin-str-widens (paths nat (kjoin ukstr ukcharm) uktop)   (idpath uktop))) ; D. str widens to top
