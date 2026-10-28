; x64 -- the x86-64 backend for holo, 64-bit operand mode throughout. r0 is rax, where syscalls
; and SysV returns land:
;   sp->rsp  r0->rax r1->rcx r2->rdx r3->rbx  r4->rbp r5->rsi r6->rdi
;   r7->r8 r8->r9 r9->r10 r10->r11 r11->r12 r12->r13 r13->r14 r14->r15
; the awkward bases are sp (rsp needs a SIB) and r4 (rbp has no disp-less form); mem handles both.
; three-address forms lower to two-address: mov d,a first unless d==a, swapped when d==b and the
; op commutes; d==b on a non-commuting op scares.

; the x86 core every mode shares, i386.l included: the ALU group, condition codes, ModRM/SIB,
; segment prefixes, relocation kinds and the short-branch rewrite
(module 'holo
(: ;; op -> (rr-opcode imm-/digit commutative?)
   x86-alu {'add '(1 0 1) 'or '(9 1 1) 'and '(33 4 1)
            'sub '(41 5 0) 'xor '(49 6 1)
            'adds '(1 0 1) 'subs '(41 5 0)}     ; add/sub already set OF, for br vs/vc
   ;; IR name -> the 0F 8x opcode low byte
   x86-cc {'eq 132 'ne 133 'lt 140 'ge 141
           'le 142 'gt 143 'below 130 'ae 131
           'be 134 'above 135 's 136 'ns 137
           'vs 128 'vc 129
           'p 138 'np 139}                        ; parity: ucomisd's unordered
   (x86-jcc c) (look x86-cc c 'badcc)
   (x86-modrm m reg rm) (m << 6 | ((reg & 7) << 3 | rm & 7))
   (x86-sib sc ix bs)   (sc << 6 | ((ix & 7) << 3 | bs & 7))
   (x86-scale s) (s @ 1 0 2 1 4 2 8 3 (scare 'badscale s))
   (x86-shift-ext op) (op @ 'shl 4 'shr 5 'sar 7 'rol 0 'ror 1 (scare 'badshift op))
   ;; the shortest displacement, and a byte forced for a base whose disp-less slot is taken (ebp/r13)
   (x86-md bn disp) (? !(charm? disp) (scare 'mem-disp disp)
                       (disp = 0 && bn & 7 != 5) 0 (fits8 disp) 1 2)
   (x86-dispb md disp) (md @ 0 () 1 [(byte disp)] (le32 disp))
   ;; [base+disp] over register numbers: an esp/r12 base takes a SIB byte
   (x86-mem regf bn disp)
    (: md (x86-md bn disp)
     ((bn & 7 = 4 ? [(x86-modrm md regf 4) (x86-sib 0 4 bn)] [(x86-modrm md regf bn)])
      + x86-dispb md disp))
   ;; [base + index*scale + disp]: always a SIB byte
   (x86-memx regf bn ixn sc disp)
    (: md (x86-md bn disp)
     ([(x86-modrm md regf 4) (x86-sib (x86-scale sc) ixn bn)] + x86-dispb md disp))
   ;; xmm binops: op -> (prefix opcode), prefix 0 for none; modrm.reg d, rm s
   x86-sse {'movupd '(102 16) 'movsd '(242 16) 'movss '(243 16) 'movapd '(0 40) 'movhlps '(0 18) 'unpcklpd '(102 20)   ; movapd lays movaps: the same whole-register copy, a byte shorter
            'mulpd '(102 89) 'addpd '(102 88) 'subpd '(102 92) 'divpd '(102 94)
            'mulsd '(242 89) 'addsd '(242 88) 'subsd '(242 92) 'divsd '(242 94)
            'minsd '(242 93) 'maxsd '(242 95)                                              ; d <- d < s ? d : s (a NaN takes s)
            'xorpd '(102 87) 'pcmpeqd '(102 118) 'andpd '(102 84) 'psubq '(102 251)
            'mulss '(243 89) 'addss '(243 88) 'subss '(243 92) 'divss '(243 94)
            'minss '(243 93) 'maxss '(243 95)
            'cvtss2sd '(243 90) 'cvtsd2ss '(242 90)
            'ucomisd '(102 46) 'ucomiss '(0 46)}
   (x86-seg s) (s @ 'fs [100] 'gs [101] 'es [38] 'cs [46] 'ss [54] 'ds [62] (scare 'x86-seg s))      ; the override prefix for the next form
   ;; pc-relative kinds measure from the field's end; aux is a byte addend
   (x86-patch kind target site width aux)
      (kind @ 'rel32 (le32 (target + aux - (site + width)))
          'rel64 (le64 (target + aux - (site + width)))
          'rel16 (: d (target + aux - (site + width))
                    (-32768 <= d <= 32767 ? 0 (scare 'rel16-range d), le16 d))
          'rel8  (: d (target - (site + width))          ; the relaxer proved the fit; this
                    (fits8 d ? 0 (scare 'rel8-range d),   ; scare is the net under that proof
                     [(byte d)]))
          'abs64 (le64 (target + aux))
         ;; truncated: right only where the address fits (a flat low kernel image, i386)
         'abs32 ((target + aux) % 4294967296 @ v
                   (le32 (v < 0 ? (v + 4294967296) v)))
         ;; a sign-extended dword (pushq $sym), as for a kernel at -2 GiB
         'abs32s ((target + aux) @ v (fits32 v ? (le32 (v < 0 ? (v + 4294967296) v)) (scare 'abs32s-range v)))
         'abs16 ((target + aux) % 65536 @ v (le16 (v < 0 ? (v + 65536) v)))
         'abs8 ((target + aux) % 256 @ v [(v < 0 ? (v + 256) v)])
         'pc8 (: d (target + aux - (site + width))       ; a hand-laid short jump
                 (fits8 d ? 0 (scare 'pc8-range d), [(byte d)]))
         (scare 'badfix kind))
   ;; rel8 measures from the end of the 2-byte short form. a re-lower, not a rewrite: the short
   ;; jump shares no bytes with its long twin
   (x86-short ins c rel)
    (? !(fits8 (rel - 2)) ()
       (<ins == 'jmp) [235 (fix 1 'rel8 (ins 1) 0)]
       [(x86-jcc (ins 1) - 16) (fix 1 'rel8 (ins 2) 0)]))
) ; module 'holo

(module 'holo
(: x64-regs {'sp 4 'r0 0 'r1 1 'r2 2 'r3 3 'r4 5
             'r5 6 'r6 7 'r7 8 'r8 9 'r9 10
             'r10 11 'r11 12 'r12 13 'r13 14 'r14 15}

   x64-alu x86-alu

   x64-cc x86-cc

   (rex w r x b) (64 | (w << 3 | (r << 2 | (x << 1 | b))))    ; 0x40 | wrxb
   modrm x86-modrm
   sib x86-sib
   (hi n) (n >> 3)                                                  ; the REX extension bit
   (lo n) (n & 7)
   (rn r) (look x64-regs r 'badreg)
   ;; REX only when it says something: REX.W, an extended register, or a byte source in 4..7
   ;; for 0x88, where it spells spl/bpl/sil/dil instead of ah/ch/dh/bh
   (mrex w opc r x b)
      (w = 1 || r >= 8 || x >= 8 || b >= 8 || bytesrc? opc r
       ? [(rex w (hi r) (hi x) (hi b))] ())
   (bytesrc? opc r) (opc = '(136) && 4 <= r <= 7)

   ;; opcode /r with Modrm.reg the source, rm the dest
   (alu-rr opcode d s)
      (: dn (rn d) sn (rn s)
         [(rex 1 (hi sn) 0 (hi dn)) opcode (modrm 3 sn dn)])
   ;; 83 /ext ib for a signed byte, else 81 /ext id
   (alu-ri ext d imm)
      (rn d @ dn
         (fits8 imm ?
            [(rex 1 0 0 (hi dn)) 131 (modrm 3 ext dn) (byte imm)]
            ([(rex 1 0 0 (hi dn)) 129 (modrm 3 ext dn)] + le32 imm)))
   (alu-step rr ext d y) (reg? y ? (alu-rr rr d y) (alu-ri ext d y))
   (reg-eq a b) (rn a = rn b)

   (emit-mov d s) (alu-rr 137 d s)                                  ; 89 mov r/m64, r64
   ;; cmp against 0 is test, the same flags: 3 bytes for 4
   (emit-cmp a b) (!(reg? b) && b = 0 ? (emit-test a a) (alu-step 57 7 a b))

   ;; b8+rd id zero-extends an unsigned 32 (5 bytes, 6 with REX.B); C7 /0 id sign-extends a
   ;; negative 32 (7); else movabs (10). a symbol survives arithmetic, so imm is checked a number
   (emit-li d imm)
      (: _ (constellation? imm ? 0 (scare 'badimm imm))
         dn (rn d)
         (? (0 <= imm <= 4294967295)
            ((hi dn = 0 ? () [(rex 0 0 0 1)]) + ((184 | lo dn) . le32 imm))
            (fits32 imm)
            ([(rex 1 0 0 (hi dn)) 199 (modrm 3 0 dn)] + le32 imm)
            ([(rex 1 0 0 (hi dn)) (184 | lo dn)] + le64 imm)))

   ;; a fresh-dest add or sub is one lea, not mov + alu: lea sets no flags, and aluops feed none
   (emit-alu op d a b)
      (: meta (peep x64-alu op 0) rr (meta 0) ext (meta 1) comm (meta 2)
         ;; xor d,d,d zeroes by the 32-bit form: its write clears the top half, and no REX.W
         (? (op = 'xor && reg-eq d a && reg? b && reg-eq d b)
              (rn d @ dn (mrex 0 () dn 0 dn + [49 (modrm 3 dn dn)]))
            (reg-eq d a)                  (alu-step rr ext d b)
            (reg? b && reg-eq d b)    (comm ? (alu-step rr ext d a) (scare 'alias-dst [op d a b]))
            (op = 'add && reg? b)     (emit-leax d a b 1 0)
            (op = 'add && fits32 b)   (emit-lea d a b)
            (op = 'sub && fits32 (0 - b)) (emit-lea d a (0 - b))
            ;; a mask of the low 8/16/32 bits is one movzx or 32-bit mov
            (op = 'and && reg? a && elem b '(255 65535 4294967295))
             (emit-zxm (b @ 255 1 65535 2 4) d a)
            (emit-mov d a + alu-step rr ext d b)))

   ;; 69 /r id (6B /r ib for a byte) is three-address; register-register folds onto two-address 0F AF /r
   (imul-rr d s) (: dn (rn d) sn (rn s) [(rex 1 (hi dn) 0 (hi sn)) 15 175 (modrm 3 dn sn)])
   (imul-ri d a imm) (: dn (rn d) an (rn a)
                        (fits8 imm ? [(rex 1 (hi dn) 0 (hi an)) 107 (modrm 3 dn an) (byte imm)]
                        ([(rex 1 (hi dn) 0 (hi an)) 105 (modrm 3 dn an)] + le32 imm)))
   (emit-imul d a b)
      (reg? b ?
         (? (reg-eq d a) (imul-rr d b)
            (reg-eq d b)  (imul-rr d a)
            (emit-mov d a + imul-rr d b))
         (imul-ri d a b))

   shift-ext x86-shift-ext
   (emit-shift op d c)
      (: dn (rn d) ext (shift-ext op)
       (c @ 1 [(rex 1 0 0 (hi dn)) 209 (modrm 3 ext dn)]                        ; D1 /ext, count 1
        ([(rex 1 0 0 (hi dn)) 193 (modrm 3 ext dn)] + [(byte c)])))             ; C1 /ext ib
   ;; no REX.W: the 32-bit write zero-extends
   (emit-shift4 op d c)
      (: dn (rn d) ext (shift-ext op)
       ((hi dn = 0 ? () [(rex 0 0 0 1)]) +
        (c @ 1 [209 (modrm 3 ext dn)]
         ([193 (modrm 3 ext dn)] + [(byte c)]))))

   (emit-test a b)
      (reg? b ? (: an (rn a) bn (rn b) [(rex 1 (hi bn) 0 (hi an)) 133 (modrm 3 bn an)])    ; 85 /r
         (rn a @ an ([(rex 1 0 0 (hi an)) 247 (modrm 3 0 an)] + le32 b)))                ; F7 /0 id

   ;; rsp cannot index (4 means none), and it is sp, never an r0..r14
   (memx regf base index scale disp) (x86-memx regf (rn base) (rn index) scale disp)
   (x64-memx w opc regf base index scale disp)
    (: fn (rn regf) bn (rn base) ixn (rn index)
     (mrex w opc fn ixn bn + opc + memx fn base index scale disp))
   (emit-ldx d base index scale disp)  (x64-memx 1 '(139) d base index scale disp)     ; 8B    mov r64, [base+index*scale+disp]
   (emit-stx base index scale disp s)  (x64-memx 1 '(137) s base index scale disp)     ; 89    mov [base+index*scale+disp], r64
   (emit-leax d base index scale disp) (x64-memx 1 '(141) d base index scale disp)     ; 8D    lea r64, [base+index*scale+disp]
   (emit-ldxb d base index scale disp) (x64-memx 1 '(15 182) d base index scale disp)  ; 0F B6 movzx r64, BYTE
   (emit-ldxw d base index scale disp) (x64-memx 0 '(139) d base index scale disp)     ; 8B    mov r32, DWORD
   (emit-ldxsw d base index scale disp) (x64-memx 1 '(99) d base index scale disp)     ; 63    movsxd r64, DWORD
   ;; and/or/xor r32 by a DWORD (23/0B/33 /r); the 32-bit write zeroes the top
   (emit-andx4 d base index scale disp) (x64-memx 0 '(35) d base index scale disp)
   (emit-orx4 d base index scale disp) (x64-memx 0 '(11) d base index scale disp)
   (emit-xorx4 d base index scale disp) (x64-memx 0 '(51) d base index scale disp)
   (emit-andm4 d base off) (x64-mem () 0 '(35) d base off)
   (emit-decm base off) (mrex 1 '(255) 1 0 (rn base) + '(255) + mem 1 base off)   ; FF /1  dec qword [base+off], the flags set
   (emit-orm4 d base off) (x64-mem () 0 '(11) d base off)
   (emit-xorm4 d base off) (x64-mem () 0 '(51) d base off)
   (emit-stxb base index scale disp s) (x64-memx 0 '(136) s base index scale disp)     ; 88    mov BYTE, s8

   (mem regf base disp) (x86-mem regf (rn base) disp)
   (x64-mem pfx w opc regf base off)
    (: fn (rn regf) bn (rn base)
     (pfx + mrex w opc fn 0 bn + opc + mem fn base off))
   (emit-ld d base off)   (x64-mem () 1 '(139) d base off)      ; 8B     mov r64, [base+off]
   (emit-st base off s)   (x64-mem () 1 '(137) s base off)      ; 89     mov [base+off], r64
   (emit-lea d base off)  (x64-mem () 1 '(141) d base off)      ; 8D     lea r64, [base+off]
   (emit-ld1 d base off)  (x64-mem () 1 '(15 190) d base off)   ; 0F BE  movsx r64, BYTE
   (emit-ld2 d base off)  (x64-mem () 1 '(15 191) d base off)   ; 0F BF  movsx r64, WORD
   (emit-ld4 d base off)  (x64-mem () 1 '(99) d base off)       ; 63     movsxd r64, DWORD
   (emit-ldu1 d base off) (x64-mem () 1 '(15 182) d base off)   ; 0F B6  movzx r64, BYTE
   (emit-ldu2 d base off) (x64-mem () 1 '(15 183) d base off)   ; 0F B7  movzx r64, WORD
   (emit-ldu4 d base off) (x64-mem () 0 '(139) d base off)      ; 8B     mov r32, DWORD
   (emit-st1 base off s)  (x64-mem () 0 '(136) s base off)      ; 88     mov BYTE, s8
   (emit-st2 base off s)  (x64-mem '(102) 0 '(137) s base off)  ; 66 89  mov WORD, s16
   (emit-st4 base off s)  (x64-mem () 0 '(137) s base off)      ; 89     mov DWORD, s32
   ;; cmpm: the flags of [base+off] - y; cmprm: of s - [base+off]. regf r6 (rdi = 7) spells /7
   (emit-cmpm base off y)
    (? (reg? y) (x64-mem () 1 '(57) y base off)                              ; 39 /r  cmp QWORD, r64
       (fits8 y)
        (x64-mem () 1 '(131) 'r6 base off + [(byte y)])                      ; 83 /7 ib
       (x64-mem () 1 '(129) 'r6 base off + le32 y))                          ; 81 /7 id
   (emit-cmprm s base off) (x64-mem () 1 '(59) s base off)                     ; 3B /r  cmp r64, QWORD

   ;; read-modify-writes on [base+off] at w 1 2 4 8, for inline asm. regf is a register or the
   ;; /digit spelled as the register of that number. base 'rip with off (sym k) is rip-relative;
   ;; tl, the immediate's bytes after the displacement, keeps the fix measuring from the end
   x64-digit '(r0 r1 r2 r3 sp r4 r5 r6)
   (x64-mw w op8 op regf base off tl)
    (: fn (rn regf) rip (base = 'rip) bn (rip ? 0 (rn base))
       rx (w = 8 || fn >= 8 || bn >= 8 || (w = 1 && 4 <= fn <= 7))
       ((w = 2 ? [102] ()) + (rx ? [(rex (w = 8 ? 1 0) (hi fn) 0 (hi bn))])
        + (w = 1 ? op8 op)
        + (rip ? [(modrm 0 (lo fn) 5) (fix 4 'rel32 <off (<>off - tl))] (mem fn base off))))
   (imw w y) (w @ 1 [(byte y)] 2 [(byte y) (byte (y >> 8))] (le32 y))   ; a quad's sign-extends its 32
   (emit-xaddm w base off s) (x64-mw w '(15 192) '(15 193) s base off 0)       ; 0F C0/C1 /r  xadd m, r
   (emit-cmpxchgm w base off s) (x64-mw w '(15 176) '(15 177) s base off 0)    ; 0F B0/B1 /r  cmpxchg m, r
   (emit-xchgm w base off s) (x64-mw w '(134) '(135) s base off 0)             ; 86/87 /r     xchg m, r
   ;; op m, y: 00+8k/01+8k /r, or 80 /k ib, 83 /k ib, 81 /k id|iw
   (emit-alum op w base off y)
    (: k (op @ 'add 0 'or 1 'adc 2 'sbb 3 'and 4 'sub 5 'xor 6 'cmp 7 (scare 'x64-alum op))
       (? (reg? y) (x64-mw w [(8 * k)] [(8 * k + 1)] y base off 0)
          (w = 1) (x64-mw 1 '(128) () (x64-digit k) base off 1 + [(byte y)])
          (fits8 y) (x64-mw w () '(131) (x64-digit k) base off 1 + [(byte y)])
          (imw (w = 8 ? 4 w) y @ iy (x64-mw w () '(129) (x64-digit k) base off #iy + iy))))
   ;; op d, m: 02+8k/03+8k /r
   (emit-alurm op w d base off)
    (: k (op @ 'add 0 'or 1 'adc 2 'sbb 3 'and 4 'sub 5 'xor 6 'cmp 7 (scare 'x64-alurm op))
       (x64-mw w [(8 * k + 2)] [(8 * k + 3)] d base off 0))
   ;; adc/sbb d, y: 10/11 and 18/19 /r, or 80/83/81 /2 /3
   (emit-carry op w d y)
    (: k (op @ 'adc 2 'sbb 3 (scare 'x64-carry op)) dn (rn d)
       yn (reg? y ? (rn y) 0)
       rx (w = 8 || hi dn != 0 || hi yn != 0 || (w = 1 && (4 <= dn <= 7 || 4 <= yn <= 7)))
       pre ((w = 2 ? [102] ()) + (rx ? [(rex (w = 8 ? 1 0) (hi yn) 0 (hi dn))]))
       (? (reg? y) (pre + [(w = 1 ? (8 * k) (8 * k + 1)) (modrm 3 yn dn)])
          (w = 1) (pre + [128 (modrm 3 k dn) (byte y)])
          (fits8 y) (pre + [131 (modrm 3 k dn) (byte y)])
          (pre + [129 (modrm 3 k dn)] + imw (w = 8 ? 4 w) y)))
   ;; test m, y: 84/85 /r, or F6/F7 /0
   (emit-testm w base off y)
    (reg? y ? (x64-mw w '(132) '(133) y base off 0)
       (imw (w = 8 ? 4 w) y @ iy (x64-mw w '(246) '(247) 'r0 base off #iy + iy)))
   ;; inc dec not neg m: FE/FF /0 /1, F6/F7 /2 /3
   (emit-unm op w base off)
    (: d (op @ 'inc 0 'dec 1 'not 2 'neg 3 (scare 'x64-unm op))
       (d < 2 ? (x64-mw w '(254) '(255) (x64-digit d) base off 0)
          (x64-mw w '(246) '(247) (x64-digit d) base off 0)))
   ;; bt bts btr btc m, y: 0F A3/AB/B3/BB /r, or 0F BA /4../7 ib
   (emit-btm op w base off y)
    (: k (op @ 'bt 4 'bts 5 'btr 6 'btc 7 (scare 'x64-btm op))
       (? (w = 1) (scare 'x64-btm-byte op)
          (reg? y) (x64-mw w () [15 (k @ 4 163 5 171 6 179 187)] y base off 0)
          (x64-mw w () '(15 186) (x64-digit k) base off 1 + [(byte y)])))

   ;; store immediate: mov r/m, imm through /0 (regf r0); the quad sign-extends its imm32
   (emit-si base off n)   (x64-mem () 1 '(199) 'r0 base off + le32 n)          ; C7 /0 id  QWORD
   (emit-si1 base off n)  (x64-mem () 0 '(198) 'r0 base off + [(byte n)])      ; C6 /0 ib  BYTE
   (emit-si2 base off n)  (x64-mem '(102) 0 '(199) 'r0 base off + le16 n)      ; 66 C7 /0 iw WORD
   (emit-si4 base off n)  (x64-mem () 0 '(199) 'r0 base off + le32 n)          ; C7 /0 id  DWORD
   ;; the 128-bit kit: a value is rdx:rax (hi:lo), a binop's left at [rsp] lo, [rsp+8] hi. one IR
   ;; form each, so no pass parts a carry pair; the sp operand is for the passes, rsp is fixed.
   ;; the v-shifts branch on cl at run time, 0..127
   (emit-a128 sp9) '(72 3 4 36  72 19 84 36 8)                    ; add rax,[rsp]; adc rdx,[rsp+8]
   (emit-s128 sp9) '(72 41 4 36  72 25 84 36 8                    ; sub [rsp],rax; sbb [rsp+8],rdx
                     72 139 4 36  72 139 84 36 8)                 ; mov rax,[rsp]; mov rdx,[rsp+8]
   (emit-mw128 sp9) '(72 247 36 36)                               ; mul QWORD [rsp] -> rdx:rax
   (emit-m128 sp9) '(72 15 175 20 36                              ; imul rdx,[rsp]       rdx = Rhi*Llo
                     72 139 76 36 8  72 15 175 200                ; mov rcx,[rsp+8]; imul rcx,rax
                     72 1 209                                     ; add rcx,rdx
                     72 247 36 36                                 ; mul QWORD [rsp]      rdx:rax = Llo*Rlo
                     72 1 202)                                    ; add rdx,rcx
   ;; the r-twins: the left in rl:rh (lo, hi). s128r clobbers them
   (emit-a128r rl rh) (alu-rr 1 'r0 rl + (charm? rh ? [72 131 210 (byte rh)] (alu-rr 17 'r2 rh)))   ; add rax,rl; adc rdx,rh|imm8
   (emit-s128r rl rh) (alu-rr 41 rl 'r0 + (alu-rr 25 rh 'r2       ; sub rl,rax; sbb rh,rdx
                     + (emit-mov 'r0 rl + emit-mov 'r2 rh)))
   (emit-mw128r rl) (rn rl @ n [(rex 1 0 0 (hi n)) 247 (modrm 3 4 n)])    ; mul rl -> rdx:rax
   (emit-m128r rl rh)
      (emit-imul 'r2 'r2 rl                                       ; rdx = Rhi*Llo
       + emit-mov 'r1 rh + emit-imul 'r1 'r1 'r0                ; rcx = Lhi*Rlo
       + alu-rr 1 'r1 'r2                                        ; add rcx,rdx
       + emit-mw128r rl                                          ; rdx:rax = Llo*Rlo
       + alu-rr 1 'r2 'r1)                                    ; add rdx,rcx
   (emit-c128r cond rl rh)
      (: chain (emit-mov 'r1 rl + (alu-rr 41 'r1 'r0              ; rcx=rl; sub rcx,rax
                + (emit-mov 'r1 rh + alu-rr 25 'r1 'r2)))         ; rcx=rh; sbb rcx,rdx
         rsub (alu-rr 41 'r0 rl + alu-rr 25 'r2 rh)               ; sub rax,rl; sbb rdx,rh
         (cond @
          ('eq || 'ne)
           (alu-rr 49 'r0 rl + alu-rr 49 'r2 rh                ; xor both words, or them
            + alu-rr 9 'r0 'r2 + emit-set cond 'r0)
          ('lt || 'below || 'ge || 'ae) (chain + emit-set cond 'r0)
          'gt    (rsub + emit-set 'lt 'r0)
          'above (rsub + emit-set 'below 'r0)
          'le    (rsub + emit-set 'ge 'r0)
          'be    (rsub + emit-set 'ae 'r0)
          (scare 'badcc128 cond)))
   (emit-shl128 c)
      (c < 64 ? [72 15 164 194 (byte c)  72 193 224 (byte c)]   ; shld rdx,rax,c; shl rax,c
         (: s9 (c = 64 ? () [72 193 226 (byte (c - 64))])       ; shl rdx,c-64
            ('(72 137 194) + s9 + '(49 192))))                  ; mov rdx,rax; ..; xor eax,eax
   (emit-shr128 c)
      (c < 64 ? [72 15 172 208 (byte c)  72 193 234 (byte c)]   ; shrd rax,rdx,c; shr rdx,c
       (: s9 (c @ 64 () [72 193 232 (byte (c - 64))])       ; shr rax,c-64
        ('(72 137 208) + s9 + '(49 210))))                  ; mov rax,rdx; ..; xor edx,edx
   (emit-sar128 c)
      (c < 64 ? [72 15 172 208 (byte c)  72 193 250 (byte c)]   ; shrd rax,rdx,c; sar rdx,c
       (: s9 (c @ 64 () [72 193 248 (byte (c - 64))])       ; sar rax,c-64
        ('(72 137 208) + s9 + '(72 193 250 63))))           ; mov rax,rdx; ..; sar rdx,63
   ;; u128 in the cell / u64 in rax: qhi = hi/d leaves its remainder in rdx for the low div, so
   ;; neither faults (rdx < d). a zero divisor faults
   (d128-div-pre z9) '(72 137 193                                 ; mov rcx,rax        (d aside)
                  72 139 4 36  72 139 84 36 8                     ; num: rax=[rsp] lo, rdx=[rsp+8] hi
                  72 137 12 36                                    ; mov [rsp],rcx      (d -> the cell)
                  72 137 193  72 137 208  49 210                  ; rcx=lo; rax=hi; xor edx,edx
                  72 247 52 36                                    ; div QWORD [rsp]    (rax=qhi, rdx=r1)
                  72 145                                          ; xchg rax,rcx       (rax=lo, rcx=qhi)
                  72 247 52 36)                                   ; div QWORD [rsp]    (rax=qlo, rdx=rem)
   (emit-dv128 sp9) (d128-div-pre 0 + '(72 137 202))              ; mov rdx,rcx: quotient qhi:qlo
   (emit-rm128 sp9) (d128-div-pre 0 + '(72 137 208  49 210))      ; rax=rem; xor edx,edx
   ;; 0/1 <- (LEFT cond RIGHT). eq/ne xor both words; lt/ge run L-R through rcx; gt/le/above/be
   ;; R-L in place, reading the flipped relation
   (emit-c128 cond sp9)
      (: chain '(72 139 12 36  72 41 193  72 139 76 36 8  72 25 209)  ; mov rcx,[rsp]; sub rcx,rax; mov rcx,[rsp+8]; sbb rcx,rdx
         rsub  '(72 43 4 36  72 27 84 36 8)                       ; sub rax,[rsp]; sbb rdx,[rsp+8]
         (cond @ ('eq || 'ne)
             ('(72 51 4 36  72 51 84 36 8  72 9 208)              ; xor rax,[rsp]; xor rdx,[rsp+8]; or rax,rdx
              + emit-set cond 'r0)
            ('lt || 'below || 'ge || 'ae) (chain + emit-set cond 'r0)
            'gt    (rsub + emit-set 'lt 'r0)
            'above (rsub + emit-set 'below 'r0)
            'le    (rsub + emit-set 'ge 'r0)
            'be    (rsub + emit-set 'ae 'r0)
            (scare 'badcc128 cond)))
   ;; rdx:rax / r -> rax quotient, rdx remainder (F7 /6); the caller stages rdx:rax
   (emit-divq s) (rn s @ sn [(rex 1 0 0 (hi sn)) 247 (modrm 3 6 sn)])
   (emit-divl s) (rn s @ sn (mrex 0 () 0 0 sn + [247 (modrm 3 6 sn)]))   ; edx:eax / r32
   ;; the TLS block's first word is its own address: mov d, fs:[0]
   (emit-tp d)
    (rn d @ dn ([100 (rex 1 (hi dn) 0 0) 139 (modrm 0 (lo dn) 4) (sib 0 4 5)] + le32 0))
   ;; lock cmpxchg [ptr], new: the old value lands in the accumulator, which must be r0
   (emit-cas w acc new ptr)
    (acc @ 'r0 (x64-mem '(240) w '(15 177) new ptr 0)   ; F0 (REX.W) 0F B1
     (scare 'cas-acc acc))
   ;; movsx/movsxd in place
   (emit-sx w d)
    (: dn (rn d)
       opc (w @ 1 '(15 190) 2 '(15 191) '(99))
     ([(rex 1 (hi dn) 0 (hi dn))] + opc + [(modrm 3 (lo dn) (lo dn))]))
   ;; movzx in place; w=4 is mov r32,r32
   (emit-zx w d)
    (rn d @ dn
       (w @ 1 ([(rex 1 (hi dn) 0 (hi dn)) 15 182] + [(modrm 3 (lo dn) (lo dn))])
            2 ([(rex 1 (hi dn) 0 (hi dn)) 15 183] + [(modrm 3 (lo dn) (lo dn))])
              ((hi dn = 0 ? () [(rex 0 1 0 1)]) + [139 (modrm 3 (lo dn) (lo dn))])))
   ;; d = s's low w bytes, zero-extended
   (emit-zxm w d s)
    (: dn (rn d) sn (rn s)
       (w @ 1 ([(rex 1 (hi dn) 0 (hi sn)) 15 182] + [(modrm 3 (lo dn) (lo sn))])
            2 ([(rex 1 (hi dn) 0 (hi sn)) 15 183] + [(modrm 3 (lo dn) (lo sn))])
              ((hi dn = 0 && hi sn = 0 ? () [(rex 0 (hi dn) 0 (hi sn))]) + [139 (modrm 3 (lo dn) (lo sn))])))
   ;; D3 /ext counts by cl, which is why the IR pins the count to r1 (rcx); d must differ
   (emit-shiftv op d c)
      (: dn (reg-eq c 'r1 || (scare 'shiftv-count-not-r1 [op d c]),
             reg-eq d 'r1 && (scare 'shiftv-dst-is-r1 [op d c]),
             rn d)
         ext (op @ 'shlv 4 'shrv 5 'sarv 7 1)      ; rorv/rorv4: /1
         (op @ 'rorv4                                            ; no REX.W, zero-extending
          ((hi dn != 0 ? [(rex 0 0 0 1)]) + [211 (modrm 3 ext (lo dn))])
          ([(rex 1 0 0 (hi dn)) 211] + [(modrm 3 ext (lo dn))])))

   ;; 50+rd / 58+rd, REX.B for r8+; an immediate push is 6A ib or 68 id, sign-extended
   (emit-push s) (? (reg? s) (rn s @ sn (sn >= 8 ? [65 (80 | lo sn)] [(80 | sn)]))
                    (fits8 s) [106 (byte s)]
                    (fits32 s) (104 . le32 s)
                    (scare 'push-imm s))
   (emit-pop  d) (rn d @ dn (dn >= 8 ? [65 (88 | lo dn)] [(88 | dn)]))

   (emit-un opcode ext d) (rn d @ dn [(rex 1 0 0 (hi dn)) opcode (modrm 3 ext dn)])

   (jcc-op c) (look x64-cc c 'badcc)
   (emit-call label) [232 (fix 4 'rel32 label 0)]
   ;; rip-relative lea
   (emit-la d label)
    (rn d @ dn [(rex 1 (hi dn) 0 0) 141 (modrm 0 (lo dn) 5) (fix 4 'rel32 label 0)])
   (emit-laa d label k)
    (rn d @ dn [(rex 1 (hi dn) 0 0) 141 (modrm 0 (lo dn) 5) (fix 4 'rel32 label k)])
   ;; lia: the linked address by movabs, not where the pc runs -- for a kernel linked high that
   ;; runs low until paging is on
   (emit-lia d label)
    (rn d @ dn [(rex 1 0 0 (hi dn)) (184 | lo dn) (fix 8 'abs64 label 0)])
   ;; d <- segment register n (es cs ss ds fs gs = 0..5) by 8C /r; REX.W zero-extends it
   (emit-ldseg d n)
    (rn d @ dn
       (0 <= n <= 5 ? 0 (scare 'x64-segnum n),
        [(rex 1 0 0 (hi dn)) 140 (modrm 3 n dn)]))
   ;; n <- s by 8E /r; segst/segld the pair over memory, 16 bits
   (emit-stseg n s)
    (rn s @ sn
       (0 <= n <= 5 ? 0 (scare 'x64-segnum n),
        (hi sn @ 0 () [(rex 0 0 0 1)]) + [142 (modrm 3 n sn)]))
   (emit-segst n base off) (rn base @ bn ((hi bn != 0 ? [(rex 0 0 0 1)]) + ([140] + mem n base off)))
   (emit-segld n base off) (rn base @ bn ((hi bn != 0 ? [(rex 0 0 0 1)]) + ([142] + mem n base off)))
   (emit-pushl label) [104 (fix 4 'abs32s label 0)]
   ;; opcode bytes over memory, the /digit as the register field
   (emit-mdig opc dig w base off) (x64-mw w opc opc (x64-digit dig) base off 0)
   ;; the same over a register, a legacy prefix ahead of the REX
   (emit-rdig pfx opc dig w r)
    (rn r @ n
       (pfx + (w = 2 ? [102] ()) + ((w = 8 || n >= 8) ? [(rex (w = 8 ? 1 0) 0 0 (hi n))]) + opc + [(modrm 3 dig (lo n))]))
   ;; opc d, s at width w: lar, lsl (0F 02, 0F 03 /r)
   (emit-rrop opc w d s)
    (: dn (rn d) sn (rn s)
       ((w = 2 ? [102] ()) + ((w = 8 || dn >= 8 || sn >= 8) ? [(rex (w = 8 ? 1 0) (hi dn) 0 (hi sn))]) + opc + [(modrm 3 (lo dn) (lo sn))]))
   (emit-invpcid r base off) (x64-mw 2 '(15 56 130) '(15 56 130) r base off 0)   ; 66 0F 38 82 /r  invpcid r, m128
   (emit-movntim w base off s) (x64-mw w '(15 195) '(15 195) s base off 0)   ; 0F C3 /r  movnti m, r
   ;; a string op by its stem (A4..AF, 6C..6F); 66 or REX.W widens the odd byte
   (emit-str op w)
    (: b (op @ 'movs 164 'cmps 166 'stos 170 'lods 172 'scas 174 'ins 108 'outs 110 (scare 'x64-str op))
     ((w = 2 ? [102] ()) + (w = 8 ? [72] ()) + [(w = 1 ? b (b + 1))]))
   (emit-jmp  label)     [233 (fix 4 'rel32 label 0)]
   ;; the table and its targets are for the analyses, not the machine
   (emit-jmpt d tl labs) (emit-jmpr d)
   (emit-br cond label)  [15 (jcc-op cond) (fix 4 'rel32 label 0)]
   ;; the short forms: EB rel8, and the jcc's 0F 8x byte less 0x10
   (emit-jmp8 label)     [235 (fix 1 'rel8 label 0)]
   (emit-br8 cond label) [(jcc-op cond - 16) (fix 1 'rel8 label 0)]
   ;; FF /4 and FF /2; no REX.W, the operand size is 64 already
   (emit-jmpr d) (rn d @ dn ((dn >= 8 ? '(65)) + [255 (modrm 3 4 dn)]))
   (emit-callr d) (rn d @ dn ((dn >= 8 ? '(65)) + [255 (modrm 3 2 dn)]))
   (emit-jmpm base off) (rn base @ bn (mrex 0 '(255) 4 0 bn + [255] + mem 4 base off))
   ;; imul sets OF exactly when the product leaves signed 64, so jo; t is unused
   (emit-mulo d a b t lbl) (emit-imul d a b + [15 128 (fix 4 'rel32 lbl 0)])      ; 0F 80 jo rel32
   ;; the high 64 of the signed (F7 /5) or unsigned (F7 /4) product. rdx:rax-fixed: rdx is
   ;; saved round it; b immediate, rax or rdx goes through a stack cell. clobbers rax; d != r2
   (emit-mulh dig d a b)
      (reg? b && !(reg-eq b 'r0) && !(reg-eq b 'r2) ?
         (rn b @ bn
            (catall ['(82)
                     (reg-eq a 'r0 ? () (emit-mov 'r0 a))
                     [(rex 1 0 0 (hi bn)) 247 (modrm 3 dig bn)]
                     (emit-mov d 'r2) '(90)]))
         (catall ['(82) (emit-push b)
                  (reg-eq a 'r0 ? () (emit-mov 'r0 a))
                  [72 247 (dig = 5 ? 44 36) 36]               ; imul | mul qword [rsp]
                  '(72 137 208  72 131 196 8  90)             ; mov rax,rdx ; add rsp,8 ; pop rdx
                  (reg-eq d 'r0 ? () (emit-mov d 'r0))]))
   ;; REX.W 0F 4x /r, the jcc byte less 0x40; d = s scares
   (emit-cmov cond d s)
      (: dn (rn d) sn (rn s)
         (dn = sn ? (scare 'cmov-alias d)
            [(rex 1 (hi dn) 0 (hi sn)) 15 (jcc-op cond - 64) (modrm 3 dn sn)]))
   ;; setcc d8 then movzx d, d8
   (emit-set cond d) (rn d @ dn (emit-set1 cond d + [(rex 1 (hi dn) 0 (hi dn)) 15 182 (modrm 3 dn dn)]))
   ;; setcc alone (0F 9x, the jcc byte + 0x10), the upper bytes kept. a REX, bare 0x40 for 4..7,
   ;; names the low byte, not ah..bh
   (emit-set1 cond d)
      (: o (jcc-op cond) dn (rn d)
         rb (? (dn >= 8) '(65) (dn >= 4) '(64))
         (rb + [15 (o + 16) (modrm 3 0 dn)]))
   ;; rdx:rax-fixed: rdx is saved round it. a divisor in rax gets a stack cell; one in rdx reads
   ;; the save's. clobbers rax
   (emit-div remf sgn d a b)
      (: bn (rn b)
         cell? (reg-eq b 'r0)
         (catall ['(82)                                    ; push rdx
                   (cell? ? (emit-push b))
                   (reg-eq a 'r0 ? () (emit-mov 'r0 a))
                   (sgn ? '(72 153) '(49 210))             ; cqo | xor edx,edx
                   (cell? || reg-eq b 'r2 ?
                      [72 247 (sgn ? 60 52) 36]            ; idiv (/7) | div (/6) qword [rsp]
                      [(rex 1 0 0 (hi bn)) 247 (modrm 3 (sgn ? 7 6) bn)])
                   (remf ? '(72 137 208))               ; mov rax, rdx
                   (cell? ? '(72 131 196 8))            ; add rsp, 8
                   '(90)                                   ; pop rdx
                   (reg-eq d 'r0 ? () (emit-mov d 'r0))]))

   ;; sse2: fN is xmmN
   x64-xregs (fregs 16)
   (xrn r) (look x64-xregs r 'badxreg)
   x64-sse x86-sse
   (xrex w r b) (mrex w () r 0 b)
   (emit-sse op d s)
      (: meta (peep x64-sse op 0) pfx (meta 0) opc (meta 1) dn (xrn d) sn (xrn s)
         (catall [(pfx @ 0 () [pfx]) (xrex 0 dn sn) [15 opc (modrm 3 dn sn)]]))
   (emit-cmppd d s imm) (: dn (xrn d) sn (xrn s)                                         ; 66 0F C2 /r ib, imm 1 lt 2 le
      (catall ['(102) (xrex 0 dn sn) [15 194 (modrm 3 dn sn) (byte imm)]]))
   (emit-movmskpd g x) (: gn (rn g) xn (xrn x)                                           ; 66 0F 50 /r  gp(reg) <- xmm(rm)
      (catall ['(102) (xrex 0 gn xn) [15 80 (modrm 3 gn xn)]]))
   (emit-cvtsi2sd x g) (: xn (xrn x) gn (rn g)                                           ; F2 REX.W 0F 2A /r  xmm(reg) <- gp(rm)
      (catall ['(242) [(rex 1 (hi xn) 0 (hi gn))] [15 42 (modrm 3 xn gn)]]))
   (emit-cvttsd2si g x) (: gn (rn g) xn (xrn x)                                          ; F2 REX.W 0F 2C /r  gp(reg) <- xmm(rm)
      (catall ['(242) [(rex 1 (hi gn) 0 (hi xn))] [15 44 (modrm 3 gn xn)]]))
   (emit-cvtsi2ss x g) (: xn (xrn x) gn (rn g)                                           ; F3 REX.W 0F 2A /r  xmm(reg) <- gp(rm), single
      (catall ['(243) [(rex 1 (hi xn) 0 (hi gn))] [15 42 (modrm 3 xn gn)]]))
   (emit-cvttss2si g x) (: gn (rn g) xn (xrn x)                                          ; F3 REX.W 0F 2C /r  gp(reg) <- xmm(rm), single
      (catall ['(243) [(rex 1 (hi gn) 0 (hi xn))] [15 44 (modrm 3 gn xn)]]))
   (emit-movdxr x g) (: xn (xrn x) gn (rn g)                                             ; 66 0F 6E /r  xmm(reg) <- gp32(rm)
      (catall ['(102) (xrex 0 xn gn) [15 110 (modrm 3 xn gn)]]))
   (emit-movdrx g x) (: xn (xrn x) gn (rn g)                                             ; 66 0F 7E /r  gp32(rm) <- xmm(reg)
      (catall ['(102) (xrex 0 xn gn) [15 126 (modrm 3 xn gn)]]))
   (emit-movqxr x g) (: xn (xrn x) gn (rn g)                                             ; 66 REX.W 0F 6E /r  xmm(reg) <- gp(rm)
      (catall ['(102) [(rex 1 (hi xn) 0 (hi gn))] [15 110 (modrm 3 xn gn)]]))
   (emit-movqrx g x) (: xn (xrn x) gn (rn g)                                             ; 66 REX.W 0F 7E /r  gp(rm) <- xmm(reg)
      (catall ['(102) [(rex 1 (hi xn) 0 (hi gn))] [15 126 (modrm 3 xn gn)]]))
   ;; movsd/movss to and from memory: F2/F3 0F 11 /r stores, 0F 10 /r loads
   (emit-stsd base disp s)
      (xrn s @ sn (catall ['(242) (xrex 0 sn (rn base)) '(15 17) (mem sn base disp)]))
   (emit-ldsd d base disp)
      (xrn d @ dn (catall ['(242) (xrex 0 dn (rn base)) '(15 16) (mem dn base disp)]))
   (emit-stss base disp s)
      (xrn s @ sn (catall ['(243) (xrex 0 sn (rn base)) '(15 17) (mem sn base disp)]))
   (emit-ldss d base disp)
      (xrn d @ dn (catall ['(243) (xrex 0 dn (rn base)) '(15 16) (mem dn base disp)]))
   ;; the F2/F3 prefix goes ahead of the REX
   (x64-fmemx pfx opc xn base index scale disp)
      (: bn (rn base) ixn (rn index)
         ([pfx] + mrex 0 () xn ixn bn + opc + memx xn base index scale disp))
   (emit-ldsdl d label)                                                                    ; xmm(d) <- [rip+label]
      (xrn d @ dn (catall ['(242) (xrex 0 dn 0) [15 16 (modrm 0 (lo dn) 5)] [(fix 4 'rel32 label 0)]]))
   (emit-ldsdx d base index scale disp) (x64-fmemx 242 '(15 16) (xrn d) base index scale disp)
   (emit-stsdx base index scale disp s) (x64-fmemx 242 '(15 17) (xrn s) base index scale disp)
   (emit-ldssx d base index scale disp) (x64-fmemx 243 '(15 16) (xrn d) base index scale disp)
   (emit-stssx base index scale disp s) (x64-fmemx 243 '(15 17) (xrn s) base index scale disp)

   ;; the system lane, for kernels. lgdt/lidt/invlpg/sgdt/sidt are 0F 01 by Modrm digit; no REX.W
   (emit-m0f digit opc base off)
      (rn base @ bn
         ((hi bn @ 0 () [(rex 0 0 0 1)]) + opc + mem digit base off))
   ;; 0F 20 reads, 0F 22 writes; the CR number in Modrm.reg (REX.R reaches cr8), no REX.W
   (emit-cr opc n g)
      (rn g @ gn
         (0 <= n <= 15 ? 0 (scare 'x64-crnum n),
          (hi n = hi gn = 0 ? () [(rex 0 (hi n) 0 (hi gn))])
          + [15 opc (modrm 3 n gn)]))
   ;; the VMX pointer ops, 0F C7 /6 [paddr] under a legacy prefix, which must lead the REX
   (emit-vmp pre base off)
      (rn base @ bn
       (pre + ((hi bn != 0 ? [(rex 0 0 0 1)]) + ('(15 199) + mem 6 base off))))
   ;; vmread/vmwrite: Modrm.reg the field, rm the GPR; no REX.W
   (emit-vmrw opc f g)
      (: fn (rn f) gn (rn g)
         ((hi fn = hi gn = 0 ? () [(rex 0 (hi fn) 0 (hi gn))])
          + [15 opc (modrm 3 fn gn)]))
   (emit-vmread d f) (emit-vmrw 120 f d)   ; d <- vmcs[f]
   (emit-vmwrite f s) (emit-vmrw 121 f s)  ; vmcs[f] <- s
   (emit-ldcr d n) (emit-cr 32 n d)        ; d <- crn
   (emit-stcr n s) (emit-cr 34 n s)        ; crn <- s
   (emit-lddr d n) (emit-cr 33 n d)        ; d <- drn
   (emit-stdr n s) (emit-cr 35 n s)        ; drn <- s
   (emit-ltr s) (rn s @ sn                 ; 0F 00 /3
    ((hi sn @ 0 () [(rex 0 0 0 1)]) + [15 0 (modrm 3 3 sn)]))
   ;; CD ib for every vector, 3 included: int3 (CC) is trap, and the two differ under vm86
   (emit-int n) (0 <= n <= 255 ? 0 (scare 'x64-int-vector n), [205 n])
   emit-seg x86-seg
   ;; bsr bsf 0F BD/BC, lzcnt tzcnt popcnt F3 0F BD/BC/B8; a 32-bit scan reads the low half only
   (emit-bscan op w d s)
    (: dn (rn d) sn (rn s)
       (w = 1 ? (scare 'x64-bscan-byte op)
          ((w = 2 ? [102] ()) + (elem op '(lzcnt tzcnt popcnt) ? [243])
           + (w = 8 || dn >= 8 || sn >= 8 ? [(rex (w = 8 ? 1 0) (hi dn) 0 (hi sn))] ())
           + [15 (op @ 'bsr 189 'bsf 188 'lzcnt 189 'tzcnt 188 'popcnt 184 (scare 'x64-bscan op))
              (modrm 3 (lo dn) (lo sn))])))

   ;; a row is a partial application, a nullary row its bytes, raw the identity (1)
   x64-emitters (emsof
        [('li . emit-li) ('mov . emit-mov) ('cmp . emit-cmp) ('imul . emit-imul)
         ('ld . emit-ld) ('st . emit-st)
         ('lea . emit-lea) ('lean . emit-lea)              ; lean: the same bytes, unseen by the sibcall escape check
         ('ldx . emit-ldx) ('stx . emit-stx) ('leax . emit-leax)
         ('ldxb . emit-ldxb) ('stxb . emit-stxb) ('ldxw . emit-ldxw) ('ldxsw . emit-ldxsw)
         ('andx4 . emit-andx4) ('orx4 . emit-orx4) ('xorx4 . emit-xorx4) ('andm4 . emit-andm4) ('orm4 . emit-orm4) ('xorm4 . emit-xorm4) ('decm . emit-decm)
         ('ldsdx . emit-ldsdx) ('stsdx . emit-stsdx) ('ldssx . emit-ldssx) ('stssx . emit-stssx)
         ('ldsdl . emit-ldsdl)
         ('ld1 . emit-ld1) ('ld2 . emit-ld2) ('ld4 . emit-ld4)
         ('st1 . emit-st1) ('st2 . emit-st2) ('st4 . emit-st4)
         ('si . emit-si) ('si1 . emit-si1) ('si2 . emit-si2) ('si4 . emit-si4)
         ('cmpm . emit-cmpm) ('cmprm . emit-cmprm)
         ('a128 . emit-a128) ('s128 . emit-s128) ('m128 . emit-m128) ('mw128 . emit-mw128)
         ('a128r . emit-a128r) ('s128r . emit-s128r) ('m128r . emit-m128r)
         ('mw128r . emit-mw128r) ('c128r . emit-c128r)
         ('shl128 . emit-shl128) ('shr128 . emit-shr128) ('sar128 . emit-sar128)
         ('c128 . emit-c128)
         ('divq . emit-divq) ('divl . emit-divl) ('dv128 . emit-dv128) ('rm128 . emit-rm128)
         ('inc128 . '(72 131 192 1  72 131 210 0))             ; add rax,1; adc rdx,0
         ('dec128 . '(72 131 232 1  72 131 218 0))             ; sub rax,1; sbb rdx,0
         ('sx128 . '(72 153))                                  ; cqo
         ('n128 . '(72 247 210  72 247 216  72 131 218 255))   ; not rdx; neg rax; sbb rdx,-1
         ('shl128v . '(128 249 64 114 10                       ; cmp cl,64; jb small
                        72 137 194  72 211 226  49 192  235 7   ; mov rdx,rax; shl rdx,cl; xor eax,eax; jmp done
                        72 15 165 194  72 211 224))             ; small: shld rdx,rax,cl; shl rax,cl
         ('shr128v . '(128 249 64 114 10
                        72 137 208  72 211 232  49 210  235 7   ; mov rax,rdx; shr rax,cl; xor edx,edx
                        72 15 173 208  72 211 234))             ; small: shrd rax,rdx,cl; shr rdx,cl
         ('sar128v . '(128 249 64 114 12
                        72 137 208  72 211 248  72 193 250 63  235 7    ; mov rax,rdx; sar rax,cl; sar rdx,63
                        72 15 173 208  72 211 250))             ; small: shrd rax,rdx,cl; sar rdx,cl
         ('ldu1 . emit-ldu1) ('ldu2 . emit-ldu2) ('ldu4 . emit-ldu4)
         ('cas . emit-cas 1) ('cas4 . emit-cas 0) ('tp . emit-tp)
         ('sx1 . emit-sx 1) ('sx2 . emit-sx 2) ('sx4 . emit-sx 4)
         ('zx1 . emit-zx 1) ('zx2 . emit-zx 2) ('zx4 . emit-zx 4)
         ('shlv . emit-shiftv 'shlv) ('shrv . emit-shiftv 'shrv) ('sarv . emit-shiftv 'sarv)
         ('rorv . emit-shiftv 'rorv) ('rorv4 . emit-shiftv 'rorv4)
         ('shl . emit-shift 'shl) ('shr . emit-shift 'shr) ('sar . emit-shift 'sar)
         ('rol . emit-shift 'rol) ('ror . emit-shift 'ror) ('ror4 . emit-shift4 'ror)
         ('test . emit-test) ('push . emit-push) ('pop . emit-pop)
         ('neg . emit-un 247 3) ('not . emit-un 247 2) ('inc . emit-un 255 0) ('dec . emit-un 255 1)
         ('jmp . emit-jmp) ('br . emit-br) ('jmp8 . emit-jmp8) ('br8 . emit-br8)
         ('jmpr . emit-jmpr) ('jmpm . emit-jmpm) ('jmpt . emit-jmpt) ('callr . emit-callr)
         ('mulo . emit-mulo) ('mulh . emit-mulh 5) ('umulh . emit-mulh 4) ('set . emit-set) ('set1 . emit-set1) ('cmov . emit-cmov)
         ('div . emit-div 0 1) ('udiv . emit-div 0 0)
         ('rem . (\ d a b t (emit-div 1 1 d a b)))         ; t unused: rdx does its work
         ('urem . (\ d a b t (emit-div 1 0 d a b)))
         ('call . emit-call)
         ('la . emit-la) ('laa . emit-laa) ('lar . emit-la)                ; rip-relative serves both
         ('lia . emit-lia) ('ldseg . emit-ldseg) ('stseg . emit-stseg) ('pushl . emit-pushl) ('segst . emit-segst) ('segld . emit-segld)
         ('cmppd . emit-cmppd) ('movmskpd . emit-movmskpd)
         ('cvtsi2sd . emit-cvtsi2sd) ('cvttsd2si . emit-cvttsd2si)
         ('cvtsi2ss . emit-cvtsi2ss) ('cvttss2si . emit-cvttss2si) ('movdxr . emit-movdxr) ('movdrx . emit-movdrx)
         ('movqxr . emit-movqxr) ('movqrx . emit-movqrx)
         ('stsd . emit-stsd) ('ldsd . emit-ldsd) ('stss . emit-stss) ('ldss . emit-ldss)
         ('raw . 1)
         ('ret . '(195)) ('sys . '(15 5)) ('nop . '(144)) ('trap . '(204))
          ; port i/o by dx only (E4..E7 reach just 0..255), the datum al/ax/eax
         ('inb . '(236)) ('inw . '(102 237)) ('inl . '(237))
         ('outb . '(238)) ('outw . '(102 239)) ('outl . '(239))
         ('cld . '(252))
         ('str . emit-str) ('rep . '(243)) ('repne . '(242))
         ('mdig . emit-mdig) ('rdig . emit-rdig) ('rrop . emit-rrop) ('movntim . emit-movntim) ('invpcid . emit-invpcid) ('rdpmc . '(15 51)) ('fninit . '(219 227)) ('fnclex . '(219 226)) ('fwait . '(155)) ('emms . '(15 119))
         ('cli . '(250)) ('sti . '(251)) ('hlt . '(244)) ('pushf . '(156)) ('popf . '(157))
         ('lock . '(240))                   ; the prefix alone, for whatever lays next
         ('ud2 . '(15 11)) ('iretq . '(72 207)) ('swapgs . '(15 1 248))
         ('rdmsr . '(15 50)) ('wrmsr . '(15 48)) ('cpuid . '(15 162)) ('rdtsc . '(15 49))
          ; SVM: vmrun/vmload/vmsave take the vmcb's physical address in rax
         ('vmrun . '(15 1 216)) ('vmload . '(15 1 218)) ('vmsave . '(15 1 219))
         ('stgi . '(15 1 220)) ('clgi . '(15 1 221))
         ('vmlaunch . '(15 1 194)) ('vmxoff . '(15 1 196))
         ('vmxon . emit-vmp '(243)) ('vmclear . emit-vmp '(102)) ('vmptrld . emit-vmp ())
         ('vmread . emit-vmread) ('vmwrite . emit-vmwrite)
         ('sgdt . emit-m0f 0 '(15 1)) ('sidt . emit-m0f 1 '(15 1))
         ('int . emit-int) ('ltr . emit-ltr) ('seg . emit-seg) ('bscan . emit-bscan)
         ('pause . '(243 144)) ('mfence . '(15 174 240)) ('lfence . '(15 174 232)) ('sfencex . '(15 174 248))
         ('stc . '(249)) ('clc . '(248)) ('cmc . '(245))
         ('stac . '(15 1 203)) ('clac . '(15 1 202))    ; SMAP's AC flag
         ('rdpkru . '(15 1 238)) ('wrpkru . '(15 1 239))   ; pkru through eax, ecx and edx 0
         ('xgetbv . '(15 1 208)) ('xsetbv . '(15 1 209))   ; XCR[ecx] <-> edx:eax
         ('wbinvd . '(15 9)) ('invd . '(15 8))
         ('monitor . '(15 1 200)) ('mwait . '(15 1 201))    ; rax the line, ecx/edx the hints
         ('monitorx . '(15 1 250)) ('mwaitx . '(15 1 251)) ('rdtscp . '(15 1 249))   ; rdtscp: aux in ecx
         ('xaddm . emit-xaddm) ('cmpxchgm . emit-cmpxchgm) ('xchgm . emit-xchgm)
         ('alum . emit-alum) ('carry . emit-carry) ('alurm . emit-alurm) ('unm . emit-unm) ('btm . emit-btm) ('testm . emit-testm)
         ('ldcr . emit-ldcr) ('stcr . emit-stcr) ('lddr . emit-lddr) ('stdr . emit-stdr)
         ('lgdt . emit-m0f 2 '(15 1)) ('lidt . emit-m0f 3 '(15 1))
         ('invlpg . emit-m0f 7 '(15 1))])
   _ (map (k \ emrow x64-emitters k (emit-alu k)) (keys x64-alu))
   _ (map (k \ emrow x64-emitters k (emit-sse k)) (keys x64-sse))
   (x64-lower ins) (lower-via @ f (lit? f ? (f x64-emitters ins) (scare 'holo-bake-stale 'lower-via)))

   x64-patch x86-patch

   x64 {'lower x64-lower
        'patch x64-patch
        'nop '(144)
        ;; holo may rewrite (li d 0) to (xor d d d) where the flags are free. flagw lands a whole
        ;; fresh set: inc/dec keep CF, a shift by 0 keeps all, imul/idiv leave some undefined
        'zeroxor 1
        'flagr '(br set cmov adc sbb)
        'flagw '(cmp cmpm cmprm test add sub and or xor andx4 orx4 xorx4 andm4 orm4 xorm4 adds subs neg mulo ucomisd ucomiss)
        'short x86-short}
   (defbackend 'x64 x64))
) ; module 'holo
