; love/holo/link.l -- a static ELF linker over obj.l's relocatable objects (the toolchain
; ladder, rung 3): read each .o (ld-read takes either ELF class off the field table below),
; resolve every symbol across the set (strong over weak, the nif brackets synthesized over
; the packed region), lay the sections at the classic et_exec base, apply the relocations,
; and wrap the bytes in elf.l's one-segment executable header. entry is the first object's
; text -- the driver leads with a crt0 object built by objelf itself. it eats a foreign .o
; too (gcc's, the differential oracle): the sections a static image cannot use are dropped
; on a stated rule, see `class`, and anything else with bytes scares rather than dropping.
; x86-64 field relocs replace their field; a64 and rv64 ones or bits into the instruction
; word the placeholder carries.
; `ldkern` is the second door: the same objects laid for bare metal, several page-aligned
; pt_loads each carrying p_paddr = p_vaddr - bias, so one ELF serves a loader that copies
; physical and a bootloader that maps virtual (free/klink.l drives it). `ldbare32` is the
; third: one ELF32 segment for a part with no MMU, laid where the core boots from.
; loads after love/holo/obj.l in the mooncc cat -- reads elf-base/elf-machines/elf64-hdr/
; le32/le64 bare (asbook.l + elf.l re-leak them). moon.l: `mooncc a.o b.c -o prog`.
(module 'holo
(borrow 'posix)

(:
   ; little-endian reads off a byte-indexable text; a u64 field can carry a
   ; signed value (a RELA addend), so sg64 folds the high half back down
   (rle16 s i) (s i + 256 * s (i + 1))
   (rle32 s i) (rle16 s i + 65536 * rle16 s (i + 2))
   (rle64 s i) (rle32 s i + 4294967296 * rle32 s (i + 4))
   (sg64 v) (v < 9223372036854775808 ? v (v - 18446744073709551616))
   ; a field of any width, little-endian -- the table below asks for 1, 2, 3, 4 and 8
   (rlew s i n) (n < 1 ? 0 (s i + (256 * rlew s (i + 1) (n - 1))))

   ; --- the field table: where each class keeps what the readers read. ---
   ; the two classes are not one shape at two widths: Elf32_Sym reorders, a rel's r_info
   ; splits at a byte (type low, sym the top three) where a RELA's splits at a word, and a
   ; rel has no addend column -- `rl-add` is absent at 32 bits and the patcher pulls it per
   ; kind. a row is (offset width); a lone scalar rides as a one-element row, so presence
   ; is always the `two?`, never a zero.
   (ld-cls c) (foldl (t \ (a . u) \ pin t a u) {} c)
   (ld-row fs nm) (peep fs nm ())
   (ld-n fs nm) (: r (ld-row fs nm) (two? r ? <r (scare 'link-field nm)))
   (ld-f fs s b nm)
    (: r (ld-row fs nm) (two? r ? (rlew s (b + <r) <>r) (scare 'link-field nm)))
   ; a table stride is the one row a wrong value does not announce: read a 16-byte symbol
   ; at 24 and the walk takes every other one, each well-formed. so hold it to sh_entsize.
   (ld-esz fs s h want sec)
    (ld-f fs s h 'sh-esz != ld-n fs want ? (scare 'link-entsize sec))
   ; the ph- rows are copy.l's, reading a linked file where this one reads relocatables --
   ; one wire shape, one table. an Elf32_Phdr too moves every field but p_type.
   ;                     elf64 / RELA                        ELF32 / rel
   elf64f (ld-cls '((sh-ent 64) (sy-ent 24) (rl-ent 24) (rl-ty 4) (ph-ent 56)
                    (e-entry 24 8) (e-phoff 32 8) (e-phent 54 2) (e-phnum 56 2)
                    (e-shent 58 2) (e-shoff 40 8) (e-shnum 60 2) (e-shstrx 62 2)
                    (ph-type 0 4) (ph-off 8 8) (ph-pa 24 8) (ph-fsz 32 8)
                    (sh-name 0 4) (sh-type 4 4) (sh-flags 8 8) (sh-off 24 8)
                    (sh-size 32 8) (sh-link 40 4) (sh-info 44 4) (sh-align 48 8) (sh-esz 56 8)
                    (sy-name 0 4) (sy-info 4 1) (sy-shndx 6 2) (sy-val 8 8) (sy-size 16 8)
                    (rl-off 0 8) (rl-kind 8 4) (rl-sym 12 4) (rl-add 16 8)))
   elf32f (ld-cls '((sh-ent 40) (sy-ent 16) (rl-ent 8) (rl-ty 9) (ph-ent 32)
                    (e-entry 24 4) (e-phoff 28 4) (e-phent 42 2) (e-phnum 44 2)
                    (e-shent 46 2) (e-shoff 32 4) (e-shnum 48 2) (e-shstrx 50 2)
                    (ph-type 0 4) (ph-off 4 4) (ph-pa 12 4) (ph-fsz 16 4)
                    (sh-name 0 4) (sh-type 4 4) (sh-flags 8 4) (sh-off 16 4)
                    (sh-size 20 4) (sh-link 24 4) (sh-info 28 4) (sh-align 32 4) (sh-esz 36 4)
                    (sy-name 0 4) (sy-info 12 1) (sy-shndx 14 2) (sy-val 4 4) (sy-size 8 4)
                    (rl-off 0 4) (rl-kind 4 1) (rl-sym 5 3)))
   (ld-cstr s i) (: (go j) (s j = 0 ? (snip s i j) (go (j + 1))) (go i))
   (ld-zeros n) (n >= 1 ? (0 . ld-zeros (n - 1)))
   (ld-align a v) (a < 2 ? v (: r (v % a) (r = 0 ? v (v + a - r))))
   ; where a segment stands when its file offset f is already spent: the next page at or
   ; after v, plus f's own place in a page -- the least address that begins a fresh page
   ; and still answers p_vaddr = p_offset (mod a). a < 2 packs tight, sharing no segments.
   (ld-lift a v f) (a < 2 ? v ((ld-align a v) + (f % a)))
   (ld-fits32 v) (-2147483648 <= v <= 2147483647)
   ; relocation field arithmetic is 64-bit modular, and % is truncated in this dialect --
   ; a negative sum comes back negative, so fold it up.
   (ld-u64 v) (: r (v % 18446744073709551616)
               (r < 0 ? (r + 18446744073709551616) r))
   (ld-u32 v) (: r (v % 4294967296) (r < 0 ? (r + 4294967296) r))

   ; --- the ARM field lane. EM_ARM is rel: each kind pulls its own addend out of the
   ; field, and the thumb bit rides in the symbol -- ldsyms folded st_value's bit 0 into S
   ; and every branch field shifts right by at least one, so ((S+A)|T) falls out of S+a.
   ; the encodings are the backend's, through refix-with -- and the arm32 family's backend,
   ; not the link target's: one image carries objects of both cores (an mps2 v6-M link
   ; takes a v7-M start.o), so the widest encoder answers for every arm32 link.
   ; the two word kinds carry their addend in a whole 32-bit field and are written here:
   ; abs32 is ((S+A)|T), rel32 that minus P (gcc's `.word handler - .`).
   ; the numbers are obj.l's plus rel32, and a kind outside the set refuses: they collide
   ; with the x86-64 and riscv numbers, which is why the machine picks the lane first.
   ldarm-kinds (ld-cls '((2 abs32) (3 rel32) (10 bl) (30 b) (47 movw16) (48 movt16)))
   (ldarm be s off sv kind site)
    (: r (ldarm-kinds kind)
       _ (atom? r ? (scare 'link-reloc kind))
       k <r  sa (sv + rle32 s off)
       (? (k == 'abs32) (le32 (ld-u32 sa))
          (k == 'rel32) (le32 (ld-u32 (sa - site)))
          (refix-with be k (map (i \ s (off + i)) ^4) sv site 4)))

   ; --- archives. the classic "!<arch>\n" file, GNU shape -- kore's `ar` writes exactly
   ; this. only the "/" ranlib index is walked, never the members: v6-M libgcc.a is 1767
   ; members and a link wants a dozen, so an archive with no index refuses rather than
   ; scanning silently -- `ranlib` (or our `ar rcs`) is the repair. a header is 60 bytes of
   ; left-justified, space-padded ASCII; the size field excludes the "\n" a member pads to
   ; even with.
   (ld-arfld s i n)
    (: t (snip s i (i + n))
       (go k) (0 < k && t (k - 1) = 32 ? (go (k - 1)) (snip t 0 k))
       (go n))
   (ld-arnum t) (: (go k a) (#t <= k ? a (go (k + 1) (10 * a + t k - 48)))
                   (go 0 0))
   (ld-arsz s off) (ld-arnum (ld-arfld s (off + 48) 10))
   (ld-arnext s off) (: z (ld-arsz s off) (off + 60 + z + (z % 2)))
   (ld-be32 s i) ((((s i << 8) | s (i + 1)) << 16) | ((s (i + 2) << 8) | s (i + 3)))
   (ld-ar? s) (8 <= #s && snip s 0 8 = "!<arch>\n")   ; glued ?( is the BIT: && answers () for a false LEFT
   ; nom -> the member header offset that defines it. a nom defined by two members
   ; keeps the first, which is the order a linker resolves in.
   (ld-arsyms id s)
    (: _ (ld-arfld s 8 16 != "/" ? (scare 'link-ar-noindex id))
       d0 68 n (ld-be32 s d0) t {}
       (go i o) (n <= i ? t
                   (: nom (ld-cstr s o)
                      _ (? (o-has? t nom) 0 (pin t nom (ld-be32 s (d0 + 4 + 4 * i))))
                      (go (i + 1) (o + 1 + #nom))))
       (go 0 (d0 + 4 + 4 * n)))
   ; the "//" table, where a name past 15 characters lives (GNU's spelling: the
   ; member is named "/<offset>" and the table's entries end at a "/"). "" when
   ; every name is short enough to sit in its own header.
   (ld-arlong s)
    (: p (ld-arnext s 8)
     (p + 60 <= #s && ld-arfld s p 16 = "//" ?
      (snip s (p + 60) ((p + 60) + ld-arsz s p)) ""))
   (ld-armem s off lt)
    (: nm (ld-arfld s off 16) d0 (off + 60)
       real (nm 0 = 47 ?
             (: o (ld-arnum (snip nm 1 #nm))
                (go k) (k < #lt && lt k != 47 ? (go (k + 1)) k)
              (snip lt o (go o)))
             (: z #nm (nm (z - 1) = 47 ? (snip nm 0 (z - 1)) nm)))
       [real (snip s d0 (d0 + ld-arsz s off))])

   ; a section name -> its lane, by prefix: gcc splits a lane across many sections
   ; (.text.unlikely, .rodata.str1.1) and every piece lands in the same run of the image.
   ; love_nifs is ours and exact -- a packed array with a bracket, not a lane.
   (ld-pre nm p) (: n #p (#nm >= n && snip nm 0 n = p))
   ; the unwinder's tables: .eh_frame at 64 bits, .ARM.exidx plus the .ARM.extab it points
   ; into on arm -- gcc splits each into one section per function, so both are prefix tests.
   (ld-unwind? nm)
    (ld-pre nm ".eh_frame" || ld-pre nm ".ARM.exidx" || ld-pre nm ".ARM.extab")
   ; the lanes the linker knows by name; anything else allocated is a named lane
   ld-lanes '(text rodata data nifs bss image note boot)
   ; a compiler-named section becomes its own lane, keyed by the name, and lays as one
   ; contiguous run -- which is what a program that brackets or scans its own table wants.
   ; progbits and nobits only; the one note this image places is named below.
   (ld-any nm ty fl) (elem ty '(1 8) && 0 < fl & 2 ? (name nm))
   ; and it travels with the known lane its flags name -- executable with text, writable
   ; with data, neither with rodata, nobits with bss. a fixed address is the driver's word.
   (ld-home lane fl ty)
    (? (elem lane ld-lanes) lane
     (ty = 8) 'bss (0 < fl & 4) 'text (0 < fl & 1) 'data 'rodata)
   (ld-lane nm ty fl)
    (? (ty = 8) (nm = ".bss" || ld-pre nm ".bss." ? 'bss (ld-any nm ty fl))
       (nm = ".text" || ld-pre nm ".text.") 'text
       (nm = ".rodata" || ld-pre nm ".rodata.") 'rodata
       (nm = ".data" || ld-pre nm ".data.") 'data
       (nm = "love_nifs") 'nifs
       (nm = ".love.image") 'image
       ; the kernel lanes (ldkern's names): the boot stub's page tables and
       ; bring-up ladder, and the PVH note qemu reads to find the 32-bit entry.
       ; a hosted object carries neither.
       (nm = ".boot" || nm = ".boot.text") 'boot
       (nm = ".note.pvh") 'note
       (ld-any nm ty fl))

   ; parse one relocatable object (id names it in scares) -> a tablet
   ;   'id 'src            the name and the raw bytes
   ;   'secs               section index -> (lane off size align home), the placed ones
   ;   'lanes              lane -> its section indices, ascending (header order)
   ;   'drops              section index -> 1, the ones ruled out (see `class`)
   ;   'syms / 'nsym       symbol index -> (name bind typ shndx value size)
   ;   'relas              ((secidx (off kind symidx addend)..) ..), the addend ()
   ;                       on a rel, where it rides in the field instead
   ; layout pins 'base -- section index -> load address -- later. keying by index, not by
   ; lane, lets a lane hold more than one section: a symbol reads its base off its shndx.
   (ld-read id s mach)
    (: _ (? (s 0 = 127 && s 1 = 69 && s 2 = 76 && s 3 = 70) 0 (scare 'link-not-elf id))
       ; ei_class picks the wire shape; e_type and e_machine sit at 16 and 18 in both
       fs (? (s 4 = 2) elf64f (s 4 = 1) elf32f (scare 'link-elf-class id))
       _ (rle16 s 16 = 1 && rle16 s 18 = mach ? 0 (scare 'link-machine id))
       _ (ld-f fs s 0 'e-shent = ld-n fs 'sh-ent ? 0 (scare 'link-shentsize id))
       shoff (ld-f fs s 0 'e-shoff)
       shnum (ld-f fs s 0 'e-shnum) shstrx (ld-f fs s 0 'e-shstrx)
       (sh i) (shoff + i * ld-n fs 'sh-ent)          ; the i-th section header
       shstro (ld-f fs s (sh shstrx) 'sh-off)
       (sname i) (ld-cstr s (shstro + ld-f fs s (sh i) 'sh-name))
       secs {} lanes {} drops {}
       ob {'id id 'src s 'lanes lanes 'secs secs 'drops drops 'base {}}
       ; droppable, by what a section is and never by a hunch: empty; no shf_alloc, so the
       ; loader never maps it (.comment, .debug_*, .note.GNU-stack); a note, advisory; or
       ; the unwinder's tables, the one alloc family dropped by name. the index is recorded
       ; so a relocation pointing at a dropped section is skipped rather than scared at.
       (drop? i ty fl nm sz)
        (? ((sz = 0) || (0 = (fl & 2)) || (ty = 7) || ld-unwind? nm)
           (: _ (pin drops i 1) 1) ())
       ; classify: progbits and nobits onto their lane by name, symtab/rela by type, the
       ; droppable set by the rule above; anything else with bytes refuses. shf_tls is
       ; exactly that -- a pt_tls the one segment cannot express, where the data lane would
       ; give every thread the same variable.
       (class i symt rls)
        (? (shnum <= i) (symt . rls)
           (: h (sh i) ty (ld-f fs s h 'sh-type) fl (ld-f fs s h 'sh-flags)
              off (ld-f fs s h 'sh-off) sz (ld-f fs s h 'sh-size) nm (sname i)
              _ (0 < fl & 1024 && 0 < sz ? (scare 'link-tls nm))
              ; a note the loader reads is placed like progbits: .note.pvh is how `qemu
              ; -kernel` finds the 32-bit entry, so dropping it as advisory strands the kernel.
              (? (elem ty '(1 8) || ty = 7 && ld-lane nm ty fl)
                  ; sht_nobits (8) is the bss lane: no file bytes (sh_offset is a
                  ; placeholder), only size and alignment, address space past the last write.
                  (: lane (ld-lane nm ty fl)
                     (? lane (: _ (pin secs i [lane (? (ty = 8) 0 off) sz
                                               (ld-f fs s h 'sh-align) (ld-home lane fl ty)])
                                _ (pin lanes lane (i . lanes lane))
                                (class (i + 1) symt rls))
                        ; .comment is dropped like any non-alloc section and kept anyway: the
                        ; output's producer record is the union of its inputs'.
                        (drop? i ty fl nm sz)
                         (: _ (? (nm = ".comment") (pin ob 'comment (snip s off (off + sz))) 0)
                            (class (i + 1) symt rls))
                        (scare 'link-section nm)))
                 (ty = 2) (: _ (ld-esz fs s h 'sy-ent nm)
                             (class (i + 1) [off sz (ld-f fs s h 'sh-link)] rls))
                 (ty = ld-n fs 'rl-ty)
                  (: _ (ld-esz fs s h 'rl-ent nm)
                     (class (i + 1) symt ([(ld-f fs s h 'sh-info) off sz] . rls)))
                 (elem ty '(0 3)) (class (i + 1) symt rls)
                 (drop? i ty fl nm sz) (class (i + 1) symt rls)
                 (scare 'link-section nm))))
       cl (class 1 () ())
       ; the named lanes this object carries, first-seen in header order -- the lay order
       nmd (: (go i acc)
               (shnum <= i ? (rev acc)
                  (: se (secs i)
                     (go (i + 1) (? !(two? se) acc
                                    (elem <se ld-lanes) acc
                                    (elem <se acc) acc
                                    (<se . acc)))))
              (go 1 ()))
       _ (pin ob 'named nmd)
       ; the walk consed, so put each lane list back in the header order it lays in
       _ (foldl (\ _ l (pin lanes l (rev (lanes l)))) 0 (ld-lanes + nmd))
       symt <cl
       _ (atom? symt ? (scare 'link-no-symtab id))
       stro (ld-f fs s (sh (symt 2)) 'sh-off)    ; .strtab offset, via symtab's link
       syms {} _ (pin ob 'syms syms)
       nsym (symt 1 // ld-n fs 'sy-ent)
       _ (pin ob 'nsym nsym)
       _ (: (go i) (? (nsym <= i) 0
                      (: e (symt 0 + i * ld-n fs 'sy-ent)
                         info (ld-f fs s e 'sy-info)
                         _ (pin syms i [(ld-cstr s (stro + ld-f fs s e 'sy-name))
                                         (info >> 4) (info & 15)
                                         (ld-f fs s e 'sy-shndx) (ld-f fs s e 'sy-val)
                                         (ld-f fs s e 'sy-size)])
                         (go (i + 1))))
            (go 0))
       ; a .rela whose target was dropped is dropped with it; a target neither placed nor
       ; dropped scares. a rel has no addend column, so the slot arrives empty and the patch
       ; stage pulls it from the field per kind -- asked by presence, never by a zero addend.
       ad (ld-row fs 'rl-add)
       rent (ld-n fs 'rl-ent)
       relas (map (\ r (: n (r 2 // rent)
                          (es i acc) (? (i < 0) acc
                                        (: e (r 1 + i * rent)
                                           (es (i - 1)
                                               ([(ld-f fs s e 'rl-off) (ld-f fs s e 'rl-kind)
                                                 (ld-f fs s e 'rl-sym)
                                                 (two? ad ? (sg64 (ld-f fs s e 'rl-add)))] . acc))))
                          (<r . es (n - 1) ())))
                  (filter (\ r (? (two? (secs <r)) 1
                                  (drops <r) ()
                                  (scare 'link-rela-target id)))
                          >cl))
       _ (pin ob 'relas relas)
       ob)

   ; every symbol a file names, whatever its e_type -- `kore nm`'s door, where ld-read is
   ; et_rel by contract. a row is
   ;   (name bind typ shndx value size sec)
   ; sec the defining section's (name type flags), () when the symbol is undefined or names
   ; a reserved index. answers () rather than scaring with no sht_symtab: a stripped file
   ; has no symbols, and .dynsym is a different table this does not read.
   (ld-syms id s)
    (: _ (? (s 0 = 127 && s 1 = 69 && s 2 = 76 && s 3 = 70) 0 (scare 'link-not-elf id))
       fs (? (s 4 = 2) elf64f (s 4 = 1) elf32f (scare 'link-elf-class id))
       shoff (ld-f fs s 0 'e-shoff) shnum (ld-f fs s 0 'e-shnum)
       (sh i) (shoff + i * ld-n fs 'sh-ent)
       shstro (ld-f fs s (sh (ld-f fs s 0 'e-shstrx)) 'sh-off)
       (sname i) (ld-cstr s (shstro + ld-f fs s (sh i) 'sh-name))
       (find i) (? (shnum <= i) () (ld-f fs s (sh i) 'sh-type = 2) [i] (find (i + 1)))
       t (find 1)
       (? !(two? t) ()
          (: h (sh <t)
             _ (ld-esz fs s h 'sy-ent ".symtab")
             ent (ld-n fs 'sy-ent)
             off (ld-f fs s h 'sh-off) n (ld-f fs s h 'sh-size // ent)
             stro (ld-f fs s (sh (ld-f fs s h 'sh-link)) 'sh-off)
             ; index 0 is ELF's null symbol and names nothing -- the walk starts at 1
             (go i acc)
              (? (i < 1) acc
                 (: e (off + i * ent)
                    info (ld-f fs s e 'sy-info) x (ld-f fs s e 'sy-shndx)
                    (go (i - 1)
                        ([(ld-cstr s (stro + ld-f fs s e 'sy-name))
                          (info >> 4) (info & 15) x
                          (ld-f fs s e 'sy-val) (ld-f fs s e 'sy-size)
                          (? (0 < x && x < shnum)
                             [(sname x) (ld-f fs s (sh x) 'sh-type)
                              (ld-f fs s (sh x) 'sh-flags)])]
                         . acc))))
             (go (n - 1) ()))))

   ; -- archives. the noms no object defines but the linker lays: a driver over any
   ; door here answers for these, so a ledger must not go looking for them in a .a.
   ldsynth '("__start_love_nifs" "__stop_love_nifs" "__start_love_rela" "__stop_love_rela"
             "__data_start__" "__data_end__" "__data_load__"
             "__bss_start__" "__bss_end__" "__load_size__")
   (dusyms id bs mach)                     ; (id bytes) -> (defs strong-undefs), global noms
    (: ob (ld-read id bs mach) sy9 (peep ob 'syms 0)
       (go i ds us)
        (? (peep ob 'nsym 0 <= i) [ds us]
           (: sy (sy9 i) bind (sy 1)
              (? !(elem bind '(1 2)) (go (i + 1) ds us)
                 (0 < sy 3) (go (i + 1) (<sy . ds) us)
                 (bind = 1) (go (i + 1) ds (<sy . us))
                 (go (i + 1) ds us))))    ; a weak undef resolves to 0 (ELF's law): no need
       (go 1 () ()))
   ; --- writing one: `ar rcs` as a function, below dusyms because the index is dusyms'
   ; own answer. deterministic (date/uid/gid 0, mode 644) and always indexed, since the
   ; reader refuses an archive without one. `ms` is ((name bytes)..) and the names must be
   ; unique: a second member spelling one name is unreachable through the index.
   (ld-arp w s) (#s < w ? (ld-arp w (s + " ")) s)      ; ar fields are left-justified
   (ld-arb4 v) (string ((v >> 24) & 255) + string ((v >> 16) & 255) + string ((v >> 8) & 255) + string (v & 255))
   (ld-arhdr nm date uid gid mode sz)
    (ld-arp 16 nm + ld-arp 12 date + ld-arp 6 uid + ld-arp 6 gid + ld-arp 8 mode + ld-arp 10 (show sz) + "`\n")
   (ld-arpad s) (#s & 1 ? (s + "\n") s)              ; members lie on even offsets
   (ld-arelf? b) (20 <= #b && b 0 = 127 && b 1 = 69 && b 2 = 76 && b 3 = 70)
   ; a member's defined globals, read by the ledger's own eye -- so what the index
   ; promises and what a pull then finds cannot part. a non-ELF member defines nothing.
   (ld-ardefs f b) (? (ld-arelf? b) <(dusyms f b (b 18 + (256 * b 19))) ())
   (arbytes ms)                                               ; ms: ((name bytes)..) -> the archive
    (: names (map cap ms)
       datas (map caup ms)
       ; the long-name table: parallel to names, each entry (offset) | ()
       lofs (: (go l off acc) (? !(two? l) (rev acc)
                                 (: ln #<l
                                    (? (ln < 16) (go >l off (() . acc))
                                       (go >l (off + ln + 2) ([off] . acc)))))
               (go names 0 ()))
       ltab (: (go ns ls) (? !(two? ns) ""
                             (two? <ls ? (<ns + "/\n" + go >ns >ls) (go >ns >ls)))
               (go names lofs))
       syml (map (m \ ld-ardefs <m <>m) ms)
       nsym (foldl (+) 0 (map tally syml))
       strt (foldl (+) "" (map (ss \ foldl (a \ s \ a + s + string 0) "" ss) syml))
       ; the index pads to even with a NUL that counts in its size field (GNU's
       ; spelling -- members pad with "\n" excluded from theirs)
       isz (: z (4 + 4 * nsym + #strt) (z + (& z 1)))
       ; member header offsets: magic, index hdr + data, "//" (when any), then each
       m0 (8 + 60 + isz)
       m1 (? #ltab (m0 + 60 + #ltab + (#ltab & 1)) m0)
       offs (: (go ds off acc) (? !(two? ds) (rev acc)
                                (go >ds (off + 60 + (: z #<ds (z + (z & 1)))) (off . acc)))
               (go datas m1 ()))
       idx (: raw ((ld-arb4 nsym
                    + (: (go os ss) (? !(two? os) ""
                                       (foldl (\ a _ (a + ld-arb4 <os)) "" <ss + go >os >ss))
                         (go offs syml)))
                   + strt)
              (#raw & 1 ? (raw + string 0) raw))
       body (: (go ns ls ds) (? !(two? ns) ""
                                (: nf (two? <ls ? ("/" + show <<ls) (<ns + "/"))
                                 (ld-arhdr nf "0" "0" "0" "644" #<ds + ld-arpad <ds + go >ns >ls >ds)))
               (go names lofs datas))
       ((("!<arch>\n" + ld-arhdr "/" "0" "0" "0" "0" isz + idx)
         + (? #ltab (ld-arhdr "//" "" "" "" "" #ltab + ld-arpad ltab) ""))
        + body))
   ; the ledger a set of objects leaves: every nom it defines, plus the synthesized ones,
   ; and the strong undefineds still owed -> (dt owed), dt a tablet the caller pins into.
   ; a __start_X/__stop_X pair is the linker's to answer (ldres), so the ledger leaves it --
   ; a bracket over a lane that never lays still scares, at the link.
   (ld-bracket? nm)
    (: z #nm (8 < z && snip nm 0 8 = "__start_" ||
              7 < z && snip nm 0 7 = "__stop_"))
   (ldledger srcs mach)
    (: duos (map (\ p (dusyms <p <>p mach)) srcs)
       dt (tablet 0)
       _ (map (nm \ pin dt nm 1) ldsynth)
       _ (map (du \ map (nm \ pin dt nm 1) <du) duos)
       [dt (foldl (\ a du (foldl (\ a2 nm (? (dt nm || elem nm a2
                                              || ld-bracket? nm) a2 (nm . a2)))
                                 a <>du))
                  () duos)])
   ; an archive resolves by need and by index: the ranlib table names the member defining
   ; each owed nom, and a pulled member's undefineds join the owe and the round repeats.
   ; -> (picked-srcs owed); `dt` grows in place, as the ledger's owner expects.
   (arpull path s dt owed mach)
    (: idx (ld-arsyms path s) lt (ld-arlong s) seen {}
       (go u picked)
        (: hit (foldl (\ a nm (two? a ? a
                                 (: o (idx nm)
                                    (? !(o-has? idx nm) a (o-has? seen o) a [o]))))
                      () u)
           (? !(two? hit) [picked u]
              (: off <hit
                 _ (pin seen off 1)
                 m (ld-armem s off lt)
                 id (path + "(" + <m + ")")
                 du (dusyms id <>m mach)
                 _ (map (nm \ pin dt nm 1) <du)
                 u2 (foldl (\ a nm (dt nm || elem nm a ? a (nm . a)))
                           (filter (nil? * dt) u) <>du)
                 (go u2 (picked + [[id <>m]])))))
       (go owed ()))
   ; every archive on the line, in command order and after every object. `pairs` are
   ; already-read (path bytes), so the file I/O and its diagnostics stay with the caller.
   (ldarch srcs pairs tgt)
    (? !(two? pairs) ()
       (: mach (peep elf-machines tgt 0)
          lg (ldledger srcs mach) dt <lg
          (go ps u acc)
           (? !(two? ps) acc
              (: r <ps
                 _ (? (ld-ar? <>r) 0 (scare 'link-not-archive <r))
                 pr (arpull <r <>r dt u mach)
                 (go >ps <>pr (acc + <pr))))
          (go pairs <>lg ())))

   ; lay one lane across the set in object order, sections in header order, each aligned as
   ; its own header asks. pins the base per section index; answers the address past the last.
   (ldlay1 lane cur os)
    (? !(two? os) cur
       (: ob <os bs (peep ob 'base 0)
          (go c is) (? !(two? is) c
                       (: se (peep (peep ob 'secs 0) <is ())
                          a (ld-align (se 3) c)
                          _ (pin bs <is a)
                          (go (a + se 2) >is)))
          (ldlay1 lane (go cur (peep (peep ob 'lanes 0) lane ())) >os)))

   ; the named lanes of a set that travel with `home`, deduped, first-seen order
   ; (object order, then header order) -- the one order layout and emit both walk.
   (ld-nlanes objs home)
    (: seen {}
       (nhome ob l) ((peep (peep ob 'secs 0) <(peep (peep ob 'lanes 0) l ()) ()) 4)
       (go os acc)
        (? !(two? os) (rev acc)
           (: ob <os
              (go >os (foldl (\ a l (? (0 < peep seen l 0 || nhome ob l != home) a
                                       (pin seen l 1, l . a)))
                             acc (ob 'named)))))
       (go objs ()))
   ; lay them, each whole, after the known lane they travel with -> the next address
   (ldlayn home cur objs)
    (foldl (c \ l \ ldlay1 l c objs) cur (ld-nlanes objs home))
   ; and emit them in that same order: the bytes and the addresses are one walk
   (ldemitn cx home objs r)
    (foldl (a \ l \ ldemit cx l <a objs >a) r (ld-nlanes objs home))

   ; how many bytes a lane holds in one object. a named lane is recorded even when empty
   ; (every object carries a zero-size .image), so weigh the bytes, never count sections.
   (ld-lanesz ob lane)
    (foldl (\ a i (a + (peep (peep ob 'secs 0) i ()) 2))
           0 (peep (peep ob 'lanes 0) lane ()))

   ; assign every section its load address: header first (hdrsz reserves the ELF header and
   ; one phdr per segment), then text, rodata, data, then the nif region -- 16-aligned once
   ; and packed tight, so the __start_/__stop_ bracket reads it as one array across every
   ; object. bss owns no file bytes and is laid last, by ldlink. pins the bases.
   ; salign is the grain the three lanes may be cut on: a page where each takes its own
   ; segment, 1 to pack tight. dense 0 writes the gap at a cut out as zeros (what a format
   ; wanting its sections on the grain needs); 1 carries the offset on and lets the address
   ; skip the page instead, so the file pays nothing. -> (end nifstart o0 d0 t1 o1), the
   ; ends among the starts because under dense 1 they are no longer the same numbers.
   (ldlay objs base hdrsz salign dense)
    (: (cut v f) (? dense (ld-lift salign v f) (ld-align salign v))
       t1 (ldlayn 'text (ldlay1 'text (base + hdrsz) objs) objs)
       o0 (cut t1 (t1 - base))
       o1 (ldlayn 'rodata (ldlay1 'rodata o0 objs) objs)
       d0 (cut o1 (o1 - base - (o0 - t1)))
       d1 (ldlayn 'data (ldlay1 'data d0 objs) objs)
       n0 (ld-align 16 d1)
       [(ldlay1 'nifs n0 objs) n0 o0 d0 t1 o1])

   ; the one symbol book: name -> (addr weak?), every defined global/weak across the set.
   ; a strong def beats any weak; two strongs scare; the first weak stands until a strong.
   (ldsyms objs)
    (: glo {}
       (one ob i)
        (? (peep ob 'nsym 0 <= i) 0
           (: sy (peep (peep ob 'syms 0) i ())
              bind (sy 1) shx (sy 3)
              (? (shx = 0 || !(elem bind '(1 2))) (one ob (i + 1))
                 (: nm <sy
                    _ (? (two? (peep (peep ob 'secs 0) shx ())) 0
                         (scare 'link-sym-section nm))
                    a (peep (peep ob 'base 0) shx 0 + sy 4)
                    w (bind = 2)
                    old (peep glo nm ())
                    _ (? !(two? old) (pin glo nm [a w])
                         w 0                                   ; incoming weak: the standing def keeps
                         (old 1) (pin glo nm [a w])     ; strong replaces weak
                         (scare 'link-dup nm))
                    (one ob (i + 1))))))
       _ (: (each os) (? !(two? os) 0 (one <os 1, each >os))
            (each objs))
       glo)

   ; the extents of every named lane, once laid: lane -> (start end). ldres's
   ; generic bracket reads it -- an empty lane never enters, so a miss stays a miss.
   (ld-extents objs)
    (: xt {}
       _ (map (ob \ map (l \ map (i \ : a (peep (peep ob 'base 0) i 0)
                                        e (a + peep (peep ob 'secs 0) i () 2)
                                        r (xt l)
                                        (pin xt l (? !(two? r) [a e] [(a < <r ? a <r) (<>r < e ? e <>r)])))
                                   (peep (peep ob 'lanes 0) l ()))
                         (ob 'named))
              objs)
       xt)

   ; resolve a name: the symbol book, or a synthesized bracket -- the nif region (n0..n1),
   ; under -pie the relative-reloc table (r0..r1) moonlibc's startup walks to slide every
   ; abs64 data pointer by the load base (non-pie leaves r0 == r1, an empty table) -- or
   ; ld's generic rule: a section named X brackets as __start_X/__stop_X off its extent.
   (ldres glo n0 n1 r0 r1 xt nm)
    (: r (glo nm)
       (? (two? r) <r
          (nm = "__start_love_nifs") n0
          (nm = "__stop_love_nifs") n1
          (nm = "__start_love_rela") r0
          (nm = "__stop_love_rela") r1
          (: z #nm
             x (? (8 < z && snip nm 0 8 = "__start_")
                   (: v (xt (name (snip nm 8 z))) (two? v ? [<v]))
                  (7 < z && snip nm 0 7 = "__stop_")
                   (: v (xt (name (snip nm 7 z))) (two? v ? [<>v])))
             (two? x ? <x (scare 'link-undef nm)))))

   ; patch one object's one section: stream its bytes, splicing each relocation's field. a
   ; section-symbol reloc lands on the object's own section base; a named one resolves
   ; through the book. entries arrive in ascending offset order (obj.l's walk order), and
   ; pieces come out as text snips + byte lists.
   ; rv flags an em_rv64 link: R_RISCV_64 is 2, the same number as R_X86_64_PC32, so the
   ; kind dispatch below switches on the machine and never on the number alone.
   ; cx is the context every lane shares: (glo n0 n1 r0 r1 relbox rv arm? be xt) -- the
   ; symbol book, the two brackets, the -pie site box, the riscv and EM_ARM flags, the
   ; backend the ARM lane re-encodes through, and the named-lane extents.
   (ldpatch ob ix base [glo n0 n1 r0 r1 relbox rv arm? be xt])
    (: s (peep ob 'src 0) se (peep (peep ob 'secs 0) ix ())
       off0 (se 1) sz (se 2)
       (ent es) (? !(two? es) ()
                   (<<es = ix) ><es
                   (ent >es))
       (go pos es acc)
        (? !(two? es) (rev (snip s pos (off0 + sz) . acc))
           (: e <es ro <e kind (e 1) ad (e 3)
              _ (pos - off0 <= ro ? 0 (scare 'link-unsorted (peep ob 'id 0)))
              sy (peep (peep ob 'syms 0) (e 2) ())
              sv (? (sy 2 = 3)                   ; stt_section: the section's base
                    (: _ (? (two? (peep (peep ob 'secs 0) (sy 3) ())) 0
                            (scare 'link-sym-section (peep ob 'id 0)))
                       (peep (peep ob 'base 0) (sy 3) 0))
                    ; a local defined symbol is its own object's business: base + value off
                    ; the object that carried it (clang relocates against .L labels). never
                    ; the global book -- a namesake from another object would answer wrong.
                    (sy 1 = 0 && 0 < sy 3 < 65280)
                     (: _ (? (two? (peep (peep ob 'secs 0) (sy 3) ())) 0
                             (scare 'link-sym-section <sy))
                        (peep (peep ob 'base 0) (sy 3) 0 + sy 4))
                    ; a weak undefined symbol resolves to zero (ELF's law, and musl's
                    ; __init_tls leans on it); only a strong one unresolved is an error.
                    (sy 1 = 2 && sy 3 = 0 && atom? (glo <sy)) 0
                    (ldres glo n0 n1 r0 r1 xt <sy))
              ; the two classes part here and nowhere else: an ARM field is 4 bytes wide
              ; whatever the kind, its addend already in it, and `ad` arrives ().
              (? arm?
                 (: _ (ro + 4 <= sz ? 0 (scare 'link-oob (peep ob 'id 0)))
                    ; the emit-relocs half: an abs32 site holds an address this link wrote,
                    ; so a loader adds its delta here. pc-relative kinds travel with the code.
                    _ (relbox && kind = 2 ? (pin relbox 0 ((base + ro) . relbox 0)))
                    ; ..and a movw/movt pair is absolute too, but carries the address as two
                    ; split immediates no loader can slide. the seats asked for a relocatable
                    ; image route `la` through a pooled abs32 word; scare rather than be short.
                    _ (relbox && elem kind '(47 48) ? (scare 'link-abs-imm <sy))
                    (go (off0 + ro + 4) >es
                        (ldarm be s (off0 + ro) sv kind (base + ro)
                         . (snip s pos (off0 + ro) . acc))))
                 (: sa (ld-u64 (sv + ad))              ; S + A, wrapped as a linker wraps it
                    prel (sg64 (ld-u64 (sa - (base + ro))))            ; ..and S + A - P, signed
                    abs64? (? rv (kind = 2) (elem kind '(1 257)))   ; R_RISCV_64 / R_X86_64_64 / R_AARCH64_ABS64
                    ; R_X86_64_32 / _32S: S + a absolute into a 4-byte field. always a
                    ; foreign object's -- we emit the 64-bit or pc-relative form.
                    abs32? (!rv && elem kind '(10 11))
                    w (? abs64? 8 (rv && kind = 19) 8 4)             ; call_plt spans the auipc pair
                    ; -pie: this abs64 site holds a base-0 offset (base is 0), so record its
                    ; load-address for the startup relocator to add the real base to.
                    _ (relbox && abs64? ? (pin relbox 0 (base + ro . relbox 0)))
                    ; ..and an abs32 site cannot be slid: a 32-bit field has nowhere to
                    ; put the 64-bit base the startup relocator adds.
                    _ (relbox && abs32? ? (scare 'link-abs32-pie <sy))
                    _ (? (elem kind $ rv ? '(2 17 19 57)
                                              '(1 2 4 10 11 257 261 275 277 278 282 283 284 285 286 299))
                         0 (scare 'link-reloc kind))
                    _ (ro + w <= sz ? 0 (scare 'link-oob (peep ob 'id 0)))
                    ; the a64/riscv field kinds patch bits of the instruction word the
                    ; placeholder carries -- read it back and or the field in
                    wd (? abs64? 0 (rle32 s (off0 + ro)))
                    bs (? abs64? (le64 sa)                             ; the abs64 three: S + a outright
                          abs32?                                       ; ..and the two abs32, range-checked
                           ; _32 is unsigned and _32S signed, so each reads the wrapped sum
                           ; its own way and checks its own range.
                           (: v (kind = 10 ? sa (sg64 sa))
                              _ (kind = 10 && v <= 4294967295 || ld-fits32 v ? 0 (scare 'link-range <sy))
                              (le32 v))
                          (rv && kind = 17)                          ; R_RISCV_JAL: S+a-p into jal's j-imm
                           (: v prel
                              _ (? (-1048576 <= v <= 1048575) 0 (scare 'link-range <sy))
                              u (v & 2097151)
                              (le32 (wd | ((((u >> 20) & 1) << 31) | ((((u >> 1) & 1023) << 21)
                                        | ((((u >> 11) & 1) << 20) | (((u >> 12) & 255) << 12)))))))
                          (rv && kind = 19)                          ; R_RISCV_CALL_PLT: S+a-p as hi20 + signed lo12
                           (: v prel
                              low (v & 4095) lo (low > 2047 ? (low - 4096) low)
                              hi ((v - lo) // 4096)
                              _ (? (-524288 <= hi <= 524287) 0 (scare 'link-range <sy))
                              (le32 (wd | ((hi & 1048575) << 12))
                               + le32 (rle32 s (off0 + ro + 4) | ((lo & 4095) << 20))))
                          (elem kind '(2 4 261) || (rv && kind = 57))
                           (: v prel                          ; pc32/plt32/32_pcrel: S + A - P
                              _ (ld-fits32 v ? 0 (scare 'link-range <sy))
                              (le32 v))
                          (elem kind '(282 283))           ; jump26/call26: (S+A-P)>>2 into imm26
                           (: v prel
                              _ (-134217728 <= v <= 134217727 ? 0 (scare 'link-range <sy))
                              (le32 (wd | (v // 4 & 67108863))))
                          (kind = 275)                        ; adr_prel_pg_hi21: page(S+A)-page(P) into adrp
                           (: pg (sa // 4096 - (base + ro) // 4096)
                              _ (-1048576 <= pg <= 1048575 ? 0 (scare 'link-range <sy))
                              (le32 (wd | (((pg & 3) << 29) | (((pg >> 2) & 524287) << 5)))))
                          ; the abs_lo12_nc family is one field: the low 12 bits of S+a into
                          ; imm12, scaled by the width the opcode implies (an `ldr x` counts
                          ; 8-byte units). the ldst widths arrive from a foreign object.
                          (: sc (kind @ 284 2 285 4 286 8 299 16 1)
                             (le32 (wd | (((sa % 4096) // sc) << 10)))))
                    (go (off0 + ro + w) >es
                        (bs . snip s pos (off0 + ro) . acc))))))
       (go off0 (ent (ob 'relas)) ()))

   ; emit one lane in layout order -- object by object, sections in header order --
   ; zero-padding up to each base, so the file offsets land where the layout put the
   ; addresses. answers (end . pieces), so the next lane picks up where this one stopped.
   (ldemit cx lane cur os acc)
    (? !(two? os) (cur . acc)
       (: ob <os
          (go c ac is)
           (? !(two? is) (c . ac)
              (: se (peep (peep ob 'secs 0) <is ())
                 b (peep (peep ob 'base 0) <is 0)
                 pad (c < b ? [(ld-zeros (b - c))])
                 (go (b + se 2) (ac + pad + ldpatch ob <is b cx) >is)))
          r (go cur acc (peep (peep ob 'lanes 0) lane ()))
          (ldemit cx lane <r >os >r)))

   ; a 24-byte Elf64_Sym and a 64-byte Elf64_Shdr. the symbol is obj.l's o-sym with
   ; st_size carried instead of zeroed: a foreign object reports real function extents.
   (ld-sym nameoff bind typ shndx value size)
    (catall [(le32 nameoff) [((bind << 4) | typ) 0] (le16 shndx) (le64 value) (le64 size)])
   (ld-shdr nm ty fl ad off sz lk inf al es)
    (catall [(le32 nm) (le32 ty) (le64 fl) (le64 ad) (le64 off) (le64 sz)
             (le32 lk) (le32 inf) (le64 al) (le64 es)])
   ; the elf32 twins -- 16 bytes and 40. Elf32_Sym reorders (st_value and st_size ahead of
   ; st_info/st_other/st_shndx), the same fact the field table up top records at the reading
   ; end, so it is its own door; the section header holds its order and is a twin.
   (ld-sym32 nameoff bind typ shndx value size)
    (catall [(le32 nameoff) (le32 value) (le32 size) [((bind << 4) | typ) 0] (le16 shndx)])
   (ld-shdr32 nm ty fl ad off sz lk inf al es)
    (catall [(le32 nm) (le32 ty) (le32 fl) (le32 ad) (le32 off) (le32 sz)
             (le32 lk) (le32 inf) (le32 al) (le32 es)])

   ; the executable's symbol table -- what makes `nm`, a labeled `objdump -d` and a gdb
   ; `break main` work on a binary of ours. every defined symbol across the set: locals
   ; first (ELF requires it, and .symtab's sh_info names the first global), then the globals
   ; that won the link. st_size rides through from the object -- ours say 0, and a size-0
   ; symbol is bounded by the next one, as every reader already assumes.
   ; lanesx maps a lane to its section index in the image -- by the lane where the caller
   ; laid one header per lane, else by the section's home, so a symbol in a compiler-named
   ; lane is classified as what it travels with rather than landing in undef. mksym/esz are
   ; the class's entry writer and stride. -> (bytes strs nlocal)
   (ldstab objs glo lanesx mksym esz)
    (: (lx se) (? (o-has? lanesx (se 0)) (peep lanesx (se 0) 0)
                  (peep lanesx (se 4) 0))
       (one ob acc)
        (: bs (peep ob 'base 0) secs (peep ob 'secs 0) syms (peep ob 'syms 0)
           (go i a)
            (? (peep ob 'nsym 0 <= i) a
               (: sy (syms i)
                  nm <sy bind (sy 1) typ (sy 2) shx (sy 3)
                  se (secs shx)
                  ad (peep bs shx 0 + sy 4)
                  won (: r (glo nm) (two? r ? (ad = <r) 0))
                  (go (i + 1)
                      (? (atom? se || 0 = #nm ||
                          !(elem typ '(0 1 2)) || !(elem bind '(0 1 2)))
                          a                             ; undefined, unnamed, a file/section marker, or dropped
                         ; a weak def a strong one replaced: its bytes stay laid, so the span
                         ; keeps a symbol rather than charging them to the one before it --
                         ; demoted to local and suffixed, since glo holds the winner.
                         (0 < bind && !won) ([(nm + ".lost") 0 typ (lx se) ad (sy 5)] . a)
                         ([nm bind typ (lx se) ad (sy 5)] . a)))))
           (go 1 acc))
       all (foldl (\ a ob (one ob a)) () objs)
       locs (filter (e \ <>e = 0) all)
       ord (locs + filter (e \ 0 < <>e) all)
       str (o-strtab (map cap ord))
       ; index 0 is the reserved NULL entry, and it counts as a local
       [(ld-zeros esz + catall (o-mapi (\ i e (mksym (<>str i) (e 1) (e 2)
                                                        (e 3) (e 4) (e 5)))
                                         ord))
        <str (1 + tally locs)])

   ; count the abs64 (R_X86_64_64 / R_AARCH64_ABS64) data relocations across the
   ; set -- the entry count of the -pie relocation table (8 bytes each).
   (ld-nabs objs rv)
    (foldl (\ a ob (foldl (\ a2 tr
              (foldl (\ a3 e (? (? rv (e 1 = 2) (elem (e 1) '(1 257))) (a3 + 1) a3)) a2 >tr))
              a (peep ob 'relas ())))
       0 objs)

   ; -- .comment, the producer record: NUL-separated strings, no shf_alloc, laid past
   ; p_filesz. `prod` wrote this file; the inputs' records ride ahead of it, deduped.
   ; a blob need not end in NUL, so the split is bounded, never ld-cstr's walk.
   (ld-cmsplit s)
    (: n #s
       (go i j acc) (? (n <= j) (rev (? (j <= i) acc (snip s i j . acc)))
                       (s j = 0) (go (j + 1) (j + 1) (? (j <= i) acc (snip s i j . acc)))
                       (go i (j + 1) acc))
       (go 0 0 ()))
   (ld-comment objs prod)
    (: (add acc t) (elem t acc ? acc (acc + [t]))
       ins (foldl (\ a ob (a + ld-cmsplit (peep ob 'comment ""))) () objs)
       (catall (map (t \ o-strbytes t + '(0)) (foldl add () (ins + [prod])))))

   ; link a set of objects -- ((id bytes-text)..) -- into a static-exe piece list (texts +
   ; byte lists; ld-write lays them down). entry = the first object's text. three segments
   ; map the file -- R+X code, R literals, R+W data -- plus a fourth for .image.
   ; pie: emit et_dyn laid at base 0, collect every abs64 site into a trailing offset table
   ; bracketed by __start_/__stop_love_rela, and let moonlibc's startup add the load base.
   ; org: () takes the default base (pie 0 / elf-base); a number lays the image there --
   ; the bare-metal lane, where `qemu -kernel` loads at p_vaddr and enters at e_entry.
   ; prod: the producer string for .comment, the base half of love-version and never the
   ; whole id: the vcs suffix names the commit that built the compiler, so love1 and love2
   ; would carry different strings and differ at e_shoff -- a broken fixpoint where the two
   ; compilers agree on every byte they emit. both doors say the same word (`love <base>`),
   ; and the full id is in love-version, in .rodata, for a reader who wants the commit.
   ; readme: plain text laid in `.love.README` beside .comment and mapped by nothing --
   ; `readelf -p .love.README` prints it and `strings` finds it. "" lays none.
   (ldlink target pie org srcs prod readme)
    (: mach (peep elf-machines target 0)
       _ (? (0 < mach) 0 (scare 'link-target target))
       objs (map (p \ ld-read <p <>p mach) srcs)
       rv (mach = 243)                          ; em_rv64: its own reloc-number namespace (see ldpatch)
       ; the page a segment stands on, not the page the MMU happens to run: a loader maps
       ; each PT_LOAD from p_vaddr rounded down to the kernel's page size, so two segments
       ; sharing one are laid over each other. aarch64 meets 4K, 16K and 64K kernels, so it
       ; answers the largest; x86-64 and riscv have one page wherever they run.
       pg (mach = 183 ? 65536 4096)
       base (? (charm? org) org pie 0 elf-base)
       ; w^x gives each lane the rights it needs and no others -- three segments, nothing
       ; ever two at once -- but only where an OS enforces it. `org` is the bare-metal lane
       ; and keeps its one segment: the header reserve sits below the text address, so
       ; inle/virt asks for 0x80000000 - hdrsz by hand and one segment more here would move
       ; the hart's first instruction. the reserve is the header plus one phdr per segment
       ; (.image takes one too), and every caller reads it off the count.
       img? (0 < foldl (\ a ob (a + ld-lanesz ob 'image)) 0 objs)
       wx? !(charm? org)
       ; netbsd's exec requires the ident note (no note -> ENOEXEC; other kernels ignore
       ; notes). 24 bytes in the header reserve, pt_note plus an alloc section so strip
       ; keeps it, on the ISAs that can meet that kernel.
       nb? (wx? && (elem mach '(62 183)))
       hdrsz (64 + 56 * ((? wx? 3 1) + (? img? 1 0) + (? nb? 1 0)) + (? nb? 24 0))
       nbo (hdrsz - 24)
       nbnote (? nb? (catall [(le32 7) (le32 4) (le32 1)                 ; namesz descsz netbsd_tag
                              '(78 101 116 66 83 68 0 0) (le32 1000000000)]))   ; "NetBSD\0\0", 10.0
                  
       lay (ldlay objs base hdrsz (? wx? pg 1) 1)
       end <lay n0 <>lay o0 <>>lay d0 <>>>lay t1 (lay 4) o1 (lay 5)
       ; the address the lay skipped to seat the cuts, which the file does not carry. below
       ; o0 an offset is `addr - base`, o0 itself is at `t1 - base`, from d0 on it is
       ; `addr - base - sk` -- each term 0 or a whole page, so offset stays congruent.
       sk ((o0 - t1) + (d0 - o1))
       nrel (? pie (ld-nabs objs rv) 0)
       r0 (? pie (ld-align 16 end) end)         ; the reloc table starts 16-aligned, just past the nifs
       r1 (r0 + 8 * nrel)
       ; ..and the segment's file bytes end on 16, so .bss and .image open on the alignment
       ; their own headers claim. the slack is claimed by no section: inside .love.rela it
       ; would be a table entry, and the relocator would read that zero as a site at base.
       dend (ld-align 16 r1)
       ; .bss last: p_memsz runs out to bend where p_filesz stops at dend, and the kernel
       ; hands over the difference already zeroed.
       bend (ldlayn 'bss (ldlay1 'bss dend objs) objs)
       ; .image last of all -- past .bss, so `love bake` can grow it at the tail of the file
       ; (inle/image.c: the section that ends the segment is the one that can grow without
       ; moving anything). it takes a segment of its own, because .bss sits between it and
       ; everything written and one segment would carry that gap as file zeros. no .image
       ; section in the set and the lane costs nothing: one segment, as before.
       ioff (dend - base - sk)                  ; the file stops where the data segment's bytes do..
       iaddr (? img? (ld-lift pg bend ioff) dend)  ; ..and the image's address is lifted onto it
       iend (? img? (ldlay1 'image iaddr objs) dend)
       isz (iend - iaddr)
       endf (? img? (ioff + isz) ioff)          ; the file bytes the segments carry
       ; the lift keeps the address congruent to the offset mod a page, which says nothing
       ; about the 16-grain .image asks for, so the contents seat up to 15 bytes above
       ; iaddr. the headers name that, never the lane's start: a header beginning below its
       ; own first byte is an image the wake cannot find, and a missed wake boots the egg.
       ist (? img? (ld-align 16 iaddr) iaddr)   ; where the lane's bytes actually start
       isho (ioff + (ist - iaddr))              ; ..its file offset, moved by the same pad
       iszr (iend - ist)                        ; ..and the size from there
       relbox (? pie {0 ()} ())    ; abs64 site accumulator (pie only)
       glo (ldsyms objs)
       ; the entry: ld's rule -- `_start` when the set defines one, else the first object's
       ; text (mooncc's crt0 lane, which names its entry __ai_start and relies on being
       ; first). a foreign libc brings its own _start and must be entered through it.
       ent (: e (glo "_start")
              o1 <objs
              (? (two? e) <e
                 (peep (peep o1 'base 0) <(peep (peep o1 'lanes 0) 'text ()) 0)))
       cx [glo n0 end r0 r1 relbox rv () () (ld-extents objs)]
       et (ldemitn cx 'text objs (ldemit cx 'text (base + hdrsz) objs ()))
       eo (ldemitn cx 'rodata objs (ldemit cx 'rodata o0 objs >et))
       ed (ldemitn cx 'data objs (ldemit cx 'data d0 objs >eo))
       en (ldemit cx 'nifs <ed objs >ed)
       tail (<en < r0 ? [(ld-zeros (r0 - <en))])       ; nif tail + table alignment in one pad
       rtab ((? pie (catall (map le64 (rev (peep relbox 0 ())))) ()) + (ld-zeros (dend - r1)))
       ei (? img? (ldemit cx 'image iaddr objs ()) [iaddr])
       ; -- the section headers and the symbol table, laid past p_filesz. nothing here is
       ; shf_alloc, so the kernel maps not a byte of it; nm, objdump and gdb read exactly
       ; this. every loaded byte gets a covering header (love_rela names the -pie table):
       ; strip rebuilds a file from its sections, and an orphan gap comes back as zeros.
       lanesx {'text 1 'rodata 2 'data 3 'nifs 4 'bss 6 'image 7}
       st (ldstab objs glo lanesx ld-sym 24)
       ; .comment goes last so no index moves: e_shstrndx and .symtab's sh_link are written
       ; down as 10 and 9, and a section spliced in ahead points both at the wrong table.
       ; the object says love_nifs and the binary says .love.nifs -- the split is the rule.
       ; GNU ld synthesizes __start_X/__stop_X only where X is a C identifier, and love.h
       ; spells that pair in C, so an object must carry the undotted name or the gcc-built
       ; love0 drains no nifs. ldres defines the pair by hand and owes the output name none.
       shstr (o-strtab '(".text" ".rodata" ".data" ".love.nifs" ".love.rela" ".bss" ".love.image"
                         ".symtab" ".strtab" ".shstrtab" ".comment" ".love.README" ".note.netbsd.ident"))
       (snm k) (<>shstr k)
       symo (ld-align 8 endf) symz #<st
       stro (symo + symz) strz #<>st
       ssto (stro + strz) sstz #<shstr
       cmt (ld-comment objs prod) cmto (ssto + sstz) cmtz #cmt
       rdm (string? readme ? (o-strbytes readme))
       rdmo (cmto + cmtz) rdmz #rdm
       nsh ((0 < rdmz ? 13 12) + ?nb?)
       shto (ld-align 8 (rdmo + rdmz))
       sht (catall [(ld-shdr 0 0 0 0 0 0 0 0 0 0)                                    ; the reserved null header
                     ; a lane stops where its bytes stop -- the next one's address may sit a
                     ; page on, but its offset is the very next byte, so no gap is left unowned
                    (ld-shdr (snm 0) 1 6 (base + hdrsz) hdrsz (t1 - (base + hdrsz)) 0 0 16 0)
                    (ld-shdr (snm 1) 1 2 o0 (t1 - base) (o1 - o0) 0 0 16 0)
                    (ld-shdr (snm 2) 1 3 d0 (d0 - base - sk) (<ed - d0) 0 0 16 0)
                    (ld-shdr (snm 3) 1 3 <ed (<ed - base - sk) (<en - <ed) 0 0 16 0)
                    (ld-shdr (snm 4) 1 2 r0 (r0 - base - sk) (r1 - r0) 0 0 16 0)     ; love_rela, the -pie table (empty non-pie)
                    (ld-shdr (snm 5) 8 3 dend (dend - base - sk) (bend - dend) 0 0 16 0)   ; NOBITS: an offset, no bytes
                    (ld-shdr (snm 6) 1 3 ist isho iszr 0 0 16 0)                     ; .image, the grow slot -- its own segment
                    (ld-shdr (snm 7) 2 0 0 symo symz 9 (st 2) 8 24)               ; link=.strtab info=first global
                    (ld-shdr (snm 8) 3 0 0 stro strz 0 0 1 0)
                    (ld-shdr (snm 9) 3 0 0 ssto sstz 0 0 1 0)
                    (ld-shdr (snm 10) 1 48 0 cmto cmtz 0 0 1 1)                     ; .comment: merge|strings, no alloc
                    (? (0 < rdmz) (ld-shdr (snm 11) 1 32 0 rdmo rdmz 0 0 1 0) ())    ; .love.readme: strings, no alloc
                    (? nb? (ld-shdr (snm 12) 7 2 (base + nbo) nbo 24 0 0 4 0) ())])   ; sht_note, alloc: strip keeps it
       ; w^x: segment one the header and the code, read+execute; two the literals, read;
       ; three .data through love_rela, running out to bss in memsz alone, read+write; a
       ; fourth carries the image, rw (a heap snapshot is read and rebased, never entered).
       ; no loaded byte belongs to neither and no page to two, each segment beginning on a
       ; page at or past where the last ended -- and the file pays no padding for it, the
       ; offsets running on while the addresses skip. this holds only because no relocation
       ; site lands in text or rodata: a lane that ever needs to write code has to say so
       ; with its own segment. bake_tail asks that .image end its segment and that no load
       ; live above it, both by construction here.
       phs ((? wx? [(elf64-phdr 1 5 0 base base (t1 - base) (t1 - base) pg)
                    (elf64-phdr 1 4 (t1 - base) o0 o0 (o1 - o0) (o1 - o0) pg)
                    (elf64-phdr 1 6 (d0 - base - sk) d0 d0 (dend - d0) (bend - d0) pg)]
                 [(elf64-phdr 1 7 0 base base (dend - base) (bend - base) pg)])
            + (? img? [(elf64-phdr 1 6 isho ist ist iszr iszr pg)] ())
            + (? nb? [(elf64-phdr 4 4 nbo (base + nbo) (base + nbo) 24 24 4)] ()))
       hdr (elf64-hdrn (? pie 3 2) ent mach [shto nsh 10] phs)
       ; the brand: ei_osabi = 9 in e_ident[7] on every exe this lane writes for an ISA that
       ; can meet freebsd -- linux never reads the byte and freebsd's imgact refuses without
       ; it. made here and not at a caller, so the two doors over one linker agree.
       hdr9 (elem mach '(62 183) ? (ld-brand hdr 7 9) hdr)
       (hdr9 . ((? nb? [nbnote] ()) + >en + tail + [rtab] + >ei
                 + [(ld-zeros (symo - endf)) <st <>st <shstr cmt rdm
                    (ld-zeros (shto - (rdmo + rdmz))) sht])))

   ; --- the kernel lane: one ELF, three doors ---------------------------------
   ; every PT_LOAD carries p_paddr = p_vaddr - bias, so an image can be laid where it runs
   ; and loaded where it lands: `qemu -kernel` copies by p_paddr with the MMU off and our
   ; bootx64.efi takes those same pages with it on (inle passes bias 0, free/klink.l).
   ; the lanes, each page-aligned and each its own segment: `boot` (the stub's page tables
   ; and bring-up ladder), text, rodata, data -- nifs and image ride the data run, .bss
   ; follows past p_filesz. .note.pvh is laid at vbase and rides no PT_LOAD: qemu reads it
   ; out of the file through pt_note to find xen_elfnote_phys32_entry. `ent` names the entry
   ; symbol rather than taking the first object's text, and `kimage_end` is synthesized just
   ; past .bss -- pvh.c and dtb.c read it to hand the heap the rest of RAM.
   (ldkern target ent vbase bias srcs)
    (: mach (peep elf-machines target 0)
       _ (0 >= mach ? (scare 'link-target target))
       objs (map (p \ ld-read <p <>p mach) srcs)
       (lsz lane) (foldl (\ a ob (a + ld-lanesz ob lane)) 0 objs)
       ne (ldlay1 'note vbase objs)                 ; the note first, at vbase
       b0 (ld-align 4096 ne)  b1 (ldlay1 'boot b0 objs)
       t0 (ld-align 4096 b1)  t1 (ldlayn 'text (ldlay1 'text t0 objs) objs)
       o0 (ld-align 4096 t1)  o1 (ldlayn 'rodata (ldlay1 'rodata o0 objs) objs)
       d0 (ld-align 4096 o1)  d1 (ldlayn 'data (ldlay1 'data d0 objs) objs)
       n0 (ld-align 16 d1)    n1 (ldlay1 'nifs n0 objs)
       i1 (ldlay1 'image n1 objs)
       kend (ldlayn 'bss (ldlay1 'bss i1 objs) objs)  ; .bss owns address space, no file bytes
       ; p_offset mirrors the address space one page in (the first page holds the header,
       ; the phdrs and the note), so every p_offset stays congruent to its p_vaddr mod page.
       (fo a) (a - vbase + 4096)
       (gap a b) (a < b ? [(ld-zeros (b - a))])
       nsz (lsz 'note)
       segs (filter (g \ 0 < g 6)
              [[1 7 (fo b0) b0 (b0 - bias) (b1 - b0) (b1 - b0) 4096]
               [1 5 (fo t0) t0 (t0 - bias) (t1 - t0) (t1 - t0) 4096]
               [1 4 (fo o0) o0 (o0 - bias) (o1 - o0) (o1 - o0) 4096]
               [1 6 (fo d0) d0 (d0 - bias) (i1 - d0) (kend - d0) 4096]])
       hdrsz (64 + 56 * (#segs + (0 < nsz)))
       phs (0 < nsz ? ([4 4 hdrsz vbase vbase nsz nsz 4] . segs) segs)
       _ (hdrsz + nsz > 4096 ? (scare 'link-kern-headers hdrsz))
       glo (ldsyms objs)
       _ (pin glo "kimage_end" [kend 0])
       e (glo ent)
       _ (atom? e ? (scare 'link-entry ent))
       ; no -pie table here and no arm32 kernel; riscv keeps its own reloc numbers,
       ; so the machine says which namespace ldpatch reads (ldlink's own slot 6).
       cx [glo n0 n1 n1 n1 () (mach = 243) () () (ld-extents objs)]
       en (ldemit cx 'note vbase objs ())
       eb (ldemit cx 'boot b0 objs (gap vbase b0))  ; the file resumes at vbase (offset 4096)
       et (ldemitn cx 'text objs (ldemit cx 'text t0 objs (>eb + gap <eb t0)))
       eo (ldemitn cx 'rodata objs (ldemit cx 'rodata o0 objs (>et + gap <et o0)))
       ed (ldemitn cx 'data objs (ldemit cx 'data d0 objs (>eo + gap <eo d0)))
       ef (ldemit cx 'nifs n0 objs (>ed + gap <ed n0))
       eg (ldemit cx 'image n1 objs (>ef + gap <ef n1))
       fsz (fo i1)                                  ; the loaded bytes end here
       ; the section headers and symbol table ride past p_filesz, mapped by nothing
       lanesx {'note 1 'boot 2 'text 3
               'rodata 4 'data 5 'nifs 5 'image 5 'bss 6}
       st (ldstab objs glo lanesx ld-sym 24)
       shstr (o-strtab '(".note.pvh" ".boot" ".text" ".rodata"
                         ".data" ".bss" ".symtab" ".strtab" ".shstrtab"))
       (snm k) (<>shstr k)
       symo (ld-align 8 fsz) symz (tally <st)
       stro (symo + symz) strz (tally <>st)
       ssto (stro + strz) sstz (tally <shstr)
       shto (ld-align 8 (ssto + sstz))
       sht (catall [(ld-shdr 0 0 0 0 0 0 0 0 0 0)                                 ; the reserved null header
                    (ld-shdr (snm 0) 7 2 vbase hdrsz nsz 0 0 4 0)                 ; .note.pvh, in the header page
                    (ld-shdr (snm 1) 1 7 b0 (fo b0) (b1 - b0) 0 0 4096 0)
                    (ld-shdr (snm 2) 1 6 t0 (fo t0) (t1 - t0) 0 0 4096 0)
                    (ld-shdr (snm 3) 1 2 o0 (fo o0) (o1 - o0) 0 0 4096 0)
                    (ld-shdr (snm 4) 1 3 d0 (fo d0) (i1 - d0) 0 0 4096 0)         ; .data, the nifs and image runs with it
                    (ld-shdr (snm 5) 8 3 i1 (fo i1) (kend - i1) 0 0 16 0)         ; NOBITS: an offset, no bytes
                    (ld-shdr (snm 6) 2 0 0 symo symz 8 (st 2) 8 24)            ; link=.strtab info=first global
                    (ld-shdr (snm 7) 3 0 0 stro strz 0 0 1 0)
                    (ld-shdr (snm 8) 3 0 0 ssto sstz 0 0 1 0)])
       hdr (elf64-hdrn 2 <e mach [shto 10 9] (map (foldl id elf64-phdr) phs))
       (hdr . (>en + [(ld-zeros (4096 - (hdrsz + nsz)))] + >eg
                + [(ld-zeros (symo - fsz)) <st <>st <shstr
                   (ld-zeros (shto - (ssto + sstz))) sht])))

   ; --- the bare-metal 32-bit door ---------------------------------------------
   ; one ELF32 executable for a part with no MMU, laid where it runs -- `qemu -kernel` and
   ; a boot ROM alike copy each segment down by p_paddr. the ELF header is outside every
   ; segment: the first run's address is where the core looks (an M7 reads its initial SP
   ; and PC out of the vector table before an instruction runs), so the first laid byte has
   ; to be the first mapped byte and the header rides file offset 0 with nothing over it --
   ; which is why nothing here reserves address space for it the way ldlink does.
   ;
   ; `runs` is the map, as data -- what a linker script says, in one list:
   ;   (at   VADDR lane..)   laid and loaded there, a gap from the run before padded in the
   ;                         file, so a header a boot rom reads at a fixed offset is a run.
   ;   (copy VADDR lane..)   laid at vaddr, loaded after the file bytes so far -- `> RAM
   ;                         AT> FLASH`, and the port's startup copies it across at boot.
   ; a lane slot may instead hold `(flags N)`: the segment permissions the board asserts in
   ; place of the ones ld-segflags reads off the sections, which has to exist because no
   ; object can answer for it (a vector table is const to the silicon and still carries the
   ; addresses that make it writable to a compiler). the fused `at` segment takes one.
   ; consecutive `at` runs share one segment; each `copy` run takes its own, p_paddr where
   ; its bytes sit. once a run is `copy` every later one must be -- the file cursor and the
   ; address cursor have parted. `bss` owns no file bytes, so it may only end the last run.
   ; and every lane the objects carry must appear somewhere in the map, or it is dropped in
   ; silence. the five noms a copied map needs are synthesized here (__data_start__ and
   ; friends): the startup cannot compute them. no -pie, a board image sliding nowhere.
   ld-lanenames (ld-cls '((text ".text") (rodata ".rodata") (data ".data")
                          (nifs ".love.nifs") (bss ".bss") (image ".love.image")))
   (ld-lanenm l) (: r (peep ld-lanenames l ()) (two? r ? <r (string l)))
   ; a lane's first section in lay order: what ldlay1 reaches first, so its flags name the
   ; lane's home and its alignment is the lane's own. () where no object fills the lane.
   (ld-lane0 objs l)
    (: (go os) (? !(two? os) ()
                  (: is (peep (peep <os 'lanes 0) l ())
                     (two? is ? (peep (peep <os 'secs 0) <is ()) (go >os))))
       (go objs))
   ; a lane's home across the set (ld-home); a lane the linker knows by name is its own.
   (ld-homeof objs l)
    (? (elem l ld-lanes) l
       (: s (ld-lane0 objs l) (two? s ? (s 4) 'rodata)))
   (ld-secflags h) (? (h == 'text) 6 (elem h '(data bss nifs image)) 3 2)
   (ld-segflags objs ls)                                    ; pf_r plus what the lanes ask
    (foldl (\ a l (: h (ld-homeof objs l)
                    (a | (? ( h == 'text) 1 (elem h '(data bss nifs image)) 2 0))))
           4 ls)
   ; a run row's two halves: the lanes it lays, and the `(flags N)` word a board may put
   ; among them -- a lane is an atom and the word a pair, so neither reads as the other.
   (ld-fword? ('flags . _)) 1
   (ld-runlanes r) (filter (nil? * ld-fword?) >>r)
   (ld-runflags r) (: f (filter ld-fword? >>r)
                      (two? f ? (: v <><f
                                   _ (charm? v && 0 < v <= 7 ? 0 (scare 'link-run-flags v))
                                   v)))
   ; the fused `at` segment takes one assertion across every run that makes it, and
   ; two that disagree are a map with two minds -- named here, not silently joined.
   (ld-onef vs)
    (foldl (\ a v (? !v a !a v (a = v) a (scare 'link-run-flags v))) () vs)
   ; every lane the set actually puts bytes or address space in, first-seen order
   (ld-uselanes objs)
    (: seen (tablet 0)
       (go os acc)
        (? !(two? os) (rev acc)
           (go >os (foldl (\ a l (? (0 < peep seen l 0) a
                                    !(0 < ld-lanesz <os l) a
                                    (pin seen l 1, l . a)))
                          acc (ld-lanes + <os 'named))))
       (go objs ()))

   (ldbare32 target runs srcs pns rel?)
    (: mach (peep elf-machines target 0)
       _ (0 >= mach  ? (scare 'link-target target))
       _ (atom? runs ? (scare 'link-no-map target))
       ; the re-encoder is the arm32 family's (see ldarm), not this target's
       be (backends (arm32? target ? 'thumb2 target))
       objs (map (p \ ld-read <p <>p mach) srcs)
       ; a compiler-named lane travels with the known lane its flags name (ld-home), so a
       ; board's map never has to have heard of it: expand each run's list in place, every
       ; known lane followed by the named ones that ride with it. everything downstream
       ; reads the expanded runs, so the three walks cannot disagree.
       ;; ..except where the map already spoke for one: a table the silicon reads at a fixed
       ;; address has only its flags to travel by, and those say rodata, which would lay it
       ;; after the code. a named lane is the board's word, and the expansion supplies the
       ;; company it did not mention.
       (lrf a r) (a + ld-runlanes r)
       spoken (foldl lrf () runs)
       (unspoken n) !(elem n spoken)
       lruns (map (r \ <r . <>r . filter ld-fword? >>r
                                + foldl (a \ l \ a + cons l (filter unspoken (ld-nlanes objs l)))
                                  () (ld-runlanes r))
                  runs)
       maplanes (foldl lrf () lruns)
       ;; a lane lives in one place: laid twice it is emitted twice while lpos keeps one
       ;; entry, so the bytes and the section headers part company and the file is corrupt.
       _ (foldl (\ seen l (elem l seen ? (scare 'link-lane-twice l) (l . seen)))
                () maplanes)
       _ (foldl (\ _ l (elem l maplanes ? 0 (scare 'link-unmapped-lane l)))
                0 (ld-uselanes objs))
       org (<lruns 1)
       foff (4096 + (org % 4096))               ; ..the header's page, and the congruence
       ; -- the layout pass, run by run and lane by lane in the map's order. lpos records
       ; each lane's (vaddr fileoff size) as it goes, so the section headers read it back
       ; rather than laying twice. -> one run: (kind vaddr fileoff filesz memsz lanes flags)
       lpos (tablet 0)
       plan (: (go rs cur fpos copied acc)
                (? !(two? rs) (rev acc)
                   (: r <rs kind <r start (r 1) ls (ld-runlanes r) fl (ld-runflags r)
                      copy? (kind == 'copy)
                      _ (!copy? && kind !== 'at ? (scare 'link-run-kind kind))
                      _ (copied && !copy? ? (scare 'link-run-after-copy start))
                      _ (elem 'bss ls && (two? >rs || last ls !== 'bss) ?
                         (scare 'link-run-bss start))
                      _ (!copy? && cur > start ? (scare 'link-run-back start))
                      fo (copy? ? fpos (fpos + start - cur))
                      w (foldl (\ a l (: c <a f <>a
                                         n (ldlay1 l c objs)
                                         _ (pin lpos l [c f (n - c)])
                                         [n (? (= l 'bss) f (f + n - c))]))
                               [start fo] ls)
                      (go >rs (? copy? cur <w) <>w (copied || copy?)
                          ([kind start fo (<>w - fo) (<w - start) ls fl] . acc))))
               (go lruns org foff () ()))
       ; -- the segments: the `at` runs fuse into one, each `copy` run stands alone with
       ; p_paddr where its bytes sit. a row is (vaddr paddr fileoff filesz memsz flags).
       (fladdr f) (org + f - foff)            ; a file offset -> the address it loads at
       ats (filter (r \ <r == 'at) plan)
       cps (filter (r \ <r == 'copy) plan)
       aseg (? (two? ats)
               (: a0 <ats aN (last ats)
                  [[(a0 1) (a0 1) (a0 2)
                    (aN 2 + aN 3 - a0 2)
                    (aN 1 + aN 4 - a0 1)
                    (: af (ld-onef (map (r \ r 6) ats))
                       (? af af (ld-segflags objs (foldl (a \ r \ a + r 5) () ats))))]]))
       segs (aseg + map (\ r [(r 1) (fladdr (r 2)) (r 2) (r 3) (r 4)
                              (r 6 || ld-segflags objs (r 5))]) cps)
       hdrsz (52 + 32 * #segs)
       _ (hdrsz > foff ? (scare 'link-bare-headers hdrsz))
       glo (ldsyms objs)
       ; -- the board's own absolutes, (name value) from the driver: whatever the memory map
       ; states and no object can know. laid before the brackets below, which a board may
       ; not quietly replace.
       _ (foldl (\ _ p (pin glo <p [<>p 0], 0)) 0 pns)
       ; -- the copied region's brackets: the load address is the linker's alone to know.
       _ (<cps @ (_ . dv . da . df . dm . _)
          (pins glo "__data_start__" [dv 0]
                    "__data_end__"   [(dv + df) 0]
                    "__data_load__"  [(fladdr da) 0]
                    "__bss_start__"  [(dv + df) 0]
                    "__bss_end__"    [(dv + dm) 0]))
       ; -- how many bytes the file lays from org, for a boot rom's length field (the i.MX
       ; IVT's boot data). the last run's file end, runs laying in map order; .bss is not in
       ; it, a rom copying what exists.
       _ (: pN (last plan)
          (pin glo "__load_size__" [(pN 2 + pN 3 - foff) 0]))
       ; the entry symbol is a courtesy -- for objdump, gdb and a reader asking what
       ; runs first. the core never consults e_entry; it takes the vector table.
       ent (: e (glo "_start") (two? e ? <e org))
       ; the nif bracket. lpos keeps a lane's cursor and ldlay1 aligns the first section as
       ; its own header asks, so the pad rides inside the lane and a start read off the
       ; cursor points into it. the end is honest, nothing following the last section.
       nif (: r (lpos 'nifs) (two? r ? r [org org 0]))
       n0 (ld-align (: s (ld-lane0 objs 'nifs) (two? s ? (s 3) 1)) <nif)
       relbox (rel? ? {0 ()} ())    ; the emit-relocs site accumulator
       cx [glo n0 (<nif + nif 2) org org relbox () 1 be (ld-extents objs)]
       ; -- the bytes, run by run, lane by lane, in that same order --
       body (: (go rs fp acc)
                (? !(two? rs) [fp acc]
                   (: r <rs
                      pad (fp < r 2 ? [(ld-zeros (r 2 - fp))])
                      e (foldl (a \ l \ ldemit cx l <a objs >a)
                               [(r 1)] (filter (!== 'bss) (r 5)))
                      (go >rs (r 2 + r 3) (acc + pad + >e))))
               (go plan foff ()))
       fend <body  pieces <>body
       ; -- the section headers and symbol table, past every loaded byte: one header per
       ; mapped lane, so `nm` sees the lane a symbol lives in, not the one it travels with.
       shl0 (filter (l \ elem l (ld-uselanes objs)) maplanes)
       ; -- one section header per lane, except where the image carries its own relocations.
       ; a loader walking .rel sections walks a roster of section names (pdc's is .text
       ; .data .got .got.plt .bss), so a lane named otherwise has its relocations dropped in
       ; silence. such a lane folds into the header before it when it is contiguous and
       ; carries the same flags -- it is that region. -> ((lane addr off flags size) ..)
       secs (: (go ls acc)
                (? !(two? ls) (rev acc)
                   (: l <ls q (peep lpos l '(0 0 0))
                      p (two? acc ? <acc ())
                      fl (ld-secflags (ld-homeof objs l))
                      (? (rel? && !(elem l '(text rodata data bss)) && two? p
                          && (p 3) = fl && (p 1) + (p 4) = <q)
                          (go >ls ([<p (p 1) (p 2) fl ((p 4) + q 2)] . >acc))
                          (go >ls ([l <q <>q fl (q 2)] . acc)))))
               (go shl0 ()))
       shl (map (e \ <e) secs)
       lanesx (: t {} (foldl (\ i l (pin t l i, i + 1)) 1 shl, t))
       st (ldstab objs glo lanesx ld-sym32 16)
       ; -- the recorded abs32 sites, grouped by the lane whose extent holds each. every
       ; entry is an Elf32_Rel naming symbol 0, whose st_value is 0 by ELF's rule, so a
       ; loader recomputing S + A lands where one adding its load delta does. no shf_alloc:
       ; the sections are for whoever reads the file, and cost the image nothing.
       rsites (sort (rel? ? (relbox 0) ()))
       (rlane v) (: (go es) (? !(two? es) ()
                               (: e <es
                                  ((e 1) <= v < (e 1) + (e 4) ? <e (go >es))))
                    (go secs))
       rgrp (foldl (\ t v (: l (rlane v) (? l (pin t l (peep t l () + [v])) t))) {} rsites)
       rlanes (filter (l \ two? (peep rgrp l ())) shl)
       nr (tally rlanes)
       shstr (o-strtab (map ld-lanenm shl + '(".symtab" ".strtab" ".shstrtab")
                        + map (l \ ".rel" + ld-lanenm l) rlanes))
       (snm k) (<>shstr k)
       nl (tally shl)
       symo (ld-align 4 fend) symz (tally <st)
       stro (symo + symz) strz #<>st
       ssto (stro + strz) sstz #<shstr
       relo (ld-align 4 (ssto + sstz))
       relbs (map (l \ catall (map (v \ catall [(le32 v) (le32 2)]) (peep rgrp l ()))) rlanes)
       reloffs (: (go bs cur acc) (? !(two? bs) acc (go >bs (cur + #<bs) (acc + [cur])))
                  (go relbs relo ()))
       relsz (foldl (\ a b (a + #b)) 0 relbs)
       shto (ld-align 4 (relo + relsz))
       sht (catall ([(ld-shdr32 0 0 0 0 0 0 0 0 0 0)]                        ; the reserved null header
                    + o-mapi (\ i e (ld-shdr32 (snm i) (<e == 'bss ? 8 1) (e 3)
                                                (e 1) (e 2) (e 4) 0 0 4 0))
                             secs
                    + [(ld-shdr32 (snm nl) 2 0 0 symo symz (nl + 2) (st 2) 4 16)    ; link=.strtab
                       (ld-shdr32 (snm (nl + 1)) 3 0 0 stro strz 0 0 1 0)
                       (ld-shdr32 (snm (nl + 2)) 3 0 0 ssto sstz 0 0 1 0)]
                    + o-mapi (\ i l (ld-shdr32 (snm (nl + 3 + i)) 9 64 0           ; sht_rel, shf_info_link
                                                (reloffs i) #(relbs i)
                                                (nl + 1) (peep lanesx l 0) 4 8))
                             rlanes))
       hdr (elf32-hdrn 2 ent mach (arm-eflags target) [shto (nl + 4 + nr) (nl + 3)]
                       (map (g \ elf32-phdr 1 (g 5) (g 2) <g (g 1) (g 3) (g 4) 4096) segs))
       (hdr . ([(ld-zeros (foff - hdrsz))] + pieces
               + [(ld-zeros (symo - fend)) <st <>st <shstr
                  (ld-zeros (relo - (ssto + sstz)))]
               + relbs
               + [(ld-zeros (shto - (relo + relsz))) sht])))

   ; one byte of a piece, whichever shape the piece arrived in (the header comes back
   ; as a text from one hdr builder and as a byte list from another)
   (ld-brand p i v)
    (? (string? p) (snip p 0 i + string v + snip p (i + 1) #p)
       (: (go k l) (? (k = i) (v . >l) (<l . (go (k + 1) >l))) (go 0 p)))

   ; write a piece list to a file, raw: texts pass through, byte lists pack into a cask.
   ; an explicit left walk -- map runs its effects right-to-left.
   ; the path is unlinked first, never truncated: a running binary refuses to open for
   ; writing (ETXTBSY) and `say` to a () port is quiet, so relinking a live love would lay
   ; the new bytes nowhere. unlinked, the live process keeps the old inode and the new
   ; bytes land on a fresh one.
   ; -> bytes written | a negative errno, as copyfile answers. test it with nom?, never
   ; for truth: a zero-byte write is falsy too.
   (ld-write path ps)
    (: _ (unlink path)
       q (open path "w")
       (go l n) (? !(two? l) (: _ (close q) n)
                   (: p <l
                      _ (say q (string? p ? p (cask p)))
                      (go >l (n + #p))))
       (? (hot? q) (go ps 0) q)))
) ; module 'holo
