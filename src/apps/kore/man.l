; src/apps/kore/man.l -- `man`: the page a name has, laid out for a terminal.
;
;   man [-w] [SECTION] NAME..     man 3 printf     man -w ls
;
; lapiz's roff reader takes the page to the document AST, its tty shower lays it out, and
; less.l pages it; man is the search path, the decompression, and the handing over. MANPATH,
; else the roots below, in section order. a page is gzipped by its magic bytes, not its
; suffix; a lone `.so` redirect is followed once. -w answers the path and reads nothing; no
; terminal pours the page plain. mdoc (.Dd/.Sh/.Nm) is refused by name, not rendered.
(module 'kore
(borrow 'cli)
(borrow 'posix)

(:
   man-usage "usage: man [-w] [SECTION] NAME.."
   ; the order a name is looked for in, and the roots it is looked for under
   mansecs '("1" "n" "l" "8" "3" "0" "2" "5" "4" "9" "6" "7")
   manroots '("/usr/local/share/man" "/usr/share/man" "/usr/local/man")
   (man-roots _)
    (: e (getenv "MANPATH")
       l (string? e && #e ? (usplit 58 e) manroots)
       (filter udirp l))
   ; a page's name is what is left when the compression and section suffixes come off the
   ; right -- never at the first dot, or valac-0.56.1.gz would answer `valac-0`
   manzs '(".gz" ".bz2" ".xz" ".zst" ".Z" ".lz" ".lzma")
   (man-pre? f p) (#p @ n (n < #f && p = snip f 0 n))
   (man-suf? f x) (: n #f m #x (m < n && x = snip f (n - m) n))
   (man-nodot f) (: n #f
                    (go i) (? (i < 0) f (f i = 46) (snip f 0 i) (go (i - 1)))
                    (go (n - 1)))
   (man-stem f)
    (man-nodot ((: (go l) (? (atom? l) f (man-suf? f <l) (snip f 0 (#f - #(<l))) (go >l))) manzs))
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
    (readdir d @ r
       (atom? r ? () (sort (filter (f \ (man-stem f = nm)) r))))
   (man-look nm sec)
    ((: (go rs)
        (atom? rs ? ()
         (: d (<rs + "/man" + sec)
            h (udirp d ? (man-hits d nm))
            (two? h ? (d + "/" + <h) (go >rs)))))
     (man-roots ()))
   ; a name with no section given walks the sections in order
   (man-find nm sec)
    (#sec ? (man-look nm sec)
       ((: (go ss) (atom? ss ? ()
                    (man-look nm <ss @ p (p ? p (go >ss))))) mansecs))
   ; the magic decides, not the name: gzip is 1f 8b, and a page may carry either spelling
   (man-gz? s) (1 < #s && s 0 = 31 && s 1 = 139)
   (man-text p)
    (uread p @ r
       (atom? r ? ()
        (<>r @ s
           (!(man-gz? s) ? s
              (cite 'gz 'gz-unzip s @ u (two? u ? <>u))))))
   ; `.so man1/other.1` is the whole of a redirect page
   (man-so s)
    (filter (x \ (#x && !(man-pre? x ".\\\""))) (lines s) @ l
       (? (atom? l) () (man-pre? <l ".so ") (snip <l 4 #(<l)) ()))
   ; the man root a page path sits under -- up past the file AND its section directory
   (man-root p) (: n #p
                   (go i k) (? (i < 0) "" (p i = 47) (k ? (snip p 0 i) (go (i - 1) 1)) (go (i - 1) k))
                   (go (n - 1) 0))
   ; ..and the file a .so names. it names an UNCOMPRESSED path and the file it names is
   ; usually gzipped, so the target is looked up the way any page is -- by stem, in its
   ; section directory -- rather than opened under the name as written. that is the whole
   ; of `man zcat`: every gzip alias in man1 is a .so onto gzip.1, and the file is gzip.1.gz.
   (man-follow root so)
    (: d (root + "/" + man-head so)
       h (udirp d ? (man-hits d (man-stem (man-base so))))
       (two? h ? (d + "/" + <h)))
   ; a page that spells .Dd or .Sh and never .TH is mdoc, which this reader does not read
   (man-mdoc? s)
    (: l (lines s)
       (go ls th)
        (? (atom? ls) th
           (man-pre? <ls ".TH ") 0
           (man-pre? <ls ".Dd ") 1
           (man-pre? <ls ".Sh ") 1
           (go >ls th))
       (go l 0))
   ; the page found, read, redirected and rendered. [1 path text] when it lands and
   ; [0 complaint] when it does not -- every way of failing carries the sentence for it
   (man-lay nm sec w)
    (man-find nm sec @ p
       (!p ? [0 ("man: no manual entry for " + nm)]
          (man-text p @ s
             (!s ? [0 ("man: cannot read " + p)]
                (: so (man-so s)
                   p2 (so ? (man-follow (man-root p) so))
                   ; a redirect whose target is missing: the .so line is the whole file,
                   ; so say which target, rather than lay a blank screen
                   (so && !p2 ? [0 ("man: " + nm + " redirects to " + so + ", which is not here")]
                    ((p2 ? (man-text p2 @ t (t ? t s)) s) @ s2
                       (man-mdoc? s2 ?
                           [0 ("man: " + nm + " is an mdoc page, which is not read yet")]
                          [1 (p2 ? p2 p) (cite 'lapiz 'rf->tty s2 w)]))))))))
   (man-moan m) (say err m, put err 10, 1)
   ; a leading operand is the section only if it LOOKS like one -- a digit, then up to three
   ; more -- and only if a name follows it. `man 411toppm` names a page, and taking its
   ; first byte for a section leaves no name at all and answers the usage instead.
   (man-sec? rest)
    (two? rest && two? >rest && 0 < #(<rest) <= 4 && 47 < <rest 0 < 58)
   (man-main as)
    (: t {}
       o (uopt as t () '(101) ())
       _ (two? o ? () (udie 2 man-usage))
       _ (uoptbad as t '(119) @ c (!c ? () (udie 2 ("man: unknown option -" + string c))))
       rest <>>o
       sec? (man-sec? rest)
       sec (sec? ? <rest "")
       nms (sec? ? >rest rest)
       _ (two? nms ? () (udie 2 man-usage))
       ws (tty 1)
       hw (two? ws ? [(0 < <ws ? <ws 24) (0 < >ws ? >ws 80)])
       w (two? hw ? <>hw 80)
       ; -w reads nothing: the search is the whole answer
       (wh nm) (man-find nm sec @ p
                  (p ? (puts (p + "\n"), 0)
                     (man-moan ("man: no manual entry for " + nm))))
       (one nm) (man-lay nm sec w @ r
                   (? !<r (man-moan <>r)
                      (atom? hw) (puts (usgr <>>r), 0)
                      (pgride () (lines <>>r)
                                   (nm + (#sec ? ("(" + sec + ")") "")) in
                                   <>hw <hw {} "", 0)))
       ; the status is the worst of the names, and a charm: the seat quits with it
       (foldl (\ a nm ((peep t 119 0 ? (wh nm) (one nm)) @ r (a || r ? 1 0))) 0 nms)))
) ; module 'kore
