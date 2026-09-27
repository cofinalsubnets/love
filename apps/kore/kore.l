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
;   kore cat|tac|shuf|head|tail|wc|sort|uniq|tee|echo|seq|yes|true|false|basename|dirname
;   kore cut|tr|nl|rev|paste|comm|join|split|od   the line, field and record tools
;                                                 (apps/kore/core.l)
;   kore fold|expand|unexpand        the column tools (a tab steps to the next stop)
;   kore dos2unix|unix2dos|mac2unix [-fkqn] [F..]   the three line endings, IN PLACE
;   kore base64|base32 [-d] [-w N]   the RFC 4648 encodings
;   kore tsort|factor                a partial order made total, and a number's primes
;   kore cksum|sum|crc32|md5sum|sha1sum|sha224sum|sha256sum|sha384sum|sha512sum|b2sum|sha3sum
;                                    the checksums (apps/kore/sum.l)
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
;   kore ed|ex [-s] [FILE]           the line editors, one buffer (apps/kore/ed.l)
;   kore less|more [-Nise] [+N|+/P] [F..]   the pager (apps/kore/less.l; one pager,
;                                           two spellings, less's keys and its manners)
;   kore man [-w] [SEC] NAME..       the manual pages (apps/kore/man.l): the roff a page is
;                                    written in, read back through lapiz and paged by less
;   kore html2text [-w N] [F..]      a page's prose, laid out (apps/kore/lens.l)
;   kore markdown [-t T] [F..]       markdown out the other side: html, roff or text
;   kore www [-w N] URL|FILE         a web page, its links numbered (apps/kore/www.l)
;   kore telnet HOST [PORT]          a remote terminal (apps/kore/net.l); httpd, kiosko
;                                    under busybox's flags, nslookup and ping beside it
;   kore gzip|gunzip|zcat [-cdfkl..]  the RFC 1952 container (apps/gz.l), xz|unxz|xzcat the .xz
;                                    one (apps/xz.l, inle/xz.c's LZMA2), bzip2|bunzip2|bzcat
;                                    (apps/bz2.l, inle/bz2.c); tar and cpio the
;   kore tar {c|x|t}[vzjJ] -f A      two containers over it (apps/tar.l, apps/cpio.l). these
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
        www-main ww-split ww-resolve ww-arg ww-get ww-lay ww-dump ww-new ww-show ww-step ww-body ww-fit
        telnet-main httpd-main tn-new tn-byte tn-send tn-echo? nslookup-main ping-main ping-ms ping-t
        diff-main as-main ar-main ld-main nm-main ed-main ex-main
        arch-main awk-main base32-main base64-main basename-main bracket-main cat-main
        chgrp-main chmod-main chomp chown-main chroot-main cksum-main cmp-main cnames comm-main cp-main cut-main
        date-main dirname-main dos2unix-main dsplit du-main echo-main env-main expand-main expr-main
        mac2unix-main unix2dos-main
        factor-main false-main find-main fold-main free-main getopt-main gfind grep-main groups-main hd-main hexdump-main
        head-main id-main install-main join-main killall-main kill-main lastn less-main lines link-main man-main html2text-main markdown-main
        ln-main ls-main vdir-main md5sum-main mkdir-main mkfifo-main mknod-main mktemp-main mount-main
        mv-main myers nl-main nice-main nohup-main nproc-main
        od-main paste-main patch-main pgrep-main pidof-main pkill-main printenv-main
        printf-main ps-main pwd-main pwdx-main ranlib-main readlink-main realpath-main rebre refind refold renice-main
        rem reparse rev-main rmdir-main rm-main sed-main seq-main sha1sum-main sha224sum-main sha256sum-main
        sha384sum-main sha512sum-main b2sum-main sum-main shuf-main size-main sleep-main
        sort-main sparse split-main srun stat-main strip-main stty-main sync-main df-main time-main tac-main tail-main
        tee-main test-main top-main
        touch-main lift-main tr-main true-main truncate-main tsort-main uatoi ubase uclk ucopy udie udiff udirp ujoin
        uleave umount-main uname-main unexpand-main uniq-main unlines unlink-main uptime-main uread urun
        users-main uset usignames usplit ustatf utag utty uupsay wc-main who-main whoami-main xargs-main yes-main
        cal-main clear-main dd-main hostname-main logname-main strings-main timeout-main tty-main
        hostid-main dnsdomainname-main setsid-main watch-main pathchk-main mountpoint-main shred-main
        sha3sum-main crc32-main basenc-main uuencode-main uudecode-main ascii-main pinky-main
        usleep-main reset-main ts-main fsync-main dircolors-main dc-main readelf-main hexedit-main
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
   ; an archive's members as ((name bytes)..), the index and the long-name table read
   ; past; () for bytes that are no archive
   (ar-mems b)
    (: n (tally b)
       (field s) (: (go k) (? ((0 < k) && (s (k - 1) = 32)) (go (k - 1)) (snip s 0 k)) (go (tally s)))
       (lname lt off) (: (go k) (? ((< k (tally lt)) && !(lt k = 10)) (go (k + 1)) k)
                         e (go off)
                         (: nm (snip lt off e) z (tally nm)
                            (? ((0 < z) && (nm (z - 1) = 47)) (snip nm 0 (z - 1)) nm)))
       (go pos lt acc)
        (? (< (n - pos) 60) (rev acc)
           (: nm (field (snip b pos (pos + 16)))
              sz (uatoi (field (snip b (pos + 48) (pos + 58))))
              d0 (pos + 60)
              nx ((d0 + sz) + (& sz 1))
              (? (nm = "/" || nm = "/SYM64/") (go nx lt acc)
                 (nm = "//") (go nx (snip b d0 (d0 + sz)) acc)
                 (: shown (? (nm 0 = 47) (lname lt (uatoi (snip nm 1 (tally nm))))
                             (: z (tally nm) (? (nm (z - 1) = 47) (snip nm 0 (z - 1)) nm)))
                    (go nx lt ([shown (snip b d0 (d0 + sz))] . acc))))))
       (? ((<= 8 n) && (snip b 0 8 = "!<arch>\n")) (go 8 "" ()) ()))
   (ar-t p)                                                   ; list member names
    (: r (uread p) _ (? (two? r) () (die ("ar: cannot open " + p)))
       b <>r
       _ (? ((<= 8 (tally b)) && (snip b 0 8 = "!<arch>\n")) () (die ("ar: not an archive: " + p)))
       _ (map (m \ puts (<m + "\n")) (ar-mems b))
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

   ; -- size, strip, ranlib: the three binutils that ride holo's ELF field table and its
   ; archive writer. little-endian ELF of either class; a section reads as
   ; (index name type flags off size link info align header-bytes) --
   (bu-le v n) (? (n < 1) "" (string (v & 255) + bu-le (v >> 8) (n - 1)))
   (bu-put fs h nm v) (: r (ld-row fs nm) o <r w <>r (snip h 0 o + bu-le v w + snip h (o + w) #h))
   (bu-elf? b) (20 <= #b && b 0 = 127 && b 1 = 69 && b 2 = 76 && b 3 = 70 && b 5 = 1
                && (b 4 = 1 || b 4 = 2))
   (bu-fs b) (? (b 4 = 2) elf64f elf32f)
   (bu-secs fs b)
    (: shoff (ld-f fs b 0 'e-shoff) n (ld-f fs b 0 'e-shnum) e (ld-n fs 'sh-ent)
       sx (ld-f fs b 0 'e-shstrx)
       stro (? (sx < n) (ld-f fs b (shoff + sx * e) 'sh-off) 0)
       (go i acc)
        (? (n <= i) (rev acc)
           (: h (shoff + i * e)
              (go (i + 1) ([i (ld-cstr b (stro + ld-f fs b h 'sh-name)) (ld-f fs b h 'sh-type)
                            (ld-f fs b h 'sh-flags) (ld-f fs b h 'sh-off) (ld-f fs b h 'sh-size)
                            (ld-f fs b h 'sh-link) (ld-f fs b h 'sh-info) (ld-f fs b h 'sh-align)
                            (snip b h (h + e))] . acc))))
       (go 0 ()))
   ; binutils' berkeley sums: allocated code or read-only is text, allocated with bytes
   ; is data, allocated without is bss
   (bu-berk b)
    (foldl (\ a sc (: fl (sc 3) sz (sc 5)
                      (? ((fl & 2) = 0) a
                         (0 < (fl & 4) || (fl & 1) = 0) [(a 0 + sz) (a 1) (a 2)]
                         !(sc 2 = 8) [(a 0) (a 1 + sz) (a 2)]
                         [(a 0) (a 1) (a 2 + sz)])))
           [0 0 0] (bu-secs (bu-fs b) b))
   (size-main as)
    (: t? (elem "-t" as || elem "--totals" as)
       bad (filter (w \ 1 < #w && w 0 = 45 && !(elem w '("-t" "--totals" "-B" "-d" "--format=berkeley"
                                                        "--format=bsd" "--radix=10"))) as)
       _ (? (two? bad) (udie 1 ("size: " + <bad + " is not here (the berkeley format, decimal, and -t)")) 0)
       fs0 (filter (w \ !(1 < #w && w 0 = 45)) as)
       fs (? (two? fs0) fs0 ["a.out"])
       hd {0 0}
       (row s nm)
        (: _ (? (hd 0) 0 (: _ (pin hd 0 1) (puts "   text\t   data\t    bss\t    dec\t    hex\tfilename\n")))
           d (s 0 + s 1 + s 2)
           (puts (upad 7 (show (s 0)) + "\t" + upad 7 (show (s 1)) + "\t" + upad 7 (show (s 2)) + "\t"
                  + upad 7 (show d) + "\t" + upad 7 (uradix d 16) + "\t" + nm + "\n")))
       ; the status is the last trouble's: 1 a file not there, 3 one not an object
       (add a s) [(a 0 + s 0) (a 1 + s 1) (a 2 + s 2) (? (0 < s 3) (s 3) (a 3))]
       (bad c m) (: _ (say err ("size: " + m + "\n")) [0 0 0 c])
       (one a f)
        (: r (uread f)
           (? !(two? r) (add a (bad 1 ("'" + f + "': No such file")))
              (: b <>r ms (ar-mems b)
                 (? (bu-elf? b) (: s (bu-berk b) _ (row s f) (add a (s + [0])))
                    (two? ms)
                     (foldl (\ a2 m (? (bu-elf? <>m) (: s (bu-berk <>m) _ (row s (<m + " (ex " + f + ")")) (add a2 (s + [0])))
                                       (add a2 (bad 3 (<m + ": file format not recognized")))))
                            a ms)
                    (add a (bad 3 (f + ": file format not recognized")))))))
       tot (foldl one [0 0 0 0] fs)
       _ (? t? (row tot "(TOTALS)") 0)
       _ (flush out)
       (tot 3))

   ; strip: the symbol table and the debugging sections out of an executable or a
   ; shared object; -g the debugging alone, which is all a relocatable object may lose,
   ; its relocations naming the symbols. what the loader maps stays where it lies; the
   ; sections nothing maps move up behind it, under a new name table and header table
   (bu-dbg? nm) (: (pre p) (#p <= #nm && snip nm 0 #p = p)
                   (pre ".debug" || pre ".zdebug" || pre ".stab" || pre ".gnu.debuglto_" || pre ".line"))
   (bu-strip b all?)                   ; -> the stripped bytes
    (: fs (bu-fs b)
       w64 (b 4 = 2)
       secs (bu-secs fs b)
       sx (ld-f fs b 0 'e-shstrx)
       na (sc \ ((sc 3) & 2) = 0)
       g0 (map (sc \ (<sc > 0) && na sc && ((all? && sc 2 = 2) || bu-dbg? (sc 1))) secs)
       (linked-by i gs) (foldl (\ a sc (? (a || (sc 6 = i && gs <sc)) 1 0)) 0 secs)
       (kept-link? i gs) (foldl (\ a sc (? (a || (sc 6 = i && !(gs <sc))) 1 0)) 0 secs)
       g1 (map (sc \ (g0 <sc) || (sc 2 = 3 && na sc && !(<sc = sx)
                                   && linked-by <sc g0 && !(kept-link? <sc g0))) secs)
       gone (map (sc \ (g1 <sc) || ((sc 2 = 4 || sc 2 = 9) && na sc
                                     && ((0 < sc 7 && sc 7 < #secs && g1 (sc 7))
                                         || (0 < sc 6 && sc 6 < #secs && g1 (sc 6))))) secs)
       keep (filter (sc \ !(gone <sc)) secs)
       (? (#keep = #secs) b
          (: map1 (foldl (\ t sc (pin t <sc #(keys t))) {} keep)
             (nx i) (peep map1 i 0)
             ehs (? w64 64 52)
             phend (: po (ld-f fs b 0 'e-phoff) pn (ld-f fs b 0 'e-phnum) pe (ld-n fs 'ph-ent)
                      (foldl (\ a k (: h (po + k * pe) (max a (ld-f fs b h 'ph-off + ld-f fs b h 'ph-fsz))))
                             (? pn (po + pn * pe) 0) ^pn))
             base (foldl (\ a sc (? (na sc || sc 2 = 8) a (max a (sc 4 + sc 5)))) (max ehs phend) keep)
             ; the name table, each kept name once, in section order
             nt (foldl (\ a sc (? (<sc = 0) a [(<a + sc 1 + string 0) (pin <>a <sc #<a)]))
                       [(string 0) {}] keep)
             names <nt noff <>nt
             ; the unmapped sections laid behind the mapped bytes, the name table among them
             lay (foldl (\ a sc (: al (max 1 (sc 8)) at (ld-align al <a)
                                   body (? (<sc = sx) names
                                           (sc 2 = 2 && !all?) (bu-symfix fs (snip b (sc 4) (sc 4 + sc 5)) nx)
                                           (sc 2 = 8) "" (snip b (sc 4) (sc 4 + sc 5)))
                                   (? (!(na sc) || <sc = 0) a
                                      [(at + #body) (pin <>a <sc at)
                                       (<>>a + [(ld-zeros (at - <a)) body])])))
                        [base {} ()] keep)
             shoff (ld-align (? w64 8 4) <lay)
             offs <>lay
             hdrs (map (sc \ (: h0 (sc 9)
                                h1 (bu-put fs h0 'sh-name (peep noff <sc 0))
                                h2 (: o (peep offs <sc -1) (? (o < 0) h1 (bu-put fs h1 'sh-off o)))
                                h3 (? (<sc = sx) (bu-put fs h2 'sh-size #names) h2)
                                h4 (? (0 < sc 6) (bu-put fs h3 'sh-link (nx (sc 6))) h3)
                                (? ((sc 2 = 4 || sc 2 = 9 || 0 < (sc 3 & 64)) && 0 < sc 7)
                                   (bu-put fs h4 'sh-info (nx (sc 7))) h4)))
                       keep)
             eh (bu-put fs (bu-put fs (bu-put fs (snip b 0 ehs) 'e-shoff shoff) 'e-shnum #keep)
                        'e-shstrx (nx sx))
             (foldl (\ a p (a + (? (string? p) p (foldl (\ s z (s + string z)) "" p))))
                    ""
                    ([eh (snip b ehs base)] + <>>lay + [(ld-zeros (shoff - <lay))] + hdrs)))))
   (bu-symfix fs s nx)                 ; a kept symbol table's section numbers, renumbered
    (: e (ld-n fs 'sy-ent) n (#s // e)
       (go i acc)
        (? (n <= i) acc
           (: h (snip s (i * e) (i * e + e)) x (ld-f fs h 0 'sy-shndx)
              (go (i + 1) (acc + (? (0 < x && x < 65280) (bu-put fs h 'sy-shndx (nx x)) h)))))
       (go 0 ""))
   (strip-main as)
    (: dbg (foldl (\ a w (a || elem w '("-g" "-S" "-d" "--strip-debug"))) 0 as)
       (go a o fs)
        (? !(two? a) [o (rev fs)]
           (: w <a
              (? (w = "-o") (? (two? >a) (go >>a <>a fs) (udie 1 "strip: option requires an argument -- 'o'"))
                 (elem w '("-g" "-S" "-d" "--strip-debug" "-s" "--strip-all" "--strip-unneeded" "-p" "--preserve-dates"))
                  (go >a o fs)
                 (1 < #w && w 0 = 45) (udie 1 ("strip: " + w + " is not here (-s -g -o -p)"))
                 (go >a o (w . fs)))))
       r (go as () ())
       o <r fs <>r
       p? (elem "-p" as || elem "--preserve-dates" as)
       _ (? (two? fs) 0 (udie 1 "Usage: strip [-s|-g] [-p] [-o OUT] FILE.."))
       _ (? (o && two? >fs) (udie 1 "strip: -o wants one input file") 0)
       (warn m) (: _ (say err ("strip: " + m + "\n")) 1)
       (one f)
        (: rd (uread f)
           (? !(two? rd) (warn ("'" + f + "': No such file"))
              (: b <>rd
                 (? !(bu-elf? b) (warn (f + ": file format not recognized"))
                    (!dbg && (b 16 + 256 * b 17) = 1)
                     (warn (f + ": a relocatable object keeps its symbols here (-g takes its debugging)"))
                    (: out (bu-strip b !dbg)
                       dst (? o o f)
                       st (stat f)
                       q (open dst "w")
                       (? !(hot? q) (warn ("unable to write " + dst))
                          (: _ (say q out) _ (close q)
                             _ (? (two? st) (chmod dst (st 2 & 4095)) 0)
                             _ (? (p? && two? st) (utime dst (st 1)) 0)
                             0)))))))
       (? (foldl (\ a f (max a (one f))) 0 fs) 1 0))

   ; ranlib: an archive written again with its index, the index holo's own reader wants
   ; -- readelf: binutils' -h -l -S -s (and -e, all three headers), wide or at 80
   ; columns, over little-endian ELF of either class. out of reach, deliberately: the
   ; relocations, the dynamic section, notes, versions and the dumps --
   (re-hex v w) (upadc w 48 (? (v = 0) "0" (ubase-hex v)))
   (re-0x v) ("0x" + (? (v = 0) "0" (ubase-hex v)))
   (re-u v w) (upad w (show v))
   (re-cut s w) (? (w < #s) (snip s 0 (w - 5) + "[...]") s)
   (re-at s w) (? (w < #s) (snip s 0 w) s)
   (re-lbl l) ("  " + urpad 35 l)
   (re-mach m) (m @ 3 "Intel 80386" 40 "ARM" 62 "Advanced Micro Devices X86-64" 183 "AArch64"
                    243 "RISC-V" 8 "MIPS R3000" 20 "PowerPC" 21 "PowerPC64" ("<unknown>: 0x" + ubase-hex m))
   (re-osabi o) (o @ 0 "UNIX - System V" 1 "UNIX - HP-UX" 2 "UNIX - NetBSD" 3 "UNIX - GNU" 6 "UNIX - Solaris"
                     9 "UNIX - FreeBSD" 12 "UNIX - OpenBSD" ("<unknown: " + ubase-hex o + ">"))
   (re-dyn fs b)                        ; the dynamic section's (tag . value) pairs
    (: w (? (b 4 = 2) 8 4)
       d (filter (\ sc (sc 2 = 6)) (bu-secs fs b))
       (? !(two? d) ()
          (: o (<d 4) n (<d 5 // (2 * w))
             (map (\ i [(ule b (o + 2 * w * i) w) (ule b (o + 2 * w * i + w) w)]) ^n))))
   (re-type fs b t)
    (t @ 0 "NONE (None)" 1 "REL (Relocatable file)" 2 "EXEC (Executable file)" 4 "CORE (Core file)"
         3 (? (any (\ p (<p = 1879048187 && 0 < (<>p & 134217728))) (re-dyn fs b))
              "DYN (Position-Independent Executable file)" "DYN (Shared object file)")
         ("<unknown>: " + ubase-hex t))
   (re-flags b m f)
    ("0x" + ubase-hex f
     + (? (m = 40) (? (f >> 24) (", Version" + show (f >> 24) + " EABI"
                               + (? (f & 1024) ", hard-float ABI" (f & 512) ", soft-float ABI" "")) "")
          (m = 243) ((? (f & 1) ", RVC" "") + ([", soft-float ABI" ", single-float ABI" ", double-float ABI" ", quad-float ABI"] ((f & 6) >> 1))
                     + (? (f & 8) ", RVE" "") + (? (f & 16) ", TSO" ""))
          ""))
   (re-head fs b)
    (: e64 (b 4 = 2) m (ule b 18 2) f (ule b (? e64 48 36) 4)
       (row l v) (say out (re-lbl l + v + "\n"))
       _ (say out "ELF Header:\n  Magic:   ")
       _ (map (\ i (say out (re-hex (b i) 2 + " "))) ^16)
       _ (say out "\n")
       _ (row "Class:" (? e64 "ELF64" "ELF32"))
       _ (row "Data:" "2's complement, little endian")
       _ (row "Version:" (show (b 6) + (? (b 6 = 1) " (current)" "")))
       _ (row "OS/ABI:" (re-osabi (b 7)))
       _ (row "ABI Version:" (show (b 8)))
       _ (row "Type:" (re-type fs b (ule b 16 2)))
       _ (row "Machine:" (re-mach m))
       _ (row "Version:" (re-0x (ule b 20 4)))
       _ (row "Entry point address:" (re-0x (ld-f fs b 0 'e-entry)))
       _ (row "Start of program headers:" (show (ld-f fs b 0 'e-phoff) + " (bytes into file)"))
       _ (row "Start of section headers:" (show (ld-f fs b 0 'e-shoff) + " (bytes into file)"))
       _ (row "Flags:" (re-flags b m f))
       _ (row "Size of this header:" (show (ule b (? e64 52 40) 2) + " (bytes)"))
       _ (row "Size of program headers:" (show (ld-f fs b 0 'e-phent) + " (bytes)"))
       _ (row "Number of program headers:" (show (ld-f fs b 0 'e-phnum)))
       _ (row "Size of section headers:" (show (ld-f fs b 0 'e-shent) + " (bytes)"))
       _ (row "Number of section headers:" (show (ld-f fs b 0 'e-shnum)))
       (row "Section header string table index:" (show (ld-f fs b 0 'e-shstrx))))
   (re-shtype m t)
    (? (t < 20) (["NULL" "PROGBITS" "SYMTAB" "STRTAB" "RELA" "HASH" "DYNAMIC" "NOTE" "NOBITS" "REL"
                  "SHLIB" "DYNSYM" "" "" "INIT_ARRAY" "FINI_ARRAY" "PREINIT_ARRAY" "GROUP" "SYMTAB SECTION INDICES" "RELR"] t)
       (t = 1879048181) "GNU_ATTRIBUTES" (t = 1879048182) "GNU_HASH" (t = 1879048183) "GNU_LIBLIST"
       (t = 1879048189) "VERDEF" (t = 1879048190) "VERNEED" (t = 1879048191) "VERSYM"
       (t = 1879048180) "GNU_SFRAME" (t = 1879002115) "LLVM_ADDRSIG"
       (m = 62 && t = 1879048193) "X86_64_UNWIND"
       (m = 40 && t = 1879048193) "ARM_EXIDX" (m = 40 && t = 1879048194) "ARM_PREEMPTMAP"
       (m = 40 && t = 1879048195) "ARM_ATTRIBUTES" (m = 243 && t = 1879048195) "RISCV_ATTRIBUTES"
       (m = 183 && t = 1879048195) "AARCH64_ATTRIBUTES"
       (1610612736 <= t && t < 1879048192) ("LOOS+0x" + ubase-hex (t - 1610612736))
       (1879048192 <= t && t < 2147483648) ("LOPROC+0x" + ubase-hex (t - 1879048192))
       (2147483648 <= t) ("LOUSER+0x" + ubase-hex (t - 2147483648))
       (re-hex t 8 + ": <unknown>"))
   (re-shflags b m f)
    (: gnu (b 7 = 3 || b 7 = 9)
       (go bit o) (? (32 <= bit) o
                     (: v (1 << bit)
                        (? (0 = (f & v)) (go (bit + 1) o)
                           (: c (? (bit < 12) ("WAX?MSILOGTC" bit)
                                   (v = 2097152 && gnu) 82
                                   (v = 268435456 && m = 62) 108
                                   (v = 536870912 && m = 40) 121
                                   (v = 2147483648) 69
                                   (0 < (v & 267386880)) 111
                                   (0 < (v & 4026531840)) 112
                                   120)
                              (go (bit + 1) (? (elem c o) o (o + string c)))))))
       (go 0 ""))
   (re-keys b m)
    ("Key to Flags:\n  W (write), A (alloc), X (execute), M (merge), S (strings), I (info),\n"
     + "  L (link order), O (extra OS processing required), G (group), T (TLS),\n"
     + "  C (compressed), x (unknown), o (OS specific), E (exclude),\n  "
     + (? (b 7 = 3 || b 7 = 9) "R (retain), " "") + "D (mbind), "
     + (m @ 62 "l (large), " 40 "y (purecode), " "") + "p (processor specific)\n")
   (re-secs fs b w? h?)
    (: e64 (b 4 = 2) m (ule b 18 2) ss (bu-secs fs b)
       (ent sc) (ld-f fs b 0 'e-shoff + sc 0 * ld-n fs 'sh-ent)
       (addr sc) (ule b ((ent sc) + (? e64 16 12)) (? e64 8 4))
       (esz sc) (ld-f fs b (ent sc) 'sh-esz)
       (? !(two? ss) (say out "\nThere are no sections in this file.\n")
          (: _ (? h? (say out "\n")
                  (say out ("There are " + show #ss + " section headers, starting at offset " + re-0x (ld-f fs b 0 'e-shoff) + ":\n\n")))
             _ (say out (? (#ss = 1) "Section Header:\n" "Section Headers:\n"))
             _ (say out (? !e64 "  [Nr] Name              Type            Addr     Off    Size   ES Flg Lk Inf Al\n"
                           w? "  [Nr] Name              Type            Address          Off    Size   ES Flg Lk Inf Al\n"
                           "  [Nr] Name              Type             Address           Offset\n       Size              EntSize          Flags  Link  Info  Align\n"))
             _ (map (\ sc
                      (: nm (sc 1) ty (re-at (re-shtype m (sc 2)) 15) fl (re-shflags b m (sc 3))
                         hd ("  [" + re-u (sc 0) 2 + "] " + urpad 17 (? w? nm (re-cut nm 17)) + " ")
                         (say out (? (!e64 || w?)
                                     (hd + urpad 15 ty + " " + re-hex (addr sc) (? e64 16 8) + " " + re-hex (sc 4) 6 + " "
                                      + re-hex (sc 5) 6 + " " + re-hex (esz sc) 2 + " " + upad 3 fl + " " + re-u (sc 6) 2
                                      + " " + re-u (sc 7) 3 + " " + re-u (sc 8) 2 + "\n")
                                     (hd + urpad 15 ty + "  " + re-hex (addr sc) 16 + "  " + re-hex (sc 4) 8 + "\n       "
                                      + re-hex (sc 5) 16 + "  " + re-hex (esz sc) 16 + " " + upad 3 fl + "      "
                                      + re-u (sc 6) 2 + "   " + re-u (sc 7) 3 + "     " + show (sc 8) + "\n")))))
                    ss)
             (say out (re-keys b m)))))
   (re-phtype m t)
    (? (t < 8) (["NULL" "LOAD" "DYNAMIC" "INTERP" "NOTE" "SHLIB" "PHDR" "TLS"] t)
       (t = 1685382480) "GNU_EH_FRAME" (t = 1685382481) "GNU_STACK" (t = 1685382482) "GNU_RELRO"
       (t = 1685382483) "GNU_PROPERTY" (t = 1685382484) "GNU_SFRAME"
       (m = 40 && t = 1879048193) "EXIDX" (m = 243 && t = 1879048195) "RISCV_ATTRIBUT"
       (1610612736 <= t && t < 1879048192) ("LOOS+0x" + ubase-hex (t - 1610612736))
       (1879048192 <= t && t < 2147483648) ("LOPROC+0x" + ubase-hex (t - 1879048192))
       ("<unknown>: " + ubase-hex t))
   (re-phs fs b)                        ; [type off vaddr paddr filesz memsz flags align]
    (: e64 (b 4 = 2) o (ld-f fs b 0 'e-phoff) n (ld-f fs b 0 'e-phnum) e (ld-f fs b 0 'e-phent)
       (map (\ i (: h (o + i * e)
                    (? e64 [(ule b h 4) (ule b (h + 8) 8) (ule b (h + 16) 8) (ule b (h + 24) 8) (ule b (h + 32) 8)
                            (ule b (h + 40) 8) (ule b (h + 4) 4) (ule b (h + 48) 8)]
                       [(ule b h 4) (ule b (h + 4) 4) (ule b (h + 8) 4) (ule b (h + 12) 4) (ule b (h + 16) 4)
                        (ule b (h + 20) 4) (ule b (h + 24) 4) (ule b (h + 28) 4)])))
            ^n))
   ; binutils' ELF_SECTION_IN_SEGMENT, strictly, the tbss case aside: the arithmetic is
   ; unsigned, so a size of 0 less 1 is every address
   (re-in? sc p)
    (: ty (sc 2) fl (sc 3) off (sc 4) sz (sc 5) addr (sc 10) pt <p
       tls (0 < (fl & 1024)) alloc (0 < (fl & 2)) nob (ty = 8)
       (le1 x v) (v = 0 || x <= v - 1)       ; x <= v - 1, unsigned
       ssz (? (!tls || !nob || pt = 7) sz 0)
       (? (tls && nob && !(pt = 7)) 0
          !(? tls (pt = 7 || pt = 1685382482 || pt = 1) !(pt = 7 || pt = 6)) 0
          (!alloc && (elem pt [1 2 1685382480 1685382481 1685382482 1685382484])) 0
          !(nob || (p 1 <= off && le1 (off - p 1) (p 4) && off - p 1 + ssz <= p 4)) 0
          !(!alloc || (p 2 <= addr && le1 (addr - p 2) (p 5) && addr - p 2 + ssz <= p 5)) 0
          (!(pt = 2 || pt = 4) || !(sz = 0) || p 5 = 0) 1
          ((nob || (p 1 < off && off - p 1 < p 4)) && (!alloc || (p 2 < addr && addr - p 2 < p 5)))))
   (re-segs fs b h? w?)
    (: e64 (b 4 = 2) m (ule b 18 2) ps (re-phs fs b)
       ss (map (\ sc (sc + [(ule b (ld-f fs b 0 'e-shoff + sc 0 * ld-n fs 'sh-ent + (? e64 16 12)) (? e64 8 4))]))
               (drop 1 (bu-secs fs b)))
       (? !(two? ps) (say out "\nThere are no program headers in this file.\n")
          (: _ (? h? 0
                  (say out ("\nElf file type is " + re-type fs b (ule b 16 2) + "\nEntry point " + re-0x (ld-f fs b 0 'e-entry)
                            + "\nThere are " + show #ps + " program headers, starting at offset " + show (ld-f fs b 0 'e-phoff) + "\n")))
             _ (say out (? !e64 "\nProgram Headers:\n  Type           Offset   VirtAddr   PhysAddr   FileSiz MemSiz  Flg Align\n"
                           w? "\nProgram Headers:\n  Type           Offset   VirtAddr           PhysAddr           FileSiz  MemSiz   Flg Align\n"
                           "\nProgram Headers:\n  Type           Offset             VirtAddr           PhysAddr\n                 FileSiz            MemSiz              Flags  Align\n"))
             (fl f) (string (? (f & 4) 82 32) + string (? (f & 2) 87 32) + string (? (f & 1) 69 32))
             _ (map (\ p
                      (: _ (say out ("  " + urpad 14 (re-at (re-phtype m <p) 14) + " "
                                     + (? (e64 && w?) ("0x" + re-hex (p 1) 6 + " 0x" + re-hex (p 2) 16 + " 0x" + re-hex (p 3) 16 + " 0x" + re-hex (p 4) 6
                                                    + " 0x" + re-hex (p 5) 6 + " " + fl (p 6) + " " + re-0x (p 7))
                                          e64 ("0x" + re-hex (p 1) 16 + " 0x" + re-hex (p 2) 16 + " 0x" + re-hex (p 3) 16
                                               + "\n                 0x" + re-hex (p 4) 16 + " 0x" + re-hex (p 5) 16 + "  " + fl (p 6) + "    " + re-0x (p 7))
                                          ("0x" + re-hex (p 1) 6 + " 0x" + re-hex (p 2) 8 + " 0x" + re-hex (p 3) 8 + " 0x" + re-hex (p 4) 5
                                           + " 0x" + re-hex (p 5) 5 + " " + fl (p 6) + " " + re-0x (p 7)))
                                     + "\n"))
                         (? (<p = 3) (say out ("      [Requesting program interpreter: " + ld-cstr b (p 1) + "]\n")) 0)))
                    ps)
             _ (say out "\n Section to Segment mapping:\n  Segment Sections...\n")
             (map (\ i (: p (ps i)
                          (say out ("   " + upadc 2 48 (show i) + "     "
                                    + foldl (\ a sc (? (re-in? sc p) (a + sc 1 + " ") a)) "" ss + "\n"))))
                  ^#ps))))
   ; a version index's name, off .gnu.version_r (what the file needs) and
   ; .gnu.version_d (what it defines): a tablet of index -> [name needed?]
   (re-vers ss b)
    (: t {}
       (str sc o) (ld-cstr b ((ss (sc 6)) 4 + o))
       (need sc)
        (: (vn o k) (? (k < 1) 0
                       (: cnt (ule b (o + 2) 2) aux (ule b (o + 8) 4) nx (ule b (o + 12) 4)
                          (va a j) (? (j < 1) 0
                                      (: _ (pin t (ule b (a + 6) 2) [(str sc (ule b (a + 8) 4)) 1])
                                         (va (a + ule b (a + 12) 4) (j - 1))))
                          _ (va (o + aux) cnt)
                          (? (nx = 0) 0 (vn (o + nx) (k - 1)))))
           (vn (sc 4) (sc 7)))
       (def sc)
        (: (vd o k) (? (k < 1) 0
                       (: ndx (ule b (o + 4) 2) aux (ule b (o + 12) 4) nx (ule b (o + 16) 4)
                          _ (pin t ndx [(str sc (ule b (o + aux) 4)) 0])
                          (? (nx = 0) 0 (vd (o + nx) (k - 1)))))
           (vd (sc 4) (sc 7)))
       _ (map (\ sc (? (sc 2 = 1879048190) (need sc) (sc 2 = 1879048189) (def sc) 0)) ss)
       t)
   (re-syms fs b w?)
    (: e64 (b 4 = 2) ss (bu-secs fs b) es (? e64 24 16)
       vt (re-vers ss b)
       vs (filter (\ sc (sc 2 = 1879048191)) ss)
       (sym o k) (: h (o + k * es)
                    (? e64 [(ule b h 4) (b (h + 4)) (b (h + 5)) (ule b (h + 6) 2) (ule b (h + 8) 8) (ule b (h + 16) 8)]
                       [(ule b h 4) (b (h + 12)) (b (h + 13)) (ule b (h + 14) 2) (ule b (h + 4) 4) (ule b (h + 8) 4)]))
       (styp t) (? (t < 7) (["NOTYPE" "OBJECT" "FUNC" "SECTION" "FILE" "COMMON" "TLS"] t) (t = 10) "IFUNC"
                   (13 <= t) ("<processor specific>: " + show t) ("<OS specific>: " + show t))
       (sbind t) (? (t < 3) (["LOCAL" "GLOBAL" "WEAK"] t) (t = 10) "UNIQUE"
                    (13 <= t) ("<processor specific>: " + show t) ("<OS specific>: " + show t))
       (ndx x) (upad 4 (? (x = 0) "UND" (x = 65521) "ABS" (x = 65522) "COM" (65280 <= x) ("PRC[0x" + re-hex x 4 + "]") (show x)))
       (szs v) (? (v < 100000) (re-u v 5) (re-0x v))
       (map (\ st
              (: n (st 5 // es) stro (? (st 6 < #ss) ((ss (st 6)) 4) 0)
                 _ (say out ("\nSymbol table '" + st 1 + "' contains " + show n + " " + (? (n = 1) "entry" "entries") + ":\n"
                             + (? e64 "   Num:    Value          Size Type    Bind   Vis      Ndx Name\n"
                                  "   Num:    Value  Size Type    Bind   Vis      Ndx Name\n")))
                 vsec (? (st 2 = 11) (filter (\ v (v 6 = st 0)) vs) ())
                 ; a needed version says its index; a defined one says @@, or @ where hidden,
                 ; and nothing on the symbol that names the version itself
                 (ver k y nm0) (? !(two? vsec) ""
                                  (: x (ule b (<vsec 4 + 2 * k) 2) i (x & 32767) e (peep vt i ())
                                     (? (i < 2 || !(two? e)) ""
                                        (y 3 = 0 || <>e) ("@" + <e + " (" + show i + ")")
                                        (<e = nm0) ""
                                        (x & 32768) ("@" + <e) ("@@" + <e))))
                 (map (\ k (: y (sym (st 4) k) t (y 1 & 15)
                              nm0 (? (t = 3 && y 0 = 0 && y 3 < #ss) ((ss (y 3)) 1) (ld-cstr b (stro + y 0)))
                              v (ver k y nm0)
                              nm (? (w? || #nm0 + #v <= 21) (nm0 + v) (snip nm0 0 (max 0 (16 - #v)) + "[...]" + v))
                              (say out (re-u k 6 + ": " + re-hex (y 4) (? e64 16 8) + " " + szs (y 5) + " "
                                        + urpad 7 (styp t) + " " + urpad 6 (sbind (y 1 >> 4)) + " "
                                        + urpad 7 (["DEFAULT" "INTERNAL" "HIDDEN" "PROTECTED"] (y 2 & 3)) + " "
                                        + ndx (y 3) + " " + nm + "\n"))))
                      ^n)))
            (filter (\ sc (sc 2 = 2 || sc 2 = 11)) ss)))
   (readelf-main as)
    (: (usage m) (udie 1 ("readelf: " + m))
       longs {"--file-header" 104 "--program-headers" 108 "--segments" 108 "--section-headers" 83
              "--sections" 83 "--headers" 101 "--syms" 115 "--symbols" 115 "--wide" 87}
       (go a o)
        (? !(two? a) o
           (: w <a n #w
              (? (w = "--") (: _ (pin o 'fs (o 'fs + >a)) o)
                 (2 < n && snip w 0 2 = "--")
                  (: k (peep longs w ()) (? (charm? k) (: _ (pin o k 1) (go >a o)) (usage (w + " is not here (-h -l -S -s -e -W)"))))
                 (1 < n && w 0 = 45)
                  (: _ (map (\ c (? (elem c "hlSseW") (pin o c 1) (usage ("-" + string c + " is not here (-h -l -S -s -e -W)"))))
                            (map w (drop 1 ^n)))
                     (go >a o))
                 (: _ (pin o 'fs (o 'fs + [w])) (go >a o)))))
       o (go as {'fs ()})
       e? (peep o 101 0)
       h? (e? || peep o 104 0) l? (e? || peep o 108 0) S? (e? || peep o 83 0) s? (peep o 115 0) w? (peep o 87 0)
       fs (o 'fs)
       _ (? (h? || l? || S? || s?) 0 (usage "Warning: Nothing to do.\nUsage: readelf <option(s)> elf-file(s)"))
       _ (? (two? fs) 0 (usage "Warning: Nothing to do.\nUsage: readelf <option(s)> elf-file(s)"))
       (one f)
        (: r (uread f)
           (? !(two? r) (: _ (say err ("readelf: Error: '" + f + "': No such file\n")) 0)
              (: b <>r
                 (? !(bu-elf? b) (: _ (say err "readelf: Error: Not an ELF file - it has the wrong magic bytes at the start\n") 0)
                    (: fs2 (bu-fs b)
                       _ (? (two? >fs) (say out ("\nFile: " + f + "\n")) 0)
                       _ (? h? (re-head fs2 b) 0)
                       _ (? S? (re-secs fs2 b w? h?) 0)
                       _ (? l? (re-segs fs2 b h? w?) 0)
                       _ (? s? (re-syms fs2 b w?) 0)
                       1)))))
       ok (foldl (\ a f (? (one f) a 0)) 1 fs)
       _ (flush out) _ (flush err)
       (? ok 0 1))

   (ranlib-main as)
    (: fs (filter (w \ !(1 < #w && w 0 = 45)) as)
       _ (? (two? fs) 0 (udie 1 "Usage: ranlib ARCHIVE.."))
       (one f)
        (: r (uread f)
           (? !(two? r) (: _ (say err ("ranlib: '" + f + "': No such file\n")) 1)
              (: ms (ar-mems <>r)
                 (? (!(two? ms) && !(snip <>r 0 8 = "!<arch>\n"))
                    (: _ (say err ("ranlib: " + f + ": file format not recognized\n")) 1)
                    (: q (open f "w")
                       (? (hot? q) (: _ (say q (arbytes ms)) _ (close q) 0)
                          (: _ (say err ("ranlib: unable to write " + f + "\n")) 1)))))))
       (? (foldl (\ a f (max a (one f))) 0 fs) 1 0))

   ; the registry: name -> main (aliases share)
   applets {'diff diff-main
            'nm nm-main
            'nc (cite 'ain 'ain-main) 'ain (cite 'ain 'ain-main)   ; ain's wrap registered ahead in the cat
            'make (cite 'cook 'cook-main) 'cook (cite 'cook 'cook-main)   ; cook.l's wrap registered ahead in the cat; the map ctor evaluates values
            'as as-main
            'ar ar-main 'ld ld-main
            'size size-main 'strip strip-main 'ranlib ranlib-main 'readelf readelf-main
            'objcopy (cite 'holo 'objcopy)   ; the applet is the function: love/holo/copy.l, module-side
            'cat cat-main 'tac tac-main 'echo echo-main
            'head head-main 'tail tail-main
            'wc wc-main 'sort sort-main 'shuf shuf-main
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
            'base64 base64-main 'base32 base32-main 'basenc basenc-main
            'uuencode uuencode-main 'uudecode uudecode-main 'ascii ascii-main
            'tsort tsort-main 'factor factor-main
            'paste paste-main 'comm comm-main 'split split-main
            'join join-main 'od od-main
            'cksum cksum-main 'sum sum-main 'md5sum md5sum-main 'sha1sum sha1sum-main
            'sha224sum sha224sum-main 'sha256sum sha256sum-main 'sha384sum sha384sum-main
            'sha512sum sha512sum-main 'b2sum b2sum-main 'sha3sum sha3sum-main 'crc32 crc32-main
            'ls ls-main 'dir ls-main   ; one lister, and the name DOS and coreutils ask it by
            'vdir vdir-main   ; ..and coreutils' long one
            'pathchk pathchk-main 'mountpoint mountpoint-main 'shred shred-main
            'fsync fsync-main 'dircolors dircolors-main
            'cp cp-main 'mv mv-main
            'rm rm-main 'mkdir mkdir-main 'rmdir rmdir-main
            'ln ln-main 'touch touch-main 'lift lift-main
            'pwd pwd-main 'chmod chmod-main
            'install install-main 'readlink readlink-main
            'realpath realpath-main 'link link-main 'unlink unlink-main
            'cmp cmp-main
            'stat stat-main 'du du-main 'df df-main 'chown chown-main 'chgrp chgrp-main 'mktemp mktemp-main
            'expr expr-main 'date date-main 'id id-main
            'bc bc-main 'dc dc-main
            'patch patch-main
            'wget wget-main
            'grep grep-main 'sed sed-main
            ; the two old spellings, GNU's own shims: -E and -F said by name
            'egrep (\ as (grep-main ("-E" . as))) 'fgrep (\ as (grep-main ("-F" . as)))
            'awk awk-main 'find find-main
            'vi (cite 'vi 'vi-main)   ; the editor's wrap registered ahead in the cat
            'ed ed-main 'ex ex-main   ; the line editors (apps/kore/ed.l)
            'hexedit hexedit-main
            'less less-main 'more less-main   ; one pager, and the two names it is asked for
            'man man-main    ; the pages the build writes, read back (apps/kore/man.l)
            'html2text html2text-main   ; a page's prose (apps/kore/lens.l), the same lens
            'markdown markdown-main     ; ..and the lens run the way papel runs it
            'www www-main               ; a page to read, its links followed (apps/kore/www.l)
            'telnet telnet-main 'httpd httpd-main   ; a remote terminal, and kiosko (apps/kore/net.l)
            'nslookup nslookup-main 'ping ping-main ; a name's records, and icmp echoes (the same)
            'env env-main 'printenv printenv-main 'sleep sleep-main 'nohup nohup-main
            'nice nice-main 'renice renice-main 'stty stty-main 'truncate truncate-main
            'setsid setsid-main 'watch watch-main 'usleep usleep-main 'ts ts-main
            'getopt getopt-main
            ; the privileged half: chroot is LFS chapter 7's own call, and mount,
            ; umount, sync, mkfifo and mknod are what a root the distro builds
            ; is filled and entered with
            'chroot chroot-main 'mount mount-main 'umount umount-main
            'sync sync-main 'mkfifo mkfifo-main 'mknod mknod-main
            'whoami whoami-main 'groups groups-main
            ; the host's utmp, read: kore keeps none of its own
            'who who-main 'users users-main 'logname logname-main
            ; the archives: gz.l and tar.l register into `verbs` for love's own rail,
            ; and these rows are the same mains under kore's door. they sit in the cat
            ; ahead of this file, so the cite reads now
            'gzip (cite 'gzcmd 'gzip-main) 'gunzip (cite 'gzcmd 'gunzip-main)
            'zcat (cite 'gzcmd 'zcat-main)
            'xz (cite 'xzcmd 'xz-main) 'unxz (cite 'xzcmd 'unxz-main)
            'xzcat (cite 'xzcmd 'xzcat-main) 'unlzma (cite 'xzcmd 'unxz-main)
            'lzcat (cite 'xzcmd 'xzcat-main)
            'bzip2 (cite 'bz2cmd 'bzip2-main) 'bunzip2 (cite 'bz2cmd 'bunzip2-main)
            'bzcat (cite 'bz2cmd 'bzcat-main)
            'tar (cite 'tarcmd 'tar-main) 'cpio (cite 'cpiocmd 'cpio-main)
            ; the byte tools, the clock's other face, and the four one-liners
            'dd dd-main 'xxd xxd-main 'strings strings-main 'hexdump hexdump-main 'hd hd-main
            'cal cal-main 'timeout timeout-main
            'which which-main 'tty tty-main 'clear clear-main 'hostname hostname-main
            'hostid hostid-main 'dnsdomainname dnsdomainname-main 'reset reset-main
            'pinky pinky-main
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
    'head "usage: head [-n N] [-c N] [-N] [FILE..]"
    'tail "usage: tail [-n N] [-c N] [-N] [FILE..]"
    'wc "usage: wc [-lwc] [FILE..]"
    'sort "usage: sort [-bfnrsu] [-k SPEC].. [-t C] [FILE..]"
    'uniq "usage: uniq [-c] [FILE]"
    'shuf "usage: shuf [-rz] [-n N] [-o F] [FILE]  |  shuf -e [ARG..]  |  shuf -i LO-HI"
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
    'sha1sum "usage: sha1sum [-c] [FILE..]"
    'sha224sum "usage: sha224sum [-c] [FILE..]"
    'sha384sum "usage: sha384sum [-c] [FILE..]"
    'sha512sum "usage: sha512sum [-c] [FILE..]"
    'b2sum "usage: b2sum [-c] [-l BITS] [FILE..]"
    'sum "usage: sum [-rs] [FILE..]"
    'vdir "usage: vdir [-aACdlrtx1] [FILE..]"
    'pathchk "usage: pathchk [-pP] [--portability] NAME.."
    'mountpoint "usage: mountpoint [-qd] [--nofollow] DIR  |  mountpoint -x DEV"
    'shred "usage: shred [-fuvxz] [-n N] [-s SIZE] FILE.."
    'setsid "usage: setsid [-cfw] CMD [ARG..]"
    'watch "usage: watch [-begtx] [-n SECS] CMD [ARG..]"
    'hostid "usage: hostid"
    'dnsdomainname "usage: dnsdomainname"
    'sha3sum "usage: sha3sum [-bcS] [-a BITS] [FILE..]"
    'crc32 "usage: crc32 [FILE..]"
    'basenc "usage: basenc --base64|--base64url|--base32|--base32hex|--base16|--base2msbf|--base2lsbf|--z85 [-di] [-w N] [FILE]"
    'uuencode "usage: uuencode [-m] [INFILE] STORED_NAME"
    'uudecode "usage: uudecode [-o OUTFILE] [INFILE]"
    'ascii "usage: ascii"
    'pinky "usage: pinky [-lbhpsfwiq] [USER..]"
    'usleep "usage: usleep MICROSECONDS"
    'reset "usage: reset"
    'ts "usage: ts [-ism] [FORMAT]"
    'fsync "usage: fsync [-d] FILE.."
    'dircolors "usage: dircolors [-b|-c|-p|--print-ls-colors] [FILE]"
    'dc "usage: dc [-e EXPR] [-f FILE] [FILE..]"
    'readelf "usage: readelf -h|-l|-S|-s|-e [-W] FILE.."
    'hexedit "usage: hexedit [-r] FILE"
    'ls "usage: ls [-aACdlrtx1] [FILE..]"
    'dir "usage: dir [-aACdlrtx1] [FILE..]"
    'cp "usage: cp [-f] [-p] [-r] SRC.. DST"
    'mv "usage: mv [-f] SRC.. DST"
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
    'chgrp "usage: chgrp [-R] GROUP FILE.."
    'mktemp "usage: mktemp [-d] [-u] [-q] [-p DIR] [TEMPLATE]"
    'sync "usage: sync   (the bare call; no operands here)"
    'mkfifo "usage: mkfifo [-m MODE] NAME.."
    'mknod "usage: mknod [-m MODE] NAME TYPE [MAJOR MINOR]"
    'expr "usage: expr EXPRESSION"
    'patch "usage: patch [-pN] [-R] [-i F] [-o F] [-s] [--dry-run]"
    'grep "usage: grep [-nvclqhaixwFEo] [-e PAT] [-m N] PATTERN [FILE..]"
    'egrep "usage: egrep [-nvclqhaixwo] [-e PAT] [-m N] PATTERN [FILE..]   (grep -E)"
    'fgrep "usage: fgrep [-nvclqhaixwo] [-e PAT] [-m N] PATTERN [FILE..]   (grep -F)"
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
    'ed ed-usage
    'ex ex-usage
    'env "usage: env [-i] [-u NAME].. [NAME=VALUE].. [CMD [ARG..]]"
    'nohup "usage: nohup CMD [ARG..]"
    'nice "usage: nice [-n N] [CMD [ARG..]]"
    'renice "usage: renice [-n|--relative] PRIORITY [-p|-g|-u] ID.."
    'stty "usage: stty [-F DEV] [-a|-g|SETTING..]"
    'truncate "usage: truncate [-co] [-r RFILE] [-s [+-<>/%]SIZE] FILE.."
    'getopt "usage: getopt [-o SHORTS] [-l LONGS].. [-n NAME] [-aqQTu] [-s sh] [--] PARAMS  |  getopt SHORTS PARAMS"
    'printenv "usage: printenv [NAME..]"
    'sleep "usage: sleep N[smhd].."
    'chroot "usage: chroot DIR [CMD [ARG..]]"
    'mount "usage: mount [-t TYPE] [-o OPTS] SRC TGT   (or bare, to list)"
    'umount "usage: umount TARGET.."
    'whoami "usage: whoami"
    'who "usage: who [-abdHlmpqrstTuw] [FILE | am i]"
    'users "usage: users [FILE]"
    'logname "usage: logname"
    'size "usage: size [-t] [FILE..]"
    'strip "usage: strip [-s|-g] [-p] [-o OUT] FILE.."
    'ranlib "usage: ranlib ARCHIVE.."
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
    'www "usage: www [-w COLS] URL|FILE"
    'telnet "usage: telnet HOST [PORT]"
    'httpd "usage: httpd [-fv] [-p PORT] [-h DIR]"
    'nslookup "usage: nslookup [-type=A|AAAA|CNAME|MX|NS|PTR|SOA|TXT] [-port=N] HOST [SERVER]"
    'ping "usage: ping [-q] [-c COUNT] [-i SECS] [-W SECS] [-s SIZE] HOST"
    'dd "usage: dd [if=F] [of=F] [bs=N] [count=N] [skip=N] [status=none]"
    'xxd "usage: xxd [-r] [FILE..]"
    'hexdump "usage: hexdump [-Cv] [-n LEN] [-s SKIP] [FILE..]"
    'hd "usage: hd [-v] [-n LEN] [-s SKIP] [FILE..]   (hexdump -C)"
    'strings "usage: strings [-n LEN] [FILE..]"
    'cal "usage: cal [[MONTH] YEAR]"
    'timeout "usage: timeout [-s SIG] [-k DURATION] DURATION CMD [ARG..]"
    'which "usage: which [-a] NAME.."
    'tty "usage: tty"
    'clear "usage: clear"
    'hostname "usage: hostname"
    ; the archives keep their own screens: the cmd modules leak them off the same
    ; bodyless letrec the mains come through, so the door shows what the tool would
    'cpio (cite 'cpiocmd 'cpioc-usage)
    'tar (cite 'tarcmd 'usage)
    'gzip (cite 'gzcmd 'gzc-help)
    'gunzip (cite 'gzcmd 'gzc-help)
    'zcat (cite 'gzcmd 'gzc-help)
    'xz (cite 'xzcmd 'xzc-help) 'unxz (cite 'xzcmd 'xzc-help) 'xzcat (cite 'xzcmd 'xzc-help)
    'unlzma (cite 'xzcmd 'xzc-help) 'lzcat (cite 'xzcmd 'xzc-help)
    'bzip2 (cite 'bz2cmd 'bzc-help) 'bunzip2 (cite 'bz2cmd 'bzc-help) 'bzcat (cite 'bz2cmd 'bzc-help)}

   ; echo, test and [ read no options at all -- posix says so, and a script writing
   ; `echo --help` means the word. cook and lush answer the flags themselves, each
   ; with more to say than a synopsis. none of them is at this door.
   korenoflag ['echo 'test (name "[") 'make 'cook 'sh 'lush]
   ; -v is never the door's: gnu gives --version no short spelling, and the letter is the
   ; tool's wherever it wants one (cpio -v names members, grep -v inverts, nl -v numbers).
   ; -h is the door's where it is free -- these spell it themselves, or posix and gnu do.
   korenoh '(grep du df ls sort touch chown ln free readelf pinky httpd)
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
   ; flags at all, which have spoken for -h themselves, and the usage text.
   (koredoor nm f)
    (: (run as) (? !(elem nm korebare) (urun f as)
                   (: w (kobare nm as)
                      (? (nil? w) (urun f as)
                         (: _ (say err (string nm + ": unknown option " + w))
                            _ (put err 10) 2))))
       (? (elem nm korenoflag) run
          (udoor nm run (peep korehelp nm ()) !(elem nm korenoh) 0)))

   kore-usage "kore -- the love multi-call toolbox
usage: kore TOOL ARGS..     (or symlink a tool's name to kore)
every tool answers --help and --version, and -h where the letter is free
  diff OLD NEW       unified diff, patience hunks (0 same / 1 differ / 2 trouble)
  nc HOST PORT       netcat; nc -l PORT listens
  make [FILE] [T..]  the build tool (Cards.l / Cookfile / Makefile)
  as TGT IN OUT      assemble IR forms from IN (x64|a64) into ELF OUT
  ar rcs OUT M..     the archive, GNU shape + ranlib index (ar t OUT lists)
  ld A.o.. -o OUT    holo's static linker (-pie, -t x64|a64|rv64, -Ttext)
  objcopy -O F IN OUT   flatten a linked ELF: F is binary or ihex (Intel HEX)
  nm [-gup] FILE..   an ELF's symbols; -g externals, -u undefined, -p unsorted
  size [-t] F.. | strip [-g] [-o OUT] F.. | ranlib A..   sizes, symbols out, the index in
  cat tac head tail wc sort uniq tee      the line tools (apps/kore/core.l)
  shuf [-rz] [-n N] [-e ARG.. | -i LO-HI | F]   the lines in a random order
  cut tr nl rev                           the field tools
  dos2unix | unix2dos | mac2unix [-fkqn] [F..]   the line endings, converted IN PLACE
  fold [-w N] [-s] [-b] | expand [-t N] [-i] | unexpand [-a] [-t N]   the columns
  base64 | base32 [-d] [-w N] [F]         the encodings (RFC 4648)
  tsort [F] | factor [N..]                the two little computations
  paste comm join split od                the record tools
  cksum | sum [-rs] | md5sum [-c] | sha1sum [-c]   the checksums (apps/kore/sum.l)
  sha224sum | sha256sum | sha384sum | sha512sum [-c] | b2sum [-c] [-l BITS]
  crc32 [F..] | sha3sum [-bcS] [-a BITS] [F..]   zlib's crc, and keccak's digests
  basenc --ENC [-di] [-w N] [F]           every RFC 4648 alphabet, base16, base2, z85
  uuencode [-m] [F] NAME | uudecode [-o OUT] [F] | ascii   the mail armour; the table
  expr EXPRESSION                         arithmetic, comparison and BRE matching
  bc [-l] [-q] [F..]                      the calculator language (apps/kore/bc.l)
  patch [-pN] [-R] [-i F] [--dry-run]     lay a unified diff on a tree
  grep [-nvclqhaixwFEo] [-e P] [-m N] PAT [F..]   BRE, or ERE under -E (apps/kore/re.l)
  egrep | fgrep                           grep -E and grep -F, by their old names
  sed [-nEi] [-e SCRIPT].. SCRIPT [F..]   the stream editor (s///gp, d, p, q, addresses)
  awk [-F FS] [-v var=val].. 'PROG' [F..]  patterns and actions over records
  awk [-F FS] -f PROGFILE.. [F..]          ... the program off a file instead
  find [PATH..] [EXPR]   -name -path -type f|d|l -print -prune -exec CMD.. \\;
                         ( ) ! -a -o -maxdepth N -mindepth N   (PATH defaults to .)
  env printenv sleep kill xargs nohup     the process tools (apps/kore/proc.l)
  nice [-n N] CMD | renice PRIO [-pgu] ID..   the niceness, for a new command or running ones
  setsid [-cfw] CMD | watch [-begtx] [-n S] CMD   a new session; a command every S seconds
  ts [-ism] [FMT] | usleep US | reset | pinky [-lsfwiq] [USER..]   stamps, a pause, the tty, who
  stty [-F DEV] [-a|-g|SETTING..]         the terminal's line discipline, shown or set
  getopt -o SHORTS [-l LONGS] -- PARAMS   options parsed and quoted for `eval set --`
  chroot DIR [CMD [ARG..]]                the root changed, then CMD in it
  mount [-t TYPE] [-o OPTS] SRC TGT       ... or bare, to list /proc/self/mounts
  umount TGT.. | sync                     ... and the two that undo and settle it
  mkfifo [-m MODE] NAME.. | mknod [-m MODE] NAME p|b|c|u [MAJOR MINOR]
  whoami | groups | arch | nproc          the four one-line answers
  who [-abdHlmqTu] | users | logname      the host's utmp, read
  ps [-e] | free [-m|-g] | uptime         what /proc says about the machine
  top [-b] [-n N] [-d SECS] [-p PID]      the process table, repainted
  pidof NAME.. | pgrep [-fx] PAT          .. and about who is running
  pkill [-SIG] [-fx] PAT | killall [-SIG] NAME.. | pwdx PID..
  time [-p] CMD [ARG..]                   what a command costs: real, user, sys
  date [-u] [-d @SEC] [-r F] [+FMT]       the clock, UTC (no tz database here)
  id [-u|-g|-G] [-n]                      who this process is
  vi [FILE]                               the editor (apps/vi/)
  ed [-s] [-p P] [F] | ex [-sRv] [-c CMD] [F]  the line editors (apps/kore/ed.l)
  less | more [-Nise] [+N|+/PAT] [F..]    the pager (apps/kore/less.l); h is its help
  man [-w] [SECTION] NAME..               the manual pages (apps/kore/man.l)
  html2text [-w COLS] [F..]               a page's prose, laid out (apps/kore/lens.l)
  markdown [-t html|roff|text] [F..]      markdown laid out the other way
  www [-w COLS] URL|FILE                  a web page, its links numbered (apps/kore/www.l)
  telnet HOST [PORT]                      a remote terminal; ^] closes (apps/kore/net.l)
  httpd [-fv] [-p PORT] [-h DIR]          kiosko under busybox's flags (apps/kore/net.l)
  nslookup [-type=T] HOST [SERVER]        a name's records, from a nameserver (apps/kore/net.l)
  ping [-q] [-c N] [-i S] [-W S] HOST     icmp echoes and their round trips (apps/kore/net.l)
  sh [-c CMD | FILE]                      the shell, lush (apps/lush.l)
  ls cp mv rm mkdir rmdir ln touch pwd chmod   the fs tools (apps/kore/fs.l)
  install readlink cmp                         ... the build's fs verbs
  realpath [-e|-m|-s] P.. | link F NEW | unlink F   ... the paths and the two calls
  stat [-c FMT] | du [-sabhc] | df [-hia] | chown | chgrp | mktemp   ... and what they report
  truncate [-co] [-r RF] [-s [+-<>/%]N] F..    ... and a file's size, set
  shred [-fuvxz] [-n N] [-s N] F.. | vdir       ... a file overwritten, ls -l's other name
  pathchk [-pP] NAME.. | mountpoint [-qdx] P    ... whether a name would work, or is a mount
  fsync [-d] F.. | dircolors [-b|-c|-p] [F]      ... a file to disk; LS_COLORS spelled
  readelf -h|-l|-S|-s|-e [-W] F..             binutils' view of an ELF file
  dc [-e EXPR] [-f F] | hexedit [-r] F         the stack calculator; the byte editor
  echo seq yes true false basename dirname     ... and the trivia
  gzip | gunzip | zcat [-cdfklnNqrtv19]        the RFC 1952 container (apps/gz.l)
  xz | unxz | xzcat [-cdfkqtz0-9] [-C CHECK]    the .xz container, .lzma read (apps/xz.l)
  bzip2 | bunzip2 | bzcat [-cdfkqtvz1-9]       the block-sorting one (apps/bz2.l)
  tar {c|x|t}[vzjJaO] [-f A] [-C D] [M..]      the ustar archive; z gzip, j bzip2, J xz (apps/tar.l)
  cpio {-o|-i|-t} [-H newc] [-dutv]            ... and the other one (apps/cpio.l)
  dd [if=F] [of=F] [bs=N] [count=N] [skip=N]   blocks in, blocks out
  xxd [-r] [F..] | strings [-n LEN] [F..]      the dump, and the printable runs
  hexdump [-Cv] [-n LEN] [-s SKIP] | hd         the BSD dump, words or -C's bytes
  cal [[MONTH] YEAR]                           a month, laid out (weeks open Sunday)
  timeout [-s SIG] [-k DUR] DUR CMD [ARG..]    a command, and the clock that ends it
  which [-a] NAME.. | tty | clear | hostname   ... and the four short answers
  hostid | dnsdomainname                       ... and what the host's name resolves to
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
