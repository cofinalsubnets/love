; test/host/zimage.l -- the zero 2 w's card, laid by src/apps/hearts/zimage.l from stand-in parts
; and read back by love's own fat: the MBR and its EBR chain, each FAT's files and boot sector,
; root a by its PARTUUID, the roots and the data part by their magic, and the same bytes twice
;   cat test/00-init.l test/host/00-host.l test/host/zimage.l | out/love
(borrow "src/apps/fat.l")
(borrow '(posix bytes hashes))
(: love <cmdline
   d "out/zimage-law"
   _ (hark ["rm" "-rf" d], mkdir d 493, mkdir (d + "/fw") 493)
   (put f s) (: p (open (d + "/" + f) "w") (say p s, close p))
   fws ["LICENCE.broadcom" "bootcode.bin" "fixup.dat" "start.elf"]
   _ (put "love" "a love", put "Image" "a kernel", put "dtb" "a tree",
      each fws (f \ put ("fw/" + f) ("the " + f)))
   (mk o) (mkdir (d + "/" + o) 493,
           <(hark [love "-l" "src/apps/sqfs.l" "-l" "src/apps/ext4.l" "src/apps/hearts/zimage.l"
                   (d + "/" + o) (d + "/love") (d + "/Image") (d + "/dtb") (d + "/fw")]))
   _ (test (0 = mk "a") (0 = mk "b")
           (0 = <(hark ["cmp" "-s" (d + "/a/disk.img") (d + "/b/disk.img")])))
   im <>(uread (d + "/a/disk.img"))
   (at s o n) (rdle im (s * 512 + o) n)

   ; the MBR: three active FATs and the extended part, back to back from 1 MiB
   (ent s k) [(im (s * 512 + 446 + 16 * k)) (im (s * 512 + 450 + 16 * k))
              (at s (454 + 16 * k) 4) (at s (458 + 16 * k) 4)]
   _ (test (#im = 925696 * 512) (im 510 = 0x55) (im 511 = 0xAA)
           ([[0x80 0x0C 2048 131072] [0x80 0x0C 133120 262144] [0x80 0x0C 395264 262144]
             [0 0x0F 657408 268288]] = map (ent 0) ^4))
   ; the logical parts down the EBR chain, each start the extended part's plus its EBR's
   (chain e) (ent e 0 @ [_ ty s n] (ent e 1 @ [_ _ nx _]
               ([(e + s) n ty] . (nx = 0 ? () (chain (657408 + nx))))))
   _ (test ([[659456 65536 0x83] [727040 65536 0x83] [794624 131072 0x83]] = chain 657408))

   ; a FAT read in place, its boot sector naming its own start and label
   (fs s n) (fat-mount [(lba \ k \ snip im ((s + lba) * 512) ((s + lba + k) * 512)) (lba \ b \ ()) n])
   (rd f p) <>(fat-read f p)
   (lab s) (snip im (s * 512 + 71) (s * 512 + 82))
   a (fs 2048 131072)  ba (fs 133120 262144)  bb (fs 395264 262144)
   _ (test (["autoboot.txt" "bootcode.bin" "config.txt"] = sort <>(fat-ls a ""))
           ("" = rd a "config.txt") ("the bootcode.bin" = rd a "bootcode.bin")
           ("[all]\ntryboot_a_b=1\nboot_partition=2\n[tryboot]\nboot_partition=3\n\n" = rd a "autoboot.txt")
           (() = <>(fat-ls bb ""))
           ([2048 133120 395264] = map (s \ at s 28 4) [2048 133120 395264])
           (["AUTOBOOT   " "BOOT-A     " "BOOT-B     "] = map lab [2048 133120 395264]))
   ; boot a: the firmware, the kernel and its tree as given, and nothing that logs a stage
   cf (rd ba "config.txt")
   cl (rd ba "cmdline.txt")
   puuid (b2hex (string (rev (map (k \ im (440 + k)) ^4))))
   _ (test (["Image" "LICENCE.broadcom" "bcm2837-rpi-zero-2-w.dtb" "cmdline.txt" "config.txt"
             "fixup.dat" "start.elf"] = sort <>(fat-ls ba ""))
           (all (f \ rd ba f = "the " + f) ["LICENCE.broadcom" "fixup.dat" "start.elf"])
           ("a kernel" = rd ba "Image") ("a tree" = rd ba "bcm2837-rpi-zero-2-w.dtb")
           (has? cf "enable_uart=1\n") (has? cf "device_tree=bcm2837-rpi-zero-2-w.dtb\n")
           !(has? cf "uart_2ndstage") !(has? cl "earlycon")
           (has? cl ("console=ttyS1,115200 root=PARTUUID=" + puuid + "-05 rootfstype=squashfs ro ")))
   ; root a a squashfs, root b empty, the data part ext4
   _ (test ("hsqs" = snip im (659456 * 512) (659456 * 512 + 4))
           ((zbytes 4) = snip im (727040 * 512) (727040 * 512 + 4))
           (0xEF53 = at 794624 1080 2))
   (hark ["rm" "-rf" d], 0))
(test_fin (), puts "zimage: ok", putc 10, 0)
