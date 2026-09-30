; test/host/web.l -- `love web`'s maker (src/apps/kiosko/web.l), driven directly with no socket:
; *.l the painted source, *.l.md its header as a document, *.md rendered, /hue.css the sheet,
; anything else (), so kiosko does what it always did. the server half is test/host/kiosko.l's.
; run: cat test/00-init.l test/host/web.l | out/love

(borrow "src/apps/vi/config.l")                    ; the theme: hue-theme
(borrow "src/apps/vi/hue.l")                       ; the class table, read bare by hueweb
(borrow 'lapiz)                                ; the document lens, read bare by serve
(borrow 'libra)                                ; ..and the header lifter, likewise
(borrow 'hueweb)
(borrow 'kiosko)
(borrow 'web)

; --- the seam -----------------------------------------------------------------
(test
 (elem 'web (cite ()))
 (elem 'web-main (keys (cite 'web)))
 ; the verb is registered, which is what makes `love web` a word on the artifact
 (lit? (peep (cite 'verbs 'tab) 'web ())))

; a scratch tree to answer for. the maker takes a root and a path and joins them
; itself, so the fixture is a real directory and the test asks for real paths.
(: dir "/tmp/servetest"
   _ (mkdir dir 493)
   (spit p s) (open (dir + p) "w" @ q (say q s, close q))
   _ (spit "/x.l" "; a comment\n(: x 1)\n")
   _ (spit "/d.md" "# a head\n\nsome *prose*.\n")
   _ (spit "/plain.txt" "not mine\n")
   box {}
   ; the maker takes the request head as well as the path: a browser navigating to a
   ; .l wants the painted page, a fetch() wants the source. an arity short of that does
   ; not fail -- it answers a partial, which is not two?, so every claim reads as refused.
   nav "GET / HTTP/1.1\r\nHost: x\r\nsec-fetch-dest: document\r\n\r\n"
   fet "GET / HTTP/1.1\r\nHost: x\r\nsec-fetch-dest: empty\r\n\r\n"
   (mk p)    (sv-make dir box p nav)
   (fetch p) (sv-make dir box p fet)
   (sub? s t) (: n #s m #t
                 ((: (g i) (i + m <= n ? (snip s i (i + m) = t ? 1 (g (i + 1))) 0)) 0))

   ; --- the three it answers for ----------------------------------------------
   ((mk "/x.l" @ r
     (test (two? r)
           (<r = "text/html; charset=utf-8")
           (sub? <>r "class=\"l-comment\"")        ; painted, by hue's own table
           (sub? <>r "id=\"L1\"")                  ; and every line is linkable
           (sub? <>r "/hue.css"),                 ; ..with the stylesheet that colours it
      0)),
    (mk "/d.md" @ r
     (test (two? r)
           (<r = "text/html; charset=utf-8")
           (sub? <>r "<h1>a head</h1>")            ; rendered, through lapiz
           (sub? <>r "<em>prose</em>"),
      0)),
    ; `.l.md` is claimed before `.md`, and reads the .l with the suffix off. the
    ; two pages link to each other, which is the whole reason the nav line exists.
    (mk "/x.l.md" @ r
     (test (two? r)
           (sub? <>r "<h1>/x.l</h1>")              ; the file names the document
           (sub? <>r "a comment")                  ; ..and its header is the document
           (sub? <>r "href=\"/x.l\""),           ; ..with the way back to the source
      0)),
    ; a file with no header says so, rather than serving a blank page
    (: _ (spit "/bare.l" "(: x 1)\n")
       r (mk "/bare.l.md")
       (test (two? r) (sub? <>r "no header comment"),
        0)),
    (mk "/hue.css" @ r
     (test (two? r)
           (<r = "text/css; charset=utf-8")
           (sub? <>r ".hue .l-comment{color:#"),  ; the theme join, not a guess
      0)),

    ; --- and the ones it refuses -----------------------------------------------
    ; () is the whole of "not mine": kiosko then serves the file, or says 404, and
    ; neither answer is this file's to give. a maker that answered for everything
    ; would take the static server away.
    test (() = mk "/plain.txt")                       ; a file it does not claim
         (() = mk "/")                                ; the listing stays kiosko's
         (() = mk "/nothing.l"),                   ; ..and a .l that is not there

    ; --- navigating, and fetching -----------------------------------------------
    ; the same path answers differently by head. handing a fetch() html is how the
    ; island ate a `<!doctype` and wedged, so the source is what a fetch gets.
    (fetch "/x.l" @ r
     (test (two? r)
           (<r = "text/plain; charset=utf-8")
           (sub? <>r "; a comment")                ; the file itself
           !(sub? <>r "class=\"l-comment\""),     ; ..not the painting
      0)),
    ; ..but a .l.md is a rendering with no file behind it, so it is made either way
    (fetch "/x.l.md" @ r
     (test (two? r) (<r = "text/html; charset=utf-8"),
      0)),

    ; --- the cache --------------------------------------------------------------
    ; keyed by the file's mtime and size, in memory, never on disk. the second ask
    ; is the same value, and rewriting the file answers the new one.
    (: a (mk "/x.l")
       b (mk "/x.l")
       (test (<>a = <>b),
        0)),
    0))

(test_fin (),
 puts "lib/serve: ok -- the maker (painted .l, its header, a rendered .md, the css, and ())
",
 0)
