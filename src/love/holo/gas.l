; gas -- the GNU-dialect front for inline asm and file-scope assembly: the text in the syntax
; the target's own toolchain speaks (AT&T on x86, ARM on a64, riscv, thumb), lowered to the
; neutral IR holo.l assembles, so one template serves every compiler. a line lands on a backend
; row where one fits, else on as.l's bytes (x64) or its own word (a64).
;
;   (gas-text tgt src)          ; text -> IR forms, tgt 'x64 'i386 'i386m16 'a64 'rv64 or a thumb
;   (gas-reg tgt r w mod)       ; the dialect's spelling of neutral register r at byte width w
;   (gas-imm tgt n mod)         ; .. of an immediate ("$3" / "3" / "#3")
;   (gas-mem tgt r)             ; .. of a memory operand at register r ("(%rax)" / "[x0]" / "0(a0)")
;   (gas-regname tgt s)         ; the dialect's register name -> the neutral symbol, () if unknown
;
; the template lane carries 64-bit register ops, immediates, base + displacement memory, labels
; local to the template (GNU's `1:` / `1f` / `1b`), and the system lane. x64's 32-bit forms ride
; the 64-bit op plus a zero-extend. a64 lays its own word where the IR's would not be gas's: W
; ops, written-back and indexed addresses, an X op the IR spells longer. a line that fits
; nothing scares, so a typo never drops out. the x64 text is read by dialect.l's att-read; the
; other dialects parse their own lines.

(module 'holo
(: ;; the lexer (gtoks) and the immediate expressions (gimm) are dialect.l's

   ;; a template separates on newline or `;`; `//` comments everywhere, `#` where it is not the
   ;; immediate marker. GNU's numeric local labels resolve before any dialect looks: the k-th
   ;; `N:` becomes the symbol lN.k, `Nf` the next one, `Nb` the last one
   (gcut s c) (: i ((: (g j) (? (j >= #s) -1 (s j = c) j (g (j + 1)))) 0) (i < 0 ? s (snip s 0 i)))
   (gcut2 s c) (: n #s                              ; a doubled c starts a comment, outside a string
      i ((: (g j q) (? (j + 1 >= n) -1 (q && s j = 92) (g (j + 2) q) (s j = 34) (g (j + 1) !q)
                        (!q && s j = c && s (j + 1) = c) j (g (j + 1) q))) 0 0)
      (i < 0 ? s (snip s 0 i)))
   ; a /* */ comment drops, outside a string, its newlines kept
   (gdecom s) (: n #s
      (cend j) (? (j + 1 >= n) n (s j = 42 && s (j + 1) = 47) (j + 2) (cend (j + 1)))
      (go i st q acc) (? (i >= n) (cats (rev (snip s st n . acc)))
                         (q && s i = 92) (go (i + 2) st q acc)
                         (s i = 34) (go (i + 1) st !q acc)
                         (!q && s i = 47 && i + 1 < n && s (i + 1) = 42)
                          (cend (i + 2) @ e (go e e q (" " + string (filter (c \ c = 10) (chars (snip s i e))) . snip s st i . acc)))
                         (go (i + 1) st q acc))
      (go 0 0 0 ()))
   (gsplit s c) (#s @ n
                   ((: (g i st acc) (? (i >= n) (rev (snip s st n . acc))
                                       (s i = c) (g (i + 1) (i + 1) (snip s st i . acc))
                                       (g (i + 1) st acc))) 0 0 ()))
   (glines src hash?) (foldr (\ ln acc (gsplit ln 59 + acc)) ()
                             (map (ln \ (gcut2 ln 47 @ a (hash? ? (gcut a 35) a))) (gsplit (gdecom src) 10)))
   (glabel n k) (name ("l" + show n + "." + show k))
   (glocal toks lc)                                 ; (lref n d) -> (sym), the count tablet updated by defs
    (toks @ (('num n) ('ch 58)) (1 + peep lc n 0 @ k (pin lc n k, [['sym (show (glabel n k))] '(ch 58)]))
          (map (t \ (t @ ('lref n d) ['sym (show (glabel n (d = 102 ? (1 + peep lc n 0) (peep lc n 0))))] t)) toks))
   ;; the operand runs: top-level commas split, parens and brackets nest
   (gops toks) (: (go l d cur acc)
                   (atom? l ? (rev (two? cur ? (rev cur . acc) acc))
                      (<l @ t
                         (? (t = '(ch 40) || t = '(ch 91) || t = '(ch 123)) (go >l (d + 1) (t . cur) acc)
                            (t = '(ch 41) || t = '(ch 93) || t = '(ch 125)) (go >l (d - 1) (t . cur) acc)
                            (t = '(ch 44) && d = 0) (go >l d () (rev cur . acc))
                            (go >l d (t . cur) acc))))
                  (go toks 0 () ()))
   ;; a line is a label (`name:`) or a mnemonic and its operand runs
   (gline toks) (atom? toks ? ()
                   (toks @ (('sym s) ('ch 58)) ['label (name s)]
                           (('sym s) . rest) ['ins (name s) (gops rest)]
                           (scare 'gas-line toks)))

   ;; the register files, dialect name -> neutral (and back)
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
   ; gcc's and clang's other names for x0..x30, which a register variable or clobber may
   ; spell (asm("r0")); asm text keeps llvm-mc's
   a64-ccnames (tablet 0 @ t
                  (foldl (\ _ i (pin t (name ("r" + show i)) (a64-names (name ("x" + show i))))) 0 ^31,
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
                 pin t 'sp 'sp, pin t 'lr 'lr, pin t 'pc 'pc,
                 t))
   (gthumb? tgt) (elem tgt '(thumb2 thumb2sp arm thumb1))
   (gx86? tgt) (elem tgt '(x64 i386 i386m16))   ; AT&T: the x64 lane, i386 through gx-w32
   ; a line `name = expr`: an identifier, one `=` (not `==`), something after it
   (gf-eqset? t) (: e (xa-idx t 61)
                    (0 < e && e + 1 < #t && t (e + 1) != 61 && gf-ident? (xa-trim (snip t 0 e))))
   (g32? tgt) (elem tgt '(i386 i386m16))

   ;; the dialect's spelling of the neutral file, for operand substitution. `mod` is GNU's
   ;; modifier letter (x64 b/w/k/q, a64 w/x) or 0.
   (gas-reg tgt r w mod)
    (? (gx86? tgt)
        (: ns (peep gx-names r ())
           w9 (mod @ 98 1 119 2 107 4 113 8 w)
           (atom? ns || g32? tgt && (w9 = 8 || !(elem r '(r0 r1 r2 r3 sp r4 r5 r6))) ? (scare 'gas-reg r)
              ("%" + ns (w9 @ 1 3 2 2 4 1 0))))
       (tgt = 'a64)
        (: k (r @ 'sp "sp" 'fp "29" 'lr "30" (snip (show r) 1 #(show r)))
           w9 (mod @ 119 4 120 8 w)
           (r = 'sp ? "sp" ((w9 <= 4 ? "w" "x") + k)))
       (tgt = 'rv64) (peep rv-back r () @ s (!s ? (scare 'gas-reg r) (show s)))
       (show r))
   (gas-imm tgt n mod) (: t (charm? n || sun? n ? (show n) n) ; n a number, or a "sym+k" text
                          (? (elem mod '(99 97 80)) t (gx86? tgt) ("$" + t) (gthumb? tgt) ("#" + t) t))
   (gas-mem tgt r) (? (gx86? tgt) ("(" + gas-reg tgt r (g32? tgt ? 4 8) 0 + ")")
                      (tgt = 'rv64) ("0(" + gas-reg tgt r 8 0 + ")")
                      ("[" + gas-reg tgt r 8 0 + "]"))
   (gas-regname tgt s)                              ; gas's own `%rdx` names the register too
    (name (s @ ("%" + r) r s) @ k
       (? (tgt = 'x64) (peep gx-regs k () @ e (two? e ? <e))
          (g32? tgt) (peep gx-regs k () @ e (two? e && <>e < 8 && elem <e '(r0 r1 r2 r3 sp r4 r5 r6) ? <e))
          (tgt = 'a64) (peep a64-names k (peep a64-ccnames k ()))
          (tgt = 'rv64) (peep rv-names k ())
          (peep t32-names k ())))

   ;; x64: att-read's (op mn w ops), destination first, physical registers, lowered here;
   ;; GNU's numeric local labels resolve over the read items first (gx-locals)
   gx-neutral '(r0 r1 r2 r3 sp r4 r5 r6 r7 r8 r9 r10 r11 r12 r13 r14)    ; the neutral file, by encoding
   (gx-r o) (<o = 'rg && <>o < 16 ? (gx-neutral <>o) (scare 'gas-x64-register o))
   (gx-rv o) (<o = 'im ? <>o (gx-r o))                            ; a register or an immediate
   (gx-imm o) (<o = 'im ? <>o (scare 'gas-x64-operand o))
   (gx-mem o) (<o = 'mem && o 1 >= 0 && o 2 < 0 ? [(gx-neutral (o 1)) (o 4)]    ; -> (base disp), no index
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
                   (stc stc) (clc clc) (cmc cmc) (stac stac) (clac clac) (rdpkru rdpkru) (wrpkru wrpkru) (xgetbv xgetbv) (xsetbv xsetbv) (wbinvd wbinvd) (invd invd) (monitor monitor) (mwait mwait) (monitorx monitorx) (mwaitx mwaitx) (rdtscp rdtscp) (rdpmc rdpmc)
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
                   (lldt ((15 0) 2 4)) (push ((255) 6 4)) (pop ((143) 0 4))
                   (prefetchw ((15 13) 1 4)) (prefetchnta ((15 24) 0 4)) (prefetcht0 ((15 24) 1 4))
                   (prefetcht1 ((15 24) 2 4)) (prefetcht2 ((15 24) 3 4))
                   (cmpxchg8b ((15 199) 1 4)) (cmpxchg16b ((15 199) 1 8))))   ; rdx:rax against the memory, rcx:rbx in
   ;; ..and over a register -> (prefix opcode digit width), width 0 the register's own
   gx-rdig (gtab '((sldt (() (15 0) 0 0)) (str (() (15 0) 1 0)) (lldt (() (15 0) 2 4))
                   (verr (() (15 0) 4 4)) (verw (() (15 0) 5 4))
                   (rdfsbase ((243) (15 174) 0 0)) (rdgsbase ((243) (15 174) 1 0))
                   (wrfsbase ((243) (15 174) 2 0)) (wrgsbase ((243) (15 174) 3 0))
                   (rdrand (() (15 199) 6 0)) (rdseed (() (15 199) 7 0))))
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
   ; address (`%gs:sym`, `%gs:40`) loads through its destination: the address, then the word
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
          ; the descriptor tables at a width: lgdtl in a 16-bit segment takes 66, the whole 32-bit base
          (elem m '(lgdtl lidtl sgdtl sidtl lgdtw lidtw sgdtw sidtw))
           (: t (show m) st (snip t 0 4)
              (gx-mem d @ bm [['mdig [15 1] (st @ "sgdt" 0 "sidt" 1 "lgdt" 2 3) (t 4 = 119 ? 2 4) <bm <>bm]]))
          ; a segment register pushed or popped, at the suffix's width (i386's; the 64-bit map
          ; keeps fs and gs alone)
          (elem m '(push pop) && <d = 'sr) [[(m @ 'push 'pushseg 'popseg) <>d (w0 > 0 ? w0 4)]]
          ; a far call or jump through memory, the segment:offset pointer there (FF /3, FF /5);
          ; the immediate forms are i386's alone, and gas-nolong refuses them
          ((elem m '(lcall lcallw lcalll ljmp ljmpw ljmpl)) && <d = 'ind)
           (gx-mref <>d @ bm [['mdig [255] (elem m '(lcall lcallw lcalll) ? 3 5)
                                (elem m '(lcallw ljmpw) ? 2 4) <bm <>bm]])
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
          ; a segment's access rights and limit, by its selector
          (elem m '(lar lsl lsll larl))
           (<d = 'rg && <s = 'rg ? [['rrop [15 (elem m '(lar larl) ? 2 3)] (w0 > 0 ? w0 (d 2)) (gx-r d) (gx-r s)]]
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
                     ; a symbol's word (`sym`, `sym(%rip)`): its address, then the load
                     (<s = 'lbl || <s = 'rip && nom? <>s) (<>(gx-mref s) @ so [['la x <so] [(gx-lop w) x x <>so]])
                     (scare 'gas-x64-operand s)))
              (<d = 'mem)
               (gx-mem d @ bm
                  (? (<s = 'rg) [[(gx-sop w) <bm <>bm (gx-r s)]]
                     (<s = 'im) [[(gx-iop w) <bm <>bm <>s]]
                     (scare 'gas-x64-operand s)))
              (scare 'gas-x64-operand d))
          (m = 'lea)
           (? ; no symbol: an address relative to this lea's end -- its own bytes, REX.W 8D,
              ; modrm rm=101 over the displacement; nothing for a fix to name
              (<s = 'rip && !(nom? <>s) && <d = 'rg)
               (<>d @ n [['raw ([(72 | (n >= 8 ? 4 0)) 141 ((n & 7) << 3 | 5)] + gf-le <>>s 4)]])
              (<s = 'rip && <>>s = 0) [['la (gx-r d) <>s]]
              (<s = 'rip && nom? <>s) [['la (gx-r d) <>s] ['lea (gx-r d) (gx-r d) <>>s]]   ; sym+k: lea keeps the flags too
              (<s = 'mem) (gx-mem s @ bm [['lea (gx-r d) <bm <>bm]])
              (scare 'gas-x64-operand ops))
          ; an ALU op of a register and a word in memory (`adcq 8(%rsi),%rax`)
          (elem m '(add or adc sbb and sub xor cmp) && <d = 'rg && elem <s '(mem lbl rip))
           (gx-mref s @ bm [['alurm m (w0 > 0 ? w0 (d 2)) (gx-r d) <bm <>bm]])
          ; add and subtract with the carry, a register at the far end (`sbb %0,%0`)
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
                      (scare 'gas-x64-line it))
   ; an inline template's line: the template lane, and as.l's bytes where it has no row (the
   ; vector rows -- pshufb, sha256rnds2). an operand the template refuses stays refused
   (gx-text src)
    (catmap (it \ (<it = 'op ? (trap gx-item it (\ a b (a = 'gas-x64-op ? (trap (i \ [['raw (as-instr i)]]) it (\ _ _ (scare a b)))
                                                       (scare a b))))
                     (gx-item it)))
            (gx-locals (att-read src)))
   ;; ..i386's: the template lane alone (as.l's bytes are 64-bit encodings), then gx-w32
   (gx-text32 src)
    (catmap (it \ (<it = 'op ? (trap gx-item it (\ a b (a = 'gas-x64-op ? (scare 'gas-i386-op b) (scare a b))))
                     (gx-item it)))
            (gx-locals (att-read src)))
   ;; the x64 lane's forms at i386's word: 4 bytes is the whole register, so the 32-bit forms
   ;; lose their zero-extension and take the plain names; an 8-byte form, a register past edi,
   ;; and raw bytes (64-bit encodings) have no i386 meaning and refuse
   gx-w8 '(alum unm btm testm xaddm cmpxchgm xchgm carry bscan movntim)
   gx-ren (gtab '((ldu4 ld) (st4 st) (si4 si)))
   (gx-w32 fs)
    (: (reg? x) (name? x && elem x '(r7 r8 r9 r10 r11 r12 r13 r14))
       (bad? f) (? (elem <f '(ld st si divq raw)) 1
                   (elem <f gx-w8) (f (elem <f '(alum unm btm carry bscan) ? 2 1) = 8)
                   (<f = 'mdig) (f 3 = 8)
                   (<f = 'rdig) (f 4 = 8)
                   0)
       (catmap (f \ (? (<f = 'zx4) ()
                       (bad? f || any reg? >f) (scare 'gas-i386-form f)
                       (ghas? gx-ren <f) [((gx-ren <f) . >f)]
                       [f]))
               fs))
   ;; ..and a file-scope run (an assembly source's): encoded exactly by as.l -- the width it says,
   ;; any addressing, the flags a 32-bit op sets -- and lowered as a template only where as.l
   ;; has no row (the system lane)
   (gx-exact src) (gx-exactm 64 'x64 src)
   ;; ..in a segment of md bits (.code16/.code32/.code64): as.l at that mode; the template lane
   ;; takes over only in the object's own mode, whose backend lays it
   (gx-md tgt) (tgt @ 'i386 32 'i386m16 16 64)
   (gx-exactm md tgt src)
    ; both refusing, as.l's word stands: it names the instruction, the template lane an operand
    (catmap (it \ (<it = 'op ? (trap (i \ [['raw (as-instrm md i)]]) it
                                (\ a b (md != gx-md tgt ? (scare a b)
                                         (trap (i \ (g32? tgt ? (gx-w32 (gx-item i)) (gx-item i))) it (\ _ _ (scare a b))))))
                     (gx-item it)))
            (gx-locals (att-read src)))

   ;; a64, the ARM dialect: dst first, xN/wN/sp/xzr, #imm, [base, #off], b.cond.
   ;; operands: (reg rN w) | (imm n) | (mem base off) | (memw base off), pre-indexed |
   ;; (memx base idx option shift) | (sym s) -- a sysreg, an option, a label. what the IR's
   ;; 64-bit rows cannot say -- a W-register op, a written-back or indexed address, `ret xN`, an
   ;; X op they would spell in two words -- lands as gas's own word; an unread operand scares.
   (ga-reg s) (name s @ k
                 (? (nom? (peep a64-names k ())) ['reg (a64-names k) 8]
                    (elem k '(fp lr)) ['reg k 8]               ; llvm-mc's names for x29 and x30
                    (k = 'wzr || k = 'w31) ['reg 'zr 4]           ; llvm-mc reads x31 and w31 as zr
                    (k = 'x31) ['reg 'zr 8]
                    (k = 'wsp) ['reg 'sp 4]
                    (#s > 1 && s 0 = 119 && digit? (s 1))
                     (peep a64-names (name ("x" + snip s 1 #s)) () @ r (nom? r ? ['reg r 4] ()))
                    ()))
   ga-exts {'uxtw 2 'lsl 3 'sxtw 6 'sxtx 7}
   ;; a shift (0-3) or an extend (8 + option) by name; a bare extend is its own `#0`
   ga-shx {'lsl 0 'lsr 1 'asr 2 'ror 3 'uxtb 8 'uxth 9 'uxtw 10 'uxtx 11 'sxtb 12 'sxth 13 'sxtw 14 'sxtx 15}
   (ga-index b ps toks)                             ; [b, rM{, lsl|uxtw|sxtw|sxtx {#s}}]
    (: i (<ps @ (('sym m)) (ga-reg m) ())
       ex (two? >ps ? <>ps ())
       o (ex @ (('sym e) . _) (peep ga-exts (name e) ()) (atom? ex ? 3 ()))
       s (ex @ (('sym _) . ('ch 35) . v) (gimm v) -1)
       (#ps > 2 || !(charm? o) || <>>i != (o & 1 ? 8 4) ? (scare 'gas-a64-operand toks)
          ['memx b <>i o s]))
   (ga-opnd toks)
    (toks @ (('sym ".") . rest) ['dot (two? rest ? (gimm rest) 0)]   ; `.`, `.+k`: this instruction's own place
            (('ch 35) . ('ch 58) . rest) (ga-opnd >toks)
            (('ch 58) . ('sym g) . ('ch 58) . rest) ['grp (name g) rest]   ; :abs_g1_s:val, one 16-bit group
            (('ch 35) . rest) ['imm (gimm rest)]
            (('num _) . _) ['imm (gimm toks)]
            (('ch 40) . _) ['imm (gimm toks)]
            (('ch 45) . _) ['imm (gimm toks)]
            (('sym s)) (ga-reg s @ r (two? r || nom? r ? r ['sym (name s)]))
            (('ch 91) ('sym b) ('ch 93)) (ga-reg b @ ('reg x 8) ['mem x 0] _ (scare 'gas-a64-operand toks))
            (('ch 91) ('sym b) ('ch 93) ('ch 33)) (ga-reg b @ r (two? r ? ['wbm <>r <>>r] (scare 'gas-a64-operand toks)))
            (('sym b) ('ch 33)) (ga-reg b @ r (two? r ? ['wbr <>r <>>r] (scare 'gas-a64-operand toks)))
            (('sym s) ('ch 91) ('num i) ('ch 93)) ['vel (name s) i]     ; vN.<T>[i], one vector lane
            (('ch 123) . rest) ['vlist rest]                          ; { vA.T, vB.T } or { vA.T - vB.T }
            (('sym s) . rest)                                       ; `lsr #3`, `lsr 3`, `sxtw #2`: a shift or extend
             (peep ga-shx (name s) () @ k (? (charm? k) ['shx k (rest @ (('ch 35) . v) (gimm v) _ (gimm rest))]
                                             (elem <rest '((ch 43) (ch 45))) ['symk (name s) (gimm rest)]   ; sym+k
                                             (name s = 'msl) ['msl (rest @ (('ch 35) . v) (gimm v) _ (gimm rest))]   ; movi's ones-shift
                                             (scare 'gas-a64-operand toks)))
            (('ch 91) . ('sym b) . ('ch 44) . rest)
             (: wb (two? rest && <(rev rest) = '(ch 33))            ; `]!`, pre-indexed
                body (wb ? (rev >(rev rest)) rest)
                r (ga-reg b) n #body
                (atom? r || <>>r != 8 || n < 2 || !(body (n - 1) = '(ch 93)) ? (scare 'gas-a64-operand toks)
                   (gops (rev >(rev body)) @ ps
                      (? (ps @ ((('sym s)) . _) (two? (ga-reg s)) 0)
                          (wb ? (scare 'gas-a64-operand toks) (ga-index <>r ps toks))
                         (#ps > 1) (scare 'gas-a64-operand toks)
                         (ga-opnd <ps @ ('grp g ts) (wb ? (scare 'gas-a64-operand toks) ['meml <>r g ts])   ; [b, :lo12:sym]
                                        o [(wb ? 'memw 'mem) <>r <>o])))))
            (scare 'gas-a64-operand toks))
   (ga-r o) (o @ ('reg x _) x (scare 'gas-a64-register o))
   (ga-rw o) (o @ ('reg x w) [x w] (scare 'gas-a64-register o))
   (ga-v o) (o @ ('imm n) n ('reg x _) x (scare 'gas-a64-operand o))   ; a register or an immediate
   ;; a system register moves through an x register or xzr, never sp or a w
   (ga-xt m os i) ((os i) @ ('reg r 8) (r != 'sp ? r (scare 'gas-a64-operand [m os])) _ (scare 'gas-a64-operand [m os]))
   (ga-hw r) (r @ 'sp 31 'zr 31 'fp 29 'lr 30 (xa-num (snip (show r) 1 #(show r))))
   (ga-raw w) [['raw (le32 w)]]
   ;; a branch to `.+k` is its own pc-relative word, no label: k in words, n bits wide
   (ga-dot o) (o @ ('dot k) k ())
   (ga-off k n) (: q (k // 4) h (1 << (n - 1))
                   (? (k % 4 != 0 || q < 0 - h || q >= h) (scare 'gas-a64-branch k) (q & ((1 << n) - 1))))
   ;; 4 when an op's registers are all W, 8 when all X; a mix is no instruction
   (ga-wide os) (: ws (filter (w \ w > 0) (map (o \ o @ ('reg _ w) w 0) os))
                   (? (all (w \ w = 4) ws) (two? ws ? 4 8) (all (w \ w = 8) ws) 8 (scare 'gas-a64-width os)))
   ga-cc (gtab '((eq eq) (ne ne) (cs ae) (hs ae) (cc below) (lo below) (mi s) (pl ns)
                 (vs vs) (vc vc) (hi above) (ls be) (ge ge) (lt lt) (gt gt) (le le)))
   ga-nils (gtab '((nop nop) (wfi wfi) (wfe wfe) (isb isb) (eret eret) (ret ret)))
   ga-alu (gtab '((add add) (sub sub) (and and) (orr or) (eor xor) (adds adds) (subs subs)))
   ga-exc (gtab '((brk brk) (hvc hvc) (smc smc) (udf udf) (hlt dbrk)))
   ga-sys '(tlbi ic dc at)
   ga-ld (gtab '((ldr (ld ldu4)) (ldrb (ldu1 ldu1)) (ldrh (ldu2 ldu2)) (ldrsb (ld1 ld1)) (ldrsh (ld2 ld2)) (ldrsw (ld4 ld4))))
   ga-st (gtab '((str (st st4)) (strb (st1 st1)) (strh (st2 st2))))
   ga-sh (gtab '((lsl shl) (lsr shr) (asr sar) (ror ror)))
   ga-arity {'mov 2 'cmp 2 'tst 2 'neg 2 'mvn 2 'mrs 2 'msr 2
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
   (ga-wimm z m d n v)                              ; the immediate word at width z
    (? (nom? (peep ga-flip m ()))
        (: f (v < 0 ? (ga-flip m) m) u (v < 0 ? (0 - v) v) b ((z = 64 ? 0x80000000 0) | <>(ga-walu f))
           (? (n = 31 || d = 31 && elem m '(add sub)) (scare 'gas-a64-operand [m v])   ; 31 would be wsp
              (u <= 4095) (b | u << 10 | n << 5 | d)
              (u % 4096 = 0 && u >> 12 <= 4095) (b | 1 << 22 | (u >> 12) << 10 | n << 5 | d)
              (scare 'imm12-range v)))
       (ga-bm v z @ f (!(charm? f) || d = 31 && m != 'ands ? (scare 'a64-bitmask-imm v)
                         ((z = 64 ? 0x80000000 0) | <>(ga-walu m) | f | n << 5 | d))))
   ;; mov rD, #v in one word as gas picks it -- movz, movn, else an orr bitmask -- or ()
   (ga-movi z d v)
    (: top ((1 << z) - 1) u (u64 v % (1 << z)) n (u ^ top) sf (z = 64 ? 0x80000000 0)
       (lanes x) (filter (h \ (x >> (16 * h)) % 65536 != 0) ^(z // 16))
       (wide base x l) (: h (two? l ? <l 0) (sf | base | h << 21 | ((x >> (16 * h)) % 65536) << 5 | d))
       (? (#(lanes u) <= 1) (wide 0x52800000 u (lanes u))
          (#(lanes n) <= 1) (wide 0x12800000 n (lanes n))
          (ga-bm u z @ f (charm? f ? (sf | 0x320003E0 | f | d) ()))))
   (ga-sp? o) (o @ ('reg x _) (x = 'sp) 0)
   (ga-irimm? m v) (nom? (peep ga-flip m ()) ? (-4095 <= v <= 4095) (charm? (ga-bm v 64)))   ; the IR lays it in one word
   (ga-dp m os z)                                   ; a data op laid as its own word, z bits wide
    (: k #os (r i) (ga-hw (ga-r (os i))) sf (z = 64 ? 0x80000000 0) top (z - 1)
       (? (m = 'mov) ((os 1) @ ('imm v) (ga-movi z (r 0) v @ w (charm? w ? (ga-raw w) (scare 'gas-a64-mov-imm v)))
                                (ga-raw (0x2A0003E0 | r 1 << 16 | r 0)))
          (m = 'neg) (ga-raw (sf | 0x4B0003E0 | r 1 << 16 | r 0))
          (m = 'mvn) (ga-raw (sf | 0x2A2003E0 | r 1 << 16 | r 0))
          (elem m '(cmp tst))
           (: op (m = 'cmp ? 'subs 'ands)
              ((os 1) @ ('imm v) (ga-raw (ga-wimm z op 31 (r 0) v))
                        (ga-raw (<(ga-walu op) | r 1 << 16 | r 0 << 5 | 31))))
          (k != 3) (scare 'gas-a64-operand os)
          (two? (peep ga-walu m ()))
           ((os 2) @ ('imm v) (ga-raw (ga-wimm z m (r 0) (r 1) v))
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
   ;; the multiply-adds, [word operands]: d n m and an addend, zr where an alias leaves it off; the
   ;; long ones take W factors into X, the high halves are X throughout
   ga-mla {'madd [0x1B000000 4] 'msub [0x1B008000 4] 'mul [0x1B000000 3] 'mneg [0x1B008000 3]
           'smaddl [0x9B200000 4] 'smsubl [0x9B208000 4] 'umaddl [0x9BA00000 4] 'umsubl [0x9BA08000 4]
           'smull [0x9B200000 3] 'smnegl [0x9B208000 3] 'umull [0x9BA00000 3] 'umnegl [0x9BA08000 3]
           'smulh [0x9B400000 3] 'umulh [0x9BC00000 3]}
   (ga-mul m os)
    (ga-mla m @ (b n)
     (: ws (map (o \ o @ ('reg r w) (r = 'sp ? 0 w) _ 0) os) w <ws
        lg (elem m '(smaddl smsubl umaddl umsubl smull smnegl umull umnegl))
        want (? lg (n = 4 ? [8 4 4 8] [8 4 4]) (elem m '(smulh umulh)) [8 8 8] (map (_ \ w) ws))
        (r i) (ga-hw (<>(os i)))
        (? (#os != n || !(w = 4 || w = 8) || ws != want) (scare 'gas-a64-operand [m os])
           (ga-raw (b | (w = 8 && b < 0x80000000 ? 0x80000000 0) | r 2 << 16 | (n = 4 ? (r 3) 31) << 10 | r 1 << 5 | r 0)))))
   ;; a load or store's unscaled word, X target then W; the access size rides bits [31:30]
   ga-ldst {'ldr [0xF8400000 0xB8400000] 'ldrb [() 0x38400000] 'ldrh [() 0x78400000]
            'ldrsb [0x38800000 0x38C00000] 'ldrsh [0x78800000 0x78C00000] 'ldrsw [0xB8800000 ()]
            'str [0xF8000000 0xB8000000] 'strb [() 0x38000000] 'strh [() 0x78000000]}
   (ga-wb lb ix t b v)                              ; post- (ix 1) or pre-indexed (ix 3): imm9, the base written back
    (charm? v && -256 <= v <= 255 ? (ga-raw (lb | (v & 511) << 12 | ix << 10 | ga-hw b << 5 | t))
       (scare 'gas-a64-operand v))
   ;; a symbol and its addend, from `sym` or `sym+k`
   (ga-sym o) (o @ ('sym s) [s 0] ('symk s k) [s k] _ (scare 'gas-a64-operand o))
   (ga-symts ts) (ga-sym (ga-opnd ts))
   ;; adrp to a symbol's page, adr to its byte, and add's :lo12: of it: address fixes, the addend aboard
   (ga-adrp m os) (? (#os != 2) (scare 'gas-a64-operand [m os])
                     (ga-rw (os 0) @ (r w) (w != 8 || r = 'sp ? (scare 'gas-a64-operand [m os])
                                              (ga-dot (os 1) @ d
                                                 ; adr to `.+k` is k itself, in bytes
                                                 (? (m = 'adr && charm? d)
                                                     (-1048576 <= d < 1048576 ?
                                                        (d & 2097151 @ u (ga-raw (0x10000000 | (u & 3) << 29 | (u >> 2) << 5 | ga-hw r)))
                                                        (scare 'gas-a64-operand [m os]))
                                                    (ga-sym (os 1) @ (s k)
                                                       (m = 'adr ? [['afix 'adr21 (0x10000000 | ga-hw r) s k]]
                                                          [['afix 'adrp21 (0x90000000 | ga-hw r) s k]])))))))
   (ga-addlo os)
    (: d (ga-rw (os 0)) n (ga-rw (os 1))
       (? (<>d != 8 || <>n != 8 || <d = 'zr || <n = 'zr) (scare 'gas-a64-operand ['add os])
          ((os 2) @ ('grp 'lo12 ts) (ga-symts ts @ (s k) [['afix 'addlo12 (0x91000000 | ga-hw <n << 5 | ga-hw <d) s k]])
                    _ (scare 'gas-a64-operand ['add os]))))
   (ga-ls m os)
    (: k #os rw (ga-rw (os 0)) t (ga-hw <rw) row (ga-ldst m) lb (<>rw = 8 ? <row <>row)
       lg (charm? lb ? (lb >> 30) 0)
       st? (elem m '(str strb strh))
       ir? (<rw != 'zr && (<>rw = 8 || !(elem m '(ldrsb ldrsh))))   ; the IR's rows say all but zr and a W sign-extend
       bs ((os 1) @ ('mem b _) b ('memw b _) b ('meml b _ _) b ('memx b _ _ _) b _ ())
       (? (!(charm? lb)) (scare 'gas-a64-width os)
          (bs = 'zr || <rw = 'sp) (scare 'gas-a64-operand os)   ; 31 is sp in a base, zr in a data register
          ; written back onto the register it moves: unpredictable, so refused
          ((k = 3 || ((os 1) @ ('memw _ _) 1 _ 0)) && bs = <rw) (scare 'gas-a64-unpredictable os)
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
             ('meml b g ts)                                   ; [b, :lo12:sym]: the scaled imm12 fixed by the access size
              (g != 'lo12 ? (scare 'gas-a64-operand os)
                 (ga-symts ts @ (s n) [['afix (lg @ 0 'lo12s1 1 'lo12s2 2 'lo12s4 'lo12s8)
                                        (lb | 0x01000000 | ga-hw b << 5 | t) s n]]))
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
   ;; the exclusive pairs and casp, [X W] by the data's width: ldxp t, t2, [n]; stxp s, t, t2, [n],
   ;; its w status never a data register nor a base but sp; casp s, s+1, t, t+1, [n], each an
   ;; even/odd pair. data never sp, a base never zr, the address bare
   ga-xp {'ldxp [0xC87F0000 0x887F0000] 'ldaxp [0xC87F8000 0x887F8000]}
   ga-sxp {'stxp [0xC8200000 0x88200000] 'stlxp [0xC8208000 0x88208000]}
   ga-casp {'casp [0x48207C00 0x08207C00] 'caspa [0x48607C00 0x08607C00]
            'caspl [0x4820FC00 0x0820FC00] 'caspal [0x4860FC00 0x0860FC00]}
   (ga-xpd m os i w) ((os i) @ ('reg r w2) (w2 = w && r != 'sp ? (ga-hw r) (scare 'gas-a64-operand [m os]))
                               _ (scare 'gas-a64-operand [m os]))
   (ga-xpb m os) ((os (#os - 1)) @ ('mem x 0) (x != 'zr ? (ga-hw x) (scare 'gas-a64-operand [m os]))
                                   _ (scare 'gas-a64-operand [m os]))
   (ga-xp-ins m row os)
    (: k #os w (<>(ga-rw (os (k - 3)))) b (w = 8 ? <row <>row)
       t (ga-xpd m os (k - 3) w) t2 (ga-xpd m os (k - 2) w) n (ga-xpb m os)
       (? (k = 3) (ga-raw (b | t2 << 10 | n << 5 | t))
          (: st (ga-xpd m os 0 4)
             (? (st = t || st = t2 || (st = n && (os 3) != ['mem 'sp 0])) (scare 'gas-a64-unpredictable [m os])
                (ga-raw (b | st << 16 | t2 << 10 | n << 5 | t))))))
   (ga-casp-ins m row os)
    (: w (<>(ga-rw <os)) b (w = 8 ? <row <>row)
       r (map (i \ ga-xpd m os i w) ^4) n (ga-xpb m os)
       (? ((r 0) & 1 || (r 1) != (r 0) + 1 || (r 2) & 1 || (r 3) != (r 2) + 1) (scare 'gas-a64-operand [m os])
          (ga-raw (b | (r 0) << 16 | n << 5 | (r 2)))))
   ;; the memory copy and set ops (mops) by spelling: cpy|cpyf|set|setg, a stage p|m|e, then
   ;; the variant -> (kind bit26 stage op2); a copy's [d]!, [s]!, n!, a set's [d]!, n!, v,
   ;; every one an X register and no two the same
   ga-cpyv ["" "wt" "rt" "t" "wn" "wtwn" "rtwn" "twn" "rn" "wtrn" "rtrn" "trn" "n" "wtn" "rtn" "tn"]
   (ga-mops m)
    (: s (show m)
       (rest t n) (snip t n #t)
       (ix l v k) (? (atom? l) () (<l = v) k (ix >l v (k + 1)))
       hd (? (starts? s "cpyf") ['cpy 0 (rest s 4)] (starts? s "cpy") ['cpy 0x04000000 (rest s 3)]
             (starts? s "setg") ['set 0x04000000 (rest s 4)] (starts? s "set") ['set 0 (rest s 3)] ())
       t (two? hd ? (hd 2) "")
       g (t = "" ? () (assoc (t 0) [[112 0] [109 1] [101 2]]))
       v (two? g ? (ix (<hd = 'cpy ? ga-cpyv ["" "t" "n" "tn"]) (rest t 1) 0) ())
       (? !(charm? v) () (<hd = 'cpy) [<hd (hd 1) <>g v] [<hd (hd 1) 0 (<>g << 2 | v)]))
   (ga-mops-ins m row os)
    (row @ (kind b g op)
       (: sh (map (o \ o @ ('wbm _ 8) 'm ('wbr _ 8) 'r ('reg _ 8) 'g _ ()) os)
          xs (map (o \ o @ ('wbm x _) x ('wbr x _) x ('reg x _) x _ ()) os)
          cp (kind = 'cpy)
          (? (sh != (cp ? ['m 'm 'r] ['m 'r 'g]) || elem 'sp xs || elem 'zr (cp ? [<xs <>xs] [<xs]))
              (scare 'gas-a64-operand [m os])
             (map ga-hw xs @ (d u n)
                (? (d = u || u = n || d = n) (scare 'gas-a64-operand [m os])
                   cp (ga-raw (0x19000400 | b | g << 22 | u << 16 | op << 12 | n << 5 | d))
                   (ga-raw (0x19C00400 | b | n << 16 | op << 12 | u << 5 | d)))))))
   ;; the pair loads and stores, (load? kind) by spelling, kind 'p plain, 'n no-allocate, 'sw ldpsw.
   ;; a data register -> (V opc scale number): x, w, or a vector s/d/q. the address an offset,
   ;; pre-indexed ([b, #k]!) or post-indexed ([b], #k), its offset scaled into imm7
   ga-pair {'ldp [1 'p] 'stp [0 'p] 'ldnp [1 'n] 'stnp [0 'n] 'ldpsw [1 'sw]}
   (ga-preg o)
    (o @ ('reg 'sp _) () ('reg x 8) [0 2 8 (ga-hw x)] ('reg x 4) [0 0 4 (ga-hw x)]
         ('sym v) (: t (show v) n (xa-num (snip t 1 #t)) e (assoc (t 0) [[115 0 4] [100 1 8] [113 2 16]])
                     (two? e && #t > 1 && all digit? (chars (snip t 1 #t)) && 0 <= n <= 31 ? [1 (e 1) (e 2) n] ()))
         _ ())
   (ga-pair-ins m os)
    (: k #os pr (ga-pair m) ld <pr kd <>pr
       a (ga-preg (os 0)) b (ga-preg (os 1))
       ad (? (k = 3) ((os 2) @ ('mem r n) [2 r n] ('memw r n) [3 r n] _ ())
             (k = 4) ([(os 2) (os 3)] @ (('mem r 0) ('imm n)) [1 r n] _ ())
             ())
       (bad _) (scare 'gas-a64-operand [m os])
       (? (!(two? a) || !(two? ad) || <a != <b || <>a != <>b) (bad 0)
          (ad @ (ty r n)
             (: z (kd = 'sw ? 4 (a 2)) q (n // z) rn (ga-hw r) wb (ty != 2)
                (? (r = 'zr || n % z != 0 || !(-64 <= q <= 63)
                    || (kd = 'n && wb) || (kd = 'sw && (<a != 0 || <>a != 2))
                    || (ld && a 3 = b 3) || (wb && <a = 0 && r != 'sp && (rn = a 3 || rn = b 3)))
                    (bad 0)
                   (ga-raw ((kd = 'sw ? 1 <>a) << 30 | 0x28000000 | <a << 26 | (kd = 'n ? 0 ty) << 23 | ld << 22
                            | (q & 127) << 15 | b 3 << 10 | rn << 5 | a 3)))))))
   (ga-shxof o) (o @ ('shx k a) [k a] ('sym e) (peep ga-shx e () @ k (charm? k && k >= 8 ? [k 0] ())) _ ())
   ;; the register ops a shifted or extended operand (or #imm, lsl #12) can close: arith (0) with its
   ;; register and immediate words, or logical (1); the aliases fill a zr for rd or rn
   ga-shop {'add [0 0x0B000000 0x11000000] 'adds [0 0x2B000000 0x31000000] 'sub [0 0x4B000000 0x51000000]
            'subs [0 0x6B000000 0x71000000] 'and [1 0x0A000000] 'bic [1 0x0A200000] 'orr [1 0x2A000000]
            'orn [1 0x2A200000] 'eor [1 0x4A000000] 'eon [1 0x4A200000] 'ands [1 0x6A000000] 'bics [1 0x6A200000]}
   ga-shal {'cmp ['subs 'd] 'cmn ['adds 'd] 'tst ['ands 'd] 'neg ['sub 'n] 'negs ['subs 'n] 'mvn ['orn 'n]}
   (ga-shifted m os)
    (: k #os al (peep ga-shal m ()) sh (ga-shxof (os (k - 1)))
       (bad _) (scare 'gas-a64-operand [m os])
       (zr o) (o @ ('reg _ w) ['reg 'zr w] _ ['reg 'zr 8])
       (? (two? al)
           (? (k != 3) (bad 0)
              (al 1 = 'd) (ga-sh3 m <al (zr (os 0)) (os 0) (os 1) sh)
              (os 1 @ ('reg _ _) (ga-sh3 m <al (os 0) (zr (os 0)) (os 1) sh) _ (bad 0)))
          (two? (peep ga-shop m ())) (k = 4 ? (ga-sh3 m m (os 0) (os 1) (os 2) sh) (bad 0))
          (bad 0)))
   (ga-sh3 m op d n r sh)
    (: row (ga-shop op) ar (<row = 0) s? (elem op '(adds subs ands bics))
       dd (ga-rw d) nn (ga-rw n) z <>dd sf (z = 8 ? 0x80000000 0) top (z = 8 ? 64 32)
       k <sh a <>sh hd (ga-hw <dd) hn (ga-hw <nn)
       rdbad (s? ? (<dd = 'sp) (<dd = 'zr))                 ; 31 in rd is zr when flags are set, else sp
       (bad _) (scare 'gas-a64-operand [m sh])
       (? (<>nn != z) (bad 0)
          (r @ ('imm v0)
             (: up (a = 0 && v0 > 4095 && v0 % 4096 = 0)       ; gas lays #4096, lsl #0 as #1, lsl #12
                v (up ? (v0 >> 12) v0) a (up ? 12 a)
                (? (!ar || k != 0 || !(a = 0 || a = 12) || !(0 <= v <= 4095) || <nn = 'zr || rdbad) (bad 0)
                   (ga-raw (sf | row 2 | (a = 12 ? 0x400000 0) | v << 10 | hn << 5 | hd))))
             ('reg x w)
             (? (k >= 8 || (k = 0 && ar && (<dd = 'sp || <nn = 'sp)))
                 (: o (k >= 8 ? (k - 8) (z = 8 ? 3 2)) xr (o & 3 = 3)
                    (? (!ar || !(0 <= a <= 4) || x = 'sp || <nn = 'zr || rdbad || (z = 8 ? ((w = 8) != xr) (w != 4))) (bad 0)
                       (ga-raw (sf | row 1 | 0x200000 | ga-hw x << 16 | o << 13 | a << 10 | hn << 5 | hd))))
                (? (x = 'sp || <dd = 'sp || <nn = 'sp || w != z || (ar && k = 3) || !(0 <= a < top)) (bad 0)
                   (ga-raw (sf | row 1 | k << 22 | ga-hw x << 16 | a << 10 | hn << 5 | hd))))
             _ (bad 0))))
   ;; the wide moves: a 16-bit immediate at lsl #0/16/32/48 (W: 0/16)
   ga-movw {'movn 0x12800000 'movz 0x52800000 'movk 0x72800000}
   ;; ..or a constant's group by name: abs_gN its Nth 16 bits, checked unsigned; _nc unchecked;
   ;; _s checked signed, and on movz a negative value lays the movn of its complement
   ga-grps {'abs_g0 [0 'u] 'abs_g1 [1 'u] 'abs_g2 [2 'u] 'abs_g3 [3 'u] 'abs_g0_nc [0 'nc] 'abs_g1_nc [1 'nc]
            'abs_g2_nc [2 'nc] 'abs_g0_s [0 's] 'abs_g1_s [1 's] 'abs_g2_s [2 's]}
   (ga-movg m rw g ts)
    (: e (peep ga-grps g ()) z <>rw
       (bad _) (scare 'gas-a64-operand [m g])
       (? (!(two? e) || <rw = 'sp || (z = 4 && <e > 1)) (bad 0)
          (gtoks? ts) (scare 'gas-a64-movw-symbol [m g])
          (: v (gimm ts) n <e top (1 << (16 * (n + 1))) ng (<>e = 's && m = 'movz && v < 0)
             f ((u64 (ng ? (v ^ -1) v) >> (16 * n)) & 65535)
             (? (<>e = 'u && !(0 <= v < top) && n < 3) (bad 0)
                (<>e = 's && (m != 'movz || !(0 - top < v < top))) (bad 0)   ; the lower edge out
                (ga-raw ((z = 8 ? 0x80000000 0) | ga-movw (ng ? 'movn m) | n << 21 | f << 5 | ga-hw <rw))))))
   (gtoks? ts) (any (t \ t @ ('sym _) 1 _ 0) ts)            ; a symbol in the run: a relocation, not a constant
   (ga-movw-ins m os)
    (: k #os rw (ga-rw (os 0)) z <>rw sh (k = 3 ? (ga-shxof (os 2)) [0 0])
       (? ((os 1) @ ('grp _ _) 1 _ 0) (k = 2 ? ((os 1) @ ('grp g ts) (ga-movg m rw g ts)) (scare 'gas-a64-operand [m os]))
          (<rw = 'sp || !(k = 2 || k = 3) || !(two? sh) || <sh != 0 || <>sh % 16 != 0 || !(0 <= <>sh < 8 * z))
           (scare 'gas-a64-operand [m os])
          ((os 1) @ ('imm v) (0 <= v <= 65535 ? (ga-raw ((z = 8 ? 0x80000000 0) | ga-movw m | (<>sh // 16) << 21 | v << 5 | ga-hw <rw))
                                 (scare 'gas-a64-operand [m os]))
                    _ (scare 'gas-a64-operand [m os]))))
   ;; the conditionals: a condition by name -> its 4-bit field, al and nv among them
   (ga-cond o) (o @ ('sym c) (: n (name c) (? (n = 'al) 14 (n = 'nv) 15 (nom? (peep ga-cc n ())) (arm-cc (ga-cc n)) ())) _ ())
   ;; the conditional selects, and their aliases (register count, base) that invert the condition
   ga-csel {'csel 0x1A800000 'csinc 0x1A800400 'csinv 0x5A800000 'csneg 0x5A800400}
   ga-csal {'cset [0 'csinc] 'csetm [0 'csinv] 'cinc [1 'csinc] 'cinv [1 'csinv] 'cneg [1 'csneg]}
   (ga-cs-ins m os)
    (: k #os al (peep ga-csal m ()) c (ga-cond (os (k - 1)))
       rs (map ga-rw (take (k - 1) os))
       (bad _) (scare 'gas-a64-operand [m os])
       (? (!(charm? c) || any (r \ <r = 'sp || <>r != <>(rs 0)) rs) (bad 0)
          (two? al)
           (? (k != 2 + <al || c >= 14) (bad 0)
              (: d <(rs 0) n (<al = 1 ? <(rs 1) 'zr)
                 (ga-cs-word (ga-csel (al 1)) (<>(rs 0)) d n n (c ^ 1))))
          (k != 4) (bad 0)
          (ga-cs-word (ga-csel m) (<>(rs 0)) <(rs 0) <(rs 1) <(rs 2) c)))
   (ga-cs-word b z d n r c) (ga-raw ((z = 8 ? 0x80000000 0) | b | ga-hw r << 16 | c << 12 | ga-hw n << 5 | ga-hw d))
   ;; conditional compare: rn against a register or #0..31, nzcv #0..15 when the condition fails
   (ga-ccmp-ins m os)
    (: n (ga-rw (os 0)) c (ga-cond (os 3)) b (m = 'ccmp ? 0x7A400000 0x3A400000) sf (<>n = 8 ? 0x80000000 0)
       (bad _) (scare 'gas-a64-operand [m os])
       ([(os 1) (os 2)] @ (('reg x w) ('imm f))
           (? (<n = 'sp || x = 'sp || w != <>n || !(charm? c) || !(0 <= f <= 15)) (bad 0)
              (ga-raw (sf | b | ga-hw x << 16 | c << 12 | ga-hw <n << 5 | f)))
          (('imm v) ('imm f))
           (? (<n = 'sp || !(charm? c) || !(0 <= v <= 31) || !(0 <= f <= 15)) (bad 0)
              (ga-raw (sf | b | 0x800 | v << 16 | c << 12 | ga-hw <n << 5 | f)))
          _ (bad 0)))
   ;; test bit and branch: the bit's high half rides bit 31, its low five [23:19]; a W register
   ;; tests 0..31, an X 0..63
   (ga-tb-ins m os)
    (: rw (ga-rw (os 0)) top (<>rw = 8 ? 64 32)
       ((os 1) @ ('imm b)
          (? (<rw = 'sp || !(0 <= b < top)) (scare 'gas-a64-operand [m os])
             (: w ((m = 'tbz ? 0x36000000 0x37000000) | (b >> 5) << 31 | (b & 31) << 19)
                (? (charm? (ga-dot (os 2))) (ga-raw (w | ga-off (ga-dot (os 2)) 14 << 5 | ga-hw <rw))
                   ((os 2) @ ('sym l) [['tbr w <rw l]] _ (scare 'gas-a64-operand [m os])))))
          _ (scare 'gas-a64-operand [m os])))
   ;; ands at either width (a W one with a register or bitmask is ga-dp's); no sp
   (ga-ands os)
    (: d (ga-rw (os 0)) n (ga-rw (os 1)) sf (<>d = 8 ? 0x80000000 0)
       (? (<>d != <>n || <d = 'sp || <n = 'sp) (scare 'gas-a64-operand ['ands os])
          ((os 2) @ ('imm v) (ga-bm v (<>d = 8 ? 64 32) @ f
                               (charm? f ? (ga-raw (sf | 0x72000000 | f | ga-hw <n << 5 | ga-hw <d)) (scare 'a64-bitmask-imm v)))
                    ('reg x w) (w = <>d && x != 'sp ? (ga-raw (sf | 0x6A000000 | ga-hw x << 16 | ga-hw <n << 5 | ga-hw <d))
                                  (scare 'gas-a64-operand ['ands os]))
                    _ (scare 'gas-a64-operand ['ands os]))))
   ;; the bitfield moves by opc; sf and N by the width, immr and imms below it
   ga-bfm {'sbfm 0 'bfm 1 'ubfm 2}
   (ga-bfm-ins m os)
    (: d (ga-rw (os 0)) s (ga-rw (os 1)) b (<>d = 8 ? 64 32)
       ([(os 2) (os 3)] @ (('imm r) ('imm t))
          (? (<>s != <>d || <d = 'sp || <s = 'sp || !(0 <= r < b && 0 <= t < b)) (scare 'gas-a64-operand [m os])
             (ga-raw ((b = 64 ? 0x80400000 0) | ga-bfm m << 29 | 0x13000000 | r << 16 | t << 10 | ga-hw <s << 5 | ga-hw <d)))
          _ (scare 'gas-a64-operand [m os])))
   ;; the bitfield aliases: an extract lays immr lsb, imms lsb+w-1; an insert immr -lsb mod size,
   ;; imms w-1; bfc inserts zr. lsb below the width, w from 1 to what is left
   ga-bfa {'ubfx ['ubfm 'x] 'sbfx ['sbfm 'x] 'bfxil ['bfm 'x] 'ubfiz ['ubfm 'z] 'sbfiz ['sbfm 'z] 'bfi ['bfm 'z] 'bfc ['bfm 'z]}
   (ga-bfa-ins m os)
    (: al (ga-bfa m) z ((ga-rw (os 0)) 1) top (z = 8 ? 64 32)
       os2 (m = 'bfc && #os = 3 ? [(os 0) ['reg 'zr z] (os 1) (os 2)] os)
       ([(os2 2) (os2 3)] @ (('imm l) ('imm w))
          (? (#os2 != 4 || !(0 <= l < top) || !(1 <= w <= top - l)) (scare 'gas-a64-operand [m os])
             (ga-bfm-ins (al 0) [(os2 0) (os2 1) ['imm (al 1 = 'x ? l ((top - l) % top))] ['imm (al 1 = 'x ? (l + w - 1) (w - 1))]]))
          _ (scare 'gas-a64-operand [m os])))
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
   ;; the vector file: vN.<arrangement>, or a whole qN -> N, () for any other spelling. a row
   ;; is its word, then each operand's arrangement; rd at 0, rn at 5, rm at 16 (mov's rm is rn)
   (ga-vr o a) (o @ ('sym s) (: t (show s) p (elem a ["q" "s" "d" "h" "b"] ? [a ""] ["v" ("." + a)])
                                (filter (n \ t = <p + show n + <>p) ^32 @ (n . _) n _ ()))
                    _ ())
   ;; a whole fp register b h s d q -> log2 of its bytes
   ga-fpcs ["b" "h" "s" "d" "q"]
   (ga-fpz o) (filter (i \ charm? (ga-vr o (ga-fpcs i))) ^5 @ (z . _) z _ ())   ; log2 of its bytes
   ;; the crypto words, rows per mnemonic: a whole q/s/d register or vN.<T>, rd rn rm ra at 0 5 16
   ;; 10, and 'i6 an immediate there (xar's rotate)
   ga-simd {'sha256h [[0x5E004000 "q" "q" "4s"]] 'sha256h2 [[0x5E005000 "q" "q" "4s"]]
            'sha256su0 [[0x5E282800 "4s" "4s"]] 'sha256su1 [[0x5E006000 "4s" "4s" "4s"]]
            'sha1c [[0x5E000000 "q" "s" "4s"]] 'sha1p [[0x5E001000 "q" "s" "4s"]] 'sha1m [[0x5E002000 "q" "s" "4s"]]
            'sha1su0 [[0x5E003000 "4s" "4s" "4s"]] 'sha1h [[0x5E280800 "s" "s"]] 'sha1su1 [[0x5E281800 "4s" "4s"]]
            'sha512h [[0xCE608000 "q" "q" "2d"]] 'sha512h2 [[0xCE608400 "q" "q" "2d"]]
            'sha512su0 [[0xCEC08000 "2d" "2d"]] 'sha512su1 [[0xCE608800 "2d" "2d" "2d"]]
            'rax1 [[0xCE608C00 "2d" "2d" "2d"]] 'xar [[0xCE800000 "2d" "2d" "2d" 'i6]]
            'eor3 [[0xCE000000 "16b" "16b" "16b" "16b"]] 'bcax [[0xCE200000 "16b" "16b" "16b" "16b"]]
            'aese [[0x4E284800 "16b" "16b"]] 'aesd [[0x4E285800 "16b" "16b"]]
            'aesmc [[0x4E286800 "16b" "16b"]] 'aesimc [[0x4E287800 "16b" "16b"]]
            'pmull [[0x0E20E000 "8h" "8b" "8b"] [0x0EE0E000 "1q" "1d" "1d"]]
            'pmull2 [[0x4E20E000 "8h" "16b" "16b"] [0x4EE0E000 "1q" "2d" "2d"]]}
   (ga-simd-ins m os)
    (: (fit row) (: rs (map (i \ row (i + 1) @ 'i6 ((os i) @ ('imm v) (0 <= v < 64 ? v ()) _ ()) a (ga-vr (os i) a)) ^#os)
                    (#os = #row - 1 && all charm? rs ? rs ()))
       (go l) (? (atom? l) (scare 'gas-a64-operand [m os])
                 (fit <l @ rs (two? rs ? (ga-raw (<<l | (#rs > 2 ? (rs 2) 0) << 16 | (#rs > 3 ? (rs 3) 0) << 10 | <>rs << 5 | <rs))
                                 (go >l))))
       (go (ga-simd m)))
   ;; crc32 by width: wd, wn, and a w or (the x forms) an x
   ga-crc {'crc32b 0x1AC04000 'crc32h 0x1AC04400 'crc32w 0x1AC04800 'crc32x 0x9AC04C00
           'crc32cb 0x1AC05000 'crc32ch 0x1AC05400 'crc32cw 0x1AC05800 'crc32cx 0x9AC05C00}
   (ga-crc-ins m os)
    (: b (ga-crc m) mw (b >> 31 = 1 ? 8 4)
       (? (#os = 3 && all (i \ (os i) @ ('reg r w) (r != 'sp && w = (i = 2 ? mw 4)) _ 0) ^3)
           (ga-raw (b | ga-hw ((os 2) 1) << 16 | ga-hw ((os 1) 1) << 5 | ga-hw ((os 0) 1)))
          (scare 'gas-a64-operand [m os])))
   ;; the memory tag moves: the stores and ldg take a 16-scaled imm9 (the stores post- and pre-indexed
   ;; too), stgm/ldgm none
   ga-stgs {'stg 0xD9200000 'stzg 0xD9600000 'st2g 0xD9A00000 'stz2g 0xD9E00000}
   (ga-mte-ins m os)
    (: t ((os 0) @ ('reg r 8) (r != 'sp ? (ga-hw r)) _ ())
       (i9 v) (v % 16 = 0 && -4096 <= v < 4096 ? ((v // 16) & 511) ())
       (w b x v o) (i9 v @ n (charm? n ? (ga-raw (b | n << 12 | o << 10 | ga-hw x << 5 | t)) (scare 'gas-a64-operand [m os])))
       (? !(charm? t) (scare 'gas-a64-operand [m os])
          (elem m '(stgm ldgm))
           (#os = 2 ? ((os 1) @ ('mem x 0) (ga-raw ((m = 'stgm ? 0xD9A00000 0xD9E00000) | ga-hw x << 5 | t)) _ (scare 'gas-a64-operand [m os]))
              (scare 'gas-a64-operand [m os]))
          (m = 'ldg) (#os = 2 ? ((os 1) @ ('mem x v) (w 0xD9600000 x v 0) _ (scare 'gas-a64-operand [m os])) (scare 'gas-a64-operand [m os]))
          (#os = 3) ([(os 1) (os 2)] @ (('mem x 0) ('imm v)) (w (ga-stgs m) x v 1) _ (scare 'gas-a64-operand [m os]))
          (#os = 2) ((os 1) @ ('mem x v) (w (ga-stgs m) x v 2) ('memw x v) (w (ga-stgs m) x v 3) _ (scare 'gas-a64-operand [m os]))
          (scare 'gas-a64-operand [m os])))
   ;; the advanced simd lane: vN.<T> registers, vN.<T>[i] lanes, { vA.T - vB.T } lists and dN
   ;; scalars, each word as llvm-mc lays it; an arrangement a form does not take refuses
   ga-varr [["8b" 0 0] ["16b" 1 0] ["4h" 0 1] ["8h" 1 1] ["2s" 0 2] ["4s" 1 2] ["1d" 0 3] ["2d" 1 3]]
   (ga-vnum t) (0 < #t && #t < 3 && (all (i \ digit? (t i)) ^#t) && xa-num t < 32 ? (xa-num t) ())
   (ga-vsplit s) (: t (show s) ds (filter (i \ t i = 46) ^#t)
                    (#ds = 1 && t 0 = 118 ? (: n (ga-vnum (snip t 1 <ds)) (charm? n ? [n (snip t (<ds + 1) #t)] ())) ()))
   (ga-vt o) (o @ ('sym s) (: r (ga-vsplit s) a (two? r ? (filter (x \ <x = <>r) ga-varr) ())
                               (two? a ? [<r (a 0 1) (a 0 2) <>r] ()))
                  _ ())                                       ; -> [n q size arrangement]
   (ga-vel o) (o @ ('vel s i) (: r (ga-vsplit s) k (two? r ? (filter (j \ ["b" "h" "s" "d"] j = <>r) ^4) ())
                                 (two? k && charm? i && 0 <= i && i < 16 >> <k ? [<r <k i] ()))
                   _ ())                                      ; -> [n log2-bytes index]
   (ga-fr o c) (o @ ('sym s) (: t (show s) (t 0 = c ? (ga-vnum (snip t 1 #t)) ())) _ ())
   (ga-vls o) (o @ ('vlist ts)                                ; -> [first count q size]
                (: n #ts
                   (? (n < 2 || ts (n - 1) != '(ch 125)) ()
                      (: rs (catmap (g \ (g @ (('sym a)) [(ga-vt ['sym (name a)])]
                                            (('sym a) ('ch 45) ('sym b))
                                             (: x (ga-vt ['sym (name a)]) y (ga-vt ['sym (name b)])
                                                (two? x && two? y && x 3 = y 3 && <x != <y ?
                                                   (map (j \ [((<x + j) % 32) (x 1) (x 2) (x 3)]) ^((<y - <x + 32) % 32 + 1))
                                                   [()]))
                                            _ [()]))
                                    (gops (take (n - 1) ts)))
                         (? (#rs < 1 || #rs > 4 || !(all two? rs)) ()
                            (all (j \ rs j 0 = (rs 0 0 + j) % 32 && rs j 3 = rs 0 3) ^#rs) [(rs 0 0) #rs (rs 0 1) (rs 0 2)]
                            ()))))
                _ ())
   ;; tbl/tbx: vd.8b|16b, a list of one to four consecutive 16b registers, vm of vd's arrangement
   (ga-tbl-ins m os)
    (: d (ga-vt (os 0)) l (#os = 3 ? (ga-vls (os 1))) v (#os = 3 ? (ga-vt (os 2)))
       (? (two? d && two? l && two? v && elem (d 3) ["8b" "16b"] && v 3 = d 3 && l 2 = 1 && l 3 = 0)
           (ga-raw (0x0E000000 | d 1 << 30 | <v << 16 | (l 1 - 1) << 13 | (m = 'tbx ? 0x1000 0) | <l << 5 | <d))
          (scare 'gas-a64-operand [m os])))
   ;; scalar floating point on h s d registers, as llvm-mc lays it: the type at bit 22 (s 0,
   ;; d 1, h 3), m << 16 | n << 5 | d; fcvt names its two types, fmov to or from a gp register
   ;; takes sf at bit 31 from an x
   ga-fty {115 0 100 1 104 3}
   ga-f1 {'fmov 0x1E204000 'fabs 0x1E20C000 'fneg 0x1E214000 'fsqrt 0x1E21C000}
   ga-f2 {'fadd 0x1E202800 'fsub 0x1E203800 'fmul 0x1E200800 'fdiv 0x1E201800 'fmax 0x1E204800 'fmin 0x1E205800}
   (ga-fs o) (o @ ('sym s) (: t (show s) ty (peep ga-fty (t 0) ()) n (ga-fr o (t 0)) (charm? ty && charm? n ? [ty n] ())) _ ())
   (ga-fp? m os) ((m = 'fcvt || charm? (peep ga-f1 m ()) || charm? (peep ga-f2 m ())) && any (o \ two? (ga-fs o)) os)
   (ga-fp m os)
    (: fs (map ga-fs os) k #os
       (gw o) (o @ ('reg r w) (r != 'sp ? [(ga-hw r) w]) _ ())
       (same? l) (all (f \ two? f && <f = <<l) l)
       (? (m = 'fcvt && k = 2 && all two? fs && <<fs != <(fs 1))
           (ga-raw (0x1E224000 | <(fs 1) << 22 | <<fs << 15 | <>(fs 1) << 5 | <>(fs 0)))
          (m = 'fmov && k = 2 && two? (fs 0) && two? (gw (os 1)))
           (: g (gw (os 1)) (ga-raw (0x1E270000 | (<>g = 8 ? 0x80000000 0) | <<fs << 22 | <g << 5 | <>(fs 0))))
          (m = 'fmov && k = 2 && two? (fs 1) && two? (gw (os 0)))
           (: g (gw (os 0)) (ga-raw (0x1E260000 | (<>g = 8 ? 0x80000000 0) | <(fs 1) << 22 | <>(fs 1) << 5 | <g)))
          (charm? (peep ga-f1 m ()) && k = 2 && same? fs)
           (ga-raw (ga-f1 m | <<fs << 22 | <>(fs 1) << 5 | <>(fs 0)))
          (charm? (peep ga-f2 m ()) && k = 3 && same? fs)
           (ga-raw (ga-f2 m | <<fs << 22 | <>(fs 2) << 16 | <>(fs 1) << 5 | <>(fs 0)))
          (scare 'gas-a64-operand [m os])))
   (ga-vec? m os) (!(two? (peep ga-simd m ())) &&
                   (any (o \ two? (ga-vt o) || (o @ ('vel _ _) 1 ('vlist _) 1 _ 0)) os
                    || (elem m '(add sub) && #os = 3 && all (o \ charm? (ga-fr o 100)) os)
                    || (m = 'movi && #os = 2 && charm? (ga-fr (os 0) 100))))
   ;; three registers of one arrangement: [word sized?], an unsized one bytes only
   ga-v3 {'add [0x0E208400 1] 'sub [0x2E208400 1] 'and [0x0E201C00 0] 'bic [0x0E601C00 0] 'orr [0x0EA01C00 0]
          'orn [0x0EE01C00 0] 'eor [0x2E201C00 0] 'bsl [0x2E601C00 0] 'bit [0x2EA01C00 0] 'bif [0x2EE01C00 0]
          'cmeq [0x2E208C00 1] 'cmtst [0x0E208C00 1] 'cmge [0x0E203C00 1] 'cmgt [0x0E203400 1]
          'cmhs [0x2E203C00 1] 'cmhi [0x2E203400 1]}
   ;; a shift by an immediate: [word right?], left esize + s (0 <= s < esize), right 2 esize - s (1 <= s <= esize)
   ga-vsh {'shl [0x0F005400 0] 'sli [0x2F005400 0] 'sshr [0x0F000400 1] 'ushr [0x2F000400 1] 'ssra [0x0F001400 1]
           'usra [0x2F001400 1] 'sri [0x2F004400 1] 'srshr [0x0F002400 1] 'urshr [0x2F002400 1]}
   ;; two registers: [word largest-size], size laid only past 0
   ga-v2 {'rev64 [0x0E200800 2] 'rev32 [0x2E200800 1] 'rev16 [0x0E201800 0] 'not [0x2E205800 0] 'mvn [0x2E205800 0]
          'cnt [0x0E205800 0] 'neg [0x2E20B800 3] 'abs [0x0E20B800 3]}
   ;; across the lanes into one scalar of the lane's size
   ga-vacr {'addv 0x0E31B800 'smaxv 0x0E30A800 'sminv 0x0E31A800 'umaxv 0x2E30A800 'uminv 0x2E31A800}
   ga-vperm {'uzp1 0x0E001800 'uzp2 0x0E005800 'zip1 0x0E003800 'zip2 0x0E007800 'trn1 0x0E002800 'trn2 0x0E006800}
   (ga-neon m os)
    (: k #os bad (_ \ scare 'gas-a64-operand [m os])
       v (map ga-vt os) e (map ga-vel os)
       same (all two? v && all (x \ x 3 = v 0 3) v)
       (gr o) (o @ ('reg r w) (r = 'sp ? () [(ga-hw r) w]) _ ())
       (el5 x) (x 2 << (x 1 + 1) | 1 << x 1)                   ; a lane's imm5
       ; orr/bic's byte immediate into 16- or 32-bit lanes, shifted by whole bytes
       sh (k = 3 ? ((os 2) @ ('shx 0 n) n _ -1) 0)
       iv ((os 1) @ ('imm x) x _ -1)
       (? (elem m '(orr bic) && (k = 2 || k = 3) && two? (v 0) && 0 <= iv <= 255 && 0 <= sh && sh % 8 = 0
           && (elem (v 0 3) ["2s" "4s"] && sh <= 24 || elem (v 0 3) ["4h" "8h"] && sh <= 8))
           (ga-raw (0x0F000400 | v 0 1 << 30 | (m = 'bic ? 0x20000000 0) | (iv >> 5) << 16
                    | ((v 0 2 = 2 ? 1 9) + sh // 4) << 12 | (iv & 31) << 5 | v 0 0))
          ; a scalar from a lane: dup's scalar form, mov its alias
          (elem m '(mov dup) && k = 2 && two? (e 1) && charm? (ga-fpz (os 0)) && ga-fpz (os 0) = e 1 1)
           (ga-raw (0x5E000400 | el5 (e 1) << 16 | e 1 0 << 5 | ga-vr (os 0) (ga-fpcs (e 1 1))))
          (charm? (peep ga-vacr m ()) && k = 2 && two? (v 1) && ga-fpz (os 0) = v 1 2 && v 1 2 < 3 && v 1 3 != "2s")
           (ga-raw (ga-vacr m | v 1 1 << 30 | v 1 2 << 22 | v 1 0 << 5 | ga-vr (os 0) (ga-fpcs (v 1 2))))
          (elem m '(add sub) && k = 3 && all (o \ charm? (ga-fr o 100)) os)
           (ga-raw ((m = 'add ? 0x5EE08400 0x7EE08400) | ga-fr (os 2) 100 << 16 | ga-fr (os 1) 100 << 5 | ga-fr (os 0) 100))
          (two? (peep ga-v3 m ()) && k = 3 && same)
           (: r (ga-v3 m) z (v 0 2)
              (? (v 0 3 = "1d" || (r 1 = 0 && z > 0)) (bad 0)
                 (ga-raw (r 0 | v 0 1 << 30 | (r 1 = 1 ? (z << 22) 0) | v 2 0 << 16 | v 1 0 << 5 | v 0 0))))
          (two? (peep ga-vsh m ()) && k = 3 && two? (v 0) && two? (v 1) && v 1 3 = v 0 3)
           (: r (ga-vsh m) es (8 << v 0 2) s ((os 2) @ ('imm x) x _ ())
              (? (v 0 3 = "1d" || !(charm? s) || (r 1 = 0 ? (s < 0 || s >= es) (s < 1 || s > es))) (bad 0)
                 (ga-raw (r 0 | v 0 1 << 30 | (r 1 = 0 ? (es + s) (2 * es - s)) << 16 | v 1 0 << 5 | v 0 0))))
          (two? (peep ga-v2 m ()) && k = 2 && same)
           (: r (ga-v2 m) z (v 0 2)
              (? (v 0 3 = "1d" || z > r 1) (bad 0)
                 (ga-raw (r 0 | v 0 1 << 30 | (r 1 = 0 ? 0 (z << 22)) | v 1 0 << 5 | v 0 0))))
          (charm? (peep ga-vperm m ()) && k = 3 && same)
           (? (v 0 3 = "1d") (bad 0)
              (ga-raw (ga-vperm m | v 0 1 << 30 | v 0 2 << 22 | v 2 0 << 16 | v 1 0 << 5 | v 0 0)))
          (m = 'ext && k = 4)
           (: s ((os 3) @ ('imm x) x _ ())
              (? (!(all two? (take 3 v)) || v 1 3 != v 0 3 || v 2 3 != v 0 3 || v 0 2 > 0 || !(charm? s)
                  || s < 0 || s >= (v 0 1 = 1 ? 16 8))   ; llvm-mc masks a wider index in silence
                  (bad 0)
                 (ga-raw (0x2E000000 | v 0 1 << 30 | v 2 0 << 16 | s << 11 | v 1 0 << 5 | v 0 0))))
          (m = 'mov && k = 2 && same) (ga-raw (0x0EA01C00 | v 0 1 << 30 | v 1 0 << 16 | v 1 0 << 5 | v 0 0))
          (elem m '(mov ins) && k = 2 && two? (e 0) && two? (gr (os 1)))
           (: x (e 0) g (gr (os 1))
              (? (g 1 != (x 1 = 3 ? 8 4)) (bad 0) (ga-raw (0x4E001C00 | el5 x << 16 | g 0 << 5 | x 0))))
          (elem m '(mov ins) && k = 2 && two? (e 0) && two? (e 1) && e 0 1 = e 1 1)
           (: x (e 0) y (e 1)
              (ga-raw (0x6E000400 | el5 x << 16 | y 2 << y 1 << 11 | y 0 << 5 | x 0)))
          (elem m '(mov umov) && k = 2 && two? (gr (os 0)) && two? (e 1))
           (: g (gr (os 0)) y (e 1)
              (? (g 1 != (y 1 = 3 ? 8 4) || (m = 'mov && y 1 < 2)) (bad 0)
                 (ga-raw (0x0E003C00 | (y 1 = 3 ? 0x40000000 0) | el5 y << 16 | y 0 << 5 | g 0))))
          (m = 'smov && k = 2 && two? (gr (os 0)) && two? (e 1))
           (: g (gr (os 0)) y (e 1)
              (? (y 1 > (g 1 = 8 ? 2 1)) (bad 0)
                 (ga-raw (0x0E002C00 | (g 1 = 8 ? 0x40000000 0) | el5 y << 16 | y 0 << 5 | g 0))))
          (m = 'dup && k = 2 && two? (v 0) && v 0 3 != "1d")
           (: z (v 0 2) g (gr (os 1)) y (e 1)
              (? (two? g) (? (g 1 != (z = 3 ? 8 4)) (bad 0) (ga-raw (0x0E000C00 | v 0 1 << 30 | 1 << z << 16 | g 0 << 5 | v 0 0)))
                 (two? y && y 1 = z) (ga-raw (0x0E000400 | v 0 1 << 30 | el5 y << 16 | y 0 << 5 | v 0 0))
                 (bad 0)))
          (m = 'movi && (k = 2 || k = 3))
           (: x ((os 1) @ ('imm i) i _ ())
              msl (k = 3 && ((os 2) @ ('msl _) 1 _ 0)) ms (msl ? ((os 2) @ ('msl n) n _ 0) 0)
              sh (k = 3 && !msl ? ((os 2) @ ('shx 0 s) s _ -1) 0)
              d0 (ga-fr (os 0) 100) t (two? (v 0) ? (v 0 3) ())
              (? (x = () || !(charm? sh) || sh < 0) (bad 0)
                 (charm? d0 || t = "2d")                      ; 64 bits, each byte all zeros or all ones
                  (: bs (map (j \ (x >> (8 * j)) & 255) ^8) i8 (foldl (\ a j (a | (bs j = 255 ? 1 0) << j)) 0 ^8)
                     (? (k = 3 || !(all (b \ b = 0 || b = 255) bs)) (bad 0)
                        (ga-raw (0x2F00E400 | (t = "2d" ? 0x40000000 0) | (i8 >> 5) << 16 | (i8 & 31) << 5 | (charm? d0 ? d0 (v 0 0))))))
                 (!(two? (v 0)) || x < 0 || x > 255 || t = "1d" || (msl && v 0 2 != 2)) (bad 0)
                 (: z (v 0 2) c (? (z = 0 && sh = 0) 0xE400 (z = 1 && (sh = 0 || sh = 8)) (0x8400 | (sh // 8) << 13)
                                   (z = 2 && msl && (ms = 8 || ms = 16)) (0xC400 | (ms = 16 ? 0x1000 0))
                                   (z = 2 && !msl && elem sh [0 8 16 24]) (0x0400 | (sh // 8) << 13) ())
                    (charm? c ? (ga-raw (0x0F000000 | c | v 0 1 << 30 | (x >> 5) << 16 | (x & 31) << 5 | v 0 0)) (bad 0)))))
          (elem m '(ld1 st1) && (k = 2 || k = 3) && two? (ga-vls (os 0)))
           (: l (ga-vls (os 0)) n (l 1) base (m = 'ld1 ? 0x0C400000 0x0C000000)
              b ((os 1) @ ('mem x 0) (ga-hw x) _ ())
              wd (charm? b ? (l 2 << 30 | [0 7 10 6 2] n << 12 | l 3 << 10 | b << 5 | l 0) ())
              (? (!(charm? b)) (bad 0)
                 (k = 2) (ga-raw (base | wd))
                 ((os 2) @ ('imm i) (i = n * (l 2 = 1 ? 16 8)) _ 0) (ga-raw (base | 0x00800000 | 31 << 16 | wd))
                 ((os 2) @ ('reg r 8) (r != 'sp) _ 0) (ga-raw (base | 0x00800000 | ga-hw ((os 2) 1) << 16 | wd))
                 (bad 0)))
          ; one element loaded to every lane, written back by its size or a register
          (m = 'ld1r && (k = 2 || k = 3) && two? (ga-vls (os 0)) && ga-vls (os 0) 1 = 1)
           (: l (ga-vls (os 0)) b ((os 1) @ ('mem x 0) (ga-hw x) _ ())
              wd (charm? b ? (l 2 << 30 | l 3 << 10 | b << 5 | l 0) ())
              (? (!(charm? b)) (bad 0)
                 (k = 2) (ga-raw (0x0D40C000 | wd))
                 ((os 2) @ ('imm i) (i = 1 << l 3) _ 0) (ga-raw (0x0DC0C000 | 31 << 16 | wd))
                 ((os 2) @ ('reg r 8) (r != 'sp) _ 0) (ga-raw (0x0DC0C000 | ga-hw ((os 2) 1) << 16 | wd))
                 (bad 0)))
          (bad 0)))
   ;; a b h s d or q register's load and store: imm12 scaled by its size, else imm9, or written back
   (ga-lsq m os)
    (: z (ga-fpz (os 0)) t (ga-vr (os 0) (ga-fpcs z)) k #os
       lb ((z = 4 ? 0 (z << 30)) | 0x3C000000 | ((m = 'str ? 0 1) + (z = 4 ? 2 0)) << 22)
       (? (k = 3) ([(os 1) (os 2)] @ (('mem b 0) ('imm v)) (ga-wb lb 1 t b v) _ (scare 'gas-a64-operand os))
          (k != 2) (scare 'gas-a64-operand os)
          ((os 1) @ ('mem b o)
             (? (charm? o && o >= 0 && o % (1 << z) = 0 && o >> z <= 4095) (ga-raw (lb | 0x01000000 | (o >> z) << 10 | ga-hw b << 5 | t))
                (charm? o && -256 <= o <= 255) (ga-raw (lb | (o & 511) << 12 | ga-hw b << 5 | t))
                (scare 'gas-a64-operand os))
             ('memw b o) (ga-wb lb 3 t b o)
             (scare 'gas-a64-operand os))))
   (ga-row row os) (: w (ga-wide os) b (w = 8 ? <row <>row)
                      (charm? b ? b (scare 'gas-a64-width os)))
   (ga-regw row os)                                 ; rd, rn{, rm}
    (: b (ga-row row os) (r i) (ga-hw (ga-r (os i)))
       (ga-raw (b | (#os = 3 ? (r 2 << 16) 0) | r 1 << 5 | r 0)))
   (ga-lnot-ins m os)
    (: row (ga-lnot m) op (row 2) d (ga-hw (ga-r (os 0))) n (ga-hw (ga-r (os 1)))
       ((os 2) @ ('imm v)                           ; bic #v is and #~v
          (ga-wide (take 2 os) = 4 ? (ga-raw (ga-wimm 32 op d n (0 - v - 1)))
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
   (ga-bcond s) (show s @ t (? (#t > 2 && t 0 = 98 && t 1 = 46) (peep ga-cc (name (snip t 2 #t)) ())
                                (#t = 3 && t 0 = 98) (peep ga-cc (name (snip t 1 3)) ())   ; gas's bne, as b.ne
                                ()))
   (ga-inplace op d s) (d = s ? () [['mov d s]])       ; the IR's unary ops work in place
   ;; sys and sysl: op1, Cn, Cm, op2 and an X register, xzr when sys leaves it off; sysl reads it first
   (ga-cr o) (o @ ('sym s) (: t (show s) (filter (n \ t = "c" + show n || t = "C" + show n) ^16 @ (n . _) n _ ())) _ ())
   (ga-sys-ins m os)
    (: l (m = 'sysl) k #os bad (_ \ scare 'gas-a64-operand [m os])
       f (? (l && k = 5) (>os + [<os]) (!l && k = 4) (os + [['reg 'zr 8]]) (!l && k = 5) os ())
       (f @ (('imm a) c n ('imm b) ('reg r 8))
          (: cn (ga-cr c) cm (ga-cr n)
             (? (r = 'sp || !(charm? cn && charm? cm) || !(0 <= a <= 7 && 0 <= b <= 7)) (bad 0)
                (ga-raw ((l ? 0xD5280000 0xD5080000) | a << 16 | cn << 12 | cm << 8 | b << 5 | ga-hw r))))
          _ (bad 0)))
   (ga-ins m os)
    (#os @ k
       (? (charm? (peep ga-movw m ())) (ga-movw-ins m os)
          (ga-fp? m os) (ga-fp m os)
          (elem m '(tbl tbx)) (ga-tbl-ins m os)
          (ga-vec? m os) (ga-neon m os)
          ; a literal load: the word at a label, pc-relative (gas-top's pools land here too)
          (elem m '(ldr ldrsw) && k = 2 && ((os 1) @ ('sym _) 1 ('symk _ _) 1 _ 0) && ((os 0) @ ('reg r _) (r != 'sp) _ 0))
           (: w ((os 0) 2) b (? (m = 'ldrsw) (w = 8 ? 0x98000000 ()) (w = 8) 0x58000000 0x18000000)
              (charm? b ? (ga-sym (os 1) @ (s a) [['afix 'ld19 (b | ga-hw ((os 0) 1)) s a]]) (scare 'gas-a64-operand [m os])))
          (elem m '(adrp adr)) (ga-adrp m os)
          (m = 'add && k = 3 && ((os 2) @ ('grp _ _) 1 _ 0)) (ga-addlo os)
          (k > 2 && two? (ga-shxof (os (k - 1))) && (two? (peep ga-shop m ()) || two? (peep ga-shal m ()))) (ga-shifted m os)
          ; a W mov beside wsp is add #0; zr has no place beside it
          (m = 'mov && k = 2 && any ga-sp? os && all (o \ o @ ('reg _ 4) 1 _ 0) os)
           (? (any (o \ o @ ('reg 'zr _) 1 _ 0) os) (scare 'gas-a64-operand [m os])
              (ga-raw (0x11000000 | ga-hw (ga-r (os 1)) << 5 | ga-hw (ga-r (os 0)))))
          ; a register form naming zr or sp, which the IR's rows cannot hold, or cmn and negs, which have none:
          ; the shifted word at lsl #0, the extended one beside sp
          ((two? (peep ga-shop m ()) || two? (peep ga-shal m ())) && (elem m '(cmn negs) || any (o \ o @ ('reg 'zr _) 1 ('reg 'sp _) 1 _ 0) os)
           && ((os (k - 1)) @ ('reg _ _) 1 _ 0))
           (ga-shifted m (os + [['shx 0 0]]))
          (charm? (peep ga-arity m ()) && k != ga-arity m) (scare 'gas-a64-operand [m os])
          (m = 'ret && k = 1) (ga-r (os 0) @ r (r = 'lr ? '((ret)) (ga-raw (0xD65F0000 | ga-hw r << 5))))
          (ghas? ga-nils m) (k = 0 ? [[(ga-nils m)]] (scare 'gas-a64-operand [m os]))
          (nom? (ga-bcond m)) (? (k != 1) (scare 'gas-a64-operand [m os])
                                 (charm? (ga-dot (os 0))) (ga-raw (0x54000000 | ga-off (ga-dot (os 0)) 19 << 5 | arm-cc (ga-bcond m)))
                                 ((os 0) @ ('symk s a) (a != 0) _ 0) [['afix 'b19 (0x54000000 | arm-cc (ga-bcond m)) <>(os 0) (os 0 2)]]
                                 [['br (ga-bcond m) (<>(os 0))]])
          (elem m '(b bl) && charm? (ga-dot (os 0)))
           (ga-raw ((m = 'b ? 0x14000000 0x94000000) | ga-off (ga-dot (os 0)) 26))
          ; sym+k: the addend rides the fix
          (elem m '(b bl) && ((os 0) @ ('symk s a) (a != 0) _ 0))
           [['afix 'b26 (m = 'b ? 0x14000000 0x94000000) <>(os 0) (os 0 2)]]
          (m = 'b) [['jmp (<>(os 0))]]
          (m = 'bl) [['call (<>(os 0))]]
          (m = 'br) [['jmpr (ga-r (os 0))]]
          (m = 'blr) [['callr (ga-r (os 0))]]
          (elem m '(dsb dmb)) [[m (<>(os 0))]]
          (m = 'mrs) [['mrs (ga-xt m os 0) (<>(os 1))]]
          (m = 'msr) ((os 1) @ ('imm n) [['msri (<>(os 0)) n]] [['msr (<>(os 0)) (ga-xt m os 1)]])
          (elem m '(sys sysl)) (ga-sys-ins m os)
          (elem m ga-sys) [[m (<>(os 0)) (k > 1 ? (ga-r (os 1)) 'zr)]]
          (ghas? ga-exc m) [[(ga-exc m) (k > 0 ? (<>(os 0)) 0)]]
          (m = 'svc) (: n (k > 0 ? (<>(os 0)) 0) (n = 0 ? '((sys)) [['svcn n]]))
          (k > 0 && elem m '(ldr str) && charm? (ga-fpz (os 0))) (ga-lsq m os)
          (two? (peep ga-simd m ())) (ga-simd-ins m os)
          (charm? (peep ga-crc m ())) (ga-crc-ins m os)
          (elem m '(stg stzg st2g stz2g ldg stgm ldgm)) (ga-mte-ins m os)
          (two? (peep ga-ldst m ())) (ga-ls m os)
          (two? (peep ga-mla m ())) (ga-mul m os)
          ; an immediate op beside no sp that the IR's rows cannot hold, zr or a word of its own: that
          ; word, or refused as llvm-mc does
          (k = 3 && two? (peep ga-walu m ()) && !(any ga-sp? os)
           && ((os 2) @ ('imm v) (charm? v && (any (o \ o @ ('reg 'zr _) 1 _ 0) os || !(ga-irimm? m v))) _ 0))
           (ga-dp m os (ga-wide os = 4 ? 32 64))
          (elem m '(mov cmp tst neg mvn add sub and orr eor adds subs ands lsl lsr asr ror) && ga-wide os = 4)
           (ga-dp m os 32)
          (elem m '(neg mvn lsl lsr asr ror) && !(any ga-sp? os)) (ga-dp m os 64)
          (m = 'mov && !(ga-sp? (os 0)) && ((os 1) @ ('imm v) (constellation? v && charm? (ga-movi 64 0 v)) 0))
           (ga-dp m os 64)
          (m = 'mov)
           (: d (ga-r (os 0)) s (os 1)
              (s @ ('imm n) [['li d n]]
                   (? (d = 'sp || ga-r s = 'sp) [['lea d (ga-r s) 0]]
                      (d = 'zr || ga-r s = 'zr) (ga-raw (0xAA0003E0 | ga-hw (ga-r s) << 16 | ga-hw d))   ; orr d, xzr, s
                      [['mov d (ga-r s)]])))
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
           (k = 2 ? (ga-rw (os 0) @ rw
                      (: w ((m = 'cbz ? 0x34000000 0x35000000) | (<>rw = 8 ? 0x80000000 0))
                         (charm? (ga-dot (os 1)) ? (ga-raw (w | ga-off (ga-dot (os 1)) 19 << 5 | ga-hw <rw))
                            [['cbr w <rw (<>(os 1))]])))
              (scare 'gas-a64-operand [m os]))
          (two? (peep ga-lnot m ())) (k = 3 ? (ga-lnot-ins m os) (scare 'gas-a64-operand [m os]))
          (elem m '(tbz tbnz)) (k = 3 ? (ga-tb-ins m os) (scare 'gas-a64-operand [m os]))
          (m = 'ands) (k = 3 ? (ga-ands os) (scare 'gas-a64-operand [m os]))
          (elem m '(ccmp ccmn)) (k = 4 ? (ga-ccmp-ins m os) (scare 'gas-a64-operand [m os]))
          (charm? (peep ga-csel m ()) || two? (peep ga-csal m ())) (ga-cs-ins m os)
          (two? (peep ga-carry m ())) (k = 3 ? (ga-regw (ga-carry m) os) (scare 'gas-a64-operand [m os]))
          (two? (peep ga-un m ())) (k = 2 ? (ga-regw (ga-un m) os) (scare 'gas-a64-operand [m os]))
          (two? (peep ga-ut m ())) (k = 2 ? (ga-ut-ins m os) (scare 'gas-a64-operand [m os]))
          (elem m '(prfm prfum)) (k = 2 ? (ga-prf-ins m os) (scare 'gas-a64-operand [m os]))
          (two? (peep ga-ex m ())) (k = 2 ? (ga-ex-ins (ga-ex m) os) (scare 'gas-a64-operand [m os]))
          (two? (peep ga-sx m ())) (k = 3 ? (ga-ex-ins (ga-sx m) os) (scare 'gas-a64-operand [m os]))
          (charm? (peep ga-bfm m ())) (k = 4 ? (ga-bfm-ins m os) (scare 'gas-a64-operand [m os]))
          (two? (peep ga-bfa m ())) (ga-bfa-ins m os)
          (two? (ga-mops m)) (ga-mops-ins m (ga-mops m) os)
          (two? (peep ga-pair m ())) (ga-pair-ins m os)
          (two? (peep ga-xp m ())) (k = 3 ? (ga-xp-ins m (ga-xp m) os) (scare 'gas-a64-operand [m os]))
          (two? (peep ga-sxp m ())) (k = 4 ? (ga-xp-ins m (ga-sxp m) os) (scare 'gas-a64-operand [m os]))
          (two? (peep ga-casp m ())) (k = 5 ? (ga-casp-ins m (ga-casp m) os) (scare 'gas-a64-operand [m os]))
          (ga-lse-ins m (ga-lse m) os)))
   ;; a register a #define named reaches here apart from its arrangement (`v5` `.4s`): one symbol again
   (ga-glue ts) (ts @ (('sym a) . ('sym b) . r) (b 0 = 46 ? (ga-glue (['sym (a + b)] . r)) (['sym a] . ga-glue (['sym b] . r)))
                      (t . r) (t . ga-glue r)
                      _ ts)
   (ga-line toks)
    (gline toks @ l
       (l @ ('label s) [['label s]]
            ('ins m os) (ga-ins m (map (o \ ga-opnd (ga-glue o)) os))
            ()))

   ;; rv64: dst first, the ABI register names, off(base) memory, the csr pseudos
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

   ;; thumb: the same operand grammar as a64 over r0..r12, a register list, a shifted operand
   (gt-reg s) (peep t32-names (name s) ())
   gt-shs (gtab '((lsl shl) (lsr shr) (asr sar) (ror ror)))
   (gt-list toks)                                   ; {r4-r7, lr} -> (r4 r5 r6 r7 lr)
    (: (r t) (t @ ('sym s) (gt-reg s @ x (nom? x ? x (scare 'gas-thumb-register s))) (scare 'gas-thumb-operand toks))
       (n x) (foldl (\ v c (v * 10 + c - 48)) 0 (chars (snip (show x) 1 #(show x))))   ; r5 -> 5
       (go ts acc)
        (ts @ () (rev acc)
              (a . ('ch 45) . b . more) (: lo (n (r a)) hi (n (r b))
                                       (go (more @ (('ch 44) . m) m more)
                                           (foldl (\ l i (name ("r" + show (lo + i)) . l)) acc ^(hi - lo + 1))))
              (a . ('ch 44) . more) (go more (r a . acc))
              (a) (rev (r a . acc))
              (scare 'gas-thumb-operand toks))
       (go toks ()))
   (gt-opnd toks)
    (toks @ (('ch 35) . rest) ['imm (gimm rest)]
            (('num _) . _) ['imm (gimm toks)]
            (('sym s)) (gt-reg s @ r (nom? r ? ['reg r 4] ['sym (name s)]))
            (('sym s) . rest) (ghas? gt-shs (name s) ? ['sh (gt-shs (name s)) <>(gt-opnd rest)]
                                 (scare 'gas-thumb-operand toks))
            (('ch 123) . rest) (#rest @ n
                                  (rest (n - 1) = '(ch 125) ? ['regs (gt-list (snip rest 0 (n - 1)))]
                                     (scare 'gas-thumb-operand toks)))
            (('ch 91) ('sym b) ('ch 93)) ['mem (gt-reg b) 0]
            (('ch 91) . ('sym b) . ('ch 44) . rest)
             (#rest @ n
                (!(rest (n - 1) = '(ch 93)) ? (scare 'gas-thumb-operand toks)
                   ['mem (gt-reg b) (<>(gt-opnd (rev >(rev rest))))]))
            (scare 'gas-thumb-operand toks))
   (gt-r o) (o @ ('reg x _) x (scare 'gas-thumb-register o))
   (gt-v o) (o @ ('imm n) n ('reg x _) x (scare 'gas-thumb-operand o))
   (gt-sh? o) (o @ ('sh _ _) 1 _ 0)
   gt-nils (gtab '((nop nop) (wfi wfi) (isb isb)))
   gt-alu (gtab '((add add) (sub sub) (and and) (orr or) (eor xor) (mul imul)
                  (adds adds) (subs subs) (adc adc) (adcs adcs) (sbc sbc) (sbcs sbcs) (rsb rsb) (rsbs rsbs)
                  (ands ands) (orrs ors) (eors eors) (bic bic) (bics bics) (orn orn) (addw add) (subw sub)))
   gt-sh3 (gtab '((lsl lsl) (lsr lsr) (asr asr)))
   ; bcc: b and a condition, as gas's bne
   (gt-bcc m) (#(show m) = 3 && (show m) 0 = 98 ? (peep ga-cc (name (snip (show m) 1 3)) ()) ())
   (gt-ins m os)
    (#os @ k
       (? (ghas? gt-nils m) [[(gt-nils m)]]
          (m = 'bkpt) (: n (k > 0 ? (<>(os 0)) 0) (n = 0 ? '((trap)) [['brk n]]))
          (m = 'svc) '((sys))
          (m = 'dsb) [['dsb (<>(os 0))]]
          (m = 'mrs) [['mrs (gt-r (os 0)) (<>(os 1))]]
          (m = 'b) [['jmp (<>(os 0))]]
          (m = 'bl) [['call (<>(os 0))]]
          (nom? (gt-bcc m)) [['br (gt-bcc m) (<>(os 0))]]
          (m = 'bx) (gt-r (os 0) = 'lr ? '((ret)) [['jmpr (gt-r (os 0))]])
          (m = 'push) [['pushm (os 0 @ ('regs rs) rs (scare 'gas-thumb-operand os))]]
          (m = 'pop) [['popm (os 0 @ ('regs rs) rs (scare 'gas-thumb-operand os))]]
          (m = 'mov) ((os 1) @ ('imm n) [['li (gt-r (os 0)) n]] [['mov (gt-r (os 0)) (gt-r (os 1))]])
          (m = 'movw) [['li (gt-r (os 0)) (<>(os 1) @ n (0 <= n < 65536 ? n (scare 'gas-thumb-movw n)))]]
          (m = 'mvn) ((os 1) @ ('imm n) [['li (gt-r (os 0)) (-1 - n)]] [['mvn (gt-r (os 0)) (gt-r (os 1))]])
          (m = 'cmp) [['cmp (gt-r (os 0)) (gt-v (os 1))]]
          (m = 'tst) [['test (gt-r (os 0)) (gt-v (os 1))]]
          (m = 'cmn) ((os 1) @ ('imm n) (n != 0 ? [['cmp (gt-r (os 0)) (0 - n)]] (scare 'gas-thumb-cmn os))   ; cmn #0 sets C apart
                               (scare 'gas-thumb-operand os))
          (m = 'clz) [['clz (gt-r (os 0)) (gt-r (os 1))]]
          (m = 'ubfx) [['ubfx (gt-r (os 0)) (gt-r (os 1)) (<>(os 2)) (<>(os 3))]]
          (elem m '(umull umlal smull)) [[m (gt-r (os 0)) (gt-r (os 1)) (gt-r (os 2)) (gt-r (os 3))]]
          (ghas? gt-sh3 m)
           (: c (os (k - 1)) [[(gt-sh3 m) (gt-r (os 0)) (gt-r (os (k - 2))) (gt-v c)]])
          (ghas? gt-alu m)
           (? (gt-sh? (os (k - 1)))
                (: sh (os (k - 1)) [['alush (gt-alu m) (gt-r (os 0)) (gt-r (os (k - 3))) (gt-r (os (k - 2))) (sh 1) (sh 2)]])
              (k = 3) [[(gt-alu m) (gt-r (os 0)) (gt-r (os 1)) (gt-v (os 2))]]
              [[(gt-alu m) (gt-r (os 0)) (gt-r (os 0)) (gt-v (os 1))]])
          (m = 'ldr) ((os 1) @ ('mem b o) [['ld (gt-r (os 0)) b o]] (scare 'gas-thumb-operand os))
          (m = 'str) ((os 1) @ ('mem b o) [['st b o (gt-r (os 0))]] (scare 'gas-thumb-operand os))
          (scare 'gas-thumb-op m)))
   (gt-line toks)
    (gline toks @ l
       (l @ ('label s) [['label s]]
            ('ins m os) (gt-ins m (map gt-opnd os))
            ()))

   ;; file scope: an asm("..") outside any function, or a .s file, is the whole assembler --
   ;; sections, data, exported labels. a run of instructions goes to gas-text; a directive not
   ;; read here scares
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
                          (elem t '("@note" "%note")) 7
                          (scare 'gas-section-type t)))
             <d)
       [nm ty (1 < #xs ? (gf-flags (xa-unquote (xs 1))) <>d)])
   (gf-width tgt mn) (? (mn = ".byte") 1
                        (elem mn '(".short" ".value" ".2byte" ".hword")) 2
                        (mn = ".word") (gx86? tgt ? 2 4)
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
   ; a product with a constant side, a quotient of constants
   (gf-term ts rl)
    (: (go r) (? (gbad? r || atom? >r || !(elem <>r '((ch 42) (ch 47)))) r
                 (gf-prim >>r rl @ q
                    (: a <r b (gbad? q ? () <q)
                       (? (atom? b) 'bad
                          (<>r = '(ch 47)) (atom? <>a && atom? <>b && <b != 0 ? (go ([(<a // <b) ()] . >q)) 'bad)
                          (atom? <>a) (go ([(<a * <b) (map (p \ (<p . (<a * >p))) <>b)] . >q))
                          (atom? <>b) (go ([(<a * <b) (map (p \ (<p . (<b * >p))) <>a)] . >q))
                          'bad))))
       (go (gf-prim ts rl)))
   (gf-sum ts rl)
    (: (go r) (? (gbad? r) 'bad
                 (atom? >r) r
                 !(elem <>r '((ch 43) (ch 45))) r
                 (gf-term >>r rl @ q
                    (gbad? q ? 'bad
                       (go ((gf-plus <r (<>r = '(ch 43) ? <q (gf-neg <q))) . >q)))))
       (go (gf-term ts rl)))
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
   ; an .octa's 16 bytes: hex digits read in pairs from the low end, a plain number sign-filled
   (gf-octa e)
    (: t (xa-trim e) n #t
       (? (2 < n && t 0 = 48 && (t 1 = 120 || t 1 = 88))
           (map (i \ (: j (n - 2 * i - 1) (lo k) (k > 1 && ghex? (t k) ? (hexv (t k)) 0)
                        (lo j + 16 * lo (j - 1)))) ^16)
           (gimm (gtoks t) @ v (gf-le v 8 + gf-le (v < 0 ? -1 0) 8))))
   (gf-le v w) (: u (v < 0 ? (v + (1 << 8 * w)) v) (map (i \ byte (u >> 8 * i)) ^w))
   ; a word's bytes, or its fixup: rel32 is S + aux - P - 4 wherever it resolves, so `- .` rides aux + 4
   (gf-word tgt w e rl)
    (: v (gf-val e rl) pc <v s <>v k <>>v
       (? !(string? s) (gf-le k w)
          pc (? (w = 4 && !(gthumb? tgt)) [['fix 4 'rel32 (name s) (k + 4)]]
                (w = 8 && elem tgt '(x64 a64)) [['fix 8 'rel64 (name s) (k + 8)]]     ; the jump table's `key - .`
                (scare 'gas-data-pcrel e))
          (w = 8) [['fix 8 'abs64 (name s) k]]
          (w = 4 && (gx86? tgt || tgt = 'a64 || gthumb? tgt)) [['fix 4 'abs32 (name s) k]]
          (w < 4 && g32? tgt) [['fix w (w = 2 ? 'abs16 'abs8) (name s) k]]   ; i386's narrow fields: R_386_16, R_386_8
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
    (elem tgt '(x64 i386 i386m16 rv64) @ hash?
       (catmap (ln \ xa-lines (hash? ? (xa-decomment ln) (gcut2 ln 47))) (gsplit (gdecom src) 10)))
   ;; gas's macro language, over a text's lines before anything reads them: .macro/.endm and a
   ;; call (positional or name=value arguments), .irp and .rept, .if/.ifc/.ifnc/.ifeq/.ifne/.ifb/.ifnb with
   ;; .else, .set/.equ (the symbol reads as its value on the lines after), `name .req reg` and
   ;; .unreq (the name reads as its register), .error, .purgem
   gf-ifs '(".if" ".ifc" ".ifnc" ".ifeq" ".ifne" ".ifb" ".ifnb" ".ifdef" ".ifndef")
   (gf-expand tgt ls)
    (: mac {} sv {} sv0 {} rq {} cnt {}
       xdirs ([".macro" ".purgem" ".irp" ".rept" ".set" ".equ" ".error"] + gf-ifs)
       (dname s) (xa-trim s @ t (0 < #t && t 0 = 46 ? (xa-mnem t @ m (snip m 0 (word m 1))) ""))   ; .inst(..) too
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
       ; a .set symbol reads as its value, a .req name as its register (vt and rt the names that apply)
       (ssub s) (rsub s sv rq)
       (rsub s vt rt) (: n #s
                      (go i acc) (i >= n ? acc
                                    (s i @ c
                                       (gidc? c && (i = 0 || !(gidc? (s (i - 1)))) ?
                                           (: j (word s i) k (snip s i j) v (peep vt k ()) q (peep rt k ())
                                              ; an alias keeps the arrangement after it (t0.4s)
                                              d (xa-idx k 46) q2 (0 < d ? (peep rt (snip k 0 d) ()) ())
                                              (go j (acc + (? (charm? v) (show v) (string? q) q (string? q2) (q2 + snip k d #k) k))))
                                          (go (i + 1) (acc + string c)))))
                      (go 0 ""))
       (val e) (gimm (gtoks (ssub e)))
       ; `.if \base == %rsp`: two registers compare by name -> [bit] | ()
       (rcmp r) (gtoks (ssub r) @ ts
                   (? (#ts = 3 && <(ts 0) = 'pct && <(ts 2) = 'pct && elem (ts 1) '((op "==") (op "!=")))
                      (: eq (<>(ts 0) = <>(ts 2)) [(ts 1 = '(op "==") ? eq !eq)])))
       ; ..at a point, acc the lines laid so far (latest first): backward local labels (`Nb`)
       ; whose distances the a64 lines between them measure. the latest named is the origin and
       ; the others sit back from it, so only their differences mean anything (`(662b-661b) / 4`).
       ; anything unmeasurable between leaves the expression refused
       (vat e acc) (trap val e (\ a b (gtoks (ssub e) @ ts (lbloffs ts acc @ m (two? m ? (gimm (lsub ts m)) (scare a b))))))
       (lsub ts m) (map (t \ lkey t @ k (two? (assoc k m) ? ['num (assoc k m @ x <>x)] t)) ts)
       ; a backward local label or a named one, by the name its line lays
       (lkey t) (t @ ('lref v 98) (show v) ('sym s) (s != "." ? s ()) _ ())
       ; a line's leading labels and the rest -> [names rest]
       (lsplit s) (: (go t ns) (: j (word t 0)
                                  (0 < j && j < #t && t j = 58 ? (go (xa-trim (snip t (j + 1) #t)) ((snip t 0 j) . ns)) [ns t]))
                     (go (xa-trim s) ()))
       ; a data directive's bytes, its items counted at top-level commas
       gf-dnil [".globl" ".global" ".weak" ".hidden" ".protected" ".local" ".type" ".size" ".set" ".equ"]
       gf-dsz {".inst" 4 ".word" 4 ".long" 4 ".4byte" 4 ".quad" 8 ".8byte" 8 ".xword" 8 ".hword" 2 ".short" 2 ".2byte" 2 ".byte" 1}
       (lsize r) (? (r = "") 0 (tgt != 'a64) ()
                    (r 0 = 46) (dname r @ d (peep gf-dsz d () @ z
                                  (? (charm? z) (z * #(xa-oplist (xa-rest r))) (elem d gf-dnil || starts? d ".cfi_") 0 ())))
                    ; an instruction it cannot lay yet (an offset over labels) is still one word
                    (trap (x \ foldl (\ n f (? !(charm? n) () (f @ ('label _) n ('raw bs) (n + #bs) ('align . _) () (n + 4))))
                                    0 (gas-text tgt x))
                          r (\ a b 4)))
       (lbloffs ts acc)
        (: refs (foldl (\ a t (lkey t @ k (k = () || elem k a ? a (k . a)))) () ts)
           ; a .pushsection..popsection run lays elsewhere: walking back, a pop opens it, its push closes it
           (go l org off m)
            (? (!(two? refs) || all (v \ two? (assoc v m)) refs) m
               (atom? l) ()
               (dname <l = ".popsection") (skip >l 1 @ l2 (l2 = 'none ? () (go l2 org off m)))
               (lsplit <l @ (ns r)
                  (: hit (filter (v \ elem v ns) refs)
                     (? !org (two? hit ? (go >l 1 0 (map (v \ [v 0]) hit + m)) (go >l () 0 m))
                        (lsize r @ k
                           (!(charm? k) ? ()
                              (go >l 1 (off + k) (map (v \ [v (0 - (off + k))]) (filter (v \ !(two? (assoc v m))) hit) + m))))))))
           (skip l d) (? (atom? l) 'none (d = 0) l
                         (dname <l @ w (skip >l (? (w = ".popsection") (d + 1) (w = ".pushsection") (d - 1) d))))
           (go acc () 0 ()))
       ; `.reloc off, type, expr` on the zero word just laid at off -> acc with that word as its
       ; expression; the offset measured back to the section's one opening, else ()
       gf-rtys {"R_AARCH64_PREL32" [4 " - ."] "R_AARCH64_ABS32" [4 ""] "R_AARCH64_ABS64" [8 ""]}
       (greloc r acc)
        (: xs (xa-oplist r) ty (two? >xs && peep gf-rtys (xa-trim <>xs) ()) opens [".pushsection" ".section"]
           (back l n) (? (atom? l) ()
                         (elem (dname <l) opens)
                          (: nm (<(xa-oplist (xa-rest (xa-trim <l))))
                             (any (x \ elem (dname x) opens && <(xa-oplist (xa-rest (xa-trim x))) = nm) >l ? () n))
                         (lsplit <l @ (_ u) (lsize u @ k (charm? k ? (back >l (n + k)) ()))))
           (? (!(two? ty) || !(two? >>xs) || atom? acc) ()
              (: w <ty p (xa-trim <acc)
                 (? (lsize p != w || xa-trim (xa-rest p) != "0" || back acc 0 != val <xs + w) ()
                    (("\t" + (w = 4 ? ".long " ".quad ") + xa-trim (xs 2) + ty 1) . >acc)))))
       ; `name .req reg` -> [name reg] | ()
       (req t) (: i (word t 0) r (xa-trim (snip t i #t))
                  (0 < i && #r > 4 && (snip r 0 4) = ".req" && blank? (r 4) ? [(snip t 0 i) (xa-trim (snip r 4 #r))]))
       ; \name -> its argument, \() -> nothing, \@ -> the call's number; an unknown \name stays
       ; for an enclosing reading
       (psub s args)
        (: n #s
           (go i acc) (i >= n ? acc
                         (s i @ c
                            (? (c = 92 && i + 2 < n && s (i + 1) = 40 && s (i + 2) = 41) (go (i + 3) acc)
                               (c = 92 && i + 1 < n && s (i + 1) = 64 && two? (assoc "@" args))
                                (go (i + 2) (acc + <>(assoc "@" args)))
                               (c = 92 && i + 1 < n && gidc? (s (i + 1)))
                                (: j (word s (i + 1)) a (assoc (snip s (i + 1) j) args)
                                   (two? a ? (go j (acc + <>a)) (go (i + 1) (acc + string c))))
                               (go (i + 1) (acc + string c)))))
           (go 0 ""))
       ; a call's arguments: split at commas, and at a space with no operator beside it
       ; (`m x0 8 1f`, but `m (a) | (b)` is one), outside brackets and quotes
       (margs s) (margsl s -1)
       ; ..the first lim, then the rest raw (a :vararg's text, commas kept)
       (margsl s lim)
        (: n #s
           (op? c) (elem c '(43 45 42 47 37 38 124 94 60 62 61 33 126))
           (sk j) (j < n && ws? (s j) ? (sk (j + 1)) j)
           (go i st d q acc)
            (? (i >= n || i = st && #acc = lim) (rev (xa-trim (snip s st n) . acc))
               (q = 1) (go (i + 1) st d (s i = 34 ? 0 1) acc)
               (s i = 34) (go (i + 1) st d 1 acc)
               (s i = 40 || s i = 91) (go (i + 1) st (d + 1) q acc)
               (s i = 41 || s i = 93) (go (i + 1) st (d - 1) q acc)
               (s i = 44 && d = 0) (go (i + 1) (i + 1) 0 q (xa-trim (snip s st i) . acc))
               (ws? (s i) && d = 0)
                (: j (sk i)
                   (? (j >= n || i = st || op? (s (i - 1)) || op? (s j) || s j = 44) (go j st d q acc)
                      (go j j d q (xa-trim (snip s st i) . acc))))
               (go (i + 1) st d q acc))
           (go 0 (sk 0) 0 0 ()))
       ; a parameter's words, its `=` spaced or not: `regsize = 64` is one, `regsize=64`
       (eqj l) (? (atom? l || atom? >l) l
                  (: a <l b <>l
                     (? ((b 0 = 61 && !(xa-has? a 61)) || a (#a - 1) = 61) (eqj ((a + b) . >>l))
                        (a . eqj >l))))
       ; a .macro line's comma piece: names at spaces, but a default runs to the comma whole
       ; (`feat=(((1U << 0) | (1U << 1)))` once cpp has expanded it)
       (mpiece f) (: i (xa-idx f 61) ws (filter (x \ 0 < #x) (xa-split (i < 0 ? f (snip f 0 i)) 32))
                     (i < 0 || !(two? ws) ? (eqj (filter (x \ 0 < #x) (xa-split f 32)))
                        (rev >(rev ws) + mdef (last ws) (xa-trim (snip f (i + 1) #f)))))
       ; ..up to the next `name=` outside parens, when the pieces are spaced (`m a=0 b=0`)
       (mdef nm d)
        (: n #d
           (sk j) (j < n && ws? (d j) ? (sk (j + 1)) j)
           (kw? i) (: k (sk i) e (word d k) m (sk e)
                      (e > k && m < n && d m = 61 && (m + 1 >= n || d (m + 1) != 61)))
           (go i p) (? (i >= n) [(nm + "=" + d)]
                       (d i = 40) (go (i + 1) (p + 1))
                       (d i = 41) (go (i + 1) (p - 1))
                       (p = 0 && ws? (d i) && kw? i) ((nm + "=" + xa-trim (snip d 0 i)) . mpiece (xa-trim (snip d i n)))
                       (go (i + 1) p))
           (go 0 0))
       ; an argument that is one quoted string passes its inside (`"dmb sy"` -> dmb sy)
       (unq a) (: n #a (n >= 2 && a 0 = 34 && a (n - 1) = 34 && !(xa-has? (snip a 1 (n - 1)) 34) ? (snip a 1 (n - 1)) a))
       ; a call's lines: keyword arguments by name, the rest in order, a default for one empty or left off
       (call m rest)
        (: ps <m
           ; `%expr` passes the expression's value under .altmacro; outside it `%rax` is a register
           (pct a) (: t (xa-trim a) (peep cnt 'alt () && 0 < #t && t 0 = 37 ? (show (val (snip t 1 #t))) a))
           va (two? ps && last ps 2 = 'va)
           as (map (a \ pct (unq a)) (0 = #(xa-trim rest) ? () (margsl rest (va ? (#ps - 1) -1))))
           kw (filter (a \ xa-has? a 61) as) po (filter (a \ !(xa-has? a 61)) as)
           (kv nm) (filter (a \ xa-trim (snip a 0 (xa-idx a 61)) = nm) kw)
           (bind ps po acc)
            (atom? ps ? acc
               (: p <ps k (kv <p)
                  (? (two? k) (bind >ps po ([<p (unq (xa-trim (snip <k (1 + xa-idx <k 61) #<k)))] . acc))
                     (p 2 = 'va) ([<p (two? po ? <po "")] . acc)               ; :vararg takes the rest, raw
                     (bind >ps >po ([<p (two? po && <po != "" ? <po <>p)] . acc)))))
           k (peep cnt 'n 0)
           _ (pin cnt 'n (k + 1))
           args (["@" (show k)] . bind ps po ())
           (map (l \ psub l args) <>m))
       (go l acc)
        (atom? l ? acc
           (: s <l t (xa-trim s) w (dname s) r (xa-rest t)
              (? (w = ".macro")
                  (: b (grab >l '(".macro") ".endm")
                     ws (foldl (\ a f (a + mpiece f)) () (xa-split r 44))
                     specs (map (x \ x @ (a + ":vararg") [a "" 'va] (a + ":" + _) [a ""] (a + "=" + b) [a b] [x ""]) >ws)
                     (pin mac <ws [specs <b],
                      go <>b acc))
                 (w = ".altmacro") (pin cnt 'alt 1, go >l acc)
                 (w = ".noaltmacro") (pin cnt 'alt (), go >l acc)
                 (w = ".purgem") (go >l acc)
                 (two? (req t)) (req t @ (nm rg) (pin rq nm (ssub rg), go >l acc))
                 (w = ".unreq") (pin rq (xa-trim r) (), go >l acc)
                 ; gas's `name = expr` is `.set name, expr`
                 (gf-eqset? t) (go ((".set " + xa-trim (snip t 0 (xa-idx t 61)) + ", " + snip t (1 + xa-idx t 61) #t) . >l) acc)
                 (elem w '(".set" ".equ"))
                  (: xs (xa-oplist r) v (xa-trim (two? >xs ? <>xs "")) rv (ssub v)
                     ; a register's name (`digest = %rdi`, then `h = g` as the rounds rotate) stands for it after
                     (? (0 < #rv && rv 0 = 37) (pin rq <xs rv, pin sv <xs (), go >l acc)
                        (gf-ident? v && !(charm? (peep sv v ())))
                         ((peep rq <xs () ? (pin rq <xs ())), go >l (s . acc))   ; an alias: gas-top lays it
                        ; a value over labels (`.set .L__sym_size_f, .-f`) is layout's, not a constant here
                        (trap val <>xs (\ _ _ 'label) @ k
                           (k = 'label ? (go >l (s . acc))
                              (pin rq <xs (), pin sv <xs k, charm? (peep sv0 <xs ()) ? 0 (pin sv0 <xs k), go >l acc)))))
                 (w = ".irp")
                  (: b (grab >l '(".irp" ".rept" ".rep") ".endr") xs (xa-oplist r)
                     (go <>b (foldl (\ a v (go (map (x \ psub x [[<xs v]]) <b) a)) acc >xs)))
                 (elem w [".rept" ".rep"])                      ; .rep is .rept
                  (grab >l '(".irp" ".rept" ".rep") ".endr" @ b
                     (go <>b (foldl (\ a i (go <b a)) acc ^(vat r acc))))
                 (elem w gf-ifs)
                  (: b (grab >l gf-ifs ".endif") ab (split <b)
                     yes (? (elem w '(".ifc" ".ifnc"))
                             (: xs (xa-oplist r) eq (xa-trim <xs = xa-trim (two? >xs ? <>xs ""))
                                (w = ".ifc" ? eq !eq))
                             (w = ".ifb") (xa-trim r = "")
                             (w = ".ifnb") (xa-trim r != "")
                             (w = ".ifeq") (vat r acc = 0)
                             ; defined so far: a .set, or a label laid above
                             (elem w '(".ifdef" ".ifndef"))
                              (: nm (xa-trim r) d (charm? (peep sv nm ()) || any (x \ starts? (xa-trim x) (nm + ":")) acc)
                                 (w = ".ifdef" ? d !d))
                             (two? (rcmp r)) <(rcmp r)
                             (vat r acc != 0))
                     (go <>b (go (yes ? <ab <>ab) acc)))
                 (w = ".reloc") (greloc r acc @ a (two? a ? (go >l a) (go >l (ssub s . acc))))
                 (w = ".error") (scare 'gas-error r)
                 (two? (mac (xa-mnem t))) (go >l (go (call (mac (xa-mnem t)) r) acc))
                 ; labels then a macro call, or a directive read here: the labels where its lines lay
                 (lsplit t @ (ns u) (two? ns && (two? (mac (xa-mnem u)) || elem (dname u) xdirs)))
                  (lsplit t @ (ns u) (go (u . >l) ((map (n \ n + ":") ns) + acc)))
                 (go >l (ssub s . acc)))))
       out (rev (go ls ()))
       ; a use before its .set reads the value it is first set to, as llvm-mc reads it
       (atom? (keys sv0) ? out (map (s \ rsub s sv0 {}) out)))
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
   ; an a64 instruction over a difference of two names (`b sym + (1b - 0b + 8)`), laid once layout holds
   (gf-ldiff? tgt s)
    (tgt = 'a64 && xa-idx s 45 > 0 &&
     (: ts (gtoks (xa-rest s)) (nm? t) (<t = 'sym && <>t != ".")
        (: (go l) (? (atom? l || atom? >l || atom? >>l) 0
                     (nm? <l && <>l = ['ch 45] && nm? <>>l) 1
                     (go >l))
           (go ts))))
   ; does gas-text read it whole: instructions, and labels on lines of their own
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
   ; -> [secs fns objs weaks [aliases]]: secs ((name type flags forms)..) first-seen, fns and
   ; objs the .globl names a label here defines, split by whether its section executes
   (gas-top tgt src) (gas-top-in tgt src ".text" [1 6] "" ".text")
   ; ..read from a section of the caller's own, home, wearing [type flags] htd; a numeric label
   ; is named pfx + GNU's own, so two readings never lay one twice
   (gas-top-in tgt src home htd pfx hsub)
    (: st {'cur home 'prev home 'stk () 'run () 'order () 'globl () 'md (gx-md tgt)}
       secs {}                                      ; name -> [type flags forms-reversed]
       labs {}                                      ; label -> its section
       lits {}                                      ; section -> its pool waiting, [label width expr] latest first
       lc {}                                        ; N -> how many `N:` so far
       sx {}                                        ; a .set over labels -> its tokens
       (rl n d) (pfx + show (glabel n (d = 102 ? (1 + peep lc n 0) (peep lc n 0))))
       (row nm td) (two? (secs nm) ? 0
                      (pin st 'order (nm . (st 'order)), pin secs nm [<td <>td ()]))
       (emit fs) (: nm (st 'cur) _ (row nm (nm = home ? htd (gf-dflt nm))) r (secs nm)
                    (pin secs nm [<r <>r (revcat fs <>>r)]))
       (flush _) (st 'run @ r
                    (two? r ? (xa-join "\n" (rev r) @ t
                                 (pin st 'run (), emit (gx86? tgt ? (gx-exactm (st 'md) tgt t) (gas-text tgt t))))
                       0))
       (goto nm td) (row nm td, pin st 'prev (st 'cur), pin st 'cur nm)
       (raw bs) (two? bs ? (emit [['raw bs]]) 0)
       ; a64's `ldr rt, =expr`: a constant one movz holds is that movz, else a word in the
       ; section's pool (one per width and expression) and a literal load of it, as llvm-mc lays them
       (lit s)
        (: xs (xa-oplist (xa-rest s)) e1 (#xs = 2 ? (xa-trim (xs 1)) "")
           (? (tgt != 'a64 || xa-mnem s != "ldr" || #xs != 2 || !(starts? e1 "=")) s
              (: rg (xa-trim <xs) e (xa-trim (snip e1 1 #e1)) w (? (starts? rg "x") 8 (starts? rg "w") 4 0)
                 ts (gtoks e) c (!(any (t \ <t = 'sym || <t = 'lref) ts))
                 u (c ? (gimm ts @ v (v < 0 ? (v + (1 << 8 * w)) v)) 0)
                 sh (c ? (filter (k \ u >> k << k = u && u >> k < 65536) (w = 8 ? [0 16 32 48] [0 16])) ())
                 (? (w = 0) s
                    (two? sh) ("movz " + rg + ", #" + show (u >> <sh) + ", lsl #" + show <sh)
                    (: nm (st 'cur) l (peep lits nm ()) hit (filter (x \ x 1 = w && x 2 = e) l)
                       lb (two? hit ? (hit 0 0) (pfx + ".Llit" + show (peep st 'nlit 0)))
                       (two? hit ? 0 (pin st 'nlit (peep st 'nlit 0 + 1), pin lits nm ([lb w e] . l)),
                        "ldr " + rg + ", " + lb))))))
       (pool nm)
        (: es (rev (peep lits nm ())) c (st 'cur)
           (two? es ? (pin st 'cur nm,
                       emit (catmap (x \ [['dalign (x 1)] ['label (name (x 0))] ['raw (gf-word tgt (x 1) (x 2) rl)]]) es),
                       pin st 'cur c, pin lits nm ())
              0))
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
           (? <v (scare 'gas-org e)
              (gbad? at) (string? s ? (orgx e) (scare 'gas-org e))
              (<>>v < at) (scare 'gas-org e)
              (raw (map (i \ 0) ^(<>>v - at)))))
       ; ..a label behind instructions: a label here, and the pad up to the target once layout holds
       (orgx e)
        (: k (peep st 'orgs 0) here (pfx + ".Lorg" + show k)
           (pin st 'orgs (k + 1),
            emit [['label (name here)]
                  ['skipx (['ch 40] . map (t \ (<t = 'lref ? ['sym (rl <>t <>>t)] t)) (gtoks e) + [['ch 41] ['ch 45] ['sym here]]) 0 0 'org]]))
       ; a word laid once layout holds, `.` its own site
       (wx ts w) (: k (peep st 'wxs 0) here (pfx + ".Lwx" + show k)
                    (pin st 'wxs (k + 1),
                     ['wordx (map (t \ (t @ ('lref n d) ['sym (rl n d)] ('sym ".") ['sym here] _ t)) ts) w here]))
       (dir mn rest)
        (: xs (xa-oplist rest) w (gf-width tgt mn)
           (? (0 < w)
               ; a word over two labels (`.byte 773b-771b`) waits like a .skip: ('wordx toks w)
               (emit (rev (foldl (\ acc f (<f = 'raw && two? acc && <<acc = 'raw ?   ; neighbouring words lay as one raw
                                              (['raw (<><acc + <>f)] . >acc) (f . acc)))
                                 ()
                                 (map (e \ (gtoks e @ ts
                                              (1 < #(filter (t \ <t = 'lref || (<t = 'sym && <>t != ".")) ts) &&
                                               !(any (t \ t = ['sym "."]) ts) || any (t \ <t = 'sym && sxn <>t) ts ? (wx ts w)
                                                 ; ..and one over `.` no fix carries, `(sym - .) / 8`
                                                 (trap (e \ ['raw (gf-word tgt w e rl)]) e
                                                       (\ a b (a = 'gas-data && any (t \ t = ['sym "."]) ts && any (t \ <t = 'lref || (<t = 'sym && <>t != ".")) ts ?
                                                                  (wx ts w) (scare a b)))))))
                                      xs))))
              (mn = ".octa") (raw (catmap gf-octa xs))
              (mn = ".ascii") (raw (catall (gf-strs rest)))
              (elem mn '(".asciz" ".string")) (raw (catmap (b \ b + [0]) (gf-strs rest)))
              (elem mn '(".zero" ".skip" ".space"))
               (: f (two? >xs ? (num <>xs) 0) ts (gtoks <xs)
                  ; a count over labels waits for the whole template: ('skipx toks fill n)
                  (any (t \ <t = 'lref || <t = 'sym) ts ?
                      (emit [['skipx (map (t \ (<t = 'lref ? ['sym (rl <>t <>>t)] t)) ts) f 0]])
                     (raw (map (i \ f & 255) ^(num <xs)))))
              ; .fill repeat, size, value: each copy the value's low bytes, past four zeros (as gas)
              (mn = ".fill")
               (: r (num <xs) z (two? >xs ? (num <>xs) 1) v (two? >>xs ? (num (xs 2)) 0)
                  (? (r < 0 || z < 0) (scare 'gas-directive mn)
                     (raw (catmap (_ \ (z <= 4 ? (gf-le v z) (gf-le v 4 + map (_ \ 0) ^(z - 4)))) ^r))))
              (mn = ".org") (org rest)
              (mn = ".inst") (tgt = 'a64 ? (raw (catmap (e \ gf-le (num e) 4) xs)) (scare 'gas-directive mn))
              ; a subsection is its section's tail, named apart until the end lays it there
              (mn = ".subsection")
               (: n (num rest) b (gf-base (st 'cur)) r (secs b)
                  (goto (n = 0 ? b (b + string 1 + show n))
                        (two? r ? [<r <>r] (b = home ? htd (gf-dflt b)))))
              (mn = ".base64") (raw (catmap gf-b64 (gf-strs rest)))
              ; what the pre-pass left: an alias, or a value over labels only .size reads. the
              ; kernel's SYM_END sizes f by `.set .L__sym_size_f, .-f`: f's end label lays here
              (elem mn '(".set" ".equ"))
               (: v (cats (split " " (xa-trim <>xs)))
                  (? (gf-ident? v) (pin st 'alias ([(xa-unquote <xs) (xa-unquote <>xs)] . peep st 'alias ()))
                     (starts? (xa-unquote <xs) ".L__sym_size_" && starts? v ".-") (emit [['label (fn-end (snip v 2 #v))]])
                     ; over labels: its tokens, `.` a label here, for the words laid once layout holds
                     (any (t \ <t = 'lref || <t = 'sym) (gtoks <>xs))
                      (: k (peep st 'sxs 0) here (pfx + ".Lset" + show k)
                         (pin st 'sxs (k + 1),
                          emit [['label (name here)]],
                          pin sx (xa-trim <xs) (map (t \ (t @ ('lref n d) ['sym (rl n d)] ('sym ".") ['sym here] _ t)) (gtoks <>xs))))
                     0))
              ; exported, and bound weak: a strong definition elsewhere wins
              (mn = ".weak") (map xa-unquote xs @ ws (pin st 'globl (rev ws + st 'globl), pin st 'weak (ws + peep st 'weak ())))
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
              (mn = ".align") (emit [['align (gx86? tgt ? (num <xs) (1 << num <xs))]])   ; bytes on x86, a power elsewhere
              (elem mn '(".section" ".pushsection"))
               (gf-sect xs @ d
                  (mn = ".pushsection" ? (pin st 'stk ([(st 'cur) (st 'prev)] . (st 'stk))) 0,
                   pin st 'named (<d . peep st 'named ()),
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
              ; .size f, .-f: an end label here, f's st_size; any other size goes unread
              (mn = ".size")
               (two? >xs && cats (split " " (xa-trim <>xs)) = ".-" + xa-unquote <xs ?
                  (emit [['label (fn-end (xa-unquote <xs))]]) 0)
              ; .type f, @function: f's type label; stt_notype for a label no .type names
              (mn = ".type")
               (filter (w \ 0 < #w) (map xa-trim (catmap (f \ xa-split f 32) (xa-split rest 44))) @ ws
                  (two? >ws && elem (ws 1) '("@function" "%function" "STT_FUNC" "\"function\"" "@gnu_indirect_function") ?
                     (emit [['label (fn-type (xa-unquote <ws))]]) 0))
              ; what a static link never reads: visibility, unwind rows
              (elem mn '(".hidden" ".protected" ".internal" ".file" ".ident" ".thumb_func") || starts? mn ".cfi_") 0
              ; gas takes every undefined name as external already
              (mn = ".extern") 0
              ; the ISA a line may use: every one this reader knows, always
              (elem mn '(".arch" ".arch_extension" ".cpu")) 0
              ; the x86 segment the lines after it run in: their operand and address widths
              (elem mn '(".code16" ".code16gcc" ".code32" ".code64"))
               (gx86? tgt ? (pin st 'md (mn @ ".code32" 32 ".code64" 64 16)) (scare 'gas-directive mn))
              (elem mn '(".ltorg" ".pool")) (pool (st 'cur))
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
                    (lit (gf-lsub s rl) @ t
                       (gf-ldiff? tgt t || (tgt = 'a64 && any (k \ <k = 'sym && sxn <>k) (gtoks t)) ?
                          (flush 0, emit [['insx t]])
                          (dline t @ fs (two? fs ? (flush 0, emit fs) (pin st 'run (t . (st 'run)))))))))))
       ; an x86 operand over two labels, `$(a - b)` or `(a - b)(%reg)`, which no instruction
       ; lays alone: laid over a sentinel, its four bytes then wait like a word (a 'wordx). () when not one
       (dcut o) (? (0 < #o && o 0 = 36) ["$" (snip o 1 #o) ""]
                   ((: (g i) (? (i < 1) () (o i = 40 && o (i + 1) = 37) ["" (snip o 0 i) (snip o i #o)] (g (i - 1))))
                    (#o - 2)))
       (diff? e) (gtoks e @ ts (any (t \ t = ['ch 45]) ts && 1 < #(filter (t \ <t = 'sym && <>t != ".") ts)))
       (dline t)
        (: os (xa-ops (xa-rest t)) c (foldl (\ a o (two? a ? a (dcut o @ d (two? d && diff? (d 1) ? d ())))) () os)
           (sent bs) ((: (g j) (? (j + 4 > #bs) () (snip bs j (j + 4) = [120 86 52 18]) j (g (j + 1)))) 0)
           (? (!(gx86? tgt) || atom? c) ()
              (trap (\ _ (gx-exactm (st 'md) tgt t)) 0 (\ _ _ ()) @ ok
                 (two? ok ? ()
                    (: u (xa-mnem t + " " + xa-join ", " (map (o \ (dcut o = c ? (c 0 + "0x12345678" + c 2) o)) os))
                       fs (gx-exactm (st 'md) tgt u) bs (two? fs && atom? >fs && <<fs = 'raw ? <>(fs 0) ())
                       j (sent bs) k (peep st 'wxs 0) here (pfx + ".Lwx" + show k)
                       (? !(charm? j) ()
                          (pin st 'wxs (k + 1),
                           [['raw (snip bs 0 j)] ['wordx (gtoks (c 1)) 4 here] ['raw (snip bs (j + 4) #bs)]])))))))
       ls (gf-expand tgt (gf-lines tgt src))
       ; the names a .set over labels makes, known before a word reads one
       sxn (foldl (\ t l (xa-trim l @ u
                            (0 < #u && u 0 = 46 ?
                               (gf-dsplit u @ (mn r) (xa-oplist r @ xs
                                  (elem mn '(".set" ".equ")) && two? >xs && !(gf-ident? (xa-trim <>xs))
                                   && !(starts? (xa-unquote <xs) ".L__sym_size_")
                                   && any (k \ <k = 'lref || <k = 'sym) (gtoks <>xs) ? (pin t (xa-trim <xs) 1) t))
                               t)))
                  {} ls)
       _ (foldl (\ _ x (line x)) 0 ls)
       _ (flush 0)
       _ (foldl (\ _ nm (pool nm)) 0 (rev (st 'order)))      ; each pool still waiting ends its section
       ; each subsection after its section's own forms, in number order; a function's home has no
       ; tail of its own, so its subsections go to hsub, the section the function lands in
       _ (foldl (\ _ nm (: b (gf-base nm) t (b = "" ? hsub b) r (secs nm)
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
       (fsz f off) (<f @ 'raw (width <>f) 'label 0 ('align || 'dalign) ((<>f - off % <>f) % <>f) 'skipx (f 3) 'wordx (f 2) 'insx 4
                         (width (holo-bytes-open tgt [f] (noms f {}))))
       ; label -> its offset, each section's shifted by k times its own large stride
       (offs k) (: t {} si {'i 1}
                   (foldl (\ _ nm (k * 1000003 * si 'i @ b (pin si 'i (si 'i + 1), pin t nm b,
                                                            foldl (\ off f (? (<f = 'label) (pin t (show <>f) (b + off))
                                                                             (<f = 'wordx && 3 < #f) (pin t (f 3) (b + off))   ; its own site
                                                                             0,
                                                                            off + fsz f off))
                                                                  0 (rev <>>(secs nm)),
                                                            0)))
                          0 (st 'order),
                    t))
       ; a .set name reads as its tokens, to a depth
       (sxp ts n) (n > 8 ? ts (catmap (k \ (k @ ('sym s) (two? (sx s) ? ([['ch 40]] + sxp (sx s) (n + 1) + [['ch 41]]) [k]) _ [k])) ts))
       (ev f t) (gimm (map (k \ (k @ ('sym s) (peep t s () @ v (charm? v ? ['num v] (scare 'gas-skip s)))
                                    k)) (sxp (f 1) 0)))
       ; ..and a count that moves with where a section lands is no constant (a difference across sections)
       (skv f t) (ev f t @ v (v = ev f (offs 1) ? v (scare 'gas-data (f 1))))
       (skip? f) (two? f && <f = 'skipx)
       ; a word over two labels: its constant, or -- `sym - 1f` across sections, a hand-laid jump's
       ; displacement -- a pc-relative fix whose addend is the field's distance from the label
       (wxlay f t)
        (trap (\ _ ['raw (gf-le (skv f t) (f 2))]) 0
              (\ a b (: ts (f 1) w (f 2) site (t (f 3)) t1 (offs 1)
                         (ts @ [('sym s) ('ch 45) ('sym l)]
                               (? (!(charm? (t l)) || t1 l - t1 (f 3) != t l - site) (scare a b)   ; l in the field's section
                                  ['raw [(fix w (w @ 4 'rel32 2 'rel16 'pc8) (name s) (site + w - t l))]])
                               (scare a b)))))
       ; an .org may read back while the pads before it still grow: refused once they hold
       (settle n)
        (: t (offs 0) ch {'c 0}
           (foldl (\ _ nm (: r (secs nm)
                             fs (map (f \ (skip? f ?
                                              (: v (skv f t) v2 (v < 0 ? 0 v)
                                                 (v2 != f 3 ? (pin ch 'c 1) 0,
                                                  (v < 0 && f 4 = 'org ? (pin ch 'back (f 1)) 0,
                                                   ['skipx (f 1) (f 2) v2 (f 4)])))
                                              f)) <>>r)
                             (pin secs nm [<r <>r fs])))
                  0 (st 'order),
            (? !(ch 'c) (two? (peep ch 'back ()) ? (scare 'gas-org-back (ch 'back)) 0)
               (n > 4) (scare 'gas-skip-settle src)
               (settle (n + 1)))))
       ; an instruction over a label difference: the labels beside a `-` read as their offsets,
       ; and what it lays may not move with where its section lands
       (isub s t) (: n #s
                     (nb i d) (? (i < 0 || n <= i) 0 (s i = 32 || s i = 9) (nb (i + d) d) (s i))
                     (go i acc) (i >= n ? acc
                                   (s i @ c
                                      (galpha? c && (i = 0 || !(gidc? (s (i - 1)))) ?
                                         (: j ((: (g j) (j < n && gidc? (s j) ? (g (j + 1)) j)) i) k (snip s i j)
                                            (go j (acc + (charm? (t k) && (nb (i - 1) -1 = 45 || nb j 1 = 45) ? (show (t k)) k))))
                                         (go (i + 1) (acc + string c)))))
                     (go 0 ""))
       ; a token run spelled back, a .set name as its run
       (tspell ts) (catmap (k \ (k @ ('num v) (show v) ('sym s) (two? (sx s) ? ("(" + tspell (sx s) + ")") s) ('ch c) (string c) _ (scare 'gas-immediate k))) ts)
       (sxs s) (gtoks s @ ts (any (k \ <k = 'sym && two? (sx <>k)) ts ? (xa-mnem s + " " + tspell (gtoks (xa-rest s))) s))
       (inlay f t) (sxs (f 1) @ u (gas-text tgt (isub u t) @ a (a = gas-text tgt (isub u (offs 1)) ? a (scare 'gas-immediate (f 1)))))
       (later? f) (two? f && elem <f '(skipx wordx insx))
       _ (any (nm \ any later? <>>(secs nm)) (st 'order) ?
            (: _ (settle 0)
               t (offs 0)
               (lay f) (<f @ 'skipx [['raw (map (i \ (f 2) & 255) ^(f 3))]]
                             'wordx [(wxlay f t)]
                             'insx (inlay f t)
                             [f])
               (foldl (\ _ nm (secs nm @ r
                                 (pin secs nm [<r <>r (filter (f \ !(<f = 'raw && atom? <>f))
                                                              (catmap (f \ (later? f ? (lay f) [f])) <>>r))])))
                      0 (st 'order)))
            0)
       ; an alias lays its label beside its target's, in the target's section; a target
       ; that is itself an alias is followed to the label at the end of the chain, and one
       ; this text never labels goes back to the caller
       am (foldl (\ t al (pin t <al <>al)) {} (peep st 'alias ()))
       (aroot s n) (string? (labs s) || n > 16 || !(am s) ? s (aroot (am s) (n + 1)))
       _ (foldl (\ _ al (: a <al s (aroot <>al 0) nm (labs s)
                          (? (!(string? nm) && am s) (scare 'gas-alias s)   ; a cycle labels nothing
                             !(string? nm) (pin st 'xal ([a s] . peep st 'xal ()))
                             (secs nm @ r
                                (pin labs a nm,
                                 pin secs nm [<r <>r (catmap (f \ (f = ['label (name s)] ? [['label (name a)] f] [f])) <>>r)])))))
                0 (peep st 'alias ()))
       (sec nm) (secs nm @ r [nm <r <>r (rev <>>r)])
       (exec? l) (0 < <>(secs (labs l)) & 4)
       def (filter (l \ string? (labs l)) (uniq (rev (st 'globl))))   ; .weak and .globl may both name one
       ; a section the text named stays though empty: a linker script may lay it
       ; the aliases onto names this text never labels ride a fifth element, only when there are any
       ([(filter (r \ two? (r 3) || elem <r (peep st 'named ())) (map sec (rev (st 'order))))
         (filter exec? def) (filter (l \ !(exec? l)) def) (rev (peep st 'weak ()))]
        + (peep st 'xal () @ x (two? x ? [(rev x)] ()))))

   ;; text -> IR, by target
   (gas-text tgt src)
    (? (tgt = 'x64) (gx-text src)
       (g32? tgt) (gx-w32 (gx-text32 src))
       (: lc {}
          f (? (tgt = 'a64) ga-line (tgt = 'rv64) gr-line (gthumb? tgt) gt-line (scare 'gas-target tgt))
          (foldl (\ acc ln (acc + f (glocal (gtoks ln) lc))) () (glines src (tgt = 'rv64))))))
) ; module 'holo
