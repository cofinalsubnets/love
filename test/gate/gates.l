; test/gates.l -- the cat|sh gates, in one love. each row names the files it wants; they
; arrive by `borrow` on a PATH, which reads a file into a layer of its own and splices it,
; so a row's parts see each other exactly as `cat` let them. the verdict comes off the
; harness's own state: run.sh had to grep the red X back out of love's stdout, because a
; pipe was the only thing a shell could see.
;
; test/00-init.l comes first and stays: `test` publishes globally (`::`, `hear`) and the
; tablet it records into is one, so a single count covers every row.
(: _ (borrow 'posix)
   _ (borrow "test/00-init.l")

   ; our own line-sayer: kore's say1 would want the whole u-floor spliced into the layer
   ; the rows load into, and this file's job is to keep that layer thin.
   (say1 s) (: _ (puts s) (putc 10))

   ; a row is [name path ..]. borrow marks a path once read, so a file two rows both want
   ; loads once and splices twice -- which is what the separate processes used to pay for.
   rows [['lux "apps/lux/core.l" "apps/lux/layout.l" "apps/lux/wire.l" "apps/lux/ewmh.l"
          "apps/lux/manage.l" "apps/lux/keys.l" "apps/lux/config.l" "apps/lux/law.l"]
         ['harp "apps/harp/harp.l" "apps/harp/play.l" "apps/harp/law.l"]]
   ; NOT a row: apps/vi/law.l's hue half asks the LIVE book what a word is -- (b "map")
   ; = 'book -- and `names` walks the whole chain, so a layer of its own does not hide
   ; what another row loaded. it passes alone and fails beside lux, which is the one
   ; thing a shared process cannot give it. its lane stays until the laws carry a book.

   ; a row's verdict is the fail list's length before and after, not its stdout: a row that
   ; recorded nothing new passed, whatever it printed. the count moves too, so a row that
   ; ran no test at all is caught here -- which is what run.sh's sentinel string was for.
   (nfail u) (: f (test_get 'fail) (? (two? f) #f 0))
   (row r)
    (: nm <r
       f0 (nfail ()) c0 (test_get 'count)
       _ (each >r borrow)
       df (nfail () - f0) dc (test_get 'count - c0)
       _ (say1 ("gates: " + show nm + " " + show dc + " tests, " + show df + " failed"))
       (? (0 < df) 1 (0 = dc) (: _ (say1 ("gates: " + show nm + " ran NO test")) 1) 0))

   ; a tail of row names runs just those, so every lane keeps a name of its own to be run
   ; by -- `love test/gates.l lux` is what `make test_lux` asks for, and the make target
   ; stays. no tail runs the lot.
   want (map intern >argv)
   pick (? want (filter (\ r (member? <r want)) rows) rows)
   miss (filter (\ n !(member? n (map cap rows))) want)
   _ (each miss (\ n (say1 ("gates: no row named " + show n))))
   bad (miss ? #miss 0 + net (map row pick))
   _ (say1 (0 < bad ? ("gates: " + show bad + " rows failed") "gates: ok"))
   (quit (0 < bad ? 1 0)))
