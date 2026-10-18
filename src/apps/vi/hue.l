; src/apps/vi/hue.l -- the .l syntax, once, for vi's painter and src/tools/hue2vim.l
; reads .l by lint.l's rules: `;` and `#!` to eol, "..." the only string; tokens, not a parse
; a row is (class vim-group rule); the rule tags are closed, each read by hue-lex and hue2vim
; row order is priority; word lanes name a runtime probe rather than list words
(module 'vi
(borrow 'posix)

(:
   hue-classes
    '((comment    Comment    (eol (";" "#!")))
      (string     String     (span 34 92))                 ; " with \ escapes
      (atom       Identifier (mark 39))                    ; 'foo -- the mark and its token
      (paren      Delimiter  (delim "()[]{}"))
      ; `,` is its own case: in no vocabulary, not a sigil, no partner
      (comma      Operator   (sep 44))
      (number     Number     (num))
      (form       Statement  (word (":" "?" "\\")))        ; letrec* / cond / lambda
      (macro      Operator   (word macros))                ; prel's macro-names
      (const      Constant   (word values))                ; bound to a value, not a nif
      (book       Function   (word names))
      (mono       Special    (punct glued))
      (dyad       Operator   (punct spaced)))

   ; the sigil alphabet, shared by both punct lanes and the vim class
   hue-sigils "@#$~.!?%^*+/<>=|&-"

   ; --- reading the table -----------------------------------------------------
   (hue-cls r)  <r
   (hue-grp r)  <>r
   (hue-rule r) <>>r
   (hue-tag r)  <(hue-rule r)
   (hue-arg r)  <>(hue-rule r)
   (hue-tagged tag) (filter (r \ hue-tag r = tag) hue-classes)
   (hue-one tag) <(hue-tagged tag)

   hue-eols (hue-arg (hue-one 'eol))                       ; the comment openers
   hue-brk  (hue-arg (hue-one 'delim))                     ; the bracket bytes
   hue-quo  (hue-arg (hue-one 'mark))
   hue-sep  (hue-arg (hue-one 'sep))                       ; the byte the grammar splits at
   hue-str  (hue-arg (hue-one 'span))                      ; the quote byte
   hue-esc  (hue-rule (hue-one 'span) 2)         ; the escape byte
   ; a token ends only on whitespace, a bracket, or a reader operator
   hue-stop (hue-brk + "\"';,")

   (hue-blank? c) (c = 32 || c = 9)
   (hue-delim? c) (elem c hue-brk)
   (hue-term? c)  (c < 33 || elem c hue-stop)
   (hue-sig? c)   (elem c hue-sigils)
   (hue-at? s i t)                                         ; does s carry t at i?
    (: n #s m #t
       (go k) (? (m <= k) 1 (n <= i + k) () (s (i + k) = t k) (go (k + 1)) ())
       (go 0))

   ; --- the book --------------------------------------------------------------
   ; the vocabulary is asked of the book, not curated; sigil-leading names go to the punct lanes
   (hue-name? w) (string w @ t (0 < #t && !(hue-sig? (t 0))))

   ; the words a lane claims: a probe asks the runtime, else the literal list. sorted, since
   ; the generator freezes it. a book name either does something (lit?) or is a scalar or a
   ; name; session data (argv, parsed) is neither, so the answer is the same however love started
   (hue-verb? w) (lit? (ev w))
   (hue-const? w) (ev w @ v
                     (!(lit? v) &&
                      (constellation? v || string? v || nom? v)))
   (hue-words a)
    (? (a = 'names)  (sort (map string (filter hue-name? (filter hue-verb? (names ())))))
       (a = 'macros) (sort (map string (macro-names ())))
       (a = 'values) (sort (map string (filter hue-name? (filter hue-const? (names ())))))
       a)

   ; token -> class, filled in reverse so an earlier row wins
   (hue-book x)
    (foldl (b \ r \ foldl (b2 \ w \ pin b2 w (hue-cls r)) b (hue-words (hue-arg r)))
           (tablet ()) (rev (hue-tagged 'word)))

   ; --- is this token a number? -----------------------------------------------
   ; -3 .5 1. 1e10 1.5e-3 0x1f; runs before the punct split so a leading `-` or `.` stays numeric
   (hue-num? t)
    (: n #t
       (digs i) (i < n && 48 <= t i && t i <= 57 ? (digs (i + 1)) i)
       (hexs i) (i < n && (t i @ c (48 <= c && c <= 57 ||
                                    97 <= c && c <= 102 ||
                                    65 <= c && c <= 70))
                 ? (hexs (i + 1)) i)
       s0 (0 < n && t 0 = 45 ? 1 0)
       hx (s0 + 2 < n && t s0 = 48 && (t (s0 + 1) = 120 || t (s0 + 1) = 88)
           ? (hexs (s0 + 2) = n) ())
       a (digs s0)                                         ; the integer part
       b (a < n && t a = 46 ? (digs (a + 1)) a)            ; the fraction
       md (s0 < a ? 1 (a + 1 < b ? 1 ()))                  ; at least one mantissa digit
       x (md && b < n && (t b = 101 || t b = 69)
          ? (: e1 (b + 1 < n && (t (b + 1) = 45 || t (b + 1) = 43) ? (b + 2) (b + 1))
               e2 (digs e1)
               (e1 < e2 ? e2 b))
            b)
       (hx || md && x = n))

   ; the word lanes' class, or () when none claims the token
   (hue-word bk t) (tablet? bk ? (bk t) ())

   ; --- the lexer -------------------------------------------------------------
   ; (hue-lex bk s in keep) answers [runs out]: runs [class from to), to exclusive, and the
   ; string state at eol: 0 code, 1 in a string, a raw text's quote count. keep gates the emit
   ; only, so hue-carry is this same walk -- one scanner, never two
   (hue-lex bk s in keep)
    (: n #s
       (emit acc k a b) (keep && a < b ? ([k a b] . acc) acc)
       (tend i) (n <= i || hue-term? (s i) ? i (tend (i + 1)))
       (srun i) (i < n && hue-sig? (s i) ? (srun (i + 1)) i)
       ; glued: the run touches a datum start; at eol a trailing run is dyadic
       (glued? j) (j < n &&
                   (: c (s j)
                      !(hue-blank? c || c = 41 || c = 44 || c = 59 || hue-sig? c)))
       (word i j acc)
        (snip s i j @ t
           (hue-num? t ? (w j (emit acc 'number i j))
              (hue-word bk t @ k
                 (nom? k ? (w j (emit acc k i j))
                    (srun i @ p                            ; a leading punct run only --
                       (i < p ?                            ; punct inside a name is the name
                           (w p (emit acc (glued? p ? 'mono 'dyad) i p))
                          (w j acc)))))))
       ; a hole, "a \(x) b": past its closer, strings and holes inside it walked
       ; whole, or () when the line ends first. its \( and closer paint as brackets
       ; and what is between as code
       (hole k d) (? (n <= k) ()
                     (: c (s k)
                        (? (c = 40 || c = 91 || c = 123) (hole (k + 1) (d + 1))
                           (c = 41 || c = 93 || c = 125) (d = 1 ? (k + 1) (hole (k + 1) (d - 1)))
                           (c = hue-str) (hole (sbody (k + 1)) d)
                           (hole (k + 1) d))))
       (sbody k) (? (n <= k) n
                    (s k = hue-str) (k + 1)
                    (s k = hue-esc) ((k + 1 < n && s (k + 1) = 40) ? (sbody (hole (k + 1) 0 || n)) (sbody (k + 2)))
                    (sbody (k + 1)))
       (wstr i a acc)                                      ; inside "..."
        (n <= i ? [(rev (emit acc 'string a n)) 1]
           (s i @ c
              (? (c = hue-esc && i + 1 < n && s (i + 1) = 40)
                   (: e (hole (i + 1) 0)
                      o (i + 2)
                      in1 <(hue-lex bk (snip s o (e ? (e - 1) n)) 0 keep)
                      acc1 (foldl (\ b r ([<r (r 1 + o) (r 2 + o)] . b))
                                  (emit (emit acc 'string a i) 'paren i o) in1)
                      (e ? (wstr e e (emit acc1 'paren (e - 1) e)) [(rev acc1) 0]))
                 (c = hue-esc) (wstr (i + 2) a acc)
                 (c = hue-str) (w (i + 1) (emit acc 'string a (i + 1)))
                 (wstr (i + 1) a acc))))
       ; a raw text: three or more quotes, closed by as many. one that ends its opening
       ; line carries the count, and closes at a line of blanks and the quotes
       (qrun i) (i < n && s i = hue-str ? (qrun (i + 1)) i)
       (bl i) (i < n && hue-blank? (s i) ? (bl (i + 1)) i)
       (raw i acc)
        (: e (qrun i)
           q (e - i)
           (find j) (? (n <= j) () (s j != hue-str) (find (j + 1)) (qrun j @ r (r - j < q ? (find r) r)))
           (? (bl e = n) [(rev (emit acc 'string i n)) q]
              (find e @ r (r ? (w r (emit acc 'string i r)) [(rev (emit acc 'string i n)) q]))))
       (wraw q acc)
        (bl 0 @ t
           (qrun t - t < q ? [(rev (emit acc 'string 0 n)) q] (w (t + q) (emit acc 'string 0 (t + q)))))
       (w i acc)
        (n <= i ? [(rev acc) 0]
           (s i @ c
              (? (hue-blank? c) (w (i + 1) acc)
                 (any (t \ hue-at? s i t) hue-eols) [(rev (emit acc 'comment i n)) 0]
                 (c = hue-str && i + 2 < n && s (i + 1) = hue-str && s (i + 2) = hue-str) (raw i acc)
                 (c = hue-str) (wstr (i + 1) i acc)
                 (c = hue-quo) (tend (i + 1) @ j (w j (emit acc 'atom i j)))
                 (hue-delim? c) (w (i + 1) (emit acc 'paren i (i + 1)))
                 (c = hue-sep) (w (i + 1) (emit acc 'comma i (i + 1)))
                 ; a stop no lane claims (a control byte) is one plain char
                 (hue-term? c) (w (i + 1) acc)
                 (word i (tend i) acc))))
       (? (in = 1) (wstr 0 0 ()) (charm? in && 2 < in) (wraw in ()) (w 0 ())))

   ; one start-state per line: fold a lexer (lx s in keep) down the buffer, keeping nothing
   (hue-carry lx ls)
    (:- (go ls 0 ())
        (go l st acc) (atom? l ? (rev acc)
                        (lx <l st () @ r (go >l <>r (st . acc)))))

   ; --- the pens --------------------------------------------------------------
   ; one escape per class, built once. the theme is keyed by vim group, so swapping
   ; colorschemes moves the editor and leaves the generated syn file alone
   hue-off "\e[0m"
   (hue-hx c) (? (48 <= c && c <= 57) (c - 48) (65 <= c && c <= 70) (c - 55) (c - 87))
   (hue-byte t k) (hue-hx (t k) * 16 + hue-hx (t (k + 1)))
   (hue-faces fs) (foldl (a \ f \ a + (f = 'bold ? "1;" "3;")) "" fs)
   (hue-rgb g) (show (hue-byte g 1) + ";" + show (hue-byte g 3) + ";" + show (hue-byte g 5))
   ; a row's ground, when it has one, rides as its fifth and sixth columns
   (hue-pen row deep)
    (: n (row 1) g (row 2) fs (row 3)
       ("\e[" + hue-faces fs
        + (deep ? ("38;2;" + hue-rgb g) ("38;5;" + show n))
        + (#row < 6 ? "" (deep ? (";48;2;" + hue-rgb (row 5)) (";48;5;" + show (row 4))))
        + "m"))
   ; a theme with a Normal row owns the ground: 'ground sets it, 'off ends a run back on
   ; it rather than on the terminal's; Visual is the selection's, MatchParen a mate's, LineNr the gutter's
   (hue-pens rows deep)
    (foldl (b \ r \ pin b <r (hue-pen r deep)) (tablet ()) rows @ gp
       (: b (foldl (b \ c \ pin b (hue-cls c) (gp (hue-grp c))) (tablet ()) hue-classes)
          gr (peep gp 'Normal ()) sl (peep gp 'Visual ()) mp (peep gp 'MatchParen ()) ln (peep gp 'LineNr ())
          (string? gr ? (pin b 'ground gr, pin b 'off (hue-off + gr)) 0,
           string? sl ? (pin b 'sel sl) 0,
           string? mp ? (pin b 'match mp) 0,
           string? ln ? (pin b 'lnr ln) 0,
           b)))

   ; --- painting one line -----------------------------------------------------
   ; escapes are zero width, so a caller clips first and paints the clipped text
   (hue-paint pens s runs)
    (: n #s
       (go i l acc)
        (atom? l ? (acc + snip s i n)
           (: r <l k <r a <>r b <>>r p (pens k)
              (string? p ? (go b >l (acc + snip s i a + p + snip s a b + peep pens 'off hue-off))
                 (go b >l (acc + snip s i b)))))
       (go 0 runs ""))
   ; one window [a b) of a line: lexed from column 0, then cut and shifted home
   (hue-win pens lx s in a b)
    (: t (snip s 0 b)
       rs <(lx t in 1)
       (cut l acc)
        (atom? l ? (rev acc)
           (: r <l x <>r y <>>r
              p (x < a ? a x)
              (cut >l (p < y ? ([<r (p - a) (y - a)] . acc) acc))))
       (hue-paint pens (snip t a b) (a < 1 ? rs (cut rs ()))))

   ; --- the theme, and the user's own ------------------------------------------
   ; a theme file under HOME overrides config.l, read as data with `sound`, never evaled.
   ; it opening is what counts, not its bytes; a bad row is skipped. the last bare name picks the theme
   (hue-over rows r) (two? r ? (map (o \ (<o = <r ? r o)) rows) rows)
   (hue-file x)                                    ; -> [name rows], name () for none
    (: h (getenv "HOME")
       q (string? h ? (open (h + hue-theme-file) "r") ())
       (hot? q ? (: t (slurp q)
                    (go x nm acc) (sound x @ r
                                     (? !(two? r) [nm (rev acc)]
                                        (name? <r) (go >r (show <r) acc)
                                        (go >r nm (<r . acc))))
                    f (go t () ())
                    (close q, f))
          [() ()]))
   ; a theme's rows by name, a string or a symbol, or () for none such
   (hue-theme-of nm) (: k (string? nm ? nm (show nm))
                        r (filter (t \ show <t = k) hue-themes)
                        (two? r ? <>(<r) ()))
   ; the theme in force: nm when given, else the file's, else molokai
   (hue-name nm) (string? nm ? nm (<(hue-file ()) @ f (string? f ? f "molokai")))
   (hue-rows nm)
    (: f (hue-file ())
       base (hue-theme-of (hue-name nm) @ b (two? b ? b hue-theme))
       (foldl hue-over base <>f))
   (hue-deep x) (getenv "COLORTERM" @ ct
                   (string? ct ? (ct = "truecolor" || ct = "24bit") ()))
   (hue-wake x) (hue-pens (hue-rows x) (hue-deep ())))
) ; module 'vi
