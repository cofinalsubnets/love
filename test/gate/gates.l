; test/gate/gates.l -- the cat|sh gates, in one love. each row names the files it wants;
; they arrive by `borrow` on a PATH, which reads a file into a layer of its own and splices
; it, so a row's parts see each other exactly as `cat` let them. the verdict comes off the
; harness's own state: run.sh had to grep the red X back out of love's stdout, because a
; pipe was the only thing a shell could see.
;
; test/00-init.l comes first and stays: `test` publishes globally (`::`, `hear`) and the
; tablet it records into is one, so a single count covers every row.
;
; the file lives here, not in test/: $t (mk/common.mk) globs test/*.l non-recursively, so a
; driver named there joins the corpus.
(: _ (borrow 'posix)
   _ (borrow "test/00-init.l")

   ; our own line-sayer: kore's say1 would want the whole u-floor spliced into the layer
   ; the rows load into, and this file's job is to keep that layer thin.
   (say1 s) (: _ (puts s) (putc 10))

   ; FIRST, and the order is the point: these rows' subject IS the ambient book, so they
   ; want the one a fresh process would hand them. apps/vi/hue.l names its word lanes
   ; `macros`/`values`/`names` and asks each -- "grammar, not the book. a list would rot; a
   ; question cannot" -- so `const` (bound to a value) and `book` (in the book) are answers
   ; about whatever else is loaded. running before anything else is the whole of what a
   ; process of its own was buying.
   early [['vi "apps/kore/text.l" "apps/kore/u.l" "apps/kore/core.l" "apps/kore/re.l"
           "apps/kore/sed.l" "apps/libra/lint.l" "apps/vi/config.l" "apps/vi/hue.l"
           "apps/vi/core.l" "apps/vi/law.l"]]

   ; a row is [name path ..]. borrow marks a path once read, so a file two rows both want
   ; loads once and splices twice -- which is what the separate processes used to pay for.
   rows [['lux "apps/lux/core.l" "apps/lux/layout.l" "apps/lux/wire.l" "apps/lux/ewmh.l"
          "apps/lux/manage.l" "apps/lux/keys.l" "apps/lux/config.l" "apps/lux/law.l"]
         ; the host-nif smokes: one file each, and one layer each is what let them stop
         ; being 33 separate loves. their roster used to say they "leak helper names into
         ; the one global scope, so they run standalone" -- the leak is real and a layer
         ; is the answer to it.
         ['gcpause "test/host/gcpause.l"] ['wharf "test/host/wharf.l"]
         ['cb "test/host/cb.l"] ['manifest "test/host/manifest.l"]
         ['rune "test/host/rune.l"] ['pty "test/host/pty.l"]
         ['loader "test/host/loader.l"] ['rdiff "test/host/rdiff.l"]
         ['luxui "test/host/luxui.l"] ['berth "test/host/berth.l"]
         ['overlay "test/host/overlay.l"] ['bake "test/host/bake.l"]
         ['rove "test/host/rove.l"] ['lapiz "test/host/lapiz.l"]
         ['papel "test/host/papel.l"] ['kiosko "test/host/kiosko.l"]
         ['serve "test/host/serve.l"] ['sbhttp "test/host/sbhttp.l"]
         ['salt "test/host/salt.l"] ['libra "test/host/libra.l"]
         ['clay "test/host/clay.l"] ['tls "test/host/tls.l"]
         ['tlsc "test/host/tlsc.l"] ['gz "test/host/gz.l"]
         ['gzc "test/host/gzc.l"] ['story "test/host/story.l"]
         ['design "test/host/design.l"] ['lupa "test/host/lupa.l"]
         ['helm "test/host/helm.l"] ['wget "test/host/wget.l"]
         ['cook "test/host/cook.l"]
         ; LAST, and it has to be. harp's module exports `rev` -- the cycle algebra's
         ; pattern reverse -- along with stack, pure, range, cut, with and n. borrow
         ; splices a module's names into the caller's layer, so from here on `rev` is
         ; harp's, and a row that reverses a list gets a pattern back. rdiff ends
         ; rd-forms with (rev acc) and answered 0 forms instead of 1929: not an error, a
         ; WRONG ANSWER, which a process apiece is what kept anyone from seeing. ordering
         ; is containment, not a fix -- the fix is a scope door the harness can close.
         ['harp "apps/harp/harp.l" "apps/harp/play.l" "apps/harp/law.l"]]

   ; NOT rows, and each for a reason a shared process cannot answer:
   ;   test/host/run.l   its children inherit love's stdin, and under `cat |` that stdin
   ;                     IS the corpus pipe -- the cat was the scope AND the child's input.
   ;   test/host/sh.l    drives the built shell, which wants a love of its own to drive.
   ;   test/host/sb.l    wants out/.sbtest cleared first, which its own target does.
   all (early + rows)

   ; a row's verdict is the fail list's length before and after, not its stdout: a row that
   ; recorded nothing new passed, whatever it printed. the count moves too, so a row that
   ; ran no test at all is caught here -- which is what run.sh's sentinel string was for.
   ; the cwd goes back where it was after every row. a row that walks into a scratch
   ; directory and stays there breaks the next row's relative borrow, and losing the cwd
   ; is one of the things a process of its own used to hide.
   (nfail u) (: f (test_get 'fail) (? (two? f) #f 0))
   (row r)
    (: nm <r
       f0 (nfail ()) c0 (test_get 'count) here (cwd ())
       _ (each >r borrow)
       _ (? (string? here) (chdir here) 0)
       df (nfail () - f0) dc (test_get 'count - c0)
       _ (say1 ("gates: " + show nm + " " + show dc + " tests, " + show df + " failed"))
       (? (0 < df) 1 (0 = dc) (: _ (say1 ("gates: " + show nm + " ran NO test")) 1) 0))

   ; a tail of row names runs just those, so every lane keeps a name of its own to be run
   ; by -- `love test/gate/gates.l lux` is what `make test_lux` asks for, and the make
   ; target stays. no tail runs the lot, early first.
   want (map intern >argv)
   pick (? want (filter (\ r (member? <r want)) all) all)
   miss (filter (\ n !(member? n (map cap all))) want)
   _ (each miss (\ n (say1 ("gates: no row named " + show n))))
   bad (miss ? #miss 0 + net (map row pick))
   _ (say1 (0 < bad ? ("gates: " + show bad + " rows failed") "gates: ok"))
   (quit (0 < bad ? 1 0)))
