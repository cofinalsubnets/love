; test/host/web.l -- `love web`'s maker (src/apps/kiosko/web.l), driven with no socket;
; the server half is test/host/kiosko.l's
; run: cat test/00-init.l test/host/web.l | out/love

(borrow "src/apps/vi/config.l")                    ; the theme: hue-theme
(borrow "src/apps/vi/hue.l")                       ; the class table, read bare by hueweb
(borrow 'lapiz)                                ; the document lens, read bare by web
(borrow 'libra)                                ; ..and the header lifter, likewise
(borrow 'hueweb)
(borrow 'kiosko)
(borrow 'web)

(test
 (elem 'web (cite ()))
 (elem 'web-main (keys (cite 'web)))
 (lit? (peep (cite 'verbs 'tab) 'web ())))

; the maker joins root and path itself, so the fixture is a real directory
(: dir "/tmp/servetest"
   _ (mkdir dir 493)
   (spit p s) (open (dir + p) "w" @ q (say q s, close q))
   _ (spit "/x.l" "; a comment\n(: x 1)\n")
   _ (spit "/d.md" "# a head\n\nsome *prose*.\n")
   _ (spit "/plain.txt" "not mine\n")
   box {}
   ; the maker takes the request head too: a navigation wants the painted page, a fetch() the
   ; source. short an arg it answers a partial, so every claim would read as refused
   nav "GET / HTTP/1.1\r\nHost: x\r\nsec-fetch-dest: document\r\n\r\n"
   fet "GET / HTTP/1.1\r\nHost: x\r\nsec-fetch-dest: empty\r\n\r\n"
   (mk p)    (sv-make dir box p nav)
   (fetch p) (sv-make dir box p fet)

   ((mk "/x.l" @ r
     (test (two? r)
           (<r = "text/html; charset=utf-8")
           (has? <>r "class=\"l-comment\"")        ; painted, by hue's own table
           (has? <>r "id=\"L1\"")
           (has? <>r "/hue.css"),
      0)),
    (mk "/d.md" @ r
     (test (two? r)
           (<r = "text/html; charset=utf-8")
           (has? <>r "<h1>a head</h1>")
           (has? <>r "<em>prose</em>"),
      0)),
    ; `.l.md` is claimed before `.md`: the .l's header as a document
    (mk "/x.l.md" @ r
     (test (two? r)
           (has? <>r "<h1>/x.l</h1>")
           (has? <>r "a comment")
           (has? <>r "href=\"/x.l\""),
      0)),
    ; a file with no header says so, rather than serving a blank page
    (: _ (spit "/bare.l" "(: x 1)\n")
       r (mk "/bare.l.md")
       (test (two? r) (has? <>r "no header comment"),
        0)),
    (mk "/hue.css" @ r
     (test (two? r)
           (<r = "text/css; charset=utf-8")
           (has? <>r ".hue .l-comment{color:#"),  ; the theme join, not a guess
      0)),

    ; () is "not mine": kiosko then serves the file or says 404
    test (() = mk "/plain.txt")
         (() = mk "/")                                ; the listing stays kiosko's
         (() = mk "/nothing.l"),                   ; ..and a .l that is not there

    ; a fetch() gets the source, never html
    (fetch "/x.l" @ r
     (test (two? r)
           (<r = "text/plain; charset=utf-8")
           (has? <>r "; a comment")
           !(has? <>r "class=\"l-comment\""),
      0)),
    ; ..but a .l.md is made either way
    (fetch "/x.l.md" @ r
     (test (two? r) (<r = "text/html; charset=utf-8"),
      0)),

    ; the cache, keyed by mtime and size, in memory
    (: a (mk "/x.l")
       b (mk "/x.l")
       (test (<>a = <>b),
        0)),
    0))

(test_fin (),
 puts "lib/serve: ok -- the maker (painted .l, its header, a rendered .md, the css, and ())
",
 0)
