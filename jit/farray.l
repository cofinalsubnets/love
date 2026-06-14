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

; --- recognizer: a closed float-arith expr in the single cell variable v ---
(: (farith e v)
   (? (symp e) (idp e v)
      (&& (fixp e) (<= 0 e)) 1                   ; non-negative int literal -> cvtsi2sd
      (&& (twop e) (= 1 (tally e))) (farith (cap e) v)    ; peel op-core's ((e)) wrapper
      (&& (twop e) (= 3 (tally e)) (memq (cap e) '(+ - * /)))
        (&& (farith (caup e) v) (farith (caup (cup e)) v))
      0))

; --- combine: xmm0 (op)= xmm1 ---
(: (fcombine op)
   (? (idp op '+) '(242 15 88 193)               ; addsd xmm0,xmm1   (F2 0F 58 C1)
      (idp op '-) '(242 15 92 193)               ; subsd xmm0,xmm1   (F2 0F 5C C1)
      (idp op '*) '(242 15 89 193)               ; mulsd xmm0,xmm1   (F2 0F 59 C1)
                  '(242 15 94 193)))             ; divsd xmm0,xmm1   (F2 0F 5E C1)

; --- emit: bytes leaving e's value in xmm0 ---
(: (femit e v)
   (? (symp e) '(242 65 15 16 199)               ; the cell: movsd xmm0,xmm15  (F2 41 0F 10 C7)
      (fixp e) (cat (cons 72 (cons 184 (leb e 8)))   ; mov rax,imm64           (48 B8 <le64>)
                    '(242 72 15 42 192))         ; cvtsi2sd xmm0,rax           (F2 48 0F 2A C0)
      (&& (twop e) (= 1 (tally e))) (femit (cap e) v)   ; peel op-core's ((e)) wrapper
      (: op (cap e) a (caup e) b (caup (cup e))
         (cat (femit a v)                        ; xmm0 = A
          (cat '(72 131 236 8  242 15 17 4 36)   ; sub rsp,8 ; movsd [rsp],xmm0   (push A)
           (cat (femit b v)                      ; xmm0 = B
            (cat '(242 15 16 200                 ; movsd xmm1,xmm0  (xmm1 = B)    (F2 0F 10 C8)
                  242 15 16 4 36  72 131 196 8)  ; movsd xmm0,[rsp] ; add rsp,8   (pop A)
             (fcombine op))))))))                ; xmm0 = (A op B)

; --- driver: (\ x <arith>) -> (\ r-array -> r-array), each cell native (SSE) ---
(: (rjit lam)
   (: v (caup lam) body (caup (cup lam))
      (? !(&& (symp v) (farith body v)) lam
         (: code (forge (l2b (cat '(242 68 15 16 248)      ; prologue: movsd xmm15,xmm0  (save cell)
                              (cat (femit body v) '(195)))))  ; ... ; ret
            (\ in (: out (arr r (ashape in) 0) _ (armap code in out) out))))))

; ============================================================================
; SELF-CHECK: the native float kernel must equal love's elementwise r-array ops,
; bit-for-bit (same IEEE doubles). (aeq a b) = every cell equal.
(: bad (tablet 0)
   (aeq a b) (aall (a = b))
   (ck nm got want)
     (: ok (aeq got want)
        _ (dot (+ nm (+ ": " (+ (show got) (+ (? ok "  ==  " "  =/=  ") (+ (show want) (? ok "\n" "  FAIL\n")))))))
        (? ok 0 (pin bad 0 (+ 1 (peep bad 0 0)))))
   dd  (rjit '(\ x (+ x x)))
   x2  (rjit '(\ x (* x 2)))
   hlf (rjit '(\ x (/ x 2)))
   sqm (rjit '(\ x (- (* x x) 1)))
   inv (rjit '(\ x (/ x 0)))                      ; float /0 -> ieee-inf (no #DE)
   _ (ck "x+x   @1.5.. " (dd  @(1.5 2.5 3.5))  (@(1.5 2.5 3.5) + @(1.5 2.5 3.5)))
   _ (ck "x*2   @1.5.. " (x2  @(1.5 2.5))      (@(1.5 2.5) * 2))
   _ (ck "x/2   @3.0.. " (hlf @(3.0 5.0))      (@(3.0 5.0) / 2))
   _ (ck "x*x-1 @2.0.. " (sqm @(2.0 3.0))      ((@(2.0 3.0) * @(2.0 3.0)) - 1))
   _ (ck "x/0   @1.0   " (inv @(1.0))          (@(1.0) / 0))      ; @(ieee-inf)
   _ (dot (? (peep bad 0 0) (+ (show (peep bad 0 0)) " FAILED\n") "ALL PASS\n")))
