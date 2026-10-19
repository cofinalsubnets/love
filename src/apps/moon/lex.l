; src/apps/moon/lex.l -- the C lexer: text -> (1 tokens) | () on a lex error. a token is
; (kind val line): ('kw nom), ('id text), ('num charm), ('p text) -- the punctuator by maximal
; munch. char literals read as ('num code), string literals as ('str text).
(module 'moon
(borrow 'kore)
(:
   clex-run (cite 'dfa 'run)                   ; the walk over ctab.l's tables (c.lex)
   ; a diagnostic a stage may answer instead of a bare bad: file/line/col (() when unknown)
   ; and a message. a gripe is a chain, so okv? excludes it. here as the first moon file loaded
   (gripe file line col msg) ['gripe file line col msg]
   (gripe? ('gripe . _)) 1
   (okv? x) (two? x && !(gripe? x))
   ; UTF-8 -> code points, utf8put's inverse. an invalid or truncated sequence decodes
   ; as its first byte, so a re-encoded high escape (L"\xE4") round-trips
   (utf8dec s)
    (: m #s
       (cb? c) (128 <= c < 192)
       (go i acc)
        (m <= i ? (rev acc)
           (s i @ c
              (? (194 <= c < 224 && i + 1 < m && cb? (s (i + 1)))
                  (go (i + 2) (((c - 192) << 6) | (s (i + 1) & 63) . acc))
                 (224 <= c < 240 && i + 2 < m && cb? (s (i + 1)) && cb? (s (i + 2)))
                  (go (i + 3) (((c - 224) << 12) | ((s (i + 1) & 63) << 6) | (s (i + 2) & 63) . acc))
                 (240 <= c < 245 && i + 3 < m && cb? (s (i + 1)) && cb? (s (i + 2)) && cb? (s (i + 3)))
                  (go (i + 4) (((c - 240) << 18) | ((s (i + 1) & 63) << 12) | ((s (i + 2) & 63) << 6) | (s (i + 3) & 63) . acc))
                 (go (i + 1) (c . acc)))))
       (go 0 ()))
   ; -- a float literal's value, deferred: the lexer hands back pieces in the value slot
   ; and these fold them only when read. a number passes straight through
   (cfipow b p) (: (go k a) (k < 1 ? a (go (k - 1) (a * b))) (go p 1))
   ; exact digits to `sound`'s correctly-rounded reader: a float divide rounds twice and
   ; overflows on 10^310. the `e` keeps the answer a gem however integral the digits
   (cfdec mant dxp) <(sound "\(mant)e\(dxp)")
   (cflo v)
    (? !(two? v) v
       (<v = 'dec) (cfdec <>v <>>v)
       ; mant * 2^-k = mant * 5^k / 10^k: exact in decimal, so the same reader takes it
       (<v = 'hex) (: m <>v b <>>v
                    (b < 0 ? (cfdec (m * cfipow 5 -b) b)
                             (cfdec (m * cfipow 2 b) 0)))
       v)
   ; an f/F literal: n/d -> binary32 in one rounding (cflo then a narrow rounds twice), scaled
   ; into [2^23, 2^24) with e floored at -149, half-even, answered as a double
   (cbits n) (: (go k b) (k < 1 ? b (go (k // 2) (b + 1))) (go n 0))
   (cfpow2 e) (: (go k a) (k < 1 ? a (go (k - 1) (a * (e < 0 ? 0.5 2.0)))) (go (e < 0 ? -e e) 1.0))
   (cf32 n0 d0)
    (? (n0 = 0) 0.0
       (: (sc e) (e < 0 ? [(n0 * cfipow 2 -e) d0] [n0 (d0 * cfipow 2 e)])
          (fit e) (sc e @ [n d] (? (n < 8388608 * d && -149 < e) (fit (e - 1))
                                   (16777216 * d <= n) (fit (e + 1))
                                   e))
          e (fit (max -149 (cbits n0 - cbits d0 - 24)))
          q (sc e) n <q d <>q
          m (n // d) r (n - m * d)
          m2 (m + (2 * r > d || 2 * r = d && m % 2 = 1))
          (m2 = 16777216 ? (8388608.0 * cfpow2 (e + 1)) ((m2 + 0.0) * cfpow2 e))))
   (cflo32 v)
    (? !(two? v) v
       (<v = 'dec) (: m <>v x <>>v (x < 0 ? (cf32 m (cfipow 10 -x)) (cf32 (m * cfipow 10 x) 1)))
       (<v = 'hex) (: m <>v b <>>v (b < 0 ? (cf32 m (cfipow 2 -b)) (cf32 (m * cfipow 2 b) 1)))
       v)

   ; clexat numbers the first line ln0, so a prepended -D text takes 1-k..0
   (clex src) (clexat src 1)
   (clexat src ln0) (clexm src ln0 () ())
   ; a token spelled as a one-char constant: 'c' or one escape; its value is the raw byte
   (chq? (_ . _ . _ . _ . s . _)) (: (bs i n) (i < #s ? (bs (i + 1) (s i = 92 ? (n + 1) n)) n)
                                     (string? s && 2 < #s && s 0 = 39 && (#s = 3 || s 1 = 92 && bs 1 0 = 1)))
   ; for cpp: a token whitespace follows carries a 6th cell, so # can spell the gaps
   (clexw src ln0) (clexm src ln0 () 1)
   ; for a .S: 1b/2f is one word, $ @ \ ` are punctuators, `#` starts gas's comment (see go).
   ; each non-directive line opens with a ("\n") mark, so the text spelled back breaks as the source did
   (clexasm src ln0 ar)
    (: r (clexm src ln0 (ar ? 3 1) 1)
       (go l ln acc) (atom? l ? (rev acc)
                        (<l @ t
                           (? (<>>t = ln) (go >l ln (t . acc))
                              (<t = 'p && <>t = "#") (go >l <>>t (t . acc))
                              (go >l <>>t (t . ['p "\n" <>>t] . acc)))))
       (okv? r ? [1 (go <>r (ln0 - 1) ())] r))
   (clexm src ln0 asm wm)
    (: n #src
       ; newlines held inside one logical line (splices, a directive's block comment): the line
       ; number stands still across them and catches up at the logical line's end
       pend {}
       (pend1 k) (pin pend 'n (peep pend 'n 0 + k))
       (nls a b c) (a < b ? (nls (a + 1) b (src a = 10 ? (c + 1) c)) c)
       (wpad t) (#t @ k (? (k = 3) (t + [() () 1]) (k = 4) (t + [() 1]) (t + [1])))
       (spc acc) (? (!wm || atom? acc || 5 < #<acc) acc (wpad <acc . >acc))
       kws '(auto break case char const continue default do double else enum
             extern float for goto if inline int long register restrict return
             short signed sizeof static struct switch typedef union unsigned
             void volatile while _Bool _Complex __int128)
       p3 '("<<=" ">>=" "...")
       p2 '("==" "!=" "<=" ">=" "&&" "||" "<<" ">>" "+=" "-=" "*=" "/=" "%="
            "&=" "|=" "^=" "->" "++" "--" "##")
       ; the multi-char punctuators bucketed by first char
       pmap (: t {}
               (add l) (!(two? l) ? t
                          (: pat <l  h (pat 0)
                             (pin t h (t h + [pat]),
                              add >l)))
               (add (p3 + p2)))
       kwt (: t {} (go l) (!(two? l) ? t (pin t <l 1, go >l)) (go kws))
       ptab (foldl (t \ p \ pin t p p) {} (p3 + p2))   ; a multi-char punctuator's one string
       ; gcc's underscored keyword spellings; only a name opening `_` is looked up
       kwal (: t {} (go l) (!(two? l) ? t (pin t <<l <><l, go >l))
               (go '((__signed__ signed) (__signed signed))))
       p1 "()[]{};,.:?~!+-*/%<>=&|^#"
       ; -- the class table: a bitmask per char. bit 0 stays unused: a string indexed past
       ; its end answers 1. 2 ws  4 dig  8 idh  16 idc  32 hexd  64 suf  128 punct1
       (cbit c) ((c = 32 || c = 9 || c = 13 || c = 12 || c = 11 ? 2 0) +
                 (48 <= c <= 57 ? 4 0) +
                 ; a byte past 127 is an identifier char (C11 6.4.2.1's extended set)
                 (97 <= c <= 122 || 65 <= c <= 90 || c = 95 || 128 <= c ? 8 0) +
                 (48 <= c <= 57 || 97 <= c <= 122 || 65 <= c <= 90 || c = 95 || 128 <= c ? 16 0) +
                 (48 <= c <= 57 || 97 <= c <= 102 || 65 <= c <= 70 ? 32 0) +
                 (c = 117 || c = 85 || c = 108 || c = 76 ? 64 0) +
                 (elem c '(40 41 91 93 123 125 59 44 46 58 63 126 33 43 45 42 47 37 60 62 61 38 124 94 35) ? 128 0))
       ctbl (: (go k acc) (k < 0 ? (string acc) (go (k - 1) (cbit k . acc))) (go 255 ()))
       ctab clex-tab                               ; ctab.l's tables, bound here as ctbl is
       (ws? c) (ctbl c & 2)
       (dig? c) (ctbl c & 4)
       (hexd? c) (ctbl c & 32)
       (hexv c) (? (dig? c) (c - 48) (97 <= c <= 102) (c - 87) (c - 55))         ; a=10 A=10
       (suf? c) (ctbl c & 64)
       (skipsuf j) (j < n && suf? (src j) ? (skipsuf (j + 1)) j)                      ; eat an int-literal suffix run
       ; a literal prefix L, u, U or u8 before ' or " -> its length (1|2), else 0
       (wpfx i) (src i @ c
                   (!(c = 76 || c = 117 || c = 85) ? 0
                      (: pl (c = 117 && i + 1 < n && src (i + 1) = 56 ? 2 1)       ; u8 -> 2
                         nc (i + pl < n ? (src (i + pl)) 0)
                         (nc = 39 || nc = 34 ? pl 0))))
       ; does [i, j) carry a u/U? an l/L? (neither is a hex digit, so the whole span is safe)
       (hasu? i j) (: (go k) (? (j <= k) () (src k = 117 || src k = 85) 1 (go (k + 1))) (go i))
       (hasl? i j) (: (go k) (? (j <= k) () (src k = 108 || src k = 76) 1 (go (k + 1))) (go i))
       ; ll/LL: its own kinds, as long long is wider than long on 32-bit targets
       (hasll? i j) (: (l? c) (c = 108 || c = 76)
                       (go k) (? (j - 1 <= k) () (l? (src k) && l? (src (k + 1))) 1 (go (k + 1)))
                       (go i))
       ; an integer literal's kind: C11 6.4.4.1's ladder, where non-decimals take the
       ; unsigned rungs and a decimal past long takes ulong (gcc's reading). dec: decimal
       (ukind i j v dec)
        (? !(hasu? i j)
            (? (hasll? i j) 'llnum
               (!dec && !(hasl? i j) && 2147483648 <= v <= 4294967295) 'unum
               (9223372036854775808 <= v <= 18446744073709551615) 'ulnum
               (hasl? i j) 'lnum                                 ; 1L is a long, not an int that fits
               'num)
           (hasll? i j) 'ullnum
           (hasl? i j || 4294967296 <= v) 'ulnum
           'unum)
       ; C11 6.4.3p2: a ucn names no basic-set char under 00a0 (bar $ @ `), no surrogate,
       ; nothing past the last code point
       (ucnok? v) ?(v = 36 || v = 64 || v = 96 ||
                    (160 <= v <= 1114111 && !(55296 <= v <= 57343)))
       (ucn? k) (k < n && src k = 92 && k + 1 < n && (src (k + 1) = 117 || src (k + 1) = 85))
       (escv d) (d @ 110 10 116 9 114 13 97 7 98 8            ; \n \t \r \a \b
                   102 12 118 11 48 0 92 92                       ; \f \v \0 backslash
                   34 34 39 39 63 63 101 27)                   ; \" \' \? \e
       (oct? c) (ctbl c & 4 && c <= 55)                                            ; an octal digit 0-7
       (escseq k) (src k @ d                     ; k = index of the char after the backslash -> (value nextpos) or ()
                     (? (oct? d)                                                          ; \ooo -- 1..3 octal digits
                         (: (oc m v cnt) (cnt < 3 && m < n && oct? (src m) ?
                                            (oc (m + 1) (v * 8 + src m - 48) (cnt + 1))
                                            [v m])
                            (oc k 0 0))
                        (d = 120)                                                         ; \xhh -- 1+ hex digits
                         (k + 1 < n && hexd? (src (k + 1)) ?
                            (: (hx m v) (m < n && hexd? (src m) ?
                                         (hx (m + 1) (v * 16 + hexv (src m)))
                                         [v m])
                               (hx (k + 1) 0)))
                        ; \uxxxx / \Uxxxxxxxx: exactly 4 or 8 hex digits. a third element marks a
                        ; ucn: a code point, utf-8 encoded even in a narrow string
                        (d = 117 || d = 85)
                         (: w (d = 117 ? 4 8)
                            (uc m v cnt) (? (cnt = w) (ucnok? v ? [v m 1])
                                            (m < n && hexd? (src m))
                                             (uc (m + 1) (v * 16 + hexv (src m)) (cnt + 1)))
                            (uc (k + 1) 0 0))
                        (escv d @ v (charm? v ? [v (k + 1)]))))
       ; a string-shaped literal's body from qi (past the quote) to `term` -> (content endpos) | ().
       ; `wide` re-encodes escapes as UTF-8. lands a run at a time: per-byte growth is quadratic
       (strbody qi term wide)
        (: sink (jug 0)
           (run k) (n <= k ? k                      ; how far the ordinary bytes reach
                      (src k @ c2
                         (c2 = term || c2 = 92 || c2 = 10 ? k (run (k + 1)))))
           (eat j)
            (run j @ e
               (j < e ? (say sink (snip src j e)),
                n <= e ? ()
                  (src e @ c2
                     (? (c2 = term) [(slurp sink) (e + 1)]
                        (c2 = 92 && e + 1 < n && src (e + 1) = 10) (eat (e + 2))       ; \<nl> splice: the pair vanishes, the string reads on
                        (c2 = 92 && e + 2 < n && src (e + 1) = 13 && src (e + 2) = 10) (eat (e + 3))           ; \<cr><nl> splice
                        (c2 = 10) ()
                        (c2 = 92 && e + 1 < n)
                         (escseq (e + 1) @ r
                            ; a ucn (two? >>r) encodes even in a narrow string
                            (two? r ? ((wide || two? >>r ? (utf8put sink <r) (put sink <r)), eat <>r)))
                        ; any other stop of `run` (a trailing \): one byte, so it cannot loop
                        (put sink c2, eat (e + 1))))))
           (eat qi))
       ; code point -> UTF-8, utf8dec's inverse
       (utf8put sink v)
        (? (v < 128) (put sink v)
           (v < 2048) (put sink (192 + (v >> 6)), put sink (128 + (v & 63)))
           (v < 65536) (put sink (224 + (v >> 12)),
                        put sink (128 + (v >> 6 & 63)),
                        put sink (128 + (v & 63)))
           (put sink (240 + (v >> 18)),
            put sink (128 + (v >> 12 & 63)),
            put sink (128 + (v >> 6 & 63)),
            put sink (128 + (v & 63))))
       (idh? c) (ctbl c & 8)
       (idc? c) (ctbl c & 16)
       (at? i pat) (: m #pat                 ; does pat sit at i?
                      (go k) (? (m <= k) 1
                                (n <= i + k) ()
                                (src (i + k) = pat k) (go (k + 1)))
                      (go 0))
       (firstat i (a . u)) (at? i a ? a (firstat i u))
       (in1? c) (ctbl c & 128)
       (digend j) (j < n && dig? (src j) ? (digend (j + 1)) j)
       ; is the line being lexed a directive (its first token `#`)? there a `#` is # or ##
       (dirline? acc ln) (: (go l f) (two? l && <>><l = ln ? (go >l <l) f)
                            f (go acc ())
                            (two? f && <f = 'p && <>f = "#"))
       ; does a directive name follow a line-opening `#` (past blanks)?
       (asmdir? j) (: (sk k) (k < n && ws? (src k) ? (sk (k + 1)) k)
                      k (sk j)
                      (idw e) (e < n && idc? (src e) ? (idw (e + 1)) e)
                      (elem (snip src k (idw k)) '("define" "undef" "if" "ifdef" "ifndef" "elif" "else" "endif"
                                                   "include" "include_next" "error" "warning" "line" "pragma")))
       ; -- float literals: a run with a '.' or an exponent. digrun -> (endj value ndigits);
       ; flolit -> (endj isflo? pieces-or-int fsuffix?), the pieces for cflo
       (ipow b p) (: (go k a) (k < 1 ? a (go (k - 1) (a * b))) (go p 1))
       (digrun j) (: (go k v nd) (k < n && dig? (src k) ?
                                  (go (k + 1) (10 * v + src k - 48) (nd + 1)) [k v nd])
                     (go j 0 0))
       (flolit i)
        (: ir (digrun i) j0 <ir iv <>ir
           dot (j0 < n && src j0 = 46)
           fr (dot ? (digrun (j0 + 1)) [j0 0 0])
           j1 <fr fv <>fr fd <>>fr
           mant (iv * ipow 10 fd + fv)
           hase (j1 < n && (src j1 = 101 || src j1 = 69))
           ee (hase ? (: k (j1 + 1)
                         neg (k < n && src k = 45)
                         k2 (neg || k < n && src k = 43 ? (k + 1) k)
                         er (digrun k2)
                         [<er (neg ? -<>er <>er)])
                      [j1 0])
           j2 <ee exp <>ee
           isflo (dot || hase)
           j3 (isflo && j2 < n && elem (src j2) '(102 70 108 76) ? (j2 + 1) j2)
           ; gcc's imaginary suffix i/I/j/J (1.0fi): the flag rises to 'imag
           im (isflo && j3 < n && elem (src j3) '(105 73 106 74))
           j4 (!im ? j3
                 (j3 + 1 @ k
                    (k < n && elem (src k) '(102 70 108 76) ? (k + 1) k)))
           dxp (exp - fd)
           ; an f/F suffix makes it a float (C11 6.4.4.2)
           fsu ?(isflo && (j2 < n) && elem (src j2) '(102 70))
           val (isflo ? ['dec mant dxp] iv)          ; cflo folds it, if anyone asks
           [j4 (im ? 'imag isflo) val fsu])
       ; -- hex literals: 0xff, or a hex float 0x1.0p-53. i at the '0' -> (endj isflo? value fsuffix?)
       (hxrun j v nd) (j < n && hexd? (src j) ? (hxrun (j + 1) (16 * v + hexv (src j)) (nd + 1)) [j v nd])
       ; -- octal literal: i at the leading 0 -> (endj value)
       (octd? c) (ctbl c & 4 && c <= 55)
       (octlit i) (: (go k v) (k < n && octd? (src k) ? (go (k + 1) (8 * v + (src k - 48))) [k v]) (go i 0))
       ; 0b/0B binary (gcc, C23)
       (binlit i) (: (go k v) (k < n && (src k = 48 || src k = 49) ?
                                 (go (k + 1) (2 * v + src k - 48)) [k v])
                     (go (i + 2) 0))
       (hexlit i)
        (: ir (hxrun (i + 2) 0 0) j0 <ir im <>ir
           dot (j0 < n && src j0 = 46)
           fr (dot ? (hxrun (j0 + 1) im 0) [j0 im 0])
           j1 <fr mant <>fr fd <>>fr          ; mant folds the fractional hex digits in; fd counts them
           hasp (j1 < n && (src j1 = 112 || src j1 = 80))        ; p / P -- the (required) binary exponent
           (!(dot || hasp) ? [(skipsuf j0) () im]          ; a plain hex integer -- eat its suffix
              (: ee (hasp ? (: k (j1 + 1)
                               neg (k < n && src k = 45)
                               k2 (neg || k < n && src k = 43 ? (k + 1) k)
                               er (digrun k2)
                               [<er (neg ? -<>er <>er)])
                            [j1 0])
                 j2 <ee exp <>ee
                 bexp (exp - 4 * fd)                        ; each fractional hex digit is 2^-4
                 val ['hex mant bexp]                    ; cflo folds it, if anyone asks
                 j3 (j2 < n && elem (src j2) '(102 70 108 76) ? (j2 + 1) j2)
                 [j3 1 val (j2 < n && elem (src j2) '(102 70))])))
       ; a newline: the line count takes the splices pending on it
       (nl line) (peep pend 'n 0 @ k (0 < k ? (pin pend 'n 0) 0, line + 1 + k))
       ; an id the hand lexer takes: a prefixed literal's L/u/U/u8, a ucn's run, a pp-number's tail
       (idback? t i j acc)
        (? ((t = "L" || t = "u" || t = "U" || t = "u8") && j < n && (src j = 34 || src j = 39)) 1
           (ucn? j) 1
           (0 < i && !(ws? (src (i - 1))) && two? acc && elem <(<acc) '(num unum lnum ulnum llnum ullnum flo flof iflo)))
       (idtok t line)
        (: s (intern t) k (t 0 = 95 ? (peep kwal s s) s)
           (kwt k ? ['kw k line] ['id (t = "__attribute" ? "__attribute__" t) line]))
       ; a one-char punctuator the hand lexer takes: the / of /*, the . of .5
       (p1back? c j) (j < n && (c = 47 && src j = 42 || c = 46 && dig? (src j)))
       (p1tok c i line) (c = 40 && 0 < i && idc? (src (i - 1)) ? ['p (string c) line 1] ['p (string c) line])
       ; c.lex's tables say the shape at i: the common ones are laid here, the hand lexer's own
       ; way; a shape they do not name (rule 0), or one a guard turns back, runs the hand lexer
       (go i line acc)
        (? (n <= i) [1 (rev acc)]
           asm (slow i line acc)
           (clex-run ctab src i @ m
              (: r (m & 65535) j (m >> 16)
                 (? (r = 4) (snip src i j @ t (idback? t i j acc ? (slow i line acc) (go j line (idtok t line . acc))))
                    (r = 2 || r = 5) (go j line (spc acc))            ; blanks, a // comment
                    (r = 7) (src i @ c (p1back? c j ? (slow i line acc) (go j line (p1tok c i line . acc))))
                    (r = 6) (go j line (['p (ptab (snip src i j)) line] . acc))
                    (r = 1) (go j (nl line) (spc acc))
                    (r = 3) (pend1 1, go j line acc)                  ; a splice: one logical line
                    (slow i line acc)))))
       (slow i line acc)
        (n <= i ? [1 (rev acc)]
           (src i @ c
              (? (c = 10) (go (i + 1) (nl line) (spc acc))
                 (c = 92 && i + 1 < n && src (i + 1) = 10)         ; \<nl> splice: one logical line
                  (pend1 1, go (i + 2) line acc)                           ; (line unadvanced so a directive stays grouped)
                 (c = 92 && i + 2 < n && src (i + 1) = 13 && src (i + 2) = 10)          ; \<cr><nl>
                  (pend1 1, go (i + 3) line acc)
                 (ws? c) (go (i + 1) line (spc acc))
                 ; gas's comment: `#` opening a line with no directive, or after code except in
                 ; asm 3 (arm, an immediate). asm 2 (cpp's view) keeps them as text
                 (asm && asm != 2 && c = 35 && (two? acc && <>><acc = line ? (asm = 1 && !(dirline? acc line)) !(asmdir? (i + 1))))
                  (: (eat j) (n <= j || src j = 10 ? j (eat (j + 1)))
                     (go (eat i) line acc))
                 ; a numeric label's reference: digits then b or f, one word
                 (asm && dig? c && (digend i @ j (j < n && elem (src j) '(98 102) && !(j + 1 < n && idc? (src (j + 1))))))
                  (1 + digend i @ j (go j line (['id (snip src i j) line] . acc)))
                 (asm && elem c '(36 64 92 96)) (go (i + 1) line (['p (string c) line] . acc))
                 (c = 47 && at? i "//")
                  (: (eat j) (n <= j || src j = 10 ? j (eat (j + 1)))
                     (go (eat i) line (spc acc)))
                 (c = 47 && at? i "/*")
                  (: ; a \<nl> in a comment is a splice (phase 2 precedes comments): same logical line
                     (spliced? j) (0 < j && (src (j - 1) = 92 ||
                                               1 < j && src (j - 1) = 13 && src (j - 2) = 92))
                     (eat j l2) (? (n <= j + 1) [() l2]   ; unterminated
                                              (at? j "*/") [(j + 2) l2]
                                              (eat (j + 1) (src j = 10 && !(spliced? j) ? (l2 + 1) l2)))
                                r (eat (i + 2) line)
                                k (charm? <r ? (nls i <r 0) 0)
                                (? !(charm? <r) ()
                                   (0 < k && dirline? acc line) (pend1 k, go <r line (spc acc))
                                   (go <r (line + k) (spc acc))))
                 ; a quote that opens no literal is its own pp-token (C11 6.4p3), for skipped groups
                 (c = 34) (strbody (i + 1) 34 () @ r          ; a string literal
                             (two? r ? (go <>r line (['str <r line () (snip src i <>r)] . acc))
                                (go (i + 1) line (['p "\"" line] . acc))))
                 ; a character constant; a multi-char one packs left to right into an int (gcc)
                 (c = 39) (: (mc k v cnt)
                             (? (n <= k || src k = 10) ()
                                (src k = 39) (cnt = 0 ? () [k v cnt])
                                (src k = 92)
                                 (escseq (k + 1) @ r
                                    (two? r ? (mc <>r ((v << 8) | (<r & 255)) (cnt + 1))))
                                (mc (k + 1) ((v << 8) | (src k & 255)) (cnt + 1)))
                             r (mc (i + 1) 0 0)
                             (two? r ?
                              (: j (<r + 1)
                                 ; one char keeps its raw byte; a wider one is a signed int
                                 v (<>>r = 1 ? <>r
                                      (<>r & 4294967295 @ w
                                         (0 < w & 2147483648 ? (w - 4294967296) w)))
                                 (go j line (['num v line () (snip src i j)] . acc)))
                              (go (i + 1) line (['p "'" line] . acc))))
                 (c = 48 && i + 1 < n && (src (i + 1) = 120 || src (i + 1) = 88))        ; 0x / 0X hex (int or float)
                  (: r (hexlit i)
                     k (<>r ? (<>>>r ? 'flof 'flo) (ukind i <r <>>r ()))   ; a u/U in the suffix run marks it unsigned (1U / 1ULL)
                     (go <r line ([k <>>r line () (snip src i <r)] . acc)))
                 (c = 48 && i + 2 < n && (src (i + 1) = 98 || src (i + 1) = 66) &&
                  (src (i + 2) = 48 || src (i + 2) = 49))                                            ; 0b / 0B binary
                  (: r (binlit i)
                     j2 (skipsuf <r)
                     k (ukind i j2 <>r ())
                     (go j2 line ([k <>r line () (snip src i j2)] . acc)))
                 (c = 48 && i + 1 < n && octd? (src (i + 1)))       ; 0nnn octal integer (0644, 0777)
                  (: r (octlit i)
                     j2 (skipsuf <r)
                     k (ukind i j2 <>r ())
                     (go j2 line ([k <>r line () (snip src i j2)] . acc)))
                 (dig? c || c = 46 && i + 1 < n && dig? (src (i + 1)))
                  (: r (flolit i)                        ; a digit run, or .digit -- integer or float
                     j2 (<>r ? <r (skipsuf <r))    ; an integer eats its u/U/l/L suffix
                     k (? (<>r = 'imag) 'iflo    ; the imaginary float (1.0fi): its own kind
                          <>r (<>>>r ? 'flof 'flo) (ukind i j2 <>>r 1))
                     (go j2 line ([k <>>r line () (snip src i j2)] . acc)))
                 ; a prefixed literal: the kind carries the width, the value is UTF-8, the
                 ; spelling keeps the prefix. a wide char constant is its last code point (gcc)
                 (0 < wpfx i)
                  (: pl (wpfx i)
                     c2 (src (i + pl))
                     k (? (c = 117 && pl = 1) 'str16 (c = 85) 'str32 (c = 76) 'wstr 'str)
                     (? (c2 = 34)
                         (strbody (i + pl + 1) 34 !(k = 'str) @ r
                            (two? r ? (go <>r line ([k <r line () (snip src i <>r)] . acc))))
                        (k = 'str) (go (i + pl) line acc)     ; u8'': lex narrow, byte semantics
                        (: r (strbody (i + pl + 1) 39 1)
                           cps (two? r ? (utf8dec <r))
                           (lastc l) (two? >l ? (lastc >l) <l)
                           (two? cps ? (go <>r line (['num (lastc cps) line () (snip src i <>r)] . acc))))))
                 ; a pp-number runs on through identifier chars (C11 6.4.8): a number flush
                 ; against an identifier run becomes ('ppnum spelling), no number to the parser
                 (idh? c && 0 < i && !(ws? (src (i - 1))) && two? acc &&
                  elem <(<acc) '(num unum lnum ulnum llnum ullnum flo flof iflo) &&
                  4 < #(<acc) && string? ((<acc) 4) && 0 < #((<acc) 4) &&
                  ((<acc) 4 @ sp (#sp <= i && snip src (i - #sp) i = sp)))
                  (: (pr j) (? (j < n && (idc? (src j) || src j = 46)) (pr (j + 1)) j)
                     j0 (pr i)
                     sp ((<acc) 4 + snip src i j0)
                     (go j0 line (['ppnum sp line () sp] . >acc)))
                 ; an identifier may hold ucns, interned as their utf-8; a malformed one lex-errors
                 (idh? c || ucn? i)
                  (: (idr j) (? (j < n && idc? (src j)) (idr (j + 1))
                                (ucn? j) (escseq (j + 1) @ r (two? r ? (idr <>r) j))
                                j)
                     j0 (idr i)
                     (esc? k) (? (j0 <= k) () (src k = 92) 1 (esc? (k + 1)))
                     (j0 <= i ? ()
                        (: t (esc? i ?
                                (: sink (jug 0)
                                   (bld k) (? (j0 <= k) (slurp sink)
                                              (ucn? k) (escseq (k + 1) @ r
                                                          (utf8put sink <r,
                                                           bld <>r))
                                              (put sink (src k), bld (k + 1)))
                                   (bld i))
                                (snip src i j0))
                           s (intern t)
                           k (t 0 = 95 ? (peep kwal s s) s)
                           ti (t = "__attribute" ? "__attribute__" t)
                           (go j0 line ((kwt k ? ['kw k line] ['id ti line]) . acc)))))
                 (firstat i (pmap c) @ hit
                    (? hit (go (i + #hit) line (['p hit line] . acc))
                       (in1? c)                        ; a '(' glued to an id carries a 4th field, for function macros
                        (c = 40 && 0 < i && idc? (src (i - 1)) @ gl
                           (go (i + 1) line ((gl ? ['p (string c) line 1] ['p (string c) line]) . acc)))
                       ; $ @ ` \ are pp-tokens too (C11 6.4), for skipped groups and #error text
                       (asm || elem c '(36 64 92 96)) (go (i + 1) line (['p (string c) line] . acc))
                       ())))))
       (go 0 ln0 ())))
) ; module 'moon
