#!/bin/love
; boot.l -- the initramfs /init: love as pid 1 on linux. mounts the fhs filesystems, then
; hands the console to lush (/lib/sh.l) and never exits: pid 1 leaving panics the kernel.
;   qemu ... -kernel <bzImage> -initrd initramfs.cpio.gz -append "console=ttys0 rdinit=/init"
; run where getpid != 1 it prints the banner and returns: no mounts, no handoff.
(borrow 'posix)
(: (say1 s) (puts s, puts "\n")

   ; mount answers () on success, else an error name (ebusy where the kernel auto-mounted devtmpfs)
   (mnt src tgt typ)
     (: _ (mkdir tgt 493)
        r (mount src tgt typ)
        (say1 ("  mount " + typ + " on " + tgt
               + (r < 0 ? (" -> errno " + show (0 - r)) " -> ok"))))

   ; a fresh love running the shell on the inherited console. -l registers module 'lush;
   ; -e borrows it in one use, since compile is per-binding and (sh 0) compiles after the splice
   (console _) ["/bin/love" "-l" "/lib/sh.l" "-e" "(: _ (borrow 'lush) (sh 0))"]

   ; a real userland command, forked and captured, before the tty is handed off
   (selfcheck _)
     (hark ["/bin/kore" "ls" "/proc"] @ r
        (say1 ("-- self-check: kore ls /proc -> exit " + show <r
               + ", " + show #>r + " bytes --")))

   ; pid 1's loop: reap every child; the console dying respawns it, any other is an orphan.
   ; a non-pair glean (nothing pending) paces the loop
   (harvest shpid)
     (glean 0 @ ev
        (two? ev ?
             (<ev = shpid ? (say1 "  [init] console exited -> respawn", harvest (spawn (console 0)))
                            (say1 "  [init] reaped a reparented orphan", harvest shpid))
           (rest 50, harvest shpid)))

   (boot-init _)
     (getpid 0 @ me
        (say1 ("-- love as PID " + show me + " -- the initramfs /init --"),
         me = 1 ?
             (say1 "-- mount the early filesystems --",
              mnt "proc"     "/proc" "proc",
              mnt "sysfs"    "/sys"  "sysfs",
              mnt "devtmpfs" "/dev"  "devtmpfs",
              selfcheck 0,
              say1 "-- start the console shell (init -> sh -> real programs) --",
              harvest (spawn (console 0)))
           (say1 "  (NOT pid 1 -- host dry run: no mounts, no handoff)", 0))))
(boot-init 0)
