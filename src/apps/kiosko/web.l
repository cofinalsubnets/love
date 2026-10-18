; src/apps/kiosko/web.l -- `love web`: the tree, in a browser, painted on the way out.
;
;   love web [-p [ip:]port] [-n] [DIR]     DIR defaults to the working directory
;
; kiosko's static serving plus one hook: *.l painted (hueweb.l) for a browser navigating
; here, the file itself for a fetch() (sv-doc?); *.l.md its header as a document;
; *.md rendered through lapiz; /hue.css. pages are boxed until the file's stamp moves.
; where DIR is the tree, the github page is laid through our own make first; a bare
; DIR gets the source aboard laid under it.
(module (web web-main sv-make)
(borrow 'libra)
(borrow 'hueweb)
(borrow 'lapiz)
(borrow 'path)

(borrow 'posix)
(:
   (sv-rdf p) (uread p @ [1 s] (string? s && [1 s]) ())

   ; the cache key: an edit moving neither mtime nor size is one nobody can see
   (sv-stamp p) (stat p @ st (two? st ? (<>st + <st * 7) 0))

   ; the box: `(stamp html) per path, replaced when the stamp moves.
   (sv-cached box p make)
   (: k (sv-stamp p) e (box p) (two? e && <e = k ? <>e (make () @ h (pin box p [k h], h))))

   ; the nav line: up to the directory, across to the file's other reading (alt is
   ; `(href text) or ()). the path is the request's, so it is escaped
   (sv-q s) (cite 'kiosko 'hesc s)
   (sv-href s) (sv-q (cite 'kiosko 'penc s))
   (sv-nav path alt)
   ("<p class=\"srcnav\"><a href=\"" + sv-href (phead path) + "\">" + sv-q (phead path) + "</a> &middot; "
    + sv-q path
    + (two? alt ? (" &middot; <a href=\"" + sv-href <alt + "\">" + sv-q <>alt + "</a>") "") + "</p>\n")
   (sv-page path body alt) (hw-page path '("/hue.css") "/" (sv-nav path alt + body))

   ; one markdown file through lapiz
   (sv-doc path src alt) (sv-page path (htshow (mdread src)) alt)

   ; ..and a .l's header as a document: libra lifts it, lapiz shows it
   (sv-head path src)
   (ldoc-md src @ md
      (0 < #md ? ("# " + path + "\n\n" + md)
         ("# " + path + "\n\nthis file has no header comment.\n")))

   ; a case-blind substring walk; the needle comes in lowercase
   (sv-in? h t)
   (:- (g 0) n #h m #t
    (fold c) (65 <= c <= 90 ? (c + 32) c)
    (at i j) (? (m <= j) 1
                (fold (h (i + j)) = t j) (at i (j + 1))
                0)
    (g i) (? (n - m < i) 0
             (at i 0) 1
             (g (i + 1))))

   ; painted, or the file itself? a navigation wants the page; a fetch() wants the source
   ; (html there wedges the repl island). sec-fetch-dest says which; absent it, an Accept
   ; naming text/html, so curl and every fetch read the file.
   (sv-doc? head)
    (sv-in? head "sec-fetch-dest:" ?
     (sv-in? head "sec-fetch-dest: document")
     (sv-in? head "text/html"))

   ; the hook: `(ctype body), or () for "not mine". `.l.md` is tested before `.md`.
   (sv-make root box p head)
   (: hd? (ends? p ".l.md")
      md? (ends? p ".md")
      src (hd? ? (snip p 0 (#p - 3)) p)
      (? (p = "/hue.css") ["text/css; charset=utf-8" (hw-css 'paper)]
         !(md? || ends? p ".l") ()
         (: f (root + src)
            r (sv-rdf f)
            (? (atom? r) ()                       ; let kiosko say 404
               ; a .l.md has no file behind it, so it is always made
               !(hd? || sv-doc? head) ["text/plain; charset=utf-8" <>r]
               ["text/html; charset=utf-8"
                (sv-cached box p
                  (_ \ (? hd? (sv-doc p (sv-head src <>r) [src "the source"])
                          md? (sv-doc p <>r ())
                          (sv-page p (hw-body p <>r) [(p + ".md") "the header, as a document"]))))]))))

   sv-usage "usage: love web [-p [IP:]PORT] [-n] [DIR]
serve a source tree to a browser
  -p, --port PORT   listen on PORT (default 8080, on 127.0.0.1); IP:PORT picks the address
  -n, --no-build    serve DIR as it is
  DIR               the tree (default .); with no tree there, this binary's source is laid out first
"
   (sv-die c m) (udie c ("web: " + m))

   ; the nest under DIR (source.l's src-nest), laid now where there is none
   (sv-root dir) (cite 'source 'src-root dir)
   (sv-lay dir)  (cite 'source 'src-nest dir)

   ; the page's build, only where DIR is the tree; a refused build stops the server
   (sv-tree? dir) (two? (stat (dir + "/Makefile")) && two? (stat (dir + "/index.html")))
   ; autonomous, as `love doom` is (src-arm): our verbs first on PATH, CC mooncc, and
   ; LOVE= names this binary, so only the wasm module is compiled.
   (sv-build dir)
   (: exe (selfpath 0)
      _ (string? exe ? 0 (sv-die 1 "can't find my own path"))
      _ (cite 'source 'src-arm dir exe)
      ; site-wasm builds the module through its own recipe; asked by name at the top it
      ; would take the x64 lane's
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
      ; DIR is positional, so a stray flag would become a tree laid under its name
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
      ; the tree: DIR, the nest laid under it, or laid now; -n serves a bare dir as is
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

   ; the verb, and fired when `serve` or serve.l is named on a command line
   door (udoor 'web (urun web-main) sv-usage 1 1)
   _ (cite 'verbs 'enlist 'web door ())
   s (cite 'verbs 'fire ["serve" "serve.l"])
   _ (two? s && quit (door >s)))
) ; module web
