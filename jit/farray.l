; ============================================================================
; jit/farray.l -- FLOAT (r-array) kernels. A single-param (\ x <arith>) compiled
; to SSE scalar-double code and applied to every cell of an r-array by the armap
; nif's tight C loop. r-array cells are raw f64; the SysV ABI passes/returns a
; double in %xmm0, so the kernel reads the cell from %xmm0, computes in the xmm
; registers, and leaves the result in %xmm0.
;
; The cell is saved to %xmm15 in the prologue (all xmm are caller-saved and this
; is a leaf, so %xmm15 is free) and re-read on each use of x -- the float analogue
; of the integer kernel re-deriving x from %rdi. Binops use the machine stack to
; hold the left operand. Integer literals are converted with cvtsi2sd (a float
; literal would need its raw IEEE bits -- deferred). Ops: + - * / (float /0 is
; ieee-inf, no #DE, so / is safe). Comparisons are omitted -- they'd yield a z
; mask, not an r-array.
;
; x86_64 host; load after jit/kernel.l (reuses leb, l2b):
;     out/host/love -l jit/kernel.l jit/farray.l

; --- recognizer: a closed float-arith expr in the bound variables vs (1 or 2) ---
(: (farith e vs)
   (? (symp e) (memq e vs)
      (&& (fixp e) (<= 0 e)) 1                   ; non-negative int literal -> cvtsi2sd
      (flop e) 1                                 ; float literal (1.5, ...) -> via fbits
      (&& (twop e) (= 1 (tally e))) (farith (cap e) vs)   ; peel op-core's ((e)) wrapper
      (&& (twop e) (= 3 (tally e)) (memq (cap e) '(+ - * /)))
        (&& (farith (caup e) vs) (farith (caup (cup e)) vs))
      0))
; (leb64 -- the bit-op byte extractor for fbits patterns -- is in jit/kernel.l)

; --- a parameter's "load to xmm0" bytes, by its SysV float-arg register ---
(: fr0 '(242 65 15 16 199)                       ; movsd xmm0,xmm15  (last/only param)
   fr1 '(242 65 15 16 198)                       ; movsd xmm0,xmm14  (1st of two)
   (vregf e regs) (? !regs () (idp e (cap (cap regs))) (cup (cap regs)) (vregf e (cup regs))))

; --- combine: xmm0 (op)= xmm1 ---
(: (fcombine op)
   (? (idp op '+) '(242 15 88 193)               ; addsd xmm0,xmm1   (F2 0F 58 C1)
      (idp op '-) '(242 15 92 193)               ; subsd xmm0,xmm1   (F2 0F 5C C1)
      (idp op '*) '(242 15 89 193)               ; mulsd xmm0,xmm1   (F2 0F 59 C1)
                  '(242 15 94 193)))             ; divsd xmm0,xmm1   (F2 0F 5E C1)

; --- emit: bytes leaving e's value in xmm0 ---
(: (femit e regs)
   (? (symp e) (vregf e regs)                    ; a param -> load from its xmm reg
      (fixp e) (cat (cons 72 (cons 184 (leb e 8)))   ; mov rax,imm64           (48 B8 <le64>)
                    '(242 72 15 42 192))         ; cvtsi2sd xmm0,rax           (F2 48 0F 2A C0)
      (flop e) (cat (cons 72 (cons 184 (leb64 (fbits e) 8)))   ; mov rax,<IEEE bits>  (48 B8 <le64>)
                    '(102 72 15 110 192))        ; movq xmm0,rax               (66 48 0F 6E C0)
      (&& (twop e) (= 1 (tally e))) (femit (cap e) regs)   ; peel op-core's ((e)) wrapper
      (: op (cap e) a (caup e) b (caup (cup e))
         (cat (femit a regs)                     ; xmm0 = A
          (cat '(72 131 236 8  242 15 17 4 36)   ; sub rsp,8 ; movsd [rsp],xmm0   (push A)
           (cat (femit b regs)                   ; xmm0 = B
            (cat '(242 15 16 200                 ; movsd xmm1,xmm0  (xmm1 = B)    (F2 0F 10 C8)
                  242 15 16 4 36  72 131 196 8)  ; movsd xmm0,[rsp] ; add rsp,8   (pop A)
             (fcombine op))))))))                ; xmm0 = (A op B)

; --- driver: (\ x <arith>) -> (\ r-array -> r-array), each cell native (SSE) ---
; --- float comparison -> 0/1 INT in rax (for a z-mask output array). comisd sets
; CF/ZF like an unsigned compare, so < is setb, > is seta, etc. ---
(: (cmpc-f op)
   (cat '(102 15 47 193)                         ; comisd xmm0,xmm1   (66 0F 2F C1)
    (cat (? (idp op '<)  '(15 146 192)           ; setb  al  (0F 92 C0)
            (idp op '<=) '(15 150 192)           ; setbe al  (0F 96 C0)
            (idp op '>)  '(15 151 192)           ; seta  al  (0F 97 C0)
            (idp op '>=) '(15 147 192)           ; setae al  (0F 93 C0)
                         '(15 148 192))          ; sete  al  (0F 94 C0)  ('=)
         '(15 182 192))))                        ; movzx eax,al  (0F B6 C0)

; --- is body a top-level float comparison (A op B) with float-arith A, B? ---
(: (fcmp? body vs)
   (&& (twop body) (= 3 (tally body)) (memq (cap body) '(< <= > >= =))
       (farith (caup body) vs) (farith (caup (cup body)) vs)))

; --- emit a comparison body: compute A,B as doubles, compare -> int in rax ---
(: (cemit-f body regs)
   (: a (caup body) b (caup (cup body))
      (cat (femit a regs)                        ; xmm0 = A
       (cat '(72 131 236 8  242 15 17 4 36)      ; sub rsp,8 ; movsd [rsp],xmm0  (push A)
        (cat (femit b regs)                      ; xmm0 = B
         (cat '(242 15 16 200  242 15 16 4 36  72 131 196 8)   ; xmm1=B ; pop A
          (cmpc-f (cap body))))))))              ; -> 0/1 int in rax

; --- driver: float arith (\ x <arith>) -> (\ r-array -> r-array) via armap;
; a top-level float comparison -> (\ r-array -> z-MASK array) via armapz. ---
(: (rjit lam)
   (: v (caup lam) body (caup (cup lam)) vs (list v) regs (list (cons v fr0))
      (? !(symp v) lam
         (fcmp? body vs)                         ; comparison -> z-mask
           (: code (forge (l2b (cat '(242 68 15 16 248) (cat (cemit-f body regs) '(195)))))
              (\ in (: out (arr z (ashape in) 0) _ (armapz code in out) out)))
         (farith body vs)                        ; float arith -> r-array
           (: code (forge (l2b (cat '(242 68 15 16 248) (cat (femit body regs) '(195)))))
              (\ in (: out (arr r (ashape in) 0) _ (armap code in out) out)))
         lam)))

; --- FLOAT FOLD: (arfold '(\ acc x <float-arith>) seed) -> (\ r-array -> float).
; acc -> %xmm14 (fr1), cell -> %xmm15 (fr0); the accumulator is a double, the
; result a boxed float -- matching asum/aprod over an r-array. ---
(: (arfold lam seed)
   (: rest (cup lam) body (last rest) ps (init rest)
      (? !(&& (= 2 (tally ps)) (all symp ps) (farith body ps)) lam
         (: regs (list (cons (cap ps) fr1) (cons (caup ps) fr0))
            code (forge (l2b (cat '(242 68 15 16 240  242 68 15 16 249)   ; xmm14=acc ; xmm15=cell
                             (cat (femit body regs) '(195)))))
            (\ in (arreduce code seed in))))))

; --- FLOAT WHOLE-LOOP FOLD: (arfoldw '(\ acc x <float-arith>) seed). Unlike
; arfold (whose C nif loops and calls the kernel per cell), the forged code OWNS
; the loop -- the op is inlined and there is NO per-cell call. The forged fn is
; fn(double *cells %rdi, uintptr_t n %rsi, double init %xmm0) -> double %xmm0.
; acc lives in %xmm14 across iterations, the cell is loaded into %xmm15 each pass,
; and the body is the SAME `femit` used by arfold (regs acc->%xmm14, cell->%xmm15,
; result %xmm0). Two self-relative jumps frame the loop; their rel32 offsets are
; computed from B = the body length (see the offset map below). ---
; the accumulate PEEPHOLE: when the body is exactly (op acc cell), op in {+ - *},
; the whole step is one register-to-register op into the live accumulator --
; <op>sd %xmm14,%xmm15 -- no stack round-trip, no acc reload. This is what lets
; the forged loop actually MATCH the C builtin; without it the general femit body
; (which spills the left operand to the machine stack per cell) dominates and
; owning the loop buys nothing.
(: (unwrap e) (? (&& (twop e) (= 1 (tally e))) (unwrap (cap e)) e)   ; peel op-core's ((..))
   (facc op)                                            ; acc <op>= cell, result in xmm14
   (? (idp op '+) '(242 69 15 88 247)                   ; addsd xmm14,xmm15
      (idp op '-) '(242 69 15 92 247)                   ; subsd xmm14,xmm15
      (idp op '*) '(242 69 15 89 247)                   ; mulsd xmm14,xmm15
      ())
   (accfast body acc cell)                              ; the fused inner, or () if not the idiom
   (: u (unwrap body)
      (? (&& (twop u) (= 3 (tally u)) (memq (cap u) '(+ - *))
             (symp (caup u)) (idp (caup u) acc) (idp (caup (cup u)) cell))
         (cat '(242 68 15 16 60 207) (facc (cap u)))    ; movsd xmm15,[rdi+rcx*8] ; <op>sd xmm14,xmm15
         ()))

   (arfoldw lam seed)
   (: rest (cup lam) body (last rest) ps (init rest)
      (? !(&& (= 2 (tally ps)) (all symp ps) (farith body ps)) lam
         (: regs (list (cons (cap ps) fr1) (cons (caup ps) fr0))   ; acc->xmm14, cell->xmm15
            fast (accfast body (cap ps) (caup ps))
            ; INNER = the per-iteration work (between jge and inc): the fast fused
            ; step, or the general (load cell ; femit body -> xmm0 ; acc<-xmm0).
            inner (? fast fast
                     (cat '(242 68 15 16 60 207)                   ; movsd xmm15,[rdi+rcx*8]
                      (cat (femit body regs)                       ; body -> xmm0
                           '(242 68 15 16 240))))                  ; movsd xmm14,xmm0  (acc=res)
            l (tally inner)
            ; offsets from loop-start: cmp[0,3) jge[3,9) inner[9,9+l)
            ; inc[9+l,12+l) jmp[12+l,17+l) done@17+l
            loopb (cat '(72 57 241)                                ; cmp rcx,rsi
                    (cat (cat '(15 141) (leb64 (+ 8 l) 4))         ; jge done  (rel = 8+l)
                     (cat inner
                      (cat '(72 255 193)                           ; inc rcx
                       (cat '(233) (leb64 (- 0 (+ 17 l)) 4))))))   ; jmp loop (rel = -(17+l))
            code (forge (l2b (cat '(242 68 15 16 240  72 49 201)   ; movsd xmm14,xmm0 (acc=init); xor rcx,rcx
                            (cat loopb '(242 65 15 16 198  195))))) ; movsd xmm0,xmm14 (return acc); ret
            (\ in (rfoldw code seed in))))))

; ============================================================================
; SELF-CHECK: the native float kernel must equal love's elementwise r-array ops,
; bit-for-bit (same IEEE doubles). (aeq a b) = every cell equal.
(: bad (tablet 0)
   (aeq a b) (aall (a = b))
   (ck nm got want)
     (: ok (aeq got want)
        _ (dot (+ nm (+ ": " (+ (show got) (+ (? ok "  ==  " "  =/=  ") (+ (show want) (? ok "\n" "  FAIL\n")))))))
        (? ok 0 (pin bad 0 (+ 1 (peep bad 0 0)))))
   (cks nm got want)                              ; scalar compare (the fold returns a float)
     (: ok (= got want)
        _ (dot (+ nm (+ ": " (+ (show got) (+ (? ok "  ==  " "  =/=  ") (+ (show want) (? ok "\n" "  FAIL\n")))))))
        (? ok 0 (pin bad 0 (+ 1 (peep bad 0 0)))))
   dd  (rjit '(\ x (+ x x)))
   x2  (rjit '(\ x (* x 2)))
   hlf (rjit '(\ x (/ x 2)))
   sqm (rjit '(\ x (- (* x x) 1)))
   inv (rjit '(\ x (/ x 0)))                      ; float /0 -> ieee-inf (no #DE)
   sc  (rjit '(\ x (* x 1.5)))                    ; FLOAT LITERAL via fbits
   af  (rjit '(\ x (+ x 0.25)))                   ; float literal add
   ne  (rjit '(\ x (* x -2.0)))                   ; NEGATIVE float literal (bit pattern, any sign)
   ln  (rjit '(\ x (+ (* x 2.5) 0.5)))            ; mixed: x*2.5 + 0.5
   _ (ck "x+x   @1.5.. " (dd  @(1.5 2.5 3.5))  (@(1.5 2.5 3.5) + @(1.5 2.5 3.5)))
   _ (ck "x*2   @1.5.. " (x2  @(1.5 2.5))      (@(1.5 2.5) * 2))
   _ (ck "x/2   @3.0.. " (hlf @(3.0 5.0))      (@(3.0 5.0) / 2))
   _ (ck "x*x-1 @2.0.. " (sqm @(2.0 3.0))      ((@(2.0 3.0) * @(2.0 3.0)) - 1))
   _ (ck "x/0   @1.0   " (inv @(1.0))          (@(1.0) / 0))      ; @(ieee-inf)
   _ (ck "x*1.5 @2.0.. " (sc  @(2.0 4.0))      (@(2.0 4.0) * 1.5))     ; @(3.0 6.0)
   _ (ck "x+.25 @1.0.. " (af  @(1.0 2.0))      (@(1.0 2.0) + 0.25))    ; @(1.25 2.25)
   _ (ck "x*-2  @1.5.. " (ne  @(1.5 2.5))      (@(1.5 2.5) * -2.0))    ; @(-3.0 -5.0)
   _ (ck "2.5x+.5 @2..  " (ln  @(2.0 4.0))     ((@(2.0 4.0) * 2.5) + 0.5)) ; @(5.5 10.5)
   ; --- float COMPARISONS -> z-mask (armapz) ---
   lt  (rjit '(\ x (< x 2.0)))                    ; -> z-array of 0/1
   ge  (rjit '(\ x (>= x 2.0)))
   ev2 (rjit '(\ x (< (* x 0.5) 1.5)))            ; comparison over an arith subexpr
   _ (ck "x<2   @1..3 " (lt  @(1.0 2.0 3.0))   (@(1.0 2.0 3.0) < 2.0))    ; @(1 0 0)  (z!)
   _ (ck "x>=2  @1..3 " (ge  @(1.0 2.0 3.0))   (@(1.0 2.0 3.0) >= 2.0))   ; @(0 1 1)
   _ (ck ".5x<1.5 @..  " (ev2 @(1.0 3.0 5.0))  ((@(1.0 3.0 5.0) * 0.5) < 1.5)) ; @(1 0 0)
   _ (dot (+ "  (x<2 type = " (+ (show (atype (lt @(1.0 2.0)))) (+ ", want z=" (+ (show z) ")\n")))))
   ; --- float FOLD (arreduce): sum/prod, returns a float scalar ---
   sumf (arfold '(\ acc x (+ acc x)) 0)
   prodf (arfold '(\ acc x (* acc x)) 1)
   _ (cks "sum  r @1..4 " (sumf @(1.0 2.0 3.0 4.0))   (asum @(1.0 2.0 3.0 4.0)))   ; 10.0
   _ (cks "prod r @1..4 " (prodf @(1.0 2.0 3.0 4.0))  (aprod @(1.0 2.0 3.0 4.0)))  ; 24.0
   ; --- float WHOLE-LOOP FOLD (rfoldw): the forged code owns the loop ---
   wsum (arfoldw '(\ acc x (+ acc x)) 0)
   wprod (arfoldw '(\ acc x (* acc x)) 1)
   wsq  (arfoldw '(\ acc x (+ acc (* x x))) 0)     ; sum of squares -- body clobbers regs
   _ (cks "Wsum  r @1..4" (wsum @(1.0 2.0 3.0 4.0))   (asum @(1.0 2.0 3.0 4.0)))   ; 10.0
   _ (cks "Wprod r @1..4" (wprod @(1.0 2.0 3.0 4.0))  (aprod @(1.0 2.0 3.0 4.0)))  ; 24.0
   _ (cks "Wsumsq @1..4 " (wsq @(1.0 2.0 3.0 4.0))    (asum (@(1.0 2.0 3.0 4.0) * @(1.0 2.0 3.0 4.0)))) ; 30.0
   _ (cks "Wsum  empty " (wsum (arr r '(0) 0))        (asum (arr r '(0) 0)))       ; 0.0 (empty loop)
   _ (dot (? (peep bad 0 0) (+ (show (peep bad 0 0)) " FAILED\n") "ALL PASS\n")))
