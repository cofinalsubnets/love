; src/apps/hearts/zimage.l -- rung 2's image: an MBR disk for the raspberry pi zero 2 w. the disk:
;   1 autoboot (FAT32): autoboot.txt (tryboot_a_b, boot a), bootcode.bin, an empty config.txt
;   2 boot a (FAT32): the firmware, config.txt, cmdline.txt, Image, the dtb; 3 boot b, empty
;   4 extended: 5 root a, 6 root b (squashfs; b empty), 7 data (ext4), each behind its EBR
; a root: love as /bin/love, helm's script as init (/bin/helm), and an app that says the board.
; the parts lie on MiB bounds, each `at` where the one before it ends.
; usage: love -l src/apps/sqfs.l -l src/apps/ext4.l zimage.l OUT LOVE IMAGE DTB FW [STAMP]
;   writes OUT/disk.img; LOVE is a baked a64 love, IMAGE the kernel, DTB the board's, FW the
;   firmware's directory (bootcode.bin start.elf fixup.dat LICENCE.broadcom), STAMP the one time
;   every file carries (seconds, default 0): the same inputs give the same bytes on any host.
(borrow '(bytes posix fat sqfs ext4 hashes))
(: ; its words are the ones after its own name, whatever loaded ahead of it
   (after l) (atom? l ? () (<l @ (_ + "zimage.l") >l (after >l)))
   as (after cmdline)
   (gone s) (say err ("hearts-zimage: " + s + "\n"), quit 1)
   (rd f) (uread f @ r (two? r ? <>r (gone ("cannot read " + f))))
   (le v n) (wrle v n)
   mib 2048                                          ; sectors

   ; --- MBR, and an EBR per logical part ---------------------------------------
   ; an entry in LBA alone: its CHS fields say past the limit, as any disk this size must
   (ent act ty at n) (n = 0 ? (zbytes 16)
                    (string act + string 0xFE + string 0xFF + string 0xFF + string ty
                     + string 0xFE + string 0xFF + string 0xFF + le at 4 + le n 4))
   (sect lead es) (lead + join "" es + zbytes (64 - 16 * #es) + string 0x55 + string 0xAA)
   sig (snip (hex2b (sha256 "hearts rung 2 disk")) 0 4)   ; the same signature every build
   ; a part by the signature, as the kernel names MBR parts: no mmcblk number to guess
   (puuid n) ("PARTUUID=" + b2hex (string (rev (chars sig))) + "-" + zpad 2 (show n))
   (mbr ps) (sect (zbytes 440 + sig + zbytes 2) ps)
   ; an EBR at e: its part from e, and the next EBR from the extended part's start x
   (ebr e at n nx nn x) (sect (zbytes 446) [(ent 0 0x83 (at - e) n) (ent 0 0x05 (nx - x) nn)])

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
     (target default (wants app))
     """
   ; the app: /proc and /sys up, then the board by its device tree, on the console
   app-l """
     (borrow 'posix)
     (: (tell s) (say err ("hearts: " + s + "\n"))
        _ (mount "proc" "/proc" "proc", mount "sysfs" "/sys" "sysfs")
        model (uread "/sys/firmware/devicetree/base/model" @ r
                 (two? r ? (<>r @ s (0 < #s && s (#s - 1) = 0 ? (snip s 0 (#s - 1)) s)) "?"))
        (tell ("zero 2 w, slot a: " + model)))
     """
   (dir kids) ['dir 493 kids]
   (fil mode b) ['file mode b]
   (root love ver)
    (dir [["app" (dir [["run.l" (fil 420 app-l)]])]
        ["bin" (dir [["helm" (fil 493 helm)] ["love" (fil 493 love)]])]
        ["boot" (dir ())] ["data" (dir ())] ["dev" (dir ())]
        ["etc" (dir [["helm.l" (fil 420 helm-conf)] ["version" (fil 420 (ver + "\n"))]])]
        ["proc" (dir ())] ["run" (dir ())] ["sys" (dir ())] ["tmp" (dir ())]
        ["usr" (dir [["bin" (dir ())] ["src" (dir ())]])]])
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
     """ + "\n")
   (cmd root) ("console=ttyS1,115200 root=" + root + " rootfstype=squashfs ro rootwait panic=5 init=/bin/helm\n")
   autoboot ("""
     [all]
     tryboot_a_b=1
     boot_partition=2
     [tryboot]
     boot_partition=3
     """ + "\n\n")

   odir (as 0)
   love (rd (as 1))
   kernel (rd (as 2))
   dtb (rd (as 3))
   (fw f) (rd (as 4 + "/" + f))
   stamp (#as > 5 ? (read (as 5)) 0)
   r1 (sqfs-make (root love "v1") stamp 'zlib)
   rsz (32 * mib)
   _ (#r1 <= rsz * 512 || gone "a root outgrows its slot")
   asz (64 * mib)  fsz (128 * mib)  dsz (64 * mib)
   ; the parts back to back from 1 MiB, each EBR a MiB ahead of its logical part
   pa mib  pb (pa + asz)  pc (pb + fsz)  x (pc + fsz)
   auto (fatimg pa "AUTOBOOT" asz [["autoboot.txt" autoboot] ["bootcode.bin" (fw "bootcode.bin")] ["config.txt" ""]])
   boota (fatimg pb "BOOT-A" fsz [["config.txt" config] ["cmdline.txt" (cmd (puuid 5))]
                      ["start.elf" (fw "start.elf")] ["fixup.dat" (fw "fixup.dat")]
                      ["LICENCE.broadcom" (fw "LICENCE.broadcom")]
                      ["Image" kernel] ["bcm2837-rpi-zero-2-w.dtb" dtb]])
   bootb (fatimg pc "BOOT-B" fsz ())
   data (ext4-image (ext4-make (dsz // 8) (snip (hex2b (sha256 "hearts rung 2 data")) 0 16)
                               (snip (hex2b (sha256 "hearts rung 2 data hash")) 0 16) stamp) (dsz // 8))
   e1 x  ra (e1 + mib)  e2 (ra + rsz)  rb (e2 + mib)  e3 (rb + rsz)  da (e3 + mib)
   total (da + dsz)
   bs [[0 (mbr [(ent 0x80 0x0C pa asz) (ent 0x80 0x0C pb fsz) (ent 0x80 0x0C pc fsz) (ent 0 0x0F x (total - x))])]
       [pa auto] [pb boota] [pc bootb]
       [e1 (ebr e1 ra rsz e2 (rb + rsz - e2) x)] [ra r1]
       [e2 (ebr e2 rb rsz e3 (total - e3) x)]
       [e3 (ebr e3 da dsz x 0 x)] [da data]]
   (disk (odir + "/disk.img") bs total,
    say err "hearts-zimage: disk.img\n"))
