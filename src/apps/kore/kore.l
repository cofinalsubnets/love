; kore: the multi-call userland. one binary picks its tool off the command line, or off argv[0]
; through a tool-named symlink; each tool lives in its own file here and states its own usage.
; loads last in the kore cat, once every tool main is defined, and its leave prunes the module to
; the head below: every <name>-main, the u/text floors later members read bare, and kore-main.
; every path answers a charm through core.l's urun, so an in-image caller lives through a tool
; that would quit: the seat below is the one site that quits, and a main leaves deep through udie
(module (kore kore-main wget-main openssl-main wg-digits wg-lower wg-url wg-resolve wg-header wg-unchunk wg-once wg-fetch wg-name
        www-main ww-split ww-resolve ww-arg ww-get ww-lay ww-dump ww-new ww-show ww-step ww-body ww-fit
        ww-art ww-splice ww-marks ww-pictures ww-hop? wg-plain
        pic-main gpic-main gp-run grap-main gr-run chem-main ch-run pic-cat pic-convert pic-pixelize pic-blocky pic-sample pic-sixel pic-kitty pic-kits pic-near pic-ans pic-type pic-ask pic-heard picless-main pic-kind pic-size pic-decode pic-frames pic-art pic-view pic-deep pic-cells pic-fit pic-probe pic-pick lens-pics
        pv-new pv-step pv-frame pv-tick pv-keys pv-view pv-unkit
        telnet-main telnetd-main td-new td-chunk td-esc httpd-main tn-new tn-byte tn-send tn-echo? nslookup-main ping-main ping6-main ping-ms ping-t traceroute-main traceroute6-main tr-mark
        diff-main as-main ar-main ld-main nm-main ed-main ex-main
        arch-main awk-main base32-main base64-main basename-main bracket-main cat-main
        chgrp-main chmod-main chomp chown-main chroot-main cksum-main cmp-main cnames comm-main cp-main cut-main
        date-main tz-zone udatez dirname-main dos2unix-main dsplit du-main echo-main env-main expand-main expr-main
        mac2unix-main unix2dos-main
        factor-main false-main find-main fold-main column-main free-main getopt-main gfind grep-main groups-main hd-main hexdump-main
        head-main id-main install-main join-main killall-main kill-main lastn less-main lines link-main man-main html2text-main markdown-main
        ln-main ls-main vdir-main md5sum-main mkdir-main mkfifo-main mknod-main mktemp-main mount-main
        mv-main myers nl-main nice-main nohup-main nproc-main
        od-main paste-main patch-main pgrep-main pidof-main pkill-main printenv-main
        printf-main ps-main pwd-main pwdx-main ranlib-main readlink-main realpath-main rebre refind refold renice-main
        rem rev-main rmdir-main rm-main sed-main seq-main sha1sum-main sha224sum-main sha256sum-main
        sha384sum-main sha512sum-main b2sum-main sum-main shuf-main size-main sleep-main
        sort-main sparse split-main srun stat-main strip-main stty-main microcom-main sync-main df-main time-main tac-main tail-main
        tee-main test-main top-main
        touch-main lift-main tr-main true-main truncate-main tsort-main uatoi ubase uclk ucopy udiff udirp ujoin
        umount-main uname-main unexpand-main uniq-main unlink-main uptime-main
        users-main uset usignames usplit ustatf utag utty uupsay wc-main who-main whoami-main xargs-main yes-main
        cal-main clear-main dd-main hostname-main logname-main strings-main timeout-main tty-main
        hostid-main dnsdomainname-main setsid-main watch-main pathchk-main mountpoint-main shred-main
        sha3sum-main crc32-main basenc-main uuencode-main uudecode-main ascii-main pinky-main
        usleep-main reset-main ts-main fsync-main dircolors-main dc-main readelf-main hexedit-main
        which-main xxd-main tz-zone)
(borrow 'cli)  ; the option walk and the -h/-v door, both of them love's floor too
(borrow 'bytes)
(borrow 'holo) ; the assembler module: elf64, arbytes, ld-syms, at -- as/ar/ld/nm read it
(borrow 'posix)
(:
   ; diff: unified hunks (-u is that), -q only whether they differ. directories compare
   ; name by name (`Only in`, -r down common subdirectories, -N a missing side empty); a
   ; file against a directory takes its namesake inside. exit the worst met
   (diff-main as)
    (: fo (uflags "diff" as () "Nqru")
       t <fo ops (fo 1)
       _ (two? ops && two? >ops && atom? >>ops ? () (udie 2 "usage: diff [-Nqru] OLD NEW"))
       fl (take (#as - #ops) as)
       (say1 m) (say out (m + "\n"))
       (text f) ((? (ukind f) (uread f) (t 78) [1 ""] ()) @ r (two? r ? <>r))
       (files fa fb row?)
        (: ta (text fa) tb (text fb)
           (? !(string? ta) (usay-err ("diff: " + fa + ": No such file or directory"), 2)
              !(string? tb) (usay-err ("diff: " + fb + ": No such file or directory"), 2)
              (udiff fa fb ta tb @ d
                 (? !d 0
                    (t 113) (say1 ("Files " + fa + " and " + fb + " differ"), 1)
                    (row? ? (say1 (ujoinc 32 ("diff" . fl + [fa fb]))) 0, puts d, 1)))))
       (names d) (udirp d ? (readdir d))
       (dirs da db)
        (foldl (\ w nm
                  (: pa (da + "/" + nm) pb (db + "/" + nm)
                     ka (ukind pa) kb (ukind pb)
                     da? (udirp pa) db? (udirp pb)
                     r (? (da? && db?) (t 114 ? (dirs pa pb) (say1 ("Common subdirectories: " + pa + " and " + pb), 0))
                          (!ka || !kb) (t 78 ? (da? || db? ? (t 114 ? (dirs pa pb) 0) (files pa pb 1))
                                        (say1 ("Only in " + (ka ? da db) + ": " + nm), 1))
                          (da? || db?) (say1 ("File " + pa + " is a " + (da? ? "directory" "regular file") + " while file "
                                              + pb + " is a " + (db? ? "directory" "regular file")), 1)
                          (files pa pb 1))
                     (max w r)))
               0 (sort (uniq (names da + names db))))
       fa <ops fb <>ops
       r (? (udirp fa && udirp fb) (dirs fa fb)
            (udirp fa) (files (fa + "/" + ubase fb "") fb 0)
            (udirp fb) (files fa (fb + "/" + ubase fa "") 0)
            (files fa fb 0))
       (flush out, r))

   ; as: IR forms -> a runnable ELF (src/love/holo/elf.l over the baked holo book)
   (as-main as)
    (atom? >>as ? (udie 2 "usage: as TARGET IN OUT   (TARGET: x64 | a64)")
     (: tgt (arch-nom <as) src <>as dst <>>as
        _ (tgt = 'x64 || tgt = 'a64 ? ()
           (udie 2 ("as: unknown target " + <as)))
        q (open src "r")
        _ (hot? q ? () (udie 2 ("as: cannot open " + src)))
        ir (sounds (slurp q) @ 'torn (udie 2 ("as: unfinished form in " + src)) fs fs)
        _ (two? ir ? () (udie 2 ("as: no IR forms in " + src)))
        res (elf64 tgt (_ \ ir) ())
        (write-bytes dst (peep res 'bytes 0),
         say err ("as: wrote " + dst), put err 10,
         0)))

   ; ar: GNU's "!<arch>" and llvm-ar's "!<thin>", to the byte, through holo's `arlay` so
   ; mooncc's runtime archive shares the writer. kbuild's verbs: r (q alike; c D P u ignored,
   ; always deterministic), m before or after a member (i b / a), t; s indexes, as by default,
   ; and S leaves the index out. a thin archive names its members by path from its directory,
   ; and a thin archive added to one gives its members, never itself
   ar-usage "usage: ar [-]{r|q|m|t}[cDPsSTuiba] [--thin] [POS] ARCHIVE [MEMBER..]"
   (ar-write dst thin ix ms)
    (open dst "w" @ q
       (hot? q ? () (udie 2 ("ar: cannot write " + dst)),
        say q (arlay thin ix ms),
        close q))
   ; a path's directory with its "/", "" for none; and p as seen from directory d
   (ar-dir p) (: (go k) (k < 0 ? "" (p k = 47 ? (snip p 0 (k + 1)) (go (k - 1)))) (go (#p - 1)))
   ; a path's components, each ".." taking back the one before it
   (ar-parts p) (rev (foldl (\ acc c (? (c = "" || c = ".") acc
                                       (c = ".." && two? acc && <acc != "..") >acc
                                       (c . acc)))
                            () (usplit 47 p)))
   (ar-rel d p)
    (p 0 = 47 ? p
     (: (go a b) (two? a && two? b && <a = <b ? (go >a >b) (ujoinc 47 (map (_ \ "..") a + b)))
        (go (ar-parts d) (ar-parts p))))
   (ar-thin? b) (8 <= #b && snip b 0 8 = "!<thin>\n")
   ; l less its first k; and the first [k bytes] of l as [it rest], [() l] for none
   (ar-less k l) (: (go l acc) (atom? l ? (rev acc) (<l = k ? (rev acc + >l) (go >l (<l . acc)))) (go l ()))
   (ar-pick k l) (: (go l acc) (atom? l ? [() (rev acc)] (<<l = k ? [<l (rev acc + >l)] (go >l (<l . acc))))
                    (go l ()))
   ; an archive at p, bytes b, as [thin ((name bytes)..)]: the index read past, a thin member's
   ; bytes off its file from p's directory; () for bytes that are no archive
   (ar-read p b)
    (: n #b thin (ar-thin? b) d (ar-dir p)
       (lname lt o) (: (go k) (k + 1 < #lt && !(lt k = 47 && lt (k + 1) = 10) ? (go (k + 1)) k)
                       (snip lt o (go o)))
       (name h lt) (1 < #h && h 0 = 47 && 48 <= h 1 && h 1 <= 57 ? (lname lt (ld-arnum (snip h 1 #h)))
                      (#h @ z (0 < z && h (z - 1) = 47 ? (snip h 0 (z - 1)) h)))
       (file nm) (nm 0 = 47 ? nm (d + nm) @ f
                    (uread f @ r (two? r ? <>r (udie 2 ("ar: cannot open " + f)))))
       (go off lt acc)
        (n - off < 60 ? [thin (rev acc)]
         (: h (ld-arfld b off 16) sz (ld-arsz b off) d0 (off + 60)
            meta (h = "/" || h = "//" || h = "/SYM64/")
            nx (thin && !meta ? d0 (off + 60 + sz + sz % 2))
            (? (h = "/" || h = "/SYM64/") (go nx lt acc)
               (h = "//") (go nx (snip b d0 (d0 + sz)) acc)
               (name h lt @ nm (go nx lt ([nm (thin ? (file nm) (snip b d0 (d0 + sz)))] . acc))))))
       (thin || ld-ar? b ? (go 8 "" ())))
   (ar-mems b) (ar-read "" b @ () () r <>r)
   (ar-load p) (uread p @ r
                  (two? r ? (ar-read p <>r @ () (udie 2 ("ar: not an archive: " + p)) a a)
                     (udie 2 ("ar: cannot open " + p))))
   (ar-t p) (map (m \ puts (<m + "\n")) <>(ar-load p), 0)
   (ar-main as)
    (: lead (: (go l acc) (two? l && 1 < #<l && <l 0 = 45 && <l 1 = 45 ? (go >l (<l . acc)) [(rev acc) l])
               (go as ()))
       rest0 <>lead
       _ (two? rest0 ? () (udie 2 ar-usage))
       fl (<rest0 @ f (0 < #f && f 0 = 45 ? (snip f 1 #f) f))
       (has c) (any (k \ fl k = c) ^#fl)
       _ (all (k \ elem (fl k) (chars "rqmtcDPsSTuiba")) ^#fl ? () (udie 2 ("ar: unsupported command " + fl + "; " + ar-usage)))
       _ (all (o \ o = "--thin") <lead ? () (udie 2 ("ar: unsupported option " + (filter (o \ o != "--thin") <lead @ l <l))))
       op (? (has 116) 't (has 109) 'm (has 114 || has 113) 'r (udie 2 ("ar: no operation in " + fl)))
       pos? (op = 'm && (has 105 || has 98 || has 97))
       args >rest0
       _ (two? args && (!pos? || two? >args) ? () (udie 2 "ar: no archive named"))
       pos (pos? ? <args ())
       dst (pos? ? <>args <args)
       fs (pos? ? >>args >args)
       ix !(has 83)
       (op = 't ? (ar-t dst)
        (: old (uread dst @ r (two? r ? (ar-read dst <>r @ () (udie 2 ("ar: not an archive: " + dst)) a a) [0 ()]))
           thin (has 84 || elem "--thin" <lead || <old)
           dd (ar-dir dst)
           (key f) (thin ? (ar-rel dd f) (ubase f ""))
           (op = 'm ?
              (: _ (two? <>old ? () (udie 2 ("ar: cannot open " + dst)))
                 pk (pos? ? (key pos) ())
                 ; each named key moves its first member; the last member named POS marks
                 ; where they land, before it (i, b) or after it (a)
                 (go l ks st mv at)
                  (atom? l ? [(rev st) (rev mv) at]
                   (: m <l at2 (<m = pk ? (has 97 ? (#st + 1) #st) at)
                      (elem <m ks ? (go >l (ar-less <m ks) st (m . mv) at2) (go >l ks (m . st) mv at2))))
                 (go <>old (map key fs) () () () @ [st mv at]
                    (: _ (pos? && !(charm? at) ? (udie 2 ("ar: no member " + pos)) ())
                       k (charm? at ? at #st)
                       (ar-write dst thin ix (take k st + mv + drop k st), 0))))
              (: ; each file, or a thin archive's members when the archive is thin
                 adds (foldl (\ acc f (uread f @ r
                                       (two? r ? (thin && ar-thin? <>r ? (acc + map (m \ [(key (ar-dir f + <m)) <>m]) <>(ar-read f <>r))
                                                    (acc + [[(key f) <>r]]))
                                          (udie 2 ("ar: cannot open " + f)))))
                             () fs)
                 ; an old member a new one names is replaced in place, by the first such; the rest append
                 (go l ns acc) (atom? l ? (rev acc + ns)
                                  (ar-pick <<l ns @ [m rest] (go >l rest ((two? m ? m <l) . acc))))
                 (ar-write dst thin ix (go <>old adds ()), 0))))))

   ; ld: holo's static linker (src/love/holo/link.l) as an applet; -pie the self-relocating
   ; et_dyn, -Ttext the bare-metal org
   (ld-main as)
    (: (num s) (: n #s
                  hex (2 < n && s 0 = 48 && s 1 = 120)
                  (go i a) (i < n ?
                              (go (i + 1) (a * (hex ? 16 10)
                                           + (s i @ b
                                                (? (48 <= b && b < 58) (b - 48)
                                                   (97 <= b && b < 103) (b - 87)
                                                   (65 <= b && b < 71) (b - 55)
                                                   (udie 2 ("ld: bad number " + s))))))
                              a)
                  (go (hex ? 2 0) 0))
       (go a fs o pie org tgt rd)
        (? (atom? a) [(rev fs) o pie org tgt rd]
           (<a = "-o")     (two? >a ? (go >>a fs <>a pie org tgt rd) (udie 2 "ld: -o wants a path"))
           (<a = "-pie")   (go >a fs o 1 org tgt rd)
           (<a = "-t")     (two? >a ? (go >>a fs o pie org (intern <>a) rd) (udie 2 "ld: -t wants a target"))
           (<a = "-Ttext") (two? >a ? (go >>a fs o pie (num <>a) tgt rd) (udie 2 "ld: -Ttext wants an address"))
           ; --readme file: plain text into `.love.README`, for whoever opens the output
           (<a = "--readme") (two? >a ?
                                (uread <>a @ t (two? t ? (go >>a fs o pie org tgt <>t)
                                                (udie 2 ("ld: cannot open " + <>a))))
                                (udie 2 "ld: --readme wants a path"))
           (go >a (<a . fs) o pie org tgt rd))
       r (go as () () 0 () 'x64 ())
       fs <r o <>r pie <>>r org (r 3) tgt (r 4) rdme (r 5)
       _ (two? fs ? () (udie 2 "usage: ld [-pie] [-t x64|a64|rv64] [-Ttext ADDR] [--readme F] A.o.. -o OUT"))
       _ (#o ? () (udie 2 "ld: no -o OUT"))
       srcs (map (f \ (uread f @ r2 (two? r2 ? [f <>r2] (udie 2 ("ld: cannot open " + f))))) fs)
       ps (ldlink tgt pie org srcs ("love " + <(usplit 43 love-version)) rdme)
       (ld-write o ps,
        chmod o 493,
        0))

   ; nm: VALUE type NAME over link.l's ld-syms. the letter is ELF's facts: U undefined,
   ; a absolute, C common, W/w weak (V/v a weak object), else section flags pick
   ; b/t/d/r, a non-alloc section N for debug or n, lowercase for a local bind. sorted by
   ; byte, `LC_ALL=C nm`'s order; -n by value, undefined first; -S adds the size. a64's
   ; $x/$d mapping symbols are not shown. an archive is not walked (that is `ar t`'s)
   (nm-sp w) (w < 1 ? "" (nm-sp (w - 1) + " "))
   (nm-hex v w) (: dg "0123456789abcdef"
                   (go k a) (k < 0 ? a (go (k - 1) (a + string (dg (v // k 16 % 16)))))
                   (go (w - 1) ""))
   (nm-let sy)
    (: x (sy 3) sec (sy 6) bd (sy 1)
       (up c) (? (97 <= c && c <= 122) (c - 32) c)
       c (? (bd = 2) (: k (sy 2 = 1 ? 118 119) (x = 0 ? k (up k)))
            (x = 0) 85 (x = 65522) 67
            (: l (? (x = 65521) 97 (atom? sec) 63
                    (: fl (sec 2)
                       (? (0 < fl & 2147483648) 101 (sec 1 = 8) 98 (0 < fl & 4) 116
                          (0 < fl & 2) (0 < fl & 1 ? 100 114)
                          (: n <sec (#n >= 6 && snip n 0 6 = ".debug" ? 78 (0 < fl & 1 ? 63 110))))))
               (? (bd = 0) l (bd = 10) 117 (up l))))
       (string [c]))
   (nm-file p wide g u srt num sz)
    (: r (uread p) _ (two? r ? () (udie 2 ("nm: cannot open " + p)))
       b <>r
       w (b 4 = 2 ? 16 8)
       a64 (b 18 = 183 && b 19 = 0)
       ; a section or file symbol names no value of the program's -- nm shows
       ; neither, and an empty name is the null-ish filler a section symbol leaves
       all (filter (sy \ (? !#<sy () (elem (sy 2) '(3 4)) ()
                            (a64 && <sy 0 = 36 && #<sy > 1 && (<sy 1 = 100 || <sy 1 = 120)) () 1))
                   (ld-syms p b))
       ; "no symbols" is the file's fact, asked before the flags narrow: a -u that
       ; comes back empty says the lanes are all ours, which is an answer, not a lack
       _ (two? all ? () (say err ("nm: " + p + ": no symbols"), put err 10, 1))
       keep (filter (sy \ (? (g && sy 1 = 0) () (u && !(sy 3 = 0)) () 1)) all)
       (def? sy) (? (sy 3 = 0) 0 1)
       ord (? num (map (k \ k 4) (sort (map (sy \ [(def? sy) (sy 4) <sy (sy 5) sy]) keep)))
              srt keep
              (sortby (\ a b (<a <= <b)) keep))
       (wide ? (puts ("\n" + p + ":\n"), 0) 0,
        ; foldl is the printing walk: it answers the accumulator, so nothing is built
        foldl (\ _ sy (puts ((sy 3 = 0 ? (nm-sp w) (nm-hex (sy 4) w))
                             + (sz ? (" " + (sy 3 = 0 ? (nm-sp w) (nm-hex (sy 5) w))) "")
                             + " " + nm-let sy + " " + <sy + "\n")))
              0 ord,
        two? all))
   (nm-main as)
    ; flags cluster: -gu is -g -u, which is what a hand types and what nm takes
    (: (nm-flags t k f)
        (#t <= k ? f
         (t k @ c
            (? (c = 103) (nm-flags t (k + 1) (pin f 'g 1))
               (c = 117) (nm-flags t (k + 1) (pin f 'u 1))
               (c = 112) (nm-flags t (k + 1) (pin f 'p 1))
               (c = 110) (nm-flags t (k + 1) (pin f 'n 1))
               (c = 83) (nm-flags t (k + 1) (pin f 'S 1))
               (udie 2 ("nm: unknown flag -" + string c)))))
       (go a f fs)
        (? (atom? a) [f (rev fs)]
           (1 < tally <a && <a 0 = 45) (go >a (nm-flags <a 1 f) fs)
           (go >a f (<a . fs)))
       r (go as {} ())
       f <r fs <>r
       _ (two? fs ? () (udie 2 "usage: nm [-g] [-u] [-p] [-n] [-S] FILE.."))
       wide (two? >fs)
       any (foldl (\ a p (nm-file p wide (f 'g) (f 'u) (f 'p) (f 'n) (f 'S) ? 1 a)) () fs)
       (flush out,
        any ? 0 1))

   ; -- size, strip, ranlib over holo's ELF field table and archive writer, little-endian
   ; ELF of either class; a section is (index name type flags off size link info align header-bytes) --
   (bu-put fs h nm v) (: r (ld-row fs nm) o <r w <>r (snip h 0 o + wrle v w + snip h (o + w) #h))
   (bu-elf? b) (20 <= #b && b 0 = 127 && b 1 = 69 && b 2 = 76 && b 3 = 70 && b 5 = 1
                && (b 4 = 1 || b 4 = 2))
   (bu-fs b) (b 4 = 2 ? elf64f elf32f)
   (bu-secs fs b)
    (: shoff (ld-f fs b 0 'e-shoff) n (ld-f fs b 0 'e-shnum) e (ld-n fs 'sh-ent)
       sx (ld-f fs b 0 'e-shstrx)
       stro (sx < n ? (ld-f fs b (shoff + sx * e) 'sh-off) 0)
       (map (i \ (shoff + i * e @ h
                    [i (ld-cstr b (stro + ld-f fs b h 'sh-name)) (ld-f fs b h 'sh-type)
                     (ld-f fs b h 'sh-flags) (ld-f fs b h 'sh-off) (ld-f fs b h 'sh-size)
                     (ld-f fs b h 'sh-link) (ld-f fs b h 'sh-info) (ld-f fs b h 'sh-align)
                     (snip b h (h + e))]))
            ^n))
   ; binutils' berkeley sums: allocated code or read-only is text, allocated with bytes
   ; is data, allocated without is bss
   (bu-berk b)
    (foldl (\ a sc (: fl (sc 3) sz (sc 5)
                      (? (fl & 2 = 0) a
                         (0 < fl & 4 || fl & 1 = 0) [(a 0 + sz) (a 1) (a 2)]
                         !(sc 2 = 8) [(a 0) (a 1 + sz) (a 2)]
                         [(a 0) (a 1) (a 2 + sz)])))
           [0 0 0] (bu-secs (bu-fs b) b))
   (size-main as)
    (: t? (elem "-t" as || elem "--totals" as)
       bad (filter (w \ 1 < #w && w 0 = 45 && !(elem w '("-t" "--totals" "-B" "-d" "--format=berkeley"
                                                        "--format=bsd" "--radix=10"))) as)
       _ (two? bad ? (udie 1 ("size: " + <bad + " is not here (the berkeley format, decimal, and -t)")) 0)
       fs0 (filter (w \ !(1 < #w && w 0 = 45)) as)
       fs (two? fs0 ? fs0 ["a.out"])
       hd {0 0}
       (row s nm)
        (: _ (hd 0 ? 0 (pin hd 0 1, puts "   text\t   data\t    bss\t    dec\t    hex\tfilename\n"))
           d (s 0 + s 1 + s 2)
           (puts (upad 7 (show (s 0)) + "\t" + upad 7 (show (s 1)) + "\t" + upad 7 (show (s 2)) + "\t"
                  + upad 7 (show d) + "\t" + upad 7 (radix d 16) + "\t" + nm + "\n")))
       ; the status is the last trouble's: 1 a file not there, 3 one not an object
       (add a s) [(a 0 + s 0) (a 1 + s 1) (a 2 + s 2) (0 < s 3 ? (s 3) (a 3))]
       (bad c m) (say err ("size: " + m + "\n"), [0 0 0 c])
       (one a f)
        (uread f @ r
           (atom? r ? (add a (bad 1 ("'" + f + "': No such file")))
            (: b <>r ms (ar-mems b)
               (? (bu-elf? b) (bu-berk b @ s
                                 (row s f, add a (s + [0])))
                  (two? ms)
                   (foldl (\ a2 m (bu-elf? <>m ? (bu-berk <>m @ s
                                                    (row s (<m + " (ex " + f + ")"), add a2 (s + [0])))
                                   (add a2 (bad 3 (<m + ": file format not recognized")))))
                          a ms)
                  (add a (bad 3 (f + ": file format not recognized")))))))
       tot (foldl one [0 0 0 0] fs)
       (t? ? (row tot "(TOTALS)") 0,
        flush out,
        tot 3))

   ; strip: the symbol table and debugging sections out; -g the debugging alone, all a
   ; relocatable may lose. what the loader maps stays put; the unmapped move up behind it
   (bu-dbg? nm) (: (pre p) (#p <= #nm && snip nm 0 #p = p)
                   (pre ".debug" || pre ".zdebug" || pre ".stab" || pre ".gnu.debuglto_" || pre ".line"))
   (bu-strip b all?)                   ; -> the stripped bytes
    (: fs (bu-fs b)
       w64 (b 4 = 2)
       secs (bu-secs fs b)
       sx (ld-f fs b 0 'e-shstrx)
       na (sc \ (sc 3 & 2) = 0)
       g0 (map (sc \ (<sc > 0) && na sc && (all? && sc 2 = 2 || bu-dbg? (sc 1))) secs)
       (linked-by i gs) (foldl (\ a sc (a || sc 6 = i && gs <sc ? 1 0)) 0 secs)
       (kept-link? i gs) (foldl (\ a sc (a || sc 6 = i && !(gs <sc) ? 1 0)) 0 secs)
       g1 (map (sc \ (g0 <sc) || (sc 2 = 3 && na sc && !(<sc = sx)
                                   && linked-by <sc g0 && !(kept-link? <sc g0))) secs)
       gone (map (sc \ (g1 <sc) || ((sc 2 = 4 || sc 2 = 9) && na sc
                                     && (0 < sc 7 && sc 7 < #secs && g1 (sc 7)
                                         || 0 < sc 6 && sc 6 < #secs && g1 (sc 6)))) secs)
       keep (filter (sc \ !(gone <sc)) secs)
       (#keep = #secs ? b
        (: map1 (foldl (\ t sc (pin t <sc #(keys t))) {} keep)
           (nx i) (peep map1 i 0)
           ehs (w64 ? 64 52)
           phend (: po (ld-f fs b 0 'e-phoff) pn (ld-f fs b 0 'e-phnum) pe (ld-n fs 'ph-ent)
                    (foldl (\ a k (po + k * pe @ h (max a (ld-f fs b h 'ph-off + ld-f fs b h 'ph-fsz))))
                           (pn ? (po + pn * pe) 0) ^pn))
           base (foldl (\ a sc (na sc || sc 2 = 8 ? a (max a (sc 4 + sc 5)))) (max ehs phend) keep)
           ; the name table, each kept name once, in section order
           nt (foldl (\ a sc (<sc = 0 ? a [(<a + sc 1 + string 0) (pin <>a <sc #<a)]))
                     [(string 0) {}] keep)
           names <nt noff <>nt
           ; the unmapped sections laid behind the mapped bytes, the name table among them
           lay (foldl (\ a sc (: al (max 1 (sc 8)) at (ld-align al <a)
                                 body (? (<sc = sx) names
                                         (sc 2 = 2 && !all?) (bu-symfix fs (snip b (sc 4) (sc 4 + sc 5)) nx)
                                         (sc 2 = 8) "" (snip b (sc 4) (sc 4 + sc 5)))
                                 (!(na sc) || <sc = 0 ? a
                                  [(at + #body) (pin <>a <sc at)
                                   (<>>a + [(ld-zeros (at - <a)) body])])))
                      [base {} ()] keep)
           shoff (ld-align (w64 ? 8 4) <lay)
           offs <>lay
           hdrs (map (sc \ (: h0 (sc 9)
                              h1 (bu-put fs h0 'sh-name (peep noff <sc 0))
                              h2 (peep offs <sc -1 @ o (o < 0 ? h1 (bu-put fs h1 'sh-off o)))
                              h3 (<sc = sx ? (bu-put fs h2 'sh-size #names) h2)
                              h4 (0 < sc 6 ? (bu-put fs h3 'sh-link (nx (sc 6))) h3)
                              ((sc 2 = 4 || sc 2 = 9 || 0 < sc 3 & 64) && 0 < sc 7 ?
                                 (bu-put fs h4 'sh-info (nx (sc 7))) h4)))
                     keep)
           eh (bu-put fs (bu-put fs (bu-put fs (snip b 0 ehs) 'e-shoff shoff) 'e-shnum #keep)
                      'e-shstrx (nx sx))
           (foldl (\ a p (a + (string? p ? p (foldl (\ s z (s + string z)) "" p))))
                  ""
                  ([eh (snip b ehs base)] + <>>lay + [(ld-zeros (shoff - <lay))] + hdrs)))))
   (bu-symfix fs s nx)                 ; a kept symbol table's section numbers, renumbered
    (: e (ld-n fs 'sy-ent) n (#s // e)
       (foldl (\ acc i (: h (snip s (i * e) (i * e + e)) x (ld-f fs h 0 'sy-shndx)
                         (acc + (0 < x && x < 65280 ? (bu-put fs h 'sy-shndx (nx x)) h))))
              "" ^n))
   (strip-main as)
    (: dbg (foldl (\ a w (a || elem w '("-g" "-S" "-d" "--strip-debug"))) 0 as)
       (go a o fs)
        (atom? a ? [o (rev fs)]
         (<a @ w
            (? (w = "-o") (two? >a ? (go >>a <>a fs) (udie 1 "strip: option requires an argument -- 'o'"))
               (elem w '("-g" "-S" "-d" "--strip-debug" "-s" "--strip-all" "--strip-unneeded" "-p" "--preserve-dates"))
                (go >a o fs)
               (1 < #w && w 0 = 45) (udie 1 ("strip: " + w + " is not here (-s -g -o -p)"))
               (go >a o (w . fs)))))
       r (go as () ())
       o <r fs <>r
       p? (elem "-p" as || elem "--preserve-dates" as)
       _ (two? fs ? 0 (udie 1 "Usage: strip [-s|-g] [-p] [-o OUT] FILE.."))
       _ (o && two? >fs ? (udie 1 "strip: -o wants one input file") 0)
       (warn m) (say err ("strip: " + m + "\n"), 1)
       (one f)
        (uread f @ rd
           (atom? rd ? (warn ("'" + f + "': No such file"))
            (<>rd @ b
               (? !(bu-elf? b) (warn (f + ": file format not recognized"))
                  (!dbg && b 16 + 256 * b 17 = 1)
                   (warn (f + ": a relocatable object keeps its symbols here (-g takes its debugging)"))
                  (: out (bu-strip b !dbg)
                     dst (o ? o f)
                     st (stat f)
                     q (open dst "w")
                     (!(hot? q) ? (warn ("unable to write " + dst))
                        (say q out, close q, two? st ? (chmod dst (st 2 & 4095)) 0, p? && two? st ? (utime dst (st 1)) 0, 0)))))))
       (foldl (\ a f (max a (one f))) 0 fs ? 1 0))

   ; ranlib: an archive written again with the index holo's reader wants
   ; -- readelf: -h -l -S -s (-e all three), little-endian ELF of either class; no
   ; relocations, dynamic section, notes or versions --
   (re-hex v w) (zpad w (v = 0 ? "0" (radix v 16)))
   (re-0x v) ("0x" + (v = 0 ? "0" (radix v 16)))
   (re-u v w) (upad w (show v))
   (re-cut s w) (w < #s ? (snip s 0 (w - 5) + "[...]") s)
   (re-at s w) (w < #s ? (snip s 0 w) s)
   (re-lbl l) ("  " + urpad 35 l)
   (re-mach m) (m @ 3 "Intel 80386" 40 "ARM" 62 "Advanced Micro Devices X86-64" 183 "AArch64"
                    243 "RISC-V" 8 "MIPS R3000" 20 "PowerPC" 21 "PowerPC64" ("<unknown>: 0x" + radix m 16))
   (re-osabi o) (o @ 0 "UNIX - System V" 1 "UNIX - HP-UX" 2 "UNIX - NetBSD" 3 "UNIX - GNU" 6 "UNIX - Solaris"
                     9 "UNIX - FreeBSD" 12 "UNIX - OpenBSD" ("<unknown: " + radix o 16 + ">"))
   (re-dyn fs b)                        ; the dynamic section's (tag . value) pairs
    (: w (b 4 = 2 ? 8 4)
       d (filter (sc \ (sc 2 = 6)) (bu-secs fs b))
       (atom? d ? ()
        (: o (<d 4) n (<d 5 // (2 * w))
           (map (i \ [(rdle b (o + 2 * w * i) w) (rdle b (o + 2 * w * i + w) w)]) ^n))))
   (re-type fs b t)
    (t @ 0 "NONE (None)" 1 "REL (Relocatable file)" 2 "EXEC (Executable file)" 4 "CORE (Core file)"
         3 (any (p \ (<p = 1879048187 && 0 < <>p & 134217728)) (re-dyn fs b) ?
              "DYN (Position-Independent Executable file)" "DYN (Shared object file)")
         ("<unknown>: " + radix t 16))
   (re-flags b m f)
    ("0x" + radix f 16
     + (? (m = 40) (f >> 24 ? (", Version" + show (f >> 24) + " EABI"
                             + (? (f & 1024) ", hard-float ABI" (f & 512) ", soft-float ABI" "")) "")
          (m = 243) ((f & 1 ? ", RVC" "") + ([", soft-float ABI" ", single-float ABI" ", double-float ABI" ", quad-float ABI"] ((f & 6) >> 1))
                     + (f & 8 ? ", RVE" "") + (f & 16 ? ", TSO" ""))
          ""))
   (re-head fs b)
    (: e64 (b 4 = 2) m (rdle b 18 2) f (rdle b (e64 ? 48 36) 4)
       (row l v) (say out (re-lbl l + v + "\n"))
       (say out "ELF Header:\n  Magic:   ",
        map (i \ (say out (re-hex (b i) 2 + " "))) ^16,
        say out "\n",
        row "Class:" (e64 ? "ELF64" "ELF32"),
        row "Data:" "2's complement, little endian",
        row "Version:" (show (b 6) + (b 6 = 1 ? " (current)" "")),
        row "OS/ABI:" (re-osabi (b 7)),
        row "ABI Version:" (show (b 8)),
        row "Type:" (re-type fs b (rdle b 16 2)),
        row "Machine:" (re-mach m),
        row "Version:" (re-0x (rdle b 20 4)),
        row "Entry point address:" (re-0x (ld-f fs b 0 'e-entry)),
        row "Start of program headers:" (show (ld-f fs b 0 'e-phoff) + " (bytes into file)"),
        row "Start of section headers:" (show (ld-f fs b 0 'e-shoff) + " (bytes into file)"),
        row "Flags:" (re-flags b m f),
        row "Size of this header:" (show (rdle b (e64 ? 52 40) 2) + " (bytes)"),
        row "Size of program headers:" (show (ld-f fs b 0 'e-phent) + " (bytes)"),
        row "Number of program headers:" (show (ld-f fs b 0 'e-phnum)),
        row "Size of section headers:" (show (ld-f fs b 0 'e-shent) + " (bytes)"),
        row "Number of section headers:" (show (ld-f fs b 0 'e-shnum)),
        row "Section header string table index:" (show (ld-f fs b 0 'e-shstrx))))
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
       (1610612736 <= t && t < 1879048192) ("LOOS+0x" + radix (t - 1610612736) 16)
       (1879048192 <= t && t < 2147483648) ("LOPROC+0x" + radix (t - 1879048192) 16)
       (2147483648 <= t) ("LOUSER+0x" + radix (t - 2147483648) 16)
       (re-hex t 8 + ": <unknown>"))
   (re-shflags b m f)
    (: gnu (b 7 = 3 || b 7 = 9)
       (go bit o) (32 <= bit ? o
                   (1 << bit @ v
                      (0 = f & v ? (go (bit + 1) o)
                       ((? (bit < 12) ("WAX?MSILOGTC" bit)
                           (v = 2097152 && gnu) 82
                           (v = 268435456 && m = 62) 108
                           (v = 536870912 && m = 40) 121
                           (v = 2147483648) 69
                           (0 < v & 267386880) 111
                           (0 < v & 4026531840) 112
                           120) @ c
                          (go (bit + 1) (elem c o ? o (o + string c)))))))
       (go 0 ""))
   (re-keys b m)
    ("Key to Flags:\n  W (write), A (alloc), X (execute), M (merge), S (strings), I (info),\n"
     + "  L (link order), O (extra OS processing required), G (group), T (TLS),\n"
     + "  C (compressed), x (unknown), o (OS specific), E (exclude),\n  "
     + (b 7 = 3 || b 7 = 9 ? "R (retain), " "") + "D (mbind), "
     + (m @ 62 "l (large), " 40 "y (purecode), " "") + "p (processor specific)\n")
   (re-secs fs b w? h?)
    (: e64 (b 4 = 2) m (rdle b 18 2) ss (bu-secs fs b)
       (ent sc) (ld-f fs b 0 'e-shoff + sc 0 * ld-n fs 'sh-ent)
       (addr sc) (rdle b (ent sc + (e64 ? 16 12)) (e64 ? 8 4))
       (esz sc) (ld-f fs b (ent sc) 'sh-esz)
       (atom? ss ? (say out "\nThere are no sections in this file.\n")
        ((h? ? (say out "\n")
                (say out ("There are " + show #ss + " section headers, starting at offset " + re-0x (ld-f fs b 0 'e-shoff) + ":\n\n"))), say out (#ss = 1 ? "Section Header:\n" "Section Headers:\n"), say out (? !e64 "  [Nr] Name              Type            Addr     Off    Size   ES Flg Lk Inf Al\n"
                         w? "  [Nr] Name              Type            Address          Off    Size   ES Flg Lk Inf Al\n"
                         "  [Nr] Name              Type             Address           Offset\n       Size              EntSize          Flags  Link  Info  Align\n"), map (sc \
                                                                                                                                                                                (: nm (sc 1) ty (re-at (re-shtype m (sc 2)) 15) fl (re-shflags b m (sc 3))
                                                                                                                                                                                   hd ("  [" + re-u (sc 0) 2 + "] " + urpad 17 (w? ? nm (re-cut nm 17)) + " ")
                                                                                                                                                                                   (say out (!e64 || w? ?
                                                                                                                                                                                               (hd + urpad 15 ty + " " + re-hex (addr sc) (e64 ? 16 8) + " " + re-hex (sc 4) 6 + " "
                                                                                                                                                                                                + re-hex (sc 5) 6 + " " + re-hex (esz sc) 2 + " " + upad 3 fl + " " + re-u (sc 6) 2
                                                                                                                                                                                                + " " + re-u (sc 7) 3 + " " + re-u (sc 8) 2 + "\n")
                                                                                                                                                                                               (hd + urpad 15 ty + "  " + re-hex (addr sc) 16 + "  " + re-hex (sc 4) 8 + "\n       "
                                                                                                                                                                                                + re-hex (sc 5) 16 + "  " + re-hex (esz sc) 16 + " " + upad 3 fl + "      "
                                                                                                                                                                                                + re-u (sc 6) 2 + "   " + re-u (sc 7) 3 + "     " + show (sc 8) + "\n")))))
                  ss, say out (re-keys b m))))
   (re-phtype m t)
    (? (t < 8) (["NULL" "LOAD" "DYNAMIC" "INTERP" "NOTE" "SHLIB" "PHDR" "TLS"] t)
       (t = 1685382480) "GNU_EH_FRAME" (t = 1685382481) "GNU_STACK" (t = 1685382482) "GNU_RELRO"
       (t = 1685382483) "GNU_PROPERTY" (t = 1685382484) "GNU_SFRAME"
       (m = 40 && t = 1879048193) "EXIDX" (m = 243 && t = 1879048195) "RISCV_ATTRIBUT"
       (1610612736 <= t && t < 1879048192) ("LOOS+0x" + radix (t - 1610612736) 16)
       (1879048192 <= t && t < 2147483648) ("LOPROC+0x" + radix (t - 1879048192) 16)
       ("<unknown>: " + radix t 16))
   (re-phs fs b)                        ; [type off vaddr paddr filesz memsz flags align]
    (: e64 (b 4 = 2) o (ld-f fs b 0 'e-phoff) n (ld-f fs b 0 'e-phnum) e (ld-f fs b 0 'e-phent)
       (map (i \ (o + i * e @ h
                    (e64 ? [(rdle b h 4) (rdle b (h + 8) 8) (rdle b (h + 16) 8) (rdle b (h + 24) 8) (rdle b (h + 32) 8)
                            (rdle b (h + 40) 8) (rdle b (h + 4) 4) (rdle b (h + 48) 8)]
                       [(rdle b h 4) (rdle b (h + 4) 4) (rdle b (h + 8) 4) (rdle b (h + 12) 4) (rdle b (h + 16) 4)
                        (rdle b (h + 20) 4) (rdle b (h + 24) 4) (rdle b (h + 28) 4)])))
            ^n))
   ; binutils' ELF_SECTION_IN_SEGMENT, strictly, the tbss case aside: the arithmetic is
   ; unsigned, so a size of 0 less 1 is every address
   (re-in? sc p)
    (: ty (sc 2) fl (sc 3) off (sc 4) sz (sc 5) addr (sc 10) pt <p
       tls (0 < fl & 1024) alloc (0 < fl & 2) nob (ty = 8)
       (le1 x v) (v = 0 || x <= v - 1)       ; x <= v - 1, unsigned
       ssz (!tls || !nob || pt = 7 ? sz 0)
       (? (tls && nob && !(pt = 7)) 0
          !(tls ? (pt = 7 || pt = 1685382482 || pt = 1) !(pt = 7 || pt = 6)) 0
          (!alloc && elem pt [1 2 1685382480 1685382481 1685382482 1685382484]) 0
          !(nob || p 1 <= off && le1 (off - p 1) (p 4) && off - p 1 + ssz <= p 4) 0
          !(!alloc || p 2 <= addr && le1 (addr - p 2) (p 5) && addr - p 2 + ssz <= p 5) 0
          (!(pt = 2 || pt = 4) || !(sz = 0) || p 5 = 0) 1
          ((nob || p 1 < off && off - p 1 < p 4) && (!alloc || p 2 < addr && addr - p 2 < p 5))))
   (re-segs fs b h? w?)
    (: e64 (b 4 = 2) m (rdle b 18 2) ps (re-phs fs b)
       ss (map (sc \ (sc + [(rdle b (ld-f fs b 0 'e-shoff + sc 0 * ld-n fs 'sh-ent + (e64 ? 16 12)) (e64 ? 8 4))]))
               (drop 1 (bu-secs fs b)))
       (atom? ps ? (say out "\nThere are no program headers in this file.\n")
        (: _ (h? ? 0
                (say out ("\nElf file type is " + re-type fs b (rdle b 16 2) + "\nEntry point " + re-0x (ld-f fs b 0 'e-entry)
                          + "\nThere are " + show #ps + " program headers, starting at offset " + show (ld-f fs b 0 'e-phoff) + "\n")))
           _ (say out (? !e64 "\nProgram Headers:\n  Type           Offset   VirtAddr   PhysAddr   FileSiz MemSiz  Flg Align\n"
                         w? "\nProgram Headers:\n  Type           Offset   VirtAddr           PhysAddr           FileSiz  MemSiz   Flg Align\n"
                         "\nProgram Headers:\n  Type           Offset             VirtAddr           PhysAddr\n                 FileSiz            MemSiz              Flags  Align\n"))
           (fl f) (string (f & 4 ? 82 32) + string (f & 2 ? 87 32) + string (f & 1 ? 69 32))
           (map (p \
                     (say out ("  " + urpad 14 (re-at (re-phtype m <p) 14) + " "
                                    + (? (e64 && w?) ("0x" + re-hex (p 1) 6 + " 0x" + re-hex (p 2) 16 + " 0x" + re-hex (p 3) 16 + " 0x" + re-hex (p 4) 6
                                                   + " 0x" + re-hex (p 5) 6 + " " + fl (p 6) + " " + re-0x (p 7))
                                         e64 ("0x" + re-hex (p 1) 16 + " 0x" + re-hex (p 2) 16 + " 0x" + re-hex (p 3) 16
                                              + "\n                 0x" + re-hex (p 4) 16 + " 0x" + re-hex (p 5) 16 + "  " + fl (p 6) + "    " + re-0x (p 7))
                                         ("0x" + re-hex (p 1) 6 + " 0x" + re-hex (p 2) 8 + " 0x" + re-hex (p 3) 8 + " 0x" + re-hex (p 4) 5
                                          + " 0x" + re-hex (p 5) 5 + " " + fl (p 6) + " " + re-0x (p 7)))
                                    + "\n"), <p = 3 ? (say out ("      [Requesting program interpreter: " + ld-cstr b (p 1) + "]\n")) 0))
                ps,
            say out "\n Section to Segment mapping:\n  Segment Sections...\n",
            map (i \ (ps i @ p
                        (say out ("   " + zpad 2 (show i) + "     "
                                  + foldl (\ a sc (re-in? sc p ? (a + sc 1 + " ") a)) "" ss + "\n"))))
                ^#ps))))
   ; a version index's name, off .gnu.version_r (what the file needs) and
   ; .gnu.version_d (what it defines): a tablet of index -> [name needed?]
   (re-vers ss b)
    (: t {}
       (str sc o) (ld-cstr b (ss (sc 6) 4 + o))
       (need sc)
        (: (vn o k) (k < 1 ? 0
                     (: cnt (rdle b (o + 2) 2) aux (rdle b (o + 8) 4) nx (rdle b (o + 12) 4)
                        (va a j) (j < 1 ? 0
                                  (pin t (rdle b (a + 6) 2) [(str sc (rdle b (a + 8) 4)) 1], va (a + rdle b (a + 12) 4) (j - 1)))
                        (va (o + aux) cnt,
                         nx = 0 ? 0 (vn (o + nx) (k - 1)))))
           (vn (sc 4) (sc 7)))
       (def sc)
        (: (vd o k) (k < 1 ? 0
                     (: ndx (rdle b (o + 4) 2) aux (rdle b (o + 12) 4) nx (rdle b (o + 16) 4)
                        (pin t ndx [(str sc (rdle b (o + aux) 4)) 0],
                         nx = 0 ? 0 (vd (o + nx) (k - 1)))))
           (vd (sc 4) (sc 7)))
       (map (sc \ (? (sc 2 = 1879048190) (need sc) (sc 2 = 1879048189) (def sc) 0)) ss,
        t))
   (re-syms fs b w?)
    (: e64 (b 4 = 2) ss (bu-secs fs b) es (e64 ? 24 16)
       vt (re-vers ss b)
       vs (filter (sc \ (sc 2 = 1879048191)) ss)
       (sym o k) (o + k * es @ h
                    (e64 ? [(rdle b h 4) (b (h + 4)) (b (h + 5)) (rdle b (h + 6) 2) (rdle b (h + 8) 8) (rdle b (h + 16) 8)]
                       [(rdle b h 4) (b (h + 12)) (b (h + 13)) (rdle b (h + 14) 2) (rdle b (h + 4) 4) (rdle b (h + 8) 4)]))
       (styp t) (? (t < 7) (["NOTYPE" "OBJECT" "FUNC" "SECTION" "FILE" "COMMON" "TLS"] t) (t = 10) "IFUNC"
                   (13 <= t) ("<processor specific>: " + show t) ("<OS specific>: " + show t))
       (sbind t) (? (t < 3) (["LOCAL" "GLOBAL" "WEAK"] t) (t = 10) "UNIQUE"
                    (13 <= t) ("<processor specific>: " + show t) ("<OS specific>: " + show t))
       (ndx x) (upad 4 (? (x = 0) "UND" (x = 65521) "ABS" (x = 65522) "COM" (65280 <= x) ("PRC[0x" + re-hex x 4 + "]") (show x)))
       (szs v) (v < 100000 ? (re-u v 5) (re-0x v))
       (map (st \
                  (: n (st 5 // es) stro (st 6 < #ss ? (ss (st 6) 4) 0)
                     _ (say out ("\nSymbol table '" + st 1 + "' contains " + show n + " " + (n = 1 ? "entry" "entries") + ":\n"
                                 + (e64 ? "   Num:    Value          Size Type    Bind   Vis      Ndx Name\n"
                                      "   Num:    Value  Size Type    Bind   Vis      Ndx Name\n")))
                     vsec (st 2 = 11 ? (filter (v \ (v 6 = st 0)) vs))
                     ; a needed version says its index; a defined one says @@, or @ where hidden,
                     ; and nothing on the symbol that names the version itself
                     (ver k y nm0) (atom? vsec ? ""
                                    (: x (rdle b (<vsec 4 + 2 * k) 2) i (x & 32767) e (vt i)
                                       (? (i < 2 || atom? e) ""
                                          (y 3 = 0 || <>e) ("@" + <e + " (" + show i + ")")
                                          (<e = nm0) ""
                                          (x & 32768) ("@" + <e) ("@@" + <e))))
                     (map (k \ (: y (sym (st 4) k) t (y 1 & 15)
                                  nm0 (t = 3 && y 0 = 0 && y 3 < #ss ? (ss (y 3) 1) (ld-cstr b (stro + y 0)))
                                  v (ver k y nm0)
                                  nm (w? || #nm0 + #v <= 21 ? (nm0 + v) (snip nm0 0 (max 0 (16 - #v)) + "[...]" + v))
                                  (say out (re-u k 6 + ": " + re-hex (y 4) (e64 ? 16 8) + " " + szs (y 5) + " "
                                            + urpad 7 (styp t) + " " + urpad 6 (sbind (y 1 >> 4)) + " "
                                            + urpad 7 (["DEFAULT" "INTERNAL" "HIDDEN" "PROTECTED"] (y 2 & 3)) + " "
                                            + ndx (y 3) + " " + nm + "\n"))))
                          ^n)))
            (filter (sc \ (sc 2 = 2 || sc 2 = 11)) ss)))
   (readelf-main as)
    (: (usage m) (udie 1 ("readelf: " + m))
       longs {"--file-header" 104 "--program-headers" 108 "--segments" 108 "--section-headers" 83
              "--sections" 83 "--headers" 101 "--syms" 115 "--symbols" 115 "--wide" 87}
       (go a o)
        (atom? a ? o
         (: w <a n #w
            (? (w = "--") (pin o 'fs (o 'fs + >a), o)
               (2 < n && snip w 0 2 = "--")
                (peep longs w () @ k (charm? k ? (pin o k 1, go >a o) (usage (w + " is not here (-h -l -S -s -e -W)"))))
               (1 < n && w 0 = 45)
                (map (c \ (elem c "hlSseW" ? (pin o c 1) (usage ("-" + string c + " is not here (-h -l -S -s -e -W)"))))
                          (map w (drop 1 ^n)), go >a o)
               (pin o 'fs (o 'fs + [w]), go >a o))))
       o (go as {'fs ()})
       e? (peep o 101 0)
       h? (e? || peep o 104 0) l? (e? || peep o 108 0) S? (e? || peep o 83 0) s? (peep o 115 0) w? (peep o 87 0)
       fs (o 'fs)
       _ (h? || l? || S? || s? ? 0 (usage "Warning: Nothing to do.\nUsage: readelf <option(s)> elf-file(s)"))
       _ (two? fs ? 0 (usage "Warning: Nothing to do.\nUsage: readelf <option(s)> elf-file(s)"))
       (one f)
        (uread f @ r
           (atom? r ? (say err ("readelf: Error: '" + f + "': No such file\n"), 0)
            (<>r @ b
               (!(bu-elf? b) ? (say err "readelf: Error: Not an ELF file - it has the wrong magic bytes at the start\n", 0)
                  (bu-fs b @ fs2
                     (two? >fs ? (say out ("\nFile: " + f + "\n")) 0,
                      h? ? (re-head fs2 b) 0,
                      S? ? (re-secs fs2 b w? h?) 0,
                      l? ? (re-segs fs2 b h? w?) 0,
                      s? ? (re-syms fs2 b w?) 0,
                      1))))))
       ok (foldl (\ a f (one f ? a 0)) 1 fs)
       (flush out, flush err,
        ok ? 0 1))

   (ranlib-main as)
    (: fs (filter (w \ !(1 < #w && w 0 = 45)) as)
       _ (two? fs ? 0 (udie 1 "Usage: ranlib ARCHIVE.."))
       (one f)
        (uread f @ r
           (atom? r ? (say err ("ranlib: '" + f + "': No such file\n"), 1)
            (ar-read f <>r @
               () (say err ("ranlib: " + f + ": file format not recognized\n"), 1)
               a (open f "w" @ q
                    (hot? q ? (say q (arlay <a 1 <>a), close q, 0)
                     (say err ("ranlib: unable to write " + f + "\n"), 1))))))
       (foldl (\ a f (max a (one f))) 0 fs ? 1 0))

   ; the registry: name -> main (aliases share)
   applets {'diff diff-main
            'nm nm-main
            'nc (cite 'nc 'nc-main)   ; nc's wrap registered ahead in the cat
            'ssh (cite 'ssh-cli 'ssh-main) 'sshd (cite 'ssh-cli 'sshd-main)   ; src/apps/ssh, ahead in the cat
            'scp (cite 'ssh-cli 'scp-main)
            'ssh-keygen (cite 'ssh-cli 'keygen-main) 'ssh-copy-id (cite 'ssh-cli 'copyid-main)
            'ssh-keyscan (cite 'ssh-cli 'keyscan-main)
            'make (cite 'cook 'cook-main) 'cook (cite 'cook 'cook-main)   ; cook.l's wrap registered ahead in the cat; the map ctor evaluates values
            'as as-main
            'ar ar-main 'ld ld-main
            'size size-main 'strip strip-main 'ranlib ranlib-main 'readelf readelf-main
            'objcopy (cite 'holo 'objcopy)   ; the applet is the function: src/love/holo/copy.l, module-side
            'cat cat-main 'tac tac-main 'echo echo-main
            'head head-main 'tail tail-main
            'wc wc-main 'sort sort-main 'shuf shuf-main
            'uniq uniq-main 'tee tee-main
            'seq seq-main 'yes yes-main
            'true true-main 'false false-main
            ; test/[ are programs, not only builtins: cook's in-image lane execs a recipe's
            ; words off PATH. `[` cannot be quoted (it opens a bracket), so it is interned by name
            'test test-main (name "[") bracket-main
            'uname uname-main 'arch arch-main 'nproc nproc-main 'printf printf-main
            'basename basename-main 'dirname dirname-main
            'cut cut-main 'tr tr-main
            ; the three line endings, one walk (src/apps/kore/core.l)
            'dos2unix dos2unix-main 'unix2dos unix2dos-main 'mac2unix mac2unix-main
            'nl nl-main 'rev rev-main
            'fold fold-main 'expand expand-main 'unexpand unexpand-main 'column column-main
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
            'openssl openssl-main   ; certificates, digests and a tls peer, openssl 3's spelling
            'grep grep-main 'sed sed-main
            'lex lex-main   ; a scanner spec to the tables dfa.c walks (src/apps/kore/lex.l)
            'yacc yacc-main ; a grammar to the LALR(1) tables lr.c walks (src/apps/kore/yacc.l)
            ; the two old spellings, GNU's own shims: -E and -F said by name
            'egrep (as \ (grep-main ("-E" . as))) 'fgrep (as \ (grep-main ("-F" . as)))
            'awk awk-main 'find find-main
            'vi (cite 'vi 'vi-main)   ; the editor's wrap registered ahead in the cat
            'ed ed-main 'ex ex-main   ; the line editors (src/apps/kore/ed.l)
            'hexedit hexedit-main
            'less less-main 'more less-main   ; one pager, and the two names it is asked for
            'man man-main    ; the pages the build writes, read back (src/apps/kore/man.l)
            'html2text html2text-main   ; a page's prose (src/apps/kore/lens.l), the same lens
            'markdown markdown-main     ; ..and the lens run the way papel runs it
            'www www-main               ; a page to read, its links followed (src/apps/kore/www.l)
            'pic pic-main 'pngcat pic-cat 'jpegcat pic-cat 'gifcat pic-cat   ; pictures (src/apps/kore/pic.l)
            'picless picless-main 'pngless picless-main 'jpegless picless-main 'gifless picless-main
            'grap grap-main   ; graphs as classic pic (src/apps/kore/grap.l)
            'chem chem-main   ; chemical structures as classic pic (src/apps/kore/chem.l)
            'telnet telnet-main 'httpd httpd-main   ; a remote terminal, and kiosko (src/apps/kore/net.l)
            'telnetd telnetd-main                     ; ... and the terminal's server
            'nslookup nslookup-main 'ping ping-main ; a name's records, and icmp echoes (the same)
            'ping6 ping6-main                   ; ... over ipv6
            'traceroute traceroute-main 'traceroute6 traceroute6-main   ; the hops to a host
            'env env-main 'printenv printenv-main 'sleep sleep-main 'nohup nohup-main
            'nice nice-main 'renice renice-main 'stty stty-main 'microcom microcom-main 'truncate truncate-main
            'setsid setsid-main 'watch watch-main 'usleep usleep-main 'ts ts-main
            'getopt getopt-main
            ; the privileged half: what a root the distro builds is filled and entered with
            'chroot chroot-main 'mount mount-main 'umount umount-main
            'sync sync-main 'mkfifo mkfifo-main 'mknod mknod-main
            'whoami whoami-main 'groups groups-main
            ; the host's utmp, read: kore keeps none of its own
            'who who-main 'users users-main 'logname logname-main
            ; gz.l and tar.l sit ahead of this file in the cat, so the cite reads now
            'gzip (cite 'gzcmd 'gzip-main) 'gunzip (cite 'gzcmd 'gunzip-main)
            'zcat (cite 'gzcmd 'zcat-main)
            'xz (cite 'xzcmd 'xz-main) 'unxz (cite 'xzcmd 'unxz-main)
            'xzcat (cite 'xzcmd 'xzcat-main) 'unlzma (cite 'xzcmd 'unxz-main)
            'lzcat (cite 'xzcmd 'xzcat-main)
            'bzip2 (cite 'bz2cmd 'bzip2-main) 'bunzip2 (cite 'bz2cmd 'bunzip2-main)
            'bzcat (cite 'bz2cmd 'bzcat-main)
            'zstd (cite 'zstdcmd 'zstd-main) 'unzstd (cite 'zstdcmd 'unzstd-main)
            'zstdcat (cite 'zstdcmd 'zstdcat-main)
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
            ; lush's wrap is registered ahead of this file in the cat. at cat load lush
            ; claims an sh/lush basename itself; this row serves the image's wake
            'sh (cite 'lush 'sh-main) 'lush (cite 'lush 'sh-main)}

   ; the synopses, one line a tool -- what `TOOL --help` prints. a name with no row
   ; here still answers the flag, with its own spelling for a synopsis.
   korehelp
   {'diff "usage: diff [-Nqru] OLD NEW   (0 same / 1 differ / 2 trouble)"
    'nm "usage: nm [-g] [-u] [-p] [-n] [-S] FILE.."
    'nc "usage: nc [-CdkNnUuvz] [-i SECS] [-o FILE] [-q SECS] [-w SECS] {HOST PORT.. | -l [[-s] ADDR] [-p] PORT | -U [-l] PATH}"
    'ssh "usage: ssh [-p port] [-i identity] [-l user] [-t|-T] [-o option=value] [user@]host [command]"
    'sshd "usage: sshd [-Deq] [-p port] [-h host_key_file] [-o AuthorizedKeysFile=path]"
    'scp "usage: scp [-pqrO] [-P port] [-i identity] [-o option=value] source .. target"
    'ssh-keygen "usage: ssh-keygen [-q] [-a rounds] [-C comment] [-f file] [-N passphrase] [-t ed25519]; -y, -l, -p [-P old] [-N new], -F host, -R host"
    'ssh-copy-id "usage: ssh-copy-id [-fn] [-i identity_file] [-p port] [-o option=value] [-t target_path] [user@]host"
    'ssh-keyscan "usage: ssh-keyscan [-Hq] [-f file] [-p port] [-t type] host .."
    'as "usage: as TARGET IN OUT   (TARGET: x64 | a64)"
    'ar "usage: ar rcs OUT MEMBER..  |  ar t OUT"
    'ld "usage: ld [-pie] [-t x64|a64|rv64] [-Ttext ADDR] [--readme F] A.o.. -o OUT"
    'objcopy "usage: objcopy [-O binary|ihex] [-S] [-R SEC] [-j SEC] IN OUT"
    'cat "usage: cat [-AbeEnstTuv] [FILE..]"
    'tac "usage: tac [-br] [-s SEP] [FILE..]"
    'head "usage: head [-qv] [-n N] [-c N] [-N] [FILE..]"
    'tail "usage: tail [-fFqv] [-s SECS] [-n N] [-c N] [-N] [FILE..]"
    'wc "usage: wc [-lwmcL] [FILE..]"
    'sort "usage: sort [-bcCfhmnrsuVz] [-k KEY].. [-t C] [-o FILE] [FILE..]"
    'uniq "usage: uniq [-cdDiuz] [-f N] [-s N] [-w N] [INPUT [OUTPUT]]"
    'shuf "usage: shuf [-rz] [-n N] [-o F] [FILE]  |  shuf -e [ARG..]  |  shuf -i LO-HI"
    'tee "usage: tee [-aip] [FILE..]"
    'seq "usage: seq [-w] [-s SEP] [-f FMT] [FIRST [INCR]] LAST"
    'yes "usage: yes [WORD..]"
    'true "usage: true   (the 0 exit, and nothing else)"
    'false "usage: false   (the 1 exit, and nothing else)"
    'uname "usage: uname [-amnrsv] (the letters combine: -srm)"
    'arch "usage: arch   (uname -m, and nothing else)"
    'nproc "usage: nproc"
    'printf "usage: printf FORMAT [ARG..]"
    'basename "usage: basename NAME [SUFFIX] | basename [-az] [-s SUFFIX] NAME.."
    'dirname "usage: dirname [-z] NAME.."
    'cut "usage: cut -f LIST [-d C] [-s] | cut -c LIST | cut -b LIST  [--complement] [--output-delimiter=S] [-z]"
    'tr "usage: tr [-cCdst] SET1 [SET2]"
    'nl "usage: nl [-b a|t|n] [-n ln|rn|rz] [-w N] [-s SEP] [-v N] [-i N] [FILE..]"
    'rev "usage: rev [FILE..]"
    'fold "usage: fold [-w N] [-s] [-b] [FILE..]"
    'column "usage: column [-tx] [-c COLUMNS] [-s SEP] [-o SEP] [FILE..]"
    'expand "usage: expand [-t N] [-i] [FILE..]"
    'unexpand "usage: unexpand [-a] [-t N] [FILE..]"
    'base64 "usage: base64 [-d] [-w N] [FILE]"
    'base32 "usage: base32 [-d] [-w N] [FILE]"
    'tsort "usage: tsort [FILE]"
    'factor "usage: factor [N..]"
    'paste "usage: paste [-s] [-d LIST] [FILE..]"
    'comm "usage: comm [-123] FILE1 FILE2"
    'split "usage: split [-l N | -b SIZE | -C SIZE | -n [l/]N] [-a N] [-d | -x] [--additional-suffix=S] [FILE [PREFIX]]"
    'join "usage: join [-i] [-1 F] [-2 F] [-t C] [-a 1|2].. [-v 1|2] [-e S] [-o FORMAT|auto] FILE1 FILE2"
    'od "usage: od [-A C] [-t TYPE] [-N N] [-j N] [-v] [-abcdiosx] [FILE..]"
    'cksum "usage: cksum [FILE..]"
    'md5sum "usage: md5sum [-bt] [FILE..] | md5sum -c [--quiet] [--status] [--ignore-missing] [--strict] [-w] [LIST..]"
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
    'ls "usage: ls [-aACcdFghiLlnoprRsStux1] [--color[=WHEN]] [FILE..]"
    'dir "usage: dir [-aACdlrtx1] [FILE..]"
    'cp "usage: cp [-afinpPLrRuv] [-t DIR] SRC.. DST"
    'mv "usage: mv [-finuv] [-t DIR] SRC.. DST"
    'rm "usage: rm [-dfirRv] FILE.."
    'mkdir "usage: mkdir [-pv] [-m MODE] DIR.."
    'rmdir "usage: rmdir [-pv] DIR.."
    'ln "usage: ln [-fnsTv] TARGET [LINK] | ln [-fnsv] TARGET.. DIR"
    'touch "usage: touch [-c] [-r FILE] [-d DATE] FILE.."
    'lift "usage: lift FILE   -- carry FILE out of the machine: the page's downloads, the runner's directory"
    'pwd "usage: pwd [-L|-P]"
    'chmod "usage: chmod [-Rf] MODE FILE.."
    'install "usage: install [-CDpsTv] [-m MODE] [-o USER] [-g GROUP] [-t DIR] SRC.. DST | install -d [-m MODE] [-v] DIR.."
    'readlink "usage: readlink [-efmnz] PATH.."
    'realpath "usage: realpath [-emqszLP] [--relative-to=DIR] [--relative-base=DIR] PATH.."
    'link "usage: link FILE NEW"
    'unlink "usage: unlink FILE"
    'cmp "usage: cmp [-bls] [-n N] [-i SKIP[:SKIP]] A B [SKIP1 [SKIP2]]"
    'stat "usage: stat [-fL] [-c FORMAT | --printf=FORMAT] FILE.."
    'du "usage: du [-abchLsx0] [-d N] [--max-depth=N] [--exclude=GLOB] [--apparent-size] [FILE..]"
    'df "usage: df [-ahHikPT] [-t TYPE].. [-x TYPE].. [FILE..]"
    'chown "usage: chown [-chRv] OWNER[:GROUP] FILE.. | chown --reference=RFILE FILE.."
    'chgrp "usage: chgrp [-chRv] GROUP FILE.. | chgrp --reference=RFILE FILE.."
    'mktemp "usage: mktemp [-dqtu] [-p DIR] [--tmpdir[=DIR]] [--suffix=S] [TEMPLATE]"
    'sync "usage: sync   (the bare call; no operands here)"
    'mkfifo "usage: mkfifo [-m MODE] NAME.."
    'mknod "usage: mknod [-m MODE] NAME TYPE [MAJOR MINOR]"
    'expr "usage: expr EXPRESSION"
    'patch "usage: patch [-pN] [-R] [-i F] [-o F] [-s] [--dry-run]"
    'grep "usage: grep [-acEFhHiLlnoqrRsvwx] [-e PAT] [-f FILE] [-m N] [-A N] [-B N] [-C N] [--include=GLOB] [--exclude=GLOB] PATTERN [FILE..]"
    'egrep "usage: egrep [grep's flags] PATTERN [FILE..]   (grep -E)"
    'fgrep "usage: fgrep [grep's flags] PATTERN [FILE..]   (grep -F)"
    'sed "usage: sed [-nErs] [-i[SUFFIX]] [-e SCRIPT].. [-f FILE].. SCRIPT [FILE..]"
    'lex "usage: lex [-m MODULE] [-n NAME] SPEC"
    'yacc "usage: yacc [-m MODULE] [-n NAME] SPEC"
    'awk "usage: awk [-F FS] [-v var=val].. PROGRAM [FILE..]  |  awk .. -f PROGFILE.. [FILE..]"
    'find "usage: find [-L] [PATH..] [EXPR]  -- see doc/misc/kore.md for the grammar"
    'less "usage: less [-Nise] [+N|+/PAT] [FILE..]"
    'more "usage: more [-Nise] [+N|+/PAT] [FILE..]"
    'wget "usage: wget [-q] [--no-check-certificate] [-O FILE] URL"
    'openssl "usage: openssl x509|s_client|verify|dgst|rand|base64|version [ARGS..]"
    'bc "usage: bc [-l] [-q] [FILE..]
  -l  the math library (e l a s c j), and scale = 20
  -q  accepted: nothing is printed at start with or without it"
    'vi "usage: vi [FILE]"
    'ed ed-usage
    'ex ex-usage
    'env "usage: env [-0i] [-u NAME].. [-C DIR] [-S STRING] [NAME=VALUE].. [CMD [ARG..]]"
    'nohup "usage: nohup CMD [ARG..]"
    'nice "usage: nice [-n N] [CMD [ARG..]]"
    'renice "usage: renice [-n|--relative] PRIORITY [-p|-g|-u] ID.."
    'stty "usage: stty [-F DEV] [-a|-g|SETTING..]"
    'microcom "usage: microcom [-X] [-s SPEED] [-t TIMEOUT] TTY"
    'truncate "usage: truncate [-co] [-r RFILE] [-s [+-<>/%]SIZE] FILE.."
    'getopt "usage: getopt [-o SHORTS] [-l LONGS].. [-n NAME] [-aqQTu] [-s sh] [--] PARAMS  |  getopt SHORTS PARAMS"
    'printenv "usage: printenv [-0] [NAME..]"
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
    'ps "usage: ps [-Aef] [-o KEY[=HDR],..] [-p PID,..] [-u USER,..] | ps [a][u][x]"
    'top "usage: top [-b] [-n FRAMES] [-d SECS] [-p PID]..
  -b  batch: no terminal wanted, every process, a frame per iteration
  -n  stop after N frames (-b alone is one frame)
  -d  seconds between frames (3 by default)
  -p  one process, spelled again for each
  keys: q quit, space or r repaint, c the command line, P M T N the orders"
    'free "usage: free [-b|-k|-m|-g|-h] [-tw]"
    'uptime "usage: uptime [-p|-s]"
    'pidof "usage: pidof [-s] NAME.."
    'pgrep "usage: pgrep [-acflnovx] [-d DELIM] [-u USER,..] [PATTERN]"
    'pkill "usage: pkill [-SIG] [-efnovx] [-u USER,..] [PATTERN]"
    'killall "usage: killall [-SIG] NAME.."
    'pwdx "usage: pwdx PID.."
    'kill "usage: kill [-s SIG | -SIG] PID.. | kill -l [SIG..]"
    'xargs "usage: xargs [-0rt] [-d C] [-n N] [-L N] [-I S] [-P N] [CMD ARGS..]"
    'time "usage: time [-p] CMD [ARG..]"
    'date "usage: date [-u] [-d DATE] [-r FILE] [+FORMAT]"
    'id "usage: id [-u|-g|-G] [-n] [-r]"
    'dos2unix "usage: dos2unix [-fkqn] [FILE..]"
    'unix2dos "usage: unix2dos [-fkqn] [FILE..]"
    'mac2unix "usage: mac2unix [-fkqn] [FILE..]"
    'man "usage: man [-w] [SECTION] NAME.."
    'html2text "usage: html2text [-w COLS] [FILE..]"
    'markdown "usage: markdown [-t html|roff|text] [-w COLS] [FILE..]"
    'www "usage: www [-w COLS] URL|FILE"
    'pic "usage: pic [cat|less|convert|pixelize] [-g MODE] [-w COLS] [-h ROWS] FILE.. | pic [-nCSU] [-t [-cz]] [FILE..]"
    'picless "usage: picless FILE.."
    'grap "usage: grap [FILE..]"
    'chem "usage: chem [FILE..]"
    'telnet "usage: telnet HOST [PORT]"
    'telnetd "usage: telnetd [-FK] [-p PORT] [-b ADDR[:PORT]] [-l LOGIN] [-f ISSUE]"
    'httpd "usage: httpd [-fv] [-p PORT] [-h DIR]"
    'nslookup "usage: nslookup [-type=A|AAAA|CNAME|MX|NS|PTR|SOA|TXT] [-port=N] HOST [SERVER]"
    'ping "usage: ping [-46q] [-c COUNT] [-i SECS] [-W SECS] [-s SIZE] HOST"
    'ping6 "usage: ping6 [-q] [-c COUNT] [-i SECS] [-W SECS] [-s SIZE] HOST"
    'traceroute "usage: traceroute [-46nI] [-f FIRST] [-m MAX] [-q N] [-w SECS] HOST"
    'traceroute6 "usage: traceroute6 [-nI] [-f FIRST] [-m MAX] [-q N] [-w SECS] HOST"
    'dd "usage: dd [if=F] [of=F] [bs=N] [ibs=N] [obs=N] [count=N] [skip=N] [seek=N] [conv=..] [iflag=..] [oflag=..] [status=none|noxfer]"
    'xxd "usage: xxd [-ipu] [-c N] [-g N] [-l N] [-s N] [FILE..] | xxd -r [-p] [FILE..]"
    'hexdump "usage: hexdump [-Cv] [-n LEN] [-s SKIP] [FILE..]"
    'hd "usage: hd [-v] [-n LEN] [-s SKIP] [FILE..]   (hexdump -C)"
    'strings "usage: strings [-n LEN] [FILE..]"
    'cal "usage: cal [[MONTH] YEAR]"
    'timeout "usage: timeout [-v] [-s SIG] [-k DUR] [--preserve-status] DURATION CMD [ARG..]"
    'which "usage: which [-a] NAME.."
    'tty "usage: tty"
    'clear "usage: clear"
    'hostname "usage: hostname [-s|-f]"
    ; the archives keep their own screens: the cmd modules leak them off the same
    ; bodyless letrec the mains come through, so the door shows what the tool would
    'cpio (cite 'cpiocmd 'cpioc-usage)
    'tar (cite 'tarcmd 'usage)
    'gzip (cite 'gzcmd 'gzc-help)
    'gunzip (cite 'gzcmd 'gzc-help)
    'zcat (cite 'gzcmd 'gzc-help)
    'xz (cite 'xzcmd 'xzc-help) 'unxz (cite 'xzcmd 'xzc-help) 'xzcat (cite 'xzcmd 'xzc-help)
    'unlzma (cite 'xzcmd 'xzc-help) 'lzcat (cite 'xzcmd 'xzc-help)
    'bzip2 (cite 'bz2cmd 'bzc-help) 'bunzip2 (cite 'bz2cmd 'bzc-help) 'bzcat (cite 'bz2cmd 'bzc-help)
    'zstd (cite 'zstdcmd 'zsc-help) 'unzstd (cite 'zstdcmd 'zsc-help) 'zstdcat (cite 'zstdcmd 'zsc-help)}

   ; echo, test and [ read no options (posix: `echo --help` means the words); cook and
   ; lush answer their flags themselves
   korenoflag ['echo 'test (name "[") 'make 'cook 'sh 'lush]
   ; -v is never the door's (gnu gives --version no short spelling; cpio -v, grep -v ..).
   ; -h is the door's unless the tool spells it itself
   korenoh '(grep du df ls sort touch chown chgrp ln free readelf pinky httpd)
   ; tools that read no options: a leading dash word not in korebareok is refused;
   ; only leading words are walked, so `ps aux` is untouched
   korebare '(arch nproc whoami groups pwd tty clear)
   korebareok {'pwd '("-L" "-P")}
   (kobare nm as)
    (peep korebareok nm () @ ok
       (<(filter (w \ 1 < #w && w 0 = 45 && (nelem w ok)) as)))
   ; the applet as the world calls it: cli's door, then the tool under urun; the verb
   ; registry and the symlink both come through here
   (koredoor nm f)
    (: (run as) (nelem nm korebare ? (urun f as)
                 (kobare nm as @ w
                    (!w ? (urun f as)
                       (say err (string nm + ": unknown option " + w), put err 10, 2))))
       (elem nm korenoflag ? run
        (udoor nm run (korehelp nm) (nelem nm korenoh) 0)))

   (bn p) (: n #p (snip p (foldl (\ r k (p k = 47 ? (k + 1) r)) 0 ^n) n))

   ; -- the dispatch (this form's body) --
   ; the spellings kore answers to: every applet (a symlink is an applet name as argv0).
   ; post.l's `seatof` scans the list handed it, drops -l pairs and answers (WORD . rest),
   ; or () when the program is someone else's, so a bake stays quiet
   mynames (map string (keys applets))
   ; every applet is registered as a verb, so `love ls` and an `ls` symlink both reach it,
   ; in every image carrying this cat. the inner `:` is a fresh scope per step, so each
   ; closure holds its own f.
   ; what each applet says of itself to a shell (post.l's verbs).
   ; the builtins are POSIX's, run ahead of PATH in every mode
   korebuiltin ['echo 'printf 'test (name "[")]
   ; ..and the ones safe to run in a caller's own process
   koreself ['uname 'basename 'dirname 'readlink 'seq 'ls 'dir 'vdir 'cmp 'diff
             'mkdir 'rmdir 'rm 'ln 'touch 'chmod 'mv 'cp 'install 'objcopy
             'nm 'ar 'ld 'as 'readelf 'size 'strip 'ranlib
             'date 'cal 'uptime 'arch 'nproc 'hostname 'tty 'whoami 'id
             'groups 'printenv 'which 'realpath 'expr 'free 'ps 'pwdx
             'logname 'users 'who 'pinky 'hostid 'dnsdomainname 'mountpoint 'pathchk
             'stat 'df 'du 'link 'unlink 'mktemp 'mkfifo 'mknod 'sync 'fsync
             'chown 'chgrp 'truncate 'shred 'mount 'umount 'clear 'lift]
   ; ..and the readers, safe per call only when every operand is a regular file: stdin,
   ; a fifo or a device need not end, so any other word (an option's argument, a -) forks
   korefiles ['cat 'wc 'tac 'rev 'cksum 'md5sum 'sha1sum 'sha224sum 'sha256sum 'sha384sum
              'sha512sum 'sha3sum 'b2sum 'crc32 'sum]
   (kregs? os) (: (reg? p) (stat p @ st (two? st && st 2 & 61440 = 32768))
                  (two? os && all (p \ !(p = "-") && reg? p) os))
   (kfiles? as)
    (: (ops l) (? (atom? l) () (<l = "--") >l
                  (1 < #<l && <l 0 = 45) (ops >l)
                  (<l . ops >l))
       (kregs? (ops as)))
   ; ..and the filters whose options carry words: each asks its own parser for its
   ; operands, so a word an option took is never mistaken for a file
   korepreds {'head (as \ (uclip-args "head" as @ p (kregs? <>p)))
              'tail (as \ (uclip-args "tail" as @ p (kregs? <>p)))
              'cut (as \ (cut-args as @ p (kregs? (p 5))))
              'grep (as \ (: t {} o (grep-opt as t) (two? o && kregs? (grep-fs t o))))}
   (koretraits k) (? (elem k korebuiltin) ['builtin 'self] (elem k koreself) ['self]
                     (elem k korefiles) [('self . kfiles?)]
                     (lit? (korepreds k)) [('self . peep korepreds k ())]
                     (elem k '(sh lush)) ['login] ())
   _ (: E (cite 'verbs 'enlist)
        (go ks) (two? ks ? (applets <ks @ f
                              (E <ks (koredoor <ks f) (koretraits <ks), go >ks)) 0)
        (go (keys applets)))
   ; kore-main: a program-relative arg list, the tool first (argv0 a tool symlink) -> the
   ; status charm, () when kore is not the program. a list handed in is scanned, () means
   ; the line love was started with; an in-image caller hands (. "ls" "-l") and reads the charm
   (kore-main a)
    ((two? a ? (cite 'verbs 'seatof mynames a) (cite 'verbs 'fire mynames)) @ s
       (atom? s ? ()
        (: n (intern (bn <s)) f (applets n)
           (f ? (koredoor n f >s))))))
; file mode dispatches on the real command line and quits with the status. under a -l
; bake preload the program word is a flag, so kore-main answers () and nothing quits
(kore-main () @ r (charm? r ? (quit r)))
) ; module 'kore
