; src/tools/uf2.l -- a flat image as UF2, the format a uf2 bootloader takes as a file copied
; onto its drive.
;   love src/tools/uf2.l IN.bin OUT.uf2 BASE FAMILY
; BASE is IN's first byte's flash address, FAMILY the chip's id (0xADA52840 the nrf52840,
; 0xE48BFF56 the rp2040), hex or decimal. 256 bytes ride each 512-byte block, the rest zero
(borrow 'posix)
(: (le32 n) [(n & 255) ((n >> 8) & 255) ((n >> 16) & 255) ((n >> 24) & 255)]
   (dig c) (? (c <= 57) (c - 48) (c <= 70) (c - 55) (c - 87))
   (num s) (? (2 < #s && s 1 = 120) (foldl (\ a i (a * 16 + dig (s i))) 0 (drop 2 ^#s))
              (foldl (\ a c (a * 10 + c - 48)) 0 (map s ^#s)))
   ; block k of n: the magics, flags (a family id present), address, payload size, the count
   (block s k n base fam)
    (: off (k * 256) m (min 256 (#s - off))
       (le32 0x0A324655 + le32 0x9E5D5157 + le32 0x2000 + le32 (base + off) + le32 256
        + le32 k + le32 n + le32 fam
        + map (i \ i < m ? (s (off + i)) 0) ^476
        + le32 0x0AB16F30))
   (fail m) (say err ("uf2: " + m + "\n"), quit 1)
   (main args)
    (: _ (#args = 4 ? 0 (fail "usage: love src/tools/uf2.l IN.bin OUT.uf2 BASE FAMILY"))
       s (uread (args 0) @ [1 s] s (fail ("cannot read " + args 0)))
       _ (0 < #s ? 0 (fail ("empty image " + args 0)))
       base (num (args 2)) fam (num (args 3))
       n ((#s + 255) // 256)
       q (open (args 1) "w")
       (go k) (k < n ? (say q (cask (block s k n base fam)), go (k + 1)) 0)
       (hot? q ? (go 0, close q) (fail ("cannot open " + args 1))))
   (main >argv))
