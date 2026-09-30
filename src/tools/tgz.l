; src/tools/tgz.l -- take apart a .tar.gz with nothing but love.
;
;   love src/tools/tgz.l x archive.tar.gz [DIR]  unpack into DIR (default ".")
;   love src/tools/tgz.l t archive.tar.gz        list, one path a line
;
; the verbs are tar's own letters because the muscle memory is worth more than a
; better name. the pack direction lives in src/tools/selfpack.l, the one cutter.
(borrow 'tar)
(borrow 'gz)

(borrow 'posix)
(: (tgz-slurp p) (uread p @ [1 s] [1 (s + "")] ())
   (tgz-die m) (udie 1 ("tgz: " + m))

   ; every read here is guarded separately so the message names which step failed:
   ; "not a gzip" and "not a tar" are different repairs, and one "cannot read" for
   ; both would send you to the wrong one.
   (tgz-open arch)                          ; -> entries, or quits
    (: b (tgz-slurp arch)
       _ (!b && tgz-die ("cannot read " + arch))
       u (gz-unzip <>b)
       _ (!u && tgz-die (arch + ": not a gzip stream, or its crc32 disagrees"))
       r (tar-unpack <>u)
       _ (!r && tgz-die (arch + ": not a tar archive, or it is truncated"))
       <>r)

   (tgz-x arch dir)
    (: es (tgz-open arch)
       w (tar-scatter dir es)
       _ (!w && tgz-die ("cannot write under " + dir))
       (say out $ "tgz: " + show <>w + " entries -> " + dir + "\n", 0))

   (tgz-t arch)
    (tgz-open arch @ es (each es (e \ say out (peep e 'nom "" + "\n")), 0))

   (tgz-main av)
    (: n #av
       v (n ? <av "")
       (? !n (tgz-die "usage: tgz x|t ARCHIVE.tar.gz [DIR]")
          (v = "x" && 2 <= n) (tgz-x <>av (3 <= n ? <>>av "."))
          (v = "t" && 2 <= n) (tgz-t <>av)
          (tgz-die "usage: tgz x|t ARCHIVE.tar.gz [DIR]")))

   ; argv's head is the script's own path, so the verbs start at the tail
   (tgz-main >argv))
