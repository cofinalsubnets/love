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
; an update: a 4K head -- "hearts-update 2\n", then for the kernel, the root and the cmd each its
; enc (1 deflated, 0 stored), its length here and once inflated (u64 le) and its raw bytes' sha256,
; and right after, those bytes' ed25519 signature under /etc/hearts.pub -- then the parts back to
; back. it streams: the head is checked before anything is written, each part as it goes to its
; place, and the slot is offered to the next boot only once every part matched.
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

   ; a part poured through w as it is read off rd, inflated where it was deflated: 1 when its
   ; raw bytes are as many as the head says and hash as it says
   (pour rd pt w)
    (pt @ [enc len raw sha]
      (: h (cask 105)
         _ (sha256-init h)
         z (enc = 1 ? (inflate-new 0) 0)
         st (pins {} 'n 0 'end (enc = 0) 'bad 0)
         (out s) (? (st 'n + #s > raw) (pin st 'bad 1)
                    (sha256-feed h s, w s, pin st 'n (st 'n + #s)))
         (take c) (? (enc = 0) (out c)
                     (inflate-feed z c @ r
                       (? (string? r) (out r)
                          (two? r) (out <r, pin st 'end 1)
                          (pin st 'bad 1))))
         (go left) (? (left = 0 || st 'bad) 0
                      (rd (min left 65536) @ c (#c = 0 ? (pin st 'bad 1) (take c, go (left - #c)))))
         _ (go len)
         (!(st 'bad) && st 'end && st 'n = raw && hex2b (sha256-done h) = sha)))

   (update f)
    (: p (open f "r")
       _ (hot? p ? 0 (gone ("cannot read " + f)))
       _ (string ((state 0) 0) = slot ? 0 (tell "an update waits until this slot is well", quit 2))
       pub (uread "/etc/hearts.pub" @ r (two? r ? <>r (gone "no /etc/hearts.pub")))
       buf (pins {} 'b "")
       ; n bytes off f, fewer only where it ends
       (rd n)
        (: (go b) (#b >= n ? (pin buf 'b (snip b n #b), snip b 0 n)
                     (see p @ c (c < 0 ? (pin buf 'b "", b) (unsee p c, go (b + chug p)))))
           (go (buf 'b)))
       hd (rd 4096)
       hl (16 + 3 * 56)
       (part i) ((16 + i * 56) @ o [(rdle hd o 8) (rdle hd (o + 8) 8) (rdle hd (o + 16) 8) (snip hd (o + 24) (o + 56))])
       ok (#hd = 4096 && snip hd 0 16 = "hearts-update 2\n" && ed-verify pub (snip hd 0 hl) (snip hd hl (hl + 64)) = 1)
       (? !ok (tell ("refused " + f + ": not signed by this device's key"), quit 2)
          (: to (other slot)
             _ (mkdir ("/boot/" + to) 493)
             kp (open ("/boot/" + to + "/Image") "w")
             _ (hot? kp ? 0 (gone "cannot write the Image"))
             k (pour rd (part 0) (s \ say kp s))
             _ (close kp)
             rp (open (rootdev to) "w")
             _ (hot? rp ? 0 (gone ("cannot open " + rootdev to)))
             r (pour rd (part 1) (s \ say rp s))
             _ (close rp)
             cb (pins {} 'c "")
             c (pour rd (part 2) (s \ pin cb 'c (cb 'c + s)))
             (? !(k && r && c) (tell ("refused " + f + ": a part is not what its head signed"), quit 2)
                ((uwrite ("/boot/" + to + "/cmd") (cb 'c + " root=" + rootdev to + "\n") ? 0
                    (gone "cannot write the cmd")),
                 setstate (string ((state 0) 0) + to + "\n"),
                 tell ("update " + f + " written to slot " + to + ", tried at the next boot"))))))

   verb (#argv > 2 ? (argv 2) "")
   (verb @
     "mount"   (domount 0)
     "well"    (well 0)
     "watch"   (watch (#argv > 3 ? (read (argv 3)) 60))
     "update"  (#argv > 3 ? (update (argv 3)) (gone "update wants a file"))
     "restart" (sync 0, reboot 0)
     "off"     (sync 0, reboot 1)
     (gone ("no verb " + verb))))
