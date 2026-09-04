; --- test/host/fs.l: smoke test for the fs nifs (src/posix.c) ---
; rename/symlink/readlink/chmod/chown/utime/umask link into `love` and love0 now
; (love0 carries the whole host/*.c glob since the self-host promotion); this
; still runs standalone against the built binary, like test/host/init.l --
; not in test/*.l. Run (assert comes from test/00-init.l):
;   cat test/00-init.l test/host/fs.l | out/host/love
; the conventions under test are src/posix.c's posix_ lane: an effect op answers
; () ok | an errno nom | 'badarg misuse; a value op answers the value | () | a nom.

(: d "out/.fs-nif-smoke"
   a (+ d "/a") b (+ d "/b") l (+ d "/l")
   _ (mkdir d 493)                                  ; EEXIST from a prior run is fine
   _ (unlink a) _ (unlink b) _ (unlink l)           ; a clean slate, tolerated if absent
   _ (: p (open a "w") _ (say p "five!") (close p))

   ; rename: the file moves whole -- old gone, new wears the same size
   _ (assert
       !(rename a b)                                ; ok is ()
       ((stat a) = 'enoent) (= 5 (cap (stat b)))
       ('enoent = (rename a (+ d "/x")))          ; a missing source is a live errno
       ('badarg = (rename 7 b)))                  ; misuse: a non-string path

   ; symlink + readlink: path becomes a link to target -- and the target string
   ; resolves relative to the link's directory, so a link beside its file names
   ; it bare. readlink answers that string verbatim; on a non-link (or a miss)
   ; it is nothing. stat follows the link, so through l it sees the file whole.
   _ (assert
       !(symlink "b" l)
       (= (readlink l) "b")
       (= 5 (cap (stat l))) (= 32768 (& 61440 (cauup (stat l))))
       ((readlink b) = 'einval) ((readlink (+ d "/nope")) = 'enoent))

   ; chmod: the permission bits land exactly (0600 = 384); utime: the mtime
   ; lands on the stat scale (MILLISECONDS), and a non-charm ms reads "now"
   _ (assert
       !(chmod b 384)
       (= 384 (- (cauup (stat b)) 32768))
       !(utime b 1600000000000)
       (= 1600000000000 (caup (stat b)))
       !(utime b ())
       (< 1600000000000 (caup (stat b)))            ; "now" is later than the pinned past
       ('enoent = (chmod (+ d "/nope") 384))      ; a miss is a live errno
       ('badarg = (chmod b "rw")))                ; misuse: a non-charm mode

   ; chown: a no-op self-chown succeeds (-1 -1 leaves both ids alone); misuse einvals
   _ (assert
       !(chown b -1 -1)
       ('badarg = (chown b "x" 0)))

   ; umask: always answers the previous mask, so set-read-restore round-trips
   _ (: m0 (umask 18)
        (assert (charm? m0) (= 18 (umask m0)) (= m0 (umask m0))))

   ; rmdir: the empty-directory unlink -- full is a live errno, empty goes
   _ (: e (+ d "/sub")
        _ (mkdir e 493)
        (assert
          ('enotempty = (rmdir d))                 ; d holds b and l still
          !(rmdir e)
          ((stat e) = 'enoent)
          ('enoent = (rmdir e))                    ; already gone: a live errno
          ('badarg = (rmdir 7))))

   ; hardlink: two names, one file -- content shows through both, and the
   ; survivor keeps it when the first name unlinks
   _ (: h (+ d "/h")
        _ (unlink h)
        (assert
          !(hardlink b h)
          (= 5 (cap (stat h)))
          ('eexist = (hardlink b h))               ; the name is taken
          (: _ (unlink b) (= 5 (cap (stat h))))
          !(unlink h)))

   ; copyfile: a value op -- the byte count, or the failure's nom. an empty source
   ; answers 0, a falsy success, which is why every caller asks charm? and never
   ; the truth.
   _ (: c (+ d "/c") z (+ d "/z")
        _ (: p (open c "w") _ (say p "five!") (close p))
        _ (: p (open z "w") (close p))
        (assert
          (= 5 (copyfile c (+ d "/c2")))
          (= 5 (cap (stat (+ d "/c2"))))
          (= 0 (copyfile z (+ d "/z2")))            ; empty in, empty out, and 0 is the count
          ('enoent = (copyfile (+ d "/nope") (+ d "/c3")))
          ('badarg = (copyfile 7 c))              ; misuse: a non-string path
          !(unlink c) !(unlink z)
          !(unlink (+ d "/c2")) !(unlink (+ d "/z2"))))

   ; selfpath: the running binary's own path, the seat every library walk starts
   ; from. no cwd and no argv here -- an absolute path at a real regular file is
   ; the whole contract, and it is what the per-OS doors have to agree on.
   _ (: s (selfpath 0)
        (assert
          (string? s)
          (= 47 (peep s 0 0))                       ; absolute, whatever the cwd was
          (= 32768 (& 61440 (cauup (stat s))))      ; s_ifreg: a file, not the /proc link
          (< 0 (cap (stat s)))))

   ; the OS roster: the linux lane is compiled in, not its stub. a lost
   ; __linux__ predefine compiles posix.c's lanes out in silence, so probe one:
   ; the stub always answers 'enosys, the real mount answers the call's own
   ; errno (nobody mounts "" on / as no-such-fs). sigfd's twin assert lives in
   ; test/host/sh.l. forks on the OS when a second one joins.
   _ (: e (mount "" "/" "no-such-fs")
        (assert (nom? e) (! (e = 'enosys))))

   _ (unlink l) _ (unlink b)
   _ (test_fin ())
   _ (say out "fs: ok") (put out 10))
