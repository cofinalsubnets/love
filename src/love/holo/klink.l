; src/love/holo/klink.l -- holo's link under a linker script, at a kernel's scale: every section
; kept by name and flags, placed by the script (lds.l), relocated, laid as ld.lld lays a
; -shared -Bsymbolic image. load with -l after lds.l. elf64, little-endian, aarch64 first.
;
;   (kl-ar path)          -> the members of an archive, thin or whole: [(name bytes) ..] in
;                            header order, and 'index the symbol index, nom -> member position
;   (kl-read id bytes)    -> one relocatable object as a tablet, see below

(:
   (kl-u16 s i) (rdle s i 2)
   (kl-u32 s i) (rdle s i 4)
   (kl-u64 s i) (rdle s i 8)
   (kl-s64 v) (? (v >= 9223372036854775808) (v - 18446744073709551616) v)
   (kl-cstr s i) (: (go j) (? (s j = 0) (snip s i j) (go (j + 1))) (go i))
   (kl-be32 s i) ((s i << 24) | (s (i + 1) << 16) | (s (i + 2) << 8) | s (i + 3))

   ;; --- archives. a header is 60 bytes: name 16, then size at 48 as decimal text. a thin
   ;     archive's members are paths beside it, its headers followed by no data.
   (kl-arfld s i n) (: t (snip s i (i + n))
                       (go k) (? (0 < k && t (k - 1) = 32) (go (k - 1)) (snip t 0 k))
                       (go n))
   (kl-arnum t) (foldl (\ a i (a * 10 + t i - 48)) 0 ^#t)
   (kl-dir p) (: (go k) (? (k < 1) "" (p (k - 1) = 47) (snip p 0 k) (go (k - 1))) (go #p))
   (kl-ar path)
    (: s <>(uread path)
       _ (? (string? s) 0 (scare 'klink-open path))
       thin (8 <= #s && snip s 0 8 = "!<thin>\n")
       _ (? (thin || (8 <= #s && snip s 0 8 = "!<arch>\n")) 0 (scare 'klink-not-ar path))
       dir (kl-dir path)
       (next off sz) (? thin (off + 60) (off + 60 + sz + sz % 2))
       ; the long-name table, a member named "/<offset>" reads to the "/\n" there
       (lname lt o) (: (go k) (? (k + 1 < #lt && !(lt k = 47 && lt (k + 1) = 10)) (go (k + 1)) k) (snip lt o (go o)))
       (walk off lt idx acc)
        (? (#s <= off + 59) [(rev acc) idx]
           (: nm (kl-arfld s off 16) sz (kl-arnum (kl-arfld s (off + 48) 10)) d0 (off + 60)
              (? (nm = "/") (walk (off + 60 + sz + sz % 2) lt (snip s d0 (d0 + sz)) acc)
                 (nm = "//") (walk (off + 60 + sz + sz % 2) (snip s d0 (d0 + sz)) idx acc)
                 (: real (? (nm 0 = 47) (lname lt (kl-arnum (snip nm 1 #nm)))
                            (#nm > 0 && nm (#nm - 1) = 47) (snip nm 0 (#nm - 1)) nm)
                    by (? thin (: r (uread (dir + real))
                                  (? (two? r) <>r (scare 'klink-member (dir + real))))
                          (snip s d0 (d0 + sz)))
                    (walk (next off sz) lt idx ([real by off] . acc))))))
       w (walk 8 "" () ())
       mem <w
       ; the index: nom -> the member's position, by its header offset; the first definer wins
       pos (: t {} (foldl (\ i m (pin t (m 2) i, i + 1)) 0 mem, t))
       ix (: t {} ix0 <>w
             (? (string? ix0)
                (: n (kl-be32 ix0 0)
                   (go i o) (? (n <= i) t
                               (: nom (kl-cstr ix0 o) at (peep pos (kl-be32 ix0 (4 + 4 * i)) -1)
                                  _ (? (peep t nom -1 != -1) 0 (pin t nom at))
                                  (go (i + 1) (o + 1 + #nom))))
                   (go 0 (4 + 4 * n)))
                t))
       {'members (map (m \ [<m <>m]) mem) 'index ix 'thin thin})

   ;; --- one relocatable object -> a tablet
   ;   'id 'src 'shnum
   ;   'sec          index -> [name type flags off size align entsize link info]
   ;   'syms 'nsym   index -> [name bind type shndx value size]
   ;   'rela         target section index -> [(off kind sym addend) ..], ascending by off
   (kl-read id s)
    (: _ (? (#s > 64 && s 0 = 127 && s 1 = 69 && s 2 = 76 && s 3 = 70) 0 (scare 'klink-not-elf id))
       _ (? (s 4 = 2 && s 5 = 1 && kl-u16 s 16 = 1) 0 (scare 'klink-not-rel64 id))
       shoff (kl-u64 s 40) shnum (kl-u16 s 60) shstrx (kl-u16 s 62)
       (sh i) (shoff + 64 * i)
       shstro (kl-u64 s (sh shstrx + 24))
       sec {}
       _ (each ^shnum
            (i \ (: h (sh i)
                    (pin sec i [(kl-cstr s (shstro + kl-u32 s h)) (kl-u32 s (h + 4)) (kl-u64 s (h + 8))
                                (kl-u64 s (h + 24)) (kl-u64 s (h + 32)) (kl-u64 s (h + 48))
                                (kl-u64 s (h + 56)) (kl-u32 s (h + 40)) (kl-u32 s (h + 44))]))))
       symi ((: (g i) (? (shnum <= i) -1 (sec i 1 = 2) i (g (i + 1)))) 1)
       _ (? (symi < 0) (scare 'klink-no-symtab id))
       sy (sec symi) stro (sec (sy 7) 3)
       nsym (sy 4 // 24)
       syms {}
       _ (each ^nsym
            (i \ (: e (sy 3 + 24 * i) info (s (e + 4))
                    (pin syms i [(kl-cstr s (stro + kl-u32 s e)) (info >> 4) (info & 15)
                                 (kl-u16 s (e + 6)) (kl-u64 s (e + 8)) (kl-u64 s (e + 16))]))))
       rela {}
       _ (each ^shnum
            (i \ (: r (sec i)
                    (? (r 1 = 4)
                       (: n (r 4 // 24) o (r 3)
                          (es k acc) (? (k < 0) acc
                                        (: e (o + 24 * k) inf (kl-u64 s (e + 8))
                                           (es (k - 1) ([(kl-u64 s e) (inf & 4294967295) (inf >> 32)
                                                         (kl-s64 (kl-u64 s (e + 16)))] . acc))))
                          (pin rela (r 8) (es (n - 1) ())))
                       (r 1 = 9) (scare 'klink-rel id)
                       0))))
       {'id id 'src s 'shnum shnum 'sec sec 'syms syms 'nsym nsym 'rela rela}))
