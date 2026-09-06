; dialect -- the x86-64 assembler-text lens: AT&T and Intel are two spellings of one parsed
; instruction, and this file is a reader and a shower for each over that one value. nothing here
; encodes: src/core/holo/as.l is the physical encoder and reads the value this file produces,
; so `as` takes either dialect and the two spellings can be converted through the middle
; (src/apps/lapiz/lapiz.l lists both under the 'x86 hub).
;
;   (att-read s)  (att-show items)  (intel-read s)  (intel-show items)
;
; --- the middle ---
; a file is a list of items, one per non-blank line:
;   ('op mn w ops)        an instruction: the canonical stem, the operand size in bytes (0 = unstated),
;                         the operands DESTINATION FIRST -- Intel's order, the manual's, and holo's
;   ('label sym)  ('globl sym)  ('dir name rest)     -- rest is the directive's tail, verbatim
; an operand:
;   ('rg enc w)   a register, w in 1/2/4/8 (16 = an xmm register)
;   ('im n)  ('ims sym)  ('lbl sym)  ('rip sym off)  ('ind o)  ('mem base index scale disp)
; a memory operand's absent register is -1. the stem folds away what the dialects disagree on:
; the at&T size suffix (movl -> mov, w 4), the sign/zero-extend family (movzbl / movzx eax, BYTE
; PTR -> movzb, w = the destination's), and the nullaries at&T names c<from>t<to> (cltq -> cdqe).
;
; --- the laws (test/holo/as.l proves them over the golden battery, test/gate/dialect.sh over
; gcc's own two outputs of every test/cc file) ---
;   (att-read (att-show v)) = v   and   (intel-read (intel-show v)) = v
; so intel = intel-show * att-read is a conversion, and it encodes to the same bytes. reading is
; a retraction: a suffix a register already carries, a PTR an SSE mnemonic already implies, the
; spaces inside a bracket, gcc's quoted symbols, `-12[rbp]` against `[rbp - 12]` all land on one
; value, and the shower picks one spelling. what neither surface carries -- a segment override,
; a symbolic displacement off anything but rip -- scares in the reader, so a typo never drops out.

(module 'holo
(: ;; --- the physical register file, both ways: a name -> (enc w), and (enc w) -> the name. the
   ;; low 8 have irregular byte/word names, so spell the rows; r8..r15 and xmm0..15 are uniform. ---
   xa-regs  (tablet 0)
   xa-names (tablet 0)
   (xa-reg! nm e w) (pin xa-regs (name nm) [e w], pin xa-names (e * 32 + w) nm)
   _ (foldl (\ _ row
               (: e (row 0)
                  _ (xa-reg! (row 1) e 8) _ (xa-reg! (row 2) e 4)
                  _ (xa-reg! (row 3) e 2) _ (xa-reg! (row 4) e 1) 0))
        0 '((0 "rax" "eax" "ax" "al")  (1 "rcx" "ecx" "cx" "cl")
             (2 "rdx" "edx" "dx" "dl")  (3 "rbx" "ebx" "bx" "bl")
             (4 "rsp" "esp" "sp" "spl") (5 "rbp" "ebp" "bp" "bpl")
             (6 "rsi" "esi" "si" "sil") (7 "rdi" "edi" "di" "dil")))
   _ (foldl (\ _ i
               (: n ("r" + show i)
                  _ (xa-reg! n i 8) _ (xa-reg! (n + "d") i 4)
                  _ (xa-reg! (n + "w") i 2) _ (xa-reg! (n + "b") i 1) 0))
        0 '(8 9 10 11 12 13 14 15))
   _ (foldl (\ _ i (xa-reg! ("xmm" + show i) i 16, 0)) 0 ^16)
   ;; the high bytes ah/ch/dh/bh share slots 4..7 with spl/bpl/sil/dil (REX tells them apart), so
   ;; they sit 16 above -- a value the encoder can see is not a byte it lays
   _ (foldl (\ _ r (xa-reg! <r <>r 1, 0)) 0 '(("ah" 20) ("ch" 21) ("dh" 22) ("bh" 23)))
   (xa-reg nm) (: r (xa-regs (name nm)) (two? r ? ['rg <r <>r] ()))    ; a register operand, or ()
   (xa-regname o) (xa-names (<>o * 32 + <>>o))
   (xa-gpr? o) (<o = 'rg && <>>o < 16)

   ;; --- numerals: decimal, 0x-hex, optionally signed -- every byte, or it is not one. ---
   (xa-hexd c) (? (48 <= c <= 57)  (c - 48)
                  (97 <= c <= 102) (c - 87)
                  (65 <= c <= 70)  (c - 55)
                  (scare 'as-hexdigit c))
   (xa-decv s) (foldl (a \ i \ a * 10 + s i - 48) 0 ^#s)
   (xa-hexv s) (foldl (a \ i \ a * 16 + xa-hexd (s i)) 0 ^#s)
   (xa-neg? s) (#s > 0 && s 0 = 45)
   (xa-hex? s) (#s >= 2 && s 0 = 48 && (s 1 = 120 || s 1 = 88))
   (xa-num s)  (? (xa-neg? s) (0 - xa-num (snip s 1 #s))
                  (xa-hex? s) (xa-hexv (snip s 2 #s))
                  (xa-decv s))
   (xa-dig? c)  (48 <= c <= 57)
   (xa-hexc? c) (xa-dig? c || 97 <= c <= 102 || 65 <= c <= 70)
   (xa-allof? s p k) (: n #s ((: (g i) (i >= n ? (n > k) (p (s i)) (g (i + 1)) 0)) k))
   (xa-num? s) (? (xa-neg? s) (xa-num? (snip s 1 #s))
                  (xa-hex? s) (xa-allof? s xa-hexc? 2)
                  (xa-allof? s xa-dig? 0))
   (xa-imm s) (xa-num? s ? (xa-num s) (scare 'as-badnum s))       ; a number where one is required
   ;; a symbol, or a symbol with an offset either side: sym, sym+4, sym-8, 4+sym -> (sym . off)
   (xa-symoff s) (: i ((: (g i) (? (i >= #s) -1 (s i = 43 || s i = 45) i (g (i + 1)))) 1)
                    (? (i < 0) ((name (xa-unquote s)) . 0)
                       (xa-num? (snip s 0 i) && s i = 43)
                       ((name (xa-unquote (snip s (i + 1) #s))) . (xa-num (snip s 0 i)))
                       ((name (xa-unquote (snip s 0 i))) . (xa-imm (snip s (s i = 43 ? (i + 1) i) #s)))))

   ;; --- string helpers over the byte string. ---
   (xa-has? s c) ((: (g i) (? (i >= #s) 0 (s i = c) 1 (g (i + 1)))) 0)
   (xa-idx s c)  ((: (g i) (? (i >= #s) -1 (s i = c) i (g (i + 1)))) 0)
   (xa-ws? c) (c = 32 || c = 9)
   (xa-trim s)   (: n #s
      a ((: (gl i) (i < n && xa-ws? (s i) ? (gl (i + 1)) i)) 0)
      b ((: (gr j) (j > a && xa-ws? (s (j - 1)) ? (gr (j - 1)) j)) n)
      (snip s a b))
   (xa-nows s) (string (filter (c \ !(xa-ws? c)) (chars s)))
   ;; gcc quotes a symbol in its Intel output: "main", and "printf"@PLT -- splice the quotes out
   (xa-unquote s) (: j (#s >= 2 && s 0 = 34 ? (xa-idx (snip s 1 #s) 34) -1)
                     (j < 0 ? s (snip s 1 (j + 1) + snip s (j + 2) #s)))
   (xa-starts? s p) (#s >= #p && (snip s 0 #p) = p)
   ;; '#' starts a comment to end of line -- outside a quoted string
   (xa-decomment s) ((: (g i q) (? (i >= #s) s
                                    (s i = 34) (g (i + 1) !q)
                                    (s i = 35 && !q) (snip s 0 i)
                                    (g (i + 1) q))) 0 0)
   (xa-lines s) (: n #s
      ((: (g i st acc) (? (i >= n) (rev (snip s st n . acc))
                          (s i = 10) (g (i + 1) (i + 1) (snip s st i . acc))
                          (g (i + 1) st acc))) 0 0 ()))
   ;; split on a byte, trimming each field
   (xa-split s c) (: n #s
      ((: (g i st acc) (? (i >= n) (rev (xa-trim (snip s st n) . acc))
                          (s i = c) (g (i + 1) (i + 1) (xa-trim (snip s st i) . acc))
                          (g (i + 1) st acc))) 0 0 ()))
   ;; the operand list splits on top-level commas only: a memory operand carries its own inside
   ;; its parens or brackets
   (xa-oplist s) (: n #s
      ((: (g i st d acc)
          (? (i >= n) (rev (xa-trim (snip s st n) . acc))
             (s i = 40 || s i = 91) (g (i + 1) st (d + 1) acc)
             (s i = 41 || s i = 93) (g (i + 1) st (d - 1) acc)
             (s i = 44 && d = 0) (g (i + 1) (i + 1) 0 (xa-trim (snip s st i) . acc))
             (g (i + 1) st d acc))) 0 0 0 ()))
   (xa-ops rest) (0 = #rest ? () (xa-oplist rest))
   ;; the head word and the tail of a line
   (xa-cut s)   (: i (xa-idx s 32) j (xa-idx s 9)
                   (? (i < 0) j (j < 0) i (i < j) i j))
   (xa-mnem s)  (: k (xa-cut s) (k < 0 ? s (snip s 0 k)))
   (xa-rest s)  (: k (xa-cut s) (k < 0 ? "" (xa-trim (snip s k #s))))
   (xa-join sep l) (? !(two? l) "" (foldl (\ a s (a + sep + s)) <l >l))

   ;; --- the operand size. stated by an at&T suffix or an Intel PTR; else read off the
   ;; destination's GPR, else the first GPR's; 0 when nothing says. a stated size that disagrees
   ;; with that register is a clash, not a choice. ---
   (xa-sfxw c) (c @ 98 1 119 2 108 4 113 8 0)
   (xa-wsfx w) (w @ 1 "b" 2 "w" 4 "l" 8 "q" "")
   (xa-gprw ops) (foldl (\ a o (a > 0 ? a (xa-gpr? o ? <>>o 0))) 0 ops)
   (xa-width sw ops)
      (: rw (xa-gprw ops)
         (? (sw = 0) rw
            (rw > 0 && rw != sw) (scare 'as-widthclash [sw rw])
            sw))
   ;; the stems that take an at&T size suffix
   xa-sfxable '(mov add or and sub xor cmp test neg not inc dec push pop lea
                imul mul div idiv adc sbb sal shl shr sar rol ror shld shrd xchg bswap bsr bsf
                movabs cvttsd2si cvttss2si cvtsd2si cvtss2si cvtsi2sd cvtsi2ss)
   ;; the nullaries at&T spells c<from>t<to>, and Intel c<from><to>; the middle keeps Intel's
   xa-att-nil (tabof [('cltq . 'cdqe) ('cltd . 'cdq) ('cqto . 'cqo) ('cwtl . 'cwde)
                      ('cbtw . 'cbw) ('cwtd . 'cwd) ('retq . 'ret) ('leaveq . 'leave) ('xlatb . 'xlat)])
   xa-nil-att (tabof [('cdqe . 'cltq) ('cdq . 'cltd) ('cqo . 'cqto) ('cwde . 'cwtl)
                      ('cbw . 'cbtw) ('cwd . 'cwtd)])
   ;; the memory operand size an SSE mnemonic (and an indirect branch) implies: Intel spells it
   ;; as a PTR, at&T not at all, and neither makes it the operand size
   xa-ptrfix (tabof
        [('movsd . 8) ('movss . 4) ('movq . 8) ('movd . 4) ('movaps . 16) ('movapd . 16)
          ('movdqa . 16) ('movdqu . 16) ('movups . 16) ('movupd . 16)
          ('addsd . 8) ('subsd . 8) ('mulsd . 8) ('divsd . 8) ('sqrtsd . 8) ('maxsd . 8) ('minsd . 8)
          ('addss . 4) ('subss . 4) ('mulss . 4) ('divss . 4) ('sqrtss . 4) ('maxss . 4) ('minss . 4)
          ('ucomisd . 8) ('comisd . 8) ('ucomiss . 4) ('comiss . 4)
          ('xorpd . 16) ('xorps . 16) ('andpd . 16) ('andps . 16) ('andnpd . 16) ('orpd . 16) ('pxor . 16)
          ('cvtss2sd . 4) ('cvtsd2ss . 8) ('cvttsd2si . 8) ('cvttss2si . 4) ('cvtsd2si . 8) ('cvtss2si . 4)
          ('call . 8) ('jmp . 8)])
   (xa-branch? mn) (member? mn '(call jmp))
   ;; push/pop of an immediate or memory are 64-bit unless sized: at&T writes pushq $5, Intel push 5
   (xa-w64 mn w) (w = 0 && member? mn '(push pop) ? 8 w)
   (xa-xmm? ops) (foldl (\ a o (a > 0 ? a (<o = 'rg && <>>o = 16))) 0 ops)
   ;; the sign/zero-extend family: stem movs<src>/movz<src>, w the destination's
   (xa-ext? mn) (member? mn '(movsb movsw movsl movzb movzw))
   (xa-extsrc mn) (mn @ 'movsb 1 'movsw 2 'movsl 4 'movzb 1 2)
   (xa-ptrword w) (w @ 1 "BYTE" 2 "WORD" 4 "DWORD" 8 "QWORD" 16 "XMMWORD" "")
   (xa-ptrsz s) (s @ "byte" 1 "word" 2 "dword" 4 "qword" 8 "xmmword" 16 0)

   ;; --- the line shapes both dialects share: blank, `name:`, `.directive tail`. ---
   (xa-line raw insn)
      (: s (xa-trim (xa-decomment raw))
         (? (0 = #s) ()
            (s (#s - 1) = 58) ['label (name (xa-unquote (xa-trim (snip s 0 (#s - 1)))))]
            (s 0 = 46)
            (: mn (xa-mnem s) rest (xa-rest s)
               (? (mn = ".globl" || mn = ".global") ['globl (name (xa-unquote rest))]
                  (mn = ".intel_syntax" || mn = ".att_syntax") ()
                  ['dir mn rest]))
            (insn (xa-mnem s) (xa-rest s))))
   (xa-read s insn) (filter two? (map (\ l (xa-line l insn)) (xa-lines s)))
   (xa-show items line)
      (foldl (\ a it (a + (<it @ 'label (show <>it + ":\n")
                                'globl ("\t.globl\t" + show <>it + "\n")
                                'dir (: r (<>>it) ("\t" + <>it + (0 = #r ? "" ("\t" + r)) + "\n"))
                                (line it))))
             "" items)

   ;; ================================================================ at&T
   ;; --- operands: %reg, $imm, $sym, disp(base,index,scale), sym(%rip), sym+4(%rip), *ind, label ---
   (at-reglook nm) (: r (xa-reg nm) (two? r ? r (scare 'as-badreg nm)))
   (at-mreg f) (? (0 = #f) -1 <>(at-reglook (snip f 1 #f)))    ; a %reg field, or absent
   (at-operand t)
      (? (t 0 = 42) ['ind (at-operand (snip t 1 #t))]
         (xa-has? t 40)
         (: op (xa-idx t 40) inner (snip t (op + 1) (#t - 1)) disp (snip t 0 op)
            (? (inner = "%rip") (: so (xa-symoff disp) ['rip <so >so])
               (: fs (xa-split inner 44) k #fs
                  d (? (0 = #disp) 0 (xa-num? disp) (xa-num disp) (scare 'as-symdisp t))
                  (? (k > 3) (scare 'as-memform t)
                     ['mem (at-mreg <fs) (k < 2 ? -1 (at-mreg (fs 1)))
                           (k < 3 ? 1 (xa-imm (fs 2))) d]))))
         (t 0 = 37) (at-reglook (snip t 1 #t))
         (t 0 = 36) (: v (snip t 1 #t)
                      (? (xa-num? v) ['im (xa-num v)]
                         (xa-dig? (v 0) || xa-neg? v) (scare 'as-badnum v)
                         ['ims (name (xa-unquote v))]))
         (xa-num? t) ['im (xa-num t)]
         ['lbl (name (xa-unquote t))])
   ;; --- the mnemonic: a size suffix off a suffixable stem, the extend family, the nullaries ---
   (at-mnw s) (: n #s l (name s)
      (? (xa-att-nil l) [(xa-att-nil l) 0]
         (n = 6 && (xa-starts? s "movs" || xa-starts? s "movz")
            && (xa-sfxw (s 4) @ 0 0 8 0 1) && xa-sfxw (s 5) > 0)
         [(name (snip s 0 5)) (xa-sfxw (s 5))]
         (: w (n < 2 ? 0 (xa-sfxw (s (n - 1)))) st (w = 0 ? 'x (name (snip s 0 (n - 1))))
            (w > 0 && member? st xa-sfxable ? [st w] [l 0]))))
   (at-insn mn rest)
      (: mw (at-mnw mn) st <mw ops (rev (map at-operand (xa-ops rest)))
         (? (xa-branch? st) ['op st 0 ops]
            (st = 'mov && xa-xmm? ops) ['op (mw 1 = 4 ? 'movd 'movq) (xa-gprw ops) ops]
            (xa-ext? st) ['op st (xa-width (mw 1) [<ops]) ops]
            ['op st (xa-w64 st (xa-width (mw 1) ops)) ops]))
   (att-read s) (xa-read s at-insn)

   ;; --- the shower ---
   (at-off n) (n = 0 ? "" ((n > 0 ? "+" "") + show n))
   (at-op o)
      (<o @ 'rg ("%" + xa-regname o)
            'im ("$" + show <>o)
            'ims ("$" + show <>o)
            'lbl (show <>o)
            'rip (show <>o + at-off <>>o + "(%rip)")
            'ind ("*" + at-op <>o)
            (: b (o 1) ix (o 2) sc (o 3) d (o 4)
               ((d = 0 && b >= 0 ? "" (show d))
                + "(" + (b < 0 ? "" ("%" + xa-names (b * 32 + 8)))
                + (ix < 0 ? "" (",%" + xa-names (ix * 32 + 8) + (sc = 1 ? "" ("," + show sc))))
                + ")")))
   (at-mn mn w ops)
      (? (xa-nil-att mn) (show (xa-nil-att mn))
         (xa-ext? mn) (show mn + xa-wsfx w)
         (w > 0 && member? mn xa-sfxable && xa-gprw ops = 0) (show mn + xa-wsfx w)
         (show mn))
   (att-show items)
      (xa-show items (\ it (: mn (it 1) w (it 2) ops (it 3)
                             ("\t" + at-mn mn w ops
                              + (two? ops ? ("\t" + xa-join ", " (map at-op (rev ops))) "") + "\n"))))

   ;; ================================================================ Intel
   ;; --- operands: reg, imm, OFFSET [FLAT:]sym, [SIZE PTR] disp[base+index*scale], sym[rip],
   ;;     [rip+sym+4], label. an operand comes back as (ptr-size . operand), size 0 when no PTR. ---
   (in-ptr l)                                   ; -> (size . rest), from the lowercased text
      (: k (xa-cut l)
         sz (k < 0 ? 0 (xa-ptrsz (snip l 0 k)))
         r  (sz = 0 ? "" (xa-trim (snip l k #l)))
         (? (sz > 0 && xa-starts? r "ptr") (sz . (xa-trim (snip r 3 #r)))
            (0 . l)))
   (in-term t) (: i (xa-idx t 42)                ; one bracket term -> (ix enc sc) (rg enc) (n v) (sym s) (rip)
      (? (t = "rip") ['rip]
         (i >= 0) (: a (snip t 0 i) b (snip t (i + 1) #t)
                    ra (xa-reg a) rb (xa-reg b)
                    (? (two? ra) ['ix <>ra (xa-imm b)]
                       (two? rb) ['ix <>rb (xa-imm a)]
                       (scare 'as-memform t)))
         (xa-num? t) ['n (xa-num t)]
         (: r (xa-reg t) (two? r ? ['rg <>r] ['sym (name (xa-unquote t))]))))
   ;; split the bracket's inside on + and -, each term with its sign
   (in-terms s) (: n #s
      ((: (g i st sg acc)
          (? (i >= n) (rev ((sg . (snip s st n)) . acc))
             (i > st && (s i = 43 || s i = 45))
             (g (i + 1) (i + 1) (s i = 45 ? -1 1) ((sg . (snip s st i)) . acc))
             (i = st && s i = 45) (g (i + 1) (i + 1) -1 acc)
             (i = st && s i = 43) (g (i + 1) (i + 1) 1 acc)
             (g (i + 1) st sg acc))) 0 0 1 ()))
   (in-mem u)
      (: i (xa-idx u 91) j (xa-idx u 93)
         pre (xa-nows (snip u 0 i)) inner (xa-nows (snip u (i + 1) j))
         _ (? (xa-has? pre 58) (scare 'as-segment u) 0)
         st {}                                    ; 'b 'ix 'sc 'd 'sym 'rip
         _ (pins st 'b -1 'ix -1 'sc 1 'd 0 'sym () 'rip 0)
         (take! sg t)
            (: tm (in-term t)
               (<tm @ 'rip (pin st 'rip 1)
                     'n (pin st 'd (peep st 'd 0 + sg * <>tm))
                     'ix (pins st 'ix <>tm 'sc <>>tm)
                     'sym (pin st 'sym <>tm)
                     (peep st 'b -1 < 0 ? (pin st 'b <>tm) (pins st 'ix <>tm 'sc 1))))
         _ (? (0 = #pre) 0
              (xa-num? pre) (pin st 'd (xa-num pre))
              (: so (xa-symoff pre) (pins st 'sym <so 'd >so)))
         _ (foldl (\ _ p (take! <p >p)) 0 (in-terms inner))
         (? (peep st 'rip 0) ['rip (peep st 'sym ()) (peep st 'd 0)]
            (nom? (peep st 'sym ())) (scare 'as-symdisp u)
            ['mem (peep st 'b -1) (peep st 'ix -1) (peep st 'sc 1) (peep st 'd 0)]))
   (in-operand t)                               ; -> (ptr-size . operand)
      (: l (lower t) p (in-ptr l) sz <p tail >p
         (? (xa-starts? l "offset ")
            (: v (xa-trim (snip t 7 #t))
               v (xa-starts? (lower v) "flat:" ? (xa-trim (snip v 5 #v)) v)
               (0 . ['ims (name (xa-unquote v))]))
            (xa-has? t 91) (sz . (in-mem (snip t (#t - #tail) #t)))
            (sz > 0) (scare 'as-segment t)
            (xa-num? t) (0 . ['im (xa-num t)])
            (: r (xa-reg t) (two? r ? (0 . r) (0 . ['lbl (name (xa-unquote t))])))))
   (in-insn mn rest)
      (: l (name (lower mn)) prs (map in-operand (xa-ops rest))
         ops (map (p \ >p) prs)
         psz (foldl (\ a p (a > 0 ? a <p)) 0 prs)          ; the PTR size, if one operand said
         (? (xa-att-nil l) ['op (xa-att-nil l) 0 ops]
            (xa-branch? l) ['op l 0 (map (o \ (<o = 'rg || <o = 'mem || <o = 'rip) ? ['ind o] o) ops)]
            (member? l '(movsx movzx movsxd))
            (: src (ops 1)
               sw (? (l = 'movsxd) 4 (xa-gpr? src) <>>src (psz > 0) psz (scare 'as-extsrc rest))
               st (name ((l = 'movzx ? "movz" "movs") + xa-wsfx sw))
               ['op st (xa-width 0 [<ops]) ops])
            (xa-ptrfix l) ['op l (xa-gprw ops) ops]
            ['op l (xa-w64 l (xa-width (l = 'lea ? 0 psz) ops)) ops]))
   (intel-read s) (xa-read s in-insn)

   ;; --- the shower ---
   (in-mem-op o)
      (<o @ 'rip ("[rip+" + show <>o + at-off <>>o + "]")
            (: b (o 1) ix (o 2) sc (o 3) d (o 4)
               bs (b < 0 ? "" (xa-names (b * 32 + 8)))
               xs (ix < 0 ? "" ((0 = #bs ? "" "+") + xa-names (ix * 32 + 8) + (sc = 1 ? "" ("*" + show sc))))
               bare (0 = #bs && 0 = #xs)
               ds (? (d = 0 && !bare) ""
                     (d < 0 || bare) (show d)
                     ("+" + show d))
               ("[" + bs + xs + ds + "]")))
   (in-ptrsz mn w k)                        ; the PTR a memory operand at slot k of mn takes
      (? (xa-ext? mn && k = 1) (xa-extsrc mn)
         (xa-ptrfix mn) (xa-ptrfix mn)
         (mn = 'lea) 0
         w)
   (in-op mn w o k)
      (<o @ 'rg (xa-regname o)
            'im (show <>o)
            'ims ("OFFSET FLAT:" + show <>o)
            'lbl (show <>o)
            'ind (in-op mn w <>o k)
            (: sz (in-ptrsz mn w k)
               ((sz > 0 ? (xa-ptrword sz + " PTR ") "") + in-mem-op o)))
   (in-mn mn)
      (? (xa-ext? mn) (mn @ 'movsl "movsxd" (xa-starts? (show mn) "movz" ? "movzx" "movsx"))
         (show mn))
   (intel-show items)
      ("\t.intel_syntax noprefix\n"
       + xa-show items (\ it (: mn (it 1) w (it 2) ops (it 3)
                               ("\t" + in-mn mn
                                + (two? ops ? ("\t" + xa-join ", " (map (\ i (in-op mn w (ops i) i)) ^#ops)) "")
                                + "\n")))))
) ; module 'holo
