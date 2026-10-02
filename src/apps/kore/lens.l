; src/apps/kore/lens.l -- the two kore doors onto lapiz: `html2text` and `markdown`.
;
;   html2text [-w COLS] [FILE..]                          html2text index.html
;   markdown [-t html|roff|text|cells] [-w COLS] [FILE..] markdown README.md > readme.html
;   markdown -t dvi [FILE]                                markdown README.md > readme.dvi
;
; the width is -w, else the terminal's, else 80; no operands reads stdin. attributes ride
; out only to a terminal. -t cells is -t text broken by caja (src/apps/caja/cell.l).
; `markdown` writes a fragment -- papel owns the page template. html2text reads a page as
; prose: lapiz's scrub drops script, style and head; an image says its [alt], and on a
; terminal a local one is drawn under it (pic.l).
(module 'kore
(borrow 'cli)
(borrow 'posix)
(borrow 'cal)

(:
   ; the width the output wants: -w, else the terminal on fd 1, else 80
   (lens-w t ws) (uoptv t 119 @ v
                    (? (string? v) (uatoi v @ n (0 < n ? n 80))
                       (two? ws && 0 < >ws) >ws
                       80))
   ; one trailing newline, always: a shower ends where the document does, and a tool that
   ; writes to a terminal owes the prompt its own line
   (lensnl s) (#s && s (#s - 1) = 10 ? s (s + "\n"))
   ; one lay over the operands, or over stdin when there are none. the status is the worst
   ; of the files, and a charm: the seat quits with it
   (lensrun lay nm fs)
    (: (one p) (uread p @ r
                  (two? r ? (puts (lensnl (lay <>r p)), 0)
                   (say err (nm + ": cannot open " + p), put err 10, 1)))
       (two? fs ? (foldl (\ a p (one p @ r (a || r ? 1 0))) 0 fs)
        (puts (lensnl (lay (slurp in) "")), 0)))
   ; the directory a path is in, with its slash; "" for a bare name
   (lens-dir p) (: (g i) (? (i < 0) "" (p i = 47) (snip p 0 (i + 1)) (g (i - 1))) (g (#p - 1)))
   (lens-has s p) (: n #p (g i) (? (#s < i + n) 0 (snip s i (i + n) = p) 1 (g (i + 1))) (g 0))
   ; an image's src -> the file it names, () for one on the web
   (lens-path dir src)
    (src @ ("file://" + p) p
           ("data:" + _) ()
           (? (lens-has src "://")) ()
           (? (src 0 = 47)) src
           (dir + src))
   ; a doc laid at w for a terminal, each local picture drawn under its image's line, no
   ; taller than the screen
   (lens-pics d w p)
    (: r (cite 'lapiz 'ttpics d w) ls (lines <r)
       ws (tty 1) rows (two? ws && 3 < <ws ? (<ws - 2))
       deep (cite 'kore 'pic-deep 0) dir (lens-dir p)
       (draw t a)
        (<a @ nm
           (nm @ (" img " + (s && 0 < #s))
              (: f (lens-path dir s)
                 rd (string? f ? (uread f))
                 im (two? rd ? (cite 'kore 'pic-decode <>rd))
                 (two? im ? (pin t (a 1) (peep t (a 1) () + cite 'kore 'ww-art im w rows deep)) t))
              t))
       pics (foldl draw {} (r 1))
       (catmap (i \ (ls i) + "\n" + catmap (x \ x + "\n") (pics i)) ^#ls))

   h2t-usage "usage: html2text [-w COLS] [FILE..]"
   (h2t-lay s w tty? p) (tty? ? (lens-pics (cite 'lapiz 'htread s) w p) (usgr (cite 'lapiz 'ht->tty s w)))
   (html2text-main as)
    (: t {}
       o (uopt as t '(119) '(101) ())                       ; -w takes a value
       _ (two? o ? () (udie 2 h2t-usage))
       _ (uoptbad as t '(119) @ c
            (!c ? () (udie 2 ("html2text: unknown option -" + string c))))
       ws (tty 1)                                     ; the width is the OUTPUT's
       w (lens-w t ws)
       tty? (two? ws)
       (lensrun (\ s p (h2t-lay s w tty? p)) "html2text" <>>o))

   md-usage "usage: markdown [-t html|roff|text|cells|dvi] [-w COLS] [FILE..]"
   md-tos ["html" "roff" "text" "cells" "dvi"]
   ; -t dvi: caja sets the document in pages (src/apps/caja/doc.l), with Computer Modern's
   ; metrics and plain's patterns out of a TeX tree -- $CAJA_TEXMF, else where TeX Live puts
   ; one. one file or stdin; a man page (its first line a request) is read as roff
   texmf-roots ["/usr/share/texmf-dist" "/usr/share/texlive/texmf-dist" "/usr/local/share/texmf-dist"]
   (lens-texmf rel)
    (: e (getenv "CAJA_TEXMF")
       rs (string? e && 0 < #e ? (e . texmf-roots) texmf-roots)
       (go l) (two? l ? (uread (<l + "/" + rel) @ r (two? r ? (<>r + "") (go >l))))
       (go rs))
   (lens-roff? s) (0 < #s && (s 0 = 46 || 1 < #s && s 0 = 39 && s 1 = 92))
   (md-dvi s)
    (: tfms (map (n \ lens-texmf ("fonts/tfm/public/cm/" + n + ".tfm")) (cite 'caja-doc 'cd-fonts))
       hy (lens-texmf "tex/generic/hyphen/hyphen.tex")
       _ (elem () (hy . tfms) ?
            (udie 1 "markdown: -t dvi wants Computer Modern's TFMs and hyphen.tex from a TeX tree; set CAJA_TEXMF"))
       ms (clock 0) sec (ms // 1000) ymd (civil (sec // 86400))
       J (cite 'caja-doc 'cd-job tfms hy [(ymd 0) (ymd 1) (ymd 2) (sec % 86400 // 60)])
       doc (lens-roff? s ? (cite 'lapiz 'rfread s) (cite 'lapiz 'mdread s))
       (cite 'caja-doc 'cd-dvi J doc))
   (md-dvi-main fs)
    (: _ (two? (tty 1) ? (udie 2 "markdown: a DVI is not for a terminal; send it to a file"))
       _ (1 < #fs ? (udie 2 "markdown: -t dvi sets one document"))
       s (two? fs ? (uread <fs @ r (two? r ? (<>r + "") (udie 1 ("markdown: cannot open " + <fs)))) (slurp in))
       (say out (md-dvi s),
        flush out,
        0))
   (md-lay s to w tty? p)
    (? (to = "roff") (cite 'lapiz 'md->rf s)
       (to = "text") (tty? ? (lens-pics (cite 'lapiz 'mdread s) w p) (usgr (cite 'lapiz 'md->tty s w)))
       (to = "cells") (: d (lens-roff? s ? (cite 'lapiz 'rfread s) (cite 'lapiz 'mdread s))
                         o (cite 'caja-cell 'cc-show d w)
                         (tty? ? o (usgr o)))
       (cite 'lapiz 'md->ht s))
   (markdown-main as)
    (: t {}
       o (uopt as t '(116 119) '(101) ())                   ; -t and -w take values
       _ (two? o ? () (udie 2 md-usage))
       _ (uoptbad as t '(116 119) @ c
            (!c ? () (udie 2 ("markdown: unknown option -" + string c))))
       v (uoptv t 116)
       to (string? v ? v "html")
       _ (elem to md-tos ? () (udie 2 md-usage))
       ws (tty 1)
       w (lens-w t ws)
       tty? (two? ws && (to = "text" || to = "cells"))
       (to = "dvi" ? (md-dvi-main <>>o)
        (lensrun (\ s p (md-lay s to w tty? p)) "markdown" <>>o))))
) ; module 'kore
