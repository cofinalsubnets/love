; apps/kiosko/serve.l -- `love serve`: the tree, in a browser, painted on the way out.
;
;   love serve [-p port] [DIR]      DIR defaults to the working directory
;
; kiosko already serves a directory and lists what it holds. what this adds is one
; hook, and three answers through it:
;
;   *.l        the painted source -- syntax coloured, one span per line, every
;              line linkable (apps/vi/hueweb.l)
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
; and the github page: its files are generated -- make web lays index.html and assets/,
; make wasm the module and its image, site-wasm copies them beside the loader, and the
; wasm inle seat (port/wasm/inle.html) is its own module -- and .sbignore drops every one
; from the source, so a checkout serves nothing of it until they are laid. where DIR is
; the tree (a Makefile and web/index.l), this lays them through our own make first; the
; two isolation headers kiosko's reply sends are what let inle.html's machine run here
; without its service worker.
;
; kiosko is a module: `from` is the reach, and its miss is checked by name -- () applied
; to operands is 1, a miss that would read as a server that started.
(module (serve serve-main sv-make)
(use 'libra)
(use 'hueweb)
(use 'lapiz)

(:
   (sv-ends? s t) (: n #s m #t (m <= n && snip s (n - m) n = t))
   (sv-rdf p) (: q (open p "r") (hot? q && (: s (slurp q) _ (close q) (string? s && [1 s]))))
   ; the directory a path sits in, as a link back up: "/a/b/c.l" -> "/a/b/"
   (sv-up p) (: n #p
                (g k r) (? (k < n) (g (k + 1) (p k = 47 ? (k + 1) r)) (snip p 0 r))
                (g 0 0))

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

   ; the hook: `(ctype body) to serve, () to say "not mine". `.l.md` is tested
   ; first because that path ends in `.md` as much as it ends in `.l.md`.
   (sv-make root box p)
   (: hd? (sv-ends? p ".l.md")
      md? (sv-ends? p ".md")
      src (hd? ? (snip p 0 (#p - 3)) p)            ; "/x.l.md" -> "/x.l"
      (? (p = "/hue.css") ["text/css; charset=utf-8" (hw-css 'paper)]
         !(md? || sv-ends? p ".l") ()
         (: f (root + src)
            r (sv-rdf f)
            (? !(two? r) ()                       ; not there: let kiosko say 404
               ["text/html; charset=utf-8"
                (sv-cached box p
                  (\ _ (? hd? (sv-doc p (sv-head src <>r) [src "the source"])
                           md? (sv-doc p <>r ())
                           (sv-page p (hw-body p <>r) [(p + ".md") "the header, as a document"]))))]))))

   (sv-usage _)
   (: _ (say err "love serve -- the tree in a browser, painted on the way out
usage: love serve [-p PORT] [-n] [DIR]
  -p, --port PORT   the port to listen on (default 8080)
  -n, --no-build    serve DIR as it is
  DIR               the directory to serve (default .)
a .l is painted, a .md rendered, and x.l.md is x.l's header as a document. where DIR
is the tree, the github page is laid first -- make web wasm site-wasm and the wasm inle
seat -- and the machine is at /port/wasm/inle.html.
")
      (quit 0))

   ; the page's build, through our own make in DIR: only where DIR is the tree, and
   ; a refused build is said and stops the server -- a page half laid is not one
   (sv-tree? dir) (two? (stat (dir + "/Makefile")) && two? (stat (dir + "/web/index.l")))
   (sv-build dir)
   (: exe (selfpath 0)
      _ (string? exe ? 0 (say err "serve: can't find my own path\n", quit 1))
      _ (say err ";; laying the page: make web wasm site-wasm out/love-wasm.wasm\n")
      p (spawn [exe "make" "-C" dir "web" "wasm" "site-wasm" "out/love-wasm.wasm"])
      st (charm? p && 0 <= p ? (wait p) 1)
      (0 = st ? 0 (say err ("serve: the page did not build (" + show st + ")\n"), quit 1)))

   (sv-num s) (:- (g 0 0)
                  (g i acc) (? (i < #s && 48 <= s i <= 57)
                               (g (i + 1) (acc * 10 + (s i - 48))) acc))

   (serve-main as)
   (: box (tablet 0)
      (loop ws port dir build)
       (? !(two? ws) [port dir build]
          (: w <ws r >ws
             (? (w = "-p" || w = "--port")
                 (two? r ? (loop >r (sv-num <r) dir build) (sv-usage 0))
                (w = "-n" || w = "--no-build") (loop r port dir 0)
                (w = "-h" || w = "--help") (sv-usage 0)
                (loop r port w build))))
      c (loop as 8080 "." 1)
      port <c
      dir <>c
      _ (<>>c && sv-tree? dir ? (sv-build dir) 0)
      serve5 (from 'kiosko 'serve5)
      _ (nil? serve5 ? (say err "serve: no kiosko aboard\n", quit 1))
      _ (sv-tree? dir ? (say err ("serve: the page is http://127.0.0.1:" + show port
                                  + "/ and the machine /port/wasm/inle.html\n")) 0)
      _ (? (serve5 dir port 0 () (p \ sv-make dir box p)) 0
           (: _ (say err ("serve: cannot listen on :" + show port)) _ (put err 10) (quit 1)))
      (quit 0))

   ; the verb, and the seat (kiosko's shape): `love serve ..` on the artifact, or
   ; this file named on a command line, and neither needs a script
   _ (pins (from 'verbs 'tab) 'serve serve-main)
   s ((from 'verbs 'fire) ["serve" "serve.l"])
   _ (two? s && serve-main >s))
) ; module serve
