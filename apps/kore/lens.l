; apps/kore/lens.l -- the two kore doors onto lapiz: `html2text` and `markdown`.
;
; lapiz is the document lens -- one middle, a reader and a shower per surface -- and papel
; already drives it (markdown in, html out) to lay this tree's pages. these are the same
; faces with a command line around them, so each cost an operand walk and not a parser.
;
;   html2text [-w COLS] [FILE..]                          html2text index.html
;   markdown [-t html|roff|text] [-w COLS] [FILE..]       markdown README.md > readme.html
;   markdown -t dvi [FILE]                                markdown README.md > readme.dvi
;
; the width is the terminal's, or -w, or 80 where there is no terminal to ask. with no
; operands either reads stdin, which is what makes them filters worth having on the end of
; a pipe. attributes ride out of a text layout when the output is a terminal and come off
; when it is not; html and roff carry none to begin with.
;
; `markdown` writes a FRAGMENT, which is what the name has always meant: the blocks, no
; doctype and no head. papel owns the template that wraps one into a page, and a second
; template here would be a second thing to keep true.
;
; what html2text is NOT is a browser. a page is prose to this tool: lapiz's scrub drops the
; script, the style and the head, and unwraps the containers, so what arrives at the reader
; is headings, paragraphs, lists, definition lists, quotes, displays and the inline spans.
; forms and anything positioned by css are gone, and that is the whole design: this answers
; "what does the page SAY", and nothing about what it looks like. an image says its [alt];
; on a terminal a local one is drawn under that line too (apps/kore/pic.l), its path taken
; from the document's own directory, and one on the web stays its [alt].
(module 'kore
(borrow 'cli)
(borrow 'posix)
(borrow 'cal)

(:
   ; the width the output wants: -w, else the terminal on fd 1, else 80
   (lens-w t ws) (: v (uoptv t 119)
                    (? (string? v) (: n (uatoi v) (? (0 < n) n 80))
                       (two? ws && 0 < >ws) >ws
                       80))
   ; one trailing newline, always: a shower ends where the document does, and a tool that
   ; writes to a terminal owes the prompt its own line
   (lensnl s) (? (tally s && s (tally s - 1) = 10) s (s + "\n"))
   ; one lay over the operands, or over stdin when there are none. the status is the worst
   ; of the files, and a charm: the seat quits with it
   (lensrun lay nm fs)
    (: (one p) (: r (uread p)
                  (? (two? r) (: _ (puts (lensnl (lay <>r p))) 0)
                     (: _ (say err (nm + ": cannot open " + p)) _ (put err 10) 1)))
       (? (two? fs) (foldl (\ a p (: r (one p) (? (a || r) 1 0))) 0 fs)
          (: _ (puts (lensnl (lay (slurp in) ""))) 0)))
   ; the directory a path is in, with its slash; "" for a bare name
   (lens-dir p) (: (g i) (? (i < 0) "" (p i = 47) (snip p 0 (i + 1)) (g (i - 1))) (g (#p - 1)))
   (lens-has s p) (: n #p (g i) (? (#s < (i + n)) 0 (snip s i (i + n) = p) 1 (g (i + 1))) (g 0))
   ; an image's src -> the file it names, () for one on the web
   (lens-path dir src)
    (? (snip src 0 7 = "file://") (snip src 7 #src)
       ((lens-has src "://") || (snip src 0 5 = "data:")) ()
       (src 0 = 47) src
       (dir + src))
   ; a doc laid at w for a terminal, each local picture drawn under its image's line, no
   ; taller than the screen
   (lens-pics d w p)
    (: r ((cite 'lapiz 'ttpics) d w) ls (lines <r)
       ws (tty 1) rows (? (two? ws && 3 < <ws) (<ws - 2) ())
       deep ((cite 'kore 'pic-deep) 0) dir (lens-dir p)
       (draw t a)
        (: nm <a
           (? !((5 < #nm) && (snip nm 0 5 = " img ")) t
              (: f (lens-path dir (snip nm 5 #nm))
                 rd (? (string? f) (uread f) ())
                 im (? (two? rd) ((cite 'kore 'pic-decode) <>rd) ())
                 (? (two? im) (pin t (a 1) (peep t (a 1) () + ((cite 'kore 'ww-art) im w rows deep))) t))))
       pics (foldl draw (tablet 0) (r 1))
       (catmap (i \ (ls i) + "\n" + catmap (x \ x + "\n") (peep pics i ())) ^#ls))

   h2t-usage "usage: html2text [-w COLS] [FILE..]"
   (h2t-lay s w tty? p) (? tty? (lens-pics ((cite 'lapiz 'htread) s) w p) (usgr ((cite 'lapiz 'ht->tty) s w)))
   (html2text-main as)
    (: t (tablet 0)
       o (uopt as t '(119) '(101) ())                       ; -w takes a value
       _ (? (two? o) () (udie 2 h2t-usage))
       _ (: c (uoptun t '(119))
            (? (nil? c) () (udie 2 ("html2text: unknown option -" + string c))))
       ws (tty 1)                                     ; the width is the OUTPUT's
       w (lens-w t ws)
       tty? (two? ws)
       (lensrun (\ s p (h2t-lay s w tty? p)) "html2text" <>>o))

   md-usage "usage: markdown [-t html|roff|text|dvi] [-w COLS] [FILE..]"
   md-tos ["html" "roff" "text" "dvi"]
   ; -t dvi: caja sets the document in pages (apps/caja/doc.l), with Computer Modern's
   ; metrics and plain's patterns out of a TeX tree -- $CAJA_TEXMF, else where TeX Live puts
   ; one. one file or stdin; a man page (its first line a request) is read as roff
   texmf-roots ["/usr/share/texmf-dist" "/usr/share/texlive/texmf-dist" "/usr/local/share/texmf-dist"]
   (lens-texmf rel)
    (: e (getenv "CAJA_TEXMF")
       rs (? (string? e && 0 < #e) (e . texmf-roots) texmf-roots)
       (go l) (? (two? l) (: r (uread (<l + "/" + rel)) (? (two? r) (<>r + "") (go >l))) ())
       (go rs))
   (lens-roff? s) (0 < #s && (s 0 = 46 || (1 < #s && s 0 = 39 && s 1 = 92)))
   (md-dvi s)
    (: tfms (map (n \ lens-texmf ("fonts/tfm/public/cm/" + n + ".tfm")) (cite 'caja-doc 'cd-fonts))
       hy (lens-texmf "tex/generic/hyphen/hyphen.tex")
       _ (? (elem () (hy . tfms))
            (udie 1 "markdown: -t dvi wants Computer Modern's TFMs and hyphen.tex from a TeX tree; set CAJA_TEXMF"))
       ms (clock 0) sec (ms // 1000) ymd (civil (sec // 86400))
       J ((cite 'caja-doc 'cd-job) tfms hy [(ymd 0) (ymd 1) (ymd 2) (sec % 86400 // 60)])
       doc (? (lens-roff? s) ((cite 'lapiz 'rfread) s) ((cite 'lapiz 'mdread) s))
       ((cite 'caja-doc 'cd-dvi) J doc))
   (md-dvi-main fs)
    (: _ (? (two? (tty 1)) (udie 2 "markdown: a DVI is not for a terminal; send it to a file"))
       _ (? (1 < #fs) (udie 2 "markdown: -t dvi sets one document"))
       s (? (two? fs) (: r (uread <fs) (? (two? r) (<>r + "") (udie 1 ("markdown: cannot open " + <fs)))) (slurp in))
       _ (say out (md-dvi s))
       _ (flush out)
       0)
   (md-lay s to w tty? p)
    (? (to = "roff") ((cite 'lapiz 'md->rf) s)
       (to = "text") (? tty? (lens-pics ((cite 'lapiz 'mdread) s) w p) (usgr ((cite 'lapiz 'md->tty) s w)))
       ((cite 'lapiz 'md->ht) s))
   (markdown-main as)
    (: t (tablet 0)
       o (uopt as t '(116 119) '(101) ())                   ; -t and -w take values
       _ (? (two? o) () (udie 2 md-usage))
       _ (: c (uoptun t '(116 119))
            (? (nil? c) () (udie 2 ("markdown: unknown option -" + string c))))
       v (uoptv t 116)
       to (? (string? v) v "html")
       _ (? (elem to md-tos) () (udie 2 md-usage))
       ws (tty 1)
       w (lens-w t ws)
       tty? ((two? ws) && (to = "text"))
       (? (to = "dvi") (md-dvi-main <>>o)
          (lensrun (\ s p (md-lay s to w tty? p)) "markdown" <>>o))))
) ; module 'kore
