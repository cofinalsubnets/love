; gas -- the GNU-dialect front for inline asm: the text an `asm("..")` template carries once its
; operands are substituted, in the assembler syntax the target's own toolchain speaks (AT&T on
; x64, ARM on a64, riscv, thumb), lowered to the neutral IR src/core/holo/holo.l assembles. where
; text.l reads holo's own mnemonics over abstract registers, this reads what clang and gcc read,
; so one template serves every compiler. it encodes nothing itself: every line lands on a backend
; row, so the encodings stay where they are gated (test/holo/golden.l). (as.l is the other AT&T
; reader -- a physical encoder for a whole .s file; this one is the inline-asm dialect front.)
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
; a multi-instruction template separates on `\n` or `;`, as GNU does.

(module 'holo
(: ;; -- the lexer: one line -> tokens (sym "s") (num n) (pct "reg") (lref n dir) (ch c) (op "<<"). --
   (gws? c) (c = 32 || c = 9)
   (gdig? c) (48 <= c <= 57)
   (galpha? c) (97 <= c <= 122 || 65 <= c <= 90 || c = 95 || c = 46)
   (gidc? c) (galpha? c || gdig? c)
   (ghexd c) (? (gdig? c) (c - 48) (97 <= c <= 102) (c - 87) (65 <= c <= 70) (c - 55) -1)
   (ghex? c) (ghexd c >= 0)
   (gdecv s) (foldl (a \ i \ a * 10 + s i - 48) 0 ^#s)
   (ghexv s) (foldl (a \ i \ a * 16 + ghexd (s i)) 0 ^#s)
   (gtoks s) (: n #s
      (span i p) ((: (g j) (? (j < n && p (s j)) (g (j + 1)) j)) i)
      (go i acc)
       (? (i >= n) (rev acc)
          (: c (s i)
             (? (gws? c) (go (i + 1) acc)
                (c = 48 && i + 1 < n && (s (i + 1) = 120 || s (i + 1) = 88))
                 (: j (span (i + 2) ghex?) (go j (['num (ghexv (snip s (i + 2) j))] . acc)))
                (gdig? c)
                 (: j (span i gdig?) v (gdecv (snip s i j))
                    (? (j < n && (s j = 102 || s j = 98) && (j + 1 >= n || !(gidc? (s (j + 1)))))
                       (go (j + 1) (['lref v (s j)] . acc))
                       (go j (['num v] . acc))))
                (galpha? c) (: j (span i gidc?) (go j (['sym (snip s i j)] . acc)))
                (c = 37 && i + 1 < n && galpha? (s (i + 1)))
                 (: j (span (i + 1) gidc?) (go j (['pct (snip s (i + 1) j)] . acc)))
                ((c = 60 || c = 62) && i + 1 < n && s (i + 1) = c)
                 (go (i + 2) (['op (snip s i (i + 2))] . acc))
                (go (i + 1) (['ch c] . acc)))))
      (go 0 ()))

   ;; -- immediate expressions: C's operators over numbers, the way `$~(1 << 2)` and `#(3 << 20)`
   ;; are written. each level answers (value . rest) | 'bad. --
   (gbad? x) (= x 'bad)
   (gprim ts) (? !(two? ts) 'bad
       (: t <ts
          (t @ ('num v) (v . >ts)
               ('ch 40) (: r (gexpr >ts)
                           (? (gbad? r || !(two? >r) || !(= <>r '(ch 41))) 'bad (<r . >>r)))
               ('ch 126) (: r (gprim >ts) (? (gbad? r) 'bad ((<r ^ -1) . >r)))
               ('ch 45) (: r (gprim >ts) (? (gbad? r) 'bad ((0 - <r) . >r)))
               ('ch 43) (gprim >ts)
               'bad)))
   (gbinop t) (t @ ('ch 124) '(1 or) ('ch 94) '(2 xor) ('ch 38) '(3 and)
                   ('op "<<") '(4 shl) ('op ">>") '(4 shr)
                   ('ch 43) '(5 add) ('ch 45) '(5 sub)
                   ('ch 42) '(6 mul) ('ch 47) '(6 div) ('ch 37) '(6 mod) ())
   (gapply op a b) (op @ 'or (a | b) 'xor (a ^ b) 'and (a & b) 'shl (a << b) 'shr (a >> b)
                        'add (a + b) 'sub (a - b) 'mul (a * b) 'div (a // b) (a % b))
   (gclimb lhs ts minp)
    (? !(two? ts) (lhs . ts)
       (: b (gbinop <ts)
          (? (!(two? b) || <b < minp) (lhs . ts)
             (: r (gprim >ts)
                (? (gbad? r) 'bad
                   (: r2 (gclimb <r >r (<b + 1))
                      (? (gbad? r2) 'bad (gclimb (gapply <>b lhs <r2) >r2 minp))))))))
   (gexpr ts) (: r (gprim ts) (? (gbad? r) 'bad (gclimb <r >r 1)))
   (gimm ts) (: r (gexpr ts) (? (gbad? r || two? >r) (scare 'gas-immediate ts) <r))   ; the whole run, or nothing

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

   ;; -- x64, the AT&T dialect: src before dst, %reg, $imm, disp(%base), the size suffix. --
   ;; operands: (reg rN w) | (cr n) | (imm n) | (mem base disp) | (rip label) | (lab sym) | (ind o)
   (gx-reg s) (: e (peep x64-regs (name s) ())
                 (? (two? e) ['reg <e <>e]
                    (: c (gx-cr s) (? (two? c) c (= s "rip") '(rip) (scare 'gas-x64-register s)))))
   (gx-opnd toks)
    (toks @ (('ch 36) . rest) ['imm (gimm rest)]
            (('ch 42) . rest) ['ind (gx-opnd rest)]
            (('pct s)) (gx-reg s)
            (('sym s)) ['lab (name s)]
            (: (mem l acc)                                          ; disp then (base)
                (? !(two? l) (scare 'gas-x64-operand toks)
                   (= <l '(ch 40))
                    (: d (? (two? acc) (rev acc) '((num 0)))
                       (>l @ (('pct b) ('ch 41))
                              (? (= b "rip") (d @ (('sym s)) ['rip (name s)] (scare 'gas-x64-operand toks))
                                 (: r (gx-reg b) (r @ ('reg x _) ['mem x (gimm d)] (scare 'gas-x64-base b))))
                             (scare 'gas-x64-operand toks)))
                   (mem >l (<l . acc)))
               (mem toks ())))
   (gx-w o) (o @ ('reg _ w) w 0)
   (gx-width w os) (? (w > 0) w (: m (foldl (\ a o (? (gx-w o > a) (gx-w o) a)) 0 os) (? (m > 0) m 8)))
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
   gx-known '(mov lea add sub and or xor imul cmp test shl sal shr sar rol ror not neg inc dec push pop div ltr)
   gx-ext (gtab '((movzbl (1 zx1 ldu1)) (movzbq (1 zx1 ldu1)) (movzwl (2 zx2 ldu2)) (movzwq (2 zx2 ldu2))
                  (movsbl (1 sx1 ld1)) (movsbq (1 sx1 ld1)) (movswl (2 sx2 ld2)) (movswq (2 sx2 ld2))
                  (movslq (4 sx4 ld4))))
   (gx-sfx m) (: s (show m) n #s c (s (n - 1))
                 (? (n < 3) () (c @ 98 [(name (snip s 0 (n - 1))) 1] 119 [(name (snip s 0 (n - 1))) 2]
                                     108 [(name (snip s 0 (n - 1))) 4] 113 [(name (snip s 0 (n - 1))) 8] ())))
   (gx-ins m os)
    (: k #os
       (? (ghas? gx-nils m) [[(gx-nils m)]]
          (two? (peep gx-ext m ()))
           (: e (gx-ext m) s (os 0) d (os 1)
              (d @ ('reg x _) (s @ ('reg y _) [['mov x y] [(e 1) x]]
                                  ('mem b o) [[(e 2) x b o]]
                                  (scare 'gas-x64-operand s))
                 (scare 'gas-x64-operand d)))
          (ghas? gx-cc m) [['br (gx-cc m) (<>(os 0))]]
          (= m 'jmp) ((os 0) @ ('lab l) [['jmp l]] ('ind ('reg x _)) [['jmpr x]] (scare 'gas-x64-operand os))
          (= m 'call) ((os 0) @ ('lab l) [['call l]] ('ind ('reg x _)) [['callr x]] (scare 'gas-x64-operand os))
          (= m 'int) [['int (<>(os 0))]]
          (member? m gx-mem2) ((os 0) @ ('mem b o) [[m b o]] (scare 'gas-x64-operand os))
          (= m 'vmread) [['vmread (<>(os 1)) (<>(os 0))]]
          (= m 'vmwrite) [['vmwrite (<>(os 1)) (<>(os 0))]]
          (: sf (? (member? m gx-known) [m 0] (gx-sfx m))
             _ (? (two? sf && member? <sf gx-known) 0 (scare 'gas-x64-op m))
             m9 <sf
             w (gx-width <>sf os)
             (? (= m9 'mov)
                 (: s (os 0) d (os 1)
                    (? (= <d 'cr) [['stcr <>d <>s]]
                       (= <s 'cr) [['ldcr <>d <>s]]
                       (d @ ('reg x _)
                             (s @ ('imm v) [['li x (? (w = 4) (v & 4294967295) (w = 8) v (scare 'gas-x64-width w))]]
                                  ('reg y _) ([['mov x y]] + gx-zx x w)
                                  ('mem b o) [[(gx-lop w) x b o]]
                                  (scare 'gas-x64-operand s))
                          ('mem b o)
                             (s @ ('reg y _) [[(gx-sop w) b o y]]
                                  ('imm v) [[(gx-iop w) b o v]]
                                  (scare 'gas-x64-operand s))
                          (scare 'gas-x64-operand d))))
                (= m9 'lea) ((os 0) @ ('rip l) [['la (<>(os 1)) l]]
                                     ('mem b o) [['lea (<>(os 1)) b o]]
                                     (scare 'gas-x64-operand os))
                (member? m9 gx-alu)
                 (? (k = 3) [['imul (<>(os 2)) (<>(os 1)) (<>(os 0))]]
                    (: s (os 0) d (os 1)
                       (? (!(= <d 'reg) || !(member? <s '(reg imm))) (scare 'gas-x64-operand os)
                          ([[m9 <>d <>d <>s]] + (? ((m9 = 'xor) && (<>s = <>d)) () (gx-zx <>d w))))))
                (= m9 'cmp) [['cmp (<>(os 1)) (<>(os 0))]]
                (= m9 'test) [['test (<>(os 1)) (<>(os 0))]]
                (member? m9 '(shl sal shr sar rol ror))
                 (: op (? (= m9 'sal) 'shl m9)
                    d (os (k - 1))
                    (? (k = 1) [[op <>d 1]]
                       ((os 0) @ ('imm n) [[op <>d n]]
                                ('reg r1 1) [[(name (show op + "v")) <>d 'r1]]
                                (scare 'gas-x64-operand os))))
                (member? m9 '(not neg inc dec push pop)) [[m9 (<>(os 0))]]
                (= m9 'div) [[(? (w = 4) 'divl 'divq) (<>(os 0))]]
                (= m9 'ltr) [['ltr (<>(os 0))]]
                (scare 'gas-x64-op m)))))
   (gx-line toks)
    (: l (gline toks)
       (l @ ('label s) [['label s]]
            ('ins m os) (gx-ins m (map gx-opnd os))
            ()))

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
    (: lc {}
       hash? (member? tgt '(x64 rv64))
       f (? (= tgt 'x64) gx-line (= tgt 'a64) ga-line (= tgt 'rv64) gr-line (gthumb? tgt) gt-line
            (scare 'gas-target tgt))
       (foldl (\ acc ln (acc + f (glocal (gtoks ln) lc))) () (glines src hash?))))
) ; module 'holo
