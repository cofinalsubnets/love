; apps/kore/lens.l -- the two kore doors onto lapiz: `html2text` and `markdown`.
;
; lapiz is the document lens -- one middle, a reader and a shower per surface -- and papel
; already drives it (markdown in, html out) to lay this tree's pages. these are the same
; faces with a command line around them, so each cost an operand walk and not a parser.
;
;   html2text [-w COLS] [FILE..]                          html2text index.html
;   markdown [-t html|roff|text] [-w COLS] [FILE..]       markdown README.md > readme.html
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

(:
   ; the width the output wants: -w, else the terminal on fd 1, else 80
   (lens-w t ws) (: v (uoptv t 119)
                    (? (string? v) (: n (uatoi v) (? (0 < n) n 80))
                       (two? ws && 0 < >ws) >ws
                       80))
   ; one trailing newline, always: a shower ends where the document does, and a tool that
   ; writes to a terminal owes the prompt its own line
   (lensnl s) (? (#s && s (#s - 1) = 10) s (s + "\n"))
   ; one lay over the operands, or over stdin when there are none. the status is the worst
   ; of the files, and a charm: the seat quits with it
   (lensrun lay nm fs)
    (: (one p) (: r (uread p)
                  (? (two? r) (puts (lensnl (lay <>r p)), 0)
                     (say err (nm + ": cannot open " + p), put err 10, 1)))
       (? (two? fs) (foldl (\ a p (: r (one p) (? (a || r) 1 0))) 0 fs)
          (puts (lensnl (lay (slurp in) "")), 0)))
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
            (? !c () (udie 2 ("html2text: unknown option -" + string c))))
       ws (tty 1)                                     ; the width is the OUTPUT's
       w (lens-w t ws)
       tty? (two? ws)
       (lensrun (\ s p (h2t-lay s w tty? p)) "html2text" <>>o))

   md-usage "usage: markdown [-t html|roff|text] [-w COLS] [FILE..]"
   md-tos ["html" "roff" "text"]
   (md-lay s to w tty? p)
    (? (to = "roff") ((cite 'lapiz 'md->rf) s)
       (to = "text") (? tty? (lens-pics ((cite 'lapiz 'mdread) s) w p) (usgr ((cite 'lapiz 'md->tty) s w)))
       ((cite 'lapiz 'md->ht) s))
   (markdown-main as)
    (: t (tablet 0)
       o (uopt as t '(116 119) '(101) ())                   ; -t and -w take values
       _ (? (two? o) () (udie 2 md-usage))
       _ (: c (uoptun t '(116 119))
            (? !c () (udie 2 ("markdown: unknown option -" + string c))))
       v (uoptv t 116)
       to (? (string? v) v "html")
       _ (? (elem to md-tos) () (udie 2 md-usage))
       ws (tty 1)
       w (lens-w t ws)
       tty? ((two? ws) && (to = "text"))
       (lensrun (\ s p (md-lay s to w tty? p)) "markdown" <>>o)))
) ; module 'kore
