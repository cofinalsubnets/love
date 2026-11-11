; src/apps/hearts/zimage.l -- rung 2's card: an MBR disk for the raspberry pi zero 2 w, its whole
; system one file. the root is a newc cpio built into the kernel (CONFIG_INITRAMFS_SOURCE), so
;   love .. zimage.l root OUT LOVE FW [STAMP [SITE]]   writes OUT/root.cpio, the kernel's input
;   love .. zimage.l disk OUT IMAGE DTB FW [STAMP]      writes OUT/disk.img from that kernel
; the disk: 1 boot (FAT32): the firmware, config.txt, cmdline.txt, Image, the dtb; 2 data (ext4).
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
     (oneshot boot (exec "/bin/love" "/app/boot.l"))
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
     (target default (wants app console wifi sshd commit))
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
   ; data's ext4 on /data, read-write; on a refusal a tmpfs stands in, gone at each boot
   data-l """
     (borrow 'posix)
     (: r (mount "/dev/mmcblk0p2" "/data" "ext4")
        _ (nom? r ? (say err ("data: ext4 refused (" + show r + "), a tmpfs instead\n"), mount "tmpfs" "/data" "tmpfs") 0)
        (umkdirs "/data/root/.ssh" 448, 0))
     """
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
   ; a trial kept: on the firmware's tryboot, the link up within 2 minutes renames Image.new
   ; over Image; down, a plain reboot runs Image again
   commit-l """
     (borrow '(posix bytes))
     (: tb (uread "/sys/firmware/devicetree/base/chosen/bootloader/tryboot" @ [1 s] (rdbe s 0 4) 0)
        (up? _) (uread "/sys/class/net/wlan0/operstate" @ [1 s] (snip s 0 2 = "up") 0)
        (wait k) (k = 0 ? 0 (up? 0 ? 1 (rest 1000, wait (k - 1))))
        (? !tb 0
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
                       ["gadget.l" (fil 420 gadget-l)] ["run.l" (fil 420 app-l)] ["update.l" (fil 420 update-l)]
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
       boot (fatimg pa "BOOT" fsz [["config.txt" config] ["cmdline.txt" cmdline]
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
