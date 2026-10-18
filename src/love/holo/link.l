; src/love/holo/link.l -- a static ELF linker over relocatable objects of either class:
; resolve every symbol across the set (strong over weak, the nif brackets synthesized over
; the packed region), lay the sections, apply the relocations, and write the executable.
; entry is the first object's text (a crt0). a foreign .o (gcc's) links too: sections a
; static image cannot use are dropped by a stated rule (see `class`), any other with bytes
; scares. x86-64 relocs replace their field; a64, rv64 and arm ones or bits into the word
; the placeholder carries.
; `ldkern` lays the same objects for bare metal: page-aligned pt_loads with p_paddr =
; p_vaddr - bias, for a loader that copies physical or one that maps virtual. `ldbare32`
; lays an ELF32 image for a part with no MMU from a map of runs.
; loads after src/love/holo/obj.l.
(module 'holo
(borrow 'posix)
(borrow 'bytes)

(:
   ; little-endian reads; a signed u64 field (a RELA addend) goes through s64
   (rle16 s i) (rdle s i 2)
   (rle32 s i) (rdle s i 4)
   (rle64 s i) (rdle s i 8)
   ; a field of any width: the table below asks for 1, 2, 3, 4 and 8
   (rlew s i n) (n < 1 ? 0 (s i + 256 * rlew s (i + 1) (n - 1)))

   ; --- the field table: where each class keeps what the readers read. ---
   ; not one shape at two widths: Elf32_Sym reorders, a REL r_info splits at a byte (type
   ; low) where RELA's splits at a word, and REL has no `rl-add`, its addend in the field.
   ; a row is (offset width), a lone scalar a one-element row; presence is `two?`.
   (ld-cls c) (foldl (t \ (a . u) \ pin t a u) {} c)
   (ld-row fs nm) (peep fs nm ())
   (ld-n fs nm) (ld-row fs nm @ r (two? r ? <r (scare 'link-field nm)))
   (ld-f fs s b nm)
    (ld-row fs nm @ r (two? r ? (rlew s (b + <r) <>r) (scare 'link-field nm)))
   ; hold a table stride to sh_entsize: a wrong one reads well-formed garbage
   (ld-esz fs s h want sec)
    (ld-f fs s h 'sh-esz != ld-n fs want ? (scare 'link-entsize sec))
   ; the ph- rows are copy.l's, which reads linked files
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
   (ld-align a v) (a < 2 ? v (v % a @ r (r = 0 ? v (v + a - r))))
   ; a segment's address for file offset f: the next page at or after v plus f's place in a
   ; page, the least fresh-page address with p_vaddr = p_offset (mod a). a < 2 packs tight.
   (ld-lift a v f) (a < 2 ? v (ld-align a v + f % a))
   ; relocation arithmetic is modular; % truncates, so a negative sum is folded up
   (ld-u64 v) (v % 18446744073709551616 @ r
                 (r < 0 ? (r + 18446744073709551616) r))
   (ld-u32 v) (v % 4294967296 @ r (r < 0 ? (r + 4294967296) r))

   ; --- the ARM field lane. EM_ARM is REL: each kind pulls its addend out of the field. the
   ; thumb bit rides in S (st_value's bit 0), and every branch field drops bit 0, so
   ; ((S+A)|T) falls out of S+A. the encodings are the widest arm32 backend's, through
   ; refix-with, since one image may mix cores (a v6-M link takes a v7-M start.o).
   ; abs32 is ((S+A)|T), rel32 that minus P (`.word handler - .`), written here.
   ; the numbers collide with x86-64's and riscv's, so the machine picks the lane first.
   ldarm-kinds (ld-cls '((2 abs32) (3 rel32) (10 bl) (30 b) (47 movw16) (48 movt16) (51 bcc)))
   ; the a64 and riscv instruction fields by relocation number, in the backend's names.
   ; RELA: S+A arrives whole, and the backend ors its field into the word already there
   lda64-kinds (ld-cls '((273 ld19) (274 adr21) (275 adrp21) (277 addlo12) (278 addlo12) (279 b14) (280 b19) (282 b26) (283 b26)
                         (284 lo12s2) (285 lo12s4) (286 lo12s8) (299 lo12s16)))
   ldrv-kinds (ld-cls '((17 j21) (19 pcrel)))
   ; EM_386 is REL too, every field whole: _32, _PC32, _PLT32 four bytes, _16 and _PC16 two,
   ; _8 and _PC8 one.
   ld386-kinds (ld-cls '((1 abs32) (2 rel32) (4 rel32) (20 abs16) (21 rel16) (22 abs8) (23 pc8)))
   (ld386 s off sv kind site)
    (: r (ld386-kinds kind)
       _ (atom? r ? (scare 'link-reloc kind))
       k <r w (k @ 'abs16 2 'rel16 2 'abs8 1 'pc8 1 4)
       sa (sv + rdle s off w)
       v (elem k '(abs32 abs16 abs8) ? sa (sa - site))
       (w @ 4 (le32 (ld-u32 v)) 2 (le16 (ld-u32 v)) [(ld-u32 v & 255)]))
   (ldarm be s off sv kind site)
    (: r (ldarm-kinds kind)
       _ (atom? r ? (scare 'link-reloc kind))
       k <r  sa (sv + rle32 s off)
       (? (k == 'abs32) (le32 (ld-u32 sa))
          (k == 'rel32) (le32 (ld-u32 (sa - site)))
          (refix-with be k (map (i \ s (off + i)) ^4) sv site 4)))

   ; --- archives: "!<arch>\n", GNU shape. only the "/" ranlib index is walked, so an
   ; archive without one refuses (`ranlib` repairs it). a header is 60 bytes of left-justified
   ; space-padded ASCII; the size excludes the "\n" a member pads to even with.
   (ld-arfld s i n)
    (: t (snip s i (i + n))
       (go k) (0 < k && t (k - 1) = 32 ? (go (k - 1)) (snip t 0 k))
       (go n))
   (ld-arnum t) (foldl (\ a k (10 * a + t k - 48)) 0 ^#t)
   (ld-arsz s off) (ld-arnum (ld-arfld s (off + 48) 10))
   (ld-arnext s off) (ld-arsz s off @ z (off + 60 + z + z % 2))
   (ld-be32 s i) ((s i << 8 | s (i + 1)) << 16 | (s (i + 2) << 8 | s (i + 3)))
   (ld-ar? s) (8 <= #s && snip s 0 8 = "!<arch>\n")
   ; nom -> the member header offset that defines it; the first definer wins
   (ld-arsyms id s)
    (: _ (ld-arfld s 8 16 != "/" ? (scare 'link-ar-noindex id))
       d0 68 n (ld-be32 s d0) t {}
       (go i o) (n <= i ? t
                   (ld-cstr s o @ nom
                      (o-has? t nom ? 0 (pin t nom (ld-be32 s (d0 + 4 + 4 * i))),
                       go (i + 1) (o + 1 + #nom))))
       (go 0 (d0 + 4 + 4 * n)))
   ; the "//" table of names past 15 characters (a member named "/<offset>", entries
   ; ending at "/"), or ""
   (ld-arlong s)
    (ld-arnext s 8 @ p
       (p + 60 <= #s && ld-arfld s p 16 = "//" ?
        (snip s (p + 60) ((p + 60) + ld-arsz s p)) ""))
   (ld-armem s off lt)
    (: nm (ld-arfld s off 16) d0 (off + 60)
       real (nm 0 = 47 ?
             (: o (ld-arnum (snip nm 1 #nm))
                (go k) (k < #lt && lt k != 47 ? (go (k + 1)) k)
              (snip lt o (go o)))
             (#nm @ z (nm (z - 1) = 47 ? (snip nm 0 (z - 1)) nm)))
       [real (snip s d0 (d0 + ld-arsz s off))])

   ; the unwinder's tables, by prefix as gcc splits them per function
   (ld-unwind? nm)
    (starts? nm ".eh_frame" || starts? nm ".ARM.exidx" || starts? nm ".ARM.extab")
   ; the lanes the linker knows by name; anything else allocated is a named lane
   ld-lanes '(text rodata data nifs bss image note boot)
   ; an allocated progbits or nobits section of another name is its own lane, laid contiguous
   (ld-any nm ty fl) (elem ty '(1 8) && 0 < fl & 2 ? (name nm))
   ; and travels with the known lane its flags name: exec text, write data, nobits bss,
   ; else rodata
   (ld-home lane fl ty)
    (? (elem lane ld-lanes) lane
     (ty = 8) 'bss (0 < fl & 4) 'text (0 < fl & 1) 'data 'rodata)
   ; a section name -> its lane, by prefix (gcc splits a lane: .text.unlikely, .rodata.str1.1)
   (ld-lane nm ty fl)
    (? (ty = 8) (nm = ".bss" || starts? nm ".bss." ? 'bss (ld-any nm ty fl))
       (nm = ".text" || starts? nm ".text.") 'text
       (nm = ".rodata" || starts? nm ".rodata.") 'rodata
       (nm = ".data" || starts? nm ".data.") 'data
       (nm = "love_nifs") 'nifs
       (nm = ".love.image") 'image
       ; ldkern's: the boot stub, and the PVH note qemu reads for the 32-bit entry
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
   ; layout pins 'base later, section index -> load address
   (ld-read id s mach)
    (: _ (s 0 = 127 && s 1 = 69 && s 2 = 76 && s 3 = 70 ? 0 (scare 'link-not-elf id))
       ; e_type and e_machine sit at 16 and 18 in both classes
       fs (? (s 4 = 2) elf64f (s 4 = 1) elf32f (scare 'link-elf-class id))
       _ (rle16 s 16 = 1 && rle16 s 18 = mach ? 0 (scare 'link-machine id))
       _ (ld-f fs s 0 'e-shent = ld-n fs 'sh-ent ? 0 (scare 'link-shentsize id))
       shoff (ld-f fs s 0 'e-shoff)
       shnum (ld-f fs s 0 'e-shnum) shstrx (ld-f fs s 0 'e-shstrx)
       (sh i) (shoff + i * ld-n fs 'sh-ent)
       shstro (ld-f fs s (sh shstrx) 'sh-off)
       (sname i) (ld-cstr s (shstro + ld-f fs s (sh i) 'sh-name))
       secs {} lanes {} drops {}
       ob {'id id 'src s 'lanes lanes 'secs secs 'drops drops 'base {}}
       ; droppable: empty, no shf_alloc, a note, or the unwinder's tables. the index is
       ; recorded so a relocation against it is skipped, not scared at.
       (drop? i ty fl nm sz)
        (sz = 0 || 0 = fl & 2 || ty = 7 || ld-unwind? nm ?
           (pin drops i 1, 1) ())
       ; classify: progbits and nobits onto their lane, symtab/rela by type, the droppable
       ; set dropped; anything else with bytes refuses, shf_tls among them (no pt_tls here).
       (class i symt rls)
        (shnum <= i ? (symt . rls)
           (: h (sh i) ty (ld-f fs s h 'sh-type) fl (ld-f fs s h 'sh-flags)
              off (ld-f fs s h 'sh-off) sz (ld-f fs s h 'sh-size) nm (sname i)
              (0 < fl & 1024 && 0 < sz ? (scare 'link-tls nm),
              ; a note with a lane (.note.pvh) is placed like progbits
               (? (elem ty '(1 8) || ty = 7 && ld-lane nm ty fl)
                   ; a nobits section's sh_offset is a placeholder
                   (ld-lane nm ty fl @ lane
                      (? lane (pin secs i [lane (ty = 8 ? 0 off) sz
                                           (ld-f fs s h 'sh-align) (ld-home lane fl ty)],
                               pin lanes lane (i . lanes lane),
                               class (i + 1) symt rls)
                         ; .comment is dropped but kept: the output's is the union of the inputs'
                         (drop? i ty fl nm sz)
                          (nm = ".comment" ? (pin ob 'comment (snip s off (off + sz))) 0,
                           class (i + 1) symt rls)
                         (scare 'link-section nm)))
                  (ty = 2) (ld-esz fs s h 'sy-ent nm,
                            class (i + 1) [off sz (ld-f fs s h 'sh-link)] rls)
                  (ty = ld-n fs 'rl-ty)
                   (ld-esz fs s h 'rl-ent nm,
                    class (i + 1) symt ([(ld-f fs s h 'sh-info) off sz] . rls))
                  (elem ty '(0 3)) (class (i + 1) symt rls)
                  (drop? i ty fl nm sz) (class (i + 1) symt rls)
                  (scare 'link-section nm)))))
       cl (class 1 () ())
       ; the named lanes this object carries, first-seen in header order
       nmd (: (go i acc)
               (shnum <= i ? (rev acc)
                  (secs i @ se
                     (go (i + 1) (? (atom? se) acc
                                    (elem <se ld-lanes) acc
                                    (elem <se acc) acc
                                    (<se . acc)))))
              (go 1 ()))
       _ (pin ob 'named nmd)
       _ (foldl (\ _ l (pin lanes l (rev (lanes l)))) 0 (ld-lanes + nmd))
       symt <cl
       _ (atom? symt ? (scare 'link-no-symtab id))
       stro (ld-f fs s (sh (symt 2)) 'sh-off)    ; .strtab offset, via symtab's link
       syms {} _ (pin ob 'syms syms)
       nsym (symt 1 // ld-n fs 'sy-ent)
       _ (pin ob 'nsym nsym)
       _ (each ^nsym (i \ (: e (symt 0 + i * ld-n fs 'sy-ent)
                              info (ld-f fs s e 'sy-info)
                              (pin syms i [(ld-cstr s (stro + ld-f fs s e 'sy-name))
                                            (info >> 4) (info & 15)
                                            (ld-f fs s e 'sy-shndx) (ld-f fs s e 'sy-val)
                                            (ld-f fs s e 'sy-size)]))))
       ; a .rela whose target was dropped goes with it; one neither placed nor dropped scares.
       ; a REL addend arrives () and the patcher pulls it from the field.
       ad (ld-row fs 'rl-add)
       rent (ld-n fs 'rl-ent)
       relas (map (r \ (: n (r 2 // rent)
                          (es i acc) (i < 0 ? acc
                                        (r 1 + i * rent @ e
                                           (es (i - 1)
                                               ([(ld-f fs s e 'rl-off) (ld-f fs s e 'rl-kind)
                                                 (ld-f fs s e 'rl-sym)
                                                 (two? ad ? (s64 (ld-f fs s e 'rl-add)))] . acc))))
                          (<r . es (n - 1) ())))
                  (filter (r \ (? (two? (secs <r)) 1
                                  (drops <r) ()
                                  (scare 'link-rela-target id)))
                          >cl))
       (pin ob 'relas relas,
        ob))

   ; every symbol in .symtab of a file of any e_type (`kore nm`) -> rows
   ;   (name bind typ shndx value size sec)
   ; sec the defining section's (name type flags), or () for an undefined or reserved index.
   ; a file without .symtab answers ().
   (ld-syms id s)
    (: _ (s 0 = 127 && s 1 = 69 && s 2 = 76 && s 3 = 70 ? 0 (scare 'link-not-elf id))
       fs (? (s 4 = 2) elf64f (s 4 = 1) elf32f (scare 'link-elf-class id))
       shoff (ld-f fs s 0 'e-shoff) shnum (ld-f fs s 0 'e-shnum)
       (sh i) (shoff + i * ld-n fs 'sh-ent)
       shstro (ld-f fs s (sh (ld-f fs s 0 'e-shstrx)) 'sh-off)
       (sname i) (ld-cstr s (shstro + ld-f fs s (sh i) 'sh-name))
       (find i) (? (shnum <= i) () (ld-f fs s (sh i) 'sh-type = 2) [i] (find (i + 1)))
       t (find 1)
       (atom? t ? ()
          (: h (sh <t)
             _ (ld-esz fs s h 'sy-ent ".symtab")
             ent (ld-n fs 'sy-ent)
             off (ld-f fs s h 'sh-off) n (ld-f fs s h 'sh-size // ent)
             stro (ld-f fs s (sh (ld-f fs s h 'sh-link)) 'sh-off)
             ; index 0 is the null symbol
             (go i acc)
              (i < 1 ? acc
                 (: e (off + i * ent)
                    info (ld-f fs s e 'sy-info) x (ld-f fs s e 'sy-shndx)
                    (go (i - 1)
                        ([(ld-cstr s (stro + ld-f fs s e 'sy-name))
                          (info >> 4) (info & 15) x
                          (ld-f fs s e 'sy-val) (ld-f fs s e 'sy-size)
                          (0 < x && x < shnum ?
                             [(sname x) (ld-f fs s (sh x) 'sh-type)
                              (ld-f fs s (sh x) 'sh-flags)])]
                         . acc))))
             (go (n - 1) ()))))

   ; -- archives. the noms the linker synthesizes, never looked for in a .a
   ldsynth '("__start_love_nifs" "__stop_love_nifs" "__start_love_rela" "__stop_love_rela"
             "__data_start__" "__data_end__" "__data_load__"
             "__bss_start__" "__bss_end__" "__load_size__")
   (dusyms id bs mach)                     ; (id bytes) -> (defs strong-undefs), global noms
    (: ob (ld-read id bs mach) sy9 (peep ob 'syms 0)
       (go i ds us)
        (peep ob 'nsym 0 <= i ? [ds us]
           (: sy (sy9 i) bind (sy 1)
              (? !(elem bind '(1 2)) (go (i + 1) ds us)
                 (0 < sy 3) (go (i + 1) (<sy . ds) us)
                 (bind = 1) (go (i + 1) ds (<sy . us))
                 (go (i + 1) ds us))))    ; a weak undef resolves to 0, owing nothing
       (go 1 () ()))
   ; --- writing one: `ar rcs`, deterministic (date/uid/gid 0, mode 644) and always indexed.
   ; `ms` is ((name bytes)..), names unique: a repeated one is unreachable through the index.
   (ld-arp w s) (#s < w ? (ld-arp w (s + " ")) s)
   (ld-arb4 v) (string (v >> 24 & 255) + string (v >> 16 & 255) + string (v >> 8 & 255) + string (v & 255))
   (ld-arhdr nm date uid gid mode sz)
    (ld-arp 16 nm + ld-arp 12 date + ld-arp 6 uid + ld-arp 6 gid + ld-arp 8 mode + ld-arp 10 (show sz) + "`\n")
   (ld-arpad s) (#s & 1 ? (s + "\n") s)
   (ld-arelf? b) (20 <= #b && b 0 = 127 && b 1 = 69 && b 2 = 76 && b 3 = 70)
   ; a member's defined globals, read as a pull reads them; a non-ELF member defines nothing
   (ld-ardefs f b) (ld-arelf? b ? <(dusyms f b (b 18 + 256 * b 19)))
   (arbytes ms)
    (: names (map cap ms)
       datas (map caup ms)
       ; the long-name table: parallel to names, each entry (offset) | ()
       lofs (: (go l off acc) (atom? l ? (rev acc)
                                 (#<l @ ln
                                    (ln < 16 ? (go >l off (() . acc))
                                       (go >l (off + ln + 2) ([off] . acc)))))
               (go names 0 ()))
       ltab (: (go ns ls) (atom? ns ? ""
                             (two? <ls ? (<ns + "/\n" + go >ns >ls) (go >ns >ls)))
               (go names lofs))
       syml (map (m \ ld-ardefs <m <>m) ms)
       nsym (foldl (+) 0 (map tally syml))
       strt (foldl (+) "" (map (ss \ foldl (a \ s \ a + s + string 0) "" ss) syml))
       ; the index pads to even with a NUL counted in its size, as GNU does
       isz (4 + 4 * nsym + #strt @ z (z + (z & 1)))
       ; member header offsets: magic, index hdr + data, "//" (when any), then each
       m0 (8 + 60 + isz)
       m1 (#ltab ? (m0 + 60 + #ltab + (#ltab & 1)) m0)
       offs (: (go ds off acc) (atom? ds ? (rev acc)
                                (go >ds (off + 60 + (#<ds @ z (z + (z & 1)))) (off . acc)))
               (go datas m1 ()))
       idx (: raw ((ld-arb4 nsym
                    + (: (go os ss) (atom? os ? ""
                                       (foldl (\ a _ (a + ld-arb4 <os)) "" <ss + go >os >ss))
                         (go offs syml)))
                   + strt)
              (#raw & 1 ? (raw + string 0) raw))
       body (: (go ns ls ds) (atom? ns ? ""
                                (: nf (two? <ls ? ("/" + show <<ls) (<ns + "/"))
                                 (ld-arhdr nf "0" "0" "0" "644" #<ds + ld-arpad <ds + go >ns >ls >ds)))
               (go names lofs datas))
       ((("!<arch>\n" + ld-arhdr "/" "0" "0" "0" "0" isz + idx)
         + (#ltab ? (ld-arhdr "//" "" "" "" "" #ltab + ld-arpad ltab) ""))
        + body))
   ; a set of objects -> (dt owed): dt every nom defined or synthesized, a tablet the caller
   ; pins into; owed the strong undefineds left. __start_X/__stop_X are ldres's to answer.
   (ld-bracket? nm)
    (nm @ ("__start_" + (s && 0 < #s)) 1 ("__stop_" + (s && 0 < #s)) 1 0)
   (ldledger srcs mach)
    (: duos (map (p \ (dusyms <p <>p mach)) srcs)
       dt {}
       (map (nm \ pin dt nm 1) ldsynth,
        map (du \ map (nm \ pin dt nm 1) <du) duos,
        [dt (foldl (\ a du (foldl (\ a2 nm (dt nm || elem nm a2
                                            || ld-bracket? nm ? a2 (nm . a2)))
                                  a <>du))
                   () duos)]))
   ; pull the members the index names for owed noms, each pull's undefineds joining the owed,
   ; until none hits -> (picked-srcs owed); `dt` grows in place.
   (arpull path s dt owed mach)
    (: idx (ld-arsyms path s) lt (ld-arlong s) seen {}
       (go u picked)
        (: hit (foldl (\ a nm (two? a ? a
                                 (idx nm @ o
                                    (? !(o-has? idx nm) a (o-has? seen o) a [o]))))
                      () u)
           (atom? hit ? [picked u]
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
   ; every archive in command order, after every object; `pairs` are read (path bytes)
   (ldarch srcs pairs tgt)
    (atom? pairs ? ()
       (: mach (peep elf-machines tgt 0)
          lg (ldledger srcs mach) dt <lg
          (go ps u acc)
           (atom? ps ? acc
              (: r <ps
                 _ (ld-ar? <>r ? 0 (scare 'link-not-archive <r))
                 pr (arpull <r <>r dt u mach)
                 (go >ps <>pr (acc + <pr))))
          (go pairs <>lg ())))

   ; lay one lane across the set, object order then header order, each section aligned as it
   ; asks. pins the base per section index -> the address past the last.
   (ldlay1 lane cur os)
    (atom? os ? cur
       (: ob <os bs (peep ob 'base 0)
          (go c is) (atom? is ? c
                       (: se (peep (peep ob 'secs 0) <is ())
                          a (ld-align (se 3) c)
                          (pin bs <is a,
                           go (a + se 2) >is)))
          (ldlay1 lane (go cur (peep (peep ob 'lanes 0) lane ())) >os)))

   ; the named lanes of a set that travel with `home`, first-seen order: layout and emit both walk it
   (ld-nlanes objs home)
    (: seen {}
       (nhome ob l) (peep (peep ob 'secs 0) <(peep (peep ob 'lanes 0) l ()) () 4)
       (go os acc)
        (atom? os ? (rev acc)
           (<os @ ob
              (go >os (foldl (\ a l (0 < peep seen l 0 || nhome ob l != home ? a
                                       (pin seen l 1, l . a)))
                             acc (ob 'named)))))
       (go objs ()))
   ; lay them, each whole, after the known lane they travel with -> the next address
   (ldlayn home cur objs)
    (foldl (c \ l \ ldlay1 l c objs) cur (ld-nlanes objs home))
   ; and emit them in that same order
   (ldemitn cx home objs r)
    (foldl (a \ l \ ldemit cx l <a objs >a) r (ld-nlanes objs home))

   ; how many bytes a lane holds in one object; a lane may be present and empty
   (ld-lanesz ob lane)
    (foldl (\ a i (a + (peep (peep ob 'secs 0) i ()) 2))
           0 (peep (peep ob 'lanes 0) lane ()))

   ; pin every section's load address: hdrsz of headers, text, rodata, data, then the nif
   ; region, 16-aligned and packed so the __start_/__stop_ bracket reads one array. bss is
   ; the caller's. salign is the grain the lanes are cut on (a page, or 1 to pack). dense 0
   ; writes a cut's gap as zeros; 1 keeps the file offset and lifts only the address.
   ; -> (end nifstart o0 d0 t1 o1); under dense 1 an end is not the next start.
   (ldlay objs base hdrsz salign dense)
    (: (cut v f) (dense ? (ld-lift salign v f) (ld-align salign v))
       t1 (ldlayn 'text (ldlay1 'text (base + hdrsz) objs) objs)
       o0 (cut t1 (t1 - base))
       o1 (ldlayn 'rodata (ldlay1 'rodata o0 objs) objs)
       d0 (cut o1 (o1 - base - (o0 - t1)))
       d1 (ldlayn 'data (ldlay1 'data d0 objs) objs)
       n0 (ld-align 16 d1)
       [(ldlay1 'nifs n0 objs) n0 o0 d0 t1 o1])

   ; the symbol book: name -> (addr weak?), every defined global/weak across the set.
   ; strong beats weak, two strongs scare, the first weak stands.
   (ldsyms objs)
    (: glo {}
       (one ob i)
        (peep ob 'nsym 0 <= i ? 0
           (: sy (peep (peep ob 'syms 0) i ())
              bind (sy 1) shx (sy 3)
              (shx = 0 || !(elem bind '(1 2)) ? (one ob (i + 1))
                 (: nm <sy
                    _ (two? (peep (peep ob 'secs 0) shx ()) ? 0
                         (scare 'link-sym-section nm))
                    a (peep (peep ob 'base 0) shx 0 + sy 4)
                    w (bind = 2)
                    old (peep glo nm ())
                    ((? (atom? old) (pin glo nm [a w])
                        w 0
                        (old 1) (pin glo nm [a w])
                        (scare 'link-dup nm)),
                     one ob (i + 1))))))
       ((: (each os) (atom? os ? 0 (one <os 1, each >os))
           (each objs)),
        glo))

   ; every laid named lane -> (start end), for ldres's generic bracket
   (ld-extents objs)
    ({} @ xt
       (map (ob \ map (l \ map (i \ : a (peep (peep ob 'base 0) i 0)
                                      e (a + peep (peep ob 'secs 0) i () 2)
                                      r (xt l)
                                      (pin xt l (atom? r ? [a e] [(a < <r ? a <r) (<>r < e ? e <>r)])))
                                 (peep (peep ob 'lanes 0) l ()))
                       (ob 'named))
            objs,
        xt))

   ; resolve a name: the symbol book, or a bracket: the nif region (n0..n1), the -pie
   ; relative-reloc table (r0..r1, empty without -pie) moonlibc's startup walks, or ld's
   ; generic __start_X/__stop_X over a section named X.
   (ldres glo n0 n1 r0 r1 xt nm)
    (glo nm @ r
       (? (two? r) <r
          (nm = "__start_love_nifs") n0
          (nm = "__stop_love_nifs") n1
          (nm = "__start_love_rela") r0
          (nm = "__stop_love_rela") r1
          (: x (nm @ ("__start_" + (s && 0 < #s)) (xt (name s) @ v (two? v ? [<v]))
                     ("__stop_" + (s && 0 < #s)) (xt (name s) @ v (two? v ? [<>v]))
                     ())
             (two? x ? <x (scare 'link-undef nm)))))

   ; patch one object's one section: its bytes as text snips + byte lists, each relocation's
   ; field spliced in. entries must ascend by offset. cx: (glo n0 n1 r0 r1 relbox rv arm? be
   ; xt), the symbol book, the brackets, the -pie/-shared site box, the riscv flag, the arm
   ; flag ('i386 for EM_386), the backend fields re-encode through, the named-lane extents.
   ; kind numbers collide across machines (R_RISCV_64 is R_X86_64_PC32), so dispatch is by machine.
   (ldpatch ob ix base [glo n0 n1 r0 r1 relbox rv arm? be xt])
    (: s (peep ob 'src 0) se (peep (peep ob 'secs 0) ix ())
       off0 (se 1) sz (se 2)
       (ent es) (? (atom? es) ()
                   (<<es = ix) ><es
                   (ent >es))
       (go pos es acc)
        (atom? es ? (rev (snip s pos (off0 + sz) . acc))
           (: e <es ro <e kind (e 1) ad (e 3)
              _ (pos - off0 <= ro ? 0 (scare 'link-unsorted (peep ob 'id 0)))
              sy (peep (peep ob 'syms 0) (e 2) ())
              ; a -shared import's dynsym index, () for anything this link defines
              dyn (? relbox (peep relbox 'dyn 0) 0)
              ix (? (dyn = 1 && sy 3 = 0) (peep (relbox 'imp) <sy ()) ())
              sv (? (sy 2 = 3)
                    (two? (peep (peep ob 'secs 0) (sy 3) ()) ? 0
                        (scare 'link-sym-section (peep ob 'id 0)),
                     peep (peep ob 'base 0) (sy 3) 0)
                    ; a defined local resolves in its own object, never the book (clang
                    ; relocates against .L labels)
                    (sy 1 = 0 && 0 < sy 3 < 65280)
                     (two? (peep (peep ob 'secs 0) (sy 3) ()) ? 0
                         (scare 'link-sym-section <sy),
                      peep (peep ob 'base 0) (sy 3) 0 + sy 4)
                    ; a weak undefined symbol resolves to zero
                    (sy 1 = 2 && sy 3 = 0 && atom? (glo <sy)) 0
                    (ldres glo n0 n1 r0 r1 xt <sy))
              ; the REL machines: the addend is in the field and `ad` arrives (). an ARM field
              ; is always 4 bytes, an i386 one by kind.
              (? (arm? == 'i386)
                 (: w (kind @ 20 2 21 2 22 1 23 1 4)
                    (ro + w <= sz ? 0 (scare 'link-oob (peep ob 'id 0)),
                     relbox ? (scare 'link-i386-pie <sy),
                     go (off0 + ro + w) >es
                        (ld386 s (off0 + ro) sv kind (base + ro)
                         . (snip s pos (off0 + ro) . acc))))
                 arm?
                 (ro + 4 <= sz ? 0 (scare 'link-oob (peep ob 'id 0)),
                  ; a relocatable image: record each abs32 site for the loader to slide
                  relbox && kind = 2 ? (pin relbox 0 ((base + ro) . relbox 0)),
                  ; ..a movw/movt pair's split immediates cannot be slid: `la` must use a
                  ; pooled abs32 word there
                  relbox && elem kind '(47 48) ? (scare 'link-abs-imm <sy),
                  go (off0 + ro + 4) >es
                     (ldarm be s (off0 + ro) sv kind (base + ro)
                      . (snip s pos (off0 + ro) . acc)))
                 (: sa (ld-u64 (sv + ad))
                    prel (s64 (ld-u64 (sa - (base + ro))))            ; S + A - P, signed
                    abs64? (rv ? (kind = 2) (elem kind '(1 257)))   ; R_RISCV_64 / R_X86_64_64 / R_AARCH64_ABS64
                    ; R_X86_64_32 / _32S and R_AARCH64_ABS32: S + A into 4 bytes; ABS32 takes either range
                    abs32? (!rv && elem kind '(10 11 258))
                    pc64? (!rv && elem kind '(24 260))              ; R_X86_64_PC64 / R_AARCH64_PREL64: S + A - P in eight bytes
                    w (? (abs64? || pc64?) 8 (rv && kind = 19) 8 4)             ; call_plt spans the auipc pair
                    ; -pie: record each abs64 site for the startup relocator to add the base.
                    ; -shared: record (site import value) for the loader, an import's addend or
                    ; the link-time value; a weak undefined stays zero.
                    wu (sy 1 = 2 && sy 3 = 0 && atom? (glo <sy))
                    _ (? (relbox && abs64? && dyn = 1)
                          (wu ? 0 (pin relbox 0 ([(base + ro) ix (ix ? ad sa)] . relbox 0)))
                         (relbox && abs64?) (pin relbox 0 (base + ro . relbox 0))
                         (charm? ix && !(elem kind (relbox 'br))) (scare 'link-import-addr <sy))
                    ; an abs32 site cannot be slid by a 64-bit base
                    _ (relbox && abs32? ? (scare 'link-abs32-pie <sy))
                    _ ((elem kind $ rv ? '(2 17 19 57)
                                            '(1 2 4 10 11 24 257 258 260 261 273 274 275 277 278 280 282 283 284 285 286 299)) ?
                         0 (scare 'link-reloc kind))
                    _ (ro + w <= sz ? 0 (scare 'link-oob (peep ob 'id 0)))
                    bs (? abs64? (le64 sa)
                          pc64? (le64 (ld-u64 (sa - (base + ro))))
                          abs32?                                       ; _32 unsigned, _32S signed
                           (: v (kind = 10 ? sa (s64 sa))
                              ((kind = 10 || kind = 258) && 0 <= v && v <= 4294967295 || fits32 v ? 0 (scare 'link-range <sy),
                               le32 v))
                          (elem kind '(2 4 261) || rv && kind = 57)
                           (: v prel                          ; pc32/plt32/32_pcrel: S + A - P
                              (fits32 v ? 0 (scare 'link-range <sy),
                               le32 v))
                          ; an instruction field, by the backend; () is out of reach
                          (: k <((rv ? ldrv-kinds lda64-kinds) kind)
                             r (refix-with be k (map (i \ s (off0 + ro + i)) ^w) sa (base + ro) w)
                             (two? r ? r (scare 'link-range <sy))))
                    (go (off0 + ro + w) >es
                        (bs . snip s pos (off0 + ro) . acc))))))
       (go off0 (ent (ob 'relas)) ()))

   ; emit one lane in layout order, zero-padding up to each base -> (end . pieces)
   (ldemit cx lane cur os acc)
    (atom? os ? (cur . acc)
       (: ob <os
          (go c ac is)
           (atom? is ? (c . ac)
              (: se (peep (peep ob 'secs 0) <is ())
                 b (peep (peep ob 'base 0) <is 0)
                 pad (c < b ? [(ld-zeros (b - c))])
                 (go (b + se 2) (ac + pad + ldpatch ob <is b cx) >is)))
          r (go cur acc (peep (peep ob 'lanes 0) lane ()))
          (ldemit cx lane <r >os >r)))

   ; the executable's symbol table: every defined symbol across the set, locals first (sh_info
   ; names the first global), then the globals that won. st_size rides through from the object.
   ; lanesx maps a lane to its section index in the image, a named lane by its home. mksym/esz
   ; are the class's entry writer and stride. -> (bytes strs nlocal)
   (ldstab objs glo lanesx mksym esz)
    (: (lx se) (o-has? lanesx (se 0) ? (peep lanesx (se 0) 0)
                  (peep lanesx (se 4) 0))
       (one ob acc)
        (: bs (peep ob 'base 0) secs (peep ob 'secs 0) syms (peep ob 'syms 0)
           (go i a)
            (peep ob 'nsym 0 <= i ? a
               (: sy (syms i)
                  nm <sy bind (sy 1) typ (sy 2) shx (sy 3)
                  se (secs shx)
                  ad (peep bs shx 0 + sy 4)
                  won (glo nm @ r (two? r ? (ad = <r) 0))
                  (go (i + 1)
                      (? (atom? se || 0 = #nm ||
                          !(elem typ '(0 1 2)) || !(elem bind '(0 1 2)))
                          a                             ; undefined, unnamed, a file/section marker, or dropped
                         ; a weak def a strong one replaced keeps its laid bytes covered, as a local ".lost"
                         (0 < bind && !won) ([(nm + ".lost") 0 typ (lx se) ad (sy 5)] . a)
                         ([nm bind typ (lx se) ad (sy 5)] . a)))))
           (go 1 acc))
       all (foldl (\ a ob (one ob a)) () objs)
       locs (filter (e \ <>e = 0) all)
       ord (locs + filter (e \ 0 < <>e) all)
       str (o-strtab (map cap ord))
       ; the NULL entry counts as a local
       [(ld-zeros esz + catall (o-mapi (\ i e (mksym (<>str i) (e 1) (e 2)
                                                        (e 3) (e 4) (e 5)))
                                         ord))
        <str (1 + tally locs)])

   ; the abs64 relocations across the set: the -pie table's entry count
   (ld-nabs objs rv)
    (foldl (\ a ob (foldl (\ a2 tr
              (foldl (\ a3 e ((rv ? (e 1 = 2) (elem (e 1) '(1 257))) ? (a3 + 1) a3)) a2 >tr))
              a (peep ob 'relas ())))
       0 objs)

   ; -- .comment, the producer record: NUL-separated strings, the inputs' deduped ahead of
   ; `prod`. a blob need not end in NUL, so the split is bounded.
   (ld-cmsplit s)
    (: n #s
       (go i j acc) (? (n <= j) (rev (j <= i ? acc (snip s i j . acc)))
                       (s j = 0) (go (j + 1) (j + 1) (j <= i ? acc (snip s i j . acc)))
                       (go i (j + 1) acc))
       (go 0 0 ()))
   (ld-comment objs prod)
    (: (add acc t) (elem t acc ? acc (acc + [t]))
       ins (foldl (\ a ob (a + ld-cmsplit (peep ob 'comment ""))) () objs)
       (catall (map (t \ o-strbytes t + '(0)) (foldl add () (ins + [prod])))))

   ; link ((id bytes)..) into an executable's piece list for ld-write. three segments, r-x
   ; code, r literals, rw data, plus one for .image.
   ; pie: et_dyn at base 0, every abs64 site in a table bracketed by __start_/__stop_love_rela
   ; for moonlibc's startup to add the load base.
   ; org: () for the default base (pie 0 / elf-base), or a number: a bare-metal image there,
   ; in one segment.
   ; prod: the .comment producer string, without the vcs suffix, which would make a fixpoint's
   ; two compilers differ. readme: text in an unmapped `.love.README`, "" for none.
   (ldlink target pie org srcs prod readme)
    (: mach (peep elf-machines target 0)
       _ (0 < mach ? 0 (scare 'link-target target))
       objs (map (p \ ld-read <p <>p mach) srcs)
       rv (mach = 243)
       ; em_386 and em_arm: ELF32 headers, symbols and REL fields
       w32 (elem mach '(3 40))
       _ (w32 && pie ? (scare 'link-i386-pie target))
       shf (w32 ? elf-shdr32 elf-shdr)
       phf (w32 ? elf32-phdr elf64-phdr)
       ; the largest page a kernel may map with: two segments sharing one overlap.
       ; aarch64 meets 4K, 16K and 64K kernels.
       pg (mach = 183 ? 65536 4096)
       base (? (charm? org) org pie 0 elf-base)
       ; w^x, three segments, only under an OS. with `org` one segment: a bare-metal caller
       ; sets org from hdrsz, the header plus one phdr per segment, so more would move the entry.
       img? (0 < foldl (\ a ob (a + ld-lanesz ob 'image)) 0 objs)
       wx? !(charm? org)
       ; netbsd's exec requires the ident note: 24 bytes in the header reserve, a pt_note plus
       ; an alloc section so strip keeps it, on the ISAs that can meet a BSD
       bsd? (elem mach '(62 183 243 3) || target = 'arm)
       nb? (wx? && bsd?)
       hdrsz ((w32 ? 52 64) + (w32 ? 32 56) * ((wx? ? 3 1) + (img? ? 1 0) + (nb? ? 1 0)) + (nb? ? 24 0))
       nbo (hdrsz - 24)
       nbnote (nb? ? (catall [(le32 7) (le32 4) (le32 1)                 ; namesz descsz netbsd_tag
                              '(78 101 116 66 83 68 0 0) (le32 1000000000)]))   ; "NetBSD\0\0", 10.0
                  
       lay (ldlay objs base hdrsz (wx? ? pg 1) 1)
       end <lay n0 <>lay o0 <>>lay d0 <>>>lay t1 (lay 4) o1 (lay 5)
       ; the address the cuts skipped, which the file does not carry: from d0 on an offset is
       ; `addr - base - sk`, o0's is `t1 - base`
       sk ((o0 - t1) + (d0 - o1))
       nrel (pie ? (ld-nabs objs rv) 0)
       r0 (pie ? (ld-align 16 end) end)
       r1 (r0 + 8 * nrel)
       ; the file bytes end on 16, for .bss and .image; the slack is outside .love.rela, where
       ; the relocator would read a zero as a site
       dend (ld-align 16 r1)
       ; .bss: p_memsz runs to bend, p_filesz stops at dend
       bend (ldlayn 'bss (ldlay1 'bss dend objs) objs)
       ; .image last, past .bss, so `love bake` can grow it at the file's tail; its own segment,
       ; or the .bss gap would be file zeros. no .image section, no segment.
       ioff (dend - base - sk)
       iaddr (img? ? (ld-lift pg bend ioff) dend)
       iend (img? ? (ldlay1 'image iaddr objs) dend)
       isz (iend - iaddr)
       endf (img? ? (ioff + isz) ioff)
       ; .image's bytes start up to 15 above iaddr, on its 16 grain, and its headers name that
       ; start: one beginning below it is an image the wake cannot find
       ist (img? ? (ld-align 16 iaddr) iaddr)
       isho (ioff + (ist - iaddr))
       iszr (iend - ist)
       relbox (pie ? {0 ()})    ; abs64 sites
       glo (ldsyms objs)
       ; the entry: `_start` when defined, else the first object's text (mooncc's crt0)
       ent (: e (glo "_start")
              o1 <objs
              (two? e ? <e
                 (peep (peep o1 'base 0) <(peep (peep o1 'lanes 0) 'text ()) 0)))
       cx [glo n0 end r0 r1 relbox rv (ld-rel32 mach) (backends target) (ld-extents objs)]
       et (ldemitn cx 'text objs (ldemit cx 'text (base + hdrsz) objs ()))
       eo (ldemitn cx 'rodata objs (ldemit cx 'rodata o0 objs >et))
       ed (ldemitn cx 'data objs (ldemit cx 'data d0 objs >eo))
       en (ldemit cx 'nifs <ed objs >ed)
       tail (<en < r0 ? [(ld-zeros (r0 - <en))])
       rtab ((pie ? (catall (map le64 (rev (peep relbox 0 ()))))) + ld-zeros (dend - r1))
       ei (img? ? (ldemit cx 'image iaddr objs ()) [iaddr])
       ; -- the section headers and symbol table, past p_filesz. every loaded byte has a
       ; covering section, as strip rebuilds a file from its sections. --
       lanesx {'text 1 'rodata 2 'data 3 'nifs 4 'bss 6 'image 7}
       st (ldstab objs glo lanesx (w32 ? elf-sym32 elf-sym) (w32 ? 16 24))
       ; e_shstrndx and .symtab's sh_link are fixed at 10 and 9, so new sections go last.
       ; an object says love_nifs, a C identifier, so GNU ld synthesizes its brackets; the
       ; binary may say .love.nifs, ldres defining the pair itself.
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
       sht (catall [(shf 0 0 0 0 0 0 0 0 0 0)                                    ; the reserved null header
                     ; a lane's offset follows the last byte before it, so no gap is unowned
                    (shf (snm 0) 1 6 (base + hdrsz) hdrsz (t1 - (base + hdrsz)) 0 0 16 0)
                    (shf (snm 1) 1 2 o0 (t1 - base) (o1 - o0) 0 0 16 0)
                    (shf (snm 2) 1 3 d0 (d0 - base - sk) (<ed - d0) 0 0 16 0)
                    (shf (snm 3) 1 3 <ed (<ed - base - sk) (<en - <ed) 0 0 16 0)
                    (shf (snm 4) 1 2 r0 (r0 - base - sk) (r1 - r0) 0 0 16 0)     ; the -pie table (empty non-pie)
                    (shf (snm 5) 8 3 dend (dend - base - sk) (bend - dend) 0 0 16 0)
                    (shf (snm 6) 1 3 ist isho iszr 0 0 16 0)
                    (shf (snm 7) 2 0 0 symo symz 9 (st 2) 8 (w32 ? 16 24))         ; link=.strtab info=first global
                    (shf (snm 8) 3 0 0 stro strz 0 0 1 0)
                    (shf (snm 9) 3 0 0 ssto sstz 0 0 1 0)
                    (shf (snm 10) 1 48 0 cmto cmtz 0 0 1 1)                     ; .comment: merge|strings, no alloc
                    (0 < rdmz ? (shf (snm 11) 1 32 0 rdmo rdmz 0 0 1 0) ())    ; .love.README: strings, no alloc
                    (nb? ? (shf (snm 12) 7 2 (base + nbo) nbo 24 0 0 4 0))])   ; sht_note, alloc: strip keeps it
       ; w^x: headers + code r-x; literals r; .data through love_rela, bss in memsz, rw; the
       ; image rw. no page is in two segments, and the file pays no padding: offsets run on
       ; while addresses skip. sound only while no relocation lands in text or rodata.
       ; .image ends its segment with no load above it, as bake_tail requires.
       phs ((wx? ? [(phf 1 5 0 base base (t1 - base) (t1 - base) pg)
                    (phf 1 4 (t1 - base) o0 o0 (o1 - o0) (o1 - o0) pg)
                    (phf 1 6 (d0 - base - sk) d0 d0 (dend - d0) (bend - d0) pg)]
                 [(phf 1 7 0 base base (dend - base) (bend - base) pg)])
            + (img? ? [(phf 1 6 isho ist ist iszr iszr pg)])
            + (nb? ? [(phf 4 4 nbo (base + nbo) (base + nbo) 24 24 4)]))
       hdr (w32 ? (elf32-hdrn 2 ent mach (arm-eflags target) [shto nsh 10] phs) (elf64-hdrn (pie ? 3 2) ent mach [shto nsh 10] phs))
       ; ei_osabi = 9 (freebsd) in e_ident[7]: freebsd refuses an unbranded exe, linux ignores it
       hdr9 (bsd? ? (ld-brand hdr 7 9) hdr)
       (hdr9 . ((nb? ? [nbnote]) + >en + tail + [rtab] + >ei
                 + [(ld-zeros (symo - endf)) <st <>st <shstr cmt rdm
                    (ld-zeros (shto - (rdmo + rdmz))) sht])))

   ; --- the shared object: ldlink's lay at base 0, plus what a dynamic loader reads ---
   ; a strong undefined no object defines is an import: a plt stub branches through a got
   ; slot the loader fills (glob_dat), and an abs64 site gets a dynamic relocation. every
   ; defined global is exported. the dynamic tables ride the data segment past the nifs,
   ; bss after them. a64 and x64.
   (ld-imports objs)
    (: defs {}
       (walk f) (map (ob \ map (i \ f (peep (peep ob 'syms 0) i ())) ^(peep ob 'nsym 0)) objs)
       _ (walk (sy \ two? sy && 0 < sy 3 && elem (sy 1) '(1 2) ? (pin defs <sy 1)))
       (: seen {}
          (go os acc)
           (atom? os ? (rev acc)
              (: ob <os
                 (one i a) (peep ob 'nsym 0 <= i ? a
                              (peep (peep ob 'syms 0) i () @ sy
                                 (one (i + 1)
                                      (sy 1 = 1 && sy 3 = 0 && !(defs <sy) && !(seen <sy)
                                       && !(elem <sy ldsynth) && !(ld-bracket? <sy) ?
                                          (pin seen <sy 1, <sy . a) a))))
                 (go >os (one 1 acc))))
          (go objs ())))
   ; the defined globals that won the link, first-seen: (name bind typ addr size)
   (ld-exports objs glo)
    (: seen {}
       (one ob acc)
        (: (go i a)
            (peep ob 'nsym 0 <= i ? a
               (: sy (peep (peep ob 'syms 0) i ())
                  ad (peep (peep ob 'base 0) (sy 3) 0 + sy 4)
                  (go (i + 1)
                      (0 < sy 3 && elem (sy 1) '(1 2) && elem (sy 2) '(0 1 2) && !(seen <sy)
                       && (glo <sy @ r (two? r && <r = ad)) ?
                          (pin seen <sy 1, [<sy (sy 1) (sy 2) ad (sy 5)] . a) a))))
           (go 1 acc))
       (rev (foldl (\ a ob (one ob a)) () objs)))
   ; the sysv hash a loader looks an export up by
   (ld-elfhash s)
    (foldl (\ h c (: g ((h << 4) + c) t (g & 0xf0000000)
                     ((t ? (g ^ (t >> 24)) g) & (0xffffffff - 0xf0000000))))
           0 (o-strbytes s))
   (ld-hash names)
    (: n #names nb (n < 1 ? 1 n)
       bk {} ch {}
       _ (each ^n (i \ (ld-elfhash (names i) % nb @ b
                          (pin ch i (peep bk b 0), pin bk b i))))
       (catall ([(le32 nb) (le32 n)] + map (b \ le32 (peep bk b 0)) ^nb
                + map (i \ le32 (peep ch i 0)) ^n)))
   ; a64: adrp x16, got; ldr x17, [x16, lo12]; br x17; nop
   (ld-plt-a64 stub got)
    (: pd ((got >> 12) - (stub >> 12)) lo (got & 4095)
       (catall [(le32 (0x90000010 | ((pd & 3) << 29) | ((pd >> 2 & 0x7ffff) << 5)))
                (le32 (0xf9400211 | ((lo >> 3) << 10)))
                (le32 0xd61f0220) (le32 0xd503201f)]))
   ; x64: jmp *got(%rip), then int3 to the slot's end
   (ld-plt-x64 stub got) (catall [[255 37] (le32 (ld-u32 (got - (stub + 6)))) (map (_ \ 204) ^10)])
   ; a machine's row: the branch kinds that may reach an import, relative / abs64 / glob_dat, the stub, the page
   ld-dyn {183 ['(282 283) 1027 257 1025 ld-plt-a64 65536]
           62 ['(4) 8 1 6 ld-plt-x64 4096]}
   (ldshared target soname needed srcs prod)
    (: mach (peep elf-machines target 0)
       dm (peep ld-dyn mach ())
       _ (two? dm ? 0 (scare 'link-shared-target target))
       objs0 (map (p \ ld-read <p <>p mach) srcs)
       _ (0 < foldl (\ a ob (a + ld-lanesz ob 'image)) 0 objs0 ? (scare 'link-shared-image soname))
       imps (ld-imports objs0) ni #imps
       plt {'id "<plt>" 'src "" 'secs {1 ['text 0 (16 * ni) 16 'text]} 'lanes {'text [1]}
            'drops {} 'syms {} 'nsym 0 'relas () 'named () 'base {}}
       objs (objs0 + [plt])
       pg (dm 5)
       nph 5                                    ; three loads, dynamic, gnu_stack
       hdrsz (64 + 56 * nph)
       lay (ldlay objs 0 hdrsz pg 1)
       end <lay n0 <>lay o0 <>>lay d0 <>>>lay t1 (lay 4) o1 (lay 5)
       sk ((o0 - t1) + (d0 - o1))
       glo (ldsyms objs)
       p0 (peep (plt 'base) 1 0)
       _ (each ^ni (k \ pin glo (imps k) [(p0 + 16 * k) 0]))
       exps (ld-exports objs0 glo) ne #exps
       ; dynsym: the null symbol, the imports, the exports
       dstr (o-strtab ((soname . needed) + imps + map cap exps))
       (soff k) (<>dstr k)
       nn #needed
       nrel (ld-nabs objs ())
       ndy (nn + 11)
       dy0 (ld-align 16 end)       got0 (dy0 + 16 * ndy)
       ra0 (got0 + 8 * ni)         ds0 (ra0 + 24 * (nrel + ni))
       nsym (1 + ni + ne)          hs0 (ds0 + 24 * nsym)
       htab (ld-hash ("" . imps + map cap exps))
       st0 (hs0 + #htab)           dend (ld-align 16 (st0 + #<dstr))
       bend (ldlayn 'bss (ldlay1 'bss dend objs) objs)
       (fo a) (a - sk)
       _ (pin plt 'src (string (catall (map (k \ (dm 4) (p0 + 16 * k) (got0 + 8 * k)) ^ni))))
       imp ({} @ t (each ^ni (k \ pin t (imps k) (1 + k)), t))
       relbox {0 () 'dyn 1 'imp imp 'br <dm}
       cx [glo n0 end dy0 dy0 relbox () () (backends target) (ld-extents objs)]
       et (ldemitn cx 'text objs (ldemit cx 'text hdrsz objs ()))
       eo (ldemitn cx 'rodata objs (ldemit cx 'rodata o0 objs >et))
       ed (ldemitn cx 'data objs (ldemit cx 'data d0 objs >eo))
       en (ldemit cx 'nifs <ed objs >ed)
       (rela off ty sy ad) (catall [(le64 off) (le32 ty) (le32 sy) (le64 (ld-u64 ad))])
       rels (map (r \ (r 1 @ k (charm? k ? (rela <r (dm 2) k (r 2)) (rela <r (dm 1) 0 (r 2)))))
                 (rev (relbox 0))
             + map (k \ rela (got0 + 8 * k) (dm 3) (1 + k) 0) ^ni)
       nr #rels
       dyn (catall (map (d \ catall [(le64 <d) (le64 <>d)])
                        (map (k \ [1 (soff (1 + k))]) ^nn
                         + [[14 (soff 0)] [4 hs0] [5 st0] [6 ds0] [10 #<dstr] [11 24]
                            [7 ra0] [8 (24 * nr)] [9 24] [30 8] [0 0]])))
       dsym (catall ([(ld-zeros 24)]
                     + map (k \ elf-sym (soff (1 + nn + k)) 1 2 0 0 0) ^ni
                     + o-mapi (\ k e (elf-sym (soff (1 + nn + ni + k)) (e 1) (e 2)
                                              (? (e 3 < t1) 1 (e 3 < o1) 2 (e 3 < dend) 3 11) (e 3) (e 4)))
                              exps))
       dbytes (catall [dyn (ld-zeros (8 * ni)) (catall rels) (ld-zeros (24 * (nrel + ni - nr)))
                       dsym htab <dstr (ld-zeros (dend - (st0 + #<dstr)))])
       pad (<en < dy0 ? [(ld-zeros (dy0 - <en))])
       endf (fo dend)
       lanesx {'text 1 'rodata 2 'data 3 'nifs 4 'bss 11}
       st (ldstab objs glo lanesx elf-sym 24)
       shstr (o-strtab '(".text" ".rodata" ".data" ".love.nifs" ".dynamic" ".got" ".rela.dyn"
                         ".dynsym" ".hash" ".dynstr" ".bss" ".symtab" ".strtab" ".shstrtab" ".comment"))
       (snm k) (<>shstr k)
       symo (ld-align 8 endf) symz #<st
       stro (symo + symz) strz #<>st
       ssto (stro + strz) sstz #<shstr
       cmt (ld-comment objs prod) cmto (ssto + sstz) cmtz #cmt
       shto (ld-align 8 (cmto + cmtz))
       sht (catall [(elf-shdr 0 0 0 0 0 0 0 0 0 0)
                    (elf-shdr (snm 0) 1 6 hdrsz hdrsz (t1 - hdrsz) 0 0 16 0)
                    (elf-shdr (snm 1) 1 2 o0 t1 (o1 - o0) 0 0 16 0)
                    (elf-shdr (snm 2) 1 3 d0 (fo d0) (<ed - d0) 0 0 16 0)
                    (elf-shdr (snm 3) 1 3 <ed (fo <ed) (<en - <ed) 0 0 16 0)
                    (elf-shdr (snm 4) 6 3 dy0 (fo dy0) (16 * ndy) 10 0 8 16)      ; link=.dynstr
                    (elf-shdr (snm 5) 1 3 got0 (fo got0) (8 * ni) 0 0 8 8)
                    (elf-shdr (snm 6) 4 2 ra0 (fo ra0) (24 * nr) 8 0 8 24)        ; link=.dynsym
                    (elf-shdr (snm 7) 11 2 ds0 (fo ds0) (24 * nsym) 10 1 8 24)    ; info=first global
                    (elf-shdr (snm 8) 5 2 hs0 (fo hs0) #htab 8 0 4 4)
                    (elf-shdr (snm 9) 3 2 st0 (fo st0) #<dstr 0 0 1 0)
                    (elf-shdr (snm 10) 8 3 dend (fo dend) (bend - dend) 0 0 16 0)
                    (elf-shdr (snm 11) 2 0 0 symo symz 13 (st 2) 8 24)
                    (elf-shdr (snm 12) 3 0 0 stro strz 0 0 1 0)
                    (elf-shdr (snm 13) 3 0 0 ssto sstz 0 0 1 0)
                    (elf-shdr (snm 14) 1 48 0 cmto cmtz 0 0 1 1)])
       phs [(elf64-phdr 1 5 0 0 0 t1 t1 pg)
            (elf64-phdr 1 4 t1 o0 o0 (o1 - o0) (o1 - o0) pg)
            (elf64-phdr 1 6 (fo d0) d0 d0 (dend - d0) (bend - d0) pg)
            (elf64-phdr 2 6 (fo dy0) dy0 dy0 (16 * ndy) (16 * ndy) 8)
            (elf64-phdr 0x6474e551 6 0 0 0 0 0 16)]
       hdr (elf64-hdrn 3 0 mach [shto 16 14] phs)
       (hdr . (>en + pad + [dbytes]
               + [(ld-zeros (symo - endf)) <st <>st <shstr cmt
                  (ld-zeros (shto - (cmto + cmtz))) sht])))

   ; --- the kernel lane ---------------------------------------------------------
   ; every PT_LOAD carries p_paddr = p_vaddr - bias: laid where it runs, loaded where it lands
   ; (`qemu -kernel` copies by p_paddr with the MMU off). page-aligned segments: `boot`,
   ; text, rodata, data (nifs and image with it, .bss past p_filesz). .note.pvh sits in the
   ; header page, in no PT_LOAD: qemu finds the 32-bit entry through pt_note. `ent` names the
   ; entry symbol; `kimage_end` is synthesized past .bss, where the heap's RAM begins.
   (ldkern target ent vbase bias srcs)
    (: mach (peep elf-machines target 0)
       _ (0 >= mach ? (scare 'link-target target))
       objs (map (p \ ld-read <p <>p mach) srcs)
       (lsz lane) (foldl (\ a ob (a + ld-lanesz ob lane)) 0 objs)
       ne (ldlay1 'note vbase objs)
       b0 (ld-align 4096 ne)  b1 (ldlay1 'boot b0 objs)
       t0 (ld-align 4096 b1)  t1 (ldlayn 'text (ldlay1 'text t0 objs) objs)
       o0 (ld-align 4096 t1)  o1 (ldlayn 'rodata (ldlay1 'rodata o0 objs) objs)
       d0 (ld-align 4096 o1)  d1 (ldlayn 'data (ldlay1 'data d0 objs) objs)
       n0 (ld-align 16 d1)    n1 (ldlay1 'nifs n0 objs)
       i1 (ldlay1 'image n1 objs)
       kend (ldlayn 'bss (ldlay1 'bss i1 objs) objs)
       ; p_offset is the address one page in (the first page holds headers and the note),
       ; congruent to p_vaddr mod page
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
       ; no -pie table and no arm32 kernel; the riscv flag picks ldpatch's reloc numbers
       cx [glo n0 n1 n1 n1 () (mach = 243) () (backends target) (ld-extents objs)]
       en (ldemit cx 'note vbase objs ())
       eb (ldemit cx 'boot b0 objs (gap vbase b0))  ; from vbase, at offset 4096
       et (ldemitn cx 'text objs (ldemit cx 'text t0 objs (>eb + gap <eb t0)))
       eo (ldemitn cx 'rodata objs (ldemit cx 'rodata o0 objs (>et + gap <et o0)))
       ed (ldemitn cx 'data objs (ldemit cx 'data d0 objs (>eo + gap <eo d0)))
       ef (ldemit cx 'nifs n0 objs (>ed + gap <ed n0))
       eg (ldemit cx 'image n1 objs (>ef + gap <ef n1))
       fsz (fo i1)
       ; the section headers and symbol table ride past p_filesz
       lanesx {'note 1 'boot 2 'text 3
               'rodata 4 'data 5 'nifs 5 'image 5 'bss 6}
       st (ldstab objs glo lanesx elf-sym 24)
       shstr (o-strtab '(".note.pvh" ".boot" ".text" ".rodata"
                         ".data" ".bss" ".symtab" ".strtab" ".shstrtab"))
       (snm k) (<>shstr k)
       symo (ld-align 8 fsz) symz #<st
       stro (symo + symz) strz #<>st
       ssto (stro + strz) sstz #<shstr
       shto (ld-align 8 (ssto + sstz))
       sht (catall [(elf-shdr 0 0 0 0 0 0 0 0 0 0)                                 ; the reserved null header
                    (elf-shdr (snm 0) 7 2 vbase hdrsz nsz 0 0 4 0)                 ; .note.pvh, in the header page
                    (elf-shdr (snm 1) 1 7 b0 (fo b0) (b1 - b0) 0 0 4096 0)
                    (elf-shdr (snm 2) 1 6 t0 (fo t0) (t1 - t0) 0 0 4096 0)
                    (elf-shdr (snm 3) 1 2 o0 (fo o0) (o1 - o0) 0 0 4096 0)
                    (elf-shdr (snm 4) 1 3 d0 (fo d0) (i1 - d0) 0 0 4096 0)         ; .data, with nifs and image
                    (elf-shdr (snm 5) 8 3 i1 (fo i1) (kend - i1) 0 0 16 0)
                    (elf-shdr (snm 6) 2 0 0 symo symz 8 (st 2) 8 24)            ; link=.strtab info=first global
                    (elf-shdr (snm 7) 3 0 0 stro strz 0 0 1 0)
                    (elf-shdr (snm 8) 3 0 0 ssto sstz 0 0 1 0)])
       hdr (elf64-hdrn 2 <e mach [shto 10 9] (map (foldl id elf64-phdr) phs))
       (hdr . (>en + [(ld-zeros (4096 - (hdrsz + nsz)))] + >eg
                + [(ld-zeros (symo - fsz)) <st <>st <shstr
                   (ld-zeros (shto - (ssto + sstz))) sht])))

   ; --- the bare-metal 32-bit image ----------------------------------------------
   ; one ELF32 executable for a part with no MMU, laid where it runs; a loader copies each
   ; segment by p_paddr. the ELF header is in no segment: the first laid byte is the first
   ; mapped one, where the core looks (an M7 reads SP and PC from the vector table).
   ;
   ; `runs` is the map, as data -- a linker script in one list:
   ;   (at   VADDR lane..)   laid and loaded there, a gap from the run before padded in the file
   ;   (copy VADDR lane..)   laid at vaddr, loaded after the file bytes so far (`> RAM AT> FLASH`),
   ;                         the port's startup copying it across
   ; a lane slot may instead hold `(flags N)`, segment permissions overriding ld-segflags (a
   ; vector table is const to the silicon yet holds relocated addresses).
   ; consecutive `at` runs fuse into one segment; each `copy` run takes its own. after a
   ; `copy` every run must be one. `bss` may only end the last run. every lane the objects
   ; fill must be in the map. the copied region's noms (__data_start__ ..) are synthesized.
   ld-lanenames (ld-cls '((text ".text") (rodata ".rodata") (data ".data")
                          (nifs ".love.nifs") (bss ".bss") (image ".love.image")))
   (ld-lanenm l) (peep ld-lanenames l () @ r (two? r ? <r (string l)))
   ; a lane's first section in lay order, or (); its home and alignment are the lane's
   (ld-lane0 objs l)
    (: (go os) (atom? os ? ()
                  (peep (peep <os 'lanes 0) l () @ is
                     (two? is ? (peep (peep <os 'secs 0) <is ()) (go >os))))
       (go objs))
   ; a lane's home across the set; a known lane is its own
   (ld-homeof objs l)
    (elem l ld-lanes ? l
       (ld-lane0 objs l @ s (two? s ? (s 4) 'rodata)))
   (ld-secflags h) (? (h == 'text) 6 (elem h '(data bss nifs image)) 3 2)
   (ld-segflags objs ls)                                    ; pf_r plus what the lanes ask
    (foldl (\ a l (ld-homeof objs l @ h
                     (a | (? ( h == 'text) 1 (elem h '(data bss nifs image)) 2 0))))
           4 ls)
   ; a run row's lanes (atoms) and its `(flags N)` word (a pair)
   (ld-fword? ('flags . _)) 1
   (ld-runlanes r) (filter (nil? * ld-fword?) >>r)
   (ld-runflags r) (filter ld-fword? >>r @ f
                      (two? f ? (<><f @ v
                                   (charm? v && 0 < v <= 7 ? 0 (scare 'link-run-flags v),
                                    v))))
   ; the fused `at` segment's one flags word; two that disagree scare
   (ld-onef vs)
    (foldl (\ a v (? !v a !a v (a = v) a (scare 'link-run-flags v))) () vs)
   ; every lane the set actually puts bytes or address space in, first-seen order
   (ld-uselanes objs)
    (: seen {}
       (go os acc)
        (atom? os ? (rev acc)
           (go >os (foldl (\ a l (? (0 < peep seen l 0) a
                                    !(0 < ld-lanesz <os l) a
                                    (pin seen l 1, l . a)))
                          acc (ld-lanes + <os 'named))))
       (go objs ()))

   ; which 32-bit reloc patcher a machine's objects take: i386's, arm's (1), or none
   (ld-rel32 mach) (? (mach = 3) 'i386 (mach = 40) 1 ())
   (ldbare32 target runs srcs pns rel?)
    (: mach (peep elf-machines target 0)
       _ (0 >= mach  ? (scare 'link-target target))
       _ (atom? runs ? (scare 'link-no-map target))
       ; the re-encoder is the arm32 family's (see ldarm)
       be (backends (arm32? target ? 'thumb2 target))
       objs (map (p \ ld-read <p <>p mach) srcs)
       ; expand each run's lanes in place: every lane followed by the named lanes homed with
       ; it, unless the map names them itself (a table the silicon reads at a fixed address)
       (lrf a r) (a + ld-runlanes r)
       spoken (foldl lrf () runs)
       (unspoken n) !(elem n spoken)
       lruns (map (r \ <r . <>r . filter ld-fword? >>r
                                + foldl (a \ l \ a + cons l (filter unspoken (ld-nlanes objs l)))
                                  () (ld-runlanes r))
                  runs)
       maplanes (foldl lrf () lruns)
       ; a lane laid twice would part the bytes from lpos's one entry
       _ (foldl (\ seen l (elem l seen ? (scare 'link-lane-twice l) (l . seen)))
                () maplanes)
       _ (foldl (\ _ l (elem l maplanes ? 0 (scare 'link-unmapped-lane l)))
                0 (ld-uselanes objs))
       org (<lruns 1)
       foff (4096 + org % 4096)               ; the header's page, congruent to org
       ; -- the layout pass in the map's order; lpos records each lane's (vaddr fileoff size).
       ; -> per run: (kind vaddr fileoff filesz memsz lanes flags)
       lpos {}
       plan (: (go rs cur fpos copied acc)
                (atom? rs ? (rev acc)
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
                                         (pin lpos l [c f (n - c)],
                                          [n (l = 'bss ? f (f + n - c))])))
                               [start fo] ls)
                      (go >rs (copy? ? cur <w) <>w (copied || copy?)
                          ([kind start fo (<>w - fo) (<w - start) ls fl] . acc))))
               (go lruns org foff () ()))
       ; -- the segments, (vaddr paddr fileoff filesz memsz flags) each
       (fladdr f) (org + f - foff)            ; a file offset -> the address it loads at
       ats (filter (r \ <r == 'at) plan)
       cps (filter (r \ <r == 'copy) plan)
       aseg (two? ats ?
               (: a0 <ats aN (last ats)
                  [[(a0 1) (a0 1) (a0 2)
                    (aN 2 + aN 3 - a0 2)
                    (aN 1 + aN 4 - a0 1)
                    (ld-onef (map (r \ r 6) ats) @ af
                       (af ? af (ld-segflags objs (foldl (a \ r \ a + r 5) () ats))))]]))
       segs (aseg + map (r \ [(r 1) (fladdr (r 2)) (r 2) (r 3) (r 4)
                              (r 6 || ld-segflags objs (r 5))]) cps)
       hdrsz (52 + 32 * #segs)
       _ (hdrsz > foff ? (scare 'link-bare-headers hdrsz))
       glo (ldsyms objs)
       ; -- the board's absolutes, (name value), pinned first: the brackets below override them
       _ (foldl (\ _ p (pin glo <p [<>p 0], 0)) 0 pns)
       ; -- the copied region's brackets
       _ (<cps @ (_ . dv . da . df . dm . _)
          (pins glo "__data_start__" [dv 0]
                    "__data_end__"   [(dv + df) 0]
                    "__data_load__"  [(fladdr da) 0]
                    "__bss_start__"  [(dv + df) 0]
                    "__bss_end__"    [(dv + dm) 0]))
       ; -- the file bytes from org, .bss excluded, for a boot rom's length field
       _ (last plan @ pN
            (pin glo "__load_size__" [(pN 2 + pN 3 - foff) 0]))
       ; e_entry is for tools: the core takes the vector table
       ent (glo "_start" @ e (two? e ? <e org))
       ; the nif bracket: lpos's start is before the first section's alignment pad, so align it
       nif (lpos 'nifs @ r (two? r ? r [org org 0]))
       n0 (ld-align (ld-lane0 objs 'nifs @ s (two? s ? (s 3) 1)) <nif)
       relbox (rel? ? {0 ()})    ; the emit-relocs sites
       cx [glo n0 (<nif + nif 2) org org relbox () (ld-rel32 mach) be (ld-extents objs)]
       body (: (go rs fp acc)
                (atom? rs ? [fp acc]
                   (: r <rs
                      pad (fp < r 2 ? [(ld-zeros (r 2 - fp))])
                      e (foldl (a \ l \ ldemit cx l <a objs >a)
                               [(r 1)] (filter (!== 'bss) (r 5)))
                      (go >rs (r 2 + r 3) (acc + pad + >e))))
               (go plan foff ()))
       fend <body  pieces <>body
       ; -- the section headers and symbol table, past every loaded byte, one header per lane
       shl0 (filter (l \ elem l (ld-uselanes objs)) maplanes)
       ; with relocations, a named lane folds into the contiguous header before it with the same
       ; flags, as a loader may relocate only known section names. -> ((lane addr off flags size) ..)
       secs (: (go ls acc)
                (atom? ls ? (rev acc)
                   (: l <ls q (peep lpos l '(0 0 0))
                      p (two? acc ? <acc)
                      fl (ld-secflags (ld-homeof objs l))
                      (rel? && !(elem l '(text rodata data bss)) && two? p
                       && p 3 = fl && p 1 + p 4 = <q ?
                          (go >ls ([<p (p 1) (p 2) fl (p 4 + q 2)] . >acc))
                          (go >ls ([l <q <>q fl (q 2)] . acc)))))
               (go shl0 ()))
       shl (map (e \ <e) secs)
       lanesx ({} @ t (foldl (\ i l (pin t l i, i + 1)) 1 shl, t))
       st (ldstab objs glo lanesx elf-sym32 16)
       ; -- the abs32 sites by lane, each an Elf32_Rel R_ARM_ABS32 against symbol 0 (value 0),
       ; so S + A and a load delta agree. no shf_alloc.
       rsites (sort (rel? ? (relbox 0)))
       (rlane v) (: (go es) (atom? es ? ()
                               (<es @ e
                                  ((e 1) <= v < (e 1) + (e 4) ? <e (go >es))))
                    (go secs))
       rgrp (foldl (\ t v (rlane v @ l (l ? (pin t l (peep t l () + [v])) t))) {} rsites)
       rlanes (filter (l \ two? (peep rgrp l ())) shl)
       nr #rlanes
       shstr (o-strtab (map ld-lanenm shl + '(".symtab" ".strtab" ".shstrtab")
                        + map (l \ ".rel" + ld-lanenm l) rlanes))
       (snm k) (<>shstr k)
       nl #shl
       symo (ld-align 4 fend) symz #<st
       stro (symo + symz) strz #<>st
       ssto (stro + strz) sstz #<shstr
       relo (ld-align 4 (ssto + sstz))
       relbs (map (l \ catall (map (v \ catall [(le32 v) (le32 2)]) (peep rgrp l ()))) rlanes)
       reloffs (: (go bs cur acc) (atom? bs ? acc (go >bs (cur + #<bs) (acc + [cur])))
                  (go relbs relo ()))
       relsz (foldl (\ a b (a + #b)) 0 relbs)
       shto (ld-align 4 (relo + relsz))
       sht (catall ([(elf-shdr32 0 0 0 0 0 0 0 0 0 0)]                        ; the reserved null header
                    + o-mapi (\ i e (elf-shdr32 (snm i) (<e == 'bss ? 8 1) (e 3)
                                                (e 1) (e 2) (e 4) 0 0 4 0))
                             secs
                    + [(elf-shdr32 (snm nl) 2 0 0 symo symz (nl + 2) (st 2) 4 16)    ; link=.strtab
                       (elf-shdr32 (snm (nl + 1)) 3 0 0 stro strz 0 0 1 0)
                       (elf-shdr32 (snm (nl + 2)) 3 0 0 ssto sstz 0 0 1 0)]
                    + o-mapi (\ i l (elf-shdr32 (snm (nl + 3 + i)) 9 64 0           ; sht_rel, shf_info_link
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

   ; set byte i of a piece, a text or a byte list
   (ld-brand p i v)
    (string? p ? (snip p 0 i + string v + snip p (i + 1) #p)
       (: (go k l) (k = i ? (v . >l) (<l . (go (k + 1) >l))) (go 0 p)))

   ; write a piece list to a file: texts pass through, byte lists as casks. unlinked first,
   ; as a running binary refuses writing (ETXTBSY) and keeps its old inode.
   ; -> bytes written | open's error nom ('enoent ..); test with nom?, as zero bytes is falsy too.
   (ld-write path ps)
    (: _ (unlink path)
       q (open path "w")
       (go l n) (atom? l ? (close q, n)
                   (<l @ p
                      (say q (string? p ? p (cask p)),
                       go >l (n + #p))))
       (hot? q ? (go ps 0) q)))
) ; module 'holo
