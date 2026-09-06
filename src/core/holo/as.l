; as -- a real assembler front over holo: it reads standard GNU x86-64 assembly, in either
; dialect, and emits the same byte/fixup item stream the neutral backend (src/core/holo/x64.l)
; produces, so src/core/holo/obj.l lays the relocatable `.o` and src/core/holo/link.l links it --
; the front tooth of the gcc-free chain, paired with link.l's `ld`. the text is read by
; src/core/holo/dialect.l (att-read / intel-read) into one parsed-instruction value, and this
; file is the physical encoder over that value: where src/core/holo/text.l parses holo's own
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
;   out/love -l src/core/holo/holo.l -l src/core/holo/x64.l -l src/core/holo/dialect.l -l src/core/holo/as.l ...

(module 'holo
(: ;; --- encoder primitives (physical, width-aware; x64.l is the form reference). ---
   (as-hi n) (n >> 3)  (as-lo n) (n & 7)
   (as-rex f w r x b) (? (f > 0 || w > 0 || r > 0 || x > 0 || b > 0)   ; only when a bit is set,
                         [(64 | ((w << 3) | ((r << 2) | ((x << 1) | b))))] ())    ; or f forces one
   (as-mrm m r rm)  ((m << 6) | (((r & 7) << 3) | (rm & 7)))
   (as-sib sc ix b) ((sc << 6) | (((ix & 7) << 3) | (b & 7)))
   (as-scb s) (s @ 1 0 2 1 4 2 8 3 (scare 'as-badscale s))
   (as-regn o) <>o                                       ; a register operand's encoding number
   (as-regw o) (<o = 'rg ? <>>o 0)                      ; ... and its width, 0 if it isn't one
   ;; spl/bpl/sil/dil name the low four's bytes only under a REX -- bare, those slots spell
   ;; ah/ch/dh/bh -- so a byte operand in 4..7 forces an otherwise-empty one.
   (as-frc o) (? !(as-regw o = 1) 0 (4 <= as-regn o <= 7))
   (as-frcs ops) (foldl (\ a o (a > 0 ? a (as-frc o))) 0 ops)

   ;; --- the r/m half: a register (mod 3) or a memory operand, which lays a Modrm (+ SIB)
   ;; (+ displacement) and hands up the REX X and B bits. an rbp/r13 base has no disp-less slot
   ;; (mod 0 there means disp32) so force a disp byte; an rsp/r12 base needs a SIB to say so; a
   ;; base-less form is mod 0 + SIB base 5 + a full disp32; rip-relative is mod 0, rm 5, and the
   ;; four bytes are a rel32 fixup -- measured from the end of its own field, and the fixup
   ;; carries no addend, so a symbol with an offset cannot be spelled and is refused. ---
   (as-mem-rm rf o)
      (: b (o 1) ix (o 2) sc (o 3) d (o 4)
         (b < 0 ? ([(as-mrm 0 rf 4) (as-sib (as-scb sc) (ix < 0 ? 4 ix) 5)] + le32 d)
            (: md (? (d = 0 && !(as-lo b = 5)) 0 (fits8 d) 1 2)
               dsp (? (md = 0) () (md = 1) [(byte d)] (le32 d))
               hd (? (ix >= 0)      [(as-mrm md rf 4) (as-sib (as-scb sc) ix b)]
                     (as-lo b = 4)  [(as-mrm md rf 4) (as-sib 0 4 b)]
                     [(as-mrm md rf (as-lo b))])
               (hd + dsp))))
   (as-rm rf o) (<o @ 'mem (as-mem-rm rf o)
                      'rip (<>>o = 0 ? [(as-mrm 0 rf 5) (fix 4 'rel32 <>o 0)] (scare 'as-ripoff o))
                      'rg  [(as-mrm 3 rf (as-regn o))]
                      (scare 'as-notrm o))
   (as-rm-x o)  (<o @ 'mem (: i <>>o (i < 0 ? 0 (as-hi i))) 0)
   (as-rm-b o)  (<o @ 'mem (: b <>o (b < 0 ? 0 (as-hi b)))
                      'rip 0
                      (as-hi (as-regn o)))
   (as-mem? o)  ((<o = 'mem) || (<o = 'rip))

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
   as-alu (tabof
        [('add . '(1 0)) ('or . '(9 1)) ('and . '(33 4)) ('sub . '(41 5))
          ('xor . '(49 6)) ('cmp . '(57 7))])
   ;; the condition codes: jcc mnemonic -> 0F 8x low byte.
   as-cc (tabof
        [('je . 132) ('jz . 132) ('jne . 133) ('jnz . 133) ('jl . 140) ('jge . 141)
          ('jle . 142) ('jg . 143) ('jb . 130) ('jc . 130) ('jae . 131) ('jnc . 131)
          ('jbe . 134) ('ja . 135) ('js . 136) ('jns . 137) ('jo . 128) ('jno . 129)
          ('jp . 138) ('jnp . 139)])

   ;; alu $imm,r/m: 80 /ext ib for a byte, else the 83 /ext ib short form where the immediate fits,
   ;; else 81 /ext iz.
   (as-alu-i ext w frc rm imm)
      (? (w = 1)     (as-emit 1 frc '(128) ext rm + [(byte imm)])
         (fits8 imm) (as-emit w frc '(131) ext rm + [(byte imm)])
         (as-emit w frc '(129) ext rm + as-imw w imm))

   ;; mov $imm,%reg: the b0/b8+r short forms by width, movabs where a 64-bit immediate needs it,
   ;; c7 /0 id where it fits signed-32.
   (as-mov-ri d w frc imm)
      (: rx (as-rex frc (as-rexw w) 0 0 (as-hi d))
         (? (w = 1) (catall [rx [(176 | as-lo d) (byte imm)]])
            (w = 2) (catall ['(102) rx [(184 | as-lo d)] (le16 imm)])
            (w = 4) (catall [rx [(184 | as-lo d)] (le32 imm)])
            (fits32 imm) (catall [rx [199 (as-mrm 3 0 d)] (le32 imm)])
            (catall [rx [(184 | as-lo d)] (le64 imm)])))

   ;; --- the per-instruction encoders (each -> a byte/fix item list), in at&T operand order. ---
   ;; a rip-relative operand with an immediate tail is refused, not encoded: x64-patch measures
   ;; rel32 from the end of its own field, and holo's fixup carries no addend to walk past the tail.
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
            (: im (<b @ 'rip (scare 'as-ripimm [a b]),
                   <>a)
               (? (mn = 'mov && kb = 'rg) (as-mov-ri (as-regn b) w frc im)
                  (opi > 0) (as-emit w frc [(as-opw opi w)] 0 b + as-imw w im)
                  (as-alu-i <>alu w frc b im)))
            (scare 'as-op2-form [a b])))
   (as-1 mn w a)                                             ; one-operand
      (: k <a  frc (as-frc a)
         pw (w @ 2 2 0)                                  ; push/pop take 66 but never REX.W
         (? (mn = 'push)                                     ; ff /6
            (k @ 'rg (: n (as-regn a)
                      (as-p16 pw + (n >= 8 ? [65 (80 | as-lo n)] [(80 | n)])))
                 (as-emit pw 0 '(255) 6 a))
            (mn = 'pop)                                      ; 8f /0
            (k @ 'rg (: n (as-regn a)
                      (as-p16 pw + (n >= 8 ? [65 (88 | as-lo n)] [(88 | n)])))
                 (as-emit pw 0 '(143) 0 a))
            (member? mn '(neg not inc dec))
            (: opc (member? mn '(inc dec) ? 255 247)
               ext (mn @ 'neg 3 'not 2 'inc 0 1)
               (w @ 0 (scare 'as-nowidth [mn a]) (as-emit w frc [(as-opw opc w)] ext a)))
            (k = 'ind)                                       ; call/jmp through a register or memory
            (: o (a 1)
               (mn @ 'call (as-emit 0 0 '(255) 2 o)
                     'jmp  (as-emit 0 0 '(255) 4 o)
                     (scare 'as-op1 mn)))
            (member? mn '(call jmp))
            (: sym (a 1) (mn @ 'call [232 (fix 4 'rel32 sym 0)] [233 (fix 4 'rel32 sym 0)]))
            (as-cc mn) (: sym (a 1) [15 (peep as-cc mn 0) (fix 4 'rel32 sym 0)])
            (scare 'as-op1 mn)))
   ;; --- the nullaries, by their one spelling: the reader folds at&T's c<from>t<to> family
   ;; (cltq, cltd, ..) and retq/leaveq/xlatb onto these. `int3' is what holo's own text calls trap.
   as-nils (tabof
        [('ret . '(195)) ('nop . '(144)) ('hlt . '(244))
          ('syscall . '(15 5)) ('leave . '(201))
          ('cbw . '(102 152)) ('cwde . '(152)) ('cdqe . '(72 152))      ; al -> ax, ax -> eax, eax -> rax
          ('cwd . '(102 153)) ('cdq . '(153)) ('cqo . '(72 153))        ; .. and the dx:ax splits
          ('int3 . '(204)) ('ud2 . '(15 11)) ('pause . '(243 144))
          ('cpuid . '(15 162)) ('rdtsc . '(15 49))
          ('cli . '(250)) ('sti . '(251))                  ; the interrupt flag
          ('clc . '(248)) ('stc . '(249)) ('cmc . '(245))   ; ... the carry flag
          ('cld . '(252)) ('std . '(253))                  ; ... and the direction flag
          ('lahf . '(159)) ('sahf . '(158))
          ('xlat . '(215))
          ('sysret . '(15 7)) ('sysretl . '(15 7)) ('sysretq . '(72 15 7))])
   (as-0 mn) (as-nils mn @ () (scare 'as-op0 mn) b b)

   ;; an instruction of the value: (op mn w ops), ops destination first; the encoders above
   ;; take at&T's order. movabs is mov by range here; a high-byte register (ah.., slot 16 up)
   ;; has no encoding in this front.
   (as-instr it)
    (: mn (it 1 = 'movabs ? 'mov (it 1)) w (it 2) ops (it 3)
     _ (foldl (\ _ o ((<o = 'rg && <>o >= 16) ? (scare 'as-highbyte o) 0)) 0 ops)
     (#ops @ 0 (as-0 mn)
             1 (as-1 mn w <ops)
             2 (as-2 mn w <>ops <ops)
             n (scare 'as-arity [mn n])))

   ;; --- pass one: walk the items, encode each, assign addresses, record labels + .globl. returns
   ;;     a tablet { 'items 'labels 'globls }. label defs emit no bytes; directives steer. ---
   as-dirs '(".text" ".data" ".section" ".p2align" ".align" ".type" ".size" ".file" ".ident")
   (as-lay its)
      (: labels {}  globls {}  st {}
         (go its addr items)
            (? !(two? its) (pins st 'items (rev items) 'labels labels 'globls globls)
               (: it <its
                  (<it @ 'label (pin labels <>it addr, go >its addr items)
                        'globl (pin globls <>it 1, go >its addr items)
                        'dir (member? <>it as-dirs ? (go >its addr items)   ; M1: single .text section
                                (scare 'as-directive <>it))
                        (: r (revonto (as-instr it) items 0)
                           (go >its (addr + <r) >r)))))
         (go its 0 ()))

   ;; --- resolve intra-section fixups (near rel32) to final .text bytes, and the hex for goldens.
   ;;     as-text reads at&T; as-textv takes the value, so either dialect assembles. ---
   (as-textv its) (: st (as-lay its)
                     (resolve (st 'items) (peep st 'labels 0) (backends 'x64) 0))
   (as-text src) (as-textv (att-read src))
   (as-hexv its) (hexs (as-textv its))
   (as-hex src)  (hexs (as-text src)))
) ; module 'holo
