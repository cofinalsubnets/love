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
       {'id id 'src s 'shnum shnum 'sec sec 'syms syms 'nsym nsym 'rela rela})

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

   ;; --- inputs in lld's order. items: ('whole path) ('obj path) ('group (path ..)).
   ;     a group's members are fetched as a strong undefined names them, depth first, and
   ;     stay fetchable for every later input. answers the link's tablet:
   ;     'objs [ob ..] in order, 'glob nom -> [oi si] the definition, 'und nom -> 1|2 (bind)
   (kl-load items)
    (: cx {'objs () 'n 0 'glob {} 'und {} 'lazy {}}
       glob (cx 'glob) und (cx 'und) lazy (cx 'lazy)
       (add ob)
        (: oi (cx 'n)
           _ (pin cx 'n (oi + 1), pin cx 'objs (ob . cx 'objs))
           sy (ob 'syms)
           _ (each ^(ob 'nsym)
              (si \ (: r (sy si) nom <r bind (r 1) sh (r 3)
                       (? (bind = 0 || #nom = 0) 0
                          (sh != 0)
                           (: cur (peep glob nom ())
                              (? (atom? cur) (pin glob nom [oi si], pin und nom 0)
                                 (bind = 1 && ((cx 'objs) ((cx 'n) - 1 - <cur)) 'syms (cur 1) 1 = 2)
                                  (pin glob nom [oi si])
                                 0))
                          (two? (peep glob nom ())) 0
                          (: u (peep und nom 0)
                             _ (pin und nom (? (u = 1 || bind = 1) 1 2))
                             (? (bind = 1) (fetch nom) 0))))))
           oi)
       (fetch nom)
        (: m (peep lazy nom ())
           (? (two? m) (: ar <m mi <>m
                          (? (peep (ar 'taken) mi 0) 0
                             (: mem ((ar 'members) mi)
                                (pin (ar 'taken) mi 1, add (kl-read <mem <>mem)))))
              0))
       _ (each items
          (it \ (: k <it
                   (? (k = 'obj) (add (kl-read <>it <>(uread <>it)))
                      (k = 'whole) (each ((kl-ar <>it) 'members) (m \ add (kl-read <m <>m)))
                      (k = 'group)
                       (: ars (map (p \ (: a (kl-ar p) (pin a 'taken {}, a))) <>it)
                          _ (each ars (a \ each (keys (a 'index))
                                         (nom \ (? (two? (peep lazy nom ())) 0
                                                   (pin lazy nom [a ((a 'index) nom)])))))
                          (each ars (a \ (: ix (a 'index)
                                            (each (sort (map (nom \ [(ix nom) nom]) (keys ix)))
                                               (p \ (? (peep und <>p 0 = 1) (fetch <>p) 0)))))))
                      (scare 'klink-input k)))))
       _ (pin cx 'objs (rev (cx 'objs)))
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
   ;     align are one synthetic section at the first's place, each distinct piece once, in
   ;     first-seen order. answers 'ms id -> {'size 'align 'flags 'entsize 'type 'tab piece -> off}
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
                          _ (pin ms id {'size 0 'align (r 5) 'palign (r 5) 'flags (r 2) 'entsize (r 6)
                                        'type (r 1) 'tab {}})
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
                        (place p) (: key (snip src <p <>p) o (peep tab key -1)
                                     (? (o >= 0) [(<p - r 3) o]
                                        (: o (kl-al (m 'size) (m 'palign))
                                           _ (pin tab key o, pin m 'size (o + <>p - <p))
                                           [(<p - r 3) o])))
                        _ (pin im (oi * 65536 + si) [id (map place (kl-pieces src (r 3) (r 4) (r 6) str))])
                        (? (f >= 0) acc (['msec id] . acc))))))
           (pin t 'steps (rev (foldl step () (t 'steps)))))
       _ (each outs one)
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
       (held? b) ((<b = 'set && b 1 != ".") || <b = 'data)
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
                                 pin t 'malign (foldl (\ a x (max a (malign x))) 1 mem))
                              fl)))))
                0 flat)
       env {'dot 0 'sv {} 'osv {} 'isa {} 'msa {} 'undef 0}
       isa (env 'isa) msa (env 'msa) sv (env 'sv)
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
       _ (pin env 'gv gv)
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
                               (pin sv nm (op2 (c 2) (peep sv nm 0) v))))
              (k = 'provide) (? (peep und (c 1) 0 > 0) (pin sv (c 1) (ev (c 2))) 0)
              (k = 'assert) (? (final && ev (c 1) = 0) (scare 'klink-assert (c 2)) 0)
              (k = 'data) (setdot (dot 0 + c 1))
              (k = 'osec) (? (peep <>c 'dead 0) 0 (lay final <>c))
              0))
       (step final x)
        (: k <x
           (? (k = 'isec) (: a (kl-al (dot 0) (x 4)) _ (pin isa (x 1 * 65536 + x 2) a) (setdot (a + x 3)))
              (k = 'synth) (: a (kl-al (dot 0) (x 3)) _ (pin isa (x 1) a) (setdot (a + x 2)))
              (k = 'msec) (: m (ms (x 1)) a (kl-al (dot 0) (m 'align)) _ (pin msa (x 1) a)
                             (setdot (a + m 'size)))
              (cmd final x)))
       (lay final t)
        (: alloc (0 < (t 'flags & 2)) saved (dot 0)
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
       (pass final) (: _ (setdot 0, pin env 'undef 0) _ (each flat (cmd final)) (snap 0))
       (go n prev)
        (: s (pass 0)
           (? (s = prev) (: _ (pass 1) env)
              (n > 12) (scare 'klink-unsettled n)
              (go (n + 1) s)))
       (go 0 ()))
)
