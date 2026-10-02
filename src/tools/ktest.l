; Driver for the kernel boot gates: boot the shipped kernel under qemu with the
; corpus named on its command line, capture the serial console (test/kernel/all.l
; prints the usual "N tests pass" summary, then (exit) quits qemu via
; isa-debug-exit), and report. There is no test kernel -- the elf door passes
; -append, and the esp door has love.cmd beside love.elf, firmware carrying no
; command line of its own.
; Run on the host love, which has the `hark` subprocess nif.
; argv = (this file firmware arch), and the file picks the door: a .elf boots
; direct (`qemu -kernel`, the PVH door -- no bootloader, no firmware image at
; all, so pass "-" for the firmware); a directory is an esp served as a FAT
; volume (the uefi door -- our own BOOTX64.EFI + love.elf), and takes the
; firmware as pflash. there is no third door, so anything else is a refusal.

(borrow 'posix)
(: (sub-at s i t j) (j >= #t ? 1                           ; does t occur in s at index i?
       (s (i + j) = t j ? (sub-at s i t (j + 1)) 0))
   (bol s i)  (? (i < 1) 0 (10 = peep s (i - 1) 0) i (bol s (i - 1)))
   (eol s i)  (? (i >= #s) i (10 = peep s i 0) i (eol s (i + 1)))
   (lineof s t) (findsub s t @ i (i < 0 ? "" (snip s (bol s i) (eol s i)))))

(: a    >argv
   iso  <a
   ovmf <>a
   arch (>>a @ x (two? x ? <x "x64"))                    ; optional 3rd arg; x64 by default
   ; optional 4th arg: a line the serial output must also contain -- test_disk's
   ; second boot demands "disk: fat kept across the reset" on top of the summary.
   need (>>>a @ x (two? x ? <x ""))
   ; a .elf boots direct: qemu's own loader reads the PVH note and enters our
   ; bring-up stub (mkboot.l) -- nothing downloaded, nothing vendored.
   elf? (#iso @ n (n > 4 && sub-at iso (n - 4) ".elf" 0))
   ; a directory is an esp: qemu fakes a FAT volume over it and the firmware
   ; runs efi/boot/bootx64.efi -- ours, the uefi door. (stat's mode is at 2;
   ; s_ifdir is 0040000 under the 0170000 type mask.)
   dir? (: st (stat iso)                          ; (size mtime mode ..) -- `at` is not bound here
           m (two? st ? (st 2) 0)
           (16384 = m & 61440))
   ; machine + exit channel are per-arch. x64 quits qemu by writing the
   ; isa-debug-exit port; the two 'virt's have no such device, so k_reset goes
   ; out through PSCI / SBI and -no-reboot below turns that into the exit.
   ; KTEST_<ARCH>_HOSTS lists boxes (ssh, qemu, /dev/kvm) an elf lane boots on under kvm instead
   ; of here: a64's are arm boxes, ~100s against tcg; x64's a VT-x box for the vmx laws, which
   ; test_kernel_vmx fills from KTEST_VMX_HOSTS. "host:slots ..", fastest first; KTEST_<ARCH>_HOST
   ; is one host, one slot. a slot is an exclusive lock, ARCHhost-HOST-N, so two lanes never crowd
   ; one box past what its memory holds; with every slot taken the lane waits
   (env-of k) (getenv k @ v (string? v && 0 < #v ? v ()))
   (num s) (foldl (\ a i (a * 10 + s i - 48)) 0 ^#s)
   pfx (arch @ "a64" "KTEST_A64_" "x64" "KTEST_X64_" ())
   hosts (? !(elf? && string? pfx) ()
            (env-of (pfx + "HOSTS") @ l
               (? (string? l) (map (w \ (cite 'kore 'usplit 58 w @ p [<p (two? >p ? (num <>p) 1)]))
                         (filter (w \ 0 < #w) (cite 'kore 'usplit 32 l)))
                  (env-of (pfx + "HOST") @ h (string? h ? [[h 1]] ())))))
   lroot ((cite 'locks 'locks-root) 0)
   (try-slot h i) (: nm (arch + "host-" + <h + "-" + show i)
                     g ((cite 'locks 'locks-acquire) lroot nm 'exclusive (getpid 0) ("ktest " + iso) () 1)
                     (peep g "granted" 0 ? [<h nm] ()))
   (try-host h) (foldl (\ a i (two? a ? a (try-slot h i))) () (map (+ 1) (jot (h 1))))
   (take-slot n) (: s (foldl (\ a h (two? a ? a (try-host h))) () hosts)
                    (? (two? s) s
                       (: _ (? (n = 0) (say err ("ktest: every " + arch + " host slot is taken; waiting\n")) 0)
                          _ (rest 5000)
                          (take-slot (n + 1)))))
   slot (two? hosts ? (take-slot 0) ())
   far  (two? slot ? <slot ())
   mach (arch @ "a64"
           ["-M" "virt,gic-version=2" "-cpu" (far ? "host" "cortex-a72") "-semihosting"]
           "rv64"
           ["-M" "virt"]
           ["-M" "q35" "-device" "isa-debug-exit,iobase=0xf4,iosize=0x04"
            ; the sound card, silent: test/horn.l drives src/inle/hda.c against it
            "-device" "intel-hda" "-device" "hda-output,audiodev=snd" "-audiodev" "none,id=snd"])
   ; the two virts carry their disk on virtio-mmio; q35 on pci
   mmio? (arch = "a64" || arch = "rv64")
   ; 1536M. the corpus outgrew 256M (a silent death mid-corpus), then
   ; 512M and then 768M (";; oom@len=N" at a deterministic dot) -- all the same
   ; wall: a major collection grows the pool by allocating a new contiguous 2x
   ; pair while the old pair still stands, so the ask (~78M at today's corpus)
   ; must fit a hole in ram the old pair fragments -- and whether one fits is a
   ; placement lottery any image-size change re-rolls. 768M lost it to a link
   ; change that moved the image by a few KB. the margin here is the mitigation
   ; and the reason it is doubled rather than nudged past the last loss; the cure
   ; would be a pool pair in two blocks. the room also buys time -- fewer
   ; collections, ~28s of corpus against 44s. a full green run is ~3min wall
   ; under tcg (the kernel's own summary clock -- don't trust it for the timeout).
   fw   ["-drive" ("if=pflash,unit=0,format=raw,file=" + ovmf + ",readonly=on")]
   ; the uefi door only: ovmf parks 64-bit bars above 4G, past every door's
   ; 0..4G map, and the driver then skips the disk (its honest fallback). this
   ; knob turns ovmf's 64-bit mmio window off, so the bar lands reachable and
   ; the disk laws run on this door too.
   below4g ["-fw_cfg" "opt/ovmf/X-PciMmio64Mb,string=0"]
   ; the esp door is the only one handed a framebuffer, and on `virt` nothing
   ; offers one unasked. ramfb, not virtio-gpu: edk2 drives that one through
   ; Blt() and its gop answers a mode with no address, which is no framebuffer
   ; at all. ramfb's lands in ordinary ram, so the console paints at memory
   ; speed and the lane costs nothing.
   gfx  (arch = "a64" ? ["-device" "ramfb"] ())
   media (? elf? ["-kernel" iso "-append" (env-of "KTEST_CORPUS" @ c (string? c ? c "test/kernel/all.l"))]   ; KTEST_CORPUS: a lane's own roster
            dir? (fw + below4g + gfx + ["-drive" ("format=raw,file=fat:rw:" + iso)])
            (scare 'ktest-media iso))
   ; kvm where the host can back it: 7x on this corpus (50s of TCG against 7s).
   ; x64-on-x64 only -- `virt` is asked for gic-version=2 above, and an
   ; arm host whose gic cannot back v2 refuses the pairing rather than degrading.
   ; a box without /dev/kvm falls to tcg, so the verdict never rides on this.
   mach? (hark ["uname" "-m"])
   kvm  (? far (arch = "x64" ? ["-enable-kvm" "-cpu" "host"] ["-enable-kvm"])   ; x64's -cpu host hands the guest VT-x
           (two? (stat "/dev/kvm") && arch = "x64" && has? >mach? "x86_64") ["-enable-kvm" "-cpu" "host"]
           ())
   ; the wall ceiling: tcg on a shared box runs ~300s quiet and past 420s loaded
   ceil (two? kvm ? "420" "900")
   ; the scratch disk (rung 5): a sparse raw image beside the artifact, virtio-blk
   ; to the kernel. truncate creates it and leaves an existing one's bytes alone
   ; (same size), so a marker written by one boot survives into the next -- the
   ; persistence gate boots twice on purpose, and test/kernel/disk.l reads which
   ; boot it is off the disk itself. the virts ride virtio-mmio, and qemu's
   ; slots default to the legacy layout -- force-legacy=false is what makes them
   ; speak version 2, the one blk.c drives.
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
   ; far: the elf and its disk go to a scratch dir there, the same line runs in it, and the
   ; dir goes after. paths are the basenames, so nothing of this tree's layout crosses
   r    (far ?
           (: d ("/tmp/ktest-" + show (getpid 0))
              b (foldl (\ a i (iso i = 47 ? (i + 1) a)) 0 (jot #iso) @ k (snip iso k #iso))
              rel (map (x \ (? (x = iso) b
                                (sub-at x 0 "file=" 0) ("file=" + b + ".disk" + snip x (5 + #disk) #x)
                                x))
                       qemu)
              _ (hark ["ssh" far ("mkdir -p " + d)])
              _ (hark ["scp" "-q" iso (far + ":" + d + "/" + b)])
              x (hark ["ssh" far ("cd " + d + " && truncate -s 35840000 " + b + ".disk && "
                                  + foldl (\ a w (a + " '" + w + "'")) "" rel)])
              _ (hark ["ssh" far ("rm -rf " + d)])
              x)
           (hark qemu))
   _    (two? slot ? ((cite 'locks 'locks-release) lroot (slot 1) 'exclusive (getpid 0)) 0)
   out  >r
   line (lineof out "tests pass")
   ; "0 tests pass" is a corpus that died before its first assert wearing a
   ; green face -- a summary only counts when it counted something.
   ok   (has? out "tests pass" && !(has? out "failed:")
         && !(sub-at line 0 "0 tests pass" 0)
         && (#need ? (has? out need) 1))
   (ok ? (puts line, putc 10)
         (say err "ktest: FAILED", put err 10,
          say err out, put err 10, quit 1)))
