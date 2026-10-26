; src/love/holo/klink.l -- holo's link under a linker script, at a kernel's scale: every section
; kept by name and flags, placed by the script (lds.l), relocated, laid as ld.lld lays a
; -shared -Bsymbolic image. after lds.l in module holo, on its field encoders. elf64,
; little-endian, aarch64 first.
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
   (kl-ar path)
    (: s <>(uread path)
       _ (? (string? s) 0 (scare 'klink-open path))
       thin (8 <= #s && snip s 0 8 = "!<thin>\n")
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
                                 (kl-u16 s (e + 6)) (kl-u64 s (e + 8)) (kl-u64 s (e + 16)) (s (e + 5))]))))
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
       {'id id 'src s 'shnum shnum 'sec sec 'syms syms 'nsym nsym 'rela rela})

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

   ;; --- glob: * ? [set] [!set] [^set], over a whole name
   (kl-glob p s)
    (: np #p ns #s
       (cls j c)                                  ; [..] at j -> (matched? . index past "]")
        (: neg (j < np && (p j = 33 || p j = 94))
           (go k hit) (? (k >= np) (scare 'klink-glob p)
                         (p k = 93 && k > (? neg (j + 1) j)) [hit (k + 1)]
                         (k + 2 < np && p (k + 1) = 45 && p (k + 2) != 93)
                          (go (k + 3) (hit || (p k <= c && c <= p (k + 2))))
                         (go (k + 1) (hit || p k = c)))
           r (go (? neg (j + 1) j) 0)
           [(? neg !(<r) <r) <>r])
       (m i j)
        (? (i >= np) (j >= ns)
           (p i = 42) (m (i + 1) j || (j < ns && m i (j + 1)))
           (j >= ns) 0
           (p i = 63) (m (i + 1) (j + 1))
           (p i = 91) (: r (cls (i + 1) (s j)) (<r && m <>r (j + 1)))
           (p i = s j && m (i + 1) (j + 1)))
       (m 0 0))

   ;; --- inputs, resolved as lld resolves them. items: ('whole path) ('obj path) ('group
   ;     (path ..)). every global name is inserted in first-seen order; a file's definitions
   ;     resolve before its undefineds, and a strong undefined extracts a lazy member at once,
   ;     depth first. a group archive's members are lazy: each in member order offers its
   ;     definitions until one meets a strong undefined, which extracts it. answers 'objs
   ;     [ob ..] in parse order, 'ot index -> ob, 'glob nom -> [oi si] the definition, 'und
   ;     nom -> 0 defined, 1|2 strong or weak undefined, 'order every name inserted
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
                      (k = 'whole) (each ((kl-ar <>it) 'members) (m \ add (kl-read <m <>m)))
                      (k = 'group)
                       (each <>it (p \ each ((kl-ar p) 'members)
                                         (m \ offer {'ob (kl-read <m <>m) 'taken 0})))
                      (scare 'klink-input k)))))
       _ (pin cx 'objs (rev (cx 'objs)), pin cx 'order (rev (cx 'order)))
       cx)

   ;; --- placement: each input section to the first SECTIONS input description whose pattern
   ;     names it (the file patterns here are all *), ordered as lld orders one description:
   ;     unsorted matches by input position, a SORT pattern's by its key. the synthetic
   ;     sections come after every object's, as lld appends them.
   kl-skip '(0 2 3 4 9 17 1879002115)             ; null symtab strtab rela rel group addrsig
   (kl-debug? nm) (starts? nm ".debug" || starts? nm ".zdebug")
   (kl-zip l) (: (go l i acc) (? (atom? l) (rev acc) (go >l (i + 1) ([i <l] . acc))) (go l 0 ()))
   ; SECTIONS' output sections -> [tablet ..], each with 'pos
   (kl-outs cmds)
    (: secs (foldl (\ a c (? (<c = 'sections) <>c a)) () cmds)
       os (map (i \ <>i) (filter (i \ <i = 'osec) secs))
       _ (foldl (\ i t (pin t 'pos i, i + 1)) 0 os)
       os)
   ; -> [[d osec desc] ..] in script order, d numbering every description
   (kl-descs os)
    (: (go l d acc)
        (? (atom? l) (rev acc)
           (: t <l
              ins (filter (b \ <b = 'in) (t 'body))
              (go >l (d + #ins) (rev (map (p \ [(d + <p) t <>p]) (kl-zip ins)) + acc))))
       (go os 0 ()))
   ; -> a fn: name -> [d pi], the first description and its first pattern naming it, else ()
   (kl-matcher descs)
    (: memo {}
       (hit pats nm i) (? (atom? pats) -1 (kl-glob (<pats 1) nm) i (hit >pats nm (i + 1)))
       (find l nm) (? (atom? l) ()
                      (: dd <l h (hit (dd 2 3) nm 0)
                         (? (h >= 0) [<dd h] (find >l nm))))
       (nm \ (: m (peep memo nm 0)
                (? (m = 0) (: r (find descs nm) _ (pin memo nm r) r) m))))
   ; one description's entries [(pos e pi) ..] -> its e's in lld's order
   (kl-order es pats)
    (: (bypos l) (map (x \ x 1) (sort l))
       (keyed k x) (? (k = 'SORT_BY_ALIGNMENT) [(0 - (x 1 4)) <x x]
                      (elem k '(SORT SORT_BY_NAME)) [(x 1 5) <x x]
                      (scare 'klink-sort k))
       (go ps i pend acc)
        (? (atom? ps) (acc + bypos pend)
           (: ms (filter (x \ x 2 = i) es) k <(<ps)
              (? (k = 'none || k = 'SORT_NONE) (go >ps (i + 1) (pend + ms) acc)
                 (go >ps (i + 1) () (acc + bypos pend + map (y \ y 2 1) (sort (map (keyed k) ms)))))))
       (go pats 0 () ()))
   ; objects, script, synthetic sections [(name size align) ..] -> [outs orphans]: each
   ; output section tablet gains 'steps, its body with every description expanded to its
   ; ('isec oi si size align name) and ('synth name size align) in order
   (kl-place objs cmds synth strip)
    (: os (kl-outs cmds)
       descs (kl-descs os)
       mt (kl-matcher descs)
       bk {}
       orph {'l ()}
       (put d e) (pin bk d (e . peep bk d ()))
       (scan oi ob)
        (each >^(ob 'shnum)
           (si \ (: r (ob 'sec si) ty (r 1) fl (r 2) nm <r
                    (? (elem ty kl-skip || 0 < (fl & 2147483648)) 0
                       (strip && 0 = (fl & 2) && kl-debug? nm) 0
                       (: m (mt nm)
                          (? (two? m) (put <m [(oi * 65536 + si) ['isec oi si (r 4) (r 5) nm] <>m])
                             (pin orph 'l ([oi nm] . orph 'l))))))))
       _ (foldl (\ oi ob (scan oi ob, oi + 1)) 0 objs)
       _ (foldl (\ k s (: m (mt <s)
                          _ (? (two? m) (put <m [k ['synth <s (s 1) (s 2) <s] <>m])
                               (pin orph 'l (['synth <s] . orph 'l)))
                          (k + 1)))
                4294967296 synth)
       dmap (: t {} _ (each descs (dd \ pin t (dd 2) dd)) t)
       (expand b) (: dd (dmap b) (kl-order (rev (peep bk <dd ())) (b 3)))
       _ (each os
            (t \ pin t 'steps
                   (foldr (\ b acc (? (<b = 'in) (expand b + acc) (b . acc))) () (t 'body))))
       [os (rev (orph 'l))])

   ;; --- 64-bit words. & is wrong on a bignum >= 2^63, so the bit ops go by 32-bit halves
   kl-m64 18446744073709551616
   kl-m32 4294967296
   (kl-w v) (: r (v % kl-m64) (? (r < 0) (r + kl-m64) r))
   (kl-bits f a b) (: x (kl-w a) y (kl-w b)
                     (f (x // kl-m32) (y // kl-m32) * kl-m32 + f (x % kl-m32) (y % kl-m32)))
   (kl-and a b) (kl-bits (&) a b)
   (kl-or a b) (kl-bits (|) a b)
   (kl-xor a b) (kl-bits (^) a b)
   (kl-not a) (kl-m64 - 1 - kl-w a)
   (kl-al v a) (? (a < 2) v (: r (v % a) (? (r = 0) v (v + a - r))))   ; align up

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

   ;; --- the script's expressions, over a layout env:
   ;     'dot, 'sv script symbols, 'osv output sections by name -> [addr size lma align],
   ;     'gv a fn nom -> an object symbol's value or ()
   (kl-sym env nom)
    (: v (peep (env 'sv) nom ())
       (? (whole? v) v
          (: g ((env 'gv) nom) (? (whole? g) g (: _ (pin env 'undef 1) 0)))))
   (kl-osv env nm k) (: r (peep (env 'osv) nm ()) (? (two? r) (r k) (: _ (pin env 'undef 1) 0)))
   (kl-ev env e)
    (? (whole? e) (kl-w e)
       (string? e) (? (e = ".") (env 'dot) (kl-sym env e))
       (: o <e (a u) (kl-ev env (e 1)) (b u) (kl-ev env (e 2))
          (? (o = '+) (kl-w (a 0 + b 0)) (o = '-) (kl-w (a 0 - b 0)) (o = '*) (kl-w (a 0 * b 0))
             (o = '/) (? (b 0 = 0) (scare 'klink-div e) (a 0 // b 0))
             (o = '%) (? (b 0 = 0) (scare 'klink-div e) (a 0 % b 0))
             (o = '<<) (kl-w (a 0 * 2 ** b 0)) (o = '>>) (a 0 // 2 ** b 0)
             (o = '&) (kl-and (a 0) (b 0)) (o = '|) (kl-or (a 0) (b 0)) (o = '^) (kl-xor (a 0) (b 0))
             (o = '==) (? (a 0 = b 0) 1 0) (o = '!=) (? (a 0 = b 0) 0 1)
             (o = '<) (? (a 0 < b 0) 1 0) (o = '<=) (? (a 0 <= b 0) 1 0)
             (o = '>) (? (a 0 > b 0) 1 0) (o = '>=) (? (a 0 >= b 0) 1 0)
             (o = '&&) (? (a 0 != 0 && b 0 != 0) 1 0) (o = '||) (? (a 0 != 0 || b 0 != 0) 1 0)
             (o = 'neg) (kl-w (0 - a 0)) (o = 'not) (? (a 0 = 0) 1 0) (o = 'cpl) (kl-not (a 0))
             (o = '?) (? (a 0 != 0) (b 0) (kl-ev env (e 3)))
             (o = 'call) (kl-call env (e 1) (e 2))
             (scare 'klink-op o))))
   (kl-call env f as)
    (: (x i) (kl-ev env (as i)) nm as
       (? (f = "ALIGN") (? (#as = 1) (kl-al (env 'dot) (x 0)) (kl-al (x 0) (x 1)))
          (f = "ABSOLUTE") (x 0)
          (f = "ADDR") (kl-osv env (nm 0) 0)
          (f = "SIZEOF") (kl-osv env (nm 0) 1)
          (f = "LOADADDR") (kl-osv env (nm 0) 2)
          (f = "ALIGNOF") (kl-osv env (nm 0) 3)
          (f = "DEFINED") (? (whole? (peep (env 'sv) (nm 0) ()) || whole? ((env 'gv) (nm 0))) 1 0)
          (f = "MAX") (? (x 0 > x 1) (x 0) (x 1))
          (f = "MIN") (? (x 0 < x 1) (x 0) (x 1))
          (f = "SEGMENT_START") (x 1)
          (f = "CONSTANT") (? (nm 0 = "MAXPAGESIZE") 65536 (nm 0 = "COMMONPAGESIZE") 4096 (scare 'klink-constant (nm 0)))
          (scare 'klink-call f)))
   ; the section names an expression reads by ADDR or LOADADDR, which keep one though empty
   (kl-named e acc)
    (? (atom? e) acc
       (<e = 'call && elem (e 1) '("ADDR" "LOADADDR")) ((e 2 0) . acc)
       (foldl (\ a x (kl-named x a)) acc >e))

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

   ;; --- layout: the script's commands in order, SECTIONS inline, in passes until every
   ;     address holds still; the ASSERTs are checked on the last. synth [(name size align
   ;     type flags) ..]. answers the env: 'sv 'osv 'isa isec key -> address, 'msa merge id ->
   ;     address; each output section tablet gains 'dead, or 'va 'sz 'la 'al 'flags 'stype
   (kl-lay cx cmds mx synth)
    (: ot (: t {} _ (foldl (\ i ob (pin t i ob, i + 1)) 0 (cx 'objs)) t)
       glob (cx 'glob) und (cx 'und) ms (mx 'ms) im (mx 'im)
       sy (: t {} _ (each synth (s \ pin t <s s)) t)
       flat (foldr (\ c acc (? (<c = 'sections) (<>c + acc) (c . acc))) () cmds)
       named (foldl (\ a c (? (<c = 'osec)
                              (: t <>c (kl-named [(t 'addr) (t 'lma) (t 'align) (t 'body)] a))
                              (kl-named c a)))
                    () flat)
       (mflags x) (? (<x = 'isec) (ot (x 1) 'sec (x 2) 2) (<x = 'synth) (sy (x 1) 4)
                     (<x = 'msec) (ms (x 1) 'flags) -1)
       (mtype x) (? (<x = 'isec) (ot (x 1) 'sec (x 2) 1) (<x = 'synth) (sy (x 1) 3) (ms (x 1) 'type))
       (malign x) (? (<x = 'isec) (x 4) (<x = 'synth) (x 3) (ms (x 1) 'align))
       (ments x) (? (<x = 'isec) (ot (x 1) 'sec (x 2) 6) (<x = 'synth) (: y (sy (x 1) 3) (? (y = 4) 24 (y = 19) 8 0))
                    (ms (x 1) 'entsize))
       (held? b) ((<b = 'set && b 1 != ".") || <b = 'data)
       osof {} mof {}                                 ; isec key, merge id -> output section
       _ (foldl (\ pf c
                  (? (<c != 'osec) pf
                     (: t <>c mem (filter (x \ mflags x >= 0) (t 'steps))
                        (? (t 'name = "/DISCARD/"
                            || (atom? mem && !(elem (t 'name) named) && !(any held? (t 'body))))
                           (: _ (pin t 'dead 1) pf)
                           (: fl (? (atom? mem) (pf & 7) (foldl (\ a x (a | mflags x)) 0 mem))
                              ty (: ts (map mtype mem) nb (filter (y \ y != 8) ts)
                                    (? (atom? ts) 1 (atom? nb) 8 <nb))
                              _ (pin t 'flags fl, pin t 'stype ty,
                                 pin t 'malign (foldl (\ a x (max a (malign x))) 1 mem),
                                 pin t 'entsize (? (atom? mem) 0
                                                   (: e (ments <mem) (? (all (x \ ments x = e) mem) e 0))))
                              _ (each mem (x \ (? (<x = 'isec) (pin osof (x 1 * 65536 + x 2) (t 'name))
                                                  (<x = 'msec) (pin mof (x 1) (t 'name)) 0)))
                              fl)))))
                0 flat)
       env {'dot 0 'sv {} 'osv {} 'isa {} 'msa {} 'undef 0 'osof osof 'mof mof 'ssec {} 'stype {} 'cur ()}
       isa (env 'isa) msa (env 'msa) sv (env 'sv) ssec (env 'ssec) stype (env 'stype)
       ; the address of byte off of input section si of object oi, or () if not laid
       (at oi si off)
        (: k (oi * 65536 + si) a (peep isa k ())
           (? (whole? a) (a + off)
              (: m (peep im k ())
                 (? (two? m)
                    (: (go l) (? (atom? >l) l (<(<>l) > off) l (go >l))
                       p <(go <>m)
                       (msa <m + p 1 + off - <p))
                    ()))))
       (gv nom)
        (: g (peep glob nom ())
           (? (atom? g) ()
              (: r (ot <g 'syms (g 1)) sh (r 3)
                 (? (sh = 65521) (r 4) (at <g sh (r 4))))))
       _ (pin env 'gv gv, pin env 'at at)
       ; the output section a value is relative to, () when absolute, as lld carries it:
       ; + and & | keep the relative side, a difference of two relatives is absolute,
       ; ALIGN(x, a) keeps x's, ADDR names its section, and . is the last section's
       (osec-of oi sh) (? (sh = 65521 || sh = 0) () (: k (oi * 65536 + sh) n (peep osof k ())
                                                     (? (string? n) n
                                                        (: m (peep im k ()) (? (two? m) (peep mof <m ()) ())))))
       (symsec nom)
        (? (whole? (peep sv nom ())) (: q (peep ssec nom ()) (? (string? q) q ()))
           (: g (peep glob nom ()) (? (two? g) (osec-of <g (ot <g 'syms (g 1) 3)) ())))
       (secof e)
        (? (whole? e) ()
           (string? e) (? (e = ".") (env 'cur) (symsec e))
           (: o <e (a u) (secof (e 1)) (b u) (secof (e 2))
              (? (o = '+ || o = '& || o = '|) (: x (a 0) (? (string? x) x (b 0)))
                 (o = '-) (: x (a 0) (? (string? x && !(string? (b 0))) x ()))
                 (o = '?) (? (kl-ev env (e 1) != 0) (b 0) (secof (e 3)))
                 (o = 'call) (? (e 1 = "ALIGN" && #(e 2) = 2) (secof (e 2 0))
                                (e 1 = "ADDR") (e 2 0)
                                ())
                 ())))
       ; a symbol assigned a symbol takes its type
       (typeof e) (? (!(string? e) || e = ".") 0
                     (whole? (peep sv e ())) (peep stype e 0)
                     (: g (peep glob e ()) (? (two? g) (ot <g 'syms (g 1) 2) 0)))
       (setsym nm v e) (: _ (pin sv nm v, pin ssec nm (secof e)) (pin stype nm (typeof e)))
       (ev e) (kl-ev env e)
       (dot u) (env 'dot)
       (setdot v) (pin env 'dot v)
       (op2 op a b) (? (op = '=) b (op = '+=) (kl-w (a + b)) (op = '-=) (kl-w (a - b))
                       (op = '*=) (kl-w (a * b)) (op = '/=) (a // b)
                       (op = '<<=) (kl-w (a * 2 ** b)) (op = '>>=) (a // 2 ** b)
                       (op = '&=) (kl-and a b) (op = '|=) (kl-or a b) (scare 'klink-assign op))
       (cmd final c)
        (: k <c
           (? (k = 'set) (: nm (c 1) v (ev (c 3))
                            (? (nm = ".") (setdot (op2 (c 2) (dot 0) v))
                               (setsym nm (op2 (c 2) (peep sv nm 0) v) (c 3))))
              (k = 'provide) (? (peep und (c 1) 0 > 0) (setsym (c 1) (ev (c 2)) (c 2)) 0)
              (k = 'assert) (? (final && ev (c 1) = 0) (scare 'klink-assert (c 2)) 0)
              (k = 'data) (setdot (dot 0 + c 1))
              (k = 'osec) (? (peep <>c 'dead 0) 0 (lay final <>c))
              0))
       (step final x)
        (: k <x
           (? (k = 'isec) (: a (kl-al (dot 0) (x 4)) _ (pin isa (x 1 * 65536 + x 2) a) (setdot (a + x 3)))
              (k = 'synth) (: a (kl-al (dot 0) (x 3)) _ (pin isa (x 1) a) (setdot (a + sy (x 1) 1)))
              (k = 'msec) (: m (ms (x 1)) a (kl-al (dot 0) (m 'align)) _ (pin msa (x 1) a)
                             (setdot (a + m 'size)))
              (cmd final x)))
       (lay final t)
        (: alloc (0 < (t 'flags & 2)) saved (dot 0)
           _ (pin env 'cur (t 'name))
           _ (setdot (? (two? (t 'addr) || whole? (t 'addr) || string? (t 'addr)) (ev (t 'addr))
                        alloc (dot 0) 0))
           al (max (t 'malign) (? (atom? (t 'align)) (? (whole? (t 'align)) (t 'align) 1) (ev (t 'align))))
           a (kl-al (dot 0) al)
           _ (setdot a)
           lma (? (atom? (t 'lma)) a (ev (t 'lma)))
           _ (pin (env 'osv) (t 'name) [a 0 lma al])
           _ (each (t 'steps) (step final))
           z (dot 0 - a)
           _ (pin t 'va a, pin t 'sz z, pin t 'la lma, pin t 'al al)
           _ (pin (env 'osv) (t 'name) [a z lma al])
           (? alloc 0 (setdot saved)))
       (snap u) (map (c \ (? (<c = 'osec && !(peep <>c 'dead 0)) [(<>c 'va) (<>c 'sz)] 0)) flat)
       (pass final) (: _ (setdot 0, pin env 'undef 0, pin env 'cur ()) _ (each flat (cmd final)) (snap 0))
       (go n prev)
        (: s (pass 0)
           (? (s = prev) (: _ (pass 1) env)
              (n > 12) (scare 'klink-unsettled n)
              (go (n + 1) s)))
       (go 0 ()))

   ;; --- relocation. a -shared -Bsymbolic image binds every definition home, so an ABS64 in
   ;     an allocated section is a load-time slide: a RELR entry where the site is even in a
   ;     section aligned to 2 or more, else a RELATIVE in .rela.dyn whose field stays 0. a weak
   ;     undefined is an ABS64 against symbol 0. lk: {'cx 'ot 'env 'mx 'outs}
   (kl-isecs outs) (foldl (\ acc t (? (peep t 'dead 0 || t 'name = "/DISCARD/") acc
                                     (foldl (\ a x (? (<x = 'isec) (x . a) a)) acc (t 'steps))))
                          () outs)
   ; S + A for entry e of object oi, () for a weak undefined
   (kl-sa lk oi e)
    (: ob (lk 'ot oi) sy (ob 'syms (e 2)) sh (sy 3) a (e 3) env (lk 'env) at (env 'at)
       (none u) (scare 'klink-dropped [(ob 'id) <sy])
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
           (each (peep (ob 'rela) si ())
              (e \ (? (e 1 != 257) 0
                      (wu? ob e) (pin rela 'l ([key e 1] . rela 'l))
                      (r 5 >= 2 && <e % 2 = 0) (pin relr 'l ([key <e] . relr 'l))
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
   ; one input section's bytes with its relocations applied -> pieces, reversed onto acc
   (kl-patch lk x acc)
    (: oi (x 1) si (x 2) ob (lk 'ot oi) r (ob 'sec si) s (ob 'src) o0 (r 3) sz (r 4)
       base (lk 'env 'isa (oi * 65536 + si)) be (backends 'a64)
       ; a weak undefined: a branch falls to the next instruction, a pc-relative field reads
       ; the place, an absolute one the addend
       (weak k p a) (? (elem k '(279 280 282 283)) (p + 4 + a) (elem k '(260 261 273 274 275)) (p + a) a)
       (field e) (: ro <e k (e 1) p (base + ro) s0 (kl-sa lk oi e)
                    sa (? (whole? s0) s0 (weak k p (e 3)))
                    (? (k = 257)
                       (? (!(whole? s0) || !(r 5 >= 2 && ro % 2 = 0)) (kl-le 0 8) (kl-le sa 8))
                       (k = 258) (? (sa < 4294967296) (kl-le sa 4) (scare 'klink-range [(ob 'id) ro]))
                       (k = 260) (kl-le (sa - p) 8)
                       (k = 261) (: v (sa - p)
                                    (? (-2147483648 <= v && v < 2147483648) (kl-le v 4)
                                       (scare 'klink-range [(ob 'id) ro])))
                       (: c (lda64-kinds k)
                          _ (? (two? c) 0 (scare 'klink-reloc [(ob 'id) k]))
                          f (refix-with be <c (map (i \ s (o0 + ro + i)) ^4) sa p 4)
                          (? (two? f) f (scare 'klink-range [(ob 'id) ro k])))))
       ; lld's relaxation: adrp xn, sym; add xn, xn, :lo12:sym, neither addended, sym within
       ; 1 MiB of the add -> nop; adr xn, sym. answers the 8 bytes, or ()
       (relax e f)
        (: ro <e i1 (kl-u32 s (o0 + ro)) i2 (kl-u32 s (o0 + ro + 4)) rd (i1 % 32)
           (? (e 1 = 275 && two? f && f 1 = 277 && <f = ro + 4 && e 2 = f 2 && e 3 = 0 && f 3 = 0
               && (i1 & 2667577344) = 2415919104 && (i2 & 4290772992) = 2432696320
               && i2 % 32 = rd && (i2 >> 5) % 32 = rd)
              (: v (kl-sa lk oi e) p (base + ro + 4)
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
   ; an output section's pieces; lk 'sdata synthetic name -> [size pieces]
   (kl-emit lk t)
    (: env (lk 'env) isa (env 'isa) ms (lk 'mx 'ms) end (t 'va + t 'sz)
       (go l cur acc)
        (? (atom? l) (rev (kl-zp (end - cur) acc))
           (: x <l k <x
              (? (k = 'isec) (: a (isa (x 1 * 65536 + x 2))
                                (go >l (a + x 3) (kl-patch lk x (kl-zp (a - cur) acc))))
                 (k = 'synth) (: a (isa (x 1)) d (lk 'sdata (x 1))
                                 (go >l (a + <d) (rev <>d + kl-zp (a - cur) acc)))
                 (k = 'msec) (: m (ms (x 1)) a (env 'msa (x 1))
                                (go >l (a + m 'size) (kl-mbytes m (kl-zp (a - cur) acc))))
                 (k = 'data) (: _ (pin env 'dot cur) (go >l (cur + x 1) (kl-le (kl-ev env (x 2)) (x 1) . acc)))
                 (k = 'set && x 1 = ".")
                  (: _ (pin env 'dot cur) v (kl-ev env (x 3))
                     (go >l v (kl-zp (v - cur) acc)))
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
       (addstr nm) (: o (str 'n) _ (pin str 'n (o + #nm + 1), pin str 'l ("\0" . nm . str 'l)) o)
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
                                (? (r 1 != 0 || r 2 = 3 || r 3 = 0 || starts? <r ".L") 0
                                   (r 3 = 65521) (put oi (ent <r (r 4) (r 5) (r 2) 0 65521))
                                   (: n (oname oi (r 3)) q (ob 'sec (r 3))
                                      (? (string? n) (put oi (ent <r (at oi (r 3) (r 4)) (r 5) (r 2) 0 (shx n)))
                                         ; a debug section --strip-debug dropped leaves its locals absolute
                                         (lk 'strip && 0 = (q 2 & 2) && kl-debug? <q) (put oi (ent <r (r 4) (r 5) (r 2) 0 65521))
                                         0)))))))))
       seen {}
       names (rev (foldl (\ a n (? (peep seen n 0) a (: _ (pin seen n 1) (n . a)))) () (cx 'order + kl-sorder lk)))
       (gl nm)
        (: v (peep sv nm ())
           (? (whole? v) (: q (peep ssec nm ())
                            (pin glo 'l (ent nm v 0 (16 + peep (env 'stype) nm 0) 0 (? (string? q) (shx q) 65521) . glo 'l)))
              (: g (peep glob nm ())
                 (? (two? g)
                    (: oi <g r (ot oi 'syms (g 1)) vis (r 6 % 4) n (oname oi (r 3))
                       vs (? (r 3 = 65521) [(r 4) 65521] (string? n) [(at oi (r 3) (r 4)) (shx n)] [0 0])
                       (? (vis = 1 || vis = 2) (put oi (ent nm <vs (r 5) (r 2) vis (vs 1)))
                          (pin glo 'l (ent nm <vs (r 5) (r 1 * 16 + r 2) vis (vs 1) . glo 'l))))
                    (peep und nm 0 > 0) (pin glo 'l (ent nm 0 0 (und nm * 16) 0 0 . glo 'l))
                    0))))
       _ (each names gl)
       locs (cats (map (oi \ rev (groups oi)) (rev (gord 'l))))
       es (locs + rev (glo 'l))
       (row e) (cask (kl-le <e 4 + [(e 3) (e 4)] + kl-le (e 5) 2 + kl-le (e 1) 8 + kl-le (e 2) 8))
       [(#locs + 1) ([(kl-le 0 24)] + map row es) (str 'n) ("\0" . rev (str 'l))])

   ;; --- the image, as lld lays it: a PT_LOAD per run of sections with one set of
   ;     permissions, a new one at each AT(); an empty section opens none. a load's first
   ;     section sits at a file offset congruent to its address mod 64K, the rest follow by
   ;     address. each section is written as it is emitted; answers the file's size
   ; the build-id, once kl-elf has written path: sha256's first 20 bytes over the file with
   ; the field still zero, written into the .note.gnu.build-id kl-elf left zero
   (kl-buildid lk path)
    (: a (lk 'env 'isa ".note.gnu.build-id")
       t <(filter (t \ !(peep t 'dead 0) && 0 < (t 'flags & 2) && t 'va <= a && a < t 'va + t 'sz) (lk 'outs))
       off (t 'off + a - t 'va + 16)
       h (sha256 <>(uread path))
       (d c) (? (c < 58) (c - 48) (c - 87))
       id (map (i \ d (h (2 * i)) * 16 + d (h (2 * i + 1))) ^20)
       (openfd path 4 @ fd
          (? (charm? fd && fd >= 0) (lseek fd off 0, fdopen fd @ q (say q (string id), close q), id)
             (scare 'klink-buildid path))))

   (kl-elf lk entry path)
    (: outs0 (filter (t \ !(peep t 'dead 0) && t 'name != "/DISCARD/") (lk 'outs))
       shx (: t {} _ (foldl (\ i x (pin t (x 'name) i, i + 1)) 1 (outs0 + [{'name ".symtab"} {'name ".strtab"}])) t)
       st (kl-symtab lk (n \ shx n))
       outs (outs0 + [{'name ".symtab" 'stype 2 'flags 0 'al 8 'sz (24 * #(st 1)) 'entsize 24
                       'link (#outs0 + 2) 'info <st 'pieces (st 1)}
                      {'name ".strtab" 'stype 3 'flags 0 'al 1 'sz (st 2) 'pieces (st 3)}])
       (alloc? t) (0 < (t 'flags & 2))
       (perm t) (4 + (? (0 < (t 'flags & 1)) 2 0) + (? (0 < (t 'flags & 4)) 1 0))
       (at? t) (? (atom? (t 'lma)) (whole? (t 'lma)) 1)
       ; loads [[first last] ..]
       loads (rev (foldl (\ acc t
                            (? (!(alloc? t) || t 'sz = 0) acc
                               (atom? acc || at? t || perm t != perm (<(<acc))) ([t t] . acc)
                               ([(<(<acc)) t] . >acc)))
                         () outs))
       _ (each loads (l \ each outs (t \ (? (t 'va >= <l 'va && alloc? t && t 'sz > 0
                                                && t 'va <= (l 1) 'va && !(peep t 'load 0))
                                             (pin t 'load l) 0))))
       nph (#loads + 1)
       names (foldl (\ a t (a + t 'name + "\0")) "\0" outs)
       shn (names + ".shstrtab\0")
       _ (foldl (\ o t
                  (: f (peep t 'load ())
                     off (? (two? f && <f 'name = t 'name) (o + (t 'va - o) % 65536)
                            (two? f) (<f 'off + t 'va - <f 'va)
                            (kl-al o (t 'al)))
                     _ (pin t 'off off)
                     (off + (? (t 'stype = 8) 0 (t 'sz)))))
                (64 + 56 * nph) outs)
       last (: l <(rev outs) (l 'off + (? (l 'stype = 8) 0 (l 'sz))))
       shso last
       shoff (kl-al (shso + #shn) 8)
       shnum (#outs + 2)
       (w2 n) (kl-le n 2) (w4 n) (kl-le n 4) (w8 n) (kl-le n 8)
       eh (cats [[127 69 76 70 2 1 1 0 0 0 0 0 0 0 0 0] (w2 3) (w2 183) (w4 1) (w8 entry) (w8 64) (w8 shoff)
                 (w4 0) (w2 64) (w2 56) (w2 nph) (w2 64) (w2 shnum) (w2 (shnum - 1))])
       (ph l) (: a <l b (l 1) fe (b 'off + (? (b 'stype = 8) 0 (b 'sz)))
                 (cats [(w4 1) (w4 (perm a)) (w8 (a 'off)) (w8 (a 'va)) (w8 (a 'la))
                        (w8 (fe - a 'off)) (w8 (b 'va + b 'sz - a 'va)) (w8 65536)]))
       phs (map ph loads + [(cats [(w4 1685382481) (w4 6) (w8 0) (w8 0) (w8 0) (w8 0) (w8 0) (w8 0)])])
       nmoff (: t {} _ (foldl (\ o x (pin t (x 'name) o, o + #(x 'name) + 1)) 1 outs) t)
       (sh t) (cats [(w4 (nmoff (t 'name))) (w4 (t 'stype)) (w8 (t 'flags)) (w8 (? (alloc? t) (t 'va) 0)) (w8 (t 'off))
                     (w8 (t 'sz)) (w4 (peep t 'link 0)) (w4 (peep t 'info 0)) (w8 (t 'al)) (w8 (peep t 'entsize 0))])
       shs ([(kl-le 0 64)] + map sh outs
            + [(cats [(w4 #names) (w4 3) (w8 0) (w8 0) (w8 shso) (w8 #shn) (w4 0) (w4 0) (w8 1) (w8 0)])])
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
       e (body (64 + 56 * nph) outs)
       _ (put (rev (kl-zp (shso - e) ())), put [shn], put (rev (kl-zp (shoff - shso - #shn) ())), put shs)
       _ (close q)
       (shoff + 64 * shnum))
)
) ; module 'holo
