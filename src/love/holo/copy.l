; src/love/holo/copy.l -- objcopy: a linked elf flattened to the bytes a flash tool takes,
; or any elf written again with sections dropped, renamed or flagged and symbols prefixed or
; dropped, byte for byte as llvm-objcopy writes it. `-O binary` is the image from the lowest
; load address, `-O ihex` the same image in Intel hex. `love objcopy` is the applet.
;
; a flasher wants the load address, not sh_addr: each section maps through the PT_LOAD
; holding its file bytes, lma = p_paddr + (off - p_offset). matching by file offset keeps
; two lanes sharing a vaddr apart.
;
; a hex record never spans two sections, as in gnu objcopy, so output compares by bytes.
;
; loads after src/love/holo/link.l, whose field table, ld-write and ld-zeros it reads.
(module 'holo
(borrow '(kore posix))

(:
   ;; the pt_loads as (fileoff filesz paddr)
   (oc-segs fs s)
    (: n (ld-f fs s 0 'e-phnum) po (ld-f fs s 0 'e-phoff) e (ld-n fs 'ph-ent)
       (rev (foldl (\ acc i (po + i * e @ h
                               (ld-f fs s h 'ph-type = 1 ?
                                  ([(ld-f fs s h 'ph-off) (ld-f fs s h 'ph-fsz) (ld-f fs s h 'ph-pa)] . acc)
                                  acc)))
                   () ^n)))
   (oc-lma id segs off)
    (: (go ps) (atom? ps ? (scare 'copy-unmapped-section off)
                  (<ps @ p
                     (<p <= off && off < <p + p 1 ? (p 2 + (off - <p))
                        (go >ps))))
       (go segs))

   ;; -> ((lma fileoff size).. in lma order, entry): every SHF_ALLOC section with file
   ;; bytes. the test is not-NOBITS, not is-PROGBITS: .note, .dynsym and .rela.dyn load too.
   (oc-read id s drop only)
    (: _ (s 0 = 127 && s 1 = 69 && s 2 = 76 && s 3 = 70 ? 0
            (scare 'copy-not-elf id))
       fs (? (s 4 = 2) elf64f (s 4 = 1) elf32f (scare 'copy-elf-class id))
       ; both tables are required: an image without section headers (elf.l's writer)
       ; is refused, not guessed at. counts before entsizes, which read 0 for a missing table.
       shnum (ld-f fs s 0 'e-shnum) phnum (ld-f fs s 0 'e-phnum)
       _ (0 < shnum ? 0 (scare 'copy-no-sections id))
       _ (0 < phnum ? 0 (scare 'copy-no-segments id))
       _ (ld-f fs s 0 'e-shent = ld-n fs 'sh-ent ? 0 (scare 'copy-shentsize id))
       _ (ld-f fs s 0 'e-phent = ld-n fs 'ph-ent ? 0 (scare 'copy-phentsize id))
       segs (oc-segs fs s)
       _ (two? segs ? 0 (scare 'copy-no-load id))
       shoff (ld-f fs s 0 'e-shoff)
       shstro (ld-f fs s (shoff + ld-f fs s 0 'e-shstrx * ld-n fs 'sh-ent) 'sh-off)
       ; -R drops a section by name, -j keeps only those named
       (want? h) (: nm (ld-cstr s (shstro + ld-f fs s h 'sh-name))
                    (? (oe-match? drop nm 1) () (two? only) (oe-match? only nm 1) 1))
       (go i acc)
        (shnum <= i ? acc
           (: h (shoff + i * ld-n fs 'sh-ent)
              ty (ld-f fs s h 'sh-type) fl (ld-f fs s h 'sh-flags)
              off (ld-f fs s h 'sh-off) sz (ld-f fs s h 'sh-size)
              keep (!(ty = 8) && 0 < fl & 2 && 0 < sz && want? h)
              (go (i + 1) (keep ? ([(oc-lma id segs off) off sz] . acc) acc))))
       secs (go 1 ())
       (two? secs ? 0 (scare 'copy-nothing id),
        [(sortby (\ a b (<a <= <b)) secs) (ld-f fs s 0 'e-entry)]))

   ;; the section named nm in a linked elf, as (file-offset size), or (). (rd o n) answers
   ;; the n bytes at o, so only the header, section table and names are read --
   ;; (\ o n (snip s o (o + n))) over bytes in hand
   (elf-sec-at rd nm) (rd 0 64 @ hd (#hd < 52 || !(hd 0 = 127 && hd 1 = 69) ? () (es-at rd nm hd)))
   (es-at rd nm hd)
    (: fs (hd 4 = 1 ? elf32f elf64f)
       e (ld-n fs 'sh-ent) shnum (ld-f fs hd 0 'e-shnum)
       tab (rd (ld-f fs hd 0 'e-shoff) (shnum * e))
       (f i k) (ld-f fs tab (i * e) k)
       sx (ld-f fs hd 0 'e-shstrx)
       strs (#tab < shnum * e || shnum <= sx ? "" (rd (f sx 'sh-off) (f sx 'sh-size)))
       (go i) (? (shnum <= i) ()
                 (ld-cstr strs (f i 'sh-name) = nm) [(f i 'sh-off) (f i 'sh-size)]
                 (go (i + 1)))
       (#strs ? (go 1) ()))

   ;; -- the flat image, as pieces for ld-write; a gap between sections is zeros
   (oc-bin s secs)
    (: (go l pos acc)
        (atom? l ? (rev acc)
           (: c <l a <c o (c 1) n (c 2)
              (a < pos ? (scare 'copy-overlap a) 0,
               go >l (a + n)
                  (snip s o (o + n) . (pos < a ? (ld-zeros (a - pos) . acc) acc)))))
       (go secs (<secs 0) ()))

   ;; -- Intel hex: ":" ll AAAA tt dd.. CC, each byte two hex digits, CC the two's
   ;; complement of the sum before it; 01 ends, and an entry of 0 writes no start record.
   ;; the high address bits ride a base record: under 1 MB an 8086 segment (02, base >> 4),
   ;; above it a linear upper half (04). the two sum, so climbing past 1 MB zeroes the
   ;; segment first. a data record stops at a 64K line. lines end crlf.
   oc-digits "0123456789ABCDEF"
   oc-pairs (foldl (\ a b (a + snip oc-digits (b >> 4) ((b >> 4) + 1)
                             + snip oc-digits (b & 15) ((b & 15) + 1)))
                   "" ^256)
   (oc-x2 b) (snip oc-pairs (b + b) (b + b + 2))
   (oc-cat ls) (foldl (+) "" ls)
   (oc-rec ty addr bs)
    (: all ([#bs (addr >> 8 & 255) (addr & 255) ty] + bs)
       ck ((256 - foldl (+) 0 all % 256) % 256)
       (oc-cat (":" . (map oc-x2 (all + [ck]) + '("\r\n")))))
   (oc-be4 v) [(v >> 24 & 255) (v >> 16 & 255) (v >> 8 & 255) (v & 255)]
   ;; the entry likewise: 03 is cs:ip under 1 MB, 05 the flat address above
   (oc-start e)
    (0xFFFFF < e ? (oc-rec 5 0 (oc-be4 e))
       (oc-rec 3 0 [((e >> 16 & 15) << 4) 0 (e >> 8 & 255) (e & 255)]))
   (oc-chunks secs)
    (: (go a o left acc)
        (left < 1 ? acc
           (: room (65536 - a % 65536)
              m (16 < left ? 16 left)
              n (room < m ? room m)
              (go (a + n) (o + n) (left - n) ([a o n] . acc))))
       (rev (foldl (\ acc c (go <c (c 1) (c 2) acc)) () secs)))
   (oc-b02 nb) (oc-rec 2 0 [(nb >> 12 & 255) (nb >> 4 & 255)])
   (oc-b04 nb) (oc-rec 4 0 [(nb >> 24 & 255) (nb >> 16 & 255)])
   ;; base is the 64K window in force, sg whether a segment base is standing in it
   (oc-ihex s secs entry)
    (: (go l base sg acc)
        (atom? l ?
           (rev (. ":00000001FF\r\n"
                      (0 < entry ? (oc-start entry . acc) acc)))
           (: c <l a <c
              new? (base + 65535 < a)
              lin? (0xFFFFF < a)
              nb (a - a % 65536)
              acc2 (? !new? acc
                      !lin? (oc-b02 nb . acc)
                      sg (oc-b04 nb . (oc-b02 0 . acc))
                      (oc-b04 nb . acc))
              b2 (new? ? nb base)
              (go >l b2 (new? ? !lin? sg)
                  (oc-rec 0 (a - b2)
                          (map (k \ s (c 1 + k)) ^(c 2)) . acc2))))
       (go (oc-chunks secs) 0 () ()))

   (oc-le v n) (map (i \ v >> (8 * i) & 255) ^n)
   ;; -- an elf rewritten as llvm-objcopy lays it: sections dropped, renamed or flagged,
   ;; symbols prefixed or dropped, the symbol and name tables built again. what a segment
   ;; holds keeps its place; the rest is laid behind the segments in its old order
   oe64 (ld-cls '((ehs 64) (she 64) (phe 56) (sye 24) (ptr 8) (rl-symsh 32)
                  (e-phoff 32 8) (e-shoff 40 8) (e-ehs 52 2) (e-phent 54 2) (e-phnum 56 2)
                  (e-shent 58 2) (e-shnum 60 2) (e-shstrx 62 2)
                  (sh-name 0 4) (sh-type 4 4) (sh-flags 8 8) (sh-addr 16 8) (sh-off 24 8)
                  (sh-size 32 8) (sh-link 40 4) (sh-info 44 4) (sh-align 48 8) (sh-esz 56 8)
                  (ph-type 0 4) (ph-flags 4 4) (ph-off 8 8) (ph-va 16 8) (ph-pa 24 8)
                  (ph-fsz 32 8) (ph-msz 40 8) (ph-align 48 8)
                  (sy-name 0 4) (sy-info 4 1) (sy-other 5 1) (sy-shndx 6 2) (sy-val 8 8) (sy-size 16 8)
                  (rl-info 8 8)))
   oe32 (ld-cls '((ehs 52) (she 40) (phe 32) (sye 16) (ptr 4) (rl-symsh 8)
                  (e-phoff 28 4) (e-shoff 32 4) (e-ehs 40 2) (e-phent 42 2) (e-phnum 44 2)
                  (e-shent 46 2) (e-shnum 48 2) (e-shstrx 50 2)
                  (sh-name 0 4) (sh-type 4 4) (sh-flags 8 4) (sh-addr 12 4) (sh-off 16 4)
                  (sh-size 20 4) (sh-link 24 4) (sh-info 28 4) (sh-align 32 4) (sh-esz 36 4)
                  (ph-type 0 4) (ph-off 4 4) (ph-va 8 4) (ph-pa 12 4) (ph-fsz 16 4)
                  (ph-msz 20 4) (ph-flags 24 4) (ph-align 28 4)
                  (sy-name 0 4) (sy-val 4 4) (sy-size 8 4) (sy-info 12 1) (sy-other 13 1) (sy-shndx 14 2)
                  (rl-info 4 4)))
   (oe-n t k) <(t k)
   (oe-r t s b k) (t k @ r (rlew s (b + <r) <>r))
   ; a record: (field value) pairs laid in offset order
   (oe-pack t kvs) (cats (map (kv \ oc-le (kv 1) (t <kv 1)) (sortby (\ a b (<(t <a) <= <(t <b))) kvs)))
   (oe-sec t s i)
    (: h (oe-r t s 0 'e-shoff + i * oe-n t 'she) (f k) (oe-r t s h k)
       {'i i 'nm0 (f 'sh-name) 'type (f 'sh-type) 'flags (f 'sh-flags) 'addr (f 'sh-addr)
        'off (f 'sh-off) 'size (f 'sh-size) 'link (f 'sh-link) 'info (f 'sh-info)
        'align (f 'sh-align) 'esz (f 'sh-esz) 'seg -1})
   (oe-seg t s i)
    (: h (oe-r t s 0 'e-phoff + i * oe-n t 'phe) (f k) (oe-r t s h k)
       {'i i 'type (f 'ph-type) 'flags (f 'ph-flags) 'off (f 'ph-off) 'va (f 'ph-va)
        'pa (f 'ph-pa) 'fsz (f 'ph-fsz) 'msz (f 'ph-msz) 'align (f 'ph-align)})
   ; the segment a section lies in, the lowest-placed of several; bss by address, tls apart
   (oe-in? sc g)
    (: sz (max 1 (sc 'size)) fl (sc 'flags) tls (0 < fl & 1024)
       (? (sc 'type = 8) (0 < fl & 2 && tls = (g 'type = 7)
                          && g 'va <= sc 'addr && sc 'addr + sz <= g 'va + g 'msz)
          (g 'off <= sc 'off && sc 'off + sz <= g 'off + g 'fsz)))
   (oe-parent sc gs) (foldl (\ p g (oe-in? sc g && (p < 0 || g 'off < gs p 'off) ? (g 'i) p)) -1 gs)
   ; a segment's container: the earliest by (offset, index) holding its start
   (oe-before a b) (a 'off < b 'off || (a 'off = b 'off && a 'i < b 'i))
   (oe-gparent c gs)
    (foldl (\ p g (!(g 'i = c 'i) && g 'off <= c 'off && c 'off < g 'off + g 'fsz && oe-before g c
                   && (p < 0 || oe-before g (gs p)) ? (g 'i) p))
           -1 gs)
   (oe-alignto v a sk) (: a1 (max a 1) k (sk % a1) ((v + a1 - 1 - k) // a1 * a1 + k))
   ; segments one after another, each at the next offset its alignment allows, a held one
   ; where its container puts it -> (index -> offset, the end)
   (oe-layseg gs)
    (: ord (sortby (\ a b !(oe-before b a)) gs)
       nw {}
       end (foldl (\ o g (: p (oe-gparent g gs)
                           at (p < 0 ? (oe-alignto o (g 'align) (g 'va)) (nw p + g 'off - gs p 'off))
                           _ (pin nw (g 'i) at)
                           (max o (at + g 'fsz))))
                  0 ord)
       [nw end])
   (oe-laysec ks gs nw o0)
    (: _ (each ks (sc \ (sc 'seg < 0 ? 0 (pin sc 'noff (nw (sc 'seg) + sc 'off - gs (sc 'seg) 'off)))))
       free (sortby (\ a b (a 'off <= b 'off)) (filter (sc \ sc 'seg < 0) ks))
       (foldl (\ o sc (: at (oe-alignto o (sc 'align) 0) _ (pin sc 'noff at)
                         (sc 'type = 8 ? at (at + sc 'nsize))))
              o0 free))
   ;; -- painting: runs (at n from) copy the input, overlays (at n pieces) lie over them
   (oe-len ps) (foldl (\ a p (a + #p)) 0 ps)
   (oe-cut r vs)
    (: (go a n f vs acc)
        (? (n < 1) acc
           (atom? vs) ([a n f] . acc)
           (: b (<vs 0) e (b + <vs 1)
              (? (e <= a) (go a n f >vs acc)
                 (a + n <= b) ([a n f] . acc)
                 (: acc2 (a < b ? ([a (b - a) f] . acc) acc)
                    (e < a + n ? (go e (a + n - e) (f + e - a) >vs acc2) acc2)))))
       (rev (go <r (r 1) (r 2) vs ())))
   (oe-paint s runs ovs)
    (: vs (sortby (\ a b (<a <= <b)) (filter (v \ 0 < v 1) ovs))
       cs (cats (map (r \ map (c \ [<c (c 1) [(snip s (c 2) (c 2 + c 1))]]) (oe-cut r vs)) runs))
       ps (sortby (\ a b (<a <= <b)) (cs + vs))
       (go l pos acc)
        (atom? l ? acc
           (: p <l at <p
              (at < pos ? (scare 'copy-overlap at) 0,
               go >l (at + p 1) (rev (p 2) + (pos < at ? (ld-zeros (at - pos) . acc) acc)))))
       (rev (go ps 0 ())))
   ;; -- symbols
   ; a string table's names by offset; one inside another's tail is read on demand
   (oe-names st) (: m {} _ (foldl (\ o w (pin m o w, o + #w + 1)) 0 (split "\0" st)) m)
   ; symbols as (index name info shndx entry)
   (oe-syms t s sc st)
    (: e (oe-n t 'sye) o (sc 'off) io <(t 'sy-info) xo <(t 'sy-shndx) nm (oe-names st)
       (map (k \ (o + k * e @ h
                  (: x (rlew s h 4) v (peep nm x 0)
                     [k (string? v ? v (ld-cstr st x)) (s (h + io)) (rlew s (h + xo) 2) (snip s h (h + e))])))
            ^(sc 'size // e)))
   (oe-shndx x nx) (0 < x && x < 65280 ? (peep nx x 0) x)
   (oe-sym t y nx so)
    (: r (y 4) xo <(t 'sy-shndx)
       [(string (oc-le (peep so (y 1) 0) 4)) (snip r 4 xo) (string (oc-le (oe-shndx (y 3) nx) 2))
        (snip r (xo + 2) #r)])
   ; names -> (pieces, name -> offset): llvm's order, by reversed spelling high first, so a
   ; name ending the one laid before it shares its bytes
   (oe-strtab nms)
    (: m {}
       srt (rev (sort (map (n \ [(string (rev (chars n))) n]) (filter (n \ 0 < #n) nms))))
       (go l prev po n acc)
        (atom? l ? [(rev acc) m]
           (: nm <>(<l)
              (? (whole? (peep m nm ())) (go >l prev po n acc)
                 (#nm <= #prev && snip prev (#prev - #nm) #prev = nm)
                  (: _ (pin m nm (po + #prev - #nm)) (go >l prev po n acc))
                 (: _ (pin m nm n) (go >l nm n (n + #nm + 1) ((nm + "\0") . acc))))))
       (go srt "" 0 1 ["\0"]))
   ; a relocation table's entries, each symbol renumbered
   (oe-rels t s sc yx)
    (: e (sc 'esz) o (sc 'off) ri <(t 'rl-info) w (t 'rl-info 1) sh (oe-n t 'rl-symsh)
       (map (k \ (o + k * e @ h
                  (: inf (rlew s (h + ri) w) y (inf >> sh) lo (inf - (y << sh))
                     [(snip s h (h + ri)) (oc-le (((peep yx y 0) << sh) + lo) w) (snip s (h + ri + w) (h + e))])))
            ^(sc 'size // e)))
   ;; -- what to drop and how to rename: a section pattern list matches one name when
   ;; some pattern does and no !pattern does
   (oe-match? ps nm wild)
    (: (m p) (wild ? (fnmatch p nm) (p = nm))
       (foldl (\ a p (? (starts? p "!") a (a || m p))) () ps
        && !(foldl (\ a p (a || starts? p "!" && m (snip p 1 #p))) () ps)))
   (oe-dbg? nm) (starts? nm ".debug" || starts? nm ".zdebug" || nm = ".gdb_index")
   ; --set-section-flags words to sh_flags over what is kept: info-link, link-order, group,
   ; tls, compressed and the os and processor bits
   (oe-flags ws old mach)
    (: (has w) (elem w ws)
       nf ((has "alloc" ? 2 0) | (has "readonly" ? 0 1) | (has "code" ? 4 0) | (has "merge" ? 16 0)
           | (has "strings" ? 32 0) | (has "exclude" ? 0x80000000 0))
       keep (0x40 | 0x80 | 0x200 | 0x400 | 0x800 | 0x0ff00000 | 0xf0000000)
       km (keep & (0xffffffffffffffff - 0x80000000) & (mach = 62 ? (0xffffffffffffffff - 0x10000000) 0xffffffffffffffff))
       (old & km | nf & (0xffffffffffffffff - km)))
   ;; o: 'drop patterns, 'all strip-all, 'dbg strip-debug, 'psym and 'palloc prefixes,
   ;; 'flags (name words).., 'unneeded patterns, 'wild
   (oe-edit id s o)
    (: _ (s 0 = 127 && s 1 = 69 && s 2 = 76 && s 3 = 70 ? 0 (scare 'copy-not-elf id))
       _ (s 5 = 1 ? 0 (scare 'copy-big-endian id))
       t (? (s 4 = 2) oe64 (s 4 = 1) oe32 (scare 'copy-elf-class id))
       ehs (oe-n t 'ehs) she (oe-n t 'she) phe (oe-n t 'phe) ptr (oe-n t 'ptr)
       ety (rlew s 16 2) mach (rlew s 18 2) rel? (ety = 1)
       shnum (oe-r t s 0 'e-shnum) phnum (oe-r t s 0 'e-phnum) phoff (oe-r t s 0 'e-phoff)
       _ (0 < shnum ? 0 (scare 'copy-no-sections id))
       secs (map (oe-sec t s) ^shnum)
       shx (oe-r t s 0 'e-shstrx)
       shstro (secs shx 'off)
       _ (each secs (sc \ (ld-cstr s (shstro + sc 'nm0) @ n (pin sc 'nm n, pin sc 'on n))))
       gs0 (map (oe-seg t s) ^phnum)
       gs (gs0 + [{'i phnum 'type 0 'off 0 'va 0 'fsz ehs 'align 0}
                  {'i (phnum + 1) 'type 6 'off phoff 'va phoff 'fsz (phnum * phe) 'align ptr}])
       _ (each (drop 1 secs) (sc \ pin sc 'seg (oe-parent sc gs0)))
       (rel-of? sc) ((sc 'type = 4 || sc 'type = 9) && 0 < sc 'info)
       ; dropped: by name, by the strips, and a relocation table with its target
       (gone0? sc)
        (? (oe-match? (o 'drop) (sc 'nm) 1) 1
           (o 'dbg && oe-dbg? (sc 'nm)) 1
           (o 'all) (!(sc 'i = shx) && !(starts? (sc 'nm) ".gnu.warning") && !(sc 'type = 0x70000003)
                     && sc 'seg < 0 && sc 'flags & 2 = 0)
           ())
       g0 (map (sc \ sc 'i = 0 ? () (gone0? sc)) secs)
       gone (map (sc \ g0 (sc 'i) || (rel-of? sc && sc 'info < shnum && g0 (sc 'info))) secs)
       ks (filter (sc \ !(gone (sc 'i))) secs)
       nx (: m {} _ (foldl (\ k sc (pin m (sc 'i) k, k + 1)) 0 ks) m)
       ; renames, then flags
       pa (o 'palloc)
       _ (each ks (sc \ (? (string? pa && 0 < sc 'flags & 2) (pin sc 'nm (pa + sc 'nm))
                           (string? pa && rel-of? sc && 0 < secs (sc 'info) 'flags & 2)
                            (pin sc 'nm ((sc 'type = 4 ? ".rela" ".rel") + pa + secs (sc 'info) 'on))
                           0)))
       _ (each (o 'flags) (fw \ each ks (sc \ (sc 'nm = <fw ?
                                                 (: nf (oe-flags (fw 1) (sc 'flags) mach)
                                                    _ (pin sc 'flags nf)
                                                    (sc 'type = 8 && (nf & 2 = 0 || elem "contents" (fw 1) || elem "load" (fw 1))
                                                     ? (pin sc 'type 1) 0))
                                                 0))))
       ; the symbol table, if kept
       yt (filter (sc \ sc 'type = 2) ks)
       ys (? (two? yt) (: l (secs (<yt 'link)) (oe-syms t s <yt (snip s (l 'off) (l 'off + l 'size)))) ())
       (sgone? y) (: x (y 3)
                     (? (<y = 0) ()
                        (0 < x && x < 65280 && x < shnum && gone x) 1
                        (o 'dbg && y 2 & 15 = 4) 1          ; -g takes the file symbols too
                        (two? (o 'unneeded) && oe-match? (o 'unneeded) (y 1) (o 'wild)
                         && (!rel? || (y 2 & 15 != 3 && (y 2 >> 4 = 0 || x = 0)))) 1
                        ()))
       ps0 (o 'psym)
       ys1 (map (y \ (string? ps0 && 0 < <y && y 2 & 15 != 3 ? [<y (ps0 + y 1) (y 2) (y 3) (y 4)] y))
                (filter (y \ !(sgone? y)) ys))
       ys2 ((filter (y \ y 2 >> 4 = 0) ys1) + filter (y \ !(y 2 >> 4 = 0)) ys1)
       same (map (y \ <y) ys2 = ^#ys)
       yx (: m {} _ (foldl (\ k y (pin m <y k, k + 1)) 0 ys2) m)
       nloc (foldl (\ a y (y 2 >> 4 = 0 ? (a + 1) a)) 0 ys2)
       ; the name tables built again: section names and, where it is linked, symbol names
       stx (? (two? yt) (<yt 'link) -1)
       (names sc) (filter (n \ 0 < #n)
                          ((sc 'i = shx ? (map (k \ k 'nm) ks) ()) + (sc 'i = stx ? (map (y \ y 1) ys2) ())))
       strs (foldl (\ m sc (sc 'i = shx || sc 'i = stx ? (pin m (sc 'i) (oe-strtab (names sc))) m)) {} ks)
       shso (<>(strs shx))
       _ (each ks (sc \ (: i (sc 'i)
                           (? (two? (peep strs i ())) (: b <(strs i) (pin sc 'body b, pin sc 'nsize (oe-len b)))
                              (sc 'type = 2) (: so <>(strs stx) b (cats (map (y \ oe-sym t y nx so) ys2))
                                                (pin sc 'body b, pin sc 'nsize (oe-len b)))
                              (rel-of? sc && two? yt && sc 'link = <yt 'i && !same)
                               (: b (cats (oe-rels t s sc yx)) (pin sc 'body b, pin sc 'nsize (sc 'size)))
                              (pin sc 'nsize (sc 'size))))))
       ; layout
       ls (oe-layseg gs)
       nw <ls
       ks1 (drop 1 ks)
       end (oe-laysec ks1 gs nw (ls 1))
       shoff (oe-alignto end ptr 0)
       nphoff (phnum ? (nw (phnum + 1)) 0)
       (hdr sc)
        (: ty (sc 'type) lk (sc 'link) in (sc 'info)
           (oe-pack t [['sh-name (peep shso (sc 'nm) 0)] ['sh-type ty] ['sh-flags (sc 'flags)]
                      ['sh-addr (sc 'addr)] ['sh-off (sc 'noff)] ['sh-size (sc 'nsize)]
                      ['sh-link (0 < lk ? (peep nx lk 0) 0)]
                      ['sh-info (? (ty = 2) nloc (ty = 17) (peep yx in 0)
                                   (rel-of? sc || 0 < sc 'flags & 64) (peep nx in 0) in)]
                      ['sh-align (sc 'align)] ['sh-esz (sc 'esz)]]))
       shdrs ([(ld-zeros she)] + map hdr ks1)
       eh [(snip s 0 9) (ld-zeros 7) (snip s 16 (<(t 'e-phoff)))
           (oc-le nphoff ptr) (oc-le shoff ptr) (snip s (<(t 'e-shoff) + ptr) (<(t 'e-ehs)))
           (oc-le ehs 2) (oc-le (phnum ? phe 0) 2) (oc-le phnum 2) (oc-le she 2)
           (oc-le #ks 2) (oc-le (peep nx shx 0) 2)]
       phs (map (g \ snip s (phoff + g 'i * phe) (phoff + g 'i * phe + <(t 'ph-off))
                     + "" + string (oc-le (nw (g 'i)) ptr)
                     + snip s (phoff + g 'i * phe + <(t 'ph-off) + ptr) (phoff + (g 'i + 1) * phe))
                gs0)
       runs (map (g \ [(nw (g 'i)) (g 'fsz) (g 'off)])
                 (filter (g \ 0 < g 'fsz && (oe-gparent g gs0) < 0) gs0))
       zs (map (sc \ (: g (gs (sc 'seg)) [(nw (sc 'seg) + sc 'off - g 'off) (sc 'size) [(ld-zeros (sc 'size))]]))
               (filter (sc \ gone (sc 'i) && 0 <= sc 'seg && !(sc 'type = 8)) secs))
       bodies (map (sc \ (: b (peep sc 'body ()) [(sc 'noff) (sc 'nsize) (two? b ? b [(snip s (sc 'off) (sc 'off + sc 'size))])]))
                   (filter (sc \ !(sc 'type = 8) && (sc 'seg < 0 || two? (peep sc 'body ()))) ks1))
       (oe-paint s runs (zs + [[0 ehs eh]] + (phnum ? [[nphoff (phnum * phe) phs]] ()) + bodies
                         + [[shoff (#ks * she) shdrs]])))

   ;; -- the applet; it complains as gnu objcopy does, named and exit 1
   (oc-die m) (say err ("objcopy: " + m), put err 10, quit 1)
   oc-use "usage: objcopy [-O binary|ihex] [-S] [-g] [-R SEC].. [-j SEC].. [--prefix-symbols=P] [--prefix-alloc-sections=P] [--set-section-flags SEC=FLAGS].. [-w] [--strip-unneeded-symbol=SYM].. IN [OUT]"
   ; the options that take a value, as --opt=v or --opt v, and where each lands
   oc-takes {"-O" 'fmt "-R" 'drop "--remove-section" 'drop "-j" 'only "--only-section" 'only
             "--prefix-symbols" 'psym "--prefix-alloc-sections" 'palloc
             "--set-section-flags" 'flags "--strip-unneeded-symbol" 'unneeded}
   (oc-set f k v)
    (? (k = 'flags) (split "=" v @ [n w] (pin f k (f k + [[n (split "," w)]]))
                                   (oc-die ("bad section flags " + v)))
       (elem k '(drop only unneeded)) (pin f k (f k + [v]))
       (pin f k v))
   ; -O writes a flat image of what loads, -S and -g taken as moot there; without it the
   ; elf is written again through oe-edit. one file is rewritten in place
   (objcopy as)
    (: (go a f ps)
        (? (atom? a) [f (rev ps)]
           (: x <a k (starts? x "--" ? <(split "=" x) x) o (peep oc-takes k 0)
              (? !(o = 0) (? (#k < #x) (go >a (oc-set f o (snip x (#k + 1) #x)) ps)
                             (two? >a) (go >>a (oc-set f o <>a) ps)
                             (oc-die ("option " + x + " wants a value")))
                 (elem x '("-S" "--strip-all")) (go >a (pin f 'all 1) ps)
                 (elem x '("-g" "--strip-debug")) (go >a (pin f 'dbg 1) ps)
                 (elem x '("-w" "--wildcard")) (go >a (pin f 'wild 1) ps)
                 (1 < #x && x 0 = 45) (oc-die ("unrecognized option " + x))
                 (go >a f (x . ps)))))
       r0 (go as {'fmt () 'drop () 'only () 'flags () 'unneeded () 'all () 'dbg () 'wild ()
                  'psym () 'palloc ()} ())
       f <r0 ps <>r0
       fmt (f 'fmt)
       _ (0 < #ps < 3 ? 0 (oc-die oc-use))
       src <ps dst (two? >ps ? <>ps src)
       _ (!(string? fmt) || elem fmt '("binary" "ihex") ? 0 (oc-die ("unknown output format " + fmt)))
       _ (string? fmt || atom? (f 'only) ? 0 (oc-die "-j wants -O binary or ihex"))
       r (uread src)
       _ (two? r ? 0 (oc-die ("cannot open " + src)))
       s <>r
       out (? (string? fmt) (: w (oc-read src s (f 'drop) (f 'only)) (fmt = "ihex" ? (oc-ihex s <w <>w) (oc-bin s <w)))
              (oe-edit src s f))
       nw (ld-write dst out)
       (nom? nw ? (oc-die ("cannot write " + dst + " -- " + show nw)) 0,
        quit 0)))
) ; module 'holo
