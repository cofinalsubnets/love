; auto -- the transparent auto-hook: rebind `ev` so a QUALIFYING closure compiles to
; NATIVE automatically. No user-facing verb -- you call `ev` (or eval a closure) as
; always; qualifying ones are just faster, and =/show-IDENTICAL to their source.
; Everything else falls through to the base interpreter unchanged.
;
; Shapes that qualify (the emitter's grammar; E := var | int | (OP E E) | (? E E E),
; OP in + - * // % & | ^ < <= > >= =):
;   LEAF1 (\ x E)            -- E over x
;   LEAF2 (\ x y E)          -- E over x,y (currying via lvm_cur; natn)
;   LOOP  (\ n ((: (go i a) (? (< i n) (go (+ i 1) (+ a B)) a)) 0 0))  -- a native counted
;         loop summing B(i) for i<n; B in the same grammar over i. Owning the LOOP is
;         where the big win is (cf. the leaf's ~6%): the back-edge stays native.
;
; ev is 1-arg, so the loader's `(ev 'ev r)` = `((ev 'ev) r)` still works after the
; rebind; njit/njit-loop call the captured base-ev -> no jit<->ev re-entry. Load AFTER
; jit/emit.l (uses emit/cgv/ld-x/ld-i/epilogue/loopcode/nat). ⚠ x86-64.
(: base-ev ev
   ; the emitter's expression grammar over var v: var | int | arith | cmp | (? t a b)
   (exprp e v) (? (= e v)   1
                  (intp e)  1
                  (twop e)  (: op (cap e)
                               (? (memq op '(+ - * // % & | ^ < <= > >= =)) (&& (exprp (caup e) v) (exprp (caup (cup e)) v))
                                  (= op '?) (&& (twop (cup (cup (cup e)))) !(twop (cup (cup (cup (cup e)))))   ; exactly 3 operands
                                               (exprp (caup e) v) (exprp (caup (cup e)) v) (exprp (caup (cup (cup e))) v))
                                  0))
                  0)
   ; --- leaf: (\ x E) ---
   (qual lam) (&& (twop lam) (= (cap lam) '\) (twop (cup lam)) (= (caup lam) 'x)
                  (twop (cup (cup lam))) !(twop (cup (cup (cup lam)))) (exprp (caup (cup lam)) 'x))
   ; --- arity-2 leaf: (\ x y E), E over {x,y} ---
   (expr2 e) (? (= e 'x) 1 (= e 'y) 1 (intp e) 1
                (twop e) (: op (cap e)
                            (? (memq op '(+ - * // % & | ^ < <= > >= =)) (&& (expr2 (caup e)) (expr2 (caup (cup e))))
                               (= op '?) (&& (twop (cup (cup (cup e)))) !(twop (cup (cup (cup (cup e)))))
                                            (expr2 (caup e)) (expr2 (caup (cup e))) (expr2 (caup (cup (cup e)))))
                               0))
                0)
   (qual2 lam) (&& (twop lam) (= (cap lam) '\) (twop (cup lam)) (= (caup lam) 'x)
                   (twop (cup (cup lam))) (= (caup (cup lam)) 'y)
                   (twop (cup (cup (cup lam)))) !(twop (cup (cup (cup (cup lam)))))   ; exactly (\ x y body)
                   (expr2 (caup (cup (cup lam)))))
   (njit lam) (nat (emit (cat (cgv 'x ld-x (caup (cup lam))) epilogue)) (base-ev lam) lam)
   ; --- loop: match the tail-recursive counted-sum skeleton, extract (B counter) ---
   (loopinfo lam)
    (: M    (caup (cup lam))                                ; lambda body
       S    (cap M)   z1 (caup M)   z2 (caup (cup M))       ; M = (S 0 0)
       G    (caup S)  IF (caup (cup S))                     ; S = (: (go i a) IF)
       GO   (cap G)   I (caup G)    A (caup (cup G))        ; (go i a)
       T    (caup IF) THEN (caup (cup IF)) ELS (caup (cup (cup IF)))   ; (? T THEN ELS)
       STEP (caup THEN) ACC (caup (cup THEN))               ; THEN = (go STEP ACC)
       B    (caup (cup ACC))                                ; ACC = (+ a B)
       ok (&& (twop lam) (= (cap lam) '\) (symp (caup lam))                  ; (\ N ..)
              (twop (cup (cup lam))) !(twop (cup (cup (cup lam))))           ; one body
              (twop M) (= z1 0) (= z2 0) !(twop (cup (cup (cup M))))         ; (S 0 0)
              (twop S) (= (cap S) ':) (symp GO) (symp I) (symp A) !(= I A)   ; (: (go i a) IF)
              (twop IF) (= (cap IF) '?) (= ELS A)                            ; (? .. .. a)
              (twop T) (= (cap T) '<) (= (caup T) I) (= (caup (cup T)) (caup lam))  ; (< i n)
              (= (cap THEN) GO)                                              ; (go ..)
              (twop STEP) (= (cap STEP) '+) (= (caup STEP) I) (= (caup (cup STEP)) 1)  ; (+ i 1)
              (twop ACC) (= (cap ACC) '+) (= (caup ACC) A) (exprp B I))      ; (+ a B), B in the grammar over i
       (? ok (L B I) 0))
   (njit-loop lam B cv) (nat (emit (loopcode B cv)) (base-ev lam) lam)
   ; COMPILE CACHE: each source \-expr compiles ONCE (no re-mmap on repeated ev).
   ; Keyed by source -- structurally-equal closures share the same native (sound:
   ; they are =). The transparent form of a hot-trigger: an execution-count trigger
   ; would need a counting wrapper, but a wrapper is not =/show its source; so the
   ; trigger is "compile on first request, cached after". Loops stay eager (their
   ; one application is internally hot). ⚠ pins natives (+ W^X arenas) for the run.
   cache (tablet 0)
   (memo e mk) (: g (peep cache e 0) (? g g (: h (mk e) _ (pin cache e h) h)))
   (auto-ev e) (? (qual e)  (memo e njit)
                  (qual2 e) (memo e jit2)
                  (: li (loopinfo e) (? li (memo e (\ l (njit-loop l (cap li) (caup li)))) (base-ev e))))
   ev auto-ev                                                  ; rebind the global: ev is now auto-native
 _ (assert
    ((\ x (+ (* x 2) 3)) = (ev '(\ x (+ (* x 2) 3))))          ; leaf: native, =-identical
    (23 = ((ev '(\ x (+ (* x 2) 3))) 10))
    (3 = ((ev '(\ x (cap x))) '(3 4)))                         ; non-qualifying -> interpreter
    (6 = (ev '(+ 1 2 3)))                                      ; non-lambda forms unaffected
    (9000000000000000000 = ((ev '(\ x (* x x))) 3000000000))   ; overflow deopts -> bignum
    (: ab (ev '(\ x (? (< x 0) (- 0 x) x))) (&& (7 = (ab -7)) (7 = (ab 7))))   ; conditional leaf auto-natived
    ; LOOP auto-detected -> native counted loop, =-identical + correct
    (: L1 '(\ n ((: (go i a) (? (< i n) (go (+ i 1) (+ a (* i 7))) a)) 0 0))
       f  (ev L1)
       (&& (= f (ev L1)) (3496500 = (f 1000)) (lamp (loopinfo L1))))
    ; LOOP with a conditional body (sum i for i<50, capped) auto-detected
    (: L2 '(\ n ((: (go i a) (? (< i n) (go (+ i 1) (+ a (? (< i 50) i 0))) a)) 0 0))
       h  (ev L2)  c ((: (go i a) (? (< i 1000) (go (+ i 1) (+ a (? (< i 50) i 0))) a)) 0 0)
       (&& (lamp (loopinfo L2)) (= c (h 1000))))
    (idp (ev L1) (ev L1))                                       ; CACHE: same source -> same native (compiled once)
    (idp (ev '(\ x (+ x 1))) (ev '(\ x (+ x 1))))
    (: ad (ev '(\ x y (+ (* x x) y))) (&& (13 = (ad 3 4)) (13 = ((ad 3) 4)) ((\ x y (+ (* x x) y)) = ad))))  ; 2-arg leaf auto-natived
 _ (puts "jit/auto: ev auto-natives qualifying closures + counted loops (transparent)") _ (putc 10))
