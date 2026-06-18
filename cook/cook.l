#!/usr/bin/env -S ai -l
; cook -- ai make
;
; ai reads the `#!` hashbang line above as a line comment (ai.c: `#!` runs to
; end of line, like `;`), so loading this file as a library is unaffected -- the
; same line serves the OS as a shebang. with the file marked executable and a `cook`
; symlink to it on PATH (the user installs that), running `cook Cookfile [ticket]`
; execs `ai -l <this-file> Cookfile [ticket]`: the -l loads cook, then Cookfile runs.
;
; (this tool was first written as tools/bake.l; it was renamed to cook/cook.l so
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
;             a subprocess via the host `run` nif, or a THUNK (any lit?), called as
;             (step 0) for its effect. an empty step list is legal (a pure aggregate).
;
; file ages come from stat(1) -- ai has no stat nif, but it has `run`, and that
; is enough. a missing file and a phony item both read as the ZERO POINT (nil):
; ageless, hence ancient, hence always rebuilt. the FIRST recipe declared is the
; default ticket, exactly as in make. drive it with (cook item) -- to cook an item
; is to prep it up to date by following its recipe over fresh ingredients.
;
; usage:  cook [-f FILE] [--emit] [recipe ..]  (with the symlink installed)
;     or:  ai -l cook/cook.l [-f FILE] [recipe ..]
; A Cookfile is ordinary ai source that lays out the recipes (recipe ..) then
; drives them: (cook-all 0) builds every recipe named on the command line (or the
; default when none), and (cook (ticket 0)) builds just the first. cook can ALSO
; read a real Makefile directly: ONLY a file NAMED like one (Makefile, makefile,
; GNUmakefile, *.mk -- makefilep) is read as make; every other recipe file (Cards.l,
; Cookfile, or a -f FILE) is ai source. See "importing a Makefile" at the foot of
; this file. The first rule is the default ticket either way.

(: cards (tablet 0)          ; the recipe cards: item -> (ingredients orderonly . steps)
   check (tablet 0)        ; a 1-cell box: the standing check -- the first item declared (the default when no ticket is named)
   tickets (tablet 0)      ; a 1-cell box: the recipe words named on the command line (the non-flag args), () until the dispatch parses them
   pgen (tablet 0)         ; a 1-cell box: a pattern-rule resolver (item -> a card | 0), installed by the Makefile importer (() until then)

   ; string -> charlist, so a captured stat string can be read as a port.
   (s2cl s) ((: (g i) (? (< i (tally s)) (link (peep s i 0) (g (+ 1 i))))) 0)

   ; "a b c" from ("a" "b" "c"); "" from the empty list.
   (join sep l) (? (two? l) (foldl (\ a x (+ a (+ sep x))) (cap l) (cup l)) "")

   ; register one card, MERGING with any prior card for the same item: ingredients
   ; and order-only prereqs accumulate, and a later NON-EMPTY recipe wins (as make
   ; does -- e.g. an explicit "prereqs only" rule that adds a dependency to a target
   ; whose recipe comes from a pattern rule). The first item ever registered is the
   ; default ticket. card = (ingredients orderonly . steps); orderonly prereqs are
   ; built-if-missing but never make a target stale (make's `| prereqs`).
   (reg item ing oo steps)
   (: prev (peep cards item ())
      (? prev
         (pin cards item (link (cat (cap prev) ing)
                               (link (cat (cap (cup prev)) oo)
                                     (? (two? steps) steps (cup (cup prev))))))
         (: _ (pin cards item (link ing (link oo steps)))
             _ (? (peep check 0 0) 0 (pin check 0 item)) item)))
   ; the public Cookfile API: (recipe item ingredients steps) -- no order-only prereqs.
   (recipe item ingredients steps) (reg item ingredients 0 steps)

   ; the modification time of an item, in seconds, or () (the zero point) when it
   ; has none: a phony symbol, or a file that is not on disk. run gives back
   ; (status . output) once stat actually executed; status 0 means the file is
   ; there and `output` is its %.Y date (nanosecond resolution), which reads
   ; straight back as a number -- the sub-second part defeats same-second races.
   (date item)
   (? (nom? item) ()
      (: r (run (L "sh" "-c" "stat -c %.Y \"$0\" 2>/dev/null" item))   ; %.Y: nanosecond float; stderr silenced (a miss is normal)
         (? (&& (two? r) (= 0 (cap r))) (read (tap (s2cl (cup r))) ()) ()))))

; --- prepping an item up to date ---------------------------------------------
; one cook call carries two books: `done` memoizes each item's settled age so a
; shared prerequisite is visited once, and `shipped` records the items whose recipe
; actually CHANGED the file this pass (its mtime advanced), so a rebuilt prerequisite
; forces its dependents even when the clock granularity would hide it -- but a recipe
; that re-runs without touching its output (the ai_version.h cmp idiom) does NOT
; cascade, matching make's mtime-only decision.

(: (prep item done shipped)
   (? (peep done item ())                                   ; settled already
      (peep done item ())
      ; the card: an explicit recipe wins outright; otherwise a pattern rule may
      ; synthesize one (merging any explicit "prereqs only" card), else the explicit
      ; prereq-only card, else nothing (a source leaf).
      ; presence is tested with `two?` (a card is a chain), never net-truthiness:
      ; a card of all-empty parts -- (() ()) -- nets 0 (blue), so (? card ..) would
      ; wrongly read it absent. A phony aggregate with no prereqs is exactly that.
      (: exr (peep cards item 'none)
         ex (? (two? exr) exr 0)
         f (peep pgen 0 ())
         r (? (&& ex (two? (cup (cup ex)))) ex
              (: g (? f (f item) 0) (? (two? g) g ex)))
         (? (two? r)
            ; item has a card: prep every prerequisite up to date, then decide.
            (: ingredients (cap r) orderonly (cap (cup r)) steps (cup (cup r))
               _ (each ingredients (\ d (prep d done shipped)))
               _ (each orderonly (\ d (prep d done shipped)))  ; order-only: built if missing, never makes us stale
               ta0 (date item)
               fresh (any (\ d (peep shipped d 0)) ingredients)   ; a prerequisite's file changed
               older (any (\ d (: da (peep done d ())     ; a prerequisite is newer
                                  (? (! da) 1 (? (! ta0) 1 (da > ta0))))) ingredients)
               stale (|| (! ta0) (|| fresh older))
               ; run the recipe when stale; mark shipped only if the recipe actually
               ; advanced the file's mtime (created it, or rewrote it newer) -- a
               ; no-op rebuild must not force dependents.
               _ (? stale (: _ (recur item steps)
                             nw (date item)
                             (? (&& (two? steps) (? (! ta0) (? nw 1 0) (? nw (nw > ta0) 0)))
                                (pin shipped item 1) 0)) 0)
               age (date item)
               _ (pin done item age)
               age)
            ; no card: a source leaf. it must already exist on disk.
            (: ta (date item)
               _ (? ta 0 (: _ (say err (+ "cook: no recipe to make " (show item)))
                            _ (put err 10) (exit 1)))
               _ (pin done item ta)
               ta))))

   ; run a recipe: each step in order.
   (recur item steps) (each steps (\ step (step1 step)))

   ; one step. a list HEADED BY THE SYMBOL `exec` -- (exec PROG ARGS..) -- is an
   ; INTERACTIVE step: it runs via the `exec` nif, which REPLACES cook and inherits
   ; the terminal, so the child (the repl, gdb, qemu) drives the real tty rather than
   ; having its stdout captured by `run`. A plain list of strings is an argv
   ; subprocess (captured); any other lit? is a thunk.
   (step1 step)
   (? (&& (two? step) (= (cap step) 'exec)) (do-exec (cup step))   ; (exec ..) -- the interactive step
      (two? step) (shell step)
      (lit? step) (step 0)
      0)

   ; an interactive step: exec the argv, replacing this process (tty inherited).
   ; the exec nif returns only on FAILURE -- then an errno fixnum -- so anything
   ; past it is the error path. exec is terminal by nature (the repl never returns),
   ; so cook's "cooked X" summary is correctly never reached.
   (do-exec argv)
   (: _ (flush out)
       _ (exec argv)
       _ (say err (+ "cook: cannot exec " (join " " argv))) _ (put err 10) (exit 1))

   ; run one argv: echo it, run it, echo its captured stdout, abort on failure.
   (shell step)
   (: _ (puts (+ "  " (join " " step))) _ (putc 10)
       r (run step)
       (? (two? r)
          (: _ (puts (cup r))
             (? (= 0 (cap r)) 0
                (: _ (say err (+ "cook: command failed (exit " (+ (show (cap r)) ")")))
                   _ (put err 10) (exit 1))))
          (: _ (say err (+ "cook: cannot run " (join " " step)))
             _ (put err 10) (exit 1))))

   ; run one make recipe line (via sh -c), make-style: echo the RAW command
   ; (the expanded line, not the `sh -c` wrapper) unless @ silent, print its
   ; captured stdout, and on a nonzero exit either carry on (- ignore, with a
   ; note to err) or abort. The Makefile path's analogue of `shell`.
   (sh-line silent ignore cmd)
   (: _ (? silent 0 (: _ (puts cmd) (putc 10)))
       r (run (L "sh" "-c" cmd))
       ec (? (two? r) (cap r) -1)
       _ (? (two? r) (puts (cup r)) 0)
       (? (= 0 ec) 0
          (! (two? r)) (: _ (say err (+ "cook: cannot run " cmd)) _ (put err 10) (exit 1))
          ignore (: _ (say err (+ "cook: " (+ cmd (+ " (exit " (+ (show ec) ", ignored)"))))) (put err 10))
          (: _ (say err (+ "cook: command failed (exit " (+ (show ec) ")"))) _ (put err 10) (exit 1)))))

; --- the entry points ----------------------------------------------------------

(: (cook item)                                ; prep item up to date and report
   (? (! item) (: _ (say err "cook: nothing to cook") _ (put err 10) (exit 1))
      (: shipped (tablet 0)
         _ (prep item (tablet 0) shipped)
         ; $ of a map is its key count: how many items actually ran a recipe.
         (? (< 0 ($ shipped))
            (: _ (puts (+ "cook: cooked " (show item))) (putc 10))
            (: _ (puts (+ "cook: " (+ (show item) " is already up to date"))) (putc 10)))))

   ; resolve a command-line word to an item: the bare string when it names a file
   ; recipe, the interned symbol when it names a phony one, else the DEFAULT -- the
   ; first recipe declared. an unknown word thus quietly cooks the default, as make's
   ; trailing target does when nothing matches.
   (pick a) (? (peep cards a 0) a
              (: s (intern a) (? (peep cards s 0) s (peep check 0 ()))))

   ; the ticket to build: the FIRST recipe word named on the command line (the
   ; `tickets` box, filled by the dispatch from the non-flag args), else the default.
   ; (ticket 0) reads it live, so a Cookfile's own (cook (ticket 0)) sees the args.
   (ticket _) (: ts (peep tickets 0 ()) (? (two? ts) (pick (cap ts)) (peep check 0 ())))

   ; cook every recipe word named on the command line (make foo bar), or the default
   ; when none were named. drives the Makefile path; a Cookfile drives itself.
   (cook-all _) (: ts (peep tickets 0 ())
                (? (two? ts) (each ts (\ w (cook (pick w)))) (cook (peep check 0 ())))))

; --- importing a Makefile ------------------------------------------------------
; cook reads a Cookfile (ordinary love source) -- but it can also read a real
; Makefile directly, the same dependency idea wearing make's notation. The reader
; is a set of PARSER COMBINATORS (after the gw.js style): a parser is (\ s y n)
; over a string s, with a success continuation y = rest parsed and a failure
; continuation n = rest; the parsed payload is a list that `seq` concatenates.
; love has no regex, so the leaves are `lit` (a literal prefix), `one` (one char
; by predicate) and `span` (a maximal run); alt/seq/opt/many build the rest.
; The import is reasonably GNU-make-compatible: recursive $(VAR) expansion and
; substitution refs, the common functions ($(shell)/$(wildcard)/$(dir)/
; $(patsubst)/$(filter)/...), ifeq/ifdef conditionals, `include`, the = := ?= +=
; flavors, pattern + static-pattern rules, order-only prereqs, and the $@ $< $^ $*
; automatics. Each recipe LINE runs via ("sh" "-c" line). See cook/cooktest.l.
;
; The whole importer lives in ONE body-having `:`, so none of its many helper
; names leak to the global scope (a body-less `:` would, and several -- `parse`,
; `span`, `sat`/$ -- collide with egg globals). The form reads outer globals
; (recipe, cook, ticket, the prel) freely; its body is the dispatch at the bottom.
(:
   ; --emit mode: a 1-cell box (0 = off). when set, expand-steps emits a
   ; serializable ("sh" "-c" cmd) argv step instead of a sh-line thunk, so the
   ; resolved cards can be SHOWN back as a Cookfile (see emit-cookfile below).
   emitp (tablet 0)

   ; -- the combinators --
   eps (\ s y n (y s 0))
   (lit l) (\ s y n
      (? (&& (<= (tally l) (tally s)) (= l (snip s 0 (tally l))))
         (y (snip s (tally l) (tally s)) (L l)) (n s)))
   (one p) (\ s y n
      (? (&& (< 0 (tally s)) (p (s 0)))
         (y (snip s 1 (tally s)) (L (s 0))) (n s)))
   (span p) (\ s y n
      (: i ((: (g j) (? (&& (< j (tally s)) (p (s j))) (g (+ 1 j)) j)) 0)
         (y (snip s i (tally s)) (L (snip s 0 i)))))
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
               (snip s i (tally s)))
   (rtrim s) (: i ((: (g j) (? (&& (< 0 j) (chws (s (- j 1)))) (g (- j 1)) j)) (tally s))
               (snip s 0 i))
   (trim s)  (rtrim (ltrim s))
   (findc s i ch) (? (>= i (tally s)) i (? (= (s i) ch) i (findc s (+ 1 i) ch)))
   (split-ws s)
   ((: (g i st acc)
       (? (>= i (tally s)) (rev (? (< st i) (link (snip s st i) acc) acc))
          (? (chws (s i))
             (g (+ 1 i) (+ 1 i) (? (< st i) (link (snip s st i) acc) acc))
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
       (? (>= i (tally s)) (rev (link (snip s st i) acc))
          (? (= (s i) 10) (g (+ 1 i) (+ 1 i) (link (snip s st i) acc))
             (g (+ 1 i) st acc))))
    0 0 0)

   ; -- string utilities for the make layer --
   (findc-ws s i) (? (>= i (tally s)) i (? (chws (s i)) i (findc-ws s (+ 1 i))))
   (first-word s) (snip s 0 (findc-ws s 0))
   (after-word s) (ltrim (snip s (findc-ws s 0) (tally s)))
   (nth l i d) (? (two? l) (? (= 0 i) (cap l) (nth (cup l) (- i 1) d)) d)
   (lastl l) (? (two? (cup l)) (lastl (cup l)) (cap l))
   ; an empty snip (start>=end) yields the zero point 0, not "" -- and (+ 0 str)
   ; prepends a NUL byte (the byte law). `sub` is the empty-safe snip: "" for empty.
   (sub s a b) (? (< a b) (snip s a b) "")
   ; strip a make comment (an unescaped #) from a NON-recipe line; \# is a literal #.
   (strip-comment l)
   ((: (g i acc)
       (? (>= i (tally l)) acc
          (: c (l i)
             (? (= c 35) acc                                  ; 35 = #
                (= c 92) (? (< (+ 1 i) (tally l))             ; 92 = backslash
                            (: d (l (+ 1 i)) (? (= d 35) (g (+ 2 i) (+ acc 35)) (g (+ 2 i) (+ (+ acc 92) d))))
                            (+ acc 92))
                (g (+ 1 i) (+ acc c))))))
    0 "")
   ; split a string on a top-level char `ch` -- parens/braces are balanced, so a
   ; delimiter inside $(..) / ${..} does not split (used for function args and the
   ; static-pattern colon).
   (splittop s ch)
   ((: (g i depth st acc)
       (? (>= i (tally s)) (rev (link (snip s st i) acc))
          (: c (s i)
             (? (|| (= c 40) (= c 123)) (g (+ 1 i) (+ 1 depth) st acc)
                (|| (= c 41) (= c 125)) (g (+ 1 i) (- depth 1) st acc)
                (&& (= c ch) (= depth 0)) (g (+ 1 i) depth (+ 1 i) (link (snip s st i) acc))
                (g (+ 1 i) depth st acc)))))
    0 0 0 0)

   ; -- the line grammar: NAME OP VALUE (op kept) and a rule header (raw text) --
   opP (alt (lit "::=") (alt (lit ":=") (alt (lit "?=") (alt (lit "+=") (lit "=")))))
   assignP (seqs (L (skip (span chws)) (span namech)
                    (skip (span chws)) (pmap (\ x (L (cap x))) opP)
                    (skip (span chws)) (span anyc)))
   ruleP (seqs (L (skip (span chws)) (span notcolon) (skip (lit ":")) (span anyc)))

   ; classify a line -> (recipe TEXT) | (assign NAME OP VAL) | (rule TGTS PREREQS)
   ; | (inc TEXT) | (ifeq|ifneq|ifdef|ifndef|else REST) | (endif) | (skip).
   (recipep l)  (&& (< 0 (tally l)) (= (l 0) 9))
   ; parse a recipe body: strip a leading run of @ - + line modifiers (and any
   ; interspersed whitespace), RECORDING whether @ (silent) and - (ignore-error)
   ; appeared. -> (silent ignore . body). + (force) is a no-op here -- cook has no
   ; dry-run mode -- so it is stripped without a flag. (64 = @, 45 = -, 43 = +.)
   (parse-mods s)
   ((: (g i sil ign)
       (? (&& (< i (tally s)) (|| (chws (s i)) (|| (= (s i) 64) (|| (= (s i) 45) (= (s i) 43)))))
          (g (+ 1 i) (|| sil (= (s i) 64)) (|| ign (= (s i) 45)))
          (link sil (link ign (snip s i (tally s)))))) 0 0 0)
   (recipe-parse l) (parse-mods (snip l 1 (tally l)))   ; drop the leading tab, then the modifier run
   (classify l)
   (? (recipep l) (L 'recipe (recipe-parse l))
      (: t (strip-comment l) tt (trim t)
         (? (= 0 (tally tt)) (L 'skip)
            (: w (first-word tt) rest (after-word tt)
               (? (= w "include") (L 'inc rest)
                  (= w "-include") (L 'inc rest)
                  (= w "sinclude") (L 'inc rest)
                  (= w "ifeq") (L 'ifeq rest)
                  (= w "ifneq") (L 'ifneq rest)
                  (= w "ifdef") (L 'ifdef rest)
                  (= w "ifndef") (L 'ifndef rest)
                  (= w "else") (L 'else rest)
                  (= w "endif") (L 'endif)
                  (: a (parse assignP t) (? (two? a) (link 'assign a)
                     (: r (parse ruleP t) (? (two? r) (link 'rule r) (L 'skip))))))))))

   ; -- nested-paren-aware variable expansion + make functions --
   ; the index of the ) that matches the ( just opened, counting nested $(..).
   (findclose s i open close)
   ((: (g j depth)
       (? (>= j (tally s)) j
          (: c (s j)
             (? (= c open) (g (+ 1 j) (+ 1 depth))
                (= c close) (? (= 0 depth) j (g (+ 1 j) (- depth 1)))
                (g (+ 1 j) depth)))))
    i 0)

   ; GNU make substitution on one word of $(VAR:from=to). With a % in `from` it is
   ; a pattern (prefix%suffix) whose stem fills the % in `to`; without a % it is a
   ; trailing-text replacement (the .o=.c shorthand). Non-match passes through.
   (patsub frm to w)
   (: pi (findc frm 0 37)                                    ; 37 = %
      (? (< pi (tally frm))
         (: pre (sub frm 0 pi) suf (sub frm (+ 1 pi) (tally frm))
            lp (tally pre) ls (tally suf) lw (tally w)
            (? (&& (>= lw (+ lp ls)) (&& (= pre (sub w 0 lp)) (= suf (sub w (- lw ls) lw))))
               (: stem (sub w lp (- lw ls)) ti (findc to 0 37)
                  (? (< ti (tally to)) (+ (sub to 0 ti) (+ stem (sub to (+ 1 ti) (tally to)))) to))
               w))
         (: lf (tally frm) lw (tally w)
            (? (&& (>= lw lf) (= frm (sub w (- lw lf) lw))) (+ (sub w 0 (- lw lf)) to) w))))

   ; substitute the stem into a pattern prereq (./%.c -> ./<stem>.c); no %, no change.
   (stemsub p stem) (: pi (findc p 0 37)
                       (? (< pi (tally p)) (+ (sub p 0 pi) (+ stem (sub p (+ 1 pi) (tally p)))) p))
   ; match a pattern (one %) against a string -> (stem) | () ; no % -> exact match.
   (pmatch pat s)
   (: pi (findc pat 0 37)
      (? (>= pi (tally pat)) (? (= pat s) (L "") ())
         (: pre (snip pat 0 pi) suf (snip pat (+ 1 pi) (tally pat))
            lp (tally pre) ls (tally suf) ls2 (tally s)
            (? (&& (>= ls2 (+ lp ls)) (&& (= pre (snip s 0 lp)) (= suf (snip s (- ls2 ls) ls2))))
               (L (snip s lp (- ls2 ls))) ()))))
   (haspct t) (< (findc t 0 37) (tally t))
   (matchany pats w) (any (\ p (two? (pmatch p w))) pats)

   (subst-ref eb as d)         ; VAR:from=to (already inner-expanded)
   (: ci (findc eb 0 58) nm (sub eb 0 ci)                    ; 58 = :
      spec (sub eb (+ 1 ci) (tally eb))
      ei (findc spec 0 61) frm (sub spec 0 ei)               ; 61 = =
      to (sub spec (+ 1 ei) (tally spec))
      v (expand (peep as nm "") as (+ 1 d))
      (join " " (map (\ w (patsub frm to w)) (split-ws v))))

   ; -- function helpers --
   (chomp s) ((: (g i) (? (&& (< 0 i) (= (s (- i 1)) 10)) (g (- i 1)) (snip s 0 i))) (tally s))
   (nl->sp s) ((: (g i acc) (? (>= i (tally s)) acc (g (+ 1 i) (+ acc (? (= (s i) 10) 32 (s i)))))) 0 "")
   (fn-shell cmd) (: r (run (L "sh" "-c" cmd)) (? (two? r) (nl->sp (chomp (cup r))) ""))
   ; $(wildcard): shell out so glob + no-match (nullglob via [ -e ]) are POSIX.
   (globsh pat) (: r (run (L "sh" "-c" "set +f; for f in $0; do [ -e \"$f\" ] && printf '%s ' \"$f\"; done" pat))
                   (? (two? r) (split-ws (cup r)) 0))
   (fdir w) (: k (mk-lastslash w) (? (< 0 k) (sub w 0 k) "./"))
   (fnotdir w) (sub w (mk-lastslash w) (tally w))
   (flastdot w) (: sl (mk-lastslash w)
                   ((: (g j) (? (> j sl) (? (= (w (- j 1)) 46) (- j 1) (g (- j 1))) (tally w))) (tally w)))
   (fbase w) (: dot (flastdot w) (? (< dot (tally w)) (sub w 0 dot) w))
   (fsuf w)  (: dot (flastdot w) (? (< dot (tally w)) (sub w dot (tally w)) ""))
   (fabs w) (? (&& (< 0 (tally w)) (= (w 0) 47)) w
              (: r (run (L "sh" "-c" "pwd")) (? (two? r) (+ (chomp (cup r)) (+ "/" w)) w)))
   (dedup l) (? (two? l) (? (two? (cup l)) (? (= (cap l) (cap (cup l))) (dedup (cup l)) (link (cap l) (dedup (cup l)))) l) l)
   (sortu l) (dedup (sort l))
   (strrep frm to s)
   (? (= 0 (tally frm)) s
      ((: (g i acc)
          (? (> (+ i (tally frm)) (tally s)) (+ acc (sub s i (tally s)))
             (? (= frm (sub s i (+ i (tally frm)))) (g (+ i (tally frm)) (+ acc to))
                (g (+ 1 i) (+ acc (s i))))))
       0 ""))
   (fn-or args as d)  ((: (g l) (? (two? l) (: v (expand (cap l) as (+ 1 d)) (? (< 0 (tally (trim v))) v (g (cup l)))) "")) args)
   (fn-and args as d) ((: (g l last) (? (two? l) (: v (expand (cap l) as (+ 1 d)) (? (< 0 (tally (trim v))) (g (cup l) v) "")) last)) args "")
   funcnames '("shell" "wildcard" "dir" "notdir" "basename" "suffix" "patsubst"
               "subst" "filter" "filter-out" "sort" "strip" "if" "or" "and"
               "addprefix" "addsuffix" "firstword" "lastword" "word" "words"
               "abspath" "realpath" "call")
   (funcp nm) (any (\ f (= f nm)) funcnames)
   (findws s) ((: (g i) (? (>= i (tally s)) i (? (chws (s i)) i (g (+ 1 i))))) 0)
   (apply-func nm at as d)
   (: ex1 (\ x (expand x as (+ 1 d)))
      argl (\ _ (map ex1 (splittop at 44)))     ; comma-split + expand (most funcs); 44 = ,
      rawl (\ _ (splittop at 44))               ; comma-split, NOT expanded (if/or/and)
      (? (= nm "shell")     (fn-shell (ex1 at))
         (= nm "wildcard")  (join " " (catmap globsh (split-ws (ex1 at))))
         (= nm "dir")       (join " " (map fdir (split-ws (ex1 at))))
         (= nm "notdir")    (join " " (map fnotdir (split-ws (ex1 at))))
         (= nm "basename")  (join " " (map fbase (split-ws (ex1 at))))
         (= nm "suffix")    (join " " (map fsuf (split-ws (ex1 at))))
         (= nm "strip")     (join " " (split-ws (ex1 at)))
         (= nm "sort")      (join " " (sortu (split-ws (ex1 at))))
         (= nm "patsubst")  (: a (argl 0) (join " " (map (\ w (patsub (nth a 0 "") (nth a 1 "") w)) (split-ws (nth a 2 "")))))
         (= nm "subst")     (: a (argl 0) (strrep (nth a 0 "") (nth a 1 "") (nth a 2 "")))
         (= nm "filter")    (: a (argl 0) (join " " (filter (\ w (matchany (split-ws (nth a 0 "")) w)) (split-ws (nth a 1 "")))))
         (= nm "filter-out")(: a (argl 0) (join " " (filter (\ w (! (matchany (split-ws (nth a 0 "")) w))) (split-ws (nth a 1 "")))))
         (= nm "addprefix") (: a (argl 0) (join " " (map (\ w (+ (nth a 0 "") w)) (split-ws (nth a 1 "")))))
         (= nm "addsuffix") (: a (argl 0) (join " " (map (\ w (+ w (nth a 0 ""))) (split-ws (nth a 1 "")))))
         (= nm "firstword") (: ws (split-ws (ex1 at)) (? (two? ws) (cap ws) ""))
         (= nm "lastword")  (: ws (split-ws (ex1 at)) (? (two? ws) (lastl ws) ""))
         (= nm "word")      (: a (argl 0) ws (split-ws (nth a 1 "")) n (read (tap (s2cl (trim (nth a 0 "")))) 0) (nth ws (- n 1) ""))
         (= nm "words")     (show (tally (split-ws (ex1 at))))
         (= nm "if")        (: a (rawl 0) c (trim (ex1 (nth a 0 ""))) (? (< 0 (tally c)) (ex1 (nth a 1 "")) (ex1 (nth a 2 ""))))
         (= nm "or")        (fn-or (rawl 0) as d)
         (= nm "and")       (fn-and (rawl 0) as d)
         (|| (= nm "abspath") (= nm "realpath")) (join " " (map fabs (split-ws (ex1 at))))
         ""))                                   ; call / unknown -> empty

   ; a group body is a function call ($(name args)), a substitution reference
   ; ($(VAR:from=to)), or a plain variable ($(VAR)).
   (eval-group body as d)
   (: sp (findws body)
      (? (&& (< sp (tally body)) (funcp (snip body 0 sp)))
         (apply-func (snip body 0 sp) (ltrim (snip body (+ 1 sp) (tally body))) as d)
         (: eb (expand body as (+ 1 d)) ci (findc eb 0 58)
            (? (< ci (tally eb)) (subst-ref eb as d) (expand (peep as eb "") as (+ 1 d))))))

   ; expansion: $(..) / ${..} groups (functions / subst refs / vars), the single-char
   ; $V form (including the automatic vars $@ $< $^ $*, which live in the table during
   ; recipe expansion), and $$ -> $.
   (expand s as d)
   (? (> d 100) s
      ((: (g i acc)
          (? (>= i (tally s)) acc
             (? (&& (= (s i) 36) (< (+ 1 i) (tally s)))
                (: nx (s (+ 1 i))
                   (? (|| (= nx 40) (= nx 123))
                      (: close (? (= nx 40) 41 125) j (findclose s (+ 2 i) nx close)
                         (g (+ 1 j) (+ acc (eval-group (snip s (+ 2 i) j) as d))))
                      (= nx 36) (g (+ 2 i) (+ acc 36))
                      (|| (namech nx) (|| (= nx 64) (|| (= nx 60) (|| (= nx 94) (= nx 42)))))
                      (g (+ 2 i) (+ acc (expand (peep as (snip s (+ 1 i) (+ 2 i)) "") as (+ 1 d))))
                      (g (+ 1 i) (+ acc (s i)))))
                (g (+ 1 i) (+ acc (s i))))))
       0 ""))
   (expand-words ws as) (catmap (\ w (split-ws (expand w as 0))) ws)
   ; a recipe LINE that begins with the shell `exec` builtin is an INTERACTIVE
   ; line: `exec <cmd>` replaces the shell, so make already runs it on the real
   ; tty -- and cook honours the same convention, running it through the exec nif
   ; (the `(exec ..)` step) rather than capturing it via `run`. So one notation --
   ; `exec` -- marks the repl / gdb / qemu targets interactive in BOTH builders.
   (starts? s pre) (&& (<= (tally pre) (tally s)) (= pre (snip s 0 (tally pre))))
   (execp cmd) (: t (ltrim cmd)
                  (&& (starts? t "exec") (|| (= 4 (tally t)) (chws (t 4)))))
   ; build a recipe's argv steps, pinning the automatic vars into the table first.
   ; build a card's steps. each raw is (silent ignore . body) from recipe-parse;
   ; expand the body NOW (the $@/$</$^/$* automatics are live in `as` at this
   ; point, and get re-pinned per item) and close over the expanded command in a
   ; thunk that runs it make-style via sh-line, carrying the @/- flags. An
   ; exec-prefixed line instead becomes an (exec "sh" "-c" cmd) interactive step
   ; (serialized as such under --emit, run via the exec nif otherwise).
   (expand-steps raws t pr stem as)
   (: _ (pin as "@" t) _ (pin as "<" (? (two? pr) (cap pr) ""))
       _ (pin as "^" (join " " pr)) _ (pin as "*" stem)
       (map (\ raw (: cmd (expand (cup (cup raw)) as 0)
                       (? (execp cmd)
                          (? (peep emitp 0 0) (link 'exec (L "sh" "-c" cmd))
                             (\ _ (do-exec (L "sh" "-c" cmd))))
                          (peep emitp 0 0) (L "sh" "-c" cmd)
                          (\ _ (sh-line (cap raw) (cap (cup raw)) cmd))))) raws))

   ; -- conditionals & assignment ops over the variable table `as` --
   (unquote-str s) (? (&& (>= (tally s) 2) (|| (= (s 0) 34) (= (s 0) 39))) (snip s 1 (- (tally s) 1)) s)
   (cond-args rest)            ; ifeq/ifneq REST -> (arg1 . arg2)
   (: t (trim rest)
      (? (&& (< 0 (tally t)) (= (t 0) 40))
         (: cl (findclose t 1 40 41) parts (splittop (snip t 1 cl) 44)
            (link (? (two? parts) (cap parts) "") (? (two? (cup parts)) (cap (cup parts)) "")))
         (: ws (map unquote-str (split-ws t))
            (link (? (two? ws) (cap ws) "") (? (two? (cup ws)) (cap (cup ws)) "")))))
   (eval-ifeq rest as) (: a (cond-args rest) (= (trim (expand (cap a) as 0)) (trim (expand (cup a) as 0))))
   (eval-ifdef rest as) (< 0 (tally (expand (peep as (trim (expand rest as 0)) "") as 0)))
   (do-assign as nm op val)
   (: v (trim val)
      (? (= op "=")   (pin as nm v)
         (= op ":=")  (pin as nm (expand v as 0))
         (= op "::=") (pin as nm (expand v as 0))
         (= op "?=")  (: cur (peep as nm 'cook.undef) (? (nom? cur) (pin as nm v) 0))
         (= op "+=")  (: o (peep as nm "") (pin as nm (? (< 0 (tally o)) (+ o (+ " " v)) v)))
         (pin as nm v)))

   ; -- fold classified lines into a rules list, mutating `as`. The conditional
   ; stack is a list of frames (pon taken active); `on` is the top frame's active
   ; (1 when there is no frame). include splices the named files' lines inline.
   (r1 c) (cap (cup c)) (r2 c) (cap (cup (cup c))) (r3 c) (cap (cup (cup (cup c))))
   (addstep cur st) (link (cap cur) (link (cap (cup cur)) (link st (cup (cup cur)))))
   (finalize cur) (link (cap cur) (link (cap (cup cur)) (rev (cup (cup cur)))))
   (flushr cur rules) (? cur (link (finalize cur) rules) rules)
   (mkrule c)                  ; -> (TGTS-text PREREQS-text . STEPS-rev); split off an inline ; recipe
   (: prr (r2 c) sc (splittop prr 59)
      inl (? (&& (two? (cup sc)) (< 0 (tally (trim (cap (cup sc)))))) (L (parse-mods (trim (cap (cup sc))))) 0)
      (link (r1 c) (link (cap sc) inl)))
   (condon cond) (? (two? cond) (cap (cup (cup (cap cond)))) 1)
   (push-cond cond pon active) (link (L pon active active) cond)
   (else-cond cond) (: f (cap cond) pon (cap f) taken (cap (cup f)) na (&& pon (! taken))
                       (link (L pon (|| taken na) na) (cup cond)))
   (build cls as)
   ((: (loop cs rules cur cond)
       (? (! (two? cs)) (rev (flushr cur rules))
          (: c (cap cs) k (cap c) rest (cup cs) on (condon cond)
             (? (= k 'recipe) (loop rest rules (? (&& on cur) (addstep cur (r1 c)) cur) cond)
                (= k 'rule)   (? on (loop rest (flushr cur rules) (mkrule c) cond)
                                    (loop rest (flushr cur rules) 0 cond))
                (= k 'assign) (: _ (? on (do-assign as (r1 c) (r2 c) (r3 c)) 0) (loop rest (flushr cur rules) 0 cond))
                (= k 'inc)    (? on (: more (catmap file-lines (split-ws (expand (r1 c) as 0)))
                                       (loop (cat more rest) (flushr cur rules) 0 cond))
                                    (loop rest (flushr cur rules) 0 cond))
                ; conditionals thread `cur` (do NOT flush): a top-level rule is
                ; already flushed by the blank line before a conditional, while a
                ; conditional INSIDE a recipe block gates its lines via `on` above.
                (= k 'ifeq)   (loop rest rules cur (push-cond cond on (&& on (eval-ifeq (r1 c) as))))
                (= k 'ifneq)  (loop rest rules cur (push-cond cond on (&& on (! (eval-ifeq (r1 c) as)))))
                (= k 'ifdef)  (loop rest rules cur (push-cond cond on (&& on (eval-ifdef (r1 c) as))))
                (= k 'ifndef) (loop rest rules cur (push-cond cond on (&& on (! (eval-ifdef (r1 c) as)))))
                (= k 'else)   (loop rest rules cur (else-cond cond))
                (= k 'endif)  (loop rest rules cur (cup cond))
                (loop rest (flushr cur rules) 0 cond)))))
    cls 0 0 0)

   ; read a file whole (for `include`), then split it into classified lines.
   (slurp-of path) (: q (open path "r") (? q (slurp q) (: _ (say err (+ "cook: cannot read " path)) _ (put err 10) (exit 1))))
   (file-lines ip) (map classify (lines (uncont (slurp-of ip))))

   ; seed make's builtin defaults (overridable by the Makefile).
   (seed-defaults as)
   (: _ (pin as "CC" (: e (getenv "CC") (? (&& (string? e) (< 0 (tally e))) e "cc")))
       _ (pin as "MAKE" "make") _ (pin as "AR" "ar") _ (pin as "RM" "rm -f") as)

   ; split a prereq word list at a `|` into (normal . order-only).
   (splitbar ws) ((: (g l acc) (? (! (two? l)) (link (rev acc) 0)
                       (? (= (cap l) "|") (link (rev acc) (cup l)) (g (cup l) (link (cap l) acc))))) ws 0)

   ; parse a Makefile and REGISTER its rules. .PHONY members become phony SYMBOLS;
   ; every other item a file STRING. A rule line is one of: a STATIC pattern rule
   ; (targets: tgtpat: prereqpats), an implicit PATTERN rule (a % target -> stored
   ; for prep-time resolution), or a NORMAL rule. The first registered is the ticket.
   (register-makefile src)
   (: as (seed-defaults (tablet 0))
      rules (build (map classify (lines (uncont src))) as)
      phony (: ps (tablet 0)
               _ (each rules (\ r (: tg (expand-words (L (cap r)) as)
                    (? (any (\ t (= t ".PHONY")) tg)
                       (each (expand-words (L (cap (cup r))) as) (\ p (pin ps p 1))) 0)))) ps)
      (mk-item nm) (? (peep phony nm 0) (intern nm) nm)
      patbox (tablet 0)        ; accumulates implicit pattern rules: (tgtpat prs oos . raws)
      _ (each rules (\ r
           (: tgtstext (cap r) prtext (cap (cup r)) raws (cup (cup r))
              tgts (expand-words (L tgtstext) as)
              (? (any (\ t (&& (< 0 (tally t)) (= (t 0) 46))) tgts) 0    ; drop .PHONY / .SUFFIXES / ...
                 (: cp (splittop prtext 58)
                    (? (two? (cup cp))
                       ; static pattern rule
                       (: tpat (cap (expand-words (L (cap cp)) as)) ppats (expand-words (L (cap (cup cp))) as)
                          (each tgts (\ t (: m (pmatch tpat t)
                             (? (two? m) (: stem (cap m) ping (map (\ pp (stemsub pp stem)) ppats)
                                            (reg (mk-item t) (map mk-item ping) 0 (expand-steps raws (mk-item t) ping stem as))) 0)))))
                       ; implicit pattern rule, or normal rule
                       (: sb (splitbar (expand-words (L prtext) as)) prs (cap sb) oos (cup sb)
                          (? (any haspct tgts)
                             (each tgts (\ t (? (haspct t) (pin patbox 0 (link (L t prs oos raws) (peep patbox 0 0))) 0)))
                             (each tgts (\ t (reg (mk-item t) (map mk-item prs) (map mk-item oos)
                                                  (expand-steps raws (mk-item t) prs "" as))))))))))))
      patlist (peep patbox 0 0)
      (psrc p item) (: stem (cap (pmatch (cap p) item)) prs (cap (cup p)) (? (two? prs) (stemsub (cap prs) stem) ""))
      (best-of ms item)        ; prefer a pattern whose stem-source exists, then the shortest stem
      (: ok (filter (\ p (exists? (psrc p item))) ms) cand (? (two? ok) ok ms)
         (foldl (\ b p (? (! b) p (? (< (tally (cap (pmatch (cap p) item))) (tally (cap (pmatch (cap b) item)))) p b))) 0 cand))
      (resolve item)           ; synthesize a card from the best matching pattern rule (merging an explicit prereq-only card)
      (: ms (filter (\ p (two? (pmatch (cap p) item))) patlist) best (best-of ms item)
         (? best
            (: stem (cap (pmatch (cap best) item))
               ping (map (\ pp (stemsub pp stem)) (cap (cup best)))
               poo  (map (\ pp (stemsub pp stem)) (cap (cup (cup best))))
               ex (peep cards item ())
               allp (? ex (cat (map mk-item ping) (cap ex)) (map mk-item ping))
               oo   (? ex (cat (map mk-item poo) (cap (cup ex))) (map mk-item poo))
               (link allp (link oo (expand-steps (cap (cup (cup (cup best)))) item ping stem as))))
            0))
      (pin pgen 0 resolve))

   ; -- emit: serialize the RESOLVED cards back as a Cookfile ------------------
   ; after register-makefile (with emitp set) the cards hold concrete, fully
   ; expanded items and ("sh" "-c" cmd) steps. We walk the dependency graph from
   ; every root -- the default ticket FIRST (so it stays the default in the output),
   ; then every other registered card -- resolving pattern rules to concrete cards
   ; exactly as prep does, and print each as a (recipe ..) / (reg ..) form. A
   ; pattern-only target with no card prints nothing (a source leaf).
   (qshow x) (+ "'" (show x))                ; a quoted datum literal: 'all, '("a" b)
   (estep steps) (? (two? steps) (qshow steps) "0")
   (emit-line item ings oo steps)
   (: row (? (two? oo)
             (L "(reg" (qshow item) (qshow (? (two? ings) ings 0)) (qshow oo) (estep steps))
             (L "(recipe" (qshow item) (qshow (? (two? ings) ings 0)) (estep steps)))
      _ (puts (join " " row)) _ (puts ")") (putc 10))
   ; pre-order walk; `seen` (a tablet) keeps a shared prerequisite to one card.
   ; the card lookup mirrors prep: an explicit recipe wins, else a pattern rule.
   (emit-walk item seen)
   (? (peep seen item 0) 0
      (: _ (pin seen item 1)
         exr (peep cards item 'none)
         ex (? (two? exr) exr 0)
         f (peep pgen 0 ())
         r (? (&& ex (two? (cup (cup ex)))) ex
              (: g (? f (f item) 0) (? (two? g) g ex)))
         (? (two? r)
            (: ings (cap r) oo (cap (cup r)) steps (cup (cup r))
               _ (emit-line item ings oo steps)
               _ (each ings (\ d (emit-walk d seen)))
               _ (each oo (\ d (emit-walk d seen))) 0)
            0)))
   (emit-cookfile _)
   (: _ (puts "; generated by `cook --emit` from the Makefile -- do not edit by hand.") _ (putc 10)
       _ (puts "; the Makefile's $(shell)/$(wildcard)/vars/patterns are RESOLVED here; each") _ (putc 10)
       _ (puts "; recipe line became an (\"sh\" \"-c\" cmd) step. make's @ (silent) and -") _ (putc 10)
       _ (puts "; (ignore-error) line modifiers are not carried across.") _ (putc 10) _ (putc 10)
       seen (tablet 0)
       dflt (peep check 0 ())
       _ (? dflt (emit-walk dflt seen) 0)
       _ (each (keys cards) (\ k (emit-walk k seen)))
       _ (putc 10) _ (puts "(cook-all 0)") (putc 10))

   ; is a recipe-file path named like a Makefile? then cook reads it as one.
   (mk-lastslash p) ((: (g j) (? (< 0 j) (? (= (p (- j 1)) 47) j (g (- j 1))) 0)) (tally p))
   (mk-base p) (snip p (mk-lastslash p) (tally p))
   (mk-ends p suf) (: ls (tally suf) lp (tally p) (&& (<= ls lp) (= suf (snip p (- lp ls) lp))))
   (makefilep p) (: b (mk-base p)
      (|| (= b "Makefile") (|| (= b "makefile") (|| (= b "GNUmakefile") (mk-ends p ".mk")))))

   ; the build file may be named explicitly (the first original-argv word that is
   ; not the program head or a -l chain) or DISCOVERED in the cwd. We cannot call
   ; cli.l's strip-l to find the explicit one -- it would re-load this file.
   (mk-args a) ((: (g x) (? (! (two? x)) 0
                  (? (= (cap x) "-l") (g (cup (cup x))) (link (cap x) (g (cup x)))))) (cup a))
   (exists? p) (: q (open p "r") (? q 1 0))     ; a one-shot probe (the fd dies with the process)
   ; discovery precedence: an ai-native recipe file wins over a Makefile -- a
   ; legacy Cards.l first, then a Cookfile, then a Makefile. Only a Makefile-named
   ; file (makefilep) is ever read as make; Cards.l and Cookfile are ai source.
   ; (a dummy param: a nullary (f) would be \ with one operand = quote.)
   (discover _) ((: (g ps) (? (two? ps) (? (exists? (cap ps)) (cap ps) (g (cup ps))) 0))
               '("Cards.l" "Cookfile" "Makefile"))

   ; -- the command line ---------------------------------------------------------
   ; cook owns its own arg parse over the rebound argv (cli.l stops at the first
   ; non-flag; cook reads the rest via mk-args). Like make, it takes flags in any
   ; order and treats every non-flag word as a recipe to build:
   ;   -f, --file FILE   the build file (a Makefile or a Cookfile); else discovered
   ;   --emit            transpile a Makefile to a resolved Cookfile on stdout, then exit
   ;   -h, --help, help  print usage and exit
   ;   -v, --version, version   print the version and exit
   ;   RECIPE ...        the items to cook (default: the first recipe declared)
   ; for back-compat with `cook <Makefile> [recipe]`, when no -f is given the first
   ; positional word that names an existing file is taken as the build file and the
   ; rest are recipes; with -f, every positional word is a recipe.
   (bye s) (: _ (puts s) _ (putc 10) _ (flush out) (exit 0))
   (version _) (bye (+ "cook (ai " (+ ai-version ")")))
   (usage _) (bye (+ "usage: cook [-f FILE] [--emit] [-v] [-h] [RECIPE ...]\n"
              (+ "  -f, --file FILE   the build file (Makefile or Cookfile); else discovered\n"
              (+ "      --emit        transpile a Makefile to a resolved Cookfile, then exit\n"
              (+ "  -v, --version     print the version and exit\n"
              (+ "  -h, --help        print this help and exit\n"
              (+ "  RECIPE ...        the items to build (default: the first recipe declared)\n"
                 "a Makefile (Makefile/makefile/GNUmakefile/*.mk) is imported and cooked; any other build file is a Cookfile of ordinary ai source.")))))))
   (need-arg h r) (? (two? r) 0 (: _ (say err (+ "cook: " (+ h " needs an argument"))) _ (put err 10) (exit 2)))
   (parse-args ws)             ; -> a tablet: 'file, 'emit, 'help, 'ver, 'pos (the recipe words, in order)
   ((: (loop ws opt) (? (! (two? ws)) opt
       (: w (cap ws) r (cup ws)
          (? (|| (= w "-f") (= w "--file")) (: _ (need-arg w r) _ (pin opt 'file (cap r)) (loop (cup r) opt))
             (= w "--emit")                                       (: _ (pin opt 'emit 1) (loop r opt))
             (|| (= w "-h") (|| (= w "--help") (= w "help")))      (: _ (pin opt 'help 1) (loop r opt))
             (|| (= w "-v") (|| (= w "--version") (= w "version"))) (: _ (pin opt 'ver 1) (loop r opt))
             (: _ (pin opt 'pos (cat (peep opt 'pos ()) (L w))) (loop r opt))))))
    ws (tablet 0))

   ; -- the dispatch (this form's body) --
   ; cook is loaded with -l, then the host CLI driver loads the recipe file. We do
   ; the whole job HERE and exit first, so the driver never tries to read a Makefile
   ; (or re-read the chosen file) as love source. A Makefile is imported and its
   ; recipes cooked; a Cookfile is read and evaluated -- it drives cook itself, the
   ; ticket read live by (ticket 0) from the tickets box this dispatch fills.
   (: opt (parse-args (mk-args argv))
      _ (? (peep opt 'help 0) (usage 0) 0)
      _ (? (peep opt 'ver 0) (version 0) 0)
      emit? (peep opt 'emit 0)
      pos (peep opt 'pos ())
      xf (peep opt 'file 0)                                       ; an explicit -f file (0 if none)
      _ (? (&& xf (! (exists? xf))) (: _ (say err (+ "cook: cannot open " xf)) _ (put err 10) (exit 1)) 0)
      posfile (? (&& (! xf) (&& (two? pos) (exists? (cap pos)))) (cap pos) 0)  ; a positional build file (back-compat)
      file (? xf xf (? posfile posfile (discover 0)))
      _ (pin tickets 0 (? posfile (cup pos) pos))                 ; the recipe words; the positional file is not a recipe
      (? emit?
         (: _ (? file 0 (: _ (say err "cook: --emit needs a Makefile") _ (put err 10) (exit 1)))
             q (open file "r")
             _ (pin emitp 0 1)
             _ (register-makefile (slurp q))
             _ (emit-cookfile 0)
             (exit 0))
         file
         (: q (open file "r")
            _ (? (makefilep file)
                 (: _ (register-makefile (slurp q)) (cook-all 0))
                 ((: (g e) (: r (read q e) (? (= e r) 0 (: _ (ev 'ev r) (g e))))) (mint 0)))
            (exit 0))
         (two? pos)
         (: _ (say err "cook: no Cards.l, Cookfile or Makefile found") _ (put err 10) (exit 1))
         0)))
