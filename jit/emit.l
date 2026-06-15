; emit -- the codegen backend: a love-level x86-64 emitter that compiles a love
; closure to NATIVE machine code and installs it as a TRANSPARENT applicable value.
; This is "ev but faster": the result applies by juxtaposition ((f x), no verb), is
; =/show IDENTICAL to its source, and DEOPTS to the interpreter on overflow -- so
; native is never wrong, only faster. The C seam is `nat` (love.c): it W^X-installs
; the bytes and wraps them in a closure cell [code, src, code, interp, lvm_ret, 0]
; whose value[-1]=src (=/show) and value[1]=interp (the deopt fallback).
;
; ⚠ x86-64 ONLY (emits x86-64; load with -l on an x86-64 host). WIP toward the auto
; hook (ev installing native for hot regions, transparently); `nat` then goes
; internal (mopped like boxfix/wev) and there is no user-facing verb at all.
;
; lvm ABI: g=rdi Ip=rsi Hp=rdx Sp=rcx. The body accumulates UNTAGGED in rax, the
; machine stack (push/pop) holds nested operands, r8 the popped temp; the loop uses
; r9=n r10=i r11=acc. Every +/-/* and the final putfix carry a `jno` over an inline
; deopt (mov rax,[rsi+8](=interp); mov rsi,rax; mov rax,[rsi]; jmp rax) -- a tail
; apply of interp to the original arg (still in Sp[0]). putfix is add rax,rax (its OF
; flag is exactly the 62-bit fixnum boundary); jno; or rax,1.
(: (le8 n) ((: (go i) (? (< i 8) (cons (& (>> n (* 8 i)) 255) (go (+ i 1))) 0)) 0)  ; n -> 8 LE bytes
   (le4 n) ((: (go i) (? (< i 4) (cons (& (>> n (* 8 i)) 255) (go (+ i 1))) 0)) 0)  ; n -> 4 LE bytes
   deopt    '(72 139 70 8  72 137 198  72 139 6  255 224)   ; mov rax,[rsi+8]; mov rsi,rax; mov rax,[rsi]; jmp rax
   guard    (cat '(113 12) deopt)                            ; jno +12 ; deopt   (skip deopt unless overflow)
   ld-x     '(72 139 1  72 209 248)                          ; mov rax,[rcx]; sar rax,1   (load arg, untag)
   ld-i     '(76 137 208)                                     ; mov rax,r10               (loop var i)
   push-rax '(80)   pop-r8 '(65 88)
   epilogue (cat '(72 1 192) (cat guard (cat '(72 131 200 1) (cat '(72 137 1)   ; add rax,rax;guard;or rax,1;mov[rcx]
              (cat '(72 131 198 16) '(72 139 6  255 224))))))                    ; add rsi,16; Continue
   (opseq op) (? (= op '+) (cat pop-r8 (cat '(76 1 192) guard))                  ; add rax,r8 ; guard
                 (= op '*) (cat pop-r8 (cat '(73 15 175 192) guard))             ; imul rax,r8 ; guard
                 (= op '-) (cat pop-r8 (cat '(73 41 192) (cat guard '(76 137 192))))  ; sub r8,rax;guard; mov rax,r8
                 0)
   (cgv v vl e) (? (= e v)  vl                                                   ; the variable -> its load
                   (intp e) (cat '(72 184) (le8 e))                              ; movabs rax, n
                   (twop e) (: a (caup e) b (caup (cup e))                       ; (op a b)
                               (cat (cgv v vl a) (cat push-rax (cat (cgv v vl b) (opseq (cap e))))))
                   0)
   (emit l) (: b (buf (tally l)) _ ((: (go i x) (? (twop x) (: _ (pin b i (cap x)) (go (+ i 1) (cup x))) 0)) 0 l) b)
   ; (jit '(\ x E)) -- compile an arithmetic single-arg closure to native.
   (jit lam) (nat (emit (cat (cgv 'x ld-x (caup (cup lam))) epilogue)) (ev lam) lam)
   ; (loopcode body cv) -- the native counted-loop bytes for sum_{cv<n} body(cv),
   ; cv the counter var (limit at Sp[0]). r9=n r10=cv r11=acc. Reusable by jitsum
   ; and by the auto loop-detector (jit/auto.l).
   (loopcode body cv)
    (: lb   (cgv cv ld-i body)  Lb (tally lb)
       pre  '(76 139 9  73 209 249  77 49 210  77 49 219)                         ; mov r9,[rcx];sar;xor r10;xor r11
       test (cat '(77 57 202) (cat '(15 141) (le4 (+ Lb 25))))                     ; cmp r10,r9 ; jge loop_end
       acc  (cat '(73 1 195) guard)                                               ; add r11,rax ; guard
       back (cat '(73 255 194) (cat '(233) (le4 (- 0 (+ Lb 34)))))                ; inc r10 ; jmp loop_top
       (cat pre (cat test (cat lb (cat acc (cat back (cat '(76 137 216) epilogue)))))))   ; ... ; mov rax,r11
   ; (jitsum body) -- compile (\ n (sum_{i<n} body(i))) to a native counted loop.
   (jitsum body)
    (: src `(\ n ((: (go i a) (? (< i n) (go (+ i 1) (+ a ,body)) a)) 0 0))
       (nat (emit (loopcode body 'i)) (ev src) src))
   ; --- self-test (x86-64): native == interpreted, transparent, deopts ---------
   (isum n) ((: (go i a) (? (< i n) (go (+ i 1) (+ a (* i 7))) a)) 0 0)
   f (jit '(\ x (+ (* x 3) 1)))   g (jitsum '(* i 7))
 _ (assert
  (lamp f) (lamp g)                                          ; native closures are applicable values
  (31 = (f 10)) (315 = (g 10))                               ; they compute
  ((\ x (+ (* x 3) 1)) = f)                                  ; ... and are =-IDENTICAL to their source
  !(f = (\ x (+ (* x 3) 2)))
  (f = (jit '(\ x (+ (* x 3) 1))))                           ; two natives, same source
  ('(2 4 6) = (map (jit '(\ x (+ x 1))) '(1 3 5)))           ; compose with higher-order fns
  ((isum 1000) = (g 1000))                                   ; the loop agrees with the interpreter
  (9000000000000000000 = ((jit '(\ x (* x x))) 3000000000))  ; OVERFLOW -> deopt -> correct bignum
  (1 = ((: (go i a) (? (< i 60) (go (+ i 1) (&& a (= ((jit `(\ x (* x ,i))) 7) (* 7 i)))) a)) 0 1)))  ; agree 0..60
 _ (puts "jit/emit: native codegen ok (arith + loop, transparent, deopt)") _ (putc 10))
