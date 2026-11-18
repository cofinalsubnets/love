; riscv -- the rv64 backend for holo (the ox64's c906, qemu -M virt). rv64imfd plus Zicsr/Zifencei
; for kernels, and rv32 (the esp32-c6's rv32imac) through the same emitters at a 4-byte word; no A (moon's __sync hands its atomic words in raw). words squeeze to C forms where
; they fit (rvc-of), so an image asks for rv64gc.
;
; no flags register: cmp/test/ucomisd emit at most an immediate load and remember their operands in
; rv-flags; br/set fuse them into beq/blt/slt/feq... the contract is x86's: a br/set must follow its
; cmp with the operands still live. adds/subs leave their overflow bit's sign in x30 for vs/vc.
;
; branches lay wide: an inverted fused branch hops a jal x0 (+-1MB); the 'short hook narrows them
; to the bare branch (+-4KB) or c.beqz/c.bnez/c.j. call/la/lar are an auipc pair (+-2GB, one 'pcrel
; fixup). immediates never scare: past 12 bits they go through a scratch.
;
; scratches outside the abstract file: x31 (t6) is dead after every lowered chunk; x30 (t5) carries
; a cmp's immediate, a test result or an overflow bit to its br/set. a far-displacement stx/stxb
; borrows x30, so it may not sit between a cmp and its br.

(module 'holo
(: ;; the instruction table, one row a machine instruction: [name match mask kinds], a word is
   ;; the row's when (w & mask) = match, its operands the kinds in text order (decode.l reads
   ;; them). a dotted name is spelt through name, since . is cons
   (rvt-r op f3 f7 ks nm) [nm (f7 << 25 | f3 << 12 | op) 0xfe00707f ks]
   (rvt-i op f3 ks nm) [nm (f3 << 12 | op) 0x707f ks]
   (rvt-f2 f7 rs2 ks nm) [nm (f7 << 25 | rs2 << 20 | 0x53) 0xfff0007f ks]  ; rs2 fixed, rm free
   (rvt-sfx nm s) (name (show nm + s))
   (rvt-sd f) (catmap (k \ f k (k = 0 ? ".s" ".d")) [0 1])                 ; a row for each width
   rv-tab (catall [
     [['lui 0x37 0x7f '(rd u20)] ['auipc 0x17 0x7f '(rd u20)] ['jal 0x6f 0x7f '(rd j)]
      ['jalr 0x67 0x707f '(rd m)]
      ['ecall 0x73 0xffffffff ()] ['ebreak 0x100073 0xffffffff ()] ['sret 0x10200073 0xffffffff ()]
      ['mret 0x30200073 0xffffffff ()] ['wfi 0x10500073 0xffffffff ()]
      [(name "sfence.vma") 0x12000073 0xfe007fff '(rs1 rs2)]
      [(name "fence.i") 0x100f 0xffffffff ()] ['fence 0xf 0x707f '(fence)]]
     (map (r \ rvt-i 0x63 (r 1) '(rs1 rs2 b) <r) '((beq 0) (bne 1) (blt 4) (bge 5) (bltu 6) (bgeu 7)))
     (map (r \ rvt-i 0x03 (r 1) '(rd m) <r) '((lb 0) (lh 1) (lw 2) (ld 3) (lbu 4) (lhu 5) (lwu 6)))
     (map (r \ rvt-i 0x23 (r 1) '(rs2 ms) <r) '((sb 0) (sh 1) (sw 2) (sd 3)))
     (map (r \ rvt-i 0x13 (r 1) '(rd rs1 i12) <r) '((addi 0) (slti 2) (sltiu 3) (xori 4) (ori 6) (andi 7)))
     [['slli 0x1013 0xfc00707f '(rd rs1 sh6)] ['srli 0x5013 0xfc00707f '(rd rs1 sh6)]
      ['srai 0x40005013 0xfc00707f '(rd rs1 sh6)]
      (rvt-i 0x1b 0 '(rd rs1 i12) 'addiw) (rvt-r 0x1b 1 0 '(rd rs1 sh5) 'slliw)
      (rvt-r 0x1b 5 0 '(rd rs1 sh5) 'srliw) (rvt-r 0x1b 5 32 '(rd rs1 sh5) 'sraiw)]
     (map (r \ rvt-r 0x33 (r 1) (r 2) '(rd rs1 rs2) <r)
          '((add 0 0) (sub 0 32) (sll 1 0) (slt 2 0) (sltu 3 0) (xor 4 0) (srl 5 0) (sra 5 32)
            (or 6 0) (and 7 0) (mul 0 1) (mulh 1 1) (mulhsu 2 1) (mulhu 3 1) (div 4 1) (divu 5 1)
            (rem 6 1) (remu 7 1)))
     (map (r \ rvt-r 0x3b (r 1) (r 2) '(rd rs1 rs2) <r)
          '((addw 0 0) (subw 0 32) (sllw 1 0) (srlw 5 0) (sraw 5 32) (mulw 0 1) (divw 4 1)
            (divuw 5 1) (remw 6 1) (remuw 7 1)))
     (map (r \ rvt-i 0x73 (r 1) (r 2) <r)
          '((csrrw 1 (rd csr rs1)) (csrrs 2 (rd csr rs1)) (csrrc 3 (rd csr rs1))
            (csrrwi 5 (rd csr zimm)) (csrrsi 6 (rd csr zimm)) (csrrci 7 (rd csr zimm))))
     ;; the atomics: aq and rl free, the name's suffix
     (catmap (r \ map (w \ [(rvt-sfx <r (w 0)) (r 1 << 27 | w 1 << 12 | 0x2f)
                            (<r = 'lr ? 0xf9f0707f 0xf800707f) ('aqrl . r 2)])
                      [[".w" 2] [".d" 3]])
             '((lr 2 (rd am)) (sc 3 (rd rs2 am)) (amoswap 1 (rd rs2 am)) (amoadd 0 (rd rs2 am))
               (amoxor 4 (rd rs2 am)) (amoand 12 (rd rs2 am)) (amoor 8 (rd rs2 am))
               (amomin 16 (rd rs2 am)) (amomax 20 (rd rs2 am)) (amominu 24 (rd rs2 am))
               (amomaxu 28 (rd rs2 am))))
     [(rvt-i 0x07 2 '(fd m) 'flw) (rvt-i 0x07 3 '(fd m) 'fld)
      (rvt-i 0x27 2 '(fs2 ms) 'fsw) (rvt-i 0x27 3 '(fs2 ms) 'fsd)]
     (rvt-sd (k \ s \ map (r \ [(rvt-sfx <r s) (k << 25 | r 1) 0x600007f '(fd fs1 fs2 fs3 rm)])
                         '((fmadd 0x43) (fmsub 0x47) (fnmsub 0x4b) (fnmadd 0x4f))))
     (rvt-sd (k \ s \ map (r \ [(rvt-sfx <r s) (r 1 + k << 25 | 0x53) 0xfe00007f '(fd fs1 fs2 rm)])
                         '((fadd 0) (fsub 4) (fmul 8) (fdiv 12))))
     (rvt-sd (k \ s \ map (r \ rvt-r 0x53 (r 2) (r 1 + k) (r 3) (rvt-sfx <r s))
                         '((fsgnj 16 0 (fd fs1 fs2)) (fsgnjn 16 1 (fd fs1 fs2)) (fsgnjx 16 2 (fd fs1 fs2))
                           (fmin 20 0 (fd fs1 fs2)) (fmax 20 1 (fd fs1 fs2))
                           (feq 80 2 (rd fs1 fs2)) (flt 80 1 (rd fs1 fs2)) (fle 80 0 (rd fs1 fs2)))))
     (rvt-sd (k \ s \ [(rvt-f2 (44 + k) 0 '(fd fs1 rm) (rvt-sfx 'fsqrt s))
                       [(rvt-sfx 'fclass s) (112 + k << 25 | 1 << 12 | 0x53) 0xfff0707f '(rd fs1)]]))
     [(rvt-f2 32 1 '(fd fs1 rm) (name "fcvt.s.d")) (rvt-f2 33 0 '(fd fs1 rm) (name "fcvt.d.s"))
      [(name "fmv.x.w") 0xe0000053 0xfff0707f '(rd fs1)] [(name "fmv.x.d") 0xe2000053 0xfff0707f '(rd fs1)]
      [(name "fmv.w.x") 0xf0000053 0xfff0707f '(fd rs1)] [(name "fmv.d.x") 0xf2000053 0xfff0707f '(fd rs1)]]
     ;; the integer conversions, by rs2: w wu l lu
     (rvt-sd (k \ s \ catmap (i \ (: t ("." + show ('(w wu l lu) i))
                                    [(rvt-f2 (96 + k) i '(rd fs1 rm) (name ("fcvt" + t + s)))
                                     (rvt-f2 (104 + k) i '(fd rs1 rm) (name ("fcvt" + s + t)))]))
                             ^4))])
   ;; the C table: [name match mask kinds base], the base instruction a word stands for, its
   ;; operands in the base's order. 0 is no instruction; c.mv is addi as llvm reads it back
   rvc-tab [["c.addi4spn" 0x0000 0xe003 '(p2 sp c4spn) 'addi] ["c.fld" 0x2000 0xe003 '(p2f cd) 'fld]
            ["c.lw" 0x4000 0xe003 '(p2 cw) 'lw] ["c.ld" 0x6000 0xe003 '(p2 cd) 'ld]
            ["c.fsd" 0xa000 0xe003 '(p2f cd) 'fsd] ["c.sw" 0xc000 0xe003 '(p2 cw) 'sw]
            ["c.sd" 0xe000 0xe003 '(p2 cd) 'sd]
            ["c.addi" 0x0001 0xe003 '(r5 r5 ci6) 'addi] ["c.addiw" 0x2001 0xe003 '(r5 r5 ci6) 'addiw]
            ["c.li" 0x4001 0xe003 '(r5 z ci6) 'addi] ["c.addi16sp" 0x6101 0xef83 '(sp sp c16sp) 'addi]
            ["c.lui" 0x6001 0xe003 '(r5 clui) 'lui]
            ["c.srli" 0x8001 0xec03 '(p1 p1 cu6) 'srli] ["c.srai" 0x8401 0xec03 '(p1 p1 cu6) 'srai]
            ["c.andi" 0x8801 0xec03 '(p1 p1 ci6) 'andi]
            ["c.sub" 0x8c01 0xfc63 '(p1 p1 p2) 'sub] ["c.xor" 0x8c21 0xfc63 '(p1 p1 p2) 'xor]
            ["c.or" 0x8c41 0xfc63 '(p1 p1 p2) 'or] ["c.and" 0x8c61 0xfc63 '(p1 p1 p2) 'and]
            ["c.subw" 0x9c01 0xfc63 '(p1 p1 p2) 'subw] ["c.addw" 0x9c21 0xfc63 '(p1 p1 p2) 'addw]
            ["c.j" 0xa001 0xe003 '(z cj) 'jal]
            ["c.beqz" 0xc001 0xe003 '(p1 z cb) 'beq] ["c.bnez" 0xe001 0xe003 '(p1 z cb) 'bne]
            ["c.slli" 0x0002 0xe003 '(r5 r5 cu6) 'slli] ["c.fldsp" 0x2002 0xe003 '(r5f cdsp) 'fld]
            ["c.lwsp" 0x4002 0xe003 '(r5 cwsp) 'lw] ["c.ldsp" 0x6002 0xe003 '(r5 cdsp) 'ld]
            ["c.jr" 0x8002 0xf07f '(z r5m) 'jalr] ["c.mv" 0x8002 0xf003 '(r5 r2 i0) 'addi]
            ["c.ebreak" 0x9002 0xffff () 'ebreak] ["c.jalr" 0x9002 0xf07f '(ra r5m) 'jalr]
            ["c.add" 0x9002 0xf003 '(r5 r5 r2) 'add]
            ["c.fsdsp" 0xa002 0xe003 '(r2f csdsp) 'fsd] ["c.swsp" 0xc002 0xe003 '(r2 cswsp) 'sw]
            ["c.sdsp" 0xe002 0xe003 '(r2 csdsp) 'sd]]
   ;; the encoder: a row and its operands in text order to the word, each kind laid back where
   ;; decode.l reads it. a register, immediate, csr or rm is a number, a memory (off base), a
   ;; fence (pred succ), a branch its offset. (rv-fb v hi lo at) puts v's bits hi..lo at bit at
   (rv-fb v hi lo at) ((v >> lo & ((1 << (hi - lo + 1)) - 1)) << at)
   (rve-op k v)
    (k @ 'rd (v << 7) 'fd (v << 7) 'rs1 (v << 15) 'fs1 (v << 15) 'rs2 (v << 20) 'fs2 (v << 20)
         'fs3 (v << 27) 'i12 (rv-fb v 11 0 20) 'u20 (rv-fb v 19 0 12) 'sh6 (rv-fb v 5 0 20) 'sh5 (rv-fb v 4 0 20)
         'm (rv-fb <v 11 0 20 | v 1 << 15) 'ms (rv-fb <v 11 5 25 | rv-fb <v 4 0 7 | v 1 << 15)
         'b (rv-fb v 12 12 31 | rv-fb v 10 5 25 | rv-fb v 4 1 8 | rv-fb v 11 11 7)
         'j (rv-fb v 20 20 31 | rv-fb v 10 1 21 | rv-fb v 11 11 20 | rv-fb v 19 12 12)
         'am (v << 15) 'rm (v << 12) 'csr (v << 20) 'zimm (rv-fb v 4 0 15) 'fence (<v << 24 | v 1 << 20)
         (scare 'rv-enc-kind k))
   ;; a row's word, aq the atomics' aq and rl bits
   (rve-word row vs aq)
    (: (go w ks vs) (? !(two? ks) w (go (w | rve-op <ks <vs) >ks >vs))
       (go (row 1 | aq << 25) (rv-kinds row) vs))
   rv-byname (foldl (\ t r (pin t (r 0) r)) {} rv-tab)
   ;; a name's row and its aq and rl bits, an atomic's .aq .rl .aqrl riding its name; () for none
   (rv-row mn)
    (: s (show mn) (cut x) (#s > #x && snip s (#s - #x) #s = x)
       aq (? (cut ".aqrl") 3 (cut ".aq") 2 (cut ".rl") 1 0)
       row (peep rv-byname (aq = 0 ? mn (name (snip s 0 (#s - (aq @ 3 5 2 3 3))))) ())
       (two? row ? [row aq] ()))
   ;; a row's operand kinds in text order
   (rv-kinds row) (<(row 3) = 'aqrl ? >(row 3) (row 3))
   ;; a name and its operands to the word
   (rv-word mn vs) (rv-row mn @ ra (two? ra ? (rve-word <ra vs (ra 1)) (scare 'rv-enc mn)))
   (rvo mn vs) (le32 (rv-word mn vs))
   ;; decode.l's items to the raw operands, a target against pc
   (rv-raw o pc) (? (elem <o '(mem fence)) >o (<o = 'lbl) (o 1 - pc) (o 1))
   (rv-enc mn ops pc) (rv-word mn (map (o \ rv-raw o pc) ops))
   ;; a C row's halfword, its operands raw in the base's order: p the three-bit registers
   ;; x8..x15, a memory's base the same field
   (rvce-op k v)
    (: m? (elem k '(cw cd)) p (m? ? (v 1 - 8) (v - 8)) o (m? ? <v 0)
       (k @ 'r5 (v << 7) 'r5f (v << 7) 'r2 (v << 2) 'r2f (v << 2) 'p1 (p << 7) 'p2 (p << 2) 'p2f (p << 2)
            'z 0 'ra 0 'sp 0 'i0 0
            'ci6 (rv-fb v 5 5 12 | rv-fb v 4 0 2) 'cu6 (rv-fb v 5 5 12 | rv-fb v 4 0 2)
            'clui (rv-fb v 5 5 12 | rv-fb v 4 0 2)
            'c16sp (rv-fb v 9 9 12 | rv-fb v 8 7 3 | rv-fb v 6 6 5 | rv-fb v 5 5 2 | rv-fb v 4 4 6)
            'c4spn (rv-fb v 5 4 11 | rv-fb v 9 6 7 | rv-fb v 2 2 6 | rv-fb v 3 3 5)
            'cw (rv-fb o 5 3 10 | rv-fb o 2 2 6 | rv-fb o 6 6 5 | p << 7) 'cd (rv-fb o 5 3 10 | rv-fb o 7 6 5 | p << 7)
            'cwsp (rv-fb <v 5 5 12 | rv-fb <v 4 2 4 | rv-fb <v 7 6 2)
            'cdsp (rv-fb <v 5 5 12 | rv-fb <v 4 3 5 | rv-fb <v 8 6 2)
            'cswsp (rv-fb <v 5 2 9 | rv-fb <v 7 6 7) 'csdsp (rv-fb <v 5 3 10 | rv-fb <v 8 6 7) 'r5m (v 1 << 7)
            'cj (rv-fb v 11 11 12 | rv-fb v 4 4 11 | rv-fb v 9 8 9 | rv-fb v 10 10 8 | rv-fb v 6 6 7
                 | rv-fb v 7 7 6 | rv-fb v 3 1 3 | rv-fb v 5 5 2)
            'cb (rv-fb v 8 8 12 | rv-fb v 4 3 10 | rv-fb v 7 6 5 | rv-fb v 2 1 3 | rv-fb v 5 5 2)
            (scare 'rvc-enc-kind k)))
   (rvc-row-word row vs)
    (: (go w ks vs) (? !(two? ks) w (go (w | rvce-op <ks <vs) >ks >vs)) (go (row 1) (row 3) vs))
   rvc-byname (foldl (\ t r (pin t (r 0) r)) {} rvc-tab)
   (rvc-word cn vs) (peep rvc-byname cn () @ row (two? row ? (rvc-row-word row vs) (scare 'rvc-enc cn)))
   (rvco cn vs) (le16 (rvc-word cn vs))
   (rvc-enc row ops pc) (rvc-row-word row (map (o \ rv-raw o pc) ops)))

(: ;; r0..r7 a0..a7, r8..r12 t0..t4, r13/r14/r15 s2/s3/s1, r19..r26 s4..s11; sp x2, fp s0, lr ra.
   ;; gp and tp are never touched. zr is x0, for the system lane (sfence zr, zr)
   rv-regs {'sp 2 'fp 8 'lr 1 'zr 0
            'r0 10 'r1 11 'r2 12 'r3 13 'r4 14
            'r5 15 'r6 16 'r7 17
            'r8 5 'r9 6 'r10 7 'r11 28 'r12 29
            'r13 18 'r14 19 'r15 9
            'r19 20 'r20 21 'r21 22 'r22 23
            'r23 24 'r24 25 'r25 26 'r26 27}
   (rvn r) (look rv-regs r 'badreg)
   (rv-reg-eq a b) (rvn a = rvn b)

   ;; f0..f7 fa0..fa7, f8..f15 ft0..ft7, f16..f19 ft8..ft11
   rv-fregs {'f0 10 'f1 11 'f2 12 'f3 13 'f4 14
             'f5 15 'f6 16 'f7 17
             'f8 0 'f9 1 'f10 2 'f11 3 'f12 4
             'f13 5 'f14 6 'f15 7
             'f16 28 'f17 29 'f18 30 'f19 31}
   (rvf r) (look rv-fregs r 'badfreg)

   (rv-fits12 n) (n >= -2048 && n <= 2047)
   ;; the low 12 bits, signed, so n - lo is a multiple of 4096
   (rv-lo12 n) (n & 4095 @ low (low > 2047 ? (low - 4096) low))
   ;; rv32 lowers through these same emitters with rv-flags 'x 32: a word is 4 bytes, no W ops
   (rv32? _) (peep rv-flags 'x 64 = 32)
   (rv-s32 n) (n & 4294967295 @ u (u > 2147483647 ? (u - 4294967296) u))

   ;; addi, lui+addiw, or the high chunks then slli 12 + addi. s64 folds an unsigned >= 2^63
   (rv-li-rec dn s)
      (? (rv-fits12 s) (rvo 'addi [dn 0 s])
         (fits32 s)
         (: lo (rv-lo12 s) hi ((s - lo) // 4096)                            ; addiw wraps mod 2^32,
            (catall [                                                       ; so hi=2^19 is exact
(rvo 'lui [dn hi])
(lo = 0 ? () (rvo (rv32? 0 ? 'addi 'addiw) [dn dn lo]))]))
         (rv-lo12 s @ lo
            (catall [
              (rv-li-rec dn ((s - lo) // 4096))
              (rvo 'slli [dn dn 12])
              (lo = 0 ? () (rvo 'addi [dn dn lo]))])))
   (rv-li d imm) (rv-li-rec (rvn d) (rv32? 0 ? (rv-s32 imm) (s64 imm)))

   (rv-mov d s) (rvo 'addi [(rvn d) (rvn s) 0])

   ;; op -> its instruction, and the immediate form's
   (rv-look t k tag) (peep t k () @ e (nom? e ? e (scare tag k)))          ; look, for names
   rv-alu {'add 'add 'sub 'sub 'and 'and 'or 'or 'xor 'xor 'imul 'mul}
   (rv-aluop op d a b)
      (: mn (rv-look rv-alu op 'rv-badalu) dn (rvn d) an (rvn a)
         (? (reg? b) (rvo mn [dn an (rvn b)])
            (op = 'sub && rv-fits12 (0 - b)) (rvo 'addi [dn an (0 - b)])
            (rv-fits12 b && elem op '(add and or xor)) (rvo (name (show mn + "i")) [dn an b])
            (catall [(rv-li-rec 31 b) (rvo mn [dn an 31])])))

   ;; the last cmp/test/ucomisd/adds: 'a/'b hardware numbers (FPRs when 'f is 1 .d or 2 .s),
   ;; 'v the overflow register or -1
   rv-flags {}
   (rv-flag-set f a b v)
      (pin rv-flags 'f f, pin rv-flags 'a a, pin rv-flags 'b b, pin rv-flags 'v v, ())

   (rv-cmp a b)
      (rvn a @ an
         (? (reg? b) (rv-flag-set 0 an (rvn b) -1)
            (b = 0)  (rv-flag-set 0 an 0 -1)
            (rv-li-rec 30 b @ bs (rv-flag-set 0 an 30 -1, bs))))
   (rv-test a b)                                                             ; x30 = a and b, against x0
      (: an (rvn a)
         bs (? (reg? b) (rvo 'and [30 an (rvn b)])
               (rv-fits12 b) (rvo 'andi [30 an b])
               (catall [(rv-li-rec 31 b) (rvo 'and [30 an 31])]))
         (rv-flag-set 0 30 0 -1,
          bs))

   ;; overflow sign in x30: (d^a)&(d^b) for add, (a^b)&(a^d) for sub, off saved operands so d
   ;; may alias. the other conds read d against x0
   (rv-addsub-s op d a b)
      (: dn (rvn d) an (rvn a)
         pre (reg? b ? (rvo 'addi [30 (rvn b) 0]) (rv-li-rec 30 b))       ; x30 = b's old value
         (rv-flag-set 0 dn 0 30,
          catall [
           pre
           (rvo 'addi [31 an 0])                                             ; x31 = a's old value
           (rvo (op = 'adds ? 'add 'sub) [dn 31 30])                         ; d = a op b
           (op = 'adds ?
              (catall [(rvo 'xor [31 dn 31]) (rvo 'xor [30 dn 30])])        ; d ^ a, d ^ b
              (catall [(rvo 'xor [30 31 30]) (rvo 'xor [31 31 dn])]))       ; a ^ b, a ^ d
           (rvo 'and [30 30 31])]))

   ;; cond -> (funct3 rs1 rs2), gt/le/above/be by swapping. f3 ^ 1 inverts; rv-bn names it
   (rv-bn f3) (f3 @ 0 'beq 1 'bne 4 'blt 5 'bge 6 'bltu 'bgeu)
   (rv-int-b cond an bn)
      (? (cond = 'eq) [0 an bn] (cond = 'ne) [1 an bn]
         (cond = 'lt) [4 an bn] (cond = 'ge) [5 an bn]
         (cond = 'gt) [4 bn an] (cond = 'le) [5 bn an]
         (cond = 'below) [6 an bn] (cond = 'ae) [7 an bn]
         (cond = 'above) [6 bn an] (cond = 'be) [7 bn an]
         (scare 'rv-badcc cond))
   ;; -> [the predicate into x31, the sense: 1 taken when set, 0 when clear]. ucomisd's conds as
   ;; x86's; gt/ge are unordered-false and lt/le their complements (unordered-true), as a64's
   ;; fcmp, so lt == below and le == be
   (rv-fp-pred cond fa fb w)                                                 ; w 2: singles
     (: (f mn) (rvt-sfx mn (w = 2 ? ".s" ".d"))
        lt (rvo (f 'flt) [31 fb fa]) le (rvo (f 'fle) [31 fb fa]) eq (rvo (f 'feq) [31 fa fb])
        ord (catall [(rvo (f 'feq) [31 fa fa]) (rvo (f 'feq) [30 fb fb]) (rvo 'and [31 31 30])])
      (? (elem cond '(above gt)) [lt 1] (elem cond '(be le)) [lt 0]                  ; flt x31, fb, fa
         (elem cond '(ae ge)) [le 1] (elem cond '(below lt)) [le 0]                  ; fle x31, fb, fa
         (cond = 'eq) [eq 1] (cond = 'ne) [eq 0]                                     ; feq x31, fa, fb
         (cond = 'p) [ord 0] (cond = 'np) [ord 1]                                    ; both ordered
         (scare 'rv-fp-badcc cond)))
   (rv-flag-read tag)
      (peep rv-flags 'a -1 @ a
         (a < 0 ? (scare 'rv-no-cmp tag) 0,
          [a (peep rv-flags 'b -1) (peep rv-flags 'f 0) (peep rv-flags 'v -1)]))

   ;; an inverted hop over the wide jal. s/ns take the sign of a-b in x31
   (rv-br cond label)
      (: st (rv-flag-read 'br) an (st 0) bn (st 1)
         jal [(fix 4 'j21 label (rv-word 'jal [0 0]))]
         (? (st 2)
            (rv-fp-pred cond an bn (st 2) @ p
               (catall [(p 0)
                         (rvo (p 1 ? 'beq 'bne) [31 0 8])               ; hop: beqz/bnez x31, +8
                         jal]))
            (elem cond '(s ns))
            (catall [(rvo 'sub [31 an bn])                                   ; x31 = a - b
                      (rvo (cond = 's ? 'bge 'blt) [31 0 8])               ; hop: bgez/bltz x31, +8
                      jal])
            (elem cond '(vs vc))
            (st 3 @ v (v < 0 ? (scare 'rv-no-overflow cond) 0,
                       catall [(rvo (cond = 'vs ? 'bge 'blt) [v 0 8]) jal]))
            (rv-int-b cond an bn @ t
               (catall [(rvo (rv-bn (t 0 ^ 1)) [(t 1) (t 2) 8]) jal]))))

   (rv-set cond d)
      (: st (rv-flag-read 'set) an (st 0) bn (st 1) dn (rvn d)
         (? (st 2)
            (rv-fp-pred cond an bn (st 2) @ p
               (catall [(p 0)
                         (p 1 ? (rvo 'addi [dn 31 0]) (rvo 'sltiu [dn 31 1]))]))   ; d = x31, or seqz
            (elem cond '(eq ne))
            (: xs (bn = 0 ? () (rvo 'xor [31 an bn]))                     ; x31 = a ^ b
               t  (bn = 0 ? an 31)
               (catall [xs (cond = 'eq ? (rvo 'sltiu [dn t 1]) (rvo 'sltu [dn 0 t]))]))
            (elem cond '(s ns))
            (catall [(rvo 'sub [31 an bn]) (rvo 'slt [dn 31 0])
                      (cond = 's ? () (rvo 'xori [dn dn 1]))])
            (elem cond '(vs vc))
            (st 3 @ v (v < 0 ? (scare 'rv-no-overflow cond) 0,
                       catall [(rvo 'slt [dn v 0]) (cond = 'vs ? () (rvo 'xori [dn dn 1]))]))
            (: neg (elem cond '(ge le ae be))
               t (rv-int-b (? (cond = 'ge) 'lt (cond = 'le) 'gt
                              (cond = 'ae) 'below (cond = 'be) 'above cond) an bn)
               (catall [(rvo (t 0 = 4 ? 'slt 'sltu) [dn (t 1) (t 2)])
                         (neg ? (rvo 'xori [dn dn 1]))]))))

   ;; a far offset builds base+hi in x31 and rides the low 12
   (rv-mem-far bn off go)                                                    ; go: (basereg lo12) -> bytes
      (: lo (rv-lo12 off) hi ((off - lo) // 4096)
         (hi >= -524288 && hi <= 524287 ? 0 (scare 'rv-mem-range off),
          catall [(rvo 'lui [31 hi]) (rvo 'add [31 31 bn]) (go 31 lo)]))
   (rv-ldn mn dt bn off)
      (rv-fits12 off ? (rvo mn [dt [off bn]]) (rv-mem-far bn off (\ b lo (rvo mn [dt [lo b]]))))
   (rv-stn mn bn off st)
      (rv-fits12 off ? (rvo mn [st [off bn]]) (rv-mem-far bn off (\ b lo (rvo mn [st [lo b]]))))
   (rv-wl _) (rv32? 0 ? 'lw 'ld)                                             ; a word: lw/sw on rv32
   (rv-ws _) (rv32? 0 ? 'sw 'sd)
   (rv-ld d base off)   (rv-ldn (rv-wl 0) (rvn d) (rvn base) off)
   (rv-st base off s)   (rv-stn (rv-ws 0) (rvn base) off (rvn s))
   (rv-ld1 d base off)  (rv-ldn 'lb (rvn d) (rvn base) off)
   (rv-ld2 d base off)  (rv-ldn 'lh (rvn d) (rvn base) off)
   (rv-ld4 d base off)  (rv-ldn 'lw (rvn d) (rvn base) off)
   (rv-ldu1 d base off) (rv-ldn 'lbu (rvn d) (rvn base) off)
   (rv-ldu2 d base off) (rv-ldn 'lhu (rvn d) (rvn base) off)
   (rv-ldu4 d base off) (rv-ldn (rv32? 0 ? 'lw 'lwu) (rvn d) (rvn base) off)
   (rv-st1 base off s)  (rv-stn 'sb (rvn base) off (rvn s))
   (rv-st2 base off s)  (rv-stn 'sh (rvn base) off (rvn s))
   (rv-st4 base off s)  (rv-stn 'sw (rvn base) off (rvn s))
   (rv-fld d base off)  (rv-ldn 'fld (rvf d) (rvn base) off)
   (rv-fst base off s)  (rv-stn 'fsd (rvn base) off (rvf s))
   (rv-flds d base off) (rv-ldn 'flw (rvf d) (rvn base) off)
   (rv-fsts base off s) (rv-stn 'fsw (rvn base) off (rvf s))

   (rv-sx w d) (rvn d @ dn
                  (w = 4 ? (rv32? 0 ? (rv-mov d d) (rvo 'addiw [dn dn 0]))  ; sext.w
                     (: c ((w = 1 ? 56 48) - (rv32? 0 ? 32 0))
                        (catall [(rvo 'slli [dn dn c]) (rvo 'srai [dn dn c])]))))
   (rv-zx w d) (rvn d @ dn
                  (? (w = 1) (rvo 'andi [dn dn 255])
                     (w = 4 && rv32? 0) (rv-mov d d)
                     (: c ((w = 2 ? 48 32) - (rv32? 0 ? 32 0))
                        (catall [(rvo 'slli [dn dn c]) (rvo 'srli [dn dn c])]))))

   ;; no rotate without Zbb: rol/ror go through x31
   (rv-shift op d c)
      (rvn d @ dn
         ; rv32 has no shamt past 31: a word shifted out is 0, or its sign, as thumb lays it
         (? (rv32? 0 && 31 < c && elem op '(shl shr)) (rvo 'addi [dn 0 0])     ; li d, 0
            (rv32? 0 && 31 < c && op = 'sar) (rvo 'srai [dn dn 31])
            (op = 'shl) (rvo 'slli [dn dn c])
            (op = 'shr) (rvo 'srli [dn dn c])
            (op = 'sar) (rvo 'srai [dn dn c])
            (elem op '(rol ror))
            (: w (rv32? 0 ? 32 64) k (op = 'ror ? c (w - c & w - 1))       ; rol c = ror w-c
               (catall [(rvo 'srli [31 dn k]) (rvo 'slli [dn dn (w - k & w - 1)]) (rvo 'or [dn dn 31])]))
            (scare 'rv-badshift op)))
   (rv-shiftv op d c)                                                        ; the IR pins the count to r1
      (: _ (rv-reg-eq c 'r1 ? 0 (scare 'shiftv-count-not-r1 [op d c]))
         _ (rv-reg-eq d 'r1 ? (scare 'shiftv-dst-is-r1 [op d c]) 0)
         dn (rvn d) cn (rvn c)
         (rvo (op @ 'shlv 'sll 'shrv 'srl 'sra) [dn dn cn]))

   (rv-lea d base off)
      (: dn (rvn d) bn (rvn base)
         (rv-fits12 off ? (rvo 'addi [dn bn off]) (catall [(rv-li-rec 31 off) (rvo 'add [dn bn 31])])))

   ;; x31 carries base + ix*scale; a far displacement's high half goes in ldx's own dest, or x30
   ;; for stx (see the header)
   (rv-shamt scale) (? (scale = 1) 0 (scale = 2) 1 (scale = 4) 2 (scale = 8) 3 (scare 'badscale scale))
   (rv-ixaddr bn ixn sc)                                                     ; x31 = base + ix*scale
      (rv-shamt sc @ amt
         (amt = 0 ? (rvo 'add [31 ixn bn]) (catall [(rvo 'slli [31 ixn amt]) (rvo 'add [31 31 bn])])))
   (rv-ix-far dp tn go)                                                      ; tn carries hi; go lo -> bytes
      (rv-fits12 dp ? (go dp)
         (: lo (rv-lo12 dp) hi ((dp - lo) // 4096)
            (catall [(rvo 'lui [tn hi]) (rvo 'add [31 31 tn]) (go lo)])))
   (rv-ldxn mn d base index scale disp)
      (rvn d @ dn
         (catall [(rv-ixaddr (rvn base) (rvn index) scale) (rv-ix-far disp dn (lo \ (rvo mn [dn [lo 31]])))]))
   (rv-ldx d base index scale disp)  (rv-ldxn (rv-wl 0) d base index scale disp)
   (rv-ldxb d base index scale disp) (rv-ldxn 'lbu d base index scale disp)
   (rv-ldxh d base index scale disp) (rv-ldxn 'lhu d base index scale disp)
   (rv-stxn mn base index scale disp s)
      (catall [(rv-ixaddr (rvn base) (rvn index) scale) (rv-ix-far disp 30 (lo \ (rvo mn [(rvn s) [lo 31]])))])
   (rv-stx base index scale disp s)  (rv-stxn (rv-ws 0) base index scale disp s)
   (rv-stxb base index scale disp s) (rv-stxn 'sb base index scale disp s)
   (rv-leax d base index scale disp)
      (: dn (rvn d) amt (rv-shamt scale)
         (catall [(amt = 0 ? (rvo 'add [dn (rvn index) (rvn base)])
                     (catall [(rvo 'slli [31 (rvn index) amt]) (rvo 'add [dn 31 (rvn base)])]))
                   (? (disp = 0) ()
                      (rv-fits12 disp) (rvo 'addi [dn dn disp])
                      (catall [(rv-li-rec 31 disp) (rvo 'add [dn dn 31])]))]))

   (rv-push s) (catall [(rvo 'addi [2 2 -16]) (rvo (rv-ws 0) [(rvn s) [0 2]])])
   (rv-pop d)  (catall [(rvo (rv-wl 0) [(rvn d) [0 2]]) (rvo 'addi [2 2 16])])

   (rv-decm base off)                                                        ; x30 = [base+off] - 1, stored, against x0
      (: far !(rv-fits12 off)  bn (far ? 31 (rvn base))  o (far ? 0 off)
         (rv-flag-set 0 30 0 -1,
          catall [(far ? (rv-li-rec 31 off + rvo 'add [31 31 (rvn base)]) ())
                  (rvo (rv-wl 0) [30 [o bn]]) (rvo 'addi [30 30 -1]) (rvo (rv-ws 0) [30 [o bn]])]))

   (rv-neg d) (rvo 'sub [(rvn d) 0 (rvn d)])
   (rv-not d) (rvo 'xori [(rvn d) (rvn d) -1])
   (rv-inc d) (rvo 'addi [(rvn d) (rvn d) 1])
   (rv-dec d) (rvo 'addi [(rvn d) (rvn d) -1])

   ;; div/rem never trap: /0 answers -1 or the dividend. rem's t goes unused
   (rv-imul d a b) (rv-aluop 'imul d a b)
   (rv-rrr mn d a b) (rvo mn [(rvn d) (rvn a) (rvn b)])
   (rv-mulh d a b)    (rv-rrr 'mulh d a b)
   (rv-umulh d a b)   (rv-rrr 'mulhu d a b)
   (rv-div d a b)     (rv-rrr 'div d a b)
   (rv-rem d a b t)   (rv-rrr 'rem d a b)
   (rv-udiv d a b)    (rv-rrr 'divu d a b)
   (rv-urem d a b t)  (rv-rrr 'remu d a b)

   ;; no overflow iff mulh equals the low half's sign fill. t must differ from a, b and d
   (rv-mulo d a b t lbl)
      (: dn (rvn d) an (rvn a) bn (rvn b) tn (rvn t)
         (catall [(rvo 'mulh [tn an bn]) (rvo 'mul [dn an bn])
                   (rvo 'srai [31 dn (rv32? 0 ? 31 63)])
                   (rvo 'beq [tn 31 8])                                       ; hop the jal
                   [(fix 4 'j21 lbl (rv-word 'jal [0 0]))]]))

   ;; the 'short hook: every rv-br ends in hop + jal; within +-4KB drop the jal, flip the hop back
   ;; and aim it at the label. a rewrite of the bytes, not a re-lower: by then rv-flags holds
   ;; the text's last cmp, not this br's
   (rvb-fits? rel) (rel >= -4096 && rel <= 4094)
   (rv-first k l)  (k < 1 || !(two? l) ? () (<l . rv-first (k - 1) >l))
   ;; tighter still, c.j and c.beqz/c.bnez: they turn on a distance, so the 'short hook lays
   ;; them, not rvc-squeeze
   (rvj-fits? rel)  (rel >= -2048 && rel <= 2046)
   (rvcb-fits? rel) (rel >= -256 && rel <= 254)
   ;; a B-form -> its c.beqz/c.bnez base word, or (): beq/bne against x0, rs1 in x8..x15, +-256
   (rv-cbase w rel)
      (: f3 (w >> 12 & 7) rs1 (w >> 15 & 31)
         (f3 < 2 && (w >> 20 & 31 = 0 && (rvc-p? rs1 && rvcb-fits? rel)) ?
            (rvc-word (f3 = 0 ? "c.beqz" "c.bnez") [rs1 0 0]) ()))
   (rv-shorten bs label rel)
      (#bs @ n
         (? (n < 5) ()
            !(fix? (bs (n - 1))) ()                  ; the jal fixup
            (: w (bs (n - 5) | (bs (n - 4) << 8
                   | (bs (n - 3) << 16 | bs (n - 2) << 24)))
               (!(w & 127 = 0x63) ? ()                ; after a B-form hop
                  (: base (w & 0x1FFF07F ^ 0x1000)    ; keep rs2/rs1/funct3/op, flip the cond
                     cb (rv-cbase base rel)
                     (rv-first (n - 5) bs
                      + (imm? cb ? [(fix 2 'cb label cb)]
                           [(fix 4 'b13 label base)])))))))

   (rv-jmp label)  [(fix 4 'j21 label (rv-word 'jal [0 0]))]
   ;; an absolute address from a literal laid inline: auipc d, 0; ld d, 16(d); j .+16; nop;
   ;; the word. 8-aligned behind an (align 8), so the load is aligned, and reach is the whole space
   (rv-lia d label) (rvn d @ dn
                      (rvo 'auipc [dn 0] + rvo 'ld [dn [16 dn]] + rvo 'jal [0 16] + rvo 'addi [0 0 0]
                       + [(fix 8 'abs64 label 0)]))
   (rv-jmpr d)     (rvo 'jalr [0 [0 (rvn d)]])
   ;; the table and its targets are for the analyses, not the machine
   (rv-jmpt d tl labs) (rv-jmpr d)
   ;; auipc pairs: aux packs both base words, the auipc low. pc-relative, so la serves lar too
   (rv-pair r lo) (lo * 4294967296 + rv-word 'auipc [r 0])           ; auipc low, its partner high
   (rv-call label) [(fix 8 'pcrel label (rv-pair 1 (rv-word 'jalr [1 [0 1]])))]
   (rv-callr d)    (rvo 'jalr [1 [0 (rvn d)]])
   (rv-la d label) (rvn d @ dn [(fix 8 'pcrel label (rv-pair dn (rv-word 'addi [dn dn 0])))])

   ;; the two-address IR repeats d as the first source. rm: 7 dynamic, 1 toward zero
   rv-fp3 {'addsd (name "fadd.d") 'subsd (name "fsub.d") 'mulsd (name "fmul.d") 'divsd (name "fdiv.d")
           'addss (name "fadd.s") 'subss (name "fsub.s") 'mulss (name "fmul.s") 'divss (name "fdiv.s")}
   (rv-fp3op op d s) (rvf d @ dn (rvo (rv-look rv-fp3 op 'rv-badfp) [dn dn (rvf s) 7]))
   (rv-fo nm vs)   (rvo (name nm) vs)
   (rv-fmov d s)   (rvf s @ sn (rv-fo "fsgnj.d" [(rvf d) sn sn]))
   (rv-fcmp a b)   (rv-flag-set 1 (rvf a) (rvf b) -1)
   (rv-fcmps a b)  (rv-flag-set 2 (rvf a) (rvf b) -1)
   (rv-scvtf d g)  (rv-fo "fcvt.d.l" [(rvf d) (rvn g) 7])
   (rv-fcvtzs g d) (rv-fo "fcvt.l.d" [(rvn g) (rvf d) 1])
   (rv-fmovxr d g) (rv-fo "fmv.d.x" [(rvf d) (rvn g)])
   (rv-fmovrx g d) (rv-fo "fmv.x.d" [(rvn g) (rvf d)])
   (rv-fwiden d s)  (rv-fo "fcvt.d.s" [(rvf d) (rvf s) 0])
   (rv-fnarrow d s) (rv-fo "fcvt.s.d" [(rvf d) (rvf s) 7])                     ; rounds
   (rv-scvtfs d g)  (rv-fo "fcvt.s.l" [(rvf d) (rvn g) 7])
   (rv-fcvtzss g d) (rv-fo "fcvt.l.s" [(rvn g) (rvf d) 1])
   (rv-fmovsw d g)  (rv-fo "fmv.w.x" [(rvf d) (rvn g)])
   (rv-fmovws g d)  (rv-fo "fmv.x.w" [(rvn g) (rvf d)])                         ; sign-extending
   (rv-xorpd d s)                                                            ; zeroing only (d==s)
      (rvf d = rvf s ? (rv-fo "fmv.d.x" [(rvf d) 0]) (scare 'rv-xorpd-general [d s]))

   (rv-tp d) (rvo 'addi [(rvn d) 4 0])

   ;; the system lane, for kernels: every CSR access is one csrr* form. no dots in names: sfence.vma is sfence, fence.i fencei,
   ;; ecall sys, ebreak trap. a bare CSR number passes through (csrw 1985 is the c906's mhcr)
   rv-csrnames {'fflags 0x001 'frm 0x002 'fcsr 0x003
                'cycle 0xC00 'time 0xC01 'instret 0xC02
                'sstatus 0x100 'sie 0x104 'stvec 0x105 'scounteren 0x106
                'sscratch 0x140 'sepc 0x141 'scause 0x142 'stval 0x143
                'sip 0x144 'satp 0x180
                'mstatus 0x300 'misa 0x301 'medeleg 0x302 'mideleg 0x303
                'mie 0x304 'mtvec 0x305 'mcounteren 0x306
                'mscratch 0x340 'mepc 0x341 'mcause 0x342 'mtval 0x343
                'mip 0x344
                'mvendorid 0xF11 'marchid 0xF12 'mimpid 0xF13 'mhartid 0xF14}
   (rv-csr c) (imm? c ? c (look rv-csrnames c 'badcsr))
   (rv-csru u) (0 <= u <= 31 ? u (scare 'rv-csr-uimm u))
   (rv-csrop f3 dn csr sn) (rvo (f3 @ 1 'csrrw 2 'csrrs 3 'csrrc 5 'csrrwi 6 'csrrsi 'csrrci) [dn (rv-csr csr) sn])
   ;; each pseudo is the full form with x0 in the slot it does not name
   (rv-csrr d csr)      (rv-csrop 2 (rvn d) csr 0)
   (rv-csrw csr s)      (rv-csrop 1 0 csr (rvn s))
   (rv-csrs csr s)      (rv-csrop 2 0 csr (rvn s))
   (rv-csrc csr s)      (rv-csrop 3 0 csr (rvn s))
   (rv-csrwi csr u)     (rv-csrop 5 0 csr (rv-csru u))
   (rv-csrsi csr u)     (rv-csrop 6 0 csr (rv-csru u))
   (rv-csrci csr u)     (rv-csrop 7 0 csr (rv-csru u))
   (rv-csrrw d csr s)   (rv-csrop 1 (rvn d) csr (rvn s))
   (rv-csrrs d csr s)   (rv-csrop 2 (rvn d) csr (rvn s))
   (rv-csrrc d csr s)   (rv-csrop 3 (rvn d) csr (rvn s))
   (rv-csrrwi d csr u)  (rv-csrop 5 (rvn d) csr (rv-csru u))
   (rv-csrrsi d csr u)  (rv-csrop 6 (rvn d) csr (rv-csru u))
   (rv-csrrci d csr u)  (rv-csrop 7 (rvn d) csr (rv-csru u))
   ;; rs1 an address, rs2 an ASID; x0 in either means all
   (rv-sfence a b) (rv-fo "sfence.vma" [(rvn a) (rvn b)])

   rv-emitters (emsof
        [('li . rv-li) ('mov . rv-mov) ('cmp . rv-cmp) ('test . rv-test)
          ('imul . rv-imul)
          ('ld . rv-ld) ('st . rv-st)
          ('ld1 . rv-ld1) ('ld2 . rv-ld2) ('ld4 . rv-ld4)
          ('st1 . rv-st1) ('st2 . rv-st2) ('st4 . rv-st4)
          ('ldu1 . rv-ldu1) ('ldu2 . rv-ldu2) ('ldu4 . rv-ldu4)
          ('sx1 . rv-sx 1) ('sx2 . rv-sx 2) ('sx4 . rv-sx 4)
          ('zx1 . rv-zx 1) ('zx2 . rv-zx 2) ('zx4 . rv-zx 4)
          ('shlv . rv-shiftv 'shlv) ('shrv . rv-shiftv 'shrv) ('sarv . rv-shiftv 'sarv)
          ('shl . rv-shift 'shl) ('shr . rv-shift 'shr) ('sar . rv-shift 'sar)
          ('rol . rv-shift 'rol) ('ror . rv-shift 'ror)
          ('lea . rv-lea) ('lean . rv-lea)
          ('push . rv-push) ('pop . rv-pop)
          ('neg . rv-neg) ('not . rv-not) ('inc . rv-inc) ('dec . rv-dec) ('decm . rv-decm)
          ('jmp . rv-jmp) ('br . rv-br) ('jmpr . rv-jmpr) ('jmpt . rv-jmpt) ('callr . rv-callr)
          ('mulo . rv-mulo) ('mulh . rv-mulh) ('umulh . rv-umulh) ('set . rv-set)
          ('adds . rv-addsub-s 'adds) ('subs . rv-addsub-s 'subs)
          ('div . rv-div) ('rem . rv-rem) ('udiv . rv-udiv) ('urem . rv-urem)
          ('ldx . rv-ldx) ('stx . rv-stx) ('leax . rv-leax)
          ('ldxb . rv-ldxb) ('ldxh . rv-ldxh) ('stxb . rv-stxb)
          ('call . rv-call) ('la . rv-la) ('lar . rv-la) ('lia . rv-lia)
          ('tp . rv-tp)
          ('movsd . rv-fmov) ('movapd . rv-fmov) ('movss . rv-fmov)
          ('addsd . rv-fp3op 'addsd) ('subsd . rv-fp3op 'subsd)
          ('mulsd . rv-fp3op 'mulsd) ('divsd . rv-fp3op 'divsd)
          ('ucomisd . rv-fcmp) ('ucomiss . rv-fcmps) ('cvtsi2sd . rv-scvtf) ('cvttsd2si . rv-fcvtzs)
          ('addss . rv-fp3op 'addss) ('subss . rv-fp3op 'subss) ('mulss . rv-fp3op 'mulss) ('divss . rv-fp3op 'divss)
          ('cvtsi2ss . rv-scvtfs) ('cvttss2si . rv-fcvtzss) ('movdxr . rv-fmovsw) ('movdrx . rv-fmovws)
          ('movqxr . rv-fmovxr) ('movqrx . rv-fmovrx)
          ('stsd . rv-fst) ('ldsd . rv-fld) ('stss . rv-fsts) ('ldss . rv-flds)
          ('cvtss2sd . rv-fwiden) ('cvtsd2ss . rv-fnarrow)
          ('xorpd . rv-xorpd)
          ('raw . 1)
          ('ret . rvo 'jalr [0 [0 1]])
          ('sys . rvo 'ecall ())
          ('nop . rvo 'addi [0 0 0])
          ('trap . rvo 'ebreak ())
          ('csrr . rv-csrr) ('csrw . rv-csrw) ('csrs . rv-csrs) ('csrc . rv-csrc)
          ('csrwi . rv-csrwi) ('csrsi . rv-csrsi) ('csrci . rv-csrci)
          ('csrrw . rv-csrrw) ('csrrs . rv-csrrs) ('csrrc . rv-csrrc)
          ('csrrwi . rv-csrrwi) ('csrrsi . rv-csrrsi) ('csrrci . rv-csrrci)
          ('sfence . rv-sfence)
          ('wfi . rvo 'wfi ())
          ('sret . rvo 'sret ()) ('mret . rvo 'mret ())
          ('fence . rvo 'fence [[15 15]])                                   ; fence iorw, iorw
          ('fencei . rv-fo "fence.i" ())])
   _ (map (k \ emrow rv-emitters k (rv-aluop k)) (keys rv-alu))

   ;; rvc: a plain word (no fixup) collapses to a C form when its operands fit. it reads only
   ;; the word, never an address, so lay needs no relaxation for it
   (rvc-p? r)      (r >= 8 && r <= 15)              ; the 3-bit register window x8..x15
   (rvc-p r)       (r - 8)
   (rvc-s6? n)     (n >= -32 && n <= 31)
   (rvc-u? n k hi) (n >= 0 && (n <= hi && n % k = 0))
   (rvc-i12 w)     (w >> 20 & 4095 @ u (u > 2047 ? (u - 4096) u))
   (rvc-s12 w)     ((w >> 25 & 127) << 5 | (w >> 7) & 31 @ u (u > 2047 ? (u - 4096) u))

   (rvc-s16? n)            (n >= -512 && (n <= 496 && n % 16 = 0))

   ;; the C word, or () where no form fits
   (rvc-of w)
    (: op (w & 127) rd (w >> 7 & 31) f3 (w >> 12 & 7)
       rs1 (w >> 15 & 31) rs2 (w >> 20 & 31) f7 (w >> 25 & 127)
       i (rvc-i12 w) s (rvc-s12 w) sh (rs2 | (f7 & 1) << 5)
       (? (op = 0x13)                                                    ; OP-IMM
           (? (f3 = 0 && (!(rd = 0) && (rs1 = rd && (!(i = 0) && rvc-s6? i))))
               (rvco "c.addi" [rd rd i])
              (f3 = 0 && (rd = 2 && (rs1 = 2 && (!(i = 0) && rvc-s16? i))))
               (rvco "c.addi16sp" [2 2 i])
              (f3 = 0 && (!(rd = 0) && (rs1 = 0 && rvc-s6? i)))
               (rvco "c.li" [rd 0 i])
              (f3 = 0 && (!(rd = 0) && (!(rs1 = 0) && (!(rs1 = rd) && i = 0))))
               (rvco "c.mv" [rd rs1 0])                                  ; addi rd, rs, 0
              (f3 = 1 && (!(rd = 0) && (rs1 = rd && (f7 & 126 = 0 && !(sh = 0)))))
               (rvco "c.slli" [rd rd sh])
              (f3 = 5 && (rvc-p? rd && (rs1 = rd && (f7 & 126 = 32 && !(sh = 0)))))
               (rvco "c.srai" [rd rd sh])
              (f3 = 5 && (rvc-p? rd && (rs1 = rd && (f7 & 126 = 0 && !(sh = 0)))))
               (rvco "c.srli" [rd rd sh])
              (f3 = 7 && (rvc-p? rd && (rs1 = rd && rvc-s6? i)))
               (rvco "c.andi" [rd rd i])
              ())
          (op = 0x1b)                                                    ; OP-IMM-32
           (f3 = 0 && (!(rd = 0) && (rs1 = rd && rvc-s6? i)) ?
               (rvco "c.addiw" [rd rd i]) ())
          (op = 0x33)                                                    ; OP
           (? (f3 = 0 && (f7 = 0 && (!(rd = 0) && (rs1 = rd && !(rs2 = 0)))))
               (rvco "c.add" [rd rd rs2])
              (f3 = 0 && (f7 = 0 && (!(rd = 0) && (rs1 = 0 && !(rs2 = 0)))))
               (rvco "c.mv" [rd rs2 0])                                  ; add rd, x0, rs2
              (f3 = 0 && (f7 = 32 && (rvc-p? rd && (rs1 = rd && rvc-p? rs2))))
               (rvco "c.sub" [rd rd rs2])
              (f3 = 4 && (f7 = 0 && (rvc-p? rd && (rs1 = rd && rvc-p? rs2))))
               (rvco "c.xor" [rd rd rs2])
              (f3 = 6 && (f7 = 0 && (rvc-p? rd && (rs1 = rd && rvc-p? rs2))))
               (rvco "c.or" [rd rd rs2])
              (f3 = 7 && (f7 = 0 && (rvc-p? rd && (rs1 = rd && rvc-p? rs2))))
               (rvco "c.and" [rd rd rs2])
              ())
          (op = 0x03)                                                    ; LOAD
           (? (f3 = 3 && (rs1 = 2 && (!(rd = 0) && rvc-u? i 8 504)))
               (rvco "c.ldsp" [rd [i 2]])
              (f3 = 3 && (rvc-p? rs1 && (rvc-p? rd && rvc-u? i 8 248)))
               (rvco "c.ld" [rd [i rs1]])
              ())
          (op = 0x23)                                                    ; store
           (? (f3 = 3 && (rs1 = 2 && rvc-u? s 8 504))
               (rvco "c.sdsp" [rs2 [s 2]])
              (f3 = 3 && (rvc-p? rs1 && (rvc-p? rs2 && rvc-u? s 8 248)))
               (rvco "c.sd" [rs2 [s rs1]])
              ())
          (op = 0x07)                                                    ; LOAD-FP
           (? (f3 = 3 && (rs1 = 2 && rvc-u? i 8 504))
               (rvco "c.fldsp" [rd [i 2]])
              (f3 = 3 && (rvc-p? rs1 && (rvc-p? rd && rvc-u? i 8 248)))
               (rvco "c.fld" [rd [i rs1]])
              ())
          (op = 0x27)                                                    ; store-FP
           (? (f3 = 3 && (rs1 = 2 && rvc-u? s 8 504))
               (rvco "c.fsdsp" [rs2 [s 2]])
              (f3 = 3 && (rvc-p? rs1 && (rvc-p? rs2 && rvc-u? s 8 248)))
               (rvco "c.fsd" [rs2 [s rs1]])
              ())
          (op = 0x67)                                                    ; jalr
           (f3 = 0 && (rd = 0 && (!(rs1 = 0) && i = 0)) ?
               (rvco "c.jr" [0 [0 rs1]]) ())                            ; ret too
          ()))

   ;; word by word through a chunk: plain bytes come four to an instruction, a fixup is one
   ;; element. sound only while no chunk branches a fixed offset over a squeezable word: the hops
   ;; are B-forms clearing exactly a jal fixup
   (rvc-4? bs) (: (go i l) (? (i = 4) 1 !(two? l) 0 !(imm? <l) 0 (go (i + 1) >l))
                  (go 0 bs))
   (rvc-squeeze bs)
    (? !(two? bs) bs
       !(imm? <bs) (<bs . rvc-squeeze >bs)          ; a fixup: its own width, never squeezed
       !(rvc-4? bs) bs                               ; a ragged tail cannot be an instruction
       (: c (rvc-of (bs 0 | (bs 1 << 8 | (bs 2 << 16 | bs 3 << 24))))
          ((two? c ? c (rv-first 4 bs)) + rvc-squeeze >>>>bs)))

   (rv-lower ins) (lower-via @ f
                     (? !(lit? f) (scare 'holo-bake-stale 'lower-via)
                        (<ins = 'raw) (f rv-emitters ins)       ; raw is never squeezed
                        (rvc-squeeze (f rv-emitters ins))))

   ;; pcrel: hi20 into aux's low word (the auipc), lo12 into its high word, hi rounded for a signed lo
   (rv-patch kind target site width aux)
      (target - site @ rb
         (? (kind = 'j21)
            (rb >= -1048576 && rb <= 1048575 ? 0 (scare 'rv-jal-range rb),
             le32 (aux | rve-op 'j rb))
            (kind = 'pcrel)
            (: lo (rv-lo12 rb) hi ((rb - lo) // 4096)
               (hi >= -524288 && hi <= 524287 ? 0 (scare 'rv-pcrel-range rb),
                le32 (aux % 4294967296 | rve-op 'u20 hi) + le32 (aux // 4294967296 | rve-op 'i12 lo)))
            (kind = 'b13)
            (rvb-fits? rb ? 0 (scare 'rv-b13-range rb),
             le32 (aux | rve-op 'b rb))
            (kind = 'cj)
            (rvj-fits? rb ? 0 (scare 'rv-cj-range rb),
             le16 (aux | rvce-op 'cj rb))
            (kind = 'cb)
            (rvcb-fits? rb ? 0 (scare 'rv-cb-range rb),
             le16 (aux | rvce-op 'cb rb))
            (kind = 'abs64) (le64 (target + aux))
            (scare 'badfix kind)))

   ;; the linker's door. rela: bs holds the base words (two for pcrel). () past the field's reach
   (rv-refix kind bs target site width)
    (: (w i) (bs i + (bs (i + 1) << 8) + (bs (i + 2) << 16) + (bs (i + 3) << 24))
       rb (target - site) hi ((rb - rv-lo12 rb) // 4096)
       (? (kind = 'j21 && !(-1048576 <= rb <= 1048575)) ()
          (kind = 'pcrel && !(-524288 <= hi <= 524287)) ()
          (rv-patch kind target site width (kind = 'pcrel ? (w 0 + w 4 * 4294967296) (w 0)))))

   rv {}
   rv32 {}
   (pin rv 'lower rv-lower,
    pin rv 'patch rv-patch,
    pin rv 'refix rv-refix,
   ;; a br's prefix before the hop is plain bytes, so its element count is its byte count
    pin rv 'short (\ ins c rel
      (? (<ins = 'jmp)
         (? (#c != 1) ()                 ; the chunk is the lone jal
            !(fix? <c) ()
            (fix-k <c != 'j21) ()
            (rvj-fits? rel) [(fix 2 'cj (ins 1) (rvc-word "c.j" [0 0]))]
            ())
         (<ins != 'br) ()
         (#c - 5 @ pre
            (pre < 0 || !(rvb-fits? (rel - pre)) ? ()
               (rv-shorten c (ins 2) (rel - pre)))))),
   ;; c.nop pads: at 2 mod 4 a torn wide nop would read as a 32-bit opcode
    pin rv 'nop '(1 0),
   ;; for the rvc fuzz test only
    pin rv 'parts {'rvc-of rvc-of 'rv-patch rv-patch 'rv-cbase rv-cbase},
    defbackend 'rv64 rv,
   ;; rv32 (rv32imac, ILP32): the same lowering at a 4-byte word. no rv32 word is one of the
   ;; W, ld/sd or OP-32 forms, so rvc-of squeezes none into an rv64-only C form
    pins rv32 'lower (ins \ (pin rv-flags 'x 32, rv-lower ins @ b (pin rv-flags 'x 64, b)))
              'patch rv-patch 'refix rv-refix 'short (rv 'short) 'nop '(1 0),
    defbackend 'rv32 rv32))
) ; module 'holo
