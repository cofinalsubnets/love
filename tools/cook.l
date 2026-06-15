#!/usr/bin/env -S ai -l
; cook -- make, in love.
;
; love reads the `#!` hashbang line above as a line comment (ai.c: `#!` runs to
; end of line, like `;`), so loading this file as a library is unaffected -- the
; same line serves the OS as a shebang. with the file marked executable and a `cook`
; symlink to it on PATH (the user installs that), running `cook Cookfile [ticket]`
; execs `ai -l <this-file> Cookfile [ticket]`: the -l loads cook, then Cookfile runs.
;
; (this tool was first written as tools/bake.l; it was renamed to tools/cook.l so
; the file name does not collide with the OTHER, unrelated sense of "bake" in this
; tree -- baking the heap image / the egg (ai/egg.l), the array-perf bake. the
; build VERB here is `cook`; "bake" is reserved for the egg. the messages this tool
; prints are prefixed `cook:` for the same reason.)
;
; an item is brought up to date by first prepping its prerequisites up to date
; (depth first), then -- if the item is missing or OLDER than any prerequisite --
; running its recipe. that is the whole of make's idea; the rest is bookkeeping.
;
; a recipe is registered with (recipe item ingredients steps):
;   item -- a filename STRING (an artifact on disk) or a PHONY SYMBOL ('all,
;             'clean ..). a phony item owns no file, so it has no age and so
;             always runs, cascading a rebuild to everything that needs it.
;   ingredients -- a list of prerequisite items (strings and/or symbols).
;   steps  -- a list of STEPS. each step is either an argv list of strings, run as
;             a subprocess via the host `run` nif, or a THUNK (any lamp), called as
;             (step 0) for its effect. an empty step list is legal (a pure aggregate).
;
; file ages come from stat(1) -- love has no stat nif, but it has `run`, and that
; is enough. a missing file and a phony item both read as the ZERO POINT (nil):
; ageless, hence ancient, hence always rebuilt. the FIRST recipe declared is the
; default ticket, exactly as in make. drive it with (cook item) -- to cook an item
; is to prep it up to date by following its recipe over fresh ingredients.
;
; usage:  cook <Cookfile> [ticket]            (with the symlink installed)
;     or:  ai -l tools/cook.l <Cookfile> [ticket]
; A Cookfile is ordinary love source that lays out the recipes (recipe ..) then
; (cook (ticket 0)). cook can ALSO read a real Makefile directly: when the file it
; is handed is named like one (Makefile, makefile, GNUmakefile, *.mk), cook imports
; its rules and cooks them -- no Cookfile needed (see "importing a Makefile" at the
; foot of this file). The first rule is the default ticket either way.

(: cards (tablet 0)          ; the recipe cards: item -> (ingredients . steps)
   check (tablet 0)        ; a 1-cell box: the standing check -- the first item declared (the default when no ticket is named)

   ; string -> charlist, so a captured stat string can be read as a port.
   (s2cl s) ((: (g i) (? (< i (tally s)) (cons (peep s i 0) (g (+ 1 i))))) 0)

   ; "a b c" from ("a" "b" "c"); "" from the empty list.
   (join sep l) (? (twop l) (foldl (\ a x (+ a (+ sep x))) (cap l) (cup l)) "")

   ; register one recipe; returns the item. the first item ever declared is
   ; remembered as the default ticket.
   (recipe item ingredients steps)
   (: _ (pin cards item (cons ingredients steps))
       _ (? (peep check 0 0) 0 (pin check 0 item))
       item)

   ; the modification time of an item, in seconds, or () (the zero point) when it
   ; has none: a phony symbol, or a file that is not on disk. run gives back
   ; (status . output) once stat actually executed; status 0 means the file is
   ; there and `output` is its %.Y date (nanosecond resolution), which reads
   ; straight back as a number -- the sub-second part defeats same-second races.
   (date item)
   (? (symp item) ()
      (: r (run (L "sh" "-c" "stat -c %.Y \"$0\" 2>/dev/null" item))   ; %.Y: nanosecond float; stderr silenced (a miss is normal)
         (? (&& (twop r) (= 0 (cap r))) (read (sip (s2cl (cup r))) ()) ()))))

; --- prepping an item up to date ---------------------------------------------
; one cook call carries two books: `done` memoizes each item's settled age so a
; shared prerequisite is visited once, and `shipped` records the items whose recipe
; actually ran this pass, so a rebuilt (or phony) prerequisite forces its dependents
; even when the clock granularity would hide it.

(: (prep item done shipped)
   (? (peep done item ())                                   ; settled already
      (peep done item ())
      (: r (peep cards item ())
         (? r
            ; item has a recipe: prep every prerequisite up to date, then decide.
            (: ingredients (cap r) steps (cup r)
               _ (each ingredients (\ d (prep d done shipped)))
               ta0 (date item)
               fresh (any (\ d (peep shipped d 0)) ingredients)   ; a prerequisite just ran
               older (any (\ d (: da (peep done d ())     ; a prerequisite is newer
                                  (? (! da) 1 (? (! ta0) 1 (da > ta0))))) ingredients)
               stale (|| (! ta0) fresh older)
               ; run the recipe when stale; only a NON-EMPTY recipe counts as work
               ; done (a phony aggregate with no steps changes nothing, so it must
               ; neither claim to have shipped nor force its dependents).
               _ (? stale (: _ (recur item steps) (? (twop steps) (pin shipped item 1) 0)) 0)
               age (date item)
               _ (pin done item age)
               age)
            ; no recipe: a source leaf. it must already exist on disk.
            (: ta (date item)
               _ (? ta 0 (: _ (fputs err (+ "cook: no recipe to make " (show item)))
                            _ (fputc err 10) (exit 1)))
               _ (pin done item ta)
               ta))))

   ; run a recipe: each step in order.
   (recur item steps) (each steps (\ step (step1 step)))

   ; one step. a list is an argv (a subprocess); any other lamp is a thunk.
   (step1 step)
   (? (twop step) (shell step)
      (lamp step) (step 0)
      0)

   ; run one argv: echo it, run it, echo its captured stdout, abort on failure.
   (shell step)
   (: _ (puts (+ "  " (join " " step))) _ (putc 10)
       r (run step)
       (? (twop r)
          (: _ (puts (cup r))
             (? (= 0 (cap r)) 0
                (: _ (fputs err (+ "cook: command failed (exit " (+ (show (cap r)) ")")))
                   _ (fputc err 10) (exit 1))))
          (: _ (fputs err (+ "cook: cannot run " (join " " step)))
             _ (fputc err 10) (exit 1)))))

; --- the entry points ----------------------------------------------------------

(: (cook item)                                ; prep item up to date and report
   (? (! item) (: _ (fputs err "cook: nothing to cook") _ (fputc err 10) (exit 1))
      (: shipped (tablet 0)
         _ (prep item (tablet 0) shipped)
         ; $ of a map is its key count: how many items actually ran a recipe.
         (? (< 0 ($ shipped))
            (: _ (puts (+ "cook: cooked " (show item))) (putc 10))
            (: _ (puts (+ "cook: " (+ (show item) " is already up to date"))) (putc 10)))))

   ; the ticket to build: the last command-line word, when it names a recipe (as the
   ; bare string, for a file item, or interned, for a phony symbol), else the
   ; DEFAULT -- the first recipe declared. (argv still holds the WHOLE invocation here
   ; -- the Cards file and any -l pair included -- so a trailing word that is no item
   ; falls through to the default. the arg is ignored; (ticket 0) reads it all live.)
   (ticket _) (: a (last argv) d (peep check 0 ())
               (? (peep cards a 0) a
                  (: s (intern a) (? (peep cards s 0) s d)))))

; --- importing a Makefile ------------------------------------------------------
; cook reads a Cookfile (ordinary love source) -- but it can also read a real
; Makefile directly, the same dependency idea wearing make's notation. The reader
; is a set of PARSER COMBINATORS (after the gw.js style): a parser is (\ s y n)
; over a string s, with a success continuation y = rest parsed and a failure
; continuation n = rest; the parsed payload is a list that `seq` concatenates.
; love has no regex, so the leaves are `lit` (a literal prefix), `one` (one char
; by predicate) and `span` (a maximal run); alt/seq/opt/many build the rest.
; Makefile variable assignments, $(VAR) expansion, rules and .PHONY become cook
; cards; each recipe LINE is run via ("sh" "-c" line) so the shell handles pipes,
; globs and redirections (cook's `run` is execvp, not a shell). Pattern rules
; (%.o: %.c), `include` and the conditional directives have no cook equivalent and
; are passed over.
;
; The whole importer lives in ONE body-having `:`, so none of its many helper
; names leak to the global scope (a body-less `:` would, and several -- `parse`,
; `span`, `sat`/$ -- collide with egg globals). The form reads outer globals
; (recipe, cook, ticket, the prel) freely; its body is the dispatch at the bottom.
(:
   ; -- the combinators --
   eps (\ s y n (y s 0))
   (lit l) (\ s y n
      (? (&& (<= (tally l) (tally s)) (= l (slice s 0 (tally l))))
         (y (slice s (tally l) (tally s)) (L l)) (n s)))
   (one p) (\ s y n
      (? (&& (< 0 (tally s)) (p (s 0)))
         (y (slice s 1 (tally s)) (L (s 0))) (n s)))
   (span p) (\ s y n
      (: i ((: (g j) (? (&& (< j (tally s)) (p (s j))) (g (+ 1 j)) j)) 0)
         (y (slice s i (tally s)) (L (slice s 0 i)))))
   (alt a b) (\ s y n (a s y (\ _ (b s y n))))
   (seq a b) (\ s y n (a s (\ s1 p1 (b s1 (\ s2 p2 (y s2 (cat p1 p2))) n)) n))
   (seqs l) (foldr seq eps l)
   (opt a) (\ s y n (a s y (\ _ (y s 0))))
   (skip a) (\ s y n (a s (\ s1 _ (y s1 0)) n))
   (pmap f a) (\ s y n (a s (\ s1 x (y s1 (f x))) n))
   (many a) (\ s y n
      (a s (\ s1 p1 (many a s1 (\ s2 p2 (y s2 (cat p1 p2))) (\ _ (y s1 p1))))
           (\ _ (y s 0))))
   (parse p s) (p s (\ r x (? (= 0 (tally r)) x ())) (\ _ ()))

   ; -- character classes and string utilities --
   (chws c)     (|| (= c 32) (= c 9))
   (digitp c)   (&& (<= 48 c) (<= c 57))
   (alphap c)   (|| (&& (<= 65 c) (<= c 90)) (&& (<= 97 c) (<= c 122)))
   (namech c)   (|| (alphap c) (|| (digitp c) (|| (= c 95) (= c 46))))
   (notcolon c) (&& (! (chws c)) (! (= c 58)))
   (anyc c)     1
   (ltrim s) (: i ((: (g j) (? (&& (< j (tally s)) (chws (s j))) (g (+ 1 j)) j)) 0)
               (slice s i (tally s)))
   (rtrim s) (: i ((: (g j) (? (&& (< 0 j) (chws (s (- j 1)))) (g (- j 1)) j)) (tally s))
               (slice s 0 i))
   (trim s)  (rtrim (ltrim s))
   (findc s i ch) (? (>= i (tally s)) i (? (= (s i) ch) i (findc s (+ 1 i) ch)))
   (split-ws s)
   ((: (g i st acc)
       (? (>= i (tally s)) (rev (? (< st i) (cons (slice s st i) acc) acc))
          (? (chws (s i))
             (g (+ 1 i) (+ 1 i) (? (< st i) (cons (slice s st i) acc) acc))
             (g (+ 1 i) st acc))))
    0 0 0)

   ; -- a Makefile is read line by line; first fold \<newline> continuations --
   (uncont s)
   ((: (g i acc)
       (? (>= i (tally s)) acc
          (? (&& (= (s i) 92) (&& (< (+ 1 i) (tally s)) (= (s (+ 1 i)) 10)))
             (g (+ 2 i) (+ acc 32)) (g (+ 1 i) (+ acc (s i))))))
    0 "")
   (lines s)
   ((: (g i st acc)
       (? (>= i (tally s)) (rev (cons (slice s st i) acc))
          (? (= (s i) 10) (g (+ 1 i) (+ 1 i) (cons (slice s st i) acc))
             (g (+ 1 i) st acc))))
    0 0 0)

   ; -- the line grammar: an assignment op, an assignment, a rule header --
   opP (alt (lit "::=") (alt (lit ":=") (alt (lit "?=") (alt (lit "+=") (lit "=")))))
   assignP (seqs (L (skip (span chws)) (span namech)
                    (skip (span chws)) (skip opP)
                    (skip (span chws)) (span anyc)))
   ruleP (seqs (L (skip (span chws))
                  (pmap (\ x (L (split-ws (cap x)))) (span notcolon))
                  (skip (lit ":"))
                  (pmap (\ x (L (split-ws (cap x)))) (span anyc))))

   ; classify a line -> (recipe TEXT) | (assign NAME VAL) | (rule (T) (P)) | (skip)
   (recipep l)  (&& (< 0 (tally l)) (= (l 0) 9))
   (commentp l) (: t (trim l) (&& (< 0 (tally t)) (= (t 0) 35)))
   (recipe-body l)             ; drop the leading tab and any @ - + modifiers
   (: b (slice l 1 (tally l))
      ((: (g i) (? (&& (< i (tally b)) (|| (chws (b i)) (|| (= (b i) 64) (|| (= (b i) 45) (= (b i) 43)))))
                   (g (+ 1 i)) (slice b i (tally b)))) 0))
   (classify l)
   (? (recipep l) (L 'recipe (recipe-body l))
      (= 0 (tally (trim l))) (L 'skip)
      (commentp l) (L 'skip)
      (: a (parse assignP l) (? (twop a) (cons 'assign a)
         (: r (parse ruleP l) (? (twop r) (cons 'rule r) (L 'skip))))))

   ; fold classified lines into (rules . assigns). A rule under construction is
   ; (TGTS PREREQS . STEPS-rev); a recipe line pushes, a blank/assign closes it.
   (rkind c) (cap c) (r1 c) (cap (cup c)) (r2 c) (cap (cup (cup c)))
   (newrule tg pr) (cons tg (cons pr 0))
   (addstep cur st) (cons (cap cur) (cons (cap (cup cur)) (cons st (cup (cup cur)))))
   (finalize cur) (cons (cap cur) (cons (cap (cup cur)) (rev (cup (cup cur)))))
   (flushr cur rules) (? cur (cons (finalize cur) rules) rules)
   (build cls)
   ((: (loop cs rules cur as)
       (? (! (twop cs)) (L (rev (flushr cur rules)) as)
          (: c (cap cs) k (rkind c) rest (cup cs)
             (? (= k 'recipe) (loop rest rules (? cur (addstep cur (r1 c)) cur) as)
                (= k 'rule)   (loop rest (flushr cur rules) (newrule (r1 c) (r2 c)) as)
                (= k 'assign) (: _ (pin as (r1 c) (trim (r2 c))) (loop rest (flushr cur rules) 0 as))
                (loop rest (flushr cur rules) 0 as)))))
    cls 0 0 (tablet 0))

   ; expansion: $(VAR)/${VAR} from the table (recursive, depth-guarded); the
   ; automatic variables $@ $< $^ (and $$ -> $) inside a recipe line.
   (expand s as d)
   (? (> d 24) s
      ((: (g i acc)
          (? (>= i (tally s)) acc
             (? (&& (= (s i) 36) (&& (< (+ 1 i) (tally s))
                                     (|| (= (s (+ 1 i)) 40) (= (s (+ 1 i)) 123))))
                (: close (? (= (s (+ 1 i)) 40) 41 125)
                   j (findc s (+ 2 i) close)
                   nm (slice s (+ 2 i) j)
                   v (peep as nm "")
                   (g (+ 1 j) (+ acc (expand v as (+ 1 d)))))
                (g (+ 1 i) (+ acc (s i))))))
       0 ""))
   (expand-words ws as) (catmap (\ w (split-ws (expand w as 0))) ws)
   (auto-vars s t pr)
   ((: (g i acc)
       (? (>= i (tally s)) acc
          (: c (s i)
             (? (&& (= c 36) (< (+ 1 i) (tally s)))
                (: d (s (+ 1 i))
                   (? (= d 64) (g (+ 2 i) (+ acc t))
                      (= d 60) (g (+ 2 i) (+ acc (? (twop pr) (cap pr) "")))
                      (= d 94) (g (+ 2 i) (+ acc (join " " pr)))
                      (= d 36) (g (+ 2 i) (+ acc 36))
                      (g (+ 1 i) (+ acc c))))
                (g (+ 1 i) (+ acc c))))))
    0 "")

   ; parse a Makefile's text and REGISTER each rule as a cook card. A .PHONY
   ; member becomes a phony SYMBOL, every other item a file STRING (consistently
   ; for items and the prereqs that name them). Special dot-targets are dropped.
   ; The first rule registered is the default ticket, as in make.
   (register-makefile src)
   (: built (build (map classify (lines (uncont src))))
      rules (cap built)
      as (cap (cup built))
      phony (: ps (tablet 0)
               _ (each rules (\ r
                     (: tg (expand-words (cap r) as)
                        (? (any (\ t (= t ".PHONY")) tg)
                           (each (expand-words (cap (cup r)) as) (\ p (pin ps p 1))) 0))))
               ps)
      (mk-item nm) (? (peep phony nm 0) (intern nm) nm)
      keep? (\ r (! (any (\ t (&& (< 0 (tally t)) (= (t 0) 46))) (expand-words (cap r) as))))
      (each (filter keep? rules) (\ r
         (: tg (expand-words (cap r) as)
            pr (expand-words (cap (cup r)) as)
            raw (cup (cup r))
            deps (map mk-item pr)
            (each tg (\ t
               (recipe (mk-item t) deps
                       (map (\ st (L "sh" "-c" (auto-vars (expand st as 0) t pr))) raw))))))))

   ; is a recipe-file path named like a Makefile? then cook reads it as one.
   (mk-lastslash p) ((: (g j) (? (< 0 j) (? (= (p (- j 1)) 47) j (g (- j 1))) 0)) (tally p))
   (mk-base p) (slice p (mk-lastslash p) (tally p))
   (mk-ends p suf) (: ls (tally suf) lp (tally p) (&& (<= ls lp) (= suf (slice p (- lp ls) lp))))
   (makefilep p) (: b (mk-base p)
      (|| (= b "Makefile") (|| (= b "makefile") (|| (= b "GNUmakefile") (mk-ends p ".mk")))))

   ; the build file may be named explicitly (the first original-argv word that is
   ; not the program head or a -l pair) or DISCOVERED in the cwd. We cannot call
   ; cli.l's strip-l to find the explicit one -- it would re-load this file.
   (mk-args a) ((: (g x) (? (! (twop x)) 0
                  (? (= (cap x) "-l") (g (cup (cup x))) (cons (cap x) (g (cup x)))))) (cup a))
   (exists? p) (: q (open p "r") (? q 1 0))     ; a one-shot probe (the fd dies with the process)
   ; discovery precedence: a Makefile wins over a Cookfile, which wins over a
   ; legacy Cards.l (cook's old recipe-file name; read as a Cookfile, being love
   ; source). (a dummy param: a nullary (f) would be \ with one operand = quote.)
   (discover _) ((: (g ps) (? (twop ps) (? (exists? (cap ps)) (cap ps) (g (cup ps))) 0))
               '("Makefile" "Cookfile" "Cards.l"))

   ; -- the dispatch (this form's body) --
   ; cook is loaded with -l, then the host CLI driver loads the recipe file. We do
   ; the whole job HERE and exit first, so the driver never tries to read a Makefile
   ; (or re-read the chosen file) as love source. The build file is the explicit arg
   ; when it names an existing file, else the discovered one (Makefile, then Cookfile).
   ; A Makefile is imported and cooked; a Cookfile is read and evaluated -- it calls
   ; cook itself. The ticket is read live by (ticket 0) from argv, as ever.
   (: af (mk-args argv)
      file (? (&& (twop af) (exists? (cap af))) (cap af) (discover 0))
      (? file
         (: q (open file "r")
            _ (? (makefilep file)
                 (: _ (register-makefile (slurp q)) (cook (ticket 0)))
                 ((: (g e) (: r (read q e) (? (= e r) 0 (: _ (ev 'ev r) (g e))))) (mint 0)))
            (exit 0))
         (twop af)
         (: _ (fputs err "cook: no Makefile, Cookfile or Cards.l found") _ (fputc err 10) (exit 1))
         0)))
