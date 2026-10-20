; src/love/holo/copy.l -- objcopy's two output formats: a linked elf flattened to the
; bytes a flash tool takes. `-O binary` is the image from the lowest load address,
; `-O ihex` the same image in Intel hex. `love objcopy` is the applet.
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
   (oc-read id s)
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
       (go i acc)
        (shnum <= i ? acc
           (: h (shoff + i * ld-n fs 'sh-ent)
              ty (ld-f fs s h 'sh-type) fl (ld-f fs s h 'sh-flags)
              off (ld-f fs s h 'sh-off) sz (ld-f fs s h 'sh-size)
              keep (!(ty = 8) && 0 < fl & 2 && 0 < sz)
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

   ;; -- the applet; it complains as gnu objcopy does, named and exit 1
   (oc-die m) (say err ("objcopy: " + m), put err 10, quit 1)
   (objcopy as)
    (#as != 4 ? (oc-die "usage: objcopy -O binary|ihex IN OUT")
       (: fmt (<as = "-O" ? <>as (oc-die ("unrecognized option " + <as)))
          src (as 2) dst (as 3)
          _ (elem fmt '("binary" "ihex") ? 0 (oc-die ("unknown output format " + fmt)))
          r (uread src)
          _ (two? r ? 0 (oc-die ("cannot open " + src)))
          s <>r
          w (oc-read src s)
          nw (ld-write dst (fmt = "ihex" ? (oc-ihex s <w <>w) (oc-bin s <w)))
          (nom? nw ? (oc-die ("cannot write " + dst + " -- " + show nw)) 0,
           quit 0))))
) ; module 'holo
