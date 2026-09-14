; a/kiosko/web.l -- `love web`: the tree, in a browser, painted on the way out.
;
;   love web [-p port] [--doom] [DIR]      DIR defaults to the working directory
;
; kiosko already serves a directory and lists what it holds. what this adds is one
; hook, and three answers through it:
;
;   *.l        the painted source -- syntax coloured, one span per line, every
;              line linkable (a/vi/hueweb.l). only for a browser NAVIGATING here:
;              a fetch() and a bare client read the file itself (sv-doc?)
;   *.l.md     that file's header comment as a document -- libra lifts it, lapiz
;              shows it, and the two pages link to each other
;   *.md       the rendered document -- markdown through lapiz's html surface
;   /hue.css   the stylesheet that colours both
;
; everything else is kiosko's ordinary static serving, directory listings and all.
; nothing is written to disk and nothing is generated ahead of time -- a page is
; built at request time and held in a box until its file's stamp moves.
;
; no papel here, so a rendered .md is the document and not a site page: no title,
; anchors, contents nav or cross-link rewriting. `make site` still builds a site.
;
; and the github page: its files are generated -- make web lays index.html and w/,
; make wasm the module and its image, site-wasm copies them beside the loader, and the
; wasm inle seat (i/wasm/inle.html) is its own module -- and .sbignore drops every one
; from the source, so a checkout serves nothing of it until they are laid. where DIR is
; the tree (a Makefile and w/index.l), this lays them through our own make first; where
; it is a bare directory the source aboard is laid under it (`love source`) and that tree
; is built and served. this binary drives the build and no love is compiled for it. the
; --doom fetches doomgeneric and the shareware IWAD into the nest's dl/ (a/doom.l's pair)
; for the machine to fetch: `doom` at its shell lays the source, builds the game aboard
; and boots what it built. the page's own module is laid plain either way -- a game inside
; it would answer `doom` at once and the build would never run. the two isolation headers
; kiosko's reply sends are what let inle.html's machine run here without its service worker.
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
   (sv-ends? s t) (: n #s m #t (m <= n && snip s (n - m) n = t))
   (sv-rdf p) (: q (open p "r") (hot? q && (: s (slurp q) _ (close q) (string? s && [1 s]))))
   ; the directory a path sits in, as a link back up: "/a/b/c.l" -> "/a/b/"
   (sv-up p) (snip p 0 (lastslash p))

   ; the cache key: an edit that moves neither mtime nor size is one nobody can see
   (sv-stamp p) (: st (stat p) (two? st ? (<>st + <st * 7) 0))

   ; ..and the box it lives in: `(stamp html) per path, replaced when the stamp moves.
   (sv-cached box p make)
   (: k (sv-stamp p)
      e (box p)
      (? (two? e && <e = k) <>e
         (: h (make ())
            _ (pin box p [k h])
            h)))

   ; the nav line every page wears: up to the directory, across to the file's
   ; other reading. alt is `(href text), or () where there is no other reading.
   (sv-nav path alt)
   ("<p class=\"srcnav\"><a href=\"" + sv-up path + "\">" + sv-up path + "</a> &middot; " + path
    + (two? alt ? (" &middot; <a href=\"" + <alt + "\">" + <>alt + "</a>") "") + "</p>\n")
   (sv-page path body alt) (hw-page path '("/hue.css") "/" (sv-nav path alt + body))

   ; one markdown file: lapiz reads it, shows it, the same template holds it
   (sv-doc path src alt) (sv-page path (htshow (mdread src)) alt)

   ; ..and a .l's header as a document: libra lifts it, lapiz shows it
   (sv-head path src)
   (: md (ldoc-md src)
      (? (0 < #md) ("# " + path + "\n\n" + md)
         ("# " + path + "\n\nthis file has no header comment.\n")))

   ; a case-blind substring walk over the request head; the needle comes in lowercase
   (sv-in? h t)
   (: n #h m #t
      (fold c) (65 <= c <= 90 ? (c + 32) c)
      (at i j) (? (m <= j) 1
                  (fold (h (i + j)) = t j) (at i (j + 1))
                  0)
      (g i) (? (n - m < i) 0
               (at i 0) 1
               (g (i + 1)))
      (g 0))

   ; painted, or the file itself? a browser NAVIGATING to a .l wants the page; a fetch()
   ; from one of our own pages wants the source it asked for, and handing it html is how
   ; the repl island ate a `<!doctype` and wedged. sec-fetch-dest says which -- browsers
   ; send it on every request, `document` only for a navigation -- and where it is absent
   ; an Accept naming text/html is the older tell, so curl and every fetch read the file.
   (sv-doc? head)
   (? (sv-in? head "sec-fetch-dest:") (sv-in? head "sec-fetch-dest: document")
      (sv-in? head "text/html"))

   ; the hook: `(ctype body) to serve, () to say "not mine". `.l.md` is tested
   ; first because that path ends in `.md` as much as it ends in `.l.md`.
   (sv-make root box p head)
   (: hd? (sv-ends? p ".l.md")
      md? (sv-ends? p ".md")
      src (hd? ? (snip p 0 (#p - 3)) p)            ; "/x.l.md" -> "/x.l"
      (? (p = "/hue.css") ["text/css; charset=utf-8" (hw-css 'paper)]
         !(md? || sv-ends? p ".l") ()
         (: f (root + src)
            r (sv-rdf f)
            (? !(two? r) ()                       ; not there: let kiosko say 404
               ; ..and a .l.md is a rendering with no file behind it, so it is always made
               !(hd? || sv-doc? head) ["text/plain; charset=utf-8" <>r]
               ["text/html; charset=utf-8"
                (sv-cached box p
                  (\ _ (? hd? (sv-doc p (sv-head src <>r) [src "the source"])
                           md? (sv-doc p <>r ())
                           (sv-page p (hw-body p <>r) [(p + ".md") "the header, as a document"]))))]))))

   sv-usage "love web -- the tree in a browser, painted on the way out
usage: love web [-p PORT] [-n] [DIR]
  -p, --port PORT   the port to listen on (default 8080)
  -n, --no-build    serve DIR as it is
  DIR               the tree to serve (default .)
a .l is painted, a .md rendered, and x.l.md is x.l's header as a document. the github
page is laid first -- make web site-wasm -- and the machine is at /i/wasm/inle.html.
where DIR is no tree the source aboard is laid under it first (`love source`) and that
tree is served. this binary drives the page's build; no love is compiled for it.
"
   (sv-die c m) (: _ (say err ("web: " + m)) _ (put err 10) (quit c))

   ; the nest under DIR (a/source.l's src-nest): the tree seed, doom and web share, laid
   ; once, and where there is none the source aboard is laid there now
   (sv-root dir) ((cite 'source 'src-root) dir)
   (sv-lay dir)  ((cite 'source 'src-nest) dir)

   ; the page's build, through our own make in DIR: only where DIR is the tree, and
   ; a refused build is said and stops the server -- a page half laid is not one
   (sv-tree? dir) (two? (stat (dir + "/Makefile")) && two? (stat (dir + "/w/index.l")))
   ; autonomous throughout, as `love doom` is (a/source.l's src-arm): our verbs first on
   ; PATH, lush -a, CC our mooncc. LOVE= names US as the driving love, so love0 is a
   ; two-line script onto this binary and no second love is compiled to lay a page --
   ; only the wasm module, which is the one thing here that is not already aboard.
   (sv-build dir)
   (: exe (selfpath 0)
      _ (string? exe ? 0 (say err "web: can't find my own path\n", quit 1))
      _ ((cite 'source 'src-arm) dir exe)
      ; the module is site-wasm's to build, through its own seat: asked for by name at
      ; the top it would be laid with the x64 lane's recipe and fail a file at a time
      _ (say err ";; laying the page: make web site-wasm\n")
      p (spawn [exe "make" "-C" dir ("LOVE=" + exe) "web" "site-wasm"])
      st (charm? p && 0 <= p ? (wait p) 1)
      (0 = st ? 0 (say err ("web: the page did not build (" + show st + ")\n"), quit 1)))

   (web-main as)
   (: box (tablet 0)
      t (tablet 0)
      o (uopt as t '(112) () {"port" 112 "no-build" 110 "doom" 100})
      _ (two? o ? 0 (sv-die 2 (last as + " needs an argument")))
      un (uoptun t '(112 110 100))
      _ (nil? un ? 0 (sv-die 2 ("unknown option -" + string un)))
      rest <>>o
      ; DIR is positional, so a flag that fell through would become one and a whole tree
      ; would be laid under its name
      sy (uoptstray as rest)
      _ (nil? sy ? 0 (sv-die 2 ("unknown option " + sy)))
      _ (two? >rest ? (sv-die 2 ("one tree at a time, not " + <>rest)) 0)
      pt (uoptv t 112)
      port (: v (unum pt) (? (nil? pt) 8080 (charm? v) v (sv-die 2 ("not a port: " + pt))))
      dir0 (two? rest ? <rest ".")
      build? (peep t 110 0 ? 0 1)
      doom? (peep t 100 0)
      ; the tree: DIR itself, the nest laid under it before, or laid there now.
      ; -n serves a bare directory as it is
      dir (? (sv-tree? dir0) dir0
             (sv-tree? (sv-root dir0)) (sv-root dir0)
             build? (sv-lay dir0)
             dir0)
      _ (? (doom? && build? && sv-tree? dir)
           ((cite 'doom 'doom-fetch) (dir + "/dl") (cite 'doom 'wad-url) (cite 'doom 'dg-url)
            ? (sv-die 1 "the doom downloads did not land") 0)
           0)
      _ (build? && sv-tree? dir ? (sv-build dir) 0)
      serve5 (cite 'kiosko 'serve5)
      _ (nil? serve5 ? (say err "web: no kiosko aboard\n", quit 1))
      _ (sv-tree? dir ? (say err ("web: " + dir + " -- the page is http://127.0.0.1:" + show port
                                  + "/ and the machine /i/wasm/inle.html\n")) 0)
      _ (? (serve5 dir port 0 () (sv-make dir box)) 0
           (: _ (say err ("web: cannot listen on :" + show port)) _ (put err 10) (quit 1)))
      (quit 0))

   ; the verb, and the seat (kiosko's shape): `love web ..` on the artifact, or
   ; this file named on a command line, and neither needs a script
   door (udoor 'web web-main sv-usage 1 1)
   _ (pins (cite 'verbs 'tab) 'web door)
   s ((cite 'verbs 'fire) ["serve" "serve.l"])
   _ (two? s && door >s))
) ; module serve
