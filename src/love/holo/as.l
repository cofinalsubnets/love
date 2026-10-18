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
   ;; the segment's. dialect.l marks a 16-bit address register +32 (bx bp si di: 35 37 38 39)
   (as-osz md w) (? (md = 16) (w @ 4 '(102) ()) (w @ 2 '(102) ()))
   (as-rexm md f w r x b) (? (md = 64) (as-rex f w r x b)
                             (f > 0 || w > 0 || r > 0 || x > 0 || b > 0) (scare 'as-rex-mode [md f w r x b])
                             ())
   (as-a16? o) (<o = 'mem && (o 1 >= 32 || o 2 >= 32))
   (as-abs? o) (<o = 'mem && o 1 < 0 && o 2 < 0)
   (as-asz md o) (? (md = 64 || !(<o = 'mem)) ()
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
   (as-mem-rm md rf o)
      (: b (o 1) ix (o 2) sc (o 3) d (o 4)
         sy (5 < #o ? (o 5) ())                            ; a symbol displacement: abs32, always four bytes
         d4 (sy ? [(fix 4 'abs32 sy d)] (le32 d))
         _ (md = 64 && (b >= 32 || ix >= 32) && scare 'as-mem16-mode o)
         (? (as-a16? o) (as-mem16 rf o)
            (md = 16 && b < 0 && ix < 0)                    ; an absolute address in a 16-bit segment: disp16
             ([(as-mrm 0 rf 6)] + (sy ? [(fix 2 'abs16 sy d)] (le16 d)))
            (md = 32 && b < 0 && ix < 0) ([(as-mrm 0 rf 5)] + d4)   ; ..and in a 32-bit one, no SIB
            (as-mem32 rf o b ix sc d sy d4)))
   (as-mem32 rf o b ix sc d sy d4)
         (b < 0 ? ([(as-mrm 0 rf 4) (as-sib (as-scb sc) (ix < 0 ? 4 ix) 5)] + d4)
            (: md (? sy 2 (d = 0 && !(as-lo b = 5)) 0 (fits8 d) 1 2)
               dsp (md @ 0 () 1 [(byte d)] d4)
               hd (? (ix >= 0)      [(as-mrm md rf 4) (as-sib (as-scb sc) ix b)]
                     (as-lo b = 4)  [(as-mrm md rf 4) (as-sib 0 4 b)]
                     [(as-mrm md rf (as-lo b))])
               (hd + dsp)))
   (as-rm md rf o) (<o @ 'mem (as-mem-rm md rf o)
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
   ;; for anything else. width 2 takes a 66 prefix, width 1 the opcode one below the wide one
   ;; (89/88, 01/00, c7/c6, f7/f6, ff/fe all sit in that relation). ---
   (as-osz md w)  (w @ 2 '(102))
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
               (? (elem mn '(call calll callw)) (as-emit md (mn @ 'callw 2 'calll 4 0) 0 '(255) 2 o)
                  (elem mn '(jmp jmpl jmpw)) (as-emit md (mn @ 'jmpw 2 'jmpl 4 0) 0 '(255) 4 o)
                  (scare 'as-op1 mn)))
            (elem mn '(call jmp calll jmpl callw jmpw))
            (a 1 @ sym ((mn @ 'callw (as-osz md 2) 'calll (as-osz md 4) 'jmpw (as-osz md 2) 'jmpl (as-osz md 4) ())
                        + (elem mn '(call calll callw) ? [232 (rel sym)] [233 (rel sym)])))
            (as-cc mn) (a 1 @ sym [15 (peep as-cc mn 0) (rel sym)])
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
            'sysret '(15 7) 'sysretl '(15 7) 'sysretq '(72 15 7)}
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
          (elem mn '(cdqe cqo syscall sysret sysretq pushfq popfq)) (scare 'as-op0-mode [mn md])
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
   as-s38 {'pshufb [[102] 0] 'sha256rnds2 [() 203] 'sha256msg1 [() 204] 'sha256msg2 [() 205]}
   as-s3a {'palignr [[102] 15] 'pblendw [[102] 14]}
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
   (as-more md mn w ops)
    (: nm (show mn) n #ops d (n > 0 ? (ops 0) ()) s (n > 1 ? (ops 1) ())
       sr (peep as-sse mn (peep as-sse2 mn ())) ss (peep as-sst mn ())
       (? ; the xmm moves across to a general register, and xmm<->m64
          (elem mn '(movq movd))
           (: g? (as-gp? d || as-gp? s) wq (mn = 'movq ? 1 0)
              (? (g? && <d = 'rg && as-regw d = 16) (as-sse-op md [102] 110 wq (as-regn d) s)   ; 66 0F 6E
                 g? (as-sse-op md [102] 126 wq (as-regn s) d)                                 ; 66 0F 7E
                 (as-mem? d) (as-sse-op md [102] 214 0 (as-regn s) d)                         ; 66 0F D6
                 (mn = 'movq) (as-sse-op md [243] 126 0 (as-regn d) s)                        ; F3 0F 7E
                 (as-sse-op md [102] 110 0 (as-regn d) s)))
          (two? ss && n = 2 && as-mem? d) (as-sse-op md <ss <>ss 0 (as-regn s) d)
          (two? sr && n = 2) (as-sse-op md <sr <>sr (as-xw d s w) (as-regn d) s)
          (two? (peep as-s38 mn ()) && (n = 2 || (n = 3 && mn = 'sha256rnds2 && <(ops 2) = 'rg && as-regn (ops 2) = 0)))
           (as-s38 mn @ r (as-sse-op3 md <r 56 <>r (as-regn d) s))
          (n = 3 && two? (peep as-s3a mn ()) && <(ops 2) = 'im)
           (as-s3a mn @ r (as-imt (as-sse-op3 md <r 58 <>r (as-regn d) s + [(byte <>(ops 2))]) 1 s))
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
   (as-instrm md it)
    (as-instrm1 md it @ bs
       (? (md = 64 && any as-hb? (it 3) && as-rexed? bs) (scare 'as-highbyte-rex (it 1)) bs))
   (as-instrm1 md it)
    (: mn (it 1 = 'movabs ? 'mov (it 1)) w (it 2) ops0 (it 3)
     ; a %fs:/%gs: operand: the override byte ahead of the same instruction over the bare operand
     sg (foldl (\ a o (? (two? a) a (two? o && <o = 'seg) o ())) () ops0)
     ; outside 64 a bare symbol a non-branch reads is memory at that address (no %rip)
     br? (xa-branch? mn || xa-cc? mn || elem mn '(calll callw jmpl jmpw))
     ops (md = 64 ? ops0 (map (o \ (<o = 'lbl && !br? ? ['mem -1 -1 1 0 <>o] o)) ops0))
     (? (two? sg) ([(<>sg @ 'fs 100 'gs 101 'es 38 'cs 46 'ss 54 62)]
                   + as-instrm1 md ['op (it 1) w (map (o \ (two? o && <o = 'seg) ? <>>o o) ops0)])
        (md < 64 && two? (as-sys md mn w ops)) (as-sys md mn w ops)
        (as-more md mn w ops @ x
           (two? x ? x
              (#ops @ 0 (as-0 md mn)
                   1 (as-1 md mn w <ops)
                   2 (as-2 md mn w <>ops <ops)
                   n (scare 'as-arity [mn n]))))))
   ;; the system lane of a 16- or 32-bit segment: the segment and control registers, the far
   ;; transfers, the descriptor tables, the ports, int. ops destination first; () when not one
   (as-sys md mn w ops)
    (: n #ops d (n > 0 ? (ops 0) ()) s (n > 1 ? (ops 1) ())
       t (show mn) sfx (t (#t - 1)) sw (sfx @ 119 2 108 4 0)        ; a w or l suffix
       stem (0 < sw ? (name (snip t 0 (#t - 1))) mn)
       dw (md = 16 ? 2 4)                                            ; the segment's own width
       fw (0 < sw ? sw dw)                                           ; a far pointer's offset width
       (imm o k) (? (<o = 'im) (k = 2 ? le16 <>o le32 <>o)
                    (<o = 'ims) (xa-symoff (show <>o) @ so [(fix k (k = 2 ? 'abs16 'abs32) <so >so)])
                    (scare 'as-sys-operand o))
       (? ; mov to/from a segment register: 8E /r and 8C /r (a register destination takes its width)
          (mn = 'mov && n = 2 && <d = 'sr) (as-emit md 0 0 '(142) <>d s)
          (mn = 'mov && n = 2 && <s = 'sr) (as-emit md (<d = 'rg ? (as-regw d) 0) 0 '(140) <>s d)
          ; ..and a control or debug register: 0F 22/20, 0F 23/21, always the full register
          (mn = 'mov && n = 2 && elem <d '(cr dr)) [15 (<d = 'cr ? 34 35) (as-mrm 3 <>d (as-regn s))]
          (mn = 'mov && n = 2 && elem <s '(cr dr)) [15 (<s = 'cr ? 32 33) (as-mrm 3 <>s (as-regn d))]
          ; a segment register pushed or popped
          (elem mn '(push pop) && n = 1 && <d = 'sr)
           (: k <>d wd (w > 0 ? w dw)
              (as-osz md wd + (mn @ 'push (k @ 0 [6] 1 [14] 2 [22] 3 [30] 4 [15 160] 5 [15 168] ())
                                    (k @ 0 [7] 2 [23] 3 [31] 4 [15 161] 5 [15 169] (scare 'as-popcs d)))))
          ; a far jump or call to an immediate segment:offset (at&T `$seg, $off` arrives [off seg])
          (elem stem '(ljmp lcall) && n = 2 && <s = 'im)
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
              (<s = 'im ? (as-emit md w 0 '(15 186) (4 + k) d + [(byte <>s)])
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
