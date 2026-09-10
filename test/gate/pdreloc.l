; test/gate/pdreloc.l -- the emit-relocs table on a WHOLE image: two links of one
; object set at two bases, and the recorded R_ARM_ABS32 sites held to being exactly
; the words that moved. test_reloc32 says this on a seven-site toy; this says it on
; the artifact, where a lane the toy never reaches is the one that would drift.
; Complete (nothing moved that the table does not name) AND minimal (nothing named
; that did not move) is the whole contract a relocating loader leans on.
; run: cat this, then (pdreloc-check "<a.elf>" "<b.elf>" <delta>).
(: (u16 s o) (s o | (s (o + 1) << 8))
   (u32 s o) (s o | (s (o + 1) << 8) | (s (o + 2) << 16) | (s (o + 3) << 24))
   ; the one PT_LOAD's (vaddr fileoff filesz) -- a bare image has exactly one
   (pd-load s)
    (: ph (u32 s 28) n (u16 s 44) z (u16 s 42)
       (go i) (? (n <= i) (scare 'pdreloc-no-load 0)
                 (: b (ph + i * z)
                    (u32 s b = 1 ? [(u32 s (b + 8)) (u32 s (b + 4)) (u32 s (b + 16))]
                                   (go (i + 1)))))
       (go 0))
   ; every Elf32_Rel r_offset across every SHT_REL section, in file order
   (pd-sites s)
    (: sh (u32 s 32) n (u16 s 48) z (u16 s 46)
       (go i acc)
        (? (n <= i) acc
           (: b (sh + i * z)
              (go (i + 1)
                  (? (u32 s (b + 4) != 9) acc
                     (: o (u32 s (b + 16)) k (u32 s (b + 20) // 8)
                        (g2 j a2) (? (k <= j) a2 (g2 (j + 1) (a2 + [(u32 s (o + 8 * j))])))
                        (acc + g2 0 ()))))))
       (go 0 ()))
   ; the bundle pdc hands the loader: "Playdate PDX", a 16-byte digest, then filesz,
   ; memsz, entry and the RELOCATION COUNT, then zlib over the image and that many
   ; 4-byte offsets. Holding the count to the ELF's own is what says every site we
   ; recorded survived the packer -- pdc keeps a .rel section only when the section it
   ; names is one of .text .data .got .got.plt .bss, so a lane named anything else is
   ; dropped in silence, and four nif pointers went that way before the lanes folded.
   (pdbin-check pb want)
    (: r (uread pb)
       _ (two? r ? 0 (scare 'pdbin-no-file pb))
       s <>r
       _ (snip s 0 12 = "Playdate PDX" ? 0 (scare 'pdbin-not-pdx pb))
       n (u32 s 44)
       _ (n = want ? 0 (scare 'pdbin-reloc-count [n want]))
       (puts ("  pdex.bin carries all " + show n + " of them past pdc"), putc 10))
   (pdreloc-check pa pb delta)
    (: ra (uread pa) rb (uread pb)
       _ (two? ra && two? rb ? 0 (scare 'pdreloc-no-file [pa pb]))
       a <>ra b <>rb
       ld (pd-load a)
       va <ld fo (ld 1) fz (ld 2)
       sites (pd-sites a)
       _ (0 < #sites ? 0 (scare 'pdreloc-no-sites pa))
       ; the site set, keyed by FILE offset -- what the two images are compared at
       hit (foldl (\ t v (: o (fo + v - va)
                           _ (va <= v < va + fz ? 0 (scare 'pdreloc-site-outside v))
                           _ (0 = o & 3 ? 0 (scare 'pdreloc-site-unaligned v))
                           (pin t o 1)))
                  {} sites)
       ; minimal: every recorded site slides by exactly the delta
       _ (foldl (\ _ v (: o (fo + v - va)
                          (u32 b o = u32 a o + delta ? 0
                           (scare 'pdreloc-not-slid [v (u32 a o) (u32 b o)]))))
                0 sites)
       ; complete: no other word in the loaded image moved
       (walk o n2)
        (? (fo + fz <= o) n2
           (? (0 < peep hit o 0) (walk (o + 4) (n2 + 1))
              (u32 a o = u32 b o) (walk (o + 4) n2)
              (scare 'pdreloc-drift [(o - fo + va) (u32 a o) (u32 b o)])))
       seen (walk fo 0)
       _ (seen = #sites ? 0 (scare 'pdreloc-site-count [seen #sites]))
       _ (puts ("  " + show #sites + " ABS32 sites over " + show fz
                + " loaded bytes slide by " + show delta + ", no other word differs"),
            putc 10)
       #sites))
