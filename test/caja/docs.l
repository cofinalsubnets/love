; test/caja/docs.l -- apps/caja/doc.l held to TeX: a whole document, laid out by caja's
; shower, set twice. the shower's tokens go through caja to OUT.dvi, and through cp-tex to
; OUT.tex, which test/gate/caja.sh gives tex -ini; the two DVIs must be one file.
;
;   love test/caja/docs.l OUT hyphen.tex TFM.. FILE     FILE markdown (.md) or roff
;
; the TFMs are cd-fonts' in order; a gzipped man page is unpacked by the caller.
(: _ (borrow 'posix)
   _ (borrow 'lapiz)
   _ (borrow "apps/tfm.l")
   _ (borrow "apps/caja/box.l")
   _ (borrow 'caja-box)
   _ (borrow "apps/caja/par.l")
   _ (borrow 'caja-par)
   _ (borrow "apps/caja/page.l")
   _ (borrow 'caja-page)
   _ (borrow "apps/caja/doc.l")
   _ (borrow 'caja-doc)
   (die m) (: _ (say err ("docs: " + m + "\n")) _ (flush err) (quit 1))
   (slurpf p) (uread p @ [1 x] (x + "") (die ("cannot read " + p)))
   (spit p s) (: q (open p "w") (? (hot? q) (: _ (say q s) (close q)) (die ("cannot write " + p))))
   (md? p) (: n #p (n > 3 && snip p (n - 3) n = ".md"))
   (main args)
    (: out (args 0) hy (args 1) nf #cd-fonts
       tfms (map (k \ slurpf (args (2 + k))) ^nf)
       src (args (2 + nf))
       s (slurpf src)
       doc (? (md? src) (mdread s) (rfread s))
       J (cd-job tfms (slurpf hy) [1776 7 4 720])
       _ (spit (out + ".tex") (cd-tex J doc hy))
       (spit (out + ".dvi") (cd-dvi J doc)))
   (main >argv))
