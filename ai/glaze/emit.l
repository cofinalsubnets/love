; emit -- the codegen backend: a love-level x86-64 emitter that compiles a love
; closure to NATIVE machine code and installs it as a TRANSPARENT applicable value.
; This is "ev but faster": the result applies by juxtaposition ((f x), no verb), is
; =/show IDENTICAL to its source, and DEOPTS to the interpreter on overflow -- so
; native is never wrong, only faster. The C seam is `nat` (ai.c): it W^X-installs
; the bytes and wraps them in a closure cell [code, src, code, interp, lvm_ret, 0]
; whose value[-1]=src (=/show) and value[1]=interp (the deopt fallback).
;
; ⚠ x86-64 ONLY (emits x86-64; load with -l on an x86-64 host). WIP toward the auto
; hook (ev installing native for hot regions, transparently); `nat` then goes
; internal (mopped like boxfix/feel) and there is no user-facing verb at all.
;
; grammar: (\ x E), E := x | int | (+/-/* E E) | (cmp E E) | (? E E E), cmp in
; < <= > >= = (-> 0/1 like the interpreter); ? is strictly-positive-test then/else.
; lvm ABI: g=rdi Ip=rsi Hp=rdx Sp=rcx. The body accumulates UNTAGGED in rax, the
; machine stack (push/pop) holds nested operands, r8 the popped temp; the loop uses
; r9=n r10=i r11=acc. Every +/-/* and the final putfix carry a `jno` over an inline
; deopt (mov rax,[rsi+8](=interp); mov rsi,rax; mov rax,[rsi]; jmp rax) -- a tail
; apply of interp to the original arg (still in Sp[0]). putfix is add rax,rax (its OF
; flag is exactly the 62-bit fixnum boundary); jno; or rax,1.
(: (le8 n) (: u (? (< n 0) (+ n 18446744073709551616) n)                            ; two's-complement; & is broken on
              ((: (go i) (? (< i 8) (link (% (// u (i 256)) 256) (go (+ i 1))) ())) 0))   ; a bignum >= 2^63, so use //% (n -> 8 LE bytes)
   (le4 n) ((: (go i) (? (< i 4) (link (& (>> n (* 8 i)) 255) (go (+ i 1))) ())) 0)  ; n -> 4 LE bytes (offsets < 2^31, & ok)
   deopt    '(72 139 70 8  72 137 198  72 139 6  255 224)   ; mov rax,[rsi+8]; mov rsi,rax; mov rax,[rsi]; jmp rax
   ; guard d / guardz d: skip the inline deopt unless OF (guard) / unless nonzero
   ; (guardz, for divide-by-zero); on deopt UNWIND d pending machine-stack operands
   ; (add rsp,8d) so the jmp-to-interp leaves rsp balanced -- else a mid-nest deopt
   ; leaks pushes and the terminator `ret` faults. deopt tail-applies interp(arg).
   (guard d)  ('(113 19 72 129 196) + (le4 (* 8 d)) + deopt)      ; jno +19; add rsp,8d; deopt
   (guardz d) ('(117 19 72 129 196) + (le4 (* 8 d)) + deopt)      ; jnz +19; add rsp,8d; deopt
   ld-i '(76 137 208)                                                           ; loop var i (raw, in r10)
   untag '(72 209 248)                                                           ; sar rax,1
   (fetch i) (? (= i 0)        '(72 139 1)                                       ; mov rax,[rcx]       (TAGGED, no untag)
                (< (* 8 i) 128) `(72 139 65 (8 * i))              ; mov rax,[rcx+disp8]
                                ('(72 139 129) + (le4 (* 8 i))))               ; mov rax,[rcx+disp32]
   ; FIXNUM INPUT GUARD: native arithmetic assumes fixnums (sar/imul/idiv), so a
   ; NON-fixnum arg (an even/heap word -- a list, mint, the zero point, ...) must DEOPT
   ; to the bytecode body, which dispatches generically. The overflow guard only catches
   ; a fixnum RESULT leaving range, never a bad INPUT. test al,1 (fixnum = odd); a clear
   ; low bit (even) falls through to the deopt -- structurally a guardz (jnz over it).
   (fxv  i d) ((fetch i) + '(168 1) + (guardz d)    + untag)           ; nat deopt (interp value[0])
   (fxmn i d) ((fetch i) + '(168 1) + (guardz-mn d) + untag)           ; natn deopt (interp body)
   push-rax '(80)   pop-r8 '(65 88)
   epilogue
    ; add rax,rax;guard;or rax,1;mov[rcx]
    ; add rsi,16; Continue
    ('(72 1 192) + (guard 0) + '(72 131 200 1 72 137 1 72 131 198 16 72 139 6 255 224))
   (opseq op d) (? (= op '+) (pop-r8 + '(76 1 192) + (guard d))            ; add rax,r8 ; guard
                   (= op '*) (pop-r8 + '(73 15 175 192) + (guard d))       ; imul rax,r8 ; guard
                   (= op '-) (pop-r8 + '(73 41 192) + (guard d) + '(76 137 192))  ; sub r8,rax;guard;mov rax,r8
                   ())
   ; // and %: a in r8 (dividend), b in rax (divisor) -> rax; preserves rdx(=Hp) via
   ; the machine stack; divide-by-zero deopts (guardz). idiv truncates toward 0, the
   ; remainder takes the dividend's sign -- matching love's // and %.
   (idivseq op d) (+ pop-r8 (+ '(72 133 192) (+ (guardz d)                 ; a->r8; test rax,rax (==0 -> deopt)
     (+ '(82 80 76 137 192 72 153 72 247 60 36)                                ; push rdx;push rax;mov rax,r8;cqo;idiv [rsp]
       (+ (? (= op '%) '(72 137 208) ()) '(72 131 196 8 90))))))                ; (% mov rax,rdx); add rsp,8; pop rdx
   ; bitwise: a in r8, b in rax -> rax = a OP b (fixnum operands stay <=62-bit, no guard)
   (bitseq op) (+ pop-r8 (? (= op '&) '(76 33 192) (= op '|) '(76 9 192) (= op '^) '(76 49 192) ()))  ; and/or/xor rax,r8
   ; comparison: a in r8, b in rax -> rax = (a OP b) ? 1 : 0 (0/1, no deopt)
   (setcc op) (? (= op '<) '(15 156 192) (= op '<=) '(15 158 192) (= op '>) '(15 159 192)
                 (= op '>=) '(15 157 192) (= op '=) '(15 148 192) ())             ; setcc al
   (cmpseq op) (+ pop-r8 (+ '(73 57 192) (+ (setcc op) '(72 15 182 192)))) ; cmp r8,rax; setcc al; movzx rax,al
   ; (? test then else): test>0 -> then else else (love truth = strictly positive)
   (condcode tb thb elb) (: Lt (tally thb) Le (tally elb)
     (+ tb (+ '(72 131 248 0)                                                ; cmp rax,0
       (+ (+ '(15 142) (le4 (+ Lt 5)))                                       ; jle else (skip then + jmp)
         (+ thb (+ (+ '(233) (le4 Le)) elb))))))                           ; then ; jmp end ; else
   (cgv v vl e d) (? (= e v)  (vl d)                                             ; vl = a load FN of d (leaf guards, loop counter doesn't)
                     (whole? e) (+ '(72 184) (le8 e))                            ; movabs rax, n
                     (two? e) (: op (cap e)  a (caup e)  b (caup (cup e))
                                 (? (member? op '(+ - *))      (+ (cgv v vl a d) (+ push-rax (+ (cgv v vl b (+ d 1)) (opseq op d))))
                                    (member? op '(// %))        (+ (cgv v vl a d) (+ push-rax (+ (cgv v vl b (+ d 1)) (idivseq op d))))
                                    (member? op '(& | ^))       (+ (cgv v vl a d) (+ push-rax (+ (cgv v vl b (+ d 1)) (bitseq op))))
                                    (member? op '(< <= > >= =)) (+ (cgv v vl a d) (+ push-rax (+ (cgv v vl b (+ d 1)) (cmpseq op))))
                                    (= op '?) (condcode (cgv v vl a d) (cgv v vl b d) (cgv v vl (caup (cup (cup e))) d))
                                    ()))
                     ())
   (emit l) (: b (cask (tally l)) _ ((: (go i x) (? (two? x) (: _ (pin b i (cap x)) (go (+ i 1) (cup x))) ())) 0 l) b)
   ; (jit '(\ x E)) -- compile an arithmetic single-arg closure to native.
   (jit lam) (: v (caup lam) (nif (emit (+ (cgv v (\ d (fxv 0 d)) (caup (cup lam)) 0) epilogue)) (ev lam) lam 1))  ; v = the param (single arg at Sp[0], fixnum-guarded)
   ; --- N-ary leaves (\ p0 .. p_{n-1} E): param i loads from Sp[i]=[rcx+8i]; the deopt
   ; jmps to interp's BODY (deopt-mn, interp+16 past its lvm_cur) where the saturated
   ; args already sit -- so the deopt/epilogue/return below are all arity-INDEPENDENT
   ; and serve EVERY arity>=2 (only the per-param arg load varies, by frame index).
   deopt-mn '(72 139 70 8  72 141 112 16  72 139 6  255 224)  ; mov rax,[rsi+8]; lea rsi,[rax+16]; mov rax,[rsi]; jmp rax
   (guard-mn d)  (+ '(113 20) (+ (+ '(72 129 196) (le4 (* 8 d))) deopt-mn))   ; jno +20; add rsp,8d; deopt-mn
   (guardz-mn d) (+ '(117 20) (+ (+ '(72 129 196) (le4 (* 8 d))) deopt-mn))   ; jnz +20; ...
   epilogue-mn (+ '(72 1 192) (+ (guard-mn 0) (+ '(72 131 200 1) (+ '(72 137 1)
                 (+ '(72 131 198 16) '(72 139 6  255 224))))))
   (opseq-mn op d) (? (= op '+) (+ pop-r8 (+ '(76 1 192) (guard-mn d)))
                      (= op '*) (+ pop-r8 (+ '(73 15 175 192) (guard-mn d)))
                      (= op '-) (+ pop-r8 (+ '(73 41 192) (+ (guard-mn d) '(76 137 192)))) ())
   (idivseq-mn op d) (+ pop-r8 (+ '(72 133 192) (+ (guardz-mn d)
     (+ '(82 80 76 137 192 72 153 72 247 60 36) (+ (? (= op '%) '(72 137 208) ()) '(72 131 196 8 90))))))
   ; param i -> frame index in [imps args]; loaded fixnum-guarded from Sp[i] (param 0 is
   ; the FIRST capture when partial-applied). argix finds a var's frame index in ps.
   (argix e ps i) (? !(two? ps) 0  (= e (cap ps)) i  (argix e (cup ps) (+ i 1)))   ; param -> index
   (cgn ps e d) (? (whole? e) (+ '(72 184) (le8 e))                       ; movabs rax, n
                   (two? e) (: op (cap e)  a (caup e)  b (caup (cup e))
                               (? (member? op '(+ - *))      (+ (cgn ps a d) (+ push-rax (+ (cgn ps b (+ d 1)) (opseq-mn op d))))
                                  (member? op '(// %))        (+ (cgn ps a d) (+ push-rax (+ (cgn ps b (+ d 1)) (idivseq-mn op d))))
                                  (member? op '(& | ^))       (+ (cgn ps a d) (+ push-rax (+ (cgn ps b (+ d 1)) (bitseq op))))
                                  (member? op '(< <= > >= =)) (+ (cgn ps a d) (+ push-rax (+ (cgn ps b (+ d 1)) (cmpseq op))))
                                  (= op '?) (condcode (cgn ps a d) (cgn ps b d) (cgn ps (caup (cup (cup e))) d))
                                  ()))
                   (fxmn (argix e ps 0) d))                               ; else: a param var (fixnum-guarded)
   ; (jitn '(\ p0 .. body)) -- an arity>=2 leaf -> native (natn curries to saturation).
   (jitn lam) (: ps (init (cup lam))  body (last (cup lam))
                 (nif (emit (+ (cgn ps body 0) epilogue-mn)) (ev lam) lam (tally ps)))
   (jit2 lam) (jitn lam)                                                  ; arity-2 alias (self-test/auto.l)
   ; --- counted fold loop: acc = (FOLD over cv<n of body(cv)), cv the counter, limit
   ; at Sp[0]. r9=n r10=cv r11=acc. FOLD is a (op . init) -- + folds from 0, * from 1 --
   ; and cmp is the loop test's comparison (the loop runs while (cmp cv n)). offsets are
   ; COMPUTED from the piece lengths, not hardcoded, so a longer acc op (imul) is fine.
   acc-add '(73 1 195)            acc-mul '(76 15 175 216)        ; add r11,rax / imul r11,rax
   (r11-init a0) (? (= a0 0) '(77 49 219) (+ '(73 199 195) (le4 a0)))   ; xor r11,r11 / mov r11,a0
   (foldbytes op) (? (= op '+) acc-add (= op '*) acc-mul ())
   (foldinit op)  (? (= op '*) 1 0)                               ; * folds from 1, + from 0
   ; END jcc = the INVERSE of the continue-comparison (exit when (cmp cv n) is false).
   (loopjcc cmp) (? (= cmp '<) '(15 141) (= cmp '<=) '(15 143) (= cmp '>) '(15 142)
                    (= cmp '>=) '(15 140) (= cmp '=) '(15 133) ())  ; jge/jg/jle/jl/jne
   (loopcode body cv op cmp)
    (: lb   (cgv cv (\ d ld-i) body 0)  Lb (tally lb)
       acc  (+ (foldbytes op) (guard 0))  La (tally acc)        ; r11 = r11 op rax ; overflow -> deopt
       pre  (+ '(76 139 9  73 209 249  77 49 210) (r11-init (foldinit op)))    ; mov r9,[rcx];sar;xor r10; init r11
       test (asm (L '(77 57 202) (loopjcc cmp) (le4 (+ (+ Lb La) 8))))       ; cmp r10,r9 ; <inverse-cmp> end
       back (asm (L '(73 255 194) '(233) (le4 (- 0 (+ (+ Lb La) 17)))))      ; inc r10 ; jmp loop_top
       (asm (L pre test lb acc back '(76 137 216) epilogue)))   ; ... ; mov rax,r11
   ; (jitsum body) -- compile (\ n (sum_{i<n} body(i))) to a native counted loop.
   (jitsum body)
    (: src `('\ 'n `(`(': `('go 'i 'a) `('? `('< 'i 'n) `('go `('+ 'i 1) `('+ 'a body)) 'a)) 0 0))
       (nif (emit (loopcode body 'i '+ '<)) (ev src) src 1))
   ; --- N-VARIABLE loop: the general tail-recursive counted loop ------------------
   ; (\ n ((: (go v0..vk) (? TEST (go U0..Uk) RESULT)) I0..Ik)), up to 3 loop vars in
   ; r9/r10/r11 (RAW), the param n the tagged Sp[0] (fxv-guarded). each iteration: if
   ; TEST, compute EVERY Uj from the OLD regs -- push all, then pop into the regs in
   ; reverse -- so the updates read pre-update values (e.g. fib's `b` and `a+b`); else
   ; RESULT. r9/r10/r11 survive the expr scratch (rax/r8/stack), so no save needed.
   (reg-ld j)   (? (= j 0) '(76 137 200) (= j 1) '(76 137 208) (= j 2) '(76 137 216) ())  ; mov rax, r9/r10/r11
   (reg-init j) (? (= j 0) '(73 199 193) (= j 1) '(73 199 194) (= j 2) '(73 199 195) ())  ; mov r9/r10/r11, imm32
   (reg-pop j)  (? (= j 0) '(65 89) (= j 1) '(65 90) (= j 2) '(65 91) ())                 ; pop r9/r10/r11
   ; cgl: an expr over {n (the fxv'd param) ; v0..vk (raw loop-var registers)} -> rax.
   (cgl n vars e d)
    (? (= e n)        (fxv 0 d)                                  ; the param: guarded Sp[0] load (untag)
       (member? e vars)  (reg-ld (argix e vars 0))                  ; a loop var: raw register
       (whole? e)       (+ '(72 184) (le8 e))                    ; movabs
       (two? e) (: op (cap e)  a (caup e)  b (caup (cup e))
                   (? (member? op '(+ - *))      (+ (cgl n vars a d) (+ push-rax (+ (cgl n vars b (+ d 1)) (opseq op d))))
                      (member? op '(// %))        (+ (cgl n vars a d) (+ push-rax (+ (cgl n vars b (+ d 1)) (idivseq op d))))
                      (member? op '(& | ^))       (+ (cgl n vars a d) (+ push-rax (+ (cgl n vars b (+ d 1)) (bitseq op))))
                      (member? op '(< <= > >= =)) (+ (cgl n vars a d) (+ push-rax (+ (cgl n vars b (+ d 1)) (cmpseq op))))
                      (= op '?) (condcode (cgl n vars a d) (cgl n vars b d) (cgl n vars (caup (cup (cup e))) d))
                      ()))
       ())
   (loopcode-n n vars updates test result inits)
    (: pre  ((: (go j is) (? (two? is) (+ (+ (reg-init j) (le4 (cap is))) (go (+ j 1) (cup is))) ())) 0 inits)
       ups  ((: (go j us) (? (two? us) (+ (+ (cgl n vars (cap us) j) push-rax) (go (+ j 1) (cup us))) ())) 0 updates)  ; push Uj at depth j
       pops ((: (go j) (? (< j 0) () (+ (reg-pop j) (go (- j 1))))) (- (tally updates) 1))   ; pop reg(k-1)..reg(0)
       ub   (+ ups pops)  Lu (tally ub)
       tb   (cgl n vars test 0)  Lt (tally tb)
       rb   (cgl n vars result 0)
       top  (asm (L tb '(72 131 248 0) '(15 132) (le4 (+ Lu 5))))   ; <test>; cmp rax,0; je end
       back (+ '(233) (le4 (- 0 (+ (+ Lt Lu) 15))))                       ; jmp top
       (asm (L pre top ub back rb epilogue)))
   ; (jitloop-n lam vars updates test result inits) -- a general N-var loop -> native.
   (jitloop-n lam vars updates test result inits)
    (nif (emit (loopcode-n (caup lam) vars updates test result inits)) (ev lam) lam 1)
   ; --- FLOAT lane (SSE) -- unboxed doubles in xmm ------------------------------
   ; the LuaJIT lever: keep float values in registers, never boxed. xmm0 is the float
   ; accumulator; a nested operand spills to the machine stack (movsd [rsp]). peek is
   ; mopped, so a float CONSTANT is materialized arithmetically -- fbits computes its
   ; IEEE-754 bits (the 52-bit mantissa makes frac*2^52 EXACT, no rounding). LANE LAW:
   ; the float lane carries NO overflow guard (doubles saturate to inf, never promote
   ; to bignum); only the INTEGER lane keeps the jno->deopt that preserves bignum
   ; promotion. this first cut: a float PREDICATE leaf (\ x (cmp <fexpr> <fexpr>)) over
   ; a FIXNUM arg -> 0/1 -- no gem args (deferred: needs the lvm_flo type guard), no
   ; float result (deferred: needs a Have-checked box). a non-fixnum arg DEOPTS (fxv).
   (fbits x)                                                          ; finite double -> its IEEE-754 u64 bits
    (? (= x 0.0) 0
       (: s (? (< x 0.0) 1 0) ax (? (< x 0.0) (- 0.0 x) x)
          eu ((: (go e) (? (<= ((+ e 1) 2.0) ax) (go (+ e 1)) e)) (int (/ (log ax) (log 2.0))))   ; raise (log error)
          e  ((: (go e) (? (< ax (e 2.0)) (go (- e 1)) e)) eu)                                     ; lower
          (+ (* s 9223372036854775808) (+ (* (+ e 1023) 4503599627370496)
             (int (* (- (/ ax (e 2.0)) 1.0) 4503599627370496.0))))))
   xpush '(72 131 236 8 242 15 17 4 36)                              ; sub rsp,8 ; movsd [rsp],xmm0
   xpop1 '(242 15 16 12 36 72 131 196 8)                             ; movsd xmm1,[rsp] ; add rsp,8
   (fconst c) (+ '(72 184) (+ (le8 (fbits c)) '(102 72 15 110 192))) ; movabs rax,bits ; movq xmm0,rax
   (fbinop op) (? (= op '+) '(242 15 88 193)                         ; addsd xmm0,xmm1
                  (= op '*) '(242 15 89 193)                         ; mulsd xmm0,xmm1
                  (= op '-) '(242 15 92 200 242 15 16 193)           ; subsd xmm1,xmm0 ; movsd xmm0,xmm1
                  (= op '/) '(242 15 94 200 242 15 16 193)           ; divsd xmm1,xmm0 ; movsd xmm0,xmm1
                  ())
   (fsetcc op) (? (= op '<) '(15 146 192) (= op '<=) '(15 150 192) (= op '>) '(15 151 192)
                  (= op '>=) '(15 147 192) (= op '=) '(15 148 192) ())   ; setb/setbe/seta/setae/sete al
   ; cgf: a FLOAT subexpr over {x (the fixnum param -> cvtsi2sd) ; numeric consts} -> xmm0
   (cgf v e d) (? (= e v)   (+ (fxv 0 d) '(242 72 15 42 192))        ; param: fixnum-guarded load + cvtsi2sd
                  (gem? e)  (fconst e)                               ; a float constant
                  (whole? e)(fconst (+ e 0.0))                       ; an int constant -> promote to double
                  (two? e) (: op (cap e) a (caup e) b (caup (cup e))
                     (? (member? op '(+ - * /)) (+ (cgf v a d) (+ xpush (+ (cgf v b (+ d 1)) (+ xpop1 (fbinop op))))) ()))
                  ())
   ; cgfp: a float PREDICATE (cmp A B) -> rax 0/1 (A->xmm1, B->xmm0; ucomisd)
   (cgfp v e d) (: op (cap e) a (caup e) b (caup (cup e))
      (+ (cgf v a d) (+ xpush (+ (cgf v b (+ d 1)) (+ xpop1
         (+ '(102 15 46 200) (+ (fsetcc op) '(72 15 182 192))))))))   ; ucomisd xmm0,xmm1 ; setcc al ; movzx rax,al
   ; (jitf '(\ x (cmp <fexpr> <fexpr>))) -- a float predicate over a fixnum arg -> native 0/1.
   (jitf lam) (: v (caup lam) (nif (emit (+ (cgfp v (caup (cup lam)) 0) epilogue)) (ev lam) lam 1))
   ; --- FLOAT RECURRENCE LOOP OWNER (the mandelbrot escape-loop class) ----------
   ; owns a numeric escape loop end to end: FIXNUM inputs (pixel coords) -> derived
   ; floats (computed once) -> a float recurrence over loop-vars in xmm8.. with an
   ; INTEGER counter, a compound escape test (counter < lim AND a float predicate),
   ; returning the COUNT (an integer -- no box). this is where owning the whole loop
   ; pays (vs a per-pixel leaf that re-boxes + re-crosses the boundary). cgF is the
   ; float-expr compiler over a multi-register env: float locals in xmm8.. (fload),
   ; int params via cvtsi2sd, constants via fconst. the counter is bounded (it<lim)
   ; so it needs no overflow guard; an int ACCUMULATOR would (the lane law) -- the
   ; count here can't overflow a fixnum. xmm0/xmm1 + [rsp] stay the float scratch.
   (fload j)  (+ '(242 65 15 16) (list (+ 192 j)))                   ; movsd xmm0, xmm(8+j)
   (fstore j) (+ '(242 68 15 16) (list (+ 192 (* 8 j))))             ; movsd xmm(8+j), xmm0
   (fzero j)  (+ '(102 69 15 87) (list (+ 192 (* 9 j))))             ; xorpd xmm(8+j), xmm(8+j)
   (fpop j)   (+ '(242 68 15 16) (+ (list (+ 4 (* 8 j))) '(36 72 131 196 8)))   ; movsd xmm(8+j),[rsp] ; add rsp,8
   (alook k al i) (? (atom? al) -1 (= k (cap al)) i (alook k (cup al) (+ i 1)))
   (clook k ce) (? (atom? ce) () (= k (caap ce)) (cap ce) (clook k (cup ce)))   ; counter env: name -> (name regbytes)
   ; --- CONSTANT HOISTING: peek is mopped so a float constant costs a movabs+movq to materialize;
   ;     re-emitting that inside a loop body is the dominant cost. so collect the DISTINCT float
   ;     constants of a kernel, preload each into a dedicated xmm reg (xmm2..7, free -- scratch is
   ;     xmm0/xmm1, locals xmm8..) ONCE before the loops, and reference the register (movsd xmm0,xmm_r)
   ;     in the body. >6 distinct constants spill back to inline fconst (graceful).
   (memv? v l) (? (atom? l) 0 (= v (cap l)) 1 (memv? v (cup l)))
   (fcc e acc) (? (gem? e) (? (memv? e acc) acc (link e acc))                    ; collect distinct constants of e
                  (whole? e) (: v (+ e 0.0) (? (memv? v acc) acc (link v acc)))
                  (two? e) (fcc (caup (cup e)) (fcc (caup e) acc))
                  acc)
   (fccl es acc) (? (two? es) (fccl (cup es) (fcc (cap es) acc)) acc)            ; collect over a list of exprs
   (htbl cs i) (? (atom? cs) () (> i 7) () (link (L (cap cs) i) (htbl (cup cs) (+ i 1))))   ; value -> reg (2..7)
   (hlook v ht) (? (atom? ht) -1 (= v (caap ht)) (caup (cap ht)) (hlook v (cup ht)))
   (hpre ht) (? (atom? ht) () (: e (cap ht)                                      ; preload: movabs bits,rax ; movq xmm_r,rax
      (+ (+ '(72 184) (+ (le8 (fbits (cap e))) (+ '(102 72 15 110) (list (+ 192 (* 8 (caup e))))))) (hpre (cup ht)))))
   (hcon v ht) (: r (hlook v ht) (? (< -1 r) (+ '(242 15 16) (list (+ 192 r))) (fconst v)))   ; hoisted -> movsd xmm0,xmm_r ; else inline
   ; register-scratch spill/reload for the float-expr stack: xmm12..15 hold nesting depth 0..3 (no
   ; memory traffic), falling back to the [rsp] xpush/xpop1 below depth 4. THIS is the win -- the
   ; inner loop's nested operands stay in registers instead of round-tripping through memory.
   (rpush d) (? (< d 4) (+ '(242 68 15 16) (list (+ 224 (* 8 d)))) xpush)   ; movsd xmm(12+d),xmm0 ; else sub rsp;movsd[rsp]
   (rpop d)  (? (< d 4) (+ '(242 65 15 16) (list (+ 204 d)))       xpop1)   ; movsd xmm1,xmm(12+d) ; else movsd[rsp];add rsp
   ; --- the OPTIMIZING float-body allocator: value-numbered DAG (CSE) + linear-scan register
   ;     allocation. compiles a SET of root exprs (the inner-loop mag + the fvar updates, which
   ;     SHARE subexprs like zx*zx) to register-only SSE, each value in its own xmm reg so the CPU
   ;     runs independent ops in parallel (ILP). leaves (fvars/consts) live in fixed regs (env);
   ;     binop results allocate from the working pool {0,1,12..15}, freed at last use, reused in
   ;     place where an operand dies -- exactly what the hand kernel did, which cgF above does not.
   (snoc l x) (cat l (list x))
   (nthl l i) (? (= i 0) (cap l) (nthl (cup l) (- i 1)))
   (dfind nd dag i) (? (atom? dag) -1 (= nd (cap dag)) i (dfind nd (cup dag) (+ i 1)))   ; CSE: existing node?
   (dadd nd dag) (: i (dfind nd dag 0) (? (< -1 i) (L i dag) (L (tally dag) (snoc dag nd))))
   (vnum e dag) (? (two? e) (: ra (vnum (caup e) dag) rb (vnum (caup (cup e)) (caup ra))
                              (dadd (L (cap e) (cap ra) (cap rb)) (caup rb)))            ; binop: (op vn-a vn-b)
                            (dadd (L 'L e 0) dag))                                       ; leaf: (L datum 0)
   (vnall rs dag acc) (? (two? rs) (: r (vnum (cap rs) dag) (vnall (cup rs) (caup r) (snoc acc (cap r)))) (L acc dag))
   (binop? dag v) (! (id? (cap (nthl dag v)) 'L))
   (luse v dag rv n) ((: (go i ds best) (? (atom? ds) (? (member? v rv) n best)         ; last index using v (roots live to n)
       (go (+ i 1) (cup ds) (? (&& (binop? dag i) (|| (= v (caup (cap ds))) (= v (caup (cup (cap ds)))))) i best)))) 0 dag -1)
   (dies? v i dag rv n) (&& (binop? dag v) (&& (= (luse v dag rv n) i) (! (member? v rv))))
   (opc op) (? (id? op 'mov) 16 (id? op '+) 88 (id? op '*) 89 (id? op '-) 92 (id? op '/) 94 ())   ; movsd/addsd/mulsd/subsd/divsd
   (sse op dst src) (L 242 (+ 64 (+ (? (> dst 7) 4 0) (? (> src 7) 1 0))) 15 (opc op) (+ 192 (+ (* 8 (% dst 8)) (% src 8))))
   (ucom a b) (L 102 (+ 64 (+ (? (> a 7) 4 0) (? (> b 7) 1 0))) 15 46 (+ 192 (+ (* 8 (% a 8)) (% b 8))))   ; ucomisd a,b (a-b)
   (rgof leaf env) (: e (clook leaf env) (? (two? e) (caup e) (scare 'glaze-leaf leaf)))   ; leaf -> its fixed reg
   (asm ps) (foldl (\ a b (+ a b)) () ps)                                                  ; concat a LIST of byte pieces (+ is associative)
   (efold names i) (? (two? names) (link (L (cap names) i) (efold (cup names) (+ i 1))) ())   ; names -> (name reg) from reg i
   (alloc dag rv env n pool)                                                             ; -> (code . regof-tablet); pool = the free working xmm regs
    (: rg (tablet 0) pl (tablet 0) _ (pin pl 'p pool)
       (pop u) (: p (peep pl 'p ()) _ (pin pl 'p (cup p)) (cap p))
       (push r) (pin pl 'p (link r (peep pl 'p ())))
       code ((: (go i acc) (? (= i n) acc
          (: nd (nthl dag i)
             (? (id? (cap nd) 'L) (: _ (pin rg i (rgof (caup nd) env)) (go (+ i 1) acc))   ; leaf: fixed reg, no code
                (: op (cap nd) a (caup nd) b (caup (cup nd)) ra (peep rg a 0) rb (peep rg b 0)
                   adie (dies? a i dag rv n) bdie (dies? b i dag rv n)
                   dst (? adie ra (pop 0))                                                 ; reuse a's reg if a dies
                   _ (? (&& bdie (! (= rb dst))) (push rb) 0) _ (pin rg i dst)             ; free b if it dies
                   (go (+ i 1) (+ acc (+ (? (= dst ra) () (sse 'mov dst ra)) (sse op dst rb))))))))) 0 ())
       (L code rg))
   ; cgF: a FLOAT subexpr -> xmm0, over the hoist table ht + THREE envs: fe (float locals in xmm8..,
   ; fload), ce (int loop-COUNTERS in raw regs -> cvtsi2sd), ie (int Sp params -> fxv+cvtsi2sd).
   (cgF ht ce ie fe e d) (? (gem? e)   (hcon e ht)
                            (whole? e) (hcon (+ e 0.0) ht)
                            (atom? e)  (: fj (alook e fe 0)
                               (? (< -1 fj) (fload fj)
                                  (: cb (clook e ce) (? (two? cb) (caup cb)               ; loop counter (raw reg) -> cvtsi2sd
                                     (: ai (alook e ie 0) (? (< -1 ai) (+ (fxv ai d) '(242 72 15 42 192)) ()))))))   ; Sp param
                            (two? e) (: op (cap e) a (caup e) b (caup (cup e))
                               (? (member? op '(+ - * /)) (+ (cgF ht ce ie fe a d) (+ (rpush d) (+ (cgF ht ce ie fe b (+ d 1)) (+ (rpop d) (fbinop op))))) ()))
                            ())
   (ucmp-exit op) (? (= op '<=) '(15 135) (= op '<) '(15 131) (= op '>=) '(15 134) (= op '>) '(15 130) ())   ; EXIT jcc = inverse of the continue cmp
   (loopcode-f ips finit fvars updates testexpr cmpop bound lim)
    (: nf (tally finit)  fenv (cat (map cap finit) fvars)
       ht (htbl (fcc bound (fccl updates (fcc testexpr (fccl (map (\ f (caup (cap f))) finit) ())))) 2)
       pre-d ((: (go j fs) (? (two? fs) (+ (+ (cgF ht () ips fenv (caup (cap fs)) 0) (fstore j)) (go (+ j 1) (cup fs))) ())) 0 finit)
       pre-z ((: (go j) (? (< j (tally fvars)) (+ (fzero (+ nf j)) (go (+ j 1))) ())) 0)
       pre   (asm (L pre-d pre-z '(77 49 192)))                     ; xor r8,r8  (counter it = 0)
       tint  (+ '(73 131 248) (list lim))                           ; cmp r8, lim
       tflt  (asm (L (cgF ht () ips fenv testexpr 0) (rpush 0) (hcon bound ht) (rpop 0) '(102 15 46 200)))   ; mag ; bound ; ucomisd
       ups   ((: (go us) (? (two? us) (+ (+ (cgF ht () ips fenv (cap us) 0) xpush) (go (cup us))) ())) updates)
       pops  ((: (go j) (? (< j nf) () (+ (fpop j) (go (- j 1))))) (+ nf (- (tally fvars) 1)))
       body  (asm (L ups pops '(73 255 192)))                       ; ... ; inc r8
       Lb (tally body)  Lt (tally tflt)
       jge (+ '(15 141) (le4 (+ (+ Lt 6) (+ Lb 5))))                ; counter exit: jge EXIT  (skip tflt+exj+body+back)
       exj (+ (ucmp-exit cmpop) (le4 (+ Lb 5)))                     ; float  exit: skip body+back
       back (+ '(233) (le4 (- 0 (+ (+ (+ (+ (+ 4 6) Lt) 6) Lb) 5))))   ; jmp TOP
       (asm (L (hpre ht) pre tint jge tflt exj body back '(76 137 192))))   ; preload consts; EXIT: mov rax,r8
   ; (jitfrec src '(px py) finit fvars updates testexpr cmpop bound lim) -> native pixel kernel.
   (jitfrec lam ips finit fvars updates testexpr cmpop bound lim)
    (nif (emit (+ (loopcode-f ips finit fvars updates testexpr cmpop bound lim) epilogue-mn)) (ev lam) lam (tally ips))
   ; --- NESTED GRID OWNER (general, D-dimensional): own a WHOLE counted-loop NEST as ONE native
   ;     kernel -- D nested integer loops over fixnum coords -> M derived-float invariants -> a float
   ;     recurrence over N float-vars, accumulating an integer count -- one boundary crossing per grid,
   ;     not one per cell. Mandelbrot's 64x64 grid is the D=2,M=2,N=2 instance; this handles any D>=1
   ;     and any M,N within the xmm budget (M+N<=6). REGISTERS: counters r10.., invariants xmm8..,
   ;     fvars next, hoisted consts xmm2..7, the inner recurrence's working pool = the leftover xmm.
   ;     r12.. are CALLEE-SAVED (D>=3) -> push/pop, and the acc-overflow deopt restores them. The acc
   ;     (r9) add is GUARDED (lane law -- overflow deopts to the interp nest -> bignum); counters and
   ;     the float lane need no guard. arity 1 (a dummy arg ignored), integer checksum out. offsets COMPUTED.
   (rangeL a b) (? (< a b) (link a (rangeL (+ a 1) b)) ())
   (map2 f a b) (? (two? a) (link (f (cap a) (cap b)) (map2 f (cup a) (cup b))) ())
   (xorR r)    (L 77 49 (+ 192 (* 9 (- r 8))))                 ; xor r,r   (r8-15)
   (incR r)    (L 73 255 (+ 192 (- r 8)))                      ; inc r
   (cmpRi r n) (+ (L 73 129 (+ 248 (- r 8))) (le4 n))          ; cmp r, imm32
   (cvtcnt r)  (L 242 73 15 42 (+ 194 (- r 10)))               ; cvtsi2sd xmm0, r   (r10-15)
   (pushR r)   (L 65 (+ 80 (- r 8)))                           ; push r   (r8-15)
   (popR r)    (L 65 (+ 88 (- r 8)))                           ; pop r
   ; cgFd: a derive expr over the COUNTER env ce (int loop counters -> cvtsi2sd) + hoisted consts,
   ; using [rsp] scratch (xpush/xpop1) so it never touches an xmm8.. local reg -- run once per cell
   ; (cold), so memory scratch costs nothing measurable.
   (cgFd ht ce e) (? (gem? e)   (hcon e ht)
                     (whole? e) (hcon (+ e 0.0) ht)
                     (atom? e)  (: cb (clook e ce) (? (two? cb) (caup cb) ()))
                     (two? e)   (: op (cap e) a (caup e) b (caup (cup e))
                                   (? (member? op '(+ - * /)) (+ (cgFd ht ce a) (+ xpush (+ (cgFd ht ce b) (+ xpop1 (fbinop op))))) ()))
                     ())
   ; guard-acc: the acc-overflow guard. D<3 -> the plain guard (counters are caller-saved). D>=3 ->
   ; pop the callee-saved counters (r12..) before the deopt, so the interp nest sees an ABI-clean frame.
   (guard-acc D) (? (< D 3) (guard 0)
                    (: pp (foldl (\ a r (+ a (popR r))) () (rev (rangeL 12 (+ 10 D))))
                       (+ (L 113 (+ (tally pp) (tally deopt))) (+ pp deopt))))   ; jno over (pops + deopt)
   ; loopwrap: wrap `inner` in one counted loop -- init counter cr=0; LTOP: cmp cr,bnd; jge EXIT;
   ; <inner>; inc cr; jmp LTOP; EXIT. Offsets COMPUTED from (tally inner), so it nests to any depth.
   (loopwrap cr bnd inner)
    (: Li (tally inner)
       (asm (L (xorR cr)                                       ; init counter = 0
               (cmpRi cr bnd)                                  ; LTOP: cmp cr, bnd
               (+ (L 15 141) (le4 (+ Li 8)))                   ; jge EXIT  (skip inner + inc(3) + jmp(5))
               inner
               (incR cr)                                       ; inc cr
               (+ (L 233) (le4 (- 0 (+ Li 21)))))))            ; jmp LTOP  (back over cmp(7)+jge(6)+inner+inc(3)+jmp(5))
   (nest loops inner) (? (atom? loops) inner
                         (loopwrap (caap loops) (cuap loops) (nest (cup loops) inner)))
   (loopcode-gridn dims cnames invs invd fvars updates testexpr cmpop bound lim)
    (: D (tally dims)  M (tally invs)  N (tally fvars)
       cregs (rangeL 10 (+ 10 D))                                              ; counter regs r10..r(9+D), outer->inner
       saved (rangeL 12 (+ 10 D))                                              ; the callee-saved counters among them (r12..)
       fenv (cat invs fvars)
       cenv (map2 (\ nm r (L nm (cvtcnt r))) cnames cregs)                     ; counter name -> cvtsi2sd of its reg
       ht (htbl (fcc bound (fccl invd (fccl updates (fcc testexpr ())))) 2)    ; distinct consts -> xmm2..7 (bound first -> reg 2)
       derives (foldl (\ a p (+ a (+ (cgFd ht cenv (cup p)) (fstore (cap p))))) () (map2 (\ i d (link i d)) (rangeL 0 M) invd))  ; inv i -> xmm(8+i)
       zerof (foldl (\ a j (+ a (fzero (+ M j)))) () (rangeL 0 N))             ; fvar j -> xmm(8+M+j) = 0
       aenv (cat (efold fenv 8) ht)                                           ; invariants/fvars at xmm8.. ; consts from ht
       pool (cat (L 0 1) (rangeL (+ 8 (+ M N)) 16))                           ; the inner allocator's working regs (the leftover xmm)
       AR (vnall (link testexpr updates) () ())  rootv (cap AR)  dag (caup AR)  nn (tally dag)
       AL (alloc dag rootv aenv nn pool)  bodyc (cap AL)  rg (caup AL)
       magr (peep rg (cap rootv) 0)
       wb (foldl (\ a j (+ a (sse 'mov (+ 8 (+ M j)) (peep rg (nthl rootv (+ 1 j)) 0)))) () (rangeL 0 N))   ; fvar j <- its update's result reg
       Lc (tally bodyc)  Lwb (tally wb)  Li (+ Lc (+ Lwb 32))                  ; cmp7+jge6+body+ucom5+exj6+wb+incr8(3)+iback5
       iblk (asm (L (+ (L 73 129 248) (le4 lim))                              ; LTOP: cmp r8, lim
                    (+ (L 15 141) (le4 (+ Lc (+ Lwb 19))))                    ; jge ESC
                    bodyc                                                     ; the CSE'd, register-only inner body
                    (ucom magr (hlook bound ht))                             ; ucomisd mag, bound
                    (+ (ucmp-exit cmpop) (le4 (+ Lwb 8)))                    ; <exit> ESC
                    wb (L 73 255 192)                                        ; writeback fvars ; inc r8
                    (+ (L 233) (le4 (- 0 Li)))))                             ; jmp LTOP
       accb (asm (L (L 77 1 193) (guard-acc D)))                              ; ESC: add r9,r8 ; deopt (pops callee-saved for D>=3)
       cell (asm (L derives zerof (L 77 49 192) iblk accb))                   ; derive invariants; zero fvars; xor r8(it=0); recur; acc += it
       loops (map2 (\ r n (link r n)) cregs dims)                             ; (counter-reg . bound) pairs, outer->inner
       pushes (foldl (\ a r (+ a (pushR r))) () saved)
       pops   (foldl (\ a r (+ a (popR r))) () (rev saved))
       (asm (L pushes (hpre ht) (L 77 49 201) (nest loops cell) pops (L 76 137 200))))   ; push callee-saved; preload consts; xor r9(acc); NEST; pop; mov rax,r9
   ; (jitfgridn lam cnames dims invs invd fvars updates testexpr cmpop bound lim) -> native D-dim grid.
   (jitfgridn lam cnames dims invs invd fvars updates testexpr cmpop bound lim)
    (nif (emit (+ (loopcode-gridn dims cnames invs invd fvars updates testexpr cmpop bound lim) epilogue)) (ev lam) lam 1)
   ; (jitfgrid src pxn pyn cxd cyd fvars updates testexpr cmpop bound lim) -> the 2D mandelbrot-class
   ; delegate (the original signature) onto the general kernel: D=2 (px py), M=2 invariants (cx cy).
   (jitfgrid lam pxn pyn cxd cyd fvars updates testexpr cmpop bound lim)
    (jitfgridn lam '(px py) (L pxn pyn) '(cx cy) (L cxd cyd) fvars updates testexpr cmpop bound lim)
   ; --- the AUTO-HOOK recognizer: read a float-recurrence GRID nest from SOURCE and extract the
   ;     jitfgrid structure, so ordinary interpreted code gets glazed transparently (no hand-call).
   ;     matches the shape: a mand recurrence (\ cx cy zx zy it (? (&& (< it LIM) (cmp TEST BOUND))
   ;     (mand ..updates.. (+ it 1)) it)) driven by two counted loops col/grid. extracts pxn pyn cxd
   ;     cyd fvars updates testexpr cmpop bound lim, then jitfgrid. exactly 2 invariants (the point)
   ;     + 2 fvars (the iterate); other shapes return () (stay interpreted). see tools/glaze-auto.l.
   (opd e i) (nthl (cup e) i)                                       ; i-th operand of a form
   (classify ps args)                                               ; mand params vs recursive args -> (fvars updates invariants)
    (? (two? ps) (: p (cap ps) a (cap args) r (classify (cup ps) (cup args))
                    (? (= a p)          (L (cap r) (caup r) (link p (nthl r 2)))            ; invariant (the point)
                       (= a (L '+ p 1)) r                                                   ; counter (+ p 1)
                                        (L (link p (cap r)) (link a (caup r)) (nthl r 2)))) ; fvar + update
                 (L () () ()))
   (posof k l i) (? (= k (cap l)) i (posof k (cup l) (+ i 1)))
   (grok glam mps mbody cbody gbody)                               ; -> a native grid closure, or () if it doesn't match the shape
    (: cond (opd mbody 0)  then (opd mbody 1)
       c2 (opd cond 1)  lim (opd (opd cond 0) 1)  cmpop (cap c2)  testexpr (opd c2 0)  bound (opd c2 1)
       cl (classify mps (cup then))  fvars (cap cl)  updates (caup cl)  invs (nthl cl 2)
       pyn (opd (opd cbody 0) 1)  margs (cup (opd (nthl (cup (opd cbody 1)) 2) 1))
       cxd (nthl margs (posof (nthl invs 0) mps 0))  cyd (nthl margs (posof (nthl invs 1) mps 0))
       pxn (opd (opd gbody 0) 1)
       (? (&& (= 2 (tally invs)) (= 2 (tally fvars)))
          (jitfgrid glam pxn pyn cxd cyd fvars updates testexpr cmpop bound lim) ()))
   ; --- self-test (x86-64): native == interpreted, transparent, deopts ---------
   (isum n) ((: (go i a) (? (< i n) (go (+ i 1) (+ a (* i 7))) a)) 0 0)
   f (jit '(\ x (+ (* x 3) 1)))   g (jitsum '(* i 7))
 _ (assert
  (lit? f) (lit? g)                                          ; native closures are applicable values
  (31 = (f 10)) (315 = (g 10))                               ; they compute
  ((\ x (+ (* x 3) 1)) = f)                                  ; ... and are =-IDENTICAL to their source
  !(f = (\ x (+ (* x 3) 2)))
  (f = (jit '(\ x (+ (* x 3) 1))))                           ; two natives, same source
  ; fixnum INPUT guard: a non-fixnum arg DEOPTS (no sar/putfix corruption of a heap word)
  (: idn (jit '(\ x x)) (&& (5 = (idn 5)) ('(1 2) = (idn '(1 2))) ('a = (idn 'a)) (id? (:) (idn (:)))))
  (: pls (jit '(\ x (+ x 1))) (&& (6 = (pls 5)) ((+ '(1 2) 1) = (pls '(1 2)))))   ; native == interp on a non-fixnum
  (: q (jit '(\ n (+ (* n 3) 1))) (&& (31 = (q 10)) ((\ n (+ (* n 3) 1)) = q) (q = f)))  ; arity-1 leaf, non-x param (= f up to alpha)
  ('(2 4 6) = (map (jit '(\ x (+ x 1))) '(1 3 5)))           ; compose with higher-order fns
  ((isum 1000) = (g 1000))                                   ; the loop agrees with the interpreter
  (9000000000000000000 = ((jit '(\ x (* x x))) 3000000000))  ; OVERFLOW -> deopt -> correct bignum
  (1 = ((: (go i a) (? (< i 60) (go (+ i 1) (&& a (= ((jit `('\ 'x `('* 'x i))) 7) (* 7 i)))) a)) 0 1))  ; agree 0..60
  ; comparisons (-> 0/1) and conditionals
  (: lt (jit '(\ x (< x 5))) (&& (1 = (lt 3)) (1 = (lt -2)) (0 = (lt 5)) (0 = (lt 9))))
  (: ab (jit '(\ x (? (< x 0) (- 0 x) x))) (&& (7 = (ab -7)) (7 = (ab 7)) (0 = (ab 0))))   ; abs
  ((\ x (? (< x 0) (- 0 x) x)) = (jit '(\ x (? (< x 0) (- 0 x) x))))                        ; transparent
  (: cap50 (jitsum '(? (< i 50) i 0)) c50 ((: (go i a) (? (< i 1000) (go (+ i 1) (+ a (? (< i 50) i 0))) a)) 0 0)
     (= c50 (cap50 1000)))                                                                  ; loop with a conditional body
  ; // and %
  (: dv (jit '(\ x (// x 3))) (&& (3 = (dv 10)) (4 = (dv 13)) (-3 = (dv -10))))
  (: md (jit '(\ x (% x 7)))  (&& (1 = (md 8)) (-1 = (md -8)) (0 = (md 14))))
  ; mid-nest deopt must leave the machine stack balanced (rsp unwind on deopt)
  (16000000000000000001 = ((jit '(\ x (+ 1 (* x x)))) 4000000000))
  (16000000000000000003 = ((jit '(\ x (+ (+ 1 (* x x)) 2))) 4000000000))
  ; bitwise & | ^
  (: bt (jit '(\ x (& x 12))) (&& (8 = (bt 10)) (12 = (bt 13))))
  (: bo (jit '(\ x (| x 1)))  (&& (3 = (bo 2)) (5 = (bo 5))))
  (: bx (jit '(\ x (^ x 5)))  (&& (15 = (bx 10)) (0 = (bx 5))))
  ; arity-2 leaves: saturated + curried, transparent, deopt via interp body
  (: ad (jit2 '(\ x y (+ x y)))           (&& (7 = (ad 3 4)) (7 = ((ad 3) 4))))
  (: sb (jit2 '(\ x y (- (* x x) y)))     (&& (5 = (sb 3 4)) (16000000000000000000 = (sb 4000000000 0))))
  ((\ x y (+ x y)) = (jit2 '(\ x y (+ x y))))
  (: dd (jit2 '(\ x y (// x y)))          (&& (3 = (dd 13 4)) (-2 = (dd -7 3))))
  ; arity-3 / arity-4 leaves: param i at Sp[i], saturating at ANY split, transparent
  (: t3 (jitn '(\ x y z (+ (+ x y) (* z 2)))) (&& (13 = (t3 1 2 5)) (13 = ((t3 1 2) 5)) (13 = ((t3 1) 2 5))))
  ((\ x y z (+ (+ x y) (* z 2))) = (jitn '(\ x y z (+ (+ x y) (* z 2)))))
  (: t4 (jitn '(\ a b c d (+ (* a b) (- c d)))) (&& (7 = (t4 2 3 7 6)) (7 = ((t4 2 3) 7 6)) (7 = ((t4 2) 3 7 6))))
  (16000000000000000005 = ((jitn '(\ x y z (+ (+ (* x x) y) z))) 4000000000 0 5))   ; deopt through a middle param
  ; N-VARIABLE loop: iterative fib (3 loop vars i,a,b) -- native == interp, deopts at overflow
  (: nf (jitloop-n '(\ n ((: (go i a b) (? (< i n) (go (+ i 1) b (+ a b)) a)) 0 0 1))
                   '(i a b) '((+ i 1) b (+ a b)) '(< i n) 'a '(0 0 1))
     fi (\ n ((: (go i a b) (? (< i n) (go (+ i 1) b (+ a b)) a)) 0 0 1))
     (&& (55 = (nf 10)) (832040 = (nf 30)) (= (fi 30) (nf 30))                       ; fib(10)=55, fib(30)=832040
         (4660046610375530309 = (nf 91))))                                          ; fib(91) > fixnum -> deopt -> bignum
  ; CAPTURES = partial-apply a native multi-arg; the leading param(s) are the captures.
  (: mk (jit2 '(\ n x (+ x n)))  a5 (mk 5)  a7 (mk 7)
     (&& (15 = (a5 10)) (17 = (a7 10)) ('(6 7 8) = (map a5 '(1 2 3)))                 ; native captured closure, composes
         (8000000000000000000 = ((mk 4000000000000000000) 4000000000000000000))))    ; ... and deopts through the capture
  ; --- added coverage: setcc <=/>/>=/=, multi-arg (cgn) %/&/|/cmp/?, *-fold loop, //-by-0 deopt ---
  ; comparison RESULT codes -- only `<` reached a setcc before, 4 of 5 opcodes were dark
  (: le (jit '(\ x (<= x 5))) (&& (1 = (le 5)) (1 = (le 3)) (0 = (le 6))))            ; setcc <=
  (: gt (jit '(\ x (>  x 5))) (&& (1 = (gt 6)) (0 = (gt 5)) (0 = (gt 2))))            ; setcc >
  (: ge (jit '(\ x (>= x 5))) (&& (1 = (ge 5)) (1 = (ge 9)) (0 = (ge 4))))            ; setcc >=
  (: eq (jit '(\ x (=  x 5))) (&& (1 = (eq 5)) (0 = (eq 4)) (0 = (eq 6))))            ; setcc =
  ; multi-arg (cgn) op dispatch -- only + - * // were exercised on the N-ary path
  (: mdn (jit2 '(\ x y (% x y))) (&& (1 = (mdn 8 7)) (-1 = (mdn -8 7)) (0 = (mdn 14 7))))   ; idivseq-mn %
  (: ban (jit2 '(\ x y (& x y))) (&& (8 = (ban 10 12)) (4 = (ban 4 5))))                    ; cgn -> bitseq
  (: bon (jit2 '(\ x y (| x y))) (&& (3 = (bon 2 1)) (7 = (bon 5 3))))
  (: ltn (jit2 '(\ x y (< x y))) (&& (1 = (ltn 3 5)) (0 = (ltn 5 3))))                      ; cgn -> cmpseq
  (: mnn (jit2 '(\ x y (? (< x y) x y))) (&& (3 = (mnn 3 5)) (4 = (mnn 9 4))))              ; cgn -> condcode (min)
  ; *-fold counted loop -- jitsum hardcodes +/<, so drive acc-mul + nonzero r11-init via loopcode
  (: prodf (: psrc `('\ 'n `(`(': `('go 'i 'a) `('? `('< 'i 'n) `('go `('+ 'i 1) `('* 'a `('+ 'i 1))) 'a)) 0 1))
              (nif (emit (loopcode '(+ i 1) 'i '* '<)) (ev psrc) psrc 1))
     pf (\ n ((: (go i a) (? (< i n) (go (+ i 1) (* a (+ i 1))) a)) 0 1))
     (&& (120 = (prodf 5)) (= (pf 8) (prodf 8))))                                           ; n! via a product fold
  ; divide-by-zero takes the guardz deopt -- only nonzero divisors were tested
  (: dz (jit '(\ x (// x 0))) (= (// 10 0) (dz 10)))                                        ; // by 0 -> deopt -> interp
  ; --- FLOAT predicate leaves (SSE): unboxed-double compares over a fixnum arg -> 0/1 ---
  (= "4616189618054758400" (show (fbits 4.0)))                                              ; fbits: 4.0 -> 0x4010000000000000
  (: flt (jitf '(\ x (< (* x 1.5) 10.0)))
     (&& (1 = (flt 6)) (0 = (flt 7)) (1 = (flt 0)) (1 = (flt -3))                           ; 1.5x < 10  <=> x < 6.67
         ((\ x (< (* x 1.5) 10.0)) = flt)                                                   ; transparent (=/show)
         (= ((\ x (< (* x 1.5) 10.0)) '(1 2)) (flt '(1 2)))))                               ; non-fixnum arg -> deopt -> interp
  (: fle (jitf '(\ x (<= (+ (* x x) 2.0) 38.0))) (&& (1 = (fle 6)) (0 = (fle 7)) (1 = (fle -6))))   ; x*x+2 <= 38 <=> |x|<=6
  (: fgt (jitf '(\ x (> (/ 100.0 x) 7.0)))       (&& (1 = (fgt 10)) (0 = (fgt 20)) (1 = (fgt 5))))  ; 100/x > 7 <=> 0<x<14.3
  (: fge (jitf '(\ x (>= (- (* x 0.5) 1.0) 2.0))) (&& (1 = (fge 6)) (0 = (fge 5))))                 ; x/2-1 >= 2 <=> x>=6
  (: feq (jitf '(\ x (= (* x 0.25) 2.0)))         (&& (1 = (feq 8)) (0 = (feq 7))))                 ; x/4 == 2 <=> x==8
  ; --- FLOAT RECURRENCE LOOP OWNER: a native mandelbrot pixel kernel == the interpreter ---
  (: msrc '(\ px py (: cx (- (* px 0.046875) 2.0) cy (- (* py 0.046875) 1.5)
                      ((: (go zx zy it) (? (&& (< it 100) (<= (+ (* zx zx) (* zy zy)) 4.0))
                            (go (+ (- (* zx zx) (* zy zy)) cx) (+ (* (* 2.0 zx) zy) cy) (+ it 1)) it)) 0.0 0.0 0)))
     mp (jitfrec msrc '(px py) '((cx (- (* px 0.046875) 2.0)) (cy (- (* py 0.046875) 1.5)))
                 '(zx zy) '((+ (- (* zx zx) (* zy zy)) cx) (+ (* (* 2.0 zx) zy) cy))
                 '(+ (* zx zx) (* zy zy)) '<= 4.0 100)
     mi (ev msrc)
     (&& (= (mi 0 0) (mp 0 0)) (= (mi 32 32) (mp 32 32)) (= (mi 20 40) (mp 20 40))                  ; native == interp
         (= (mi 63 63) (mp 63 63)) (= (mi 10 50) (mp 10 50)) (= (mi 45 18) (mp 45 18))))
  ; --- NESTED grid owner: native whole-grid mandelbrot == interpreter (checksum 87130) ---
  (: gsrc '(\ _ (: (mand cx cy zx zy it) (? (&& (< it 100) (<= (+ (* zx zx) (* zy zy)) 4.0))
                       (mand cx cy (+ (- (* zx zx) (* zy zy)) cx) (+ (* (* 2.0 zx) zy) cy) (+ it 1)) it)
                   (col px py acc) (? (< py 64) (col px (+ py 1) (+ acc (mand (- (* px 0.046875) 2.0) (- (* py 0.046875) 1.5) 0.0 0.0 0))) acc)
                   (grid px acc) (? (< px 64) (grid (+ px 1) (+ acc (col px 0 0))) acc)
                 (grid 0 0)))
     mg (jitfgrid gsrc 64 64 '(- (* px 0.046875) 2.0) '(- (* py 0.046875) 1.5)
                  '(zx zy) '((+ (- (* zx zx) (* zy zy)) cx) (+ (* (* 2.0 zx) zy) cy))
                  '(+ (* zx zx) (* zy zy)) '<= 4.0 100)
     (&& (= 87130 (mg 0)) (= ((ev gsrc) 0) (mg 0))))
  ; --- AUTO-HOOK: recognize the (mand col grid) nest from SOURCE and glaze it -> checksum 87130 ---
  (: gmand '(? (&& (< it 100) (<= (+ (* zx zx) (* zy zy)) 4.0))
               (mand cx cy (+ (- (* zx zx) (* zy zy)) cx) (+ (* (* 2.0 zx) zy) cy) (+ it 1)) it)
     gcol '(? (< py 64) (col px (+ py 1) (+ acc (mand (+ -2.0 (* px 0.046875)) (+ -1.5 (* py 0.046875)) 0.0 0.0 0))) acc)
     ggrid '(? (< px 64) (grid (+ px 1) (+ acc (col px 0 0))) acc)
     ng (grok '(\ _ 0) '(cx cy zx zy it) gmand gcol ggrid)
     (= 87130 (ng 0))))
 _ (say err "ai/glaze/emit: native codegen ok (arith + loop + D-dim float grid, transparent, deopt)\n"))
