; auto -- the transparent auto-hook: rebind `ev` so a QUALIFYING closure compiles to
; NATIVE automatically. No user-facing verb -- you call `ev` (or eval a closure) as
; always; qualifying ones are just faster, and =/show-IDENTICAL to their source.
; Everything else falls through to the base interpreter unchanged.
;
; Shapes that qualify (the emitter's grammar; E := var | int | (OP E E) | (? E E E),
; OP in + - * // % & | ^ < <= > >= =):
;   LEAF1 (\ x E)            -- E over x
;   LEAFN (\ p0 .. p_{n-1} E) -- E over the params, any arity n>=2 (currying via lvm_cur; natn)
;   LOOP  (\ n ((: (go i a) (? (< i n) (go (+ i 1) (+ a B)) a)) 0 0))  -- a native counted
;         loop summing B(i) for i<n; B in the same grammar over i. Owning the LOOP is
;         where the big win is (cf. the leaf's ~6%): the back-edge stays native.
;
; ev is 1-arg, so the loader's `(ev 'ev r)` = `((ev 'ev) r)` still works after the
; rebind; njit/njit-loop call the captured base-ev -> no jit<->ev re-entry. Load AFTER
; ai/glaze/emit.l (uses emit/cgv/ld-x/ld-i/epilogue/loopcode/nat). ⚠ x86-64.
(: base-ev ev
   ; the emitter's expression grammar over var v: var | int | arith | cmp | (? t a b)
   (exprp e v) (? (= e v)   1
                  (whole? e)  1
                  (two? e)  (: op (cap e)
                               (? (has? op '(+ - * // % & | ^ < <= > >= =)) (&& (exprp (caup e) v) (exprp (caup (cup e)) v))
                                  (= op '?) (&& (two? (cup (cup (cup e)))) !(two? (cup (cup (cup (cup e)))))   ; exactly 3 operands
                                               (exprp (caup e) v) (exprp (caup (cup e)) v) (exprp (caup (cup (cup e))) v))
                                  0))
                  0)
   ; --- leaf: (\ x E) ---
   (qual lam) (&& (two? lam) (= (cap lam) '\) (two? (cup lam)) (symp (caup lam))                ; (\ v E), v any symbol
                  (two? (cup (cup lam))) !(two? (cup (cup (cup lam)))) (exprp (caup (cup lam)) (caup lam)))
   ; --- arity-N leaf: (\ p0 .. p_{n-1} E), E over the params (any distinct symbols) ---
   (exprn ps e) (? (has? e ps) 1  (whole? e) 1
                   (two? e) (: op (cap e)
                               (? (has? op '(+ - * // % & | ^ < <= > >= =)) (&& (exprn ps (caup e)) (exprn ps (caup (cup e))))
                                  (= op '?) (&& (two? (cup (cup (cup e)))) !(two? (cup (cup (cup (cup e)))))
                                               (exprn ps (caup e)) (exprn ps (caup (cup e))) (exprn ps (caup (cup (cup e)))))
                                  0))
                   0)
   (distinctp l) (? !(two? l) 1  (has? (cap l) (cup l)) 0  (distinctp (cup l)))        ; no repeated param
   (qualn lam) (: ps (? (two? (cup lam)) (init (cup lam)) 0)  body (? (two? (cup lam)) (last (cup lam)) 0)
                  (&& (two? lam) (= (cap lam) '\) (two? (cup lam))
                      (all symp ps) (< 1 (tally ps)) (distinctp ps)                     ; >=2 distinct symbol params
                      (exprn ps body)))
   (njit lam) (: v (caup lam) (nat (emit (cat (cgv v (\ d (fxv 0 d)) (caup (cup lam)) 0) epilogue)) (base-ev lam) lam))  ; v any param name, fixnum-guarded
   ; --- loop: match the tail-recursive counted-sum skeleton, extract (B counter) ---
   (loopinfo lam)
    (: M    (caup (cup lam))                                ; lambda body
       S    (cap M)   z1 (caup M)   z2 (caup (cup M))       ; M = (S 0 0)
       G    (caup S)  IF (caup (cup S))                     ; S = (: (go i a) IF)
       GO   (cap G)   I (caup G)    A (caup (cup G))        ; (go i a)
       T    (caup IF) THEN (caup (cup IF)) ELS (caup (cup (cup IF)))   ; (? T THEN ELS)
       STEP (caup THEN) ACC (caup (cup THEN))               ; THEN = (go STEP ACC)
       B    (caup (cup ACC))                                ; ACC = (op a B)
       op   (? (two? ACC) (cap ACC) 0)  cmp (? (two? T) (cap T) 0)   ; the fold op + the loop-test comparison
       ok (&& (two? lam) (= (cap lam) '\) (symp (caup lam))                  ; (\ N ..)
              (two? (cup (cup lam))) !(two? (cup (cup (cup lam))))           ; one body
              (two? M) (= z1 0) !(two? (cup (cup (cup M))))                  ; (S 0 a0)
              (two? S) (= (cap S) ':) (symp GO) (symp I) (symp A) !(= I A)   ; (: (go i a) IF)
              (two? IF) (= (cap IF) '?) (= ELS A)                            ; (? .. .. a)
              (two? T) (has? cmp '(< <= > >= =)) (= (caup T) I) (= (caup (cup T)) (caup lam))  ; (cmp i n)
              (= (cap THEN) GO)                                              ; (go ..)
              (two? STEP) (= (cap STEP) '+) (= (caup STEP) I) (= (caup (cup STEP)) 1)  ; (+ i 1)
              (two? ACC) (has? op '(+ *)) (= (caup ACC) A) (exprp B I)       ; (op a B), op in {+,*}, B over i
              (= z2 (foldinit op)))                                          ; a0 matches the op's identity (0 / 1)
       (? ok (L B I op cmp) 0))
   (njit-loop lam B cv op cmp) (nat (emit (loopcode B cv op cmp)) (base-ev lam) lam)
   ; --- general N-VARIABLE loop: (\ n ((: (go v0..vk) (? T (go U..) R)) I0..Ik)),
   ; up to 3 loop vars + arbitrary update exprs -- this is the shape iterative fib/tak
   ; take (i,a,b with updates b and a+b), not just the fold skeleton above.
   (loopinfo-n lam)
    (: BODY (? (two? (cup lam)) (caup (cup lam)) 0)
       S    (? (two? BODY) (cap BODY) 0)  inits (? (two? BODY) (cup BODY) 0)
       G    (? (two? S) (caup S) 0)
       IF   (? (&& (two? S) (two? (cup S))) (caup (cup S)) 0)
       GO   (? (two? G) (cap G) 0)  vars (? (two? G) (cup G) 0)
       T    (? (two? IF) (caup IF) 0)
       THEN (? (&& (two? IF) (two? (cup IF))) (caup (cup IF)) 0)
       R    (? (&& (two? IF) (two? (cup (cup IF)))) (caup (cup (cup IF))) 0)
       updates (? (two? THEN) (cup THEN) 0)
       fr   (link (caup lam) vars)                                  ; cgl frame: {n, v0..vk}
       ok (&& (two? lam) (= (cap lam) '\) (symp (caup lam)) (two? (cup (cup lam))) !(two? (cup (cup (cup lam))))
              (two? BODY) (two? S) (= (cap S) ':) (two? (cup S)) !(two? (cup (cup (cup S))))   ; (: G IF)
              (two? G) (symp GO) (two? vars) (all symp vars) (distinctp vars) !(has? GO vars)
              (< (tally vars) 4)                                    ; <= 3 loop vars (register limit)
              (two? IF) (= (cap IF) '?) (two? THEN) (= (cap THEN) GO)   ; (? T (go U..) R)
              (= (tally updates) (tally vars)) (= (tally inits) (tally vars))
              (two? T) (has? (cap T) '(< <= > >= =)) (exprn fr T)   ; TEST a comparison over {n,vars}
              (all (\ u (exprn fr u)) updates) (exprn fr R)         ; updates + RESULT exprs over {n,vars}
              (all whole? inits))                                     ; inits are fixnum consts
       (? ok (L vars updates T R inits) 0))
   (njit-loop-n lam vars updates test result inits)
    (nat (emit (loopcode-n (caup lam) vars updates test result inits)) (base-ev lam) lam)
   ; --- captured-closure CONSTRUCTOR (\ p (\ q E)): a nest of 1-arg lambdas, E over
   ; {p,q}. Compiled as the flat 2-param native (\ p q E); applying it to p yields a
   ; native CAPTURED closure -- fully transparent (= the interpreter's ((2param) p)
   ; partial form: native captures via partial-apply are =/show-identical to interp).
   ; The constructor itself normalizes to the flat 2-param (a curry-equivalent form).
   (qualc lam) (: p (caup lam)  inner (? (two? (cup lam)) (caup (cup lam)) 0)
                  (&& (two? lam) (= (cap lam) '\) (two? (cup lam)) (symp p)
                      (two? (cup (cup lam))) !(two? (cup (cup (cup lam))))               ; (\ p INNER), one body
                      (two? inner) (= (cap inner) '\) (two? (cup inner)) (symp (caup inner)) !(= p (caup inner))
                      (two? (cup (cup inner))) !(two? (cup (cup (cup inner))))            ; INNER = (\ q E), q != p
                      (exprn (L p (caup inner)) (caup (cup inner)))))
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
   ; compile cache makes structurally-equal closures id?-IDENTICAL, breaking love's
   ; equal-but-distinct closure semantics (!(id? (\ x E) (\ x E))). A safe creation hook
   ; needs the POST-macro opfix seam + a CODE cache (distinct cells per instance). Future.)
   (auto-ev e) (? (qual e)  (memo e njit)
                  (qualn e) (memo e jitn)
                  (qualc e) (memo e (\ l (jitn (flatc l))))
                  (: li (loopinfo e)
                     (? li (memo e (\ l (njit-loop l (cap li) (caup li) (caup (cup li)) (caup (cup (cup li))))))
                        (: ln (loopinfo-n e)
                           (? ln (memo e (\ l (njit-loop-n l (cap ln) (caup ln) (caup (cup ln)) (caup (cup (cup ln))) (caup (cup (cup (cup ln)))))))
                              (base-ev e))))))
   ev auto-ev                                                  ; rebind the global: ev is now auto-native
 _ (assert
    ((\ x (+ (* x 2) 3)) = (ev '(\ x (+ (* x 2) 3))))          ; leaf: native, =-identical
    (23 = ((ev '(\ x (+ (* x 2) 3))) 10))
    (((base-ev '(\ x (+ (* x 9) 4))) 11) = ((ev '(\ x (+ (* x 9) 4))) 11))      ; native leaf == interp (catches njit codegen regressions)
    (: ny (ev '(\ y (+ y 1))) (&& (6 = (ny 5)) ((\ y (+ y 1)) = ny)))   ; arity-1 leaf, non-x param, auto-natived
    (3 = ((ev '(\ x (cap x))) '(3 4)))                         ; non-qualifying -> interpreter
    (6 = (ev '(+ 1 2 3)))                                      ; non-lambda forms unaffected
    (9000000000000000000 = ((ev '(\ x (* x x))) 3000000000))   ; overflow deopts -> bignum
    (: ab (ev '(\ x (? (< x 0) (- 0 x) x))) (&& (7 = (ab -7)) (7 = (ab 7))))   ; conditional leaf auto-natived
    ; LOOP auto-detected -> native counted loop, =-identical + correct
    (: L1 '(\ n ((: (go i a) (? (< i n) (go (+ i 1) (+ a (* i 7))) a)) 0 0))
       f  (ev L1)
       (&& (= f (ev L1)) (3496500 = (f 1000)) (lit? (loopinfo L1))))
    ; LOOP with a conditional body (sum i for i<50, capped) auto-detected
    (: L2 '(\ n ((: (go i a) (? (< i n) (go (+ i 1) (+ a (? (< i 50) i 0))) a)) 0 0))
       h  (ev L2)  c ((: (go i a) (? (< i 1000) (go (+ i 1) (+ a (? (< i 50) i 0))) a)) 0 0)
       (&& (lit? (loopinfo L2)) (= c (h 1000))))
    ; GENERALIZED loop -- a PRODUCT fold (op=*, init 1): n! = prod_{i<n}(i+1)
    (: P '(\ n ((: (go i a) (? (< i n) (go (+ i 1) (* a (+ i 1))) a)) 0 1))
       f (ev P)  fi ((: (go i a) (? (< i 10) (go (+ i 1) (* a (+ i 1))) a)) 0 1)
       (&& (lit? (loopinfo P)) (3628800 = (f 10)) (= fi (f 10)) (= (ev P) (ev P))
           (15511210043330985984000000 = (f 25))))             ; overflow -> deopt -> bignum (transparent)
    ; GENERALIZED loop -- a <= comparison: sum_{i<=n} i
    (: Q '(\ n ((: (go i a) (? (<= i n) (go (+ i 1) (+ a i)) a)) 0 0))
       g (ev Q)  (&& (lit? (loopinfo Q)) (55 = (g 10))))        ; 0+1+..+10 = 55
    ; N-VARIABLE loop auto-detected: iterative fib (i,a,b -- updates b and a+b)
    (: F '(\ n ((: (go i a b) (? (< i n) (go (+ i 1) b (+ a b)) a)) 0 0 1))
       nf (ev F)  (&& (lit? (loopinfo-n F)) (832040 = (nf 30)) (= (ev F) (ev F))   ; fib(30)=832040, native+transparent
                      (4660046610375530309 = (nf 91))))                            ; fib(91) -> deopt -> bignum
    (id? (ev L1) (ev L1))                                       ; CACHE: same source -> same native (compiled once)
    (id? (ev '(\ x (+ x 1))) (ev '(\ x (+ x 1))))
    (: ad (ev '(\ x y (+ (* x x) y))) (&& (13 = (ad 3 4)) (13 = ((ad 3) 4)) ((\ x y (+ (* x x) y)) = ad)))  ; 2-arg leaf auto-natived
    (: a3 (ev '(\ x y z (+ (+ x y) (* z 3))))                                                  ; 3-arg leaf auto-natived, currying at any split
       (&& (13 = (a3 1 3 3)) (13 = ((a3 1 3) 3)) (13 = ((a3 1) 3 3)) ((\ x y z (+ (+ x y) (* z 3))) = a3)))
    ; captured-closure constructor auto-natived: captures transparent (= interp)
    (: adder (ev '(\ n (\ x (+ x n))))  a5 (adder 5)
       (&& (15 = (a5 10)) ('(6 7 8) = (map a5 '(1 2 3))) (= a5 ((\ n (\ x (+ x n))) 5)))))
 _ (puts "ai/glaze/auto: ev auto-natives qualifying closures + counted loops (transparent)") _ (putc 10))
