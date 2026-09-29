; apps/kore/fs.l -- the fs tools of kore: ls, cp, mv, rm, mkdir, rmdir, ln,
; touch, pwd, chmod, truncate. every tool a <name>-main dispatched by kore (apps/kore/kore.l),
; same as core.l -- a toolbox, no seat, kore is its door. loads after core.l in the
; cat and rides its u-floor (udie, uread, ubase); the effects ride love/posix.c's
; posix_ lane (stat readdir unlink mkdir rename symlink hardlink rmdir
; chmod utime cwd truncate), whose convention shapes every loop here: an effect op
; answers () ok or an errno nom, so !e is the success every loop below asks.
; a body-less top-level `:` leaking uoct (lawed in test/law/kore.l) and the mains.
(module 'kore
(borrow 'cli)
(borrow 'cal)
(borrow 'posix)
(borrow 'text)

(:
   ; octal text -> a charm ("755" is 493), chmod's one argument shape
   (uoct s) (:- (go 0 0) n #s (go i acc)
    (i >= n ? acc (go (i + 1) ((8 * acc) + (s i - 48))))
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
                         (? (hot? q) (say q <>r, close q, 1) 0))
             0)))
   ; the stat leads so the two failures stay tellable apart: one errno covers either end,
   ; and `cp: cannot open X` vs `cannot create Y` is the whole diagnostic. it is the same
   ; stat the mode comes from, so it costs nothing it did not already spend.
   ; ucopy1 says its complaint and answers 0, so a tool with many operands carries on;
   ; ucopy leaves with 1 instead
   (usay-err m) (say err m, put err 10, 0)
   (ucopy1 who src dst)
    (: st (stat src)
       (? (atom? st) (usay-err (who + ": cannot open " + src))
          !(ucopy-bytes src dst) (usay-err (who + ": cannot create " + dst))
          (chmod dst (4095 & <>>st), 1)))
   (ucopy who src dst) (? (ucopy1 who src dst) 1 (uleave 1))
   ; a path's own kind, a link not followed: 'dir, 'link or 'file, () when there is none
   (ukind q) (: st (lstat q) (? (atom? st) () (: m (61440 & <>>st) (? (m = 16384) 'dir (m = 40960) 'link 'file))))
   ; m said on stderr and a line read back: 1 for a y or Y first, else 0 (eof too)
   (uyes m) (: _ (say err m, flush err)
               (line acc) (: c (see in) (? (c < 0 || c = 10) (rev acc) (line (c . acc))))
               a (line ())
               (? (two? a && (<a = 121 || <a = 89)) 1 0))
   ; a mode word onto the mode cur: octal whole, or chmod's symbolic clauses, `who` of
   ; ugoa then +-= runs of rwxXst or one of ugo to copy (u+x,go-w,a=rX). no who is all
   ; three less the umask um. a directory keeps its setuid and setgid bits through = and
   ; octal, as GNU's does. () for a word that is neither
   (umode m cur dir? um)
    (: n #m
       (oct? i) (? (n <= i) 1 (48 <= m i <= 55) (oct? (i + 1)) 0)
       (base c) (? (c = 117) 64 (c = 103) 8 1)
       (over ws f) (foldl (\ a w (a | f w)) 0 ws)
       (perm ws cur c)
        (? (c = 114) (over ws (w \ 4 * base w))
           (c = 119) (over ws (w \ 2 * base w))
           (c = 120) (over ws base)
           (c = 88) (? (dir? || 0 < (cur & 73)) (over ws base) 0)
           (c = 115) ((? (elem 117 ws) 2048 0) | (? (elem 103 ws) 1024 0))
           (c = 116) (? (elem 111 ws) 512 0)
           (: v ((cur // base c) & 7) (over ws (w \ v * base w))))
       (class ws) ((over ws (w \ 7 * base w)) | (? dir? 0 (perm ws 0 115)) | perm ws 0 116)
       (who i ws) (? (i < n && elem (m i) "ugoa")
                     (who (i + 1) (m i = 97 ? (117 . 103 . 111 . ws) (m i . ws)))
                     [i ws])
       ; one clause's op runs from i to its comma or the end: [i cur], or () on a stranger
       (ops i ws mask cur)
        (? (n <= i || m i = 44) [i cur]
           !(elem (m i) "+-=") ()
           (: op (m i)
              (run j p) (? (j < n && elem (m j) "rwxXst") (run (j + 1) (p | perm ws cur (m j)))
                           (j < n && elem (m j) "ugo") [(j + 1) (p | perm ws cur (m j))]
                           [j p])
              r (run (i + 1) 0)
              b ((r 1) & mask)
              (ops (r 0) ws mask (? (op = 43) (cur | b) (op = 45) (cur - (cur & b)) ((cur - (cur & class ws)) | b)))))
       (clauses i cur)
        (: w (who i ())
           ws (? (two? (w 1)) (w 1) '(117 103 111))
           mask (? (two? (w 1)) 4095 (4095 - (4095 & um)))
           r (? (w 0 < n && elem (m (w 0)) "+-=") (ops (w 0) ws mask cur) ())
           (? !(two? r) ()
              (n <= r 0) (r 1)
              (clauses (r 0 + 1) (r 1))))
       (? (0 < n && n <= 4 && oct? 0) (uoct m | (? dir? (cur & 3072) 0)) (0 < n) (clauses 0 cur) ()))

   ; -- pwd: where we stand --
   (pwd-main _) (say out (cwd ()), put out 10, flush out, 0)

   ; -- sync: the writeback, scheduled. sync(2) answers nothing and cannot fail.
   ; GNU's takes FILEs and fsyncs each; this one is the bare call only, since the
   ; per-file lane wants an fsync nif and there is none -- taking the operands and
   ; syncing everything instead would be a different thing wearing the same name.
   (sync-main as)
    ((? (two? as) (udie 1 "sync: takes no operands here (no fsync nif)") ()), (? (lit? (cite 'posix 'sync)) (sync 0) ()), 0)

   ; -- mkfifo and mknod: the two rows a /dev wants ------------------------------
   ; mode carries the TYPE bits as well as the permissions, which is mknod(2)'s own
   ; shape: S_IFIFO 4096, S_IFCHR 8192, S_IFBLK 24576.
   ; linux packs a device number wide -- major in bits 8..19 and 44.., minor in 0..7
   ; and 20.. -- so the obvious (major << 8) | minor is right only while both are small.
   (umkdev maj mn)
    (((maj & 4095) << 8) | (mn & 255) | ((maj >> 12) << 44) | ((mn >> 8) << 20))
   ; the seat may carry no mknod (inle, wasm), so the row is probed -- and probed in the
   ; MODULE, which is where posix's names live: the book holds none of them.
   (umknod who p md dev)
    (? (lit? (cite 'posix 'mknod)) (mknod p md dev) 'enosys)
   (mkfifo-main as)
    (: t (tablet 0)
       o (uopt as t '(109) '(101) ())
       _ (? (two? o) () (udie 1 "mkfifo: -m wants a mode"))
       _ (: c (uoptun t "m") (? !c () (udie 1 ("mkfifo: unknown option -" + string c))))
       v (uoptv t 109)
       md (? (string? v) (uoct v) 438)          ; 0666, the mode mkfifo(1) defaults to
       fs <>>o
       _ (: w (uoptstray as fs) (? !w () (udie 1 ("mkfifo: unknown option " + w))))
       _ (? (two? fs) () (udie 1 "usage: mkfifo [-m MODE] NAME.."))
       (go l ok) (? (atom? l) ok
                    (: e (umknod "mkfifo" <l (md | 4096) 0)
                       _ (? e (say err ("mkfifo: cannot create " + <l + ": " + (show e)), put err 10)
                            ())
                       (go >l (? e 0 ok))))
       ok (go fs 1)
       _ (flush err) (? ok 0 1))
   (mknod-main as)
    (: t (tablet 0)
       o (uopt as t '(109) '(101) ())
       _ (? (two? o) () (udie 1 "mknod: -m wants a mode"))
       _ (: c (uoptun t "m") (? !c () (udie 1 ("mknod: unknown option -" + string c))))
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
   ;   -1 one per line   -C columns down   -x columns across
   ; the format with none of those spelled is the terminal's: columns onto one, a
   ; name a line into a pipe. GNU lets the LAST format flag win; uopt keeps presence
   ; and not order, so they rank instead -- -l, then -1, then -x, then -C.
   ; the screen and the grid on it are both grid's: $COLUMNS then the terminal, ragged
   ; columns, a pad that elides onto tab stops. all three are GNU's own and not an
   ; imitation of them, and test/kore/ls.sh is where the two are compared.
   ; several operands print GNU's `name:` headers, files before directories.
   ; THE LONG ROW'S CLOCK IS UTC. this tree carries no timezone database (see
   ; date's own note), so `ls -l` reads local time only where local time is UTC, and
   ; the gate that compares it to GNU sets TZ for that reason.
   ; colour is automatic and goes only onto a terminal -- (tty 1) answers a pair for
   ; one and 'enotty for anything else, so a pipe keeps the plain name and `ls | grep`
   ; reads what it always read. there is no --color to ask for it or refuse it.
   ; absent and said so: -R, -S, -h, -i and -F.
   uls-opts "aACldrtx1"
   ; GNU shows the clock for the last six months and the year outside them. six
   ; months is 31556952/2 -- the average Gregorian year halved, coreutils' own
   ; constant, not 180 days.
   (uls-when s now)
    (: ymd (civil (s // 86400)) secs (s % 86400)
       mo (mon3 (<>ymd - 1))
       d (upad 2 (show <>>ymd))
       (? (((now - 15778476) <= s) && (s <= now))
          (mo + " " + d + " " + (zpad 2 (show (secs // 3600)))
              + ":" + (zpad 2 (show ((secs % 3600) // 60))))
          (mo + " " + d + "  " + (show <ymd))))
   ; the sgr a name wears, "" for none. the class is read off the lstat already in
   ; hand; a broken link is the one class that costs a second call, since only the
   ; stat behind the link can miss.
   (uls-hue p md)
    (: k (md & 61440)
       (? (k = 16384) "\e[1;34m"
          (k = 40960) (? (two? (stat p)) "\e[36m" "\e[31m")
          (md & 73)   "\e[32m"
          ""))
   (uls-tint s h) (? #h (h + (s + "\e[0m")) s)
   (uls-name e tty?) (uls-tint <e (? tty? (uls-hue (e 2) (<>e 2)) ""))
   ; a name as the long row shows it -- a link wears its target, which is why every
   ; stat here is an lstat: ls -l describes the link and not what it points at. the
   ; colour dresses the name alone: the target after the arrow keeps its own text.
   (uls-nom p nm md h)
    (: n (uls-tint nm h)
       (? (40960 = (md & 61440))
          (: t (readlink p) (? (string? t) (n + " -> " + t) n))
          n))
   (uls-row p nm st now tty?)           ; the six columns, as strings
    [(ust-perm (st 2))
     (? (charm? (ust-at st 6)) (show (st 6)) "?")
     (? (charm? (ust-at st 4)) (uidname "/etc/passwd" (st 4)) "?")
     (? (charm? (ust-at st 5)) (uidname "/etc/group" (st 5)) "?")
     (show <st)
     (uls-when ((st 3) // 1000000000) now)
     (uls-nom p nm (st 2) (? tty? (uls-hue p (st 2)) ""))]
   ; the names as a grid. a cell's width is the NAME's and not the coloured text's:
   ; the sgr bytes ride along and take up no screen, and a wide character takes two.
   (uls-grid es tty? w down?)
    (: cs (map (\ e ((uls-name e tty?) . swidth <e)) es)
       (go l) (? (atom? l) () (say out <l, put out 10, go >l))
       (go ((cite 'grid 'lay) cs w down?)))
   (uls-wide rs k) (foldl (\ w r (: n #(r k) (? (w < n) n w))) 0 rs)
   ; the widths come from `ws` and not from `rs`. GNU sizes the command-line block's
   ; columns over EVERY operand, directories included -- even though a directory
   ; operand is listed further down as a block of its own and its row is never
   ; printed here. `ls -l file dir` pads file's size to the width of dir's, and a
   ; block sizing itself off its own rows silently loses that space.
   (uls-emit rs ws0)                    ; the rows, columns aligned the way GNU aligns
    (: wl (uls-wide ws0 1) wu (uls-wide ws0 2) wg (uls-wide ws0 3) ws (uls-wide ws0 4)
       (go l) (? (atom? l) ()
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
    (: le (? t? (\ x y (: a (<>x 3) b (<>y 3) (? (a = b) (<x <= <y) (b < a))))
              (\ x y (<x <= <y)))
       s (sortby le es)
       (? r? (rev s) s))
   ; one entry: [name lstat] | () when it cannot be stat'd
   (uls-ent dir nm)
    (: p (? #dir (dir + "/" + nm) nm)
       st (lstat p)
       (? (two? st) [nm st p] ()))
   (vdir-main as) (ls-main ("-l" . as))           ; coreutils' long one
   (ls-main as)
    (: t (tablet 0)
       o (uopt as t '() '(101) ())
       _ (? (two? o) () (udie 2 "ls: an option wants a value"))
       ops <>>o
       _ (: k (uoptun t uls-opts) (? !k () (udie 2 ("ls: unknown option -- " + (string k)))))
       a? (peep t 97 0) aa? (peep t 65 0) l? (peep t 108 0) d? (peep t 100 0)
       r? (peep t 114 0) tm? (peep t 116 0)
       c? (peep t 67 0) x? (peep t 120 0) o1? (peep t 49 0)
       now ((clock 0) // 1000)
       tty? (two? (tty 1))                  ; colour only onto a terminal
       w ((cite 'grid 'screen) 1)
       grid? (? l? 0 o1? 0 (x? || c? || tty?) 1 0)
       down? !x?
       fs (? (two? ops) ops '("."))
       hdr? (two? >fs)
       (rows es) (map (\ e (uls-row (e 2) <e <>e now tty?)) es)
       (show1 es ws0)                    ; a run of entries: long, gridded, or a name a line
        (? l? (uls-emit (rows es) ws0)
           grid? (uls-grid es tty? w down?)
           (: (go l) (? (atom? l) ()
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
           _ (? hdr? ((? first () (put out 10)), say out (p + ":"), put out 10) ())
           _ (? l? (: blk (foldl (\ a e (: b (ust-at <>e 7) (? (charm? b) (a + b) a))) 0 es)
                      _ (say out ("total " + (show (blk // 2)))) (put out 10)) ())
           _ (show1 srt rs)
           ok)
       ; the operands, GNU's way round: the non-directories first as one listing,
       ; then a listing per directory. -d makes every operand a non-directory.
       (miss p) (say err ("ls: cannot access " + p), put err 10, 0)
       bad (filter (\ p (atom? (lstat p))) fs)
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
       (walk l first ok) (? (atom? l) ok (walk >l 0 (dirlist <l first ok)))
       ok (walk dps (atom? pes) (? (two? bad) 0 1))
       ; GNU's ls answers 2 for "cannot access", not 1: 1 is a minor trouble
       ; (an unreadable subdirectory under -R) and 2 is "the operand is not there",
       ; which is the status a script's `ls x || ...` is reading.
       _ (flush out) (? ok 0 2))

   ; -- cp and mv: a directory destination pulls the basename in beside --
   ; -f is taken and ignored: it means "do not prompt", and without -i nothing prompts.
   ; -i asks before replacing, -n never replaces, the last of -f -i -n spelled wins; -u
   ; replaces only an older file. cp -a is -rpP: under -r or -P a link is copied as a
   ; link, and -L follows it as a plain cp does
   ; whether src may land on dst, which may already be there
   (uclob who how u? src dst)
    (: a (stat src) b (stat dst)
       (? !(ukind dst) 1
          (how = 110) 0
          (u? && two? a && two? b && <>>>a <= <>>>b) 0
          (how = 105) (uyes (who + ": overwrite '" + dst + "'? "))
          1))
   ; SRC.. DST, or with -t DIR every operand a source. with more than one source the
   ; target must be a directory; each source lands under udest, a miss is said and the
   ; rest still go
   (cp-srcs who ops td each1)
    (: fs (rev ops)
       dst (? td td <fs)
       srcs (? td ops (rev >fs))
       (? (atom? srcs) (udie 2 ("usage: " + who + " [-" + (who = "cp" ? "afinpPLrRuv" "finuv") + "] [-t DIR] SRC.. DST"))
          ((td || two? >srcs) && !(udirp dst))
           (udie 1 (who + ": target " + dst + " is not a directory"))
          (: ok (foldl (\ ok src (? (each1 src (udest src dst)) ok 0)) 1 srcs)
             (? ok 0 1))))
   (cp-main as)
    (: fo (uflags "cp" as '(116) "afinpPLrRtuv")
       t <fo
       a? (t 97)
       r? (? (a? || t 114 || t 82) 1 0)
       p? (? (a? || t 112) 1 0)
       deref? (? (t 76) 1 (a? || r? || t 80) 0 1)
       how (uoptlast as '(102 105 110) '(116) ())
       (said s d) (? (t 118) (say out ("'" + s + "' -> '" + d + "'\n")) 0)
       (kind q) (? deref? (? (udirp q) 'dir (ukind q) 'file ()) (ukind q))
       ; one thing that is not a directory
       (one1 s d)
        (: k (? (kind s = 'link)
                (: tg (readlink s)
                   _ (? (ukind d) (unlink d) 0)
                   (? (string? tg) (? (symlink tg d) (usay-err ("cp: cannot create " + d)) 1)
                      (usay-err ("cp: cannot read " + s))))
                (: k (ucopy1 "cp" s d)
                   st (? (k && p?) (stat s) ())
                   _ (? (two? st) (utime d <>st) 0)
                   k))
           _ (? k (said s d) 0)
           k)
       ; -r walks a tree top-down: a directory is laid at the far end and its entries
       ; follow it, its mode after them. a miss inside costs the answer, not the rest
       (tree s d)
        (: _ (? (udirp d) 0 (mkdir d 493, said s d))
           (? !(udirp d) (usay-err ("cp: cannot create " + d))
              (: ok (foldl (\ ok nm (: sp (s + "/" + nm) dp (d + "/" + nm)
                                       k (? (kind sp = 'dir) (tree sp dp)
                                            (uclob "cp" how (t 117) sp dp) (one1 sp dp)
                                            1)
                                       (? k ok 0)))
                           1 (readdir s))
                 st (stat s)
                 _ (? (two? st) (chmod d (4095 & <>>st)) 0)
                 _ (? (p? && two? st) (utime d <>st) 0)
                 ok)))
       (one src dst)
        (: k (kind src)
           (? !k (usay-err ("cp: cannot stat " + src))
              (k = 'dir) (? r? (tree src dst) (usay-err ("cp: -r not given; omitting directory " + src)))
              (uclob "cp" how (t 117) src dst) (one1 src dst)
              1))
       (cp-srcs "cp" (fo 1) (uoptv t 116) one))
   (mv-main as)
    (: fo (uflags "mv" as '(116) "finuvt")
       t <fo
       how (uoptlast as '(102 105 110) '(116) ())
       (one src dst)
        (? !(ukind src) (usay-err ("mv: cannot stat " + src))
           !(uclob "mv" how (t 117) src dst) 1
           (: e (rename src dst)
              k (? !e 1
                   (e = 'exdev) (? (ucopy1 "mv" src dst) (unlink src, 1) 0)  ; the long way
                   (usay-err ("mv: cannot move " + src)))
              _ (? (k && t 118) (say out ("renamed '" + src + "' -> '" + dst + "'\n")) 0)
              k))
       (cp-srcs "mv" (fo 1) (uoptv t 116) one))

   ; -- rm: unlink; -r walks a tree bottom-up and never through a link; -d takes an empty
   ; directory; -f keeps quiet about misses and answers no prompt; -i asks for each, the
   ; later of -f and -i winning. . and .. are refused, as GNU's are --
   (rm-main as)
    (: fo (uflags "rm" as () "dfirRv")
       t <fo fs (fo 1)
       r? (t 114 || t 82)
       f? (t 102)
       i? (uoptlast as '(102 105) () () = 105)
       (ask m) (? i? (uyes m) 1)
       (gone q m) (? (t 118) (say out (m + " '" + q + "'\n"), 1) 1)
       (rm1 q how e) (? !e (gone q how) (usay-err ("rm: cannot remove " + q)))
       (zap q)
        (: k (ukind q)
           (? !k (? f? 1 (usay-err ("rm: cannot remove " + q + ": no such file")))
              (k = 'dir)
               (? r? (: ok (foldl (\ ok nm (? (zap (q + "/" + nm)) ok 0)) 1 (readdir q))
                        (? !(ask ("rm: remove directory '" + q + "'? ")) ok
                           (rm1 q "removed directory" (rmdir q)) ok
                           0))
                  (t 100) (? (ask ("rm: remove directory '" + q + "'? ")) (rm1 q "removed directory" (rmdir q)) 1)
                  (usay-err ("rm: cannot remove " + q + ": is a directory")))
              (? (ask ("rm: remove '" + q + "'? ")) (rm1 q "removed" (unlink q)) 1)))
       (one q ok)
        (: b (ubase q "")
           k (? (b = "." || b = "..") (usay-err ("rm: refusing to remove " + q))
                (b = "/") (usay-err "rm: refusing to remove /")
                (zap q))
           (? k ok 0))
       (? (two? fs) (? (foldl (\ ok q (one q ok)) 1 fs) 0 1)
          f? 0
          (udie 2 "usage: rm [-dfirRv] FILE..")))

   ; -- mkdir and rmdir: -p lays every prefix on the way down, or takes it away on the
   ; way up; -m sets the new directory's mode whole, the umask aside --
   (mkdir-main as)
    (: fo (uflags "mkdir" as '(109) "mpv")
       t <fo fs (fo 1)
       p? (t 112)
       mw (uoptv t 109)
       m (? mw (umode mw 511 1 0) ())
       _ (? (!mw || charm? m) () (udie 1 ("mkdir: invalid mode: '" + mw + "'")))
       (made q) (? (t 118) (say out ("mkdir: created directory '" + q + "'\n")) 0)
       (mk q) (: e (mkdir q 493) (? e e (made q, ())))
       (mkp q)                          ; a tolerant mkdir at every slash, then the whole
        (: n #q
           (go k) (? (n <= k) (mk q)
                     ((? ((0 < k) && (q k = 47) && !(ukind (snip q 0 k))) (mk (snip q 0 k)) ()), go (k + 1)))
           (go 1))
       (one q ok)
        (: e (? p? (mkp q) (mk q))
           _ (? (!e && charm? m) (chmod q m) 0)
           (? (!e || (p? && udirp q)) ok
              (say err ("mkdir: cannot create " + q), put err 10, 0)))
       (go a ok) (? (two? a) (go >a (one <a ok)) (? ok 0 1))
       (? (two? fs) (go fs 1) (udie 2 "usage: mkdir [-pv] [-m MODE] DIR..")))
   (rmdir-main as)
    (: fo (uflags "rmdir" as () "pv")
       t <fo
       (rd q) (: e (rmdir q)
                 (? e (usay-err ("rmdir: cannot remove " + q))
                    (: _ (? (t 118) (say out ("rmdir: removing directory, '" + q + "'\n")) 0)
                       u (udir q)
                       (? (t 112 && !(u = "." || u = "/")) (rd u) 1))))
       (? (two? (fo 1)) (? (foldl (\ ok q (? (rd q) ok 0)) 1 (fo 1)) 0 1)
          (udie 2 "usage: rmdir [-pv] DIR..")))

   ; -- ln: two names for one thing (-s the pointing kind, -f moves the old name aside).
   ; TARGET LINK, TARGET alone into here, or TARGET.. DIR; -T never reads the last as a
   ; directory, -n not when it is a link to one --
   (ln-main as)
    (: fo (uflags "ln" as () "fnsTv")
       t <fo ops (fo 1) n #ops
       (dir? d) (? (t 84) 0 (t 110 && ukind d = 'link) 0 (udirp d))
       (mk tg nm)
        (: _ (? (t 102 && ukind nm && !(ukind nm = 'dir)) (unlink nm) 0)
           e (? (t 115) (symlink tg nm) (hardlink tg nm))
           (? e (usay-err ("ln: cannot link " + nm))
              (: _ (? (t 118) (say out ("'" + nm + "' -> '" + tg + "'\n")) 0) 1)))
       last (? (0 < n) (ops (n - 1)) ())
       (? (n = 0) (udie 2 "usage: ln [-fnsTv] TARGET [LINK] | ln [-fnsv] TARGET.. DIR")
          (n = 1) (? (mk <ops (ubase <ops "")) 0 1)
          (dir? last) (? (foldl (\ ok tg (? (mk tg (last + "/" + ubase tg "")) ok 0)) 1 (rev >(rev ops))) 0 1)
          (2 < n) (udie 1 ("ln: target " + last + " is not a directory"))
          (? (mk <ops last) 0 1)))

   ; -- touch: be there, and be now; -c makes nothing, -r takes a file's time, -d @SECONDS
   ; a given one --
   (touch-main as)
    (: fo (uflags "touch" as '(100 114) "cdr")
       t <fo fs (fo 1)
       rf (uoptv t 114)
       dw (uoptv t 100)
       rs (? rf (stat rf) ())
       _ (? (!rf || two? rs) () (udie 1 ("touch: cannot stat " + rf)))
       ms (? rf <>rs
             dw (? (1 < #dw && dw 0 = 64 && all digit? (chars (snip dw 1 #dw))) (1000 * unum (snip dw 1 #dw))
                   (udie 1 ("touch: cannot read the date '" + dw + "' (only @SECONDS here)")))
             ())
       (one q ok)
        (: there (two? (stat q))
           _ (? (there || t 99) () (: p (open q "a") (? (hot? p) (close p) ())))
           e (? (there || !(t 99)) (utime q ms) ())
           (? !e ok (say err ("touch: cannot touch " + q), put err 10, 0)))
       (go a ok) (? (two? a) (go >a (one <a ok)) (? ok 0 1))
       (? (two? fs) (go fs 1) (udie 2 "usage: touch [-c] [-r FILE] [-d @SECONDS] FILE..")))

   ; -- lift: hand a file to whatever is outside the machine -- the page's downloads,
   ; the node runner's directory -- by way of /proc/lift. a seat with no outside has
   ; no such file, and says so.
   (lift-main as)
    (: f (two? as && atom? >as ? <as (udie 2 "usage: lift FILE"))
       _ (two? (stat f) ? () (udie 1 ("lift: no such file: " + f)))
       p (open "/proc/lift" "w")
       (hot? p ? (say p f, close p, 0) (udie 1 "lift: nothing outside this seat to lift to")))

   ; -- chmod: a mode, octal or symbolic, onto every named path; -R down each directory,
   ; never through a link found on the way; -f keeps quiet. a word that is no mode
   ; refuses before anything changes --
   (chmod-main as)
    (: (cfl? w) (1 < #w && w 0 = 45 && all (i \ elem (w i) "Rf") >^#w)
       (fl a r f) (? (atom? a) [r f a]
                     (<a = "--") [r f >a]
                     (cfl? <a) (fl >a (? (r || has? <a "R") 1 0) (? (f || has? <a "f") 1 0))
                     [r f a])
       p (fl as 0 0) r? <p f? <>p rest <>>p
       _ (? (two? >rest) () (udie 2 "usage: chmod [-Rf] MODE FILE.."))
       m <rest
       um (umask-now 0)
       _ (? (charm? (umode m 0 0 um)) () (udie 1 ("chmod: invalid mode: '" + m + "'")))
       (set q) (: st (stat q)
                  (? (atom? st) (? f? 0 (usay-err ("chmod: cannot access " + q)))
                     (: e (chmod q (umode m (4095 & <>>st) (16384 = 61440 & <>>st) um))
                        (? !e 1 f? 0 (usay-err ("chmod: cannot chmod " + q))))))
       (tree q ok)
        (: k (set q)
           (? (r? && udirp q)
              (foldl (\ o nm (: p (q + "/" + nm) (? (ukind p = 'link) o (tree p o)))) (? k ok 0) (readdir q))
              (? k ok 0)))
       (? (foldl (\ ok q (tree q ok)) 1 >rest) 0 1))

   ; -- install: copy with the mode set in the same breath (what the build's
   ; place-a-file steps say). -d makes directories (with parents, like -p);
   ; -D lays the destination's parents first; -m octal sets the mode (else 755);
   ; -s (strip) is accepted and noted -- no stripper rides kore yet, so the copy
   ; keeps its symbol table (a fatter install, never a wrong one) --
   (imkp q)                        ; a tolerant mkdir at every slash (parents only)
    (: n #q
       (go k) (? (k < n) ((? ((0 < k) && (q k = 47)) (mkdir (snip q 0 k) 493) ()), go (k + 1))
                 ())
       (go 1))
   (install-main as)
    (: (fl a d D m s fs) (? (atom? a) [d D m s fs]
                            (<a = "-d") (fl >a 1 D m s fs)
                            (<a = "-D") (fl >a d 1 m s fs)
                            ((<a = "-m") && two? >a) (fl >>a d D (uoct <>a) s fs)
                            (<a = "-s") (fl >a d D m 1 fs)
                            (fl >a d D m s (fs + [<a])))
       p (fl as 0 0 493 0 ())
       d? <p D? <>p m <>>p s? <>>>p fs <>>>>p
       _ (? s? (say err "install: -s noted, not stripped (no kore stripper yet)", put err 10) ())
       (? d? (: (go a ok)
                 (? (two? a)
                    (: _ (imkp <a) e (mkdir <a m)
                       ok2 (? (udirp <a) ((? !e (chmod <a m) ()), ok)
                              (say err ("install: cannot create " + <a), put err 10, 0))
                       (go >a ok2))
                    (? ok 0 1))
                 (? (two? fs) (go fs 1) (udie 2 "usage: install -d DIR..")))
          (atom? >fs) (udie 2 "usage: install [-D] [-m OCTAL] [-s] SRC DST")
          (: src <fs dst (udest <fs <>fs)
             _ (? D? (imkp dst) ())
             _ (ucopy "install" src dst)
             _ (chmod dst m)
             0)))

   ; -- readlink: what a symbolic link says (-f chases to an absolute, clean path) --
   (rl-abs q) (? ((0 < tally q) && (q 0 = 47)) q (cwd () + "/" + q))
   (rl-clean q)                    ; lexically: no // . .. (.. pops a segment)
    (: n #q
       (seg i st acc) (? (i < n)
                         (? (q i = 47)
                            (seg (i + 1) (i + 1) (? (st < i) (snip q st i . acc) acc))
                            (seg (i + 1) st acc))
                         (rev (? (st < i) (snip q st i . acc) acc)))
       (fold l acc) (? (atom? l) (rev acc)
                       (<l = ".") (fold >l acc)
                       (<l = "..") (fold >l (? (two? acc) >acc acc))
                       (fold >l (<l . acc)))
       ("/" + ujoinc 47 (fold (seg 0 0 ()) ())))
   (rl-chase q n)                  ; follow link upon link (n bounds a cycle)
    (: t (readlink q)
       (? (atom? (stat q)) ()
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
       (? (string? r) (say out r, put out 10, flush out, 0) 1))

   ; -- realpath: a path with every symlink, every . and every .. taken out of it.
   ; the walk resolves component by component, so a last name that does not exist yet
   ; still answers -- GNU's default face. -e wants the whole path to be there, -m
   ; allows any of it to be missing, -s takes the links as they lie --
   (rp-parts p) (filter (\ w (0 < tally w)) (usplit 47 p))
   (rp-canon q n)                      ; the resolved path, or () past n links
    (: (walk acc parts d)
        (? (atom? parts) [1 acc]
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
       _ (: c (uoptun t "ems") (? !c () (udie 1 ("realpath: unknown option -" + string c))))
       fs <>>o
       _ (? (two? fs) () (udie 1 "usage: realpath [-e|-m|-s] PATH.."))
       e? (peep t 101 0) m? (peep t 109 0) s? (peep t 115 0)
       (one q ok)
        (: r (? s? [1 (rl-clean (rl-abs q))] (rp-canon q 40))
           (? (atom? r)
              (say err ("realpath: " + q + ": too many levels of symbolic links"), put err 10, 0)
              (: p <>r
                 want (? m? () (? e? p (udir p)))    ; what has to be there to answer
                 (? ((want = ()) || (two? (stat want)))
                    (say out p, put out 10, ok)
                    (say err ("realpath: " + q + ": No such file or directory"), put err 10, 0)))))
       (go a ok) (? (two? a) (go >a (one <a ok)) (flush out, (? ok 0 1)))
       (go fs 1))

   ; -- link and unlink: the two syscalls said plainly, no face on them (ln and rm
   ; are where the faces live) --
   (link-main as)
    (? (atom? >as) (udie 1 "usage: link FILE NEW")
       (: e (hardlink <as <>as)
          (? !e 0 (udie 1 ("link: cannot link " + <>as + " to " + <as)))))
   (unlink-main as)
    (? (atom? as) (udie 1 "usage: unlink FILE")
       (: e (unlink <as)
          (? !e 0 (udie 1 ("unlink: cannot unlink " + <as)))))

   ; ---- the reporting tools: stat, du -- and chown, mktemp ---------------------
   ; these read the stat tail. love/posix.c's stat answers
   ; (size mtime mode ns uid gid nlink blocks ino), append-only, and the kernel's own
   ; stat (inle/kmain.c) answers the first four alone -- an image tree has no ownership
   ; to tell about. so the tail is asked by tally and a world that does not carry it
   ; says so rather than reading a 0 someone might believe.
   (ust-at st k) (? (#st <= k) () (st k))
   ; /etc/passwd and /etc/group, read as the files they are (no NSS, no getpwnam)
   (uidname path id)                   ; a numeric id -> its name, or the number back
    (: r (uread path)
       (atom? r ? (show id)
        (: (go ls) (atom? ls ? (show id)
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
        (? (atom? ls) acc
           (: f (usplit 58 <ls)
              g (? (4 <= tally f) (uatoi (f 2)) -1)
              ms (? (4 <= tally f) (usplit 44 (f 3)) ())
              (go >ls (? ((elem nm ms) && !(g = gid)) (g . acc) acc))))
       rest (? (two? r) (sort (go (lines <>r) ())) ())
       (gid . rest))

   ; -- stat: the file's own facts. bare, it prints GNU's eight-line block; -c FORMAT
   ; (or --printf=, which reads the escapes and adds no newline) asks for named fields:
   ; %n %N %s %b %B %f %a %A %F %u %U %g %G %h %i %m %o %d %D %r %R %t %T %y %Y %x %X
   ; %z %Z %w %W, the \n \t \\ escapes, and %% ; anything else is GNU's bare ?. -L
   ; follows a symbolic link and the bare face does not.
   ; %N is the name shell-quoted, and a link's own target after an arrow.
   ; the quoting is the shell's: single quotes, '\'' for a quote of its own, $'\t' for a
   ; control byte, and double quotes for a name whose only trouble IS the quote. a byte
   ; over 127 rides through -- there is no locale here to tell text from a stray byte,
   ; and text is what a name usually is.
   (ushq-esc c)                        ; the text after the backslash in $'..'
    (c @ 7 "a" 8 "b" 9 "t" 10 "n" 11 "v" 12 "f" 13 "r" (zpad 3 (radix c 8)))
   (ushq-ctl? c) (c < 32 || c = 127)
   (ushq w)
    (: n #w
       (scan k q? hard?)                ; holds a quote? holds anything a "" would escape?
        (? (n <= k) [q? hard?]
           (: c (w k)
              (scan (k + 1) (q? || c = 39)
                    (hard? || (ushq-ctl? c) || elem c '(34 36 92 96)))))
       (sq k o)
        (? (n <= k) (slurp o)
           (: c (w k)
              _ (? (c = 39) (say o "'\\''")
                   (ushq-ctl? c) (say o ("'$'\\" + (ushq-esc c) + "''"))
                   (put o c))
              (sq (k + 1) o)))
       r (scan 0 0 0)
       (? (<r && !<>r) ("\"" + w + "\"") ("'" + (sq 0 (jug 0)) + "'")))
   (ust-name p md)
    (: q (ushq p)
       (? !(40960 = md & 61440) q
          (: t (readlink p) (? (string? t) (q + " -> " + (ushq t)) q))))
   ; a device number is one packed word and linux splits it unevenly: the major's low
   ; twelve bits sit at 8, its high twenty at 32; the minor's low eight at 0 and the
   ; rest at 12. %t/%T print the two in hex, %d/%D and %r/%R the whole word either way.
   (ust-major d) (((d >> 32) & 4294963200) | ((d >> 8) & 4095))
   (ust-minor d) (((d >> 12) & 4294967040) | (d & 255))
   (ust-mount p)                       ; %m: the mount point the path sits on
    (: m (udf-holds (udf-mounts ()) p) (? m <>m "/"))
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
    (: s (ns // 1000000000) frac (ns % 1000000000)
       ymd (civil (s // 86400)) secs (s % 86400)
       (p2 v) (zpad 2 (show v))
       ((((show <ymd) + "-" + (p2 <>ymd) + "-" + (p2 <>>ymd)) + " ")
        + (((p2 (secs // 3600)) + ":" + (p2 ((secs % 3600) // 60)) + ":" + (p2 (secs % 60)))
           + ("." + (zpad 9 (show frac)) + " +0000"))))
   ; -c does not read escapes -- `stat -c 'a\tb'` prints the backslash and the t, and
   ; adds a newline of its own; --printf reads them and adds none. GNU's split, and the
   ; only way a format can carry a literal backslash at all.
   (ust-expand fmt p st esc? L?)
    (:- (go 0)
     n #fmt o (jug 0)
     sz <st md <>>st ns (st 3)
     uid (ust-at st 4) gid (ust-at st 5) nlk (ust-at st 6)
     blk (ust-at st 7) ino (ust-at st 8)
     ats (ust-at st 9) cts (ust-at st 10)
     dev (ust-at st 11) rdev (ust-at st 12) iob (ust-at st 13)
     (num v) (? (charm? v) (show v) "?")
     (hex v) (? (charm? v) (radix v 16) "?")
     (secs v) (? (charm? v) (show (v // 1000000000)) "?")
     (when v) (? (charm? v) (ustamp v) "?")
     (go k) (n <= k ? (slurp o) (: c (fmt k) (?- (go (k + 2))
      (esc? && c = 92 && k + 1 < n)
       (: d (fmt (k + 1))
        (d @ 110 (put o 10) 116 (put o 9) 92 (put o 92) (put o 92, put o d), go (k + 2)))
       (c != 37 || k + 1 >= n) (put o c, go (k + 1))
       (fmt (k + 1) @
        37 (put o 37)
        110 (say o p)
        78 (say o (ust-name p md))
        115 (say o (show sz))
        98 (say o (num blk))
        66 (say o "512")
        102 (say o (radix md 16))
        97 (say o (radix (md & 4095) 8))
        65 (say o (ust-perm md))
        70 (say o (ust-kind md sz))
        117 (say o (num uid))
        85 (say o (charm? uid ? (uidname "/etc/passwd" uid) "?"))
        103 (say o (num gid))
        71 (say o (charm? gid ? (uidname "/etc/group" gid) "?"))
        104 (say o (num nlk))
        105 (say o (num ino))
        89 (say o (secs ns))
        121 (say o (when ns))
        88 (say o (secs ats))
        120 (say o (when ats))
        90 (say o (secs cts))
        122 (say o (when cts))
        ; the birth time is statx's own call, so it is asked only where it is spelled --
        ; and a filesystem keeping none answers the dash and the zero GNU answers
        87 (say o (: b (birth p L?) (charm? b ? (secs b) "0")))
        119 (say o (: b (birth p L?) (charm? b ? (ustamp b) "-")))
        100 (say o (num dev))
        68 (say o (hex dev))
        114 (say o (num rdev))
        82 (say o (hex rdev))
        116 (say o (hex (? (charm? rdev) (ust-major rdev) ())))
        84 (say o (hex (? (charm? rdev) (ust-minor rdev) ())))
        111 (say o (num iob))
        109 (say o (ust-mount p))
        67 (say o "?")                  ; the security context: no labels here
        (put o 63))))))                 ; an unknown directive is GNU's bare ?
   ; the default face: GNU's block, line for line. what once refused it was missing
   ; access, change and device -- the stat tuple carries all three now -- and the birth
   ; time, which is statx's own call and answers the dash where a filesystem keeps none.
   ; the widths are GNU's printf: a Links is padded only when a device type follows it,
   ; and the name here is raw, not %N's shell-quoted one.
   (ust-block p st L?)
    (: sz <st md <>>st ns (st 3)
       kind (md & 61440)
       dev (ust-at st 11) rdev (ust-at st 12)
       dev? ((kind = 8192) || (kind = 24576))
       ; -L followed, so a link's own mode can only be here when it did not: the kind
       ; alone says whether there is an arrow to draw, and asks readlink only then
       t (? (kind = 40960) (readlink p) ())
       nm (? (string? t) (p + " -> " + t) p)
       (num v) (? (charm? v) (show v) "?")
       (idcol id path) (: n (? (charm? id) (uidname path id) "?")
                          ((upad 5 (num id)) + "/" + (upad 8 n)))
       (line s) (say out s, put out 10)
       _ (line ("  File: " + nm))
       _ (line ("  Size: " + (urpad 10 (show sz)) + string 9
                + "Blocks: " + (urpad 10 (num (ust-at st 7)))
                + " IO Block: " + (urpad 6 (num (ust-at st 13)))
                + " " + (ust-kind md sz)))
       _ (line ("Device: " + (num (? (charm? dev) (ust-major dev) ()))
                + "," + (num (? (charm? dev) (ust-minor dev) ()))
                + string 9 + "Inode: " + (urpad 10 (num (ust-at st 8)))
                + "  Links: " + (? dev? (urpad 5 (num (ust-at st 6))) (num (ust-at st 6)))
                ; the block spells a device type in DECIMAL; only %t and %T are hex
                + (? dev? (" Device type: " + (num (ust-major rdev))
                           + "," + (num (ust-minor rdev))) "")))
       _ (line ("Access: (" + (zpad 4 (radix (md & 4095) 8)) + "/" + (ust-perm md)
                + ")  Uid: (" + (idcol (ust-at st 4) "/etc/passwd")
                + ")   Gid: (" + (idcol (ust-at st 5) "/etc/group") + ")"))
       _ (line ("Access: " + (ustamp (ust-at st 9))))
       _ (line ("Modify: " + (ustamp ns)))
       _ (line ("Change: " + (ustamp (ust-at st 10))))
       b (birth p L?)
       (line (" Birth: " + (charm? b ? (ustamp b) "-"))))
   (stat-main as)
    (: (long? w n s) ((n < tally w) && (snip w 0 n = s))
       (fl a fmt L pf fs)
        (? (atom? a) [fmt L pf (rev fs)]
           (<a = "-L") (fl >a fmt 1 pf fs)
           (<a = "-c") (? (two? >a) (fl >>a <>a L 0 fs) (udie 2 "stat: -c wants a format"))
           (2 < #<a && snip <a 0 2 = "-c") (fl >a (snip <a 2 #<a) L 0 fs)
           (long? <a 9 "--format=") (fl >a (snip <a 9 #<a) L 0 fs)
           (long? <a 9 "--printf=") (fl >a (snip <a 9 #<a) L 1 fs)
           (fl >a fmt L pf (<a . fs)))
       p (fl as () 0 0 ())
       fmt <p L? <>p pf? <>>p fs (p 3)
       _ (? (two? fs) () (udie 2 "usage: stat [-L] [-c FORMAT | --printf=FORMAT] FILE.."))
       (one q ok)
        (: st (? L? (stat q) (lstat q))
           (? (atom? st)
              (say err ("stat: cannot stat '" + q + "': No such file or directory\n"), 0)
              (string? fmt) (say out (ust-expand fmt q st pf? L?), pf? || put out 10, ok)
              (ust-block q st L?, ok)))
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
    (: (fl a t fs) (? (atom? a) [t (rev fs)]
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
           ct (? b? (? dir? 0 <st) (512 * (? (charm? (ust-at st 7)) (ust-at st 7) 0)))
           (? ((charm? nlk) && (1 < nlk))
              (? (peep seen ino 0) 0 (pin seen ino 1, ct))
              ct))
       (walk q depth top?)
        (: st (lstat q)
           (atom? st ?  (say err ("du: cannot access '" + q + "'\n"), pin t 'bad 1, 0)
            (: dir? (16384 = (61440 & <>>st))
               kids (?- 0 dir?
                     (foldl (acc \ c \ acc + walk (q + "/" + c) (depth + 1) 0) 0 (sort (readdir q))))
               tot (own st dir? + kids)
               deep? (charm? maxd && maxd < depth)
               _ ((dir? || a? || top?) && !s? && !deep? && emit tot q)
               tot)))
       (go a acc) (atom? a ? acc (walk <a 0 1 @ n (s? && emit n <a, go >a (acc + n))))
       total (go fs 0)
       (c? && emit total "total",
        flush out,
        !!(peep t 'bad 0)))

   ; -- df: what each filesystem holds. the mount list is /proc/self/mounts, the same
   ; place `mount` reads and the only one there is here, and the numbers are statfs(2)'s
   ; -- linux's call alone, so a kernel without it never gets past the mount list.
   ; 1K blocks by default; -h the three-figure human face du -h already spells, -i the
   ; inode counts instead, -a the filesystems with no blocks at all (proc, sysfs, the
   ; cgroups), which the bare face drops the way GNU's does. every figure rounds UP, and
   ; Use% is taken off the raw counts rather than the rounded ones -- a filesystem whose
   ; used and available are both nothing has no percentage, and says so with a dash.
   ; a named FILE reports the one filesystem holding it: statfs answers the numbers, and
   ; the longest mount point its resolved path starts with names the device.
   ; every mount here is asked, GNU's -a dashes a few by TYPE (autofs and the rest of its
   ; dummy list) without asking at all -- so an automount placeholder reports the zeroes
   ; statfs really answered instead of a dash.
   (udf-esc w)                         ; a mount line's \040 \011 \012 \134, read back
    (: n #w o (jug 0)
       (oct? c) ((47 < c) && (c < 56))
       (go k) (? (n <= k) (slurp o)
                 (: a (? (k + 3 < n && w k = 92) (w (k + 1)) 0)
                    b (? a (w (k + 2)) 0) c (? a (w (k + 3)) 0)
                    (? ((oct? a) && (oct? b) && (oct? c))
                       (put o (((a - 48) * 64 + (b - 48) * 8) + (c - 48)), go (k + 4))
                       (put o (w k), go (k + 1)))))
       (go 0))
   (udf-mounts _)                      ; ((dev point)..) in the kernel's order, or ()
    (: r (uread "/proc/self/mounts")
       (go l acc) (? (atom? l) (rev acc)
                     (: w (words <l)
                        (go >l (? (2 <= #w) ([(udf-esc (w 0)) (udf-esc (w 1))] . acc) acc))))
       (? (two? r) (go (filter (\ s #s) (lines <>r)) ()) ()))
   ; the mount a path sits on: the LONGEST point its resolved name starts with, so a
   ; bind mount names itself and not the twin it shares a device with. stat's %m asks
   ; this too, which is why it is here and not inside df's own walk.
   (udf-holds ms p)
    (: c (: q (rp-canon p 40) (? (two? q) <>q p))
       (fits m) (: pt <>m n #pt
                   ((snip c 0 n = pt) && ((n = #c) || (pt = "/") || (c n = 47))))
       (foldl (\ b m (? ((fits m) && (!b || (#<>b < #<>m))) m b)) () ms))
   (udf-up a b) (? (b <= 0) 0 ((a + b - 1) // b))
   (udf-pct u a) (? ((u + a) <= 0) "-" ((show (udf-up (u * 100) (u + a))) + "%"))
   (udf-cells dev pt fs h? i?)         ; a statfs tuple -> the six cells of its row
    (: bs (fs 0) blk (fs 1) fre (fs 2) av (fs 3) ino (fs 4) ifr (fs 5)
       frs (: f (fs 6) (? ((charm? f) && (0 < f)) f bs))
       (sz n) (? h? (uhuman (n * frs)) (show (udf-up (n * frs) 1024)))
       (? i? [dev (show ino) (show (ino - ifr)) (show ifr) (udf-pct (ino - ifr) ifr) pt]
          [dev (sz blk) (sz (blk - fre)) (sz av) (udf-pct (blk - fre) av) pt]))
   ; the table: every column as wide as its widest cell but never under the floor below,
   ; one space between, the ends ragged -- the first column reads left and the last is
   ; never padded at all. the floors are GNU's, and they are why a table of short names
   ; still lines up with one of long ones.
   udf-min '(14 5 5 5 4 0)
   (udf-show rows)
    (: n #<rows
       ws (map (\ k (foldl (\ w r (: c #(r k) (? (w < c) c w))) (udf-min k) rows)) ^n)
       (line r) (: (go k acc) (? (n <= k) acc
                                 (: s (r k)
                                    p (? (k + 1 = n) s (? k (upad (ws k) s) (urpad (ws k) s)))
                                    (go (k + 1) (? k (acc + " " + p) p))))
                   (go 0 ""))
       (go rs) (? (two? rs) (say out (line <rs), put out 10, go >rs) 0)
       (go rows))
   (df-main as)
    (: t {}
       (fl a fs) (? (atom? a) (rev fs)
                    (#<a < 2 || <a 0 != 45) (fl >a (<a . fs))
                    (:- (cl 1) w <a (cl k) (#w <= k ? (fl >a fs) (w k @
                     104 (pin t 'h 1, cl (k + 1))
                     105 (pin t 'i 1, cl (k + 1))
                     97 (pin t 'a 1, cl (k + 1))
                     107 (cl (k + 1))   ; -k is the default, and -P names this very face
                     80 (cl (k + 1))    ; (posix's, and the only one laid out here)
                     c (udie 2 $ "df: unknown option -" + string c)))))
       fs (fl as ())
       h? (t 'h) i? (t 'i) a? (t 'a)
       hdr (? i? '("Filesystem" "Inodes" "IUsed" "IFree" "IUse%" "Mounted on")
              h? '("Filesystem" "Size" "Used" "Avail" "Use%" "Mounted on")
              '("Filesystem" "1K-blocks" "Used" "Available" "Use%" "Mounted on"))
       ms (udf-mounts ())
       _ (? ((two? fs) || (two? ms)) () (udie 1 "df: cannot read /proc/self/mounts"))
       (named p acc)
        (: r (statfs p)
           (? (two? r) (: m (udf-holds ms p) ((udf-cells (? m <m "-") (? m <>m p) r h? i?) . acc))
              (say err ("df: " + p + ": "
                             + (? (r = 'eacces) "Permission denied" "No such file or directory")), put err 10, pin t 'bad 1, acc)))
       ; a filesystem the call refuses (a mount someone else owns) is dropped from the
       ; bare face and kept by -a, its figures dashed -- there is nothing to report and
       ; a row of zeroes would read as an answer.
       (scan mm acc)
        (? (atom? mm) acc
           (: m <mm r (statfs <>m)
              (scan >mm (? (two? r) (? (a? || (r 1)) ((udf-cells <m <>m r h? i?) . acc) acc)
                           a? ([<m "-" "-" "-" "-" <>m] . acc)
                           acc))))
       rows (rev (? (two? fs) (foldl (\ a p (named p a)) () fs) (scan ms ())))
       _ (? (two? rows) (udf-show (hdr . rows)) ())
       _ (flush out)
       !!(peep t 'bad 0))

   ; -- chown: owner[:group] onto every named path, -R down the tree. a name is looked
   ; up in /etc/passwd / /etc/group, a numeral is taken as itself, and an empty side is
   ; -1, which the kernel reads as "leave this one alone" --
   (uowner who spec shown)             ; "u:g" / "u" / ":g" -> (uid gid), -1 for absent
    (: ps (usplit 58 spec)
       (side w path kind) (0 >= #w ? -1
                           (uidof path w @ r
                            (two? r ? <>r (w 0 @ c (48 <= c <= 57 ? (uatoi w)
                                           (udie 1 (who + ": invalid " + kind + ": '" + shown + "'")))))))
       [(side <ps "/etc/passwd" "user") (atom? >ps ? -1 (side <>ps "/etc/group" "group"))])
   ; chown and chgrp are one walk: chgrp's GROUP is chown's :GROUP
   (uchown who as)
    (: r? (two? as && <as = "-R")
       rest (r? ? >as as)
       grp? (who = "chgrp")
       _ (atom? >rest && udie 2 ("usage: " + who + (grp? ? " [-R] GROUP FILE.." " [-R] OWNER[:GROUP] FILE..")))
       ug (grp? ? (uowner who (":" + <rest) <rest) (uowner who <rest <rest))
       uid <ug gid <>ug
       (one q ok)
        (: e (chown q uid gid)
           ok2 (!e ? ok (say err (who + (grp? ? ": cannot change group of '" ": cannot chown '") + q + "'\n"), 0))
           (r? && (udirp q) ?
            (foldl (acc \ c \ one (q + "/" + c) acc) ok2 (readdir q))
            ok2))
       (go a ok) (two? a ? (go >a (one <a ok)) !ok)
       (go >rest 1))
   (chown-main as) (uchown "chown" as)
   (chgrp-main as) (uchown "chgrp" as)

   ; -- truncate: each file cut or stretched to a size. -s [+-<>/%]N with GNU's suffixes
   ; (grow by, shrink by, at most, at least, down or up to a multiple), -r a file whose
   ; size is the start, -o the count in the file's own blocks, -c make no file --
   (utrunc-n w)
    (: n #w (dend k) (? (k < n && 47 < w k < 58) (dend (k + 1)) k)
       e (dend 0) v (? (0 < e) (unum (snip w 0 e)) ())
       sf (snip w e n)
       m (? (sf = "") 1 (: r (filter (\ p (<p = sf)) uclip-sfx) (? (two? r) <>(<r) ())))
       (? (charm? v && charm? m) (v * m) (udie 1 ("truncate: Invalid number: '" + w + "'"))))
   (truncate-main as)
    (: t (tablet 0)
       (val w k a f) (? (k < #w) (pin t f (snip w k #w), go a)
                        (two? a) (pin t f <a, go >a)
                        (udie 1 ("truncate: option requires an argument -- '" + string (w (k - 1)) + "'")))
       (go a)
        (? (atom? a) ()
           (: w <a n #w
              (? (w = "--") >a
                 (w = "--no-create") (pin t 'c 1, go >a)
                 (w = "--io-blocks") (pin t 'o 1, go >a)
                 (w = "--size" || w = "--reference")
                  (? (two? >a) (pin t (? (w 2 = 115) 's 'r) <>a, go >>a)
                     (udie 1 ("truncate: option '" + w + "' requires an argument")))
                 (7 < n && snip w 0 7 = "--size=") (pin t 's (snip w 7 n), go >a)
                 (12 < n && snip w 0 12 = "--reference=") (pin t 'r (snip w 12 n), go >a)
                 (1 < n && w 0 = 45 && !(w 1 = 45))
                  (: (cl k) (? (n <= k) (go >a)
                               (: c (w k)
                                  (? (c = 99) (pin t 'c 1, cl (k + 1))
                                     (c = 111) (pin t 'o 1, cl (k + 1))
                                     (c = 115) (val w (k + 1) >a 's)
                                     (c = 114) (val w (k + 1) >a 'r)
                                     (udie 1 ("truncate: invalid option -- '" + string c + "'\nTry 'truncate --help' for more information.")))))
                     (cl 1))
                 (1 < n && w 0 = 45) (udie 1 ("truncate: unrecognized option '" + w + "'\nTry 'truncate --help' for more information."))
                 (w . (go >a)))))
       fs (go as)
       sz (t 's) rf (t 'r)
       op (? sz (: c (? (0 < #sz) (sz 0) 0) (? (elem c [43 45 60 62 47 37]) c 0)) 0)
       num (? sz (utrunc-n (? (op = 0) sz (snip sz 1 #sz))) 0)
       try "\nTry 'truncate --help' for more information."
       _ (? (!sz && !rf) (udie 1 ("truncate: you must specify either '--size' or '--reference'" + try)) 0)
       _ (? (rf && sz && op = 0) (udie 1 ("truncate: you must specify a relative '--size' with '--reference'" + try)) 0)
       _ (? ((t 'o) && !sz) (udie 1 ("truncate: '--io-blocks' was specified but '--size' was not" + try)) 0)
       _ (? (two? fs) 0 (udie 1 ("truncate: missing file operand" + try)))
       _ (? ((op = 47 || op = 37) && num = 0) (udie 1 "truncate: division by zero") 0)
       rsz (? rf (: st (stat rf) (? (two? st) <st (udie 1 ("truncate: cannot stat '" + rf + "': " + uerrno st)))) 0)
       (fail f e) (say err ("truncate: cannot open '" + f + "' for writing: " + uerrno e + "\n"), 1)
       (one f)
        (: st0 (stat f)
           mk (? (t 'c) 0 1)
           e0 (? ((atom? st0) && t 'o && mk) (truncate f 0 1) ())
           st (? (two? st0) st0 (stat f))
           (? ((atom? st0) && t 'c) 0
              (nom? e0) (fail f e0)
              (: bs (? (two? st && 13 < #st) (st 13) 512)
                 n (? (t 'o) (num * bs) num)
                 base (? rf rsz (two? st) <st 0)
                 want (? !sz rsz (op = 0) n (op = 43) (base + n) (op = 45) (max 0 (base - n))
                         (op = 60) (min base n) (op = 62) (max base n)
                         (op = 47) (base // n * n) ((base + n - 1) // n * n))
                 e (truncate f want mk)
                 (? (nom? e) (fail f e) 0))))
       r (foldl (\ a f (max a (one f))) 0 fs)
       _ (flush err)
       r)

   ; -- fsync: what the kernel holds of each file written down (-d fdatasync's lesser
   ; promise, the file's data alone) --
   (fsync-main as)
    (: d? (two? as && <as = "-d")
       fs (? d? >as as)
       ok (foldl (\ a f (: e (fsync f d?)
                           (? (nom? e) (say err ("fsync: " + f + ": " + uerrno e + "\n"), 0) a)))
                 1 fs)
       _ (flush err)
       (? ok 0 1))

   ; -- dircolors: LS_COLORS spelled for a shell, off GNU's database -- its own text,
   ; which says it may be copied, as -p prints it -- or a file of that language: the
   ; TERM and COLORTERM globs pick the stanzas that apply, a keyword names a file kind,
   ; .ext and *glob name a suffix. -b and -c pick the shell, else $SHELL does --
   udc-db "# Configuration file for dircolors, a utility to help you set the
# LS_COLORS environment variable used by GNU ls with the --color option.
# Copyright (C) 1996-2026 Free Software Foundation, Inc.
# Copying and distribution of this file, with or without modification,
# are permitted provided the copyright notice and this notice are preserved.
#
# The keywords COLOR, OPTIONS, and EIGHTBIT (honored by the
# slackware version of dircolors) are recognized but ignored.
# Global config options can be specified before TERM or COLORTERM entries
# ===================================================================
# Terminal filters
# ===================================================================
# Below are TERM or COLORTERM entries, which can be glob patterns, which
# restrict following config to systems with matching environment variables.
COLORTERM ?*
TERM Eterm
TERM ansi
TERM *color*
TERM con[0-9]*x[0-9]*
TERM cons25
TERM console
TERM cygwin
TERM *direct*
TERM dtterm
TERM gnome
TERM hurd
TERM jfbterm
TERM konsole
TERM kterm
TERM linux
TERM linux-c
TERM mlterm
TERM putty
TERM rxvt*
TERM screen*
TERM st
TERM terminator
TERM tmux*
TERM vt100
TERM vt220
TERM xterm*
# ===================================================================
# Basic file attributes
# ===================================================================
# Below are the color init strings for the basic file types.
# One can use codes for 256 or more colors supported by modern terminals.
# The default color codes use the capabilities of an 8 color terminal
# with some additional attributes as per the following codes:
# Attribute codes:
# 00=none 01=bold 04=underscore 05=blink 07=reverse 08=concealed
# Text color codes:
# 30=black 31=red 32=green 33=yellow 34=blue 35=magenta 36=cyan 37=white
# Background color codes:
# 40=black 41=red 42=green 43=yellow 44=blue 45=magenta 46=cyan 47=white
#NORMAL 00 # no color code at all
#FILE 00 # regular file: use no color at all
RESET 0 # reset to \"normal\" color
DIR 01;34 # directory
LINK 01;36 # symbolic link. (If you set this to 'target' instead of a
 # numerical value, the color is as for the file pointed to.)
MULTIHARDLINK 00 # regular file with more than one link
FIFO 40;33 # pipe
SOCK 01;35 # socket
DOOR 01;35 # door
BLK 40;33;01 # block device driver
CHR 40;33;01 # character device driver
ORPHAN 40;31;01 # symlink to nonexistent file, or non-stat'able file ...
MISSING 00 # ... and the files they point to
SETUID 37;41 # regular file that is setuid (u+s)
SETGID 30;43 # regular file that is setgid (g+s)
CAPABILITY 00 # regular file with capability (very expensive to lookup)
STICKY_OTHER_WRITABLE 30;42 # dir that is sticky and other-writable (+t,o+w)
OTHER_WRITABLE 34;42 # dir that is other-writable (o+w) and not sticky
STICKY 37;44 # dir with the sticky bit set (+t) and not other-writable
# This is for regular files with execute permission:
EXEC 01;32
# ===================================================================
# File extension attributes
# ===================================================================
# List any file extensions like '.gz' or '.tar' that you would like ls
# to color below. Put the suffix, a space, and the color init string.
# (and any comments you want to add after a '#').
# Suffixes are matched case insensitively, but if you define different
# init strings for separate cases, those will be honored.
#
# If you use DOS-style suffixes, you may want to uncomment the following:
#.cmd 01;32 # executables (bright green)
#.exe 01;32
#.com 01;32
#.btm 01;32
#.bat 01;32
# Or if you want to color scripts even if they do not have the
# executable bit actually set.
#.sh 01;32
#.csh 01;32
# archives or compressed (bright red)
.7z 01;31
.ace 01;31
.alz 01;31
.apk 01;31
.arc 01;31
.arj 01;31
.bz 01;31
.bz2 01;31
.cab 01;31
.cpio 01;31
.crate 01;31
.deb 01;31
.drpm 01;31
.dwm 01;31
.dz 01;31
.ear 01;31
.egg 01;31
.esd 01;31
.gz 01;31
.jar 01;31
.lha 01;31
.lrz 01;31
.lz 01;31
.lz4 01;31
.lzh 01;31
.lzma 01;31
.lzo 01;31
.pyz 01;31
.rar 01;31
.rpm 01;31
.rz 01;31
.sar 01;31
.swm 01;31
.t7z 01;31
.tar 01;31
.taz 01;31
.tbz 01;31
.tbz2 01;31
.tgz 01;31
.tlz 01;31
.txz 01;31
.tz 01;31
.tzo 01;31
.tzst 01;31
.udeb 01;31
.war 01;31
.whl 01;31
.wim 01;31
.xz 01;31
.z 01;31
.zip 01;31
.zoo 01;31
.zst 01;31
# image formats
.avif 01;35
.jpg 01;35
.jpeg 01;35
.jxl 01;35
.mjpg 01;35
.mjpeg 01;35
.gif 01;35
.bmp 01;35
.pbm 01;35
.pgm 01;35
.ppm 01;35
.tga 01;35
.xbm 01;35
.xpm 01;35
.tif 01;35
.tiff 01;35
.png 01;35
.svg 01;35
.svgz 01;35
.mng 01;35
.pcx 01;35
.mov 01;35
.mpg 01;35
.mpeg 01;35
.m2v 01;35
.mkv 01;35
.webm 01;35
.webp 01;35
.ogm 01;35
.mp4 01;35
.m4v 01;35
.mp4v 01;35
.vob 01;35
.qt 01;35
.nuv 01;35
.wmv 01;35
.asf 01;35
.rm 01;35
.rmvb 01;35
.flc 01;35
.avi 01;35
.fli 01;35
.flv 01;35
.gl 01;35
.dl 01;35
.xcf 01;35
.xwd 01;35
.yuv 01;35
.cgm 01;35
.emf 01;35
# https://wiki.xiph.org/MIME_Types_and_File_Extensions
.ogv 01;35
.ogx 01;35
# audio formats
.aac 00;36
.au 00;36
.flac 00;36
.m4a 00;36
.mid 00;36
.midi 00;36
.mka 00;36
.mp3 00;36
.mpc 00;36
.ogg 00;36
.ra 00;36
.wav 00;36
# https://wiki.xiph.org/MIME_Types_and_File_Extensions
.oga 00;36
.opus 00;36
.spx 00;36
.xspf 00;36
# backup files
*~ 00;90
*# 00;90
.bak 00;90
.crdownload 00;90
.dpkg-dist 00;90
.dpkg-new 00;90
.dpkg-old 00;90
.dpkg-tmp 00;90
.old 00;90
.orig 00;90
.part 00;90
.rej 00;90
.rpmnew 00;90
.rpmorig 00;90
.rpmsave 00;90
.swp 00;90
.tmp 00;90
.ucf-dist 00;90
.ucf-new 00;90
.ucf-old 00;90
#
# Subsequent TERM or COLORTERM entries, can be used to add / override
# config specific to those matching environment variables.
"
   udc-slack '("NORMAL" "NORM" "FILE" "RESET" "DIR" "LNK" "LINK" "SYMLINK" "ORPHAN" "MISSING"
               "FIFO" "PIPE" "SOCK" "BLK" "BLOCK" "CHR" "CHAR" "DOOR" "EXEC" "LEFT" "LEFTCODE"
               "RIGHT" "RIGHTCODE" "END" "ENDCODE" "SUID" "SETUID" "SGID" "SETGID" "STICKY"
               "OTHER_WRITABLE" "OWR" "STICKY_OTHER_WRITABLE" "OWT" "CAPABILITY" "MULTIHARDLINK"
               "CLRTOEOL")
   udc-ls '("no" "no" "fi" "rs" "di" "ln" "ln" "ln" "or" "mi" "pi" "pi" "so" "bd" "bd" "cd" "cd"
            "do" "ex" "lc" "lc" "rc" "rc" "ec" "ec" "su" "su" "sg" "sg" "st" "ow" "ow" "tw" "tw"
            "ca" "mh" "cl")
   (udc-up s) (: o (jug 0) _ (map (\ c (put o (? (96 < c && c < 123) (c - 32) c))) (map s ^#s)) (slurp o))
   ; fnmatch's three, enough for the database's globs: * ? and a [set]
   (udc-glob p s)
    (: (m i j)
        (? (#p <= i) (#s <= j)
           (p i = 42) (: (any k) (? (m (i + 1) k) 1 (k < #s) (any (k + 1)) 0) (any j))
           (#s <= j) 0
           (p i = 63) (m (i + 1) (j + 1))
           (p i = 91)
            (: e (: (f k) (? (#p <= k) -1 (p k = 93 && i + 1 < k) k (f (k + 1))) (f (i + 1)))
               (? (e < 0) (? (s j = 91) (m (i + 1) (j + 1)) 0)
                  (: (inset k) (? (e <= k) 0
                                  (k + 2 < e && p (k + 1) = 45) (? (p k <= s j && s j <= p (k + 2)) 1 (inset (k + 3)))
                                  (p k = s j) 1 (inset (k + 1)))
                     (? (inset (i + 1)) (m (e + 1) (j + 1)) 0))))
           (p i = s j) (m (i + 1) (j + 1))
           0)
       (m 0 0))
   ; GNU's quoting: a ' closes and reopens, a : or = after an odd run of \ and ^ is escaped
   (udc-q s)
    (: o (jug 0) n #s
       (go k nb) (? (n <= k) (slurp o)
                    (: c (s k)
                       nb2 (? (c = 39) (say o "'\\'", 1)
                              (c = 92 || c = 94) !nb
                              (c = 58 || c = 61) ((? nb (put o 92) 0), 1)
                              1)
                       _ (put o c)
                       (go (k + 1) nb2)))
       (go 0 1))
   (udc-parse txt nm)                   ; -> [ok [key val]..]
    (: term (: t (getenv "TERM") (? (string? t && 0 < #t) t "none"))
       cterm (: t (getenv "COLORTERM") (? (string? t) t ""))
       ; GNU's line: a keyword to the first blank (a # in it is its own), then the
       ; argument to the next #, its trailing blanks trimmed
       (words l)
        (: n #l
           (sp? j) (j < n && (l j = 32 || l j = 9))
           (skip j) (? (sp? j) (skip (j + 1)) j)
           (tok j) (? (j < n && !(sp? j)) (tok (j + 1)) j)
           (upto j) (? (j < n && !(l j = 35)) (upto (j + 1)) j)
           (trim j a) (? (a < j && (l (j - 1) = 32 || l (j - 1) = 9)) (trim (j - 1) a) j)
           a (skip 0)
           (? (n <= a || l a = 35) ()
              (: e (tok a) b (skip e)
                 (? (n <= b || l b = 35) [(snip l a e)]
                    [(snip l a e) (snip l b (trim (upto b) b))]))))
       (go ls i st ok acc)
        (? (atom? ls) [ok (rev acc)]
           (: ws (words <ls)
              (? (atom? ws) (go >ls (i + 1) st ok acc)
                 (atom? >ws) (say err ("dircolors: " + nm + ":" + show i + ": invalid line;  missing second token\n"), go >ls (i + 1) st 0 acc)
                 (: kw <ws arg <>ws up (udc-up kw)
                    (? (up = "TERM" || up = "COLORTERM")
                        (go >ls (i + 1) (? (udc-glob arg (? (up = "TERM") term cterm)) 'sure (st = 'sure) 'sure 'no) ok acc)
                       (: st2 (? (st = 'sure) 'yes st)
                          (? (st2 = 'no) (go >ls (i + 1) st2 ok acc)
                             (kw 0 = 46) (go >ls (i + 1) st2 ok ([("*" + kw) arg] . acc))
                             (kw 0 = 42) (go >ls (i + 1) st2 ok ([kw arg] . acc))
                             (elem up ["OPTIONS" "COLOR" "EIGHTBIT"]) (go >ls (i + 1) st2 ok acc)
                             (: k (: (f l j) (? (atom? l) -1 (<l = up) j (f >l (j + 1))) (f udc-slack 0))
                                (? (k < 0)
                                   ((? (st2 = 'global) 0 (say err ("dircolors: " + nm + ":" + show i + ": unrecognized keyword " + kw + "\n"))), go >ls (i + 1) st2 (? (st2 = 'global) ok 0) acc)
                                   (go >ls (i + 1) st2 ok ([(udc-ls k) arg] . acc)))))))))))
       (go (lines txt) 1 'global 1 ()))
   (dircolors-main as)
    (: (usage m) (udie 1 ("dircolors: " + m + "\nTry 'dircolors --help' for more information."))
       (go a o)
        (? (atom? a) o
           (: w <a
              (? (elem w ["-b" "--sh" "--bourne-shell"]) (pin o 'sh 'b, go >a o)
                 (elem w ["-c" "--csh" "--c-shell"]) (pin o 'sh 'c, go >a o)
                 (elem w ["-p" "--print-database"]) (pin o 'p 1, go >a o)
                 (w = "--print-ls-colors") (pin o 'l 1, go >a o)
                 (w = "--") (pin o 'fs (o 'fs + >a), o)
                 (1 < #w && w 0 = 45 && !(w = "-")) (usage (? (w 1 = 45) ("unrecognized option '" + w + "'") ("invalid option -- '" + string (w 1) + "'")))
                 (pin o 'fs (o 'fs + [w]), go >a o))))
       o (go as {'fs ()})
       fs (o 'fs)
       _ (? (two? >fs) (usage ("extra operand '" + <>fs + "'")) 0)
       _ (? (o 'p && (o 'sh || o 'l)) (usage "the options to output non shell syntax,\nand to select a shell syntax are mutually exclusive") 0)
       _ (? (o 'p && two? fs) (usage ("extra operand '" + <fs + "'\nfile operands cannot be combined with --print-database (-p)")) 0)
       (? (o 'p) (say out udc-db, flush out, 0)
          (: nm (? (two? fs) <fs "")
             txt (? (atom? fs) udc-db (nm = "-") (slurp in)
                    (: r (uread nm) (? (two? r) <>r (udie 1 ("dircolors: " + nm + ": No such file or directory")))))
             r (udc-parse txt (? (nm = "-") "-" nm))
             sh (? (o 'sh) (o 'sh)
                   (: s (getenv "SHELL") b (? (string? s) (ubase s "") "")
                      (? (b = "csh" || b = "tcsh") 'c 'b)))
             (? !<r (uleave 1)
                (o 'l) (map (\ e (say out ("\e[" + <>e + "m" + <e + "\t" + <>e + "\e[0m\n"))) <>r, flush out, 0)
                (: v (foldl (\ a e (a + udc-q <e + "=" + udc-q <>e + ":")) "" <>r)
                   _ (say out (? (sh = 'c) ("setenv LS_COLORS '" + v + "'\n") ("LS_COLORS='" + v + "';\nexport LS_COLORS\n")))
                   _ (flush out) 0)))))

   ; -- pathchk: would these names work. bare, each is asked of the system as it stands
   ; (a component that is a file, a name past the limits where it does not exist yet);
   ; -p asks POSIX's portable floor instead (the 65 characters, 14 a component, 255 a
   ; name), -P forbids the empty name and a leading '-', --portability is both --
   (upc-oct c) ("\\" + string (48 + c // 64) + string (48 + c // 8 % 8) + string (48 + c % 8))
   (upc-print? c) (31 < c && c < 127)
   (upc-all p s) (: (go k) (? (#s <= k) 1 (p (s k)) (go (k + 1)) 0) (go 0))
   (upc-q s)                            ; GNU's quote(): '..', ".." round a ', $'\ooo' for the rest
    (? (upc-all (\ c (upc-print? c && !(c = 39))) s) ("'" + s + "'")
       (upc-all (\ c (upc-print? c && !(elem c [34 36 92 96]))) s) ("\"" + s + "\"")
       (: n #s
          (go k acc) (? (n <= k) acc
                        (upc-print? (s k) && !(s k = 39)) (go (k + 1) (acc + string (s k)))
                        (: (run j a) (? (j < n && !(upc-print? (s j) && !(s j = 39))) (run (j + 1) (a + upc-oct (s j))) [j a])
                           r (run k "")
                           (go <r (acc + "'$'" + <>r + "''"))))
          t ("'" + go 0 "" + "'")
          (? (2 < #t && snip t (#t - 2) #t = "''") (snip t 0 (#t - 2)) t)))
   (upc-cq c) (? (c = 39) "'\\''" (upc-print? c) ("'" + string c + "'") ("'" + upc-oct c + "'"))
   (upc-f s)                            ; quotef: bare where nothing needs it
    (? (#s && upc-all (\ c (elem c "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._/+,:@%^-")) s) s (upc-q s))
   (pathchk-main as)
    (: (usage m) (udie 1 ("pathchk: " + m + "\nTry 'pathchk --help' for more information."))
       (go a b x)
        (? (atom? a) [b x ()]
           (: w <a n #w
              (? (w = "--") [b x >a]
                 (w = "--portability") (go >a 1 1)
                 (2 < n && snip w 0 2 = "--") (usage ("unrecognized option '" + w + "'"))
                 (1 < n && w 0 = 45)
                  (: (cl k b x) (? (n <= k) (go >a b x)
                                   (w k = 112) (cl (k + 1) 1 x)
                                   (w k = 80) (cl (k + 1) b 1)
                                   (usage ("invalid option -- '" + string (w k) + "'")))
                     (cl 1 b x))
                 [b x a])))
       r (go as 0 0)
       b <r x <>r fs <>>r
       _ (? (two? fs) 0 (usage "missing operand"))
       portable "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-/"
       (no m) (say err ("pathchk: " + m + "\n"), 0)
       (one f)
        (: n #f
           comps (filter (\ c (0 < #c)) (usplit 47 f))
           hy (: (h k) (? (n <= k) 0 (f k = 45 && (k = 0 || f (k - 1) = 47)) 1 (h (k + 1))) (h 0))
           bad (? b (: (p k) (? (n <= k) () (elem (f k) portable) (p (k + 1)) (f k)) (p 0)) ())
           st (? b 'enoent (0 = n) 'enoent (lstat f))
           pmax (? b 256 4096) cmax (? b 14 255)
           long (filter (\ c (cmax < #c)) comps)
           (? (x && hy) (no ("leading '-' in a component of file name " + upc-q f))
              ((b || x) && n = 0) (no "empty file name")
              (charm? bad) (no ("non-portable character " + upc-cq bad + " in file name " + upc-q f))
              (!b && n = 0) (no "'': No such file or directory")
              (!b && nom? st && !(st = 'enoent)) (no (upc-f f + ": " + uerrno st))
              (two? st) 1
              (pmax <= n) (no ("limit " + show (pmax - 1) + " exceeded by length " + show n + " of file name " + upc-q f))
              (two? long) (no ("limit " + show cmax + " exceeded by length " + show #<long + " of file name component " + upc-q <long))
              1))
       ok (foldl (\ a f (? (one f) a 0)) 1 fs)
       _ (flush err)
       (? ok 0 1))

   ; -- mountpoint: is DIR where a filesystem is mounted -- a target in the kernel's
   ; own table (/proc/self/mountinfo) where there is one, else a device that differs
   ; from its parent's. -d says that filesystem's major:minor, -x DEV a block device's
   ; own; 32 for "not", 1 for trouble, util-linux's --
   (ump-unesc s)                        ; mountinfo's \ooo escapes put back
    (: n #s o (jug 0)
       (go k) (? (n <= k) (slurp o)
                 (s k = 92 && k + 3 < n) (put o (((s (k + 1) - 48) * 64) + ((s (k + 2) - 48) * 8) + (s (k + 3) - 48)), go (k + 4))
                 (put o (s k), go (k + 1)))
       (go 0))
   (ump-devno d) (show ((d >> 8) & 4095 | ((d >> 32) & -4096)) + ":" + show ((d & 255) | ((d >> 12) & -256)))
   (mountpoint-main as)
    (: (usage _) (udie 1 "mountpoint: bad usage\nTry 'mountpoint --help' for more information.")
       (go a o)
        (? (atom? a) o
           (: w <a
              (? (w = "--") (pin o 'ops (o 'ops + >a), o)
                 (w = "-q" || w = "--quiet") (pin o 'q 1, go >a o)
                 (w = "-d" || w = "--fs-devno") (pin o 'd 1, go >a o)
                 (w = "-x" || w = "--devno") (pin o 'x 1, go >a o)
                 (w = "--nofollow") (pin o 'nf 1, go >a o)
                 (1 < #w && w 0 = 45) (usage 0)
                 (pin o 'ops (o 'ops + [w]), go >a o))))
       o (go as {'ops ()})
       ops (o 'ops)
       _ (? (two? ops && (atom? >ops)) 0 (usage 0))
       p <ops q (o 'q)
       (say1 s) (? q 0 (say out (s + "\n"), flush out))
       st (? (o 'nf) (lstat p) (stat p))
       _ (? (nom? st) ((? q 0 (say err ("mountpoint: " + p + ": " + uerrno st + "\n"), flush err)), uleave 1) 0)
       (? (o 'x)
          (? ((st 2 & 61440) = 24576) (say1 (ump-devno (st 12)), 0)
             ((? q 0 (say err ("mountpoint: " + p + ": not a block device\n"), flush err)), 32))
          (: c (? (o 'nf) [1 (rl-clean (rl-abs p))] (rp-canon p 40))
             mi (uread "/proc/self/mountinfo")
             hit (? (two? mi && two? c)
                    (foldl (\ h l (: ws (usplit 32 l) (? (4 < #ws && ump-unesc (ws 4) = <>c) (ws 2) h))) () (lines <>mi))
                    (: up (stat (p + "/.."))
                       (? (two? up && (!(st 11 = up 11) || st 8 = up 8)) (ump-devno (st 11)) ())))
             (? (string? hit) (say1 (? (o 'd) hit (p + " is a mountpoint")), 0)
                (say1 (p + " is not a mountpoint"), 32)))))

   ; -- shred: a file overwritten where it lies, -n passes (3) of random bytes and GNU's
   ; patterns in GNU's arrangement, -z a last pass of zeros; the size rounded up to the
   ; file's block unless -x, or -s bytes exactly; each pass forced to the disk. -u then
   ; empties it, renames it down to one character and removes it; -v says each step as
   ; GNU says it. the random bytes are /dev/urandom's --
   ushr-pats '(-2 2 0 4095 2 1365 2730 -1 6 585 1170 1755 2340 2925 3510
               12 273 546 819 1092 1638 1911 2184 2457 3003 3276 3549 3822 -1
               8 4096 4681 5266 5851 6436 7021 7606 8191
               14 4369 4642 4915 5188 5461 5734 6007 6280 6553 6826 7099 7372 7645 7918 -1)
   (ushr-plan num)                      ; -> the passes: -1 random, else a 13-bit pattern
    (: d {}
       (stage1 p n rp k)              ; fills d from 0 -> the random pass count
        (? (n <= 0) rp
           (atom? p) (stage1 ushr-pats n rp k)
           (: v <p
              (? (v < 0) (? (n <= 0 - v) (rp + n) (stage1 >p (n + v) (rp - v) k))
                 (v <= n) (map (\ i (pin d (k + i) (>p i))) ^v, stage1 (drop v >p) (n - v) rp (k + v))
                 (n < 2 || 3 * n < v) (rp + n)
                 (: (pad q n m k) (? (n <= 0) rp
                                     (n = m || rand m < n) (pin d k <q, pad >q (n - 1) (m - 1) (k + 1))
                                     (pad >q n (m - 1) k))
                    (pad >p n v k)))))
       rp (stage1 ushr-pats num 0 0)
       ; the random passes spread evenly, the first and the last among them; the
       ; patterns shuffled into the seats between
       (stage2 n top nx)
        (? (num <= n) ()
           (nx < rp && nx * (num - 1) <= n * (rp - 1))
            (pin d top (peep d n 0), pin d n -1, stage2 (n + 1) (top + 1) (nx + 1))
           (: s (n + rand (top - n)) v (peep d n 0) _ (pin d n (peep d s 0)) _ (pin d s v)
              (stage2 (n + 1) top nx)))
       _ (stage2 0 (num - rp) 0)
       (map (\ i (peep d i -1)) ^num))
   (ushr-fill pat n)                    ; a pattern's bytes, n of them, a bit flipped per 512
    (: bits (pat & 4095) b3 (bits | (bits << 12))
       tri ((string ((b3 >> 4) & 255)) + string ((b3 >> 8) & 255) + string (b3 & 255))
       (rep s) (? (n <= #s) (snip s 0 n) (rep (s + s)))
       s (rep tri)
       (? (pat & 4096) (: c (cask n) _ (map (\ i (pin c i (? (i % 512) (s i) ((s i) ^ 128)))) ^n) (string c)) s))
   (ushr-hex s) (zpad 2 (radix (s 0) 16) + zpad 2 (radix (s 1) 16) + zpad 2 (radix (s 2) 16))
   (shred-main as)
    (: (usage m) (udie 1 ("shred: " + m + "\nTry 'shred --help' for more information."))
       (num w what) (: v (unum w) (? (charm? v && 0 <= v) v (udie 1 ("shred: invalid number of " + what + ": '" + w + "'"))))
       (size w) (: n #w u (? n (w (n - 1)) 0)
                   m (? (u = 75 || u = 107) 1024 (u = 77) 1048576 (u = 71) 1073741824 1)
                   v (unum (? (1 < m) (snip w 0 (n - 1)) w))
                   (? (charm? v && 0 <= v) (v * m) (udie 1 ("shred: invalid file size: '" + w + "'"))))
       (arg o k w a key f)
        (? (k < #w) (pin o key (f (snip w k #w)), [>a])
           (two? >a) (pin o key (f <>a), [>>a])
           (usage ("option requires an argument -- '" + string (w (k - 1)) + "'")))
       (go a o)
        (? (atom? a) o
           (: w <a n #w
              (? (w = "--") (pin o 'fs (o 'fs + >a), o)
                 (elem w ["--force" "--exact" "--verbose" "--zero"])
                  (pin o (w 2 @ 102 'f 101 'x 118 'v 'z) 1, go >a o)
                 (w = "--remove" || w = "-u") (pin o 'u 1, go >a o)
                 (13 < n && snip w 0 13 = "--iterations=") (pin o 'n (num (snip w 13 n) "passes"), go >a o)
                 (7 < n && snip w 0 7 = "--size=") (pin o 's (size (snip w 7 n)), go >a o)
                 (2 < n && snip w 0 2 = "--") (usage ("unrecognized option '" + w + "'"))
                 (1 < n && w 0 = 45)
                  (: (cl k) (? (n <= k) (go >a o)
                               (w k = 110) (go <(arg o (k + 1) w a 'n (\ v (num v "passes"))) o)
                               (w k = 115) (go <(arg o (k + 1) w a 's size) o)
                               (elem (w k) "fxvzu") (pin o (w k @ 102 'f 120 'x 118 'v 122 'z 'u) 1, cl (k + 1))
                               (usage ("invalid option -- '" + string (w k) + "'")))
                     (cl 1))
                 (pin o 'fs (o 'fs + [w]), go >a o))))
       o (go as {'n 3 'fs ()})
       fs (o 'fs)
       _ (? (two? fs) 0 (usage "missing file operand"))
       v? (o 'v)
       (tell m) (? v? (say err ("shred: " + m + "\n"), flush err) 0)
       (no f m) (say err ("shred: " + f + ": " + m + "\n"), flush err, 0)
       rnd (open "/dev/urandom" "r")
       _ (? (nom? rnd) (udie 1 ("shred: /dev/urandom: " + uerrno rnd)) 0)   ; no entropy stops, never zeros
       buf (cask 65536)
       (fillr k) (: g (swig rnd buf) (? (charm? g && 0 < g) (? (k <= g) (snip (string buf) 0 k) ((snip (string buf) 0 g) + fillr (k - g))) (udie 1 "shred: /dev/urandom: read failed")))
       (pass f n pat)                  ; -> 1 | 0, n bytes of the pattern (or random) laid over f
        (: fd (openfd f 4)
           (? (nom? fd) (no f ("failed to open for writing: " + uerrno fd))
              (: p (fdopen fd)
                 blk (? (pat < 0) () (ushr-fill pat (min n 65536)))
                 (go k) (? (n <= k) 1
                           (: m (min 65536 (n - k))
                              _ (say p (? (pat < 0) (fillr m) (m < #blk) (snip blk 0 m) blk))
                              (go (k + m))))
                 _ (go 0)
                 _ (close p)
                 _ (fsync f 1)
                 1)))
       ; -u: the name worn down a character at a time, each a fresh name of 0s (or the
       ; next character GNU tries where that one is taken), then removed
       (rename-down f)
        (: base (ubase f "")
           pre (snip f 0 (#f - #base))
           set "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_."
           (zeros k) (? (k < 1) "" ("0" + zeros (k - 1)))
           (step cur len)
            (? (len < 1) cur
               (: (try i) (? (#set <= i) (step cur (len - 1))
                             (: nm (pre + zeros (len - 1) + string (set i))
                                (? (two? (lstat nm)) (try (i + 1))
                                   (rename cur nm) (step cur (len - 1))
                                   (tell (cur + ": renamed to " + nm), step nm (len - 1)))))
                  (try 0)))
           (step f #base))
       (one f)
        (: st (stat f)
           (? (nom? st) (no f ("failed to open for writing: " + uerrno st))
              (: _ (? ((o 'f) && !(st 2 & 128)) (chmod f ((st 2 & 4095) | 128)) 0)
                 reg ((st 2 & 61440) = 32768)
                 bs (? (13 < #st && 0 < st 13) (st 13) 512)
                 sz (? (charm? (o 's)) (o 's) !reg <st (o 'x) <st ((<st + bs - 1) // bs * bs))
                 plan ((ushr-plan (o 'n)) + (? (o 'z) [0] ()))
                 tot #plan
                 (run l k) (? (atom? l) 1
                              (: pat <l
                                 _ (tell (f + ": pass " + show k + "/" + show tot + " ("
                                          + (? (pat < 0) "random" (ushr-hex (ushr-fill pat 3))) + ")..."))
                                 (? (pass f sz pat) (run >l (k + 1)) 0)))
                 ok (run plan 1)
                 (? !ok 0 !(o 'u) 1
                    (: _ (tell (f + ": removing"))
                       _ (truncate f 0 0)
                       last (rename-down f)
                       e (unlink last)
                       (? (nom? e) (no f ("failed to remove: " + uerrno e))
                          (tell (f + ": removed"), 1)))))))
       ok (foldl (\ a f (? (one f) a 0)) 1 fs)
       (? ok 0 1))

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
        (? (atom? a) [d u q dir (rev fs)]
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
       _ (atom? >fs ? (udie 2 "usage: cmp [-s] A B"))
       ra (uread <fs) rb (uread <>fs)
       (? (atom? ra || atom? rb)
          (!s? ? (say err ("cmp: cannot read " + (two? ra ? <>fs <fs)), put err 10),
             2)
          (<>ra = <>rb) 0
          ((? s? () (say out ((<fs + " ") + (<>fs + " differ")), put out 10, flush out)), 1))))
) ; module 'kore
