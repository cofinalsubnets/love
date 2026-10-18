#!/usr/bin/env -S love -l
; papel -- the static site: a tree of markdown becomes a tree of html. lapiz reads and shows
; each page; cook rebuilds only the stale ones, one recipe per page. papel keeps what is true
; of a page only because of the others: titles, anchors, contents, blurbs, cross-links.
; the index is an AST papel builds and lapiz shows. papel's own html is the template and the
; two nodes lapiz has no id for: the anchored head and the anchored deflist.

; no brackets: a consumer says (borrow 'papel); a -l load reads the names bare.

; --- the modules papel stands on ---------------------------------------------------------
; papel loads its siblings itself, since two tool files cannot both be -l'd. `root` is this
; file's directory off the command line, so siblings come from the tree papel sits in.
(borrow 'path)
(borrow 'posix)
(: (findme (a . u)) ; the word that named this file, if any
    (pbase a @ ("papel" || "papel.l") a (findme u))
   root (findme >cmdline @ me (me ? (phead me) "src/apps/"))          ; src/apps/papel.l -> src/apps/
   ; want: a module already registered is left alone; else the sibling beside this file,
   ; else by name off the registry
   (want nm f) (cite nm ? 1
                  (open (root + f) "r" @ q
                     (hot? q ? (close q, borrow (root + f), 1)
                        (borrow nm, 1))))
   _ (want 'lapiz "lapiz.l")
   _ (want 'cook "cook.l")
   _ (want 'hueweb "vi/hueweb.l"))

; --- the two seams -------------------------------------------------------------------
; from lapiz, read and show plus what papel's own nodes need: `hq` escapes, `hti` shows an
; inl, `htb` a block. from cook, the two verbs a build is made of.
(: L (cite 'lapiz)
   mdread (L 'mdread)  htshow (L 'htshow)  htb (L 'htb)  hti (L 'hti)  hq (L 'hq)  mget (L 'mget)
   C (cite 'cook)
   recipe (C 'recipe)  prepped (C 'prepped))

; --- little utils (papel's own: it leans on lapiz for DOCUMENTS, not for lists) --------
(: (strcat l)    (foldl (+) "" l)
   (slurpf f)    (uread f @ [1 s] s "")
   (spitf f s)   (open f "w" @ q (hot? q ? (say q s, close q, 1) 0))
   ; a directory answers a list from readdir, a file nothing: no mode bits needed
   (dir? p)      (two? (readdir p)))

; --- slugs: a heading becomes an id ----------------------------------------------------
; lowercase, other runs one dash, the ends trimmed; a repeated slug is deduped by a counter
(: (down c)   (65 <= c && c <= 90 ? (c + 32) c)
   (squash s) (:- (g 0 "" 0)
                  (g i acc prev) (i < #s ?
                                    (s i @ c
                                       (c = 45 && prev = 45 ? (g (i + 1) acc c)
                                          (g (i + 1) (acc + string c) c)))
                                    acc))
   (trimd s)  (: n #s
                 a (:- (f 0) (f i) (i < n && s i = 45 ? (f (i + 1)) i))
                 b (:- (f n) (f i) (a < i && s (i - 1) = 45 ? (f (i - 1)) i))
                 (snip s a b))
   (slug s)   (: raw (jug 0 @ j (each ^#s (i \ (s i @ c (say j (alnum? c ? (string (down c)) "-")))), slurp j))
                 out (trimd (squash raw))
                 (0 < #out ? out "section")))

; --- reading the middle: the site-level facts of one page ------------------------------
; every one of these is a walk over the AST, which is the point of having one.
(: (itext l) (strcat (map (x \ (<x @ t
                                  (? (t = 'text) <>x
                                     (t = 'code) <>x
                                     (t = 'strong || t = 'em || t = 'link) (itext <>x)
                                     ""))) l))
   (head? b)  (<b = 'head)
   (pmeta d)  (filter (b \ <b = 'meta) d @ m (two? m ? <><m ()))
   (pbody d)  (filter (b \ <b != 'meta) d)
   ; the heads, each with its deduped slug: ((level slug label) ..). one parse feeds both
   ; the anchors in the body and the toc beside it, so the two cannot drift apart.
   (pheads d) (:- (g d {} ())
                  (g l seen acc)
                  (atom? l ? (rev acc)
                     (<l @ b
                        (head? b ?
                           (: lab (itext (b 2))
                              s0 (slug lab)
                              k (peep seen s0 0)
                              sn (0 < k ? (s0 + "-" + show k) s0)
                              (pin seen s0 (k + 1), g >l seen ([<>b sn lab] . acc)))
                           (g >l seen acc)))))
   ; the deflist terms with their slugs, one list per deflist, deduped after the heads so a
   ; term and a heading never share an anchor
   (pterms d hs) (: seen (foldl (t \ h \ (slug (h 2) @ s0 (pin t s0 (peep t s0 0 + 1)))) {} hs)
                    (one it) (: s0 (slug (itext <it))
                                k (peep seen s0 0)
                                (pin seen s0 (k + 1), (0 < k ? (s0 + "-" + show k) s0)))
                    (map (b \ map one <>b) (filter (b \ <b = 'deflist) d)))
   ; the title: the first head-1, else the meta `title`, else the caller's fallback.
   (ptitle d dflt) (: h1 (filter (b \ head? b && <>b = 1) d)
                      mt (mget (pmeta d) 'title)
                      (? (two? h1) (itext (<h1 2))
                         (0 < #mt) mt
                         dflt))
   ; the blurb: the first paragraph, clipped on a word boundary. () when the page has none.
   (clip s n) (#s @ t
                 (t <= n ? s
                    (: b (:- (f n) (f i) (0 < i && s (i - 1) != 32 ? (f (i - 1)) i))
                       (snip s 0 (0 < b ? (b - 1) n) + "..."))))
   (blurb d)  (filter (b \ <b = 'para) d @ ps
                 (two? ps ? [['text (clip (itext <><ps) 160)]] ())))

; --- cross-links: .md becomes .html, but only inside the site --------------------------
; a `*.md` url is rewritten iff it has no :// and its basename is a page the site builds;
; anything else stays as written, so papel invents no dead link
(: (mdurl known u)
   (u @ (? (has? u "://")) u
        (s + ".md") (pbase u @ b (peep known b 0 ? (s + ".html") u))
        u)
   (rli f l)  (map (x \ (<x @ 'link ['link (rli f <>x) (f <>>x)]
                              ('strong || 'em) [<x (rli f <>x)]
                              x)) l)
   (rlb f b) (<b @ 'para    ['para (rli f <>b)]
                   'head    ['head <>b (rli f <>>b)]
                   'bullets ['bullets (map (i \ rli f i) <>b)]
                   'numbers ['numbers (map (i \ rli f i) <>b)]
                   'deflist ['deflist (map (it \ [(rli f <it) (rli f <>it)]) <>b)]
                   'quote   ['quote (map (x \ rlb f x) <>b)]
                   b)
   (relink f d) (map (b \ rlb f b) d))

; --- showing: lapiz shows every block but two ------------------------------------------
; papel emits the anchored head and deflist itself: lapiz has nowhere for an id or a class.
; a deflist's class is the slug of the heading above it. heads and terms arrive slugged, in
; document order, and the walk consumes them in step.
(: (hhead lev sl inl) (: h ("h" + show lev)
                         ("<" + h + " id=\"" + hq sl + "\">" + hti inl + "</" + h + ">"))
   (hdl cls sls items)
   (: (row sl it) ("<dt id=\"" + hq sl + "\">" + hti <it + "</dt>\n<dd>" + hti <>it + "</dd>")
      (rows sls its) (atom? its ? () (row <sls <its . rows >sls >its))
      ("<dl" + (0 < #cls ? (" class=\"" + hq cls + "\"") "") + ">\n"
       + join "\n" (rows sls items) + "\n</dl>"))
   (pshow d hs ts)
   (:- (g d hs ts () "")
       (g l hs ts acc cls)
       (atom? l ? (join "\n" (rev acc))
          (<l @ b
             (? (head? b)
                (hhead <<hs <><hs <>>b @ h
                   (g >l >hs ts (h . acc) <><hs))
                (<b = 'deflist) (g >l hs >ts (hdl cls <ts <>b . acc) cls)
                (g >l hs ts (htb b . acc) cls)))))
   ; the toc: the same heads, minus the one that became the title. a page with fewer than
   ; two of them gets none -- a one-item contents is furniture, not navigation.
   (ptoc d hs) (: rest (two? hs && 1 = <<hs ? >hs hs)
                  (atom? >rest ? ""
                     ("<ul>\n" + strcat (map (h \ "<li class=\"l" + show <h + "\"><a href=\"#"
                                                   + hq <>h + "\">" + hq <>>h + "</a></li>\n") rest)
                      + "</ul>")))
   (pmetah kvs) (atom? kvs ? "" (htb ['meta kvs])))

; --- the page template ------------------------------------------------------------------
(: (wrap conf ttl metah toch body)
   (peep conf 'title "papel" @ site
      ("<!doctype html>\n<html lang=\"en\">\n<head>\n<meta charset=\"utf-8\">\n"
       + "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n"
       + "<title>" + hq ttl + (ttl = site ? "" (" &middot; " + hq site)) + "</title>\n"
       + "<link rel=\"stylesheet\" href=\"papel.css\">\n"
       + (metah ? (metah + "\n"))
       + "</head>\n<body>\n"
       + "<header><a href=\"index.html\">" + hq site + "</a></header>\n"
       + "<main>\n"
       + (tally toch ? ("<nav class=\"toc\">\n" + toch + "\n</nav>\n"))
       + "<article>\n" + body + "\n</article>\n</main>\n"
       + "<footer>markdown through <b>lapiz</b>, built by <b>cook</b>, laid out by <b>papel</b></footer>\n"
       + "</body>\n</html>\n")))

; --- the stylesheet ---------------------------------------------------------------------
; one file, linked by every page, built by a cook recipe like the pages. the colours are
; the paper palette through hueweb's hw-vars
(: css
   (cite 'hueweb 'hw-vars 'paper +
   "*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--fg);font:16px/1.65 ui-serif,Georgia,serif}
header{border-bottom:1px solid var(--rule);padding:1rem 1.25rem;font-family:ui-sans-serif,system-ui,sans-serif}
header a{color:var(--fg);text-decoration:none;font-weight:600;letter-spacing:.02em}
main{display:flex;gap:2.5rem;align-items:flex-start;max-width:64rem;margin:0 auto;padding:2rem 1.25rem}
article{min-width:0;flex:1}
footer{border-top:1px solid var(--rule);padding:1.25rem;color:var(--dim);font-size:.85rem;text-align:center}
a{color:var(--link)}
h1,h2,h3,h4,h5,h6{font-family:ui-sans-serif,system-ui,sans-serif;line-height:1.25;margin:2rem 0 .6rem}
h1{margin-top:0;font-size:1.9rem}
h2{font-size:1.35rem;border-bottom:1px solid var(--rule);padding-bottom:.3rem}
h3{font-size:1.1rem}
p,ul,ol,dl,blockquote,pre{margin:0 0 1rem}
code{background:var(--pre);padding:.1em .35em;border-radius:3px;font:.88em/1.5 ui-monospace,Menlo,monospace}
pre{background:var(--pre);padding:.9rem 1rem;border-radius:6px;overflow-x:auto}
pre code{background:none;padding:0}
blockquote{border-left:3px solid var(--rule);margin-left:0;padding-left:1rem;color:var(--dim)}
hr{border:0;border-top:1px solid var(--rule);margin:2rem 0}
dt{font-weight:600;margin-top:.8rem}
dd{margin:0 0 .2rem 1.2rem;color:var(--dim)}
table{border-collapse:collapse}
.toc{position:sticky;top:1.5rem;flex:0 0 14rem;font-family:ui-sans-serif,system-ui,sans-serif;font-size:.85rem;line-height:1.5;border-left:1px solid var(--rule);padding-left:1rem}
.toc ul{list-style:none;margin:0;padding:0}
.toc li{margin:.15rem 0}
.toc a{color:var(--dim);text-decoration:none}
.toc a:hover{color:var(--link)}
.toc .l3{padding-left:.9rem}
.toc .l4,.toc .l5,.toc .l6{padding-left:1.8rem}
@media (max-width:52rem){main{display:block}.toc{position:static;border-left:0;border-bottom:1px solid var(--rule);padding:0 0 1rem;margin-bottom:1.5rem}}
"))

; --- one page, and the index ------------------------------------------------------------
(: (outname s) (pbase s @ b (snip b 0 (#b - 3) + ".html"))
   (render conf known src dst)
   (: d0 (mdread (slurpf src))
      d  (relink (u \ mdurl known u) d0)
      body (pbody d)
      hs (pheads body)
      ttl (ptitle body (pbase src))
      (spitf dst (wrap conf ttl (pmetah (pmeta d)) (ptoc body hs)
                       (pshow body hs (pterms body hs))),
       dst))
   ; the index is an AST, a head then a deflist of link/blurb pairs, shown like any page
   (index-doc conf srcs)
   (: site (peep conf 'title "papel")
      rows (map (s \ (mdread (slurpf s) @ d
                      [[['link [['text (ptitle d (pbase s))]] (outname s)]] (blurb d)])) srcs)
    [['head 1 [['text site]]] ['deflist rows]])
   (windex conf srcs dst)
   (: d (index-doc conf srcs)
      hs (pheads d)
      (spitf dst (wrap conf (peep conf 'title "papel") "" "" (pshow d hs (pterms d hs))), dst)))

; --- the sources, and the build -----------------------------------------------------------
(: (mdsof p) (? (dir? p) (map (f \ p + "/" + f) (sort (filter (f \ ends? f ".md") (readdir p))))
                (ends? p ".md") [p])
   (sources conf) (foldl (+) () (map mdsof (conf 'src)))
   (conf0 _) {'out "out/site" 'title "papel" 'src () 'self "src/apps/papel.l"}
   ; the dev server's gate: `build` only when a fingerprint of the sources moved, as even a
   ; no-op build walks the recipe graph. 0 when nothing ran. mtime and size, as an edit can
   ; keep either one
   (fprint conf) (foldl (+) 0 (map (s \ (stat s @ st (two? st ? (<>st + <st) 0)))
                                   (sources conf)))
   (refresh conf box) (fprint conf @ f
                         (f = peep box 'f -1 ? 0 (pin box 'f f, build conf)))

   ; one recipe per page, one for the sheet, one for the index, a phony `site` over them; cook
   ; decides what is stale. each also depends on this file, when it is on disk
   (build conf)
   (: out (peep conf 'out "out/site")
      srcs (sources conf)
      _ (atom? srcs ? (scare 'papel "papel: no markdown sources"))
      _ (umkdirs out 493)
      known (foldl (t \ s \ pin t (pbase s) 1) {} srcs)
      self (peep conf 'self "")
      dep (two? (stat self) ? [self])
      dsts (map (s \ out + "/" + outname s) srcs)
      _ (each srcs (s \ recipe (out + "/" + outname s) (s . dep)
                         [(_ \ render conf known s (out + "/" + outname s))]))
      sheet (out + "/papel.css")
      _ (recipe sheet dep [(_ \ spitf sheet css)])
      idx (out + "/index.html")
      own? (peep known "index.md" 0)                 ; a real index.md wins; papel adds none
      _ (own? ? 0 (recipe idx (srcs + dep) [(_ \ windex conf srcs idx)]))
      _ (recipe 'site (dsts + [sheet] + (own? ? () [idx])) ())
      ; prepped is cook's quiet entry: the items whose recipe advanced their mtime
      n #(prepped 'site)
      _ (!(peep conf 'quiet 0) ?
         (puts $ "papel: " + (0 < n ? (show n + " written to " + out + "/\n")
                                      (out + "/ is up to date\n"))))
      n))

; --- the command line ---------------------------------------------------------------------
(: papel-usage "papel -- a static site from markdown
usage: papel [-o OUT] [-t TITLE] [SRC ..]
  -o, --out DIR     where the site is written (default out/site)
  -t, --title NAME  the site name, used in the header and on the index (default papel)
  -q, --quiet       write the site and say nothing
  -s, --serve PORT  build, then serve the site on PORT
  SRC               a .md file or a directory of them; with none, README.md and doc/
"
   pm (:
   (pdie c m) (udie c ("papel: " + m))
   (papel-main as)
   (: _ (lit? (cite 'papel) ? (borrow 'papel) 0)   ; splice my registered self if I am one;
                                                  ; on a -l load my names already read bare
      ; ..and posix: a global name reads the live book, which the caller's chain may lack
      _ (borrow 'posix)
      c (conf0 ())
      t {}
      o (uopt as t '(111 116 115) () {"out" 111 "title" 116 "quiet" 113 "serve" 115})
      _ (two? o ? 0 (pdie 2 (last as + " needs an argument")))
      un (uoptun t '(111 116 113 115))
      _ (!un ? 0 (pdie 2 ("unknown option -" + string un)))
      src <>>o
      sy (uoptstray as src)
      _ (!sy ? 0 (pdie 2 ("unknown option " + sy)))
      _ (uoptv t 111 @ v (!v ? 0 (pin c 'out v)))
      _ (uoptv t 116 @ v (!v ? 0 (pin c 'title v)))
      _ (peep t 113 0 ? (pin c 'quiet 1) 0)
      sp (uoptv t 115)
      _ (!sp ? 0 (uport sp @ v (v ? (pin c 'serve v) (pdie 2 ("not a port: " + sp)))))
      _ (pin c 'src (two? src ? src '("README.md" "doc")))
      _ (build c)
      ; --serve hands the built directory to kiosko with `refresh` as the thunk it runs before
      ; each client, quiet. the box holds the last fingerprint, seeded from this build
      port (peep c 'serve 0)
      ((port ?
          (: _ (want 'kiosko "kiosko/kiosko.l")
             q (peep c 'quiet 0)
             _ (pin c 'quiet 1)
             box (pin {} 'f (fprint c))
             (cite 'kiosko 'serve (peep c 'out "out/site") port q (_ \ _ \ refresh c box) ? 0
              (pdie 1 ("cannot listen on :" + show port))))),
       0))
   papel-main)

   papel-main pm)

; fire papel-main iff this file or the installed `papel` script is the program named on
; the real command line, on the args after it
(: door (udoor 'papel (urun papel-main) papel-usage 1 1)
   s (cite 'verbs 'fire ["papel" "papel.l"])
   (two? s ? (quit (door >s))))
