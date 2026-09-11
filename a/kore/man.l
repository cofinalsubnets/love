; a/kore/man.l -- `man`: the page a name has, laid out for a terminal.
;
; the tree writes its man pages in doc/*.md and the build shows them as roff (u/mkman.l,
; through a/lapiz.l). reading one back is the same lens run the other way: lapiz's roff
; reader takes the page to the document AST, its tty shower lays that out at a width, and
; a/kore/less.l pages the result. so man owns none of the three hard parts -- it is the
; search path, the decompression, and the handing over.
;
;   man [-w] [SECTION] NAME..     man 3 printf     man -w ls
;
; the search is the usual one: MANPATH if it is set, else the three roots below, each
; walked in section order. a page may be plain or gzipped (a/gz/) -- the suffix is not
; consulted, the two magic bytes are, so a page named without .gz still reads. a page
; whose whole body is `.so man1/other.1` is a redirect and is followed once.
;
; -w answers the path and reads nothing, which is what a script wants and what makes the
; search testable without a terminal. with no terminal at all the page is poured, and
; poured plain: the attributes are the terminal's business and a pipe is not one.
;
; out of scope, and said rather than found: mdoc. a BSD-style page (.Dd/.Sh/.Nm, about
; one page in twenty-five here) is a different macro set that lapiz's roff surface does
; not read, and rendering it anyway produces a page of macro names -- so it is named as
; unsupported instead. apropos/whatis, the cat cache, and .so chains deeper than one
; are also absent.
(module 'kore
(borrow 'posix)

(:
   man-usage "usage: man [-w] [SECTION] NAME.."
   ; the order a name is looked for in, and the roots it is looked for under
   mansecs '("1" "n" "l" "8" "3" "0" "2" "5" "4" "9" "6" "7")
   manroots '("/usr/local/share/man" "/usr/share/man" "/usr/local/man")
   (man-roots _)
    (: e (getenv "MANPATH")
       l (? (string? e && tally e) (usplit 58 e) manroots)
       (filter udirp l))
   ; a page's name is what is left when the compression suffix and the section suffix come
   ; off, and both come off the RIGHT. a stem taken at the FIRST dot loses every name that
   ; has one in it: valac-0.56.1.gz would answer `valac-0`, and systemd-foo.service.7.gz
   ; would answer `systemd-foo`, and neither finds its page.
   manzs '(".gz" ".bz2" ".xz" ".zst" ".Z" ".lz" ".lzma")
   (man-pre? f p) (: n #p (n < #f && p = snip f 0 n))
   (man-suf? f x) (: n #f m #x (m < n && x = snip f (n - m) n))
   (man-nodot f) (: n #f
                    (go i) (? (i < 0) f (f i = 46) (snip f 0 i) (go (i - 1)))
                    (go (n - 1)))
   (man-stem f)
    (man-nodot ((: (go l) (? (one? l) f (man-suf? f <l) (snip f 0 (#f - #(<l))) (go >l))) manzs))
   ; a path's last component, and the first component of a relative one
   (man-base p) (: n #p
                   (go i) (? (i < 0) p (p i = 47) (snip p (i + 1) n) (go (i - 1)))
                   (go (n - 1)))
   (man-head p) (: n #p
                   (go i) (? (n <= i) p (p i = 47) (snip p 0 i) (go (i + 1)))
                   (go 0))
   ; a directory's entries that are this name's page, shortest suffix first -- so foo.1
   ; is preferred to foo.1p.gz without either being spelled out here
   (man-hits d nm)
    (: r (readdir d)
       (? !(two? r) () (sort (filter (\ f (man-stem f = nm)) r))))
   (man-look nm sec)
    ((: (go rs)
        (? !(two? rs) ()
           (: d (<rs + "/man" + sec)
              h (? (udirp d) (man-hits d nm) ())
              (? (two? h) (d + "/" + <h) (go >rs)))))
     (man-roots ()))
   ; a name with no section given walks the sections in order
   (man-find nm sec)
    (? (tally sec) (man-look nm sec)
       ((: (go ss) (? !(two? ss) ()
                      (: p (man-look nm <ss) (? p p (go >ss))))) mansecs))
   ; the magic decides, not the name: gzip is 1f 8b, and a page may carry either spelling
   (man-gz? s) (1 < #s && s 0 = 31 && s 1 = 139)
   (man-text p)
    (: r (uread p)
       (? !(two? r) ()
          (: s <>r
             (? !(man-gz? s) s
                (: u ((cite 'gz 'gz-unzip) s) (? (two? u) <>u ()))))))
   ; `.so man1/other.1` is the whole of a redirect page
   (man-so s)
    (: l (filter (\ x (tally x && !(man-pre? x ".\\\""))) (lines s))
       (? !(two? l) () (man-pre? <l ".so ") (snip <l 4 #(<l)) ()))
   ; the man root a page path sits under -- up past the file AND its section directory
   (man-root p) (: n #p
                   (go i k) (? (i < 0) "" (p i = 47) (? k (snip p 0 i) (go (i - 1) 1)) (go (i - 1) k))
                   (go (n - 1) 0))
   ; ..and the file a .so names. it names an UNCOMPRESSED path and the file it names is
   ; usually gzipped, so the target is looked up the way any page is -- by stem, in its
   ; section directory -- rather than opened under the name as written. that is the whole
   ; of `man zcat`: every gzip alias in man1 is a .so onto gzip.1, and the file is gzip.1.gz.
   (man-follow root so)
    (: d (root + "/" + man-head so)
       h (? (udirp d) (man-hits d (man-stem (man-base so))) ())
       (? (two? h) (d + "/" + <h) ()))
   ; a page that spells .Dd or .Sh and never .TH is mdoc, which this reader does not read
   (man-mdoc? s)
    (: l (lines s)
       (go ls th)
        (? !(two? ls) th
           (man-pre? <ls ".TH ") 0
           (man-pre? <ls ".Dd ") 1
           (man-pre? <ls ".Sh ") 1
           (go >ls th))
       (go l 0))
   ; the escapes come off when there is no terminal to read them
   (man-plain s)
    (: n #s
       o (jug 0)
       (go i) (? (n <= i) (slurp o)
                 (i + 1 < n && s i = 27 && s (i + 1) = 91)
                  ((: (g k) (? (n <= k) (slurp o)
                               (s k = 109) (go (k + 1))
                               (g (k + 1)))) (i + 2))
                 (: _ (put o (s i)) (go (i + 1))))
       (go 0))
   ; the page found, read, redirected and rendered. [1 path text] when it lands and
   ; [0 complaint] when it does not -- every way of failing carries the sentence for it
   (man-lay nm sec w)
    (: p (man-find nm sec)
       (? !p [0 ("man: no manual entry for " + nm)]
          (: s (man-text p)
             (? !s [0 ("man: cannot read " + p)]
                (: so (man-so s)
                   p2 (? so (man-follow (man-root p) so) ())
                   ; a redirect whose target is not here has no page of its own to fall
                   ; back on -- the .so line IS the whole file, and rendering it lays a
                   ; blank screen. say which target is missing instead.
                   (? (so && !p2) [0 ("man: " + nm + " redirects to " + so + ", which is not here")]
                      (: s2 (? p2 (: t (man-text p2) (? t t s)) s)
                         (? (man-mdoc? s2)
                             [0 ("man: " + nm + " is an mdoc page, which is not read yet")]
                            [1 (? p2 p2 p) ((cite 'lapiz 'rf->tty) s2 w)]))))))))
   (man-moan m) (: _ (say err m) _ (put err 10) 1)
   ; a leading operand is the section only if it LOOKS like one -- a digit, then up to three
   ; more -- and only if a name follows it. `man 411toppm` names a page, and taking its
   ; first byte for a section leaves no name at all and answers the usage instead.
   (man-sec? rest)
    ((two? rest) && (two? >rest) && (0 < #(<rest) <= 4) && (47 < (<rest 0) < 58))
   (man-main as)
    (: t (tablet 0)
       o (uopts as t () ())
       _ (? (two? o) () (udie 2 man-usage))
       _ (foldl (\ a c (? (c = 119) a (udie 2 ("man: unknown option -" + string c)))) 0 (keys t))
       rest <>>o
       sec? (man-sec? rest)
       sec (? sec? <rest "")
       nms (? sec? >rest rest)
       _ (? (two? nms) () (udie 2 man-usage))
       ws (winsize 0)
       hw (? (two? ws) [(? (0 < <ws) <ws 24) (? (0 < >ws) >ws 80)] ())
       w (? (two? hw) <>hw 80)
       ; -w reads nothing: the search is the whole answer
       (wh nm) (: p (man-find nm sec)
                  (? p (: _ (puts (p + "\n")) 0)
                     (man-moan ("man: no manual entry for " + nm))))
       (one nm) (: r (man-lay nm sec w)
                   (? !<r (man-moan <>r)
                      !(two? hw) (: _ (puts (man-plain <>>r)) 0)
                      (: _ (pgride () (lines <>>r)
                                   (nm + (tally sec ? ("(" + sec + ")") "")) in
                                   <>hw <hw (tablet 0) "")
                         0)))
       ; the status is the worst of the names, and a charm: the seat quits with it
       (foldl (\ a nm (: r (peep t 119 0 ? (wh nm) (one nm)) (? (a || r) 1 0))) 0 nms)))
) ; module 'kore
