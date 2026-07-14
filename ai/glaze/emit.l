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

; the module span opens here: ai/glaze/export.l diffs (names ()) against this mark and
; sweeps every name emit.l + auto.l leak into the ONE `glaze` book -- measured, never
; listed. (in a dev cat-load of these sources, where export.l never loads, it is inert.)
(: glaze-mark (names ()))

(: (le8 n) (: u (? (< n 0) (+ n 18446744073709551616) n)                            ; two's-complement; & is broken on
              ((: (go i) (? (< i 8) (link (% (// u (i 256)) 256) (go (+ i 1))) ())) 0))   ; a bignum >= 2^63, so use //% (n -> 8 LE bytes)
   (le4 n) ((: (go i) (? (< i 4) (link (& (>> n (* 8 i)) 255) (go (+ i 1))) ())) 0)  ; n -> 4 LE bytes (offsets < 2^31, & ok)
   ; the raw-byte x86 lane is fully RETIRED: every codegen helper now emits neutral crew/holo/ IR (cgir/cgvir for
   ; arith, the float lanes cgf/jitfr, the grid kernels gridn/grid2), assembled per target. The old byte
   ; blobs (deopt/guard/guardz/fetch/untag/fxv/epilogue) are gone -- their IR twins are deoptbody/ldeopt/
   ; zdeopt/fxvir/loopepi, which serve BOTH x86 and arm64.
   (emit l) (: b (cask (tally l)) _ ((: (go i x) (? (two? x) (: _ (pin b i (cap x)) (go (+ i 1) (cup x))) ())) 0 l) b)
   ; (jit '(\ x E)) -- compile an arithmetic single-arg closure to native.
   (jit lam) (jitir lam 'x64)  ; arity-1 leaf -> the neutral-IR lane (cgir)
   ; argix finds a param var's frame index in ps (shared with the IR lane's fxir/cgir).
   (argix e ps i) (? !(two? ps) 0  (= e (cap ps)) i  (argix e (cup ps) (+ i 1)))   ; param -> index
   ; (jitn '(\ p0 .. body)) -- an arity>=2 leaf -> native (natn curries to saturation). Now an ALIAS for
   ; the neutral-IR lane (jitnir): cgir already serves the n-ary case in IR, so the old byte cgn/-mn
   ; family below is retired (deleted) -- one lane, label-resolved, and arm64 falls out for free.
   (jitn lam) (jitnir lam 'x64)
   (jit2 lam) (jitn lam)                                                  ; arity-2 alias (self-test/auto.l)
   (gfind p l) (? (atom? l) () (p (cap l)) (cap l) (gfind p (cup l)))     ; first elt matching p
   chainkind (apof (link 0 0))                                                      ; lvm_chain's ap sentinel, for the inline two?/cap/cup kind test (cf. (apof "") for the string lane)
   mapkind (apof (tablet 0))                                                        ; lvm_map_lookup's sentinel, for the map-param entry guard + the (mpeep ..) probe
   nomkind (apof 'nomk)                                                             ; lvm_nom's sentinel, for the point-param entry guard
   mintkind (apof (nom 0))                                                          ; lvm_sym's (a mint's) sentinel, ditto -- () is a mint too
   mapmix 11400714819323198485                                                      ; the hash multiplier 0x9e3779b97f4a7c15 (= ai.c's map hash mult), for the inline probe
   ; -- the map probe, via the crew/holo/ assembler SERVICE (baked into the post-egg layer; the glaze is its
   ;    client). crew/holo/ resolves the hit/miss/loop labels to rel32 -- no hand-counted je/jmp offsets, the
   ;    fragile bit. reg map: holo r0=rax, r7=x86-r8, r8=x86-r9, r9=x86-r10, r10=x86-r11. The probe wants
   ;    the MAP in rax and the TAGGED key in r11 (holo r10); it ends branched to `hit` (match) / `miss` (gap).
   (asmx ir) (peep (assemble 'x64 ir) 'bytes 0)                                     ; assemble neutral IR -> flat bytes, X86 (the post-egg `assemble` service; emit.l's own `holo` is byte-concat, untouched)
   (asmt tgt ir) (peep (assemble tgt ir) 'bytes 0)                                  ; ... target-aware (the loop/float lanes that run on both arches)
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
   (nuse? e P) (? (two? e) (? (&& (id? (cap e) '=) (= 3 (tally e))
                                  (: x1 (caup e) y1 (caup (cup e))
                                     (|| (&& (id? x1 P) (two? y1) (member? (cap y1) '(cap cup)))
                                         (&& (id? y1 P) (two? x1) (member? (cap x1) '(cap cup))))))
                               1 (foldl (\ a x (|| a (nuse? x P))) 0 (cup e))) 0)   ; P a POINT key -- (= P (cap ..))/(= (cap ..) P): raw word identity, entry-guarded nom|mint (a point equals only itself; a charm could bridge (= 2 2.0) so charms deopt to interp)
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
              body (filter (\ k (suse? body (nthl fp k))) (rangeL 0 (tally fp)))))                        ; seed acc = DIRECT peep/tally params
   (sm-size smap) (foldl (\ a e (+ a (tally (cup e)))) 0 smap)
   ; INTERPROCEDURAL string-param inference as a projection of the shared `monofix` harness (prel): the
   ; step recomputes every fn's smask from the whole (name . smask) map; sm-size (total mask width, ascending)
   ; is the measure. The (name . smask)-map shape is the caller's, not the harness's -- monofix is generic.
   (smfix info smap) (monofix smap (\ st (map (\ f (link (cap f) (fnsm (nthl f 1) (nthl f 2) st))) info)) sm-size)
   ; --- counted fold loop: acc = (FOLD over cv<n of body(cv)), cv the counter, limit
   ; at Sp[0]. FOLD is a (op . init) -- + folds from 0, * from 1 -- and cmp is the loop
   ; test's comparison (the loop runs while (cmp cv n)). Now fully neutral IR, both targets.
   (foldinit op)  (? (= op '*) 1 0)                               ; * folds from 1, + from 0
   ; loopregs: the 3 loop-state registers (n / counter / accumulator). CALLER-SAVED on both targets, so
   ; they survive the body's acc/tmp/scratch (and there is no anchor in the loop lane). arm64 picks x6/x7/x8
   ; to dodge scratch=x10 / anchor=x9; x86 keeps r9/r10/r11 (IR r8/r9/r10).
   (loopregs tgt) (? (id? tgt 'x64) '(r8 r9 r10) '(r6 r7 r8))
   ; loopepi: result already in acc -- putfix (overflow -> inline deopt) + Continue (Ip+=16; jmp [Ip]).
   (loopepi tgt) (: A (greg tgt 'acc) S (greg tgt 'sp) IP (greg tgt 'ip) T (greg tgt 'tmp)
      (`(`('adds A A A)) + (ldeopt tgt 0) + `(`('or A A 1) `('st S 0 A) `('add IP IP 16) `('ld T IP 0) `('jmpr T))))
   ; END condition = the INVERSE of the continue-comparison (exit when (cmp cv n) is false).
   (exitcc cmp) (? (= cmp '<) 'ge (= cmp '<=) 'gt (= cmp '>) 'le
                   (= cmp '>=) 'lt (= cmp '=) 'ne ())  ; ge/gt/le/lt/ne
   (loopcode body cv op cmp tgt)
    (: rs (loopregs tgt) N (nthl rs 0) CV (nthl rs 1) ACC (nthl rs 2) A (greg tgt 'acc) S (greg tgt 'sp)
       bodyir (cgvir tgt (\ e d (? (= e cv) `(`('mov A CV)) ())) body 0)      ; body -> acc; the counter is read from CV
       accir  (? (id? op '+) (`(`('adds ACC ACC A)) + (ldeopt tgt 0))                                  ; ACC += acc ; overflow -> inline deopt
                 (id? op '*) (: dl (mint 0) ok (mint 0)                                                ; ACC *= acc ; mulo (no arm64 flag) branches to the inline deopt
                    (`(`('mulo ACC ACC A (greg tgt 'scratch) dl)) + `(`('jmp ok) `('label dl)) + (deoptbody tgt 0) + `(`('label ok)))) ())
       pre  `(`('ld N S 0) `('sar N 1) `('li CV 0) `('li ACC (foldinit op)))   ; n = Sp[0]>>1 (assumed fixnum) ; cv = 0 ; acc = init
       (asmt tgt (pre + `('(label top) `('cmp CV N) `('br (exitcc cmp) 'end))   ; cmp cv,n ; exit when (cmp cv n) false
              + bodyir + accir + `(`('inc CV) '(jmp top) '(label end) `('mov A ACC)) + (loopepi tgt))))   ; cv++ ; loop ; acc <- ACC ; putfix + Continue
   ; (jitsum body) -- compile (\ n (sum_{i<n} body(i))) to a native counted loop (x86 self-test helper).
   (jitsum body)
    (: src `('\ 'n `(`(': `('go 'i 'a) `('? `('< 'i 'n) `('go `('+ 'i 1) `('+ 'a body)) 'a)) 0 0))
       (nif (emit (loopcode body 'i '+ '< 'x64)) (ev src) src 1))
   ; --- N-VARIABLE loop: the general tail-recursive counted loop ------------------
   ; (\ n ((: (go v0..vk) (? TEST (go U0..Uk) RESULT)) I0..Ik)), up to 3 loop vars in
   ; r9/r10/r11 (RAW), the param n the tagged Sp[0] (fxv-guarded). each iteration: if
   ; TEST, compute EVERY Uj from the OLD regs -- push all, then pop into the regs in
   ; reverse -- so the updates read pre-update values (e.g. fib's `b` and `a+b`); else
   ; RESULT. r9/r10/r11 survive the expr scratch (rax/r8/stack), so no save needed.
   ; lvreg: loop var j -> its abstract register (arch-aware, the loopregs bank: x86 IR r8/r9/r10 = phys
   ; r9/r10/r11 ; arm64 r6/r7/r8 = x6/x7/x8, dodging scratch/anchor).
   (lvreg tgt j) (nthl (loopregs tgt) j)
   (loopcode-n n vars updates test result inits tgt)
    ; the whole N-var loop in neutral IR, both targets. nvld loads a var: n from Sp[0] (fxvir, guarded), a
    ; loop var from its register. updates are computed from the OLD regs (all pushed at depth j, then popped
    ; reverse so reg(j) <- Uj). control flow + per-depth deopt + the putfix epilogue are all label-resolved.
    (: A (greg tgt 'acc)
       nvld (\ e d (? (= e n) (fxvir tgt 0 d)
                       (member? e vars) `(`('mov A (lvreg tgt (argix e vars 0))))
                       ()))
       pre  ((: (go j is) (? (two? is) (`(`('li (lvreg tgt j) (cap is))) + (go (+ j 1) (cup is))) ())) 0 inits)        ; reg-init
       ups  ((: (go j us) (? (two? us) ((cgvir tgt nvld (cap us) j) + `(`('push A)) + (go (+ j 1) (cup us))) ())) 0 updates)   ; push Uj at depth j
       pops ((: (go j) (? (< j 0) () (`(`('pop (lvreg tgt j))) + (go (- j 1))))) (- (tally updates) 1))                ; pop reg(k-1)..reg(0)
       tb   (cgvir tgt nvld test 0)
       rb   (cgvir tgt nvld result 0)
       (asmt tgt (pre + '((label top))
              + tb + `(`('cmp A 0) '(br eq end))           ; <test>; acc==0 (false) -> end
              + ups + pops + '((jmp top) (label end))      ; updates ; loop top
              + rb + (loopepi tgt))))                      ; result -> acc ; putfix + Continue
   ; (jitloop-n lam vars updates test result inits) -- a general N-var loop -> native (x86 self-test helper).
   (jitloop-n lam vars updates test result inits)
    (nif (emit (loopcode-n (caup lam) vars updates test result inits 'x64)) (ev lam) lam 1)
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
   ; the float spill rides the machine stack at the loop/group slot size (x86 8 / arm64 16, for sp
   ; alignment), so a mid-nest deopt (deoptbody, slotsz*d) unwinds it correctly.
   (xpushir tgt) `(`('sub 'sp 'sp (slotsz tgt)) '(stsd sp 0 f0))   ; spill xmm0/d0 -> [sp]
   (xpop1ir tgt) `('(ldsd f1 sp 0) `('add 'sp 'sp (slotsz tgt)))   ; reload [sp] -> xmm1/d1
   (fconst tgt c) (: A (greg tgt 'acc) `(`('li A (fbits c)) `('movqxr 'f0 A)))   ; bits -> gpr ; gpr -> xmm0 (movq / fmov)
   (fbinop op) (? (= op '+) '((addsd f0 f1))                         ; f0 = f0 + f1
                  (= op '*) '((mulsd f0 f1))                         ; f0 = f0 * f1
                  (= op '-) '((subsd f1 f0) (movsd f0 f1))           ; f1 = f1 - f0 ; f0 = f1
                  (= op '/) '((divsd f1 f0) (movsd f0 f1))           ; f1 = f1 / f0 ; f0 = f1
                  ())                                                ; reg-reg double IR (two-address: x86 SSE / arm64 scalar-double), both targets
   ; cgf: a FLOAT subexpr over {x (the fixnum param -> cvtsi2sd) ; numeric consts} -> xmm0/d0, as neutral
   ; crew/holo/ IR (both targets). the param load is fxvir (fixnum-guarded, inline deopt) then int->double.
   (cgf tgt v e d) (? (= e v)   ((fxvir tgt 0 d) + `(`('cvtsi2sd 'f0 (greg tgt 'acc))))   ; param: fixnum-guarded untag in acc, cvtsi2sd
                  (gem? e)  (fconst tgt e)                           ; a float constant
                  (whole? e)(fconst tgt (+ e 0.0))                   ; an int constant -> promote to double
                  (two? e) (: op (cap e) a (caup e) b (caup (cup e))
                     (? (member? op '(+ - * /)) (+ (cgf tgt v a d) (+ (xpushir tgt) (+ (cgf tgt v b (+ d 1)) (+ (xpop1ir tgt) (fbinop op))))) ()))
                  ())
   ; cgfp: a float PREDICATE (cmp A B) -> acc 0/1 (A->xmm1, B->xmm0; ucomisd then set). x86-only (the
   ; ucomisd-flag conditions are x86 unsigned cc); jitf (its sole caller) is an x86 self-test helper.
   (cgfp tgt v e d) (: op (cap e) a (caup e) b (caup (cup e))
      cc (? (= op '<) 'below (= op '<=) 'be (= op '>) 'above (= op '>=) 'ae 'eq)
      (+ (cgf tgt v a d) (+ (xpushir tgt) (+ (cgf tgt v b (+ d 1)) (+ (xpop1ir tgt)
         (+ '((ucomisd f1 f0)) `(`('set cc (greg tgt 'acc)))))))))   ; ucomisd xmm1,xmm0 ; acc = (cc) ? 1 : 0
   ; (jitf '(\ x (cmp <fexpr> <fexpr>))) -- a float predicate over a fixnum arg -> native 0/1 (x86 helper).
   (jitf lam) (: v (caup lam) (nif (emit (asmx ((cgfp 'x64 v (caup (cup lam)) 0) + (loopepi 'x64)))) (ev lam) lam 1))
   ; --- HEAP RESULT (the deferred "Have-checked box"): (jitfr '(\ x <fexpr>)) returns a GEM, not 0/1.
   ; the lane never allocates because it can't GC (its raw regs aren't roots) -- so it does the alloc
   ; twin of the overflow guard: a ROOM GUARD (Sp - Hp >= flo_req+floor words) DEOPTS to interp when
   ; the heap is too full to fit the box, exactly as `jo` deopts when a fixnum result leaves range.
   ; fast path (room proven): write [Hp]=lvm_flo (apof's kind const, ASLR-captured at emit like the
   ; string guard), the double at [Hp+8] with NaN->0 (flo_put's law), return Hp UNTAGGED (an even heap
   ; ptr IS the gem), bump Hp by flo_req. the epilogue stores the POINTER (NO putfix) and threads the
   ; advanced Hp on through Continue, so the box is live to the next op and the GC at the next safepoint.
   ; nanc: NaN -> 0.0 in f0 (flo_put's law). x86: ucomisd xmm0,xmm0 ; jnp +4 ; xorpd (the parity cc +
   ; self-jump as a raw blob). arm64: fcmp d0,d0 ; b.vc ok ; (d0 <- 0) ; ok -- unordered sets V, so vc
   ; skips when not-NaN; zero via a gpr-0 moved into d0.
   (nanc tgt) (? (id? tgt 'x64) `(`('raw '(102 15 46 192  123 4  102 15 87 192)))
                 (: A (greg tgt 'acc) ok (mint 0)
                    (`('(ucomisd f0 f0) `('br 'vc ok)) + `(`('li A 0) `('movqxr 'f0 A)) + `(`('label ok)))))
   (jitfr lam tgt)
    (: v (caup lam)  kind (apof 1.5)                                 ; lvm_flo's address, captured now (code never moves)
       A (greg tgt 'acc) S (greg tgt 'sp) HP (greg tgt 'hp) IP (greg tgt 'ip) T (greg tgt 'tmp) ok (mint 0)
       ; neutral crew/holo/ IR (both targets): the room-guard skips the deopt by LABEL; the box store is `stsd`;
       ; the deopt is deoptbody (no pending spills here -- cgf balances its own); nanc is arch-aware.
       (nif (emit (asmt tgt ((cgf tgt v (caup (cup lam)) 0)
          + `(`('lea A HP 80) `('cmp S A) `('br 'ae ok))                  ; cmp Sp,Hp+10w ; room? skip deopt
          + (deoptbody tgt 0) + `(`('label ok)) + (nanc tgt)             ; heap-full -> deopt ; NaN -> 0.0
          + `(`('li T kind) `('st HP 0 T)                                 ; [Hp] = lvm_flo (box header)
              `('stsd HP 8 'f0)                                           ; [Hp+8] = the double
              `('mov A HP) `('add HP HP 16)                               ; acc = Hp (the gem ptr) ; Hp += 16
              `('st S 0 A) `('add IP IP 16) `('ld T IP 0) `('jmpr T)))))   ; [Sp] = gem ; Continue (NO putfix: acc IS the gem)
        (ev lam) lam 1))
   (clook k ce) (? (atom? ce) () (= k (caap ce)) (cap ce) (clook k (cup ce)))   ; counter env: name -> (name regbytes; cgFd/rgof read it)
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
   (hcon tgt v ht) (: r (hlook v ht) (? (< -1 r) `(`('movsd 'f0 (fr r))) (fconst tgt v)))   ; hoisted const reg -> f0 (movsd) ; else inline fconst -- neutral IR, both targets
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
   (rgof leaf env) (: e (clook leaf env) (? (two? e) (caup e) (scare 'glaze-leaf leaf)))   ; leaf -> its fixed reg
   (holo ps) (foldl (\ a b (+ a b)) () ps)                                                  ; concat a LIST of byte pieces (+ is associative)
   (efold names i) (? (two? names) (link (L (cap names) i) (efold (cup names) (+ i 1))) ())   ; names -> (name reg) from reg i
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
   ; cgFd: a derive expr over the COUNTER env ce (int loop counters -> cvtsi2sd, the IR carried by cenv) +
   ; hoisted consts, using [sp] scratch (xpushir/xpop1ir) so it never touches an xmm8.. local reg -- run
   ; once per cell (cold). Neutral IR, both targets.
   (cgFd tgt ht ce e) (? (gem? e)   (hcon tgt e ht)
                     (whole? e) (hcon tgt (+ e 0.0) ht)
                     (atom? e)  (: cb (clook e ce) (? (two? cb) (caup cb) ()))           ; counter -> its (cvtsi2sd f0 cntr) IR
                     (two? e)   (: op (cap e) a (caup e) b (caup (cup e))
                                   (? (member? op '(+ - * /)) ((cgFd tgt ht ce a) + (xpushir tgt) + (cgFd tgt ht ce b) + (xpop1ir tgt) + (fbinop op)) ()))
                     ())
   (loopcode-gridn dims cnames invs invd fvars updates testexpr cmpop bound lim tgt)
    ; the scalar D-dim grid kernel as a neutral crew/holo/ IR PROGRAM, BOTH targets: control flow is LABELS (no
    ; hand offsets), the recurrence is allocp's CSE'd named-SSE forms, the cold derives (cgFd) are IR too.
    ; k=r7(iter), acc=r8, counters=r9..(gr); SCR=scratch (greg acc), the deopt tail uses greg ip. xmm: consts
    ; f2.., invariants f8.., fvars next, the rest the DAG pool. On x86 D>=3 spills the callee-saved counters
    ; (r12..); on arm64 the counters are caller-saved (x8..), so none. The acc add is GUARDED (lane law).
    (: D (tally dims)  M (tally invs)  N (tally fvars)  SCR (greg tgt 'acc)    ; SCR: integer scratch (fbits load + the result)
       cregs (rangeL 10 (+ 10 D))                                             ; counter regs (phys r10..), outer->inner
       saved (? (id? tgt 'x64) (rangeL 12 (+ 10 D)) ())                       ; x86 r12.. callee-saved (D>=3); arm64 counters caller-saved -> none
       fenv (cat invs fvars)
       cenv (map2 (\ nm r (L nm `(`('cvtsi2sd 'f0 (gr r))))) cnames cregs)    ; counter name -> its (cvtsi2sd f0 cntr) IR (cgFd reads it)
       ht (htbl (fcc bound (fccl invd (fccl updates (fcc testexpr ())))) 2)   ; distinct consts -> xmm2..7
       derives (foldl (\ a p (a + (cgFd tgt ht cenv (cup p)) + `(`('movsd (fr (8 + (cap p))) 'f0)))) () (map2 (\ i d (link i d)) (rangeL 0 M) invd))   ; inv i -> xmm(8+i)
       zerof (foldl (\ a j (a + `(`('xorpd (fr (8 + M + j)) (fr (8 + M + j)))))) () (rangeL 0 N))   ; fvar j -> xmm(8+M+j) = 0
       aenv ((efold fenv 8) + ht)
       pool (`(0 1) + (rangeL (+ 8 (+ M N)) 16))
       AR (vnall (link testexpr updates) () ())  rootv (cap AR)  dag (caup AR)  nn (tally dag)
       AL (allocp dag rootv aenv nn pool 'movsd sseops)  bodyc (cap AL)  rg (caup AL)
       magr (peep rg (cap rootv) 0)  breg (fr (hlook bound ht))
       wb (foldl (\ a j (a + `(`('movsd (fr (8 + M + j)) (fr (peep rg (nthl rootv (1 + j)) 0)))))) () (rangeL 0 N))   ; fvar <- its update's reg
       iter (`('(label itop) `('cmp 'r7 lim) '(br ge iesc))                   ; while k<lim AND (cmp mag bound)
             + bodyc + `(`('ucomisd (fr magr) breg) `('br (ucmpx cmpop) 'iesc))
             + wb + '((inc r7) (jmp itop) (label iesc)))
       popsv (foldl (\ a r (a + `(`('pop (gr r))))) () (rev saved))           ; x86 D>=3: restore callee-saved counters before deopt
       accb (`('(adds r8 r8 r7) '(br vc cont)) + popsv + (deoptbody tgt 0) + '((label cont)))   ; ESC: acc += k ; overflow -> deopt
       cell (derives + zerof + '((li r7 0)) + iter + accb)                    ; derive invariants; zero fvars; k=0; recur; acc += k
       (loop-nest ci body) (: cr (gr (nthl cregs ci))  b (nthl dims ci)       ; counted loops outer->inner (single-step)
          tp (intern ("lt" + (show ci)))  en (intern ("le" + (show ci)))
          inner (? (= ci (- D 1)) body (loop-nest (+ ci 1) body))
          (`(`('li cr 0) `('label tp) `('cmp cr b) `('br 'ge en)) + inner + `(`('inc cr) `('jmp tp) `('label en))))
       pushsv (foldl (\ a r (a + `(`('push (gr r))))) () saved)
       popsv2 (foldl (\ a r (a + `(`('pop (gr r))))) () (rev saved))
       preload (foldl (\ a e (a + `(`('li SCR (fbits (cap e))) `('movqxr (fr (caup e)) SCR)))) () ht)   ; load each const
       (pushsv + preload + '((li r8 0)) + (loop-nest 0 cell) + popsv2 + `(`('mov SCR 'r8))))   ; IR program: push saved; consts; acc=0; NEST; pop; result -> SCR(=acc)
   ; --- 2-WIDE PACKED-SSE2 grid kernel (loopcode-grid2): the SAME D-dim float-recurrence grid, but the
   ;     INNERMOST dim is processed TWO cells at a time -- lanes [c, c+1] packed [low,high] in each xmm.
   ;     The recurrence runs PACKED (addpd/mulpd/subpd via the crew/holo/ SSE2 lane) so both pixels advance per op; the
   ;     two independent chains hide the mul latency the SCALAR kernel (one z, serial dependency) is bound
   ;     by -- ~2.4x on mandelbrot. The escape test -> a per-lane mask (cmplepd) ANDed into a sticky `alive`;
   ;     the per-lane iteration count is a packed-int vector bumped by `psubq count,alive` (alive lane =
   ;     all-ones = -1, so -=(-1) = +1); the loop runs while ANY lane is alive (movmskpd) AND k<lim. BIT-EXACT
   ;     vs the scalar interp (identical IEEE per-lane ops, same count-until-first-escape-capped-at-lim).
   ;     Gated (grid2-ok?) to the mandelbrot/float shape: D<=2, M+N<=4 (invs/fvars at xmm8..11), <=2 inner
   ;     consts (xmm2,3 -> xmm4,5,6 free for count/alive/scratch), cmpop in {< <=}, even innermost dim. The
   ;     acc adds keep the lane-law overflow guard (deopt to the faithful interp nest). ⚠ x86-64 (SSE2).
   (fr n)   (intern ("f" + (show n)))                                                    ; an xmm NUMBER -> its crew/holo/ IR symbol f0..f15
   (gr p)   (intern ("r" + (show (- p 1))))                                              ; a physical GPR encoding (>=8) -> its abstract-file IR name (r10->r9 ..)
   (sseop op) (? (= op '+) 'addpd (= op '*) 'mulpd (= op '-) 'subpd (= op '/) 'divpd 'movupd)   ; DAG op -> PACKED-double mnemonic (grid2)
   (sseops op) (? (= op '+) 'addsd (= op '*) 'mulsd (= op '-) 'subsd (= op '/) 'divsd 'movsd)   ; DAG op -> SCALAR-double mnemonic (gridn)
   (ucmpx op) (? (= op '<=) 'above (= op '<) 'ae (= op '>=) 'be (= op '>) 'below ())     ; EXIT cc after ucomisd = inverse of the continue cmp
   (allocp dag rv env n pool mv opmap)                                                   ; the float-body allocator (CSE + linear-scan); emits crew/holo/ IR FORMS via mv (move) + opmap (op->mnemonic): scalar OR packed
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
   ; the kernel as a neutral crew/holo/ IR PROGRAM (asmx): control flow is LABELS (no hand-counted offsets),
   ; the SSE ops are NAMED (no raw opcode bytes). GP IR regs: r0=rax(scratch), r5=rsi(Ip, the deopt
   ; tail), r7=k(iter), r8=acc, r9../r10..=the grid counters. XMM: f2,f3=consts, f4=count, f5=alive,
   ; f6=scratch, f8,f9=invariants, f10,f11=fvars, f0,f1,f12..15=the DAG pool. The cold per-cell DERIVES
   ; (cgFd) stay raw bytes spliced via `(raw ..)`.
   (loopcode-grid2 dims cnames invs invd fvars updates testexpr cmpop bound lim)
    (: D (tally dims)  M (tally invs)  N (tally fvars)
       cregs (rangeL 10 (+ 10 D))  rinner (last cregs)  iir (gr rinner)                  ; iir = inner counter's IR reg (bumped for lane1)
       fenv (invs + fvars)
       cenv (map2 (\ nm r (L nm `(`('cvtsi2sd 'f0 (gr r))))) cnames cregs)               ; counter name -> its (cvtsi2sd f0 cntr) IR (cgFd reads these)
       ht (htbl (fcc bound (fccl updates (fcc testexpr ()))) 2)                          ; ONLY inner-recurrence consts (bound+..) -> f2,f3; derive consts inline -> f4,5,6 free
       breg (fr (hlook bound ht))  pred (cmppd-imm cmpop)
       idx (map2 (\ i d (link i d)) (rangeL 0 M) invd)                                   ; (inv-index . derive-expr) pairs
       d0 (foldl (\ a p (a + (cgFd 'x64 ht cenv (cup p)) + `(`('movsd (fr (8 + (cap p))) 'f0)))) () idx)       ; inv i lane0 -> low of f(8+i)
       d1 (foldl (\ a p (a + (cgFd 'x64 ht cenv (cup p)) + `(`('unpcklpd (fr (8 + (cap p))) 'f0)))) () idx)    ; inv i lane1 (counter+1) -> high
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
       deopt (deoptbody 'x64 0)                                                          ; tail-apply the interp fallback (overflow)
       accb ('((movqrx r0 f4) (adds r8 r8 r0) (br vc cont0)) + deopt                     ; acc += count.lane0 ; guard
             + '((label cont0) (movhlps f6 f4) (movqrx r0 f6) (adds r8 r8 r0) (br vc cont1)) + deopt + '((label cont1)))   ; acc += count.lane1 ; guard
       cell (derives + zerof + '((xorpd f4 f4) (pcmpeqd f5 f5) (li r7 0)) + iter + accb)   ; count=0; alive=ones; k=0; loop; acc
       (loop-nest ci body) (: p (nthl cregs ci) cr (gr p) b (nthl dims ci)               ; counted loops outer->inner; innermost STEPS BY 2
          tp (intern ("lt" + (show ci))) en (intern ("le" + (show ci)))
          inner (? (= ci (- D 1)) body (loop-nest (+ ci 1) body))
          step  (? (= ci (- D 1)) `(`('add cr cr 2)) `(`('inc cr)))
          (`(`('li cr 0) `('label tp) `('cmp cr b) `('br 'ge en)) + inner + step + `(`('jmp tp) `('label en))))
       preload (foldl (\ a e (a + `(`('li 'r0 (fbits (cap e))) `('movqxr (fr (caup e)) 'r0) `('unpcklpd (fr (caup e)) (fr (caup e)))))) () ht)   ; broadcast each const [c,c]
       (preload + '((li r8 0)) + (loop-nest 0 cell) + '((mov r0 r8))))                    ; IR program (x86): acc=0 ; NEST ; result -> r0(=acc)
   ; (jitfgridn lam cnames dims invs invd fvars updates testexpr cmpop bound lim) -> native D-dim grid.
   ; Tries the 2-wide PACKED kernel when the shape fits (grid2-ok?), else the scalar grid kernel.
   ; the PACKED 2-wide kernel (grid2) is x86-only (NEON has no movmskpd); arm64 uses the scalar gridn.
   ; both kernels return a neutral IR PROGRAM ending with the checksum in acc; jitfgridn appends loopepi
   ; (putfix + Continue) and assembles for `tgt`.
   (jitfgridn lam cnames dims invs invd fvars updates testexpr cmpop bound lim tgt)
    (: pk (? (&& (id? tgt 'x64) (grid2-ok? dims invs fvars updates testexpr cmpop bound))
             (loopcode-grid2 dims cnames invs invd fvars updates testexpr cmpop bound lim) ())
       prog (? (atom? pk) (loopcode-gridn dims cnames invs invd fvars updates testexpr cmpop bound lim tgt) pk)
       (nif (emit (asmt tgt (prog + (loopepi tgt)))) (ev lam) lam 1))
   ; (jitfgrid src pxn pyn cxd cyd fvars updates testexpr cmpop bound lim tgt) -> the 2D mandelbrot-class
   ; delegate (the original signature) onto the general kernel: D=2 (px py), M=2 invariants (cx cy).
   (jitfgrid lam pxn pyn cxd cyd fvars updates testexpr cmpop bound lim tgt)
    (jitfgridn lam '(px py) (L pxn pyn) '(cx cy) (L cxd cyd) fvars updates testexpr cmpop bound lim tgt)
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
   (grok glam mps mbody cbody gbody tgt)                           ; -> a native grid closure, or () if it doesn't match the shape
    (: cond (opd mbody 0)  then (opd mbody 1)
       c2 (opd cond 1)  lim (opd (opd cond 0) 1)  cmpop (cap c2)  testexpr (opd c2 0)  bound (opd c2 1)
       cl (classify mps (cup then))  fvars (cap cl)  updates (caup cl)  invs (nthl cl 2)
       pyn (opd (opd cbody 0) 1)  margs (cup (opd (nthl (cup (opd cbody 1)) 2) 1))
       cxd (nthl margs (posof (nthl invs 0) mps 0))  cyd (nthl margs (posof (nthl invs 1) mps 0))
       pxn (opd (opd gbody 0) 1)
       (? (&& (= 2 (tally invs)) (= 2 (tally fvars)))
          (jitfgrid glam pxn pyn cxd cyd fvars updates testexpr cmpop bound lim tgt) ()))
   ; --- the NEUTRAL-IR retarget (leaf + n-ary lanes) ---------------------------------------------
   ; the byte-emitting lanes above are x86-64-only (raw byte lists). this lane emits the crew/holo/ neutral
   ; IR instead and assembles for a TARGET ('x64 or 'arm64), so aarch64 falls out of crew/holo/arm64.l. it is
   ; ADDITIVE -- the live byte path is untouched; auto.l still drives `jit`/`njit`. spec in doc/glaze-arm64.md.
   ; greg: a logical role -> the abstract holo register, PER TARGET. x86 lands g/Ip/Hp/Sp in rdi/rsi/rdx/rcx
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
   (bitop op) (? (id? op '&) 'and (id? op '|) 'or (id? op '^) 'xor ())   ; source bitwise symbol -> the crew/holo/ IR ALU op

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
   ; deoptbody: unwind d pending machine-stack pushes (slotsz each -- x86 8 / arm64 16), then tail-apply
   ; interp (value[1]) to the arg still in Sp[0]. NO branch/label of its own; ldeopt/zdeopt/the *-overflow
   ; lane wrap it with the guard branch + a skip label. The loop lanes have no free anchor reg (state fills
   ; the loop registers), so the unwind is by COUNT here, not the leaf/group's anchor-restore.
   (deoptbody tgt d) (: A (greg tgt 'acc) IP (greg tgt 'ip)
      ((? (> d 0) `(`('add 'sp 'sp (* (slotsz tgt) d))) ()) + `(`('ld A IP 8) `('mov IP A) `('ld A IP 0) `('jmpr A))))
   (ldeopt tgt d) (: ok (mint 0) (`(`('br 'vc ok)) + (deoptbody tgt d) + `(`('label ok))))   ; skip the deopt unless OVerflow
   (zdeopt tgt d) (: ok (mint 0) (`(`('br 'ne ok)) + (deoptbody tgt d) + `(`('label ok))))   ; skip unless nonzero (the /-by-0 AND fixnum-input guard)
   (fxvir tgt i d) (: A (greg tgt 'acc) S (greg tgt 'sp)   ; load Sp[i] TAGGED, fixnum-guard (inline deopt at depth d), untag
      (`(`('ld A S (* 8 i)) `('test A 1)) + (zdeopt tgt d) + `(`('sar A 1))))
   (arithl tgt op d) (: A (greg tgt 'acc) T (greg tgt 'tmp) SC (greg tgt 'scratch) dl (mint 0) ok (mint 0)   ; acc = (popped a) OP acc, overflow -> inline deopt
      (? (id? op '+) (`(`('adds A A T)) + (ldeopt tgt d))
         (id? op '*) (`(`('mulo A A T SC dl)) + `(`('jmp ok) `('label dl)) + (deoptbody tgt d) + `(`('label ok)))   ; mulo sets no arm64 flag -> it branches to the inline deopt (SC the smulh scratch)
         (id? op '-) (`(`('subs T T A)) + (ldeopt tgt d) + `(`('mov A T))) ()))
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
   ;     to native, both targets. `call H_g` is `(call <name>)`, each H opens `(label <name>)`, and crew/holo/
   ;     resolves the rel offsets. IR chunks concatenate FLAT via `holo` (foldl-(+); on lists of IR forms,
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
   (saveargsir tgt k) (foldl (\ a i (holo (L a (L (L 'push (argregir tgt i)))))) () (rangeL 0 k))
   (restargsir tgt k) (foldl (\ a i (holo (L a (L (L 'pop (argregir tgt (- (- k 1) i))))))) () (rangeL 0 k))
   (loadargsir tgt k) (foldl (\ a i (holo (L a (L (L 'ld (argregir tgt i) 'sp (* (slotsz tgt) (- (* 2 k) i))))))) () (rangeL 0 k))   ; argreg_i <- the passed arg at [sp + slotsz*(2k-i)]
   (garith tgt op) (: A (greg tgt 'acc) T (greg tgt 'tmp) SC (greg tgt 'scratch)   ; acc = (popped a) OP acc, overflow -> OVF
      (? (id? op '+) (L (L 'adds A A T) '(br vs OVF))
         (id? op '-) (L (L 'subs T T A) '(br vs OVF) (L 'mov A T))
         (id? op '*) (L (L 'mulo A A T SC 'OVF)) ()))
   ; --- register/immediate-operand peephole (the cgg lane's, ported into the neutral IR) ---
   ; the generic binary lane is push-acc..pop-tmp per op -- the gap vs a register machine. when one operand
   ; is already a PARAM (in an arg reg) or a small immediate, combine it DIRECTLY: acc OP= reg|imm, no stack
   ; traffic. e.g. primes' (* d d), (< n (* d d)), (+ d 1), (= 0 ..) all run flat. both targets: the crew/holo/ ALU
   ; takes a reg or an imm for adds/subs/cmp (arm64 imm is 12-bit -> pimm?); mulo is register-only on arm64,
   ; so the imm lane skips `*` (the param-`*` case -- d*d -- is the one that matters and IS a register).
   (pimm? x) (&& (whole? x) (<= (? (< x 0) (- 0 x) x) 4095))                     ; a small immediate both arches add/sub/cmp directly
   (preg tgt ps x) (&& (member? x ps) (argregir tgt (argix x ps 0)))            ; x a param -> its arg reg, else ()
   (garith-r tgt op R) (: A (greg tgt 'acc) SC (greg tgt 'scratch)              ; acc = acc OP R (R a reg), overflow -> OVF
      (? (id? op '+) `(`('adds A A R) '(br vs OVF))
         (id? op '-) `(`('subs A A R) '(br vs OVF))
         (id? op '*) `(`('mulo A A R SC 'OVF)) ()))
   (garith-i tgt op imm) (: A (greg tgt 'acc)                                   ; acc = acc OP imm (no '*'), overflow -> OVF
      (? (id? op '+) `(`('adds A A imm) '(br vs OVF))
         (id? op '-) `(`('subs A A imm) '(br vs OVF)) ()))
   (flipc op) (? (id? op '<) '> (id? op '<=) '>= (id? op '>) '< (id? op '>=) '<= op)   ; mirror a cmp's operands (= stays)
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
                 (holo (L (gargsir tgt syms ps (cup e)) (L (L 'call op)) (L (L 'add 'sp 'sp (* (slotsz tgt) (tally (cup e)))))))
               (member? op '(+ - *))
                 (: pa (preg tgt ps a) pb (preg tgt ps b)
                    (? pb                                (holo `((cggir tgt syms ps a) (garith-r tgt op pb)))   ; (E op p): E->acc; acc OP= p_reg
                       (&& (pimm? b) !(id? op '*))       (holo `((cggir tgt syms ps a) (garith-i tgt op b)))    ; (E op C)
                       (&& pa (member? op '(+ *)))       (holo `((cggir tgt syms ps b) (garith-r tgt op pa)))   ; (p op E): commute
                       (&& (pimm? a) (id? op '+))         (holo `((cggir tgt syms ps b) (garith-i tgt op a)))    ; (C + E): commute (imm '*' has no arm64 form -> generic)
                       (holo `((cggir tgt syms ps a) `(`('push A)) (cggir tgt syms ps b) `(`('pop T)) (garith tgt op)))))   ; generic
               (member? op '(// %))
                 (holo (L (cggir tgt syms ps a) (L (L 'push A)) (cggir tgt syms ps b) (L (L 'test A A) '(br eq OVF) (L 'pop T)) (divir tgt op)))
               (member? op '(& | ^))
                 (holo (L (cggir tgt syms ps a) (L (L 'push A)) (cggir tgt syms ps b) (L (L 'pop T) (L (bitop op) A A T))))
               (member? op '(< <= > >= =))
                 (: pa (preg tgt ps a) pb (preg tgt ps b)
                    (? pb         (holo `((cggir tgt syms ps a) `(`('cmp A pb) `('set (ccof op) A))))             ; (E op p): cmp acc,p_reg
                       (pimm? b)  (holo `((cggir tgt syms ps a) `(`('cmp A b)  `('set (ccof op) A))))             ; (E op C)
                       pa         (holo `((cggir tgt syms ps b) `(`('cmp pa A) `('set (ccof op) A))))             ; (p op E): flags p-acc = a-b, cc kept
                       (pimm? a)  (holo `((cggir tgt syms ps b) `(`('cmp A a)  `('set (ccof (flipc op)) A))))     ; (C op E): cmp acc,C = b-a, flip cc
                       (holo `((cggir tgt syms ps a) `(`('push A)) (cggir tgt syms ps b) `(`('pop T) `('cmp T A) `('set (ccof op) A))))))   ; generic
               (id? op '?)
                 (: el (mint 0) en (mint 0)
                    (holo (L (cggir tgt syms ps a) (L (L 'cmp A 0) (L 'br 'le el)) (cggir tgt syms ps b)
                            (L (L 'jmp en) (L 'label el)) (cggir tgt syms ps (caup (cup (cup e)))) (L (L 'label en)))))
               (id? op 'tally) (: R (argregir tgt (argix a ps 0)) `(`('ld A R 8)))                        ; (tally STR): acc = the len at [STR+8] (raw)
               (id? op 'peep) (: R (argregir tgt (argix a ps 0)) d (caup (cup (cup e))) inl (mint 0) endl (mint 0)   ; (peep STR i d): i unsigned-vs-len, OOB -> d, else byte [STR+i+16]
                  (holo `((cggir tgt syms ps b)
                         `(`('ld T R 8) `('cmp A T) `('br 'below inl) `('li A (? (whole? d) d 0)) `('jmp endl) `('label inl) `('ldxb A R A 1 16) `('label endl)))))
               (id? op 'pin) (: R (argregir tgt (argix a ps 0)) val (caup (cup (cup e)))     ; (pin C i V): store V's low byte at C's backing[i] (r8=[C+8]=backing str), return C
                  (holo `((cggir tgt syms ps b) `(`('push A)) (cggir tgt syms ps val)         ; i -> acc, push; V -> acc
                         `(`('pop T) `('ld 'r8 R 8) `('stxb 'r8 T 1 16 A) `('mov A R)))))      ; pop T(=i); r8=backing; [backing+i+16]=V.lo; acc=C
               (id? op 'mpeep) (: R (argregir tgt (argix a ps 0)) d (caup (cup (cup e))) lp (mint 0) ht (mint 0) ms (mint 0) en (mint 0)   ; (mpeep MAP k d): open-addressed probe -> the value (raw) in acc, gap-miss -> d
                  (holo `((cggir tgt syms ps b) `(`('leax 'r10 A A 1 1) `('mov A R)) (relabel (mpeep-ir (? (whole? d) d 0)) lp ht ms en 'deopt))))   ; k -> acc; r10 = tagged key (2k+1); acc = MAP; the probe (labels gensym'd)
               (id? op 'mpin) (: R (argregir tgt (argix a ps 0)) val (caup (cup (cup e))) lp (mint 0) ht (mint 0) ms (mint 0) en (mint 0)   ; (mpin MAP k v): probe + UPDATE-in-place; a grow-due MISS -> OVF (full unwind+deopt); returns MAP
                  (holo `((cggir tgt syms ps val) `(`('push A)) (cggir tgt syms ps b) `(`('leax 'r10 A A 1 1) `('mov A R)) (relabel mpin-ir lp ht ms en 'OVF) `(`('mov A R)))))   ; v -> acc, push (spill); k -> acc; r10=tag(k); acc=MAP; probe+store (the `(pop r8)` tail pops v); acc=MAP (threaded)
               (id? op 'two?) (: z (mint 0) en (mint 0)                                       ; (two? E): is E a chain? -> 1/0, TOTAL (no deopt -- a non-chain reads 0)
                  (holo `((cggir tgt syms ps a) `(`('test A 1) `('br 'ne z) `('ld T A 0) `('li 'r8 chainkind) `('cmp T 'r8) `('br 'ne z) `('li A 1) `('jmp en) `('label z) `('li A 0) `('label en)))))
               (id? op 'cap) (holo `((cggir tgt syms ps a) `(`('test A 1) `('br 'ne 'OVF) `('ld T A 0) `('li 'r8 chainkind) `('cmp T 'r8) `('br 'ne 'OVF) `('ld A A 8))))    ; (cap E): chain-guard -> OVF (non-chain deopts; always under two?), then acc=[E+8]
               (id? op 'cup) (holo `((cggir tgt syms ps a) `(`('test A 1) `('br 'ne 'OVF) `('ld T A 0) `('li 'r8 chainkind) `('cmp T 'r8) `('br 'ne 'OVF) `('ld A A 16))))   ; (cup E): chain-guard, then acc=[E+16]
               ()))
         ()))
   (gargsir tgt syms ps as) (? (atom? as) () (holo (L (cggir tgt syms ps (cap as)) (L (L 'push (greg tgt 'acc))) (gargsir tgt syms ps (cup as)))))
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
               (id? op 'link) (holo `((cggvir tgt syms ps (caup e)) `(`('push A)) (cggvir tgt syms ps (caup (cup e))) `(`('pop T)) (consir tgt)))   ; A;push;B;pop T(=A); cons(T,A)
               (id? op '?) (: el (mint 0) en (mint 0)
                  (holo `((cggir tgt syms ps (caup e)) `(`('cmp A 0) `('br 'le el)) (cggvir tgt syms ps (caup (cup e)))
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
            (holo `((gargsir tgt syms ps (cup e))                                      ; push the new args (all from the OLD regs)
                   (foldl (\ a i (holo `(a `(`('pop (argregir tgt (- (- k 1) i))))))) () (rangeL 0 k))   ; pop into the arg regs, reverse
                   `(`('jmp Lbody))))
          (&& (two? e) (id? (cap e) '?))                                              ; TAIL ? -> test non-tail, both branches tail
            (: el (mint 0) en (mint 0)
               (holo `((cggir tgt syms ps (caup e)) `(`('cmp A 0) `('br 'le el)) (cggtir tgt syms ps (caup (cup e)) selfnm Lbody)
                      `(`('jmp en) `('label el)) (cggtir tgt syms ps (caup (cup (cup e))) selfnm Lbody) `(`('label en)))))
          (cggir tgt syms ps e)))                                                     ; any other tail expr -> value in acc
   ; mkhir: one function. label; [push lr]; save arg regs; load the passed args; Lbody:; body; restore; [pop lr]; ret.
   (mkhir tgt syms nm ps body)
    (: k (tally ps) Lbody (mint 0)
       (holo (L (L (L 'label nm)) (hsave tgt) (saveargsir tgt k) (loadargsir tgt k) (L (L 'label Lbody))
               (? (hasl body) (cggvir tgt syms ps body) (cggtir tgt syms ps body nm Lbody))   ; VALUE body (conses) -> cggvir (no TCO); int body -> cggtir (TCO)
               (restargsir tgt k) (hrest tgt) (L '(ret)))))
   ; mkouterir: the entry's OUTER -- save anchor+arg regs; anchor=sp; fixnum-guard+push the args; call
   ; H_entry; pop args; restore; putfix + Continue; OVF (mov sp,anchor -> abandon frames; restore) -> DEOPT.
   (mkouterir tgt k entry arity valt smask mmask bufmask cmask pmask)              ; valt: VALUE-typed entry (heap ptr / tagged scalar) -> store acc AS-IS, no putfix. the masks
    (: A (greg tgt 'acc) S (greg tgt 'sp) IP (greg tgt 'ip) T (greg tgt 'tmp) OVFR (govf tgt) ss (slotsz tgt)   ; partition the entry's EXTERNAL args: int (sar) / string|map|cask (kind-guard, raw) / chain (raw, no guard) / point (nom|mint-guard, raw)
       strk (apof "") mapk mapkind bufk (apof (cask 1))                            ; the kind sentinels the raw-param guards check against
       (pusharg1 i) (: o (* 8 i)                                                   ; one external arg: load Sp[i] -> acc, guard by type, push
          (? (member? i cmask) `(`('ld A S o) `('push A))                          ; chain: raw, NO guard (two? total; cap/cup deopt a non-chain inline)
             (|| (member? i smask) (|| (member? i mmask) (member? i bufmask)))     ; string/map/cask: a fixnum can't be a heap obj (-> OVF), and [arg]'s kind must match (-> OVF); push RAW
               (: kind (? (member? i mmask) mapk (member? i bufmask) bufk strk)
                  `(`('ld A S o) `('test A 1) '(br ne OVF) `('ld T A 0) `('li 'r8 kind) `('cmp T 'r8) '(br ne OVF) `('push A)))   ; a FIXNUM (odd, br ne) deopts; then the kind word must match (br ne)
             (member? i pmask)                                                     ; point key: nom OR mint, pushed RAW -- word identity IS its whole equality;
               (: pok (mint 0)                                                     ;   a charm deopts (only interp knows the numeric bridges, (= 2 2.0))
                  `(`('ld A S o) `('test A 1) '(br ne OVF)
                    `('ld T A 0) `('li 'r8 nomkind) `('cmp T 'r8) `('br 'eq pok)
                    `('li 'r8 mintkind) `('cmp T 'r8) '(br ne OVF) `('label pok) `('push A)))
             `(`('ld A S o) `('test A 1) '(br eq OVF) `('sar A 1) `('push A))))    ; int: fixnum-guard (non-fixnum -> OVF), untag (sar), push
       pushargs (foldl (\ a i (holo `(a (pusharg1 i)))) () (rangeL 0 k))
       epi (? valt `(`('st S 0 A) `('add IP IP 16) `('ld T IP 0) `('jmpr T))                                  ; VALUE: store acc as-is; Continue (no putfix)
                 `(`('adds A A A) '(br vs DEOPT) `('or A A 1) `('st S 0 A) `('add IP IP 16) `('ld T IP 0) `('jmpr T)))   ; INT: putfix (overflow -> deopt); Continue
       (holo `((hsave tgt) `(`('push OVFR)) (saveargsir tgt k) `(`('lea OVFR 'sp 0)) pushargs
              `(`('call entry) `('add 'sp 'sp (* ss k))) (restargsir tgt k) `(`('pop OVFR)) (hrest tgt)   ; save/restore lr around the `call entry`: on arm64 `bl` clobbers x30, but x30 is the live return addr the threaded tail-call chain eventually `ret`s through -- the OUTER tail-jumps onward (br), so it must hand x30 back intact (no-op on x86: CALL/RET ride the stack)
              epi
              `(`('label 'OVF) `('lea 'sp OVFR 0)) (restargsir tgt k) `(`('pop OVFR)) (hrest tgt)
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
       ord (link efn (filter (\ f (! (id? (cap f) entry))) parse))                      ; entry first (H_entry sits right after the OUTER)
       valt (hasl eb)                                                                 ; entry value-typed (body conses) -> the value epilogue stores acc as-is
       info (map (\ f (L (cap f) (nthl f 1) (nthl f 2) (tally (nthl f 1)))) parse)     ; (name params body arity) -- for the interprocedural string fixpoint
       smap0 (map (\ f (link (cap f) (filter (\ j (suse? (nthl f 2) (nthl (nthl f 1) j))) (rangeL 0 (nthl f 3))))) info)   ; per-fn DIRECT string params (peep/tally/pin)
       smask (gsm entry (smfix info smap0))                                            ; the entry's STRING params, propagated to a fixpoint -> raw pointer, kind-guarded
       mmask (filter (\ j (muse? eb (nthl eps j))) (rangeL 0 k))                         ; entry MAP params (mpeep/mpin)
       bufmask (filter (\ j (buse? eb (nthl eps j))) (rangeL 0 k))                       ; entry CASK params (pin)
       cmask (filter (\ j (cuse? eb (nthl eps j))) (rangeL 0 k))                         ; entry CHAIN params (cap/cup/two?) -> raw, no guard
       pmask (filter (\ j (&& (nuse? eb (nthl eps j)) (! (member? j cmask)))) (rangeL 0 k))   ; entry POINT keys ((= P (cap ..))) -> raw, nom|mint-guarded; a chain-used param is never a point
       outer (mkouterir tgt k entry k valt smask mmask bufmask cmask pmask)
       Hs (foldl (\ a f (holo (L a (mkhir tgt syms (cap f) (nthl f 1) (nthl f 2))))) () ord)
       lrf (\ ds (? (atom? ds) (L entry) (: d (cap ds) (link (cap d) (link (cup d) (lrf (cup ds)))))))
       fb (ev (link ': (link '(mpeep mc mk md) (link '(peep mc mk md) (link '(mpin mc mk mv) (link '(pin mc mk mv) (lrf defs)))))))   ; the WHOLE group re-evaluated as the deopt fallback. Post-rebind `ev` is the glaze, so this RE-GLAZES the group (harmless: a never-deopting native re-build) -- which is why the mpeep/mpin->peep/pin byte-lane aliases (ldxb/stxb) MUST assemble on EVERY target (arm64 included). mpeep/mpin are GLAZE-internal (not real fns), aliased to the core peep/pin (the body reads the PREVIOUS=global binding by the sequence law -- not recursion); harmless for non-map lanes (peep/pin stay the core accessors)
       elam (link '\ (cat (nthl efn 1) (L (nthl efn 2))))                              ; the entry's source lambda (=/show)
       (nif (emit (peep (assemble tgt (holo (L outer Hs))) 'bytes 0)) fb elam k))
)
