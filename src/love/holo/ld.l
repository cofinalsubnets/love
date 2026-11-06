; src/love/holo/ld.l -- holo's link under a linker script, at a kernel's scale: every section
; kept by name and flags, placed and laid by link.l's script engine, relocated, written as
; ld.lld writes a -shared -Bsymbolic image, or copied whole as ld.lld -r lays a relocatable
; one. after link.l in module holo, on its field encoders. elf64, little-endian, aarch64 first.
;
;   (ld-ar path)          -> the members of an archive, thin or whole: [(name bytes) ..] in
;                            header order; the symbol index is not read
;   (ld-rel64 id bytes)   -> one relocatable object as a tablet, see below
;   (ld-banner id text)   -> an object of one .comment line, for the linker to sign with
;   (ld-kas id text)      -> the object scripts/kallsyms' .S assembles to, read directly

(module 'holo
(borrow '(posix bytes hashes))
(:
   (ld-s64 v) (? (v >= 9223372036854775808) (v - 18446744073709551616) v)

   ;; --- archives. a header is 60 bytes: name 16, then size at 48 as decimal text. a thin
   ;     archive's members are paths beside it, its headers followed by no data.
   (ld-dir p) (: (go k) (? (k < 1) "" (p (k - 1) = 47) (snip p 0 k) (go (k - 1))) (go #p))
   (ld-ar path) (: s <>(uread path) (? (string? s) (ld-ars path s) (scare 'link-open path)))
   (ld-ar-or-thin? s) (8 <= #s && (snip s 0 8 = "!<arch>\n" || snip s 0 8 = "!<thin>\n"))
   (ld-ars path s)
    (: thin (8 <= #s && snip s 0 8 = "!<thin>\n")
       _ (? (thin || (8 <= #s && snip s 0 8 = "!<arch>\n")) 0 (scare 'link-not-ar path))
       dir (ld-dir path)
       (next off sz) (? thin (off + 60) (off + 60 + sz + sz % 2))
       ; the long-name table, a member named "/<offset>" reads to the "/\n" there
       (lname lt o) (: (go k) (? (k + 1 < #lt && !(lt k = 47 && lt (k + 1) = 10)) (go (k + 1)) k) (snip lt o (go o)))
       (walk off lt acc)
        (? (#s <= off + 59) (rev acc)
           (: nm (ld-arfld s off 16) sz (ld-arnum (ld-arfld s (off + 48) 10)) d0 (off + 60)
              (? (nm = "/") (walk (off + 60 + sz + sz % 2) lt acc)
                 (nm = "//") (walk (off + 60 + sz + sz % 2) (snip s d0 (d0 + sz)) acc)
                 (: real (? (nm 0 = 47) (lname lt (ld-arnum (snip nm 1 #nm)))
                            (#nm > 0 && nm (#nm - 1) = 47) (snip nm 0 (#nm - 1)) nm)
                    by (? thin (: r (uread (dir + real))
                                  (? (two? r) <>r (scare 'link-member (dir + real))))
                          (snip s d0 (d0 + sz)))
                    (walk (next off sz) lt ([real by] . acc))))))
       {'members (walk 8 "" ()) 'thin thin})

   ;; --- one relocatable object -> a tablet
   ;   'id 'src 'shnum
   ;   'sec          index -> [name type flags off size align entsize link info]
   ;   'syms 'nsym   index -> [name bind type shndx value size other]
   ;   'relz         target section index -> its relocations' decoder (ld-relas)
   (ld-rel64 id s)
    (: r (ld-obj id s 2)
       ; i386's are ELF32, their relocations REL; every other machine's ELF64 and RELA
       i386 (r 'mach = 3)
       _ (r 'class = (? i386 32 64) && r 'type = 1 ? 0 (scare 'link-not-rel64 id))
       _ (r 'nsym > 0 ? 0 (scare 'link-no-symtab id))
       _ (each ^(r 'shnum) (i \ (r 'sec i 1 = (? i386 4 9) ? (scare 'link-rel id))))
       (any (i \ 0 < (r 'sec i 2 & 2048)) ^(r 'shnum) ? (ld-unz r) r))

   ; compressed sections read as lld reads them: inflated, the size and alignment their header's.
   ; the bytes land past the file's own, so every offset holds and nothing later need know
   (ld-unz r)
    (: s (r 'src) id (r 'id) hz (? (r 'class = 64) 24 12) w (? (r 'class = 64) 8 4)
       (door m f) (: g (cite m f) (? (lit? g) g (scare 'link-compressed [id m])))
       (out nm v) (? (two? v) <>v (scare 'link-compressed [id nm]))
       st {'n #s 'ps ()}
       (one e)
        (? (0 = (e 2 & 2048)) e
           (: o (e 3) ty (rle32 s o) n (rdle s (o + hz - 2 * w) w) al (rdle s (o + hz - w) w)
              z (snip s (o + hz) (o + e 4))
              b (? (ty = 1) (out <e (door 'gz 'gz-inflate (snip z 2 #z) n))
                   (ty = 2) (out <e (door 'zstd 'zstd-unpack z))
                   (scare 'link-compressed [id <e ty]))
              _ (? (#b = n) 0 (scare 'link-compressed [id <e n #b]))
              off (st 'n)
              _ (pin st 'n (off + n), pin st 'ps (b . st 'ps))
              [<e (e 1) (e 2 - 2048) off n (max al 1) (e 6) (e 7) (e 8)]))
       sec (spread (map (i \ one (r 'sec i)) ^(r 'shnum)))
       _ (pin r 'sec sec, pin r 'src (foldl (\ a p (a + p)) s (rev (st 'ps))))
       r)

   ; the linker's own .comment line, an object after every other, as ld.lld adds its banner
   (ld-banner id t)
    (: s (string (map t ^#t + [0]))
       {'id id 'src s 'shnum 2 'sec {0 ["" 0 0 0 0 0 0 0 0] 1 [".comment" 1 48 0 #s 1 1 0 0]}
        'syms {0 ["" 0 0 0 0 0 0]} 'nsym 1 'rela {}})

   ; the .S scripts/kallsyms writes, read straight to an object: .byte .short .long .asciz,
   ; ALGN and PTR at 64 bits, labels and .globl; laid as clang lays it, the debug sections
   ; empty but there, so a strip-debug link writes the same symbols
   (ld-kas id s)
    (: n #s
       (eol i) (: (go k) (? (k >= n || s k = 10) k (go (k + 1))) (go i))
       (sp? c) (c = 32 || c = 9 || c = 44)
       (skip i e) (? (i < e && sp? (s i)) (skip (i + 1) e) i)
       (word i e) (: (go k) (? (k >= e || sp? (s k) || s k = 58) k (go (k + 1))) (go i))
       (dig c) (? (c < 58) (c - 48) (c < 71) (c - 55) (c - 87))
       (num i e) (? (i + 1 < e && s i = 48 && s (i + 1) = 120)
                    (: (go k a) (? (k >= e) a (go (k + 1) (a * 16 + dig (s k)))) (go (i + 2) 0))
                    (: (go k a) (? (k >= e) a (go (k + 1) (a * 10 + s k - 48))) (go i 0)))
       ; numbers to a comment or the line's end
       (nums i e acc) (: j (skip i e)
                         (? (j >= e || s j = 47) (rev acc)
                            (: k (word j e) (nums k e (num j k . acc)))))
       st {'off 0 'out () 'lab {} 'ord () 'seen {} 'rel ()}
       (emit b) (pin st 'out (b . st 'out), pin st 'off (st 'off + #b))
       (name nm) (? (peep (st 'seen) nm ()) () (pin (st 'seen) nm 1, pin st 'ord (nm . st 'ord)))
       (line i e)
        (: j (skip i e) k (word j e) w (snip s j k)
           (? (j >= e || s j = 35) ()
              (k < e && s k = 58) (: _ (name w) (pin (st 'lab) w (st 'off)))
              (w = ".byte") (emit (string (nums k e ())))
              (w = ".short") (emit (string (ld-le (num (skip k e) (word (skip k e) e)) 2)))
              (w = ".long") (emit (string (ld-le (num (skip k e) (word (skip k e) e)) 4)))
              (w = ".asciz") (: q (skip k e) (go z) (? (s z = 34) z (go (z + 1)))
                                (emit (snip s (q + 1) (go (q + 1))), emit (string [0])))
              (w = ".globl") (name (snip s (skip k e) (word (skip k e) e)))
              (w = "ALGN") (: r (st 'off % 8) (? (r = 0) () (emit (string (map (x \ 0) ^(8 - r))))))
              (w = "PTR") (: a (skip k e) b (word a e) nm (snip s a b) p (skip b e)
                             add (? (p < e && s p = 43) (: q (skip (p + 1) e) (num q (word q e))) 0)
                             _ (name nm)
                             _ (pin st 'rel ([(st 'off) nm add] . st 'rel))
                             (emit (string (ld-le 0 8))))
              (w = ".section") ()
              (scare 'link-kas w)))
       (walk i) (? (i >= n) () (: e (eol i) _ (line i e) (walk (e + 1))))
       _ (walk 0)
       src (cats (rev (st 'out)))
       ord (rev (st 'ord))
       ix (: t {} _ (foldl (\ k nm (pin t nm k, k + 1)) 5 ord) t)
       {'id id 'src src 'shnum 9 'nsym (5 + #ord)
        'sec {0 ["" 0 0 0 0 0 0 0 0] 1 [".strtab" 3 0 0 0 1 0 0 0] 2 [".text" 1 6 0 0 4 0 0 0]
              3 [".rodata" 1 2 0 #src 8 0 0 0] 4 [".rela.rodata" 4 64 0 (24 * #(st 'rel)) 8 24 8 3]
              5 [".debug_line" 1 0 0 0 1 0 0 0] 6 [".rela.debug_line" 4 64 0 0 8 24 8 5]
              7 [".debug_line_str" 1 48 0 0 1 1 0 0] 8 [".symtab" 2 0 0 0 8 24 1 5]}
        'syms (foldl (\ t nm (: o (peep (st 'lab) nm -1)
                               (pin t (ix nm) [nm 1 0 (o < 0 ? 0 3) (o < 0 ? 0 o) 0 0])))
                     {0 ["" 0 0 0 0 0 0] 1 ["$d" 0 0 3 0 0 0] 2 ["$d" 0 0 5 0 0 0]
                      3 ["" 0 3 7 0 0 0] 4 ["$d" 0 0 7 0 0 0]}
                     ord)
        'rela {3 (rev (map (r \ [<r 257 (ix (r 1)) (r 2)]) (st 'rel)))}})

   ; a string table in the making, one text: (ld-stradd t nm) -> its offset, 0 for an empty name
   (ld-strtab u) (: j (jug 0) _ (put j 0) {'n 1 'j j})
   (ld-stradd t nm) (? (#nm = 0) 0 (: o (t 'n) _ (pin t 'n (o + #nm + 1), say (t 'j) nm, put (t 'j) 0) o))
   ; a pass over all an object's locals reads them afresh where the reader can
   (ld-symr ob) (peep ob 'symr (ob 'syms))
   (ld-nloc ob) (peep ob 'nloc (ob 'nsym))
   ; each symbol past the locals, a global or weak: (f si row)
   (ld-globs ob f)
    (: n (ob 'nsym) sy (ob 'syms)
       (go si) (? (si >= n) 0 (: r (sy si) _ (? (r 1 = 0) 0 (f si r)) (go (si + 1))))
       (go (max 1 (peep ob 'nloc 1))))

   ;; --- inputs, resolved as lld resolves them. items: ('whole path) ('obj path) ('group
   ;     (path ..)) ('in path whole?), an object or an archive by its magic. every global
   ;     name is inserted in first-seen order; a file's definitions resolve before its
   ;     undefineds, and a strong undefined extracts a lazy member at once, depth first. a
   ;     group archive's members are lazy: each in member order offers its definitions
   ;     until one meets a strong undefined, which extracts it. answers 'objs [ob ..] in
   ;     parse order, 'ot index -> ob, 'glob nom -> [oi si] the definition, 'und nom -> 0
   ;     defined, 1|2 strong or weak undefined, 'order every name inserted
   (ld-load items)
    (: cx {'objs () 'n 0 'ot {} 'glob {} 'und {} 'lazy {} 'order () 'seen {} 'grp {} 'uonly {}}
       glob (cx 'glob) und (cx 'und) lazy (cx 'lazy) ot (cx 'ot) seen (cx 'seen)
       (ins nom) (? (peep seen nom 0) 0 (: _ (pin seen nom 1) (pin cx 'order (nom . cx 'order))))
       (gl ob f) (ld-globs ob (\ si r (? (#(<r) = 0) 0 (f si r))))
       ; a definition in a dropped group's section is a reference, as lld takes it
       (add ob)
        (: oi (cx 'n)
           dr (ld-comdat (cx 'grp) ob)
           (gone? r) (r 3 = 0 || peep dr (r 3) 0)
           _ (pin cx 'n (oi + 1), pin ot oi ob, pin cx 'objs (ob . cx 'objs))
           _ (gl ob (\ si r (ins <r)))
           _ (gl ob (\ si r (? (gone? r) 0 (def oi si r))))
           _ (gl ob (\ si r (? (gone? r) (: _ (pin (cx 'uonly) <r 0) (ref <r (r 1))) 0)))
           oi)
       (def oi si r)
        (: nom <r cur (peep glob nom ())
           (? (atom? cur) (: _ (pin glob nom [oi si], pin und nom 0) (pin lazy nom ()))
              (r 1 = 1 && ot <cur 'syms (cur 1) 1 = 2) (pin glob nom [oi si])
              0))
       (ref nom bind)
        (? (two? (peep glob nom ())) 0
           (: u (peep und nom 0) m (peep lazy nom ())
              _ (pin und nom (? (u = 1 || bind = 1) 1 2))
              (? (bind = 1 && two? m) (extract <m) 0)))
       (extract mem) (? (mem 'taken) 0 (: _ (pin mem 'taken 1) (add (mem 'ob))))
       ; a lazy member offers its definitions in order until one meets a strong undefined
       (offer mem)
        (: ob (mem 'ob) sy (ob 'syms)
           (go si) (? (si >= ob 'nsym) 0
                      (: r (sy si)
                         (? (r 3 = 0 || #(<r) = 0) (go (si + 1))
                            (: nom <r _ (ins nom)
                               (? (two? (peep glob nom ())) (go (si + 1))
                                  (peep und nom 0 = 1) (extract mem)
                                  (: _ (? (two? (peep lazy nom ())) 0 (pin lazy nom [mem]))
                                     (go (si + 1))))))))
           (go (max 1 (peep ob 'nloc 1))))
       _ (each items
          (it \ (: k <it
                   (? (k = 'obj) (add (ld-rel64 <>it <>(uread <>it)))
                      (k = 'tablet) (add <>it)
                      (k = 'undef) (: _ (ins <>it) _ (? (peep und <>it 0 = 0) (pin (cx 'uonly) <>it 1) 0) (ref <>it 1))
                      (k = 'in)
                       (: p (it 1) s <>(uread p)
                          (? (!(string? s)) (scare 'link-open p)
                             !(ld-ar-or-thin? s) (add (ld-rel64 p s))
                             (it 2) (each ((ld-ars p s) 'members) (m \ add (ld-rel64 <m <>m)))
                             (each ((ld-ars p s) 'members) (m \ offer {'ob (ld-rel64 <m <>m) 'taken 0}))))
                      (k = 'whole) (each ((ld-ar <>it) 'members) (m \ add (ld-rel64 <m <>m)))
                      (k = 'group)
                       (each <>it (p \ each ((ld-ar p) 'members)
                                         (m \ offer {'ob (ld-rel64 <m <>m) 'taken 0})))
                      (scare 'link-input k)))))
       _ (pin cx 'objs (rev (cx 'objs)), pin cx 'order (rev (cx 'order)))
       cx)

   ; a COMDAT group is the first object's to name its signature: a later one's sections join
   ; ob 'drops, which ld-place passes over. answers the drops
   (ld-comdat grp ob)
    (: s (ob 'src) d (peep ob 'drops ()) dr (? (d = ()) {} d)
       (one si) (: r (ob 'sec si)
                   (? (r 1 != 17 || (rle32 s (r 3) & 1) = 0) 0
                      (: sig <(ob 'syms (r 8))
                         (? (peep grp sig 0) (: _ (pin dr si 1) (each >^(r 4 // 4) (k \ pin dr (rle32 s (r 3 + 4 * k)) 1)))
                            (pin grp sig 1)))))
       _ (each >^(ob 'shnum) one)
       _ (pin ob 'drops dr)
       dr)

   ;; --- xxh3_64 with seed 0, lld's piece hash: its low word's top five bits pick a merge shard
   ld-xsec (string [184 254 108 57 35 164 75 190 124 1 129 44 247 33 173 28 222 212 109 233 131 144 151 219
                  114 64 164 164 183 179 103 31 203 121 230 78 204 192 229 120 130 90 208 125 204 255 114 33
                  184 8 70 116 247 67 36 142 224 53 144 230 129 58 38 76 60 40 82 187 145 195 0 203
                  136 208 101 139 27 83 46 163 113 100 72 151 162 13 249 78 56 25 239 70 169 222 172 216
                  168 250 118 63 227 156 52 63 249 220 187 199 199 11 79 29 138 81 224 75 205 180 89 49
                  200 159 126 201 217 120 115 100 234 197 172 131 52 211 235 195 197 129 160 255 250 19 99 235
                  23 13 221 81 183 240 218 73 211 22 85 38 41 212 104 158 43 22 190 88 125 71 161 252
                  143 248 184 209 122 208 49 206 69 203 58 143 149 22 4 40 175 215 251 202 187 75 64 126])
   ld-xp1 11400714785074694791 ld-xp2 14029467366897019727 ld-xp3 1609587929392839161
   ld-xp4 9650029242287828579 ld-xp5 2870177450012600261
   ld-xmx1 1609587791953885689 ld-xmx2 11507291218515648293
   (ld-xm a b) (ld-w (a * b))
   (ld-xf a b) (: p (a * b) (ld-xor (p % ld-m64) (p // ld-m64)))         ; 128-bit product, folded
   (ld-xr h n) (ld-xor h (h // (2 ** n)))
   (ld-xrot h r) (ld-w (h * (2 ** r)) + h // (2 ** (64 - r)))
   (ld-xsw x) (foldl (\ a i (a * 256 + x // (256 ** i) % 256)) 0 ^8)
   (ld-xav h) (ld-xr (ld-xm (ld-xr h 37) ld-xmx1) 32)
   (ld-x64av h) (ld-xr (ld-xm (ld-xr (ld-xm (ld-xr h 33) ld-xp2) 29) ld-xp3) 32)
   (ld-xrrmx h n) (: a (ld-xm (ld-xor h (ld-xor (ld-xrot h 49) (ld-xrot h 24))) ld-xmx2)
                     b (ld-xm (ld-xor a (ld-w (a // (2 ** 35) + n))) ld-xmx2)
                     (ld-xr b 28))
   (ld-xxh s)
    (: n #s k ld-xsec (r64 t i) (rdle t i 8)
       (mix i j) (ld-xf (ld-xor (r64 s i) (r64 k j)) (ld-xor (r64 s (i + 8)) (r64 k (j + 8))))
       (mixes l) (foldl (\ a p (a + mix <p <>p)) 0 l)
       (? (n = 0) (ld-x64av (ld-xor (r64 k 56) (r64 k 64)))
          (n < 4) (ld-x64av (ld-xor (s 0 * 65536 + s (n // 2) * 16777216 + s (n - 1) + n * 256)
                                    (ld-xor (rdle k 0 4) (rdle k 4 4))))
          (n <= 8) (ld-xrrmx (ld-xor (rdle s (n - 4) 4 + rdle s 0 4 * ld-m32) (ld-xor (r64 k 8) (r64 k 16))) n)
          (n <= 16) (: lo (ld-xor (r64 s 0) (ld-xor (r64 k 24) (r64 k 32)))
                       hi (ld-xor (r64 s (n - 8)) (ld-xor (r64 k 40) (r64 k 48)))
                       (ld-xav (ld-w (n + ld-xsw lo + hi + ld-xf lo hi))))
          (n <= 128) (ld-xav (ld-w (n * ld-xp1 + mixes (cats [[[0 0] [(n - 16) 16]]
                                                             (? (n > 32) [[16 32] [(n - 32) 48]] ())
                                                             (? (n > 64) [[32 64] [(n - 48) 80]] ())
                                                             (? (n > 96) [[48 96] [(n - 64) 112]] ())]))))
          (n <= 240) (: a (ld-xav (ld-w (n * ld-xp1 + mixes (map (i \ [(16 * i) (16 * i)]) ^8))))
                        (ld-xav (ld-w (a + mixes (map (i \ [(16 * i) (16 * (i - 8) + 3)]) (drop 8 ^(n // 16)))
                                       + mix (n - 16) 119))))
          (ld-xlong s n)))
   ; over 240 bytes: eight lanes over 64-byte stripes, scrambled every 1024
   (ld-xlong s n)
    (: k ld-xsec (r64 t i) (rdle t i 8)
       (stripe acc p j)
        (: dv (map (i \ r64 s (p + 8 * i)) ^8)
           (map (i \ (: d (ld-xor (dv i) (r64 k (j + 8 * i)))
                        (ld-w (acc i + dv (i ^ 1) + (d % ld-m32) * (d // ld-m32)))))
                ^8))
       (stripes acc p m) (foldl (\ a q (stripe a (p + 64 * q) (8 * q))) acc ^m)
       (scram acc) (map (i \ (: a (acc i) (ld-xm (ld-xor (ld-xr a 47) (r64 k (128 + 8 * i))) 2654435761))) ^8)
       nb ((n - 1) // 1024)
       a0 (foldl (\ a b (scram (stripes a (1024 * b) 16)))
                 [3266489917 ld-xp1 ld-xp2 ld-xp3 ld-xp4 2246822519 ld-xp5 2654435761] ^nb)
       a1 (stripes a0 (1024 * nb) ((n - 1 - 1024 * nb) // 64))
       a2 (stripe a1 (n - 64) 121)
       (ld-xav (ld-w (foldl (\ r i (r + ld-xf (ld-xor (a2 (2 * i)) (r64 k (11 + 16 * i)))
                                              (ld-xor (a2 (2 * i + 1)) (r64 k (19 + 16 * i)))))
                            (n * ld-xp1) ^4))))

   ;; --- merging: an output section's SHF_MERGE inputs of one flags, entsize and, for strings,
   ;     align are one synthetic section at the first's place, each distinct piece once: 32
   ;     shards by the piece's hash, first-seen within each, laid at the group's final align.
   ;     a section a .rel or .rela targets is laid whole, as lld lays it: its pieces differ only
   ;     once relocated. answers 'ms id -> {'size 'align 'flags 'entsize 'type 'tab piece -> off}
   ;     and 'im isec key -> [id starts offs], two trays by piece
   (ld-pieces s off size e str)
    (: end (off + size)
       (zero? i) (: (go k) (? (k >= e) 1 (s (i + k) != 0) 0 (go (k + 1))) (go 0))
       (go i st acc)
        (? (i >= end) (rev (? (st < end) ([st end] . acc) acc))
           !str (go (i + e) (i + e) ([i (i + e)] . acc))
           (zero? i) (go (i + e) (i + e) ([st (i + e)] . acc))
           (go (i + e) st acc))
       (go off off ()))
   (ld-merge ot outs)
    (: ms {} im {} nid {'n 0}
       rt (: t {}
             (aim oi si) (: r (ot oi 'sec si) (? (elem (r 1) '(4 9)) (pin t (oi * 65536 + r 8) 1) 0))
             _ (each (keys ot) (oi \ each >^(ot oi 'shnum) (aim oi)))
             t)
       (one t)
        (: cur {'l ()}
           (find k) (: (go l) (? (atom? l) -1 (<(<l) = k) (<>(<l)) (go >l)) (go (cur 'l)))
           (fresh k r) (: id (nid 'n)
                          _ (pin nid 'n (id + 1), pin cur 'l ([k id] . cur 'l))
                          _ (pin ms id {'size 0 'align (r 5) 'flags (r 2) 'entsize (r 6)
                                        'type (r 1) 'tab {} 'sh {}})
                          id)
           (step acc x)
            (? (<x != 'isec) (x . acc)
               (: oi (x 1) si (x 2) ob (ot oi) r (ob 'sec si) fl (r 2)
                  (? (0 = (fl & 16) || r 6 = 0 || peep rt (oi * 65536 + si) 0) (x . acc)
                     (: str (0 < (fl & 32))
                        k [fl (r 6) (? str (r 5) 0)]
                        f (find k)
                        id (? (f >= 0) f (fresh k r))
                        m (ms id) tab (m 'tab) src (ob 'src)
                        _ (pin m 'align (max (m 'align) (r 5)))
                        e (r 6)
                        ; the hash leaves a string's terminator out
                        (place p) (: key (snip src <p <>p)
                                     _ (? (peep tab key ()) ()
                                          (: h (ld-xxh (? str (snip src <p (<>p - e)) key)) k (h % ld-m32 // 134217728)
                                             (pin tab key 1, pin (m 'sh) k (key . peep (m 'sh) k ()))))
                                     [(<p - r 3) key])
                        _ (pin im (oi * 65536 + si) [id (map place (ld-pieces src (r 3) (r 4) (r 6) str))])
                        (? (f >= 0) acc (['msec id] . acc))))))
           (pin t 'steps (rev (foldl step () (t 'steps)))))
       _ (each outs one)
       (lay m) (: a (m 'align) tab (m 'tab)
                  (put1 o key) (: q (ld-al o a) _ (pin tab key q) (q + #key))
                  (shard o k) (: l (peep (m 'sh) k ()) (? (two? l) (foldl put1 (ld-al o a) (rev l)) o))
                  (pin m 'size (foldl shard 0 ^32)))
       _ (each (keys ms) (id \ lay (ms id)))
       _ (each (keys im) (k \ (: v (im k) tab (ms <v 'tab)
                                 (pin im k [<v (spread (map cap (v 1))) (spread (map (q \ tab (q 1)) (v 1)))]))))
       {'ms ms 'im im})

   ;; --- relocation. a -shared -Bsymbolic image binds every definition home, so an ABS64 in
   ;     an allocated section is a load-time slide: a RELR entry where the site is even in a
   ;     section aligned to 2 or more, else a RELATIVE in .rela.dyn whose field stays 0. a weak
   ;     undefined is an ABS64 against symbol 0. lk: {'cx 'ot 'env 'mx 'outs}
   (ld-isecs outs) (foldl (\ acc t (? (peep t 'dead 0 || t 'name = "/DISCARD/") acc
                                     (foldl (\ a x (? (<x = 'isec) (x . a) a)) acc (t 'steps))))
                          () outs)
   ; S + A for entry e of object oi, () for a weak undefined; a symbol in a section the
   ; link dropped is refused, or under dead answers 'dead, as a debug section's reference
   (ld-sa lk oi e) (ld-sad lk oi e 0)
   (ld-sad lk oi e dead)
    (: ob (lk 'ot oi) sy (ob 'syms (e 2)) sh (sy 3) a (e 3) env (lk 'env) at (env 'at)
       (none u) (? dead 'dead (scare 'link-dropped [(ob 'id) <sy]))
       (? (sy 2 = 3) (: v (at oi sh (sy 4 + a)) (? (whole? v) v (none 0)))
          (sy 1 = 0 && sh != 0)
           (? (sh = 65521) (sy 4 + a) (: v (at oi sh (sy 4)) (? (whole? v) (v + a) (none 0))))
          (: v (peep (env 'sv) <sy ()) g (? (whole? v) v ((env 'gv) <sy))
             (? (whole? g) (g + a)
                (sy 1 = 2) ()
                (scare 'link-undef [(ob 'id) <sy])))))
   ; an entry's symbol absolute as lld's isAbsolute sees it: SHN_ABS, or a script's symbol
   ; outside every section. env () is before layout, when a script's symbols count relative
   (ld-absym? lk env oi e)
    (: ob (lk 'ot oi) sy (ob 'syms (e 2))
       (? (sy 2 = 3 || sy 1 = 0) (sy 3 = 65521)
          (: v (? (env = ()) () (peep (env 'sv) <sy ()))
             (? (whole? v) (: q (peep (env 'ssec) <sy ()) !(string? q || q = 'aether))
                (: g (peep (lk 'cx 'glob) <sy ())
                   (? (two? g) (lk 'ot <g 'syms (g 1) 3 = 65521) 0))))))
   ; the dynamic sites: {'relr [[key ro] ..] 'rela [[key entry weak?] ..]}, in input order.
   ; a -pie's weak undefined is absolute, and a site in a read-only section wants -z notext
   (ld-dynsites lk env)
    (: relr {'l ()} rela {'l ()}
       (wu? ob e) (: sy (ob 'syms (e 2))
                     (sy 1 = 2 && sy 3 = 0 && atom? (peep (lk 'cx 'glob) <sy ())))
       (one x)
        (: oi (x 1) si (x 2) ob (lk 'ot oi) r (ob 'sec si) key (oi * 65536 + si)
           (each (? (0 < (r 2 & 2)) (ld-relas ob si) ())
              (e \ (? (e 1 != peep lk 'abs 257) 0
                      (wu? ob e) (? (peep lk 'pie 0) 0 (pin rela 'l ([key e 1] . rela 'l)))
                      (ld-absym? lk env oi e) 0
                      (0 = (r 2 & 1) && !(peep lk 'notext 0)) (scare 'link-textrel [(ob 'id) <r <e])
                      (peep lk 'relr 1 && r 5 >= 2 && <e % 2 = 0) (pin relr 'l ([key <e] . relr 'l))
                      (pin rela 'l ([key e 0] . rela 'l))))))
       _ (each (rev (ld-isecs (lk 'outs))) one)
       {'relr (rev (relr 'l)) 'rela (rev (rela 'l))})
   ; sorted addresses -> RELR words: an address, then bitmaps of the 63 words after it
   (ld-relr as)
    (: (bits l base bm)
        (? (atom? l) [bm l]
           (: d (<l - base)
              (? (d < 0 || d >= 504 || d % 8 != 0) [bm l]
                 (bits >l base (bm + 2 ** (d // 8))))))
       (maps l base acc)
        (: r (bits l base 0)
           (? (<r = 0) (start l acc)
              (maps <>r (base + 504) ((<r * 2 + 1) . acc))))
       (start l acc) (? (atom? l) (rev acc) (maps >l (<l + 8) (<l . acc)))
       (start as ()))

   ;; --- a -shared image's dynamic tables, as lld lays them under a version script of one
   ;     node exporting a list, the rest local. (ld-dso cx opts vtext) plans them before
   ;     layout, opts {'soname 'symbolic 'bti}: 'exports, 'syms the exported names in
   ;     .gnu.hash's bucket order, 'synth their sections, 'slink their sh_link and sh_info.
   ;     (ld-dsdata lk) answers their bytes once laid, for lk 'sdata
   (ld-ehash s) (foldl (\ h i (: x ((h * 16 + s i) % 4294967296) ((x ^ ((x >> 28) << 4)) & 268435455))) 0 ^#s)
   (ld-ghash s) (foldl (\ h i ((h * 33 + s i) % 4294967296)) 5381 ^#s)
   (ld-words t) (: n #t
                   (go i st acc) (? (i >= n) (rev (? (st < i) (snip t st i . acc) acc))
                                    (lds-sp? (t i)) (go (i + 1) (i + 1) (? (st < i) (snip t st i . acc) acc))
                                    (go (i + 1) st acc))
                   (go 0 0 ()))
   ; with no version script (opts 'flat) every definition of default or protected
   ; visibility is exported, unversioned, and the table carries no soname; a -pie's exports none
   (ld-dso cx opts vt)
    (: ws (ld-words vt)
       pie (peep opts 'pie 0)
       fl (peep opts 'flat 0 || pie)
       vn <ws
       (gs l on acc) (? (atom? l) (rev acc) (<l = "global:") (gs >l 1 acc) (<l = "local:") (gs >l 0 acc)
                        (on && <l != ";") (gs >l on (<l . acc)) (gs >l on acc))
       ex (: t {} _ (each (gs >ws 0 ()) (n \ pin t n 1)) t)
       (vis? n) (: g (peep (cx 'glob) n ())
                   (? (two? g) (: v ((cx 'objs) <g 'syms (g 1) 6 & 3) (v = 0 || v = 3)) 0))
       ds (? pie () (filter (n \ (? fl (vis? n) (peep ex n 0 && two? (peep (cx 'glob) n ())))) (cx 'order)))
       nb (max (#ds // 4) 1)
       syms (map (p \ p 2) (sort (map (i \ [(ld-ghash (ds i) % nb) i (ds i)]) ^#ds)))
       ; the version base is named by -soname, else by the output as given, and with no
       ; -soname no DT_SONAME; each name's offset is by when it was added, before the hash sort
       so (opts 'soname) base (? (string? so) so (opts 'out))
       st {'n 1}
       _ (each (ds + (? fl () [base vn])) (s \ (? (whole? (peep st s ())) 0 (: _ (pin st s (st 'n)) (pin st 'n (st 'n + #s + 1))))))
       mw ((: (go p) (? (p > #syms * 12 // 64) p (go (p * 2)))) 1)
       n (#syms + 1)
       d {'exports ex 'syms syms 'vn vn 'soname so 'base base 'str st 'nb nb 'mw mw 'flat fl 'pie pie
          'symbolic (peep opts 'symbolic 0) 'bti (peep opts 'bti 0) 'notext (peep opts 'notext 0)
          'slink {".hash" [".dynsym" 0] ".gnu.hash" [".dynsym" 0] ".dynsym" [".dynstr" 1] ".gnu.version" [".dynsym" 0]
                  ".gnu.version_d" [".dynstr" 2] ".dynamic" [".dynstr" 0]}}
       _ (? pie (pin (d 'slink) ".rela.dyn" [".dynsym" 0]) 0)
       ; in lld's order of creation, which orders the orphans of one rank; .dynamic's size is
       ; its tags', ld-dtags once laid
       (pin d 'synth
            ([[".dynsym" (24 * n) 8 11 2 24]]
             + (? fl () [[".gnu.version" (2 * n) 2 1879048191 2 2] [".gnu.version_d" 56 4 1879048189 2 0]])
             + [[".gnu.hash" (16 + 8 * mw + 4 * nb + 4 * #syms) 8 1879048182 2 0] [".hash" (4 * (2 + 2 * n)) 4 5 2 4]
                [".dynamic" (16 * #(ld-dtags d {})) 8 6 3 16] [".dynstr" (st 'n) 1 3 2 0]
                [".got" 0 8 1 3 0 1] [".got.plt" 0 8 1 3 0 1] [".plt" 0 16 1 6 0 1] [".iplt" 0 16 1 6 0 1]])))
   ; a symbol's value, a script's first
   (ld-symv env n) (: v (peep (env 'sv) n ()) (? (whole? v) v ((env 'gv) n)))
   ; .dynamic's tags in lld's order. q: 'rela 'relc 'relr counts, 'arrs the array and init tags
   (ld-dtags d q)
    (: fl (d 'flat) so (d 'soname) f ((? (d 'symbolic) 2 0) | (? (d 'notext) 4 0))
       (cats [(? (fl || !(string? so)) () [[14 'soname]]) (? (f = 0) () [[30 f]])
              (? (d 'pie) [[1879048187 134217728] [21 0]] ())
              (? (peep q 'rela 0 = 0) ()
                 ([[7 ".rela.dyn"] [8 'relasz] [9 24]] + (? (peep q 'relc 0 = 0) () [[1879048185 'relacount]])))
              (? (peep q 'relr 0 = 0) () [[36 ".relr.dyn"] [35 'relrsz] [37 'relrent]])
              (? (d 'bti) [[1879048193 0]] ())
              [[6 ".dynsym"] [11 'syment] [5 ".dynstr"] [10 'strsz]]
              (? (d 'notext) [[22 0]] ())
              [[1879047925 ".gnu.hash"] [4 ".hash"]]
              (peep q 'arrs ())
              (? fl () [[1879048176 ".gnu.version"] [1879048188 ".gnu.version_d"] [1879048189 'nverdef]])
              [[0 0]]]))
   (ld-dsdata lk)
    (: d (lk 'dso) env (lk 'env) isa (env 'isa) glob (lk 'cx 'glob) ot (lk 'ot) shx (ld-shx (lk 'outs))
       syms (d 'syms) st (d 'str) n (#syms + 1) nb (d 'nb) mw (d 'mw)
       (w2 v) (ld-le v 2) (w4 v) (ld-le v 4) (w8 v) (ld-le v 8)
       (dsym nm) (: g (glob nm) oi <g r (ot oi 'syms (g 1)) sh (r 3)
                    shn (? (sh = 65521) 65521 (shx (env 'osof (oi * 65536 + sh))))
                    (cats [(w4 (st nm)) [(r 1 * 16 + r 2) 0] (w2 shn) (w8 ((env 'gv) nm)) (w8 (r 5))]))
       ; .hash: a bucket per symbol, chained newest first
       hb {} hc {}
       _ (each (ld-zip syms) (p \ (: i (<p + 1) h (ld-ehash (p 1) % n)
                                    _ (pin hc i (peep hb h 0)) (pin hb h i))))
       sysv (cats [(w4 n) (w4 n) (cats (map (i \ w4 (peep hb i 0)) ^n)) (cats (map (i \ w4 (peep hc i 0)) ^n))])
       ; .gnu.hash: one bloom word per 64 bits, two bits a name; the chain's low bit ends a bucket
       hs (map ld-ghash syms)
       bk (map (h \ h % nb) hs)
       bloom (foldl (\ t h (: k (h // 64 % mw) (pin t k (ld-or (peep t k 0) (ld-or (2 ** (h % 64)) (2 ** ((h >> 26) % 64)))))))
                    {} hs)
       first (: t {} _ (each (rev (ld-zip bk)) (p \ pin t (p 1) (<p + 1))) t)
       gh (cats [(w4 nb) (w4 1) (w4 mw) (w4 26) (cats (map (i \ w8 (peep bloom i 0)) ^mw))
                 (cats (map (b \ w4 (peep first b 0)) ^nb))
                 (cats (map (i \ w4 (hs i // 2 * 2 + (? (i + 1 = #hs || bk (i + 1) != bk i) 1 0))) ^#hs))])
       strs (sort (map (k \ [(st k) k]) (filter string? (keys st))))
       dstr (cats ([0] . map (p \ map (p 1) ^#(p 1) + [0]) strs))
       vd (? (d 'flat) () (cats [(w2 1) (w2 1) (w2 1) (w2 1) (w4 (ld-ehash (d 'base))) (w4 20) (w4 28) (w4 (st (d 'base))) (w4 0)
                 (w2 1) (w2 0) (w2 2) (w2 1) (w4 (ld-ehash (d 'vn))) (w4 20) (w4 0) (w4 (st (d 'vn))) (w4 0)]))
       osv (env 'osv)
       (dv k) (? (whole? k) k (string? k) (isa k) (two? k) (? (<k = 'osa) <(osv (k 1)) (<k = 'osz) (osv (k 1) 1) (ld-symv env (k 1)))
                 (k = 'soname) (st (d 'soname)) (k = 'syment) 24
                 (k = 'strsz) (st 'n) (k = 'nverdef) 2 (k = 'relrsz) (peep d 'relrsz 0) (k = 'relrent) 8
                 (k = 'relasz) (peep d 'relasz 0) (k = 'relacount) (peep d 'relacount 0) 0)
       dyn (cats (map (e \ w8 <e + w8 (dv (e 1))) (d 'dt)))
       one (\ b [#b [b]])
       {".hash" (one sysv) ".gnu.hash" (one gh) ".dynsym" (one (cats ((ld-le 0 24) . map dsym syms)))
        ".dynstr" (one dstr) ".gnu.version" (one (cats ((w2 0) . map (s \ w2 2) syms)))
        ".gnu.version_d" (one vd) ".dynamic" (one dyn)})

   ;; --- emission. pieces are texts and byte lists, laid in file order
   ld-z64 (cask (ld-zeros 65536))
   (ld-zp n acc) (? (n <= 0) acc (n <= 65536) (snip ld-z64 0 n . acc) (ld-zp (n - 65536) (ld-z64 . acc)))
   ; pieces gathered to blocks for f, a text at a time: a write(2) each is a kernel's .strtab's
   ; whole cost. -> [add flush]; add takes a text or a cask
   (ld-blocks f)
    (: st {'j (jug 0) 'n 0}
       (fl u) (? (st 'n = 0) 0 (: s (slurp (st 'j)) _ (pin st 'j (jug 0), pin st 'n 0) (f s)))
       (add p) (? (#p < 1048576)
                  (: _ (say (st 'j) p, pin st 'n (st 'n + #p)) (? (st 'n < 1048576) 0 (fl 0)))
                  (: _ (fl 0) (f (? (string? p) p (string p)))))
       [add fl])
   ; n's low w bytes, little-endian; one split into 32-bit halves, then shifts
   (ld-le n w)
    (: u (ld-w n) lo (u % 4294967296) hi (u // 4294967296)
       (map (i \ (? (i < 4) ((lo >> (8 * i)) & 255) (i < 8) ((hi >> (8 * (i - 4))) & 255) 0)) ^w))
   ; v laid over 4 or 8 bytes of a cask
   (ld-pin4 b o v) (pin b o (v & 255), pin b (o + 1) (v >> 8 & 255), pin b (o + 2) (v >> 16 & 255), pin b (o + 3) (v >> 24 & 255))
   (ld-pin8 b o v) (: u (ld-w v) _ (ld-pin4 b o (u % 4294967296)) (ld-pin4 b (o + 4) (u // 4294967296)))
   ; .rela.dyn: RELATIVE first, then the weak ABS64s, each by address
   (ld-rela lk dy)
    (: isa (lk 'env 'isa) x64 (peep lk 'mach 183 = 62)
       es (map (r \ (: k <r e (r 1) p (isa k + <e)
                     (? (r 2) [1 p (? x64 1 257) (e 3)] [0 p (? x64 8 1027) (ld-sa lk (k // 65536) e)])))
               (dy 'rela))
       (map (x \ ld-le (x 1) 8 + ld-le (x 2) 8 + ld-le (x 3) 8) (sort es)))
   ; what a non-alloc section's absolute reference to a dropped section reads, as lld
   ; writes it: a debug section's tombstone, the addend elsewhere
   (ld-tomb nm a) (? (elem nm '(".debug_loc" ".debug_ranges")) 1 (nm = ".debug_names") (ld-m64 - 1)
                     (ld-debug? nm) 0 a)
   ; one input section's bytes with its relocations applied -> pieces, reversed onto acc
   (ld-patch lk x acc)
    (: oi (x 1) si (x 2) r (lk 'ot oi 'sec si)
       (? (elem (r 1) '(4 9)) (ld-erela lk oi (r 8) acc)
          (ld-patchr lk oi si 0 (r 4) (lk 'env 'isa (oi * 65536 + si)) acc)))
   ; bytes from to to of input section si, relocated as laid at base + from
   (ld-patchr lk oi si from to base acc)
    (: ob (lk 'ot oi) r (ob 'sec si) s (ob 'src) o0 (r 3) sz to
       mach (peep lk 'mach 183) abs (peep lk 'abs 257)
       be (backends (? (mach = 62) 'x64 'a64))
       ; a weak undefined: a branch falls to the next instruction, a pc-relative field reads
       ; the place, an absolute one the addend
       (weak k p a) (? (elem k '(279 280 282 283)) (p + 4 + a) (elem k '(260 261 273 274 275)) (p + a) a)
       ; S+A and P as lld's uint64 arithmetic sees them: S+A the value nearest P mod 2^64,
       ; both lifted a turn should it fall below 0, so pages divide as they would unsigned
       (near p0 s0) (: v (p0 + ld-s64 (ld-w (s0 - p0))) (? (v < 0) [(v + ld-m64) (p0 + ld-m64)] [v p0]))
       nal (0 = (r 2 & 2))
       ; i386's REL: the addend is the field's, sign-extended at its width
       i386 (mach = 3)
       (imp e) (: w <(ld-rk 3 (e 1)) v (rdle s (o0 + <e) w) h (2 ** (8 * w - 1))
                  [<e (e 1) (e 2) (? (v >= h) (v - 2 * h) v)])
       (field e0) (: e (? i386 (imp e0) e0) ro <e k (e 1) p0 (base + ro) s0 (ld-sad lk oi e nal)
                    q (? (whole? s0) (near p0 s0) [(weak k p0 (e 3)) p0])
                    sa <q p <>q
                    (? (s0 = 'dead) (? (elem k '(257 258)) (ld-le (ld-tomb <r (e 3)) (? (k = 257) 8 4))
                                       (i386 && k = 1) (ld-le (ld-tomb <r (e 3)) 4)
                                       (scare 'link-dropped [(ob 'id) ro k]))
                       (k = abs && nal) (ld-le sa 8)               ; not loaded: no slide
                       (k = abs)
                       (? (!(whole? s0)) (ld-le (? (peep lk 'shared 1) 0 sa) 8)         ; -shared binds it at load
                          (peep lk 'etype 3 = 2) (ld-le sa 8)                            ; ET_EXEC: nothing slides
                          (ld-absym? lk (lk 'env) oi e) (ld-le sa 8)
                          (peep lk 'relr 1 && r 5 >= 2 && ro % 2 = 0) (ld-le sa 8)       ; relr: the field is the addend
                          (ld-le (? (peep lk 'apply 0) sa 0) 8))
                       ; a narrower absolute can't slide: lld wants -fPIC
                       (!nal && peep lk 'etype 3 = 3 && whole? s0 && elem [mach k] '((62 10) (62 11) (62 12) (62 14) (183 258))
                        && !(ld-absym? lk (lk 'env) oi e))
                        (scare 'link-pic [(ob 'id) ro k])
                       (: c (peep (ld-rtab mach) k ())
                          _ (? (two? c) 0 (scare 'link-reloc [(ob 'id) k]))
                          f (ld-fix be c (map (i \ s (o0 + ro + i)) ^4) sa p)
                          (? (two? f) f (scare 'link-range [(ob 'id) ro k])))))
       ; lld's relaxation: adrp xn, sym; add xn, xn, :lo12:sym, neither addended, sym within
       ; 1 MiB of the add -> nop; adr xn, sym. answers the 8 bytes, or ()
       (relax e f)
        (: ro <e i1 (rle32 s (o0 + ro)) i2 (rle32 s (o0 + ro + 4)) rd (i1 % 32)
           (? (e 1 = 275 && two? f && f 1 = 277 && <f = ro + 4 && e 2 = f 2 && e 3 = 0 && f 3 = 0
               && (i1 & 2667577344) = 2415919104 && (i2 & 4290772992) = 2432696320
               && i2 % 32 = rd && (i2 >> 5) % 32 = rd)
              (: v0 (ld-sa lk oi e) q (? (whole? v0) (near (base + ro + 4) v0) [() 0]) v <q p <>q
                 (? (whole? v && -1048576 <= v - p && v - p < 1048576)
                    (ld-le 3573751839 4 + refix-with be 'adr21 (ld-le (268435456 + rd) 4) v p 4)
                    ()))
              ()))
       ; under a writer's sink the pieces leave every 4096 fields, not held to the end. the
       ; relocations come off a cursor 4096 at a time, one ahead kept for relax
       sink (peep lk 'sink ())
       cur (ld-relcur ob si)
       (more es) (? (two? es && two? >es) es (: m (ld-relnext cur 4096) (? (atom? m) es (es + m))))
       (go pos es0 acc c)
        (: es (more es0)
         (? (atom? es || <(<es) >= to) (snip s pos (o0 + sz) . acc)
           (<(<es) < from) (go pos >es acc c)
           (c > 4095 && sink != ()) (: _ (sink acc) (go pos es () 0))
           (: e <es x (relax e (? (two? >es) <(>es) ()))
              (? (two? x) (go (o0 + <e + 8) >(>es) (x . snip s pos (o0 + <e) . acc) (c + 1))
                 (: b (field e)
                    (go (o0 + <e + #b) >es (b . snip s pos (o0 + <e) . acc) (c + 1)))))))
       (? (r 1 = 8) (ld-zp (to - from) acc) (go (o0 + from) () acc 0)))
   ;; --- .eh_frame as lld lays it: each input's records split, a CIE once by its bytes and
   ;     personality, in the order first seen, each followed by the FDEs whose function's
   ;     section is laid, then a zero terminator. the inputs give way to one synthetic
   ;     .eh_frame in the first's place. answers {'recs [cie [fde ..]] .. 'size 'nf}, () with no .eh_frame
   (ld-eh cx os)
    (: ot (: t {} _ (foldl (\ i ob (pin t i ob, i + 1)) 0 (cx 'objs)) t) glob (cx 'glob)
       kept (filter (t \ t 'name != "/DISCARD/") os)
       live {}
       _ (each kept (t \ each (t 'steps) (x \ (? (<x = 'isec) (pin live (x 1 * 65536 + x 2) 1) 0))))
       (eh? x) (<x = 'isec && x 5 = ".eh_frame" && elem (ot (x 1) 'sec (x 2) 1) '(1 1879048193))
       (at? oi sh) (0 < sh && sh < 65280 && peep live (oi * 65536 + sh) 0)
       ; the symbol a relocation names: a global by its name, a local by its place
       (who oi e) (: sy (ot oi 'syms (e 2)) (? (sy 1 = 0) [oi (e 2)] <sy))
       (live? oi e) (: sy (ot oi 'syms (e 2))
                       (? (sy 1 = 0) (at? oi (sy 3))
                          (: g (peep glob <sy ()) (? (two? g) (at? <g (ot <g 'syms (g 1) 3)) 0))))
       (split oi si)
        (: ob (ot oi) r (ob 'sec si) s (ob 'src) o0 (r 3) n (r 4)
           (go p acc) (? (p + 4 > n) (rev acc)
                         (: len (rle32 s (o0 + p))
                            (? (len = 0) (rev acc) (len = 4294967295) (scare 'link-eh64 (ob 'id))
                               (go (p + 4 + len) ([p (p + 4 + len) (rle32 s (o0 + p + 4))] . acc)))))
           (go 0 ()))
       rc {}
       (rels oi si) (: k (oi * 65536 + si) _ (? (peep rc k 0 = 0) (pin rc k (ld-relas (ot oi) si)) 0) (rc k))
       (first oi si a b) (: es (filter (e \ a <= <e && <e < b) (rels oi si))
                            (? (atom? es) () <(sort es)))
       cies {} order {'l ()} nf {'n 0}
       (one x)
        (: oi (x 1) si (x 2) rs (split oi si) src (ot oi 'src) o0 (ot oi 'sec si 3) loc {}
           _ (each (filter (q \ q 2 = 0) rs)
               (q \ (: f (first oi si <q (q 1))
                        k (snip src (o0 + <q) (o0 + q 1) + "\0" + show (? (f = ()) () (who oi f)))
                        c (peep cies k ())
                        c2 (? (c != ()) c (: c {'cie [oi si <q (q 1)] 'fdes {'l ()}}
                                              _ (pin cies k c, pin order 'l (c . order 'l)) c))
                        (pin loc <q c2))))
           (each (filter (q \ q 2 != 0) rs)
              (q \ (: c (peep loc (<q + 4 - q 2) ())
                       _ (? (c = ()) (scare 'link-eh-cie (ot oi 'id)) 0)
                       f (first oi si <q (q 1))
                       (? (f != () && live? oi f)
                          (: _ (pin (c 'fdes) 'l ([oi si <q (q 1) f] . c 'fdes 'l)) (pin nf 'n (nf 'n + 1)))
                          0)))))
       ins (cats (map (t \ filter eh? (t 'steps)) kept))
       _ (each ins one)
       recs (map (c \ [(c 'cie) (rev (c 'fdes 'l))]) (rev (order 'l)))
       size (foldl (\ a c (foldl (\ b f (b + f 3 - f 2)) (a + <c 3 - <c 2) (c 1))) 0 recs)
       (? (atom? ins) ()
          (: fst <ins
             _ (each kept (t \ pin t 'steps
                                 (foldr (\ x acc (? !(eh? x) (x . acc)
                                                     (x = fst) (['synth ".eh_frame" 0 8 ".eh_frame"] . acc)
                                                     acc))
                                        () (t 'steps))))
             {'recs recs 'size (size + 4) 'nf (nf 'n)})))
   ; .eh_frame's bytes laid at a, and under hv its header's laid at hv
   (ld-ehbytes lk eh a hv)
    (: (w4 v) (ld-le (v % 4294967296) 4)
       pos {'o 0} pcs {'l ()} acc {'l ()}
       (put oi si from to at) (pin acc 'l (ld-patchr lk oi si from to (at - from) (acc 'l)))
       _ (each (eh 'recs)
           (c \ (: cie <c co (pos 'o) _ (put (cie 0) (cie 1) (cie 2) (cie 3) (a + co))
                    _ (pin pos 'o (co + cie 3 - cie 2))
                    (each (c 1)
                       (f \ (: fo (pos 'o) oi <f si (f 1) p (f 2) q (f 3)
                                _ (put oi si p (p + 4) (a + fo))
                                _ (pin acc 'l (w4 (fo + 4 - co) . acc 'l))
                                _ (put oi si (p + 8) q (a + fo + 8))
                                _ (pin pcs 'l ([(ld-sa lk oi (f 4)) (a + fo)] . pcs 'l))
                                (pin pos 'o (fo + q - p))))))))
       body (rev (w4 0 . acc 'l))
       ; the header: version, its encodings, .eh_frame's place, then the FDEs by pc, one a pc
       ps (rev (pcs 'l))
       srt (map (x \ x 2) (sort (map (i \ [(<(ps i)) i (ps i)]) ^#ps)))
       (uq l) (? (atom? l || atom? >l) l (<(<l) = <(<(>l))) (uq (<l . >(>l))) (<l . uq >l))
       tab (uq srt)
       hdr (cats ([[1 27 3 59] (w4 (a - hv - 4)) (w4 #tab)] + map (x \ w4 (<x - hv) + w4 (x 1 - hv)) tab
                  + [(ld-zeros (8 * (eh 'nf - #tab)))]))
       [body hdr])

   ; a merge section's bytes: its pieces by offset, the gaps zero
   (ld-mbytes m acc)
    (: t (m 'tab) ps (sort (map (k \ [(t k) k]) (keys t)))
       (go l cur acc) (? (atom? l) (ld-zp (m 'size - cur) acc)
                         (: o <(<l) k <>(<l) (go >l (o + #k) (k . ld-zp (o - cur) acc))))
       (go ps 0 acc))
   ; an output section's pieces; lk 'sdata synthetic name -> [size pieces], lk 'patch an
   ; input section's bytes, ld-patch by default
   (ld-emit lk t)
    (: env (lk 'env) isa (env 'isa) ms (lk 'mx 'ms) end (t 'va + t 'sz)
       ; the bytes from c to e: the section's fill, big-endian from its start, else zeros
       fp (: f (peep t 'fill ()) (? (whole? f) (rev (ld-le f 4)) ()))
       ; a writer's sink takes an input section's pieces as they come
       sink (peep lk 'sink ())
       (flow acc) (? (sink = ()) acc (: _ (sink acc) ()))
       (gap c e acc) (? (atom? fp) (ld-zp (e - c) acc) (e <= c) acc
                        ((map (i \ fp ((c + i - t 'va) % 4)) ^(e - c)) . acc))
       (go l cur acc)
        (? (atom? l) (rev (gap cur end acc))
           (: x <l k <x
              (? (k = 'isec) (: a (isa (x 1 * 65536 + x 2))
                                (go >l (a + x 3) (flow ((peep lk 'patch ld-patch) lk x (gap cur a acc)))))
                 (k = 'synth && !(whole? (peep isa (x 1) ()))) (go >l cur acc)
                 (k = 'synth) (: a (isa (x 1)) d (lk 'sdata (x 1))
                                 (go >l (a + <d) (rev <>d + gap cur a acc)))
                 (k = 'msec) (: m (ms (x 1)) a (env 'msa (x 1))
                                (go >l (a + m 'size) (ld-mbytes m (gap cur a acc))))
                 (k = 'data) (: _ (pin env 'dot cur) (go >l (cur + x 1) (ld-le (ld-ev env (x 2)) (x 1) . acc)))
                 (k = 'set && x 1 = ".")
                  (: _ (pin env 'dot cur) v (ld-aop (x 2) cur (ld-ev env (x 3)))
                     (go >l v (gap cur v acc)))
                 (go >l cur acc))))
       (? (t 'stype = 8) () (go (t 'steps) (t 'va) ())))

   ;; --- the symbol table as lld writes it. the script's names enter after the objects':
   ;     the names its expressions read (not a PROVIDE's, nor a section name), then the
   ;     right sides of the PROVIDEs it takes, then the names it assigns
   (ld-sorder lk)
    (: cmds (lk 'cmds) und (lk 'cx 'und) sv (lk 'env 'sv)
       flat (foldr (\ c acc (? (<c = 'sections) (<>c + acc) (c . acc))) () cmds)
       (ex e acc)
        (? (string? e) (? (e = ".") acc (e . acc))
           (atom? e) acc
           (<e = 'call) (? (elem (e 1) '("ADDR" "SIZEOF" "LOADADDR" "ALIGNOF" "DEFINED" "CONSTANT" "SEGMENT_START")) acc
                           (foldl (\ a x (ex x a)) acc (e 2)))
           (foldl (\ a x (ex x a)) acc >e))
       (taken? c) (peep und (c 1) 0 > 0)
       (walk f l acc) (foldl (\ a c (? (<c = 'osec) (: t <>c (walk f (t 'body) (f ['hdr t] a))) (f c a))) acc l)
       (reads c a) (? (<c = 'set) (ex (c 3) a) (<c = 'assert) (ex (c 1) a) (<c = 'data) (ex (c 2) a)
                      (<c = 'hdr) (: t (c 1) (ex (t 'align) (ex (t 'lma) (ex (t 'addr) a))))
                      a)
       (provs c a) (? (<c = 'provide && taken? c) (ex (c 2) a) a)
       (sets c a) (? (<c = 'set && c 1 != ".") ((c 1) . a) (<c = 'provide && taken? c) ((c 1) . a) a)
       (rev (walk sets flat (walk provs flat (walk reads flat ())))))
   ; -> [nlocal entries strsize strpieces]; shx output section name -> its index
   (ld-symtab lk shx)
    (: cx (lk 'cx) ot (cx 'ot) env (lk 'env) sv (env 'sv) ssec (env 'ssec)
       osof (env 'osof) mof (env 'mof) im (lk 'mx 'im) at (env 'at) glob (cx 'glob) und (cx 'und)
       str (ld-strtab 0)
       (oname oi sh) (: k (oi * 65536 + sh) n (peep osof k ())
                        (? (string? n) n (: m (peep im k ()) (? (two? m) (peep mof <m ()) ()))))
       (ent nm v z info oth shn) [(ld-stradd str nm) v z info oth shn]
       ; an entry keyed for --emit-relocs: an object symbol, ('sec name), or a name
       (ky k e) (e + [k])
       (sk oi si) (oi * 16777216 + si)
       erel (peep lk 'erel 0)
       groups {} gord {'l ()} glo {'l ()}
       (put oi e) (: g (peep groups oi ())
                     _ (? (two? g) 0 (pin gord 'l (oi . gord 'l)))
                     (pin groups oi (e . g)))
       ; a local a copied .rela names stays, .L or not
       used (: u {}
               _ (? (erel && lk 'discard != 'none)
                    (each (lk 'outs)
                       (t \ each (t 'steps)
                             (x \ (? (<x = 'isec && elem (ot (x 1) 'sec (x 2) 1) '(4 9))
                                     (each (ld-relas (ot (x 1)) (ot (x 1) 'sec (x 2) 8)) (e \ pin u (sk (x 1) (e 2)) 1)) 0))))
                    0)
               u)
       _ (each ^(cx 'n)
           (oi \ (: ob (ot oi) sy (ld-symr ob)
                    (each >^(ld-nloc ob)
                       (si \ (: r (sy si)
                                (? (r 1 != 0 || r 2 = 3 || r 3 = 0) 0
                                   ; .L: all under -X, else those in a merge section, as lld drops them; none under --discard-none
                                   (starts? <r ".L" && lk 'discard != 'none && !(peep used (sk oi si) 0)
                                    && (lk 'discard = 'locals || (r 3 < 65280 && 0 < (ob 'sec (r 3) 2 & 16)))) 0
                                   (r 3 = 65521) (put oi (ky (sk oi si) (ent <r (r 4) (r 5) (r 2) 0 65521)))
                                   (: n (oname oi (r 3)) q (ob 'sec (r 3))
                                      (? (string? n) (put oi (ky (sk oi si) (ent <r (at oi (r 3) (r 4)) (r 5) (r 2) 0 (shx n))))
                                         ; a debug section --strip-debug dropped leaves its locals absolute, at 0 in a merge section
                                         (lk 'strip && 0 = (q 2 & 2) && ld-debug? <q)
                                         (put oi (ky (sk oi si) (ent <r (? (0 < (q 2 & 16)) 0 (r 4)) (r 5) (r 2) 0 65521)))
                                         0)))))))))
       ; --emit-relocs: a section symbol for each output a relocation may point into, in ld-first's
       ; group, the script's outputs then the orphans as they were made
       _ (? erel
            (each (ld-live (peep lk 'sord (lk 'outs)))
               (t \ (: f (ld-first ot t)
                       (? (f = ()) 0 (put <f (ky ['sec (t 'name)] (ent "" (? (0 < (t 'flags & 2)) (t 'va) 0) 0 3 0 (shx (t 'name)))))))))
            0)
       seen {}
       names (rev (foldl (\ a n (? (peep seen n 0) a (: _ (pin seen n 1) (n . a)))) () (cx 'order + ld-sorder lk)))
       ; a -shared link's version script keeps its list global and makes the rest local, a
       ; script's own names a group after every object's; the default script's words are love ld's
       dso (peep lk 'dso 0)
       (loc? nm) (? (dso = 0 || dso 'flat) 0 !(peep (dso 'exports) nm 0))
       ; a name's visibility, the strictest any object gives it, a reference too; hidden or
       ; internal is local
       vtab {}
       _ (each ^(cx 'n)
           (oi \ ld-globs (ot oi)
              (\ si r (: v (r 6 % 4) w (peep vtab <r 0)
                         (? (v = 0) 0 (pin vtab <r (? (w = 0 || v < w) v w)))))))
       (gl nm)
        (: v (peep sv nm ())
           (? (whole? v && starts? nm "__ld_") 0
              (whole? v) (: q (peep ssec nm ()) ty (peep (env 'stype) nm 0) vs (peep vtab nm 0)
                            shn (? (q = 'aether) 1 (string? q) (shx q) 65521)
                            (? (loc? nm || vs = 1 || vs = 2) (put -1 (ky nm (ent nm v 0 ty vs shn)))
                               (pin glo 'l (ky nm (ent nm v 0 (16 + ty) vs shn) . glo 'l))))
              (: g (peep glob nm ())
                 (? (two? g)
                    (: oi <g r (ot oi 'syms (g 1)) vis (peep vtab nm (r 6 % 4)) n (oname oi (r 3))
                       vs (? (r 3 = 65521) [(r 4) 65521] (string? n) [(at oi (r 3) (r 4)) (shx n)] [0 0])
                       (? (vis = 1 || vis = 2 || loc? nm) (put oi (ky nm (ent nm <vs (r 5) (r 2) vis (vs 1))))
                          (pin glo 'l (ky nm (ent nm <vs (r 5) (r 1 * 16 + r 2) vis (vs 1)) . glo 'l))))
                    ; an undefined only -u named stays out, as lld leaves it
                    (peep und nm 0 > 0 && !(peep (cx 'uonly) nm 0)) (pin glo 'l (ky nm (ent nm 0 0 (und nm * 16) 0 0) . glo 'l))
                    0))))
       _ (each names gl)
       ; lld's _DYNAMIC, hidden at .dynamic, gone with it
       _ (? (dso = 0 || !(whole? (peep (env 'isa) ".dynamic" ()))) 0
            (: a (env 'isa ".dynamic") (put -1 (ent "_DYNAMIC" a 0 0 2 (shx (ld-holder lk a 'name))))))
       ; the erratum scan's section symbols, each at the end of its object's locals
       _ (each (peep lk 'a53 ()) (x \ (: oi <x si (x 1) (put oi (ent "" (at oi si 0) 0 3 0 (shx (oname oi si)))))))
       locs (cats (map (oi \ rev (groups oi)) (rev (gord 'l))))
       es (locs + rev (glo 'l))
       ; the index each keyed entry is written at, for --emit-relocs' entries to name
       _ (? erel
            (: li {} xi {} gi {}
               _ (foldl (\ i e (: k (? (#e > 6) (e 6) ())
                                  _ (? (whole? k) (pin li k i) (string? k) (pin gi k i) (two? k) (pin xi (k 1) i) 0)
                                  (i + 1)))
                        1 es)
               (: _ (pin lk 'lidx li) _ (pin lk 'sidx xi) (pin lk 'gidx gi)))
            0)
       w32 (peep lk 'mach 183 = 3)
       (row e) (cask (? w32 (ld-le <e 4 + ld-le (e 1) 4 + ld-le (e 2) 4 + [(e 3) (e 4)] + ld-le (e 5) 2)
                        (ld-le <e 4 + [(e 3) (e 4)] + ld-le (e 5) 2 + ld-le (e 1) 8 + ld-le (e 2) 8)))
       [(#locs + 1) ([(ld-le 0 (? w32 16 24))] + map row es) (str 'n) [(slurp (str 'j))]])

   ; the live output sections, and each one's section index
   (ld-live outs) (filter (t \ !(peep t 'dead 0) && t 'name != "/DISCARD/") outs)
   (ld-shx outs) (: t {} _ (foldl (\ i x (pin t (x 'name) i, i + 1)) 1 (ld-live outs)) t)
   ; the allocated output section an address falls in
   (ld-holder lk a) <(filter (t \ !(peep t 'dead 0) && 0 < (t 'flags & 2) && t 'va <= a && a < t 'va + t 'sz) (lk 'outs))

   ; the build-id, once ld-elf has written path: sha256's first 20 bytes over the file with
   ; the field still zero, written into the .note.gnu.build-id ld-elf left zero
   (ld-buildid lk path)
    (: a (lk 'env 'isa ".note.gnu.build-id")
       t (ld-holder lk a)
       off (t 'off + a - t 'va + 16)
       h (peep lk 'bidhash ())
       (d c) (? (c < 58) (c - 48) (c - 87))
       id (map (i \ d (h (2 * i)) * 16 + d (h (2 * i + 1))) ^20)
       (openfd path 4 @ fd
          (? (charm? fd && fd >= 0) (lseek fd off 0, fdopen fd @ q (say q (string id), close q), id)
             (scare 'link-buildid path))))

   ;; --- the image, as lld lays it: a PT_LOAD per run of sections with one set of
   ;     permissions, a new one at each AT(); an empty section opens none. under PHDRS the
   ;     script's headers instead, a section in those it names or else its predecessor's.
   ;     a load's first section sits at a file offset congruent to its address mod 64K, or
   ;     at the next aligned one under lk 'nmagic; the rest follow by address. each section
   ;     is written as it is emitted; answers the file's size
   ; the sections lld's relro covers
   ld-relro '(".data.rel.ro" ".dynamic" ".got" ".relro_padding")
   (ld-pt ty) (? (whole? ty) ty
                 (: l '(("PT_NULL" 0) ("PT_LOAD" 1) ("PT_DYNAMIC" 2) ("PT_INTERP" 3) ("PT_NOTE" 4) ("PT_PHDR" 6)
                        ("PT_TLS" 7) ("PT_GNU_EH_FRAME" 1685382480) ("PT_GNU_STACK" 1685382481) ("PT_GNU_RELRO" 1685382482))
                    r (filter (p \ <p = ty) l) n (ld-num ty)
                    (? (two? r) <>(<r) (whole? n) n (scare 'link-phdr ty))))
   ;     with no script (lk 'flat) as lld lays its own: a PT_PHDR, the first load from the
   ;     file's start, a load at each change of permissions or relro, the empty ones dropped
   ;     but their headers' room kept, then PT_DYNAMIC, PT_GNU_RELRO and PT_GNU_STACK, and
   ;     .shstrtab before .strtab
   (ld-elf lk entry path)
    (: outs0 (ld-live (lk 'outs))
       flat (peep lk 'flat 0) pg (peep lk 'pg 65536)
       ; the tables a script names sit after its sections, in its order; the orphans follow,
       ; then the rest as lld creates them, .symtab .shstrtab .strtab
       nmd (? flat () (map (c \ <>c 'name) (filter (c \ <c = 'osec) (ld-flat (lk 'cmds)))))
       tabn (filter (n \ elem n '(".symtab" ".strtab" ".shstrtab")) nmd)
       tabu (filter (n \ !(elem n tabn)) '(".symtab" ".shstrtab" ".strtab"))
       sc0 (filter (t \ !(peep t 'orph 0)) outs0) or0 (filter (t \ peep t 'orph 0) outs0)
       ordn (map (t \ t 'name) sc0 + tabn + map (t \ t 'name) or0 + tabu)
       shx (: t {} _ (foldl (\ i n (pin t n i, i + 1)) 1 ordn) t)
       st (ld-symtab lk (n \ shx n))
       w32 (peep lk 'mach 183 = 3) se (? w32 16 24)
       tabs {".symtab" {'name ".symtab" 'stype 2 'flags 0 'al (? w32 4 8) 'sz (se * #(st 1)) 'entsize se
                        'link (shx ".strtab") 'info <st 'pieces (st 1)}
             ".strtab" {'name ".strtab" 'stype 3 'flags 0 'al 1 'sz (st 2) 'pieces (st 3)}
             ".shstrtab" {'name ".shstrtab" 'stype 3 'flags 0 'al 1}}
       sht (tabs ".shstrtab")
       ; --emit-relocs' tables link .symtab and name their target, SHF_INFO_LINK always
       _ (each or0 (t \ (? (peep t 'tgt () = ()) 0 (: _ (pin t 'link (shx ".symtab")) _ (pin t 'flags (peep t 'flags 0 | 64)) (pin t 'info (peep shx (t 'tgt) 0))))))
       outs (sc0 + map tabs tabn + or0 + map tabs tabu)
       slink (peep lk 'slink {})
       nmagic (peep lk 'nmagic 0)
       (alloc? t) (0 < (t 'flags & 2))
       (perm t) (4 + (? (0 < (t 'flags & 1)) 2 0) + (? (0 < (t 'flags & 4)) 1 0))
       (at? t) (? (atom? (t 'lma)) (whole? (t 'lma)) 1)
       phr (foldl (\ a c (? (<c = 'phdrs) <>c a)) () (lk 'cmds))
       _ (foldl (\ pv t (? (alloc? t) (: ns (? (two? (peep t 'phdrs ())) (t 'phdrs) pv) _ (pin t 'phn ns) ns) pv)) () outs)
       (in p) (filter (t \ alloc? t && elem (p 'name) (t 'phn)) outs)
       ; a script with no PHDRS: lld's PT_GNU_RELRO over the relro run, a load opened past it
       rr (? (flat || two? phr || !(peep lk 'zrelro 0)) [() ()] (ld-relrun outs))
       rsec <rr
       rbrk (? (atom? (rr 1)) ()
               (: e <(rr 1) f (filter (t \ alloc? t && t 'sz > 0 && t 'va >= e 'va) outs) (? (atom? f) () (<f 'name))))
       ; loads [[first last row] ..], row the PHDRS one or ()
       grps (? flat (ld-fgroups outs0) ())
       loads (? (two? phr)
                (cats (map (p \ (: ms (in p) (? (ld-pt (p 'type) = 1 && two? ms) [[<ms <(rev ms) p]] ()))) phr))
                flat (map (g \ [<g (g 1) ()]) (filter (g \ g 2) grps))
                (rev (foldl (\ acc t
                               (? (!(alloc? t) || t 'sz = 0) acc
                                  (atom? acc || at? t || perm t != perm (<(<acc)) || t 'name = rbrk) ([t t ()] . acc)
                                  ([(<(<acc)) t ()] . >acc)))
                            () outs)))
       _ (each loads (l \ each outs (t \ (? (t 'va >= <l 'va && alloc? t && t 'sz > 0
                                                && t 'va <= (l 1) 'va && !(peep t 'load 0))
                                             (pin t 'load l) 0))))
       ; under PHDRS an empty section rides its header's load too, for its offset
       _ (? (atom? phr) 0
            (each outs (t \ (? (alloc? t && t 'sz = 0 && !(two? (peep t 'load ())))
                                (: m <(filter (x \ x 2 != () && elem (x 2 'name) (t 'phn)) loads)
                                   (? (two? m) (pin t 'load m) 0))
                                0))))
       dyn (filter (t \ t 'name = ".dynamic") outs0)
       ; lld's PT_NOTE over each run of allocated notes, a script with no PHDRS
       notes (? (two? phr || flat) ()
                (rev <(foldl (\ s t (? (alloc? t && t 'stype = 7)
                                       (? (s 1) [([(<(<(<s))) t] . >(<s)) 1] [([t t] . <s) 1])
                                       [<s 0]))
                             [() 0] outs)))
       nph (? (two? phr) #phr flat (#loads + 4) (#loads + 1 + #dyn + #notes + (? (two? rsec) 1 0)))
       nres (? flat (#grps + 4) nph)
       hdrs (? w32 (52 + 32 * nres) (64 + 56 * nres))
       names (foldl (\ a t (a + t 'name + "\0")) "\0" outs)
       fouts (filter alloc? outs + filter (t \ !(alloc? t)) outs)        ; the file: allocated first
       shn names
       _ (pin sht 'sz #shn, pin sht 'pieces [shn])
       _ (foldl (\ o t
                  (: f (peep t 'load ())
                     ; lld's computeFileOffset: a load's first congruent to its address, a later
                     ; NOBITS where the file stands, the rest by the first's offset
                     off (? (two? f && <f 'name = t 'name) (? nmagic (ld-al o (t 'al)) (o + ((t 'va - o) % pg + pg) % pg))
                            (t 'stype = 8) o
                            (two? f) (<f 'off + t 'va - <f 'va)
                            (ld-al o (t 'al)))
                     _ (pin t 'off off)
                     (off + (? (t 'stype = 8) 0 (t 'sz)))))
                hdrs fouts)
       last (: l <(rev fouts) (l 'off + (? (l 'stype = 8) 0 (l 'sz))))
       shoff (ld-al last (? w32 4 8))
       shnum (#outs + 1)
       shstx (shx ".shstrtab")
       (w2 n) (ld-le n 2) (w4 n) (ld-le n 4) (w8 n) (ld-le n 8)
       ; a word of the class: 4 bytes in ELF32, 8 in ELF64
       (wa n) (ld-le n (? w32 4 8))
       eh (cats [[127 69 76 70 (? w32 1 2) 1 1 0 0 0 0 0 0 0 0 0] (w2 (peep lk 'etype 3)) (w2 (peep lk 'mach 183)) (w4 1)
                 (wa entry) (wa (? w32 52 64)) (wa shoff)
                 (w4 0) (w2 (? w32 52 64)) (w2 (? w32 32 56)) (w2 nph) (w2 (? w32 40 64)) (w2 shnum) (w2 shstx)])
       ; a program header: ELF32 keeps its flags after the sizes
       (phd ty fl o v l fz mz al)
        (? w32 (cats [(w4 ty) (w4 o) (w4 v) (w4 l) (w4 fz) (w4 mz) (w4 fl) (w4 al)])
           (cats [(w4 ty) (w4 fl) (w8 o) (w8 v) (w8 l) (w8 fz) (w8 mz) (w8 al)]))
       ; a load from its first section, or under flat the first from the file's start
       (ph l) (: a <l b (l 1) fe (b 'off + (? (b 'stype = 8) 0 (b 'sz)))
                 o0 (? (flat && a 'name = <(<loads) 'name) 0 (a 'off))
                 v0 (a 'va - a 'off + o0) l0 (a 'la - a 'off + o0)
                 (phd 1 (perm a) o0 v0 l0 (fe - o0) (b 'va + b 'sz - v0) pg))
       (row ty fl o v fz mz al) (phd ty fl o v v fz mz al)
       rro (filter (t \ alloc? t && elem (t 'name) ld-relro) outs0)
       (fend t) (t 'off + (? (t 'stype = 8) 0 (t 'sz)))
       fphs (? flat
               ([(row 6 4 64 64 (56 * nres) (56 * nres) 8)] + map ph loads
                + (? (two? dyn) [(: t <dyn (row 2 6 (t 'off) (t 'va) (t 'sz) (t 'sz) 8))] ())
                + (? (two? rro) [(: a <rro b <(rev rro)
                                    (row 1685382482 4 (a 'off) (a 'va) (fend b - a 'off) (b 'va + b 'sz - a 'va) 1))] ())
                + [(row 1685382481 6 0 0 0 0 0)] + [(ld-le 0 ((? w32 32 56) * (nres - nph)))]))
       ; a script's header: FILEHDR opens it at offset 0, the headers before its first section
       (prow p)
        (: ms (in p) ty (ld-pt (p 'type)) fl (peep p 'flags ())
           (? (atom? ms) (phd ty (? (whole? fl) fl 0) 0 0 0 0 0 0)
              (: a <ms b <(rev ms) hd (peep p 'FILEHDR 0)
                 o0 (? hd 0 (a 'off)) v0 (? hd (a 'va - hdrs) (a 'va)) l0 (? hd (a 'la - hdrs) (a 'la))
                 fe (b 'off + (? (b 'stype = 8) 0 (b 'sz)))
                 al (? (ty = 1 && !nmagic) pg (foldl (\ m t (max m (t 'al))) 1 ms))
                 (phd ty (? (whole? fl) fl (perm a)) o0 v0 l0 (fe - o0) (b 'va + b 'sz - v0) al))))
       phs (? (two? phr) (map prow phr) flat fphs
              (map ph loads
               + (? (two? dyn) [(: t <dyn (row 2 6 (t 'off) (t 'va) (t 'sz) (t 'sz) 8))] ())
               + (? (two? rsec) [(: a <rsec b <(rev rsec) (row 1685382482 4 (a 'off) (a 'va) (fend b - a 'off) (b 'va + b 'sz - a 'va) 1))] ())
               + [(row 1685382481 6 0 0 0 0 0)]
               + map (g \ (: a <g b (g 1) (row 4 (perm a) (a 'off) (a 'va) (fend b - a 'off) (b 'va + b 'sz - a 'va) (max (a 'al) (b 'al))))) notes))
       (lnk t k) (: s (peep slink (t 'name) ()) (? (two? s) (? (k = 0) (peep shx <s 0) <>s) (peep t (? (k = 0) 'link 'info) 0)))
       nmoff (: t {} _ (foldl (\ o x (pin t (x 'name) o, o + #(x 'name) + 1)) 1 outs) t)
       (sh t) (cats [(w4 (nmoff (t 'name))) (w4 (t 'stype)) (wa (t 'flags)) (wa (? (alloc? t) (t 'va) 0)) (wa (t 'off))
                     (wa (t 'sz)) (w4 (lnk t 0)) (w4 (lnk t 1)) (wa (t 'al)) (wa (peep t 'entsize 0))])
       shs ([(ld-le 0 (? w32 40 64))] + map sh outs)
       _ (unlink path)
       q (open path "w")
       ; under --build-id the bytes are hashed as they go, the id's own still zero
       hs (? (peep lk 'bid 0) (: h (cask 105) _ (sha256-init h) h) ())
       ; a piece is a text, a list of bytes or a cask: the hash takes only a text
       bl (ld-blocks (b \ (: _ (say q b) (? (hs = ()) 0 (sha256-feed hs b)))))
       (put ps) (each ps (p \ (? (#p > 0) (<bl (? (two? p) (string p) p)) 0)))
       ; a section's pieces as they come, newest first; fl counts their bytes
       fl {'n 0}
       (sink acc) (: ps (rev acc) _ (pin fl 'n (fl 'n + foldl (\ a p (a + #p)) 0 ps)) (put ps))
       (body o l)
        (? (atom? l) o
           (: t <l
              (? (t 'stype = 8 || t 'sz = 0) (body o >l)
                 (: _ (put (rev (ld-zp (t 'off - o) ())), pin fl 'n 0, pin lk 'sink sink)
                    ps (? (two? (peep t 'pieces ())) (t 'pieces) (ld-emit lk t))
                    _ (pin lk 'sink (), sink (rev ps))
                    _ (? (fl 'n = t 'sz) 0 (scare 'link-emit [(t 'name) (fl 'n) (t 'sz)]))
                    (body (t 'off + t 'sz) >l)))))
       _ (put (eh . phs))
       e (body hdrs fouts)
       _ (put (rev (ld-zp (shoff - e) ())))
       _ (put shs)
       _ (bl 1 0)
       _ (close q)
       _ (? (hs = ()) 0 (pin lk 'bidhash (sha256-done hs)))
       (shoff + 64 * shnum))

   ;; --- the cortex-a53 erratum 843419: an adrp in a page's last two words, a load or store
   ;     not writing its register, then a load or store through it. lld scans each input
   ;     section of an executable output section over its code ($x to the next $d) and
   ;     patches a hit; love ld refuses one. answers [oi si] of each scanned section whose
   ;     object holds no section symbol for it, in order: lld lays one for each
   (ld-a53 lk)
    (: ot (lk 'ot) isa (lk 'env 'isa)
       (is i m v) ((i & m) = v)
       (rt i) (i % 32) (rn i) ((i >> 5) % 32)
       (st1m i) (elem (i & 61440) '(8192 24576 28672 40960))
       (st1s i) (elem (i & 4251648) '(0 16384 32768))
       (st1 i) ((is i 3221159936 201326592 && st1m i) || (is i 3219128320 209715200 && st1m i)
                || (is i 3221159936 218103808 && st1s i) || (is i 3219128320 226492416 && st1s i))
       (imm-post i) (is i 989858816 939525120) (imm-pre i) (is i 989858816 939527168)
       (stp-post i) (is i 1002438656 679477248) (stp-pre i) (is i 1002438656 696254464)
       (stp i) (stp-post i || is i 1002438656 687865856 || stp-pre i)
       (lit i) (is i 989855744 402653184)
       (ldst1 i) (is i 989858816 939524096 || imm-post i || is i 989858816 939526144 || imm-pre i
                  || is i 989858816 941623296 || is i 989855744 956301312)
       (load i) (? (is i 1061158912 138412032 || lit i) 1
                   (ldst1 i) (: z ((i >> 30) % 4) v ((i >> 26) % 2) o ((i >> 22) % 4)
                                (o != 0 && !(z = 0 && v = 1 && o = 2) && !(z = 3 && v = 0 && o = 2)))
                   0)
       (wback i) (imm-pre i || imm-post i || stp-pre i || stp-post i
                  || (is i 3219128320 226492416 && st1s i) || (is i 3219128320 209715200 && st1m i))
       (writes i r) ((load i && rt i = r) || (wback i && rn i = r))
       (seq a b d) (: r (rt a)
                      (is a 2667577344 2415919104 && is b 167772160 134217728
                       && (is b 1056964608 134217728 || lit b || ldst1 b || stp b || is b 1002438656 671088640 || st1 b)
                       && !(writes b r) && is d 989855744 956301312 && rn d = r))
       (branch? i) (is i 4261412864 3590324224 || is i 4261412864 1409286144
                    || is i 2080374784 335544320 || is i 2080374784 872415232)
       (scan ob si a0 off lim)
        (: s (ob 'src) o0 (ob 'sec si 3) (w k) (rle32 s (o0 + k))
           po ((a0 + off) % 4096) off2 (? (po < 4088) (off + 4088 - po) off)
           (? (off2 >= lim || lim - off2 < 12) 0
              (: hit (? (seq (w off2) (w (off2 + 4)) (w (off2 + 8))) 1
                        (lim - off2 > 12 && !(branch? (w (off2 + 8))) && seq (w off2) (w (off2 + 4)) (w (off2 + 12))) 1 0)
                 _ (? hit (scare 'link-843419 [(ob 'id) off2]) 0)
                 (scan ob si a0 (off2 + (? ((a0 + off2) % 4096 = 4088) 4 4092)) lim))))
       (xsym? n) (n = "$x" || starts? n "$x.") (dsym? n) (n = "$d" || starts? n "$d.")
       ; per object: si -> its mapping symbols [value code?] ascending, and the sections it holds symbols for
       memo {}
       (maps oi)
        (: m (peep memo oi ())
           (? (two? m) m
              (: ob (ot oi) ms {} ss {}
                 sy (ld-symr ob)
                 _ (each >^(ld-nloc ob)
                      (k \ (: r (sy k)
                              (? (r 1 != 0 || r 3 = 0 || r 3 >= 65280) 0
                                 (r 2 = 3) (pin ss (r 3) 1)
                                 (0 < (ob 'sec (r 3) 2 & 4) && (xsym? <r || dsym? <r))
                                 (pin ms (r 3) ([(r 4) (? (xsym? <r) 1 0) k] . peep ms (r 3) ()))
                                 0))))
                 (run l acc) (? (atom? l) (rev acc) (two? acc && <l 1 = <acc 1) (run >l acc) (run >l (<l . acc)))
                 _ (each (keys ms) (k \ pin ms k (run (map (x \ [<x (x 2)]) (sort (map (x \ [<x (x 2) (x 1)]) (ms k)))) ())))
                 r [ms ss]
                 _ (pin memo oi r)
                 r)))
       (one acc x)
        (: oi (x 1) si (x 2) ob (ot oi) m (maps oi) ms (peep <m si ()) a0 (isa (oi * 65536 + si))
           (walk l) (? (atom? l) 0
                       (: lim (? (two? >l) <(>l) (ob 'sec si 4))
                          _ (scan ob si a0 <(<l) lim)
                          (? (two? >l) (walk >>l) 0)))
           _ (walk ms)
           (? (peep <>m si 0) acc ([oi si] . acc)))
       outs (filter (t \ !(peep t 'dead 0) && t 'name != "/DISCARD/" && (t 'flags & 6) = 6) (lk 'outs))
       (rev (foldl (\ acc t (foldl (\ a x (? (<x = 'isec) (one a x) a)) acc (t 'steps))) () outs)))

   ;; --- -r: one relocatable object, as ld.lld -r lays it. a script places what it names, the
   ;     rest are orphans by name in input order, a .rela joining its target's output as
   ;     ".rela" + that name. nothing is relocated: each .rela is copied, its symbols
   ;     renumbered, a section symbol's reference retargeted at its output section's. laid as
   ;     a link lays it, then every offset counts from its section's 0
   (ld-rgone? r) (elem <r '(".note.GNU-stack" ".note.gnu.property") || elem (r 1) '(0 2 3 1879048195))
   (ld-rel o)
    (: out (peep o 'out ())
       (no w) (scare 'link-refuses w)
       _ (? (string? out) 0 (no "no -o"))
       _ (? (o 'shared) (no "-r with -shared") 0)
       cx (ld-load (o 'ins)) objs (cx 'objs)
       ; the machine the objects name, one for all, as lld takes it from the first
       em (? (atom? objs) 183 (rle16 (<objs 'src) 18))
       _ (each objs (ob \ (? (rle16 (ob 'src) 18 = em) 0 (scare 'link-machine (ob 'id)))))
       _ (? (elem [(o 'emu) em] '((() 183) (() 62) (a64 183) (x64 62))) 0 (no (show (o 'emu))))
       ot (: t {} _ (foldl (\ i ob (pin t i ob, i + 1)) 0 objs) t)
       sc (peep o 'script ())
       cmds (? (string? sc) (lds-read <>(uread sc)) ())
       (key oi si) (oi * 65536 + si)
       os (map (t \ (: _ (pin t 'steps (filter (x \ <x != 'isec || !(ld-rgone? (ot (x 1) 'sec (x 2)))) (t 'steps))) t))
               <(ld-place objs cmds () 0 0))
       on {}                                          ; isec key -> its output section's name
       _ (each os (t \ each (t 'steps) (x \ (? (<x = 'isec) (pin on (key (x 1) (x 2)) (t 'name)) 0))))
       sby (: m {} _ (each os (t \ pin m (t 'name) t)) m)
       oby {} rby {} orph {'l ()}
       (fresh m k nm) (: t {'name nm 'body () 'steps ()} _ (pin m k t, pin orph 'l (t . orph 'l)) t)
       (join t oi si r) (: _ (pin on (key oi si) (t 'name)) (pin t 'rs (['isec oi si (r 4) (r 5) <r] . peep t 'rs ())))
       ; a group and a member of one stay apart, each an output of its own
       (own oi si r) (: nm (<r + "\0g" + show (key oi si)) (fresh oby nm nm))
       ; lld's addOrphanSections: a .rela's target first, a name an output section already has joins it,
       ; a link-order section the one of its name whose members link to its link's output
       (add oi si)
        (: r (ot oi 'sec si) mem (0 < (r 2 & 512))
           (? (peep on (key oi si) () != () || ld-rgone? r || peep (ot oi 'drops) si 0) 0
              (r 1 = 17) (join (own oi si r) oi si r)
              (<r = ".note.GNU-split-stack") (scare 'link-split-stack (ot oi 'id))
              (r 1 = 4)
               (: _ (add oi (r 8)) tn (peep on (key oi (r 8)) ())
                  (? (tn = ()) 0
                     (join (: t (? mem () (peep rby tn ()))
                              (? (t != ()) t
                                 (: n (? mem (own oi si r) (fresh rby tn (".rela" + tn))) _ (pin n 'tgt tn) n)))
                           oi si r)))
              mem (: u (own oi si r) _ (? (0 < (r 2 & 128) && r 7 > 0) (pin u 'ltk (key oi (r 7))) 0) (join u oi si r))
              (: s (peep sby <r ())
                 lo (? (s = () && 0 < (r 2 & 128) && r 7 > 0) (: _ (add oi (r 7)) (peep on (key oi (r 7)) ())) ())
                 nm (? (lo = ()) <r (<r + "\0" + lo))
                 ; the first output of a name takes that name's plain members, a link-order one too
                 (join (? (s != ()) s
                          (: t (peep oby nm ())
                             (? (t != ()) t
                                (: u (fresh oby nm nm)
                                   _ (? (lo = ()) 0 (: _ (pin u 'lto lo) (? (peep oby <r () = ()) (pin oby <r u) 0)))
                                   u))))
                       oi si r))))
       ; a link-order section is added just after its link, among that section's dependents
       (lo? oi si) (0 < (ot oi 'sec si 2 & 128))
       (walk oi ob)
        (: deps {}
           _ (each (rev >^(ob 'shnum)) (si \ (? (lo? oi si) (: l (ot oi 'sec si 7) (pin deps l (si . peep deps l ()))) 0)))
           _ (each >^(ob 'shnum) (si \ (? (lo? oi si) 0 (: _ (add oi si) (each (peep deps si ()) (add oi))))))
           (oi + 1))
       _ (foldl (\ oi ob (walk oi ob)) 0 objs)
       orphs (rev (orph 'l))
       outs (os + orphs)
       ; a group's size is its members' outputs, known once every section has one
       (gsz x) (: r (ot (x 1) 'sec (x 2))
                  (? (r 1 = 17) ['isec (x 1) (x 2) (4 + 4 * #(ld-rgroup (ot (x 1)) (x 1) r on)) (x 4) (x 5)] x))
       _ (each outs (t \ (: k (peep t 'ltk ())
                            _ (? (k = ()) 0 (pin t 'lto (peep on k ())))
                            (pin t 'steps (peep t 'steps () + rev (map gsz (peep t 'rs ())))))))
       cmds2 (cmds + map (t \ ['osec t]) orphs)
       mx (ld-merge ot outs)
       env (ld-lay cx cmds2 mx ())
       ; lld's own .note.GNU-stack, empty, after every orphan
       live (ld-live outs + [{'name ".note.GNU-stack" 'stype 1 'flags 0 'al 1 'sz 0 'va 0 'steps ()}])
       ; x86's code gaps are int3, as lld fills them; aarch64's stay zero
       _ (? (em = 62) (each live (t \ (? (0 < (t 'flags & 4) && peep t 'fill () = ()) (pin t 'fill 3435973836) 0))) 0)
       shx (: t {} _ (foldl (\ i x (pin t (x 'name) i, i + 1)) 1 live) t)
       lk {'cx cx 'ot ot 'mx mx 'outs live 'cmds cmds2 'env env 'on on 'shx shx 'discard (o 'discard) 'patch ld-rpatch 'rsx {}}
       st (ld-rsyms lk shx)
       _ (each ['lidx 'sidx 'gidx] (k \ pin lk k (st k)))
       (ld-relf lk st em out))

   ; group section r's members' outputs in order, each once; one a member lost is gone
   (ld-rgroup ob oi r on)
    (: s (ob 'src)
       (go k acc) (? (k >= r 4) (rev acc)
                     (: n (peep on (oi * 65536 + rle32 s (r 3 + k)) ())
                        (go (k + 4) (? (n = () || n = "/DISCARD/" || elem n acc) acc (n . acc)))))
       (go 4 ()))

   ; the index a group's output names its signature by
   (ld-rgsig lk x)
    (: oi (x 1) ob (lk 'ot oi) si (ob 'sec (x 2) 8) v (ld-rsymx lk oi si)
       (? (v >= 0) v (lk 'sidx (lk 'on (oi * 65536 + ob 'syms si 3)))))

   ; -> {'nl 'rows 'strn 'strs 'lidx 'sidx 'gidx}: the locals by object, each object's then
   ; the section symbols of the outputs it opens, a merged section's after every object's;
   ; the globals in insertion order. lidx object symbol key, sidx output name, gidx name ->
   ; the index each is written at
   (ld-rsyms lk shx)
    (: cx (lk 'cx) ot (lk 'ot) env (lk 'env) at (env 'at) sv (env 'sv) ssec (env 'ssec) on (lk 'on)
       glob (cx 'glob) und (cx 'und)
       (va n) (env 'osv n 0)
       str (ld-strtab 0)
       ; a row laid at once and copied out, by object: a list each was most of a link's live set
       rw (cask 24)
       (ent nm v z info oth shn)
        (: _ (ld-pin4 rw 0 (ld-stradd str nm), pin rw 4 info, pin rw 5 oth, pin rw 6 (shn & 255), pin rw 7 (shn >> 8),
              ld-pin8 rw 8 v, ld-pin8 rw 16 z)
           rw)
       groups {} gord {'l ()}
       (put oi k e) (: g (peep groups oi ())
                       h (? (g = ()) (: t {'j (jug 0) 'k ()} _ (pin groups oi t, pin gord 'l (oi . gord 'l)) t) g)
                       (say (h 'j) e, pin h 'k (k . h 'k)))
       ; a local a kept .rela names stays, .L or not; an object's read when one is in question
       useds {}
       (used? oi si)
        (: u (peep useds oi ())
           (? (u != ()) (peep u si 0)
              (: t {} ob (ot oi)
                 _ (each (ld-reltgs ob)
                      (tg \ (? (peep on (oi * 65536 + tg) () = ()) 0
                               (each (ld-relas ob tg) (e \ pin t (e 2) 1)))))
                 _ (pin useds oi t)
                 (peep t si 0))))
       _ (each ^(cx 'n)
           (oi \ (: ob (ot oi) sy (ld-symr ob)
                    (each >^(ld-nloc ob)
                       (si \ (: r (sy si) sh (r 3)
                                (? (r 1 != 0 || r 2 = 3 || sh = 0) 0
                                   ; a dropped group's own signature stays, absolute
                                   (sh = 65521 || (peep (ob 'drops) sh 0 && ob 'sec sh 1 = 17))
                                    (put oi si (ent <r (r 4) (r 5) (r 2) (r 6) 65521))
                                   (: n (peep on (oi * 65536 + sh) ())
                                      (? (n = () || n = "/DISCARD/") 0
                                         (starts? <r ".L" && lk 'discard != 'none
                                          && (lk 'discard = 'locals || 0 < (ob 'sec sh 2 & 16)) && !(used? oi si)) 0
                                         (put oi si (ent <r (at oi sh (r 4) - va n) (r 5) (r 2) (r 6) (shx n))))))))))))
       ; a section symbol for each output a relocation may point into, in its first member's group
       _ (each (lk 'outs) (t \ (: f (ld-first ot t) (? (f = ()) 0 (put <f ['sec (t 'name)] (ent "" 0 0 3 0 (shx (t 'name))))))))
       ; each group in turn numbers its keys and gives up its rows; lidx object -> a local's index, 4 bytes each
       lidx {} sidx {} gidx {}
       (take i oi)
        (: h (groups oi) lx (? (oi < 0) () (cask (4 * ld-nloc (ot oi))))
           n (foldl (\ i k (: _ (? (two? k) (pin sidx (k 1) i) (ld-pin4 lx (4 * k) i)) (i + 1))) i (rev (h 'k)))
           _ (? (oi < 0) 0 (pin lidx oi (string lx)))
           _ (pin h 'r (slurp (h 'j)), pin h 'j (), pin h 'k ())
           n)
       nl (foldl take 1 (rev (gord 'l)))
       ; a name's visibility, the strictest any object gives it; an undefined's type, its first
       vis {} uty {}
       _ (each ^(cx 'n)
           (oi \ ld-globs (ot oi)
              (\ si r (: v (r 6 % 4) w (peep vis <r 0)
                         _ (? (v = 0) 0 (pin vis <r (? (w = 0 || v < w) v w)))
                         (? (r 3 = 0 && peep uty <r () = ()) (pin uty <r (r 2)) 0)))))
       (oth nm r6) (r6 - r6 % 4 + peep vis nm 0)
       gj (jug 0) gn {'n nl}
       (gput nm e) (: i (gn 'n) _ (pin gidx nm i, pin gn 'n (i + 1)) (say gj e))
       (gl nm)
        (: v (peep sv nm ())
           (? (whole? v)
              (: q (peep ssec nm ()) ty (peep (env 'stype) nm 0)
                 (? (string? q) (gput nm (ent nm (v - va q) 0 (16 + ty) (peep vis nm 0) (shx q)))
                    (q = ()) (gput nm (ent nm v 0 (16 + ty) (peep vis nm 0) 65521))
                    (scare 'link-rel-sym nm)))
              (: g (peep glob nm ())
                 (? (two? g)
                    (: oi <g r (ot oi 'syms (g 1)) sh (r 3) info (r 1 * 16 + r 2)
                       (? (sh = 65521) (gput nm (ent nm (r 4) (r 5) info (oth nm (r 6)) 65521))
                          (: n (peep on (oi * 65536 + sh) ())
                             (? (n = ()) (scare 'link-dropped [(ot oi 'id) nm])
                                (n = "/DISCARD/") 0
                                (gput nm (ent nm (at oi sh (r 4) - va n) (r 5) info (oth nm (r 6)) (shx n)))))))
                    (peep und nm 0 > 0) (gput nm (ent nm 0 0 (und nm * 16 + peep uty nm 0) (peep vis nm 0) 0))
                    0))))
       seen {}
       _ (each (cx 'order + ld-sorder lk) (n \ (? (peep seen n 0) 0 (: _ (pin seen n 1) (gl n)))))
       {'nl nl 'rows ((<(ld-zp 24 ()) . map (oi \ groups oi 'r) (rev (gord 'l))) + [(slurp gj)]) 'nrow (gn 'n)
        'strn (str 'n) 'strs [(slurp (str 'j))] 'lidx lidx 'sidx sidx 'gidx gidx})

   ; the group an output's section symbol joins, as lld picks it: the first input a relocation
   ; may point into of the last description holding one -- its object, -1 a merged section's
   (ld-first ot t)
    (: ms (any (x \ <x = 'msec) (t 'steps))
       (go l) (? (atom? l) ()
                 (: x <l r (? (<x = 'isec) (ot (x 1) 'sec (x 2)) ())
                    (? (<x = 'msec || <x = 'synth && x 1 = ".comment") [-1]
                       (r = () || elem (r 1) '(4 9)) (go >l) (ms && 0 < (r 2 & 16)) [-1] [(x 1)])))
       f (foldl (\ f d (: g (go d) (? (g = ()) f g))) () (peep t 'isds ()))
       (? (f = ()) (go (t 'steps)) f))

   ; --emit-relocs: object oi's relocations of section tg copied as lld does -- the offset
   ; the field's address, a section symbol's addend from its output's, one dropped R_NONE --
   ; reversed onto acc, handed to lk 'sink every 4096. i386's are REL, the addend left in the field
   (ld-erela lk oi tg acc)
    (: ot (lk 'ot) env (lk 'env) at (env 'at) on (lk 'on) sink (peep lk 'sink ())
       lidx (lk 'lidx) sidx (lk 'sidx) gidx (lk 'gidx)
       (va n) (env 'osv n 0)
       rel? (peep lk 'mach 183 = 3) sh (? rel? 256 4294967296)
       (row off info a) (cask (? rel? (ld-le off 4 + ld-le info 4) (ld-le off 8 + ld-le info 8 + ld-le a 8)))
       (one ob oi tg e)
        (: sy (ob 'syms (e 2)) k (e 1) off (at oi tg <e)
           (? (e 2 = 0) (row off k (e 3))
              (sy 2 = 3) (: n (peep on (oi * 65536 + sy 3) ())
                            (? (n = () || n = "/DISCARD/") (row off 0 (e 3))
                               (row off (peep sidx n 0 * sh + k) (? rel? 0 (at oi (sy 3) (sy 4 + e 3) - va n)))))
              (sy 1 = 0) (row off (peep lidx (oi * 16777216 + e 2) 0 * sh + k) (e 3))
              (row off (peep gidx <sy 0 * sh + k) (e 3))))
       ob (ot oi) c (ld-relcur ob tg)
       (go acc) (: m (ld-relnext c 4096)
                   (? (atom? m) acc
                      (: a (foldl (\ a e (one ob oi tg e . a)) acc m)
                         (? (sink = ()) (go a) (: _ (sink a) (go ()))))))
       (go acc))

   ; one input section's bytes under -r: a .rela its entries renumbered, else as read but a
   ; debug section's absolute reference to no definition, which takes lld's tombstone
   (ld-rpatch lk x acc)
    (: oi (x 1) si (x 2) ob (lk 'ot oi) r (ob 'sec si) s (ob 'src) o0 (r 3) sz (r 4)
       on (lk 'on) sv (lk 'env 'sv) glob (lk 'cx 'glob)
       (undef? e) (: sy (ob 'syms (e 2))
                     (? (e 2 = 0) 1
                        (sy 1 = 0) (sy 3 != 65521 && peep on (oi * 65536 + sy 3) () = ())
                        !(whole? (peep sv <sy ())) && !(two? (peep glob <sy ()))))
       (go pos es acc)
        (? (atom? es) (snip s pos (o0 + sz) . acc)
           (: e <es w (? (e 1 = 257) 8 4)
              (go (o0 + <e + w) >es (string (ld-le (ld-tomb <r (e 3)) w) . snip s pos (o0 + <e) . acc))))
       (? (r 1 = 8) (ld-zp sz acc)
          (r 1 = 4) (ld-rrela lk oi r . acc)
          (r 1 = 17) (string (ld-le (rle32 s o0) 4 + cats (map (n \ ld-le (lk 'shx n) 4) (ld-rgroup ob oi r on))) . acc)
          (0 = (r 2 & 2) && ld-debug? <r)
           (go o0 (sort (filter (e \ elem (e 1) '(257 258) && undef? e) (ld-relas ob si))) acc)
          (snip s o0 (o0 + sz) . acc)))

   ; object oi's symbols as -r numbers them: si -> its index, -1 a section symbol's, which its
   ; relocation decides; kept per object in lk 'rsx
   (ld-rsymx lk oi)
    (: m (lk 'rsx) v (peep m oi ())
       (? (tray? v) v
          (: ob (lk 'ot oi) sy (ld-symr ob) lx (peep (lk 'lidx) oi ()) gidx (lk 'gidx)
             (one si) (: e (sy si)
                         (? (si = 0) 0 (e 2 = 3) -1 (e 1 = 0) (? (string? lx) (rle32 lx (4 * si)) 0) (peep gidx <e 0)))
             x (spread (map one ^(ob 'nsym)))
             _ (pin m oi x)
             x)))
   ; relocation section r of object oi as lld -r copies it: the offset from the output
   ; section's 0, a section symbol's addend from its output's, one dropped turned R_NONE. the
   ; input's bytes, each row's changed fields laid over them
   (ld-rrela lk oi r)
    (: ob (lk 'ot oi) env (lk 'env) at (env 'at) on (lk 'on) sidx (lk 'sidx)
       (va n) (env 'osv n 0)
       s (ob 'src) o0 (r 3) sy (ob 'syms) x (ld-rsymx lk oi) sz (r 4)
       dt (at oi (r 8) 0 - va (on (oi * 65536 + r 8)))
       b (cask sz)
       _ (pour b 0 s o0 sz)
       (w4 o v) (ld-pin4 b o v)
       (w8 o v) (ld-pin8 b o v)
       (go k)
        (? (k >= sz) b
           (: e0 (o0 + k) si (rle32 s (e0 + 12)) v (x si)
              _ (w8 k (rle64 s e0 + dt))
              _ (? (v >= 0) (w4 (k + 12) v)
                   (: e (sy si) n (peep on (oi * 65536 + e 3) ())
                      (? (n = () || n = "/DISCARD/") (: _ (w4 (k + 8) 0) (w4 (k + 12) 0))
                         (: _ (w4 (k + 12) (sidx n))
                            (w8 (k + 16) (at oi (e 3) (e 4 + ld-s64 (rle64 s (e0 + 16))) - va n))))))
              (go (k + 24))))
       (go 0))

   ; the relocatable file: no program headers, every address 0, the allocated sections' bytes
   ; first, then .symtab .shstrtab .strtab; answers its size
   (ld-relf lk st em path)
    (: outs0 (lk 'outs) n0 #outs0 shx (: t {} _ (foldl (\ i x (pin t (x 'name) i, i + 1)) 1 outs0) t)
       outs (outs0 + [{'name ".symtab" 'stype 2 'flags 0 'al 8 'sz (24 * st 'nrow) 'entsize 24
                       'link (n0 + 3) 'info (st 'nl) 'pieces (st 'rows)}
                      {'name ".shstrtab" 'stype 3 'flags 0 'al 1 'sz 0}
                      {'name ".strtab" 'stype 3 'flags 0 'al 1 'sz (st 'strn) 'pieces (st 'strs)}])
       nmoff {}
       ; a link-order output's name carries its link's after a 0, written without it
       (wn t) (: nm (t 'name) (go k) (? (k >= #nm) nm (nm k = 0) (snip nm 0 k) (go (k + 1))) (go 0))
       shn (foldl (\ a t (? (peep nmoff (wn t) ()) a (: _ (pin nmoff (wn t) #a) (a + wn t + "\0")))) "\0" outs)
       _ (pin (outs (n0 + 1)) 'sz #shn, pin (outs (n0 + 1)) 'pieces [shn])
       (alloc? t) (0 < (t 'flags & 2))
       fouts (filter alloc? outs + filter (t \ !(alloc? t)) outs)
       last (foldl (\ o t (: off (? (t 'stype = 8) o (ld-al o (t 'al))) _ (pin t 'off off)
                             (off + (? (t 'stype = 8) 0 (t 'sz)))))
                   64 fouts)
       shoff (ld-al last 8)
       shnum (#outs + 1)
       (w2 n) (ld-le n 2) (w4 n) (ld-le n 4) (w8 n) (ld-le n 8)
       eh (cats [[127 69 76 70 2 1 1 0 0 0 0 0 0 0 0 0] (w2 1) (w2 em) (w4 1) (w8 0) (w8 0) (w8 shoff)
                 (w4 0) (w2 64) (w2 0) (w2 0) (w2 64) (w2 shnum) (w2 (n0 + 2))])
       (lnk t) (? (t 'stype = 4) [(n0 + 1) (shx (t 'tgt))]
                  (t 'stype = 17) [(n0 + 1) (ld-rgsig lk (t 'steps 0))]
                  [(: l (peep t 'lto ()) (? (l = ()) (peep t 'link 0) (shx l))) (peep t 'info 0)])
       ; SHF_INFO_LINK a .rela's alone, as lld resolves an input's
       (sh t) (: l (lnk t) f (t 'flags - (t 'flags & 64) + (? (t 'stype = 4) 64 0))
                 (cats [(w4 (nmoff (wn t))) (w4 (t 'stype)) (w8 f) (w8 0) (w8 (t 'off))
                        (w8 (t 'sz)) (w4 <l) (w4 (l 1)) (w8 (t 'al)) (w8 (peep t 'entsize 0))]))
       _ (unlink path)
       q (open path "w")
       bl (ld-blocks (say q))
       (put ps) (each ps (p \ (? (two? p) (<bl (cask p)) (#p > 0) (<bl p) 0)))
       fl {'n 0}
       (sink acc) (: ps (rev acc) _ (pin fl 'n (fl 'n + foldl (\ a p (a + #p)) 0 ps)) (put ps))
       (body o l)
        (? (atom? l) o
           (: t <l
              (? (t 'stype = 8 || t 'sz = 0) (body o >l)
                 (: _ (put (rev (ld-zp (t 'off - o) ())), pin fl 'n 0, pin lk 'sink sink)
                    ps (? (two? (peep t 'pieces ())) (t 'pieces) (ld-emit lk t))
                    _ (pin lk 'sink (), sink (rev ps))
                    _ (? (fl 'n = t 'sz) 0 (scare 'link-emit [(t 'name) (fl 'n) (t 'sz)]))
                    (body (t 'off + t 'sz) >l)))))
       _ (put [eh])
       e (body 64 fouts)
       _ (put (rev (ld-zp (shoff - e) ())), put ([(ld-le 0 64)] + map sh outs))
       _ (bl 1 0)
       _ (close q)
       (shoff + 64 * shnum))

   ;; --- the command line kbuild gives $(LD), lld's dialect. (ld-args argv) -> the options,
   ;     or the text of what it refuses; (ld-ld o) links them under o 'script, answering
   ;     the file's size. an option love ld does not carry out is refused, so a probe
   ;     (ld-option: the flags and -v) answers what this linker does
   ld-lld "LLD 22.1.8"
   (ld-num t) (: hex (2 < #t && t 0 = 48 && (t 1 = 120 || t 1 = 88))
                 (go i a) (? (i >= #t) a
                             (: c (t i) d (? (48 <= c && c < 58) (c - 48) (97 <= c && c < 103) (c - 87)
                                             (65 <= c && c < 71) (c - 55) 99)
                                (? (d < (? hex 16 10)) (go (i + 1) (a * (? hex 16 10) + d)) ())))
                 (? (#t = 0) () (go (? hex 2 0) 0)))
   (ld-emu m) (? (elem m '("aarch64elf" "aarch64linux")) 'a64 (elem m '("elf_x86_64")) 'x64 (m = "elf_i386") 'i386
                 (elem m '("elf64lriscv")) 'rv64 (elem m '("armelf" "armelf_linux_eabi")) 'arm ())
   (ld-args as)
    (: o {'ins () 'emu () 'apply 0 'discard 'default 'orphan "place" 'whole 0 'relro 1 'reloc 0
          'shared 0 'symbolic 0 'a53 0 'nmagic 0 'bti 0 'relr 0 'strip 0 'ver 0 'bid 0 'pie 0 'tgt () 'und () 'ehh 0 'erel 0 'notext 0}
       (pre? a p) (#a > #p && snip a 0 #p = p)
       (aft a p) (snip a #p #a)
       (zopt z) (? (z = "norelro") (pin o 'relro 0) (z = "relro") (pin o 'relro 1)
                   (z = "notext") (pin o 'notext 1) (z = "text") (pin o 'notext 0)
                   (elem z '("noexecstack" "nodelete")) o
                   (z = "force-bti") (pin o 'bti 1)
                   (pre? z "max-page-size=") (: n (ld-num (aft z "max-page-size="))
                                                (? (whole? n && n > 0 && (n & (n - 1)) = 0) (pin o 'pg n) ()))
                   (pre? z "common-page-size=") (? (ld-num (aft z "common-page-size=") = 4096) o ())
                   ())
       (emu m) (: e (ld-emu m) (? (e = ()) () (pin o 'emu e)))
       (flag a)
        ; love refuses where lld warns, and lays no .interp, and lays both .hash and .gnu.hash
        (? (elem a '("-EL" "--no-undefined" "--pic-veneer" "--no-apply-dynamic-relocs"
                     "--start-group" "--end-group" "-(" "-)" "--fatal-warnings" "--no-dynamic-linker"
                     "--hash-style=both")) o
           (elem a '("-v" "--version")) (pin o 'ver 1)
           (elem a '("-h" "--help")) (pin o 'help 1)
           (elem a '("-r" "--relocatable")) (pin o 'reloc 1)
           (elem a '("-shared" "--shared" "-Bshareable")) (pin o 'shared 1)
           (a = "-Bsymbolic") (pin o 'symbolic 1)
           (a = "--fix-cortex-a53-843419") (pin o 'a53 1)
           (elem a '("-n" "--nmagic")) (pin o 'nmagic 1)
           (elem a '("-X" "--discard-locals")) (pin o 'discard 'locals)
           (a = "--discard-none") (pin o 'discard 'none)
           (a = "--eh-frame-hdr") (pin o 'ehh 1)
           (elem a '("-q" "--emit-relocs")) (pin o 'erel 1)
           (elem a '("-S" "--strip-debug")) (pin o 'strip 1)
           (a = "--apply-dynamic-relocs") (pin o 'apply 1)
           (a = "--whole-archive") (pin o 'whole 1)
           (a = "--no-whole-archive") (pin o 'whole 0)
           (a = "--pack-dyn-relocs=relr") (pin o 'relr 1)
           (a = "--pack-dyn-relocs=none") (pin o 'relr 0)
           (elem a '("--build-id=sha1" "--build-id=fast")) (pin o 'bid 1)
           (a = "--build-id=none") (pin o 'bid 0)
           (a = "-pie") (pin o 'pie 1)
           (pre? a "--orphan-handling=") (: h (aft a "--orphan-handling=")
                                            (? (elem h '("place" "warn" "error")) (pin o 'orphan h) ()))
           (pre? a "--script=") (pin o 'script (aft a "--script="))
           (pre? a "-soname=") (pin o 'soname (aft a "-soname="))
           (pre? a "--soname=") (pin o 'soname (aft a "--soname="))
           (pre? a "--undefined=") (pin o 'und (aft a "--undefined=" . o 'und))
           (pre? a "-u" && a != "-u") (pin o 'und (aft a "-u" . o 'und))
           (pre? a "-Ttext=") (: v (ld-num (aft a "-Ttext=")) (? (whole? v) (pin o 'org v) ()))
           (pre? a "-z" && !(a = "-z")) (zopt (aft a "-z"))
           (pre? a "-m" && a != "-m") (emu (aft a "-m"))
           ())
       ; an option and its value, as the next word
       (valued a v)
        (? (a = "-o") (pin o 'out v) (elem a '("-T" "--script")) (pin o 'script v)
           (elem a '("-soname" "--soname" "-h")) (pin o 'soname v)
           (a = "-z") (zopt v) (a = "-m") (emu v)
           (a = "-t") (pin o 'tgt (intern v))
           (a = "-Ttext") (: n (ld-num v) (? (whole? n) (pin o 'org n) ()))
           (a = "--readme") (pin o 'readme v)
           (elem a '("-u" "--undefined")) (pin o 'und (v . o 'und))
           ())
       valued? '("-o" "-T" "--script" "-soname" "--soname" "-h" "-z" "-m" "-t" "-Ttext" "--readme" "-u" "--undefined")
       (go l)
        (? (atom? l) o
           (: a <l
              (? (elem a valued?)
                 (? (two? >l) (? (valued a <(>l) = ()) ("ld: unsupported: " + a + " " + <(>l)) (go >>l))
                    ("ld: " + a + " wants a value"))
                 (0 < #a && a 0 = 45 && a != "-")
                 (? (flag a = ()) ("ld: unsupported option " + a) (go >l))
                 (: _ (pin o 'ins (['in a (o 'whole)] . o 'ins)) (go >l)))))
       r (go as)
       ; -u's names are undefined before any input, so an archive's member defining one is taken
       (? (string? r) r (: _ (pin o 'ins (map (u \ ['undef u]) (rev (o 'und)) + rev (o 'ins))) o)))

   ; -shared with no script: lld's own layout said as one, by rank -- the read-only tables,
   ; text, the relro run padded to a page, then data -- each load lifted a page past the
   ; last as its file offset runs on. a link sets __ld_pg and __ld_hdrs
   ld-shtmpl (lds-read """
     SECTIONS {
     . = __ld_hdrs;
     .dynsym : { *(.dynsym) }
     .gnu.hash : { *(.gnu.hash) }
     .hash : { *(.hash) }
     .dynstr : { *(.dynstr) }
     .rela.dyn : { *(.rela.dyn) }
     .relr.dyn : { *(.relr.dyn) }
     .rodata : { *(.rodata .rodata.*) }
     . = ALIGN(__ld_pg) + (. & (__ld_pg - 1));
     .text : { *(.text .text.*) }
     .plt : { *(.plt) }
     .iplt : { *(.iplt) }
     . = ALIGN(__ld_pg) + (. & (__ld_pg - 1));
     .data.rel.ro : { *(.data.rel.ro .data.rel.ro.*) }
     .dynamic : { *(.dynamic) }
     .got : { *(.got) }
     __ld_rr = .;
     .relro_padding : { *(.relro_padding) }
     . = ALIGN(__ld_pg) + (__ld_rr & (__ld_pg - 1));
     .data : { *(.data .data.*) }
     .got.plt : { *(.got.plt) }
     .bss : { *(.bss .bss.*) }
     .comment 0 : { *(.comment) }
     /DISCARD/ : { *(.note.GNU-stack) }
     }
     """)
   ; a template's commands with each output section afresh, for ld-place to fill
   (ld-fresh cmds)
    (: (osec t) (: n {} _ (each (keys t) (k \ pin n k (t k))) n)
       (map (c \ (? (<c = 'sections) ['sections (map (i \ (? (<i = 'osec) ['osec (osec <>i)] i)) <>c)] c)) cmds))
   ; lld's isRelroSection, with no -z now and no DATA_SEGMENT_RELRO_END
   (ld-relro? t) (: f (peep t 'flags 0) nm (t 'name)
                    (0 < (f & 2) && 0 < (f & 1)
                     && (0 < (f & 1024) || elem (peep t 'stype 1) '(14 15 16)
                         || elem nm '(".data.rel.ro" ".bss.rel.ro" ".got" ".toc" ".relro_padding" ".dynamic" ".ctors"
                                      ".dtors" ".jcr" ".eh_frame" ".fini_array" ".init_array" ".preinit_array"))))
   ; a script's relro with no PHDRS -> [relro sections, [the first section past them] or ()]:
   ; over the sections a load holds, one run, else refused as lld errs
   (ld-relrun outs)
    (: (go l acc end)
        (? (atom? l) [(rev acc) end]
           (: t <l (? (ld-relro? t)
                      (? (two? end) (scare 'link-refuses ("section: " + t 'name + " is not contiguous with other relro sections"))
                         (go >l (t . acc) end))
                      (two? acc && atom? end) (go >l acc [t])
                      (go >l acc end))))
       (go (filter (t \ 0 < (t 'flags & 2) && !(0 < (t 'flags & 1024) && peep t 'stype 1 = 8)) outs) () ()))
   ; lld's loads with no script, over the allocated sections in order: a new one at a change
   ; of permissions or into or out of relro -> [[first last bytes?] ..], the empty ones kept
   (ld-fgroups outs)
    (: (perm t) (4 + (? (0 < (t 'flags & 1)) 2 0) + (? (0 < (t 'flags & 4)) 1 0))
       (rel? t) (elem (t 'name) ld-relro)
       (rev (foldl (\ acc t
                      (? (!(0 < (t 'flags & 2))) acc
                         (atom? acc || perm t != perm (<acc 1) || rel? t != rel? (<acc 1)) ([t t (t 'sz > 0)] . acc)
                         ([(<(<acc)) t (<acc 2 || t 'sz > 0)] . >acc)))
                   () (ld-live outs))))

   ; a script's SECTIONS items, its last
   (lk-secs cmds) (foldl (\ a c (? (<c = 'sections) <>c a)) () cmds)
   ; an output's [inputs? flags type] from its steps, as lld's commitSection takes them
   (ld-oinfo ot t)
    (: ms (filter (x \ <x = 'isec || (<x = 'synth && x 2 > 0)) (peep t 'steps ()))
       (fl x) (? (<x = 'isec) (ot (x 1) 'sec (x 2) 2) (whole? (x 6)) (x 6) 2)
       (ty x) (? (<x = 'isec) (ot (x 1) 'sec (x 2) 1) (whole? (x 5)) (x 5) (starts? (x 1) ".note") 7 1)
       tys (map ty ms) nb (filter (y \ y != 8) tys)
       [(two? ms && t 'name != "/DISCARD/") (foldl (\ a x (a | fl x)) 0 ms) (? (atom? tys) 1 (atom? nb) 8 <nb)])
   ; lld's getSectionRank: partition 1, no address set; then not alloc, else by write and exec,
   ; a note or non-PROGBITS first among the read-only, TLS and relro first among the writable
   (ld-rank f ty nm relro)
    (: x (0 < (f & 4)) w (0 < (f & 1)) base 134479872
       rr (relro && w && (0 < (f & 1024) || elem ty '(14 15 16) || nm = ".data.rel.ro" || starts? nm ".data.rel.ro."
                          || elem nm '(".bss.rel.ro" ".ctors" ".dtors" ".jcr" ".eh_frame" ".fini_array" ".init_array"
                                       ".preinit_array" ".dynamic" ".got" ".relro_padding")))
       (? (0 = (f & 2)) (base | 67108864)
          (: r (? (!w && !x) (base | 512 | (? (ty = 7) 3 (ty != 1) 4 2048))
                  x (base | (? w 8192 4096))
                  (base | 16384 | (? (0 < (f & 1024)) 0 128) | (? rr 0 256)))
             (? (ty = 8) (r | 64) r))))
   ; how alike two ranks are: their leading equal bits of 32
   (ld-prox a b) (: (go n k) (? (k = 0) n (go (n - 1) (k // 2))) (go 32 (ld-xor a b)))
   ; lld's sortOrphanSections over SECTIONS items l: the orphans by rank, each rank's after the
   ; section most like it -- the last of the likest, or before a likest ranked above -- past the
   ; assignments that follow it, at the end when no section with inputs follows
   (ld-orphpos ot l orphs relro after?)
    (: (rk t) (: i (ld-oinfo ot t) (ld-rank (i 1) (i 2) (t 'name) relro))
       (has? c) (<c = 'osec && <(ld-oinfo ot <>c))
       (skip? c) (elem <c '(set provide) && c 1 != ".")
       s0 ((: (f k) (? (k >= #l || !(skip? (l k))) k (f (k + 1)))) 0)
       b (? (s0 < #l && elem <(l s0) '(set assert)) (s0 + 1) s0)
       (pos l r)
        (: e #l
           (px c) (? (has? c) (ld-prox r (rk <>c)) -1)
           (best j mp i) (? (j >= e) [mp i]
                            (: p (px (l j))
                               (? (p > mp || (p = mp && p >= 0 && rk <>(l j) <= r)) (best (j + 1) p j) (best (j + 1) mp i))))
           bm (best b 0 e) mp <bm i0 (bm 1)
           (fw j i) (? (j >= e) i (!(has? (l j))) (fw (j + 1) i) (px (l j) != mp) i (fw (j + 1) (j + 1)))
           (bw i) (? (i = b || has? (l (i - 1))) i (bw (i - 1)))
           (more? i) (? (i >= e) 0 (has? (l i)) 1 (more? (i + 1)))
           (sk i) (? (i < e && skip? (l i)) (sk (i + 1)) i)
           (? (i0 = e) e
              (: i1 (? (after? || rk <>(l i0) <= r) (fw (i0 + 1) (i0 + 1)) (bw i0))
                 (? (more? i1) (sk i1) e))))
       (ins l k xs) (: (go l k acc) (? (k = 0 || atom? l) (rev acc + xs + l) (go >l (k - 1) (<l . acc))) (go l k ()))
       (grp l q) (? (atom? q) l
                    (: r <(<q) g (filter (x \ <x = r) q)
                       (grp (ins l (pos l r) (map (x \ ['osec (x 2)]) g)) (filter (x \ <x != r) q))))
       (grp l (sort (map (i \ [(rk (orphs i)) i (orphs i)]) ^#orphs))))

   ; the link under a script. o from ld-args, o 'banner the .comment line to sign with
   (ld-ld o) (? (o 'reloc) (ld-rel o) (ld-exe o))
   (ld-exe o)
    (: out (peep o 'out ())
       (no w) (scare 'link-refuses w)
       _ (? (string? out) 0 (no "no -o"))
       sc (peep o 'script ())
       ; -shared with no script lays lld's own layout, ld-shtmpl
       flat (o 'shared && !(string? sc))
       _ (? (string? sc || flat) 0 (no "no linker script"))
       _ (? (o 'shared && !(o 'symbolic)) (no "-shared without -Bsymbolic") 0)
       _ (? (flat && !(o 'relr)) (no "-shared with no script and no --pack-dyn-relocs=relr") 0)
       _ (? (flat && !(o 'relro)) (no "-z norelro with no script") 0)
       cx (ld-load (o 'ins))
       ; the machine: aarch64, x86-64 or i386
       em (? (atom? (cx 'objs)) 183 (rle16 (<(cx 'objs) 'src) 18))
       _ (? (elem [(o 'emu) em] '((() 183) (a64 183) (() 62) (x64 62) (() 3) (i386 3))) 0
            (no (show (? (o 'emu = ()) em (o 'emu)))))
       _ (pin cx 'objs (cx 'objs + [(ld-banner "<linker>" (peep o 'banner ("Linker: " + ld-lld)))]))
       pg (peep o 'pg (? (elem em '(62 3)) 4096 65536))   ; lld's max-page-size
       body (? flat (ld-fresh ld-shtmpl) (lds-read <>(uread sc)))
       (words h) (? flat [['set "__ld_pg" '= pg] ['set "__ld_hdrs" '= h]] ())
       cmds (words 0 + body)
       vt (foldl (\ a c (? (<c = 'version) <>c a)) "" cmds)
       ; a -pie lays the dynamic tables a -shared does, exporting nothing
       pie (o 'pie && !(o 'shared))
       _ (? (pie && em = 3) (no "-pie for i386") 0)
       dyn (o 'shared || pie)
       d (? (o 'shared && (flat || 0 < #vt))
            (ld-dso cx {'soname (peep o 'soname ()) 'out out 'symbolic 1 'bti (o 'bti) 'flat flat 'relr (o 'relr) 'notext (o 'notext)} vt)
            pie (ld-dso cx {'pie 1 'out out 'bti (o 'bti) 'relr (o 'relr) 'notext (o 'notext)} vt) 0)
       dsyn (? (d = 0) () (d 'synth))
       bid (? (o 'bid) [[".note.gnu.build-id" 36 4 7 2]] ())
       dyns ((? dyn (? (o 'relr) [".rela.dyn" ".relr.dyn"] [".rela.dyn"]) ()) + (? flat [".relro_padding"] ()))
       ehp (? (o 'ehh) [[".eh_frame_hdr" 0 4]] ())
       pl (ld-place (cx 'objs) cmds (bid + dsyn + map (n \ (? (n = ".relro_padding") [n 0 1 8 3] [n 0 8 (? (n = ".rela.dyn") 4 19) 2])) dyns + ehp)
                    (o 'strip) (o 'erel))
       ; orphans as lld places them under a script: an empty synthetic section goes, an input
       ; joins the output section of its name, else a non-alloc one opens one after them all
       byn (: t {} _ (each <pl (u \ pin t (u 'name) u)) t)
       syn (: t {} _ (each (bid + dsyn) (s \ pin t <s s)) t)
       news {'l ()} bad {'l ()}
       ; isec key -> its output's name. under --emit-relocs an input .rela is an orphan named
       ; ".rela" or ".rel" + its target's output, dropped with its target
       on (: t {} _ (each <pl (u \ each (u 'steps) (x \ (? (<x = 'isec) (pin t (x 1 * 65536 + x 2) (u 'name)) 0)))) t)
       (orph x)
        (? (<x = 'synth) 0
           (: oi <x si (x 2) r (cx 'objs oi 'sec si) rel? (elem (r 1) '(4 9))
              tn (? rel? (peep on (oi * 65536 + r 8) ()) ())
              nm (? rel? ((? (r 1 = 4) ".rela" ".rel") + tn) (x 1))
              st ['isec oi si (r 4) (r 5) nm]
              u (peep byn nm ())
              (? (rel? && (tn = () || tn = "/DISCARD/")) 0
                 (rel? && tn = ".eh_frame") (no "--emit-relocs over .eh_frame")
                 (u != ()) (: _ (pin on (oi * 65536 + si) nm) (pin u 'steps (u 'steps + [st])))
                 (0 < (r 2 & 2) && atom? (lk-secs body)) (pin bad 'l ((cx 'objs oi 'id + ":(" + nm + ")") . bad 'l))
                 (: n {'name nm 'body () 'steps [st] 'orph 1 'tgt tn}
                    _ (pin on (oi * 65536 + si) nm) _ (pin byn nm n) (pin news 'l (n . news 'l))))))
       _ (each <>pl orph)
       _ (? (two? (bad 'l)) (no ("orphan sections, which love ld does not place: " + show (lds-first (rev (bad 'l)) 8))) 0)
       ot0 (: t {} _ (foldl (\ i ob (pin t i ob, i + 1)) 0 (cx 'objs)) t)
       ab (? (em = 62) 1 (em = 3) -1 257)
       ; the dynamic sites before layout, a script's symbols counted relative
       dy0 (? dyn (ld-dynsites {'cx cx 'ot ot0 'outs (<pl + rev (news 'l)) 'relr (o 'relr) 'abs ab 'pie pie 'notext (o 'notext)} ())
              {'rela () 'relr ()})
       ; a synthetic orphan opens an output of its name after the inputs', as lld creates them
       (sorph x)
        (: nm (x 1)
           s (? (nm = ".rela.dyn") [nm (24 * #(dy0 'rela)) 8 4 2] (nm = ".relr.dyn") [nm (8 * #(dy0 'relr)) 8 19 2] (peep syn nm ()))
           (? (atom? s || s 1 = 0 || s 6 = 1) 0
              (: n {'name nm 'body () 'steps [['synth nm (s 1) (s 2) nm (s 3) (s 4)]] 'orph 1}
                 _ (pin byn nm n) (pin news 'l (n . news 'l)))))
       _ (each (filter (x \ <x = 'synth) <>pl) sorph)
       orphs (rev (news 'l))
       ; --orphan-handling=error under SECTIONS refuses every orphan as lld does, a table the
       ; script leaves unnamed too, but not a relocation table --emit-relocs copies
       _ (? (o 'orphan = "error" && two? (lk-secs body))
            (: sn (map (c \ <>c 'name) (filter (c \ <c = 'osec) (ld-flat (lk-secs body))))
               l (map (u \ u 'name) (filter (u \ peep u 'tgt () = ()) orphs)
                  + filter (n \ !(elem n sn)) [".symtab" ".strtab" ".shstrtab"])
               (? (two? l) (no ("orphan sections, which --orphan-handling=error refuses: " + show (lds-first l 8))) 0))
            0)
       ; an allocated orphan joins SECTIONS where lld's findOrphanPos puts it; the rest follow it
       (alloc? u) (0 < (ld-oinfo ot0 u 1 & 2))
       secs2 (ld-orphpos ot0 (lk-secs body) (filter alloc? orphs) (o 'relro) (any (c \ <c = 'phdrs) body))
       body1 (map (c \ (? (<c = 'sections) ['sections secs2] c)) body)
       nao (filter (u \ !(alloc? u)) orphs)
       _ (each orphs (u \ (? (alloc? u) (pin u 'orph 0) 0)))
       os (ld-outs body1 + nao)
       body2 (body1 + map (u \ ['osec u]) nao)
       ; .eh_frame and, under --eh-frame-hdr, its header, synthetic as lld lays them
       eh (ld-eh cx os)
       ehs ((? (eh = ()) () [[".eh_frame" (eh 'size) 8 1 2 0]])
            + (? (o 'ehh) [(? (eh = ()) [".eh_frame_hdr" 0 4 1 2 0 1] [".eh_frame_hdr" (12 + 8 * eh 'nf) 4 1 2 0])] ()))
       ot (: t {} _ (foldl (\ i ob (pin t i ob, i + 1)) 0 (cx 'objs)) t)
       mx (ld-merge ot os)
       lk {'cx cx 'ot ot 'mx mx 'outs os 'cmds (words 0 + body2) 'strip (o 'strip) 'discard (o 'discard)
           'relr (o 'relr) 'apply (o 'apply) 'nmagic (o 'nmagic) 'flat flat 'pg pg 'zrelro (o 'relro && !(o 'nmagic))
           'mach em 'abs ab 'shared (o 'shared) 'pie pie 'notext (o 'notext)
           'etype (? (o 'shared || o 'pie) 3 2) 'bid (o 'bid)                   ; ET_DYN for -pie and -shared, else ET_EXEC
           'erel (o 'erel) 'on on
           'sord (: sn (map (c \ <>c 'name) (filter (c \ <c = 'osec) (ld-flat (lk-secs body))))
                    (filter (t \ elem (t 'name) sn) os + filter (u \ !(elem (u 'name) sn)) orphs))}
       _ (? (d = 0) 0 (: _ (pin lk 'dso d) (pin lk 'slink (d 'slink))))
       ; .dynamic's counts, its array tags for the live outputs, and _init's and _fini's if defined
       (dtq env dy)
        {'rela #(dy 'rela) 'relc #(filter (x \ x 2 = 0) (dy 'rela)) 'relr #(dy 'relr)
         'arrs (cats (map (p \ (? (any (t \ t 'name = <p && !(peep t 'dead 0)) os) [[(p 1) ['osa <p]] [(p 2) ['osz <p]]] ()))
                          [[".preinit_array" 32 33] [".init_array" 25 27] [".fini_array" 26 28]])
                + cats (map (p \ (? (whole? (peep (peep env 'sv {}) <p ()) || two? (peep (cx 'glob) <p ())) [[(p 1) ['sym <p]]] ()))
                            [["_init" 12] ["_fini" 13]]))}
       (dz q) (? (d = 0) 0 (16 * #(ld-dtags d q)))
       ; an empty .rela.dyn or .relr.dyn lends its flags as lld's removed synthetic sections do;
       ; with no script lld keeps aarch64's empty .rela.dyn
       (dsec n z ty es l) [n z 8 ty 2 es (? (z = 0 && !(flat && ty = 4 && em = 183) && atom? l) 1 0)]
       _ (? (flat && two? (dy0 'rela)) (no "-shared with no script and a .rela.dyn") 0)
       (lay rz pz h dy z) (ld-lay cx (words h + body2) mx
                            (map (s \ (? (<s = ".dynamic") [".dynamic" z 8 6 3 16] s)) dsyn + bid + ehs
                             + (? dyn [(dsec ".rela.dyn" (24 * #(dy 'rela)) 4 24 (dy 'rela))] ())
                             + (? (dyn && o 'relr) [(dsec ".relr.dyn" rz 19 8 (dy 'relr))] ())
                             + (? flat [[".relro_padding" pz 1 8 3 0 0]] ())))
       ; .relr.dyn's size moves the layout it encodes, and with no script so do the relro
       ; padding and the headers, one for each load before the empty ones go; a script's
       ; absolute symbols move the sites and so .dynamic: lay until they hold
       (go n rz pz h dy z)
        (: env (lay rz pz h dy z) isa (env 'isa)
           dy2 (? dyn (ld-dynsites lk env) dy)
           q (dtq env dy2) z2 (dz q)
           w (ld-relr (sort (map (p \ isa <p + <>p) (dy2 'relr))))
           rr (peep (env 'sv) "__ld_rr" 0)
           pz2 (? flat (ld-al rr 4096 - rr) 0)
           h2 (? flat (64 + 56 * (4 + #(ld-fgroups os))) 0)
           (? (8 * #w = rz && pz2 = pz && h2 = h && #(dy2 'rela) = #(dy 'rela) && #(dy2 'relr) = #(dy 'relr) && z2 = z)
              [env w dy2 q]
              (n > 8) (scare 'link-relr n)
              (go (n + 1) (8 * #w) pz2 h2 dy2 z2)))
       r (go 0 0 0 0 dy0 (dz (dtq {} dy0)))
       env <r dy (r 2) nrela #(dy 'rela)
       _ (? (atom? (dy 'rela) = atom? (dy0 'rela) && atom? (dy 'relr) = atom? (dy0 'relr)) 0
            (no "a script's absolute symbols empty or fill .rela.dyn"))
       _ (pin lk 'env env)
       ; an output section is in no group
       _ (each os (t \ (? (0 < (peep t 'flags 0 & 512)) (pin t 'flags (t 'flags - 512)) 0)))
       ; x86's code gaps are int3, as lld fills them
       _ (? (elem em '(62 3)) (each os (t \ (? (0 < (peep t 'flags 0 & 4) && peep t 'fill () = ()) (pin t 'fill 3435973836) 0))) 0)
       _ (? (d = 0) 0 (: _ (pin d 'relrsz (8 * #(<>r)), pin d 'relasz (24 * nrela), pin d 'relacount (r 3 'relc))
                         (pin d 'dt (ld-dtags d (r 3)))))
       _ (? (o 'a53) (pin lk 'a53 (ld-a53 lk)) 0)
       sd (? (d = 0) {} (ld-dsdata lk))
       _ (? dyn (: _ (pin sd ".rela.dyn" [(24 * nrela) (ld-rela lk dy)])
                           (pin sd ".relr.dyn" [(8 * #(<>r)) (map (x \ ld-le x 8) <>r)])) 0)
       _ (? (o 'bid) (pin sd ".note.gnu.build-id" [36 [[4 0 0 0 20 0 0 0 3 0 0 0 71 78 85 0] (ld-le 0 20)]]) 0)
       _ (? (eh = ()) 0
            (: isa (env 'isa) b (ld-ehbytes lk eh (isa ".eh_frame") (peep isa ".eh_frame_hdr" 0))
               _ (pin sd ".eh_frame" [(eh 'size) <b])
               (? (o 'ehh) (pin sd ".eh_frame_hdr" [(12 + 8 * eh 'nf) [(b 1)]]) 0)))
       _ (pin lk 'sdata sd)
       en (foldl (\ a c (? (<c = 'entry) <>c a)) "_start" cmds)
       ev (: v (peep (env 'sv) en ()) (? (whole? v) v ((env 'gv) en)))
       z (ld-elf lk (? (whole? ev) ev 0) out)
       _ (? (o 'bid) (ld-buildid lk out) 0)
       z)
)
) ; module 'holo
