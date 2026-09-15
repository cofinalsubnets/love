; apps/kore/kore.l -- the multi-call dispatcher (busybox's trick): one binary, `kore`,
; shadowing nothing on the host, picking the util off the command line -- or off
; argv[0] through a tool-named symlink, which is how the distro will shadow at will.
;
;   kore diff old new    unified diff (patience hunks); exit 0 same / 1 differ / 2 trouble
;   kore nc host port    the netcat (apps/ain.l); nc -l port listens
;   kore make [F] [T..]  the build tool (apps/cook.l)
;   kore as tgt in out   assemble IR forms from in (x64|a64) into an ELF at out
;   kore objcopy -O binary|ihex in out   a linked ELF flattened (love/holo/copy.l)
;   kore nm [-gup] file..   an ELF's symbols, nm's three columns (love/holo/link.l)
;   kore cat|tac|head|tail|wc|sort|uniq|tee|echo|seq|yes|true|false|basename|dirname
;   kore cut|tr|nl|rev|paste|comm|join|split|od   the line, field and record tools
;                                                 (apps/kore/core.l)
;   kore fold|expand|unexpand        the column tools (a tab steps to the next stop)
;   kore dos2unix|unix2dos|mac2unix [-fkqn] [F..]   the three line endings, IN PLACE
;   kore base64|base32 [-d] [-w N]   the RFC 4648 encodings
;   kore tsort|factor                a partial order made total, and a number's primes
;   kore cksum|md5sum|sha256sum [-c] [F..]   the checksums (apps/kore/sum.l)
;   kore ls|cp|mv|rm|mkdir|rmdir|ln|touch|pwd|chmod   the fs tools (apps/kore/fs.l)
;   kore realpath|link|unlink        a path made canonical, and the two bare calls
;   kore stat|du|df|chown|mktemp                     ... and what they report
;   kore expr expression             the little language (apps/kore/expr.l)
;   kore patch [-pN] [-R] [-i F]     unified diffs laid on a tree (apps/kore/patch.l)
;   kore grep [-nvclqhaixwFEo] [-e P] [-m N] pattern [F..]   BRE/ERE (apps/kore/re.l)
;   kore sed [-nEi] [-e script].. script [F..]   the stream editor (apps/kore/sed.l)
;   kore awk [-F fs] [-v v=x].. 'PROG' [F..]     the language (apps/kore/awk.l)
;   kore find [PATH..] [EXPR]                    the tree walk (apps/kore/find.l)
;   kore env|printenv|sleep|kill|xargs|time|date|id   the process and world tools
;                                                 (apps/kore/proc.l)
;   kore ps|top|free|uptime|pidof|pgrep|pkill|killall|pwdx   the /proc family
;   kore whoami|groups|arch|nproc    the four one-line answers
;   kore vi [file]                   the editor (apps/vi/)
;   kore less|more [-Nise] [+N|+/P] [F..]   the pager (apps/kore/less.l; one pager,
;                                           two spellings, less's keys and its manners)
;   kore man [-w] [SEC] NAME..       the manual pages (apps/kore/man.l): the roff a page is
;                                    written in, read back through lapiz and paged by less
;   kore html2text [-w N] [F..]      a page's prose, laid out (apps/kore/lens.l)
;   kore markdown [-t T] [F..]       markdown out the other side: html, roff or text
;   kore gzip|gunzip|zcat [-cdfkl..]  the RFC 1952 container (apps/gz.l); tar and cpio the
;   kore tar czf|xzf|tzf ARCHIVE      two containers over it (apps/tar.l, apps/cpio/). these
;   kore cpio {-o|-i|-t} [-H newc]    ride love's own verb rail too -- one main, two doors
;   kore dd [if= of= bs= count= skip=]   blocks in, blocks out; no seek=, see core.l
;   kore xxd [-r] [F..]              the canonical dump, and back again
;   kore strings [-n LEN] [F..]      the printable runs of an object file
;   kore cal [[MONTH] YEAR]          a month, off the same two calendar rows date reads
;   kore timeout [-s SIG] [-k D] D CMD..   a command, and the clock that ends it (124)
;   kore which [-a] NAME..           the PATH walk; tty, clear and hostname the rest
;   kore sh [-c CMD | file]          the shell, lush (apps/lush.l; also `lush`, and an sh symlink)
; (the C compiler is NO LONGER here -- it split into its own app `mooncc`, doc/misc/moon.md.)
;
; loads LAST in the kore cat, when every tool main is defined, and its leave prunes the
; module down to the head below: every tool's <name>-main (the spelling lush's in-image lane
; and any (cite 'kore ..) reach), the u/text floors later cat members read bare, and
; kore-main. die, read-text and the registry stay private.
; every path answers a charm through core.l's urun, so an in-image caller lives through a
; tool that would have quit -- the SEAT below is the one site that quits, and a main here
; leaves deep through `die`.
(module (kore kore-main wget-main wg-digits wg-find wg-lower wg-url wg-resolve wg-header wg-unchunk wg-once wg-fetch wg-name
        diff-main as-main ar-main ld-main nm-main
        arch-main awk-main base32-main base64-main basename-main bracket-main cat-main
        chmod-main chomp chown-main chroot-main cksum-main cmp-main cnames comm-main cp-main cut-main
        date-main dirname-main dos2unix-main dsplit du-main echo-main env-main expand-main expr-main
        mac2unix-main unix2dos-main
        factor-main false-main find-main fold-main free-main gfind grep-main groups-main
        head-main id-main install-main join-main killall-main kill-main lastn less-main lines link-main man-main html2text-main markdown-main
        ln-main ls-main md5sum-main mkdir-main mkfifo-main mknod-main mktemp-main mount-main
        mv-main myers nl-main nproc-main
        od-main paste-main patch-main pgrep-main pidof-main pkill-main printenv-main
        printf-main ps-main pwd-main pwdx-main readlink-main realpath-main rebre refind refold
        rem reparse rev-main rmdir-main rm-main sed-main seq-main sha256sum-main sleep-main
        sort-main sparse split-main srun stat-main sync-main df-main time-main tac-main tail-main
        tee-main test-main top-main
        touch-main lift-main tr-main true-main tsort-main uatoi ubase uclk ucopy udie udiff udirp ujoin
        uleave umount-main uname-main unexpand-main uniq-main unlines unlink-main uptime-main uread urun
        uset usplit ustatf utag utty uupsay wc-main whoami-main xargs-main yes-main
        cal-main clear-main dd-main hostname-main strings-main timeout-main tty-main
        which-main xxd-main)
(borrow 'cli)  ; the option walk and the -h/-v door, both of them love's floor too
(borrow 'holo) ; the assembler module: elf64, arbytes, ld-syms, at -- as/ar/ld/nm read it
(borrow 'posix)
(: (read-text p) (: q (open p "r") (? (hot? q) (: t (slurp q) _ (close q) [1 t]) ()))    ; (1 text) | ()
   (die m) (: _ (say err m) _ (put err 10) (uleave 2))

   ; diff: two files -> unified hunks on out; the classic exit triple
   (diff-main as)
    (? !(two? >as) (die "usage: kore diff OLD NEW")
       (: fa <as fb <>as
          ta (read-text fa) tb (read-text fb)
          _ (? (two? ta) () (die ("diff: cannot open " + fa)))
          _ (? (two? tb) () (die ("diff: cannot open " + fb)))
          d (udiff fa fb <>ta <>tb)
          (? (nil? d) 0
             (: _ (puts d) _ (flush out) 1))))

   ; as: IR forms -> a runnable ELF (love/holo/elf.l over the baked holo book)
   (as-main as)
    (? !(two? >>as) (die "usage: kore as TARGET IN OUT   (TARGET: x64 | a64)")
       (: tgt (arch-nom <as) src <>as dst <>>as
          _ (? ((tgt = 'x64) || (tgt = 'a64)) ()
               (die ("as: unknown target " + <as)))
          q (open src "r")
          _ (? (hot? q) () (die ("as: cannot open " + src)))
          (rd x acc) (: r (sound x)
                      (? (two? r) (rd >r (<r . acc))
                         (= r 'torn) (die ("as: unfinished form in " + src))
                         (rev acc)))
          ir (rd (slurp q) ())
          _ (? (two? ir) () (die ("as: no IR forms in " + src)))
          res (elf64 tgt (\ _ ir) ())
          _ (write-bytes dst (peep res 'bytes 0))
          _ (say err ("as: wrote " + dst)) _ (put err 10)
          0))

   ; ar: the classic "!<arch>" archive, GNU shape to the byte. the bytes come from holo's
   ; `arbytes`, beside the reader that pulls them back, so mooncc's runtime archive and this
   ; one share a writer. `ar rcs OUT M..` writes out whole; names stored as basenames.
   (ar-write dst ms)                                          ; ms: ((basename bytes)..)
    (: q (open dst "w")
       _ (? (hot? q) () (die ("ar: cannot write " + dst)))
       _ (say q (arbytes ms))
       (close q))
   (ar-t p)                                                   ; list member names
    (: r (uread p) _ (? (two? r) () (die ("ar: cannot open " + p)))
       b <>r n (tally b)
       _ (? ((<= 8 n) && (snip b 0 8 = "!<arch>\n")) () (die ("ar: not an archive: " + p)))
       (field s) (: (go k) (? ((0 < k) && (s (k - 1) = 32)) (go (k - 1)) (snip s 0 k)) (go (tally s)))
       (lname lt off) (: (go k) (? ((< k (tally lt)) && !(lt k = 10)) (go (k + 1)) k)
                         e (go off)
                         (: nm (snip lt off e) z (tally nm)
                            (? ((0 < z) && (nm (z - 1) = 47)) (snip nm 0 (z - 1)) nm)))
       (go pos lt) (? (< (n - pos) 60) 0
                      (: nm (field (snip b pos (pos + 16)))
                         sz (uatoi (field (snip b (pos + 48) (pos + 58))))
                         d0 (pos + 60)
                         nx ((d0 + sz) + (& sz 1))
                         (? (nm = "/") (go nx lt)
                            (nm = "//") (go nx (snip b d0 (d0 + sz)))
                            (: shown (? (nm 0 = 47) (lname lt (uatoi (snip nm 1 (tally nm))))
                                        (: z (tally nm) (? (nm (z - 1) = 47) (snip nm 0 (z - 1)) nm)))
                               _ (puts (shown + "\n"))
                               (go nx lt)))))
       _ (go 8 "")
       0)
   (ar-main as)
    (? !(two? as) (die "usage: kore ar rcs OUT MEMBER..   |   kore ar t OUT")
       (: fl <as
          (? (fl = "t") (? (two? >as) (ar-t <>as) (die "ar: t wants an archive"))
             (: hasr ((: (go i) (? (< i (tally fl)) (? (fl i = 114) 1 (go (i + 1))) 0)) 0)
                _ (? hasr () (die ("ar: unsupported command " + fl + " (rcs / t)")))
                _ (? (two? >as) () (die "ar: no archive named"))
                dst <>as
                fs >>as
                _ (? (two? fs) () (die "ar: no members"))
                ms (map (\ f (: r (uread f)
                                 (? (two? r) [(ubase f "") <>r] (die ("ar: cannot open " + f)))))
                        fs)
                _ (ar-write dst ms)
                0))))

   ; ld: holo's static linker as an applet -- mooncc .o (and any ELF relocatable
   ; love/holo/link.l reads) into a static exe, no binutils anywhere; -pie the
   ; self-relocating et_dyn, -Ttext the bare-metal org (qemu -kernel's lane).
   (ld-main as)
    (: (num s) (: n (tally s)
                  hex ((2 < n) && (s 0 = 48) && (s 1 = 120))
                  (go i a) (? (< i n)
                              (go (i + 1) ((a * (? hex 16 10))
                                           + (: b (s i)
                                                (? ((<= 48 b) && (< b 58)) (b - 48)
                                                   ((<= 97 b) && (< b 103)) (b - 87)
                                                   ((<= 65 b) && (< b 71)) (b - 55)
                                                   (die ("ld: bad number " + s))))))
                              a)
                  (go (? hex 2 0) 0))
       (go a fs o pie org tgt rd)
        (? !(two? a) [(rev fs) o pie org tgt rd]
           (<a = "-o")     (? (two? >a) (go >>a fs <>a pie org tgt rd) (die "ld: -o wants a path"))
           (<a = "-pie")   (go >a fs o 1 org tgt rd)
           (<a = "-t")     (? (two? >a) (go >>a fs o pie org (intern <>a) rd) (die "ld: -t wants a target"))
           (<a = "-Ttext") (? (two? >a) (go >>a fs o pie (num <>a) tgt rd) (die "ld: -Ttext wants an address"))
           ; --readme file: plain text into `.love.README`, for whoever opens the output
           (<a = "--readme") (? (two? >a)
                                (: t (uread <>a) (? (two? t) (go >>a fs o pie org tgt <>t)
                                                    (die ("ld: cannot open " + <>a))))
                                (die "ld: --readme wants a path"))
           (go >a (<a . fs) o pie org tgt rd))
       r (go as () () 0 () 'x64 ())
       fs <r o <>r pie <>>r org (r 3) tgt (r 4) rdme (r 5)
       _ (? (two? fs) () (die "usage: kore ld [-pie] [-t x64|a64|rv64] [-Ttext ADDR] [--readme F] A.o.. -o OUT"))
       _ (? (tally o) () (die "ld: no -o OUT"))
       srcs (map (\ f (: r2 (uread f) (? (two? r2) [f <>r2] (die ("ld: cannot open " + f))))) fs)
       ps (ldlink tgt pie org srcs ("love " + <(usplit 43 love-version)) rdme)
       _ (ld-write o ps)
       _ (chmod o 493)
       0)

   ; nm: VALUE type NAME over love/holo/link.l's ld-syms. the letter is ELF's own facts, never
   ; a guess: U undefined, a absolute, C common, else the section's flags pick T/B/D/R, and a
   ; local bind lowercases it. -u names the undefined, which is what says a lane was borrowed
   ; from libgcc rather than ours (tools/moon-parity.sh reads exactly that).
   ; the sort is BY BYTE -- `LC_ALL=C nm`'s order, so it is the same on every machine.
   ; an archive is not walked here: nm's per-member header wants the walk `ar t` owns.
   (nm-sp w) (? (w < 1) "" (nm-sp (w - 1) + " "))
   (nm-hex v w) (: dg "0123456789abcdef"
                   (go k a) (? (k < 0) a (go (k - 1) (a + string (dg ((v // (k 16)) % 16)))))
                   (go (w - 1) ""))
   (nm-low t) (: c (t 0) (? ((65 <= c) && (c <= 90)) (string (c + 32)) t))
   (nm-let sy)
    (: x (sy 3) sec (sy 6)
       u (? (x = 0) "U" (x = 65521) "A" (x = 65522) "C"
            !(two? sec) "?"
            (: ty (sec 1) fl (sec 2)
               (? (ty = 8) "B" (0 < (fl & 4)) "T" (0 < (fl & 1)) "D" "R")))
       (? (sy 1 = 2) (? (x = 0) "w" "W")
          (sy 1 = 0) (nm-low u)
          u))
   (nm-file p wide g u srt)
    (: r (uread p) _ (? (two? r) () (die ("nm: cannot open " + p)))
       b <>r
       w (? (b 4 = 2) 16 8)
       ; a section or file symbol names no value of the program's -- nm shows
       ; neither, and an empty name is the null-ish filler a section symbol leaves
       all (filter (\ sy (? (nil? (tally <sy)) () (elem (sy 2) '(3 4)) () 1))
                   (ld-syms p b))
       ; "no symbols" is the file's fact, asked before the flags narrow: a -u that
       ; comes back empty says the lanes are all ours, which is an answer, not a lack
       _ (? (two? all) () (: _ (say err ("nm: " + p + ": no symbols")) _ (put err 10) 1))
       keep (filter (\ sy (? (g && (sy 1 = 0)) () (u && !(sy 3 = 0)) () 1)) all)
       ord (? srt keep (sortby (\ a b (<a <= <b)) keep))
       _ (? wide (: _ (puts ("\n" + p + ":\n")) 0) 0)
       ; foldl is the printing walk: it answers the accumulator, so nothing is built
       _ (foldl (\ _ sy (puts ((? (sy 3 = 0) (nm-sp w) (nm-hex (sy 4) w))
                               + " " + nm-let sy + " " + <sy + "\n")))
                0 ord)
       (two? all))
   (nm-main as)
    ; flags cluster: -gu is -g -u, which is what a hand types and what nm takes
    (: (nm-flags t k g u srt)
        (? (tally t <= k) [g u srt]
           (: c (t k)
              (? (c = 103) (nm-flags t (k + 1) 1 u srt)
                 (c = 117) (nm-flags t (k + 1) g 1 srt)
                 (c = 112) (nm-flags t (k + 1) g u 1)
                 (die ("nm: unknown flag -" + (string c))))))
       (go a g u srt fs)
        (? !(two? a) [g u srt (rev fs)]
           ((1 < tally <a) && (<a 0 = 45))
            (: f (nm-flags <a 1 g u srt) (go >a <f <>f <>>f fs))
           (go >a g u srt (<a . fs)))
       r (go as () () () ())
       fs (r 3)
       _ (? (two? fs) () (die "usage: kore nm [-g] [-u] [-p] FILE.."))
       wide (two? >fs)
       any (foldl (\ a p (? (nm-file p wide <r <>r <>>r) 1 a)) () fs)
       _ (flush out)
       (? any 0 1))

   ; the registry: name -> main (aliases share)
   applets {'diff diff-main
            'nm nm-main
            'nc (cite 'ain 'ain-main) 'ain (cite 'ain 'ain-main)   ; ain's wrap registered ahead in the cat
            'make (cite 'cook 'cook-main) 'cook (cite 'cook 'cook-main)   ; cook.l's wrap registered ahead in the cat; the map ctor evaluates values
            'as as-main
            'ar ar-main 'ld ld-main
            'objcopy (cite 'holo 'objcopy)   ; the applet is the function: love/holo/copy.l, module-side
            'cat cat-main 'tac tac-main 'echo echo-main
            'head head-main 'tail tail-main
            'wc wc-main 'sort sort-main
            'uniq uniq-main 'tee tee-main
            'seq seq-main 'yes yes-main
            'true true-main 'false false-main
            ; t/[ are programs here, not just shell builtins: cook's in-image lane
            ; execs a recipe's words directly, so a `test -s $t && mv ..` looks them up
            ; on PATH. uname and printf are the other two a bootstrap cannot start without.
            ; `[` cannot be quoted -- it opens a bracket in the reader -- so the nom
            ; is interned by name; the map ctor evaluates its keys, which is the door.
            'test test-main (name "[") bracket-main
            'uname uname-main 'arch arch-main 'nproc nproc-main 'printf printf-main
            'basename basename-main 'dirname dirname-main
            'cut cut-main 'tr tr-main
            ; the three line endings, one walk (apps/kore/core.l)
            'dos2unix dos2unix-main 'unix2dos unix2dos-main 'mac2unix mac2unix-main
            'nl nl-main 'rev rev-main
            'fold fold-main 'expand expand-main 'unexpand unexpand-main
            'base64 base64-main 'base32 base32-main
            'tsort tsort-main 'factor factor-main
            'paste paste-main 'comm comm-main 'split split-main
            'join join-main 'od od-main
            'cksum cksum-main 'md5sum md5sum-main 'sha256sum sha256sum-main
            'ls ls-main 'dir ls-main   ; one lister, and the name DOS and coreutils ask it by
            'cp cp-main 'mv mv-main
            'rm rm-main 'mkdir mkdir-main 'rmdir rmdir-main
            'ln ln-main 'touch touch-main 'lift lift-main
            'pwd pwd-main 'chmod chmod-main
            'install install-main 'readlink readlink-main
            'realpath realpath-main 'link link-main 'unlink unlink-main
            'cmp cmp-main
            'stat stat-main 'du du-main 'df df-main 'chown chown-main 'mktemp mktemp-main
            'expr expr-main 'date date-main 'id id-main
            'bc bc-main
            'patch patch-main
            'wget wget-main
            'grep grep-main 'sed sed-main
            'awk awk-main 'find find-main
            'vi (cite 'vi 'vi-main)   ; the editor's wrap registered ahead in the cat
            'less less-main 'more less-main   ; one pager, and the two names it is asked for
            'man man-main    ; the pages the build writes, read back (apps/kore/man.l)
            'html2text html2text-main   ; a page's prose (apps/kore/lens.l), the same lens
            'markdown markdown-main     ; ..and the lens run the way papel runs it
            'env env-main 'printenv printenv-main 'sleep sleep-main
            ; the privileged half: chroot is LFS chapter 7's own call, and mount,
            ; umount, sync, mkfifo and mknod are what a root the distro builds
            ; is filled and entered with
            'chroot chroot-main 'mount mount-main 'umount umount-main
            'sync sync-main 'mkfifo mkfifo-main 'mknod mknod-main
            'whoami whoami-main 'groups groups-main
            ; the archives: gz.l and tar.l register into `verbs` for love's own rail,
            ; and these rows are the same mains under kore's door. they sit in the cat
            ; ahead of this file, so the cite reads now
            'gzip (cite 'gzcmd 'gzip-main) 'gunzip (cite 'gzcmd 'gunzip-main)
            'zcat (cite 'gzcmd 'zcat-main)
            'tar (cite 'tarcmd 'tar-main) 'cpio (cite 'cpiocmd 'cpio-main)
            ; the byte tools, the clock's other face, and the four one-liners
            'dd dd-main 'xxd xxd-main 'strings strings-main
            'cal cal-main 'timeout timeout-main
            'which which-main 'tty tty-main 'clear clear-main 'hostname hostname-main
            ; the /proc family -- no nif of their own, /proc is a filesystem
            'ps ps-main 'free free-main 'uptime uptime-main 'top top-main
            'pidof pidof-main 'pgrep pgrep-main 'pkill pkill-main
            'killall killall-main 'pwdx pwdx-main
            'kill kill-main 'xargs xargs-main 'time time-main
            ; the shell: lush's wrap registered ahead of this file in the cat, so sh-main
            ; folds here. `kore sh ..` and a /bin/sh symlink both land it (the
            ; symlink usually through lush's own seat, which fires first at
            ; cat load on an sh/lush basename -- this row serves the image
            ; wake, where only kore-main dispatches)
            'sh (cite 'lush 'sh-main) 'lush (cite 'lush 'sh-main)}

   ; the synopses, one line a tool -- what `TOOL --help` prints. a name with no row
   ; here still answers the flag, with its own spelling for a synopsis.
   korehelp
   {'diff "usage: diff OLD NEW   (0 same / 1 differ / 2 trouble)"
    'nm "usage: nm [-g] [-u] [-p] FILE.."
    'nc "usage: nc HOST PORT  |  nc -l PORT"
    'ain "usage: ain HOST PORT  |  ain -l PORT"
    'as "usage: as TARGET IN OUT   (TARGET: x64 | a64)"
    'ar "usage: ar rcs OUT MEMBER..  |  ar t OUT"
    'ld "usage: ld [-pie] [-t x64|a64|rv64] [-Ttext ADDR] [--readme F] A.o.. -o OUT"
    'objcopy "usage: objcopy -O binary|ihex IN OUT"
    'cat "usage: cat [FILE..]"
    'tac "usage: tac [FILE..]"
    'head "usage: head [-n N] [-N] [FILE..]"
    'tail "usage: tail [-n N] [-N] [FILE..]"
    'wc "usage: wc [-lwc] [FILE..]"
    'sort "usage: sort [-bfnrsu] [-k SPEC].. [-t C] [FILE..]"
    'uniq "usage: uniq [-c] [FILE]"
    'tee "usage: tee [-a] [FILE..]"
    'seq "usage: seq [FIRST [INCR]] LAST"
    'yes "usage: yes [WORD..]"
    'true "usage: true   (the 0 exit, and nothing else)"
    'false "usage: false   (the 1 exit, and nothing else)"
    'uname "usage: uname [-snrma]"
    'arch "usage: arch   (uname -m, and nothing else)"
    'nproc "usage: nproc"
    'printf "usage: printf FORMAT [ARG..]"
    'basename "usage: basename NAME [SUFFIX]"
    'dirname "usage: dirname NAME"
    'cut "usage: cut -f LIST [-d C] [-s] | cut -c LIST"
    'tr "usage: tr SET1 SET2 | tr -d SET1 | tr -s SET1"
    'nl "usage: nl [FILE..]"
    'rev "usage: rev [FILE..]"
    'fold "usage: fold [-w N] [-s] [-b] [FILE..]"
    'expand "usage: expand [-t N] [-i] [FILE..]"
    'unexpand "usage: unexpand [-a] [-t N] [FILE..]"
    'base64 "usage: base64 [-d] [-w N] [FILE]"
    'base32 "usage: base32 [-d] [-w N] [FILE]"
    'tsort "usage: tsort [FILE]"
    'factor "usage: factor [N..]"
    'paste "usage: paste [-s] [-d LIST] [FILE..]"
    'comm "usage: comm [-123] FILE1 FILE2"
    'split "usage: split [-l N] [-b SIZE] [-a N] [-d] [FILE [PREFIX]]"
    'join "usage: join [-1 F] [-2 F] [-t C] [-a 1|2] [-v 1|2] FILE1 FILE2"
    'od "usage: od [-A C] [-t TYPE] [-N N] [-j N] [-v] [-abcdiosx] [FILE..]"
    'cksum "usage: cksum [FILE..]"
    'md5sum "usage: md5sum [-c] [FILE..]"
    'sha256sum "usage: sha256sum [-c] [FILE..]"
    'ls "usage: ls [-aACdlrtx1] [FILE..]"
    'dir "usage: dir [-aACdlrtx1] [FILE..]"
    'cp "usage: cp [-f] [-p] SRC DST"
    'mv "usage: mv [-f] SRC DST"
    'rm "usage: rm [-r] [-f] FILE.."
    'mkdir "usage: mkdir [-p] DIR.."
    'rmdir "usage: rmdir DIR.."
    'ln "usage: ln [-s] [-f] TARGET LINKNAME"
    'touch "usage: touch FILE.."
    'lift "usage: lift FILE   -- carry FILE out of the machine: the page's downloads, the runner's directory"
    'pwd "usage: pwd"
    'chmod "usage: chmod OCTAL FILE.."
    'install "usage: install [-D] [-m OCTAL] [-s] SRC DST  |  install -d DIR.."
    'readlink "usage: readlink [-f] PATH"
    'realpath "usage: realpath [-e|-m|-s] PATH.."
    'link "usage: link FILE NEW"
    'unlink "usage: unlink FILE"
    'cmp "usage: cmp [-s] A B"
    'stat "usage: stat [-L] [-c FORMAT | --printf=FORMAT] FILE.."
    'du "usage: du [-sabchk] [-d N] [FILE..]"
    'df "usage: df [-h|-k] [-i] [-a] [-P] [FILE..]"
    'chown "usage: chown [-R] OWNER[:GROUP] FILE.."
    'mktemp "usage: mktemp [-d] [-u] [-q] [-p DIR] [TEMPLATE]"
    'sync "usage: sync   (the bare call; no operands here)"
    'mkfifo "usage: mkfifo [-m MODE] NAME.."
    'mknod "usage: mknod [-m MODE] NAME TYPE [MAJOR MINOR]"
    'expr "usage: expr EXPRESSION"
    'patch "usage: patch [-pN] [-R] [-i F] [-o F] [-s] [--dry-run]"
    'grep "usage: grep [-nvclqhaixwFEo] [-e PAT] [-m N] PATTERN [FILE..]"
    'sed "usage: sed [-n] [-E] [-i] [-e SCRIPT].. SCRIPT [FILE..]"
    'awk "usage: awk [-F FS] [-v var=val].. PROGRAM [FILE..]  |  awk .. -f PROGFILE.. [FILE..]"
    'find "usage: find [PATH..] [EXPR]  -- see doc/misc/kore.md for the grammar"
    'less "usage: less [-Nise] [+N|+/PAT] [FILE..]"
    'more "usage: more [-Nise] [+N|+/PAT] [FILE..]"
    'wget "usage: wget [-q] [-O FILE] URL"
    'bc "usage: bc [-l] [-q] [FILE..]
  -l  the math library (e l a s c j), and scale = 20
  -q  accepted: nothing is printed at start with or without it"
    'vi "usage: vi [FILE]"
    'env "usage: env [-i] [-u NAME].. [NAME=VALUE].. [CMD [ARG..]]"
    'printenv "usage: printenv [NAME..]"
    'sleep "usage: sleep N[smhd].."
    'chroot "usage: chroot DIR [CMD [ARG..]]"
    'mount "usage: mount [-t TYPE] [-o OPTS] SRC TGT   (or bare, to list)"
    'umount "usage: umount TARGET.."
    'whoami "usage: whoami"
    'groups "usage: groups"
    'ps "usage: ps [-e]"
    'top "usage: top [-b] [-n FRAMES] [-d SECS] [-p PID]..
  -b  batch: no terminal wanted, every process, a frame per iteration
  -n  stop after N frames (-b alone is one frame)
  -d  seconds between frames (3 by default)
  -p  one process, spelled again for each
  keys: q quit, space or r repaint, c the command line, P M T N the orders"
    'free "usage: free [-m|-g]"
    'uptime "usage: uptime"
    'pidof "usage: pidof NAME.."
    'pgrep "usage: pgrep [-f] [-x] PATTERN"
    'pkill "usage: pkill [-SIG] [-f] [-x] PATTERN"
    'killall "usage: killall [-SIG] NAME.."
    'pwdx "usage: pwdx PID.."
    'kill "usage: kill [-SIG] PID.."
    'xargs "usage: xargs [-n N] [CMD ARGS..]"
    'time "usage: time [-p] CMD [ARG..]"
    'date "usage: date [-u] [-d TIME] [-r FILE] [+FORMAT]"
    'id "usage: id [-u|-g|-G] [-n] [-r]"
    'dos2unix "usage: dos2unix [-fkqn] [FILE..]"
    'unix2dos "usage: unix2dos [-fkqn] [FILE..]"
    'mac2unix "usage: mac2unix [-fkqn] [FILE..]"
    'man "usage: man [-w] [SECTION] NAME.."
    'html2text "usage: html2text [-w COLS] [FILE..]"
    'markdown "usage: markdown [-t html|roff|text] [-w COLS] [FILE..]"
    'dd "usage: dd [if=F] [of=F] [bs=N] [count=N] [skip=N] [status=none]"
    'xxd "usage: xxd [-r] [FILE..]"
    'strings "usage: strings [-n LEN] [FILE..]"
    'cal "usage: cal [[MONTH] YEAR]"
    'timeout "usage: timeout [-s SIG] [-k DURATION] DURATION CMD [ARG..]"
    'which "usage: which [-a] NAME.."
    'tty "usage: tty"
    'clear "usage: clear"
    'hostname "usage: hostname"}

   ; echo, test and [ read no options at all -- posix says so, and a script writing
   ; `echo --help` means the word. cook and lush answer the flags themselves, each
   ; with more to say than a synopsis. none of them is at this door.
   korenoflag ['echo 'test (name "[") 'make 'cook 'sh 'lush]
   ; -h and -v are not free everywhere. the tools below spell one of them themselves,
   ; or posix and gnu do, so they answer the long forms only and the letter stays theirs.
   korenoh '(grep du df ls sort touch chown ln free)
   korenov '(grep awk od join nl uname cat head tail cp mv rm ln mkdir rmdir chmod
             chown install mount umount readlink patch pgrep pkill killall)
   ; the tools that read no options at all, and the few dash words the two of them
   ; that do read still answer. each of these ignored every argument it was handed,
   ; so `arch -Z` printed the machine and `ps --nosuch` the process table -- the walk
   ; is the leading words only, which leaves `ps aux` (no dash) exactly as it was.
   korebare '(arch nproc whoami groups uptime pwd ps free tty clear hostname)
   korebareok {'ps '("-e" "-A" "-a" "-ax" "-x") 'free '("-g" "-m" "-h")}
   (kobare nm as)
    (: ok (peep korebareok nm ())
       (<(filter (w \ 1 < #w && w 0 = 45 && !(elem w ok)) as)))
   ; the applet as the world calls it: cli's door, then the tool under urun. both
   ; dispatch lanes come through here -- the verb registry and the symlink -- so there
   ; is one answer and not two. what kore keeps is the policy: which names take no
   ; flags at all, which have spoken for a letter themselves, and the usage text.
   (koredoor nm f)
    (: (run as) (? !(elem nm korebare) (urun f as)
                   (: w (kobare nm as)
                      (? (nil? w) (urun f as)
                         (: _ (say err (string nm + ": unknown option " + w))
                            _ (put err 10) 2))))
       (? (elem nm korenoflag) run
          (udoor nm run (peep korehelp nm ()) !(elem nm korenoh) !(elem nm korenov))))

   kore-usage "kore -- the love multi-call toolbox
usage: kore TOOL ARGS..     (or symlink a tool's name to kore)
every tool answers --help and --version, and -h and -v where the letter is free
  diff OLD NEW       unified diff, patience hunks (0 same / 1 differ / 2 trouble)
  nc HOST PORT       netcat; nc -l PORT listens
  make [FILE] [T..]  the build tool (Cards.l / Cookfile / Makefile)
  as TGT IN OUT      assemble IR forms from IN (x64|a64) into ELF OUT
  ar rcs OUT M..     the archive, GNU shape + ranlib index (ar t OUT lists)
  ld A.o.. -o OUT    holo's static linker (-pie, -t x64|a64|rv64, -Ttext)
  objcopy -O F IN OUT   flatten a linked ELF: F is binary or ihex (Intel HEX)
  nm [-gup] FILE..   an ELF's symbols; -g externals, -u undefined, -p unsorted
  cat tac head tail wc sort uniq tee      the line tools (apps/kore/core.l)
  cut tr nl rev                           the field tools
  dos2unix | unix2dos | mac2unix [-fkqn] [F..]   the line endings, converted IN PLACE
  fold [-w N] [-s] [-b] | expand [-t N] [-i] | unexpand [-a] [-t N]   the columns
  base64 | base32 [-d] [-w N] [F]         the encodings (RFC 4648)
  tsort [F] | factor [N..]                the two little computations
  paste comm join split od                the record tools
  cksum | md5sum [-c] | sha256sum [-c]    the checksums (apps/kore/sum.l)
  expr EXPRESSION                         arithmetic, comparison and BRE matching
  bc [-l] [-q] [F..]                      the calculator language (apps/kore/bc.l)
  patch [-pN] [-R] [-i F] [--dry-run]     lay a unified diff on a tree
  grep [-nvclqhaixwFEo] [-e P] [-m N] PAT [F..]   BRE, or ERE under -E (apps/kore/re.l)
  sed [-nEi] [-e SCRIPT].. SCRIPT [F..]   the stream editor (s///gp, d, p, q, addresses)
  awk [-F FS] [-v var=val].. 'PROG' [F..]  patterns and actions over records
  awk [-F FS] -f PROGFILE.. [F..]          ... the program off a file instead
  find [PATH..] [EXPR]   -name -path -type f|d|l -print -prune -exec CMD.. \\;
                         ( ) ! -a -o -maxdepth N -mindepth N   (PATH defaults to .)
  env printenv sleep kill xargs           the process tools (apps/kore/proc.l)
  chroot DIR [CMD [ARG..]]                the root changed, then CMD in it
  mount [-t TYPE] [-o OPTS] SRC TGT       ... or bare, to list /proc/self/mounts
  umount TGT.. | sync                     ... and the two that undo and settle it
  mkfifo [-m MODE] NAME.. | mknod [-m MODE] NAME p|b|c|u [MAJOR MINOR]
  whoami | groups | arch | nproc          the four one-line answers
  ps [-e] | free [-m|-g] | uptime         what /proc says about the machine
  top [-b] [-n N] [-d SECS] [-p PID]      the process table, repainted
  pidof NAME.. | pgrep [-fx] PAT          .. and about who is running
  pkill [-SIG] [-fx] PAT | killall [-SIG] NAME.. | pwdx PID..
  time [-p] CMD [ARG..]                   what a command costs: real, user, sys
  date [-u] [-d @SEC] [-r F] [+FMT]       the clock, UTC (no tz database here)
  id [-u|-g|-G] [-n]                      who this process is
  vi [FILE]                               the editor (apps/vi/)
  less | more [-Nise] [+N|+/PAT] [F..]    the pager (apps/kore/less.l); h is its help
  man [-w] [SECTION] NAME..               the manual pages (apps/kore/man.l)
  html2text [-w COLS] [F..]               a page's prose, laid out (apps/kore/lens.l)
  markdown [-t html|roff|text] [F..]      markdown laid out the other way
  sh [-c CMD | FILE]                      the shell, lush (apps/lush.l)
  ls cp mv rm mkdir rmdir ln touch pwd chmod   the fs tools (apps/kore/fs.l)
  install readlink cmp                         ... the build's fs verbs
  realpath [-e|-m|-s] P.. | link F NEW | unlink F   ... the paths and the two calls
  stat [-c FMT] | du [-sabhc] | df [-hia] | chown | mktemp   ... and what they report
  echo seq yes true false basename dirname     ... and the trivia
  gzip | gunzip | zcat [-cdfklnNqrtv19]        the RFC 1952 container (apps/gz.l)
  tar czf|xzf|tzf ARCHIVE [DIR]                the ustar archive (apps/tar.l)
  cpio {-o|-i|-t} [-H newc] [-dutv]            ... and the other one (apps/cpio/)
  dd [if=F] [of=F] [bs=N] [count=N] [skip=N]   blocks in, blocks out
  xxd [-r] [F..] | strings [-n LEN] [F..]      the dump, and the printable runs
  cal [[MONTH] YEAR]                           a month, laid out (weeks open Sunday)
  timeout [-s SIG] [-k DUR] DUR CMD [ARG..]    a command, and the clock that ends it
  which [-a] NAME.. | tty | clear | hostname   ... and the four short answers
"
   (usage _) (: _ (say err kore-usage) 2)
   (bn p) (: n (tally p)
             (go k r) (? (k < n) (go (k + 1) (? (p k = 47) (k + 1) r)) (snip p r n))
             (go 0 0))

   ; -- the dispatch (this form's body) --
   ; the spellings kore answers to: itself, its file, and every applet -- the symlink
   ; lane is just an applet name in the program seat, so the table is the list. the
   ; scan is love/boot/post.l's `seatof` (over the list we are handed, never a command
   ; line: the in-image door dispatches (. "kore" "ls" "-l")), which drops the -l
   ; pairs and answers (SEAT-WORD . rest), () when the seat is someone else's -- so a
   ; bake loading the cat as `love -l .kore-cat.l -e ..` stays quiet.
   ; the seat word's basename picks the face: a tool name runs that tool on the rest;
   ; anything else (kore itself, a dev path) reads the next word as the tool.
   mynames ("kore" . "kore.l" . map string (keys applets))
   ; the verbs: kore's applet table is a verb collection, and the registry is where one
   ; goes. every row lands twice over -- `love ls -l` (the word door) and an `ls` symlink
   ; onto the artifact (the seat door) -- while `love kore ls` still nests through the
   ; dispatch below. pinned here rather than by whoever cats the file, so every image
   ; carrying this cat carries the names: the dist artifact, and the kernel, whose
   ; userland this is.
   ; each row closes over its own f -- the inner `:` is a fresh scope per step, so the
   ; closures do not all end up holding the last applet.
   _ (: T (cite 'verbs 'tab)
        ; kore-main is unbound here -- it binds later in this same form -- so the
        ; closure reads it through the registry at the call, when module 'kore holds
        ; it. a bare read compiled here would ride a missing cell against the
        ; caller's walk, where kore never walks.
        _ (pin T 'kore (\ as ((cite 'kore 'kore-main) ("kore" . as))))
        (go ks) (? (two? ks) (: f (applets <ks) _ (pin T <ks (koredoor <ks f)) (go >ks)) 0)
        (go (keys applets)))
   ; kore-main is the dispatch door, and the in-image door too: it dispatches a
   ; program-relative arg list -- argv0 a tool symlink, or `kore`/a dev path then the
   ; tool word -- and answers the status charm, () when kore is not seated (the bake
   ; stays quiet; an unknown tool is usage's 2, a status like any other). the baked
   ; kore.image wakes to it with a synthetic "kore" argv0, so a caller holding the
   ; image runs a tool by handing it (. "kore" "ls" "-l") and reading the charm.
   ; two doors: a list handed in is scanned, () means "the line I was started with".
   (kore-main a)
    (: s (? (two? a) ((cite 'verbs 'seatof) mynames a) ((cite 'verbs 'fire) mynames))
       (? !(two? s) ()
          (: n0 (intern (bn <s))
             f0 (applets n0)
             (? f0 ((koredoor n0 f0) >s)
                (: t >s
                   n (? (two? t) (intern <t) ())
                   f (? n (applets n) ())
                   ; no tool named: kore's own two flags, then the listing
                   (? f ((koredoor n f) >t)
                      (uask t 1 1
                       @ 'help (: _ (puts kore-usage) _ (flush out) 0)
                         'vers (: _ (puts ("kore (love " + love-version + ")\n"))
                                  _ (flush out) 0)
                         (usage ())))))))))
; the seat: file mode (cat | love) dispatches on the real command line and quits with
; the status. the -l bake preload seats a flag, not kore, so the scan answers () and
; kore-main answers () -- the presence guard, and the one answer that is not a status.
(: r (kore-main ()) (? (charm? r) (quit r) ()))
) ; module 'kore
