; auto -- the transparent auto-hook: rebind `ev` so a QUALIFYING closure compiles to
; NATIVE automatically. No user-facing verb -- you call `ev` (or eval a closure) as
; always; qualifying ones are just faster, and =/show-IDENTICAL to their source.
; Everything else falls through to the base interpreter unchanged. This is the last
; brick of "ev but faster": `nat`/`jit` are no longer touched by hand.
;
; ev is 1-arg, so the loader's `(ev 'ev r)` is `((ev 'ev) r)` -- it re-reads ev and
; applies it, so rebinding ev is picked up (and `(auto-ev 'ev)` just yields the new
; ev, then runs r). njit calls the CAPTURED base-ev (never auto-ev) -> no jit<->ev
; re-entry. Load AFTER jit/emit.l (uses emit/cgv/ld-x/epilogue/nat). ⚠ x86-64; arith
; (\ x E) only for now (loops/captures/multi-arg are the emitter's next grammar).
(: base-ev ev
   (arithp e) (? (= e 'x)   1
                 (intp e)   1
                 (twop e)   (&& (memq (cap e) '(+ - *)) (arithp (caup e)) (arithp (caup (cup e))))
                 0)
   (qual lam) (&& (twop lam) (= (cap lam) '\)                 ; (\ ...
                  (twop (cup lam)) (= (caup lam) 'x)          ;    x ...
                  (twop (cup (cup lam))) !(twop (cup (cup (cup lam))))   ; exactly one body
                  (arithp (caup (cup lam))))                  ; body in the arith grammar
   (njit lam) (nat (emit (cat (cgv 'x ld-x (caup (cup lam))) epilogue)) (base-ev lam) lam)
   (auto-ev e) (? (qual e) (njit e) (base-ev e))
   ev auto-ev                                                  ; rebind the global: ev is now auto-native
 _ (assert
    ((\ x (+ (* x 2) 3)) = (ev '(\ x (+ (* x 2) 3))))          ; ev of a qualifying lambda is native, =-identical
    (23 = ((ev '(\ x (+ (* x 2) 3))) 10))                      ; ... and runs
    (3 = ((ev '(\ x (cap x))) '(3 4)))                         ; non-qualifying -> base interpreter, still right
    (6 = (ev '(+ 1 2 3)))                                      ; non-lambda forms unaffected
    (9000000000000000000 = ((ev '(\ x (* x x))) 3000000000)))  ; overflow deopts -> correct bignum
 _ (puts "jit/auto: ev auto-natives qualifying closures (transparent)") _ (putc 10))
