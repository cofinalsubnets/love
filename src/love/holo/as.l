; as -- a real assembler front over holo: it reads standard GNU x86-64 assembly, in either
; dialect, and emits the same byte/fixup item stream the neutral backend (src/love/holo/x64.l)
; produces, so src/love/holo/obj.l lays the relocatable `.o` and src/love/holo/link.l links it --
; the front tooth of the gcc-free chain, paired with link.l's `ld`. the text is read by
; src/love/holo/dialect.l (att-read / intel-read) into one parsed-instruction value, and this
; file is the physical encoder over that value: where src/love/holo/text.l parses holo's own
; mnemonics over abstract registers, this encodes real x86-64 -- physical registers, the operand
; width, the full operand grammar. the encoders mirror x64.l form-for-form but read the register
; number off the operand and carry the width (x64.l is 64-bit-mode only). scope: the GPR core at
; all four widths -- ALU, mov, unary, push/pop, lea, test over register, immediate and memory
; operands; call/jmp/jcc (NEAR; branch relaxation is M2), and the nullaries. a memory operand is
; the full base+index*scale+disp, rip-relative and indirect included.
;
; load after holo.l + x64.l + dialect.l (bare, dev/test context -- the encoder primitives
; le32/byte/fix/modrm.. are still on the global book; the eventual host path reaches them
; through the `holo` book):
;   out/love -l src/love/holo/holo.l -l src/love/holo/x64.l -l src/love/holo/dialect.l -l src/love/holo/as.l ...

(module 'holo
(: ;; --- encoder primitives (physical, width-aware; x64.l is the form reference). ---
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

   ;; --- the r/m half: a register (mod 3) or a memory operand, which lays a Modrm (+ SIB)
   ;; (+ displacement) and hands up the REX X and B bits. an rbp/r13 base has no disp-less slot
   ;; (mod 0 there means disp32) so force a disp byte; an rsp/r12 base needs a SIB to say so; a
   ;; base-less form is mod 0 + SIB base 5 + a full disp32; rip-relative is mod 0, rm 5, and the
   ;; four bytes are a rel32 fixup -- measured from the end of its own field, and the fixup
   ;; carries no addend, so a symbol with an offset cannot be spelled and is refused. ---
   (as-mem-rm rf o)
      (: b (o 1) ix (o 2) sc (o 3) d (o 4)
         sy (5 < #o ? (o 5) ())                            ; a symbol displacement: abs32, always four bytes
         d4 (sy ? [(fix 4 'abs32 sy d)] (le32 d))
         (b < 0 ? ([(as-mrm 0 rf 4) (as-sib (as-scb sc) (ix < 0 ? 4 ix) 5)] + d4)
            (: md (? sy 2 (d = 0 && !(as-lo b = 5)) 0 (fits8 d) 1 2)
               dsp (md @ 0 () 1 [(byte d)] d4)
               hd (? (ix >= 0)      [(as-mrm md rf 4) (as-sib (as-scb sc) ix b)]
                     (as-lo b = 4)  [(as-mrm md rf 4) (as-sib 0 4 b)]
                     [(as-mrm md rf (as-lo b))])
               (hd + dsp))))
   (as-rm rf o) (<o @ 'mem (as-mem-rm rf o)
                      'rip (nom? <>o ? [(as-mrm 0 rf 5) (fix 4 'rel32 <>o <>>o)] ([(as-mrm 0 rf 5)] + le32 <>>o))   ; `0(%rip)`: a bare displacement
                      'rg  [(as-mrm 3 rf (as-regn o))]
                      (scare 'as-notrm o))
   (as-rm-x o)  (<o @ 'mem (<>>o @ i (i < 0 ? 0 (as-hi i))) 0)
   (as-rm-b o)  (<o @ 'mem (<>o @ b (b < 0 ? 0 (as-hi b)))
                      'rip 0
                      (as-hi (as-regn o)))
   (as-mem? o)  (<o = 'mem || <o = 'rip)

   ;; --- operand size: the value carries it resolved (dialect.l's xa-width), 0 when neither the
   ;; text nor a register said -- fine for the 64-bit-default forms (push/pop/call/jmp), a raise
   ;; for anything else. width 2 takes a 66 prefix, width 1 the opcode one below the wide one
   ;; (89/88, 01/00, c7/c6, f7/f6, ff/fe all sit in that relation). ---
   (as-p16 w)  (w @ 2 '(102))
   (as-rexw w) (w = 8)
   (as-opw opc w) (w @ 1 (opc - 1) opc)
   (as-imw w n)   (w @ 1 [(byte n)] 2 (le16 n) (le32 n))
   ;; the whole reg-with-r/m family in one spelling: size prefix, REX, opcode, Modrm tail. `rn` is
   ;; the reg field -- a register encoding, or an opcode extension digit.
   (as-emit w frc opc rn rm)
      (catall [(as-p16 w) (as-rex frc (as-rexw w) (as-hi rn) (as-rm-x rm) (as-rm-b rm))
                opc (as-rm rn rm)])

   ;; the ALU group: mnemonic -> (rr-opcode  imm-ext). reg field carries the source (AT&T src,dst);
   ;; the reg->r/m direction is the table's opcode and r/m->reg is +2 (mov's 89/8b sit the same way).
   as-alu {'add '(1 0) 'or '(9 1) 'and '(33 4) 'sub '(41 5) 'xor '(49 6) 'cmp '(57 7)}
   ;; the condition codes: jcc mnemonic -> 0F 8x low byte.
   as-cc {'jo 128 'jno 129 'jb 130 'jc 130 'jnae 130 'jae 131 'jnb 131 'jnc 131
          'je 132 'jz 132 'jne 133 'jnz 133 'jbe 134 'jna 134 'ja 135 'jnbe 135
          'js 136 'jns 137 'jp 138 'jpe 138 'jnp 139 'jpo 139
          'jl 140 'jnge 140 'jge 141 'jnl 141 'jle 142 'jng 142 'jg 143 'jnle 143}

   ;; alu $imm,r/m: 80 /ext ib for a byte, else the 83 /ext ib short form where the immediate fits,
   ;; else 81 /ext iz.
   (as-alu-i ext w frc rm imm)
      (? (w = 1)     (as-emit 1 frc '(128) ext rm + [(byte imm)])
         (fits8 imm) (as-emit w frc '(131) ext rm + [(byte imm)])
         (as-emit w frc '(129) ext rm + as-imw w imm))

   ;; mov $imm,%reg: the b0/b8+r short forms by width, movabs where a 64-bit immediate needs it,
   ;; c7 /0 id where it fits signed-32.
   (as-mov-ri d w frc imm)
      (as-rex frc (as-rexw w) 0 0 (as-hi d) @ rx
         (? (w = 1) (catall [rx [(176 | as-lo d) (byte imm)]])
            (w = 2) (catall ['(102) rx [(184 | as-lo d)] (le16 imm)])
            (w = 4) (catall [rx [(184 | as-lo d)] (le32 imm)])
            (fits32 imm) (catall [rx [199 (as-mrm 3 0 d)] (le32 imm)])
            (catall [rx [(184 | as-lo d)] (le64 imm)])))

   ;; --- the per-instruction encoders (each -> a byte/fix item list), in at&T operand order. ---
   ;; a rip-relative operand with an immediate tail: x64-patch measures rel32 from the end of its
   ;; own field, so the fix's aux steps back over the n immediate bytes that follow it
   (as-imt bs n o) (<o = 'rip ? (as-riptail bs n) bs)       ; n immediate bytes after o's field
   (as-riptail bs n) (map (x \ (two? x && <x = 'fix && x 2 = 'rel32 ? (fix (x 1) 'rel32 (x 3) (x 4 - n)) x)) bs)
   (as-2 mn w a b)                                           ; two-operand: at&T src,dst
      (: ka <a kb <b frc (as-frcs [a b])
         alu (as-alu mn)
         rr  (mn @ 'mov 137 'test 133 (alu @ (a . _) a 0))
         opi (mn @ 'mov 199 'test 247 0)          ; the imm-to-r/m opcode, 0 = the ALU's
         (? (mn = 'lea)
            (kb = 'rg && as-mem? a ?
             (as-emit w frc '(141) (as-regn b) a)
             (scare 'as-lea-form [a b]))
            (rr = 0) (scare 'as-op2 mn)
            (w = 0)  (scare 'as-nowidth [mn a b])
            (as-mem? a && as-mem? b) (scare 'as-twomem [a b])
            (ka = 'rg) (as-emit w frc [(as-opw rr w)] (as-regn a) b)                ; reg -> r/m
            (kb = 'rg && as-mem? a)                                              ; r/m -> reg
            (as-emit w frc [(as-opw (mn @ 'test rr (rr + 2)) w)] (as-regn b) a)
            (ka = 'im)                                                             ; $imm -> r/m
            (: im <>a
               bs (? (mn = 'mov && kb = 'rg) (as-mov-ri (as-regn b) w frc im)
                     (opi > 0) (as-emit w frc [(as-opw opi w)] 0 b + as-imw w im)
                     (as-alu-i <>alu w frc b im))
               ; the immediate's width as its encoder laid it: 80/83's byte, else the operand's
               n (? (opi > 0) (w @ 1 1 2 2 4) (w = 1 || fits8 im) 1 (w @ 2 2 4))
               (<b = 'rip ? (as-riptail bs n) bs))
            (scare 'as-op2-form [a b])))
   (as-1 mn w a)                                             ; one-operand
      (: k <a  frc (as-frc a)
         pw (w @ 2 2 0)                                  ; push/pop take 66 but never REX.W
         (? (mn = 'push)                                     ; ff /6
            (k @ 'rg (as-regn a @ n
                        (as-p16 pw + (n >= 8 ? [65 (80 | as-lo n)] [(80 | n)])))
                 (as-emit pw 0 '(255) 6 a))
            (mn = 'pop)                                      ; 8f /0
            (k @ 'rg (as-regn a @ n
                        (as-p16 pw + (n >= 8 ? [65 (88 | as-lo n)] [(88 | n)])))
                 (as-emit pw 0 '(143) 0 a))
            (elem mn '(neg not inc dec))
            (: opc (elem mn '(inc dec) ? 255 247)
               ext (mn @ 'neg 3 'not 2 'inc 0 1)
               (w @ 0 (scare 'as-nowidth [mn a]) (as-emit w frc [(as-opw opc w)] ext a)))
            (k = 'ind)                                       ; call/jmp through a register or memory
            (a 1 @ o
               (mn @ 'call (as-emit 0 0 '(255) 2 o)
                     'jmp  (as-emit 0 0 '(255) 4 o)
                     (scare 'as-op1 mn)))
            (elem mn '(call jmp))
            (a 1 @ sym (mn @ 'call [232 (fix 4 'rel32 sym 0)] [233 (fix 4 'rel32 sym 0)]))
            (as-cc mn) (a 1 @ sym [15 (peep as-cc mn 0) (fix 4 'rel32 sym 0)])
            (scare 'as-op1 mn)))
   ;; --- the nullaries, by their one spelling: the reader folds at&T's c<from>t<to> family
   ;; (cltq, cltd, ..) and retq/leaveq/xlatb onto these. `int3' is what holo's own text calls trap.
   as-nils {'ret '(195) 'nop '(144) 'hlt '(244)
            'syscall '(15 5) 'leave '(201)
            'cbw '(102 152) 'cwde '(152) 'cdqe '(72 152)      ; al -> ax, ax -> eax, eax -> rax
            'cwd '(102 153) 'cdq '(153) 'cqo '(72 153)        ; .. and the dx:ax splits
            'int3 '(204) 'ud2 '(15 11) 'pause '(243 144)
            'cpuid '(15 162) 'rdtsc '(15 49)
            'cli '(250) 'sti '(251)                  ; the interrupt flag
            'pushf '(156) 'pushfq '(156) 'popf '(157) 'popfq '(157)   ; ... and the whole word, through the stack
            'clc '(248) 'stc '(249) 'cmc '(245)   ; ... the carry flag
            'cld '(252) 'std '(253)                  ; ... and the direction flag
            'lahf '(159) 'sahf '(158)
            'xlat '(215)
            'sysret '(15 7) 'sysretl '(15 7) 'sysretq '(72 15 7)}
   (as-0 mn) (as-nils mn @ () (scare 'as-op0 mn) b b)

   ;; --- past the GPR core: what a compiler's own .s asks. SSE by a table of (prefix opcode),
   ;; register <- r/m, and a move's store row where the destination is memory; REX.W only where a
   ;; general register is 64 wide. a symbol as an immediate is an abs32 the link fills (the
   ;; non-PIE images this links); cmov/set key off jcc's table. ops destination first here. ---
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
   as-ssh {'psrlw [113 2] 'psraw [113 4] 'psllw [113 6] 'psrld [114 2] 'psrad [114 4] 'pslld [114 6]
           'psrlq [115 2] 'psllq [115 6] 'psrldq [115 3] 'pslldq [115 7]}
   as-shf {'rol 0 'ror 1 'rcl 2 'rcr 3 'shl 4 'sal 4 'shr 5 'sar 7}
   ; ..more integer lanes, the same shape
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
   (as-sym o) (xa-symoff (show <>o) @ so (fix 4 'abs32 <so >so))       ; `$sym+k` -> its fix
   (as-gp? o) (<o = 'rg && as-regw o < 16)
   (as-xw d s w) (? (w = 8) 1 (as-gp? d && as-regw d = 8) 1 (as-gp? s && as-regw s = 8) 1 0)
   (as-sse-op pf op wb rn rm)
    (catall [pf (as-rex 0 wb (as-hi rn) (as-rm-x rm) (as-rm-b rm)) [15 op] (as-rm rn rm)])
   (as-more mn w ops)
    (: nm (show mn) n #ops d (n > 0 ? (ops 0) ()) s (n > 1 ? (ops 1) ())
       sr (peep as-sse mn (peep as-sse2 mn ())) ss (peep as-sst mn ())
       (? ; the xmm moves across to a general register, and xmm<->m64
          (elem mn '(movq movd))
           (: g? (as-gp? d || as-gp? s) wq (mn = 'movq ? 1 0)
              (? (g? && <d = 'rg && as-regw d = 16) (as-sse-op [102] 110 wq (as-regn d) s)   ; 66 0F 6E
                 g? (as-sse-op [102] 126 wq (as-regn s) d)                                 ; 66 0F 7E
                 (as-mem? d) (as-sse-op [102] 214 0 (as-regn s) d)                         ; 66 0F D6
                 (mn = 'movq) (as-sse-op [243] 126 0 (as-regn d) s)                        ; F3 0F 7E
                 (as-sse-op [102] 110 0 (as-regn d) s)))
          (two? ss && n = 2 && as-mem? d) (as-sse-op <ss <>ss 0 (as-regn s) d)
          (two? sr && n = 2) (as-sse-op <sr <>sr (as-xw d s w) (as-regn d) s)
          ; a symbol's address as the immediate
          (n = 2 && <s = 'ims)
           (: fx (as-sym s) frc (as-frc d)
              (? (mn = 'mov && <d = 'rg && w <= 4) (catall [(as-rex frc 0 0 0 (as-hi (as-regn d))) [(184 | as-lo (as-regn d)) fx]])
                 (mn = 'mov) (as-emit w frc '(199) 0 d + [fx] @ bs (<d = 'rip ? (as-riptail bs 4) bs))
                 (two? (as-alu mn)) (as-emit w frc '(129) <>(as-alu mn) d + [fx] @ bs (<d = 'rip ? (as-riptail bs 4) bs))
                 ()))
          (n = 1 && mn = 'push && <d = 'ims) [104 (as-sym d)]
          (n = 1 && elem mn '(prefetchnta prefetcht0 prefetcht1 prefetcht2) && as-mem? d)   ; 0F 18 /0../3
           (as-emit 0 0 '(15 24) (mn @ 'prefetchnta 0 'prefetcht0 1 'prefetcht1 2 3) d)
          ; the extends, exactly: w is the destination's, so movsbl sign-fills 32 and zeroes the rest
          (n = 2 && elem mn '(movzb movzw movsb movsw movsl))
           (as-emit w (as-frcs ops) (mn @ 'movzb '(15 182) 'movzw '(15 183) 'movsb '(15 190) 'movsw '(15 191) '(99))
                    (as-regn d) s)
          ; the imm8 SSE forms: at&T `$k, src, dst` arrives [dst src k]; a shift names one register
          (n = 3 && two? (peep as-ssi mn ()) && <(ops 2) = 'im)
           (as-ssi mn @ r (as-imt (as-sse-op <r <>r 0 (as-regn d) s + [(byte <>(ops 2))]) 1 s))
          (n = 2 && two? (peep as-ssh mn ()) && <s = 'im)
           (as-ssh mn @ r (as-sse-op [102] <r 0 <>r d + [(byte <>s)]))
          ; the shifts and rotates: by one, by an immediate, by %cl
          (charm? (peep as-shf mn ()))
           (: k (as-shf mn) frc (as-frc d) o8 (w = 1 ? 0 1)
              (? (n = 1 || (n = 2 && <s = 'im && <>s = 1)) (as-emit w frc [(208 + o8)] k d)
                 (n = 2 && <s = 'im) (as-imt (as-emit w frc [(192 + o8)] k d + [(byte <>s)]) 1 d)
                 (n = 2 && <s = 'rg && as-regn s = 1) (as-emit w frc [(210 + o8)] k d)
                 ()))
          (n = 1 && mn = 'bswap && <d = 'rg)
           (as-regn d @ r (catall [(as-rex 0 (as-rexw w) 0 0 (as-hi r)) [15 (200 + as-lo r)]]))
          (n = 3 && elem mn '(shld shrd))
           (: c (ops 2) b (mn = 'shld ? 164 172)
              (<c = 'im ? (as-imt (as-emit w (as-frcs ops) [15 b] (as-regn s) d + [(byte <>c)]) 1 d)
                 (as-emit w (as-frcs ops) [15 (b + 1)] (as-regn s) d)))
          (n = 2 && starts? nm "cmov" && 0 < as-ccl nm 4) (as-emit w (as-frcs ops) [15 (as-ccl nm 4 - 64)] (as-regn d) s)
          (n = 1 && starts? nm "set" && 0 < as-ccl nm 3) (as-emit 1 (as-frc d) [15 (as-ccl nm 3 + 16)] 0 d)
          (n = 1 && elem mn '(mul imul div idiv))
           (as-emit w (as-frc d) [(as-opw 247 w)] (mn @ 'mul 4 'imul 5 'div 6 7) d)
          (n = 2 && mn = 'imul && <d = 'rg) (as-emit w (as-frcs ops) [15 175] (as-regn d) s)
          (n = 3 && mn = 'imul && <(ops 2) = 'im)
           (: k <>(ops 2) n (? (fits8 k) 1 (w = 2) 2 4)
              (as-imt (as-emit w (as-frcs ops) [(fits8 k ? 107 105)] (as-regn d) s + (fits8 k ? [(byte k)] (as-imw (w = 8 ? 4 w) k))) n s))
          ; xchg with the accumulator: 90+r, as gas lays it (not eax with itself: 90 is nop, and
          ; the 32-bit exchange must zero the upper half)
          (n = 2 && mn = 'xchg && 1 < w && <d = 'rg && <s = 'rg && (as-regn d = 0 || as-regn s = 0)
           && !(as-regn d = 0 && as-regn s = 0))
           (: o (as-regn d = 0 ? s d) k (as-regn o)
              (catall [(as-p16 w) (as-rex 0 (as-rexw w) 0 0 (as-hi k)) [(144 + as-lo k)]]))
          (n = 2 && mn = 'xchg && (<d = 'rg || <s = 'rg))
           (: r (<s = 'rg ? s d) o (<s = 'rg ? d s) (as-emit w (as-frcs ops) [(as-opw 135 w)] (as-regn r) o))
          ()))

   ;; an instruction of the value: (op mn w ops), ops destination first; the encoders above
   ;; take at&T's order. movabs is mov by range here; a high-byte register (ah.., slot 16 up)
   ;; has no encoding in this front.
   (as-instr it)
    (: mn (it 1 = 'movabs ? 'mov (it 1)) w (it 2) ops (it 3)
     ; a %fs:/%gs: operand: the override byte ahead of the same instruction over the bare operand
     sg (foldl (\ a o (? (two? a) a (two? o && <o = 'seg) o ())) () ops)
     (two? sg ? ([(<>sg @ 'fs 100 'gs 101 'es 38 'cs 46 'ss 54 62)]
                  + as-instr ['op (it 1) w (map (o \ (two? o && <o = 'seg) ? <>>o o) ops)])
     (as-more mn w ops @ x
        (two? x ? x
           (#ops @ 0 (as-0 mn)
                1 (as-1 mn w <ops)
                2 (as-2 mn w <>ops <ops)
                n (scare 'as-arity [mn n]))))))

   ;; --- pass one: walk the items, encode each, assign addresses, record labels + .globl. returns
   ;;     a tablet { 'items 'labels 'globls }. label defs emit no bytes; directives steer. ---
   as-dirs '(".text" ".data" ".section" ".p2align" ".align" ".type" ".size" ".file" ".ident")
   (as-lay its)
      (: labels {}  globls {}  st {}
         (go its addr items)
            (!(two? its) ? (pins st 'items (rev items) 'labels labels 'globls globls)
               (<its @ it
                  (<it @ 'label (pin labels <>it addr, go >its addr items)
                        'globl (pin globls <>it 1, go >its addr items)
                        'dir (elem <>it as-dirs ? (go >its addr items)   ; M1: single .text section
                                (scare 'as-directive <>it))
                        (revonto (as-instr it) items 0 @ r
                           (go >its (addr + <r) >r)))))
         (go its 0 ()))

   ;; --- resolve intra-section fixups (near rel32) to final .text bytes, and the hex for goldens.
   ;;     as-text reads at&T; as-textv takes the value, so either dialect assembles. ---
   (as-textv its) (as-lay its @ st
                     (resolve (st 'items) (peep st 'labels 0) (backends 'x64) 0))
   (as-text src) (as-textv (att-read src))
   (as-hexv its) (hexs (as-textv its))
   (as-hex src)  (hexs (as-text src)))
) ; module 'holo
