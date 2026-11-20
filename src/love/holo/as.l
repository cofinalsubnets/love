; as -- a GNU x86-64 assembler over holo: dialect.l reads either dialect into one value, and
; this lays it by x64.l's table to the byte/fixup item stream, for obj.l and link.l: the value
; in the table's terms, at the mode (64, or i386's 32 and 16). branches are near, never relaxed.
;
; load after holo.l, x64.l and dialect.l:
;   out/love -l src/love/holo/holo.l -l src/love/holo/x64.l -l src/love/holo/dialect.l -l src/love/holo/as.l ...

(module 'holo
(:
   (as-regn o) (<>o >= 16 ? (<>o - 16) <>o)            ; a register operand's encoding number (ah..bh: 4..7)
   (as-regw o) (<o = 'rg ? <>>o 0)                      ; ... and its width, 0 if it isn't one
   ;; the address size outside an operand: 67 where memory's registers are not the segment's
   ;; width. dialect.l marks a 16-bit address register +32 (bx bp si di: 35 37 38 39), and
   ;; 32-bit ones by a seventh field, 'a32, which a 64-bit segment lays as 67
   (as-a16? o) (<o = 'mem && (o 1 >= 32 || o 2 >= 32))
   (as-abs? o) (<o = 'mem && o 1 < 0 && o 2 < 0)
   (as-a32? o) (6 < #o && o 6 = 'a32)
   (as-asz md o) (? !(<o = 'mem) ()
                    (md = 64) (as-a32? o ? '(103) ())
                    (as-a16? o) (md = 32 ? '(103) ())
                    (as-abs? o) ()
                    (md = 16 ? '(103) ()))

   ;; jcc -> the low byte of 0F 8x
   as-cc {'jo 128 'jno 129 'jb 130 'jc 130 'jnae 130 'jae 131 'jnb 131 'jnc 131
          'je 132 'jz 132 'jne 133 'jnz 133 'jbe 134 'jna 134 'ja 135 'jnbe 135
          'js 136 'jns 137 'jp 138 'jpe 138 'jnp 139 'jpo 139
          'jl 140 'jnge 140 'jge 141 'jnl 141 'jle 142 'jng 142 'jg 143 'jnle 143}
   ;; the rel8-only branches -> their opcode
   as-loops {'loop 226 'loope 225 'loopz 225 'loopne 224 'loopnz 224 'jecxz 227 'jrcxz 227 'jcxz 227}

   ;; an immediate spelled unsigned in w bytes, as the signed value those bytes hold
   (as-sx w v) (v >= 1 << (8 * w - 1) && v < 1 << 8 * w ? (v - (1 << 8 * w)) v)
   ;; a string op spelled with its operands: they say only the source's override and the
   ;; address size, laid ahead of the table's bare row as gas does. () when the line is not one
   as-strs '(movs stos lods cmps scas ins outs)
   (as-stro md mn ops)
    (? (#ops != 2) ()
       (: t (show mn) n #t stem (name (snip t 0 (n - 1)))
          sw (t (n - 1) @ 98 1 119 2 108 4 113 8 0)
          (bare o) (two? o && <o = 'seg ? <>>o o)
          (lane o) (bare o 1 % 32)
          ; beside the memory, stos lods scas name the accumulator and ins outs %dx
          (reg? o) (<o = 'rg && (? (elem stem '(ins outs)) (o = ['rg 2 2]) (as-regn o = 0 && as-regw o = sw)))
          ms (filter (o \ <(bare o) = 'mem) ops)
          (? (sw = 0 || nelem stem as-strs) ()
             !(#ms = (elem stem '(movs cmps) ? 2 1) && all (o \ <(bare o) = 'mem || reg? o) ops) ()
             (: src (filter (o \ lane o = 6) ms)
                sg (two? src && <<src = 'seg ? <><src 'ds)
                (? !(all (o \ elem (lane o) '(6 7)) ms) (scare 'as-strop ops)
                   ((sg = 'ds ? () [(sg @ 'fs 100 'gs 101 'es 38 'cs 46 'ss 54 (scare 'as-strop ops))])
                    + as-asz md (bare <ms)
                    + (as-tab md (name (show stem + (sw @ 1 "b" 2 "w" 4 "d" "q"))) 0 () @ b
                         (two? b ? b (scare 'as-strop ops)))))))))
   ; BMI's names, a width suffix past them
   as-bmi '(andn bzhi bextr pdep pext mulx sarx shlx shrx rorx blsr blsmsk blsi)
   ; pclmulqdq's spellings of its immediate, which halves it multiplies
   as-clmul {'pclmullqlqdq 0 'pclmulhqlqdq 1 'pclmullqhqdq 16 'pclmulhqhqdq 17}
   ; a cmov/set condition -> jcc's low byte, past a width suffix if it carries one; none is 0
   (as-ccl nm k) (: c (snip nm k #nm) v (peep as-cc (name ("j" + c)) 0)
                    (0 < v || #c < 2 ? v (peep as-cc (name ("j" + snip c 0 (#c - 1))) 0)))
   (as-symw o k) (xa-symoff (show <>o) @ so (fix k (k = 2 ? 'abs16 'abs32) <so >so))   ; `$sym+k` -> its fix of k bytes
   (as-syms o) (xa-symoff (show <>o) @ so (fix 4 'abs32s <so >so))      ; ..a dword the cpu sign-extends (64-bit mode)
   ;; x87: a waiting form is 9b ahead of its fn twin; these take st(1), or it beside the top, when
   ;; at&t names fewer
   as-x87w {'fstcw 'fnstcw 'fstsw 'fnstsw 'fstenv 'fnstenv 'fsave 'fnsave 'finit 'fninit 'fclex 'fnclex}
   as-x87d '(fld fst fstp fxch ffree fucom fucomp fcom fcomp fcomi fcomip fucomi fucomip faddp fmulp fsubp fsubrp fdivp fdivrp)
   ;; an instruction of the value: (op mn w ops), ops destination first. movabs is mov by range; a high-byte register (16 up) lays as 4..7
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
        (#ops @ 0 (scare 'as-op0 [mn md])
             1 (elem mn '(neg not inc dec) && w = 0 ? (scare 'as-nowidth [mn <ops]) (scare 'as-op1 mn))
             2 (scare 'as-op2 [mn ops])
             n (scare 'as-arity [mn n]))))
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
          (elem mn '(inb inw inl outb outw outl sgdtl sgdtw sidtl sidtw lgdtl lgdtw lidtl lidtw crc32b crc32w crc32l crc32q))
           (name (snip t 0 (#t - 1)))
          (as-sfx mn) (name (snip t 0 (#t - 1)))
          (mn @ 'wait 'fwait 'fildq 'fildll 'fistpq 'fistpll 'fisttpq 'fisttpll (as-brn mn))))
   ; the nullaries a suffix sizes, and a suffix's width
   (as-sfx mn) (show mn @ t (#t > 3 && elem (t (#t - 1)) [119 108 113] && elem (name (snip t 0 (#t - 1))) '(pushf popf pusha popa ret lret iret)))
   (as-sw t) (t (#t - 1) @ 98 1 119 2 108 4 113 8 0)
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
       ; a bare string op's l is Intel's d
       st (show mn @ t (#ops = 0 && #t > 3 && t (#t - 1) = 108 && elem (name (snip t 0 (#t - 1))) as-strs))
       tn (? (two? cp) <cp (mn = 'int && ops = [['im 3]]) 'int3
             st (show mn @ t (name (snip t 0 (#t - 1) + "d")))
             (as-tabn mn))
       ; a push's or pop's width unsuffixed, or the reader's 8 outside 64, is the segment's
       pp? (elem tn '(push pop pushf popf)) dw (? (md = 64) 8 (md = 16) 2 4)
       ; a descriptor table's or a sized nullary's width is its suffix's, crc32's its source's;
       ; a port's, int3's and a string op's the row's own
       w (? (as-sfx mn || elem tn '(sgdt sidt lgdt lidt crc32) && mn != tn) (as-sw (show mn))
            (tn = 'crc32) (#ops = 2 && <(ops 1) = 'rg ? (as-regw (ops 1)) 0)
            (pp? && md != 64 && w0 = 8) 0
            (st || elem tn '(in out int3)) 0
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
          (!(two? (peep x64-byname tn ())) || tn = 'crc32 && w = 0) ()
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
