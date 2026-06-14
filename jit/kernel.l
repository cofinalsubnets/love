; ============================================================================
; jit/kernel.l -- the FIRST native kernel: a fixnum  (\ x <arith>)  compiled to
; x86_64 machine code, with an overflow guard back to the interpreter. The whole
; codegen is love emitting bytes into a buf, then (forge)+(call) -- no C. This is
; roadmap step 2 (see jit/README.md): the unboxed fast-path that the self-hosted
; `ev` lambda analyzer (love/ev.l, where `(= (cap e) '\)`) would eventually call,
; guarded by `born` (a forged buf can NEVER be baked into the egg) and by target
; (x86_64 only; the VM is always the portable fallback).
;
; x86_64 ONLY (raw opcodes). Run on a hosted x86_64 build:
;
;     make host
;     out/host/love jit/kernel.l        # expect: every line "==", then ALL PASS
;
; KEPT OUT OF THE GATE CORPUS on purpose: x86 opcodes crash an aarch64/wasm host,
; so test/jit.l stays architecture-neutral and the real execution lives here, run
; by hand on the matching machine (the same rule as jit/forge.l + jit/probe.l).

; --- THE ABI ACROSS (call ...) ---
; (call f a) passes the love arg in %rdi as its RAW TAGGED word putfix(X)=2X+1,
; and re-tags the result putfix(r). So the kernel UNTAGS on entry (X = rdi>>1,
; arithmetic shift -- correct for negatives), computes on X, and leaves a result
; word in %rax. love fixnums auto-widen to bignum but native int64 WRAPS, so the
; kernel must never return a wrong answer: it tracks overflow and signals a BAIL,
; on which the love wrapper falls back to the interpreter.
;
; THE RESULT PROTOCOL (no error channel through call's fixnum return, so we encode
; one bit): success returns 2R (EVEN); bail returns 1 (ODD). The wrapper reads the
; low bit -- odd -> interpret instead. This costs one bit of range (2R must stay a
; valid fixnum, so the native path covers R in [-2^61, 2^61); anything past that
; bails to the VM, which is exact). Overflow is tracked BRANCHLESSLY: `seto r9b ;
; or r8b,r9b` after every op makes r8 a sticky OF accumulator, and the epilogue
; folds in the range check, so there are NO forward jumps to backpatch.

; --- the recognizer: is e a closed arith expr in the single variable x? ---
; (literals are non-negative fixnums: a negative literal needs two's-complement
; byte emission, deferred; negative *results* already work via the signed untag.)
(: (arithp e)
   (? (symp e) (idp e 'x)
      (&& (fixp e) (<= 0 e)) 1
      (&& (twop e) (= 3 (tally e)) (memq (cap e) '(+ - * // % < <= > >= =)))
        (&& (arithp (caup e)) (arithp (caup (cup e))))
      0))

; --- little-endian n bytes of a non-negative integer ---
(: (leb k n) (? (< n 1) () (cons (% k 256) (leb (// k 256) (- n 1)))))

; --- the overflow guard appended after every arithmetic op: r8 |= OF ---
(: guard '(65 15 144 193  69 8 200))            ; seto r9b ; or r8b,r9b

; --- division setup: guard divisor==0 (love's /0 is a FLOAT, unrepresentable
; here, so mark sticky -> bail), forcing a safe nonzero divisor to dodge #DE.
; (A is a fixnum, |A|<2^62, so the INT64_MIN/-1 #DE case can't arise.) cqo
; sign-extends rax into rdx:rax; idiv leaves quotient in rax, remainder in rdx. ---
(: divsetup
   '(69 49 201                                  ; xor  r9d,r9d            (45 31 C9)
     72 133 201                                 ; test rcx,rcx           (48 85 C9)
     65 15 148 193                              ; setz r9b   (B==0)       (41 0F 94 C1)
     69 8 200                                   ; or   r8b,r9b  -> sticky (45 08 C8)
     76 1 201                                   ; add  rcx,r9 (B==0 -> 1) (4C 01 C9)
     72 153                                     ; cqo                     (48 99)
     72 247 249))                               ; idiv rcx                (48 F7 F9)

; --- a comparison: cmp, set the byte, zero-extend to 0/1 in rax. NO overflow
; guard -- cmp sets OF as a side effect and we must NOT fold it into the sticky. ---
(: (cmpc op)
   (cat '(72 57 200)                            ; cmp rax,rcx             (48 39 C8)
    (cat (? (idp op '<)  '(15 156 192)          ; setl  al                (0F 9C C0)
            (idp op '<=) '(15 158 192)          ; setle al                (0F 9E C0)
            (idp op '>)  '(15 159 192)          ; setg  al                (0F 9F C0)
            (idp op '>=) '(15 157 192)          ; setge al                (0F 9D C0)
                         '(15 148 192))         ; sete  al  ('=)          (0F 94 C0)
         '(15 182 192))))                       ; movzx eax,al            (0F B6 C0)

; --- combine: the full post-(pop rax) sequence leaving rax = (A op B). Arith ops
; carry the overflow guard; // and % carry the zero-divide guard inside divsetup;
; comparisons carry none. ---
(: (combine op)
   (? (idp op '+)  (cat '(72 1 200) guard)      ; add  rax,rcx ; guard    (48 01 C8)
      (idp op '-)  (cat '(72 41 200) guard)     ; sub  rax,rcx ; guard    (48 29 C8)
      (idp op '*)  (cat '(72 15 175 193) guard) ; imul rax,rcx ; guard    (48 0F AF C1)
      (idp op '//) divsetup                     ; rax = quotient
      (idp op '%)  (cat divsetup '(72 137 208)) ; ... ; mov rax,rdx       (48 89 D0)
      (cmpc op)))                               ; <, <=, >, >=, = -> 0/1

; --- emit e -> the bytes leaving e's value in rax, overflow folded into r8 ---
(: (emit e)
   (? (symp e) '(72 137 248  72 209 248)        ; x: mov rax,rdi ; sar rax,1  (48 89 F8  48 D1 F8)
      (fixp e) (cons 72 (cons 184 (leb e 8)))   ; k: mov rax,imm64            (48 B8 <le64>)
      (: op (cap e) a (caup e) b (caup (cup e))
         (cat (emit a)                          ; rax = A
          (cat '(80)                            ; push rax                    (50)
           (cat (emit b)                        ; rax = B
            (cat '(72 137 193  88)              ; mov rcx,rax ; pop rax (A)   (48 89 C1  58)
             (combine op))))))))                ; rax = (A op B), guard folded per op

(: prologue '(69 49 192))                       ; xor r8d,r8d   (45 31 C0): clear the sticky flag

; epilogue: rax=R. Double once (rax=2R, guard catches R out of fixnum range),
; test the double again (4R, guard catches 2R out of range = the binding check),
; then branchlessly pick 2R (success) or 1 (bail) by the sticky flag.
(: epilogue
   (cat '(72 1 192)                             ; add rax,rax  -> 2R          (48 01 C0)
    (cat guard
     (cat '(72 137 193  72 1 201)               ; mov rcx,rax ; add rcx,rcx (test 4R)  (48 89 C1  48 01 C9)
      (cat guard
       '(185 1 0 0 0                            ; mov ecx,1   (bail value, odd)  (B9 01 00 00 00)
         77 133 192                             ; test r8,r8                     (4D 85 C0)
         72 15 69 193                           ; cmovne rax,rcx (overflow -> 1) (48 0F 45 C1)
         195))))))                              ; ret                            (C3)

; --- a byte list -> a buf ---
(: (l2b bs)
   (: n (tally bs) b (buf n)
      _ ((: (go i l) (? l (: _ (pin b i (cap l)) (go (+ i 1) (cup l))) 0)) 0 bs)
      b))

; --- THE DRIVER: a (\ x <arith>) source form -> a native closure (VM fallback) ---
(: (jit lam)
   (: body (caup (cup lam))
      vm (ev lam)                               ; the interpreter compile -- always available
      (? !(arithp body) vm                      ; not JIT-able: hand back the VM closure
         (: code (forge (l2b (cat prologue (cat (emit body) epilogue))))
            (\ a (: v (call code a)             ; v = 2R (even, success) or 1 (odd, bail)
                    (? (& v 1) (vm a) (// v 2))))))))   ; odd -> interpret; even -> R

; ============================================================================
; SELF-CHECK: native must equal the interpreter on every case, success AND
; overflow (which routes through the bail to the exact VM/bignum answer).
(: bad (tablet 0)
   (ck nm n form)
     (: j (jit form) vm (ev form) jr (j n) vr (vm n) ok (= jr vr)
        _ (dot (+ nm (+ " @" (+ (show n) (+ ": native=" (+ (show jr)
              (+ (? ok "  ==  " "  =/=  ") (+ (show vr) (? ok "\n" "   <-- FAIL\n")))))))))
        (? ok 0 (pin bad 0 (+ 1 (peep bad 0 0)))))
   _ (ck "x*x      " 7          '(\ x (* x x)))
   _ (ck "x*x+1    " 7          '(\ x (+ (* x x) 1)))
   _ (ck "3x-7     " 10         '(\ x (- (* 3 x) 7)))
   _ (ck "3x-7     " -4         '(\ x (- (* 3 x) 7)))            ; negative input: signed untag
   _ (ck "(x+1)*(x-1)" 9        '(\ x (* (+ x 1) (- x 1))))     ; nested binops
   _ (ck "x*x      " 1000000000 '(\ x (* x x)))                 ; 1e18 < 2^61: native
   _ (ck "x*x      " 2000000000 '(\ x (* x x)))                 ; 4e18: 2R out of range -> bail -> VM
   _ (ck "x*x      " 4000000000 '(\ x (* x x)))                 ; 1.6e19: bail -> VM bignum
   _ (ck "(x+x)*x  " 3037000500 '(\ x (* (+ x x) x)))           ; overflow mid-expr -> bail -> VM
   _ (ck "x//3     " 17         '(\ x (// x 3)))                ; truncating division
   _ (ck "x//3     " -17        '(\ x (// x 3)))               ; toward zero (-5, like the VM)
   _ (ck "x%7      " 100        '(\ x (% x 7)))                ; remainder
   _ (ck "x%7      " -100       '(\ x (% x 7)))                ; dividend's sign (-2)
   _ (ck "100//x   " 0          '(\ x (// 100 x)))             ; /0 -> love float -> bail -> VM (ieee-inf)
   _ (ck "100%x    " 0          '(\ x (% 100 x)))              ; %0 -> bail -> VM (0.0)
   _ (ck "x<10     " 7          '(\ x (< x 10)))               ; comparison -> 1
   _ (ck "x<10     " 20         '(\ x (< x 10)))               ; -> 0
   _ (ck "x>=x*x   " 1          '(\ x (>= x (* x x))))         ; 1>=1 -> 1
   _ (ck "x=42     " 42         '(\ x (= x 42)))               ; equality -> 1
   _ (ck "(x%2)<1  " 8          '(\ x (< (% x 2) 1)))          ; even? composed: % then <
   _ (ck "fallback " 5          '(\ x (cap x)))                 ; non-arith: jit == vm (both interpret)
   _ (dot (? (peep bad 0 0) (+ (show (peep bad 0 0)) " FAILED\n") "ALL PASS\n")))
