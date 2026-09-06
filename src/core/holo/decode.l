; decode -- x86-64 machine code back to the parsed instruction of src/core/holo/dialect.l: the
; bytes-to-text half of the x86 lens. what as.l and x64.l emit, what gcc's output uses, and the
; kernel's system lane all read back; anything else lands as a `.byte` item, one byte at a time,
; so a stream never scares and always resynchronises. the showers then print either dialect.
;
;   (x64-decode s i)         one instruction at byte offset i of the string s -> (n . items):
;                            its length and its items (one, or a prefix item -- lock, rep -- first)
;   (x64-disasm s base)      the whole string -> ((off n items) ..), a branch or rip target an
;                            absolute number (base + where it points)
;   (x64-relabel rows)       the same rows with every in-range target a symbol L<addr> and a
;                            (label L<addr>) row laid where it lands -- what as.l re-encodes
;
; a decoded operand is the value's: (rg enc w), (im n), (mem base index scale disp), a rip form
; (rip () disp) with no symbol, a branch target (lbl n) as a number, a memory operand under a
; segment override as (seg fs o). the operand size w is the instruction's, 0 where the value
; keeps none (branches, the SSE lane with no GPR) -- the same reading the text readers make, so
; decode and att-read agree on the bytes as.l lays (test/holo/decode.l holds both laws).

(module 'holo
(: ;; --- bytes and fields: reads past the end answer 0, and `fin` refuses the instruction ---
   (dc-at s k) (k < #s ? (s k) 0)
   (dc-le s i n) ((: (g k a) (? (k < n) (g (k + 1) (a + (dc-at s (i + k) << (8 * k)))) a)) 0 0)
   (dc-sx v n) (: m (1 << (8 * n - 1)) (v >= m ? (v - (m << 1)) v))
   (dc-imm s i n) (dc-sx (dc-le s i n) n)                     ; a signed immediate of n bytes
   dc-hexd "0123456789abcdef"
   (dc-hex2 b) ("0x" + string (dc-hexd (b >> 4)) + string (dc-hexd (b & 15)))
   (dc-byte b) ['dir ".byte" (dc-hex2 b)]
   dc-conds '(o no b ae e ne be a s ns p np l ge le g)      ; the sixteen, by low nibble
   (dc-ccname pre k) (name (pre + show (dc-conds k)))
   ;; a register operand: n the 4-bit number, w its width; a byte register 4..7 without a REX
   ;; is ah..bh, which the value keeps 16 above (dialect.l)
   (dc-reg n w rexp) (? (w = 1 && !rexp && 4 <= n <= 7) ['rg (n + 16) 1] ['rg n w])
   dc-alu  '(add or adc sbb and sub xor cmp)
   dc-grp2 '(rol ror rcl rcr shl shr shl sar)
   dc-grp3 '(test test not neg mul imul div idiv)
   ;; the SSE2 integer lane, 66 0F xx, xmm <- xmm/m128
   dc-p66 (tabof
        [(96 . 'punpcklbw) (97 . 'punpcklwd) (98 . 'punpckldq) (99 . 'packsswb)
          (100 . 'pcmpgtb) (101 . 'pcmpgtw) (102 . 'pcmpgtd) (103 . 'packuswb)
          (104 . 'punpckhbw) (105 . 'punpckhwd) (106 . 'punpckhdq) (107 . 'packssdw)
          (108 . 'punpcklqdq) (109 . 'punpckhqdq) (116 . 'pcmpeqb) (117 . 'pcmpeqw) (118 . 'pcmpeqd)
          (212 . 'paddq) (213 . 'pmullw) (218 . 'pminub) (219 . 'pand) (222 . 'pmaxub) (223 . 'pandn)
          (224 . 'pavgb) (227 . 'pavgw) (228 . 'pmulhuw) (229 . 'pmulhw) (234 . 'pminsw) (235 . 'por)
          (238 . 'pmaxsw) (239 . 'pxor) (244 . 'pmuludq) (245 . 'pmaddwd)
          (248 . 'psubb) (249 . 'psubw) (250 . 'psubd) (251 . 'psubq)
          (252 . 'paddb) (253 . 'paddw) (254 . 'paddd)])
   ;; ..and its shifts by an immediate: 66 0F 71/72/73 /digit ib
   dc-pshift (tabof [(113 . '(() () psrlw () psraw () psllw ())) (114 . '(() () psrld () psrad () pslld ()))
                     (115 . '(() () psrlq psrldq () () psllq pslldq))])
   (pf p k) (peep p k 0)
   ;; the value's w: the GPR operand's width, else 0 (the SSE lane, branches)
   (dc-vw wr wm) (? (wr < 16) wr (wm < 16) wm 0)

   ;; --- modrm at k, the register field at width wr and the r/m at wm (16 = xmm): ---
   ;;     -> [k2 reg-operand rm-operand digit], a memory operand wrapped by any segment override
   (dc-modrm s k p wr wm)
    (: m (dc-at s k) md (m >> 6) dg ((m >> 3) & 7) rm (m & 7)
       rexp (pf p 'rex) bx (pf p 'b) xx (pf p 'x)
       reg (dc-reg (dg | (pf p 'r << 3)) wr rexp)
       (wrap o) (nom? (pf p 'seg) ? ['seg (pf p 'seg) o] o)
       (? (md = 3) [(k + 1) reg (dc-reg (rm | (bx << 3)) wm rexp) dg]
          (md = 0 && rm = 5) [(k + 5) reg (wrap ['rip () (dc-imm s (k + 1) 4)]) dg]
          (rm = 4)                                                    ; a SIB
          (: sb (dc-at s (k + 1))
             ix (((sb >> 3) & 7) | (xx << 3)) ix2 (ix = 4 ? -1 ix)
             sc (ix2 < 0 ? 1 (1 << (sb >> 6)))
             nobase (md = 0 && (sb & 7) = 5)
             bs (nobase ? -1 ((sb & 7) | (bx << 3)))
             dn (? nobase 4 (md = 1) 1 (md = 2) 4 0)
             d (dn = 0 ? 0 (dc-imm s (k + 2) dn))
             [(k + 2 + dn) reg (wrap ['mem bs ix2 sc d]) dg])
          (: dn (md @ 1 1 2 4 0) d (dn = 0 ? 0 (dc-imm s (k + 1) dn))
             [(k + 1 + dn) reg (wrap ['mem (rm | (bx << 3)) -1 1 d]) dg])))

   ;; --- the prefixes, then the opcode ---
   (x64-decode s i)
    (: n #s
       (go j p)
         (? (j >= n) (1 . [(dc-byte (dc-at s i))])
            (: c (s j)
               (c @ 102 (go (j + 1) (pin p 'opsz 1))
                    243 (go (j + 1) (pin p 'rep 1))
                    242 (go (j + 1) (pin p 'repne 1))
                    240 (go (j + 1) (pin p 'lock 1))
                    100 (go (j + 1) (pin p 'seg 'fs))
                    101 (go (j + 1) (pin p 'seg 'gs))
                    (38 || 46 || 54 || 62) (go (j + 1) p)   ; es/cs/ss/ds: null in long mode
                    (c && 64 <= c <= 79) (go (j + 1) (pins p 'rex 1 'w ((c >> 3) & 1) 'r ((c >> 2) & 1) 'x ((c >> 1) & 1) 'b (c & 1)))
                    (dc-op s i j p))))
       (go i {}))

   ;; the prefix items an instruction carries: lock always, rep/repne unless the opcode ate them
   (dc-pre p ate) ((pf p 'lock ? [['op 'lock 0 ()]] ())
                   + (pf p 'rep && !ate ? [['op 'rep 0 ()]] ())
                   + (pf p 'repne && !ate ? [['op 'repne 0 ()]] ()))

   (dc-op s i j p)
    (: n #s c (dc-at s j) k (j + 1)
       w (? (pf p 'w) 8 (pf p 'opsz) 2 4)                    ; the operand size: REX.W outranks 66
       w8 (pf p 'opsz ? 2 8)                                 ; push/pop: 64-bit unless 66
       rexp (pf p 'rex)
       (rl c) ((c & 7) | (pf p 'b << 3))                      ; a register in the opcode's low bits
       (fin k2 items) (k2 > n ? (1 . [(dc-byte c)]) ((k2 - i) . (dc-pre p 0 + items)))
       (fin1 k2 items) (k2 > n ? (1 . [(dc-byte c)]) ((k2 - i) . (dc-pre p 1 + items)))   ; the opcode ate rep
       (op1 mn w ops) ['op mn w ops]
       (nil mn) (fin k [(op1 mn 0 ())])
       ;; the two modrm faces: ge is reg <- r/m (dst the reg field), eg is r/m <- reg
       (ge mn wr wm) (: r (dc-modrm s k p wr wm) (fin (r 0) [(op1 mn (dc-vw wr wm) [(r 1) (r 2)])]))
       (eg mn wm wr) (: r (dc-modrm s k p wr wm) (fin (r 0) [(op1 mn (dc-vw wr wm) [(r 2) (r 1)])]))
       ;; r/m with a digit: the ALU immediates, the shifts, the unary groups
       (grp1 wm isz) (: r (dc-modrm s k p wm wm) (fin (r 0 + isz) [(op1 (dc-alu (r 3)) wm [(r 2) ['im (dc-imm s (r 0) isz)]])]))
       (grp2 wm cnt) (: r (dc-modrm s k p wm wm) mn (dc-grp2 (r 3))
                        (cnt @ 'ib (fin (r 0 + 1) [(op1 mn wm [(r 2) ['im (dc-imm s (r 0) 1)]])])
                             'cl (fin (r 0) [(op1 mn wm [(r 2) ['rg 1 1]])])
                             (fin (r 0) [(op1 mn wm [(r 2)])])))
       (grp3 wm) (: r (dc-modrm s k p wm wm) dg (r 3) mn (dc-grp3 dg)
                    (? (dg < 2) (: isz (wm @ 1 1 2 2 4) (fin (r 0 + isz) [(op1 'test wm [(r 2) ['im (dc-imm s (r 0) isz)]])]))
                       (fin (r 0) [(op1 mn wm [(r 2)])])))
       (rel isz mn) (: t (k + isz + dc-imm s k isz) (fin (k + isz) [(op1 mn 0 [['lbl t]])]))
       (c @ ;; the ALU block 00-3F: the op in bits 5..3, the form in bits 2..0
          (c && c < 64 && (c & 7) < 6)
           (: mn (dc-alu (c >> 3)) f (c & 7)
              (f @ 0 (eg mn 1 1) 1 (eg mn w w) 2 (ge mn 1 1) 3 (ge mn w w)
                 4 (fin (k + 1) [(op1 mn 1 [['rg 0 1] ['im (dc-imm s k 1)]])])
                 (: isz (w = 2 ? 2 4) (fin (k + isz) [(op1 mn w [['rg 0 w] ['im (dc-imm s k isz)]])]))))
          (c && 80 <= c <= 87) (fin k [(op1 'push w8 [['rg (rl c) w8]])])
          (c && 88 <= c <= 95) (fin k [(op1 'pop w8 [['rg (rl c) w8]])])
          99 (: r (dc-modrm s k p w 4) (fin (r 0) [(op1 'movsl w [(r 1) (r 2)])]))     ; movsxd
          104 (fin (k + 4) [(op1 'push 8 [['im (dc-imm s k 4)]])])
          106 (fin (k + 1) [(op1 'push 8 [['im (dc-imm s k 1)]])])
          (105 || 107)                                                                ; imul r, r/m, imm
           (: r (dc-modrm s k p w w) isz (c = 105 ? (w = 2 ? 2 4) 1)
              (fin (r 0 + isz) [(op1 'imul w [(r 1) (r 2) ['im (dc-imm s (r 0) isz)]])]))
          (c && 112 <= c <= 127) (rel 1 (dc-ccname "j" (c & 15)))
          128 (grp1 1 1)  129 (grp1 w (w = 2 ? 2 4))  131 (grp1 w 1)
          132 (eg 'test 1 1)  133 (eg 'test w w)
          134 (eg 'xchg 1 1)  135 (eg 'xchg w w)
          136 (eg 'mov 1 1)  137 (eg 'mov w w)  138 (ge 'mov 1 1)  139 (ge 'mov w w)
          141 (ge 'lea w w)
          143 (: r (dc-modrm s k p w8 w8) (fin (r 0) [(op1 'pop w8 [(r 2)])]))
          144 (? (pf p 'rep) (fin1 k [(op1 'pause 0 ())])
                       (pf p 'b) (fin k [(op1 'xchg w [['rg 8 w] ['rg 0 w]])])
                       (pf p 'opsz) (fin k [(op1 'xchg 2 [['rg 0 2] ['rg 0 2]])])      ; 66 90: the two-byte nop's spelling
                       (nil 'nop))
          (c && 145 <= c <= 151) (fin k [(op1 'xchg w [['rg (rl c) w] ['rg 0 w]])])
          152 (nil (w @ 2 'cbw 8 'cdqe 'cwde))
          153 (nil (w @ 2 'cwd 8 'cqo 'cdq))
          158 (nil 'sahf)  159 (nil 'lahf)
          ;; the string ops, Intel's names (the at&T shower respells movsd's)
          164 (nil 'movsb)  165 (nil (w @ 2 'movsw 8 'movsq 'movsd))
          166 (nil 'cmpsb)  167 (nil (w @ 2 'cmpsw 8 'cmpsq 'cmpsd))
          170 (nil 'stosb)  171 (nil (w @ 2 'stosw 8 'stosq 'stosd))
          172 (nil 'lodsb)  173 (nil (w @ 2 'lodsw 8 'lodsq 'lodsd))
          174 (nil 'scasb)  175 (nil (w @ 2 'scasw 8 'scasq 'scasd))
          168 (fin (k + 1) [(op1 'test 1 [['rg 0 1] ['im (dc-imm s k 1)]])])
          169 (: isz (w = 2 ? 2 4) (fin (k + isz) [(op1 'test w [['rg 0 w] ['im (dc-imm s k isz)]])]))
          (c && 176 <= c <= 183) (fin (k + 1) [(op1 'mov 1 [(dc-reg (rl c) 1 rexp) ['im (dc-imm s k 1)]])])
          (c && 184 <= c <= 191)
           (? (w = 8) (fin (k + 8) [(op1 'mov 8 [['rg (rl c) 8] ['im (dc-le s k 8)]])])      ; the imm64 form: mov, by range
              (: isz (w = 2 ? 2 4) (fin (k + isz) [(op1 'mov w [['rg (rl c) w] ['im (dc-le s k isz)]])])))
          192 (grp2 1 'ib)  193 (grp2 w 'ib)
          208 (grp2 1 'one)  209 (grp2 w 'one)  210 (grp2 1 'cl)  211 (grp2 w 'cl)
          195 (nil 'ret)
          194 (fin (k + 2) [(op1 'ret 0 [['im (dc-le s k 2)]])])
          198 (: r (dc-modrm s k p 1 1) (fin (r 0 + 1) [(op1 'mov 1 [(r 2) ['im (dc-imm s (r 0) 1)]])]))
          199 (: r (dc-modrm s k p w w) isz (w = 2 ? 2 4) (fin (r 0 + isz) [(op1 'mov w [(r 2) ['im (dc-imm s (r 0) isz)]])]))
          201 (nil 'leave)  204 (nil 'int3)
          205 (fin (k + 1) [(op1 'int 0 [['im (dc-at s k)]])])
          215 (nil 'xlat)
          232 (rel 4 'call)  233 (rel 4 'jmp)  235 (rel 1 'jmp)
          244 (nil 'hlt)  245 (nil 'cmc)  248 (nil 'clc)  249 (nil 'stc)
          250 (nil 'cli)  251 (nil 'sti)  252 (nil 'cld)  253 (nil 'std)
          246 (grp3 1)  247 (grp3 w)
          254 (: r (dc-modrm s k p 1 1) dg (r 3)
                       (dg < 2 ? (fin (r 0) [(op1 (dg = 0 ? 'inc 'dec) 1 [(r 2)])]) (fin k [(dc-byte c)])))
          255 (: r (dc-modrm s k p w w) dg (r 3)
                       r8 (dc-modrm s k p 8 8)                            ; the 64-bit faces: call, jmp
                       (dg @ 0 (fin (r 0) [(op1 'inc w [(r 2)])])
                           1 (fin (r 0) [(op1 'dec w [(r 2)])])
                           2 (fin (r8 0) [(op1 'call 0 [['ind (r8 2)]])])
                           4 (fin (r8 0) [(op1 'jmp 0 [['ind (r8 2)]])])
                           6 (: rp (dc-modrm s k p w8 w8) (fin (rp 0) [(op1 'push w8 [(rp 2)])]))
                           (fin k [(dc-byte c)])))
          15 (dc-0f s i j p)
          (fin k [(dc-byte c)])))

   ;; --- the 0F map: the system lane, cmov/jcc/setcc, the extends, and SSE under its prefixes ---
   (dc-0f s i j p)
    (: n #s k (j + 1) c (dc-at s k) k2 (k + 1)
       px (? (pf p 'repne) 'f2 (pf p 'rep) 'f3 (pf p 'opsz) '66 'none)       ; the SSE mandatory prefix
       w (? (pf p 'w) 8 (pf p 'opsz && !(px = '66)) 2 4) rexp (pf p 'rex)     ; a 66 that is the SSE prefix sizes nothing
       ate (px = 'f2 || px = 'f3)
       (fin k3 items) (k3 > n ? (1 . [(dc-byte 15)]) ((k3 - i) . (dc-pre p 0 + items)))
       (finx k3 items) (k3 > n ? (1 . [(dc-byte 15)]) ((k3 - i) . (dc-pre p ate + items)))
       (op1 mn w ops) ['op mn w ops]
       (nil mn) (fin k2 [(op1 mn 0 ())])
       (bad _) (fin k [(dc-byte 15)])
       (ge mn wr wm) (: r (dc-modrm s k2 p wr wm) (fin (r 0) [(op1 mn (dc-vw wr wm) [(r 1) (r 2)])]))
       (eg mn wm wr) (: r (dc-modrm s k2 p wr wm) (fin (r 0) [(op1 mn (dc-vw wr wm) [(r 2) (r 1)])]))
       ;; an SSE face: xmm <- xmm/m (or the store, r/m <- xmm), the name by the prefix's lane
       (lane base) (name (base + (px @ 'none "ps" '66 "pd" 'f3 "ss" "sd")))
       (xx mn) (: r (dc-modrm s k2 p 16 16) (finx (r 0) [(op1 mn 0 [(r 1) (r 2)])]))
       (xxs mn) (: r (dc-modrm s k2 p 16 16) (finx (r 0) [(op1 mn 0 [(r 2) (r 1)])]))
       (c @ 5 (nil 'syscall)  7 (nil (w = 8 ? 'sysretq 'sysretl))  11 (nil 'ud2)
          48 (nil 'wrmsr)  49 (nil 'rdtsc)  50 (nil 'rdmsr)  162 (nil 'cpuid)
          (c && c = 0) (: r (dc-modrm s k2 p 2 2) (r 3 = 3 ? (fin (r 0) [(op1 'ltr 2 [(r 2)])]) (bad 0)))
          31 (: r (dc-modrm s k2 p w w) (fin (r 0) [(op1 'nop w [(r 2)])]))          ; the long nops
          (c && c = 30 && px = 'f3 && (dc-at s k2 = 250 || dc-at s k2 = 251))
           (finx (k2 + 1) [(op1 (dc-at s k2 = 250 ? 'endbr64 'endbr32) 0 ())])
          1 (: m (dc-at s k2)
                     (? (m = 248) (fin (k2 + 1) [(op1 'swapgs 0 ())])
                        (m = 208) (fin (k2 + 1) [(op1 'xgetbv 0 ())])
                        (m = 209) (fin (k2 + 1) [(op1 'xsetbv 0 ())])
                        (m = 249) (fin (k2 + 1) [(op1 'rdtscp 0 ())])
                        (m >> 6 = 3) (bad 0)
                        (: r (dc-modrm s k2 p 8 8) mn (r 3 @ 0 'sgdt 1 'sidt 2 'lgdt 3 'lidt 7 'invlpg ())
                           (nom? mn ? (fin (r 0) [(op1 mn 0 [(r 2)])]) (bad 0)))))
          32 (: r (dc-modrm s k2 p 8 8) (fin (r 0) [(op1 'mov 8 [(r 2) ['cr <>(r 1)]])]))    ; mov r64, crN
          34 (: r (dc-modrm s k2 p 8 8) (fin (r 0) [(op1 'mov 8 [['cr <>(r 1)] (r 2)])]))    ; mov crN, r64
          120 (eg 'vmread 8 8)  121 (ge 'vmwrite 8 8)
          199 (: r (dc-modrm s k2 p 8 8)
                       (r 3 = 6 ? (finx (r 0) [(op1 (px @ 'none 'vmptrld '66 'vmclear 'f3 'vmxon 'vmptrld) 0 [(r 2)])]) (bad 0)))
          (c && 64 <= c <= 79) (ge (dc-ccname "cmov" (c & 15)) w w)
          (c && 128 <= c <= 143) (: t (k2 + 4 + dc-imm s k2 4) (fin (k2 + 4) [(op1 (dc-ccname "j" (c & 15)) 0 [['lbl t]])]))
          (c && 144 <= c <= 159) (: r (dc-modrm s k2 p 1 1) (fin (r 0) [(op1 (dc-ccname "set" (c & 15)) 1 [(r 2)])]))
          175 (ge 'imul w w)
          182 (ge 'movzb w 1)  183 (ge 'movzw w 2)  190 (ge 'movsb w 1)  191 (ge 'movsw w 2)
          176 (eg 'cmpxchg 1 1)  177 (eg 'cmpxchg w w)
          (164 || 172) (: r (dc-modrm s k2 p w w)
                                  (fin (r 0 + 1) [(op1 (c = 164 ? 'shld 'shrd) w [(r 2) (r 1) ['im (dc-imm s (r 0) 1)]])]))
          (165 || 173) (: r (dc-modrm s k2 p w w) (fin (r 0) [(op1 (c = 165 ? 'shld 'shrd) w [(r 2) (r 1) ['rg 1 1]])]))
          188 (ge 'bsf w w)  189 (ge 'bsr w w)
          (c && 200 <= c <= 207) (fin k2 [(op1 'bswap w [['rg ((c & 7) | (pf p 'b << 3)) w]])])
          ;; SSE
          16 (xx (px @ 'none 'movups '66 'movupd 'f3 'movss 'movsd))
          17 (xxs (px @ 'none 'movups '66 'movupd 'f3 'movss 'movsd))
          (c && c = 18 && px = 'none) (: r (dc-modrm s k2 p 16 16) (finx (r 0) [(op1 (<(r 2) = 'rg ? 'movhlps 'movlps) 0 [(r 1) (r 2)])]))
          (c && c = 20 && (px = 'none || px = '66)) (xx (lane "unpckl"))
          40 (xx (px = '66 ? 'movapd 'movaps))  41 (xxs (px = '66 ? 'movapd 'movaps))
          (c && c = 42 && ate) (: r (dc-modrm s k2 p 16 w) (finx (r 0) [(op1 (px = 'f3 ? 'cvtsi2ss 'cvtsi2sd) w [(r 1) (r 2)])]))
          (c && c = 44 && ate) (: r (dc-modrm s k2 p w 16) (finx (r 0) [(op1 (px = 'f3 ? 'cvttss2si 'cvttsd2si) w [(r 1) (r 2)])]))
          (c && c = 45 && ate) (: r (dc-modrm s k2 p w 16) (finx (r 0) [(op1 (px = 'f3 ? 'cvtss2si 'cvtsd2si) w [(r 1) (r 2)])]))
          46 (xx (px = '66 ? 'ucomisd 'ucomiss))  47 (xx (px = '66 ? 'comisd 'comiss))
          80 (: r (dc-modrm s k2 p 4 16) (finx (r 0) [(op1 (px = '66 ? 'movmskpd 'movmskps) 4 [(r 1) (r 2)])]))
          81 (xx (lane "sqrt"))  84 (xx (lane "and"))  85 (xx (lane "andn"))
          86 (xx (lane "or"))  87 (xx (lane "xor"))  88 (xx (lane "add"))  89 (xx (lane "mul"))
          90 (xx (px @ 'none 'cvtps2pd '66 'cvtpd2ps 'f3 'cvtss2sd 'cvtsd2ss))
          92 (xx (lane "sub"))  93 (xx (lane "min"))  94 (xx (lane "div"))  95 (xx (lane "max"))
          (c && c = 110 && px = '66) (: r (dc-modrm s k2 p 16 w) (finx (r 0) [(op1 (w = 8 ? 'movq 'movd) w [(r 1) (r 2)])]))
          (c && c = 126 && px = '66) (: r (dc-modrm s k2 p 16 w) (finx (r 0) [(op1 (w = 8 ? 'movq 'movd) w [(r 2) (r 1)])]))
          (c && c = 126 && px = 'f3) (xx 'movq)
          (c && c = 214 && px = '66) (xxs 'movq)
          (c && c = 111 && px = '66) (xx 'movdqa)  (c && c = 127 && px = '66) (xxs 'movdqa)
          (c && c = 111 && px = 'f3) (xx 'movdqu)  (c && c = 127 && px = 'f3) (xxs 'movdqu)
          (c && px = '66 && nom? (dc-p66 c)) (xx (dc-p66 c))
          (c && px = '66 && two? (dc-pshift c))                                       ; the shifts by an immediate
           (: r (dc-modrm s k2 p 16 16) mn ((dc-pshift c) (r 3))
              (nom? mn ? (finx (r 0 + 1) [(op1 mn 0 [(r 2) ['im (dc-at s (r 0))]])]) (bad 0)))
          (c && c = 112 && (ate || px = '66))                                 ; pshufd / pshufhw / pshuflw ib
           (: r (dc-modrm s k2 p 16 16) (finx (r 0 + 1) [(op1 (px @ '66 'pshufd 'f3 'pshufhw 'pshuflw) 0 [(r 1) (r 2) ['im (dc-at s (r 0))]])]))
          198 (: r (dc-modrm s k2 p 16 16) (finx (r 0 + 1) [(op1 (px = '66 ? 'shufpd 'shufps) 0 [(r 1) (r 2) ['im (dc-at s (r 0))]])]))
          (c && c = 215 && px = '66) (: r (dc-modrm s k2 p 4 16) (finx (r 0) [(op1 'pmovmskb 4 [(r 1) (r 2)])]))
          194 (: r (dc-modrm s k2 p 16 16) (finx (r 0 + 1) [(op1 (lane "cmp") 0 [(r 1) (r 2) ['im (dc-at s (r 0))]])]))
          (bad 0)))

   ;; --- the stream: every instruction with its offset, targets made absolute ---
   (dc-abs base off n o)
    (<o @ 'lbl (charm? <>o ? ['lbl (<>o + base)] o)
          'rip (nom? <>o ? o ['rip () (<>>o + base + off + n)])   ; a rip form's disp becomes the address
          'ind ['ind (dc-abs base off n <>o)]
          'seg ['seg <>o (dc-abs base off n <>>o)]
          o)
   (x64-disasm s base)
    (: n #s
       (go off acc)
        (? (off >= n) (rev acc)
           (: r (x64-decode s off) ln <r
              its (map (\ it (<it = 'op ? ['op (it 1) (it 2) (map (o \ dc-abs base off ln o) (it 3))] it)) >r)
              (go (off + ln) ([off ln its] . acc))))
       (go 0 ()))
   ;; a target inside the stream, on an instruction boundary, becomes the symbol L<addr> and a
   ;; label row is laid there; a rip form keeps its address as (rip L<addr> 0). base is the first
   ;; row's address, so the symbol names an address, and the encoder's fixups resolve.
   (x64-relabel rows)
    (: base (two? rows ? (<(<rows)) 0)
       starts (foldl (\ t r (pin t (<r + base) 1)) {} rows)
       (sym a) (name ("L" + show a))
       (tgt a) (peep starts a 0)
       (fix o) (<o @ 'lbl (charm? <>o && tgt <>o ? ['lbl (sym <>o)] o)
                     'rip (!(nom? <>o) && tgt <>>o ? ['rip (sym <>>o) 0] o)
                     'ind ['ind (fix <>o)]
                     'seg ['seg <>o (fix <>>o)]
                     o)
       (tg o) (<o @ 'lbl (charm? <>o ? <>o -1)                       ; an operand's in-stream address, or -1
                    'rip (nom? <>o ? -1 <>>o)
                    'ind (tg <>o)
                    'seg (tg <>>o)
                    -1)
       used (foldl (\ t r (foldl (\ t it (? (<it = 'op) (foldl (\ t o (: a (tg o) (tgt a ? (pin t a 1) t))) t (it 3))
                                                    t))
                                 t (r 2)))
                   {} rows)
       (catmap (\ r (: a (<r + base)
                        its (map (\ it (<it = 'op ? ['op (it 1) (it 2) (map fix (it 3))] it)) (r 2))
                        ((peep used a 0 ? [['label (sym a)]] ()) + its)))
               rows)))
) ; module 'holo
