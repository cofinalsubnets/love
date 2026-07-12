; crew/cc/lex.l -- the C lexer (rung 3 stage 0; doc/cc.md is the plan). text ->
; (1 tokens) | () on a lex error. a token is (kind val line): ('kw nom), ('id
; text), ('num charm), ('p text) -- the punctuator by maximal munch. comments
; both kinds; line numbers carried for diagnostics. char literals 'a' (with
; \n \t \r \0 \\ \') read as ('num code); string literals (same escapes,
; plus \") as ('str text). not yet (staged): hex/octal/float literals,
; adjacent-string pasting, the preprocessor's # lines.
(:
   (clex src)
    (: n (tally src)
       kws '(auto break case char const continue default do double else enum
             extern float for goto if inline int long register restrict return
             short signed sizeof static struct switch typedef union unsigned
             void volatile while)
       p3 '("<<=" ">>=" "...")
       p2 '("==" "!=" "<=" ">=" "&&" "||" "<<" ">>" "+=" "-=" "*=" "/=" "%="
            "&=" "|=" "^=" "->" "++" "--" "##")
       p1 "()[]{};,.:?~!+-*/%<>=&|^#"
       (ws? c) (|| (= c 32) (|| (= c 9) (= c 13)))
       (dig? c) (&& (<= 48 c) (<= c 57))
       (hexd? c) (|| (dig? c) (|| (&& (<= 97 c) (<= c 102)) (&& (<= 65 c) (<= c 70))))   ; 0-9 a-f A-F
       (hexv c) (? (dig? c) (- c 48) (&& (<= 97 c) (<= c 102)) (- c 87) (- c 55))         ; a=10 A=10
       (suf? c) (|| (= c 117) (|| (= c 85) (|| (= c 108) (= c 76))))                      ; u U l L
       (skipsuf j) (? (&& (< j n) (suf? (src j))) (skipsuf (+ j 1)) j)                    ; eat an int-literal suffix run
       ; does the literal spanning [i, j) carry a u/U? an l/L? (neither is a hex
       ; digit, so the whole-span scan is safe for decimal and hex integers alike)
       (hasu? i j) (: (go k) (? (<= j k) () (|| (= (src k) 117) (= (src k) 85)) 1 (go (+ k 1))) (go i))
       (hasl? i j) (: (go k) (? (<= j k) () (|| (= (src k) 108) (= (src k) 76)) 1 (go (+ k 1))) (go i))
       ; the token kind of an integer literal: u alone reads unsigned INT (-1u
       ; wraps at 32 bits), u with l/L -- or a value past 32 bits -- unsigned LONG
       (ukind i j v) (? (! (hasu? i j)) 'num
                        (|| (hasl? i j) (<= 4294967296 v)) 'ulnum
                        'unum)
       (escv d) (? (= d 110) 10 (= d 116) 9 (= d 114) 13 (= d 97) 7 (= d 98) 8            ; \n \t \r \a \b
                   (= d 102) 12 (= d 118) 11 (= d 48) 0 (= d 92) 92                       ; \f \v \0 backslash
                   (= d 34) 34 (= d 39) 39 (= d 63) 63 (= d 101) 27 ())                   ; \" \' \? \e
       (idh? c) (|| (&& (<= 97 c) (<= c 122)) (|| (&& (<= 65 c) (<= c 90)) (= c 95)))
       (idc? c) (|| (idh? c) (dig? c))
       (at? i pat) (: m (tally pat)                 ; does pat sit at i?
                      (go k) (? (<= m k) 1
                                (<= n (+ i k)) ()
                                (= (src (+ i k)) (pat k)) (go (+ k 1))
                                ())
                      (go 0))
       (firstat i ps) (? (! (two? ps)) ()
                         (at? i (cap ps)) (cap ps)
                         (firstat i (cup ps)))
       (in1? c) (: m (tally p1)
                   (go k) (? (<= m k) () (= (p1 k) c) 1 (go (+ k 1)))
                   (go 0))
       ; -- float literals: a run with a '.' or an exponent (12.5, .5, 2., 1e9,
       ; 3.14e-2, a trailing f/F/l/L consumed). digrun scans a decimal run ->
       ; (endj value ndigits); flolit -> (endj isflo? gem-or-int). --
       (ipow b p) (: (go k a) (? (< k 1) a (go (- k 1) (* a b))) (go p 1))
       (digrun j) (: (go k v nd) (? (&& (< k n) (dig? (src k)))
                                    (go (+ k 1) (+ (* 10 v) (- (src k) 48)) (+ nd 1)) (L k v nd))
                     (go j 0 0))
       (flolit i)
        (: ir (digrun i) j0 (cap ir) iv (caup ir)
           dot (&& (< j0 n) (= (src j0) 46))
           fr (? dot (digrun (+ j0 1)) (L j0 0 0))
           j1 (cap fr) fv (caup fr) fd (cauup fr)
           mant (+ (* iv (ipow 10 fd)) fv)
           hase (&& (< j1 n) (|| (= (src j1) 101) (= (src j1) 69)))
           ee (? hase (: k (+ j1 1)
                         neg (&& (< k n) (= (src k) 45))
                         k2 (? (|| neg (&& (< k n) (= (src k) 43))) (+ k 1) k)
                         er (digrun k2)
                         (L (cap er) (? neg (- 0 (caup er)) (caup er))))
                      (L j1 0))
           j2 (cap ee) exp (caup ee)
           isflo (|| dot hase)
           j3 (? (&& isflo (&& (< j2 n) (member? (src j2) '(102 70 108 76)))) (+ j2 1) j2)
           dxp (- exp fd)
           val (? isflo (? (< dxp 0) (+ 0.0 (/ mant (ipow 10 (- 0 dxp))))
                           (+ 0.0 (* mant (ipow 10 dxp)))) iv)
           (L j3 isflo val))
       ; -- hex literals: 0x integer (0xff), OR a hex FLOAT 0x H.H p [+-] D (a binary
       ; exponent, base 2): 0x1.0p-53, 0x1p4, 0x.8p1. i points at the '0'. -> (endj isflo? value). --
       (hxrun j v nd) (? (&& (< j n) (hexd? (src j))) (hxrun (+ j 1) (+ (* 16 v) (hexv (src j))) (+ nd 1)) (L j v nd))
       (hexlit i)
        (: ir (hxrun (+ i 2) 0 0) j0 (cap ir) im (caup ir)
           dot (&& (< j0 n) (= (src j0) 46))
           fr (? dot (hxrun (+ j0 1) im 0) (L j0 im 0))
           j1 (cap fr) mant (caup fr) fd (cauup fr)          ; mant folds the fractional hex digits in; fd counts them
           hasp (&& (< j1 n) (|| (= (src j1) 112) (= (src j1) 80)))    ; p / P -- the (required) binary exponent
           (? (! (|| dot hasp)) (L (skipsuf j0) () im)       ; a plain hex integer -- eat its suffix
              (: ee (? hasp (: k (+ j1 1)
                               neg (&& (< k n) (= (src k) 45))
                               k2 (? (|| neg (&& (< k n) (= (src k) 43))) (+ k 1) k)
                               er (digrun k2)
                               (L (cap er) (? neg (- 0 (caup er)) (caup er))))
                            (L j1 0))
                 j2 (cap ee) exp (caup ee)
                 bexp (- exp (* 4 fd))                        ; each fractional hex digit is 2^-4
                 val (? (< bexp 0) (+ 0.0 (/ mant (ipow 2 (- 0 bexp)))) (+ 0.0 (* mant (ipow 2 bexp))))
                 j3 (? (&& (< j2 n) (member? (src j2) '(102 70 108 76))) (+ j2 1) j2)
                 (L j3 1 val))))
       (go i line acc)
        (? (<= n i) (L 1 (rev acc))
           (: c (src i)
              (? (= c 10) (go (+ i 1) (+ line 1) acc)
                 (&& (= c 92) (&& (< (+ i 1) n) (= (src (+ i 1)) 10)))     ; \<nl> splice: ONE logical line
                  (go (+ i 2) line acc)                                    ; (line unadvanced so a directive stays grouped)
                 (&& (= c 92) (&& (< (+ i 2) n) (&& (= (src (+ i 1)) 13) (= (src (+ i 2)) 10))))  ; \<cr><nl>
                  (go (+ i 3) line acc)
                 (ws? c) (go (+ i 1) line acc)
                 (at? i "//") (: (eat j) (? (|| (<= n j) (= (src j) 10)) j (eat (+ j 1)))
                                (go (eat i) line acc))
                 (at? i "/*") (: (eat j l2) (? (<= n (+ j 1)) (L () l2)   ; unterminated
                                              (at? j "*/") (L (+ j 2) l2)
                                              (eat (+ j 1) (? (= (src j) 10) (+ l2 1) l2)))
                                r (eat (+ i 2) line)
                                (? (charm? (cap r)) (go (cap r) (caup r) acc) ()))
                 (= c 34) (: (eat j acc2)                     ; a string literal
                              (? (<= n j) ()
                                 (: c2 (src j)
                                    (? (= c2 34) (L acc2 (+ j 1))
                                       (= c2 10) ()
                                       (&& (= c2 92) (< (+ j 1) n))
                                        (: d (src (+ j 1))
                                           v (escv d)
                                           (? (charm? v) (eat (+ j 2) (+ acc2 (string v))) ()))
                                       (eat (+ j 1) (+ acc2 (string c2))))))
                             r (eat (+ i 1) "")
                             (? (two? r) (go (caup r) line (link (L 'str (cap r) line) acc)) ()))
                 (= c 39) (: esc (&& (< (+ i 2) n) (= (src (+ i 1)) 92))
                             v (? esc (escv (src (+ i 2)))
                                  (< (+ i 1) n) (src (+ i 1))
                                  ())
                             j (+ i (? esc 4 3))
                             (? (&& (charm? v) (&& (<= j n) (= (src (- j 1)) 39)))
                                (go j line (link (L 'num v line) acc))
                                ()))
                 (&& (= c 48) (&& (< (+ i 1) n) (|| (= (src (+ i 1)) 120) (= (src (+ i 1)) 88))))  ; 0x / 0X hex (int or float)
                  (: r (hexlit i)
                     k (? (caup r) 'flo (ukind i (cap r) (cauup r)))   ; a u/U in the suffix run marks it UNSIGNED (1U / 1ULL)
                     (go (cap r) line (link (L k (cauup r) line) acc)))
                 (|| (dig? c) (&& (= c 46) (&& (< (+ i 1) n) (dig? (src (+ i 1))))))
                  (: r (flolit i)                        ; a digit run, or .digit -- integer or float
                     j2 (? (caup r) (cap r) (skipsuf (cap r)))    ; an integer eats its u/U/l/L suffix
                     k (? (caup r) 'flo (ukind i j2 (cauup r)))
                     (go j2 line (link (L k (cauup r) line) acc)))
                 (idh? c) (: (idr j) (? (&& (< j n) (idc? (src j))) (idr (+ j 1)) j)
                             j (idr i)
                             t (snip src i j)
                             s (intern t)
                             (go j line (link (? (member? s kws) (L 'kw s line) (L 'id t line)) acc)))
                 (: hit (firstat i (cat p3 p2))
                    (? hit (go (+ i (tally hit)) line (link (L 'p hit line) acc))
                       (in1? c)                        ; a '(' GLUED to a preceding id (no space) carries a 4th field: the function-macro paren
                        (: gl (&& (= c 40) (&& (< 0 i) (idc? (src (- i 1)))))
                           (go (+ i 1) line (link (? gl (L 'p (string c) line 1) (L 'p (string c) line)) acc)))
                       ())))))
       (go 0 1 ())))
