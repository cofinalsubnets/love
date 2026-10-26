; src/love/holo/lds.l -- a GNU ld script read into love data, for holo's link to lay. load with
; -l after the prel; it only parses, the layout reads what it answers.
;
;   (lds-read text) -> the commands, in order:
;     ('entry "sym")  ('set "sym" op e)  ('provide "sym" e hidden?)  ('assert e "msg")
;     ('sections items)  ('phdrs rows)  ('version "words")  ('arch "x")  ('format "x")
;   a SECTIONS item is a set, provide or assert, or ('osec tablet): 'name 'addr 'type 'lma
;   'align 'subalign 'constraint 'body 'phdrs 'fill. a body item is a set, provide or assert, or
;     ('in keep? filepat pats), each pat (sort "glob"), sort one of none sort sort_by_name ..
;     ('data width e)  ('fill e)
;   an expression is a whole number, a text (a symbol, "." the location counter), or a list:
;     (op a b)  ('neg a)  ('not a)  ('cpl a)  ('? c a b)  ('call "NAME" args)
;
; words split on blanks, ( ) { } ; , and strings; a glob keeps every other character, so
; `___ksymtab+*` stays one word. an expression re-lexes its words into numbers, names and
; operators.

(:
   (lds-sp? c) (c = 32 || c = 9 || c = 10 || c = 13 || c = 12)
   (lds-punc? c) (elem c '(40 41 123 125 59 44))      ; ( ) { } ; ,
   (lds-idc? c) (? (97 <= c && c <= 122) 1 (65 <= c && c <= 90) 1 (48 <= c && c <= 57) 1
                   (elem c '(95 46 36)) 1 0)            ; _ . $

   ;; the words: comments gone, a string one word with its quotes, punctuation alone
   (lds-words s)
    (: n #s
       (opens? i) (s i = 47 && i + 1 < n && s (i + 1) = 42)
       (skipc i) (? (i + 1 >= n) n (s i = 42 && s (i + 1) = 47) (i + 2) (skipc (i + 1)))
       (strend i) (? (i >= n) (scare 'lds-string i) (s i = 34) (i + 1) (strend (i + 1)))
       (wend i) (? (i >= n) n (lds-sp? (s i) || lds-punc? (s i) || s i = 34 || opens? i) i
                   (wend (i + 1)))
       (go i acc)
        (? (i >= n) (rev acc)
           (lds-sp? (s i)) (go (i + 1) acc)
           (opens? i) (go (skipc (i + 2)) acc)
           (lds-punc? (s i)) (go (i + 1) (snip s i (i + 1) . acc))
           (s i = 34) (strend (i + 1) @ j (go j (snip s i j . acc)))
           (wend i @ j (go j (snip s i j . acc))))
       (go 0 ()))

   ;; an expression's tokens out of its words: numbers, names, operators longest first
   lds-ops '("<<=" ">>=" "<<" ">>" "<=" ">=" "==" "!=" "&&" "||" "+=" "-=" "*=" "/=" "&=" "|="
             "+" "-" "*" "/" "%" "<" ">" "!" "~" "&" "|" "^" "?" ":" "=" "(" ")" "," "{" "}" ";")
   (lds-num t)
    (: n #t
       (dig c) (? (48 <= c && c <= 57) (c - 48) (97 <= c && c <= 102) (c - 87)
                  (65 <= c && c <= 70) (c - 55) 99)
       (val i b a) (? (i >= n) a (dig (t i) < b) (val (i + 1) b (a * b + dig (t i))) (scare 'lds-number t))
       last (t (n - 1))
       (? (n > 2 && t 0 = 48 && (t 1 = 120 || t 1 = 88)) (val 2 16 0)
          (last = 75 || last = 107) (1024 * lds-num (snip t 0 (n - 1)))
          (last = 77 || last = 109) (1048576 * lds-num (snip t 0 (n - 1)))
          (val 0 10 0)))
   (lds-xtoks w)
    (: n #w
       (opat i) ((: (g os) (? (atom? os) ()
                              (: o <os (? (i + #o <= n && snip w i (i + #o) = o) o (g >os)))))
                 lds-ops)
       (idend i) (? (i < n && lds-idc? (w i)) (idend (i + 1)) i)
       (tok t) (? (48 <= t 0 && t 0 <= 57) (lds-num t) t)
       (go i acc)
        (? (i >= n) (rev acc)
           (lds-idc? (w i)) (: j (idend i) (go j (tok (snip w i j) . acc)))
           (: o (opat i) (? (string? o) (go (i + #o) (['op o] . acc)) (scare 'lds-char w))))
       (go 0 ()))
   (lds-wtoks ws) (foldr (\ w acc (lds-xtoks w + acc)) () ws)

   ;; precedence climbing over the tokens; each answers (expr . rest)
   lds-bin '(("||" 1) ("&&" 2) ("|" 3) ("^" 4) ("&" 5) ("==" 6) ("!=" 6) ("<" 7) ("<=" 7) (">" 7)
             (">=" 7) ("<<" 8) (">>" 8) ("+" 9) ("-" 9) ("*" 10) ("/" 10) ("%" 10))
   (lds-prec o) ((: (g l) (? (atom? l) 0 (<<l = o) <>(<l) (g >l))) lds-bin)
   (lds-op? t o) (two? t && <t = 'op && <>t = o)
   (lds-binp t) (? (two? t && <t = 'op) (lds-prec <>t) 0)
   (lds-unary ts)
    (: t <ts
       (? (atom? ts) (scare 'lds-expr-end ())
          (lds-op? t "-") (: r (lds-unary >ts) (['neg <r] . >r))
          (lds-op? t "!") (: r (lds-unary >ts) (['not <r] . >r))
          (lds-op? t "~") (: r (lds-unary >ts) (['cpl <r] . >r))
          (lds-op? t "+") (lds-unary >ts)
          (lds-op? t "(") (: r (lds-expr >ts)
                             (? (lds-op? <>r ")") (<r . >>r) (scare 'lds-paren ts)))
          (whole? t) (t . >ts)
          (string? t) (? (lds-op? <>ts "(")                  ; a builtin: ALIGN(..), ADDR(..)
                         (: r (lds-args >>ts ()) (['call t <r] . >r))
                         (t . >ts))
          (scare 'lds-expr ts)))
   (lds-args ts acc)                                       ; after "(", args to ")"
    (? (lds-op? <ts ")") ((rev acc) . >ts)
       (: r (lds-expr ts)
          (? (lds-op? <>r ",") (lds-args >>r (<r . acc))
             (lds-op? <>r ")") ((rev (<r . acc)) . >>r)
             (scare 'lds-args ts))))
   (lds-climb lhs ts minp)
    (: t <ts p (lds-binp t)
       (? (p > 0 && p >= minp)
          (: r (lds-unary >ts)
             (more rhs rs) (: q (lds-binp <rs)
                              (? (q > p) (: x (lds-climb rhs rs (p + 1)) (more <x >x)) (rhs . rs)))
             m (more <r >r)
             (lds-climb [(name <>t) lhs <m] >m minp))
          (lhs . ts)))
   (lds-expr ts)
    (: u (lds-unary ts) r (lds-climb <u >u 1)
       (? (lds-op? <>r "?")
          (: a (lds-expr >>r)
             (? (lds-op? <>a ":") (: b (lds-expr >>a) (['? <r <a <b] . >b)) (scare 'lds-ternary ts)))
          r))
   ; a whole word run is one expression
   (lds-x ws) (: r (lds-expr (lds-wtoks ws)) (? (atom? >r) <r (scare 'lds-trail >r)))

   ;; word runs: up to a depth-0 stop word, parens and braces nesting -> [run rest-at-stop]
   (lds-upto ws stops)
    (: (go l d acc)
        (? (atom? l) [(rev acc) ()]
           (d = 0 && elem <l stops) [(rev acc) l]
           (<l = "(" || <l = "{") (go >l (d + 1) (<l . acc))
           (<l = ")" || <l = "}") (go >l (d - 1) (<l . acc))
           (go >l d (<l . acc)))
       (go ws 0 ()))
   (lds-first l k) (? (atom? l || k < 1) () (<l . lds-first >l (k - 1)))
   (lds-want ws w) (? (<ws = w) >ws (scare 'lds-want [w (lds-first ws 6)]))
   (lds-semi ws) (? (two? ws && <ws = ";") >ws ws)
   (lds-unq w) (? (#w > 1 && w 0 = 34) (snip w 1 (#w - 1)) w)
   ; NAME ( run ) -> [run rest-after-")"]
   (lds-call ws) (: r (lds-upto (lds-want >ws "(") '(")")) [<r >(<>r)])

   ;; an assignment: `sym op expr ;` with the op glued or apart
   lds-aops '("=" "+=" "-=" "*=" "/=" "<<=" ">>=" "&=" "|=")
   (lds-assign? ws)
    (: ts (lds-wtoks (lds-first ws 2))
       (two? ts && string? <ts && two? >ts && two? <>ts && <(<>ts) = 'op && elem <>(<>ts) lds-aops))
   (lds-assign ws)
    (: r (lds-upto ws '(";" "}"))
       ts (lds-wtoks <r)
       [['set <ts (name <>(<>ts)) (lds-x0 >>ts)] (lds-semi <>r)])
   (lds-x0 ts) (: e (lds-expr ts) (? (atom? >e) <e (scare 'lds-trail >e)))
   ; PROVIDE(sym = e), PROVIDE_HIDDEN, HIDDEN; ASSERT(e, "msg")
   (lds-provide ws hid)
    (: c (lds-call ws) ts (lds-wtoks <c)
       [['provide <ts (lds-x0 >>ts) hid] (lds-semi <>c)])
   (lds-assert ws)
    (: c (lds-call ws) r (lds-upto <c '(","))
       [['assert (lds-x <r) (lds-unq <>(<>r))] (lds-semi <>c)])

   ;; an input description: filepat ( pats ), KEEP's around it
   lds-sorts '("SORT" "SORT_BY_NAME" "SORT_BY_ALIGNMENT" "SORT_BY_INIT_PRIORITY" "SORT_NONE")
   (lds-pats ws acc)                                       ; to ")" -> (pats . rest)
    (? (atom? ws) (scare 'lds-pats acc)
       (<ws = ")") ((rev acc) . >ws)
       (elem <ws lds-sorts)
        (: k (name <ws) c (lds-call ws) in (lds-pats (<c + [")"]) ())
           (lds-pats <>c (rev (map (p \ (? (<p = 'none) [k <>p] p)) <in) + acc)))
       (<ws = "EXCLUDE_FILE") (scare 'lds-exclude-file (lds-first ws 6))
       (lds-pats >ws (['none <ws] . acc)))
   (lds-input ws keep)
    (: fp <ws
       _ (? (fp = "EXCLUDE_FILE") (scare 'lds-exclude-file (lds-first ws 6)))
       p (lds-pats (lds-want >ws "(") ())
       [['in keep fp <p] >p])

   ;; one body item -> (item . rest)
   lds-widths '(("BYTE" 1) ("SHORT" 2) ("LONG" 4) ("QUAD" 8) ("SQUAD" 8))
   (lds-width w) ((: (g l) (? (atom? l) 0 (<<l = w) <>(<l) (g >l))) lds-widths)
   (lds-common ws)                                         ; set, provide, assert: () if none
    (: w <ws
       (? (lds-assign? ws) (lds-assign ws)
          (w = "PROVIDE") (lds-provide ws 0)
          (w = "PROVIDE_HIDDEN" || w = "HIDDEN") (lds-provide ws 1)
          (w = "ASSERT") (lds-assert ws)
          ()))
   (lds-item ws)
    (: w <ws cm (lds-common ws)
       (? (two? cm) (<cm . <>cm)
          (w = ";") (['nop] . >ws)
          (w = "CONSTRUCTORS") (['nop] . lds-semi >ws)
          (w = "KEEP") (: r (lds-input (lds-want >ws "(") 1) (<r . lds-semi (lds-want <>r ")")))
          (lds-width w > 0) (: c (lds-call ws) (['data (lds-width w) (lds-x <c)] . lds-semi <>c))
          (w = "FILL") (: c (lds-call ws) (['fill (lds-x <c)] . lds-semi <>c))
          (: r (lds-input ws 0) (<r . lds-semi <>r))))
   (lds-body ws acc)                                       ; to "}" -> (items . rest)
    (? (atom? ws) (scare 'lds-brace (lds-first acc 3))
       (<ws = "}") ((rev acc) . >ws)
       (: r (lds-item ws) (lds-body >r (? (<<r = 'nop) acc (<r . acc)))))

   ;; an output section: name [addr] [(TYPE)] : [AT(e)] [ALIGN(e)] [SUBALIGN(e)] { body } trailers
   (lds-osec ws)
    (: nm <ws
       glued (#nm > 1 && nm (#nm - 1) = 58)                   ; `.text:`
       t {'name (? glued (snip nm 0 (#nm - 1)) nm)}
       hd (? glued [() >ws] (lds-upto >ws '(":")))
       pre <hd
       _ (? (two? pre && <pre = "(") (pin t 'type <>pre) (two? pre) (pin t 'addr (lds-x pre)))
       r1 (? glued >ws >(<>hd))
       (heads l)
        (? (elem <l '("AT" "ALIGN" "SUBALIGN"))
           (: c (lds-call l)
              (pin t (? (<l = "AT") 'lma (<l = "ALIGN") 'align 'subalign) (lds-x <c), heads <>c))
           (elem <l '("ONLY_IF_RO" "ONLY_IF_RW")) (pin t 'constraint (name <l), heads >l)
           (<l = "ALIGN_WITH_INPUT") (heads >l)
           l)
       b (lds-body (lds-want (heads r1) "{") ())
       _ (pin t 'body <b)
       (tails l ph)
        (? (atom? l) (pin t 'phdrs (rev ph), l)
           (#<l > 1 && <l 0 = 58) (tails >l (snip <l 1 #<l . ph))     ; :phdr
           (#<l > 1 && <l 0 = 62) (tails >l ph)                       ; >region
           (#<l > 1 && <l 0 = 61) (pin t 'fill (lds-x [(snip <l 1 #<l)]), tails >l ph)   ; =fill
           (<l = ",") (tails >l ph)
           (pin t 'phdrs (rev ph), l))
       (['osec t] . tails >b ()))

   (lds-sitem ws)
    (: w <ws cm (lds-common ws)
       (? (two? cm) (<cm . <>cm)
          (w = ";") (['nop] . >ws)
          (w = "ENTRY") (: c (lds-call ws) (['entry <<c] . lds-semi <>c))
          (lds-osec ws)))
   (lds-sbody ws acc)
    (? (atom? ws) (scare 'lds-brace (lds-first acc 3))
       (<ws = "}") ((rev acc) . >ws)
       (: r (lds-sitem ws) (lds-sbody >r (? (<<r = 'nop) acc (<r . acc)))))

   ;; PHDRS { name TYPE [FILEHDR] [PHDRS] [AT(e)] [FLAGS(e)] ; }
   (lds-phrow ws)
    (: r (lds-upto ws '(";"))
       w <r
       (flg l acc) (? (atom? l) acc
                      (<l = "FLAGS") (: c (lds-call l) (flg <>c (pin acc 'flags (lds-x <c))))
                      (<l = "AT") (: c (lds-call l) (flg <>c (pin acc 'lma (lds-x <c))))
                      (flg >l (pin acc (name <l) 1)))
       (flg >>w {'name <w 'type <>w} . lds-semi <>r))
   (lds-phdrs ws acc)
    (? (atom? ws) (scare 'lds-brace (lds-first acc 3))
       (<ws = "}") ((rev acc) . >ws)
       (: r (lds-phrow ws) (lds-phdrs >r (<r . acc))))

   ;; the top level
   (lds-top ws acc)
    (? (atom? ws) (rev acc)
       (: w <ws
          (? (w = "SECTIONS") (: r (lds-sbody (lds-want >ws "{") ()) (lds-top >r (['sections <r] . acc)))
             (w = "PHDRS") (: r (lds-phdrs (lds-want >ws "{") ()) (lds-top >r (['phdrs <r] . acc)))
             (w = "VERSION")
              (: r (lds-upto (lds-want >ws "{") '("}"))
                 (lds-top (lds-semi >(<>r)) (['version (foldl (\ a x (a + " " + x)) "" <r)] . acc)))
             (w = "OUTPUT_ARCH") (: c (lds-call ws) (lds-top (lds-semi <>c) (['arch (lds-unq <<c)] . acc)))
             (w = "OUTPUT_FORMAT") (: c (lds-call ws) (lds-top (lds-semi <>c) (['format (lds-unq <<c)] . acc)))
             (: r (lds-sitem ws) (lds-top >r (? (<<r = 'nop) acc (<r . acc)))))))
   (lds-read s) (lds-top (lds-words s) ()))
