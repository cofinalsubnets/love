#!/usr/bin/env -S love -l
; libra ⚖ -- the .l balance tool. `libra` says what is wrong with a file, and
; `libra doc` lifts its header out as a document. balance is lint.l's text scan, which
; reports a torn file; the rules and the comments are read off spans.l's tree.
;
; usage:  libra file ..      weigh them: balance is the default verb
;         libra doc file     its header as a document -- md, -ht html, -rf man
;     or: love -l src/apps/libra/libra.l ..
;
; settings: salt.l -- ~/.love/etc/libra.l, then ./.libra.l over it.

; the head names the exports, so the scanner's helpers stay off the tablet;
; `fatal?` is out because test/host/libra.l pins the gate rule against it.
(module (libra libra-main libra-check libra-doc ldoc-head ldoc-md fatal? lint-of libra-cmts)
(borrow '(lint spans salt cli))

(borrow 'posix)
(:
   ; --- lines ----------------------------------------------------------------
   (ltrim s) (:- (g 0) n #s (g i) (i < n && (s i = 32 || s i = 9) ? (g (i + 1)) (snip s i n)))
   (linesof s) (:- (g 0 0 ()) n #s
                (g i st acc) (? (n <= i) (rev (snip s st n . acc))
                                (s i = 10) (g (i + 1) (i + 1) (snip s st i . acc))
                                (g (i + 1) st acc)))

   ; --- the check ------------------------------------------------------------
   ; `path:line:col: text`, the shape an editor's error list already parses
   (warnline path w) (path + ":" + show <w + ":" + show <>w + ": " + <>>w + "\n")

   ; --- the rules, over the reader's tree --------------------------------------
   ; (lint-of src conf) is the whole weighing: lint-scan's balance, then, on a file that
   ; balances, the rules a config turns on, off spans' nodes. a warning is
   ; [line col text rule]; no config is balance alone, any other has singleton on
   (lint-yes? conf k) (conf k @ (v . _) !!v 1)
   (lname t) (:- (go 0) n #t (go k) (k < n && t k = 39 ? (go (k + 1)) (snip t k n)))
   (lint-dep roster t)
    (atom? roster ? ()
       (: e <roster nm (two? e ? <e e)
          (string nm @ ^t [1 e] (lint-dep >roster t))))
   (lint-depmsg e)
    (: nm (two? e ? <e e) h (two? e && two? >e ? <>e ())
       ("deprecated \(nm)" + (string? h ? " -- \(h)" "")))
   (lopc? c) (elem c "!#$%&*+-./:<=>?\\^|~")
   (ltkc? c) !(c < 33 || elem c '(34 59 40 41 91 93 123 125))
   (lall? p s) (:- (go 0) n #s (go k) (? (n <= k) (0 < n) (p (s k)) (go (k + 1)) ()))
   ; [line col] of each offset in ks, ascending, in one sweep
   (lcols src ks)
    (: n #src
       (go i l c ks acc) (? !(two? ks) (rev acc)
                            (<ks <= i || n <= i) (go i l c >ks ([l c] . acc))
                            (src i = 10) (go (i + 1) (l + 1) 1 ks acc)
                            (go (i + 1) l (c + 1) ks acc))
       (go 0 1 1 ks ()))
   (lint-of src conf)
    (: bal (lint-scan src)
       sg (conf @ () 0 (lint-yes? conf 'singleton))
       dp (conf 'deprecated)
       n #src
       (tok i) (: (go k) (k < n && ltkc? (src k) ? (go (k + 1)) k) (snip src i (go i)))
       ; the token glued before i, empty when i stands free
       (pre i) (: (go k) (0 < k && ltkc? (src (k - 1)) ? (go (k - 1)) k) (snip src (go i) i))
       (list? x) (two? (x 0))
       (from x) (x 1 0)
       ; a binder slot: a `:` form's names (an odd index past its head), any element past a `\`
       (bind? p k) (: h (p 0 0) t (tok (from h))
                      (? !(two? (p 0)) () (t = ":") (k % 2 = 1) (t = "\\") (1 <= k) ()))
       (last? p k) (k + 1 = #(p 0))
       ; a (x) where (x) == x: not data, not glued to a sigil or operator, not a hole, not
       ; in a match's arms, its one element not all punctuation; in a binder slot (or one
       ; level in) only the body warns
       (single x q am up)
        (: kids (x 0) a (from x) g (pre a)
           (? (!sg || q || am || src a != 40 || #kids != 1) ()
              (0 < a && src (a - 1) = 92) ()
              (0 < #g && (lall? lopc? g || lall? (c \ c = 39 || c = 64) g)) ()
              (lall? lopc? (tok (from <kids))) ()
              (: t (tok (from <kids))
                 wr [a ("singleton " + (0 < #t ? "(\(t)) " "") + "-- (x) == x") 'singleton]
                 (up @ [[p k] gp]
                    (? (bind? p k) (last? p k ? [wr] ())
                       (two? gp && bind? (gp 0) (gp 1)) (last? (gp 0) (gp 1) ? [wr] ())
                       [wr])
                    _ [wr]))))
       ; a quoted name warns at its quote
       (qb k) (0 < k && src (k - 1) = 39 ? (qb (k - 1)) k)
       (dep x)
        (: f (x 0) t (snip src (from x) (x 1 1))
           (? (!(two? dp) || !(nom? f)) ()
              (lint-dep dp (lname t) @ r (two? r ? [[(qb (from x)) (lint-depmsg <>r) 'deprecated]] ()))))
       ; a warning is [offset text rule] until the sweep lays its line and column
       ; q: inside quoted data; am: past a bare `@` in an enclosing form; up: [[parent index] grandparent]
       (walk x q am up)
        (? !(list? x) (dep x)
           (: kids (x 0)
              qq (q || (nom? (kids 0 0) && kids 0 0 = (nom "\\") && src (from x) = 39))
              (go ks k am2 acc)
               (? !(two? ks) acc
                  (: c <ks
                     am3 (am2 || (c 0 = (nom "@") && snip src (from c) (c 1 1) = "@"))
                     (go >ks (k + 1) am3 (acc + walk c qq am2 [[x k] (up @ [pk _] pk _ ())]))))
              (single x q am up + go kids 0 am ())))
       ws (? (two? bal || !(sg || two? dp)) () (trap spans src (a \ b \ ()) @ ts (sort (catmap (t \ walk t 0 0 ()) ts))))
       rules (map (p \ [(>p 0) (>p 1) (<p 1) (<p 2)]) (zip ws (lcols src (map (w \ w 0) ws))))
       (sort (bal + rules)))

   ; every comment in reading order, [line col text kind], 1-based at the introducer and the
   ; text past it, kind 'semi or 'bang; none for a file that does not read
   (libra-cmts src)
    (: (notes x) (x 2 + (two? (x 0) ? (catmap notes (x 0)) ()))
       ; a file of no forms is blanks and comments alone, with no node to keep them
       (bare i acc) (: (eol k) (k < #src && src k != 10 ? (eol (k + 1)) k)
                       (? (#src <= i) (rev acc)
                          (src i < 33) (bare (i + 1) acc)
                          (bare (eol i) ([(snip src i (eol i)) [i (eol i)]] . acc))))
       ns (trap spans src (a \ b \ ()) @ ts (two? ts ? (catmap notes ts) (sounds src @ () (bare 0 ()) _ ())))
       ms (map (p \ <>p) (sort (map (m \ [(m 1 0) m]) ns)))
       (one m w) (: t (m 0) b (t 0 = 35) [(w 0) (w 1) (snip t (b ? 2 1) #t) (b ? 'bang 'semi)])
       (map (p \ one <p >p) (zip ms (lcols src (map (m \ m 1 0) ms)))))

   ; --- the verbs ------------------------------------------------------------

   ; balance alone fails; the other rules only speak
   (fatal? w) (<>>>w = 'balance)
   (tally-fatal ws) (foldl (a \ w \ fatal? w ? (a + 1) a) 0 ws)

   (libra-check-files conf fs bad)
    (atom? fs ? bad
       (uread <fs @ r
          (atom? r ? (say err ("libra: cannot open " + <fs + "\n"),
                      libra-check-files conf >fs (bad + 1))
             (: src <>r
                bw (lint-of src conf)
                (foldl (\ _ w (say err (warnline <fs w), 0)) 0 bw,
                 libra-check-files conf >fs (bad + tally-fatal bw))))))

   ; the count is the status, answered not quit with: a caller in this image reads it
   (libra-check conf fs) (0 < libra-check-files conf fs 0)

   (flag? x) (0 < #x && x 0 = 45)
   files (filter (nil? * flag?))

   ; --- the header, as a document --------------------------------------------
   ; the comments spans keeps; the header runs to the first line carrying code, blanks
   ; included
   (dblank? s) !(0 < #(ltrim s))
   ; one leading space off, so a bare `;` is a blank line
   (dbody s) (#s @ n (0 < n && s 0 = 32 ? (snip s 1 n) s))
   (dcmts src) ({} @ t (each (libra-cmts src) (c \ pin t <c c), t))
   (dalone ln c) (<>c - 1 @ k
                    (dblank? (snip ln 0 k) ? [1 (snip ln 0 k + dbody <>>c)] ()))
   (drtrim l) (two? l ? (drtrim >l @ r (two? r || !(dblank? <l) ? (<l . r) ())))

   ; a `#!` line is skipped
   (ldoc-head src)
    (: t (dcmts src)
       (g ls k acc)
        (atom? ls ? (drtrim (rev acc))
           (: c (t k)
              a (two? c ? (dalone <ls c) ())      ; the line's own sentence, if it is one
              (? (atom? a) (dblank? <ls ? (g >ls (k + 1) ("" . acc))
                             (drtrim (rev acc)))   ; code: the header ends
                 (<>>>c = 'bang) (g >ls (k + 1) acc)
                 (g >ls (k + 1) (<>a . acc)))))
       (g (linesof src) 1 ()))

   ; prose as written, but a `--- name ---` banner is a heading, an indented run
   ; a fence (its alignment is the content), and a list item stays an item
   (dind s) (: n #s (g i) (i < n && (s i = 32 || s i = 9) ? (g (i + 1)) i) (g 0))
   (ddashy? c) (c = 45 || c = 32)
   ; `--- name ------------` -> [1 "name"]
   (dbanner s)
    (#s @ n
       (? !(3 <= n && snip s 0 3 = "---") ()
          (: a ((: (f i) (i < n && ddashy? (s i) ? (f (i + 1)) i)) 0)
             b ((: (f j) (a < j && ddashy? (s (j - 1)) ? (f (j - 1)) j)) n)
             (a < b ? [1 (snip s a b)] ()))))
   (ditem? s)
    (#s @ n (2 <= n && snip s 0 2 = "- " || 3 <= n && 47 < s 0 && s 0 < 58 && snip s 1 3 = ". "))

   ; a display: the run of indented lines at the head of ls, and what is left.
   (dtake ls) (:- (g ls ()) (g l acc)
    (atom? l || dblank? <l || !(0 < dind <l) ? [(rev acc) l] (g >l (<l . acc))))
   ; ..fenced, dedented by its own least indent
   (dmin a b) (a < b ? a b)
   (dfence ls)
    (foldl (a \ s \ dblank? s ? a (dmin a (dind s))) #<ls ls @ k
       ("```\n" + foldl (+) "" (map (s \ snip s (dmin k #s) #s + "\n") ls)
        + "```\n"))

   ; the header as markdown. li: last line was a list item or its wrap, which
   ; decides what an indented line means
   (ldoc-md src)
    (: (go ls li acc)
        (atom? ls ? acc
           (: s <ls
              b (dbanner s)
              (? (dblank? s)         (go >ls 0 (acc + "\n"))
                 (two? b)            (go >ls 0 (acc + "## " + <>b + "\n"))
                 (starts? s "usage:")
                  (dtake >ls @ r (go <>r 0 (acc + dfence (s . <r))))
                 (0 < dind s && li)  (go >ls 1 (acc + s + "\n"))
                 (0 < dind s)        (dtake ls @ r (go <>r 0 (acc + dfence <r)))
                 (ditem? s)          (go >ls 1 (acc + s + "\n"))
                 (go >ls 0 (acc + s + "\n")))))
       (go (ldoc-head src) 0 ""))

   ; --- doc ------------------------------------------------------------------
   ; the `# name` carries a page's title and nav. lapiz loads here, not at the
   ; top: `make lint` runs check over every .l and pays for what this file names
   (libra-doc-files fs surf bad)
    (atom? fs ? bad
       (uread <fs @ r
          (atom? r ? (say err ("libra: cannot open " + <fs + "\n"),
                      libra-doc-files >fs surf (bad + 1))
             (: body (ldoc-md <>r)
                md ("# " + <fs + "\n\n" + body)
                (? !(0 < #body)
                    (say err (<fs + ": no header comment\n"),
                     libra-doc-files >fs surf (bad + 1))
                   (say out (surf @ 'md md (cite 'lapiz (surf @ 'ht 'md->ht 'md->rf) md)),
                    libra-doc-files >fs surf bad))))))
   (libra-doc fs surf)
    (surf @ 'md 0 (borrow 'lapiz),
     0 < libra-doc-files fs surf 0)

   ; above its reader: only lambda-to-lambda recursion resolves lazily
   usage """
    usage: libra [check] FILE ..   balance: path:line:col: on err, quiet when
                                   clean, exit 1. THE DEFAULT.
           libra doc FILE ..      the file's HEADER as a document, on stdout
                                  markdown by default; -ht for html, -rf for man
      config: ~/.love/etc/libra.l, then ./.libra.l over it -- (singleton 0),
              (deprecated old (worse "use better")). doc/misc/libra.md

    """

   libra-help ("libra ⚖ -- the .l balance tool.\n" + usage)
   ; the config is read once, here, and handed down
   (libra-main as)
    (: conf (salt 'libra)
       v (two? as ? <as "")
       r >as
       ; `files` drops every dash word: name the known ones, refuse the rest
       bad (<(filter (x \ flag? x && !(elem x '("-ht" "-rf"))) as))
       (? (string? bad) (say err ("libra: unknown option " + bad), put err 10, 2)
          (v = "check") (libra-check conf (files r))
          (v = "doc")   (libra-doc (files r) (? (elem "-ht" r) 'ht
                                                (elem "-rf" r) 'rf
                                                'md))
          (v = "")      (say err usage, 1)
          ; no verb: the whole line is files, so an unknown verb says "cannot open"
          (libra-check conf (files as))))
)

; the verb, and the seat: `love libra ..` is a word on the artifact, and libra-main
; fires iff this file is the program of the real command line
(: door (udoor 'libra libra-main libra-help 1 1)
   _ (cite 'verbs 'enlist 'libra door ['self])
   s (cite 'verbs 'fire ["libra" "libra.l"])
   ; quit, never return: the shebang's -l makes this a preload, so answering
   ; would load our first argument as a program. the seat miss does return
   (two? s ? (door >s @ r (quit (charm? r ? r 0)))))
) ; module libra
