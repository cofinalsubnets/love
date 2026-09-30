; src/apps/kore/grap.l -- grap, kernighan and bentley's language for graphs: a troff
; preprocessor whose graphs, each between .G1 and .G2, become pictures in classic pic for
; pic (src/apps/kore/gpic.l) to draw. held to plan 9's grap byte for byte
; (test/gate/grap.sh), learned by asking it, never by reading it.
;
;   grap [FILE..]
;
; a graph is read and run statement by statement: the lexer expands macros, copy and the
; bodies of for and if as text. what a graph draws goes out in order, after its coordinate
; systems' macros, its frame and its automatic ticks, which wait for the graph's end.
(module 'kore
(borrow 'posix)

(:
   ; -- tables (at the head: a value binding sees only those above it) ------------------
   gr-defines-path "/usr/lib/plan9/lib/grap.defines"
   ; the marks plan 9 defines there, for a host without the file
   gr-defines (cats ["define\tbullet\t% \"\\s-5\\(bu\\s0\" %\n"
                     "define\tplus\t% \"\\s-3\\(pl\\s0\" %\n"
                     "define\tbox\t% \"\\s-4\\(bx\\s0\" %\n"
                     "define\tstar\t% \"\\(**\" %\n"
                     "define\tdot\t% \"\\v'-.2m'\\s+4.\\s0\\v'.2m'\" %\n"
                     "define\ttimes\t% \"\\s-3\\(mu\\s0\" %\n"
                     "define\thtick\t% \"\\-\" %\n"
                     "define\tvtick\t% \"\\(or\" %\n"
                     "define\tsquare\t% \"\\s-3\\(sq\\s0\" %\n"
                     "define\tdelta\t% \"\\s-3\\(*D\\s0\" %\n"])
   gr-ops ["==" "!=" "<=" ">=" "&&" "||"]
   gr-funcs ["log" "exp" "sin" "cos" "sqrt" "atan2" "max" "min" "int" "rand"]
   ; a line's styles and how pic spells them
   gr-styles {"solid" "" "dotted" "dotted" "dashed" "dashed" "invis" "invis"}
   gr-sides {"bot" 'bot "bottom" 'bot "top" 'top "left" 'left "right" 'right}
   gr-huge 1e30
   ; words a linedesc's expression cannot begin with
   gr-kw ["at" "from" "to" "by" "in" "out" "off" "on" "ht" "wid" "width" "up" "down" "left" "right"
          "top" "bot" "bottom" "ljust" "rjust" "above" "below" "x" "y" "log" "rad" "radius" "until"
          "thru" "dotted" "dashed" "invis" "solid" "sprintf"]

   ; -- numbers --------------------------------------------------------------------
   (gr-fl x) (x * 1.0)
   (gr-neg0? x) (x = 0 && 1 / (gr-fl x) < 0)
   ; %g, a negative zero signed as C signs it
   (gr-g x) (? (gr-neg0? x) "-0" (aw-gen (gr-fl x) 6))
   (gr-f2 x) (aw-fixed x 2)
   (gr-bits n) (: (go k p) (? (n < p) k (go (k + 1) (p * 2))) (go 0 1))
   ; the double nearest n/d, ties to even (n an integer of either sign, d > 0)
   (gr-dbl n d)
    (? (n = 0) 0.0
       (n < 0) (-1.0 * gr-dbl (0 - n) d)
       (: k0 (53 - (gr-bits n - gr-bits d))
          (at k) (? (0 <= k) [(n * 2 ** k) d] [n (d * 2 ** (0 - k))])
          (fit k) (: r (at k) q (<r // (r 1)) (? (q < 4503599627370496) (fit (k + 1)) (9007199254740992 <= q) (fit (k - 1)) k))
          k (fit k0)
          r (at k) a <r b (r 1) q (a // b) rm (a - q * b)
          q2 (? (b < 2 * rm || (2 * rm = b && q % 2 = 1)) (q + 1) q)
          (? (q2 = 9007199254740992) (gr-fl (4503599627370496 * 2.0 ** (1 - k)))
             ((q2 * 1.0) * 2.0 ** (0 - k)))))
   ; a double as n/d exactly, the sign on n
   (gr-rat x) (: a (abs x) r (aw-exact a) (? (x < 0) [(0 - <r) (r 1)] r))
   ; fixed point: a real times 2^gr-p, an integer
   gr-p 136
   gr-one (2 ** gr-p)
   ; 2 atanh(n/d) in fixed point, |n/d| small
   (gr-atanh2 n d)
    (: t ((n * gr-one) // d) n2 (n * n) d2 (d * d)
       (go pw k acc) (? (pw = 0) (2 * acc) (go ((pw * n2) // d2) (k + 2) (acc + pw // k)))
       (go t 1 0))
   gr-ln2 (gr-atanh2 1 3)
   gr-ln10 (3 * gr-ln2 + gr-atanh2 1 9)
   ; ln(n/d) in fixed point, n/d > 0
   (gr-lnq n d)
    (: e0 (gr-bits n - gr-bits d)
       ; n/d over 2^e in [0.75, 1.5)
       (red e) (: a (? (0 <= e) n (n * 2 ** (0 - e))) b (? (0 <= e) (d * 2 ** e) d)
                  (? (3 * b <= 2 * a) (red (e + 1)) (4 * a < 3 * b) (red (e - 1)) [a b e]))
       r (red e0)
       (gr-atanh2 (<r - r 1) (<r + r 1) + r 2 * gr-ln2))
   ; e^(f / 2^gr-p) as n/d
   (gr-expq f)
    (: k (? (0 <= f) ((2 * f + gr-ln2) // (2 * gr-ln2)) (0 - ((2 * (0 - f) + gr-ln2) // (2 * gr-ln2))))
       r (f - k * gr-ln2)
       (go term j acc) (? (term = 0) acc (go ((term * r) // (j * gr-one)) (j + 1) (acc + term)))
       s (go gr-one 1 0)
       (? (0 <= k) [(s * 2 ** k) gr-one] [s (gr-one * 2 ** (0 - k))]))
   ; the natural log and the powers, each the double nearest the true value, as glibc's are
   (gr-ln x) (? (x <= 0) (scare 'gr-err "log of a number not above zero")
                (: r (gr-rat x) (gr-dbl (gr-lnq <r (r 1)) gr-one)))
   ; e^(f / 2^gr-p) as the nearest double, out of range said
   (gr-expd f)
    (? (gr-one * 710 < f) (scare 'gr-err "exp overflow")
       (f < gr-one * -745) 0.0
       (: q (gr-expq f) (gr-dbl <q (q 1))))
   (gr-pow10 y) (: r (gr-rat y) (gr-expd ((<r * gr-ln10) // (r 1))))
   (gr-pow a b)
    (? (a = 0) (? (b > 0) 0.0 (scare 'gr-err "pow of zero"))
       (a < 0) (: m (gr-pow (0 - a) b) (? (b = floor b && (int b) % 2 != 0) (0 - m) m))
       (: ra (gr-rat a) rb (gr-rat b)
          (gr-expd ((<rb * gr-lnq <ra (ra 1)) // (rb 1)))))
   ; log10 as glibc's: the power of two apart, log's rest in two pieces
   (gr-log10 x)
    (: _ (? (x <= 0) (scare 'gr-err "log of a number not above zero") 0)
       r (gr-rat x) e (gr-bits <r - gr-bits (r 1))
       k (? (x < 2.0 ** e) (e - 1) e)
       i (? (k < 0) 1 0)
       xm (? (0 <= k + i) (gr-dbl <r ((r 1) * 2 ** (k + i))) (gr-dbl (<r * 2 ** (0 - k - i)) (r 1)))
       y (gr-fl (k + i))
       z (y * 3.69423907715893078616e-13 + 4.34294481903251816668e-01 * gr-ln xm)
       (z + y * 3.01029995663611771306e-01))
   ; a numeral as the nearest double, as atof reads it
   (gr-atof t)
    (: n #t
       (dig? c) (48 <= c <= 57)
       (go i m f) (? (i < n && dig? (t i)) (go (i + 1) (m * 10 + t i - 48) f) [i m f])
       a (go 0 0 0)
       b (? (<a < n && t <a = 46) (: (fr i m f) (? (i < n && dig? (t i)) (fr (i + 1) (m * 10 + t i - 48) (f + 1)) [i m f]) (fr (<a + 1) (a 1) 0)) a)
       i <b m (b 1) f (b 2)
       ex (? (i < n && (t i = 101 || t i = 69))
             (: sg (? (t (i + 1) = 45) -1 1) j (? (t (i + 1) = 45 || t (i + 1) = 43) (i + 2) (i + 1))
                (: (go2 k v) (? (k < n && dig? (t k)) (go2 (k + 1) (v * 10 + t k - 48)) v) (sg * go2 j 0)))
             0)
       p (ex - f)
       (? (m = 0) 0.0 (0 <= p) (gr-dbl (m * 10 ** p) 1) (gr-dbl m (10 ** (0 - p)))))

   ; -- errors ------------------------------------------------------------------
   (gr-err g m) (scare 'gr-err m)

   ; -- the lexer: sources -----------------------------------------------------------
   ; a source is text read left to right: 'file the graph's own lines (a line opening with
   ; a dot not before a figure is troff's), 'text a macro's or a body's expansion, 'for a
   ; loop's body, which runs again while the loop holds
   (gr-src t k) {'t t 'i 0 'k k 'bol 1 'ln 0}
   (gr-top g) (: s (g 'srcs) (? (two? s) <s ()))
   (gr-push g s) (pin g 'srcs (s . g 'srcs))
   (gr-pop g) (pin g 'srcs >(g 'srcs))
   (gr-at s k) (: i (s 'i + k) (? (i < #(s 't)) (s 't i) -1))
   (gr-c g) (: s (gr-top g) (? !(tablet? s) -1 (gr-at s 0)))
   (gr-c1 g) (: s (gr-top g) (? !(tablet? s) -1 (gr-at s 1)))
   (gr-adv g) (: s (gr-top g) c (gr-at s 0)
                 _ (pin s 'i (s 'i + 1))
                 _ (? (c = 10) (pin s 'ln (s 'ln + 1)) 0)
                 (pin s 'bol (c = 10)))
   ; the line of the document the lexer is on, under any expansion
   (gr-fline g) (: f (peep g 'fsrc ()) (? (tablet? f) (f 'ln) 0))
   (gr-dig? c) (48 <= c <= 57)
   (gr-alpha? c) ((65 <= c <= 90) || (97 <= c <= 122) || c = 95)
   (gr-wc? c) (gr-alpha? c || gr-dig? c)
   (gr-blank? c) (c = 32 || c = 9)
   ; the text up to a newline (not taken)
   (gr-rest-line g)
    (: o (jug 0)
       (go _) (: c (gr-c g) (? (c < 0 || c = 10) (slurp o) (put o c, gr-adv g, go 0)))
       (go 0))
   (gr-skip-blanks g) (? (gr-blank? (gr-c g)) (gr-adv g, gr-skip-blanks g) 0)
   (gr-skip-space g)
    (: c (gr-c g) (? (gr-blank? c || c = 10) (gr-adv g, gr-skip-space g) 0))
   (gr-word g)
    (: o (jug 0)
       (go _) (? (gr-wc? (gr-c g)) (put o (gr-c g), gr-adv g, go 0) (slurp o))
       (go 0))
   ; a quoted string, the quote taken: \" stays as it is written, the quote kept
   (gr-string g)
    (: o (jug 0)
       (go _) (: c (gr-c g)
                 (? (c < 0 || c = 10) (gr-err g "newline in string")
                    (c = 34) (gr-adv g, slurp o)
                    (c = 92 && 0 <= gr-c1 g) (gr-adv g, put o 92, put o (gr-c g), gr-adv g, go 0)
                    (put o c, gr-adv g, go 0)))
       (go 0))
   ; a delimited body: {..} nested, or any other character to its twin
   (gr-delim g)
    (: _ (gr-skip-space g)
       d (gr-c g) o (jug 0)
       _ (? (d < 0) (gr-err g "missing delimiter") (gr-adv g))
       cl (? (d = 123) 125 d)
       (go n) (: c (gr-c g)
                 (? (c < 0) (gr-err g "end of file in a delimited body")
                    (c = cl && n = 0) (gr-adv g, slurp o)
                    (d = 123 && c = 123) (put o c, gr-adv g, go (n + 1))
                    (d = 123 && c = 125) (put o c, gr-adv g, go (n - 1))
                    (put o c, gr-adv g, go n)))
       (go 0))
   ; a numeral's text
   (gr-numeral g)
    (: o (jug 0)
       (digs _) (? (gr-dig? (gr-c g)) (put o (gr-c g), gr-adv g, digs 0) 0)
       _ (digs 0)
       _ (? (gr-c g = 46) (put o 46, gr-adv g, digs 0) 0)
       c (gr-c g) c1 (gr-c1 g)
       _ (? ((c = 101 || c = 69) && (gr-dig? c1 || ((c1 = 43 || c1 = 45) && gr-dig? (gr-at (gr-top g) 2))))
            (put o c, gr-adv g, (? (gr-dig? (gr-c g)) 0 (put o (gr-c g), gr-adv g)), digs 0) 0)
       (slurp o))

   ; -- the lexer: macros, copy ----------------------------------------------------
   ; $1..$9 in a body, each its argument, a missing one nothing
   (gr-subst b as)
    (: o (jug 0) n #b
       (go i) (? (n <= i) (slurp o)
                 (b i = 36 && i + 1 < n && gr-dig? (b (i + 1)))
                  (: (dend j v) (? (j < n && gr-dig? (b j)) (dend (j + 1) (v * 10 + b j - 48)) [j v])
                     r (dend (i + 1) 0)
                     k <>r
                     _ (? (0 < k && k <= #as) (say o (as (k - 1))) 0)
                     (go <r))
                 (put o (b i), go (i + 1)))
       (go 0))
   ; a call's arguments, the ( taken: split at commas outside parens and strings
   (gr-args g)
    (: (go o n acc) (: c (gr-c g)
                       (? (c < 0) (gr-err g "end of file in macro arguments")
                          (c = 34) (put o c, gr-adv g, gr-strraw g o, go o n acc)
                          (c = 40) (put o c, gr-adv g, go o (n + 1) acc)
                          (c = 41 && n = 0) (gr-adv g, rev (slurp o . acc))
                          (c = 41) (put o c, gr-adv g, go o (n - 1) acc)
                          (c = 44 && n = 0) (gr-adv g, go (jug 0) n (slurp o . acc))
                          (put o c, gr-adv g, go o n acc)))
       (go (jug 0) 0 ()))
   ; the rest of a string into o, raw, the closing quote kept
   (gr-strraw g o)
    (: c (gr-c g)
       (? (c < 0) 0
          (c = 34) (put o c, gr-adv g)
          (c = 92) (put o c, gr-adv g, (? (0 <= gr-c g) (put o (gr-c g), gr-adv g) 0), gr-strraw g o)
          (put o c, gr-adv g, gr-strraw g o)))
   (gr-define g)
    (: _ (gr-skip-space g)
       nm (gr-word g)
       _ (? (#nm = 0) (gr-err g "bad macro name") 0)
       (pin (g 'macros) nm (gr-delim g)))
   ; words split on blanks
   (gr-words s)
    (: n #s
       (go i acc) (? (n <= i) (rev acc)
                     (gr-blank? (s i)) (go (i + 1) acc)
                     (: (e j) (? (j < n && !(gr-blank? (s j))) (e (j + 1)) j)
                        j (e i) (go j (snip s i j . acc))))
       (go 0 ()))
   (gr-looking? s w) (: n #w (go k) (? (n <= k) 1 (gr-at s k = w k) (go (k + 1)) 0) (go 0))
   (gr-take-word g w) (: s (gr-top g) (? (gr-looking? s w && !(gr-wc? (gr-at s #w))) (map (_ \ gr-adv g) ^#w, 1) 0))
   ; copy "file", copy [file] thru body|macro [until "word"]: laid out as text and pushed
   (gr-copy g)
    (: _ (gr-skip-blanks g)
       file (? (gr-c g = 34) (gr-adv g, gr-string g) ())
       _ (gr-skip-blanks g)
       thru (? (gr-take-word g "thru")
               (: _ (gr-skip-blanks g)
                  c (gr-c g)
                  (? (gr-alpha? c)
                      (: s2 (gr-top g) i0 (s2 'i) w (gr-word g) m (peep (g 'macros) w ())
                         (? (string? m) m (pin s2 'i i0, gr-delim g)))
                     (gr-delim g)))
               ())
       _ (gr-skip-blanks g)
       until (? (gr-take-word g "until")
                (: _ (gr-skip-blanks g) (? (gr-c g = 34) (gr-adv g, gr-string g) (gr-word g)))
                ())
       text (? (string? file)
                (: r (uread file) (? (two? r) <>r (gr-err g ("can't open file " + file))))
                ())
       (? !(string? thru)
           (? (string? file) (gr-push-file g file text) 0)
          (: ls (? (string? file) (lines text) (gr-take-lines g until))
             ls2 (? (string? file) (gr-cut-until ls until) ls)
             body (cats (map (l \ gr-subst thru (gr-words l) + "\n") ls2))
             (? (string? file) (gr-push-file g file body) (gr-push g (gr-src body 'text))))))
   ; a file's text pushed: troff hears of it, and of where the graph goes on after it
   (gr-push-file g file t)
    (: _ (gr-o0 g (".lf 1 " + file + "\n"))
       s (gr-src t 'text)
       _ (pin s 'endlf (".lf " + show (gr-fline g + g 'skew) + " " + g 'name + "\n"))
       (gr-push g s))
   (gr-cut-until ls w)
    (? (!(string? w) || atom? ls) ls
       (: ws (gr-words <ls) (? (two? ws && <ws = w) () (<ls . gr-cut-until >ls w))))
   ; the lines after this one, off the graph, up to one opening with w (taken, not kept)
   ; or the end
   (gr-take-lines g w)
    (: _ (gr-rest-line g) _ (? (gr-c g = 10) (gr-adv g) 0)
       (go acc) (? (gr-c g < 0) (rev acc)
                   (: l (gr-rest-line g) _ (? (gr-c g = 10) (gr-adv g) 0)
                      ws (gr-words l)
                      (? (string? w && two? ws && <ws = w) (rev acc) (go (l . acc)))))
       (go ()))

   ; -- the lexer ------------------------------------------------------------------
   ; a token is [kind value]: 'num 'str 'name 'op 'nl 'eof 'troff 'pic 'body 'ifb 'sh
   (gr-lex g)
    (: s (gr-top g) ln (gr-fline g)
       (tok k v) [k v ln]
       (? !(tablet? s) (tok 'eof ())
          (#(s 't) <= s 'i)
           (? (s 'k = 'file) (tok 'eof ())
              (s 'k = 'for) (? (gr-for-next g s) (gr-lex g) (gr-pop g, gr-lex g))
              (: _ (? (peep s 'endlf ()) (gr-o0 g (s 'endlf)) 0) _ (gr-pop g) (gr-lex g)))
          (: c (gr-c g) c1 (gr-c1 g)
             (? ((s 'bol) && c = 46 && !(gr-dig? c1))
                 (: t (gr-rest-line g) _ (? (gr-c g = 10) (gr-adv g) 0) (tok 'troff t))
                (gr-blank? c) (gr-adv g, gr-lex g)
                (c = 92 && c1 = 10) (gr-adv g, gr-adv g, gr-lex g)
                (c = 35) (gr-rest-line g, gr-lex g)
                (c = 10) (gr-adv g, tok 'nl "\n")
                (c = 59) (gr-adv g, tok 'nl ";")
                (gr-dig? c || (c = 46 && gr-dig? c1)) (tok 'num (gr-atof (gr-numeral g)))
                (c = 34) (gr-adv g, tok 'str (gr-string g))
                (gr-alpha? c) (gr-lex-word g (gr-word g) tok)
                (: op (: (go l) (? (atom? l) (string c) (gr-looking? s <l) <l (go >l))
                         (go gr-ops))
                   _ (map (_ \ gr-adv g) ^#op)
                   (tok 'op op))))))
   (gr-lex-word g w tok)
    (: m (peep (g 'macros) w ())
       (? (string? m)
           (: as (? (gr-c g = 40) (gr-adv g, gr-args g) ())
              _ (gr-push g (gr-src (gr-subst m as) 'text))
              (gr-lex g))
          (w = "define") (gr-define g, gr-lex g)
          (w = "copy") (gr-copy g, gr-lex g)
          (w = "for") (pin g 'forp 1, tok 'name w)
          (w = "if") (pin g 'ifp 1, tok 'name w)
          (w = "do" && g 'forp) (pin g 'forp 0, tok 'body (gr-delim g))
          (w = "then" && g 'ifp)
           (: _ (pin g 'ifp 0)
              a (gr-delim g)
              _ (gr-skip-space g)
              e (? (gr-take-word g "else") (gr-delim g) ())
              (tok 'ifb [a e]))
          (w = "sh") (tok 'sh (gr-delim g))
          (w = "pic") (: _ (gr-skip-blanks g) (tok 'pic (gr-rest-line g)))
          (tok 'name w)))
   ; a loop's body is spent: step the variable and say whether to go round again
   (gr-for-next g s)
    (: f (s 'for) v (gr-var g (f 'var))
       v2 (gr-step (f 'op) v (f 'by))
       _ (gr-setvar g (f 'var) v2)
       (? (gr-for-ok f v2) (pins s 'i 0 'bol 0, 1) 0))
   (gr-step op v by) (op @ "*" (v * by) "/" (v / by) "-" (v - by) (v + by))
   ; a tick's value as a label: troff's minus on a negative one
   (gr-tnum v) (? (v < 0) ("\\-" + gr-g (0.0 - v)) (gr-g v))
   (gr-down? op by) (op @ "*" (by < 1) "/" (by > 1) "-" (by > 0) (by < 0))
   (gr-for-ok f v) (? (f 'down) (f 'to <= v) (v <= f 'to))

   ; -- tokens ---------------------------------------------------------------------
   ; a few tokens looked ahead; a statement never looks past its end
   (gr-t g k)
    (: la (g 'la)
       (? (k < #la) (la k)
          (: _ (pin g 'la (la + [(gr-lex g)])) (gr-t g k))))
   (gr-k g k) (gr-t g k 0)
   (gr-v g k) (gr-t g k 1)
   (gr-next g) (: t (gr-t g 0) _ (pin g 'la >(g 'la)) t)
   (gr-drop g n) (? (n < 1) 0 (: _ (gr-next g) (gr-drop g (n - 1))))
   (gr-op? g k o) (gr-k g k = 'op && gr-v g k = o)
   (gr-w? g k w) (gr-k g k = 'name && gr-v g k = w)
   (gr-syn g) (: t (gr-t g 0) _ (pin g 'errln (t 2)) (gr-err g "syntax error"))
   (gr-want-op g o) (? (gr-op? g 0 o) (gr-next g) (gr-syn g))
   (gr-end? g) (elem (gr-k g 0) ['nl 'eof])

   ; -- variables ---------------------------------------------------------------------
   (gr-var g nm) (peep (g 'vars) nm 0.0)
   (gr-setvar g nm v) (pin (g 'vars) nm (gr-fl v))

   ; -- expressions --------------------------------------------------------------
   (gr-truth b) (? b 1.0 0.0)
   (gr-apply g o a b)
    (o @ "||" (gr-truth (a != 0 || b != 0))
         "&&" (gr-truth (a != 0 && b != 0))
         "==" (gr-truth (a = b)) "!=" (gr-truth (a != b))
         "<" (gr-truth (a < b)) ">" (gr-truth (a > b))
         "<=" (gr-truth (a <= b)) ">=" (gr-truth (a >= b))
         "+" (a + b) "-" (a - b) "*" (a * b)
         "/" (? (b = 0) (gr-err g "division by zero") (gr-fl a / b))
         "%" (? (b = 0) (gr-err g "modulus by zero") (gr-fl a % gr-fl b))
         0)
   (gr-left g sub ops)
    (: (go v) (? (gr-k g 0 = 'op && elem (gr-v g 0) ops)
                 (: o (gr-v g 0) _ (gr-next g) (go (gr-apply g o v (sub g))))
                 v)
       (go (sub g)))
   (gr-expr g) (gr-left g gr-and ["||"])
   (gr-and g) (gr-left g gr-eq ["&&"])
   (gr-eq g) (gr-left g gr-rel ["==" "!="])
   (gr-rel g) (gr-left g gr-add ["<" ">" "<=" ">="])
   (gr-add g) (gr-left g gr-mul ["+" "-"])
   (gr-mul g) (gr-left g gr-unary ["*" "/" "%"])
   (gr-unary g)
    (? (gr-op? g 0 "-") (: _ (gr-next g) (-1.0 * gr-unary g))
       (gr-op? g 0 "+") (: _ (gr-next g) (gr-unary g))
       (gr-op? g 0 "!") (: _ (gr-next g) (gr-truth (gr-unary g = 0)))
       (gr-power g))
   (gr-power g)
    (: a (gr-prim g)
       (? (gr-op? g 0 "^") (: _ (gr-next g) b (gr-unary g) (gr-pow a b)) a))
   ; a call's arguments, the ( next
   (gr-callargs g)
    (: _ (gr-want-op g "(")
       (? (gr-op? g 0 ")") (: _ (gr-next g) ())
          (: (go acc) (: v (gr-expr g)
                         (? (gr-op? g 0 ",") (: _ (gr-next g) (go (v . acc)))
                            (: _ (gr-want-op g ")") (rev (v . acc)))))
             (go ()))))
   (gr-func g f as)
    (: n #as (a k) (? (k < n) (as k) 0.0)
       (f @ "log" (gr-log10 (a 0))
            "exp" (gr-pow10 (a 0))
            "sin" (sin (a 0)) "cos" (cos (a 0))
            "sqrt" (sqrt (a 0))
            "atan2" (atan2 (a 0) (a 1))
            "int" (: v (a 0) (? (v < 0) (0.0 - gr-fl (floor (0 - v))) (gr-fl (floor v))))
            "max" (? (a 1 > a 0) (a 1) (a 0))
            "min" (? (a 1 < a 0) (a 1) (a 0))
            "rand" (gr-rand g)
            0.0))
   ; a small lcg: rand's numbers are ours, not plan 9's
   (gr-rand g) (: s ((g 'seed * 1103515245 + 12345) % 2147483648) _ (pin g 'seed s) (s / 2147483648.0))
   (gr-prim g)
    (: k (gr-k g 0) v (gr-v g 0)
       (? (k = 'num) (: _ (gr-next g) v)
          (gr-op? g 0 "(") (: _ (gr-next g) e (gr-expr g) _ (gr-want-op g ")") e)
          (k = 'name && elem v gr-funcs) (: _ (gr-next g) (gr-func g v (gr-callargs g)))
          (k = 'name) (: _ (gr-next g) (gr-var g v))
          (gr-syn g)))
   ; an expression or a string, for print and sprintf's arguments
   (gr-sprintf g)
    (: _ (gr-next g) _ (gr-want-op g "(")
       f (? (gr-k g 0 = 'str) ((gr-next g) 1) (gr-syn g))
       (go acc) (? (gr-op? g 0 ",") (: _ (gr-next g) (go (gr-expr g . acc)))
                   (: _ (gr-want-op g ")") (aw-sprintf f (rev acc) "%g")))
       (go ()))
   ; a string, or sprintf(..) -> the string, or ()
   (gr-text g)
    (? (gr-k g 0 = 'str) (<>(gr-next g))
       (gr-w? g 0 "sprintf") (gr-sprintf g)
       ())

   ; -- coordinate systems ------------------------------------------------------------
   ; a system: its name, its ranges (log10 ones on a log axis), whether a coord statement
   ; set it, and which of its axes it fixed
   (gr-coord g nm)
    (: c (peep (g 'cs) nm ())
       (? (tablet? c) c
          (: c2 {'name nm 'xl gr-huge 'xu (0 - gr-huge) 'yl gr-huge 'yu (0 - gr-huge)
                 'set 0 'xfix 0 'yfix 0 'xlog 0 'ylog 0}
             _ (pin (g 'cs) nm c2)
             _ (pin g 'corder (nm . g 'corder))
             c2)))
   (gr-cname? g nm) (tablet? (peep (g 'cs) nm ()))
   ; the system a point takes by default: the default's name as the graph began, which
   ; follows a rename only when that name was grap's buffer already
   (gr-cur g) (: c (g 'cur) (? (c = 'buf) (g 'dflt) c))
   ; a coord's name before a point or a value, if the next is one
   (gr-optcoord g)
    (? (gr-k g 0 = 'name && gr-cname? g (gr-v g 0)) (<>(gr-next g)) (gr-cur g))
   ; the value an axis keeps: its log on a log axis
   (gr-axv c ax v) (? (c (? (ax = 'x) 'xlog 'ylog)) (gr-log10 v) v)
   ; a value taken into an axis's range: a point's unless a coord said the axis, a tick's
   ; unless a coord said the other one
   (gr-extend c ax v) (gr-extend2 c ax v 0)
   (gr-extend2 c ax v tick)
    (: l (? (ax = 'x) 'xl 'yl) u (? (ax = 'x) 'xu 'yu)
       f (? (ax = 'x) (? tick 'yfix 'xfix) (? tick 'xfix 'yfix))
       (? (c f) 0
          (: _ (? (v < c l) (pin c l v) 0) (? (v > c u) (pin c u v) 0))))
   ; a point [name x y] kept by its system -> its pic, xy_name(x,y)
   (gr-pt g p)
    (: c (gr-coord g <p) x (gr-axv c 'x (p 1)) y (gr-axv c 'y (p 2))
       _ (gr-extend c 'x x) _ (gr-extend c 'y y)
       ("xy_" + <p + "(" + gr-g x + "," + gr-g y + ")"))
   ; [coord] expr, expr, or the same in parens -> [name x y]
   (gr-point g)
    (: nm (gr-optcoord g)
       paren (gr-op? g 0 "(")
       ; (x, y) is a pair; (x) + 1, y is not
       p (? paren (gr-paren-pair g) ())
       (? (two? p) [nm <p (p 1)]
          (: x (gr-expr g) _ (gr-want-op g ",") y (gr-expr g) [nm x y])))
   (gr-paren-pair g)
    (: la (g 'la)
       (: _ (gr-next g) x (gr-expr g)
          (? (gr-op? g 0 ",")
              (: _ (gr-next g) y (gr-expr g) _ (gr-want-op g ")") [x y])
             ; not a pair: read it again as an expression
             (: _ (pin g 'la (la + (g 'la))) ()))))
   ; coord [name] [x lo, hi] [y lo, hi] [log x | log y | log log]
   (gr-coord-stmt g)
    (: _ (gr-next g)
       named (gr-k g 0 = 'name && !(elem (gr-v g 0) ["x" "y" "log"]))
       nm (? named (<>(gr-next g)) (g 'dflt))
       _ (pin g 'ncoord (g 'ncoord + 1))
       c0 (gr-coord g nm)
       ; a second unnamed one renames the default, in grap's own buffer
       nm2 (? (!named && 1 < g 'ncoord) ("gg" + show (g 'ncoord)) nm)
       _ (? (named || nm2 = nm) 0 (pins g 'dflt nm2 'dbuf 1))
       c (gr-coord g nm2)
       (rng ax) (: l (gr-expr g) _ (gr-want-op g ",") u (gr-expr g)
                   (? (ax = 'x) (pins c 'xl l 'xu u 'xfix 1) (pins c 'yl l 'yu u 'yfix 1)))
       (go _) (? (gr-w? g 0 "x") (: _ (gr-next g) _ (rng 'x) (go 0))
                 (gr-w? g 0 "y") (: _ (gr-next g) _ (rng 'y) (go 0))
                 (gr-w? g 0 "log")
                  (: _ (gr-next g)
                     _ (? (gr-w? g 0 "x") (: _ (gr-next g) (pin c 'xlog 1))
                          (gr-w? g 0 "y") (: _ (gr-next g) (pin c 'ylog 1))
                          (gr-w? g 0 "log") (: _ (gr-next g) (pins c 'xlog 1 'ylog 1))
                          (gr-syn g))
                     (go 0))
                 0)
       _ (go 0)
       ; a range said anywhere in the graph, and no system gets the default margin
       _ (? (c 'xfix || c 'yfix) (: _ (pin c 'set 1) (pin g 'anyset 1)) 0)
       ; a log axis keeps its range as logs
       (lg ax) (: l (? (ax = 'x) 'xl 'yl) u (? (ax = 'x) 'xu 'yu) f (? (ax = 'x) 'xfix 'yfix)
                  (? (c f)
                      (? (c l <= 0 || c u <= 0)
                          (gr-err g ("can't have log of " + (show ax) + " coord " + gr-g (c l) + "," + gr-g (c u)))
                         (pins c l (gr-log10 (c l)) u (gr-log10 (c u))))
                     0))
       _ (? (c 'xlog) (lg 'x) 0) _ (? (c 'ylog) (lg 'y) 0)
       _ (gr-coord g (g 'dflt))
       0)

   ; -- output ----------------------------------------------------------------------
   (gr-o g s) (: _ (say (g 'body) s) (pin g 'drew 1))
   (gr-ol g s) (gr-o g (s + "\n"))

   ; -- lines: draw, new, next, and a line of numbers --------------------------------------
   ; a line's state: its style, its mark, whether it has begun
   (gr-line g nm)
    (: l (peep (g 'lines) nm ())
       (? (tablet? l) l (: l2 {'style "" 'mark () 'on 0 'draw 0} _ (pin (g 'lines) nm l2) l2)))
   ; linedesc: dotted dashed invis solid, then an optional expression -> its pic, or ()
   (gr-linedesc g)
    (: w (gr-v g 0)
       (? (gr-k g 0 = 'name && peep gr-styles w () != ())
           (: _ (gr-next g)
              s (gr-styles w)
              (? (gr-num-ahead? g) (s + " " + gr-g (gr-expr g)) s))
          ()))
   (gr-num-ahead? g)
    (: k (gr-k g 0)
       (? (k = 'num) 1
          (gr-op? g 0 "(") 1
          (gr-op? g 0 "-") 1
          (k = 'name && !(elem (gr-v g 0) gr-kw) && !(gr-cname? g (gr-v g 0))) 1
          0))
   ; draw|new [name] [linedesc] [mark]
   (gr-draw-stmt g new)
    (: _ (gr-next g)
       ; a bare draw or new is an error, found at what follows it
       _ (? (gr-end? g) (: _ (? (gr-k g 0 = 'nl) (gr-next g) 0) (gr-syn g)) 0)
       nm (? (gr-k g 0 = 'name && peep gr-styles (gr-v g 0) () = ()) (: n (<>(gr-next g)) _ (gr-coord g n) n) (gr-cur g))
       l (gr-line g nm)
       st (gr-linedesc g)
       mk (gr-text g)
       ; a style draws the line; a mark alone is what plain points are plotted with
       _ (? (string? mk) (pin g 'mark mk) 0)
       _ (? (string? st) (pins l 'style st 'mark mk 'draw 1) (pins l 'mark mk 'draw 0))
       _ (gr-coord g nm)
       ; a new line counts its lone numbers' places from one again
       (? new (: _ (pin l 'on 0) (pin g 'nextx 1.0)) 0))
   ; the line nm on to a point, its mark there
   (gr-next-pt g nm p st)
    (: l (gr-line g nm) at (gr-pt g p)
       _ (? (l 'on)
             (gr-ol g ("line " + (? (string? st) st (l 'style)) + " from L" + nm + " to " + at + "; L" + nm + ": Here"))
             (: _ (pin l 'on 1) (gr-ol g ("L" + nm + ": " + at))))
       (? (string? (l 'mark)) (gr-ol g ("\"" + l 'mark + "\" at " + at)) 0))
   ; next [name] at point [linedesc]
   (gr-next-stmt g)
    (: _ (gr-next g)
       nm (? (gr-k g 0 = 'name && !(gr-w? g 0 "at")) (: n (<>(gr-next g)) _ (gr-coord g n) n) (gr-cur g))
       _ (? (gr-w? g 0 "at") (gr-next g) (gr-syn g))
       p (gr-point g)
       st (gr-linedesc g)
       (gr-next-pt g nm p st))
   ; x y1 y2 ..: each y a mark at x, or on along the line when it is drawn
   (gr-data g)
    (: (num _) (? (gr-op? g 0 "-") (: _ (gr-next g) (-1.0 * <>(gr-next g))) (<>(gr-next g)))
       (go acc) (? (gr-k g 0 = 'num || (gr-op? g 0 "-" && gr-k g 1 = 'num)) (go (num 0 . acc)) (rev acc))
       vs (go ())
       nm (gr-cur g)
       l (gr-line g nm)
       xs (? (atom? >vs) [(g 'nextx) <vs] vs)
       _ (? (atom? >vs) (pin g 'nextx (g 'nextx + 1)) 0)
       x <xs
       (map (y \ (? (l 'draw) (gr-next-pt g nm [nm x y] ())
                    (gr-ol g ("box invis wid 0 ht 1*textht \"" + g 'mark + "\" at " + gr-pt g [nm x y]))))
            >xs))

   ; -- plot, line, circle, pic ---------------------------------------------------------
   ; the placing words after a string
   (gr-just g)
    (: (go acc) (? (gr-k g 0 = 'name && elem (gr-v g 0) ["ljust" "rjust" "above" "below"])
                   (go (<>(gr-next g) . acc)) (rev acc))
       (go ()))
   (gr-said ws) (foldl (\ a w (a + " " + w)) "" ws)
   ; plot "str" [just..] at point | plot expr at point
   (gr-plot-stmt g)
    (: _ (gr-next g)
       s (gr-text g)
       (? (string? s)
           (: js (gr-just g) _ (? (gr-w? g 0 "at") (gr-next g) (gr-syn g))
              p (gr-point g)
              (gr-ol g ("box invis wid 0 ht 1*textht \"" + s + "\"" + gr-said js + " at " + gr-pt g p)))
          (: v (gr-expr g) _ (? (gr-w? g 0 "at") (gr-next g) (gr-syn g))
             p (gr-point g)
             (gr-ol g ("\"" + gr-tnum v + "\" at " + gr-pt g p)))))
   ; line|arrow [linedesc] from point to point [linedesc]
   (gr-line-stmt g kw)
    (: _ (gr-next g)
       s1 (gr-linedesc g)
       _ (? (gr-w? g 0 "from") (gr-next g) (gr-syn g))
       a (gr-point g)
       _ (? (gr-w? g 0 "to") (gr-next g) (gr-syn g))
       b (gr-point g)
       s2 (gr-linedesc g)
       st (? (string? s2) s2 (string? s1) s1 "")
       pa (gr-pt g a) pb (gr-pt g b)
       (gr-ol g (kw + " " + st + " from " + pa + " to " + pb)))
   ; circle [rad expr] at point
   (gr-circle-stmt g)
    (: _ (gr-next g)
       r (? (gr-w? g 0 "rad" || gr-w? g 0 "radius") (: _ (gr-next g) (gr-expr g)) ())
       _ (? (gr-w? g 0 "at") (gr-next g) (gr-syn g))
       p (gr-point g)
       (? (r = ()) (gr-ol g ("\"\\s-3\\(ob\\s0\" at " + gr-pt g p))
          (gr-ol g ("circle rad " + gr-g r + " at " + gr-pt g p))))

   ; -- frame and labels --------------------------------------------------------------
   ; frame [ht e] [wid e] [side linedesc].. [linedesc]
   (gr-frame-stmt g)
    (: _ (gr-next g) _ (pin g 'drew 1)
       (go _)
        (? (gr-w? g 0 "ht") (: _ (gr-next g) _ (pin g 'ht (gr-expr g)) (go 0))
           (gr-w? g 0 "wid" || gr-w? g 0 "width") (: _ (gr-next g) _ (pin g 'wid (gr-expr g)) (go 0))
           (gr-k g 0 = 'name && peep gr-sides (gr-v g 0) () != ())
            (: sd (gr-sides (<>(gr-next g))) st (gr-linedesc g)
               _ (pin (g 'fsides) sd (? (string? st) st ""))
               (go 0))
           (gr-k g 0 = 'name && peep gr-styles (gr-v g 0) () != ())
            (: st (gr-linedesc g) _ (map (sd \ pin (g 'fsides) sd st) ['top 'bot 'left 'right]) (go 0))
           0)
       (go 0))
   ; label side "s" [just..] "s" .. [left|right|up|down e].. [width e]
   (gr-label-stmt g)
    (: _ (gr-next g)
       sd (? (gr-k g 0 = 'name && peep gr-sides (gr-v g 0) () != ()) (gr-sides (<>(gr-next g))) 'bot)
       (strs acc) (: s (gr-text g) (? (string? s) (strs ([s (gr-said (gr-just g))] . acc)) (rev acc)))
       ss (strs ())
       (go dx dy w)
        (? (gr-w? g 0 "left") (: _ (gr-next g) (go (dx - gr-expr g) dy w))
           (gr-w? g 0 "right") (: _ (gr-next g) (go (dx + gr-expr g) dy w))
           (gr-w? g 0 "up") (: _ (gr-next g) (go dx (dy + gr-expr g) w))
           (gr-w? g 0 "down") (: _ (gr-next g) (go dx (dy - gr-expr g) w))
           (gr-w? g 0 "width") (: _ (gr-next g) (go dx dy (gr-expr g)))
           [dx dy w])
       r (go 0.0 0.0 ())
       dx <r dy (r 1) w (r 2)
       lr (elem sd ['left 'right])
       n #ss
       width (? (w != ()) (w + 0.00001) (gr-fl (foldl (\ m s (max m #<s)) 0 ss) / 15))
       _ (gr-ol g "\ttextht = 0.166667")
       _ (? (lr || w != ()) (gr-ol g ("\ttextwid = " + gr-g width)) 0)
       body (cats (map (s \ " \"" + <s + "\"" + s 1) ss))
       at (sd @ 'bot " with .n at Frame.s - (0,2 * textht)"
               'top " with .s at Frame.n + (0,2 * textht)"
               'left " wid textwid with .e at Frame.w - (0.2,0)"
               " wid textwid with .w at Frame.e + (0.2,0)")
       sh (? (dx != 0 || dy != 0) (" + (" + gr-g dx + "," + gr-g dy + ")") "")
       (gr-ol g ("Label:\tbox invis wid 0 ht " + show n + "*textht" + body + at + sh)))

   ; -- ticks and grids -----------------------------------------------------------------
   ; the values of an at list [[v label] ..] or a from list, and whether any were labelled
   ; -> [coordname items anylabel]
   (gr-tick-list g grid)
    (? (gr-w? g 0 "at")
        (: _ (gr-next g) nm (gr-optcoord g)
           (go acc) (: v (gr-expr g) s (gr-text g) it [v s]
                       (? (gr-op? g 0 ",") (: _ (gr-next g) (go (it . acc))) (rev (it . acc))))
           its (go ())
           [nm its (0 < #(filter (it \ string? (it 1)) its)) 'at])
       (gr-w? g 0 "from")
        (: _ (gr-next g) nm (gr-optcoord g)
           a (gr-expr g) _ (? (gr-w? g 0 "to") (gr-next g) (gr-syn g))
           b (gr-expr g)
           r (? (gr-w? g 0 "by")
                (: _ (gr-next g) op (? (gr-k g 0 = 'op && elem (gr-v g 0) ["+" "-" "*" "/"]) (<>(gr-next g)) " ")
                   [op (gr-expr g)])
                ["+" 1.0])
           op <r by (r 1)
           fmt (gr-text g)
           down (gr-down? op by)
           (go v acc n) (? (1000 < n || (? down (v < b) (v > b))) (rev acc)
                           (go (gr-step op v by) ([v (? (string? fmt) (aw-sprintf fmt [v] "%g") ())] . acc) (n + 1)))
           its (go a () 0)
           [nm its 1 'from (string? fmt)])
       ())
   ; the label of an item: said, else its value unless some other item was said
   (gr-tick-label it any kind)
    (? (string? (it 1)) (? (kind = 'at) (gr-atlabel (it 1)) (it 1))
       (kind = 'from) (gr-tnum (it 0))
       any ()
       (gr-tnum (it 0)))
   ; an at list's said label runs through printf with no value: plan 9's grap loses it
   (gr-atlabel s) (gr-fmt0 (gr-fmt0 s))
   ; one pass: %% is %, a % at the end is nothing, a conversion formats a zero
   (gr-fmt0 s)
    (: n #s o (jug 0)
       (go i) (? (n <= i) (slurp o)
                 (s i != 37) (put o (s i), go (i + 1))
                 (n <= i + 1) (slurp o)
                 (s (i + 1) = 37) (put o 37, go (i + 2))
                 (: (spec j) (? (j < n && (0 <= wg-find "-+ #0123456789." (string (s j)) 0)) (spec (j + 1)) j)
                    j (spec (i + 1))
                    (? (n <= j) (slurp o)
                       (: f (snip s i (j + 1)) c (s j)
                          _ (say o (? (elem c [100 105 120 88 111 117 99]) (aw-sprintf f [0] "%g")
                                      (elem c [102 101 103 69 71]) (aw-sprintf f [0.0] "%g")
                                      ""))
                          (go (j + 1))))))
       (go 0))
   ; the in widths leave out the tick; the out ones count it
   (gr-lwid s in) (gr-f2 ((? in 0.0 0.1) + (4.0 * #s) / 30))
   ; one tick's pic: side, in, the coord, the value as kept, its label or ()
   (gr-tick g sd in auto nm v lab)
    (: xy (? (elem sd ['bot 'top]) ("x_" + nm + "(" + gr-g v + ")") ("y_" + nm + "(" + gr-g v + ")"))
       end (? (in && !auto) "start" "end")
       _ (gr-ol g (sd @ 'bot ("\tline  " + (? in "up" "down") + " ticklen from (" + xy + ",0)")
                       'top ("\tline  " + (? in "down" "up") + " ticklen from (" + xy + ",frameht)")
                       'left ("\tline  " + (? in "right" "left") + " ticklen from (0," + xy + ")")
                       ("\tline  " + (? in "left" "right") + " ticklen from (framewid," + xy + ")")))
       win (in && !auto)
       (? (lab = ()) 0
          (gr-ol g (sd @ 'bot ("\tbox invis \"" + lab + "\" ht .25 wid 0 with .n at last line." + end)
                         'top ("\tbox invis \"" + lab + "\" ht .2 wid 0 with .s at last line." + end)
                         'left ("\t\"" + lab + " \" wid " + gr-lwid lab win + " rjust at last line." + end)
                         ("\t\" " + lab + "\" wid " + gr-lwid lab win + " ljust at last line." + end)))))
   ; the axis a side's values ride
   (gr-axis sd) (? (elem sd ['bot 'top]) 'x 'y)
   ; ticks [side] [in|out [len]] [off | at .. | from ..]
   (gr-ticks-stmt g)
    (: _ (gr-next g) _ (pin g 'drew 1)
       sd (? (gr-k g 0 = 'name && peep gr-sides (gr-v g 0) () != ()) (gr-sides (<>(gr-next g))) ())
       io (? (gr-w? g 0 "in") (: _ (gr-next g) 1) (gr-w? g 0 "out") (: _ (gr-next g) 0) ())
       len (? (io != () && gr-num-ahead? g) (gr-expr g) 0.1)
       ; off: none, one side the fewer, or with in or out that side alone
       (? (gr-w? g 0 "off")
           (: _ (gr-next g)
              (? (sd = ()) (pin g 'auto ())
                 (io != ()) (: _ (pin g 'auto [sd]) _ (gr-autopref g sd) (? (io = 1) (pin (g 'autoin) sd 1) 0))
                 (pin g 'auto (filter (s \ s != sd) (g 'auto)))))
          (: tl (gr-tick-list g 0)
             (? (tl = ())
                 (? (sd = ()) 0
                    (: _ (? (elem sd (g 'auto)) 0 (pin g 'auto (sd . g 'auto)))
                       _ (gr-autopref g sd)
                       (? (io = 1) (pin (g 'autoin) sd 1) 0)))
                (: nm <tl its (tl 1) any (tl 2) kind (tl 3)
                   c (gr-coord g nm)
                   _ (? (sd = ()) 0 (gr-unauto g sd))
                   _ (gr-ol g ("Ticks_" + nm + ":\n\tticklen = " + gr-g len))
                   (map (it \ (: ax (? (sd = ()) 'x (gr-axis sd)) v (gr-axv c ax (it 0))
                                 _ (gr-extend2 c ax v 1)
                                 (? (sd = ()) 0 (gr-tick g sd (io = 1) 0 nm v (gr-tick-label it any kind)))))
                        its))))))
   ; the side an axis's automatic ticks take, when both of its are on
   (gr-autopref g sd) (pin (g 'autopref) (? (elem sd ['bot 'top]) 'bot 'left) sd)
   ; explicit ticks or a grid on an axis end its automatic ones
   (gr-unauto g sd)
    (: pair (? (elem sd ['bot 'top]) ['bot 'top] ['left 'right])
       (pin g 'auto (filter (s \ !(elem s pair)) (g 'auto))))
   ; grid side [linedesc] [ticks off] at ..|from ..
   (gr-grid-stmt g)
    (: _ (gr-next g) _ (pin g 'drew 1)
       sd (? (gr-k g 0 = 'name && peep gr-sides (gr-v g 0) () != ()) (gr-sides (<>(gr-next g))) 'bot)
       st (: s (gr-linedesc g) (? (string? s) s ""))
       tl (gr-tick-list g 1)
       (? (tl = ()) 0
          (: nm <tl its (tl 1) kind (tl 3)
             c (gr-coord g nm)
             _ (gr-unauto g sd)
             _ (gr-ol g ("Grid_" + nm + ":"))
             (map (it \ (: ax (gr-axis sd) v (gr-axv c ax (it 0)) _ (gr-extend2 c ax v 1)
                           xy (? (ax = 'x) ("x_" + nm + "(" + gr-g v + ")") ("y_" + nm + "(" + gr-g v + ")"))
                           _ (gr-ol g (sd @ 'bot ("\tline " + st + " up frameht from (" + xy + ",0)")
                                          'top ("\tline " + st + " down frameht from (" + xy + ",frameht)")
                                          'left ("\tline " + st + " right framewid from (0," + xy + ")")
                                          ("\tline " + st + " left framewid from (framewid," + xy + ")")))
                           lab (? (string? (it 1)) (? (kind = 'at) (gr-atlabel (it 1)) (it 1)) (kind = 'from) (gr-tnum (it 0)) ())
                           (? (lab = ()) 0
                              (gr-ol g (sd @ 'bot ("\tbox invis \"" + lab + "\" ht .25 wid 0 with .n at last line.start")
                                            'top ("\tbox invis \"" + lab + "\" ht .2 wid 0 with .s at last line.start")
                                            'left ("\t\"" + lab + " \" wid " + gr-lwid lab 1 + " rjust at last line.start")
                                            ("\t\" " + lab + "\" wid " + gr-lwid lab 1 + " ljust at last line.start"))))))
                  its))))

   ; -- automatic ticks -----------------------------------------------------------------
   ; the step for a range: 1, 2, 5 times a power of ten, as few as a range of r wants
   (gr-q r)
    (: (up m q) (? (m >= 10) (up (m / 10) (q * 10)) (down m q))
       (down m q) (? (m < 1) (down (m * 10) (q / 10)) [m q])
       r2 (up r 1.0) m <r2 q (r2 1)
       (? (m <= 1) (q / 5) (m < 3) (q / 2) (m < 6) q (2 * q)))
   ; the values from lo to hi a step q apart, a hundredth of a step's slack at each end
   (gr-lin-ticks lo hi q)
    (: c (gr-ceil (lo / q - 0.01))
       (go x acc) (? ((x - hi) / q <= 0.01)
                     (go (x + q) (? ((lo - x) / q <= 0.01) (x . acc) acc))
                     (rev acc))
       (go (c * q) ()))
   (gr-ceil x) (: f (gr-fl (floor x)) c (? (f = x) f (f + 1.0)) (? (c = 0 && x < 0) -0.0 c))
   ; a log axis's: 1, 2, 5 a decade over a range under a hundredfold, else the decades, and
   ; steps as a line's when it spans under five
   ; the power of ten at or under v, a whole one over it counting as under
   (gr-decade v) (: (u q) (? (q * 10 < v) (u (q * 10)) q) (d q) (? (q > v) (d (q / 10)) q) (d (u 1.0)))
   ; 1, 2, 5 or 10 times it: the most at or under v, the least at or over it
   (gr-nice-lo v) (: q (gr-decade v) (: (go cs) (? (atom? >cs) (<cs * q) (>cs 0 * q <= v) (go >cs) (<cs * q)) (go [1 2 5 10])))
   (gr-nice-hi v) (: q (gr-decade v) (: (go cs) (? (atom? >cs) (<cs * q) (<cs * q >= v) (<cs * q) (go >cs)) (go [1 2 5 10])))
   ; -> [q values tlo thi], the ticks between lo and hi, over a range found rather than
   ; said (auto) and under a hundredfold widened to nice ends first
   (gr-log-ticks lo hi auto)
    (? (hi / lo >= 5)
        (: wide (auto && hi / lo < 100)
           tl (? wide (gr-nice-lo lo) lo) th (? wide (gr-nice-hi hi) hi)
           q (gr-decade lo)
           (on v) (lo <= v && v <= hi)
           [q (: (go x acc) (? (x < th)
                               (go (x * 10) (: a (? (on x) (x . acc) acc)
                                               (? (hi / lo <= 100)
                                                   (: b (? (on (2 * x)) (2 * x . a) a) (? (on (5 * x)) (5 * x . b) b))
                                                  a)))
                               (rev acc))
                (go q ()))
            tl th])
       (: q2 (gr-q (hi - lo)) [q2 (gr-lin-ticks lo hi q2) lo hi]))
   ; the axis of the default system: [lo hi q values] in the axis's own units
   (gr-auto-axis c ax)
    (: l (c (? (ax = 'x) 'xl 'yl)) u (c (? (ax = 'x) 'xu 'yu)) lg (c (? (ax = 'x) 'xlog 'ylog))
       lo (? lg (gr-pow10 l) l) hi (? lg (gr-pow10 u) u)
       (? (hi < lo) [lo hi 0.0 () lo hi]
          (hi = lo) [lo hi 0.0 [lo] lo hi]
          lg (: r (gr-log-ticks lo hi !(c 'set)) [lo hi <r (r 1) (r 2) (r 3)])
          (: q (gr-q (hi - lo)) [lo hi q (gr-lin-ticks lo hi q) lo hi])))
   (gr-autoticks g o)
    (: c (peep (g 'cs) (g 'dflt) ())
       au (g 'auto)
       (? (!(tablet? c) || atom? au) 0
          (: xa (gr-auto-axis c 'x) ya (gr-auto-axis c 'y) nm (g 'dflt)
             _ (say o ("Autoticks:\t# x " + gr-g <xa + ".." + gr-g (xa 1) + ", y " + gr-g <ya + ".." + gr-g (ya 1)
                       + ";   xt " + gr-g (xa 4) + "," + gr-g (xa 5) + ", yt " + gr-g (ya 4) + "," + gr-g (ya 5)
                       + ", xq,xm = " + gr-g (xa 2) + ",0, yq,ym = " + gr-g (ya 2) + ",0\n"))
             body0 (g 'body)
             _ (pin g 'body o)
             (axis a sides)
              ; the side of the axis named last, else the other one still on
              (: pf (peep (g 'autopref) <sides <sides) ot (? (pf = <sides) (sides 1) <sides)
                 sd (? (elem pf au) pf (elem ot au) ot ())
                 lg (c (? (<sides = 'bot) 'xlog 'ylog))
                 (? (sd = () || atom? (a 3)) 0
                    (: _ (gr-ol g ("Ticks_" + nm + ":\n\tticklen = 0.1"))
                       (map (v \ gr-tick g sd (peep (g 'autoin) sd 0) 1 nm (? lg (gr-log10 v) v) (gr-tnum v)) (a 3)))))
             _ (axis xa ['bot 'top])
             _ (axis ya ['left 'right])
             (pin g 'body body0))))

   ; -- a graph ---------------------------------------------------------------------
   (gr-margin c ax m)
    (: l (? (ax = 'x) 'xl 'yl) u (? (ax = 'x) 'xu 'yu) d (c u - c l)
       (pins c l (c l - m * d) u (c u + m * d)))
   ; a system's macros: its range as it was said or found, then the map to the frame
   (gr-coord-defs g c o)
    (: nm (c 'name) wid (g 'wid) ht (g 'ht)
       (said ax) (: l (c (? (ax = 'x) 'xl 'yl)) u (c (? (ax = 'x) 'xu 'yu)) lg (c (? (ax = 'x) 'xlog 'ylog))
                    (? (lg && l <= u) [(gr-pow10 l) (gr-pow10 u)] [l u]))
       sx (said 'x) sy (said 'y)
       _ (say o ("\t# " + nm + " " + gr-g <sx + " .. " + gr-g (sx 1) + ", " + gr-g <sy + " .. " + gr-g (sy 1) + "\n"))
       m (? (g 'mset) (gr-var g "margin") (g 'anyset) 0.0 0.07)
       _ (? (c 'xfix) 0 (gr-margin c 'x m))
       _ (? (c 'yfix) 0 (gr-margin c 'y m))
       (map1 ax arg size) (: l (c (? (ax = 'x) 'xl 'yl)) u (c (? (ax = 'x) 'xu 'yu))
                             (? (l < u) ("(($" + arg + ")-(" + gr-g l + "))*" + gr-g (size / (u - l))) (gr-g (size / 2))))
       mx (map1 'x "1" wid) my (map1 'y "2" ht) my1 (map1 'y "1" ht)
       (say o ("define xy_" + nm + " @ \t" + mx + ", " + my + " @\ndefine x_" + nm + " @ \t" + mx
               + " @\ndefine y_" + nm + " @ \t" + my1 + " @\n")))
   (gr-frame g o)
    (: fs (g 'fsides)
       _ (say o ("\tframeht = " + gr-g (g 'ht) + "\n\tframewid = " + gr-g (g 'wid) + "\n"))
       any (0 < #(keys fs))
       _ (say o ("Frame:\tbox ht frameht wid framewid with .sw at 0,0 " + (? any "invis" "") + "\n"))
       (? any
           (map (e \ (: st (peep fs <e ()) (say o ("\tline from Frame." + e 1 + " to Frame." + e 2 + (? (string? st) (" " + st) "") + "\n"))))
                [['top "nw" "ne"] ['bot "sw" "se"] ['left "sw" "nw"] ['right "se" "ne"]])
          0))
   ; a graph's pic, when it drew anything: its systems newest first, its frame, its automatic
   ; ticks, and what it drew
   (gr-finish g)
    (? !(g 'drew) 0
       (: o (g 'o)
          _ (say o (g 'gname + ": [\n"))
          cs (map (nm \ g 'cs nm) (g 'corder))
          ; the automatic ticks see the ranges the margins leave
          co (jug 0)
          _ (map (c \ gr-coord-defs g c co) cs)
          _ (say o (slurp co))
          _ (gr-frame g o)
          _ (gr-autoticks g o)
          _ (say o (slurp (g 'body)))
          (say o ("\n] " + g 'gpos + "\n"))))
   (gr-new-graph g nm pos)
    (pins g 'gname nm 'gpos pos 'drew 0 'body (jug 0) 'cs (tablet 0) 'corder () 'lines (tablet 0)
            'fsides (tablet 0) 'auto ['bot 'left] 'autoin (tablet 0) 'autopref (tablet 0) 'ht 2.0 'wid 3.0 'ncoord 0 'nextx 1.0 'anyset 0)

   ; -- statements -------------------------------------------------------------------
   ; a statement ends at a newline or a semicolon; troff's lines, for and if do not
   (gr-stmt g)
    (: k (gr-k g 0) v (gr-v g 0)
       (? (k = 'nl) (gr-next g)
          (k = 'eof) 0
          (k = 'troff) (: _ (gr-next g) (gr-ol g v))
          (gr-w? g 0 "for") (gr-for g)
          (gr-w? g 0 "if") (gr-if g)
          (: _ (gr-stmt1 g k v)
             (? (gr-end? g) (? (gr-k g 0 = 'nl) (gr-next g) 0) (gr-syn g)))))
   (gr-stmt1 g k v)
    (? (k = 'pic) (: _ (gr-next g) (gr-ol g v))
       (k = 'sh) (: _ (gr-next g) (gr-sh g v))
       (k = 'num || (gr-op? g 0 "-" && gr-k g 1 = 'num)) (gr-data g)
       (k = 'name && gr-op? g 1 "=") (: _ (gr-drop g 2) _ (? (v = "margin") (pin g 'mset 1) 0) (gr-setvar g v (gr-expr g)))
       (k = 'name)
        (v @ "frame" (gr-frame-stmt g)
             "coord" (gr-coord-stmt g)
             "ticks" (gr-ticks-stmt g) "tick" (gr-ticks-stmt g)
             "grid" (gr-grid-stmt g)
             "label" (gr-label-stmt g)
             "plot" (gr-plot-stmt g)
             "line" (gr-line-stmt g "line") "arrow" (gr-line-stmt g "arrow")
             "circle" (gr-circle-stmt g)
             "draw" (gr-draw-stmt g 0) "new" (gr-draw-stmt g 1)
             "next" (gr-next-stmt g)
             "print" (gr-print g)
             "graph" (gr-graph-stmt g)
             (gr-syn g))
       (gr-syn g))
   (gr-print g)
    (: _ (gr-next g)
       s (gr-text g)
       (say err ("\t" + (? (string? s) s (gr-g (gr-expr g))) + "\n")))
   ; sh runs the command, its output straight out ahead of all grap has kept
   (gr-sh g cmd)
    (: r (hark ["sh" "-c" cmd])
       _ (? (two? r) (: _ (say out >r) (flush out)) 0)
       (gr-ol g "# shell cmd..."))
   ; graph Name rest: the graph before it ends, and a new one starts in the same picture
   (gr-graph-stmt g)
    (: _ (gr-next g)
       nm (? (gr-k g 0 = 'name) (<>(gr-next g)) (gr-syn g))
       ; the rest of the line places it, as it was written
       rest (? (atom? (g 'la)) (gr-rest-line g) "")
       _ (gr-finish g)
       (gr-new-graph g nm rest))
   ; for v from|= a to b [by [op] c] do body
   (gr-for g)
    (: _ (gr-next g)
       v (? (gr-k g 0 = 'name) (<>(gr-next g)) (gr-syn g))
       _ (? (gr-w? g 0 "from" || gr-op? g 0 "=") (gr-next g) (gr-syn g))
       a (gr-expr g)
       _ (? (gr-w? g 0 "to") (gr-next g) (gr-syn g))
       b (gr-expr g)
       r (? (gr-w? g 0 "by")
            (: _ (gr-next g) op (? (gr-k g 0 = 'op && elem (gr-v g 0) ["+" "-" "*" "/"]) (<>(gr-next g)) " ")
               [op (gr-expr g)])
            ["+" 1.0])
       op <r by (r 1)
       body (? (gr-k g 0 = 'body) (<>(gr-next g)) (gr-syn g))
       _ (gr-ol g ("# for " + v + " from " + gr-g a + " to " + gr-g b + " by " + op + " " + gr-g by + " "))
       f {'var v 'to b 'by by 'op op 'down (gr-down? op by)}
       _ (gr-setvar g v a)
       ; the rest of the for's line waits under the body
       (? (gr-for-ok f a) (: s (gr-src (body + "\n") 'for) _ (pin s 'for f) (gr-push g s)) 0))
   (gr-if g)
    (: _ (gr-next g)
       e (gr-expr g)
       b (? (gr-k g 0 = 'ifb) (<>(gr-next g)) (gr-syn g))
       t (? (e != 0) <b (b 1))
       (? (string? t) (gr-push g (gr-src (t + "\n") 'text)) 0))

   ; -- the document -------------------------------------------------------------------
   (gr-starts? l w) (#w <= #l && snip l 0 #w = w)
   (gr-macro? l w) (gr-starts? l w && (#l = #w || gr-blank? (l #w)))
   ; the statements of a graph body run, the graph's pic said
   (gr-run-body g t ln)
    (: f (gr-src t 'file)
       _ (pins f 'ln ln) _ (pins g 'srcs [f] 'fsrc f 'la () 'forp 0 'ifp 0 'errln ())
       (go _) (? (gr-k g 0 = 'eof) 0 (: _ (gr-stmt g) (go 0)))
       (go 0))
   (gr-doc g nm text)
    (: ls (lines text)
       _ (pin g 'name nm)
       _ (gr-o0 g (".lf 1 " + nm + "\n"))
       (go ls k)
        (? (atom? ls) 0
           (gr-macro? <ls ".G1")
            (: args (snip <ls 3 #(<ls))
               (body l j acc) (? (atom? l) [(rev acc) j l]
                                 (gr-macro? <l ".G2") [(rev acc) j >l]
                                 (body >l (j + 1) (<l . acc)))
               r (body >ls (k + 1) ())
               bl (r 0) pk (r 1)
               ; the .G2 line, when there was one
               pe (: (fin l) (? (atom? l) () (gr-macro? <l ".G2") <l (fin >l)) (fin >ls))
               sk (g 'skew)
               _ (gr-o0 g (".PS" + args + "\nscale = 1\n.lf " + show (k + 1 + sk) + "\n"))
               _ (? (g 'defs) 0
                    (: _ (pin g 'defs 1)
                       _ (gr-o0 g (".lf 1 " + gr-defines-path + "\n"))
                       d (: r2 (uread gr-defines-path) (? (two? r2) <>r2 gr-defines))
                       _ (gr-run-defs g d)
                       (gr-o0 g (".lf " + show (k + sk) + " " + nm + "\n"))))
               _ (gr-new-graph g "Graph" "")
               _ (pins g 'dflt (peep g 'dflt "gg") 'cur (? (peep g 'dbuf 0) 'buf (peep g 'dflt "gg")))
               ok (trap (_ \ (: _ (gr-run-body g (cats (map (x \ x + "\n") bl)) (k + 1)) 1)) ()
                        (\ a m (a @ 'gr-err (: _ (gr-gave-up g nm m k bl pe pk) 0) (scare a m))))
               _ (? ok (: _ (gr-finish g) (gr-o0 g (".PE\n.lf " + show (pk + 1 + sk) + "\n"))) 0)
               (go (r 2) (pk + 1)))
           (: _ (gr-o0 g (<ls + "\n")) (go >ls (k + 1))))
       (go ls 1))
   (gr-o0 g s) (say (g 'o) s)
   ; a graph given up: said, and what it drew let go. the lines after the one it failed
   ; on go through as they are, and grap's count of lines is one short from then on. the
   ; status stays 0, as plan 9's does
   (gr-gave-up g nm m k bl pe pk)
    (: t (? (g 'errln = ()) (gr-fline g) (g 'errln))
       sk (g 'skew)
       _ (say err ("grap: " + m + " near " + nm + ":" + show (t - 1) + "\n"))
       rest (: (drop l j) (? (atom? l) () (t < j) l (drop >l (j + 1))) (drop bl (k + 1)))
       _ (gr-o0 g (".PE\n.lf " + show (t + sk) + "\n" + cats (map (x \ x + "\n") rest) + (? (string? pe && t < pk) (pe + "\n") "")))
       (pin g 'skew (sk - 1)))
   ; grap.defines: definitions only
   (gr-run-defs g d)
    (: _ (pins g 'srcs [(gr-src d 'text)] 'la () 'forp 0 'ifp 0)
       (go _) (? (gr-k g 0 = 'eof) 0 (: _ (gr-next g) (go 0)))
       (go 0))

   (grap-main as) (grap-run as ())
   (grap-run as sin) (gr-run as sin @ [st t] (say out t, flush out, st) 0)
   ; a run -> [status output]
   (gr-run as sin)
    (: g {'macros (tablet 0) 'vars (tablet 0) 'o (jug 0) 'status 0 'defs 0 'seed 1 'mark "\\(bu" 'skew 0}
       _ (gr-setvar g "margin" 0.07)
       fs (filter (a \ !(gr-starts? a "-") || a = "-") as)
       (go l) (? (atom? l) 0
                 (: f <l
                    t (? (f = "-") (? (string? sin) sin (slurp in)) (: r (uread f) (? (two? r) <>r ())))
                    (? (string? t) (gr-doc g f t, go >l)
                       (: _ (say err ("grap: can't open " + f + "\n")) (pin g 'status 1)))))
       _ (go (? (two? fs) fs ["-"]))
       [(g 'status) (slurp (g 'o))])
)
) ; module 'kore
