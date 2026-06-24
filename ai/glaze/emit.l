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
   ; --- RECURSIVE / MUTUALLY-RECURSIVE native (own a GROUP's CALL GRAPH): a set of first-order integer
   ;     functions whose bodies are the arithmetic fragment  E := param | int | (op E E) | (cmp E E) |
   ;     (// E E) | (% E E) | (bit E E) | (? E E E) | (g E..)  where g is ANY function of the group.
   ;     EVERY call -- self OR sibling -- compiles to `call H_g` (a rel32 to that function's entry in
   ;     the SAME buffer): the recursion AND the mutual recursion stay NATIVE, no interpreter per call
   ;     (fib/tak are SINGLETON groups; even?/odd? a 2-fn group). Args pass on the machine stack; each H
   ;     callee-saves its OWN k arg regs (rbx/r13/r14/r15, k<=4) -- a reg a deeper callee uses is saved
   ;     by THAT callee, so a caller's args of ANY arity survive nested calls. ONE shared OVF handler
   ;     lives in the entry's OUTER (r12 = its post-prologue rsp): every int +/-/* `jo`s there, a /,% by
   ;     zero `jz`s there; OVF does `mov rsp,r12` to abandon ALL the native frames at once and tail-
   ;     deopts to a faithful interpreted closure of the WHOLE group -- so an int64-exceeding
   ;     intermediate (fib 93+, factorial 21+) is never WRONG, just interpreted. arity >=1, x86-64 only.
   (recop op) (? (= op '+) '(76 1 192) (= op '*) '(73 15 175 192) (= op '-) (asm (L '(73 41 192) '(76 137 192))) ())   ; add/imul/sub rax,r8
   (glook nm syms) (? (atom? syms) -1 (id? nm (caap syms)) (cuap syms) (glook nm (cup syms)))   ; group fn name -> its H offset (dotted (name . off); -1 if absent)
   (gfind p l) (? (atom? l) () (p (cap l)) (cap l) (gfind p (cup l)))     ; first elt matching p
   (gfilt p l) (? (atom? l) () (p (cap l)) (link (cap l) (gfilt p (cup l))) (gfilt p (cup l)))   ; keep elts matching p
   ; immediate-operand peephole: `(+ E C)`/`(- E C)`/`(* E C)` with C a small int const -> E in rax, then
   ; `add/sub/imul rax, imm32` (no push/movabs/pop). +/* commute, so `(C op E)` works too; - only `(- E C)`.
   (whole-imm? x) (&& (whole? x) (<= -2147483648 x) (< x 2147483648))                ; fits a sign-extended imm32?
   (immop op c) (? (= op '+) (asm (L '(72 5) (le4 c)))                               ; add  rax, imm32  (48 05 id)
                   (= op '-) (asm (L '(72 45) (le4 c)))                              ; sub  rax, imm32  (48 2D id)
                   (= op '*) (asm (L '(72 105 192) (le4 c))) ())                      ; imul rax, rax, imm32 (48 69 C0 id)
   (immlen op) (? (= op '*) 7 6)
   ; register-operand peephole: when one operand is a PARAM (already in an arg register rbx/r13/r14/r15),
   ; combine it DIRECTLY (op rax,reg / cmp rax,reg) instead of push-rax..pop-r8 -- the stack traffic that
   ; made the integer lane lag a register machine (e.g. primes' (* d d), (< n ..), (= 0 ..) every iter).
   (pregn i) (nthl '(3 13 14 15) i)                                                 ; arg-slot i -> x86 reg num
   chainkind (apof (link 0 0))                                                      ; lvm_chain's ap sentinel, for the inline two?/cap/cup kind test (cf. (apof "") for the string lane)
   (rrm reg) (+ 192 (% reg 8))                                                      ; ModRM mod11: reg-field=rax, rm=reg
   (rrr reg) (+ 192 (* 8 (% reg 8)))                                                ; ModRM mod11: reg-field=reg, rm=rax
   (rexb reg) (? (< reg 8) 72 73)                                                   ; REX.W (+B if reg extended, in rm)
   (rexr reg) (? (< reg 8) 72 76)                                                   ; REX.W (+R if reg extended, in reg-field)
   (opreg op reg) (? (= op '+) (L (rexr reg) 1 (rrr reg))                           ; add  rax, reg
                     (= op '*) (L (rexb reg) 15 175 (rrm reg))                      ; imul rax, reg
                     (= op '-) (L (rexb reg) 43 (rrm reg)) ())                      ; sub  rax, reg  (rax - reg)
   (cmpimm c)     (asm (L '(72 61) (le4 c)))                                        ; cmp rax, imm32  (rax - imm)
   (cmprb reg)    (L (rexb reg) 59 (rrm reg))                                       ; cmp rax, reg    (rax - reg)
   (cmpra reg)    (L (rexb reg) 57 (rrm reg))                                       ; cmp reg, rax    (reg - rax)
   (flipc op) (? (= op '<) '> (= op '<=) '>= (= op '>) '< (= op '>=) '<= op)        ; mirror a cmp's operands (= stays)
   (setx op c)    (asm (L c (setcc op) '(72 15 182 192)))                           ; <cmp bytes>; setcc al; movzx rax,al
   (testreg reg)  (L (? (< reg 8) 72 77) 133 (+ (+ 192 (* 8 (% reg 8))) (% reg 8))) ; test reg, reg
   (idivr reg)    (L (rexb reg) 247 (+ 248 (% reg 8)))                              ; idiv reg
   (movr9 reg)    (L (? (< reg 8) 73 77) 137 (+ (+ 192 (* 8 (% reg 8))) 1))         ; mov r9, reg  (load a raw buf-param pointer)
   ; cgg -- the GROUP arithmetic-fragment compiler (the WHOLE integer lane): an expr over {ps (this fn's
   ; params, in arg regs rbx/r13/r14/r15) ; int ; group calls} -> rax. syms = the group's dotted (name .
   ; offset) table (glook resolves a call's target, self or sibling, UNIFORMLY); off = the abs offset of
   ; e; OVF = the abs offset of the shared overflow handler. A singleton group IS plain recursion.
   (cgg syms ps e off OVF)
    (? (member? e ps) (arx (argix e ps 0))                               ; a param -> its register
       (whole? e) (asm (L '(72 184) (le8 e)))                            ; movabs rax, n
       (two? e) (: op (cap e) a (caup e) b (caup (cup e)) Ho (glook op syms)
          (? (< -1 Ho) (: as (cup e) ka (tally as) ab (gargs syms ps as off OVF) callabs (+ off (tally ab))   ; CALL g: push args; call H_g; pop them
                          (asm (L ab '(232) (le4 (- Ho (+ callabs 5))) '(72 131 196) (list (* 8 ka)))))
             (member? op '(+ - *))
                (? (whole-imm? b) (: ab (cgg syms ps a off OVF) joa (+ (+ off (tally ab)) (immlen op))        ; (E op C): E;op rax,C;jo OVF
                                     (asm (L ab (immop op b) '(15 128) (le4 (- OVF (+ joa 6))))))
                   (&& (whole-imm? a) (member? op '(+ *))) (: bb (cgg syms ps b off OVF) job (+ (+ off (tally bb)) (immlen op))   ; (C op E), commute
                                     (asm (L bb (immop op a) '(15 128) (le4 (- OVF (+ job 6))))))
                   (member? b ps) (: ab (cgg syms ps a off OVF) opb (opreg op (pregn (argix b ps 0))) joa (+ (+ off (tally ab)) (tally opb))   ; (E op p): E;op rax,p_reg;jo OVF
                                     (asm (L ab opb '(15 128) (le4 (- OVF (+ joa 6))))))
                   (&& (member? a ps) (member? op '(+ *))) (: bb (cgg syms ps b off OVF) opb (opreg op (pregn (argix a ps 0))) job (+ (+ off (tally bb)) (tally opb))   ; (p op E), commute
                                     (asm (L bb opb '(15 128) (le4 (- OVF (+ job 6))))))
                   (: ab (cgg syms ps a off OVF) po (+ off (tally ab)) bb (cgg syms ps b (+ po 1) OVF)        ; generic: A;push;B;pop r8;op;jo OVF
                      opb (recop op) joa (+ (+ po 1) (+ (tally bb) (+ 2 (tally opb))))
                      (asm (L ab push-rax bb pop-r8 opb '(15 128) (le4 (- OVF (+ joa 6)))))))
             (&& (member? op '(// %)) (member? b ps))
                (: ab (cgg syms ps a off OVF) reg (pregn (argix b ps 0)) tb (testreg reg)
                   jzo (+ (+ off (tally ab)) (tally tb))
                   (asm (L ab tb '(15 132) (le4 (- OVF (+ jzo 6))) '(82) '(72 153) (idivr reg) (? (= op '%) '(72 137 208) ()) '(90))))
             (member? op '(// %)) (: ab (cgg syms ps a off OVF) po (+ off (tally ab)) bb (cgg syms ps b (+ po 1) OVF)
                jza (+ (+ po 1) (+ (tally bb) 5))                                                             ; A;push;B(divisor);pop r8(=A);test;jz OVF;idiv
                (asm (L ab push-rax bb '(65 88) '(72 133 192) '(15 132) (le4 (- OVF (+ jza 6)))
                       '(82 80 76 137 192 72 153 72 247 60 36) (? (= op '%) '(72 137 208) ()) '(72 131 196 8 90))))
             (member? op '(& | ^)) (: ab (cgg syms ps a off OVF) po (+ off (tally ab)) bb (cgg syms ps b (+ po 1) OVF)
                (asm (L ab push-rax bb (bitseq op))))
             (member? op '(< <= > >= =))
                (? (whole-imm? b) (: ab (cgg syms ps a off OVF) (asm (L ab (setx op (cmpimm b)))))                              ; (E < C): E;cmp rax,C;setcc
                   (member? b ps)  (: ab (cgg syms ps a off OVF) (asm (L ab (setx op (cmprb (pregn (argix b ps 0)))))))         ; (E < p): cmp rax,p
                   (member? a ps)  (: bb (cgg syms ps b off OVF) (asm (L bb (setx op (cmpra (pregn (argix a ps 0)))))))         ; (p < E): cmp p,rax
                   (whole-imm? a)  (: bb (cgg syms ps b off OVF) (asm (L bb (setx (flipc op) (cmpimm a)))))                     ; (C < E): cmp rax,C, flip
                   (: ab (cgg syms ps a off OVF) po (+ off (tally ab)) bb (cgg syms ps b (+ po 1) OVF)                          ; generic: A;push;B;pop r8;cmp;setcc
                      (asm (L ab push-rax bb (cmpseq op)))))
             (= op '?) (: el (caup (cup (cup e))) tb (cgg syms ps a off OVF) thoff (+ off (+ (tally tb) 10)) thb (cgg syms ps b thoff OVF) eloff (+ thoff (+ (tally thb) 5)) elb (cgg syms ps el eloff OVF)
                (asm (L tb '(72 131 248 0) '(15 142) (le4 (+ (tally thb) 5)) thb '(233) (le4 (tally elb)) elb)))   ; cmp rax,0; jle else; then; jmp end; else
             (&& (= op 'peep) (member? a ps)) (: ib (cgg syms ps b off OVF) d (caup (cup (cup e)))                ; (peep STR i d): native string byte read (plain ai_str: bytes at STR+16, len at STR+8)
                defb (asm (L '(72 184) (le8 (? (whole? d) d 0)))) load '(65 15 182 68 0 16)
                (asm (L ib push-rax (arx (argix a ps 0)) '(73 137 192) '(88) '(73 59 64 8)                        ; i;push; STR->rax; r8=STR; pop i; cmp i,[r8+8] len
                       (L 114 (+ (tally defb) 2)) defb (L 235 (tally load)) load)))                               ; jb IN; OOB: movabs rax,d; jmp; IN: movzx eax,[r8+rax+16]
             (&& (= op 'tally) (member? a ps)) (asm (L (arx (argix a ps 0)) '(72 139 64 8)))                      ; (tally STR): rax=STR; rax=[rax+8] = len
             (&& (= op 'pin) (member? a ps))                                                                       ; (pin C i V): native byte store into a raw buf-param C, returns C
                (: idx (caup (cup e)) val (caup (cup (cup e))) creg (pregn (argix a ps 0))
                   ixb (cgg syms ps idx off OVF) po (+ off (tally ixb)) vb (cgg syms ps val (+ po 1) OVF)
                   (asm (L ixb push-rax vb '(65 88)                                                                ; idx->rax;push; V->rax; pop r8(=idx)
                          (movr9 creg) '(77 139 73 8)                                                              ; r9=C (buf ptr); r9=[r9+8] (the backing str)
                          '(67 136 68 8 16)                                                                        ; mov [r9+r8+16], al  (store V's low byte at str's bytes + idx)
                          (arx (argix a ps 0)))))                                                                  ; rax = C (chain the buf)
             (= op 'two?) (: ab (cgg syms ps a off OVF)                                                            ; (two? E): chainp(E) -> 0/1 (TOTAL -- no deopt; a non-chain is just false)
                (asm (L ab '(168 1 117 25 76 139 16) '(73 187) (le8 chainkind) '(77 57 218 117 7 184 1 0 0 0 235 2 49 192))))   ; test al,1;jnz z; r10=[rax];movabs r11,kind;cmp r10,r11;jne z; eax=1;jmp e; z:xor eax,eax; e:
             (= op 'cap) (: ab (cgg syms ps a off OVF) base (+ off (tally ab))                                     ; (cap E): chain guard, then rax=[E+8] (non-chain -> deopt to interp; in ck always under two?)
                (asm (L ab '(168 1 15 133) (le4 (- OVF (+ base 8))) '(76 139 16 73 187) (le8 chainkind) '(77 57 218 15 133) (le4 (- OVF (+ base 30))) '(72 139 64 8))))
             (= op 'cup) (: ab (cgg syms ps a off OVF) base (+ off (tally ab))                                     ; (cup E): chain guard, then rax=[E+16]
                (asm (L ab '(168 1 15 133) (le4 (- OVF (+ base 8))) '(76 139 16 73 187) (le8 chainkind) '(77 57 218 15 133) (le4 (- OVF (+ base 30))) '(72 139 64 16))))
             ()))
       ())
   (gargs syms ps as off OVF) (? (atom? as) ()                           ; push each call arg left->right (offset-threaded)
      (: ab (cgg syms ps (cap as) off OVF) nb (asm (L ab push-rax)) (asm (L nb (gargs syms ps (cup as) (+ off (tally nb)) OVF)))))
   ; cggt -- compile e in TAIL position. A tail SELF-call (selfnm, matching arity) becomes TCO: shuffle
   ; the new args through the stack into the arg regs, then `jmp Lbody` (the body-start, past saveargs/
   ; ldargs) -- the frame is REUSED, so a counted loop is O(1) stack with NO call/ret per iteration. A
   ; tail `?` recurses tail into both branches (the test stays non-tail). Everything else (a value, an
   ; arith expr, a sibling/non-tail call) delegates to cgg and falls through to restargs+ret as before.
   (cggt syms ps e off OVF selfnm Lbody)
    (? (&& (two? e) (id? (cap e) selfnm) (= (tally (cup e)) (tally ps)))   ; TAIL SELF-CALL -> loop
         (: as (cup e) ka (tally as) ab (gargs syms ps as off OVF)                                  ; push the new args
            pops (foldl (\ a i (+ a (popr (- (- ka 1) i)))) () (rangeL 0 ka))                       ; pop them into the arg regs (reverse)
            joff (+ off (+ (tally ab) (tally pops)))
            (asm (L ab pops '(233) (le4 (- Lbody (+ joff 5))))))                                    ; jmp Lbody (reuse the frame)
       (&& (two? e) (id? (cap e) '?))                                      ; TAIL ? -> test non-tail, branches tail
         (: a (caup e) b (caup (cup e)) el (caup (cup (cup e)))
            tb (cgg syms ps a off OVF) thoff (+ off (+ (tally tb) 10)) thb (cggt syms ps b thoff OVF selfnm Lbody)
            eloff (+ thoff (+ (tally thb) 5)) elb (cggt syms ps el eloff OVF selfnm Lbody)
            (asm (L tb '(72 131 248 0) '(15 142) (le4 (+ (tally thb) 5)) thb '(233) (le4 (tally elb)) elb)))
       (cgg syms ps e off OVF))                                           ; any other tail expr -> value in rax, then restargs+ret
   ; --- the ARG-REGISTER ABI (k<=4): args in rbx/r13/r14/r15, r12 the shared OVF anchor. A call passes
   ;     args ON THE MACHINE STACK; the callee H saves/loads/restores its OWN k arg regs per frame, so a
   ;     caller's args survive nested calls (tak nests three). The deopt is deopt-mn (interp body); the
   ;     cell is arity-k (lvm_cur saturates the curry).
   (arx i)  (? (= i 0) '(72 137 216) (L 76 137 (+ 224 (* 8 i))))          ; mov rax, argreg_i  (rbx/r13/r14/r15)
   (pshr i) (? (= i 0) '(83) (L 65 (+ 84 i)))                             ; push argreg_i
   (popr i) (? (= i 0) '(91) (L 65 (+ 92 i)))                             ; pop  argreg_i
   (ldr i d) (? (= i 0) (asm (L '(72 139 156 36) (le4 d))) (asm (L (L 76 139 (+ 164 (* 8 i)) 36) (le4 d))))   ; mov argreg_i, [rsp+d]
   ; mkouter -- the entry's OUTER (prologue + putfix-epilogue + shared OVF handler + deopt-mn) for arity
   ; k. The called H_entry sits RIGHT AFTER it (offset Lo = the OUTER's length), so jitgroup lays the
   ; entry first among the H's. (This is the old single-fn outer, now factored out.) Returns (outer Aovf).
   ; mkguards -- the string-param TYPE GUARD (soundness): for each string param (smask), check Sp[i] is a
   ; PLAIN string (kind == strkind, the `apof` of a reference string); a fixnum or any other kind (cask,
   ; list, map, ...) jumps to the OVF handler -> deopt to the interp fallback (which handles every type).
   ; Without it a non-string arg would deref a bad pointer. off = guards' start offset; Aovf = the handler.
   (mkguards ms bufmask strkind bufkind off Aovf)                                                ; a raw param's kind: a pin-param (bufmask) must be a CASK, else a plain STRING
    (? (atom? ms) ()
       (: i (cap ms) f (fetch i) kind (? (member? i bufmask) bufkind strkind)
          jnz-end (+ off (+ (tally f) 8)) jne-end (+ jnz-end 22)
          g (asm (L f '(168 1) '(15 133) (le4 (- Aovf jnz-end))                                  ; mov rax,Sp[i]; test al,1; jnz Aovf (fixnum)
                    '(76 139 0) '(72 184) (le8 kind) '(73 57 192) '(15 133) (le4 (- Aovf jne-end))))   ; mov r8,[rax]; movabs rax,kind; cmp r8,rax; jne Aovf
          (asm (L g (mkguards (cup ms) bufmask strkind bufkind jne-end Aovf)))))
   (mkouter k smask bufmask cmask strkind)
    (: bufkind (apof (cask 1))                                                                    ; a cask's kind, for a pin (buf) param's type guard
       dpt (? (= k 1) deopt deopt-mn)                                                             ; arity 1 applies fb directly; >=2 enters its body past the lvm_cur
       saveargs (foldl (\ a i (+ a (pshr i))) () (rangeL 0 k))                                    ; save the k arg regs (callee-saved)
       restargs (foldl (\ a i (+ a (popr (- (- k 1) i)))) () (rangeL 0 k))                        ; restore (reverse)
       pushargs (foldl (\ a i (+ a (asm (L (fetch i) (? (|| (member? i smask) (member? i cmask)) () '(72 209 248)) push-rax)))) () (rangeL 0 k))  ; push Sp[0..k-1]; untag (sar) UNLESS a string (smask) or chain (cmask) param -- both pass a raw pointer
       s6 (asm (L '(72 131 196) (list (* 8 k))))  s10 (asm (L '(72 131 200 1) '(72 137 1) '(72 131 198 16) '(72 139 6 255 224)))
       Lr (tally restargs)
       Aguard (+ 2 (+ (tally saveargs) 3))                                                       ; guards sit after push r12(2)+saveargs+mov r12,rsp(3)
       Lg (tally (mkguards smask bufmask strkind bufkind 0 0))                                                    ; guard length (offset-independent; 0 when no string params)
       Acall (+ Aguard (+ Lg (tally pushargs)))
       Arest (+ Acall (+ 5 (tally s6)))  As8 (+ Arest Lr)  As9 (+ As8 2)  Ajmpend (+ As9 10)
       As10 Ajmpend  Aovf (+ As10 (tally s10))  Adeopt (+ Aovf (+ 3 (+ Lr 2)))  Hh (+ Adeopt (tally dpt))
       guards (mkguards smask bufmask strkind bufkind Aguard Aovf)                                               ; real guards (jump to Aovf on a non-string)
       callb (asm (L '(232) (le4 (- Hh (+ Acall 5)))))                                            ; call H_entry (right after the OUTER)
       s9 (asm (L '(72 1 192) '(113 5) '(233) (le4 (- Adeopt Ajmpend))))                          ; add rax,rax; jno PUTOK(+5); jmp DEOPT
       s11 (asm (L '(76 137 228) restargs '(65 92)))                                              ; OVF: mov rsp,r12; restores; pop r12
       (L (asm (L '(65 84) saveargs '(73 137 228) guards pushargs callb s6 restargs '(65 92) s9 s10 s11 dpt)) Aovf))
   ; jitgroup -- compile a GROUP of mutually-recursive integer fns (each a dotted (nameform . body)) to
   ; native, exposing `entry` as the applicable value (its arity). Layout: the entry's OUTER, then
   ; H_entry, then the other H's, in ONE buffer. TWO passes -- measure each H body's length (offset-
   ; INDEPENDENT: a call rel32 is 5 bytes whatever its target), compute every H's offset, then emit with
   ; the real (name . offset) syms so every self/sibling call resolves. The deopt fallback is the WHOLE
   ; group as an interpreted letrec (mutual recursion intact) -> a faithful, never-wrong slow path.
   (suse? e P) (? (two? e) (? (&& (member? (cap e) '(peep tally pin)) (id? (caup e) P)) 1 (foldl (\ a x (|| a (suse? x P))) 0 (cup e))) 0)   ; P used DIRECTLY as (peep P..)/(tally P)/(pin P..)?
   (buse? e P) (? (two? e) (? (&& (id? (cap e) 'pin) (id? (caup e) P)) 1 (foldl (\ a x (|| a (buse? x P))) 0 (cup e))) 0)   ; P used as a CASK -- (pin P..) -- so its guard wants the buf kind, not str
   (cuse? e P) (? (two? e) (? (&& (member? (cap e) '(cap cup two?)) (id? (caup e) P)) 1 (foldl (\ a x (|| a (cuse? x P))) 0 (cup e))) 0)   ; P used as a CHAIN -- (cap P)/(cup P)/(two? P) -- raw pointer, NO entry guard (two? is total: a non-chain reads false)
   ; INTERPROCEDURAL string-param inference: a param is a string if used in peep/tally OR passed as the arg
   ; to a sibling's string param. (strhash's `s` is a string because it flows into strhash_go's peep.) A
   ; deduped fixpoint over the group's (name . smask) map -- smasks only grow, so the size stabilizes.
   (dedup l) (? (atom? l) () (member? (cap l) (cup l)) (dedup (cup l)) (link (cap l) (dedup (cup l))))   ; unique elements
   (gsm nm smap) (? (atom? smap) () (id? nm (caap smap)) (cuap smap) (gsm nm (cup smap)))                ; nm's smask in the (name . smask) map (() absent)
   (fnsm fp body smap)
    (dedup ((: (walk e acc) (? (two? e)
                (: gm (gsm (cap e) smap)                                                                 ; if (cap e) is a group fn, its string-param indices
                   a2 (? (atom? gm) acc (foldl (\ ac j (: arg (nthl (cup e) j) (? (member? arg fp) (link (posof arg fp 0) ac) ac))) acc gm))   ; a string arg that is OUR param -> our string param
                   (foldl (\ ac x (walk x ac)) a2 (cup e)))
                acc))
              body (gfilt (\ k (suse? body (nthl fp k))) (rangeL 0 (tally fp)))))                        ; seed acc = DIRECT peep/tally params
   (sm-size smap) (foldl (\ a e (+ a (tally (cup e)))) 0 smap)
   (smfix info smap) (: nx (map (\ f (link (cap f) (fnsm (nthl f 1) (nthl f 2) smap))) info) (? (= (sm-size nx) (sm-size smap)) nx (smfix info nx)))   ; iterate to a fixpoint
   (jitgroup defs entry)
    (: info (map (\ d (: nf (cap d) (L (cap nf) (cup nf) (cup d) (- (tally nf) 1)))) defs)   ; (name params body arity)
       efn  (gfind (\ f (id? (cap f) entry)) info)
       ord  (link efn (gfilt (\ f (! (id? (cap f) entry))) info))                            ; entry FIRST (H_entry sits at Lo)
       smap0 (map (\ f (link (cap f) (gfilt (\ k (suse? (nthl f 2) (nthl (nthl f 1) k))) (rangeL 0 (nthl f 3))))) info)   ; per-fn DIRECT string params
       smask (gsm entry (smfix info smap0))                                                   ; entry's STRING params, propagated to a fixpoint -> raw pointer, no sar
       bufmask (gfilt (\ k (buse? (nthl efn 2) (nthl (nthl efn 1) k))) (rangeL 0 (nthl efn 3)))   ; entry params used as a CASK (pin) -> guard with the buf kind, not str
       cmask (gfilt (\ k (cuse? (nthl efn 2) (nthl (nthl efn 1) k))) (rangeL 0 (nthl efn 3)))   ; entry params used as a CHAIN (cap/cup/two?) -> raw pointer, no entry guard
       OU (mkouter (nthl efn 3) smask bufmask cmask (apof "")) outer (cap OU) Aovf (caup OU) Lo (tally outer)   ; (apof "") = the plain-string kind for the type guard; bufmask overrides to buf

       sa (\ k (foldl (\ a i (+ a (pshr i))) () (rangeL 0 k)))
       ld (\ k (foldl (\ a i (+ a (ldr i (- (* 16 k) (* 8 i))))) () (rangeL 0 k)))
       re (\ k (foldl (\ a i (+ a (popr (- (- k 1) i)))) () (rangeL 0 k)))
       dummy (map (\ f (link (cap f) 0)) ord)                                                ; membership-only syms (pass 1; offsets unused)
       rows (map (\ f (: k (nthl f 3) (cat f (L (sa k) (ld k) (re k) (tally (cggt dummy (nthl f 1) (nthl f 2) 0 Aovf (nthl f 0) 0)))))) ord)   ; +sa +ld +re +bodylen (cggt: TCO-aware length)
       hlen (map (\ r (+ (tally (nthl r 4)) (+ (tally (nthl r 5)) (+ (nthl r 7) (+ (tally (nthl r 6)) 1))))) rows)   ; sa+ld+body+re+ret
       offs ((: (go acc hs) (? (atom? hs) () (link acc (go (+ acc (cap hs)) (cup hs))))) Lo hlen)
       syms (map2 (\ r o (link (cap r) o)) rows offs)                                         ; dotted (name . offset)
       Hs (map2 (\ r o (: s (nthl r 4) l (nthl r 5) bo (+ o (+ (tally s) (tally l)))                  ; bo = body start = Lbody (tail self-calls jmp here)
                          (asm (L s l (cggt syms (nthl r 1) (nthl r 2) bo Aovf (nthl r 0) bo) (nthl r 6) '(195))))) rows offs)   ; H: save; load; BODY(tail); restore; ret
       lr (\ ds (? (atom? ds) (L entry) (: d (cap ds) (link (cap d) (link (cup d) (lr (cup ds)))))))   ; defs -> (: (n p..) body .. entry)
       fb (ev (link ': (lr defs)))                                                            ; interp the WHOLE group, yield the entry closure
       elam (link '\ (cat (nthl efn 1) (L (nthl efn 2))))                                     ; the entry's source lambda (value[-1], =/show)
       (nif (emit (asm (link outer Hs))) fb elam (nthl efn 3)))
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
   ; a FIXNUM arg -> 0/1 -- no gem args (deferred: needs the lvm_flo type guard); a
   ; float RESULT is now `jitfr` below (the Have-checked box). a non-fixnum arg DEOPTS (fxv).
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
   ; --- HEAP RESULT (the deferred "Have-checked box"): (jitfr '(\ x <fexpr>)) returns a GEM, not 0/1.
   ; the lane never allocates because it can't GC (its raw regs aren't roots) -- so it does the alloc
   ; twin of the overflow guard: a ROOM GUARD (Sp - Hp >= flo_req+floor words) DEOPTS to interp when
   ; the heap is too full to fit the box, exactly as `jo` deopts when a fixnum result leaves range.
   ; fast path (room proven): write [Hp]=lvm_flo (apof's kind const, ASLR-captured at emit like the
   ; string guard), the double at [Hp+8] with NaN->0 (flo_put's law), return Hp UNTAGGED (an even heap
   ; ptr IS the gem), bump Hp by flo_req. the epilogue stores the POINTER (NO putfix) and threads the
   ; advanced Hp on through Continue, so the box is live to the next op and the GC at the next safepoint.
   floflo '(72 141 66 80  72 57 193)                                 ; lea rax,[rdx+80](=Hp+(flo_req+floor)w); cmp rcx,rax (Sp ? room)
   (jitfr lam)
    (: v (caup lam)  kind (apof 1.5)                                 ; lvm_flo's address, captured now (code never moves)
       roomg (asm (L floflo (L 115 (tally deopt)) deopt))            ; jae +|deopt| (room) ; else deopt-to-interp (heap full)
       nanc  '(102 15 46 192  123 4  102 15 87 192)                  ; ucomisd xmm0,xmm0 ; jnp +4 ; xorpd xmm0,xmm0  (NaN -> 0.0)
       boxw  (asm (L '(73 184) (le8 kind) '(76 137 2)                ; movabs r8,kind ; mov [rdx],r8       (box header = lvm_flo)
                     '(242 15 17 66 8) '(72 137 208) '(72 131 194 16)))   ; movsd [rdx+8],xmm0 ; mov rax,rdx ; add rdx,16
       epifr '(72 137 1  72 131 198 16  72 139 6  255 224)           ; mov [rcx],rax ; add rsi,16 ; Continue  (NO putfix: rax IS the gem)
       (nif (emit (asm (L (cgf v (caup (cup lam)) 0) roomg nanc boxw epifr))) (ev lam) lam 1))
   ; --- BYTE LAW (string RESULT): (jitba '(\ s (+ s B))) -- native s ++ [B], a fresh heap string. Same
   ;     heap-result machinery as jitfr but VARIABLE-sized: read len=[s+8], reserve n = str_type_width +
   ;     b2w(len+1) content words (NO GC tag -- the cheney scan derives a string's size from its len
   ;     field, ai.c:959; only threads/continuations are tag-copied), ROOM-GUARD-or-deopt (the alloc
   ;     twin again), write the ai_str header (kind = lvm_str via apof, len+1), COPY len bytes (an inline
   ;     loop -- rep movsb would clobber Ip=rsi/Sp=rcx), append B,
   ;     return the raw ai_str ptr (no putfix). A non-string s (fixnum/list/num) hits the kind TYPE
   ;     GUARD and deopts to the generic interpreter `+`. B is a compile-time byte (0..255). The
   ;     emitted body is offset-independent: every branch is a fixed local distance. ⚠ x86-64.
   (jitba lam)
    (: body (caup (cup lam))  B (caup (cup body))  kind (apof "")
       (nif (emit (asm (L
          '(76 139 1) (L 65 246 192 1 116 (tally deopt)) deopt                  ; mov r8,[rcx](=s); test r8b,1; jz+; deopt (fixnum)
          '(77 139 16 73 187) (le8 kind) (L 77 57 218 116 (tally deopt)) deopt   ; mov r10,[r8]; movabs r11,lvm_str; cmp; je+; deopt (non-str)
          '(77 139 72 8)                                                        ; mov r9,[r8+8]  (len)
          '(77 141 81 8 73 193 234 3 73 131 194 2)                              ; r10 = total_words = 2 + ((len+8)>>3)  (b2w(len+1), NO GC tag)
          '(78 141 20 210 73 131 194 64)                                        ; r10 = Hp + total*8 + floor(64)
          (L 76 57 209 115 (tally deopt)) deopt                                 ; cmp rcx,r10; jae+; deopt (heap full)
          '(76 137 26)                                                          ; mov [rdx],r11  (header: lvm_str)
          '(77 141 81 1 76 137 82 8)                                            ; r10=len+1 ; mov [rdx+8],r10
          '(49 192 76 57 200 15 141 16 0 0 0)                                   ; xor eax,eax ; COPY: cmp rax,r9 ; jge DONE(+16)
          '(69 15 182 84 0 16 68 136 84 2 16 72 255 192 235 231)                ; movzx r10d,[r8+rax+16]; mov [rdx+rax+16],r10b; inc rax; jmp COPY
          (L 66 198 68 10 16 B)                                                 ; DONE: mov byte [rdx+r9+16], B
          '(72 137 208)                                                         ; mov rax,rdx  (result = the new string ptr)
          '(77 141 81 8 73 193 234 3 73 131 194 2 74 141 20 210)                ; r10=total_words ; lea rdx,[rdx+r10*8]  (Hp += total*8)
          '(72 137 1 72 131 198 16 72 139 6 255 224))))                         ; mov [rcx],rax ; add rsi,16 ; Continue (NO putfix)
        (ev lam) lam 1))
   ; --- CASK-BACKED string BUILDER (sketch): (jitsb '(\ s <byte-map loop>) K) -- the O(n) PRODUCER lane.
   ;     the cask insight: allocate the RESULT once (sized N=len s; ONE room-guard-or-deopt), then a native
   ;     pin-LOOP writes out[i] = low8((peep s i 0)+K) with ZERO per-iteration allocation -- so no GC fires
   ;     in the loop (the whole wall), and it is O(n), not the immutable-append O(n^2). a non-string s
   ;     deopts to the interpreter. NO GC tag word (the cheney scan derives a string's size from len, so
   ;     unlike a tagged thread a string carries none -- this is the right framing jitba's surplus tag had
   ;     wrong). BOUNDED output only: out len == in len (a 1:1 byte map). K is the per-byte add, masked to
   ;     a byte by the low-8 store (matching (& (+ b K) 255)). The body is offset-independent. ⚠ x86-64.
   (jitsb lam K)
    (: kind (apof "")
       (nif (emit (asm (L
          '(76 139 1) (L 65 246 192 1 116 (tally deopt)) deopt                  ; mov r8,[rcx](=s); test r8b,1; jz+; deopt (fixnum)
          '(77 139 16 73 187) (le8 kind) (L 77 57 218 116 (tally deopt)) deopt   ; mov r10,[r8]; movabs r11,lvm_str; cmp; je+; deopt (non-str)
          '(77 139 72 8)                                                        ; mov r9,[r8+8]  (N = output len = input len)
          '(77 141 81 7 73 193 234 3 73 131 194 2)                              ; r10 = total = 2 + ((N+7)>>3)   (b2w(N), no tag)
          '(78 141 20 210 73 131 194 64)                                        ; r10 = Hp + total*8 + floor(64)
          (L 76 57 209 115 (tally deopt)) deopt                                 ; cmp rcx,r10; jae+; deopt (heap full)
          '(76 137 26 76 137 74 8)                                              ; mov [rdx],r11 (kind); mov [rdx+8],r9 (len=N)
          '(49 192)                                                             ; xor eax,eax  (i=0)
          '(76 57 200 15 141 23 0 0 0)                                          ; LOOP: cmp rax,r9 ; jge DONE(+23)
          '(69 15 182 84 0 16) (L 65 129 194) (le4 K)                           ; movzx r10d,[r8+rax+16] ; add r10d, K
          '(68 136 84 2 16 72 255 192 235 224)                                  ; mov [rdx+rax+16],r10b (low8 = &255) ; inc rax ; jmp LOOP(-32)
          '(72 137 208)                                                         ; DONE: mov rax,rdx  (result)
          '(77 141 81 7 73 193 234 3 73 131 194 2 74 141 20 210)                ; r10=total ; lea rdx,[rdx+r10*8]  (Hp += total*8)
          '(72 137 1 72 131 198 16 72 139 6 255 224))))                         ; mov [rcx],rax ; add rsi,16 ; Continue (NO putfix)
        (ev lam) lam 1))
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
  ; --- GROUP recursion (jitgroup): self + multi-arg + MUTUAL, native == interp, overflow -> bignum ---
  (: gfib (jitgroup (L (link '(fib n) '(? (< n 2) n (+ (fib (- n 1)) (fib (- n 2)))))) 'fib)
     (&& (lit? gfib) (75025 = (gfib 25))
         (= ((ev '(: (fib n) (? (< n 2) n (+ (fib (- n 1)) (fib (- n 2)))) fib)) 25) (gfib 25))
         (gfib = (jitgroup (L (link '(fib n) '(? (< n 2) n (+ (fib (- n 1)) (fib (- n 2)))))) 'fib))))   ; two natives, same source -> = (cache soundness)
  (: gtak (jitgroup (L (link '(tak x y z) '(? (< y x) (tak (tak (- x 1) y z) (tak (- y 1) z x) (tak (- z 1) x y)) z))) 'tak)
     (&& (7 = (gtak 18 12 6)) (7 = ((gtak 18 12) 6)) (7 = ((gtak 18) 12 6))))            ; nested self-calls; curries at any split
  ; MUTUAL recursion: evn/odn cross-call -- both compiled into ONE buffer, sibling calls native
  (: geo (jitgroup (L (link '(evn n) '(? (= n 0) 1 (odn (- n 1)))) (link '(odn n) '(? (= n 0) 0 (evn (- n 1))))) 'evn)
     god (jitgroup (L (link '(evn n) '(? (= n 0) 1 (odn (- n 1)))) (link '(odn n) '(? (= n 0) 0 (evn (- n 1))))) 'odn)
     (&& (1 = (geo 10)) (0 = (geo 7)) (1 = (geo 0)) (1 = (geo 100))                      ; entry=evn
         (0 = (god 10)) (1 = (god 7))))                                                  ; entry=odn (the other entry of the same group)
  ; overflow in a singleton group deopts to the interp fallback -> exact bignum (2^70)
  (: gp2 (jitgroup (L (link '(p2 n) '(? (< n 1) 1 (* 2 (p2 (- n 1)))))) 'p2)
     (= (ev '(: (p2 n) (? (< n 1) 1 (* 2 (p2 (- n 1)))) (p2 70))) (gp2 70)))
  ; the // and % integer ops in the GROUP lane (trial-division residue), with /-by-0 deopt
  (: gmod (jitgroup (L (link '(r n d) '(% n d))) 'r) (&& (1 = (gmod 10 3)) (0 = (gmod 12 4)) (= (% 7 0) (gmod 7 0))))
  (: gdiv (jitgroup (L (link '(q n d) '(// n d))) 'q) (&& (3 = (gdiv 10 3)) (-3 = (gdiv -10 3))))
  ; STRING LANE: native (peep s i) on a plain string (s passed RAW, byte at s+16); the apof TYPE GUARD
  ; deopts a non-string (fixnum / cask / nil) to the interp fallback -- never a bad deref. glazed == interp.
  (: gsb (jitgroup (L (link '(sb s i) '(? (< i 0) 0 (+ (peep s i 0) (sb s (- i 1)))))) 'sb)
     isb (ev '(: (sb s i) (? (< i 0) 0 (+ (peep s i 0) (sb s (- i 1)))) sb))
     d (string (L 72 105 90 33 65))
     (&& (365 = (gsb d 4)) (= (isb d 4) (gsb d 4))                                                ; string: native byte-sum == interp
         (= (isb 5 4) (gsb 5 4)) (= (isb (cask 3) 4) (gsb (cask 3) 4)) (= (isb () 4) (gsb () 4))))
  ; HEAP RESULT (jitfr): a float-result leaf BOXES on the heap -- a gem out, == interp, transparent, deopts
  (: fr (jitfr '(\ x (+ (* x 1.5) 2.0)))  ifr (\ x (+ (* x 1.5) 2.0))
     (&& (gem? (fr 4)) (8.0 = (fr 4)) (= (ifr 7) (fr 7))                  ; a FLOAT box; 4*1.5+2=8.0; == interp
         (lit? fr) ((\ x (+ (* x 1.5) 2.0)) = fr)                         ; applicable + =-IDENTICAL to source
         (= (map ifr '(1 2 3)) (map fr '(1 2 3)))                         ; composes with map, == interp
         (= (ifr (:)) (fr (:)))))                                         ; non-fixnum arg -> fxv deopt -> interp
  (: frz (jitfr '(\ x (/ (- x x) (- x x)))) (&& (gem? (frz 5)) (0.0 = (frz 5))))   ; 0/0 -> NaN -> 0.0 (flo_put's law)
  ; GC-SAFETY: a native-written box is a normal ai_flo (kind=lvm_flo, 2 words) -> the cheney copier
  ; traces/moves it like any gem. hold one across a big alloc (forces GC), and box thousands under
  ; pressure -- if the box were malformed or the bump corrupted Sp's region, these would diverge/crash.
  (: gfr (jitfr '(\ x (+ (* x 1.5) 2.0)))  b (gfr 4)  _ (tally (jot 200000))  (8.0 = b))   ; the box survives a forced GC
  (: gfr (jitfr '(\ x (+ (* x 1.5) 2.0)))  ys (map gfr (jot 4000))  zs (map (\ x (+ (* x 1.5) 2.0)) (jot 4000)) (= ys zs))  ; 4000 boxes under GC pressure == interp
  ; BYTE LAW (jitba): native s ++ [B] -- a fresh heap string, == interp, transparent, GC-safe, deopts
  (: ba (jitba '(\ s (+ s 66)))
     (&& (string? (ba "abc")) (= "abcB" (ba "abc")) (= ((\ s (+ s 66)) "abc") (ba "abc"))   ; appends byte 66='B', == interp
         (= "B" (ba "")) (4 = (tally (ba "abc")))                                            ; empty input -> a 1-byte string
         ((\ s (+ s 66)) = ba)                                                               ; =-identical to source
         (= (map (\ s (+ s 66)) (L "x" "ab" "")) (map ba (L "x" "ab" "")))                   ; composes == interp
         (= (+ 5 66) (ba 5)) (= (+ '(1 2) 66) (ba '(1 2)))))                                 ; non-string s -> kind guard deopts -> generic +
  (: ba (jitba '(\ s (+ s 90)))  b (ba "hello")  _ (tally (jot 200000))  (= "helloZ" b))     ; the string box survives a forced GC
  (: ba (jitba '(\ s (+ s 33)))  xs (map (\ i (string (L (+ 97 (% i 26))))) (jot 1500))      ; 1500 strings ++ '!' under GC pressure == interp
     (= (map (\ s (+ s 33)) xs) (map ba xs)))
  ; CASK-BACKED BUILDER (jitsb, sketch): O(n) string producer -- map each byte b -> (b+K)&255, == interp
  (: bsrc '(\ s ((: (go i acc) (? (< i (tally s)) (go (+ i 1) (+ acc (& (+ (peep s i 0) 1) 255))) acc)) 0 ""))
     sb (jitsb bsrc 1)  isb (ev bsrc)
     (&& (string? (sb "abc")) (= "bcd" (sb "abc")) (= (isb "abc") (sb "abc"))                ; +1 byte-map: abc->bcd, == interp
         (= "" (sb "")) (3 = (tally (sb "abc")))                                             ; empty -> empty; length preserved
         (= isb sb)                                                                          ; =-identical to its interpreted twin (same source)
         (= (map isb (L "Hello!" "xyz" "")) (map sb (L "Hello!" "xyz" "")))                  ; composes == interp
         (= (isb 5) (sb 5))))                                                                ; non-string s -> deopt -> interp
  (: sb (jitsb '(\ s ((: (go i acc) (? (< i (tally s)) (go (+ i 1) (+ acc (& (+ (peep s i 0) 3) 255))) acc)) 0 "")) 3)
     b (sb "hello")  _ (tally (jot 200000))  (= "khoor" b))                                  ; +3 build survives a forced GC (no tag needed)
  (: bs '(\ s ((: (go i acc) (? (< i (tally s)) (go (+ i 1) (+ acc (& (+ (peep s i 0) 1) 255))) acc)) 0 ""))
     sb (jitsb bs 1)  isb (ev bs)
     xs (map (\ i (string (L (+ 97 (% i 26)) (+ 65 (% i 7))))) (jot 1500))                   ; 1500 2-char strings, +1 byte-map under GC pressure == interp
     (= (map isb xs) (map sb xs)))   ; non-string -> guard deopts == interp
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
