; test/host/zimage.l -- the zero 2 w's card, laid by src/apps/hearts/zimage.l from stand-in parts
; and read back by love's own fat and cpio: the root's tree and its console node, the MBR's two
; parts, the boot FAT's files and its trial line, the data part by its magic, the same bytes twice
;   cat test/00-init.l test/host/00-host.l test/host/zimage.l | out/love
(borrow "src/apps/fat.l")
(borrow "src/apps/tar.l")
(borrow "src/apps/cpio.l")
(borrow '(posix bytes hashes cpio))
(: love <cmdline
   d "out/zimage-law"
   _ (hark ["rm" "-rf" d], mkdir d 493, mkdir (d + "/fw") 493)
   (put f s) (: p (open (d + "/" + f) "w") (say p s, close p))
   fws ["LICENCE.broadcom" "bootcode.bin" "fixup.dat" "start.elf"]
   _ (put "love" "a love", put "Image" "a kernel", put "dtb" "a tree",
      each fws (f \ put ("fw/" + f) ("the " + f)))
   (z ws) <(hark ([love "-l" "src/apps/tar.l" "-l" "src/apps/cpio.l" "-l" "src/apps/sqfs.l" "-l" "src/apps/ext4.l"
                   "src/apps/hearts/zimage.l"] + ws))
   (mk o) (mkdir (d + "/" + o) 493,
           z ["root" (d + "/" + o) (d + "/love") (d + "/fw")]
           + z ["disk" (d + "/" + o) (d + "/Image") (d + "/dtb") (d + "/fw")])
   (same f) (0 = <(hark ["cmp" "-s" (d + "/a/" + f) (d + "/b/" + f)]))
   _ (test (0 = mk "a") (0 = mk "b") (same "root.cpio") (same "disk.img")
           (0 != z ["disk" (d + "/a")]))
   ; a site's choices beside the firmware: a node a real fdt keeps from its driver, in place
   ; (a root, the node, its status, its strings), config lines, a cmdline of its own
   (w v) (wrbe v 4)
   dt (w 0xd00dfeed + w 108 + w 40 + w 100 + w 0 + w 17 + w 16 + w 0 + w 8 + w 60
       + w 1 + w 0 + w 1 + "uart@7e201000" + string [0 0 0]
       + w 3 + w 5 + w 0 + "okay" + string [0 0 0 0] + w 2 + w 2 + w 9 + "status" + string [0 0])
   _ (put "fdt" dt, mkdir (d + "/f") 493, mkdir (d + "/fs") 493,
      each fws (f \ put ("fs/" + f) ("the " + f)),
      put "fs/dtb-off" "uart@7e201000\n", put "fs/config.add" "dtparam=x=on", put "fs/cmdline.txt" "console=tty1\n")
   _ (test (0 = z ["disk" (d + "/f") (d + "/Image") (d + "/fdt") (d + "/fs")]))

   ; the root: helm as init, love as the shell, and the console the kernel opens before either
   es (cpio-unpack <>(uread (d + "/a/root.cpio")) @ [1 es] es ())
   (at1 n) (foldl (a \ e \ peep e 'nom "" = n ? e a) () es)
   _ (test (es != ())
           ("a love" = peep (at1 "bin/love") 'body "") (493 = peep (at1 "bin/love") 'mode 0)
           ('link = peep (at1 "bin/sh") 'kind 0) ("love" = peep (at1 "bin/sh") 'to "")
           (has? (peep (at1 "bin/helm") 'body "") "#!/bin/love\n")
           ('chr = peep (at1 "dev/console") 'kind 0) ([5 1] = peep (at1 "dev/console") 'rdev ())
           (has? (peep (at1 "etc/helm.l") 'body "") "(oneshot commit (after boot wifi sshd)")
           (has? (peep (at1 "app/commit.l") 'body "") "(has? x v ? 1")
           (has? (peep (at1 "app/data.l") 'body "") "/dev/mmcblk0p2")
           ; a name only a site gives; the kernel takes it at boot, ahead of the dhcp that sends it
           (() = at1 "etc/hostname")
           (has? (peep (at1 "app/host.l") 'body "") "/proc/sys/kernel/hostname")
           (has? (peep (at1 "etc/helm.l") 'body "") "(service wifi (after data host)")
           ; each directory ahead of what it holds
           (all (e \ (: n (peep e 'nom "") k (foldl (a \ i \ n i = 47 ? i a) -1 ^#n)
                      (k < 0 || foldl (a \ x \ a || peep x 'nom "" = snip n 0 k) 0 es)))
                es))

   ; a trial names its file in config.txt's [tryboot] line, the rest as it was; a missing file
   ; or a config with no such line leaves it alone. run on a stand-in /boot, reboot a no-op
   tb (d + "/tb")
   (trial f cf has) (: _ (hark ["rm" "-rf" tb], mkdir tb 493, mkdir (tb + "/boot") 493,
                         each has (h \ put ("tb/boot/" + h) "a kernel"), put "tb/boot/config.txt" cf,
                         put "tb/t.l" (replace (replace (peep (at1 ("app/" + f)) 'body "") "/boot/" (tb + "/boot/"))
                                               "reboot \"0 tryboot\"" "0"))
                     r <(hark [love (tb + "/t.l")])
                   [r <>(uread (tb + "/boot/config.txt"))])
   cf0 "kernel=Image\n[tryboot]\nkernel=Image.new\n"
   _ (test ([0 "kernel=Image\n[tryboot]\nkernel=inle.img\n"] = trial "inle.l" cf0 ["inle.img"])
           ([0 cf0] = trial "update.l" "kernel=Image\n[tryboot]\nkernel=inle.img\n" ["Image.new"])
           ([1 cf0] = trial "inle.l" cf0 ())
           ([1 "kernel=Image\n"] = trial "inle.l" "kernel=Image\n" ["inle.img"]))

   im <>(uread (d + "/a/disk.img"))
   (at s o n) (rdle im (s * 512 + o) n)
   ; the MBR: the boot FAT, active, from 1 MiB, and data behind it
   (ent s k) [(im (s * 512 + 446 + 16 * k)) (im (s * 512 + 450 + 16 * k))
              (at s (454 + 16 * k) 4) (at s (458 + 16 * k) 4)]
   _ (test (#im = 657408 * 512) (im 510 = 0x55) (im 511 = 0xAA)
           ([[0x80 0x0C 2048 524288] [0 0x83 526336 131072] [0 0 0 0] [0 0 0 0]] = map (ent 0) ^4))

   ; the boot FAT read in place, its boot sector naming its own start and label
   b (fat-mount [(lba \ k \ snip im ((2048 + lba) * 512) ((2048 + lba + k) * 512)) (lba \ b \ ()) 524288])
   (rd p) <>(fat-read b p)
   cf (rd "config.txt")
   _ (test (["Image" "LICENCE.broadcom" "autoboot.txt" "bcm2837-rpi-zero-2-w.dtb" "bootcode.bin" "cmdline.txt"
             "config.txt" "fixup.dat" "start.elf"] = sort <>(fat-ls b ""))
           ("[all]\ntryboot_a_b=1\nboot_partition=1\n[tryboot]\nboot_partition=1\n\n" = rd "autoboot.txt")
           (all (f \ rd f = "the " + f) fws)
           ("a kernel" = rd "Image") ("a tree" = rd "bcm2837-rpi-zero-2-w.dtb")
           (2048 = at 2048 28 4) ("BOOT       " = snip im (2048 * 512 + 71) (2048 * 512 + 82))
           (has? cf "kernel=Image\n") (has? cf "[tryboot]\nkernel=Image.new\n")
           (has? cf "enable_uart=1\n") (has? cf "device_tree=bcm2837-rpi-zero-2-w.dtb\n")
           (has? cf "disable_splash=1\n[tryboot]\nkernel=Image.new\n")
           ("a tree" = rd "bcm2837-rpi-zero-2-w.dtb")
           ("console=ttyS1,115200 rdinit=/bin/helm panic=5\n" = rd "cmdline.txt"))
   _ (test (0xEF53 = at 526336 1080 2))
   fim <>(uread (d + "/f/disk.img"))
   fb (fat-mount [(lba \ k \ snip fim ((2048 + lba) * 512) ((2048 + lba + k) * 512)) (lba \ b \ ()) 524288])
   (frd p) <>(fat-read fb p)
   fd (frd "bcm2837-rpi-zero-2-w.dtb")
   _ (test (#fd = #dt) (snip fd 0 80 = snip dt 0 80) ("fail" = snip fd 80 84) (snip fd 84 #fd = snip dt 84 #dt)
           (has? (frd "config.txt") "disable_splash=1\ndtparam=x=on\n[tryboot]\nkernel=Image.new\n")
           ("console=tty1\n" = frd "cmdline.txt"))
   (hark ["rm" "-rf" d], 0))
(test_fin (), puts "zimage: ok", putc 10, 0)
