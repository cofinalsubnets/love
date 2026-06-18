; hook -- install the native-creation hook: bag['natjit], read by ev.l's `ala` on
; EVERY closure built, top-level AND embedded in a fn/let body (the reach the ev-rebind
; in ai/glaze/auto.l never had -- it only saw the form handed to `ev`). A qualifying leaf (the
; emit grammar over its frame [imps args]) is native-backed AT CREATION and DEOPTS into
; the closure's own bytecode `e` on overflow -- so native is never wrong, just faster.
;
; Why this is safe where the source-rewrite jit-walk wasn't:
;  * transparent -- the native cell keeps value[-1]=s (the surface src), so =/show see
;    the source; the enclosing closure's src is never rewritten.
;  * id?-distinct -- a fresh native cell per `ala` call (no compile cache), exactly like
;    bytecode closures: !(id? (\ x E) (\ x E)) holds.
;  * macro-safe -- compiles the SURFACE body `(last (cup s))` (post-opfix, pre-tag), so
;    iop/apx tags never reach codegen; a macro/non-arith body simply fails the grammar
;    and stays bytecode.
;  * no double-compile -- the deopt target is `e` itself (the bytecode closure ala built),
;    passed as nat/natn's `interp`; no separate (ev lam) pass.
; Loops are NOT caught here (their body isn't leaf-grammar) -- they stay bytecode, or use
; ai/glaze/auto.l's counted-loop path. Load AFTER ai/glaze/emit.l (uses cgn/emit/nat/natn/epilogue/
; epilogue-mn). x86-64 only.
(: (exprn ps e) (? (has? e ps) 1  (whole? e) 1                          ; var in frame | int literal
                   (two? e) (: op (cap e)
                               (? (has? op '(+ - * // % & | ^ < <= > >= =)) (&& (exprn ps (caup e)) (exprn ps (caup (cup e))))
                                  (= op '?) (&& (two? (cup (cup (cup e)))) !(two? (cup (cup (cup (cup e)))))
                                               (exprn ps (caup e)) (exprn ps (caup (cup e))) (exprn ps (caup (cup (cup e)))))
                                  0))
                   0)
   fires #0                                          ; a probe: how many closures the hook native-backed
   ; natjit e s a -- e = the bytecode entry (deopt target), s = (\ frame.. body) the
   ; surface src, a = arity. ps = (init (cup s)) = the frame [imps args]; body = the
   ; surface body. compile body over ps; deopt -> e. non-qualifying -> e unchanged.
   (natjit e s a)
    (: ps (init (cup s))  body (last (cup s))
       (? (&& (two? s) (two? (cup (cup s))) (exprn ps body))         ; >=1 param, a body, leaf grammar
          (: _ (pin fires 0 (+ 1 (peep fires 0 0)))
             (? (= a 1) (nat  (emit (cat (cgv (cap ps) (\ d (fxv 0 d)) body 0) epilogue))    e s)  ; arity 1 -> nat (deopt to e value[0])
                        (natn (emit (cat (cgn ps body 0) epilogue-mn)) e s a))) ; arity>=2 -> natn (deopt to e body)
          e))
   (fired? n) (< n (peep fires 0 0))                 ; did the hook fire since count n?
 _ (assert
    ; --- embedded leaves get native-backed at creation, and compute correctly ---
    (: n (peep fires 0 0)
       (&& (31 = (ev '(: f (\ x (+ (* x 3) 1)) (f 10))))            ; leaf in a let body
           (fired? n)))                                             ; ... the hook fired on it
    (9000000000000000000 = (ev '((\ x (* x x)) 3000000000)))        ; embedded leaf, applied inline -> deopt -> bignum
    (3 = (ev '(: g (\ x (cap x)) (g '(3 4)))))                      ; non-arith body -> stays bytecode, still right
    ; --- an embedded CAPTURING closure: native captured closure, transparent ---
    (: mk (ev '(\ y (\ x (+ x y))))  a5 (mk 5)                      ; inner (\ x (+ x y)) is the embedded one
       (&& (15 = (a5 10)) ('(6 7 8) = (map a5 '(1 2 3)))            ; native captured closure, composes
           (= a5 ((\ y (\ x (+ x y))) 5))))                         ; ... and = the interpreter's instance
    ; --- transparency + id? on an embedded leaf pulled out as a value ---
    (: id (ev '(\ z (\ x (+ x 0))))  f (id 9)  g (id 9)            ; two instances of the same embedded source
       (&& ((\ x (+ x 0)) = f) !(id? f g)))                         ; =/show its source, yet distinct objects
   )
 _ (puts "ai/glaze/hook: ev.l ala native-backs every qualifying closure (embedded too), transparent") _ (putc 10))
