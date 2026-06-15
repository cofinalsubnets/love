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
   ; --- arity-2 leaf: (\ p0 p1 E), E over {p0,p1} (any distinct symbols) ---
   (expr2 e v0 v1) (? (= e v0) 1 (= e v1) 1 (intp e) 1
                      (twop e) (: op (cap e)
                                  (? (memq op '(+ - * // % & | ^ < <= > >= =)) (&& (expr2 (caup e) v0 v1) (expr2 (caup (cup e)) v0 v1))
                                     (= op '?) (&& (twop (cup (cup (cup e)))) !(twop (cup (cup (cup (cup e)))))
                                                  (expr2 (caup e) v0 v1) (expr2 (caup (cup e)) v0 v1) (expr2 (caup (cup (cup e))) v0 v1))
                                     0))
                      0)
   (qual2 lam) (: p0 (caup lam) p1 (caup (cup lam))
                  (&& (twop lam) (= (cap lam) '\) (twop (cup lam)) (symp p0)
                      (twop (cup (cup lam))) (symp p1) !(= p0 p1)
                      (twop (cup (cup (cup lam)))) !(twop (cup (cup (cup (cup lam)))))   ; exactly (\ p0 p1 body)
                      (expr2 (caup (cup (cup lam))) p0 p1)))
   (njit lam) (nat (emit (cat (cgv 'x ld-x (caup (cup lam)) 0) epilogue)) (base-ev lam) lam)
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
   ; --- captured-closure CONSTRUCTOR (\ p (\ q E)): a nest of 1-arg lambdas, E over
   ; {p,q}. Compiled as the flat 2-param native (\ p q E); applying it to p yields a
   ; native CAPTURED closure -- fully transparent (= the interpreter's ((2param) p)
   ; partial form: native captures via partial-apply are =/show-identical to interp).
   ; The constructor itself normalizes to the flat 2-param (a curry-equivalent form).
   (qualc lam) (: p (caup lam)  inner (? (twop (cup lam)) (caup (cup lam)) 0)
                  (&& (twop lam) (= (cap lam) '\) (twop (cup lam)) (symp p)
                      (twop (cup (cup lam))) !(twop (cup (cup (cup lam))))               ; (\ p INNER), one body
                      (twop inner) (= (cap inner) '\) (twop (cup inner)) (symp (caup inner)) !(= p (caup inner))
                      (twop (cup (cup inner))) !(twop (cup (cup (cup inner))))            ; INNER = (\ q E), q != p
                      (expr2 (caup (cup inner)) p (caup inner))))
   (flatc lam) (: inner (caup (cup lam)) (L '\ (caup lam) (caup inner) (caup (cup inner))))  ; (\ p (\ q E)) -> (\ p q E)
   ; COMPILE CACHE: each source \-expr compiles ONCE (no re-mmap on repeated ev).
   ; Keyed by source -- structurally-equal closures share the same native (sound:
   ; they are =). The transparent form of a hot-trigger: an execution-count trigger
   ; would need a counting wrapper, but a wrapper is not =/show its source; so the
   ; trigger is "compile on first request, cached after". Loops stay eager (their
   ; one application is internally hot). ⚠ pins natives (+ W^X arenas) for the run.
   cache (tablet 0)
   (memo e mk) (: g (peep cache e 0) (? g g (: h (mk e) _ (pin cache e h) h)))
   ; auto-ev: a WHOLE-FORM lambda -> native (cached), else the base interpreter. (The
   ; creation hook -- rewriting embedded lambdas via a jit-walk -- was tried and pulled:
   ; it's pre-macroexpansion so it can disturb a macro/quasiquote's data args, AND the
   ; compile cache makes structurally-equal closures idp-IDENTICAL, breaking love's
   ; equal-but-distinct closure semantics (!(idp (\ x E) (\ x E))). A safe creation hook
   ; needs the POST-macro opfix seam + a CODE cache (distinct cells per instance). Future.)
   (auto-ev e) (? (qual e)  (memo e njit)
                  (qual2 e) (memo e jit2)
                  (qualc e) (memo e (\ l (jit2 (flatc l))))
                  (: li (loopinfo e) (? li (memo e (\ l (njit-loop l (cap li) (caup li)))) (base-ev e))))
   ev auto-ev                                                  ; rebind the global: ev is now auto-native
 _ (assert
    ((\ x (+ (* x 2) 3)) = (ev '(\ x (+ (* x 2) 3))))          ; leaf: native, =-identical
    (23 = ((ev '(\ x (+ (* x 2) 3))) 10))
    (((base-ev '(\ x (+ (* x 9) 4))) 11) = ((ev '(\ x (+ (* x 9) 4))) 11))      ; native leaf == interp (catches njit codegen regressions)
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
    (: ad (ev '(\ x y (+ (* x x) y))) (&& (13 = (ad 3 4)) (13 = ((ad 3) 4)) ((\ x y (+ (* x x) y)) = ad)))  ; 2-arg leaf auto-natived
    ; captured-closure constructor auto-natived: captures transparent (= interp)
    (: adder (ev '(\ n (\ x (+ x n))))  a5 (adder 5)
       (&& (15 = (a5 10)) ('(6 7 8) = (map a5 '(1 2 3))) (= a5 ((\ n (\ x (+ x n))) 5)))))
 _ (puts "jit/auto: ev auto-natives qualifying closures + counted loops (transparent)") _ (putc 10))
