; wasmfn -- holo IR to wasm: the lowering of one function, and the whole-program link
; (doc/misc/plan/moon-wasm.md, rungs 1, 2 and 4). the IR is what gen.l emits for rv64 -- the
; a8 argument shape, the sp/fp/lr frame, la for every address, a compare chain for switch --
; and none of it changes: this file is the machine under that lane.
;
; the machine. every abstract register is an i64 local and every f-register an f64 local;
; sp is global 0, the shadow stack in linear memory, so push/pop and the frame are stores.
; control flow is one loop and one br_table over a label local (rung 1): every (label l)
; opens a segment, the entry is segment 0, falling out of block j runs segment j and its
; tail falls into j+1 as the IR does; a jmp sets the local and branches to the loop at depth
; k-j, a br the same under an if, one deeper. the flags are locals (rung 2): A B the last
; cmp's operands, V the overflow sign adds/subs leave, FA FB the last ucomisd's, with rv64's
; float law and which compare came last read in emission order. a narrowed f-register holds
; the single's bits in its low word (x64's law); the conversions saturate.
;
; the convention (rung 4): ONE function type for the whole program, (i64 x 8, f64 x 8) ->
; (i64 i64 f64 f64) -- r0..r7 and f0..f7 in, r0 r1 f0 f1 out (a 16-byte aggregate rides a
; pair) -- because a callr carries no arity and C lets a call disagree with its callee
; anyway. so every function is in the table at its own index, a function's address IS its
; index, callr is call_indirect and a jmpr (gen.l's tail call) return_call_indirect. a call
; clobbers only the four answer registers: a callee's locals are its own.
; the hand lane (test/holo/wasm.l) keeps a per-arity layout, mode n instead of 'uni.

(module 'holo
(: ;; -- the layout: register -> local. uni: r0..r7 0..7, f0..f7 8..15, then r8..r26 fp lr,
   ;;    lab (i32), A B V, f8..f19, FA FB. per-arity n: r0..r26 fp lr, lab, A B V, f0..f19, FA FB. --
   w-st (tablet 0)                                   ; 'uni 'fl (1 after ucomisd) 'labs 'env 'k
   (w-uni? _) (peep w-st 'uni 0)
   w-regs (tabof [('r0 >< 0) ('r1 >< 1) ('r2 >< 2) ('r3 >< 3) ('r4 >< 4) ('r5 >< 5) ('r6 >< 6) ('r7 >< 7)
                  ('r8 >< 8) ('r9 >< 9) ('r10 >< 10) ('r11 >< 11) ('r12 >< 12) ('r13 >< 13) ('r14 >< 14)
                  ('r15 >< 15) ('r16 >< 16) ('r17 >< 17) ('r18 >< 18) ('r19 >< 19) ('r20 >< 20)
                  ('r21 >< 21) ('r22 >< 22) ('r23 >< 23) ('r24 >< 24) ('r25 >< 25) ('r26 >< 26)
                  ('fp >< 27) ('lr >< 28)])
   w-fregs (tabof [('f0 >< 0) ('f1 >< 1) ('f2 >< 2) ('f3 >< 3) ('f4 >< 4) ('f5 >< 5) ('f6 >< 6) ('f7 >< 7)
                   ('f8 >< 8) ('f9 >< 9) ('f10 >< 10) ('f11 >< 11) ('f12 >< 12) ('f13 >< 13) ('f14 >< 14)
                   ('f15 >< 15) ('f16 >< 16) ('f17 >< 17) ('f18 >< 18) ('f19 >< 19)])
   (w-reg r) (: n (peep w-regs r -1)                 ; r0 is 0, and 0 is falsy: a sentinel, never nil?
                (? (n < 0) (scare 'wasm-badreg r) (w-uni? 0) (? (n < 8) n (n + 8)) n))
   (w-freg r) (: n (peep w-fregs r -1)
                 (? (n < 0) (scare 'wasm-badfreg r) (w-uni? 0) (? (n < 8) (n + 8) (n + 33)) (n + 33)))
   (w-lab _) (? (w-uni? 0) 37 29)
   (w-A _) (? (w-uni? 0) 38 30)  (w-B _) (? (w-uni? 0) 39 31)  (w-V _) (? (w-uni? 0) 40 32)
   w-FA 53  w-FB 54
   (w-locals n) (? (w-uni? 0) '((21 i64) (1 i32) (3 i64) (14 f64))
                   [[(29 - n) 'i64] '(1 i32) '(3 i64) '(22 f64)])
   (w-val x) (? (= x 'sp) '((global.get 0)) (reg? x) [['local.get (w-reg x)]] [['i64.const x]])
   (w-set r) (? (= r 'sp) '((global.set 0)) [['local.set (w-reg r)]])
   (w-fval r) [['local.get (w-freg r)]]
   (w-fset r) [['local.set (w-freg r)]]

   ;; -- the ALU and the conditions --
   w-alu (tabof [('add >< 'i64.add) ('sub >< 'i64.sub) ('and >< 'i64.and) ('or >< 'i64.or)
                 ('xor >< 'i64.xor) ('imul >< 'i64.mul) ('div >< 'i64.div_s) ('udiv >< 'i64.div_u)
                 ('rem >< 'i64.rem_s) ('urem >< 'i64.rem_u)
                 ('shl >< 'i64.shl) ('shr >< 'i64.shr_u) ('sar >< 'i64.shr_s) ('rol >< 'i64.rotl) ('ror >< 'i64.rotr)
                 ('shlv >< 'i64.shl) ('shrv >< 'i64.shr_u) ('sarv >< 'i64.shr_s) ('rorv >< 'i64.rotr)])
   w-cc (tabof [('eq >< 'i64.eq) ('ne >< 'i64.ne) ('lt >< 'i64.lt_s) ('le >< 'i64.le_s)
                ('gt >< 'i64.gt_s) ('ge >< 'i64.ge_s) ('below >< 'i64.lt_u) ('be >< 'i64.le_u)
                ('above >< 'i64.gt_u) ('ae >< 'i64.ge_u)])
   (w-fab _) [['local.get w-FA] ['local.get w-FB]]  (w-fba _) [['local.get w-FB] ['local.get w-FA]]
   (w-fcond c)                                       ; FA against FB, rv64's law
    (c @ ('above || 'gt) (w-fba 0 + '((f64.lt)))
         ('be || 'le)    (w-fba 0 + '((f64.lt) (i32.eqz)))
         ('ae || 'ge)    (w-fba 0 + '((f64.le)))
         ('below || 'lt) (w-fba 0 + '((f64.le) (i32.eqz)))
         'eq (w-fab 0 + '((f64.eq)))
         'ne (w-fab 0 + '((f64.eq) (i32.eqz)))
         'np [['local.get w-FA] ['local.get w-FA] '(f64.eq) ['local.get w-FB] ['local.get w-FB] '(f64.eq) '(i32.and)]
         'p  [['local.get w-FA] ['local.get w-FA] '(f64.eq) ['local.get w-FB] ['local.get w-FB] '(f64.eq) '(i32.and) '(i32.eqz)]
             (scare 'wasm-badfcond c))
   (w-cond c)                                        ; the condition as an i32 on the stack
    (? (peep w-st 'fl 0) (w-fcond c)
       (c @ 's  [['local.get (w-A 0)] ['local.get (w-B 0)] '(i64.sub) '(i64.const 0) '(i64.lt_s)]
            'ns [['local.get (w-A 0)] ['local.get (w-B 0)] '(i64.sub) '(i64.const 0) '(i64.ge_s)]
            'vs [['local.get (w-V 0)] '(i64.const 0) '(i64.lt_s)]
            'vc [['local.get (w-V 0)] '(i64.const 0) '(i64.ge_s)]
                (: op (peep w-cc c ())
                   (? !(nom? op) (scare 'wasm-badcond c) [['local.get (w-A 0)] ['local.get (w-B 0)] [op]]))))
   (w-flags a b) (: _ (pin w-st 'fl 0) (w-val a + [['local.set (w-A 0)]] + w-val b + [['local.set (w-B 0)]]))
   ;; adds/subs: d = a op b off saved operands (d may alias), V the overflow sign, flags d vs 0
   (w-addsub op d a b)
    (w-flags a b
     + [['local.get (w-A 0)] ['local.get (w-B 0)] [(w-alu op)]] + w-set d
     + (? (op = 'add)
          (w-val d + [['local.get (w-A 0)] '(i64.xor)] + w-val d + [['local.get (w-B 0)] '(i64.xor)])
          ([['local.get (w-A 0)] ['local.get (w-B 0)] '(i64.xor) ['local.get (w-A 0)]] + w-val d + '((i64.xor))))
     + [['i64.and] ['local.set (w-V 0)]]
     + w-flags d 0)
   ;; mulo: d = a*b, the branch on signed overflow -- no wide multiply, so the quotient check,
   ;; guarded where the division itself would trap (-1 against the minimum)
   (w-mulo d a b lbl dep)
    (w-flags a b
     + [['local.get (w-A 0)] ['local.get (w-B 0)] '(i64.mul)] + w-set d
     + [['local.get (w-A 0)] '(i64.eqz) '(if i32) '(i32.const 0) '(else)
        ['local.get (w-A 0)] '(i64.const -1) '(i64.eq) '(if i32)
        ['local.get (w-B 0)] '(i64.const -9223372036854775808) '(i64.eq) '(else)]
     + w-val d + [['local.get (w-A 0)] '(i64.div_s) ['local.get (w-B 0)] '(i64.ne) '(end) '(end) '(if)]
     + w-jump lbl (dep + 1) + [['end]])

   ;; -- memory: (forms . memarg-offset); a negative displacement folds into the address --
   (w-mem base off) (? (off < 0) ((w-val base + [['i64.const off] '(i64.add)]) . 0) ((w-val base) . off))
   (w-memx base ix sc dp)
    (: a (w-val base + w-val ix + [['i64.const sc] '(i64.mul) '(i64.add)])
       (? (dp < 0) ((a + [['i64.const dp] '(i64.add)]) . 0) (a . dp)))
   w-ld (tabof [('ld >< '(i64.load 3)) ('ld1 >< '(i64.load8_s 0)) ('ld2 >< '(i64.load16_s 1)) ('ld4 >< '(i64.load32_s 2))
                ('ldu1 >< '(i64.load8_u 0)) ('ldu2 >< '(i64.load16_u 1)) ('ldu4 >< '(i64.load32_u 2))])
   w-st-ops (tabof [('st >< '(i64.store 3)) ('st1 >< '(i64.store8 0)) ('st2 >< '(i64.store16 1)) ('st4 >< '(i64.store32 2))])
   (w-load op m d) (: r (w-ld op) (<m + [[<r (r 1) >m]] + w-set d))
   (w-store op m s) (: r (w-st-ops op) (<m + w-val s + [[<r (r 1) >m]]))
   ;; the shadow stack: push and pop move sp by 16, the arm family's law (the frame stays
   ;; 16-aligned; the word sits at the low end), and gen.l's frame offsets count on it
   (w-push s) ('((global.get 0) (i64.const 16) (i64.sub) (global.set 0) (global.get 0)) + w-val s + '((i64.store 3 0)))
   (w-pop d) ('((global.get 0) (i64.load 3 0)) + w-set d + '((global.get 0) (i64.const 16) (i64.add) (global.set 0)))
   ;; r0 <-> [r1], w bytes: the old value (sign-extended) lands in r0
   (w-xchg w)
    (w-val 'r1 + [[(? (w = 4) 'i64.load32_s 'i64.load) (? (w = 4) 2 3) 0] ['local.set (w-A 0)]]
     + w-val 'r1 + w-val 'r0 + [[(? (w = 4) 'i64.store32 'i64.store) (? (w = 4) 2 3) 0]]
     + [['local.get (w-A 0)]] + w-set 'r0)

   ;; -- symbols and calls. env: name -> (fn idx [n]) | (data addr). a call under uni hands
   ;;    every argument local and takes both answers back; the per-arity lane counts. --
   (w-sym x) (peep (peep w-st 'env {}) x ())
   (w-args e) (? (w-uni? 0) (catmap (\ i [['local.get i]]) (jot 16))
                 (catmap (\ i [['local.get i]]) (jot (e 2))))
   (w-rets _) (? (w-uni? 0) [['local.set 9] ['local.set 8] ['local.set 1] ['local.set 0]] [['local.set 0]])
   (w-indirect d op) (? (w-uni? 0) (w-args () + w-val d + [['i32.wrap_i64] [op 0 0]])
                        (scare 'wasm-indirect-needs-uni d))
   (w-la d x) (: e (w-sym x)
                 (? !(two? e) (scare 'wasm-la x)
                    (<e = 'fn) ([['i64.const (e 1)]] + w-set d)
                    (<e = 'data) ([['i64.const (e 1)]] + w-set d)
                    (<e = 'null) ([['i64.const 0]] + w-set d)       ; a weak nothing defined
                    (scare 'wasm-la x)))
   (w-jump l d) (: labs (peep w-st 'labs {}) j (peep labs l -1)
                   (? (j < 0) (scare 'wasm-nolabel l) [['i32.const j] ['local.set (w-lab 0)] ['br d]]))
   ;; a jmp names a label of this function, or a function: gen.l's direct tail call
   (w-jmp l d) (: labs (peep w-st 'labs {}) j (peep labs l -1)
                  (? (0 <= j) (w-jump l d)
                     (: e (w-sym l)
                        (? (two? e && <e = 'fn && (w-uni? 0)) (w-args e + [['return_call (e 1)]])
                           (two? e && <e = 'null) '((unreachable))
                           (scare 'wasm-nolabel l)))))
   (w-call x) (: e (w-sym x)
                 (? (two? e && <e = 'null) '((unreachable))         ; the C guards the call; reaching it is a trap
                    !(two? e && <e = 'fn) (scare 'wasm-nocall x)
                    (w-args e + [['call (e 1)]] + w-rets 0)))
   (w-ret _) (? (w-uni? 0) '((local.get 0) (local.get 1) (local.get 8) (local.get 9) (return)) '((local.get 0) (return)))

   ;; -- one IR form, in segment depth d. what stays refused: sys (the wasm kernel is an import,
   ;;    __ai_sys, and nothing here issues it), tp, raw (inline asm), the 128-bit lane. --
   (w-ins f d)
    (<f @
     'li   (w-val (f 2) + w-set (f 1))
     'mov  (w-val (f 2) + w-set (f 1))
     ('add || 'sub || 'and || 'or || 'xor || 'imul || 'div || 'udiv || 'rem || 'urem)
           (w-val (f 2) + w-val (f 3) + [[(w-alu <f)]] + w-set (f 1))
     'adds (w-addsub 'add (f 1) (f 2) (f 3))
     'subs (w-addsub 'sub (f 1) (f 2) (f 3))
     'mulo (w-mulo (f 1) (f 2) (f 3) (f 5) d)
     ('shl || 'shr || 'sar || 'rol || 'ror || 'shlv || 'shrv || 'sarv || 'rorv)
           (w-val (f 1) + w-val (f 2) + [[(w-alu <f)]] + w-set (f 1))
     'neg  ([['i64.const 0]] + w-val (f 1) + '((i64.sub)) + w-set (f 1))
     'not  (w-val (f 1) + '((i64.const -1) (i64.xor)) + w-set (f 1))
     'inc  (w-val (f 1) + '((i64.const 1) (i64.add)) + w-set (f 1))
     'dec  (w-val (f 1) + '((i64.const 1) (i64.sub)) + w-set (f 1))
     'sx1  (w-val (f 1) + '((i64.extend8_s)) + w-set (f 1))
     'sx2  (w-val (f 1) + '((i64.extend16_s)) + w-set (f 1))
     'sx4  (w-val (f 1) + '((i64.extend32_s)) + w-set (f 1))
     'zx1  (w-val (f 1) + '((i64.const 255) (i64.and)) + w-set (f 1))
     'zx2  (w-val (f 1) + '((i64.const 65535) (i64.and)) + w-set (f 1))
     'zx4  (w-val (f 1) + '((i64.const 4294967295) (i64.and)) + w-set (f 1))
     'clz  (w-val (f 2) + '((i64.clz)) + w-set (f 1))
     'cmp  (w-flags (f 1) (f 2))
     'test (: _ (pin w-st 'fl 0)                    ; the flags are the ALU's again
              (w-val (f 1) + w-val (f 2) + [['i64.and] ['local.set (w-A 0)] ['i64.const 0] ['local.set (w-B 0)]]))
     'set  (w-cond (f 1) + '((i64.extend_i32_u)) + w-set (f 2))
     ('jmp || 'jmp8) (w-jmp (f 1) d)
     ('br || 'br8)   (w-cond (f 1) + [['if]] + w-jump (f 2) (d + 1) + [['end]])
     ('ld || 'ld1 || 'ld2 || 'ld4 || 'ldu1 || 'ldu2 || 'ldu4) (w-load <f (w-mem (f 2) (f 3)) (f 1))
     ('st || 'st1 || 'st2 || 'st4) (w-store <f (w-mem (f 1) (f 2)) (f 3))
     'ldx  (w-load 'ld (w-memx (f 2) (f 3) (f 4) (f 5)) (f 1))
     'stx  (w-store 'st (w-memx (f 1) (f 2) (f 3) (f 4)) (f 5))
     ('lea || 'lean) (w-val (f 2) + [['i64.const (f 3)] '(i64.add)] + w-set (f 1))
     'leax (: m (w-memx (f 2) (f 3) (f 4) (f 5)) (<m + [['i64.const >m] '(i64.add)] + w-set (f 1)))
     ('la || 'lar) (w-la (f 1) (f 2))
     'push (w-push (f 1))
     'pop  (w-pop (f 1))
     'call (w-call (f 1))
     'callr (w-indirect (f 1) 'call_indirect + w-rets 0)
     'jmpr  (w-indirect (f 1) 'return_call_indirect)
     'ret  (w-ret 0)
     ;; raw bytes are inline asm, refused -- except gen.l's own two rv64 idioms for the sync
     ;; builtins, which this one-thread machine lowers: the fence is nothing, the atomic
     ;; swap (amoswap.w/d.aq a0,a0,(a1)) an exchange through A
     'raw (: bs (f 1)
             (? (= bs '(15 0 16 3)) ()
                (= bs '(47 165 165 12)) (w-xchg 4)
                (= bs '(47 181 165 12)) (w-xchg 8)
                (scare 'wasm-noasm bs)))
     'trap '((unreachable))
     ('nop || 'align) ()
     ;; the double lane
     'movsd (w-fval (f 2) + w-fset (f 1))
     ('addsd || 'subsd || 'mulsd || 'divsd)
           (w-fval (f 1) + w-fval (f 2) + [[(peep (tabof [('addsd >< 'f64.add) ('subsd >< 'f64.sub) ('mulsd >< 'f64.mul) ('divsd >< 'f64.div)]) <f ())]] + w-fset (f 1))
     'xorpd (w-fval (f 1) + '((i64.reinterpret_f64)) + w-fval (f 2) + '((i64.reinterpret_f64) (i64.xor) (f64.reinterpret_i64)) + w-fset (f 1))
     'ucomisd (: _ (pin w-st 'fl 1) (w-fval (f 1) + [['local.set w-FA]] + w-fval (f 2) + [['local.set w-FB]]))
     'cvtsi2sd  (w-val (f 2) + '((f64.convert_i64_s)) + w-fset (f 1))
     'cvtui2sd  (w-val (f 2) + '((f64.convert_i64_u)) + w-fset (f 1))
     'cvttsd2si (w-fval (f 2) + '((i64.trunc_sat_f64_s)) + w-set (f 1))
     'cvttsd2ui (w-fval (f 2) + '((i64.trunc_sat_f64_u)) + w-set (f 1))
     'movqxr (w-val (f 2) + '((f64.reinterpret_i64)) + w-fset (f 1))
     'movqrx (w-fval (f 2) + '((i64.reinterpret_f64)) + w-set (f 1))
     'cvtsd2ss (w-fval (f 2) + '((f32.demote_f64) (i32.reinterpret_f32) (i64.extend_i32_u) (f64.reinterpret_i64)) + w-fset (f 1))
     'cvtss2sd (w-fval (f 2) + '((i64.reinterpret_f64) (i32.wrap_i64) (f32.reinterpret_i32) (f64.promote_f32)) + w-fset (f 1))
     'ldsd (: m (w-mem (f 2) (f 3)) (<m + [['f64.load 3 >m]] + w-fset (f 1)))
     'stsd (: m (w-mem (f 1) (f 2)) (<m + w-fval (f 3) + [['f64.store 3 >m]]))
     'ldss (: m (w-mem (f 2) (f 3)) (<m + [['i32.load 2 >m]] + '((i64.extend_i32_u) (f64.reinterpret_i64)) + w-fset (f 1)))
     'stss (: m (w-mem (f 1) (f 2)) (<m + w-fval (f 3) + '((i64.reinterpret_f64) (i32.wrap_i64)) + [['i32.store 2 >m]]))
           (scare 'wasm-noins <f))
   ;; split at the labels: (segments . label tablet), the entry segment 0, labels 1..k in order
   (w-segs prog)
    (: labs {}
       (go l cur segs k)
        (? !(two? l) (rev ((rev cur) . segs))
           (: ins <l
              (? (<ins = 'label) (: _ (pin labs (ins 1) (k + 1)) (go >l () ((rev cur) . segs) (k + 1)))
                 (go >l (ins . cur) segs k))))
       ((go prog () () 0) . labs))
   ;; -> (locals . body). mode: 'uni, or the parameter count of the per-arity lane
   (wasm-fn prog mode env)
    (: uni (= mode 'uni)
       _ (pin w-st 'uni (? uni 1 0)) _ (pin w-st 'fl 0) _ (pin w-st 'env env)
       s (w-segs prog) segs <s k ((tally segs) - 1)
       _ (pin w-st 'labs >s)
       (seg j) (catmap (\ f (w-ins f (k - j))) (segs j))
       ((w-locals (? uni 0 mode))
        . [['i32.const 0] ['local.set (w-lab 0)] '(loop)]
          + catmap (\ _ '((block))) (jot (k + 1))
          + [['local.get (w-lab 0)] ['br_table (jot (k + 1)) 0]]
          + catall (map (\ j ('((end)) + seg j)) (jot (k + 1)))
          + '((end) (unreachable))))

   ;; -- the hand lane's program: functions by name, one type per arity in use. --
   ;;    p: {'imports ((mod name n) ..) 'fns ((name n prog) ..) 'exports (name ..)
   ;;        'memory (min [max]) 'data .. 'start name}
   (wasm-program p)
    (: imps (peep p 'imports ())  fns (peep p 'fns ())
       ars (: t {} _ (map (\ i (pin t (i 2) 1)) imps) _ (map (\ f (pin t (f 1) 1)) fns) (sort (keys t)))
       tyof (: t {} _ (map (\ i (pin t (ars i) i)) (jot (tally ars))) t)
       (ty n) (peep tyof n ())
       env (: t {} ni (tally imps)
              _ (map (\ i (pin t (nom ((imps i) 1)) ['fn i ((imps i) 2)])) (jot ni))   ; a call names it by nom
              _ (map (\ i (pin t ((fns i) 0) ['fn (i + ni) ((fns i) 1)])) (jot (tally fns)))
              t)
       (idx name) (: e (peep env name ()) (? !(two? e) (scare 'wasm-noname name) (e 1)))
       n (tally imps + tally fns)
       start (peep p 'start ())
       {'types (map (\ a [(map (\ _ 'i64) (jot a)) '(i64)]) ars)
        'imports (map (\ i [(i 0) (i 1) ['func (ty (i 2))]]) imps)
        'funcs (map (\ f (: r (wasm-fn (f 2) (f 1) env) [(ty (f 1)) <r >r])) fns)
        'table n 'elem (jot n)
        'memory (peep p 'memory '(1))
        'data (peep p 'data ())
        'exports ((map (\ e [(show e) 'func (idx e)]) (peep p 'exports ())) + '(("mem" memory 0)))
        'start (? (= start ()) -1 (idx start))})

   ;; -- the whole program, off gen.l's objects (rung 4). a tu is cgen-obj's tuple with the
   ;;    weak names appended: (tforms dforms fnames gnames nforms iforms lnames xsecs bforms
   ;;    rforms xfns weaks). the names are strings, the labels in the forms noms. --
   ;; the symbol positions: where a nom in a form is a label and not a register or an op
   (w-symap f ren)
    (: (m x) (peep ren x x)
       (? !(two? f) f
          (<f @ ('label || 'call || 'jmp || 'jmp8 || 'lapool) [<f (m (f 1))]
                ('la || 'lar) [<f (f 1) (m (f 2))]
                'br [<f (f 1) (m (f 2))]
                'mulo [<f (f 1) (f 2) (f 3) (f 4) (m (f 5))]
                'raw [<f (map (\ x (? (two? x && <x = 'fix) [<x (x 1) (x 2) (m (x 3)) (x 4)] x)) (f 1))]
                f)))
   ;; the noms a stream defines (its labels) and the ones it names
   (w-labels forms) (foldl (\ a f (? (two? f && <f = 'label) (pin a (f 1) 1) a)) {} forms)
   (w-refs forms t)
    (foldl (\ a f (? !(two? f) a
                     (<f @ ('call || 'jmp || 'jmp8 || 'lapool) (pin a (f 1) 1)
                           ('la || 'lar) (pin a (f 2) 1)
                           'raw (foldl (\ a2 x (? (two? x && <x = 'fix) (pin a2 (x 3) 1) a2)) a (f 1))
                           a)))
           t forms)
   (w-tu-streams tu) ((tu 0) + (tu 1) + (tu 4) + (tu 5) + (tu 8) + (tu 9)
                      + catmap (\ x (x 1)) (tu 7) + catmap (\ x (x 1)) (tu 10))
   ;; the ledger of one tu: (defs . refs), the global names it defines and the names it
   ;; wants from outside -- for a driver pulling a runtime by need
   (wasm-tu-syms tu)
    (: defs (map nom ((tu 2) + (tu 3)))
       labs (w-labels (w-tu-streams tu))
       refs (filter (\ x !(peep labs x 0)) (keys (w-refs (w-tu-streams tu) {})))
       (defs . refs))
   ;; the text stream split at the function labels -> ((name forms) ..), between-function
   ;; alignment dropped; the sectioned functions (xfns) ride the same shape
   ;; -> (((name forms) ..) . aliases): a second function label on code nothing has been
   ;; laid for yet is another name for the same function (an alias attribute)
   (w-split forms fnset)
    (: als {}
       (go l cur name acc)
        (? !(two? l) (rev (? (= name ()) acc ([name (rev cur)] . acc)))
           (: f <l
              (? (two? f && <f = 'label && peep fnset (f 1) 0)
                 (? (!(= name ()) && !(two? cur)) (: _ (pin als (f 1) name) (go >l cur name acc))
                    (go >l () (f 1) (? (= name ()) acc ([name (rev cur)] . acc))))
                 (two? f && <f = 'align) (go >l cur name acc)
                 (go >l (f . cur) name acc))))
       ((go forms () () ()) . als))
   ;; a data stream laid at addr: (addr' items) with items ((addr . bytes) | (addr fix-sym aux))
   (w-lay-data forms addr syms items)
    (? !(two? forms) [addr items]
       (: f <forms
          (? (<f = 'label) (: _ (pin syms (f 1) ['data addr]) (w-lay-data >forms addr syms items))
             (<f = 'align) (: n (f 1) a2 (addr + ((n - (addr % n)) % n))
                              (w-lay-data >forms a2 syms items))
             (<f = 'raw) (: (go xs a acc)
                             (? !(two? xs) (w-lay-data >forms a syms acc)
                                (two? <xs) (go >xs (a + 8) ([a (<xs 3) (<xs 4)] . acc))
                                (go >xs (a + 1) ((a . <xs) . acc)))
                            (go (f 1) addr items))
             (scare 'wasm-data-form <f))))
   (w-align16 a) (a + ((16 - (a % 16)) % 16))
   ;; opts: 'imports (name ..) the functions the environment supplies; 'exports (name ..) | 'all;
   ;; 'stack bytes; 'base addr
   (wasm-link tus opts)
    (: ntu (tally tus)
       ;; 1. every tu-local label wears the tu's number, so two statics never meet
       ren1 (map (\ i (: tu (tus i)
                          glob (: t {} _ (map (\ s (pin t (nom s) 1)) ((tu 2) + (tu 3))) t)
                          labs (w-labels (w-tu-streams tu))
                          r {}
                          _ (map (\ l (? (peep glob l 0) 0 (pin r l (nom (show l + "." + show i))))) (keys labs))
                          r))
                 (jot ntu))
       (rn i forms) (map (\ f (w-symap f (ren1 i))) forms)
       tus1 (map (\ i (: tu (tus i)
                           [(rn i (tu 0)) (rn i (tu 1)) (tu 2) (tu 3) (rn i (tu 4)) (rn i (tu 5)) (tu 6)
                            (map (\ x [(x 0) (rn i (x 1)) (x 2)]) (tu 7))
                            (rn i (tu 8)) (rn i (tu 9))
                            (map (\ x [(x 0) (rn i (x 1)) (x 2)]) (tu 10)) (tu 11)]))
                 (jot ntu))
       ;; 2. weak against strong: a weak definition with a strong twin elsewhere keeps its
       ;;    body under a private name; two weak ones, the first stands
       strong (: t {} _ (map (\ tu (map (\ s (? (member? s (tu 11)) 0 (pin t (nom s) 1))) ((tu 2) + (tu 3)))) tus1) t)
       wkseen {}
       ren2 (map (\ i (: tu (tus1 i) r {}
                          _ (map (\ s (: l (nom s)
                                         (? !(member? s (tu 11)) 0
                                            (peep strong l 0) (pin r l (nom (show l + ".wk." + show i)))
                                            (peep wkseen l 0) (pin r l (nom (show l + ".wk." + show i)))
                                            (pin wkseen l 1))))
                                 ((tu 2) + (tu 3)))
                          r))
                 (jot ntu))
       (rd i forms) (map (\ f (? (two? f && <f = 'label) (w-symap f (ren2 i)) f)) forms)   ; the definition alone
       tus2 (map (\ i (: tu (tus1 i)
                           [(rd i (tu 0)) (rd i (tu 1)) (tu 2) (tu 3) (rd i (tu 4)) (rd i (tu 5)) (tu 6)
                            (map (\ x [(x 0) (rd i (x 1)) (x 2)]) (tu 7))
                            (rd i (tu 8)) (rd i (tu 9))
                            (map (\ x [(x 0) (rd i (x 1)) (x 2)]) (tu 10)) (tu 11)]))
                 (jot ntu))
       ;; 3. the functions, in tu order and stream order; every label of a text stream that is
       ;;    a function symbol opens one (the rest are the function's own)
       fnsets (map (\ i (: tu (tus2 i) t {}
                           _ (map (\ s (pin t (peep (ren1 i) (nom s) (nom s)) 1)) ((tu 2) + (tu 6)))   ; a static wears its tu
                           _ (map (\ x (map (\ f (? (two? f && <f = 'label) (pin t (f 1) 1) 0)) (x 1))) (tu 10))
                           _ (map (\ k (pin t (peep (ren2 i) k 0) 1)) (keys (ren2 i)))   ; a renamed weak keeps its slot
                           t))
                   (jot ntu))
       splits (catmap (\ i (: tu (tus2 i) fs (fnsets i)
                              ((w-split (tu 0) fs) . map (\ x (w-split (x 1) fs)) (tu 10))))
                      (jot ntu))
       fns (catmap cap splits)
       als (catmap (\ s (map (\ k [k (peep >s k ())]) (keys >s))) splits)   ; (alias . name) pairs
       ;; 4. the data, section-major across the tus: rodata, data, love_nifs, .love.image, then
       ;;    the named sections grouped by name, then every bss. a lane the ELF linker brackets
       ;;    (love_nifs, love_rela, every named section) gets its __start_/__stop_ pair here.
       syms {}
       base (peep opts 'base 4096)
       (lay st forms) (: r (w-lay-data forms (w-align16 <st) syms (st 1)) [<r (r 1)])
       (lane st forms) (foldl lay st forms)
       (bracket nm st forms)                          ; the pair around one lane's whole
        (: a (w-align16 <st) r (lane [a (st 1)] forms)
           _ (pin syms (nom ("__start_" + nm)) ['data a])
           _ (pin syms (nom ("__stop_" + nm)) ['data <r])
           r)
       xnames (: (go l acc) (? !(two? l) (rev acc) (go >l (? (member? <l acc) acc (<l . acc))))
                 (go (catmap (\ tu (map (\ x (x 0)) (tu 7))) tus2) ()))
       st1 (lane [base ()] (map (\ tu (tu 9)) tus2))
       st2 (lane st1 (map (\ tu (tu 1)) tus2))
       st3 (bracket "love_nifs" st2 (map (\ tu (tu 4)) tus2))
       st4 (bracket "love_rela" st3 ())
       st5 (lane st4 (map (\ tu (tu 5)) tus2))
       st6 (foldl (\ st nm (bracket nm st (catmap (\ tu (catmap (\ x (? (= (x 0) nm) [(x 1)] ())) (tu 7))) tus2)))
                  st5 xnames)
       dend <st6
       _ (pin syms '__data_start__ ['data base]) _ (pin syms '__data_load__ ['data base])
       _ (pin syms '__data_end__ ['data dend])
       st7 (lane [(w-align16 dend) (st6 1)] (map (\ tu (tu 8)) tus2))
       bend <st7
       _ (pin syms '__bss_start__ ['data (w-align16 dend)]) _ (pin syms '__bss_end__ ['data bend])
       _ (pin syms '__load_size__ ['data (bend - base)])
       items (rev (st7 1))
       ;; 5. the index space: the imports the program names, then the functions
       defd (foldl (\ a tu (: t (w-labels (w-tu-streams tu)) _ (map (\ k (pin a k 1)) (keys t)) a)) {} tus2)
       refs (keys (foldl (\ a tu (w-refs (w-tu-streams tu) a)) {} tus2))
       owed0 (filter (\ x (!(peep defd x 0) && !(two? (peep syms x ())))) refs)   ; a bracket is the link's
       ;; a weak reference nothing defines is null, as at a static link; the rest are imports
       wkall (foldl (\ a tu (: _ (map (\ s (pin a (nom s) 1)) (tu 11)) a)) {} tus2)
       _ (pin wkall 'main 1)                            ; a module with a face of its own has no main; the runtime's start never runs
       _ (map (\ x (? (peep wkall x 0) (pin syms x '(null)) 0)) owed0)
       owed (filter (\ x !(peep wkall x 0)) owed0)
       allowed (map nom (peep opts 'imports ()))
       bad (filter (\ x !(member? x allowed)) owed)
       _ (? (two? bad) (scare 'wasm-undefined bad) 0)
       imps (filter (\ x (member? x owed)) allowed)
       ni (tally imps)
       _ (map (\ i (pin syms (imps i) ['fn i])) (jot ni))
       _ (map (\ i (pin syms ((fns i) 0) ['fn (i + ni)])) (jot (tally fns)))
       _ (map (\ a (pin syms (a 0) (peep syms (a 1) ()))) (als + als))   ; twice: an alias of an alias
       ;; 6. the data image, its pointers resolved: a function's address is its index
       (symval x) (: e (peep syms x ()) (? !(two? e) (scare 'wasm-unresolved x) (e 1)))
       dsize (dend - base)
       img (cask dsize)
       _ (map (\ it (? (two? >it)                             ; (addr sym aux): an abs64 pointer
                        (: v ((symval (it 1)) + (it 2)) a (<it - base)
                           (map (\ j (pin img (a + j) ((v // (256 ** j)) % 256))) (jot 8)))
                        (? (<it < dend) (pin img (<it - base) >it) 0)))   ; bss stays zero
              items)
       ;; 7. the stack above the data, sp at its top; the memory holds it all
       stack (peep opts 'stack 4194304)
       sp0 (w-align16 bend + stack)
       pages ((sp0 + 65535) // 65536 + 1)
       exports (: e (peep opts 'exports 'all)
                  seen {}                                 ; a weak twin names the same export once
                  (? (= e 'all) (catmap (\ tu (filter (\ s (? (peep seen s 0) 0 (: _ (pin seen s 1) (two? (peep syms (nom s) ()))))) (tu 2))) tus2) e))
       {'types '(((i64 i64 i64 i64 i64 i64 i64 i64 f64 f64 f64 f64 f64 f64 f64 f64) (i64 i64 f64 f64)))
        'imports (map (\ x ["env" (show x) '(func 0)]) imps)
        'funcs (map (\ f (: r (wasm-fn (f 1) 'uni syms) [0 <r >r])) fns)
        'table (ni + tally fns) 'elem (jot (ni + tally fns))
        'memory [pages]
        'globals [['i64 1 [['i64.const sp0]]]]
        'exports ((map (\ s [s 'func (symval (nom s))]) exports) + '(("mem" memory 0)))
        'data [(base . string img)]
        'names (map (\ i [i (show (imps i))]) (jot ni) + map (\ i [(i + ni) (show ((fns i) 0))]) (jot (tally fns)))
        'start -1}))
) ; module 'holo
