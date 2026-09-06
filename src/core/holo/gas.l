; gas -- the GNU-dialect front for inline asm: the text an `asm("..")` template carries once its
; operands are substituted, in the assembler syntax the target's own toolchain speaks (AT&T on
; x64, ARM on a64, riscv, thumb), lowered to the neutral IR src/core/holo/holo.l assembles. where
; text.l reads holo's own mnemonics over abstract registers, this reads what clang and gcc read,
; so one template serves every compiler. it encodes nothing itself: every line lands on a backend
; row, so the encodings stay where they are gated (test/holo/golden.l). (as.l is the physical
; encoder over the same x64 value; this one is the inline-asm dialect front.)
;
;   (gas-text tgt src)          ; text -> IR forms, tgt one of 'x64 'a64 'rv64 'thumb2 'thumb1
;   (gas-reg tgt r w mod)       ; the dialect's spelling of neutral register r at byte width w
;   (gas-imm tgt n mod)         ; .. of an immediate ("$3" / "3" / "#3")
;   (gas-mem tgt r)             ; .. of a memory operand at register r ("(%rax)" / "[x0]" / "0(a0)")
;   (gas-regname tgt s)         ; the dialect's register name -> the neutral symbol, () if unknown
;
; what a line may say is what the neutral IR can carry: 64-bit register ops, immediates, base +
; displacement memory, labels local to the template (GNU's `1:` / `1f` / `1b` included), and the
; system lane. x64's 32-bit forms ride the 64-bit op plus a zero-extend; the 8/16-bit register
; forms and indexed memory refuse. a line that fits nothing scares, so a typo never drops out.
; a multi-instruction template separates on `\n` or `;`, as GNU does. the x64 text is read by
; src/core/holo/dialect.l's att-read -- the same parsed instruction as.l encodes and the Intel
; dialect shows -- and only lowered here; the other dialects still parse their own lines.

(module 'holo
(: ;; the lexer (gtoks) and the immediate expressions (gimm) sit in src/core/holo/dialect.l,
   ;; shared with the x86 lens; the lines and local labels below are GNU's, for every dialect

   ;; -- lines. a template separates on newline or `;`; `//` comments everywhere, `#` where it is
   ;; not the immediate marker. GNU's numeric local labels resolve here, before any dialect looks:
   ;; the k-th `N:` becomes the symbol lN.k, `Nf` the next one, `Nb` the last one. --
   (gcut s c) (: i ((: (g j) (? (j >= #s) -1 (s j = c) j (g (j + 1)))) 0) (? (i < 0) s (snip s 0 i)))
   (gcut2 s c) (: n #s
      i ((: (g j) (? (j + 1 >= n) -1 (s j = c && s (j + 1) = c) j (g (j + 1)))) 0)
      (? (i < 0) s (snip s 0 i)))
   (gsplit s c) (: n #s
      ((: (g i st acc) (? (i >= n) (rev (snip s st n . acc))
                          (s i = c) (g (i + 1) (i + 1) (snip s st i . acc))
                          (g (i + 1) st acc))) 0 0 ()))
   (glines src hash?) (foldr (\ ln acc (gsplit ln 59 + acc)) ()
                             (map (\ ln (: a (gcut2 ln 47) (? hash? (gcut a 35) a))) (gsplit src 10)))
   (glabel n k) (name ("l" + show n + "." + show k))
   (glocal toks lc)                                 ; (lref n d) -> (sym), the count tablet updated by defs
    (toks @ (('num n) ('ch 58)) (: k (1 + peep lc n 0) _ (pin lc n k) [['sym (show (glabel n k))] '(ch 58)])
          (map (\ t (t @ ('lref n d) ['sym (show (glabel n (? (d = 102) (1 + peep lc n 0) (peep lc n 0))))] t)) toks))
   ;; the operand runs: top-level commas split, parens and brackets nest
   (gops toks) (: (go l d cur acc)
                   (? !(two? l) (rev (? (two? cur) (rev cur . acc) acc))
                      (: t <l
                         (? ((= t '(ch 40)) || (= t '(ch 91))) (go >l (d + 1) (t . cur) acc)
                            ((= t '(ch 41)) || (= t '(ch 93))) (go >l (d - 1) (t . cur) acc)
                            ((= t '(ch 44)) && d = 0) (go >l d () (rev cur . acc))
                            (go >l d (t . cur) acc))))
                  (go toks 0 () ()))
   ;; a line is a label (`name:`) or a mnemonic and its operand runs
   (gline toks) (? !(two? toks) ()
                   (toks @ (('sym s) ('ch 58)) ['label (name s)]
                           (('sym s) . rest) ['ins (name s) (gops rest)]
                           (scare 'gas-line toks)))

   ;; -- the register files, dialect name -> neutral (and back). --
   (gtab rows) (: t (tablet 0) _ (foldl (\ _ p (pin t <p <>p)) 0 rows) t)
   (ghas? t k) (nom? (peep t k ()))                ; a symbol-valued row is there
   x64-rows '((r0 "rax" "eax" "ax" "al") (r1 "rcx" "ecx" "cx" "cl") (r2 "rdx" "edx" "dx" "dl")
              (r3 "rbx" "ebx" "bx" "bl") (sp "rsp" "esp" "sp" "spl") (r4 "rbp" "ebp" "bp" "bpl")
              (r5 "rsi" "esi" "si" "sil") (r6 "rdi" "edi" "di" "dil")
              (r7 "r8" "r8d" "r8w" "r8b") (r8 "r9" "r9d" "r9w" "r9b") (r9 "r10" "r10d" "r10w" "r10b")
              (r10 "r11" "r11d" "r11w" "r11b") (r11 "r12" "r12d" "r12w" "r12b")
              (r12 "r13" "r13d" "r13w" "r13b") (r13 "r14" "r14d" "r14w" "r14b") (r14 "r15" "r15d" "r15w" "r15b"))
   x64-regs (: t (tablet 0)                           ; name -> (rN w)
                _ (foldl (\ _ row (: r <row
                                    _ (pin t (name (row 1)) [r 8]) _ (pin t (name (row 2)) [r 4])
                                    _ (pin t (name (row 3)) [r 2]) _ (pin t (name (row 4)) [r 1]) 0))
                         0 x64-rows)
                t)
   x64-names (gtab (map (\ row [<row >row]) x64-rows))   ; rN -> (q l w b)
   (gx-cr s) (? (#s = 3 && s 0 = 99 && s 1 = 114 && gdig? (s 2)) ['cr (s 2 - 48)] ())
   a64-names (: t (tablet 0)
                _ (foldl (\ _ i (pin t (name ("x" + show i)) (name ("r" + show i)))) 0 ^29)
                _ (foldl (\ _ p (pin t <p <>p)) 0 '((x29 fp) (x30 lr) (sp sp) (xzr zr)))
                t)
   rv-names (gtab '((zero zr) (x0 zr) (ra lr) (sp sp) (s0 fp) (fp fp) (s1 r15)
                    (a0 r0) (a1 r1) (a2 r2) (a3 r3) (a4 r4) (a5 r5) (a6 r6) (a7 r7)
                    (t0 r8) (t1 r9) (t2 r10) (t3 r11) (t4 r12) (s2 r13) (s3 r14)
                    (s4 r19) (s5 r20) (s6 r21) (s7 r22) (s8 r23) (s9 r24) (s10 r25) (s11 r26)))
   rv-back (gtab '((zr zero) (lr ra) (sp sp) (fp s0) (r15 s1)
                   (r0 a0) (r1 a1) (r2 a2) (r3 a3) (r4 a4) (r5 a5) (r6 a6) (r7 a7)
                   (r8 t0) (r9 t1) (r10 t2) (r11 t3) (r12 t4) (r13 s2) (r14 s3)
                   (r19 s4) (r20 s5) (r21 s6) (r22 s7) (r23 s8) (r24 s9) (r25 s10) (r26 s11)))
   t32-names (: t (tablet 0)
                _ (foldl (\ _ i (pin t (name ("r" + show i)) (name ("r" + show i)))) 0 ^13)
                _ (pin t 'sp 'sp) _ (pin t 'lr 'lr)
                t)
   (gthumb? tgt) (member? tgt '(thumb2 thumb2sp thumb1))

   ;; the dialect's spelling of the neutral file, for operand substitution. `mod` is GNU's
   ;; modifier letter (x64 b/w/k/q, a64 w/x) or 0.
   (gas-reg tgt r w mod)
    (? (= tgt 'x64)
        (: ns (peep x64-names r ())
           w9 (mod @ 98 1 119 2 107 4 113 8 w)
           (? !(two? ns) (scare 'gas-reg r)
              ("%" + ns (w9 @ 1 3 2 2 4 1 0))))
       (= tgt 'a64)
        (: k (r @ 'sp "sp" 'fp "29" 'lr "30" (snip (show r) 1 #(show r)))
           w9 (mod @ 119 4 120 8 w)
           (? (= r 'sp) "sp" ((? (w9 <= 4) "w" "x") + k)))
       (= tgt 'rv64) (: s (peep rv-back r ()) (? !s (scare 'gas-reg r) (show s)))
       (show r))
   (gas-imm tgt n mod) (? (= tgt 'x64) (? (= mod 99) (show n) ("$" + show n))
                          (gthumb? tgt) ("#" + show n)
                          (show n))
   (gas-mem tgt r) (? (= tgt 'x64) ("(" + gas-reg tgt r 8 0 + ")")
                      (= tgt 'rv64) ("0(" + gas-reg tgt r 8 0 + ")")
                      ("[" + gas-reg tgt r 8 0 + "]"))
   (gas-regname tgt s)
    (: k (name s)
       (? (= tgt 'x64) (: e (peep x64-regs k ()) (? (two? e) <e ()))
          (= tgt 'a64) (peep a64-names k ())
          (= tgt 'rv64) (peep rv-names k ())
          (peep t32-names k ())))

   ;; -- x64: the AT&T text is read by src/core/holo/dialect.l (att-read) into the parsed
   ;;    instruction -- (op mn w ops), destination first, physical registers -- and lowered here.
   ;;    GNU's numeric local labels resolve over the read items first, the k-th `N:` becoming
   ;;    lN.k, `Nf` the next one, `Nb` the last one. --
   gx-neutral '(r0 r1 r2 r3 sp r4 r5 r6 r7 r8 r9 r10 r11 r12 r13 r14)    ; the neutral file, by encoding
   (gx-r o) (? (<o = 'rg && <>o < 16) (gx-neutral <>o) (scare 'gas-x64-register o))
   (gx-rv o) (? (<o = 'im) <>o (gx-r o))                            ; a register or an immediate
   (gx-imm o) (? (<o = 'im) <>o (scare 'gas-x64-operand o))
   (gx-mem o) (? (<o = 'mem && (o 1) >= 0 && (o 2) < 0) [(gx-neutral (o 1)) (o 4)]    ; -> (base disp)
                 (scare 'gas-x64-operand o))
   (gx-zx d w) (? (w = 4) [['zx4 d]] (w = 8) () (scare 'gas-x64-width w))
   (gx-lop w) (w @ 8 'ld 4 'ldu4 2 'ldu2 'ldu1)
   (gx-sop w) (w @ 8 'st 4 'st4 2 'st2 'st1)
   (gx-iop w) (w @ 8 'si 4 'si4 2 'si2 'si1)
   gx-nils (gtab '((cli cli) (sti sti) (hlt hlt) (ud2 ud2) (iretq iretq) (swapgs swapgs)
                   (rdmsr rdmsr) (wrmsr wrmsr) (cpuid cpuid) (rdtsc rdtsc)
                   (vmrun vmrun) (vmload vmload) (vmsave vmsave) (stgi stgi) (clgi clgi)
                   (vmlaunch vmlaunch) (vmxoff vmxoff) (cld cld)
                   (inb inb) (inw inw) (inl inl) (outb outb) (outw outw) (outl outl)
                   (insb insb) (insw insw) (insl insl) (outsb outsb) (outsw outsw) (outsl outsl)
                   (nop nop) (ret ret) (syscall sys) (int3 trap)))
   gx-alu '(add sub and or xor imul)
   gx-cc (gtab '((je eq) (jz eq) (jne ne) (jnz ne) (jl lt) (jle le) (jg gt) (jge ge)
                 (jb below) (jc below) (jnae below) (ja above) (jnbe above)
                 (jae ae) (jnb ae) (jnc ae) (jbe be) (jna be) (js s) (jns ns) (jo vs) (jno vc)))
   gx-mem2 '(vmxon vmclear vmptrld sgdt sidt lgdt lidt invlpg)
   gx-ext (gtab '((movzb (zx1 ldu1)) (movzw (zx2 ldu2)) (movsb (sx1 ld1)) (movsw (sx2 ld2)) (movsl (sx4 ld4))))
   (gx-ins m w0 ops)
    (: k #ops w (w0 > 0 ? w0 8)
       d (k > 0 ? (ops 0) ()) s (k > 1 ? (ops 1) ())
       (? (ghas? gx-nils m) [[(gx-nils m)]]
          (two? (peep gx-ext m ()))
           (: e (gx-ext m) x (gx-r d)
              (? (<s = 'rg) [['mov x (gx-r s)] [<e x]]
                 (<s = 'mem) (: bm (gx-mem s) [[<>e x <bm <>bm]])
                 (scare 'gas-x64-operand s)))
          (ghas? gx-cc m) [['br (gx-cc m) <>d]]
          (= m 'jmp) (? (<d = 'lbl) [['jmp <>d]] (<d = 'ind) [['jmpr (gx-r <>d)]] (scare 'gas-x64-operand ops))
          (= m 'call) (? (<d = 'lbl) [['call <>d]] (<d = 'ind) [['callr (gx-r <>d)]] (scare 'gas-x64-operand ops))
          (= m 'int) [['int (gx-imm d)]]
          (member? m gx-mem2) (: bm (gx-mem d) [[m <bm <>bm]])
          (= m 'vmread) [['vmread (gx-r d) (gx-r s)]]
          (= m 'vmwrite) [['vmwrite (gx-r d) (gx-r s)]]
          (= m 'mov)
           (? (<d = 'cr) [['stcr <>d (gx-r s)]]
              (<s = 'cr) [['ldcr (gx-r d) <>s]]
              (<d = 'rg)
               (: x (gx-r d)
                  (? (<s = 'im) [['li x (? (w = 4) (<>s & 4294967295) (w = 8) <>s (scare 'gas-x64-width w))]]
                     (<s = 'rg) ([['mov x (gx-r s)]] + gx-zx x w)
                     (<s = 'mem) (: bm (gx-mem s) [[(gx-lop w) x <bm <>bm]])
                     (scare 'gas-x64-operand s)))
              (<d = 'mem)
               (: bm (gx-mem d)
                  (? (<s = 'rg) [[(gx-sop w) <bm <>bm (gx-r s)]]
                     (<s = 'im) [[(gx-iop w) <bm <>bm <>s]]
                     (scare 'gas-x64-operand s)))
              (scare 'gas-x64-operand d))
          (= m 'lea)
           (? (<s = 'rip && <>>s = 0) [['la (gx-r d) <>s]]
              (<s = 'mem) (: bm (gx-mem s) [['lea (gx-r d) <bm <>bm]])
              (scare 'gas-x64-operand ops))
          (member? m gx-alu)
           (? (k = 3) [['imul (gx-r d) (gx-r s) (gx-imm (ops 2))]]
              (: x (gx-r d) v (gx-rv s)
                 ([[m x x v]] + (? (m = 'xor && v = x) () (gx-zx x w)))))
          (= m 'cmp) [['cmp (gx-r d) (gx-rv s)]]
          (= m 'test) [['test (gx-r d) (gx-rv s)]]
          (member? m '(shl sal shr sar rol ror))
           (: op (m = 'sal ? 'shl m) x (gx-r d)
              (? (k = 1) [[op x 1]]
                 (<s = 'im) [[op x <>s]]
                 (<s = 'rg && <>s = 1 && <>>s = 1) [[(name (show op + "v")) x 'r1]]
                 (scare 'gas-x64-operand ops)))
          (member? m '(not neg inc dec push pop)) [[m (gx-r d)]]
          (= m 'div) [[(w = 4 ? 'divl 'divq) (gx-r d)]]
          (= m 'ltr) [['ltr (gx-r d)]]
          (scare 'gas-x64-op m)))
   (gx-locals items)
    (: lc {}
       (lref s) (: t (show s) n #t c (t (n - 1))                  ; "1f" / "1b" -> (n . dir), else ()
                   (? (n > 1 && (c = 102 || c = 98) && xa-allof? (snip t 0 (n - 1)) xa-dig? 0)
                      ((xa-num (snip t 0 (n - 1))) . c) ()))
       (ref s) (: r (lref s) (? !(two? r) s (glabel <r (>r = 102 ? (1 + peep lc <r 0) (peep lc <r 0)))))
       (fix o) (<o @ 'lbl ['lbl (ref <>o)] 'rip ['rip (ref <>o) <>>o] o)
       (rev (foldl (\ acc it
                      ((<it @ 'label (: t (show <>it)
                                        (? (xa-allof? t xa-dig? 0)
                                           (: n (xa-num t) k (1 + peep lc n 0) _ (pin lc n k) ['label (glabel n k)])
                                           it))
                            'op ['op (it 1) (it 2) (map fix (it 3))]
                            it) . acc))
                   () items)))
   (gx-item it) (<it @ 'label [['label <>it]]
                      'op (gx-ins (it 1) (it 2) (it 3))
                      (scare 'gas-x64-line it))                    ; a directive has no place in a template
   (gx-text src) (catmap gx-item (gx-locals (att-read src)))

   ;; -- a64, the ARM dialect: dst first, xN/wN/sp/xzr, #imm, [base, #off], b.cond. --
   ;; operands: (reg rN w) | zr | (imm n) | (mem base off) | (sym s) -- a sysreg, an option, a label
   (ga-reg s) (: k (name s)
                 (? (nom? (peep a64-names k ())) ['reg (a64-names k) 8]
                    (= k 'xzr || (= k 'wzr)) 'zr
                    (#s > 1 && s 0 = 119 && gdig? (s 1)) ['reg (peep a64-names (name ("x" + snip s 1 #s)) ()) 4]
                    ()))
   (ga-opnd toks)
    (toks @ (('ch 35) . rest) ['imm (gimm rest)]
            (('num _) . _) ['imm (gimm toks)]
            (('ch 40) . _) ['imm (gimm toks)]
            (('ch 45) . _) ['imm (gimm toks)]
            (('sym s)) (: r (ga-reg s) (? (two? r || nom? r) r ['sym (name s)]))
            (('ch 91) ('sym b) ('ch 93)) ['mem (<>(ga-reg b)) 0]
            (('ch 91) . ('sym b) . ('ch 44) . rest)
             (: r (ga-reg b) n #rest
                (? (!(two? r) || !((rest (n - 1)) = '(ch 93))) (scare 'gas-a64-operand toks)
                   ['mem <>r (<>(ga-opnd (rev >(rev rest))))]))
            (scare 'gas-a64-operand toks))
   (ga-r o) (o @ ('reg x _) x 'zr 'zr (scare 'gas-a64-register o))
   (ga-rw o) (o @ ('reg x w) [x w] (scare 'gas-a64-register o))
   (ga-v o) (o @ ('imm n) n ('reg x _) x 'zr 'zr (scare 'gas-a64-operand o))   ; a register or an immediate
   ga-cc (gtab '((eq eq) (ne ne) (cs ae) (hs ae) (cc below) (lo below) (mi s) (pl ns)
                 (vs vs) (vc vc) (hi above) (ls be) (ge ge) (lt lt) (gt gt) (le le)))
   ga-nils (gtab '((nop nop) (wfi wfi) (wfe wfe) (isb isb) (eret eret) (ret ret)))
   ga-alu (gtab '((add add) (sub sub) (and and) (orr or) (eor xor) (mul imul) (adds adds) (subs subs)))
   ga-exc (gtab '((brk brk) (hvc hvc) (smc smc) (udf udf) (hlt dbrk)))
   ga-sys '(tlbi ic dc at)
   ga-ld (gtab '((ldr (ld ldu4)) (ldrb (ldu1 ldu1)) (ldrh (ldu2 ldu2)) (ldrsb (ld1 ld1)) (ldrsh (ld2 ld2)) (ldrsw (ld4 ld4))))
   ga-st (gtab '((str (st st4)) (strb (st1 st1)) (strh (st2 st2))))
   ga-sh (gtab '((lsl shl) (lsr shr) (asr sar) (ror ror)))
   (ga-bcond s) (: t (show s) (? (#t > 2 && t 0 = 98 && t 1 = 46) (peep ga-cc (name (snip t 2 #t)) ()) ()))
   (ga-inplace op d s) (? (= d s) () [['mov d s]])       ; the IR's unary ops work in place
   (ga-ins m os)
    (: k #os
       (? (ghas? ga-nils m) [[(ga-nils m)]]
          (nom? (ga-bcond m)) [['br (ga-bcond m) (<>(os 0))]]
          (= m 'b) [['jmp (<>(os 0))]]
          (= m 'bl) [['call (<>(os 0))]]
          (= m 'br) [['jmpr (ga-r (os 0))]]
          (= m 'blr) [['callr (ga-r (os 0))]]
          (member? m '(dsb dmb)) [[m (<>(os 0))]]
          (= m 'mrs) [['mrs (ga-r (os 0)) (<>(os 1))]]
          (= m 'msr) ((os 1) @ ('imm n) [['msri (<>(os 0)) n]] [['msr (<>(os 0)) (ga-r (os 1))]])
          (member? m ga-sys) [[m (<>(os 0)) (? (k > 1) (ga-r (os 1)) 'zr)]]
          (ghas? ga-exc m) [[(ga-exc m) (? (k > 0) (<>(os 0)) 0)]]
          (= m 'svc) (: n (? (k > 0) (<>(os 0)) 0) (? (n = 0) '((sys)) [['svcn n]]))
          (= m 'mov)
           (: d (ga-r (os 0)) s (os 1)
              (s @ ('imm n) [['li d n]]
                   (? (= d 'sp || (= (ga-r s) 'sp)) [['lea d (ga-r s) 0]] [['mov d (ga-r s)]])))
          (= m 'movz) [['li (ga-r (os 0)) (<>(os 1))]]
          (ghas? ga-alu m)
           (? (k = 3) [[(ga-alu m) (ga-r (os 0)) (ga-r (os 1)) (ga-v (os 2))]] (scare 'gas-a64-operand os))
          (= m 'cmp) [['cmp (ga-r (os 0)) (ga-v (os 1))]]
          (= m 'tst) [['test (ga-r (os 0)) (ga-v (os 1))]]
          (= m 'neg) (: d (ga-r (os 0)) (ga-inplace 'neg d (ga-r (os 1)) + [['neg d]]))
          (= m 'mvn) (: d (ga-r (os 0)) (ga-inplace 'not d (ga-r (os 1)) + [['not d]]))
          (ghas? ga-sh m)
           (: d (ga-r (os 0)) s (ga-r (os 1)) c (os 2)
              (c @ ('imm n) (ga-inplace m d s + [[(ga-sh m) d n]])
                   (? (= d s) [[(name (show (ga-sh m) + "v")) d (ga-r c)]] (scare 'gas-a64-operand os))))
          (two? (peep ga-ld m ()))
           (: r (ga-rw (os 0)) ((os 1) @ ('mem b o) [[(ga-ld m (? (<>r = 8) 0 1)) <r b o]] (scare 'gas-a64-operand os)))
          (two? (peep ga-st m ()))
           (: r (ga-rw (os 0)) ((os 1) @ ('mem b o) [[(ga-st m (? (<>r = 8) 0 1)) b o <r]] (scare 'gas-a64-operand os)))
          (scare 'gas-a64-op m)))
   (ga-line toks)
    (: l (gline toks)
       (l @ ('label s) [['label s]]
            ('ins m os) (ga-ins m (map ga-opnd os))
            ()))

   ;; -- rv64: dst first, the ABI register names, off(base) memory, the csr pseudos. --
   (gr-reg s) (peep rv-names (name s) ())
   (gr-opnd toks)
    (toks @ (('sym s)) (: r (gr-reg s) (? (nom? r) ['reg r 8] ['sym (name s)]))
            (('ch 40) ('sym b) ('ch 41)) ['mem (gr-reg b) 0]
            (: (mem l acc)
                (? !(two? l) ['imm (gimm toks)]
                   (= <l '(ch 40))
                    (>l @ (('sym b) ('ch 41)) (: r (gr-reg b) (? (nom? r) ['mem r (? (two? acc) (gimm (rev acc)) 0)] (scare 'gas-rv64-operand toks)))
                          (scare 'gas-rv64-operand toks))
                   (mem >l (<l . acc)))
               (mem toks ())))
   (gr-r o) (o @ ('reg x _) x (scare 'gas-rv64-register o))
   (gr-v o) (o @ ('imm n) n ('reg x _) x (scare 'gas-rv64-operand o))
   gr-nils (gtab '((nop nop) (ret ret) (ecall sys) (ebreak trap) (wfi wfi) (sret sret) (mret mret) (fence fence) (fence.i fencei)))
   gr-alu (gtab '((add add) (addi add) (sub sub) (and and) (andi and) (or or) (ori or) (xor xor) (xori xor) (mul imul)))
   gr-sh (gtab '((slli shl) (srli shr) (srai sar) (sll shlv) (srl shrv) (sra sarv)))
   gr-ld (gtab '((ld ld) (lw ld4) (lwu ldu4) (lh ld2) (lhu ldu2) (lb ld1) (lbu ldu1)))
   gr-st (gtab '((sd st) (sw st4) (sh st2) (sb st1)))
   gr-bcc (gtab '((beq eq) (bne ne) (blt lt) (bge ge) (bltu below) (bgeu ae)))
   gr-bz (gtab '((beqz eq) (bnez ne) (bltz lt) (bgez ge)))
   gr-csr1 '(csrw csrs csrc csrwi csrsi csrci)
   gr-csr2 '(csrrw csrrs csrrc csrrwi csrrsi csrrci)
   (gr-ins m os)
    (: k #os
       (? (ghas? gr-nils m) [[(gr-nils m)]]
          (= m 'unimp) '((csrw cycle zr))
          (= m 'sfence.vma) [['sfence (? (k > 0) (gr-r (os 0)) 'zr) (? (k > 1) (gr-r (os 1)) 'zr)]]
          (= m 'li) [['li (gr-r (os 0)) (<>(os 1))]]
          (= m 'mv) [['mov (gr-r (os 0)) (gr-r (os 1))]]
          (= m 'j) [['jmp (<>(os 0))]]
          (= m 'jr) [['jmpr (gr-r (os 0))]]
          (= m 'jalr) [['callr (gr-r (os 0))]]
          (= m 'call) [['call (<>(os 0))]]
          (ghas? gr-bcc m) [['cmp (gr-r (os 0)) (gr-r (os 1))] ['br (gr-bcc m) (<>(os 2))]]
          (ghas? gr-bz m) [['cmp (gr-r (os 0)) 0] ['br (gr-bz m) (<>(os 1))]]
          (ghas? gr-alu m) [[(gr-alu m) (gr-r (os 0)) (gr-r (os 1)) (gr-v (os 2))]]
          (ghas? gr-sh m)
           (: d (gr-r (os 0)) s (gr-r (os 1))
              ((? (= d s) () [['mov d s]]) + [[(gr-sh m) d (gr-v (os 2))]]))
          (= m 'neg) (: d (gr-r (os 0)) s (gr-r (os 1)) ((? (= d s) () [['mov d s]]) + [['neg d]]))
          (= m 'not) (: d (gr-r (os 0)) s (gr-r (os 1)) ((? (= d s) () [['mov d s]]) + [['not d]]))
          (ghas? gr-ld m) ((os 1) @ ('mem b o) [[(gr-ld m) (gr-r (os 0)) b o]] (scare 'gas-rv64-operand os))
          (ghas? gr-st m) ((os 1) @ ('mem b o) [[(gr-st m) b o (gr-r (os 0))]] (scare 'gas-rv64-operand os))
          (= m 'csrr) [['csrr (gr-r (os 0)) (<>(os 1))]]
          (member? m gr-csr1) [[m (<>(os 0)) (gr-v (os 1))]]
          (member? m gr-csr2) [[m (gr-r (os 0)) (<>(os 1)) (gr-v (os 2))]]
          (scare 'gas-rv64-op m)))
   (gr-line toks)
    (: l (gline toks)
       (l @ ('label s) [['label s]]
            ('ins m os) (gr-ins m (map gr-opnd os))
            ()))

   ;; -- thumb: the same operand grammar as a64 over r0..r12, the small system handful. --
   (gt-reg s) (peep t32-names (name s) ())
   (gt-opnd toks)
    (toks @ (('ch 35) . rest) ['imm (gimm rest)]
            (('num _) . _) ['imm (gimm toks)]
            (('sym s)) (: r (gt-reg s) (? (nom? r) ['reg r 4] ['sym (name s)]))
            (('ch 91) ('sym b) ('ch 93)) ['mem (gt-reg b) 0]
            (('ch 91) . ('sym b) . ('ch 44) . rest)
             (: n #rest
                (? !((rest (n - 1)) = '(ch 93)) (scare 'gas-thumb-operand toks)
                   ['mem (gt-reg b) (<>(gt-opnd (rev >(rev rest))))]))
            (scare 'gas-thumb-operand toks))
   (gt-r o) (o @ ('reg x _) x (scare 'gas-thumb-register o))
   (gt-v o) (o @ ('imm n) n ('reg x _) x (scare 'gas-thumb-operand o))
   gt-nils (gtab '((nop nop) (wfi wfi) (isb isb)))
   gt-alu (gtab '((add add) (sub sub) (and and) (orr or) (eor xor) (mul imul)))
   (gt-ins m os)
    (: k #os
       (? (ghas? gt-nils m) [[(gt-nils m)]]
          (= m 'bkpt) (: n (? (k > 0) (<>(os 0)) 0) (? (n = 0) '((trap)) [['brk n]]))
          (= m 'svc) '((sys))
          (= m 'dsb) [['dsb (<>(os 0))]]
          (= m 'mrs) [['mrs (gt-r (os 0)) (<>(os 1))]]
          (= m 'b) [['jmp (<>(os 0))]]
          (= m 'bl) [['call (<>(os 0))]]
          (= m 'bx) (? (= (gt-r (os 0)) 'lr) '((ret)) [['jmpr (gt-r (os 0))]])
          (= m 'mov) ((os 1) @ ('imm n) [['li (gt-r (os 0)) n]] [['mov (gt-r (os 0)) (gt-r (os 1))]])
          (= m 'cmp) [['cmp (gt-r (os 0)) (gt-v (os 1))]]
          (ghas? gt-alu m)
           (? (k = 3) [[(gt-alu m) (gt-r (os 0)) (gt-r (os 1)) (gt-v (os 2))]]
              [[(gt-alu m) (gt-r (os 0)) (gt-r (os 0)) (gt-v (os 1))]])
          (= m 'ldr) ((os 1) @ ('mem b o) [['ld (gt-r (os 0)) b o]] (scare 'gas-thumb-operand os))
          (= m 'str) ((os 1) @ ('mem b o) [['st b o (gt-r (os 0))]] (scare 'gas-thumb-operand os))
          (scare 'gas-thumb-op m)))
   (gt-line toks)
    (: l (gline toks)
       (l @ ('label s) [['label s]]
            ('ins m os) (gt-ins m (map gt-opnd os))
            ()))

   ;; -- the front door: TEXT -> IR, by target. --
   (gas-text tgt src)
    (? (= tgt 'x64) (gx-text src)
       (: lc {}
          f (? (= tgt 'a64) ga-line (= tgt 'rv64) gr-line (gthumb? tgt) gt-line (scare 'gas-target tgt))
          (foldl (\ acc ln (acc + f (glocal (gtoks ln) lc))) () (glines src (= tgt 'rv64))))))
) ; module 'holo
