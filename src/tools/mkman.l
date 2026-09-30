; src/tools/mkman.l -- markdown -> roff(man), through the lapiz lens (src/apps/lapiz.l): the man
; pages are written once, in doc/*.md, and laid as roff at build time. run from the repo root:
;   love src/tools/mkman.l file.md [love_version.h]
; @VERSION@ is the one placeholder; the second argument fills it from love_version.h, and with
; none it rides through, which is what a hand run wants.
(borrow 'lapiz)
(borrow 'posix)
(: (rd p) (open p "r" @ q
             (q ? (slurp q @ t (close q, t))
                (say err ("mkman: cannot read " + p), put err 10, quit 1)))
   ; the version is whatever sits between love_version.h's two quotes
   (quoted t)
    (: n #t
       (go i a) (? (n <= i) ""
                   !(t i = 34) (go (i + 1) a)
                   (two? a) (snip t <a i)
                   (go (i + 1) [(i + 1)]))
       (go 0 ()))
   ; segments onto a list and joined once -- a per-hit concat would re-copy the whole
   ; page each time, which on a man page is quadratic for no reason
   (fill t k v)
    (: n #t m #k
       (go i st acc)
        (? (n <= i) (foldl (+) "" (rev (snip t st n . acc)))
           (i + m <= n && snip t i (i + m) = k)
            (go (i + m) (i + m) (v . snip t st i . acc))
           (go (i + 1) st acc))
       (go 0 0 ()))
   vh >>argv
   rf (md->rf (rd <>argv))
   (puts (two? vh ? (fill rf "@VERSION@" (quoted (rd <vh))) rf), 0))
