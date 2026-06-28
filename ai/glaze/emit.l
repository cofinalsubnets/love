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
   ; the leaf/loop arith body-codegen + its helpers (cgv, opseq/idivseq/bitseq/cmpseq/setcc, condcode)
   ; are RETIRED: the IR lanes carry them now -- cgir (leaf/n-ary) and cgvir (loops). guard/guardz/fetch/
   ; untag survive (the float param-load fxv); epilogue survives (jitf + the loop/grid raw tails).
   epilogue
    ; add rax,rax;guard;or rax,1;mov[rcx] ; add rsi,16; Continue
    ('(72 1 192) + (guard 0) + '(72 131 200 1 72 137 1 72 131 198 16 72 139 6 255 224))
   (emit l) (: b (cask (tally l)) _ ((: (go i x) (? (two? x) (: _ (pin b i (cap x)) (go (+ i 1) (cup x))) ())) 0 l) b)
   ; (jit '(\ x E)) -- compile an arithmetic single-arg closure to native.
   (jit lam) (jitir lam 'x64)  ; arity-1 leaf -> the neutral-IR lane (cgir)
   ; --- the arity-INDEPENDENT deopt/epilogue blobs for the >=2-arity natives: the deopt jmps to interp's
   ; BODY (interp+16 past its lvm_cur) where the saturated args already sit. The byte n-ary ARITH lane
   ; (cgn + opseq-mn/idivseq-mn) is retired -- jitn now routes through the neutral-IR cgir (below); these
   ; three blobs stay because the float loop driver (loopcode-f) reuses epilogue-mn.
   deopt-mn '(72 139 70 8  72 141 112 16  72 139 6  255 224)  ; mov rax,[rsi+8]; lea rsi,[rax+16]; mov rax,[rsi]; jmp rax
   (guard-mn d)  (+ '(113 20) (+ (+ '(72 129 196) (le4 (* 8 d))) deopt-mn))   ; jno +20; add rsp,8d; deopt-mn
   epilogue-mn (+ '(72 1 192) (+ (guard-mn 0) (+ '(72 131 200 1) (+ '(72 137 1)
                 (+ '(72 131 198 16) '(72 139 6  255 224))))))
   ; argix finds a param var's frame index in ps (shared with the IR lane's fxir/cgir).
   (argix e ps i) (? !(two? ps) 0  (= e (cap ps)) i  (argix e (cup ps) (+ i 1)))   ; param -> index
   ; (jitn '(\ p0 .. body)) -- an arity>=2 leaf -> native (natn curries to saturation). Now an ALIAS for
   ; the neutral-IR lane (jitnir): cgir already serves the n-ary case in IR, so the old byte cgn/-mn
   ; family below is retired (deleted) -- one lane, label-resolved, and arm64 falls out for free.
   (jitn lam) (jitnir lam 'x64)
   (jit2 lam) (jitn lam)                                                  ; arity-2 alias (self-test/auto.l)
   (gfind p l) (? (atom? l) () (p (cap l)) (cap l) (gfind p (cup l)))     ; first elt matching p
   (gfilt p l) (? (atom? l) () (p (cap l)) (link (cap l) (gfilt p (cup l))) (gfilt p (cup l)))   ; keep elts matching p
   chainkind (apof (link 0 0))                                                      ; lvm_chain's ap sentinel, for the inline two?/cap/cup kind test (cf. (apof "") for the string lane)
   mapkind (apof (tablet 0))                                                        ; lvm_map_lookup's sentinel, for the map-param entry guard + the (mpeep ..) probe
   mapmix 11400714819323198485                                                      ; the hash multiplier 0x9e3779b97f4a7c15 (= ai.c's map hash mult), for the inline probe
   ; -- the map probe, via the asm/ assembler SERVICE (baked into the post-egg layer; the glaze is its
   ;    client). asm/ resolves the hit/miss/loop labels to rel32 -- no hand-counted je/jmp offsets, the
   ;    fragile bit. reg map: asm r0=rax, r7=x86-r8, r8=x86-r9, r9=x86-r10, r10=x86-r11. The probe wants
   ;    the MAP in rax and the TAGGED key in r11 (asm r10); it ends branched to `hit` (match) / `miss` (gap).
   (asmx ir) (peep (assemble 'x64 ir) 'bytes 0)                                     ; assemble neutral IR -> flat bytes (the post-egg `assemble` service; emit.l's own `asm` is byte-concat, untouched)
   mprobe-ir (L '(ld r7 r0 8) '(ld r8 r7 16) '(shr r8 1) '(dec r8) '(add r7 r7 24)    ; r8=backing; r9=cap; >>1; --(=mask); r8=&slots
      (L 'li 'r0 mapmix) '(imul r0 r0 r10) '(rol r0 32) '(and r0 r0 r8) '(mov r9 r0)    ; rax=rot(mix*tagkey)&mask=I -> r10
      '(label loop) '(leax r0 r9 r9 1 0) '(ldx r0 r7 r0 8 0) '(cmp r0 r10) '(br eq hit)  ; slot[I].key == tagkey? -> hit
      '(test r0 1) '(br eq miss) '(inc r9) '(and r9 r9 r8) '(jmp loop))                  ; gap (even) -> miss; else I=(I+1)&mask, loop
   (mpeep-ir d) (cat mprobe-ir                                                      ; READ tails: MISS -> default d; HIT -> slot[I].value, untagged
      (L (L 'label 'miss) (L 'li 'r0 d) '(jmp end)
         '(label hit) '(leax r0 r9 r9 1 0) '(ldx r0 r7 r0 8 8) '(sar r0 1) '(label end)))
   (asmx-seed ir nm addr) (: t (tablet 0) _ (pin t nm addr) (peep (assemble-at 'x64 ir t) 'bytes 0))   ; assemble with ONE pre-bound external label nm->addr (the glaze's deopt handler)
   ; the SAME probe; WRITE tails (the correct `pin` = insert-OR-update). MISS (absent key, a GAP at slot I):
   ; guard the load factor -- if (len+1)*4 >= cap*3 a grow is due, which native can't do, so DEOPT (an
   ; EXTERNAL label the caller seeds); else INSERT (store the tagged key + spilled value, bump len). HIT:
   ; update in place. `(tablet n)` presizes so a counted insert loop of n keys never hits the deopt. The
   ; key/value are FIXNUMS (the group compiler is integer-only), so no GC write-barrier is needed.
   mpin-ir (mprobe-ir + '((label miss)
      (ld r0 r7 -16) (sar r0 1) (cmp r0 r8) (br ge deopt)                           ; len >= mask(=cap-1) -> table near-full -> deopt (r8 still holds the mask)
      (leax r0 r9 r9 1 0) (stx r7 r0 8 0 r10)                                       ; slot[I].key = tagged key
      (pop r8) (leax r8 r8 r8 1 1) (stx r7 r0 8 8 r8)                               ; slot[I].value = tag(v)
      (ld r0 r7 -16) (add r0 r0 2) (st r7 -16 r0) (jmp end)                         ; len++ (putcharm: +2)
      (label hit) (leax r0 r9 r9 1 0) (pop r8) (leax r8 r8 r8 1 1) (stx r7 r0 8 8 r8)
      (label end)))
   (hasl e) (? (two? e) (|| (id? (cap e) 'link) (foldl (\ a x (|| a (hasl x))) 0 (cup e))) 0)   ; does e syntactically contain a (link ..)? -> the group is VALUE-typed
   (suse? e P) (? (two? e) (? (&& (member? (cap e) '(peep tally pin)) (id? (caup e) P)) 1 (foldl (\ a x (|| a (suse? x P))) 0 (cup e))) 0)   ; P used DIRECTLY as (peep P..)/(tally P)/(pin P..)?
   (buse? e P) (? (two? e) (? (&& (id? (cap e) 'pin) (id? (caup e) P)) 1 (foldl (\ a x (|| a (buse? x P))) 0 (cup e))) 0)   ; P used as a CASK -- (pin P..) -- so its guard wants the buf kind, not str
   (cuse? e P) (? (two? e) (? (&& (member? (cap e) '(cap cup two?)) (id? (caup e) P)) 1 (foldl (\ a x (|| a (cuse? x P))) 0 (cup e))) 0)   ; P used as a CHAIN -- (cap P)/(cup P)/(two? P) -- raw pointer, NO entry guard (two? is total: a non-chain reads false)
   (muse? e P) (? (two? e) (? (&& (|| (id? (cap e) 'mpeep) (id? (cap e) 'mpin)) (id? (caup e) P)) 1 (foldl (\ a x (|| a (muse? x P))) 0 (cup e))) 0)   ; P used as a MAP -- (mpeep P k d) READ or (mpin P k v) UPDATE -- raw pointer, guarded as a map
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
   ; --- counted fold loop: acc = (FOLD over cv<n of body(cv)), cv the counter, limit
   ; at Sp[0]. r9=n r10=cv r11=acc. FOLD is a (op . init) -- + folds from 0, * from 1 --
   ; and cmp is the loop test's comparison (the loop runs while (cmp cv n)). offsets are
   ; COMPUTED from the piece lengths, not hardcoded, so a longer acc op (imul) is fine.
   (r11-init a0) (? (= a0 0) '(77 49 219) (+ '(73 199 195) (le4 a0)))   ; xor r11,r11 / mov r11,a0  (loopcode pre; acc-fold is IR)
   (foldinit op)  (? (= op '*) 1 0)                               ; * folds from 1, + from 0
   ; END condition = the INVERSE of the continue-comparison (exit when (cmp cv n) is false).
   (exitcc cmp) (? (= cmp '<) 'ge (= cmp '<=) 'gt (= cmp '>) 'le
                   (= cmp '>=) 'lt (= cmp '=) 'ne ())  ; ge/gt/le/lt/ne
   (loopcode body cv op cmp)
    (: bodyir (cgvir 'x64 (\ e d (? (= e cv) '((mov r0 r9)) ())) body 0)      ; body -> acc(rax); cv loaded raw from r10 (IR r9)
       accir  (cat (? (id? op '+) '((adds r10 r10 r0)) (id? op '*) '((imul r10 r10 r0)) ()) (ldeopt 'x64 0))   ; r11 = r11 op rax ; overflow -> deopt
       pre  (+ '(76 139 9  73 209 249  77 49 210) (r11-init (foldinit op)))    ; mov r9,[rcx];sar;xor r10; init r11
       ; whole loop in asm/ IR now: pre/epilogue are raw x86 blobs, the BODY + acc-fold + control flow are
       ; label-resolved IR. phys r9=n r10=cv r11=acc -> IR r8 r9 r10, so cmp r10,r9 = (cmp r9 r8).
       (asmx (cat (L `('raw pre) '(label top) '(cmp r9 r8) `('br (exitcc cmp) 'end))   ; cmp cv,n ; exit when (cmp cv n) false
              (cat bodyir (cat accir
                   (L '(inc r9) '(jmp top) '(label end) '(mov r0 r10) `('raw epilogue)))))))   ; cv++ ; loop ; mov rax,r11
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
   ; lvreg: loop var j -> its abstract register (v0/v1/v2 = phys r9/r10/r11 = IR r8/r9/r10).
   (lvreg j) (nthl '(r8 r9 r10) j)
   (loopcode-n n vars updates test result inits)
    ; the whole N-var loop in asm/ IR. nvld loads a var: n from Sp[0] (fxvir, guarded), a loop var from its
    ; raw register. updates are computed from the OLD regs (all pushed at depth j, then popped reverse so
    ; reg(j) <- Uj). control flow + per-depth deopt are label-resolved; only epilogue stays a raw blob.
    (: nvld (\ e d (? (= e n) (fxvir 'x64 0 d)
                       (member? e vars) (L (L 'mov 'r0 (lvreg (argix e vars 0))))
                       ()))
       pre  ((: (go j is) (? (two? is) (cat (L (L 'li (lvreg j) (cap is))) (go (+ j 1) (cup is))) ())) 0 inits)        ; reg-init
       ups  ((: (go j us) (? (two? us) (cat (cgvir 'x64 nvld (cap us) j) (cat (L '(push r0)) (go (+ j 1) (cup us)))) ())) 0 updates)   ; push Uj at depth j
       pops ((: (go j) (? (< j 0) () (cat (L (L 'pop (lvreg j))) (go (- j 1))))) (- (tally updates) 1))                ; pop reg(k-1)..reg(0)
       tb   (cgvir 'x64 nvld test 0)
       rb   (cgvir 'x64 nvld result 0)
       (asmx (cat pre (cat (L '(label top))
              (cat tb (cat (L '(cmp r0 0) '(br eq end))                ; <test>; rax==0 (false) -> end
              (cat ups (cat pops (cat (L '(jmp top) '(label end))      ; updates ; loop top
              (cat rb (L `('raw epilogue))))))))))))                    ; result -> rax
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
   xpush '(72 131 236 8 242 15 17 4 36)                              ; sub rsp,8 ; movsd [rsp],xmm0  (bytes, for the byte-built grid lanes)
   xpop1 '(242 15 16 12 36 72 131 196 8)                             ; movsd xmm1,[rsp] ; add rsp,8
   xpushir '((sub sp sp 8) (stsd sp 0 f0))                           ; the same spill, as asm/ IR (the scalar float lane): xmm0 -> [rsp]
   xpop1ir '((ldsd f1 sp 0) (add sp sp 8))                           ; the same reload, as asm/ IR: [rsp] -> xmm1
   (fconst c) `(`('li 'r0 (fbits c)) '(movqxr f0 r0))               ; movabs rax,bits ; movq xmm0,rax
   (fbinop op) (? (= op '+) '((addsd f0 f1))                         ; addsd xmm0,xmm1
                  (= op '*) '((mulsd f0 f1))                         ; mulsd xmm0,xmm1
                  (= op '-) '((subsd f1 f0) (movsd f0 f1))           ; subsd xmm1,xmm0 ; movsd xmm0,xmm1
                  (= op '/) '((divsd f1 f0) (movsd f0 f1))           ; divsd xmm1,xmm0 ; movsd xmm0,xmm1
                  ())                                                ; asm/ IR (reg-reg SSE); byte-lane callers wrap via (asmx (fbinop op))
   ; cgf: a FLOAT subexpr over {x (the fixnum param -> cvtsi2sd) ; numeric consts} -> xmm0, as asm/ IR.
   ; the [rsp] spills are now IR too (xpushir/xpop1ir); only the param load (fxv) stays a raw byte blob.
   (cgf v e d) (? (= e v)   `(`('raw (fxv 0 d)) '(cvtsi2sd f0 r0))   ; param: fixnum-guarded load + cvtsi2sd
                  (gem? e)  (fconst e)                               ; a float constant
                  (whole? e)(fconst (+ e 0.0))                       ; an int constant -> promote to double
                  (two? e) (: op (cap e) a (caup e) b (caup (cup e))
                     (? (member? op '(+ - * /)) (+ (cgf v a d) (+ xpushir (+ (cgf v b (+ d 1)) (+ xpop1ir (fbinop op))))) ()))
                  ())
   ; cgfp: a float PREDICATE (cmp A B) -> rax 0/1 (A->xmm1, B->xmm0; ucomisd then set).
   (cgfp v e d) (: op (cap e) a (caup e) b (caup (cup e))
      cc (? (= op '<) 'below (= op '<=) 'be (= op '>) 'above (= op '>=) 'ae 'eq)
      (+ (cgf v a d) (+ xpushir (+ (cgf v b (+ d 1)) (+ xpop1ir
         (+ '((ucomisd f1 f0)) `(`('set cc 'r0))))))))               ; ucomisd xmm1,xmm0 ; rax = (cc) ? 1 : 0
   ; (jitf '(\ x (cmp <fexpr> <fexpr>))) -- a float predicate over a fixnum arg -> native 0/1.
   (jitf lam) (: v (caup lam) (nif (emit (asmx (+ (cgfp v (caup (cup lam)) 0) `(`('raw epilogue))))) (ev lam) lam 1))
   ; --- HEAP RESULT (the deferred "Have-checked box"): (jitfr '(\ x <fexpr>)) returns a GEM, not 0/1.
   ; the lane never allocates because it can't GC (its raw regs aren't roots) -- so it does the alloc
   ; twin of the overflow guard: a ROOM GUARD (Sp - Hp >= flo_req+floor words) DEOPTS to interp when
   ; the heap is too full to fit the box, exactly as `jo` deopts when a fixnum result leaves range.
   ; fast path (room proven): write [Hp]=lvm_flo (apof's kind const, ASLR-captured at emit like the
   ; string guard), the double at [Hp+8] with NaN->0 (flo_put's law), return Hp UNTAGGED (an even heap
   ; ptr IS the gem), bump Hp by flo_req. the epilogue stores the POINTER (NO putfix) and threads the
   ; advanced Hp on through Continue, so the box is live to the next op and the GC at the next safepoint.
   (jitfr lam)
    (: v (caup lam)  kind (apof 1.5)                                 ; lvm_flo's address, captured now (code never moves)
       nanc '(102 15 46 192  123 4  102 15 87 192)                   ; ucomisd xmm0,xmm0 ; jnp +4 ; xorpd (NaN->0): parity cc + self-jump -> raw
       ; asm/ IR: the room-guard skips the deopt blob by LABEL (no hand offset); the box store is the
       ; new SSE-mem op `stsd`. cgf/deopt/nanc stay raw (float blob / self-contained jumps).
       (nif (emit (asmx (+ (cgf v (caup (cup lam)) 0)                ; cgf now emits IR -> concat (not raw)
          `('(lea r0 r2 80)                                          ; lea rax,[Hp+(flo_req+floor)w]
            '(cmp r1 r0) '(br ae okroom) `('raw deopt) '(label okroom)   ; cmp Sp,rax ; jae over deopt (else heap-full deopt)
            `('raw nanc)                                             ; NaN -> 0.0
            `('li 'r7 kind) '(st r2 0 r7)                            ; movabs r8,lvm_flo ; mov [Hp],r8  (box header)
            '(stsd r2 8 f0)                                          ; movsd [Hp+8],xmm0
            '(mov r0 r2) '(add r2 r2 16)                             ; rax = Hp (the gem ptr) ; Hp += 16
            '(st r1 0 r0) '(add r5 r5 16) '(ld r0 r5 0) '(jmpr r0)))))   ; mov [Sp],rax ; Continue (NO putfix: rax IS the gem)
        (ev lam) lam 1))
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
   (hcon v ht) (: r (hlook v ht) (? (< -1 r) (+ '(242 15 16) (list (+ 192 r))) (asmx (fconst v))))   ; hoisted -> movsd xmm0,xmm_r ; else inline fconst
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
                               (? (member? op '(+ - * /)) (+ (cgF ht ce ie fe a d) (+ (rpush d) (+ (cgF ht ce ie fe b (+ d 1)) (+ (rpop d) (asmx (fbinop op)))))) ()))
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
                                   (? (member? op '(+ - * /)) (+ (cgFd ht ce a) (+ xpush (+ (cgFd ht ce b) (+ xpop1 (asmx (fbinop op)))))) ()))
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
    ; the scalar D-dim grid kernel as a neutral asm/ IR PROGRAM (the grid2 pattern, single-step): control
    ; flow is LABELS (no hand offsets), the recurrence is allocp's CSE'd named-SSE forms, the cold derives
    ; (cgFd) stay raw. k=r7(iter), acc=r8, counters=r9..(gr); xmm: consts xmm2.., invariants xmm8.., fvars
    ; next, the rest the DAG pool. D>=3 spills callee-saved counters; the acc-overflow deopt restores them.
    (: D (tally dims)  M (tally invs)  N (tally fvars)
       cregs (rangeL 10 (+ 10 D))                                             ; counter regs (phys r10..), outer->inner
       saved (rangeL 12 (+ 10 D))                                            ; the callee-saved counters (phys r12..) for D>=3
       fenv (cat invs fvars)
       cenv (map2 (\ nm r `(nm (cvtcnt r))) cnames cregs)                     ; counter name -> cvtsi2sd bytes (cgFd reads, raw)
       ht (htbl (fcc bound (fccl invd (fccl updates (fcc testexpr ())))) 2)   ; distinct consts -> xmm2..7
       derives (foldl (\ a p (a + `(`('raw (cgFd ht cenv (cup p))) `('movsd (fr (8 + (cap p))) 'f0)))) () (map2 (\ i d (link i d)) (rangeL 0 M) invd))   ; inv i -> xmm(8+i)
       zerof (foldl (\ a j (a + `(`('xorpd (fr (8 + M + j)) (fr (8 + M + j)))))) () (rangeL 0 N))   ; fvar j -> xmm(8+M+j) = 0
       aenv ((efold fenv 8) + ht)
       pool (`(0 1) + (rangeL (+ 8 (+ M N)) 16))
       AR (vnall (link testexpr updates) () ())  rootv (cap AR)  dag (caup AR)  nn (tally dag)
       AL (allocp dag rootv aenv nn pool 'movsd sseops)  bodyc (cap AL)  rg (caup AL)
       magr (peep rg (cap rootv) 0)  breg (fr (hlook bound ht))
       wb (foldl (\ a j (a + `(`('movsd (fr (8 + M + j)) (fr (peep rg (nthl rootv (1 + j)) 0)))))) () (rangeL 0 N))   ; fvar <- its update's reg
       deopt '((ld r0 r5 8) (mov r5 r0) (ld r0 r5 0) (jmpr r0))               ; tail-apply the interp fallback (overflow)
       iter (`('(label itop) `('cmp 'r7 lim) '(br ge iesc))                   ; while k<lim AND (cmp mag bound)
             + bodyc + `(`('ucomisd (fr magr) breg) `('br (ucmpx cmpop) 'iesc))
             + wb + '((inc r7) (jmp itop) (label iesc)))
       popsv (foldl (\ a r (a + `(`('pop (gr r))))) () (rev saved))           ; D>=3: restore callee-saved counters before deopt
       accb (`('(adds r8 r8 r7) '(br vc cont)) + popsv + deopt + '((label cont)))   ; ESC: acc += k ; overflow -> deopt
       cell (derives + zerof + '((li r7 0)) + iter + accb)                    ; derive invariants; zero fvars; k=0; recur; acc += k
       (loop-nest ci body) (: cr (gr (nthl cregs ci))  b (nthl dims ci)       ; counted loops outer->inner (single-step)
          tp (intern ("lt" + (show ci)))  en (intern ("le" + (show ci)))
          inner (? (= ci (- D 1)) body (loop-nest (+ ci 1) body))
          (`(`('li cr 0) `('label tp) `('cmp cr b) `('br 'ge en)) + inner + `(`('inc cr) `('jmp tp) `('label en))))
       pushsv (foldl (\ a r (a + `(`('push (gr r))))) () saved)
       popsv2 (foldl (\ a r (a + `(`('pop (gr r))))) () (rev saved))
       preload (foldl (\ a e (a + `(`('li 'r0 (fbits (cap e))) `('movqxr (fr (caup e)) 'r0)))) () ht)   ; load each const
       (asmx (pushsv + preload + '((li r8 0)) + (loop-nest 0 cell) + popsv2 + '((mov r0 r8)))))   ; push saved; consts; acc=0; NEST; pop; rax<-acc
   ; --- 2-WIDE PACKED-SSE2 grid kernel (loopcode-grid2): the SAME D-dim float-recurrence grid, but the
   ;     INNERMOST dim is processed TWO cells at a time -- lanes [c, c+1] packed [low,high] in each xmm.
   ;     The recurrence runs PACKED (addpd/mulpd/subpd via the asm/ SSE2 lane) so both pixels advance per op; the
   ;     two independent chains hide the mul latency the SCALAR kernel (one z, serial dependency) is bound
   ;     by -- ~2.4x on mandelbrot. The escape test -> a per-lane mask (cmplepd) ANDed into a sticky `alive`;
   ;     the per-lane iteration count is a packed-int vector bumped by `psubq count,alive` (alive lane =
   ;     all-ones = -1, so -=(-1) = +1); the loop runs while ANY lane is alive (movmskpd) AND k<lim. BIT-EXACT
   ;     vs the scalar interp (identical IEEE per-lane ops, same count-until-first-escape-capped-at-lim).
   ;     Gated (grid2-ok?) to the mandelbrot/float shape: D<=2, M+N<=4 (invs/fvars at xmm8..11), <=2 inner
   ;     consts (xmm2,3 -> xmm4,5,6 free for count/alive/scratch), cmpop in {< <=}, even innermost dim. The
   ;     acc adds keep the lane-law overflow guard (deopt to the faithful interp nest). ⚠ x86-64 (SSE2).
   (fr n)   (intern ("f" + (show n)))                                                    ; an xmm NUMBER -> its asm/ IR symbol f0..f15
   (gr p)   (intern ("r" + (show (- p 1))))                                              ; a physical GPR encoding (>=8) -> its abstract-file IR name (r10->r9 ..)
   (sseop op) (? (= op '+) 'addpd (= op '*) 'mulpd (= op '-) 'subpd (= op '/) 'divpd 'movupd)   ; DAG op -> PACKED-double mnemonic (grid2)
   (sseops op) (? (= op '+) 'addsd (= op '*) 'mulsd (= op '-) 'subsd (= op '/) 'divsd 'movsd)   ; DAG op -> SCALAR-double mnemonic (gridn)
   (ucmpx op) (? (= op '<=) 'above (= op '<) 'ae (= op '>=) 'be (= op '>) 'below ())     ; EXIT cc after ucomisd = inverse of the continue cmp
   (allocp dag rv env n pool mv opmap)                                                   ; the float-body allocator (CSE + linear-scan); emits asm/ IR FORMS via mv (move) + opmap (op->mnemonic): scalar OR packed
    (: rg (tablet 0) pl (tablet 0) _ (pin pl 'p pool)
       (pop u) (: p (peep pl 'p ()) _ (pin pl 'p (cup p)) (cap p))
       (push r) (pin pl 'p (link r (peep pl 'p ())))
       forms ((: (go i acc) (? (= i n) acc
          (: nd (nthl dag i)
             (? (id? (cap nd) 'L) (: _ (pin rg i (rgof (caup nd) env)) (go (+ i 1) acc))
                (: op (cap nd) a (caup nd) b (caup (cup nd)) ra (peep rg a 0) rb (peep rg b 0)
                   adie (dies? a i dag rv n) bdie (dies? b i dag rv n)
                   dst (? adie ra (pop 0))
                   _ (? (&& bdie (! (= rb dst))) (push rb) 0) _ (pin rg i dst)
                   mvc (? (= dst ra) () `(`(mv (fr dst) (fr ra))))                       ; move only if dst != a's reg
                   (go (+ i 1) (acc + mvc + `(`((opmap op) (fr dst) (fr rb)))))))))) 0 ())
       `(forms rg))
   (cmppd-imm op) (? (= op '<=) 2 (= op '<) 1 ())                                        ; cmppd predicate: LE / LT (the "continue while small" escape tests)
   (grid2-ok? dims invs fvars updates testexpr cmpop bound)                              ; the packed shape fits?
    (&& (member? cmpop '(< <=)) (< (tally dims) 3) (< 1 (last dims)) (= 0 (% (last dims) 2))
        (< (+ (tally invs) (tally fvars)) 5)
        (< (tally (htbl (fcc bound (fccl updates (fcc testexpr ()))) 2)) 3))
   ; the kernel as a neutral asm/ IR PROGRAM (asmx): control flow is LABELS (no hand-counted offsets),
   ; the SSE ops are NAMED (no raw opcode bytes). GP IR regs: r0=rax(scratch), r5=rsi(Ip, the deopt
   ; tail), r7=k(iter), r8=acc, r9../r10..=the grid counters. XMM: f2,f3=consts, f4=count, f5=alive,
   ; f6=scratch, f8,f9=invariants, f10,f11=fvars, f0,f1,f12..15=the DAG pool. The cold per-cell DERIVES
   ; (cgFd) stay raw bytes spliced via `(raw ..)`.
   (loopcode-grid2 dims cnames invs invd fvars updates testexpr cmpop bound lim)
    (: D (tally dims)  M (tally invs)  N (tally fvars)
       cregs (rangeL 10 (+ 10 D))  rinner (last cregs)  iir (gr rinner)                  ; iir = inner counter's IR reg (bumped for lane1)
       fenv (invs + fvars)
       cenv (map2 (\ nm r `(nm (cvtcnt r))) cnames cregs)                                ; counter name -> cvtsi2sd bytes (cgFd reads these)
       ht (htbl (fcc bound (fccl updates (fcc testexpr ()))) 2)                          ; ONLY inner-recurrence consts (bound+..) -> f2,f3; derive consts inline -> f4,5,6 free
       breg (fr (hlook bound ht))  pred (cmppd-imm cmpop)
       idx (map2 (\ i d (link i d)) (rangeL 0 M) invd)                                   ; (inv-index . derive-expr) pairs
       d0 (foldl (\ a p (a + `(`('raw (cgFd ht cenv (cup p))) `('movsd (fr (8 + (cap p))) 'f0)))) () idx)       ; inv i lane0 -> low of f(8+i)
       d1 (foldl (\ a p (a + `(`('raw (cgFd ht cenv (cup p))) `('unpcklpd (fr (8 + (cap p))) 'f0)))) () idx)    ; inv i lane1 (counter+1) -> high
       derives (d0 + `(`('inc iir)) + d1 + `(`('dec iir)))                               ; lane1 = the same derive at counter+1
       zerof (foldl (\ a j (a + `(`('xorpd (fr (8 + M + j)) (fr (8 + M + j)))))) () (rangeL 0 N))   ; fvars := 0 (both lanes)
       aenv ((efold fenv 8) + ht)
       pool (`(0 1) + (rangeL (+ 8 (+ M N)) 16))
       AR (vnall (link testexpr updates) () ())  rootv (cap AR)  dag (caup AR)  nn (tally dag)
       AL (allocp dag rootv aenv nn pool 'movupd sseop)  bodyc (cap AL)  rg (caup AL)
       magr (peep rg (cap rootv) 0)
       wb (foldl (\ a j (a + `(`('movupd (fr (8 + M + j)) (fr (peep rg (nthl rootv (1 + j)) 0)))))) () (rangeL 0 N))   ; fvar <- its update's reg
       maskc `(`('movupd 'f6 (fr magr)) `('cmppd 'f6 breg pred) '(andpd f5 f6) '(psubq f4 f5) '(movmskpd r0 f5))
       iter (`('(label itop) `('cmp 'r7 lim) '(br ge iesc)) + bodyc + maskc             ; while k<lim AND any lane alive
             + '((test r0 r0) (br eq iesc)) + wb + '((inc r7) (jmp itop) (label iesc)))
       deopt '((ld r0 r5 8) (mov r5 r0) (ld r0 r5 0) (jmpr r0))                          ; tail-apply the interp fallback (overflow)
       accb ('((movqrx r0 f4) (adds r8 r8 r0) (br vc cont0)) + deopt                     ; acc += count.lane0 ; guard
             + '((label cont0) (movhlps f6 f4) (movqrx r0 f6) (adds r8 r8 r0) (br vc cont1)) + deopt + '((label cont1)))   ; acc += count.lane1 ; guard
       cell (derives + zerof + '((xorpd f4 f4) (pcmpeqd f5 f5) (li r7 0)) + iter + accb)   ; count=0; alive=ones; k=0; loop; acc
       (loop-nest ci body) (: p (nthl cregs ci) cr (gr p) b (nthl dims ci)               ; counted loops outer->inner; innermost STEPS BY 2
          tp (intern ("lt" + (show ci))) en (intern ("le" + (show ci)))
          inner (? (= ci (- D 1)) body (loop-nest (+ ci 1) body))
          step  (? (= ci (- D 1)) `(`('add cr cr 2)) `(`('inc cr)))
          (`(`('li cr 0) `('label tp) `('cmp cr b) `('br 'ge en)) + inner + step + `(`('jmp tp) `('label en))))
       preload (foldl (\ a e (a + `(`('li 'r0 (fbits (cap e))) `('movqxr (fr (caup e)) 'r0) `('unpcklpd (fr (caup e)) (fr (caup e)))))) () ht)   ; broadcast each const [c,c]
       prog (preload + '((li r8 0)) + (loop-nest 0 cell) + '((mov r0 r8)))                ; acc=0 ; NEST ; rax<-acc
       (asmx prog))
   ; (jitfgridn lam cnames dims invs invd fvars updates testexpr cmpop bound lim) -> native D-dim grid.
   ; Tries the 2-wide PACKED kernel when the shape fits (grid2-ok?), else the scalar grid kernel.
   (jitfgridn lam cnames dims invs invd fvars updates testexpr cmpop bound lim)
    (: pk (? (grid2-ok? dims invs fvars updates testexpr cmpop bound)
             (loopcode-grid2 dims cnames invs invd fvars updates testexpr cmpop bound lim) ())
       (nif (emit (+ (? (atom? pk) (loopcode-gridn dims cnames invs invd fvars updates testexpr cmpop bound lim) pk) epilogue)) (ev lam) lam 1))
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
   ; --- the NEUTRAL-IR retarget (leaf + n-ary lanes) ---------------------------------------------
   ; the byte-emitting lanes above are x86-64-only (raw byte lists). this lane emits the asm/ neutral
   ; IR instead and assembles for a TARGET ('x64 or 'arm64), so aarch64 falls out of asm/arm64.l. it is
   ; ADDITIVE -- the live byte path is untouched; auto.l still drives `jit`/`njit`. spec in doc/glaze-arm64.md.
   ; greg: a logical role -> the abstract asm register, PER TARGET. x86 lands g/Ip/Hp/Sp in rdi/rsi/rdx/rcx
   ; (= abstract r6/r5/r2/r1, SysV's first 4 args -- the convention IS the calling convention); aarch64's
   ; AAPCS lands them in x0/x1/x2/x3 (= r0/r1/r2/r3), so the accumulator moves off r0. (anchor = the machine
   ; stack pointer snapshot for the deopt unwind; scratch = mulo/rem's extra reg, unused on x86.)
   (greg tgt role)
    (: x (id? tgt 'x64)
       (? (id? role 'g)       (? x 'r6 'r0)   (id? role 'ip)      (? x 'r5 'r1)
          (id? role 'hp)      (? x 'r2 'r2)   (id? role 'sp)      (? x 'r1 'r3)
          (id? role 'acc)     (? x 'r0 'r4)   (id? role 'tmp)     (? x 'r7 'r5)
          (id? role 'anchor)  (? x 'r8 'r9)   (id? role 'scratch) (? x 'r4 'r10) ()))
   (ccof op) (? (id? op '<) 'lt (id? op '<=) 'le (id? op '>) 'gt (id? op '>=) 'ge (id? op '=) 'eq ())
   (bitop op) (? (id? op '&) 'and (id? op '|) 'or (id? op '^) 'xor ())   ; source bitwise symbol -> the asm/ IR ALU op

   ; fxir: fetch param i from Sp[i], fixnum-guard (low bit), untag -> acc. a non-fixnum jumps to deopt.
   (fxir tgt i) (: A (greg tgt 'acc) S (greg tgt 'sp) (L (L 'ld A S (* 8 i)) (L 'test A 1) '(br eq deopt) (L 'sar A 1)))
   ; arithir: acc = (the popped a) OP acc, overflow -> deopt. - keeps a-b order; * uses the fused mulo.
   (arithir tgt op) (: A (greg tgt 'acc) T (greg tgt 'tmp) SC (greg tgt 'scratch)
      (? (id? op '+) (L (L 'adds A A T) '(br vs deopt))
         (id? op '-) (L (L 'subs T T A) '(br vs deopt) (L 'mov A T))
         (id? op '*) (L (L 'mulo A A T SC 'deopt)) ()))
   (divir tgt op) (: A (greg tgt 'acc) T (greg tgt 'tmp) SC (greg tgt 'scratch)   ; caller emits the /-by-0 guard
      (? (id? op '//) (L (L 'div A T A)) (id? op '%) (L (L 'rem A T A SC)) ()))
   ; cgir: an arith expr e over params ps -> IR ops, accumulating in acc; a param fetches from Sp[i] (by
   ; its index in ps). nested operands ride the machine stack (push acc / pop tmp); ? gets fresh mint
   ; labels; one shared deopt label. serves BOTH the leaf (ps = one param) and the n-ary lane.
   (cgir tgt ps e)
    (: A (greg tgt 'acc) T (greg tgt 'tmp)
      (? (member? e ps) (fxir tgt (argix e ps 0))
         (whole? e) (L (L 'li A e))
         (two? e) (: op (cap e) a (caup e) b (caup (cup e))
            (? (member? op '(+ - *))
                 (cat (cgir tgt ps a) (cat (L (L 'push A)) (cat (cgir tgt ps b) (cat (L (L 'pop T)) (arithir tgt op)))))
               (member? op '(// %))
                 (cat (cgir tgt ps a) (cat (L (L 'push A)) (cat (cgir tgt ps b)
                      (cat (L (L 'test A A) '(br eq deopt) (L 'pop T)) (divir tgt op)))))
               (member? op '(& | ^))
                 (cat (cgir tgt ps a) (cat (L (L 'push A)) (cat (cgir tgt ps b) (L (L 'pop T) (L (bitop op) A A T)))))
               (member? op '(< <= > >= =))
                 (cat (cgir tgt ps a) (cat (L (L 'push A)) (cat (cgir tgt ps b) (L (L 'pop T) (L 'cmp T A) (L 'set (ccof op) A)))))
               (id? op '?)
                 (: el (mint 0) en (mint 0)
                    (cat (cgir tgt ps a) (cat (L (L 'cmp A 0) (L 'br 'le el))
                         (cat (cgir tgt ps b) (cat (L (L 'jmp en) (L 'label el))
                              (cat (cgir tgt ps (caup (cup (cup e)))) (L (L 'label en))))))))
               ()))
         ()))
   ; deoptir: the shared deopt block -- restore the machine sp from the anchor, then tail-apply the interp
   ; fallback. arity 1 jumps to value[1] (the closure, re-applied to the arg); arity>=2 jumps to value[1]+16
   ; (its BODY, where the saturated args already sit on Sp) -- the lone per-arity difference (mov vs lea).
   (deoptir tgt bodyp) (: AN (greg tgt 'anchor) IP (greg tgt 'ip) T (greg tgt 'tmp)
      (L (L 'label 'deopt) (L 'lea 'sp AN 0) (L 'ld T IP 8) (? bodyp (L 'lea IP T 16) (L 'mov IP T)) (L 'ld T IP 0) (L 'jmpr T)))
   ; coreir: the whole-function IR -- prologue (anchor = the machine sp) ; the body ; putfix epilogue +
   ; Continue (Ip+=16; jmp [Ip]) ; the deopt block. (jitcore assembles + installs it; tests assemble it.)
   (coreir tgt ps body deoptblk)
    (: AN (greg tgt 'anchor) S (greg tgt 'sp) A (greg tgt 'acc) IP (greg tgt 'ip) T (greg tgt 'tmp)
       (cat (L (L 'lea AN 'sp 0))
         (cat (cgir tgt ps body)
           (cat (L (L 'adds A A A) '(br vs deopt) (L 'or A A 1) (L 'st S 0 A) (L 'add IP IP 16) (L 'ld T IP 0) (L 'jmpr T)) deoptblk))))
   ; jitcore: assemble coreir for tgt and install as a nat of the given arity (deopt -> interp).
   (jitcore tgt ps body deoptblk arity lam)
    (nif (emit (peep (assemble tgt (coreir tgt ps body deoptblk)) 'bytes 0)) (ev lam) lam arity)
   ; (jitir '(\ x E) tgt) -- an arity-1 leaf. (jitnir '(\ p0 .. E) tgt) -- arity>=2 (natn curries to saturation).
   (jitir lam tgt)  (jitcore tgt (L (caup lam)) (caup (cup lam)) (deoptir tgt 0) 1 lam)
   (jitnir lam tgt) (: ps (init (cup lam)) body (last (cup lam)) (jitcore tgt ps body (deoptir tgt 1) (tally ps) lam))

   ; --- the LOOP-BODY neutral IR (cgvir): the same arith grammar as cgir, but for the loop lanes, whose
   ; state (n/counter/acc) fills r9/r10/r11 leaving NO free reg for an anchor. So the overflow/div-by-0
   ; guard deopts INLINE -- unwind the d pending machine-stack pushes, then tail-apply interp (value[1] to
   ; the arg still in Sp[0]) -- instead of cgir's anchor-restore. A var is loaded by `varld` (the counter
   ; from its raw register; an n-loop param via fxir). Replaces the byte cgv/cgl + opseq/cmpseq/... lane.
   (ldeopt tgt d) (: A (greg tgt 'acc) IP (greg tgt 'ip) ok (mint 0)   ; jno over deopt; on overflow: unwind d, tail to interp
      (cat (L (L 'br 'vc ok)) (cat (? (> d 0) (L (L 'add 'sp 'sp (* 8 d))) ())
           (L (L 'ld A IP 8) (L 'mov IP A) (L 'ld A IP 0) (L 'jmpr A) (L 'label ok)))))
   (zdeopt tgt d) (: A (greg tgt 'acc) IP (greg tgt 'ip) ok (mint 0)   ; jnz over deopt (the /-by-0 AND fixnum-input guard)
      (cat (L (L 'br 'ne ok)) (cat (? (> d 0) (L (L 'add 'sp 'sp (* 8 d))) ())
           (L (L 'ld A IP 8) (L 'mov IP A) (L 'ld A IP 0) (L 'jmpr A) (L 'label ok)))))
   (fxvir tgt i d) (: A (greg tgt 'acc) S (greg tgt 'sp)   ; load Sp[i] TAGGED, fixnum-guard (inline deopt at depth d), untag
      (cat (L (L 'ld A S (* 8 i)) (L 'test A 1)) (cat (zdeopt tgt d) (L (L 'sar A 1)))))
   (arithl tgt op d) (: A (greg tgt 'acc) T (greg tgt 'tmp)   ; acc = (popped a) OP acc, overflow -> inline deopt
      (? (id? op '+) (cat (L (L 'adds A A T)) (ldeopt tgt d))
         (id? op '*) (cat (L (L 'imul A A T)) (ldeopt tgt d))
         (id? op '-) (cat (L (L 'subs T T A)) (cat (ldeopt tgt d) (L (L 'mov A T)))) ()))
   (divl tgt op d) (: A (greg tgt 'acc) T (greg tgt 'tmp) SC (greg tgt 'scratch)   ; a in tmp (popped), b in acc -> acc; b==0 deopts
      (cat (L (L 'pop T) (L 'test A A)) (cat (zdeopt tgt d) (? (id? op '//) (L (L 'div A T A)) (id? op '%) (L (L 'rem A T A SC)) ()))))
   (cgvir tgt varld e d) (: A (greg tgt 'acc) T (greg tgt 'tmp)
      (: vl (varld e d)
       (? vl vl                                              ; a var -> its loader IR (acc <- the var, at depth d)
          (whole? e) (L (L 'li A e))
          (two? e) (: op (cap e) a (caup e) b (caup (cup e))
             (? (member? op '(+ - *))
                  (cat (cgvir tgt varld a d) (cat (L (L 'push A)) (cat (cgvir tgt varld b (+ d 1)) (cat (L (L 'pop T)) (arithl tgt op d)))))
                (member? op '(// %))
                  (cat (cgvir tgt varld a d) (cat (L (L 'push A)) (cat (cgvir tgt varld b (+ d 1)) (divl tgt op d))))
                (member? op '(& | ^))
                  (cat (cgvir tgt varld a d) (cat (L (L 'push A)) (cat (cgvir tgt varld b (+ d 1)) (L (L 'pop T) (L (bitop op) A A T)))))
                (member? op '(< <= > >= =))
                  (cat (cgvir tgt varld a d) (cat (L (L 'push A)) (cat (cgvir tgt varld b (+ d 1)) (L (L 'pop T) (L 'cmp T A) (L 'set (ccof op) A)))))
                (id? op '?)
                  (: el (mint 0) en (mint 0)
                     (cat (cgvir tgt varld a d) (cat (L (L 'cmp A 0) (L 'br 'le el))
                          (cat (cgvir tgt varld b d) (cat (L (L 'jmp en) (L 'label el))
                               (cat (cgvir tgt varld (caup (cup (cup e))) d) (L (L 'label en))))))))
                ()))
          ())))
   ; --- the NEUTRAL-IR group lane (jitgroupir) -- a GROUP of mutually-recursive first-order integer fns
   ;     to native, both targets. `call H_g` is `(call <name>)`, each H opens `(label <name>)`, and asm/
   ;     resolves the rel offsets. IR chunks concatenate FLAT via `asm` (foldl-(+); on lists of IR forms,
   ;     + appends). Covers the full op grammar: int arith, TCO, value-mode cons, string/map/cask lanes.
   ; arg-register ABI: args in the CALLEE-SAVED bank (x86 rbx/r13/r14/r15 = r3/r12/r13/r14; arm64 x19..x22),
   ; the OVF anchor in another callee-saved reg (govf). a call passes args on the MACHINE STACK; each H
   ; saves/loads/restores its own arg regs (so a caller's args survive nested calls) + on arm64 saves `lr`
   ; (bl clobbers it; x86 CALL/RET keeps the return address on the stack). slotsz = the push/pop unit (x86 8,
   ; arm64 16). mov-to/from-sp is `lea` (the ORR-based mov reads/writes XZR for reg 31, never sp).
   (slotsz tgt) (? (id? tgt 'x64) 8 16)
   (govf tgt)   (? (id? tgt 'x64) 'r11 'r23)                                    ; the OVF anchor reg: x86 r12 / arm64 x23
   (argregir tgt i) (nthl (? (id? tgt 'x64) '(r3 r12 r13 r14) '(r19 r20 r21 r22)) i)
   (hsave tgt)  (? (id? tgt 'x64) () (L '(push lr)))                            ; arm64 H spills lr; x86 uses CALL/RET's stack
   (hrest tgt)  (? (id? tgt 'x64) () (L '(pop lr)))
   (saveargsir tgt k) (foldl (\ a i (asm (L a (L (L 'push (argregir tgt i)))))) () (rangeL 0 k))
   (restargsir tgt k) (foldl (\ a i (asm (L a (L (L 'pop (argregir tgt (- (- k 1) i))))))) () (rangeL 0 k))
   (loadargsir tgt k) (foldl (\ a i (asm (L a (L (L 'ld (argregir tgt i) 'sp (* (slotsz tgt) (- (* 2 k) i))))))) () (rangeL 0 k))   ; argreg_i <- the passed arg at [sp + slotsz*(2k-i)]
   (garith tgt op) (: A (greg tgt 'acc) T (greg tgt 'tmp) SC (greg tgt 'scratch)   ; acc = (popped a) OP acc, overflow -> OVF
      (? (id? op '+) (L (L 'adds A A T) '(br vs OVF))
         (id? op '-) (L (L 'subs T T A) '(br vs OVF) (L 'mov A T))
         (id? op '*) (L (L 'mulo A A T SC 'OVF)) ()))
   (deoptmn tgt bodyp) (: IP (greg tgt 'ip) T (greg tgt 'tmp)                    ; tail-apply interp (value[1]); bodyp -> its BODY (+16, arity>=2)
      (L (L 'ld T IP 8) (? bodyp (L 'lea IP T 16) (L 'mov IP T)) (L 'ld T IP 0) (L 'jmpr T)))
   ; cggir: a group expr e over params ps (in arg regs). syms = the group fn names (call targets). a call
   ; pushes its args, `call H_g`, pops them; arith/div overflow & /-by-0 jump to the shared OVF handler.
   (cggir tgt syms ps e)
    (: A (greg tgt 'acc) T (greg tgt 'tmp)
      (? (member? e ps) (L (L 'mov A (argregir tgt (argix e ps 0))))
         (whole? e) (L (L 'li A e))
         (two? e) (: op (cap e) a (caup e) b (caup (cup e))
            (? (member? op syms)
                 (asm (L (gargsir tgt syms ps (cup e)) (L (L 'call op)) (L (L 'add 'sp 'sp (* (slotsz tgt) (tally (cup e)))))))
               (member? op '(+ - *))
                 (asm (L (cggir tgt syms ps a) (L (L 'push A)) (cggir tgt syms ps b) (L (L 'pop T)) (garith tgt op)))
               (member? op '(// %))
                 (asm (L (cggir tgt syms ps a) (L (L 'push A)) (cggir tgt syms ps b) (L (L 'test A A) '(br eq OVF) (L 'pop T)) (divir tgt op)))
               (member? op '(& | ^))
                 (asm (L (cggir tgt syms ps a) (L (L 'push A)) (cggir tgt syms ps b) (L (L 'pop T) (L (bitop op) A A T))))
               (member? op '(< <= > >= =))
                 (asm (L (cggir tgt syms ps a) (L (L 'push A)) (cggir tgt syms ps b) (L (L 'pop T) (L 'cmp T A) (L 'set (ccof op) A))))
               (id? op '?)
                 (: el (mint 0) en (mint 0)
                    (asm (L (cggir tgt syms ps a) (L (L 'cmp A 0) (L 'br 'le el)) (cggir tgt syms ps b)
                            (L (L 'jmp en) (L 'label el)) (cggir tgt syms ps (caup (cup (cup e)))) (L (L 'label en)))))
               (id? op 'tally) (: R (argregir tgt (argix a ps 0)) `(`('ld A R 8)))                        ; (tally STR): acc = the len at [STR+8] (raw)
               (id? op 'peep) (: R (argregir tgt (argix a ps 0)) d (caup (cup (cup e))) inl (mint 0) endl (mint 0)   ; (peep STR i d): i unsigned-vs-len, OOB -> d, else byte [STR+i+16]
                  (asm `((cggir tgt syms ps b)
                         `(`('ld T R 8) `('cmp A T) `('br 'below inl) `('li A (? (whole? d) d 0)) `('jmp endl) `('label inl) `('ldxb A R A 1 16) `('label endl)))))
               (id? op 'pin) (: R (argregir tgt (argix a ps 0)) val (caup (cup (cup e)))     ; (pin C i V): store V's low byte at C's backing[i] (r8=[C+8]=backing str), return C
                  (asm `((cggir tgt syms ps b) `(`('push A)) (cggir tgt syms ps val)         ; i -> acc, push; V -> acc
                         `(`('pop T) `('ld 'r8 R 8) `('stxb 'r8 T 1 16 A) `('mov A R)))))      ; pop T(=i); r8=backing; [backing+i+16]=V.lo; acc=C
               (id? op 'mpeep) (: R (argregir tgt (argix a ps 0)) d (caup (cup (cup e))) lp (mint 0) ht (mint 0) ms (mint 0) en (mint 0)   ; (mpeep MAP k d): open-addressed probe -> the value (raw) in acc, gap-miss -> d
                  (asm `((cggir tgt syms ps b) `(`('leax 'r10 A A 1 1) `('mov A R)) (relabel (mpeep-ir (? (whole? d) d 0)) lp ht ms en 'deopt))))   ; k -> acc; r10 = tagged key (2k+1); acc = MAP; the probe (labels gensym'd)
               (id? op 'mpin) (: R (argregir tgt (argix a ps 0)) val (caup (cup (cup e))) lp (mint 0) ht (mint 0) ms (mint 0) en (mint 0)   ; (mpin MAP k v): probe + UPDATE-in-place; a grow-due MISS -> OVF (full unwind+deopt); returns MAP
                  (asm `((cggir tgt syms ps val) `(`('push A)) (cggir tgt syms ps b) `(`('leax 'r10 A A 1 1) `('mov A R)) (relabel mpin-ir lp ht ms en 'OVF) `(`('mov A R)))))   ; v -> acc, push (spill); k -> acc; r10=tag(k); acc=MAP; probe+store (the `(pop r8)` tail pops v); acc=MAP (threaded)
               (id? op 'two?) (: z (mint 0) en (mint 0)                                       ; (two? E): is E a chain? -> 1/0, TOTAL (no deopt -- a non-chain reads 0)
                  (asm `((cggir tgt syms ps a) `(`('test A 1) `('br 'ne z) `('ld T A 0) `('li 'r8 chainkind) `('cmp T 'r8) `('br 'ne z) `('li A 1) `('jmp en) `('label z) `('li A 0) `('label en)))))
               (id? op 'cap) (asm `((cggir tgt syms ps a) `(`('test A 1) `('br 'ne 'OVF) `('ld T A 0) `('li 'r8 chainkind) `('cmp T 'r8) `('br 'ne 'OVF) `('ld A A 8))))    ; (cap E): chain-guard -> OVF (non-chain deopts; always under two?), then acc=[E+8]
               (id? op 'cup) (asm `((cggir tgt syms ps a) `(`('test A 1) `('br 'ne 'OVF) `('ld T A 0) `('li 'r8 chainkind) `('cmp T 'r8) `('br 'ne 'OVF) `('ld A A 16))))   ; (cup E): chain-guard, then acc=[E+16]
               ()))
         ()))
   (gargsir tgt syms ps as) (? (atom? as) () (asm (L (cggir tgt syms ps (cap as)) (L (L 'push (greg tgt 'acc))) (gargsir tgt syms ps (cup as)))))
   ; relabel: gensym the map probe's FIXED labels (loop/hit/miss/end) per call site, and point deopt at the
   ; given group label -- so the same mprobe-ir/mpeep-ir/mpin-ir IR can be spliced N times in ONE group
   ; assemble without label collisions.
   (relabel ir lp ht ms en dp) (map (\ f (map (\ x (? (id? x 'loop) lp (id? x 'hit) ht (id? x 'miss) ms (id? x 'end) en (id? x 'deopt) dp x)) f)) ir)
   ; consir: build a chain cell (cons) on the heap -> acc. ROOM-GUARD first (Sp - Hp >= 3w + floor, else
   ;   br OVF -> deopt, so no GC fires mid-native), then [Hp]=chainkind, [Hp+8]=cap(=tmp), [Hp+16]=cup(=acc),
   ;   acc=Hp (an even ptr IS the value, no putfix), Hp+=3w. r9/r10 are
   ;   free scratch in the group ABI (args r3/r12-r14, anchor r11, acc r0, tmp r7, sp r1, hp r2, ip r5).
   (consir tgt) (: A (greg tgt 'acc) T (greg tgt 'tmp) S (greg tgt 'sp) HP (greg tgt 'hp)
      `(`('lea 'r9 HP 88) `('cmp S 'r9) '(br below OVF)                             ; room for 3w+floor; Sp < Hp+88 -> heap full -> deopt
        `('li 'r10 chainkind) `('st HP 0 'r10)                                      ; [Hp] = chain header
        `('st HP 8 T) `('st HP 16 A)                                               ; [Hp+8] = cap (the popped a); [Hp+16] = cup (b)
        `('mov A HP) `('add HP HP 24)))                                            ; acc = Hp (result ptr); bump Hp by 3 words
   ; cggvir -- VALUE-mode codegen: e yields an AI VALUE (heap ptr or tagged scalar) in acc, NOT a raw int.
   ;   int-const C -> tagged value | param -> re-tag the raw arg reg (2p+1) | (link A B) cons (A,B values) |
   ;   (? T A B) int test via cggir, value branches | (g E..) a value-group CALL (args INT via cggir).
   (cggvir tgt syms ps e)
    (: A (greg tgt 'acc) T (greg tgt 'tmp)
      (? (whole? e) `(`('li A (+ (* 2 e) 1)))                                        ; the tagged VALUE C
         (member? e ps) (: R (argregir tgt (argix e ps 0)) `(`('leax A R R 1 1)))    ; param: acc = 2*reg + 1 (re-tag)
         (two? e) (: op (cap e)
            (? (member? op syms) (cggir tgt syms ps e)                              ; a value-group call -> cggir's call (result is the value)
               (id? op 'link) (asm `((cggvir tgt syms ps (caup e)) `(`('push A)) (cggvir tgt syms ps (caup (cup e))) `(`('pop T)) (consir tgt)))   ; A;push;B;pop T(=A); cons(T,A)
               (id? op '?) (: el (mint 0) en (mint 0)
                  (asm `((cggir tgt syms ps (caup e)) `(`('cmp A 0) `('br 'le el)) (cggvir tgt syms ps (caup (cup e)))
                         `(`('jmp en) `('label el)) (cggvir tgt syms ps (caup (cup (cup e)))) `(`('label en)))))
               ()))
         ()))
   ; cggtir: e in TAIL position. a tail SELF-call (selfnm, matching arity) -> compute the new args (from the
   ;   OLD arg regs) onto the machine stack, pop them into the arg regs, then jmp Lbody (the body-start, past
   ;   save/load) -- the frame is REUSED, so a counted loop is O(1) stack, no call/ret per iteration. a tail ?
   ;   recurses tail into both branches (the test stays non-tail). everything else -> cggir (value in acc),
   ;   falling through to restore+ret. self-only (a sibling tail-call stays a plain `call`, as the byte path).
   (cggtir tgt syms ps e selfnm Lbody)
    (: A (greg tgt 'acc) k (tally ps)
       (? (&& (two? e) (id? (cap e) selfnm) (= (tally (cup e)) k))                    ; TAIL SELF-CALL -> loop in place
            (asm `((gargsir tgt syms ps (cup e))                                      ; push the new args (all from the OLD regs)
                   (foldl (\ a i (asm `(a `(`('pop (argregir tgt (- (- k 1) i))))))) () (rangeL 0 k))   ; pop into the arg regs, reverse
                   `(`('jmp Lbody))))
          (&& (two? e) (id? (cap e) '?))                                              ; TAIL ? -> test non-tail, both branches tail
            (: el (mint 0) en (mint 0)
               (asm `((cggir tgt syms ps (caup e)) `(`('cmp A 0) `('br 'le el)) (cggtir tgt syms ps (caup (cup e)) selfnm Lbody)
                      `(`('jmp en) `('label el)) (cggtir tgt syms ps (caup (cup (cup e))) selfnm Lbody) `(`('label en)))))
          (cggir tgt syms ps e)))                                                     ; any other tail expr -> value in acc
   ; mkhir: one function. label; [push lr]; save arg regs; load the passed args; Lbody:; body; restore; [pop lr]; ret.
   (mkhir tgt syms nm ps body)
    (: k (tally ps) Lbody (mint 0)
       (asm (L (L (L 'label nm)) (hsave tgt) (saveargsir tgt k) (loadargsir tgt k) (L (L 'label Lbody))
               (? (hasl body) (cggvir tgt syms ps body) (cggtir tgt syms ps body nm Lbody))   ; VALUE body (conses) -> cggvir (no TCO); int body -> cggtir (TCO)
               (restargsir tgt k) (hrest tgt) (L '(ret)))))
   ; mkouterir: the entry's OUTER -- save anchor+arg regs; anchor=sp; fixnum-guard+push the args; call
   ; H_entry; pop args; restore; putfix + Continue; OVF (mov sp,anchor -> abandon frames; restore) -> DEOPT.
   (mkouterir tgt k entry arity valt smask mmask bufmask cmask)                    ; valt: VALUE-typed entry (heap ptr / tagged scalar) -> store acc AS-IS, no putfix. the masks
    (: A (greg tgt 'acc) S (greg tgt 'sp) IP (greg tgt 'ip) T (greg tgt 'tmp) OVFR (govf tgt) ss (slotsz tgt)   ; partition the entry's EXTERNAL args: int (sar) / string|map|cask (kind-guard, raw) / chain (raw, no guard)
       strk (apof "") mapk mapkind bufk (apof (cask 1))                            ; the kind sentinels the raw-param guards check against
       (pusharg1 i) (: o (* 8 i)                                                   ; one external arg: load Sp[i] -> acc, guard by type, push
          (? (member? i cmask) `(`('ld A S o) `('push A))                          ; chain: raw, NO guard (two? total; cap/cup deopt a non-chain inline)
             (|| (member? i smask) (|| (member? i mmask) (member? i bufmask)))     ; string/map/cask: a fixnum can't be a heap obj (-> OVF), and [arg]'s kind must match (-> OVF); push RAW
               (: kind (? (member? i mmask) mapk (member? i bufmask) bufk strk)
                  `(`('ld A S o) `('test A 1) '(br ne OVF) `('ld T A 0) `('li 'r8 kind) `('cmp T 'r8) '(br ne OVF) `('push A)))   ; a FIXNUM (odd, br ne) deopts; then the kind word must match (br ne)
             `(`('ld A S o) `('test A 1) '(br eq OVF) `('sar A 1) `('push A))))    ; int: fixnum-guard (non-fixnum -> OVF), untag (sar), push
       pushargs (foldl (\ a i (asm `(a (pusharg1 i)))) () (rangeL 0 k))
       epi (? valt `(`('st S 0 A) `('add IP IP 16) `('ld T IP 0) `('jmpr T))                                  ; VALUE: store acc as-is; Continue (no putfix)
                 `(`('adds A A A) '(br vs DEOPT) `('or A A 1) `('st S 0 A) `('add IP IP 16) `('ld T IP 0) `('jmpr T)))   ; INT: putfix (overflow -> deopt); Continue
       (asm `(`(`('push OVFR)) (saveargsir tgt k) `(`('lea OVFR 'sp 0)) pushargs
              `(`('call entry) `('add 'sp 'sp (* ss k))) (restargsir tgt k) `(`('pop OVFR))
              epi
              `(`('label 'OVF) `('lea 'sp OVFR 0)) (restargsir tgt k) `(`('pop OVFR))
              `(`('label 'DEOPT)) (deoptmn tgt (> arity 1)))))
   ; jgir-ok? -- the op-COVERAGE gate: does jitgroupir implement every op this group uses (jgir-supported)?
   ; autogroup routes here when true, else leaves the group INTERPRETED (the val fallback in auto.l). Reached
   ; ONLY after the recognizer (auto.l groupok?/vok?/cok?/grpfix) has proven the group glazeable -- shapes,
   ; arities, the int/chain/value typing, the interprocedural string inference; so jgir-ok? does NOT re-derive
   ; the grammar, its lone job is op coverage. jgir-supported now spans the full recognizer grammar, so the
   ; gate is vacuously true for any admitted group -- it stays as a soundness backstop.
   jgir-supported '(+ - * // % & | ^ < <= > >= = ? link peep tally pin mpeep mpin two? cap cup)   ; the full op set cggir/cggvir handle
   (jgir-ops-ok? syms e) (? (two? e)                                            ; every op head in e is a group call or a supported op; recurse into every operand
      (: op (cap e) (&& (|| (member? op syms) (member? op jgir-supported)) (all (\ x (jgir-ops-ok? syms x)) (cup e))))
      1)
   (jgir-ok? defs) (: syms (map (\ d (cap (cap d))) defs)
      (all (\ d (jgir-ops-ok? syms (cup d))) defs))
   ; (jitgroupir defs entry tgt) -- defs = ((nameform . body) ..); compile the group, entry as the value.
   (jitgroupir defs entry tgt)
    (: parse (map (\ d (: nf (cap d) (L (cap nf) (cup nf) (cup d)))) defs)            ; (name params body) per fn
       syms (map cap parse)                                                            ; the fn names (call targets)
       efn (gfind (\ f (id? (cap f) entry)) parse)  k (tally (nthl efn 1))  eps (nthl efn 1) eb (nthl efn 2)
       ord (link efn (gfilt (\ f (! (id? (cap f) entry))) parse))                      ; entry first (H_entry sits right after the OUTER)
       valt (hasl eb)                                                                 ; entry value-typed (body conses) -> the value epilogue stores acc as-is
       info (map (\ f (L (cap f) (nthl f 1) (nthl f 2) (tally (nthl f 1)))) parse)     ; (name params body arity) -- for the interprocedural string fixpoint
       smap0 (map (\ f (link (cap f) (gfilt (\ j (suse? (nthl f 2) (nthl (nthl f 1) j))) (rangeL 0 (nthl f 3))))) info)   ; per-fn DIRECT string params (peep/tally/pin)
       smask (gsm entry (smfix info smap0))                                            ; the entry's STRING params, propagated to a fixpoint -> raw pointer, kind-guarded
       mmask (gfilt (\ j (muse? eb (nthl eps j))) (rangeL 0 k))                         ; entry MAP params (mpeep/mpin)
       bufmask (gfilt (\ j (buse? eb (nthl eps j))) (rangeL 0 k))                       ; entry CASK params (pin)
       cmask (gfilt (\ j (cuse? eb (nthl eps j))) (rangeL 0 k))                         ; entry CHAIN params (cap/cup/two?) -> raw, no guard
       outer (mkouterir tgt k entry k valt smask mmask bufmask cmask)
       Hs (foldl (\ a f (asm (L a (mkhir tgt syms (cap f) (nthl f 1) (nthl f 2))))) () ord)
       lrf (\ ds (? (atom? ds) (L entry) (: d (cap ds) (link (cap d) (link (cup d) (lrf (cup ds)))))))
       fb (ev (link ': (link '(mpeep mc mk md) (link '(peep mc mk md) (link '(mpin mc mk mv) (link '(pin mc mk mv) (lrf defs)))))))   ; the WHOLE group interpreted -- the deopt fallback. mpeep/mpin are GLAZE-internal (not real fns), so alias them to the core peep/pin (the body reads the PREVIOUS=global binding by the sequence law -- not recursion); harmless for non-map lanes (peep/pin stay the core accessors)
       elam (link '\ (cat (nthl efn 1) (L (nthl efn 2))))                              ; the entry's source lambda (=/show)
       (nif (emit (peep (assemble tgt (asm (L outer Hs))) 'bytes 0)) fb elam k))
)
