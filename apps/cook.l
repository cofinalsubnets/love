#!/usr/bin/env -S love -l
; cook -- love make
;
; love reads the `#!` line above as a line comment, so the same line serves the OS as a
; shebang and a library load is unaffected: `cook Cookfile [ticket]` execs
; `love -l <this-file> Cookfile [ticket]`, the -l loading cook before Cookfile runs.
; the verb is `cook`, never "bake" -- that word is the egg's (love/boot/egg.l).
;
; an item is brought up to date by prepping its prerequisites first (depth first), then
; running its recipe if the item is missing or older than any of them.
;
; (recipe item ingredients steps):
;   item -- a filename string, or a phony symbol ('all, 'clean ..) which owns no file,
;           so it has no age and always runs, cascading to everything that needs it.
;   ingredients -- a list of prerequisite items (strings and/or symbols).
;   steps -- each an argv list of strings run as a subprocess via `hark`, or a thunk
;           (any lit?) called as (step 0). an empty list is legal (a pure aggregate).
; a missing file and a phony item both read as the zero point (): ageless, hence ancient,
; hence always rebuilt. the first recipe declared is the default ticket, as in make.
;
; usage:  cook [-f file] [--emit] [recipe ..]  (with the symlink installed)
;     or:  love -l apps/cook.l [-f file] [recipe ..]
; a Cookfile is ordinary love source laying out recipes then driving them: (cook-all 0)
; builds every recipe named on the command line, (cook (ticket 0)) just the first. only a
; file named like a Makefile (makefilep) is read as make; every other recipe file is love
; source. the first rule is the default ticket either way.

; every lane rides module 'cook: a consumer says (borrow 'cook) or probes (cite 'cook 'recipe).
; riding a cat the wrap registers the same module, so the ~30 globals (`join` `date` `check`
; `shell` among them) stay off the cat's session layer too.
(module 'cook

; the combinators (love/boot/post.l), the wrap's first form so the names walk before
; anything below compiles against them, scoped to this module's compile.
(borrow 'peg)

(borrow 'posix)

; the pattern law and the path clips both (love/boot/post.l): match/anyglob under
; $(wildcard), lastslash/lastdot/segs/pclean under make's own $(dir) family.
(borrow 'glob)
(borrow 'path)

(: cards (tablet 0)          ; the recipe cards: item -> (ingredients orderonly . steps)
   check (tablet 0)        ; a 1-cell box: the standing check -- the first item declared (the default when no ticket is named)
   tickets (tablet 0)      ; a 1-cell box: the recipe words named on the command line (the non-flag args), () until the dispatch parses them
   pgen (tablet 0)         ; a 1-cell box: a pattern-rule resolver (item -> a card | 0), installed by the Makefile importer (() until then)
   cookbox (tablet 0)      ; a 1-cell box: the in-image shell verdict (sh-line's `inimg`), decided once a run
   jobs (tablet 0)         ; a 1-cell box: the -j width (1 = serial, and nothing forks)
   dryrun (tablet 0)       ; ..and one for -n: set, every step is said and none is run
   running (tablet 0)      ; pid -> the item whose recipe that job is running
   verdicts (tablet 0)     ; pid -> the status a reaped job answered, until its land takes it

   origins (tablet 0)      ; $(origin): name -> "default" | "environment" | "file" |
                           ; "command line" | "override"; a file assignment never beats a command-line one
   flavors (tablet 0)      ; $(flavor): name -> "simple" | "recursive" -- := expands at assign
                           ; time and = stores the text, so the value itself cannot say which
   clivars (tablet 0)      ; a 1-cell box: the command line's VAR=VAL words, ((name . val) ..)

   ; "a b c" from ("a" "b" "c"); "" from the empty list.
   (join sep l) (? (two? l) (foldl (\ a x (a + sep + x)) <l >l) "")

   ; register one card, merging with any prior one for the same item: prereqs accumulate
   ; (deduped -- a caller who re-registers the same recipe would otherwise grow the card
   ; without bound) and a later non-empty recipe wins, as make does. the first item ever
   ; registered is the default ticket. card = (ingredients orderonly . steps); orderonly
   ; prereqs are built-if-missing but never make a target stale (make's `| prereqs`).
   (adds a b) (foldl (\ acc x (? (elem x acc) acc (acc + [x]))) a b)
   ; a leading $HOME or $PWD in an item or a prereq opens here, at registration. step strings
   ; want none of it -- sh -c expands them itself; a non-string item is phony and rides through.
   (unpre w tok val)
   (: n #tok
      (? (string? val && #w >= n && tok = snip w 0 n)
         (val + snip w n #w) w))
   (unseat w) (!(string? w) ? w (unpre (unpre w "$HOME" (getenv "HOME")) "$PWD" (cwd 0)))
   (unseatl l) (one? l ? l (map unseat l))
   (reg item ing oo steps)
   (: at (unseat item) ins (unseatl ing) ors (unseatl oo)
      prev (cards at)
      (? prev
         (pin cards at (adds <prev ins .  adds <>prev ors .  (two? steps ? steps >>prev)))
         (pin cards at (ins . ors . steps),
          peep check 0 0 ? 0 (pin check 0 at),
          at)))
   ; `tgt:: ..` is the one place a second recipe does not replace the first: make runs every
   ; such rule's steps, in the order written. reg's rule -- a later recipe wins -- is `:`'s.
   ; the targets carrying a target-specific variable -- see classify. recur asks.
   tvarbox {}
   (regd item ing oo steps)
   (: at (unseat item) ins (unseatl ing) ors (unseatl oo)
      prev (cards at)
      (? prev (pin cards at (adds <prev ins . adds <>prev ors . >>prev + steps))
         (reg item ing oo steps)))
   ; the public Cookfile API: (recipe item ingredients steps) -- no order-only prereqs.
   (recipe item ingredients steps) (reg item ingredients 0 steps)

   ; the item's mtime in nanoseconds (the stat nif's fourth element -- sub-millisecond, so two
   ; writes inside one tick still order), or () for a phony item or a file not on disk.
   (date item)
   (nom? item ? () (: st (stat item) (two? st ? <>>>st))))

; --- prepping an item up to date ---------------------------------------------
; `done` memoizes each item's settled age, so a shared prerequisite is visited once, and
; `shipped` records the items whose recipe advanced their file's mtime, so a rebuilt
; prerequisite forces its dependents even where the clock granularity would hide it.

(: (prep item done shipped pending)
   (? (done item) (done item) ; settled already
      (two? (pending item)) ()                       ; a job is up for it; landing it settles it
      ; an explicit recipe wins outright; else a pattern rule may synthesize a card (merging
      ; any explicit prereq-only one), else that card, else nothing (a source leaf). presence
      ; is `two?`, never truthiness: an all-empty card (() ()) nets 0, and a phony aggregate
      ; with no prereqs is exactly that.
      (: exr (peep cards item 'none)
         ex (two? exr ? exr 0)
         f (pgen 0)
         r (? (ex && two? >>ex) ex
              (: g (? f (f item) 0) (? (two? g) g ex)))
         (? (two? r)
            ; prepping and landing are two passes, and that is the whole of -j: prep leaves a
            ; stale prerequisite's recipe running so the next one's subtree starts beside it,
            ; and only the second pass waits, since an age cannot be read off a file still
            ; being written. at -j1 nothing is left running and the two read as one walk.
            (: ingredients <r orderonly <>r steps >>r
               _ (each ingredients (d \ prep d done shipped pending))
               _ (each orderonly (d \ prep d done shipped pending))  ; order-only: built if missing, never makes us stale
               ; a pure aggregate owes no age, so it need not wait here -- and waiting puts a
               ; phony's whole subtree in front of the sibling beside it. park the land under
               ; the item instead: the parent calls jobland on the way past, so every job comes home.
               (? (one? steps)
                  (: _ (pin pending item (. 'agg (. (ingredients + orderonly) ()))) ())
                  (: _ (each ingredients (\ d (jobland d done shipped pending)))
                     _ (each orderonly (\ d (jobland d done shipped pending)))
                     ta0 (date item)
                     fresh (any shipped ingredients)   ; a prerequisite's file changed
                     older (any (\ d (: da (done d)     ; a prerequisite is newer
                                        (? !da 1 (? !ta0 1 (da > ta0))))) ingredients)
                     stale (!ta0 || fresh || older)
                     ; run the recipe when stale -- as a job where there is room to fork
                     ; one, else right here. a job's item settles when it lands;
                     ; everything else settles now.
                     j (? stale (jobstart item steps) 0)
                     (? j (: _ (pin pending item (j . ta0 . steps)) ta0)
                          (settle item ta0 (stale ? steps) done shipped)))))
            ; no card: a source leaf. it must already exist on disk.
            (: ta (date item)
             (ta ? 0 (say err $ "cook: no recipe to make " + show item + "\n", quit 1),
              pin done item ta,
              ta)))))

   ; read the item's age and pin it, marking shipped only where the recipe advanced the file's
   ; mtime, so a no-op rebuild does not force dependents. `steps` is () when no recipe ran.
   (settle item ta0 steps done shipped)
   (: nw (date item)
      _ (? (two? steps && (? !ta0 (? nw 1 0) (? nw (nw > ta0) 0)))
           (pin shipped item 1) 0)
      _ (pin done item nw)
      nw)

   ; a prerequisite's job must land before its age can be read; () for an item that never took
   ; one, which is every item at -j1. landing an aggregate lands the prerequisites it parked,
   ; and the pull leads, so a card that reaches itself cannot circle.
   (jobland item done shipped pending)
   (: v (peep pending item 0)
      (? (one? v) ()
         (= <v 'agg) (: _ (pull pending item 0)
                        _ (each <>v (d \ jobland d done shipped pending))
                        (settle item () () done shipped))
         (: st (jobwait <v)
            _ (pull pending item 0)
            _ (0 != st && jobdie item st)
            (settle item <>v >>v done shipped))))

   ; each step in order -- but a target-specific variable (classify's 'tvar) is refused here
   ; and not at parse, which would refuse a Makefile over a scope no build ever enters.
   (recur item steps)
   (: k (unseat item)
      nm (string? k ? k (show k))
      _ (? #(peep tvarbox k "")
           (say err $ "cook: target-specific variable (" + nm + ") not implemented.\n",
            quit 2))
      (each steps step1))

   ; --- the job pool (-j N) --------------------------------------------------
   ; a stale recipe runs in a forked child -- the fork nif, no exec -- so a job's only outputs
   ; are the files it wrote and the status it answered, which is make's whole contract for a
   ; recipe. a thunk step's heap effect lands in the child, so a Cookfile that builds by
   ; mutating cook's own tables wants -j1, and gets it by default.
   ; every name here is job-prefixed: this scope leaks into the layer the expander walks,
   ; where `join` and `start` already mean other things.
   (jobw _) (: n (peep jobs 0 1) (? (0 < n) n 1))

   ; an (exec ..) step replaces the process, so a recipe carrying one can never be a
   ; job: the child would be replaced and cook would carry on as if it had run.
   (jobforkable? steps) (!(any (\ s (two? s && (<s = 'exec))) steps))

   ; answers the job's pid, which the caller must land before reading the item's age, or 0 when
   ; it ran here. the serial lane drains first: a recipe run here calls herald, which waits on
   ; its own child, and `glean` reaps any child, so the two must never be in the air at once.
   (jobstart item steps)
   (? (!(two? steps)) 0                                     ; a pure aggregate runs nothing: no job, and no drain either
      (!((1 < jobw ()) && (jobforkable? steps))) (: _ (jobdrain 0) _ (recur item steps) 0)
      (: _ (? (jobw () <= #running) (jobreap 0) 0)          ; wait for a slot
         _ (flush out) _ (flush err)
         p (fork 0)
         (? (0 = p) (: _ (recur item steps) (quit 0))       ; the child: run it and go
            (0 < p) (: _ (pin running p item) p)
            (: _ (recur item steps) 0))))

   ; reap one job and file its verdict under its pid, so whichever land wants it finds it however
   ; the reaps fall. `glean` is waitpid(-1, WNOHANG), so the wait is a poll and `rest` parks it.
   (jobreap _)
   (: r (glean 0)
      (? (two? r) (: _ (pin verdicts <r >r) _ (pull running <r 0) <r)
         (charm? r) ()                                      ; -errno: no children left
         (: _ (rest 1) (jobreap 0))))

   ; this pid's status, reaping as needed. a pid neither filed nor running was reaped by
   ; something that is not this pool and its verdict is gone, which is not a green one.
   (jobwait p)
   (: v (peep verdicts p 'no)
      (? !(= v 'no) (: _ (pull verdicts p 0) v)
         (0 = #running) (: _ (say err ("cook: lost the job for pid " + show p))
                            _ (put err 10) (quit 1))
         (: _ (jobreap 0) (jobwait p))))

   (jobdrain _) (? (0 < #running) (: _ (jobreap 0) (jobdrain 0)) 0)

   ; the child already said which command failed and with what status; this adds the item.
   ; outstanding jobs are let finish, as make does: a half-written file left behind by a kill
   ; would read as up to date on the next run.
   (jobdie item ec)
   (jobdrain 0,
    say err $ "cook: the recipe for " + show item + " failed\n",
    quit ec)

   ; (exec PROG ARGS..) is the interactive step: the exec nif replaces cook and inherits the
   ; terminal, so the child drives the real tty. a plain list of strings is an argv subprocess
   ; -- streamed, but on a pipe with /dev/null stdin, so it cannot be interactive; else a thunk.
   (step1 step)
   (? (two? step && <step = 'exec) (do-exec >step)     ; (exec ..) -- the interactive step
      (two? step) (shell step)
      (lit? step) (step 0))

   ; exec the argv, replacing this process (tty inherited). the exec nif returns only on
   ; failure -- then -errno -- so anything past it is the error path.
   (do-exec argv)
   (flush out,
    exec argv,
    say err $ cats ["cook: cannot exec " (join " " argv) "\n"],
    quit 1)

   ; echo the argv, run it streaming (herald relays each chunk as it arrives), abort on failure.
   ; the flush is load-bearing: herald writes the child's bytes past the `out` buffer, so an
   ; unflushed echo would land after them.
   (shell step)
   (: _ (puts ("  " + join " " step)) _ (putc 10)
       _ (flush out)
       r (herald step)
       (? (two? r)
          (? (0 = <r) 0
             (: _ (say err ("cook: command failed (exit " + show <r + ")"))
                _ (put err 10) (quit 1)))
          (: _ (say err ("cook: cannot run " + join " " step))
             _ (put err 10) (quit 1))))

   ; the in-image shell, decided once and kept: where the shell we would spawn is the binary
   ; already running, the recipe line runs here -- one image wake for a whole make instead of
   ; one per line. asked through the module, never by a bare reference: cook runs standalone
   ; too (`love -l apps/cook.l`), where lush's engine is not aboard and the from-reads answer
   ; () -- the spawn lane, unchanged. the policy is lush's, not ours.
   (inimg sh)
   (: v (peep cookbox 'inimg 'no)
       (? !(= v 'no) v
          (: ours (cite 'lush 'sh-ours?) one (cite 'lush 'sh-oneline)
             f (? ((lit? ours) && (lit? one) && (ours sh)) one 0)
             _ (pin cookbox 'inimg f)
             f)))

   ; one make recipe line via SHELL -c: echo the raw command (the expanded line, not the shell
   ; wrapper) unless @ silent, stream its stdout (a recursive $(MAKE) rides this, which is why
   ; it must stream), and on a nonzero exit carry on (- ignore) or abort. the in-image door goes
   ; first and answers (1 status) when it took the line; a () falls through to the spawn.
   (sh-line silent ignore sh flags cmd)
   (: _ (? silent 0 (puts cmd, putc 10))
       _ (flush out)
       f (inimg sh)
       o (? f (f flags cmd) ())
       r (? (two? o) [<>o] (herald (([sh] + flags) + [cmd])))
       ec (? (two? r) <r -1)
       (? (0 = ec) 0
          !(two? r) (: _ (say err ("cook: cannot run " + cmd)) _ (put err 10) (quit 1))
          ignore (say err $ "cook: " + cmd + " (exit " + show ec + ", ignored)\n")
          (say err $ "cook: command failed (exit " + show ec + ")\n", quit 1))))

; --- the entry points ----------------------------------------------------------

; prep item up to date quietly, answering the tablet of items whose recipe advanced their file.
; a caller that wants the number tallies it -- a tablet nets 1, like the lambda it is.
(: (prepped item)
   (: done {} shipped {} pending {}
      _ (prep item done shipped pending)
      _ (jobland item done shipped pending)       ; the top item's own job, if it took one
      shipped)

   (cook item)                                ; prep item up to date and report
   (? !item (say err "cook: nothing to cook\n", quit 1)
      (: shipped (prepped item)
         ; a run that built something says nothing, as make does: the recipes tag themselves
         (? (0 < #shipped) 0
            (puts $ "cook: " + show item + " is already up to date\n"))))

   ; a command-line word -> an item: the bare string for a file recipe (explicit or from a
   ; pattern rule), the interned symbol for a phony one, a file that is there as itself, else a
   ; refusal -- never the default, which would cook the whole tree behind a typo.
   (pick a) (? (cards a) a
               (: s (nom a)
                  f (pgen 0)
                  g (? f (f a) 0)
                  (? (cards s) s
                     (two? g) a
                     (date a) a
                     (say err $ "cook: no recipe to make " + show a + "\n", quit 1))))

   ; the first recipe word named on the command line (the `tickets` box), else the default.
   ; (ticket 0) reads it live, so a Cookfile's own (cook (ticket 0)) sees the args.
   (ticket _) (: ts (tickets 0) (two? ts ? (pick <ts) (check 0)))

   ; cook every recipe word named on the command line (make foo bar), or the default
   ; when none were named. drives the Makefile path; a Cookfile drives itself.
   (cook-all _) (: ts (tickets 0)
                (two? ts ? (each ts (cook * pick)) (cook (check 0)))))

; --- importing a Makefile ------------------------------------------------------
; a parser is (\ s y n) over a string s: y the success continuation (rest parsed), n the
; failure continuation (rest); the parsed payload is a list `seq` concatenates. love has no
; regex, so the leaves are `lit` (a literal prefix), `one` (one char by predicate) and `span`
; (a maximal run), with alt/seq/opt/many over them. the import is reasonably GNU-compatible:
; recursive $(VAR) and substitution refs, the common functions, ifeq/ifdef, `include`, the
; = := ?= += flavors, pattern and static-pattern rules, order-only prereqs and the $@ $< $^ $*
; automatics; each recipe line runs via ("sh" "-c" line). see test/host/cook.l.
;
; $(wildcard) prefers pure love: lush's glob (apps/lush.l, the mask law) over readdir/stat, so
; `kore make` globs before a shell exists; where it is not aboard globw below keeps the POSIX
; shell-out lane. the probe names sh-line and not the module: module 'lush starts at the floor
; in love/boot/post.l, so its presence says nothing about the shell itself being aboard.
(? (lit? (cite 'lush 'sh-line)) 0
   (two? (stat "apps/lush.l")) (borrow "apps/lush.l")  ; the file that carries the shell half
   0)
; the pathname glob: a closure when lush's glob is aboard, () when not (a from-read miss),
; and the importer then keeps its POSIX shell-out lane.
(: cook-glob (: g (cite 'lush 'sh-glob) o (cite 'lush 'sh-ones)
                (lit? g && lit? o ? (pat \ g pat (o #pat)))))

; the whole importer lives in one body-having `:`, so none of its many helper names leak; it
; reads the outer globals freely and its body answers cook-main (args -> the whole job, exiting
; via quit). the outer `_`-holder leaks cook-main as the one public -- the multi-call `kore`
; calls it as `make` -- and the seat at the bottom fires it when this file was invoked.
(: _ (:
   ; --emit: when set, expand-steps emits a serializable ("sh" "-c" cmd) step instead of a
   ; sh-line thunk, so the resolved cards can be shown back as a Cookfile (emit-cookfile below).
   emitp (tablet 0)

   ; -- eps/lit/one/span/alt/seq/seqs/opt/skip/pmap/many/parse come from (borrow 'peg) above,
   ;    read bare down this body-having `:`.

   ; -- character classes and string utilities --
   (chws (32 || 9)) 1
   (digitp c)   (48 <= c <= 57)
   (alphap c)   (65 <= c <= 90 || (97 <= c <= 122))
   (namech c)   (alphap c || digitp c || c = 95 || c = 46)
   ; notcolon admits whitespace: a rule's target text runs to the first colon, and
   ; `a.out b.out: src` is one rule with two targets. assignP runs first, so assignment lines
   ; never reach this span.
   (notcolon c) (c != 58)
   (anyc c)     1
   (ltrim s) (: i ((: (g j) (j < #s && chws (s j) ? (g (1 + j)) j)) 0)
               (snip s i #s))
   (rtrim s) (: i ((: (g j) (0 < j && chws (s (j - 1)) ? (g (j - 1)) j)) #s)
               (snip s 0 i))
   (trim s)  (rtrim (ltrim s))
   (findc s i ch) (? (i >= #s) i (? (s i = ch) i (findc s (1 + i) ch)))
   (split-ws s)
   ((: (g i st acc)
       (? (i >= #s) (rev (st < i ? (snip s st i . acc) acc))
          (? (chws (s i))
             (g (1 + i) (1 + i) (st < i ? (snip s st i . acc) acc))
             (g (1 + i) st acc))))
    0 0 0)

   ; fold \<newline> continuations -- make has two rules. off a recipe, `<ws>*\<newline><ws>*`
   ; is one space and the whitespace either side goes with it; in a recipe the join is the
   ; shell's, so the backslash-newline goes entirely and only the continuation's leading tab is
   ; eaten. a recipe is decided by the first physical line, so the flag survives every fold.
   (rtws s) (: i ((: (g j) (? ((0 < j) && ((s (j - 1) = 32) || (s (j - 1) = 9))) (g (j - 1)) j))
                  #s)
               (snip s 0 i))
   (uncont s)
   ((: (g i acc rec bol)
       (? (i >= #s) acc
          (: c (s i)
             (? (c = 92 && 1 + i < #s && s (1 + i) = 10)
                (? rec (: j (2 + i) (g (j < #s && s j = 9 ? (1 + j) j) acc rec 0))
                   (: j ((: (h k) (k < #s && (s k = 32 || s k = 9) ? (h (1 + k)) k))
                         (2 + i))
                      (g j (rtws acc + " ") rec 0)))
                (c = 10) (g (1 + i) (acc + "\n") rec 1)
                (g (1 + i) (acc + string c) (? bol (c = 9) rec) 0)))))
    0 "" 0 1)
   (lines s)
   ((: (g i st acc)
       (? (i >= #s) (rev (snip s st i . acc))
          (? (s i = 10) (g (1 + i) (1 + i) (snip s st i . acc))
             (g (1 + i) st acc))))
    0 0 0)

   ; -- string utilities for the make layer --
   (findc-ws s i) (? (i >= #s) i (? (chws (s i)) i (findc-ws s (1 + i))))
   (first-word s) (snip s 0 (findc-ws s 0))
   (after-word s) (ltrim (snip s (findc-ws s 0) #s))
   (lastl l) (two? >l ? (lastl >l) <l)
   ; `sub` is snip with the ends ordered: "" when start >= end.
   (sub s a b) (a < b ? (snip s a b) "")
   ; strip a make comment (an unescaped #) from a non-recipe line; \# is a literal #.
   (strip-comment l)
   ((: (g i acc)
       (? (i >= #l) acc
          (: c (l i)
             (? (c = 35) acc                                  ; 35 = #
                (c = 92) (? (1 + i < #l)               ; 92 = backslash
                            (: d (l (1 + i)) (d @ 35 (g (2 + i) (acc + "#")) (g (2 + i) (acc + "\\" + string d))))
                            (acc + "\\"))
                (g (1 + i) (acc + string c))))))
    0 "")
   ; split on a top-level `ch`: parens and braces balance, so a delimiter inside $(..) / ${..}
   ; does not split (function args, the static-pattern colon).
   (splittop s ch)
   (:- (g 0 0 0 0)
    (g i depth st acc)
     (i >= #s ? (rev (snip s st i . acc))
      (s i @ (40 || 123) (g (1 + i) (1 + depth) st acc)
             (41 || 125) (g (1 + i) (depth - 1) st acc)
             (^ch && depth = 0) (g (1 + i) depth (1 + i) (snip s st i . acc))
             (g (1 + i) depth st acc))))

   ; -- the line grammar: NAME OP VALUE (op kept) and a rule header (raw text) --
   ; `!=` runs its value and takes the output, the portable spelling of $(shell ..): bmake and
   ; GNU both read it, where neither reads the other's conditionals.
   opP (alt (lit "::=") (alt (lit ":=") (alt (lit "?=") (alt (lit "+=") (alt (lit "!=") (lit "="))))))
   assignP (seqs [(skip (span chws)) (span namech)
                   (skip (span chws)) (pmap (\ x [<x]) opP)
                   (skip (span chws)) (span anyc)])
   ruleP (seqs [(skip (span chws)) (span notcolon) (skip (lit ":")) (span anyc)])

   ; classify a line -> (recipe TEXT) | (assign NAME OP VAL) | (rule TGTS PREREQS)
   ; | (inc TEXT) | (ifeq|ifneq|ifdef|ifndef|else REST) | (endif) | (skip).
   (recipep l)  (0 < #l && l 0 = 9)
   ; strip the leading run of @ - + modifiers and any whitespace between them, recording @
   ; (silent) and - (ignore-error) -> (silent ignore . body). + (force) is a no-op here, so it
   ; is stripped without a flag. (64 = @, 45 = -, 43 = +.)
   (parse-mods s)
   ((: (g i sil ign)
       (? (i < #s && (chws (s i) || s i = 64 || s i = 45 || s i = 43))
          (g (1 + i) (sil || s i = 64) (ign || s i = 45))
          (sil . ign . snip s i #s))) 0 0 0)
   (recipe-parse l) (parse-mods (snip l 1 #l))   ; drop the leading tab, then the modifier run
   (classify l)
   (? (recipep l) ['recipe (recipe-parse l)]
      (: t (strip-comment l) tt (trim t)
         (? (0 = #tt) '(skip)
            (: w (first-word tt) rest (after-word tt)
               (? (w = "include") ['inc rest]
                  (w = "-include") ['inc rest]
                  (w = "sinclude") ['inc rest]
                  ; `override NAME op VAL` assigns past a command-line VAR=VAL;
                  ; `export NAME [op VAL]` assigns (when an op is there) and hands the
                  ; final value to the process environment, so recipes inherit it.
                  (w = "override") (: a (parse assignP rest) (? (two? a) ('oassign . a) '(skip)))
                  (w = "export") (: a (parse assignP rest)
                                    (? (two? a) ('xassign . a) ['xname (trim rest)]))
                  ; a lone $(..) line -- the whole line, its closer last -- is expanded for
                  ; its side effect, since `$(error ..)` is a guard. a line that merely begins
                  ; with $( stays an ordinary rule or assignment named by a variable:
                  ; `$(outs): %.out: %.in` is a static pattern rule.
                  (1 < #tt && tt 0 = 36
                   && (? (tt 1 = 40) ((findclose tt 2 40 41) = (#tt - 1))
                         (tt 1 = 123) ((findclose tt 2 123 125) = (#tt - 1))
                         0))
                    ['expand tt]
                  (w = "undefine" || w = "vpath") (cook-gap w)
                  (w = "ifeq") ['ifeq rest]
                  (w = "ifneq") ['ifneq rest]
                  (w = "ifdef") ['ifdef rest]
                  (w = "ifndef") ['ifndef rest]
                  (w = "else") ['else rest]
                  (w = "endif") '(endif)
                  (: a (parse assignP t)
                     (? (two? a) ('assign . a)
                        (: r (parse ruleP t)
                           ; `tgts: NAME op VALUE` is a target-specific variable, and read as
                           ; a rule it invents a prerequisite named for the variable. cook keeps
                           ; one variable table and cannot scope one to a target, so it is
                           ; recorded against its targets and refuses only if one is remade.
                           (? !(two? r) '(skip)
                              (two? (parse assignP <>r)) ['tvar <r]
                              ('rule . r))))))))))

   ; -- nested-paren-aware variable expansion + make functions --
   ; the index of the ) that matches the ( just opened, counting nested $(..).
   (findclose s i open close)
   (:- (g i 0) (g j depth)
     (j >= #s ? j
        (: c (s j)
           (? (c = open) (g (1 + j) (1 + depth))
              (c = close) (? (0 = depth) j (g (1 + j) (depth - 1)))
              (g (1 + j) depth)))))

   ; $(VAR:from=to) on one word: with a % it is a pattern (prefix%suffix) whose stem fills the
   ; % in `to`, without one a trailing-text replacement (.o=.c). a non-match passes through.
   (patsub frm to w)
   (: pi (findc frm 0 37)                                    ; 37 = %
      (? (pi < #frm)
         (: pre (sub frm 0 pi) suf (sub frm (1 + pi) #frm)
            lp #pre ls #suf lw #w
            (? (lw >= lp + ls && pre = sub w 0 lp && suf = sub w (lw - ls) lw)
               (: stem (sub w lp (lw - ls)) ti (findc to 0 37)
                  (ti >= #to ? to (sub to 0 ti + stem + sub to (1 + ti) #to)))
               w))
         (: lf #frm lw #w
            (? (lw >= lf && frm = sub w (lw - lf) lw) (sub w 0 (lw - lf) + to) w))))

   ; substitute the stem into a pattern prereq (./%.c -> ./<stem>.c); no %, no change.
   (stemsub p stem) (: pi (findc p 0 37)
                       (? (pi < tally p) (sub p 0 pi + stem + sub p (1 + pi) #p) p))
   ; match a pattern (one %) against a string -> (stem) | () ; no % -> exact match.
   (pmatch pat s)
   (: pi (findc pat 0 37)
      (? (pi >= #pat) (? (pat = s) '("") ())
         (: pre (snip pat 0 pi) suf (snip pat (1 + pi) #pat)
            lp #pre ls #suf ls2 #s
            (? (ls2 >= lp + ls && pre = snip s 0 lp && suf = snip s (ls2 - ls) ls2)
               [(snip s lp (ls2 - ls))] ()))))
   (haspct t) (findc t 0 37 < #t)
   (matchany pats w) (any (p \ two? (pmatch p w)) pats)

   (subst-ref eb as d)         ; VAR:from=to (already inner-expanded)
   (: ci (findc eb 0 58) nm (sub eb 0 ci)                    ; 58 = :
      spec (sub eb (1 + ci) #eb)
      ei (findc spec 0 61) frm (sub spec 0 ei)               ; 61 = =
      to (sub spec (1 + ei) #spec)
      v (expand (peep as nm "") as (1 + d))
      (join " " (map (patsub frm to) (split-ws v))))

   ; -- function helpers --
   (chomp s) ((: (g i) (? (0 < i && s (i - 1) = 10) (g (i - 1)) (snip s 0 i))) #s)
   (nl->sp s) ((: (g i acc) (i >= #s ? acc (g (1 + i) (acc + string (s i @ 10 32 (s i)))))) 0 "")
   (fn-shell sh cmd) (: r (hark [sh "-c" cmd]) (? (two? r) (nl->sp (chomp >r)) ""))
   ; $(wildcard): lush's glob (cook-glob -- classes, multi-segment patterns, the mask law) when
   ; aboard, else glob1 -- a word with no glob char is an existence test, otherwise the last
   ; path segment is the pattern, matched over readdir by 'glob's `match` (a leading . only by
   ; an explicit .) and sorted under its directory prefix, in glob(3) order.
   (glob1 pat)
   (? !(anyglob pat) (? (exists? pat) [pat] 0)
      (: k (lastslash pat)
         dir (? (0 < k) (snip pat 0 (1 < k ? (k - 1) k)) ".")
         pfx (sub pat 0 k)
         leaf (snip pat k #pat)
         hid (0 < #leaf && leaf 0 = 46)
         ms (filter (e \ (hid || e 0 != 46) && match leaf e)
                    (: es (readdir dir) (two? es && es)))
         (map (e \ 0 < #pfx ? (pfx + e) e) (sort ms))))
   (globw pat) (? (lit? cook-glob) (cook-glob pat) (glob1 pat))
   ; make's own faces over 'glob's clips: $(dir) keeps the trailing slash and
   ; answers "./" for a bare name, which is where it parts from posix's dirname.
   (fdir w) (: k (lastslash w) (? (0 < k) (sub w 0 k) "./"))
   (fnotdir w) (sub w (lastslash w) #w)
   (fbase w) (: dot (lastdot w) (dot < #w ? (sub w 0 dot) w))
   (fsuf w)  (: dot (lastdot w) (dot < #w ? (sub w dot #w) ""))
   ; $(abspath): rooted on the cwd, then lexically cleaned. the climb bounds at 0 since the path
   ; is already absolute, and a `/..` that runs out comes back empty -> "/", make's own answer.
   (fabs w)
   (: r (? ((0 < #w) && (w 0 = 47)) w
           (: p (cwd 0) (? (string? p) (p + "/" + w) w)))
      cl (pclean (segs r) 0)
      ("/" + join "/" cl))
   (dedup l) (? (two? l) (? (two? >l) (? (<l = <>l) (dedup >l) (<l . dedup >l)) l) l)
   (sortu l) (dedup (sort l))
   (strrep frm to s)
   (? (0 = #frm) s
      ((: (g i acc)
          (? ((i + #frm) > #s) (acc + sub s i #s)
             (? (frm = sub s i (i + #frm)) (g (i + #frm) (acc + to))
                (g (1 + i) (acc + string (s i))))))
       0 ""))
   (fn-or args as d)  ((: (g l) (? (two? l) (: v (expand <l as (1 + d)) (? (0 < #(trim v)) v (g >l))) "")) args)
   (fn-and args as d) ((: (g l last) (? (two? l) (: v (expand <l as (1 + d)) (? (0 < #(trim v)) (g >l v) "")) last)) args "")
   ; -- the helpers the added builtins stand on ------------------------------------
   (findsub s sub)                        ; index of sub in s | -1
    (: n #s m #sub
       (at i) (? (i + m > n) -1
                 (: (eq k) (k >= m ? 1 (s (i + k) = sub k ? (eq (1 + k)) 0))
                    (? (eq 0) i (at (1 + i)))))
       (? (m = 0) 0 (at 0)))
   (num1 s) (: r (sound (trim s)) (? (two? r) <r 0))     ; a leading integer | 0
   (fn-join a b)                          ; $(join): pairwise, the longer list's tail rides alone
    (: (g x y acc) (? (two? x) (g >x (two? y && >y) (<x + (two? y ? <y "") . acc))
                      (two? y) (g () >y (<y . acc))
                      (join " " (rev acc)))
       (g a b ()))
   (fn-slice ws n1 n2)                    ; $(wordlist): 1-based, inclusive, clamped both ends
    (: (g l i acc) (? (one? l || i > n2) (rev acc)
                      (i < n1) (g >l (1 + i) acc)
                      (g >l (1 + i) (<l . acc)))
       (g ws 1 ()))
   funcnames '("shell" "wildcard" "dir" "notdir" "basename" "suffix" "patsubst"
               "subst" "filter" "filter-out" "sort" "strip" "if" "or" "and"
               "addprefix" "addsuffix" "firstword" "lastword" "word" "words"
               "abspath" "realpath" "call" "origin"
               ; a name off this list is a variable: `$(foo bar)` answers empty, make's own rule
               "findstring" "join" "wordlist" "foreach" "value" "flavor"
               "error" "warning" "info")
   ; ..but a name make implements and we do not refuses instead: make never takes the variable
   ; branch for these, so an empty answer is a rule quietly not existing, and no output diff
   ; sees a target that was never made. the list is GNU's roster minus ours.
   gapnames '("file" "let" "intcmp" "guile")
   (cook-gap what)
    (say err ("cook: " + what + " is not implemented.\n"),
     quit 2)
   ; $(call fn,a,..): bind $0 (the name) and $1.. to the expanded args, expand
   ; fn's body, put the old bindings back (a shadowed outer $1 survives).
   (fn-call args as d)
   (: fname (trim (peep args 0 ""))
      body (peep as fname "")
      n ((: (g l i) (? (two? l) (g >l (1 + i)) i)) args 0)
      olds ((: (g i acc) (? (i < n) (g (1 + i) ((show i . peep as (show i) 'cook.undef) . acc)) acc)) 0 0)
      _ ((: (g i l) (? (two? l) (pin as (show i) <l, g (1 + i) >l) 0)) 0 args)
      r (expand body as (1 + d))
      _ (each olds (pr \ nom? >pr ? (pull as <pr 0) (pin as <pr >pr)))
      r)
   (funcp nm) (any (\ f (f = nm)) funcnames)
   (findws s) ((: (g i) (? (i >= tally s) i (? (chws (s i)) i (g (1 + i))))) 0)
   (apply-func nm at as d)
   (: ex1 (\ x (expand x as (1 + d)))
      argl (\ _ (map ex1 (splittop at 44)))     ; comma-split + expand (most funcs); 44 = ,
      rawl (\ _ (splittop at 44))               ; comma-split, not expanded (if/or/and)
      (nm @ "shell"     (fn-shell (shname as) (ex1 at))
          "wildcard"  (join " " (catmap globw (split-ws (ex1 at))))
          "dir"       (join " " (map fdir (split-ws (ex1 at))))
          "notdir"    (join " " (map fnotdir (split-ws (ex1 at))))
          "basename"  (join " " (map fbase (split-ws (ex1 at))))
          "suffix"    (join " " (map fsuf (split-ws (ex1 at))))
          "strip"     (join " " (split-ws (ex1 at)))
          "sort"      (join " " (sortu (split-ws (ex1 at))))
          "patsubst"  (: a (argl 0) (join " " (map (\ w (patsub (peep a 0 "") (peep a 1 "") w)) (split-ws (peep a 2 "")))))
          "subst"     (: a (argl 0) (strrep (peep a 0 "") (peep a 1 "") (peep a 2 "")))
         "filter"    (: a (argl 0) (join " " (filter (\ w (matchany (split-ws (peep a 0 "")) w)) (split-ws (peep a 1 "")))))
         "filter-out"(: a (argl 0) (join " " (filter (\ w !(matchany (split-ws (peep a 0 "")) w)) (split-ws (peep a 1 "")))))
         "addprefix" (: a (argl 0) (join " " (map (w \ peep a 0 "" + w) (split-ws (peep a 1 "")))))
         "addsuffix" (: a (argl 0) (join " " (map (w \ w + peep a 0 "") (split-ws (peep a 1 "")))))
         "firstword" (: ws (split-ws (ex1 at)) (? (two? ws) <ws ""))
         "lastword"  (: ws (split-ws (ex1 at)) (? (two? ws) (lastl ws) ""))
         "word"      (: a (argl 0) ws (split-ws (peep a 1 "")) n (: r (sound (trim (peep a 0 ""))) (? (two? r) <r 0)) (peep ws (n - 1) ""))
         "words"     (show #(split-ws (ex1 at)))
         "if"        (: a (rawl 0) c (trim (ex1 (peep a 0 ""))) (? (0 < tally c) (ex1 (peep a 1 "")) (ex1 (peep a 2 ""))))
         "or"        (fn-or (rawl 0) as d)
         "and"       (fn-and (rawl 0) as d)
         "call"      (fn-call (argl 0) as d)
         "origin"    (peep origins (trim (ex1 at)) "undefined")
         ("abspath" || "realpath") (join " " (map fabs (split-ws (ex1 at))))
         "findstring" (: a (argl 0) (? (0 <= (findsub (peep a 1 "") (peep a 0 ""))) (peep a 0 "") ""))
         "join"      (: a (argl 0) (fn-join (split-ws (peep a 0 "")) (split-ws (peep a 1 ""))))
         "wordlist"  (: a (argl 0)
                               ws (split-ws (peep a 2 ""))
                               n1 (num1 (peep a 0 "")) n2 (num1 (peep a 1 ""))
                               (join " " (fn-slice ws n1 n2)))
         "foreach"   (: a (rawl 0)
                               v (trim (ex1 (peep a 0 "")))
                               body (peep a 2 "")
                               old (peep as v "")
                               r (join " " (map (\ w (pin as v w, ex1 body))
                                                (split-ws (ex1 (peep a 1 "")))))
                               _ (pin as v old)              ; put the outer binding back
                               r)
         ; value/flavor read the variable without expanding it -- the one pair that must not ex1
         "value"     (peep as (trim (ex1 at)) "")
         "flavor"    (: o (peep origins (trim (ex1 at)) "undefined")
                               (? (o = "undefined") "undefined" (peep flavors (trim (ex1 at)) "recursive")))
         ; the diagnostics: a guard spelled $(error ..) must not vanish into an empty string
         "info"      (puts (ex1 at), putc 10, "")
         "warning"   (say err ("cook: " + ex1 at), put err 10, "")
         "error"     (say err ("cook: *** " + ex1 at + ".  Stop.\n"), quit 2)
         ""))                                   ; unknown -> empty (make's own rule; see funcnames)

   ; a group body is a function call ($(name args)), a substitution reference
   ; ($(VAR:from=to)), or a plain variable ($(VAR)).
   (eval-group body as d)
   (: sp (findws body)
      nm (snip body 0 (? (sp < #body) sp #body))
      _ (? (any (= nm) gapnames) (cook-gap ("$(" + nm + " ..)")) 0)
      (? ((sp < #body) && funcp (snip body 0 sp))
         (apply-func (snip body 0 sp) (ltrim (snip body (1 + sp) #body)) as d)
         (: eb (expand body as (1 + d)) ci (findc eb 0 58)
            (? (ci < #eb) (subst-ref eb as d) (expand (peep as eb "") as (1 + d))))))

   ; expansion: $(..) / ${..} groups (functions / subst refs / vars), the single-char
   ; $V form (including the automatic vars $@ $< $^ $*, which live in the table during
   ; recipe expansion), and $$ -> $.
   (expand s as d)
   (? (d > 100) s
      ((: (g i acc)
          (? (i >= #s) acc
             (? (s i = 36 && 1 + i < #s)
                (: nx (s (1 + i))
                   (? (nx = 40 || nx = 123)
                      (: close (? (nx = 40) 41 125) j (findclose s (2 + i) nx close)
                         (g (1 + j) (acc + eval-group (snip s (2 + i) j) as d)))
                      (nx = 36) (g (2 + i) (acc + "$"))
                      (namech nx || nx = 64 || nx = 60 || nx = 94 || nx = 42 || nx = 63)
                      (g (2 + i) (acc + expand (peep as (snip s (1 + i) (2 + i)) "") as (1 + d)))
                      (g (1 + i) (acc + string (s i)))))
                (g (1 + i) (acc + string (s i))))))
       0 ""))
   (expand-words ws as) (catmap (w \ split-ws (expand w as 0)) ws)
   ; a recipe line leading with the shell's `exec` is interactive: it replaces the shell, so make
   ; already runs it on the real tty, and cook runs it through the exec nif to match.
   (starts? s pre) (#pre <= #s && pre = snip s 0 #pre)
   (execp cmd) (: t (ltrim cmd) (starts? t "exec" && (4 = #t || chws (t 4))))
   ; build a card's steps. each raw is (silent ignore . body) from recipe-parse; expand the body
   ; now (the $@/$</$^/$* automatics are live in `as` and re-pinned per item) and close over the
   ; expanded command in a thunk that runs it make-style via sh-line, carrying the @/- flags. an
   ; exec-prefixed line becomes an (exec "sh" "-c" cmd) step instead.
   ; the shell a recipe line rides. .SHELLFLAGS is a plain make variable, so it is
   ; already in `as` (the .DEFAULT_GOAL precedent); its default is make's own -c.
   (shflags as) (: f (trim (peep as ".SHELLFLAGS" ""))
                   (? (0 < #f) (split-ws f) '("-c")))
   ; $(@D): the target's directory sans trailing slash ("." for a bare name), $(@F)
   ; its basename -- make's D/F faces, pinned beside the plain automatics.
   (dslash w) (: k (lastslash w) (? (0 < k) (snip w 0 (? (1 < k) (k - 1) k)) "."))
   ; ..and SHELL picks the shell itself (a Makefile saying SHELL := lush runs
   ; its recipes -- and its $(shell) calls -- under lush), default sh.
   (shname as) (: s (trim (peep as "SHELL" "")) (? (0 < #s) s "sh"))
   ; a phony item is a symbol, not a string (mk-item interns it), and an automatic must read as
   ; the name either way -- `cd src && $(MAKE) $@` over a phony target is handed nothing otherwise.
   (itext x) (? (nom? x) (show x) x)
   (expand-steps raws t pr stem as)
   (: pt (map itext pr)
       td (date t)
       ; $?: the prerequisites newer than the target, all of them when it is not on disk (make's
       ; answer for a phony and a first build); a phony prerequisite is newer whatever the clock says.
       nwr (filter (\ x (? (nom? x) 1 (: xd (date x) (? !td (? xd 1 0) (? xd (xd > td) 0))))) pr)
       _ (pins as "@" (itext t) "<" (? (two? pt) <pt "") "^" (join " " pt) "*" stem)
       _ (pins as "?" (join " " (map itext nwr)))
       _ (pins as "@D" (? (nom? t) "." (dslash t)) "@F" (? (nom? t) (show t) (fnotdir t)))
       fl (shflags as)
       sn (shname as)
       quiet? (0 < #(peep as ".SILENT" ""))
       ; make reads the @/-/+ modifiers after expansion too (the $(Q)-as-@ idiom), so re-strip the
       ; expanded line and fold its flags in. expand once and keep the whole parse: the oneshell
       ; test and the per-line lane both want it, and expanding twice runs every $(shell ..) twice.
       exs (map (raw \ parse-mods (expand >>raw as 0)) raws)
       cmds (map cuup exs)
       ; .ONESHELL: the whole recipe rides one shell, and make's rule is that the first line's
       ; @/- modifiers govern the lot. with plain -c only the last line's status is checked, so a
       ; oneshell Makefile wants .SHELLFLAGS := -ec. an `exec` line still wants a process of its
       ; own (it replaces cook to inherit the tty), so a recipe carrying one stays per-line.
       one? (0 < #(peep as ".ONESHELL" "") &&
             two? raws && !(any execp cmds))
       (? one?
          (: r0 <raws
             (? (peep dryrun 0 0) [(\ _ (: _ (puts (join "\n" cmds)) (putc 10)))]
                (peep emitp 0 0) [(([sn] + fl) + [(join "\n" cmds)])]
                [(_ \ sh-line <r0 <>r0 sn fl (join "\n" cmds))]))
          (: (g rs es acc)
              (? !(two? rs) (rev acc)
                 (: raw <rs e <es
                    sil (<raw || <e || quiet?) ign (<>raw || <>e) cmd >>e
                    ; -n says the line and runs nothing -- and @ does not hide it, which is
                    ; make's rule: the point of -n is to show the silent ones too.
                    st (? (peep dryrun 0 0) (\ _ (puts cmd, putc 10))
                          (execp cmd)
                          (? (peep emitp 0 0) ('exec . [sn "-c" cmd])
                             (_ \ do-exec [sn "-c" cmd]))
                          (peep emitp 0 0) ([sn] + fl + [cmd])
                          (_ \ sh-line sil ign sn fl cmd))
                    (g >rs >es (st . acc))))
             (g raws exs ()))))

   ; -- conditionals & assignment ops over the variable table `as` --
   (unquote-str s) (? (#s >= 2 && (s 0 = 34 || s 0 = 39)) (snip s 1 (#s - 1)) s)
   (cond-args rest)            ; ifeq/ifneq rest -> (arg1 . arg2)
   (: t (trim rest)
      (? (0 < #t && t 0 = 40)
         (: cl (findclose t 1 40 41) parts (splittop (snip t 1 cl) 44)
            ((? (two? parts) <parts "") . (? (two? >parts) <>parts "")))
         (: ws (map unquote-str (split-ws t))
            ((two? ws ? <ws "") . (? (two? >ws) <>ws "")))))
   (eval-ifeq rest as) (: a (cond-args rest) (trim (expand <a as 0) = trim (expand >a as 0)))
   (eval-ifdef rest as) (0 < tally (expand (peep as (trim (expand rest as 0)) "") as 0))
   ; ov nonzero is `override`, the one assignment that beats a command-line VAR=VAL (which
   ; otherwise silences every file assignment to that name, ?= and += included -- make's rule).
   ; origins records provenance for $(origin); an unfired ?= leaves value and origin alone.
   (do-assign as nm op val) (assign1 as nm op val 0)
   (assign1 as nm op val ov)
   (? (!ov && (peep origins nm "undefined" = "command line")) 0
      (: v (trim val)
         ; the flavor rides beside the origin: an expanded `:=` and a stored `=` are the
         ; same text afterwards, so nothing in the value itself can answer $(flavor).
         (org f) (: _ (pin origins nm (? ov "override" "file")) (pin flavors nm f))
         (op @ "!="  (: _ (pin as nm (fn-shell (shname as) (expand v as 0))) (org "simple"))
               ":="  (: _ (pin as nm (expand v as 0)) (org "simple"))
               "::=" (: _ (pin as nm (expand v as 0)) (org "simple"))
               "?="  (: cur (peep as nm 'cook.undef)
                      (nom? cur ? (pin as nm v, org "recursive") 0))
               "+="  (: o (peep as nm "")
                        _ (pin as nm (? (0 < tally o) (o + " " + v) v))
                      (org (peep flavors nm "recursive")))
            (pin as nm v, org "recursive"))))

   ; -- fold classified lines into a rules list, mutating `as`. The conditional
   ; stack is a list of frames (pon taken active); `on` is the top frame's active
   ; (1 when there is no frame). include splices the named files' lines inline.
   (r1 c) <>c (r2 c) <>>c (r3 c) <>>>c
   (addstep cur st) (<cur . (<>cur . (st . >>cur)))
   (finalize cur) (<cur . (<>cur . rev >>cur))
   (flushr cur rules) (? cur (finalize cur . rules) rules)
   (mkrule c)                  ; -> (TGTS-text PREREQS-text . STEPS-rev); split off an inline ; recipe
   ; the recipe is everything past the first `;`, semicolons included: `a:;x ; y` is one recipe
   ; line the shell splits, not two fields.
   (: prr (r2 c) sc (splittop prr 59)
      rec (? (two? >sc) (join ";" >sc) "")
      inl (? (0 < tally (trim rec)) [(parse-mods (trim rec))] 0)
      (r1 c . (<sc . inl)))
   (condon cond) (? (two? cond) <>><cond 1)
   (push-cond cond pon active) ([pon active active] . cond)
   (else-cond cond) (: f <cond pon <f taken <>f na (pon && !taken)
                       ([pon (taken || na) na] . >cond))
   (build cls as)
   ((: (loop cs rules cur cond)
       (? !(two? cs) (rev (flushr cur rules))
          (: c <cs k <c rest >cs on (condon cond)
             (k @ 'recipe (loop rest rules (? (on && cur) (addstep cur (r1 c)) cur) cond)
                  'rule   (? on (loop rest (flushr cur rules) (mkrule c) cond)
                                      (loop rest (flushr cur rules) 0 cond))
                  'assign (: _ (? on (do-assign as (r1 c) (r2 c) (r3 c)) 0) (loop rest (flushr cur rules) 0 cond))
                  'oassign (: _ (? on (assign1 as (r1 c) (r2 c) (r3 c) 1) 0) (loop rest (flushr cur rules) 0 cond))
                  'xassign (: _ (? on (: _ (assign1 as (r1 c) (r2 c) (r3 c) 0)
                                               (setenv (r1 c) (expand (peep as (r1 c) "") as 0))) 0)
                                    (loop rest (flushr cur rules) 0 cond))
                  'xname   (: _ (? on (setenv (r1 c) (expand (peep as (r1 c) "") as 0)) 0)
                                    (loop rest (flushr cur rules) 0 cond))
                  'inc    (? on (: more (catmap file-lines (split-ws (expand (r1 c) as 0)))
                                         (loop (more + rest) (flushr cur rules) 0 cond))
                                      (loop rest (flushr cur rules) 0 cond))
                  ; conditionals thread `cur` rather than flushing it: a top-level rule is
                  ; already flushed by the blank line before one, and a conditional inside a
                  ; recipe block gates its lines via `on` above.
                  'defassign (: _ (? on (do-assign as (r1 c) "=" (r2 c)) 0)
                                      (loop rest (flushr cur rules) 0 cond))
                  ; remember which targets carry one, so recur can refuse if one is remade
                  'tvar (: _ (? on (each (split-ws (expand (r1 c) as 0))
                                               (\ w (pin tvarbox (unseat w) "1"))) 0)
                                 (loop rest (flushr cur rules) 0 cond))
                  'expand (? (on && evalp (r1 c))
                                   (: more (text-lines (expand (eval-args (r1 c)) as 0))
                                      (loop (more + rest) (flushr cur rules) 0 cond))
                                   (: _ (? on (expand (r1 c) as 0) 0) (loop rest rules cur cond)))
                  'ifeq   (loop rest rules cur (push-cond cond on (on && eval-ifeq (r1 c) as)))
                  'ifneq  (loop rest rules cur (push-cond cond on (on && !(eval-ifeq (r1 c) as))))
                  'ifdef  (loop rest rules cur (push-cond cond on (on && eval-ifdef (r1 c) as)))
                  'ifndef (loop rest rules cur (push-cond cond on (on && !(eval-ifdef (r1 c) as))))
                  'else   (loop rest rules cur (else-cond cond))
                  'endif  (loop rest rules cur >cond)
                  (loop rest (flushr cur rules) 0 cond)))))
    cls 0 0 0)

   ; `$(eval TEXT)` alone on a line: expand TEXT, then parse it, as the `include` splice does with
   ; a string where the file was. nested in an expression it cannot work -- expand answers a
   ; string and cannot reach the rule list.
   (evalp s) (: n #s
                (7 < n && s 0 = 36 && (s 1 = 40 || s 1 = 123)
                 && snip s 2 6 = "eval" && chws (s 6)
                 && findclose s 2 (s 1) (s 1 @ 40 41 125) = n - 1))
   (eval-args s) (ltrim (snip s 6 (#s - 1)))
   ; a define body must survive verbatim, and classify strips comments, trims, and reads a
   ; tab-led line as a recipe -- so the walk takes those lines itself and hands over the rest.
   (text-lines src)
    ((: (g l acc)
        (? (one? l) (rev acc)
           (: t (trim (strip-comment <l))
              (? (first-word t = "define")
                 (: nm (trim (after-word t))
                    (body r bs) (? (one? r) (: _ (say err "cook: define with no endef.  Stop.")
                                                 _ (put err 10) (quit 2))
                                    (trim (strip-comment <r) = "endef") [>r bs]
                                    (body >r (bs + <r + "\n")))
                    p (body >l "")
                    (g <p (['defassign nm <>p] . acc)))
                 (g >l (classify <l . acc))))))
     (lines (uncont src)) ())

   ; read a file whole (for `include`), then split it into classified lines.
   (slurp-of path) (: q (open path "r") (? (hot? q) (slurp q) (: _ (say err ("cook: cannot read " + path)) _ (put err 10) (quit 1))))
   (file-lines ip) (text-lines (slurp-of ip))

   ; seed the variable table as make does: the environment first (every NAME=value, origin
   ; "environment"), then the builtin defaults for whatever it left unsaid, then the command
   ; line's VAR=VAL words, whose origin silences file assignments. `.POSIX:` changes make's own
   ; defaults (CC to c99, CFLAGS to -O1) and is read off the raw source, since the defaults are
   ; seeded before a rule is parsed -- and as defaults, so a file's own CC= still wins.
   (posixp src)
   (any (\ l (: t (trim (strip-comment l))
                (7 <= #t && snip t 0 7 = ".POSIX:")))
        (lines src))
   (seed-defaults as px)
   (: _ (each (keys origins) (k \ pull origins k 0))       ; a fresh provenance per import
      ; ..except SHELL: make's documented exception -- the user's login shell
      ; must never become the recipe shell (only a Makefile's own SHELL= does)
      _ (each (environ 0)
              (\ e (: i (findc e 0 61)                       ; 61 = =
                      (? (i < #e)
                         (: nm (snip e 0 i)
                            (? (nm = "SHELL") 0
                               (: _ (pin as nm (sub e (1 + i) #e))
                                  (pin origins nm "environment"))))
                         0))))
      (dflt nm v) (? (nom? (peep as nm 'cook.undef))
                     (: _ (pin as nm v) (pin origins nm "default")) 0)
      _ (dflt "CC" (? px "c99" "cc")) _ (? px (dflt "CFLAGS" "-O1") 0)
      _ (dflt "MAKE" "make") _ (dflt "AR" "ar") _ (dflt "RM" "rm -f")
      ; CURDIR is make's own and is read after -C: a makefile that names itself with
      ; $(notdir $(CURDIR)) spells every output wrong when it is unset.
      _ (dflt "CURDIR" (: p (cwd 0) (? (string? p) p "")))
      _ (dflt "AS" "as") _ (dflt "ARFLAGS" "rv")      ; the builtin rules below read these
      _ (each (clivars 0)
              (\ pr (: _ (pin as <pr >pr) (pin origins <pr "command line"))))
      as)

   ; make's old-style suffix rules: `.c.o:` is `%.o: %.c`, and a single `.c:` is `%: %.c`.
   ; answers (tgtpat srcpat), or 0 when the target is not one. keyed on the suffix list and not
   ; on a leading dot, or .PHONY reads as a single-suffix rule the moment somebody hangs a
   ; recipe off it -- and the dot-target drop below eats these in silence if they go unread.
   sufs '("c" "cc" "C" "cpp" "S" "s" "o" "a" "h" "y" "l" "f" "F" "p" "r" "m" "sh")
   ; ..and what a Makefile's own `.SUFFIXES` says: bare it clears, with prerequisites it adds.
   ; boxed because sufpat is asked per rule and the declaration may be any line above.
   sufbox {}
   (sufnow _) (peep sufbox 0 sufs)
   (sufknown x) (any (= x) (sufnow 0))
   (sufpat t)
   (: n #t
      (? (|| (n < 2) !(t 0 = 46)) 0
         (: (lastdot k r) (? (n <= k) r (? (t k = 46) (lastdot (1 + k) k) (lastdot (1 + k) r)))
            d (lastdot 1 0)
            (? (d = 0)                                        ; .c -> % : %.c
               (? (sufknown (snip t 1 n)) ["%" ("%" + t)] 0)
               (: sr (snip t 1 d) tg (snip t (1 + d) n)       ; .c.o -> %.o : %.c
                  (? (&& (sufknown sr) (sufknown tg))
                     [("%." + tg) ("%." + sr)] 0))))))

   ; split a prereq word list at a `|` into (normal . order-only).
   (splitbar ws) ((: (g l acc) (? (one? l) (rev acc . 0)
                       (? (<l = "|") (rev acc . >l) (g >l (<l . acc))))) ws 0)

   ; parse a Makefile and register its rules: .PHONY members become phony symbols, every other
   ; item a file string. a rule is a static pattern rule (targets: tgtpat: prereqpats), an
   ; implicit pattern rule (a % target, stored for prep-time resolution), or a normal one.
   (register-makefile src)
   (: as (seed-defaults {} (posixp src))
      rules (build (text-lines src) as)
      phony (: ps {}
               _ (each rules (\ r (: tg (expand-words [<r] as)
                    (? (any (= ".PHONY") tg)
                       (each (expand-words [<>r] as) (\ p (pin ps p 1))) 0)))) ps)
      ; .ONESHELL is a target, not a variable, but what it governs is recipe
      ; expansion -- so record it where expand-steps already looks: `as`.
      _ (each rules (\ r (? (any (= ".ONESHELL") (expand-words [<r] as))
                            (pin as ".ONESHELL" "1") 0)))
      ; `.SUFFIXES:` bare empties the vocabulary and each one after it adds, read in file order
      ; before any rule asks sufpat, or a rule above its own declaration is judged by the defaults.
      _ (each rules (\ r (? (any (= ".SUFFIXES") (expand-words [<r] as))
                            (: ws (expand-words [<>r] as)
                               (? (two? ws)
                                  (pin sufbox 0 ((sufnow 0) + map (\ w (? ((0 < tally w) && (w 0 = 46))
                                                                          (snip w 1 #w) w)) ws))
                                  (pin sufbox 0 ())))
                            0)))
      ; .SILENT with no prerequisites quiets every recipe. named prerequisites quiet only those
      ; targets, and that wants a per-target ask expand-steps has no room for yet.
      _ (each rules (\ r (? (any (= ".SILENT") (expand-words [<r] as)
                             && 0 = #(trim <>r))
                            (pin as ".SILENT" "1") 0)))
      (mk-item nm) (? (peep phony nm 0) (intern nm) nm)
      patbox (tablet 0)        ; accumulates implicit pattern rules: (tgtpat prs oos . raws)
      _ (each rules (\ r
           (: tgtstext <r prtext0 <>r raws >>r
              ; `tgt:: ..` -- ruleP eats one colon, so a second one leading the prerequisites
              ; is the marker. left in place it reads as a static pattern rule with an empty
              ; target pattern, and the rule vanishes.
              pl (ltrim prtext0)
              dbl (0 < #pl && pl 0 = 58)
              prtext (? dbl (snip pl 1 #pl) prtext0)
              tgts (expand-words [tgtstext] as)
              sp (? (two? raws) (sufpat <tgts) 0)   ; an old-style suffix rule, .c.o style
              (? sp (pin patbox 0 ([<sp [<>sp] () raws] . peep patbox 0 0))
                 ; drop .PHONY / .SUFFIXES / ... -- a special target names no directory,
                 ; so a leading dot alone is not the test: ./x and ../x are paths.
                 (any (\ t ((0 < tally t) && (t 0 = 46) && (0 = lastslash t))) tgts) 0
                 (: cp (splittop prtext 58)
                    (? (two? >cp)
                       ; static pattern rule
                       (: tpat <(expand-words [<cp] as) ppats (expand-words [<>cp] as)
                          (each tgts (\ t (: m (pmatch tpat t)
                             (? (two? m) (: stem <m ping (map (\ pp (stemsub pp stem)) ppats)
                                            (reg (mk-item t) (map mk-item ping) 0 (expand-steps raws (mk-item t) ping stem as))) 0)))))
                       ; implicit pattern rule, or normal rule
                       (: sb (splitbar (expand-words [prtext] as)) prs <sb oos >sb
                          (? (any haspct tgts)
                             ; an empty recipe is make's cancellation idiom, and with no lex
                             ; builtin cancelling is registering nothing.
                             (? !(two? raws) 0
                                (each tgts (\ t (? (haspct t) (pin patbox 0 ([t prs oos raws] . peep patbox 0 0)) 0))))
                             ; make expands $</$^ when the recipe runs, against every line's
                             ; prerequisites merged; cook expands here, so it asks the card
                             ; already registered before adding this line's own words.
                             ; prerequisites arriving after their recipe still read short.
                             (each tgts (\ t (: it (mk-item t) ps (map mk-item prs)
                                                all (adds <(peep cards (unseat it) '(())) ps)
                                                ((? dbl regd reg) it ps (map mk-item oos)
                                                     (expand-steps raws it all "" as)))))))))))))
      ; make's .DEFAULT_GOAL overrides "first rule declared" -- it is a plain
      ; variable, so it survives the dot-target drop above and lands in `as`.
      dg (trim (peep as ".DEFAULT_GOAL" ""))
      _ (0 < #dg && pin check 0 (mk-item dg))
      patlist (peep patbox 0 0)
      ; make's builtin implicit rules, same shape as a file's own pattern: (tgtpat prs oos raws).
      ; two fences, both load-bearing: tried only after the file's patterns, so a Makefile that
      ; states its own %.o: %.c wins outright, and taken only where the stem-source exists,
      ; since `%: %.c` matches every word there is. a raw recipe line is (silent ignore . text),
      ; what parse-mods answers, so the builtins go down the door the file's own recipes take --
      ; a plain string here reads as a recipe of no lines: the card resolves and nothing runs.
      (bpat tgt prs cmd) [tgt prs () [(parse-mods cmd)]]
      builtpats
       [(bpat "%.o" '("%.c") "$(CC) $(CFLAGS) $(CPPFLAGS) -c -o $@ $<")
        (bpat "%.o" '("%.S") "$(CC) $(ASFLAGS) $(CPPFLAGS) -c -o $@ $<")
        (bpat "%.o" '("%.s") "$(AS) $(ASFLAGS) -o $@ $<")]
      ; make's match-anything builtins -- `%: %.c` and `%: %.o` -- are deliberately not here. they
      ; match every target there is, and GNU only dares them under conditions this resolver does
      ; not model (never against a target that already has a rule, nor an intermediate), so
      ; `%: %.o` would hijack a real link, seeing one object beside the target and linking that
      ; alone. the narrow %.o: rules above cannot: their target must already end in .o.
      (psrc p item) (: stem <(pmatch <p item) prs <>p (two? prs ? (stemsub <prs stem) ""))
      ; a pattern whose source cannot be had does not apply -- make rejects it and tries the next,
      ; and with none left the target is a source leaf already on disk. "can be had" is
      ; exists-or-has-a-card: no intermediates, per the note above.
      (phave? p item) (: s (psrc p item) (exists? s || two? (cards s)))
      (best-of ms item)        ; the shortest stem among the patterns that apply
      (: ok (filter (p \ phave? p item) ms)
         (? (one? ok) 0
            (foldl (\ b p (? !b p (? (#<(pmatch <p item) < #<(pmatch <b item)) p b))) 0 ok)))
      (builtin-of item)        ; the builtin lane: a match whose source is really there
      (: ms (filter (p \ two? (pmatch <p item) && exists? (psrc p item)) builtpats)
         (best-of ms item))
      (resolve item)           ; synthesize a card from the best matching pattern rule (merging an explicit prereq-only card)
      (: ms (filter (p \ two? (pmatch <p item)) patlist)
         best (: b (best-of ms item) (? b b (builtin-of item)))
         (? best
            (: stem <(pmatch <best item)
               ping (map (pp \ stemsub pp stem) <>best)
               poo  (map (pp \ stemsub pp stem) <>>best)
               ex (peep cards item ())
               allp (? ex (map mk-item ping + <ex) (map mk-item ping))
               oo   (? ex (map mk-item poo + <>ex) (map mk-item poo))
               (allp . (oo . expand-steps <>>>best item ping stem as)))
            0))
      (pin pgen 0 resolve))

   ; -- emit: serialize the resolved cards back as a Cookfile ------------------
   ; with emitp set the cards hold concrete, fully expanded items and ("sh" "-c" cmd) steps.
   ; walk the graph from the default ticket first, so it stays the default in the output, then
   ; every other card, resolving patterns exactly as prep does and printing each as a
   ; (recipe ..) / (reg ..) form. a pattern-only target with no card prints nothing.
   (qshow x) ("'" + show x)                  ; a quoted datum literal: 'all, '("a" b)
   ; write $HOME and $PWD back over the resolved prefixes, or the emitted Cookfile installs into
   ; a home nobody else has. the cwd goes first: it usually sits under the home, and a $HOME
   ; pass would hide it from the $PWD one. `reg` opens both again at the far end.
   (seat w)
   (? (string? w)
      (: c (cwd 0) h (getenv "HOME")
         a (? (string? c && (1 < #c)) (strrep c "$PWD" w) w)
         (? (string? h && (1 < #h)) (strrep h "$HOME" a) a))
      w)
   (seatl l) (? (two? l) (map seat l) l)
   (estep steps) (? (two? steps) (qshow (map seatl steps)) "0")
   (emit-line o item ings oo steps)
   (: row (? (two? oo)
             ["(reg" (qshow (seat item)) (qshow (? (two? ings) (seatl ings) 0)) (qshow (seatl oo)) (estep steps)]
             ["(recipe" (qshow (seat item)) (qshow (? (two? ings) (seatl ings) 0)) (estep steps)])
      _ (say o (join " " row)) _ (say o ")") (put o 10))
   ; pre-order walk; `seen` (a tablet) keeps a shared prerequisite to one card.
   ; the card lookup mirrors prep: an explicit recipe wins, else a pattern rule.
   (emit-walk o item seen)
   (? (peep seen item 0) 0
      (: _ (pin seen item 1)
         exr (peep cards item 'none)
         ex (? (two? exr) exr 0)
         f (peep pgen 0 ())
         r (? (ex && two? >>ex) ex
              (: g (? f (f item) 0) (? (two? g) g ex)))
         (? (two? r)
            (: ings <r oo <>r steps >>r
               _ (emit-line o item ings oo steps)
               _ (each ings (d \ emit-walk o d seen))
               _ (each oo (d \ emit-walk o d seen)) 0)
            0)))
   (emit-cookfile o)
   (: _ (say o "; generated by `cook --emit` from the Makefile -- do not edit by hand.") _ (put o 10)
       _ (say o "; the Makefile's $(shell)/$(wildcard)/vars/patterns are RESOLVED here; each") _ (put o 10)
       _ (say o "; recipe line became an (\"sh\" \"-c\" cmd) step. make's @ (silent) and -") _ (put o 10)
       _ (say o "; (ignore-error) line modifiers are not carried across.") _ (put o 10) _ (put o 10)
       seen {}
       dflt (check 0)
       _ (? dflt (emit-walk o dflt seen) 0)
       _ (each (keys cards) (k \ emit-walk o k seen))
       (say o "\n(cook-all 0)\ "))

   ; is a recipe-file path named like a Makefile? then cook reads it as one.
   (mk-base p) (snip p (lastslash p) #p)
   (mk-ends p suf) (: ls #suf lp #p ((ls <= lp) && (suf = snip p (lp - ls) lp)))
   (makefilep p) (: b (mk-base p)
      ((b = "Makefile") || b = "makefile" || b = "GNUmakefile" || mk-ends p ".mk"))
   ; the love-recipe names, and there are only these: Cards.l, Cookfile, or anything else .l
   (lovefilep p) (: b (mk-base p) (mk-ends p ".l" || (b = "Cookfile")))
   ; -f names the makefile whatever it is called, as make's does, so only a love-recipe name
   ; argues back; discovery still needs the name to tell it what it found.
   (asmake? p explicit?) (? explicit? !(lovefilep p) (makefilep p))

   ; the build file may be named explicitly (the first arg word) or discovered in
   ; the cwd; the seat at the bottom already stripped the program head + -l chain.
   (exists? p) (: q (open p "r") (? (hot? q) 1 0))     ; a one-shot probe (the fd dies with the process)
   ; discovery precedence: Cards.l, then Cookfile, then Makefile. only a Makefile-named file
   ; (makefilep) is read as make; Cards.l and Cookfile are love source.
   ; (a dummy param: a nullary (f) would be \ with one operand = quote.)
   (discover _) ((: (g ps) (? (two? ps) (? (exists? <ps) <ps (g >ps)) 0))
               '("Cards.l" "Cookfile" "Makefile"))

   ; empty the import books so a fresh build starts clean (cards/check/pgen are
   ; the global tablets the Makefile importer and the Cookfile eval both fill).
   (clear-cards _) (each (keys cards) (k \ pull cards k 0), pull check 0 0, pull pgen 0 0, 0)
   ; transpile Makefile `mk` into the Cookfile at path `ck`, then wipe the import
   ; books so the regenerated Cookfile can be read back into a clean scope.
   (regen-cookfile mk ck)
   (: _ (pin emitp 0 1)
       q (open mk "r")
       _ (register-makefile (slurp q))
       o (open ck "w")
       _ (emit-cookfile o)
       _ (close o)
       _ (pin emitp 0 0)
       _ (clear-cards 0)
       _ (say err ("cook: " + ck + " regenerated from " + mk)) (put err 10))
   ; where a Cookfile and a Makefile both sit in the cwd and the Makefile is the newer, refresh
   ; the Cookfile from it before discovery picks it up. (date is () for a missing file.)
   (autoregen _)
   (: tm (date "Makefile") tc (date "Cookfile")
      (? (tm && tc && tm > tc) (regen-cookfile "Makefile" "Cookfile") 0))

   ; -- the command line ---------------------------------------------------------
   ; cook owns its own arg parse over the rebound argv. like make, it takes flags in any order
   ; and treats every non-flag word as a recipe to build:
   ;   -f, --file file   the build file (a Makefile or a Cookfile); else discovered
   ;   -j, --jobs [N]    run up to N recipes at once (default 1). a bare -j is not make's
   ;                     "unlimited" but this machine's width (jobauto below), and it does not
   ;                     travel: no jobserver, so a recursive $(MAKE) runs at -j1 on its own.
   ;   --emit            transpile a Makefile to a resolved Cookfile on stdout, then exit
   ;   -h, --help, help  print usage and exit
   ;   -v, --version, version   print the version and exit
   ;   recipe ...        the items to cook (default: the first recipe declared)
   ; back-compat with `cook <Makefile> [recipe]`: with no -f, a first positional naming an
   ; existing file may be the build file, but only where discovery would find nothing else or
   ; would find that very file. everywhere else, and always with -f, a positional is a recipe.
   (bye s) (puts s, putc 10, flush out, quit 0)
   (version _) (bye ("cook (love " + love-version + ")"))
   (usage _) (bye ("usage: cook [-C DIR] [-f FILE] [-j [N]] [--emit] [-v] [-h] [VAR=VAL ...] [RECIPE ...]\n"
                   + "  -C, --directory DIR  cook in DIR\n"
                   + "  -f, --file FILE   the build file (Makefile or Cookfile); else discovered\n"
                   + "  -j, --jobs [N]    run up to N recipes at once (default 1; bare -j = this machine)\n"
                   + "      --emit        transpile a Makefile to a resolved Cookfile, then exit\n"
                   + "  -v, --version     print the version and exit\n"
                   + "  -h, --help        print this help and exit\n"
                   + "  VAR=VAL           a command-line variable (silences the file's assignments)\n"
                   + "  RECIPE ...        the items to build (default: the first recipe declared)\n"
                   + "a Makefile (Makefile/makefile/GNUmakefile/*.mk) is imported and cooked; any other build file is a Cookfile of ordinary love source."))
   (need-arg h r) (? (two? r) 0 (: _ (say err ("cook: " + h + " needs an argument")) _ (put err 10) (quit 2)))
   ; is this word the count, or the next argument? all digits and at least one.
   (jobword? w)
   (: n #w
      (go k) (? (n <= k) 1 (!(digitp (w k))) 0 (go (k + 1)))
      ((0 < n) && (go 0)))
   ; a file's lines, or () where there is none -- /proc is the only door in reach here.
   (jobfile p)
   (: q (open p "r")
      (? !(hot? q) () (: s (slurp q) _ (close q) (lines s))))
   ; the leading number in a line, 0 where there is none: MemAvailable's kB field.
   (jobnum l)
   (: n #l
      (go k a seen) (? (n <= k) (seen ? a 0)
                       (digitp (l k)) (go (k + 1) (a * 10 + (l k) - 48) 1)
                       seen a
                       (go (k + 1) a 0))
      (go 0 0 0))
   ; a bare -j: what this machine can carry, cores and memory. half the cores plus one, since the
   ; wall stops paying for width well before the last core while every worker costs a whole
   ; mooncc heap; bounded by MemAvailable at 512 MB a job, since one TU peaks near 350 MB, and
   ; the smaller of the two wins. no /proc (the BSDs) answers 1.
   (jobauto _)
   (: (rows p w) (: ls (jobfile p)
                    (? !(two? ls) 0
                       (foldl (\ a l (: k #w
                                        ((k <= tally l) && (snip l 0 k = w) ? (a + 1) a)))
                              0 ls)))
      cpus (rows "/proc/cpuinfo" "processor")
      mls (jobfile "/proc/meminfo")
      free (? !(two? mls) 0
              (foldl (\ a l ((13 <= tally l) && (snip l 0 13 = "MemAvailable:")
                             ? (jobnum (snip l 13 #l)) a)) 0 mls))
      room (? (0 < free) (free // 524288) 0)               ; kB -> 512 MB slots
      want (? (0 < cpus) (cpus // 2 + 1) 0)
      n (? (0 = want) 1 (0 = room) want (room < want) room want)
      (? (0 < n) n 1))
   ; a job count: all digits and above zero, or the run ends here. `-j0` and `-j x`
   ; are the same mistake and get the same word.
   (jobn w)
   (: n #w
      (go k a) (? (n <= k) a
                  (!(digitp (w k))) 0
                  (go (k + 1) (a * 10 + (w k) - 48)))
      v (? (0 < n) (go 0 0) 0)
      (? (0 < v) v (say err ("cook: -j wants a job count, not " + show w),
                    put err 10, quit 2)))
   ; a NAME=VAL word (make's command-line variable; NAME:=VAL folds to the same,
   ; the split point's leading : stripped) -> (name . val), or () for a plain word.
   (varw w)
   (: i (findc w 0 61)                                       ; 61 = =
      (? (i >= #w || 0 = i) ()
         (: e (? (w (i - 1) = 58) (i - 1) i)                 ; 58 = :
            (? (0 = e) () (snip w 0 e . sub w (1 + i) #w)))))
   (parse-args ws)             ; -> a tablet: 'file, 'emit, 'help, 'ver, 'var, 'pos (the recipe words, in order)
   ((: (loop ws opt) (? !(two? ws) opt
       (: w <ws r >ws
          (? (w = "-f" || w = "--file") (: _ (need-arg w r) _ (pin opt 'file <r) (loop >r opt))
             (w = "-C" || w = "--directory") (: _ (need-arg w r) _ (pin opt 'dir <r) (loop >r opt))
             (w = "-j" || w = "--jobs")
                (? ((two? r) && (jobword? <r)) (: _ (pin opt 'jobs (jobn <r)) (loop >r opt))
                   (: _ (pin opt 'jobs (jobauto 0)) (loop r opt)))
             ((2 < tally w) && ("-j" = snip w 0 2))          ; glued: -j8
                                             (: _ (pin opt 'jobs (jobn (snip w 2 #w))) (loop r opt))
             ((w = "-n") || (w = "--dry-run") || (w = "--just-print"))
                                                  (: _ (pin opt 'dry 1) (loop r opt))
             (w = "--emit")                                       (: _ (pin opt 'emit 1) (loop r opt))
             ((w = "-h") || (w = "--help") || (w = "help"))      (: _ (pin opt 'help 1) (loop r opt))
             ((w = "-v") || (w = "--version") || (w = "version")) (: _ (pin opt 'ver 1) (loop r opt))
             ; make's -s is .SILENT for the run; the directory chatter flags have nothing to do
             ((w = "-s") || (w = "--silent") || (w = "--quiet"))
                                                  (: _ (pin opt 'var (peep opt 'var () + [(".SILENT" . "1")])) (loop r opt))
             ((w = "--no-print-directory") || (w = "-w") || (w = "--print-directory")) (loop r opt)
             ((0 < tally w) && (w 0 = 45))                     ; any other dash word is a flag, never a recipe
                                                  (say err ("cook: unknown option " + w), put err 10, quit 2)
             (: vw (varw w)
                (? (two? vw) (: _ (pin opt 'var (peep opt 'var () + [vw])) (loop r opt))
                   (: _ (pin opt 'pos (peep opt 'pos () + [w])) (loop r opt))))))))
    ws (tablet 0))

   ; -- cook-main (this form's body answers it) --
   ; the whole job from the args: parse flags, find the build file, cook, and exit first (quit),
   ; so a -l preload's CLI driver never tries to read the chosen file as love source. a Makefile
   ; is imported and its recipes cooked; a Cookfile is read and evaluated -- it drives cook
   ; itself, the ticket read live by (ticket 0) from the tickets box.
   ; it splices its own layer first, and owns that for every caller: a Cookfile is love source
   ; read at runtime, so its bare (recipe ..) (cook-all 0) (ticket 0) only resolve on the walk.
   (cook-main as)
   (: _ (? !(nil? (cite 'cook)) (borrow 'cook) 0)  ; splice my registered self if I am one; riding
                                                ; a cat my names walk already, and the guard keeps the loader out
      ; ..and posix beside it: a global name reads the live book (love/ev.c's lvm_index), and this
      ; is called on a chain that carries neither -- nothing else puts back its loading doors.
      _ (borrow 'posix)
      opt (parse-args as)
      _ (? (peep opt 'help 0) (usage 0) 0)
      _ (? (peep opt 'ver 0) (version 0) 0)
      ; -C DIR: the cook runs there -- discovery, the build file, every recipe -- as make's does
      _ (: d (peep opt 'dir 0)
           (? (!d || !(nom? (chdir d))) 0
              (: _ (say err ("cook: cannot cd to " + d)) _ (put err 10) (quit 2))))
      _ (pin clivars 0 (peep opt 'var ()))                   ; the VAR=VAL words, for seed-defaults
      _ (pin jobs 0 (peep opt 'jobs 1))                      ; the -j width; 1 is the serial cook
      ; ..and the width goes down the environment, for a recipe that forks on its own account.
      ; not a jobserver: nothing is handed back, so it is a hint and no claim on this pool.
      _ (setenv "COOKJOBS" (show (jobw ())))
      _ (pin dryrun 0 (peep opt 'dry 0))                     ; -n: say the steps, run none
      emit? (peep opt 'emit 0)
      pos (peep opt 'pos ())
      xf (peep opt 'file 0)                                       ; an explicit -f file (0 if none)
      _ (? (xf && !(exists? xf)) (: _ (say err ("cook: cannot open " + xf)) _ (put err 10) (quit 1)) 0)
      ; a positional is a recipe wherever discovery can name the build file itself; the back-compat
      ; form is kept for the case it was written for, a build file discovery cannot find.
      disc0 (? xf 0 (discover 0))                                    ; what discovery would name, if anything
      posfile (? (!xf && two? pos && exists? <pos && (? disc0 (disc0 = <pos) 1)) <pos 0)
      file (? xf xf (? posfile posfile (: _ (autoregen 0) (discover 0))))     ; discovery may auto-regen a stale Cookfile from a newer Makefile
      _ (pin tickets 0 (? posfile >pos pos))                 ; the recipe words; the positional file is not a recipe
      (? emit?
         (: _ (? file 0 (: _ (say err "cook: --emit needs a Makefile") _ (put err 10) (quit 1)))
             q (open file "r")
             _ (pin emitp 0 1)
             _ (register-makefile (slurp q))
             _ (emit-cookfile out)
             (quit 0))
         file
         (: q (open file "r")
            _ (? (asmake? file xf)
                 (: _ (register-makefile (slurp q)) (cook-all 0))
                 ((: (g x) (: r (sound x)
                                  (? (two? r) (: _ (ev 'ev <r) (g >r))
                                     (= r 'torn)
                                       (: _ (say err ("cook: unfinished form in " + file))
                                          _ (put err 10) (quit 1))
                                     0)))
                   (slurp q)))
            (quit 0))
         (two? pos)
         (: _ (say err "cook: no Cards.l, Cookfile or Makefile found") _ (put err 10) (quit 1))
         0))

   cook-main)

   cook-main _)

; the seat (apps/ain.l's shape): fire cook-main iff this file -- or the installed `cook` symlink
; -- sits in the program seat of the real command line, taking the args after the seat. cmdline
; is the full C argv, never rebound, so the read is the same in both load orders; inside the
; multi-call `kore` nothing matches and kore's dispatcher calls cook-main itself.
; cook-main reads bare here: the module's layer holds this file's binds and is still the head.
(: _ (pins (cite 'verbs 'tab) 'cook cook-main)
   s (cite 'verbs 'fire ["cook" "cook.l"])
   (? (two? s) (cook-main >s) ()))

) ; module 'cook
