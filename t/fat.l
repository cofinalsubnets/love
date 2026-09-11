; --- t/fat.l: FAT32 in love (a/fat/fat.l) over a cask device -- the same
; module the kernel mounts on its virtio disk (rung 5), proven here where the
; laws run in milliseconds and mtools can sit on the other side of the format.
; run standalone from the repo root:
;   cat t/00-init.l t/fat.l | b/love

(borrow "a/fat/fat.l")

; the device: 70000 sectors in one cask. rd answers fresh strings, wr pours.
(: img (cask (70000 * 512))
   (mkdev im) [(\ lba n (: b (cask (n * 512)) _ (pour b 0 im (lba * 512) (n * 512)) (string b)))
               (\ lba s (: _ (pour im (lba * 512) s 0 #s) (#s // 512)))
               (tally im // 512)]
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
                 (go i w acc) (? (n <= i) (rev (? #w (. w acc) acc))
                                 (? (s i = 10) (go (i + 1) "" (. w acc))
                                    (go (i + 1) (w + string [(s i)]) acc)))
                 (go 0 "" ()))
   have-mtools (: r (hark '("sh" "-c" "command -v mdir >/dev/null && echo yes"))
                  ((! <r) && (0 < tally >r)))
   _ (? have-mtools
        (: ip "b/.fat-probe.img"
           _ (: p (open ip "w") _ (say p (string img)) (close p))
           md (hark ["mdir" "-i" ip "-b" "::/"])
           mt (hark ["mtype" "-i" ip "::/limine.conf"])
           lp "b/.fat-probe.txt"
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
            (: _ (unlink ip) _ (unlink lp) 1)))
        (puts "  (mtools interop skipped: no mdir here)")))

(test_fin ())
(puts "fat: ok") (putc 10)
