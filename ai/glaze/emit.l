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
(: (le8 n) ((: (go i) (? (< i 8) (link (& (>> n (* 8 i)) 255) (go (+ i 1))) ())) 0)  ; n -> 8 LE bytes
   (le4 n) ((: (go i) (? (< i 4) (link (& (>> n (* 8 i)) 255) (go (+ i 1))) ())) 0)  ; n -> 4 LE bytes
   deopt    '(72 139 70 8  72 137 198  72 139 6  255 224)   ; mov rax,[rsi+8]; mov rsi,rax; mov rax,[rsi]; jmp rax
   ; guard d / guardz d: skip the inline deopt unless OF (guard) / unless nonzero
   ; (guardz, for divide-by-zero); on deopt UNWIND d pending machine-stack operands
   ; (add rsp,8d) so the jmp-to-interp leaves rsp balanced -- else a mid-nest deopt
   ; leaks pushes and the terminator `ret` faults. deopt tail-applies interp(arg).
   (guard d)  (+ '(113 19) (+ (+ '(72 129 196) (le4 (* 8 d))) deopt))      ; jno +19; add rsp,8d; deopt
   (guardz d) (+ '(117 19) (+ (+ '(72 129 196) (le4 (* 8 d))) deopt))      ; jnz +19; add rsp,8d; deopt
   ld-i '(76 137 208)                                                           ; loop var i (raw, in r10)
   untag '(72 209 248)                                                           ; sar rax,1
   (fetch i) (? (= i 0)        '(72 139 1)                                       ; mov rax,[rcx]       (TAGGED, no untag)
                (< (* 8 i) 128) (+ '(72 139 65) (link (* 8 i) ()))              ; mov rax,[rcx+disp8]
                                (+ '(72 139 129) (le4 (* 8 i))))               ; mov rax,[rcx+disp32]
   ; FIXNUM INPUT GUARD: native arithmetic assumes fixnums (sar/imul/idiv), so a
   ; NON-fixnum arg (an even/heap word -- a list, mint, the zero point, ...) must DEOPT
   ; to the bytecode body, which dispatches generically. The overflow guard only catches
   ; a fixnum RESULT leaving range, never a bad INPUT. test al,1 (fixnum = odd); a clear
   ; low bit (even) falls through to the deopt -- structurally a guardz (jnz over it).
   (fxv  i d) (+ (fetch i) (+ '(168 1) (+ (guardz d)    untag)))           ; nat deopt (interp value[0])
   (fxmn i d) (+ (fetch i) (+ '(168 1) (+ (guardz-mn d) untag)))           ; natn deopt (interp body)
   push-rax '(80)   pop-r8 '(65 88)
   epilogue (+ '(72 1 192) (+ (guard 0) (+ '(72 131 200 1) (+ '(72 137 1)   ; add rax,rax;guard;or rax,1;mov[rcx]
              (+ '(72 131 198 16) '(72 139 6  255 224))))))                    ; add rsi,16; Continue
   (opseq op d) (? (= op '+) (+ pop-r8 (+ '(76 1 192) (guard d)))            ; add rax,r8 ; guard
                   (= op '*) (+ pop-r8 (+ '(73 15 175 192) (guard d)))       ; imul rax,r8 ; guard
                   (= op '-) (+ pop-r8 (+ '(73 41 192) (+ (guard d) '(76 137 192))))  ; sub r8,rax;guard;mov rax,r8
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
       test (+ '(77 57 202) (+ (loopjcc cmp) (le4 (+ (+ Lb La) 8))))         ; cmp r10,r9 ; <inverse-cmp> end
       back (+ '(73 255 194) (+ '(233) (le4 (- 0 (+ (+ Lb La) 17)))))        ; inc r10 ; jmp loop_top
       (+ pre (+ test (+ lb (+ acc (+ back (+ '(76 137 216) epilogue)))))))   ; ... ; mov rax,r11
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
       top  (+ tb (+ '(72 131 248 0) (+ '(15 132) (le4 (+ Lu 5)))))   ; <test>; cmp rax,0; je end
       back (+ '(233) (le4 (- 0 (+ (+ Lt Lu) 15))))                       ; jmp top
       (+ pre (+ top (+ ub (+ back (+ rb epilogue))))))
   ; (jitloop-n lam vars updates test result inits) -- a general N-var loop -> native.
   (jitloop-n lam vars updates test result inits)
    (nif (emit (loopcode-n (caup lam) vars updates test result inits)) (ev lam) lam 1)
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
         (16000000000000000000 = ((mk 0) 4000000000)))))                             ; ... and deopts through the capture
 _ (puts "ai/glaze/emit: native codegen ok (arith + loop, transparent, deopt)") _ (putc 10))
