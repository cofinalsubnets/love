; src/love/holo/elfsec.l -- a named section's bytes out of any ELF, any machine's:
;
;   (elfsec path nm) -> (1 bytes) | ()      () for no file / no section
;
; the wrapper keeps an empty section distinct from an absent one.
(borrow 'posix)
(:
   (es-slurp p) (uread p @ [1 s] s ())
   (es-le s i n) (: (go k a m) (k = n ? a (go (k + 1) (a + peep s (i + k) 0 * m) (m * 256)))
                    (go 0 0 1))
   ; by e_ident[4] (1 elf32, 2 elf64): e_shoff off width, e_shentsize off, e_shnum off |
   ; sh_name sh_offset sh_size as off width; e_shstrndx sits two past e_shnum.
   es-e32 '(32 4 46 48   0 4 16 4 20 4)
   es-e64 '(40 8 58 60   0 4 24 8 32 8)
   (es-sec exe nm)
    (: t (peep exe 4 0 = 1 ? es-e32 es-e64)
       (le i n) (es-le exe i n)
       (f i) (t i)
       shoff (le (f 0) (f 1)) shentsz (le (f 2) 2) shnum (le (f 3) 2)
       shstrx (le (f 3 + 2) 2)
       (sh i o w) (le (shoff + i * shentsz + o) w)
       (shf i k) (sh i (f k) (f (k + 1)))
       stro (shf shstrx 6)
       (cstr i) (: (go j) (peep exe j 0 = 0 ? (snip exe i j) (go (j + 1))) (go i))
       (go i) (? (i = shnum) ()
                 (nm = cstr (stro + shf i 4))
                  (shf i 6 @ o [(snip exe o (o + shf i 8))])
                 (go (i + 1)))
       (go 0))
   (elfsec path nm) (es-slurp path @ s (string? s && es-sec s nm))
   )
