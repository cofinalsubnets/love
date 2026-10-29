; src/love/holo/link.l -- a static ELF linker over relocatable objects of either class:
; resolve every symbol across the set (strong over weak, the nif brackets synthesized over
; the packed region), lay the sections by its default script (the engine klink's scripts
; share), apply the relocations, and write the executable.
; entry is the first object's text (a crt0). a foreign .o (gcc's) links too: sections a
; static image cannot use are dropped by a stated rule (see `class`), any other with bytes
; scares. x86-64 relocs replace their field; a64, rv64 and arm ones or bits into the word
; the placeholder carries.
; `ldkern` lays the same objects for bare metal: page-aligned pt_loads with p_paddr =
; p_vaddr - bias, for a loader that copies physical or one that maps virtual. `ldbare32`
; lays an ELF32 image for a part with no MMU from a map of runs.
; loads after src/love/holo/obj.l and lds.l.
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

   ; --- one ELF reader, either class and any e_type: link.l's lanes, nm and klink read
   ;     through it. rels? reads the relocations too. -> a tablet
   ;   'id 'src 'class 32|64 'type 'mach 'shnum
   ;   'sec        index -> [name type flags off size align entsize link info]
   ;   'syms 'nsym index -> [name bind type shndx value size other], 'nsym 0 with no .symtab
   ;   'rela       target index -> [(off kind sym addend) ..] in file order, the addend ()
   ;               on a REL; 'rels the same as [(target . entries) ..] in header order
   (ld-obj id s rels?)
    (: _ (#s > 52 && s 0 = 127 && s 1 = 69 && s 2 = 76 && s 3 = 70 ? 0 (scare 'link-not-elf id))
       fs (? (s 4 = 2) elf64f (s 4 = 1) elf32f (scare 'link-elf-class id))
       (f b r) (rdle s (b + <r) <>r)
       (fx nm) (ld-row fs nm)
       shoff (ld-f fs s 0 'e-shoff) shnum (ld-f fs s 0 'e-shnum)
       _ (shnum = 0 || ld-f fs s 0 'e-shent = ld-n fs 'sh-ent ? 0 (scare 'link-shentsize id))
       she (ld-n fs 'sh-ent)
       hn (fx 'sh-name) ht (fx 'sh-type) hf (fx 'sh-flags) ho (fx 'sh-off) hz (fx 'sh-size)
       ha (fx 'sh-align) he (fx 'sh-esz) hl (fx 'sh-link) hi (fx 'sh-info)
       shstro (? (shnum = 0) 0 (f (shoff + she * ld-f fs s 0 'e-shstrx) ho))
       sec {}
       _ (each ^shnum (i \ (: h (shoff + she * i)
                              (pin sec i [(ld-cstr s (shstro + f h hn)) (f h ht) (f h hf) (f h ho) (f h hz)
                                          (f h ha) (f h he) (f h hl) (f h hi)]))))
       ob {'id id 'src s 'class (? (s 4 = 2) 64 32) 'type (rle16 s 16) 'mach (rle16 s 18) 'shnum shnum
           'sec sec 'syms {} 'nsym 0 'rela {} 'rels ()}
       ; held to sh_entsize: a wrong stride reads well-formed garbage
       (esz r want) (? (r 6 = ld-n fs want) 0 (scare 'link-entsize <r))
       symi ((: (g i) (? (shnum <= i) -1 (sec i 1 = 2) i (g (i + 1)))) 1)
       _ (? (symi < 0) 0
            (: y (sec symi) _ (esz y 'sy-ent) ye (ld-n fs 'sy-ent) stro (sec (y 7) 3)
               yn (fx 'sy-name) yi (fx 'sy-info) yo (<yi + 1) yx (fx 'sy-shndx)
               yv (fx 'sy-val) yz (fx 'sy-size) syms (ob 'syms) n (y 4 // ye)
               _ (pin ob 'nsym n)
               (each ^n (i \ (: e (y 3 + ye * i) info (f e yi)
                                (pin syms i [(ld-cstr s (stro + f e yn)) (info >> 4) (info & 15)
                                             (f e yx) (f e yv) (f e yz) (s (e + yo))]))))))
       rty (? (s 4 = 2) 4 9) re (ld-n fs 'rl-ent)
       ro (fx 'rl-off) rk (fx 'rl-kind) rs (fx 'rl-sym) ad (fx 'rl-add)
       (ents r) (: (go k acc) (? (k < 0) acc
                                 (: e (r 3 + re * k)
                                    (go (k - 1) ([(f e ro) (f e rk) (f e rs) (? (two? ad) (s64 (f e ad)))] . acc))))
                   (go (r 4 // re - 1) ()))
       _ (? rels? (each ^shnum (i \ (: r (sec i)
                                       (? (r 1 = rty) (: _ (esz r 'rl-ent) es (ents r)
                                                         (pin (ob 'rela) (r 8) es, pin ob 'rels ((r 8 . es) . ob 'rels)))
                                          0))))
            0)
       _ (pin ob 'rels (rev (ob 'rels)))
       ob)

   ; --- the relocation table, every machine's: e_machine -> kind -> (width how), how the
   ; field takes S+A at P. RELA: abs whole, pc S+A-P whole, abs32 four bytes in either range,
   ; u32 unsigned, s32 signed, pc32 S+A-P signed; else a backend's instruction field, ored
   ; into the word already there. arm and i386 are REL, each kind pulling its addend out of
   ; the field: w32 w16 w8 S+A, r32 r16 r8 S+A-P. the numbers collide across machines, so
   ; the machine picks the row first
   ld-rtab {62 (ld-cls '((1 8 abs) (10 4 u32) (11 4 s32) (2 4 pc32) (4 4 pc32) (24 8 pc)
                         (18 8 tpoff) (23 4 tpoff32) (22 4 gottpoff)))
            183 (ld-cls '((257 8 abs) (258 4 abs32) (260 8 pc) (261 4 pc32) (273 4 ld19) (274 4 adr21)
                          (275 4 adrp21) (277 4 addlo12) (278 4 addlo12) (279 4 b14) (280 4 b19) (282 4 b26)
                          (283 4 b26) (284 4 lo12s2) (285 4 lo12s4) (286 4 lo12s8) (299 4 lo12s16)
                          (549 4 tphi12) (550 4 tplo12) (551 4 tplo12nc) (553 4 tpst0) (555 4 tpst1)
                          (557 4 tpst2) (559 4 tpst3) (571 4 tpst4) (541 4 gottprel21) (542 4 gottprel12)))
            ; call_plt spans the auipc pair
            243 (ld-cls '((2 8 abs) (57 4 pc32) (17 4 j21) (19 8 pcrel)))
            ; the thumb bit rides in S (st_value's bit 0) and every branch field drops bit 0, so
            ; ((S+A)|T) falls out of S+A; one image may mix cores, so the widest arm32 backend
            40 (ld-cls '((2 4 w32) (3 4 r32) (10 4 bl) (30 4 b) (47 4 movw16) (48 4 movt16) (51 4 bcc)))
            3 (ld-cls '((1 4 w32) (2 4 r32) (4 4 r32) (20 2 w16) (21 2 r16) (22 1 w8) (23 1 r8)))}
   ; a64's thread-pointer kinds -> (how shift): an add's imm12 (hi or lo, the lo checked or
   ; not), a load's scaled imm12, or initial-exec's adrp and ldr from the got
   ld-a64tp {'tphi12 '(hi 12) 'tplo12 '(lo 0) 'tplo12nc '(nc 0) 'tpst0 '(nc 0) 'tpst1 '(nc 1)
             'tpst2 '(nc 2) 'tpst3 '(nc 3) 'tpst4 '(nc 4) 'gottprel21 '(movz 16) 'gottprel12 '(movk 0)}
   ld-tpkinds ('(tpoff tpoff32 gottpoff) + keys ld-a64tp)
   ; machine, kind -> its row, or a scare
   (ld-rk mach kind) (: t (peep ld-rtab mach ()) r (? (t = ()) () (peep t kind ()))
                        (two? r ? r (scare 'link-reloc kind)))
   ; a RELA field: row r, the field's old bytes bs, S+A, P -> its bytes, () out of reach
   (ld-fix be r bs sa p)
    (: k (r 1)
       (? (k == 'abs) (le64 (ld-u64 sa))
          (k == 'pc) (le64 (ld-u64 (sa - p)))
          (k == 'pc32) (: v (s64 (ld-u64 (sa - p))) (fits32 v ? (le32 v)))
          (k == 'abs32) (: v (s64 (ld-u64 sa)) (0 <= v && v <= 4294967295 || fits32 v ? (le32 v)))
          (k == 'u32) (: v (ld-u64 sa) (v <= 4294967295 ? (le32 v)))
          (k == 's32) (: v (s64 (ld-u64 sa)) (fits32 v ? (le32 v)))
          (refix-with be k bs sa p <r)))
   ; a REL field: S+A whole, or less P, or the backend's
   (ld386 s off sv kind site)
    (: r (ld-rk 3 kind) w <r k (r 1)
       sa (sv + rdle s off w)
       v (elem k '(w32 w16 w8) ? sa (sa - site))
       (w @ 4 (le32 (ld-u32 v)) 2 (le16 (ld-u32 v)) [(ld-u32 v & 255)]))
   (ldarm be s off sv kind site)
    (: r (ld-rk 40 kind) k (r 1) sa (sv + rle32 s off)
       (? (k == 'w32) (le32 (ld-u32 sa))
          (k == 'r32) (le32 (ld-u32 (sa - site)))
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
   ld-lanes '(text rodata data nifs bss image note boot tdata tbss)
   ; an allocated progbits or nobits section of another name is its own lane, laid contiguous
   (ld-any nm ty fl) (elem ty '(1 8) && 0 < fl & 2 ? (name nm))
   ; and travels with the known lane its flags name: exec text, write data, nobits bss,
   ; else rodata
   (ld-home lane fl ty)
    (? (elem lane ld-lanes) lane
     (ty = 8) 'bss (0 < fl & 4) 'text (0 < fl & 1) 'data 'rodata)
   ; a section name -> its lane, by prefix (gcc splits a lane: .text.unlikely, .rodata.str1.1)
   (ld-lane nm ty fl)
    (? (0 < fl & 1024) (ty = 8 ? 'tbss 'tdata)        ; shf_tls: the thread template
       (ty = 8) (nm = ".bss" || starts? nm ".bss." ? 'bss (ld-any nm ty fl))
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
    (: r (ld-obj id s 1) sec (r 'sec) shnum (r 'shnum) rty (? (r 'class = 64) 4 9)
       _ (r 'type = 1 && r 'mach = mach ? 0 (scare 'link-machine id))
       secs {} lanes {} drops {}
       ob {'id id 'src s 'lanes lanes 'secs secs 'drops drops 'base {} 'mach mach}
       ; droppable: empty, no shf_alloc, a note, or the unwinder's tables. the index is
       ; recorded so a relocation against it is skipped, not scared at.
       (drop? i ty fl nm sz)
        (sz = 0 || 0 = fl & 2 || ty = 7 || ld-unwind? nm ?
           (pin drops i 1, 1) ())
       ; classify: progbits and nobits onto their lane, symtab/rela by type, the droppable
       ; set dropped; anything else with bytes refuses.
       (class i)
        (shnum <= i ? ()
           (: h (sec i) nm <h ty (h 1) fl (h 2) off (h 3) sz (h 4)
              ; a note with a lane (.note.pvh) is placed like progbits
              (? (elem ty '(1 8) || ty = 7 && ld-lane nm ty fl)
                   ; a nobits section's sh_offset is a placeholder
                   (ld-lane nm ty fl @ lane
                      (? lane (pin secs i [lane (ty = 8 ? 0 off) sz (h 5) (ld-home lane fl ty)],
                               pin lanes lane (i . lanes lane),
                               class (i + 1))
                         ; .comment is dropped but kept: the output's is the union of the inputs'
                         (drop? i ty fl nm sz)
                          (nm = ".comment" ? (pin ob 'comment (snip s off (off + sz))) 0,
                           class (i + 1))
                         (scare 'link-section nm)))
                  (ty = 2 || ty = rty || elem ty '(0 3)) (class (i + 1))
                  (drop? i ty fl nm sz) (class (i + 1))
                  (scare 'link-section nm))))
       _ (class 1)
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
       _ (r 'nsym = 0 ? (scare 'link-no-symtab id))
       _ (pin ob 'syms (r 'syms), pin ob 'nsym (r 'nsym), pin ob 'sec (r 'sec), pin ob 'shnum shnum)
       ; a .rela whose target was dropped goes with it; one neither placed nor dropped scares.
       ; a REL addend arrives () and the patcher pulls it from the field.
       (pin ob 'relas (filter (x \ (? (two? (secs <x)) 1
                                     (drops <x) ()
                                     (scare 'link-rela-target id)))
                              (rev (r 'rels))),
        ob))

   ; every symbol in .symtab of a file of any e_type (`love nm`) -> rows
   ;   (name bind typ shndx value size sec)
   ; sec the defining section's (name type flags), or () for an undefined or reserved index.
   ; a file without .symtab answers ().
   (ld-syms id s)
    (: r (ld-obj id s 0) sec (r 'sec) shnum (r 'shnum) sy (r 'syms)
       (map (i \ (: e (sy i) x (e 3)
                    [<e (e 1) (e 2) x (e 4) (e 5) (0 < x && x < shnum ? [<(sec x) (sec x 1) (sec x 2)])]))
            >^(r 'nsym)))

   ; -- archives. the noms the linker synthesizes, never looked for in a .a. gcc names
   ; _GLOBAL_OFFSET_TABLE_ beside a gottpoff the link relaxes; no got is laid, and a
   ; relocation that would read one refuses by its kind
   ldsynth '("__start_love_nifs" "__stop_love_nifs" "__start_love_rela" "__stop_love_rela"
             "__data_start__" "__data_end__" "__data_load__"
             "__bss_start__" "__bss_end__" "__load_size__" "_GLOBAL_OFFSET_TABLE_")
   (dusyms id bs mach)                     ; (id bytes) -> (defs strong-undefs tls?), global noms
    (: ob (ld-read id bs mach) sy9 (peep ob 'syms 0)
       (go i ds us)
        (peep ob 'nsym 0 <= i ? [ds us (ld-tls? [ob])]
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
   ; a member's defined globals in symbol-table order; a non-ELF member defines nothing
   (ld-ardefs f b) (ld-arelf? b ? (rev <(dusyms f b (b 18 + 256 * b 19))))
   (arbytes ms) (arlay 0 1 ms)
   ; ..any shape: thin keeps only each member's header, its name (a path from the archive's
   ; directory) in "//" however short, as llvm-ar lays one; ix 0 leaves the index out
   (arlay thin ix ms)
    (: names (map cap ms)
       datas (map caup ms)
       ; the long-name table: parallel to names, each entry (offset) | ()
       lofs (: (go l off acc) (atom? l ? (rev acc)
                                 (#<l @ ln
                                    (ln < 16 && !thin ? (go >l off (() . acc))
                                       (go >l (off + ln + 2) ([off] . acc)))))
               (go names 0 ()))
       ; padded to even inside its own size, as GNU and llvm-ar count it
       ltab (ld-arpad (: (go ns ls) (atom? ns ? ""
                                       (two? <ls ? (<ns + "/\n" + go >ns >ls) (go >ns >ls)))
                         (go names lofs)))
       syml (map (m \ ix ? (ld-ardefs <m <>m) ()) ms)
       nsym (foldl (+) 0 (map tally syml))
       strt (foldl (+) "" (map (ss \ foldl (a \ s \ a + s + string 0) "" ss) syml))
       ; the index pads to even with a NUL counted in its size, as GNU does
       isz (4 + 4 * nsym + #strt @ z (z + (z & 1)))
       ; member header offsets: magic, index hdr + data (when any), "//" (when any), then each
       m0 (ix ? (8 + 60 + isz) 8)
       m1 (#ltab ? (m0 + 60 + #ltab) m0)
       offs (: (go ds off acc) (atom? ds ? (rev acc)
                                (go >ds (off + 60 + (thin ? 0 (#<ds @ z (z + (z & 1))))) (off . acc)))
               (go datas m1 ()))
       idx (: raw ((ld-arb4 nsym
                    + (: (go os ss) (atom? os ? ""
                                       (foldl (\ a _ (a + ld-arb4 <os)) "" <ss + go >os >ss))
                         (go offs syml)))
                   + strt)
              (#raw & 1 ? (raw + string 0) raw))
       body (: (go ns ls ds) (atom? ns ? ""
                                (: nf (two? <ls ? ("/" + show <<ls) (<ns + "/"))
                                 (ld-arhdr nf "0" "0" "0" "644" #<ds + (thin ? "" (ld-arpad <ds)) + go >ns >ls >ds)))
               (go names lofs datas))
       (((thin ? "!<thin>\n" "!<arch>\n") + (ix ? (ld-arhdr "/" "0" "0" "0" "0" isz + idx) "")
         + (#ltab ? (ld-arhdr "//" "" "" "" "" #ltab + ltab) ""))
        + body))
   ; a set of objects -> (dt owed tls?): dt every nom defined or synthesized, a tablet the
   ; caller pins into; owed the strong undefineds left; tls? whether one carries a thread
   ; template. __start_X/__stop_X are ldres's to answer.
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
                   () duos)
         (any (du \ du 2) duos)]))
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
   ; the set's thread template: any tdata or tbss section, and the widest alignment among them
   (ld-tls? objs) (any (ob \ two? (peep (peep ob 'lanes 0) 'tdata ()) || two? (peep (peep ob 'lanes 0) 'tbss ())) objs)
   (ld-tlsalign objs)
    (foldl (\ a ob (foldl (\ b i ((peep (peep ob 'secs 0) i ()) 3 @ x (x > b ? x b)))
                          a (peep (peep ob 'lanes 0) 'tdata () + peep (peep ob 'lanes 0) 'tbss ())))
           1 objs)

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

   ; one a64 field: (how sh), the section's bytes s, the word's offset o, v = S + A - tp -> its
   ; four bytes. the got's adrp and ldr relax, as ld does, to movz and movk of v, the ldr's
   ; base its own target
   (ld-a64tls [how sh] s o v nm)
    (: wd (+(map (i \ (s (o + i)) << (8 * i)) ^4))
       rd (wd & 31)
       _ (0 <= v < (? (how == 'hi) 16777216 (how == 'lo) 4096 4294967296) ? 0 (scare 'link-range nm))
       _ (how == 'nc && (v % (1 << sh)) != 0 ? (scare 'link-tls-align nm))
       _ (how == 'movz && (wd & 2667577344) != 2415919104 ? (scare 'link-tls-gottprel nm))
       _ (how == 'movk && ((wd & 4290772992) != 4181721088 || ((wd >> 5) & 31) != rd) ? (scare 'link-tls-gottprel nm))
       (le32 (? (how == 'movz) (3533701120 | (((v >> 16) & 65535) << 5) | rd)
                (how == 'movk) (4068474880 | ((v & 65535) << 5) | rd)
                ((wd & 4290774015) | (((v >> sh) & 4095) << 10)))))

   ; patch one object's one section: its bytes as text snips + byte lists, each relocation's
   ; field spliced in. entries must ascend by offset. cx: (glo n0 n1 r0 r1 relbox rv arm? be
   ; xt tp), the symbol book, the brackets, the -pie/-shared site box, the riscv flag, the arm
   ; flag ('i386 for EM_386), the backend fields re-encode through, the named-lane extents,
   ; the thread pointer's address beside the template (x64's variant II ends the block at it,
   ; a64's variant I starts it a control block past), () where the link lays no tls.
   ; kind numbers collide across machines (R_RISCV_64 is R_X86_64_PC32), so dispatch is by machine.
   (ldpatch ob ix base [glo n0 n1 r0 r1 relbox rv arm? be xt tp])
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
                 (: w <(ld-rk 3 kind)
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
                    row (ld-rk (peep ob 'mach 0) kind) w <row k (row 1)
                    abs64? (k == 'abs)
                    abs32? (elem k '(abs32 u32 s32))
                    ; the thread-pointer kinds: S + A from tp
                    _ (elem k ld-tpkinds && !(charm? tp) ? (scare 'link-tls <sy))
                    ; GOTTPOFF's mov or add from the got, relaxed as ld does to the same op on an
                    ; immediate: the three bytes ahead of the field rewritten
                    gx (? (k == 'gottpoff)
                          (: o (off0 + ro) rx (s (o - 3)) op (s (o - 2)) md (s (o - 1))
                             (pos <= o - 3 && elem rx '(72 76) && (md & 199) = 5 && elem op '(139 3) ?
                              [(rx = 76 ? 73 72) (op = 139 ? 199 129) (192 | ((md >> 3) & 7))]
                              (scare 'link-tls-gottpoff <sy))))
                    ax (peep ld-a64tp k () @ f (two? f ? (ld-a64tls f s (off0 + ro) (s64 (ld-u64 (sa - tp))) <sy)))
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
                    ; ..nor a site in .rodata, which the startup cannot write: a -fno-pie object's
                    ; const that holds an address
                    _ (relbox && abs64? && se 4 = 'rodata ? (scare 'link-rodata-pie <sy))
                    _ (ro + w <= sz ? 0 (scare 'link-oob (peep ob 'id 0)))
                    bs (? (two? ax) ax
                          (k == 'tpoff) (le64 (ld-u64 (sa - tp)))
                          ; GOTTPOFF's addend is the -4 of its rip-relative field, gone with the got
                          (elem k '(tpoff32 gottpoff))
                           (: v (s64 (ld-u64 ((k == 'gottpoff ? sv sa) - tp)))
                              (fits32 v ? 0 (scare 'link-range <sy),
                               le32 (ld-u32 v)))
                          (: r (ld-fix be row (map (i \ s (off0 + ro + i)) ^w) sa (base + ro))
                             (two? r ? r (scare 'link-range <sy))))
                    (go (off0 + ro + w) >es
                        (? (two? gx) (bs . gx . snip s pos (off0 + ro - 3) . acc)
                           (bs . snip s pos (off0 + ro) . acc)))))))
       (go off0 (ent (ob 'relas)) ()))

   ; emit one lane in layout order, zero-padding up to each base -> (end . pieces)
   (ldemit cx lane cur os acc)
    (? (#cx != 11) (scare 'link-cx #cx)          ; a short cx misses ldpatch's pattern: () in silence
       (atom? os) (cur . acc)
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
   (ld-nabs objs)
    (foldl (\ a ob (: t (peep ld-rtab (peep ob 'mach 0) {})
                      (foldl (\ a2 tr (foldl (\ a3 e (peep t (e 1) () @ r (two? r && r 1 == 'abs ? (a3 + 1) a3))) a2 >tr))
                             a (peep ob 'relas ()))))
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
                    (? (elem ty kl-skip || 0 < (fl & 2147483648) || peep (peep ob 'drops {}) si 0) 0
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
       (string? e) (? (e = ".") (env 'dot)
                      (e = "SIZEOF_HEADERS") (: h (peep env 'hdrs ()) (? (whole? h) h (scare 'klink-headers e)))
                      (kl-sym env e))
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
   ; SECTIONS inline; f folded over every command, an output section as ('hdr t) then its body
   (kl-flat cmds) (foldr (\ c acc (? (<c = 'sections) (<>c + acc) (c . acc))) () cmds)
   (kl-walk f l acc) (foldl (\ a c (? (<c = 'osec) (: t <>c (kl-walk f (t 'body) (f ['hdr t] a))) (f c a))) acc l)
   ; the symbol names an expression reads, onto acc
   (kl-reads e acc)
    (? (string? e) (? (e = "." || e = "SIZEOF_HEADERS") acc (e . acc))
       (atom? e) acc
       (<e = 'call) (? (elem (e 1) '("ADDR" "SIZEOF" "LOADADDR" "ALIGNOF" "DEFINED" "CONSTANT" "SEGMENT_START")) acc
                       (foldl (\ a x (kl-reads x a)) acc (e 2)))
       (foldl (\ a x (kl-reads x a)) acc >e))
   ; the names a command reads, a PROVIDE's aside
   (kl-creads c a) (? (<c = 'set) (kl-reads (c 3) a) (<c = 'assert) (kl-reads (c 1) a) (<c = 'data) (kl-reads (c 2) a)
                      (<c = 'hdr) (: t (c 1) (kl-reads (t 'align) (kl-reads (t 'lma) (kl-reads (t 'addr) a))))
                      a)
   ; the PROVIDEs the link takes -> name -> 1: a name no object defines, which one leaves
   ; undefined, the script reads outside a PROVIDE, or a taken PROVIDE reads
   (kl-taken cx cmds)
    (: und (cx 'und) glob (cx 'glob) flat (kl-flat cmds)
       ref (: t {} _ (each (kl-walk kl-creads flat ()) (n \ pin t n 1)) t)
       ps (kl-walk (\ c a (? (<c = 'provide) (c . a) a)) flat ())
       tk {}
       (want? nm) (!(peep tk nm 0) && !(two? (peep glob nm ())) && (peep und nm 0 > 0 || peep ref nm 0))
       (go u)
        (: n (foldl (\ k c (? (want? (c 1))
                              (: _ (pin tk (c 1) 1) _ (each (kl-reads (c 2) ()) (x \ pin ref x 1)) (k + 1))
                              k))
                    0 ps)
           (? (n > 0) (go 0) tk))
       (go 0))

   ;; --- layout: the script's commands in order, SECTIONS inline, in passes until every
   ;     address holds still; the ASSERTs are checked on the last. synth [(name size align
   ;     type flags [entsize ghost]) ..], a ghost lending its flags and align but keeping no
   ;     section, as lld's empty .got and .plt do. answers the env: 'sv 'osv 'isa isec key ->
   ;     address, 'msa merge id -> address; each output section tablet gains 'dead, or 'va
   ;     'sz 'la 'al 'flags 'stype
   (kl-lay cx cmds mx synth)
    (: ot (: t {} _ (foldl (\ i ob (pin t i ob, i + 1)) 0 (cx 'objs)) t)
       glob (cx 'glob) und (cx 'und) ms (mx 'ms) im (mx 'im)
       sy (: t {} _ (each synth (s \ pin t <s s)) t)
       flat (kl-flat cmds)
       tk (kl-taken cx cmds)
       phr (foldl (\ a c (? (<c = 'phdrs) <>c a)) () cmds)
       named (foldl (\ a c (? (<c = 'osec)
                              (: t <>c (kl-named [(t 'addr) (t 'lma) (t 'align) (t 'body)] a))
                              (kl-named c a)))
                    () flat)
       (mflags x) (? (<x = 'isec) (ot (x 1) 'sec (x 2) 2) (<x = 'synth) (sy (x 1) 4)
                     (<x = 'msec) (ms (x 1) 'flags) -1)
       (mtype x) (? (<x = 'isec) (ot (x 1) 'sec (x 2) 1) (<x = 'synth) (sy (x 1) 3) (ms (x 1) 'type))
       (malign x) (? (<x = 'isec) (x 4) (<x = 'synth) (x 3) (ms (x 1) 'align))
       (ments x) (? (<x = 'isec) (ot (x 1) 'sec (x 2) 6)
                    (<x = 'synth) (: s (sy (x 1)) y (s 3) (? (whole? (s 5)) (s 5) (y = 4) 24 (y = 19) 8 0))
                    (ms (x 1) 'entsize))
       (ghost? x) (<x = 'synth && sy (x 1) 6 = 1)
       (held? b) ((<b = 'set && b 1 != ".") || <b = 'data)
       osof {} mof {}                                 ; isec key, merge id -> output section
       _ (foldl (\ pf c
                  (? (<c != 'osec) pf
                     (: t <>c mem (filter (x \ mflags x >= 0) (t 'steps))
                        (? (t 'name = "/DISCARD/"
                            || (all ghost? mem && !(elem (t 'name) named) && !(any held? (t 'body))))
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
       env {'dot 0 'sv {} 'osv {} 'isa {} 'msa {} 'undef 0 'osof osof 'mof mof 'ssec {} 'stype {} 'cur ()
            'hdrs (? (two? phr) (64 + 56 * #phr) ())}
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
        (? (whole? (peep sv nom ())) (: q (peep ssec nom ()) (? (rel? q) q ()))
           (: g (peep glob nom ()) (? (two? g) (osec-of <g (ot <g 'syms (g 1) 3)) ())))
       ; the aether: before any output section, where lld counts . relative to the first
       (rel? x) (string? x || x = 'aether)
       (secof e)
        (? (whole? e) ()
           (string? e) (? (e = ".") (? (string? (env 'cur)) (env 'cur) 'aether) (symsec e))
           (: o <e (a u) (secof (e 1)) (b u) (secof (e 2))
              (? (o = '+ || o = '& || o = '|) (: x (a 0) (? (rel? x) x (b 0)))
                 (o = '-) (: x (a 0) (? (rel? x && !(rel? (b 0))) x ()))
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
              (k = 'provide) (? (peep tk (c 1) 0) (setsym (c 1) (ev (c 2)) (c 2)) 0)
              (k = 'assert) (? (final && ev (c 1) = 0) (scare 'klink-assert (c 2)) 0)
              (k = 'data) (setdot (dot 0 + c 1))
              (k = 'osec) (? (peep <>c 'dead 0) 0 (lay final <>c))
              0))
       (step final x)
        (: k <x
           (? (k = 'isec) (: a (kl-al (dot 0) (x 4)) _ (pin isa (x 1 * 65536 + x 2) a) (setdot (a + x 3)))
              (k = 'synth) (? (ghost? x) 0 (: a (kl-al (dot 0) (x 3)) _ (pin isa (x 1) a) (setdot (a + sy (x 1) 1))))
              (k = 'msec) (: m (ms (x 1)) a (kl-al (dot 0) (m 'align)) _ (pin msa (x 1) a)
                             (setdot (a + m 'size)))
              (cmd final x)))
       (lay final t)
        (: alloc (0 < (t 'flags & 2)) saved (dot 0)
           _ (pin env 'cur (t 'name))
           ; an address given is taken as it stands, its alignment ignored, as lld takes it
           at? (two? (t 'addr) || whole? (t 'addr) || string? (t 'addr))
           _ (setdot (? at? (ev (t 'addr)) alloc (dot 0) 0))
           al (max (t 'malign) (? (atom? (t 'align)) (? (whole? (t 'align)) (t 'align) 1) (ev (t 'align))))
           a (? at? (dot 0) (kl-al (dot 0) al))
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
       ; a pass that read nothing before it was set is where the passes would settle
       asserts (kl-walk (\ c a (? (<c = 'assert) (c . a) a)) flat ())
       (? (atom? asserts && (: _ (pass 1) (env 'undef = 0))) env (go 0 ())))

   ; the static image's default script, link.l's layout said as one: each lane an output
   ; section at the address reached, so none is lifted to its widest input; a cut lifts the
   ; address a page, the file offset running on. read once; a link sets the __ld_ words
   ld-dtmpl (lds-read """
     SECTIONS {
     . = __ld_start;
     .text . : { *(.text .text.*) }
     __t1 = .;
     . = ALIGN(__ld_cut) + (. & (__ld_cut - 1));
     __o0 = .;
     .rodata . : { *(.rodata .rodata.*) }
     __o1 = .;
     . = ALIGN(__ld_cut) + (. & (__ld_cut - 1));
     __d0 = .;
     .data . : { *(.data .data.*) }
     . = ALIGN(16);
     __n0 = .;
     .love.nifs . : { *(love_nifs) }
     __end = .;
     . = ALIGN(__ld_tal);
     __tl0 = .;
     .tdata . : { *(.tdata .tdata.*) }
     .tbss . : { *(.tbss .tbss.*) }
     __tl1 = .;
     . = ALIGN(__ld_ra);
     __r0 = .;
     . = . + __ld_rsz;
     . = ALIGN(16);
     __dend = .;
     .bss . : { *(.bss .bss.*) }
     __bend = .;
     . = ALIGN(__ld_pg) + ((__dend - __ld_base) & (__ld_pg - 1));
     __ia = .;
     .love.image . : { *(.love.image) }
     __ie = .;
     }
     """)
   ; -> the commands for one link: its words, then a template's output sections afresh,
   ; each lane's named lanes inside it after it, first-seen
   ld-dhome {".text" 'text ".rodata" 'rodata ".data" 'data ".bss" 'bss}
   (ld-tscript objs words tmpl)
    (: (osec t) (: n {} _ (each (keys t) (k \ pin n k (t k)))
                   h (peep ld-dhome (t 'name) 0)
                   _ (? (h != 0) (pin n 'body (t 'body + map (l \ ['in 0 "*" [['none (show l)]]]) (ld-nlanes objs h))) 0)
                   n)
       (item c) (<c = 'osec ? ['osec (osec <>c)] c)
       (map (p \ ['set <p '= <>p]) words
        + map (c \ (<c = 'sections ? ['sections (map item <>c)] c)) tmpl))
   (ld-dscript objs base hdrsz pg wx? pie nrel tal)
    (ld-tscript objs [["__ld_start" (base + hdrsz)] ["__ld_cut" (wx? ? pg 1)] ["__ld_tal" tal]
                      ["__ld_ra" (pie ? 16 1)] ["__ld_rsz" (8 * nrel)] ["__ld_pg" pg] ["__ld_base" base]]
       ld-dtmpl)
   ; lay the set by a script: each placed section's address pinned in its object's 'base,
   ; each in the output section `want` names for it, or a scare -> the script's symbols
   ld-lanesec {'text ".text" 'rodata ".rodata" 'data ".data" 'nifs ".love.nifs" 'tdata ".tdata"
               'tbss ".tbss" 'bss ".bss" 'image ".love.image"}
   (ld-homesec se) (peep ld-lanesec (se 4) ())
   (ld-kernsec se) (peep ld-lanesec (se 4) () || peep {'note ".note.pvh" 'boot ".boot"} (se 4) ())

   ; the bare-metal kernel's default script: the PVH note in the header page, then boot, text,
   ; rodata and data each on its own page, nifs, image and bss running on from data
   ld-ktmpl (lds-read """
     SECTIONS {
     . = __ld_vbase;
     .note.pvh . : { *(.note.pvh) }
     . = ALIGN(4096);
     __b0 = .;
     .boot . : { *(.boot .boot.text) }
     __b1 = .;
     . = ALIGN(4096);
     __t0 = .;
     .text . : { *(.text .text.*) }
     __t1 = .;
     . = ALIGN(4096);
     __o0 = .;
     .rodata . : { *(.rodata .rodata.*) }
     __o1 = .;
     . = ALIGN(4096);
     __d0 = .;
     .data . : { *(.data .data.*) }
     . = ALIGN(16);
     __n0 = .;
     .love.nifs . : { *(love_nifs) }
     __n1 = .;
     .love.image . : { *(.love.image) }
     __i1 = .;
     .bss . : { *(.bss .bss.*) }
     __kend = .;
     }
     """)
   (ld-script objs cmds want)
    (: _ (kl-place objs cmds () 0)
       env (kl-lay {'objs objs 'glob {} 'und {}} cmds {'ms {} 'im {}} ())
       isa (env 'isa) osof (env 'osof)
       _ (foldl (\ oi ob
                  (: secs (ob 'secs) bs (ob 'base)
                     _ (each (keys secs)
                          (i \ (: se (secs i) k (oi * 65536 + i) w (want se)
                                  (? (!(string? w)) 0
                                     (peep osof k () = w) (pin bs i (isa k))
                                     (scare 'link-script-lane [(ob 'id) (ob 'sec i 0)])))))
                     (oi + 1)))
                0 objs)
       (env 'sv))
   (ldlink target pie org srcs prod readme)
    (: mach (peep elf-machines target 0)
       _ (0 < mach ? 0 (scare 'link-target target))
       objs (map (p \ ld-read <p <>p mach) srcs)
       rv (mach = 243)
       ; a thread template (x64 and a64): .tdata then .tbss as file zeros, past the nifs, a pt_tls
       tls? (ld-tls? objs)
       _ (tls? && !(elem mach '(62 183)) ? (scare 'link-tls target))
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
       hdrsz ((w32 ? 52 64) + (w32 ? 32 56) * ((wx? ? 3 1) + (img? ? 1 0) + (nb? ? 1 0) + (tls? ? 1 0)) + (nb? ? 24 0))
       nbo (hdrsz - 24)
       nbnote (nb? ? (catall [(le32 7) (le32 4) (le32 1)                 ; namesz descsz netbsd_tag
                              '(78 101 116 66 83 68 0 0) (le32 1000000000)]))   ; "NetBSD\0\0", 10.0
                  
       nrel (pie ? (ld-nabs objs) 0)
       tal (ld-tlsalign objs)
       sv (ld-script objs (ld-dscript objs base hdrsz pg wx? pie nrel tal) ld-homesec)
       end (sv "__end") n0 (sv "__n0") o0 (sv "__o0") d0 (sv "__d0") t1 (sv "__t1") o1 (sv "__o1")
       ; the address the cuts skipped, which the file does not carry: from d0 on an offset is
       ; `addr - base - sk`, o0's is `t1 - base`
       sk ((o0 - t1) + (d0 - o1))
       ; the template, a symbol's offset its address less tp: x64's thread pointer is the
       ; block's end on its alignment, a64's lies a 16-byte control block (aligned) before it
       tl0 (sv "__tl0") tl1 (sv "__tl1")
       tp (tls? ? (mach = 183 ? (tl0 - ld-align tal 16) (tl0 + ld-align tal (tl1 - tl0))))
       r0 (sv "__r0")
       r1 (r0 + 8 * nrel)
       ; the file bytes end on 16, for .bss and .image; the slack is outside .love.rela, where
       ; the relocator would read a zero as a site
       dend (sv "__dend")
       ; .bss: p_memsz runs to bend, p_filesz stops at dend
       bend (sv "__bend")
       ; .image last, past .bss, so `love bake` can grow it at the file's tail; its own segment,
       ; or the .bss gap would be file zeros. no .image section, no segment.
       ioff (dend - base - sk)
       iaddr (img? ? (sv "__ia") dend)
       iend (img? ? (sv "__ie") dend)
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
       cx [glo n0 end r0 r1 relbox rv (ld-rel32 mach) (backends target) (ld-extents objs) tp]
       et (ldemitn cx 'text objs (ldemit cx 'text (base + hdrsz) objs ()))
       eo (ldemitn cx 'rodata objs (ldemit cx 'rodata o0 objs >et))
       ed (ldemitn cx 'data objs (ldemit cx 'data d0 objs >eo))
       en (ldemit cx 'nifs <ed objs >ed)
       etd (ldemit cx 'tdata <en objs >en)
       tbz (<etd < tl1 ? [(ld-zeros (tl1 - <etd))])
       tail (tl1 < r0 ? [(ld-zeros (r0 - tl1))])
       rtab ((pie ? (catall (map le64 (rev (peep relbox 0 ()))))) + ld-zeros (dend - r1))
       ei (img? ? (ldemit cx 'image iaddr objs ()) [iaddr])
       ; -- the section headers and symbol table, past p_filesz. every loaded byte has a
       ; covering section, as strip rebuilds a file from its sections. --
       lanesx {'text 1 'rodata 2 'data 3 'nifs 4 'bss 6 'image 7}
       st (ldstab objs glo lanesx (w32 ? elf-sym32 elf-sym) (w32 ? 16 24))
       ; e_shstrndx and .symtab's sh_link are fixed at 10 and 9, so new sections go last.
       ; an object says love_nifs, a C identifier, so GNU ld synthesizes its brackets; the
       ; binary may say .love.nifs, ldres defining the pair itself.
       shstr (o-strtab ('(".text" ".rodata" ".data" ".love.nifs" ".love.rela" ".bss" ".love.image"
                          ".symtab" ".strtab" ".shstrtab" ".comment" ".love.README" ".note.netbsd.ident")
                        + (tls? ? '(".tdata"))))
       (snm k) (<>shstr k)
       symo (ld-align 8 endf) symz #<st
       stro (symo + symz) strz #<>st
       ssto (stro + strz) sstz #<shstr
       cmt (ld-comment objs prod) cmto (ssto + sstz) cmtz #cmt
       rdm (string? readme ? (o-strbytes readme))
       rdmo (cmto + cmtz) rdmz #rdm
       nsh ((0 < rdmz ? 13 12) + ?nb? + ?tls?)
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
                    (nb? ? (shf (snm 12) 7 2 (base + nbo) nbo 24 0 0 4 0))     ; sht_note, alloc: strip keeps it
                    (tls? ? (shf (snm 13) 1 1027 tl0 (tl0 - base - sk) (tl1 - tl0) 0 0 tal 0))])   ; alloc|write|tls
       ; w^x: headers + code r-x; literals r; .data through love_rela, bss in memsz, rw; the
       ; image rw. no page is in two segments, and the file pays no padding: offsets run on
       ; while addresses skip. sound only while no relocation lands in text or rodata.
       ; .image ends its segment with no load above it, as bake_tail requires.
       phs ((wx? ? [(phf 1 5 0 base base (t1 - base) (t1 - base) pg)
                    (phf 1 4 (t1 - base) o0 o0 (o1 - o0) (o1 - o0) pg)
                    (phf 1 6 (d0 - base - sk) d0 d0 (dend - d0) (bend - d0) pg)]
                 [(phf 1 7 0 base base (dend - base) (bend - base) pg)])
            + (img? ? [(phf 1 6 isho ist ist iszr iszr pg)])
            + (nb? ? [(phf 4 4 nbo (base + nbo) (base + nbo) 24 24 4)])
            + (tls? ? [(phf 7 4 (tl0 - base - sk) tl0 tl0 (tl1 - tl0) (tl1 - tl0) tal)]))
       hdr (w32 ? (elf32-hdrn 2 ent mach (arm-eflags target) [shto nsh 10] phs) (elf64-hdrn (pie ? 3 2) ent mach [shto nsh 10] phs))
       ; ei_osabi = 9 (freebsd) in e_ident[7]: freebsd refuses an unbranded exe, linux ignores it
       hdr9 (bsd? ? (ld-brand hdr 7 9) hdr)
       (hdr9 . ((nb? ? [nbnote]) + >etd + tbz + tail + [rtab] + >ei
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
       _ (ld-tls? objs0 ? (scare 'link-tls target))   ; a thread template is ldlink's alone
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
       nrel (ld-nabs objs)
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
       cx [glo n0 end dy0 dy0 relbox () () (backends target) (ld-extents objs) ()]
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
       _ (ld-tls? objs ? (scare 'link-tls target))   ; a thread template is ldlink's alone
       (lsz lane) (foldl (\ a ob (a + ld-lanesz ob lane)) 0 objs)
       sv (ld-script objs (ld-tscript objs [["__ld_vbase" vbase]] ld-ktmpl) ld-kernsec)
       b0 (sv "__b0") b1 (sv "__b1") t0 (sv "__t0") t1 (sv "__t1") o0 (sv "__o0") o1 (sv "__o1")
       d0 (sv "__d0") n0 (sv "__n0") n1 (sv "__n1") i1 (sv "__i1") kend (sv "__kend")
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
       cx [glo n0 n1 n1 n1 () (mach = 243) () (backends target) (ld-extents objs) ()]
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
   ; the map said as a script: each run from its address, each lane an output section of
   ; its inputs between __lb and __le words, a known lane's by its patterns, a named one's by name
   ld-lanepats {'text [".text" ".text.*"] 'rodata [".rodata" ".rodata.*"] 'data [".data" ".data.*"]
                'nifs ["love_nifs"] 'bss [".bss" ".bss.*"] 'image [".love.image"]}
   (ld-bscript lruns)
    (: (w nm v) ['set nm '= v]
       (lane a l) (: nm (ld-lanenm l)
                     (a + [(w ("__lb" + nm) ".")
                           ['osec {'phdrs () 'name nm 'addr "."
                                   'body [['in 0 "*" (map (p \ ['none p]) (peep ld-lanepats l [nm]))]]}]
                           (w ("__le" + nm) ".")]))
       [['sections (foldl (\ a r (foldl lane (a + [(w "." (r 1))]) (ld-runlanes r))) () lruns)]])
   (ld-lanesecof se) (ld-lanenm <se)
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
       _ (ld-tls? objs ? (scare 'link-tls target))   ; a thread template is ldlink's alone
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
       ; -- the map laid as a script, then read in its order; lpos records each lane's
       ; (vaddr fileoff size). -> per run: (kind vaddr fileoff filesz memsz lanes flags)
       sv (ld-script objs (ld-bscript lruns) ld-lanesecof)
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
                      w (foldl (\ a l (: f <>a nm (ld-lanenm l)
                                         c (sv ("__lb" + nm)) n (sv ("__le" + nm))
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
       cx [glo n0 (<nif + nif 2) org org relbox () (ld-rel32 mach) be (ld-extents objs) ()]
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
