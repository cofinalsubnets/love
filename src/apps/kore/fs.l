; src/apps/kore/fs.l -- the fs tools of kore: ls cp mv rm mkdir rmdir ln touch pwd chmod
; truncate. a toolbox dispatched by kore.l, after core.l on the u-floor. an effect op of
; posix.c answers () on success or an errno nom, so !e is the success every loop asks.
; a body-less top-level `:` leaking uoct (lawed in test/law/kore.l) and the mains.
(module 'kore
(borrow 'cli)
(borrow 'cal)
(borrow 'posix)
(borrow 'text)
(borrow 'glob) ; du --exclude

(:
   ; a file destination: into a directory the source's basename lands beside
   (udest src dst) (udirp dst ? (dst + "/" + ubase src "") dst)
   ; copy bytes + permission bits (cp's heart; mv's cross-device leg)
   ; the bytes, by whichever door this love has. kore runs in two worlds and they do not
   ; carry the same nifs: the Makefile bakes this whole cat verbatim (korecat), and a seat
   ; without `copyfile` takes the slurp, the freestanding leg. asked at the call, never bound at the top: the kernel's image is
   ; baked by a host love, so a load-time answer would freeze this world's nif set into
   ; that one's.
   (ucopy-bytes src dst)
    (lit? (cite 'posix 'copyfile) ?
     (charm? (copyfile src dst))
     (uread src @ r
      (two? r ? (open dst "w" @ q
                 (hot? q ? (say q <>r, close q, 1) 0))
       0)))
   ; the stat leads so the two failures stay tellable apart: one errno covers either end,
   ; and `cp: cannot open X` vs `cannot create Y` is the whole diagnostic. it is the same
   ; stat the mode comes from, so it costs nothing it did not already spend.
   ; ucopy1 says its complaint and answers 0, so a tool with many operands carries on;
   ; ucopy leaves with 1 instead
   (usay-err m) (say err m, put err 10, 0)
   (ucopy1 who src dst)
    (stat src @ st
     (? (atom? st) (usay-err (who + ": cannot open " + src))
        !(ucopy-bytes src dst) (usay-err (who + ": cannot create " + dst))
        (chmod dst (4095 & <>>st), 1)))
   (ucopy who src dst) (ucopy1 who src dst ? 1 (uleave 1))
   ; m said on stderr and a line read back: 1 for a y or Y first, else 0 (eof too)
   (uyes m) (: _ (say err m, flush err)
               (line acc) (see in @ c (c < 0 || c = 10 ? (rev acc) (line (c . acc))))
               a (line ())
               (two? a && (<a = 121 || <a = 89) ? 1 0))

   ; -- pwd: where we stand. -P the path with no link in it; -L $PWD, the way the shell
   ; came, when it is absolute, holds no . or .., and is the same directory; the later
   ; of the two wins, and -P unsaid --
   (pwd-main as)
    (: L? (filter (w \ w = "-L" || w = "-P") as @ ws (two? ws ? (<(rev ws) = "-L") 0))
       e (getenv "PWD")
       (same a b) (: x (stat a) y (stat b) (two? x && two? y ? (x 8 = y 8 && ust-at x 11 = ust-at y 11) 0))
       (clean? p) (usplit 47 p @ segs (elem "." segs || elem ".." segs ? 0 1))
       w (L? && string? e && 0 < #e && e 0 = 47 && clean? e && same e "." ? e (cwd ()))
       (say out w, put out 10, flush out, 0))

   ; -- sync: the writeback, scheduled. sync(2) answers nothing and cannot fail.
   ; GNU's takes FILEs and fsyncs each; this one is the bare call only, since the
   ; per-file lane wants an fsync nif and there is none -- taking the operands and
   ; syncing everything instead would be a different thing wearing the same name.
   (sync-main as)
    (two? as ? (udie 1 "sync: takes no operands here (no fsync nif)"), lit? (cite 'posix 'sync) ? (sync 0), 0)

   ; -- mkfifo and mknod: the two rows a /dev wants ------------------------------
   ; mode carries the TYPE bits as well as the permissions, which is mknod(2)'s own
   ; shape: S_IFIFO 4096, S_IFCHR 8192, S_IFBLK 24576.
   ; linux packs a device number wide -- major in bits 8..19 and 44.., minor in 0..7
   ; and 20.. -- so the obvious (major << 8) | minor is right only while both are small.
   (umkdev maj mn)
    ((maj & 4095) << 8 | mn & 255 | (maj >> 12) << 44 | (mn >> 8) << 20)
   ; the seat may carry no mknod (inle, wasm), so the row is probed -- and probed in the
   ; MODULE, which is where posix's names live: the book holds none of them.
   (umknod who p md dev)
    (lit? (cite 'posix 'mknod) ? (mknod p md dev) 'enosys)
   (mkfifo-main as)
    (: t {}
       o (uopt as t '(109) '(101) ())
       _ (two? o ? () (udie 1 "mkfifo: -m wants a mode"))
       _ (uoptbad as t "m" @ c (!c ? () (udie 1 ("mkfifo: unknown option -" + string c))))
       v (uoptv t 109)
       md (string? v ? (uoct v) 438)          ; 0666, the mode mkfifo(1) defaults to
       fs <>>o
       _ (uoptstray as fs @ w (!w ? () (udie 1 ("mkfifo: unknown option " + w))))
       _ (two? fs ? () (udie 1 "usage: mkfifo [-m MODE] NAME.."))
       (go l ok) (atom? l ? ok
                  (umknod "mkfifo" <l (md | 4096) 0 @ e
                   (e ? (say err ("mkfifo: cannot create " + <l + ": " + show e), put err 10),
                    go >l (e ? 0 ok))))
       ok (go fs 1)
       (flush err, ok ? 0 1))
   (mknod-main as)
    (: t {}
       o (uopt as t '(109) '(101) ())
       _ (two? o ? () (udie 1 "mknod: -m wants a mode"))
       _ (uoptbad as t "m" @ c (!c ? () (udie 1 ("mknod: unknown option -" + string c))))
       v (uoptv t 109)
       md (string? v ? (uoct v) 438)
       fs <>>o
       n #fs
       _ (2 <= n ? () (udie 1 "usage: mknod [-m MODE] NAME TYPE [MAJOR MINOR]"))
       nm <fs ty <>fs
       kind (ty @ "p" 4096 "c" 8192 "u" 8192 "b" 24576
                  (udie 1 ("mknod: unknown type " + ty + " (want p, b, c or u)")))
       _ ((kind = 4096) || (4 <= n) ? ()
          (udie 1 "mknod: a block or character node wants MAJOR and MINOR"))
       dev (kind = 4096 ? 0 (umkdev (uatoi (fs 2)) (uatoi (fs 3))))
       e (umknod "mknod" nm (md | kind) dev)
       (e ? (udie 1 ("mknod: cannot create " + nm + ": " + show e)) 0))

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
   ; the long row's clock is UTC. this tree carries no timezone database (see
   ; date's own note), so `ls -l` reads local time only where local time is UTC, and
   ; the gate that compares it to GNU sets TZ for that reason.
   ; colour is automatic and goes only onto a terminal -- (tty 1) answers a pair for
   ; one and 'enotty for anything else, so a pipe keeps the plain name and `ls | grep`
   ; reads what it always read; --color=always|never|auto says otherwise, bare always.
   ;   -h sizes as du -h's   -S by size   -u -c atime or ctime for -t and the row
   ;   -R down every directory, a link never followed   -L the thing a link names
   ;   -F / * @ | = after a name, -p the / alone   -i inode, -s 1K blocks, ahead of it
   ;   -n numeric owners, -g no owner, -o no group -- each of the three a long row
   uls-opts (chars "aACcdFghiLlnoprRsStux1" + [1001])
   ; GNU shows the clock for the last six months and the year outside them. six
   ; months is 31556952/2 -- the average Gregorian year halved, coreutils' own
   ; constant, not 180 days.
   (uls-when s now)
    (: ymd (civil (s // 86400)) secs (s % 86400)
       mo (mon3 (<>ymd - 1))
       d (upad 2 (show <>>ymd))
       ((now - 15778476 <= s) && (s <= now) ?
        (mo + " " + d + " " + zpad 2 (show (secs // 3600))
            + ":" + zpad 2 (show ((secs % 3600) // 60)))
        (mo + " " + d + "  " + show <ymd)))
   ; the sgr a name wears, "" for none. the class is read off the lstat already in
   ; hand; a broken link is the one class that costs a second call, since only the
   ; stat behind the link can miss.
   (uls-hue p md)
    (md & 61440 @ k
     (? (k = 16384) "\e[1;34m"
        (k = 40960) (two? (stat p) ? "\e[36m" "\e[31m")
        (md & 73)   "\e[32m"
        ""))
   (uls-tint s h) (#h ? (h + (s + "\e[0m")) s)
   (uls-name e tty?) (uls-tint <e (tty? ? (uls-hue (e 2) (<>e 2)) ""))
   ; a name as the long row shows it -- a link wears its target, which is why every
   ; stat here is an lstat: ls -l describes the link and not what it points at. the
   ; colour dresses the name alone: the target after the arrow keeps its own text.
   (uls-nom p nm md h)
    (uls-tint nm h @ n
     (40960 = (md & 61440) ?
      (readlink p @ t (string? t ? (n + " -> " + t) n))
      n))
   ; the long row's columns as strings, an owner or group column () when -g or -o drops
   ; it. o: the tablet of flags ls-main read, 'n 'g 'o 'h 'tf 'ind
   (uls-row p nm st now col? o)
    (: (id k f) (charm? (ust-at st k) ? (o 'n ? (show (st k)) (uidname f (st k))) "?")
       [(ust-perm (st 2))
        (charm? (ust-at st 6) ? (show (st 6)) "?")
        (o 'g ? () (id 4 "/etc/passwd"))
        (o 'o ? () (id 5 "/etc/group"))
        (o 'h ? (uhuman <st) (show <st))
        (uls-when (o 'tf st // 1000000000) now)
        (uls-nom p nm (st 2) (col? ? (uls-hue p (st 2)) "") + (o 'ind st p))])
   ; -F's mark after a name (-p's the / alone), "" for none; a long row's link wears its
   ; target and not an @
   (uls-mark F? st long?)
    (61440 & st 2 @ k
     (? (k = 16384) "/" !F? ""
        (k = 40960) (long? ? "" "@") (k = 4096) "|" (k = 49152) "="
        (k = 32768 && 0 < (st 2 & 73)) "*" ""))
   ; the names as a grid. a cell's width is the NAME's and not the coloured text's:
   ; the sgr bytes ride along and take up no screen, and a wide character takes two.
   (uls-grid es tty? w down? pre)
    (: cs (map (e \ ((pre e + uls-name e tty?) . (#(pre e) + swidth <e))) es)
       (go l) (atom? l ? () (say out <l, put out 10, go >l))
       (go (cite 'grid 'lay cs w down?)))
   (uls-wide rs k) (foldl (w \ r \ (#(r k) @ n (w < n ? n w))) 0 rs)
   ; the widths come from `ws` and not from `rs`. GNU sizes the command-line block's
   ; columns over every operand, directories included -- even though a directory
   ; operand is listed further down as a block of its own and its row is never
   ; printed here. `ls -l file dir` pads file's size to the width of dir's, and a
   ; block sizing itself off its own rows silently loses that space.
   (uls-emit rs ws0 pres)               ; the rows, columns aligned the way GNU aligns
    (: wl (uls-wide ws0 1) wu (uls-wide ws0 2) wg (uls-wide ws0 3) ws (uls-wide ws0 4)
       (cell s pad w) (string? s ? (" " + pad w s) "")
       (go l ps) (atom? l ? ()
                  (<l @ r
                   (say out (<ps + <r + cell (r 1) upad wl + cell (r 2) urpad wu
                                + cell (r 3) urpad wg + cell (r 4) upad ws
                                + " " + r 5 + " " + r 6),
                    put out 10,
                    go >l >ps)))
       (go rs pres))
   ; the order: by name, or by mtime newest-first under -t with the name breaking a
   ; tie. -r turns whichever of those around, which is why it is applied last and not
   ; folded into the comparison.
   (uls-sort es key r?)                 ; key: () by name, else a number, biggest first
    (: le (key ? (x \ y \ (: a (key <>x) b (key <>y) (a = b ? (<x <= <y) (b < a))))
           (x \ y \ <x <= <y))
       s (sortby le es)
       (r? ? (rev s) s))
   ; one entry: [name lstat] | () when it cannot be stat'd
   ; one entry: [name stat path] | () when it cannot be stat'd; -L's stat reads through a
   ; link, and a broken one keeps its own
   (uls-ent dir nm L?)
    (: p (#dir ? (dir + "/" + nm) nm)
       st (L? ? (stat p @ s (two? s ? s (lstat p))) (lstat p))
       (two? st ? [nm st p]))
   (vdir-main as) (ls-main ("-l" . as))           ; coreutils' long one
   (ls-main as0)
    (: as (map (w \ (w = "--color" ? "--color=always" w)) as0)
       t {}
       o (uopt as t '(1001) '(101) {"color" 1001})
       _ (two? o ? () (udie 2 "ls: an option wants a value"))
       ops (ustray "ls" as <>>o)
       _ (uoptbad as t uls-opts @ k (!k ? () (udie 2 ("ls: unknown option -- " + string k))))
       a? (peep t 97 0) aa? (peep t 65 0) d? (peep t 100 0)
       r? (peep t 114 0) tm? (peep t 116 0) R? (peep t 82 0) L? (peep t 76 0)
       l? (peep t 108 0 || peep t 110 0 || peep t 103 0 || peep t 111 0)
       c? (peep t 67 0) x? (peep t 120 0) o1? (peep t 49 0)
       i? (peep t 105 0) s? (peep t 115 0) h? (peep t 104 0)
       now (clock 0 // 1000)
       tty? (two? (tty 1))
       cw (uoptv t 1001)
       col? (? (!cw || cw = "auto" || cw = "tty" || cw = "if-tty") tty?
               (cw = "always" || cw = "yes" || cw = "force") 1
               (cw = "never" || cw = "no" || cw = "none") 0
               (udie 2 ("ls: invalid argument '" + cw + "' for '--color'")))
       w (cite 'grid 'screen 1)
       grid? (? l? 0 o1? 0 (x? || c? || tty?) 1 0)
       down? !x?
       (tf st) (? (peep t 117 0) (ust-at st 9) (peep t 99 0) (ust-at st 10) (st 3))
       key (? (peep t 83 0) (st \ <st) tm? tf ())
       F? (peep t 70 0) p? (peep t 112 0)
       o {'n (peep t 110 0) 'g (peep t 103 0) 'o (peep t 111 0) 'h h? 'tf tf
          ; a long row's link wears, under -F, the mark of what it names
          'ind (st \ p \ (F? || p? ? (40960 = 61440 & st 2 ? (stat p @ q (F? && two? q ? (uls-mark F? q 0) ""))
                                      (uls-mark F? st 1)) ""))}
       fs (two? ops ? ops '("."))
       hdr? (two? >fs || R?)
       (blocks st) (ust-at st 7 @ b (charm? b ? b 0))
       (kb st) (h? ? (uhuman (512 * blocks st)) (show ((blocks st + 1) // 2)))
       ; -i and -s ride ahead of a name in every face, padded across the run
       (pres es) (: ws (foldl (m \ e \ max m #(show (ust-at <>e 8))) 0 es)
                    wb (foldl (m \ e \ max m #(kb <>e)) 0 es)
                    (map (e \ ((i? ? (upad ws (show (ust-at <>e 8)) + " ") "") + (s? ? (upad wb (kb <>e) + " ") ""))) es))
       (rows es) (map (e \ uls-row (e 2) <e <>e now col? o) es)
       (name e) (uls-name e col? + (F? || p? ? (uls-mark F? <>e 0) ""))
       (show1 es ws0)                    ; a run of entries: long, gridded, or a name a line
        (: ps (pres es) pt {} _ (each (zip es ps) (q \ pin pt (<q 2) >q))
           (pre e) (peep pt (e 2) "")
           (? l? (uls-emit (rows es) ws0 ps)
              grid? (uls-grid es col? w down? pre)
              (: (go l) (atom? l ? ()
                         (<l @ e (say out (pre e + name e), put out 10, go >l)))
                 (go es))))
       ; a directory's own listing: the entries, with `total` ahead of a long one.
       ; an EMPTY directory still owes its header and its `total 0`, so nothing here
       ; returns early on the empty readdir.
       (dirlist p first ok)
        ; readdir does not hand back . and .. -- it answers the names a walk wants.
        ; `ls -a` owes both, so they are put back here rather than taught to readdir,
        ; where every other caller would then have to take them out again.
        (: ns (readdir p)
           keep (? a? ("." . (".." . ns))
                   aa? ns
                   (filter (n \ !(n 0 = 46)) ns))
           es (filter two? (map (n \ uls-ent p n L?) keep))
           srt (uls-sort es key r?)
           rs (l? ? (rows srt))
           _ (hdr? ? (first ? () (put out 10), say out (p + ":"), put out 10))
           _ (l? || s? ? (foldl (a \ e \ a + blocks <>e) 0 es @ blk
                          (say out ("total " + (h? ? (uhuman (512 * blk)) (show ((blk + 1) // 2)))), put out 10)))
           _ (show1 srt rs)
           ; -R: each directory in the listing, in its order, a link to one not followed
           sub (R? ? (filter (e \ !(<e = "." || <e = "..") && 16384 = 61440 & (<>e 2)) srt))
           (foldl (k \ e \ dirlist (e 2) 0 k) ok sub))
       ; the operands, GNU's way round: the non-directories first as one listing,
       ; then a listing per directory. -d makes every operand a non-directory.
       (miss p) (say err ("ls: cannot access " + p), put err 10, 0)
       bad (filter (p \ atom? (lstat p)) fs)
       good (filter (p \ two? (lstat p)) fs)
       _ (map miss bad)
       plain (d? ? good (filter (p \ !(udirp p)) good))
       dirs (d? ? () (filter udirp good))
       pes (filter two? (map (p \ uls-ent "" p L?) plain))
       aes (filter two? (map (p \ uls-ent "" p L?) good))
       _ (two? pes ? (show1 (uls-sort pes key r?) (rows aes)))
       ; the directory operands go in name order (-r turns them around); -t orders
       ; what is INSIDE a directory and is not claimed over the operands themselves.
       dps (sort dirs @ s (r? ? (rev s) s))
       (walk l first ok) (atom? l ? ok (walk >l 0 (dirlist <l first ok)))
       ok (walk dps (atom? pes) (two? bad ? 0 1))
       ; GNU's ls answers 2 for "cannot access", not 1: 1 is a minor trouble
       ; (an unreadable subdirectory under -R) and 2 is "the operand is not there",
       ; which is the status a script's `ls x || ...` is reading.
       (flush out, ok ? 0 2))

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
       dst (td ? td <fs)
       srcs (td ? ops (rev >fs))
       (? (atom? srcs) (udie 2 ("usage: " + who + " [-" + (who @ "cp" "afinpPLrRuv" "mv" "finuv" "CDgmopsv") + "] [-t DIR] SRC.. DST"))
          ((td || two? >srcs) && !(udirp dst))
           (udie 1 (who + ": target " + dst + " is not a directory"))
          (: ok (foldl (ok \ src \ (each1 src (udest src dst) ? ok 0)) 1 srcs)
             (ok ? 0 1))))
   (cp-main as)
    (: fo (uflags "cp" as '(116) "afinpPLrRtuv")
       t <fo
       a? (t 97)
       r? (a? || t 114 || t 82 ? 1 0)
       p? (a? || t 112 ? 1 0)
       deref? (? (t 76) 1 (a? || r? || t 80) 0 1)
       how (uoptlast as '(102 105 110) '(116) ())
       (said s d) (t 118 ? (say out ("'" + s + "' -> '" + d + "'\n")) 0)
       (kind q) (deref? ? (? (udirp q) 'dir (ukind q) 'file ()) (ukind q))
       ; one thing that is not a directory
       (one1 s d)
        (: k (kind s = 'link ?
              (readlink s @ tg
               (ukind d ? (unlink d) 0,
                (string? tg ? (symlink tg d ? (usay-err ("cp: cannot create " + d)) 1)
                 (usay-err ("cp: cannot read " + s)))))
              (: k (ucopy1 "cp" s d)
                 st (k && p? ? (stat s))
                 (two? st ? (utime d <>st) 0,
                  k)))
           (k ? (said s d) 0,
            k))
       ; -r walks a tree top-down: a directory is laid at the far end and its entries
       ; follow it, its mode after them. a miss inside costs the answer, not the rest
       (tree s d)
        (udirp d ? 0 (mkdir d 493, said s d),
         (!(udirp d) ? (usay-err ("cp: cannot create " + d))
          (: ok (foldl (ok \ nm \ (: sp (s + "/" + nm) dp (d + "/" + nm)
                                     k (? (kind sp = 'dir) (tree sp dp)
                                          (uclob "cp" how (t 117) sp dp) (one1 sp dp)
                                          1)
                                     (k ? ok 0)))
                       1 (readdir s))
             st (stat s)
             (two? st ? (chmod d (4095 & <>>st)) 0,
              p? && two? st ? (utime d <>st) 0,
              ok))))
       (one src dst)
        (kind src @ k
         (? !k (usay-err ("cp: cannot stat " + src))
            (k = 'dir) (r? ? (tree src dst) (usay-err ("cp: -r not given; omitting directory " + src)))
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
                   (e = 'exdev) (ucopy1 "mv" src dst ? (unlink src, 1) 0)  ; the long way
                   (usay-err ("mv: cannot move " + src)))
              (k && t 118 ? (say out ("renamed '" + src + "' -> '" + dst + "'\n")) 0,
               k)))
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
       (ask m) (i? ? (uyes m) 1)
       (gone q m) (t 118 ? (say out (m + " '" + q + "'\n"), 1) 1)
       (rm1 q how e) (!e ? (gone q how) (usay-err ("rm: cannot remove " + q)))
       (zap q)
        (ukind q @ k
         (? !k (f? ? 1 (usay-err ("rm: cannot remove " + q + ": no such file")))
            (k = 'dir)
             (? r? (: ok (foldl (ok \ nm \ (zap (q + "/" + nm) ? ok 0)) 1 (readdir q))
                      (? !(ask ("rm: remove directory '" + q + "'? ")) ok
                         (rm1 q "removed directory" (rmdir q)) ok
                         0))
                (t 100) (ask ("rm: remove directory '" + q + "'? ") ? (rm1 q "removed directory" (rmdir q)) 1)
                (usay-err ("rm: cannot remove " + q + ": is a directory")))
            (ask ("rm: remove '" + q + "'? ") ? (rm1 q "removed" (unlink q)) 1)))
       (one q ok)
        (: b (ubase q "")
           k (? (b = "." || b = "..") (usay-err ("rm: refusing to remove " + q))
                (b = "/") (usay-err "rm: refusing to remove /")
                (zap q))
           (k ? ok 0))
       (? (two? fs) (foldl (ok \ q \ one q ok) 1 fs ? 0 1)
          f? 0
          (udie 2 "usage: rm [-dfirRv] FILE..")))

   ; -- mkdir and rmdir: -p lays every prefix on the way down, or takes it away on the
   ; way up; -m sets the new directory's mode whole, the umask aside --
   (mkdir-main as)
    (: fo (uflags "mkdir" as '(109) "mpv")
       t <fo fs (fo 1)
       p? (t 112)
       mw (uoptv t 109)
       m (mw ? (umode mw 511 1 0))
       _ (!mw || charm? m ? () (udie 1 ("mkdir: invalid mode: '" + mw + "'")))
       (made q) (t 118 ? (say out ("mkdir: created directory '" + q + "'\n")) 0)
       (mk q) (mkdir q 493 @ e (e ? e (made q, ())))
       (mkp q)                          ; a tolerant mkdir at every slash, then the whole
        (: n #q
           (go k) (n <= k ? (mk q)
                   ((0 < k) && (q k = 47) && !(ukind (snip q 0 k)) ? (mk (snip q 0 k)), go (k + 1)))
           (go 1))
       (one q ok)
        ((p? ? (mkp q) (mk q)) @ e
         (!e && charm? m ? (chmod q m) 0,
          (!e || (p? && udirp q) ? ok
           (say err ("mkdir: cannot create " + q), put err 10, 0))))
       (go a ok) (two? a ? (go >a (one <a ok)) (ok ? 0 1))
       (two? fs ? (go fs 1) (udie 2 "usage: mkdir [-pv] [-m MODE] DIR..")))
   (rmdir-main as)
    (: fo (uflags "rmdir" as () "pv")
       t <fo
       (rd q) (rmdir q @ e
               (e ? (usay-err ("rmdir: cannot remove " + q))
                (: _ (t 118 ? (say out ("rmdir: removing directory, '" + q + "'\n")) 0)
                   u (udir q)
                   (t 112 && !(u = "." || u = "/") ? (rd u) 1))))
       (two? (fo 1) ? (foldl (ok \ q \ (rd q ? ok 0)) 1 (fo 1) ? 0 1)
        (udie 2 "usage: rmdir [-pv] DIR..")))

   ; -- ln: two names for one thing (-s the pointing kind, -f moves the old name aside).
   ; TARGET LINK, TARGET alone into here, or TARGET.. DIR; -T never reads the last as a
   ; directory, -n not when it is a link to one --
   (ln-main as)
    (: fo (uflags "ln" as () "fnsTv")
       t <fo ops (fo 1) n #ops
       (dir? d) (? (t 84) 0 (t 110 && ukind d = 'link) 0 (udirp d))
       (mk tg nm)
        (: _ (t 102 && ukind nm && !(ukind nm = 'dir) ? (unlink nm) 0)
           e (t 115 ? (symlink tg nm) (hardlink tg nm))
           (e ? (usay-err ("ln: cannot link " + nm))
            (t 118 ? (say out ("'" + nm + "' -> '" + tg + "'\n")) 0, 1)))
       last (0 < n ? (ops (n - 1)))
       (? (n = 0) (udie 2 "usage: ln [-fnsTv] TARGET [LINK] | ln [-fnsv] TARGET.. DIR")
          (n = 1) (mk <ops (ubase <ops "") ? 0 1)
          (dir? last) (foldl (ok \ tg \ (mk tg (last + "/" + ubase tg "") ? ok 0)) 1 (rev >(rev ops)) ? 0 1)
          (2 < n) (udie 1 ("ln: target " + last + " is not a directory"))
          (mk <ops last ? 0 1)))

   ; -- touch: be there, and be now; -c makes nothing, -r takes a file's time, -d DATE
   ; a given one, as date -d reads it --
   (touch-main as)
    (: fo (uflags "touch" as '(100 114) "cdr")
       t <fo fs (fo 1)
       rf (uoptv t 114)
       dw (uoptv t 100)
       rs (rf ? (stat rf))
       _ (!rf || two? rs ? () (udie 1 ("touch: cannot stat " + rf)))
       ms (? rf <>rs
             dw (udate dw (clock 0) @ v (charm? v ? v (udie 1 ("touch: invalid date format '" + dw + "'"))))
             ())
       (one q ok)
        (: there (two? (stat q))
           _ (there || t 99 ? () (open q "a" @ p (hot? p ? (close p))))
           e (there || !(t 99) ? (utime q ms))
           (!e ? ok (say err ("touch: cannot touch " + q), put err 10, 0)))
       (go a ok) (two? a ? (go >a (one <a ok)) (ok ? 0 1))
       (two? fs ? (go fs 1) (udie 2 "usage: touch [-c] [-r FILE] [-d @SECONDS] FILE..")))

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
                     (cfl? <a) (fl >a (r || has? <a "R" ? 1 0) (f || has? <a "f" ? 1 0))
                     [r f a])
       p (fl as 0 0) r? <p f? <>p rest <>>p
       _ (two? >rest ? () (udie 2 "usage: chmod [-Rf] MODE FILE.."))
       m <rest
       um (umask-now 0)
       _ (charm? (umode m 0 0 um) ? () (udie 1 ("chmod: invalid mode: '" + m + "'")))
       (set q) (stat q @ st
                (atom? st ? (f? ? 0 (usay-err ("chmod: cannot access " + q)))
                 (chmod q (umode m (4095 & <>>st) (16384 = 61440 & <>>st) um) @ e
                  (? !e 1 f? 0 (usay-err ("chmod: cannot chmod " + q))))))
       (tree q ok)
        (set q @ k
         (r? && udirp q ?
          (foldl (o \ nm \ (q + "/" + nm @ p (ukind p = 'link ? o (tree p o)))) (k ? ok 0) (readdir q))
          (k ? ok 0)))
       (foldl (ok \ q \ tree q ok) 1 >rest ? 0 1))

   ; -- install: copy with the mode set in the same breath (what the build's
   ; place-a-file steps say). SRC DST, SRC.. DIR, or -t DIR SRC.., as cp's walk takes
   ; them; -d makes directories (with parents, like -p); -D lays the destination's
   ; parents first; -m MODE sets the mode (755 else), octal or symbolic; -o and -g the
   ; owner and group; -p keeps the source's time; -C leaves a target already the same
   ; bytes and mode alone; -v says each; -s (strip) is accepted and noted -- no
   ; stripper rides kore yet, so the copy keeps its symbol table (a fatter install,
   ; never a wrong one) --
   (imkp q v?)                     ; a tolerant mkdir at every slash (parents only), -v saying each made
    (: n #q
       (mk d) (!(mkdir d 493) && v? ? (say out ("install: creating directory '" + d + "'\n")) 0)
       (go k) (k < n ? ((0 < k) && (q k = 47) ? (mk (snip q 0 k)), go (k + 1)))
       (go 1))
   (install-main as)
    (: fo (uflags "install" as '(109 116 111 103) "CdDgmopstTv")
       t <fo fs (fo 1)
       mw (uoptv t 109)
       m (mw ? (umode mw 0 0 0) 493)
       _ (charm? m ? () (udie 1 ("install: invalid mode '" + mw + "'")))
       own (t 111 || t 103 ? (uowner "install" (t 111 ? (uoptv t 111) "") + (t 103 ? (":" + uoptv t 103) "") ""))
       _ (t 115 ? (say err "install: -s noted, not stripped (no kore stripper yet)", put err 10))
       (owned q) (own ? (chown q <own <>own))
       (same? src dst) (: a (uread src) b (uread dst) sa (stat src) sb (stat dst)
                          (two? a && two? b && two? sb ? (<>a = <>b && (4095 & <>>sb) = m) 0))
       (one src dst)
        (t 67 && same? src dst ? 1
         (: _ (t 68 ? (imkp dst (t 118)))
            k (ucopy1 "install" src dst)
            ((k ? (: _ (chmod dst m) _ (owned dst)
                     st (t 112 ? (stat src))
                     (two? st ? (utime dst <>st) 0,
                      t 118 ? (say out ("'" + src + "' -> '" + dst + "'\n")) 0)) 0),
             k)))
       (? (t 100)
          (: (go a ok)
              (two? a ?
               (: _ (imkp <a (t 118)) e (mkdir <a m)
                  _ (!e && t 118 ? (say out ("install: creating directory '" + <a + "'\n")) 0)
                  ok2 (udirp <a ? (!e ? (chmod <a m, owned <a), ok)
                       (say err ("install: cannot create " + <a), put err 10, 0))
                  (go >a ok2))
               (ok ? 0 1))
             (two? fs ? (go fs 1) (udie 2 "usage: install -d DIR..")))
          (t 84) (atom? >fs ? (udie 2 "usage: install -T SRC DST") (one <fs <>fs ? 0 1))
          (cp-srcs "install" fs (uoptv t 116) one @ r (flush out, r))))

   ; -- readlink: what a symbolic link says (-f chases to an absolute, clean path) --
   (rl-abs q) ((0 < tally q) && (q 0 = 47) ? q (cwd () + "/" + q))
   (rl-clean q)                    ; lexically: no // . .. (.. pops a segment)
    (: n #q
       (seg i st acc) (i < n ?
                       (q i = 47 ?
                        (seg (i + 1) (i + 1) (st < i ? (snip q st i . acc) acc))
                        (seg (i + 1) st acc))
                       (rev (st < i ? (snip q st i . acc) acc)))
       (fold l acc) (? (atom? l) (rev acc)
                       (<l = ".") (fold >l acc)
                       (<l = "..") (fold >l (two? acc ? >acc acc))
                       (fold >l (<l . acc)))
       ("/" + ujoinc 47 (fold (seg 0 0 ()) ())))
   ; -- readlink: a link's target, or with -f -e -m the whole path canonical by
   ; realpath's walk -- -f all but the last name there, -e all of it, -m none; -n no
   ; newline, -z a NUL after each; a failure says nothing and costs the status --
   (readlink-main as)
    (: fo (uflagsl "readlink" as () "efmnqsvz" {"canonicalize" 102 "canonicalize-existing" 101 "canonicalize-missing" 109
                                                 "no-newline" 110 "zero" 122 "quiet" 113 "silent" 115 "verbose" 118})
       t <fo fs (fo 1)
       _ (two? fs ? () (udie 2 "usage: readlink [-efmnz] PATH.."))
       mode (? (t 101) 'e (t 109) 'm (t 102) 'f ())
       end (? (t 122) (string 0) (t 110 && atom? >fs) "" "\n")
       (one q) (!mode ? (readlink q @ r (string? r ? r))
                (rp-canon q 40 @ r
                 (atom? r ? (mode = 'm ? (rl-clean (rl-abs q)))   ; a loop: -m keeps the path
                  (: p <>r want (mode @ 'm () 'e p (udir p))
                     (!want || two? (stat want) ? p)))))
       ok (foldl (ok \ q \ (one q @ r (string? r ? (say out (r + end), ok) 0))) 1 fs)
       (flush out, ok ? 0 1))

   ; -- realpath: a path with every symlink, every . and every .. taken out of it.
   ; the walk resolves component by component, so a last name that does not exist yet
   ; still answers -- GNU's default face. -e wants the whole path to be there, -m
   ; allows any of it to be missing, -s takes the links as they lie --
   (rp-parts p) (filter (w \ 0 < tally w) (usplit 47 p))
   (rp-canon q n)                      ; the resolved path, or () past n links
    (: (walk acc parts d)
        (? (atom? parts) [1 acc]
           (0 = d) ()
           (<parts @ p
            (p @ "." (walk acc >parts d)
                 ".." (walk (rl-clean (acc + "/..")) >parts d)
                 (: cand (acc = "/" ? ("/" + p) (acc + "/" + p))
                    t (readlink cand)
                    (!(string? t) ? (walk cand >parts d)
                     (walk (t 0 = 47 ? "/" acc) (rp-parts t + >parts) (d - 1)))))))
       (walk "/" (rp-parts (rl-abs q)) n))
   ; -q says nothing of a miss, -z ends each with a NUL; -L takes .. before the links
   ; (a/link/.. is a), -P after them, the default; --relative-to=DIR says the answer
   ; from DIR, --relative-base=DIR only for what lies under DIR
   (rp-rel p base)                     ; two canonical paths -> p seen from base
    (: a (rp-parts p) b (rp-parts base)
       (common x y) (two? x && two? y && <x = <y ? (common >x >y) [x y])
       c (common a b)
       ups (map (_ \ "..") <>c)
       r (ups + <c)
       (two? r ? (ujoinc 47 r) "."))
   (realpath-main as)
    (: t {}
       o (uopt as t '(1001 1002) '(101) {"relative-to" 1001 "relative-base" 1002 "quiet" 113 "zero" 122 "logical" 76 "physical" 80
                                        "canonicalize-existing" 101 "canonicalize-missing" 109 "strip" 115 "no-symlinks" 115})
       _ (uoptbad as t (chars "emsqzLP" + [1001 1002]) @ c (!c ? () (udie 1 ("realpath: unknown option -" + string c))))
       fs (ustray "realpath" as <>>o)
       _ (two? fs ? () (udie 1 "usage: realpath [-emqszLP] [--relative-to=DIR] [--relative-base=DIR] PATH.."))
       e? (peep t 101 0) m? (peep t 109 0) s? (peep t 115 0) q? (peep t 113 0) L? (peep t 76 0)
       end (peep t 122 0 ? 0 10)
       (canon q) (s? ? [1 (rl-clean (rl-abs q))] (rp-canon (L? ? (rl-clean (rl-abs q)) q) 40))
       (dir d) (canon d @ r (two? r ? <>r (udie 1 ("realpath: " + d + ": No such file or directory"))))
       rto (peep t 1001 0 ? (dir (uoptv t 1001)))
       rbase (peep t 1002 0 ? (dir (uoptv t 1002)))
       (under? p b) (b = "/" ? 1 (p = b || starts? p (b + "/")))
       (face p) (? (rto && (!rbase || (under? p rbase && under? rto rbase))) (rp-rel p rto)
                   (rbase && under? p rbase) (rp-rel p rbase)
                   p)
       (one q ok)
        (canon q @ r
         (atom? r ?
          (q? ? 0 ((say err ("realpath: " + q + ": too many levels of symbolic links"), put err 10), 0))
          (: p <>r
             want (m? ? () (e? ? p (udir p)))    ; what has to be there to answer
             ((want = ()) || (two? (stat want)) ?
              ((say out (face p), put out end), ok)
              (q? ? 0 ((say err ("realpath: " + q + ": No such file or directory"), put err 10), 0))))))
       (go a ok) (two? a ? (go >a (one <a ok)) (flush out, ok ? 0 1))
       (go fs 1))

   ; -- link and unlink: the two syscalls said plainly, no face on them (ln and rm
   ; are where the faces live) --
   (link-main as0)
    (uflags "link" as0 () "" 1 @ as
     (atom? >as ? (udie 1 "usage: link FILE NEW")
      (hardlink <as <>as @ e
       (!e ? 0 (udie 1 ("link: cannot link " + <>as + " to " + <as))))))
   (unlink-main as0)
    (uflags "unlink" as0 () "" 1 @ as
     (atom? as ? (udie 1 "usage: unlink FILE")
      (unlink <as @ e
       (!e ? 0 (udie 1 ("unlink: cannot unlink " + <as))))))

   ; ---- the reporting tools: stat, du -- and chown, mktemp ---------------------
   ; these read the stat tail. src/love/posix.c's stat answers
   ; (size mtime mode ns uid gid nlink blocks ino), append-only, and the kernel's own
   ; stat (src/inle/kmain.c) answers the first four alone -- an image tree has no ownership
   ; to tell about. so the tail is asked by tally and a world that does not carry it
   ; says so rather than reading a 0 someone might believe.
   (ust-at st k) (#st <= k ? () (st k))
   ; /etc/passwd and /etc/group, read as the files they are (no NSS, no getpwnam)
   (uidname path id)                   ; a numeric id -> its name, or the number back
    (uread path @ r
     (atom? r ? (show id)
      (: (go ls) (atom? ls ? (show id)
                  (usplit 58 <ls @ f
                   (3 <= #f && uatoi (f 2) = id ? (f 0) (go >ls))))
         (go (lines <>r)))))
   (uidof path nm)                     ; a name -> (1 id), or () when the file has none
    (uread path @ r (two? r ?
   (:- (go (lines <>r)) (go ls) (two? ls ? 
    (usplit 58 <ls @ f
     (3 <= #f && f 0 = nm ? [1 (uatoi (f 2))] (go >ls)))))))
   ; every group a user belongs to: the primary first, then the /etc/group rows naming
   ; them, ascending -- which is the order the kernel keeps its credential list in, and
   ; so the order `id` prints
   (ugroups nm gid)
    (: r (uread "/etc/group")
       (go ls acc)
        (atom? ls ? acc
         (: f (usplit 58 <ls)
            g (4 <= tally f ? (uatoi (f 2)) -1)
            ms (4 <= tally f ? (usplit 44 (f 3)))
            (go >ls ((elem nm ms) && !(g = gid) ? (g . acc) acc))))
       rest (two? r ? (sort (go (lines <>r) ())))
       (gid . rest))

   ; -- stat: the file's own facts. bare, it prints GNU's eight-line block; -c FORMAT
   ; (or --printf=, which reads the escapes and adds no newline) asks for named fields:
   ; %n %N %s %b %B %f %a %A %F %u %U %g %G %h %i %m %o %d %D %r %R %t %T %y %Y %x %X
   ; %z %Z %w %W, the \n \t \\ escapes, and %% ; anything else is GNU's bare ?. -L
   ; follows a symbolic link and the bare face does not.
   ; %N is the name shell-quoted, and a link's own target after an arrow. a name the shell
   ; reads as itself goes bare, as GNU's shell-escape style has it; else the quoting is the
   ; shell's: single quotes, '\'' for a quote of its own, $'\t' for a control byte, and
   ; double quotes for a name whose only trouble is the quote. a byte over 127 rides
   ; through -- there is no locale here to tell text from a stray byte, and text is what a
   ; name usually is.
   (ushq-esc c)                        ; the text after the backslash in $'..'
    (c @ 7 "a" 8 "b" 9 "t" 10 "n" 11 "v" 12 "f" 13 "r" (zpad 3 (radix c 8)))
   (ushq-ctl? c) (c < 32 || c = 127)
   ; bare: no shell special anywhere, no # or ~ to start it, and not { or } alone
   (ushq-bare? w)
    (: n #w
       (0 < n && !(any (c \ ushq-ctl? c || elem c '(32 33 34 36 38 39 40 41 42 59 60 61 62 63 91 92 94 96 124)) (map w ^n))
        && !(elem (w 0) '(35 126)) && !(n = 1 && elem (w 0) '(123 125))))
   (ushq w) (? (ushq-bare? w) w (ushq1 w))
   (ushq1 w)
    (: n #w
       (scan k q? hard?)                ; holds a quote? holds anything a "" would escape?
        (n <= k ? [q? hard?]
         (w k @ c
          (scan (k + 1) (q? || c = 39)
                (hard? || (ushq-ctl? c) || elem c '(34 36 92 96)))))
       (sq _) (jug 0 @ o (each ^n (k \ (w k @ c (? (c = 39) (say o "'\\''")
                                                  (ushq-ctl? c) (say o ("'$'\\" + ushq-esc c + "''"))
                                                  (put o c)))),
                          slurp o))
       r (scan 0 0 0)
       (<r && !<>r ? ("\"" + w + "\"") ("'" + sq 0 + "'")))
   (ust-name p md)
    (ushq p @ q
     (!(40960 = md & 61440) ? q
      (readlink p @ t (string? t ? (q + " -> " + ushq t) q))))
   ; a device number is one packed word and linux splits it unevenly: the major's low
   ; twelve bits sit at 8, its high twenty at 32; the minor's low eight at 0 and the
   ; rest at 12. %t/%T print the two in hex, %d/%D and %r/%R the whole word either way.
   (ust-major d) ((d >> 32) & 4294963200 | (d >> 8) & 4095)
   (ust-minor d) ((d >> 12) & 4294967040 | d & 255)
   (ust-mount p)                       ; %m: the mount point the path sits on
    (udf-holds (udf-mounts ()) p @ m (m ? <>m "/"))
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
            + (!s ? (x ? "x" "-") (x ? ch (string (ch 0 - 32))))))
       (ust-kindc m + (tri 6 2048 "s" + (tri 3 1024 "s" + tri 0 512 "t"))))
   (ustamp ns)                         ; %y: 2026-08-17 13:32:41.073610912 +0000
    (: s (ns // 1000000000) frac (ns % 1000000000)
       ymd (civil (s // 86400)) secs (s % 86400)
       (p2 v) (zpad 2 (show v))
       (((show <ymd + "-" + p2 <>ymd + "-" + p2 <>>ymd) + " ")
        + ((p2 (secs // 3600) + ":" + p2 ((secs % 3600) // 60) + ":" + p2 (secs % 60))
           + ("." + zpad 9 (show frac) + " +0000"))))
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
     (num v) (charm? v ? (show v) "?")
     (hex v) (charm? v ? (radix v 16) "?")
     (secs v) (charm? v ? (show (v // 1000000000)) "?")
     (when v) (charm? v ? (ustamp v) "?")
     (go k) (n <= k ? (slurp o) (fmt k @ c (?- (go (k + 2))
    (esc? && c = 92 && k + 1 < n)
     (fmt (k + 1) @ d
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
      87 (say o (birth p L? @ b (charm? b ? (secs b) "0")))
      119 (say o (birth p L? @ b (charm? b ? (ustamp b) "-")))
      100 (say o (num dev))
      68 (say o (hex dev))
      114 (say o (num rdev))
      82 (say o (hex rdev))
      116 (say o (hex (charm? rdev ? (ust-major rdev))))
      84 (say o (hex (charm? rdev ? (ust-minor rdev))))
      111 (say o (num iob))
      109 (say o (ust-mount p))
      67 (say o "?")                  ; the security context: no labels here
      (put o 63))))))                 ; an unknown directive is GNU's bare ?
   ; the default face: GNU's block, line for line. what once refused it was missing
   ; access, change and device -- the stat tuple carries all three now -- and the birth
   ; time, which is statx's own call and answers the dash where a filesystem keeps none.
   ; the widths are GNU's printf: a Links is padded only when a device type follows it,
   ; and the name is %N's, quoted only where the shell needs it.
   (ust-block p st L?)
    (: sz <st md <>>st ns (st 3)
       kind (md & 61440)
       dev (ust-at st 11) rdev (ust-at st 12)
       dev? (kind = 8192 || kind = 24576)
       ; -L followed, so a link's own mode can only be here when it did not: the kind
       ; alone says whether there is an arrow to draw
       (num v) (charm? v ? (show v) "?")
       (idcol id path) ((charm? id ? (uidname path id) "?") @ n
                        (upad 5 (num id) + "/" + upad 8 n))
       (line s) (say out s, put out 10)
       _ (line ("  File: " + ust-name p kind))
       _ (line ("  Size: " + (urpad 10 (show sz)) + string 9
                + "Blocks: " + (urpad 10 (num (ust-at st 7)))
                + " IO Block: " + (urpad 6 (num (ust-at st 13)))
                + " " + (ust-kind md sz)))
       _ (line ("Device: " + (num (charm? dev ? (ust-major dev)))
                + "," + (num (charm? dev ? (ust-minor dev)))
                + string 9 + "Inode: " + (urpad 10 (num (ust-at st 8)))
                + "  Links: " + (dev? ? (urpad 5 (num (ust-at st 6))) (num (ust-at st 6)))
                ; the block spells a device type in DECIMAL; only %t and %T are hex
                + (dev? ? (" Device type: " + num (ust-major rdev)
                           + "," + num (ust-minor rdev)) "")))
       _ (line ("Access: (" + zpad 4 (radix (md & 4095) 8) + "/" + ust-perm md
                + ")  Uid: (" + idcol (ust-at st 4) "/etc/passwd"
                + ")   Gid: (" + idcol (ust-at st 5) "/etc/group" + ")"))
       _ (line ("Access: " + ustamp (ust-at st 9)))
       _ (line ("Modify: " + ustamp ns))
       _ (line ("Change: " + ustamp (ust-at st 10)))
       b (birth p L?)
       (line (" Birth: " + (charm? b ? (ustamp b) "-"))))
   ; -f: the filesystem a path is on, statfs's tuple through a format of its own -- %n
   ; the name, %i the id and %l the longest name, %t the type's magic in hex and %T its
   ; name off the mount list, %s %S the block and fundamental block, %b %f %a the blocks,
   ; free and available, %c %d the inodes and free ones; a - and a width pad a field
   ufs-face "    ID: %-8i Namelen: %-7l Type: %T\nBlock size: %-10s Fundamental block size: %S\nBlocks: Total: %-10b Free: %-10f Available: %a\nInodes: Total: %-10c Free: %d\n"
   (ufs-expand fmt p r)
    (: n #fmt o (jug 0)
       ty (udf-holds (udf-mounts ()) p @ m (two? m ? (m 2) "?"))
       (at k) ((k < #r ? (r k)) @ v (charm? v ? v 0))
       (cell c) (c @ 110 p 105 (radix (at 7) 16 + zpad 8 (radix (at 8) 16)) 108 (show (at 9)) 116 (radix (at 10) 16) 84 ty
                    115 (show (at 0)) 83 (show (at 6)) 98 (show (at 1)) 102 (show (at 2)) 97 (show (at 3))
                    99 (show (at 4)) 100 (show (at 5)) 37 "%" ("?"))
       (go k) (? (n <= k) (slurp o)
                 (!(fmt k = 37) || n <= k + 1) (put o (fmt k), go (k + 1))
                 (: left (fmt (k + 1) = 45) j0 (left ? (k + 2) (k + 1))
                    (dg j) (j < n && 48 <= fmt j <= 57 ? (dg (j + 1)) j)
                    j (dg j0) w (j0 < j ? (uatoi (snip fmt j0 j)) 0)
                    v (j < n ? (cell (fmt j)) "")
                    (say o (? (w <= #v) v left (urpad w v) (upad w v)),
                     go (j + 1))))
       (go 0))
   (stat-main as)
    (: fsm {'f 0}
       (fl a fmt L pf fs)
        (atom? a ? [fmt L pf (rev fs)]
         (<a @ "-L" (fl >a fmt 1 pf fs)
               ("-f" || "--file-system") (pin fsm 'f 1, fl >a fmt L pf fs)
               "-c" (two? >a ? (fl >>a <>a L 0 fs) (udie 2 "stat: -c wants a format"))
               ("-c" + f) (fl >a f L 0 fs)
               ("--format=" + (f && 0 < #f)) (fl >a f L 0 fs)
               ("--printf=" + (f && 0 < #f)) (fl >a f L 1 fs)
               (fl >a fmt L pf (<a . fs))))
       p (fl as () 0 0 ())
       fmt <p L? <>p pf? <>>p fs (ustray "stat" as (p 3))
       _ (two? fs ? () (udie 2 "usage: stat [-L] [-c FORMAT | --printf=FORMAT] FILE.."))
       (one q ok)
        ((? (fsm 'f) (statfs q) L? (stat q) (lstat q)) @ st
         (? (atom? st) (say err ("stat: cannot read file system information for '" + q + "': No such file or directory\n"), 0)
            (fsm 'f) (say out (string? fmt ? (ufs-expand (fmt + (pf? ? "" "\n")) q st)
                                 ("  File: " + ushq q + "\n" + ufs-expand ufs-face q st)), ok)
            0))
       (one0 q ok)
        ((L? ? (stat q) (lstat q)) @ st
         (? (atom? st)
            (say err ("stat: cannot stat '" + q + "': No such file or directory\n"), 0)
            (string? fmt) (say out (ust-expand fmt q st pf? L?), pf? || put out 10, ok)
            (ust-block q st L?, ok)))
       (go a ok) (two? a ? (go >a ((fsm 'f ? one one0) <a ok)) (flush out, !ok))
       (go fs 1))

   ; -- du: what a tree costs on the disk. the count is st_blocks (512 each), which is
   ; allocation and not size -- a sparse file costs less than it measures and a tiny one
   ; costs a whole block -- and the report is in 1K units, rounded up, unless -b asks for
   ; apparent bytes or -h for the three-figure human face. -a counts files too, -s only
   ; the totals, -c a grand total, -d N stops descending. a hard link is counted once
   ; per run, keyed by inode alone: this stat carries no device, so a walk crossing two
   ; filesystems could collide two inodes -- rare, and named here rather than hidden.
   ; the walk sorts each directory, like find's, so the same tree reports twice alike.
   (uhuman n) (uhumanb n 0)             ; GNU's -h: three significant figures, rounded up
   ; the same in powers of 1000 when si? (-H, --si), kilo spelled k as GNU's spells it
   (uhumanb n si?)
    (: units (si? ? '("k" "M" "G" "T" "P") '("K" "M" "G" "T" "P"))
       (pow k) (si? ? ((3 * k) 10) ((10 * k) 2))      ; n x is x ** n
       (pick k) (4 < k || n < pow (k + 1) ? k (pick (k + 1)))
       k (n < pow 1 ? 0 (pick 1))
       d (pow k)
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
        (<a = "--") [t (rev fs + >a)]
        ; GNU's long names, onto the same keys the letters take
        (<a 1 = 45)
         (: w <a
            (long p) (#p @ n (n < #w && snip w 0 n = p))
            (? (long "--max-depth=") (pin t 'd (uatoi (snip w 12 #w)), fl >a t fs)
               (long "--exclude=") (pin t 'ex (snip w 10 #w), fl >a t fs)
               (w = "--all") (pin t 'a 1, fl >a t fs)
               (w = "--summarize") (pin t 's 1, fl >a t fs)
               (w = "--total") (pin t 'c 1, fl >a t fs)
               (w = "--bytes") (pin t 'b 1, fl >a t fs)
               (w = "--apparent-size") (pin t 'ap 1, fl >a t fs)
               (w = "--human-readable") (pin t 'h 1, fl >a t fs)
               (w = "--one-file-system") (pin t 'x 1, fl >a t fs)
               (w = "--dereference") (pin t 'L 1, fl >a t fs)
               (w = "--null") (pin t 'z 1, fl >a t fs)
               (udie 2 ("du: unknown option " + w))))
        (:- (cl 1) w <a (cl k) (#w <= k ? (fl >a t fs) (w k @
         97 (pin t 'a 1, cl (k + 1))
         115 (pin t 's 1, cl (k + 1))
         99 (pin t 'c 1, cl (k + 1))
         98 (pin t 'b 1, cl (k + 1))
         104 (pin t 'h 1, cl (k + 1))
         107 (cl (k + 1))       ; -k is the default
         120 (pin t 'x 1, cl (k + 1))
         76 (pin t 'L 1, cl (k + 1))
         48 (pin t 'z 1, cl (k + 1))
         100 (pin t 'd (uatoi (snip w (k + 1) #w)), fl >a t fs)
         c (udie 2 $ "du: unknown option -" + string c)))))
       t {}
       p (fl as t ())
       fs (two? <>p ? <>p '("."))
       a? (t 'a) s? (t 's) c? (t 'c)
       b? (t 'b) h? (t 'h) maxd (t 'd)
       ; --apparent-size counts as -b does and still says K; -x keeps to the first
       ; operand's device, -L stats through links, --exclude drops a name by its glob
       ap? (b? || t 'ap) x? (t 'x) L? (t 'L) ex (t 'ex)
       seen {}
       (fmt n) (h? ? (uhuman n) (b? ? (show n) (show $ (n + 1023) // 1024)))
       (emit n q) (say out (fmt n), put out 9, say out q, put out (t 'z ? 0 10))
       ; -b's apparent size counts a file's st_size and a directory's not at all --
       ; GNU's rule, and not a guess: an empty directory whose st_size is 40 reports 0.
       (own st dir?)
        (: nlk (ust-at st 6) ino (ust-at st 8)
           ct (ap? ? (dir? ? 0 <st) (512 * (charm? (ust-at st 7) ? (ust-at st 7) 0)))
           ((charm? nlk) && (1 < nlk) || L? ?
            (peep seen ino 0 ? 0 (pin seen ino 1, ct))
            ct))
       ; a directory is counted once however it is reached -- under -L a link can reach
       ; one twice, and GNU's says it where it met it first
       (again? st) ([(ust-at st 11) (ust-at st 8)] @ k (peep seen k 0 ? 1 (pin seen k 1, 0)))
       (walk q depth top?)
        ((L? ? (stat q @ s (two? s ? s (lstat q))) (lstat q)) @ st
         (top? ? (pin t 'dev (ust-at st 11)) 0,
          (atom? st ?  (say err ("du: cannot access '" + q + "'\n"), pin t 'bad 1, 0)
           (: dir? (16384 = 61440 & <>>st)
              in? (!x? || ust-at st 11 = t 'dev)
              dup? (dir? && again? st)
              kids (?- 0 (dir? && in? && !dup?)
                    (foldl (acc \ c \ (ex && match ex c ? acc (acc + walk (q + "/" + c) (depth + 1) 0))) 0 (sort (readdir q))))
              tot (dup? ? 0 (own st dir? + kids))
              deep? (charm? maxd && maxd < depth)
              ((dir? || a? || top?) && !s? && !deep? && !dup? && emit tot q,
               tot)))))
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
       (oct? c) (47 < c && c < 56)
       (go k) (n <= k ? (slurp o)
               (: a (k + 3 < n && w k = 92 ? (w (k + 1)) 0)
                  b (a ? (w (k + 2)) 0) c (a ? (w (k + 3)) 0)
                  ((oct? a) && (oct? b) && (oct? c) ?
                   (put o (((a - 48) * 64 + (b - 48) * 8) + (c - 48)), go (k + 4))
                   (put o (w k), go (k + 1)))))
       (go 0))
   (udf-mounts _)                      ; ((dev point)..) in the kernel's order, or ()
    (: r (uread "/proc/self/mounts")
       (go l acc) (atom? l ? (rev acc)
                   (words <l @ w
                    (go >l (3 <= #w ? ([(udf-esc (w 0)) (udf-esc (w 1)) (w 2)] . acc) acc))))
       (two? r ? (go (filter (s \ #s) (lines <>r)) ())))
   ; the mount a path sits on: the LONGEST point its resolved name starts with, so a
   ; bind mount names itself and not the twin it shares a device with. stat's %m asks
   ; this too, which is why it is here and not inside df's own walk.
   (udf-holds ms p)
    (: c (rp-canon p 40 @ q (two? q ? <>q p))
       (fits m) (: pt <>m n #pt
                   ((snip c 0 n = pt) && (n = #c || pt = "/" || (c n = 47))))
       (foldl (b \ m \ ((fits m) && (!b || #<>b < #<>m) ? m b)) () ms))
   (udf-up a b) (b <= 0 ? 0 ((a + b - 1) // b))
   (udf-pct u a) ((u + a) <= 0 ? "-" (show (udf-up (u * 100) (u + a)) + "%"))
   (udf-cells dev pt fs h? i?)         ; a statfs tuple -> the six cells of its row
    (: bs (fs 0) blk (fs 1) fre (fs 2) av (fs 3) ino (fs 4) ifr (fs 5)
       frs (fs 6 @ f ((charm? f) && (0 < f) ? f bs))
       (sz n) (h? ? (uhumanb (n * frs) (h? = 'si)) (show (udf-up (n * frs) 1024)))
       (i? ? [dev (show ino) (show (ino - ifr)) (show ifr) (udf-pct (ino - ifr) ifr) pt]
        [dev (sz blk) (sz (blk - fre)) (sz av) (udf-pct (blk - fre) av) pt]))
   ; the table: every column as wide as its widest cell but never under the floor below,
   ; one space between, the ends ragged -- the first column reads left and the last is
   ; never padded at all. the floors are GNU's, and they are why a table of short names
   ; still lines up with one of long ones.
   udf-min '(14 5 5 5 4 0)
   (udf-show rows mins lefts)           ; lefts: the columns that read left
    (: n #<rows
       ws (map (k \ foldl (w \ r \ (#(r k) @ c (w < c ? c w))) (mins k) rows) ^n)
       (line r) (foldl (\ acc k (: s (r k)
                                     p (? (k + 1 = n) s (elem k lefts) (urpad (ws k) s) (upad (ws k) s))
                                     (k ? (acc + " " + p) p)))
                       "" ^n)
       (go rs) (two? rs ? (say out (line <rs), put out 10, go >rs) 0)
       (go rows))
   ; -T wears each mount's type after its name, -t TYPE takes only those types and -x
   ; TYPE leaves those out, each as many times as said; -H is -h in powers of 1000
   (df-main as)
    (: t {'t () 'x ()}
       (val a k fs) (two? >a ? (pin t k (<>a . t k), fl >>a fs) (udie 2 "df: an option wants a type"))
       (fl a fs) (atom? a ? (rev fs)
                  (<a @ "--" (rev fs + >a)
                    ("-t" || "-x") (val a (<a = "-t" ? 't 'x) fs)
                    ("-T" || "--print-type") (pin t 'T 1, fl >a fs)
                    ("-H" || "--si") (pin t 'h 'si, fl >a fs)
                    ("-t" + v) (pin t 't (v . t 't), fl >a fs)
                    ("-x" + v) (pin t 'x (v . t 'x), fl >a fs)
                    ("--type=" + (v && 0 < #v)) (pin t 't (v . t 't), fl >a fs)
                    ("--exclude-type=" + (v && 0 < #v)) (pin t 'x (v . t 'x), fl >a fs)
                    (? (#<a < 2 || <a 0 != 45)) (fl >a (<a . fs))
                    (:- (cl 1) w <a (cl k) (#w <= k ? (fl >a fs) (w k @
                     104 (pin t 'h (t 'h = 'si ? 'si 1), cl (k + 1))
                     84 (pin t 'T 1, cl (k + 1))
                     72 (pin t 'h 'si, cl (k + 1))
                     105 (pin t 'i 1, cl (k + 1))
                     97 (pin t 'a 1, cl (k + 1))
                     107 (cl (k + 1))   ; -k is the default, and -P names this very face
                     80 (cl (k + 1))    ; (posix's, and the only one laid out here)
                     c (udie 2 $ "df: unknown option -" + string c))))))
       fs (fl as ())
       h? (t 'h) i? (t 'i) a? (t 'a) T? (t 'T)
       hdr0 (? i? '("Filesystem" "Inodes" "IUsed" "IFree" "IUse%" "Mounted on")
               h? '("Filesystem" "Size" "Used" "Avail" "Use%" "Mounted on")
               '("Filesystem" "1K-blocks" "Used" "Available" "Use%" "Mounted on"))
       ; -T's column rides second
       (typed ty r) (T? ? (<r . ty . >r) r)
       hdr (typed "Type" hdr0)
       mins (T? ? '(14 4 5 5 5 4 0) udf-min)
       (keep? ty) (? (two? (t 't)) (elem ty (t 't)) (two? (t 'x)) !(elem ty (t 'x)) 1)
       ms (filter (m \ keep? (m 2)) (udf-mounts ()))
       _ ((two? fs) || (two? ms) ? () (udie 1 "df: cannot read /proc/self/mounts"))
       (named p acc)
        (statfs p @ r
         (two? r ? (udf-holds ms p @ m (atom? m ? acc ((typed (m 2) (udf-cells <m <>m r h? i?)) . acc)))
          (say err ("df: " + p + ": "
                         + (r = 'eacces ? "Permission denied" "No such file or directory")), put err 10, pin t 'bad 1, acc)))
       ; a filesystem the call refuses or cannot find (a mount someone else owns) is
       ; dropped from the bare face and kept by -a, its figures dashed -- a row of zeroes
       ; would read as an answer. any other failure (a dead fuse mount) is said and dropped.
       (scan mm acc)
        (atom? mm ? acc
         (: m <mm r (statfs <>m)
            (scan >mm (? (two? r) (a? || (r 1) ? ((typed (m 2) (udf-cells <m <>m r h? i?)) . acc) acc)
                         (r = 'eacces || r = 'enoent) (a? ? ((typed (m 2) [<m "-" "-" "-" "-" <>m]) . acc) acc)
                         (say err ("df: " + <>m + ": " + uerrno r), put err 10, pin t 'bad 1, acc)))))
       rows (rev (two? fs ? (foldl (a \ p \ named p a) () fs) (scan ms ())))
       (two? rows ? (udf-show (hdr . rows) mins (T? ? '(0 1) '(0))),
        flush out,
        !!(peep t 'bad 0)))

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
   ; -R goes down a tree, a directory after what is in it, changing a link found on the
   ; way itself and never what it names; -h does the same for an operand; -v says each, -c only those it changed; --reference=FILE takes
   ; FILE's owner and group, every operand then a file
   (uchown who as)
    (: fo (uflagsl who as '(1001) (chars "chRv" + [1001 102]) {"reference" 1001 "no-dereference" 104 "changes" 99 "verbose" 118
                                                        "recursive" 82 "silent" 102 "quiet" 102})
       t <fo r? (t 82) rest (fo 1)
       grp? (who = "chgrp")
       rf (uoptv t 1001)
       rs (rf ? (stat rf))
       _ (!rf || two? rs ? 0 (udie 1 (who + ": failed to get attributes of '" + rf + "'")))
       _ ((rf && atom? rest) || (!rf && atom? >rest) ? (udie 2 ("usage: " + who + " [-chRv] " + (grp? ? "GROUP" "OWNER[:GROUP]") + " FILE.. | " + who + " --reference=RFILE FILE..")) 0)
       ug (? rf [(grp? ? -1 (rs 4)) (rs 5)] grp? (uowner who (":" + <rest) <rest) (uowner who <rest <rest))
       files (rf ? rest >rest)
       uid <ug gid <>ug
       (nm path id) (charm? id ? (uidname path id) "?")
       (face st) (grp? ? (nm "/etc/group" (st 5)) (nm "/etc/passwd" (st 4) + ":" + nm "/etc/group" (st 5)))
       (one q ok top?)
        (: k (ukind q)
           kids (r? && k = 'dir ? (foldl (acc \ c \ one (q + "/" + c) acc 0) ok (readdir q)) ok)
           (one1 q kids (!top? || t 104)))
       (one1 q ok own?)
        (: lk? (own? && ukind q = 'link)
           before (lk? ? (lstat q) (stat q))
           e (lk? ? (lchown q uid gid) (chown q uid gid))
           after (lk? ? (lstat q) (stat q))
           ((!e && two? before && two? after && (t 118 || t 99) ?
             (: a (face before) b (face after)
                (? (!(a = b)) (say out ("changed " + (grp? ? "group" "ownership") + " of '" + q + "' from " + a + " to " + b + "\n"))
                   (t 118) (say out ((grp? ? "group" "ownership") + " of '" + q + "' retained as " + b + "\n"))
                   0))
             0),
            !e ? ok (? (t 102) 0 (say err (who + (grp? ? ": cannot change group of '" ": cannot chown '") + q + "'\n")), 0)))
       (go a ok) (two? a ? (go >a (one <a ok 1)) (flush out, !ok))
       (go files 1))
   (chown-main as) (uchown "chown" as)
   (chgrp-main as) (uchown "chgrp" as)

   ; -- truncate: each file cut or stretched to a size. -s [+-<>/%]N with GNU's suffixes
   ; (grow by, shrink by, at most, at least, down or up to a multiple), -r a file whose
   ; size is the start, -o the count in the file's own blocks, -c make no file --
   (utrunc-n w)
    (: n #w (dend k) (k < n && 47 < w k < 58 ? (dend (k + 1)) k)
       e (dend 0) v (0 < e ? (unum (snip w 0 e)))
       sf (snip w e n)
       m (sf = "" ? 1 (filter (p \ <p = sf) uclip-sfx @ r (two? r ? <>(<r))))
       (charm? v && charm? m ? (v * m) (udie 1 ("truncate: Invalid number: '" + w + "'"))))
   (truncate-main as)
    (: t {}
       (val w k a f) (? (k < #w) (pin t f (snip w k #w), go a)
                        (two? a) (pin t f <a, go >a)
                        (udie 1 ("truncate: option requires an argument -- '" + string (w (k - 1)) + "'")))
       (go a)
        (atom? a ? ()
         (: w <a n #w
            (w @ "--" >a
               "--no-create" (pin t 'c 1, go >a)
               "--io-blocks" (pin t 'o 1, go >a)
               ("--size" || "--reference")
                (two? >a ? (pin t (w 2 = 115 ? 's 'r) <>a, go >>a)
                 (udie 1 ("truncate: option '" + w + "' requires an argument")))
               ("--size=" + (v && 0 < #v)) (pin t 's v, go >a)
               ("--reference=" + (v && 0 < #v)) (pin t 'r v, go >a)
               (? (1 < n && w 0 = 45 && !(w 1 = 45)))
                (: (cl k) (n <= k ? (go >a)
                           (w k @ c
                            (c @ 99 (pin t 'c 1, cl (k + 1))
                                 111 (pin t 'o 1, cl (k + 1))
                                 115 (val w (k + 1) >a 's)
                                 114 (val w (k + 1) >a 'r)
                                 (udie 1 ("truncate: invalid option -- '" + string c + "'\nTry 'truncate --help' for more information.")))))
                   (cl 1))
               (1 < n && w 0 = 45) (udie 1 ("truncate: unrecognized option '" + w + "'\nTry 'truncate --help' for more information."))
               (w . (go >a)))))
       fs (go as)
       sz (t 's) rf (t 'r)
       op (sz ? ((0 < #sz ? (sz 0) 0) @ c (elem c [43 45 60 62 47 37] ? c 0)) 0)
       num (sz ? (utrunc-n (op = 0 ? sz (snip sz 1 #sz))) 0)
       try "\nTry 'truncate --help' for more information."
       _ (!sz && !rf ? (udie 1 ("truncate: you must specify either '--size' or '--reference'" + try)) 0)
       _ (rf && sz && op = 0 ? (udie 1 ("truncate: you must specify a relative '--size' with '--reference'" + try)) 0)
       _ ((t 'o) && !sz ? (udie 1 ("truncate: '--io-blocks' was specified but '--size' was not" + try)) 0)
       _ (two? fs ? 0 (udie 1 ("truncate: missing file operand" + try)))
       _ ((op = 47 || op = 37) && num = 0 ? (udie 1 "truncate: division by zero") 0)
       rsz (rf ? (stat rf @ st (two? st ? <st (udie 1 ("truncate: cannot stat '" + rf + "': " + uerrno st)))) 0)
       (fail f e) (say err ("truncate: cannot open '" + f + "' for writing: " + uerrno e + "\n"), 1)
       (one f)
        (: st0 (stat f)
           mk (t 'c ? 0 1)
           e0 ((atom? st0) && t 'o && mk ? (truncate f 0 1))
           st (two? st0 ? st0 (stat f))
           (? ((atom? st0) && t 'c) 0
              (nom? e0) (fail f e0)
              (: bs (two? st && 13 < #st ? (st 13) 512)
                 n (t 'o ? (num * bs) num)
                 base (? rf rsz (two? st) <st 0)
                 want (? !sz rsz (op = 0) n (op = 43) (base + n) (op = 45) (max 0 (base - n))
                         (op = 60) (min base n) (op = 62) (max base n)
                         (op = 47) (base // n * n) ((base + n - 1) // n * n))
                 e (truncate f want mk)
                 (nom? e ? (fail f e) 0))))
       r (foldl (a \ f \ max a (one f)) 0 fs)
       (flush err,
        r))

   ; -- fsync: what the kernel holds of each file written down (-d fdatasync's lesser
   ; promise, the file's data alone) --
   (fsync-main as)
    (: fo (uflags "fsync" as () "d")
       d? (<fo 100) fs (fo 1)
       ok (foldl (a \ f \ (fsync f d? @ e
                           (nom? e ? (say err ("fsync: " + f + ": " + uerrno e + "\n"), 0) a)))
                 1 fs)
       (flush err,
        ok ? 0 1))

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
   (udc-up s) (jug 0 @ o (map (c \ put o (96 < c && c < 123 ? (c - 32) c)) (map s ^#s), slurp o))
   ; fnmatch's three, enough for the database's globs: * ? and a [set]
   (udc-glob p s)
    (: (m i j)
        (? (#p <= i) (#s <= j)
           (p i = 42) (: (any k) (? (m (i + 1) k) 1 (k < #s) (any (k + 1)) 0) (any j))
           (#s <= j) 0
           (p i = 63) (m (i + 1) (j + 1))
           (p i = 91)
            ((: (f k) (? (#p <= k) -1 (p k = 93 && i + 1 < k) k (f (k + 1))) (f (i + 1))) @ e
             (e < 0 ? (s j = 91 ? (m (i + 1) (j + 1)) 0)
              (: (inset k) (? (e <= k) 0
                              (k + 2 < e && p (k + 1) = 45) (p k <= s j && s j <= p (k + 2) ? 1 (inset (k + 3)))
                              (p k = s j) 1 (inset (k + 1)))
                 (inset (i + 1) ? (m (e + 1) (j + 1)) 0))))
           (p i = s j) (m (i + 1) (j + 1))
           0)
       (m 0 0))
   ; GNU's quoting: a ' closes and reopens, a : or = after an odd run of \ and ^ is escaped
   (udc-q s)
    (: o (jug 0) n #s
       (foldl (\ nb k (: c (s k)
                         nb2 (? (c = 39) (say o "'\\'", 1)
                                (c = 92 || c = 94) !nb
                                (c = 58 || c = 61) (nb ? (put o 92) 0, 1)
                                1)
                         (put o c, nb2)))
              1 ^n,
        slurp o))
   (udc-parse txt nm)                   ; -> [ok [key val]..]
    (: term (getenv "TERM" @ t (string? t && 0 < #t ? t "none"))
       cterm (getenv "COLORTERM" @ t (string? t ? t ""))
       ; GNU's line: a keyword to the first blank (a # in it is its own), then the
       ; argument to the next #, its trailing blanks trimmed
       (words l)
        (: n #l
           (sp? j) (j < n && (l j = 32 || l j = 9))
           (skip j) (sp? j ? (skip (j + 1)) j)
           (tok j) (j < n && !(sp? j) ? (tok (j + 1)) j)
           (upto j) (j < n && !(l j = 35) ? (upto (j + 1)) j)
           (trim j a) (a < j && (l (j - 1) = 32 || l (j - 1) = 9) ? (trim (j - 1) a) j)
           a (skip 0)
           (n <= a || l a = 35 ? ()
            (: e (tok a) b (skip e)
               (n <= b || l b = 35 ? [(snip l a e)]
                [(snip l a e) (snip l b (trim (upto b) b))]))))
       (go ls i st ok acc)
        (atom? ls ? [ok (rev acc)]
         (words <ls @ ws
          (? (atom? ws) (go >ls (i + 1) st ok acc)
             (atom? >ws) (say err ("dircolors: " + nm + ":" + show i + ": invalid line;  missing second token\n"), go >ls (i + 1) st 0 acc)
             (: kw <ws arg <>ws up (udc-up kw)
                (up = "TERM" || up = "COLORTERM" ?
                 (go >ls (i + 1) (? (udc-glob arg (up = "TERM" ? term cterm)) 'sure (st = 'sure) 'sure 'no) ok acc)
                 ((st = 'sure ? 'yes st) @ st2
                  (? (st2 = 'no) (go >ls (i + 1) st2 ok acc)
                     (kw 0 = 46) (go >ls (i + 1) st2 ok ([("*" + kw) arg] . acc))
                     (kw 0 = 42) (go >ls (i + 1) st2 ok ([kw arg] . acc))
                     (elem up ["OPTIONS" "COLOR" "EIGHTBIT"]) (go >ls (i + 1) st2 ok acc)
                     ((: (f l j) (? (atom? l) -1 (<l = up) j (f >l (j + 1))) (f udc-slack 0)) @ k
                      (k < 0 ?
                       (st2 = 'global ? 0 (say err ("dircolors: " + nm + ":" + show i + ": unrecognized keyword " + kw + "\n")), go >ls (i + 1) st2 (st2 = 'global ? ok 0) acc)
                       (go >ls (i + 1) st2 ok ([(udc-ls k) arg] . acc)))))))))))
       (go (lines txt) 1 'global 1 ()))
   (dircolors-main as)
    (: (usage m) (udie 1 ("dircolors: " + m + "\nTry 'dircolors --help' for more information."))
       (go a o)
        (atom? a ? o
         (<a @ w
          (? (elem w ["-b" "--sh" "--bourne-shell"]) (pin o 'sh 'b, go >a o)
             (elem w ["-c" "--csh" "--c-shell"]) (pin o 'sh 'c, go >a o)
             (elem w ["-p" "--print-database"]) (pin o 'p 1, go >a o)
             (w = "--print-ls-colors") (pin o 'l 1, go >a o)
             (w = "--") (pin o 'fs (o 'fs + >a), o)
             (1 < #w && w 0 = 45 && !(w = "-")) (usage (w 1 = 45 ? ("unrecognized option '" + w + "'") ("invalid option -- '" + string (w 1) + "'")))
             (pin o 'fs (o 'fs + [w]), go >a o))))
       o (go as {'fs ()})
       fs (o 'fs)
       (two? >fs ? (usage ("extra operand '" + <>fs + "'")) 0,
        o 'p && (o 'sh || o 'l) ? (usage "the options to output non shell syntax,\nand to select a shell syntax are mutually exclusive") 0,
        o 'p && two? fs ? (usage ("extra operand '" + <fs + "'\nfile operands cannot be combined with --print-database (-p)")) 0,
        (o 'p ? (say out udc-db, flush out, 0)
         (: nm (two? fs ? <fs "")
            txt (? (atom? fs) udc-db (nm = "-") (slurp in)
                   (uread nm @ r (two? r ? <>r (udie 1 ("dircolors: " + nm + ": No such file or directory")))))
            r (udc-parse txt (nm = "-" ? "-" nm))
            sh (o 'sh ? (o 'sh)
                (: s (getenv "SHELL") b (string? s ? (ubase s "") "")
                   (b = "csh" || b = "tcsh" ? 'c 'b)))
            (? !<r (uleave 1)
               (o 'l) (map (e \ say out ("\e[" + <>e + "m" + <e + "\t" + <>e + "\e[0m\n")) <>r, flush out, 0)
               (foldl (a \ e \ a + udc-q <e + "=" + udc-q <>e + ":") "" <>r @ v
                (say out (sh = 'c ? ("setenv LS_COLORS '" + v + "'\n") ("LS_COLORS='" + v + "';\nexport LS_COLORS\n")),
                 flush out, 0)))))))

   ; -- pathchk: would these names work. bare, each is asked of the system as it stands
   ; (a component that is a file, a name past the limits where it does not exist yet);
   ; -p asks POSIX's portable floor instead (the 65 characters, 14 a component, 255 a
   ; name), -P forbids the empty name and a leading '-', --portability is both --
   (upc-oct c) ("\\" + string (48 + c // 64) + string (48 + c // 8 % 8) + string (48 + c % 8))
   (upc-print? c) (31 < c && c < 127)
   (upc-all p s) (: (go k) (? (#s <= k) 1 (p (s k)) (go (k + 1)) 0) (go 0))
   (upc-q s)                            ; GNU's quote(): '..', ".." round a ', $'\ooo' for the rest
    (? (upc-all (c \ upc-print? c && !(c = 39)) s) ("'" + s + "'")
       (upc-all (c \ upc-print? c && !(elem c [34 36 92 96])) s) ("\"" + s + "\"")
       (: n #s
          (go k acc) (? (n <= k) acc
                        (upc-print? (s k) && !(s k = 39)) (go (k + 1) (acc + string (s k)))
                        (: (run j a) (j < n && !(upc-print? (s j) && !(s j = 39)) ? (run (j + 1) (a + upc-oct (s j))) [j a])
                           r (run k "")
                           (go <r (acc + "'$'" + <>r + "''"))))
          t ("'" + go 0 "" + "'")
          (2 < #t && snip t (#t - 2) #t = "''" ? (snip t 0 (#t - 2)) t)))
   (upc-cq c) (? (c = 39) "'\\''" (upc-print? c) ("'" + string c + "'") ("'" + upc-oct c + "'"))
   (upc-f s)                            ; quotef: bare where nothing needs it
    (#s && upc-all (c \ elem c "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._/+,:@%^-") s ? s (upc-q s))
   (pathchk-main as)
    (: (usage m) (udie 1 ("pathchk: " + m + "\nTry 'pathchk --help' for more information."))
       (go a b x)
        (atom? a ? [b x ()]
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
       _ (two? fs ? 0 (usage "missing operand"))
       portable "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-/"
       (no m) (say err ("pathchk: " + m + "\n"), 0)
       (one f)
        (: n #f
           comps (filter (c \ 0 < #c) (usplit 47 f))
           hy (: (h k) (? (n <= k) 0 (f k = 45 && (k = 0 || f (k - 1) = 47)) 1 (h (k + 1))) (h 0))
           bad (b ? (: (p k) (? (n <= k) () (elem (f k) portable) (p (k + 1)) (f k)) (p 0)))
           st (? b 'enoent (0 = n) 'enoent (lstat f))
           pmax (b ? 256 4096) cmax (b ? 14 255)
           long (filter (c \ cmax < #c) comps)
           (? (x && hy) (no ("leading '-' in a component of file name " + upc-q f))
              ((b || x) && n = 0) (no "empty file name")
              (charm? bad) (no ("non-portable character " + upc-cq bad + " in file name " + upc-q f))
              (!b && n = 0) (no "'': No such file or directory")
              (!b && nom? st && !(st = 'enoent)) (no (upc-f f + ": " + uerrno st))
              (two? st) 1
              (pmax <= n) (no ("limit " + show (pmax - 1) + " exceeded by length " + show n + " of file name " + upc-q f))
              (two? long) (no ("limit " + show cmax + " exceeded by length " + show #<long + " of file name component " + upc-q <long))
              1))
       ok (foldl (a \ f \ (one f ? a 0)) 1 fs)
       (flush err,
        ok ? 0 1))

   ; -- mountpoint: is DIR where a filesystem is mounted -- a target in the kernel's
   ; own table (/proc/self/mountinfo) where there is one, else a device that differs
   ; from its parent's. -d says that filesystem's major:minor, -x DEV a block device's
   ; own; 32 for "not", 1 for trouble, util-linux's --
   (ump-unesc s)                        ; mountinfo's \ooo escapes put back
    (: n #s o (jug 0)
       (go k) (? (n <= k) (slurp o)
                 (s k = 92 && k + 3 < n) (put o ((s (k + 1) - 48) * 64 + (s (k + 2) - 48) * 8 + (s (k + 3) - 48)), go (k + 4))
                 (put o (s k), go (k + 1)))
       (go 0))
   (ump-devno d) (show ((d >> 8) & 4095 | (d >> 32 & -4096)) + ":" + show (d & 255 | (d >> 12) & -256))
   (mountpoint-main as)
    (: (usage _) (udie 1 "mountpoint: bad usage\nTry 'mountpoint --help' for more information.")
       (go a o)
        (atom? a ? o
         (<a @ w
          (? (w = "--") (pin o 'ops (o 'ops + >a), o)
             (w = "-q" || w = "--quiet") (pin o 'q 1, go >a o)
             (w = "-d" || w = "--fs-devno") (pin o 'd 1, go >a o)
             (w = "-x" || w = "--devno") (pin o 'x 1, go >a o)
             (w = "--nofollow") (pin o 'nf 1, go >a o)
             (1 < #w && w 0 = 45) (usage 0)
             (pin o 'ops (o 'ops + [w]), go >a o))))
       o (go as {'ops ()})
       ops (o 'ops)
       _ (two? ops && (atom? >ops) ? 0 (usage 0))
       p <ops q (o 'q)
       (say1 s) (q ? 0 (say out (s + "\n"), flush out))
       st (o 'nf ? (lstat p) (stat p))
       (nom? st ? (q ? 0 (say err ("mountpoint: " + p + ": " + uerrno st + "\n"), flush err), uleave 1) 0,
        (o 'x ?
         ((st 2 & 61440) = 24576 ? (say1 (ump-devno (st 12)), 0)
          (q ? 0 (say err ("mountpoint: " + p + ": not a block device\n"), flush err), 32))
         (: c (o 'nf ? [1 (rl-clean (rl-abs p))] (rp-canon p 40))
            mi (uread "/proc/self/mountinfo")
            hit (two? mi && two? c ?
                 (foldl (h \ l \ (usplit 32 l @ ws (4 < #ws && ump-unesc (ws 4) = <>c ? (ws 2) h))) () (lines <>mi))
                 (stat (p + "/..") @ up
                  (two? up && (!(st 11 = up 11) || st 8 = up 8) ? (ump-devno (st 11)))))
            (string? hit ? (say1 (o 'd ? hit (p + " is a mountpoint")), 0)
             (say1 (p + " is not a mountpoint"), 32))))))

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
           (<p @ v
            (? (v < 0) (n <= 0 - v ? (rp + n) (stage1 >p (n + v) (rp - v) k))
               (v <= n) (map (i \ pin d (k + i) (>p i)) ^v, stage1 (drop v >p) (n - v) rp (k + v))
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
       (stage2 0 (num - rp) 0,
        map (i \ peep d i -1) ^num))
   (ushr-fill pat n)                    ; a pattern's bytes, n of them, a bit flipped per 512
    (: bits (pat & 4095) b3 (bits | bits << 12)
       tri ((string (b3 >> 4 & 255)) + string (b3 >> 8 & 255) + string (b3 & 255))
       (rep s) (n <= #s ? (snip s 0 n) (rep (s + s)))
       s (rep tri)
       (pat & 4096 ? (cask n @ c (map (i \ pin c i (i % 512 ? (s i) (s i ^ 128))) ^n, string c)) s))
   (ushr-hex s) (zpad 2 (radix (s 0) 16) + zpad 2 (radix (s 1) 16) + zpad 2 (radix (s 2) 16))
   (shred-main as)
    (: (usage m) (udie 1 ("shred: " + m + "\nTry 'shred --help' for more information."))
       (num w what) (unum w @ v (charm? v && 0 <= v ? v (udie 1 ("shred: invalid number of " + what + ": '" + w + "'"))))
       (size w) (: n #w u (n ? (w (n - 1)) 0)
                   m (? (u = 75 || u = 107) 1024 (u = 77) 1048576 (u = 71) 1073741824 1)
                   v (unum (1 < m ? (snip w 0 (n - 1)) w))
                   (charm? v && 0 <= v ? (v * m) (udie 1 ("shred: invalid file size: '" + w + "'"))))
       (arg o k w a key f)
        (? (k < #w) (pin o key (f (snip w k #w)), [>a])
           (two? >a) (pin o key (f <>a), [>>a])
           (usage ("option requires an argument -- '" + string (w (k - 1)) + "'")))
       (go a o)
        (atom? a ? o
         (: w <a n #w
            (w @ "--" (pin o 'fs (o 'fs + >a), o)
               ("--force" || "--exact" || "--verbose" || "--zero")
                (pin o (w 2 @ 102 'f 101 'x 118 'v 'z) 1, go >a o)
               ("--remove" || "-u") (pin o 'u 1, go >a o)
               ("--iterations=" + (v && 0 < #v)) (pin o 'n (num v "passes"), go >a o)
               ("--size=" + (v && 0 < #v)) (pin o 's (size v), go >a o)
               ("--" + _) (usage ("unrecognized option '" + w + "'"))
               (? (1 < n && w 0 = 45))
                (: (cl k) (? (n <= k) (go >a o)
                             (w k = 110) (go <(arg o (k + 1) w a 'n (v \ num v "passes")) o)
                             (w k = 115) (go <(arg o (k + 1) w a 's size) o)
                             (elem (w k) "fxvzu") (pin o (w k @ 102 'f 120 'x 118 'v 122 'z 'u) 1, cl (k + 1))
                             (usage ("invalid option -- '" + string (w k) + "'")))
                   (cl 1))
               (pin o 'fs (o 'fs + [w]), go >a o))))
       o (go as {'n 3 'fs ()})
       fs (o 'fs)
       _ (two? fs ? 0 (usage "missing file operand"))
       v? (o 'v)
       (tell m) (v? ? (say err ("shred: " + m + "\n"), flush err) 0)
       (no f m) (say err ("shred: " + f + ": " + m + "\n"), flush err, 0)
       rnd (open "/dev/urandom" "r")
       _ (nom? rnd ? (udie 1 ("shred: /dev/urandom: " + uerrno rnd)) 0)   ; no entropy stops, never zeros
       buf (cask 65536)
       (fillr k) (swig rnd buf @ g (charm? g && 0 < g ? (k <= g ? (snip (string buf) 0 k) ((snip (string buf) 0 g) + fillr (k - g))) (udie 1 "shred: /dev/urandom: read failed")))
       (pass f n pat)                  ; -> 1 | 0, n bytes of the pattern (or random) laid over f
        (openfd f 4 @ fd
         (nom? fd ? (no f ("failed to open for writing: " + uerrno fd))
          (: p (fdopen fd)
             blk (pat < 0 ? () (ushr-fill pat (min n 65536)))
             (go k) (n <= k ? 1
                     (min 65536 (n - k) @ m
                      (say p (? (pat < 0) (fillr m) (m < #blk) (snip blk 0 m) blk),
                       go (k + m))))
             (go 0,
              close p,
              fsync f 1,
              1))))
       ; -u: the name worn down a character at a time, each a fresh name of 0s (or the
       ; next character GNU tries where that one is taken), then removed
       (rename-down f)
        (: base (ubase f "")
           pre (snip f 0 (#f - #base))
           set "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_."
           (zeros k) (k < 1 ? "" ("0" + zeros (k - 1)))
           (step cur len)
            (len < 1 ? cur
             (: (try i) (#set <= i ? (step cur (len - 1))
                         (pre + zeros (len - 1) + string (set i) @ nm
                          (? (two? (lstat nm)) (try (i + 1))
                             (rename cur nm) (step cur (len - 1))
                             (tell (cur + ": renamed to " + nm), step nm (len - 1)))))
                (try 0)))
           (step f #base))
       (one f)
        (stat f @ st
         (nom? st ? (no f ("failed to open for writing: " + uerrno st))
          (: _ ((o 'f) && !(st 2 & 128) ? (chmod f ((st 2 & 4095) | 128)) 0)
             reg ((st 2 & 61440) = 32768)
             bs (13 < #st && 0 < st 13 ? (st 13) 512)
             sz (? (charm? (o 's)) (o 's) !reg <st (o 'x) <st ((<st + bs - 1) // bs * bs))
             plan (ushr-plan (o 'n) + (o 'z ? [0]))
             tot #plan
             (run l k) (atom? l ? 1
                        (<l @ pat
                         (tell (f + ": pass " + show k + "/" + show tot + " ("
                                + (pat < 0 ? "random" (ushr-hex (ushr-fill pat 3))) + ")..."),
                          pass f sz pat ? (run >l (k + 1)) 0)))
             ok (run plan 1)
             (? !ok 0 !(o 'u) 1
                (: _ (tell (f + ": removing"))
                   _ (truncate f 0 0)
                   last (rename-down f)
                   e (unlink last)
                   (nom? e ? (no f ("failed to remove: " + uerrno e))
                    (tell (f + ": removed"), 1)))))))
       ok (foldl (a \ f \ (one f ? a 0)) 1 fs)
       (ok ? 0 1))

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
       (go en,
        slurp o))
   ; GNU's long names too: --suffix=S after the random run, --tmpdir[=DIR] as -p (bare,
   ; $TMPDIR or /tmp), --directory --dry-run --quiet
   (mktemp-main as)
    (: sf {'s ""}
       (fl a d u q dir fs)
        (atom? a ? [d u q dir (rev fs)]
         (<a @ ("-d" || "--directory") (fl >a 1 u q dir fs)
               ("-u" || "--dry-run") (fl >a d 1 q dir fs)
               ("-q" || "--quiet") (fl >a d u 1 dir fs)
               "--tmpdir" (fl >a d u q (getenv "TMPDIR" @ e (string? e ? e "/tmp")) fs)
               ("--tmpdir=" + (v && 0 < #v)) (fl >a d u q v fs)
               ("--suffix=" + (v && 0 < #v)) (pin sf 's v, fl >a d u q dir fs)
               "--suffix" (two? >a ? (pin sf 's <>a, fl >>a d u q dir fs) (udie 1 "mktemp: --suffix wants a suffix"))
               "-t" (fl >a d u q (dir ? dir (getenv "TMPDIR")) fs)
               "-p" (two? >a ? (fl >>a d u q <>a fs) (udie 1 "mktemp: -p wants a directory"))
               ("-p" + v) (fl >a d u q v fs)
               ; anything else is the template -- unless it still looks like a flag, which
               ; would name a temporary file after the option someone meant
               (? (1 < #<a && <a 0 = 45)) (udie 1 ("mktemp: unknown option " + <a))
               (fl >a d u q dir (<a . fs))))
       p (fl as 0 0 0 () ())
       d? <p u? <>p q? <>>p pdir (p 3) fs (p 4)
       tm (string? pdir ? pdir (getenv "TMPDIR" @ e (string? e ? e "/tmp")))
       named (two? fs)
       tmpl (named ? <fs "tmp.XXXXXXXXXX")
       base (named && !(string? pdir) ? tmpl ((0 < #tm ? tm ".") + "/" + tmpl))
       (try n)
        (n < 1 ? (q? ? 1 (udie 1 "mktemp: could not make a name nobody had"))
         (: nm (umtname base + sf 's)
            fd (d? ? -1 (openfd nm 3))
            got (d? ? !(mkdir nm 448) (charm? fd && 0 <= fd))
            (charm? fd && 0 <= fd ? (close fd),
             (!got ? (try (n - 1))
              (? u? (d? ? (rmdir nm) (unlink nm)) (),
               say out nm, put out 10, flush out, 0)))))
       (try 100))

   ; -- cmp: are two files the same bytes. the first difference is said by its char (POSIX's word)
   ; and line, as POSIX has it; -b adds the two bytes, -l lists every difference in
   ; octal, -s says nothing and the status answers; -n N compares at most N, -i SKIP or
   ; SKIP1:SKIP2 (and the operands after the files) skip a start. a file that ends
   ; first is an EOF on stderr, status 1 --
   (cmp-main as)
    (: fo (uflagsl "cmp" as '(110 105) "blsin" {"silent" 115 "quiet" 115 "verbose" 108 "print-bytes" 98 "bytes" 110 "ignore-initial" 105})
       t <fo s? (t 115) l? (t 108) b? (t 98) fs (fo 1)
       _ (two? >fs && atom? >>>>fs ? () (udie 2 "usage: cmp [-bls] [-n N] [-i SKIP[:SKIP]] A B [SKIP1 [SKIP2]]"))
       (num w) (unum w @ v (charm? v ? v (udie 2 ("cmp: invalid number: '" + w + "'"))))
       iv (uoptv t 105)
       ab (iv ? (iv @ (a + ":" + b) [a b] [iv iv]))
       sk1 (? (two? >>fs) (num (fs 2)) iv (num <ab) 0)
       sk2 (? (two? >>>fs) (num (fs 3)) iv (num <>ab) 0)
       lim (t 110 ? (num (uoptv t 110)))
       (rd f) (f = "-" ? [1 (slurp in)] (uread f))
       ra (rd <fs) rb (rd <>fs)
       (atom? ra || atom? rb ?
        (s? ? () (say err ("cmp: " + (two? ra ? <>fs <fs) + ": No such file or directory\n")), 2)
        (: A (snip <>ra (min sk1 #<>ra) #<>ra) B (snip <>rb (min sk2 #<>rb) #<>rb)
           n0 (min #A #B) n (lim ? (min lim n0) n0)
           short (? (lim && lim <= n0) () (#A < #B) <fs (#B < #A) <>fs ())
           (oct c) (upad 3 (radix c 8))
           (face c) (? (32 <= c < 127) (string c) (c < 32) ("^" + string (c + 64)) (c = 127) "^?" ("M-" + string (c - 128)))
           (bc c) (oct c + " " + face c)
           ; -l's byte number is as wide as the longer file's size
           wn #(show (max #A #B))
           ; the first difference, and its line: the newlines before it, plus one
           (first i ln) (? (n <= i) () (A i = B i) (first (i + 1) (A i = 10 ? (ln + 1) ln)) [i ln])
           (eof i ln) (s? || !short ? 0 (say err ("cmp: EOF on '" + short + "'" + (i = 0 ? " which is empty" (" after byte " + show i + (l? ? "" (", in line " + show ln)))) + "\n")))
           (l? ? (: (go i d) (? (n <= i) d
                               (A i = B i) (go (i + 1) d)
                               ((s? ? 0 (say out (upad wn (show (i + 1)) + " " + oct (A i) + (b? ? (" " + urpad 4 (face (A i))) "")
                                                  + " " + oct (B i) + (b? ? (" " + face (B i)) "") + "\n"))), go (i + 1) 1))
                    d (go 0 0)
                    (flush out,
                     eof n 0,
                     d || short ? 1 0))
            (first 0 1 @ f
             (? f (: i <f _ (s? ? 0 (say out (<fs + " " + <>fs + " differ: " + (b? ? "byte " "char ") + show (i + 1) + ", line " + show <>f
                                             + (b? ? (" is " + bc (A i) + " " + bc (B i)) "") + "\n"))) _ (flush out) 1)
                short (foldl (a \ c \ (c = 10 ? (a + 1) a)) 1 (chars (snip A 0 n)) @ ln (eof n ln, 1))
                0)))))))
) ; module 'kore
