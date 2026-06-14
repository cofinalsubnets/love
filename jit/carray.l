; ============================================================================
; jit/carray.l -- COMPLEX (c-array) kernels. A single-param (\ x <arith>) compiled
; to SSE code over packed (re,im) f64 cells and applied by the acmap nif's C loop.
; g_C cells are interleaved (re,im); the SysV ABI passes/returns a two-double
; struct in %xmm0 (re) and %xmm1 (im), so a complex value lives in (%xmm0,%xmm1).
;
; The cell is saved to (%xmm14,%xmm15) in the prologue and re-read on each use of
; x. Binops use a 16-byte machine-stack slot for the left operand. Integer
; literals become (k, 0) via cvtsi2sd + pxor. Ops: + - * (complex literals and /
; deferred). add/sub are componentwise; mul is (a+bi)(c+di) = (ac-bd)+(ad+bc)i.
;
; x86_64 host; load after jit/kernel.l (reuses leb, l2b):
;     out/host/love -l jit/kernel.l jit/carray.l

; --- recognizer: a closed complex-arith expr in the single cell variable v ---
(: (carith e v)
   (? (symp e) (idp e v)
      (&& (fixp e) (<= 0 e)) 1                   ; non-negative int literal -> (k, 0)
      (&& (twop e) (= 3 (tally e)) (idp (cap e) 'plex)   ; complex literal ~(re im) reads as
          (|| (fixp (caup e)) (flop (caup e)))           ;   (plex re im) -- real-literal components
          (|| (fixp (caup (cup e))) (flop (caup (cup e))))) 1
      (&& (twop e) (= 1 (tally e))) (carith (cap e) v)   ; peel op-core's ((e)) wrapper
      (&& (twop e) (= 3 (tally e)) (memq (cap e) '(+ - * /)))
        (&& (carith (caup e) v) (carith (caup (cup e)) v))
      0))

; --- combine: A=(xmm0,xmm1)=(a,b), B=(xmm2,xmm3)=(c,d) -> result in (xmm0,xmm1) ---
(: (ccombine op)
   (? (idp op '+) '(242 15 88 194  242 15 88 203)        ; addsd xmm0,xmm2 ; addsd xmm1,xmm3
      (idp op '-) '(242 15 92 194  242 15 92 203)        ; subsd xmm0,xmm2 ; subsd xmm1,xmm3
      (idp op '*)
      ; complex mul: re = ac-bd, im = ad+bc  (xmm4,xmm5 scratch)
      '(242 15 16 224  242 15 89 226              ; movsd xmm4,xmm0(a) ; mulsd xmm4,xmm2  -> ac
        242 15 16 233  242 15 89 235              ; movsd xmm5,xmm1(b) ; mulsd xmm5,xmm3  -> bd
        242 15 92 229                             ; subsd xmm4,xmm5                       -> re=ac-bd
        242 15 16 232  242 15 89 235              ; movsd xmm5,xmm0(a) ; mulsd xmm5,xmm3  -> ad
        242 15 89 202                             ; mulsd xmm1,xmm2(b*c)                  -> bc
        242 15 88 233                             ; addsd xmm5,xmm1                       -> im=ad+bc
        242 15 16 196  242 15 16 205)             ; movsd xmm0,xmm4(re) ; movsd xmm1,xmm5(im)
      ; complex div: re = (ac+bd)/D, im = (bc-ad)/D, D = c*c+d*d (xmm4..7 scratch;
      ; SSE divsd by a 0 divisor is inf/nan, not #DE -- no crash). a,b,c,d kept in
      ; xmm0..3 until the final stores.
      '(242 15 16 242  242 15 89 246              ; movsd xmm6,xmm2(c) ; mulsd xmm6,xmm6  -> c*c
        242 15 16 251  242 15 89 255              ; movsd xmm7,xmm3(d) ; mulsd xmm7,xmm7  -> d*d
        242 15 88 247                             ; addsd xmm6,xmm7                       -> D=c*c+d*d
        242 15 16 224  242 15 89 226              ; movsd xmm4,xmm0(a) ; mulsd xmm4,xmm2  -> ac
        242 15 16 249  242 15 89 251              ; movsd xmm7,xmm1(b) ; mulsd xmm7,xmm3  -> bd
        242 15 88 231                             ; addsd xmm4,xmm7                       -> ac+bd
        242 15 16 233  242 15 89 234              ; movsd xmm5,xmm1(b) ; mulsd xmm5,xmm2  -> bc
        242 15 16 248  242 15 89 251              ; movsd xmm7,xmm0(a) ; mulsd xmm7,xmm3  -> ad
        242 15 92 239                             ; subsd xmm5,xmm7                       -> bc-ad
        242 15 94 230  242 15 94 238              ; divsd xmm4,xmm6 ; divsd xmm5,xmm6      -> re,im
        242 15 16 196  242 15 16 205)))           ; movsd xmm0,xmm4(re) ; movsd xmm1,xmm5(im)

; --- emit: bytes leaving e's value in (xmm0,xmm1) ---
(: (cemit e v)
   (? (symp e) '(242 65 15 16 198  242 65 15 16 207)     ; x: movsd xmm0,xmm14 ; movsd xmm1,xmm15
      (fixp e) (cat (cons 72 (cons 184 (leb e 8)))       ; mov rax,imm64
                    '(242 72 15 42 192  102 15 239 201)) ; cvtsi2sd xmm0,rax ; pxor xmm1,xmm1  -> (k,0)
      (&& (twop e) (= 3 (tally e)) (idp (cap e) 'plex))   ; complex literal (plex re im)
        (cat (cons 72 (cons 184 (leb64 (fbits (caup e)) 8)))         ; mov rax,<re bits>
          (cat '(102 72 15 110 192)                                  ; movq xmm0,rax  (66 48 0F 6E C0)
           (cat (cons 72 (cons 184 (leb64 (fbits (caup (cup e))) 8)))   ; mov rax,<im bits>
                '(102 72 15 110 200))))            ; movq xmm1,rax  (66 48 0F 6E C8)  -> (re,im)
      (&& (twop e) (= 1 (tally e))) (cemit (cap e) v)     ; peel op-core's ((e)) wrapper
      (: op (cap e) a (caup e) b (caup (cup e))
         (cat (cemit a v)                                 ; (xmm0,xmm1) = A
          (cat '(72 131 236 16  242 15 17 4 36  242 15 17 76 36 8)   ; sub rsp,16 ; push A (re,im)
           (cat (cemit b v)                               ; (xmm0,xmm1) = B
            (cat '(242 15 16 208  242 15 16 217           ; movsd xmm2,xmm0 ; movsd xmm3,xmm1  (B -> 2,3)
                   242 15 16 4 36  242 15 16 76 36 8  72 131 196 16)  ; pop A (re,im) ; add rsp,16
             (ccombine op))))))))                         ; (xmm0,xmm1) = (A op B)

; --- driver: (\ x <arith>) -> (\ c-array -> c-array), each cell native (SSE) ---
(: (cjit lam)
   (: v (caup lam) body (caup (cup lam))
      (? !(&& (symp v) (carith body v)) lam
         (: code (forge (l2b (cat '(242 68 15 16 240  242 68 15 16 249)   ; prologue: save cell -> xmm14,xmm15
                              (cat (cemit body v) '(195)))))              ; ... ; ret
            (\ in (: out (arr c (ashape in) 0) _ (acmap code in out) out))))))

; --- COMPLEX FOLD: (acfold '(\ acc x <complex-arith>) seed) -> (\ c-array -> ~).
; The acreduce ABI passes acc = (xmm0,xmm1) and cell = (xmm2,xmm3) (two two-double
; structs), result in (xmm0,xmm1). The prologue stashes acc -> (xmm12,xmm13) and
; cell -> (xmm14,xmm15); each param then re-reads from its pair on every use.
; `regs` maps a param symbol to the byte run that loads it into (xmm0,xmm1).
; Matches asum/aprod over a c-array. ---
(: cr0 '(242 65 15 16 196  242 65 15 16 205)     ; acc:  movsd xmm0,xmm12 ; movsd xmm1,xmm13
   cr1 '(242 65 15 16 198  242 65 15 16 207)     ; cell: movsd xmm0,xmm14 ; movsd xmm1,xmm15
   (cvreg e regs) (? !regs () (idp e (cap (cap regs))) (cup (cap regs)) (cvreg e (cup regs)))

   (cfarith e regs)                              ; closed complex-arith over the param regs
   (? (symp e) (? (cvreg e regs) 1 0)
      (&& (fixp e) (<= 0 e)) 1
      (&& (twop e) (= 3 (tally e)) (idp (cap e) 'plex)
          (|| (fixp (caup e)) (flop (caup e)))
          (|| (fixp (caup (cup e))) (flop (caup (cup e))))) 1
      (&& (twop e) (= 1 (tally e))) (cfarith (cap e) regs)
      (&& (twop e) (= 3 (tally e)) (memq (cap e) '(+ - * /)))
        (&& (cfarith (caup e) regs) (cfarith (caup (cup e)) regs))
      0)

   (cfemit e regs)                               ; bytes leaving e in (xmm0,xmm1)
   (? (symp e) (cvreg e regs)
      (fixp e) (cat (cons 72 (cons 184 (leb e 8))) '(242 72 15 42 192  102 15 239 201))
      (&& (twop e) (= 3 (tally e)) (idp (cap e) 'plex))
        (cat (cons 72 (cons 184 (leb64 (fbits (caup e)) 8)))
          (cat '(102 72 15 110 192)
           (cat (cons 72 (cons 184 (leb64 (fbits (caup (cup e))) 8)))
                '(102 72 15 110 200))))
      (&& (twop e) (= 1 (tally e))) (cfemit (cap e) regs)
      (: op (cap e) a (caup e) b (caup (cup e))
         (cat (cfemit a regs)
          (cat '(72 131 236 16  242 15 17 4 36  242 15 17 76 36 8)
           (cat (cfemit b regs)
            (cat '(242 15 16 208  242 15 16 217
                   242 15 16 4 36  242 15 16 76 36 8  72 131 196 16)
             (ccombine op)))))))

   (acfold lam seed)
   (: rest (cup lam) body (last rest) ps (init rest)
      (? !(&& (= 2 (tally ps)) (all symp ps) (cfarith body (list (cons (cap ps) cr0) (cons (caup ps) cr1)))) lam
         (: regs (list (cons (cap ps) cr0) (cons (caup ps) cr1))
            code (forge (l2b (cat '(242 68 15 16 224  242 68 15 16 233    ; xmm12=acc.re ; xmm13=acc.im
                                    242 68 15 16 242  242 68 15 16 251)   ; xmm14=cell.re ; xmm15=cell.im
                             (cat (cfemit body regs) '(195)))))
            (\ in (acreduce code seed in))))))

; ============================================================================
; SELF-CHECK: the native complex kernel must equal love's elementwise c-array ops,
; bit-for-bit. (aeq a b) = every cell equal.
(: bad (tablet 0)
   (aeq a b) (aall (a = b))
   (ck nm got want)
     (: ok (aeq got want)
        _ (dot (+ nm (+ ": " (+ (show got) (+ (? ok "  ==  " "  =/=  ") (+ (show want) (? ok "\n" "  FAIL\n")))))))
        (? ok 0 (pin bad 0 (+ 1 (peep bad 0 0)))))
   cv  (array 2 ~(1 2) ~(3 4))
   dd  (cjit '(\ x (+ x x)))
   sq  (cjit '(\ x (* x x)))                      ; the showcase: complex multiply
   s1  (cjit '(\ x (- x 1)))
   x2  (cjit '(\ x (* x 2)))
   pol (cjit '(\ x (+ (* x x) 1)))                ; x^2 + 1, complex
   dv2 (cjit '(\ x (/ x 2)))                      ; complex / real
   dvs (cjit '(\ x (/ x x)))                      ; x/x = 1 (the showcase: complex divide)
   dvm (cjit '(\ x (/ (* x x) x)))                ; x^2/x = x
   lit (cjit '(\ x (+ x ~(0.5 1.5))))             ; COMPLEX LITERAL ~(0.5 1.5) via fbits
   rot (cjit '(\ x (* x ~(0 1))))                 ; * i = rotate 90 (complex literal)
   _ (ck "x+x  c     " (dd  cv)   (cv + cv))
   _ (ck "x*x  c     " (sq  cv)   (cv * cv))       ; ~(1 2)^2 = ~(-3 4); ~(3 4)^2 = ~(-7 24)
   _ (ck "x-1  c     " (s1  cv)   (cv - 1))
   _ (ck "x*2  c     " (x2  cv)   (cv * 2))
   _ (ck "x*x+1 c    " (pol cv)   ((cv * cv) + 1))
   _ (ck "x/2  c     " (dv2 cv)   (cv / 2))        ; @(~(0.5 1) ~(1.5 2))
   _ (ck "x/x  c     " (dvs cv)   (cv / cv))       ; @(~1 ~1)
   _ (ck "x*x/x c    " (dvm cv)   ((cv * cv) / cv)) ; back to cv (up to fp)
   _ (ck "x+~(.5 1.5)" (lit cv)   (cv + ~(0.5 1.5)))  ; complex literal add
   _ (ck "x*i  (rot) " (rot cv)   (cv * ~(0 1)))       ; multiply by i
   (cks nm got want)                              ; the fold returns a complex SCALAR
     (: ok (got = want)
        _ (dot (+ nm (+ ": " (+ (show got) (+ (? ok "  ==  " "  =/=  ") (+ (show want) (? ok "\n" "  FAIL\n")))))))
        (? ok 0 (pin bad 0 (+ 1 (peep bad 0 0)))))
   sumc (acfold '(\ acc x (+ acc x)) ~0)          ; complex sum -> asum
   prodc (acfold '(\ acc x (* acc x)) ~1)         ; complex product -> aprod (complex mul!)
   _ (cks "sum  c     " (sumc cv)   (asum cv))     ; ~(1 2)+~(3 4) = ~(4 6)
   _ (cks "prod c     " (prodc cv)  (aprod cv))    ; ~(1 2)*~(3 4) = ~(-5 10)
   _ (dot (? (peep bad 0 0) (+ (show (peep bad 0 0)) " FAILED\n") "ALL PASS\n")))
