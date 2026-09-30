; test/caja/docs.l -- src/apps/caja/doc.l held to TeX: a whole document, laid out by caja's
; shower, set twice. the shower's tokens go through caja to OUT.dvi, and through cp-tex to
; OUT.tex, which test/gate/caja.sh gives tex -ini; the two DVIs must be one file.
;
;   love test/caja/docs.l OUT hyphen.tex TFM.. FILE     FILE markdown (.md) or roff
;
; the TFMs are cd-fonts' in order; a gzipped man page is unpacked by the caller.
(: _ (borrow 'posix)
   _ (borrow 'lapiz)
   _ (borrow "src/apps/tfm.l")
   _ (borrow "src/apps/caja/box.l")
   _ (borrow 'caja-box)
   _ (borrow "src/apps/caja/par.l")
   _ (borrow 'caja-par)
   _ (borrow "src/apps/caja/page.l")
   _ (borrow 'caja-page)
   _ (borrow "src/apps/caja/doc.l")
   _ (borrow 'caja-doc)
   (die m) (say err ("docs: " + m + "\n"), flush err, quit 1)
   (slurpf p) (uread p @ [1 x] (x + "") (die ("cannot read " + p)))
   (spit p s) (open p "w" @ q (hot? q ? (say q s, close q) (die ("cannot write " + p))))
   (md? p) (#p @ n (n > 3 && snip p (n - 3) n = ".md"))
   (main args)
    (: out (args 0) hy (args 1) nf #cd-fonts
       tfms (map (k \ slurpf (args (2 + k))) ^nf)
       src (args (2 + nf))
       s (slurpf src)
       doc (md? src ? (mdread s) (rfread s))
       J (cd-job tfms (slurpf hy) [1776 7 4 720])
       (spit (out + ".tex") (cd-tex J doc hy),
        spit (out + ".dvi") (cd-dvi J doc)))
   (main >argv))
