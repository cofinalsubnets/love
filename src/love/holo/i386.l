; i386 -- the 32-bit x86 backend for the neutral assembler (src/love/holo/holo.l), and its 16-bit
; twin. one emitter tablet per mode: 'i386 lays protected-mode code, 'i386m16 the same instructions
; for a 16-bit code segment the way gcc's -m16 (gas's .code16gcc) does -- 66 on a 32-bit operand,
; 67 on every memory operand, call and ret 32-bit so a frame keeps its shape, jumps 16-bit.
; every encoding was checked against `objdump -d` (-M i8086 for the twin).
;
; loads after x64.l, whose x86 core (ModRM/SIB, the tables, the relocation kinds) it shares.
; the register file is x64's first eight, no REX anywhere:
;   sp->esp  r0->eax r1->ecx r2->edx r3->ebx  r4->ebp r5->esi r6->edi
; and r7..r14 refuse at the door (i386-lower). only r0..r3 have a byte face: a byte store, setcc or movzx from r4..r6 or sp
; would name ah..bh, so it refuses. the wide ops (the 128-bit kit, REX.W faces) are not rows.

(module 'holo
(: i386-regs {'sp 4 'r0 0 'r1 1 'r2 2 'r3 3 'r4 5 'r5 6 'r6 7}
   (i3rn r) (look i386-regs r 'i386-badreg)
   jcc-op x86-jcc
   modrm x86-modrm
   shift-ext x86-shift-ext
   emit-seg x86-seg
   (mem regf base disp) (x86-mem regf (i3rn base) disp)
   (memx regf base index scale disp) (x86-memx regf (i3rn base) (i3rn index) scale disp)
   (i3b r) (i3rn r @ n (n < 4 ? n (scare 'i386-bytereg r)))     ; a register with a low byte

   ;; the mode's prefixes: a 32-bit operand, a 16-bit one, a memory operand
   (o32 m) (m = 1 ? [102] ())
   (o16 m) (m = 1 ? () [102])
   (a32 m) (m = 1 ? [103] ())
   (ow m w) (w @ 1 () 2 (o16 m) 4 (o32 m) (scare 'i386-width w))

   (i3rr m opc d s) (o32 m + opc + [(modrm 3 (i3rn s) (i3rn d))])
   (i3ri m ext d imm)
    (i3rn d @ dn
       (o32 m + (fits8 imm ? [131 (modrm 3 ext dn) (byte imm)] ([129 (modrm 3 ext dn)] + le32 imm))))
   (i3step m rr ext d y) (reg? y ? (i3rr m [rr] d y) (i3ri m ext d y))
   ;; [base+off] and [base+index*scale+disp] at width w, the register field regf
   (i3mem m w opc regf base off) (a32 m + ow m w + opc + mem (i3rn regf) base off)
   (i3memd m w opc dig base off) (a32 m + ow m w + opc + mem dig base off)
   (i3memx m w opc regf base ix sc dp) (a32 m + ow m w + opc + memx (i3rn regf) base ix sc dp)
   ;; a byte face's register field must have a low byte
   (i3mw m w opc8 opc regf base off) (i3mem m w (w = 1 ? opc8 opc) (w = 1 ? (i3b regf, regf) regf) base off)

   (i3-li m d imm)
    (: _ (constellation? imm ? 0 (scare 'badimm imm))
       _ (-2147483648 <= imm <= 4294967295 || scare 'i386-imm imm)
     (o32 m + [(184 | i3rn d)] + le32 imm))
   (i3-mov m d s) (i3rr m [137] d s)
   (i3-cmp m a b) (!(reg? b) && b = 0 ? (i3-test m a a) (i3step m 57 7 a b))
   (i3-test m a b)
    (reg? b ? (i3rr m [133] a b) (i3rn a @ an (o32 m + [247 (modrm 3 0 an)] + le32 b)))
   (i3-alu m op d a b)
    (: meta (peep x86-alu op 0) rr (meta 0) ext (meta 1) comm (meta 2)
       (? (op = 'xor && reg? a && reg? b && i3rn d = i3rn a = i3rn b) (i3rr m [49] d d)
          (reg? a && i3rn d = i3rn a) (i3step m rr ext d b)
          (reg? b && i3rn d = i3rn b) (comm ? (i3step m rr ext d a) (scare 'alias-dst [op d a b]))
          (op = 'add && reg? b) (i3-leax m d a b 1 0)
          (op = 'add) (i3-lea m d a b)
          (op = 'sub && !(reg? b)) (i3-lea m d a (0 - b))
          (op = 'and && elem b '(255 65535)) (i3-zxm m (b @ 255 1 2) d a)
          (i3-mov m d a + i3step m rr ext d b)))
   (i3-imul m d a b)
    (? !(reg? b) (o32 m + [105 (modrm 3 (i3rn d) (i3rn a))] + le32 b)
       (i3rn d = i3rn a) (o32 m + [15 175 (modrm 3 (i3rn d) (i3rn b))])
       (i3rn d = i3rn b) (o32 m + [15 175 (modrm 3 (i3rn d) (i3rn a))])
       (i3-mov m d a + o32 m + [15 175 (modrm 3 (i3rn d) (i3rn b))]))
   (i3-shift m op d c)
    (: dn (i3rn d) ext (shift-ext op)
     (o32 m + (c = 1 ? [209 (modrm 3 ext dn)] [193 (modrm 3 ext dn) (byte c)])))
   (i3-shiftv m op d c)
    (: _ (i3rn c = 1 || scare 'shiftv-count-not-r1 [op d c])
       _ (i3rn d = 1 && scare 'shiftv-dst-is-r1 [op d c])
     (o32 m + [211 (modrm 3 (op @ 'shlv 4 'shrv 5 'sarv 7 1) (i3rn d))]))

   (i3-lea m d base off) (i3mem m 4 [141] d base off)
   (i3-leax m d base ix sc dp) (i3memx m 4 [141] d base ix sc dp)
   (i3-st1 m base off s) (i3b s, i3mem m 1 [136] s base off)
   (i3-stxb m base ix sc dp s) (i3b s, i3memx m 1 [136] s base ix sc dp)
   (i3-si m w base off n) (i3memd m w (w = 1 ? [198] [199]) 0 base off + (w @ 1 [(byte n)] 2 (le16 n) (le32 n)))
   (i3-cmpm m base off y)
    (? (reg? y) (i3mem m 4 [57] y base off)
       (fits8 y) (i3memd m 4 [131] 7 base off + [(byte y)])
       (i3memd m 4 [129] 7 base off + le32 y))

   ;; the sized read-modify-writes, inline asm's: w 1 2 4. base 'rip with off (sym k) is that
   ;; symbol's absolute address, ModRM's disp32-only face -- 32-bit mode has no rip
   (i3-mw m w op8 op regf base off)
    (: fn (charm? regf ? regf (w = 1 ? (i3b regf) (i3rn regf)))
     (base = 'rip
        ? (a32 m + ow m w + (w = 1 ? op8 op) + [(modrm 0 fn 5) (fix 4 'abs32 <off <>off)])
        (a32 m + ow m w + (w = 1 ? op8 op) + mem fn base off)))
   (i3imw w y) (w @ 1 [(byte y)] 2 (le16 y) (le32 y))
   (i3-alum m op w base off y)
    (: k (op @ 'add 0 'or 1 'adc 2 'sbb 3 'and 4 'sub 5 'xor 6 'cmp 7 (scare 'i386-alum op))
       (? (reg? y) (i3-mw m w [(8 * k)] [(8 * k + 1)] y base off)
          (w = 1) (i3-mw m 1 [128] () k base off + [(byte y)])
          (fits8 y) (i3-mw m w () [131] k base off + [(byte y)])
          (i3-mw m w () [129] k base off + i3imw w y)))
   (i3-carry m op w d y)
    (: k (op @ 'adc 2 'sbb 3 (scare 'i386-carry op))
       dn (w = 1 ? (i3b d) (i3rn d))
       (? (reg? y) (ow m w + [(w = 1 ? (8 * k) (8 * k + 1)) (modrm 3 (w = 1 ? (i3b y) (i3rn y)) dn)])
          (w = 1) [128 (modrm 3 k dn) (byte y)]
          (fits8 y) (ow m w + [131 (modrm 3 k dn) (byte y)])
          (ow m w + [129 (modrm 3 k dn)] + i3imw w y)))
   (i3-testm m w base off y)
    (reg? y ? (i3-mw m w [132] [133] y base off)
       (i3-mw m w [246] [247] 0 base off + i3imw w y))
   (i3-unm m op w base off)
    (: d (op @ 'inc 0 'dec 1 'not 2 'neg 3 (scare 'i386-unm op))
       (i3-mw m w (d < 2 ? [254] [246]) (d < 2 ? [255] [247]) d base off))
   (i3-btm m op w base off y)
    (: k (op @ 'bt 4 'bts 5 'btr 6 'btc 7 (scare 'i386-btm op))
       (? (w = 1) (scare 'i386-btm-byte op)
          (reg? y) (i3-mw m w () [15 (k @ 4 163 5 171 6 179 187)] y base off)
          (i3-mw m w () [15 186] k base off + [(byte y)])))
   (i3-cas m acc new ptr)
    (acc @ 'r0 ([240] + i3mem m 4 [15 177] new ptr 0) (scare 'cas-acc acc))
   ;; the thread pointer: linux i386 keeps it in gs, the block's first word the pointer itself
   (i3-tp m d) ([101] + a32 m + o32 m + [139 (modrm 0 (i3rn d) 5)] + le32 0)

   ;; movsx/movzx r32 from a register's low byte or word; the 32-bit faces are the register itself
   (i3-sx m w d) (w = 4 ? () (o32 m + [15 (w @ 1 190 191) (modrm 3 (i3rn d) (w = 1 ? (i3b d) (i3rn d)))]))
   (i3-zx m w d) (w = 4 ? () (i3-zxm m w d d))
   (i3-zxm m w d s)
    (w = 4 ? (i3-mov m d s)
       (o32 m + [15 (w @ 1 182 183) (modrm 3 (i3rn d) (w = 1 ? (i3b s) (i3rn s)))]))

   (i3-push m s)
    (? (reg? s) (o32 m + [(80 | i3rn s)])
       (fits8 s) (o32 m + [106 (byte s)])
       (o32 m + (104 . le32 s)))
   (i3-pop m d) (o32 m + [(88 | i3rn d)])
   (i3-un m opc ext d) (o32 m + [opc (modrm 3 ext (i3rn d))])

   ;; control. call is 32-bit in both modes; a jump's displacement is the mode's own width
   (i3-call m label) (o32 m + [232 (fix 4 'rel32 label 0)])
   (i3-jmp m label) (m = 1 ? [233 (fix 2 'rel16 label 0)] [233 (fix 4 'rel32 label 0)])
   (i3-br m cond label)
    (m = 1 ? [15 (jcc-op cond) (fix 2 'rel16 label 0)] [15 (jcc-op cond) (fix 4 'rel32 label 0)])
   (i3-jmpr m d) (o32 m + [255 (modrm 3 4 (i3rn d))])
   (i3-callr m d) (o32 m + [255 (modrm 3 2 (i3rn d))])
   (i3-jmpm m base off) (i3memd m 4 [255] 4 base off)
   (i3-jmpt m d tl labs) (i3-jmpr m d)
   ;; a label's address: absolute, as gcc -fno-pic lays it. lar is the translation-invariant
   ;; one, where the image runs: call the next instruction, pop it, add the distance
   (i3-la m d label) (i3-laa m d label 0)
   (i3-laa m d label k) (o32 m + [(184 | i3rn d) (fix 4 'abs32 label k)])
   (i3-lar m d label)
    (i3rn d @ dn
       (: tail (o32 m + [(88 | dn)] + o32 m + [129 (modrm 3 0 dn)])
          (o32 m + [232 0 0 0 0] + tail + [(fix 4 'rel32 label (#tail + 4))])))
   (i3-pushl m label) (o32 m + [104 (fix 4 'abs32 label 0)])

   (i3-set1 m cond d) [15 (jcc-op cond + 16) (modrm 3 0 (i3b d))]
   (i3-set m cond d) (i3-set1 m cond d + i3-zxm m 1 d d)
   (i3-cmov m cond d s)
    (i3rn d = i3rn s ? (scare 'cmov-alias d) (o32 m + [15 (jcc-op cond - 64) (modrm 3 (i3rn d) (i3rn s))]))
   (i3-mulo m d a b t lbl) (i3-imul m d a b + (m = 1 ? [15 128 (fix 2 'rel16 lbl 0)] [15 128 (fix 4 'rel32 lbl 0)]))
   ;; div/rem and the high multiply: edx:eax-fixed, so edx is saved round them and a divisor in
   ;; eax or edx goes through a stack cell. clobbers eax; d must not be r2
   (i3-div m remf sgn d a b)
    (: cell? (i3rn b = 0 || i3rn b = 2)
       (catall [(o32 m + [82])
                (cell? ? (i3-push m b))
                (i3rn a = 0 ? () (i3-mov m 'r0 a))
                (o32 m + (sgn ? [153] [49 210]))                        ; cdq | xor edx,edx
                (cell? ? (a32 m + o32 m + [247 (sgn ? 60 52) 36])        ; idiv | div [esp]
                   (o32 m + [247 (modrm 3 (sgn ? 7 6) (i3rn b))]))
                (remf ? (o32 m + [137 208]))                             ; mov eax,edx
                (cell? ? (o32 m + [131 196 4]))                          ; add esp,4
                (o32 m + [90])                                           ; pop edx
                (i3rn d = 0 ? () (i3-mov m d 'r0))]))
   (i3-mulh m dig d a b)
    (: cell? (!(reg? b) || i3rn b = 0 || i3rn b = 2)
       (catall [(o32 m + [82])
                (cell? ? (i3-push m b))
                (reg? a && i3rn a = 0 ? () (i3-mov m 'r0 a))
                (cell? ? (a32 m + o32 m + [247 (dig = 5 ? 44 36) 36]) (o32 m + [247 (modrm 3 dig (i3rn b))]))
                (o32 m + [137 208])                                      ; mov eax,edx
                (cell? ? (o32 m + [131 196 4]))
                (o32 m + [90])
                (i3rn d = 0 ? () (i3-mov m d 'r0))]))
   (i3-divl m s) (o32 m + [247 (modrm 3 6 (i3rn s))])

   (i3-ldseg m d n) (0 <= n <= 5 || scare 'i386-segnum n, o32 m + [140 (modrm 3 n (i3rn d))])
   (i3-stseg m n s) (0 <= n <= 5 || scare 'i386-segnum n, [142 (modrm 3 n (i3rn s))])
   (i3-segst m n base off) (i3memd m 1 [140] n base off)
   (i3-segld m n base off) (i3memd m 1 [142] n base off)
   (i3-cr m opc n g) (0 <= n <= 7 || scare 'i386-crnum n, [15 opc (modrm 3 n (i3rn g))])
   (i3-m0f m dig opc base off) (i3memd m 1 opc dig base off)
   (i3-mdig m opc dig w base off) (w = 8 ? (scare 'i386-width w) (i3-mw m w opc opc dig base off))
   (i3-rdig m pfx opc dig w r) (w = 8 ? (scare 'i386-width w) (pfx + ow m w + opc + [(modrm 3 dig (i3rn r))]))
   (i3-str m op w)
    (: b (op @ 'movs 164 'cmps 166 'stos 170 'lods 172 'scas 174 'ins 108 'outs 110 (scare 'i386-str op))
     (ow m w + [(w = 1 ? b (b + 1))]))
   (i3-bscan m op w d s)
    (? (w = 1 || w = 8) (scare 'i386-bscan-width op)
       (ow m w + (elem op '(lzcnt tzcnt popcnt) ? [243])
        + [15 (op @ 'bsr 189 'bsf 188 'lzcnt 189 'tzcnt 188 'popcnt 184 (scare 'i386-bscan op))
           (modrm 3 (i3rn d) (i3rn s))]))
   (i3-int m n) (0 <= n <= 255 || scare 'i386-int-vector n, [205 n])

   ;; the tablet for a mode
   (i386-ems m)
    (: t (emsof
          [('li . i3-li m) ('mov . i3-mov m) ('cmp . i3-cmp m) ('test . i3-test m) ('imul . i3-imul m)
           ('ld . i3mem m 4 [139]) ('st . (\ b o s (i3mem m 4 [137] s b o)))
           ('lea . i3-lea m) ('lean . i3-lea m)
           ('ld1 . i3mem m 4 [15 190]) ('ld2 . i3mem m 4 [15 191]) ('ld4 . i3mem m 4 [139])
           ('ldu1 . i3mem m 4 [15 182]) ('ldu2 . i3mem m 4 [15 183]) ('ldu4 . i3mem m 4 [139])
           ('st1 . i3-st1 m) ('st2 . (\ b o s (i3mem m 2 [137] s b o))) ('st4 . (\ b o s (i3mem m 4 [137] s b o)))
           ('si . i3-si m 4) ('si1 . i3-si m 1) ('si2 . i3-si m 2) ('si4 . i3-si m 4)
           ('ldx . i3memx m 4 [139]) ('stx . (\ b i s d r (i3memx m 4 [137] r b i s d))) ('leax . i3-leax m)
           ('ldxb . i3memx m 4 [15 182]) ('stxb . i3-stxb m) ('ldxw . i3memx m 4 [139]) ('ldxsw . i3memx m 4 [139])
           ('andx4 . i3memx m 4 [35]) ('orx4 . i3memx m 4 [11]) ('xorx4 . i3memx m 4 [51])
           ('andm4 . i3mem m 4 [35]) ('orm4 . i3mem m 4 [11]) ('xorm4 . i3mem m 4 [51])
           ('cmpm . i3-cmpm m) ('cmprm . i3mem m 4 [59])
           ('cas . i3-cas m) ('cas4 . i3-cas m) ('tp . i3-tp m)
           ('sx1 . i3-sx m 1) ('sx2 . i3-sx m 2) ('sx4 . i3-sx m 4)
           ('zx1 . i3-zx m 1) ('zx2 . i3-zx m 2) ('zx4 . i3-zx m 4)
           ('shlv . i3-shiftv m 'shlv) ('shrv . i3-shiftv m 'shrv) ('sarv . i3-shiftv m 'sarv)
           ('rorv . i3-shiftv m 'rorv) ('rorv4 . i3-shiftv m 'rorv4)
           ('shl . i3-shift m 'shl) ('shr . i3-shift m 'shr) ('sar . i3-shift m 'sar)
           ('rol . i3-shift m 'rol) ('ror . i3-shift m 'ror) ('ror4 . i3-shift m 'ror)
           ('push . i3-push m) ('pop . i3-pop m)
           ('neg . i3-un m 247 3) ('not . i3-un m 247 2) ('inc . i3-un m 255 0) ('dec . i3-un m 255 1)
           ('call . i3-call m) ('jmp . i3-jmp m) ('br . i3-br m)
           ('jmp8 . (\ l [235 (fix 1 'rel8 l 0)])) ('br8 . (\ c l [(jcc-op c - 16) (fix 1 'rel8 l 0)]))
           ('jmpr . i3-jmpr m) ('jmpm . i3-jmpm m) ('jmpt . i3-jmpt m) ('callr . i3-callr m)
           ('la . i3-la m) ('laa . i3-laa m) ('lia . i3-la m) ('lar . i3-lar m) ('pushl . i3-pushl m)
           ('set . i3-set m) ('set1 . i3-set1 m) ('cmov . i3-cmov m) ('mulo . i3-mulo m)
           ('mulh . i3-mulh m 5) ('umulh . i3-mulh m 4)
           ('div . i3-div m 0 1) ('udiv . i3-div m 0 0)
           ('rem . (\ d a b t (i3-div m 1 1 d a b))) ('urem . (\ d a b t (i3-div m 1 0 d a b)))
           ('divl . i3-divl m)
           ('xaddm . (\ w b o s (i3-mw m w [15 192] [15 193] s b o)))
           ('cmpxchgm . (\ w b o s (i3-mw m w [15 176] [15 177] s b o)))
           ('xchgm . (\ w b o s (i3-mw m w [134] [135] s b o)))
           ('alum . i3-alum m) ('carry . i3-carry m) ('unm . i3-unm m) ('btm . i3-btm m) ('testm . i3-testm m)
           ('movntim . (\ w b o s (i3-mw m w [15 195] [15 195] s b o)))
           ('ldseg . i3-ldseg m) ('stseg . i3-stseg m) ('segst . i3-segst m) ('segld . i3-segld m)
           ('ldcr . (\ d n (i3-cr m 32 n d))) ('stcr . (\ n s (i3-cr m 34 n s)))
           ('lddr . (\ d n (i3-cr m 33 n d))) ('stdr . (\ n s (i3-cr m 35 n s)))
           ('ltr . (\ s [15 0 (modrm 3 3 (i3rn s))]))
           ('lgdt . i3-m0f m 2 [15 1]) ('lidt . i3-m0f m 3 [15 1])
           ('sgdt . i3-m0f m 0 [15 1]) ('sidt . i3-m0f m 1 [15 1]) ('invlpg . i3-m0f m 7 [15 1])
           ('mdig . i3-mdig m) ('rdig . i3-rdig m) ('str . i3-str m) ('bscan . i3-bscan m)
           ('int . i3-int m) ('seg . emit-seg) ('raw . 1)
           ('ret . (o32 m + [195])) ('iretq . [207]) ('sys . [205 128])
           ('nop . [144]) ('trap . [204]) ('ud2 . [15 11])
           ('inb . [236]) ('inw . (o16 m + [237])) ('inl . (o32 m + [237]))
           ('outb . [238]) ('outw . (o16 m + [239])) ('outl . (o32 m + [239]))
           ('pushf . (o32 m + [156])) ('popf . (o32 m + [157]))
           ('cld . [252]) ('rep . [243]) ('repne . [242]) ('lock . [240])
           ('cli . [250]) ('sti . [251]) ('hlt . [244])
           ('rdmsr . [15 50]) ('wrmsr . [15 48]) ('cpuid . [15 162]) ('rdtsc . [15 49]) ('rdpmc . [15 51])
           ('fninit . [219 227]) ('fnclex . [219 226]) ('fwait . [155]) ('emms . [15 119])
           ('pause . [243 144]) ('mfence . [15 174 240]) ('lfence . [15 174 232]) ('sfencex . [15 174 248])
           ('stc . [249]) ('clc . [248]) ('cmc . [245]) ('stac . [15 1 203]) ('clac . [15 1 202])
           ('rdpkru . [15 1 238]) ('wrpkru . [15 1 239]) ('xgetbv . [15 1 208]) ('xsetbv . [15 1 209])
           ('wbinvd . [15 9]) ('invd . [15 8]) ('monitor . [15 1 200]) ('mwait . [15 1 201])])
       _ (map (k \ emrow t k (i3-alu m k)) (keys x86-alu))
       t)
   i386-ems32 (i386-ems 0)
   i386-ems16 (i386-ems 1)
   ;; a register past r6 has no 32-bit face
   i386-wide '(r7 r8 r9 r10 r11 r12 r13 r14)
   (i386-lower ems ins)
    (: _ (each >ins (o \ elem o i386-wide && scare 'i386-badreg [o ins]))
     (lower-via ems ins))
   (i386-be ems)
    {'lower (i386-lower ems)
     'patch x86-patch
     'nop '(144)
     'zeroxor 1
     'flagr '(br set cmov adc sbb)
     'flagw '(cmp cmpm cmprm test add sub and or xor andx4 orx4 xorx4 andm4 orm4 xorm4 adds subs neg mulo)
     'short x86-short}
   _ (defbackend 'i386 (i386-be i386-ems32))
   (defbackend 'i386m16 (i386-be i386-ems16)))
) ; module 'holo
