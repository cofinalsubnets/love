; src/apps/hearts/pcimage.l -- hearts on a pc's own disk, beside what it already boots: a FAT
; part labelled HEARTS that the pc's loader chainloads (EFI/BOOT/BOOTX64.EFI, love's boot menu,
; src/inle/uefi), the bzImage it starts with the root built in (CONFIG_INITRAMFS_SOURCE), and a
; data part named hearts-data, which the root finds by its name
;   love .. pcimage.l root OUT LOVE [STAMP [SITE]]       writes OUT/root.cpio, the kernel's input
;   love .. pcimage.l fat OUT KERNEL EFI KELF SECTORS [AT [STAMP [INITRD]]]   writes OUT/fat.img
; (load with -l src/apps/tar.l -l src/apps/cpio.l -l src/apps/sqfs.l)
;   LOVE is a baked x64 love, KERNEL the bzImage, EFI love's BOOTX64.EFI, KELF the love.elf it
;   starts, SECTORS the FAT's size and AT its part's first sector (the boot sector's hidden
;   sectors, 0 by default), STAMP the one time every file carries (seconds, default 0): the same
;   inputs give the same bytes on any host. INITRD a cpio the menu hands a kernel that carries
;   no root of its own. SITE a directory laid into /etc, this pc's own: hostname and
;   ssh/authorized_keys
; a root: love as /bin/love and /bin/sh, helm's script as init (/bin/helm), a shell on tty1,
; dhcp on the first wire (src/apps/wifi's -w), sshd, their state on data
(borrow '(bytes posix fat tar cpio sqfs hashes))
(: ; its words are the ones after its own name, whatever loaded ahead of it
   (after l) (atom? l ? () (<l @ (_ + "pcimage.l") >l (after >l)))
   as (after cmdline)
   (gone s) (say err ("hearts-pcimage: " + s + "\n"), quit 1)
   (rd f) (uread f @ r (two? r ? <>r (gone ("cannot read " + f))))
   (le v n) (wrle v n)

   ; --- FAT, laid in memory ----------------------------------------------------
   ; the label in both boot sectors and as the root's first entry, where a loader looks for
   ; it by name; the hidden sectors its part's start
   (fatimg at lab nsec files)
    (: im (cask (nsec * 512))
       dev [(lba \ k \ (cask (k * 512) @ b (pour b 0 im (lba * 512) (k * 512), string b)))
            (lba \ s \ (pour im (lba * 512) s 0 #s, #s // 512)) nsec (stamp * 1000)]
       _ (fat-mkfs dev || gone "fat-mkfs refused")
       f (fat-mount dev)
       nm (snip (lab + "           ") 0 11)
       _ (each [0 6] (k \ (pour im (k * 512 + 28) (le at 4) 0 4, pour im (k * 512 + 71) nm 0 11)))
       _ ((dev 1) (f 7) (nm + string [8] + zbytes 500))
       (dirs path) (: ws (split "/" path)
                     (go acc l) (two? >l ? (fat-mkdir f (acc + <l), go (acc + <l + "/") >l) 0)
                     (go "" ws))
       _ (each files (x \ x @ [path b] (dirs path, fat-write f path b || gone ("fat-write " + path))))
       (string im))

   ; --- a root -------------------------------------------------------------------
   helm-conf """
     (service app (exec "/bin/love" "/app/run.l") (restart no))
     (oneshot host (exec "/bin/love" "/app/host.l"))
     (oneshot data (exec "/bin/love" "/app/data.l"))
     (oneshot boot (exec "/bin/love" "/app/boot.l"))
     ; the console's own session, so a ^C there reaches what runs there; -w keeps one shell:
     ; helm starts a group leader, so setsid forks, and a parent gone is a restart
     (service console
       (exec "/bin/love" "sh" "-c" "exec /bin/love setsid -cw /bin/love sh < /dev/tty1 > /dev/tty1 2>&1")
       (restart always))
     (service net (after data host)
       (exec "/bin/love" "-l" "/app/wifi/netlink.l" "-l" "/app/wifi/dhcp.l" "/app/wifi/wifi.l" "-w" "*")
       (log "/data/net.log") (restart always))
     (service sshd (after data)
       (exec "/bin/love" "sshd" "-o" "AuthorizedKeysFile=/etc/ssh/authorized_keys")
       (env "HOME" "/data/root") (log "/data/sshd.log") (restart always))
     (target default (wants app console net sshd boot))
     """
   ; a part by its gpt name, its device's name in /dev once the kernel has seen it. a oneshot
   ; has 3 s of helm's patience before what comes after it starts: 2.5 s of looking
   part-l """
     (borrow 'posix)
     (: (part n k) (: bs (filter (b \ uread ("/sys/class/block/" + b + "/uevent") @ [1 s] (has? s ("PARTNAME=" + n + "\n")) 0)
                                 (sort (readdir "/sys/class/block")))
                      (? (two? bs) ("/dev/" + <bs) (k > 0) (rest 500, part n (k - 1)) ()))
     """
   ; data's ext4 on /data, read-write; with no such part, or a refusal, a tmpfs stands in, gone
   ; at each boot
   data-l (part-l + """
        (tell s) (say err ("data: " + s + "\n"))
        (tmp s) (tell (s + ", a tmpfs instead"), mount "tmpfs" "/data" "tmpfs")
        d (part "hearts-data" 5)
        _ (? (d = ()) (tmp "no part named hearts-data")
             (mount d "/data" "ext4" @ r (nom? r ? (tmp ("ext4 refused (" + show r + ")")) (tell (d + " on /data")))))
        (umkdirs "/data/root/.ssh" 448, 0))
     """)
   ; the FAT on /boot, read-write: an update writes there
   boot-l (part-l + """
        d (part "hearts" 5)
        (? (d = ()) (say err "boot: no part named hearts\n", 1)
           (mount d "/boot" "vfat" @ r (nom? r ? (say err ("boot: vfat refused (" + show r + ")\n"), 1) 0))))
     """)
   ; the kernel's name, /etc/hostname's line: dhcp sends it
   host-l """
     (borrow 'posix)
     (uread "/etc/hostname" @ [1 s] (uwrite "/proc/sys/kernel/hostname" (snip s 0 (#s - 1))) 0)
     """
   ; the app: the machine as its firmware names it, on the console
   app-l """
     (borrow 'posix)
     (: (id f) (uread ("/sys/class/dmi/id/" + f) @ [1 s] (s @ (t + "\n") t s) "?")
        (say err ("hearts: " + id "sys_vendor" + " " + id "product_version" + "\n")))
     """
   (dir kids) ['dir 493 kids]
   (fil mode b) ['file mode b]
   (link t) ['link t]
   app-wifi (map (f \ [f (fil 420 (rd ("src/apps/wifi/" + f)))]) ["dhcp.l" "netlink.l" "wifi.l"])
   (root love ver site)
    (dir [["app" (dir [["boot.l" (fil 420 boot-l)] ["data.l" (fil 420 data-l)] ["host.l" (fil 420 host-l)]
                       ["run.l" (fil 420 app-l)] ["wifi" (dir app-wifi)]])]
        ["bin" (dir [["helm" (fil 493 helm)] ["love" (fil 493 love)] ["sh" (link "love")]])]
        ["boot" (dir ())] ["data" (dir ())] ["dev" (dir [["console" ['chr 384 [5 1]]]])]
        ["etc" (dir (sort (site + [["helm.l" (fil 420 helm-conf)] ["version" (fil 420 (ver + "\n"))]
                                   ["passwd" (fil 420 "root:x:0:0:root:/data/root:/bin/sh\n")]
                                   ["resolv.conf" (link "/run/resolv.conf")]])))]
        ["proc" (dir ())] ["run" (dir ())] ["sys" (dir ())] ["tmp" (dir ())]
        ["usr" (dir [["bin" (dir ())] ["src" (dir ())]])]])
   ; the tree as cpio entries, each directory ahead of what it holds
   (walk pre t acc) (t @ ['dir _ ks] (foldl (a \ k \ k @ [n x] (: p (pre + n) (walk (p + "/") x (ent1 p x . a)))) acc ks)
                         _ acc)
   (ent1 p x) (: e (tar-entry p <x (x @ ['file _ b] b ""))
                 (pins e 'mode (x 1) 'mtime stamp,
                  x @ ['link t] (pins e 'mode 511 'to t) ['chr _ d] (pin e 'rdev d) _ e))
   ; helm is four files catted into one script, run by love as the kernel's init
   helm ("#!/bin/love\n" + join "" (map rd ["src/apps/helm/unit.l" "src/apps/helm/sup.l"
                                            "src/apps/helm/moor.l" "src/apps/helm/helm.l"]))

   ; --- the boot files -----------------------------------------------------------
   ; a panic reboots, and the pc's loader then boots what it boots by default. the screen is
   ; the console; the first serial port, where there is one, hears the kernel too
   cmd "rdinit=/bin/helm console=ttyS0,115200 console=tty0 panic=10"
   (bootl initrd) ("(timeout 3)\n(default 0)\n(entry \"hearts\" \"/bzImage\" \"" + cmd + "\""
                   + (initrd ? " \"/root.cpio\"" "") + ")\n")

   verb (as 0)
   odir (as 1)
   ; root's words: OUT LOVE STAMP SITE; fat's: OUT KERNEL EFI KELF SECTORS AT STAMP INITRD
   (opt i d) (#as > i ? (as i) d)
   stamp (read (opt (verb = "root" ? 3 7) "0"))
   (mkroot _)
    (: love (rd (as 2))
       site (#as > 4 ? (sqfs-tree (as 4) @ ['dir _ ks] ks ()) ())
       (uwrite (odir + "/root.cpio") (cpio-pack (rev (walk "" (root love "v1" site) ()))),
        say err "hearts-pcimage: root.cpio\n"))
   (mkfat _)
    (: kernel (rd (as 2))
       ird (#as > 8 ? (rd (as 8)) ())
       nsec (read (as 5))
       at (read (opt 6 "0"))
       _ (2 * #kernel + #(ird || "") + 16 * 1048576 < nsec * 512 || gone "the FAT holds no second bzImage")
       fs [["EFI/BOOT/BOOTX64.EFI" (rd (as 3))] ["love.elf" (rd (as 4))] ["love.stay" "stay\n"]
           ["love.cmd" "src/inle/uefi/menu.l\n"] ["boot.l" (bootl ird)] ["bzImage" kernel]]
       (uwrite (odir + "/fat.img") (fatimg at "HEARTS" nsec (fs + (ird ? [["root.cpio" ird]] ()))),
        say err "hearts-pcimage: fat.img\n"))
   (? (verb = "root" && 2 < #as) (mkroot 0)
      (verb = "fat" && 5 < #as) (mkfat 0)
      (gone "usage: pcimage.l root OUT LOVE [STAMP [SITE]] | fat OUT KERNEL EFI KELF SECTORS [AT [STAMP [INITRD]]]")))
