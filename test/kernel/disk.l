; test/kernel/disk.l -- the virtio disk's raw door, then src/apps/fat.l mounted on the device.
; a bus that hides the disk skips with a word. the raw probe writes sector 16, inside FAT32's
; reserved region: src/tools/ktest.l boots this corpus twice on one image and greps the second
; log for "disk: fat kept", the reset-persistence gate.
(disk () @ dn
   (!dn ? (puts "disk: none here, laws skipped", putc 10, ())
      (: pat ((: (go b i) (i < 512 ? (pin b i (i * 7 % 256), go b (i + 1))
                           (string b)))
              (cask 512) 0)
         (test (65536 < dn)                        ; the gate attaches ~70000 sectors
               (1 = disk-write 16 pat)
               (pat = disk-read 16 1)
               (1024 = #(disk-read 16 2))
               !(disk-read dn 1)                   ; past the end: absence
               !(disk-write 3 "abc")               ; not whole sectors: refused
               !(disk-read 0 0),
          ()))))
(borrow "src/apps/fat.l")
(fat-disk () @ dev
   (atom? dev ? ()
    (: f0 (fat-mount dev)
       seen (tablet? f0 ? (fat-read f0 "boot.txt"))
       f (tablet? f0 ? f0 (fat-mkfs dev, fat-mount dev))
       ((two? seen ?
           (test ("the machine remembers" = <>seen),
            puts "disk: fat kept across the reset", putc 10)
           (puts "disk: fat born", putc 10, ())),
        test (tablet? f),
        test (1 = fat-write f "boot.txt" "the machine remembers"),
        test (1 = fat-write f "scratch.txt" "abc")
               ("abc" = <>(fat-read f "scratch.txt"))
               (two? <>(fat-ls f ""))
               (1 = fat-rm f "scratch.txt")
               !(fat-stat f "scratch.txt"),
        ()))))
