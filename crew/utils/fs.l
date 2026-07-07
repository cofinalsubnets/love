; crew/utils/fs.l -- the fs tools of aiutils: ls, cp, mv, rm, mkdir, rmdir, ln,
; touch, pwd, chmod. every tool a <name>-main dispatched by au (crew/utils/au.l),
; same as core.l -- a toolbox, no seat, au is its door. loads after core.l in the
; cat and rides its u-floor (udie, uread, ubase); the effects ride host/fs.c +
; init.c's posix_ lane (stat readdir unlink mkdir rename symlink hardlink rmdir
; chmod utime cwd), whose convention shapes every loop here: an effect op nets
; truthy exactly when something went wrong. a body-less top-level `:` leaking
; uoct (lawed in law.l) and the mains.
(:
   ; octal text -> a charm ("755" is 493), chmod's one argument shape
   (uoct s)
    (: n (tally s)
       (go i acc) (? (< i n) (go (+ i 1) (+ (* 8 acc) (- (s i) 48))) acc)
       (go 0 0))
   ; is the path a directory (stat follows links, like the tools want)
   (udirp q) (: st (stat q) (&& (two? st) (= 16384 (& 61440 (cauup st)))))
   ; a file destination: into a directory the source's basename lands beside
   (udest src dst) (? (udirp dst) (+ dst (+ "/" (ubase src ""))) dst)
   ; copy bytes + permission bits (cp's heart; mv's cross-device leg)
   (ucopy who src dst)
    (: r (uread src)
       _ (? (two? r) () (udie 1 (+ who (+ ": cannot open " src))))
       q (open dst "w")
       _ (? q () (udie 1 (+ who (+ ": cannot create " dst))))
       _ (say q (caup r)) _ (close q)
       st (stat src)
       _ (? (two? st) (chmod dst (& 4095 (cauup st))) ())
       1)

   ; -- pwd: where we stand --
   (pwd-main _) (: _ (say out (cwd ())) _ (put out 10) _ (flush out) (quit 0))

   ; -- ls: a directory's entries, sorted, dotfiles held back (-a shows them);
   ; a file argument answers its own name --
   (ls-main as)
    (: a? (&& (two? as) (= (cap as) "-a"))
       fs (? a? (cup as) as)
       (one p ok)
        (? (! (two? (stat p)))
           (: _ (say err (+ "ls: cannot access " p)) _ (put err 10) 0)
           (! (udirp p)) (: _ (say out p) _ (put out 10) ok)
           (: (go m) (? (! (two? m)) ok
                        (: _ (? (&& (! a?) (= ((cap m) 0) 46)) ()
                                (: _ (say out (cap m)) (put out 10)))
                           (go (cup m))))
              (go (sort (readdir p)))))
       (go a ok) (? (two? a) (go (cup a) (one (cap a) ok))
                    (: _ (flush out) (quit (? ok 0 1))))
       (go (? (two? fs) fs (L ".")) 1))

   ; -- cp and mv: a directory destination pulls the basename in beside --
   (cp-main as)
    (? (! (two? (cup as))) (udie 2 "usage: cp SRC DST")
       (: _ (ucopy "cp" (cap as) (udest (cap as) (caup as))) (quit 0)))
   (mv-main as)
    (? (! (two? (cup as))) (udie 2 "usage: mv SRC DST")
       (: src (cap as) dst (udest (cap as) (caup as))
          e (rename src dst)
          (? (! e) (quit 0)
             (= e 18) (: _ (ucopy "mv" src dst) _ (unlink src) (quit 0))   ; EXDEV: the long way
             (udie 1 (+ "mv: cannot move " src)))))

   ; -- rm: unlink, -r walks a tree bottom-up, -f keeps quiet about misses --
   (rm-main as)
    (: (fl a r f) (? (! (two? a)) (L r f a)
                     (= (cap a) "-r") (fl (cup a) 1 f)
                     (= (cap a) "-f") (fl (cup a) r 1)
                     (|| (= (cap a) "-rf") (= (cap a) "-fr")) (fl (cup a) 1 1)
                     (L r f a))
       p (fl as 0 0)
       r? (cap p) f? (caup p) fs (caup (cup p))
       (zap q)
        (? (udirp q)
           (: (go m ok) (? (! (two? m)) ok
                           (: k (zap (+ q (+ "/" (cap m))))
                              (go (cup m) (? k ok 0))))
              ok (go (readdir q) 1)
              e (rmdir q)
              (&& ok (! e)))
           (! (unlink q)))
       (one q ok)
        (: hit (? r? (zap q) (! (unlink q)))
           (? hit ok
              f? ok
              (: _ (say err (+ "rm: cannot remove " q)) _ (put err 10) 0)))
       (go a ok) (? (two? a) (go (cup a) (one (cap a) ok)) (quit (? ok 0 1)))
       (? (two? fs) (go fs 1)
          f? (quit 0)
          (udie 2 "usage: rm [-r] [-f] FILE..")))

   ; -- mkdir and rmdir: -p lays every prefix on the way down --
   (mkdir-main as)
    (: p? (&& (two? as) (= (cap as) "-p"))
       fs (? p? (cup as) as)
       (mkp q)                          ; a tolerant mkdir at every slash, then the whole
        (: n (tally q)
           (go k) (? (<= n k) (mkdir q 493)
                     (: _ (? (&& (< 0 k) (= (q k) 47)) (mkdir (snip q 0 k) 493) ())
                        (go (+ k 1))))
           (go 1))
       (one q ok)
        (? p? (: _ (mkp q)
                 (? (udirp q) ok
                    (: _ (say err (+ "mkdir: cannot create " q)) _ (put err 10) 0)))
           (: e (mkdir q 493)
              (? (! e) ok
                 (: _ (say err (+ "mkdir: cannot create " q)) _ (put err 10) 0))))
       (go a ok) (? (two? a) (go (cup a) (one (cap a) ok)) (quit (? ok 0 1)))
       (? (two? fs) (go fs 1) (udie 2 "usage: mkdir [-p] DIR..")))
   (rmdir-main as)
    (: (go a ok)
        (? (two? a)
           (: e (rmdir (cap a))
              (go (cup a)
                  (? (! e) ok (: _ (say err (+ "rmdir: cannot remove " (cap a))) _ (put err 10) 0))))
           (quit (? ok 0 1)))
       (? (two? as) (go as 1) (udie 2 "usage: rmdir DIR..")))

   ; -- ln: two names for one thing (-s the pointing kind) --
   (ln-main as)
    (: s? (&& (two? as) (= (cap as) "-s"))
       rest (? s? (cup as) as)
       _ (? (two? (cup rest)) () (udie 2 "usage: ln [-s] TARGET LINKNAME"))
       e (? s? (symlink (cap rest) (caup rest)) (hardlink (cap rest) (caup rest)))
       (? (! e) (quit 0) (udie 1 (+ "ln: cannot link " (caup rest)))))

   ; -- touch: be there, and be now --
   (touch-main as)
    (: (one q ok)
        (: _ (? (two? (stat q)) () (: p (open q "a") (? p (close p) ())))
           e (utime q ())
           (? (! e) ok (: _ (say err (+ "touch: cannot touch " q)) _ (put err 10) 0)))
       (go a ok) (? (two? a) (go (cup a) (one (cap a) ok)) (quit (? ok 0 1)))
       (? (two? as) (go as 1) (udie 2 "usage: touch FILE..")))

   ; -- chmod: the octal bits onto every named path --
   (chmod-main as)
    (? (! (two? (cup as))) (udie 2 "usage: chmod OCTAL FILE..")
       (: m (uoct (cap as))
          (go a ok)
           (? (two? a)
              (: e (chmod (cap a) m)
                 (go (cup a)
                     (? (! e) ok (: _ (say err (+ "chmod: cannot chmod " (cap a))) _ (put err 10) 0))))
              (quit (? ok 0 1)))
          (go (cup as) 1))))
