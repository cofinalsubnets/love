; a/kore/lens.l -- the two kore doors onto lapiz: `html2text` and `markdown`.
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
; a table is unwrapped to its cells, which reads as prose and not as a table -- the middle
; has no table node and inventing one here would be a lie about the lens. forms, images and
; anything positioned by css are gone, and that is the whole design: this answers "what does
; the page SAY", and nothing about what it looks like.
(module 'kore
(borrow 'posix)

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
                  (? (two? r) (: _ (puts (lensnl (lay <>r))) 0)
                     (: _ (say err (nm + ": cannot open " + p)) _ (put err 10) 1)))
       (? (two? fs) (foldl (\ a p (: r (one p) (? (a || r) 1 0))) 0 fs)
          (: _ (puts (lensnl (lay (slurp in)))) 0)))

   h2t-usage "usage: html2text [-w COLS] [FILE..]"
   (h2t-lay s w tty?) (: t ((cite 'lapiz 'ht->tty) s w) (? tty? t (usgr t)))
   (html2text-main as)
    (: t (tablet 0)
       o (uopts as t '(119) ())                       ; -w takes a value
       _ (? (two? o) () (udie 2 h2t-usage))
       _ (foldl (\ a c (? (c = 119) a
                          (udie 2 ("html2text: unknown option -" + string c)))) 0 (keys t))
       ws (tty 1)                                     ; the width is the OUTPUT's
       w (lens-w t ws)
       tty? (two? ws)
       (lensrun (\ s (h2t-lay s w tty?)) "html2text" <>>o))

   md-usage "usage: markdown [-t html|roff|text] [-w COLS] [FILE..]"
   md-tos ["html" "roff" "text"]
   (md-lay s to w tty?)
    (? (to = "roff") ((cite 'lapiz 'md->rf) s)
       (to = "text") (: t ((cite 'lapiz 'md->tty) s w) (? tty? t (usgr t)))
       ((cite 'lapiz 'md->ht) s))
   (markdown-main as)
    (: t (tablet 0)
       o (uopts as t '(116 119) ())                   ; -t and -w take values
       _ (? (two? o) () (udie 2 md-usage))
       _ (foldl (\ a c (? (elem c '(116 119)) a
                          (udie 2 ("markdown: unknown option -" + string c)))) 0 (keys t))
       v (uoptv t 116)
       to (? (string? v) v "html")
       _ (? (elem to md-tos) () (udie 2 md-usage))
       ws (tty 1)
       w (lens-w t ws)
       tty? ((two? ws) && (to = "text"))
       (lensrun (\ s (md-lay s to w tty?)) "markdown" <>>o)))
) ; module 'kore
