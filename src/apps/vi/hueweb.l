; src/apps/vi/hueweb.l -- the .l syntax as a stylesheet and as painted html, from hue.l's
; class table and config.l's theme; it asks hue what each span is, so a new class reaches
; every reader of that table.
;
;   (hw-vars scheme)     the :root block: a palette as css variables, dark under a media query
;   (hw-css scheme)      the stylesheet: a rule per class, the frame, a little prose styling
;   (hw-body path src)   that source as a <pre>, one span per line
;   (hw-page ttl hrefs home body)   ..in a page, with its stylesheets and a home link
;
; no papel: it does not ride the artifact, and `love serve` paints its own source.
; (borrow 'vi) sits inside the module, so vi's names stay out of the session.
(module (hueweb hw-vars hw-css hw-body hw-page)
(borrow 'vi)
(:
   ; the first row of tbl headed by k; there is no assoc in the vocabulary
   (hw-find tbl k) (:- (f tbl) (f l) (? (atom? l) () (<<l = k) <l (f >l)))
   (hw-q s) (cite 'lapiz 'hq s)
   ; the final newline ends the last line, it does not open another
   (hw-lines s) (:- (g 0 0 ())
                 (g i st acc) (? (i >= #s) (st < i ? (rev (snip s st i . acc)) (rev acc))
                                 (s i = 10) (g (i + 1) (i + 1) (snip s st i . acc))
                                 (g (i + 1) st acc)))

   ; --- the palette ----------------------------------------------------------
   ; a role is the variable of its own name, so the frame says var(--link). an
   ; unknown scheme is an empty block
   (hw-vars nm)
   (: s (hw-find hue-page nm)
      (roles p) (":root{" + cats (map (r \ "--" + string <r + ":" + <>r + ";") p) + "}\n")
      (atom? s ? ""
         (roles (s 1) + (two? >>s ? ("@media (prefers-color-scheme:dark){" + roles (s 2) + "}\n") ""))))

   ; --- the stylesheet -------------------------------------------------------
   ; a class whose group the theme does not carry gets no rule rather than a guess
   hw-faces (cats * map (f \ f @ 'bold ";font-weight:700" 'italic ";font-style:italic" ""))
   ; a row is (group cterm256 "#rrggbb" faces)
   (hw-rule r) (hw-find hue-theme (hue-grp r) @
                (_ _ col fs) (".hue .l-" + string (hue-cls r) + "{color:" + col + hw-faces fs + "}\n")
                "")
   ; line numbers out of a css counter, so selecting the code copies the code alone
   hw-frame
   ".hue{background:var(--pre);padding:1rem 0;border-radius:6px;overflow-x:auto;counter-reset:ln;
  font:.82rem/1.55 ui-monospace,Menlo,monospace}
.hue .ln{display:block;padding:0 1rem 0 0;white-space:pre}
.hue .ln::before{counter-increment:ln;content:counter(ln);display:inline-block;width:3.4rem;
  padding-right:1rem;text-align:right;color:var(--dim);opacity:.55;-webkit-user-select:none;user-select:none}
.hue .ln:target{background:rgba(127,127,127,.16)}
.srcnav{font-size:.85rem;margin:0 0 1rem;color:var(--dim)}
.srcnav a{color:var(--link)}
body{margin:0;background:var(--bg);color:var(--fg);font:16px/1.65 ui-serif,Georgia,serif}
header{border-bottom:1px solid var(--rule);padding:1rem 1.25rem;font-family:ui-sans-serif,system-ui,sans-serif}
header a{color:var(--fg);text-decoration:none;font-weight:600}
main{max-width:64rem;margin:0 auto;padding:2rem 1.25rem}
a{color:var(--link)}
h1,h2,h3,h4,h5,h6{font-family:ui-sans-serif,system-ui,sans-serif;line-height:1.25;margin:2rem 0 .6rem}
h1{margin-top:0;font-size:1.7rem}
h2{font-size:1.3rem;border-bottom:1px solid var(--rule);padding-bottom:.3rem}
p,ul,ol,dl,blockquote,pre{margin:0 0 1rem}
code{background:var(--pre);padding:.1em .35em;border-radius:3px;font:.88em/1.5 ui-monospace,Menlo,monospace}
pre{background:var(--pre);padding:.9rem 1rem;border-radius:6px;overflow-x:auto}
pre code,.hue code{background:none;padding:0}
blockquote{border-left:3px solid var(--rule);margin-left:0;padding-left:1rem;color:var(--dim)}
dt{font-weight:600;margin-top:.8rem}
dd{margin:0 0 .2rem 1.2rem;color:var(--dim)}
hr{border:0;border-top:1px solid var(--rule);margin:2rem 0}
"
   (hw-css nm) (hw-vars nm + hw-frame + cats (map hw-rule hue-classes))

   ; --- one file, painted ----------------------------------------------------
   ; the unclaimed gaps between runs stay plain text; `in` carries an open string
   (hw-span c a b s) ("<span class=\"l-" + string c + "\">" + hw-q (snip s a b) + "</span>")
   (hw-paint bk s in)
   (:- (go <r 0 "")
    r (hue-lex bk s in 1)
    (go rs i acc)
     (atom? rs ? [(acc + hw-q (snip s i #s)) <>r]
      (<rs @ [c a b] (go >rs b (acc + hw-q (snip s i a) + hw-span c a b s)))))
   (hw-body path src)
   (:- ("<pre class=\"hue\">" + go (hw-lines src) 1 0 "" + "</pre>")
    bk (hue-book 0)
    (go ls k in acc)
     (atom? ls ? acc
        (hw-paint bk <ls in @ (txt in2)
         (go >ls (k + 1) in2
             (acc + "<span class=\"ln\" id=\"L" + show k + "\">" + txt + "\n</span>")))))

   ; --- the page -------------------------------------------------------------
   ; the site passes papel.css; `love serve` passes its own
   (hw-page ttl hrefs home body)
   ("<!doctype html>\n<html lang=\"en\">\n<head>\n<meta charset=\"utf-8\">\n"
    + "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n"
    + "<title>" + hw-q ttl + "</title>\n"
    + cats (map (h \ "<link rel=\"stylesheet\" href=\"" + hw-q h + "\">\n") hrefs)
    + "</head>\n<body>\n"
    + (#home ? ("<header><a href=\"" + hw-q home + "\">love</a></header>\n") "")
    + "<main>\n<article>\n" + body + "\n</article>\n</main>\n</body>\n</html>\n"))
) ; module hueweb
