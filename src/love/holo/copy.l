; src/love/holo/copy.l -- objcopy's output formats: a linked elf flattened to the bytes a
; flash tool takes, or stripped to an elf. `-O binary` is the image from the lowest load
; address, `-O ihex` the same image in Intel hex, -S alone the elf less every section that
; does not load. `love objcopy` is the applet.
;
; a flasher wants the load address, not sh_addr: each section maps through the PT_LOAD
; holding its file bytes, lma = p_paddr + (off - p_offset). matching by file offset keeps
; two lanes sharing a vaddr apart.
;
; a hex record never spans two sections, as in gnu objcopy, so output compares by bytes.
;
; loads after src/love/holo/link.l, whose field table, ld-write and ld-zeros it reads.
(module 'holo
(borrow 'kore)
(borrow 'posix)

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
                    (? (elem nm drop) () (two? only) (elem nm only) 1))
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

;; -- strip-all to an elf, as llvm-objcopy -S lays it: the sections that load keep their
   ;; offsets, the segments' bytes copied whole; the rest go, but .gnu.warning* and arm
   ;; attributes. a new .shstrtab follows the segments, then the section table at 8
   (oc-le v n) (map (i \ v >> (8 * i) & 255) ^n)
   ; names -> (text, name -> offset): by reversed spelling, high first, so a name that ends
   ; the one laid before it shares its bytes
   (oc-strtab nms)
    (: (rv x) (string (rev (map x ^#x)))
       t {}
       (go l prev po n acc)
        (atom? l ? [(oc-cat (rev acc)) t]
           (: nm <>(<l)
              (? (whole? (peep t nm ())) (go >l prev po n acc)
                 (#nm <= #prev && snip prev (#prev - #nm) #prev = nm)
                  (: _ (pin t nm (po + #prev - #nm)) (go >l prev po n acc))
                 (: _ (pin t nm n) (go >l nm n (n + #nm + 1) ((nm + "\0") . acc))))))
       (go (rev (sort (map (n \ [(rv n) n]) nms))) "" 0 1 ["\0"]))
   (oc-strip id s)
    (: _ (s 0 = 127 && s 1 = 69 && s 2 = 76 && s 3 = 70 ? 0 (scare 'copy-not-elf id))
       _ (s 4 = 2 ? 0 (scare 'copy-elf-class id))
       fs elf64f
       shoff (ld-f fs s 0 'e-shoff) shnum (ld-f fs s 0 'e-shnum)
       phoff (ld-f fs s 0 'e-phoff) phnum (ld-f fs s 0 'e-phnum)
       (h i) (shoff + 64 * i)
       (f i k) (ld-f fs s (h i) k)
       stro (f (ld-f fs s 0 'e-shstrx) 'sh-off)
       (nm i) (ld-cstr s (stro + f i 'sh-name))
       (keep? i) (0 < f i 'sh-flags & 2 || starts? (nm i) ".gnu.warning" || f i 'sh-type = 1879048195)
       kept (filter keep? (drop 1 ^shnum))
       nx (: t {} _ (foldl (\ j i (pin t i j, j + 1)) 1 kept) t)
       se (foldl (\ m k (: p (phoff + 56 * k) (max m (ld-f fs s p 'ph-off + ld-f fs s p 'ph-fsz))))
                 (phoff + 56 * phnum) ^phnum)
       _ (each kept (i \ (f i 'sh-type = 8 || f i 'sh-off + f i 'sh-size <= se ? 0 (scare 'copy-strip-unloaded (nm i)))))
       st (oc-strtab (map nm kept + [".shstrtab"]))
       so <>st txt <st
       sho (: e (se + #txt) (e + (8 - e % 8) % 8))
       (row i) (: o (h i) fl (f i 'sh-flags) in (f i 'sh-info)
                  [(oc-le (so (nm i)) 4) (snip s (o + 4) (o + 40)) (oc-le (peep nx (f i 'sh-link) 0) 4)
                   (oc-le (0 < fl & 64 ? (peep nx in 0) in) 4) (snip s (o + 48) (o + 64))])
       eh [(snip s 0 40) (oc-le sho 8) (snip s 48 60) (oc-le (#kept + 2) 2) (oc-le (#kept + 1) 2)]
       (eh + [(snip s 64 se) txt (ld-zeros (sho - se - #txt)) (ld-zeros 64)]
        + cats (map row kept)
        + [(oc-le (so ".shstrtab") 4) (oc-le 3 4) (ld-zeros 16) (oc-le se 8) (oc-le #txt 8) (ld-zeros 8) (oc-le 1 8) (ld-zeros 8)]))

   ;; -- the applet; it complains as gnu objcopy does, named and exit 1
   (oc-die m) (say err ("objcopy: " + m), put err 10, quit 1)
   ; -O binary|ihex, -R/--remove-section and -j/--only-section by name; -S/--strip-all
   ; and --strip-debug are taken, a flat image carrying no symbols or debug anyway. -S
   ; without -O writes the stripped elf
   (objcopy as)
    (: (go a f ps)
        (? (atom? a) [f (rev ps)]
           (a @ ("-O" . w . r) (go r (pin f 'fmt w) ps)
                ("-R" . w . r) (go r (pin f 'drop (w . f 'drop)) ps)
                ("-j" . w . r) (go r (pin f 'only (w . f 'only)) ps)
                (("--remove-section=" + n) . r) (go r (pin f 'drop (n . f 'drop)) ps)
                (("--only-section=" + n) . r) (go r (pin f 'only (n . f 'only)) ps)
                ((x . r) && elem x '("-S" "--strip-all")) (go r (pin f 'strip 1) ps)
                ((x . r) && elem x '("-g" "--strip-debug")) (go r f ps)
                ((x . r) && 1 < #x && x 0 = 45) (oc-die ("unrecognized option " + x))
                (x . r) (go r f (x . ps))))
       r0 (go as {'fmt () 'drop () 'only () 'strip 0} ())
       f <r0 ps <>r0
       fmt (f 'fmt)
       elf (!(string? fmt) && f 'strip = 1 && atom? (f 'drop) && atom? (f 'only))
       _ (? (#ps = 2 && (string? fmt || elf)) 0 (oc-die "usage: objcopy [-O binary|ihex] [-S] [-R SEC] [-j SEC] IN OUT"))
       src <ps dst <>ps
       _ (elf || elem fmt '("binary" "ihex") ? 0 (oc-die ("unknown output format " + fmt)))
       r (uread src)
       _ (two? r ? 0 (oc-die ("cannot open " + src)))
       s <>r
       out (? elf (oc-strip src s)
              (: w (oc-read src s (f 'drop) (f 'only)) (fmt = "ihex" ? (oc-ihex s <w <>w) (oc-bin s <w))))
       nw (ld-write dst out)
       (nom? nw ? (oc-die ("cannot write " + dst + " -- " + show nw)) 0,
        quit 0)))
) ; module 'holo
