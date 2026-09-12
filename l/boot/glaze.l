; glaze -- ev but faster: a closure compiled to native machine code and installed as a
; transparent applicable value. it applies by juxtaposition, is =/show identical to its
; source, and deopts to the interpreter on overflow, so native is never wrong, only faster.
;
; one file, in bake order. u/lcat.l lays it as src_glaze_z with l/holo's holo/x64/a64
; trailing, because the glaze folds `assemble` at its own compile:
;   (module 'glaze  emit   the native emitter
;                   auto)  ev's source recognizer, which reads emit's names bare
;   hook   the ala creation hook -- leaks natjit/fires/fired?/bake, so OUTSIDE the module
;   walk   prel's list walkers re-declared through the glazed compiler
;
; THE DECLINE LAW, before touching a lane. a lane is a recognizer + codegen pair, and
; cggir's dispatch ends in a silent (): an operand it cannot emit compiles to NO CODE at
; all and leaves whatever the accumulator last held. so a recognizer admitting one shape
; too many does not crash -- it answers a plausible number, forever. test_glazefuzz is the
; standing guard, and its leaf pools carry what the integer lanes CANNOT hold (strings,
; noms, lists, gems), the interesting behaviour being the decline and not the compile.
;
; the boundary contract: a value crossing into native arrives as its raw tagged love word
; (putfix A) and the result is re-tagged, so a codegen untags at the boundary. keep what
; crosses unboxed -- no allocation, no heap pointer held inside -- and it stays GC-safe.
; `nat` (l/love.c) is the install seam: cell [code src code interp lvm_ret 0] with the
; value at the 3rd word, so value[-1] is src and value[1] the deopt fallback, in a W^X
; arena. a64 still wants __builtin___clear_cache where the bytes are WRITTEN.
;
; and the law under all of it: a glaze wins only when it OWNS the loop -- a native
; function called from an interpreted loop pays a call boundary heavier than interpreting
; a small body. on the kernel the HHDM carries no NX bit and emitted bytes simply run; the
; host maps its heap no-execute, which is what the arena is for. a new freestanding target
; re-opens that question, so emit its probe with holo, never a hardcoded x86-64 buf.

(borrow 'holo)
(module 'glaze
; emit -- the codegen backend: a love closure compiled to native machine code and
; installed as a transparent applicable value. "ev but faster": the result applies
; by juxtaposition, is =/show identical to its source, and deopts to the interpreter
; on any surprise, so native is never wrong, only faster. the C seam is `nat`
; (love.c): it w^x-installs the bytes and wraps them in a closure cell
; [code, src, code, interp, lvm_ret, 0], value[-1]=src (=/show) and value[1]=interp.
;
; every lane below lays neutral l/holo/ IR and assembles it per target, so the
; roles are named through `greg`: x86 lands g/Ip/Hp/Sp in rdi/rsi/rdx/rcx, a64
; in x0..x3. putfix is `adds A A A` then `or A A 1` -- the overflow flag is the
; 62-bit fixnum boundary, which is what every arith result gates on.

; nif/nifx -- the C install seam (love.c). the book loses them on every boot
; (i/main.c), so this is the one door onto raw byte installation, and it is the
; glaze's. the RHS is the outer nif: a body-less `:` rebinds, it does not letrec.
(: nif nif  nifx nifx)

(: ; i/main.c brackets this load with (borrow 'holo) .. ai_shelve_, so assemble and
   ; assemble-at resolve at compile and fold into every closure (the capture law).
   ; this `:` is body-less, so its bindings leak to the glaze module's own book --
   ; which is why the byte-piece concat helper is `bcat` and never `holo`.
   ; glazeasm holds the assembler hook.l pins at its own install (holo is evaluated
   ; again, native-backed, after the glaze); unpinned, the module's current one serves.
   ; it leads the letrec: a value a lambda reads must precede every lambda reaching it.
   glazeasm {}
   (le8 n) (: u (n < 0 ? (n + 18446744073709551616) n)                        ; & is broken on a bignum >= 2^63,
              ((: (go i) (i < 8 ? ((u // (i 256)) % 256 . go (i + 1)) ())) 0))   ; so //% splits n into 8 LE bytes
   (le4 n) ((: (go i) (i < 4 ? ((n >> (8 * i)) & 255 . go (i + 1)) ())) 0)  ; n -> 4 LE bytes (offsets < 2^31, & ok)
   (emit l) (cask l)                       ; the charlist lane fills in C -- this was a pin per byte
   (jit lam) (jitir lam 'x64)            ; (jit '(\ x E)): an arity-1 arith leaf -> the neutral-IR lane
   (argix e ps i) (atom? ps ? 0  (e = <ps) i  (argix e >ps (i + 1)))   ; a param -> its frame index
   (jitn lam) (jitnir lam 'x64)          ; (jitn '(\ p0 .. E)): arity>=2 (natn curries to saturation)
   (jit2 lam) (jitn lam)                                                  ; arity-2 alias (self-t/auto.l)
   (gfind p l) (atom? l ? () (p <l) <l (gfind p >l))     ; first elt matching p
   ; a blob names no address of the binary: the kind sentinels and the callout drives are read
   ; off g at run time (love.h's JkX slots), so the bytes ride any base and any image
   (jk tgt r k) ['ld r (greg tgt 'g) ((jkoff 0) + (8 * k))]   ; 0 chain 1 str 2 map 3 nom 4 mint 5 gem 6 cask 7 drive 8 resume 9 cur 10 unc
   mapmix 0x9e3779b97f4a7c15                                       ; = love.c's map hash multiplier, for the inline probe
   (hasm tgt ir) (: f (glazeasm 'f) ((lit? f ? f (cite 'holo 'assemble)) tgt ir))   ; the pinned assembler, else the module's
   (asmx ir) ((hasm 'x64 ir) 'bytes)                                          ; assemble neutral IR -> flat bytes, x86
   (asmt tgt ir) ((hasm tgt ir) 'bytes)                                       ; ... target-aware (the loop/float lanes that run on both arches)
   ; the map probe, laid by the l/holo/ assembler so hit/miss/loop resolve as labels.
   ; reg map: holo r0=rax, r7=x86-r8, r8=x86-r9, r9=x86-r10, r10=x86-r11. it wants the map
   ; in rax and the tagged key in r11 (holo r10), and ends branched to hit (match) / miss (gap).
   mprobe-ir ['(ld r7 r0 8) '(ld r8 r7 16) '(shr r8 1) '(dec r8) '(add r7 r7 24)    ; r8=backing; r9=cap; >>1; --(=mask); r8=&slots
      ['li 'r0 mapmix] '(imul r0 r0 r10) '(rol r0 32) '(and r0 r0 r8) '(mov r9 r0)    ; rax=rot(mix*tagkey)&mask=I -> r10
      '(label loop) '(leax r0 r9 r9 1 0) '(ldx r0 r7 r0 8 0) '(cmp r0 r10) '(br eq hit)  ; slot[I].key == tagkey? -> hit
      '(test r0 1) '(br eq miss) '(inc r9) '(and r9 r9 r8) '(jmp loop)]                  ; gap (even) -> miss; else I=(I+1)&mask, loop
   (mpeep-ir d) (mprobe-ir                                                          ; read tails: miss -> default d; hit -> slot[I].value, untagged
      + [['label 'miss] ['li 'r0 d] '(jmp end)
         '(label hit) '(leax r0 r9 r9 1 0) '(ldx r0 r7 r0 8 8) '(sar r0 1) '(label end)])
   (asmx-seed ir nm addr) (: t (pin {} nm addr) f (glazeasm 'at)
                             (((lit? f ? f (cite 'holo 'assemble-at)) 'x64 ir t) 'bytes))   ; one pre-bound external label nm->addr (the glaze's deopt handler)
   ; the same probe with write tails, so `pin` is insert-or-update. a miss (a gap at slot I)
   ; with the table near full needs a grow, which native cannot do, so it deopts through an
   ; external label the caller seeds; `(tablet n)` presizes so a counted insert loop never gets
   ; there. keys and values are fixnums, so no GC write barrier is needed.
   mpin-ir (mprobe-ir + '((label miss)
      (ld r0 r7 -16) (sar r0 1) (cmp r0 r8) (br ge deopt)                           ; len >= mask(=cap-1) -> table near-full -> deopt (r8 still holds the mask)
      (leax r0 r9 r9 1 0) (stx r7 r0 8 0 r10)                                       ; slot[I].key = tagged key
      (pop r8) (leax r8 r8 r8 1 1) (stx r7 r0 8 8 r8)                               ; slot[I].value = tag(v)
      (ld r0 r7 -16) (add r0 r0 2) (st r7 -16 r0) (jmp end)                         ; len++ (putcharm: +2)
      (label hit) (leax r0 r9 r9 1 0) (pop r8) (leax r8 r8 r8 1 1) (stx r7 r0 8 8 r8)
      (label end)))
   ; the param-kind probes: how does the group body use P? each answer picks the entry
   ; guard mkouterir lays for that arg slot.
   (hasl e) (two? e ? (= <e '. || foldl (\ a x (a || hasl x)) 0 >e) 0)   ; e contains a cons? -> the group is value-typed
   (suse? e P) (? (atom? e) 0  (elem <e '(peep tally pin) && (= <>e P)) 1  (foldl (\ a x (a || suse? x P)) 0 >e))   ; a string: (peep P..)/(tally P)/(pin P..)
   (buse? e P) (? (atom? e) 0  (= <e 'pin && (= <>e P)) 1  (foldl (\ a x (a || buse? x P)) 0 >e))   ; a cask: (pin P..), so the guard wants the buf kind, not str
   (cuse? e P) (? (atom? e) 0  (elem <e '(cap cup two?) && (= <>e P)) 1  (foldl (\ a x (a || cuse? x P)) 0 >e))   ; a chain: <P />P /(two? P) -- raw, no entry guard, since two? is total
   (muse? e P) (? (atom? e) 0  ((= <e 'mpeep || (= <e 'mpin)) && (= <>e P)) 1  (foldl (\ a x (a || muse? x P)) 0 >e))   ; a map: (mpeep P k d) read or (mpin P k v) update -- raw, map-guarded
   ; a point key -- (P = <..) or (<.. = P) -- is raw word identity, guarded nom|mint: a point
   ; equals only itself, where a charm could bridge (2 = 2.0), so charms deopt to interp
   (nuse? e P)
    (? (atom? e) 0
       (e @ ('= x1 y1) ((= x1 P && two? y1 && elem <y1 '(cap cup))
                        || (= y1 P && two? x1 && elem <x1 '(cap cup)))
            0)
        1
       (foldl (\ a x (a || nuse? x P)) 0 >e))
   ; interprocedural string-param inference: a param is a string if used in peep/tally or
   ; passed as the arg to a sibling's string param, to a deduped fixpoint over the group's
   ; (name . smask) map. smasks only grow, so sm-size stabilizes and monofix (prel) converges.
   (dedup l) (atom? l ? () (elem <l >l) (dedup >l) (<l . dedup >l))   ; unique elements
   (gsm nm smap) (atom? smap ? () (= nm <<smap) ><smap (gsm nm >smap))                ; nm's smask in the (name . smask) map (() absent)
   (fnsm fp body smap)
    (dedup ((: (walk e acc)
              (two? e ?
                (: gm (gsm <e smap)                                                                 ; if <e is a group fn, its string-param indices
                   a2 (atom? gm ? acc (foldl (\ ac j (: arg (>e j) (elem arg fp ? (posof arg fp 0 . ac) ac))) acc gm))   ; a string arg that is our param -> our string param
                   (foldl (\ ac x (walk x ac)) a2 >e))
                acc))
              body (filter (k \ suse? body (fp k)) (rangeL 0 #fp))))                        ; seed acc = the direct peep/tally params
   (sm-size smap) (foldl (\ a e (a + #>e)) 0 smap)                                          ; total mask width, the ascending measure
   (smfix info smap) (monofix smap (st \ map (f \ <f . fnsm (f 1) (f 2) st) info) sm-size)
   ; the counted fold loop: acc = the fold of body(CV) over cv < N, N the tagged Sp[0], cmp the
   ; test the loop runs while.
   (foldinit op)  (op = '* ? 1 0)                                 ; * folds from 1, + from 0
   ; loopregs: N / counter / accumulator, caller-saved on both targets so they survive the body's
   ; acc/tmp/scratch. a64 picks x6/x7/x8 to dodge scratch=x10 and anchor=x9.
   (loopregs tgt) (= tgt 'x64 ? '(r8 r9 r10) '(r6 r7 r8))
   ; loopepi: the result is already in acc -- putfix, then Continue (Ip += 16 ; jmp [Ip]).
   (loopepi tgt) (: A (greg tgt 'acc) S (greg tgt 'sp) IP (greg tgt 'ip) T (greg tgt 'tmp)
      ([['adds A A A]] + (ldeopt tgt 0) + [['or A A 1] ['st S 0 A] ['add IP IP 16] ['ld T IP 0] ['jmpr T]]))
   (exitcc cmp) (cmp @ '< 'ge  '<= 'gt  '> 'le  '>= 'lt  '= 'ne  ())   ; exit on the inverse of the continue-comparison
   (loopcode body cv op cmp tgt)
    (: rs (loopregs tgt) N (rs 0) CV (rs 1) ACC (rs 2) A (greg tgt 'acc) S (greg tgt 'sp)
       bodyir (cgvir tgt (\ e d (e = cv && [['mov A CV]])) body 0)      ; body -> acc; the counter is read from cv
       accir  (op @ '+ ([['adds ACC ACC A]] + (ldeopt tgt 0))                                  ; acc += acc ; overflow -> inline deopt
                  '* (: dl (mint 0) ok (mint 0)                                                ; acc *= acc ; mulo sets no a64 flag, so it branches
                       ([['mulo ACC ACC A (greg tgt 'scratch) dl]] + [['jmp ok] ['label dl]] + (deoptbody tgt 0) + [['label ok]]))
                  ())
       pre  [['ld N S 0] ['sar N 1] ['li CV 0] ['li ACC (foldinit op)]]   ; N = Sp[0]>>1 (assumed fixnum) ; cv = 0 ; acc = init
       (asmt tgt (pre + ['(label top) ['cmp CV N] ['br (exitcc cmp) 'end]]   ; cmp cv,N ; exit when (cmp CV N) false
              + bodyir + accir + [['inc CV] '(jmp top) '(label end) ['mov A ACC]] + (loopepi tgt))))   ; cv++ ; loop ; acc <- acc ; putfix + Continue
   ; (jitsum body) -- compile (\ n (sum_{i<n} body(i))) to a native counted loop (x86 self-test helper).
   (jitsum body)
    (: src ['\ 'n [[': ['go 'i 'a] ['? ['< 'i 'n] ['go ['+ 'i 1] ['+ 'a body]] 'a]] 0 0]]
       (nif (emit (loopcode body 'i '+ '< 'x64)) (ev src) src 1))
   ; --- the stackless call-out drive ---------------------------------------------------------
   ; a counted loop over (clos i) that calls out without a re-entrant C frame: the blob builds
   ; the frame on Sp, points Ip at callout_drive (love.c, {lvm_ap, lvm_ret0}) and tail-jumps, and
   ; the result lands back at the blob's own resume label bb. `lar` materializes bb's address
   ; pc-relatively (rip-lea / ADR) -- la's page-relative adrp would mis-page in the word-aligned
   ; mmap blob. so the callee runs entirely on the VM stack: it grows Sp, never the C stack.
   ; the loop state is 6 reserved Sp slots, a GC root, so a callee GC relocates it for free:
   ;   R[0]=sa sum  R[1]=SC counter  R[2]=sn bound  R[3]=Sclos closure  R[4]=Sbase blob base
   ;   R[5]=Stwin the interp twin ; the arg n rides at R[6], the caller continuation at R[7].
   ; two inline gates deopt to that twin, so the native answer is exact or absent: the resume
   ; untags the callout result, so an even (heap) result deopts; and the sa fold is adds + br vc,
   ; so an out-of-range sum re-runs in interp and promotes to a bignum.
   ; value[1] is the plain twin -- the image-dump revert reads it as-is, and a pack chain there
   ; data-applies. `codeopt` restores Sp to entry (Sp[0] = the original tagged n) and continues
   ; into the twin, discarding the native partial sa as any loop deopt does.
   ; jitcalloutx stamps the caller's src at value[-1] for =/show; post-egg has no `poke`.
   ; the Sp offsets are VM words, the same on both targets -- slotsz only matters for push/pop,
   ; which the callout never uses.
   ; coacc / coend fold the callout result (tagged at Sp[0], Sp = R-8 at bb) into sa @ Sp[8]:
   ; `+` keeps sa tagged from init tag(0)=1 and adds the even 2r; `*` keeps it raw from 1 and
   ; retags in coend. both deopt to codeopt, which wants Sp = R-8, so coend's `*` path subs 8.
   (coacc tgt op) (: A (greg tgt 'acc) SP (greg tgt 'sp) T (greg tgt 'tmp) SC (greg tgt 'scratch)
      (= op '* ? [['sar A 1] ['ld T SP 8] ['mulo T T A SC 'codeopt] ['st SP 8 T]]                        ; sa(raw) *= untag(r) ; overflow -> deopt
         [['sub A A 1] ['ld T SP 8] ['adds T T A] ['br 'vc 'sok] ['jmp 'codeopt] ['label 'sok] ['st SP 8 T]]))  ; sa(tagged) += 2r ; overflow -> deopt
   (coend tgt op) (: A (greg tgt 'acc) SP (greg tgt 'sp)
      (= op '* ? [['ld A SP 0] ['adds A A A] ['br 'vc 'etag] ['sub SP SP 8] ['jmp 'codeopt] ['label 'etag] ['or A A 1]]  ; sa raw -> tag(SA) ; overflow -> deopt (Sp R -> R-8 first)
         [['ld A SP 0]]))                                                                                       ; sa already tagged
   ; a computed call-out arg: the per-step term is (F ARG), arg an expr over the counter rather than
   ; the bare counter. caargir lowers arg to acc raw -- exprp guarantees the counter is the only
   ; variable, so a name is the counter and wants no fixnum guard. guards and overflow branch to the
   ; callout's own `deopt`, which unwinds to codeopt and the interp twin; nesting rides the machine
   ; stack, independent of VM Sp, so coff is constant across sub-exprs.
   (caargir tgt e coff)
    (: A (greg tgt 'acc) S (greg tgt 'sp) T (greg tgt 'tmp)
       (bin a b fin) ((caargir tgt a coff) + [['push A]] + (caargir tgt b coff) + fin)
       (? (nom? e) [['ld A S coff]]                                                                          ; the counter, raw
          (whole? e) [['li A e]]
          (e @ ('? c t f) (: el (mint 0) en (mint 0)
                             ((caargir tgt c coff) + [['cmp A 0] ['br 'le el]] + (caargir tgt t coff)
                              + [['jmp en] ['label el]] + (caargir tgt f coff) + [['label en]]))
               (op a b) (? (elem op '(+ - *))       (bin a b ([['pop T]] + (arithir tgt op)))
                           (elem op '(// %) && divc? b) ((caargir tgt a coff) + [['mov T A]] + (divk tgt op b))
                           (elem op '(// %))        (bin a b ([['test A A] '(br eq deopt) ['pop T]] + (divir tgt op)))
                           (elem op '(& | ^))       (bin a b [['pop T] [(bitop op) A A T]])
                           (elem op '(< <= > >= =)) (bin a b [['pop T] ['cmp T A] ['set (ccof op) A]])
                           ())
               ())))
   ; caarg: leave tag(ARG(counter)) in the frame slot F[0] = Sp[-32], the 4-word walkable frame. a bare
   ; counter tags directly (a loop index is always a valid fixnum); a computed arg anchors the machine
   ; sp first, and both its guards and the tag overflow go to `deopt`.
   (caarg tgt arg) (: A (greg tgt 'acc) SP (greg tgt 'sp) T (greg tgt 'tmp) AN (greg tgt 'anchor)
      (nom? arg ? [['ld T SP 8] ['leax T T T 1 1] ['st SP -32 T]]                                         ; bare counter: F[0] = tag(i)
         ([['lea AN 'sp 0]]                                                                                     ; anchor the machine sp for the arg-expr deopt unwind
          + (caargir tgt arg 8)                                                                                   ; A = arg(counter) raw ; guards/overflow -> deopt
          + [['adds A A A] ['br 'vs 'deopt] ['or A A 1] ['st SP -32 A]])))                                   ; F[0] = tag(ARG) ; tag overflow -> deopt
   ; caargdeopt: restore the machine sp from the anchor (dropping any pending arg-expr pushes), bring
   ; VM Sp from R to R-8, and fall into codeopt. appended only when the arg is computed.
   (caargdeopt tgt) (: SP (greg tgt 'sp) AN (greg tgt 'anchor)
      ['(label deopt) ['lea 'sp AN 0] ['sub SP SP 8] ['jmp 'codeopt]])
   (calloutir tgt op arg)
    (: A (greg tgt 'acc)  IP (greg tgt 'ip)  SP (greg tgt 'sp)  T (greg tgt 'tmp)  U (greg tgt 'scratch)
       (['(label entry0)                                      ; the resume-offset anchor (lvm_resume jumps base + tag'd offset)
          ['sub SP SP 48]                                     ; reserve 6 loop-state slots (Sp = R)
          ['ld U IP 32] ['st SP 24 U]                        ; Sclos = the nifx extras slot = clos     -> R[3]  (IP still &value[0])
          ['ld U IP 8]  ['st SP 40 U]                         ; Stwin = value[1] = twin (interp)        -> R[5]
          ['ld T SP 48] ['sar T 1] ['st SP 16 T]            ; sn = untag(arg @ R[6])                  -> R[2]
          ['li T 1] ['st SP 0 T] ['li T 0] ['st SP 8 T]   ; sa = tag(0)=1, tagged so gate 2 checks the fixnum boundary ; SC = 0   -> R[0] R[1]
          ['lar T 'entry0] ['st SP 32 T]]                     ; Sbase = the blob base (out-of-pool W^X; lar = ADR on a64)  -> R[4]
        + ['(label top)
           ['ld T SP 8] ['ld U SP 16] ['cmp T U] ['br 'ge 'end]]   ; i >= n -> end
        + (caarg tgt arg)                                       ; F[0] = tag(ARG(counter)) -- bare i, or a computed expr (deopts to `deopt`)
        + [['ld T SP 24] ['st SP -24 T]                      ; F[1] = clos
           ['lar T 'bb] ['ld U SP 32] ['subs T T U]          ; F[2] = tag(&bb - base): an odd charm, GC-walk-clean
           ['leax T T T 1 1] ['st SP -16 T]
           ['st SP -8 U]                                       ; F[3] = base (out-of-pool -- the walk returns it unharmed)
           (jk tgt IP 8) ['sub SP SP 32]         ; Ip = callout_resume ; Sp = frame
           ['ld T IP 0] ['jmpr T]]                            ; Continue -> lvm_ap -> clos -> lvm_resume -> bb
        + ['(label bb)
           ['ld A SP 0]                                        ; A = result (Sp[0] on resume, Sp = R-8 -- same landing as the retired retB path)
           ['test A 1] ['br 'eq 'codeopt]]                    ; gate 1: non-fixnum (even) result -> deopt
        + (coacc tgt op)                                        ; gate 2: fold the result into sa @ Sp[8] (overflow -> deopt)
        + [['ld T SP 16] ['add T T 1] ['st SP 16 T]         ; SC += 1
           ['add SP SP 8] ['jmp 'top]]                        ; Sp = R ; next iteration
        + ['(label end)]
        + (coend tgt op)                                        ; A = sa tagged (`*` retags here, overflow -> deopt)
        + [['add SP SP 48] ['st SP 0 A]                      ; Sp = entry ; result into arg slot
           ['ld IP SP 8] ['st SP 8 A] ['add SP SP 8]         ; inline ret0: Ip=caller-cont; Sp[1]=result; Sp++
           ['ld T IP 0] ['jmpr T]]                            ; Continue -> caller
        + ['(label codeopt)                                    ; shared deopt (both gates); Sp = R-8 on entry
           ['ld A SP 48]                                       ; A = Stwin (R[5] @ Sp+48) -- before restoring Sp
           ['add SP SP 56]                                     ; Sp = entry (R+48); Sp[0] = the original tagged n
           ['mov IP A] ['ld A IP 0] ['jmpr A]]               ; Continue into twin, applied to Sp[0] = n
        + (nom? arg ? () (caargdeopt tgt))))                  ; the computed-arg `deopt` label, only when arg is an expr
   (jitcalloutsum clos) (jitcalloutx clos ['\ 'n 0] '+ 'i 'i 'x64)
   (jitcalloutx clos src op iv arg tgt)
    (: fop (= op '* ? (*) (+))  a0 (foldinit op)                             ; the fold op as a value -- a bare `* +` mid-list mis-factors -- and its identity
       argfn (nom? arg ? 0 (ev ['\ iv arg]))                               ; a computed arg -> a closure (\ counter ARG); a bare one needs none
       twin (nom? arg ? (n \ (: (go i a) (i < n ? (go (i + 1) (fop a (clos i))) a)) 0 a0)            ; bare: clos applied to the counter
                         (n \ (: (go i a) (i < n ? (go (i + 1) (fop a (clos (argfn i)))) a)) 0 a0))   ; computed: clos applied to arg(counter)
       (nifx (emit (asmt tgt (calloutir tgt op arg))) twin src 1 clos))   ; value[1] = the twin (image-revert-clean); clos = the extras slot; value[-1]=src
   ; --- the captured / multi-arg call-out ------------------------------------------------------
   ; the same stackless sum over (F i), but F and the bound N are frame params -- a captured import
   ; or a genuine second arg -- read at Sp[8*idx] rather than baked. `a` is the whole frame size
   ; (imports + args, ala's `ary`), so the entry frame is [p0..p_{a-1}] with the caller-cont at
   ; Sp[a], and the return hand-rolls lvm_ret(n=a): the call-out clobbers Ip, so the standard
   ; putfix + Continue epilogue is unreachable. either gate, or a non-fixnum N at the prologue,
   ; deopts to value[1]=e, the bytecode twin ala built -- it captures F, so it recomputes right.
   ; a>=2 here (a=1 no-imports is the global lane), so e is an lvm_cur cell: enter its body at
   ; e+16 with the saturated frame on Sp. the 6 reserved slots (Sp=R) are
   ;   R[0]=sa  R[1]=SC  R[2]=sn  R[3]=sf  R[4]=Sbase  R[5]=Se(=e), the frame above at E=R+48.
   (calloutframeir tgt Fidx Nidx a op arg)
    (: A (greg tgt 'acc)  IP (greg tgt 'ip)  SP (greg tgt 'sp)  T (greg tgt 'tmp)  U (greg tgt 'scratch)
       (['(label entry0)                                      ; the resume-offset anchor
          ['ld U SP (8 * Fidx)]                               ; U = F (raw closure) from the frame
          ['ld A SP (8 * Nidx)] ['test A 1] ['br 'ne 'ngood]]   ; N a fixnum? -> ngood
        + [['ld T IP 8] ['lea IP T 16] ['ld T IP 0] ['jmpr T]]   ; N not a fixnum -> deopt to e's body (Sp = E, IP valid)
        + ['(label ngood) ['sar A 1]                          ; A = N untagged
           ['ld T IP 8]                                        ; T = e (deopt twin = value[1], IP+8 at body entry)
           ['sub SP SP 48]                                     ; reserve 6 slots; Sp = R
           ['st SP 24 U] ['st SP 16 A] ['st SP 40 T]         ; sf = F ; sn = N ; Se = e
           ['li T 1] ['st SP 0 T] ['li T 0] ['st SP 8 T]   ; sa = tag(0)=1, kept tagged so gate 2 checks the fixnum boundary ; SC = 0
           ['lar T 'entry0] ['st SP 32 T]]                     ; Sbase = the blob base (out-of-pool W^X)
        + ['(label top)
           ['ld T SP 8] ['ld U SP 16] ['cmp T U] ['br 'ge 'end]]   ; SC >= sn -> end
        + (caarg tgt arg)                                       ; F[0] = tag(ARG(counter)) -- bare SC, or a computed expr (deopts to `deopt`)
        + [['ld T SP 24] ['st SP -24 T]                      ; F[1] = sf (clos)
           ['lar T 'bb] ['ld U SP 32] ['subs T T U]          ; F[2] = tag(&bb - base)
           ['leax T T T 1 1] ['st SP -16 T]
           ['st SP -8 U]                                       ; F[3] = base
           (jk tgt IP 8) ['sub SP SP 32]         ; Ip = callout_resume ; Sp = frame
           ['ld T IP 0] ['jmpr T]]                            ; Continue -> lvm_ap -> F -> lvm_resume -> bb
        + ['(label bb)
           ['ld A SP 0] ['test A 1] ['br 'eq 'codeopt]]      ; gate 1: a non-fixnum result -> deopt
        + (coacc tgt op)                                        ; gate 2: fold the result into sa @ Sp[8] (overflow -> deopt)
        + [['ld T SP 16] ['add T T 1] ['st SP 16 T]         ; SC += 1
           ['add SP SP 8] ['jmp 'top]]                        ; Sp = R ; next iteration
        + ['(label end)]
        + (coend tgt op)                                        ; A = sa tagged (`*` retags here, overflow -> deopt)
        + [['add SP SP 48] ['st SP 0 A]                      ; Sp = E (frame) ; result into Sp[0]
           ['ld IP SP (8 * a)] ['st SP (8 * a) A] ['add SP SP (8 * a)]   ; hand-rolled lvm_ret(n=a): cont@Sp[a] ; deliver ; pop a
           ['ld T IP 0] ['jmpr T]]                            ; Continue -> caller
        + ['(label codeopt)                                    ; shared gate deopt; Sp = R-8 on entry
           ['ld T SP 48]                                       ; T = Se (= e, R[5] @ Sp+48) -- before restoring Sp
           ['add SP SP 56]                                     ; Sp = E (frame intact for e's body)
           ['lea IP T 16] ['ld T IP 0] ['jmpr T]]            ; enter e's body (a>=2: e+16), saturated frame on Sp
        + (nom? arg ? () (caargdeopt tgt))))                 ; the computed-arg `deopt` label, only when arg is an expr
   (njit-calloutframe src Fidx Nidx a e op arg tgt)
    (nif (emit (asmt tgt (calloutframeir tgt Fidx Nidx a op arg))) e src a)   ; value[1] = e (the bytecode twin, deopt target -- source-shaped, so op- AND arg-correct); arity a ; src for =/show
   ; --- amble: the boring-tier translator ------------------------------------------------------
   ; the last natjit lane: a closure every other lane declined gets a per-op native translation.
   ; values stay tagged, so heap refs ride whole and there are no result gates; every temporary
   ; lives in a reserved vm-sp slot, a GC root, so a callee GC relocates mid-expression state for
   ; free; the machine stack is never used. calls leave via the stackless callout_drive and resume
   ; at a lar label, so any callee value works (lvm_ap is total -- data self-applies) and a
   ; multi-arg call chains 1-arg drives, since application is currying.
   ; every runtime surprise -- a non-fixnum under arith/cmp, a heap value under ?, overflow, a
   ; full heap under link -- deopts by restart: the twin comes from its reserved slot (a call
   ; clobbers Ip, so the epilogue hand-rolls lvm_ret and the deopt never reads Ip-relative), Sp
   ; is restored, and e re-runs from the restart point. a restart repeats any call-out already
   ; made from that point, which only a pure callee survives -- so asafe (njit-amble) declines a
   ; body where a deopting op sits after a call, and the grammar's calls stay ones no restart can
   ; reach.
   ; amble-ok? below is the grammar. strings, floats and global reads in operand position decline.
   ; a global callee resolves via gv at compile -- redefinition-stale, the callout lanes' bet --
   ; and never through a farq name, whose book entry is at best a stale namesake.
   ; a ? over a heap test value, bare (? l ..) on a list, deopts every call: correct, and a small
   ; entry tax over pure bytecode.
   amble-nil (:)
   amble-lam (mint 0)                                             ; the inner-lambda site marker: (amble-lam i n v..) -- entry i of arity n, curried through the imports v..
   (amax a b) (a < b ? b a)
   (adistinct l) (l @ (a . u) (!(elem a u) && adistinct u) 1)
   ; a constant rides as the immediate tag(e) = 2e+1, so only one that fits the machine word
   ; can: a big literal (or one folding left behind) would be laid truncated, silently.
   (afix? e) (whole? e && (-4611686018427387904 <= e <= 4611686018427387903))
   (aconst? e) (afix? e || (= e amble-nil))
   (aop2? op) (elem op '(+ - * // % & | ^ < <= > >= = == .))
   (acmp? op) (elem op '(< <= > >= =))
   (aquote? e) (two? e && (= <e '\) && 2 = #e)            ; the reader's quote: (\ X) at exactly two -- a datum constant
   (aqnom? e) (aquote? e && nom? <>e)                          ; a quoted nom: a point, so (a = 'sym) is raw identity
   (amemq x l) (atom? l ? 0  (= x <l) 1  (amemq x >l))     ; ==-membership: interp's quote answers the source node, so two
   (aposq x l i) (= x <l ? i (aposq x >l (i + 1)))         ; =-equal quote nodes stay distinct slots
   (aq e acc) (? (aquote? e) (amemq e acc ? acc (e . acc))          ; collect quote nodes; never walk into quoted data
                 (two? e) (foldl (\ ac x (aq x ac)) acc e)
                 acc)
   aopheads '(? : two? cap cup + - * // % & | ^ < <= > >= = == .)   ; the heads that are ops, not calls
   ; every head the amble reads by NAME: aopheads, the ones carrying their own arm, and the
   ; two reads asafe rules a call-out out for. a frame that rebinds one of these does not mean
   ; the op by it, so njit-amble masks the taken ones out of all three recognizers at once.
   ; ? and : stay off the roster -- they are the reader's syntax, not names a body can take.
   aopnames '(two? cap cup + - * // % & | ^ < <= > >= = == . || && tally list
              one? nil? atom? != !== peep mpeep)
   (ahascall? env go e)                                                  ; does e contain a call (any non-op head)? the bisect knob's test
    (? (aquote? e) 0
       (two? e) (: op <e
          ((nom? op && !(= op go) && !(elem op aopheads))
           || (foldl (\ a x (a || ahascall? env go x)) 0 >e)))
       0)
   ; aheads: collect the free call heads of e, the global-callee candidates. within the accepted
   ; grammar the only binders are the frame and the one named-let, so a head outside env/go is a
   ; global. go and the frame/loop names are never candidates: a named-let binds go over its whole
   ; body, so a non-tail (go ..) is local and must decline rather than resolve a leaked namesake.
   ; collection over-approximates -- amble-ok? is the gate, gn merely feeds it -- and quoted data
   ; stays unwalked.
   (aheads env go e acc)
    (? (aquote? e) acc
       (two? e)
        (: op <e                                                    ; a2, not a rebind of acc: a `:` is one scope, so `acc (.. acc ..)`
           a2 (? ((nom? op) && !(= op go) && !(elem op env) && !(elem op acc)
                  && !(elem op aopheads))
                 (op . acc) acc)                                      ; would read the unpinned local
           (foldl (\ ac x (aheads env go x ac)) a2 >e))
       acc)
   ; amble-ok?: does e compile? env = visible names (loop vars shadow params), shd = the op
   ; names this frame may not claim, gn = resolvable global call heads, go/k = the loop name +
   ; its arity (0 outside a loop), tl = tail position ((go ..) is a jump, so it is only sound
   ; where its value IS the loop's value).
   (amble-ok? env shd gn go k tl e)
    (? (nom? e) (elem e env)
       (aconst? e) 1
       (nom? e) (elem e env)                                                      ; a mint: an inlined callee's let-bound arg
       (aquote? e) 1
       (two? e)
        (: op <e  as >e  n #as  oop (elem op shd ? 0 op)      ; a name the frame took is a call
           (? (= op '?) (2 <= n <= 3 && (amble-ok? env shd gn go k 0 <as)   ; 2-arm ?: the missing else is (), acg's amble-nil slot
                           && (amble-ok? env shd gn go k tl <>as)
                           && (amble-ok? env shd gn go k tl <>>as))
              (= op ':) (!(#e % 2)                                        ; a value let: binders enter env in order, so a forward
                           && ((: (gol l ev)                                       ; read declines rather than reading a stale slot
                                (? (atom? >l) (amble-ok? ev shd gn go k tl <l)
                                   ((amble-ok? ev shd gn go k 0 <>l)
                                    && (gol >>l (= <l '_ ? ev (<l . ev))))))
                               as env))
              (elem oop '(two? cap cup)) (n = 1 && amble-ok? env shd gn go k 0 <as)
              (aop2? oop) (n = 2 && amble-ok? env shd gn go k 0 <as && amble-ok? env shd gn go k 0 <>as)
              (= oop '||) (2 <= n && all (x \ amble-ok? env shd gn go k 0 x) as)
              (= op amble-lam) (all (v \ elem v env) >>as)                 ; an inner lambda site: its imports are frame reads
              (= op go) (tl && n = k && all (x \ amble-ok? env shd gn go k 0 x) as)
              (nom? op) ((0 < n) && (elem op env || elem op gn)
                          && (all (x \ amble-ok? env shd gn go k 0 x) as))
              0))
       0)
   ; amble-depth: an upper bound on the spill slots e needs (operand nesting rides VM slots).
   ; cx op = the extra curry steps a head carries -- a sibling callee's import count, since its
   ; chain is entry(imports.. args..); 0 for every other head.
   (admax go cx as) (foldl (\ a x (amax a (amble-depth go cx x))) 0 as)   ; the widest operand
   (amble-depth go cx e)
    (? (atom? e) 0
       (aquote? e) 0
       (: op <e  as >e
          (? (= op '?) (amax (amble-depth go cx <as) (amax (amble-depth go cx <>as) (amble-depth go cx <>>as)))
             (= op ':) (admax go cx as)                             ; lets ride their own slots; parts run sequentially
             (elem op '(two? cap cup)) (amble-depth go cx <as)
             (= op '||) (#as + admax go cx as)                      ; aor needs no spills, but a shadowed || is a call, and
                                                                      ; the call formula covers both -- over-reserving is safe
             (= op amble-lam) 0                                     ; the site lays its chain straight onto the heap
             (= op '=) (2 + (amax (amble-depth go cx <as) (1 + (amble-depth go cx <>as))))   ; aeq2's slow lane spills the partial + the operand
             (aop2? op) (amax (amble-depth go cx <as) (1 + (amble-depth go cx <>as)))
             (= op go) (#as + admax go cx as)
             ((cx op) + #as + admax go cx as))))                      ; a call spills a partial per curry step, so an n-arg call reserves n
   ; amble-loop: match the named-let body, both def sugars x both spellings --
   ;   applied:  ((: (go v..) GB) i..)  |  ((: go (\ v.. GB)) i..)
   ;   trigger:  (: (go v..) GB (go i..))  |  (: go (\ v.. GB) (go i..))   the body-having let
   ; whose result is the fired loop, moon's lexer spelling.  -> (go vars GB inits) | 0
   (amble-let1 S inits)
    (S @ (': D1 D2)
         (? (two? D1 && nom? <D1 && all nom? >D1 && 0 < #>D1)
              [<D1 >D1 D2 inits]
            (nom? D1 && two? D2 && (= <D2 '\) && two? >D2 && two? >>D2)
              [D1 (init >D2) (last >D2) inits]
            0)
       0)
   (amble-loop M)
    (? (atom? M) 0
       (two? <M) (amble-let1 <M >M)                        ; applied
       (M @ (': DEF GB trg)                                ; trigger: the let's result is the fired loop
            (: r (amble-let1 [': DEF GB] ())
               (r && two? trg && (= <trg <r) ?              ; the trigger fires the same name; its args are the inits
                  [<r <>r <>>r >trg]                        ; amble-ok? gates their content -- a (go ..) inside one declines
                  0))
            0))
   ; asub: naive whole-form substitution, safe because the amble grammar admits no inner binders
   ; (no nested \ or : inside a loop body), so there is nothing to capture. it alpha-renames a
   ; loop var that shadows a frame param, the walker idiom ((: (go l a) ..) l a): the inits then
   ; read the params, the body the renamed vars, and one flat env serves both.
   (asub old new e) (? (= e old) new  (aquote? e) e  (two? e) (map (x \ asub old new x) e)  e)   ; quoted data is inert -- never rename inside it
   (afresh v avoid) (: c (intern ((string v) + "~")) (elem c avoid ? (afresh c avoid) c))
   ; aopv: a macro expansion splices op values, not noms -- the list/backtick macro emits the link
   ; nif as a head, and show prints that as `link`, invisibly. normalize a value head back to its
   ; nom, ==-keyed, and only when the nom is not env-shadowed: a param named link must win, as it
   ; does in bytecode. a miss falls through to `opnom`, the glued lane's own value -> word map
   ; (prel), so every sigil-backed head is named without this list carrying all fourteen.
   aopv [[two? 'two?] [cap 'cap] [cup 'cup] [(.) '.]
           [tally 'tally] [(+) '+] [(-) '-] [(*) '*] [(<) '<] [(<=) '<=]
           [(>) '>] [(>=) '>=] [(=) '=] [(//) '//] [(%) '%] [(&) '&] [(|) '|] [(^) '^]]
   (aopn x l) (atom? l ? (opnom x)  (= x <<l) <><l  (aopn x >l))
   ; adesug: rewrite what amble can own by pure source identity, so the twin/deopt story is
   ; untouched. (X) is X -- an infix span reads as the wrapped application, (k < n) -> ((k < n)),
   ; so every infix-written body wears these singletons -- a value head is its nom, (list a..) is
   ; nested links, and (&& a..) is nested (? a .. ()), short-circuit included, since && answers
   ; its last value or the unit. env-shadowed names stay calls and quoted data stays inert.
   ; (|| ..) is not rewritten: its value is the first truthy arg, so a rewrite would double-eval.
   ; aor emits it.
   (adesug env ti ta e)
    (? (aquote? e) e
       (atom? e) e
       ; the analyzer's tags, worn by synthesized surfaces (a letrec body-lambda has no source
       ; stash): (apx n head args..) is the apply, (iop VALUE args..) carries the VM op as a
       ; value aopv/opnom name back. ti/ta are ev.l's own uninterned markers, handed down by
       ; ala, so the match is exact and unforgeable; an unmapped or shadowed op value declines.
       (= <e ta) (two? >e && whole? <>e && two? >>e ? (adesug env ti ta >>e) e)
       (= <e ti) (two? >e && two? >>e ?
                      (: vn (aopn <>e aopv)
                         (vn && !(elem vn env) ? (adesug env ti ta (vn . >>e)) e))
                      e)
       ; the (X) singleton, by emptiness and never nil?: a tail of nameless mints (bsub's fresh
       ; binders) nets to 0, and the net test unwraps (\ m1 m2 m2) to a bare \, a quote-shaped
       ; wreck amble would then compile as the constant \
       (atom? >e) (adesug env ti ta <e)
       (: op0 <e
          vn (nom? op0 || two? op0 ? 0 (aopn op0 aopv))
          op (vn && !(elem vn env) ? vn op0)
          as >e
          (? (= op 'list && 0 < #as && !(elem op env))
               ((: (go l) (two? l ? ['. (adesug env ti ta <l) (go >l)] ())) as)
             (= op '? && 3 < #as)                                            ; a cond chain nests: (? c a c2 b e) is (? c a (? c2 b e))
               ((: (go l) (atom? >l ? (adesug env ti ta <l)
                             (['? (adesug env ti ta <l) (adesug env ti ta <>l)] + (two? >>l ? [(go >>l)] ()))))
                as)
             (= op 'nil? && 1 = #as && !(elem op env))    ; opfix spells the negations as ?s: (nil? x) is (? x 0 1),
               ['? (adesug env ti ta <as) 0 1]                 ; (one? x) is (? (two? x) 0 1), (!= a b) is (? (= a b) 0 1)
             ((= op 'one? || (= op 'atom?)) && 1 = #as && !(elem op env))
               ['? ['two? (adesug env ti ta <as)] 0 1]
             (= op '!= && 2 = #as && !(elem op env))
               ['? ['= (adesug env ti ta <as) (adesug env ti ta <>as)] 0 1]
             (op = '!== && 2 = #as && !(elem op env))          ; and identity's, the same shape
               ['? ['== (adesug env ti ta <as) (adesug env ti ta <>as)] 0 1]
             (= op '&& && 2 <= #as && !(elem op env))
               ((: (go l) (two? >l ? ['? (adesug env ti ta <l) (go >l) ()] (adesug env ti ta <l))) as)
             ((= op op0 ? (adesug env ti ta op0) op) . map (x \ adesug env ti ta x) as))))
   ; njit-amble: the hook entry -- compile s (deopt -> e) or answer 0 (decline; the hook keeps e).
   ; farq = ala's letrec-local predicate (see hook.l): a truthy (farq nom) names a binding that
   ; is free-looking in a weave re-analysis surface, wire-resolved in truth -- never a gn candidate.
   ; lams = the scope's lambda-sibling list ((name . cell)..): a cell holds (entry . import-names),
   ; lz's frozen site.
   ; alets: collect the value-let binders of e -- every (: p v .. body) node -- and validate
   ; what amble can own: an even tally (the body-less form binds the ENCLOSING scope), name
   ; binders (a define-sugar pair is a lambda), and no shadowing, where enc is the binders
   ; still in scope. one slot serves a name wherever it is bound, so the `(: r ..)` of one arm
   ; and the `(: r ..)` of its sibling share it, each written before it is read. `_` evaluates
   ; and drops, never binds. answers the name list, or 'bad (the body declines).
   (alets e acc) (alt e acc ())
   (alt e acc enc)
    (? (= acc 'bad) 'bad
       (aquote? e) acc
       (atom? e) acc
       (= <e ':)
        (#e % 2 ? 'bad
           ((: (gol l ac en)
               (? (= ac 'bad) 'bad
                  (atom? >l) (alt <l ac en)
                  (: p <l  v <>l
                     (!(nom? p) || (= p ()) ? 'bad                           ; a binder is a name, or the mint an inlined callee's arg wears
                        (: a2 (alt v ac en)
                           (? (= a2 'bad) 'bad
                              (= p '_) (gol >>l a2 en)
                              (elem p en) 'bad
                              (gol >>l (elem p a2 ? a2 (p . a2)) (p . en))))))))
            >e acc enc))
       (foldl (\ ac x (alt x ac enc)) acc e))
   ; adrv?: does e contain a driver call -- a self-call or an applied frame/loop nom? the
   ; non-loop cost gate: a body whose only calls go to resolvable globals is a one-shot
   ; wrapper, whose compile is nearly always a waste, where a body that drives a parameter
   ; (a walker's f) or itself amortizes like a loop.
   (adrv? env sf e)
    (? (aquote? e) 0
       (two? e) (: op <e
          ((nom? op && (= op sf || (elem op env && two? >e)))
           || (foldl (\ a x (a || adrv? env sf x)) 0 >e)))
       0)
   ; ainl: rewrite every inner lambda (\ q.. B) whose creation ala recorded -- inl is this
   ; lambda's subtree ((exp src-tail (entry . imports))..), matched by the node itself -- into
   ; the site marker (amble-lam i n v..): entry i enters st's list, n is its arity (imports +
   ; params), v.. the import names the site reads off the frame. an unrecorded lambda stays and
   ; declines; the inner body is never walked, since its binders are its own, and quoted data
   ; is inert. a body with no record and no inner lambda is answered as it is, unwalked.
   (ainlr t inl) (atom? inl ? 0  (= t <<inl || (= t <><inl)) <>><inl  (ainlr t >inl))
   (alam? e) (? (aquote? e) 0  (atom? e) 0  (= <e '\ && two? >e && two? >>e) 1  (foldl (\ a x (a || alam? x)) 0 e))
   (ainl e inl st) (two? inl && alam? e ? (ainl0 e inl st) e)
   (ainl0 e inl st)
    (? (aquote? e) e
       (atom? e) e
       (= <e '\ && two? >e && two? >>e)
        (: r (ainlr >e inl)
           (r ? (: i #(st 'l)
                   _ (pin st 'l ((st 'l) + [<r]))
                   (amble-lam . i . (#>r + #e - 2) . >r))
              e))
       (map (x \ ainl0 x inl st) e))
   (njit-amble s a e gv farq lams nm ti ta inl tgt)
    (: ps (init >s)  M (last >s)
       lp (amble-loop M)
       go   (lp ? <lp 0)     vars0 (lp ? <>lp ())
       GB0  (lp ? (lp 2) 0)  inits (lp ? (lp 3) ())
       shad (filter (v \ elem v ps) vars0)
       ren  (map (v \ [v (afresh v (go . vars0 + ps))]) shad)
       vars (map (v \ (: r (assoc v ren) (r ? <>r v))) vars0)
       st   {}                                                 ; the inner-lambda sites: 'l = their entries, in site order (the marker's index)
       GB   (lp ? (foldl (\ b pr (asub <pr <>pr b)) (ainl GB0 inl st) ren) 0)   ; the sites first, so a shadowing loop var renames their imports too
       k    #vars
       body (lp ? GB (ainl M inl st))
       env  (vars + ps)
       ; a head is the op only where its name still MEANS it, and env is this frame's binders
       ; alone -- an enclosing letrec that rebinds one of the amble's words is invisible there,
       ; so every recognizer would read the op the name no longer names. farq knows those
       ; binders: shd is the taken names, usually none, and adesug, amble-ok?, asafe and acg
       ; all mask through it, so a rebound word stays a call in all four.
       shd  (filter (nm \ elem nm env || farq nm) aopnames)
       denv (env + shd)
       body (adesug denv ti ta body)                         ; own list/&& by definition (nested links / nested ?s) + untag
       inits (map (i \ adesug denv ti ta (ainl i inl st)) inits)
       ins  (st 'l)
       nin  #ins
       ; self: the letrec name this closure is being bound to (ala's nm; 0 when anonymous).
       ; a saturated tail self-call jumps the body top on a rewritten frame, so the recursion
       ; becomes a loop; any other self-call drives the blob's own cell, read off Ip at the
       ; prologue -- early-bound, exactly the wire's backpatched site. a shadowed name declines.
       sc   (assoc nm lams)                                  ; the self lams cell: its kept import row names the frame's leading slots,
       scc  (two? sc ? (peep >sc 0 0) 0)                     ; so a self-call re-supplies the imports the way the wire's site does
       simp (two? scc ? >scc ())
       ni   #simp
       self (? (= nm 0) 0  (elem nm ps) 0  (elem nm vars0) 0  (= nm go) 0
               (elem nm '(? two? cap cup == + - * < <= > >= = || tally list &&)) 0
               !(simp = (take ni ps)) 0
               nm)
       sfq  !(= self 0)
       ; the value lets ride pre-allocated slots past the spills: one flat namespace (alets
       ; declines a rebind or a shadow), binders visible in order.
       lts0 (foldl (\ ac i (alets i ac)) (alets body ()) inits)
       lts  (? (= lts0 'bad) 'bad
               (foldl (\ ac p (ac || elem p env || (= p go) || (= p self))) 0 lts0) 'bad
               lts0)
       nl   (= lts 'bad ? 0 #lts)
       envl (= lts 'bad ? env (env + lts))
       ; the free-head seams: loop bodies, and drok bodies that drive a param or themselves --
       ; the shapes that amortize the call and compile taxes. a one-shot wrapper whose only
       ; calls go to globals, (\ t k (peep t k ())) and kin, stays bytecode.
       ; a free head that is not farq resolves via gv at compile and rides an extras slot,
       ; redefinition-stale, exactly the callout lanes' bet. a farq name -- a letrec local the
       ; weave re-analysis dropped from the import row -- must never gv-resolve: the book holds
       ; at best a stale namesake.
       ; a farq name that lamq does resolve is a woven lambda sibling of this very let, and its
       ; (entry . import-names) is the same pair lz freezes into a bytecode reference site, so
       ; amble compiles the identical application with no staleness bet: the entry rides an
       ; extras slot and the call curries entry(imports.. args..). fixcaps' pour guarantees the
       ; import names sit in this frame; entry 0 (a forward or self ref, lz's backpatch case) or
       ; a stray import just isn't in cn, and amble-ok? declines that body.
       cand (filter (f \ !(= f self)) (foldl (\ ac i (aheads envl go i ac)) (aheads envl go body ()) inits))
       drok (lp ? 1 (two? cand || two? ins ? (adrv? envl self body) 1))  ; the non-loop cost gate: free heads and inner lambdas ride only a body that
                                                                         ; drives a param or itself -- and a declining body skips the resolution below
       csx  (drok ? (map (f \ [f (farq f ?                   ; only a letrec-local can be a sibling, and farq is the cheap gate
                              (: lfd (assoc f lams)          ; the lam-list assoc; the cell read mirrors ev.l's cof, box slot 0
                                 (two? lfd ? (peep >lfd 0 0) 0))
                              0)])
                 cand) ())
       cgood (filter (p \ (: cc <>p                    ; import names must be frame params (ps, where fixcaps pours them)
                             (two? cc && <cc && all (x \ elem x ps) >cc))) csx)   ; and never loop vars -- bytecode reads the propagated capture
       cn    (map cap cgood)
       cvals (map (p \ <<>p) cgood)
       (cimp f) ><>(assoc f cgood)
       gps  (drok ? (filter (p \ lit? <>p)
             (map (f \ [f (gv f 0)])
              (filter (f \ !(farq f)) (filter (f \ !(elem f cn)) cand)))) ())
       gn   (map cap gps)
       gvals (map caup gps)
       qs   (drok ? (foldl (\ ac i (aq i ac)) (aq body ()) inits) ())   ; the quoted-datum constants (==-deduped source nodes); a declined body skips the walk
       nq   #qs
       eqv  (gv '= 0)                                       ; the = value: aeq2's generic lane drives it off an extras slot
       cx   (op \ (? (= op self) ni (elem op cn) #(cimp op) 0))
       ; a body with a call never restarts: past the first call a deopt would re-run it, so in
       ; that body every guard on an arith op, a compare, cap/cup, a cons or a truth test jumps a
       ; stub that drives the op's own value over the operands and resumes -- the answer is the
       ; interpreter's, and nothing is replayed. the values ride the extras chain past the inner
       ; entries, and a stub pulls its own into one slot -- the entry never copies them
       fbk  (drok && (ahascall? env go body || foldl (\ ac i (ac || ahascall? env go i)) 0 inits))
       ovs  (fbk ? '(+ - * // % & | ^ < <= > >= = cap cup . bit) ())
       ovals (map (o \ (= o 'bit ? bit (gv o 0))) ovs)   ; the truth stub's bit is the glaze's own: the book's may be a module's namesake
       nd0  (drok ? (amax (amble-depth go cx body) (foldl (\ acd i (amax acd (amble-depth 0 cx i))) 0 inits)) 0)
       nd   (nd0 + (fbk ? 1 0))                                  ; the stubs read the right operand off one spill past its op
       kn   (sfq ? (self . (gn + cn)) (gn + cn))         ; every resolvable free head + the self name (amble-ok?'s membership test)
       lpok (lp ? ((all nom? vars) && (adistinct vars) && (k = #inits)
                   && !(elem go vars) && !(elem go ps)) 1)
       ; the restart law. a deopt restarts: Sp goes back and the twin re-runs from the restart
       ; point, so every call-out the native already made is made again -- faithful only where
       ; the callee is pure, which the grammar cannot ask. so in a body with a call (fbk) the
       ; guards on arith, compares, cap/cup, a cons and the truth test do not deopt at all: each
       ; jumps a stub that drives the op's own value and resumes (fb1/fb2/atruth). what still
       ; restarts -- the map lanes' guards and an inner site's room guard -- may not sit after a
       ; call: asafe walks acg's own evaluation order carrying "a call has run", answering that
       ; flag onward or 'bad where such a guard follows one. the restart point is the arg slots: a
       ; saturated tail self-call rewrites them before the jump, so the flag clears at that back
       ; edge. the lanes that drive rather than guard -- =, tally -- resolve book primitives at
       ; compile, and two?/== carry no guard at all, so none of them sets the flag.
       (asafe tl cl ex)
        (: (aseq c l) (foldl (\ ac x (asafe 0 ac x)) c l)                      ; the children, in order
           (aguard c) (? (= c 'bad) 'bad  c 'bad  0)                         ; then the node's own guard
           (? (= cl 'bad) 'bad
              (atom? ex) cl
              (aquote? ex) cl
              (: op <ex  as >ex  oop (elem op shd ? 0 op)
                 (? (= op ':) ((: (gol l c) (atom? >l ? (asafe tl c <l) (gol >>l (asafe 0 c <>l)))) as cl)
                    (= op '?)
                     (: ct (fbk ? (asafe 0 cl <as) (aguard (asafe 0 cl <as)))
                        (? (= ct 'bad) 'bad
                           (: ca (asafe tl 0 <>as)  cb (asafe tl 0 <>>as)      ; the arms are alternatives; either call poisons the sequel
                              (? (= ca 'bad || (= cb 'bad)) 'bad (ca || cb)))))
                    (sfq && tl && (= op self) && (#as = (a - ni)))
                     (: c2 (aseq cl as) (= c2 'bad ? 'bad 0))                ; the self back edge
                    (= op go) (fbk ? (aseq cl as) (aguard (aseq cl as)))     ; the named-let back edge
                    (elem oop '(two? ==)) (aseq cl as)
                    (= oop '= && (aqnom? <as || aqnom? <>as || lit? eqv)) (aseq cl as)
                    (= oop 'tally && elem 'tally gn && atom? >as) (aseq cl as)
                    (= oop '|| && two? >as) (fbk ? (aseq cl as) (aguard (aseq cl as)))
                    (= op amble-lam) (two? >>as ? (aguard cl) cl)            ; the site's room guard, over frame reads
                    (elem oop '(cap cup . + - * // % & | ^ < <= > >= =)) (fbk ? (aseq cl as) (aguard (aseq cl as)))   ; stubs in fallback mode
                    (elem oop '(mpeep peep)) (aguard (aseq cl as))         ; reads: a guard, never a call-out
                    (: c2 (aseq cl as) (= c2 'bad ? 'bad 1))))))             ; a call: its args, then the call
       ok ((two? s) && (two? >s) && (all nom? ps) && (adistinct ps)
           && (a = #ps) && (0 < a) && lpok && drok && !(= lts 'bad) && (two? body)
           && (getenv "LOVE_AMBLE_NOCALL" ? !(ahascall? env go body) 1)                ; the call-lane bisect knob: splits the call machinery from the rest
           && (all lit? gvals) && (all lit? ovals) && (nd < 48) && ((k + #gn + #cn + nq + nin + nl + (fbk ? 1 0)) < 48)   ; slots are cheap once the prologue guards the room (below)
           && (all (i \ amble-ok? ps shd kn 0 0 0 i) inits)
           && (amble-ok? env shd kn go k 1 body)
           && !(= (asafe 1 (foldl (\ ac i (asafe 0 ac i)) 0 inits) body) 'bad))   ; the restart law, over the gated body
       (? ok
          (: _ (getenv "LOVE_AMBLE_TRACE" ? (puts ("amble: " + show s + "\n")) 0)   ; the compile trace: names every ambled source
             ng (1 + #gn + #cn + nq + (lit? eqv ? 1 0) + nin)   ; extras = [() | globals | sibling entries | quoted data | = | inner entries] (+ op values, chain-only):
                                                                ; () is the empty mint -- li 1 would be the charm 0-fossil -- and entries and
                                                                ; quotes are heap values, all riding the nifx chain into GC-walked slots
             R (k + 3 + ng + nd + nl + (fbk ? 1 0))         ; loopvars | Se | So | budget | extras | spills | lets | op value
             A (greg tgt 'acc)  T (greg tgt 'tmp)  X (greg tgt 'anchor)  SC (greg tgt 'scratch)
             SP (greg tgt 'sp)  IP (greg tgt 'ip)  HP (greg tgt 'hp)
             seo (8 * k)  soo (8 * (k + 1))  budo (8 * (k + 2))  gbo (8 * (k + 3))  spo (8 * (k + 3 + ng))  fro (8 * R)
             (voff v) (? (elem v vars) (8 * (posof v vars 0))  (elem v lts) (lvo v)  (fro + (8 * (posof v ps 0))))
             (spill d) (spo + (8 * d))
             eqo (gbo + (8 * (1 + #gn + #cn + nq)))   ; the = value's extras slot (past globals, siblings, quotes)
             ino (eqo + (8 * (lit? eqv ? 1 0)))                    ; the inner entries' slots (past =)
             ovo (8 * (k + 3 + ng + nd + nl))                       ; the one op-value slot, fallback mode only: a stub fills it off the chain
             (ovload o) ([['ld T SP budo]]                          ; the chain from the budget cell: ng copied links, then the op values
                         + ((: (go j) (j < (1 + ng + (posof o ovs 0)) ? (['ld T T 16] . go (j + 1)) ())) 0)
                         + [['ld X T 8] ['st SP ovo X]])
             lto (8 * (k + 3 + ng + nd))                    ; the let region, past the spills
             (lvo v) (lto + (8 * (posof v lts 0)))
             (fx2 lbl) [['mov X T] ['and X X A] ['test X 1] ['br 'eq lbl]]    ; both T and a fixnum, else lbl
             (abin sa sb d fin) ((acg sa d) + [['st SP (spill d) A]] + (acg sb (d + 1))
                                 + (fbk ? [['st SP (spill (d + 1)) A]] ()) + [['ld T SP (spill d)]] + fin)   ; T = a, A = b (b spilled too for a stub)
             (refb seq fb) (map (i \ map (x \ (= x 'deopt ? fb x)) i) seq)                        ; a sequence's deopts retargeted to a stub
             (fb2 op d fin) (? !fbk fin                                                            ; the two-operand stub: drive op's value over a (spill d) then b
                              (: fb (mint 0) en (mint 0)                                          ; (spill d+1), the partial rolling through spill d, answer in A
                                 ((refb fin fb) + [['jmp en] ['label fb]] + (ovload op) + [['ld A SP (spill d)]] + (adrive ovo)
                                  + [['st SP (spill d) A] ['ld A SP (spill (d + 1))]] + (adrive (spill d)) + [['label en]])))
             (fb1 op fin) (? !fbk fin                                                              ; the one-operand stub: A still holds the operand at the guard
                            (: fb (mint 0) en (mint 0)
                               ((refb fin fb) + [['jmp en] ['label fb]] + (ovload op) + (adrive ovo) + [['label en]])))
             (atruth _) (: fb (fbk ? (mint 0) 'deopt) tk (mint 0)                                     ; the truth guard and its stub: bit's value answers 0/1, back to the compare
                         [[['test A 1] ['br 'eq fb] ['label tk]]
                          (fbk ? ([['label fb]] + (ovload 'bit) + (adrive ovo) + [['jmp tk]]) ())])   ; ovload spares A
             (aar op sa sb d)
              (abin sa sb d (fb2 op d
               (op @ '+ ((fx2 'deopt) + [['sub A A 1] ['adds A A T] ['br 'vs 'deopt]])         ; 2y + (2x+1) = tag(x+y)
                    '- ((fx2 'deopt) + [['subs T T A] ['br 'vs 'deopt] ['lea A T 1]])          ; 2(x-y) then tag
                    ((fx2 'deopt) + [['sar A 1] ['sub T T 1] ['mulo A A T SC 'deopt] ['or A A 1]]))))   ; y * 2x = 2xy, where mulo is the tag-range gate, then tag
             (acmp2 op sa sb d) (abin sa sb d (fb2 op d ((fx2 'deopt) + [['cmp T A] ['set (ccof op) A] ['leax A A A 1 1]])))
             (adm op sa sb d) (abin sa sb d (fb2 op d                                             ; // %: untag, /-by-0 -> twin, divir (trunc toward zero), retag
              ((fx2 'deopt) + [['sar T 1] ['sar A 1]]                                              ; (the adds gate catches most-negative // -1)
               + (divc? sb ? (divk tgt op sb) ([['test A A] ['br 'eq 'deopt]] + (divir tgt op)))
               + [['adds A A A] ['br 'vs 'deopt] ['or A A 1]])))
             (abit op sa sb d) (abin sa sb d (fb2 op d                                            ; & | ride the tags whole (2x+1 op 2y+1 = tag(x op y)); ^ re-tags
              ((fx2 'deopt) + (= op '^ ? [['xor A A T] ['or A A 1]] [[(bitop op) A A T]]))))
             ; aeq2: the generic =, total and never a deopt. equal fixnums and the same point
             ; answer 1; distinct fixnums, and a point against anything else, answer 0, since a
             ; point equals only itself. everything structural -- strings, gems (the numeric
             ; bridges and NaN), bigs, lists -- drives the = value off its extras slot.
             (aeq2 sa sb d) (: ys (mint 0)  no (mint 0)  sl (mint 0)  dn (mint 0)  ne1 (mint 0)  et (mint 0)
              (abin sa sb d
               ([['cmp T A] ['br 'ne ne1]
                 ['test A 1] ['br 'ne ys]                                                          ; equal fixnums -> 1
                 ['ld X A 0] (jk tgt SC 3) ['cmp X SC] ['br 'eq ys]                              ; the same point -> 1
                 (jk tgt SC 4) ['cmp X SC] ['br 'eq ys] ['jmp sl]                                ; the same heap box: structural (NaN) -> drive
                 ['label ne1] ['test T 1] ['br 'eq et]
                 ['test A 1] ['br 'ne no]                                                          ; distinct fixnums -> 0
                 ['ld X A 0] (jk tgt SC 3) ['cmp X SC] ['br 'eq no]                              ; a point equals only itself -> 0
                 (jk tgt SC 4) ['cmp X SC] ['br 'eq no] ['jmp sl]
                 ['label et] ['ld X T 0] (jk tgt SC 3) ['cmp X SC] ['br 'eq no]
                 (jk tgt SC 4) ['cmp X SC] ['br 'eq no] ['jmp sl]
                 ['label ys] ['li A 3] ['jmp dn]
                 ['label no] ['li A 1] ['jmp dn]
                 ['label sl] ['st SP (spill (d + 1)) A] ['mov A T]]                              ; slow: spill b ; A = a
                + (adrive eqo)                                                                     ; A = (= a)
                + [['st SP (spill d) A] ['ld A SP (spill (d + 1))]]                              ; spill the partial ; A = b
                + (adrive (spill d))                                                               ; A = (= a b)
                + [['label dn]])))
             (aid sa sb d) (abin sa sb d [['cmp T A] ['set 'eq A] ['leax A A A 1 1]])                ; raw word identity: total, no guard
             (atwo sx d) (: ln (mint 0)
              ((acg sx d) + [['li T 1] ['test A 1] ['br 'ne ln]
                              ['ld X A 0] (jk tgt A 0) ['cmp X A] ['br 'ne ln]
                              ['li T 3] ['label ln] ['mov A T]]))
             (acap sx d off) ((acg sx d) + (fb1 (off = 8 ? 'cap 'cup)
                                            [['test A 1] ['br 'ne 'deopt]
                                             ['ld X A 0] (jk tgt T 0) ['cmp X T] ['br 'ne 'deopt]
                                             ['ld A A off]]))
             (alink sa sb d) (abin sa sb d (fb2 '. d                                                ; room for 3w + floor, else deopt (no GC mid-native) -- or the
                                             [['lea X HP 88] ['cmp SP X] ['br 'below 'deopt]         ; stub, whose cons collects
                                              (jk tgt X 0) ['st HP 0 X] ['st HP 8 T] ['st HP 16 A]
                                              ['mov A HP] ['add HP HP 24]]))
             (acq st sth sel d) (: le (mint 0)  ln (mint 0)  tr (atruth 0)
              ((acg st d) + <tr + [['cmp A 1] ['br 'le le]]                                       ; heap truth -> net -> twin, or the bit stub; tag(x)<=1 <=> x<=0
               + (acg sth d) + [['jmp ln]] + <>tr + [['label le]] + (acg sel d) + [['label ln]]))
             (aor as d) (: en (mint 0)                                                                      ; (|| a..): the first truthy value, single-eval, short-circuit --
              (((: (go l) (atom? >l ? (acg <l d)                                                 ; each arg lands in A; charm truth keeps it (heap truth -> the twin,
                             (: tr (atruth 0) nx (mint 0)                                                 ; acq's bet); the last arg is the value either way
                                ((acg <l d)
                                 + <tr + [['cmp A 1] ['br 'gt en]]
                                 + (fbk ? ([['jmp nx]] + <>tr + [['label nx]]) ())
                                 + (go >l))))) as)
               + [['label en]]))
             (adrive cso) (: bb (mint 0)                                                                    ; apply the value at Sp[cso] to the arg in A, via the walkable resume:
              [['st SP -32 A] ['ld T SP cso] ['st SP -24 T]                                         ; frame [arg, callee, tag(bb-entry0), entry0] -- an odd charm + an out-of-
                 ['lar T bb] ['lar X 'entry0] ['subs T T X] ['leax T T T 1 1]                       ; pool code base, so a GC with the call pending walks it clean (no retB)
                 ['st SP -16 T] ['st SP -8 X]
                 (jk tgt IP 8) ['sub SP SP 32] ['ld T IP 0] ['jmpr T]                  ; -> lvm_ap -> callee -> lvm_resume -> bb
                 ['label bb] ['ld A SP 0] ['add SP SP 8]])                                            ; resume: result at Sp[0], pop it
             (achain as cso d) (atom? >as
                                  ? ((acg <as d) + (adrive cso))
                                    ((acg <as d) + (adrive cso) + [['st SP (spill d) A]]
                                     + (achain >as (spill d) (d + 1))))                                ; partial -> spill -> next arg (currying)
             ; asite: an inner lambda (amble-lam i n v..) -- entry i of arity n, curried through the
             ; imports v.. -- is the closure lz's site builds: lvm_cur's own partial cells laid
             ; straight onto the heap under one room guard, [cur n-1 unc arg cont tag] while the
             ; rest still curries and [unc arg cont tag] for the last, where cont is the callee
             ; cell + 2 and tag the cell's address | 2. a fresh chain per evaluation; a closed
             ; lambda is its cell.
             (asite as d) (: so (ino + (8 * <as))  n <>as  vs >>as
                             (acur v a) (a > 2 ?
                                           [(jk tgt X 9) ['st HP 0 X] ['li X ((2 * a) - 1)] ['st HP 8 X]
                                            (jk tgt X 10) ['st HP 16 X] ['ld X SP (voff v)] ['st HP 24 X] ['lea X T 16] ['st HP 32 X]
                                            ['mov X HP] ['or X X 2] ['st HP 40 X] ['mov T HP] ['add HP HP 48]]
                                           [(jk tgt X 10) ['st HP 0 X] ['ld X SP (voff v)] ['st HP 8 X] ['lea X T 16] ['st HP 16 X]
                                            ['mov X HP] ['or X X 2] ['st HP 24 X] ['mov T HP] ['add HP HP 32]])
                             (gov l a) (two? l ? ((acur <l a) + (gov >l (a - 1))) ())
                             (two? vs ?
                                ([['lea X HP (64 + (48 * #vs))] ['cmp SP X] ['br 'below 'deopt] ['ld T SP so]]
                                 + (gov vs n) + [['mov A T]])
                                [['ld A SP so]]))
             (astr1 cso) (: ld (mint 0) ok (mint 0) en (mint 0)                                             ; the string fast lane at a 1-arg frame-callee site: (s i) with s a
              ([['ld T SP cso] ['test T 1] ['br 'ne ld]                                             ; text and i a charm is a byte index: in range, the unsigned byte,
                  ['ld X T 0] (jk tgt SC 1) ['cmp X SC] ['br 'ne ld]                             ; native. everything else falls to the drive (never a deopt -- a
                  ['test A 1] ['br 'eq ld]                                                              ; mixed-type call site keeps its closure speed): another callee or
                  ['mov X A] ['sar X 1] ['ld SC T 8]                                                  ; index kind, and -- since the one unsigned compare wraps a negative
                  ['cmp X SC] ['br 'below ok]                                                           ; huge -- every index out of range, negative or past the end, alike. so
                  ['jmp ld]                                                                             ; the lane answers what C answers, at the cost of driving one.
                  ['label ok] ['ldxb A T X 1 16] ['leax A A A 1 1]
                  ['jmp en] ['label ld]]
               + (adrive cso)
               + [['label en]]))
             (atally sx d) (: ld (mint 0) en (mint 0)                                                       ; (tally X) with X a text: A = tag(len at [X+8]); anything else
              ((acg sx d)                                                                                   ; drives the tally global through its gn slot (a chain tally is a
               + [['test A 1] ['br 'ne ld]                                                            ; walk -- C's, not a deopt storm)
                    ['ld X A 0] (jk tgt SC 1) ['cmp X SC] ['br 'ne ld]
                    ['ld X A 8] ['leax A X X 1 1] ['jmp en]
                    ['label ld]]
               + (adrive (gbo + (8 * (1 + (posof 'tally gn 0)))))
               + [['label en]]))
             ; asat: a saturated n-ary call site (n >= 2). if the callee is a cur cell of arity
             ; exactly n (bytecode closures, natives, and the nifs share the [cur arity body..]
             ; layout), lay the apn frame [args cont tag base] and enter its body at cell+2
             ; directly -- one call, no curry chain, no partials. any other callee -- a partial,
             ; an over-application, arity 1, data -- takes the drive chain over the same spilled
             ; args (evaluated once, either way).
             (asat as cso d) (: bb (mint 0)  sw (mint 0)  dn (mint 0)  n #as  w (n + 3)
              ((agous as 0 d)
               + [['ld X SP cso] ['test X 1] ['br 'ne sw]
                  ['ld T X 0] (jk tgt SC 9) ['cmp T SC] ['br 'ne sw]                               ; entry = lvm_cur?
                  ['ld T X 8] ['cmp T ((2 * n) + 1)] ['br 'ne sw]]                                 ; arity = n?
               + (: (gsl j) (j < n ? ([['ld A SP (spill (d + j))] ['st SP ((8 * j) - (8 * w)) A]] + (gsl (j + 1))) ()) (gsl 0))
               + [(jk tgt T 8) ['add T T 8] ['st SP ((8 * n) - (8 * w)) T]                         ; cont = &resume[1]
                  ['lar T bb] ['lar A 'entry0] ['subs T T A] ['leax T T T 1 1] ['st SP ((8 * (n + 1)) - (8 * w)) T]
                  ['st SP ((8 * (n + 2)) - (8 * w)) A]
                  ['lea IP X 16] ['sub SP SP (8 * w)] ['ld T IP 0] ['jmpr T]                      ; enter the body at cell+2
                  ['label bb] ['ld A SP 0] ['add SP SP 8] ['jmp dn]
                  ['label sw]]
               + (: (goj j so) (j < n ?                                                            ; the chain, from the spills: each partial rolls through spill d
                                  ([['ld A SP (spill (d + j))]] + (adrive so)
                                   + (j < (n - 1) ? [['st SP (spill d) A]] ())
                                   + (goj (j + 1) (spill d)))
                                  ()) (goj 0 cso))
               + [['label dn]]))
             ; a 1-arg frame callee can be a string at run time (the lexer class), so the string
             ; fast lane rides looping bodies only -- named-let or self-call, the same cost gate as
             ; gn -- since on a one-shot recursion wrapper it taxed every drive. a gn or sibling
             ; callee is never a string (lit?-gated, or a woven entry), so those keep the bare drive.
             (acall f as d)
              (? (= f self)                                                                               ; self: saturated -> the direct frame jump; partial or over-applied ->
                 (#as = (a - ni) ?                                                                  ; curry the own cell through its imports, then the args (a saturated
                    (aselfcall as d)                                                                        ; tail self-call took sgo instead)
                    (achain (simp + as) soo d))
                 (elem f cn)                                                                             ; a sibling: its frozen entry takes the import names (all in the frame
                 (: sas ((cimp f) + as)  sso (gbo + (8 * (1 + #gn + (posof f cn 0))))            ; by fixcaps) then the args -- lz's site, saturated when it can be
                    (two? >sas ? (asat sas sso d) (achain sas sso d)))
                 (: fr  (elem f vars || elem f ps || elem f lts)                           ; f in the frame, else a gn slot
                    cso (fr ? (voff f) (gbo + (8 * (1 + (posof f gn 0)))))
                    (? ((lp ? 1 sfq) && atom? >as && fr) ((acg <as d) + (astr1 cso))
                       (two? >as) (asat as cso d)                                                      ; multi-arg saturates when the callee's arity agrees
                       (achain as cso d))))
             (agous us j d) (two? us ? ((acg <us (d + j)) + [['st SP (spill (d + j)) A]] + (agous >us (j + 1) d)) ())
             (agomv j d) (j < 0 ? () ([['ld A SP (spill (d + j))] ['st SP (8 * j) A]] + (agomv (j - 1) d)))
             (ago as d) ((agous as 0 d) + (agomv (k - 1) d) + [['jmp 'top]])                            ; updates from the old vars (spilled first), then the back-edge
             (asmv j d) (j < 0 ? () ([['ld A SP (spill (d + j))] ['st SP (fro + (8 * (ni + j))) A]] + (asmv (j - 1) d)))
             ; aselfcall: a saturated non-tail self-call jumps the blob's own entry directly, on the
             ; frame [imports.. args.. resume tag(bb-entry0) entry0] under Sp with Ip restored off
             ; So, and the callee's hand-rolled ret returns through lvm_resume to bb. no drive, no
             ; curry chain, no partials; the entry's room and budget guards run per level.
             (aselfcall as d) (: bb (mint 0)  w (a + 3)
              ((agous as 0 d)
               + (: (gimp l i) (two? l ? ([['ld T SP (voff <l)] ['st SP ((8 * i) - (8 * w)) T]] + (gimp >l (i + 1))) ()) (gimp simp 0))
               + (: (garg j) (j < (a - ni) ? ([['ld T SP (spill (d + j))] ['st SP ((8 * (ni + j)) - (8 * w)) T]] + (garg (j + 1))) ()) (garg 0))
               + [(jk tgt T 8) ['add T T 8] ['st SP ((8 * a) - (8 * w)) T]                          ; cont = &resume[1]: ret jumps the cell's word 0 = lvm_resume
                  ['lar T bb] ['lar X 'entry0] ['subs T T X] ['leax T T T 1 1] ['st SP ((8 * (a + 1)) - (8 * w)) T]
                  ['st SP ((8 * (a + 2)) - (8 * w)) X]
                  ['ld IP SP soo]]
               + (a = 1 ? () [['add IP IP 16]])
               + [['sub SP SP (8 * w)] ['jmp 'entry0]
                  ['label bb] ['ld A SP 0] ['add SP SP 8]]))
             (aselfgo as d) ((agous as 0 d) + (asmv (a - ni - 1) d) + [['jmp 'sgo]])               ; saturated tail self-call: new args (spilled first) over the arg slots (imports keep), jump the body top
             (acqt st sth sel d) (: le (mint 0)  ln (mint 0)  tr (atruth 0)                          ; acq, tails threaded
              ((acg st d) + <tr + [['cmp A 1] ['br 'le le]]
               + (acgt sth d) + [['jmp ln]] + <>tr + [['label le]] + (acgt sel d) + [['label ln]]))
             (acgt e d)                                                                             ; tail-position acg: thread tails through ? and let bodies so a saturated self-call jumps
              (? (aquote? e) (acg e d)
                 (atom? e) (acg e d)
                 (: op <e  as >e
                    (? (= op '?) (acqt <as <>as <>>as d)
                       (= op ':) ((: (gol l) (atom? >l ? (acgt <l d)
                                                  ((acg <>l d)
                                                   + (= <l '_ ? () [['st SP (lvo <l) A]])
                                                   + (gol >>l)))) as)
                       (sfq && (= op self) && (#as = (a - ni))) (aselfgo as d)
                       (acg e d))))
             (acg e d)
              (? (nom? e) [['ld A SP (voff e)]]
                 (whole? e) [['li A ((2 * e) + 1)]]
                 (= e amble-nil) [['ld A SP gbo]]
                 (nom? e) [['ld A SP (voff e)]]
                 (aquote? e) [['ld A SP (gbo + (8 * (1 + #gn + #cn + (aposq e qs 0))))]]   ; a quoted datum: its extras slot (past the globals + sibling entries)
                 (: op <e  as >e  oop (elem op shd ? 0 op)
                    (? (= op ':) ((: (gol l) (atom? >l ? (acg <l d)                            ; a value let: each binding lands in its slot, in order
                                                  ((acg <>l d)
                                                   + (= <l '_ ? () [['st SP (lvo <l) A]])
                                                   + (gol >>l)))) as)
                       (= op '?) (acq <as <>as <>>as d)
                       (= oop 'two?) (atwo <as d)
                       (= oop 'cap) (acap <as d 8)
                       (= oop 'cup) (acap <as d 16)
                       (= oop '==) (aid <as <>as d)
                       (= oop '.) (alink <as <>as d)
                       (= oop '= && (aqnom? <as || aqnom? <>as))
                        (aid <as <>as d)                                               ; (a = 'sym): a point equals only itself (the point-= law) -> raw identity, total
                       (= oop '= && (lit? eqv)) (aeq2 <as <>as d)
                       (acmp? oop) (acmp2 op <as <>as d)
                       (elem oop '(+ - *)) (aar op <as <>as d)
                       (elem oop '(// %)) (adm op <as <>as d)
                       (elem oop '(& | ^)) (abit op <as <>as d)
                       (= oop 'tally && elem 'tally gn && atom? >as)
                        (atally <as d)                                       ; the tally fast lane (a taken name or multi-arg falls to the call paths)
                       (= oop '|| && two? >as) (aor as d)
                       (= op amble-lam) (asite as d)
                       (= op go) (ago as d)
                       (acall op as d))))
             initR (: (goi j) (j < R ? ([['st SP (8 * j) T]] + (goi (j + 1))) ())
                      ([['li T 1]] + (goi 0)))                                                          ; every reserved slot a valid value before any call (GC walks them)
             unpk ([['ld T IP 8] ['st SP seo T]]                                                  ; Se = value[1] = e (plain -- image-revert-clean)
                   + (a = 1 ? [['st SP soo IP]] [['mov T IP] ['sub T T 16] ['st SP soo T]])     ; So = the own cell (= Ip, or Ip-16 past the cur pair) -- the self-drive callee
                   + [['ld T IP 32]                                                               ; T = the nifx extras chain
                       ['st SP budo T] ['ld T T 16]]                                                    ; link 0 = the budget cell (saved for the deopt decrement), slots after it
                   + (: (gou j) (j < ng ? ([['ld X T 8] ['st SP (gbo + (8 * j)) X] ['ld T T 16]] + (gou (j + 1))) ()) (gou 0)))
             initsir (: (goj is j) (two? is ? ((acg <is 0) + [['st SP (8 * j) A]] + (goj >is (j + 1))) ())
                        (goj inits 0))
             bodyir ((sfq ? ['(label sgo)] ())                                                     ; the self-jump landing: a fresh invocation on the rewritten frame
                     + (lp ? (initsir + ['(label top)] + (acgt body 0)) (acgt body 0)))   ; body = GB or M, desugared -- never the raw forms
             epi [['add SP SP fro] ['st SP 0 A]                                                       ; hand-rolled lvm_ret (a drive call clobbered Ip)
                    ['ld IP SP (8 * a)] ['st SP (8 * a) A] ['add SP SP (8 * a)]
                    ['ld T IP 0] ['jmpr T]]
             dpt (['(label deopt)
                      ['ld X SP budo] ['ld SC X 8] ['sub SC SC 2] ['st X 8 SC]                      ; budget -= 1 (tagged: 2k+1 - 2): a restart is the profitability signal
                      ['ld T SP seo] ['add SP SP fro]]                                                  ; (d0 room-guard entries never count); twin from its slot before the restore
                  + (a = 1 ? [['mov IP T]] [['lea IP T 16]])                                      ; a=1: re-apply e; else enter e's body on the saturated frame
                  + [['ld T IP 0] ['jmpr T]])
             prog (['(label entry0)                                                                       ; entry0 = the resume-offset anchor (any shared label works; the blob's first byte)
                      ['lea X HP (40 + (8 * (R + 4 + (amax a nd))))] ['cmp SP X] ['br 'below 'd0]    ; room guard: the reservation + the widest call frame (nd bounds any site's arg count) + floor must fit Sp-Hp,
                      ['ld T IP 32] ['ld X T 8] ['cmp X 1] ['br 'le 'd0]                            ; the deopt budget (extras link 0, a charm): spent -> the native is
                      ['sub SP SP fro]]                                                                   ; retired, every call takes d0 straight to the twin (frame untouched
                                                                                                            ; -> the twin runs it whole; a perma-deopting native heals to bytecode)
                   + initR + unpk + bodyir + epi + dpt
                   + ['(label d0) ['ld T IP 8]] + (a = 1 ? [['mov IP T]] [['lea IP T 16]]) + [['ld T IP 0] ['jmpr T]])
             (nifx (emit (asmt tgt prog)) e s a (8 . (amble-nil . gvals + cvals + (map (q \ <>q) qs) + (lit? eqv ? [eqv] ()) + ins + ovals))))
          0))
   ; --- the general tail-recursive counted loop, n loop vars ------------------------------------
   ; (\ n ((: (go v0..vk) (? TEST (go U0..Uk) RESULT)) I0..Ik)), up to 3 loop vars in the loopregs
   ; bank raw, the param n the tagged Sp[0]. each iteration computes every Uj from the old regs --
   ; push all, then pop into the regs in reverse -- so the updates read pre-update values, as fib's
   ; `b` and `a+b` must. the loop regs survive the expr scratch, so nothing is saved.
   (lvreg tgt j) ((loopregs tgt) j)               ; loop var j -> its abstract register
   (loopcode-n n vars updates test result inits tgt)
    ; nvld loads a var: n from Sp[0] (fxvir, guarded), a loop var from its register. control flow,
    ; the per-depth deopt and the putfix epilogue are all label-resolved.
    (: A (greg tgt 'acc)
       nvld (\ e d (? (e = n) (fxvir tgt 0 d)
                       (elem e vars) [['mov A (lvreg tgt (argix e vars 0))]]
                       ()))
       pre  ((: (go j is) (two? is ? ([['li (lvreg tgt j) <is]] + (go (j + 1) >is)) ())) 0 inits)        ; reg-init
       ups  ((: (go j us) (two? us ? ((cgvir tgt nvld <us j) + [['push A]] + (go (j + 1) >us)) ())) 0 updates)   ; push Uj at depth j
       pops ((: (go j) (j < 0 ? () ([['pop (lvreg tgt j)]] + (go (j - 1))))) (#updates - 1))                ; pop reg(k-1)..reg(0)
       tb   (cgvir tgt nvld test 0)
       rb   (cgvir tgt nvld result 0)
       (asmt tgt (pre + '((label top))
              + tb + [['cmp A 0] '(br eq end)]           ; <test>; acc==0 (false) -> end
              + ups + pops + '((jmp top) (label end))      ; updates ; loop top
              + rb + (loopepi tgt))))                      ; result -> acc ; putfix + Continue
   ; (jitloop-n lam vars updates test result inits) -- a general N-var loop -> native (x86 self-test helper).
   (jitloop-n lam vars updates test result inits)
    (nif (emit (loopcode-n <>lam vars updates test result inits 'x64)) (ev lam) lam 1)
   ; --- the float lane: unboxed doubles in xmm/d --------------------------------------------------
   ; float values stay in registers, never boxed. f0 is the accumulator and a nested operand spills
   ; to the machine stack. peek is mopped, so a float constant is materialized arithmetically:
   ; fbits computes its IEEE-754 bits, and the 52-bit mantissa makes frac*2^52 exact.
   ; lane law: the float lane carries no overflow guard, since doubles saturate to inf and never
   ; promote to a bignum; only the integer lane keeps the deopt that preserves bignum promotion.
   ; a float predicate leaf over a fixnum arg answers 0/1 here; a float result is jitfr below.
   ; a gem arg would want the lvm_gembox type guard, so a non-fixnum arg deopts instead.
   (fbits x)                                                          ; a finite double -> its IEEE-754 u64 bits
    (x = 0.0 ? 0
       (: s (x < 0.0 ? 1 0) ax (x < 0.0 ? (0.0 - x) x)
          eu ((: (go e) (((e + 1) 2.0) <= ax ? (go (e + 1)) e)) (int ((log ax) / (log 2.0))))   ; raise past the log's error
          e  ((: (go e) (ax < (e 2.0) ? (go (e - 1)) e)) eu)                                    ; then lower; (e 2.0) is the tower, 2.0 ** e
          ((s * 9223372036854775808) + ((e + 1023) * 4503599627370496) + (int (((ax / (e 2.0)) - 1.0) * 4503599627370496.0)))))
   ; the float spill rides the machine stack at the loop/group slot size (x86 8 / a64 16, for sp
   ; alignment), so a mid-nest deopt (deoptbody, slotsz*d) unwinds it correctly.
   (xpushir tgt) [['sub 'sp 'sp (slotsz tgt)] '(stsd sp 0 f0)]   ; spill xmm0/d0 -> [sp]
   (xpop1ir tgt) ['(ldsd f1 sp 0) ['add 'sp 'sp (slotsz tgt)]]   ; reload [sp] -> xmm1/d1
   (fconst tgt c) (: A (greg tgt 'acc) [['li A (fbits c)] ['movqxr 'f0 A]])   ; bits -> GPR ; GPR -> xmm0 (movq / fmov)
   (fbinop op) (op @ '+ '((addsd f0 f1))                       ; f0 = f0 + f1
                     '* '((mulsd f0 f1))                       ; f0 = f0 * f1
                     '- '((subsd f1 f0) (movsd f0 f1))         ; f1 = f1 - f0 ; f0 = f1
                     '/ '((divsd f1 f0) (movsd f0 f1))         ; f1 = f1 / f0 ; f0 = f1
                     ())                                       ; two-address reg-reg double IR, both targets
   ; cgf: a float subexpr over the fixnum param (cvtsi2sd) and numeric consts -> f0, as neutral IR.
   ; the param load is fxvir, fixnum-guarded with an inline deopt, then int->double.
   (cgf tgt v e d) (? (e = v)   ((fxvir tgt 0 d) + [['cvtsi2sd 'f0 (greg tgt 'acc)]])   ; param: fixnum-guarded untag in acc, cvtsi2sd
                  (gem? e)  (fconst tgt e)                           ; a float constant
                  (whole? e)(fconst tgt (e + 0.0))                   ; an int constant -> promote to double
                  (e @ (op a b)
                       (elem op '(+ - * /)
                        && ((cgf tgt v a d) + (xpushir tgt) + (cgf tgt v b (d + 1)) + (xpop1ir tgt) + (fbinop op)))
                       ()))
   ; cgfp: a float predicate (cmp A B) -> acc 0/1 (a to f1, B to f0, ucomisd then set). x86-only, since
   ; the ucomisd-flag conditions are x86 unsigned cc; jitf, its sole caller, is an x86 self-test helper.
   (cgfp tgt v e d) (: op <e a <>e b <>>e
      cc (op @ '< 'below  '<= 'be  '> 'above  '>= 'ae  'eq)
      ((cgf tgt v a d) + (xpushir tgt) + (cgf tgt v b (d + 1)) + (xpop1ir tgt) + '((ucomisd f1 f0)) + [['set cc (greg tgt 'acc)]]))   ; ucomisd xmm1,xmm0 ; acc = (cc) ? 1 : 0
   ; (jitf '(\ x (cmp <fexpr> <fexpr>))) -- a float predicate over a fixnum arg -> native 0/1 (x86 helper).
   (jitf lam) (: v <>lam (nif (emit (asmx ((cgfp 'x64 v <>>lam 0) + (loopepi 'x64)))) (ev lam) lam 1))
   ; --- heap result (the deferred "Have-checked box"): (jitfr '(\ x <fexpr>)) returns a gem, not 0/1.
   ; the lane never allocates because it can't GC (its raw regs aren't roots) -- so it does the alloc
   ; twin of the overflow guard: a room guard (Sp - Hp >= gem_req+floor words) deopts to interp when
   ; the heap is too full to fit the box, exactly as `jo` deopts when a fixnum result leaves range.
   ; fast path (room proven): write [Hp]=lvm_gembox (the jk gem slot, read off g like the
   ; string guard), the double at [Hp+8] with NaN->0 (mk_gem's law), return Hp untagged (an even heap
   ; ptr is the gem), bump Hp by gem_req. the epilogue stores the pointer (NO putfix) and threads the
   ; advanced Hp on through Continue, so the box is live to the next op and the GC at the next safepoint.
   ; nanc: NaN -> 0.0 in f0 (mk_gem's law). x86: ucomisd xmm0,xmm0 ; jnp +4 ; xorpd (the parity cc +
   ; self-jump as a raw blob). a64: fcmp d0,d0 ; b.vc ok ; (d0 <- 0) ; ok -- unordered sets V, so vc
   ; skips when not-NaN; zero via a GPR 0 moved into d0.
   (nanc tgt) (= tgt 'x64 ? [['raw '(102 15 46 192  123 4  102 15 87 192)]]
                 (: A (greg tgt 'acc) ok (mint 0)
                    (['(ucomisd f0 f0) ['br 'vc ok]] + [['li A 0] ['movqxr 'f0 A]] + [['label ok]])))
   (jitfr lam tgt) (jitfrx lam tgt (ev lam))                        ; 2-arg public: bakes the interpreter deopt (auto-ev + the glaze-x86 tests)
   ; jitfrx: the deopt-parameterized core. auto-ev/tests reach it through jitfr ((ev lam)); the natjit
   ; creation hook (the hook half below) calls it directly with `e`, the bytecode twin ala already built --
   ; re-interpreting lam there would re-enter ala -> natjit -> ... (the leaf lane's `e`-deopt law).
   (jitfrx lam tgt interp)
    (: v <>lam
       A (greg tgt 'acc) S (greg tgt 'sp) HP (greg tgt 'hp) IP (greg tgt 'ip) T (greg tgt 'tmp) ok (mint 0)
       ; neutral l/holo/ IR (both targets): the room-guard skips the deopt by label; the box store is `stsd`;
       ; the deopt is deoptbody (no pending spills here -- cgf balances its own); nanc is arch-aware.
       (nif (emit (asmt tgt ((cgf tgt v <>>lam 0)
          + [['lea A HP 80] ['cmp S A] ['br 'ae ok]]                  ; cmp Sp,Hp+10w ; room? skip deopt
          + (deoptbody tgt 0) + [['label ok]] + (nanc tgt)             ; heap-full -> deopt ; NaN -> 0.0
          + [(jk tgt T 5) ['st HP 0 T]                                  ; [Hp] = lvm_gembox (box header)
              ['stsd HP 8 'f0]                                           ; [Hp+8] = the double
              ['mov A HP] ['add HP HP 16]                               ; acc = Hp (the gem ptr) ; Hp += 16
              ['st S 0 A] ['add IP IP 16] ['ld T IP 0] ['jmpr T]])))   ; [Sp] = gem ; Continue (NO putfix: acc IS the gem)
        interp lam 1))
   (clook k ce) (? (atom? ce) () (k = <<ce) <ce (clook k >ce))   ; counter env: name -> (name regbytes); cgFd/rgof read it
   ; constant hoisting: peek is mopped, so materializing a float constant costs a movabs + movq,
   ; and re-emitting that inside a loop body dominates. so the kernel's distinct float constants
   ; preload into f2..f7 once before the loops (f0/f1 are scratch, f8.. are locals) and the body
   ; references the register. past 6 distinct constants the rest fall back to inline fconst.
   (memv? v l) (? (atom? l) 0 (v = <l) 1 (memv? v >l))
   (fcc e acc) (? (gem? e) (memv? e acc ? acc (e . acc))                    ; collect the distinct constants of e
                  (whole? e) (: v (e + 0.0) (memv? v acc ? acc (v . acc)))
                  (two? e) (fcc <>>e (fcc <>e acc))
                  acc)
   (fccl es acc) (two? es ? (fccl >es (fcc <es acc)) acc)            ; ... over a list of exprs
   (htbl cs i) (? (atom? cs) () (i > 7) () ([<cs i] . htbl >cs (i + 1)))   ; value -> reg (2..7)
   (hlook v ht) (? (atom? ht) -1 (v = <<ht) <><ht (hlook v >ht))
   (hcon tgt v ht) (: r (hlook v ht) (-1 < r ? [['movsd 'f0 (fr r)]] (fconst tgt v)))   ; the hoisted const's reg -> f0, else an inline fconst
   ; the optimizing float-body allocator: a value-numbered DAG (CSE) plus linear-scan allocation.
   ; it compiles a set of root exprs -- the inner-loop mag and the fvar updates, which share
   ; subexprs like zx*zx -- to register-only code, each value in its own xmm so the CPU runs
   ; independent ops in parallel. leaves (fvars, consts) live in fixed regs from env; binop results
   ; allocate from the working pool, are freed at last use, and are reused in place where an
   ; operand dies.
   (snoc l x) (l + (list x))
   (dfind nd dag i) (? (atom? dag) -1 (nd = <dag) i (dfind nd >dag (i + 1)))   ; cse: an existing node?
   (dadd nd dag) (: i (dfind nd dag 0) (-1 < i ? [i dag] [#dag (snoc dag nd)]))
   (vnum e dag) (two? e ? (: ra (vnum <>e dag) rb (vnum <>>e <>ra)
                             (dadd [<e <ra <rb] <>rb))            ; a binop: (op vn-a vn-b)
                          (dadd ['L e 0] dag))                    ; a leaf: (L datum 0)
   (vnall rs dag acc) (two? rs ? (: r (vnum <rs dag) (vnall >rs <>r (snoc acc <r))) [acc dag])
   (binop? dag v) !(= <(dag v) 'L)
   (luse v dag rv n) ((: (go i ds best) (? (atom? ds) (elem v rv ? n best)         ; the last index using v (roots live to n)
       (go (i + 1) >ds (binop? dag i && (v = <><ds || v = <>><ds) ? i best)))) 0 dag -1)
   (dies? v i dag rv n) (binop? dag v && ((luse v dag rv n) = i && !(elem v rv)))
   (rgof leaf env) (: e (clook leaf env) (two? e ? <>e (scare 'glaze-leaf leaf)))   ; a leaf -> its fixed reg
   (bcat ps) (foldl (\ a b (a + b)) () ps)                                          ; concat a list of IR pieces
   (efold names i) (two? names ? ([<names i] . efold >names (i + 1)) ())   ; names -> (name reg) from reg i
   ; --- the nested grid owner, D-dimensional -----------------------------------------------------
   ; own a whole counted-loop nest as one native kernel: D nested integer loops over fixnum coords,
   ; M derived-float invariants per cell, then a float recurrence over N float-vars accumulating an
   ; integer count -- one boundary crossing per grid rather than one per cell. mandelbrot's 64x64
   ; grid is the D=2, M=2, N=2 instance; any D>=1 and any M+N<=6 fits.
   ; registers: counters r10.., invariants f8.., fvars next, hoisted consts f2..f7, and the inner
   ; recurrence's working pool is the leftover xmm. on x86 r12.. are callee-saved (D>=3) and the
   ; acc-overflow deopt restores them. the acc add is guarded by the lane law -- overflow deopts to
   ; the interp nest and promotes -- where counters and the float lane need no guard. arity 1, with
   ; a dummy arg ignored, and an integer checksum out.
   (rangeL a b) (a < b ? (a . rangeL (a + 1) b) ())
   (map2 f a b) (two? a ? (f <a <b . map2 f >a >b) ())
   ; cgFd: a derive expr over the counter env ce (loop counters -> cvtsi2sd, the IR carried by cenv)
   ; and the hoisted consts, on [sp] scratch so it never touches an f8.. local. cold, once per cell.
   (cgFd tgt ht ce e) (? (gem? e)   (hcon tgt e ht)
                     (whole? e) (hcon tgt (e + 0.0) ht)
                     (atom? e)  (: cb (clook e ce) (two? cb ? <>cb ()))           ; a counter -> its (cvtsi2sd f0 cntr) IR
                     (e @ (op a b)
                          (elem op '(+ - * /)
                           && ((cgFd tgt ht ce a) + (xpushir tgt) + (cgFd tgt ht ce b) + (xpop1ir tgt) + (fbinop op)))
                          ()))
   (loopcode-gridn dims cnames invs invd fvars updates testexpr cmpop bound lim tgt)
    ; the scalar D-dim kernel as one neutral IR program, both targets: control flow is labels, the
    ; recurrence is allocp's cse'd scalar-double forms, the cold derives are IR too.
    ; k=r7, acc=r8, counters r9.. through gr; f2..=consts, f8..=invariants, fvars next, rest the
    ; DAG pool. x86 D>=3 spills the callee-saved counters; on a64 the counters are caller-saved.
    (: D #dims  M #invs  N #fvars  SCR (greg tgt 'acc)    ; scr: integer scratch (the fbits load + the result)
       cregs (rangeL 10 (10 + D))                                             ; counter regs (phys r10..), outer->inner
       saved (= tgt 'x64 ? (rangeL 12 (10 + D)) ())                       ; x86 r12.. callee-saved (D>=3); a64's counters are caller-saved
       fenv (invs + fvars)
       cenv (map2 (\ nm r [nm [['cvtsi2sd 'f0 (gr r)]]]) cnames cregs)    ; counter name -> its (cvtsi2sd f0 cntr) IR (cgFd reads it)
       ht (htbl (fcc bound (fccl invd (fccl updates (fcc testexpr ())))) 2)   ; distinct consts -> xmm2..7
       derives (foldl (\ a p (a + (cgFd tgt ht cenv >p) + [['movsd (fr (8 + <p)) 'f0]])) () (map2 (\ i d (i . d)) (rangeL 0 M) invd))   ; inv i -> xmm(8+i)
       zerof (foldl (\ a j (a + [['xorpd (fr (8 + M + j)) (fr (8 + M + j))]])) () (rangeL 0 N))   ; fvar j -> xmm(8+M+j) = 0
       aenv ((efold fenv 8) + ht)
       pool ([0 1] + (rangeL (8 + M + N) 16))
       AR (vnall (testexpr . updates) () ())  rootv <AR  dag <>AR  nn #dag
       AL (allocp dag rootv aenv nn pool 'movsd sseops)  bodyc <AL  rg <>AL
       magr (peep rg <rootv 0)  breg (fr (hlook bound ht))
       wb (foldl (\ a j (a + [['movsd (fr (8 + M + j)) (fr (peep rg (rootv (1 + j)) 0))]])) () (rangeL 0 N))   ; fvar <- its update's reg
       iter (['(label itop) ['cmp 'r7 lim] '(br ge iesc)]                   ; while k<lim and (cmp mag bound)
             + bodyc + [['ucomisd (fr magr) breg] ['br (ucmpx cmpop) 'iesc]]
             + wb + '((inc r7) (jmp itop) (label iesc)))
       popsv (foldl (\ a r (a + [['pop (gr r)]])) () (rev saved))           ; x86 D>=3: restore callee-saved counters before deopt
       accb (['(adds r8 r8 r7) '(br vc cont)] + popsv + (deoptbody tgt 0) + '((label cont)))   ; escape: acc += k ; overflow -> deopt
       cell (derives + zerof + '((li r7 0)) + iter + accb)                    ; derive invariants; zero fvars; k=0; recur; acc += k
       (loop-nest ci body) (: cr (gr (cregs ci))  b (dims ci)                 ; counted loops outer->inner, single-step
          tp (intern ("lt" + (show ci)))  en (intern ("le" + (show ci)))
          inner (ci = (D - 1) ? body (loop-nest (ci + 1) body))
          ([['li cr 0] ['label tp] ['cmp cr b] ['br 'ge en]] + inner + [['inc cr] ['jmp tp] ['label en]]))
       pushsv (foldl (\ a r (a + [['push (gr r)]])) () saved)
       popsv2 (foldl (\ a r (a + [['pop (gr r)]])) () (rev saved))
       preload (foldl (\ a e (a + [['li SCR (fbits <e)] ['movqxr (fr <>e) SCR]])) () ht)   ; load each const
       (pushsv + preload + '((li r8 0)) + (loop-nest 0 cell) + popsv2 + [['mov SCR 'r8]]))   ; push saved; consts; acc=0; the nest; pop; result -> scr
   ; --- the 2-wide packed grid kernel ------------------------------------------------------------
   ; the same D-dim float-recurrence grid, but the innermost dim runs two cells at a time: lanes
   ; [c, c+1] packed [low, high] in each xmm, the recurrence packed, so both pixels advance per op
   ; and the two independent chains hide the mul latency the scalar kernel's serial z is bound by.
   ; the escape test becomes a per-lane mask anded into a sticky `alive`, and the per-lane count is
   ; a packed-int vector bumped by `psubq count,alive` -- an alive lane is all-ones = -1, so
   ; subtracting it adds 1. the loop runs while any lane is alive and k < lim, and is bit-exact vs
   ; the scalar interp: identical IEEE per-lane ops, the same count until first escape, capped.
   ; grid2-ok? gates the shape: D<=2, M+N<=4 (invs and fvars at f8..f11), at most 2 inner consts
   ; (f2,f3, leaving f4,f5,f6 for count/alive/scratch), cmpop in {< <=}, an even innermost dim.
   ; sse2, so x86-64 only.
   (fr n)   (intern ("f" + (show n)))                                                    ; an xmm number -> its IR symbol f0..f15
   (gr p)   (intern ("r" + (show (p - 1))))                                              ; a physical GPR encoding (>=8) -> its abstract-file IR name (r10 -> r9 ..)
   (sseop op)  (op @ '+ 'addpd  '* 'mulpd  '- 'subpd  '/ 'divpd  'movupd)   ; a DAG op -> its packed-double mnemonic (grid2)
   (sseops op) (op @ '+ 'addsd  '* 'mulsd  '- 'subsd  '/ 'divsd  'movsd)    ; ... its scalar-double mnemonic (gridn)
   (ucmpx op) (op @ '<= 'above  '< 'ae  '>= 'be  '> 'below  ())             ; the exit cc after ucomisd: the inverse of the continue cmp
   ; the float-body allocator: cse plus linear scan, emitting IR forms through mv (the move) and
   ; opmap (op -> mnemonic), so the same walk serves the scalar and the packed kernel.
   (allocp dag rv env n pool mv opmap)
    (: rg {} pl (pin {} 'p pool)
       (pop u) (: p (pl 'p) _ (pin pl 'p >p) <p)
       (push r) (pin pl 'p (r . pl 'p))
       forms ((: (go i acc) (i = n ? acc
          (: nd (dag i)
             (? (= <nd 'L) (: _ (pin rg i (rgof <>nd env)) (go (i + 1) acc))
                (: op <nd a <>nd b <>>nd ra (peep rg a 0) rb (peep rg b 0)
                   adie (dies? a i dag rv n) bdie (dies? b i dag rv n)
                   dst (adie ? ra (pop 0))
                   _ (bdie && !(rb = dst) ? (push rb) 0) _ (pin rg i dst)
                   mvc (dst = ra ? () [[mv (fr dst) (fr ra)]])                       ; move only when dst is not a's reg
                   (go (i + 1) (acc + mvc + [[(opmap op) (fr dst) (fr rb)]]))))))) 0 ())
       [forms rg])
   (cmppd-imm op) (op @ '<= 2  '< 1  ())                                    ; the cmppd predicate: le / lt, the "continue while small" escape tests
   (grid2-ok? dims invs fvars updates testexpr cmpop bound)                              ; the packed shape fits?
    ((elem cmpop '(< <=)) && (#dims < 3) && (1 < (last dims)) && (0 = ((last dims) % 2))
     && ((#invs + #fvars) < 5)
     && (#(htbl (fcc bound (fccl updates (fcc testexpr ()))) 2) < 3))
   ; gp IR regs: r0=scratch, r5=Ip (the deopt tail), r7=k, r8=acc, r9../r10..=the grid counters.
   ; xmm: f2,f3=consts, f4=count, f5=alive, f6=scratch, f8,f9=invariants, f10,f11=fvars, and
   ; f0,f1,f12..f15 the DAG pool.
   (loopcode-grid2 dims cnames invs invd fvars updates testexpr cmpop bound lim)
    (: D #dims  M #invs  N #fvars
       cregs (rangeL 10 (10 + D))  rinner (last cregs)  iir (gr rinner)                  ; iir = inner counter's IR reg (bumped for lane1)
       fenv (invs + fvars)
       cenv (map2 (\ nm r [nm [['cvtsi2sd 'f0 (gr r)]]]) cnames cregs)               ; counter name -> its (cvtsi2sd f0 cntr) IR (cgFd reads these)
       ht (htbl (fcc bound (fccl updates (fcc testexpr ()))) 2)                          ; only inner-recurrence consts (bound+..) -> f2,f3; derive consts inline -> f4,5,6 free
       breg (fr (hlook bound ht))  pred (cmppd-imm cmpop)
       idx (map2 (\ i d (i . d)) (rangeL 0 M) invd)                                   ; (inv-index . derive-expr) pairs
       d0 (foldl (\ a p (a + (cgFd 'x64 ht cenv >p) + [['movsd (fr (8 + <p)) 'f0]])) () idx)       ; inv i lane0 -> low of f(8+i)
       d1 (foldl (\ a p (a + (cgFd 'x64 ht cenv >p) + [['unpcklpd (fr (8 + <p)) 'f0]])) () idx)    ; inv i lane1 (counter+1) -> high
       derives (d0 + [['inc iir]] + d1 + [['dec iir]])                               ; lane1 = the same derive at counter+1
       zerof (foldl (\ a j (a + [['xorpd (fr (8 + M + j)) (fr (8 + M + j))]])) () (rangeL 0 N))   ; fvars := 0 (both lanes)
       aenv ((efold fenv 8) + ht)
       pool ([0 1] + (rangeL (8 + M + N) 16))
       AR (vnall (testexpr . updates) () ())  rootv <AR  dag <>AR  nn #dag
       AL (allocp dag rootv aenv nn pool 'movupd sseop)  bodyc <AL  rg <>AL
       magr (peep rg <rootv 0)
       wb (foldl (\ a j (a + [['movupd (fr (8 + M + j)) (fr (peep rg (rootv (1 + j)) 0))]])) () (rangeL 0 N))   ; fvar <- its update's reg
       maskc [['movupd 'f6 (fr magr)] ['cmppd 'f6 breg pred] '(andpd f5 f6) '(psubq f4 f5) '(movmskpd r0 f5)]
       iter (['(label itop) ['cmp 'r7 lim] '(br ge iesc)] + bodyc + maskc             ; while k<lim and any lane alive
             + '((test r0 r0) (br eq iesc)) + wb + '((inc r7) (jmp itop) (label iesc)))
       deopt (deoptbody 'x64 0)                                                          ; tail-apply the interp fallback (overflow)
       accb ('((movqrx r0 f4) (adds r8 r8 r0) (br vc cont0)) + deopt                     ; acc += count.lane0 ; guard
             + '((label cont0) (movhlps f6 f4) (movqrx r0 f6) (adds r8 r8 r0) (br vc cont1)) + deopt + '((label cont1)))   ; acc += count.lane1 ; guard
       cell (derives + zerof + '((xorpd f4 f4) (pcmpeqd f5 f5) (li r7 0)) + iter + accb)   ; count=0; alive=ones; k=0; loop; acc
       (loop-nest ci body) (: p (cregs ci) cr (gr p) b (dims ci)               ; counted loops outer->inner; innermost steps by 2
          tp (intern ("lt" + (show ci))) en (intern ("le" + (show ci)))
          inner (? (ci = (D - 1)) body (loop-nest (ci + 1) body))
          step  (? (ci = (D - 1)) [['add cr cr 2]] [['inc cr]])
          ([['li cr 0] ['label tp] ['cmp cr b] ['br 'ge en]] + inner + step + [['jmp tp] ['label en]]))
       preload (foldl (\ a e (a + [['li 'r0 (fbits <e)] ['movqxr (fr <>e) 'r0] ['unpcklpd (fr <>e) (fr <>e)]])) () ht)   ; broadcast each const [c,c]
       (preload + '((li r8 0)) + (loop-nest 0 cell) + '((mov r0 r8))))                    ; IR program (x86): acc=0 ; nest ; result -> r0(=acc)
   ; jitfgridn tries the 2-wide packed kernel when the shape fits and takes the scalar one otherwise.
   ; grid2 is x86-only, since neon has no movmskpd, so a64 always rides gridn. both kernels answer an
   ; IR program ending with the checksum in acc, and jitfgridn appends loopepi and assembles for tgt.
   (jitfgridn lam cnames dims invs invd fvars updates testexpr cmpop bound lim tgt)
    (: pk (= tgt 'x64 && grid2-ok? dims invs fvars updates testexpr cmpop bound
             ? (loopcode-grid2 dims cnames invs invd fvars updates testexpr cmpop bound lim) ())
       prog (atom? pk ? (loopcode-gridn dims cnames invs invd fvars updates testexpr cmpop bound lim tgt) pk)
       (nif (emit (asmt tgt (prog + (loopepi tgt)))) (ev lam) lam 1))
   ; jitfgrid delegates the 2D mandelbrot-class signature onto the general kernel: D=2 over (px py),
   ; M=2 invariants (cx cy).
   (jitfgrid lam pxn pyn cxd cyd fvars updates testexpr cmpop bound lim tgt)
    (jitfgridn lam '(px py) [pxn pyn] '(cx cy) [cxd cyd] fvars updates testexpr cmpop bound lim tgt)
   ; --- the auto-hook grid recognizer ------------------------------------------------------------
   ; read a float-recurrence grid nest from source and extract the jitfgrid structure, so ordinary
   ; interpreted code glazes with no hand-call. the shape is a recurrence
   ;   (\ cx cy zx zy it (? (&& (it < LIM) (cmp TEST BOUND)) (mand ..updates.. (it + 1)) it))
   ; driven by two counted loops, with exactly 2 invariants (the point) and 2 fvars (the iterate).
   ; any other shape answers () and stays interpreted.
   (opd e i) (>e i)                                       ; the i-th operand of a form
   (classify ps args)                                               ; mand params vs recursive args -> (fvars updates invariants)
    (two? ps ? (: p <ps a <args r (classify >ps >args)
                  (? (a = p)       [<r <>r (p . (r 2))]            ; an invariant: the point
                     (a = ['+ p 1]) r                              ; a counter: (p + 1)
                                    [(p . <r) (a . <>r) (r 2)]))   ; an fvar and its update
               [() () ()])
   (posof k l i) (k = <l ? i (posof k >l (i + 1)))
   (grok glam mps mbody cbody gbody tgt)                           ; -> a native grid closure, or () when the shape misses
    (: cond (opd mbody 0)  then (opd mbody 1)
       c2 (opd cond 1)  lim (opd (opd cond 0) 1)  cmpop <c2  testexpr (opd c2 0)  bound (opd c2 1)
       cl (classify mps >then)  fvars <cl  updates <>cl  invs (cl 2)
       pyn (opd (opd cbody 0) 1)  margs >(opd ((>(opd cbody 1)) 2) 1)
       cxd (margs (posof (invs 0) mps 0))  cyd (margs (posof (invs 1) mps 0))
       pxn (opd (opd gbody 0) 1)
       (2 = #invs && 2 = #fvars
          ? (jitfgrid glam pxn pyn cxd cyd fvars updates testexpr cmpop bound lim tgt) ()))
   ; --- the neutral-IR lanes ---------------------------------------------------------------------
   ; greg maps a logical role to the abstract holo register, per target. x86 lands g/Ip/Hp/Sp in
   ; rdi/rsi/rdx/rcx (abstract r6/r5/r2/r1, SysV's first four args -- the convention IS the calling
   ; convention); a64's aapcs lands them in x0..x3, so the accumulator moves off r0. anchor is
   ; the machine stack-pointer snapshot for the deopt unwind; scratch is the callout lanes' second
   ; temp (mulo/rem take it as an operand and x86 ignores it -- rdx is the divide's own).
   ; EVERY ROLE MUST BE CALLER-SAVED. a blob is an lvm: entered by jmp, left by jmp, so it owns no
   ; epilogue to restore in, and the ret at the end of the dispatch chain answers to the C caller.
   ; holo's r0..r14 are x0..x14 on a64, all temporary; on x64 r3 and r4 are rbx and rbp.
   (greg tgt role)                                                     ; a role table, not a chain: read it in columns
    (: x (= tgt 'x64)
       (? (= role 'g)       (x ? 'r6 'r0)   (= role 'ip)      (x ? 'r5 'r1)
          (= role 'hp)      (x ? 'r2 'r2)   (= role 'sp)      (x ? 'r1 'r3)
          (= role 'acc)     (x ? 'r0 'r4)   (= role 'tmp)     (x ? 'r7 'r5)
          (= role 'anchor)  (x ? 'r8 'r9)   (= role 'scratch) (x ? 'r10 'r10) ()))
   (ccof op)  (op @ '< 'lt  '<= 'le  '> 'gt  '>= 'ge  '= 'eq  ())      ; a source comparison -> its IR condition code
   (bitop op) (op @ '& 'and  '| 'or  '^ 'xor  ())                      ; a source bitwise symbol -> its IR ALU op

   ; fxir: fetch param i from Sp[i], fixnum-guard the low bit, untag into acc. a non-fixnum jumps to deopt.
   (fxir tgt i) (: A (greg tgt 'acc) S (greg tgt 'sp) [['ld A S (8 * i)] ['test A 1] '(br eq deopt) ['sar A 1]])
   ; arithir: acc = (the popped a) OP acc, overflow -> deopt. - keeps the a-b order; * uses the fused mulo.
   (arithir tgt op) (: A (greg tgt 'acc) T (greg tgt 'tmp) SC (greg tgt 'scratch)
      (op @ '+ [['adds A A T] '(br vs deopt)]
            '- [['subs T T A] '(br vs deopt) ['mov A T]]
            '* [['mulo A A T SC 'deopt]]
            ()))
   (divir tgt op) (: A (greg tgt 'acc) T (greg tgt 'tmp) SC (greg tgt 'scratch)   ; the caller emits the /-by-0 guard
      (op @ '// [['div A T A]]  '% [['rem A T A SC]]  ()))
   ; divk: n in tmp, divided by the literal k >= 2 through its magic multiply (Hacker's Delight
   ; 10-1, the signed 64-bit form): q = mulh(n, M) (+ n when M < 0) >> s, then + 1 for a negative
   ; n so it truncates toward zero as idiv does; % is n - q*k. no divide, no /-by-0 guard.
   (divc? b) (whole? b && b >= 2)
   (magic k) (: two63 9223372036854775808  two64 18446744073709551616
                anc (two63 - 1 - (two63 % k))
                (go p q1 r1 q2 r2)
                 (: p1 (p + 1)
                    q1a (2 * q1) r1a (2 * r1)
                    q1b (r1a >= anc ? (q1a + 1) q1a) r1b (r1a >= anc ? (r1a - anc) r1a)
                    q2a (2 * q2) r2a (2 * r2)
                    q2b (r2a >= k ? (q2a + 1) q2a) r2b (r2a >= k ? (r2a - k) r2a)
                    delta (k - r2b)
                    (? (|| (< q1b delta) (&& (= q1b delta) (= r1b 0))) (go p1 q1b r1b q2b r2b)
                       (: M (q2b + 1) ((M >= two63 ? (M - two64) M) . (p1 - 64)))))
                (go 63 (two63 // anc) (two63 - ((two63 // anc) * anc)) (two63 // k) (two63 - ((two63 // k) * k))))
   (pow2 k) ((: (go j) (? (< (j 2) k) (go (j + 1)) (= (j 2) k) j 0)) 1)                  ; k = 2^j -> j, else 0
   (divk tgt op k) (: A (greg tgt 'acc) T (greg tgt 'tmp) SC (greg tgt 'scratch) j (pow2 k)
      (? j ([['mov A T] ['sar A 63] ['shr A (64 - j)] ['add A A T] ['sar A j]]                   ; a power of two: bias a negative n by k-1, then shift
            + (op @ '% [['shl A j] ['sub T T A] ['mov A T]] ()))
         (: m (magic k) M <m s >m
            ([['li SC M] ['mulh A T SC]]
             + (M < 0 ? [['add A A T]] ())
             + (s > 0 ? [['sar A s]] ())
             + [['mov SC T] ['shr SC 63] ['add A A SC]]
             + (op @ '% [['li SC k] ['imul SC A SC] ['sub T T SC] ['mov A T]] ())))))
   ; cgir: an arith expr e over params ps -> IR ops accumulating in acc, a param fetched from its Sp
   ; slot. nested operands ride the machine stack, ? gets fresh mint labels, and one deopt label is
   ; shared. serves both the leaf (ps one param) and the n-ary lane.
   ; cgir and cgvir read every op by NAME and never consult shd: they are safe only because
   ; amble-ok? declines a frame that rebinds one, so a shadowed loop reaches bytecode instead.
   ; loosen that gate and these arms take the op over the binding.
   (cgir tgt ps e)
    (: A (greg tgt 'acc) T (greg tgt 'tmp)
       (bin a b fin) ((cgir tgt ps a) + [['push A]] + (cgir tgt ps b) + fin)
       (? (elem e ps) (fxir tgt (argix e ps 0))
          (whole? e) [['li A e]]
          (e @ ('? c t f) (: el (mint 0) en (mint 0)
                             ((cgir tgt ps c) + [['cmp A 0] ['br 'le el]] + (cgir tgt ps t)
                              + [['jmp en] ['label el]] + (cgir tgt ps f) + [['label en]]))
               (op a b) (? (elem op '(+ - *))       (bin a b ([['pop T]] + (arithir tgt op)))
                           (elem op '(// %) && divc? b) ((cgir tgt ps a) + [['mov T A]] + (divk tgt op b))
                           (elem op '(// %))        (bin a b ([['test A A] '(br eq deopt) ['pop T]] + (divir tgt op)))
                           (elem op '(& | ^))       (bin a b [['pop T] [(bitop op) A A T]])
                           (elem op '(< <= > >= =)) (bin a b [['pop T] ['cmp T A] ['set (ccof op) A]])
                           ())
               ())))
   ; deoptir: the shared deopt block -- restore the machine sp from the anchor, then tail-apply the interp
   ; fallback. arity 1 jumps to value[1], the closure re-applied to the arg; arity>=2 jumps to value[1]+16,
   ; its body, where the saturated args already sit on Sp. mov vs lea is the lone per-arity difference.
   (deoptir tgt bodyp) (: AN (greg tgt 'anchor) IP (greg tgt 'ip) T (greg tgt 'tmp)
      [['label 'deopt] ['lea 'sp AN 0] ['ld T IP 8] (bodyp ? ['lea IP T 16] ['mov IP T]) ['ld T IP 0] ['jmpr T]])
   ; coreir: the whole-function IR -- prologue (anchor = the machine sp) ; the body ; putfix epilogue +
   ; Continue (Ip+=16; jmp [Ip]) ; the deopt block. (jitcore assembles + installs it; tests assemble it.)
   (coreir tgt ps body deoptblk)
    (: AN (greg tgt 'anchor) S (greg tgt 'sp) A (greg tgt 'acc) IP (greg tgt 'ip) T (greg tgt 'tmp)
       ([['lea AN 'sp 0]] + (cgir tgt ps body) + [['adds A A A] '(br vs deopt) ['or A A 1] ['st S 0 A] ['add IP IP 16] ['ld T IP 0] ['jmpr T]] + deoptblk))
   ; jitcore: assemble coreir for tgt and install as a nat of the given arity (deopt -> interp).
   (jitcore tgt ps body deoptblk arity lam)
    (nif (emit (asmt tgt (coreir tgt ps body deoptblk))) (ev lam) lam arity)
   ; (jitir '(\ x E) tgt) -- an arity-1 leaf. (jitnir '(\ p0 .. E) tgt) -- arity>=2 (natn curries to saturation).
   (jitir lam tgt)  (jitcore tgt [<>lam] <>>lam (deoptir tgt 0) 1 lam)
   (jitnir lam tgt) (: ps (init >lam) body (last >lam) (jitcore tgt ps body (deoptir tgt 1) #ps lam))


   ; --- the loop-body neutral IR ------------------------------------------------------------------
   ; cgvir is cgir's arith grammar for the loop lanes, whose state fills the loop registers and leaves
   ; no free reg for an anchor. so the overflow and /-by-0 guards deopt inline: unwind the d pending
   ; machine-stack pushes, then tail-apply interp (value[1]) to the arg still in Sp[0], where cgir
   ; restores from its anchor. a var is loaded by `varld` -- the counter from its raw register, an
   ; n-loop param via fxir.
   ; deoptbody carries no branch or label of its own; ldeopt, zdeopt and the *-overflow lane wrap it
   ; with the guard branch and a skip label.
   (deoptbody tgt d) (: A (greg tgt 'acc) IP (greg tgt 'ip)
      ((d > 0 ? [['add 'sp 'sp ((slotsz tgt) * d)]] ()) + [['ld A IP 8] ['mov IP A] ['ld A IP 0] ['jmpr A]]))
   (ldeopt tgt d) (: ok (mint 0) ([['br 'vc ok]] + (deoptbody tgt d) + [['label ok]]))   ; skip the deopt unless overflow
   (zdeopt tgt d) (: ok (mint 0) ([['br 'ne ok]] + (deoptbody tgt d) + [['label ok]]))   ; skip unless nonzero: the /-by-0 and fixnum-input guard
   (fxvir tgt i d) (: A (greg tgt 'acc) S (greg tgt 'sp)   ; load Sp[i] tagged, fixnum-guard with an inline deopt at depth d, untag
      ([['ld A S (8 * i)] ['test A 1]] + (zdeopt tgt d) + [['sar A 1]]))
   (arithl tgt op d) (: A (greg tgt 'acc) T (greg tgt 'tmp) SC (greg tgt 'scratch) dl (mint 0) ok (mint 0)   ; acc = (popped a) OP acc, overflow -> inline deopt
      (op @ '+ ([['adds A A T]] + (ldeopt tgt d))
            '* ([['mulo A A T SC dl]] + [['jmp ok] ['label dl]] + (deoptbody tgt d) + [['label ok]])   ; mulo sets no a64 flag, so it branches; SC is the smulh scratch
            '- ([['subs T T A]] + (ldeopt tgt d) + [['mov A T]])
            ()))
   (divl tgt op d) (: A (greg tgt 'acc) T (greg tgt 'tmp) SC (greg tgt 'scratch)   ; a in tmp (popped), b in acc -> acc; b == 0 deopts
      ([['pop T] ['test A A]] + (zdeopt tgt d) + (op @ '// [['div A T A]]  '% [['rem A T A SC]]  ())))
   (cgvir tgt varld e d)
    (: A (greg tgt 'acc) T (greg tgt 'tmp)
       (bin a b fin) ((cgvir tgt varld a d) + [['push A]] + (cgvir tgt varld b (d + 1)) + fin)
       vl (varld e d)
       (? vl vl                                              ; a var -> its loader IR (acc <- the var, at depth d)
          (whole? e) [['li A e]]
          (e @ ('? c t f) (: el (mint 0) en (mint 0)
                             ((cgvir tgt varld c d) + [['cmp A 0] ['br 'le el]] + (cgvir tgt varld t d)
                              + [['jmp en] ['label el]] + (cgvir tgt varld f d) + [['label en]]))
               (op a b) (? (elem op '(+ - *))       (bin a b ([['pop T]] + (arithl tgt op d)))
                           (elem op '(// %) && divc? b) ((cgvir tgt varld a d) + [['mov T A]] + (divk tgt op b))
                           (elem op '(// %))        (bin a b (divl tgt op d))
                           (elem op '(& | ^))       (bin a b [['pop T] [(bitop op) A A T]])
                           (elem op '(< <= > >= =)) (bin a b [['pop T] ['cmp T A] ['set (ccof op) A]])
                           ())
               ())))
   ; --- the neutral-IR group lane ----------------------------------------------------------------
   ; a group of mutually recursive first-order integer fns to native, both targets: `call H_g` is
   ; (call <name>), each H opens (label <name>), and the assembler resolves the rel offsets. IR
   ; chunks concatenate flat through bcat. it covers the full op grammar: int arith, tco, value-mode
   ; cons, and the string/map/cask lanes.
   ; arg-register ABI: args in the callee-saved bank (x86 rbx/r13/r14/r15, a64 x19..x22) and the
   ; OVF anchor in another callee-saved reg. a call passes args on the machine stack, and each H
   ; saves, loads and restores its own arg regs so a caller's args survive a nested call; on a64 it
   ; also saves lr, which bl clobbers, where x86's call/RET keeps the return address on the stack.
   ; mov to or from sp is `lea`: the ORR-based mov reads and writes XZR for reg 31, never sp.
   (slotsz tgt) (= tgt 'x64 ? 8 16)                                          ; the push/pop unit
   (govf tgt)   (= tgt 'x64 ? 'r11 'r23)                                     ; the OVF anchor reg: x86 r12 / a64 x23
   (argregir tgt i) ((= tgt 'x64 ? '(r3 r12 r13 r14) '(r19 r20 r21 r22)) i)
   (hsave tgt)  (= tgt 'x64 ? () ['(push lr)])                            ; a64's H spills lr; x86 rides call/RET's stack
   (hrest tgt)  (= tgt 'x64 ? () ['(pop lr)])
   (saveargsir tgt k) (foldl (\ a i (bcat [a [['push (argregir tgt i)]]])) () (rangeL 0 k))
   (restargsir tgt k) (foldl (\ a i (bcat [a [['pop (argregir tgt ((k - 1) - i))]]])) () (rangeL 0 k))
   (loadargsir tgt k) (foldl (\ a i (bcat [a [['ld (argregir tgt i) 'sp ((slotsz tgt) * ((2 * k) - i))]]])) () (rangeL 0 k))   ; argreg_i <- the passed arg at [sp + slotsz*(2k-i)]
   (garith tgt op) (: A (greg tgt 'acc) T (greg tgt 'tmp) SC (greg tgt 'scratch)   ; acc = (popped a) OP acc, overflow -> OVF
      (op @ '+ [['adds A A T] '(br vs OVF)]
            '- [['subs T T A] '(br vs OVF) ['mov A T]]
            '* [['mulo A A T SC 'OVF]]
            ()))
   ; the register/immediate operand peephole: the generic binary lane is push-acc .. pop-tmp per op,
   ; which is the gap against a register machine. when one operand is already a param (so, in an arg
   ; reg) or a small immediate, combine it directly -- acc OP= reg|imm, no stack traffic -- and
   ; primes' (d * d), (n < (d * d)), (d + 1) and (0 = ..) all run flat. the ALU takes a reg or an imm
   ; for adds/subs/cmp on both targets, a64's imm being 12-bit; mulo is register-only on a64, so
   ; the imm lane skips `*`, and the case that matters -- d*d -- is a register anyway.
   (pimm? x) (whole? x && (x < 0 ? (0 - x) x) <= 4095)                      ; an immediate both arches add/sub/cmp directly
   (preg tgt ps x) (elem x ps && argregir tgt (argix x ps 0))            ; x a param -> its arg reg, else ()
   (garith-r tgt op R) (: A (greg tgt 'acc) SC (greg tgt 'scratch)              ; acc = acc OP R (R a reg), overflow -> OVF
      (? (= op '+) [['adds A A R] '(br vs OVF)]
         (= op '-) [['subs A A R] '(br vs OVF)]
         (= op '*) [['mulo A A R SC 'OVF]] ()))
   (garith-i tgt op imm) (: A (greg tgt 'acc)                                   ; acc = acc OP imm (no `*`), overflow -> OVF
      (op @ '+ [['adds A A imm] '(br vs OVF)]
            '- [['subs A A imm] '(br vs OVF)]
            ()))
   (flipc op) (op @ '< '>  '<= '>=  '> '<  '>= '<=  op)   ; mirror a cmp's operands; = stays
   (deoptmn tgt bodyp) (: IP (greg tgt 'ip) T (greg tgt 'tmp)                    ; tail-apply interp (value[1]); bodyp -> its body (+16, arity>=2)
      [['ld T IP 8] (bodyp ? ['lea IP T 16] ['mov IP T]) ['ld T IP 0] ['jmpr T]])
   ; cggir: a group expr e over params ps, which live in arg regs; syms are the group fn names, the call
   ; targets. a call pushes its args, `call H_g`, pops them; arith overflow and a /-by-0 jump to the
   ; shared OVF handler. the operand patterns are exact-arity, matching auto.l's groupok? grammar.
   (cggir tgt syms ps e)
    (: A (greg tgt 'acc) T (greg tgt 'tmp)
       (go x) (cggir tgt syms ps x)
       (? (elem e ps) [['mov A (argregir tgt (argix e ps 0))]]
          (whole? e) [['li A e]]
          (atom? e) ()
          (elem <e syms)
            (bcat [(gargsir tgt syms ps >e) [['call <e]] [['add 'sp 'sp ((slotsz tgt) * #>e)]]])
          (e @ (op a b)
            (? (elem op '(+ - *))
                 (: pa (preg tgt ps a) pb (preg tgt ps b)
                    (? pb                             (bcat [(go a) (garith-r tgt op pb)])   ; (E op p): E->acc; acc OP= p_reg
                       (pimm? b && !(= op '*))   (bcat [(go a) (garith-i tgt op b)])    ; (E op C)
                       (pa && elem op '(+ *))   (bcat [(go b) (garith-r tgt op pa)])   ; (p op E): commute
                       (pimm? a && (= op '+))     (bcat [(go b) (garith-i tgt op a)])    ; (C + E): commute; an imm `*` has no a64 form, so it stays generic
                       (bcat [(go a) [['push A]] (go b) [['pop T]] (garith tgt op)])))   ; generic
               (elem op '(// %) && divc? b) (bcat [(go a) [['mov T A]] (divk tgt op b)])
               (elem op '(// %))
                 (bcat [(go a) [['push A]] (go b) [['test A A] '(br eq OVF) ['pop T]] (divir tgt op)])
               (elem op '(& | ^))
                 (bcat [(go a) [['push A]] (go b) [['pop T] [(bitop op) A A T]]])
               (elem op '(< <= > >= =))
                 (: pa (preg tgt ps a) pb (preg tgt ps b)
                    (? pb         (bcat [(go a) [['cmp A pb] ['set (ccof op) A]]])             ; (E op p): cmp acc,p_reg
                       (pimm? b)  (bcat [(go a) [['cmp A b]  ['set (ccof op) A]]])             ; (E op C)
                       pa         (bcat [(go b) [['cmp pa A] ['set (ccof op) A]]])             ; (p op E): flags p-acc = a-b, cc kept
                       (pimm? a)  (bcat [(go b) [['cmp A a]  ['set (ccof (flipc op)) A]]])     ; (C op E): cmp acc,C = b-a, flip cc
                       (bcat [(go a) [['push A]] (go b) [['pop T] ['cmp T A] ['set (ccof op) A]]])))   ; generic
               ())
            (op a b c)
            (? (= op '?)
                 (: el (mint 0) en (mint 0)
                    (bcat [(go a) [['cmp A 0] ['br 'le el]] (go b)
                            [['jmp en] ['label el]] (go c) [['label en]]]))
               (= op 'peep) (: R (argregir tgt (argix a ps 0)) inl (mint 0) endl (mint 0)   ; (peep STR i d): i unsigned-vs-len, out of range -> d, else the byte at [STR+i+16]
                  (bcat [(go b)
                         [['ld T R 8] ['cmp A T] ['br 'below inl] ['li A (whole? c ? c 0)] ['jmp endl] ['label inl] ['ldxb A R A 1 16] ['label endl]]]))
               (= op 'pin) (: R (argregir tgt (argix a ps 0))                              ; (pin C i V): store V's low byte at C's backing[i], answer C
                  (bcat [(go b) [['push A]] (go c)                                            ; i -> acc, push; V -> acc
                         [['pop T] ['ld 'r8 R 8] ['stxb 'r8 T 1 16 A] ['mov A R]]]))          ; pop T(=i); r8 = the backing str; [backing+i+16] = V.lo; acc = C
               (= op 'mpeep) (: R (argregir tgt (argix a ps 0)) lp (mint 0) ht (mint 0) ms (mint 0) en (mint 0)   ; (mpeep MAP k d): the open-addressed probe -> the raw value in acc, a gap-miss -> d
                  (bcat [(go b) [['leax 'r10 A A 1 1] ['mov A R]] (relabel (mpeep-ir (whole? c ? c 0)) lp ht ms en 'deopt)]))   ; k -> acc; r10 = tag(k); acc = the map; then the probe, labels gensym'd
               (= op 'mpin) (: R (argregir tgt (argix a ps 0)) lp (mint 0) ht (mint 0) ms (mint 0) en (mint 0)   ; (mpin MAP k v): probe and update in place; a grow-due miss -> OVF; answers the map
                  (bcat [(go c) [['push A]] (go b) [['leax 'r10 A A 1 1] ['mov A R]] (relabel mpin-ir lp ht ms en 'OVF) [['mov A R]]]))   ; v -> acc, pushed as the spill mpin-ir's own (pop r8) takes; k -> acc; acc = the map, threaded back out
               ())
            (op a)
            (? (= op 'tally) (: R (argregir tgt (argix a ps 0)) [['ld A R 8]])              ; (tally STR): acc = the raw len at [STR+8]
               (= op 'two?) (: z (mint 0) en (mint 0)                                       ; (two? E): is E a chain? -> 1/0, total, since a non-chain reads 0
                  (bcat [(go a) [['test A 1] ['br 'ne z] ['ld T A 0] (jk tgt 'r8 0) ['cmp T 'r8] ['br 'ne z] ['li A 1] ['jmp en] ['label z] ['li A 0] ['label en]]]))
               (= op 'cap) (bcat [(go a) [['test A 1] ['br 'ne 'OVF] ['ld T A 0] (jk tgt 'r8 0) ['cmp T 'r8] ['br 'ne 'OVF] ['ld A A 8]]])    ; <E: a non-chain deopts, and it always runs under a two?
               (= op 'cup) (bcat [(go a) [['test A 1] ['br 'ne 'OVF] ['ld T A 0] (jk tgt 'r8 0) ['cmp T 'r8] ['br 'ne 'OVF] ['ld A A 16]]])   ; >E: the same guard, then acc = [E+16]
               ())
            ())))
   (gargsir tgt syms ps as) (atom? as ? () (bcat [(cggir tgt syms ps <as) [['push (greg tgt 'acc)]] (gargsir tgt syms ps >as)]))
   ; relabel: gensym the map probe's fixed labels per call site and point deopt at the given group
   ; label, so the same probe IR can be spliced N times into one group assemble without collisions.
   (relabel ir lp ht ms en dp) (map (f \ map (x \ (x @ 'loop lp  'hit ht  'miss ms  'end en  'deopt dp  x)) f) ir)
   ; consir: build a chain cell on the heap -> acc. the room guard comes first, so no GC fires
   ; mid-native, then [Hp] = the chain kind, [Hp+8] = cap (the popped a), [Hp+16] = cup, acc = Hp --
   ; an even pointer is the value, so no putfix -- and Hp += 3 words. r9/r10 are free scratch in the
   ; group ABI (args r3/r12-r14, anchor r11, acc r0, tmp r7, sp r1, hp r2, ip r5).
   (consir tgt) (: A (greg tgt 'acc) T (greg tgt 'tmp) S (greg tgt 'sp) HP (greg tgt 'hp)
      [['lea 'r9 HP 88] ['cmp S 'r9] '(br below OVF)                             ; room for 3w+floor; Sp < Hp+88 -> heap full -> deopt
        (jk tgt 'r10 0) ['st HP 0 'r10]                                      ; [Hp] = chain header
        ['st HP 8 T] ['st HP 16 A]                                               ; [Hp+8] = cap (the popped a); [Hp+16] = cup (b)
        ['mov A HP] ['add HP HP 24]])                                            ; acc = Hp (result ptr); bump Hp by 3 words
   ; cggvir is VALUE-mode codegen: e yields a love value -- a heap pointer or a tagged scalar -- in acc
   ; rather than a raw int. an int const becomes the tagged value, a param re-tags its raw arg reg, and
   ; (? T A B) takes its test through cggir and its branches through here.
   (cggvir tgt syms ps e)
    (: A (greg tgt 'acc) T (greg tgt 'tmp)
      (? (whole? e) [['li A ((2 * e) + 1)]]                                        ; the tagged value C
         (elem e ps) (: R (argregir tgt (argix e ps 0)) [['leax A R R 1 1]])    ; a param: acc = 2*reg + 1
         (atom? e) ()
         (elem <e syms) (cggir tgt syms ps e)                                   ; a value-group call: cggir's call already answers the value
         (e @ ('. a b) (bcat [(cggvir tgt syms ps a) [['push A]] (cggvir tgt syms ps b) [['pop T]] (consir tgt)])   ; A ; push ; B ; pop T(=A) ; cons(T,A)
              ('? c t f) (: el (mint 0) en (mint 0)
                 (bcat [(cggir tgt syms ps c) [['cmp A 0] ['br 'le el]] (cggvir tgt syms ps t)
                        [['jmp en] ['label el]] (cggvir tgt syms ps f) [['label en]]]))
              ())))
   ; cggtir: e in tail position. a tail self-call of matching arity computes the new args from the old
   ; arg regs onto the machine stack, pops them into the arg regs, then jumps Lbody, past save/load --
   ; the frame is reused, so a counted loop is O(1) stack with no call/ret per iteration. a tail ?
   ; recurses tail into both branches, its test staying non-tail. anything else goes to cggir and falls
   ; through to restore + ret. self only: a sibling tail-call stays a plain `call`.
   (cggtir tgt syms ps e selfnm Lbody)
    (: A (greg tgt 'acc) k #ps
       (? (two? e && (= <e selfnm) && #>e = k)                    ; a tail self-call -> loop in place
            (bcat [(gargsir tgt syms ps >e)                                      ; push the new args, all read from the old regs
                   (foldl (\ a i (bcat [a [['pop (argregir tgt ((k - 1) - i))]]])) () (rangeL 0 k))   ; pop into the arg regs, in reverse
                   [['jmp Lbody]]])
          (e @ ('? c t f) (: el (mint 0) en (mint 0)                            ; a tail ? -> test non-tail, both branches tail
                 (bcat [(cggir tgt syms ps c) [['cmp A 0] ['br 'le el]] (cggtir tgt syms ps t selfnm Lbody)
                        [['jmp en] ['label el]] (cggtir tgt syms ps f selfnm Lbody) [['label en]]]))
               (cggir tgt syms ps e))))                                          ; any other tail expr -> a value in acc
   ; mkhir: one function -- label; [push lr]; save arg regs; load the passed args; Lbody; body; restore;
   ; [pop lr]; ret. a value body (it conses) takes cggvir and no tco; an int body takes cggtir.
   (mkhir tgt syms nm ps body)
    (: k #ps Lbody (mint 0)
       (bcat [[['label nm]] (hsave tgt) (saveargsir tgt k) (loadargsir tgt k) [['label Lbody]]
               (hasl body ? (cggvir tgt syms ps body) (cggtir tgt syms ps body nm Lbody))
               (restargsir tgt k) (hrest tgt) ['(ret)]]))
   ; mkouterir: the entry's outer -- save the anchor and arg regs; anchor = sp; fixnum-guard and push
   ; the args; call H_entry; pop; restore; putfix + Continue. OVF restores sp from the anchor, which
   ; abandons the group's frames, then falls into deopt.
   ; it also partitions the entry's external args by kind: int (untagged), string|map|cask (kind-guarded,
   ; raw), chain (raw, unguarded), point (nom|mint-guarded, raw).
   (mkouterir tgt k entry arity valt smask mmask bufmask cmask pmask)              ; valt: a value-typed entry stores acc as-is, with no putfix
    (: A (greg tgt 'acc) S (greg tgt 'sp) IP (greg tgt 'ip) T (greg tgt 'tmp) OVFR (govf tgt) ss (slotsz tgt)
       strk 1 mapk 2 bufk 6                                                            ; the jk slots of the kind sentinels the raw-param guards check against
       (pusharg1 i) (: o (8 * i)                                                   ; one external arg: load Sp[i] -> acc, guard by kind, push
          (? (elem i cmask) [['ld A S o] ['push A]]                          ; a chain: raw, no guard -- two? is total and cap/cup deopt a non-chain inline
             (elem i smask || (elem i mmask || elem i bufmask))     ; a string, map or cask: a fixnum cannot be a heap object, and [arg]'s kind must match
               (: kind (? (elem i mmask) mapk (elem i bufmask) bufk strk)
                  [['ld A S o] ['test A 1] '(br ne OVF) ['ld T A 0] (jk tgt 'r8 kind) ['cmp T 'r8] '(br ne OVF) ['push A]])   ; an odd (fixnum) word deopts, then the kind word must match
             (elem i pmask)                                                     ; a point key: nom or mint, pushed raw -- word identity is its whole equality,
               (: pok (mint 0)                                                     ; and a charm deopts, since only interp knows the numeric bridges like (2 = 2.0)
                  [['ld A S o] ['test A 1] '(br ne OVF)
                    ['ld T A 0] (jk tgt 'r8 3) ['cmp T 'r8] ['br 'eq pok]
                    (jk tgt 'r8 4) ['cmp T 'r8] '(br ne OVF) ['label pok] ['push A]])
             [['ld A S o] ['test A 1] '(br eq OVF) ['sar A 1] ['push A]]))    ; an int: fixnum-guarded, untagged, pushed
       pushargs (foldl (\ a i (bcat [a (pusharg1 i)])) () (rangeL 0 k))
       epi (valt ? [['st S 0 A] ['add IP IP 16] ['ld T IP 0] ['jmpr T]]                                  ; a value: store acc as-is, then Continue with no putfix
                 [['adds A A A] '(br vs DEOPT) ['or A A 1] ['st S 0 A] ['add IP IP 16] ['ld T IP 0] ['jmpr T]])   ; an int: putfix, overflow -> deopt, then Continue
       (bcat [(hsave tgt) [['push OVFR]] (saveargsir tgt k) [['lea OVFR 'sp 0]] pushargs
              [['call entry] ['add 'sp 'sp (ss * k)]] (restargsir tgt k) [['pop OVFR]] (hrest tgt)   ; lr is saved and restored around `call entry`: on a64 bl clobbers x30, which is the live return address the threaded tail-call chain eventually rets through, and the outer tail-jumps onward, so it must hand x30 back intact
              epi
              [['label 'OVF] ['lea 'sp OVFR 0]] (restargsir tgt k) [['pop OVFR]] (hrest tgt)
              [['label 'DEOPT]] (deoptmn tgt (arity > 1))]))
   ; jgir-ok? is the op gate: does the group lane implement every op this group uses, at the arity
   ; cggir lowers? autogroup routes here when it answers true and leaves the group interpreted when
   ; it does not. it is reached only after auto.l's recognizer has proven the group glazeable --
   ; shapes, arities, the int/chain/value typing, the interprocedural string inference -- so it does
   ; not re-derive the grammar; it is the backstop for the natjit path, which has no recognizer.
   ; jgir-arity is the operand count cggir/cggvir read, form tally included, so a head at any other
   ; arity would have its extra operands silently dropped.
   jgir-arity {'+ 3 '- 3 '* 3 '// 3 '% 3 '& 3 '| 3 '^ 3 '< 3 '<= 3 '> 3 '>= 3 '= 3 '. 3
               '? 4 'peep 4 'pin 4 'mpeep 4 'mpin 4
               'tally 2 'two? 2 'cap 2 'cup 2}
   (jgir-ops-ok? syms e)                                          ; every head in e is a group call or a supported op at its own arity
    (? (atom? e) (gem? e || twin? e ? 0 1)                       ; a smooth-numeric leaf is out of the integer lane
       (: op <e
          n (jgir-arity op)
          ((elem op syms || (n && #e = n)) && all (x \ jgir-ops-ok? syms x) >e)))
   (jgir-ok? defs) (: syms (map (d \ <<d) defs)
      (all (d \ jgir-ops-ok? syms >d) defs))
   ; jgir-lrf -- the ((mpeep..) (peep..) (mpin..) (pin..) def..) tail the deopt fallback re-evaluates.
   (jgir-lrf entry ds) (atom? ds ? [entry] (: d <ds (<d . (>d . jgir-lrf entry >ds))))
   ; (jitgroupir defs entry tgt): defs are ((nameform . body) ..), and the entry is the group's value.
   ; the deopt fallback is (ev <the whole group>), and post-rebind `ev` is the glaze, so it re-glazes
   ; the group -- harmless, a never-deopting native gets rebuilt -- which is why the mpeep/mpin ->
   ; peep/pin aliases (ldxb/stxb) must assemble on every target, a64 included. mpeep and mpin are
   ; glaze-internal, not real fns: the aliases read the previous, global binding by the sequence law
   ; rather than recursing, so a non-map lane keeps the core accessors.
   (jitgroupir defs entry tgt)
    (jitgroupirx defs entry tgt (ev (': . ('(mpeep mc mk md) . ('(peep mc mk md) . ('(mpin mc mk mv) . ('(pin mc mk mv) . jgir-lrf entry defs)))))) ())
   ; jitgroupirx takes the deopt target directly instead. the natjit hook passes `e`, the bytecode
   ; twin, so a group-bearing closure native-backs without re-entering the evaluator mid-ala, which
   ; jitgroupir's (ev ..) fallback would. pure otherwise: assemble and install, no ev.
   (jitgroupirx defs entry tgt deopt src)
    (: parse (map (d \ (: nf <d [<nf >nf >d])) defs)            ; (name params body) per fn
       syms (map cap parse)                                                            ; the fn names, which are the call targets
       efn (gfind (f \ (= <f entry)) parse)  eps (efn 1)  eb (efn 2)  k #eps
       ord (efn . filter (f \ !(= <f entry)) parse)                      ; the entry first, so H_entry sits right after the outer
       valt (hasl eb)                                                                 ; a value-typed entry (its body conses) takes the value epilogue
       info (map (f \ [<f (f 1) (f 2) #(f 1)]) parse)                   ; (name params body arity), for the interprocedural string fixpoint
       smap0 (map (f \ <f . filter (j \ suse? (f 2) ((f 1) j)) (rangeL 0 (f 3))) info)   ; per-fn direct string params (peep/tally/pin)
       smask (gsm entry (smfix info smap0))                                            ; the entry's string params at the fixpoint -> raw pointer, kind-guarded
       mmask (filter (j \ muse? eb (eps j)) (rangeL 0 k))                         ; entry map params (mpeep/mpin)
       bufmask (filter (j \ buse? eb (eps j)) (rangeL 0 k))                       ; entry cask params (pin)
       cmask (filter (j \ cuse? eb (eps j)) (rangeL 0 k))                         ; entry chain params (cap/cup/two?) -> raw, no guard
       pmask (filter (j \ nuse? eb (eps j) && !(elem j cmask)) (rangeL 0 k))   ; entry point keys -> raw, nom|mint-guarded; a chain-used param is never a point
       outer (mkouterir tgt k entry k valt smask mmask bufmask cmask pmask)
       Hs (foldl (\ a f (bcat [a (mkhir tgt syms <f (f 1) (f 2))])) () ord)
       elam ('\ . eps + [eb])                                        ; the entry's source lambda, the =/show src fallback
       (nif (emit ((assemble tgt (bcat [outer Hs])) 'bytes)) deopt (two? src ? src elam) k))   ; the outer surface if the caller gave one, else elam
)
; auto -- rebind `ev` so a qualifying closure compiles to native, transparently: no verb
; and no annotation, and the native is =/show-identical to its source. Everything else
; falls through to the base interpreter unchanged.
;
; the lanes, over the emitter's grammar E := var | int | (OP E E) | (? E E E),
; OP in + - * // % & | ^ < <= > >= = -- every recognizer here is exact-arity, since
; (+ x 1 2) is the tower ((+ x 1) 2) and not the two-operand add it reads as:
;   leaf   (\ x E), (\ p0 .. pn E) any arity, and (\ p (\ q E)) flattened to the 2-param
;   fleaf  (\ x F), F a float body -> a heap-boxed gem; sound only where the param is
;          floated at first use (allsafe), else the interpreter keeps an int subexpr exact
;   loop   (\ n ((: (go i a) (? (i < n) (go (i + 1) (a + B)) a)) 0 0)), a counted sum --
;          owning the back-edge is where the win is, well past the leaf's few percent
;   then the source rewrites (castbuild/twolow/autonat/autogroup) carry everything else.
;
; ev stays 1-arg, so the loader's `(ev 'ev r)` = `((ev 'ev) r)` survives the rebind;
; njit-loop and njit-loop-n call the captured base-ev, so a jit never re-enters ev.
; loads after emit above; the two are the `glaze` module (i/main.c
; registers the pair), so every name here is reached by (cite 'glaze 'k) and none of them
; touches the book -- `ev` and `elem` are the exceptions the tail explains.
(: sfuel {})   ; autospec's unfold-fuel, a global because a sibling-captured value-local misses in the hatched ev; smix re-seeds it per specialization
(: glaze-loaded? (lit? (cite 'glaze))   ; a re-load detector, read before this load defglob's anything: `glaze` in the registry means the baked glaze is already installed, and the `ev` rebind below hands it straight back
   ; the registry, never `book` -- a woken image has `book` sealed away and the read would scare
   ; the pure interpreter, captured once: on a re-load `ev` is auto-ev already, so read the interpreter
   ; out of the module book -- else base-ev is the glaze, and autospec's static fold re-enters it
   base-ev (: G (cite 'glaze) (? G (G 'base-ev) ev))
   arch love-arch                         ; the host CPU as the assembler target ('x64 / 'a64), already a nom; glaze loads only on these
   x86? (= arch 'x64)                 ; gates the still-x86-only lanes (float result, counted loops, float grids)
   ; the emitter's expression grammar over var v, exact arity: (+ x 1 2) is a tower, not x + 1
   (exprp e v) (? (e = v) 1  (whole? e) 1  (atom? e) 0
                  (e @ (op a b) (elem op '(+ - * // % & | ^ < <= > >= =) && exprp a v && exprp b v)
                       ('? c a b) (exprp c v && exprp a v && exprp b v)
                       0))
   ; --- leaf: (\ x E) ---
   (qual ['\ x E]) (nom? x && exprp E x)
   ; --- arity-N leaf: (\ p0 .. p_{n-1} E), E over the params (any distinct symbols) ---
   (exprn ps e) (? (elem e ps) 1  (whole? e) 1  (atom? e) 0
                   (e @ (op a b) (elem op '(+ - * // % & | ^ < <= > >= =) && exprn ps a && exprn ps b)
                        ('? c a b) (exprn ps c && exprn ps a && exprn ps b)
                        0))
   (distinctp l) (l @ (a . u) (!(elem a u) && distinctp u) 1)                ; no repeated param
   (qualn ('\ . u)) (: ps (init u)  body (last u)
                       (all nom? ps && 1 < #ps && distinctp ps && exprn ps body))
   ; --- loop: the counted-sum skeleton (\ N ((: (go i a) (? (cmp i N) (go (+ i 1) (op a B)) a)) 0 a0)) ---
   ;     the pattern is exact at every level: one extra operand anywhere is a different program
   (loopinfo lam)
    (lam @ ['\ N [[': [GO I A] ['? [cmp I N] [GO ['+ I 1] [op A B]] A]] 0 z2]]
          (nom? N && nom? GO && nom? I && nom? A && I !== A
           && elem cmp '(< <= > >= =)                             ; the loop-test comparison
           && elem op '(+ *) && z2 = (foldinit op)                ; the fold op, a0 its identity (0 / 1)
           && exprp B I                                              ; the summed term, over i
           ? [B I op cmp] 0)
          0)
   ; --- call-out loop: loopinfo's shape, with the per-step term a call (F ARG) rather than arithmetic.
   ; answers (F op i ARG); the caller resolves F and compiles arg for the callout arg (emit.l jitcalloutx).
   (calloutinfo lam)                                                    ; the one param means F is free, hence a global
    (lam @ ['\ N [[': [GO I A] ['? [cmp I N] [GO ['+ I 1] [op A [F ARG]]] A]] 0 z2]]
          (nom? N && nom? GO && nom? I && nom? A && I !== A
           && elem cmp '(< <= > >= =)
           && elem op '(+ *) && z2 = (foldinit op)
           && nom? F && F !== I && F !== A && F !== N && exprp ARG I
           ? [F op I ARG] 0)
          0)
   ; --- the same sum-over-(F i), with F and the bound N read from the [imps args] frame instead of baked:
   ; a captured import (ala prepends the imp) or a genuine multi-arg. answers (Fidx Nidx op ARG).
   (calloutinfo-frame lam)
    (: ps (init >lam)
       ((last >lam) @ [[': [GO I A] ['? [cmp I N] [GO ['+ I 1] [op A [F ARG]]] A]] 0 z2]
          (two? lam && <lam = '\ && 1 < #ps && all nom? ps && distinctp ps   ; >=2 frame params
           && nom? GO && nom? I && nom? A && I !== A
           && elem cmp '(< <= > >= =)
           && elem op '(+ *) && z2 = (foldinit op)
           && elem N ps && N !== I && N !== A                            ; the bound is a frame param
           && nom? F && elem F ps && F !== I && F !== A && F !== N      ; ... and so is the callout head
           && exprp ARG I
           ? [(posof F ps 0) (posof N ps 0) op ARG] 0)
          0))
   (njit-loop lam B cv op cmp interp) (nif (emit (loopcode B cv op cmp arch)) interp lam 1)
   ; --- general n-variable loop: (\ n ((: (go v0..vk) (? T (go U..) R)) I0..Ik)),
   ; up to 3 loop vars + arbitrary update exprs -- this is the shape iterative fib/tak
   ; take (i,a,b with updates b and a+b), not just the fold skeleton above.
   (loopinfo-n lam)
    (lam @ ['\ N ([': (GO . vars) ['? T (GO . updates) R]] . inits)]
          (: fr (N . vars)                                            ; cgl frame: {n, v0..vk}
             (nom? N && nom? GO && two? vars && all nom? vars && distinctp vars
              && !(elem GO vars) && #vars < 4                      ; <= 3 loop vars (register limit)
              && #updates = #vars && #inits = #vars
              && elem <T '(< <= > >= =) && exprn fr T              ; test a comparison over {n,vars}
              && all (u \ exprn fr u) updates && exprn fr R           ; updates + result exprs over {n,vars}
              && all whole? inits                                     ; inits are fixnum consts
              ? [vars updates T R inits] 0))
          0)
   ; --- c-finite bignum deopt: a constant-coefficient linear recurrence with a
   ;     canonical counter (init 0, step (c + 1), test (c < n)) closes to m^n x0, O(log n) -- so only
   ;     njit-loop-n's post-overflow path changes. linearity is a structural certificate, read off the
   ;     syntax by cf-lin: anything non-linear or non-canonical declines to `interp`. the state carries a
   ;     trailing `1` coordinate so an affine update reads linear, and M's last row [0..0 1] keeps it.
   (cf-nul? l)     !(two? l)
   (cf-zeros m)    (? (m = 0) () (0 . cf-zeros (m - 1)))
   (cf-unit m i)   (: (go j) (? (j < m) ((? (j = i) 1 0) . go (j + 1)) ()) (go 0))      ; e_i in dim m
   (cf-const m k)  ((cf-zeros (m - 1)) + [k])                                             ; [0..0 k]
   (cf-idx l v)    (: (go xs i) (? (cf-nul? xs) -1 (= <xs v) i (go >xs (i + 1))) (go l 0))
   (cf-dot a b)    (? (cf-nul? a) 0 ((<a * <b) + (cf-dot >a >b)))
   (cf-rowf f a b) (? (cf-nul? a) () (f <a <b . cf-rowf f >a >b))  ; elementwise
   (cf-scale k r)  (map (x \ k * x) r)
   (cf-const? r)   (all (x \ x = 0) (init r))                                              ; pure constant row
   (cf-lin vs e)                                                                            ; e -> augmented coeff row, or () if not integer-affine
    (: m (#vs + 1)
       (? (whole? e) (cf-const m e)
          (nom? e)  (: i (cf-idx vs e) (? (i < 0) () (cf-unit m i)))                        ; a state var -> e_i ; else (e.g. n) decline
          (two? e && elem <e '(+ -) && 3 = #e)
            (: a (cf-lin vs <>e) b (cf-lin vs <>>e)
               (? (cf-nul? a || cf-nul? b) () (cf-rowf (? (= <e '+) (\ x y (x + y)) (\ x y (x - y))) a b)))
          (two? e && (= <e '*) && 3 = #e)                                     ; a product is linear only if a side is constant
            (: a (cf-lin vs <>e) b (cf-lin vs <>>e)
               (? (cf-nul? a || cf-nul? b) ()
                  (cf-const? a) (cf-scale (last a) b)
                  (cf-const? b) (cf-scale (last b) a)
                  ()))                                                                       ; var*var -> nonlinear -> decline
          ()))
   (cf-mat vs ups) (: m (#vs + 1) rows (map (u \ cf-lin vs u) ups)
                      (? (any cf-nul? rows) () (rows + [(cf-unit m (m - 1))])))           ; () if any update is non-linear
   (cf-id m)       (: (go i) (? (i < m) (cf-unit m i . go (i + 1)) ()) (go 0))
   (cf-tpose M)    (? (cf-nul? <M) () (map cap M . cf-tpose (map cup M)))
   (cf-mv M v)     (map (r \ cf-dot r v) M)
   (cf-mul A B)    (: Bt (cf-tpose B) (map (r \ map (c \ cf-dot r c) Bt) A))
   (cf-mpow M n)   (: D #M (go p acc base)
                      (? (p = 0) acc (: b2 (cf-mul base base) (? (1 = (p % 2)) (go (p // 2) (cf-mul acc base) b2) (go (p // 2) acc b2))))
                      (go n (cf-id D) M))                                                    ; m^n by repeated squaring, O(log n) matmuls
   (cf-aug inits)  (inits + [1])                                                          ; x0 = [inits.. 1]
   (cf-canon? lam vs ups test inits)                                                        ; counter c -> exactly n trips (the lambda param)?
    ((two? test) && (= <test '<) && (3 = #test) && (= <>>test <>lam)
     && (: c <>test i (cf-idx vs c)
           ((i >= 0) && ((inits i) = 0)
            && (: u (ups i) (two? u && (= <u '+) && 3 = #u && (= <>u c) && <>>u = 1)))))
   ; matrix power if linear+canonical, else the caller's own deopt target `interp` -- never
   ; (base-ev lam) here, which under the natjit hook would re-enter ala
   (cf-deopt lam vs ups test result inits interp)
    (: M (cf-mat vs ups) rrow (cf-lin vs result)
       (? (cf-canon? lam vs ups test inits && !(cf-nul? M) && !(cf-nul? rrow))
          (n \ cf-dot rrow (cf-mv (cf-mpow M n) (cf-aug inits)))            ; the matrix-power closure is itself bytecode under the hook -- its body isn't leaf/loop grammar, so no re-entry
          interp))
   (njit-loop-n lam vars updates test result inits interp)
    (nif (emit (loopcode-n <>lam vars updates test result inits arch)) (cf-deopt lam vars updates test result inits interp) lam 1)
   ; --- captured-closure constructor (\ p (\ q E)): compiled as the flat 2-param native, whose partial
   ; application at p is =/show-identical to the interpreter's own partial. a curry-equivalent form.
   (qualc ['\ p ['\ q E]]) (nom? p && nom? q && p !== q && exprn [p q] E)
   (flatc ['\ p ['\ q E]]) ['\ p q E]                          ; (\ p (\ q E)) -> (\ p q E)
   ; --- float-result leaf (\ x <fexpr>): a body that boxes a gem, over +-*/ on a fixnum param and
   ;     float/int consts. soundness turns on when the param floats -- native cvtsi2sd's it at every use,
   ;     where the interpreter keeps an integer subexpression exact until a float forces promotion, so
   ;     ((x * 3) + 1.5) diverges at x=2^53+1. fty types each node F / I / 0(reject) and allsafe demands
   ;     the param never sit inside an I-typed compound, which lands the two promotion points together.
   (fty e v) (? (e = v) 'I  (gem? e) 'F  (whole? e) 'I                     ; param/int = I, float const = F
                (e @ (('+ || '- || '*) a b)                                ; +-*: float iff an operand is float
                       (: ta (fty a v) tb (fty b v)
                          (? (= ta 0 || (= tb 0)) 0  (= ta 'F || (= tb 'F)) 'F 'I))
                     ['/ a b]                                              ; /: float-division ok; int/int is value-dependent -> reject
                       (: ta (fty a v) tb (fty b v)
                          (? (= ta 0 || (= tb 0)) 0  (= ta 'F || (= tb 'F)) 'F 0))
                     0))
   (allsafe e v) (? !(occurs? v e) 1  (atom? e) 1  (= (fty e v) 'I) 0    ; an I-typed compound holding the param -> late promotion -> reject
                    (allsafe <>e v && allsafe <>>e v))
   (qualfr ['\ v body]) (nom? v && (= (fty body v) 'F) && allsafe body v)   ; a float result, param floated everywhere
   ; --- the grid nest, D-dimensional: a letrec of D counted-loop defs wrapping a float recurrence.
   ; the recurrence self-recurses under an (&& (it < LIM) (cmp TEST BOUND)) escape test; each loop def
   ; is (? (cnt < N) (self ..outer.. (cnt + 1) ..(acc + INNERCALL)..) acc), the outermost driven by a
   ; trailing (driver 0 ..). autonat walks the chain for D bounds + counters, splits the recurrence into
   ; M invariants / N float-vars, and builds the whole grid via jitfgridn. M+N<=6 is the xmm budget.
   (anat-defs bs) (? (atom? >bs) [() <bs]             ; a : binding list -> (pairs body); pairs = ((nameform . body)..)
                     (: r (anat-defs >>bs)
                        [((<bs . <>bs) . <r) <>r]))
   (afind pred l) (? (atom? l) () (pred <l) <l (afind pred >l))
   ; the recurrence pair: a (? (&& ..) (SELF ..) ..) whose then-branch self-calls (head = its own name)
   (anat-rec? p) (: nm <<p
                    (>p @ ['? cond then _]
                        (two? cond && (= <cond '&&) && two? then && (= <then nm))
                        0))
   ; anat-callee: the next-inner function a loop def calls -- innercall's head in (? (cnt < N)
   ; (self .. (acc + INNERCALL)) acc) -- or () if the pair doesn't match the loop shape. The outermost
   ; loop is the one no other loop names (the driver reaches it -- maybe wrapped, e.g. (bench .. (g 0 0))).
   (anat-callee q)
    (>q @ ['? _ then _]
        (? !(two? then) ()
           ((last >then) @ ['+ _ ic] (? (two? ic) <ic ()) ()))
        ())
   ; loopchain: walk loopnm's pair -- (? (cnt < N) (self ..(acc + INNERCALL)..) acc) -- record
   ; (cnt N rec-args), recursing on innercall's head until it reaches the recurrence recnm. The list
   ; runs outer->inner; () on any structural mismatch (so autonat bails to the unchanged form).
   (loopchain loopnm pairs recnm)
    (: p (afind (q \ (= <<q loopnm)) pairs)
       (? !(two? p) ()
          (>p @ ['? ['< cnt bnd] then _]
              (? !(two? then) ()
                 ((last >then) @ ['+ _ ic]
                     (? !(two? ic) ()
                        (= <ic recnm) [[cnt bnd >ic]]                    ; innermost: the recurrence call's args
                        (: rest (loopchain <ic pairs recnm)                ; else recurse on the next loop
                           (? (two? rest) ([cnt bnd ()] . rest) ())))
                     ()))
              ())))
   ; rebind: rebuild a : binding list, replacing the outermost loop's body with (native 0)
   (anat-rebind bs outernm ng)
    (? (atom? >bs) bs
       (: nm <bs bd <>bs
          (nm . ((? (two? nm && (= <nm outernm)) [ng 0] bd) . anat-rebind >>bs outernm ng))))
   ; --- a group of mutually-recursive arithmetic fns in a `:`, each body in the integer fragment
   ; `groupok?` accepts: param | int | (op E E) | (cmp E E) | (? E E E) | (g E..), g any member of
   ; matching arity. autogroup takes the maximal closed subset -- a fn calling out of the fragment
   ; drops, taking its callers with it -- and rewrites each binding to its own native (jitgroupir), so
   ; a reference from anywhere resolves to native while the calls among the group stay in the buffer.
   ; --- lambda-lifting: a fn body (NL inits..), nl = (: (g q..) GBODY), is a local loop; lift g to a
   ;     top-level (g' FV.. q..) with fv the enclosing params free in gbody, threaded through g's own
   ;     self-calls, and leave the body as (g' FV.. inits..) -- so the loop joins the group's call graph.
   ;     one level only; a non-named-let body passes through untouched.
   (occurs? s e) (? (two? e) (foldl (\ a x (a || occurs? s x)) 0 e) (= e s))                  ; s occurs (syntactically) in e?
   (subst-call g gn fv e) (? (two? e) (? (= <e g) (gn . fv + (map (x \ subst-call g gn fv x) >e))   ; (g A..) -> (gn fv.. A'..)
                                          (map (x \ subst-call g gn fv x) e)) e)
   (named-let? e) ((two? e) && (: nl <e                                                      ; e = ((: (g q..) GBODY) inits..) ?
                      ((two? nl) && (= <nl ':) && (two? >nl)
                       && (: gnf <>nl
                             ((two? gnf) && (nom? <gnf) && (1 < #gnf) && (all nom? >gnf) && (distinctp >gnf)
                              && (two? >>nl) && !(two? >>>nl)               ; (: (g q..) GBODY), body-less (one binding)
                              && (#>e = #>gnf))))))                       ; inits arity == g's arity
   (subst-sym nm val e) (? (= e nm) val (two? e) (map (x \ subst-sym nm val x) e) e)            ; symbol nm -> val in e
   ; norm-let: a fn body (: aux.. (g q..) GBODY (g inits..)) -- value aux bindings, one local fn, a call
   ; result -- normalizes to the named-let ((: (g q..) GBODY[aux inlined]) inits..) that lift handles.
   ; the aux bindings are dropped, each leaving with its value, so auxclose closes the values against
   ; each other left to right; every use is a copy, hence only a dcheap? value goes -- a call would
   ; recompute at each use and an allocating one would hand each use a buffer of its own.
   (auxclose aps) (foldl (\ acc ap (acc + [(<ap . (foldl (\ b q (subst-sym <q >q b)) >ap acc))])) () aps)
   (auxinl aps x) (foldl (\ b ap (subst-sym <ap >ap b)) x (auxclose aps))
   (norm-let body)
    (? !(two? body && (= <body ':) && !(atom? >body)) body
       (: parsed (anat-defs >body) pairs <parsed result <>parsed
          fnps (filter (pr \ two? <pr) pairs) auxps (filter (pr \ !(two? <pr)) pairs)
          (? !(1 = #fnps && two? result) body                                         ; need exactly one local fn + a call result
             !(all (ap \ dcheap? >ap) auxps) body                                          ; a call-valued aux does not copy -> leave the let alone
             (: g <<<fnps q ><<fnps gbody ><fnps
                (? !(= <result g && #>result = #q) body            ; result must be (g inits..) matching arity
                   (: inl (x \ auxinl auxps x)                                             ; inline every aux name -> its closed value
                      ((': . ((g . q) . (inl gbody . ()))) . map inl >result)))))))
   (lift-pair p)                                                                                  ; (nameform . body) -> (rewritten-pair newdefs)
    (: nf <p pbody (norm-let >p)
       (? !(two? nf && nom? <nf && 1 < #nf && named-let? pbody) [p ()]
          (: F <nf P >nf  nl <pbody inits >pbody
             gnf <>nl g <gnf q >gnf GBODY <>>nl
             gn (name (string F + "_" + string g))                                        ; lifted name F_g (unique per enclosing fn)
             fv (filter (pp \ occurs? pp GBODY && !(elem pp q)) P)                        ; enclosing params free in gbody
             [(nf . (gn . fv + inits))                                                 ; F's body -> (gn fv.. inits..)
               [((gn . fv + q) . subst-call g gn fv GBODY)]])))                       ; new def: (gn fv.. q..) . gbody'
   (unpair ps body) (? (atom? ps) [body] (: pr <ps (<pr . (>pr . unpair >ps body))))    ; pairs + body -> a : binding list
   (lift form)                                                                                    ; lambda-lift every named-let fn body in a `:`
    (? !(two? form && (= <form ':) && !(atom? >form)) form
       (: parsed (anat-defs >form) pairs <parsed body <>parsed
          results (map lift-pair pairs)
          allpairs ((map cap results) + (foldl (\ a r (a + <>r)) () results))            ; rewritten originals ++ all the lifted defs
          hasbody (1 = (#>form % 2))
          (': . (? hasbody (unpair allpairs body) (cbflat allpairs)))))                       ; body-less in, body-less out
   ; --- partial lift (plift): hoist a read-only loop fn out of a nested `:` body to the top level,
   ;     threading its captures as leading params -- the sibling case lift can't reach, where a read loop
   ;     sits among allocating siblings that must stay interpreted. read-only means no pin/link/tablet/
   ;     cask/say, since a write cannot hoist past the interpreted fills it interleaves with; and the loop
   ;     must be self-recursive with no sibling call. the lifted fn gets the same captures by value.
   roalloc '(pin pull . tablet hash cask say pour jug tap put puts putc putn putx flush dot see sip slurp sound read reads rand randf twirl catch scare ev)   ; allocating/mutating/IO heads -- a `_`-bound one is an effect that must not be dropped or hoisted
   (uses-head? hs e) (? (two? e) (elem <e hs || foldl (\ a x (a || uses-head? hs x)) 0 >e) 0)
   (fnpair? pr) (: nf <pr (two? nf && nom? <nf && 1 < #nf && all nom? >nf && distinctp >nf))  ; (g q..) define-sugar
   (roloop? pr sibs) (: g <<pr body >pr                                                 ; a hoistable read-only self-loop
      ((fnpair? pr) && (occurs? g body) && !(uses-head? roalloc body)
       && !(any (s \ !(= s g) && occurs? s body) sibs)))                              ; calls no sibling fn
   ; --- write-loop, the map update-in-place lane: (g i) (? COND (: k.. _ (pin H k V) (g STEP)) H), a
   ;     read-modify-write self-loop over a captured map whose only effect is that one in-place pin.
   ;     plift hoists it like a roloop, but the hoisted body threads the pin into the recursive call's H
   ;     slot as (mpin H k V) -- mpin writes and answers H -- and the base H becomes 0, since native
   ;     returns a fixnum, not the pointer the nif would tag. sound only where H's result is discarded at
   ;     every call site, which bumpok? enforces; a missing key deopts.
   (wmaph pr sibs) (: g <<pr body >pr                                                   ; the captured map H of an rmw write-loop pr, else ()
      (? !((fnpair? pr) && (occurs? g body) && !(any (s \ !(= s g) && occurs? s body) sibs)
             && (two? body) && (= <body '?) && (4 = #body)) ()
         (: THEN (opd body 1) BASE (opd body 2)
            (? !(nom? BASE && two? THEN && (= <THEN ':) && !(atom? >THEN)) ()
               (: pp (anat-defs >THEN) binds <pp call <>pp
                  pinpr (afind (b \ (: v >b (two? v && (= <v 'pin) && 4 = #v && (= <>v BASE)))) binds)
                  (? ((two? pinpr)
                      && (all (b \ (= b pinpr) || !(uses-head? roalloc >b)) binds)   ; the only effect is that one pin
                      && (two? call) && (= <call g)) BASE ()))))))                            ; tail self-call (H is captured pre-lift; wthread threads it via the recursive call after plift adds it)
   (wthread g gn fv H pr) (: body >pr COND (opd body 0) THEN (opd body 1)                    ; the threaded hoisted body for a write-loop (still peep/pin -> interpretable; mapfix rewrites to mpeep/mpin later)
      pp (anat-defs >THEN) binds <pp call <>pp
      pinpr (afind (b \ (: v >b (two? v && (= <v 'pin) && (= <>v H)))) binds)
      pv >pinpr K (opd pv 1) V (opd pv 2)
      others (filter (b \ !(= b pinpr)) binds)
      inl (e \ auxinl others e)                                                     ; inline the pure value-binds (e.g. k), closed against each other
      nc (map (x \ (= x H) ? ['pin H (inl K) (inl V)] x) (subst-call g gn fv call))          ; (gn fv.. STEP) with H's slot threaded as (pin H k v) -- pin writes and returns H, threading the map
      ['? (subst-call g gn fv COND) nc 0])                                                       ; base -> 0 (the map result is discarded -- bumpok?)
   (other-use? nm self ipairs ibody) (occurs? nm ibody || any (pr \ !(= pr self) && occurs? nm >pr) ipairs)   ; nm used outside its own binding?
   (bumpok? g defpr ipairs ibody)                                                                ; every (g ..) call (besides g's def) is a discarded whole-binding value
    (!(occurs? g ibody)
     && (all (pr \ (= pr defpr) || !(occurs? g >pr)
                    || (!(fnpair? pr) && (: v >pr (two? v && (= <v g))) && !(other-use? <pr pr ipairs ibody))) ipairs))
   (subst-pairs g gn fv pairs) (map (pr \ <pr . subst-call g gn fv >pr) pairs)    ; rewrite (g A..) in every pair's value
   (plift-fn Fpair)                                                                               ; ((F P..) . FBODY) -> `(Fpair' newdefs)
    (: nf <Fpair FBODY >Fpair
       (? !(two? nf && nom? <nf && two? FBODY && (= <FBODY ':) && !(atom? >FBODY)) [Fpair ()]
          (: F <nf P >nf
             parsed (anat-defs >FBODY) ipairs <parsed ibody <>parsed
             sibnames (map caap (filter fnpair? ipairs))                                           ; all inner fn names
             valnames (map cap (filter (pr \ !(fnpair? pr)) ipairs))                            ; inner value-binding names (bare symbols)
             wlifts (filter (pr \ nom? (wmaph pr sibnames) && bumpok? <<pr pr ipairs ibody) ipairs)   ; the hoistable write-loops (map RMW, discarded result)
             mapsz (foldl (\ m w (: H (wmaph w sibnames) bd >w                                  ; presize: each write-loop's map H -> its counted bound N
                            cnd (? (two? bd && (= <bd '?)) (opd bd 0) ())
                            N (? (two? cnd && (= <cnd '<)) (opd cnd 1) ())                   ; cond (i < N) -> the bound
                            (? (nom? H && !(= N ())) ((H . N) . m) m))) () wlifts)       ; so `(tablet 0)` -> `(tablet N)`: the native inserts never grow
             lifts ((filter (pr \ roloop? pr sibnames) ipairs) + wlifts)
             (? (atom? lifts) [Fpair ()]
                (: remain (filter (pr \ !(any (lp \ (= pr lp)) lifts)) ipairs)                ; the non-lifted inner bindings (by identity)
                   specs (map (pr \ <<pr                                               ; per lift a spec (g gn fv..): name, hoisted name F_g, captures
                               . ((name (string F + "_" + string <<pr))
                                     . (filter (s \ !(= s '_) && !(elem s ><pr) && occurs? s >pr) (P + valnames)))) lifts)   ; `_` is the throwaway/effect binding -- the loop body rebinds it locally (the pin slot), never captures the enclosing one
                   (presz pr) (? (fnpair? pr) pr (: ms (afind (x \ (= <x <pr)) mapsz) v >pr   ; a map binding `(H (tablet 0))` -> `(H (tablet N))`
                                  (? (two? ms && two? v && (= <v 'tablet)) (<pr . ['tablet >ms]) pr)))    ; presize `(tablet N)` so the N native inserts never grow
                   rwp (map presz (foldl (\ ps sp (subst-pairs <sp <>sp >>sp ps)) remain specs))   ; rewrite (g A..) calls through every spec, then presize the maps
                   rwb (foldl (\ b sp (subst-call <sp <>sp >>sp b)) ibody specs)       ; ... and in the trailing body
                   newdefs (map (sp \ (: lp (afind (pr \ (= <<pr <sp)) lifts)            ; the hoisted def: (gn fv.. q..) . body'[g->gn]
                                  wl (any (w \ (= w lp)) wlifts)                                   ; a write-loop -> threaded body; else the plain read-only rename
                                  ((<>sp . >>sp + ><lp)
                                     . (? wl (wthread <sp <>sp >>sp (wmaph lp sibnames) lp)
                                           (subst-call <sp <>sp >>sp >lp))))) specs)
                   [(nf . (': . unpair rwp rwb)) newdefs])))))
   (plift form)                                                                                   ; hoist read-only loops out of every top-level fn's nested :
    (? !(two? form && (= <form ':) && !(atom? >form)) form
       (: parsed (anat-defs >form) pairs <parsed body <>parsed
          results (map plift-fn pairs)
          extradefs (foldl (\ a r (a + <>r)) () results)
          hasbody (1 = (#>form % 2))
          (? (atom? extradefs) form
             (: allp ((map cap results) + extradefs)
                (': . (? hasbody (unpair allp body) (cbflat allp))))))) ; body-less in -> body-less out
   ; --- map lane (mapfix): a group fn's param that is peep'd but never tally'd is a map, not a string,
   ;     so its (peep h k d) becomes (mpeep h k d) and the emitter lays an open-addressed probe. the
   ;     heuristic is backstopped by the entry's mapkind guard -- a non-map arg deopts to interp.
   (puse? e P) (? (two? e) (? (= <e 'peep && (= <>e P)) 1 (foldl (\ a x (a || puse? x P)) 0 >e)) 0)   ; P used as (peep P k d)?
   (tuse? e P) (? (two? e) (? (= <e 'tally && (= <>e P)) 1 (foldl (\ a x (a || tuse? x P)) 0 >e)) 0)   ; P used as (tally P)?
   (peep->mpeep P e) (? (two? e) (? (= <e 'peep && (= <>e P)) ('mpeep . map (x \ peep->mpeep P x) >e) (map (x \ peep->mpeep P x) e)) e)
   (pin->mpin P e)   (? (two? e) (? (= <e 'pin && (= <>e P)) ('mpin . map (x \ pin->mpin  P x) >e) (map (x \ pin->mpin  P x) e)) e)   ; a map param's (pin P k v) update -> (mpin P k v); a cask param is pin'd-not-peep'd so never in mps
   (mapfix-def def) (: nf <def body >def
      mps (filter (P \ puse? body P && !(tuse? body P)) >nf)                              ; this fn's map params (peep'd, not tally'd)
      (nf . foldl (\ b P (pin->mpin P (peep->mpeep P b))) body mps))
   ; --- string-builder fusion (castbuild): (: (g v.. s ..) (? COND (g u.. (s + X) ..) s) (g i.. "" ..))
   ;     builds a string by repeated append, and each `+` copies the whole prefix -- an O(n^2) build. the
   ;     clean single-byte counted case lowers to a native cask-fill (cbcask below); the general case here
   ;     threads a `jug` -- the memory output port -- in the accumulator's own loop slot, said into per step
   ;     and drained once at the base. threading it as a loop var rather than an aux let is what survives
   ;     autogroup's purity-assuming inliners, which would substitute an aux (jug 0) into both use sites and
   ;     reborn it empty each step. sound because (say s (string X)) reproduces +'s string coercion exactly.
   ;     the guard demands a pure append accumulator: init "", s only as the left operand of (s + X) in the
   ;     self-call's slot and as the base result -- not in the test, not in X, not in a sibling's arg.
   (cbquote? x) (two? x && (= <x '\) && 2 = #x)                       ; (\ datum) -- quoted data, don't descend
   (cbsay? x)   (string? x || (two? x && (= <x 'string) && 2 = #x)) ; already string-valued -> say x as-is
   (cbcall? e g ar) (two? e && (= <e g) && #>e = ar)             ; e a self-call (g ..) of arity ar
   (cbset l i v) (? (i = 0) (v . >l) (<l . cbset >l (i - 1) v))  ; l with index i replaced by v
   (cbnotelse? s as si) (foldl (\ a j (a && (? (j = si) 1 !(occurs? s (as j))))) 1 (rangeL 0 #as))   ; s in no arg but si
   (cbacc nf)                                                                        ; -> (si X g q COND RECUR recur-is-then?) on a match, else ()
    (? !(named-let? nf) ()
       (: nl <nf inits >nf gnf <>nl g <gnf q >gnf B <>>nl    ; B = the loop body
          (? !(two? B && (= <B '?) && 4 = #B) ()                   ; B = (? COND e1 e2)
             (: ar #q c (opd B 0) e1 (opd B 1) e2 (opd B 2)
                rth (cbcall? e1 g ar) r (? rth e1 (cbcall? e2 g ar) e2 ()) base (? rth e2 e1)   ; which branch is the tail self-call; the other is the base
                (? !(two? r && nom? base && elem base q) ()                ; need a self-call branch + a param-returning base
                   (: si (posof base q 0) sa (>r si) IN (inits si)
                      (? !(two? sa && (= <sa '+) && 3 = #sa && (= (opd sa 0) base)) ()   ; arg_si = (s + X)
                         (: X (opd sa 1)
                            (? (string? IN && 0 = #IN && !(occurs? base c) && !(occurs? base X) && cbnotelse? base >r si)
                               [si X g q c r rth] ())))))))))                        ; init "" + s only in (s + X)@si and the base
   (cbrw nf [si X g q c r rth])                                                  ; the threaded-jug rewrite: the accumulator param becomes a jug, init (jug 0)
    (: inits >nf  s (q si)                                                      ; s = the accumulator param (now the jug, threaded unchanged)
       app  (? (cbsay? X) ['say s X] ['say s ['string X]])                        ; (say s X) | (say s (string X)) -- mirrors (s + X)
       r2   (': . ['_ app (g . cbset >r si s)])                        ; (: _ (say s ..) (g ..s..)) -- pass the jug unchanged
       b2   (? rth ['? c r2 ['slurp s]] ['? c ['slurp s] r2])                    ; keep the original branch orientation; base -> (slurp s)
       (': . [(g . q) b2 (g . cbset inits si '(jug 0))]))                ; (: (g q..) b2 (g ..(jug 0)..)) -- the jug born once at the call
   (cbwalk e) (? (atom? e) e  (cbquote? e) e
                 (: nf (norm-let e) info (cbacc nf) (? (two? info) (cbrw nf info) (map cbwalk e))))
   ; --- the native cask variant: a clean single-byte counted builder, i:0-by-1 the cask index and the
   ;     appended E a charm expr, compiled to a counted byte-store. the cask cannot come back from native
   ;     -- the epilogue tags rax as a fixnum and would mangle the pointer -- so the loop lifts to a
   ;     sibling F-fill answering the count, with the cask threaded as a buf param, and the wrapper F
   ;     holds the cask and converts it. multi-char appends, other counters and the else-orientation fall
   ;     back to the threaded jug.
   (cbbyte? e i) (? (whole? e) 1  (= e i) 1  (two? e && (= <e 'peep)) 1                ; a charm expr: const | the counter | a peep byte | arith thereof
                    (two? e && elem <e '(+ - * // % & | ^ << >>) && 3 = #e) (cbbyte? (opd e 0) i && cbbyte? (opd e 1) i) 0)
   (cbcask nlval nf)                                                                              ; -> (wrapper-pair fill-pair) on a clean single-byte counted match, else ()
    (? !(two? nf && nom? <nf && 1 < #nf) ()                                    ; nf must be (F p..) so we can sibling the fill
       ((cbacc nlval) @ [si X g q cond r rth]
          (: inits >nlval
             (? !(rth && (two? cond) && (= <cond '<) && (3 = #cond) && (elem (opd cond 0) q)   ; recur-then; cond = (i < n)
                   && (two? X) && (= <X 'string) && (2 = #X) && (cbbyte? (opd X 0) (opd cond 0))) ()   ; append = (string E), E a charm in the counter
                (: i (opd cond 0) n (opd cond 1) ci (posof i q 0) E (opd X 0) rargs >r ia (rargs ci)
                   (? !(0 = (inits ci) && two? ia && (= <ia '+) && 3 = #ia && (= (opd ia 0) i) && 1 = (opd ia 1)) ()   ; counter init 0, step (i + 1)
                      (: F <nf Fp >nf s (q si) fillnm (name (string F + "-fill")) cbn (name (string F + "-cb"))
                         fv (filter (p \ occurs? p cond || occurs? p r) Fp)               ; enclosing params the loop reads
                         fbody ['? cond (fillnm . fv + (cbset rargs si ['pin s i E])) i]     ; (? COND (F-fill fv.. (i + 1) (pin s i E)) i)
                         wbody (': . [cbn ['cask n] '_ (fillnm . fv + (cbset inits si cbn)) ['string cbn]])
                         [(nf . wbody) ((fillnm . fv + q) . fbody)])))))
          ()))
   (cbcpair p) (: info (cbcask (norm-let >p) <p) (? (two? info) info [(<p . cbwalk >p)]))    ; cask variant, else keep (jug via cbwalk)
   (cbflat ps) (? (atom? ps) () (: pr <ps (<pr . (>pr . cbflat >ps))))   ; pairs -> a binding list, no trailing body (preserves a body-less `:`)
   (castbuild form)
    (? !(two? form && (= <form ':) && !(atom? >form)) (cbwalk form)              ; a `:` group: try the cask variant per binding (adds F-fill siblings); else the in-place walk
       (: parsed (anat-defs >form) pairs <parsed body <>parsed
          newpairs (foldl (\ a r (a + r)) () (map cbcpair pairs))
          (? (1 = (#>form % 2)) (': . unpair newpairs (cbwalk body))             ; odd count -> has a body
             (': . cbflat newpairs))))                                                       ; even -> body-less, which leaks its bindings globally: keep it so
   ; fold-consts: inline a top-level `:`'s whole-constant value bindings (e.g. strscan's `hmod 1000000007`)
   ; into every body and drop them -- so a folded constant doesn't read as an un-glazeable free symbol.
   ; a pair's own params -- the sugared head's tail, or a lambda value's -- shadow a
   ; same-named sibling throughout its body, so no inliner may substitute one there
   (prps pr) (? (two? <pr) ><pr (two? >pr && (= <>pr '\)) (ho-initl >>pr) ())
   (fold-consts form)
    (? !(two? form && (= <form ':) && !(atom? >form)) form
       (: parsed (anat-defs >form) pairs <parsed body <>parsed
          consts (filter (pr \ nom? <pr && whole? >pr) pairs)
          (? (atom? consts) form
             (: sub (\ ps e (foldl (\ b pr (? (elem <pr ps) b (subst-sym <pr >pr b))) e consts))
                hasbody (1 = (#>form % 2))
                keep (? hasbody (filter (pr \ !(nom? <pr && whole? >pr)) pairs) pairs)  ; body-less: the const is exported, keep it bound
                subbed (map (pr \ <pr . sub (prps pr) >pr) keep)
                (': . (? hasbody (unpair subbed (sub () body)) (cbflat subbed)))))))
   ; --- hof inline (dehof): a non-recursive lambda-constant binding inlines into every body, and dsimp
   ;     beta-collapses the now-literal curried application -- so ((twice (adder i)) i) reduces to the
   ;     first-order arithmetic that lift+autogroup glaze, and the inlined lambdas drop like fold-consts'.
   ; desugar the binding head so `(f a..) body` decides exactly what the explicit `f (\ a.. body)` does --
   ; glazeability must not turn on how a sibling binding was spelled.
   (dehead pr) (: h <pr (? (atom? h) pr (<h . ('\ . >h + [>pr]))))    ; (f a..) body -> (f . (\ a.. body)); a plain name binding passes through (dsug is mopped post-egg)
   ; --- higher-order inference: a group fn is higher-order iff it returns a function or takes a function
   ;     param, and dehof inlines exactly those -- the group lane is first-order, so a hof can only glaze
   ;     by being inlined and collapsed. a monotone fixpoint over the call graph: func-param(f,k) = param k
   ;     is applied in operator position, or passed to a callee's func-param; func-result(f) = the body
   ;     yields a function (a lambda, a partial call, a call to a ho-result fn, a func-typed param, or a
   ;     ?-branch that does). marks ho only when provable -- a missed hof falls to interp, never to a wrong
   ;     answer. the ho-* helpers are local because the boxfix globals they would use are mopped post-egg.
   (ho-initl l) (? (atom? >l) () (<l . ho-initl >l))                         ; all but the last
   (ho-lamb? v) (two? v && (= <v '\) && 2 < #v)
   (ho-any p l) (foldl (\ a x (a || p x)) 0 l)
   (ho-memb x l) (? (atom? l) 0 (= <l x) 1 (ho-memb x >l))
   (ho-posn x l i) (? (atom? l) -1 (= <l x) i (ho-posn x >l (i + 1)))
   (ho-dedup l) (? (atom? l) () (ho-memb <l >l) (ho-dedup >l) (<l . ho-dedup >l))
   (ho-assq k l) (? (atom? l) () (= <<l k) <l (ho-assq k >l))                ; entry (k . rest) by car
   (ho-fpm nm hm) (: e (ho-assq nm hm) (? (two? e) >>e ()))                                  ; nm's func-param mask
   (ho-rf nm hm) (: e (ho-assq nm hm) (? (two? e) <>e 0))                                    ; nm returns a function?
   (ho-ar nm info) (: e (ho-assq nm info) (? (two? e) #<>e -1))                       ; nm's arity, -1 if not a group fn
   (ho-walkfp fp body hm)                                                                         ; func-param mask of fp in body
    (ho-dedup ((: (walk e acc) (? !(two? e) acc
                  (: hd <e a0 (? (ho-memb hd fp) (ho-posn hd fp 0 . acc) acc)            ; (p ..) -> p applied as a fn
                     gm (ho-fpm hd hm)
                     a1 (? (atom? gm) a0 (foldl (\ ac j (: arg (>e j) (? (ho-memb arg fp) (ho-posn arg fp 0 . ac) ac))) a0 gm))   ; our param at a callee's func-pos
                     (foldl (\ ac x (walk x ac)) a1 >e)))) body ()))
   (ho-ret? e fp fpm info hm)                                                                     ; does e yield a function?
    (? (atom? e) (ho-memb e fp && ho-memb (ho-posn e fp 0) fpm)                               ; a func-typed param
       (= <e '\) (ho-lamb? e)                                                              ; a lambda literal
       (= <e '?) (ho-any (b \ ho-ret? b fp fpm info hm) >e)                          ; a ?-branch that does
       (: hd <e ar (ho-ar hd info) (? (ar < 0) 0 (#>e < ar) 1 (ho-rf hd hm))))    ; non-group->0; partial->fn; full->g's result
   (ho-fn fp body info hm) (: fpm (ho-walkfp fp body hm) ((? (ho-ret? body fp fpm info hm) 1 0) . fpm))
   (ho-sz hm) (foldl (\ a e (a + <>e + #>>e)) 0 hm)                            ; monotone measure (rflags + |fpmask|)
   (ho-fix info hm) (monofix hm (st \ map (f \ <f . ho-fn (f 1) (f 2) info st) info) ho-sz)   ; higher-order lattice (ascending: rflags+|fpmask|) over the shared harness (prel)
   (dehof form)
    (? !(two? form && (= <form ':) && !(atom? >form)) form
       (: parsed (anat-defs >form) pairs <parsed body <>parsed
          fns (filter (p \ ho-lamb? >p) (map dehead pairs))                              ; lambda-valued (desugared) bindings = the group fns
          info (map (p \ [<p (ho-initl >>p) (last >p)]) fns)                 ; (name params body)
          hm (ho-fix info (map (f \ <f . (0 . ())) info))                            ; the higher-order fixpoint
          ho? (nm \ (: e (ho-assq nm hm) (two? e && (<>e || two? >>e))))             ; returns-fn or takes-fn -> inline it
          lamc? (pr \ (: nd (dehead pr) (ho-lamb? >nd && !(dcount <nd >nd) && ho? <nd)))   ; a non-recursive higher-order const
          lamcs0 (map dehead (filter lamc? pairs))
          ; a lamc named in another lamc's body stays bound: the fold substitutes each value as
          ; written, so a name already spent is never rewritten inside the text replacing a later
          ; one -- inlining both would leave the dropped binding dangling in that text.
          lamcs (filter (q \ !(ho-any (r \ !(= <r <q) && occurs? <q >r) lamcs0)) lamcs0)
          (? (atom? lamcs) form                                                                  ; no hof const -> leave the form for the other lanes (dsimp mangles string/cask/loop forms)
             (: sub (\ ps e (dsimp (foldl (\ b pr (? (elem <pr ps) b (subst-sym <pr >pr b))) e lamcs)))   ; inline each hof lamc the pair does not shadow, then beta-collapse
                hasbody (1 = (#>form % 2))
                ; a body-less `:` exports every binding, so an inlined hof const stays bound:
                ; its callers are outside the form (kore's verb table names bracket-main, and
                ; core.l holds its only other mention -- its own define). Dropping what we
                ; inlined is dead-binding elimination, sound for a body-having `:` -- a local
                ; let, where an unreferenced binding is unobservable -- and a deletion of the
                ; module's surface here. The inlining still lands at every call site either way.
                keep (? hasbody (filter (pr \ !(ho-any (q \ (= <q <)(dehead pr)) lamcs)) pairs)
                                pairs)                                                           ; non-inlined bindings keep their raw form (grpfix recognizes define-sugar function heads)
                subbed (map (pr \ <pr . sub (prps pr) >pr) keep)
                (': . (? hasbody (unpair subbed (sub () body)) (cbflat subbed)))))))
   ; --- church lowering (dechurch): (N f x) with N a small numeral and f a literal function is f applied
   ;     to x N times, so lower it to the nesting at compile time -- (2 (+ i) i) -> (i + i + i), pure
   ;     arithmetic the group lane glazes, where church otherwise dispatches through `num-ap` and stays
   ;     interpreted. exact: this is love's church semantics, (0 f x)=x and (1 f x)=(f x). what tells it
   ;     apart from the tower is that the operand is a function -- (2 i)/(2 5)/(2 3 4) carry a numeral, so
   ;     dch-fn? is false and they stay exponentiation. a variable count or operand rides num-ap.
   (dch-fn? f) (ho-lamb? f || (two? f && 2 = #f && elem <f '(+ - * // % & | ^)))   ; a lambda, or a dyadic-op partial like (+ i)
   (dch-ap f x) (? (ho-lamb? f) (dsimp [f x]) (f + [x]))                                            ; apply f to x: beta a lambda, extend an op-partial
   (dch-nest f n x) (? (n = 0) x (dch-ap f (dch-nest f (n - 1) x)))                                     ; f^n(x), built innermost-out
   (dch-occs v e) (? (= e v) 1  (atom? e) 0  (dquote? e) 0                                            ; occurrences of the param in the body (shadow/quote overcount = safe)
                     (foldl (\ s t (s + (dch-occs v t))) 0 e))
   ; the fat gate: beta splices the accumulated x at every param occurrence, so a body naming its param
   ; k>=2 times residualizes ~k^N nodes. unroll only while k^N stays small; a fat one rides num-ap.
   ; op-partials and multi-param lambdas never duplicate (dsimp betas unary only), so only k for a
   ; unary lambda is measured.
   (dch-fat? f n) ((ho-lamb? f) && (3 = #f)
                   && (: k (dch-occs <>f <>>f) (1 < k && 256 < (n k))))
   (dechurch e)
    (? (atom? e) e  (dquote? e) e
       (: y (map dechurch e)                                                                           ; bottom-up: lower nested church first
          (? ((3 = #y) && (whole? <y) && (0 <= <y) && (<y < 64) && (dch-fn? <>y)
              && !(dch-fat? <>y <y))
             (dch-nest <>y <y <>>y)                                       ; (N f x) -> f^N(x), the flat surface form
             ((2 = #y) && (two? <y) && (2 = #<y) && (whole? <<y) && (0 <= <<y) && (<<y < 64) && (dch-fn? <><y)
              && !(dch-fat? <><y <<y))
             (dch-nest <><y <<y <>y)                                                ; ((N f) x) -> f^N(x), the curried surface form -- ((2 (+ i)) i) and (2 (+ i) i) are the same value, so compile the same
             y)))
   ; --- local let (delet): a pure value-let (: n1 v1 .. result), every binder a distinct plain symbol,
   ;     inlines by ordered substitution into one fragment expression, so a fn that names its intermediates
   ;     joins the group. substitution preserves value and order only for a dup-cheap value (arithmetic,
   ;     cmp, peep, tally -- no call): a binding holding a call bails to the unchanged `:`, since a dup
   ;     would recompute, a 0-use drop would lose an effect, and even a 1-use move breaks the sequence law
   ;     when the call effects. delet-body walks the whole body bottom-up, so a let nested in a
   ;     sub-expression surfaces too -- a raw `:` left in arg position deopts the whole group -- and a
   ;     shadowing inner let resolves before its outer namesake substitutes. a `\` is opaque, a local-fn
   ;     binding defers to norm-let/lift, and delet runs before lift, whose free vars it must fix up.
   (dcount s e) (? (= e s) 1 (two? e) (foldl (\ a x (a + (dcount s x))) 0 e) 0)            ; syntactic occurrences of s in e
   (dcheap? e) (? (atom? e) 1  (dquote? e) 0                                                  ; dup-cheap: arith/cmp/bit/peep/tally, no call
                  (: h <e (? (= h '? || elem h '(+ - * // % & | ^ < <= > >= = peep tally)) (all dcheap? >e) 0)))
   (delet-go pairs result orig)
    (? (atom? pairs) result
       (: pr <pairs nm <pr val >pr rest >pairs
          uses (foldl (\ a e (a + (dcount nm e))) 0 ((map cup rest) + [result]))          ; uses in subsequent values + body
          (? !(dcheap? val) orig                       ; a call never inlines -- bail to the unchanged `:`
             (delet-go (map (p \ <p . subst-sym nm val >p) rest) (subst-sym nm val result) orig))))
   (delet-body e)                                                                             ; inline value-lets anywhere in a fn body (root or nested), bottom-up
    (? (atom? e) e
       (= <e '\) e                                                                     ; a quote / lambda is opaque -- never descend
       !(= <e ':) (map delet-body e)                                                ; a (?/call/arith) form -> recurse into children to reach a nested let
       (atom? >e) e                                                                      ; a bare (:) -> leave
       (: parsed (anat-defs >e) pairs <parsed result <>parsed names (map cap pairs)
          hasbody (1 = (#>e % 2))                                                  ; odd count -> a trailing result; even -> body-less (a named-let returning its fn)
          pairs2  (map (pr \ <pr . delet-body >pr) pairs)                     ; bottom-up: inline within each value (incl. a local-fn's BODY) ...
          result2 (delet-body result)                                                         ; ... and within the result
          (? (!hasbody || !(all nom? names && distinctp names) || uses-head? roalloc e) ; body-less, a local-fn `(g q..)`, or an effectful let (a `_`-bound `pin`/`say`/.. used 0x must not be dropped) -> keep the structure (parity-preserving),
               (': . (? hasbody (unpair pairs2 result2) (cbflat pairs2)))                   ; but surface a value-let nested in any body (else it survives lift -> deopt)
             (delet-go pairs2 result2 (': . unpair pairs2 result2)))))                    ; a pure value-let with a body -> inline it (a bail keeps the walked `:`, sound)
   (delet form)                                                                              ; inline value-lets in every fn body of a `:`
    (? !(two? form && (= <form ':) && !(atom? >form)) form
       (: parsed (anat-defs >form) pairs <parsed body <>parsed
          hasbody (1 = (#>form % 2))                                               ; as delet-body reads it: even is body-less
          pairs2 (map (pr \ <pr . (? (two? <pr) (delet-body >pr) >pr)) pairs)
          (': . (? hasbody (unpair pairs2 body) (cbflat pairs2)))))                      ; cbflat keeps a body-less `:` body-less
   ; --- booleans & clamps (debool): (&& a b)=(? a b a), (|| a b)=(? a a b),
   ;     (abs x)=(? (x < 0) (0 - x) x) -- a connective answers one of its operands, so both dup theirs
   ;     and reuse delet's dcheap? guard, leaving a call-valued form un-lowered. bottom-up, so nested compounds
   ;     collapse; runs inside autogroup, so autonat still sees a raw (&& (it < L) ..) escape test.
   ;     `min`/`max` are array reducers, not binary scalar ops -- (min 7 3) is (7 3), the tower -- so a
   ;     binary (min a b) is no language feature and is not lowered here.
   (dband as) (? (atom? as) 1  (atom? >as) <as  !(dcheap? <as) ('&& . as)            ; (&& a R..) = (? a (&& R..) a); a dup'd, so guard
                 ['? <as (dband >as) <as])
   (dbor as)  (? (atom? as) 0  (atom? >as) <as  !(dcheap? <as) ('|| . as)            ; (|| a R..) = (? a a (|| R..)); a dup'd, so guard
                 ['? <as <as (dbor >as)])
   (dbabs x) (? !(dcheap? x) ['abs x] ['? ['< x 0] ['- 0 x] x])                           ; (abs x) = (? (x < 0) (0 - x) x)
   ; an `@` clause's odd operands are patterns: `(b && lx-ws? b)` there is a guard, and a lowered `&&`
   ;   would ask for `b` before `b` binds, matching nothing and saying nothing. bodies lower, patterns
   ;   stay verbatim -- the guard expressions inside them included.
   (dbarms cs) (? (atom? cs) ()  (atom? >cs) [(debool <cs)]                     ; pat body .. [trailing default]
                  (<cs . ((debool <>cs) . dbarms >>cs)))
   (debool e)                                                                                   ; recursively lower &&/||/abs to ?
    (? (atom? e) e  (dquote? e) e
       (two? e && (= <e '@) && two? >e) ('@ . ((debool <>e) . dbarms >>e))
       (: y (map debool e) h (opword <y) as >y                    ; lower operands first (bottom-up); opword names a glued value head
          (? (= h '&&) (dband as)  (= h '||) (dbor as)
             (= h 'abs && 1 = #as) (dbabs <as)  y)))
   ; --- specialization (autospec): mix wired in as a recognizer -- the 1st
   ;     Futamura projection composed with the native lane. an interpreter applied to a static program (a
   ;     const-bound quoted AST) and a dynamic input specializes: the dispatch and AST navigation fold
   ;     away to the program's straight-line arithmetic, which the later passes then native. a
   ;     static-driven recursion unrolls, bounded by specall's descent guard and sfuel; a dynamic-driven
   ;     one residualizes clean. a no-op on any form with no defined-fn call over a static-data binding.
   (sstat v) ['s v]  (sdyn c) ['r c]  (sstat? p) (= <p 's)  (spval p) <>p
   (sqv v) ['\ v]                                                                 ; quote a static datum -> seen as data
   (sreify p) (: v <>p (? (sstat? p && !(constellation? v)) (sqv v) v))  ; non-number static -> quoted
   (sstatval? p v) (sstat? p && v = (spval p))
   (szipenv ps apv) (? (atom? ps) () ([<ps <apv] . szipenv >ps >apv))
   (slook env k) (? (atom? env) (sdyn k) (= k <<env) <><env (slook >env k))  ; unbound -> dynamic
   (sdeflook nm defs) (? (atom? defs) () (= nm <<defs) <defs (sdeflook nm >defs))
   (sprim? h) (elem h '(* - + ! < <= > >= = cap cup caap caup cuap cuup ==))   ; arith + comparisons + static AST navigation
   (ssimp1 h a b)
    (? (= h '* && sstatval? a 1) b   (= h '* && sstatval? b 1) a       ; drop the * and + units on a residual
       (= h '+ && sstatval? a 0) b   (= h '+ && sstatval? b 0) a
       (sdyn [h (sreify a) (sreify b)]))
   (speprim h apv)
    (? (all sstat? apv) (sstat (base-ev (h . map sqv (map spval apv))))       ; all static -> fold over quoted data
       (2 = #apv) (ssimp1 h <apv <>apv)                           ; binary -> residualize, drop units
       (sdyn (h . map sreify apv)))
   (spcondm cs env seen defs)
    (? (atom? >cs) (spe <cs env seen defs)                              ; lone else
       (: cv (spe <cs env seen defs)
          (? !(sstat? cv) (sdyn ('? . sresidcl cv <>cs >>cs env seen defs))  ; dynamic test -> residual tail
             !(spval cv) (spcondm >>cs env seen defs)                     ; static false -> drop clause
             (spe <>cs env seen defs))))                                     ; static true  -> take result
   (sresidcl cv then rest env seen defs)
    (sreify cv . (sreify (spe then env seen defs) . sresidtl rest env seen defs))
   (sresidtl cs env seen defs)
    (? (atom? >cs) [(sreify (spe <cs env seen defs))]
       (: cv (spe <cs env seen defs)
          (? !(sstat? cv) (sresidcl cv <>cs >>cs env seen defs)
             !(spval cv) (sresidtl >>cs env seen defs)
             [(sreify (spe <>cs env seen defs))])))
   ; the descent guard: an unfold re-entering a fn along the chain must strictly shrink its static
   ; weight -- the structural-recursion certificate. an AST walk shrinks its datum every level and so
   ; unfolds to the bottom; a non-descending re-entry residualizes as a plain call, still correct.
   ; a same-signature seen-set cannot see a changing static ((n - 1) never repeats) and would unroll a
   ; non-folding test to the fuel floor. `seen` threads the in-progress chain as (nm . weight) pairs.
   (ssz v) (? (two? v) ((ssz <v) + (ssz >v)) 1)                          ; total leaf count of a static datum
   (sw apv) (foldl (\ a p (? (sstat? p) (a + (ssz (spval p))) a)) 0 apv)           ; the call's static weight
   (sanc nm seen) (? (atom? seen) -1 (= nm <<seen) ><seen (sanc nm >seen))   ; nearest in-progress weight for nm (-1 = none)
   (specall def apv seen defs)                                                    ; unfold a defined-fn call, unless non-descending / out of fuel
    (: nm <def ps <>def bd <>>def sz (sw apv)
       w (sanc nm seen) n (peep sfuel 'n 0)
       (? (0 <= w && w <= sz) (sdyn (nm . map sreify apv))               ; no strict descent -> residual call
          !n (sdyn (nm . map sreify apv))                                 ; fuel out -> bail to a residual call (still correct)
          (: _ (pin sfuel 'n (n - 1)) (spe bd (szipenv ps apv) ((nm . sz) . seen) defs))))
   (spe x env seen defs)                                                          ; the partial evaluator
    (? (constellation? x) (sstat x)
       (nom? x) (slook env x)
       (atom? x) (sstat x)
       (: h <x a >x
          (? (= h '\ && atom? >a) (sstat <a)                      ; (\ datum) quote -> a static datum
             (= h '?) (spcondm a env seen defs)
             (sprim? h) (speprim h (map (e \ spe e env seen defs) a))
             (: d (sdeflook h defs)
                (? d (specall d (map (e \ spe e env seen defs) a) seen defs)
                     (sdyn (h . map sreify (map (e \ spe e env seen defs) a))))))))
   ; the residual-size gate: spe substitutes a param's residual at every occurrence, so nested unfolds
   ; share one small DAG whose tree reading is exponential -- and every downstream walker reads trees,
   ; so an over-budget residual is a hang, not a win. stsz walks with a step budget, 0 = blown.
   (stsz e n) (? (n < 1) 0 (atom? e) (n - 1) (: m (stsz <e (n - 1)) (? !m 0 (stsz >e m))))
   (smix call statenv defs) (: _ (pin sfuel 'n 100000) r (sreify (spe call statenv () defs))
                               (? (stsz r 20000) r call))   ; specialize one call -> residual source (small ones only)
   ; autospec proper: build defs (fn bindings) + statenv (names bound to a quoted datum), then replace
   ; every call to a defined fn that mentions a static name with its specialized residual (in place).
   (sconst? v) (two? v && (= <v '\) && 2 = #v)                      ; a quoted-constant binding value (\ datum)
   (sment? e statn) (? (nom? e) (elem e statn)  (two? e) (srefany? e statn)  0)
   (srefany? args statn) (? (atom? args) 0 (sment? <args statn || srefany? >args statn))
   (specall? e defn statn) (two? e && elem <e defn && srefany? >e statn)   ; defined-fn call mentioning a static name
   (swalk e statenv defs defn statn)
    (? (atom? e) e
       (dquote? e) e                                                              ; never descend into a quoted datum
       (specall? e defn statn) (smix e statenv defs)                              ; specialize this call in place
       (map (x \ swalk x statenv defs defn statn) e))                           ; walk every element (a list head holds the loop body)
   (autospec form)
    (? !(two? form && (= <form ':) && !(atom? >form)) form
       (: parsed (anat-defs >form) pairs <parsed
          fnps (filter (pr \ two? <pr) pairs)
          defs (map (pr \ <<pr . (><pr . (>pr . ()))) fnps)   ; (name (p..) body)
          statps (filter (pr \ nom? <pr && sconst? >pr) pairs)
          statenv (map (pr \ [<pr (sstat <>>pr)]) statps)         ; name -> (stat datum)
          (? !(two? defs && two? statenv) form                            ; need a defined fn and a static-data binding
             (swalk form statenv defs (map cap defs) (map cap statenv)))))
   ; --- deforestation: fuse a map/filter pipeline under its consumer into one pass, then lower it over
   ;     (jot N) to the named-let loop lift already glazes.
   ;     consumers: foldl/foldr, a counted loop counting up for foldl and down for foldr, and all/any,
   ;     an early-exit loop answering truth bits -- all/any glaze only because their false is the fixnum
   ;     0 like =/</!, not the zero point (), which is what the integer compiler returns. `each` is not
   ;     here: its body is an effect, outside the arithmetic fragment. the transducer view of shortcut
   ;     fusion -- map f: elem|->(f elem); filter p: step|->(? (p elem) step skip) -- and dsimp then
   ;     beta-inlines the stage lambdas to a first-order step. step binders are fresh gensym noms.
   (dquote? x) (two? x && (= <x '\) && 2 = #x)                  ; (\ datum) -> a quote, never descend
   (drm ks env) (filter (p \ !(elem <p ks)) env)                    ; drop the shadowed substitutions
   (dcolnms bs) (? (atom? >bs) () (: n <bs (? (nom? n) (n . dcolnms >>bs) (dcolnms >>bs))))   ; a : binding list's binder noms
   (dsubx env x)                                                              ; capture-avoiding multi-substitution (twin of ev.l's): α-rename both \ and : binders
    (? (nom? x) (: p (assoc x env) (? (two? p) >p x))
       (atom? x) x
       (dquote? x) x
       (= <x '\) (? (atom? >>x) x
          (: ps (init >x) ren (map (p \ p . nom 0) ps)
             ('\ . (map cup ren) + [(dsubx (ren + (drm ps env)) (last x))])))
       (= <x ':) (: nms (dcolnms >x) ren (map (p \ p . nom 0) nms)
          (map (e \ dsubx (ren + (drm nms env)) e) x))
       (map (e \ dsubx env e) x))
   (dsub old new B) (dsubx [(old . new)] B)                               ; substitute old->new in B, capture-avoiding
   ; the define-sugar decline guard: a sugared : binder ((g z..) B) is a list --
   ; dsubx never renames it -- so a beta whose argument carries a colliding free name would capture.
   ; decline such a beta: the redex stays source -- a missed inline, never a miscompile.
   (dsyms e) (? (nom? e) [e] (atom? e) () (dquote? e) () (foldl (\ a x (a + (dsyms x))) () e))
   (dsugcol bs) (? (atom? >bs) () (: r (dsugcol >>bs) n <bs (? (two? n) (n + r) r)))
   (dsugs e) (? (atom? e) () (dquote? e) ()
                (: r (foldl (\ a x (a + (dsugs x))) () e)
                   (? (= <e ':) ((dsugcol >e) + r) r)))
   (dbeta? old new B) (: ds (dsugs B)
      (? (atom? ds) 1
         (!(elem old ds) && !(foldl (\ a s (a || elem s ds)) 0 (dsyms new)))))
   (dmap? P)   (two? P && (= <P 'map) && 3 = #P)                ; exact: (map f l x) indexes the mapped list
   (dfilt? P)  (two? P && (= <P 'filter) && 3 = #P)
   (dprod? P)  (dmap? P || dfilt? P)
   (dsfn P)    <>P  (dssrc P) <>>P                              ; (map f P') -> f / P'
   (dpeel B e felse P)                                                        ; thread step body B over (elem e, filter-skip felse) through the chain
    (? (dmap? P)  (dpeel (dsub e [(dforest (dsfn P)) e] B) e felse (dssrc P))    ; e := (f e)
       (dfilt? P) (dpeel ['? [(dforest (dsfn P)) e] B felse] e felse (dssrc P))   ; (? (p e) B skip)
       [B (dforest P)])                                                      ; base list (forest nested pipelines)
   (dfold? x) (elem <x '(foldl foldr) && 4 = #x && (: P <>>>x (dprod? P || djot? P)))   ; (foldl/foldr c z P)
   (dpred? x) (elem <x '(all any) && 3 = #x && (: P <>>x (dprod? P || djot? P)))         ; (all/any q P)
   (dforest x)
    (? (atom? x)   x
       (dquote? x) x
       (dfold? x)  (: tag <x c <>x z <>>x P <>>>x e (mint 0) a (mint 0)
                      B0 (? (= tag 'foldl) [c a e] [c e a])               ; foldl step (c a e); foldr step (c e a)
                      r (dpeel B0 e a P)                                      ; filter-skip = the acc (unchanged)
                      hd (? (= tag 'foldl) ['\ a e <r] ['\ e a <r])
                      [tag hd (dforest z) <>r])
       (dpred? x)  (: tag <x q <>x P <>>x e (mint 0) unit (? (= tag 'all) 1 0)   ; filter-skip = the short-circuit unit
                      r (dpeel [q e] e unit P)
                      [tag ['\ e <r] <>r])
       (<x . map dforest >x))
   (dspecial? h) (= h '? || (= h '\ || (= h ':)))
   (dsimp x)                                                                  ; reduce to first-order: beta unary lambdas, flatten curried heads
    (? (atom? x)   x
       (dquote? x) x
       (: y (dsimp <x . map dsimp >x) h <y as >y
          (? (atom? h) y
             (= <h '\ && (3 = #h && (1 = #as && dbeta? <>h <as <>>h))) (dsimp (dsub <>h <as <>>h))
             (atom? <h && !(dspecial? <h))                 (dsimp (<h . >h + as))
             y)))
   ; (jot N) is the list source -- the chain (0 .. N-1) foldl/map iterate, which the loop never builds.
   ; jot only: iota is the array, which the chain ops do not iterate, so a foldl over one answers z.
   (djot? s) (two? s && (= <s 'jot) && 2 = #s)                 ; (jot N)
   (dstep? f)  (two? f && (= <f '\) && 4 = #f)                 ; (\ A E BODY)  -- a 2-param fold step
   (dstep1? f) (two? f && (= <f '\) && 3 = #f)                 ; (\ E BODY)    -- a 1-param predicate
   (dlowerfold x)                                                            ; (foldl/foldr STEP Z (jot N)) -> counted loop (up / down)
    (: tag <x STEP <>x Z <>>x SRC <>>>x
       (? !(dstep? STEP && djot? SRC) x
          (: P1 <>STEP P2 <>>STEP BODY <>>>STEP N <>SRC go (mint 0)
             (? (= tag 'foldl)                                            ; step=(\ a e B): p1=a p2=e ; count e up 0..n-1
                [[': [go P2 P1] ['? ['< P2 N] [go ['+ P2 1] BODY] P1]] 0 Z]
                [[': [go P1 P2] ['? ['< P1 0] P2 [go ['- P1 1] BODY]]] ['- N 1] Z]))))           ; step=(\ e a B): count e down n-1..0
   (dlowerpred x)                                                            ; (all/any PRED (jot N)) -> short-circuit loop over one index
    (: tag <x PRED <>x SRC <>>x
       (? !(dstep1? PRED && djot? SRC) x
          (: E <>PRED BODY <>>PRED N <>SRC go (mint 0)
             (? (= tag 'all)                                              ; all: a false body returns 0 early; run-off returns 1
                [[': [go E] ['? ['< E N] ['? BODY [go ['+ E 1]] 0] 1]] 0]
                [[': [go E] ['? ['< E N] ['? BODY 1 [go ['+ E 1]]] 0]] 0]))))           ; any: a true body returns 1 early; run-off 0
   (dlower x)
    (? (atom? x) x (dquote? x) x
       (elem <x '(foldl foldr) && 4 = #x) (dlowerfold (<x . map dlower >x))
       (elem <x '(all any) && 3 = #x)     (dlowerpred (<x . map dlower >x))
       (<x . map dlower >x))
   (has-pipe? x) (? (atom? x) 0  (dquote? x) 0  (dprod? x) 1  (dfold? x) 1  (dpred? x) 1  (any has-pipe? >x))
   (defol-body b) (? (has-pipe? b) (dlower (dsimp (dforest b))) b)            ; fuse+lower a pipeline body, else leave it
   (defol-bs bl) (? (atom? bl) ()                                  ; exhausted, and a body-less `:` ends
                                                                   ; here: without this the next arm reads
                                                                   ; () as a trailing body and invents one,
                                                                   ; turning a defglob into a local let
                    (atom? >bl) [(defol-body <bl)]                 ; trailing body
                    (<bl . (defol-body <>bl . defol-bs >>bl)))   ; (name value ..) -> transform each value
   (defoliate form)
    (? !(has-pipe? form) form                                             ; no pipeline anywhere -> byte-identical (every legacy form)
       !(two? form && (= <form ':) && !(atom? >form)) (dlower (dsimp (dforest form)))
       (': . defol-bs >form))
   ; --- loop-closer (loopclose): collapse a polynomial accumulation (foldl/foldr (+) z SRC) to its
   ;     closed form in the bound, work independent of the trip count.
   ;     runs before defoliate -- it wants the raw fold, not the lowered loop. the engine is finite
   ;     differences in exact integers: the forward differences c_k = Δ^k g(0) plus the hockey-stick
   ;     identity Σ_{i<N} C(i,k) = C(N,k+1) give Σ_{i<N} g(i) = Σ_k c_k C(N,k+1), emitted as falling
   ;     factorials over k! with no runtime helper. the body is a black box we sample through base-ev.
   ;     sound only where map F / filter P `qual` (so nothing captures the bound) and the difference
   ;     table dies -- the top difference exactly 0, not `nil?`, which also fires on a negative leading
   ;     term. a period-2 filter reparametrizes to the dense kept index; other predicates decline.
   (lcfd ys)    (? (atom? >ys) () (<>ys - <ys . lcfd >ys))         ; one forward difference
   (lclead ys)  (? (atom? ys) () (<ys . lclead (lcfd ys)))                          ; leading diagonal c_0..c_d
   (lctopfd ys) (? (atom? >ys) <ys (lctopfd (lcfd ys)))                             ; last entry: Δ^(L-1) g(0)
   (lcsamp g d) (: (go i) (? (i <= d) (g i . go (i + 1)) ()) (go 0))                   ; (g 0)..(g d)
   (lcdeg g cp) (: (go d) (? (d >= cp) -1 (? (0 = (lctopfd (lcsamp g (d + 1)))) d (go (d + 1)))) (go 0))   ; degree, -1 if not polynomial within cp
   (lcfac r)    (: (go k a) (? (k < 2) a (go (k - 1) (a * k))) (go r 1))                      ; r! (a literal at glaze time)
   (lcsub N j)  (? (j = 0) N ['- N j])                                                       ; (N - j), or N when j=0
   (lcff N j r) (? (j = (r - 1)) (lcsub N j) ['* (lcsub N j) (lcff N (j + 1) r)])            ; falling factorial N(N-1)..(N-r+1) as source
   (lccbn N r)  (? (r = 1) N ['// (lcff N 0 r) (lcfac r)])                                   ; C(N,r) as source (r consecutive ints / r!, exact)
   (lcmul c t)  (? (c = 1) t ['* c t])
   (lcadd a b)  (? (b = 0) a ['+ a b])
   (lcsum cks N) (: (go ks k) (? (atom? ks) 0 (: rest (go >ks (k + 1)) (? (<ks = 0) rest (lcadd (lcmul <ks (lccbn N (k + 1))) rest)))) (go cks 0))   ; Σ_k c_k C(N,k+1), nonzero terms
   (lcfinal z sum) (? (z = 0) sum ['+ z sum])
   (lcemit z g M) (: d (lcdeg g 8) (? (d < 0) () [(lcfinal z (lcsum (lclead (lcsamp g d)) M))]))    ; sample -> degree -> closed source, wrapped; () declines
   (lcjot? s)   (two? s && (= <s 'jot) && 2 = #s)
   (lcmap? s)   (two? s && (= <s 'map) && 3 = #s)
   (lcfilt? s)  (two? s && (= <s 'filter) && 3 = #s)
   (lcplus? f)  (= f '+ || (two? f && (= <f '+) && 1 = #f))                ; + or (+)
   (lcfold? x)  (two? x && elem <x '(foldl foldr) && 4 = #x && lcplus? (opd x 0))
   (lcsrc s)                                                                                  ; src -> (Fsrc Psrc Nexpr) | () ; F/P = () when absent
    (? (lcjot? s)  [() () (opd s 0)]
       (lcfilt? s) (: in (opd s 1) (? (lcjot? in) [() (opd s 0) (opd in 0)] ()))
       (lcmap? s)  (: in (opd s 1) (? (lcjot? in) [(opd s 0) () (opd in 0)]
                                       (lcfilt? in && lcjot? (opd in 1)) [(opd s 0) (opd in 0) (opd (opd in 1) 0)]
                                       ()))
       ())
   ; soundness: only close a body that is a pure polynomial (+ - * over the param + int consts) -- a
   ; genuine polynomial, so the difference table dies exactly at its degree (a body with //, %, <, or ?
   ; can fit a low-degree polynomial on the first samples yet break later -- sampling can't prove it).
   (lc1lam? f)   (two? f && (= <f '\) && 3 = #f && nom? (opd f 0))               ; (\ v BODY)
   (lcpoly? v e) (? (= e v) 1 (whole? e) 1
                    (two? e && elem <e '(+ - *) && 3 = #e) (lcpoly? v (opd e 0) && lcpoly? v (opd e 1))
                    0)
   (lcpolyf? f)  (lc1lam? f && lcpoly? (opd f 0) (opd f 1))
   ; and recognize the filter predicate structurally (odd/even over (v % 2)) -- not by sampling, which
   ; a longer-period predicate could fool. canonical forms: (v % 2)/(1 = (v % 2)) odd, (0 = (v % 2)) even.
   (lcmod2? e v) (two? e && (= <e '%) && 3 = #e && (= (opd e 0) v) && (opd e 1) = 2)
   (lcoddp? f)   (? !(lc1lam? f) ()                                                          ; -> 'odd | 'even | ()
                    (: v (opd f 0) b (opd f 1)
                       (? (lcmod2? b v) 'odd
                          (two? b && (= <b '=) && 3 = #b)
                             (: a (opd b 0) c (opd b 1)
                                (? (a = 1 && lcmod2? c v) 'odd  (c = 1 && lcmod2? a v) 'odd
                                   (a = 0 && lcmod2? c v) 'even (c = 0 && lcmod2? a v) 'even ()))
                          ())))
   (lcclose1 x)                                                                               ; (foldl/foldr (+) z SRC) -> (closed-source) | () decline
    (: z (opd x 1) p (lcsrc (opd x 2))
       (? (atom? p) ()
          (: Fsrc <p Psrc <>p N <>>p
             Fc (? (= Fsrc ()) (i \ i) (? (lcpolyf? Fsrc) (base-ev Fsrc) ()))              ; identity if no map; else F must be a pure polynomial
             (? (= Fc ()) ()
                (= Psrc ()) (lcemit z Fc N)                                                 ; no filter: g = F over [0,N)
                (: pat (lcoddp? Psrc)                                                         ; else need a recognized odd/even filter
                   (? (= pat 'odd)  (lcemit z (j \ Fc (1 + (2 * j))) ['// N 2])          ; k=2j+1, M=N//2
                      (= pat 'even) (lcemit z (j \ Fc (2 * j)) ['// ['+ N 1] 2])        ; k=2j,   M=(N+1)//2
                      ()))))))
   (lcquote? x) (two? x && (= <x '\) && 2 = #x)
   (lc:form? x) (two? x && (= <x ':) && !(atom? >x))                            ; a (: ..) with bindings
   (lcocc? v e) (? (= e v) 1 (atom? e) 0 (lcquote? e) 0 (any (s \ lcocc? v s) >e))   ; v occurs in e
   ; --- named-let accumulator: (NM i a) (? (i < N) (NM (i + 1) (a + B)) a) with B a pure polynomial in i
   ;     and N loop-invariant closes to the sum in O(1) -- the same finite-difference engine as the fold
   ;     lane, reached through a `:` binding instead of a combinator. Σ_{i<=j<N} g(j) = G[N]-G[i], guarded
   ;     by the original test so the function stays faithful for i>=N, where the loop answers acc.
   ;     restricted to step (i + 1), test `<` and op `+`; lcpoly? is what rejects a reference to acc or an
   ;     outer var.
   (lcacc? name val)
    ((two? name) && (3 = #name) && (nom? <name) && (nom? <>name) && (nom? <>>name)
     && !(= <>name <>>name)                                               ; (NM i a), i /= a
     && (two? val) && (= <val '?) && (4 = #val)                                        ; (? T THEN ELS)
     && (: NM <name I <>name A <>>name
           T (opd val 0) THEN (opd val 1) ELS (opd val 2)
           ((two? T) && (= <T '<) && (3 = #T) && (= (opd T 0) I)                     ; T = (i < N)
            && !(lcocc? I (opd T 1)) && !(lcocc? A (opd T 1))                               ; N loop-invariant in i,a
            && (= ELS A)                                                                      ; base case -> acc
            && (two? THEN) && (= <THEN NM) && (3 = #THEN)                               ; then = (NM STEP ACC)
            && (: STEP (opd THEN 0) ACC (opd THEN 1)
                  ((two? STEP) && (= <STEP '+) && (3 = #STEP) && (= (opd STEP 0) I) && ((opd STEP 1) = 1)  ; (i + 1)
                   && (two? ACC) && (= <ACC '+) && (3 = #ACC) && (= (opd ACC 0) A)       ; (a + B)
                   && (lcpoly? I (opd ACC 1)))))))                                              ; B a pure polynomial in i
   (lcaccsum gfn N i)                                                                          ; G[N]-G[i] source, wrapped ; () declines
    (: d (lcdeg gfn 8) (? (d < 0) () (: cks (lclead (lcsamp gfn d)) [['- (lcsum cks N) (lcsum cks i)]])))
   (lcaccrw name val)                                                                          ; the accumulator binding -> its closed value
    (: I <>name A <>>name T (opd val 0)
       N (opd T 1) B (opd (opd (opd val 1) 1) 1)                                               ; then=(NM (i + 1) (a + B)) -> acc=(a + B) -> B
       cs (lcaccsum (base-ev ['\ I B]) N I)
       (? (atom? cs) val ['+ A ['? T <cs 0]]))                                           ; (a + (? (i < N) (G[N]-G[i]) 0))
   (lc-bs bl) (? (atom? bl) bl  (atom? >bl) [(lcwalk <bl)]                           ; trailing body
                 (<bl . ((? (lcacc? <bl <>bl) (lcaccrw <bl <>bl) (lcwalk <>bl)) . lc-bs >>bl)))
   (lcwalk x) (? (atom? x) x (lcquote? x) x
                 (lc:form? x) (': . lc-bs >x)                                         ; walk `:` bindings (accumulators + recurse)
                 (: c (? (lcfold? x) (lcclose1 x) ())
                    (? (atom? c) (<x . map lcwalk >x) <c)))               ; () decline -> recurse; (src) -> the residual
   (lc-bs-has? bl) (? (atom? bl) 0  (atom? >bl) (lc-has-acc? <bl)
                      (lcacc? <bl <>bl || (lc-has-acc? <>bl || lc-bs-has? >>bl)))
   (lc-has-acc? x) (? (atom? x) 0 (lcquote? x) 0 (lc:form? x) (lc-bs-has? >x) (any lc-has-acc? >x))
   (lc-has-fold? x) (? (atom? x) 0 (lcquote? x) 0 (lcfold? x) 1 (any lc-has-fold? >x))
   (loopclose form) (? (lc-has-fold? form || lc-has-acc? form) (lcwalk form) form)          ; byte-identical when nothing closeable
   (clook2 nm al) (? (atom? al) -1 (= nm <<al) <><al (clook2 nm >al))   ; (name arity) alist -> arity (-1 absent)
   (cmlook nm cm) (? (atom? cm) () (= nm <<cm) ><cm (cmlook nm >cm))          ; (name . chain-param-INDEX-list) -> indices (() absent)
   ; cok? -- e is chain-valued: a raw chain word, not an untagged int. such a word must never reach an
   ; arith/cmp operand, where the body would read it as an int; it may only flow to two?/cap/cup or a
   ; callee's chain slot.
   (cok? cm cands cps ps e) (? (elem e cps) 1
                               (two? e && elem <e '(cap cup) && tally e = 2) (cok? cm cands cps ps <>e)
                               0)
   ; pwcar? -- w is a raw chain-car word: <ce/>ce over a chain-valued operand. The one
   ; place such a word may reach a compare: the point-= production below (raw word identity).
   (pwcar? cm cands cps ps w) (two? w && elem <w '(cap cup) && 2 = #w && cok? cm cands cps ps <>w)
   (gargok? cm pm cands cps pps ps as i callee) (? (atom? as) 1                                ; call args: slot i chain (per callee's cmap) -> cok?; point (per pm) -> a point param; else int
      ((? (elem i (cmlook callee cm)) (cok? cm cands cps ps <as)
             (elem i (cmlook callee pm)) (elem <as pps)                             ; a point slot takes a point param, nothing else (the guard is at the entry only)
             (groupok? cm pm cands cps pps ps <as))
       && (gargok? cm pm cands cps pps ps >as (i + 1) callee)))
   (groupok? cm pm cands cps pps ps e)                                                        ; int-valued e over cands; cps/pps = the current fn's chain-/point-param names
    (? (elem e cps) 0                                                                       ; a chain param is not int-valued (only valid via cok?)
       (elem e pps) 0                                                                       ; a point param neither (raw word: only the point-= and point slots)
       (elem e ps) 1  (whole? e) 1
       (two? e) (: op <e ar (clook2 op cands)
          (? (-1 < ar)                                  (#>e = ar && gargok? cm pm cands cps pps ps >e 0 op)   ; group call: arity ok, each arg ok for its slot's kind
             ((= op '=) && ((3 = #e)                                              ; point-=: (P = <..)/(<.. = P) -- word identity, int 0/1.
              && (: x1 <>e y1 <>>e                                             ;   total because P is entry-guarded nom|mint and a point equals only
                    ((elem x1 pps && pwcar? cm cands cps ps y1)                     ;   itself, whatever kind the car is (charm keys deopt at the entry --
                     || (elem y1 pps && pwcar? cm cands cps ps x1))))) 1               ;   only interp knows the numeric bridges, (2 = 2.0))
             (elem op '(+ - * // % & | ^ < <= > >= =)) (3 = #e && groupok? cm pm cands cps pps ps <>e && groupok? cm pm cands cps pps ps <>>e)
             (= op '?)                                  (4 = #e && groupok? cm pm cands cps pps ps <>e && groupok? cm pm cands cps pps ps <>>e && groupok? cm pm cands cps pps ps <>>>e)
             (= op 'tally)                              (2 = #e && elem <>e ps)                                          ; (tally STR): str a param (string lane)
             (= op 'peep)                               (4 = #e && elem <>e ps && groupok? cm pm cands cps pps ps <>>e && whole? <>>>e)   ; (peep STR i d): str param, i ok, d const
             (= op 'mpeep)                              (4 = #e && elem <>e ps && groupok? cm pm cands cps pps ps <>>e && whole? <>>>e)   ; (mpeep MAP k d): map param, key ok, d const (the map lane -- mapfix rewrote a map-valued peep here)
             (= op 'mpin)                               (4 = #e && elem <>e ps && groupok? cm pm cands cps pps ps <>>e && groupok? cm pm cands cps pps ps <>>>e)   ; (mpin MAP k v): map param, key ok, v ok -- update-in-place; produces the map (threaded into a call's map slot, or a discarded result)
             (= op 'pin)                                (4 = #e && elem <>e ps && groupok? cm pm cands cps pps ps <>>e && groupok? cm pm cands cps pps ps <>>>e)   ; (pin BUF i V): buf a raw-buf param, i ok, V ok
             (= op 'two?)                               (2 = #e && cok? cm cands cps ps <>e)               ; (two? CE): ce chain-valued; result int 0/1 (total -- a non-chain reads false)
             0))                                                                               ; bare cap/cup are chain-valued -> not admitted in an int position (cok? and the point-= carry them)
       0)
   ; --- vok? -- the value grammar, a heap-allocating fn's body: an int const | a param | (. V V) |
   ;     (? INT V V), the test through groupok? and the branches value | a call to a value-typed
   ;     candidate. cross-call soundness comes from the candidate sets being separate -- vok?'s calls
   ;     resolve only in vcands, groupok?'s only in icands, so neither kind can call the other.
   (vok? cm pm icands vcands cps pps ps e)
    (? (whole? e) 1
       (elem e cps) 0  (elem e pps) 0                                                   ; raw-word params (chain/point) are not values: cggvir would re-tag them
       (elem e ps) 1
       (two? e) (: op <e ar (clook2 op vcands)
          (? (-1 < ar)         (#>e = ar && gargok? cm pm icands cps pps ps >e 0 op)   ; a value-group call (target in vcands)
             (= op '.)                    (3 = #e && vok? cm pm icands vcands cps pps ps <>e && vok? cm pm icands vcands cps pps ps <>>e)
             (= op '?)       (4 = #e && groupok? cm pm icands cps pps ps <>e && vok? cm pm icands vcands cps pps ps <>>e && vok? cm pm icands vcands cps pps ps <>>>e)
             0))
       0)
   (chps body ps) (filter (k \ cuse? body (ps k)) (rangeL 0 #ps))                ; chain-param indices: params used in cap/cup/two? (cuse? from emit.l)
   (grpok-1 fns cm pm icands vcands vnames c) (: p (afind (q \ (= <<q <c)) fns)
                                cps (map (k \ ><p k) (cmlook <c cm))      ; this fn's chain-param names (its index list -> names)
                                pps (map (k \ ><p k) (cmlook <c pm))      ; ... and its point-param names (same alist shape)
                                (? (elem <c vnames) (vok? cm pm icands vcands cps pps ><p >p)   ; a value fn -> value grammar
                                   (groupok? cm pm icands cps pps ><p >p)))      ; an int fn -> int grammar, over the int candidates only
   ; the group-membership fixpoint as a descending projection of the shared `monofix` (prel): each step
   ; drops candidates that fail the int/value grammar, recomputing the int/value split from the surviving
   ; set; tally (shrinking) is the measure. Converges when a pass drops nothing -- the closed glazeable subset.
   (gfix fns cm pm vnames cands)
    (monofix cands
       (st \ (: icands (filter (c \ !(elem <c vnames)) st)
                vcands (filter (c \ elem <c vnames) st)
                (filter (c \ grpok-1 fns cm pm icands vcands vnames c) st)))
       tally)
   (grpfix fns cands) (: cm (map (f \ <<f . chps >f ><f) fns)   ; (name . chain-param-index-list) for every candidate fn
                         pm (map (f \ (: fps ><f cix (chps >f fps)              ; (name . point-param-index-list): point-compared ((P = <..)), never chain-used
                                         (<<f . filter (k \ nuse? >f (fps k) && !(elem k cix)) (rangeL 0 #fps)))) fns)
                         vnames (map (f \ <<f) (filter (f \ hasl >f) fns))    ; the value-typed candidate names (body conses)
                         (gfix fns cm pm vnames cands))
   (rewrite-bindings bl gnames gdefs) (? (atom? >bl) bl                                  ; the trailing body form -> keep
      (: nf <bl val <>bl  hit (two? nf && elem <nf gnames)
         ((? hit <nf nf)                                                            ; drop the (name p..) define-sugar -> a plain binding
            . ((? hit (? (jgir-ok? gdefs) (jitgroupir gdefs <nf arch) val) val)   ; jgir-ok? -> the neutral-IR group lane; else interp -- jgir spans the recognizer grammar, so that
         ;   fallback is a soundness backstop, not a live lane
                  . (rewrite-bindings >>bl gnames gdefs)))))
   ; memo-leak? -- a candidate fn reading a `:`-sibling map free: the native group lane can only touch a
   ; map that is one of the fn's own PARAMS, so a free one is a silent miscompile. decline to interp.
   ; the map-param lane is unaffected -- there the binding name never occurs inside the callee.
   (memo-leak? form)
    (: ps <(anat-defs >form)
       mn (filter (p \ atom? <p && two? >p && elem <>p '(tablet hash)) ps)   ; names bound to a tablet/hash
       !(atom? (filter (p \ (two? <p)                                                    ; a fn binding whose body ...
       && !(atom? (filter (m \ occurs? <m >p && !(elem <m ><p)) mn))) ps)))   ; ... references a mapname that is not its param
   ; --- group swallow: a member calling an external global int fn would drop the whole group to interp,
   ;     so srcrec records every top-level global fn define's source and swgather pulls a called global's
   ;     recording into the candidate set as a synthetic member, to a fixpoint. jitgroupir emits it as an
   ;     in-blob (label g) sibling under the group's one shared ovf/deopt: no cross-blob call, no split
   ;     deopt. the "real global" test is the body-less `:` that leaks its bindings, so srcreg never holds
   ;     a bench's local fn. a swallowed body over a free var or an unknown call is rejected by groupok?'s
   ;     own grammar, so the swallow declines rather than miscompiles. `F_g`, lift's name for a lifted fn,
   ;     is content-derived and collision-free because a name is either a `:`-local candidate or a
   ;     swallowed global, never both, so each F_ namespace is owned once.
   ; srcreg holds name -> (params . body) once lowered, or the form's shared cell {'form f} until a pull
   ; first asks for one of its names: a crew file's forms are recorded by the thousand while the swallow
   ; pulls a handful, so the lowering waits for the first pull and then registers the lowered pairs
   ; (a lifted F_g included) over entries that are free or this cell's own.
   srcreg {}
   (swfnpair? pr) (: nf <pr (two? nf && 1 < #nf < 6 && all nom? >nf && distinctp >nf))
   (srcrec form0) (? ((two? form0) && (= <form0 ':) && !(atom? >form0)
                    && (0 = (#>form0 % 2)))                                   ; body-less `:` only -> a global-leaking define
      (: cell (pin {} 'form form0)
         (foldl (\ _ n (pin srcreg n cell)) () (swbnds form0))) ())
   (swlow c) (? (peep c 'low 0) 0
      (: _ (pin c 'low 1)
         low (plift (lift (delet (defoliate (loopclose (autospec (debool (dehof (dechurch (fold-consts (opfix (c 'form))))))))))))   ; autogroup's full lowering: church/hof/&& + structural (lift/loops/value-lets)
         (foldl (\ _ pr (? (swfnpair? pr && (: cur (peep srcreg <<pr 0) (= cur 0 || (= cur c))))
                            (pin srcreg <<pr (><pr . >pr)) ())) () <(anat-defs >low))))
   (swsrc h) (: d (peep srcreg h 0)                                                   ; a recorded global's lowered pair, or 0
      (? (= d 0) 0
         (tablet? d) (: _ (swlow d) d2 (peep srcreg h 0)
                        (? (tablet? d2) (: _ (pin srcreg h 0) 0) d2))                   ; the name did not survive its form's lowering
         d))
   (swuniq l) (? (atom? l) () (elem <l >l) (swuniq >l) (<l . swuniq >l))
   (swbnds e) (map (p \ two? <p ? <<p <p) <(anat-defs >e))                       ; a `:`'s binding names
   ; collect call heads (symbols); skip lambda subforms. the walk reads opfixed source, so an
   ; infix (a op b) arrives factored and an operand never masquerades as a head. bnd is the
   ; binder set that filters real-but-local heads: `:` names + params (a `\` subform is
   ; skipped whole, so its params never leak).
   (swwalk e bnd acc) (? (atom? e) acc  (two? e && (= <e '\)) acc
      (two? e && (= <e ':)) (foldl (\ a x (swwalk x (swbnds e + bnd) a)) acc >e)
      (: h <e acc2 (? (nom? h && !(elem h bnd)) (h . acc) acc)
         (foldl (\ a x (swwalk x bnd a)) acc2 >e)))
   (swheads e bnd acc) (swwalk (opfix e) bnd acc)
   (swgather fns) (: names (map caap fns)                                                 ; enlarge fns with recorded globals reachable from the bodies (to fixpoint)
      heads (foldl (\ a p (swheads >p ><p a)) () fns)                                ; the fn's own params bind too
      new (swuniq (filter (h \ !(elem h names) && !(= (swsrc h) 0)) heads))
      (? (atom? new) fns
         (swgather (foldr (\ h a (: d (swsrc h) (((h . <d) . >d) . a))) fns new))))
   (autogroup form0)
    (: _ (srcrec form0)                                                                  ; record global fn sources (flag-gated inside srcrec) before any decline
     (? !(two? form0) form0
       !(= <form0 ':) form0
       (atom? >form0) form0
       ; decline a body-less `:`, the global-leaking top-level define every crew file is made of.
       ; lowering it is sound, but autogroup is all-or-nothing per form and only a handful of one-line
       ; integer predicates survive grpfix there, so the whole file pays the lifting to carry them --
       ; measurably slower everywhere and faster nowhere. it comes back when grpfix's fragment reaches
       ; past integers into list and charlist code. srcrec above still walks the same chain over these
       ; forms to feed the swallow, so the lowering has to be right for them: a price, not a guard.
       (0 = (#>form0 % 2)) form0
       (memo-leak? form0) form0                                                                ; a `:`-sibling map memo (fact/bell) -> interp, sound
       ; opfixed at the head: every pass below reads a call as a list with a head, where raw source
       ; leaves a bare symbol standing in infix operand position
       (: form (plift (lift (delet (defoliate (loopclose (autospec (debool (dehof (dechurch (fold-consts (opfix form0)))))))))))
          parsed (anat-defs >form) pairs <parsed
          fns0 (filter (p \ (: nf <p (two? nf && 1 < #nf < 6 && all nom? >nf && distinctp >nf))) pairs)   ; (name p..), 1..4 distinct sym params
          fns (swgather fns0)                                                              ; swallow: pull called globals' recorded sources in as synthetic members
          (? !(two? fns) form0                                                            ; no candidate functions -> original
             (: armap (map (p \ [<<p (#<p - 1)]) fns)                  ; (name arity) candidates
                grp (grpfix fns armap)                                                        ; the closed glazeable subset
                (? (atom? grp) form0                                                          ; nothing survives the fixpoint -> original (un-lifted)
                   ; a group of swallowed members only rewrites nothing here, so committing the
                   ; lowered form buys nothing and stakes the whole file on it.
                   !(ho-any (p \ elem (? (two? <p) <<p <p) (map cap grp)) pairs) form0
                   (: gnames (map cap grp)
                      gdefs (map mapfix-def (filter (p \ elem <<p gnames) fns))   ; the group's (nameform . body) defs, with map-valued peeps rewritten to mpeep
                      (': . rewrite-bindings >form gnames gdefs))))))))             ; each binding of the lifted form -> its native
   ; --- twin lowering (twolow): a complex-recurrence grid becomes the real-pair float grid autonat
   ;     already glazes, so idiomatic complex code needs no new codegen. each twin param p splits into
   ;     (p_r p_i), twin ops become real-pair arithmetic ((a+bi)(c+di) = (ac-bd, ad+bc)), and every call
   ;     site's twin args split in two; a small fixpoint propagating twin-ness from call-site args to
   ;     callee params picks which params are twin. bit-exact: z*z's imag rides re*im+im*re = 2*re*im,
   ;     and scaling a rounded product by 2 is exact. runs before autonat.
   (twolow form)
    (:
       (op2 e i)  (>e i)
       (memq x l) (? (atom? l) 0 (= <l x) 1 (memq x >l))
       (negf x)   ['- 0.0 x]
       (zero0? x) (gem? x && x = 0.0)
       (mkadd a b) (? (zero0? a) b (zero0? b) a ['+ a b])
       (mksub a b) (? (zero0? b) a ['- a b])
       (mkmul a b) (? (zero0? a || zero0? b) 0.0 ['* a b])
       (adefs bs) (? (atom? >bs) (() . <bs)                          ; binding list -> (pairs . body)
                     (: r (adefs >>bs) (((<bs . <>bs) . <r) . >r)))
       (fnpair? pr) (two? <pr)                                               ; nameform is a (name params..) list
       (fnname pr) <<pr  (fnparams pr) ><pr  (fnbody pr) >pr
       (twname p suf) (name (string p + suf))                                ; p_r / p_i
       (? !(two? form && (= <form ':)) form
          (atom? >form) form
          (: parsed (adefs >form) pairs <parsed body >parsed
             (? !(all fnpair? pairs) form                                      ; only the all-function-def `:` shape
                (: fnames (map fnname pairs)
                   pt {} chg {}                                   ; `(fn i) -> 1 if param i of fn is twin
                   ; --- twin-type inference: is e twin under env (param-name -> twin bool)? ---
                   (tty e env) (? (atom? e) (peep env e 0)
                                  (e @ ('twin . _) 1
                                       (('re || 'im) . _) 0
                                       (('+ || '- || '*) a b) (tty a env || tty b env)
                                       ('? _ a b) (tty a env || tty b env)
                                       0))                                         ; a defined-fn call returns int here
                   (mkenv fn ps) (: e {} _ (mke fn ps 0 e) e)
                   (mke fn ps i e) (? (atom? ps) e (: _ (pin e <ps (peep pt [fn i] 0)) (mke fn >ps (i + 1) e)))
                   (propargs g as i env) (? (atom? as) 0                          ; call-site arg twin-ness -> callee param
                      (: _ (? (memq g fnames && tty <as env && !(peep pt [g i] 0)) (: _ (pin pt [g i] 1) (pin chg 0 1)) 0)
                         (propargs g >as (i + 1) env)))
                   (walkprop env e) (? !(two? e) 0
                      (: op <e _ (? (memq op fnames) (propargs op >e 0 env) 0) (: _ (map (a \ walkprop env a) >e) 0)))
                   (infer _) (: _ (pin chg 0 0)                                   ; fixpoint (monotone: flags only flip 0->1)
                               _ (map (pr \ walkprop (mkenv (fnname pr) (fnparams pr)) (fnbody pr)) pairs)
                               _ (walkprop {} body)
                               (? (peep chg 0 0) (infer ()) 0))
                   _ (infer ())
                   (anytwin? prs) (? (atom? prs) 0 (twfn? (fnname <prs) 0 || anytwin? >prs))
                   (twfn? fn i) (? (peep pt [fn i] 0) 1 (i < 8) (twfn? fn (i + 1)) 0)
                   (? !(anytwin? pairs) form                                   ; no twin param -> pass through
                      ; --- lowering: loR scalar-valued ; loT twin-valued -> (re-expr . im-expr) ---
                      (: (mknmap fn ps) (: m {} _ (mkn fn ps 0 m) m)      ; twin param -> (p_r . p_i) pair
                         (mkn fn ps i m) (? (atom? ps) m (: _ (? (peep pt [fn i] 0) (pin m <ps (twname <ps "_r" . twname <ps "_i")) 0) (mkn fn >ps (i + 1) m)))
                         (flatps fn ps i) (? (atom? ps) ()                        ; flatten params, splitting twins
                            (: p <ps rest (flatps fn >ps (i + 1))
                               (? (peep pt [fn i] 0) (twname p "_r" . (twname p "_i" . rest)) (p . rest))))
                         (loR e env nm) (? (atom? e) e
                            (e @ ['re x] (? (tty x env) <(loT x env nm) (loR x env nm))
                                 ['im x] (? (tty x env) >(loT x env nm) 0.0)
                                 (: op <e (? (memq op fnames) (op . splitargs op >e 0 env nm)
                                               (op . map (a \ loR a env nm) >e)))))
                         (loT2 e env nm) (? (tty e env) (loT e env nm) (loR e env nm . 0.0))
                         (loT e env nm) (? (atom? e) (peep nm e (e . e))
                            (e @ ['twin u v] (loR u env nm . loR v env nm)
                                 ['twin u] (? (tty u env) (: p (loT u env nm) (<p . negf >p)) (loR u env nm . 0.0))
                                 ['+ u v] (: a (loT2 u env nm) b (loT2 v env nm) (mkadd <a <b . mkadd >a >b))
                                 ['- u v] (: a (loT2 u env nm) b (loT2 v env nm) (mksub <a <b . mksub >a >b))
                                 ['* u v] (: a (loT2 u env nm)
                                             (? (u = v)                                       ; squaring (z*z): the imag is 2*ar*ai, one product, and better ilp than the M+M chain
                                                (: ar <a ai >a (mksub (mkmul ar ar) (mkmul ai ai) . mkmul (mkmul 2.0 ar) ai))
                                                (: b (loT2 v env nm) ar <a ai >a br <b bi >b
                                                   (mksub (mkmul ar br) (mkmul ai bi) . mkadd (mkmul ar bi) (mkmul ai br)))))
                                 ['? t u v] (: c (loR t env nm) a (loT u env nm) b (loT v env nm)
                                               (['? c <a <b] . ['? c >a >b]))
                                 (e . e)))
                         (splitargs g as i env nm) (? (atom? as) ()
                            (: a <as rest (splitargs g >as (i + 1) env nm)
                               (? (peep pt [g i] 0) (: p (loT2 a env nm) (<p . (>p . rest))) (loR a env nm . rest))))
                         (lowerfn pr) (: fn (fnname pr) ps (fnparams pr) bd (fnbody pr) env (mkenv fn ps) nm (mknmap fn ps)
                                         ((fn . flatps fn ps 0) . loR bd env nm))
                         (rebuild lowfns) (? (atom? lowfns) (loR body {} {} . ())
                            (: lf <lowfns (<lf . (>lf . rebuild >lowfns))))
                         (': . rebuild (map lowerfn pairs)))))))))
   (autonat form)
    (? !(two? form) form
       !(= <form ':) form
       (atom? >form) form
       (: parsed (anat-defs >form) pairs <parsed
          (? !(1 < #pairs) form                        ; need a recurrence + >=1 loop
             (: recp (afind anat-rec? pairs)
                (? !(two? recp) form                          ; no float recurrence found
                   (: recnm <<recp recps ><recp
                      (>recp @ ['? ['&& ['< _ lim] [cmpop testexpr bound]] then _]
                         (: cl (classify recps >then) fvars <cl updates <>cl invs (cl 2)
                            looppairs (filter (q \ !(= q recp)) pairs)             ; the loop defs
                            callees (map anat-callee looppairs)
                            outerp (afind (q \ !(elem <<q callees)) looppairs)   ; the loop no loop calls
                            (? !(two? outerp) form
                               (: chain (loopchain <<outerp pairs recnm)       ; outermost -> recurrence
                                  D #chain M #invs N #fvars
                                  (? !(two? chain && elem cmpop '(< <= > >=) && 0 < N && (M + N) < 7 && D < 7) form
                                     (: cnames (map cap chain) dims (map caup chain)
                                        margs ((last chain) 2)
                                        invd (map (iv \ margs (posof iv recps 0)) invs)
                                        glam ['\ '_ form]        ; faithful interp nest (deopt fallback / =-show)
                                        ng (jitfgridn glam cnames dims invs invd fvars updates testexpr cmpop bound lim arch)
                                        (? (lit? ng) (': . anat-rebind >form <<outerp ng) form))))))
                         form)))))))
   ; compile cache: each source \-expr compiles once, keyed by source, so structurally-equal closures
   ; share the one native -- sound, they are =. this is the transparent form of a hot-trigger: an
   ; execution-count trigger wants a counting wrapper, and a wrapper is not =/show its source, so the
   ; trigger is "compile on first request, cached after". pins natives for the run.
   cache {}
   (memo e mk) (: g (peep cache e 0) (? g g (: h (mk e) _ (pin cache e h) h)))
   ; auto-ev: a whole-form lambda -> native (cached), else the base interpreter. a creation hook -- one
   ; that rewrote embedded lambdas on a jit-walk -- cannot sit here: it is pre-macroexpansion, so it can
   ; disturb a macro's data args, and the compile cache would make structurally-equal closures
   ; ==-identical, against love's !(== (\ x E) (\ x E)).
   ; the lanes route to `arch`. on x86 the full glaze runs; on a64 the integer lanes and the scalar
   ; float-result leaf are live, and only the float-grid lane and castbuild's cask-fill are x86-only --
   ; autogroup carries every source rewrite that lowers to the integer group, so fib/tak/primes glaze
   ; there too.
   ; canon: a free nom respelled by the value it names, toward the canonical spelling -- (: add +)
   ; reads +, link reads ., a twin alias reads twin -- so a synonym meets the recognizers, which
   ; read source by name. gv is ala's global read, pinned into gvbox by hook.l's first closure;
   ; before that, or for a lexically bound nom, the spelling stands. a tablet keys a function by
   ; identity, so the value table is one peep.
   gvbox {}
   gone (mint 0)
   canon-names '(+ - * // % & | ^ < <= > >= = twin re im cap cup . two? one? tally peep pin   ; the tree's canonical spellings, one per value:
                 map filter foldl foldr jot iota net string list && ||)                       ; link reads ., atom? reads one?, ~ reads twin
   ctab {}
   (ctable gv) (? (peep ctab 'ok 0) ctab
                  (: _ (each canon-names (n \ (: v (gv n gone) (? (= v gone) 0 (pin ctab v n)))))
                     _ (pin ctab 'ok 1)
                     ctab))
   (canon e) (: gv (peep gvbox 0 0)
                (? gv (: tab (ctable gv)
                         ops '(+ - * // % & | ^ < <= > >= = . && ||)                                   ; infix spellings: an operand written so reads as infix
                         (cnom x bnd hd) (? (elem x bnd) x
                                            (: v (gv x gone) c (? (= v gone) 0 (peep tab v 0))
                                               (? (nil? c) x  (hd || !(elem c ops)) c  x)))
                         (cbinders bs) (? (atom? >bs) () (: b <bs ((? (two? b) <b b) . cbinders >>bs)))   ; a :'s names, sugared heads too
                         (cw x bnd) (?
                          (nom? x) (cnom x bnd 0)
                          (atom? x) x
                          (= <x '\) (? (atom? >>x) x                                           ; (\ v): a quote
                                       (: ps (init >x) (. '\ (ps + [(cw (last x) (ps + bnd))]))))
                          (= <x '@) (: (arms l) (? (atom? l) l (atom? >l) [(cw <l bnd)]            ; (@ x pat body ..): a pattern is the
                                                    (<l . (cw <>l bnd) . arms >>l))               ; macro's to read, only the bodies respell
                                       ('@ . (cw <>x bnd) . arms >>x))
                          (= <x ':) (: bnd2 (cbinders >x + bnd)
                                       (cbs bs) (? (atom? bs) bs
                                                   (atom? >bs) [(cw <bs bnd2)]
                                                   (: b <bs ps (? (two? b) >b ())
                                                      (. b (. (cw <>bs (ps + bnd2)) (cbs >>bs)))))
                                       (': . cbs >x))
                          (nom? <x) ((cnom <x bnd 1) . map (y \ cw y bnd) >x)                       ; the head may take an operator spelling
                          (map (y \ cw y bnd) x))
                         (cw e ()))
                   e))
   (auto-ev e) (? !x86? (? (qual e)  (memo e (l \ jitir l arch))        ; a64: integer + scalar-float lanes native
                               (qualn e) (memo e (l \ jitnir l arch))
                               (qualc e) (memo e (l \ jitnir (flatc l) arch))
                               (qualfr e) (memo e (l \ jitfr l arch))      ; float-result leaf -> heap-boxed gem
                               (: li (loopinfo e)                            ; counted loops (arch-aware loopcode)
                                  (? li (memo e (l \ njit-loop l <li <>li <>>li <>>>li (base-ev l)))
                                     (: ln (loopinfo-n e)
                                        (? ln (memo e (l \ njit-loop-n l <ln <>ln <>>ln <>>>ln <>>>>ln (base-ev l)))
                                           (base-ev (autogroup (autonat (twolow (canon (opfix e)))))))))))   ; float-grid nest (scalar gridn, arch-aware) then group; castbuild (cask-fill) is x86-only so skipped
                  (qual e)  (memo e (l \ jitir l arch))
                  (qualn e) (memo e (l \ jitnir l arch))
                  (qualc e) (memo e (l \ jitnir (flatc l) arch))
                  (qualfr e) (memo e (l \ jitfr l arch))         ; float-result leaf -> heap-boxed gem (sound: param floated at first use)
                  (: li (loopinfo e)
                     (? li (memo e (l \ njit-loop l <li <>li <>>li <>>>li (base-ev l)))
                        (: ln (loopinfo-n e)
                           (? ln (memo e (l \ njit-loop-n l <ln <>ln <>>ln <>>>ln <>>>>ln (base-ev l)))
                              ; fall-through: cask-build a string-accumulator loop, lower a complex
                              ; grid to real pairs, then a float-grid nest or an arith group, else interp
                              (base-ev (autogroup (autonat (twolow (castbuild (canon (opfix e))))))))))))
   ; the auto-native ev under the module's own name: `ev` is orth, which a module layer cannot write,
   ; so the boot installs it as (: ev (cite 'glaze 'ev)). a re-load hands the baked auto-ev straight
   ; back, and a trampoline build (love-tco 0) stays the interpreter -- glazed code Continues by
   ; tail-jump, which only the threaded vm honors
   ev (? glaze-loaded? ev
         (0 < love-tco) auto-ev
         ev)
)

)
(: ev (cite 'glaze 'ev))
; hook -- the native-creation hook. book['natjit] is read by ev.l's `ala` on every
; closure built, top-level or embedded: a qualifying leaf, loop, call-out, group or
; amble body is native-backed at creation and deopts into the closure's own bytecode
; `e`, so native is never wrong, only faster. the native cell keeps value[-1]=s, the
; surface src, so =/show see the source; a fresh cell per ala call keeps == honest.
;
; deliberately outside the `glaze` module: ala reads the hook via (gv 'natjit) and
; fires/fired? are its probe, so the three must be on the book, and a post-egg stream
; installs a global only by leaking a body-less `:`. the glaze aliases stay private
; in the inner body-having `:`. the laws are t/glaze-hook.l, `make test_hook`.
(: fires {0}                                                              ; probe counter: closures the hook native-backed
   natjit
    (: arch love-arch                                                     ; the runtime target ('x64 / 'a64), read on the actual binary
       G (cite 'glaze)                                                    ; this file is not in the module (test_glaze re-cats it alone): every name arrives by key
       emit (G 'emit)  coreir (G 'coreir)  deoptir (G 'deoptir)
       loopinfo (G 'loopinfo)  njit-loop (G 'njit-loop)
       loopinfo-n (G 'loopinfo-n)  njit-loop-n (G 'njit-loop-n)
       calloutinfo (G 'calloutinfo)  jitcalloutx (G 'jitcalloutx)
       calloutinfo-frame (G 'calloutinfo-frame)  njit-calloutframe (G 'njit-calloutframe)
       qualfr (G 'qualfr)  jitfrx (G 'jitfrx)
       anat-defs (G 'anat-defs)  jgir-ok? (G 'jgir-ok?)  jitgroupirx (G 'jitgroupirx)  grpfix (G 'grpfix)
       njit-amble (G 'njit-amble)
       asm (cite 'holo 'assemble)                                         ; holo's post-hook build, pinned for the glaze: the cat's later reopen of holo never moves it
       _ (pin (G 'glazeasm) 'f asm)
       _ (pin (G 'glazeasm) 'at (cite 'holo 'assemble-at))
       gvbox (G 'gvbox)                                                     ; auto.l's canon reads globals through ala's gv, pinned here on the first closure
       (hit x) (pin fires () (1 + peep fires () 0), x)
       ; grp-ok? is the group gate: autogroup's own recognizer over the defs jitgroupirx compiles. jgir-ok?
       ; only says the ops are implemented -- a body past the grammar reaches cggir, whose ? chain ends in a
       ; silent () that emits no code for an operand it cannot hold
       (grp-ok? gds) (: cands (map (gd \ [<<gd (#<gd - 1)]) gds) (#(grpfix gds cands) = #gds))   ; (name arity)
       (exprn ps e) (? (elem e ps) 1  (whole? e) 1  (atom? e) 0                    ; the leaf grammar, exact arity: (+ x 1 2) is a tower, not x + 1
                       (e @ (op a b) (elem op '(+ - * // % & | ^ < <= > >= =) && exprn ps a && exprn ps b)
                            ('? c a b) (exprn ps c && exprn ps a && exprn ps b)
                            0))
       (opnd-ok? ps e) (? (two? e) (all (opnd-ok? ps) >e)  (nom? e) (elem e ps)  1)   ; every operand leaf a frame param: jgir has no slot for a free capture
       (gdefs-ok? gds) (all (gd \ opnd-ok? ><gd >gd) gds)                             ; ... and per def body, over that def's own params
       ; e = the bytecode entry (the deopt target), s = the surface (\ frame.. body), a = arity, gv = ala's
       ; folded global resolver (the book is mopped post-egg), farq = the letrec-local predicate (a farq name
       ; is wire-resolved: never gv it, the book namesake is stale), lams = the scope's lambda siblings
       ; ((name . cell)..) verbatim (a cell's (entry . imports) is what lz freezes; entry 0 declines), nm = the
       ; letrec name being bound (0 anonymous: amble's self-call seam), ti/ta = ev.l's uninterned iop/apx
       ; markers, inl = the inner-closure record ((exp src-tail cell)..) amble's site reads
       (natjit e s a gv farq lams nm ti ta inl)
        (: _ (? (peep gvbox 0 0) 0 (pin gvbox 0 gv))
           ps (init >s)  body (last >s)                                                ; the frame [imps args] + the surface body
           (? !(all nom? ps) e                                                       ; a frame that is not all points (a pattern binder) declines every lane
              (two? s && two? >>s && exprn ps body)                                   ; the leaf: >=1 param, a body in the grammar
              (hit (nif (emit (peep (asm arch (coreir arch ps body (deoptir arch (a = 1 ? 0 1)))) 'bytes 0)) e s a))
              (qualfr s) (hit (jitfrx s arch e))                                      ; the float-result leaf boxes a gem; deopt to e, never (ev s), which re-enters ala
              (loopinfo s @ [B I op cmp] (hit (njit-loop s B I op cmp e))             ; the counted loop, then the n-var one: the back-edge is the win
               (loopinfo-n s @ [vars ups T R inits] (hit (njit-loop-n s vars ups T R inits e))
                (: ci (calloutinfo s)                                                 ; a counted sum over (F i), F a resolvable global: the stackless bridge
                   fv (ci && !(farq <ci) && gv <ci 0)
                   (? (lit? fv) (ci @ [_ op iv arg] (hit (jitcalloutx fv s op iv arg arch)))
                      (calloutinfo-frame s @ [F N op arg] (hit (njit-calloutframe s F N a e op arg arch))   ; ... F and the bound read from the frame
                       ; the group lane: a first-order mutually recursive arith group under the frame, its tail
                       ; either (entry frame..) -- flat, no indirection -- or any arith over group calls, through
                       ; a synthetic ((__outer . frame) . tail) entry. post-feel every def is name (\ p.. B)
                       (: pd (? (two? body && (= <body ':)) (anat-defs >body) ())
                          dds (? pd <pd ())  tail (? pd <>pd ())
                          okshape (pd && two? tail && all (dd \ dd @ (n . '\ . _ . _) (nom? n) 0) dds)
                          gdefs (? okshape (map (dd \ (<dd . init >>dd) . last >>dd) dds) ())     ; ((name p..) . B)
                          gnames (map caap gdefs)
                          flat? (okshape && elem <tail gnames && >tail = ps)                     ; the tail is (entry frame..)
                          osym '__outer  agdefs (? okshape (gdefs + [((osym . ps) . tail)]) ())
                          (? (flat? && grp-ok? gdefs && jgir-ok? gdefs && gdefs-ok? gdefs)
                             (hit (jitgroupirx gdefs <tail arch e s))                               ; stamps the outer s: =/show transparent
                             (okshape && !(elem osym gnames) && opnd-ok? ps tail && grp-ok? agdefs && jgir-ok? agdefs && gdefs-ok? gdefs)
                             (hit (jitgroupirx agdefs osym arch e s))
                             (: aj (njit-amble s a e gv farq lams nm ti ta inl arch)                 ; amble, the last lane: 0 on decline
                                (? aj (hit aj)
                                   (getenv "LOVE_AMBLE_TRACE2" && puts ("amble-DECLINE: " + show s + "\n"), e))))))))))))
       natjit)                                                            ; the inner : answers the closure; its aliases stay private
   (fired? n) (n < peep fires () 0))                                       ; did the hook fire since count n?

; walk -- re-declare the prel list walkers through the glazed compiler. the prel
; originals are egg-baked pre-glaze; these compile under the live natjit, so amble owns
; their self-recursion, an applied param takes the drive, and the generic = keeps symbol
; and string keys native. bodies verbatim from l/boot/prel.l, caap spelled through cap (a
; free accessor head declines). loads after hook.l; egg-baked consumers keep the closures
; they folded, every post-boot stream folds these.
(? (0 < love-tco)
   (ev '(: (foldl f z l) (? (two? l) (foldl f (f z (cap l)) (cup l)) z)
           (foldr f z l) (? (two? l) (f (cap l) (foldr f z (cup l))) z)
           (filter p l) (? (two? l) (: m (filter p (cup l)) (? (p (cap l)) (. (cap l) m) m)))
           (revcat l acc) (? (two? l) (revcat (cup l) (. (cap l) acc)) acc)
           (assoc x l) (? (two? l) (? (= x (cap (cap l))) (cap l) (assoc x (cup l))))
           (all f l) (? (two? l) (? (f (cap l)) (all f (cup l)) 0) 1)
           (any f l) (? (two? l) (? (f (cap l)) 1 (any f (cup l))) 0)
           (zip a b) (? (two? a) (? (two? b) (. (. (cap a) (cap b)) (zip (cup a) (cup b)))))
           (drop n l) (? n (drop (- n 1) (cup l)) l)
           (take n l) (? n (? (two? l) (. (cap l) (take (- n 1) (cup l)))))
           (init l) (? (two? (cup l)) (. (cap l) (init (cup l))))
           (last l) (? (two? (cup l)) (last (cup l)) (cap l))
           (ldel x l) (? (two? l) (? (= (cap l) x) (cup l) (. (cap l) (ldel x (cup l)))))))
   0)
