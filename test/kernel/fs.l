; test/kernel/fs.l -- the file nifs on inle: stat, readdir, lseek, raw fds, the wall clock.
; the shapes are the host's exactly: kore reads them and a divergence would be silent.
; the initrd is flat, so a directory is a prefix some path lies under. kernel corpus only.

(: f "src/apps/json.l" d "src/apps" g "/tmp/l-fs-dns.l"
   (rd p) (: q (open p "r") s (slurp q) (close q, s))
   (wr p s) (open p "w" @ q (say q s, close q))
   st (stat f)
   sz #(rd f)
   orig (rd "src/apps/dns.l")
   _ (wr g orig)                                 ; the tree itself refuses a write
   was (stat g)
   _ (wr g "abc")
   now (stat g)
   _ (wr g orig)
   back (stat g)
   ; a write in place keeps the bytes about it; truncate cuts or stretches with zeros
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
   ; stat answers four fields; the size is the bytes a read hands over
   (two? st)
   (sz = <st)
   ; the mtime is the source's, off the archive, in milliseconds
   (1600000000000 < <>st)
   (32768 = 61440 & <>>st)                     ; s_ifmt: regular file
   (1000000 * <>st = <>>>st)                   ; ns is that same date
   ; a directory wears the dir bits and the newest date under it
   (16384 = 61440 & <>>(stat d))
   (1600000000000 < <>(stat d))
   ; absence is 'enoent, never a tray of fields
   (stat (d + "/no-such-thing.l") = 'enoent)
   !(charm? (stat (d + "/no-such-thing.l")))
   (elem "json.l" (readdir d))
   (string? <(readdir d))
   ; "" and "." are both the tree's top. the root holds home (empty), tmp and the
   ; machine's own files, and no row of the tree, which lists under /love
   (elem "src" (readdir "."))
   (elem "src" (readdir "/love"))
   (elem "test" (readdir "/love"))
   (elem "love" (readdir "/"))
   (() = readdir "/home")
   (elem "home" (readdir "/"))
   (elem "tmp" (readdir "/"))
   (nelem "src" (readdir "/"))
   (elem "etc" (readdir "/"))
   (nelem "etc" (readdir "/love"))
   (0 < tally (rd "/etc/profile"))
   (nelem f (readdir "/love"))              ; components, never whole paths
   ; a file is no directory, and neither is a prefix nothing lies under
   (readdir f = 'enotdir)
   (readdir (d + "/nope") = 'enoent)
   ; lseek: end is the size, set and cur the arithmetic
   (openfd f 0 @ fd
        (sz = lseek fd 0 2 && 1 = lseek fd 1 0 && 3 = lseek fd 2 1
            && !(close fd)))
   ('ebadf = lseek -1 0 0)                   ; a bad fd is its nom
   ('enoent = openfd (d + "/no-such-thing.l") 0)
   ; an unknown whence is 'einval and moves nothing
   (openfd f 0 @ fd
        (2 = lseek fd 2 0 && 'einval = lseek fd 0 7 && 'einval = lseek fd 0 -3
            && 2 = lseek fd 0 1 && !(close fd)))
   ; stat of a charm is fstat: the same tuple the path answers
   (: fd (openfd f 0) r (stat fd = stat f) (close fd, r))
   (stat 4096 = 'ebadf) !(charm? (stat 4096))
   ; fstat reads the kind: a directory opens read-only and answers as one
   (: fd (openfd f 0) s (stat fd) (close fd, (32768 = 61440 & <>>s)))
   (: fd (openfd d 0) s (stat fd) (close fd, (16384 = 61440 & <>>s)))
   ; a second close is 'ebadf: the row is gone
   (: fd (openfd f 0) a (close fd) b (close fd) (!a && 'ebadf = b))
   ('ebadf = close 4096)
   !(close -1)
   ; the raw-fd lane reads the ramfs as the port lane does, across gulp boundaries
   (: fd (openfd f 0) a (slurp fd) (close fd, (a = rd f && sz = #a)))
   ; a write moves the size and the date: stat reads the copy's stamp
   (3 = <now)
   (<>was <= <>now)
   (#orig = <back)
   ("abXYef" = inplace)
   ("abX" = cut)
   ("abX" + string [0 0] = grown)
   !(uwrite-at "/tmp/l-fs-none" 0 "x")
   !(two? (stat "/tmp/l-fs-none"))
   ; the wall clock: the door's date if it left one, else the machine's rtc,
   ; in milliseconds since the epoch as on the host
   (1600000000000 < clock 0)))

; the tree's tls roots ride the initrd, under /love, for src/apps/tls/verify.l
(: r (: q (open "src/apps/tls/roots.pem" "r") s (slurp q) (close q, s))
 (test (100 < #(filter (l \ l = "-----BEGIN CERTIFICATE-----") (split "\n" r)))))
