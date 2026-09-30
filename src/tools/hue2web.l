; src/tools/hue2web.l -- the build-time face of src/apps/vi/hueweb.l: write the .l syntax
; stylesheet, and write one source file out as a painted page.
;
;   love src/tools/hue2web.l css        the stylesheet, on stdout
;   love src/tools/hue2web.l src file   that file as an annotated page, on stdout
;
; the painting itself is src/apps/vi/hueweb.l, which `love serve` also uses to paint the
; same file at request time. one painter, two errands -- a build that wrote pages
; a server would paint differently is two answers to one question.
;
; LOVE_NO_IMAGE must be cleared by whoever runs this, and the Makefile does: the
; word lanes ask the running binary for its vocabulary, and under the egg boot
; that answer is the compiler's own internals rather than the language we ship.
(borrow "src/apps/vi/config.l")
(borrow "src/apps/vi/hue.l")
(borrow 'hueweb)

(borrow 'posix)
(: (h2w-rdf p) (uread p @ [1 s] (string? s ? [1 s]) ())
   (h2w-usage _) (udie 2 "usage: love src/tools/hue2web.l css | src FILE")

   ; the site's own chrome: papel.css first, so a painted page and a doc page are
   ; one design, then hue.css over it for the syntax.
   (h2w-src path)
   (: r (h2w-rdf path)
      (atom? r ? (udie 1 ("hue2web: cannot open " + path))
       (say out (hw-page path '("papel.css" "hue.css") "index.html"
                         ("<p class=\"srcnav\">the source of <code>" + path + "</code></p>\n"
                          + hw-body path <>r)),
        0)))

   (h2w-main as)
   (? (atom? as) (h2w-usage 0)
      (<as = "css") (say out (hw-css 'paper), 0)
      (<as = "src" && two? >as) (h2w-src <>as)
      (h2w-usage 0))
   _ (h2w-main >>cmdline))
