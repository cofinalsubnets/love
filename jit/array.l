; ============================================================================
; jit/array.l -- ARRAY KERNELS (roadmap step 4). A single-param (\ x <arith>)
; compiled to a RAW int64 kernel and applied to every cell of a z-array by the
; amap nif's tight C loop. This is where a JIT pays the most: the packed z-array
; is already an unboxed int64 C buffer, so the kernel is pure register arithmetic
; with no per-element dispatch or boxing.
;
; THE RAW CONTRACT (simpler than the scalar kernel): z-array cells are raw int64,
; and z-array arithmetic WRAPS at 64 bits (probed: a*a on a big cell gives the
; wrapped value, not the scalar's exact bignum). So the kernel takes the raw cell
; in %rdi, computes, and returns the raw result in %rax -- NO untag, NO overflow
; guard, NO 2R encoding. A wrapping native kernel matches love's elementwise ops
; EXACTLY, the wrap included.
;
; Ops: + - * and comparisons (< <= > >= =). // and % are deferred -- idiv #DE's on
; a zero cell, and z-array //0 semantics need their own handling.
;
; x86_64 host; load after jit/kernel.l (reuses leb, l2b):
;     out/host/love -l jit/kernel.l jit/array.l

; --- recognizer: a closed arith expr in the cell variables vs (1 or 2; no // %) ---
(: (arith-arr e vs)
   (? (symp e) (memq e vs)
      (&& (fixp e) (<= 0 e)) 1
      (&& (twop e) (= 1 (tally e))) (arith-arr (cap e) vs)    ; peel op-core's ((e)) wrapper
      (&& (twop e) (= 3 (tally e)) (memq (cap e) '(+ - * < <= > >= =)))
        (&& (arith-arr (caup e) vs) (arith-arr (caup (cup e)) vs))
      0))

; --- combine: rax (op)= rcx, RAW (no overflow guard -- z-array arith wraps) ---
(: (combine-arr op)
   (? (idp op '+) '(72 1 200)                   ; add  rax,rcx   (48 01 C8)
      (idp op '-) '(72 41 200)                  ; sub  rax,rcx   (48 29 C8)
      (idp op '*) '(72 15 175 193)              ; imul rax,rcx   (48 0F AF C1)
      (cat '(72 57 200)                         ; cmp rax,rcx                (48 39 C8)
       (cat (? (idp op '<)  '(15 156 192)       ; setl  al                   (0F 9C C0)
               (idp op '<=) '(15 158 192)       ; setle al                   (0F 9E C0)
               (idp op '>)  '(15 159 192)       ; setg  al                   (0F 9F C0)
               (idp op '>=) '(15 157 192)       ; setge al                   (0F 9D C0)
                            '(15 148 192))      ; sete  al  ('=)             (0F 94 C0)
            '(15 182 192)))))                   ; movzx eax,al               (0F B6 C0)

; --- cells arrive RAW in their arg registers (no untag): 1st->%rdi, 2nd->%rsi ---
(: arrx '(72 137 248)                           ; mov rax,rdi  (48 89 F8)
   arry '(72 137 240)                           ; mov rax,rsi  (48 89 F0)
   (vreg e regs) (? !regs () (idp e (cap (cap regs))) (cup (cap regs)) (vreg e (cup regs))))

; --- emit: bytes leaving e's value in rax ---
(: (emit-arr e regs)
   (? (symp e) (vreg e regs)                    ; a cell variable -> its raw register read
      (fixp e) (cons 72 (cons 184 (leb e 8)))   ; k: mov rax,imm64                        (48 B8 <le64>)
      (&& (twop e) (= 1 (tally e))) (emit-arr (cap e) regs)   ; peel op-core's ((e)) wrapper
      (: op (cap e) a (caup e) b (caup (cup e))
         (cat (emit-arr a regs)                 ; rax = A
          (cat '(80)                            ; push rax                                (50)
           (cat (emit-arr b regs)               ; rax = B
            (cat '(72 137 193  88)              ; mov rcx,rax ; pop rax (A)               (48 89 C1  58)
             (combine-arr op))))))))            ; rax = (A op B)

; --- driver: (\ x <arith>) -> (\ array -> array) via amap; (\ x y <arith>) ->
; (\ a b -> array) zipWith via amap2. Each cell computed natively, love allocates
; the matching output z-array. Non-jittable / wrong arity -> the source unchanged. ---
(: (ajit lam)
   (: rest (cup lam) body (last rest) ps (init rest) n (tally ps)
      (? (|| (< n 1) (> n 2)) lam
         !(all symp ps) lam
         !(arith-arr body ps) lam
         (: regs (? (= n 1) (list (cons (cap ps) arrx))
                            (list (cons (cap ps) arrx) (cons (caup ps) arry)))
            code (forge (l2b (cat (emit-arr body regs) '(195))))   ; ... ; ret (raw)
            (? (= n 1) (\ in   (: out (arr z (ashape in) 0) _ (amap  code in out)   out))
                       (\ a b  (: out (arr z (ashape a)  0) _ (amap2 code a b out) out)))))))

; ============================================================================
; SELF-CHECK: the native cellwise kernel must equal love's elementwise ops,
; including the int64 wrap. (aeq a b) = every cell equal.
(: bad (tablet 0)
   (aeq a b) (aall (a = b))
   (ck nm got want)
     (: ok (aeq got want)
        _ (dot (+ nm (+ ": " (+ (show got) (+ (? ok "  ==  " "  =/=  ") (+ (show want) (? ok "\n" "  FAIL\n")))))))
        (? ok 0 (pin bad 0 (+ 1 (peep bad 0 0)))))
   sqr  (ajit '(\ x (* x x)))
   inc1 (ajit '(\ x (+ x 1)))
   lin  (ajit '(\ x (- (* 2 x) 1)))
   lt3  (ajit '(\ x (< x 3)))
   big  (array 2 3037000500 3037000500)
   ; two-array zipWith (amap2): a-cell -> %rdi, b-cell -> %rsi
   zadd (ajit '(\ x y (+ x y)))
   zmad (ajit '(\ a b (+ (* a b) 1)))
   zlt  (ajit '(\ x y (< x y)))
   _ (ck "x*x   @1..5 " (sqr @(1 2 3 4 5))   (@(1 2 3 4 5) * @(1 2 3 4 5)))
   _ (ck "x+1   @10.. " (inc1 @(10 20 30))   (@(10 20 30) + 1))
   _ (ck "2x-1  @1..3 " (lin @(1 2 3))       ((@(1 2 3) * 2) - 1))
   _ (ck "x<3   @1..4 " (lt3 @(1 2 3 4))     (@(1 2 3 4) < 3))
   _ (ck "x*x wrap    " (sqr big)            (big * big))            ; both WRAP to the same int64
   _ (ck "a+b  zip    " (zadd @(1 2 3) @(10 20 30))   (@(1 2 3) + @(10 20 30)))
   _ (ck "a*b+1 zip   " (zmad @(2 3 4) @(5 6 7))      ((@(2 3 4) * @(5 6 7)) + 1))
   _ (ck "a<b  zip    " (zlt @(1 5 3) @(2 4 9))       (@(1 5 3) < @(2 4 9)))
   _ (dot (? (peep bad 0 0) (+ (show (peep bad 0 0)) " FAILED\n") "ALL PASS\n")))
