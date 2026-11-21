; mips -- the mips32r2 backend for holo: big-endian, o32 linux (the 24Kc and 74Kc), soft float.
; every instruction is one big-endian word; a branch, jump or call fills its delay slot with a nop.
; no flags register: cmp and test keep their operands, br compares in the branch or by slt into
; $1, and set lays the comparison's 0 or 1 straight into its register.
; $1 (at) is holo's scratch and $25 (t9) holds a cmp's or an address's immediate, outside the IR's names.

(module 'holo
(: ;; the instruction table, a row [name match mask kinds]: a word is the row's when
   ;; (w & mask) = match, its operands the kinds in text order (decode.l reads them). llvm's
   ;; readings come first, so a word several rows fit is shown by the first; the encoder
   ;; takes a name's first row too
   (mt-sp ks m r) [<r (r 1) m ks]                                      ; op 0, by funct
   (mt-op ks r) [<r (r 1 << 26) 0xfc000000 ks]
   (mt-ri r) [<r (1 << 26 | r 1 << 16) 0xfc1f0000 '(rs b16)]          ; regimm, by rt
   mips-tab (catall [
     [['nop 0 0xffffffff ()] ['ssnop 0x40 0xffffffff ()] ['ehb 0xc0 0xffffffff ()]
      ['move 0x21 0xfc1f07ff '(rd rs)] ['move 0x25 0xfc1f07ff '(rd rs)]   ; addu, or with $zero
      ['neg 0x22 0xffe007ff '(rd rt)] ['negu 0x23 0xffe007ff '(rd rt)]  ; sub and subu rd, $zero, rt
      ['not 0x27 0xfc1f07ff '(rd rs)]                                  ; nor rd, rs, $zero
      ['b 0x10000000 0xffff0000 '(b16)] ['bal 0x04110000 0xffff0000 '(b16)]
      ['beqz 0x10000000 0xfc1f0000 '(rs b16)] ['bnez 0x14000000 0xfc1f0000 '(rs b16)]
      ['jalr 0xf809 0xfc1fffff '(rs)]]                                 ; the link in $ra
     (map (mt-sp '(rd rs rt) 0xfc0007ff)
          '((add 0x20) (addu 0x21) (sub 0x22) (subu 0x23) (and 0x24) (or 0x25) (xor 0x26)
            (nor 0x27) (slt 0x2a) (sltu 0x2b) (movz 0x0a) (movn 0x0b)))
     (map (mt-sp '(rd rt sa) 0xffe0003f) '((sll 0) (srl 2) (sra 3) (rotr 0x200002)))
     (map (mt-sp '(rd rt rs) 0xfc0007ff) '((sllv 4) (srlv 6) (srav 7) (rotrv 0x46)))
     [['jr 8 0xfc1fffff '(rs)] ['jr 9 0xfc1fffff '(rs)] ['jalr 9 0xfc1f07ff '(rd rs)]   ; jalr $zero is jr
      ['syscall 0xc 0xffffffff ()] ['break 0xd 0xffffffff ()] ['sync 0xf 0xffffffff ()]
      ['mfhi 0x10 0xffff07ff '(rd)] ['mflo 0x12 0xffff07ff '(rd)]
      ['mthi 0x11 0xfc1fffff '(rs)] ['mtlo 0x13 0xfc1fffff '(rs)]
      ['mult 0x18 0xfc00ffff '(rs rt)] ['multu 0x19 0xfc00ffff '(rs rt)]
      ['div 0x1a 0xfc00ffff '(z rs rt)] ['divu 0x1b 0xfc00ffff '(z rs rt)]
      ['teq 0x34 0xfc00ffff '(rs rt)]]
     (map mt-ri '((bltz 0) (bgez 1) (bltzal 16) (bgezal 17)))
     [['j 0x08000000 0xfc000000 '(j26)] ['jal 0x0c000000 0xfc000000 '(j26)]
      ['beq 0x10000000 0xfc000000 '(rs rt b16)] ['bne 0x14000000 0xfc000000 '(rs rt b16)]
      ['blez 0x18000000 0xfc1f0000 '(rs b16)] ['bgtz 0x1c000000 0xfc1f0000 '(rs b16)]
      ['lui 0x3c000000 0xffe00000 '(rt u16)]]
     (map (mt-op '(rt rs i16)) '((addi 8) (addiu 9) (slti 10) (sltiu 11)))
     (map (mt-op '(rt rs u16)) '((andi 12) (ori 13) (xori 14)))
     [['madd 0x70000000 0xfc00ffff '(rs rt)] ['maddu 0x70000001 0xfc00ffff '(rs rt)]
      ['mul 0x70000002 0xfc0007ff '(rd rs rt)]
      ['msub 0x70000004 0xfc00ffff '(rs rt)] ['msubu 0x70000005 0xfc00ffff '(rs rt)]
      ['clz 0x70000020 0xfc0007ff '(rdt rs)]
      ['ext 0x7c000000 0xfc00003f '(rt rs pos exsz)] ['ins 0x7c000004 0xfc00003f '(rt rs pos insz)]
      ['wsbh 0x7c0000a0 0xffe007ff '(rd rt)] ['seb 0x7c000420 0xffe007ff '(rd rt)]
      ['seh 0x7c000620 0xffe007ff '(rd rt)] ['rdhwr 0x7c00003b 0xffe007ff '(rt hw)]]
     (map (mt-op '(rt mem))
          '((lb 0x20) (lh 0x21) (lwl 0x22) (lw 0x23) (lbu 0x24) (lhu 0x25) (lwr 0x26)
            (sb 0x28) (sh 0x29) (swl 0x2a) (sw 0x2b) (swr 0x2e) (ll 0x30) (sc 0x38)))])
   ;; the encoder: each kind laid back where decode.l reads it. a register or immediate is a
   ;; number, a memory (off base), a branch its byte offset from the slot, a jump its target.
   ;; acc is the word so far: ins's size field counts from its position
   (me-op k v acc)
    (k @ 'rd (v << 11) 'rs (v << 21) 'rt (v << 16) 'rdt (v << 11 | v << 16) 'z 0 'hw (v << 11)
         'sa ((v & 31) << 6) 'pos ((v & 31) << 6) 'i16 (v & 0xffff) 'u16 (v & 0xffff)
         'mem (<v & 0xffff | v 1 << 21) 'b16 (v >> 2 & 0xffff) 'j26 (v >> 2 & 0x3ffffff)
         'exsz ((v - 1 & 31) << 11) 'insz (((acc >> 6 & 31) + v - 1 & 31) << 11)
         (scare 'mips-enc-kind k))
   (me-word row vs)
    (: (go w ks vs) (? !(two? ks) w (go (w | me-op <ks <vs w) >ks >vs)) (go (row 1) (row 3) vs))
   mips-byname (foldl (\ t r (peep t <r () = () ? (pin t <r r) t)) {} mips-tab)
   (mips-word mn vs) (peep mips-byname mn () @ row (two? row ? (me-word row vs) (scare 'mips-enc mn)))
   (mo mn vs) (be32 (mips-word mn vs))
   ;; decode.l's operands to the raw ones by the row's kinds: a branch counts from its slot
   (mips-vals row ops pc)
    (map (i \ ops i @ o (? (<o = 'mem) >o (<o = 'lbl && row 3 i = 'b16) (o 1 - pc - 4) (o 1))) ^#ops)
   (mips-enc mn ops pc)
    (peep mips-byname mn () @ row (two? row ? (me-word row (mips-vals row ops pc)) (scare 'mips-enc mn)))

   mips-regs {'r0 2 'r1 3 'r2 4 'r3 5 'r4 6 'r5 7 'r6 8 'r7 9
              'r8 16 'r9 17 'r10 18 'r11 19 'sp 29 'fp 30 'lr 31}
   (mr r) (? (r = 'at) 1 (r = 't9) 25 (look mips-regs r 'badreg))

   (m16? k) (-32768 <= k <= 32767)
   (mu16? k) (0 <= k <= 65535)
   (msx16 k) (((k & 0xffff) ^ 0x8000) - 0x8000)
   (msx32 k) (((k & 0xffffffff) ^ 0x80000000) - 0x80000000)
   mnop (be32 0)

   ;; any word into register number dn: addiu, ori, else lui and ori
   (m-li dn v0)
    (: v (msx32 v0) lo (v & 0xffff) hi (v >> 16 & 0xffff)
       (? (m16? v) (mo 'addiu [dn 0 v])
          (mu16? v) (mo 'ori [dn 0 v])
          (catall [(mo 'lui [dn hi]) (lo = 0 ? () (mo 'ori [dn dn lo]))])))
   (mips-li d imm) (m-li (mr d) imm)
   (mips-mov d s) (mr d = mr s ? () (mo 'addu [(mr d) (mr s) 0]))
   ;; a scratch other than r
   (msc r) (r = 1 ? 25 1)
   ;; d = s + k: addiu, else k through a scratch
   (m-addk dn sn k0)
    (: k (msx32 k0)
       (? (k = 0) (dn = sn ? () (mo 'addu [dn sn 0]))
          (m16? k) (mo 'addiu [dn sn k])
          (catall [(m-li (msc sn) k) (mo 'addu [dn sn (msc sn)])])))
   ;; b as a register number, an immediate through a scratch -> [bytes reg]
   (mbr a b) (reg? b ? [() (mr b)] [(m-li (msc a) b) (msc a)])

   malu {'add 'addu 'sub 'subu 'and 'and 'or 'or 'xor 'xor}
   malui {'and 'andi 'or 'ori 'xor 'xori}
   (mips-alu op d a b)
    (: dn (mr d) an (mr a)
       (? (reg? b) (mo (malu op) [dn an (mr b)])
          (op = 'add) (m-addk dn an b)
          (op = 'sub) (m-addk dn an (0 - b))
          (mu16? b) (mo (malui op) [dn an b])
          (mbr an b @ [bs bn] (bs + mo (malu op) [dn an bn]))))
   (mips-mul d a b) (: an (mr a) (mbr an b @ [bs bn] (bs + mo 'mul [(mr d) an bn])))
   ;; hi or lo of a multiply or divide: op the hi/lo producer, take mfhi or mflo
   (mips-hilo op take d a b)
    (: an (mr a) (mbr an b @ [bs bn] (catall [bs (mo op (elem op '(div divu) ? [0 an bn] [an bn])) (mo take [(mr d)])])))
   (mips-rem op d a b t) (mips-hilo op 'mfhi d a b)

   ;; a load or store of register tn at base + off: off past 16 bits goes through $1
   (m-mem op tn bn off)
    (? (m16? off) (mo op [tn [off bn]])
       (: lo (msx16 off) hi ((off - lo) >> 16 & 0xffff)
          (catall [(mo 'lui [1 hi]) (mo 'addu [1 1 bn]) (mo op [tn [lo 1]])])))
   (mips-ld op d base off) (m-mem op (mr d) (mr base) off)
   (mips-st op base off s) (m-mem op (mr s) (mr base) off)

   (mips-sx w d) (mr d @ dn (w @ 1 (mo 'seb [dn dn]) 2 (mo 'seh [dn dn]) ()))
   (mips-zx w d) (mr d @ dn (w @ 1 (mo 'andi [dn dn 255]) 2 (mo 'andi [dn dn 65535]) ()))
   mshi {'shl 'sll 'shr 'srl 'sar 'sra 'ror4 'rotr}
   mshv {'shlv 'sllv 'shrv 'srlv 'sarv 'srav 'rorv4 'rotrv}
   (mips-shift op d c) (: dn (mr d) k (c & 31) (k = 0 ? () (mo (mshi op) [dn dn k])))
   (mips-shiftv op d c) (mr d @ dn (mo (mshv op) [dn dn (mr c)]))

   (mips-lea d base off) (m-addk (mr d) (mr base) off)
   ;; tn = base + index * scale, the scaled index in $1
   (m-ea tn base index scale)
    (: bn (mr base) in (mr index)
       sh (scale @ 1 0 2 1 4 2 8 3 (scare 'mips-badscale scale))
       (sh = 0 ? (mo 'addu [tn bn in]) (catall [(mo 'sll [1 in sh]) (mo 'addu [tn bn 1])])))
   (mips-leax d base index scale disp) (mr d @ dn (m-ea dn base index scale + m-addk dn dn disp))
   (m-memx op tn base index scale disp)
    (m-ea 1 base index scale
     + (m16? disp ? (mo op [tn [disp 1]]) (m-addk 1 1 disp + mo op [tn [0 1]])))
   (mips-ldx op d base index scale disp) (m-memx op (mr d) base index scale disp)
   (mips-stx op base index scale disp s) (m-memx op (mr s) base index scale disp)

   (mips-push s) (catall [(mo 'addiu [29 29 -16]) (mo 'sw [(mr s) [0 29]])])
   (mips-pop d) (catall [(mo 'lw [(mr d) [0 29]]) (mo 'addiu [29 29 16])])
   (mips-neg d) (mr d @ dn (mo 'subu [dn 0 dn]))
   (mips-not d) (mr d @ dn (mo 'nor [dn dn 0]))

   ;; the last cmp or test: 'a and 'b register numbers, $zero for zero
   mips-flags {}
   (mflag a b) (pin mips-flags 'a a, pin mips-flags 'b b)
   (mips-cmp a b)
    (mr a @ an
       (? (reg? b) (mflag an (mr b), ())
          (b = 0) (mflag an 0, ())
          (mflag an 25, m-li 25 b)))
   (mips-test a b)
    (: an (mr a)
       bs (? (reg? b) (mo 'and [1 an (mr b)]) (mu16? b) (mo 'andi [1 an b])
             (catall [(m-li 25 b) (mo 'and [1 an 25])]))
       (mflag 1 0, bs))
   (mips-decm base off)
    (: bn (mr base)
       (m16? off ? 0 (scare 'mips-decm-far off),
        mflag 1 0,
        catall [(mo 'lw [1 [off bn]]) (mo 'addiu [1 1 -1]) (mo 'sw [1 [off bn]])]))

   ;; a branch to label: its word with the offset left 0, then the delay slot
   (mbf mn regs label) (fix 4 'mb16 label (mips-word mn (regs + [0])) . mnop)
   ;; slt or sltu into $1 then a branch on it: lt (x y) is x < y
   (mslt sl x y nz label) (catall [(mo sl [1 x y]) (mbf (nz ? 'bne 'beq) [1 0] label)])
   (mips-br cond label)
    (: a (mips-flags 'a) b (mips-flags 'b)
       (? (b = 0)
          (cond @ 'eq (mbf 'beq [a 0] label) 'ne (mbf 'bne [a 0] label)
                  ('lt || 's) (mbf 'bltz [a] label) ('ge || 'ns) (mbf 'bgez [a] label)
                  'gt (mbf 'bgtz [a] label) 'le (mbf 'blez [a] label)
                  'below () 'ae (mbf 'beq [0 0] label)
                  'above (mbf 'bne [a 0] label) 'be (mbf 'beq [a 0] label)
                  (scare 'mips-badcc cond))
          (cond @ 'eq (mbf 'beq [a b] label) 'ne (mbf 'bne [a b] label)
                  'lt (mslt 'slt a b 1 label) 'ge (mslt 'slt a b 0 label)
                  'gt (mslt 'slt b a 1 label) 'le (mslt 'slt b a 0 label)
                  'below (mslt 'sltu a b 1 label) 'ae (mslt 'sltu a b 0 label)
                  'above (mslt 'sltu b a 1 label) 'be (mslt 'sltu b a 0 label)
                  (scare 'mips-badcc cond))))
   ;; the condition's 0 or 1 in d: by slt or sltu, flipped by xori, or eq/ne by xor
   (mips-set cond d)
    (: a (mips-flags 'a) b (mips-flags 'b) dn (mr d)
       (fl l) (l + mo 'xori [dn dn 1])
       (cond @ 'eq (catall [(mo 'xor [dn a b]) (mo 'sltiu [dn dn 1])])
               'ne (catall [(mo 'xor [dn a b]) (mo 'sltu [dn 0 dn])])
               ('lt || 's) (mo 'slt [dn a b]) ('ge || 'ns) (fl (mo 'slt [dn a b]))
               'gt (mo 'slt [dn b a]) 'le (fl (mo 'slt [dn b a]))
               'below (mo 'sltu [dn a b]) 'ae (fl (mo 'sltu [dn a b]))
               'above (mo 'sltu [dn b a]) 'be (fl (mo 'sltu [dn b a]))
               (scare 'mips-badcc cond)))

   (mips-jmp label) (mbf 'beq [0 0] label)
   (mips-call label) (fix 4 'mj26 label (mips-word 'jal [0]) . mnop)
   (mips-callr d) (mo 'jalr [(mr d)] + mnop)
   (mips-jmpr d) (mo 'jr [(mr d)] + mnop)
   (mips-jmpt d tl labs) (mips-jmpr d)
   ;; la: lui and addiu, the pair ELF relocates as hi16 and lo16
   (mips-la d label)
    (mr d @ dn [(fix 4 'mhi16 label (mips-word 'lui [dn 0])) (fix 4 'mlo16 label (mips-word 'addiu [dn dn 0]))])

   mips-emitters (emsof
        [('li . mips-li) ('mov . mips-mov) ('cmp . mips-cmp) ('test . mips-test)
          ('add . mips-alu 'add) ('sub . mips-alu 'sub) ('and . mips-alu 'and)
          ('or . mips-alu 'or) ('xor . mips-alu 'xor) ('imul . mips-mul)
          ('umulh . mips-hilo 'multu 'mfhi) ('mulh . mips-hilo 'mult 'mfhi)
          ('div . mips-hilo 'div 'mflo) ('udiv . mips-hilo 'divu 'mflo)
          ('rem . mips-rem 'div) ('urem . mips-rem 'divu)
          ('ror4 . mips-shift 'ror4) ('rorv4 . mips-shiftv 'rorv4) ('decm . mips-decm)
          ('ld . mips-ld 'lw) ('ld4 . mips-ld 'lw) ('ldu4 . mips-ld 'lw) ('st . mips-st 'sw) ('st4 . mips-st 'sw)
          ('ldu1 . mips-ld 'lbu) ('ldu2 . mips-ld 'lhu) ('ld1 . mips-ld 'lb) ('ld2 . mips-ld 'lh)
          ('st1 . mips-st 'sb) ('st2 . mips-st 'sh)
          ('sx1 . mips-sx 1) ('sx2 . mips-sx 2) ('sx4 . mips-sx 4)
          ('zx1 . mips-zx 1) ('zx2 . mips-zx 2) ('zx4 . mips-zx 4)
          ('shl . mips-shift 'shl) ('shr . mips-shift 'shr) ('sar . mips-shift 'sar)
          ('shlv . mips-shiftv 'shlv) ('shrv . mips-shiftv 'shrv) ('sarv . mips-shiftv 'sarv)
          ('lea . mips-lea) ('lean . mips-lea) ('leax . mips-leax)
          ('ldx . mips-ldx 'lw) ('ldxb . mips-ldx 'lbu) ('ldxh . mips-ldx 'lhu)
          ('stx . mips-stx 'sw) ('stxb . mips-stx 'sb)
          ('push . mips-push) ('pop . mips-pop) ('neg . mips-neg) ('not . mips-not)
          ('inc . (d \ m-addk (mr d) (mr d) 1)) ('dec . (d \ m-addk (mr d) (mr d) -1))
          ('clz . (d \ s \ mo 'clz [(mr d) (mr s)]))
          ('set . mips-set) ('jmp . mips-jmp) ('br . mips-br) ('call . mips-call)
          ('jmpr . mips-jmpr) ('jmpt . mips-jmpt) ('callr . mips-callr) ('la . mips-la)
          ('raw . 1)
          ('ret . (mo 'jr [31] + mnop))
          ('sys . (mo 'syscall ()))
          ('nop . mnop)
          ('trap . (mo 'break ()))])
   (mips-lower ins) (lower-via @ f (lit? f ? (f mips-emitters ins) (scare 'holo-bake-stale 'lower-via)))

   ;; a field's word: mb16 counts words from the delay slot, mj26 a word target in the slot's
   ;; 256MB region, mhi16 the half mlo16's signed low half carries into
   (mips-fits? kind target site)
    (? (kind = 'mb16) (target - (site + 4) @ o (0 = o & 3 && -131072 <= o <= 131071))
       (kind = 'mj26) (0 = target & 3 && (site + 4) >> 28 = target >> 28)
       1)
   (mips-field kind target site w)
    (? (kind = 'mb16) (w | (target - (site + 4)) >> 2 & 0xffff)
       (kind = 'mj26) (w | target >> 2 & 0x3ffffff)
       (kind = 'mhi16) (w | (target + 0x8000) >> 16 & 0xffff)
       (kind = 'mlo16) (w | target & 0xffff)
       ; a link's own: a GOT16's lw of a page turned to the lui of the high half, its rt kept
       (kind = 'mgotlui) (0x3c000000 | w & 0x1f0000 | (target + 0x8000) >> 16 & 0xffff)
       (scare 'badfix kind))
   (mips-patch kind target site width aux)
    (? (kind = 'abs32) (be32 (target + aux))
       (mips-fits? kind target site ? (be32 (mips-field kind target site aux))
          (scare 'mips-fix-range [kind target site])))
   ;; a link's field: the word its object left, its field cleared (a REL object's addend rode
   ;; there) and the value or'd in; () out of reach. target is S + A, a branch's A counting
   ;; from the branch itself (-4 to its slot)
   (mips-refix kind bs target site width)
    (: t (kind = 'mb16 ? (target + 4) target)
       w (bs 0 << 24 | bs 1 << 16 | bs 2 << 8 | bs 3)
       m (kind = 'mj26 ? 0x3ffffff 0xffff)
       (? (kind = 'mabs32) (be32 target)
          (mips-fits? kind t site ? (be32 (mips-field kind t site (w & (4294967295 ^ m)))))))

   mips {'lower mips-lower 'patch mips-patch 'refix mips-refix 'nop mnop}
   _ (defbackend 'mips mips))
) ; module 'holo
