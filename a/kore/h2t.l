; a/kore/h2t.l -- `html2text`: a page's prose, laid out for a terminal.
;
; the same three-part path `man` takes, with the first part swapped: lapiz's html reader
; takes the page to the document AST, its tty shower lays that out at a width, and what is
; left over here is the operand walk. papel already runs this lens the other way (markdown
; in, html out), so reading html back costs a face and not a parser.
;
;   html2text [-w COLS] [FILE..]        html2text index.html    wget -O - URL | html2text
;
; the width is the terminal's, or -w, or 80 where there is no terminal to ask. with no
; operands it reads stdin, which is what makes it a filter worth having on the end of a
; pipe. attributes ride out when the output is a terminal and come off when it is not.
;
; what it is NOT is a browser. a page is prose to this tool: lapiz's scrub drops the
; script, the style and the head, and unwraps the containers, so what arrives at the
; reader is headings, paragraphs, lists, definition lists, quotes, displays and the inline
; spans. a table is unwrapped to its cells, which reads as prose and not as a table --
; the middle has no table node and inventing one here would be a lie about the lens.
; forms, images and anything positioned by css are gone, and that is the whole design:
; this answers "what does the page SAY", and nothing about what it looks like.
(module 'kore
(borrow 'posix)

(:
   h2t-usage "usage: html2text [-w COLS] [FILE..]"
   (h2t-lay s w tty?) (: t ((cite 'lapiz 'ht->tty) s w) (? tty? t (usgr t)))
   (html2text-main as)
    (: t (tablet 0)
       o (uopts as t '(119) ())                       ; -w takes a value
       _ (? (two? o) () (udie 2 h2t-usage))
       _ (foldl (\ a c (? (c = 119) a
                          (udie 2 ("html2text: unknown option -" + string c)))) 0 (keys t))
       fs <>>o
       ws (winsize 1)                                 ; the width is the OUTPUT's
       v (uoptv t 119)
       w (? (string? v) (: n (uatoi v) (? (0 < n) n 80))
            (two? ws && 0 < >ws) >ws
            80)
       tty? (two? ws)
       (one p) (: r (uread p)
                  (? (two? r) (: _ (puts (h2t-lay <>r w tty?)) 0)
                     (: _ (say err ("html2text: cannot open " + p)) _ (put err 10) 1)))
       (? (two? fs) (foldl (\ a p (: r (one p) (? (a || r) 1 0))) 0 fs)
          (: _ (puts (h2t-lay (slurp in) w tty?)) 0))))
) ; module 'kore
