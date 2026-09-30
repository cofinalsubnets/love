; test/gate/rootns.l -- chroot, mount, umount and mknod proved, not just refused: an
; unprivileged user namespace makes us root inside it, so the calls are real. mounting proc wants
; a pid namespace too and is left out. every command runs through spawn and its real argv, since
; the applet's dispatch, options and status are the half most likely to be wrong.
; a kernel with user namespaces off skips with a word and stays green. run: out/love test/gate/rootns.l

(borrow 'posix)
(newns 0 @ e
   (e ? (puts "rootns: no unprivileged user namespace here, laws skipped", putc 10, 0)
      (:
   me (selfpath 0)
   W ("/tmp/l-rootns-" + show (getpid 0))
   (run as) (spawn (me . as) @ p (nom? p ? 127 (wait p)))
   ; the same, with the child's stderr thrown away: the refusal rows below are
   ; SUPPOSED to complain, and a gate that prints their complaints reads like a
   ; failure to anyone scrolling past it
   (nope as) (: fd (openfd "/dev/null" 1)
                p (spawnio (me . as) 0 1 fd () -1 0)
                r (nom? p ? 127 (wait p))
                (close fd,
                 r))
   ; a command's stdout, as a string. spawnio's in/b/err are RAW FDS and not
   ; ports, so a jug cannot be handed to it -- the capture goes through a file the
   ; child writes and this side reads back.
   (out-of as) (: f (W + "/.cap")
                   fd (openfd f 1)               ; 1 = write, create, truncate
                   p (spawnio (me . as) 0 fd 2 () -1 0)
                   _ (nom? p ? () (wait p))
                   _ (close fd)
                   q (open f "r") s (slurp q) (close q, s))
   ; is `needle` anywhere in `hay`? love has no regex operator and this file wants
   ; one question asked once
   (has? hay needle)
    (: n #hay k #needle
       (go i) (? (n - k < i) 0 (needle = snip hay i (i + k)) 1 (go (i + 1)))
       (k <= n ? (go 0) 0))
   (mk d) (mkdir d 493)
   _ (mk W, mk (W + "/t"), mk (W + "/b"), mk (W + "/root"))

   ; -- mount: a tmpfs, and a bind that really shows the other tree ---------------
   _ (assert (0 = run ["mount" "-t" "tmpfs" "tmpfs" (W + "/t")]))
   _ (assert (0 = run ["mount" "-o" "bind" "/etc" (W + "/b")]))
   _ (assert (elem "hosts" (readdir (W + "/b"))))   ; the bind is not a nod
   ; a tmpfs is writable, which is what says the mount is a mount and not a mkdir
   _ (assert (open (W + "/t/x") "w" @ q (port? q && (say q "hi", close q, 1)))
             ("hi" = (: q (open (W + "/t/x") "r") s (slurp q) (close q, s))))

   ; -- bare mount lists what we just did, /proc/self/mounts being the one truth ---
   ls (out-of ["mount"])
   _ (assert (0 < #ls)
             (has? ls ("tmpfs on " + W + "/t type tmpfs"))
             (has? ls (W + "/b")))

   ; -- umount, both of them, and the tmpfs's file goes with it ------------------
   _ (assert (0 = run ["umount" (W + "/b")]))
   _ (assert (0 = run ["umount" (W + "/t")]))
   _ (assert (atom? (stat (W + "/t/x"))))          ; the tmpfs took its contents away
   _ (assert (nelem "hosts" (readdir (W + "/b"))))

   ; -- mkfifo and mknod ---------------------------------------------------------
   ; a CHARACTER DEVICE is refused even here, and that is the kernel's policy and
   ; not ours: mknod(2) wants CAP_MKNOD in the INITIAL user namespace, so a userns
   ; root cannot make one however root it looks. The refusal is asserted instead --
   ; that it comes back as a status and a word rather than a crash is the half this
   ; gate can actually say.
   _ (assert (0 != nope ["mknod" (W + "/null") "c" "1" "3"]))
   _ (assert (atom? (stat (W + "/null"))))
   ; the fifo lane is allowed, both ways of spelling it
   _ (assert (0 = run ["mkfifo" (W + "/f")]))
   _ (assert (stat (W + "/f") @ st (two? st && 4096 = 61440 & st 2)))
   _ (assert (0 = run ["mknod" (W + "/f2") "p"]))
   _ (assert (stat (W + "/f2") @ st (two? st && 4096 = 61440 & st 2)))
   ; -m lands: 0600 on the second, the default 0666 on the first
   _ (assert (0 = run ["mkfifo" "-m" "600" (W + "/f3")]))
   _ (assert (stat (W + "/f3") @ st (two? st && 384 = 4095 & st 2)))
   ; and the refusals a script reads
   _ (assert (0 != nope ["mknod" (W + "/bad") "z"]))
   _ (assert (0 != nope ["mknod" (W + "/bad") "c"]))    ; a device with no major/minor
   _ (assert (0 = run ["sync"]))

   ; -- chroot: the root moves and a command runs inside it ----------------------
   ; the command has to BE in the new root, so love is copied in beside it. this is
   ; the whole of LFS chapter 7 in four lines, and it is what the gate exists for.
   _ (mk (W + "/root/bin"))
   _ (assert (0 = run ["cp" me (W + "/root/bin/love")]))
   _ (mk (W + "/root/hello"))
   ; `chroot DIR CMD` execs, so it never comes back -- the status is the CHILD's,
   ; and a chroot that quietly failed would answer 1 here rather than ls's own 0.
   r (out-of ["chroot" (W + "/root") "/bin/love" "ls" "/"])
   (assert (elem "hello" (lines r)) (elem "bin" (lines r)),

    ; the tree goes LAST and only on the way out: an early rm would take the
    ; chroot's own /bin/love with it, and the failure would read as a missing binary.
    run ["rm" "-rf" W],
    puts "rootns: chroot, mount (tmpfs + bind), umount, mknod and mkfifo -- proved in a userns",
    putc 10,
    0))))
