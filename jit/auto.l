; auto -- the transparent auto-hook: rebind `ev` so a QUALIFYING closure compiles to
; NATIVE automatically. No user-facing verb -- you call `ev` (or eval a closure) as
; always; qualifying ones are just faster, and =/show-IDENTICAL to their source.
; Everything else falls through to the base interpreter unchanged.
;
; Two shapes qualify (the emitter's grammar):
;   LEAF  (\ x E)   E := x | int | (+/-/* E E) | (cmp E E) | (? E E E), cmp in < <= > >= =
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
                               (? (memq op '(+ - * < <= > >= =)) (&& (exprp (caup e) v) (exprp (caup (cup e)) v))
                                  (= op '?) (&& (twop (cup (cup (cup e)))) !(twop (cup (cup (cup (cup e)))))   ; exactly 3 operands
                                               (exprp (caup e) v) (exprp (caup (cup e)) v) (exprp (caup (cup (cup e))) v))
                                  0))
                  0)
   ; --- leaf: (\ x E) ---
   (qual lam) (&& (twop lam) (= (cap lam) '\) (twop (cup lam)) (= (caup lam) 'x)
                  (twop (cup (cup lam))) !(twop (cup (cup (cup lam)))) (exprp (caup (cup lam)) 'x))
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
   (auto-ev e) (? (qual e) (njit e)
                  (: li (loopinfo e) (? li (njit-loop e (cap li) (caup li)) (base-ev e))))
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
       (&& (lamp (loopinfo L2)) (= c (h 1000)))))
 _ (puts "jit/auto: ev auto-natives qualifying closures + counted loops (transparent)") _ (putc 10))
