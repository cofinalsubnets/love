; test/kernel/fs.l -- the file nifs on inle: stat, readdir, lseek, raw fds, and the wall clock.
; the shapes are the host's exactly, since kore reads them and a divergence would be silent.
; the initrd is flat, so a directory is a prefix some path lies under, synthesized every time.
; kernel only (test/kernel/all.l's roster). runs after ramfs.l, so the write laws use
; src/apps/dns.l, which the boot never loads, and put it back. each law is its own assert
; argument: a `do` would report only the last.

(: f "src/apps/json.l" d "src/apps" g "/tmp/l-fs-dns.l"
   (rd p) (: q (open p "r") s (slurp q) (close q, s))
   (wr p s) (open p "w" @ q (say q s, close q))
   st (stat f)
   sz #(rd f)
   orig (rd "src/apps/dns.l")
   _ (wr g orig)                                 ; the scratch: the tree itself refuses a write
   was (stat g)
   _ (wr g "abc")
   now (stat g)
   _ (wr g orig)
   back (stat g)
   ; a write in place keeps the bytes about it, and a truncate cuts or stretches with zeros
   h "/tmp/l-fs-at"
   _ (wr h "abcdef")
   _ (uwrite-at h 2 "XY")
   inplace (rd h)
   _ (truncate h 3 0)
   cut (rd h)
   _ (truncate h 5 0)
   grown (rd h)
   (unlink g, unlink h,
    test
   ; stat answers the four fields, and the size is the bytes a read hands over
   (two? st)
   (sz = <st)
   ; the mtime is the source's, off the archive: milliseconds, and a 2020s stamp
   (1600000000000 < <>st)
   (32768 = 61440 & <>>st)                     ; s_ifmt bits say regular file
   (1000000 * <>st = <>>>st)                   ; ns is that same date whole
   ; a directory wears the dir bits and the newest date under it
   (16384 = 61440 & <>>(stat d))
   (1600000000000 < <>(stat d))
   ; absence is the real (), never an empty tray of fields
   (stat (d + "/no-such-thing.l") = 'enoent)
   !(charm? (stat (d + "/no-such-thing.l")))
   ; readdir hands over the baked names as strings
   (elem "json.l" (readdir d))
   (string? <(readdir d))
   ; "" and "." are both the seat, the tree's top: its own top names, each deduped
   ; across every row beneath it. the root holds the home, empty, and tmp -- the scratch
   ; the rung-2 tree seeds at boot -- and no row of the tree, which lists under /love
   (elem "src" (readdir "."))
   (elem "src" (readdir "/love"))
   (elem "test" (readdir "/love"))
   (elem "love" (readdir "/"))
   (() = readdir "/home")
   (elem "home" (readdir "/"))
   (elem "tmp" (readdir "/"))
   (nelem "src" (readdir "/"))
   ; the machine's own files (src/inle/rootfs/) stand at the root, no file of the tree
   (elem "etc" (readdir "/"))
   (nelem "etc" (readdir "/love"))
   (0 < tally (rd "/etc/profile"))
   (nelem f (readdir "/love"))              ; components, never whole paths
   ; a file is no directory, and neither is a prefix nothing lies under
   (readdir f = 'enotdir)
   (readdir (d + "/nope") = 'enoent)
   ; lseek rides the raw openfd lane: end is the size, set and cur the arithmetic
   (openfd f 0 @ fd
        (sz = lseek fd 0 2 && 1 = lseek fd 1 0 && 3 = lseek fd 2 1
            && !(close fd)))
   ('ebadf = lseek -1 0 0)                   ; a bad fd is its nom, never a seek
   ('enoent = openfd (d + "/no-such-thing.l") 0)  ; and so is an absent path
   ; a whence no seat knows is the row's 'einval and moves nothing -- read as SET
   ; it would have seeked to 0 and called that success
   (openfd f 0 @ fd
        (2 = lseek fd 2 0 && 'einval = lseek fd 0 7 && 'einval = lseek fd 0 -3
            && 2 = lseek fd 0 1 && !(close fd)))
   ; stat takes a charm as an fd, which is fstat under another name: the same
   ; tuple the path answers, and nothing for a row that is not there
   (: fd (openfd f 0) r (stat fd = stat f) (close fd, r))
   (stat 4096 = 'ebadf) !(charm? (stat 4096))
   ; and stat reads a row's KIND off the fd: a file, and a directory, which opens
   ; read-only by POSIX's own rule and answers as the tree it is
   (: fd (openfd f 0) s (stat fd) (close fd, (32768 = 61440 & <>>s)))
   (: fd (openfd d 0) s (stat fd) (close fd, (16384 = 61440 & <>>s)))
   ; close wears the errno convention: a stranger row is 'ebadf, and so is the
   ; second close of a real one -- the row is gone, which is what the answer says
   (: fd (openfd f 0) a (close fd) b (close fd) (!a && 'ebadf = b))
   ('ebadf = close 4096)
   !(close -1)                                 ; closing nothing still answers ok
   ; the raw-fd lane reads the ramfs byte for byte where the port lane does, gulp
   ; boundaries and all -- one file is longer than a single gulp
   (: fd (openfd f 0) a (slurp fd) (close fd, (a = rd f && sz = #a)))
   ; a write moves the size, and the date with it: stat reads the copy's stamp once
   ; there is a copy, the bake's until then
   (3 = <now)
   (<>was <= <>now)
   (#orig = <back)
   ("abXYef" = inplace)
   ("abX" = cut)
   ("abX" + string [0 0] = grown)
   !(uwrite-at "/tmp/l-fs-none" 0 "x")         ; in place is not a create
   !(two? (stat "/tmp/l-fs-none"))
   ; the wall clock, which every line above leans on: the door's date if it left
   ; one, else the machine's own rtc (mc146818 on x64, PL031 on a64). It reads as
   ; milliseconds since the epoch here exactly as it does on the host -- an uptime
   ; in ticks is what it used to be, and would fail this by a factor of a thousand.
   (1600000000000 < clock 0)))

; the tree's tls roots ride the initrd: where no host bundle is, src/apps/tls/verify.l reads
; them here, under /love
(: r (: q (open "src/apps/tls/roots.pem" "r") s (slurp q) (close q, s))
 (test (100 < #(filter (l \ l = "-----BEGIN CERTIFICATE-----") (split "\n" r)))))
