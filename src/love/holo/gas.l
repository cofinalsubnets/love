; gas -- the GNU-dialect front for inline asm: the text an `asm("..")` template carries once its
; operands are substituted, in the assembler syntax the target's own toolchain speaks (AT&T on
; x64, ARM on a64, riscv, thumb), lowered to the neutral IR src/love/holo/holo.l assembles. where
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
; forms and indexed memory refuse. a64 lays its own word where the IR's would not be gas's: W ops,
; written-back and indexed addresses, an X op the IR spells longer. a line that fits nothing
; scares, so a typo never drops out.
; a multi-instruction template separates on `\n` or `;`, as GNU does. the x64 text is read by
; src/love/holo/dialect.l's att-read -- the same parsed instruction as.l encodes and the Intel
; dialect shows -- and only lowered here; the other dialects still parse their own lines.

(module 'holo
(: ;; the lexer (gtoks) and the immediate expressions (gimm) sit in src/love/holo/dialect.l,
   ;; shared with the x86 lens; the lines and local labels below are GNU's, for every dialect

   ;; -- lines. a template separates on newline or `;`; `//` comments everywhere, `#` where it is
   ;; not the immediate marker. GNU's numeric local labels resolve here, before any dialect looks:
   ;; the k-th `N:` becomes the symbol lN.k, `Nf` the next one, `Nb` the last one. --
   (gcut s c) (: i ((: (g j) (? (j >= #s) -1 (s j = c) j (g (j + 1)))) 0) (i < 0 ? s (snip s 0 i)))
   (gcut2 s c) (: n #s
      i ((: (g j) (? (j + 1 >= n) -1 (s j = c && s (j + 1) = c) j (g (j + 1)))) 0)
      (i < 0 ? s (snip s 0 i)))
   (gsplit s c) (#s @ n
                   ((: (g i st acc) (? (i >= n) (rev (snip s st n . acc))
                                       (s i = c) (g (i + 1) (i + 1) (snip s st i . acc))
                                       (g (i + 1) st acc))) 0 0 ()))
   (glines src hash?) (foldr (\ ln acc (gsplit ln 59 + acc)) ()
                             (map (ln \ (gcut2 ln 47 @ a (hash? ? (gcut a 35) a))) (gsplit src 10)))
   (glabel n k) (name ("l" + show n + "." + show k))
   (glocal toks lc)                                 ; (lref n d) -> (sym), the count tablet updated by defs
    (toks @ (('num n) ('ch 58)) (1 + peep lc n 0 @ k (pin lc n k, [['sym (show (glabel n k))] '(ch 58)]))
          (map (t \ (t @ ('lref n d) ['sym (show (glabel n (d = 102 ? (1 + peep lc n 0) (peep lc n 0))))] t)) toks))
   ;; the operand runs: top-level commas split, parens and brackets nest
   (gops toks) (: (go l d cur acc)
                   (atom? l ? (rev (two? cur ? (rev cur . acc) acc))
                      (<l @ t
                         (? (t = '(ch 40) || t = '(ch 91)) (go >l (d + 1) (t . cur) acc)
                            (t = '(ch 41) || t = '(ch 93)) (go >l (d - 1) (t . cur) acc)
                            (t = '(ch 44) && d = 0) (go >l d () (rev cur . acc))
                            (go >l d (t . cur) acc))))
                  (go toks 0 () ()))
   ;; a line is a label (`name:`) or a mnemonic and its operand runs
   (gline toks) (atom? toks ? ()
                   (toks @ (('sym s) ('ch 58)) ['label (name s)]
                           (('sym s) . rest) ['ins (name s) (gops rest)]
                           (scare 'gas-line toks)))

   ;; -- the register files, dialect name -> neutral (and back). --
   (gtab rows) (tablet 0 @ t (foldl (\ _ p (pin t <p <>p)) 0 rows, t))
   (ghas? t k) (nom? (peep t k ()))                ; a symbol-valued row is there
   gx-rows '((r0 "rax" "eax" "ax" "al") (r1 "rcx" "ecx" "cx" "cl") (r2 "rdx" "edx" "dx" "dl")
              (r3 "rbx" "ebx" "bx" "bl") (sp "rsp" "esp" "sp" "spl") (r4 "rbp" "ebp" "bp" "bpl")
              (r5 "rsi" "esi" "si" "sil") (r6 "rdi" "edi" "di" "dil")
              (r7 "r8" "r8d" "r8w" "r8b") (r8 "r9" "r9d" "r9w" "r9b") (r9 "r10" "r10d" "r10w" "r10b")
              (r10 "r11" "r11d" "r11w" "r11b") (r11 "r12" "r12d" "r12w" "r12b")
              (r12 "r13" "r13d" "r13w" "r13b") (r13 "r14" "r14d" "r14w" "r14b") (r14 "r15" "r15d" "r15w" "r15b"))
   gx-regs (: t {}                           ; name -> (rN w)
                (foldl (\ _ row (<row @ r
                                   (pin t (name (row 1)) [r 8], pin t (name (row 2)) [r 4],
                                    pin t (name (row 3)) [r 2], pin t (name (row 4)) [r 1], 0)))
                       0 gx-rows,
                 t))
   gx-names (gtab (map (row \ [<row >row]) gx-rows))   ; rN -> (q l w b)
   (gx-cr s) (#s = 3 && s 0 = 99 && s 1 = 114 && digit? (s 2) ? ['cr (s 2 - 48)] ())
   a64-names (tablet 0 @ t
                (foldl (\ _ i (pin t (name ("x" + show i)) (name ("r" + show i)))) 0 ^29,
                 foldl (\ _ p (pin t <p <>p)) 0 '((x29 fp) (x30 lr) (sp sp) (xzr zr)),
                 t))
   rv-names (gtab '((zero zr) (x0 zr) (ra lr) (sp sp) (s0 fp) (fp fp) (s1 r15)
                    (a0 r0) (a1 r1) (a2 r2) (a3 r3) (a4 r4) (a5 r5) (a6 r6) (a7 r7)
                    (t0 r8) (t1 r9) (t2 r10) (t3 r11) (t4 r12) (s2 r13) (s3 r14)
                    (s4 r19) (s5 r20) (s6 r21) (s7 r22) (s8 r23) (s9 r24) (s10 r25) (s11 r26)))
   rv-back (gtab '((zr zero) (lr ra) (sp sp) (fp s0) (r15 s1)
                   (r0 a0) (r1 a1) (r2 a2) (r3 a3) (r4 a4) (r5 a5) (r6 a6) (r7 a7)
                   (r8 t0) (r9 t1) (r10 t2) (r11 t3) (r12 t4) (r13 s2) (r14 s3)
                   (r19 s4) (r20 s5) (r21 s6) (r22 s7) (r23 s8) (r24 s9) (r25 s10) (r26 s11)))
   t32-names (tablet 0 @ t
                (foldl (\ _ i (pin t (name ("r" + show i)) (name ("r" + show i)))) 0 ^13,
                 pin t 'sp 'sp, pin t 'lr 'lr,
                 t))
   (gthumb? tgt) (elem tgt '(thumb2 thumb2sp thumb1))

   ;; the dialect's spelling of the neutral file, for operand substitution. `mod` is GNU's
   ;; modifier letter (x64 b/w/k/q, a64 w/x) or 0.
   (gas-reg tgt r w mod)
    (? (tgt = 'x64)
        (: ns (peep gx-names r ())
           w9 (mod @ 98 1 119 2 107 4 113 8 w)
           (atom? ns ? (scare 'gas-reg r)
              ("%" + ns (w9 @ 1 3 2 2 4 1 0))))
       (tgt = 'a64)
        (: k (r @ 'sp "sp" 'fp "29" 'lr "30" (snip (show r) 1 #(show r)))
           w9 (mod @ 119 4 120 8 w)
           (r = 'sp ? "sp" ((w9 <= 4 ? "w" "x") + k)))
       (tgt = 'rv64) (peep rv-back r () @ s (!s ? (scare 'gas-reg r) (show s)))
       (show r))
   (gas-imm tgt n mod) (: t (charm? n ? (show n) n)             ; n a number, or a "sym+k" text
                          (? (elem mod '(99 97 80)) t (tgt = 'x64) ("$" + t) (gthumb? tgt) ("#" + t) t))
   (gas-mem tgt r) (? (tgt = 'x64) ("(" + gas-reg tgt r 8 0 + ")")
                      (tgt = 'rv64) ("0(" + gas-reg tgt r 8 0 + ")")
                      ("[" + gas-reg tgt r 8 0 + "]"))
   (gas-regname tgt s)                              ; gas's own `%rdx` names the register too (the kernel's __get_user)
    (name (s @ ("%" + r) r s) @ k
       (? (tgt = 'x64) (peep gx-regs k () @ e (two? e ? <e))
          (tgt = 'a64) (peep a64-names k ())
          (tgt = 'rv64) (peep rv-names k ())
          (peep t32-names k ())))

   ;; -- x64: the AT&T text is read by src/love/holo/dialect.l (att-read) into the parsed
   ;;    instruction -- (op mn w ops), destination first, physical registers -- and lowered here.
   ;;    GNU's numeric local labels resolve over the read items first, the k-th `N:` becoming
   ;;    lN.k, `Nf` the next one, `Nb` the last one. --
   gx-neutral '(r0 r1 r2 r3 sp r4 r5 r6 r7 r8 r9 r10 r11 r12 r13 r14)    ; the neutral file, by encoding
   (gx-r o) (<o = 'rg && <>o < 16 ? (gx-neutral <>o) (scare 'gas-x64-register o))
   (gx-rv o) (<o = 'im ? <>o (gx-r o))                            ; a register or an immediate
   (gx-imm o) (<o = 'im ? <>o (scare 'gas-x64-operand o))
   (gx-mem o) (<o = 'mem && o 1 >= 0 && o 2 < 0 ? [(gx-neutral (o 1)) (o 4)]    ; -> (base disp)
                 (scare 'gas-x64-operand o))
   (gx-zx d w) (? (w = 4) [['zx4 d]] (w = 8) () (scare 'gas-x64-width w))
   (gx-lop w) (w @ 8 'ld 4 'ldu4 2 'ldu2 'ldu1)
   (gx-sop w) (w @ 8 'st 4 'st4 2 'st2 'st1)
   (gx-iop w) (w @ 8 'si 4 'si4 2 'si2 'si1)
   gx-nils (gtab '((cli cli) (sti sti) (hlt hlt) (ud2 ud2) (iretq iretq) (swapgs swapgs)
                   (pushf pushf) (pushfq pushf) (popf popf) (popfq popf) (lock lock) (rep rep) (repne repne)
                   (rdmsr rdmsr) (wrmsr wrmsr) (cpuid cpuid) (rdtsc rdtsc)
                   (vmrun vmrun) (vmload vmload) (vmsave vmsave) (stgi stgi) (clgi clgi)
                   (vmlaunch vmlaunch) (vmxoff vmxoff) (cld cld)
                   (inb inb) (inw inw) (inl inl) (outb outb) (outw outw) (outl outl)
                   (nop nop) (ret ret) (syscall sys) (int3 trap)
                   (pause pause) (mfence mfence) (lfence lfence) (sfence sfencex)
                   (stc stc) (clc clc) (cmc cmc) (stac stac) (clac clac) (rdpkru rdpkru) (wrpkru wrpkru) (xgetbv xgetbv) (xsetbv xsetbv) (wbinvd wbinvd) (invd invd) (monitor monitor) (mwait mwait) (rdpmc rdpmc)
                   (fninit fninit) (fnclex fnclex) (fwait fwait) (wait fwait) (emms emms)))   ; sfencex: rv64's sfence is sfence.vma
   ;; the string ops by Intel's names -> (stem width); the port pair has no q
   gx-str (gtab (catmap (s \ (map (p \ [(name (show s + <p)) [s <>p]])
                                  ((elem s '(ins outs)) ? '(("b" 1) ("w" 2) ("d" 4))
                                     '(("b" 1) ("w" 2) ("d" 4) ("q" 8)))))
                  '(movs cmps stos lods scas ins outs)))
   ;; the fpu's state over memory -> (opcode digit width); the whole-state saves take a q or 64
   ;; for REX.W, the 64-bit pointer layout
   gx-mdig (gtab '((fnsave ((221) 6 4)) (frstor ((221) 4 4)) (fldcw ((217) 5 4)) (fnstcw ((217) 7 4))
                   (fnstsw ((221) 7 4)) (fildl ((219) 0 4)) (filds ((223) 0 4)) (fildll ((223) 5 4))
                   (fildq ((223) 5 4)) (ldmxcsr ((15 174) 2 4)) (stmxcsr ((15 174) 3 4))
                   (clflush ((15 174) 7 4)) (clflushopt ((15 174) 7 2)) (clwb ((15 174) 6 2))   ; w 2: the 66 they take
                   (verr ((15 0) 4 4)) (verw ((15 0) 5 4)) (sldt ((15 0) 0 4)) (str ((15 0) 1 4))
                   (lldt ((15 0) 2 4)) (push ((255) 6 4)) (pop ((143) 0 4))))
   ;; ..and over a register -> (prefix opcode digit width), width 0 the register's own
   gx-rdig (gtab '((sldt (() (15 0) 0 0)) (str (() (15 0) 1 0)) (lldt (() (15 0) 2 4))
                   (verr (() (15 0) 4 4)) (verw (() (15 0) 5 4))
                   (rdfsbase ((243) (15 174) 0 0)) (rdgsbase ((243) (15 174) 1 0))
                   (wrfsbase ((243) (15 174) 2 0)) (wrgsbase ((243) (15 174) 3 0))))
   _ (each '((fxsave (15 174) 0) (fxrstor (15 174) 1) (xsave (15 174) 4) (xrstor (15 174) 5)
             (xsaveopt (15 174) 6) (xsavec (15 199) 4) (xsaves (15 199) 5) (xrstors (15 199) 3))
        (r \ (: t (show <r) e (w \ [<>r <>>r w])
                (pin gx-mdig <r (e 4), pin gx-mdig (name (t + "q")) (e 8), pin gx-mdig (name (t + "64")) (e 8)))))
   gx-alu '(add sub and or xor imul)
   gx-cc (gtab '((je eq) (jz eq) (jne ne) (jnz ne) (jl lt) (jle le) (jg gt) (jge ge)
                 (jb below) (jc below) (jnae below) (ja above) (jnbe above)
                 (jae ae) (jnb ae) (jnc ae) (jbe be) (jna be) (js s) (jns ns) (jo vs) (jno vc)))
   ;; set<cc> -> its condition, the jump's suffix read off the table above
   (gx-setcc m) (show m @ t (t @ ("set" + (c && 0 < #c)) (gx-cc (name ("j" + c))) ()))
   gx-mem2 '(vmxon vmclear vmptrld sgdt sidt lgdt lidt invlpg)
   gx-rmw '(xadd cmpxchg xchg add or and sub xor cmp test inc dec not neg bt bts btr btc adc sbb)
   ; a memory operand -> (base off): a register base, or 'rip and (sym k) for `sym+k(%rip)` and
   ; the absolute `sym+k`, the same address wherever the image sits
   (gx-mref o) (<o @ 'mem (gx-mem o)
                    'rip ['rip [<>o <>>o]]
                    'lbl (xa-symoff (show <>o) @ so ['rip [<so >so]])
                    (scare 'gas-x64-operand o))
   gx-ext (gtab '((movzb (zx1 ldu1)) (movzw (zx2 ldu2)) (movsb (sx1 ld1)) (movsw (sx2 ld2)) (movsl (sx4 ld4))))
   ; a %gs:/%fs: operand: the override byte before the one form that reaches memory. an absolute
   ; address (percpu's `%gs:sym`, `%gs:40`) loads through its destination: the address, then the word
   (gx-seg m w0 ops)
    (: i ((: (g j) (? (j >= #ops) -1 (<(ops j) = 'seg) j (g (j + 1)))) 0)
       sg <>(ops i) o <>>(ops i) w (w0 > 0 ? w0 8)
       ab (? (<o = 'lbl) <>o (<o = 'mem && o 1 < 0 && o 2 < 0) (o 4) ())
       (? (<o = 'mem && o 1 >= 0)
           (: fs (gx-ins m w0 (map (x \ (<x = 'seg ? <>>x x)) ops))
              (#fs = 1 ? [['seg sg] <fs] (scare 'gas-x64-seg ops)))
          (m = 'mov && i = 1 && <(ops 0) = 'rg && (nom? ab || charm? ab))
           (gx-r (ops 0) @ x
              [(nom? ab ? ['lia x ab] ['li x ab]) ['seg sg] [(gx-lop w) x x 0]])
          (scare 'gas-x64-seg ops)))
   (gx-ins m w0 ops)
    (: k #ops w (w0 > 0 ? w0 8)
       d (k > 0 ? (ops 0) ()) s (k > 1 ? (ops 1) ())
       (? (ghas? gx-nils m) [[(gx-nils m)]]
          (k = 0 && two? (peep gx-str m ())) (gx-str m @ e [['str <e <>e]])
          (k = 0 && elem m '(cs ds es ss)) [['seg m]]                   ; a null override, the padding alternatives lay
          (k = 1 && elem <d '(mem rip lbl) && two? (peep gx-mdig m ()))
           (: e (gx-mdig m) bm (gx-mref d) [['mdig <e <>e <>>e <bm <>bm]])
          (k = 1 && <d = 'rg && two? (peep gx-rdig m ()))
           (gx-rdig m @ e [['rdig (e 0) (e 1) (e 2) (e 3 = 0 ? (d 2) (e 3)) (gx-r d)]])
          (m = 'invpcid) (gx-mref s @ bm [['invpcid (gx-r d) <bm <>bm]])   ; the type register, the descriptor
          (m = 'movnti) (gx-mref d @ bm [['movntim (w0 > 0 ? w0 (s 2)) <bm <>bm (gx-r s)]])
          (two? (peep gx-ext m ()))
           (: e (gx-ext m) x (gx-r d)
              (? (<s = 'rg) [['mov x (gx-r s)] [<e x]]
                 (<s = 'mem) (gx-mem s @ bm [[<>e x <bm <>bm]])
                 (scare 'gas-x64-operand s)))
          (ghas? gx-cc m) [['br (gx-cc m) <>d]]
          (k = 1 && nom? (gx-setcc m)) [['set1 (gx-setcc m) (gx-r d)]]
          ; an indirect branch through a register, or through memory (FF /4, FF /2)
          (elem m '(jmp call))
           (? (<d = 'lbl) [[m <>d]]
              (<d = 'ind && <(<>d) = 'rg) [[(m = 'jmp ? 'jmpr 'callr) (gx-r <>d)]]
              (<d = 'ind) (gx-mref <>d @ bm [['mdig [255] (m = 'jmp ? 4 2) 4 <bm <>bm]])
              (scare 'gas-x64-operand ops))
          (m = 'int) [['int (gx-imm d)]]
          (elem m gx-mem2) (gx-mem d @ bm [[m <bm <>bm]])
          ; a read-modify-write on memory: atomics and counters. no suffix takes the register's width
          ((<d = 'mem || (elem <d '(lbl rip) && nom? <>d)) && elem m gx-rmw)
           (: bm (gx-mref d) wm (w0 > 0 ? w0 (<s = 'rg) (s 2) 8)
              (? (elem m '(xadd cmpxchg xchg)) (<s = 'rg ? [[(name (show m + "m")) wm <bm <>bm (gx-r s)]] (scare 'gas-x64-operand ops))
                 (elem m '(inc dec not neg)) [['unm m wm <bm <>bm]]
                 (elem m '(bt bts btr btc)) [['btm m wm <bm <>bm (gx-rv s)]]
                 (m = 'test) [['testm wm <bm <>bm (gx-rv s)]]
                 [['alum m wm <bm <>bm (gx-rv s)]]))
          (m = 'xchg && <s = 'mem && <d = 'rg) (gx-ins m w0 [s d])
          ; the bit scans and counts, at the suffix's width or the destination's
          (elem m '(bsr bsf tzcnt lzcnt popcnt))
           (<d = 'rg && <s = 'rg ? [['bscan m (w0 > 0 ? w0 (d 2)) (gx-r d) (gx-r s)]]
              (scare 'gas-x64-operand ops))
          (m = 'vmread) [['vmread (gx-r d) (gx-r s)]]
          (m = 'vmwrite) [['vmwrite (gx-r d) (gx-r s)]]
          (m = 'mov)
           (? (<d = 'cr) [['stcr <>d (gx-r s)]]
              (<s = 'cr) [['ldcr (gx-r d) <>s]]
              (<d = 'dr) [['stdr <>d (gx-r s)]]
              (<s = 'dr) [['lddr (gx-r d) <>s]]
              ; a segment register: 8C reads it into a register or memory, 8E writes it
              (<s = 'sr) (? (<d = 'rg) [['ldseg (gx-r d) <>s]]
                            (<d = 'mem) (gx-mem d @ bm [['segst <>s <bm <>bm]])
                            (scare 'gas-x64-operand d))
              (<d = 'sr) (? (<s = 'rg) [['stseg <>d (gx-r s)]]
                            (<s = 'mem) (gx-mem s @ bm [['segld <>d <bm <>bm]])
                            (scare 'gas-x64-operand s))
              (<d = 'rg)
               (gx-r d @ x
                  (? (<s = 'im) [['li x (? (w = 4) (<>s & 4294967295) (w = 8) <>s (scare 'gas-x64-width w))]]
                     (<s = 'rg) ([['mov x (gx-r s)]] + gx-zx x w)
                     (<s = 'mem) (gx-mem s @ bm [[(gx-lop w) x <bm <>bm]])
                     (scare 'gas-x64-operand s)))
              (<d = 'mem)
               (gx-mem d @ bm
                  (? (<s = 'rg) [[(gx-sop w) <bm <>bm (gx-r s)]]
                     (<s = 'im) [[(gx-iop w) <bm <>bm <>s]]
                     (scare 'gas-x64-operand s)))
              (scare 'gas-x64-operand d))
          (m = 'lea)
           (? ; no symbol: the address past this lea (the kernel's _THIS_IP_) -- its own bytes,
              ; REX.W 8D, modrm rm=101 over the displacement; nothing for a fix to name
              (<s = 'rip && !(nom? <>s) && <d = 'rg)
               (<>d @ n [['raw ([(72 | (n >= 8 ? 4 0)) 141 ((n & 7) << 3 | 5)] + gf-le <>>s 4)]])
              (<s = 'rip && <>>s = 0) [['la (gx-r d) <>s]]
              (<s = 'rip && nom? <>s) [['la (gx-r d) <>s] ['lea (gx-r d) (gx-r d) <>>s]]   ; sym+k: lea keeps the flags too
              (<s = 'mem) (gx-mem s @ bm [['lea (gx-r d) <bm <>bm]])
              (scare 'gas-x64-operand ops))
          ; add and subtract with the carry, a register at the far end: the kernel's
          ; array_index_mask_nospec (`cmp; sbb %0,%0`, the borrow spread to a mask)
          (elem m '(adc sbb))
           (<d = 'rg ? [['carry m (w0 > 0 ? w0 (d 2)) (gx-r d) (gx-rv s)]] (scare 'gas-x64-operand ops))
          (elem m gx-alu)
           (k = 3 ? [['imul (gx-r d) (gx-r s) (gx-imm (ops 2))]]
              (: x (gx-r d) v (gx-rv s)
                 ([[m x x v]] + (m = 'xor && v = x ? () (gx-zx x w)))))
          (m = 'cmp) [['cmp (gx-r d) (gx-rv s)]]
          (m = 'test) [['test (gx-r d) (gx-rv s)]]
          (elem m '(shl sal shr sar rol ror))
           (: op (m = 'sal ? 'shl m) x (gx-r d)
              (? (k = 1) [[op x 1]]
                 (<s = 'im) [[op x <>s]]
                 (<s = 'rg && <>s = 1 && <>>s = 1) [[(name (show op + "v")) x 'r1]]
                 (scare 'gas-x64-operand ops)))
          ; push takes an immediate, or a symbol's address as a sign-extended dword (gas's `pushq $1f`)
          (m = 'push) (? (<d = 'im) [['push <>d]] (<d = 'ims) [['pushl <>d]] [['push (gx-r d)]])
          (elem m '(not neg inc dec pop)) [[m (gx-r d)]]
          (m = 'div) [[(w = 4 ? 'divl 'divq) (gx-r d)]]
          (m = 'ltr) [['ltr (gx-r d)]]
          (scare 'gas-x64-op m)))
   (gx-locals items)
    (: lc {}
       (lref s) (: t (show s) n #t c (t (n - 1))                  ; "1f" / "1b" -> (n . dir), else ()
                   (n > 1 && (c = 102 || c = 98) && xa-allof? (snip t 0 (n - 1)) digit? 0 ?
                      ((xa-num (snip t 0 (n - 1))) . c) ()))
       (ref s) (lref s @ r (!(two? r) ? s (glabel <r (>r = 102 ? (1 + peep lc <r 0) (peep lc <r 0)))))
       (fix o) (<o @ 'lbl ['lbl (ref <>o)] 'rip ['rip (ref <>o) <>>o] 'ims ['ims (ref <>o)] o)
       (rev (foldl (\ acc it
                      ((<it @ 'label (show <>it @ t
                                        (xa-allof? t digit? 0 ?
                                           (: n (xa-num t) k (1 + peep lc n 0) (pin lc n k, ['label (glabel n k)]))
                                           it))
                            'op ['op (it 1) (it 2) (map fix (it 3))]
                            it) . acc))
                   () items)))
   (gx-item it) (<it @ 'label [['label <>it]]
                      'op (any (o \ two? o && <o = 'seg) (it 3) ? (gx-seg (it 1) (it 2) (it 3))
                             (gx-ins (it 1) (it 2) (it 3)))
                      (scare 'gas-x64-line it))                    ; a directive has no place in a template
   (gx-text src) (catmap gx-item (gx-locals (att-read src)))
   ;; ..and a file-scope run (an assembly source's): encoded exactly by as.l -- the width it says,
   ;; any addressing, the flags a 32-bit op sets -- and lowered as a template only where as.l
   ;; has no row (the system lane)
   (gx-exact src)
    ; both refusing, as.l's word stands: it names the instruction, the template lane an operand
    (catmap (it \ (<it = 'op ? (trap (i \ [['raw (as-instr i)]]) it (\ a b (trap gx-item it (\ _ _ (scare a b)))))
                     (gx-item it)))
            (gx-locals (att-read src)))

   ;; -- a64, the ARM dialect: dst first, xN/wN/sp/xzr, #imm, [base, #off], b.cond. --
   ;; operands: (reg rN w) | (imm n) | (mem base off) | (memw base off), pre-indexed |
   ;; (memx base idx option shift) | (sym s) -- a sysreg, an option, a label. what the IR's
   ;; 64-bit rows cannot say -- a W-register op, a written-back or indexed address, `ret xN`, an
   ;; X op they would spell in two words -- lands as gas's own word; an unread operand scares.
   (ga-reg s) (name s @ k
                 (? (nom? (peep a64-names k ())) ['reg (a64-names k) 8]
                    (k = 'wzr) ['reg 'zr 4]
                    (#s > 1 && s 0 = 119 && digit? (s 1)) ['reg (peep a64-names (name ("x" + snip s 1 #s)) ()) 4]
                    ()))
   ga-exts {'uxtw 2 'lsl 3 'sxtw 6 'sxtx 7}
   (ga-index b ps toks)                             ; [b, rM{, lsl|uxtw|sxtw|sxtx {#s}}]
    (: i (<ps @ (('sym m)) (ga-reg m) ())
       ex (two? >ps ? <>ps ())
       o (ex @ (('sym e) . _) (peep ga-exts (name e) ()) (atom? ex ? 3 ()))
       s (ex @ (('sym _) . ('ch 35) . v) (gimm v) -1)
       (#ps > 2 || !(charm? o) || <>>i != (o & 1 ? 8 4) ? (scare 'gas-a64-operand toks)
          ['memx b <>i o s]))
   (ga-opnd toks)
    (toks @ (('ch 35) . rest) ['imm (gimm rest)]
            (('num _) . _) ['imm (gimm toks)]
            (('ch 40) . _) ['imm (gimm toks)]
            (('ch 45) . _) ['imm (gimm toks)]
            (('sym s)) (ga-reg s @ r (two? r || nom? r ? r ['sym (name s)]))
            (('ch 91) ('sym b) ('ch 93)) ['mem (<>(ga-reg b)) 0]
            (('ch 91) . ('sym b) . ('ch 44) . rest)
             (: wb (two? rest && <(rev rest) = '(ch 33))            ; `]!`, pre-indexed
                body (wb ? (rev >(rev rest)) rest)
                r (ga-reg b) n #body
                (atom? r || n < 2 || !(body (n - 1) = '(ch 93)) ? (scare 'gas-a64-operand toks)
                   (gops (rev >(rev body)) @ ps
                      (? (ps @ ((('sym s)) . _) (two? (ga-reg s)) 0)
                          (wb ? (scare 'gas-a64-operand toks) (ga-index <>r ps toks))
                         (#ps > 1) (scare 'gas-a64-operand toks)
                         [(wb ? 'memw 'mem) <>r (<>(ga-opnd <ps))]))))
            (scare 'gas-a64-operand toks))
   (ga-r o) (o @ ('reg x _) x (scare 'gas-a64-register o))
   (ga-rw o) (o @ ('reg x w) [x w] (scare 'gas-a64-register o))
   (ga-v o) (o @ ('imm n) n ('reg x _) x (scare 'gas-a64-operand o))   ; a register or an immediate
   (ga-hw r) (r @ 'sp 31 'zr 31 'fp 29 'lr 30 (xa-num (snip (show r) 1 #(show r))))
   (ga-raw w) [['raw (le32 w)]]
   ;; 4 when an op's registers are all W, 8 when all X; a mix is no instruction
   (ga-wide os) (: ws (filter (w \ w > 0) (map (o \ o @ ('reg _ w) w 0) os))
                   (? (all (w \ w = 4) ws) (two? ws ? 4 8) (all (w \ w = 8) ws) 8 (scare 'gas-a64-width os)))
   ga-cc (gtab '((eq eq) (ne ne) (cs ae) (hs ae) (cc below) (lo below) (mi s) (pl ns)
                 (vs vs) (vc vc) (hi above) (ls be) (ge ge) (lt lt) (gt gt) (le le)))
   ga-nils (gtab '((nop nop) (wfi wfi) (wfe wfe) (isb isb) (eret eret) (ret ret)))
   ga-alu (gtab '((add add) (sub sub) (and and) (orr or) (eor xor) (mul imul) (adds adds) (subs subs)))
   ga-exc (gtab '((brk brk) (hvc hvc) (smc smc) (udf udf) (hlt dbrk)))
   ga-sys '(tlbi ic dc at)
   ga-ld (gtab '((ldr (ld ldu4)) (ldrb (ldu1 ldu1)) (ldrh (ldu2 ldu2)) (ldrsb (ld1 ld1)) (ldrsh (ld2 ld2)) (ldrsw (ld4 ld4))))
   ga-st (gtab '((str (st st4)) (strb (st1 st1)) (strh (st2 st2))))
   ga-sh (gtab '((lsl shl) (lsr shr) (asr sar) (ror ror)))
   ga-arity {'mov 2 'movz 2 'cmp 2 'tst 2 'neg 2 'mvn 2 'mrs 2 'msr 2
             'b 1 'bl 1 'br 1 'blr 1 'dsb 1 'dmb 1}
   ;; the W forms' words: register form, then immediate (add/sub imm12, the logicals a bitmask)
   ga-walu {'add [0x0B000000 0x11000000] 'sub [0x4B000000 0x51000000]
            'adds [0x2B000000 0x31000000] 'subs [0x6B000000 0x71000000]
            'and [0x0A000000 0x12000000] 'orr [0x2A000000 0x32000000]
            'eor [0x4A000000 0x52000000] 'ands [0x6A000000 0x72000000]}
   ga-flip {'add 'sub 'sub 'add 'adds 'subs 'subs 'adds}
   ;; a logical immediate at width z -> N:immr:imms at [22:10]: a rotated run of ones in a
   ;; 2..z-bit element repeated across the register; () when it is none
   (ga-bm v z)
    (: u (u64 v % (1 << z))
       e ((: (el e) (: h (e // 2) m ((1 << h) - 1) (h >= 2 && u & m = (u >> h & m) ? (el h) e))) z)
       m ((1 << e) - 1) x (u & m)
       s (net (map (k \ x >> k & 1) ^e))
       (ror y r) ((y >> r | y << (e - r)) & m)
       r (filter (r \ ror ((1 << s) - 1) r = x) ^e)
       (x = 0 || x = m || atom? r ? ()
          ((e = 64 ? 1 0) << 22 | <r << 16 | (((63 ^ (2 * e - 1)) & 63) | (s - 1)) << 10)))
   (ga-wimm m d n v)
    (? (nom? (peep ga-flip m ()))
        (: f (v < 0 ? (ga-flip m) m) u (v < 0 ? (0 - v) v) b (<>(ga-walu f))
           (? (n = 31 || d = 31 && elem m '(add sub)) (scare 'gas-a64-operand [m v])   ; 31 would be wsp
              (u <= 4095) (b | u << 10 | n << 5 | d)
              (u % 4096 = 0 && u >> 12 <= 4095) (b | 1 << 22 | (u >> 12) << 10 | n << 5 | d)
              (scare 'imm12-range v)))
       (ga-bm v 32 @ f (!(charm? f) || d = 31 && m != 'ands ? (scare 'a64-bitmask-imm v)
                          (<>(ga-walu m) | f | n << 5 | d))))
   ;; mov rD, #v in one word as gas picks it -- movz, movn, else an orr bitmask -- or ()
   (ga-movi z d v)
    (: top ((1 << z) - 1) u (u64 v % (1 << z)) n (u ^ top) sf (z = 64 ? 0x80000000 0)
       (lanes x) (filter (h \ (x >> (16 * h)) % 65536 != 0) ^(z // 16))
       (wide base x l) (: h (two? l ? <l 0) (sf | base | h << 21 | ((x >> (16 * h)) % 65536) << 5 | d))
       (? (#(lanes u) <= 1) (wide 0x52800000 u (lanes u))
          (#(lanes n) <= 1) (wide 0x12800000 n (lanes n))
          (ga-bm u z @ f (charm? f ? (sf | 0x320003E0 | f | d) ()))))
   (ga-sp? o) (o @ ('reg x _) (x = 'sp) 0)
   (ga-dp m os z)                                   ; a data op laid as its own word, z bits wide
    (: k #os (r i) (ga-hw (ga-r (os i))) sf (z = 64 ? 0x80000000 0) top (z - 1)
       (? (m = 'mov) ((os 1) @ ('imm v) (ga-movi z (r 0) v @ w (charm? w ? (ga-raw w) (scare 'gas-a64-mov-imm v)))
                                (ga-raw (0x2A0003E0 | r 1 << 16 | r 0)))
          (m = 'neg) (ga-raw (sf | 0x4B0003E0 | r 1 << 16 | r 0))
          (m = 'mvn) (ga-raw (sf | 0x2A2003E0 | r 1 << 16 | r 0))
          (elem m '(cmp tst))
           (: op (m = 'cmp ? 'subs 'ands)
              ((os 1) @ ('imm v) (ga-raw (ga-wimm op 31 (r 0) v))
                        (ga-raw (<(ga-walu op) | r 1 << 16 | r 0 << 5 | 31))))
          (k != 3) (scare 'gas-a64-operand os)
          (m = 'mul) (ga-raw (0x1B007C00 | r 2 << 16 | r 1 << 5 | r 0))
          (two? (peep ga-walu m ()))
           ((os 2) @ ('imm v) (ga-raw (ga-wimm m (r 0) (r 1) v))
                     (ga-raw (<(ga-walu m) | r 2 << 16 | r 1 << 5 | r 0)))
          ((os 2) @ ('imm s)                       ; the shifts: a bitfield move by an immediate
             (s < 0 || s > top ? (scare 'gas-a64-operand os)
                (ga-raw ((m @ 'lsl (0x53000000 | ((z - s) % z) << 16 | (top - s) << 10)
                              'lsr (0x53000000 | s << 16 | top << 10)
                              'asr (0x13000000 | s << 16 | top << 10)
                              (0x13800000 | r 1 << 16 | s << 10))
                         | sf | (z = 64 ? 0x400000 0) | r 1 << 5 | r 0)))
             (ga-raw (sf | (m @ 'lsl 0x1AC02000 'lsr 0x1AC02400 'asr 0x1AC02800 0x1AC02C00)   ; ..and by a register
                       | r 2 << 16 | r 1 << 5 | r 0)))))
   ;; a load or store's unscaled word, X target then W; the access size rides bits [31:30]
   ga-ldst {'ldr [0xF8400000 0xB8400000] 'ldrb [() 0x38400000] 'ldrh [() 0x78400000]
            'ldrsb [0x38800000 0x38C00000] 'ldrsh [0x78800000 0x78C00000] 'ldrsw [0xB8800000 ()]
            'str [0xF8000000 0xB8000000] 'strb [() 0x38000000] 'strh [() 0x78000000]}
   (ga-wb lb ix t b v)                              ; post- (ix 1) or pre-indexed (ix 3): imm9, the base written back
    (charm? v && -256 <= v <= 255 ? (ga-raw (lb | (v & 511) << 12 | ix << 10 | ga-hw b << 5 | t))
       (scare 'gas-a64-operand v))
   (ga-ls m os)
    (: k #os rw (ga-rw (os 0)) t (ga-hw <rw) row (ga-ldst m) lb (<>rw = 8 ? <row <>row)
       lg (charm? lb ? (lb >> 30) 0)
       st? (elem m '(str strb strh))
       ir? (<>rw = 8 || !(elem m '(ldrsb ldrsh)))   ; the IR's rows say all but a W sign-extend
       (? (!(charm? lb)) (scare 'gas-a64-width os)
          (k = 3) ((os 1) @ ('mem b 0) ((os 2) @ ('imm v) (ga-wb lb 1 t b v) (scare 'gas-a64-operand os))
                             (scare 'gas-a64-operand os))
          (k != 2) (scare 'gas-a64-operand os)
          ((os 1) @ ('mem b o)
             (? ir? (st? ? [[(ga-st m (<>rw = 8 ? 0 1)) b o <rw]] [[(ga-ld m (<>rw = 8 ? 0 1)) <rw b o]])
                (charm? o && o >= 0 && o % (1 << lg) = 0 && o >> lg <= 4095)      ; scaled imm12
                 (ga-raw (lb | 0x01000000 | (o >> lg) << 10 | ga-hw b << 5 | t))
                (charm? o && -256 <= o <= 255) (ga-raw (lb | (o & 511) << 12 | ga-hw b << 5 | t))
                (scare 'gas-a64-operand os))
             ('memw b o) (ga-wb lb 3 t b o)
             ('memx b i x s)
              (s != -1 && s != 0 && s != lg ? (scare 'gas-a64-operand os)
                 (ga-raw (lb | 0x00200800 | ga-hw i << 16 | x << 13 | (s = lg ? 1 0) << 12 | ga-hw b << 5 | t)))
             (scare 'gas-a64-operand os))))
   ;; words the IR has no row for: the hints, by name and by number
   ga-hints {'yield 0xD503203F 'sev 0xD503209F 'sevl 0xD50320BF 'csdb 0xD503229F 'esb 0xD503221F
             'paciasp 0xD503233F 'autiasp 0xD50323BF 'pacibsp 0xD503237F 'autibsp 0xD50323FF
             'xpaclri 0xD50320FF}
   ga-bti {'c 0xD503245F 'j 0xD503249F 'jc 0xD50324DF}
   ;; register ops laid as their own word, [X W]: the inverted logicals, the carry pair, the bit
   ;; and byte reversals and counts
   ga-lnot {'bic [0x8A200000 0x0A200000 'and] 'bics [0xEA200000 0x6A200000 'ands]
            'orn [0xAA200000 0x2A200000 'orr] 'eon [0xCA200000 0x4A200000 'eor]}
   ga-carry {'adc [0x9A000000 0x1A000000] 'adcs [0xBA000000 0x3A000000]
             'sbc [0xDA000000 0x5A000000] 'sbcs [0xFA000000 0x7A000000]}
   ga-un {'rbit [0xDAC00000 0x5AC00000] 'rev [0xDAC00C00 0x5AC00800] 'rev16 [0xDAC00400 0x5AC00400]
          'rev32 [0xDAC00800 ()] 'clz [0xDAC01000 0x5AC01000] 'cls [0xDAC01400 0x5AC01400]}
   ;; the unprivileged loads and stores (uaccess): an imm9 offset, never written back
   ga-ut {'sttr [0xF8000800 0xB8000800] 'sttrb [() 0x38000800] 'sttrh [() 0x78000800]
          'ldtr [0xF8400800 0xB8400800] 'ldtrb [() 0x38400800] 'ldtrh [() 0x78400800]
          'ldtrsw [0xB8800800 ()]}
   ;; the exclusives and acquire/release, [X W] by the data register; a store-exclusive's
   ;; status register leads. the address is a bare base
   ga-ex {'ldxr [0xC85F7C00 0x885F7C00] 'ldxrb [() 0x085F7C00] 'ldxrh [() 0x485F7C00]
          'ldaxr [0xC85FFC00 0x885FFC00] 'ldaxrb [() 0x085FFC00] 'ldaxrh [() 0x485FFC00]
          'ldar [0xC8DFFC00 0x88DFFC00] 'ldarb [() 0x08DFFC00] 'ldarh [() 0x48DFFC00]
          'stlr [0xC89FFC00 0x889FFC00] 'stlrb [() 0x089FFC00] 'stlrh [() 0x489FFC00]}
   ga-sx {'stxr [0xC8007C00 0x88007C00] 'stxrb [() 0x08007C00] 'stxrh [() 0x48007C00]
          'stlxr [0xC800FC00 0x8800FC00] 'stlxrb [() 0x0800FC00] 'stlxrh [() 0x4800FC00]}
   (ga-ex-ins row os)
    (: k #os rw (ga-rw (os (k - 2))) b (<>rw = 8 ? <row <>row)
       s9 (k = 3 ? (ga-rw <os) ['zr 4])
       ((os (k - 1)) @ ('mem x 0)
          (charm? b && <>s9 = 4 ? (ga-raw (b | (k = 3 ? (ga-hw <s9 << 16) 0) | ga-hw x << 5 | ga-hw <rw))
             (scare 'gas-a64-operand os))
          (scare 'gas-a64-operand os)))
   ;; the lse atomics by spelling: ld<op>/st<op>/swp/cas, then a|l|al, then b|h ->
   ;; (kind opbits acq rel size), size () for the register's own
   ga-lse-ops '(("add" 0) ("clr" 1) ("eor" 2) ("set" 3) ("smax" 4) ("smin" 5) ("umax" 6) ("umin" 7))
   (ga-lse m)
    (: s (show m)
       (rest t n) (snip t n #t)
       (pre t l) (? !l () (starts? t <<l) [(<>(<l)) (rest t #(<<l))] (pre t >l))
       (op k t) (pre t ga-lse-ops @ (o u) [k (o << 12) u] _ ())
       hd (? (starts? s "cas") ['cas 0 (rest s 3)] (starts? s "swp") ['ld 0x8000 (rest s 3)]
             (starts? s "ld") (op 'ld (rest s 2)) (starts? s "st") (op 'st (rest s 2)) ())
       (ord t) (? (starts? t "al") [1 1 (rest t 2)] (starts? t "a") [1 0 (rest t 1)]
                  (starts? t "l") [0 1 (rest t 1)] [0 0 t])
       (siz t) (? (t = "") ['n] (t = "b") [0] (t = "h") [1] ())
       (? !hd () (ord (hd 2) @ (a r t) (? (siz t = ()) () (<hd = 'st && a = 1) ()
                                          [<hd (hd 1) a r <(siz t)]))))
   (ga-lse-ins m row os)
    (row @ (kind ob a r z)
       (: k #os st (kind = 'st) rs (ga-rw (os 0)) w <>rs
          rt (st ? ['zr w] (ga-rw (os 1)))
          sz (z = 'n ? (w = 8 ? 3 2) z)
          (? ((st ? 2 3) != k || <>rt != w || (z != 'n && w != 4)) (scare 'gas-a64-operand [m os])
             ((os (k - 1)) @ ('mem x 0)
                (ga-raw (sz << 30 | ga-hw <rs << 16 | ga-hw x << 5 | ga-hw <rt
                         | (kind = 'cas ? (0x08A07C00 | a << 22 | r << 15) (0x38200000 | a << 23 | r << 22 | ob))))
                (scare 'gas-a64-operand [m os]))))
       _ (scare 'gas-a64-op m))
   ;; a prefetch: its operation by name (type << 3 | level - 1 << 1 | strm) or number; the
   ;; address scaled by 8 when it can be, else prfum's imm9
   ga-prf {'pldl1keep 0 'pldl1strm 1 'pldl2keep 2 'pldl2strm 3 'pldl3keep 4 'pldl3strm 5
           'plil1keep 8 'plil1strm 9 'plil2keep 10 'plil2strm 11 'plil3keep 12 'plil3strm 13
           'pstl1keep 16 'pstl1strm 17 'pstl2keep 18 'pstl2strm 19 'pstl3keep 20 'pstl3strm 21}
   (ga-prf-ins m os)
    (: op ((os 0) @ ('sym t) (peep ga-prf t ()) ('imm n) (0 <= n <= 31 ? n ()) ())
       ((os 1) @ ('mem x v)
          (? !(charm? op) (scare 'gas-a64-operand os)
             (m = 'prfm && v % 8 = 0 && 0 <= v <= 32760) (ga-raw (0xF9800000 | (v // 8) << 10 | ga-hw x << 5 | op))
             (-256 <= v <= 255) (ga-raw (0xF8800000 | (v & 511) << 12 | ga-hw x << 5 | op))
             (scare 'gas-a64-operand os))
          (scare 'gas-a64-operand os)))
   (ga-row row os) (: w (ga-wide os) b (w = 8 ? <row <>row)
                      (charm? b ? b (scare 'gas-a64-width os)))
   (ga-regw row os)                                 ; rd, rn{, rm}
    (: b (ga-row row os) (r i) (ga-hw (ga-r (os i)))
       (ga-raw (b | (#os = 3 ? (r 2 << 16) 0) | r 1 << 5 | r 0)))
   (ga-lnot-ins m os)
    (: row (ga-lnot m) op (row 2) d (ga-hw (ga-r (os 0))) n (ga-hw (ga-r (os 1)))
       ((os 2) @ ('imm v)                           ; bic #v is and #~v
          (ga-wide (take 2 os) = 4 ? (ga-raw (ga-wimm op d n (0 - v - 1)))
             (ga-bm (0 - v - 1) 64 @ f
                (charm? f ? (ga-raw (0x80000000 | <>(ga-walu op) | f | n << 5 | d))
                   (scare 'a64-bitmask-imm v))))
          (ga-regw row os)))
   (ga-ut-ins m os)
    (: rw (ga-rw (os 0)) row (ga-ut m) b (<>rw = 8 ? <row <>row)
       ((os 1) @ ('mem x v)
          (charm? b && -256 <= v <= 255 ? (ga-raw (b | (v & 511) << 12 | ga-hw x << 5 | ga-hw <rw))
             (scare 'gas-a64-operand os))
          (scare 'gas-a64-operand os)))
   (ga-bcond s) (show s @ t (#t > 2 && t 0 = 98 && t 1 = 46 ? (peep ga-cc (name (snip t 2 #t)) ()) ()))
   (ga-inplace op d s) (d = s ? () [['mov d s]])       ; the IR's unary ops work in place
   (ga-ins m os)
    (#os @ k
       (? (charm? (peep ga-arity m ()) && k != ga-arity m) (scare 'gas-a64-operand [m os])
          (m = 'ret && k = 1) (ga-r (os 0) @ r (r = 'lr ? '((ret)) (ga-raw (0xD65F0000 | ga-hw r << 5))))
          (ghas? ga-nils m) (k = 0 ? [[(ga-nils m)]] (scare 'gas-a64-operand [m os]))
          (nom? (ga-bcond m)) (k = 1 ? [['br (ga-bcond m) (<>(os 0))]] (scare 'gas-a64-operand [m os]))
          (m = 'b) [['jmp (<>(os 0))]]
          (m = 'bl) [['call (<>(os 0))]]
          (m = 'br) [['jmpr (ga-r (os 0))]]
          (m = 'blr) [['callr (ga-r (os 0))]]
          (elem m '(dsb dmb)) [[m (<>(os 0))]]
          (m = 'mrs) [['mrs (ga-r (os 0)) (<>(os 1))]]
          (m = 'msr) ((os 1) @ ('imm n) [['msri (<>(os 0)) n]] [['msr (<>(os 0)) (ga-r (os 1))]])
          (elem m ga-sys) [[m (<>(os 0)) (k > 1 ? (ga-r (os 1)) 'zr)]]
          (ghas? ga-exc m) [[(ga-exc m) (k > 0 ? (<>(os 0)) 0)]]
          (m = 'svc) (: n (k > 0 ? (<>(os 0)) 0) (n = 0 ? '((sys)) [['svcn n]]))
          (two? (peep ga-ldst m ())) (ga-ls m os)
          (elem m '(mov cmp tst neg mvn mul add sub and orr eor adds subs ands lsl lsr asr ror) && ga-wide os = 4)
           (ga-dp m os 32)
          (elem m '(neg mvn lsl lsr asr ror) && !(any ga-sp? os)) (ga-dp m os 64)
          (m = 'mov && !(ga-sp? (os 0)) && ((os 1) @ ('imm v) (constellation? v && charm? (ga-movi 64 0 v)) 0))
           (ga-dp m os 64)
          (m = 'mov)
           (: d (ga-r (os 0)) s (os 1)
              (s @ ('imm n) [['li d n]]
                   (d = 'sp || ga-r s = 'sp ? [['lea d (ga-r s) 0]] [['mov d (ga-r s)]])))
          (m = 'movz) [['li (ga-r (os 0)) (<>(os 1))]]
          (ghas? ga-alu m)
           (k = 3 ? [[(ga-alu m) (ga-r (os 0)) (ga-r (os 1)) (ga-v (os 2))]] (scare 'gas-a64-operand os))
          (m = 'cmp) [['cmp (ga-r (os 0)) (ga-v (os 1))]]
          (m = 'tst) [['test (ga-r (os 0)) (ga-v (os 1))]]
          (m = 'neg) (ga-r (os 0) @ d (ga-inplace 'neg d (ga-r (os 1)) + [['neg d]]))
          (m = 'mvn) (ga-r (os 0) @ d (ga-inplace 'not d (ga-r (os 1)) + [['not d]]))
          (ghas? ga-sh m)
           (: d (ga-r (os 0)) s (ga-r (os 1)) c (os 2)
              (k != 3 ? (scare 'gas-a64-operand os)
                 (c @ ('imm n) (ga-inplace m d s + [[(ga-sh m) d n]])
                      (d = s ? [[(name (show (ga-sh m) + "v")) d (ga-r c)]] (scare 'gas-a64-operand os)))))
          (charm? (peep ga-hints m ())) (k = 0 ? (ga-raw (ga-hints m)) (scare 'gas-a64-operand [m os]))
          (m = 'hint) ((os 0) @ ('imm n) (k = 1 && 0 <= n <= 127 ? (ga-raw (0xD503201F | n << 5)) (scare 'gas-a64-operand [m os]))
                         (scare 'gas-a64-operand [m os]))
          (m = 'bti) (? (k = 0) (ga-raw 0xD503241F)
                        ((os 0) @ ('sym t) (charm? (peep ga-bti t ()) && k = 1) 0) (ga-raw (ga-bti <>(os 0)))
                        (scare 'gas-a64-operand [m os]))
          (elem m '(cbz cbnz))                       ; compare and branch: the flags untouched
           (k = 2 ? (ga-rw (os 0) @ rw [['cbr ((m = 'cbz ? 0x34000000 0x35000000) | (<>rw = 8 ? 0x80000000 0)) <rw (<>(os 1))]])
              (scare 'gas-a64-operand [m os]))
          (two? (peep ga-lnot m ())) (k = 3 ? (ga-lnot-ins m os) (scare 'gas-a64-operand [m os]))
          (two? (peep ga-carry m ())) (k = 3 ? (ga-regw (ga-carry m) os) (scare 'gas-a64-operand [m os]))
          (two? (peep ga-un m ())) (k = 2 ? (ga-regw (ga-un m) os) (scare 'gas-a64-operand [m os]))
          (two? (peep ga-ut m ())) (k = 2 ? (ga-ut-ins m os) (scare 'gas-a64-operand [m os]))
          (elem m '(prfm prfum)) (k = 2 ? (ga-prf-ins m os) (scare 'gas-a64-operand [m os]))
          (two? (peep ga-ex m ())) (k = 2 ? (ga-ex-ins (ga-ex m) os) (scare 'gas-a64-operand [m os]))
          (two? (peep ga-sx m ())) (k = 3 ? (ga-ex-ins (ga-sx m) os) (scare 'gas-a64-operand [m os]))
          (ga-lse-ins m (ga-lse m) os)))
   (ga-line toks)
    (gline toks @ l
       (l @ ('label s) [['label s]]
            ('ins m os) (ga-ins m (map ga-opnd os))
            ()))

   ;; -- rv64: dst first, the ABI register names, off(base) memory, the csr pseudos. --
   (gr-reg s) (peep rv-names (name s) ())
   (gr-opnd toks)
    (toks @ (('sym s)) (gr-reg s @ r (nom? r ? ['reg r 8] ['sym (name s)]))
            (('ch 40) ('sym b) ('ch 41)) ['mem (gr-reg b) 0]
            (: (mem l acc)
                (? (atom? l) ['imm (gimm toks)]
                   (<l = '(ch 40))
                    (>l @ (('sym b) ('ch 41)) (gr-reg b @ r (nom? r ? ['mem r (two? acc ? (gimm (rev acc)) 0)] (scare 'gas-rv64-operand toks)))
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
    (#os @ k
       (? (ghas? gr-nils m) [[(gr-nils m)]]
          (m = 'unimp) '((csrw cycle zr))
          (m = 'sfence.vma) [['sfence (k > 0 ? (gr-r (os 0)) 'zr) (k > 1 ? (gr-r (os 1)) 'zr)]]
          (m = 'li) [['li (gr-r (os 0)) (<>(os 1))]]
          (m = 'mv) [['mov (gr-r (os 0)) (gr-r (os 1))]]
          (m = 'j) [['jmp (<>(os 0))]]
          (m = 'jr) [['jmpr (gr-r (os 0))]]
          (m = 'jalr) [['callr (gr-r (os 0))]]
          (m = 'call) [['call (<>(os 0))]]
          (ghas? gr-bcc m) [['cmp (gr-r (os 0)) (gr-r (os 1))] ['br (gr-bcc m) (<>(os 2))]]
          (ghas? gr-bz m) [['cmp (gr-r (os 0)) 0] ['br (gr-bz m) (<>(os 1))]]
          (ghas? gr-alu m) [[(gr-alu m) (gr-r (os 0)) (gr-r (os 1)) (gr-v (os 2))]]
          (ghas? gr-sh m)
           (: d (gr-r (os 0)) s (gr-r (os 1))
              ((d = s ? () [['mov d s]]) + [[(gr-sh m) d (gr-v (os 2))]]))
          (m = 'neg) (: d (gr-r (os 0)) s (gr-r (os 1)) ((d = s ? () [['mov d s]]) + [['neg d]]))
          (m = 'not) (: d (gr-r (os 0)) s (gr-r (os 1)) ((d = s ? () [['mov d s]]) + [['not d]]))
          (ghas? gr-ld m) ((os 1) @ ('mem b o) [[(gr-ld m) (gr-r (os 0)) b o]] (scare 'gas-rv64-operand os))
          (ghas? gr-st m) ((os 1) @ ('mem b o) [[(gr-st m) b o (gr-r (os 0))]] (scare 'gas-rv64-operand os))
          (m = 'csrr) [['csrr (gr-r (os 0)) (<>(os 1))]]
          (elem m gr-csr1) [[m (<>(os 0)) (gr-v (os 1))]]
          (elem m gr-csr2) [[m (gr-r (os 0)) (<>(os 1)) (gr-v (os 2))]]
          (scare 'gas-rv64-op m)))
   (gr-line toks)
    (gline toks @ l
       (l @ ('label s) [['label s]]
            ('ins m os) (gr-ins m (map gr-opnd os))
            ()))

   ;; -- thumb: the same operand grammar as a64 over r0..r12, the small system handful. --
   (gt-reg s) (peep t32-names (name s) ())
   (gt-opnd toks)
    (toks @ (('ch 35) . rest) ['imm (gimm rest)]
            (('num _) . _) ['imm (gimm toks)]
            (('sym s)) (gt-reg s @ r (nom? r ? ['reg r 4] ['sym (name s)]))
            (('ch 91) ('sym b) ('ch 93)) ['mem (gt-reg b) 0]
            (('ch 91) . ('sym b) . ('ch 44) . rest)
             (#rest @ n
                (!(rest (n - 1) = '(ch 93)) ? (scare 'gas-thumb-operand toks)
                   ['mem (gt-reg b) (<>(gt-opnd (rev >(rev rest))))]))
            (scare 'gas-thumb-operand toks))
   (gt-r o) (o @ ('reg x _) x (scare 'gas-thumb-register o))
   (gt-v o) (o @ ('imm n) n ('reg x _) x (scare 'gas-thumb-operand o))
   gt-nils (gtab '((nop nop) (wfi wfi) (isb isb)))
   gt-alu (gtab '((add add) (sub sub) (and and) (orr or) (eor xor) (mul imul)))
   (gt-ins m os)
    (#os @ k
       (? (ghas? gt-nils m) [[(gt-nils m)]]
          (m = 'bkpt) (: n (k > 0 ? (<>(os 0)) 0) (n = 0 ? '((trap)) [['brk n]]))
          (m = 'svc) '((sys))
          (m = 'dsb) [['dsb (<>(os 0))]]
          (m = 'mrs) [['mrs (gt-r (os 0)) (<>(os 1))]]
          (m = 'b) [['jmp (<>(os 0))]]
          (m = 'bl) [['call (<>(os 0))]]
          (m = 'bx) (gt-r (os 0) = 'lr ? '((ret)) [['jmpr (gt-r (os 0))]])
          (m = 'mov) ((os 1) @ ('imm n) [['li (gt-r (os 0)) n]] [['mov (gt-r (os 0)) (gt-r (os 1))]])
          (m = 'cmp) [['cmp (gt-r (os 0)) (gt-v (os 1))]]
          (ghas? gt-alu m)
           (k = 3 ? [[(gt-alu m) (gt-r (os 0)) (gt-r (os 1)) (gt-v (os 2))]]
              [[(gt-alu m) (gt-r (os 0)) (gt-r (os 0)) (gt-v (os 1))]])
          (m = 'ldr) ((os 1) @ ('mem b o) [['ld (gt-r (os 0)) b o]] (scare 'gas-thumb-operand os))
          (m = 'str) ((os 1) @ ('mem b o) [['st b o (gt-r (os 0))]] (scare 'gas-thumb-operand os))
          (scare 'gas-thumb-op m)))
   (gt-line toks)
    (gline toks @ l
       (l @ ('label s) [['label s]]
            ('ins m os) (gt-ins m (map gt-opnd os))
            ()))

   ;; -- file scope: an asm("..") outside any function is the whole assembler -- sections, data,
   ;; labels the object exports. the directives read are the ones C headers write there (the
   ;; kernel's export, initcall, tracepoint and static-call rows); a run of instructions goes to
   ;; gas-text, and any other directive scares. --
   (gf-kin? nm b) (nm = b || starts? nm (b + "."))
   ; gas's own defaults for a section named without flags: the standard four and their dotted
   ; kin, .init/.fini, and otherwise none -- not even allocated
   (gf-dflt nm) (? (gf-kin? nm ".text" || elem nm '(".init" ".fini")) [1 6]
                   (gf-kin? nm ".data") [1 3]
                   (gf-kin? nm ".bss") [8 3]
                   (gf-kin? nm ".rodata") [1 2]
                   [1 0])
   ; M and S only license merging, which a section never owes
   (gf-flags s) (foldl (\ a c (c @ 97 (a | 2) 119 (a | 1) 120 (a | 4) 77 a 83 a
                                  (scare 'gas-section-flag (string c))))
                       0 (chars s))
   ; .section name[, "flags"[, @type[, entsize]]] -> [name type flags]
   (gf-sect xs)
    (: nm (xa-unquote <xs) d (gf-dflt nm)
       ty (2 < #xs ?
             (xs 2 @ t (? (elem t '("@progbits" "%progbits")) 1
                          (elem t '("@nobits" "%nobits")) 8
                          (scare 'gas-section-type t)))
             <d)
       [nm ty (1 < #xs ? (gf-flags (xa-unquote (xs 1))) <>d)])
   (gf-width tgt mn) (? (mn = ".byte") 1
                        (elem mn '(".short" ".value" ".2byte" ".hword")) 2
                        (mn = ".word") (tgt = 'x64 ? 2 4)
                        (elem mn '(".long" ".int" ".4byte")) 4
                        (elem mn '(".quad" ".8byte" ".dword")) 8
                        0)
   ; .ascii's operands: literals split by commas or blanks, C's escapes -> one byte list per literal
   (gf-strs s)
    (: n #s
       (oct? c) (48 <= c <= 55)
       (esc i)                                      ; i past the backslash -> [byte next]
        (s i @ c
           (? (oct? c) ((: (o j v k) (k < 3 && j < n && oct? (s j) ? (o (j + 1) (v * 8 + s j - 48) (k + 1))
                                        [(v & 255) j])) i 0 0)
              (c = 120) ((: (h j v) (j < n && ghex? (s j) ? (h (j + 1) (v * 16 + hexv (s j)))
                                       [(v & 255) j])) (i + 1) 0)
              [(c @ 110 10 116 9 114 13 98 8 102 12 118 11 97 7 c) (i + 1)]))
       (str i acc)
        (? (i >= n) (scare 'gas-string s)
           (s i = 34) [(rev acc) (i + 1)]
           (s i = 92 && i + 1 < n) (esc (i + 1) @ e (str <>e (<e . acc)))
           (str (i + 1) (s i . acc)))
       (go i acc)
        (? (i >= n) (rev acc)
           (blank? (s i) || s i = 44) (go (i + 1) acc)
           (s i = 34) (str (i + 1) () @ r (go <>r (<r . acc)))
           (scare 'gas-string s))
       (go 0 ()))
   ; a data operand as a linear sum [k terms], terms ((sym . coef)..) with `.` among the syms --
   ; label arithmetic, which is all a relocation can carry. each level answers (sum . rest) | 'bad
   (gf-neg l) [(0 - <l) (map (p \ (<p . (0 - >p))) <>l)]
   (gf-plus a b) [(<a + <b) (<>a + <>b)]
   (gf-prim ts rl)
    (atom? ts ? 'bad
       (<ts @ ('num v) ([v ()] . >ts)
              ('sym s) ([0 [(s . 1)]] . >ts)
              ('lref n d) ([0 [((rl n d) . 1)]] . >ts)
              ('ch 40) (gf-sum >ts rl @ r
                          (gbad? r || atom? >r || !(<>r = '(ch 41)) ? 'bad (<r . >>r)))
              ('ch 45) (gf-prim >ts rl @ r (gbad? r ? 'bad ((gf-neg <r) . >r)))
              ('ch 43) (gf-prim >ts rl)
              'bad))
   (gf-sum ts rl)
    (: (go r) (? (gbad? r) 'bad
                 (atom? >r) r
                 !(elem <>r '((ch 43) (ch 45))) r
                 (gf-prim >>r rl @ q
                    (gbad? q ? 'bad
                       (go ((gf-plus <r (<>r = '(ch 43) ? <q (gf-neg <q))) . >q)))))
       (go (gf-prim ts rl)))
   (gf-norm terms)                                  ; summed per sym, zeros dropped
    ({} @ t (foldl (\ _ p (pin t <p (peep t <p 0 + >p))) 0 terms,
             filter (p \ >p != 0) (map (k \ (k . (t k))) (sort (keys t)))))
   ; -> [pc? sym k]: sym () for a constant; pc? for sym + k - `.`
   (gf-val e rl)
    (gtoks e @ ts
       (!(any (t \ <t = 'sym || <t = 'lref) ts) ? [() () (gimm ts)]
          (gf-sum ts rl @ r
             (gbad? r || two? >r ? (scare 'gas-data e)
                (: ns (gf-norm <><r)
                   dt (filter (p \ <p = ".") ns)
                   sy (filter (p \ <p != ".") ns)
                   (? (atom? sy || two? >sy || ><sy != 1) (scare 'gas-data e)
                      (atom? dt) [() <<sy <<r]
                      (><dt = -1) [1 <<sy <<r]
                      (scare 'gas-data e)))))))
   (gf-le v w) (: u (v < 0 ? (v + (1 << 8 * w)) v) (map (i \ byte (u >> 8 * i)) ^w))
   ; a word's bytes, or its fixup: rel32 is S + aux - P - 4 wherever it resolves, so `- .` rides aux + 4
   (gf-word tgt w e rl)
    (: v (gf-val e rl) pc <v s <>v k <>>v
       (? !(string? s) (gf-le k w)
          pc (? (w = 4 && !(gthumb? tgt)) [['fix 4 'rel32 (name s) (k + 4)]]
                (w = 8 && elem tgt '(x64 a64)) [['fix 8 'rel64 (name s) (k + 8)]]     ; the jump table's `key - .`
                (scare 'gas-data-pcrel e))
          (w = 8) [['fix 8 'abs64 (name s) k]]
          (w = 4 && (tgt = 'x64 || gthumb? tgt)) [['fix 4 'abs32 (name s) k]]
          (scare 'gas-data-width e)))
   ; GNU's numeric local labels in an instruction line -> the names gas-top laid them under
   (gf-lsub s rl)
    (: n #s
       (go i acc)
        (i >= n ? acc
           (s i @ c
              (digit? c && (i = 0 || !(gidc? (s (i - 1)))) ?
                 (: j ((: (g j) (j < n && digit? (s j) ? (g (j + 1)) j)) i)
                    (j < n && (s j = 102 || s j = 98) && (j + 1 >= n || !(gidc? (s (j + 1)))) ?
                       (go (j + 1) (acc + rl (gdecv (snip s i j)) (s j)))
                       (go j (acc + snip s i j))))
                 (go (i + 1) (acc + string c)))))
       (go 0 ""))
   ; a leading `name:`'s colon, or -1
   (gf-labat s) (: n #s j ((: (g j) (j < n && gidc? (s j) ? (g (j + 1)) j)) 0)
                   (0 < j && j < n && s j = 58 ? j -1))
   ; a directive's name runs to its identifier's end: a .S line spells `.long((x)-.)` unspaced
   (gf-dsplit s) (: j ((: (g j) (j < #s && (gidc? (s j) || s j = 46) ? (g (j + 1)) j)) 1)
                    [(snip s 0 j) (xa-trim (snip s j #s))])
   (gf-base nm) ((: (g j) (? (j >= #nm) nm (nm j = 1) (snip nm 0 j) (g (j + 1)))) 0)   ; a subsection's section
   (gf-lines tgt src)
    (elem tgt '(x64 rv64) @ hash?
       (catmap (ln \ xa-lines (hash? ? (xa-decomment ln) (gcut2 ln 47))) (gsplit src 10)))
   ;; gas's macro language, over a text's lines before anything reads them: .macro/.endm and a
   ;; call (positional or name=value arguments), .irp and .rept, .if/.ifc/.ifnc/.ifeq/.ifne with
   ;; .else, .set/.equ (the symbol reads as its value on the lines after), .error, .purgem --
   ;; the kernel's exception-table macro, which finds a register's number by name
   gf-ifs '(".if" ".ifc" ".ifnc" ".ifeq" ".ifne")
   (gf-expand ls)
    (: mac {} sv {}
       (dname s) (xa-trim s @ t (0 < #t && t 0 = 46 ? (xa-mnem t) ""))
       (word s i) ((: (g j) (j < #s && gidc? (s j) ? (g (j + 1)) j)) i)
       ; a block's body up to its closer, nested openers counted -> (body rest)
       (grab l opens close)
        (: (go l d acc) (atom? l ? (scare 'gas-block close)
                           (dname <l @ w
                              (w = close && d = 0 ? [(rev acc) >l]
                                 (go >l (? (elem w opens) (d + 1) (w = close) (d - 1) d) (<l . acc)))))
           (go l 0 ()))
       ; an .if body split at its own .else; an .elseif opens the rest as an .if of its own
       (split l) (: (go l d acc) (atom? l ? [(rev acc) ()]
                                    (dname <l @ w
                                       (? (w = ".else" && d = 0) [(rev acc) >l]
                                          (w = ".elseif" && d = 0)
                                           [(rev acc) (("\t.if " + xa-rest (xa-trim <l)) . >l + ["\t.endif"])]
                                          (go >l (? (elem w gf-ifs) (d + 1) (w = ".endif") (d - 1) d) (<l . acc)))))
                    (go l 0 ()))
       ; a .set symbol reads as its value
       (ssub s) (: n #s
                   (go i acc) (i >= n ? acc
                                 (s i @ c
                                    (gidc? c && (i = 0 || !(gidc? (s (i - 1)))) ?
                                        (: j (word s i) v (peep sv (snip s i j) ())
                                           (go j (acc + (charm? v ? (show v) (snip s i j)))))
                                       (go (i + 1) (acc + string c)))))
                   (go 0 ""))
       (val e) (gimm (gtoks (ssub e)))
       ; \name -> its argument, \() -> nothing; an unknown \name stays for an enclosing reading
       (psub s args)
        (: n #s
           (go i acc) (i >= n ? acc
                         (s i @ c
                            (? (c = 92 && i + 2 < n && s (i + 1) = 40 && s (i + 2) = 41) (go (i + 3) acc)
                               (c = 92 && i + 1 < n && gidc? (s (i + 1)))
                                (: j (word s (i + 1)) a (assoc (snip s (i + 1) j) args)
                                   (two? a ? (go j (acc + <>a)) (go (i + 1) (acc + string c))))
                               (go (i + 1) (acc + string c)))))
           (go 0 ""))
       ; a call's lines: keyword arguments by name, the rest in order, a default else
       (call m rest)
        (: ps <m
           as (0 = #(xa-trim rest) ? () (xa-oplist rest))
           kw (filter (a \ xa-has? a 61) as) po (filter (a \ !(xa-has? a 61)) as)
           (kv nm) (filter (a \ xa-trim (snip a 0 (xa-idx a 61)) = nm) kw)
           (bind ps po acc)
            (atom? ps ? acc
               (: p <ps k (kv <p)
                  (two? k ? (bind >ps po ([<p (xa-trim (snip <k (1 + xa-idx <k 61) #<k))] . acc))
                     (bind >ps >po ([<p (two? po ? <po <>p)] . acc)))))
           args (bind ps po ())
           (map (l \ psub l args) <>m))
       (go l acc)
        (atom? l ? acc
           (: s <l t (xa-trim s) w (dname s) r (xa-rest t)
              (? (w = ".macro")
                  (: b (grab >l '(".macro") ".endm")
                     ws (filter (x \ 0 < #x) (xa-split (string (map (c \ (c = 44 ? 32 c)) (chars r))) 32))
                     specs (map (x \ x @ (a + ":" + _) [a ""] (a + "=" + b) [a b] [x ""]) >ws)
                     (pin mac <ws [specs <b],
                      go <>b acc))
                 (w = ".purgem") (go >l acc)
                 (elem w '(".set" ".equ"))
                  (: xs (xa-oplist r) v (xa-trim (two? >xs ? <>xs ""))
                     (gf-ident? v && !(charm? (peep sv v ())) ? (go >l (s . acc))   ; an alias: gas-top lays it
                        ; a value over labels (`.set .L__sym_size_f, .-f`) is layout's, not a constant here
                        (trap val <>xs (\ _ _ 'label) @ k
                           (k = 'label ? (go >l (s . acc)) (pin sv <xs k, go >l acc)))))
                 (w = ".irp")
                  (: b (grab >l '(".irp" ".rept") ".endr") xs (xa-oplist r)
                     (go <>b (foldl (\ a v (go (map (x \ psub x [[<xs v]]) <b) a)) acc >xs)))
                 (w = ".rept")
                  (grab >l '(".irp" ".rept") ".endr" @ b
                     (go <>b (foldl (\ a i (go <b a)) acc ^(val r))))
                 (elem w gf-ifs)
                  (: b (grab >l gf-ifs ".endif") ab (split <b)
                     yes (? (elem w '(".ifc" ".ifnc"))
                             (: xs (xa-oplist r) eq (xa-trim <xs = xa-trim (two? >xs ? <>xs ""))
                                (w = ".ifc" ? eq !eq))
                             (w = ".ifeq") (val r = 0)
                             (val r != 0))
                     (go <>b (go (yes ? <ab <>ab) acc)))
                 (w = ".error") (scare 'gas-error r)
                 (two? (mac (xa-mnem t))) (go >l (go (call (mac (xa-mnem t)) r) acc))
                 (go >l (ssub s . acc)))))
       (rev (go ls ())))
   ; does gas-text read it whole: instructions, and labels on lines of their own
   ; .base64's text -> its bytes: six bits a character accumulate, a byte out per eight; padding
   ; and anything else outside the alphabet carries no bits
   (gf-b64v c) (? (65 <= c <= 90) (c - 65) (97 <= c <= 122) (c - 71) (48 <= c <= 57) (c + 4)
                  (c = 43) 62 (c = 47) 63 -1)
   (gf-b64 bs)
    (: (go l a n acc)
        (atom? l ? (rev acc)
           (gf-b64v <l @ v
              (v < 0 ? (go >l a n acc)
                 (: a2 (a << 6 | v) n2 (n + 6)
                    (8 <= n2 ? (go >l (a2 & (1 << n2 - 8) - 1) (n2 - 8) ((a2 >> n2 - 8 & 255) . acc))
                       (go >l a2 n2 acc))))))
       (go bs 0 0 ()))
   ; a bare symbol name, the right side of an alias `.set`
   (gf-alpha? c) (65 <= c <= 90 || 97 <= c <= 122)
   (gf-ident? t) (0 < #t && (gf-alpha? (t 0) || t 0 = 95 || t 0 = 46)
                  && all (c \ gf-alpha? c || digit? c || c = 95 || c = 46 || c = 36) (chars t))
   (gas-plain? tgt src)
    (all (l \ (: s (xa-trim l) c (gf-labat s)
                 (? (0 = #s) 1 (0 <= c) (0 = #(xa-trim (snip s (c + 1) #s))) (s 0 != 46))))
         (gf-lines tgt src))
   ; an x64 instruction the 64-bit opcode map dropped -> its mnemonic, else (): the BCD adjusts,
   ; pusha/popa and the rest, and a far call or jump to an immediate segment:offset
   gx-gone '("pusha" "pushaw" "pushal" "pushad" "popa" "popaw" "popal" "popad" "aaa" "aad" "aam"
             "aas" "daa" "das" "into" "bound" "boundw" "boundl" "salc" "arpl" "les" "lds")
   gx-farimm '("lcall" "lcallw" "lcalll" "ljmp" "ljmpw" "ljmpl")
   (gas-nolong tgt src)
    (tgt != 'x64 ? ()
       (foldl (\ a l (nom? a ? a
                       (: s (xa-trim l) c (gf-labat s) t (0 <= c ? (xa-trim (snip s (c + 1) #s)) s)
                          mn (xa-mnem t)
                          (elem mn gx-gone || (elem mn gx-farimm && starts? (xa-trim (xa-rest t)) "$")
                           ? (name mn) ()))))
              () (gf-lines tgt src)))
   ; -> [secs fns objs]: secs ((name type flags forms)..) first-seen, fns and objs the .globl
   ; names a label here defines, split by whether its section executes
   (gas-top tgt src) (gas-top-in tgt src ".text" [1 6] "")
   ; ..read from a section of the caller's own, home, wearing [type flags] htd; a numeric label
   ; is named pfx + GNU's own, so two readings never lay one twice
   (gas-top-in tgt src home htd pfx)
    (: st {'cur home 'prev home 'stk () 'run () 'order () 'globl ()}
       secs {}                                      ; name -> [type flags forms-reversed]
       labs {}                                      ; label -> its section
       lc {}                                        ; N -> how many `N:` so far
       (rl n d) (pfx + show (glabel n (d = 102 ? (1 + peep lc n 0) (peep lc n 0))))
       (row nm td) (two? (secs nm) ? 0
                      (pin st 'order (nm . (st 'order)), pin secs nm [<td <>td ()]))
       (emit fs) (: nm (st 'cur) _ (row nm (nm = home ? htd (gf-dflt nm))) r (secs nm)
                    (pin secs nm [<r <>r (revcat fs <>>r)]))
       (flush _) (st 'run @ r
                    (two? r ? (xa-join "\n" (rev r) @ t
                                 (pin st 'run (), emit (tgt = 'x64 ? (gx-exact t) (gas-text tgt t))))
                       0))
       (goto nm td) (row nm td, pin st 'prev (st 'cur), pin st 'cur nm)
       (raw bs) (two? bs ? (emit [['raw bs]]) 0)
       (num e) (gimm (gtoks e))
       ; .org label+k (or k from the section's start): zeros up to it, over data laid since
       (org e)
        (gtoks e @ ts
           ; `. - (664b-663b) + (662b-661b)`, the alternatives' size check: the pad is the rest, laid
           ; once the labels hold, and it may not move back
           (two? >ts && <ts = ['sym "."] ?
               (emit [['skipx (['num 0] . map (t \ (<t = 'lref ? ['sym (rl <>t <>>t)] t)) >ts) 0 0 'org]])
              (org1 e)))
       (org1 e)
        (: v (gf-val e rl) s <>v r (secs (st 'cur))
           (back l n) (atom? l ? (string? s ? 'bad n)
                         (<l @ f
                            (? (<f = 'label && string? s && <>f = name s) n
                               (<f = 'raw) (back >l (n + foldl (\ a x (a + (two? x ? (x 1) 1))) 0 <>f))
                               (<f = 'label) (back >l n)
                               'bad)))
           at (back (two? r ? <>>r) 0)
           (<v || gbad? at || <>>v < at ? (scare 'gas-org e) (raw (map (i \ 0) ^(<>>v - at)))))
       (dir mn rest)
        (: xs (xa-oplist rest) w (gf-width tgt mn)
           (? (0 < w)
               ; a word over two labels (`.byte 773b-771b`) waits like a .skip: ('wordx toks w)
               (emit (rev (foldl (\ acc f (<f = 'raw && two? acc && <<acc = 'raw ?   ; neighbouring words lay as one raw
                                              (['raw (<><acc + <>f)] . >acc) (f . acc)))
                                 ()
                                 (map (e \ (gtoks e @ ts
                                              (1 < #(filter (t \ <t = 'lref || (<t = 'sym && <>t != ".")) ts) &&
                                               !(any (t \ t = ['sym "."]) ts) ?
                                                  ['wordx (map (t \ (<t = 'lref ? ['sym (rl <>t <>>t)] t)) ts) w]
                                                 ['raw (gf-word tgt w e rl)])))
                                      xs))))
              (mn = ".ascii") (raw (catall (gf-strs rest)))
              (elem mn '(".asciz" ".string")) (raw (catmap (b \ b + [0]) (gf-strs rest)))
              (elem mn '(".zero" ".skip" ".space"))
               (: f (two? >xs ? (num <>xs) 0) ts (gtoks <xs)
                  ; a count over labels waits for the whole template: ('skipx toks fill n)
                  (any (t \ <t = 'lref || <t = 'sym) ts ?
                      (emit [['skipx (map (t \ (<t = 'lref ? ['sym (rl <>t <>>t)] t)) ts) f 0]])
                     (raw (map (i \ f & 255) ^(num <xs)))))
              (mn = ".org") (org rest)
              (mn = ".inst") (tgt = 'a64 ? (raw (catmap (e \ gf-le (num e) 4) xs)) (scare 'gas-directive mn))
              ; a subsection is its section's tail, named apart until the end lays it there
              (mn = ".subsection")
               (: n (num rest) b (gf-base (st 'cur)) r (secs b)
                  (goto (n = 0 ? b (b + string 1 + show n))
                        (two? r ? [<r <>r] (b = home ? htd (gf-dflt b)))))
              (mn = ".base64") (raw (catmap gf-b64 (gf-strs rest)))
              ; what the pre-pass left: an alias, or a value over labels only .size reads
              (elem mn '(".set" ".equ"))
               (gf-ident? (xa-trim <>xs) ? (pin st 'alias ([(xa-unquote <xs) (xa-unquote <>xs)] . peep st 'alias ())) 0)
              (mn = ".weak") (pin st 'globl (rev (map xa-unquote xs) + st 'globl))   ; a static link: a definition
              (mn = ".local") (pin st 'local (map xa-unquote xs + peep st 'local ()))
              ; a common symbol: its zeros in .bss at its alignment, and exported unless .local said
              (elem mn '(".comm" ".lcomm"))
               (: nm (xa-unquote <xs) sz (num <>xs)
                  al (two? >>xs ? (num <>>xs) (: (p2 k) (k < 16 && k * 2 <= sz ? (p2 (k * 2)) k) (p2 1)))
                  c (st 'cur) pv (st 'prev)
                  (goto ".bss" (gf-dflt ".bss"),
                   emit [['align al]], pin labs nm ".bss", emit [['label (name nm)]],
                   raw (map (i \ 0) ^sz),
                   pins st 'cur c 'prev pv,
                   mn = ".comm" && !(elem nm (peep st 'local ())) ? (pin st 'globl (nm . st 'globl)) 0))
              (mn = ".balign") (emit [['align (num <xs)]])
              (mn = ".p2align") (emit [['align (1 << num <xs)]])
              (mn = ".align") (emit [['align (tgt = 'x64 ? (num <xs) (1 << num <xs))]])   ; bytes on x86, a power elsewhere
              (elem mn '(".section" ".pushsection"))
               (gf-sect xs @ d
                  (mn = ".pushsection" ? (pin st 'stk ([(st 'cur) (st 'prev)] . (st 'stk))) 0,
                   goto <d >d))
              (mn = ".popsection")
               (st 'stk @ s
                  (two? s ? 0 (scare 'gas-popsection src),
                   pin st 'stk >s,
                   pin st 'cur <<s,
                   pin st 'prev <><s))
              (mn = ".previous") (st 'cur @ c (pin st 'cur (st 'prev), pin st 'prev c))
              (elem mn '(".text" ".data" ".bss")) (goto mn (gf-dflt mn))
              (elem mn '(".globl" ".global")) (pin st 'globl (rev (map xa-unquote xs) + st 'globl))
              ; what a static link never reads: symbol types and sizes, visibility, unwind rows
              (elem mn '(".type" ".size" ".hidden" ".protected" ".internal" ".file" ".ident") || starts? mn ".cfi_") 0
              ; the ISA a line may use: every one this reader knows, always
              (elem mn '(".arch" ".arch_extension" ".cpu")) 0
              (scare 'gas-directive mn)))
       (line s0)
        (xa-trim s0 @ s
           (0 = #s ? 0
              (gf-labat s @ c
                 (? (0 <= c)
                    (snip s 0 c @ l
                       (flush 0,
                        xa-allof? l digit? 0 ?
                          (: n (gdecv l) k (1 + peep lc n 0) (pin lc n k,
                                                              emit [['label (name (pfx + show (glabel n k)))]]))
                          (pin labs l (st 'cur), emit [['label (name l)]]),
                        line (snip s (c + 1) #s)))
                    (s 0 = 46) (flush 0, gf-dsplit s @ d (dir <d <>d))
                    (pin st 'run ((gf-lsub s rl) . (st 'run)))))))
       _ (foldl (\ _ x (line x)) 0 (gf-expand (gf-lines tgt src)))
       _ (flush 0)
       ; each subsection after its section's own forms, in number order; a function's home has no
       ; tail of its own, so its subsections go to .text
       _ (foldl (\ _ nm (: b (gf-base nm) t (b = "" ? ".text" b) r (secs nm)
                          (row t [<r <>r],
                           secs t @ q (pin secs t [<q <>q (<>>r + <>>q)]),
                           foldl (\ _ f (two? f && <f = 'label ? (pin labs (show <>f) t) 0)) 0 <>>r,
                           pin st 'order (filter (x \ x != nm) (st 'order)))))
                0 (sort (filter (nm \ gf-base nm != nm) (st 'order))))
       ; a .skip over label arithmetic (the alternatives' padding): each section's forms are
       ; sized -- an instruction assembled alone -- and the count read with the labels' section
       ; offsets in place, again until the sizes hold; then it lays its fill
       (width l) (foldl (\ a x (a + (two? x ? (x 1) 1))) 0 l)
       (noms x t) (? (nom? x) (pin t x 1) (atom? x) t (noms >x (noms <x t)))
       (fsz f off) (<f @ 'raw (width <>f) 'label 0 'align ((<>f - off % <>f) % <>f) 'skipx (f 3) 'wordx (f 2)
                         (width (holo-bytes-open tgt [f] (noms f {}))))
       ; label -> its offset, each section's shifted by k times its own large stride
       (offs k) (: t {} si {'i 1}
                   (foldl (\ _ nm (k * 1000003 * si 'i @ b (pin si 'i (si 'i + 1),
                                                            foldl (\ off f (<f = 'label ? (pin t (show <>f) (b + off)) 0,
                                                                            off + fsz f off))
                                                                  0 (rev <>>(secs nm)),
                                                            0)))
                          0 (st 'order),
                    t))
       (ev f t) (gimm (map (k \ (k @ ('sym s) (peep t s () @ v (charm? v ? ['num v] (scare 'gas-skip s)))
                                    k)) (f 1)))
       ; ..and a count that moves with where a section lands is no constant (a difference across sections)
       (skv f t) (ev f t @ v (v = ev f (offs 1) ? v (scare 'gas-data (f 1))))
       (skip? f) (two? f && <f = 'skipx)
       (settle n)
        (: t (offs 0) ch {'c 0}
           (foldl (\ _ nm (: r (secs nm)
                             fs (map (f \ (skip? f ?
                                              (: v (skv f t) v2 (v < 0 ? 0 v)
                                                 (v2 != f 3 ? (pin ch 'c 1) 0,
                                                  (v < 0 && f 4 = 'org ? (scare 'gas-org-back (f 1)) 0,
                                                   ['skipx (f 1) (f 2) v2 (f 4)])))
                                              f)) <>>r)
                             (pin secs nm [<r <>r fs])))
                  0 (st 'order),
            (? !(ch 'c) 0 (n > 4) (scare 'gas-skip-settle src) (settle (n + 1)))))
       (later? f) (two? f && elem <f '(skipx wordx))
       _ (any (nm \ any later? <>>(secs nm)) (st 'order) ?
            (: _ (settle 0)
               t (offs 0)
               (lay f) (<f @ 'skipx ['raw (map (i \ (f 2) & 255) ^(f 3))]
                             'wordx ['raw (gf-le (skv f t) (f 2))]
                             f)
               (foldl (\ _ nm (secs nm @ r
                                 (pin secs nm [<r <>r (filter (f \ !(<f = 'raw && atom? <>f))
                                                              (map (f \ (later? f ? (lay f) f)) <>>r))])))
                      0 (st 'order)))
            0)
       ; an alias lays its label beside its target's, in the target's section
       _ (foldl (\ _ al (: a <al s <>al nm (labs s)
                          (!(string? nm) ? (scare 'gas-alias s)
                             (secs nm @ r
                                (pin labs a nm,
                                 pin secs nm [<r <>r (catmap (f \ (f = ['label (name s)] ? [['label (name a)] f] [f])) <>>r)])))))
                0 (peep st 'alias ()))
       (sec nm) (secs nm @ r [nm <r <>r (rev <>>r)])
       (exec? l) (0 < <>(secs (labs l)) & 4)
       def (filter (l \ string? (labs l)) (rev (st 'globl)))
       [(filter (r \ two? (r 3)) (map sec (rev (st 'order))))
        (filter exec? def) (filter (l \ !(exec? l)) def)])

   ;; -- the front door: TEXT -> IR, by target. --
   (gas-text tgt src)
    (tgt = 'x64 ? (gx-text src)
       (: lc {}
          f (? (tgt = 'a64) ga-line (tgt = 'rv64) gr-line (gthumb? tgt) gt-line (scare 'gas-target tgt))
          (foldl (\ acc ln (acc + f (glocal (gtoks ln) lc))) () (glines src (tgt = 'rv64))))))
) ; module 'holo
