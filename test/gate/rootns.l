; test/gate/rootns.l -- chroot, mount, umount and mknod proved, not just refused: an
; unprivileged user namespace makes us root in it, so the calls are real (proc mounting wants a
; pid namespace, left out). every command goes through spawn and its real argv. a kernel with
; user namespaces off skips and stays green. run: out/love test/gate/rootns.l

(borrow 'posix)
(newns 0 @ e
   (e ? (getenv "LOVE_GATE_STRICT" || (open ((getenv "HOME") + "/.love/etc/gate-strict") "r" @ q (hot? q ? (close q, 1) 0)) ?
         (puts "rootns: no unprivileged user namespace here, laws skipped -- REFUSED: a strict box runs every lane", putc 10, quit 1)
         (puts "rootns: no unprivileged user namespace here, laws skipped", putc 10, 0))
      (:
   me (selfpath 0)
   W ("/tmp/l-rootns-" + show (getpid 0))
   (run as) (spawn (me . as) @ p (nom? p ? 127 (wait p)))
   ; stderr thrown away: the refusal rows are supposed to complain
   (nope as) (: fd (openfd "/dev/null" 1)
                p (spawnio (me . as) 0 1 fd () -1 0)
                r (nom? p ? 127 (wait p))
                (close fd,
                 r))
   ; a command's stdout: spawnio takes raw fds, not ports, so it goes through a file
   (out-of as) (: f (W + "/.cap")
                   fd (openfd f 1)               ; write, create, truncate
                   p (spawnio (me . as) 0 fd 2 () -1 0)
                   _ (nom? p ? () (wait p))
                   _ (close fd)
                   q (open f "r") s (slurp q) (close q, s))
   (has? hay needle)
    (: n #hay k #needle
       (go i) (? (n - k < i) 0 (needle = snip hay i (i + k)) 1 (go (i + 1)))
       (k <= n ? (go 0) 0))
   (mk d) (mkdir d 493)
   _ (mk W, mk (W + "/t"), mk (W + "/b"), mk (W + "/root"))

   ; -- mount: a tmpfs, and a bind that really shows the other tree --
   _ (assert (0 = run ["mount" "-t" "tmpfs" "tmpfs" (W + "/t")]))
   _ (assert (0 = run ["mount" "-o" "bind" "/etc" (W + "/b")]))
   _ (assert (elem "hosts" (readdir (W + "/b"))))
   ; a tmpfs is writable: the mount is a mount and not a mkdir
   _ (assert (open (W + "/t/x") "w" @ q (port? q && (say q "hi", close q, 1)))
             ("hi" = (: q (open (W + "/t/x") "r") s (slurp q) (close q, s))))

   ; -- bare mount lists what we did --
   ls (out-of ["mount"])
   _ (assert (0 < #ls)
             (has? ls ("tmpfs on " + W + "/t type tmpfs"))
             (has? ls (W + "/b")))

   ; -- umount both, and the tmpfs's file goes with it --
   _ (assert (0 = run ["umount" (W + "/b")]))
   _ (assert (0 = run ["umount" (W + "/t")]))
   _ (assert (atom? (stat (W + "/t/x"))))
   _ (assert (nelem "hosts" (readdir (W + "/b"))))

   ; -- mkfifo and mknod --
   ; a char device is refused even here: mknod(2) wants CAP_MKNOD in the initial user namespace,
   ; so the refusal is asserted: a status and a word, not a crash
   _ (assert (0 != nope ["mknod" (W + "/null") "c" "1" "3"]))
   _ (assert (atom? (stat (W + "/null"))))
   _ (assert (0 = run ["mkfifo" (W + "/f")]))
   _ (assert (stat (W + "/f") @ st (two? st && 4096 = 61440 & st 2)))
   _ (assert (0 = run ["mknod" (W + "/f2") "p"]))
   _ (assert (stat (W + "/f2") @ st (two? st && 4096 = 61440 & st 2)))
   ; -m lands: 0600
   _ (assert (0 = run ["mkfifo" "-m" "600" (W + "/f3")]))
   _ (assert (stat (W + "/f3") @ st (two? st && 384 = 4095 & st 2)))
   ; the refusals a script reads
   _ (assert (0 != nope ["mknod" (W + "/bad") "z"]))
   _ (assert (0 != nope ["mknod" (W + "/bad") "c"]))    ; no major/minor
   _ (assert (0 = run ["sync"]))

   ; -- chroot: the root moves and a command runs inside it --
   ; the command has to be in the new root, so love is copied in beside it
   _ (mk (W + "/root/bin"))
   _ (assert (0 = run ["cp" me (W + "/root/bin/love")]))
   _ (mk (W + "/root/hello"))
   ; `chroot DIR CMD` execs, so the status is the child's; a failed chroot would answer 1
   r (out-of ["chroot" (W + "/root") "/bin/love" "ls" "/"])
   (assert (elem "hello" (lines r)) (elem "bin" (lines r)),

    ; the tree goes last: an early rm takes the chroot's /bin/love and reads as a missing binary
    run ["rm" "-rf" W],
    puts "rootns: chroot, mount (tmpfs + bind), umount, mknod and mkfifo -- proved in a userns",
    putc 10,
    0))))
