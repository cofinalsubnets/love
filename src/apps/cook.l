#!/usr/bin/env -S love -l
; cook -- love make
;
; `cook Cookfile [ticket]` execs `love -l <this-file> Cookfile [ticket]`: the `#!` line is
; a comment to love. the verb is `cook`, never "bake" -- that word is the egg's.
;
; an item is brought up to date by prepping its prerequisites first (depth first), then
; running its recipe if the item is missing or older than any of them.
;
; (recipe item ingredients steps):
;   item -- a filename string, or a phony symbol ('all, 'clean ..): no file, so no age, and
;           it always runs, cascading to everything that needs it.
;   ingredients -- a list of prerequisite items (strings and/or symbols).
;   steps -- each an argv list run as a subprocess via `hark`, or a thunk called as (step 0).
;           an empty list is a pure aggregate.
; a missing file and a phony item both read as the zero point (): ageless, so always rebuilt.
; the first recipe declared is the default ticket, as in make.
;
; usage:  cook [-f file] [--emit] [recipe ..]  (with the symlink installed)
;     or:  love -l src/apps/cook.l [-f file] [recipe ..]
; a Cookfile is love source laying out recipes then driving them: (cook-all 0) builds every
; recipe named on the command line, (cook (ticket 0)) just the first. only a file named like a
; Makefile (makefilep) is read as make.

; module 'cook keeps the ~30 globals (`join` `date` `check` `shell` among them) off a cat's
; session layer too.
(module 'cook

; the combinators, first so the names walk before anything below compiles against them.
(borrow 'peg)

(borrow 'posix)

; match/anyglob under $(wildcard), the path clips under make's $(dir) family.
(borrow 'glob)
(borrow 'path)

(: cards {}          ; the recipe cards: item -> (ingredients orderonly . steps)
   check {}        ; a 1-cell box: the first item declared, the default ticket
   tickets {}      ; a 1-cell box: the recipe words named on the command line
   pgen {}         ; a 1-cell box: a pattern-rule resolver (item -> a card | 0), from the importer
   cookbox {}      ; the in-image shell verdicts (inimg), one per SHELL and .SHELLFLAGS
   jobs {}         ; a 1-cell box: the -j width (1 = serial, nothing forks)
   dryrun {}       ; ..and one for -n: every step is said and none is run
   running {}      ; pid -> the item whose recipe that job is running
   verdicts {}     ; pid -> the status a reaped job answered, until its land takes it

   origins {}      ; $(origin): name -> "default" | "environment" | "file" | "command line" | "override"
   flavors {}      ; $(flavor): name -> "simple" | "recursive": the value cannot say which
   clivars {}      ; a 1-cell box: the command line's VAR=VAL words, ((name . val) ..)

   ; one card per item, merging: prereqs accumulate deduped and a later non-empty recipe
   ; wins, as make does. card = (ingredients orderonly . steps); orderonly prereqs are
   ; built-if-missing but never make a target stale (make's `| prereqs`).
   (adds a b) (foldl (acc \ x \ elem x acc ? acc (acc + [x])) a b)
   ; a leading $HOME or $PWD in an item or a prereq opens here; step strings are left to sh -c
   (unpre w tok val)
   (#tok @ n
      (string? val && #w >= n && tok = snip w 0 n ?
         (val + snip w n #w) w))
   (unseat w) (!(string? w) ? w (unpre (unpre w "$HOME" (getenv "HOME")) "$PWD" (cwd 0)))
   (unseatl l) (atom? l ? l (map unseat l))
   (reg item ing oo steps)
   (: at (unseat item) ins (unseatl ing) ors (unseatl oo)
      prev (cards at)
      (prev ?
         (pin cards at (adds <prev ins .  adds <>prev ors .  (two? steps ? steps >>prev)))
         (pin cards at (ins . ors . steps),
          peep check 0 0 ? 0 (pin check 0 at),
          at)))
   ; `tgt:: ..` runs every such rule's steps, in the order written; reg's later-wins is `:`'s.
   ; tvarbox: the targets carrying a target-specific variable (see classify); recur asks.
   tvarbox {}
   (regd item ing oo steps)
   (: at (unseat item) ins (unseatl ing) ors (unseatl oo)
      prev (cards at)
      (prev ? (pin cards at (adds <prev ins . adds <>prev ors . >>prev + steps))
         (reg item ing oo steps)))
   ; the public Cookfile API: no order-only prereqs.
   (recipe item ingredients steps) (reg item ingredients 0 steps)

   ; the item's mtime in nanoseconds, so two writes inside one tick still order; () for a
   ; phony item or a file not on disk.
   (date item)
   (nom? item ? () (stat item @ st (two? st ? <>>>st))))

; --- prepping an item up to date ---------------------------------------------
; `done` memoizes each item's settled age; `shipped` records the items whose recipe advanced
; their file's mtime, so a rebuilt prerequisite forces its dependents past clock granularity.

(: (prep item done shipped pending)
   (? (done item) (done item)
      (two? (pending item)) ()                       ; a job is up for it; landing it settles it
      ; an explicit recipe wins; else a pattern rule may synthesize a card. presence is
      ; `two?`, never truthiness: an all-empty card (() ()) nets 0
      (: exr (peep cards item 'none)
         ex (two? exr ? exr 0)
         f (pgen 0)
         r (ex && two? >>ex ? ex
              (: g (f ? (f item) 0) (two? g ? g ex)))
         (two? r ?
            ; prep leaves a stale prerequisite's job running so the next subtree starts beside
            ; it; only the land pass waits, since an age cannot be read off a file being written
            (: ingredients <r orderonly <>r steps >>r
               (each ingredients (d \ prep d done shipped pending),
                each orderonly (d \ prep d done shipped pending),
               ; a pure aggregate owes no age: park its land under the item, so a phony's
               ; subtree does not block its siblings; the parent's jobland brings it home.
                (atom? steps ?
                   (pin pending item ['agg (ingredients + orderonly)], ())
                   (: _ (each ingredients (d \ jobland d done shipped pending))
                      _ (each orderonly (d \ jobland d done shipped pending))
                      ta0 (date item)
                      fresh (any shipped ingredients)   ; a prerequisite's file changed
                      older (any (d \ (done d @ da
                                         (!da ? 1 (!ta0 ? 1 (da > ta0))))) ingredients)
                      stale (!ta0 || fresh || older)
                      ; stale: run as a job where there is room to fork one, else here
                      j (stale ? (jobstart item steps) 0)
                      (j ? (pin pending item (j . ta0 . steps), ta0)
                           (settle item ta0 (stale ? steps) done shipped))))))
            ; no card: a source leaf, which must already exist.
            (date item @ ta
             (ta ? 0 (say err "cook: no recipe to make \(item)\n", quit 1),
              pin done item ta,
              ta)))))

   ; marks shipped only where the recipe advanced the mtime, so a no-op rebuild does not
   ; force dependents. `steps` is () when no recipe ran.
   (settle item ta0 steps done shipped)
   (date item @ nw
      ((two? steps && (!ta0 ? !!nw (nw ? (nw > ta0) 0)) ?
          (pin shipped item 1) 0),
       pin done item nw,
       nw))

   ; a prerequisite's job must land before its age can be read. the pull leads, so a card
   ; that reaches itself cannot circle.
   (jobland item done shipped pending)
   (peep pending item 0 @ v
      (? (atom? v) ()
         (<v = 'agg) (pull pending item 0,
                      each <>v (d \ jobland d done shipped pending),
                      settle item () () done shipped)
         (jobwait <v @ st
            (pull pending item 0,
             0 != st && jobdie item st,
             settle item <>v >>v done shipped))))

   ; a target-specific variable is refused here, not at parse, which would refuse a
   ; Makefile over a scope no build enters.
   (recur item steps)
   (: k (unseat item)
      nm (string? k ? k (show k))
      ((#(peep tvarbox k "") ?
          (say err "cook: target-specific variable (\(nm)) not implemented.\n",
           quit 2)),
       each steps step1))

   ; --- the job pool (-j N) --------------------------------------------------
   ; a stale recipe runs in a forked child (no exec): a job's outputs are the files it wrote
   ; and its status. a thunk's heap effect lands in the child, so a Cookfile that mutates
   ; cook's tables wants -j1, the default. names are job-prefixed: this scope leaks into the
   ; layer the expander walks.
   (jobw _) (peep jobs 0 1 @ n (0 < n ? n 1))

   ; an (exec ..) step replaces the process, so it can never be a job
   (jobforkable? steps) (!(any ('exec . _ \ 1) steps))

   ; answers the job's pid, or 0 when it ran here. the serial lane drains first: herald waits
   ; on its own child and `glean` reaps any child, so the two must never overlap.
   (jobstart item steps)
   (? (!(two? steps)) 0
      (!(1 < jobw () && jobforkable? steps)) (jobdrain 0, recur item steps, 0)
      (: _ (jobw () <= #running ? (jobreap 0) 0)          ; wait for a slot
         _ (flush out) _ (flush err)
         p (fork 0)
         (? (0 = p) (quit (urun (_ \ (recur item steps, 0)) ()))   ; the child
            (0 < p) (pin running p item, p)
            (recur item steps, 0))))

   ; reap one job and file its verdict under its pid. `glean` is waitpid(-1, WNOHANG): a poll
   (jobreap _)
   (glean 0 @ r
      (? (two? r) (pin verdicts <r >r, pull running <r 0, <r)
         (charm? r) ()                                      ; -errno: no children left
         (rest 1, jobreap 0)))

   ; a pid neither filed nor running was reaped elsewhere: its verdict is gone, not green
   (jobwait p)
   (peep verdicts p 'no @ v
      (? (v != 'no) (pull verdicts p 0, v)
         (0 = #running) (udie 1 "cook: lost the job for pid \(p)")
         (jobreap 0, jobwait p)))

   (jobdrain _) (0 < #running ? (jobreap 0, jobdrain 0) 0)

   ; outstanding jobs finish first, as make does: a half-written file left by a kill would read
   ; as up to date on the next run.
   (jobdie item ec)
   (jobdrain 0,
    say err "cook: the recipe for \(item) failed\n",
    quit ec)

   ; (exec PROG ARGS..) replaces cook and inherits the terminal; a string list runs on a pipe
   ; with /dev/null stdin, so it cannot be interactive; else a thunk.
   (step1 step)
   (? (two? step && <step = 'exec) (do-exec >step)
      (two? step) (shell step)
      (lit? step) (step 0))

   ; the exec nif returns only on failure
   (do-exec argv)
   (flush out,
    exec argv,
    say err $ cats ["cook: cannot exec " (join " " argv) "\n"],
    quit 1)

   ; the flush is load-bearing: herald writes the child's bytes past the `out` buffer
   (shell step)
   (: _ (puts ("  " + join " " step)) _ (putc 10)
       _ (flush out)
       r (herald step)
       (two? r ?
          (0 = <r ? 0 (udie 1 "cook: command failed (exit \(<r))"))
          (udie 1 "cook: cannot run \(join " " step)")))

   ; the in-image shell, decided once: where the shell we would spawn is this binary, the
   ; line runs here, one wake per make. asked through the module: standalone cook has no lush
   ; aboard, and the from-reads answer () -- the spawn lane. a mode letter in .SHELLFLAGS
   ; (-ac, -gc, -pc) is the mode the shell is asked under.
   (inimg sh fl)
   (: k (join " " (sh . fl)) v (peep cookbox k 'no)
       (v != 'no ? v
          (: ours (cite 'lush 'sh-ours?) one (cite 'lush 'sh-oneline)
             fs (cite 'lush 'sh-oneflags) in (cite 'lush 'sh-inmode) nw (cite 'lush 'sh-new)
             ; each line a shell of its own, its state fresh
             f (lit? ours && lit? one && lit? fs && lit? in && lit? nw
                && (nw 0 @ S (in S (fs fl @ r (two? r ? (r 4) ())) (_ \ ours S sh)))
                ? (\ g c (one (nw 0) g c)) 0)
             (pin cookbox k f,
              f))))

   ; one make recipe line via SHELL -c: echo it unless @, stream its stdout (a recursive
   ; $(MAKE) rides this), and on failure carry on (-) or abort. the in-image door answers
   ; (1 status) when it took the line; () falls through to the spawn.
   (sh-line silent ignore sh flags cmd)
   (: _ (silent ? 0 (puts cmd, putc 10))
       _ (flush out)
       f (inimg sh flags)
       o (f ? (f flags cmd))
       r (two? o ? [<>o] (herald ([sh] + flags + [cmd])))
       ec (two? r ? <r -1)
       (? (0 = ec) 0
          (atom? r) (udie 1 "cook: cannot run \(cmd)")
          ignore (say err "cook: \(cmd) (exit \(ec), ignored)\n")
          (udie 1 "cook: command failed (exit \(ec))"))))

; --- the entry points ----------------------------------------------------------

; prep item quietly, answering the tablet of items whose recipe advanced their file.
(: (prepped item)
   (: done {} shipped {} pending {}
      (prep item done shipped pending,
       jobland item done shipped pending,
       shipped))

   (cook item)
   (!item ? (say err "cook: nothing to cook\n", quit 1)
      (prepped item @ shipped 
         ; a run that built something says nothing, as make does
         (0 < #shipped ? 0 (puts "cook: \(item) is already up to date\n"))))

   ; a command-line word -> an item: a file recipe's string, a phony's symbol, a file that is
   ; there, else a refusal -- never the default, which would cook the tree behind a typo.
   (pick a) (cards a ? a
               (: s (nom a)
                  f (pgen 0)
                  g (f ? (f a) 0)
                  (? (cards s) s
                     (two? g) a
                     (date a) a
                     (say err $ "cook: no recipe to make " + show a + "\n", quit 1))))

   ; the first recipe word named, else the default; read live, so a Cookfile sees the args.
   (ticket _) (tickets 0 @ ts (two? ts ? (pick <ts) (check 0)))

   ; every recipe word named on the command line, or the default
   (cook-all _) (tickets 0 @ ts
                (two? ts ? (each ts (cook * pick)) (cook (check 0)))))

; --- importing a Makefile ------------------------------------------------------
; a parser is (\ s y n) over a state s (text . i): y the success continuation, n the failure
; one; the payload is a list `seq` concatenates. reasonably GNU-compatible: recursive $(VAR)
; and substitution refs, the common functions, ifeq/ifdef, `include`, the = := ?= += flavors,
; pattern and static-pattern rules, order-only prereqs, the automatics; recipe lines run via sh -c.
;
; $(wildcard) prefers lush's glob, so `love make` globs before a shell exists; else globw
; shells out. the probe names sh-line, not the module: module 'lush exists from the floor.
(? (lit? (cite 'lush 'sh-line)) 0
   (two? (stat "src/apps/lush.l")) (borrow "src/apps/lush.l")
   0)
; the pathname glob: a closure when lush's glob is aboard, else ().
(: cook-glob (: g (cite 'lush 'sh-glob) o (cite 'lush 'sh-ones)
                (lit? g && lit? o ? (pat \ g pat (o #pat)))))

; the importer is one body-having `:`, so its helpers do not leak. it answers cook-main
; (args -> status; failure leaves by udie), which kore calls as `make`, and cook-vars/cook-expand.
(: cook-pubs (:
   ; --emit: expand-steps lays a serializable ("sh" "-c" cmd) step, not a thunk
   emitp {}


   ; -- character classes and string utilities --
   (chws (32 || 9)) 1
   (digitp c)   (48 <= c <= 57)
   (alphap c)   (65 <= c <= 90 || 97 <= c <= 122)
   (namech c)   (alphap c || digitp c || c = 95 || c = 46)
   ; notcolon admits whitespace: `a.out b.out: src` is one rule with two targets
   (notcolon c) (c != 58)
   ; an assigned name is make's: anything but whitespace, : = #, and the op leads + ? !
   (varch c)    !(chws c || elem c '(58 61 35 43 63 33))
   ; ..read paren-aware: inside a $(..) or ${..} anything goes
   (nameP s y n)
    (: t <s i >s
       (g j d) (? (#t <= j) j
                  (0 < d) (? (t j = 40 || t j = 123) (g (1 + j) (d + 1))
                             (t j = 41 || t j = 125) (g (1 + j) (d - 1))
                             (g (1 + j) d))
                  (t j = 36 && j + 1 < #t && (t (1 + j) = 40 || t (1 + j) = 123)) (g (2 + j) 1)
                  (varch (t j)) (g (1 + j) 0)
                  j)
       k (g i 0)
       (y (t . k) [(snip t i k)]))
   (anyc c)     1
   (ltrim s) (: i ((: (g j) (j < #s && chws (s j) ? (g (1 + j)) j)) 0)
               (snip s i #s))
   (rtrim s) (: i ((: (g j) (0 < j && chws (s (j - 1)) ? (g (j - 1)) j)) #s)
               (snip s 0 i))
   (trim s)  (rtrim (ltrim s))
   (findc s i ch) (i >= #s ? i (s i = ch ? i (findc s (1 + i) ch)))
   (split-ws s)
   ((: (g i st acc)
       (i >= #s ? (rev (st < i ? (snip s st i . acc) acc))
          (chws (s i) ?
             (g (1 + i) (1 + i) (st < i ? (snip s st i . acc) acc))
             (g (1 + i) st acc))))
    0 0 0)

   ; fold \<newline> continuations: off a recipe, `<ws>*\<newline><ws>*` is one space; in a
   ; recipe the backslash-newline goes and only the continuation's leading tab is eaten.
   ; the first physical line decides recipe-ness for every fold.
   (rtws s) (: i ((: (g j) (0 < j && (s (j - 1) = 32 || s (j - 1) = 9) ? (g (j - 1)) j))
                  #s)
               (snip s 0 i))
   (uncont s)
    (: (cont? l) (0 < #l && l (#l - 1) = 92)
       (lead l) ((: (h k) (k < #l && (l k = 32 || l k = 9) ? (h (1 + k)) k)) 0)
       (glue rec cur l)
        (: c (snip cur 0 (#cur - 1))
           (rec ? (c + (0 < #l && l 0 = 9 ? (snip l 1 #l) l))
              (rtws c + " " + snip l (lead l) #l)))
       ; one logical line off the head: [text rest]
       (one rec cur ls) (cont? cur && two? ls ? (one rec (glue rec cur <ls) >ls) [cur ls])
       ; a define body's joins are a variable's, never a recipe's, however its lines lead
       (indef d x) (: t (trim x) w (first-word t)
                      (d ? (w != "endef")
                         (w = "define" || (w = "override" || w = "export") && first-word (after-word t) = "define")))
       (g ls acc d)
        (atom? ls ? (join "\n" (rev acc))
           (: l <ls
              (one (!d && 0 < #l && l 0 = 9) l >ls @ [x r] (g r (x . acc) (indef d x)))))
       (g (lines s) () 0))
   (lines s)
   ((: (g i st acc)
       (i >= #s ? (rev (snip s st i . acc))
          (s i = 10 ? (g (1 + i) (1 + i) (snip s st i . acc))
             (g (1 + i) st acc))))
    0 0 0)

   ; -- string utilities for the make layer --
   (findc-ws s i) (i >= #s ? i (chws (s i) ? i (findc-ws s (1 + i))))
   (first-word s) (snip s 0 (findc-ws s 0))
   (after-word s) (ltrim (snip s (findc-ws s 0) #s))
   (lastl l) (two? >l ? (lastl >l) <l)
   ; `sub` is snip with the ends ordered: "" when start >= end.
   (sub s a b) (a < b ? (snip s a b) "")
   ; strip a make comment (an unescaped #) from a non-recipe line; \# is a literal #.
   (strip-comment l)
   (findc l 0 35 = #l && findc l 0 92 = #l ? l
   ((: (g i acc)
       (i >= #l ? acc
          (l i @ c
             (? (c = 35) acc
                (c = 92) (1 + i < #l ?
                            (l (1 + i) @ d (d @ 35 (g (2 + i) (acc + "#")) (g (2 + i) (acc + "\\" + string d))))
                            (acc + "\\"))
                (g (1 + i) (acc + string c))))))
    0 ""))
   ; split on a top-level `ch`: a delimiter inside $(..) / ${..} does not split
   (splittop s ch)
   (:- (g 0 0 0 ())
    (g i depth st acc)
     (i >= #s ? (rev (snip s st i . acc))
      (s i @ (40 || 123) (g (1 + i) (1 + depth) st acc)
             (41 || 125) (g (1 + i) (depth - 1) st acc)
             (^ch && depth = 0) (g (1 + i) depth (1 + i) (snip s st i . acc))
             (g (1 + i) depth st acc))))

   ; -- the line grammar: NAME OP VALUE (op kept) and a rule header (raw text) --
   ; `!=` runs its value and takes the output, the spelling bmake and GNU both read
   opP (alt (lit "::=") (alt (lit ":=") (alt (lit "?=") (alt (lit "+=") (alt (lit "!=") (lit "="))))))
   assignP (seqs [(skip (span chws)) nameP
                   (skip (span chws)) (pmap (x \ [<x]) opP)
                   (skip (span chws)) (span anyc)])
   ruleP (seqs [(skip (span chws)) (span notcolon) (skip (lit ":")) (span anyc)])

   ; classify a line -> (recipe TEXT) | (assign NAME OP VAL) | (rule TGTS PREREQS)
   ; | (inc TEXT) | (ifeq|ifneq|ifdef|ifndef|else REST) | (endif) | (skip).
   (recipep l)  (0 < #l && l 0 = 9)
   ; strip the leading run of @ - + modifiers -> (silent ignore . body); + is a no-op here
   (parse-mods s)
   ((: (g i sil ign)
       (i < #s && (chws (s i) || s i = 64 || s i = 45 || s i = 43) ?
          (g (1 + i) (sil || s i = 64) (ign || s i = 45))
          (sil . ign . snip s i #s))) 0 0 0)
   (recipe-parse l) (parse-mods (snip l 1 #l))   ; drop the leading tab
   (classify l)
   (recipep l ? ['recipe (recipe-parse l) l]
      (: t (strip-comment l) tt (trim t)
         (? (0 = #tt) '(skip)
            (: w (first-word tt) rest (after-word tt)
               (? (w = "include") ['inc rest]
                  (w = "-include") ['sinc rest]
                  (w = "sinclude") ['sinc rest]
                  ; `override` assigns past a command-line VAR=VAL; `export` hands the
                  ; final value to the process environment
                  (w = "override") (parse assignP rest @ a (? (two? a) ('oassign . a) '(skip)))
                  (w = "export") (parse assignP rest @ a
                                    (two? a ? ('xassign . a) ['xname (trim rest)]))
                  ; a lone $(..) line is expanded for its side effect ($(error ..) is a
                  ; guard); `$(outs): %.out: %.in` merely begins with $( and stays a rule
                  (1 < #tt && tt 0 = 36
                   && (? (tt 1 = 40) (findclose tt 2 40 41 = #tt - 1)
                         (tt 1 = 123) (findclose tt 2 123 125 = #tt - 1)
                         0))
                    ['expand tt]
                  (w = "undefine" || w = "vpath") (cook-gap w)
                  (w = "ifeq") ['ifeq rest]
                  (w = "ifneq") ['ifneq rest]
                  (w = "ifdef") ['ifdef rest]
                  (w = "ifndef") ['ifndef rest]
                  (w = "else") ['else rest]
                  (w = "endif") '(endif)
                  (parse assignP t @ a
                     (two? a ? ('assign . a)
                        (parse ruleP t @ r 
                           ; `tgts: NAME op VALUE` is a target-specific variable: cook has
                           ; one variable table, so it is recorded and refused only if remade
                           (? !(two? r) '(skip)
                              (two? (parse assignP (tvar-text <>r 1))) ['tvar <r (tvar-text <>r 0)]
                              ('rule . r))))))))))
   ; a target-specific assignment past its modifiers; kept (x? 0) it holds its `export`
   (tvar-text s x?)
    (ltrim s @ t (first-word t @ w
       (any (= w) (x? ? '("private" "override" "export") '("private" "override")) && 0 < #(after-word t)
        ? (tvar-text (after-word t) x?) t)))

   ; -- nested-paren-aware variable expansion + make functions --
   ; the index of the ) that matches the ( just opened
   (findclose s i open close)
   (:- (g i 0) (g j depth)
     (j >= #s ? j
        (s j @ c
           (? (c = open) (g (1 + j) (1 + depth))
              (c = close) (0 = depth ? j (g (1 + j) (depth - 1)))
              (g (1 + j) depth)))))

   ; $(VAR:from=to) on one word: with a % a pattern whose stem fills `to`'s %, without one a
   ; trailing-text replacement. a non-match passes through.
   (patsub frm to w)
   (findc frm 0 37 @ pi
      (pi < #frm ?
         (: pre (sub frm 0 pi) suf (sub frm (1 + pi) #frm)
            lp #pre ls #suf lw #w
            (lw >= lp + ls && pre = sub w 0 lp && suf = sub w (lw - ls) lw ?
               (: stem (sub w lp (lw - ls)) ti (findc to 0 37)
                  (ti >= #to ? to (sub to 0 ti + stem + sub to (1 + ti) #to)))
               w))
         (: lf #frm lw #w
            (lw >= lf && frm = sub w (lw - lf) lw ? (sub w 0 (lw - lf) + to) w))))

   ; substitute the stem into a pattern prereq; no %, no change.
   (stemsub p stem) (findc p 0 37 @ pi
                       (pi < tally p ? (sub p 0 pi + stem + sub p (1 + pi) #p) p))
   ; match a pattern (one %) against a string -> (stem) | (); no % -> exact match.
   (pmatch pat s)
   (findc pat 0 37 @ pi
      (pi >= #pat ? (? (pat = s) '("") ())
         (: pre (snip pat 0 pi) suf (snip pat (1 + pi) #pat)
            lp #pre ls #suf ls2 #s
            (ls2 >= lp + ls && pre = snip s 0 lp && suf = snip s (ls2 - ls) ls2 ?
               [(snip s lp (ls2 - ls))]))))
   (haspct t) (findc t 0 37 < #t)
   (matchany pats w) (any (p \ two? (pmatch p w)) pats)

   (subst-ref eb as d)         ; VAR:from=to, already inner-expanded
   (: ci (findc eb 0 58) nm (sub eb 0 ci)
      spec (sub eb (1 + ci) #eb)
      ei (findc spec 0 61) frm (sub spec 0 ei)
      to (sub spec (1 + ei) #spec)
      v (expand (peep as nm "") as (1 + d))
      (join " " (map (patsub frm to) (split-ws v))))

   ; -- function helpers --
   (chomp s) ((: (g i) (0 < i && s (i - 1) = 10 ? (g (i - 1)) (snip s 0 i))) #s)
   (nl->sp s) (jug 0 @ j (each ^#s (i \ say j (string (s i @ 10 32 (s i)))), slurp j))
   ; $(shell) and != ride SHELL and .SHELLFLAGS as a recipe line does, captured. a
   ; function under " shell" answers instead, keeping a build's probes off the host
   (fn-shell as cmd)
    (: hook (peep as " shell" 0)
       (lit? hook ? (hook cmd) (fn-shell1 as cmd)))
   (fn-shell1 as cmd)
    (: sh (shname as) fl (shflags as) cap (cite 'lush 'sh-onecap) nw (cite 'lush 'sh-new)
       o (inimg sh fl && lit? cap ? (cap (nw 0) fl cmd))
       r (two? o ? o (hark ([sh] + fl + [cmd])))
       (two? r ? (nl->sp (chomp >r)) ""))
   ; $(wildcard): lush's glob when aboard, else glob1 -- no glob char is an existence test,
   ; else the last segment matched over readdir (a leading . only by an explicit .), sorted
   (glob1 pat)
   (!(anyglob pat) ? (exists? pat ? [pat] 0)
      (: k (lastslash pat)
         dir (0 < k ? (snip pat 0 (1 < k ? (k - 1) k)) ".")
         pfx (sub pat 0 k)
         leaf (snip pat k #pat)
         hid (0 < #leaf && leaf 0 = 46)
         ms (filter (e \ (hid || e 0 != 46) && match leaf e)
                    (readdir dir @ es (two? es && es)))
         (map (e \ 0 < #pfx ? (pfx + e) e) (sort ms))))
   (globw pat) (lit? cook-glob ? (cook-glob pat) (glob1 pat))
   ; $(dir) keeps the trailing slash and answers "./" for a bare name, unlike dirname
   (fdir w) (lastslash w @ k (0 < k ? (sub w 0 k) "./"))
   (fnotdir w) (sub w (lastslash w) #w)
   (fbase w) (lastdot w @ dot (dot < #w ? (sub w 0 dot) w))
   (fsuf w)  (lastdot w @ dot (dot < #w ? (sub w dot #w) ""))
   ; $(abspath): rooted on the cwd, then lexically cleaned; a `/..` past the root is "/"
   (fabs w)
   (: r (0 < #w && w 0 = 47 ? w
           (cwd 0 @ p (string? p ? (p + "/" + w) w)))
      cl (pclean (segs r) 0)
      ("/" + join "/" cl))
   (dedup l) (two? l ? (two? >l ? (<l = <>l ? (dedup >l) (<l . dedup >l)) l) l)
   (sortu l) (dedup (sort l))
   (strrep frm to s)
   (0 = #frm ? s
      ((: (g i acc) (subidx s frm i @ k (k < 0 ? (join "" (rev (snip s i #s . acc)))
                                           (g (k + #frm) (to . snip s i k . acc)))))
       0 ()))
   (fn-or args as d)  ((: (g l) (two? l ? (expand <l as (1 + d) @ v (0 < #(trim v) ? v (g >l))) "")) args)
   (fn-and args as d) ((: (g l last) (two? l ? (expand <l as (1 + d) @ v (0 < #(trim v) ? (g >l v) "")) last)) args "")
   ; --
   (num1 s) (sound (trim s) @ r (two? r ? <r 0))     ; a leading integer | 0
   (fn-join a b)                          ; $(join): the longer list's tail rides alone
    (: (g x y acc) (? (two? x) (g >x (two? y && >y) (<x + (two? y ? <y "") . acc))
                      (two? y) (g () >y (<y . acc))
                      (join " " (rev acc)))
       (g a b ()))
   (fn-slice ws n1 n2)                    ; $(wordlist): 1-based, inclusive, clamped
    (: (g l i acc) (? (atom? l || i > n2) (rev acc)
                      (i < n1) (g >l (1 + i) acc)
                      (g >l (1 + i) (<l . acc)))
       (g ws 1 ()))
   funcnames '("shell" "wildcard" "dir" "notdir" "basename" "suffix" "patsubst"
               "subst" "filter" "filter-out" "sort" "strip" "if" "or" "and"
               "addprefix" "addsuffix" "firstword" "lastword" "word" "words"
               "abspath" "realpath" "call" "origin"
               ; a name off this list is a variable: `$(foo bar)` answers empty
               "findstring" "join" "wordlist" "foreach" "value" "flavor"
               "error" "warning" "info" "eval" "intcmp" "file")
   ; ..but a name make implements and we do not refuses: an empty answer would be a rule
   ; quietly not existing. GNU's roster minus ours.
   gapnames '("let" "guile")
   (cook-gap what)
    (say err ("cook: " + what + " is not implemented.\n"),
     quit 2)
   ; $(call fn,a,..): bind $0 and $1.. to the expanded args, expand fn's body, restore
   (fn-call args as d)
   (: fname (trim (peep args 0 ""))
      body (peep as fname "")
      n ((: (g l i) (two? l ? (g >l (1 + i)) i)) args 0)
      olds (foldl (\ acc i ((show i . peep as (show i) 'cook.undef) . acc)) 0 ^n)
      _ ((: (g i l) (two? l ? (pin as (show i) (esc <l), g (1 + i) >l) 0)) 0 args)
      r (expand body as (1 + d))
      (each olds (pr \ nom? >pr ? (pull as <pr 0) (pin as <pr >pr)),
       r))
   (funcp nm) (any (f \ f = nm) funcnames)
   (findws s) ((: (g i) (i >= tally s ? i (chws (s i) ? i (g (1 + i))))) 0)
   (apply-func nm at as d)
   (: ex1 (x \ expand x as (1 + d))
      argl (_ \ map ex1 (splittop at 44))     ; comma-split + expanded
      rawl (_ \ splittop at 44)               ; comma-split, not expanded (if/or/and)
      (nm @ "shell"     (fn-shell as (ex1 at))
          "wildcard"  (join " " (catmap globw (split-ws (ex1 at))))
          "dir"       (join " " (map fdir (split-ws (ex1 at))))
          "notdir"    (join " " (map fnotdir (split-ws (ex1 at))))
          "basename"  (join " " (map fbase (split-ws (ex1 at))))
          "suffix"    (join " " (map fsuf (split-ws (ex1 at))))
          "strip"     (join " " (split-ws (ex1 at)))
          "sort"      (join " " (sortu (split-ws (ex1 at))))
          "patsubst"  (argl 0 @ a (join " " (map (w \ patsub (peep a 0 "") (peep a 1 "") w) (split-ws (peep a 2 "")))))
          "subst"     (argl 0 @ a (strrep (peep a 0 "") (peep a 1 "") (peep a 2 "")))
         "filter"    (argl 0 @ a (join " " (filter (w \ matchany (split-ws (peep a 0 "")) w) (split-ws (peep a 1 "")))))
         "filter-out"(: a (argl 0) (join " " (filter (\ w !(matchany (split-ws (peep a 0 "")) w)) (split-ws (peep a 1 "")))))
         "addprefix" (argl 0 @ a (join " " (map (w \ peep a 0 "" + w) (split-ws (peep a 1 "")))))
         "addsuffix" (argl 0 @ a (join " " (map (w \ w + peep a 0 "") (split-ws (peep a 1 "")))))
         "firstword" (split-ws (ex1 at) @ ws (two? ws ? <ws ""))
         "lastword"  (split-ws (ex1 at) @ ws (two? ws ? (lastl ws) ""))
         "word"      (: a (argl 0) ws (split-ws (peep a 1 "")) n (sound (trim (peep a 0 "")) @ r (two? r ? <r 0)) (peep ws (n - 1) ""))
         "words"     (show #(split-ws (ex1 at)))
         "if"        (: a (rawl 0) c (trim (ex1 (peep a 0 ""))) (0 < tally c ? (ex1 (peep a 1 "")) (ex1 (peep a 2 ""))))
         ; $(intcmp l,r,lt,eq,gt): gt falls back to eq; with two args, l when equal, else empty
         "intcmp"    (: a (rawl 0) l (num1 (ex1 (peep a 0 ""))) r (num1 (ex1 (peep a 1 "")))
                        (#a < 3 ? (l = r ? (show l) "")
                           (ex1 (peep a (l < r ? 2 (l = r || #a < 5 ? 3 4)) ""))))
         ; $(file <f): the text less one trailing newline, a missing file empty; writes refuse
         "file"      (ltrim (ex1 at) @ s
                        (0 < #s && s 0 = 60
                         ? (uread (trim (snip s 1 #s)) @ [1 x] (0 < #x && x (#x - 1) = 10 ? (snip x 0 (#x - 1)) x) "")
                         (cook-gap "$(file >..)")))
         "or"        (fn-or (rawl 0) as d)
         "and"       (fn-and (rawl 0) as d)
         "call"      (fn-call (argl 0) as d)
         "origin"    (trim (ex1 at) @ v (elem v (peep as " cl" ()) ? "command line" (peep origins v "undefined")))
         ("abspath" || "realpath") (join " " (map fabs (split-ws (ex1 at))))
         "findstring" (argl 0 @ a (0 <= findsub (peep a 1 "") (peep a 0 "") ? (peep a 0 "") ""))
         "join"      (argl 0 @ a (fn-join (split-ws (peep a 0 "")) (split-ws (peep a 1 ""))))
         "wordlist"  (: a (argl 0)
                               ws (split-ws (peep a 2 ""))
                               n1 (num1 (peep a 0 "")) n2 (num1 (peep a 1 ""))
                               (join " " (fn-slice ws n1 n2)))
         "foreach"   (: a (rawl 0)
                               v (trim (ex1 (peep a 0 "")))
                               body (peep a 2 "")
                               old (peep as v "")
                               r (join " " (map (w \ (pin as v (esc w), ex1 body))
                                                (split-ws (ex1 (peep a 1 "")))))
                               (pin as v old,              ; put the outer binding back
                                r))
         ; value/flavor read the variable without expanding it -- the one pair that must not ex1
         "value"     (trim (ex1 at) @ v (peep as v "" @ x
                        (peep flavors v "" = "simple" ? (strrep "$$" "$" x) x)))
         "flavor"    (peep origins (trim (ex1 at)) "undefined" @ o
                               (o = "undefined" ? "undefined" (peep flavors (trim (ex1 at)) "recursive")))
         ; a guard spelled $(error ..) must not vanish into an empty string. eval queues its
         ; text for the parse to splice behind the asking line, so it works nested
         "eval"      (peep as " parsing" 0 ? (pin as " evals" (ex1 at . peep as " evals" ()), "")
                        (cook-gap "$(eval ..) outside the parse"))
         "info"      (puts (ex1 at), putc 10, "")
         "warning"   (say err ("cook: " + ex1 at), put err 10, "")
         "error"     (say err ("cook: *** " + ex1 at + ".  Stop.\n"), quit 2)
         ""))                                   ; unknown -> empty, as make

   ; a group body is a function call ($(name args)), a substitution reference
   ; ($(VAR:from=to)), or a plain variable ($(VAR)).
   (eval-group body as d)
   (: sp (findws body)
      nm (snip body 0 (sp < #body ? sp #body))
      ; a bare $(file) is a variable (a foreach's loop name)
      ((sp < #body && any (= nm) gapnames ? (cook-gap ("$(" + nm + " ..)")) 0),
       (sp < #body && funcp (snip body 0 sp) ?
          (apply-func (snip body 0 sp) (ltrim (snip body (1 + sp) #body)) as d)
          (: eb (expand body as (1 + d)) ci (findc eb 0 58)
             (ci < #eb ? (subst-ref eb as d) (expand (peep as eb "") as (1 + d)))))))

   ; expansion: $(..) / ${..} groups, the single-char $V form (the automatics live in the
   ; table during recipe expansion), and $$ -> $. the runs between references are joined once,
   ; so a long value expands in linear time
   (expand s as d)
   (d > 100 ? s
      ((: (g i acc)
          (findc s i 36 @ k
             (k + 1 >= #s ? (join "" (rev (snip s i #s . acc)))
                (: pa (snip s i k . acc)
                   (s (1 + k) @ nx
                      (? (nx = 40 || nx = 123)
                         (: close (nx = 40 ? 41 125) j (findclose s (2 + k) nx close)
                            (g (1 + j) (eval-group (snip s (2 + k) j) as d . pa)))
                         (nx = 36) (g (2 + k) ("$" . pa))
                         (namech nx || nx = 64 || nx = 60 || nx = 94 || nx = 42 || nx = 63)
                         (g (2 + k) (expand (peep as (snip s (1 + k) (2 + k)) "") as (1 + d) . pa))
                         (g (1 + k) ("$" . pa))))))))
       0 ()))
   (expand-words ws as) (catmap (w \ split-ws (expand w as 0)) ws)
   ; a recipe line leading with the shell's `exec` runs through the exec nif, on the real tty
   (execp cmd) (ltrim cmd @ t (starts? t "exec" && (4 = #t || chws (t 4))))
   ; .SHELLFLAGS is a plain make variable; its default is make's own -c.
   (shflags as) (trim (peep as ".SHELLFLAGS" "") @ f (0 < #f ? (split-ws f) '("-c")))
   ; $(@D): the target's directory sans trailing slash ("." for a bare name), $(@F) its basename
   (dslash w) (lastslash w @ k (0 < k ? (snip w 0 (1 < k ? (k - 1) k)) "."))
   ; ..and SHELL picks the shell itself, $(shell) calls included; default sh.
   (shname as) (trim (peep as "SHELL" "") @ s (0 < #s ? s "sh"))
   ; a phony item is a symbol, and an automatic must read as its name either way
   ; build a card's steps: raws are recipe-parse's; the body expands now, the automatics
   ; pinned per item, into a sh-line thunk (an exec line: an (exec "sh" "-c" cmd) step)
   (itext x) (nom? x ? (show x) x)
   (expand-steps raws t pr stem as)
   (: pt (map itext pr)
       td (date t)
       ; $?: the prerequisites newer than the target, all when it is not on disk; a phony
       ; prerequisite is always newer
       nwr (filter (x \ (nom? x ? 1 (date x @ xd (!td ? (xd ? 1 0) (xd ? (xd > td) 0))))) pr)
       _ (pins as "@" (itext t) "<" (two? pt ? <pt "") "^" (join " " pt) "*" stem
                  "?" (join " " (map itext nwr))
                  "@D" (nom? t ? "." (dslash t)) "@F" (nom? t ? (show t) (fnotdir t)))
       fl (shflags as)
       sn (shname as)
       quiet? (0 < #(peep as ".SILENT" ""))
       ; make reads the @/-/+ modifiers after expansion too (the $(Q)-as-@ idiom). expand once:
       ; expanding twice runs every $(shell ..) twice
       exs (map (raw \ parse-mods (expand >>raw as 0)) raws)
       cmds (map cuup exs)
       ; .ONESHELL: one shell for the recipe, the first line's @/- governing the lot. an
       ; `exec` line wants a process of its own, so a recipe carrying one stays per-line.
       atom? (0 < #(peep as ".ONESHELL" "") &&
             two? raws && !(any execp cmds))
       (atom? ?
          (<raws @ r0
             (? (peep dryrun 0 0) [(_ \ (puts (join "\n" cmds), putc 10))]
                (peep emitp 0 0) [([sn] + fl + [(join "\n" cmds)])]
                [(_ \ sh-line <r0 <>r0 sn fl (join "\n" cmds))]))
          (: (g rs es acc)
              (!(two? rs) ? (rev acc)
                 (: raw <rs e <es
                    sil (<raw || <e || quiet?) ign (<>raw || <>e) cmd >>e
                    ; -n says the line and runs nothing, @ or not, as make
                    st (? (peep dryrun 0 0) (_ \ (puts cmd, putc 10))
                          (execp cmd)
                          (peep emitp 0 0 ? ('exec . [sn "-c" cmd])
                             (_ \ do-exec [sn "-c" cmd]))
                          (peep emitp 0 0) ([sn] + fl + [cmd])
                          (_ \ sh-line sil ign sn fl cmd))
                    (g >rs >es (st . acc))))
             (g raws exs ()))))

   ; -- conditionals & assignment ops over the variable table `as` --
   (unquote-str s) (#s >= 2 && (s 0 = 34 || s 0 = 39) ? (snip s 1 (#s - 1)) s)
   (cond-args rest)            ; ifeq/ifneq rest -> (arg1 . arg2)
   (trim rest @ t
      (0 < #t && t 0 = 40 ?
         (: cl (findclose t 1 40 41) parts (splittop (snip t 1 cl) 44)
            ((two? parts ? <parts "") . (two? >parts ? <>parts "")))
         (map unquote-str (split-ws t) @ ws
            ((two? ws ? <ws "") . (two? >ws ? <>ws "")))))
   (eval-ifeq rest as) (cond-args rest @ a (trim (expand <a as 0) = trim (expand >a as 0)))
   (eval-ifdef rest as) (0 < tally (expand (peep as (trim (expand rest as 0)) "") as 0))
   ; ov nonzero is `override`, the one assignment that beats a command-line VAR=VAL (which
   ; otherwise silences every file assignment to that name). an unfired ?= changes nothing.
   (do-assign as nm op val) (assign1 as nm op val 0)
   ; a value expanded already and expanded again later keeps its $ as $$
   (esc s) (strrep "$" "$$" s)
   ; the name is expanded first, as make does: mmu-$(CONFIG_MMU) := .. names mmu-y
   (assign1 as nm0 op val ov)
   (expand nm0 as 0 @ nm
   ; a caller of cook-vars names its own command line under " cl"
   (!ov && (peep origins nm "undefined" = "command line" || elem nm (peep as " cl" ())) ? 0
      ; a define's body is kept as written, its leading tab too
      (: v (op = "define" ? val (trim val))
         ; the flavor rides beside the origin: the value cannot answer $(flavor)
         (org f) (pin origins nm (ov ? "override" "file"), pin flavors nm f)
         (op @ "!="  (pin as nm (fn-shell as (expand v as 0)), org "simple")
               ":="  (pin as nm (esc (expand v as 0)), org "simple")
               "::=" (pin as nm (esc (expand v as 0)), org "simple")
               "?="  (peep as nm 'cook.undef @ cur
                      (nom? cur ? (pin as nm v, org "recursive") 0))
               ; onto a simple variable the value expands now, and it stays simple
               "+="  (: o (peep as nm "") f (peep flavors nm "recursive")
                        w (f = "simple" ? (esc (expand v as 0)) v)
                        (pin as nm (0 < tally o ? (o + " " + w) w), org f))
            (pin as nm v, org "recursive")))))

   ; -- fold classified lines into a rules list, mutating `as`. the conditional stack is a
   ; list of frames [pon taken active]; `on` is the top frame's active, 1 with none.
   (r1 c) <>c (r2 c) <>>c (r3 c) <>>>c
   (addstep cur st) (<cur . (<>cur . (st . >>cur)))
   (finalize cur) (<cur . (<>cur . rev >>cur))
   (flushr cur rules) (cur ? (finalize cur . rules) rules)
   (mkrule c)                  ; -> (TGTS-text PREREQS-text . STEPS-rev)
   ; an inline recipe is everything past the first `;`: `a:;x ; y` is one line
   (: prr (r2 c) sc (splittop prr 59)
      rec (two? >sc ? (join ";" >sc) "")
      inl (0 < tally (trim rec) ? [(parse-mods (trim rec))] 0)
      (r1 c . (<sc . inl)))
   ; an exported name: into the environment recipes inherit, and kept under " exports"
   (xport as nm)
    (setenv nm (expand (peep as nm "") as 0),
     peep as " exports" () @ xs (elem nm xs ? 0 (pin as " exports" (nm . xs))))
   ; an included file joins MAKEFILE_LIST before its lines are read
   (mklist as f) (peep as "MAKEFILE_LIST" "" @ l (pin as "MAKEFILE_LIST" (0 < #l ? (l + " " + f) f)))
   (condon cond) (two? cond ? <>><cond 1)
   (push-cond cond pon active) ([pon active active] . cond)
   ; `else ifeq ..` chains: the tail's test runs only while no earlier arm was taken
   (else-cond cond tail as)
    (: f <cond pon <f taken <>f
       q (0 < #tail ? (classify tail) 0)
       na (pon && !taken && (!q || cond-test q as))
       ([pon (taken || na) na] . >cond))
   (cond-test q as)
    (<q @ 'ifeq (eval-ifeq (r1 q) as)
          'ifneq !(eval-ifeq (r1 q) as)
          'ifdef (eval-ifdef (r1 q) as)
          'ifndef !(eval-ifdef (r1 q) as)
          (cook-gap ("else " + show <q)))
   ; the text $(eval ..) queued while the last line expanded, as lines, oldest first
   (evals-take as)
    (peep as " evals" () @ q (two? q ? (pull as " evals" 0, catmap text-lines (rev q)) ()))
   (build cls as)
   (pin as " parsing" 1,
    ((: (loop cs rules cur cond)
       (evals-take as @ more
          (? (two? more) (loop (more + cs) (flushr cur rules) 0 cond)
             !(two? cs) (pull as " parsing" 0, rev (flushr cur rules))
          (: c <cs k <c rest >cs on (condon cond)
             ; a tab-led line is a recipe only while a rule is open
             (k @ 'recipe (cur ? (loop rest rules (on ? (addstep cur (r1 c)) cur) cond)
                             (loop (classify (ltrim (r2 c)) . rest) rules cur cond))
                  ; a blank or comment line leaves the rule open
                  'skip   (loop rest rules cur cond)
                  'rule   (on ? (loop rest (flushr cur rules) (mkrule c) cond)
                                      (loop rest (flushr cur rules) 0 cond))
                  'assign ((on ? (do-assign as (r1 c) (r2 c) (r3 c)) 0), loop rest (flushr cur rules) 0 cond)
                  'oassign ((on ? (assign1 as (r1 c) (r2 c) (r3 c) 1) 0), loop rest (flushr cur rules) 0 cond)
                  'xassign ((on ? (assign1 as (r1 c) (r2 c) (r3 c) 0,
                                   xport as (expand (r1 c) as 0)) 0),
                            loop rest (flushr cur rules) 0 cond)
                  'xname   ((on ? (each (split-ws (expand (r1 c) as 0)) (n \ xport as n)) 0),
                            loop rest (flushr cur rules) 0 cond)
                  'inc    (on ? (catmap (f \ (mklist as f, file-lines f)) (split-ws (expand (r1 c) as 0)) @ more
                                         (loop (more + rest) (flushr cur rules) 0 cond))
                                      (loop rest (flushr cur rules) 0 cond))
                  'sinc   (on ? (catmap (f \ exists? f ? (mklist as f, file-lines f) ()) (split-ws (expand (r1 c) as 0)) @ more
                                         (loop (more + rest) (flushr cur rules) 0 cond))
                                      (loop rest (flushr cur rules) 0 cond))
                  'defassign ((on ? (do-assign as (r1 c) "define" (r2 c)) 0),
                              loop rest (flushr cur rules) 0 cond)
                  ; recur refuses a marked target if remade; " tvars" keeps (targets assignment)
                  'tvar ((on ? (expand (r1 c) as 0 @ ts
                                  (each (split-ws ts) (w \ pin tvarbox (unseat w) "1"),
                                   pin as " tvars" ([ts (r2 c)] . peep as " tvars" ()))) 0),
                         loop rest (flushr cur rules) 0 cond)
                  'expand ((on ? (expand (r1 c) as 0) 0), loop rest rules cur cond)
                  'ifeq   (loop rest rules cur (push-cond cond on (on && eval-ifeq (r1 c) as)))
                  'ifneq  (loop rest rules cur (push-cond cond on (on && !(eval-ifeq (r1 c) as))))
                  'ifdef  (loop rest rules cur (push-cond cond on (on && eval-ifdef (r1 c) as)))
                  'ifndef (loop rest rules cur (push-cond cond on (on && !(eval-ifdef (r1 c) as))))
                  'else   (loop rest rules cur (else-cond cond (trim (r1 c)) as))
                  'endif  (loop rest rules cur >cond)
                  (loop rest (flushr cur rules) 0 cond))))))
     cls 0 0 0))

   ; a define body must survive verbatim, which classify would not leave it
   (text-lines src)
    ((: (g l acc)
        (atom? l ? (rev acc)
           (trim (strip-comment <l) @ t
              (first-word t = "define" ?
                 (: nm (trim (after-word t))
                    ; the newline before endef is not the value's
                    (body r bs) (? (atom? r) (udie 2 "cook: define with no endef.  Stop.")
                                    (trim (strip-comment <r) = "endef") [>r (join "\n" (rev bs))]
                                    (body >r (<r . bs)))
                    p (body >l ())
                    (g <p (['defassign nm <>p] . acc)))
                 (g >l (classify <l . acc))))))
     (lines (uncont src)) ())

   (slurp-of path) (uread path @ [1 s] s (udie 1 "cook: cannot read \(path)"))
   (file-lines ip) (text-lines (slurp-of ip))

   ; seed the variable table as make does: the environment, then the builtin defaults, then the
   ; command line's VAR=VAL words. `.POSIX:` changes the defaults (CC c99, CFLAGS -O1), read off
   ; the raw source since defaults are seeded before parsing; a file's own CC= still wins.
   (posixp src)
   (any (l \ (trim (strip-comment l) @ t
                (7 <= #t && snip t 0 7 = ".POSIX:")))
        (lines src))
   (seed-defaults as px)
   (: _ (each (keys origins) (k \ pull origins k 0))       ; a fresh provenance per import
      ; ..except SHELL: the login shell never becomes the recipe shell
      _ (each (environ 0)
              (e \ (findc e 0 61 @ i
                      (i < #e ?
                         (snip e 0 i @ nm
                            (nm = "SHELL" ? 0
                               (pin as nm (sub e (1 + i) #e),
                                pin origins nm "environment")))
                         0))))
      (dflt nm v) (nom? (peep as nm 'cook.undef) ?
                     (pin as nm v, pin origins nm "default") 0)
      (dflt "CC" (px ? "c99" "cc"), (px ? (dflt "CFLAGS" "-O1") 0),
       dflt "MAKE" "make", dflt "AR" "ar", dflt "RM" "rm -f",
      ; CURDIR is read after -C
       dflt "CURDIR" (cwd 0 @ p (string? p ? p "")),
       dflt "AS" "as", dflt "ARFLAGS" "rv",
       each (clivars 0)
            (pr \ (pin as <pr >pr, pin origins <pr "command line")),
       as))

   ; old-style suffix rules: `.c.o:` is `%.o: %.c`, `.c:` is `%: %.c` -> (tgtpat srcpat) | 0.
   ; keyed on the suffix list, not a leading dot, or .PHONY with a recipe reads as one.
   sufs '("c" "cc" "C" "cpp" "S" "s" "o" "a" "h" "y" "l" "f" "F" "p" "r" "m" "sh")
   ; ..and a Makefile's own `.SUFFIXES`: bare it clears, with prerequisites it adds.
   sufbox {}
   (sufnow _) (peep sufbox 0 sufs)
   (sufknown x) (any (= x) (sufnow 0))
   (sufpat t)
   (#t @ n
      (n < 2 || t 0 != 46 ? 0
         (: (lastdot k r) (n <= k ? r (t k = 46 ? (lastdot (1 + k) k) (lastdot (1 + k) r)))
            d (lastdot 1 0)
            (d = 0 ?
               (sufknown (snip t 1 n) ? ["%" "%\(t)"] 0)
               (: sr (snip t 1 d) tg (snip t (1 + d) n)
                  (sufknown sr && sufknown tg ?
                     [("%." + tg) ("%." + sr)] 0))))))

   ; split a prereq word list at a `|` into (normal . order-only).
   (splitbar ws) ((: (g l acc) (atom? l ? [(rev acc)]
                       (<l = "|" ? (rev acc . >l) (g >l (<l . acc))))) ws ())

   ; parse a Makefile and register its rules: .PHONY members become symbols, every other item
   ; a file string; static pattern, implicit pattern (resolved at prep), or normal rules.
   (register-makefile src)
   (: as (seed-defaults {} (posixp src))
      rules (build (text-lines src) as)
      phony ({} @ ps
               (each rules (r \ expand-words [<r] as @ tg
                  (any (= ".PHONY") tg ?
                     (each (expand-words [<>r] as) (p \ pin ps p 1)) 0)), ps))
      ; .ONESHELL is a target, but expand-steps reads it from `as`
      _ (each rules (r \ (any (= ".ONESHELL") (expand-words [<r] as) ?
                            (pin as ".ONESHELL" "1") 0)))
      ; `.SUFFIXES` is read in file order before any rule asks sufpat
      _ (each rules (r \ (any (= ".SUFFIXES") (expand-words [<r] as) ?
                            (expand-words [<>r] as @ ws
                               (two? ws ?
                                  (pin sufbox 0 (sufnow 0 + map (w \ (0 < tally w && w 0 = 46 ?
                                                                          (snip w 1 #w) w)) ws))
                                  (pin sufbox 0 ())))
                            0)))
      ; .SILENT with no prerequisites quiets every recipe; a named one is not honoured
      _ (each rules (r \ (any (= ".SILENT") (expand-words [<r] as)
                          && 0 = #(trim <>r) ?
                            (pin as ".SILENT" "1") 0)))
      (mk-item nm) (peep phony nm 0 ? (intern nm) nm)
      patbox {}        ; implicit pattern rules: (tgtpat prs oos . raws)
      _ (each rules (r \
           (: tgtstext <r prtext0 <>r raws >>r
              ; `tgt:: ..`: ruleP eats one colon, so a second leading the prerequisites marks it
              pl (ltrim prtext0)
              dbl (0 < #pl && pl 0 = 58)
              prtext (dbl ? (snip pl 1 #pl) prtext0)
              tgts (expand-words [tgtstext] as)
              sp (two? raws ? (sufpat <tgts) 0)
              (? sp (pin patbox 0 ([<sp [<>sp] () raws] . peep patbox 0 ()))
                 ; drop the special targets; ./x and ../x are paths
                 (any (t \ 0 < tally t && t 0 = 46 && 0 = lastslash t) tgts) 0
                 (splittop prtext 58 @ cp
                    (two? >cp ?
                       (: tpat <(expand-words [<cp] as) ppats (expand-words [<>cp] as)
                          (each tgts (t \ (pmatch tpat t @ m
                             (two? m ? (: stem <m ping (map (pp \ stemsub pp stem) ppats)
                                          (reg (mk-item t) (map mk-item ping) 0 (expand-steps raws (mk-item t) ping stem as))) 0)))))
                       (: sb (splitbar (expand-words [prtext] as)) prs <sb oos >sb
                          (any haspct tgts ?
                             ; an empty recipe is make's cancellation: register nothing
                             (!(two? raws) ? 0
                                (each tgts (t \ (haspct t ? (pin patbox 0 ([t prs oos raws] . peep patbox 0 ())) 0))))
                             ; make expands $</$^ at run time over every line's prerequisites;
                             ; cook expands here, so prerequisites after their recipe read short
                             (each tgts (t \ (: it (mk-item t) ps (map mk-item prs)
                                                all (adds <(peep cards (unseat it) '(())) ps)
                                                ((dbl ? regd reg) it ps (map mk-item oos)
                                                     (expand-steps raws it all "" as)))))))))))))
      ; .DEFAULT_GOAL overrides the first rule declared
      dg (trim (peep as ".DEFAULT_GOAL" ""))
      _ (0 < #dg && pin check 0 (mk-item dg))
      patlist (peep patbox 0 ())
      ; make's builtin implicit rules: tried only after the file's own, and only where the
      ; stem-source exists, since `%: %.c` matches every word. a raw line is parse-mods' shape:
      ; a plain string would read as a recipe of no lines
      (bpat tgt prs cmd) [tgt prs () [(parse-mods cmd)]]
      builtpats
       [(bpat "%.o" '("%.c") "$(CC) $(CFLAGS) $(CPPFLAGS) -c -o $@ $<")
        (bpat "%.o" '("%.S") "$(CC) $(ASFLAGS) $(CPPFLAGS) -c -o $@ $<")
        (bpat "%.o" '("%.s") "$(AS) $(ASFLAGS) -o $@ $<")]
      ; no match-anything builtins (`%: %.c`, `%: %.o`): unfenced, `%: %.o` would hijack a real
      ; link with the one object beside the target. the %.o: rules want a target ending in .o.
      (psrc p item) (: stem <(pmatch <p item) prs <>p (two? prs ? (stemsub <prs stem) ""))
      ; a pattern whose source cannot be had (exists or has a card; no intermediates) does not
      ; apply; with none left the target is a source leaf
      (phave? p item) (psrc p item @ s (exists? s || two? (cards s)))
      (best-of ms item)        ; the shortest stem among the patterns that apply
      (filter (p \ phave? p item) ms @ ok
         (atom? ok ? 0
            (foldl (b \ p \ (!b ? p (#<(pmatch <p item) < #<(pmatch <b item) ? p b))) 0 ok)))
      (builtin-of item)        ; a builtin whose source is really there
      (filter (p \ two? (pmatch <p item) && exists? (psrc p item)) builtpats @ ms
         (best-of ms item))
      (resolve item)           ; a card from the best pattern rule, merging an explicit prereq-only one
      (: ms (filter (p \ two? (pmatch <p item)) patlist)
         best (best-of ms item @ b (b ? b (builtin-of item)))
         (best ?
            (: stem <(pmatch <best item)
               ping (map (pp \ stemsub pp stem) <>best)
               poo  (map (pp \ stemsub pp stem) <>>best)
               ex (peep cards item ())
               allp (ex ? (map mk-item ping + <ex) (map mk-item ping))
               oo   (ex ? (map mk-item poo + <>ex) (map mk-item poo))
               (allp . (oo . expand-steps <>>>best item ping stem as)))
            0))
      (pin pgen 0 resolve))

   ; -- emit: serialize the resolved cards back as a Cookfile ------------------
   ; with emitp set the cards hold fully expanded items and ("sh" "-c" cmd) steps. the default
   ; ticket is walked first so it stays the default; a pattern-only target prints nothing.
   (qshow x) ("'" + show x)
   ; write $HOME and $PWD back over the resolved prefixes; the cwd first, since it usually sits
   ; under the home. `reg` opens both again.
   (seat w)
   (string? w ?
      (: c (cwd 0) h (getenv "HOME")
         a (string? c && 1 < #c ? (strrep c "$PWD" w) w)
         (string? h && 1 < #h ? (strrep h "$HOME" a) a))
      w)
   (seatl l) (two? l ? (map seat l) l)
   (estep steps) (two? steps ? (qshow (map seatl steps)) "0")
   (emit-line o item ings oo steps)
   (: row (two? oo ?
             ["(reg" (qshow (seat item)) (qshow (two? ings ? (seatl ings) 0)) (qshow (seatl oo)) (estep steps)]
             ["(recipe" (qshow (seat item)) (qshow (two? ings ? (seatl ings) 0)) (estep steps)])
      (say o (join " " row), say o ")", put o 10))
   ; pre-order walk; `seen` keeps a shared prerequisite to one card. the lookup mirrors prep.
   (emit-walk o item seen)
   (peep seen item 0 ? 0
      (: _ (pin seen item 1)
         exr (peep cards item 'none)
         ex (two? exr ? exr 0)
         f (peep pgen 0 ())
         r (ex && two? >>ex ? ex
              (: g (f ? (f item) 0) (two? g ? g ex)))
         (two? r ?
            (: ings <r oo <>r steps >>r
               (emit-line o item ings oo steps,
                each ings (d \ emit-walk o d seen),
                each oo (d \ emit-walk o d seen), 0))
            0)))
   (emit-cookfile o)
   (: _ (say o "; generated by `cook --emit` from the Makefile -- do not edit by hand.") _ (put o 10)
       _ (say o "; the Makefile's $(shell)/$(wildcard)/vars/patterns are RESOLVED here; each") _ (put o 10)
       _ (say o "; recipe line became an (\"sh\" \"-c\" cmd) step. make's @ (silent) and -") _ (put o 10)
       _ (say o "; (ignore-error) line modifiers are not carried across.") _ (put o 10) _ (put o 10)
       seen {}
       dflt (check 0)
       ((dflt ? (emit-walk o dflt seen) 0),
        each (keys cards) (k \ emit-walk o k seen),
        say o "\n(cook-all 0)\ "))

   (mk-ends p suf) (: ls #suf lp #p (ls <= lp && suf = snip p (lp - ls) lp))
   (makefilep p) (pbase p @ ("Makefile" || "makefile" || "GNUmakefile") 1 (mk-ends p ".mk"))
   ; the love-recipe names: Cookfile, or anything .l
   (lovefilep p) (pbase p @ "Cookfile" 1 b (mk-ends p ".l"))
   ; -f names the makefile whatever it is called, unless it has a love-recipe name
   (asmake? p explicit?) (? explicit? !(lovefilep p) (makefilep p))

   (exists? p) (open p "r" @ q (hot? q ? (close q, 1) 0))
   ; its fd closed before any recipe could inherit it
   (slurp-close p) (: q (open p "r") s (slurp q) (close q, s))
   ; discovery precedence: Cards.l, then Cookfile, then Makefile.
   ; (a dummy param: a nullary (f) would be \ with one operand = quote.)
   (discover _) ((: (g ps) (two? ps ? (exists? <ps ? <ps (g >ps)) 0))
               '("Cards.l" "Cookfile" "Makefile"))

   ; empty the import books so a fresh build starts clean
   (clear-cards _) (each (keys cards) (k \ pull cards k 0), pull check 0 0, pull pgen 0 0, 0)
   ; transpile Makefile `mk` into Cookfile `ck`, then wipe the books to read it back clean
   (regen-cookfile mk ck)
   (: _ (pin emitp 0 1)
      _ (register-makefile (slurp-close mk))
      o (open ck "w")
    (emit-cookfile o,
     close o,
     pin emitp 0 0,
     clear-cards 0,
     say err "cook: \(ck) regenerated from \(mk)\n"))
   ; a Makefile newer than the Cookfile beside it refreshes it before discovery
   (autoregen _)
   (: tm (date "Makefile") tc (date "Cookfile")
      (tm && tc && tm > tc ? (regen-cookfile "Makefile" "Cookfile") 0))

   ; -- the command line ---------------------------------------------------------
   ; flags in any order, every non-flag word a recipe (see usage). a bare -j is this machine's
   ; width (jobauto), not make's unlimited, and does not travel: no jobserver.
   ; `cook <Makefile> [recipe]`: with no -f, a first positional naming an existing file is the
   ; build file only where discovery would find nothing else or that very file.
   (bye s) (puts s, putc 10, flush out, uleave 0)
   (version _) (bye (uvers "cook"))
   (usage _) (bye """
    usage: cook [-C DIR] [-f FILE] [-j [N]] [--emit] [-v] [-h] [VAR=VAL ...] [RECIPE ...]
      -C, --directory DIR  cook in DIR
      -f, --file FILE   the build file (Makefile or Cookfile); else discovered
      -j, --jobs [N]    run up to N recipes at once (default 1; bare -j = this machine)
          --emit        transpile a Makefile to a resolved Cookfile, then exit
      -v, --version     print the version and exit
      -h, --help        print this help and exit
      VAR=VAL           a command-line variable (silences the file's assignments)
      RECIPE ...        the items to build (default: the first recipe declared)
    a Makefile (Makefile/makefile/GNUmakefile/*.mk) is imported and cooked; any other build file is a Cookfile of ordinary love source.
    """)
   (need-arg h r) (two? r ? 0 (udie 2 "cook: \(h) needs an argument"))
   ; is this word the count, or the next argument? all digits and at least one.
   (jobword? w)
   (: n #w
      (go k) (? (n <= k) 1 (!(digitp (w k))) 0 (go (k + 1)))
      (0 < n && go 0))
   ; a file's lines, or () where there is none
   (jobfile p)
   (open p "r" @ q
      (!(hot? q) ? () (slurp q @ s (close q, lines s))))
   ; the leading number in a line, 0 where there is none: MemAvailable's kB field.
   (jobnum l)
   (: n #l
      (go k a seen) (? (n <= k) (seen ? a 0)
                       (digitp (l k)) (go (k + 1) (a * 10 + l k - 48) 1)
                       seen a
                       (go (k + 1) a 0))
      (go 0 0 0))
   ; a bare -j: half the cores plus one (width stops paying well before the last core, and each
   ; worker costs a mooncc heap), bounded by MemAvailable at 512 MB a job (one TU peaks near
   ; 350 MB). without MemAvailable the cores alone decide.
   (jobauto _)
   (: cpus (sysconf () @ (_ . _ . c . _) (charm? c ? c 0) 0)
      mls (jobfile "/proc/meminfo")
      free (!(two? mls) ? 0
              (foldl (a \ l \ (l @ ("MemAvailable:" + v) (jobnum v) a)) 0 mls))
      room (0 < free ? (free // 524288) 0)               ; kB -> 512 MB slots
      want (0 < cpus ? (cpus // 2 + 1) 0)
      n (? (0 = want) 1 (0 = room) want (room < want) room want)
      (0 < n ? n 1))
   ; a job count: all digits and above zero, or the run ends here
   (jobn w)
   (: n #w
      (go k a) (? (n <= k) a
                  (!(digitp (w k))) 0
                  (go (k + 1) (a * 10 + w k - 48)))
      v (0 < n ? (go 0 0) 0)
      (0 < v ? v (say err "cook: -j wants a job count, not \(w)",
                  put err 10, quit 2)))
   ; a NAME=VAL (or NAME:=VAL) word -> (name . val), or () for a plain word.
   (varw w)
   (findc w 0 61 @ i
      (i >= #w || 0 = i ? ()
         (: e (w (i - 1) = 58 ? (i - 1) i)
            (0 = e ? () (snip w 0 e . sub w (1 + i) #w)))))
   (parse-args ws)             ; -> a tablet: 'file 'dir 'jobs 'dry 'emit 'help 'ver 'var 'pos
   ((: (loop ws opt) (!(two? ws) ? opt
       (: w <ws r >ws
          (w @ ("-f" || "--file") (need-arg w r, pin opt 'file <r, loop >r opt)
             ("-C" || "--directory") (need-arg w r, pin opt 'dir <r, loop >r opt)
             ("-j" || "--jobs")
                (two? r && jobword? <r ? (pin opt 'jobs (jobn <r), loop >r opt)
                   (pin opt 'jobs (jobauto 0), loop r opt))
             ("-j" + _)
                                             (pin opt 'jobs (jobn (snip w 2 #w)), loop r opt)
             ("-n" || "--dry-run" || "--just-print")
                                                  (pin opt 'dry 1, loop r opt)
             "--emit"                                       (pin opt 'emit 1, loop r opt)
             ("-h" || "--help" || "help")      (pin opt 'help 1, loop r opt)
             ("-v" || "--version" || "version") (pin opt 'ver 1, loop r opt)
             ; make's -s is .SILENT for the run; the directory chatter flags are ignored
             ("-s" || "--silent" || "--quiet") (pin opt 'var (peep opt 'var () + [(".SILENT" . "1")]), loop r opt)
             ("--no-print-directory" || "-w" || "--print-directory") (loop r opt)
             (? (0 < #w && w 0 = 45))                     ; any other dash word is a flag
                                     (say err "cook: unknown option \(w)", put err 10, quit 2)
             (varw w @ vw
                (two? vw ? (pin opt 'var (opt 'var + [vw]), loop r opt)
                   (pin opt 'pos (opt 'pos + [w]), loop r opt)))))))
    ws {})

   ; -- cook-main: parse flags, find the build file, cook, answer the status (failure leaves by
   ; udie). the seat quits with it, so a -l preload's CLI never reads the file as love. a
   ; Cookfile is love read at runtime: its bare (recipe ..) (cook-all 0) resolve on the walk,
   ; so cook-main splices its own layer first.
   (cook-main as)
   (: _ (cite 'cook ? (borrow 'cook) 0)  ; the guard keeps the loader out
      ; ..and posix: a global name reads the live book, and this chain carries neither
      _ (borrow 'posix)
      opt (parse-args as)
      _ (peep opt 'help 0 ? (usage 0) 0)
      _ (peep opt 'ver 0 ? (version 0) 0)
      ; -C DIR: discovery, the build file and every recipe run there
      _ (peep opt 'dir 0 @ d
           (!d || !(nom? (chdir d)) ? 0
              (udie 2 "cook: cannot cd to \(d)")))
      _ (pin clivars 0 (opt 'var))
      _ (pin jobs 0 (peep opt 'jobs 1))
      ; ..and the width goes down the environment as a hint; no jobserver
      _ (setenv "COOKJOBS" (show (jobw ())))
      _ (pin dryrun 0 (peep opt 'dry 0))
      emit? (peep opt 'emit 0)
      pos (peep opt 'pos ())
      xf (peep opt 'file 0)
      _ (xf && !(exists? xf) ? (udie 1 "cook: cannot open \(xf)") 0)
      disc0 (xf ? 0 (discover 0))
      posfile (!xf && two? pos && exists? <pos && (disc0 ? (disc0 = <pos) 1) ? <pos 0)
      file (xf ? xf (posfile ? posfile (autoregen 0, discover 0)))
      (pin tickets 0 (posfile ? >pos pos),
       (? emit?
          ((file ? 0 (udie 1 "cook: --emit needs a Makefile")),
           pin emitp 0 1,
           register-makefile (slurp-close file),
           emit-cookfile out,
           0)
          file
          (slurp-close file @ s
             ((asmake? file xf ?
                 (register-makefile s, cook-all 0)
                 (sounds s @ 'torn (udie 1 "cook: unfinished form in \(file)")
                             fs (each fs (ev 'ev)))),
              0))
          (two? pos) (udie 1 "cook: no Cards.l, Cookfile or Makefile found")
          0)))

   ; make text read into the caller's tablet, the variable layer alone; answers the rules,
   ; unregistered, as (targets prereqs . steps) texts, for a reader that owns its graph.
   ; cook-expand reads a text against that tablet as make would
   (cook-vars src as) (build (text-lines src) as)
   (cook-expand s as) (expand s as 0)

   [cook-main cook-vars cook-expand])
   cook-main (cook-pubs 0)
   cook-vars (cook-pubs 1)
   cook-expand (cook-pubs 2))

; the seat: fire cook-main iff this file or the `cook` symlink is the program of the real
; command line (cmdline is the C argv, never rebound); inside kore nothing matches and kore's
; dispatcher calls cook-main itself.
(: _ (cite 'verbs 'enlist 'cook (urun cook-main) ())
   s (cite 'verbs 'fire ["cook" "cook.l"])
   (two? s ? (quit (urun cook-main >s))))

) ; module 'cook
