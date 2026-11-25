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
     ((bn & 7 @ 4 [(x86-modrm md regf 4) (x86-sib 0 4 bn)] [(x86-modrm md regf bn)])
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
      (kind @ ('rel32 || 'pc32) (le32 (target + aux - (site + width)))
          'rel64 (le64 (target + aux - (site + width)))
          'rel16 (: d (target + aux - (site + width))
                    (-32768 <= d <= 32767 ? 0 (scare 'rel16-range d), le16 d))
          'rel8  (: d (target - (site + width))          ; the relaxer proved the fit; this
                    (fits8 d ? 0 (scare 'rel8-range d),   ; scare is the net under that proof
                     [(byte d)]))
          'abs64 (le64 (target + aux))
         ;; truncated: right only where the address fits (a flat low kernel image, i386)
         ('abs32 || 'abs32d) ((target + aux) % 4294967296 @ v
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
;; the instruction table, one row an encoding: [name map opcode kinds attrs]. map 0 is the
;; one-byte map, 1 0F, 2 0F 38, 3 0F 3A. kinds in Intel order (dest first), a role and a width:
;; G the modrm reg field, E its r/m, V and W the same as xmm, Z a register in the opcode's low
;; bits, A the accumulator, CL, S a segment register, C D a control or debug register, N an
;; indirect r/m, T an x87 st(i) in r/m and K the stack's top, Q the segment register sr names,
;; O an absolute address (moffs), DX the port register; under VEX, H the vvvv register, B
;; a general one there, L one in an immediate's high nibble; I a signed immediate kept with its
;; size, U an unsigned one, ub a bare byte, J a relative target. widths: b w d q 1 2 4 8, v the
;; operand size (66, REX.W), p a push's (64 unless 66), y 4 or 8 by REX.W, z an immediate's 2 or
;; 4; a bare V W H L the row's vector, x an xmm, y a ymm. attrs: p the mandatory prefix (none 66
;; f3 f2), d the modrm digit, mod r or m, rm the whole modrm byte, b REX.B, w REX.W (VEX.W), ow
;; the operand size, iw the item's width when not its first register's (p a push's, o the
;; operand size), i64 a row a 64-bit segment refuses, sr Q's register, x rep and repne go to
;; a mandatory f3 or f2, ate the rep it reads, fw a wait that may lead an escape, vex or evex
;; its length L (0 xmm, 1 ymm, 2 zmm), n the bytes an EVEX disp8 counts in
(: x6t-cc '(o no b ae e ne be a s ns p np l ge le g)
   (x6t-ccn pre k) (name (pre + show (x6t-cc k)))
   x6t-alu '(add or adc sbb and sub xor cmp)
   x6t-grp2 '(rol ror rcl rcr shl shr shl sar)
   ;; rows by the modrm digit: names in digit order, () for none
   (x6t-dig mp op ks at nms) (catmap (d \ (d < #nms ? (nms d) ()) @ () () n [[n mp op ks (pin (x6t-at at) 'd d)]]) ^8)
   (x6t-at at) (foldl (\ t p (pin t <p (p 1))) {} at)
   (x6t-r nm mp op ks at) [nm mp op ks (x6t-at at)]
   ;; an SSE row under each prefix lane, name base + ps pd ss sd
   (x6t-lane base op ks)
    (map (l \ x6t-r (name (base + l 1)) 1 op ks [['p <l] '(x 1)]) '((none "ps") (66 "pd") (f3 "ss") (f2 "sd")))
   (x6t-px op ks l x) (map (e \ x6t-r (e 1) 1 op ks ((<e = 'any ? () [['p <e]]) + (x ? '((x 1)) ()))) l)
   ;; VEX and EVEX rows, one a length of ls; a v-twin is its legacy row's name after v
   (x6t-v nm mp op ks at ls) (map (l \ x6t-r nm mp op ks ([['vex l]] + at)) ls)
   (x6t-e nm mp op ks at ls) (map (l \ x6t-r nm mp op ks ([['evex l]] + at)) ls)
   (x6t-vn nm) (name ("v" + show nm))
   x6t-l01 '(0 1)
   ; the three-byte SSE rows under 66: 0F 38 xx, 0F 3A xx ib
   x6t-s38 '((1 phaddw) (2 phaddd) (3 phaddsw) (4 pmaddubsw) (5 phsubw) (6 phsubd) (7 phsubsw) (8 psignb)
             (9 psignw) (10 psignd) (11 pmulhrsw) (40 pmuldq) (41 pcmpeqq) (43 packusdw) (55 pcmpgtq)
             (56 pminsb) (57 pminsd) (58 pminuw) (59 pminud) (60 pmaxsb) (61 pmaxsd) (62 pmaxuw) (63 pmaxud)
             (64 pmulld) (220 aesenc) (221 aesenclast) (222 aesdec) (223 aesdeclast))
   x6t-s3a '((12 blendps) (13 blendpd) (68 pclmulqdq))
   x6t-sx '((32 pmovsxbw) (33 pmovsxbd) (34 pmovsxbq) (35 pmovsxwd) (36 pmovsxwq) (37 pmovsxdq)
            (48 pmovzxbw) (49 pmovzxbd) (50 pmovzxbq) (51 pmovzxwd) (52 pmovzxwq) (53 pmovzxdq))
   ; the v-twins whose sources commute: clang lays the r/m one in vvvv when that drops VEX to C5
   x6t-vcomm '(paddb paddw paddd paddq pand por pxor pmullw pmuludq pmulhw pmulhuw pmaddwd pcmpeqb pcmpeqw
               pcmpeqd pminub pmaxub pminsw pmaxsw pavgb pavgw paddusb paddusw paddsb paddsw psadbw
               addps addpd mulps mulpd andps andpd orps orpd xorps xorpd)
   x6t-xsh '(psrlw psrld psrlq psraw psrad psllw pslld psllq)
   x6t-p66 '((96 punpcklbw) (97 punpcklwd) (98 punpckldq) (99 packsswb) (100 pcmpgtb) (101 pcmpgtw)
             (102 pcmpgtd) (103 packuswb) (104 punpckhbw) (105 punpckhwd) (106 punpckhdq) (107 packssdw)
             (108 punpcklqdq) (109 punpckhqdq) (116 pcmpeqb) (117 pcmpeqw) (118 pcmpeqd)
             (212 paddq) (213 pmullw) (218 pminub) (219 pand) (222 pmaxub) (223 pandn)
             (224 pavgb) (227 pavgw) (228 pmulhuw) (229 pmulhw) (234 pminsw) (235 por)
             (238 pmaxsw) (239 pxor) (244 pmuludq) (245 pmaddwd)
             (209 psrlw) (210 psrld) (211 psrlq) (216 psubusb) (217 psubusw) (220 paddusb) (221 paddusw)
             (225 psraw) (226 psrad) (232 psubsb) (233 psubsw) (236 paddsb) (237 paddsw)
             (241 psllw) (242 pslld) (243 psllq) (246 psadbw)
             (248 psubb) (249 psubw) (250 psubd) (251 psubq) (252 paddb) (253 paddw) (254 paddd))
   x64-tab (catall [
     ;; the ALU block 00-3F, the op in bits 5..3
     (catmap (o \ (: b (o * 8) n (x6t-alu o)
                     [(x6t-r n 0 b '(Eb Gb) ()) (x6t-r n 0 (b + 1) '(Ev Gv) ()) (x6t-r n 0 (b + 2) '(Gb Eb) ())
                      (x6t-r n 0 (b + 3) '(Gv Ev) ()) (x6t-r n 0 (b + 4) '(Ab Ib) ()) (x6t-r n 0 (b + 5) '(Av Iz) ())]))
             ^8)
     (map (r \ x6t-r 'push 0 (80 + r) '(Zp) ()) ^8) (map (r \ x6t-r 'pop 0 (88 + r) '(Zp) ()) ^8)
     [(x6t-r 'movsl 0 99 '(Gv Ed) ()) (x6t-r 'push 0 104 '(Iz) '((iw p))) (x6t-r 'push 0 106 '(Ib) '((iw p)))
      (x6t-r 'imul 0 105 '(Gv Ev Iz) ()) (x6t-r 'imul 0 107 '(Gv Ev Ib) ())]
     (map (k \ x6t-r (x6t-ccn "j" k) 0 (112 + k) '(Jb) ()) ^16)
     (x6t-dig 0 128 '(Eb Ib) () x6t-alu) (x6t-dig 0 129 '(Ev Iz) () x6t-alu) (x6t-dig 0 131 '(Ev Ib) () x6t-alu)
     [(x6t-r 'test 0 132 '(Eb Gb) ()) (x6t-r 'test 0 133 '(Ev Gv) ()) (x6t-r 'xchg 0 134 '(Eb Gb) ())
      (x6t-r 'xchg 0 135 '(Ev Gv) ()) (x6t-r 'mov 0 136 '(Eb Gb) ()) (x6t-r 'mov 0 137 '(Ev Gv) ())
      (x6t-r 'mov 0 138 '(Gb Eb) ()) (x6t-r 'mov 0 139 '(Gv Ev) ()) (x6t-r 'lea 0 141 '(Gv Ev) ())
      ; a segment register in the reg field: 8C stores it to r/m, 8E loads it
      (x6t-r 'mov 0 140 '(Ev S) '((iw 2))) (x6t-r 'mov 0 142 '(S Ev) '((iw 2))) (x6t-r 'pop 0 143 '(Ep) ())
      (x6t-r 'pause 0 144 () '((p f3) (ate 1))) (x6t-r 'xchg 0 144 '(Zv Av) '((b 1)))
      (x6t-r 'xchg 0 144 '(Aw Aw) '((p 66)))                    ; 66 90: the two-byte nop's spelling
      (x6t-r 'nop 0 144 () ())]
     (map (r \ x6t-r 'xchg 0 (145 + r) '(Zv Av) ()) ^7)
     ; ..the accumulator or the register written first, the same bytes; after, so a decode reads its own
     [(x6t-r 'xchg 0 144 '(Av Zv) '((b 1)))] (map (r \ x6t-r 'xchg 0 (145 + r) '(Av Zv) ()) ^7)
     [(x6t-r 'xchg 0 134 '(Gb Eb) ()) (x6t-r 'xchg 0 135 '(Gv Ev) ())]
     [(x6t-r 'cbw 0 152 () '((ow 2))) (x6t-r 'cdqe 0 152 () '((ow 8))) (x6t-r 'cwde 0 152 () '((ow 4)))
      (x6t-r 'cwd 0 153 () '((ow 2))) (x6t-r 'cqo 0 153 () '((ow 8))) (x6t-r 'cdq 0 153 () '((ow 4)))
      (x6t-r 'sahf 0 158 () ()) (x6t-r 'lahf 0 159 () ()) (x6t-r 'fwait 0 155 () '((fw 1)))]
     ;; the x87 escapes d8..df: memory by the digit, at&t's names carrying the width
     (catmap (e \ x6t-dig 0 (216 + <e) '(Ed) '((mod m) (iw 0)) (e 1))
             '((0 (fadds fmuls fcoms fcomps fsubs fsubrs fdivs fdivrs))
               (1 (flds () fsts fstps fldenv fldcw fnstenv fnstcw))
               (2 (fiaddl fimull ficoml ficompl fisubl fisubrl fidivl fidivrl))
               (3 (fildl fisttpl fistl fistpl () fldt () fstpt))
               (4 (faddl fmull fcoml fcompl fsubl fsubrl fdivl fdivrl))
               (5 (fldl fisttpll fstl fstpl frstor () fnsave fnstsw))
               (6 (fiadds fimuls ficoms ficomps fisubs fisubrs fidivs fidivrs))
               (7 (filds fisttps fists fistps fbld fildll fbstp fistpll))))
     ; ..over the stack: T st(i) in r/m, K the top. dc's sub and div are at&t's, as gas and llvm read them
     (x6t-dig 0 216 '(K T) '((mod r)) '(fadd fmul () () fsub fsubr fdiv fdivr))
     (x6t-dig 0 216 '(T) '((mod r)) '(() () fcom fcomp))
     (x6t-dig 0 217 '(T) '((mod r)) '(fld fxch))
     (x6t-dig 0 218 '(K T) '((mod r)) '(fcmovb fcmove fcmovbe fcmovu))
     (x6t-dig 0 219 '(K T) '((mod r)) '(fcmovnb fcmovne fcmovnbe fcmovnu () fucomi fcomi))
     (x6t-dig 0 220 '(T K) '((mod r)) '(fadd fmul () () fsub fsubr fdiv fdivr))
     (x6t-dig 0 221 '(T) '((mod r)) '(ffree () fst fstp fucom fucomp))
     (x6t-dig 0 222 '(T K) '((mod r)) '(faddp fmulp () () fsubp fsubrp fdivp fdivrp))
     (x6t-dig 0 223 '(T) '((mod r)) '(ffreep))
     (x6t-dig 0 223 '(K T) '((mod r)) '(() () () () () fucomip fcomip))
     ; ..and the whole modrm byte
     (map (e \ x6t-r (e 1) 0 <e () [['rm (e 2)]])
          '((217 fnop 208) (217 fchs 224) (217 fabs 225) (217 ftst 228) (217 fxam 229) (217 fld1 232)
            (217 fldl2t 233) (217 fldl2e 234) (217 fldpi 235) (217 fldlg2 236) (217 fldln2 237) (217 fldz 238)
            (217 f2xm1 240) (217 fyl2x 241) (217 fptan 242) (217 fpatan 243) (217 fxtract 244) (217 fprem1 245)
            (217 fdecstp 246) (217 fincstp 247) (217 fprem 248) (217 fyl2xp1 249) (217 fsqrt 250) (217 fsincos 251)
            (217 frndint 252) (217 fscale 253) (217 fsin 254) (217 fcos 255) (218 fucompp 233)
            (219 fnclex 226) (219 fninit 227) (222 fcompp 217)))
     [(x6t-r 'fnstsw 0 223 '(Aw) '((rm 224)))]
     ;; the string ops, Intel's names (the AT&T shower respells movsd's)
     (catmap (e \ (: op <e b (e 1)
                     [(x6t-r (name (b + "b")) 0 op () ()) (x6t-r (name (b + "w")) 0 (op + 1) () '((ow 2)))
                      (x6t-r (name (b + (e 2))) 0 (op + 1) () '((ow 8)))  (x6t-r (name (b + "d")) 0 (op + 1) () '((ow 4)))]))
             '((164 "movs" "q") (166 "cmps" "q") (170 "stos" "q") (172 "lods" "q") (174 "scas" "q")
               (108 "ins" "d") (110 "outs" "d")))
     [(x6t-r 'test 0 168 '(Ab Ib) ()) (x6t-r 'test 0 169 '(Av Iz) ())]
     (map (r \ x6t-r 'mov 0 (176 + r) '(Zb Ib) ()) ^8) (map (r \ x6t-r 'mov 0 (184 + r) '(Zv Uv) ()) ^8)
     (x6t-dig 0 192 '(Eb Ib) () x6t-grp2) (x6t-dig 0 193 '(Ev Ib) () x6t-grp2)
     (x6t-dig 0 208 '(Eb) () x6t-grp2) (x6t-dig 0 209 '(Ev) () x6t-grp2)
     (x6t-dig 0 210 '(Eb CL) () x6t-grp2) (x6t-dig 0 211 '(Ev CL) () x6t-grp2)
     [(x6t-r 'ret 0 195 () '((ow 2) (iw 2))) (x6t-r 'ret 0 195 () ()) (x6t-r 'ret 0 194 '(Uw) '((iw 0)))
      (x6t-r 'mov 0 198 '(Eb Ib) ()) (x6t-r 'mov 0 199 '(Ev Iz) ())
      (x6t-r 'leave 0 201 () ()) (x6t-r 'int3 0 204 () ()) (x6t-r 'int 0 205 '(ub) ()) (x6t-r 'xlat 0 215 () ())
      (x6t-r 'call 0 232 '(Jz) ()) (x6t-r 'jmp 0 233 '(Jz) ()) (x6t-r 'jmp 0 235 '(Jb) ())
      (x6t-r 'loopne 0 224 '(Jb) ()) (x6t-r 'loope 0 225 '(Jb) ()) (x6t-r 'loop 0 226 '(Jb) ()) (x6t-r 'jrcxz 0 227 '(Jb) ())
      (x6t-r 'hlt 0 244 () ()) (x6t-r 'cmc 0 245 () ()) (x6t-r 'clc 0 248 () ()) (x6t-r 'stc 0 249 () ())
      (x6t-r 'cli 0 250 () ()) (x6t-r 'sti 0 251 () ()) (x6t-r 'cld 0 252 () ()) (x6t-r 'std 0 253 () ())
      (x6t-r 'pushf 0 156 () '((ow 2) (iw 2))) (x6t-r 'pushf 0 156 () ()) (x6t-r 'pushf 0 156 () '((iw p)))
      (x6t-r 'popf 0 157 () '((ow 2) (iw 2))) (x6t-r 'popf 0 157 () ()) (x6t-r 'popf 0 157 () '((iw p)))]
     (x6t-dig 0 246 '(Eb Ib) () '(test test)) (x6t-dig 0 246 '(Eb) () '(() () not neg mul imul div idiv))
     (x6t-dig 0 247 '(Ev Iz) () '(test test)) (x6t-dig 0 247 '(Ev) () '(() () not neg mul imul div idiv))
     (x6t-dig 0 254 '(Eb) () '(inc dec)) (x6t-dig 0 255 '(Ev) () '(inc dec))
     (x6t-dig 0 255 '(Nq) '((iw 0)) '(() () call () jmp)) (x6t-dig 0 255 '(Ep) () '(() () () () () () push))
     ;; the 0F map: the system lane
     (map (e \ x6t-r (e 1) 1 <e () ()) '((5 syscall) (11 ud2) (119 emms) (8 invd) (9 wbinvd) (51 rdpmc)
                                       (48 wrmsr) (49 rdtsc) (50 rdmsr) (162 cpuid) (52 sysenter) (53 sysexit) (6 clts)))
     [(x6t-r 'sysretq 1 7 () '((ow 8))) (x6t-r 'sysretl 1 7 () '((ow 4))) (x6t-r 'sysret 1 7 () ())
      (x6t-r 'lar 1 2 '(Gv Ev) ()) (x6t-r 'lsl 1 3 '(Gv Ev) ())]
     (x6t-dig 1 0 '(Ew) '((iw 0) (mod m)) '(sldt str)) (x6t-dig 1 0 '(Ew) '((iw 0)) '(() () lldt () verr verw)) (x6t-dig 1 0 '(Ew) () '(() () () ltr))
     [(x6t-r 'nop 1 31 '(Ev) ())]                                       ; the long nops
     (x6t-dig 1 24 '(Eq) '((mod m) (iw 0)) '(prefetchnta prefetcht0 prefetcht1 prefetcht2))
     [(x6t-r 'endbr64 1 30 () '((p f3) (rm 250) (x 1))) (x6t-r 'endbr32 1 30 () '((p f3) (rm 251) (x 1)))]
     (map (e \ x6t-r (e 1) 1 1 () [['rm <e]])
          '((248 swapgs) (208 xgetbv) (209 xsetbv) (249 rdtscp) (202 clac) (200 monitor) (201 mwait)
            (250 monitorx) (251 mwaitx) (203 stac) (238 rdpkru) (239 wrpkru) (193 vmcall) (217 vmmcall)))
     (x6t-dig 1 1 '(Eq) '((mod m) (iw 0)) '(sgdt sidt lgdt lidt () () () invlpg))
     [(x6t-r 'mov 1 32 '(Eq C) ()) (x6t-r 'mov 1 34 '(C Eq) ()) (x6t-r 'mov 1 33 '(Eq D) ()) (x6t-r 'mov 1 35 '(D Eq) ())
      (x6t-r 'vmread 1 120 '(Eq Gq) ()) (x6t-r 'vmwrite 1 121 '(Gq Eq) ())]
     (x6t-dig 1 199 '(Eq) '((mod m) (w 1) (iw 0)) '(() cmpxchg16b)) (x6t-dig 1 199 '(Eq) '((mod m) (iw 0)) '(() cmpxchg8b))
     (x6t-dig 1 199 '(Eq) '((mod m) (p none) (w 1) (iw 0)) '(() () () xrstors64 xsavec64 xsaves64))
     (x6t-dig 1 199 '(Eq) '((mod m) (p none) (iw 0)) '(() () () xrstors xsavec xsaves))
     (map (e \ x6t-r (e 1) 1 199 '(Eq) [['p <e] '(d 6) '(x 1) '(iw 0)]) '((none vmptrld) (66 vmclear) (f3 vmxon) (f2 vmptrld)))
     (map (k \ x6t-r (x6t-ccn "cmov" k) 1 (64 + k) '(Gv Ev) ()) ^16)
     (map (k \ x6t-r (x6t-ccn "j" k) 1 (128 + k) '(Jz) ()) ^16)
     (map (k \ x6t-r (x6t-ccn "set" k) 1 (144 + k) '(Eb) ()) ^16)
     [(x6t-r 'imul 1 175 '(Gv Ev) ()) (x6t-r 'movzb 1 182 '(Gv Eb) ()) (x6t-r 'movzw 1 183 '(Gv Ew) ())
      (x6t-r 'movsb 1 190 '(Gv Eb) ()) (x6t-r 'movsw 1 191 '(Gv Ew) ())
      (x6t-r 'cmpxchg 1 176 '(Eb Gb) ()) (x6t-r 'cmpxchg 1 177 '(Ev Gv) ())
      (x6t-r 'xadd 1 192 '(Eb Gb) ()) (x6t-r 'xadd 1 193 '(Ev Gv) ())
      (x6t-r 'bt 1 163 '(Ev Gv) ()) (x6t-r 'bts 1 171 '(Ev Gv) ()) (x6t-r 'btr 1 179 '(Ev Gv) ()) (x6t-r 'btc 1 187 '(Ev Gv) ())]
     (x6t-dig 1 186 '(Ev Ib) () '(() () () () bt bts btr btc))
     [(x6t-r 'shld 1 164 '(Ev Gv Ib) ()) (x6t-r 'shrd 1 172 '(Ev Gv Ib) ())
      (x6t-r 'shld 1 165 '(Ev Gv CL) ()) (x6t-r 'shrd 1 173 '(Ev Gv CL) ())
      ; the scans, and under F3 the counts
      (x6t-r 'tzcnt 1 188 '(Gv Ev) '((p f3) (x 1))) (x6t-r 'bsf 1 188 '(Gv Ev) ())
      (x6t-r 'lzcnt 1 189 '(Gv Ev) '((p f3) (x 1))) (x6t-r 'bsr 1 189 '(Gv Ev) ())
      (x6t-r 'movnti 1 195 '(Ev Gv) ())
      (x6t-r 'invpcid 2 130 '(Gq Eq) '((p 66) (x 1) (iw 0)))
      ; the three-byte SSE rows: pshufb, the sha256 rounds and schedule, palignr and pblendw ib
      (x6t-r 'pshufb 2 0 '(V W) '((p 66) (x 1)))
      (x6t-r 'sha256rnds2 2 203 '(V W) '((p none) (x 1))) (x6t-r 'sha256msg1 2 204 '(V W) '((p none) (x 1)))
      (x6t-r 'sha256msg2 2 205 '(V W) '((p none) (x 1)))
      (x6t-r 'pblendw 3 14 '(V W ub) '((p 66) (x 1))) (x6t-r 'palignr 3 15 '(V W ub) '((p 66) (x 1)))]
     (x6t-dig 1 174 '(Ev) '((p f3) (mod r) (x 1) (iw 0)) '(rdfsbase rdgsbase wrfsbase wrgsbase wrgsbase wrgsbase wrgsbase wrgsbase))
     [(x6t-r 'popcnt 1 184 '(Gv Ev) '((p f3) (x 1)))
      ; the fences: 0F AE with modrm F0 E8 F8
      (x6t-r 'mfence 1 174 () '((rm 240))) (x6t-r 'lfence 1 174 () '((rm 232))) (x6t-r 'sfence 1 174 () '((rm 248)))]
     (x6t-dig 1 174 '(Eq) '((mod m) (p 66) (w 1) (iw 0)) '(() () () () () () clwb64 clflushopt64))
     (x6t-dig 1 174 '(Eq) '((mod m) (p 66) (iw 0)) '(() () () () () () clwb clflushopt))
     (x6t-dig 1 174 '(Eq) '((mod m) (p none) (w 1) (iw 0)) '(fxsave64 fxrstor64 () () xsave64 xrstor64 xsaveopt64 clflush64))
     (x6t-dig 1 174 '(Eq) '((mod m) (p none) (iw 0)) '(fxsave fxrstor ldmxcsr stmxcsr xsave xrstor xsaveopt clflush))
     (map (r \ x6t-r 'bswap 1 (200 + r) '(Zv) ()) ^8)
     ;; SSE: xmm <- xmm/m, or the store; the name by the prefix's lane
     (x6t-px 16 '(V W) '((none movups) (66 movupd) (f3 movss) (f2 movsd)) 1)
     (x6t-px 17 '(W V) '((none movups) (66 movupd) (f3 movss) (f2 movsd)) 1)
     ; the half moves: a register pair is movhlps/movlhps, memory the low or high 8 bytes
     [(x6t-r 'movlpd 1 18 '(V W) '((p 66) (x 1))) (x6t-r 'movhpd 1 22 '(V W) '((p 66) (x 1)))
      (x6t-r 'movhlps 1 18 '(V W) '((p none) (mod r) (x 1))) (x6t-r 'movlhps 1 22 '(V W) '((p none) (mod r) (x 1)))
      (x6t-r 'movlps 1 18 '(V W) '((p none) (x 1))) (x6t-r 'movhps 1 22 '(V W) '((p none) (x 1)))
      (x6t-r 'movlpd 1 19 '(W V) '((p 66) (mod m) (x 1))) (x6t-r 'movhpd 1 23 '(W V) '((p 66) (mod m) (x 1)))
      (x6t-r 'movlps 1 19 '(W V) '((p none) (mod m) (x 1))) (x6t-r 'movhps 1 23 '(W V) '((p none) (mod m) (x 1)))]
     (x6t-px 20 '(V W) '((none unpcklps) (66 unpcklpd)) 1) (x6t-px 21 '(V W) '((none unpckhps) (66 unpckhpd)) 1)
     (x6t-px 40 '(V W) '((66 movapd) (any movaps)) 1) (x6t-px 41 '(W V) '((66 movapd) (any movaps)) 1)
     (x6t-px 42 '(V Ev) '((f3 cvtsi2ss) (f2 cvtsi2sd)) 1)
     (x6t-px 44 '(Gv W) '((f3 cvttss2si) (f2 cvttsd2si)) 1) (x6t-px 45 '(Gv W) '((f3 cvtss2si) (f2 cvtsd2si)) 1)
     (x6t-px 46 '(V W) '((66 ucomisd) (any ucomiss)) 1) (x6t-px 47 '(V W) '((66 comisd) (any comiss)) 1)
     (x6t-px 80 '(Gd W) '((66 movmskpd) (any movmskps)) 1)
     (catmap (e \ x6t-lane (e 1) <e '(V W))
             '((81 "sqrt") (84 "and") (85 "andn") (86 "or") (87 "xor") (88 "add") (89 "mul")
               (92 "sub") (93 "min") (94 "div") (95 "max")))
     (x6t-px 90 '(V W) '((none cvtps2pd) (66 cvtpd2ps) (f3 cvtss2sd) (f2 cvtsd2ss)) 1)
     (x6t-px 91 '(V W) '((none cvtdq2ps) (66 cvtps2dq) (f3 cvttps2dq)) 1)
     (x6t-px 230 '(V W) '((f3 cvtdq2pd) (66 cvttpd2dq) (f2 cvtpd2dq)) 1)
     [(x6t-r 'movq 1 110 '(V Ey) '((p 66) (w 1) (x 1))) (x6t-r 'movd 1 110 '(V Ey) '((p 66) (x 1)))
      (x6t-r 'movq 1 126 '(Ey V) '((p 66) (w 1) (x 1))) (x6t-r 'movd 1 126 '(Ey V) '((p 66) (x 1)))
      (x6t-r 'movq 1 126 '(V W) '((p f3) (x 1))) (x6t-r 'movq 1 214 '(W V) '((p 66) (x 1)))
      (x6t-r 'movdqa 1 111 '(V W) '((p 66) (x 1))) (x6t-r 'movdqa 1 127 '(W V) '((p 66) (x 1)))
      (x6t-r 'movdqu 1 111 '(V W) '((p f3) (x 1))) (x6t-r 'movdqu 1 127 '(W V) '((p f3) (x 1)))]
     (map (e \ x6t-r (e 1) 1 <e '(V W) '((p 66) (x 1))) x6t-p66)
     ;; the shifts by an immediate: 66 0F 71/72/73 /digit ib
     (x6t-dig 1 113 '(W ub) '((p 66) (x 1)) '(() () psrlw () psraw () psllw ()))
     (x6t-dig 1 114 '(W ub) '((p 66) (x 1)) '(() () psrld () psrad () pslld ()))
     (x6t-dig 1 115 '(W ub) '((p 66) (x 1)) '(() () psrlq psrldq () () psllq pslldq))
     (x6t-px 112 '(V W ub) '((66 pshufd) (f3 pshufhw) (f2 pshuflw)) 1)
     (x6t-px 198 '(V W ub) '((66 shufpd) (any shufps)) 1)
     [(x6t-r 'pmovmskb 1 215 '(Gd W) '((p 66) (x 1)))]
     (catmap (l \ [(x6t-r (name ("cmp" + l 1)) 1 194 '(V W ub) [['p <l] '(x 1)])]) '((none "ps") (66 "pd") (f3 "ss") (f2 "sd")))
     ;; SSSE3 SSE4 AES PCLMUL GFNI SHA1: 0F 38 and 0F 3A, the blends' xmm0 implied
     (map (e \ x6t-r (e 1) 2 <e '(V W) '((p 66) (x 1))) (x6t-s38 + x6t-sx + '((23 ptest) (28 pabsb) (29 pabsw) (30 pabsd)
                                                         (16 pblendvb) (20 blendvps) (21 blendvpd) (219 aesimc) (207 gf2p8mulb))))
     (map (e \ x6t-r (e 1) 3 <e '(V W ub) '((p 66) (x 1))) (x6t-s3a + '((223 aeskeygenassist) (206 gf2p8affineqb) (207 gf2p8affineinvqb))))
     [(x6t-r 'movntdqa 2 42 '(V W) '((p 66) (mod m) (x 1)))
      (x6t-r 'sha1nexte 2 200 '(V W) '((p none) (x 1))) (x6t-r 'sha1msg1 2 201 '(V W) '((p none) (x 1)))
      (x6t-r 'sha1msg2 2 202 '(V W) '((p none) (x 1))) (x6t-r 'sha1rnds4 3 204 '(V W ub) '((p none) (x 1)))
      (x6t-r 'pinsrw 1 196 '(V Ed ub) '((p 66) (x 1))) (x6t-r 'pextrw 1 197 '(Gd W ub) '((p 66) (mod r) (x 1)))
      (x6t-r 'pinsrb 3 32 '(V Ed ub) '((p 66) (x 1))) (x6t-r 'pinsrq 3 34 '(V Eq ub) '((p 66) (w 1) (x 1)))
      (x6t-r 'pinsrd 3 34 '(V Ed ub) '((p 66) (x 1))) (x6t-r 'pextrb 3 20 '(Ed V ub) '((p 66) (x 1)))
      (x6t-r 'pextrw 3 21 '(Ed V ub) '((p 66) (x 1))) (x6t-r 'pextrq 3 22 '(Eq V ub) '((p 66) (w 1) (x 1)))
      (x6t-r 'pextrd 3 22 '(Ed V ub) '((p 66) (x 1)))]
     ;; VEX: the v-twins, a second source in vvvv (H); packed at both lengths, a scalar's at L0
     (catmap (e \ (: nm (e 1) vn (x6t-vn nm)
                     ks (elem nm x6t-xsh ? '(V H Wx) '(V H W))
                     (x6t-v vn 1 <e ks '((p 66)) x6t-l01
                      + (elem nm x6t-vcomm ? (x6t-v vn 1 <e '(V W H) '((p 66)) x6t-l01) ()))))
             x6t-p66)
     (catmap (e \ (: op <e b (e 1)
                     (catmap (l \ (: vn (name ("v" + b + l 1)) sc (elem (l 1) '("ss" "sd"))
                                    (x6t-v vn 1 op '(V H W) [['p <l]] (sc ? '(0) x6t-l01)
                                     + (elem (name (b + l 1)) x6t-vcomm ? (x6t-v vn 1 op '(V W H) [['p <l]] x6t-l01) ()))))
                             (b = "sqrt" ? '((f3 "ss") (f2 "sd")) '((none "ps") (66 "pd") (f3 "ss") (f2 "sd"))))))
             '((84 "and") (85 "andn") (86 "or") (87 "xor") (88 "add") (89 "mul") (92 "sub") (93 "min") (94 "div") (95 "max")
               (81 "sqrt")))
     (catmap (e \ x6t-v (x6t-vn (e 1)) 1 <e '(V H W) [['p (e 2)]] x6t-l01)
          '((20 unpcklps none) (20 unpcklpd 66) (21 unpckhps none) (21 unpckhpd 66)))
     (catmap (e \ x6t-v (x6t-vn (e 1)) 1 <e '(V H W ub) [['p (e 2)]] x6t-l01) '((198 shufps none) (198 shufpd 66)))
     (catmap (e \ x6t-v (x6t-vn (e 1)) 2 <e '(V H W) '((p 66)) x6t-l01) ('((0 pshufb)) + x6t-s38))
     (catmap (e \ x6t-v (x6t-vn (e 1)) 3 <e '(V H W ub) '((p 66)) x6t-l01) ('((15 palignr) (14 pblendw)) + x6t-s3a))
     (catmap (e \ x6t-v (x6t-vn (e 1)) 3 <e '(V H W ub) '((p 66) (w 1)) x6t-l01) '((206 gf2p8affineqb) (207 gf2p8affineinvqb)))
     (x6t-v 'vgf2p8mulb 2 207 '(V H W) '((p 66) (w 0)) x6t-l01)
     ; ..two operands: the moves, a store row to memory, and the one-source ops
     (catmap (e \ x6t-v (x6t-vn (e 2)) 1 <e (e 3) [['p (e 1)]] x6t-l01)
          '((16 none movups (V W)) (17 none movups (W V)) (16 66 movupd (V W)) (17 66 movupd (W V))
            (40 none movaps (V W)) (41 none movaps (W V)) (40 66 movapd (V W)) (41 66 movapd (W V))
            (111 66 movdqa (V W)) (127 66 movdqa (W V)) (111 f3 movdqu (V W)) (127 f3 movdqu (W V))
            (81 none sqrtps (V W)) (81 66 sqrtpd (V W)) (82 none rsqrtps (V W)) (83 none rcpps (V W))
            (80 none movmskps (Gd W)) (80 66 movmskpd (Gd W)) (215 66 pmovmskb (Gd W))))
     (catmap (e \ x6t-v (x6t-vn (e 2)) 1 <e '(V W) [['p (e 1)]] '(0)) '((46 66 ucomisd) (46 none ucomiss) (47 66 comisd) (47 none comiss)))
     (catmap (e \ x6t-v (x6t-vn (e 1)) 1 112 '(V W ub) [['p <e]] x6t-l01) '((66 pshufd) (f3 pshufhw) (f2 pshuflw)))
     (catmap (e \ x6t-v (x6t-vn (e 1)) 2 <e '(V W) '((p 66)) x6t-l01) '((23 ptest) (28 pabsb) (29 pabsw) (30 pabsd)))
     (catmap (e \ x6t-v (x6t-vn (e 1)) 2 <e '(V Wx) '((p 66)) x6t-l01) x6t-sx)
     (catall [(x6t-v 'vmovntdqa 2 42 '(V W) '((p 66) (mod m)) x6t-l01) (x6t-v 'vaesimc 2 219 '(V W) '((p 66)) '(0))
      (x6t-v 'vaeskeygenassist 3 223 '(V W ub) '((p 66)) '(0))])
     ; ..the shifts by an immediate: vvvv the destination, reg the digit
     (catmap (e \ catmap (d \ (e 1 d) @ () () nm (x6t-v (x6t-vn nm) 1 <e '(H W ub) [['p 66] ['d d] ['mod 'r]] x6t-l01)) ^8)
             '((113 (() () psrlw () psraw () psllw ())) (114 (() () psrld () psrad () pslld ()))
               (115 (() () psrlq psrldq () () psllq pslldq))))
     ; ..moves to and from a general register, and xmm <-> m64
     (catall [(x6t-v 'vmovq 1 110 '(V Eq) '((p 66) (w 1)) '(0)) (x6t-v 'vmovd 1 110 '(V Ed) '((p 66) (w 0)) '(0))
      (x6t-v 'vmovq 1 126 '(Eq V) '((p 66) (w 1)) '(0)) (x6t-v 'vmovd 1 126 '(Ed V) '((p 66) (w 0)) '(0))
      (x6t-v 'vmovq 1 126 '(V Wx) '((p f3)) '(0)) (x6t-v 'vmovq 1 214 '(Wx V) '((p 66)) '(0))
      (x6t-v 'vpinsrb 3 32 '(V H Ed ub) '((p 66) (w 0)) '(0)) (x6t-v 'vpinsrq 3 34 '(V H Eq ub) '((p 66) (w 1)) '(0))
      (x6t-v 'vpinsrd 3 34 '(V H Ed ub) '((p 66) (w 0)) '(0)) (x6t-v 'vpinsrw 1 196 '(V H Ed ub) '((p 66)) '(0))
      (x6t-v 'vpextrb 3 20 '(Ed V ub) '((p 66) (w 0)) '(0)) (x6t-v 'vpextrq 3 22 '(Eq V ub) '((p 66) (w 1)) '(0))
      (x6t-v 'vpextrd 3 22 '(Ed V ub) '((p 66) (w 0)) '(0)) (x6t-v 'vpextrw 1 197 '(Gd W ub) '((p 66) (mod r)) '(0))
      (x6t-v 'vpextrw 3 21 '(Ed V ub) '((p 66)) '(0))])
     ;; AVX's own: broadcasts, the 128-bit lanes, permutes, blends by register, the shifts by vector
     (catmap (e \ x6t-v (e 1) (e 2) <e (e 3) [['p 66] ['w (e 4)]] (e 5))
          '((24 vbroadcastss 2 (V Wx) 0 (0 1)) (25 vbroadcastsd 2 (V Wx) 0 (1)) (90 vbroadcasti128 2 (V Wx) 0 (1))
            (26 vbroadcastf128 2 (V Wx) 0 (1)) (120 vpbroadcastb 2 (V Wx) 0 (0 1)) (121 vpbroadcastw 2 (V Wx) 0 (0 1))
            (88 vpbroadcastd 2 (V Wx) 0 (0 1)) (89 vpbroadcastq 2 (V Wx) 0 (0 1))
            (24 vinsertf128 3 (V H Wx ub) 0 (1)) (56 vinserti128 3 (V H Wx ub) 0 (1))
            (25 vextractf128 3 (Wx V ub) 0 (1)) (57 vextracti128 3 (Wx V ub) 0 (1))
            (6 vperm2f128 3 (V H W ub) 0 (1)) (70 vperm2i128 3 (V H W ub) 0 (1)) (54 vpermd 2 (V H W) 0 (1))
            (22 vpermps 2 (V H W) 0 (1)) (0 vpermq 3 (V W ub) 1 (1)) (1 vpermpd 3 (V W ub) 1 (1))
            (2 vpblendd 3 (V H W ub) 0 (0 1)) (76 vpblendvb 3 (V H W L) 0 (0 1))
            (74 vblendvps 3 (V H W L) 0 (0 1)) (75 vblendvpd 3 (V H W L) 0 (0 1))
            (71 vpsllvd 2 (V H W) 0 (0 1)) (71 vpsllvq 2 (V H W) 1 (0 1)) (69 vpsrlvd 2 (V H W) 0 (0 1))
            (69 vpsrlvq 2 (V H W) 1 (0 1)) (70 vpsravd 2 (V H W) 0 (0 1))))
     [(x6t-r 'vzeroupper 1 119 () '((vex 0) (p none))) (x6t-r 'vzeroall 1 119 () '((vex 1) (p none)))]
     ;; BMI's general-register ops under VEX, B a general register in vvvv
     (map (e \ x6t-r (e 1) (e 2) <e (e 3) [['vex 0] ['p (e 4)]])
          '((242 andn 2 (Gy By Ey) none) (245 bzhi 2 (Gy Ey By) none) (247 bextr 2 (Gy Ey By) none)
            (245 pdep 2 (Gy By Ey) f2) (245 pext 2 (Gy By Ey) f3) (246 mulx 2 (Gy By Ey) f2)
            (247 sarx 2 (Gy Ey By) f3) (247 shlx 2 (Gy Ey By) 66) (247 shrx 2 (Gy Ey By) f2) (240 rorx 3 (Gy Ey ub) f2)))
     (x6t-dig 2 243 '(By Ey) '((vex 0) (p none)) '(() blsr blsmsk blsi))
     ;; EVEX, AVX-512's: the d and q rows by W, a zmm's twins of the VEX rows above. n the bytes
     ;; a disp8 counts in, where not the whole vector
     (catmap (e \ (: b (e 1)
                     (x6t-e (name (b + "d")) (e 2) <e (e 3) [['p 66] '(w 0)] '(0 1 2)
                      + x6t-e (name (b + "q")) (e 2) <e (e 3) [['p 66] '(w 1)] '(0 1 2))))
             '((37 "vpternlog" 3 (V H W ub)) (118 "vpermi2" 2 (V H W)) (126 "vpermt2" 2 (V H W))
               (239 "vpxor" 1 (V H W)) (219 "vpand" 1 (V H W)) (235 "vpor" 1 (V H W)) (223 "vpandn" 1 (V H W))))
     (catmap (d \ x6t-e (name ("vpro" + d 1 + "d")) 1 114 '(H W ub) [['p 66] ['d <d] '(w 0)] '(0 1 2)
                  + x6t-e (name ("vpro" + d 1 + "q")) 1 114 '(H W ub) [['p 66] ['d <d] '(w 1)] '(0 1 2))
             '((0 "r") (1 "l")))
     (catmap (e \ x6t-e <e 1 111 '(V W) [['p (e 1)] ['w (e 2)]] '(0 1 2) + x6t-e <e 1 127 '(W V) [['p (e 1)] ['w (e 2)]] '(0 1 2))
             '((vmovdqu8 f2 0) (vmovdqu16 f2 1) (vmovdqu32 f3 0) (vmovdqu64 f3 1) (vmovdqa32 66 0) (vmovdqa64 66 1)))
     (catmap (e \ x6t-e (e 1) (e 2) <e (e 3) [['p 66] ['w (e 4)] ['n (e 6)]] (e 5))
          '((90 vbroadcasti32x4 2 (V Wx) 0 (1 2) 16) (90 vbroadcasti64x2 2 (V Wx) 1 (1 2) 16)
            (91 vbroadcasti32x8 2 (V Wy) 0 (2) 32) (91 vbroadcasti64x4 2 (V Wy) 1 (2) 32)
            (57 vextracti32x4 3 (Wx V ub) 0 (1 2) 16) (57 vextracti64x2 3 (Wx V ub) 1 (1 2) 16)
            (59 vextracti32x8 3 (Wy V ub) 0 (2) 32) (59 vextracti64x4 3 (Wy V ub) 1 (2) 32)
            (56 vinserti32x4 3 (V H Wx ub) 0 (1 2) 16) (56 vinserti64x2 3 (V H Wx ub) 1 (1 2) 16)
            (58 vinserti32x8 3 (V H Wy ub) 0 (2) 32) (58 vinserti64x4 3 (V H Wy ub) 1 (2) 32)))
     (catmap (e \ x6t-e (e 1) (e 2) <e (e 3) [['p 66] ['w (e 4)]] '(2))
          '((254 vpaddd 1 (V H W) 0) (212 vpaddq 1 (V H W) 1) (0 vpshufb 2 (V H W) 0) (68 vpclmulqdq 3 (V H W ub) 0)
            (220 vaesenc 2 (V H W) 0) (221 vaesenclast 2 (V H W) 0) (222 vaesdec 2 (V H W) 0) (223 vaesdeclast 2 (V H W) 0)
            (206 vgf2p8affineqb 3 (V H W ub) 1) (207 vgf2p8affineinvqb 3 (V H W ub) 1) (207 vgf2p8mulb 2 (V H W) 0)
            (98 vpunpckldq 1 (V H W) 0) (106 vpunpckhdq 1 (V H W) 0) (108 vpunpcklqdq 1 (V H W) 1)
            (109 vpunpckhqdq 1 (V H W) 1) (112 vpshufd 1 (V W ub) 0) (71 vpsllvq 2 (V H W) 1) (69 vpsrlvq 2 (V H W) 1)
            (124 vpbroadcastq 2 (V Eq) 1) (67 vshufi64x2 3 (V H W ub) 1)))
     (catmap (e \ x6t-e (e 1) 1 115 '(H W ub) [['p 66] ['d <e] ['w (e 2)] '(mod r)] '(2))
             '((7 vpslldq 0) (3 vpsrldq 0) (6 vpsllq 1) (2 vpsrlq 1)))
     ;; the system rows by mode, i64 those a 64-bit segment refuses. a segment register: to it
     ;; never 66, from it 66 only into a register; the control and debug registers whole
     [(x6t-r 'mov 0 140 '(Ew S) '((mod m))) (x6t-r 'mov 0 140 '(Ev S) '((mod r))) (x6t-r 'mov 0 142 '(S Ew) ())
      (x6t-r 'mov 0 142 '(S Ed) '((mod r))) (x6t-r 'mov 0 142 '(S Eq) '((mod r) (w 1)))
      (x6t-r 'mov 1 32 '(Ed C) '((i64 1))) (x6t-r 'mov 1 34 '(C Ed) '((i64 1)))
      (x6t-r 'mov 1 33 '(Ed D) '((i64 1))) (x6t-r 'mov 1 35 '(D Ed) '((i64 1)))]
     ; ..pushed and popped, Q the one the row's sr names
     (map (e \ x6t-r (e 1) (e 2) <e '(Qp) [['sr (e 3)] '(iw p) (e 4 ? '(i64 1) '(i64 ()))])
          '((6 push 0 0 1) (7 pop 0 0 1) (14 push 0 1 1) (22 push 0 2 1) (23 pop 0 2 1) (30 push 0 3 1) (31 pop 0 3 1)
            (160 push 1 4 0) (161 pop 1 4 0) (168 push 1 5 0) (169 pop 1 5 0)))
     ; the far transfers: to a segment:offset, the offset's width the operand size, or through memory
     [(x6t-r 'ljmp 0 234 '(Iz Uw) '((i64 1) (iw o))) (x6t-r 'lcall 0 154 '(Iz Uw) '((i64 1) (iw o)))]
     (x6t-dig 0 255 '(Nv) '((mod m) (iw o)) '(() () () lcall () ljmp))
     ; the descriptor tables at a suffix's operand size; a word's register forms
     (x6t-dig 1 1 '(Ev) '((mod m) (iw o) (i64 1)) '(sgdt sidt lgdt lidt))
     (x6t-dig 1 0 '(Ev) '((mod r)) '(sldt str)) (x6t-dig 1 0 '(Ew) '((mod r)) '(() () lldt ltr verr verw))
     (x6t-dig 1 1 '(Ew) '((iw 0) (mod m)) '(() () () () smsw () lmsw)) (x6t-dig 1 1 '(Ev) '((mod r)) '(() () () () smsw))
     (x6t-dig 1 1 '(Ew) '((mod r)) '(() () () () () () lmsw))
     ; the ports, by an imm8 or by DX, at the accumulator's width
     [(x6t-r 'in 0 228 '(Ab ub) ()) (x6t-r 'in 0 229 '(Av ub) '((w 0))) (x6t-r 'in 0 236 '(Ab DX) ()) (x6t-r 'in 0 237 '(Av DX) '((w 0)))
      (x6t-r 'out 0 230 '(ub Ab) ()) (x6t-r 'out 0 231 '(ub Av) '((w 0))) (x6t-r 'out 0 238 '(DX Ab) ()) (x6t-r 'out 0 239 '(DX Av) '((w 0)))]
     ; inc and dec 40+r and 48+r, REX in 64; mov's accumulator to and from an absolute address
     (map (r \ x6t-r 'inc 0 (64 + r) '(Zv) '((i64 1))) ^8) (map (r \ x6t-r 'dec 0 (72 + r) '(Zv) '((i64 1))) ^8)
     [(x6t-r 'mov 0 160 '(Ab Ob) '((i64 1))) (x6t-r 'mov 0 161 '(Av Ov) '((i64 1)))
      (x6t-r 'mov 0 162 '(Ob Ab) '((i64 1))) (x6t-r 'mov 0 163 '(Ov Av) '((i64 1)))]
     ;; the far returns and pusha at a suffix's operand size; the prefixes as instructions, as
     ;; gas reads `rep; movsb` (the decoder reads them as prefixes first)
     [(x6t-r 'lret 0 203 () '((iw o))) (x6t-r 'iret 0 207 () '((iw o))) (x6t-r 'ret 0 195 () '((iw o) (i64 1)))
      (x6t-r 'pusha 0 96 () '((iw o) (i64 1))) (x6t-r 'popa 0 97 () '((iw o) (i64 1)))
      (x6t-r 'lock 0 240 () ()) (x6t-r 'rep 0 243 () ()) (x6t-r 'repe 0 243 () ()) (x6t-r 'repz 0 243 () ())
      (x6t-r 'repne 0 242 () ()) (x6t-r 'repnz 0 242 () ())
      ; crc32 by its source's width, the item's; rdpid's register whole, no REX.W; ud1
      (x6t-r 'crc32 2 240 '(Gd Eb) '((p f2) (w 0) (iw 1) (x 1))) (x6t-r 'crc32 2 240 '(Gq Eb) '((p f2) (w 1) (iw 1) (x 1)))
      (x6t-r 'crc32 2 241 '(Gd Ev) '((p f2) (ow 2) (iw o) (x 1))) (x6t-r 'crc32 2 241 '(Gd Ev) '((p f2) (ow 4) (iw o) (x 1)))
      (x6t-r 'crc32 2 241 '(Gq Eq) '((p f2) (w 1) (iw o) (x 1)))
      (x6t-r 'ud1 1 185 '(Gv Ev) ())]
     (x6t-dig 1 199 '(Eq) '((mod r) (p f3) (x 1)) '(() () () () () () () rdpid))
     (x6t-dig 1 199 '(Ed) '((mod r) (p f3) (x 1) (i64 1)) '(() () () () () () () rdpid))])
   ;; the rows by map and opcode, in table order
   x64-tabix (foldl (\ t r (: k (r 1 * 256 + r 2) (pin t k (peep t k () + [r])))) {} x64-tab)
   ;; the encoder: a row lays operands written as the decoder's (decode.l), Intel order; of the
   ;; rows of a name that take them, the shortest, the first on a tie
   (x64-role k) (show k @ t (? (elem t ["CL" "ub" "DX"]) t (#t = 1) t (snip t 0 1)))
   (x64-wl k) (show k @ t (#t = 2 && nelem t ["CL" "ub" "DX"] ? (snip t 1 2) ""))
   (x6e-rg? o) (two? o && <o = 'rg)
   (x6e-mem? o) (two? o && elem <o '(mem rip seg))
   ;; a memory operand's modrm, sib and displacement with reg field rf -> [bytes X B], or ()
   (x6e-mem rf o)
    (o @ ('seg _ m) (x6e-mem rf m)
         ('rip () d) [([(x86-modrm 0 rf 5)] + (fix? d ? (d 1 = 4 ? [d] ()) (le32 d))) 0 0]
         ('mem b ix sc d)
          (? (!(charm? d) || !(fits32 d) || ix = 4) ()
             (b < 0) [([(x86-modrm 0 rf 4) (x86-sib (x86-scale sc) (ix < 0 ? 4 ix) 5)] + le32 d) (ix < 0 ? 0 (ix >> 3)) 0]
             (: md (x6md b d)
                dsp (x6e-dsp md d)
                hd (? (ix >= 0 || (b & 7) = 4) [(x86-modrm md rf 4) (x86-sib (x86-scale sc) (ix < 0 ? 4 ix) b)]
                      [(x86-modrm md rf b)])
                [(hd + dsp) (ix < 0 ? 0 (ix >> 3)) (b >> 3)]))
         ())
   ;; ..in a segment of md bits, as gas lays it -> [bytes X B 67]: 16-bit addressing (registers 32
   ;; up), 67 where the address is not the segment's width (a 32-bit one in 64 marks field 6
   ;; 'a32), a bare address by the segment's form, a symbol in field 5 the displacement's fix
   (x6e-memm md rf o) (x6e-memmn md rf o 1)
   ;; ..its disp8 counted in units of n bytes (EVEX's), 1 elsewhere
   (x6e-memmn md rf o n)
    (o @ ('seg _ m) (x6e-memmn md rf m n)
         ('rip _ _) (md = 64 ? (x6e-mem rf o @ () () m (m + [()])) ())
         ('mem . b . ix . sc . d . more)
          (: sy (two? more ? <more ()) a32 (#more > 1 && more 1 = 'a32)
             (? (b >= 32 || ix >= 32) (md = 64 ? () (x6e-m16 rf b ix sc d sy @ () () m (m + [(md = 32 ? [103] ())])))
                (sy = () && md = 64 && !a32 && n = 1) (x6e-mem rf o @ () () m (m + [()]))
                (: d4 (sy ? [(fix 4 (md = 64 ? 'abs32s 'abs32d) sy d)] (charm? d && fits32 d ? (le32 d) ()))
                   a67 (? (md = 64) (a32 ? [103] ()) (md = 16) [103] ())
                   (? (d4 = () || ix = 4) ()
                      (md = 16 && b < 0 && ix < 0) [([(x86-modrm 0 rf 6)] + (sy ? [(fix 2 'abs16 sy d)] (le16 d))) 0 0 ()]
                      (md = 32 && b < 0 && ix < 0) [([(x86-modrm 0 rf 5)] + (sy ? [(fix 4 'abs32 sy d)] (le32 d))) 0 0 ()]
                      (b < 0) [([(x86-modrm 0 rf 4) (x86-sib (x86-scale sc) (ix < 0 ? 4 ix) 5)] + d4) (ix < 0 ? 0 (ix >> 3)) 0 a67]
                      (: m (? sy 2 (d = 0 && (b & 7) != 5) 0 (d % n = 0 && fits8 (d // n)) 1 2)
                         hd (? (ix >= 0 || (b & 7) = 4) [(x86-modrm m rf 4) (x86-sib (x86-scale sc) (ix < 0 ? 4 ix) b)]
                               [(x86-modrm m rf b)])
                         [(hd + (m @ 0 () 1 [(byte (d // n))] d4)) (ix < 0 ? 0 (ix >> 3)) (b >> 3) a67])))))
         ())
   ;; 16-bit addressing: a base and an index (either order) -> rm by their numbers (bx 3 bp 5 si 6
   ;; di 7), -1 for no row; bp alone has no disp-less form
   (x6e-a16rm b ix) (: x (b < ix ? ix b) y (b < ix ? b ix)
                       (? (y < 0) (x @ 6 4 7 5 5 6 3 7 -1)
                          (y = 3) (x @ 6 0 7 1 -1)
                          (y = 5) (x @ 6 2 7 3 -1)
                          -1))
   (x6e-m16 rf b0 ix0 sc d sy)
    (: rm (x6e-a16rm (b0 < 0 ? -1 (b0 - 32)) (ix0 < 0 ? -1 (ix0 - 32)))
       (? (rm < 0 || sc != 1) ()
          sy [[(x86-modrm 2 rf rm) (fix 2 'abs16 sy d)] 0 0]
          !(charm? d) ()
          (d = 0 && rm != 6) [[(x86-modrm 0 rf rm)] 0 0]
          (fits8 d) [[(x86-modrm 1 rf rm) (byte d)] 0 0]
          [([(x86-modrm 2 rf rm)] + le16 d) 0 0]))
   ;; an immediate's bytes by kind, or () when it does not fit
   (x6e-in lo v hi) ((lo <= v) && (v <= hi))
   ;; [b+d]'s mod: none, a byte, a dword
   (x6md b d) (? (d = 0 && (b & 7) != 5) 0 (fits8 d) 1 2)
   (x6e-dsp md d) (md @ 0 () 1 [(byte d)] (le32 d))
   ;; the lay of an immediate of kind l, for the operand size: a number -> bytes, or ()
   (x6e-immf l osz byte?)
    (: (in lo hi f) (v \ (charm? v && x6e-in lo v hi) ? (f v) ())
       (b1 v) [(byte v)]
       (? (l = "Uv" && osz = 8) le64
          (l @ "Ib" (in -128 (byte? ? 255 127) b1)
               "Iz" (? (osz = 2) (in -32768 65535 le16)
                       (osz = 8) (in -2147483648 2147483647 le32)
                       (in -2147483648 4294967295 le32))
               "Id" (in -2147483648 2147483647 le32)
               "Uv" (osz = 2 ? (in -32768 65535 le16) (in -2147483648 4294967295 le32))
               "Uw" (in 0 65535 le16)
               "ub" (in -128 255 b1)
               (v \ ()))))
   ;; a row's plan, all of the row that its operands do not change: its roles and widths as
   ;; symbols, the indices of its sized, G, E and Z items, its opcode bytes, its immediates
   (x6e-plan r)
    (: ks (r 3) at (r 4) n #ks (a k) (peep at k ())
       rl (map (k \ name (x64-role k)) ks) wl (map (k \ x64-wl k @ "" '- l (name l)) ks)
       (idx role) (filter (i \ elem (rl i) role) ^n @ (i . _) i _ -1)
       [r n rl wl
        (filter (i \ elem (wl i) '(v p y) && elem (rl i) '(G E Z A)) ^n)
        (any (i \ elem (wl i) '(v p y z) && nelem (rl i) '(V W H L)) ^n || a 'ow != () || elem (a 'iw) '(p o))
        (any (i \ wl i = 'b && nelem (rl i) '(I U J)) ^n)
        (idx '(G V S C D)) (idx '(E W N T)) (idx '(Z))
        (catmap (ro \ filter (i \ rl i = ro) ^n) '(G E Z A) @ (i . _) i _ -1)
        (a 'ow) (a 'iw) (a 'p) (a 'mod) (a 'rm) (a 'd) (a 'w) (a 'b)
        ((r 1 @ 0 () 1 [15] 2 [15 56] [15 58]) + [(r 2)]) (a 'p @ 'f3 [243] 'f2 [242] _ ()) (elem 'p wl || a 'iw = 'p)
        (filter (i \ elem (rl i) '(I U ub J L O)) ^n @ is (map (i \ [i (show (ks i))]) is))
        (r 2) (a 'vex) (a 'evex) (a 'n) (idx '(H B)) (r 1) (a 'i64) (a 'sr)])
   ;; a row's lay for operands of this shape, or (): all the shape decides, once, and a
   ;; (\ ops pc) for the rest, a memory operand, the immediates and targets -> bytes or ().
   ;; md the segment's bits: outside 64 no REX, and 66 names the width that is not its own
   (x6e-stage p w ops) (x6e-stagem 64 p w ops)
   (x6e-stagem md p w ops)
    (p @ [_ n rl wl szc vsz byte? gi ei zi gwi ow iw0 ap mod rm ad aw ab opb pfx hasp ims oc vl el nn hi mp i6 sk]
     (: ; the operand size: ow, else a sized register's, else the item's
       sized (filter (i \ x6e-rg? (ops i) && ops i 2 >= 2) szc)
       dsz (md = 16 ? 2 4)
       osz (? (ow != ()) ow (two? sized) (ops <sized 2) (w > 1) w dsz)
       o66 (osz != dsz && (osz = 2 || osz = 4))
       (wd l) (l @ 'b 1 'w 2 'd 4 'q 8 'v osz 'p osz 'y osz 0)
       ; VEX and EVEX: L the vector's length, a bare V W H or L its width, x an xmm, y a ymm
       vx (vl != () || el != ()) L (vl != () ? vl (el != () ? el 0)) vw (16 << L)
       (vwd l) (l @ 'x 16 'y 32 vw)
       (vec? o l) (x6e-rg? o && o 2 = vwd l && o 1 < 16)
       ; a field's width, for a fix laid in it
       (fw l) (l @ ("Jb" || "Ib" || "ub") 1 "Jz" (osz = 2 ? 2 4) "Id" 4 "Uw" 2 ("Iz" || "Uv") (osz = 2 ? 2 (l = "Uv" && osz = 8 ? 8 4)) 0)
       (gpr? o l) (x6e-rg? o && (o 2 = wd l) && ((o 1 < 16) || (wd l = 1 && (o 1 < 24))))
       (ok o r l)
        (r @ 'G (gpr? o l) 'Z (gpr? o l && (o 1 & 7) = (oc & 7))
             'A (gpr? o l && o 1 = 0) 'CL (o = ['rg 1 1])
             'E (gpr? o l || x6e-mem? o) ('V || 'H || 'L) (vec? o l) 'W (vec? o l || x6e-mem? o) 'B (gpr? o l)
             'N (two? o && <o = 'ind && (x6e-rg? (o 1) && o 1 2 = (md = 64 ? 8 osz) || x6e-mem? (o 1)))
             'S (two? o && <o = 'sr) 'C (two? o && <o = 'cr) 'D (two? o && <o = 'dr)
             'T (two? o && <o = 'st && charm? (o 1)) 'K (o = ['st] || o = ['st 0])
             'Q (o = ['sr sk]) 'DX (o = ['rg 2 2])
             'O (two? o && <o = 'mem && o 1 < 0 && o 2 < 0 && #o < 7)
             (two? o && elem <o '(im lbl)))
       (oks os rs ls) (? !(two? os) 1 (ok <os <rs <ls) (oks >os >rs >ls) 0)
       ; the item's width as the decoder names it: iw, else the first general register kind's.
       ; outside 64 a target's or an indirect one's is the operand size it names
       iw (? (iw0 = 'p) (md = 64 ? (osz = 2 ? 2 8) osz) (iw0 = 'o) w (iw0 != ()) iw0 (gwi < 0 ? 0 (wd (wl gwi))))
       jn (any (r \ elem r '(J N)) rl)
       ; outside 64 no 64-bit register, and no 64-bit push
       (? (#ops != n || (i6 && md = 64) || (md != 64 && (any (o \ x6e-rg? o && o 2 = 8) ops || hasp && osz = 8)) || (iw != w && !(jn && iw = 0 && md != 64 && (w = 2 || w = 4))) || !(oks ops rl wl)
           || (ow != () && w > 0 && vsz && w != ow) || (hasp && md = 64 && osz = 4)
           || (o66 && (ap = 'none)) || (mod = 'r && ei >= 0 && !(x6e-rg? (ops ei) || <(ops ei) = 'st || <(ops ei) = 'ind && x6e-rg? (ops ei 1)))
           || (mod = 'm && ei >= 0 && (x6e-rg? (ops ei) || <(ops ei) = 'ind && x6e-rg? (ops ei 1))))
           ()
          (: eo (ei < 0 ? () (ops ei @ ('ind x) x x x))
             go (gi < 0 ? () (ops gi))
             rf (? (ad != ()) ad (gi < 0) 0
                   (go @ ('sr d) d ('cr c) c ('dr c) c ('rg c _) c 0))
             ; the modrm: fixed, none, a register's, or a memory operand's, laid per call
             mk (? (rm != ()) [[rm] 0 0]
                   (eo = ()) (gi >= 0 || ad != () ? () [() 0 0])
                   (x6e-rg? eo) [[(x86-modrm 3 rf (eo 1))] 0 (eo 1 >> 3 & 1)]
                   (<eo = 'st) [[(x86-modrm 3 rf (eo 1))] 0 0]
                   (md = 64 && el = () && (eo @ ('mem b ix sc d) (ix < 0 && sc = 1 && charm? b && 0 <= b && b < 32 && charm? d && fits32 d) 0)) 'base
                   'mem)
             ; [b+d]: all but the displacement, laid once
             mb (mk = 'base ? (eo @ ('mem b _ _ d) (: md (x6md b d) [md [((b & 7) = 4 ? [(x86-modrm md rf 4) (x86-sib 0 4 b)] [(x86-modrm md rf b)]) 0 (b >> 3)]])) ())
             ; a byte register 4..7 forces a REX; ah..bh refuse one
             bregs (filter (o \ x6e-rg? o && o 2 = 1) ops)
             frc (any (o \ 4 <= o 1 && o 1 <= 7) bregs) hib (any (o \ o 1 >= 16) bregs)
             W ((aw = 1) || (vsz && (osz = 8) && !hasp))
             R (rf >> 3 & 1)
             zb (zi >= 0 ? (ops zi 1 >> 3 & 1) ())
             sg (eo @ ('seg s _) (x86-seg s) _ ())
             pre1 (catall [(o66 && (vsz || jn) || ap = 66 ? [102] ()) pfx])
             ; VEX's C5 when the map is 0F and W X B are clear, else C4; EVEX's 62 (no masks, no
             ; registers past 15). R X B and vvvv ride inverted, the mandatory prefix as pp
             hv (hi < 0 ? 0 (ops hi 1)) vv ((15 - hv) & 15) pp (ap @ 66 1 'f3 2 'f2 3 0) Wb (W ? 1 0)
             en (el != () ? (nn != () ? nn vw) 1)
             (vexb X B)
              (? (el != ()) [98 ((1 - R) << 7 | (1 - X) << 6 | (1 - B) << 5 | 16 | mp) (Wb << 7 | vv << 3 | 4 | pp) (L << 5 | 8)]
                 (mp = 1 && Wb = 0 && X = 0 && B = 0) [197 ((1 - R) << 7 | vv << 3 | L << 2 | pp)]
                 [196 ((1 - R) << 7 | (1 - X) << 6 | (1 - B) << 5 | mp) (Wb << 7 | vv << 3 | L << 2 | pp)])
             (? (mk = () || (aw = 0 && W)) ()
                (: ; the head before the immediates, of a modrm laid
                   (head mrm) (: X (two? mrm ? (mrm 1) 0)
                                 B (? (zb != ()) zb (two? mrm) (mrm 2) 0)
                                 rex? (W || R || X || B || frc)
                                 (? !(two? mrm) ()
                                    vx (md != 64 && (R || X || B || hv > 7) ? () (sg + (#mrm > 3 ? (mrm 3) ()) + vexb X B + [oc] + <mrm))
                                    ((rex? && (hib || md != 64)) || (ab = 1 && B = 0)) ()
                                    (sg + (#mrm > 3 ? (mrm 3) ()) + pre1 + (rex? ? [(64 | (W ? 8 0) | R << 2 | X << 1 | B)] ()) + opb + <mrm)))
                   ; ..once, where no memory operand lays it
                   hd0 (? (mk = 'mem) () (mk = 'base) (head (mb 1)) (head mk))
                   ; each immediate or target's lay, of the operand and where its field starts
                   (lay1 l)
                    (: w (fw l) z (? (l = "Jb") 1 (l = "Jz") w 0) im (x6e-immf l osz byte?)
                       (? (l = "L") (\ o at [(o 1 << 4)])
                          ; an absolute address at the segment's address width
                          (starts? l "O")
                           (\ o at (: d (o 4) sy (#o > 5 ? (o 5) ()) k (md = 16 ? 2 4)
                                      (? (nom? sy) [(fix k (k = 2 ? 'abs16 'abs32) sy d)]
                                         (k = 2) (0 <= d && d < 65536 ? (le16 d) ()) (fits32 d || 0 <= d && d < 1 << 32) (le32 d) ())))
                       (\ o at
                          (: v (o 1)
                             (? (fix? v) (v 1 = w ? [v] ())
                                (z = 1) (: d (v - (at + 1)) (fits8 d ? [(byte d)] ()))
                                (z = 4) (: d (v - (at + 4)) (fits32 d ? (le32 d) ()))
                                (im v @ b ((two? b && (#o < 3 || o 2 = #b)) ? b ())))))))
                   lays (map (q \ [(q 0) (lay1 (q 1))]) ims)
                   ; the immediates and targets, in order, after hd
                   (tail hd pc is acc ops)
                    (? !(two? is) acc
                       (: q <is b ((q 1) (ops (q 0)) (pc + #hd + #acc))
                          (b = () ? () (tail hd pc >is (acc + b) ops))))
                   (eo-of ops) (ops ei @ ('ind x) x x x)
                   (? (mk != 'mem && hd0 = ()) ()
                      (!(two? ims) && mk = 'base) (mb 0 @ 0 (\ ops pc hd0)
                                                        1 (\ ops pc (hd0 + [(byte (eo-of ops 4))]))
                                                        (\ ops pc (hd0 + le32 (eo-of ops 4))))
                      !(two? ims) (mk = 'mem ? (\ ops pc (head (x6e-memmn md rf (eo-of ops) en))) (\ ops pc hd0))
                      ; a head laid once and one immediate or target, at a known offset
                      (mk != 'mem && mk != 'base && #lays = 1)
                       (: i (lays 0 0) f (lays 0 1) nh #hd0
                          (\ ops pc (f (ops i) (pc + nh) @ () () b (hd0 + b))))
                      (\ ops pc
                         (: hd (? (mk = 'mem) (head (x6e-memmn md rf (eo-of ops) en))
                                  (mk = 'base) (hd0 + x6e-dsp (mb 0) (eo-of ops 4))
                                  hd0)
                            (? (hd = ()) () (tail hd pc lays () ops @ t (t = () ? () (hd + t)))))))))))) _ ())
   ;; a row's bytes for the operands, pc where the instruction starts (a target is absolute), or ()
   (x6e-lay p w ops pc) (x6e-stage p w ops @ () () f (f ops pc))
   (x6e-laym md p w ops pc) (x6e-stagem md p w ops @ () () f (f ops pc))

   ;; each name's rows as plans, in table order
   x64-byname (foldl (\ t r (pin t <r (peep t <r () + [(x6e-plan r)]))) {} x64-tab)
   ;; an instruction by name from the decoder's operands -> its bytes, the shortest row's. a
   ;; target, immediate or rip displacement may be a fix of its field's width
   (x64-enc mn w ops pc)
    (: bs (filter two? (map (p \ x6e-lay p w ops pc) (peep x64-byname mn ())))
       (? !(two? bs) (scare 'x64-enc [mn w ops])
          (foldl (\ b x (#x < #b ? x b)) <bs >bs)))
   ;; ..in a segment of md bits, or (); on a tie the row without the accumulator's, as gas
   (x64-encm md mn w ops pc)
    (: ls (filter (l \ two? (l 1)) (map (p \ [(elem 'A (p 2)) (x6e-laym md p w ops pc)]) (peep x64-byname mn ())))
       (two? ls ? (foldl (\ b x (#(x 1) < #(b 1) || (#(x 1) = #(b 1) && b 0 && !(x 0)) ? x b)) <ls >ls 1) ()))
   ;; a rip operand's rel32 measures from its own field's end: its addend steps back over the
   ;; bytes laid after it, an immediate's, a fix counting its width
   (riptail bs) (bs @ (b . r) (fix? b && fix-k b = 'rel32 ? (fix 4 'rel32 (b 3) (b 4 - x6blen r) . r) (b . riptail r)) _ ())
   (x6blen l) (foldl (\ n x (n + (fix? x ? (x 1) 1))) 0 l)
   ;; the lowering's: by name, or the row of opcode k (map * 256 + opcode) when the form matters.
   ;; each takes the row chosen once for its operands' shape, an integer: a register itself, a
   ;; memory operand's kind, the ranges an immediate fits, a fix's width. a number laid as a
   ;; target is not a shape, so a name with a target row laying one is laid in full
   x64-jn (foldl (\ t r (any (k \ snip (show k) 0 1 = "J") (r 3) ? (pin t <r 1) t)) {} x64-tab)
   x6-rows {} x6-krows {}
   x6-ranges [[-128 127] [-128 255] [-32768 65535] [0 65535] [-2147483648 2147483647] [-2147483648 4294967295]]
   (x6wc w) (w @ 0 0 1 1 2 2 4 3 8 4 16 5 -1)
   ;; an operand's shape in 16 bits, a tag in the low four; -1 where it has none
   (x6q o)
    (? (atom? o) -1
       (<o = 'rg) (o @ ('rg n w) ((charm? n && 0 <= n && n < 32 && x6wc w >= 0) ? ((n * 8 + x6wc w) * 16 + 1) -1) _ -1)
       (<o = 'im) (: v (o 1) z >>o c (x6ic v)
                     zc (? (z = ()) 0 (#z = 1 && charm? (z 0) && 0 <= z 0 && z 0 < 15) (z 0 + 1) -1)
                     ((c < 0 || zc < 0) ? -1 ((zc * 128 + c) * 16 + 6)))
       (<o = 'lbl) ((fix? (o 1) && 0 < o 1 1 && o 1 1 < 16) ? ((64 + o 1 1) * 16 + 10) -1)
       (o @ ('rg n w) ((charm? n && 0 <= n && n < 32 && x6wc w >= 0) ? ((n * 8 + x6wc w) * 16 + 1) -1)
            ('mem b ix sc d) (? !(charm? d) 2 (ix < 0 && sc != 1) (fits32 d ? 18 2) (x6mq b ix d))
            ('rip () d) ((fix? d ? (d 1 = 4 ? 1 2) 0) * 16 + 3)
            ('seg s m) (x6q m @ q ((q < 0 || q >= 512 || !(charm? s && 0 <= s && s < 8)) ? -1 ((s * 32 + (q >> 4)) * 16 + 4)))
            ('ind x) (x6q x @ q ((q < 0 || q >= 4096) ? -1 (q * 16 + 5)))
            ('sr n) ((charm? n && 0 <= n && n < 8) ? (n * 16 + 7) -1)
            ('cr n) ((charm? n && 0 <= n && n < 16) ? (n * 16 + 8) -1)
            ('dr n) ((charm? n && 0 <= n && n < 16) ? (n * 16 + 9) -1)
            _ -1))
   ;; an immediate's class: a fix by its width, a number by the ranges it fits
   (x6ic v)
    (? (fix? v) ((0 < v 1 && v 1 < 16) ? (64 + v 1) -1)
       (charm? v) ((-128 <= v && v <= 127) ? (v < 0 ? 59 63)
                     (foldl (\ c q (c * 2 + (x6e-in (q 0) v (q 1) ? 1 0))) 0 x6-ranges))
       127)
   ;; the operands' shapes in one integer, 16 bits each, under their count and the width; -1
   ;; for none. jn: a name with a target row, where a number laid as one has no shape
   (x6key mn w ops) (: c (x6wc w) ((#ops > 3 || c < 0) ? -1 (x6kf (x64-jn mn) (#ops * 8 + c) ops)))
   (x6kf jn k os) (? !(two? os) k
                     (jn && <<os = 'im && !(fix? (<os 1))) -1
                     (x6q <os @ q (q < 0 ? -1 (x6kf jn (k * 65536 + q) >os))))
   (x6c t short key ps w ops)
    (: hit (key < 0 ? () (peep t key ())) lb (hit = () ? () (hit ops 0))
       (two? lb ? lb
          (: bs (filter (b \ two? (b 1)) (map (p \ (x6e-stage p w ops @ () [p ()] f [f (f ops 0)])) ps))
             (two? bs ? (: b (short ? (foldl (\ b x (#(x 1) < #(b 1) ? x b)) <bs >bs) <bs)
                           (key < 0 ? 0 (pin t key (b 0)), b 1)) ()))))
   (x6tab t k) (peep t k () @ () (: u {} (pin t k u, u)) u u)
   (x6h t key ops) (key < 0 ? () (peep t key () @ () () f (f ops 0)))
   (x6at mn w key ops)
    (: t (x6tab x6-rows mn)
       (x6h t key ops @ () (x6c t 1 key (peep x64-byname mn ()) w ops @ () (scare 'x64-enc [mn w ops]) b b) b b))
   (x6kat k mn w key ops)
    (: t (x6tab (x6tab x6-krows k) mn)
       (x6h t key ops @ ()
        (x6c t 0 key (filter (p \ p 0 1 * 256 + p 0 2 = k) (peep x64-byname mn ())) w ops @ () (scare 'x64-enc [mn k w ops]) b b)
        b b))
   (x6 mn w ops) (x6at mn w (x6key mn w ops) ops)
   (x6k k mn w ops) (x6kat k mn w (x6key mn w ops) ops)
   ;; the keys of the shapes an emitter knows, x6key's for the same operands: a register n at
   ;; w, [base+d] with no index, an immediate, a target fix, rip; one operand or two, under w
   (x6rq n w) ((n * 8 + x6wc w) * 16 + 1)
   (x6mq b ix d) (? !(fits32 d && ix != 4) 2
                    (ix < 0 && charm? b && 0 <= b && b < 32) ((2 + b * 4 + x6md b d) * 16 + 2)
                    18)
   (x6iq v) (x6ic v @ c (c < 0 ? -1 (c * 16 + 6)))
   (x6k1 w a) ((8 + x6wc w) * 65536 + a)
   (x6k2 w a b) ((a < 0 || b < 0) ? -1 (((16 + x6wc w) * 65536 + a) * 65536 + b))
   ;; ..and a cond's name by its stem, once
   x6-ccm {}
   (x6ccn pre c f) (: t (x6tab x6-ccm pre) (peep t c () @ () (: n (f c) (pin t c n, n)) n n)))

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
   (mem regf base disp) (x86-mem regf (rn base) disp)

   ;; the table encoder's operands: a register at width w, an xmm, [base+off] ('rip with off
   ;; (sym k) is rip-relative), [base+index*scale+disp], an immediate, a target
   (x6g r w) ['rg (rn r) w]
   ;; register and register, register and immediate, by their key
   (x6gg mn w d s) (: dn (rn d) sn (rn s) (x6at mn w (x6k2 w (x6rq dn w) (x6rq sn w)) [['rg dn w] ['rg sn w]]))
   (x6gm mn w d m) (: dn (rn d) (x6at mn w (x6k2 w (x6rq dn w) (x6mq (m 1) (m 2) (m 4))) [['rg dn w] m]))
   (x6gi mn w d v) (: dn (rn d) (x6at mn w (x6k2 w (x6rq dn w) (x6iq v)) [['rg dn w] ['im v]]))
   (x6x r) ['rg (xrn r) 16]
   (x6m b off) (rn b @ bn (charm? off ? ['mem bn -1 1 off] (scare 'mem-disp off)))
   (x6mr b off) (b = 'rip && two? off ? (x6rip <off <>off) (x6m b off))
   (x6rip lbl k) ['rip () (fix 4 'rel32 lbl k)]
   (MX b ix sc d) (: bn (rn b) xn (rn ix) (charm? d ? ['mem bn xn sc d] (scare 'mem-disp d)))
   (x6i v) ['im v]
   (x6j f) ['lbl f]
   ;; a rip displacement measures from the instruction's end: the bytes after its field come off
   (x6r mn w ops) (riptail (x6 mn w ops))

   ;; reg <- reg by the r/m-destination row (89, 01+8k), as the old hand did
   (alu-rr w opcode d s)
    (: dn (rn d) sn (rn s)
       (x6kat opcode (opcode @ 137 'mov (x6t-alu (opcode >> 3))) w (x6k2 w (x6rq dn w) (x6rq sn w)) [['rg dn w] ['rg sn w]]))
   ;; 83 /ext ib for a signed byte, else 81 /ext id, or rax's own 05+8*ext id: the shortest
   (alu-ri w ext d imm) (x6gi (x6t-alu ext) w d imm)
   (alu-step w rr ext d y) (reg? y ? (alu-rr w rr d y) (alu-ri w ext d y))
   (reg-eq a b) (rn a = rn b)

   (emit-movw w d s) (alu-rr w 137 d s)
   (emit-mov d s) (emit-movw 8 d s)
   ;; cmp against 0 is test, the same flags: 3 bytes for 4
   (emit-cmp a b) (!(reg? b) && b = 0 ? (emit-test a a) (alu-step 8 57 7 a b))

   ;; b8+rd id zero-extends an unsigned 32; C7 /0 id sign-extends a negative 32; else movabs.
   ;; a symbol survives arithmetic, so imm is checked a number
   (emit-li d imm)
      (: _ (constellation? imm ? 0 (scare 'badimm imm))
         (? (0 <= imm <= 4294967295) (x6gi 'mov 4 d imm)
            (fits32 imm) (x6k 199 'mov 8 [(x6g d 8) (x6i imm)])
            (x6gi 'mov 8 d imm)))
   ;; d's low word <- imm by 66 B8+r iw; the rest of d stays
   (emit-li2 d imm) (x6 'mov 2 [(x6g d 2) (x6i imm)])

   ;; a fresh-dest add or sub is one lea, not mov + alu: lea sets no flags, and aluops feed none.
   ;; at w 4 the 32-bit write zero-extends, and the caller knows the op is one instruction
   (emit-aluw w op d a b)
      (: meta (peep x64-alu op 0) rr (meta 0) ext (meta 1) comm (meta 2)
         ;; xor d,d,d zeroes by the 32-bit form: its write clears the top half, and no REX.W
         (? (op = 'xor && reg-eq d a && reg? b && reg-eq d b) (alu-rr 4 49 d d)
            (reg-eq d a)                  (alu-step w rr ext d b)
            (reg? b && reg-eq d b)    (comm ? (alu-step w rr ext d a) (scare 'alias-dst [op d a b]))
            (op = 'add && reg? b)     (x6gm 'lea w d (MX a b 1 0))
            (op = 'add && fits32 b)   (x6gm 'lea w d (x6m a b))
            (op = 'sub && fits32 -b) (x6gm 'lea w d (x6m a -b))
            ;; a mask of the low 8/16/32 bits is one movzx or 32-bit mov
            (op = 'and && reg? a && elem b '(255 65535 4294967295))
             (emit-zxmw w (b @ 255 1 65535 2 4) d a)
            (emit-movw w d a + alu-step w rr ext d b)))
   (emit-alu op d a b) (emit-aluw 8 op d a b)
   (emit-alu4 op d a b) (emit-aluw 4 op d a b)

   ;; 69 /r id (6B /r ib for a byte) is three-address; register-register folds onto two-address 0F AF /r
   (imul-rr d s) (x6 'imul 8 [(x6g d 8) (x6g s 8)])
   (imul-ri d a imm) (x6 'imul 8 [(x6g d 8) (x6g a 8) (x6i imm)])
   (emit-imul d a b)
      (reg? b ?
         (? (reg-eq d a) (imul-rr d b)
            (reg-eq d b)  (imul-rr d a)
            (emit-mov d a + imul-rr d b))
         (imul-ri d a b))

   shift-ext x86-shift-ext
   ;; D1 /ext for a count of 1, else C1 /ext ib; at w 4 the 32-bit write zero-extends
   (emit-shiftw w op d c)
      (: g (x6g d w) _ (shift-ext op)
         (c @ 1 (x6 op w [g]) (x6gi op w d c)))
   (emit-shift op d c) (emit-shiftw 8 op d c)
   (emit-shift4 op d c) (emit-shiftw 4 op d c)

   ;; 85 /r, or A9 id on rax, else F7 /0 id
   (emit-test a b) (reg? b ? (x6gg 'test 8 a b) (x6gi 'test 8 a b))
   ;; the low byte against an imm8, F6 /0 ib (A8 ib on al); spl..dil and r8b..r15b want a REX
   (emit-testb a k) (x6 'test 1 [(x6g a 1) (x6i k)])
   ;; movzx r32 in place, which clears the top half: no REX.W
   (emit-zxl w d) (emit-zxml w d d)
   ;; d = s's low byte or word into r32, which clears the top half
   (emit-zxml w d s) (: g (x6g d 4) (x6 (w @ 1 'movzb 'movzw) 4 [g (x6g s w)]))
   ;; rsp cannot index (4 means none), and it is sp, never an r0..r14
   (emit-ldx d base index scale disp)
    (: dn (rn d) m (MX base index scale disp) (x6at 'mov 8 (x6k2 8 (x6rq dn 8) (x6mq (m 1) (m 2) disp)) [['rg dn 8] m]))
   (emit-stx base index scale disp s)
    (: sn (rn s) m (MX base index scale disp) (x6at 'mov 8 (x6k2 8 (x6mq (m 1) (m 2) disp) (x6rq sn 8)) [m ['rg sn 8]]))
   (emit-leax d base index scale disp) (: g (x6g d 8) (x6 'lea 8 [g (MX base index scale disp)]))
   (emit-ldxb d base index scale disp) (: g (x6g d 8) (x6 'movzb 8 [g (MX base index scale disp)]))
   (emit-ldxh d base index scale disp) (: g (x6g d 8) (x6 'movzw 8 [g (MX base index scale disp)]))
   (emit-ldxbl d base index scale disp) (: g (x6g d 4) (x6 'movzb 4 [g (MX base index scale disp)]))
   (emit-ldxhl d base index scale disp) (: g (x6g d 4) (x6 'movzw 4 [g (MX base index scale disp)]))
   (emit-ldxw d base index scale disp) (: g (x6g d 4) (x6 'mov 4 [g (MX base index scale disp)]))
   (emit-ldxsw d base index scale disp) (: g (x6g d 8) (x6 'movsl 8 [g (MX base index scale disp)]))
   ;; and/or/xor r32 by a DWORD (23/0B/33 /r); the 32-bit write zeroes the top
   (emit-andx4 d base index scale disp) (: g (x6g d 4) (x6 'and 4 [g (MX base index scale disp)]))
   (emit-orx4 d base index scale disp) (: g (x6g d 4) (x6 'or 4 [g (MX base index scale disp)]))
   (emit-xorx4 d base index scale disp) (: g (x6g d 4) (x6 'xor 4 [g (MX base index scale disp)]))
   (emit-andm4 d base off) (: g (x6g d 4) (x6 'and 4 [g (x6m base off)]))
   (emit-decm base off) (x6 'dec 8 [(x6m base off)])                ; dec qword [base+off], the flags set
   (emit-orm4 d base off) (: g (x6g d 4) (x6 'or 4 [g (x6m base off)]))
   (emit-xorm4 d base off) (: g (x6g d 4) (x6 'xor 4 [g (x6m base off)]))
   (emit-stxb base index scale disp s) (: g (x6g s 1) (x6 'mov 1 [(MX base index scale disp) g]))

   ;; a load into d at width w by name, a store from s
   (ldw mn w d base off)
    (: dn (rn d) bn (rn base)
       (charm? off ? (x6at mn w (x6k2 w (x6rq dn w) (x6mq bn -1 off)) [['rg dn w] ['mem bn -1 1 off]]) (scare 'mem-disp off)))
   (stw w base off s)
    (: sn (rn s) bn (rn base)
       (charm? off ? (x6at 'mov w (x6k2 w (x6mq bn -1 off) (x6rq sn w)) [['mem bn -1 1 off] ['rg sn w]]) (scare 'mem-disp off)))
   (emit-ld d base off)   (ldw 'mov 8 d base off)
   (emit-st base off s)   (stw 8 base off s)
   (emit-lea d base off)  (ldw 'lea 8 d base off)
   (emit-ld1 d base off)  (ldw 'movsb 8 d base off)
   (emit-ld2 d base off)  (ldw 'movsw 8 d base off)
   (emit-ld4 d base off)  (ldw 'movsl 8 d base off)
   (emit-ldu1 d base off) (ldw 'movzb 8 d base off)
   (emit-ldu2 d base off) (ldw 'movzw 8 d base off)
   (emit-ldu1l d base off) (ldw 'movzb 4 d base off)            ; ..into r32, no REX.W
   (emit-ldu2l d base off) (ldw 'movzw 4 d base off)
   (emit-ldu4 d base off) (ldw 'mov 4 d base off)
   (emit-st1 base off s)  (stw 1 base off s)
   (emit-st2 base off s)  (stw 2 base off s)
   (emit-st4 base off s)  (stw 4 base off s)
   ;; cmpm: the flags of [base+off] - y; cmprm: of s - [base+off]
   (emit-cmpm base off y) (x6 'cmp 8 [(x6m base off) (reg? y ? (x6g y 8) (x6i y))])
   (emit-cmprm s base off) (ldw 'cmp 8 s base off)

   ;; read-modify-writes on [base+off] at w 1 2 4 8, for inline asm. base 'rip with off (sym k)
   ;; is rip-relative
   x64-digit '(r0 r1 r2 r3 sp r4 r5 r6)
   (x64-mw w op8 op regf base off tl)
    (: fn (rn regf) rip (base = 'rip) bn (rip ? 0 (rn base))
       rx (w = 8 || fn >= 8 || bn >= 8 || (w = 1 && 4 <= fn <= 7))
       ((w @ 2 [102] ()) + (rx ? [(rex (w @ 8 1 0) (hi fn) 0 (hi bn))])
        + (w @ 1 op8 op)
        + (rip ? [(modrm 0 (lo fn) 5) (fix 4 'rel32 <off (<>off - tl))] (mem fn base off))))
   (mrw mn w base off s) (: g (x6g s w) (x6r mn w [(x6mr base off) g]))
   (emit-xaddm w base off s) (mrw 'xadd w base off s)
   (emit-cmpxchgm w base off s) (mrw 'cmpxchg w base off s)
   (emit-xchgm w base off s) (mrw 'xchg w base off s)
   ;; op m, y: 00+8k/01+8k /r, or 80 /k ib, 83 /k ib, 81 /k id|iw
   (emit-alum op w base off y)
    (: _ (elem op x6t-alu ? 0 (scare 'x64-alum op))
       (reg? y ? (mrw op w base off y) (x6r op w [(x6mr base off) (x6i y)])))
   ;; op d, m: 02+8k/03+8k /r
   (emit-alurm op w d base off)
    (: _ (elem op x6t-alu ? 0 (scare 'x64-alurm op))
       g (x6g d w) (x6r op w [g (x6mr base off)]))
   ;; adc/sbb d, y: 10/11 and 18/19 /r, or 80/83/81 /2 /3, or the accumulator's 14/15 and 1c/1d
   (emit-carry op w d y)
    (: _ (elem op '(adc sbb) ? 0 (scare 'x64-carry op))
       (? (reg? y) (x6k ((op @ 'adc 16 24) + (w @ 1 0 1)) op w [(x6g d w) (x6g y w)])
          (x6 op w [(x6g d w) (x6i y)])))
   ;; test m, y: 84/85 /r, or F6/F7 /0
   (emit-testm w base off y) (reg? y ? (mrw 'test w base off y) (x6r 'test w [(x6mr base off) (x6i y)]))
   ;; inc dec not neg m: FE/FF /0 /1, F6/F7 /2 /3
   (emit-unm op w base off)
    (: _ (elem op '(inc dec not neg) ? 0 (scare 'x64-unm op))
       (x6r op w [(x6mr base off)]))
   ;; bt bts btr btc m, y: 0F A3/AB/B3/BB /r, or 0F BA /4../7 ib
   (emit-btm op w base off y)
    (: _ (elem op '(bt bts btr btc) ? 0 (scare 'x64-btm op))
       (? (w = 1) (scare 'x64-btm-byte op)
          (reg? y) (mrw op w base off y)
          (x6r op w [(x6mr base off) (x6i y)])))

   ;; store immediate: mov r/m, imm by C6/C7 /0; the quad sign-extends its imm32
   (siw w base off n) (x6 'mov w [(x6m base off) (x6i n)])
   (emit-si base off n)   (siw 8 base off n)
   (emit-si1 base off n)  (siw 1 base off n)
   (emit-si2 base off n)  (siw 2 base off n)
   (emit-si4 base off n)  (siw 4 base off n)
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
   (emit-a128r rl rh) (alu-rr 8 1 'r0 rl + (alu-step 8 17 2 'r2 rh))   ; add rax,rl; adc rdx,rh|imm8
   (emit-s128r rl rh) (alu-rr 8 41 rl 'r0 + (alu-rr 8 25 rh 'r2       ; sub rl,rax; sbb rh,rdx
                     + (emit-mov 'r0 rl + emit-mov 'r2 rh)))
   (emit-mw128r rl) (x6 'mul 8 [(x6g rl 8)])    ; mul rl -> rdx:rax
   (emit-m128r rl rh)
      (emit-imul 'r2 'r2 rl                                       ; rdx = Rhi*Llo
       + emit-mov 'r1 rh + emit-imul 'r1 'r1 'r0                ; rcx = Lhi*Rlo
       + alu-rr 8 1 'r1 'r2                                        ; add rcx,rdx
       + emit-mw128r rl                                          ; rdx:rax = Llo*Rlo
       + alu-rr 8 1 'r2 'r1)                                    ; add rdx,rcx
   (emit-c128r cond rl rh)
      (: chain (emit-mov 'r1 rl + (alu-rr 8 41 'r1 'r0              ; rcx=rl; sub rcx,rax
                + (emit-mov 'r1 rh + alu-rr 8 25 'r1 'r2)))         ; rcx=rh; sbb rcx,rdx
         rsub (alu-rr 8 41 'r0 rl + alu-rr 8 25 'r2 rh)               ; sub rax,rl; sbb rdx,rh
         (cond @
          ('eq || 'ne)
           (alu-rr 8 49 'r0 rl + alu-rr 8 49 'r2 rh                ; xor both words, or them
            + alu-rr 8 9 'r0 'r2 + emit-set cond 'r0)
          ('lt || 'below || 'ge || 'ae) (chain + emit-set cond 'r0)
          'gt    (rsub + emit-set 'lt 'r0)
          'above (rsub + emit-set 'below 'r0)
          'le    (rsub + emit-set 'ge 'r0)
          'be    (rsub + emit-set 'ae 'r0)
          (scare 'badcc128 cond)))
   (emit-shl128 c)
      (c < 64 ? [72 15 164 194 (byte c)  72 193 224 (byte c)]   ; shld rdx,rax,c; shl rax,c
         (: s9 (c @ 64 () [72 193 226 (byte (c - 64))])       ; shl rdx,c-64
            ([72 137 194] + s9 + [49 192])))                  ; mov rdx,rax; ..; xor eax,eax
   (emit-shr128 c)
      (c < 64 ? [72 15 172 208 (byte c)  72 193 234 (byte c)]   ; shrd rax,rdx,c; shr rdx,c
       (: s9 (c @ 64 () [72 193 232 (byte (c - 64))])       ; shr rax,c-64
        ([72 137 208] + s9 + [49 210])))                  ; mov rax,rdx; ..; xor edx,edx
   (emit-sar128 c)
      (c < 64 ? [72 15 172 208 (byte c)  72 193 250 (byte c)]   ; shrd rax,rdx,c; sar rdx,c
       (: s9 (c @ 64 () [72 193 248 (byte (c - 64))])       ; sar rax,c-64
        ([72 137 208] + s9 + [72 193 250 63])))           ; mov rax,rdx; ..; sar rdx,63
   ;; u128 in the cell / u64 in rax: qhi = hi/d leaves its remainder in rdx for the low div, so
   ;; neither faults (rdx < d). a zero divisor faults
   (d128-div-pre z9) '(72 137 193                                 ; mov rcx,rax        (d aside)
                  72 139 4 36  72 139 84 36 8                     ; num: rax=[rsp] lo, rdx=[rsp+8] hi
                  72 137 12 36                                    ; mov [rsp],rcx      (d -> the cell)
                  72 137 193  72 137 208  49 210                  ; rcx=lo; rax=hi; xor edx,edx
                  72 247 52 36                                    ; div QWORD [rsp]    (rax=qhi, rdx=r1)
                  72 145                                          ; xchg rax,rcx       (rax=lo, rcx=qhi)
                  72 247 52 36)                                   ; div QWORD [rsp]    (rax=qlo, rdx=rem)
   (emit-dv128 sp9) (d128-div-pre 0 + [72 137 202])              ; mov rdx,rcx: quotient qhi:qlo
   (emit-rm128 sp9) (d128-div-pre 0 + [72 137 208  49 210])      ; rax=rem; xor edx,edx
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
   (emit-divq s) (x6 'div 8 [(x6g s 8)])
   (emit-divl s) (x6 'div 4 [(x6g s 4)])                  ; edx:eax / r32
   ;; the TLS block's first word is its own address: mov d, fs:[0]
   (emit-tp d) (: g (x6g d 8) (x6 'mov 8 [g ['seg 'fs ['mem -1 -1 1 0]]]))
   ;; lock cmpxchg [ptr], new: the old value lands in the accumulator, which must be r0
   (emit-cas w acc new ptr)
    (acc @ 'r0 (: g (x6g new (w @ 1 8 4)) (240 . x6 'cmpxchg (w @ 1 8 4) [(x6m ptr 0) g]))
     (scare 'cas-acc acc))
   ;; movsx/movsxd in place
   (emit-sx w d) (: g (x6g d 8) (x6 (w @ 1 'movsb 2 'movsw 'movsl) 8 [g (x6g d w)]))
   ;; movzx in place; w=4 is mov r32,r32
   (emit-zx w d) (emit-zxm w d d)
   ;; d = s's low w bytes, zero-extended; at w 4 the mov r32,r32 by 8B
   (emit-zxmw ow w d s)
    (? (w = 4) (: g (x6g d 4) (x6k 139 'mov 4 [g (x6g s 4)]))
       (: g (x6g d ow) (x6 (w @ 1 'movzb 'movzw) ow [g (x6g s w)])))
   (emit-zxm w d s) (emit-zxmw 8 w d s)
   ;; D3 /ext counts by cl, which is why the IR pins the count to r1 (rcx); d must differ
   (emit-shiftv op d c)
      (: _ (reg-eq c 'r1 || (scare 'shiftv-count-not-r1 [op d c]),
            reg-eq d 'r1 && (scare 'shiftv-dst-is-r1 [op d c]))
         w (op @ 'rorv4 4 8)                                      ; rorv4 zero-extends
         (x6 (op @ 'shlv 'shl 'shrv 'shr 'sarv 'sar 'ror) w [(x6g d w) ['rg 1 1]]))

   ;; 50+rd / 58+rd, REX.B for r8+; an immediate push is 6A ib or 68 id, sign-extended
   (emit-push s) (? (reg? s) (x6 'push 8 [(x6g s 8)])
                    (fits32 s) (x6 'push 8 [(x6i s)])
                    (scare 'push-imm s))
   (emit-pop  d) (x6 'pop 8 [(x6g d 8)])

   (emit-un op d) (x6 op 8 [(x6g d 8)])

   (jcc-op c) (look x64-cc c 'badcc)
   (jcc-mn pre c) (x6ccn pre c (c \ x6t-ccn pre (jcc-op c & 15)))
   ;; a target fix of 4 bytes or 1, the key its width's
   (x6t4 mn label) (x6at mn 0 (x6k1 0 1098) [['lbl (fix 4 'rel32 label 0)]])
   (x6t1 mn label) (x6at mn 0 (x6k1 0 1050) [['lbl (fix 1 'rel8 label 0)]])
   (emit-call label) (x6t4 'call label)
   ;; rip-relative lea
   (emit-la d label) (emit-laa d label 0)
   (emit-laa d label k) (: dn (rn d) (x6at 'lea 8 (x6k2 8 (x6rq dn 8) 19) [['rg dn 8] (x6rip label k)]))
   ;; lia: the linked address by movabs, not where the pc runs -- for a kernel linked high that
   ;; runs low until paging is on
   (emit-lia d label) (x6 'mov 8 [(x6g d 8) (x6i (fix 8 'abs64 label 0))])
   ;; d <- segment register n (es cs ss ds fs gs = 0..5) by 8C /r; REX.W zero-extends it
   (emit-ldseg d n)
    (: g (x6g d 8)
       (0 <= n <= 5 ? 0 (scare 'x64-segnum n),
        x6 'mov 2 [g ['sr n]]))
   ;; n <- s by 8E /r; segst/segld the pair over memory, 16 bits and no 66
   (emit-stseg n s)
    (: g (x6g s 4)
       (0 <= n <= 5 ? 0 (scare 'x64-segnum n),
        x6 'mov 2 [['sr n] g]))
   (emit-segst n base off) (rn base @ bn ((hi bn != 0 ? [(rex 0 0 0 1)]) + ([140] + mem n base off)))
   (emit-segld n base off) (rn base @ bn ((hi bn != 0 ? [(rex 0 0 0 1)]) + ([142] + mem n base off)))
   (emit-pushl label) (x6 'push 8 [(x6i (fix 4 'abs32s label 0))])
   ;; gas's opcode bytes over memory, the /digit as the register field
   (emit-mdig opc dig w base off) (x64-mw w opc opc (x64-digit dig) base off 0)
   ;; the same over a register, a legacy prefix ahead of the REX
   (emit-rdig pfx opc dig w r)
    (rn r @ n
       (pfx + (w @ 2 [102] ()) + ((w = 8 || n >= 8) ? [(rex (w @ 8 1 0) 0 0 (hi n))]) + opc + [(modrm 3 dig (lo n))]))
   ;; opc d, s at width w: lar, lsl (0F 02, 0F 03 /r)
   (emit-rrop opc w d s)
    (: dn (rn d) sn (rn s)
       ((w @ 2 [102] ()) + ((w = 8 || dn >= 8 || sn >= 8) ? [(rex (w @ 8 1 0) (hi dn) 0 (hi sn))]) + opc + [(modrm 3 (lo dn) (lo sn))]))
   (emit-invpcid r base off) (: g (x6g r 8) (x6r 'invpcid 0 [g (x6mr base off)]))   ; 66 0F 38 82 /r  invpcid r, m128
   (emit-movntim w base off s) (mrw 'movnti w base off s)
   ;; a string op by its stem (A4..AF, 6C..6F); 66 or REX.W widens the odd byte
   (emit-str op w)
    (: _ (elem op '(movs cmps stos lods scas ins outs) ? 0 (scare 'x64-str op))
       (x6 (name (show op + (w @ 1 "b" 2 "w" 8 "q" "d"))) 0 []))
   (emit-jmp  label)     (x6t4 'jmp label)
   ;; the table and its targets are for the analyses, not the machine
   (emit-jmpt d tl labs) (emit-jmpr d)
   (emit-br cond label)  (x6t4 (jcc-mn "j" cond) label)
   ;; the short forms: EB rel8, and 70+cc rel8
   (emit-jmp8 label)     (x6t1 'jmp label)
   (emit-br8 cond label) (x6t1 (jcc-mn "j" cond) label)
   ;; FF /4 and FF /2; no REX.W, the operand size is 64 already
   (emit-jmpr d) (: dn (rn d) (x6at 'jmp 0 (x6k1 0 (x6rq dn 8 * 16 + 5)) [['ind ['rg dn 8]]]))
   (emit-callr d) (: dn (rn d) (x6at 'call 0 (x6k1 0 (x6rq dn 8 * 16 + 5)) [['ind ['rg dn 8]]]))
   (emit-jmpm base off) (x6r 'jmp 0 [['ind (x6m base off)]])
   ;; imul sets OF exactly when the product leaves signed 64, so jo; t is unused
   (emit-mulo d a b t lbl) (emit-imul d a b + x6t4 'jo lbl)
   ;; the high 64 of the signed (F7 /5) or unsigned (F7 /4) product. rdx:rax-fixed: rdx is
   ;; saved round it; b immediate, rax or rdx goes through a stack cell. clobbers rax; d != r2
   (emit-mulh dig d a b)
      (: mn (dig @ 5 'imul 'mul)
         (reg? b && !(reg-eq b 'r0) && !(reg-eq b 'r2) ?
            (catall [(emit-push 'r2)
                     (reg-eq a 'r0 ? () (emit-mov 'r0 a))
                     (x6 mn 8 [(x6g b 8)])
                     (emit-mov d 'r2) (emit-pop 'r2)])
            (catall [(emit-push 'r2) (emit-push b)
                     (reg-eq a 'r0 ? () (emit-mov 'r0 a))
                     (x6 mn 8 [(x6m 'sp 0)])                       ; imul | mul qword [rsp]
                     (emit-mov 'r0 'r2) (alu-ri 8 0 'sp 8) (emit-pop 'r2)
                     (reg-eq d 'r0 ? () (emit-mov d 'r0))])))
   ;; 0F 4x /r; d = s scares
   (emit-cmov cond d s)
      (: dn (rn d) sn (rn s)
         (dn = sn ? (scare 'cmov-alias d) (x6 (jcc-mn "cmov" cond) 8 [(x6g d 8) (x6g s 8)])))
   ;; setcc d8 then movzx d, d8
   (emit-set cond d) (emit-set1 cond d + emit-zxm 1 d d)
   ;; setcc alone (0F 9x), the upper bytes kept. a REX, bare 0x40 for 4..7, names the low byte,
   ;; not ah..bh
   (emit-set1 cond d) (: mn (jcc-mn "set" cond) (x6 mn 1 [(x6g d 1)]))
   ;; rdx:rax-fixed: rdx is saved round it. a divisor in rax gets a stack cell; one in rdx reads
   ;; the save's. clobbers rax
   (emit-div remf sgn d a b)
      (: bn (rn b)
         cell? (reg-eq b 'r0)
         (catall [(emit-push 'r2)
                   (cell? ? (emit-push b))
                   (reg-eq a 'r0 ? () (emit-mov 'r0 a))
                   (sgn ? (x6 'cqo 0 []) (alu-rr 4 49 'r2 'r2))
                   (x6 (sgn ? 'idiv 'div) 8 [(cell? || reg-eq b 'r2 ? (x6m 'sp 0) (x6g b 8))])
                   (remf ? (emit-mov 'r0 'r2))
                   (cell? ? (alu-ri 8 0 'sp 8))
                   (emit-pop 'r2)
                   (reg-eq d 'r0 ? () (emit-mov d 'r0))]))

   ;; sse2: fN is xmmN
   x64-xregs (fregs 16)
   (xrn r) (look x64-xregs r 'badxreg)
   x64-sse x86-sse
   ;; a map 1 opcode under its legacy prefix (0 for none), pfx * 256 + k -> the table's first name
   x64-pxn (foldl (\ t r (: k ((r 4 'p @ () 0 'none 0 66 102 'f3 243 242) * 256 + r 2)
                             (r 1 = 1 && peep t k () = () ? (pin t k <r) t)))
                  {} x64-tab)
   (x6p pfx k w ops) (x6 (peep x64-pxn (pfx * 256 + k) () @ () (scare 'x64-sse [pfx k]) n n) w ops)
   (emit-sse op d s)
      (: meta (peep x64-sse op 0) dn (x6x d) sn (x6x s) (x6p (meta 0) (meta 1) 0 [dn sn]))
   (emit-cmppd d s imm) (: dn (x6x d) sn (x6x s) (x6 'cmppd 0 [dn sn (x6i imm)]))      ; imm 1 lt 2 le
   (emit-movmskpd g x) (: gn (x6g g 4) xn (x6x x) (x6 'movmskpd 4 [gn xn]))
   (emit-cvtsi2sd x g) (: xn (x6x x) gn (x6g g 8) (x6 'cvtsi2sd 8 [xn gn]))
   (emit-cvttsd2si g x) (: gn (x6g g 8) xn (x6x x) (x6 'cvttsd2si 8 [gn xn]))
   (emit-cvtsi2ss x g) (: xn (x6x x) gn (x6g g 8) (x6 'cvtsi2ss 8 [xn gn]))
   (emit-cvttss2si g x) (: gn (x6g g 8) xn (x6x x) (x6 'cvttss2si 8 [gn xn]))
   (emit-movdxr x g) (: xn (x6x x) gn (x6g g 4) (x6 'movd 4 [xn gn]))
   (emit-movdrx g x) (: xn (x6x x) gn (x6g g 4) (x6 'movd 4 [gn xn]))
   (emit-movqxr x g) (: xn (x6x x) gn (x6g g 8) (x6 'movq 8 [xn gn]))
   (emit-movqrx g x) (: xn (x6x x) gn (x6g g 8) (x6 'movq 8 [gn xn]))
   ;; movsd/movss to and from memory: F2/F3 0F 11 /r stores, 0F 10 /r loads
   (emit-stsd base disp s) (: x (x6x s) (x6 'movsd 0 [(x6m base disp) x]))
   (emit-ldsd d base disp) (: x (x6x d) (x6 'movsd 0 [x (x6m base disp)]))
   (emit-stss base disp s) (: x (x6x s) (x6 'movss 0 [(x6m base disp) x]))
   (emit-ldss d base disp) (: x (x6x d) (x6 'movss 0 [x (x6m base disp)]))
   (emit-ldsdl d label) (: x (x6x d) (x6 'movsd 0 [x (x6rip label 0)]))                  ; xmm(d) <- [rip+label]
   ;; a scalar op with its source in memory: d op= [base+disp], or [rip+label]
   (emit-fopm op d base disp)
      (emit-fop op d (x6m base disp))
   (emit-fopl op d label) (emit-fop op d (x6rip label 0))
   (emit-fop op d m) (: meta (peep x64-sse op 0) x (x6x d) (x6p (meta 0) (meta 1) 0 [x m]))
   (emit-ldsdx d base index scale disp) (: x (x6x d) (x6 'movsd 0 [x (MX base index scale disp)]))
   (emit-stsdx base index scale disp s) (: x (x6x s) (x6 'movsd 0 [(MX base index scale disp) x]))
   (emit-ldssx d base index scale disp) (: x (x6x d) (x6 'movss 0 [x (MX base index scale disp)]))
   (emit-stssx base index scale disp s) (: x (x6x s) (x6 'movss 0 [(MX base index scale disp) x]))

   ;; the system lane, for kernels. lgdt/lidt/invlpg/sgdt/sidt are 0F 01 by Modrm digit; no REX.W
   (emit-m0f mn base off) (x6 mn 0 [(x6m base off)])
   ;; 0F 20 reads, 0F 22 writes; the CR number in Modrm.reg (REX.R reaches cr8), no REX.W
   (emit-cr k n g)
      (: gn (x6g g 8)
         (0 <= n <= 15 ? 0 (scare 'x64-crnum n),
          x6 'mov 8 (k @ 'cr [gn ['cr n]] 'wcr [['cr n] gn] 'dr [gn ['dr n]] [['dr n] gn])))
   ;; the VMX pointer ops, 0F C7 /6 [paddr] under a legacy prefix, which must lead the REX
   (emit-vmp mn base off) (x6 mn 0 [(x6m base off)])
   ;; vmread/vmwrite: Modrm.reg the field, rm the GPR; no REX.W
   (emit-vmread d f) (: g (x6g d 8) (x6 'vmread 8 [g (x6g f 8)]))      ; d <- vmcs[f]
   (emit-vmwrite f s) (: g (x6g f 8) (x6 'vmwrite 8 [g (x6g s 8)]))   ; vmcs[f] <- s
   (emit-ldcr d n) (emit-cr 'cr n d)        ; d <- crn
   (emit-stcr n s) (emit-cr 'wcr n s)       ; crn <- s
   (emit-lddr d n) (emit-cr 'dr n d)        ; d <- drn
   (emit-stdr n s) (emit-cr 'wdr n s)       ; drn <- s
   (emit-ltr s) (x6 'ltr 2 [(x6g s 2)])       ; 0F 00 /3
   ;; CD ib for every vector, 3 included: int3 (CC) is trap, and the two differ under vm86
   (emit-int n) (0 <= n <= 255 ? 0 (scare 'x64-int-vector n), x6 'int 0 [(x6i n)])
   emit-seg x86-seg
   ;; bsr bsf 0F BD/BC, lzcnt tzcnt popcnt F3 0F BD/BC/B8; a 32-bit scan reads the low half only
   (emit-bscan op w d s)
    (: dn (x6g d w) sn (x6g s w)
       (w @ 1 (scare 'x64-bscan-byte op)
          (elem op '(bsr bsf lzcnt tzcnt popcnt) ? (x6 op w [dn sn]) (scare 'x64-bscan op))))

   ;; a row is a partial application, a nullary row its bytes, raw the identity (1)
   x64-emitters (emsof
        [('li . emit-li) ('li2 . emit-li2) ('mov . emit-mov) ('cmp . emit-cmp) ('imul . emit-imul)
         ('ld . emit-ld) ('st . emit-st)
         ('lea . emit-lea) ('lean . emit-lea)              ; lean: the same bytes, unseen by the sibcall escape check
         ('ldx . emit-ldx) ('stx . emit-stx) ('leax . emit-leax)
         ('ldxb . emit-ldxb) ('ldxh . emit-ldxh) ('ldxbl . emit-ldxbl) ('ldxhl . emit-ldxhl) ('stxb . emit-stxb) ('ldxw . emit-ldxw) ('ldxsw . emit-ldxsw)
         ('andx4 . emit-andx4) ('orx4 . emit-orx4) ('xorx4 . emit-xorx4) ('andm4 . emit-andm4) ('orm4 . emit-orm4) ('xorm4 . emit-xorm4) ('decm . emit-decm)
         ('ldsdx . emit-ldsdx) ('stsdx . emit-stsdx) ('ldssx . emit-ldssx) ('stssx . emit-stssx)
         ('ldsdl . emit-ldsdl) ('fopm . emit-fopm) ('fopl . emit-fopl)
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
         ('ldu1 . emit-ldu1) ('ldu2 . emit-ldu2) ('ldu1l . emit-ldu1l) ('ldu2l . emit-ldu2l) ('zxml . emit-zxml) ('ldu4 . emit-ldu4)
         ('cas . emit-cas 1) ('cas4 . emit-cas 0) ('tp . emit-tp)
         ('sx1 . emit-sx 1) ('sx2 . emit-sx 2) ('sx4 . emit-sx 4)
         ('zx1 . emit-zx 1) ('zx2 . emit-zx 2) ('zx4 . emit-zx 4)
         ('shlv . emit-shiftv 'shlv) ('shrv . emit-shiftv 'shrv) ('sarv . emit-shiftv 'sarv)
         ('rorv . emit-shiftv 'rorv) ('rorv4 . emit-shiftv 'rorv4)
         ('shl . emit-shift 'shl) ('shr . emit-shift 'shr) ('sar . emit-shift 'sar)
         ('rol . emit-shift 'rol) ('ror . emit-shift 'ror) ('ror4 . emit-shift4 'ror) ('shl4 . emit-shift4 'shl)
         ('test . emit-test) ('testb . emit-testb) ('zxl1 . emit-zxl 1) ('zxl2 . emit-zxl 2) ('push . emit-push) ('pop . emit-pop)
         ('neg . emit-un 'neg) ('not . emit-un 'not) ('inc . emit-un 'inc) ('dec . emit-un 'dec)
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
         ('vmxon . emit-vmp 'vmxon) ('vmclear . emit-vmp 'vmclear) ('vmptrld . emit-vmp 'vmptrld)
         ('vmread . emit-vmread) ('vmwrite . emit-vmwrite)
         ('sgdt . emit-m0f 'sgdt) ('sidt . emit-m0f 'sidt)
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
         ('alum . emit-alum) ('carry . emit-carry) ('alurm . emit-alurm) ('alu4 . emit-alu4) ('unm . emit-unm) ('btm . emit-btm) ('testm . emit-testm)
         ('ldcr . emit-ldcr) ('stcr . emit-stcr) ('lddr . emit-lddr) ('stdr . emit-stdr)
         ('lgdt . emit-m0f 'lgdt) ('lidt . emit-m0f 'lidt)
         ('invlpg . emit-m0f 'invlpg)])
   _ (map (k \ emrow x64-emitters k (emit-alu k)) (keys x64-alu))
   _ (map (k \ emrow x64-emitters k (emit-sse k)) (keys x64-sse))
   (x64-lower ins) (lower-via @ f (lit? f ? (f x64-emitters ins) (scare 'holo-bake-stale 'lower-via)))

   x64-patch x86-patch
   ;; a pad of k bytes as the long nops (0F 1F /0 and its 66 forms), 10 bytes at most each, as clang
   x64-nops [() '(144) '(102 144) '(15 31 0) '(15 31 64 0) '(15 31 68 0 0) '(102 15 31 68 0 0)
             '(15 31 128 0 0 0 0) '(15 31 132 0 0 0 0 0) '(102 15 31 132 0 0 0 0 0)
             '(102 46 15 31 132 0 0 0 0 0)]
   (x64-pad k) (k < 11 ? (x64-nops k) (x64-nops 10 + x64-pad (k - 10)))

   x64 {'lower x64-lower
        'patch x64-patch
        'nop '(144)
        'pad x64-pad
        ;; holo may rewrite (li d 0) to (xor d d d) where the flags are free. flagw lands a whole
        ;; fresh set: inc/dec keep CF, a shift by 0 keeps all, imul/idiv leave some undefined
        'zeroxor 1
        'flagr '(br set cmov adc sbb)
        'flagw '(cmp cmpm cmprm test add sub and or xor alu4 shl4 andx4 orx4 xorx4 andm4 orm4 xorm4 adds subs neg mulo ucomisd ucomiss)
        'short x86-short}
   (defbackend 'x64 x64))
) ; module 'holo
