; --- test/fat.l: FAT32 in love (src/apps/fat.l) over a cask device -- the same
; module the kernel mounts on its virtio disk (rung 5), proven here where the
; laws run in milliseconds and mtools can sit on the other side of the format.
; run standalone from the repo root:
;   cat test/00-init.l test/fat.l | out/love

(borrow "src/apps/fat.l")

; the device: 70000 sectors in one cask. rd answers fresh strings, wr pours.
(: img (cask (70000 * 512))
   (mkdev im) [(\ lba n (: b (cask (n * 512)) _ (pour b 0 im (lba * 512) (n * 512)) (string b)))
               (\ lba s (pour im (lba * 512) s 0 #s, (#s // 512)))
               (#im // 512)]
   dev (mkdev img))

; mkfs: a whole format answers 1; a device under FAT32's own floor refuses
(test
 (1 = (fat-mkfs dev))
 !(fat-mkfs (mkdev (cask (1000 * 512)))))

(: f (fat-mount dev))

; mount: presence, and the honest refusals
(test
 (tablet? f)
 !(fat-mount (mkdev (cask (70000 * 512)))) ; unformatted: no signature
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
(: big ((: (go i acc) (? (i < 200) (go (i + 1) (acc + "0123456789")) acc)) 0 ""))
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

; --- the other side of the format: mtools reads what we wrote, we read what it
; wrote. guarded on mdir being installed (the hdd lane already leans on it).
(: (lines* s) (: n #s
                 (go i w acc) (? (n <= i) (rev (? #w (w . acc) acc))
                                 (? (s i = 10) (go (i + 1) "" (w . acc))
                                    (go (i + 1) (w + string [(s i)]) acc)))
                 (go 0 "" ()))
   have-mtools (: r (hark '("sh" "-c" "command -v mdir >/dev/null && echo yes"))
                  ((! <r) && (0 < #>r)))
   _ (? have-mtools
        (: ip "out/.fat-probe.img"
           _ (: p (open ip "w") _ (say p (string img)) (close p))
           md (hark ["mdir" "-i" ip "-b" "::/"])
           mt (hark ["mtype" "-i" ip "::/limine.conf"])
           lp "out/.fat-probe.txt"
           _ (: p (open lp "w") _ (say p "from the host side") (close p))
           mc (hark ["mcopy" "-i" ip lp "::/fromhost.txt"])
           s (: q (open ip "r") t (slurp q) _ (close q) t)
           im2 (cask #s)
           _ (pour im2 0 s 0 #s)
           f3 (fat-mount (mkdev im2))
           (test
            (! <md) (! <mt) (! <mc)
            (elem "::/limine.conf" (lines* >md))
            ("timeout: 1" = >mt)
            (tablet? f3)
            ("from the host side" = <>(fat-read f3 "fromhost.txt"))
            (unlink ip, unlink lp, 1)))
        (puts "  (mtools interop skipped: no mdir here)")))

; a chain that loops back on itself -- a corrupt or hostile image -- ends where it loops:
; a file's clusters 3 4 5 6 with 4 pointed back at 3, then the root's own cluster at itself
(: lp-im (cask (70000 * 512))
   lp-dev (mkdev lp-im)
   rdle (cite 'bytes 'rdle) wrle (cite 'bytes 'wrle)
   _ (fat-mkfs lp-dev)
   s0 (string lp-im)
   rsvd (rdle s0 14 2) fatsz (rdle s0 36 4) cb (512 * s0 13)
   body ((: (go i acc) (? (i < 4 * cb) (go (i + 1) (acc + "x")) acc)) 0 "")
   _ (fat-write (fat-mount lp-dev) "loop.txt" body)
   (set cl v) (each [rsvd (rsvd + fatsz)] (\ sec (pour lp-im (sec * 512 + 4 * cl) (wrle v 4) 0 4)))
   _ (set 4 3)
   r1 (fat-read (fat-mount lp-dev) "loop.txt")
   _ (set 2 2)
   r2 (fat-ls (fat-mount lp-dev) "")
   (test (two? r1) (#<>r1 = 2 * cb)
         ('("loop.txt") = <>r2)))

(test_fin ())
(puts "fat: ok") (putc 10)
