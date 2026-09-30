; src/apps/kiosko/web.l -- `love web`: the tree, in a browser, painted on the way out.
;
;   love web [-p [ip:]port] [-n] [DIR]     DIR defaults to the working directory
;
; kiosko's static serving plus one hook with three answers: *.l painted (hueweb.l; only
; for a browser navigating here, a fetch() gets the file itself -- sv-doc?), *.l.md its
; header comment as a document (libra lifts, lapiz shows), *.md rendered through lapiz,
; and /hue.css. pages are built at request time and boxed until the file's stamp moves.
; where DIR is the tree, the github page's laid files (icon, fonts, the wasm machine) are
; laid through our own make first; a bare DIR gets the source aboard laid under it.
; the page's module is laid plain: a game inside it would answer `doom` before the build.
;
; kiosko is a module: `cite` is the reach, and its miss is checked by name -- () applied
; to operands is 1, a miss that would read as a server that started.
(module (web web-main sv-make)
(borrow 'libra)
(borrow 'hueweb)
(borrow 'lapiz)
(borrow 'path)

(borrow 'posix)
(:
   (sv-rdf p) (uread p @ [1 s] (string? s && [1 s]) ())
   ; the directory a path sits in, as a link back up: "/a/b/c.l" -> "/a/b/"

   ; the cache key: an edit that moves neither mtime nor size is one nobody can see
   (sv-stamp p) (stat p @ st (two? st ? (<>st + <st * 7) 0))

   ; ..and the box it lives in: `(stamp html) per path, replaced when the stamp moves.
   (sv-cached box p make)
   (: k (sv-stamp p) e (box p) (two? e && <e = k ? <>e (make () @ h (pin box p [k h], h))))

   ; the nav line every page wears: up to the directory, across to the file's
   ; other reading. alt is `(href text), or () where there is no other reading.
   ; a path is the request's, so it is escaped for html and an href percent-encoded
   (sv-q s) (cite 'kiosko 'hesc s)
   (sv-href s) (sv-q (cite 'kiosko 'penc s))
   (sv-nav path alt)
   ("<p class=\"srcnav\"><a href=\"" + sv-href (phead path) + "\">" + sv-q (phead path) + "</a> &middot; "
    + sv-q path
    + (two? alt ? (" &middot; <a href=\"" + sv-href <alt + "\">" + sv-q <>alt + "</a>") "") + "</p>\n")
   (sv-page path body alt) (hw-page path '("/hue.css") "/" (sv-nav path alt + body))

   ; one markdown file: lapiz reads it, shows it, the same template holds it
   (sv-doc path src alt) (sv-page path (htshow (mdread src)) alt)

   ; ..and a .l's header as a document: libra lifts it, lapiz shows it
   (sv-head path src)
   (ldoc-md src @ md
      (0 < #md ? ("# " + path + "\n\n" + md)
         ("# " + path + "\n\nthis file has no header comment.\n")))

   ; a case-blind substring walk over the request head; the needle comes in lowercase
   (sv-in? h t)
   (:- (g 0) n #h m #t
    (fold c) (65 <= c <= 90 ? (c + 32) c)
    (at i j) (? (m <= j) 1
                (fold (h (i + j)) = t j) (at i (j + 1))
                0)
    (g i) (? (n - m < i) 0
             (at i 0) 1
             (g (i + 1))))

   ; painted, or the file itself? a browser NAVIGATING to a .l wants the page; a fetch()
   ; from one of our own pages wants the source it asked for, and handing it html is how
   ; the repl island ate a `<!doctype` and wedged. sec-fetch-dest says which -- browsers
   ; send it on every request, `document` only for a navigation -- and where it is absent
   ; an Accept naming text/html is the older tell, so curl and every fetch read the file.
   (sv-doc? head)
    (sv-in? head "sec-fetch-dest:" ?
     (sv-in? head "sec-fetch-dest: document")
     (sv-in? head "text/html"))

   ; the hook: `(ctype body) to serve, () to say "not mine". `.l.md` is tested
   ; first because that path ends in `.md` as much as it ends in `.l.md`.
   (sv-make root box p head)
   (: hd? (ends? p ".l.md")
      md? (ends? p ".md")
      src (hd? ? (snip p 0 (#p - 3)) p)            ; "/x.l.md" -> "/x.l"
      (? (p = "/hue.css") ["text/css; charset=utf-8" (hw-css 'paper)]
         !(md? || ends? p ".l") ()
         (: f (root + src)
            r (sv-rdf f)
            (? (atom? r) ()                       ; not there: let kiosko say 404
               ; ..and a .l.md is a rendering with no file behind it, so it is always made
               !(hd? || sv-doc? head) ["text/plain; charset=utf-8" <>r]
               ["text/html; charset=utf-8"
                (sv-cached box p
                  (_ \ (? hd? (sv-doc p (sv-head src <>r) [src "the source"])
                          md? (sv-doc p <>r ())
                          (sv-page p (hw-body p <>r) [(p + ".md") "the header, as a document"]))))]))))

   sv-usage "love web -- the tree in a browser, painted on the way out
usage: love web [-p [IP:]PORT] [-n] [DIR]
  -p, --port PORT   the port to listen on (default 8080), on 127.0.0.1 alone; IP:PORT
                    names the address, 0.0.0.0:PORT every one
  -n, --no-build    serve DIR as it is
  DIR               the tree to serve (default .)
a .l is painted, a .md rendered, and x.l.md is x.l's header as a document. the github
page is laid first -- make web site-wasm -- and the machine is the page, at /.
where DIR is no tree the source aboard is laid under it first (`love source`) and that
tree is served. this binary drives the page's build; no love is compiled for it.
"
   (sv-die c m) (udie c ("web: " + m))

   ; the nest under DIR (src/apps/source.l's src-nest): the tree seed, doom and web share, laid
   ; once, and where there is none the source aboard is laid there now
   (sv-root dir) (cite 'source 'src-root dir)
   (sv-lay dir)  (cite 'source 'src-nest dir)

   ; the page's build, through our own make in DIR: only where DIR is the tree, and
   ; a refused build is said and stops the server -- a page half laid is not one
   (sv-tree? dir) (two? (stat (dir + "/Makefile")) && two? (stat (dir + "/index.html")))
   ; autonomous throughout, as `love doom` is (src/apps/source.l's src-arm): our verbs first on
   ; PATH, lush -a, CC our mooncc. LOVE= names US as the driving love, so love0 is a
   ; two-line script onto this binary and no second love is compiled to lay a page --
   ; only the wasm module, which is the one thing here that is not already aboard.
   (sv-build dir)
   (: exe (selfpath 0)
      _ (string? exe ? 0 (sv-die 1 "can't find my own path"))
      _ (cite 'source 'src-arm dir exe)
      ; the module is site-wasm's to build, through its own seat: asked for by name at
      ; the top it would be laid with the x64 lane's recipe and fail a file at a time
      _ (say err ";; laying the page: make web site-wasm\n")
      p (spawn [exe "make" "-C" dir ("LOVE=" + exe) "web" "site-wasm"])
      st (charm? p && 0 <= p ? (wait p) 1)
      (st @ 0 0 (sv-die 1 ("the page did not build (" + show st + ")"))))

   (web-main as)
   (: box {}
      t {}
      o (uopt as t '(112) () {"port" 112 "no-build" 110})
      _ (atom? o && sv-die 2 (last as + " needs an argument"))
      un (uoptun t '(112 110))
      _ (un && sv-die 2 ("unknown option -" + string un))
      rest <>>o
      ; DIR is positional, so a flag that fell through would become one and a whole tree
      ; would be laid under its name
      sy (uoptstray as rest)
      _ (nil? sy ? 0 (sv-die 2 ("unknown option " + sy)))
      _ (two? >rest ? (sv-die 2 ("one tree at a time, not " + <>rest)) 0)
      pt (uoptv t 112)
      ; [IP:]PORT, loopback unless an address is named
      k (string? pt ? ((: (g i) (? (i < 0) -1 (pt i = 58) i (g (i - 1)))) (#pt - 1)) -1)
      ip (k < 1 ? "127.0.0.1" (snip pt 0 k))
      pn (string? pt ? (snip pt (k + 1) #pt))
      port (uport pn @ v (? !pn 8080 v v (sv-die 2 ("not a port: " + pt))))
      dir0 (two? rest ? <rest ".")
      build? (peep t 110 0 ? 0 1)
      ; the tree: DIR itself, the nest laid under it before, or laid there now.
      ; -n serves a bare directory as it is
      dir (? (sv-tree? dir0) dir0
             (sv-tree? (sv-root dir0)) (sv-root dir0)
             build? (sv-lay dir0)
             dir0)
      _ (build? && sv-tree? dir ? (sv-build dir) 0)
      serve5 (cite 'kiosko 'serve5)
      (nil? serve5 ? (udie 1 "web: no kiosko aboard"),
       sv-tree? dir ? (say err ("web: " + dir + " -- the page is http://" + ip + ":" + show port
                                + "/, the machine\n")) 0,
       serve5 dir [ip port] 0 () (sv-make dir box) @ r
         (nom? r ? (udie 1 ("web: cannot listen on " + ip + ":" + show port + " -- " + show r))),
       0))

   ; the verb, and the seat (kiosko's shape): `love web ..` on the artifact, or
   ; this file named on a command line, and neither needs a script
   door (udoor 'web (urun web-main) sv-usage 1 1)
   _ (cite 'verbs 'enlist 'web door ())
   s (cite 'verbs 'fire ["serve" "serve.l"])
   _ (two? s && quit (door >s)))
) ; module serve
