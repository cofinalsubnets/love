; src/love/holo/klink.l -- holo's link under a linker script, at a kernel's scale: every section
; kept by name and flags, placed and laid by link.l's script engine, relocated, written as
; ld.lld writes a -shared -Bsymbolic image, or copied whole as ld.lld -r lays a relocatable
; one. after link.l in module holo, on its field encoders. elf64, little-endian, aarch64 first.
;
;   (kl-ar path)          -> the members of an archive, thin or whole: [(name bytes) ..] in
;                            header order; the symbol index is not read
;   (kl-read id bytes)    -> one relocatable object as a tablet, see below
;   (kl-banner id text)   -> an object of one .comment line, for the linker to sign with
;   (kl-kas id text)      -> the object scripts/kallsyms' .S assembles to, read directly

(module 'holo
(borrow 'posix)
(borrow 'bytes)
(:
   (kl-u16 s i) (rdle s i 2)
   (kl-u32 s i) (rdle s i 4)
   (kl-u64 s i) (rdle s i 8)
   (kl-s64 v) (? (v >= 9223372036854775808) (v - 18446744073709551616) v)
   (kl-cstr s i) (: (go j) (? (s j = 0) (snip s i j) (go (j + 1))) (go i))

   ;; --- archives. a header is 60 bytes: name 16, then size at 48 as decimal text. a thin
   ;     archive's members are paths beside it, its headers followed by no data.
   (kl-arfld s i n) (: t (snip s i (i + n))
                       (go k) (? (0 < k && t (k - 1) = 32) (go (k - 1)) (snip t 0 k))
                       (go n))
   (kl-arnum t) (foldl (\ a i (a * 10 + t i - 48)) 0 ^#t)
   (kl-dir p) (: (go k) (? (k < 1) "" (p (k - 1) = 47) (snip p 0 k) (go (k - 1))) (go #p))
   (kl-ar path) (: s <>(uread path) (? (string? s) (kl-ars path s) (scare 'klink-open path)))
   (kl-ar? s) (8 <= #s && (snip s 0 8 = "!<arch>\n" || snip s 0 8 = "!<thin>\n"))
   (kl-ars path s)
    (: thin (8 <= #s && snip s 0 8 = "!<thin>\n")
       _ (? (thin || (8 <= #s && snip s 0 8 = "!<arch>\n")) 0 (scare 'klink-not-ar path))
       dir (kl-dir path)
       (next off sz) (? thin (off + 60) (off + 60 + sz + sz % 2))
       ; the long-name table, a member named "/<offset>" reads to the "/\n" there
       (lname lt o) (: (go k) (? (k + 1 < #lt && !(lt k = 47 && lt (k + 1) = 10)) (go (k + 1)) k) (snip lt o (go o)))
       (walk off lt acc)
        (? (#s <= off + 59) (rev acc)
           (: nm (kl-arfld s off 16) sz (kl-arnum (kl-arfld s (off + 48) 10)) d0 (off + 60)
              (? (nm = "/") (walk (off + 60 + sz + sz % 2) lt acc)
                 (nm = "//") (walk (off + 60 + sz + sz % 2) (snip s d0 (d0 + sz)) acc)
                 (: real (? (nm 0 = 47) (lname lt (kl-arnum (snip nm 1 #nm)))
                            (#nm > 0 && nm (#nm - 1) = 47) (snip nm 0 (#nm - 1)) nm)
                    by (? thin (: r (uread (dir + real))
                                  (? (two? r) <>r (scare 'klink-member (dir + real))))
                          (snip s d0 (d0 + sz)))
                    (walk (next off sz) lt ([real by] . acc))))))
       {'members (walk 8 "" ()) 'thin thin})

   ;; --- one relocatable object -> a tablet
   ;   'id 'src 'shnum
   ;   'sec          index -> [name type flags off size align entsize link info]
   ;   'syms 'nsym   index -> [name bind type shndx value size other]
   ;   'rela         target section index -> [(off kind sym addend) ..], ascending by off
   (kl-read id s)
    (: r (ld-obj id s 1)
       _ (r 'class = 64 && r 'type = 1 ? 0 (scare 'klink-not-rel64 id))
       _ (r 'nsym > 0 ? 0 (scare 'klink-no-symtab id))
       _ (each ^(r 'shnum) (i \ (r 'sec i 1 = 9 ? (scare 'klink-rel id))))
       r)

   ; the linker's own .comment line, an object after every other, as ld.lld adds its banner
   (kl-banner id t)
    (: s (string (map (i \ t i) ^#t + [0]))
       {'id id 'src s 'shnum 2 'sec {0 ["" 0 0 0 0 0 0 0 0] 1 [".comment" 1 48 0 #s 1 1 0 0]}
        'syms {0 ["" 0 0 0 0 0 0]} 'nsym 1 'rela {}})

   ; the .S scripts/kallsyms writes, read straight to an object: .byte .short .long .asciz,
   ; ALGN and PTR at 64 bits, labels and .globl; laid as clang lays it, the debug sections
   ; empty but there, so a strip-debug link writes the same symbols
   (kl-kas id s)
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
              (w = ".short") (emit (string (kl-le (num (skip k e) (word (skip k e) e)) 2)))
              (w = ".long") (emit (string (kl-le (num (skip k e) (word (skip k e) e)) 4)))
              (w = ".asciz") (: q (skip k e) (go z) (? (s z = 34) z (go (z + 1)))
                                (emit (snip s (q + 1) (go (q + 1))), emit (string [0])))
              (w = ".globl") (name (snip s (skip k e) (word (skip k e) e)))
              (w = "ALGN") (: r (st 'off % 8) (? (r = 0) () (emit (string (map (x \ 0) ^(8 - r))))))
              (w = "PTR") (: a (skip k e) b (word a e) nm (snip s a b) p (skip b e)
                             add (? (p < e && s p = 43) (: q (skip (p + 1) e) (num q (word q e))) 0)
                             _ (name nm)
                             _ (pin st 'rel ([(st 'off) nm add] . st 'rel))
                             (emit (string (kl-le 0 8))))
              (w = ".section") ()
              (scare 'klink-kas w)))
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

   ;; --- inputs, resolved as lld resolves them. items: ('whole path) ('obj path) ('group
   ;     (path ..)) ('in path whole?), an object or an archive by its magic. every global
   ;     name is inserted in first-seen order; a file's definitions resolve before its
   ;     undefineds, and a strong undefined extracts a lazy member at once, depth first. a
   ;     group archive's members are lazy: each in member order offers its definitions
   ;     until one meets a strong undefined, which extracts it. answers 'objs [ob ..] in
   ;     parse order, 'ot index -> ob, 'glob nom -> [oi si] the definition, 'und nom -> 0
   ;     defined, 1|2 strong or weak undefined, 'order every name inserted
   (kl-load items)
    (: cx {'objs () 'n 0 'ot {} 'glob {} 'und {} 'lazy {} 'order () 'seen {}}
       glob (cx 'glob) und (cx 'und) lazy (cx 'lazy) ot (cx 'ot) seen (cx 'seen)
       (ins nom) (? (peep seen nom 0) 0 (: _ (pin seen nom 1) (pin cx 'order (nom . cx 'order))))
       (gl ob f) (each >^(ob 'nsym) (si \ (: r (ob 'syms si) (? (r 1 = 0 || #(<r) = 0) 0 (f si r)))))
       (add ob)
        (: oi (cx 'n)
           _ (pin cx 'n (oi + 1), pin ot oi ob, pin cx 'objs (ob . cx 'objs))
           _ (gl ob (\ si r (ins <r)))
           _ (gl ob (\ si r (? (r 3 = 0) 0 (def oi si r))))
           _ (gl ob (\ si r (? (r 3 = 0) (ref <r (r 1)) 0)))
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
                         (? (r 1 = 0 || r 3 = 0 || #(<r) = 0) (go (si + 1))
                            (: nom <r _ (ins nom)
                               (? (two? (peep glob nom ())) (go (si + 1))
                                  (peep und nom 0 = 1) (extract mem)
                                  (: _ (? (two? (peep lazy nom ())) 0 (pin lazy nom [mem]))
                                     (go (si + 1))))))))
           (go 1))
       _ (each items
          (it \ (: k <it
                   (? (k = 'obj) (add (kl-read <>it <>(uread <>it)))
                      (k = 'tablet) (add <>it)
                      (k = 'in)
                       (: p (it 1) s <>(uread p)
                          (? (!(string? s)) (scare 'klink-open p)
                             !(kl-ar? s) (add (kl-read p s))
                             (it 2) (each ((kl-ars p s) 'members) (m \ add (kl-read <m <>m)))
                             (each ((kl-ars p s) 'members) (m \ offer {'ob (kl-read <m <>m) 'taken 0}))))
                      (k = 'whole) (each ((kl-ar <>it) 'members) (m \ add (kl-read <m <>m)))
                      (k = 'group)
                       (each <>it (p \ each ((kl-ar p) 'members)
                                         (m \ offer {'ob (kl-read <m <>m) 'taken 0})))
                      (scare 'klink-input k)))))
       _ (pin cx 'objs (rev (cx 'objs)), pin cx 'order (rev (cx 'order)))
       cx)

   ;; --- xxh3_64 with seed 0, lld's piece hash: its low word's top five bits pick a merge shard
   kl-xsec (string [184 254 108 57 35 164 75 190 124 1 129 44 247 33 173 28 222 212 109 233 131 144 151 219
                  114 64 164 164 183 179 103 31 203 121 230 78 204 192 229 120 130 90 208 125 204 255 114 33
                  184 8 70 116 247 67 36 142 224 53 144 230 129 58 38 76 60 40 82 187 145 195 0 203
                  136 208 101 139 27 83 46 163 113 100 72 151 162 13 249 78 56 25 239 70 169 222 172 216
                  168 250 118 63 227 156 52 63 249 220 187 199 199 11 79 29 138 81 224 75 205 180 89 49
                  200 159 126 201 217 120 115 100 234 197 172 131 52 211 235 195 197 129 160 255 250 19 99 235
                  23 13 221 81 183 240 218 73 211 22 85 38 41 212 104 158 43 22 190 88 125 71 161 252
                  143 248 184 209 122 208 49 206 69 203 58 143 149 22 4 40 175 215 251 202 187 75 64 126])
   kl-xp1 11400714785074694791 kl-xp2 14029467366897019727 kl-xp3 1609587929392839161
   kl-xp4 9650029242287828579 kl-xp5 2870177450012600261
   kl-xmx1 1609587791953885689 kl-xmx2 11507291218515648293
   (kl-xm a b) (kl-w (a * b))
   (kl-xf a b) (: p (a * b) (kl-xor (p % kl-m64) (p // kl-m64)))         ; 128-bit product, folded
   (kl-xr h n) (kl-xor h (h // (2 ** n)))
   (kl-xrot h r) (kl-w (h * (2 ** r)) + h // (2 ** (64 - r)))
   (kl-xsw x) (foldl (\ a i (a * 256 + x // (256 ** i) % 256)) 0 ^8)
   (kl-xav h) (kl-xr (kl-xm (kl-xr h 37) kl-xmx1) 32)
   (kl-x64av h) (kl-xr (kl-xm (kl-xr (kl-xm (kl-xr h 33) kl-xp2) 29) kl-xp3) 32)
   (kl-xrrmx h n) (: a (kl-xm (kl-xor h (kl-xor (kl-xrot h 49) (kl-xrot h 24))) kl-xmx2)
                     b (kl-xm (kl-xor a (kl-w (a // (2 ** 35) + n))) kl-xmx2)
                     (kl-xr b 28))
   (kl-xxh s)
    (: n #s k kl-xsec (r64 t i) (rdle t i 8)
       (mix i j) (kl-xf (kl-xor (r64 s i) (r64 k j)) (kl-xor (r64 s (i + 8)) (r64 k (j + 8))))
       (mixes l) (foldl (\ a p (a + mix <p <>p)) 0 l)
       (? (n = 0) (kl-x64av (kl-xor (r64 k 56) (r64 k 64)))
          (n < 4) (kl-x64av (kl-xor (s 0 * 65536 + s (n // 2) * 16777216 + s (n - 1) + n * 256)
                                    (kl-xor (rdle k 0 4) (rdle k 4 4))))
          (n <= 8) (kl-xrrmx (kl-xor (rdle s (n - 4) 4 + rdle s 0 4 * kl-m32) (kl-xor (r64 k 8) (r64 k 16))) n)
          (n <= 16) (: lo (kl-xor (r64 s 0) (kl-xor (r64 k 24) (r64 k 32)))
                       hi (kl-xor (r64 s (n - 8)) (kl-xor (r64 k 40) (r64 k 48)))
                       (kl-xav (kl-w (n + kl-xsw lo + hi + kl-xf lo hi))))
          (n <= 128) (kl-xav (kl-w (n * kl-xp1 + mixes (cats [[[0 0] [(n - 16) 16]]
                                                             (? (n > 32) [[16 32] [(n - 32) 48]] ())
                                                             (? (n > 64) [[32 64] [(n - 48) 80]] ())
                                                             (? (n > 96) [[48 96] [(n - 64) 112]] ())]))))
          (n <= 240) (: a (kl-xav (kl-w (n * kl-xp1 + mixes (map (i \ [(16 * i) (16 * i)]) ^8))))
                        (kl-xav (kl-w (a + mixes (map (i \ [(16 * i) (16 * (i - 8) + 3)]) (drop 8 ^(n // 16)))
                                       + mix (n - 16) 119))))
          (kl-xlong s n)))
   ; over 240 bytes: eight lanes over 64-byte stripes, scrambled every 1024
   (kl-xlong s n)
    (: k kl-xsec (r64 t i) (rdle t i 8)
       (stripe acc p j)
        (: dv (map (i \ r64 s (p + 8 * i)) ^8)
           (map (i \ (: d (kl-xor (dv i) (r64 k (j + 8 * i)))
                        (kl-w (acc i + dv (i ^ 1) + (d % kl-m32) * (d // kl-m32)))))
                ^8))
       (stripes acc p m) (foldl (\ a q (stripe a (p + 64 * q) (8 * q))) acc ^m)
       (scram acc) (map (i \ (: a (acc i) (kl-xm (kl-xor (kl-xr a 47) (r64 k (128 + 8 * i))) 2654435761))) ^8)
       nb ((n - 1) // 1024)
       a0 (foldl (\ a b (scram (stripes a (1024 * b) 16)))
                 [3266489917 kl-xp1 kl-xp2 kl-xp3 kl-xp4 2246822519 kl-xp5 2654435761] ^nb)
       a1 (stripes a0 (1024 * nb) ((n - 1 - 1024 * nb) // 64))
       a2 (stripe a1 (n - 64) 121)
       (kl-xav (kl-w (foldl (\ r i (r + kl-xf (kl-xor (a2 (2 * i)) (r64 k (11 + 16 * i)))
                                              (kl-xor (a2 (2 * i + 1)) (r64 k (19 + 16 * i)))))
                            (n * kl-xp1) ^4))))

   ;; --- merging: an output section's SHF_MERGE inputs of one flags, entsize and, for strings,
   ;     align are one synthetic section at the first's place, each distinct piece once: 32
   ;     shards by the piece's hash, first-seen within each, laid at the group's final align.
   ;     answers 'ms id -> {'size 'align 'flags 'entsize 'type 'tab piece -> off}
   ;     and 'im isec key -> [id [[start off] ..]]
   (kl-pieces s off size e str)
    (: end (off + size)
       (zero? i) (: (go k) (? (k >= e) 1 (s (i + k) != 0) 0 (go (k + 1))) (go 0))
       (go i st acc)
        (? (i >= end) (rev (? (st < end) ([st end] . acc) acc))
           !str (go (i + e) (i + e) ([i (i + e)] . acc))
           (zero? i) (go (i + e) (i + e) ([st (i + e)] . acc))
           (go (i + e) st acc))
       (go off off ()))
   (kl-merge ot outs)
    (: ms {} im {} nid {'n 0}
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
                  (? (0 = (fl & 16) || r 6 = 0) (x . acc)
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
                                          (: h (kl-xxh (? str (snip src <p (<>p - e)) key)) k (h % kl-m32 // 134217728)
                                             (pin tab key 1, pin (m 'sh) k (key . peep (m 'sh) k ()))))
                                     [(<p - r 3) key])
                        _ (pin im (oi * 65536 + si) [id (map place (kl-pieces src (r 3) (r 4) (r 6) str))])
                        (? (f >= 0) acc (['msec id] . acc))))))
           (pin t 'steps (rev (foldl step () (t 'steps)))))
       _ (each outs one)
       (lay m) (: a (m 'align) tab (m 'tab)
                  (put1 o key) (: q (kl-al o a) _ (pin tab key q) (q + #key))
                  (shard o k) (: l (peep (m 'sh) k ()) (? (two? l) (foldl put1 (kl-al o a) (rev l)) o))
                  (pin m 'size (foldl shard 0 ^32)))
       _ (each (keys ms) (id \ lay (ms id)))
       _ (each (keys im) (k \ (: v (im k) tab (ms <v 'tab)
                                 (pin im k [<v (map (q \ [<q (tab (q 1))]) (v 1))]))))
       {'ms ms 'im im})

   ;; --- relocation. a -shared -Bsymbolic image binds every definition home, so an ABS64 in
   ;     an allocated section is a load-time slide: a RELR entry where the site is even in a
   ;     section aligned to 2 or more, else a RELATIVE in .rela.dyn whose field stays 0. a weak
   ;     undefined is an ABS64 against symbol 0. lk: {'cx 'ot 'env 'mx 'outs}
   (kl-isecs outs) (foldl (\ acc t (? (peep t 'dead 0 || t 'name = "/DISCARD/") acc
                                     (foldl (\ a x (? (<x = 'isec) (x . a) a)) acc (t 'steps))))
                          () outs)
   ; S + A for entry e of object oi, () for a weak undefined; a symbol in a section the
   ; link dropped is refused, or under dead answers 'dead, as a debug section's reference
   (kl-sa lk oi e) (kl-sad lk oi e 0)
   (kl-sad lk oi e dead)
    (: ob (lk 'ot oi) sy (ob 'syms (e 2)) sh (sy 3) a (e 3) env (lk 'env) at (env 'at)
       (none u) (? dead 'dead (scare 'klink-dropped [(ob 'id) <sy]))
       (? (sy 2 = 3) (: v (at oi sh (sy 4 + a)) (? (whole? v) v (none 0)))
          (sy 1 = 0 && sh != 0)
           (? (sh = 65521) (sy 4 + a) (: v (at oi sh (sy 4)) (? (whole? v) (v + a) (none 0))))
          (: v (peep (env 'sv) <sy ()) g (? (whole? v) v ((env 'gv) <sy))
             (? (whole? g) (g + a)
                (sy 1 = 2) ()
                (scare 'klink-undef [(ob 'id) <sy])))))
   ; the dynamic sites: {'relr [[key ro] ..] 'rela [[key entry weak?] ..]}, in input order
   (kl-dyn lk)
    (: relr {'l ()} rela {'l ()}
       (wu? ob e) (: sy (ob 'syms (e 2))
                     (sy 1 = 2 && sy 3 = 0 && atom? (peep (lk 'cx 'glob) <sy ())))
       (one x)
        (: oi (x 1) si (x 2) ob (lk 'ot oi) r (ob 'sec si) key (oi * 65536 + si)
           (each (? (0 < (r 2 & 2)) (peep (ob 'rela) si ()) ())
              (e \ (? (e 1 != peep lk 'abs 257) 0
                      (wu? ob e) (pin rela 'l ([key e 1] . rela 'l))
                      (peep lk 'relr 1 && r 5 >= 2 && <e % 2 = 0) (pin relr 'l ([key <e] . relr 'l))
                      (pin rela 'l ([key e 0] . rela 'l))))))
       _ (each (rev (kl-isecs (lk 'outs))) one)
       {'relr (rev (relr 'l)) 'rela (rev (rela 'l))})
   ; sorted addresses -> RELR words: an address, then bitmaps of the 63 words after it
   (kl-relr as)
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
   ;     node exporting a list, the rest local. (kl-dso cx opts vtext) plans them before
   ;     layout, opts {'soname 'symbolic 'bti}: 'exports, 'syms the exported names in
   ;     .gnu.hash's bucket order, 'synth their sections, 'slink their sh_link and sh_info.
   ;     (kl-dsdata lk) answers their bytes once laid, for lk 'sdata
   (kl-ehash s) (foldl (\ h i (: x ((h * 16 + s i) % 4294967296) ((x ^ ((x >> 28) << 4)) & 268435455))) 0 ^#s)
   (kl-ghash s) (foldl (\ h i ((h * 33 + s i) % 4294967296)) 5381 ^#s)
   (kl-words t) (: n #t
                   (go i st acc) (? (i >= n) (rev (? (st < i) (snip t st i . acc) acc))
                                    (lds-sp? (t i)) (go (i + 1) (i + 1) (? (st < i) (snip t st i . acc) acc))
                                    (go (i + 1) st acc))
                   (go 0 0 ()))
   ; with no version script (opts 'flat) every definition of default or protected
   ; visibility is exported, unversioned, and the table carries no soname
   (kl-dso cx opts vt)
    (: ws (kl-words vt)
       fl (peep opts 'flat 0)
       vn <ws
       (gs l on acc) (? (atom? l) (rev acc) (<l = "global:") (gs >l 1 acc) (<l = "local:") (gs >l 0 acc)
                        (on && <l != ";") (gs >l on (<l . acc)) (gs >l on acc))
       ex (: t {} _ (each (gs >ws 0 ()) (n \ pin t n 1)) t)
       (vis? n) (: g (peep (cx 'glob) n ())
                   (? (two? g) (: v ((cx 'objs) <g 'syms (g 1) 6 & 3) (v = 0 || v = 3)) 0))
       ds (filter (n \ (? fl (vis? n) (peep ex n 0 && two? (peep (cx 'glob) n ())))) (cx 'order))
       nb (max (#ds // 4) 1)
       syms (map (p \ p 2) (sort (map (i \ [(kl-ghash (ds i) % nb) i (ds i)]) ^#ds)))
       so (opts 'soname)
       st {'n 1}
       _ (each (syms + (? fl () [so vn])) (s \ (? (whole? (peep st s ())) 0 (: _ (pin st s (st 'n)) (pin st 'n (st 'n + #s + 1))))))
       mw ((: (go p) (? (p > #syms * 12 // 64) p (go (p * 2)))) 1)
       n (#syms + 1)
       dt (cats [(? fl () [[14 'soname]]) (? (opts 'symbolic) [[30 'symbolic]] ()) (? (opts 'bti) [[1879048193 'zero]] ())
                 (? (fl && opts 'relr) [[36 ".relr.dyn"] [35 'relrsz] [37 'relrent]] ())
                 [[6 ".dynsym"] [11 'syment] [5 ".dynstr"] [10 'strsz] [1879047925 ".gnu.hash"] [4 ".hash"]]
                 (? fl () [[1879048176 ".gnu.version"] [1879048188 ".gnu.version_d"] [1879048189 'nverdef]])
                 [[0 'zero]]])
       {'exports ex 'syms syms 'vn vn 'soname so 'str st 'nb nb 'mw mw 'dt dt 'flat fl
        'synth ([[".hash" (4 * (2 + 2 * n)) 4 5 2 4] [".gnu.hash" (16 + 8 * mw + 4 * nb + 4 * #syms) 8 1879048182 2 0]
                [".dynsym" (24 * n) 8 11 2 24] [".dynstr" (st 'n) 1 3 2 0]]
                + (? fl () [[".gnu.version" (2 * n) 2 1879048191 2 2] [".gnu.version_d" 56 4 1879048189 2 0]])
                + [[".dynamic" (16 * #dt) 8 6 3 16]
                [".got" 0 8 1 3 0 1] [".got.plt" 0 8 1 3 0 1] [".plt" 0 16 1 6 0 1] [".iplt" 0 16 1 6 0 1]])
        'slink {".hash" [".dynsym" 0] ".gnu.hash" [".dynsym" 0] ".dynsym" [".dynstr" 1] ".gnu.version" [".dynsym" 0]
                ".gnu.version_d" [".dynstr" 2] ".dynamic" [".dynstr" 0]}})
   (kl-dsdata lk)
    (: d (lk 'dso) env (lk 'env) isa (env 'isa) glob (lk 'cx 'glob) ot (lk 'ot) shx (kl-shx (lk 'outs))
       syms (d 'syms) st (d 'str) n (#syms + 1) nb (d 'nb) mw (d 'mw)
       (w2 v) (kl-le v 2) (w4 v) (kl-le v 4) (w8 v) (kl-le v 8)
       (dsym nm) (: g (glob nm) oi <g r (ot oi 'syms (g 1)) sh (r 3)
                    shn (? (sh = 65521) 65521 (shx (env 'osof (oi * 65536 + sh))))
                    (cats [(w4 (st nm)) [(r 1 * 16 + r 2) 0] (w2 shn) (w8 ((env 'gv) nm)) (w8 (r 5))]))
       ; .hash: a bucket per symbol, chained newest first
       hb {} hc {}
       _ (each (kl-zip syms) (p \ (: i (<p + 1) h (kl-ehash (p 1) % n)
                                    _ (pin hc i (peep hb h 0)) (pin hb h i))))
       sysv (cats [(w4 n) (w4 n) (cats (map (i \ w4 (peep hb i 0)) ^n)) (cats (map (i \ w4 (peep hc i 0)) ^n))])
       ; .gnu.hash: one bloom word per 64 bits, two bits a name; the chain's low bit ends a bucket
       hs (map kl-ghash syms)
       bk (map (h \ h % nb) hs)
       bloom (foldl (\ t h (: k (h // 64 % mw) (pin t k (kl-or (peep t k 0) (kl-or (2 ** (h % 64)) (2 ** ((h >> 26) % 64)))))))
                    {} hs)
       first (: t {} _ (each (rev (kl-zip bk)) (p \ pin t (p 1) (<p + 1))) t)
       gh (cats [(w4 nb) (w4 1) (w4 mw) (w4 26) (cats (map (i \ w8 (peep bloom i 0)) ^mw))
                 (cats (map (b \ w4 (peep first b 0)) ^nb))
                 (cats (map (i \ w4 (hs i // 2 * 2 + (? (i + 1 = #hs || bk (i + 1) != bk i) 1 0))) ^#hs))])
       strs (sort (map (k \ [(st k) k]) (filter string? (keys st))))
       dstr (cats ([0] . map (p \ map (i \ p 1 i) ^#(p 1) + [0]) strs))
       vd (? (d 'flat) () (cats [(w2 1) (w2 1) (w2 1) (w2 1) (w4 (kl-ehash (d 'soname))) (w4 20) (w4 28) (w4 (st (d 'soname))) (w4 0)
                 (w2 1) (w2 0) (w2 2) (w2 1) (w4 (kl-ehash (d 'vn))) (w4 20) (w4 0) (w4 (st (d 'vn))) (w4 0)]))
       (dv k) (? (string? k) (isa k) (k = 'soname) (st (d 'soname)) (k = 'symbolic) 2 (k = 'syment) 24
                 (k = 'strsz) (st 'n) (k = 'nverdef) 2 (k = 'relrsz) (peep d 'relrsz 0) (k = 'relrent) 8 0)
       dyn (cats (map (e \ w8 <e + w8 (dv (e 1))) (d 'dt)))
       one (\ b [#b [b]])
       {".hash" (one sysv) ".gnu.hash" (one gh) ".dynsym" (one (cats ((kl-le 0 24) . map dsym syms)))
        ".dynstr" (one dstr) ".gnu.version" (one (cats ((w2 0) . map (s \ w2 2) syms)))
        ".gnu.version_d" (one vd) ".dynamic" (one dyn)})

   ;; --- emission. pieces are texts and byte lists, laid in file order
   kl-z64 (cask (ld-zeros 65536))
   (kl-zp n acc) (? (n <= 0) acc (n <= 65536) (snip kl-z64 0 n . acc) (kl-zp (n - 65536) (kl-z64 . acc)))
   ; n's low w bytes, little-endian; one split into 32-bit halves, then shifts
   (kl-le n w)
    (: u (kl-w n) lo (u % 4294967296) hi (u // 4294967296)
       (map (i \ (? (i < 4) ((lo >> (8 * i)) & 255) (i < 8) ((hi >> (8 * (i - 4))) & 255) 0)) ^w))
   ; .rela.dyn: RELATIVE first, then the weak ABS64s, each by address
   (kl-rela lk dy)
    (: isa (lk 'env 'isa)
       es (map (r \ (: k <r e (r 1) p (isa k + <e)
                     (? (r 2) [1 p 257 (e 3)] [0 p 1027 (kl-sa lk (k // 65536) e)])))
               (dy 'rela))
       (map (x \ kl-le (x 1) 8 + kl-le (x 2) 8 + kl-le (x 3) 8) (sort es)))
   ; what a non-alloc section's absolute reference to a dropped section reads, as lld
   ; writes it: a debug section's tombstone, the addend elsewhere
   (kl-tomb nm a) (? (elem nm '(".debug_loc" ".debug_ranges")) 1 (nm = ".debug_names") (kl-m64 - 1)
                     (kl-debug? nm) 0 a)
   ; one input section's bytes with its relocations applied -> pieces, reversed onto acc
   (kl-patch lk x acc)
    (: oi (x 1) si (x 2) ob (lk 'ot oi) r (ob 'sec si) s (ob 'src) o0 (r 3) sz (r 4)
       base (lk 'env 'isa (oi * 65536 + si)) mach (peep lk 'mach 183) abs (peep lk 'abs 257)
       be (backends (? (mach = 62) 'x64 'a64))
       ; a weak undefined: a branch falls to the next instruction, a pc-relative field reads
       ; the place, an absolute one the addend
       (weak k p a) (? (elem k '(279 280 282 283)) (p + 4 + a) (elem k '(260 261 273 274 275)) (p + a) a)
       ; S+A and P as lld's uint64 arithmetic sees them: S+A the value nearest P mod 2^64,
       ; both lifted a turn should it fall below 0, so pages divide as they would unsigned
       (near p0 s0) (: v (p0 + kl-s64 (kl-w (s0 - p0))) (? (v < 0) [(v + kl-m64) (p0 + kl-m64)] [v p0]))
       nal (0 = (r 2 & 2))
       (field e) (: ro <e k (e 1) p0 (base + ro) s0 (kl-sad lk oi e nal)
                    q (? (whole? s0) (near p0 s0) [(weak k p0 (e 3)) p0])
                    sa <q p <>q
                    (? (s0 = 'dead) (? (elem k '(257 258)) (kl-le (kl-tomb <r (e 3)) (? (k = 257) 8 4))
                                       (scare 'klink-dropped [(ob 'id) ro k]))
                       (k = abs && nal) (kl-le sa 8)               ; not loaded: no slide
                       (k = abs)
                       (? (!(whole? s0)) (kl-le 0 8)
                          (peep lk 'relr 1 && r 5 >= 2 && ro % 2 = 0) (kl-le sa 8)       ; relr: the field is the addend
                          (kl-le (? (peep lk 'apply 0) sa 0) 8))
                       (: c (peep (ld-rtab mach) k ())
                          _ (? (two? c) 0 (scare 'klink-reloc [(ob 'id) k]))
                          f (ld-fix be c (map (i \ s (o0 + ro + i)) ^4) sa p)
                          (? (two? f) f (scare 'klink-range [(ob 'id) ro k])))))
       ; lld's relaxation: adrp xn, sym; add xn, xn, :lo12:sym, neither addended, sym within
       ; 1 MiB of the add -> nop; adr xn, sym. answers the 8 bytes, or ()
       (relax e f)
        (: ro <e i1 (kl-u32 s (o0 + ro)) i2 (kl-u32 s (o0 + ro + 4)) rd (i1 % 32)
           (? (e 1 = 275 && two? f && f 1 = 277 && <f = ro + 4 && e 2 = f 2 && e 3 = 0 && f 3 = 0
               && (i1 & 2667577344) = 2415919104 && (i2 & 4290772992) = 2432696320
               && i2 % 32 = rd && (i2 >> 5) % 32 = rd)
              (: v0 (kl-sa lk oi e) q (? (whole? v0) (near (base + ro + 4) v0) [() 0]) v <q p <>q
                 (? (whole? v && -1048576 <= v - p && v - p < 1048576)
                    (kl-le 3573751839 4 + refix-with be 'adr21 (kl-le (268435456 + rd) 4) v p 4)
                    ()))
              ()))
       (go pos es acc)
        (? (atom? es) (snip s pos (o0 + sz) . acc)
           (: e <es x (relax e (? (two? >es) <(>es) ()))
              (? (two? x) (go (o0 + <e + 8) >(>es) (x . snip s pos (o0 + <e) . acc))
                 (: b (field e)
                    (go (o0 + <e + #b) >es (b . snip s pos (o0 + <e) . acc))))))
       (? (r 1 = 8) (kl-zp sz acc) (go o0 (peep (ob 'rela) si ()) acc)))
   ; a merge section's bytes: its pieces by offset, the gaps zero
   (kl-mbytes m acc)
    (: t (m 'tab) ps (sort (map (k \ [(t k) k]) (keys t)))
       (go l cur acc) (? (atom? l) (kl-zp (m 'size - cur) acc)
                         (: o <(<l) k <>(<l) (go >l (o + #k) (k . kl-zp (o - cur) acc))))
       (go ps 0 acc))
   ; an output section's pieces; lk 'sdata synthetic name -> [size pieces], lk 'patch an
   ; input section's bytes, kl-patch by default
   (kl-emit lk t)
    (: env (lk 'env) isa (env 'isa) ms (lk 'mx 'ms) end (t 'va + t 'sz)
       ; the bytes from c to e: the section's fill, big-endian from its start, else zeros
       fp (: f (peep t 'fill ()) (? (whole? f) (rev (kl-le f 4)) ()))
       (gap c e acc) (? (atom? fp) (kl-zp (e - c) acc) (e <= c) acc
                        ((map (i \ fp ((c + i - t 'va) % 4)) ^(e - c)) . acc))
       (go l cur acc)
        (? (atom? l) (rev (gap cur end acc))
           (: x <l k <x
              (? (k = 'isec) (: a (isa (x 1 * 65536 + x 2))
                                (go >l (a + x 3) ((peep lk 'patch kl-patch) lk x (gap cur a acc))))
                 (k = 'synth && !(whole? (peep isa (x 1) ()))) (go >l cur acc)
                 (k = 'synth) (: a (isa (x 1)) d (lk 'sdata (x 1))
                                 (go >l (a + <d) (rev <>d + gap cur a acc)))
                 (k = 'msec) (: m (ms (x 1)) a (env 'msa (x 1))
                                (go >l (a + m 'size) (kl-mbytes m (gap cur a acc))))
                 (k = 'data) (: _ (pin env 'dot cur) (go >l (cur + x 1) (kl-le (kl-ev env (x 2)) (x 1) . acc)))
                 (k = 'set && x 1 = ".")
                  (: _ (pin env 'dot cur) v (kl-ev env (x 3))
                     (go >l v (gap cur v acc)))
                 (go >l cur acc))))
       (? (t 'stype = 8) () (go (t 'steps) (t 'va) ())))

   ;; --- the symbol table as lld writes it. the script's names enter after the objects':
   ;     the names its expressions read (not a PROVIDE's, nor a section name), then the
   ;     right sides of the PROVIDEs it takes, then the names it assigns
   (kl-sorder lk)
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
   (kl-symtab lk shx)
    (: cx (lk 'cx) ot (cx 'ot) env (lk 'env) sv (env 'sv) ssec (env 'ssec)
       osof (env 'osof) mof (env 'mof) im (lk 'mx 'im) at (env 'at) glob (cx 'glob) und (cx 'und)
       str {'n 1 'l ()}
       (addstr nm) (? (#nm = 0) 0 (: o (str 'n) _ (pin str 'n (o + #nm + 1), pin str 'l ("\0" . nm . str 'l)) o))
       (oname oi sh) (: k (oi * 65536 + sh) n (peep osof k ())
                        (? (string? n) n (: m (peep im k ()) (? (two? m) (peep mof <m ()) ()))))
       (ent nm v z info oth shn) [(addstr nm) v z info oth shn]
       groups {} gord {'l ()} glo {'l ()}
       (put oi e) (: g (peep groups oi ())
                     _ (? (two? g) 0 (pin gord 'l (oi . gord 'l)))
                     (pin groups oi (e . g)))
       _ (each ^(cx 'n)
           (oi \ (: ob (ot oi) sy (ob 'syms)
                    (each >^(ob 'nsym)
                       (si \ (: r (sy si)
                                (? (r 1 != 0 || r 2 = 3 || r 3 = 0) 0
                                   ; .L: all under -X, else those in a merge section, as lld drops them
                                   (starts? <r ".L" && (lk 'discard = 'locals || (r 3 < 65280 && 0 < (ob 'sec (r 3) 2 & 16)))) 0
                                   (r 3 = 65521) (put oi (ent <r (r 4) (r 5) (r 2) 0 65521))
                                   (: n (oname oi (r 3)) q (ob 'sec (r 3))
                                      (? (string? n) (put oi (ent <r (at oi (r 3) (r 4)) (r 5) (r 2) 0 (shx n)))
                                         ; a debug section --strip-debug dropped leaves its locals absolute, at 0 in a merge section
                                         (lk 'strip && 0 = (q 2 & 2) && kl-debug? <q)
                                         (put oi (ent <r (? (0 < (q 2 & 16)) 0 (r 4)) (r 5) (r 2) 0 65521))
                                         0)))))))))
       seen {}
       names (rev (foldl (\ a n (? (peep seen n 0) a (: _ (pin seen n 1) (n . a)))) () (cx 'order + kl-sorder lk)))
       ; a -shared link's version script keeps its list global and makes the rest local, a
       ; script's own names a group after every object's; the default script's words are klink's
       dso (peep lk 'dso 0)
       (loc? nm) (? (dso = 0 || dso 'flat) 0 !(peep (dso 'exports) nm 0))
       (gl nm)
        (: v (peep sv nm ())
           (? (whole? v && starts? nm "__ld_") 0
              (whole? v) (: q (peep ssec nm ()) ty (peep (env 'stype) nm 0)
                            shn (? (q = 'aether) 1 (string? q) (shx q) 65521)
                            (? (loc? nm) (put -1 (ent nm v 0 ty 0 shn))
                               (pin glo 'l (ent nm v 0 (16 + ty) 0 shn . glo 'l))))
              (: g (peep glob nm ())
                 (? (two? g)
                    (: oi <g r (ot oi 'syms (g 1)) vis (r 6 % 4) n (oname oi (r 3))
                       vs (? (r 3 = 65521) [(r 4) 65521] (string? n) [(at oi (r 3) (r 4)) (shx n)] [0 0])
                       (? (vis = 1 || vis = 2 || loc? nm) (put oi (ent nm <vs (r 5) (r 2) vis (vs 1)))
                          (pin glo 'l (ent nm <vs (r 5) (r 1 * 16 + r 2) vis (vs 1) . glo 'l))))
                    (peep und nm 0 > 0) (pin glo 'l (ent nm 0 0 (und nm * 16) 0 0 . glo 'l))
                    0))))
       _ (each names gl)
       ; lld's _DYNAMIC, hidden at .dynamic
       _ (? (dso = 0) 0
            (: a (env 'isa ".dynamic") (put -1 (ent "_DYNAMIC" a 0 0 2 (shx (kl-holder lk a 'name))))))
       ; the erratum scan's section symbols, each at the end of its object's locals
       _ (each (peep lk 'a53 ()) (x \ (: oi <x si (x 1) (put oi (ent "" (at oi si 0) 0 3 0 (shx (oname oi si)))))))
       locs (cats (map (oi \ rev (groups oi)) (rev (gord 'l))))
       es (locs + rev (glo 'l))
       (row e) (cask (kl-le <e 4 + [(e 3) (e 4)] + kl-le (e 5) 2 + kl-le (e 1) 8 + kl-le (e 2) 8))
       [(#locs + 1) ([(kl-le 0 24)] + map row es) (str 'n) ("\0" . rev (str 'l))])

   ; the live output sections, and each one's section index
   (kl-live outs) (filter (t \ !(peep t 'dead 0) && t 'name != "/DISCARD/") outs)
   (kl-shx outs) (: t {} _ (foldl (\ i x (pin t (x 'name) i, i + 1)) 1 (kl-live outs)) t)
   ; the allocated output section an address falls in
   (kl-holder lk a) <(filter (t \ !(peep t 'dead 0) && 0 < (t 'flags & 2) && t 'va <= a && a < t 'va + t 'sz) (lk 'outs))

   ; the build-id, once kl-elf has written path: sha256's first 20 bytes over the file with
   ; the field still zero, written into the .note.gnu.build-id kl-elf left zero
   (kl-buildid lk path)
    (: a (lk 'env 'isa ".note.gnu.build-id")
       t (kl-holder lk a)
       off (t 'off + a - t 'va + 16)
       h (sha256 <>(uread path))
       (d c) (? (c < 58) (c - 48) (c - 87))
       id (map (i \ d (h (2 * i)) * 16 + d (h (2 * i + 1))) ^20)
       (openfd path 4 @ fd
          (? (charm? fd && fd >= 0) (lseek fd off 0, fdopen fd @ q (say q (string id), close q), id)
             (scare 'klink-buildid path))))

   ;; --- the image, as lld lays it: a PT_LOAD per run of sections with one set of
   ;     permissions, a new one at each AT(); an empty section opens none. under PHDRS the
   ;     script's headers instead, a section in those it names or else its predecessor's.
   ;     a load's first section sits at a file offset congruent to its address mod 64K, or
   ;     at the next aligned one under lk 'nmagic; the rest follow by address. each section
   ;     is written as it is emitted; answers the file's size
   ; the sections lld's relro covers
   kl-relro '(".data.rel.ro" ".dynamic" ".got" ".relro_padding")
   (kl-pt ty) (? (whole? ty) ty
                 (: l '(("PT_NULL" 0) ("PT_LOAD" 1) ("PT_DYNAMIC" 2) ("PT_INTERP" 3) ("PT_NOTE" 4) ("PT_PHDR" 6)
                        ("PT_TLS" 7) ("PT_GNU_EH_FRAME" 1685382480) ("PT_GNU_STACK" 1685382481) ("PT_GNU_RELRO" 1685382482))
                    r (filter (p \ <p = ty) l)
                    (? (two? r) <>(<r) (scare 'klink-phdr ty))))
   ;     with no script (lk 'flat) as lld lays its own: a PT_PHDR, the first load from the
   ;     file's start, a load at each change of permissions or relro, the empty ones dropped
   ;     but their headers' room kept, then PT_DYNAMIC, PT_GNU_RELRO and PT_GNU_STACK, and
   ;     .shstrtab before .strtab
   (kl-elf lk entry path)
    (: outs0 (kl-live (lk 'outs))
       flat (peep lk 'flat 0) pg (peep lk 'pg 65536)
       shx (: t {} _ (foldl (\ i x (pin t (x 'name) i, i + 1)) 1 (outs0 + [{'name ".symtab"} {'name ".strtab"}])) t)
       st (kl-symtab lk (n \ shx n))
       sht {'name ".shstrtab" 'stype 3 'flags 0 'al 1}
       outs (outs0 + [{'name ".symtab" 'stype 2 'flags 0 'al 8 'sz (24 * #(st 1)) 'entsize 24
                       'link (#outs0 + (? flat 3 2)) 'info <st 'pieces (st 1)}]
             + (? flat [sht] ())
             + [{'name ".strtab" 'stype 3 'flags 0 'al 1 'sz (st 2) 'pieces (st 3)}])
       slink (peep lk 'slink {})
       nmagic (peep lk 'nmagic 0)
       (alloc? t) (0 < (t 'flags & 2))
       (perm t) (4 + (? (0 < (t 'flags & 1)) 2 0) + (? (0 < (t 'flags & 4)) 1 0))
       (at? t) (? (atom? (t 'lma)) (whole? (t 'lma)) 1)
       phr (foldl (\ a c (? (<c = 'phdrs) <>c a)) () (lk 'cmds))
       _ (foldl (\ pv t (? (alloc? t) (: ns (? (two? (peep t 'phdrs ())) (t 'phdrs) pv) _ (pin t 'phn ns) ns) pv)) () outs)
       (in p) (filter (t \ alloc? t && t 'sz > 0 && elem (p 'name) (t 'phn)) outs)
       ; loads [[first last row] ..], row the PHDRS one or ()
       grps (? flat (kl-fgroups outs0) ())
       loads (? (two? phr)
                (cats (map (p \ (: ms (in p) (? (kl-pt (p 'type) = 1 && two? ms) [[<ms <(rev ms) p]] ()))) phr))
                flat (map (g \ [<g (g 1) ()]) (filter (g \ g 2) grps))
                (rev (foldl (\ acc t
                               (? (!(alloc? t) || t 'sz = 0) acc
                                  (atom? acc || at? t || perm t != perm (<(<acc))) ([t t ()] . acc)
                                  ([(<(<acc)) t ()] . >acc)))
                            () outs)))
       _ (each loads (l \ each outs (t \ (? (t 'va >= <l 'va && alloc? t && t 'sz > 0
                                                && t 'va <= (l 1) 'va && !(peep t 'load 0))
                                             (pin t 'load l) 0))))
       nph (? (two? phr) #phr flat (#loads + 4) (#loads + 1))
       nres (? flat (#grps + 4) nph)
       hdrs (64 + 56 * nres)
       names (foldl (\ a t (a + t 'name + "\0")) "\0" outs)
       fouts (filter alloc? outs + filter (t \ !(alloc? t)) outs)        ; the file: allocated first
       shn (? flat names (names + ".shstrtab\0"))
       _ (pin sht 'sz #shn, pin sht 'pieces [shn])
       _ (foldl (\ o t
                  (: f (peep t 'load ())
                     off (? (two? f && <f 'name = t 'name) (? nmagic (kl-al o (t 'al)) (o + (t 'va - o) % pg))
                            (two? f) (<f 'off + t 'va - <f 'va)
                            (kl-al o (t 'al)))
                     _ (pin t 'off off)
                     (off + (? (t 'stype = 8) 0 (t 'sz)))))
                hdrs fouts)
       last (: l <(rev fouts) (l 'off + (? (l 'stype = 8) 0 (l 'sz))))
       shso last
       shoff (kl-al (? flat last (shso + #shn)) 8)
       shnum (#outs + (? flat 1 2))
       shstx (? flat (#outs0 + 2) (shnum - 1))
       (w2 n) (kl-le n 2) (w4 n) (kl-le n 4) (w8 n) (kl-le n 8)
       eh (cats [[127 69 76 70 2 1 1 0 0 0 0 0 0 0 0 0] (w2 3) (w2 (peep lk 'mach 183)) (w4 1) (w8 entry) (w8 64) (w8 shoff)
                 (w4 0) (w2 64) (w2 56) (w2 nph) (w2 64) (w2 shnum) (w2 shstx)])
       ; a load from its first section, or under flat the first from the file's start
       (ph l) (: a <l b (l 1) fe (b 'off + (? (b 'stype = 8) 0 (b 'sz)))
                 o0 (? (flat && a 'name = <(<loads) 'name) 0 (a 'off))
                 v0 (a 'va - a 'off + o0) l0 (a 'la - a 'off + o0)
                 (cats [(w4 1) (w4 (perm a)) (w8 o0) (w8 v0) (w8 l0)
                        (w8 (fe - o0)) (w8 (b 'va + b 'sz - v0)) (w8 pg)]))
       (row ty fl o v fz mz al) (cats [(w4 ty) (w4 fl) (w8 o) (w8 v) (w8 v) (w8 fz) (w8 mz) (w8 al)])
       rro (filter (t \ alloc? t && elem (t 'name) kl-relro) outs0)
       dyn (filter (t \ t 'name = ".dynamic") outs0)
       (fend t) (t 'off + (? (t 'stype = 8) 0 (t 'sz)))
       fphs (? flat
               ([(row 6 4 64 64 (56 * nres) (56 * nres) 8)] + map ph loads
                + (? (two? dyn) [(: t <dyn (row 2 6 (t 'off) (t 'va) (t 'sz) (t 'sz) 8))] ())
                + (? (two? rro) [(: a <rro b <(rev rro)
                                    (row 1685382482 4 (a 'off) (a 'va) (fend b - a 'off) (b 'va + b 'sz - a 'va) 1))] ())
                + [(row 1685382481 6 0 0 0 0 0)] + [(kl-le 0 (56 * (nres - nph)))]))
       ; a script's header: FILEHDR opens it at offset 0, the headers before its first section
       (prow p)
        (: ms (in p) ty (kl-pt (p 'type)) fl (peep p 'flags ())
           (? (atom? ms) (cats [(w4 ty) (w4 (? (whole? fl) fl 0)) (kl-le 0 48)])
              (: a <ms b <(rev ms) hd (peep p 'FILEHDR 0)
                 o0 (? hd 0 (a 'off)) v0 (? hd (a 'va - hdrs) (a 'va)) l0 (? hd (a 'la - hdrs) (a 'la))
                 fe (b 'off + (? (b 'stype = 8) 0 (b 'sz)))
                 al (? (ty = 1 && !nmagic) 65536 (foldl (\ m t (max m (t 'al))) 1 ms))
                 (cats [(w4 ty) (w4 (? (whole? fl) fl (perm a))) (w8 o0) (w8 v0) (w8 l0)
                        (w8 (fe - o0)) (w8 (b 'va + b 'sz - v0)) (w8 al)]))))
       phs (? (two? phr) (map prow phr) flat fphs
              (map ph loads + [(cats [(w4 1685382481) (w4 6) (w8 0) (w8 0) (w8 0) (w8 0) (w8 0) (w8 0)])]))
       (lnk t k) (: s (peep slink (t 'name) ()) (? (two? s) (? (k = 0) (shx <s) <>s) (peep t (? (k = 0) 'link 'info) 0)))
       nmoff (: t {} _ (foldl (\ o x (pin t (x 'name) o, o + #(x 'name) + 1)) 1 outs) t)
       (sh t) (cats [(w4 (nmoff (t 'name))) (w4 (t 'stype)) (w8 (t 'flags)) (w8 (? (alloc? t) (t 'va) 0)) (w8 (t 'off))
                     (w8 (t 'sz)) (w4 (lnk t 0)) (w4 (lnk t 1)) (w8 (t 'al)) (w8 (peep t 'entsize 0))])
       shs ([(kl-le 0 64)] + map sh outs
            + (? flat () [(cats [(w4 #names) (w4 3) (w8 0) (w8 0) (w8 shso) (w8 #shn) (w4 0) (w4 0) (w8 1) (w8 0)])]))
       _ (unlink path)
       q (open path "w")
       (put ps) (each ps (p \ (? (two? p) (say q (cask p)) (atom? p && #p > 0) (say q p) 0)))
       (body o l)
        (? (atom? l) o
           (: t <l
              (? (t 'stype = 8 || t 'sz = 0) (body o >l)
                 (: ps (? (two? (peep t 'pieces ())) (t 'pieces) (kl-emit lk t))
                    n (foldl (\ a p (a + #p)) 0 ps)
                    _ (? (n = t 'sz) 0 (scare 'klink-emit [(t 'name) n (t 'sz)]))
                    _ (put (rev (kl-zp (t 'off - o) ())), put ps)
                    (body (t 'off + t 'sz) >l)))))
       _ (put (eh . phs))
       e (body hdrs fouts)
       _ (? flat (put (rev (kl-zp (shoff - e) ())))
            (: _ (put (rev (kl-zp (shso - e) ()))) (put [shn], put (rev (kl-zp (shoff - shso - #shn) ())))))
       _ (put shs)
       _ (close q)
       (shoff + 64 * shnum))

   ;; --- the cortex-a53 erratum 843419: an adrp in a page's last two words, a load or store
   ;     not writing its register, then a load or store through it. lld scans each input
   ;     section of an executable output section over its code ($x to the next $d) and
   ;     patches a hit; klink refuses one. answers [oi si] of each scanned section whose
   ;     object holds no section symbol for it, in order: lld lays one for each
   (kl-a53 lk)
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
        (: s (ob 'src) o0 (ob 'sec si 3) (w k) (kl-u32 s (o0 + k))
           po ((a0 + off) % 4096) off2 (? (po < 4088) (off + 4088 - po) off)
           (? (off2 >= lim || lim - off2 < 12) 0
              (: hit (? (seq (w off2) (w (off2 + 4)) (w (off2 + 8))) 1
                        (lim - off2 > 12 && !(branch? (w (off2 + 8))) && seq (w off2) (w (off2 + 4)) (w (off2 + 12))) 1 0)
                 _ (? hit (scare 'klink-843419 [(ob 'id) off2]) 0)
                 (scan ob si a0 (off2 + (? ((a0 + off2) % 4096 = 4088) 4 4092)) lim))))
       (xsym? n) (n = "$x" || starts? n "$x.") (dsym? n) (n = "$d" || starts? n "$d.")
       ; per object: si -> its mapping symbols [value code?] ascending, and the sections it holds symbols for
       memo {}
       (maps oi)
        (: m (peep memo oi ())
           (? (two? m) m
              (: ob (ot oi) ms {} ss {}
                 _ (each >^(ob 'nsym)
                      (k \ (: r (ob 'syms k)
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
   (kl-rgone? r) (elem <r '(".note.GNU-stack" ".note.gnu.property") || elem (r 1) '(0 2 3 1879048195))
   (kl-rel o)
    (: out (peep o 'out ())
       (no w) (scare 'klink-refuses w)
       _ (? (string? out) 0 (no "no -o"))
       _ (? (o 'shared) (no "-r with -shared") 0)
       cx (kl-load (o 'ins)) objs (cx 'objs)
       ; the machine the objects name, one for all, as lld takes it from the first
       em (? (atom? objs) 183 (kl-u16 (<objs 'src) 18))
       _ (each objs (ob \ (? (kl-u16 (ob 'src) 18 = em) 0 (scare 'klink-machine (ob 'id)))))
       _ (? (elem [(o 'emu) em] '((() 183) (() 62) (a64 183) (x64 62))) 0 (no (show (o 'emu))))
       ot (: t {} _ (foldl (\ i ob (pin t i ob, i + 1)) 0 objs) t)
       sc (peep o 'script ())
       cmds (? (string? sc) (lds-read <>(uread sc)) ())
       (key oi si) (oi * 65536 + si)
       os (map (t \ (: _ (pin t 'steps (filter (x \ <x != 'isec || !(kl-rgone? (ot (x 1) 'sec (x 2)))) (t 'steps))) t))
               <(kl-place objs cmds () 0))
       on {}                                          ; isec key -> its output section's name
       _ (each os (t \ each (t 'steps) (x \ (? (<x = 'isec) (pin on (key (x 1) (x 2)) (t 'name)) 0))))
       sby (: m {} _ (each os (t \ pin m (t 'name) t)) m)
       oby {} rby {} orph {'l ()}
       (fresh m k nm) (: t {'name nm 'body () 'steps ()} _ (pin m k t, pin orph 'l (t . orph 'l)) t)
       (join t oi si r) (: _ (pin on (key oi si) (t 'name)) (pin t 'rs (['isec oi si (r 4) (r 5) <r] . peep t 'rs ())))
       ; lld's addOrphanSections: a .rela's target first, a name an output section already has joins it
       (add oi si)
        (: r (ot oi 'sec si)
           (? (peep on (key oi si) () != () || kl-rgone? r) 0
              (r 1 = 17) (scare 'klink-group (ot oi 'id))
              (<r = ".note.GNU-split-stack") (scare 'klink-split-stack (ot oi 'id))
              (r 1 = 4)
               (: _ (add oi (r 8)) tn (peep on (key oi (r 8)) ())
                  (? (tn = ()) 0
                     (join (: t (peep rby tn ()) (? (t = ()) (: n (fresh rby tn (".rela" + tn)) _ (pin n 'tgt tn) n) t))
                           oi si r)))
              (: s (peep sby <r ())
                 (join (? (s != ()) s (: t (peep oby <r ()) (? (t = ()) (fresh oby <r <r) t))) oi si r))))
       _ (foldl (\ oi ob (: _ (each >^(ob 'shnum) (si \ add oi si)) (oi + 1))) 0 objs)
       orphs (rev (orph 'l))
       outs (os + orphs)
       _ (each outs (t \ pin t 'steps (peep t 'steps () + rev (peep t 'rs ()))))
       cmds2 (cmds + map (t \ ['osec t]) orphs)
       mx (kl-merge ot outs)
       env (kl-lay cx cmds2 mx ())
       ; lld's own .note.GNU-stack, empty, after every orphan
       live (kl-live outs + [{'name ".note.GNU-stack" 'stype 1 'flags 0 'al 1 'sz 0 'va 0 'steps ()}])
       ; x86's code gaps are int3, as lld fills them; aarch64's stay zero
       _ (? (em = 62) (each live (t \ (? (0 < (t 'flags & 4) && peep t 'fill () = ()) (pin t 'fill 3435973836) 0))) 0)
       shx (: t {} _ (foldl (\ i x (pin t (x 'name) i, i + 1)) 1 live) t)
       lk {'cx cx 'ot ot 'mx mx 'outs live 'cmds cmds2 'env env 'on on 'discard (o 'discard) 'patch kl-rpatch}
       st (kl-rsyms lk shx)
       _ (each ['lidx 'sidx 'gidx] (k \ pin lk k (st k)))
       (kl-relf lk st em out))

   ; -> {'nl 'rows 'strn 'strs 'lidx 'sidx 'gidx}: the locals by object, each object's then
   ; the section symbols of the outputs it opens, a merged section's after every object's;
   ; the globals in insertion order. lidx object symbol key, sidx output name, gidx name ->
   ; the index each is written at
   (kl-rsyms lk shx)
    (: cx (lk 'cx) ot (lk 'ot) env (lk 'env) at (env 'at) sv (env 'sv) ssec (env 'ssec) on (lk 'on)
       glob (cx 'glob) und (cx 'und)
       (va n) (env 'osv n 0)
       (sk oi si) (oi * 16777216 + si)
       str {'n 1 'l ()}
       (addstr nm) (? (#nm = 0) 0 (: o (str 'n) _ (pin str 'n (o + #nm + 1), pin str 'l ("\0" . nm . str 'l)) o))
       (ent nm v z info oth shn) [(addstr nm) v z info oth shn]
       groups {} gord {'l ()}
       (put oi e) (: g (peep groups oi ())
                     _ (? (g = ()) (pin gord 'l (oi . gord 'l)) 0)
                     (pin groups oi (e . g)))
       ; a local a kept .rela names stays, .L or not
       used {}
       _ (each ^(cx 'n)
           (oi \ (: ob (ot oi)
                    (each (keys (ob 'rela))
                       (tg \ (? (peep on (oi * 65536 + tg) () = ()) 0
                                (each (ob 'rela tg) (e \ pin used (sk oi (e 2)) 1))))))))
       _ (each ^(cx 'n)
           (oi \ (: ob (ot oi) sy (ob 'syms)
                    (each >^(ob 'nsym)
                       (si \ (: r (sy si) sh (r 3)
                                (? (r 1 != 0 || r 2 = 3 || sh = 0) 0
                                   (sh = 65521) (put oi [(sk oi si) (ent <r (r 4) (r 5) (r 2) (r 6) 65521)])
                                   (: n (peep on (oi * 65536 + sh) ())
                                      (? (n = ()) 0
                                         (starts? <r ".L" && !(peep used (sk oi si) 0)
                                          && (lk 'discard = 'locals || 0 < (ob 'sec sh 2 & 16))) 0
                                         (put oi [(sk oi si) (ent <r (at oi sh (r 4) - va n) (r 5) (r 2) (r 6) (shx n))]))))))))))
       ; a section symbol for each output a relocation may point into, in its first member's group
       (first t) (: (go l) (? (atom? l) ()
                              (: x <l (? (<x = 'isec && !(elem (ot (x 1) 'sec (x 2) 1) '(4 9))) [(x 1)]
                                         (<x = 'msec) [-1]
                                         (go >l))))
                    (go (t 'steps)))
       _ (each (lk 'outs) (t \ (: f (first t) (? (f = ()) 0 (put <f [['sec (t 'name)] (ent "" 0 0 3 0 (shx (t 'name)))])))))
       ; a name's visibility, the strictest any object gives it; an undefined's type, its first
       vis {} uty {}
       _ (each ^(cx 'n)
           (oi \ (: ob (ot oi) sy (ob 'syms)
                    (each >^(ob 'nsym)
                       (si \ (: r (sy si)
                                (? (r 1 = 0) 0
                                   (: v (r 6 % 4) w (peep vis <r 0)
                                      _ (? (v = 0) 0 (pin vis <r (? (w = 0 || v < w) v w)))
                                      (? (r 3 = 0 && peep uty <r () = ()) (pin uty <r (r 2)) 0)))))))))
       (oth nm r6) (r6 - r6 % 4 + peep vis nm 0)
       glo {'l ()}
       (gput nm e) (pin glo 'l ([nm e] . glo 'l))
       (gl nm)
        (: v (peep sv nm ())
           (? (whole? v)
              (: q (peep ssec nm ()) ty (peep (env 'stype) nm 0)
                 (? (string? q) (gput nm (ent nm (v - va q) 0 (16 + ty) (peep vis nm 0) (shx q)))
                    (q = ()) (gput nm (ent nm v 0 (16 + ty) (peep vis nm 0) 65521))
                    (scare 'klink-rel-sym nm)))
              (: g (peep glob nm ())
                 (? (two? g)
                    (: oi <g r (ot oi 'syms (g 1)) sh (r 3) info (r 1 * 16 + r 2)
                       (? (sh = 65521) (gput nm (ent nm (r 4) (r 5) info (oth nm (r 6)) 65521))
                          (: n (peep on (oi * 65536 + sh) ())
                             (? (n = ()) (scare 'klink-dropped [(ot oi 'id) nm])
                                (gput nm (ent nm (at oi sh (r 4) - va n) (r 5) info (oth nm (r 6)) (shx n)))))))
                    (peep und nm 0 > 0) (gput nm (ent nm 0 0 (und nm * 16 + peep uty nm 0) (peep vis nm 0) 0))
                    0))))
       seen {}
       _ (each (cx 'order + kl-sorder lk) (n \ (? (peep seen n 0) 0 (: _ (pin seen n 1) (gl n)))))
       locs (cats (map (oi \ rev (groups oi)) (rev (gord 'l))))
       lidx {} sidx {} gidx {}
       _ (foldl (\ i x (: tg <x _ (? (two? tg) (pin sidx (tg 1) i) (pin lidx tg i)) (i + 1))) 1 locs)
       gs (rev (glo 'l))
       _ (foldl (\ i x (: _ (pin gidx <x i) (i + 1))) (#locs + 1) gs)
       (row e) (cask (kl-le <e 4 + [(e 3) (e 4)] + kl-le (e 5) 2 + kl-le (e 1) 8 + kl-le (e 2) 8))
       {'nl (#locs + 1) 'rows ([(cask (kl-le 0 24))] + map (x \ row (x 1)) (locs + gs))
        'strn (str 'n) 'strs ("\0" . rev (str 'l)) 'lidx lidx 'sidx sidx 'gidx gidx})

   ; one input section's bytes under -r: a .rela its entries renumbered, else as read but a
   ; debug section's absolute reference to no definition, which takes lld's tombstone
   (kl-rpatch lk x acc)
    (: oi (x 1) si (x 2) ob (lk 'ot oi) r (ob 'sec si) s (ob 'src) o0 (r 3) sz (r 4)
       on (lk 'on) sv (lk 'env 'sv) glob (lk 'cx 'glob)
       (undef? e) (: sy (ob 'syms (e 2))
                     (? (e 2 = 0) 1
                        (sy 1 = 0) (sy 3 != 65521 && peep on (oi * 65536 + sy 3) () = ())
                        !(whole? (peep sv <sy ())) && !(two? (peep glob <sy ()))))
       (go pos es acc)
        (? (atom? es) (snip s pos (o0 + sz) . acc)
           (: e <es w (? (e 1 = 257) 8 4)
              (go (o0 + <e + w) >es (string (kl-le (kl-tomb <r (e 3)) w) . snip s pos (o0 + <e) . acc))))
       (? (r 1 = 8) (kl-zp sz acc)
          (r 1 = 4) (foldl (\ a p (p . a)) acc (kl-rrela lk oi (r 8)))
          (0 = (r 2 & 2) && kl-debug? <r)
           (go o0 (sort (filter (e \ elem (e 1) '(257 258) && undef? e) (peep (ob 'rela) si ()))) acc)
          (snip s o0 (o0 + sz) . acc)))

   ; object oi's relocations of section tg as lld -r copies them: the offset from the output
   ; section's 0, a section symbol's addend from its output's, one dropped turned R_NONE
   (kl-rrela lk oi tg)
    (: ob (lk 'ot oi) env (lk 'env) at (env 'at) on (lk 'on)
       lidx (lk 'lidx) sidx (lk 'sidx) gidx (lk 'gidx)
       (va n) (env 'osv n 0)
       tv (va (on (oi * 65536 + tg)))
       (row off info a) (cask (kl-le off 8 + kl-le info 8 + kl-le a 8))
       (map (e \ (: sy (ob 'syms (e 2)) k (e 1) off (at oi tg <e - tv)
                    (? (e 2 = 0) (row off k (e 3))
                       (sy 2 = 3) (: n (peep on (oi * 65536 + sy 3) ())
                                     (? (n = ()) (row off 0 (e 3))
                                        (row off (sidx n * 4294967296 + k) (at oi (sy 3) (sy 4 + e 3) - va n))))
                       (sy 1 = 0) (row off (peep lidx (oi * 16777216 + e 2) 0 * 4294967296 + k) (e 3))
                       (row off (gidx <sy * 4294967296 + k) (e 3)))))
            (ob 'rela tg)))

   ; the relocatable file: no program headers, every address 0, the allocated sections' bytes
   ; first, then .symtab .shstrtab .strtab; answers its size
   (kl-relf lk st em path)
    (: outs0 (lk 'outs) n0 #outs0 shx (: t {} _ (foldl (\ i x (pin t (x 'name) i, i + 1)) 1 outs0) t)
       outs (outs0 + [{'name ".symtab" 'stype 2 'flags 0 'al 8 'sz (24 * #(st 'rows)) 'entsize 24
                       'link (n0 + 3) 'info (st 'nl) 'pieces (st 'rows)}
                      {'name ".shstrtab" 'stype 3 'flags 0 'al 1 'sz 0}
                      {'name ".strtab" 'stype 3 'flags 0 'al 1 'sz (st 'strn) 'pieces (st 'strs)}])
       nmoff {}
       shn (foldl (\ a t (? (peep nmoff (t 'name) ()) a (: _ (pin nmoff (t 'name) #a) (a + t 'name + "\0")))) "\0" outs)
       _ (pin (outs (n0 + 1)) 'sz #shn, pin (outs (n0 + 1)) 'pieces [shn])
       (alloc? t) (0 < (t 'flags & 2))
       fouts (filter alloc? outs + filter (t \ !(alloc? t)) outs)
       last (foldl (\ o t (: off (? (t 'stype = 8) o (kl-al o (t 'al))) _ (pin t 'off off)
                             (off + (? (t 'stype = 8) 0 (t 'sz)))))
                   64 fouts)
       shoff (kl-al last 8)
       shnum (#outs + 1)
       (w2 n) (kl-le n 2) (w4 n) (kl-le n 4) (w8 n) (kl-le n 8)
       eh (cats [[127 69 76 70 2 1 1 0 0 0 0 0 0 0 0 0] (w2 1) (w2 em) (w4 1) (w8 0) (w8 0) (w8 shoff)
                 (w4 0) (w2 64) (w2 0) (w2 0) (w2 64) (w2 shnum) (w2 (n0 + 2))])
       (lnk t) (? (t 'stype = 4) [(n0 + 1) (shx (t 'tgt))] [(peep t 'link 0) (peep t 'info 0)])
       ; SHF_INFO_LINK a .rela's alone, as lld resolves an input's
       (sh t) (: l (lnk t) f (t 'flags - (t 'flags & 64) + (? (t 'stype = 4) 64 0))
                 (cats [(w4 (nmoff (t 'name))) (w4 (t 'stype)) (w8 f) (w8 0) (w8 (t 'off))
                        (w8 (t 'sz)) (w4 <l) (w4 (l 1)) (w8 (t 'al)) (w8 (peep t 'entsize 0))]))
       _ (unlink path)
       q (open path "w")
       (put ps) (each ps (p \ (? (two? p) (say q (cask p)) (atom? p && #p > 0) (say q p) 0)))
       (body o l)
        (? (atom? l) o
           (: t <l
              (? (t 'stype = 8 || t 'sz = 0) (body o >l)
                 (: ps (? (two? (peep t 'pieces ())) (t 'pieces) (kl-emit lk t))
                    n (foldl (\ a p (a + #p)) 0 ps)
                    _ (? (n = t 'sz) 0 (scare 'klink-emit [(t 'name) n (t 'sz)]))
                    _ (put (rev (kl-zp (t 'off - o) ())), put ps)
                    (body (t 'off + t 'sz) >l)))))
       _ (put [eh])
       e (body 64 fouts)
       _ (put (rev (kl-zp (shoff - e) ())), put ([(kl-le 0 64)] + map sh outs))
       _ (close q)
       (shoff + 64 * shnum))

   ;; --- the command line kbuild gives $(LD), lld's dialect. (kl-args argv) -> the options,
   ;     or the text of what it refuses; (kl-ld o) links them under o 'script, answering
   ;     the file's size. an option klink does not carry out is refused, so a probe
   ;     (ld-option: the flags and -v) answers what this linker does
   kl-lld "LLD 22.1.8"
   (kl-num t) (: hex (2 < #t && t 0 = 48 && (t 1 = 120 || t 1 = 88))
                 (go i a) (? (i >= #t) a
                             (: c (t i) d (? (48 <= c && c < 58) (c - 48) (97 <= c && c < 103) (c - 87)
                                             (65 <= c && c < 71) (c - 55) 99)
                                (? (d < (? hex 16 10)) (go (i + 1) (a * (? hex 16 10) + d)) ())))
                 (? (#t = 0) () (go (? hex 2 0) 0)))
   (kl-emu m) (? (elem m '("aarch64elf" "aarch64linux")) 'a64 (elem m '("elf_x86_64")) 'x64
                 (elem m '("elf64lriscv")) 'rv64 (elem m '("armelf" "armelf_linux_eabi")) 'arm ())
   (kl-args as)
    (: o {'ins () 'emu () 'apply 0 'discard 'default 'orphan "place" 'whole 0 'relro 1 'reloc 0
          'shared 0 'symbolic 0 'a53 0 'nmagic 0 'bti 0 'relr 0 'strip 0 'ver 0 'bid 0 'pie 0 'tgt ()}
       (pre? a p) (#a > #p && snip a 0 #p = p)
       (aft a p) (snip a #p #a)
       (zopt z) (? (z = "norelro") (pin o 'relro 0) (z = "relro") (pin o 'relro 1)
                   (elem z '("noexecstack" "notext" "text" "nodelete")) o
                   (z = "force-bti") (pin o 'bti 1)
                   (pre? z "max-page-size=") (? (kl-num (aft z "max-page-size=") = 65536) o ())
                   (pre? z "common-page-size=") (? (kl-num (aft z "common-page-size=") = 4096) o ())
                   ())
       (emu m) (: e (kl-emu m) (? (e = ()) () (pin o 'emu e)))
       (flag a)
        (? (elem a '("-EL" "--no-undefined" "--pic-veneer" "--no-apply-dynamic-relocs"
                     "--start-group" "--end-group" "-(" "-)")) o
           (elem a '("-v" "--version")) (pin o 'ver 1)
           (elem a '("-h" "--help")) (pin o 'help 1)
           (elem a '("-r" "--relocatable")) (pin o 'reloc 1)
           (elem a '("-shared" "--shared" "-Bshareable")) (pin o 'shared 1)
           (a = "-Bsymbolic") (pin o 'symbolic 1)
           (a = "--fix-cortex-a53-843419") (pin o 'a53 1)
           (elem a '("-n" "--nmagic")) (pin o 'nmagic 1)
           (elem a '("-X" "--discard-locals")) (pin o 'discard 'locals)
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
           (pre? a "-Ttext=") (: v (kl-num (aft a "-Ttext=")) (? (whole? v) (pin o 'org v) ()))
           (pre? a "-z" && !(a = "-z")) (zopt (aft a "-z"))
           (pre? a "-m" && a != "-m") (emu (aft a "-m"))
           ())
       ; an option and its value, as the next word
       (valued a v)
        (? (a = "-o") (pin o 'out v) (elem a '("-T" "--script")) (pin o 'script v)
           (elem a '("-soname" "--soname" "-h")) (pin o 'soname v)
           (a = "-z") (zopt v) (a = "-m") (emu v)
           (a = "-t") (pin o 'tgt (intern v))
           (a = "-Ttext") (: n (kl-num v) (? (whole? n) (pin o 'org n) ()))
           (a = "--readme") (pin o 'readme v)
           ())
       valued? '("-o" "-T" "--script" "-soname" "--soname" "-h" "-z" "-m" "-t" "-Ttext" "--readme")
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
       (? (string? r) r (: _ (pin o 'ins (rev (o 'ins))) o)))

   ; -shared with no script: lld's own layout said as one, by rank -- the read-only tables,
   ; text, the relro run padded to a page, then data -- each load lifted a page past the
   ; last as its file offset runs on. a link sets __ld_pg and __ld_hdrs
   kl-shtmpl (lds-read """
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
   ; a template's commands with each output section afresh, for kl-place to fill
   (kl-fresh cmds)
    (: (osec t) (: n {} _ (each (keys t) (k \ pin n k (t k))) n)
       (map (c \ (? (<c = 'sections) ['sections (map (i \ (? (<i = 'osec) ['osec (osec <>i)] i)) <>c)] c)) cmds))
   ; lld's loads with no script, over the allocated sections in order: a new one at a change
   ; of permissions or into or out of relro -> [[first last bytes?] ..], the empty ones kept
   (kl-fgroups outs)
    (: (perm t) (4 + (? (0 < (t 'flags & 1)) 2 0) + (? (0 < (t 'flags & 4)) 1 0))
       (rel? t) (elem (t 'name) kl-relro)
       (rev (foldl (\ acc t
                      (? (!(0 < (t 'flags & 2))) acc
                         (atom? acc || perm t != perm (<acc 1) || rel? t != rel? (<acc 1)) ([t t (t 'sz > 0)] . acc)
                         ([(<(<acc)) t (<acc 2 || t 'sz > 0)] . >acc)))
                   () (kl-live outs))))

   ; the link under a script. o from kl-args, o 'banner the .comment line to sign with
   (kl-ld o) (? (o 'reloc) (kl-rel o) (kl-exe o))
   (kl-exe o)
    (: out (peep o 'out ())
       (no w) (scare 'klink-refuses w)
       _ (? (string? out) 0 (no "no -o"))
       sc (peep o 'script ())
       ; -shared with no script lays lld's own layout, kl-shtmpl
       flat (o 'shared && !(string? sc))
       _ (? (string? sc || flat) 0 (no "no linker script"))
       _ (? (o 'shared && !(o 'symbolic)) (no "-shared without -Bsymbolic") 0)
       _ (? (flat && !(o 'relr)) (no "-shared with no script and no --pack-dyn-relocs=relr") 0)
       _ (? (flat && !(o 'relro)) (no "-z norelro with no script") 0)
       _ (? (o 'relro && !flat) (no "PT_GNU_RELRO: pass -z norelro") 0)
       cx (kl-load (o 'ins))
       ; the machine: aarch64, or x86-64 with no script
       em (? (atom? (cx 'objs)) 183 (kl-u16 (<(cx 'objs) 'src) 18))
       _ (? (elem [(o 'emu) em] (? flat '((() 183) (a64 183) (() 62) (x64 62)) '((() 183) (a64 183)))) 0
            (no (show (? (o 'emu = ()) em (o 'emu)))))
       _ (pin cx 'objs (cx 'objs + [(kl-banner "<linker>" (peep o 'banner ("Linker: " + kl-lld)))]))
       pg (? (em = 62) 4096 65536)
       body (? flat (kl-fresh kl-shtmpl) (lds-read <>(uread sc)))
       (words h) (? flat [['set "__ld_pg" '= pg] ['set "__ld_hdrs" '= h]] ())
       cmds (words 0 + body)
       vt (foldl (\ a c (? (<c = 'version) <>c a)) "" cmds)
       d (? (o 'shared && (flat || 0 < #vt))
            (kl-dso cx {'soname (peep o 'soname "") 'symbolic 1 'bti (o 'bti) 'flat flat 'relr (o 'relr)} vt) 0)
       dsyn (? (d = 0) () (d 'synth))
       bid (? (o 'bid) [[".note.gnu.build-id" 36 4 7 2]] ())
       dyns ((? (o 'shared) (? (o 'relr) [".rela.dyn" ".relr.dyn"] [".rela.dyn"]) ()) + (? flat [".relro_padding"] ()))
       pl (kl-place (cx 'objs) cmds (map (s \ [<s (s 1) (s 2)]) dsyn + map (n \ [n 0 (? (n = ".relro_padding") 1 8)]) dyns + bid) (o 'strip))
       os <pl
       _ (? (two? <>pl)
            (: w (map (x \ (? (<x = 'synth) (x 1) (cx 'objs <x 'id + ":(" + x 1 + ")"))) (lds-first <>pl 8))
               (no ("orphan sections, which klink does not place: " + show w))) 0)
       ot (: t {} _ (foldl (\ i ob (pin t i ob, i + 1)) 0 (cx 'objs)) t)
       mx (kl-merge ot os)
       lk {'cx cx 'ot ot 'mx mx 'outs os 'cmds cmds 'strip (o 'strip) 'discard (o 'discard)
           'relr (o 'relr) 'apply (o 'apply) 'nmagic (o 'nmagic) 'flat flat 'pg pg
           'mach em 'abs (? (em = 62) 1 257)}
       _ (? (d = 0) 0 (: _ (pin lk 'dso d) (pin lk 'slink (d 'slink))))
       dy (? (o 'shared) (kl-dyn lk) {'rela () 'relr ()})
       nrela #(dy 'rela)
       ; an empty .rela.dyn or .relr.dyn lends its flags as lld's removed synthetic sections do;
       ; with no script lld keeps aarch64's empty .rela.dyn
       (dsec n z ty es) [n z 8 ty 2 es (? (z = 0 && !(flat && ty = 4 && em = 183) && atom? (? (ty = 4) (dy 'rela) (dy 'relr))) 1 0)]
       _ (? (flat && two? (dy 'rela)) (no "-shared with no script and a .rela.dyn") 0)
       (lay rz pz h) (kl-lay cx (words h + body) mx
                        (dsyn + bid + (? (o 'shared) [(dsec ".rela.dyn" (24 * nrela) 4 24)] ())
                         + (? (o 'shared && o 'relr) [(dsec ".relr.dyn" rz 19 8)] ())
                         + (? flat [[".relro_padding" pz 1 8 3 0 0]] ())))
       ; .relr.dyn's size moves the layout it encodes, and with no script so do the relro
       ; padding and the headers, one for each load before the empty ones go: lay until they hold
       (go n rz pz h)
        (: env (lay rz pz h) isa (env 'isa)
           w (kl-relr (sort (map (p \ isa <p + <>p) (dy 'relr))))
           rr (peep (env 'sv) "__ld_rr" 0)
           pz2 (? flat (kl-al rr 4096 - rr) 0)
           h2 (? flat (64 + 56 * (4 + #(kl-fgroups os))) 0)
           (? (8 * #w = rz && pz2 = pz && h2 = h) [env w] (n > 8) (scare 'klink-relr n)
              (go (n + 1) (8 * #w) pz2 h2)))
       r (go 0 0 0 0)
       env <r
       _ (pin lk 'env env)
       ; x86's code gaps are int3, as lld fills them
       _ (? (em = 62) (each os (t \ (? (0 < (peep t 'flags 0 & 4) && peep t 'fill () = ()) (pin t 'fill 3435973836) 0))) 0)
       _ (? (d = 0) 0 (pin d 'relrsz (8 * #(<>r))))
       _ (? (o 'a53) (pin lk 'a53 (kl-a53 lk)) 0)
       sd (? (d = 0) {} (kl-dsdata lk))
       _ (? (o 'shared) (: _ (pin sd ".rela.dyn" [(24 * nrela) (kl-rela lk dy)])
                           (pin sd ".relr.dyn" [(8 * #(<>r)) (map (x \ kl-le x 8) <>r)])) 0)
       _ (? (o 'bid) (pin sd ".note.gnu.build-id" [36 [[4 0 0 0 20 0 0 0 3 0 0 0 71 78 85 0] (kl-le 0 20)]]) 0)
       _ (pin lk 'sdata sd)
       en (foldl (\ a c (? (<c = 'entry) <>c a)) "_start" cmds)
       ev (: v (peep (env 'sv) en ()) (? (whole? v) v ((env 'gv) en)))
       z (kl-elf lk (? (whole? ev) ev 0) out)
       _ (? (o 'bid) (kl-buildid lk out) 0)
       z)
)
) ; module 'holo
