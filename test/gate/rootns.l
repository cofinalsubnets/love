; test/gate/rootns.l -- chroot, mount, umount and mknod PROVED, not just refused.
;
; the privileged verbs cannot be smoked as an ordinary user, and a gate that only
; watched them answer 'eperm would pass just as well against a stub. `newns` is the
; way out: an unprivileged user namespace makes us root inside it, and then the calls
; are the real calls on a real kernel. What the namespace still refuses (mounting
; proc, which wants a pid namespace too) is left out rather than worked around.
;
; ⚠ every command below runs through SPAWN and the real argv, not by calling a main:
; the applet's own dispatch, option walk and status are the half most likely to be
; wrong, and a direct call skips all three. the child inherits the namespace, which
; is the whole reason this can be one process's worth of setup.
;
; run standalone:  out/love test/gate/rootns.l
; a kernel with unprivileged user namespaces off skips the file with a word and
; stays green -- that is a machine's policy, not a fault in the code.

(: e (newns 0)
   (? e (: _ (puts "rootns: no unprivileged user namespace here, laws skipped")
           _ (putc 10) 0)
      (:
   me (selfpath 0)
   W ("/tmp/l-rootns-" + (show (getpid 0)))
   (run as) (: p (spawn (me >< as)) (? (nom? p) 127 (wait p)))
   ; the same, with the child's stderr thrown away: the refusal rows below are
   ; SUPPOSED to complain, and a gate that prints their complaints reads like a
   ; failure to anyone scrolling past it
   (nope as) (: fd (openfd "/dev/null" 1)
                p (spawnio (me >< as) 0 1 fd () -1 0)
                r (? (nom? p) 127 (wait p))
                _ (close fd)
                r)
   ; a command's stdout, as a string. ⚠ spawnio's in/out/err are RAW FDS and not
   ; ports, so a jug cannot be handed to it -- the capture goes through a file the
   ; child writes and this side reads back.
   (out-of as) (: f (W + "/.cap")
                   fd (openfd f 1)               ; 1 = write, create, truncate
                   p (spawnio (me >< as) 0 fd 2 () -1 0)
                   _ (? (nom? p) () (wait p))
                   _ (close fd)
                   q (open f "r") s (slurp q) _ (close q) s)
   ; is `needle` anywhere in `hay`? love has no regex operator and this file wants
   ; one question asked once
   (has? hay needle)
    (: n #hay k #needle
       (go i) (? ((n - k) < i) 0 (needle = (snip hay i (i + k))) 1 (go (i + 1)))
       (? (k <= n) (go 0) 0))
   (mk d) (mkdir d 493)
   _ (mk W) _ (mk (W + "/t")) _ (mk (W + "/b")) _ (mk (W + "/root"))

   ; -- mount: a tmpfs, and a bind that really shows the other tree ---------------
   _ (assert (0 = (run ["mount" "-t" "tmpfs" "tmpfs" (W + "/t")])))
   _ (assert (0 = (run ["mount" "-o" "bind" "/etc" (W + "/b")])))
   _ (assert (member? "hosts" (readdir (W + "/b"))))   ; the bind is not a nod
   ; a tmpfs is writable, which is what says the mount is a mount and not a mkdir
   _ (assert (: q (open (W + "/t/x") "w") (port? q && (: _ (say q "hi") _ (close q) 1)))
             ("hi" = (: q (open (W + "/t/x") "r") s (slurp q) _ (close q) s)))

   ; -- bare mount lists what we just did, /proc/self/mounts being the one truth ---
   ls (out-of ["mount"])
   _ (assert (0 < #ls)
             (has? ls ("tmpfs on " + W + "/t type tmpfs"))
             (has? ls (W + "/b")))

   ; -- umount, both of them, and the tmpfs's file goes with it ------------------
   _ (assert (0 = (run ["umount" (W + "/b")])))
   _ (assert (0 = (run ["umount" (W + "/t")])))
   _ (assert !(two? (stat (W + "/t/x"))))          ; the tmpfs took its contents away
   _ (assert !(member? "hosts" (readdir (W + "/b"))))

   ; -- mkfifo and mknod ---------------------------------------------------------
   ; ⚠ a CHARACTER DEVICE is refused even here, and that is the kernel's policy and
   ; not ours: mknod(2) wants CAP_MKNOD in the INITIAL user namespace, so a userns
   ; root cannot make one however root it looks. The refusal is asserted instead --
   ; that it comes back as a status and a word rather than a crash is the half this
   ; gate can actually say.
   _ (assert (0 != (nope ["mknod" (W + "/null") "c" "1" "3"])))
   _ (assert !(two? (stat (W + "/null"))))
   ; the fifo lane is allowed, both ways of spelling it
   _ (assert (0 = (run ["mkfifo" (W + "/f")])))
   _ (assert (: st (stat (W + "/f")) (two? st && (4096 = (& 61440 (st 2))))))
   _ (assert (0 = (run ["mknod" (W + "/f2") "p"])))
   _ (assert (: st (stat (W + "/f2")) (two? st && (4096 = (& 61440 (st 2))))))
   ; -m lands: 0600 on the second, the default 0666 on the first
   _ (assert (0 = (run ["mkfifo" "-m" "600" (W + "/f3")])))
   _ (assert (: st (stat (W + "/f3")) (two? st && (384 = (& 4095 (st 2))))))
   ; and the refusals a script reads
   _ (assert (0 != (nope ["mknod" (W + "/bad") "z"])))
   _ (assert (0 != (nope ["mknod" (W + "/bad") "c"])))    ; a device with no major/minor
   _ (assert (0 = (run ["sync"])))

   ; -- chroot: the root moves and a command runs inside it ----------------------
   ; the command has to BE in the new root, so love is copied in beside it. this is
   ; the whole of LFS chapter 7 in four lines, and it is what the gate exists for.
   _ (mk (W + "/root/bin"))
   _ (assert (0 = (run ["cp" me (W + "/root/bin/love")])))
   _ (mk (W + "/root/hello"))
   ; ⚠ `chroot DIR CMD` execs, so it never comes back -- the status is the CHILD's,
   ; and a chroot that quietly failed would answer 1 here rather than ls's own 0.
   r (out-of ["chroot" (W + "/root") "/bin/love" "ls" "/"])
   _ (assert (member? "hello" (lines r)) (member? "bin" (lines r)))

   ; ⚠ the tree goes LAST and only on the way out: an early rm would take the
   ; chroot's own /bin/love with it, and the failure would read as a missing binary.
   _ (run ["rm" "-rf" W])
   _ (puts "rootns: chroot, mount (tmpfs + bind), umount, mknod and mkfifo -- proved in a userns")
   _ (putc 10)
   0)))
