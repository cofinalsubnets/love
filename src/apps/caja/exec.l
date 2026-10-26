; src/apps/caja/exec.l -- caja's stomach: tex.web's chief executive and its mode-independent
; commands (parts 46 and 49), print_cmd_chr, and the main program (part 51). the second part
; of the module caja-tex, after mouth.l.
(module 'caja-tex
(borrow 'posix)
(borrow 'tfm)
(borrow 'caja-box)
(:
   ; --- print_cmd_chr (tex.web 227-1346) ---------------------------------------------------
   ; what a command prints when its chr is none of its primitives'
   cmd-defaults
    [[assign-toks "errhelp"] [input "endinput"] [top-bot-mark "topmark"] [register "muskip"]
     [set-aux "spacefactor"] [set-page-int "insertpenalties"] [set-box-dimen "dp"]
     [last-item "badness"] [convert "jobname"] [if-test "if"] [fi-or-else "else"]
     [car-ret "crcr"] [set-page-dimen "pagedepth"] [stop "end"] [hskip "hfilneg"]
     [vskip "vfilneg"] [hmove "moveright"] [vmove "lower"] [make-box "hbox"]
     [leader-ship "shipout"] [start-par "indent"] [remove-item "unpenalty"] [un-hbox "unhcopy"]
     [un-vbox "unvcopy"] [discretionary "discretionary"] [eq-no "eqno"] [math-comp "overline"]
     [limit-switch "displaylimits"] [above "above"] [left-right "right"] [prefix "global"]
     [def "xdef"] [let-cmd "futurelet"] [shorthand-def "toksdef"] [def-code "delcode"]
     [hyph-data "hyphenation"] [assign-font-int "skewchar"] [set-interaction "errorstopmode"]
     [in-stream "openin"] [message "errmessage"] [case-shift "uppercase"] [xray "show"]]
   (cmd-key cmd chr) (cmd * 100000 + chr)
   (init-cmd-names J)
    (: names {} dflt {}
       _ (map (\ p (: c (p 1) n (p 0)
                      (pin names (cmd-key c (p 2)) n,
                       pin dflt c (peep dflt c () = () ? n 'many))))
              primitive-table)
       _ (map (\ p (pin dflt (p 0) (p 1))) cmd-defaults)
       (pins J 'cmd-names names 'cmd-default dflt))
   (chr-cmd J s chr) (print J s, print J chr)
   (font-name-at J f)
    (: F (J 'fonts f) t (F 'tfm)
       (slow-print J (F 'name),
        t 'size != t 'dsize ? (print J " at ", print-scaled J (t 'size), print J "pt")))
   (print-cmd-chr J cmd chr)
    (? (cmd = left-brace) (chr-cmd J "begin-group character " chr)
       (cmd = right-brace) (chr-cmd J "end-group character " chr)
       (cmd = math-shift) (chr-cmd J "math shift character " chr)
       (cmd = mac-param) (chr-cmd J "macro parameter character " chr)
       (cmd = sup-mark) (chr-cmd J "superscript character " chr)
       (cmd = sub-mark) (chr-cmd J "subscript character " chr)
       (cmd = endv) (print J "end of alignment template")
       (cmd = spacer) (chr-cmd J "blank space " chr)
       (cmd = letter) (chr-cmd J "the letter " chr)
       (cmd = other-char) (chr-cmd J "the character " chr)
       (cmd = tab-mark && chr != span-code) (chr-cmd J "alignment tab character " chr)
       (cmd = assign-glue || cmd = assign-mu-glue)
        (? (chr < skip-base) (print-skip-param J (chr - glue-base))
           (chr < mu-skip-base) (print-esc J "skip", print-int J (chr - skip-base))
           (print-esc J "muskip", print-int J (chr - mu-skip-base)))
       (cmd = assign-toks && chr >= toks-base) (print-esc J "toks", print-int J (chr - toks-base))
       (cmd = assign-int)
        (? (chr < count-base) (print-param J (chr - int-base))
           (print-esc J "count", print-int J (chr - count-base)))
       (cmd = assign-dimen)
        (? (chr < scaled-base) (print-length-param J (chr - dimen-base))
           (print-esc J "dimen", print-int J (chr - scaled-base)))
       (cmd = set-font) (print J "select font ", font-name-at J chr)
       (cmd = char-given) (print-esc J "char", print-hex J chr)
       (cmd = math-given) (print-esc J "mathchar", print-hex J chr)
       (cmd = def-family) (print-size J (chr - math-font-base))
       (cmd = math-style) (print-style J chr)
       (cmd = undefined-cs) (print J "undefined")
       (cmd = call) (print J "macro")
       (cmd = long-call) (print-esc J "long macro")
       (cmd = outer-call) (print-esc J "outer macro")
       (cmd = long-outer-call) (print-esc J "long", print-esc J "outer macro")
       (cmd = end-template) (print-esc J "outer endtemplate")
       (cmd = extension && chr > set-language-code) (print J "[unknown extension!]")
       (: s (peep (J 'cmd-names) (cmd-key cmd chr) ())
          d (peep (J 'cmd-default) cmd ())
          (? (s != ()) (print-esc J s)
             (string? d) (print-esc J d)
             (print J "[unknown command code!]"))))

   ; --- the chief executive's small cases (tex.web 1045-1069) -------------------------------
   (you-cant J)
    (print-err J "You can't use `", print-cmd-chr J (J 'cur-cmd) (J 'cur-chr),
     print J "' in ", print-mode J (mode J))
   (report-illegal-case J)
    (you-cant J,
     set-help J ["Sorry, but I'm not programmed to handle this case;"
                 "I'll just pretend that you didn't ask for it."
                 "If you're in the wrong mode, you might be able to"
                 "return to the right one by typing `I}' or `I$' or `I\\par'."],
     tex-error J)
   (privileged? J) (mode J > 0 ? 1 (report-illegal-case J, 0))
   (insert-dollar-sign J)
    (back-input J, pin J 'cur-tok (math-shift-token + 36),
     print-err J "Missing $ inserted",
     set-help J ["I've inserted a begin-math/end-math symbol since I think"
                 "you left one out. Proceed, with fingers crossed."],
     ins-error J)
   (its-all-over? J)
    (? (!(privileged? J)) 0
       (J 'page-contents-list = () && J 'cur-list 'head == J 'cur-list 'tail && J 'dead-cycles = 0) 1
       (not-yet J "the page builder"))
   (off-save J)
    (? (J 'cur-group = bottom-level)
        (print-err J "Extra ", print-cmd-chr J (J 'cur-cmd) (J 'cur-chr),
         set-help J ["Things are pretty mixed up, but I think the worst is over."], tex-error J)
       (: _ (back-input J) _ (print-err J "Missing ")
          g (J 'cur-group)
          l (? (g = semi-simple-group) (print-esc J "endgroup", [(cs-token-flag + frozen-end-group)])
               (g = math-shift-group) (print-char J 36, [(math-shift-token + 36)])
               (g = math-left-group)
                (print-esc J "right.", [(cs-token-flag + frozen-right) (other-token + 46)])
               (print-char J 125, [(right-brace-token + 125)]))
          _ (print J " inserted") _ (ins-list J l)
          _ (set-help J ["I've inserted something that you may have forgotten."
                         "(See the <inserted text> above.)"
                         "With luck, this will get me unwedged. But if you"
                         "really didn't forget anything, try typing `2' now; then"
                         "my insertion and my current dilemma will both disappear."])
          (tex-error J)))
   (handle-right-brace J)
    (: g (J 'cur-group)
       (? (g = simple-group) (unsave J)
          (g = bottom-level)
           (print-err J "Too many }'s",
            set-help J ["You've closed more groups than you opened."
                        "Such booboos are generally harmless, so keep going."],
            tex-error J)
          (g = semi-simple-group || g = math-shift-group || g = math-left-group) (extra-right-brace J)
          (not-yet J "this group's end")))
   (extra-right-brace J)
    (: g (J 'cur-group)
       _ (print-err J "Extra }, or forgotten ")
       _ (? (g = semi-simple-group) (print-esc J "endgroup")
            (g = math-shift-group) (print-char J 36)
            (print-esc J "right"))
       _ (set-help J ["I've deleted a group-closing symbol because it seems to be"
                      "spurious, as in `$x}$'. But perhaps the } is legitimate and"
                      "you forgot something else, as in `\\hbox{$x}'. In such cases"
                      "the way to recover is to insert both the forgotten and the"
                      "deleted material, e.g., by typing `I$}'."])
       _ (tex-error J)
       (pin J 'align-state (J 'align-state + 1)))
   ; what caja cannot do yet: said plainly, and the run ends
   (not-yet J what)
    (print-err J "caja cannot yet do ", print J what, print J " (", print-cmd-chr J (J 'cur-cmd) (J 'cur-chr),
     print-char J 41, set-help J [], pin J 'history fatal-error-stop, jump-out J)

   ; --- mode-independent processing (tex.web 1208-1298) -----------------------------------
   (non-blank-non-relax J)
    (get-x-token J, J 'cur-cmd = spacer || J 'cur-cmd = relax ? (non-blank-non-relax J))
   (define J a p t e) (a >= 4 ? (geq-define J p t e) (eq-define J p t e))
   (word-define J a p w) (a >= 4 ? (geq-word-define J p w) (eq-word-define J p w))
   (prefixed-command J)
    (: (go a)
        (? (J 'cur-cmd != prefix) a
           (: c (J 'cur-chr) a2 ((a // c) % 2 = 0 ? (a + c) a)
              _ (non-blank-non-relax J)
              (? (J 'cur-cmd <= max-non-prefixed-command)
                  (print-err J "You can't use a prefix with `",
                   print-cmd-chr J (J 'cur-cmd) (J 'cur-chr), print-char J 39,
                   set-help J ["I'll pretend you didn't say \\long or \\outer or \\global."],
                   back-error J, 'exit)
                 (go a2))))
       a0 (go 0)
       (a0 != 'exit ?
          (: _ (J 'cur-cmd != def && a0 % 4 != 0 ?
                  (print-err J "You can't use `", print-esc J "long", print J "' or `",
                   print-esc J "outer", print J "' with `", print-cmd-chr J (J 'cur-cmd) (J 'cur-chr),
                   print-char J 39,
                   set-help J ["I'll pretend you didn't say \\long or \\outer here."], tex-error J))
             gd (int-par J global-defs-code)
             a (? (gd = 0) a0 (gd < 0) (a0 >= 4 ? (a0 - 4) a0) (a0 >= 4 ? a0 (a0 + 4)))
             _ (assignment J a)
             (J 'after-token != 0 ?
                (pin J 'cur-tok (J 'after-token), back-input J, pin J 'after-token 0)))))
   (get-r-token J)
    (: (go _) (get-token J, J 'cur-tok = space-token ? (go ()))
       _ (go ())
       (J 'cur-cs = 0 || J 'cur-cs > frozen-control-sequence ?
          (print-err J "Missing control sequence inserted",
           set-help J ["Please don't say `\\def cs{...}', say `\\def\\cs{...}'."
                       "I've inserted an inaccessible control sequence so that your"
                       "definition will be completed without mixing me up too badly."
                       "You can recover graciously from this error, if you're"
                       "careful; see exercise 27.2 in The TeXbook."],
           J 'cur-cs = 0 ? (back-input J),
           pin J 'cur-tok (cs-token-flag + frozen-protection), ins-error J, get-r-token J)))
   (trap-zero-glue J)
    (J 'cur-val @ g
       (g 'width = 0 && g 'stretch = 0 && g 'shrink = 0 ? (pin J 'cur-val (J 'zero-glue))))
   (assignment J a)
    (: cmd (J 'cur-cmd) chr (J 'cur-chr)
       (? (cmd = set-font) (define J a cur-font-loc data chr)
          (cmd = def)
           (: a2 (chr % 2 = 1 && a < 4 && int-par J global-defs-code >= 0 ? (a + 4) a)
              _ (get-r-token J) p (J 'cur-cs)
              l (scan-toks J 1 (chr >= 2))
              (define J a2 p (call + (a2 % 4)) l))
          (cmd = let-cmd) (assign-let J a chr)
          (cmd = shorthand-def) (do-shorthand-def J a chr)
          (cmd = read-to-cs)
           (: _ (scan-int J) n (J 'cur-val)
              _ (!(scan-keyword J "to") ?
                   (print-err J "Missing `to' inserted",
                    set-help J ["You should have said `\\read<number> to \\cs'."
                                "I'm going to look for the \\cs now."],
                    tex-error J))
              _ (get-r-token J) p (J 'cur-cs)
              _ (read-toks J n p)
              (define J a p call (J 'cur-val)))
          (cmd = toks-register || cmd = assign-toks) (assign-toks-cmd J a)
          (cmd = assign-int)
           (scan-optional-equals J, scan-int J, word-define J a chr (J 'cur-val))
          (cmd = assign-dimen)
           (scan-optional-equals J, scan-normal-dimen J, word-define J a chr (J 'cur-val))
          (cmd = assign-glue || cmd = assign-mu-glue)
           (scan-optional-equals J, scan-glue J (cmd = assign-mu-glue ? mu-val glue-val),
            trap-zero-glue J, define J a chr glue-ref (J 'cur-val))
          (cmd = def-code) (assign-def-code J a chr)
          (cmd = def-family)
           (: _ (scan-four-bit-int J) p (chr + J 'cur-val)
              _ (scan-optional-equals J) _ (scan-font-ident J)
              (define J a p data (J 'cur-val)))
          (cmd >= register && cmd <= divide) (do-register-command J a)
          (cmd = set-aux) (alter-aux J)
          (cmd = set-prev-graf) (alter-prev-graf J)
          (cmd = set-page-dimen)
           (scan-optional-equals J, scan-normal-dimen J, pin (J 'page-so-far) chr (J 'cur-val))
          (cmd = set-page-int)
           (scan-optional-equals J, scan-int J,
            pin J (chr = 0 ? 'dead-cycles 'insert-penalties) (J 'cur-val))
          (cmd = set-box-dimen)
           (: _ (scan-eight-bit-int J) b (equiv J (box-base + J 'cur-val))
              _ (scan-optional-equals J) _ (scan-normal-dimen J)
              (b != () ?
                 (pin b (? (chr = width-offset) 'width (chr = height-offset) 'height 'depth)
                      (J 'cur-val))))
          (cmd = set-shape)
           (: _ (scan-optional-equals J) _ (scan-int J) n (J 'cur-val)
              (pair _) (: _ (scan-normal-dimen J) i (J 'cur-val) _ (scan-normal-dimen J)
                          [i (J 'cur-val)])
              (go k acc) (k > n ? (rev acc) (go (k + 1) (pair () . acc)))
              (define J a par-shape-loc shape-ref (n <= 0 ? () (go 1 ()))))
          (cmd = assign-font-dimen)
           (: _ (find-font-dimen J 1) fd (J 'fd)
              _ (scan-optional-equals J) _ (scan-normal-dimen J)
              (fd != () ? (pin (J 'fonts (fd 0) 'tfm 'param) (fd 1) (J 'cur-val))))
          (cmd = assign-font-int)
           (: _ (scan-font-ident J) f (J 'cur-val)
              _ (scan-optional-equals J) _ (scan-int J)
              (pin (J 'fonts f) (chr = 0 ? 'hyphenchar 'skewchar) (J 'cur-val)))
          (cmd = def-font) (new-font J a)
          (cmd = set-interaction) (new-interaction J chr)
          (cmd = set-box) (not-yet J "boxes")
          (cmd = hyph-data) (not-yet J "hyphenation")
          (confusion J "prefix")))
   (assign-let J a n)
    (: _ (get-r-token J) p (J 'cur-cs)
       _ (? (n = normal)
             (: (sp _) (get-token J, J 'cur-cmd = spacer ? (sp ()))
                _ (sp ())
                (J 'cur-tok = other-token + 61 ?
                   (get-token J, J 'cur-cmd = spacer ? (get-token J))))
            (: _ (get-token J) q (J 'cur-tok) _ (get-token J) _ (back-input J)
               (pin J 'cur-tok q, back-input J)))
       (define J a p (J 'cur-cmd) (J 'cur-chr)))
   (do-shorthand-def J a n)
    (: _ (get-r-token J) p (J 'cur-cs)
       _ (define J a p relax 256)
       _ (scan-optional-equals J)
       (? (n = char-def-code) (scan-char-num J, define J a p char-given (J 'cur-val))
          (n = math-char-def-code) (scan-fifteen-bit-int J, define J a p math-given (J 'cur-val))
          (: _ (scan-eight-bit-int J) v (J 'cur-val)
             (? (n = count-def-code) (define J a p assign-int (count-base + v))
                (n = dimen-def-code) (define J a p assign-dimen (scaled-base + v))
                (n = skip-def-code) (define J a p assign-glue (skip-base + v))
                (n = mu-skip-def-code) (define J a p assign-mu-glue (mu-skip-base + v))
                (define J a p assign-toks (toks-base + v))))))
   (assign-toks-cmd J a)
    (: q (J 'cur-cs)
       p (J 'cur-cmd = toks-register ? (scan-eight-bit-int J, toks-base + J 'cur-val) (J 'cur-chr))
       _ (scan-optional-equals J)
       _ (non-blank-non-relax J)
       _ (J 'cur-cmd = toks-register ?
            (scan-eight-bit-int J, pins J 'cur-cmd assign-toks 'cur-chr (toks-base + J 'cur-val)))
       (? (J 'cur-cmd = assign-toks)
           (equiv J (J 'cur-chr) @ l (l = () ? (define J a p undefined-cs ()) (define J a p call l)))
          (: _ (back-input J) _ (pin J 'cur-cs q)
             l (scan-toks J 0 0)
             (? (l = ()) (define J a p undefined-cs ())
                (define J a p call
                   (p = output-routine-loc ? ((left-brace-token + 123) . (l + [(right-brace-token + 125)])) l))))))
   (assign-def-code J a chr)
    (: n (? (chr = cat-code-base) max-char-code (chr = math-code-base) 32768
            (chr = sf-code-base) 32767 (chr = del-code-base) 16777215 255)
       _ (scan-char-num J) p (chr + J 'cur-val)
       _ (scan-optional-equals J) _ (scan-int J)
       _ ((J 'cur-val < 0 && p < del-code-base) || J 'cur-val > n ?
            (print-err J "Invalid code (", print-int J (J 'cur-val),
             print J (p < del-code-base ? "), should be in the range 0.." "), should be at most "),
             print-int J n,
             set-help J ["I'm going to use 0 instead of that illegal code value."],
             tex-error J, pin J 'cur-val 0))
       (p < del-code-base ? (define J a p data (J 'cur-val)) (word-define J a p (J 'cur-val))))
   (do-register-command J a)
    (: q (J 'cur-cmd)
       lp (? (q != register)
              (: _ (get-x-token J)
                 (? (J 'cur-cmd >= assign-int && J 'cur-cmd <= assign-mu-glue)
                     [(J 'cur-chr) (J 'cur-cmd - assign-int)]
                    (J 'cur-cmd != register)
                     (print-err J "You can't use `", print-cmd-chr J (J 'cur-cmd) (J 'cur-chr),
                      print J "' after ", print-cmd-chr J q 0,
                      set-help J ["I'm forgetting what you said and not changing anything."],
                      tex-error J, ())
                    (register-loc J)))
              (register-loc J))
       (lp != () ? (register-op J a q (lp 0) (lp 1))))
   (register-loc J)
    (: p (J 'cur-chr) _ (scan-eight-bit-int J) v (J 'cur-val)
       [(? (p = int-val) (count-base + v) (p = dimen-val) (scaled-base + v)
           (p = glue-val) (skip-base + v) (mu-skip-base + v))
        p])
   (register-op J a q l p)
    (: _ (? (q = register) (scan-optional-equals J) (scan-keyword J "by"))
       _ (pin J 'arith-error 0)
       _ (? (q < multiply)
             (? (p < glue-val)
                 (: _ (p = int-val ? (scan-int J) (scan-normal-dimen J))
                    (q = advance ? (pin J 'cur-val (J 'cur-val + J 'eq l))))
                (: _ (scan-glue J p) (q = advance ? (pin J 'cur-val (glue-sum (J 'cur-val) (equiv J l))))))
            (: _ (scan-int J) n (J 'cur-val)
               (? (p < glue-val)
                   (pin J 'cur-val
                      (? (q = multiply)
                          (p = int-val ? (mult-integers J (J 'eq l) n) (nx-plus-y J (J 'eq l) n 0))
                         (x-over-n J (J 'eq l) n)))
                  (: s (equiv J l) r (new-spec s)
                     f (q = multiply ? (\ x (nx-plus-y J x n 0)) (\ x (x-over-n J x n)))
                     _ (pins r 'width (f (s 'width)) 'stretch (f (s 'stretch)) 'shrink (f (s 'shrink)))
                     (pin J 'cur-val r)))))
       (? (J 'arith-error)
           (print-err J "Arithmetic overflow",
            set-help J ["I can't carry out that multiplication or division,"
                        "since the result is out of range."],
            tex-error J)
          (p < glue-val) (word-define J a l (J 'cur-val))
          (trap-zero-glue J, define J a l glue-ref (J 'cur-val))))
   (glue-sum q0 r)
    (: q (new-spec q0)
       _ (pin q 'width (q 'width + r 'width))
       _ (q 'stretch = 0 ? (pin q 'sto normal))
       _ (? (q 'sto = r 'sto) (pin q 'stretch (q 'stretch + r 'stretch))
            (q 'sto < r 'sto && r 'stretch != 0) (pins q 'stretch (r 'stretch) 'sto (r 'sto)))
       _ (q 'shrink = 0 ? (pin q 'sho normal))
       _ (? (q 'sho = r 'sho) (pin q 'shrink (q 'shrink + r 'shrink))
            (q 'sho < r 'sho && r 'shrink != 0) (pins q 'shrink (r 'shrink) 'sho (r 'sho)))
       q)
   (alter-aux J)
    (: c (J 'cur-chr)
       (? (c != abs (mode J)) (report-illegal-case J)
          (: _ (scan-optional-equals J)
             (? (c = vmode) (scan-normal-dimen J, pin (J 'cur-list) 'prev-depth (J 'cur-val))
                (: _ (scan-int J) v (J 'cur-val)
                   (? (v <= 0 || v > 32767)
                       (print-err J "Bad space factor",
                        set-help J ["I allow only values in the range 1..32767 here."], int-error J v)
                      (pin (J 'cur-list) 'space-factor v)))))))
   (alter-prev-graf J)
    (: (find l) (abs (<l 'mode) = vmode ? <l (find >l))
       n (find (J 'cur-list . J 'nest))
       _ (scan-optional-equals J) _ (scan-int J)
       (? (J 'cur-val < 0)
           (print-err J "Bad ", print-esc J "prevgraf",
            set-help J ["I allow only nonnegative values here."], int-error J (J 'cur-val))
          (pin n 'pg (J 'cur-val))))
   (new-interaction J c)
    (print-ln J, pin J 'interaction c,
     pin J 'selector (c = batch-mode ? no-print term-only),
     J 'log-opened ? (pin J 'selector (J 'selector + 2)))

   ; --- fonts (tex.web 560-576, 1257-1260) ---------------------------------------------------
   (new-font J a)
    (: _ (J 'job-name = () ? (open-log-file J))
       _ (get-r-token J) u (J 'cur-cs)
       t (? (u >= hash-base) (J 'text u)
            (u = null-cs) "FONT"
            (u >= single-base) (string (u - single-base))
            (in-new-string J (\ _ (print J "FONT", print J (u - active-base)))))
       _ (define J a u set-font null-font)
       _ (scan-optional-equals J) _ (scan-file-name J)
       _ (pin J 'name-in-progress 1)
       s (? (scan-keyword J "at")
             (: _ (scan-normal-dimen J) s (J 'cur-val)
                (? (s <= 0 || s >= 134217728)
                   (print-err J "Improper `at' size (", print-scaled J s, print J "pt), replaced by 10pt",
                    set-help J ["I can only handle fonts at positive sizes that are"
                                "less than 2048pt, so I've changed what you said to 10pt."],
                    tex-error J, 10 * unity)
                   s))
            (scan-keyword J "scaled")
             (: _ (scan-int J) v (J 'cur-val)
                (? (v <= 0 || v > 32768)
                   (print-err J "Illegal magnification has been changed to 1000",
                    set-help J ["The magnification ratio must be between 1 and 32768."],
                    int-error J v, -1000)
                   (0 - v)))
            -1000)
       _ (pin J 'name-in-progress 0)
       nm (J 'cur-name) ar (J 'cur-area)
       (same f)
        (: F (J 'fonts f) t (F 'tfm)
           (F 'name = nm && F 'area = ar
            && (s > 0 ? (s = t 'size) (t 'size = xn-over-d J (t 'dsize) (0 - s) 1000))))
       (loaded f) (? (f > J 'nfonts) () (same f) f (loaded (f + 1)))
       f (loaded 1 @ g (g != () ? g (read-font-info J u nm ar s)))
       _ (set-equiv J u f)
       _ (set-eqtb J (font-id-base + f) (eq-type J u) (eq-level J u) f)
       (pin (J 'text) (font-id-base + f) t))
   (find-tfm J name area)
    (: file (name + ".tfm")
       (try ds) (? (ds = ()) () (readable? (<ds + file) ? (<ds + file) (try >ds)))
       (area != "" ? (readable? (area + file) ? (area + file) ()) (try (J 'tfm-dirs))))
   (read-font-info J u nm ar s)
    (: p (find-tfm J nm ar)
       bytes (p = () ? () (: q (open p "r") b (slurp q) (close q, b)))
       f (bytes = () ? 'badtfm (cb-font J nm ar bytes s))
       (? (f != 'badtfm)
           (: F (J 'fonts f)
              (pins F 'hyphenchar (int-par J default-hyphen-char-code)
                      'skewchar (int-par J default-skew-char-code) 'glue (), f))
          (: _ (print-err J "Font ") _ (sprint-cs J u) _ (print-char J 61)
             _ (print-file-name J nm ar "")
             _ (? (s >= 0) (print J " at ", print-scaled J s, print J "pt")
                  (s != -1000) (print J " scaled ", print-int J (0 - s)))
             _ (print J (bytes = () ? " not loadable: Metric (TFM) file not found"
                                       " not loadable: Bad metric (TFM) file"))
             _ (set-help J ["I wasn't able to read the size data for this font,"
                            "so I will ignore the font specification."
                            "[Wizards can fix TFM files using TFtoPL/PLtoTF.]"
                            "You might try inserting a different font spec;"
                            "e.g., type `I\\font<same font id>=<substitute font name>'."])
             (tex-error J, null-font))))

   ; --- \openin, \message, \uppercase, \show (tex.web 1275-1298) ----------------------------
   (open-or-close-in J)
    (: c (J 'cur-chr) _ (scan-four-bit-int J) n (J 'cur-val)
       _ (pin (J 'read-open) n closed)
       (c != 0 ?
          (: _ (scan-optional-equals J) _ (scan-file-name J)
             p (find-input J (pack-cur-name J))
             (p != () ? (pin (J 'read-file) n (read-whole p), pin (J 'read-open) n just-open)))))
   (issue-message J)
    (: c (J 'cur-chr)
       l (scan-toks J 0 1)
       s (in-new-string J (\ _ (token-show J l)))
       (? (c = 0)
           (: _ (? (J 'term-offset + #s > J 'max-print-line - 2) (print-ln J)
                   (J 'term-offset > 0 || J 'file-offset > 0) (print-char J 32))
              (slow-print J s, flush (J 'term-out)))
          (: _ (print-err J "") _ (slow-print J s)
             _ (? (equiv J err-help-loc != ()) (pin J 'use-err-help 1)
                  (J 'long-help-seen) (set-help J ["(That was another \\errmessage.)"])
                  (: _ (J 'interaction < error-stop-mode ? (pin J 'long-help-seen 1))
                     (set-help J ["This error message was generated by an \\errmessage"
                                  "command, so I can't give any explicit help."
                                  "Pretend that you're Hercule Poirot: Examine all clues,"
                                  "and deduce the truth by order and method."])))
             (tex-error J, pin J 'use-err-help 0))))
   (shift-case J)
    (: b (J 'cur-chr)
       l (scan-toks J 0 0)
       (change t)
        (? (t >= cs-token-flag + single-base) t
           (: c (t % 256) e (equiv J (b + c)) (e != 0 ? (t - c + e) t)))
       (back-list J (map change l)))
   (show-whatever J)
    (: c (J 'cur-chr)
       _ (? (c = show-code)
             (: _ (get-token J) _ (print-nl J "> ")
                _ (J 'cur-cs != 0 ? (sprint-cs J (J 'cur-cs), print-char J 61))
                (print-meaning J))
            (c = show-the-code)
             (: l (the-toks J) _ (print-nl J "> ") (token-show J l))
            (not-yet J "\\showbox and \\showlists"))
       _ (? (J 'interaction < error-stop-mode) (set-help J [], pin J 'error-count (J 'error-count - 1))
            (int-par J tracing-online-code > 0)
             (set-help J ["This isn't an error message; I'm just \\showing something."
                          "Type `I\\show...' to show more (e.g., \\show\\cs,"
                          "\\showthe\\count10, \\showbox255, \\showlists)."])
            (set-help J ["This isn't an error message; I'm just \\showing something."
                         "Type `I\\show...' to show more (e.g., \\show\\cs,"
                         "\\showthe\\count10, \\showbox255, \\showlists)."
                         "And type `I\\tracingonline=1\\show...' to show boxes and"
                         "lists on your terminal as well as in the transcript file."]))
       (tex-error J))

   ; --- main_control (tex.web 1029-1031, 1045) ------------------------------------------------
   (main-control J)
    (: _ (equiv J every-job-loc != () ? (begin-token-list J (equiv J every-job-loc) every-job-text))
       (big _) (get-x-token J, sw ())
       (sw _)
        (: _ (int-par J tracing-commands-code > 0 ? (show-cur-cmd-chr J))
           m (abs (mode J)) cmd (J 'cur-cmd)
           (is c) (cmd = c)
           (? (is relax || (cmd = spacer && m != hmode) || (cmd = no-boundary && m = mmode)) (big ())
              (is ignore-spaces)
               (: (go _) (get-x-token J, J 'cur-cmd = spacer ? (go ())) (go (), sw ()))
              (is stop && m = vmode) (its-all-over? J ? () (big ()))
              ((m = vmode && cmd = vmove) || (m != vmode && cmd = hmove) || is last-item
               || (m = vmode && (cmd = vadjust || cmd = ital-corr))
               || (m != mmode && cmd = eq-no) || is mac-param)
               (report-illegal-case J, big ())
              (m != mmode && math-only? cmd) (insert-dollar-sign J, big ())
              (m = mmode && (cmd = endv || cmd = par-end || cmd = stop || cmd = vskip || cmd = un-vbox
                             || cmd = valign || cmd = hrule))
               (insert-dollar-sign J, big ())
              (m = vmode && cmd = par-end) (normal-paragraph J, mode J > 0 ? (build-page J), big ())
              (m != mmode && cmd = left-brace) (new-save-level J simple-group, big ())
              (is begin-group) (new-save-level J semi-simple-group, big ())
              (is end-group)
               (J 'cur-group = semi-simple-group ? (unsave J) (off-save J), big ())
              (is right-brace) (handle-right-brace J, big ())
              (prefixed? cmd) (prefixed-command J, big ())
              (is after-assignment) (get-token J, pin J 'after-token (J 'cur-tok), big ())
              (is after-group) (get-token J, save-for-after J (J 'cur-tok), big ())
              (is in-stream) (open-or-close-in J, big ())
              (is message) (issue-message J, big ())
              (is case-shift) (shift-case J, big ())
              (is xray) (show-whatever J, big ())
              (is end-cs-name)
               (print-err J "Extra ", print-esc J "endcsname",
                set-help J ["I'm ignoring this, since I wasn't doing a \\csname."],
                tex-error J, big ())
              (not-yet J "typesetting")))
       (big ()))
   (normal-paragraph J)
    (int-par J looseness-code != 0 ? (eq-word-define J (int-base + looseness-code) 0),
     dimen-par J hang-indent-code != 0 ? (eq-word-define J (dimen-base + hang-indent-code) 0),
     int-par J hang-after-code != 1 ? (eq-word-define J (int-base + hang-after-code) 1),
     equiv J par-shape-loc != () ? (eq-define J par-shape-loc shape-ref ()))
   (build-page J) (J 'contrib-list != () && !(J 'output-active) ? (not-yet J "the page builder"))
   (math-only? c)
    (c = sup-mark || c = sub-mark || c = math-char-num || c = math-given || c = math-comp
     || c = delim-num || c = left-right || c = above || c = radical || c = math-style
     || c = math-choice || c = vcenter || c = non-script || c = mkern || c = limit-switch
     || c = mskip || c = math-accent)
   (prefixed? c)
    (c = toks-register || c = assign-toks || c = assign-int || c = assign-dimen || c = assign-glue
     || c = assign-mu-glue || c = assign-font-dimen || c = assign-font-int || c = set-aux
     || c = set-prev-graf || c = set-page-dimen || c = set-page-int || c = set-box-dimen
     || c = set-shape || c = def-code || c = def-family || c = set-font || c = def-font
     || c = register || c = advance || c = multiply || c = divide || c = prefix || c = let-cmd
     || c = shorthand-def || c = read-to-cs || c = def || c = set-box || c = hyph-data
     || c = set-interaction)

   ; --- the main program (tex.web 1330-1337) ------------------------------------------------
   (null-font-info _)
    {'tfm {'dsize 0 'size 0 'bc 1 'ec 0 'ci {} 'np 7 'param {1 0 2 0 3 0 4 0 5 0 6 0 7 0}
           'nl 0 'lig {} 'kern {} 'ext {} 'bchar 256 'fbchar 256}
     'name "nullfont" 'area "" 'used 0 'hyphenchar 45 'skewchar -1 'glue ()}
   ; a fresh job; O gives the first line and the run's settings
   (tex-job O)
    (: J (cb-job ())
       H {'type 'head 'link ()}
       _ (pin (J 'fonts) null-font (null-font-info ()))
       _ (pins J 'eq {} 'et {} 'el {} 'xl {} 'hash {} 'text {} 'hash-used hash-base 'cs-count 0
               'zero-glue (spec 0 0 normal 0 normal)
               'selector term-only 'term-offset 0 'file-offset 0 'tally 0 'trick-buf {}
               'trick-count 0 'first-count 0 'str-buf () 'old-setting 0
               'term-out (peep O 'out out) 'term-in (peep O 'in in) 'log-file () 'log-opened 0
               'log-name () 'job-name () 'interaction (peep O 'interaction error-stop-mode)
               'history fatal-error-stop 'error-count 0 'help () 'use-err-help 0
               'deletions-allowed 1 'set-box-allowed 1 'ok-to-interrupt 1 'long-help-seen 0
               'arith-error 0 'remainder 0
               'max-print-line (peep O 'max-print-line 79) 'error-line (peep O 'error-line 79)
               'half-error-line (peep O 'half-error-line 50)
               'banner "This is caja, Version 3.141592653" 'format-ident " (INITEX)"
               'sys-time (peep O 'time {'day 4 'month 7 'year 1776 'time 720})
               'tex-inputs (peep O 'tex-inputs ["./"]) 'tfm-dirs (peep O 'tfm-dirs ["./"])
               'cur {'state new-line 'index 0 'start 0 'loc 0 'limit -1 'name 0 'buf ""}
               'istack () 'input-ptr 0 'max-in-stack 0 'in-open 0 'line 0 'line-stack {}
               'input-file {} 'param-stack {} 'param-ptr 0 'max-param-stack 0 'open-parens 0
               'force-eof 0 'align-state 1000000 'scanner-status normal 'warning-index 0
               'def-ref () 'temp-list () 'hold-list () 'name-in-progress 0 'base-ptr 0
               'edit-name () 'long-state 0 'no-new-control-sequence 1
               'ss {} 'save-ptr 0 'max-save-stack 0 'cur-level level-one
               'cur-group bottom-level 'cur-boundary 0
               'cond-ptr () 'if-limit normal 'cur-if 0 'if-line 0 'skip-line 0
               'cur-mark {} 'read-open {} 'read-file {} 'write-file {} 'after-token 0
               'cur-list {'mode vmode 'head H 'tail H 'prev-depth ignore-depth 'space-factor 0
                          'pg 0 'ml 0 'clang 0}
               'nest () 'shown-mode 0 'page-contents empty 'page-contents-list () 'contrib-list ()
               'page-so-far {} 'last-glue () 'last-penalty 0 'last-kern 0 'dead-cycles 0
               'insert-penalties 0 'output-active 0 'mag-set 0
               'cur-cs 0 'cur-cmd 0 'cur-chr 0 'cur-tok 0 'cur-val 0 'cur-val-level int-val
               'radix 0 'cur-order 0 'cur-name "" 'cur-area "" 'cur-ext "" 'fd ()
               'up {})
       _ (init-eqtb J)
       _ (primitives J)
       _ (init-cmd-names J)
       _ (: t (J 'sys-time)
            (map (\ kv (pin (J 'eq) (int-base + kv 0) (t (kv 1))))
                 [[time-code 'time] [day-code 'day] [month-code 'month] [year-code 'year]]))
       J)
   ; the run: tex.web's main body from the first line on; answers the job when it is over
   (tex-run O)
    (: J (tex-job O)
       I (J 'cur)
       _ (pin I 'buf (peep O 'line ""))
       _ (trap (\ _ (start-job J)) () (\ a b (? (a = 'caja-end) () (scare a b))))
       _ (close-files-and-terminate J)
       J)
   (start-job J)
    (: I (J 'cur) l (I 'buf)
       _ (set-line J I l)
       _ (pin I 'loc (: (skip k) (k < #l && l k = 32 ? (skip (k + 1)) k) (skip 0)))
       _ (pin J 'selector (J 'interaction = batch-mode ? no-print term-only))
       _ (I 'loc < I 'limit && cat-code J (I 'buf (I 'loc)) != escape ? (start-input J))
       _ (pin J 'history spotless)
       _ (main-control J)
       (final-cleanup J))
   (final-cleanup J)
    (: c (J 'cur-chr)
       _ (J 'job-name = () ? (open-log-file J))
       (unwind _)
        (J 'input-ptr > 0 ?
           ((J 'cur 'state = token-list ? (end-token-list J) (end-file-reading J)), unwind ()))
       _ (unwind ())
       (parens _) (J 'open-parens > 0 ? (print J " )", pin J 'open-parens (J 'open-parens - 1), parens ()))
       _ (parens ())
       _ (J 'cur-level > level-one ?
            (print-nl J "(", print-esc J "end occurred ", print J "inside a group at level ",
             print-int J (J 'cur-level - level-one), print-char J 41))
       (conds _)
        (J 'cond-ptr != () ?
           (print-nl J "(", print-esc J "end occurred ", print J "when ",
            print-cmd-chr J if-test (J 'cur-if),
            J 'if-line != 0 ? (print J " on line ", print-int J (J 'if-line)),
            print J " was incomplete)", pop-cond J, conds ()))
       _ (conds ())
       _ (J 'history != spotless && (J 'history = warning-issued || J 'interaction < error-stop-mode)
          && J 'selector = term-and-log ?
            (pin J 'selector term-only,
             print-nl J "(see the transcript file for additional information)",
             pin J 'selector term-and-log))
       (c = 1 ? (not-yet J "\\dump")))
   (close-files-and-terminate J)
    (: _ (print-nl J "No pages of output.")
       (J 'log-opened ?
          (: _ (put (J 'log-file) 10) _ (close (J 'log-file))
             _ (pin J 'selector (J 'selector - 2))
             _ (J 'selector = term-only ?
                  (print-nl J "Transcript written on ", slow-print J (J 'log-name), print-char J 46))
             (print-ln J, flush (J 'term-out)))))
))
