; as -- a GNU x86-64 assembler over holo: dialect.l reads either dialect into one value, and
; this encodes it to the byte/fixup item stream x64.l produces, for obj.l and link.l. the
; encoders mirror x64.l form for form, but take physical registers and carry the operand width
; and the mode (64, or i386's 32 and 16). branches are near, never relaxed.
;
; load after holo.l, x64.l and dialect.l:
;   out/love -l src/love/holo/holo.l -l src/love/holo/x64.l -l src/love/holo/dialect.l -l src/love/holo/as.l ...

(module 'holo
(:
   (as-hi n) (n >> 3)  (as-lo n) (n & 7)
   (as-rex f w r x b) (f > 0 || w > 0 || r > 0 || x > 0 || b > 0 ?   ; only when a bit is set,
                         [(64 | (w << 3 | (r << 2 | (x << 1 | b))))] ())    ; or f forces one
   (as-mrm m r rm)  (m << 6 | ((r & 7) << 3 | rm & 7))
   (as-sib sc ix b) (sc << 6 | ((ix & 7) << 3 | b & 7))
   (as-scb s) (s @ 1 0 2 1 4 2 8 3 (scare 'as-badscale s))
   (as-regn o) (<>o >= 16 ? (<>o - 16) <>o)            ; a register operand's encoding number (ah..bh: 4..7)
   (as-regw o) (<o = 'rg ? <>>o 0)                      ; ... and its width, 0 if it isn't one
   ;; spl/bpl/sil/dil name the low four's bytes only under a REX -- bare, those slots spell
   ;; ah/ch/dh/bh -- so a byte operand in 4..7 forces an otherwise-empty one.
   (as-frc o) (as-regw o != 1 || <>o >= 16 ? 0 (4 <= as-regn o <= 7))
   (as-frcs ops) (foldl (a \ o \ a > 0 ? a (as-frc o)) 0 ops)

   ;; the r/m half: a register (mod 3), or memory as Modrm (+ SIB) (+ disp), the REX X and B bits
   ;; apart. an rbp/r13 base has no disp-less form (mod 0 there means disp32), so it takes a disp
   ;; byte; an rsp/r12 base needs a SIB; a base-less form is mod 0 + SIB base 5 + disp32;
   ;; rip-relative is mod 0, rm 5 and a rel32 fixup, its displacement the addend.
   ;; the mode md: 64 (x86-64), 32 or 16 (i386's segments). outside 64 there is no REX; an
   ;; operand of the other width takes 66, and memory takes 67 where its registers' width is not
   ;; the segment's. dialect.l marks a 16-bit address register +32 (bx bp si di: 35 37 38 39),
   ;; and 32-bit ones by a seventh field, 'a32, which a 64-bit segment lays as 67
   (as-osz md w) (? (md = 16) (w @ 4 '(102) ()) (w @ 2 '(102) ()))
   (as-rexm md f w r x b) (? (md = 64) (as-rex f w r x b)
                             (f > 0 || w > 0 || r > 0 || x > 0 || b > 0) (scare 'as-rex-mode [md f w r x b])
                             ())
   (as-a16? o) (<o = 'mem && (o 1 >= 32 || o 2 >= 32))
   (as-abs? o) (<o = 'mem && o 1 < 0 && o 2 < 0)
   (as-a32? o) (6 < #o && o 6 = 'a32)
   (as-asz md o) (? !(<o = 'mem) ()
                    (md = 64) (as-a32? o ? '(103) ())
                    (as-a16? o) (md = 32 ? '(103) ())
                    (as-abs? o) ()
                    (md = 16 ? '(103) ()))
   ;; 16-bit addressing's table: a base and an index (either order) -> rm, by the registers'
   ;; numbers (bx 3 bp 5 si 6 di 7); -1 when the pair has no row
   (as-a16rm b ix) (: x (b < ix ? ix b) y (b < ix ? b ix)       ; x the larger, y the smaller
                      (? (y < 0) (x @ 6 4 7 5 5 6 3 7 -1)
                         (y = 3) (x @ 6 0 7 1 -1)
                         (y = 5) (x @ 6 2 7 3 -1)
                         -1))
   (as-mem16 rf o)
      (: b (o 1 < 0 ? -1 (o 1 - 32)) ix (o 2 < 0 ? -1 (o 2 - 32)) d (o 4)
         sy (5 < #o ? (o 5) ())
         rm (as-a16rm b ix)
         (? (rm < 0) (scare 'as-mem16 o)
            (o 3 != 1) (scare 'as-mem16-scale o)
            sy ([(as-mrm 2 rf rm)] + [(fix 2 'abs16 sy d)])
            (d = 0 && rm != 6) [(as-mrm 0 rf rm)]
            (fits8 d) [(as-mrm 1 rf rm) (byte d)]
            ([(as-mrm 2 rf rm)] + le16 d)))
   (as-mem-rm md rf o n)
      (: b (o 1) ix (o 2) sc (o 3) d (o 4)
         sy (5 < #o ? (o 5) ())                            ; a symbol displacement: four bytes, sign-extended in 64
         d4 (sy ? [(fix 4 (md = 64 ? 'abs32s 'abs32) sy d)] (le32 d))
         _ (md = 64 && (b >= 32 || ix >= 32) && scare 'as-mem16-mode o)
         (? (as-a16? o) (as-mem16 rf o)
            (md = 16 && b < 0 && ix < 0)                    ; an absolute address in a 16-bit segment: disp16
             ([(as-mrm 0 rf 6)] + (sy ? [(fix 2 'abs16 sy d)] (le16 d)))
            (md = 32 && b < 0 && ix < 0) ([(as-mrm 0 rf 5)] + d4)   ; ..and in a 32-bit one, no SIB
            (as-mem32 rf o b ix sc d sy d4 n)))
   ; n scales a disp8: EVEX's disp8*N, 1 elsewhere
   (as-mem32 rf o b ix sc d sy d4 n)
         (b < 0 ? ([(as-mrm 0 rf 4) (as-sib (as-scb sc) (ix < 0 ? 4 ix) 5)] + d4)
            (: md (? sy 2 (d = 0 && !(as-lo b = 5)) 0 (d % n = 0 && fits8 (d // n)) 1 2)
               dsp (md @ 0 () 1 [(byte (d // n))] d4)
               hd (? (ix >= 0)      [(as-mrm md rf 4) (as-sib (as-scb sc) ix b)]
                     (as-lo b = 4)  [(as-mrm md rf 4) (as-sib 0 4 b)]
                     [(as-mrm md rf (as-lo b))])
               (hd + dsp)))
   (as-rm md rf o) (as-rmn md rf o 1)
   (as-rmn md rf o n) (<o @ 'mem (as-mem-rm md rf o n)
                      'rip (? (md != 64) (scare 'as-rip-mode o)
                              (nom? <>o) [(as-mrm 0 rf 5) (fix 4 'rel32 <>o <>>o)]
                              ([(as-mrm 0 rf 5)] + le32 <>>o))   ; `0(%rip)`: a bare displacement
                      'rg  [(as-mrm 3 rf (as-regn o))]
                      (scare 'as-notrm o))
   (as-rm-x o)  (<o @ 'mem (<>>o @ i (i < 0 || i >= 32 ? 0 (as-hi i))) 0)
   (as-rm-b o)  (<o @ 'mem (<>o @ b (b < 0 || b >= 32 ? 0 (as-hi b)))
                      'rip 0
                      (as-hi (as-regn o)))
   (as-mem? o)  (<o = 'mem || <o = 'rip)

   ;; --- operand size: the value carries it resolved (dialect.l's xa-width), 0 when neither the
   ;; text nor a register said -- fine for the 64-bit-default forms (push/pop/call/jmp), a raise
   ;; for anything else. the 66 prefix is as-osz's, by mode; width 1 takes the opcode one below
   ;; the wide one (89/88, 01/00, c7/c6, f7/f6, ff/fe all sit in that relation). ---
   (as-rexw w) (w = 8)
   (as-opw opc w) (w @ 1 (opc - 1) opc)
   (as-imw w n)   (w @ 1 [(byte n)] 2 (le16 n) (le32 n))
   ;; the reg-with-r/m family: size prefixes, REX, opcode, Modrm tail. `rn` is the reg field,
   ;; a register or an opcode extension digit
   (as-emit md w frc opc rn rm)
      (catall [(as-asz md rm) (as-osz md w) (as-rexm md frc (as-rexw w) (as-hi rn) (as-rm-x rm) (as-rm-b rm))
                opc (as-rm md rn rm)])

   ;; mnemonic -> (rr-opcode imm-ext): the table's opcode is reg -> r/m, and r/m -> reg is +2
   as-alu {'add '(1 0) 'or '(9 1) 'and '(33 4) 'sub '(41 5) 'xor '(49 6) 'cmp '(57 7)}
   ;; jcc -> the low byte of 0F 8x
   as-cc {'jo 128 'jno 129 'jb 130 'jc 130 'jnae 130 'jae 131 'jnb 131 'jnc 131
          'je 132 'jz 132 'jne 133 'jnz 133 'jbe 134 'jna 134 'ja 135 'jnbe 135
          'js 136 'jns 137 'jp 138 'jpe 138 'jnp 139 'jpo 139
          'jl 140 'jnge 140 'jge 141 'jnl 141 'jle 142 'jng 142 'jg 143 'jnle 143}
   ;; the rel8-only branches -> their opcode
   as-loops {'loop 226 'loope 225 'loopz 225 'loopne 224 'loopnz 224 'jecxz 227 'jrcxz 227 'jcxz 227}

   ;; alu $imm,r/m: 80 /ext ib for a byte, else 83 /ext ib where the immediate fits, else 81 /ext iz
   (as-alu-i md ext w frc rm imm)
      (? (w = 1)     (as-emit md 1 frc '(128) ext rm + [(byte imm)])
         (fits8 imm) (as-emit md w frc '(131) ext rm + [(byte imm)])
         (as-emit md w frc '(129) ext rm + as-imw w imm))

   ;; mov $imm,%reg: b0/b8+r by width; at width 8, c7 /0 id where it fits signed-32, else movabs
   (as-mov-ri md d w frc imm)
      (as-rexm md frc (as-rexw w) 0 0 (as-hi d) @ rx
         (? (w = 1) (catall [rx [(176 | as-lo d) (byte imm)]])
            (w = 2) (catall [(as-osz md 2) rx [(184 | as-lo d)] (le16 imm)])
            (w = 4) (catall [(as-osz md 4) rx [(184 | as-lo d)] (le32 imm)])
            (fits32 imm) (catall [rx [199 (as-mrm 3 0 d)] (le32 imm)])
            (catall [rx [(184 | as-lo d)] (le64 imm)])))

   ;; the per-instruction encoders, in AT&T operand order.
   ;; a rip-relative operand with an immediate tail: x64-patch measures rel32 from the end of its
   ;; own field, so the fix's aux steps back over the n immediate bytes that follow it
   (as-imt bs n o) (<o = 'rip ? (as-riptail bs n) bs)
   (as-riptail bs n) (map (x \ (two? x && <x = 'fix && x 2 = 'rel32 ? (fix (x 1) 'rel32 (x 3) (x 4 - n)) x)) bs)
   (as-2 md mn w a b)                                           ; AT&T src,dst
      (: ka <a kb <b frc (as-frcs [a b])
         alu (as-alu mn)
         rr  (mn @ 'mov 137 'test 133 (alu @ (a . _) a 0))
         opi (mn @ 'mov 199 'test 247 0)          ; the imm-to-r/m opcode, 0 = the ALU's
         (? (mn = 'lea)
            (kb = 'rg && as-mem? a ?
             (as-emit md w frc '(141) (as-regn b) a)
             (scare 'as-lea-form [a b]))
            (rr = 0) (scare 'as-op2 mn)
            (w = 0)  (scare 'as-nowidth [mn a b])
            (as-mem? a && as-mem? b) (scare 'as-twomem [a b])
            (ka = 'rg) (as-emit md w frc [(as-opw rr w)] (as-regn a) b)                ; reg -> r/m
            (kb = 'rg && as-mem? a)                                              ; r/m -> reg
            (as-emit md w frc [(as-opw (mn @ 'test rr (rr + 2)) w)] (as-regn b) a)
            (ka = 'im)                                                             ; $imm -> r/m
            (: im <>a
               bs (? (mn = 'mov && kb = 'rg) (as-mov-ri md (as-regn b) w frc im)
                     (opi > 0) (as-emit md w frc [(as-opw opi w)] 0 b + as-imw w im)
                     (as-alu-i md <>alu w frc b im))
               ; the immediate's width as its encoder laid it: 80/83's byte, else the operand's
               n (? (opi > 0) (w @ 1 1 2 2 4) (w = 1 || fits8 im) 1 (w @ 2 2 4))
               (<b = 'rip ? (as-riptail bs n) bs))
            (scare 'as-op2-form [a b])))
   (as-1 md mn w a)
      (: k <a  frc (as-frc a)
         ; push/pop take 66 but never REX.W; outside 64 the width is the suffix's or the register's
         pw (? (md = 64) (w @ 2 2 0) (w > 0) w (k = 'rg) (as-regw a) 0)
         ; a near target: its field is the operand's width (callw in a 32-bit segment, calll in a 16-bit one)
         ow (? (elem mn '(callw jmpw)) 2 (elem mn '(calll jmpl)) 4 (md = 16) 2 4)
         (rel sym) (ow = 2 ? (fix 2 'rel16 sym 0) (fix 4 'rel32 sym 0))
         (? (mn = 'push)                                     ; ff /6
            (k @ 'rg (as-regn a @ n
                        (as-osz md pw + (n >= 8 ? [65 (80 | as-lo n)] [(80 | n)])))
                 ; 6a ib where it fits, else 68 with the operand's word (a 64-bit push's four, sign-extended)
                 'im (: v <>a iw (? (pw = 2) 2 (pw = 4) 4 (md = 16) 2 4)
                        (as-osz md pw + (fits8 v ? [106 (byte v)] (104 . (iw = 2 ? (le16 v) (le32 v))))))
                 (as-emit md pw 0 '(255) 6 a))
            (mn = 'pop)                                      ; 8f /0
            (k @ 'rg (as-regn a @ n
                        (as-osz md pw + (n >= 8 ? [65 (88 | as-lo n)] [(88 | n)])))
                 (as-emit md pw 0 '(143) 0 a))
            (elem mn '(neg not inc dec))
            (: opc (elem mn '(inc dec) ? 255 247)
               ext (mn @ 'neg 3 'not 2 'inc 0 1)
               (w @ 0 (scare 'as-nowidth [mn a]) (as-emit md w frc [(as-opw opc w)] ext a)))
            (k = 'ind)                                       ; call/jmp through a register or memory
            (a 1 @ o
               (? (elem mn '(call calll callw callq)) (as-emit md (mn @ 'callw 2 'calll 4 0) 0 '(255) 2 o)
                  (elem mn '(jmp jmpl jmpw jmpq)) (as-emit md (mn @ 'jmpw 2 'jmpl 4 0) 0 '(255) 4 o)
                  (scare 'as-op1 mn)))
            (elem mn '(call jmp calll jmpl callw jmpw))
            (a 1 @ sym ((mn @ 'callw (as-osz md 2) 'calll (as-osz md 4) 'jmpw (as-osz md 2) 'jmpl (as-osz md 4) ())
                        + (elem mn '(call calll callw) ? [232 (rel sym)] [233 (rel sym)])))
            (as-cc mn) (a 1 @ sym [15 (peep as-cc mn 0) (rel sym)])
            ; the rel8-only branches: loop, and jecxz (67 in a 64-bit segment, which jrcxz spells bare)
            (charm? (peep as-loops mn ()))
             (a 1 @ sym ((mn = 'jecxz && md = 64 ? [103] ()) + [(as-loops mn) (fix 1 'pc8 sym 0)]))
            (scare 'as-op1 mn)))
   ;; the nullaries: the reader folds AT&T's c<from>t<to> family and retq/leaveq/xlatb onto these
   as-nils {'ret '(195) 'nop '(144) 'hlt '(244)
            'syscall '(15 5) 'leave '(201)
            'cbw '(102 152) 'cwde '(152) 'cdqe '(72 152)      ; al -> ax, ax -> eax, eax -> rax
            'cwd '(102 153) 'cdq '(153) 'cqo '(72 153)        ; .. and the dx:ax splits
            'int3 '(204) 'ud2 '(15 11) 'pause '(243 144)
            'cpuid '(15 162) 'rdtsc '(15 49) 'rdtscp '(15 1 249)
            'cli '(250) 'sti '(251)
            'pushf '(156) 'pushfq '(156) 'popf '(157) 'popfq '(157)
            'clc '(248) 'stc '(249) 'cmc '(245)
            'cld '(252) 'std '(253)
            'lahf '(159) 'sahf '(158)
            'xlat '(215)
            'sysret '(15 7) 'sysretl '(15 7) 'sysretq '(72 15 7)
            'lretq '(72 203) 'sysenter '(15 52) 'sysexit '(15 53)
            'endbr64 '(243 15 30 250) 'endbr32 '(243 15 30 251)          ; IBT's landing pads
            'vmcall '(15 1 193) 'vmmcall '(15 1 217)
            'lock '(240) 'rep '(243) 'repe '(243) 'repz '(243) 'repne '(242) 'repnz '(242)}   ; a prefix the reader parted
   ;; ..and in a 16- or 32-bit segment: a size suffix (w l, the string ops' b w d) sets the operand,
   ;; none takes the segment's own; the prefixes stand alone, as gas reads `rep; movsb`
   as-sized {'ret 195 'lret 203 'iret 207 'pushf 156 'popf 157 'pusha 96 'popa 97}
   as-strs {'movs 165 'stos 171 'lods 173 'cmps 167 'scas 175 'ins 109 'outs 111}
   as-nil32 {'rep '(243) 'repe '(243) 'repz '(243) 'repne '(242) 'repnz '(242) 'lock '(240)
             'wbinvd '(15 9) 'invd '(15 8) 'wrmsr '(15 48) 'rdmsr '(15 50) 'clts '(15 6)}
   (as-0 md mn) (? (md = 64) (as-nils mn @ () (scare 'as-op0 mn) b b) (as-0n mn md))
   (as-0n mn md)
    (: t (show mn) n #t c (t (n - 1)) stem (name (snip t 0 (n - 1)))
       sw (c @ 98 1 119 2 108 4 100 4 0)              ; b w l d
       (? (two? (peep as-nil32 mn ())) (as-nil32 mn)
          (charm? (peep as-sized mn ())) [(as-sized mn)]
          (1 < sw && charm? (peep as-sized stem ())) (as-osz md sw + [(as-sized stem)])
          (0 < sw && charm? (peep as-strs stem ())) (sw = 1 ? [(as-strs stem - 1)] (as-osz md sw + [(as-strs stem)]))
          (elem mn '(cbw cwde cwd cdq)) (as-osz md (elem mn '(cbw cwd) ? 2 4) + [(elem mn '(cbw cwde) ? 152 153)])
          (elem mn '(cdqe cqo syscall sysret sysretq pushfq popfq lretq)) (scare 'as-op0-mode [mn md])
          (as-nils mn @ () (scare 'as-op0 mn) b b)))

   ;; past the GPR core, ops destination first. SSE by a table of (prefix opcode), register <-
   ;; r/m, with a store row for a move to memory; REX.W only where a general register is 64 wide.
   ;; a symbol as an immediate is an absolute fix (non-PIE); cmov/set key off jcc's table
   as-sse {'addsd [[242] 88] 'subsd [[242] 92] 'mulsd [[242] 89] 'divsd [[242] 94]
              'minsd [[242] 93] 'maxsd [[242] 95] 'sqrtsd [[242] 81] 'addss [[243] 88]
              'subss [[243] 92] 'mulss [[243] 89] 'divss [[243] 94] 'minss [[243] 93]
              'maxss [[243] 95] 'sqrtss [[243] 81] 'addps [() 88] 'subps [() 92]
              'mulps [() 89] 'divps [() 94] 'addpd [[102] 88] 'subpd [[102] 92]
              'mulpd [[102] 89] 'divpd [[102] 94] 'andps [() 84] 'andpd [[102] 84]
              'andnps [() 85] 'andnpd [[102] 85] 'orps [() 86] 'orpd [[102] 86]
              'xorps [() 87] 'xorpd [[102] 87] 'ucomisd [[102] 46] 'ucomiss [() 46]
              'comisd [[102] 47] 'comiss [() 47] 'cvtss2sd [[243] 90] 'cvtsd2ss [[242] 90]
              'cvtdq2pd [[243] 230] 'cvtdq2ps [() 91] 'cvttps2dq [[243] 91] 'cvtps2pd [() 90]
              'cvtpd2ps [[102] 90] 'cvtsi2sd [[242] 42] 'cvtsi2ss [[243] 42] 'cvttsd2si [[242] 44]
              'cvtsd2si [[242] 45] 'cvttss2si [[243] 44] 'cvtss2si [[243] 45] 'unpcklps [() 20]
              'unpcklpd [[102] 20] 'unpckhps [() 21] 'unpckhpd [[102] 21] 'movlhps [() 22]
              'movhlps [() 18] 'pxor [[102] 239] 'pand [[102] 219] 'pandn [[102] 223]
              'por [[102] 235] 'paddb [[102] 252] 'paddw [[102] 253] 'paddd [[102] 254]
              'paddq [[102] 212] 'psubb [[102] 248] 'psubw [[102] 249] 'psubd [[102] 250]
              'psubq [[102] 251] 'pcmpeqb [[102] 116] 'pcmpeqw [[102] 117] 'pcmpeqd [[102] 118]
              'pcmpgtb [[102] 100] 'pcmpgtw [[102] 101] 'pcmpgtd [[102] 102] 'pmovmskb [[102] 215]
              'punpcklbw [[102] 96] 'punpcklwd [[102] 97] 'punpckldq [[102] 98] 'punpcklqdq [[102] 108]
              'punpckhqdq [[102] 109] 'pmullw [[102] 213] 'pminub [[102] 218] 'pmaxub [[102] 222]
              'psadbw [[102] 246] 'movmskpd [[102] 80] 'movmskps [() 80] 'movaps [() 40]
              'movapd [[102] 40] 'movups [() 16] 'movupd [[102] 16] 'movsd [[242] 16]
              'movss [[243] 16] 'movdqa [[102] 111] 'movdqu [[243] 111]
              'movhps [() 22] 'movlps [() 18] 'movhpd [[102] 22] 'movlpd [[102] 18]}
   ; imm8 forms: name -> (prefix opcode) with the immediate last (shufps, pshufd), or
   ; (prefix opcode digit) for a shift of the whole register by the immediate
   as-ssi {'shufps [() 198] 'shufpd [[102] 198] 'pshufd [[102] 112] 'pshuflw [[242] 112] 'pshufhw [[243] 112]}
   ; the three-byte rows: 0F 38 xx, and 0F 3A xx with an imm8 last (sha256rnds2's xmm0 is implied)
   as-s38 {'pshufb [[102] 0] 'movntdqa [[102] 42] 'sha256rnds2 [() 203] 'sha256msg1 [() 204] 'sha256msg2 [() 205]
           'sha1nexte [() 200] 'sha1msg1 [() 201] 'sha1msg2 [() 202]
           'pblendvb [[102] 16] 'blendvps [[102] 20] 'blendvpd [[102] 21]
           'pmovsxbw [[102] 32] 'pmovsxbd [[102] 33] 'pmovsxbq [[102] 34] 'pmovsxwd [[102] 35]
           'pmovsxwq [[102] 36] 'pmovsxdq [[102] 37] 'pmovzxbw [[102] 48] 'pmovzxbd [[102] 49]
           'pmovzxbq [[102] 50] 'pmovzxwd [[102] 51] 'pmovzxwq [[102] 52] 'pmovzxdq [[102] 53]}
   as-s3a {'palignr [[102] 15] 'pblendw [[102] 14] 'pclmulqdq [[102] 68] 'sha1rnds4 [() 204]
           'pinsrb [[102] 32] 'pinsrd [[102] 34]}
   ; pclmulqdq's spellings of its immediate, which halves it multiplies
   as-clmul {'pclmullqlqdq 0 'pclmulhqlqdq 1 'pclmullqhqdq 16 'pclmulhqhqdq 17}
   as-ssh {'psrlw [113 2] 'psraw [113 4] 'psllw [113 6] 'psrld [114 2] 'psrad [114 4] 'pslld [114 6]
           'psrlq [115 2] 'psllq [115 6] 'psrldq [115 3] 'pslldq [115 7]}
   as-shf {'rol 0 'ror 1 'rcl 2 'rcr 3 'shl 4 'sal 4 'shr 5 'sar 7}
   as-sse2 {'punpckhbw [[102] 104] 'punpckhwd [[102] 105] 'punpckhdq [[102] 106] 'pmuludq [[102] 244]
            'pmulhw [[102] 229] 'pmulhuw [[102] 228] 'pmaddwd [[102] 245] 'packuswb [[102] 103]
            'packsswb [[102] 99] 'packssdw [[102] 107] 'pmaxsw [[102] 238] 'pminsw [[102] 234]
            'pavgb [[102] 224] 'pavgw [[102] 227] 'psubusb [[102] 216] 'psubusw [[102] 217]
            'paddusb [[102] 220] 'paddusw [[102] 221] 'psubsb [[102] 232] 'psubsw [[102] 233]
            'paddsb [[102] 236] 'paddsw [[102] 237] 'pcmpgtq [[102] 55]}
   as-sst {'movaps [() 41] 'movapd [[102] 41] 'movups [() 17] 'movupd [[102] 17]
              'movsd [[242] 17] 'movss [[243] 17] 'movdqa [[102] 127] 'movdqu [[243] 127]
              'movhps [() 23] 'movlps [() 19] 'movhpd [[102] 23] 'movlpd [[102] 19]}
   ; a cmov/set condition -> jcc's low byte, past a width suffix if it carries one; none is 0
   (as-ccl nm k) (: c (snip nm k #nm) v (peep as-cc (name ("j" + c)) 0)
                    (0 < v || #c < 2 ? v (peep as-cc (name ("j" + snip c 0 (#c - 1))) 0)))
   (as-sym o) (as-symw o 4)                                             ; `$sym+k` -> its fix
   (as-symw o k) (xa-symoff (show <>o) @ so (fix k (k = 2 ? 'abs16 'abs32) <so >so))   ; ..a 16-bit operand's two bytes
   (as-syms o) (xa-symoff (show <>o) @ so (fix 4 'abs32s <so >so))      ; ..a dword the cpu sign-extends (64-bit mode)
   (as-gp? o) (<o = 'rg && as-regw o < 16)
   (as-xw d s w) (? (w = 8) 1 (as-gp? d && as-regw d = 8) 1 (as-gp? s && as-regw s = 8) 1 0)
   (as-sse-op md pf op wb rn rm)
    (catall [(as-asz md rm) pf (as-rexm md 0 wb (as-hi rn) (as-rm-x rm) (as-rm-b rm)) [15 op] (as-rm md rn rm)])
   (as-sse-op3 md pf esc op rn rm)
    (catall [(as-asz md rm) pf (as-rexm md 0 0 (as-hi rn) (as-rm-x rm) (as-rm-b rm)) [15 esc op] (as-rm md rn rm)])

   ;; VEX, the AVX forms: C5 (R̄ vvvv̄ L pp) when the map is 0F and W, X and B are clear, else
   ;; C4 (R̄ X̄ B̄ map) (W vvvv̄ L pp). vv is the second source, 0 when none (vvvv̄ all ones);
   ;; the map 1 0F, 2 0F 38, 3 0F 3A; the legacy prefix becomes pp
   (as-vpp pf) (charm? <pf ? (<pf @ 102 1 243 2 242 3 0) 0)
   (as-vex md pf mm wb l rn vv op rm)
    (: r (1 - as-hi rn) x (1 - as-rm-x rm) b (1 - as-rm-b rm) lp ((l << 2) | as-vpp pf) v ((15 - vv) & 15)
       (catall [(as-asz md rm)
                (mm = 1 && wb = 0 && x = 1 && b = 1 ? [197 ((r << 7) | ((v << 3) | lp))]
                   [196 ((r << 7) | ((x << 6) | ((b << 5) | mm))) ((wb << 7) | ((v << 3) | lp))])
                [op] (as-rm md rn rm)]))
   ; an SSE row's v-twin takes its second source in vvvv, but these keep two operands
   as-v2 '(movntdqa pshufd pshuflw pshufhw ptest pabsb pabsw pabsd sqrtps sqrtpd rcpps rsqrtps
           movmskps movmskpd pmovmskb ucomiss ucomisd comiss comisd
           pmovsxbw pmovsxbd pmovsxbq pmovsxwd pmovsxwq pmovsxdq pmovzxbw pmovzxbd pmovzxbq pmovzxwd pmovzxwq pmovzxdq)
   ; ..and these have no v-twin among the rows
   as-vno '(sha256rnds2 sha256msg1 sha256msg2 sha1nexte sha1msg1 sha1msg2 sha1rnds4 movsd movss
            movhps movlps movhpd movlpd movlhps movhlps)
   ; a v-twin whose sources trade places: when only r/m wants VEX's B, clang swaps them for C5
   as-vcomm '(paddb paddw paddd paddq pand por pxor pmullw pmuludq pmulhw pmulhuw pmaddwd pcmpeqb pcmpeqw
              pcmpeqd pminub pmaxub pminsw pmaxsw pavgb pavgw paddusb paddusw paddsb paddsw psadbw
              addps addpd mulps mulpd andps andpd orps orpd xorps xorpd)
   ; the shifts by an xmm's count (the imm8 forms are as-ssh's)
   as-vsh {'psrlw 209 'psrld 210 'psrlq 211 'psraw 225 'psrad 226 'psllw 241 'pslld 242 'psllq 243}
   ; the AVX-only rows, all 66: (map opcode shape), the shape 'nds a second source, 'nds8 with an
   ; imm8, 'two none, 'ext8 the xmm in reg and the destination in r/m, 'is4 a fourth register in imm8's top
   as-vrows {'vperm2f128 [3 6 'nds8] 'vperm2i128 [3 70 'nds8] 'vinsertf128 [3 24 'nds8] 'vinserti128 [3 56 'nds8]
             'vpblendd [3 2 'nds8] 'vpinsrb [3 32 'nds8] 'vpinsrd [3 34 'nds8] 'vpclmulqdq [3 68 'nds8]
             'vextractf128 [3 25 'ext8] 'vextracti128 [3 57 'ext8] 'vpextrb [3 20 'ext8] 'vpextrd [3 22 'ext8]
             'vbroadcasti128 [2 90 'two] 'vpbroadcastd [2 88 'two] 'vpbroadcastq [2 89 'two]
             'vpbroadcastb [2 120 'two] 'vpbroadcastw [2 121 'two] 'vpermd [2 54 'nds] 'vpblendvb [3 76 'is4]}

   ;; EVEX, AVX-512's forms: 62 (R̄ X̄ B̄ R̄' 0 0 map) (W vvvv̄ 1 pp) (z L'L b V̄' aaa), here without
   ;; masks, broadcast or the registers past 15. a disp8 counts in units of n bytes, the whole
   ;; vector unless the row says (the 128- and 256-bit lanes of the inserts and extracts)
   (as-evex md pf mm wb ll rn vv op rm n)
    (: r (1 - as-hi rn) x (1 - as-rm-x rm) b (1 - as-rm-b rm) v ((15 - vv) & 15)
       (catall [(as-asz md rm)
                [98 ((r << 7) | ((x << 6) | ((b << 5) | (16 | mm)))) ((wb << 7) | ((v << 3) | (4 | as-vpp pf))) ((ll << 5) | 8)]
                [op] (as-rmn md rn rm (n = 0 ? (16 << ll) n))]))
   ; (prefix map opcode W shape n), the shapes as-vrows' and 'mov (a load, its store at op+16) and
   ; 'shi (a shift by imm8: vvvv the destination, reg the digit, the row's seventh)
   as-xrows {'vpternlogd [[102] 3 37 0 'nds8 0] 'vpternlogq [[102] 3 37 1 'nds8 0]
             'vprord [[102] 1 114 0 'shi 0 0] 'vprorq [[102] 1 114 1 'shi 0 0]
             'vprold [[102] 1 114 0 'shi 0 1] 'vprolq [[102] 1 114 1 'shi 0 1]
             'vpermi2d [[102] 2 118 0 'nds 0] 'vpermi2q [[102] 2 118 1 'nds 0]
             'vpermt2d [[102] 2 126 0 'nds 0] 'vpermt2q [[102] 2 126 1 'nds 0]
             'vpxord [[102] 1 239 0 'nds 0] 'vpxorq [[102] 1 239 1 'nds 0] 'vpandd [[102] 1 219 0 'nds 0]
             'vpandq [[102] 1 219 1 'nds 0] 'vpord [[102] 1 235 0 'nds 0] 'vporq [[102] 1 235 1 'nds 0]
             'vpandnd [[102] 1 223 0 'nds 0] 'vpandnq [[102] 1 223 1 'nds 0]
             'vmovdqu8 [[242] 1 111 0 'mov 0] 'vmovdqu16 [[242] 1 111 1 'mov 0] 'vmovdqu32 [[243] 1 111 0 'mov 0]
             'vmovdqu64 [[243] 1 111 1 'mov 0] 'vmovdqa32 [[102] 1 111 0 'mov 0] 'vmovdqa64 [[102] 1 111 1 'mov 0]
             'vbroadcasti32x4 [[102] 2 90 0 'two 16] 'vbroadcasti64x2 [[102] 2 90 1 'two 16]
             'vbroadcasti32x8 [[102] 2 91 0 'two 32] 'vbroadcasti64x4 [[102] 2 91 1 'two 32]
             'vextracti32x4 [[102] 3 57 0 'ext8 16] 'vextracti64x2 [[102] 3 57 1 'ext8 16]
             'vextracti32x8 [[102] 3 59 0 'ext8 32] 'vextracti64x4 [[102] 3 59 1 'ext8 32]
             'vinserti32x4 [[102] 3 56 0 'nds8 16] 'vinserti64x2 [[102] 3 56 1 'nds8 16]
             'vinserti32x8 [[102] 3 58 0 'nds8 32] 'vinserti64x4 [[102] 3 58 1 'nds8 32]}
   ; a VEX row a zmm operand takes to EVEX, with its W there
   as-xzmm {'vpclmulqdq [[102] 3 68 0 'nds8 0] 'vpaddd [[102] 1 254 0 'nds 0] 'vpaddq [[102] 1 212 1 'nds 0]
            'vpshufb [[102] 2 0 0 'nds 0]}
   (as-evx md mn ops)
    (: nm (show mn) n #ops d (n > 0 ? (ops 0) ()) a (n > 1 ? (ops 1) ()) c (n > 2 ? (ops 2) ())
       ll (? (any (o \ <o = 'rg && <>>o = 64) ops) 2 (any (o \ <o = 'rg && <>>o = 32) ops) 1 0)
       cl (peep as-clmul (name (snip nm 1 #nm)) ())
       r (peep as-xrows mn (? (ll < 2) () (charm? cl) (as-xzmm 'vpclmulqdq) (peep as-xzmm mn ())))
       (? !(two? r) ()
          (: pf (r 0) mm (r 1) op (r 2) wb (r 3) k (r 4) nn (r 5)
             (im? o) (two? o && <o = 'im)
             (ex rn vv rm) (as-evex md pf mm wb ll rn vv op rm nn)
             (ex8 rn vv rm i) (as-imt (ex rn vv rm + [(byte <>i)]) 1 rm)
             (? (charm? cl && n = 3) (ex8 (as-regn d) (as-regn a) c ['im cl])
                (k = 'nds && n = 3) (ex (as-regn d) (as-regn a) c)
                (k = 'nds8 && n = 4 && im? (ops 3)) (ex8 (as-regn d) (as-regn a) c (ops 3))
                (k = 'two && n = 2) (ex (as-regn d) 0 a)
                (k = 'ext8 && n = 3 && im? c) (ex8 (as-regn a) 0 d c)
                (k = 'shi && n = 3 && im? c) (ex8 (r 6) (as-regn d) a c)
                (k = 'mov && n = 2 && as-mem? d) (as-evex md pf mm wb ll (as-regn a) 0 (op + 16) d nn)
                (k = 'mov && n = 2) (ex (as-regn d) 0 a)
                ()))))
   (as-vx md mn ops)
    (: nm (show mn) n #ops
       (? (#nm < 3 || nm 0 != 118) ()
          (: b (name (snip nm 1 #nm)) d (n > 0 ? (ops 0) ()) a (n > 1 ? (ops 1) ()) c (n > 2 ? (ops 2) ())
             l (any (o \ <o = 'rg && <>>o = 32) ops ? 1 0)
             (im? o) (two? o && <o = 'im)
             (ib o) [(byte <>o)]
             (hi? o) (<o = 'rg && as-hi (as-regn o) = 1)
             (vx pf mm op wb rn vv rm) (as-vex md pf mm wb l rn vv op rm)
             (vx8 pf mm op wb rn vv rm k) (as-imt (vx pf mm op wb rn vv rm + ib k) 1 rm)
             ld (peep as-sse b (peep as-sse2 b ())) st (peep as-sst b ()) vr (peep as-vrows mn ())
             cl (peep as-clmul b ()) s38 (peep as-s38 b ()) s3a (peep as-s3a b ()) si (peep as-ssi b ())
             ev (as-evx md mn ops)
             (? (two? ev) ev
                (any (o \ <o = 'rg && <>>o = 64) ops) ()               ; a zmm only EVEX lays
                (elem mn '(vzeroupper vzeroall)) (n = 0 ? [197 (mn = 'vzeroall ? 252 248) 119] ())
                (elem b as-vno) ()
                ; vmovd/vmovq across to a general register or memory, mirroring the legacy rows
                (elem mn '(vmovd vmovq) && n = 2)
                 (: g? (as-gp? d || as-gp? a) wq (mn = 'vmovq && g? ? 1 0)
                    (? (<d = 'rg && as-regw d = 16 && !(mn = 'vmovq && !g?)) (vx [102] 1 110 wq (as-regn d) 0 a)
                       (<a = 'rg && as-regw a = 16 && (g? || mn = 'vmovd)) (vx [102] 1 126 wq (as-regn a) 0 d)
                       (as-mem? d) (vx [102] 1 214 0 (as-regn a) 0 d)
                       (vx [243] 1 126 0 (as-regn d) 0 a)))
                ; the moves: a store row to memory, and for a register pair where only the source wants
                ; B, as clang lays it so C5 holds
                (two? st && two? ld && n = 2)
                 (? (as-mem? d || (<a = 'rg && hi? a && !(hi? d))) (vx <st 1 <>st 0 (as-regn a) 0 d)
                    (vx <ld 1 <>ld 0 (as-regn d) 0 a))
                (two? vr)
                 (vr @ (mm op k)
                    (? (k = 'nds && n = 3) (vx [102] mm op 0 (as-regn d) (as-regn a) c)
                       (k = 'nds8 && n = 4 && im? (ops 3)) (vx8 [102] mm op 0 (as-regn d) (as-regn a) c (ops 3))
                       (k = 'two && n = 2) (vx [102] mm op 0 (as-regn d) 0 a)
                       (k = 'ext8 && n = 3 && im? c) (vx8 [102] mm op 0 (as-regn a) 0 d c)
                       (k = 'is4 && n = 4 && <(ops 3) = 'rg) (vx [102] mm op 0 (as-regn d) (as-regn a) c + [(as-regn (ops 3) << 4)])
                       ()))
                (charm? cl && n = 3) (vx8 [102] 3 68 0 (as-regn d) (as-regn a) c ['im cl])
                ; the shifts: by an immediate the destination rides vvvv and reg holds the digit
                (n = 3 && im? c && two? (peep as-ssh b ()))
                 (as-ssh b @ r (vx8 [102] 1 <r 0 <>r (as-regn d) a c))
                (n = 3 && charm? (peep as-vsh b ())) (vx [102] 1 (as-vsh b) 0 (as-regn d) (as-regn a) c)
                (two? si && n = 3 && im? c && !(elem b '(shufps shufpd))) (vx8 <si 1 <>si 0 (as-regn d) 0 a c)
                (two? si && n = 4 && im? (ops 3)) (vx8 <si 1 <>si 0 (as-regn d) (as-regn a) c (ops 3))
                (two? s3a && n = 4 && im? (ops 3)) (vx8 <s3a 3 <>s3a 0 (as-regn d) (as-regn a) c (ops 3))
                (two? s38 && n = 2 && elem b as-v2) (vx <s38 2 <>s38 0 (as-regn d) 0 a)
                (two? s38 && n = 3) (vx <s38 2 <>s38 0 (as-regn d) (as-regn a) c)
                (two? ld && n = 2 && elem b as-v2) (vx <ld 1 <>ld 0 (as-regn d) 0 a)
                (two? ld && n = 3 && !(starts? (show b) "cvt"))
                 (? (elem b as-vcomm && <c = 'rg && hi? c && !(hi? a)) (vx <ld 1 <>ld 0 (as-regn d) (as-regn c) a)
                    (vx <ld 1 <>ld 0 (as-regn d) (as-regn a) c))
                ()))))
   ;; x87: the nullaries, a memory operand by its mnemonic (opcode digit), the waiting forms (9b
   ;; ahead of their fn twin), %st(i)'s own rows, and the arithmetic over two stack registers
   as-x87n {'fninit '(219 227) 'finit '(155 219 227) 'fwait '(155) 'wait '(155) 'fnclex '(219 226) 'fclex '(155 219 226)
            'fld1 '(217 232) 'fldz '(217 238) 'fldpi '(217 235) 'fldl2e '(217 234) 'fldl2t '(217 233) 'fldlg2 '(217 236)
            'fldln2 '(217 237) 'fchs '(217 224) 'fabs '(217 225) 'ftst '(217 228) 'fxam '(217 229) 'fsqrt '(217 250)
            'frndint '(217 252) 'fscale '(217 253) 'fprem '(217 248) 'fprem1 '(217 245) 'fsin '(217 254) 'fcos '(217 255)
            'fsincos '(217 251) 'fptan '(217 242) 'fpatan '(217 243) 'f2xm1 '(217 240) 'fyl2x '(217 241) 'fyl2xp1 '(217 249)
            'fxtract '(217 244) 'fincstp '(217 247) 'fdecstp '(217 246) 'fnop '(217 208) 'fcompp '(222 217) 'fucompp '(218 233)}
   as-x87m {'flds [217 0] 'fldl [221 0] 'fldt [219 5] 'fsts [217 2] 'fstl [221 2] 'fstps [217 3] 'fstpl [221 3] 'fstpt [219 7]
            'fadds [216 0] 'faddl [220 0] 'fmuls [216 1] 'fmull [220 1] 'fcoms [216 2] 'fcoml [220 2] 'fcomps [216 3] 'fcompl [220 3]
            'fsubs [216 4] 'fsubl [220 4] 'fsubrs [216 5] 'fsubrl [220 5] 'fdivs [216 6] 'fdivl [220 6] 'fdivrs [216 7] 'fdivrl [220 7]
            'filds [223 0] 'fildl [219 0] 'fildll [223 5] 'fildq [223 5] 'fists [223 2] 'fistl [219 2]
            'fistps [223 3] 'fistpl [219 3] 'fistpll [223 7] 'fistpq [223 7]
            'fisttps [223 1] 'fisttpl [219 1] 'fisttpll [221 1] 'fisttpq [221 1]
            'fiadds [222 0] 'fiaddl [218 0] 'fimuls [222 1] 'fimull [218 1] 'fisubs [222 4] 'fisubl [218 4] 'fidivs [222 6] 'fidivl [218 6]
            'fldcw [217 5] 'fnstcw [217 7] 'fnstsw [221 7] 'fldenv [217 4] 'fnstenv [217 6] 'frstor [221 4] 'fnsave [221 6]
            'fbld [223 4] 'fbstp [223 6]}
   as-x87w {'fstcw 'fnstcw 'fstsw 'fnstsw 'fstenv 'fnstenv 'fsave 'fnsave}
   ; %st(i) alone, or beside %st; none is gas's %st(1)
   as-x87r {'fld [217 192] 'fst [221 208] 'fstp [221 216] 'fxch [217 200] 'ffree [221 192]
            'fucom [221 224] 'fucomp [221 232] 'fcom [216 208] 'fcomp [216 216]
            'fcomi [219 240] 'fcomip [223 240] 'fucomi [219 232] 'fucomip [223 232]
            'faddp [222 192] 'fmulp [222 200] 'fsubp [222 224] 'fsubrp [222 232] 'fdivp [222 240] 'fdivrp [222 248]}
   ; %st(i),%st onto d8, %st,%st(i) onto dc at the same row: AT&T's sub and div name the
   ; reversed op there (and in the p forms), as llvm-mc lays them
   as-x87a {'fadd 192 'fmul 200 'fsub 224 'fsubr 232 'fdiv 240 'fdivr 248}
   (as-more md mn w ops)
    (: nm (show mn) n #ops d (n > 0 ? (ops 0) ()) s (n > 1 ? (ops 1) ())
       sr (peep as-sse mn (peep as-sse2 mn ())) ss (peep as-sst mn ())
       x7 (peep as-x87w mn mn)
       (? (n = 0 && two? (peep as-x87n mn ())) (as-x87n mn)
          (n = 1 && as-mem? d && two? (peep as-x87m x7 ()))
           ((x7 = mn ? () [155]) + (as-x87m x7 @ r (as-emit md 0 0 [<r] <>r d)))
          (n = 1 && elem mn '(fnstsw fstsw) && <d = 'rg && as-regn d = 0) ((mn = 'fstsw ? [155] ()) + [223 224])
          (n <= 2 && two? (peep as-x87r mn ()) && all (o \ <o = 'st) ops)
           (: i (? (n = 0) 1 (n = 1) <>d (<>d != 0) <>d <>s) (as-x87r mn @ r [<r (<>r + i)]))
          (n = 2 && charm? (peep as-x87a mn ()) && <d = 'st && <s = 'st)
           (as-x87a mn @ r (<>d = 0 ? [216 (r + <>s)] [220 (r + <>d)]))
          ; the xmm moves across to a general register, and xmm<->m64
          (elem mn '(movq movd))
           (: g? (as-gp? d || as-gp? s) wq (mn = 'movq ? 1 0)
              (? (g? && <d = 'rg && as-regw d = 16) (as-sse-op md [102] 110 wq (as-regn d) s)   ; 66 0F 6E
                 g? (as-sse-op md [102] 126 wq (as-regn s) d)                                 ; 66 0F 7E
                 (as-mem? d) (as-sse-op md [102] 214 0 (as-regn s) d)                         ; 66 0F D6
                 (mn = 'movq) (as-sse-op md [243] 126 0 (as-regn d) s)                        ; F3 0F 7E
                 (as-sse-op md [102] 110 0 (as-regn d) s)))
          (two? ss && n = 2 && as-mem? d) (as-sse-op md <ss <>ss 0 (as-regn s) d)
          (two? sr && n = 2) (as-sse-op md <sr <>sr (as-xw d s w) (as-regn d) s)
          (two? (peep as-s38 mn ()) && (n = 2 || (n = 3 && elem mn '(sha256rnds2 pblendvb blendvps blendvpd)
                                                   && <(ops 2) = 'rg && as-regw (ops 2) = 16 && as-regn (ops 2) = 0)))
           (as-s38 mn @ r (as-sse-op3 md <r 56 <>r (as-regn d) s))
          (n = 3 && two? (peep as-s3a mn ()) && <(ops 2) = 'im)
           (as-s3a mn @ r (as-imt (as-sse-op3 md <r 58 <>r (as-regn d) s + [(byte <>(ops 2))]) 1 s))
          (n = 2 && charm? (peep as-clmul mn ()))
           (as-imt (as-sse-op3 md [102] 58 68 (as-regn d) s + [(as-clmul mn)]) 1 s)
          ; pextrd: the xmm in reg, the destination in r/m
          (n = 3 && elem mn '(pextrb pextrd) && <(ops 2) = 'im && <s = 'rg)
           (as-imt (as-sse-op3 md [102] 58 (mn = 'pextrb ? 20 22) (as-regn s) d + [(byte <>(ops 2))]) 1 d)
          ; a symbol's address as the immediate
          (n = 2 && <s = 'ims)
           (: fx (md = 64 && w = 8 ? (as-syms s) (as-symw s (w = 2 ? 2 4))) frc (as-frc d)
              (? (mn = 'mov && <d = 'rg && w <= 4) (catall [(as-osz md w) (as-rexm md frc 0 0 0 (as-hi (as-regn d))) [(184 | as-lo (as-regn d)) fx]])
                 (mn = 'mov) (as-emit md w frc '(199) 0 d + [fx] @ bs (<d = 'rip ? (as-riptail bs 4) bs))
                 (two? (as-alu mn)) (as-emit md w frc '(129) <>(as-alu mn) d + [fx] @ bs (<d = 'rip ? (as-riptail bs 4) bs))
                 ()))
          ; push $sym: the segment's width unless a suffix says (pushw in a 32-bit one, pushl in a 16-bit)
          (n = 1 && mn = 'push && <d = 'ims)
           (: pw (? (w > 0) w (md = 16) 2 4) (as-osz md pw + [104 (md = 64 ? (as-syms d) (as-symw d (pw = 2 ? 2 4)))]))
          (n = 1 && elem mn '(prefetchnta prefetcht0 prefetcht1 prefetcht2) && as-mem? d)   ; 0F 18 /0../3
           (as-emit md 0 0 '(15 24) (mn @ 'prefetchnta 0 'prefetcht0 1 'prefetcht1 2 3) d)
          ; the extends, exactly: w is the destination's, so movsbl sign-fills 32 and zeroes the rest
          (n = 2 && elem mn '(movzb movzw movsb movsw movsl))
           (as-emit md w (as-frcs ops) (mn @ 'movzb '(15 182) 'movzw '(15 183) 'movsb '(15 190) 'movsw '(15 191) '(99))
                    (as-regn d) s)
          ; the imm8 SSE forms: at&T `$k, src, dst` arrives [dst src k]; a shift names one register
          (n = 3 && two? (peep as-ssi mn ()) && <(ops 2) = 'im)
           (as-ssi mn @ r (as-imt (as-sse-op md <r <>r 0 (as-regn d) s + [(byte <>(ops 2))]) 1 s))
          (n = 2 && two? (peep as-ssh mn ()) && <s = 'im)
           (as-ssh mn @ r (as-sse-op md [102] <r 0 <>r d + [(byte <>s)]))
          ; the shifts and rotates: by one, by an immediate, by %cl
          (charm? (peep as-shf mn ()))
           (: k (as-shf mn) frc (as-frc d) o8 (w = 1 ? 0 1)
              (? (n = 1 || (n = 2 && <s = 'im && <>s = 1)) (as-emit md w frc [(208 + o8)] k d)
                 (n = 2 && <s = 'im) (as-imt (as-emit md w frc [(192 + o8)] k d + [(byte <>s)]) 1 d)
                 (n = 2 && <s = 'rg && as-regn s = 1) (as-emit md w frc [(210 + o8)] k d)
                 ()))
          ; crc32 by its source's suffix: F2 0F 38 F0 a byte, F1 the rest; the destination's REX.W
          (n = 2 && elem mn '(crc32 crc32b crc32w crc32l crc32q) && <d = 'rg && (mn != 'crc32 || as-gp? s))
           (: sw (mn = 'crc32 ? (as-regw s) (xa-sfxw (nm 5))) ew (? (sw = 1) (as-regw d = 8 ? 8 4) (sw = 2) 4 sw)   ; gas lays 66 ahead of F2
              ((sw = 2 ? [102 242] [242]) + as-emit md ew (as-frcs ops) [15 56 (sw = 1 ? 240 241)] (as-regn d) s))
          ; BMI's VEX-encoded general-register ops, W the destination's width
          (n = 3 && mn = 'rorx && <(ops 2) = 'im && as-gp? d)
           (as-imt (as-vex md [242] 3 (as-regw d = 8 ? 1 0) 0 (as-regn d) 0 240 s + [(byte <>(ops 2))]) 1 s)
          (n = 3 && mn = 'andn && as-gp? d) (as-vex md () 2 (as-regw d = 8 ? 1 0) 0 (as-regn d) (as-regn s) 242 (ops 2))
          (n = 3 && elem mn '(shlx sarx shrx) && as-gp? d && as-gp? (ops 2))
           (as-vex md (mn @ 'shlx [102] 'sarx [243] [242]) 2 (as-regw d = 8 ? 1 0) 0 (as-regn d) (as-regn (ops 2)) 247 s)
          (n = 1 && mn = 'rdpid && <d = 'rg) ([243] + as-emit md 4 0 '(15 199) 7 d)          ; F3 0F C7 /7
          (n = 2 && mn = 'ud1 && <d = 'rg) (as-emit md w (as-frcs ops) '(15 185) (as-regn d) s)   ; 0F B9 /r
          (n = 1 && mn = 'bswap && <d = 'rg)
           (as-regn d @ r (catall [(as-rexm md 0 (as-rexw w) 0 0 (as-hi r)) [15 (200 + as-lo r)]]))
          (n = 3 && elem mn '(shld shrd))
           (: c (ops 2) b (mn = 'shld ? 164 172)
              (<c = 'im ? (as-imt (as-emit md w (as-frcs ops) [15 b] (as-regn s) d + [(byte <>c)]) 1 d)
                 (as-emit md w (as-frcs ops) [15 (b + 1)] (as-regn s) d)))
          (n = 2 && starts? nm "cmov" && 0 < as-ccl nm 4) (as-emit md w (as-frcs ops) [15 (as-ccl nm 4 - 64)] (as-regn d) s)
          (n = 1 && starts? nm "set" && 0 < as-ccl nm 3) (as-emit md 1 (as-frc d) [15 (as-ccl nm 3 + 16)] 0 d)
          (n = 1 && elem mn '(mul imul div idiv))
           (as-emit md w (as-frc d) [(as-opw 247 w)] (mn @ 'mul 4 'imul 5 'div 6 7) d)
          (n = 2 && mn = 'imul && <d = 'rg) (as-emit md w (as-frcs ops) [15 175] (as-regn d) s)
          (n = 3 && mn = 'imul && <(ops 2) = 'im)
           (: k <>(ops 2) n (? (fits8 k) 1 (w = 2) 2 4)
              (as-imt (as-emit md w (as-frcs ops) [(fits8 k ? 107 105)] (as-regn d) s + (fits8 k ? [(byte k)] (as-imw (w = 8 ? 4 w) k))) n s))
          ; xchg with the accumulator: 90+r, as gas lays it (not eax with itself: 90 is nop, and
          ; the 32-bit exchange must zero the upper half)
          (n = 2 && mn = 'xchg && 1 < w && <d = 'rg && <s = 'rg && (as-regn d = 0 || as-regn s = 0)
           && !(as-regn d = 0 && as-regn s = 0))
           (: o (as-regn d = 0 ? s d) k (as-regn o)
              (catall [(as-osz md w) (as-rexm md 0 (as-rexw w) 0 0 (as-hi k)) [(144 + as-lo k)]]))
          (n = 2 && mn = 'xchg && (<d = 'rg || <s = 'rg))
           (: r (<s = 'rg ? s d) o (<s = 'rg ? d s) (as-emit md w (as-frcs ops) [(as-opw 135 w)] (as-regn r) o))
          ()))

   ;; an instruction of the value: (op mn w ops), ops destination first; the encoders above
   ;; take AT&T's order. movabs is mov by range; a high-byte register (16 up) lays as 4..7
   (as-instr it) (as-instrm 64 it)
   ;; ah..bh share their slots with spl..dil, which a REX selects: one beside a REX is refused,
   ;; as gas refuses it, where laying it would name the other register
   (as-hb? o) (two? o && <o = 'rg && <>>o = 1 && <>o >= 16)
   (as-rexed? bs) (: (go l) (? (atom? l) 0 !(charm? <l) 0
                                (elem <l [38 46 54 62 100 101 102 103 240 242 243]) (go >l)
                                (64 <= <l <= 79))
                     (go bs))
   ;; the system lane's rows a 64-bit segment shares: the bit tests, the tables, a far transfer through memory
   (as-sys64? mn) (elem mn '(bt bts btr btc lgdt lidt sgdt sidt ljmp ljmpl lcall lcalll mov))
   (as-instrm md it)
    (as-instrm1 md it @ bs
       (? (md = 64 && any as-hb? (it 3) && as-rexed? bs) (scare 'as-highbyte-rex (it 1)) bs))
   (as-instrm1 md it)
    (: mn (it 1 = 'movabs ? 'mov (it 1)) w (it 2) ops0 (it 3)
     ; a %fs:/%gs: operand: the override byte ahead of the same instruction over the bare operand
     sg (foldl (\ a o (? (two? a) a (two? o && <o = 'seg) o ())) () ops0)
     ; outside 64 a bare symbol a non-branch reads is memory at that address (no %rip)
     br? (xa-branch? mn || xa-cc? mn || elem mn '(calll callw jmpl jmpw) || charm? (peep as-loops mn ()))
     ops (md = 64 ? ops0 (map (o \ (<o = 'lbl && !br? ? ['mem -1 -1 1 0 <>o] o)) ops0))
     (? (two? sg) ([(<>sg @ 'fs 100 'gs 101 'es 38 'cs 46 'ss 54 62)]
                   + as-instrm1 md ['op (it 1) w (map (o \ (two? o && <o = 'seg) ? <>>o o) ops0)])
        ((md < 64 || as-sys64? mn) && two? (as-sys md mn w ops)) (as-sys md mn w ops)
        (as-vx md mn ops @ v
           (two? v ? v
              (as-more md mn w ops @ x
                 (two? x ? x
                    (#ops @ 0 (as-0 md mn)
                         1 (as-1 md mn w <ops)
                         2 (as-2 md mn w <>ops <ops)
                         n (scare 'as-arity [mn n]))))))))
   ;; the system lane of a 16- or 32-bit segment: the segment and control registers, the far
   ;; transfers, the descriptor tables, the ports, int. ops destination first; () when not one
   (as-sys md mn w ops)
    (: n #ops d (n > 0 ? (ops 0) ()) s (n > 1 ? (ops 1) ())
       t (show mn) sfx (t (#t - 1)) sw (sfx @ 119 2 108 4 0)        ; a w or l suffix
       stem (0 < sw ? (name (snip t 0 (#t - 1))) mn)
       dw (md = 16 ? 2 4)                                            ; the segment's own width
       fw (0 < sw ? sw dw)                                           ; a far pointer's offset width
       (imm o k) (? (<o = 'im) (k = 2 ? (le16 <>o) (le32 <>o))
                    (<o = 'ims) (xa-symoff (show <>o) @ so [(fix k (k = 2 ? 'abs16 'abs32) <so >so)])
                    (scare 'as-sys-operand o))
       (? ; mov to/from a segment register: 8E /r and 8C /r (a register destination takes its width)
          (mn = 'mov && n = 2 && <d = 'sr) (as-emit md 0 0 '(142) <>d s)
          (mn = 'mov && n = 2 && <s = 'sr) (as-emit md (<d = 'rg ? (as-regw d) 0) 0 '(140) <>s d)
          ; ..and a control or debug register: 0F 22/20, 0F 23/21, always the full register
          ; (in a 64-bit segment REX reaches cr8 and r8..r15)
          (mn = 'mov && n = 2 && elem <d '(cr dr))
           (catall [(as-rexm md 0 0 (as-hi <>d) 0 (as-hi (as-regn s))) [15 (<d = 'cr ? 34 35) (as-mrm 3 (as-lo <>d) (as-lo (as-regn s)))]])
          (mn = 'mov && n = 2 && elem <s '(cr dr))
           (catall [(as-rexm md 0 0 (as-hi <>s) 0 (as-hi (as-regn d))) [15 (<s = 'cr ? 32 33) (as-mrm 3 (as-lo <>s) (as-lo (as-regn d)))]])
          ; a segment register pushed or popped
          (elem mn '(push pop) && n = 1 && <d = 'sr)
           (: k <>d wd (w > 0 ? w dw)
              (as-osz md wd + (mn @ 'push (k @ 0 [6] 1 [14] 2 [22] 3 [30] 4 [15 160] 5 [15 168] ())
                                    (k @ 0 [7] 2 [23] 3 [31] 4 [15 161] 5 [15 169] (scare 'as-popcs d)))))
          ; a far jump or call to an immediate segment:offset (at&T `$seg, $off` arrives [off seg])
          (elem stem '(ljmp lcall) && n = 2 && <s = 'im && md < 64)
           (as-osz md fw + [(stem = 'ljmp ? 234 154)] + imm d fw + le16 <>s)
          ; ..and through a pointer in memory: FF /5, FF /3
          (elem stem '(ljmp lcall) && n = 1 && <d = 'ind)
           (as-emit md fw 0 '(255) (stem = 'ljmp ? 5 3) <>d)
          ; the descriptor tables: 0F 01 /0../3, the l or w a 16-bit segment's 66 asks for
          (elem stem '(sgdt sidt lgdt lidt) && n = 1)
           (as-emit md sw 0 '(15 1) (stem @ 'sgdt 0 'sidt 1 'lgdt 2 3) d)
          (elem mn '(lldt ltr sldt str verr verw) && n = 1)
           (as-emit md 0 0 '(15 0) (mn @ 'sldt 0 'str 1 'lldt 2 'ltr 3 'verr 4 5) d)
          (elem mn '(lmsw smsw) && n = 1) (as-emit md 0 0 '(15 1) (mn = 'lmsw ? 6 4) d)
          (mn = 'invlpg && n = 1) (as-emit md 0 0 '(15 1) 7 d)
          ; the ports: by an imm8 or by %dx, at the accumulator's width
          (elem mn '(inb inw inl) && n = 2)
           (: wd (as-regw d) (as-osz md wd + (<s = 'im ? [(wd = 1 ? 228 229) (byte <>s)] [(wd = 1 ? 236 237)])))
          (elem mn '(outb outw outl) && n = 2)
           (: wd (as-regw s) (as-osz md wd + (<d = 'im ? [(wd = 1 ? 230 231) (byte <>d)] [(wd = 1 ? 238 239)])))
          (mn = 'int && n = 1 && <d = 'im) [205 (byte <>d)]
          ; the bit tests, over a register or an imm8
          (elem mn '(bt bts btr btc) && n = 2)
           (: k (mn @ 'bt 0 'bts 1 'btr 2 3)
              (<s = 'im ? (as-imt (as-emit md w 0 '(15 186) (4 + k) d + [(byte <>s)]) 1 d)
                 (as-emit md w 0 [15 (163 + 8 * k)] (as-regn s) d)))
          ()))

   ;; pass one: encode each item, assign addresses, record labels and .globl -> {'items 'labels
   ;; 'globls}. the listed directives are ignored: one .text section
   as-dirs '(".text" ".data" ".section" ".p2align" ".align" ".type" ".size" ".file" ".ident")
   (as-lay its)
      (: labels {}  globls {}  st {}
         (go its addr items)
            (!(two? its) ? (pins st 'items (rev items) 'labels labels 'globls globls)
               (<its @ it
                  (<it @ 'label (pin labels <>it addr, go >its addr items)
                        'globl (pin globls <>it 1, go >its addr items)
                        'dir (elem <>it as-dirs ? (go >its addr items)
                                (scare 'as-directive <>it))
                        (revonto (as-instr it) items 0 @ r
                           (go >its (addr + <r) >r)))))
         (go its 0 ()))

   ;; resolve the fixups against the labels. as-text reads AT&T; as-textv takes the value
   (as-textv its) (as-lay its @ st
                     (resolve (st 'items) (peep st 'labels 0) (backends 'x64) 0))
   (as-text src) (as-textv (att-read src))
   (as-hexv its) (hexs (as-textv its))
   (as-hex src)  (hexs (as-text src)))
) ; module 'holo
