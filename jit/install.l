; ============================================================================
; jit/install.l -- the SELF-INSTALLING opjit hook (x86_64). Baked into the host
; `love` binary and run via g_evals_ at boot, AFTER the egg, under #ifdef
; __x86_64__ (see main.c). Pins book['opjit] = jit-walk, so from boot on the
; opfix wrapper (love/prelude.l) turns qualifying (\ p <arith>) lambdas into
; native machine code through BOTH compilers -- transparently, no file to load.
;
; Equality is preserved (respec): a jitted closure carries the ORIGINAL source
; and holds no captures, so it = the interpreted closure and the 1/0 numeral
; bridges survive -- the corpus runs through this unchanged.
;
; The whole codegen is wrapped in one (: opjit (: <helpers> jit-walk)) so ONLY
; `opjit` becomes a global -- no name collides with the prelude/corpus.
(: opjit (:
   ; --- recognizer: a closed arith expr in the bound variables vs (1 or 2) ---
   (arithp e vs)
    (? (symp e) (memq e vs)
       (&& (fixp e) (<= 0 e)) 1
       (&& (twop e) (= 1 (tally e))) (arithp (cap e) vs)        ; peel op-core's ((e)) wrapper
       (&& (twop e) (= 3 (tally e)) (memq (cap e) '(+ - * // % < <= > >= =)))
         (&& (arithp (caup e) vs) (arithp (caup (cup e)) vs))
       0)
   (leb k n) (? (< n 1) () (cons (% k 256) (leb (// k 256) (- n 1))))
   guard '(65 15 144 193  69 8 200)                             ; seto r9b ; or r8b,r9b
   divsetup '(69 49 201  72 133 201  65 15 148 193  69 8 200  76 1 201  72 153  72 247 249)
   (cmpc op)
    (cat '(72 57 200)
     (cat (? (idp op '<)  '(15 156 192) (idp op '<=) '(15 158 192)
             (idp op '>)  '(15 159 192) (idp op '>=) '(15 157 192) '(15 148 192))
          '(15 182 192)))
   (combine op)
    (? (idp op '+)  (cat '(72 1 200) guard)
       (idp op '-)  (cat '(72 41 200) guard)
       (idp op '*)  (cat '(72 15 175 193) guard)
       (idp op '//) divsetup
       (idp op '%)  (cat divsetup '(72 137 208))
       (cmpc op))
   argx '(72 137 248  72 209 248)                               ; mov rax,rdi ; sar rax,1
   argy '(72 137 240  72 209 248)                               ; mov rax,rsi ; sar rax,1
   (vreg e regs) (? !regs () (idp e (cap (cap regs))) (cup (cap regs)) (vreg e (cup regs)))
   (emit e regs)
    (? (symp e) (vreg e regs)
       (fixp e) (cons 72 (cons 184 (leb e 8)))
       (&& (twop e) (= 1 (tally e))) (emit (cap e) regs)
       (: op (cap e) a (caup e) b (caup (cup e))
          (cat (emit a regs) (cat '(80) (cat (emit b regs)
             (cat '(72 137 193  88) (combine op)))))))
   prologue '(69 49 192)                                        ; xor r8d,r8d
   epilogue (cat '(72 1 192) (cat guard (cat '(72 137 193  72 1 201) (cat guard
              '(185 1 0 0 0  77 133 192  72 15 69 193  195)))))
   (l2b bs) (: n (tally bs) b (buf n)
               _ ((: (go i l) (? l (: _ (pin b i (cap l)) (go (+ i 1) (cup l))) 0)) 0 bs) b)
   ; --- the driver: source (\ p <arith>) -> native closure (respec'd to = the source) ---
   (jit lam)
    (: rest (cup lam) body (last rest) ps (init rest) n (tally ps)
       vm (ev lam)
       (? (|| (< n 1) (> n 2)) vm
          !(all symp ps) vm
          !(arithp body ps) vm
          (: regs (? (= n 1) (list (cons (cap ps) argx))
                             (list (cons (cap ps) argx) (cons (caup ps) argy)))
             code (forge (l2b (cat prologue (cat (emit body regs) epilogue))))
             wsrc (? (= n 1)
                    (L '\ 'a   (L ': 'v (L 'call  (L '\ code) 'a)
                                   (L '? (L '& 'v 1) (L (L '\ vm) 'a)        (L '// 'v 2))))
                    (L '\ 'a 'b (L ': 'v (L 'call2 (L '\ code) 'a 'b)
                                   (L '? (L '& 'v 1) (L (L (L '\ vm) 'a) 'b) (L '// 'v 2)))))
             (respec (ev wsrc) lam))))
   ; --- re-entry guard: jit's (ev lam) fallback must not re-jit lam ---
   jguard (tablet 0)
   (qual e)
    (&& (twop e) (idp (cap e) '\)
        (: rest (cup e) body (last rest) ps (init rest) n (tally ps)
           (&& (|| (= n 1) (= n 2)) (all symp ps) (arithp body ps))))
   ; --- the book['opjit] pass: source -> source, qualifying lambdas -> native ---
   (jit-walk e)
    (? (peep jguard 0 0) e                                      ; re-entrant: leave verbatim
       !(twop e) e
       (qual e) (: _ (pin jguard 0 1) c (jit e) _ (pin jguard 0 0) (list '\ c))
       (: h (cap e)
        (? (idp h '\) e          ; any other \-form (quote / non-qual lambda): leave ENTIRELY.
                                 ; NEVER rewrite a lambda body -- that would change the stashed
                                 ; \-expr of the enclosing lambda, breaking its show (de Bruijn)
                                 ; and = (salpha). Lambdas in :/application bodies are still
                                 ; reached, since those forms are walked below.
           (idp h 'qq) e
           (idp h '::) e
           (map jit-walk e))))
   jit-walk))                                                   ; opjit = jit-walk
