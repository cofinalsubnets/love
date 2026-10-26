; src/love/holo/obj.l -- a relocatable elf object emitter: sections, a symbol table, and a
; relocation for every reference the assembler cannot resolve within its section. elf64 for
; x64/a64/rv64, elf32 for the thumb backends and i386. loads after src/love/holo/elf.l.
(module 'holo
(:
   ; the ELF relocation types emitted, x86-64
   r-64    1                                        ; R_X86_64_64     S + A   (an abs64 data pointer)
   r-pc32  2                                        ; R_X86_64_PC32   S + A - P (an la into .data)
   r-plt32 4                                        ; R_X86_64_PLT32  L + A - P (a call to an external fn)
   r-pc64  24                                       ; R_X86_64_PC64   S + A - P in eight bytes (a jump table's `key - .`)
   r-32    10                                       ; R_X86_64_32     S + A in 4 bytes (the PVH note's entry)
   r-32s   11                                       ; R_X86_64_32S    S + A, sign-extended (pushq $sym)
   ; ... a64: a field reloc patches bits of an instruction word; the placeholder carries
   ; the base opcode (the fixup's aux).
   ra-abs64  257                                    ; R_AARCH64_ABS64           S + A
   ra-abs32  258                                    ; R_AARCH64_ABS32           S + A in four bytes (the image header's `.long sym`)
   ra-jump26 282                                    ; R_AARCH64_JUMP26          (S+A-P)>>2 into b's imm26
   ra-call26 283                                    ; R_AARCH64_CALL26          ... into bl's imm26
   ra-condbr19 280                                  ; R_AARCH64_CONDBR19        ... into b.cond's or cbz's imm19
   ra-ldlo19 273                                    ; R_AARCH64_LD_PREL_LO19    ... into a literal load's imm19
   ra-tstbr14 279                                   ; R_AARCH64_TSTBR14         ... into tbz's imm14
   ra-ldst {'lo12s1 278 'lo12s2 284 'lo12s4 285 'lo12s8 286 'lo12s16 299}   ; R_AARCH64_LDST{8..128}_ABS_LO12_NC
   ra-prel64 260                                    ; R_AARCH64_PREL64          S + A - P in eight bytes (the jump table's key)
   ra-prel32 261                                    ; R_AARCH64_PREL32          S + A - P in four bytes (a jump table's entry)
   ra-pghi21 275                                    ; R_AARCH64_ADR_PREL_PG_HI21  page(S+A)-page(P) into adrp
   ra-adrlo21 274                                   ; R_AARCH64_ADR_PREL_LO21   S+A-P into adr
   ra-lo12   277                                    ; R_AARCH64_ADD_ABS_LO12_NC   (S+A) & 0xfff into add
   ; ... rv64: the 8-byte 'pcrel fixup across an auipc pair maps onto call_plt, for call and
   ; la alike, as jalr/addi/ld share the I-form imm field.
   rr-64    2                                       ; r_rv64_64        S + A  (collides with R_X86_64_PC32: link.l dispatches by machine)
   rr-pc32  57                                      ; R_RISCV_32_PCREL  S + A - P in four bytes (a jump table's entry)
   rr-jal   17                                      ; R_RISCV_JAL       S + A - P into jal's j-imm
   rr-call  19                                      ; R_RISCV_CALL_PLT  S + A - P across the auipc pair

   (o-has? tab k) (peep tab k 'no !== 'no)
   ; a lane's file size; an item may be a blob of many bytes
   (o-blen l) (:- (go l 0) (go l n) (!(two? l) ? n (go >l (n + item-len <l))))
   ; data sections' st_size per name: the raw bytes after a run of labels, up to the next align
   ; or label. gen lays each global as align, labels, raw; any other form leaves its labels unsized
   (o-dsizes secs)
    (: t {}
       (key x) (string? x ? x (show x))
       (close cur n) (n > 0 ? (map (x \ pin t (key x) n) cur) 0)
       (go l cur n)
        (? !(two? l) (close cur n)
           (<l @ f
              (<f @ 'label (n > 0 ? (close cur n, go >l [<>f] 0) (go >l (<>f . cur) n))
                    'align (close cur n, go >l () 0)
                    'raw (go >l cur (n + o-blen <>f))
                    (go >l () 0))))
       _ (map (s \ (0 < s 2 & 4 ? 0 (go (s 4) () 0))) secs)
       t)
   (o-strbytes s) (: (go i acc) (i < 0 ? acc (go (i - 1) (s i . acc)))
                     (go (#s - 1) ()))

   ; an assembled section's items -> (bytes relocs). a fixup resolves in place only when
   ; internal? and its kind is in rset, the kinds a section move leaves valid (an adrp page
   ; delta is not). otherwise it is a record (off kind label aux prevbyte) over placeholder
   ; bytes: zeros where RELA overwrites the field, the base word where a reloc patches bits.
   (o-walk be items labels wkset internal? rset)
    (any fix? items ? (o-walkr be items labels wkset internal? rset 0 () ())
       [items ()])
   (o-walkr be items labels wkset internal? rset off bacc racc)
    (!(two? items) ? [(rev bacc) (rev racc)]
       (<items @ x
          (fix? x ?
              (: lbl (fix-l x) w (fix-w x) k (fix-k x)
                 (internal? && elem k rset &&
                  o-has? labels lbl && !(o-has? wkset lbl) ?
                     (: tgt (peep labels lbl 0)
                        bs (patch-with be k tgt off w (fix-a x))
                        (o-walkr be >items labels wkset internal? rset (off + w)
                                 (rev bs + bacc) racc))
                    (: fill (? (elem k a64-afixk) (le32 (afix-w (fix-a x)))
                               (elem k '(b26 b19 b14 j21)) (le32 (fix-a x))
                               ; riscv 'pcrel: aux packs both base words, auipc low, the I-insn high
                               (k == 'pcrel) (le32 (fix-a x % 4294967296) + le32 (fix-a x // 4294967296))
                               ; arm is REL: a thumb branch holds its encoding with the -4 addend
                               ; baked in (the field counts from instr+4, the reloc's P from instr)
                               (elem k '(b bcc bl)) (patch-with be k off off w (fix-a x))
                               ; movw16/movt16 (thumb2 la): zero imm16 here, bakemw fills it
                               (elem k '(movw16 movt16)) (patch-with be k 0 off w (fix-a x))
                               (o-zeros w))
                       ; carry the byte before the field, the x64 opcode that tells a call
                       ; (PLT32) from an address-of (PC32); a blob head is a string, so 0
                       (o-walkr be >items labels wkset internal? rset (off + w)
                                (rev fill + bacc)
                                ([off k lbl (fix-a x) (two? bacc && charm? <bacc ? <bacc 0)] . racc)))))
             (o-walkr be >items labels wkset internal? rset (off + item-len x) (x . bacc) racc))))
   (o-zeros n) (n >= 1 ? (0 . o-zeros (n - 1)))
   (o-take l n) (two? l && n >= 1 ? (<l . o-take >l (n - 1)))
   (o-drop l n) (n < 1 || atom? l ? l (o-drop >l (n - 1)))
   ; splice pre-encoded bytes in at off
   (o-putbs bytes off bs) (catall [(o-take bytes off) bs (o-drop bytes (off + #bs))])
   (o-put32 bytes off val) (o-putbs bytes off (le32 val))

   ; a lane is one laid section: (name type flags align bytes relocs labels).
   ; o-where: a label -> (shndx offset), 1-based, or ().
   (o-where lanes lbl)
    (: (go ls i) (!(two? ls) ? ()
                    (<ls 6 @ lb
                       (o-has? lb lbl ? [i (peep lb lbl 0)] (go >ls (i + 1)))))
       (go lanes 1))
   ; a func symbol's size: its end label's offset less its own, in the same lane, else 0
   (o-fsize lanes w nm) (o-where lanes (fn-end nm) @ e (two? e && <e = <w ? (<>e - <>w) 0))
   ; labels a relocation names that no lane defines, each an undef symbol; first-seen order
   (o-exts lanes rels)
    (: seen {}
       (go rs acc)
        (!(two? rs) ? acc
           (<rs 2 @ lbl
              (o-where lanes lbl || o-has? seen lbl ? (go >rs acc)
               (pin seen lbl 1, go >rs (lbl . acc)))))
       (rev (go rels ())))

   ; a 24-byte RELA entry (the symbols are elf.l's elf-sym, st_size 0).
   (o-rela offset symidx typ addend)
    (catall [(le64 offset) (le64 (symidx * 4294967296 + typ)) (le64 addend)])

   ; a string table from a list of names -> (blob (offset..)), leading NUL
   (o-strtab names)
    (: (go ns off bacc offs)
        (!(two? ns) ? [(rev bacc) (rev offs)]
           (o-strbytes <ns + '(0) @ bs
              (go >ns (off + #bs) (rev bs + bacc) (off . offs))))
       (go names 1 '(0) ()))

   ; a name set (interned -> 1), an index map (elem -> i0+i), and map-with-index
   (o-names ns) (: t {} (go ws) (atom? ws ? t (pin t (intern <ws) 1, go >ws)) (go ns))
   (o-idx ls i0) (: t {} (go es i) (atom? es ? t (pin t <es i, go >es (i + 1))) (go ls i0))
   (o-mapi f ls) (: (go l i acc) (atom? l ? (rev acc) (go >l (i + 1) (f i <l . acc))) (go ls 0 ()))

   ; -- ELF32, EM_ARM (the thumb backends) and EM_386: objsecsn's shape with a 52-byte header,
   ; 16-byte symbols, and REL rather than RELA: the addend rides in the field. --
   arm32-targets '(thumb1 thumb2 thumb2sp arm)
   (arm32? t) (elem t arm32-targets)
   (i386? t) (elem t '(i386 i386m16))
   (elf32? t) (arm32? t || i386? t)
   r-386-32 1                                       ; R_386_32    S + A
   r-386-pc32 2                                     ; R_386_PC32  S + A - P
   r-386-pc16 21                                    ; R_386_PC16  S + A - P in two bytes (a 16-bit jump)
   r-386-16 20                                      ; R_386_16    S + A in two bytes (a 16-bit segment's address)
   r-386-8 22                                       ; R_386_8     S + A in one byte
   r-386-pc8 23                                     ; R_386_PC8   S + A - P in one byte
   r-thm-call 10                                    ; R_ARM_THM_CALL   ((S+A)|T) - P  (a thumb BL to a symbol)
   r-thm-jump24 30                                  ; R_ARM_THM_JUMP24 same math      (a thumb2 B.W tail-jump)
   r-thm-jump19 51                                  ; R_ARM_THM_JUMP19 same math      (a thumb2 Bcc.W)
   r-arm-abs32 2                                     ; R_ARM_ABS32      S + A           (la's pooled address word)
   r-thm-movw 47                                    ; R_ARM_THM_MOVW_ABS_NC  (S+A)|T, low 16   (thumb2 la)
   r-thm-movt 48                                    ; R_ARM_THM_MOVT_ABS     S+A, high 16
   ; an 8-byte rel entry (the symbols are elf.l's elf-sym32, st_size 0).
   (o-rel32 offset symidx typ) (catall [(le32 offset) (le32 (symidx * 256 + typ))])
   ; anames maps a C name to its asm label: the strtab spells that, the forms keep the C name
   (objsecs32 target0 secs funcnames globnames wknames) (objsecs32n target0 secs funcnames globnames wknames {})
   (objsecs32n target0 secs funcnames globnames wknames anames)
    (: target (arch-nom target0)
       machine (elf-machines target)
       _ (!machine ? (scare 'no-elf-machine target))
       be (peep backends target ())
       x86 (i386? target)
       tb (x86 ? 0 1)                                ; the thumb bit a func symbol's value carries
       rset (x86 ? '(rel32 rel8 rel16 pc8) '(b bcc bl))
       wkset (o-names wknames)
       nsec #secs
       _ (0 >= nsec ? (scare 'obj-no-sections target))
       (exec? s) (0 < s 2 & 4)
       ; one section is one lay, an executable one through the relaxer
       lanes (map (s \
                (: fm (s 4)
                   p (exec? s ?
                        (laylax @ r
                           (lit? laylax ? (r fm be 0 {} wkset)
                            (scare 'holo-bake-stale 'laylax)))
                        (lay (o-dal fm) be 0 () {}))
                   w (o-walk be <p >p wkset (exec? s ? 1) rset)
                   [(s 0) (s 1) (s 2) (s 3) <w <>w >p]))
              secs)
       (ln i) (lanes i)
       (ln-ty l) (l 1)  (ln-bs l) (l 4)  (ln-rl l) (l 5)
       (ln-fsz l) (ln-ty l = 8 ? 0 (o-blen (ln-bs l)))     ; a NOBITS lane owns no file bytes
       (sec-exec? si) (exec? (secs (si - 1)))            ; by 1-based shndx
       allrel (foldl (a \ l \ a + ln-rl l) () lanes)
       exts (o-exts lanes allrel)
       fnset (o-names funcnames)
       gset (o-names globnames)
       ; a relocated label with no symbol of its own gets a local one, addend 0: on its section
       ; symbol a movw/movt half's signed 16-bit in-field addend loses the middle bits past 32K.
       ; an abs32 to data stays section-relative. -> ((label shndx offset) ..), relocation order.
       (o-locs pick kinds)
        (: seen {}
           (go rs acc)
            (!(two? rs) ? acc
               (: r <rs lbl (r 2)
                  w (elem (r 1) kinds ? (o-where lanes lbl))
                  (go >rs (? !(two? w) acc
                             !(pick <w lbl) acc
                             (o-has? seen lbl) acc
                             (pin seen lbl 1, [lbl <w <>w] . acc)))))
           (rev (go allrel ())))
       ; the branch kinds too: a branch across sections has no room in its field for the offset
       locfns (o-locs (\ si lbl (sec-exec? si && !(o-has? fnset lbl)))
                      (x86 ? '(rel32 rel16 pc8) '(movw16 movt16 abs32 b bcc bl)))
       locdat (o-locs (\ si lbl (!(sec-exec? si) && !(o-has? gset lbl)))
                      '(movw16 movt16))
       locs (locfns + locdat)
       ; -- symbol indices: NULL, a section symbol each, those locals, funcs, globs, exts;
       ; every local ahead of the first global, where .symtab's sh_info points --
       nloc #locs nfun #funcnames nglob #globnames
       fstart (1 + nsec + nloc) gstart (fstart + nfun) estart (gstart + nglob)
       locidx (o-idx (map cap locs) (1 + nsec))
       extidx (o-idx exts estart)
       fnidx (o-idx (map intern funcnames) fstart)
       globidx (o-idx (map intern globnames) gstart)
       ; an abs32 target -> (symidx field): its own global, func or local symbol, else its
       ; section symbol with the offset in the field, else its undef.
       (a32loc lbl aux)
        (? (o-has? globidx lbl) [(peep globidx lbl 0) aux]
           (o-has? fnidx lbl)   [(peep fnidx lbl 0) aux]
           (o-has? locidx lbl)  [(peep locidx lbl 0) aux]
           (o-where lanes lbl @ w
              (two? w ? [<w (<>w + aux)] [(peep extidx lbl 0) aux])))
       ; a movw16/movt16 target -> (symidx addend); its aux is Rd, not an addend
       (mwloc lbl) (a32loc lbl 0)
       ; bake each abs32/16/8 field (addend + any section offset) into the bytes..
       (bakeabs bytes rs)
        (: (go rs bs) (!(two? rs) ? bs
                         (<rs @ r
                            (go >rs (? (<>r == 'abs32) (a32loc <>>r <>>>r @ sl (o-put32 bs <r <>sl))
                                       (<>r == 'abs16) (a32loc <>>r <>>>r @ sl (o-putbs bs <r (le16 <>sl)))
                                       (<>r == 'abs8) (a32loc <>>r <>>>r @ sl (o-putbs bs <r [(<>sl & 255)]))
                                       bs))))
           (go rs bytes))
       ; ..and a movw16/movt16's, scattered into the imm16 by patch-with
       (bakemw bytes rs)
        (:- (go rs bytes) (go rs bs)
         (rs @- bs (r . u)
          (go u (nelem <>r '(movw16 movt16) ? bs
           (mwloc <>>r @ sl
              (<>sl @ 0 bs (o-putbs bs <r (patch-with be <>r <>sl 0 4 <>>>r))))))))
       ; ..and a pc-relative field's: S + A - P counts from the field's start, the fixup from
       ; its end, so A is aux less the width
       (bakepc bytes rs)
        (: (go rs bs) (!(two? rs) ? bs
                         (<rs @ r
                            (go >rs (? (<>r == 'rel32) (o-put32 bs <r (<>>>r - 4))
                                       (<>r == 'rel16) (o-putbs bs <r (le16 (<>>>r - 2)))
                                       (<>r == 'pc8) (o-putbs bs <r [((<>>>r - 1) & 255)])
                                       bs))))
           (go rs bytes))
       lbytes (map (l \ (ln-rl l @ rs (bakepc (bakemw (bakeabs (ln-bs l) rs) rs) rs))) lanes)
       symnames (map (s \ peep anames s s) (map (string * cap) locs + funcnames + globnames + map string exts))
       str (o-strtab symnames)
       strblob <str stroffs <>str
       ; -- the symbol table. on arm a func symbol's value carries the thumb bit, which
       ; R_ARM_THM_CALL folds into T; data syms stay even. a symbol's section is wherever its
       ; bytes went. --
       (o-place nm) (o-where lanes (name nm) @ w (two? w ? w '(1 0)))
       dsz (o-dsizes secs)
       symbytes
        (: lsyms (catall (o-mapi (\ i e (: si <>e off <>>e
                                           (sec-exec? si ?
                                              (elf-sym32 (stroffs i) 0 2 si (off | tb) (o-fsize lanes [si off] (cap e)))   ; stb_local stt_func, +thumb bit
                                              (elf-sym32 (stroffs i) 0 1 si off 0))))      ; stb_local stt_object
                                 locs))
           fsyms (catall (o-mapi (\ i fs (o-place fs @ w
                                            (elf-sym32 (stroffs (nloc + i))
                                                     (elem fs wknames ? 2 1)         ; stb_weak vs stb_global
                                                     2 <w (<>w | tb) (o-fsize lanes w fs))))   ; stt_func, +thumb bit
                                 funcnames))
           gsyms (catall (o-mapi (\ i gs (o-place gs @ w
                                            (elf-sym32 (stroffs (nloc + nfun + i))
                                                     (elem gs wknames ? 2 1) 1 <w <>w (peep dsz (string? gs ? gs (show gs)) 0))))
                                 globnames))
           ; a weak undef resolves to zero at static link
           esyms (catall (o-mapi (\ i e (elf-sym32 (stroffs (nloc + nfun + nglob + i))
                                                 (o-has? wkset e ? 2 1) 0 0 0 0))
                                 exts))
           ssyms (catall (o-mapi (\ i l (elf-sym32 0 0 3 (i + 1) 0 0)) lanes))
           (catall [(elf-sym32 0 0 0 0 0 0) ssyms lsyms fsyms gsyms esyms]))    ; the NULL symbol leads
       nsym (1 + nsec + nloc + nfun + nglob + #exts)
       ; -- the relocations, by the fixup's kind. a branch binds a symbol, never section +
       ; offset: the thumb bit rides the symbol's value and REL has no addend column. --
       (fnsym lbl) (? (o-has? wkset lbl) (peep fnidx lbl 0)
                      (o-has? locidx lbl) (peep locidx lbl 0)
                      (o-has? fnidx lbl) (peep fnidx lbl 0)
                      (peep extidx lbl 0))
       (o-rels32 rs)
        (catall (map (\ [off k lbl aux _]
          (k @ 'rel32 (o-rel32 off (fnsym lbl) r-386-pc32)
               'rel16 (o-rel32 off (fnsym lbl) r-386-pc16)
               'pc8 (o-rel32 off (fnsym lbl) r-386-pc8)
               'bl (o-rel32 off (fnsym lbl) r-thm-call)
               'b  (o-rel32 off (fnsym lbl) r-thm-jump24)   ; a B.W tail-jump to an external/weak fn
               'bcc (o-rel32 off (fnsym lbl) r-thm-jump19)  ; a Bcc.W into another section
               'abs32 (a32loc lbl aux @ sl (o-rel32 off <sl (x86 ? r-386-32 r-arm-abs32)))
               'abs16 (a32loc lbl aux @ sl (o-rel32 off <sl r-386-16))
               'abs8 (a32loc lbl aux @ sl (o-rel32 off <sl r-386-8))
               ('movw16 || 'movt16)
                (mwloc lbl @ sl
                   (o-rel32 off <sl $ k == 'movw16 ? r-thm-movw r-thm-movt))
               (scare 'obj32-reloc k)))
          rs))
       rels (map (o-rels32 * ln-rl) lanes)
       (rcnt i) #(ln-rl (ln i))
       shnames (map cap lanes
                + '(".symtab" ".strtab")
                + map (l \ ".rel" + <l) lanes
                + '(".shstrtab"))
       shstr (o-strtab shnames)
       shstrblob <shstr shoffs <>shstr
       shname shoffs
       ; -- file layout: header, section contents packed tight, then the sht. the indices:
       ; 0 NULL, the content sections, .symtab, .strtab, a .rel per content section, .shstrtab --
       i-sym (1 + nsec) i-str (2 + nsec)
       i-shs (2 * nsec + 3) nsh (2 * nsec + 4)
       h-sz 52
       (o-offs32 i off acc) (nsec <= i ? [(rev acc) off]
                               (o-offs32 (i + 1) (off + ln-fsz (ln i)) (off . acc)))
       co (o-offs32 0 h-sz ())    coffs <co
       sym-off <>co               sym-sz (nsym * 16)
       str-off (sym-off + sym-sz) str-sz #strblob
       (o-roffs32 i off acc) (nsec <= i ? [(rev acc) off]
                                (o-roffs32 (i + 1) (off + rcnt i * 8) (off . acc)))
       ro (o-roffs32 0 (str-off + str-sz) ())   roffs <ro
       shs-off <>ro               shs-sz #shstrblob
       sht-off (shs-off + shs-sz)
       sht (catall ([(o-zeros 40)]                                             ; 0 NULL
              + o-mapi (\ i l (elf-shdr32 (shname i) (ln-ty l) (l 2)             ; 1..nsec the content sections
                                    0 (coffs i) (o-blen (ln-bs l)) 0 0 (l 3) 0))
                       lanes
              + [(elf-shdr32 (shname nsec) 2 0 0 sym-off sym-sz i-str (1 + nsec + nloc) 4 16)   ; .symtab link=.strtab info=first-global
                 (elf-shdr32 (shname (nsec + 1)) 3 0 0 str-off str-sz 0 0 1 0)]                   ; .strtab
              + o-mapi (\ i l (elf-shdr32 (shname (nsec + 2 + i)) 9 0                        ; one .rel per section, link=.symtab
                                    0 (roffs i) (rcnt i * 8) i-sym (i + 1) 4 8))
                       lanes
              + [(elf-shdr32 (shname (2 * nsec + 2)) 3 0 0 shs-off shs-sz 0 0 1 0)]))           ; .shstrtab
       hdr (catall [
             '(127 69 76 70 1 1 1 0 0 0 0 0 0 0 0 0)                      ; e_ident: \x7fELF 32-bit LSB
             (le16 1) (le16 machine) (le32 1)                             ; et_rel, e_machine, version
             (le32 0) (le32 0) (le32 sht-off)                             ; e_entry=0, e_phoff=0, e_shoff
             (le32 (x86 ? 0 83886080)) (le16 52) (le16 0)                 ; e_flags=eabi_ver5 on arm, e_ehsize=52, e_phentsize=0
             (le16 0) (le16 40) (le16 nsh)                                ; e_phnum=0, e_shentsize=40, e_shnum
             (le16 i-shs)])                                               ; e_shstrndx
       (catall ([hdr]
                + o-mapi (i \ l \ ln-ty l != 8 && lbytes i) lanes       ; a NOBITS lane writes nothing
                + [symbytes strblob]
                + rels
                + [shstrblob sht])))

   ; a section's sh_addralign: the floor a0, or the widest ('align n) its forms ask, else an
   ; inner pad aligns nothing.
   (o-dalign a0 forms)
    (:- (go forms a0) (go l a2)
     (l @- a2 (f . u) (go u (two? f && <f == 'align && f 1 > a2 ? <>f a2))))

   ; the section descriptors of a .o, from gen.l's cgen-obj split IR. love_nifs is read through
   ; the linker's __start_/__stop_ brackets; .love.image is the bake slot, laid last so `love
   ; bake` can grow it. each rides only an object that fills it: an empty one is an orphan
   ; another link (the kernel's) must place. moon.l appends other named sections itself.
   ; .bss is NOBITS: its loader owes the zeros. .rodata (flags 2) promises no relocation.
   (objsecs4 textforms dataforms nifforms imgforms bssforms rodataforms)
    ([[".text"   1 6 16 textforms]
      [".rodata" 1 2 (o-dalign 8 rodataforms) rodataforms]
      [".data"   1 3 (o-dalign 8 dataforms) dataforms]
      [".bss"    8 3 (o-dalign 8 bssforms) bssforms]]
     + (two? nifforms ? [["love_nifs" 1 3 8 nifforms]] ())
     + (two? imgforms ? [[".love.image"  1 3 16 imgforms]] ()))
   ; a named section a compiler emits: progbits on the widest grain its globals ask and no wider,
   ; as objects' pieces may tile one array (the kernel's .videocards); writable unless ro.
   (objsec-named nm forms ro) [nm 1 (ro ? 2 3) (o-dalign 1 forms) forms]
   ; ..and the code twin, for a function that named its own section; flags 6 = alloc|execinstr.
   ; the grain is the caller's: one-fn sections at grain N tile at N (love.h's love_typ stride).
   (objsec-code nm forms al) [nm 1 6 al forms]
   ; a data section's alignment pads with zeros, not the backend's nop
   (o-dal fm) (map (f \ (two? f && <f == 'align ? ['dalign (f 1)] f)) fm)
   ; a file-scope asm's sections, (name type flags forms) each: a name already laid takes the
   ; forms at its tail and keeps its own flags, a new one rides after the rest
   (objsec-merge secs xs)
    (foldl (\ a x (: nm <x fs (x 3)
                     (any (s \ <s = nm) a ?
                        (map (s \ (<s = nm ? [nm (s 1) (s 2) (o-dalign (s 3) fs) (s 4 + fs)] s)) a)
                        (a + [[nm (x 1) (x 2) (o-dalign 1 fs) fs]]))))
           secs xs)
   ; the .ARM.attributes an arm32 object owes its linker, which refuses a pair that cannot
   ; merge. an unstated tag reads 0 and disarms the check; ld compares VFP_args only where
   ; Tag_ABI_FP_number_model (23) says floats are used.
   ; format: 'A', le32 over all that follows, "aeabi\0", Tag_File (1) with its own le32 length,
   ; then (tag value) uleb128 pairs, a string value NUL-terminated; all here are under 128.
   (armattrs t)
    (: t1 (t == 'thumb1) a? (t == 'arm)                       ; linux's arm: the fpv5 set is armv8's aarch32
       pairs ('(5) + o-strbytes (? t1 "6-M" a? "8-A" "7E-M") + '(0)   ; Tag_CPU_name
              + [6 (? t1 11 a? 14 13)]                         ; Tag_CPU_arch: v6-M | v8 | v7E-M
              + [7 (a? ? 65 77)]                               ; Tag_CPU_arch_profile: 'A' | 'M'
              + [9 (t1 ? 1 2)]                                 ; Tag_THUMB_ISA_use: 1 | 2
              + (? (t == 'thumb2 || a?) '(10 8)                ; Tag_FP_arch: FPv5/FP-D16
                   (t == 'thumb2sp) '(10 6 27 1) ())           ; ..VFPv4-D16, and SP only
              + '(18 4)                                        ; Tag_ABI_PCS_wchar_t
              + '(23 3)                                        ; Tag_ABI_FP_number_model: IEEE 754
              + '(26 1)                                        ; Tag_ABI_enum_size: small
              + (t1 ? () '(28 1)))                             ; Tag_ABI_VFP_args: VFP regs
       sub ('(1) + le32 (5 + #pairs) + pairs)             ; Tag_File, over its own length
       ('(65) + le32 (10 + #sub) + o-strbytes "aeabi" + '(0) + sub))

   ; the elf32 twin of objsecs4: no .love.image at 32 bits (no bake). arm code sits at grain 4,
   ; flash being scarce; .bss rides as NOBITS since these ports zero it themselves.
   (objsecs3 target textforms dataforms nifforms imgforms bssforms rodataforms)
    (two? imgforms ? (scare 'obj-image-arm32 target) 0,
     [[".text"   1 6 (i386? target ? 16 4) textforms]
      [".rodata" 1 2 (o-dalign 4 rodataforms) rodataforms]
      [".data"   1 3 (o-dalign 4 dataforms) dataforms]
      [".bss"    8 3 (o-dalign 4 bssforms) bssforms]]
     + (two? nifforms ? [["love_nifs" 1 3 4 nifforms]] ())
     + (i386? target ? () [[".ARM.attributes" 1879048195 0 1 [['raw (armattrs target)]]]]))   ; SHT_ARM_ATTRIBUTES

   (objelf target0 textforms dataforms funcnames globnames wknames nifforms imgforms locnames bssforms rodataforms)
    (arch-nom target0 @ target
       (elf32? target ?
         (objsecs32 target (objsecs3 target textforms dataforms nifforms imgforms bssforms rodataforms)
                    funcnames globnames wknames)          ; locnames unrepresented on elf32
         (objsecs target (objsecs4 textforms dataforms nifforms imgforms bssforms rodataforms)
                  funcnames globnames wknames locnames)))

   ; -- the general object: a list of sections, each (name type flags align forms), each one
   ; lay: a branch inside resolves in place, a reference across becomes a relocation.
   ; shf_execinstr (flags & 4) picks the relaxer and rset (a64's branches resolve in any
   ; section). a NOBITS section lays its forms for labels and size but writes no bytes. --
   (objsecs target0 secs funcnames globnames wknames locnames) (objsecsn target0 secs funcnames globnames wknames locnames {})
   (objsecsn target0 secs funcnames globnames wknames locnames anames)
    (: target (arch-nom target0)
       a64 (target = 'a64)
       rv (target = 'rv64)
       _ (target = 'x64 || a64 || rv ? 0 (scare 'obj-target target))
       ; the in-place-resolvable kinds; riscv's auipc is byte pc-relative, no page math
       rset (? a64 '(b26 b19 b14 ld19 adr21) rv '(j21 pcrel b13 cj cb) '(rel32 rel8))
       drset (a64 ? rset ())
       machine (peep elf-machines target 0)
       ; a cross backend joins at runtime; unregistered, lay would lower nothing, silently
       be (backends target @ b
             (lit? b ? b (scare 'obj-no-backend target)))
       ; a weak-defined function's callers go through a relocation, so a strong override wins;
       ; the relaxer must keep them long too
       wkset (o-names wknames)
       nsec #secs
       _ (0 >= nsec ? (scare 'obj-no-sections target))
       (exec? s) (0 < s 2 & 4)
       ; the relaxer, for executable sections only; a holo bake without laylax is a stale
       ; binary under a fresh obj.l, and scares
       lanes (map (s \
                (: fm (s 4)
                   p (exec? s ?
                        (laylax @ r
                           (lit? r ? (r fm be 0 {} wkset)
                              (scare 'holo-bake-stale 'laylax)))   ; each section at org 0
                        (lay (o-dal fm) be 0 () {}))
                   w (o-walk be <p >p wkset 1 (exec? s ? rset drset))
                   [(s 0) (s 1) (s 2) (s 3) <w <>w >p]))
              secs)
       (ln i) (lanes i)
       (ln-ty l) (l 1)  (ln-bs l) (l 4)  (ln-rl l) (l 5)
       (ln-fsz l) (ln-ty l = 8 ? 0 (o-blen (ln-bs l)))     ; a NOBITS lane owns no file bytes
       allrel (foldl (a \ l \ a + ln-rl l) () lanes)
       exts (o-exts lanes allrel)

       ; -- symbol indices: NULL, a section symbol each, the local statics, funcs, globs,
       ; exts. every local ahead of the first global, where .symtab's sh_info points --
       nloc #locnames nfun #funcnames nglob #globnames
       fstart (1 + nsec + nloc) gstart (fstart + nfun) estart (gstart + nglob)
       extidx (o-idx exts estart)
       fnidx (o-idx (map name funcnames) fstart)   ; relocs to a global bind these
       gidx (o-idx (map name globnames) gstart)

       symnames (map (s \ peep anames s s) (locnames + funcnames + globnames + map string exts))
       str (o-strtab symnames)
       strblob <str stroffs <>str

       ; -- the symbol table, locals first. a symbol's section is wherever its bytes went;
       ; o-place falls back to section 1 for a name never laid --
       (o-place nm) (o-where lanes (name nm) @ w (two? w ? w '(1 0)))
       dsz (o-dsizes secs)
       (o-size nm) (peep dsz (string? nm ? nm (show nm)) 0)
       symbytes
        (: lsyms (catall (o-mapi (\ i ls (: w (o-place ls)                ; stb_local: a func, or an object in data
                                            x (exec? (secs (<w - 1)))
                                            (elf-sym (stroffs i) 0 (x ? 2 1) <w <>w (x ? (o-fsize lanes w ls) (o-size ls)))))
                                 locnames))
           fsyms (catall (o-mapi (\ i fs (o-place fs @ w
                                            (elf-sym (stroffs (nloc + i))
                                             (elem fs wknames ? 2 1)   ; stb_weak | stb_global
                                             2 <w <>w (o-fsize lanes w fs))))
                                 funcnames))
           gsyms (catall (o-mapi (\ i gs (o-place gs @ w
                                            (elf-sym (stroffs (nloc + nfun + i))
                                                   (elem gs wknames ? 2 1) 1 <w <>w (o-size gs))))
                                 globnames))
           ; a weak undef resolves to zero at static link
           esyms (catall (o-mapi (\ i e (elf-sym (stroffs (nloc + nfun + nglob + i))
                                               (o-has? wkset e ? 2 1) 0 0 0 0))
                                 exts))
           ; one stt_section symbol per section, in section order
           ssyms (catall (o-mapi (\ i l (elf-sym 0 0 3 (i + 1) 0 0)) lanes))
           (catall [(elf-sym 0 0 0 0 0 0) ssyms lsyms fsyms gsyms esyms]))    ; the NULL symbol leads
       nsym (1 + nsec + nloc + nfun + nglob + #exts)

       ; -- the relocations, by the fixup's kind, never the section. --
       ; a label -> (symidx base-addend): a global binds itself (base 0), as gas does, so the
       ; linker can redirect a weak one and modpost reads an export's name; a local label
       ; its section symbol + offset, else its undef.
       (secsym lbl)
        (? (o-has? fnidx lbl) [(peep fnidx lbl 0) 0]
           (o-has? gidx lbl)  [(peep gidx lbl 0) 0]
           (o-where lanes lbl @ w (two? w ? w [(peep extidx lbl 0) 0])))
       rabs (? a64 ra-abs64 rv rr-64 r-64)
       (o-rels rs)
        (catall (map (\ [off k lbl aux pv]
           (: sl (secsym lbl) si <sl sa <>sl
              (k @
                 ; aux is the constant byte offset of a &arr[i] / &s.field
                 'abs64 (o-rela off si rabs (sa + aux))
                 'abs32 (o-rela off si (a64 ? ra-abs32 r-32) (sa + aux))
                 'abs32s (o-rela off si r-32s (sa + aux))
                 ; an 8-byte word measured from its own start
                 'rel64 (o-rela off si (a64 ? ra-prel64 r-pc64) ((sa + aux) - 8))
                 ; x64 counts from the field's end, so the -4. a weak fn binds plt32; for an
                 ; external, a preceding E8/E9 (call/jmp) wants plt32, anything else pc32 (data
                 ; has no plt stub).
                 'rel32
                  (o-rela off si
                          (? rv rr-pc32
                             a64 ra-prel32
                             (o-has? wkset lbl && o-has? fnidx lbl) r-plt32
                             (o-where lanes lbl) r-pc32
                             (elem pv '(232 233)) r-plt32
                             r-pc32)
                          ((sa + aux) - 4))
                 ; a64: a page delta never resolves inside a .o
                 'adrp21 (o-rela off si ra-pghi21 (sa + afix-ad aux))
                 'addlo12 (o-rela off si ra-lo12 (sa + afix-ad aux))
                 ('lo12s1 || 'lo12s2 || 'lo12s4 || 'lo12s8 || 'lo12s16) (o-rela off si (ra-ldst k) (sa + afix-ad aux))
                 'b26 (o-rela off si (aux = 2483027968 ? ra-call26 ra-jump26) sa)   ; 0x94000000 = bl
                 'b19 (o-rela off si ra-condbr19 sa)
                 'b14 (o-rela off si ra-tstbr14 sa)
                 'ld19 (o-rela off si ra-ldlo19 (sa + afix-ad aux))
                 'adr21 (o-rela off si ra-adrlo21 (sa + afix-ad aux))
                 'pcrel (o-rela off si rr-call sa)
                 'j21 (o-rela off si rr-jal sa)
                 (scare 'obj-fix k))))
           rs))
       relas (map (o-rels * ln-rl) lanes)
       rcnt (tally * ln-rl * ln)

       shnames (map cap lanes
                + '(".symtab" ".strtab")
                + map (l \ ".rela" + <l) lanes
                + '(".shstrtab"))
       shstr (o-strtab shnames)
       shstrblob <shstr shoffs <>shstr
       shname shoffs

       ; -- file layout: header, section contents packed tight (sh_addralign places them),
       ; then the sht. the indices: 0 NULL, the content sections, .symtab, .strtab, a .rela
       ; per content section, .shstrtab last. --
       i-sym (1 + nsec) i-str (2 + nsec) i-rel0 (3 + nsec)
       i-shs (2 * nsec + 3) nsh (2 * nsec + 4)
       h-sz 64
       ; the content offsets, in section order; a NOBITS sh_offset is a placeholder.
       (o-offs i off acc) (nsec <= i ? [(rev acc) off]
                             (o-offs (i + 1) (off + ln-fsz (ln i)) (off . acc)))
       co (o-offs 0 h-sz ())    coffs <co
       sym-off <>co             sym-sz (nsym * 24)
       str-off (sym-off + sym-sz) str-sz #strblob
       (o-roffs i off acc) (nsec <= i ? [(rev acc) off]
                              (o-roffs (i + 1) (off + rcnt i * 24) (off . acc)))
       ro (o-roffs 0 (str-off + str-sz) ())    roffs <ro
       shs-off <>ro             shs-sz #shstrblob
       sht-off (shs-off + shs-sz)

       sht (catall ([(o-zeros 64)]                                         ; 0 NULL
              + o-mapi (\ i l (elf-shdr (shname i) (ln-ty l) (l 2)           ; 1..nsec the content sections
                                  0 (coffs i) (o-blen (ln-bs l)) 0 0 (l 3) 0))
                       lanes
              + [(elf-shdr (shname nsec) 2 0 0 sym-off sym-sz i-str ((1 + nsec) + nloc) 8 24)    ; .symtab link=.strtab info=first-global
                 (elf-shdr (shname (nsec + 1)) 3 0 0 str-off str-sz 0 0 1 0)]                    ; .strtab
              + o-mapi (\ i l (elf-shdr (shname (nsec + 2 + i)) 4 0                          ; one .rela per section, link=.symtab
                                  0 (roffs i) (rcnt i * 24) i-sym (i + 1) 8 24))
                       lanes
              + [(elf-shdr (shname (2 * nsec + 2)) 3 0 0 shs-off shs-sz 0 0 1 0)]))             ; .shstrtab

       hdr (catall [
             '(127 69 76 70 2 1 1 0 0 0 0 0 0 0 0 0)                      ; e_ident: \x7fELF 64-bit LSB
             (le16 1) (le16 machine) (le32 1)                             ; et_rel, e_machine, version
             (le64 0) (le64 0) (le64 sht-off)                             ; e_entry=0, e_phoff=0, e_shoff
             (le32 (machine = 243 ? 5 0)) (le16 64) (le16 0)            ; e_flags (riscv: RVC | FLOAT_ABI_DOUBLE), e_ehsize, e_phentsize=0
             (le16 0) (le16 64) (le16 nsh)                                ; e_phnum=0, e_shentsize=64, e_shnum
             (le16 i-shs)])                                               ; e_shstrndx
       (catall ([hdr]
                + map (l \ (ln-ty l = 8 ? () (ln-bs l))) lanes           ; a NOBITS lane writes nothing
                + [symbytes strblob]
                + relas
                + [shstrblob sht]))))
) ; module 'holo
