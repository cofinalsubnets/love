; src/tools/kflat.l -- a kernel elf as the flat image a loader copies to its first load's address
; and enters there: each PT_LOAD at its physical address, its bss laid as zeros, so the file
; is the whole span and a dtb placed past it lands clear of the kernel
;   love src/tools/kflat.l IN.elf OUT.img
(borrow 'posix)
(: (rle s i n) (foldl (\ a k (a * 256 + s (i + n - 1 - k))) 0 ^n)
   (fail m) (say err ("kflat: " + m + "\n"), quit 1)
   (main args)
    (: _ (#args = 2 ? 0 (fail "usage: love src/tools/kflat.l IN.elf OUT.img"))
       s (uread (args 0) @ [1 s] s (fail ("cannot read " + args 0)))
       _ (rle s 0 4 = 0x464c457f ? 0 (fail ("not an elf " + args 0)))
       phoff (rle s 32 8) phn (rle s 56 2)
       (ph i) (phoff + i * 56)
       ; each load: (paddr offset filesz memsz), ascending
       ls (sort (foldl (\ a i (rle s (ph i) 4 = 1
                                 ? ([(rle s (ph i + 24) 8) (rle s (ph i + 8) 8)
                                     (rle s (ph i + 32) 8) (rle s (ph i + 40) 8)] . a)
                                 a))
                       () ^phn))
       _ (two? ls ? 0 (fail ("no loads in " + args 0)))
       base (<ls 0)
       ; [far edge, pieces]: the gap before a load, its bytes, its bss
       r (foldl (\ a l (: at (l 0 - base)
                          _ (<a <= at ? 0 (fail "loads overlap"))
                          [(at + l 3)
                           ([("\0" * (l 3 - l 2)) (snip s (l 1) (l 1 + l 2)) ("\0" * (at - <a))]
                            + <>a)]))
                [0 ()] ls)
       (uwrite (args 1) (foldl (\ a p (a + p)) "" (rev <>r)) @ 1 0 (fail ("cannot write " + args 1))))
   (main >argv))
