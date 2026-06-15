#!/usr/bin/env -S love -l
; cook -- make, in love.
;
; love reads the `#!` hashbang line above as a line comment (ai.c: `#!` runs to
; end of line, like `;`), so loading this file as a library is unaffected -- the
; same line serves the OS as a shebang. with the file marked executable and a `cook`
; symlink to it on PATH (the user installs that), running `cook Cards.l [ticket]`
; execs `love -l <this-file> Cards.l [ticket]`: the -l loads cook, then Cards.l runs.
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
; usage:  cook <Cards.l> [ticket]              (with the symlink installed)
;     or:  love -l tools/cook.l <Cards.l> [ticket]
; Cards.l is ordinary love source that lays out the recipes (recipe ..) then (cook (ticket 0)).

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
