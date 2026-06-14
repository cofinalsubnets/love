; ============================================================================
; jit/opjit.l -- the PRODUCTION hook, baked into opfix. Installs a native-codegen
; pass at book['opjit]; the opfix wrapper (love/prelude.l) applies it after
; factoring, so EVERY form compiled -- through c0 AND the self-hosted wev -- gets
; its qualifying lambdas turned native. No ev redefinition (cf. jit/auto.l); the
; compiler itself does it.
;
; Load after jit/kernel.l on an x86_64 host (it reuses kernel.l's arithp + jit):
;
;     make host
;     out/host/love -l jit/kernel.l jit/opjit.l
;
; WHY THIS IS GATE-SAFE: book['opjit] is DORMANT in the shipped image -- opfix's
; (peep book 'opjit 0) is 0 until something installs it, and the gate never does,
; so the bootstrap is byte-identical. This file is the x86_64 installer; the
; codegen is x86-only, so it lives here, not in the portable prelude.
;
; THE SEAM: a top-level (: opjit jit-walk) lands in the `book` tablet via defglob
; (lvm_defglob pins symbol->value into g->book), which is exactly the tablet
; opfix captured at bake -- so its (peep book 'opjit 0) reads what we install,
; even though the global NAME `book` was pulled at birth.

(: jstat (tablet 0) (njit _) (peep jstat 0 0))   ; count jitted lambdas (proof the hook fired)

; RE-ENTRY GUARD: jit (kernel.l) computes its VM fallback via (ev lam), which now
; re-enters opfix -> opjit -> jit-walk on the SAME lambda -> jit -> (ev lam) ...
; an infinite loop. While inside a jit, jguard is 1 and jit-walk leaves forms
; verbatim, so the fallback (ev lam) compiles the plain VM closure.
(: jguard (tablet 0))

(: (qual e)                                      ; a (\ p <arith>) / (\ p q <arith>) jit can compile
   (&& (twop e) (idp (cap e) '\)
       (: rest (cup e) body (last rest) ps (init rest) n (tally ps)
          (&& (|| (= n 1) (= n 2)) (all symp ps) (arithp body ps)))))

(: (jit-walk e)                                  ; the book['opjit] pass: source -> source
   (? (peep jguard 0 0) e                        ; re-entrant (a jit's fallback compile): leave verbatim
      !(twop e) e
      (qual e) (: _ (pin jguard 0 1) c (jit e) _ (pin jguard 0 0)
                   _ (pin jstat 0 (+ 1 (peep jstat 0 0))) (list '\ c))   ; (\ p arith) -> (\ <native closure>)
      (: h (cap e)
       (? (idp h '\) e          ; any other \-form (quote / non-qual lambda): leave ENTIRELY --
                                ; never rewrite a lambda body, else the enclosing lambda's stashed
                                ; \-expr changes, breaking its show (de Bruijn) and = (salpha)
          (idp h 'qq) e                          ; quasiquote: DATA, leave
          (idp h '::) e                          ; macro def: leave
          (map jit-walk e)))))                   ; application / : / ? : walk every element

; INSTALL: pin jit-walk at book['opjit]. opfix is dormant until this line runs.
(: opjit jit-walk)

; ============================================================================
; PROOF -- these forms are compiled by the now-armed opfix, so their lambdas are
; jitted with no (jit ...) and no ev redefinition: the COMPILER did it.
(: sq (\ x (* x x)))                             ; 1-arg
(: hyp (\ a b (+ (* a a) (* b b))))              ; 2-arg via call2
(: even? (\ x (< (% x 2) 1)))                    ; composed % then <
(: hof (foldl (+) 0 (map (\ k (* k k)) (jot 5))))   ; lambda jitted in ARGUMENT position
(: infix (\ x (x * x)))                          ; INFIX arith -- op-core factors it BEFORE opjit sees it
(: _ (dot (+ "lambdas jitted via the opfix hook: " (+ (show (njit 0)) "\n")))   ; sq hyp even? hof's k infix = 5
   _ (dot (+ "sq 12       = " (+ (show (sq 12)) "   (== 144)\n")))
   _ (dot (+ "hyp 3 4     = " (+ (show (hyp 3 4)) "   (== 25)\n")))
   _ (dot (+ "even? 8     = " (+ (show (even? 8)) "   (== 1)\n")))
   _ (dot (+ "infix 9     = " (+ (show (infix 9)) "   (== 81, infix factored then jitted)\n")))
   _ (dot (+ "sq 4e9      = " (+ (show (sq 4000000000)) "   (bignum via bail)\n")))
   _ (dot (+ "map-sum jot5= " (+ (show hof) "   (== 30)\n")))
   ; SAFETY: ordinary code compiled under the armed hook still computes correctly
   _ (dot (+ "safety foldl= " (+ (show (foldl (+) 0 (jot 100))) "   (== 4950)\n")))
   _ (dot (+ "safety sort = " (+ (show (sort '(3 1 2))) "   (== (1 2 3))\n")))
   _ (dot (+ "safety quote= " (+ (show '(\ x (* x x))) "   (DATA, NOT jitted)\n")))
   _ (dot (? (= 81 (infix 9)) (? (= 25 (hyp 3 4)) (? (= 144 (sq 12)) (? (= 30 hof)
        (? (= 4950 (foldl (+) 0 (jot 100))) "ALL PASS\n" "FAIL foldl") "FAIL hof") "FAIL sq") "FAIL hyp") "FAIL infix")))
