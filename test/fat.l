; FAT32 in love over a cask device, with mtools on the other side when present

(borrow "src/apps/fat.l")

; the device: a sector a tablet's row, an unwritten or zero one absent. rd answers fresh strings
(: zero-sec (string (cask 512))
   (mkdev nsec) (: m {}
     [(lba \ n \ cask (n * 512) @ b
        (each ^n (i \ peep m (lba + i) () @ s (s ? (pour b (i * 512) s 0 512) 0)), string b))
      (lba \ s \ (each ^(#s // 512) (i \ snip s (i * 512) (i * 512 + 512) @ t
                                     (pin m (lba + i) (t = zero-sec ? () t))), (#s // 512)))
      nsec])
   dev (mkdev 70000))

; the device's own law, at its far end: a run lands sector by sector, its zero sector too, and an
; overwrite with zeros reads back as zeros
(: (ws c) (string (cask 512 @ b (pin b 0 c, pin b 511 (c + 1), b)))
   d (mkdev 70000) run (ws 1 + zero-sec + ws 3)
   _ (<>d 69996 run)
   r (<d 69995 4)
   _ (<>d 69996 zero-sec)
   (test (2048 = #r) (zero-sec = snip r 0 512) (run = snip r 512 2048)
         (zero-sec = <d 69996 1) (ws 3 = <d 69998 1) (70000 = <>>d)))

; mkfs: a whole format answers 1; a device under FAT32's own floor refuses
(test
 (1 = (fat-mkfs dev))
 !(fat-mkfs (mkdev 1000)))

(: f (fat-mount dev))

; mount: presence, and the honest refusals
(test
 (tablet? f)
 !(fat-mount (mkdev 70000)) ; unformatted: no signature
 (two? (fat-ls f "")) (! <>(fat-ls f ""))  ; the fresh root: (1 ())
 !(fat-ls f "nope") !(fat-read f "nope") !(fat-stat f "nope"))

; files: write, list, stat, read -- and every answer wears the (1 _) wrapper
(test
 (1 = (fat-write f "hello.txt" "hello disk"))
 ('("hello.txt") = <>(fat-ls f ""))
 ('(1 10 32) = (fat-stat f "hello.txt"))
 ("hello disk" = <>(fat-read f "hello.txt"))
 ; the empty file is a real answer: (1 ""), never ()
 (1 = (fat-write f "empty" ""))
 (two? (fat-read f "empty")) ("" = <>(fat-read f "empty"))
 ('(1 0 32) = (fat-stat f "empty")))

; replace: longer, then shorter; the size follows, the old chain is freed
(: big ((: (go i acc) (i < 200 ? (go (i + 1) (acc + "0123456789")) acc)) 0 ""))
(test
 (1 = (fat-write f "hello.txt" big))                  ; 2000 bytes: a real chain
 (2000 = <>(fat-stat f "hello.txt"))
 (big = <>(fat-read f "hello.txt"))
 (1 = (fat-write f "hello.txt" "short"))
 ("short" = <>(fat-read f "hello.txt")))

; long names: LFN written and read back, case-blind like everything here
(test
 (1 = (fat-write f "limine.conf" "timeout: 1"))
 ("timeout: 1" = <>(fat-read f "LIMINE.CONF"))
 (1 = (fat-write f "a rather long name indeed.text" "lfn"))
 ("lfn" = <>(fat-read f "a rather long name indeed.text"))
 (elem "limine.conf" <>(fat-ls f "")))

; directories: mkdir, files inside, nesting; rm insists a dir be empty first
(test
 (1 = (fat-mkdir f "boot"))
 (1 = (fat-write f "boot/love.elf" "ELF!"))
 ("ELF!" = <>(fat-read f "/boot/love.elf"))
 ('("love.elf") = <>(fat-ls f "boot"))
 (1 = (fat-mkdir f "boot/deep"))
 (1 = (fat-write f "boot/deep/x" "y"))
 ("y" = <>(fat-read f "boot/deep/x"))
 !(fat-write f "gone/x" "y")                          ; an absent parent refuses
 !(fat-rm f "boot")                                   ; not empty
 (1 = (fat-rm f "boot/deep/x"))
 (1 = (fat-rm f "boot/deep"))
 (1 = (fat-rm f "hello.txt"))
 !(fat-stat f "hello.txt"))

; persistence is the point: a fresh mount over the same bytes reads it all back
(: f2 (fat-mount dev))
(test
 (tablet? f2)
 ("timeout: 1" = <>(fat-read f2 "limine.conf"))
 ("ELF!" = <>(fat-read f2 "boot/love.elf"))
 ("" = <>(fat-read f2 "empty")))

; --- mtools reads what we wrote, we read what it wrote; only where mdir is installed
(: (lines* s) (: n #s
                 (go i w acc) (n <= i ? (rev (#w ? (w . acc) acc))
                                 (s i = 10 ? (go (i + 1) "" (w . acc))
                                    (go (i + 1) (w + string [(s i)]) acc)))
                 (go 0 "" ()))
   have-mtools (hark '("sh" "-c" "command -v mdir >/dev/null && echo yes") @ r
                (! <r && 0 < #>r))
   _ (? have-mtools
        (: ip ("out/.fat-probe." + show (getpid 0) + ".img")   ; per process: shards run at once
           _ (open ip "w" @ p (say p (<dev 0 70000), close p))
           md (hark ["mdir" "-i" ip "-b" "::/"])
           mt (hark ["mtype" "-i" ip "::/limine.conf"])
           lp ("out/.fat-probe." + show (getpid 0) + ".txt")
           _ (open lp "w" @ p (say p "from the host side", close p))
           mc (hark ["mcopy" "-i" ip lp "::/fromhost.txt"])
           s (: q (open ip "r") t (slurp q) (close q, t))
           d3 (mkdev (#s // 512))
           _ (<>d3 0 s)
           f3 (fat-mount d3)
           (test
            (! <md) (! <mt) (! <mc)
            (elem "::/limine.conf" (lines* >md))
            ("timeout: 1" = >mt)
            (tablet? f3)
            ("from the host side" = <>(fat-read f3 "fromhost.txt"))
            (unlink ip, unlink lp, 1)))
        (puts "  (mtools interop skipped: no mdir here)")))

; the shared device goes with the file
(: dev () f () f2 ())

; a cluster chain that loops back on itself ends where it loops: a file's, then the root's
(: lp-dev (mkdev 70000)
   rdle (cite 'bytes 'rdle) wrle (cite 'bytes 'wrle)
   _ (fat-mkfs lp-dev)
   s0 (<lp-dev 0 1)
   rsvd (rdle s0 14 2) fatsz (rdle s0 36 4) cb (512 * s0 13)
   body ((: (go i acc) (i < 4 * cb ? (go (i + 1) (acc + "x")) acc)) 0 "")
   _ (fat-write (fat-mount lp-dev) "loop.txt" body)
   (set cl v) (each [rsvd (rsvd + fatsz)] (sec \ cask 512 @ b (pour b 0 (<lp-dev sec 1) 0 512, pour b (4 * cl) (wrle v 4) 0 4, <>lp-dev sec (string b))))
   _ (set 4 3)
   r1 (fat-read (fat-mount lp-dev) "loop.txt")
   _ (set 2 2)
   r2 (fat-ls (fat-mount lp-dev) "")
   (test (two? r1) (#<>r1 = 2 * cb)
         ('("loop.txt") = <>r2)))

; an MBR card: the first FAT32 partition mounts, its lbas shifted; a FAT16 entry is passed over
(: wd (mkdev 72048)
   pd [(lba \ n \ <wd (lba + 2048) n) (lba \ s \ <>wd (lba + 2048) s) 70000]
   wrle (cite 'bytes 'wrle)
   _ (fat-mkfs pd)
   _ (fat-write (fat-mount pd) "card.txt" "on a partition")
   mbr (cask 512)
   _ (pin mbr 450 6, pin mbr 466 12)
   _ (pour mbr 470 (wrle 2048 4) 0 4, pour mbr 474 (wrle 70000 4) 0 4)
   _ (pin mbr 510 0x55, pin mbr 511 0xAA)
   _ (<>wd 0 (string mbr))
   (test ("on a partition" = <>(fat-read (fat-mount wd) "card.txt"))
         !(fat-mount (mkdev 4096))))

(test_fin ())
