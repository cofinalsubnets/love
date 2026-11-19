; decode -- x86-64 machine code back to dialect.l's parsed instruction, for either shower to
; print. an opcode not known here lands as a `.byte` item, one byte at a time, so a stream never
; scares and always resynchronises.
;
;   (x64-decode s i)         one instruction at byte offset i of the string s -> (n . items):
;                            its length and its items (one, or a prefix item -- lock, rep -- first)
;   (x64-disasm s base)      the whole string -> ((off n items) ..), a branch or rip target an
;                            absolute number (base + where it points)
;   (x64-relabel rows base)  the same rows with every in-range target a symbol L<addr> and a
;                            (label L<addr>) row laid where it lands -- what as.l re-encodes
;
; a decoded operand is the value's: (rg enc w), (im n), (mem base index scale disp), a rip form
; (rip () disp) with no symbol, a branch target (lbl n) as a number, a memory operand under a
; segment override as (seg fs o). the operand size w is the instruction's, 0 where the value
; keeps none (branches, the SSE lane with no GPR) -- the reading att-read makes of the same text.

(module 'holo
(: ;; a read past the end answers 0; `fin` then refuses the instruction
   (dc-at s k) (k < #s ? (s k) 0)
   (dc-le s i n) (foldl (\ a k (a + (dc-at s (i + k) << 8 * k))) 0 ^n)
   (dc-sx v n) (1 << 8 * n - 1 @ m (v >= m ? (v - (m << 1)) v))
   (dc-imm s i n) (dc-sx (dc-le s i n) n)
   dc-hexd "0123456789abcdef"
   (dc-hex2 b) ("0x" + string (dc-hexd (b >> 4)) + string (dc-hexd (b & 15)))
   (dc-byte b) ['dir ".byte" (dc-hex2 b)]
   ;; a register operand: n the 4-bit number, w its width; a byte register 4..7 without a REX
   ;; is ah..bh, which the value keeps 16 above (dialect.l)
   (dc-reg n w rexp) (w = 1 && !rexp && 4 <= n <= 7 ? ['rg (n + 16) 1] ['rg n w])
   (pf p k) (peep p k 0)
   ;; modrm at k, the reg field at width wr and the r/m at wm (16 = xmm) -> [k2 reg rm digit],
   ;; a memory operand wrapped by any segment override
   (dc-modrm s k p wr wm)
    (: m (dc-at s k) md (m >> 6) dg (m >> 3 & 7) rm (m & 7)
       rexp (pf p 'rex) bx (pf p 'b) xx (pf p 'x)
       reg (dc-reg (dg | pf p 'r << 3) wr rexp)
       (wrap o) (nom? (pf p 'seg) ? ['seg (pf p 'seg) o] o)
       (? (md = 3) [(k + 1) reg (dc-reg (rm | bx << 3) wm rexp) dg]
          (md = 0 && rm = 5) [(k + 5) reg (wrap ['rip () (dc-imm s (k + 1) 4)]) dg]
          (rm = 4)                                                    ; a SIB
          (: sb (dc-at s (k + 1))
             ix ((sb >> 3) & 7 | xx << 3) ix2 (ix = 4 ? -1 ix)
             sc (ix2 < 0 ? 1 (1 << (sb >> 6)))
             nobase (md = 0 && sb & 7 = 5)
             bs (nobase ? -1 (sb & 7 | bx << 3))
             dn (? nobase 4 (md = 1) 1 (md = 2) 4 0)
             d (dn = 0 ? 0 (dc-imm s (k + 2) dn))
             [(k + 2 + dn) reg (wrap ['mem bs ix2 sc d]) dg])
          (: dn (md @ 1 1 2 4 0) d (dn @ 0 0 (dc-imm s (k + 1) dn))
             [(k + 1 + dn) reg (wrap ['mem (rm | bx << 3) -1 1 d]) dg])))

   ;; the prefixes, then the opcode
   (x64-decode s i)
    (:- (go i {}) n #s (go j p)
     (j >= n ? (1 . [(dc-byte (dc-at s i))])
      (s j @
       102 (go (j + 1) (pin p 'opsz 1))
       243 (go (j + 1) (pin p 'rep 1))
       242 (go (j + 1) (pin p 'repne 1))
       240 (go (j + 1) (pin p 'lock 1))
       100 (go (j + 1) (pin p 'seg 'fs))
       101 (go (j + 1) (pin p 'seg 'gs))
       38 (go (j + 1) (pin p 'seg 'es))  46 (go (j + 1) (pin p 'seg 'cs))
       54 (go (j + 1) (pin p 'seg 'ss))  62 (go (j + 1) (pin p 'seg 'ds))
       (c && 64 <= c <= 79)
        (go (j + 1) (pins p 'rex 1 'w (c >> 3 & 1) 'r (c >> 2 & 1) 'x (c >> 1 & 1) 'b (c & 1)))
       (dc-op s i j p))))

   ;; the prefix items an instruction carries: lock always, rep/repne unless the opcode ate them
   (dc-pre p ate) ((pf p 'lock ? [['op 'lock 0 ()]])
                   + (pf p 'rep && !ate ? [['op 'rep 0 ()]] ())
                   + (pf p 'repne && !ate ? [['op 'repne 0 ()]] ()))

   (dc-first p l) (? !(two? l) () (p <l) <l (dc-first p >l))
   ;; an instruction by its row in x64-tab (x64.l): the first row of its map and opcode whose
   ;; prefixes, modrm digit and widths fit, its kinds read in order
   (dc-op s i j p)
    (: n #s c (dc-at s j)
       mp (? (c != 15) 0 (dc-at s (j + 1) = 56) 2 (dc-at s (j + 1) = 58) 3 1)
       oc (mp @ 0 c 1 (dc-at s (j + 1)) (dc-at s (j + 2)))
       k (j + (mp @ 0 1 1 2 3))
       px (? (pf p 'repne) 'f2 (pf p 'rep) 'f3 (pf p 'opsz) 66 'none)
       w (? (pf p 'w) 8 (pf p 'opsz) 2 4) w8 (pf p 'opsz ? 2 8) wx (pf p 'w ? 8 4) rexp (pf p 'rex)
       lead (mp = 0 ? c 15)
       (fin ate k2 items) (k2 > n ? (1 . [(dc-byte lead)]) ((k2 - i) . (dc-pre p ate + items)))
       (wd l) (l @ "b" 1 "w" 2 "d" 4 "q" 8 "v" w "p" w8 "y" wx "z" (w = 2 ? 2 4) 0)
       m (dc-at s k)
       (fits? at) (all (e \ (: v (peep at e ()) (v = () ||
                         (e @ 'p (v = px) 'b (pf p 'b = v) 'w (pf p 'w = v) 'ow (w = v)
                              'd (((m >> 3) & 7) = v) 'mod (v = 'r ? ((m >> 6) = 3) ((m >> 6) != 3)) 'rm (m = v) 1))))
                       '(p b w ow d mod rm))
       (lay r)
        (: ks (r 3) at (r 4)
           g (dc-first (k \ elem (x64-role k) ["G" "V" "S" "C" "D"]) ks)
           e (dc-first (k \ elem (x64-role k) ["E" "W" "N"]) ks)
           (kw k) (x64-role k @ "V" 16 "W" 16 "N" 8 "S" 8 "C" 8 "D" 8 (wd (x64-wl k)))
           wr (g = () ? (e = () ? 0 (kw e)) (kw g)) wm (e = () ? wr (kw e))
           mr (g != () || e != ()) md (mr ? (dc-modrm s k p wr wm) ())
           (imm k0 l)                                          ; -> [operand next]
            (l @ "Ib" [['im (dc-imm s k0 1) 1] (k0 + 1)]
                 "Iz" ((w = 2 ? 2 4) @ z [['im (dc-imm s k0 z) z] (k0 + z)])
                 "Id" [['im (dc-imm s k0 4) 4] (k0 + 4)]
                 "Uv" ((w @ 8 8 2 2 4) @ z [['im (dc-le s k0 z) z] (k0 + z)])
                 "Uw" [['im (dc-le s k0 2) 2] (k0 + 2)]
                 "ub" [['im (dc-at s k0)] (k0 + 1)]
                 "Jb" [['lbl (k0 + 1 + dc-imm s k0 1)] (k0 + 1)]
                 [['lbl (k0 + 4 + dc-imm s k0 4)] (k0 + 4)])
           (go ks pos acc)
            (? !(two? ks) [pos (rev acc)]
               (: q <ks ro (x64-role q)
                  (ro @ "G" (go >ks pos (md 1 . acc)) "V" (go >ks pos (md 1 . acc))
                        "E" (go >ks pos (md 2 . acc)) "W" (go >ks pos (md 2 . acc))
                        "N" (go >ks pos (['ind (md 2)] . acc)) "S" (go >ks pos (['sr (md 3)] . acc))
                        "C" (go >ks pos (['cr <>(md 1)] . acc)) "D" (go >ks pos (['dr <>(md 1)] . acc))
                        "Z" (go >ks pos (dc-reg (oc & 7 | pf p 'b << 3) (wd (x64-wl q)) rexp . acc))
                        "A" (go >ks pos (dc-reg 0 (wd (x64-wl q)) rexp . acc))
                        "CL" (go >ks pos (['rg 1 1] . acc))
                        "T" (go >ks pos (['st (m & 7)] . acc)) "K" (go >ks pos (['st] . acc))
                        (imm pos (show q) @ (o nx) (go >ks nx (o . acc))))))
           st (mr ? (md 0) (peep at 'rm () != () || any (k \ x64-role k = "T") ks ? (k + 1) k))
           ; the item's width: the first general register's, reg field ahead of r/m
           gw (catmap (ro \ filter (k \ x64-role k = ro) ks) ["G" "E" "Z" "A"] @ l (two? l ? <l ()))
           iw (peep at 'iw () @ v (? (v = 'p) w8 (v != ()) v (gw = () ? 0 (kw gw))))
           ate (? (peep at 'ate 0) 1 (peep at 'x 0) (elem px '(f2 f3) ? 1 0) 0)
           (go ks st () @ (pos ops)
              (peep at 'fw 0 && pos < n && 216 <= dc-at s pos <= 223 ? (dc-op s i pos p @ r (<r . ([['op 'fwait 0 ()]] + >r)))
                 (fin ate pos [['op <r iw ops]]))))
       (try l) (? !(two? l) (mp = 0 ? (fin 0 k [(dc-byte c)]) (fin 0 (j + 1) [(dc-byte 15)]))
                  (fits? (<l 4) ? (lay <l) (try >l)))
       (try (peep x64-tabix (mp * 256 + oc) ())))

   ;; every instruction with its offset, targets made absolute
   (dc-abs base off n o)
    (<o @- o
     'lbl (charm? <>o ? ['lbl (<>o + base)] o)
     'rip (nom? <>o ? o ['rip () (<>>o + base + off + n)])   ; a rip form's disp becomes the address
     'ind ['ind (dc-abs base off n <>o)]
     'seg ['seg <>o (dc-abs base off n <>>o)])
   (x64-disasm s base)
    (:- (go 0 ()) n #s (go off acc)
     (off >= n ? (rev acc)
      (: r (x64-decode s off) ln <r
         its (map (it \ (<it = 'op ? ['op (it 1) (it 2) (map (dc-abs base off ln) (it 3))] it)) >r)
       (go (off + ln) ([off ln its] . acc)))))
   ;; a target on an instruction boundary becomes the symbol L<addr>, with a label row laid
   ;; there; a rip form becomes (rip L<addr> 0). base is where x64-disasm read the rows, so a
   ;; row's address is its offset past it
   (x64-relabel rows base)
    (: starts (foldl (t \ r \ pin t (<r + base) 1) {} rows)
       (sym a) (name ("L" + show a))
       (tgt a) (peep starts a 0)
       (fix o) (<o @- o
        'lbl (charm? <>o && tgt <>o ? ['lbl (sym <>o)] o)
        'rip (!(nom? <>o) && tgt <>>o ? ['rip (sym <>>o) 0] o)
        'ind ['ind (fix <>o)]
        'seg ['seg <>o (fix <>>o)])
       (tg o) (<o @- -1
        'lbl (charm? <>o ? <>o -1)                       ; an operand's in-stream address, or -1
        'rip (nom? <>o ? -1 <>>o)
        'ind (tg <>o)
        'seg (tg <>>o))
       used (foldl (\ t r (foldl (\ t it (<it = 'op ? (foldl (\ t o (tg o @ a (tgt a ? (pin t a 1) t))) t (it 3))
                                                    t))
                                 t (r 2)))
                   {} rows)
       (catmap (r \ (: a (<r + base)
                        its (map (it \ (<it = 'op ? ['op (it 1) (it 2) (map fix (it 3))] it)) (r 2))
                        ((peep used a 0 ? [['label (sym a)]]) + its)))
               rows)))
;; llvm-objdump's at&t: a row of x64-disasm at address a -> (text notes), the text past the
;; bytes and the comments after it, oldest first. sym names an address as " <sym+0x..>", or "".
;; a size suffix wherever llvm writes one, hex numbers, an immediate past a byte noted again
(: (od-hex v) ((v < 0 ? "-0x" "0x") + radix (v < 0 ? (0 - v) v) 16)
   ;; an immediate as llvm reads it: a byte, one sign-extended to a wider operand and the
   ;; 64-bit move's are signed, one at the operand's own width unsigned; no size, as decoded
   (od-iv v k w) (? (!(charm? k)) v
                    (k = 8) (v >= 1 << 63 ? (v - (1 << 64)) v)
                    (k = 1 || k < w) v
                    (v < 0 ? (v + (1 << 8 * k)) v))
   ;; past a byte's range: in hex again, at 16, 32 or 64 bits, whichever holds it
   (od-immnote v)
    (? (v <= 255 && v >= -256) ""
       ("imm = 0x" + upper (radix (? (-32768 <= v && v < 32768) (v & 0xFFFF)
                                       (-2147483648 <= v && v < 2147483648) (v & 0xFFFFFFFF)
                                       (v & 0xFFFFFFFFFFFFFFFF)) 16)))
   (od-mem o) (: b (o 1) ix (o 2) sc (o 3) d (o 4)
                 ((d = 0 && (b >= 0 || ix >= 0) ? "" (od-hex d))
                  + (b < 0 && ix < 0 ? ""
                       ("(" + (b < 0 ? "" ("%" + xa-mregname b))
                        + (ix < 0 ? "" (",%" + xa-mregname ix + (sc = 1 && b >= 0 ? "" ("," + show sc))))
                        + ")"))))
   ;; an operand -> (text note)
   (od-op o w nx sym)
    (<o @ 'rg [("%" + xa-regname o) ""]
          'im (od-iv <>o (o 2) w @ v [("$" + od-hex v) (od-immnote v)])
          'ims [("$" + show <>o) ""]
          'lbl [(od-hex <>o + sym <>o) ""]
          'rip [((<>>o - nx) @ d ((d = 0 ? "" (od-hex d)) + "(%rip)")) (od-hex <>>o + sym <>>o)]
          'ind (od-op <>o w nx sym @ r [("*" + <r) <>r])
          'seg (od-op <>>o w nx sym @ r [("%" + show <>o + ":" + <r) ""])
          'mem [(od-mem o) ""]
          'dr [("%dr" + show <>o) ""]
          'st [(#o = 1 ? "%st" ("%st(" + show <>o + ")")) ""]
          [(at-op o) ""])
   (od-mem? ops) (any (o \ <o = 'mem || <o = 'rip || <o = 'seg) ops)
   ;; the string ops' implicit operands, the accumulator at the suffix's width
   (od-strops s)
    (: n #s st (name (snip s 0 (n - 1))) w (s (n - 1) @ 98 1 119 2 108 4 113 8 0)
       a (w > 0 ? ("%" + xa-regname ['rg 0 w]) "") di "%es:(%rdi)" si "(%rsi)"
       (? (w = 0 || n < 4) ()
          (st @ 'movs [si di] 'cmps [di si] 'stos [a di] 'lods [si a] 'scas [di a]
                'ins ["%dx" di] 'outs [si "%dx"] ())))
   ;; an item as llvm names it: an sse compare with a predicate below 8 takes the predicate's
   ;; name (cmpltsd), 66 90 is nop, a selector's source is 16 bits and a stored one 32
   od-cmpp '(eq lt le unord neq nlt nle ord)
   (od-fix n it)
    (: mn (it 1) w (it 2) ops (it 3) rg? (#ops = 2 && <(ops 1) = 'rg)
       (? (elem mn '(cmpss cmpsd cmpps cmppd) && #ops = 3 && <(ops 2) = 'im && 0 <= ops 2 1 < 8)
          ['op (name ("cmp" + show (od-cmpp (ops 2 1)) + snip (show mn) 3 5)) w (snip ops 0 2)]
          (mn = 'xchg && n = 2 && ops = [['rg 0 2] ['rg 0 2]]) ['op 'nop 0 ()]
          (elem mn '(lar lsl) && rg?) ['op mn w [<ops ['rg (ops 1 1) 2]]]
          (elem mn '(sldt str smsw) && #ops = 1 && <<ops = 'rg) ['op mn 0 [['rg (ops 0 1) (w > 2 ? w 4)]]]
          it))
;; a shuffle's lanes, as llvm notes them: mask m picks lane i of source one below n, of
   ;; source two above, -1 a zero; a run from one source is one bracket. "" for no shuffle
   (od-masks d s1 s2 m)
    (: n #m m (s1 = s2 ? (map (i \ i >= n ? (i - n) i) m) m)
       (src i) (? (i < 0) 0 (i < n) 1 2)
       gs (foldl (\ g i (: k (src i)
                          (two? g && k > 0 && <<g = k ? ([k (<g 1 + [(i % n)])] . >g) ([k [(i % n)]] . g))))
                 () m)
       (d + " = " + xa-join "," (map (g \ (<g = 0 ? "zero"
                                          ((<g = 1 ? s1 s2) + "[" + xa-join "," (map show (g 1)) + "]")))
                                   (rev gs))))
   (od-shuf mn ops)
    (: (nm o) (<o = 'rg ? (xa-regname o) "mem") x? (o \ <o = 'rg && (o 2) = 16)
       d (nm <ops) s (two? >ops ? (nm (ops 1)) "") reg2 (two? >ops && x? (ops 1))
       iv (last ops @ o (<o = 'im ? <>o 0))
       (f i) (iv >> 2 * i & 3)
       (lohi n hi) (catmap (i \ [(hi * n // 2 + i) (hi * n // 2 + i + n)]) ^(n // 2))
       up (mn @ 'punpcklbw [16 0] 'punpckhbw [16 1] 'punpcklwd [8 0] 'punpckhwd [8 1]
                'punpckldq [4 0] 'punpckhdq [4 1] 'punpcklqdq [2 0] 'punpckhqdq [2 1]
                'unpcklps [4 0] 'unpckhps [4 1] 'unpcklpd [2 0] 'unpckhpd [2 1] ())
       (? (!(two? ops) || !(x? <ops)) ""
          (two? up) (od-masks d d s (lohi <up (up 1)))
          (mn = 'pshufd) (od-masks d s s (map f ^4))
          (mn = 'pshuflw) (od-masks d s s (map f ^4 + [4 5 6 7]))
          (mn = 'pshufhw) (od-masks d s s ([0 1 2 3] + map (i \ 4 + f i) ^4))
          (mn = 'shufps) (od-masks d d s [(f 0) (f 1) (f 2 + 4) (f 3 + 4)])
          (mn = 'shufpd) (od-masks d d s [(iv & 1) ((iv >> 1 & 1) + 2)])
          (mn = 'psrldq) (od-masks d d d (map (i \ i + iv < 16 ? (i + iv) -1) ^16))
          (mn = 'pslldq) (od-masks d d d (map (i \ i < iv ? -1 (i - iv)) ^16))
          (mn = 'palignr) (od-masks d s d (map (i \ i + iv < 32 ? (i + iv) -1) ^16))
          (mn = 'pblendw) (od-masks d d s (map (i \ iv >> i & 1 ? (i + 8) i) ^8))
          (mn = 'movsd && reg2) (od-masks d d s [2 1])
          (mn = 'movss && reg2) (od-masks d d s [4 1 2 3])
          (mn = 'movq && reg2) (od-masks d s s [0 -1])
          (mn = 'movlhps) (od-masks d d s [0 2])
          (mn = 'movhlps) (od-masks d d s [3 1])
          (mn = 'movhps && !reg2) (od-masks d d s [0 1 4 5])
          (mn = 'movlps && !reg2) (od-masks d d s [4 5 2 3])
          (mn = 'movhpd && !reg2) (od-masks d d s [0 2])
          (mn = 'movlpd && !reg2) (od-masks d d s [2 1])
          ""))
   (od-mn mn w ops)
    (: s (show mn)
       (? (elem mn '(call ret push pop pushf popf)) (s + "q")
          (mn = 'fwait) "wait"
          (elem mn '(fucomip fcomip)) (mn @ 'fucomip "fucompi" "fcompi")
          (elem mn '(lar lsl)) (s + xa-wsfx w)
          (elem mn '(lldt ltr)) (s + "w")
          (elem mn '(sldt str smsw rdfsbase rdgsbase wrfsbase wrgsbase))
           (s + (<<ops = 'rg ? (xa-wsfx (ops 0 2)) "w"))
          (mn = 'mov && any (o \ <o = 'sr) ops)
           (s + (filter (o \ <o = 'rg) ops @ g (two? g ? (xa-wsfx (<g 2)) "w")))
          (elem mn '(jmp)) (s + (any (o \ <o = 'ind) ops ? "q" ""))
          (starts? s "cmov" || mn = 'nop) (s + (w > 0 ? (xa-wsfx w) ""))
          (elem mn '(cvtsi2ss cvtsi2sd)) (s + (od-mem? ops ? (xa-wsfx w) ""))
          (elem mn '(cvtss2si cvtsd2si cvttss2si cvttsd2si)) s
          (mn = 'mov && any (o \ <o = 'im && o 2 = 8) ops) "movabsq"
          (xa-branch? mn || xa-cc? mn) s
          (w > 0 && elem mn xa-sfxable) (s + xa-wsfx w)
          (at-mn mn w ops)))
   (x64-od r a sym)
    (: nx (a + r 1)
       ; at&t reverses the operands, but an xchg of two registers llvm writes as it is encoded
       (one it0) (<it0 = 'dir ? [(it0 1) (xa-join ", " >>it0) ()]
                  (: it (od-fix (r 1) it0) mn (it 1) w (it 2) ops (it 3)
                     os (map (o \ od-op o w nx sym) (mn = 'xchg && all (o \ <o = 'rg) ops ? ops (rev ops)))
                     ms (od-mn mn w ops)
                     [ms (xa-join ", " (two? ops ? (map (o \ <o) os) (od-strops ms)))
                      (filter (n \ n != "") (od-shuf mn ops . map (o \ <>o) os))]))
       ps (map one (r 2))
       ; a prefix before the instruction rides its line, two tabs on, as llvm writes lock and rep
       [(xa-join "\t\t" (map (p \ <p + (<>p = "" ? "" ("\t" + <>p))) ps))
        (<>>(ps (#ps - 1)))]))
;; an ISA's decoder (dec s i pc) -> (n item) walked over s from lo to hi, laid at base: rows
;; (off n item). eight or more zero bytes are one (skip) row, four at a time, as llvm reads them
(: (od-zeros s i hi) (: (go k) (k < hi && s k = 0 ? (go (k + 1)) k) n (go i - i)
                        (n < 8 ? 0 (n & -4)))
   (od-walk dec s base lo hi)
    (: (go i acc) (? (i >= hi) (rev acc)
                     (od-zeros s i hi @ z (z > 0 ? (go (i + z) ([i z ['skip]] . acc))
                                             (dec s i (base + i) @ d (go (i + <d) ([i <d (d 1)] . acc))))))
       (go lo ())))

;; riscv: a word decoded by its row in rv-tab, a half by rvc-tab's (rv64.l), and shown as
;; llvm-objdump writes it. an operand: (x n) (f n) (im v) (mem off n) (amem n) (lbl a) (rm k)
;; (csr n) (fence pred succ)
(: rvd-xn '(zero ra sp gp tp t0 t1 t2 s0 s1 a0 a1 a2 a3 a4 a5 a6 a7 s2 s3 s4 s5 s6 s7 s8 s9 s10 s11
            t3 t4 t5 t6)
   rvd-fn '(ft0 ft1 ft2 ft3 ft4 ft5 ft6 ft7 fs0 fs1 fa0 fa1 fa2 fa3 fa4 fa5 fa6 fa7 fs2 fs3 fs4 fs5
            fs6 fs7 fs8 fs9 fs10 fs11 ft8 ft9 ft10 ft11)
   (rvd-b w hi lo) (w >> lo & ((1 << (hi - lo + 1)) - 1))
   (rvd-sx v n) (v >= 1 << (n - 1) ? (v - (1 << n)) v)
   (rvd-first p l) (? !(two? l) () (p <l) <l (rvd-first p >l))
   ;; the CSRs llvm names on rv64: (number name), or a run (first count prefix from)
   rvd-csrs '((1 fflags) (2 frm) (3 fcsr) (8 vstart) (9 vxsat) (10 vxrm) (15 vcsr) (17 ssp)
               (21 seed) (23 jvt) (256 sstatus) (260 sie) (261 stvec) (262 scounteren)
               (266 senvcfg) (268 4 sstateen 0) (288 scountinhibit) (320 sscratch) (321 sepc)
               (322 scause) (323 stval) (324 sip) (333 stimecmp) (334 sctrctl) (335 sctrstatus)
               (336 siselect) (337 sireg) (338 2 sireg 2) (341 3 sireg 4) (348 stopei)
               (351 sctrdepth) (384 satp) (385 srmcfg) (512 vsstatus) (516 vsie) (517 vstvec)
               (576 vsscratch) (577 vsepc) (578 vscause) (579 vstval) (580 vsip) (589 vstimecmp)
               (590 vsctrctl) (592 vsiselect) (593 vsireg) (594 2 vsireg 2) (597 3 vsireg 4)
               (604 vstopei) (640 vsatp) (768 mstatus) (769 misa) (770 medeleg) (771 mideleg)
               (772 mie) (773 mtvec) (774 mcounteren) (776 mvien) (777 mvip) (778 menvcfg)
               (780 4 mstateen 0) (800 mcountinhibit) (801 mcyclecfg) (802 minstretcfg)
               (803 29 mhpmevent 3) (832 mscratch) (833 mepc) (834 mcause) (835 mtval) (836 mip)
               (842 mtinst) (843 mtval2) (846 mctrctl) (848 miselect) (849 mireg) (850 2 mireg 2)
               (853 3 mireg 4) (860 mtopei) (928 pmpcfg0) (930 pmpcfg2) (932 pmpcfg4) (934 pmpcfg6)
               (936 pmpcfg8) (938 pmpcfg10) (940 pmpcfg12) (942 pmpcfg14) (944 64 pmpaddr 0)
               (1448 scontext) (1536 hstatus) (1538 hedeleg) (1539 hideleg) (1540 hie)
               (1541 htimedelta) (1542 hcounteren) (1543 hgeie) (1544 hvien) (1545 hvictl)
               (1546 henvcfg) (1548 4 hstateen 0) (1603 htval) (1604 hip) (1605 hvip)
               (1606 2 hviprio 1) (1610 htinst) (1664 hgatp) (1704 hcontext) (1856 mnscratch)
               (1857 mnepc) (1858 mncause) (1860 mnstatus) (1863 mseccfg) (1952 tselect)
               (1953 3 tdata 1) (1956 tinfo) (1957 tcontrol) (1960 mcontext) (1962 mscontext)
               (1968 dcsr) (1969 dpc) (1970 2 dscratch 0) (2816 mcycle) (2818 minstret)
               (2819 29 mhpmcounter 3) (3072 cycle) (3073 time) (3074 instret)
               (3075 29 hpmcounter 3) (3104 vl) (3105 vtype) (3106 vlenb) (3488 scountovf)
               (3504 stopi) (3602 hgeip) (3760 vstopi) (3857 mvendorid) (3858 marchid)
               (3859 mimpid) (3860 mhartid) (3861 mconfigptr) (4016 mtopi))
   (rvd-csr n)
    (rvd-first (e \ #e = 2 ? (<e = n) (<e <= n && n < <e + e 1)) rvd-csrs @ e
     (? !(two? e) (od-hex n) (#e = 2) (show (e 1)) (show (e 2) + show (e 3 + n - <e))))
   ;; a table's rows by opcode, in its order
   (rvd-index tab) (foldl (\ t r (r 1 & 127 @ k (pin t k (peep t k () + [r])))) {} tab)
   (rvd-op k w pc)
    (: (b hi lo) (rvd-b w hi lo)
       (k @ 'rd ['x (b 11 7)] 'fd ['f (b 11 7)] 'rs1 ['x (b 19 15)] 'fs1 ['f (b 19 15)]
            'rs2 ['x (b 24 20)] 'fs2 ['f (b 24 20)] 'fs3 ['f (b 31 27)]
            'i12 ['im (rvd-sx (b 31 20) 12)] 'u20 ['im (b 31 12)] 'sh6 ['im (b 25 20)] 'sh5 ['im (b 24 20)]
            'm ['mem (rvd-sx (b 31 20) 12) (b 19 15)]
            'ms ['mem (rvd-sx (b 31 25 << 5 | b 11 7) 12) (b 19 15)]
            'b ['lbl (pc + rvd-sx (b 31 31 << 12 | b 7 7 << 11 | b 30 25 << 5 | b 11 8 << 1) 13)]
            'j ['lbl (pc + rvd-sx (b 31 31 << 20 | b 19 12 << 12 | b 20 20 << 11 | b 30 21 << 1) 21)]
            'am ['amem (b 19 15)] 'rm ['rm (b 14 12)] 'csr ['csr (b 31 20)] 'zimm ['im (b 19 15)]
            ['fence (b 27 24) (b 23 20)]))
   (rvd-cop k h pc)
    (: (b hi lo) (rvd-b h hi lo) p1 (8 + b 9 7) p2 (8 + b 4 2) c6 (b 12 12 << 5 | b 6 2)
       (k @ 'r5 ['x (b 11 7)] 'r5f ['f (b 11 7)] 'r2 ['x (b 6 2)] 'r2f ['f (b 6 2)]
            'p1 ['x p1] 'p2 ['x p2] 'p2f ['f p2] 'z ['x 0] 'ra ['x 1] 'sp ['x 2] 'i0 ['im 0]
            'ci6 ['im (rvd-sx c6 6)] 'cu6 ['im c6] 'clui ['im (rvd-sx c6 6 & 0xfffff)]
            'c16sp ['im (rvd-sx (b 12 12 << 9 | b 4 3 << 7 | b 5 5 << 6 | b 2 2 << 5 | b 6 6 << 4) 10)]
            'c4spn ['im (b 12 11 << 4 | b 10 7 << 6 | b 6 6 << 2 | b 5 5 << 3)]
            'cw ['mem (b 12 10 << 3 | b 6 6 << 2 | b 5 5 << 6) p1]
            'cd ['mem (b 12 10 << 3 | b 6 5 << 6) p1]
            'cwsp ['mem (b 12 12 << 5 | b 6 4 << 2 | b 3 2 << 6) 2]
            'cdsp ['mem (b 12 12 << 5 | b 6 5 << 3 | b 4 2 << 6) 2]
            'cswsp ['mem (b 12 9 << 2 | b 8 7 << 6) 2]
            'csdsp ['mem (b 12 10 << 3 | b 9 7 << 6) 2]
            'r5m ['mem 0 (b 11 7)]
            'cj ['lbl (pc + rvd-sx (b 12 12 << 11 | b 11 11 << 4 | b 10 9 << 8 | b 8 8 << 10
                                    | b 7 7 << 6 | b 6 6 << 7 | b 5 3 << 1 | b 2 2 << 5) 12)]
            ['lbl (pc + rvd-sx (b 12 12 << 8 | b 11 10 << 3 | b 6 5 << 6 | b 4 3 << 1 | b 2 2 << 5) 9)]))
   ;; a C word's item. a hint (rd zero) keeps its C name, c.addi's is c.nop; a reserved
   ;; zero immediate or register is no instruction
   (rvd-c r h pc)
    (: cn (r 0) ops (map (k \ rvd-cop k h pc) (r 3)) rd (h >> 7 & 31) iv (two? ops ? (last ops 1) 0)
       (? (cn = "c.addi" && rd = 0 && iv != 0) ['op (name "c.nop") [(last ops)]]
          (elem cn ["c.li" "c.slli"] && rd = 0) ['op (name cn) [<ops (ops 2)]]
          (cn = "c.lui" && iv = 0) ['dir "<unknown>"]
          (cn = "c.lui" && rd = 0) ['op (name cn) ops]
          (elem cn ["c.addi4spn" "c.addi16sp"] && iv = 0) ['dir "<unknown>"]
          (elem cn ["c.lwsp" "c.ldsp" "c.jr" "c.addiw"] && rd = 0) ['dir "<unknown>"]
          ['op (r 4) ops]))
   ;; how far a word that is no instruction reaches, by its low bits as llvm reads them: 16, 32,
   ;; 48 or 64 bits, 80 to 176 by the second byte's nnn, else a byte; a byte too when it is cut
   (rvd-len s i)
    (: b0 (dc-at s i) b1 (dc-at s (i + 1)) m (#s - i)
       n (? (b0 & 3 != 3) 2 (b0 & 28 != 28) 4 (b0 & 63 = 31) 6 (b0 & 127 = 63) 8
            (m < 2) 1 (b1 >> 4 & 7 = 7) 1 (10 + 2 * (b1 >> 4 & 7)))
       (n <= m ? n 1))
   ;; -> (n item): item (op name ops), or (dir "<unknown>") for no row
   (rvd-dec ix s i pc)
    (: h (dc-at s i | dc-at s (i + 1) << 8) n (rvd-len s i)
       (? (n != 2 && n != 4) [n ['dir "<unknown>"]]
          (h & 3 != 3)
           (rvd-first (r \ h & r 2 = r 1) rvc-tab @ r
            (? (h = 0) [2 ['op 'unimp ()]] !(two? r) [2 ['dir "<unknown>"]] [2 (rvd-c r h pc)]))
          (: w (h | dc-at s (i + 2) << 16 | dc-at s (i + 3) << 24)
             (rvd-first (r \ w & r 2 = r 1) (peep ix (w & 127) ()) @ r
              (!(two? r) ? [4 ['dir "<unknown>"]]
                 (: ks (r 3) aq (<ks = 'aqrl) sf (aq ? (w >> 25 & 3 @ 0 "" 1 ".rl" 2 ".aq" ".aqrl") "")
                    [4 ['op (sf = "" ? <r (name (show <r + sf))) (map (k \ rvd-op k w pc) (aq ? >ks ks))]]))))))
   ;; rows (off n item) for the bytes s laid at base, from lo to hi. a jalr through a register
   ;; an auipc set is told its target as a fourth item field, as llvm tracks them: any other
   ;; write forgets the register, a branch or call forgets all
   (rv-disasm s base lo hi)
    (: rows (od-walk (rvd-dec (rvd-index rv-tab)) s base lo hi)
       (sx v n) (v >= 1 << (n - 1) ? (v - (1 << n)) v)
       (flow? it) (elem (it 1) '(jal jalr beq bne blt bge bltu bgeu))
       (def it) (two? (it 2) && <<(it 2) = 'x && nelem (it 1) '(sb sh sw sd fence) ? (it 2 0 1) -1)
       (step st r) (: it (r 2) a (base + <r)
                      (? (<it != 'op) st (flow? it) {}
                         (it 1 = 'auipc) (pin st (it 2 0 1) (a + (sx (it 2 1 1) 20 << 12)))
                         (def it @ d (d > 0 ? (pin st d ()) st))))
       (mark st r) (: it (r 2)
                      (<it = 'op && it 1 = 'jalr && r 1 = 4 && charm? (peep st (it 2 1 2) ())
                       ? [<r (r 1) ['op 'jalr (it 2) (peep st (it 2 1 2) () + sx (it 2 1 1) 12)]] r))
       (: (go st l acc) (? !(two? l) (rev acc) (go (step st <l) >l (mark st <l . acc)))
          (go {} rows ())))
   ;; llvm's aliases, the operands as written
   (rvd-x? o n) (<o = 'x && o 1 = n)
   (rvd-alias mn ops)
    (: a (dc-at ops 0) b (dc-at ops 1) c (dc-at ops 2) s (show mn)
       (im? o v) (two? o && <o = 'im && o 1 = v)
       (z? o) (two? o && rvd-x? o 0)
       (? (mn = 'addi && z? a && z? b && im? c 0) ['nop ()]
          (mn = 'addi && z? b) ['li [a c]]
          (mn = 'addi && im? c 0) ['mv [a b]]
          (mn = 'addiw && im? c 0) [(name "sext.w") [a b]]
          (mn = 'andi && im? c 255) [(name "zext.b") [a b]]
          (mn = 'xori && im? c -1) ['not [a b]]
          (mn = 'sub && z? b) ['neg [a c]]
          (mn = 'subw && z? b) ['negw [a c]]
          (mn = 'sltiu && im? c 1) ['seqz [a b]]
          (mn = 'sltu && z? b) ['snez [a c]]
          (mn = 'slt && z? c) ['sltz [a b]]
          (mn = 'slt && z? b) ['sgtz [a c]]
          (mn = 'jal && z? a) ['j [b]]
          (mn = 'jal && rvd-x? a 1) ['jal [b]]
          (mn = 'jalr && z? a && b = ['mem 0 1]) ['ret ()]
          (mn = 'jalr && z? a) ['jr [(b 1 = 0 ? ['x (b 2)] b)]]
          (mn = 'jalr && rvd-x? a 1) ['jalr [(b 1 = 0 ? ['x (b 2)] b)]]
          (elem mn '(beq bne blt bge) && z? b)
           [(mn @ 'beq 'beqz 'bne 'bnez 'blt 'bltz 'bgez) [a c]]
          (elem mn '(blt bge) && z? a) [(mn = 'blt ? 'bgtz 'blez) [b c]]
          (starts? s "fsgnj" && a != 0 && b = c)
           [(name (s @ ("fsgnjn" + t) ("fneg" + t) ("fsgnjx" + t) ("fabs" + t) ("fsgnj" + t) ("fmv" + t) s)) [a b]]
          (mn = 'fence && b = 0 && a = ['fence 15 15]) ['fence ()]
          (mn = 'csrrw && z? a && z? c && b 1 = 3072) ['unimp ()]
          (mn = 'csrrs && z? c && elem (b 1) [1 2 3 3072 3073 3074])
           [(b 1 @ 1 'frflags 2 'frrm 3 'frcsr 3072 'rdcycle 3073 'rdtime 'rdinstret) [a]]
          (elem mn '(csrrw csrrwi) && elem (b 1) (mn = 'csrrw ? [1 2 3] [1 2]))
           [(name ((b 1 @ 1 "fsflags" 2 "fsrm" "fscsr") + (mn = 'csrrwi ? "i" ""))) (z? a ? [c] [a c])]
          (mn = 'csrrs && z? c) ['csrr [a b]]
          (elem mn '(csrrw csrrs csrrc csrrwi csrrsi csrrci) && z? a)
           [(name ("csr" + snip s 4 #s)) [b c]]
          (mn = (name "sfence.vma") && z? b) [mn (z? a ? () [a])]
          [mn ops]))
   (rvd-fence v) (v = 0 ? "0" (catmap (i \ v >> (3 - i) & 1 ? (string ("iorw" i)) "") ^4))
   (rvd-opt o sym)
    (<o @ 'x (show (rvd-xn (o 1))) 'f (show (rvd-fn (o 1)))
          'im (od-hex (o 1))
          'mem (od-hex (o 1) + "(" + show (rvd-xn (o 2)) + ")")
          'amem ("(" + show (rvd-xn (o 1)) + ")")
          'lbl (od-hex (o 1) + sym (o 1))
          'rm (show ('(rne rtz rdn rup rmm 5 6 dyn) (o 1)))
          'csr (rvd-csr (o 1))
          'fence (rvd-fence (o 1) + ", " + rvd-fence (o 2))
          (show o))
   ;; a row -> (text notes) as x64-od answers. a dynamic rounding mode is not written, nor
   ;; round-to-nearest on a conversion that is always exact
   rvd-exact (map name ["fcvt.d.s" "fcvt.d.w" "fcvt.d.wu"])
   (rv-od r a sym)
    (: it (r 2) mn (it 1)
       (quiet? o) (<o = 'rm && (o 1 = 7 || o 1 = 0 && elem mn rvd-exact))
       (? (<it = 'skip) ["..." ()] (<it = 'dir) [(it 1) ()]
          (rvd-alias mn (filter (o \ !(quiet? o)) (it 2)) @ m
           [(show <m + (two? (m 1) ? ("\t" + xa-join ", " (map (o \ rvd-opt o sym) (m 1))) "")
             + (3 < #it ? (sym (it 3)) "")) ()]))))

;; a64: a word decoded by its row in a64-tab (a64.l), and shown as llvm-objdump writes it. an
;; operand: (x n) (w n) with 31 zr and 32 sp, (f c n), (v n arr), (el n c i), (im v) (dec v)
;; (sh name v) (ext name v), (cc k), (mem n off) (pre n off) (post n off) (memr n m ext amt s),
;; (lbl a), (sys k), (bar k), (prf k), (raw text), (list n k arr idx)
(: ;; sys's aliases: (op1 crn crm op2 name reg), reg 1 when the op takes xt
   a6d-sysops '((0 7 1 0 ic ialluis 0) (0 7 5 0 ic iallu 0) (3 7 5 1 ic ivau 1)
                (3 7 4 1 dc zva 1) (0 7 6 1 dc ivac 1) (0 7 6 2 dc isw 1) (3 7 10 1 dc cvac 1)
                (0 7 10 2 dc csw 1) (3 7 11 1 dc cvau 1) (3 7 14 1 dc civac 1) (0 7 14 2 dc cisw 1)
                (3 7 12 1 dc cvap 1)
                (0 7 8 0 at s1e1r 1) (0 7 8 1 at s1e1w 1) (0 7 8 2 at s1e0r 1) (0 7 8 3 at s1e0w 1)
                (4 7 8 0 at s1e2r 1) (4 7 8 1 at s1e2w 1) (6 7 8 0 at s1e3r 1) (6 7 8 1 at s1e3w 1)
                (0 8 3 0 tlbi vmalle1is 0) (0 8 7 0 tlbi vmalle1 0) (0 8 3 1 tlbi vae1is 1)
                (0 8 7 1 tlbi vae1 1) (0 8 3 2 tlbi aside1is 1) (0 8 7 2 tlbi aside1 1)
                (0 8 3 3 tlbi vaae1is 1) (0 8 7 3 tlbi vaae1 1) (0 8 3 5 tlbi vale1is 1)
                (0 8 7 5 tlbi vale1 1) (0 8 3 7 tlbi vaale1is 1) (0 8 7 7 tlbi vaale1 1)
                (4 8 7 0 tlbi alle2 0) (4 8 3 0 tlbi alle2is 0) (4 8 7 1 tlbi vae2 1)
                (4 8 3 1 tlbi vae2is 1) (4 8 7 4 tlbi alle1 0) (4 8 3 4 tlbi alle1is 0)
                (4 8 7 6 tlbi vmalls12e1 0) (4 8 3 6 tlbi vmalls12e1is 0) (6 8 7 0 tlbi alle3 0)
                (6 8 3 0 tlbi alle3is 0) (6 8 7 1 tlbi vae3 1) (6 8 3 1 tlbi vae3is 1)
                (4 8 4 1 tlbi ipas2e1 1) (4 8 0 1 tlbi ipas2e1is 1))
   a6d-hints {0 'nop 1 'yield 2 'wfe 3 'wfi 4 'sev 5 'sevl 7 'xpaclri}
   ;; system registers llvm names: (op0 op1 crn crm op2 name)
   a6d-sregs '((3 3 4 2 0 NZCV) (3 3 4 2 1 DAIF) (3 3 4 4 0 FPCR) (3 3 4 4 1 FPSR)
               (3 3 13 0 2 TPIDR_EL0) (3 3 13 0 3 TPIDRRO_EL0) (3 0 13 0 4 TPIDR_EL1)
               (3 3 14 0 0 CNTFRQ_EL0) (3 3 14 0 1 CNTPCT_EL0) (3 3 14 0 2 CNTVCT_EL0)
               (3 3 0 0 1 CTR_EL0) (3 3 0 0 7 DCZID_EL0)
               (3 0 0 0 0 MIDR_EL1) (3 0 0 0 5 MPIDR_EL1) (3 0 0 4 0 ID_AA64PFR0_EL1)
               (3 0 0 4 1 ID_AA64PFR1_EL1) (3 0 0 6 0 ID_AA64ISAR0_EL1) (3 0 0 6 1 ID_AA64ISAR1_EL1)
               (3 0 0 7 0 ID_AA64MMFR0_EL1) (3 0 0 7 1 ID_AA64MMFR1_EL1) (3 0 4 2 2 CurrentEL)
               (3 0 1 0 0 SCTLR_EL1) (3 0 1 0 2 CPACR_EL1) (3 0 2 0 0 TTBR0_EL1) (3 0 2 0 1 TTBR1_EL1)
               (3 0 2 0 2 TCR_EL1) (3 0 4 0 0 SPSR_EL1) (3 0 4 0 1 ELR_EL1) (3 0 4 1 0 SP_EL0)
               (3 0 5 2 0 ESR_EL1) (3 0 6 0 0 FAR_EL1) (3 0 7 4 0 PAR_EL1) (3 0 10 2 0 MAIR_EL1)
               (3 0 12 0 0 VBAR_EL1) (3 0 13 0 1 CONTEXTIDR_EL1) (3 0 14 1 0 CNTKCTL_EL1)
               (3 3 14 2 0 CNTP_TVAL_EL0) (3 3 14 2 1 CNTP_CTL_EL0) (3 3 14 2 2 CNTP_CVAL_EL0)
               (3 3 14 3 0 CNTV_TVAL_EL0) (3 3 14 3 1 CNTV_CTL_EL0) (3 3 14 3 2 CNTV_CVAL_EL0)
               (3 4 1 0 0 SCTLR_EL2) (3 4 1 1 0 HCR_EL2) (3 4 4 0 0 SPSR_EL2) (3 4 4 0 1 ELR_EL2)
               (3 4 14 1 0 CNTHCTL_EL2) (3 4 14 0 3 CNTVOFF_EL2) (2 0 0 2 2 MDSCR_EL1))
   (a6d-b w hi lo) (w >> lo & ((1 << (hi - lo + 1)) - 1))
   (a6d-sx v n) (v >= 1 << (n - 1) ? (v - (1 << n)) v)
   ;; 2^k as a number past the word's reach of & and <<
   (a6d-p2 k) (k 2)
   (a6d-ones k) (a6d-p2 k - 1)
   ;; a logical immediate (DecodeBitMasks) at width wd, or () for a reserved pattern
   (a6d-bimm n immr imms wd)
    (: v (n << 6 | (imms ^ 63))
       len ((: (go k) (k < 0 || (v >> k & 1) = 1 ? k (go (k - 1)))) 6)
       (len < 1 || n = 1 && wd = 32 ? ()
          (: e (1 << len) lv (e - 1) s (imms & lv) r (immr & lv)
             (s = lv ? ()
                (: el (a6d-ones (s + 1))
                   rot (el // a6d-p2 r + (el % a6d-p2 r) * a6d-p2 (e - r))
                   (foldl (\ a i (a + rot * a6d-p2 (e * i))) 0 ^(wd // e)))))))
   ;; an fmov immediate, imm8 -> its text, eight places as llvm writes them
   (a6d-sreg k)
    (: o0 (2 + (k >> 14 & 1)) o1 (k >> 11 & 7) cn (k >> 7 & 15) cm (k >> 3 & 15) o2 (k & 7)
       e (rvd-first (r \ <r = o0 && r 1 = o1 && r 2 = cn && r 3 = cm && r 4 = o2) a6d-sregs)
       (two? e ? (show (e 5))
          ("S" + show o0 + "_" + show o1 + "_C" + show cn + "_C" + show cm + "_" + show o2)))
   (a6d-bar k) (peep {15 "sy" 14 "st" 13 "ld" 11 "ish" 10 "ishst" 9 "ishld" 7 "nsh" 6 "nshst"
                      5 "nshld" 3 "osh" 2 "oshst" 1 "oshld"} k ("#" + od-hex k))
   (a6d-prf k)
    (: t (k >> 3) l (k >> 1 & 3)
       (t = 3 || l = 3 ? ("#" + show k)
          (["pld" "pli" "pst"] t + "l" + show (l + 1) + (k & 1 ? "strm" "keep"))))
   ;; a register: c the class, n its number, w the word
   (a6d-reg c n w)
    (: sf (w >> 31) ft (w >> 22 & 3)
       (c @ 'r [(sf ? 'x 'w) n] 'R [(sf ? 'x 'w) (n = 31 ? 32 n)] 'x ['x n] 'w ['w n]
            'X ['x (n = 31 ? 32 n)] 'W ['w (n = 31 ? 32 n)]
            'f (ft = 2 ? 'bad ['f (ft @ 0 's 1 'd 'h) n])
            'fs ['f (ft & 1 ? 'd 's) n]
            'v ((w >> 22 & 3) << 1 | w >> 30 & 1 @ k (k = 6 ? 'bad ['v n (a6t-arr k)]))
            'vb ['v n (w >> 30 & 1 ? "16b" "8b")]
            'vw (ft = 3 ? 'bad ['v n (["8h" "4s" "2d"] ft)])
            'vn ((w >> 22 & 3) << 1 | w >> 30 & 1 @ k (k > 5 ? 'bad ['v n (a6t-arr k)]))
            'vf (: q (w >> 30 & 1) sz (w >> 22 & 1)
                   (sz && !q ? 'bad ['v n (sz ? "2d" (q ? "4s" "2s"))]))
            ['f c n]))
   ;; an element size by imm5's lowest set bit: 0 b .. 3 d, else -1
   (a6d-esz i5) (? (i5 & 1) 0 (i5 & 2) 1 (i5 & 4) 2 (i5 & 8) 3 -1)
   (a6d-ech k) (['b 'h 's 'd] k)
   ;; the shift-by-immediate element: 0 b .. 3 d by immh, -1 for none
   (a6d-ish w) (w >> 19 & 15 @ h (? (h >= 8) 3 (h >= 4) 2 (h >= 2) 1 (h = 1) 0 -1))
   ;; a kind -> its operands, or 'bad
   (a6d-op k w pc)
    (: (b hi lo) (a6d-b w hi lo) sf (w >> 31) q (b 30 30)
       (fld f) (f @ 'd (b 4 0) 'n (b 9 5) 'm (b 20 16) (b 14 10))
       (one o) (o = 'bad ? 'bad [o])
       (? (two? k && elem <k a6t-rcls) (one (a6d-reg <k (fld (k 1)) w))
          (k @
           'aimm (b 22 22 ? [['im (b 21 10)] ['sh 'lsl 12]] [['im (b 21 10)]])
           'bimm (a6d-bimm (b 22 22) (b 21 16) (b 15 10) (sf ? 64 32) @ v (v = () ? 'bad [['im v]]))
           'imm16 (!sf && b 22 22 ? 'bad
                     (b 22 21 ? [['im (b 20 5)] ['sh 'lsl (16 * b 22 21)]] [['im (b 20 5)]]))
           'immr (b 22 22 != sf || !sf && (b 21 21 || b 15 15) ? 'bad [['dec (b 21 16)]])
           'imms [['dec (b 15 10)]]
           'lsb (b 22 22 != sf || !sf && b 15 15 ? 'bad [['im (b 15 10)]])
           'adr [['lbl (pc + a6d-sx (b 23 5 << 2 | b 30 29) 21)]]
           'adrp [['lbl (pc - pc % 4096 + a6d-sx (b 23 5 << 2 | b 30 29) 21 * 4096)]]
           'l26 [['lbl (pc + 4 * a6d-sx (b 25 0) 26)]]
           'l19 [['lbl (pc + 4 * a6d-sx (b 23 5) 19)]]
           'l14 [['lbl (pc + 4 * a6d-sx (b 18 5) 14)]]
           'tr [[(sf ? 'x 'w) (b 4 0)]]
           'tbit [['im (sf << 5 | b 23 19)]]
           'x16 [['imx (b 20 5)]] 'u16 [['im (b 15 0)]]
           ('v4s f) [['v (fld f) "4s"]] ('v16b f) [['v (fld f) "16b"]]
           'hint7 [['im (b 11 5)]] 'crm (b 11 8 = 15 ? () [['im (b 11 8)]])
           'bar [['bar (b 11 8)]] 'isbo (b 11 8 = 15 ? () [['bar (b 11 8)]])
           'pstate [['pst (b 18 16) (b 7 5)] ['im (b 11 8)]]
           'sysop [['raw ("#" + show (b 18 16))] ['raw ("c" + show (b 15 12))] ['raw ("c" + show (b 11 8))]
                   ['raw ("#" + show (b 7 5))] ['x (b 4 0)]]
           'sysl [['raw ("#" + show (b 18 16))] ['raw ("c" + show (b 15 12))] ['raw ("c" + show (b 11 8))]
                  ['raw ("#" + show (b 7 5))]]
           'sreg [['sys (b 19 5)]]
           'prf [['prf (b 4 0)]]
           'lsh (!sf && b 15 15 ? 'bad
                   (b 23 22 = 0 && b 15 10 = 0 ? () [['sh (a6t-shn (b 23 22)) (b 15 10)]]))
           'ash (b 23 22 = 3 || !sf && b 15 15 ? 'bad
                   (b 23 22 = 0 && b 15 10 = 0 ? () [['sh (a6t-shn (b 23 22)) (b 15 10)]]))
           'xm [[(sf && b 14 13 = 3 ? 'x 'w) (b 20 16)]]
           'ext (: o (b 15 13) i (b 12 10)
                   sp (b 9 5 = 31 || !(b 29 29) && b 4 0 = 31)
                   (? (i > 4) 'bad
                      (sp && o = (sf ? 3 2)) (i = 0 ? () [['sh 'lsl i]])
                      [['ext (a6t-extn o) i]]))
           'cond [['cc (b 15 12)]] 'nzcv [['im (b 3 0)]] 'ccimm [['im (b 20 16)]]
           ('mu s) [['mem (b 9 5) (b 21 10 * s)]]
           'mo [['mem (b 9 5) (a6d-sx (b 20 12) 9)]]
           'mpost [['post (b 9 5) (a6d-sx (b 20 12) 9)]]
           'mpre [['pre (b 9 5) (a6d-sx (b 20 12) 9)]]
           ('mr s) (: o (b 15 13)
                      (o & 2 = 0 ? 'bad
                         [['memr (b 9 5) [(o & 1 ? 'x 'w) (b 20 16)] (o = 3 ? 'lsl (a6t-extn o))
                           (b 12 12 ? (s @ 1 0 2 1 4 2 8 3 4) 0) (b 12 12)]]))
           ('mp s) [['mem (b 9 5) (a6d-sx (b 21 15) 7 * s)]]
           ('mpp s) [['post (b 9 5) (a6d-sx (b 21 15) 7 * s)]]
           ('mpr s) [['pre (b 9 5) (a6d-sx (b 21 15) 7 * s)]]
           'm0 [['mem (b 9 5) 0]]
           'fz [['raw "#0.0"]] 'z0 [['raw "#0"]]
           'fimm [['raw (a6t-fimm (b 20 13))]]
           'modi (a6d-modi w)
           'shr (a6d-ish w @ e (e < 0 ? 'bad [['im ((16 << e) - b 22 16)]]))
           'shl (a6d-ish w @ e (e < 0 ? 'bad [['im (b 22 16 - (8 << e))]]))
           ('vi f) (a6d-ish w @ e (e < 0 || e = 3 && !q ? 'bad [['v (fld f) (a6t-arr (e << 1 | q))]]))
           ('vin f) (a6d-ish w @ e (e < 0 || e = 3 ? 'bad [['v (fld f) (a6t-arr (e << 1 | q))]]))
           ('viw f) (a6d-ish w @ e (e < 0 || e = 3 ? 'bad [['v (fld f) (["8h" "4s" "2d"] e)]]))
           'fbits (!sf && !(b 15 15) ? 'bad [['im (64 - b 15 10)]])
           'vsz (b 23 22 @ s (s = 3 || s = 2 && !q ? 'bad [['f (a6d-ech s) (b 4 0)]]))
           'vszw (b 23 22 @ s (s = 3 || s = 2 && !q ? 'bad [['f (a6d-ech (s + 1)) (b 4 0)]]))
           'vpsz [['f (b 22 22 ? 'd 's) (b 4 0)]]
           'vp [['v (b 9 5) (b 22 22 ? "2d" "2s")]]
           'v2d [['v (b 9 5) "2d"]]
           'v4sd [['v (b 4 0) "4s"]] 'v4sn [['v (b 9 5) "4s"]]
           'vd1n [['el (b 9 5) 'd 1]] 'vd1d [['el (b 4 0) 'd 1]]
           ('v5 f) (a6d-esz (b 20 16) @ e (e < 0 || e = 3 && !q ? 'bad [['v (fld f) (a6t-arr (e << 1 | q))]]))
           ('e5 f) (a6d-esz (b 20 16) @ e (e < 0 ? 'bad [['el (fld f) (a6d-ech e) (b 20 16 >> (e + 1))]]))
           'g5 (a6d-esz (b 20 16) @ e (e < 0 ? 'bad [[(e = 3 ? 'x 'w) (b 9 5)]]))
           'e4 (a6d-esz (b 20 16) @ e (e < 0 ? 'bad [['el (b 9 5) (a6d-ech e) (b 14 11 >> e)]]))
           's5 (a6d-esz (b 20 16) @ e (e < 0 ? 'bad [['f (a6d-ech e) (b 4 0)]]))
           'tlist [['list (b 9 5) (b 14 13 + 1) "16b" -1]]
           'exti (!q && b 14 14 ? 'bad [['im (b 14 11)]])
           'fel (b 22 22 && b 21 21 ? 'bad
                   [['el (b 20 16) (b 22 22 ? 'd 's) (b 22 22 ? (b 11 11) (b 11 11 << 1 | b 21 21))]])
           'lane (: o (b 15 13) s (b 12 12) z (b 11 10)
                    (? (o = 0) [['list (b 4 0) 1 "b" (q << 3 | s << 2 | z)]]
                       (o = 2) [['list (b 4 0) 1 "h" (q << 2 | s << 1 | z >> 1)]]
                       (z = 0) [['list (b 4 0) 1 "s" (q << 1 | s)]]
                       [['list (b 4 0) 1 "d" q]]))
           'list1 ((w >> 10 & 3) << 1 | q @ k (k = 6 ? 'bad [['list (b 4 0) 1 (a6t-arr k) -1]]))
           'bad)))
   ;; a modified immediate: the register, the value and its shift, by cmode and op
   (a6d-modi w)
    (: q (w >> 30 & 1) op (w >> 29 & 1) cm (w >> 12 & 15) d (w & 31)
       i8 ((w >> 16 & 7) << 5 | w >> 5 & 31)
       (? (cm < 8) (catall [[['v d (q ? "4s" "2s")] ['im i8]] (cm >> 1 ? [['sh 'lsl (8 * (cm >> 1))]] ())])
          (cm < 12) (catall [[['v d (q ? "8h" "4h")] ['im i8]] (cm >> 1 & 1 ? [['sh 'lsl 8]] ())])
          (cm < 14) [['v d (q ? "4s" "2s")] ['im i8] ['sh 'msl (cm & 1 ? 16 8)]]
          (cm = 14 && !op) [['v d (q ? "16b" "8b")] ['im i8]]
          (cm = 15 && !op) [['v d (q ? "4s" "2s")] ['raw (a6t-fimm i8)]]
          (cm = 14)
           (: v (foldl (\ a i (a + (i8 >> i & 1) * 255 * a6d-p2 (8 * i))) 0 ^8)
              [(q ? ['v d "2d"] ['f 'd d]) ['m64 v]])
          (q ? [['v d "2d"] ['raw (a6t-fimm i8)]] 'bad)))
   ;; the rows by their top bits; a row whose match leaves a bit free lists under each
   (a6d-index tab)
    (foldl (\ t r (: m (r 2 >> 25) v (r 1 >> 25)
                     (foldl (\ t k (k & m = v ? (pin t k (peep t k () + [r])) t)) t ^128)))
           {} tab)
   ;; -> (n item): (op name ops w), or (dir "<unknown>")
   (a6d-dec ix s i pc)
    (: w (dc-le s i 4)
       (go l) (? !(two? l) [4 ['dir "<unknown>"]]
                 (w & <l 2 != <l 1) (go >l)
                 (: r <l ops (map (k \ a6d-op k w pc) (r 3))
                    (elem 'bad ops ? (go >l)
                       [4 ['op <r (catall ops) w (r 3)]])))
       (#s - i < 4 ? [(#s - i) ['dir "<unknown>"]] (go (peep ix (w >> 25) ()))))
   (a64-disasm s base lo hi) (od-walk (a6d-dec (a6d-index a64-tab)) s base lo hi)
   ;; llvm's aliases, the operands as written -> (name ops note)
   (a6d-zr? o) (two? o && elem <o '(x w) && o 1 = 31)
   (a6d-sp? o) (two? o && elem <o '(x w) && o 1 = 32)
   (a6d-inv k) (k ^ 1)
   (a6d-mov v wd) (: sv (wd = 32 && v >= a6d-p2 31 ? (v - a6d-p2 32) (v >= a6d-p2 63 ? (v - a6d-p2 64) v))
                     [[['im sv]] ("// =" + show sv)])
   ;; movz shapes: v at shift sh, by 16 within the width
   (a6d-movz? v sh wd) (: m (a6d-p2 wd)
                          (: u (v % m) (u = 0 && sh != 0 ? 0 (u % a6d-p2 sh = 0 && u // a6d-p2 sh < 65536))))
   (a6d-movn? v sh wd) (: m (a6d-p2 wd) (a6d-movz? v sh wd ? 0 (a6d-movz? (m - 1 - v % m) sh wd)))
   (a6d-movw? v wd) (any (k \ a6d-movz? v (16 * k) wd || a6d-movn? v (16 * k) wd) ^(wd // 16))
   (a6d-alias mn ops w)
    (: a (dc-at ops 0) b (dc-at ops 1) c (dc-at ops 2) d (dc-at ops 3) e (dc-at ops 4)
       sf (w >> 31) wd (sf ? 64 32) s (show mn)
       (fld hi lo) (a6d-b w hi lo)
       (? (elem mn '(movz movn))
           (: hw (fld 22 21) i (fld 20 5) m (a6d-p2 wd)
              v (mn = 'movz ? (i * a6d-p2 (16 * hw)) (m - 1 - i * a6d-p2 (16 * hw)))
              ok (mn = 'movz ? (a6d-movz? v (16 * hw) wd) (a6d-movn? v (16 * hw) wd))
              (ok ? (a6d-mov v wd @ r ['mov (a . <r) (r 1)]) [mn ops ()]))
          (mn = 'orr && fld 28 23 = 0x24 && a6d-zr? b && !(a6d-movw? (c 1) wd))
           (a6d-mov (c 1) wd @ r ['mov (a . <r) (r 1)])
          (mn = 'orr && fld 28 24 = 0x0a && a6d-zr? b && #ops = 3) ['mov [a c] ()]
          (mn = 'orn && fld 28 24 = 0x0a && a6d-zr? b) ['mvn (a . >>ops) ()]
          (elem mn '(add sub adds subs) && fld 28 24 = 0x11 && fld 22 22)
           (: n ("// =" + od-hex (fld 21 10 * 4096))
              (? (mn = 'subs && a6d-zr? a) ['cmp >ops n] (mn = 'adds && a6d-zr? a) ['cmn >ops n] [mn ops n]))
          (mn = 'add && fld 28 24 = 0x11 && fld 21 10 = 0 && (a6d-sp? a || a6d-sp? b)) ['mov [a b] ()]
          (elem mn '(subs adds) && a6d-zr? a) [(mn = 'subs ? 'cmp 'cmn) >ops ()]
          (mn = 'ands && a6d-zr? a) ['tst >ops ()]
          (elem mn '(sub subs) && fld 28 24 = 0x0b && fld 21 21 = 0 && a6d-zr? b)
           [(mn = 'sub ? 'neg 'negs) (a . >>ops) ()]
          (elem mn '(sbc sbcs) && a6d-zr? b) [(mn = 'sbc ? 'ngc 'ngcs) [a c] ()]
          (elem mn '(lslv lsrv asrv rorv)) [(name (snip s 0 3)) ops ()]
          (elem mn '(sbfm ubfm))
           (: r (c 1) t (d 1) sg (mn = 'sbfm) ww (sf ? 64 32)
              (wr o) ['w (o 1)]
              (? (r = 0 && (t = 7 || t = 15) && (sg || !sf))
                  [(name ((sg ? "s" "u") + (t = 7 ? "xtb" "xth"))) [a (wr b)] ()]
                 (r = 0 && t = 31 && sf && sg) ['sxtw [a (wr b)] ()]
                 (!sg && t != ww - 1 && t + 1 = r) ['lsl [a b ['dec (ww - 1 - t)]] ()]
                 (t = ww - 1) [(sg ? 'asr 'lsr) [a b ['dec r]] ()]
                 (r > t) [(sg ? 'sbfiz 'ubfiz) [a b ['dec (ww - r)] ['dec (t + 1)]] ()]
                 [(sg ? 'sbfx 'ubfx) [a b ['dec r] ['dec (t - r + 1)]] ()]))
          (mn = 'bfm)
           (: r (c 1) t (d 1) ww (sf ? 64 32)
              (? (a6d-zr? b && (r = 0 || t < r)) ['bfc [a ['dec ((ww - r) % ww)] ['dec (t + 1)]] ()]
                 (t < r) ['bfi [a b ['dec ((ww - r) % ww)] ['dec (t + 1)]] ()]
                 ['bfxil [a b ['dec r] ['dec (t - r + 1)]] ()]))
          (mn = 'extr && b = c) ['ror [a b d] ()]
          (elem mn '(csinc csinv) && a6d-zr? b && a6d-zr? c && d 1 < 14)
           [(mn = 'csinc ? 'cset 'csetm) [a ['cc (a6d-inv (d 1))]] ()]
          (elem mn '(csinc csinv csneg) && b = c && d 1 < 14)
           [(mn @ 'csinc 'cinc 'csinv 'cinv 'cneg) [a b ['cc (a6d-inv (d 1))]] ()]
          (elem mn '(madd msub smaddl smsubl umaddl umsubl) && a6d-zr? d)
           [(mn @ 'madd 'mul 'msub 'mneg 'smaddl 'smull 'smsubl 'smnegl 'umaddl 'umull 'umnegl)
            [a b c] ()]
          (mn = 'hint && nom? (peep a6d-hints (a 1) ()))
           [(peep a6d-hints (a 1) ()) () ()]
          (mn = 'ret && a = ['x 30]) ['ret () ()]
          (mn = 'sys) (a6d-sysa w ops)
          (fld 29 24 = 0x38 && fld 21 21 = 1 && fld 11 10 = 0 && fld 15 15 = 0 && fld 23 23 = 0 && a6d-zr? b)
           [(name ("st" + snip s 2 #s)) [a c] ()]
          (mn = 'umov && elem (b 2) '(s d)) ['mov ops ()]
          (mn = 'ins) ['mov ops ()]
          (mn = 'dup && fld 31 24 = 0x5e) ['mov ops ()]
          (mn = 'orr && fld 28 21 = 0x75 && b = c) ['mov [a b] ()]
          (mn = 'not) ['mvn ops ()]
          [mn ops ()]))
   (a6d-sysa w ops)
    (: (b hi lo) (a6d-b w hi lo) rt (b 4 0)
       e (rvd-first (r \ <r = b 18 16 && r 1 = b 15 12 && r 2 = b 11 8 && r 3 = b 7 5) a6d-sysops)
       (? !(two? e) ['sys ops ()]
          (e 6 = 1) [(e 4) [['raw (show (e 5))] ['x rt]] ()]
          (rt = 31) [(e 4) [['raw (show (e 5))]] ()]
          ['sys ops ()]))
   ;; a name with 2 when the row widens or narrows the upper half
   (a6d-two mn ks w) (w >> 30 & 1 && w >> 28 & 1 = 0 && any (k \ two? k && elem <k '(vw viw)) ks
                      && !(elem mn '(ins mov)) ? (name (show mn + "2")) mn)
   (a6d-r o) (: n (o 1)
              (<o = 'x ? (? (n = 31) "xzr" (n = 32) "sp" ("x" + show n))
                 (? (n = 31) "wzr" (n = 32) "wsp" ("w" + show n))))
   (a6d-ix i) (i < 0 ? "" ("[" + show i + "]"))
   (a6d-opt o sym)
    (<o @ 'x (a6d-r o) 'w (a6d-r o)
          'f (show (o 1) + show (o 2))
          'v ("v" + show (o 1) + "." + o 2)
          'el ("v" + show (o 1) + "." + show (o 2) + "[" + show (o 3) + "]")
          'im ("#" + od-hex (o 1)) 'dec ("#" + show (o 1))
          'imx (o 1 = 0 ? "#0" ("#" + od-hex (o 1)))
          'm64 (o 1 = 0 ? "#0000000000000000"
                  (radix (o 1) 16 @ h ("#0x" + catall (map (_ \ "0") ^(max 0 (14 - #h))) + h)))
          'sh (show (o 1) + " #" + show (o 2))
          'ext (show (o 1) + (o 2 = 0 ? "" (" #" + show (o 2))))
          'cc (show (a6t-cc (o 1)))
          'mem ("[" + a6d-r ['x (o 1 = 31 ? 32 (o 1))] + (o 2 = 0 ? "" (", #" + od-hex (o 2))) + "]")
          'pre ("[" + a6d-r ['x (o 1 = 31 ? 32 (o 1))] + ", #" + od-hex (o 2) + "]!")
          'post ("[" + a6d-r ['x (o 1 = 31 ? 32 (o 1))] + "], #" + od-hex (o 2))
          'memr ("[" + a6d-r ['x (o 1 = 31 ? 32 (o 1))] + ", " + a6d-r (o 2)
                 + (o 5 ? (", " + show (o 3) + " #" + show (o 4)) (o 3 = 'lsl ? "" (", " + show (o 3)))) + "]")
          'lbl (od-hex (o 1) + sym (o 1))
          'sys (a6d-sreg (o 1)) 'bar (a6d-bar (o 1)) 'prf (a6d-prf (o 1))
          'pst (peep {5 "SPSel" 30 "DAIFSet" 31 "DAIFClr" 3 "UAO" 4 "PAN"} (o 1 << 3 | o 2)
                     ("#" + show (o 1 << 3 | o 2)))
          'list ("{ " + xa-join ", " (map (i \ "v" + show ((o 1 + i) % 32) + "." + o 3) ^(o 2)) + " }"
                 + a6d-ix (o 4))
          'raw (o 1)
          (show o))
   ;; a row -> (text notes) as x64-od answers; a note pads to the fortieth column
   (a64-od r a sym)
    (: it (r 2)
       (? (<it = 'skip) ["..." ()] (<it = 'dir) [(it 1) ()]
          (a6d-alias (it 1) (it 2) (it 3) @ m
           (: mn (show (a6d-two <m (it 4) (it 3)))
              ops (xa-join ", " (map (o \ a6d-opt o sym) (m 1)))
              t (mn + (two? (m 1) ? ("\t" + ops) ""))
              col ((8 + #mn) // 8 * 8 + 8 + #ops)
              [(m 2 = () ? t (t + catall (map (_ \ " ") ^(max 1 (40 - col))) + m 2)) ()]))))

   ;; a $d region as llvm shows it: a word at a time, a byte at the tail
   (a6d-hx v n) (radix v 16 @ h (catall (map (_ \ "0") ^(max 0 (n - #h))) + h))
   (a6d-data s i pc)
    (#s - i >= 4 ? [4 ['dir (".word\t0x" + a6d-hx (dc-le s i 4) 8) 'data]]
       [1 ['dir (".byte\t0x" + a6d-hx (s i) 2) 'data]])
   (a64-data s base lo hi) (od-walk a6d-data s base lo hi)
   ;; a64-tab both ways: a row's word from its operands, and the word decodes back to them
   (a64-lay r ops pc)
    (a64-fit r ops pc @ w
       (w = () ? () (map (k \ a6d-op k w pc) (r 3) @ back (elem 'bad back || catall back != ops ? () w))))
   ;; an instruction by name from the decoder's operands: the first of its rows that lays them
   (a64-enc mn ops pc)
    (: (go l) (? !(two? l) (scare 'a64-enc [mn ops]) (a64-lay <l ops pc @ w (w = () ? (go >l) w)))
       (go (peep a64-byname mn ()))))
) ; module 'holo
