; the fs nifs: an effect op answers () ok, an errno nom, or 'badarg on misuse;
; a value op answers the value, (), or a nom. hosted only: inle's ramfs keeps no such metadata
(!hosted ? 0
(: d ("out/.fs-nif-smoke." + show (getpid 0))        ; per process: shards run at once
   a (d + "/a") b (d + "/b") l (d + "/l")
   (mkdir d 493,                                    ; EEXIST from a prior run is fine
    unlink a, unlink b, unlink l,                   ; a clean slate, tolerated if absent
    (open a "w" @ p (say p "five!", close p)),

    ; rename: the file moves whole -- old gone, new wears the same size
    (test
      !(rename a b)                                 ; ok is ()
      ((stat a) = 'enoent) (5 = <(stat b))
      ('enoent = (rename a (d + "/x")))  ; a missing source is a live errno
      ('badarg = (rename 7 b))),         ; misuse: a non-string path

    ; symlink + readlink: the target resolves from the link's directory, readlink
    ; answers it verbatim, and stat follows the link
    (test
      !(symlink "b" l)
      (readlink l = "b")
      (5 = <(stat l)) (32768 = (& 61440 <>>(stat l)))
      ((readlink b) = 'einval) ((readlink (d + "/nope")) = 'enoent)),

    ; chmod: the bits land exactly (0600 = 384); utime: milliseconds, a non-charm is "now"
    (test
      !(chmod b 384)
      (384 = (<>>(stat b) - 32768))
      !(utime b 1600000000000)
      (1600000000000 = <>(stat b))
      !(utime b ())
      (1600000000000 < <>(stat b))           ; "now" is later than the pinned past
      ('enoent = (chmod (d + "/nope") 384))  ; a miss is a live errno
      ('badarg = (chmod b "rw"))),           ; misuse: a non-charm mode

    ; chown: a no-op self-chown succeeds (-1 -1 leaves both ids alone); misuse einvals
    (test
      !(chown b -1 -1)
      ('badarg = (chown b "x" 0))),

    ; umask: always answers the previous mask, so set-read-restore round-trips
    (umask 18 @ m0
     (test (charm? m0) (18 = umask m0) (m0 = umask m0))),

    ; rmdir: the empty-directory unlink -- full is a live errno, empty goes
    ((d + "/sub") @ e
     (mkdir e 493,
      (test
        ('enotempty = (rmdir d))                   ; d holds b and l still
        !(rmdir e)
        ((stat e) = 'enoent)
        ('enoent = (rmdir e))                      ; already gone: a live errno
        ('badarg = (rmdir 7))))),

    ; hardlink: two names, one file; the survivor keeps it when the first unlinks
    ((d + "/h") @ h
     (unlink h,
      (test
        !(hardlink b h)
        (5 = <(stat h))
        ('eexist = (hardlink b h))                 ; the name is taken
        (unlink b, (5 = <(stat h)))
        !(unlink h)))),

    ; copyfile: the byte count or a nom; an empty source answers a falsy 0, so ask charm?
    (: c (d + "/c") z (d + "/z")
       ((open c "w" @ p (say p "five!", close p)),
        (open z "w" @ p (close p)),
        (test
          (5 = copyfile c (d + "/c2"))
          (5 = <(stat (d + "/c2")))
          (0 = copyfile z (d + "/z2"))            ; empty in, empty out, and 0 is the count
          ('enoent = (copyfile (d + "/nope") (d + "/c3")))
          ('badarg = (copyfile 7 c))              ; misuse: a non-string path
          !(unlink c) !(unlink z)
          !(unlink (d + "/c2")) !(unlink (d + "/z2"))))),

    ; selfpath: the running binary, an absolute path at a regular file
    (selfpath 0 @ s
     (test
       (string? s)
       (47 = peep s 0 0)                       ; absolute, whatever the cwd was
       (32768 = (& 61440 <>>(stat s)))         ; s_ifreg: a file, not the /proc link
       (0 < <(stat s)))),

    ; the os lane is compiled in, not its stub: the stub answers 'enosys, a real mount
    ; its own errno
    (mount "" "/" "no-such-fs" @ e
     (test (nom? e) !(e = 'enosys))),

    ; a NUL inside a path is misuse: the kernel would stop at it, at a shorter path
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
