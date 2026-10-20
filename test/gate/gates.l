; test/gate/gates.l -- the cat|sh gates in one love. each row's files arrive by `borrow` on a
; path, a layer of its own spliced in, so a row's parts see each other as `cat` let them. the
; verdict comes off the harness's state. test/00-init.l loads first: one tablet counts every row.
; it lives here, not in test/: $t globs test/*.l, so a driver there would join the corpus.
(: _ (borrow 'posix)
   _ (borrow "test/00-init.l")

   ; our own say1: kore's would splice the whole u-floor into the layer the rows load into
   (say1 s) (puts s, putc 10)

   ; FIRST, on purpose: vi's hue.l asks the ambient book (`const`, `book`), so these rows want
   ; the book a fresh process would hand them.
   early [['vi "src/apps/kore/text.l" "src/apps/kore/u.l" "src/apps/kore/core.l" "src/apps/kore/re.l"
           "src/apps/kore/sed.l" "src/apps/libra/lint.l" "src/apps/vi/config.l" "src/apps/vi/hue.l" "src/apps/vi/hues.l"
           "src/apps/vi/core.l" "test/law/vi.l"]]

   ; a row is [name path ..]. borrow reads a path once, so a file two rows want splices twice
   rows [['lux "src/apps/lux/core.l" "src/apps/lux/layout.l" "src/apps/lux/wire.l" "src/apps/lux/ewmh.l"
          "src/apps/lux/manage.l" "src/apps/lux/keys.l" "src/apps/lux/config.l" "test/law/lux.l"]
         ; LAST, on purpose: harp's module exports `rev` (pattern reverse), and borrow splices it into
         ; the caller's layer, so any later row that reverses a list gets a pattern back, silently.
         ['harp "src/apps/harp/harp.l" "src/apps/harp/play.l" "test/law/harp.l"
                "src/apps/harp/just.l" "src/apps/harp/drift.l" "src/apps/harp/tonnetz.l" "test/law/drift.l"]]

   ; host-nif smokes are not rows: a row that calls `quit` ends the shared process and still exits
   ; 0 (bake, cook, luxui and salt each carry one). grep a candidate for `(quit` before adding it.
   all (early + rows)

   ; a row's verdict is the fail list's growth, not its stdout; a row that ran no test fails too.
   ; the cwd is restored after every row, or a row that chdirs breaks the next relative borrow.
   (nfail u) (test_get 'fail @ f (two? f ? #f 0))
   (row r)
    (: nm <r
       f0 (nfail ()) c0 (test_get 'count) here (cwd ())
       _ (each >r borrow)
       _ (string? here ? (chdir here) 0)
       df (nfail () - f0) dc (test_get 'count - c0)
       (say1 ("gates: " + show nm + " " + show dc + " tests, " + show df + " failed"),
        (? (0 < df) 1 (0 = dc) (say1 ("gates: " + show nm + " ran NO test"), 1) 0)))

   ; a tail of row names runs just those (`make test_lux` asks for lux); none runs the lot, early first
   want (map intern >argv)
   pick (want ? (filter (r \ (elem <r want)) all) all)
   miss (filter (n \ (nelem n (map cap all))) want)
   _ (each miss (n \ (say1 ("gates: no row named " + show n))))
   bad (miss ? #miss 0 + net (map row pick))
   (say1 (0 < bad ? ("gates: " + show bad + " rows failed") "gates: ok"),
    quit (0 < bad ? 1 0)))
