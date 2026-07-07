; hook -- install the native-creation hook: book['natjit], read by ev.l's `ala` on
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
; ai/glaze/auto.l's counted-loop path. Rides the BAKED glaze through the module books
; (the binds just below). x86-64 only.
(: assemble (holo 'assemble)                                                 ; through the module books (crew/holo/export.l,
   emit (glaze 'emit)  coreir (glaze 'coreir)  deoptir (glaze 'deoptir)     ;   ai/glaze/export.l) -- this stream cat-loads
                                                                            ;   post-boot, so nothing folded for it
   (exprn ps e) (? (member? e ps) 1  (whole? e) 1                          ; var in frame | int literal
                   (two? e) (: op (cap e)
                               (? (member? op '(+ - * // % & | ^ < <= > >= =)) (&& (exprn ps (caup e)) (exprn ps (caup (cup e))))
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
          (: _ (pin fires () (+ 1 (peep fires () 0)))                  ; compile via the neutral-IR lane (coreir); deopt target = e
             (nif (emit (peep (assemble 'x64 (coreir 'x64 ps body (deoptir 'x64 (? (= a 1) 0 1)))) 'bytes 0)) e s a))
          e))
   (fired? n) (< n (peep fires () 0))                 ; did the hook fire since count n?
 _ (assert
    ; --- embedded leaves get native-backed at creation, and compute correctly ---
    (: n (peep fires () 0)
       (&& (31 = (ev '(: f (\ x (+ (* x 3) 1)) (f 10))))            ; leaf in a let body
           (fired? n)))                                             ; ... the hook fired on it
    (9000000000000000000 = (ev '((\ x (* x x)) 3000000000)))        ; embedded leaf, applied inline -> deopt -> bignum
    (3 = (ev '(: g (\ x (cap x)) (g '(3 4)))))                      ; non-arith body -> stays bytecode, still right
    ; --- an embedded CAPTURING closure: native captured closure, transparent ---
    (: mk (ev '(\ y (\ x (+ x y))))  a5 (mk 5)                      ; inner (\ x (+ x y)) is the embedded one
       (&& (15 = (a5 10)) ('(6 7 8) = (map a5 '(1 2 3)))            ; native captured closure, composes
           (= a5 ((\ y (\ x (+ x y))) 5))))                         ; ... and = the interpreter's instance
    ; --- id? + transparency on an embedded CAPTURING leaf pulled out as a value ---
    ; (the leaf must CAPTURE (z) -- a closed leaf like (\ x (+ x 0)) hoists to a shared
    ; constant, so (id 9) twice is one object; a capturing one is allocated per call.
    (: id (ev '(\ z (\ x (+ x z))))  f (id 9)  g (id 9)            ; inner CAPTURES z -> a fresh native cell per call
       (&& (19 = (f 10)) (= f ((\ z (\ x (+ x z))) 9)) !(id? f g))) ; computes right, = the interp instance, yet distinct
   )
 _ (puts "ai/glaze/hook: ev.l ala native-backs every qualifying closure (embedded too), transparent") _ (putc 10))
