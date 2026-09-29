; apps/kore/gpic.l -- classic pic: kernighan's picture language as GNU pic speaks it, a troff
; (or TeX) preprocessor. a document's text goes through; each picture between .PS and .PE (or
; .PF .PY) becomes troff's \D drawing, or with -t tpic's \specials. held to groff's own pic
; byte for byte (test/gate/gpic.sh), learned by asking it, never by reading it.
;
;   pic [-nCSU] [FILE..]       troff, -n without groff's extensions to \D
;   pic -t [-cCSUz] [FILE..]   TeX: a box \graph of tpic specials
;
; pic.l's dispatch sends a bare pic here unless its input is a picture (png, jpeg, gif).
; a picture is read, run and drawn statement by statement as groff's is: the lexer expands
; macros, copy and the bodies of for and if as text; the parser reads one statement ahead
; of nothing, so what a statement does to the lexer lands before the next token is read.
(module 'kore
(borrow 'posix)

(:
   ; -- tables (at the head: a value binding sees only those above it) ------------------
   gp-pi 3.141592653589793
   gp-r2 0.7071067811865476
   ; the predefined variables and their defaults
   gp-defaults [["arcrad" 0.25] ["arrowht" 0.1] ["arrowwid" 0.05] ["boxht" 0.5]
                ["boxwid" 0.75] ["boxrad" 0.0] ["circlerad" 0.25] ["dashwid" 0.05]
                ["ellipseht" 0.5] ["ellipsewid" 0.75] ["lineht" 0.5] ["linewid" 0.5]
                ["moveht" 0.5] ["movewid" 0.5] ["textht" 0.0] ["textwid" 0.0]
                ["scale" 1.0] ["fillval" 0.5] ["linethick" -1.0] ["arrowhead" 1.0]
                ["maxpsht" 11.0] ["maxpswid" 8.5]]
   ; the ones a new scale multiplies
   gp-dims ["arcrad" "arrowht" "arrowwid" "boxht" "boxwid" "boxrad" "circlerad" "dashwid"
            "ellipseht" "ellipsewid" "lineht" "linewid" "moveht" "movewid" "textht" "textwid"]
   ; the operators longer than a character, the longest first
   gp-ops ["<->" "->" "<-" "==" "!=" "<=" ">=" "&&" "||" ":=" "'th"]
   ; words that are never a variable
   gp-reserved ["box" "circle" "ellipse" "arc" "line" "arrow" "spline" "move" "polygon"
                "right" "left" "up" "down" "at" "with" "from" "to" "by" "then" "chop" "same"
                "dashed" "dotted" "invis" "invisible" "fill" "filled" "thick" "thickness" "cw"
                "ccw" "ht" "height" "wid" "width" "rad" "radius" "diam" "diameter" "ljust" "rjust"
                "above" "below" "center" "last" "of" "the" "way" "between" "and" "Here" "for" "do"
                "if" "then" "else" "print" "command" "reset" "sprintf" "outline" "outlined" "shaded"
                "color" "colour" "colored" "coloured" "xslanted" "yslanted" "aligned" "solid"
                "figname" "plot" "sh" "until" "thru" "copy" "define" "undef" "north" "south" "east"
                "west" "top" "bottom" "bot" "start" "end" "upper" "lower"]
   gp-funcs ["sin" "cos" "atan2" "log" "exp" "sqrt" "int" "max" "min" "rand" "srand"]
   gp-corners {"n" 'n "north" 'n "top" 'n "t" 'n "s" 's "south" 's "bottom" 's "bot" 's "b" 's
               "e" 'e "east" 'e "right" 'e "r" 'e "w" 'w "west" 'w "left" 'w "l" 'w
               "ne" 'ne "nw" 'nw "se" 'se "sw" 'sw "c" 'c "center" 'c "centre" 'c
               "start" 'start "end" 'end}

   ; -- numbers -----------------------------------------------------------------
   (gp-fl x) (x * 1.0)
   (gp-neg0? x) (x = 0 && 1 / (gp-fl x) < 0)
   ; %.<nd>f, a negative zero signed as C signs it
   (gp-f x nd) (? (gp-neg0? x) ("-" + aw-fixed 0 nd) (aw-fixed x nd))
   (gp-3 x) (gp-f x 3)
   (gp-in x) (gp-3 x + "i")
   ; %g
   (gp-g x) (? (gp-neg0? x) "-0" (aw-gen x 6))

   (gp-default nm) (: (go l) (? (atom? l) () (<<l = nm) <>(<l) (go >l)) (go gp-defaults))

   ; -- errors ------------------------------------------------------------------
   ; a picture's error gives it up; the document goes on and pic leaves 1
   (gp-err g m) (scare 'gp-err m)

   ; -- the lexer: sources -----------------------------------------------------------
   ; a source is text read left to right: 'file the picture's own lines (counted, and a
   ; line opening with a dot is troff's), 'text a macro's or a body's expansion, 'for a
   ; loop's body, which runs again while the loop holds
   (gp-src t k ln) {'t t 'i 0 'k k 'ln ln 'bol 1}
   (gp-top g) (: s (g 'srcs) (? (two? s) <s ()))
   (gp-push g s) (pin g 'srcs (s . g 'srcs))
   (gp-pop g) (pin g 'srcs >(g 'srcs))
   (gp-at s k) (: i (s 'i + k) (? (i < #(s 't)) (s 't i) -1))
   (gp-c g) (: s (gp-top g) (? !(tablet? s) -1 (gp-at s 0)))
   ; does the text at s's place read w
   (gp-looking? s w) (: n #w (go k) (? (n <= k) 1 (gp-at s k = w k) (go (k + 1)) 0) (go 0))
   (gp-c1 g) (: s (gp-top g) (? !(tablet? s) -1 (gp-at s 1)))
   (gp-adv g) (: s (gp-top g) c (gp-at s 0)
                 _ (pin s 'i (s 'i + 1))
                 (? (c = 10) (pins s 'bol 1 'ln (s 'ln + 1)) (pin s 'bol 0)))
   ; the line a token is on: the picture's, under any expansion
   (gp-line g) (: (go l) (? (atom? l) 0 (<l 'k = 'file) (<l 'ln) (go >l)) (go (g 'srcs)))

   (gp-dig? c) (48 <= c <= 57)
   (gp-alpha? c) ((65 <= c <= 90) || (97 <= c <= 122) || c = 95)
   (gp-wc? c) (gp-alpha? c || gp-dig? c)
   (gp-blank? c) (c = 32 || c = 9)

   ; the text up to a newline (not taken)
   (gp-rest-line g)
    (: o (jug 0)
       (go _) (: c (gp-c g) (? (c < 0 || c = 10) (slurp o) (put o c, gp-adv g, go 0)))
       (go 0))
   (gp-skip-blanks g) (? (gp-blank? (gp-c g)) (gp-adv g, gp-skip-blanks g) 0)
   (gp-skip-space g)
    (: c (gp-c g)
       (? (gp-blank? c || c = 10) (gp-adv g, gp-skip-space g)
          (c = 92 && gp-c1 g = 10) (gp-adv g, gp-adv g, gp-skip-space g)
          0))
   (gp-word g)
    (: o (jug 0)
       (go _) (? (gp-wc? (gp-c g)) (put o (gp-c g), gp-adv g, go 0) (slurp o))
       (go 0))
   ; a quoted string, the quote taken: \" is a quote, any other backslash stays
   (gp-string g)
    (: o (jug 0)
       (go _) (: c (gp-c g)
                 (? (c < 0 || c = 10) (gp-err g "newline in string")
                    (c = 34) (gp-adv g, slurp o)
                    (c = 92 && gp-c1 g = 34) (gp-adv g, gp-adv g, put o 34, go 0)
                    (c = 92 && 0 <= gp-c1 g) (gp-adv g, put o 92, put o (gp-c g), gp-adv g, go 0)
                    (put o c, gp-adv g, go 0)))
       (go 0))
   ; a delimited body: {..} nested, or any other character to its twin. a quoted string
   ; inside may hold either
   (gp-delim g)
    (: _ (gp-skip-space g)
       d (gp-c g) o (jug 0)
       _ (? (d < 0) (gp-err g "missing delimiter") (gp-adv g))
       cl (? (d = 123) 125 d)
       (str _) (: c (gp-c g)
                  (? (c < 0) 0
                     (c = 34) (put o c, gp-adv g)
                     (c = 92) (put o c, gp-adv g, (? (0 <= gp-c g) (put o (gp-c g), gp-adv g) 0), str 0)
                     (put o c, gp-adv g, str 0)))
       (go n) (: c (gp-c g)
                 (? (c < 0) (gp-err g "end of file in a delimited body")
                    (c = cl && n = 0) (gp-adv g, slurp o)
                    (c = 34) (put o c, gp-adv g, str 0, go n)
                    (d = 123 && c = 123) (put o c, gp-adv g, go (n + 1))
                    (d = 123 && c = 125) (put o c, gp-adv g, go (n - 1))
                    (put o c, gp-adv g, go n)))
       (go 0))
   ; a numeral's value as groff's pic reads one: the whole part by tens, each figure of the
   ; fraction a tenth of the last one's weight, then times 10^exponent. not the nearest
   ; double (0.3 reads 0.30000000000000004), and every place it matters says so
   (gp-decimal t)
    (: n #t
       (whole i v) (? (i < n && gp-dig? (t i)) (whole (i + 1) (v * 10.0 + (t i - 48))) [i v])
       (frac i v f) (? (i < n && gp-dig? (t i))
                       (: f2 (f / 10.0) (frac (i + 1) (? (t i = 48) v (v + f2 * (t i - 48))) f2))
                       [i v])
       r1 (whole 0 0.0)
       r2 (? (<r1 < n && t <r1 = 46) (frac (<r1 + 1) (r1 1) 1.0) r1)
       i (<r2) v (r2 1)
       (? (i < n && (t i = 101 || t i = 69))
           (: sg (? (t (i + 1) = 45) -1 1) j (? (t (i + 1) = 45 || t (i + 1) = 43) (i + 2) (i + 1))
              e (: (go k a) (? (k < n) (go (k + 1) (a * 10 + t k - 48)) a) (go j 0))
              p (: (go k a) (? (k < e) (go (k + 1) (a * 10.0)) a) (go 0 1.0))
              (? (sg < 0) (v * (1.0 / p)) (v * p)))
          v))
   ; a number off the text: digits, a fraction, an exponent; a trailing i is inches and
   ; dropped; 1st 2nd 3rd 4th is an ordinal
   (gp-number g)
    (: o (jug 0)
       (digs _) (? (gp-dig? (gp-c g)) (put o (gp-c g), gp-adv g, digs 0) 0)
       _ (digs 0)
       whole (gp-c g != 46)
       _ (? (gp-c g = 46) (put o 46, gp-adv g, digs 0) 0)
       c (gp-c g) c1 (gp-c1 g)
       _ (? ((c = 101 || c = 69) && (gp-dig? c1 || ((c1 = 43 || c1 = 45) && gp-dig? (gp-at (gp-top g) 2))))
            (put o c, gp-adv g, (? (gp-dig? (gp-c g)) 0 (put o (gp-c g), gp-adv g)), digs 0) 0)
       t (slurp o)
       v (gp-decimal t)
       s (gp-top g)
       (sfx w) (? (gp-looking? s w && !(gp-wc? (gp-at s #w))) (map (_ \ gp-adv g) ^#w, 1) 0)
       c2 (gp-c g) c3 (gp-c1 g)
       (? (whole && (sfx "st" || sfx "nd" || sfx "rd" || sfx "th")) ['ord (int v)]
          ((c2 = 105 || c2 = 73) && !(gp-wc? c3)) (gp-adv g, ['num v])
          ['num v]))

   ; -- the lexer: macros, copy ----------------------------------------------------
   ; $1..$9 in a body, each its argument, a missing one nothing
   (gp-subst b as)
    (: o (jug 0) n #b
       (go i) (? (n <= i) (slurp o)
                 (b i = 36 && i + 1 < n && gp-dig? (b (i + 1)))
                  (: (dend j v) (? (j < n && gp-dig? (b j)) (dend (j + 1) (v * 10 + b j - 48)) [j v])
                     r (dend (i + 1) 0)
                     k <>r
                     _ (? (0 < k && k <= #as) (say o (as (k - 1))) 0)
                     (go <r))
                 (put o (b i), go (i + 1)))
       (go 0))
   ; a call's arguments, the ( taken: split at commas outside parens and strings
   (gp-args g)
    (: (go o n acc) (: c (gp-c g)
                       (? (c < 0) (gp-err g "end of file in macro arguments")
                          (c = 34) (put o c, gp-adv g, gp-strraw g o, go o n acc)
                          (c = 40) (put o c, gp-adv g, go o (n + 1) acc)
                          (c = 41 && n = 0) (gp-adv g, rev (slurp o . acc))
                          (c = 41) (put o c, gp-adv g, go o (n - 1) acc)
                          (c = 44 && n = 0) (gp-adv g, go (jug 0) n (slurp o . acc))
                          (put o c, gp-adv g, go o n acc)))
       (go (jug 0) 0 ()))
   ; the rest of a string into o, raw, the closing quote kept
   (gp-strraw g o)
    (: c (gp-c g)
       (? (c < 0) 0
          (c = 34) (put o c, gp-adv g)
          (c = 92) (put o c, gp-adv g, (? (0 <= gp-c g) (put o (gp-c g), gp-adv g) 0), gp-strraw g o)
          (put o c, gp-adv g, gp-strraw g o)))
   (gp-expand g body as) (gp-push g (gp-src (gp-subst body as) 'text 0))
   (gp-define g)
    (: _ (gp-skip-space g)
       nm (gp-word g)
       _ (? (#nm = 0) (gp-err g "bad macro name") 0)
       (pin (g 'macros) nm (gp-delim g)))
   (gp-undef g) (: _ (gp-skip-space g) nm (gp-word g) (pin (g 'macros) nm ()))
   ; words split on blanks
   (gp-words s)
    (: n #s
       (go i acc) (? (n <= i) (rev acc)
                     (gp-blank? (s i)) (go (i + 1) acc)
                     (: (e j) (? (j < n && !(gp-blank? (s j))) (e (j + 1)) j)
                        j (e i) (go j (snip s i j . acc))))
       (go 0 ()))
   ; copy "file", copy [file] thru body|macro [until "word"]: laid out as text and pushed
   (gp-copy g)
    (: _ (gp-skip-blanks g)
       file (? (gp-c g = 34) (gp-adv g, gp-string g) ())
       _ (gp-skip-blanks g)
       s (gp-top g)
       thru (? (gp-at s 0 = 116 && gp-at s 1 = 104 && gp-at s 2 = 114 && gp-at s 3 = 117 && !(gp-wc? (gp-at s 4)))
               (: _ (map (_ \ gp-adv g) ^4) _ (gp-skip-blanks g)
                  c (gp-c g)
                  (? (gp-alpha? c)
                      (: s2 (gp-top g) i0 (s2 'i) w (gp-word g) m (peep (g 'macros) w ())
                         (? (string? m) m (pin s2 'i i0, gp-delim g)))
                     (gp-delim g)))
               ())
       _ (gp-skip-blanks g)
       s3 (gp-top g)
       until (? (gp-at s3 0 = 117 && gp-at s3 1 = 110 && gp-at s3 2 = 116 && gp-at s3 3 = 105 && gp-at s3 4 = 108)
                (: _ (map (_ \ gp-adv g) ^5) _ (gp-skip-blanks g)
                   (? (gp-c g = 34) (gp-adv g, gp-string g) (gp-word g)))
                ())
       text (? (string? file)
                (: r (uread file) (? (two? r) <>r (gp-err g ("cannot open " + file))))
                ())
       (? !(string? thru)
           (? (string? file) (gp-push g (gp-src text 'text 0)) 0)
          (: ls (? (string? file) (lines text) (gp-take-lines g until))
             ls2 (? (string? file) (gp-cut-until ls until) ls)
             body (cats (map (l \ gp-subst thru (gp-words l) + "\n") ls2))
             (gp-push g (gp-src body 'text 0)))))
   (gp-cut-until ls w)
    (? (!(string? w) || atom? ls) ls
       (: ws (gp-words <ls) (? (two? ws && <ws = w) () (<ls . gp-cut-until >ls w))))
   ; the lines after this one, off the picture, up to one opening with w (taken, not
   ; kept) or the end
   (gp-take-lines g w)
    (: _ (gp-rest-line g) _ (? (gp-c g = 10) (gp-adv g) 0)
       (go acc) (? (gp-c g < 0) (rev acc)
                   (: l (gp-rest-line g) _ (? (gp-c g = 10) (gp-adv g) 0)
                      ws (gp-words l)
                      (? (string? w && two? ws && <ws = w) (rev acc) (go (l . acc)))))
       (go ()))

   ; -- the lexer ------------------------------------------------------------------
   ; a token is [kind value line]: 'num 'ord 'str 'word 'label 'dot 'op 'nl 'eof 'troff
   ; 'body 'ifb 'sh
   (gp-lex g)
    (: s (gp-top g) ln (gp-line g)
       (tok k v) [k v ln]
       (? !(tablet? s) (tok 'eof ())
          (#(s 't) <= s 'i)
           (? (s 'k = 'file) (tok 'eof ())
              (s 'k = 'for) (? (gp-for-next g s) (gp-lex g) (gp-pop g, gp-lex g))
              (gp-pop g, gp-lex g))
          (: c (gp-c g) c1 (gp-c1 g)
             (? ((s 'bol) && s 'k = 'file && c = 46 && g 'mode = 'troff)
                 (: t (gp-rest-line g) _ (? (gp-c g = 10) (gp-adv g) 0) (tok 'troff t))
                ((s 'bol) && s 'k = 'file && c = 92 && g 'mode = 'tex)
                 (: t (gp-rest-line g) _ (? (gp-c g = 10) (gp-adv g) 0) (tok 'troff t))
                (gp-blank? c) (gp-adv g, gp-lex g)
                (c = 92 && c1 = 10) (gp-adv g, gp-adv g, gp-lex g)
                (c = 35) (gp-rest-line g, gp-lex g)
                (c = 10) (gp-adv g, tok 'nl "newline")
                (c = 59) (gp-adv g, tok 'nl ";")
                (gp-dig? c || (c = 46 && gp-dig? c1)) (: r (gp-number g) (tok <r <>r))
                (c = 34) (gp-adv g, tok 'str (gp-string g))
                (gp-alpha? c) (gp-lex-word g (gp-word g) tok)
                (c = 46 && gp-alpha? c1) (gp-adv g, tok 'dot (gp-word g))
                (: op (: (go l) (? (atom? l) (string c) (gp-looking? s <l) <l (go >l))
                         (go gp-ops))
                   _ (map (_ \ gp-adv g) ^#op)
                   (tok 'op op))))))
   (gp-lex-word g w tok)
    (: m (peep (g 'macros) w ())
       (? (string? m)
           (: as (? (gp-c g = 40) (gp-adv g, gp-args g) ()) _ (gp-expand g m as) (gp-lex g))
          (w = "define") (gp-define g, gp-lex g)
          (w = "undef") (gp-undef g, gp-lex g)
          (w = "copy") (gp-copy g, gp-lex g)
          (w = "for") (pin g 'forp 1, tok 'word w)
          (w = "if") (pin g 'ifp 1, tok 'word w)
          (w = "do" && g 'forp) (pin g 'forp 0, tok 'body (gp-delim g))
          (w = "then" && g 'ifp)
           (: _ (pin g 'ifp 0)
              a (gp-delim g)
              _ (gp-skip-blanks g)
              s (gp-top g)
              e (? (gp-at s 0 = 101 && gp-at s 1 = 108 && gp-at s 2 = 115 && gp-at s 3 = 101 && !(gp-wc? (gp-at s 4)))
                   (: _ (map (_ \ gp-adv g) ^4) (gp-delim g)) ())
              (tok 'ifb [a e]))
          (w = "sh") (tok 'sh (gp-delim g))
          (65 <= w 0 <= 90 && w != "Here") (tok 'label w)
          (tok 'word w)))
   ; a loop's body is spent: step the variable and say whether to go round again
   (gp-for-next g s)
    (: f (s 'for) v (gp-var g (f 'var))
       v2 (? (f 'mul) (v * f 'by) (v + f 'by))
       _ (gp-setvar g (f 'var) v2)
       (? (gp-for-ok f v2) (pins s 'i 0 'bol 0, 1) 0))
   (gp-for-ok f v) (? (0 <= f 'by || f 'mul) (v <= f 'to) (f 'to <= v))

   ; -- tokens ---------------------------------------------------------------------
   (gp-t g i)
    (? (i < g 'nt) (g 'tk i)
       (: tk (gp-lex g) _ (pin (g 'tk) (g 'nt) tk) _ (pin g 'nt (g 'nt + 1)) (gp-t g i)))
   (gp-k g i) (gp-t g i 0)
   (gp-v g i) (gp-t g i 1)
   (gp-op? g i o) (gp-k g i = 'op && gp-v g i = o)
   (gp-w? g i w) (gp-k g i = 'word && gp-v g i = w)
   (gp-syn g i)
    (: t (gp-t g i) k <t v <>t
       _ (pins g 'errk k 'errln (t 2))
       (gp-err g ("syntax error before "
                  + (? (k = 'nl) (? (v = ";") "';'" "newline") (k = 'eof) "end of picture"
                       (k = 'str) ("'\"" + v + "\"'") (k = 'num) ("'" + gp-g v + "'")
                       (string? v) ("'" + v + "'") "'?'"))))

   ; -- variables and scopes ------------------------------------------------------------
   ; a frame is a block's: its variables, labels, objects (newest first), here and the
   ; direction; 'up the frame around it
   (gp-frame up) {'vars (tablet 0) 'labels (tablet 0) 'objs () 'here [0.0 0.0] 'dir 'right 'up up}
   (gp-find-var g nm)
    (: (go f) (? !(tablet? f) () (? (peep (f 'vars) nm () != ()) f (go (f 'up))))
       (go (g 'fr)))
   (gp-var g nm)
    (: f (gp-find-var g nm)
       (? (tablet? f) (f 'vars nm) (gp-err g ("there is no variable '" + nm + "'"))))
   (gp-setvar g nm v) (pin (g 'fr 'vars) nm (gp-fl v))
   (gp-root g) (: (go f) (? (tablet? (f 'up)) (go (f 'up)) f) (go (g 'fr)))
   (gp-reset g nms)
    (: r (gp-root g) sc (peep (r 'vars) "scale" 1.0)
       (map (nm \ pin (r 'vars) nm (gp-default nm)) nms))
   ; scale set anew: every dimension its default times it
   (gp-set-scale g v)
    (: r (gp-root g)
       _ (map (nm \ pin (r 'vars) nm (gp-default nm * v)) gp-dims)
       (pin (r 'vars) "scale" (gp-fl v)))

   ; -- geometry -------------------------------------------------------------------
   (gp-add a b) [(<a + <b) (a 1 + b 1)]
   (gp-sub a b) [(<a - <b) (a 1 - b 1)]
   (gp-mul a k) [(<a * k) (a 1 * k)]
   (gp-mid a b) [((<a + <b) / 2) ((a 1 + b 1) / 2)]
   (gp-len d) (sqrt (<d * <d + d 1 * d 1))
   ; the unit step in a direction
   (gp-unit d) (d @ 'right [1.0 0.0] 'left [-1.0 0.0] 'up [0.0 1.0] [0.0 -1.0])
   (gp-horiz? d) (d = 'right || d = 'left)
   ; a vector turned a quarter, left or right, its zeros signed as negation signs them
   (gp-rot v ccw) (? ccw [(-1.0 * v 1) (<v)] [(v 1) (-1.0 * <v)])
   ; a direction turned a quarter, left (ccw) or right
   (gp-turn d ccw)
    (? ccw (d @ 'right 'up 'up 'left 'left 'down 'right)
       (d @ 'right 'down 'down 'left 'left 'up 'right))

   ; -- expressions --------------------------------------------------------------
   ; every parse answers [value next] or () where it does not read; a value is a number,
   ; a position [x y], or an object
   (gp-truth b) (? b 1.0 0.0)
   (gp-apply g o a b)
    (o @ "||" (gp-truth (a != 0 || b != 0))
         "&&" (gp-truth (a != 0 && b != 0))
         "==" (gp-truth (a = b)) "!=" (gp-truth (a != b))
         "<" (gp-truth (a < b)) ">" (gp-truth (a > b))
         "<=" (gp-truth (a <= b)) ">=" (gp-truth (a >= b))
         "+" (a + b) "-" (a - b) "*" (a * b)
         "/" (? (b = 0) (gp-err g "division by zero") (gp-fl a / b))
         "%" (? (b = 0) (gp-err g "modulus by zero") (gp-fl a % gp-fl b))
         0)
   (gp-left g i sub ops)
    (sub g i @ [a j]
      (: (go v j) (? (gp-k g j = 'op && elem (gp-v g j) ops)
                     (sub g (j + 1) @ [b k] (go (gp-apply g (gp-v g j) v b) k)
                       ; only < may turn out not to be an operator: x < A, B >
                       (? (gp-op? g j "<") [v j] (gp-syn g (j + 1))))
                     [v j])
         (go a j))
      ())
   (gp-expr g i) (gp-left g i gp-and ["||"])
   (gp-and g i) (gp-left g i gp-eq ["&&"])
   (gp-eq g i) (gp-left g i gp-rel ["==" "!="])
   (gp-rel g i) (gp-left g i gp-add2 ["<" ">" "<=" ">="])
   (gp-add2 g i) (gp-left g i gp-mul2 ["+" "-"])
   (gp-mul2 g i) (gp-left g i gp-unary ["*" "/" "%"])
   (gp-unary g i)
    (? (gp-op? g i "-") (gp-unary g (i + 1) @ [v j] [(0 - v) j] ())
       (gp-op? g i "!") (gp-unary g (i + 1) @ [v j] [(gp-truth (v = 0)) j] ())
       (gp-pow g i))
   (gp-pow g i)
    (gp-prim g i @ [a j]
      (? (gp-op? g j "^") (gp-unary g (j + 1) @ [b k] [(gp-fl a ** b) k] [a j]) [a j])
      ())
   ; a call's arguments, (..) taken -> [values next]
   (gp-callargs g i)
    (? !(gp-op? g i "(") ()
       (gp-op? g (i + 1) ")") [() (i + 2)]
       (: (go j acc) (gp-expr g j @ [v k]
                       (? (gp-op? g k ",") (go (k + 1) (v . acc))
                          (gp-op? g k ")") [(rev (v . acc)) (k + 1)] ())
                       ())
          (go (i + 1) ())))
   (gp-func g f as)
    (: n #as (a k) (as k)
       (need m) (? (n = m) 0 (gp-err g ("wrong number of arguments to " + f)))
       (f @ "sin" (need 1, sin (a 0)) "cos" (need 1, cos (a 0))
            "atan2" (need 2, (? (a 0 = 0 && a 1 = 0) (gp-err g "atan2 argument out of domain") (atan2 (a 0) (a 1))))
            "log" (need 1, (? (a 0 <= 0) (gp-err g "log argument out of domain") (log (a 0) / log 10.0)))
            "exp" (need 1, 10.0 ** a 0)
            "sqrt" (need 1, (? (a 0 < 0) (gp-err g "sqrt argument out of domain") (sqrt (a 0))))
            "int" (need 1, (: v (a 0) (? (v < 0) (0 - gp-fl (floor (0 - v))) (gp-fl (floor v)))))
            "max" (need 2, (? (a 1 > a 0) (a 1) (a 0)))
            "min" (need 2, (? (a 1 < a 0) (a 1) (a 0)))
            "rand" (: r (gp-rand g) (? (n = 0) r (1.0 + gp-fl (floor (r * a 0)))))
            "srand" (need 1, pin g 'seed (int (a 0)), 0.0)
            0.0))
   ; a small lcg: rand's numbers are ours, not the oracle's
   (gp-rand g) (: s ((g 'seed * 1103515245 + 12345) % 2147483648) _ (pin g 'seed s) (s / 2147483648.0))
   (gp-prim g i)
    (: k (gp-k g i) v (gp-v g i)
       (? (k = 'num) [(gp-fl v) (i + 1)]
          (gp-op? g i "(") (gp-expr g (i + 1) @ [e j] (? (gp-op? g j ")") [e (j + 1)] ()) ())
          (k = 'str)
           (? (gp-k g (i + 1) = 'op && elem (gp-v g (i + 1)) ["==" "!="] && gp-k g (i + 2) = 'str)
               [(gp-truth ((v = gp-v g (i + 2)) = (gp-v g (i + 1) = "=="))) (i + 3)]
              ())
          (k = 'word && elem v gp-funcs)
           (gp-callargs g (i + 1) @ [as j] [(gp-func g v as) j] ())
          (k = 'word && !(elem v gp-reserved)) [(gp-var g v) (i + 1)]
          ; a place's coordinate, an object's size
          (gp-place g i @ [p j]
            (: d (gp-v g j)
               (? (gp-k g j != 'dot) ()
                  (d = "x") [(<(gp-pos g p)) (j + 1)]
                  (d = "y") [(gp-pos g p 1) (j + 1)]
                  (!(tablet? p)) ()
                  (elem d ["ht" "height"]) [(gp-size p 'h) (j + 1)]
                  (elem d ["wid" "width"]) [(gp-size p 'w) (j + 1)]
                  (elem d ["rad" "radius"]) [(gp-size p 'r) (j + 1)]
                  (elem d ["diam" "diameter"]) [(2 * gp-size p 'r) (j + 1)]
                  ()))
            ())))
   (gp-size o k) (peep o k 0.0)

   ; -- places and positions ---------------------------------------------------------
   (gp-corner-name s) (peep gp-corners s ())
   ; a value as a position: an object's is its centre
   (gp-pos g v) (? (tablet? v) (gp-corner g v 'c) v)
   (gp-kind-word w)
    (w @ "box" 'box "circle" 'circle "ellipse" 'ellipse "arc" 'arc "line" 'line "arrow" 'arrow
         "spline" 'spline "move" 'move "polygon" 'polygon ())
   ; an object's type after last or an ordinal -> [kind next]
   (gp-otype g i)
    (: k (gp-k g i)
       (? (k = 'word && gp-kind-word (gp-v g i) != ()) [(gp-kind-word (gp-v g i)) (i + 1)]
          (gp-op? g i "[" && gp-op? g (i + 1) "]") ['block (i + 2)]
          (k = 'str) [['text (gp-v g i)] (i + 1)]
          ()))
   ; the nth object of a kind here, from the first or (back) from the last
   (gp-nth-obj g ty n back)
    (: os (? back (g 'fr 'objs) (rev (g 'fr 'objs)))
       (hit o) (? (two? ty) (two? (peep o 'txt ()) && <(o 'txt) 's = <>ty)
                  (ty = 'line) (o 'kw = 'line || o 'kw = 'arrow)
                  (o 'kw = ty))
       (go l k) (? (atom? l) () (hit <l) (? (k = 1) <l (go >l (k - 1))) (go >l k))
       (go os n))
   (gp-nth-err g ty n back)
    (: nm (? (two? ty) ("\"" + <>ty + "\"") (ty = 'block) "[]" (show ty))
       (gp-err g ("there is no " + gp-ordinal n + (? back " last " " ") + nm)))
   (gp-ordinal n)
    (: s (show n) m (n % 100) d (n % 10)
       (s + (? (11 <= m <= 13) "th" (d = 1) "st" (d = 2) "nd" (d = 3) "rd" "th")))
   ; `ord [last] type`, `last type`, `` `e'th `` -> [object next]
   (gp-nth g i)
    (: k (gp-k g i)
       (tail n j) (? (gp-w? g j "last")
                      (gp-otype g (j + 1) @ [ty m] (: o (gp-nth-obj g ty n 1) [(? (tablet? o) o (gp-nth-err g ty n 1)) m]) ())
                      (gp-otype g j @ [ty m] (: o (gp-nth-obj g ty n 0) [(? (tablet? o) o (gp-nth-err g ty n 0)) m]) ()))
       (? (k = 'ord) (tail (gp-v g i) (i + 1))
          (gp-w? g i "last") (gp-otype g (i + 1) @ [ty m] (: o (gp-nth-obj g ty 1 1) [(? (tablet? o) o (gp-nth-err g ty 1 1)) m]) ())
          (gp-op? g i "`") (gp-expr g (i + 1) @ [v j] (? (gp-op? g j "'th") (tail (int v) (j + 1)) ()) ())
          ()))
   ; a label's value, the frames outward
   (gp-label g nm)
    (: (go f) (? !(tablet? f) () (: v (peep (f 'labels) nm ()) (? (v != ()) v (go (f 'up)))))
       (go (g 'fr)))
   ; a place -> [object-or-position next]. a label or object may go on into a block's
   ; labels (.A.B) and end at a corner; a .x .y .ht is an expression's and is left
   (gp-place g i)
    (: k (gp-k g i) v (gp-v g i)
       (dots p j)
        (: d (gp-v g j)
           (? (gp-k g j != 'dot) [p j]
              (tablet? p && 65 <= d 0 <= 90)
               (: q (peep (peep p 'labels (tablet 0)) d ())
                  (? (q = ()) (gp-err g ("there is no label '" + d + "' in the block")) (dots q (j + 1))))
              (gp-corner-name d != ()) [(gp-corner g p (gp-corner-name d)) (j + 1)]
              (elem d ["x" "y" "ht" "height" "wid" "width" "rad" "radius" "diam" "diameter"]) [p j]
              (gp-syn g j)))
       (? (k = 'label)
           (: p (gp-label g v) (? (p = ()) (gp-err g ("there is no place '" + v + "'")) (dots p (i + 1))))
          (gp-w? g i "Here") [(g 'fr 'here) (i + 1)]
          (k = 'word && gp-corner-name v != () && gp-w? g (i + 1) "of")
           (gp-place g (i + 2) @ [p j] [(gp-corner g p (gp-corner-name v)) j] ())
          (k = 'dot && gp-corner-name v != () && gp-w? g (i + 1) "of")
           (gp-place g (i + 2) @ [p j] [(gp-corner g p (gp-corner-name v)) j] ())
          (gp-nth g i @ [o j] (dots o j) ())))
   ; (x, y) or x, y
   (gp-pair g i)
    (? (gp-op? g i "(")
        (: r (gp-pair g (i + 1)) (? (two? r && gp-op? g (r 1) ")") [(r 0) (r 1 + 1)] (gp-pair-bare g i)))
       (gp-pair-bare g i))
   (gp-pair-bare g i)
    (gp-expr g i @ [x j] (? (gp-op? g j ",") (gp-expr g (j + 1) @ [y k] [[x y] k] ()) ()) ())
   ; a position -> [[x y] next]
   (gp-position g i)
    (: r (gp-position1 g i)
       (go p j) (? (gp-op? g j "+") (gp-pair g (j + 1) @ [d k] (go (gp-add p d) k) [p j])
                   (gp-op? g j "-") (gp-pair g (j + 1) @ [d k] (go (gp-sub p d) k) [p j])
                   [p j])
       (? (two? r) (go (r 0) (r 1)) ()))
   (gp-position1 g i)
    (: pl (gp-place g i)
       ok (two? pl && !(gp-k g (pl 1) = 'dot))
       (? ok [(gp-pos g (pl 0)) (pl 1)]
          (: r1 (? (gp-op? g i "(")
                   (gp-position g (i + 1) @ [a j]
                     (? (gp-op? g j ",") (gp-position g (j + 1) @ [b k] (? (gp-op? g k ")") [[(a 0) (b 1)] (k + 1)] ()) ())
                        (gp-op? g j ")") [a (j + 1)]
                        ())
                     ())
                   ())
             (? (two? r1) r1
                (gp-expr g i @ [e j]
                  (? (gp-op? g j ",") (gp-expr g (j + 1) @ [y k] [[e y] k] ())
                     (gp-w? g j "of") (? (gp-w? g (j + 1) "the" && gp-w? g (j + 2) "way" && gp-w? g (j + 3) "between")
                                          (gp-between g e (j + 4)) ())
                     (gp-w? g j "between") (gp-between g e (j + 1))
                     (gp-op? g j "<")
                      (gp-position g (j + 1) @ [a k]
                        (? (gp-op? g k ",") (gp-position g (k + 1) @ [b m] (? (gp-op? g m ">") [(gp-interp e a b) (m + 1)] ()) ()) ())
                        ())
                     ())
                  ())))))
   (gp-between g e i)
    (gp-position g i @ [a j]
      (? (gp-w? g j "and") (gp-position g (j + 1) @ [b k] [(gp-interp e a b) k] ()) ())
      ())
   (gp-interp e a b) [(<a + (<b - <a) * e) (a 1 + (b 1 - a 1) * e)]

   ; -- objects --------------------------------------------------------------------
   ; an object is a tablet: 'ty box circle ellipse arc line spline move text block troff,
   ; 'kw what last and nth call it (arrow for a line with a head), 'c the centre, 'w 'h
   ; 'r, 'pts a path's points, 'st 'en, and how it is drawn
   ; a corner's offset from the centre of a thing w by h, round or square
   (gp-off round w h c)
    (: x (w / 2) y (h / 2) dx (? round (x * gp-r2) x) dy (? round (y * gp-r2) y)
       (c @ 'n [0.0 y] 's [0.0 (0 - y)] 'e [x 0.0] 'w [(0 - x) 0.0]
            'ne [dx dy] 'nw [(0 - dx) dy] 'se [dx (0 - dy)] 'sw [(0 - dx) (0 - dy)]
            [0.0 0.0]))
   ; a position's every corner is itself
   (gp-corner g o c) (? (tablet? o) (gp-corner-of g o c) o)
   (gp-corner-of g o c)
    (: ty (o 'ty)
       (? (elem ty ['box 'text 'block 'circle 'ellipse])
           (? (elem c ['start 'end]) (o 'c)
              (gp-add (o 'c) (gp-off (ty = 'circle || ty = 'ellipse) (o 'w) (o 'h) c)))
          (ty = 'arc)
           (? (c = 'start) (o 'st) (c = 'end) (o 'en)
              (gp-add (o 'c) (gp-off 1 (2 * o 'r) (2 * o 'r) c)))
          (elem ty ['line 'spline 'move 'polygon])
           (? (c = 'start) (o 'st) (c = 'end) (o 'en) (c = 'c) (gp-mid (o 'st) (o 'en))
              (: b (gp-bbox o) m [((b 0 + b 2) / 2) ((b 1 + b 3) / 2)]
                 (gp-add m (gp-off 0 (b 2 - b 0) (b 3 - b 1) c))))
          (o 'c)))
   ; [llx lly urx ury], or () for what takes no room
   (gp-bbox o)
    (: ty (o 'ty)
       (? (elem ty ['box 'text 'block 'circle 'ellipse])
           (: c (o 'c) x (o 'w / 2) y (o 'h / 2) [(<c - x) (c 1 - y) (<c + x) (c 1 + y)])
          (ty = 'arc) (gp-arc-bbox o)
          (ty = 'spline) (gp-pts-bbox (gp-spline-hull (o 'pts)))
          (elem ty ['line 'move 'polygon]) (gp-pts-bbox (o 'pts))
          ()))
   ; what a spline's box is taken over: its ends, and each bend's point halfway round
   (gp-spline-hull ps)
    (: (go l acc) (? (atom? >>l) (rev (<>l . acc))
                     (: a (gp-mid <l <>l) b <>l c (gp-mid <>l <>>l)
                        (go >l ([(0.25 * <a + 0.5 * <b + 0.25 * <c) (0.25 * a 1 + 0.5 * b 1 + 0.25 * c 1)] . acc))))
       (? (atom? >>ps) ps (go ps [<ps])))
   (gp-pts-bbox ps)
    (foldl (\ b p [(min (b 0) <p) (min (b 1) (p 1)) (max (b 2) <p) (max (b 3) (p 1))])
           [(<(<ps)) (<ps 1) (<(<ps)) (<ps 1)] >ps)
   (gp-bb-join a b)
    (? (atom? a) b (atom? b) a
       [(min (a 0) (b 0)) (min (a 1) (b 1)) (max (a 2) (b 2)) (max (a 3) (b 3))])
   (gp-arc-bbox o)
    (: c (o 'c) r (o 'r) s (o 'st) e (o 'en) ccw !(o 'cw)
       a0 (atan2 (s 1 - c 1) (<s - <c)) a1 (atan2 (e 1 - c 1) (<e - <c))
       tau (2 * gp-pi)
       (norm a) (: m (a % tau) (? (m < 0) (m + tau) m))
       sweep (norm (? ccw (a1 - a0) (a0 - a1)))
       (on a) (: d (norm (? ccw (a - a0) (a0 - a))) (1e-9 < d && d < sweep - 1e-9))
       ax [[0.0 [(<c + r) (c 1)]] [(gp-pi / 2) [(<c) (c 1 + r)]]
           [gp-pi [(<c - r) (c 1)]] [(0 - gp-pi / 2) [(<c) (c 1 - r)]]]
       ps (foldl (\ acc q (? (on <q) (<>q . acc) acc)) [s e] ax)
       (gp-pts-bbox ps))
   (gp-shift o d) (gp-move o (p \ gp-add p d))
   ; every point of an object, and of a block's insides, through f
   (gp-move o f)
    (: _ (map (k \ (? (peep o k () != ()) (pin o k (f (o k))) 0)) ['c 'st 'en])
       _ (? (two? (peep o 'pts ())) (pin o 'pts (map f (o 'pts))) 0)
       (? (o 'ty = 'block)
           (: _ (map (x \ gp-move x f) (o 'objs))
              lb (o 'labels)
              (map (nm \ (: v (lb nm) (? (two? v) (pin lb nm (f v)) 0))) (keys lb)))
          0))
   (gp-add-obj g o) (pin (g 'fr) 'objs (o . g 'fr 'objs))

   ; -- object specs ------------------------------------------------------------------
   (gp-spec ty) {'ty ty 'segs () 'cur () 'txt ()}
   (gp-seg-close sp) (? (two? (sp 'cur)) (pins sp 'segs (['rel (sp 'cur)] . sp 'segs) 'cur ()) 0)
   ; a direction word's default length
   (gp-dirlen g sp d)
    (: t (sp 'ty) h (gp-horiz? d)
       (? (t = 'move) (gp-var g (? h "movewid" "moveht"))
          (gp-var g (? h "linewid" "lineht"))))
   (gp-add-dir g sp d n)
    (: u (gp-unit d) cur (? (two? (sp 'cur)) (sp 'cur) [0.0 0.0])
       (pins sp 'cur (gp-add cur (gp-mul u n)) 'dir d))
   (gp-last-text sp f v) (? (two? (sp 'txt)) (pin (<(sp 'txt)) f v) 0)
   (gp-text-item s ln) {'s s 'ln ln}
   ; an optional expression -> [value next] or [() i]
   (gp-opt-expr g i) (: r (gp-expr g i) (? (two? r) r [() i]))
   (gp-sprintf g i)
    (? !(gp-op? g i "(" && gp-k g (i + 1) = 'str) ()
       (: f (gp-v g (i + 1))
          (go j acc) (? (gp-op? g j ")") [(aw-sprintf f (rev acc) "%g") (j + 1)]
                        (gp-op? g j ",") (gp-expr g (j + 1) @ [v k] (go k (v . acc)) ())
                        ())
          (go (i + 2) ())))
   ; a text: "string" or sprintf(..) -> [string next]
   (gp-text g i)
    (? (gp-k g i = 'str) [(gp-v g i) (i + 1)]
       (gp-w? g i "sprintf") (gp-sprintf g (i + 1))
       ())
   ; one attribute -> next, or () where none begins
   (gp-attr g i sp)
    (: k (gp-k g i) v (gp-v g i) ln (gp-t g i 2)
       (ex f) (gp-expr g (i + 1) @ [e j] (f e, j) (gp-syn g (i + 1)))
       (pos f) (gp-position g (i + 1) @ [p j] (f p, j) (gp-syn g (i + 1)))
       (opt f) (: r (gp-opt-expr g (i + 1)) (f (r 0), r 1))
       (? (k = 'str || gp-w? g i "sprintf")
           (gp-text g i @ [s j] (pin sp 'txt ((gp-text-item s ln) . sp 'txt), j) ())
          (k = 'op)
           (v @ "->" (pin sp 'ah ((peep sp 'ah 0) | 2), i + 1)
                "<-" (pin sp 'ah ((peep sp 'ah 0) | 1), i + 1)
                "<->" (pin sp 'ah 3, i + 1)
                ())
          (k != 'word)
           (: r (gp-expr g i) (? (two? r) (gp-add-dir g sp (g 'fr 'dir) (r 0), r 1) ()))
          (elem v ["ht" "height"]) (ex (e \ pin sp 'ht e))
          (elem v ["wid" "width"]) (ex (e \ pin sp 'wid e))
          (elem v ["rad" "radius"]) (ex (e \ pin sp 'rad e))
          (elem v ["diam" "diameter"]) (ex (e \ pin sp 'rad (e / 2)))
          (elem v ["up" "down" "left" "right"])
           (: d (name v) r (gp-opt-expr g (i + 1))
              (gp-add-dir g sp d (? (r 0 = ()) (gp-dirlen g sp d) (r 0)), r 1))
          (v = "then") (gp-seg-close sp, pin sp 'then 1, i + 1)
          (v = "from") (pos (p \ pin sp 'from p))
          (v = "to") (pos (p \ (gp-seg-close sp, pin sp 'segs (['abs p] . sp 'segs))))
          (v = "by") (gp-pair g (i + 1) @ [p j] (gp-seg-close sp, pin sp 'segs (['rel p] . sp 'segs), j) (gp-syn g (i + 1)))
          (v = "at") (pos (p \ pin sp 'at p))
          (v = "with") (gp-with g (i + 1) sp)
          (v = "chop") (opt (e \ pin sp 'chop (e . peep sp 'chop ())))
          (v = "dashed") (opt (e \ pins sp 'lt 'dashed 'dw e))
          (v = "dotted") (opt (e \ pins sp 'lt 'dotted 'dw e))
          (elem v ["invis" "invisible"]) (pin sp 'invis 1, i + 1)
          (v = "solid") (pin sp 'lt 'solid, i + 1)
          (elem v ["fill" "filled"]) (opt (e \ pin sp 'fill (? (e = ()) (gp-var g "fillval") e)))
          (elem v ["thick" "thickness"]) (ex (e \ pin sp 'thick e))
          (v = "same") (pin sp 'same 1, i + 1)
          (v = "cw") (pin sp 'cw 1, i + 1)
          (v = "ccw") (pin sp 'cw 0, i + 1)
          (v = "ljust") (gp-last-text sp 'ljust 1, i + 1)
          (v = "rjust") (gp-last-text sp 'rjust 1, i + 1)
          (v = "above") (gp-last-text sp 'above 1, i + 1)
          (v = "below") (gp-last-text sp 'below 1, i + 1)
          (v = "center") (i + 1)
          (v = "aligned") (pin sp 'aligned 1, i + 1)
          (elem v ["outline" "outlined"]) (gp-text g (i + 1) @ [s j] (pin sp 'outline s, j) (gp-syn g (i + 1)))
          (v = "shaded") (gp-text g (i + 1) @ [s j] (pin sp 'shaded s, j) (gp-syn g (i + 1)))
          (elem v ["color" "colour" "colored" "coloured"])
           (gp-text g (i + 1) @ [s j] (pins sp 'outline s 'shaded s, j) (gp-syn g (i + 1)))
          (v = "xslanted") (ex (e \ pin sp 'xsl e))
          (v = "yslanted") (ex (e \ pin sp 'ysl e))
          (: r (gp-expr g i) (? (two? r) (gp-add-dir g sp (g 'fr 'dir) (r 0), r 1) ()))))
   ; with .corner, with .A.B.corner (into a block), or with a position
   (gp-with g i sp)
    (: (dots j acc) (? (gp-k g j = 'dot) (dots (j + 1) (gp-v g j . acc)) [(rev acc) j])
       (? (gp-k g i = 'dot) (dots i () @ [ps j] (pin sp 'with ps, j) ())
          (gp-k g i = 'word && gp-corner-name (gp-v g i) != ()) (pin sp 'with [(gp-v g i)], i + 1)
          (gp-position g i @ [p j] (pin sp 'with p, j) (gp-syn g i))))
   (gp-attrs g i sp) (: j (gp-attr g i sp) (? (j = ()) i (gp-attrs g j sp)))

   ; -- making objects --------------------------------------------------------------
   (gp-last-kw g kw) (gp-nth-obj g kw 1 1)
   ; what every object carries off its spec
   (gp-common g sp o)
    (pins o 'lt (peep sp 'lt 'solid) 'dw (peep sp 'dw ()) 'invis (peep sp 'invis 0)
            'fill (peep sp 'fill ()) 'thick (peep sp 'thick (gp-var g "linethick"))
            'txt (rev (sp 'txt)) 'outline (peep sp 'outline ()) 'shaded (peep sp 'shaded ())
            'aligned (peep sp 'aligned 0))
   ; where a closed thing of w by h goes: at, with, or on from here
   (gp-place-closed g sp o)
    (: fr (g 'fr) d (fr 'dir) w (o 'w) h (o 'h) round (elem (o 'ty) ['circle 'ellipse])
       wo (: wv (peep sp 'with ())
             (? (wv = ()) [0.0 0.0]
                (string? <wv) (gp-with-off g o wv round)
                wv))
       half (? (gp-horiz? d) (w / 2) (h / 2))
       c (? (peep sp 'at () != ()) (gp-sub (sp 'at) wo)
            (peep sp 'with () != ()) (gp-sub (fr 'here) wo)
            (gp-add (fr 'here) (gp-mul (gp-unit d) half)))
       _ (pin o 'c c)
       (pin fr 'here (gp-add c (gp-mul (gp-unit d) half))))
   ; a with path's offset from the centre: a corner, or into a block's labels
   (gp-with-off g o ps round)
    (? (atom? >ps && gp-corner-name <ps != ()) (gp-off round (o 'w) (o 'h) (gp-corner-name <ps))
       (o 'ty = 'block)
        (: q (peep (o 'labels) <ps ())
           _ (? (q = ()) (gp-err g ("there is no label '" + <ps + "' in the block")) 0)
           p (? (tablet? q) (gp-with-at g q >ps) q)
           (gp-sub p (o 'c)))
       (gp-err g "with: not a block"))
   (gp-with-at g o ps)
    (? (atom? ps) (gp-pos g o)
       (atom? >ps && gp-corner-name <ps != ()) (gp-corner g o (gp-corner-name <ps))
       (: q (peep (peep o 'labels (tablet 0)) <ps ()) (? (q = ()) (gp-err g ("there is no label '" + <ps + "' in the block")) (gp-with-at g q >ps))))
   (gp-make-closed g sp ty w h)
    (: o {'ty ty 'kw ty 'w w 'h h}
       _ (gp-common g sp o)
       _ (gp-place-closed g sp o)
       _ (gp-add-obj g o)
       o)
   (gp-make g sp)
    (: ty (sp 'ty) same (peep sp 'same 0)
       lastc (? same (gp-last-kw g ty) ())
       (dim k var sk)
        (? (peep sp k () != ()) (sp k)
           (tablet? lastc) (lastc sk)
           (gp-var g var))
       (ty @ 'box (: o (gp-make-closed g sp 'box (dim 'wid "boxwid" 'w) (dim 'ht "boxht" 'h))
                     (pins o 'rad (peep sp 'rad (gp-var g "boxrad")) 'xsl (peep sp 'xsl 0.0) 'ysl (peep sp 'ysl 0.0)))
            'circle (: r (dim 'rad "circlerad" 'r) o (gp-make-closed g sp 'circle (2 * r) (2 * r)) (pin o 'r r))
            'ellipse (gp-make-closed g sp 'ellipse (dim 'wid "ellipsewid" 'w) (dim 'ht "ellipseht" 'h))
            'text (gp-make-closed g sp 'text (peep sp 'wid (gp-var g "textwid"))
                                   (peep sp 'ht (#(sp 'txt) * gp-var g "textht")))
            'arc (gp-make-arc g sp)
            'block (gp-make-block g sp)
            (gp-make-linear g sp)))
   (gp-make-linear g sp)
    (: ty (sp 'ty) fr (g 'fr) d (fr 'dir)
       _ (gp-seg-close sp)
       segs0 (rev (sp 'segs))
       lastl (? (peep sp 'same 0) (gp-last-kw g (? (ty = 'arrow) 'line ty)) ())
       segs (? (two? segs0) segs0
               (tablet? lastl) (peep lastl 'segs ())
               [['rel (gp-mul (gp-unit d) (gp-dirlen g sp d))]])
       st (peep sp 'from (fr 'here))
       pts (rev (foldl (\ acc s (: p <acc (((s 0) = 'rel ? (gp-add p (s 1)) (s 1)) . acc))) [st] segs))
       en (<(rev pts))
       kind (? (ty = 'arrow) 'line ty)
       o {'ty kind 'kw ty 'pts pts 'st st 'en en 'segs segs}
       _ (gp-common g sp o)
       ah (peep sp 'ah (? (ty = 'arrow) 2 0))
       _ (pins o 'ah ah 'aht (peep sp 'ht (gp-var g "arrowht")) 'awid (peep sp 'wid (gp-var g "arrowwid"))
               'asolid (gp-var g "arrowhead" != 0 && !(g 'nflag)))
       _ (? (ty = 'move) (pin o 'invis 1) 0)
       _ (? (peep sp 'at () != ()) (: m (gp-mid st en) (gp-shift o (gp-sub (sp 'at) m))) 0)
       _ (gp-chop g sp o)
       _ (gp-add-obj g o)
       _ (pin fr 'here (o 'en))
       _ (? (peep sp 'dir () != ()) (pin fr 'dir (sp 'dir)) 0)
       o)
   ; chop: each end drawn short, by circlerad or the amounts given
   (gp-chop g sp o)
    (: cs (rev (peep sp 'chop ()))
       (? (atom? cs) 0
          (: dflt (gp-var g "circlerad")
             a (? (<cs = ()) dflt <cs)
             b (? (two? >cs) (? (<>cs = ()) dflt <>cs) a)
             ps (o 'pts) n #ps
             p0 (ps 0) p1 (ps 1) q1 (ps (n - 2)) q0 (ps (n - 1))
             (cut p q k) (: v (gp-sub q p) l (gp-len v) (? (l = 0) p (gp-add p (gp-mul v (k / l)))))
             s2 (cut p0 p1 a) e2 (cut q0 q1 b)
             ps2 (s2 . rev (e2 . >(rev >ps)))
             (pins o 'pts ps2 'st s2 'en e2))))
   (gp-make-arc g sp)
    (: fr (g 'fr) d (fr 'dir) cw (peep sp 'cw 0)
       lasta (? (peep sp 'same 0) (gp-last-kw g 'arc) ())
       r0 (? (peep sp 'rad () != ()) (sp 'rad) (tablet? lasta) (lasta 'r) (gp-var g "arcrad"))
       u (gp-unit d) v (gp-rot u !cw)
       st (peep sp 'from (fr 'here))
       o {'ty 'arc 'kw 'arc 'cw cw}
       ; the centre a quarter turn off the way, the end on along it, both by angle
       _ (? (peep sp 'segs () != () || peep sp 'at () != ())
             (gp-arc-to g sp o st r0 cw)
             (: a (atan2 (v 1) <v)
                c (gp-add st [(r0 * cos a) (r0 * sin a)])
                en (gp-add st (gp-mul (gp-add u v) r0))
                (pins o 'c c 'r r0 'st st 'en en)))
       _ (gp-common g sp o)
       _ (pins o 'ah (peep sp 'ah 0) 'aht (peep sp 'ht (gp-var g "arrowht")) 'awid (peep sp 'wid (gp-var g "arrowwid"))
               'asolid (gp-var g "arrowhead" != 0 && !(g 'nflag)))
       _ (gp-add-obj g o)
       _ (pin fr 'here (o 'en))
       _ (pin fr 'dir (gp-turn d !cw))
       o)
   ; an arc to a point: the centre on the chord's bisector, the radius at least half it
   (gp-arc-to g sp o st r cw)
    (: segs (rev (sp 'segs))
       en (? (two? segs) (: s (<(rev segs)) (? (<s = 'abs) (s 1) (gp-add st (s 1)))) st)
       ctr (peep sp 'at ())
       (? (ctr != ())
           (pins o 'c ctr 'r (gp-len (gp-sub st ctr)) 'st st 'en en)
          (: m (gp-mid st en) h (gp-sub en st) dl (gp-len h)
             r2 (? (r < dl / 2) (dl / 2) r)
             k (sqrt (r2 * r2 - dl * dl / 4))
             n (? (dl = 0) [0.0 0.0] [((0 - h 1) / dl) (<h / dl)])
             c (? cw (gp-sub m (gp-mul n k)) (gp-add m (gp-mul n k)))
             (pins o 'c c 'r r2 'st st 'en en))))
   (gp-make-block g sp)
    (: os (sp 'objs)
       bb (foldl (\ b o (gp-bb-join b (gp-bbox o))) () os)
       bb2 (? (two? bb) bb [0.0 0.0 0.0 0.0])
       o {'ty 'block 'kw 'block 'w (bb2 2 - bb2 0) 'h (bb2 3 - bb2 1)
          'c [((bb2 0 + bb2 2) / 2) ((bb2 1 + bb2 3) / 2)] 'objs os 'labels (sp 'labels)}
       c0 (o 'c)
       _ (gp-common g sp o)
       ; the block moves by where its reference point should be less where it is
       fr (g 'fr) d (fr 'dir) half (? (gp-horiz? d) (o 'w / 2) (o 'h / 2))
       wv (peep sp 'with ())
       ref (? (wv = ()) c0 (string? <wv) (gp-with-at g o wv) (gp-add c0 wv))
       to (? (peep sp 'at () != ()) (sp 'at) (wv != ()) (fr 'here) (gp-add (fr 'here) (gp-mul (gp-unit d) half)))
       _ (gp-move o (p \ gp-add (gp-sub p ref) to))
       _ (pin fr 'here (gp-add (o 'c) (gp-mul (gp-unit d) half)))
       _ (gp-add-obj g o)
       o)

   ; -- statements -------------------------------------------------------------------
   (gp-closer? g i cl)
    (? (cl = "eof") (gp-k g i = 'eof) (gp-op? g i cl))
   (gp-elist g i cl)
    (: k (gp-k g i)
       (? (k = 'nl) (gp-elist g (i + 1) cl)
          (k = 'troff) (gp-add-obj g {'ty 'troff 'kw 'troff 'line (gp-v g i) 'ln (gp-t g i 2)}, gp-elist g (i + 1) cl)
          (gp-closer? g i cl) i
          (k = 'eof) (gp-syn g i)
          (: j (gp-element g i)
             (? (gp-closer? g j cl) j
                (gp-k g j = 'nl || gp-k g j = 'troff) (gp-elist g j cl)
                (pin g 'between 1, gp-syn g j)))))
   (gp-skip-nl g i) (? (gp-k g i = 'nl) (gp-skip-nl g (i + 1)) i)
   (gp-element g i)
    (: k (gp-k g i) v (gp-v g i) fr (g 'fr)
       (? (k = 'label && gp-op? g (i + 1) ":")
           ; A: B: .. labels one thing twice
           (: (names j acc) (? (gp-k g j = 'label && gp-op? g (j + 1) ":") (names (gp-skip-nl g (j + 2)) (gp-v g j . acc)) [acc j])
              ls (names i ())
              j (ls 1)
              r (gp-object g j)
              (label x) (map (nm \ pin (g 'fr 'labels) nm x) (ls 0))
              (? (two? r) (label (r 0), r 1)
                 (gp-position g j @ [p m] (label p, m) (gp-syn g j))))
          (k = 'word && elem v ["right" "left" "up" "down"]
               && (gp-k g (i + 1) = 'nl || gp-k g (i + 1) = 'eof || gp-k g (i + 1) = 'troff
                   || gp-op? g (i + 1) "]" || gp-op? g (i + 1) "}"))
           (pin fr 'dir (name v), i + 1)
          (k = 'word && (gp-op? g (i + 1) "=" || gp-op? g (i + 1) ":=") && !(elem v gp-reserved))
           (gp-expr g (i + 2) @ [e j] (gp-assign g v e (gp-op? g (i + 1) ":="), j) (gp-syn g (i + 2)))
          (gp-w? g i "figname" && gp-op? g (i + 1) "=")
           (pin g 'figname (gp-v g (i + 2)), i + 3)
          (gp-op? g i "{")
           (: h (fr 'here) d (fr 'dir)
              j (gp-elist g (i + 1) "}")
              _ (pins fr 'here h 'dir d)
              (j + 1))
          (gp-w? g i "reset") (gp-reset-stmt g (i + 1))
          (gp-w? g i "print") (gp-print g (i + 1))
          (gp-w? g i "command") (gp-command g (i + 1))
          (gp-w? g i "for") (gp-for g (i + 1))
          (gp-w? g i "if")
           (gp-expr g (i + 1) @ [e j]
             (? (gp-k g j = 'ifb)
                 (: b (gp-v g j) t (? (e != 0) <b <>b)
                    _ (? (string? t) (gp-push g (gp-src ("\n" + t + "\n") 'text 0)) 0)
                    (j + 1))
                (gp-syn g j))
             (gp-syn g (i + 1)))
          (k = 'sh) (gp-sh g v, i + 1)
          (: r (gp-object g i) (? (two? r) (r 1) (pin g 'between 1, gp-syn g i)))))
   (gp-assign g nm e local?)
    (? local?
        (: f (gp-find-var g nm)
           (? (tablet? f) (pin (f 'vars) nm (gp-fl e)) (gp-err g ("variable '" + nm + "' not defined"))))
       (nm = "scale") (gp-set-scale g e)
       (gp-setvar g nm e))
   (gp-reset-stmt g i)
    (: (go j acc) (? (gp-k g j = 'word && !(gp-default (gp-v g j) = ())) (go (j + 1) (gp-v g j . acc))
                     (gp-op? g j ",") (go (j + 1) acc)
                     [(rev acc) j])
       r (go i ())
       _ (? (two? (r 0)) (gp-reset g (r 0)) (gp-reset g (map (d \ <d) gp-defaults)))
       (r 1))
   ; print's and command's arguments, each text, a position or a number, run together
   (gp-args-text g i)
    (: (go j acc)
        (? (gp-k g j = 'nl || gp-k g j = 'eof || gp-op? g j "]" || gp-op? g j "}") [(cats (rev acc)) j]
           (gp-text g j @ [s k] (go k (s . acc))
             (: r (gp-position g j)
                (? (two? r) (go (r 1) (("(" + gp-g (r 0 0) + ", " + gp-g (r 0 1) + ")") . acc))
                   (gp-expr g j @ [e k] (go k (gp-g e . acc)) (gp-syn g j))))))
       (go i ()))
   (gp-print g i) (gp-args-text g i @ [s j] (say err (s + "\n"), j) ())
   (gp-command g i)
    (gp-args-text g i @ [s j] (gp-add-obj g {'ty 'troff 'kw 'troff 'line s 'ln (gp-t g i 2)}, j) ())
   (gp-sh g cmd)
    (? (g 'unsafe) (hark ["sh" "-c" cmd])
       (say err ("pic: error: unsafe to run command '" + cmd + "'; ignoring\n")))
   (gp-for g i)
    (: v (gp-v g i)
       _ (? (gp-k g i = 'word && gp-op? g (i + 1) "=") 0 (gp-syn g i))
       r1 (gp-expr g (i + 2))
       _ (? (two? r1 && gp-w? g (r1 1) "to") 0 (gp-syn g (i + 2)))
       r2 (gp-expr g (r1 1 + 1))
       _ (? (two? r2) 0 (gp-syn g (r1 1 + 1)))
       j (r2 1)
       by? (gp-w? g j "by")
       mul (by? && gp-op? g (j + 1) "*")
       r3 (? by? (gp-expr g (? mul (j + 2) (j + 1))) [1.0 j])
       _ (? (two? r3) 0 (gp-syn g j))
       k (r3 1)
       _ (? (gp-k g k = 'body) 0 (gp-syn g k))
       f {'var v 'to (r2 0) 'by (r3 0) 'mul mul}
       _ (gp-setvar g v (r1 0))
       ok (? (mul && r3 0 <= 0) 0 (gp-for-ok f (r1 0)))
       _ (? ok (: s (gp-src ("\n" + gp-v g k + "\n") 'for 0) _ (pin s 'for f) (gp-push g s)) 0)
       (k + 1))
   ; an object -> [object next] | ()
   (gp-object g i)
    (: k (gp-k g i) v (gp-v g i)
       (go sp j) (: m (gp-attrs g j sp) [(gp-make g sp) m])
       (? (k = 'word && gp-kind-word v != () ) (go (gp-spec (gp-kind-word v)) (i + 1))
          (gp-op? g i "[")
           (: fr0 (g 'fr) nf (gp-frame fr0)
              _ (pin nf 'dir (fr0 'dir))
              _ (pin g 'fr nf)
              _ (: k (gp-skip-nl g (i + 1)) (? (gp-op? g k "]") (gp-syn g k) 0))
              j (gp-elist g (i + 1) "]")
              _ (pin g 'fr fr0)
              sp (gp-spec 'block)
              _ (pins sp 'objs (rev (nf 'objs)) 'labels (nf 'labels))
              (go sp (j + 1)))
          (k = 'str || gp-w? g i "sprintf")
           (: sp (gp-spec 'text) (go sp i))
          ()))

   ; -- troff --------------------------------------------------------------------------
   ; the writer carries the page's transform ('llx 'ury 'sf) and the thickness and fill it
   ; last set, so it says each only when it moves
   (gp-o g s) (say (g 'o) s)
   (gp-X g p) ((<p - g 'llx) * g 'sf)
   (gp-Y g p) ((g 'ury - p 1) * g 'sf)
   (gp-at-p g p) ("\\h'" + gp-in (gp-X g p) + "'\\v'" + gp-in (gp-Y g p) + "'")
   (gp-d g a b) (gp-in (gp-X g b - gp-X g a) + " " + gp-in (gp-Y g b - gp-Y g a))
   ; a path's displacements, each from the point before
   (gp-join l) (? (atom? l) "" (foldl (\ a s (a + " " + s)) <l >l))
   (gp-ds g ps) (: (go l acc) (? (atom? >l) (gp-join (rev acc)) (go >l (gp-d g <l <>l . acc))) (go ps ()))
   (gp-draw g p cmd) (gp-o g (gp-at-p g p + "\\D'" + cmd + "'\n.sp -1\n"))
   (gp-thick g t)
    (? (g 'cthick = t || g 'nflag) 0
       (: _ (pin g 'cthick t)
          (gp-o g ("\\D't " + gp-3 t + "p'\\h'" + gp-3 (-1.0 * t) + "p'\n.sp -1\n"))))
   (gp-fillto g f)
    (? (g 'cfill = f || g 'nflag) 0
       (: _ (pin g 'cfill f)
          (gp-o g ("\\&\\D'Fg " + gp-3 (1.0 - f) + "'\n.sp -1\n"))))
   ; a line drawn solid, dashed or dotted
   (gp-seg g o a b)
    (: lt (o 'lt)
       (? (lt = 'dashed) (gp-dash g o a b)
          (lt = 'dotted) (gp-dots g o a b)
          (gp-draw g a ("l " + gp-d g a b))))
   (gp-dw g o) (: w (o 'dw) (? (w = ()) (gp-var g "dashwid") w))
   (gp-dash g o a b)
    (: v (gp-sub b a) l (gp-len v) w (gp-dw g o)
       (? (l = 0) 0
          (l <= w) (gp-draw g a ("l " + gp-d g a b))
          (: n (int ((l - w) / (2 * w) + 0.5))
             dv (gp-mul v (w / l)) gap ((l - w) / n)
             gv (gp-mul v (gap / l))
             (map (k \ (: s (gp-add a (gp-mul gv k)) (gp-draw g s ("l " + gp-d g s (gp-add s dv))))) ^(n + 1)))))
   (gp-dots g o a b)
    (: v (gp-sub b a) l (gp-len v) w (gp-dw g o)
       n (max 1 (int (l / w + 0.5)))
       (map (k \ gp-dot g (gp-add a (gp-mul v (k / n)))) ^(n + 1)))
   ; a dot: a line of no length, or without groff's extensions a period
   (gp-dot g p)
    (? (g 'nflag) (gp-o g ("\\h'" + gp-in (gp-X g p) + "-(\\w'.'u/2u)'\\v'" + gp-in (gp-Y g p) + "+0.04m'.\n.sp -1\n"))
       (gp-draw g p ("l " + gp-d g p p)))
   (gp-visible? o) !(o 'invis)
   (gp-text-at g o c)
    (: ts (o 'txt) n #ts
       (? (n = 0) 0
          (: _ (gp-thick g -1.0)
             (map (k \ (: t (ts k) s (t 's)
                          h (? (peep t 'ljust 0) ("\\h'" + gp-in (gp-X g c) + "'")
                               (peep t 'rjust 0) ("\\h'" + gp-in (gp-X g c) + "-\\w'" + s + "'u'")
                               ("\\h'" + gp-in (gp-X g c) + "-(\\w'" + s + "'u/2u)'"))
                          vv ("\\v'" + gp-in (gp-Y g c) + "-(" + show (n - 1) + "v/2u)+" + show k + "v+0.22m"
                              + (? (peep t 'above 0) "-.5v" (peep t 'below 0) "+.5v" "") + "'")
                          (gp-o g (".lf " + show (t 'ln) + "\n" + h + vv + s + "\n.sp -1\n"))))
                  (gp-said ts)))))
   ; the strings of a text that are said: an empty one keeps its place and draws nothing
   (gp-said ts) (filter (k \ 0 < #(ts k 's)) ^#ts)
   (gp-text-pos g o)
    (: ty (o 'ty)
       (? (ty = 'move) (o 'en) (elem ty ['line 'spline 'polygon]) (gp-mid (o 'st) (o 'en))
          (o 'c)))
   ; an arrowhead with its tip at p, pointing along u
   ; an arrowhead with its tip at p, pointing along u: solid, filled in the stroke's colour
   ; under a hairline, or two strokes whose tip stands back a quarter of the line's width
   (gp-head g o p u)
    (: l (gp-len u) e (? (l = 0) [1.0 0.0] (gp-mul u (1.0 / l)))
       b (gp-sub p (gp-mul e (o 'aht)))
       nrm [(-1.0 * e 1) (<e)]
       hw (o 'awid / 2)
       (? (o 'asolid)
           (: v1 (gp-sub b (gp-mul nrm hw)) v2 (gp-add b (gp-mul nrm hw))
              _ (gp-fillto g 1.0)
              _ (gp-draw g p ("P " + gp-ds g [p v1 v2]))
              _ (gp-thick g 0.1)
              (gp-draw g p ("p " + gp-ds g [p v1 v2])))
          (: k (gp-retreat o) p2 (gp-sub p (gp-mul e k)) b2 (gp-sub b (gp-mul e k))
             v1 (gp-sub b2 (gp-mul nrm hw)) v2 (gp-add b2 (gp-mul nrm hw))
             _ (gp-thick g (o 'thick))
             _ (gp-draw g v2 ("l " + gp-d g v2 p2))
             (gp-draw g v1 ("l " + gp-d g v1 p2)))))
   ; how far an open head's tip stands back: a quarter of the line's width
   (gp-retreat o) (: t (o 'thick) ((? (t < 0) 1.0 t) / 288))
   (gp-tr-obj g o)
    (: ty (o 'ty)
       _ (? (g 'mode = 'tex) (gp-tx-obj g o)
          (ty = 'troff) (gp-o g (".lf " + show (o 'ln) + "\n" + o 'line + "\n"))
          (ty = 'block) (map (x \ gp-tr-obj g x) (o 'objs))
          (ty = 'box) (? (0 < peep o 'rad 0.0 && !(g 'nflag && 0)) (gp-tr-rbox g o) (gp-tr-box g o))
          (ty = 'circle) (gp-tr-round g o "c" ("c " + gp-in (2 * o 'r * g 'sf)))
          (ty = 'ellipse) (gp-tr-round g o "e" ("e " + gp-in (o 'w * g 'sf) + " " + gp-in (o 'h * g 'sf)))
          (ty = 'arc) (gp-tr-arc g o)
          (elem ty ['line 'spline]) (gp-tr-line g o)
          0)
       (? (ty = 'troff || g 'mode = 'tex) 0 (gp-text-at g o (gp-text-pos g o))))
   (gp-tr-box g o)
    (: c (o 'c) x (o 'w / 2) y (o 'h / 2)
       se (gp-add c [x (0 - y)]) ne (gp-add c [x y]) nw (gp-add c [(0 - x) y]) sw (gp-add c [(0 - x) (0 - y)])
       vs [se ne nw sw]
       _ (? (o 'fill != () && !(g 'nflag)) (: _ (gp-fillto g (o 'fill)) (gp-draw g se ("P " + gp-ds g vs))) 0)
       (? !(gp-visible? o) 0
          (: _ (gp-thick g (o 'thick))
             (? (o 'lt = 'solid && !(g 'nflag)) (gp-draw g se ("p " + gp-ds g vs))
                (map (e \ gp-seg g o <e <>e) [[sw se] [se ne] [ne nw] [nw sw]])))))
   ; a box with round corners: filled as four discs and two bands, drawn as four quarter
   ; arcs and the four straights between them
   (gp-tr-rbox g o)
    (: c (o 'c) w (o 'w) h (o 'h) r (min (o 'rad) (min (w / 2) (h / 2)))
       x0 (<c - w / 2) x1 (<c + w / 2) y0 (c 1 - h / 2) y1 (c 1 + h / 2)
       hw (w / 2 - r) hh (h / 2 - r)
       ne (gp-add c [hw hh]) nw (gp-add c [(0 - hw) hh]) sw (gp-add c [(0 - hw) (0 - hh)]) se (gp-add c [hw (0 - hh)])
       (disc p) (gp-draw g [(<p - r) (p 1)] ("C " + gp-in (2 * r * g 'sf)))
       _ (? (o 'fill != () && !(g 'nflag))
             (: _ (gp-fillto g (o 'fill))
                _ (disc ne) _ (gp-thick g 1.0) _ (disc nw) _ (disc sw) _ (disc se)
                _ (gp-draw g [x1 (ne 1)] ("P " + gp-ds g [[x1 (ne 1)] [x0 (ne 1)] [x0 (se 1)] [x1 (se 1)]]))
                (gp-draw g [(<ne) y1] ("P " + gp-ds g [[(<ne) y1] [(<nw) y1] [(<nw) y0] [(<ne) y0]])))
             0)
       (arc s m e) (gp-draw g s ("a " + gp-d g s m + " " + gp-d g m e))
       (? !(gp-visible? o) 0
          (: _ (gp-thick g (o 'thick))
             _ (arc [x0 (y0 + r)] [(x0 + r) (y0 + r)] [(x0 + r) y0])
             _ (arc [(x0 + r) y1] [(x0 + r) (y1 - r)] [x0 (y1 - r)])
             _ (arc [x1 (y1 - r)] [(x1 - r) (y1 - r)] [(x1 - r) y1])
             _ (arc [(x1 - r) y0] [(x1 - r) (y0 + r)] [x1 (y0 + r)])
             (map (e \ gp-draw g <e ("l " + gp-d g <e <>e))
                  [[[x0 (y0 + r)] [x0 (y1 - r)]] [[(x0 + r) y1] [(x1 - r) y1]]
                   [[x1 (y1 - r)] [x1 (y0 + r)]] [[(x1 - r) y0] [(x0 + r) y0]]]))))
   (gp-tr-round g o f cmd)
    (: c (o 'c) at ("\\h'" + gp-in (gp-X g c - o 'w / 2 * g 'sf) + "'\\v'" + gp-in (gp-Y g c) + "'")
       (draw cmd) (gp-o g (at + "\\D'" + cmd + "'\n.sp -1\n"))
       _ (? (o 'fill != () && !(g 'nflag)) (: _ (gp-fillto g (o 'fill)) (draw (upper f + snip cmd 1 #cmd))) 0)
       (? !(gp-visible? o) 0 (: _ (gp-thick g (o 'thick)) (draw cmd))))
   ; an arc's head points from the arc's point its own length back round, and the arc
   ; stops there
   (gp-arc-base o p fwd)
    (: c (o 'c) r (o 'r) d (o 'aht / r)
       a (atan2 (p 1 - c 1) (<p - <c)) b (? fwd (a - d) (a + d))
       [(<c + r * cos b) (c 1 + r * sin b)])
   (gp-tr-arc g o)
    (? !(gp-visible? o) 0
       (: c (o 'c) ah (peep o 'ah 0) ccw !(o 'cw)
          st (o 'st) en (o 'en)
          bs (? (ah & 1) (gp-arc-base o st !ccw) st)
          be (? (ah & 2) (gp-arc-base o en ccw) en)
          _ (? (ah & 1) (gp-head g o st (gp-sub st bs)) 0)
          _ (? (ah & 2) (gp-head g o en (gp-sub en be)) 0)
          s (? (o 'asolid) bs st) e (? (o 'asolid) be en)
          a (? ccw s e) b (? ccw e s)
          _ (gp-thick g (o 'thick))
          (gp-draw g a ("a " + gp-d g a c + " " + gp-d g c b))))
   (gp-tr-line g o)
    (: ps (o 'pts) n #ps ah (peep o 'ah 0)
       vis (gp-visible? o) spl (o 'ty = 'spline)
       p0 (ps 0) p1 (ps 1) q1 (ps (n - 2)) q0 (ps (n - 1))
       (unit p q) (: v (gp-sub p q) l (gp-len v) (? (l = 0) [1.0 0.0] (gp-mul v (1.0 / l))))
       (base p q) (gp-sub p (gp-mul (unit p q) (o 'aht)))
       _ (? (vis && (ah & 1)) (gp-head g o p0 (gp-sub p0 p1)) 0)
       _ (? (vis && (ah & 2)) (gp-head g o q0 (gp-sub q0 q1)) 0)
       ; the line stops at a solid head's base (a spline a tenth of the way in), at an
       ; open one's tip
       (back p q) (gp-sub p (gp-mul (unit p q) (? (o 'asolid) (? spl (o 'aht / 10) (o 'aht)) (gp-retreat o))))
       ps2 (: a (? (ah & 1) (back p0 p1) p0) b (? (ah & 2) (back q0 q1) q0)
              (a . rev (b . >(rev >ps))))
       (? !vis 0
          (: _ (gp-thick g (o 'thick))
             (? spl (gp-draw g <ps2 ("~ " + gp-ds g ps2))
                (: (go l) (? (atom? >l) 0 (gp-seg g o <l <>l, go >l)) (go ps2))))))
   (gp-tr-picture g os args)
    (: bb (foldl (\ b o (gp-bb-join b (gp-bbox o))) () os)
       b (? (two? bb) bb [0.0 0.0 0.0 0.0])
       sc (gp-var g "scale")
       w0 ((b 2 - b 0) / sc) h0 ((b 3 - b 1) / sc)
       aw (: ws (gp-words args) (? (two? ws) (gem <ws) ())) ah (: ws (gp-words args) (? (two? >ws) (gem <>ws) ()))
       ; .PS wid ht fits the picture to them, a zero one aside; else maxpswid maxpsht
       ; bound it
       fw (? (aw != () && aw > 0 && w0 > 0) (aw / w0) ())
       fh (? (ah != () && ah > 0 && h0 > 0) (ah / h0) ())
       mw (gp-var g "maxpswid") mh (gp-var g "maxpsht")
       f (? (fw != () && fh != ()) (min fw fh) (fw != ()) fw (fh != ()) fh
            (w0 > mw || h0 > mh) (min (? (w0 > 0) (mw / w0) 1.0) (? (h0 > 0) (mh / h0) 1.0))
            1.0)
       _ (pins g 'llx (b 0) 'ury (b 3) 'sf (f / sc))
       W (w0 * f) H (h0 * f)
       _ (pins g 'W W 'H H)
       (? (g 'mode = 'tex) (gp-tx-picture g os) (gp-tr-frame g os args b)))
   (gp-tr-frame g os args b)
    (: W (g 'W) H (g 'H)
       _ (gp-o g (".PS " + gp-in H + " " + gp-in W + args + "\n"))
       _ (gp-o g (".\\\" " + gp-g (b 0) + " " + gp-g (b 1) + " " + gp-g (b 2) + " " + gp-g (b 3) + "\n"))
       _ (gp-o g (".\\\" " + gp-in (gp-X g [(b 0) (b 1)]) + " " + gp-in (gp-Y g [(b 0) (b 1)]) + " "
                  + gp-in (gp-X g [(b 2) (b 3)]) + " " + gp-in (gp-Y g [(b 2) (b 3)]) + "\n"))
       _ (gp-o g (".nr 00 \\n(.u\n.nf\n.nr 0x 1\n\\h'" + gp-in W + "'\n.sp -1\n"
                  + ".ds gpic*saved-stroke-color default\n.ds gpic*saved-fill-color default\n"
                  + ".if !'\\n[.m]'' .ds gpic*saved-stroke-color \\n[.m]\n"
                  + ".if !'\\n[.M]'' .ds gpic*saved-fill-color \\n[.M]\n"))
       _ (map (o \ gp-tr-obj g o) os)
       _ (gp-thick g -1.0)
       (gp-o g ((? (g 'top) "" (".sp " + gp-in H + "+1\n")) + ".if \\n(00 .fi\n.br\n.nr 0x 0\n"
                + ".gcolor \\*[gpic*saved-stroke-color]\n.fcolor \\*[gpic*saved-fill-color]\n")))

   ; -- TeX: tpic's specials ------------------------------------------------------------
   ; milli-inches, as C's (int)(x + .5) takes them
   (gp-mi v) (int (v * 1000.0 + 0.5))
   (gp-tin x) (gp-3 x + "in")
   (gp-sp g s) (gp-o g ("    \\special{" + s + "}%\n"))
   (gp-tx-xy g p) (show (gp-mi (gp-X g p)) + " " + show (gp-mi (gp-Y g p)))
   ; the pen, said when it moves: a width in milli-inches, 8 unless the line says
   (gp-pen g t) (gp-pen-n g (? (t < 0) 8 (int (t / 72.0 * 1000.0 + 0.5))))
   (gp-pen-n g n) (? (g 'cpen = n) 0 (: _ (pin g 'cpen n) (gp-sp g ("pn " + show n))))
   (gp-shade g f) (gp-sp g ("sh " + gp-3 f))
   (gp-tx-path g ps fin) (: _ (map (p \ gp-sp g ("pa " + gp-tx-xy g p)) ps) (gp-sp g fin))
   ; how a path ends: stroked, dashed, dotted, or filled unstroked
   (gp-tx-end g o)
    (: lt (o 'lt)
       (? (lt = 'dashed) ("da " + gp-3 (gp-dw g o)) (lt = 'dotted) ("dt " + gp-3 (gp-dw g o)) "fp"))
   (gp-tx-obj g o)
    (: ty (o 'ty) vis (gp-visible? o) fill (o 'fill != ())
       _ (? (ty = 'troff) (gp-o g (o 'line + "%\n"))
            (ty = 'block) (map (x \ gp-tx-obj g x) (o 'objs))
            (ty = 'box)
             (: c (o 'c) x (o 'w / 2) y (o 'h / 2)
                se (gp-add c [x (0 - y)]) ne (gp-add c [x y]) nw (gp-add c [(0 - x) y]) sw (gp-add c [(0 - x) (0 - y)])
                (? (vis || fill)
                    (: _ (? fill (gp-shade g (o 'fill)) 0) _ (gp-pen g (o 'thick))
                       (gp-tx-path g [sw se ne nw sw] (? vis (gp-tx-end g o) "ip")))
                   0))
            (ty = 'circle || ty = 'ellipse)
             (? (vis || fill)
                 (: _ (? fill (gp-shade g (o 'fill)) 0) _ (gp-pen g (o 'thick))
                    (gp-sp g ((? vis "ar " "ia ") + gp-tx-xy g (o 'c) + " " + show (gp-mi (o 'w / 2 * g 'sf))
                              + " " + show (gp-mi (o 'h / 2 * g 'sf)) + " 0 6.28319")))
                0)
            (ty = 'arc) (? vis (gp-tx-arc g o) 0)
            (elem ty ['line 'spline]) (? vis (gp-tx-line g o) 0)
            0)
       (? (ty = 'troff) 0 (gp-tx-text g o (gp-text-pos g o))))
   (gp-tx-text g o c)
    (: ts (o 'txt) n #ts
       (map (k \ (: t (ts k) s (t 's)
                    m (2 * k - (n - 1) + (? (peep t 'above 0) -1 0) + (? (peep t 'below 0) 1 0))
                    _ (? (m = 0) (gp-o g "    \\graphtemp=.5ex\n")
                         (gp-o g ("    \\graphtemp=\\baselineskip\n    \\multiply\\graphtemp by " + show m
                                  + "\n    \\divide\\graphtemp by 2\n    \\advance\\graphtemp by .5ex\n")))
                    box (? (peep t 'ljust 0) (s + "\\hss") (peep t 'rjust 0) ("\\hss " + s) ("\\hss " + s + "\\hss"))
                    (gp-o g ("    \\advance\\graphtemp by " + gp-tin (gp-Y g c) + "\n    \\rlap{\\kern " + gp-tin (gp-X g c)
                             + "\\lower\\graphtemp\\hbox to 0pt{" + box + "}}%\n"))))
            (gp-said ts)))
   ; a tpic arc runs clockwise down the page, so from the pic arc's end to its start
   (gp-tx-ang g c p) (-1.0 * atan2 (p 1 - c 1) (<p - <c))
   (gp-tx-arc g o)
    (: c (o 'c) ah (peep o 'ah 0) ccw !(o 'cw)
       st (o 'st) en (o 'en)
       bs (? (ah & 1) (gp-arc-base o st !ccw) st)
       be (? (ah & 2) (gp-arc-base o en ccw) en)
       _ (? (ah & 1) (gp-tx-head g o st (gp-sub st bs)) 0)
       _ (? (ah & 2) (gp-tx-head g o en (gp-sub en be)) 0)
       s (? (o 'asolid) bs st) e (? (o 'asolid) be en)
       a1 (gp-tx-ang g c (? ccw e s)) a2 (gp-tx-ang g c (? ccw s e))
       a3 (: (up a) (? (a < a1) (up (a + 2 * gp-pi)) a) (up a2))
       _ (gp-pen g (o 'thick))
       (gp-sp g ("ar " + gp-tx-xy g c + " " + show (gp-mi (o 'r * g 'sf)) + " " + show (gp-mi (o 'r * g 'sf))
                 + " " + gp-f a1 6 + " " + gp-f a3 6)))
   (gp-tx-head g o p u)
    (: l (gp-len u) e (? (l = 0) [1.0 0.0] (gp-mul u (1.0 / l)))
       b (gp-sub p (gp-mul e (o 'aht)))
       nrm [(-1.0 * e 1) (<e)]
       hw (o 'awid / 2)
       (? (o 'asolid)
           (: v1 (gp-sub b (gp-mul nrm hw)) v2 (gp-add b (gp-mul nrm hw))
              _ (gp-shade g 1.0) _ (gp-pen-n g 1)
              (gp-tx-path g [v2 p v1 v2] "fp"))
          (: k (gp-retreat o) p2 (gp-sub p (gp-mul e k)) b2 (gp-sub b (gp-mul e k))
             v1 (gp-sub b2 (gp-mul nrm hw)) v2 (gp-add b2 (gp-mul nrm hw))
             _ (gp-pen g (o 'thick))
             _ (gp-tx-path g [v2 p2] "fp")
             (gp-tx-path g [v1 p2] "fp"))))
   (gp-tx-line g o)
    (: ps (o 'pts) n #ps ah (peep o 'ah 0) spl (o 'ty = 'spline)
       p0 (ps 0) p1 (ps 1) q1 (ps (n - 2)) q0 (ps (n - 1))
       (unit p q) (: v (gp-sub p q) l (gp-len v) (? (l = 0) [1.0 0.0] (gp-mul v (1.0 / l))))
       _ (? (ah & 1) (gp-tx-head g o p0 (gp-sub p0 p1)) 0)
       _ (? (ah & 2) (gp-tx-head g o q0 (gp-sub q0 q1)) 0)
       (back p q) (gp-sub p (gp-mul (unit p q) (? (o 'asolid) (? spl (o 'aht / 10) (o 'aht)) (gp-retreat o))))
       ps2 (: a (? (ah & 1) (back p0 p1) p0) b (? (ah & 2) (back q0 q1) q0)
              (a . rev (b . >(rev >ps))))
       _ (gp-pen g (o 'thick))
       (gp-tx-path g ps2 (? spl (: lt (o 'lt) (? (lt = 'solid) "sp" ("sp " + gp-3 (gp-dw g o)))) (gp-tx-end g o))))
   (gp-tx-picture g os)
    (: nm (g 'figname) W (g 'W) H (g 'H)
       _ (pin g 'cpen ())
       _ (gp-o g ("\\expandafter\\ifx\\csname " + nm + "\\endcsname\\relax\n"
                  + "   \\csname newbox\\expandafter\\endcsname\\csname " + nm + "\\endcsname\n\\fi\n"
                  + "\\ifx\\graphtemp\\undefined\n  \\csname newdimen\\endcsname\\graphtemp\n\\fi\n"
                  + "\\expandafter\\setbox\\csname " + nm + "\\endcsname\n =\\vtop{\\vskip 0pt\\hbox{%\n"))
       _ (map (o \ gp-tx-obj g o) os)
       (gp-o g ("    \\hbox{\\vrule depth" + gp-tin H + " width0pt height 0pt}%\n    \\kern " + gp-tin W
                + "\n  }%\n}%\n")))

   ; -- a picture ----------------------------------------------------------------------
   (gp-new-root g)
    (: fr (gp-frame ())
       _ (map (d \ pin (fr 'vars) <d <>d) gp-defaults)
       fr)
   ; the picture's lines run and written -> 1 when it drew, 0 when empty; an error gives up
   ; a picture given up: said, and pic will leave 1. a syntax error inside a line still
   ; draws what came before it (2), one at a line's end or a missing place draws nothing
   (gp-gave-up g nm m args)
    (: ln (? (g 'errk = ()) (gp-line g) (g 'errln))
       _ (say err ("pic:" + nm + ":" + show ln + ": error: " + m + "\n"
                   + "pic:" + nm + ":" + show ln + ": error: giving up on this picture\n"))
       _ (pin g 'status 1)
       os (rev (g 'fr 'objs))
       (? (!(g 'between) || atom? os) -1 (: _ (gp-tr-picture g os args) 2)))
   (gp-picture g body psln args)
    (: _ (pins g 'fr (gp-new-root g) 'srcs [(gp-src body 'file (psln + 1))] 'tk (tablet 0) 'nt 0 'forp 0 'ifp 0
               'errk () 'between 0)
       _ (gp-elist g 0 "eof")
       os (rev (g 'fr 'objs))
       (? (atom? os) 0
          (: _ (gp-tr-picture g os args) 1)))

   ; -- the document -------------------------------------------------------------------
   (gp-starts? l w) (#w <= #l && snip l 0 #w = w)
   ; a .PS, .PE line: the macro and then a blank or the end, or anything with -C
   (gp-macro? g l w) (gp-starts? l w && (#l = #w || g 'Cflag || gp-blank? (l #w)))
   (gp-end? g l) (gp-macro? g l ".PE" || gp-macro? g l ".PF" || gp-macro? g l ".PY")
   (gp-doc g nm text)
    (: ls (lines text) n #ls
       _ (? (g 'mode = 'troff) (gp-o g (".lf " + show (g 'prevln) + " \"" + nm + "\n")) 0)
       _ (pin g 'name nm)
       (go ls k)
        (? (atom? ls) 0
           (gp-macro? g <ls ".PS")
            (: args (snip <ls 3 #(<ls))
               (body l j acc) (? (atom? l) [(rev acc) () j l]
                                 (gp-end? g <l) [(rev acc) <l j >l]
                                 (body >l (j + 1) (<l . acc)))
               r (body >ls (k + 1) ())
               bl (r 0) pe (r 1) pk (r 2)
               _ (pin g 'top (string? pe && !(gp-macro? g pe ".PE")))
               t (cats (map (x \ x + "\n") bl))
               tex (g 'mode = 'tex)
               _ (? tex 0 (gp-o g (".lf " + show k + "\n")))
               o0 (g 'o)
               _ (pin g 'o (jug 0))
               drew (trap (_ \ gp-picture g t k args) ()
                          (\ a m (a @ 'gp-err (gp-gave-up g nm m args) (scare a m))))
               pic (slurp (g 'o))
               _ (pin g 'o o0)
               endln (? (drew = 2) (g 'errln) pk)
               _ (? (drew < 1) 0 tex (gp-o g pic)
                    (gp-o g (pic + ".lf " + show endln + "\n" + (? (string? pe) pe ".PE") + "\n")))
               _ (? tex 0 (gp-o g (".lf " + show (pk + 1) + "\n")))
               (go (r 3) (pk + 1)))
           (: _ (gp-o g (<ls + "\n")) (go >ls (k + 1))))
       _ (go ls 1)
       (pin g 'prevln (n + 1)))

   (gpic-main as) (gpic-run as ())
   ; stdin already read (by pic's sniffing) comes as sin
   (gpic-run as sin) (gp-run as sin @ [st t] (say out t, flush out, st) 0)
   ; a run -> [status output]: 0, 1 when a picture was given up, 3 when a file would not
   ; open (what came before it still written). a stranger flag is warned of and let be
   (gp-run as sin)
    (: g {'mode 'troff 'nflag 0 'cflag 0 'zflag 0 'unsafe 0 'Cflag 0 'status 0 'prevln 0
          'macros (tablet 0) 'o (jug 0) 'figname "graph" 'seed 1}
       (flag c) (? (c = 110) (pin g 'nflag 1) (c = 116) (pin g 'mode 'tex)
                   (c = 99) (pins g 'cflag 1 'mode 'tex) (c = 122) (pin g 'zflag 1)
                   (c = 67) (pin g 'Cflag 1) (c = 83) (pins g 'unsafe 0 'safe 1)
                   (c = 85) (? (peep g 'safe 0) 0 (pin g 'unsafe 1))
                   (c = 68 || c = 84) 0
                   (say err ("pic: warning: command-line option '-" + string c + "' is obsolete; ignoring\n")))
       (flags l)
        (? (atom? l) ()
           (<l = "--") >l
           (<l = "-" || !(gp-starts? <l "-")) l
           (<l = "-T") (flags >>l)
           (: w <l _ (map (k \ flag (w (k + 1))) ^(#w - 1)) (flags >l)))
       fs (flags as)
       _ (? (g 'mode = 'troff)
            (gp-o g ".do if !dPS .ds PS\n.do if !dPE .ds PE\n.do if !dPF .ds PF\n.do if !dPY .ds PY\n") 0)
       (go l) (? (atom? l) 0
                 (: f <l
                    t (? (f = "-") (? (string? sin) sin (slurp in)) (: r (uread f) (? (two? r) <>r ())))
                    (? (string? t) (gp-doc g f t, go >l)
                       (: _ (say err ("pic: fatal error: cannot open '" + f + "': No such file or directory\n"))
                          (pin g 'status 3)))))
       _ (go (? (two? fs) fs ["-"]))
       [(g 'status) (slurp (g 'o))])
)
) ; module 'kore
