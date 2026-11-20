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
   ;; memory by the table's lay (x64.l's x6e-memm, which gives the 67 as-asz lays here)
   (as-rm md rf o) (<o @ 'mem (x6e-memm md rf o @ () (scare 'as-mem o) m (m 0))
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
   ;; the reg-with-r/m family: size prefixes, REX, opcode, Modrm tail. `rn` is the reg field,
   ;; a register or an opcode extension digit
   (as-emit md w frc opc rn rm)
      (catall [(as-asz md rm) (as-osz md w) (as-rexm md frc (as-rexw w) (as-hi rn) (as-rm-x rm) (as-rm-b rm))
                opc (as-rm md rn rm)])

   ;; jcc -> the low byte of 0F 8x
   as-cc {'jo 128 'jno 129 'jb 130 'jc 130 'jnae 130 'jae 131 'jnb 131 'jnc 131
          'je 132 'jz 132 'jne 133 'jnz 133 'jbe 134 'jna 134 'ja 135 'jnbe 135
          'js 136 'jns 137 'jp 138 'jpe 138 'jnp 139 'jpo 139
          'jl 140 'jnge 140 'jge 141 'jnl 141 'jle 142 'jng 142 'jg 143 'jnle 143}
   ;; the rel8-only branches -> their opcode
   as-loops {'loop 226 'loope 225 'loopz 225 'loopne 224 'loopnz 224 'jecxz 227 'jrcxz 227 'jcxz 227}

   ;; an immediate spelled unsigned in w bytes, as the signed value those bytes hold
   (as-sx w v) (v >= 1 << (8 * w - 1) && v < 1 << 8 * w ? (v - (1 << 8 * w)) v)
   ;; the per-instruction encoders, in AT&T operand order.
   ;; a rip-relative operand with an immediate tail: x64-patch measures rel32 from the end of its
   ;; own field, so the fix's aux steps back over the n immediate bytes that follow it
   (as-imt bs n o) (<o = 'rip ? (as-riptail bs n) bs)
   (as-riptail bs n) (map (x \ (two? x && <x = 'fix && x 2 = 'rel32 ? (fix (x 1) 'rel32 (x 3) (x 4 - n)) x)) bs)
   ;; what the table leaves of one operand: neg not inc dec with no width say so
   (as-1 md mn w a) (? (elem mn '(neg not inc dec) && w = 0) (scare 'as-nowidth [mn a]) (scare 'as-op1 mn))
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
   as-nil32 {'syscall '(15 5) 'rep '(243) 'repe '(243) 'repz '(243) 'repne '(242) 'repnz '(242) 'lock '(240)
             'wbinvd '(15 9) 'invd '(15 8) 'wrmsr '(15 48) 'rdmsr '(15 50) 'clts '(15 6)}
   ;; a string op spelled with its operands: they say only the source's override and the
   ;; address size. () when the line is not one
   (as-stro md mn ops)
    (? (#ops != 2) ()
       (: t (show mn) n #t stem (name (snip t 0 (n - 1)))
          sw (t (n - 1) @ 98 1 119 2 108 4 100 4 113 8 0)
          op (as-strs stem)
          (bare o) (two? o && <o = 'seg ? <>>o o)
          (lane o) (bare o 1 % 32)
          (acc? o) (<o = 'rg && as-regn o = 0 && as-regw o = sw)
          ms (filter (o \ <(bare o) = 'mem) ops)
          (? (sw = 0 || !(charm? op)) ()
             !(#ms = (elem stem '(stos lods scas) ? 1 2) && (#ms = 2 || any acc? ops)) ()
             (: as (filter (o \ lane o != 2 || !(elem stem '(ins outs))) ms)
                src (filter (o \ lane o = 6) as)
                sg (two? src && two? <src && <<src = 'seg ? <><src 'ds)
                (? !(all (o \ elem (lane o) '(6 7)) as) (scare 'as-strop ops)
                   (sw = 8 && (md != 64 || elem stem '(ins outs))) (scare 'as-strop ops)
                   (as-asz md (bare <as)
                    + (sg = 'ds ? () [(sg @ 'fs 100 'gs 101 'es 38 'cs 46 'ss 54 (scare 'as-strop ops))])
                    + (sw = 8 ? [72] (as-osz md sw))
                    + [(sw = 1 ? (op - 1) op)]))))))
   (as-0 md mn) (? (md = 64) (as-nils mn @ () (scare 'as-op0 mn) b b) (as-0n mn md))
   (as-0n mn md)
    (: t (show mn) n #t c (t (n - 1)) stem (name (snip t 0 (n - 1)))
       sw (c @ 98 1 119 2 108 4 100 4 0)              ; b w l d
       (? (two? (as-nil32 mn)) (as-nil32 mn)
          (charm? (as-sized mn)) [(as-sized mn)]
          (1 < sw && charm? (as-sized stem)) (as-osz md sw + [(as-sized stem)])
          (0 < sw && charm? (as-strs stem)) (sw = 1 ? [(as-strs stem - 1)] (as-osz md sw + [(as-strs stem)]))
          (elem mn '(cbw cwde cwd cdq)) (as-osz md (elem mn '(cbw cwd) ? 2 4) + [(elem mn '(cbw cwde) ? 152 153)])
          (elem mn '(cdqe cqo sysret sysretq pushfq popfq lretq)) (scare 'as-op0-mode [mn md])
          (as-nils mn @ () (scare 'as-op0 mn) b b)))

   ; BMI's names, a width suffix past them
   as-bmi '(andn bzhi bextr pdep pext mulx sarx shlx shrx rorx blsr blsmsk blsi)
   ; pclmulqdq's spellings of its immediate, which halves it multiplies
   as-clmul {'pclmullqlqdq 0 'pclmulhqlqdq 1 'pclmullqhqdq 16 'pclmulhqhqdq 17}
   ; a cmov/set condition -> jcc's low byte, past a width suffix if it carries one; none is 0
   (as-ccl nm k) (: c (snip nm k #nm) v (peep as-cc (name ("j" + c)) 0)
                    (0 < v || #c < 2 ? v (peep as-cc (name ("j" + snip c 0 (#c - 1))) 0)))
   (as-symw o k) (xa-symoff (show <>o) @ so (fix k (k = 2 ? 'abs16 'abs32) <so >so))   ; `$sym+k` -> its fix of k bytes
   (as-syms o) (xa-symoff (show <>o) @ so (fix 4 'abs32s <so >so))      ; ..a dword the cpu sign-extends (64-bit mode)
   (as-gp? o) (<o = 'rg && as-regw o < 16)
   ;; x87: a waiting form is 9b ahead of its fn twin; these take st(1), or it beside the top, when
   ;; at&t names fewer
   as-x87w {'fstcw 'fnstcw 'fstsw 'fnstsw 'fstenv 'fnstenv 'fsave 'fnsave 'finit 'fninit 'fclex 'fnclex}
   as-x87d '(fld fst fstp fxch ffree fucom fucomp fcom fcomp fcomi fcomip fucomi fucomip faddp fmulp fsubp fsubrp fdivp fdivrp)
   (as-more md mn w ops)
    (: nm (show mn) n #ops d (n > 0 ? (ops 0) ()) s (n > 1 ? (ops 1) ())
       ; crc32 by its source's suffix: F2 0F 38 F0 a byte, F1 the rest; the destination's REX.W
       (? (n = 2 && elem mn '(crc32 crc32b crc32w crc32l crc32q) && <d = 'rg && (mn != 'crc32 || as-gp? s))
           (: sw (mn = 'crc32 ? (as-regw s) (xa-sfxw (nm 5))) ew (? (sw = 1) (as-regw d = 8 ? 8 4) (sw = 2) 4 sw)   ; gas lays 66 ahead of F2
              ((sw = 2 ? [102 242] [242]) + as-emit md ew (as-frcs ops) [15 56 (sw = 1 ? 240 241)] (as-regn d) s))
          (n = 1 && mn = 'rdpid && <d = 'rg) ([243] + as-emit md 4 0 '(15 199) 7 d)          ; F3 0F C7 /7
          (n = 2 && mn = 'ud1 && <d = 'rg) (as-emit md w (as-frcs ops) '(15 185) (as-regn d) s)   ; 0F B9 /r
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
     ; a bare symbol a non-branch reads is memory at that address (no %rip)
     br? (xa-branch? mn || xa-cc? mn || elem mn '(calll callw jmpl jmpw) || charm? (as-loops mn))
     (nosp s) ((: (g i a) (i >= #s ? a (g (i + 1) (s i = 32 ? a (a + string (s i)))))) 0 "")
     ops (map (o \ (<o = 'lbl && !br? ? (xa-symoff (nosp (show <>o)) @ so ['mem -1 -1 1 >so <so]) o)) ops0)
     (? (two? (as-stro md mn ops0)) (as-stro md mn ops0)
        (two? sg) ([(<>sg @ 'fs 100 'gs 101 'es 38 'cs 46 'ss 54 62)]
                   + as-instrm1 md ['op (it 1) w (map (o \ (two? o && <o = 'seg) ? <>>o o) ops0)])
        (two? (as-tab md mn w ops)) (as-tab md mn w ops)
        (as-more md mn w ops @ x
           (two? x ? x
              (#ops @ 0 (as-0 md mn)
                   1 (as-1 md mn w <ops)
                   2 (scare 'as-op2 [mn ops])
                   n (scare 'as-arity [mn n]))))))
   ;; the table's lay (x64-encm), the value in its terms: a cc alias by its number, an immediate
   ;; signed at the width, $sym a fix of the immediate's field, a rip symbol its rel32. a width
   ;; the text left 0 is the one width that lays, if one does; movd's is its name's. () where the table has no row;
   ;; branches stay the encoders' above. an sse compare's predicate spelled in its name is
   ;; its immediate
   (as-cmpp p) (p @ "eq" 0 "lt" 1 "le" 2 "unord" 3 "neq" 4 "nlt" 5 "nle" 6 "ord" 7 -1)
   ; ..as are pclmulqdq's halves
   (as-cmpn t) (? (charm? (as-clmul (name t))) ['pclmulqdq (as-clmul (name t))]
                  (#t > 1 && t 0 = 118 && charm? (as-clmul (name (snip t 1 #t)))) ['vpclmulqdq (as-clmul (name (snip t 1 #t)))]
                  (#t > 5 && starts? t "cmp") (: k (as-cmpp (snip t 3 (#t - 2))) (k < 0 ? () [(name ("cmp" + snip t (#t - 2) #t)) k])) ())
   (as-tabn mn)
    (: t (show mn)
       (? (mn = 'sal) 'shl
          (starts? t "cmov") (as-ccl t 4 @ v (0 < v ? (x6t-ccn "cmov" (v - 128)) mn))
          (starts? t "set") (as-ccl t 3 @ v (0 < v ? (x6t-ccn "set" (v - 128)) mn))
          (starts? t "j") (as-ccl t 1 @ v (0 < v ? (x6t-ccn "j" (v - 128)) (as-brn mn)))
          (#t > 3 && elem (t (#t - 1)) [108 113] && elem (name (snip t 0 (#t - 1))) as-bmi) (name (snip t 0 (#t - 1)))
          (elem mn '(inb inw inl outb outw outl sgdtl sgdtw sidtl sidtw lgdtl lgdtw lidtl lidtw))
           (name (snip t 0 (#t - 1)))
          (mn @ 'wait 'fwait 'fildq 'fildll 'fistpq 'fistpll 'fisttpq 'fisttpll (as-brn mn))))
   (as-brn mn) (mn @ ('callw || 'calll || 'callq) 'call ('jmpw || 'jmpl || 'jmpq) 'jmp ('ljmpw || 'ljmpl) 'ljmp
                     ('lcallw || 'lcalll) 'lcall 'loopz 'loope 'loopnz 'loopne
                     ('jecxz || 'jcxz) 'jrcxz mn)
   ;; a branch's target: rel8 for loop and jrcxz, else the operand's width, pc-relative
   (as-bro md tn ow o) (? (<o != 'lbl) o
                          (elem tn '(loop loope loopne jrcxz)) ['lbl (fix 1 'pc8 <>o 0)]
                          ['lbl (ow = 2 ? (fix 2 'rel16 <>o 0) (fix 4 (md = 64 ? 'rel32 'pc32) <>o 0))])
   (as-tabo md w o)
    (<o @ 'im (charm? <>o && 0 < w && w < 8 ? ['im (as-sx w <>o)] o)
          'ims ['im (md = 64 && w = 8 ? (as-syms o) (as-symw o (w = 2 ? 2 4)))]
          'rip (nom? <>o ? ['rip () (fix 4 'rel32 <>o <>>o)] ['rip () <>>o])
          'ind ['ind (<(o 1) = 'lbl ? (xa-symoff (show <>(o 1)) @ so ['mem -1 -1 1 >so <so]) (as-tabo md w <>o))]
          o)
   (as-tab md mn w0 ops)
    (: rip? (any (o \ <o = 'rip || <o = 'ind && <(o 1) = 'rip) ops)
       cp (as-cmpn (show mn))
       tn (? (two? cp) <cp (mn = 'int && ops = [['im 3]]) 'int3 (as-tabn mn))
       ; a push's or pop's width unsuffixed, or the reader's 8 outside 64, is the segment's
       pp? (elem tn '(push pop)) dw (? (md = 64) 8 (md = 16) 2 4)
       ; a descriptor table's width is its suffix's; a port's and int3's the row's own
       w (? (pp? && md != 64 && w0 = 8) 0
            (elem tn '(sgdt sidt lgdt lidt) && mn != tn) (show mn @ t (t (#t - 1) = 119 ? 2 4))
            (elem tn '(in out int3)) 0
            w0)
       ; a branch's operand size by its suffix: callw jmpw 2, calll jmpl 4
       ow (mn @ ('callw || 'jmpw || 'ljmpw || 'lcallw) 2 ('calll || 'jmpl || 'ljmpl || 'lcalll) 4 (md = 16 ? 2 4))
       bw (? (md = 64) 0 (ow = dw) 0 ow)
       ; the blends' and sha256rnds2's xmm0 is the row's own
       ops1 (elem tn '(pblendvb blendvps blendvpd sha256rnds2) && #ops = 3 && last ops = ['rg 0 16] ? (snip ops 0 2) ops)
       ; int $3 is int3, as gas and llvm lay it
       os (? (tn = 'int3) () (map (as-bro md tn ow) (two? cp ? (ops1 + [['im (cp 1)]]) ops1)))
       (enc1 w os) (x64-encm md tn w (map (as-tabo md w) os) 0 @ b (rip? ? (riptail b) b))
       (enc w) (enc1 w os)
       wt (peep as-x87w mn ())
       sts (? (#ops = 0) [[['st 1]] [['st 0] ['st 1]] [['st 1] ['st 0]]] [[['st 0] <ops] [<ops ['st 0]]])
       ; jecxz in a 64-bit segment is 67 jrcxz
       (? (nom? wt) (as-tab md wt w0 ops @ b (two? b ? ([155] + b) ()))
          !(two? (peep x64-byname tn ())) ()
          (#ops < 2 && elem tn as-x87d && all (o \ <o = 'st) ops && !(two? (enc 0)))
           (foldl (\ b o (two? b ? b (enc1 0 o))) () sts)
          (tn = 'jrcxz) (enc 0 @ b (two? b && mn = 'jecxz && md = 64 ? ([103] + b) b))
          (elem tn '(call jmp loop loope loopne ljmp lcall)) (enc bw)
          (w != 0) (enc w)
          (mn = 'movd) (enc 4)
          (pp? && two? (enc dw)) (enc dw)
          ; a bit test of memory by an immediate, unsized, at the segment's width as gas
          (elem tn '(bt bts btr btc) && #ops = 2 && <(ops 1) = 'im && two? (enc (md = 16 ? 2 4))) (enc (md = 16 ? 2 4))
          (enc 0 @ b (two? b ? b
             (filter two? (map enc '(1 2 4 8)) @ l (#l = 1 ? <l ()))))))

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
