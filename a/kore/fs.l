; a/kore/fs.l -- the fs tools of kore: ls, cp, mv, rm, mkdir, rmdir, ln,
; touch, pwd, chmod. every tool a <name>-main dispatched by kore (a/kore/kore.l),
; same as core.l -- a toolbox, no seat, kore is its door. loads after core.l in the
; cat and rides its u-floor (udie, uread, ubase); the effects ride i/posix.c's
; posix_ lane (stat readdir unlink mkdir rename symlink hardlink rmdir
; chmod utime cwd), whose convention shapes every loop here: an effect op
; answers () ok or an errno nom, so !e is the success every loop below asks.
; a body-less top-level `:` leaking uoct (lawed in t/law/kore.l) and the mains.
(module 'kore
(borrow 'cli)
(borrow 'posix)

(:
   ; octal text -> a charm ("755" is 493), chmod's one argument shape
   (uoct s) (:- (go 0 0) n #s (go i acc)
    (i >= n ? acc (go (i + 1) ((* 8 acc) + (s i - 48))))
       )
   ; a file destination: into a directory the source's basename lands beside
   (udest src dst) (? (udirp dst) (dst + "/" + ubase src "") dst)
   ; copy bytes + permission bits (cp's heart; mv's cross-device leg)
   ; the bytes, by whichever door this love has. kore runs in two worlds and they do not
   ; carry the same nifs: the Makefile bakes this whole cat verbatim (korecat), and a seat
   ; without `copyfile` takes the slurp, the freestanding leg. asked at the call, never bound at the top: the kernel's image is
   ; baked by a host love, so a load-time answer would freeze this world's nif set into
   ; that one's.
   (ucopy-bytes src dst)
    (? (lit? (cite 'posix 'copyfile))
       (charm? (copyfile src dst))
       (: r (uread src)
          (? (two? r) (: q (open dst "w")
                         (? (hot? q) (: _ (say q <>r) _ (close q) 1) 0))
             0)))
   ; the stat leads so the two failures stay tellable apart: one errno covers either end,
   ; and `cp: cannot open X` vs `cannot create Y` is the whole diagnostic. it is the same
   ; stat the mode comes from, so it costs nothing it did not already spend.
   (ucopy who src dst)
    (: st (stat src)
       _ (? (two? st) () (udie 1 (who + ": cannot open " + src)))
       _ (? (ucopy-bytes src dst) () (udie 1 (who + ": cannot create " + dst)))
       _ (chmod dst (& 4095 <>>st))
       1)

   ; -- pwd: where we stand --
   (pwd-main _) (: _ (say out (cwd ())) _ (put out 10) _ (flush out) 0)

   ; -- sync: the writeback, scheduled. sync(2) answers nothing and cannot fail.
   ; GNU's takes FILEs and fsyncs each; this one is the bare call only, since the
   ; per-file lane wants an fsync nif and there is none -- taking the operands and
   ; syncing everything instead would be a different thing wearing the same name.
   (sync-main as)
    (: _ (? (two? as) (udie 1 "sync: takes no operands here (no fsync nif)") ())
       _ (? (lit? (cite 'posix 'sync)) (sync 0) ())
       0)

   ; -- mkfifo and mknod: the two rows a /dev wants ------------------------------
   ; mode carries the TYPE bits as well as the permissions, which is mknod(2)'s own
   ; shape: S_IFIFO 4096, S_IFCHR 8192, S_IFBLK 24576.
   ; linux packs a device number wide -- major in bits 8..19 and 44.., minor in 0..7
   ; and 20.. -- so the obvious (major << 8) | minor is right only while both are small.
   (umkdev maj mn)
    (((& maj 4095) << 8) | (& mn 255) | ((maj >> 12) << 44) | ((mn >> 8) << 20))
   ; the seat may carry no mknod (inle, wasm), so the row is probed -- and probed in the
   ; MODULE, which is where posix's names live: the book holds none of them.
   (umknod who p md dev)
    (? (lit? (cite 'posix 'mknod)) (mknod p md dev) 'enosys)
   (mkfifo-main as)
    (: t (tablet 0)
       o (uopt as t '(109) '(101) ())
       _ (? (two? o) () (udie 1 "mkfifo: -m wants a mode"))
       _ (: c (uoptun t "m") (? (nil? c) () (udie 1 ("mkfifo: unknown option -" + string c))))
       v (uoptv t 109)
       md (? (string? v) (uoct v) 438)          ; 0666, the mode mkfifo(1) defaults to
       fs <>>o
       _ (: w (uoptstray as fs) (? (nil? w) () (udie 1 ("mkfifo: unknown option " + w))))
       _ (? (two? fs) () (udie 1 "usage: mkfifo [-m MODE] NAME.."))
       (go l ok) (? !(two? l) ok
                    (: e (umknod "mkfifo" <l (md | 4096) 0)
                       _ (? e (: _ (say err ("mkfifo: cannot create " + <l + ": " + (show e)))
                                 (put err 10))
                            ())
                       (go >l (? e 0 ok))))
       ok (go fs 1)
       _ (flush err) (? ok 0 1))
   (mknod-main as)
    (: t (tablet 0)
       o (uopt as t '(109) '(101) ())
       _ (? (two? o) () (udie 1 "mknod: -m wants a mode"))
       _ (: c (uoptun t "m") (? (nil? c) () (udie 1 ("mknod: unknown option -" + string c))))
       v (uoptv t 109)
       md (? (string? v) (uoct v) 438)
       fs <>>o
       n #fs
       _ (? (2 <= n) () (udie 1 "usage: mknod [-m MODE] NAME TYPE [MAJOR MINOR]"))
       nm <fs ty <>fs
       kind (? (ty = "p") 4096 (ty = "c") 8192 (ty = "u") 8192 (ty = "b") 24576
               (udie 1 ("mknod: unknown type " + ty + " (want p, b, c or u)")))
       _ (? ((kind = 4096) || (4 <= n)) ()
            (udie 1 "mknod: a block or character node wants MAJOR and MINOR"))
       dev (? (kind = 4096) 0 (umkdev (uatoi (fs 2)) (uatoi (fs 3))))
       e (umknod "mknod" nm (md | kind) dev)
       (? e (udie 1 ("mknod: cannot create " + nm + ": " + (show e))) 0))

   ; -- ls: a directory's entries, sorted, dotfiles held back (-a shows them);
   ; a file argument answers its own name --
   ;   -a all   -A all but . and ..   -l long   -d the directory itself
   ;   -r reverse   -t newest first
   ;   -1 one per line, which is what this ls always does: GNU writes one name a line
   ;      whenever stdout is not a terminal, and columns are still absent here
   ; several operands print GNU's `name:` headers, files before directories.
   ; THE LONG ROW'S CLOCK IS UTC. this tree carries no timezone database (see
   ; date's own note), so `ls -l` reads local time only where local time is UTC, and
   ; the gate that compares it to GNU sets TZ for that reason.
   ; colour is automatic and goes only onto a terminal -- (tty 1) answers a pair for
   ; one and 'enotty for anything else, so a pipe keeps the plain name and `ls | grep`
   ; reads what it always read. there is no --color to ask for it or refuse it.
   ; absent and said so: -C/-x columns, -R, -S, -h, -i and -F.
   uls-opts "aAldrt1"
   ; GNU shows the clock for the last six months and the year outside them. six
   ; months is 31556952/2 -- the average Gregorian year halved, coreutils' own
   ; constant, not 180 days.
   (uls-when s now)
    (: ymd (ucivil (// s 86400)) secs (% s 86400)
       mo (udt-mo (<>ymd - 1))
       d (upad 2 (show <>>ymd))
       (? (((now - 15778476) <= s) && (s <= now))
          (mo + " " + d + " " + (uzpad 2 (show (// secs 3600)))
              + ":" + (uzpad 2 (show (// (% secs 3600) 60))))
          (mo + " " + d + "  " + (show <ymd))))
   ; the sgr a name wears, "" for none. the class is read off the lstat already in
   ; hand; a broken link is the one class that costs a second call, since only the
   ; stat behind the link can miss.
   (uls-hue p md)
    (: k (& md 61440)
       (? (k = 16384) "\e[1;34m"
          (k = 40960) (? (two? (stat p)) "\e[36m" "\e[31m")
          (& md 73)   "\e[32m"
          ""))
   (uls-tint s h) (? #h (h + (s + "\e[0m")) s)
   (uls-name e tty?) (uls-tint <e (? tty? (uls-hue (e 2) (<>e 2)) ""))
   ; a name as the long row shows it -- a link wears its target, which is why every
   ; stat here is an lstat: ls -l describes the link and not what it points at. the
   ; colour dresses the name alone: the target after the arrow keeps its own text.
   (uls-nom p nm md h)
    (: n (uls-tint nm h)
       (? (40960 = (& md 61440))
          (: t (readlink p) (? (string? t) (n + " -> " + t) n))
          n))
   (uls-row p nm st now tty?)           ; the six columns, as strings
    [(ust-perm (st 2))
     (? (charm? (ust-at st 6)) (show (st 6)) "?")
     (? (charm? (ust-at st 4)) (uidname "/etc/passwd" (st 4)) "?")
     (? (charm? (ust-at st 5)) (uidname "/etc/group" (st 5)) "?")
     (show <st)
     (uls-when (// (st 3) 1000000000) now)
     (uls-nom p nm (st 2) (? tty? (uls-hue p (st 2)) ""))]
   (uls-wide rs k) (foldl (\ w r (: n #(r k) (? (w < n) n w))) 0 rs)
   ; the widths come from `ws` and not from `rs`. GNU sizes the command-line block's
   ; columns over EVERY operand, directories included -- even though a directory
   ; operand is listed further down as a block of its own and its row is never
   ; printed here. `ls -l file dir` pads file's size to the width of dir's, and a
   ; block sizing itself off its own rows silently loses that space.
   (uls-emit rs ws0)                    ; the rows, columns aligned the way GNU aligns
    (: wl (uls-wide ws0 1) wu (uls-wide ws0 2) wg (uls-wide ws0 3) ws (uls-wide ws0 4)
       (go l) (? !(two? l) ()
                 (: r <l
                    _ (say out (<r + " " + (upad wl (r 1)) + " " + (urpad wu (r 2))
                                   + " " + (urpad wg (r 3)) + " " + (upad ws (r 4))
                                   + " " + (r 5) + " " + (r 6)))
                    _ (put out 10)
                    (go >l)))
       (go rs))
   ; the order: by name, or by mtime newest-first under -t with the name breaking a
   ; tie. -r turns whichever of those around, which is why it is applied last and not
   ; folded into the comparison.
   (uls-sort es t? r?)
    (: le (? t? (\ x y (: a (<>x 3) b (<>y 3) (? (= a b) (<x <= <y) (b < a))))
              (\ x y (<x <= <y)))
       s (sortby le es)
       (? r? (rev s) s))
   ; one entry: [name lstat] | () when it cannot be stat'd
   (uls-ent dir nm)
    (: p (? #dir (dir + "/" + nm) nm)
       st (lstat p)
       (? (two? st) [nm st p] ()))
   (ls-main as)
    (: t (tablet 0)
       o (uopt as t '() '(101) ())
       _ (? (two? o) () (udie 2 "ls: an option wants a value"))
       ops <>>o
       _ (: k (uoptun t uls-opts) (? (nil? k) () (udie 2 ("ls: unknown option -- " + (string k)))))
       a? (peep t 97 0) aa? (peep t 65 0) l? (peep t 108 0) d? (peep t 100 0)
       r? (peep t 114 0) tm? (peep t 116 0)
       now (// (clock 0) 1000)
       tty? (two? (tty 1))                  ; colour only onto a terminal
       fs (? (two? ops) ops '("."))
       hdr? (two? >fs)
       (rows es) (map (\ e (uls-row (e 2) <e <>e now tty?)) es)
       (show1 es ws0)                    ; a run of entries, long or bare
        (? l? (uls-emit (rows es) ws0)
           (: (go l) (? !(two? l) ()
                        (: e <l _ (say out (uls-name e tty?)) _ (put out 10) (go >l)))
              (go es)))
       ; a directory's own listing: the entries, with `total` ahead of a long one.
       ; an EMPTY directory still owes its header and its `total 0`, so nothing here
       ; returns early on the empty readdir.
       (dirlist p first ok)
        ; readdir does NOT hand back . and .. -- it answers the names a walk wants.
        ; `ls -a` owes both, so they are put back here rather than taught to readdir,
        ; where every other caller would then have to take them out again.
        (: ns (readdir p)
           keep (? a? ("." . (".." . ns))
                   aa? ns
                   (filter (\ n !(n 0 = 46)) ns))
           es (filter two? (map (\ n (uls-ent p n)) keep))
           srt (uls-sort es tm? r?)
           rs (? l? (rows srt) ())
           _ (? hdr? (: _ (? first () (put out 10))
                        _ (say out (p + ":")) (put out 10)) ())
           _ (? l? (: blk (foldl (\ a e (: b (ust-at <>e 7) (? (charm? b) (a + b) a))) 0 es)
                      _ (say out ("total " + (show (// blk 2)))) (put out 10)) ())
           _ (show1 srt rs)
           ok)
       ; the operands, GNU's way round: the non-directories first as one listing,
       ; then a listing per directory. -d makes every operand a non-directory.
       (miss p) (: _ (say err ("ls: cannot access " + p)) _ (put err 10) 0)
       bad (filter (\ p !(two? (lstat p))) fs)
       good (filter (\ p (two? (lstat p))) fs)
       _ (map miss bad)
       plain (? d? good (filter (\ p !(udirp p)) good))
       dirs (? d? () (filter udirp good))
       pes (filter two? (map (\ p (uls-ent "" p)) plain))
       aes (filter two? (map (\ p (uls-ent "" p)) good))
       _ (? (two? pes) (show1 (uls-sort pes tm? r?) (rows aes)) ())
       ; the directory operands go in name order (-r turns them around); -t orders
       ; what is INSIDE a directory and is not claimed over the operands themselves.
       dps (: s (sort dirs) (? r? (rev s) s))
       (walk l first ok) (? !(two? l) ok (walk >l 0 (dirlist <l first ok)))
       ok (walk dps !(two? pes) (? (two? bad) 0 1))
       ; GNU's ls answers 2 for "cannot access", not 1: 1 is a minor trouble
       ; (an unreadable subdirectory under -R) and 2 is "the operand is not there",
       ; which is the status a script's `ls x || ...` is reading.
       _ (flush out) (? ok 0 2))

   ; -- cp and mv: a directory destination pulls the basename in beside --
   ; -f is taken and ignored, and that is not a silent lie: -f means "do not prompt",
   ; and nothing here ever prompts, so forced is the behaviour. -p is the other kind --
   ; it changes what lands, so it is honoured. (ucopy already carries the mode; the
   ; mtime is the half that was missing.) a recipe saying `mv -f` fails without this.
   (cpf-split as)                              ; -> (p? rest) off a leading -f/-p cluster
    (: (fl a p) (? !(two? a) [p a]
                    (elem <a '("-f" "-p" "-fp" "-pf"))
                     (fl >a (? (elem <a '("-p" "-fp" "-pf")) 1 p))
                    [p a])
       (fl as 0))
   (cp-main as)
    (: q (cpf-split as) p? <q rest <>q
       (? !(two? >rest) (udie 2 "usage: cp [-f] [-p] SRC DST")
          (: src <rest dst (udest src <>rest)
             _ (ucopy "cp" src dst)
             s (? p? (stat src) ())
             _ (? (two? s) (utime dst <>s) 0)
             0)))
   (mv-main as)
    (: rest (<>(cpf-split as))
       (? !(two? >rest) (udie 2 "usage: mv [-f] SRC DST")
          (: src <rest dst (udest src <>rest)
             e (rename src dst)
             (? !e 0
                (= e 'exdev) (: _ (ucopy "mv" src dst) _ (unlink src) 0)  ; the long way
                (udie 1 ("mv: cannot move " + src))))))

   ; -- rm: unlink, -r walks a tree bottom-up, -f keeps quiet about misses --
   (rm-main as)
    (: (fl a r f) (? !(two? a) [r f a]
                     (<a = "-r") (fl >a 1 f)
                     (<a = "-f") (fl >a r 1)
                     ((<a = "-rf") || (<a = "-fr")) (fl >a 1 1)
                     [r f a])
       p (fl as 0 0)
       r? <p f? <>p fs <>>p
       (zap q)
        (? (udirp q)
           (: (go m ok) (? !(two? m) ok
                           (: k (zap (q + "/" + <m))
                              (go >m (? k ok 0))))
              ok (go (readdir q) 1)
              e (rmdir q)
              (ok && !e))
           !(unlink q))
       (one q ok)
        (: hit (? r? (zap q) !(unlink q))
           (? hit ok
              f? ok
              (: _ (say err ("rm: cannot remove " + q)) _ (put err 10) 0)))
       (go a ok) (? (two? a) (go >a (one <a ok)) (? ok 0 1))
       (? (two? fs) (go fs 1)
          f? 0
          (udie 2 "usage: rm [-r] [-f] FILE..")))

   ; -- mkdir and rmdir: -p lays every prefix on the way down --
   (mkdir-main as)
    (: t (tablet 0)
       o (uopt as t () '(101) ())
       _ (: c (uoptun t "p") (? (nil? c) () (udie 2 ("mkdir: unknown option -" + string c))))
       p? (peep t 112 0)
       fs <>>o
       _ (: w (uoptstray as fs) (? (nil? w) () (udie 2 ("mkdir: unknown option " + w))))
       (mkp q)                          ; a tolerant mkdir at every slash, then the whole
        (: n (tally q)
           (go k) (? (n <= k) (mkdir q 493)
                     (: _ (? ((0 < k) && (q k = 47)) (mkdir (snip q 0 k) 493) ())
                        (go (k + 1))))
           (go 1))
       (one q ok)
        (? p? (: _ (mkp q)
                 (? (udirp q) ok
                    (: _ (say err ("mkdir: cannot create " + q)) _ (put err 10) 0)))
           (: e (mkdir q 493)
              (? !e ok
                 (: _ (say err ("mkdir: cannot create " + q)) _ (put err 10) 0))))
       (go a ok) (? (two? a) (go >a (one <a ok)) (? ok 0 1))
       (? (two? fs) (go fs 1) (udie 2 "usage: mkdir [-p] DIR..")))
   (rmdir-main as)
    (: (go a ok)
        (? (two? a)
           (: e (rmdir <a)
              (go >a
                  (? !e ok (: _ (say err ("rmdir: cannot remove " + <a)) _ (put err 10) 0))))
           (? ok 0 1))
       (? (two? as) (go as 1) (udie 2 "usage: rmdir DIR..")))

   ; -- ln: two names for one thing (-s the pointing kind, -f moves the old name aside) --
   (ln-main as)
    (: (fl a s f rest) (? !(two? a) [s f rest]
                          (<a = "-s") (fl >a 1 f rest)
                          (<a = "-f") (fl >a s 1 rest)
                          ((<a = "-sf") || (<a = "-fs")) (fl >a 1 1 rest)
                          [s f (rest + a)])
       p (fl as 0 0 ())
       s? <p f? <>p rest <>>p
       _ (? (two? >rest) () (udie 2 "usage: ln [-s] [-f] TARGET LINKNAME"))
       _ (? f? (unlink <>rest) ())
       e (? s? (symlink <rest <>rest) (hardlink <rest <>rest))
       (? !e 0 (udie 1 ("ln: cannot link " + <>rest))))

   ; -- touch: be there, and be now --
   (touch-main as)
    (: t (tablet 0)
       o (uopt as t () '(101) ())
       ; touch reads no options: "" names an empty alphabet, so every letter the walk
       ; pinned is unknown. the file really called -h is `touch -- -h`
       _ (: c (uoptun t "") (? (nil? c) () (udie 2 ("touch: unknown option -" + string c))))
       fs <>>o
       _ (: w (uoptstray as fs) (? (nil? w) () (udie 2 ("touch: unknown option " + w))))
       (one q ok)
        (: _ (? (two? (stat q)) () (: p (open q "a") (? (hot? p) (close p) ())))
           e (utime q ())
           (? !e ok (: _ (say err ("touch: cannot touch " + q)) _ (put err 10) 0)))
       (go a ok) (? (two? a) (go >a (one <a ok)) (? ok 0 1))
       (? (two? fs) (go fs 1) (udie 2 "usage: touch FILE..")))

   ; -- chmod: the octal bits onto every named path --
   (chmod-main as)
    (? !(two? >as) (udie 2 "usage: chmod OCTAL FILE..")
       (: m (uoct <as)
          (go a ok)
           (? (two? a)
              (: e (chmod <a m)
                 (go >a
                     (? !e ok (: _ (say err ("chmod: cannot chmod " + <a)) _ (put err 10) 0))))
              (? ok 0 1))
          (go >as 1)))

   ; -- install: copy with the mode set in the same breath (what the build's
   ; place-a-file steps say). -d makes directories (with parents, like -p);
   ; -D lays the destination's parents first; -m octal sets the mode (else 755);
   ; -s (strip) is accepted and noted -- no stripper rides kore yet, so the copy
   ; keeps its symbol table (a fatter install, never a wrong one) --
   (imkp q)                        ; a tolerant mkdir at every slash (parents only)
    (: n (tally q)
       (go k) (? (k < n) (: _ (? ((0 < k) && (q k = 47)) (mkdir (snip q 0 k) 493) ())
                            (go (k + 1)))
                 ())
       (go 1))
   (install-main as)
    (: (fl a d D m s fs) (? !(two? a) [d D m s fs]
                            (<a = "-d") (fl >a 1 D m s fs)
                            (<a = "-D") (fl >a d 1 m s fs)
                            ((<a = "-m") && two? >a) (fl >>a d D (uoct <>a) s fs)
                            (<a = "-s") (fl >a d D m 1 fs)
                            (fl >a d D m s (fs + [<a])))
       p (fl as 0 0 493 0 ())
       d? <p D? <>p m <>>p s? <>>>p fs <>>>>p
       _ (? s? (: _ (say err "install: -s noted, not stripped (no kore stripper yet)") (put err 10)) ())
       (? d? (: (go a ok)
                 (? (two? a)
                    (: _ (imkp <a) e (mkdir <a m)
                       ok2 (? (udirp <a) (: _ (? !e (chmod <a m) ()) ok)
                              (: _ (say err ("install: cannot create " + <a)) _ (put err 10) 0))
                       (go >a ok2))
                    (? ok 0 1))
                 (? (two? fs) (go fs 1) (udie 2 "usage: install -d DIR..")))
          !(two? >fs) (udie 2 "usage: install [-D] [-m OCTAL] [-s] SRC DST")
          (: src <fs dst (udest <fs <>fs)
             _ (? D? (imkp dst) ())
             _ (ucopy "install" src dst)
             _ (chmod dst m)
             0)))

   ; -- readlink: what a symbolic link says (-f chases to an absolute, clean path) --
   (rl-abs q) (? ((0 < tally q) && (q 0 = 47)) q (cwd () + "/" + q))
   (rl-clean q)                    ; lexically: no // . .. (.. pops a segment)
    (: n (tally q)
       (seg i st acc) (? (i < n)
                         (? (q i = 47)
                            (seg (i + 1) (i + 1) (? (st < i) (snip q st i . acc) acc))
                            (seg (i + 1) st acc))
                         (rev (? (st < i) (snip q st i . acc) acc)))
       (fold l acc) (? !(two? l) (rev acc)
                       (<l = ".") (fold >l acc)
                       (<l = "..") (fold >l (? (two? acc) >acc acc))
                       (fold >l (<l . acc)))
       ("/" + ujoinc 47 (fold (seg 0 0 ()) ())))
   (rl-chase q n)                  ; follow link upon link (n bounds a cycle)
    (: t (readlink q)
       (? !(two? (stat q)) ()
          !(string? t) q
          (0 = n) ()
          (rl-chase (? (t 0 = 47) t (rl-clean (rl-abs q + "/../" + t))) (n - 1))))
   (readlink-main as)
    (: f? (two? as && (<as = "-f"))
       fs (? f? >as as)
       _ (? (two? fs) () (udie 2 "usage: readlink [-f] PATH"))
       q <fs
       r (? f? (: c (rl-chase (rl-clean (rl-abs q)) 40) (? (string? c) c ()))
            (: t (readlink q) (? (string? t) t ())))
       (? (string? r) (: _ (say out r) _ (put out 10) _ (flush out) 0) 1))

   ; -- realpath: a path with every symlink, every . and every .. taken out of it.
   ; the walk resolves component by component, so a last name that does not exist yet
   ; still answers -- GNU's default face. -e wants the whole path to be there, -m
   ; allows any of it to be missing, -s takes the links as they lie --
   (rp-parts p) (filter (\ w (0 < tally w)) (usplit 47 p))
   (rp-canon q n)                      ; the resolved path, or () past n links
    (: (walk acc parts d)
        (? !(two? parts) [1 acc]
           (0 = d) ()
           (: p <parts
              (? (p = ".") (walk acc >parts d)
                 (p = "..") (walk (rl-clean (acc + "/..")) >parts d)
                 (: cand (? (acc = "/") ("/" + p) (acc + "/" + p))
                    t (readlink cand)
                    (? !(string? t) (walk cand >parts d)
                       (walk (? (t 0 = 47) "/" acc) (rp-parts t + >parts) (d - 1)))))))
       (walk "/" (rp-parts (rl-abs q)) n))
   (realpath-main as)
    (: t (tablet 0)
       o (uopt as t () '(101) ())
       _ (: c (uoptun t "ems") (? (nil? c) () (udie 1 ("realpath: unknown option -" + string c))))
       fs <>>o
       _ (? (two? fs) () (udie 1 "usage: realpath [-e|-m|-s] PATH.."))
       e? (peep t 101 0) m? (peep t 109 0) s? (peep t 115 0)
       (one q ok)
        (: r (? s? [1 (rl-clean (rl-abs q))] (rp-canon q 40))
           (? !(two? r)
              (: _ (say err ("realpath: " + q + ": too many levels of symbolic links"))
                 _ (put err 10) 0)
              (: p <>r
                 want (? m? () (? e? p (udir p)))    ; what has to be there to answer
                 (? ((= want ()) || (two? (stat want)))
                    (: _ (say out p) _ (put out 10) ok)
                    (: _ (say err ("realpath: " + q + ": No such file or directory"))
                       _ (put err 10) 0)))))
       (go a ok) (? (two? a) (go >a (one <a ok)) (: _ (flush out) (? ok 0 1)))
       (go fs 1))

   ; -- link and unlink: the two syscalls said plainly, no face on them (ln and rm
   ; are where the faces live) --
   (link-main as)
    (? !(two? >as) (udie 1 "usage: link FILE NEW")
       (: e (hardlink <as <>as)
          (? !e 0 (udie 1 ("link: cannot link " + <>as + " to " + <as)))))
   (unlink-main as)
    (? !(two? as) (udie 1 "usage: unlink FILE")
       (: e (unlink <as)
          (? !e 0 (udie 1 ("unlink: cannot unlink " + <as)))))

   ; ---- the reporting tools: stat, du -- and chown, mktemp ---------------------
   ; these read the stat tail. i/posix.c's stat answers
   ; (size mtime mode ns uid gid nlink blocks ino), append-only, and the kernel's own
   ; stat (i/kmain.c) answers the first four alone -- an image tree has no ownership
   ; to tell about. so the tail is asked by tally and a world that does not carry it
   ; says so rather than reading a 0 someone might believe.
   (ust-at st k) (? (tally st <= k) () (st k))
   ; /etc/passwd and /etc/group, read as the files they are (no NSS, no getpwnam)
   (uidname path id)                   ; a numeric id -> its name, or the number back
    (: r (uread path)
       (one? r ? (show id)
        (: (go ls) (one? ls ? (show id)
                    (: f (usplit 58 <ls)
                       (3 <= #f && uatoi (f 2) = id ? (f 0) (go >ls))))
           (go (lines <>r)))))
   (uidof path nm)                     ; a name -> (1 id), or () when the file has none
    (: r (uread path) (two? r ?
     (:- (go (lines <>r)) (go ls) (two? ls ? 
      (: f (usplit 58 <ls)
       (3 <= #f && f 0 = nm ? [1 (uatoi (f 2))] (go >ls)))))))
   ; every group a user belongs to: the primary first, then the /etc/group rows naming
   ; them, ascending -- which is the order the kernel keeps its credential list in, and
   ; so the order `id` prints
   (ugroups nm gid)
    (: r (uread "/etc/group")
       (go ls acc)
        (? !(two? ls) acc
           (: f (usplit 58 <ls)
              g (? (4 <= tally f) (uatoi (f 2)) -1)
              ms (? (4 <= tally f) (usplit 44 (f 3)) ())
              (go >ls (? ((elem nm ms) && !(g = gid)) (g . acc) acc))))
       rest (? (two? r) (sort (go (lines <>r) ())) ())
       (gid . rest))

   ; -- stat: the file's own facts, by -c format. %n %N %s %b %B %f %a %A %F %u %U %g %G
   ; %h %i %Y %y, the \n \t \\ escapes, and %% . -L follows a symbolic link; the bare
   ; face does not. there is no default block. GNU's is four lines of access, change
   ; and birth times and a device number, and this stat carries none of them -- printing
   ; a block with the modify time standing in three times over would be a fabrication,
   ; so the tool asks for -c instead of inventing one.
   (ust-kindc m) (m & 61440 @
    32768 "-" 16384 "d" 40960 "l" 8192 "c"
    24576 "b" 4096 "p" 49152 "s"
    "?")
   (ust-kind m sz) (m & 61440 @
    32768 (sz ? "regular file" "regular empty file")
    16384 "directory"  40960 "symbolic link"
    8192 "character special file"
    24576 "block special file"
    4096 "fifo"  49152 "socket"
    "weird file")
   (ust-perm m)                        ; the ls face: drwxr-sr-t, the three set bits told
    (: (tri sh sb ch)
        (: b ((m // sh 2) % 8)
           x (0 < b & 1)
           s (0 < m & sb)
           (((0 < b & 4 ? "r" "-") + (0 < b & 2 ? "w" "-"))
            + (!s ? (x ? "x" "-") (x ? ch (string ((ch 0) - 32))))))
       ((ust-kindc m) + ((tri 6 2048 "s") + ((tri 3 1024 "s") + (tri 0 512 "t")))))
   (ustamp ns)                         ; %y: 2026-08-17 13:32:41.073610912 +0000
    (: s (// ns 1000000000) frac (% ns 1000000000)
       ymd (ucivil (// s 86400)) secs (% s 86400)
       (p2 v) (uzpad 2 (show v))
       ((((show <ymd) + "-" + (p2 <>ymd) + "-" + (p2 <>>ymd)) + " ")
        + (((p2 (// secs 3600)) + ":" + (p2 (// (% secs 3600) 60)) + ":" + (p2 (% secs 60)))
           + ("." + (uzpad 9 (show frac)) + " +0000"))))
   ; -c does not read escapes -- `stat -c 'a\tb'` prints the backslash and the t, and
   ; adds a newline of its own; --printf reads them and adds none. GNU's split, and the
   ; only way a format can carry a literal backslash at all.
   (ust-expand fmt p st esc?)
    (:- (go 0)
     n #fmt o (jug 0)
     sz <st md <>>st ns (st 3)
     uid (ust-at st 4) gid (ust-at st 5) nlk (ust-at st 6)
     blk (ust-at st 7) ino (ust-at st 8)
     (num v) (? (charm? v) (show v) "?")
     (go k) (n <= k ? (slurp o) (: c (fmt k) (?- (go (k + 2))
      (esc? && c = 92 && k + 1 < n)
       (: d (fmt (k + 1))
        (d @ 110 (put o 10) 116 (put o 9) 92 (put o 92) (put o 92, put o d), go (k + 2)))
       (c != 37 || k + 1 >= n) (put o c, go (k + 1))
       (fmt (k + 1) @
        37 (put o 37)
        110 (say o p)
        78 (say o ("'" + p + "'"))
        115 (say o (show sz))
        98 (say o (num blk))
        66 (say o "512")
        102 (say o (uradix md 16))
        97 (say o (uradix (& md 4095) 8))
        65 (say o (ust-perm md))
        70 (say o (ust-kind md sz))
        117 (say o (num uid))
        85 (say o (charm? uid ? (uidname "/etc/passwd" uid) "?"))
        103 (say o (num gid))
        71 (say o (charm? gid ? (uidname "/etc/group" gid) "?"))
        104 (say o (num nlk))
        105 (say o (num ino))
        89 (say o (show (ns // 1000000000)))
        121 (say o (ustamp ns))
        d (put o 37, put o d))))))
   (stat-main as)
    (: (long? w n s) ((n < tally w) && (snip w 0 n = s))
       (fl a fmt L pf fs)
        (? (one? a) [fmt L pf (rev fs)]
           (<a = "-L") (fl >a fmt 1 pf fs)
           (<a = "-c") (? (two? >a) (fl >>a <>a L 0 fs) (udie 2 "stat: -c wants a format"))
           (2 < #<a && snip <a 0 2 = "-c") (fl >a (snip <a 2 #<a) L 0 fs)
           (long? <a 9 "--format=") (fl >a (snip <a 9 #<a) L 0 fs)
           (long? <a 9 "--printf=") (fl >a (snip <a 9 #<a) L 1 fs)
           (fl >a fmt L pf (<a . fs)))
       p (fl as () 0 0 ())
       fmt <p L? <>p pf? <>>p fs (p 3)
       _ (? ((string? fmt) && two? fs) ()
            (udie 2 "usage: stat [-L] -c FORMAT | --printf=FORMAT   FILE.."))
       (one q ok)
        (: st (? L? (stat q) (lstat q))
           (? (one? st)
              (say err ("stat: cannot stat '" + q + "': No such file or directory\n"), 0)
              (say out (ust-expand fmt q st pf?), pf? || put out 10, ok)))
       (go a ok) (two? a ? (go >a (one <a ok)) (flush out, !ok))
       (go fs 1))

   ; -- du: what a tree costs on the disk. the count is st_blocks (512 each), which is
   ; allocation and not size -- a sparse file costs less than it measures and a tiny one
   ; costs a whole block -- and the report is in 1K units, rounded up, unless -b asks for
   ; apparent bytes or -h for the three-figure human face. -a counts files too, -s only
   ; the totals, -c a grand total, -d N stops descending. a hard link is counted once
   ; per run, keyed by inode alone: this stat carries no device, so a walk crossing two
   ; filesystems could collide two inodes -- rare, and named here rather than hidden.
   ; the walk sorts each directory, like find's, so the same tree reports twice alike.
   (uhuman n)                          ; GNU's -h: three significant figures, rounded up
    (: units '("K" "M" "G" "T" "P")
       (pick k) (? (4 < k || n < (10 * (k + 1)) 2) k (pick (k + 1)))
       k (n < 1024 ? 0 (pick 1))
       d ((10 * k) 2)
       (k @ 0 (show n)
          (: tenths ((n * 10 + d - 1) // d)
             whole ((n + d - 1) // d)
             u (units (k - 1))
           (tenths < 100 ? (show (tenths // 10) + "." + show (tenths % 10) + u) (show whole + u)))))
   (du-main as)
    (: (fl a t fs) (? (one? a) [t (rev fs)]
        (<a = "-d") (two? >a ? (pin t 'd (uatoi <>a), fl >>a t fs)
                     (udie 2 "du: -d wants a depth"))
        (#<a < 2 || <a 0 != 45) (fl >a t (<a . fs))
        (:- (cl 1) w <a (cl k) (#w <= k ? (fl >a t fs) (w k @
         97 (pin t 'a 1, cl (k + 1))
         115 (pin t 's 1, cl (k + 1))
         99 (pin t 'c 1, cl (k + 1))
         98 (pin t 'b 1, cl (k + 1))
         104 (pin t 'h 1, cl (k + 1))
         107 (cl (k + 1))       ; -k is the default
         100 (pin t 'd (uatoi (snip w (k + 1) #w)), fl >a t fs)
         c (udie 2 $ "du: unknown option -" + string c)))))
       t {}
       p (fl as t ())
       fs (? (two? <>p) <>p '("."))
       a? (t 'a) s? (t 's) c? (t 'c)
       b? (t 'b) h? (t 'h) maxd (t 'd)
       seen (tablet 0)
       (fmt n) (? h? (uhuman n) (b? ? (show n) (show $ (n + 1023) // 1024)))
       (emit n q) (say out (fmt n), put out 9, say out q, put out 10)
       ; -b's apparent size counts a file's st_size and a directory's not at all --
       ; GNU's rule, and not a guess: an empty directory whose st_size is 40 reports 0.
       (own st dir?)
        (: nlk (ust-at st 6) ino (ust-at st 8)
           ct (? b? (? dir? 0 <st) (* 512 (? (charm? (ust-at st 7)) (ust-at st 7) 0)))
           (? ((charm? nlk) && (1 < nlk))
              (? (peep seen ino 0) 0 (pin seen ino 1, ct))
              ct))
       (walk q depth top?)
        (: st (lstat q)
           (one? st ?  (say err ("du: cannot access '" + q + "'\n"), pin t 'bad 1, 0)
            (: dir? (16384 = (& 61440 <>>st))
               kids (?- 0 dir?
                     (foldl (acc \ c \ acc + walk (q + "/" + c) (depth + 1) 0) 0 (sort (readdir q))))
               tot (own st dir? + kids)
               deep? (charm? maxd && maxd < depth)
               _ ((dir? || a? || top?) && !s? && !deep? && emit tot q)
               tot)))
       (go a acc) (one? a ? acc (walk <a 0 1 @ n (s? && emit n <a, go >a (acc + n))))
       total (go fs 0)
       (c? && emit total "total",
        flush out,
        !!(peep t 'bad 0)))

   ; -- chown: owner[:group] onto every named path, -R down the tree. a name is looked
   ; up in /etc/passwd / /etc/group, a numeral is taken as itself, and an empty side is
   ; -1, which the kernel reads as "leave this one alone" --
   (uowner spec)                       ; "u:g" / "u" / ":g" -> (uid gid), -1 for absent
    (: ps (usplit 58 spec)
       (side w path) (0 >= #w ? -1
                      (uidof path w @ r
                       (two? r ? <>r (w 0 @ c (48 <= c <= 57 ? (uatoi w)
                                      (udie 1 ("chown: invalid user: '" + spec + "'")))))))
       [(side <ps "/etc/passwd") (one? >ps ? -1 (side <>ps "/etc/group"))])
   (chown-main as)
    (: r? (two? as && <as = "-R")
       rest (r? ? >as as)
       _ (one? >rest && udie 2 "usage: chown [-R] OWNER[:GROUP] FILE..")
       ug (uowner <rest)
       uid <ug gid <>ug
       (one q ok)
        (: e (chown q uid gid)
           ok2 (!e ? ok (say err ("chown: cannot chown '" + q + "'\n"), 0))
           (r? && (udirp q) ?
            (foldl (acc \ c \ one (q + "/" + c) acc) ok2 (readdir q))
            ok2))
       (go a ok) (two? a ? (go >a (one <a ok)) !ok)
       (go >rest 1))

   ; -- mktemp: a name nobody else has, made and not merely proposed. the trailing run
   ; of X's in the template becomes random alphanumerics and the name is claimed with an
   ; exclusive create (openfd's mode 3) or an exclusive mkdir under -d, so the answer is
   ; a fact by the time it is printed. -u drops the file again (the unsafe face, and
   ; GNU calls it that too), -p DIR / -t put the name under a directory --
   umtchars "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
   (umtname tmpl)                      ; the X run filled with fresh charms
    (: n #tmpl
       (e k) (0 < k && tmpl (k - 1) = 88 ? (e (k - 1)) k)
       en (e n)
       o (jug 0)
       _ (say o (snip tmpl 0 en))
       (go k) (n > k ? (put o (umtchars (rand 62)), go (k + 1)))
       _ (go en)
       (slurp o))
   (mktemp-main as)
    (: (fl a d u q dir fs)
        (? (one? a) [d u q dir (rev fs)]
           (<a = "-d") (fl >a 1 u q dir fs)
           (<a = "-u") (fl >a d 1 q dir fs)
           (<a = "-q") (fl >a d u 1 dir fs)
           (<a = "-t") (fl >a d u q (? dir dir (getenv "TMPDIR")) fs)
           (<a = "-p") (? (two? >a) (fl >>a d u q <>a fs) (udie 1 "mktemp: -p wants a directory"))
           (2 < #<a && snip <a 0 2 = "-p") (fl >a d u q (snip <a 2 #<a) fs)
           ; anything else is the template -- unless it still looks like a flag, which
           ; would name a temporary file after the option someone meant
           (1 < #<a && <a 0 = 45) (udie 1 ("mktemp: unknown option " + <a))
           (fl >a d u q dir (<a . fs)))
       p (fl as 0 0 0 () ())
       d? <p u? <>p q? <>>p pdir (p 3) fs (p 4)
       tm (string? pdir ? pdir (: e (getenv "TMPDIR") (? (string? e) e "/tmp")))
       named (two? fs)
       tmpl (? named <fs "tmp.XXXXXXXXXX")
       base (named && !(string? pdir) ? tmpl ((0 < #tm ? tm ".") + "/" + tmpl))
       (try n)
        (? (n < 1) (? q? 1 (udie 1 "mktemp: could not make a name nobody had"))
           (: nm (umtname base)
              fd (? d? -1 (openfd nm 3))
              got (? d? !(mkdir nm 448) (charm? fd && 0 <= fd))
              _ (? (charm? fd && 0 <= fd) (close fd) ())
              (? !got (try (n - 1))
                 (? u? (? d? (rmdir nm) (unlink nm)) (),
                  say out nm, put out 10, flush out, 0))))
       (try 100))

   ; -- cmp: are two files the same bytes (-s says nothing, the exit code answers) --
   (cmp-main as)
    (: s? (two? as && (<as = "-s"))
       fs (? s? >as as)
       _ (one? >fs ? (udie 2 "usage: cmp [-s] A B"))
       ra (uread <fs) rb (uread <>fs)
       (? (one? ra || one? rb)
          (!s? ? (say err ("cmp: cannot read " + (two? ra ? <>fs <fs)), put err 10),
             2)
          (<>ra = <>rb) 0
          (: _ (? s? () (: _ (say out ((<fs + " ") + (<>fs + " differ")))
                           _ (put out 10) (flush out)))
             1))))
) ; module 'kore
