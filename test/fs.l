; the fs nifs: an effect op answers () ok, an errno nom, or 'badarg; a value op the value, (), or a nom.
; hosted only: inle's ramfs keeps no such metadata
(!hosted ? 0
(: d ("out/.fs-nif-smoke." + show (getpid 0))        ; per process: shards run at once
   a (d + "/a") b (d + "/b") l (d + "/l")
   (mkdir d 493,                                    ; EEXIST from a prior run is fine
    unlink a, unlink b, unlink l,
    (open a "w" @ p (say p "five!", close p)),

    ; rename: old gone, new the same size
    (test
      !(rename a b)
      ((stat a) = 'enoent) (5 = <(stat b))
      ('enoent = (rename a (d + "/x")))
      ('badarg = (rename 7 b))),         ; misuse: a non-string path

    ; symlink: the target resolves from the link's dir, readlink answers it verbatim, stat follows
    (test
      !(symlink "b" l)
      (readlink l = "b")
      (5 = <(stat l)) (32768 = (& 61440 <>>(stat l)))
      ((readlink b) = 'einval) ((readlink (d + "/nope")) = 'enoent)),

    ; chmod: 0600 = 384; utime: milliseconds, a non-charm is "now"
    (test
      !(chmod b 384)
      (384 = (<>>(stat b) - 32768))
      !(utime b 1600000000000)
      (1600000000000 = <>(stat b))
      !(utime b ())
      (1600000000000 < <>(stat b))           ; "now" is later than the pinned past
      ('enoent = (chmod (d + "/nope") 384))
      ('badarg = (chmod b "rw"))),           ; misuse: a non-charm mode

    ; chown -1 -1 leaves both ids alone
    (test
      !(chown b -1 -1)
      ('badarg = (chown b "x" 0))),

    ; umask answers the previous mask
    (umask 18 @ m0
     (test (charm? m0) (18 = umask m0) (m0 = umask m0))),

    ; rmdir: full is a live errno, empty goes
    ((d + "/sub") @ e
     (mkdir e 493,
      (test
        ('enotempty = (rmdir d))                   ; d holds b and l still
        !(rmdir e)
        ((stat e) = 'enoent)
        ('enoent = (rmdir e))
        ('badarg = (rmdir 7))))),

    ; hardlink: the survivor keeps the file when the first unlinks
    ((d + "/h") @ h
     (unlink h,
      (test
        !(hardlink b h)
        (5 = <(stat h))
        ('eexist = (hardlink b h))
        (unlink b, (5 = <(stat h)))
        !(unlink h)))),

    ; copyfile: an empty source answers a falsy 0
    (: c (d + "/c") z (d + "/z")
       ((open c "w" @ p (say p "five!", close p)),
        (open z "w" @ p (close p)),
        (test
          (5 = copyfile c (d + "/c2"))
          (5 = <(stat (d + "/c2")))
          (0 = copyfile z (d + "/z2"))            ; 0 is the count
          ('enoent = (copyfile (d + "/nope") (d + "/c3")))
          ('badarg = (copyfile 7 c))
          !(unlink c) !(unlink z)
          !(unlink (d + "/c2")) !(unlink (d + "/z2"))))),

    ; selfpath: absolute, a regular file
    (selfpath 0 @ s
     (test
       (string? s)
       (47 = peep s 0 0)
       (32768 = (& 61440 <>>(stat s)))         ; s_ifreg: a file, not the /proc link
       (0 < <(stat s)))),

    ; the os lane is compiled in, not its stub ('enosys)
    (mount "" "/" "no-such-fs" @ e
     (test (nom? e) !(e = 'enosys))),

    ; a NUL in a path is misuse: the kernel would stop at it
    ((d + string 0 + "x") @ z
     (test ('badarg = (open z "r")) ('badarg = (stat z)) ('badarg = (lstat z))
           ('badarg = (openfd z 0)) ('badarg = (readdir z)) ('badarg = (unlink z))
           ('badarg = (chdir z)) ('badarg = (mkdir z 493)) ('badarg = (copyfile z (d + "/c4")))
           ('badarg = (setenv ("LOVE_FS" + string 0 + "X") "v"))
           ('badarg = (setenv "LOVE_FS" ("v" + string 0)))
           ('badarg = (spawn ["true" ("a" + string 0)]))
           (two? (stat d)))),

    unlink l, unlink b, rmdir d,
    test_fin ())))
