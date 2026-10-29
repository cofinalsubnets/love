; driver for the kernel boot gates: boot the shipped kernel under qemu with the corpus
; on its command line, capture the serial console ("N tests pass", then isa-debug-exit
; or the reset quits qemu), and report. runs on the host love (`hark`).
; argv = (this file firmware arch [need]). a .elf boots direct (PVH, `-kernel`; firmware
; "-"); a directory is an esp served as a FAT volume, firmware as pflash. nothing else.

(borrow 'posix)
(: (sub-at s i t j) (j >= #t ? 1
       (s (i + j) = t j ? (sub-at s i t (j + 1)) 0))
   (bol s i)  (? (i < 1) 0 (10 = peep s (i - 1) 0) i (bol s (i - 1)))
   (eol s i)  (? (i >= #s) i (10 = peep s i 0) i (eol s (i + 1)))
   (lineof s t) (findsub s t @ i (i < 0 ? "" (snip s (bol s i) (eol s i)))))

(: a    >argv
   iso  <a
   ovmf <>a
   arch (>>a @ x (two? x ? <x "x64"))                    ; x64 by default
   ; a line the output must also contain (test_disk's second boot)
   need (>>>a @ x (two? x ? <x ""))
   ; a .elf: qemu's loader reads the PVH note and enters mkboot.l's stub
   elf? (#iso @ n (n > 4 && sub-at iso (n - 4) ".elf" 0))
   ; a directory is an esp: qemu fakes a FAT volume, the firmware runs our bootx64.efi.
   ; s_ifdir 0040000 under the 0170000 mask
   dir? (: st (stat iso)                          ; (size mtime mode ..)
           m (two? st ? (st 2) 0)
           (16384 = m & 61440))
   ; x64 quits through isa-debug-exit; the virts reset through PSCI/SBI and -no-reboot
   ; makes that the exit. an elf lane boots under kvm on a bee host with the lane's cap
   ; (kvm-a64 for a64, or KTEST_CAP); a slot is the host's lock, so lanes never crowd a
   ; box past its memory. no host: it boots here
   (env-of k) (getenv k @ v (string? v && 0 < #v ? v ()))
   cap  (env-of "KTEST_CAP" @ c (string? c ? c (arch = "a64" ? "kvm-a64" ())))
   hosts (? (elf? && string? cap) ((cite 'hosts 'hosts-live) ((cite 'hosts 'hosts-with) cap ())) ())
   slot (two? hosts ? ((cite 'hosts 'hosts-take) hosts (getpid 0) ("ktest " + iso)) ())
   far  (two? slot)
   mach (arch @ "a64"
           ["-M" "virt,gic-version=2" "-cpu" (far ? "host" "cortex-a72") "-semihosting"]
           "rv64"
           ["-M" "virt"]
           ["-M" "q35" "-device" "isa-debug-exit,iobase=0xf4,iosize=0x04"
            ; the sound card, silent: test/horn.l drives hda.c against it
            "-device" "intel-hda" "-device" "hda-output,audiodev=snd" "-audiodev" "none,id=snd"])
   ; the two virts carry their disk on virtio-mmio; q35 on pci
   mmio? (arch = "a64" || arch = "rv64")
   ; 1536M: a major collection allocates a new contiguous 2x pool pair while the old
   ; one stands, so it needs a hole the old pair fragments; whether one fits shifts with
   ; any image-size change, hence the wide margin. a green run is ~3min under tcg.
   fw   ["-drive" ("if=pflash,unit=0,format=raw,file=" + ovmf + ",readonly=on")]
   ; uefi door: ovmf parks 64-bit bars above 4G, past the kernel's map, and the disk is
   ; skipped; this turns ovmf's 64-bit mmio window off so the disk laws run here too.
   below4g ["-fw_cfg" "opt/ovmf/X-PciMmio64Mb,string=0"]
   ; only the esp door gets a framebuffer. ramfb, not virtio-gpu: edk2's gop over that
   ; answers a mode with no address. ramfb's lands in ordinary ram.
   gfx  (arch = "a64" ? ["-device" "ramfb"] ())
   ; KTEST_CORPUS: a lane's own roster; KTEST_INITRD: a file the kernel shows at /proc/initrd
   media (? elf? (["-kernel" iso "-append" (env-of "KTEST_CORPUS" @ c (string? c ? c "test/kernel/all.l"))]
                  + (env-of "KTEST_INITRD" @ f (string? f ? ["-initrd" f] ())))
            dir? (fw + below4g + gfx + ["-drive" ("format=raw,file=fat:rw:" + iso)])
            (scare 'ktest-media iso))
   ; kvm where the host backs it (~7x); x64-on-x64 only, since an arm host whose gic
   ; cannot back v2 refuses. without /dev/kvm it is tcg; the verdict never rides on this.
   mach? (hark ["uname" "-m"])
   kvm  (? far (arch = "x64" ? ["-enable-kvm" "-cpu" "host"] ["-enable-kvm"])   ; -cpu host hands the guest VT-x
           (two? (stat "/dev/kvm") && arch = "x64" && has? >mach? "x86_64") ["-enable-kvm" "-cpu" "host"]
           ())
   ; tcg on a shared box runs ~300s quiet, past 420s loaded; rv64 tcg nears 900s loaded
   ceil (two? kvm ? "420" (arch = "rv64" ? "1200" "900"))
   ; the scratch disk: truncate leaves an existing image's bytes alone, so the
   ; persistence gate's two boots share it (test/kernel/disk.l). force-legacy=false
   ; makes virtio-mmio speak version 2, the one blk.c drives.
   disk (iso + ".disk")
   _    (hark ["truncate" "-s" "35840000" disk])
   dargs (["-drive" ("file=" + disk + ",if=none,format=raw,id=d0")] @ d
            (mmio? ?
               (d + ["-device" "virtio-blk-device,drive=d0"
                     "-global" "virtio-mmio.force-legacy=false"])
               (d + ["-device" "virtio-blk-pci,drive=d0"])))
   qemu (["timeout" ceil ("qemu-system-" + arch-mach (intern arch)) "-m" "1536M"]
         + mach + kvm + dargs
         + ["-serial" "stdio" "-display" "none" "-no-reboot"] + media)
   ; far: the elf goes over in a dir of its own, the disk made beside it, paths as
   ; basenames, and the dir removed after
   r    (far ?
           (: d ("/tmp/ktest-" + show (getpid 0))
              b (foldl (\ a i (iso i = 47 ? (i + 1) a)) 0 (jot #iso) @ k (snip iso k #iso))
              rel (map (x \ (? (x = iso) b
                                (sub-at x 0 "file=" 0) ("file=" + b + ".disk" + snip x (5 + #disk) #x)
                                x))
                       qemu)
              _ (hark ["mkdir" "-p" d]) _ (hark ["cp" iso (d + "/" + b)])
              x (hark ["sh" "-c" ((cite 'hosts 'hosts-line) <slot d
                                    ["sh" "-c" ("truncate -s 35840000 " + b + ".disk && exec"
                                                + foldl (\ a w (a + " '" + w + "'")) "" rel)])])
              _ (hark ["rm" "-rf" d])
              x)
           (hark qemu))
   _    (far ? ((cite 'hosts 'hosts-free) slot (getpid 0)) 0)
   out  >r
   line (lineof out "tests pass")
   ; "0 tests pass" is a corpus that died before its first assert
   ok   (has? out "tests pass" && !(has? out "failed:")
         && !(sub-at line 0 "0 tests pass" 0)
         && (#need ? (has? out need) 1))
   (ok ? (puts line, putc 10)
         (say err "ktest: FAILED", put err 10,
          say err out, put err 10, quit 1)))
