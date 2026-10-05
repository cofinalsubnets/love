; src/apps/hearts/dev.l -- hearts on the device: the slot this boot came up on, its commit, a
; trial's deadline, and a signed update written to the other slot. run by helm's units:
;   love dev.l mount         the ESP rw at /boot, data at /data, an update disk at /drop if any
;   love dev.l well          the app is well: a trial boot becomes the active slot
;   love dev.l watch SECS    a trial not well by then is restarted, and comes back on the active
;   love dev.l update FILE   a signed update into the other slot, tried at the next boot;
;                            exit 2 when it is refused
;   love dev.l restart | off
; the chooser (src/inle/uefi/slot.c) spends a trial before it boots, so this side only commits.
; slot a's root is /dev/vda2 and b's /dev/vda3; /boot/hearts.st is active, trial, newline.
; an update: "hearts-update 1\n", the kernel's, root's and cmd's lengths (u64 le), the three,
; then the ed25519 signature of that much's sha256 under /etc/hearts.pub, and whatever padding.
(borrow 'bytes)
(borrow 'posix)
(: argv cmdline
   ; by name: a borrow of 'ssh would bring its own split
   ed-verify (cite 'ssh 'ed-verify)
   (tell s) (say err ("hearts: " + s + "\n"))
   (gone s) (tell s, quit 1)
   line (uread "/proc/cmdline" @ r (two? r ? <>r ""))
   (arg k) (foldl (a \ w \ w @ (key + "=" + v) (key = k ? v a) a) "" (words line))
   slot (arg "hearts.slot")
   trial (arg "hearts.try" = "1")
   (other s) (s = "a" ? "b" "a")
   (rootdev s) (s = "a" ? "/dev/vda2" "/dev/vda3")
   (state _) (uread "/boot/hearts.st" @ r (two? r && #(<>r) = 3 ? <>r (gone "no state in /boot/hearts.st")))
   (setstate s) (uwrite "/boot/hearts.st" s ? (sync 0) (gone "cannot write /boot/hearts.st"))

   (domount _)
    (mount "/dev/vda1" "/boot" "vfat" @ r (nom? r ? (gone ("cannot mount the ESP: " + show r)) 0),
     mount "/dev/vda4" "/data" "vfat" @ r (nom? r ? (gone ("cannot mount data: " + show r)) 0),
     (two? (stat "/dev/vdb") ? (mount "/dev/vdb" "/drop" "vfat") 0),
     tell ("up on slot " + slot + (trial ? ", a trial" "")))

   (well _)
    (? !trial (tell ("well on slot " + slot))
       (setstate (slot + "-\n"), tell ("well on slot " + slot + ": committed")))

   (watch secs)
    (? !trial 0
       (rest (secs * 1000),
        state 0 @ s
          (string (s 0) = slot ? 0
             (tell ("slot " + slot + " never said it was well: back to slot " + string (s 0)),
              sync 0, reboot 0))))

   ; the archive's own lengths say where it ends: a disk carrying one pads it out
   (update f)
    (: u (uread f @ r (two? r ? <>r (gone ("cannot read " + f))))
       hd "hearts-update 1\n"
       pub (uread "/etc/hearts.pub" @ r (two? r ? <>r (gone "no /etc/hearts.pub")))
       h0 #hd
       kl (#u >= h0 + 24 ? (rdle u h0 8) 0)
       rl (#u >= h0 + 24 ? (rdle u (h0 + 8) 8) 0)
       cl (#u >= h0 + 24 ? (rdle u (h0 + 16) 8) 0)
       k0 (h0 + 24) r0 (k0 + kl) c0 (r0 + rl) n (c0 + cl)
       ok (n + 64 <= #u && snip u 0 h0 = hd && ed-verify pub (hex2b (sha256 (snip u 0 n))) (snip u n (n + 64)) = 1)
       (? !ok (tell ("refused " + f + ": not signed by this device's key"), quit 2)
          (: to (other slot)
             p (open (rootdev to) "w")
             _ (hot? p ? (say p (snip u r0 c0), close p) (gone ("cannot open " + rootdev to)))
             _ (mkdir ("/boot/" + to) 493)
             _ (uwrite ("/boot/" + to + "/Image") (snip u k0 r0) ? 0 (gone "cannot write the Image"))
             _ (uwrite ("/boot/" + to + "/cmd") (snip u c0 n + " root=" + rootdev to + "\n")
                ? 0 (gone "cannot write the cmd"))
             (setstate (string ((state 0) 0) + to + "\n"),
              tell ("update " + f + " written to slot " + to + ", tried at the next boot")))))

   verb (#argv > 2 ? (argv 2) "")
   (verb @
     "mount"   (domount 0)
     "well"    (well 0)
     "watch"   (watch (#argv > 3 ? (read (argv 3)) 60))
     "update"  (#argv > 3 ? (update (argv 3)) (gone "update wants a file"))
     "restart" (sync 0, reboot 0)
     "off"     (sync 0, reboot 1)
     (gone ("no verb " + verb))))
