; src/apps/hearts/zimage.l -- rung 2's card: an MBR disk for the raspberry pi zero 2 w, its whole
; system one file. the root is a newc cpio built into the kernel (CONFIG_INITRAMFS_SOURCE), so
;   love .. zimage.l root OUT LOVE FW [STAMP [SITE]]   writes OUT/root.cpio, the kernel's input
;   love .. zimage.l disk OUT IMAGE DTB FW [STAMP]      writes OUT/disk.img from that kernel
; the disk: 1 boot (FAT32): the firmware, autoboot.txt, config.txt, cmdline.txt, Image, the dtb;
; 2 data (ext4).
; an update is a second file beside the first: Image.new, run once by the firmware's tryboot,
; renamed over Image when the board comes up on it, else a plain reboot runs Image again.
; a root: love as /bin/love and /bin/sh, helm's script as init (/bin/helm), an app that says the
; board, the otg port's console, wifi's station (src/apps/wifi) and sshd, their state on data.
; (load with -l src/apps/tar.l -l src/apps/cpio.l -l src/apps/sqfs.l -l src/apps/ext4.l)
;   LOVE is a baked a64 love, IMAGE the kernel, DTB the board's, FW the firmware's directory
;   (bootcode.bin start.elf fixup.dat LICENCE.broadcom, and wifi/, the root's /lib/firmware,
;   where it has one), STAMP the one time every file carries (seconds, default 0): the same
;   inputs give the same bytes on any host. SITE a directory laid into /etc, this card's own:
;   wifi.conf (the ssid's line, the passphrase's, the country's) and ssh/authorized_keys
(borrow '(bytes posix fat tar cpio sqfs ext4 hashes))
(: ; its words are the ones after its own name, whatever loaded ahead of it
   (after l) (atom? l ? () (<l @ (_ + "zimage.l") >l (after >l)))
   as (after cmdline)
   (gone s) (say err ("hearts-zimage: " + s + "\n"), quit 1)
   (rd f) (uread f @ r (two? r ? <>r (gone ("cannot read " + f))))
   (le v n) (wrle v n)
   mib 2048                                          ; sectors

   ; --- MBR ---------------------------------------------------------------------
   ; an entry in LBA alone: its CHS fields say past the limit, as any disk this size must
   (ent act ty at n) (n = 0 ? (zbytes 16)
                    (string act + string 0xFE + string 0xFF + string 0xFF + string ty
                     + string 0xFE + string 0xFF + string 0xFF + le at 4 + le n 4))
   (sect lead es) (lead + join "" es + zbytes (64 - 16 * #es) + string 0x55 + string 0xAA)
   sig (snip (hex2b (sha256 "hearts rung 2 disk")) 0 4)   ; the same signature every build
   (mbr ps) (sect (zbytes 440 + sig + zbytes 2) ps)

   ; the disk written front to back, each block at its sector and the gaps zeros
   (disk path bs total)
    (: p (open path "w")
       _ (hot? p ? 0 (gone ("cannot write " + path)))
       (pad n) (n > 0 ? (zbytes (min n (8 * 1048576)) @ z (say p z, pad (n - #z))))
       (go at l) (? (atom? l) (pad ((total - at) * 512))
                    (<l @ [s b] (pad ((s - at) * 512), say p b, go (s + #b // 512 + (#b % 512 > 0 ? 1 0)) >l)))
       (go 0 bs, close p))

   ; --- FAT, laid in memory --------------------------------------------------
   ; at its part's start and with a label in both boot sectors, as bootcode.bin reads them
   (fatimg at lab nsec files)
    (: im (cask (nsec * 512))
       dev [(lba \ k \ (cask (k * 512) @ b (pour b 0 im (lba * 512) (k * 512), string b)))
            (lba \ s \ (pour im (lba * 512) s 0 #s, #s // 512)) nsec (stamp * 1000)]
       _ (fat-mkfs dev || gone "fat-mkfs refused")
       f (fat-mount dev)
       _ (each files (x \ x @ [path b] (fat-write f path b || gone ("fat-write " + path))))
       nm (snip (lab + "           ") 0 11)
       _ (each [0 6] (k \ (pour im (k * 512 + 28) (le at 4) 0 4, pour im (k * 512 + 71) nm 0 11)))
       (string im))

   ; --- a root ---------------------------------------------------------------
   helm-conf """
     (service app (exec "/bin/love" "/app/run.l") (restart no))
     (oneshot gadget (exec "/bin/love" "/app/gadget.l"))
     (oneshot data (exec "/bin/love" "/app/data.l"))
     ; boot waits on data, so no part of the card is held while its table is read again
     (oneshot boot (after data) (exec "/bin/love" "/app/boot.l"))
     (oneshot swap (after data) (exec "/bin/love" "/app/swap.l"))
     (oneshot source (after data) (exec "/bin/love" "/app/source.l"))
     ; the console's own session, so a ^C on the port reaches what runs there; -w keeps one
     ; shell: helm starts a group leader, so setsid forks, and a parent gone is a restart
     (service console (after gadget)
       (exec "/bin/love" "sh" "-c" "exec /bin/love setsid -cw /bin/love sh < /dev/ttyGS0 > /dev/ttyGS0 2>&1")
       (restart always))
     (service wifi (after data)
       (exec "/bin/love" "-l" "/app/wifi/netlink.l" "-l" "/app/wifi/dhcp.l" "/app/wifi/wifi.l" "wlan0" "/etc/wifi.conf")
       (log "/data/wifi.log") (restart on-fail) (tries 5))
     (service sshd (after data)
       (exec "/bin/love" "sshd" "-o" "AuthorizedKeysFile=/etc/ssh/authorized_keys")
       (env "HOME" "/data/root") (log "/data/sshd.log") (restart always))
     (oneshot commit (after boot wifi sshd) (exec "/bin/love" "/app/commit.l"))
     (target default (wants app console wifi sshd swap source commit))
     """
   ; the otg port as a usb serial port: an acm function through configfs, bound to the one udc
   gadget-l """
     (borrow 'posix)
     (: g "/sys/kernel/config/usb_gadget/hearts"
        (put p s) (uwrite (g + "/" + p) s || say err ("gadget: can't write " + p + "\n"))
        udc (readdir "/sys/class/udc")
        (? !(two? udc) (say err "gadget: no udc\n", 1)
           (mount "configfs" "/sys/kernel/config" "configfs",
            each ["" "/strings/0x409" "/configs/c.1" "/configs/c.1/strings/0x409" "/functions/acm.gs0"]
                 (d \ umkdirs (g + d) 493),
            put "idVendor" "0x1d6b", put "idProduct" "0x0104",
            put "strings/0x409/manufacturer" "love", put "strings/0x409/product" "hearts",
            put "strings/0x409/serialnumber" "hearts-z2w",
            put "configs/c.1/strings/0x409/configuration" "acm",
            symlink (g + "/functions/acm.gs0") (g + "/configs/c.1/acm.gs0"),
            put "UDC" <udc,
            say err ("gadget: acm on " + <udc + "\n"), 0)))
     """
   ; data's ext4 on /data, read-write; on a refusal a tmpfs stands in, gone at each boot. a part
   ; short of the card grows to its last whole group (128 MiB): the MBR entry, checked against
   ; what the kernel read, then the table read again, then the ext4 online (equal is a no-op)
   data-l """
     (borrow '(posix bytes))
     (: (num p) (uread p @ [1 s] (read s) 0)
        (tell s) (say err ("data: " + s + "\n"))
        n    (num "/sys/block/mmcblk0/size")
        at   (num "/sys/block/mmcblk0/mmcblk0p2/start")
        had  (num "/sys/block/mmcblk0/mmcblk0p2/size")
        want ((n - at) // 262144 * 262144)
        mbr  (open "/dev/mmcblk0" "r" @ q (hot? q ? (see q @ c (unsee q c, chug q @ x (close q, x))) ""))
        ours (511 < #mbr && rdle mbr 510 2 = 43605 && mbr 466 = 131
              && rdle mbr 470 4 = at && rdle mbr 474 4 = had)
        _    (? !(0 < at && had < want) 0
                !ours (tell "p2 is not the entry the kernel read, left alone")
                (openfd "/dev/mmcblk0" 4 @ fd (!(charm? fd) ? (tell ("the card refused a write (" + show fd + ")"))
                   (lseek fd 474 0, (fdopen fd @ p (say p (wrle want 4), close p)), sync 0,
                    openfd "/dev/mmcblk0" 0 @ d
                      (ioctl d 4703 0 @ e (fdopen d @ p (close p),
                         tell ("p2 " + show had + " -> " + show want + " sectors"
                               + (nom? e ? (", the table held (" + show e + ") till a boot") ""))))))))
        r (mount "/dev/mmcblk0p2" "/data" "ext4")
        _ (nom? r ? (tell ("ext4 refused (" + show r + "), a tmpfs instead"), mount "tmpfs" "/data" "tmpfs")
             (openfd "/data/.grow" 1 @ fd
                ; EXT4_IOC_RESIZE_FS, in 4K blocks, to the part as the kernel now has it
                (ioctl fd 1074292240 (num "/sys/block/mmcblk0/mmcblk0p2/size" // 8) @ e
                   (fdopen fd @ p (close p), unlink "/data/.grow",
                    nom? e ? (tell ("the ext4 did not grow (" + show e + ")")) 0))))
        (umkdirs "/data/root/.ssh" 448, 0))
     """
   ; on data's ext4 alone: a tmpfs /data is RAM
   (on-disk body) ("""
     (borrow '(posix bytes))
     (: disk (uread "/proc/mounts" @ [1 s] (has? s "/dev/mmcblk0p2 /data ext4 ") 0)
        (!disk ? 0
     """ + "\n" + body + "))\n")
   ; a 1 GiB swap file: zeros written (no holes), then mkswap's header, so a torn lay has none
   ; and is laid again
   swap-l (on-disk """
     (: f "/data/swap"  n 1073741824
        pg (sysconf () @ (p . _) (charm? p ? p 4096) 4096)
        head (zbytes 1024 + wrle 1 4 + wrle (n // pg - 1) 4 + zbytes (pg - 1042) + "SWAPSPACE2")
        (lay _) (unlink f, openfd f 3 @ fd
                  (charm? fd ? (fdopen fd @ p (zbytes 1048576 @ z (each ^(n // 1048576) (_ \ say p z)), close p),
                                openfd f 4 @ h (fdopen h @ p (say p head, close p)), sync 0) 0))
        (on _) (swapon f @ e (nom? e ? e (say err ("swap: " + f + " on\n"), 0)))
        (nom? (on 0) ? (lay 0, (on 0 @ e (nom? e ? (say err ("swap: refused (" + show e + ")\n"), 1) 0))) 0))
     """)
   ; the carried source under /data/src, once a build: helm's own extract, in its own process
   source-l (on-disk """
     (exec ["/bin/helm" "extract" "/data/src"])
     """)
   ; the boot FAT on /boot, read-write: an update writes Image.new there
   boot-l """
     (borrow 'posix)
     (mount "/dev/mmcblk0p1" "/boot" "vfat" @ r (nom? r ? (say err ("boot: vfat refused (" + show r + ")\n"), 1) 0))
     """
   ; an update, once Image.new is on /boot (ssh root@BOARD 'cat > /boot/Image.new' < Image):
   ; the firmware runs it at the next boot only
   update-l """
     (borrow 'posix)
     (? !(two? (lstat "/boot/Image.new")) (say err "update: no /boot/Image.new\n", quit 1)
        (sync 0, say err "update: a trial of Image.new\n", reboot "0 tryboot"))
     """
   ; a trial kept: on the firmware's tryboot, and the running kernel's banner inside Image.new,
   ; the link up within 2 minutes renames Image.new over Image; down, a plain reboot runs Image
   commit-l """
     (borrow '(posix bytes))
     (: tb (uread "/sys/firmware/devicetree/base/chosen/bootloader/tryboot" @ [1 s] (rdbe s 0 4) 0)
        v (uread "/proc/version" @ [1 s] (snip s 0 (#s - 1)) "?")
        ; read a piece at a time: the board has no room for the whole Image beside helm
        (ours? _) (open "/boot/Image.new" "r" @ q
                    (hot? q ? (: (go t) (see q @ c (c < 0 ? 0 (unsee q c, t + chug q @ x
                                         (has? x v ? 1 (go (snip x (max 0 (#x - #v)) #x))))))
                                 r (go "")
                                 (close q, r))
                       0))
        (up? _) (uread "/sys/class/net/wlan0/operstate" @ [1 s] (snip s 0 2 = "up") 0)
        (wait k) (k = 0 ? 0 (up? 0 ? 1 (rest 1000, wait (k - 1))))
        (? !tb 0
           !(ours? 0) (say err "commit: the trial is not Image.new's kernel, nothing kept\n", 1)
           (wait 120) (rename "/boot/Image.new" "/boot/Image" @ r
                        (nom? r ? (say err ("commit: rename refused (" + show r + ")\n"), 1)
                           (sync 0, say err "commit: Image.new is Image\n", 0)))
           (say err "commit: no link on the trial, back to Image\n", sync 0, reboot 0)))
     """
   ; the app: /proc and /sys up, then the board by its device tree, on the console
   app-l """
     (borrow 'posix)
     (: (tell s) (say err ("hearts: " + s + "\n"))
        _ (mount "proc" "/proc" "proc", mount "sysfs" "/sys" "sysfs")
        model (uread "/sys/firmware/devicetree/base/model" @ r
                 (two? r ? (<>r @ s (0 < #s && s (#s - 1) = 0 ? (snip s 0 (#s - 1)) s)) "?"))
        (tell ("zero 2 w: " + model)))
     """
   (dir kids) ['dir 493 kids]
   (fil mode b) ['file mode b]
   (link t) ['link t]
   ; the station's three files, beside the tree's own
   app-wifi (map (f \ [f (fil 420 (rd ("src/apps/wifi/" + f)))]) ["dhcp.l" "netlink.l" "wifi.l"])
   (root love ver site)
    (dir [["app" (dir [["boot.l" (fil 420 boot-l)] ["commit.l" (fil 420 commit-l)] ["data.l" (fil 420 data-l)]
                       ["gadget.l" (fil 420 gadget-l)] ["run.l" (fil 420 app-l)] ["source.l" (fil 420 source-l)]
                       ["swap.l" (fil 420 swap-l)] ["update.l" (fil 420 update-l)]
                       ["wifi" (dir app-wifi)]])]
        ["bin" (dir [["helm" (fil 493 helm)] ["love" (fil 493 love)] ["sh" (link "love")]])]
        ["boot" (dir ())] ["data" (dir ())] ["dev" (dir [["console" ['chr 384 [5 1]]]])]
        ["etc" (dir (sort (site + [["helm.l" (fil 420 helm-conf)] ["version" (fil 420 (ver + "\n"))]
                                   ["passwd" (fil 420 "root:x:0:0:root:/data/root:/bin/sh\n")]
                                   ["resolv.conf" (link "/run/resolv.conf")]])))]
        ["lib" (dir (two? (readdir wifi) ? [["firmware" (sqfs-tree wifi)]] ()))]
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

   ; --- the boot files ---------------------------------------------------------
   ; the mini uart on gpio14/15 is serial1 in the mainline dtb; enable_uart pins the core
   ; clock it counts its baud from. gpu_mem stays the firmware's: 16 asks for start_cd.elf
   config ("""
     arm_64bit=1
     kernel=Image
     device_tree=bcm2837-rpi-zero-2-w.dtb
     start_file=start.elf
     fixup_file=fixup.dat
     enable_uart=1
     disable_splash=1
     [tryboot]
     kernel=Image.new
     """ + "\n")
   cmdline "console=ttyS1,115200 rdinit=/bin/helm panic=5\n"
   ; the zero 2 w's bootcode hands start.elf the tryboot flag only under tryboot_a_b: both
   ; modes name this one part, and config.txt's [tryboot] picks the file
   autoboot ("""
     [all]
     tryboot_a_b=1
     boot_partition=1
     [tryboot]
     boot_partition=1
     """ + "\n\n")

   verb (as 0)
   odir (as 1)
   (fw f) (rd (as 4 + "/" + f))
   ; root's words: OUT LOVE FW STAMP SITE; disk's: OUT IMAGE DTB FW STAMP
   sa (verb = "root" ? 4 5)
   stamp (#as > sa ? (read (as sa)) 0)
   wifi (as 3 + "/wifi")
   ; the root: what the kernel unpacks into its rootfs and runs /bin/helm from
   (mkroot _)
    (: love (rd (as 2))
       site (#as > 5 ? (sqfs-tree (as 5) @ ['dir _ ks] ks ()) ())
       (uwrite (odir + "/root.cpio") (cpio-pack (rev (walk "" (root love "v1" site) ()))),
        say err "hearts-zimage: root.cpio\n"))
   ; the disk: the boot FAT, room for Image.new beside Image, then data
   (mkdisk _)
    (: kernel (rd (as 2))
       dtb (rd (as 3))
       fsz (256 * mib)  dsz (64 * mib)
       _ (2 * #kernel + 16 * 1048576 < fsz * 512 || gone "the boot part holds no second Image")
       pa mib  pd (pa + fsz)
       boot (fatimg pa "BOOT" fsz [["autoboot.txt" autoboot] ["config.txt" config] ["cmdline.txt" cmdline]
                       ["bootcode.bin" (fw "bootcode.bin")] ["start.elf" (fw "start.elf")]
                       ["fixup.dat" (fw "fixup.dat")] ["LICENCE.broadcom" (fw "LICENCE.broadcom")]
                       ["Image" kernel] ["bcm2837-rpi-zero-2-w.dtb" dtb]])
       data (ext4-image (ext4-make (dsz // 8) (snip (hex2b (sha256 "hearts rung 2 data")) 0 16)
                                   (snip (hex2b (sha256 "hearts rung 2 data hash")) 0 16) stamp) (dsz // 8))
       total (pd + dsz)
       (disk (odir + "/disk.img") [[0 (mbr [(ent 0x80 0x0C pa fsz) (ent 0 0x83 pd dsz)])] [pa boot] [pd data]] total,
        say err "hearts-zimage: disk.img\n"))
   (? (verb = "root" && 2 < #as) (mkroot 0)
      (verb = "disk" && 4 < #as) (mkdisk 0)
      (gone "usage: zimage.l root OUT LOVE FW [STAMP [SITE]] | disk OUT IMAGE DTB FW [STAMP]")))
