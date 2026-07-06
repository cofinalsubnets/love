; crew/cc/gen.l -- the code generator (rung 3 stage 1). AST -> (1 ir-forms) |
; (). holo's neutral IR, chibicc-plain: every expression computes into r0;
; binaries push the left, evaluate the right, pop into r1, combine 3-address.
; locals live at negative offsets off r4 (the frame register -- rbp, callee-
; saved, its disp quirk handled in holo); arguments ride the SysV integer
; registers rdi rsi rdx rcx r8 r9 = holo r6 r5 r2 r1 r7 r8, at most six a
; call (the stack tail is later seam work); params spill to frame slots at
; the prologue. call args evaluate left to right, push as they go, and pop
; into the registers reversed. stack alignment at calls is OURS alone until
; libc arrives (noted for stage 6).
; offsets never re-used across sibling scopes, the frame is the high-water
; mark, sized after the body generates (forms are data) and rounded to 16.
; ints are 8 BYTES this stage -- 32-bit truncation arrives with stage 2's
; types, so the differential battery steers clear of the overflow edges.
; shifts take CONSTANT counts only (holo shifts by immediate; the register-
; count extension is stage 2 seam work) -- a variable count answers ().
; errors ride up as the nom 'bad (undeclared name, a non-var lvalue, a
; break/continue outside any loop): () is a legitimate empty form list.
(:
   ; the gen state g (a tablet): 'n the label counter, 'off the frame's
   ; high-water offset, 'brk/'cnt the loop label stacks. env: ((name . off)..)
   (nlab g pfx) (: k (peep g 'n 0) _ (pin g 'n (+ k 1)) (intern (+ pfx (show k))))
   argregs '(r6 r5 r2 r1 r7 r8)
   (nthr l i) (? (< i 1) (cap l) (nthr (cup l) (- i 1)))
   (voff env name) (: e (assoc name env) (? (two? e) (caup e) 'bad))
   (bad? x) (id? x 'bad)

   ; expr -> forms leaving the value in r0, | 'bad
   (cgexpr g env e)
    (: k (cap e)
       (? (= k 'num) (L (L 'li 'r0 (caup e)))
          (= k 'var) (: o (voff env (caup e))
                        (? (bad? o) 'bad (L (L 'ld 'r0 'r4 o))))
          (= k 'asn)
           (: lv (caup e)
              (? (! (= (cap lv) 'var)) 'bad
                 (: o (voff env (caup lv))
                    r (cgexpr g env (cauup e))
                    (? (|| (bad? o) (bad? r)) 'bad
                       (cat r (L (L 'st 'r4 o 'r0)))))))
          (= k 'post)
           (: lv (caup e)
              (? (! (= (cap lv) 'var)) 'bad
                 (: o (voff env (caup lv))
                    (? (bad? o) 'bad
                       (L (L 'ld 'r0 'r4 o)
                          (L 'add 'r1 'r0 (cauup e))
                          (L 'st 'r4 o 'r1))))))
          (= k 'un)
           (: r (cgexpr g env (cauup e))
              (? (bad? r) 'bad
                 (cat r (? (= (caup e) 'neg) (L (L 'neg 'r0))
                           (= (caup e) 'bnot) (L (L 'not 'r0))
                           (L (L 'cmp 'r0 0) (L 'set 'eq 'r0))))))
          (= k 'comma)
           (: a (cgexpr g env (caup e)) b (cgexpr g env (cauup e))
              (? (|| (bad? a) (bad? b)) 'bad (cat a b)))
          (= k 'land)
           (: a (cgexpr g env (caup e)) b (cgexpr g env (cauup e))
              lf (nlab g ".f") ld (nlab g ".d")
              (? (|| (bad? a) (bad? b)) 'bad
                 (cat a (cat (L (L 'cmp 'r0 0) (L 'br 'eq lf))
                        (cat b (L (L 'cmp 'r0 0) (L 'br 'eq lf)
                                  (L 'li 'r0 1) (L 'jmp ld)
                                  (L 'label lf) (L 'li 'r0 0) (L 'label ld)))))))
          (= k 'lor)
           (: a (cgexpr g env (caup e)) b (cgexpr g env (cauup e))
              lt (nlab g ".t") ld (nlab g ".d")
              (? (|| (bad? a) (bad? b)) 'bad
                 (cat a (cat (L (L 'cmp 'r0 0) (L 'br 'ne lt))
                        (cat b (L (L 'cmp 'r0 0) (L 'br 'ne lt)
                                  (L 'li 'r0 0) (L 'jmp ld)
                                  (L 'label lt) (L 'li 'r0 1) (L 'label ld)))))))
          (= k 'cond)
           (: c (cgexpr g env (caup e))
              t (cgexpr g env (cauup e))
              el (cgexpr g env (cap (cuuup e)))
              le (nlab g ".e") ld (nlab g ".d")
              (? (|| (bad? c) (|| (bad? t) (bad? el))) 'bad
                 (cat c (cat (L (L 'cmp 'r0 0) (L 'br 'eq le))
                        (cat t (cat (L (L 'jmp ld) (L 'label le))
                               (cat el (L (L 'label ld)))))))))
          (= k 'call)
           (: args (cauup e)
              n (tally args)
              (? (< 6 n) 'bad
                 (: (pushes as acc)
                     (? (! (two? as)) acc
                        (: r (cgexpr g env (cap as))
                           (? (bad? r) 'bad
                              (: r2 (pushes (cup as) (cat acc (cat r (L (L 'push 'r0)))))
                                 (? (bad? r2) 'bad r2)))))
                    up (pushes args ())
                    (pops i acc) (? (< i 0) acc
                                    (pops (- i 1) (cat acc (L (L 'pop (nthr argregs i))))))
                    (? (bad? up) 'bad
                       (cat up (cat (pops (- n 1) ())
                                    (L (L 'call (intern (caup e))))))))))
          (= k 'bin) (cgbin g env e)
          'bad))
   (cgbin g env e)
    (: op (caup e)
       a (cgexpr g env (cauup e))
       b (cgexpr g env (cap (cuuup e)))
       rhs (cap (cuuup e))
       (? (|| (bad? a) (bad? b)) 'bad
          ; constant shift counts ride the immediate shift ops
          (member? op '(shl shr))
           (? (= (cap rhs) 'num)
              (cat a (L (L (? (= op 'shl) 'shl 'sar) 'r0 (caup rhs))))
              'bad)
          ; holo's two-address lowering allows d = a, never d = b (unless
          ; commutative): compute into r1 (= the popped left), mov to r0
          (: mid (cat a (cat (L (L 'push 'r0)) (cat b (L (L 'pop 'r1)))))
             back (L (L 'mov 'r0 'r1))
             tail (? (= op '+) (cat (L (L 'add 'r1 'r1 'r0)) back)
                     (= op '-) (cat (L (L 'sub 'r1 'r1 'r0)) back)
                     (= op '*) (cat (L (L 'imul 'r1 'r1 'r0)) back)
                     (= op '/) (cat (L (L 'div 'r1 'r1 'r0)) back)
                     (= op '%) (cat (L (L 'rem 'r1 'r1 'r0 'r3)) back)
                     (= op '&) (cat (L (L 'and 'r1 'r1 'r0)) back)
                     (= op '|) (cat (L (L 'or 'r1 'r1 'r0)) back)
                     (= op '^) (cat (L (L 'xor 'r1 'r1 'r0)) back)
                     (member? op '(eq ne lt le gt ge))
                      (L (L 'cmp 'r1 'r0) (L 'set op 'r0))
                     'bad)
             (? (bad? tail) 'bad (cat mid tail)))))

   epi (L (L 'mov 'sp 'r4) (L 'pop 'r4) (L 'ret))

   ; a declaration list: allocates offsets, extends env -> (forms env) | 'bad
   (cgdecl g env pairs)
    (: (one ps env2 acc)
        (? (! (two? ps)) (L acc env2)
           (: p (cap ps)
              off (- 0 (+ (peep g 'off 0) 8))
              _ (pin g 'off (+ (peep g 'off 0) 8))
              env3 (link (L (cap p) off) env2)
              (? (two? (caup p))
                 (: r (cgexpr g env3 (caup p))
                    (? (bad? r) 'bad
                       (one (cup ps) env3 (cat acc (cat r (L (L 'st 'r4 off 'r0)))))))
                 (one (cup ps) env3 acc))))
       (one pairs env ()))

   ; stmt -> forms | 'bad. env only grows through cgitems (decl threading)
   (cgstmt g env s)
    (: k (cap s)
       (? (= k 'ret) (: r (cgexpr g env (caup s))
                        (? (bad? r) 'bad (cat r epi)))
          (= k 'expr) (cgexpr g env (caup s))
          (= k 'nop) ()
          (= k 'blk) (: r (cgitems g env (caup s) ())
                        (? (bad? r) 'bad r))
          (= k 'if)
           (: c (cgexpr g env (caup s))
              t (cgstmt g env (cauup s))
              le (nlab g ".e")
              (? (|| (bad? c) (bad? t)) 'bad
                 (! (two? (cap (cuuup s))))
                  (cat c (cat (L (L 'cmp 'r0 0) (L 'br 'eq le)) (cat t (L (L 'label le)))))
                 (: el (cgstmt g env (cap (cuuup s)))
                    ld (nlab g ".d")
                    (? (bad? el) 'bad
                       (cat c (cat (L (L 'cmp 'r0 0) (L 'br 'eq le))
                              (cat t (cat (L (L 'jmp ld) (L 'label le))
                                     (cat el (L (L 'label ld)))))))))))
          (= k 'while)
           (: lc (nlab g ".c") ld (nlab g ".d")
              c (cgexpr g env (caup s))
              _ (pin g 'brk (link ld (g 'brk)))
              _ (pin g 'cnt (link lc (g 'cnt)))
              b (cgstmt g env (cauup s))
              _ (pin g 'brk (cup (g 'brk)))
              _ (pin g 'cnt (cup (g 'cnt)))
              (? (|| (bad? c) (bad? b)) 'bad
                 (cat (L (L 'label lc))
                  (cat c (cat (L (L 'cmp 'r0 0) (L 'br 'eq ld))
                         (cat b (L (L 'jmp lc) (L 'label ld))))))))
          (= k 'for)
           (: init (caup s) cnd (cauup s) stp (cap (cuuup s)) body (caup (cuuup s))
              lc (nlab g ".c") ls (nlab g ".s") ld (nlab g ".d")
              ir (? (! (two? init)) (L () env)
                    (= (cap init) 'decl) (cgdecl g env (caup init))
                    (: r (cgexpr g env (caup init)) (? (bad? r) 'bad (L r env))))
              (? (bad? ir) 'bad
                 (: env2 (caup ir)
                    c (? (two? cnd) (cgexpr g env2 cnd) ())
                    _ (pin g 'brk (link ld (g 'brk)))
                    _ (pin g 'cnt (link ls (g 'cnt)))
                    b (cgstmt g env2 body)
                    _ (pin g 'brk (cup (g 'brk)))
                    _ (pin g 'cnt (cup (g 'cnt)))
                    st2 (? (two? stp) (cgexpr g env2 stp) ())
                    (? (|| (bad? c) (|| (bad? b) (bad? st2))) 'bad
                       (cat (cap ir)
                        (cat (L (L 'label lc))
                         (cat (? (two? cnd) (cat c (L (L 'cmp 'r0 0) (L 'br 'eq ld))) ())
                          (cat b
                           (cat (L (L 'label ls))
                            (cat st2 (L (L 'jmp lc) (L 'label ld))))))))))))
          (= k 'brk) (? (two? (g 'brk)) (L (L 'jmp (cap (g 'brk)))) 'bad)
          (= k 'cont) (? (two? (g 'cnt)) (L (L 'jmp (cap (g 'cnt)))) 'bad)
          'bad))
   ; a block's items, the env threading through decls -> forms | 'bad
   (cgitems g env items acc)
    (? (! (two? items)) acc
       (: it (cap items)
          (? (= (cap it) 'decl)
             (: r (cgdecl g env (caup it))
                (? (bad? r) 'bad
                   (cgitems g (caup r) (cup items) (cat acc (cap r)))))
             (: r (cgstmt g env it)
                (? (bad? r) 'bad
                   (cgitems g env (cup items) (cat acc r)))))))

   (cgfn g f)                                       ; ('fn name params ('blk items)) -> forms | 'bad
    (: params (cauup f)
       (? (< 6 (tally params)) 'bad
          (: _ (pin g 'off 0)
             (spill ps i env acc)                   ; params into frame slots off the arg regs
              (? (! (two? ps)) (L acc env)
                 (: off (- 0 (+ (peep g 'off 0) 8))
                    _ (pin g 'off (+ (peep g 'off 0) 8))
                    (spill (cup ps) (+ i 1)
                           (link (L (cap ps) off) env)
                           (cat acc (L (L 'st 'r4 off (nthr argregs i)))))))
             sp0 (spill params 0 () ())
             body (cgitems g (caup sp0) (caup (caup (cuup f))) ())
             (? (bad? body) 'bad
                (: frame (& (+ (peep g 'off 0) 15) -16)
                   (cat (L (L 'label (intern (caup f)))
                           (L 'push 'r4) (L 'mov 'r4 'sp) (L 'sub 'sp 'sp frame))
                    (cat (cap sp0)
                     (cat body (cat (L (L 'li 'r0 0)) epi)))))))))
   (cgen ast)                                       ; ('prog fns) -> (1 forms) | ()
    (: g (: t (tablet 0) _ (pin t 'n 0) _ (pin t 'brk ()) _ (pin t 'cnt ()) t)
       crt0 (L (L 'call 'main) (L 'mov 'r6 'r0) (L 'li 'r0 60) (L 'sys))
       (gfns fs acc saw)
        (? (! (two? fs))
           (? saw (L 1 (cat crt0 acc)) ())          ; no main, no program
           (: f (cap fs)
              (? (= (cap f) 'proto) (gfns (cup fs) acc saw)
                 (: r (cgfn g f)
                    (? (bad? r) ()
                       (gfns (cup fs) (cat acc r)
                             (|| saw (= (caup f) "main"))))))))
       (gfns (caup ast) () ())))
