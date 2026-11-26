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
   r-16    12                                       ; R_X86_64_16     S + A in 2 bytes (a 16-bit segment's word)
   r-8     14                                       ; R_X86_64_8      S + A in a byte
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
   rr-32    1                                       ; R_RISCV_32        S + A  in four bytes
   rr-64    2                                       ; r_rv64_64        S + A  (collides with R_X86_64_PC32: link.l dispatches by machine)
   rr-pc32  57                                      ; R_RISCV_32_PCREL  S + A - P in four bytes (a jump table's entry)
   rr-jal   17                                      ; R_RISCV_JAL       S + A - P into jal's j-imm
   rr-call  19                                      ; R_RISCV_CALL_PLT  S + A - P across the auipc pair
   ; ... xtensa: slot0 is a j's or call0's offset, whichever opcode holds the field
   xr-32    1                                       ; R_XTENSA_32       S + A  in four bytes
   xr-slot0 20                                      ; R_XTENSA_SLOT0_OP S + A into slot 0's pc-relative offset
   ; ... mips: each field ored into the big-endian word its object holds
   mr-32    2                                       ; R_MIPS_32         S + A  in four bytes
   mr-26    4                                       ; R_MIPS_26         (S + A) >> 2 into j's or jal's index
   mr-hi16  5                                       ; R_MIPS_HI16       S + A's high half, carried for lo16's sign
   mr-lo16  6                                       ; R_MIPS_LO16       S + A's low half
   mr-pc16  10                                      ; R_MIPS_PC16       (S + A - P) >> 2 into a branch's offset
   ; ... avr: a fixup's kind and R_AVR_'s number. a branch counts from P + 2, which the linker
   ; takes off; pm is a word address, neg the negated one
   avr-rels {'av7 2 'av13 3 'av16pm 5 'avcall 18
             'avlo8 6 'avhi8 7 'avlo8neg 9 'avhi8neg 10 'avlo8pm 12 'avhi8pm 13}
   ; every R_AVR_ by number
   avr-rnames ["NONE" "32" "7_PCREL" "13_PCREL" "16" "16_PM" "LO8_LDI" "HI8_LDI" "HH8_LDI" "LO8_LDI_NEG" "HI8_LDI_NEG"
               "HH8_LDI_NEG" "LO8_LDI_PM" "HI8_LDI_PM" "HH8_LDI_PM" "LO8_LDI_PM_NEG" "HI8_LDI_PM_NEG" "HH8_LDI_PM_NEG" "CALL"
               "LDI" "6" "6_ADIW" "MS8_LDI" "MS8_LDI_NEG" "LO8_LDI_GS" "HI8_LDI_GS" "8" "8_LO8" "8_HI8" "8_HLO8"
               "DIFF8" "DIFF16" "DIFF32" "LDS_STS_16" "PORT6" "PORT5"]
   (avr-rname n) ("R_AVR_" + peep avr-rnames n (show n))
   ; what a reader does with one: () for a kind it may apply, else a scare naming it. 32, 16 and 8 are
   ; plain words; a gs wants a stub past 128k and a diff a relaxing linker
   (avr-rtake n) (elem n [1 2 3 4 5 6 7 9 10 12 13 18 26] ? () (scare 'avr-reloc (avr-rname n)))

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
                               (elem k '(b14 j21)) (le32 (fix-a x))
                               ; xtensa: a j or call0 with a zero offset, its opcode telling slot0 which
                               (k == 'j18) [6 0 0]  (k == 'call0) [5 0 0]
                               ; mips: the instruction's word, its field zero
                               (elem k '(mb16 mj26 mhi16 mlo16)) (be32 (fix-a x))
                               ; avr: the instruction's word, or the two of a call or jmp
                               (o-has? avr-rels k) (afix-w (fix-a x) @ v (w = 4 ? (le16 (v >> 16) + le16 (v & 0xffff)) (le16 v)))
                               ; riscv 'pcrel: aux packs both base words, auipc low, the I-insn high
                               (k == 'pcrel) (le32 (fix-a x % 4294967296) + le32 (fix-a x // 4294967296))
                               ; arm is REL: a thumb branch holds its encoding with the -4 addend
                               ; baked in (the field counts from instr+4, the reloc's P from instr)
                               (elem k '(b bcc bl)) (patch-with be k off off w (fix-a x))
                               ; movw16/movt16 (thumb2 la): zero imm16 here, bakemw fills it
                               (elem k '(movw16 movt16)) (patch-with be k 0 off w (fix-a x))
                               ; movw16p/movt16p (thumb2 lap): the addend that counts P to the add's pc
                               (elem k '(movw16p movt16p)) (peep be 'lapa 0 k (fix-a x))
                               ; gotprel: the word's addend, REL, counting P to the add's pc
                               (k == 'gotprel) (le32 (fix-a x % 4294967296))
                               (o-zeros w))
                       ; carry the byte before the field, the x64 opcode that tells a call
                       ; (PLT32) from an address-of (PC32); a blob head is a string, so 0.
                       ; an 8x is a jcc only after its 0F, else it is a Modrm
                       (o-walkr be >items labels wkset internal? rset (off + w)
                                (rev fill + bacc)
                                ([off k lbl (fix-a x) (two? bacc && charm? <bacc && (<bacc < 128 || 143 < <bacc || >bacc && <>bacc = 15) ? <bacc 0)] . racc)))))
             (o-walkr be >items labels wkset internal? rset (off + item-len x) (x . bacc) racc))))
   (o-zeros n) (n >= 1 ? (0 . o-zeros (n - 1)))
   (o-take l n) (two? l && n >= 1 ? (<l . o-take >l (n - 1)))
   (o-drop l n) (n < 1 || atom? l ? l (o-drop >l (n - 1)))
   ; splice pre-encoded bytes in at off
   (o-putbs bytes off bs) (catall [(o-take bytes off) bs (o-drop bytes (off + #bs))])
   (o-put32 bytes off val) (o-putbs bytes off (le32 val))

   ; a lane is one laid section: (name type flags align bytes relocs labels).
   ; o-wix: every label -> (shndx offset), 1-based, the first lane's that has it.
   ; o-where reads it, () for none.
   (o-wix lanes)
    (: t {}
       (go ls i) (? (atom? ls) t
                    (<ls 6 @ lb
                       (foldl (\ _ k (o-has? t k ? 0 (pin t k [i (peep lb k 0)]))) 0 (keys lb),
                        go >ls (i + 1))))
       (go lanes 1))
   (o-where wx lbl) (wx lbl)
   ; lane index -> lane, so a walk by index is no walk of the list
   (o-rows ls) (: t {} (go es i) (atom? es ? t (pin t i <es, go >es (i + 1))) (go ls 0))
   ; a func symbol's size: its end label's offset less its own, in the same lane, else 0
   (o-fsize wx w nm) (o-where wx (fn-end nm) @ e (two? e && <e = <w ? (<>e - <>w) 0))
   (o-ftype wx nm) (two? (o-where wx (fn-type nm)) ? 2 0)        ; stt_func | stt_notype
   ; a size its text gave: a constant, or ('dif end start) over labels, -> st_size; () when neither
   (o-gsize wx z)
    (? (charm? z) z
       (two? z) (: e (o-where wx (name (z 1))) s (o-where wx (name (z 2))) (two? e && two? s && <e = <s ? (<>e - <>s) 0))
       ())
   ; labels a relocation names that no lane defines, each an undef symbol; first-seen order
   (o-exts wx rels)
    (: seen {}
       (go rs acc)
        (!(two? rs) ? acc
           (<rs 2 @ lbl
              (o-where wx lbl || o-has? seen lbl ? (go >rs acc)
               (pin seen lbl 1, go >rs (lbl . acc)))))
       (rev (go rels ())))

   ; a 24-byte RELA entry (the symbols are elf.l's elf-sym, st_size 0).
   (o-rela offset symidx typ addend)
    (catall [(le64 offset) (le64 (symidx * 4294967296 + typ)) (le64 addend)])
   ; ..and the 12-byte ELF32 one, rv32's
   (o-rela32 offset symidx typ addend)
    (catall [(le32 offset) (le32 (symidx * 256 + typ)) (le32 addend)])

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
   (i386? t) (elem t '(i386 i386m16))
   (elf32? t) (thumb? t || i386? t)
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
   r-arm-rel32 3                                     ; R_ARM_REL32      S + A - P       (a word over two labels)
   r-arm-gotprel 96                                  ; R_ARM_GOT_PREL   GOT(S) + A - P  (a pie's address of an import)
   r-thm-movw 47                                    ; R_ARM_THM_MOVW_ABS_NC  (S+A)|T, low 16   (thumb2 la)
   r-thm-movt 48                                    ; R_ARM_THM_MOVT_ABS     S+A, high 16
   r-thm-movwp 49                                   ; R_ARM_THM_MOVW_PREL_NC ((S+A)|T) - P, low 16   (thumb2 lap)
   r-thm-movtp 50                                   ; R_ARM_THM_MOVT_PREL    S+A - P, high 16
   ; an 8-byte rel entry (the symbols are elf.l's elf-sym32, st_size 0).
   (o-rel32 offset symidx typ) (catall [(le32 offset) (le32 (symidx * 256 + typ))])
   ; anames maps a C name to its asm label: the strtab spells that, the forms keep the C name
   (objsecs32 target0 secs funcnames globnames wknames) (objsecs32n target0 secs funcnames globnames wknames {})
   (objsecs32n target0 secs funcnames globnames wknames anames) (objsecs32x target0 secs funcnames globnames wknames anames () [() () ()])
   ; loc0 and ax are objsecsn's, and i386's alone
   (objsecs32x target0 secs funcnames globnames wknames anames loc0 ax)
    (: target (arch-nom target0)
       adata (o-names <ax) abss (filter (p \ #p = 2) <>ax) labss (filter (p \ #p = 3) <>ax)
       szt (foldl (\ t p (pin t (name <p) <>p)) {} (2 < #ax ? (ax 2) ()))
       machine (elf-machines target)
       _ (!machine ? (scare 'no-elf-machine target))
       be (backends target)
       x86 (i386? target)
       tb (x86 ? 0 1)                                ; the thumb bit a func symbol's value carries
       rset (x86 ? '(rel32 rel8 rel16 pc8) '(b bcc bl b16 b8 cbz ldl16 ldlw vldl))
       wkset (o-names wknames)
       ; i386: a reach to any global stays a relocation, as gas leaves it
       gbset (x86 ? (o-names (wknames + funcnames + globnames)) wkset)
       _ (atom? secs ? (scare 'obj-no-sections target))
       (exec? s) (0 < s 2 & 4)
       ; one section is one lay, an executable one through the relaxer
       lanes0 (map (s \
                (: fm (s 4)
                   p (exec? s ?
                        (laylax @ r
                           (lit? laylax ? (r fm be 0 {} gbset)
                            (scare 'holo-bake-stale 'laylax)))
                        (lay (o-dal fm) be 0 () {}))
                   w (o-walk be <p >p gbset (x86 || exec? s ? 1) rset)
                   [(s 0) (s 1) (s 2) (s 3) <w <>w >p]))
              secs)
       ; -g's sections: their words reach a section and an offset, so a function's has no thumb bit
       lanes (lanes0 + (5 < #ax && two? (ax 5) ?
                          (map ([nm t f al bs rs lb] \ [nm t f al bs (map ([o k l a p] \ [o 'dabs32 l a p]) rs) lb])
                               ((thumb-framed? target ? (o-eh lanes0 (funcnames + loc0) target 1 @ e (two? e ? [e] ())) ())
                                + o-dwarf lanes0 (ax 5) (funcnames + loc0) funcnames target))
                          ()))
       nsec #lanes
       wx (o-wix lanes) lnt (o-rows lanes)
       (ln i) (lnt i)
       (ln-ty l) (l 1)  (ln-bs l) (l 4)  (ln-rl l) (l 5)
       (ln-fsz l) (ln-ty l = 8 ? 0 (o-blen (ln-bs l)))     ; a NOBITS lane owns no file bytes
       (sec-exec? si) (exec? (ln (si - 1)))            ; by 1-based shndx
       allrel (catall (map ln-rl lanes))
       ext0 (o-exts wx allrel)
       exts (ext0 + filter (u \ (nelem u ext0)) (map name (3 < #ax ? (ax 3) ())))
       vist (foldl (\ t p (pin t (name <p) <>p)) {} (4 < #ax ? (ax 4) ()))
       (o-vis nm b) (peep vist (name nm) 0 @ v (v = 0 ? b (o-putbs b 13 [v])))
       ; i386: a reach with a constant into a merging section names its label, as on x64
       (rel-c k aux) (k @ ('rel32 || 'pc32) (aux - 4) 'rel16 (aux - 2) 'pc8 (aux - 1) aux)
       (mrg? r) (: w (o-where wx (r 2))
                   (two? w && 0 < ((ln (<w - 1)) 2 & 16) && !(o-has? gbset (r 2)) && rel-c (r 1) (r 3) != 0))
       mlabs (x86 ? (uniq (map (r \ show (r 2)) (filter mrg? allrel))) ())
       mset (o-names mlabs)
       loc0s (o-names loc0)
       mnew (filter (l \ !(o-has? loc0s (intern l))) mlabs)
       mnews (o-names mnew)
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
                  w (elem (r 1) kinds ? (o-where wx lbl))
                  (go >rs (? !(two? w) acc
                             !(pick <w lbl) acc
                             (o-has? seen lbl) acc
                             (pin seen lbl 1, [lbl <w <>w] . acc)))))
           (rev (go allrel ())))
       (o-place nm) (o-where wx (name nm) @ w (two? w ? w '(1 0)))
       locs (? x86 (map (nm \ (o-place nm @ w [(name nm) <w <>w])) (loc0 + mnew))
               ; the branch kinds too: a branch across sections has no room in its field for the
               ; offset; nor a pc-relative reach into data
               (o-locs (\ si lbl (sec-exec? si && !(o-has? fnset lbl))) '(movw16 movt16 movw16p movt16p abs32 b bcc bl)
                + o-locs (\ si lbl (!(sec-exec? si) && !(o-has? gset lbl))) '(movw16 movt16 movw16p movt16p)))
       ; -- symbol indices: NULL, a section symbol each, those locals, funcs, globs, exts;
       ; every local ahead of the first global, where .symtab's sh_info points --
       nloc (#locs + #labss) nfun #funcnames nglob #globnames nabs #abss
       fstart (1 + nsec + nloc) gstart (fstart + nfun) estart (gstart + nglob + nabs)
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
           (o-where wx lbl @ w
              (two? w ? [<w (<>w + aux)] [(peep extidx lbl 0) aux])))
       ; i386, as gas: a global binds itself, a local its section symbol and the offset in the
       ; field, unless a merging section needs the label -> (symidx base)
       (xsl k lbl aux)
        (? (o-has? fnidx lbl) [(peep fnidx lbl 0) 0]
           (o-has? globidx lbl) [(peep globidx lbl 0) 0]
           (o-has? mset lbl && rel-c k aux != 0) [(peep locidx lbl 0) 0]
           (o-where wx lbl @ w (two? w ? w [(peep extidx lbl 0) 0])))
       (a32k k lbl aux) (x86 ? (xsl k lbl aux @ s [<s (<>s + aux)]) (a32loc lbl aux))
       ; a movw16/movt16 target -> (symidx addend); its aux is Rd, not an addend
       (mwloc lbl) (a32loc lbl 0)
       ; bake each abs32/16/8 field (addend + any section offset) into the bytes..
       (bakeabs bytes rs)
        (: (go rs bs) (!(two? rs) ? bs
                         (<rs @ r
                            (go >rs (? (<>r == 'abs32 || <>r == 'abs32d) (a32k <>r <>>r <>>>r @ sl (o-put32 bs <r <>sl))
                                       (<>r == 'dabs32) (o-where wx (<>>r) @ w (o-put32 bs <r (<>w + <>>>r)))
                                       (<>r == 'abs16) (a32k <>r <>>r <>>>r @ sl (o-putbs bs <r (le16 <>sl)))
                                       (<>r == 'abs8) (a32k <>r <>>r <>>>r @ sl (o-putbs bs <r [(<>sl & 255)]))
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
       (pcf r) (<>(xsl <>r <>>r <>>>r) + <>>>r)
       (bakepc bytes rs)
        (: (go rs bs) (!(two? rs) ? bs
                         (<rs @ r
                            (go >rs (? (<>r == 'rel32 || <>r == 'pc32) (o-put32 bs <r (pcf r - 4))
                                       (<>r == 'rel16) (o-putbs bs <r (le16 (pcf r - 2)))
                                       (<>r == 'pc8) (o-putbs bs <r [((pcf r - 1) & 255)])
                                       bs))))
           (go rs bytes))
       lbytes (map (l \ (ln-rl l @ rs (bakepc (bakemw (bakeabs (ln-bs l) rs) rs) rs))) lanes)
       symnames (map (s \ peep anames s s) (map (string * cap) locs + map cap labss + funcnames + globnames + map cap abss + map string exts))
       str (o-strtab symnames)
       strblob <str stroffs (o-rows <>str)
       ; -- the symbol table. on arm a func symbol's value carries the thumb bit, which
       ; R_ARM_THM_CALL folds into T; data syms stay even. a symbol's section is wherever its
       ; bytes went. --
       dsz (o-dsizes secs)
       (o-size nm) (peep dsz (string? nm ? nm (show nm)) 0)
       ; i386's types and sizes, as objsecsn's: an asm text's as it says, else from the data
       (o-asm? nm) (o-has? adata (name nm) || o-has? mnews (name nm))
       (o-xtype nm) (two? (o-where wx (fn-obj nm)) ? 1 (o-ftype wx nm))
       (o-dtype nm) (x86 ? (o-asm? nm ? (o-xtype nm) 1) 1)
       (o-ftyp nm) (x86 ? (o-xtype nm) 2)
       (o-xsize w nm) (o-gsize wx (szt (name nm)) @ z (charm? z ? z (o-fsize wx w nm)))
       (o-dsize w nm) (x86 && o-asm? nm ? (o-xsize w nm) (o-size nm))
       symbytes
        (: lsyms (catall (o-mapi (\ i e (: si <>e off <>>e
                                           (sec-exec? si ?
                                              (elf-sym32 (stroffs i) 0 (o-ftyp (cap e)) si (off | tb) (o-xsize [si off] (cap e)))   ; stb_local, +thumb bit
                                              (x86 ? (elf-sym32 (stroffs i) 0 (o-dtype (cap e)) si off (o-dsize [si off] (cap e)))
                                                 (elf-sym32 (stroffs i) 0 1 si off 0)))))      ; stb_local stt_object
                                 locs))
           fsyms (catall (o-mapi (\ i fs (o-place fs @ w
                                            (o-vis fs (elf-sym32 (stroffs (nloc + i))
                                                     (elem fs wknames ? 2 1)         ; stb_weak vs stb_global
                                                     (o-ftyp fs) <w (<>w | tb) (o-xsize w fs)))))   ; +thumb bit
                                 funcnames))
           gsyms (catall (o-mapi (\ i gs (o-place gs @ w
                                            (o-vis gs (elf-sym32 (stroffs (nloc + nfun + i))
                                                     (elem gs wknames ? 2 1) (o-dtype gs) <w <>w (o-dsize w gs)))))
                                 globnames))
           ; an absolute symbol: stt_notype, shn_abs
           lasyms (catall (o-mapi (\ i p (elf-sym32 (stroffs (#locs + i)) 0 0 65521 <>p 0)) labss))
           asyms (catall (o-mapi (\ i p (elf-sym32 (stroffs (nloc + nfun + nglob + i)) 1 0 65521 <>p 0)) abss))
           ; a weak undef resolves to zero at static link
           esyms (catall (o-mapi (\ i e (o-vis e (elf-sym32 (stroffs (nloc + nfun + nglob + nabs + i))
                                                 (o-has? wkset e ? 2 1) 0 0 0 0)))
                                 exts))
           ssyms (catall (o-mapi (\ i l (elf-sym32 0 0 3 (i + 1) 0 0)) lanes))
           (catall [(elf-sym32 0 0 0 0 0 0) ssyms lsyms lasyms fsyms gsyms asyms esyms]))    ; the NULL symbol leads
       nsym (1 + nsec + nloc + nfun + nglob + nabs + #exts)
       ; -- the relocations, by the fixup's kind. a branch binds a symbol, never section +
       ; offset: the thumb bit rides the symbol's value and REL has no addend column. --
       (fnsym lbl) (? (o-has? wkset lbl) (peep fnidx lbl 0)
                      (o-has? locidx lbl) (peep locidx lbl 0)
                      (o-has? fnidx lbl) (peep fnidx lbl 0)
                      (o-has? globidx lbl) (peep globidx lbl 0)
                      (peep extidx lbl 0))
       (o-rels32 rs)
        (catall (map (\ [off k lbl aux _]
          (k @ ('rel32 || 'pc32) (o-rel32 off <(xsl k lbl aux) (x86 ? r-386-pc32 r-arm-rel32))
               'rel16 (o-rel32 off <(xsl k lbl aux) r-386-pc16)
               'pc8 (o-rel32 off <(xsl k lbl aux) r-386-pc8)
               'bl (o-rel32 off (fnsym lbl) r-thm-call)
               'gotprel (o-rel32 off (fnsym lbl) r-arm-gotprel)
               'b  (o-rel32 off (fnsym lbl) r-thm-jump24)   ; a B.W tail-jump to an external/weak fn
               'bcc (o-rel32 off (fnsym lbl) r-thm-jump19)  ; a Bcc.W into another section
               ('abs32 || 'abs32d) (a32k k lbl aux @ sl (o-rel32 off <sl (x86 ? r-386-32 r-arm-abs32)))
               'dabs32 (o-where wx lbl @ w (o-rel32 off <w (x86 ? r-386-32 r-arm-abs32)))
               'abs16 (a32k k lbl aux @ sl (o-rel32 off <sl r-386-16))
               'abs8 (a32k k lbl aux @ sl (o-rel32 off <sl r-386-8))
               ('movw16 || 'movt16)
                (mwloc lbl @ sl
                   (o-rel32 off <sl $ k == 'movw16 ? r-thm-movw r-thm-movt))
               ; lap's target is a symbol of its own: its field already holds the addend
               ('movw16p || 'movt16p)
                (mwloc lbl @ sl
                   (<>sl != 0 ? (scare 'obj32-lap-offset lbl)
                      (o-rel32 off <sl $ k == 'movw16p ? r-thm-movwp r-thm-movtp)))
               (scare 'obj32-reloc k)))
          rs))
       rels (map (o-rels32 * ln-rl) lanes)
       (rcnt i) #(ln-rl (ln i))
       shnames (map cap lanes
                + '(".symtab" ".strtab")
                + map (l \ ".rel" + <l) lanes
                + '(".shstrtab"))
       shstr (o-strtab shnames)
       shstrblob <shstr shoffs (o-rows <>shstr)
       shname shoffs
       ; -- file layout: header, section contents packed tight, then the sht. the indices:
       ; 0 NULL, the content sections, .symtab, .strtab, a .rel per content section, .shstrtab --
       i-sym (1 + nsec) i-str (2 + nsec)
       i-shs (2 * nsec + 3) nsh (2 * nsec + 4)
       h-sz 52
       (o-offs32 i off acc) (nsec <= i ? [(rev acc) off]
                               (o-offs32 (i + 1) (off + ln-fsz (ln i)) (off . acc)))
       co (o-offs32 0 h-sz ())    coffs (o-rows <co)
       sym-off <>co               sym-sz (nsym * 16)
       str-off (sym-off + sym-sz) str-sz #strblob
       (o-roffs32 i off acc) (nsec <= i ? [(rev acc) off]
                                (o-roffs32 (i + 1) (off + rcnt i * 8) (off . acc)))
       ro (o-roffs32 0 (str-off + str-sz) ())   roffs (o-rows <ro)
       shs-off <>ro               shs-sz #shstrblob
       sht-off (shs-off + shs-sz)
       sht (catall ([(o-zeros 40)]                                             ; 0 NULL
              + o-mapi (\ i l (elf-shdr32 (shname i) (ln-ty l) (l 2 & 4294967295)   ; 1..nsec the content sections
                                    0 (coffs i) (o-blen (ln-bs l)) 0 0 (l 3) (l 2 >> 32)))
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
       (elf-order machine
        (catall ([hdr]
                 + o-mapi (i \ l \ ln-ty l != 8 && lbytes i) lanes       ; a NOBITS lane writes nothing
                 + [symbytes strblob]
                 + rels
                 + [shstrblob sht]))))

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
   (objsec-named nm forms ro) [nm 1 (? (ro = 'lo) 131 ro 2 3) (o-dalign 1 forms) forms]   ; 'lo: wa, link order
   ; ..and the code twin, for a function that named its own section; flags 6 = alloc|execinstr.
   ; the grain is the caller's: one-fn sections at grain N tile at N (love.h's love_typ stride).
   (objsec-code nm forms al) [nm 1 6 al forms]
   ; a data section's alignment pads with zeros, not the backend's nop
   (o-dal fm) (map (f \ (two? f && <f == 'align ? ('dalign . >f) f)) fm)
   ; a file-scope asm's sections, (name type flags forms) each: a name already laid takes the
   ; forms at its tail and keeps its own flags, a new one rides after the rest
   (objsec-merge secs xs)
    (: more {} inn (foldl (\ t s (pin t <s 1)) {} secs)       ; a name's asm sections, latest first
       news (foldl (\ a x (: l (more <x)
                             (pin more <x (x . l), (atom? l && !(inn <x) ? (x . a) a))))
                   () xs)
       (grown nm al f) (rev (more nm) @ l
                          [(foldl (\ a x (o-dalign a (x 3))) al l) (catall (f . map (x \ x 3) l))])
       (map (s \ (grown <s (s 3) (s 4) @ g [<s (s 1) (s 2) <g <>g])) secs
        + map (x \ (grown <x 1 () @ g [<x (x 1) (x 2) <g <>g])) (rev news)))
   ; the .ARM.attributes an arm32 object owes its linker, which refuses a pair that cannot
   ; merge. an unstated tag reads 0 and disarms the check; ld compares VFP_args only where
   ; Tag_ABI_FP_number_model (23) says floats are used.
   ; format: 'A', le32 over all that follows, "aeabi\0", Tag_File (1) with its own le32 length,
   ; then (tag value) uleb128 pairs, a string value NUL-terminated; all here are under 128.
   ; vfp 0 is -mfloat-abi=soft: floats pass in core registers, base aapcs
   (armattrs t vfp)
    (: t1 (t == 'thumb1) a? (aprofile? t)                      ; linux's arm: the fpv5 set is armv8's aarch32
       pairs ('(5) + o-strbytes (? t1 "6-M" a? "8-A" "7E-M") + '(0)   ; Tag_CPU_name
              + [6 (? t1 11 a? 14 13)]                         ; Tag_CPU_arch: v6-M | v8 | v7E-M
              + [7 (a? ? 65 77)]                               ; Tag_CPU_arch_profile: 'A' | 'M'
              + [9 (t1 ? 1 2)]                                 ; Tag_THUMB_ISA_use: 1 | 2
              + (? (t == 'thumb2 || a?) '(10 8)                ; Tag_FP_arch: FPv5/FP-D16
                   (t == 'thumb2sp) '(10 6 27 1) ())           ; ..VFPv4-D16, and SP only
              + '(18 4)                                        ; Tag_ABI_PCS_wchar_t
              + '(23 3)                                        ; Tag_ABI_FP_number_model: IEEE 754
              + '(26 1)                                        ; Tag_ABI_enum_size: small
              + (t1 ? () [28 vfp]))                            ; Tag_ABI_VFP_args: VFP regs | base
       sub ('(1) + le32 (5 + #pairs) + pairs)             ; Tag_File, over its own length
       ('(65) + le32 (10 + #sub) + o-strbytes "aeabi" + '(0) + sub))

   ; the elf32 twin of objsecs4. arm code sits at grain 4, flash being scarce; .bss rides as
   ; NOBITS since these ports zero it themselves.
   (objsecs3 target textforms dataforms nifforms imgforms bssforms rodataforms)
    ([[".text"   1 6 (i386? target ? 16 4) textforms]
      [".rodata" 1 2 (o-dalign 4 rodataforms) rodataforms]
      [".data"   1 3 (o-dalign 4 dataforms) dataforms]
      [".bss"    8 3 (o-dalign 4 bssforms) bssforms]]
     + (two? nifforms ? [["love_nifs" 1 3 4 nifforms]] ())
     + (two? imgforms ? [[".love.image" 1 3 16 imgforms]] ())
     + (i386? target ? () [[".ARM.attributes" 1879048195 0 1 [['raw (armattrs target 1)]]]]))   ; SHT_ARM_ATTRIBUTES
   ; the same under -mfloat-abi=soft
   (armsoft target secs) (map (s \ (<s = ".ARM.attributes" ? [<s (s 1) (s 2) (s 3) [['raw (armattrs target 0)]]] s)) secs)

   (objelf target0 textforms dataforms funcnames globnames wknames nifforms imgforms locnames bssforms rodataforms)
    (arch-nom target0 @ target
       (elf32? target ?
         (objsecs32 target (objsecs3 target textforms dataforms nifforms imgforms bssforms rodataforms)
                    funcnames globnames wknames)          ; locnames unrepresented on elf32
         (objsecs target (objsecs4 textforms dataforms nifforms imgforms bssforms rodataforms)
                  funcnames globnames wknames locnames)))

   ; -- a64's .eh_frame, as clang lays it under -fasynchronous-unwind-tables: one CIE, then an
   ; FDE per function named, its rows read off the laid words. a walk from the entry along the
   ; branches gives every word a frame state, and a row opens wherever the state changes.
   ; a state is (reg off sp fp saves ra pro): the cfa is reg+off; sp and fp how far the cfa
   ; sits above each, () unknown; saves ((dwreg slot) ..), slots cfa-relative; ra 1 while lr
   ; is signed; pro what the entry's straight line has written, or 'body past its first branch
   ; or call, where a store saves nothing --
   ; "zR", code factor 1, data -4, ra x30, pointers pcrel sdata4; the cfa sp+0
   o-cie [16 0 0 0 0 0 0 0 1 122 82 0 1 124 30 1 27 12 31 0]
   o-st0 [31 0 0 () () 0 ()]
   (o-sx v n) (v >= 1 << (n - 1) ? (v - (1 << n)) v)
   (o-w32 s o) (s o | (s (o + 1) << 8) | (s (o + 2) << 16) | (s (o + 3) << 24))
   (o-flat l) (catmap (x \ (string? x ? (map x ^#x) [x])) l)
   ; the registers a callee saves: x19-x30 and d8-d15 (dwarf 72-79)
   (o-cs? r) (19 <= r && r <= 30 || 72 <= r && r <= 79)
   ; a word's effect on the state; nm names the function a refusal blames
   (o-ehst st w nm)
    (@ st [cb co sd fd sv ra pw]
       (: rt (w & 31) rn ((w >> 5) & 31) rt2 ((w >> 10) & 31)
          pro (pw != 'body)
          (mk cb co sd fd sv ra pw) [cb co sd fd sv ra pw]
          ; where a base register points, cfa-relative
          (at r) (? (r = 31) (sd = () ? () (0 - sd)) (r = 29) (fd = () ? () (0 - fd)) ())
          (wrote st r) (@ st [cb co sd fd sv ra pw] (mk cb co sd fd sv ra (pro ? (r . pw) pw)))
          ; x29 written: a cfa on it moves to sp
          (fpw st f)
           (@ st [cb co sd fd sv ra pw]
              (? (cb != 29) (mk cb co sd f sv ra pw)
                 (sd = ()) (scare 'obj-eh-fp nm)
                 (mk 31 sd sd f sv ra pw)))
          (spw st d)
           (@ st [cb co sd fd sv ra pw]
              (? (cb != 31) (mk cb co d fd sv ra pw)
                 (d = ()) (scare 'obj-eh-sp nm)
                 (mk 31 d d fd sv ra pw)))
          (wr st r) (wrote (r = 29 ? (fpw st ()) st) r)
          ; a store of a register the entry still holds is its save
          (sav st r a)
           (@ st [cb co sd fd sv ra pw]
              (? (pro && a != () && o-cs? r && (nelem r pw) && !(any (p \ <p = r) sv))
                 (mk cb co sd fd (sort ([r a] . sv)) ra pw)
                 st))
          ; a load back from its slot restores it
          (rst st r a) (@ st [cb co sd fd sv ra pw] (wr (mk cb co sd fd (filter (p \ p != [r a]) sv) ra pw) r))
          (wb st r d) (? (r = 31) (spw st (sd = () ? () (sd - d))) (r = 29) (fpw st (fd = () ? () (fd - d))) st)
          (body st) (@ st [cb co sd fd sv ra pw] (mk cb co sd fd sv ra 'body))
          (? ; a pair: stp/ldp, writeback or not
             ((w & 0x3A000000) = 0x28000000)
              (: opc (w >> 30) v ((w >> 26) & 1) md ((w >> 23) & 3) ld ((w >> 22) & 1)
                 sc (v = 1 ? (4 << opc) (opc = 2 ? 8 4))
                 imm (o-sx ((w >> 15) & 127) 7 * sc)
                 a (at rn) ea (a = () ? () (md = 1 ? a (a + imm)))
                 wide (v = 0 && opc = 2 || v = 1 && opc = 1)
                 (dw r) (v = 1 ? (64 + r) r)
                 e2 (ea = () ? () (ea + 8))
                 s2 (? (ld = 0) (wide ? (sav (sav st (dw rt) ea) (dw rt2) e2) st)
                       (rst (rst st (dw rt) (wide ? ea)) (dw rt2) (wide ? e2)))
                 (md = 1 || md = 3 ? (wb s2 rn imm) s2))
             ; one register, an unsigned offset, or nine signed bits (plain, post, pre)
             ((w & 0x3B000000) = 0x39000000 || (w & 0x3B200000) = 0x38000000)
              (: sz (w >> 30) v ((w >> 26) & 1) opc ((w >> 22) & 3)
                 sc (v = 1 && opc >= 2 ? 16 (1 << sz))
                 u ((w & 0x3B000000) = 0x39000000)
                 ix (u ? 2 ((w >> 10) & 3))
                 off (u ? (((w >> 10) & 4095) * sc) (o-sx ((w >> 12) & 511) 9))
                 a (at rn) ea (a = () || ix = 1 ? a (a + off))
                 wide (sz = 3 && (v = 0 || opc < 2))
                 r (v = 1 ? (64 + rt) rt)
                 s2 (? (ix = 2 && !u) (opc = 0 ? st (wr st r))         ; unprivileged
                       (opc = 0 || v = 1 && opc = 2) (wide ? (sav st r ea) st)
                       (rst st r (wide ? ea)))
                 (ix = 1 || ix = 3 ? (wb s2 rn off) s2))
             ; add/sub immediate: sp and x29 as either end
             ((w & 0x1F800000) = 0x11000000)
              (: s ((w >> 29) & 1) v (((w >> 10) & 4095) << (((w >> 22) & 1) * 12))
                 d ((w >> 30) & 1 = 1 ? (0 - v) v)
                 (from r) (? (r = 31) (sd = () ? () (sd - d)) (r = 29) (fd = () ? () (fd - d)) ())
                 (? (s = 1) (rt = 31 ? st (wr st rt))
                    (rt = 31) (spw st (from rn))
                    (rt = 29)
                     (: f (from rn) s2 (wrote (fpw st f) 29)
                        ; mov x29, sp over the saved frame record: the cfa rides fp
                        (@ s2 [cb co sd fd sv ra pw]
                           (cb = 31 && f != () && any (p \ <p = 29) sv ? (mk 29 f sd f sv ra pw) s2)))
                    (wr st rt)))
             ; add/sub extended register, logical immediate: rd 31 is sp
             ((w & 0x1FE00000) = 0x0B200000 && (w >> 29) & 1 = 0 && rt = 31) (spw st ())
             ((w & 0x1F800000) = 0x12000000 && (w >> 29) & 3 != 3 && rt = 31) (spw st ())
             ; pac-ret's sign and authenticate, a key and sp's modifier; the others no unwinder reads
             (w = 0xD503233F) (mk cb co sd fd sv 1 pw)
             (w = 0xD50323BF) (mk cb co sd fd sv 0 pw)
             (elem w [0xD503237F 0xD50323FF 0xD503231F 0xD503239F 0xD503235F 0xD50323DF]) (scare 'obj-eh-pac nm)
             ; a branch or a call ends the entry's straight line; mrs writes its rt
             ((w & 0x7C000000) = 0x14000000 || (w & 0x7C000000) = 0x34000000 || (w & 0xFF000010) = 0x54000000
              || (w & 0xFE000000) = 0xD6000000)
              ((w & 0xFC000000) = 0x94000000 || (w & 0xFFFFFC1F) = 0xD63F0000 ? (body (wrote st 30)) (body st))
             ((w & 0xFFF00000) = 0xD5300000) (wr st rt)
             ((w & 0x1C000000) = 0x14000000) st
             ; anything else writing rd: data processing, fp/simd, a literal or exclusive load
             ((w & 0x1C000000) = 0x10000000 || (w & 0x0E000000) = 0x0A000000) (wr st rt)
             ; a convert or a move to the integer file, an element's, else an fp rd
             ((w & 0x0E000000) = 0x0E000000)
              (: op ((w >> 16) & 7)
                 gp (? ((w & 0x7F20FC00) = 0x1E200000) (op < 2 || op = 4 || op = 5 || op = 6)
                       ((w & 0x7F200000) = 0x1E000000) (op < 2)
                       ((w & 0xBFE08400) = 0x0E000400) (elem ((w >> 11) & 15) '(5 7)))
                 (gp ? (wr st rt) (wrote st (64 + rt))))
             ((w & 0x0A000000) = 0x08000000)
              (? ((w >> 22) & 1 = 0 && (w & 0x3B000000) != 0x18000000) st
                 ((w >> 26) & 1 = 1) (wrote st (64 + rt))
                 (wr st rt))
             st)))
   ; a word's successors within lo..hi; rl the offsets a branch relocation patches (an external target)
   (o-ehnx w pc lo hi rl)
    (: (to imm n) (elem pc rl ? () (pc + o-sx imm n * 4 @ t (lo <= t && t < hi ? [t] ())))
       nx (pc + 4 < hi ? [(pc + 4)] ())
       (? ((w & 0xFC000000) = 0x14000000) (to (w & 0x3FFFFFF) 26)                             ; b: in reach, else a tail call
          ((w & 0xFF000010) = 0x54000000 || (w & 0x7E000000) = 0x34000000) (nx + to ((w >> 5) & 0x7FFFF) 19)   ; b.cond, cbz
          ((w & 0x7E000000) = 0x36000000) (nx + to ((w >> 5) & 0x3FFF) 14)                     ; tbz
          ((w & 0xFFFFFC1F) = 0xD65F0000 || w = 0xD65F0BFF || w = 0xD65F0FFF) ()            ; ret, retaa, retab
          ((w & 0xFFFFFC1F) = 0xD61F0000 || (w & 0xFFE0001F) = 0xD4200000 || w < 65536) ()  ; br, brk, udf
          nx))
   ; -- x64's, the same walk over decode.l's reading of each instruction. "zR", code factor 1,
   ; data -8, ra rip (16), pointers pcrel sdata4; the cfa rsp+8, rip at cfa-8. a state's
   ; registers are dwarf's: rsp 7, rbp 6 --
   x-cie [20 0 0 0 0 0 0 0 1 122 82 0 1 120 16 1 27 12 7 8 144 1 0 0]
   x-st0 [7 8 8 () () 0 ()]
   x-dw [0 2 1 3 7 6 4 5 8 9 10 11 12 13 14 15]          ; an encoding's dwarf number
   (x-cs? r) (elem r '(3 6 12 13 14 15))                  ; rbx rbp r12-r15
   x-jcc '(jo jno jb jae je jne jbe ja js jns jp jnp jl jge jle jg)   ; decode.l's sixteen
   ; an instruction's effect on the state, it its decoded (op mn w operands)
   (x-ehst st it nm)
    (@ st [cb co sd fd sv ra pw]
       (: mn (it 1) os (it 3)
          pro (pw != 'body)
          (mk cb co sd fd sv pw) [cb co sd fd sv ra pw]
          (neg v) (v = () ? () (0 - v))
          (at st r) (? (r = 7) (neg (st 2)) (r = 6) (neg (st 3)) ())
          (wrote st r) (@ st [cb co sd fd sv _ pw] (mk cb co sd fd sv (pro ? (r . pw) pw)))
          (fpw st f)
           (@ st [cb co sd fd sv _ pw]
              (? (cb != 6) (mk cb co sd f sv pw)
                 (sd = ()) (scare 'obj-eh-fp nm)
                 (mk 7 sd sd f sv pw)))
          (spw st d)
           (@ st [cb co sd fd sv _ pw]
              (? (cb != 7) (mk cb co d fd sv pw)
                 (d = ()) (scare 'obj-eh-sp nm)
                 (mk 7 d d fd sv pw)))
          (wr st r) (wrote (? (r = 6) (fpw st ()) (r = 7) (spw st ()) st) r)
          (sav st r a)
           (@ st [cb co sd fd sv _ pw]
              (? (pro && a != () && x-cs? r && (nelem r pw) && !(any (p \ <p = r) sv))
                 (mk cb co sd fd (sort ([r a] . sv)) pw)
                 st))
          (rst st r a) (@ st [cb co sd fd sv _ pw] (wr (mk cb co sd fd (filter (p \ p != [r a]) sv) pw) r))
          (down st d) (spw st (st 2 = () ? () (st 2 + d)))                   ; rsp lowered by d
          (from st r) (? (r = 7) (st 2) (r = 6) (st 3) ())                    ; how far the cfa sits above r
          (body st) (@ st [cb co sd fd sv _ _] (mk cb co sd fd sv 'body))
          (q o) (o @ ['rg k 8] (x-dw k) _ ())                                 ; a whole register's number
          (anyr o) (o @ ['rg k w] (? (w = 16) () (k < 16) (x-dw k) (x-dw (k - 20))) _ ())   ; ..any width's, ah-bh too; no xmm
          (mb o) (o @ ['mem mbr -1 _ mdk] (0 <= mbr < 16 ? [(x-dw mbr) mdk] ()) _ ())   ; a plain base and displacement
          ; mov rbp, rsp over the pushed rbp: the cfa rides rbp
          (link st) (@ st [cb co sd fd sv _ pw] (cb = 7 && fd != () && any (p \ <p = 6) sv ? (mk 6 fd sd fd sv pw) st))
          d (two? os ? <os) s2 (two? os && two? >os ? <>os)
          (? (elem mn '(call jmp ret)) (body st)
             (elem mn x-jcc) (body st)
             (mn = 'push) (: r (q d) a (at st 7) s1 (down st 8)
                             (r != () ? (sav s1 r (a = () ? () (a - 8))) s1))
             (mn = 'pop) (: r (q d) a (at st 7) s1 (down st -8)
                            (r != () ? (rst s1 r a) (anyr d @ k (k != () ? (wr s1 k) s1))))
             (mn = 'leave) (: s1 (spw st (st 3)) a (at s1 7) (rst (down s1 -8) 6 a))
             (elem mn '(sub add) && q d = 7 && two? s2 && <s2 = 'im)
              (down st (mn = 'sub ? <>s2 (0 - <>s2)))
             (mn = 'mov && q d = 6 && q s2 = 7) (link (wrote (fpw st (st 2)) 6))
             (mn = 'mov && q d = 7 && q s2 = 6) (spw st (st 3))
             (mn = 'lea && q d = 7 && mb s2 != ()) (mb s2 @ [b k] (from st b @ f (spw st (f = () ? () (f - k)))))
             (mn = 'lea && q d = 6 && mb s2 != ())
              (mb s2 @ [b k] (from st b @ f (link (wrote (fpw st (f = () ? () (f - k))) 6))))
             ; a whole register stored to a frame slot is its save, loaded back its restore
             (mn = 'mov && mb d != () && q s2 != ()) (mb d @ [b k] (at st b @ a (sav st (q s2) (a = () ? () (a + k)))))
             (mn = 'mov && q d != () && mb s2 != ()) (mb s2 @ [b k] (at st b @ a (rst st (q d) (a = () ? () (a + k)))))
             (mn = 'xchg) (foldl (\ st o (anyr o @ k (k != () ? (wr st k) st))) st os)
             (mn = 'cpuid) (foldl wr st '(0 1 2 3))
             (elem mn '(cmp test bt nop)) st
             (anyr d @ k (k != () ? (wr st k) st)))))
   ; the instruction at pc: [state successors indirect?]; one decode.l cannot read refuses
   (x-ehstep s pc st nm lo hi rl)
    (: d (x64-decode s pc) n <d it (last >d)
       (!(two? it) || <it != 'op ? (scare 'obj-eh-x64 [nm pc])
          (: mn (it 1) os (it 3) nx (pc + n < hi ? [(pc + n)] ())
             t (two? os ? (<os @ ['lbl t] t _ ()))
             ; a branch the linker patches is to another function: a tail call, no successor here
             to (? (t = () || elem (pc + n - 4) rl) () (lo <= t && t < hi) [t] ())
             ind (mn = 'jmp && two? os && two? <os && <<os = 'ind)
             [(x-ehst st it nm)
              (? (elem mn '(ret ud2)) () (mn = 'jmp) to (elem mn x-jcc) (nx + to) nx)
              ind])))
   ; -- rv64's, over a reading of each instruction. .debug_frame only: code factor 1, data -8, ra
   ; x1, the cfa sp+0. a state is as above but its sixth slot, unused, and its last, (t6 . pro):
   ; t6 ('k n) a constant, ('a n) an address, cfa-relative, else () --
   rv-dcie [12 0 0 0 255 255 255 255 1 0 1 120 1 12 2 0]
   rv32-dcie [12 0 0 0 255 255 255 255 1 0 1 124 1 12 2 0]
   rv-st0 [2 0 0 () () 0 '(() . ())]
   ; rv64.l's r0.. and f0.., dwarf's numbers
   rv-dwr [10 11 12 13 14 15 16 17 5 6 7 28 29 18 19 9 0 0 0 20 21 22 23 24 25 26 27]
   rv-dwf [42 43 44 45 46 47 48 49 32 33 34 35 36 37 38 39 60 61 62 63]
   (rv-cs? r) (elem r '(1 8 9 18 19 20 21 22 23 24 25 26 27 40 41 50 51 52 53 54 55 56 57 58 59))
   ; an instruction, read: (length kind ..), 'ld and 'sd a whole register's, x32 rv32's. f registers are 32 and up
   (rv-ehdec x32 s pc)
    (: h (s pc | (s (pc + 1) << 8))
       (bt i n) ((h >> i) & ((1 << n) - 1))
       (pr i) (8 + bt i 3)
       cj (o-sx ((bt 12 1 << 11) | (bt 11 1 << 4) | (bt 9 2 << 8) | (bt 8 1 << 10) | (bt 7 1 << 6) | (bt 6 1 << 7) | (bt 3 3 << 1) | (bt 2 1 << 5)) 12)
       cb (o-sx ((bt 12 1 << 8) | (bt 10 2 << 3) | (bt 5 2 << 6) | (bt 3 2 << 1) | (bt 2 1 << 5)) 9)
       rd (bt 7 5) r2 (bt 2 5) im6 (o-sx ((bt 12 1 << 5) | r2) 6) f3 (h >> 13)
       (? (h & 3 != 3)
          (2 . (h & 3 @
             0 (: o8 ((bt 10 3 << 3) | (bt 5 2 << 6))
                  (h = 0 ? ['trap]
                     f3 = 0 ? ['addi (pr 2) 2 ((bt 7 4 << 6) | (bt 11 2 << 4) | (bt 5 1 << 3) | (bt 6 1 << 2))]
                     f3 = 1 ? ['ld (32 + pr 2) (pr 7) o8]
                     f3 = 2 ? (x32 ? ['ld (pr 2) (pr 7) ((bt 10 3 << 3) | (bt 6 1 << 2) | (bt 5 1 << 6))] ['wr (pr 2)])
                     f3 = 3 ? (x32 ? ['no] ['ld (pr 2) (pr 7) o8])
                     f3 = 6 && x32 ? ['sd (pr 2) (pr 7) ((bt 10 3 << 3) | (bt 6 1 << 2) | (bt 5 1 << 6))]
                     f3 = 5 ? ['sd (32 + pr 2) (pr 7) o8]
                     f3 = 7 && !x32 ? ['sd (pr 2) (pr 7) o8] ['no]))
             1 (f3 = 0 ? ['addi rd rd im6]
                f3 = 1 ? (x32 ? ['jal 1 cj] ['addiw rd rd im6])
                f3 = 2 ? ['addi rd 0 im6]
                f3 = 3 ? (rd = 2 ? ['addi 2 2 (o-sx ((bt 12 1 << 9) | (bt 6 1 << 4) | (bt 5 1 << 6) | (bt 3 2 << 7) | (bt 2 1 << 5)) 10)]
                                   ['lui rd (im6 << 12)])
                f3 = 4 ? ['wr (pr 7)]
                f3 = 5 ? ['jal 0 cj]
                ['br cb])
             (f3 = 0 ? ['wr rd]
              f3 = 1 ? ['ld (32 + rd) 2 ((bt 12 1 << 5) | (bt 5 2 << 3) | (bt 2 3 << 6))]
              f3 = 2 ? (x32 ? ['ld rd 2 ((bt 12 1 << 5) | (bt 4 3 << 2) | (bt 2 2 << 6))] ['wr rd])
              f3 = 6 && x32 ? ['sd r2 2 ((bt 9 4 << 2) | (bt 7 2 << 6))]
              f3 = 3 && x32 ? ['no]
              f3 = 7 && x32 ? ['no]
              f3 = 3 ? ['ld rd 2 ((bt 12 1 << 5) | (bt 5 2 << 3) | (bt 2 3 << 6))]
              f3 = 4 ? (bt 12 1 = 0 ? (r2 = 0 ? ['jalr 0 rd] ['add rd 0 r2])
                        rd = 0 ? ['trap] r2 = 0 ? ['jalr 1 rd] ['add rd rd r2])
              f3 = 5 ? ['sd (32 + r2) 2 ((bt 10 3 << 3) | (bt 7 3 << 6))]
              f3 = 7 ? ['sd r2 2 ((bt 10 3 << 3) | (bt 7 3 << 6))]
              ['no])))
          (: w (o-w32 s pc) op (w & 127) d ((w >> 7) & 31) g3 ((w >> 12) & 7) a ((w >> 15) & 31) b ((w >> 20) & 31)
             i (o-sx (w >> 20) 12) si (o-sx (((w >> 25) << 5) | d) 12) f7 (w >> 25)
             (4 . (op @
               0x13 (g3 = 0 ? ['addi d a i] ['wr d])
               0x1B (g3 = 0 ? ['addiw d a i] ['wr d])
               0x33 (g3 = 0 && f7 = 0 ? ['add d a b] g3 = 0 && f7 = 32 ? ['sub d a b] ['wr d])
               0x37 ['lui d (o-sx (w & 0xFFFFF000) 32)]
               0x03 (g3 = (x32 ? 2 3) ? ['ld d a i] ['wr d])
               0x07 (g3 = 3 ? ['ld (32 + d) a i] ['wr (32 + d)])
               0x23 (g3 = (x32 ? 2 3) ? ['sd b a si] ['no])
               0x27 (g3 = 3 ? ['sd (32 + b) a si] ['no])
               0x6F ['jal d (o-sx (((w >> 31) << 20) | (((w >> 12) & 255) << 12) | (((w >> 20) & 1) << 11) | (((w >> 21) & 1023) << 1)) 21)]
               0x67 ['jalr d a]
               0x63 ['br (o-sx (((w >> 31) << 12) | (((w >> 7) & 1) << 11) | (((w >> 25) & 63) << 5) | (((w >> 8) & 15) << 1)) 13)]
               ; a compare, a convert or a move to the integer file, else an fp op
               0x53 ['wr (elem (f7 >> 2) '(0x14 0x18 0x1C) ? d (32 + d))]
               (0x43 || 0x47 || 0x4B || 0x4F) ['wr (32 + d)]
               0x0F ['no]
               0x73 (w = 0x100073 || w = 0xC0001073 ? ['trap] ['wr d])
               _ ['wr d])))))
   (mips-cs? r) (16 <= r <= 23 || r = 30 || r = 31)
   ; an instruction's effect, it as read; mp: whose registers, 0 rv's 1 mips's 2 thumb2's 3 thumb1's: sp, fp, the scratch and what a callee saves
   (rv-ehst mp st it nm)
    (@ st [cb co sd fd sv _ (t6 . pw)]
       (: sp ([2 29 13 13] mp) fp ([8 30 11 7] mp) sc ([31 1 12 4] mp)
          (cs? r) (mp = 0 ? (rv-cs? r) (mp = 1) (mips-cs? r) (t-cs? r))
          pro (pw != 'body)
          (mk cb co sd fd sv t6 pw) [cb co sd fd sv 0 (t6 . pw)]
          (neg v) (v = () ? () (0 - v))
          ; what a scratch register holds: an address ['a n] or a constant ['k n]. thumb1's are the low ones, by register
          (sc? r) (mp = 3 ? (r < 7) (r = sc))
          (val r) (? (!(sc? r)) () (mp = 3) (filter (p \ <p = r) t6 @ (p . _) (p 1) _ ()) t6)
          (at r) (? (r = sp) (neg sd) (r = fp) (neg fd) (val r @ ['a n] n _ ()))
          (konst r) (? (mp < 2 && r = 0) 0 (val r @ ['k n] n _ ()))
          (wrote st r) (@ st [cb co sd fd sv _ (t6 . pw)] (mk cb co sd fd sv t6 (pro ? (r . pw) pw)))
          (fpw st f)
           (@ st [cb co sd fd sv _ (t6 . pw)]
              (? (cb != fp) (mk cb co sd f sv t6 pw)
                 (sd = ()) (scare 'obj-eh-fp nm)
                 (mk sp sd sd f sv t6 pw)))
          ; a slot sp rises past is gone
          (spw st d)
           (@ st [cb co sd fd sv0 _ (t6 . pw)]
              (: sv (d = () ? sv0 (filter ([_ l] \ 0 - d <= l) sv0))
                 (? (cb != sp) (mk cb co d fd sv t6 pw)
                    (d = ()) (scare 'obj-eh-sp nm)
                    (mk sp d d fd sv t6 pw))))
          (t6w st r v) (@ st [cb co sd fd sv _ (t6 . pw)]
             (mk cb co sd fd sv (mp = 3 ? ((v = () ? () [[r v]]) + filter (p \ <p != r) t6) v) pw))
          (wr st r) (? (mp < 2 && r = 0) st (wrote (? (r = fp) (fpw st ()) (r = sp) (spw st ()) (sc? r) (t6w st r ()) st) r))
          (sav st r a)
           (@ st [cb co sd fd sv _ (t6 . pw)]
              (? (pro && a != () && cs? r && nelem r pw && !(any (p \ <p = r) sv))
                 (mk cb co sd fd (sort ([r a] . sv)) t6 pw)
                 st))
          (rst st r a) (@ st [cb co sd fd sv _ (t6 . pw)] (wr (mk cb co sd fd (filter (p \ p != [r a]) sv) t6 pw) r))
          (body st) (@ st [cb co sd fd sv _ (t6 . _)] (mk cb co sd fd sv (mp = 3 ? (filter (p \ <p = 4) t6) ()) 'body))
          ; rd = a cfa-relative address, or () for one unknown; mv s0, sp over the saved s0: the cfa rides s0
          (aset rd a)
           (? (rd = sp) (spw st (neg a))
              (rd = fp) (: s2 (wrote (fpw st (neg a)) fp)
                          (@ s2 [cb co sd fd sv _ (t6 . pw)]
                             (cb = sp && fd != () && any (p \ <p = fp) sv ? (mk fp fd sd fd sv t6 pw) s2)))
              (sc? rd && a != ()) (wrote (t6w st rd ['a a]) rd)
              (wr st rd))
          (plus a k) (a = () || k = () ? () (a + k))
          (it @ ['addi d a i] (sc? d && konst a != () ? (wrote (t6w st d ['k (konst a + i)]) d) (aset d (plus (at a) i)))
                ['addiw d a i] (sc? d && konst a != () ? (wrote (t6w st d ['k (o-sx ((konst a + i) & 0xFFFFFFFF) 32)]) d) (wr st d))
                ['ori d a i] (sc? d && konst a != () ? (wrote (t6w st d ['k (konst a | i)]) d) (wr st d))
                ['lui d v] (sc? d ? (wrote (t6w st d ['k v]) d) (wr st d))
                ['add d a b] (at a = () ? (aset d (plus (at b) (konst a))) (aset d (plus (at a) (konst b))))
                ['sub d a b] (aset d (plus (at a) (neg (konst b))))
                ['shl d a i] (sc? d && konst a != () ? (wrote (t6w st d ['k ((konst a << i) & 0xFFFFFFFF)]) d) (wr st d))
                ['sd r a i] (sav st r (plus (at a) i))
                ['ld r a i] (rst st r (plus (at a) i))
                ['wr r] (wr st r)
                (('jal || 'jalr) . d . _) (body (wr st d))
                ['br _] (body st)
                _ st)))
   ; the instruction at pc: [state successors indirect?]. a jump out of a frame is a table's, one
   ; with the entry's state a tail call
   (rv-ehstep x32 s pc st nm lo hi rl)
    (: d (rv-ehdec x32 s pc) n <d it >d nx (pc + n < hi ? [(pc + n)] ())
       (to v) (elem pc rl ? () (pc + v @ t (lo <= t && t < hi ? [t] ())))
       [(rv-ehst 0 st it nm)
        (it @ ['jal 0 v] (to v)
              ['jalr 0 _] ()
              ['br v] (nx + to v)
              ['trap] ()
              _ nx)
        (it @ ['jalr 0 a] (a != 1) _ 0)])
   ; -- mips's, the same effects over its words, big-endian: ra x31, sp x29, fp x30, at the scratch. a
   ; branch's delay slot is the nop moon lays, part of it --
   mips-dcie [0 0 0 12 255 255 255 255 1 0 1 124 31 12 29 0]
   mips-st0 [29 0 0 () () 0 '(() . ())]
   (mips-ehdec w)
    (: op (w >> 26) a ((w >> 21) & 31) b ((w >> 16) & 31) d ((w >> 11) & 31) f (w & 63)
       i (o-sx (w & 65535) 16) u (w & 65535) to (i * 4 + 4)
       (op @ 0 (f @ 8 ['jalr 0 a] 9 ['jalr d a] 13 ['trap] 0x21 ['add d a b] 0x23 ['sub d a b]
                    0x25 (b = 0 ? ['add d a 0] a = 0 ? ['add d 0 b] ['wr d])
                    _ ['wr d])
             1 (b & 16 = 0 ? ['br to] ['jal 31 to])
             2 ['jal 0 ()] 3 ['jal 31 ()]
             (4 || 5 || 6 || 7 || 20 || 21 || 22 || 23) (op = 4 && a = 0 && b = 0 ? ['jal 0 to] ['br to])
             9 ['addi b a i]
             13 (a = 0 || a = 1 && b = 1 ? ['ori b a u] ['wr b])
             15 ['lui b (o-sx (u << 16) 32)]
             17 (a = 8 ? ['br to] a = 0 || a = 2 || a = 3 ? ['wr b] ['no])
             28 ['wr d] 31 (f = 32 ? ['wr d] ['wr b])
             35 ['ld b a i] 43 ['sd b a i]
             (32 || 33 || 34 || 36 || 37 || 38 || 48) ['wr b]
             (40 || 41 || 42 || 46 || 49 || 51 || 53 || 57 || 61) ['no]
             56 ['wr b]
             _ ['wr b]))
   (mips-ehstep s pc st nm lo hi rl)
    (: (rd k) ((s k << 24) | (s (k + 1) << 16) | (s (k + 2) << 8) | s (k + 3))
       w (rd pc) it (mips-ehdec w)
       n (it @ (('jal || 'jalr || 'br) . _) 8 _ 4)
       _ (n = 8 && pc + 4 < hi && rd (pc + 4) != 0 && scare 'obj-eh-slot-mips [nm pc])
       nx (pc + n < hi ? [(pc + n)] ())
       (to v) (v = () || elem pc rl ? () (pc + v @ t (lo <= t && t < hi ? [t] ())))
       [(rv-ehst 1 st it nm)
        (it @ ['jal 0 v] (to v)
              ['jalr 0 _] ()
              ['br v] (nx + to v)
              ['trap] ()
              _ nx)
        (it @ ['jalr 0 a] (a != 31) _ 0)])
   ; -- thumb's, the same effects: ra r14, sp r13, fp r11 (thumb2) or r7 (thumb1, whose r4 holds the frame's
   ; low end). a reading: (bytes items to), items the effects in order, to a branch's target --
   t-dcie [12 0 0 0 255 255 255 255 1 0 1 124 14 12 13 0]
   t-st0 [13 0 0 () () 0 '(() . ())]
   (t-cs? r) (4 <= r && r <= 11 || r = 14 || 264 <= r && r <= 271)
   (t-list m) (filter (r \ m >> r & 1) ^16)
   ; a register list at an address: stores, or loads with r13's own move after
   (t-push rs n) (['addi 13 13 (0 - n)] . map (i \ ['sd (rs i) 13 (4 * i)]) ^#rs)
   (t-pop rs n) (map (i \ ['ld (rs i) 13 (4 * i)]) ^#rs + [['addi 13 13 n]] + (elem 15 rs ? [['ret]] ()))
   (t-wrs rs) (map (r \ ['wr r]) rs)
   ; a modified immediate
   (t-mimm v) (: b (v & 255) k (v >> 8 & 15)
                 (? (k = 0) b (k = 1) (b << 16 | b) (k = 2) (b << 24 | b << 8) (k = 3) (b << 24 | b << 16 | b << 8 | b)
                    (: x (128 | (v & 127)) r (v >> 7) ((x >> r | x << (32 - r)) & 0xFFFFFFFF))))
   (t-dec16 h)
    (: a (h & 7) b (h >> 3 & 7) d (h >> 8 & 7) i5 ((h >> 6 & 31) * 4) i8 ((h & 255) * 4)
       (one it) [2 [it] ()]
       (? (h < 0x1C00 || 0x1E00 <= h && h < 0x2000) (one (? (h < 0x0800) (h & 0xFFC0 = 0 ? ['addi a b 0] ['shl a b (h >> 6 & 31)])
                                                                   (h & 0xFE00 = 0x1800) ['add a b (h >> 6 & 7)] ['wr a]))
          (h < 0x1E00) (one (h < 0x1C00 ? ['wr a] ['addi a b (h >> 6 & 7)]))
          (h < 0x2800) (one ['lui d (h & 255)])
          (h < 0x3000) (one ['no])
          (h < 0x4000) (one ['addi d d (h < 0x3800 ? (h & 255) (0 - (h & 255)))])
          (h < 0x4400) (one (elem (h >> 6 & 15) '(8 10 11) ? ['no] ['wr a]))
          (h < 0x4800) (: rd (a | (h >> 4 & 8)) rm (h >> 3 & 15) k (h >> 8 & 3)
                          (? (k = 1) (one ['no])
                             (k = 3) (one (h & 128 ? ['call] rm = 14 ? ['ret] ['jump]))
                             (rd = 15) (one ['jump])
                             (one (k = 2 ? ['addi rd rm 0] ['add rd rd rm]))))
          (h < 0x5000) (one ['wr d])
          (h < 0x6000) (one (3 <= (h >> 9 & 7) ? ['wr a] ['no]))
          (h < 0x6800) (one ['sd a b i5])
          (h < 0x7000) (one ['ld a b i5])
          (h < 0x9000) (one (h & 0x0800 ? ['wr a] ['no]))
          (h < 0x9800) (one ['sd d 13 i8])
          (h < 0xA000) (one ['ld d 13 i8])
          (h < 0xA800) (one ['wr d])
          (h < 0xB000) (one ['addi d 13 i8])
          (h < 0xB080) (one ['addi 13 13 ((h & 127) * 4)])
          (h < 0xB100) (one ['addi 13 13 (0 - (h & 127) * 4)])
          (h & 0xF500 = 0xB100) [2 [['br]] (4 + ((h >> 9 & 1) << 6 | (h >> 3 & 31) << 1))]
          (h & 0xFE00 = 0xB400) (: rs (t-list (h & 255 | (h & 256) << 6)) [2 (t-push rs (4 * #rs)) ()])
          (h & 0xFE00 = 0xBC00) (: rs (t-list (h & 255 | (h & 256) << 7)) [2 (t-pop rs (4 * #rs)) ()])
          (h < 0xBB00) (one (h & 0xF600 = 0xB600 ? ['no] ['wr a]))
          (h < 0xC000) (one ['no])
          (h < 0xC800) (one ['wr d])
          (h < 0xD000) [2 (t-wrs (d . t-list (h & 255))) ()]
          (h < 0xDE00) [2 [['br]] (4 + o-sx (h & 255) 8 * 2)]
          (h < 0xDF00) (one ['trap])
          (h < 0xE000) (one ['no])
          [2 [['jmp]] (4 + o-sx (h & 2047) 11 * 2)]))
   (t-dec32 h k)
    (: a (h & 15) rt (k >> 12) rd (k >> 8 & 15) i12 (k & 4095) i8 (k & 255)
       (all its) [4 its ()]
       (one it) (all [it])
       (sgn u) (u ? i8 (0 - i8))
       (? (k & 0x8000 && h & 0xF800 = 0xF000)
           (: s (h >> 10 & 1) j1 (k >> 13 & 1) j2 (k >> 11 & 1)
              (? (k & 0x9000 = 0x9000)
                  [4 [[(k & 0x4000 ? 'bl 'jmp)]] (4 + o-sx (s << 24 | (1 - (j1 ^ s)) << 23 | (1 - (j2 ^ s)) << 22 | (h & 1023) << 12 | (k & 2047) << 1) 25)]
                 (h & 0x0380 != 0x0380)
                  [4 [['br]] (4 + o-sx (s << 20 | j2 << 19 | j1 << 18 | (h & 63) << 12 | (k & 2047) << 1) 21)]
                 (h & 0xFFF0 = 0xF7F0) (one ['trap])
                 (one (h & 0xFFE0 = 0xF3E0 ? ['wr rd] ['no]))))
          (h = 0xE92D) (: rs (t-list k) (all (t-push rs (4 * #rs))))
          (h = 0xE8BD) (: rs (t-list k) (all (t-pop rs (4 * #rs))))
          (h & 0xFFF0 = 0xE8D0 && k & 0xFFE0 = 0xF000) (one ['jump])
          (h & 0xFF70 = 0xE940) (all [['sd rt a (4 * sgn (h & 128))] ['sd rd a (4 * sgn (h & 128))]])
          (h & 0xFE00 = 0xE800)
           (? (h & 0x0040 = 0) (h & 16 ? (all (t-wrs (t-list k + (h & 32 ? [a] ()))))
                                  (one (h & 32 ? ['wr a] ['no])))
              ; a pair or an exclusive: what it may write
              (h & 16) (all (t-wrs [rt rd] + (h & 32 ? [['wr a]] ())))
              (all (t-wrs ((h & 32 ? [a] ()) + (h & 0xFFF0 = 0xE840 ? [rd] h & 0xFFF0 = 0xE8C0 ? [(k & 15)] ())))))
          (h & 0xFFEF = 0xEA4F && k & 0x70F0 = 0) (one ['addi rd (k & 15) 0])
          (h & 0xFE00 = 0xEA00)
           (? (rd = 15) (one ['no])
              (elem (h >> 5 & 15) '(8 13) && k & 0x70F0 = 0) (one [(h >> 5 & 15 = 8 ? 'add 'sub) rd a (k & 15)])
              (one ['wr rd]))
          (h & 0xFF30 = 0xED00 && k & 0x0F00 = 0x0B00) (one ['sd (256 + (rt | (h >> 2 & 16))) a (4 * sgn (h & 128))])
          (h & 0xFF30 = 0xED10 && k & 0x0F00 = 0x0B00) (one ['ld (256 + (rt | (h >> 2 & 16))) a (4 * sgn (h & 128))])
          (h & 0xFC00 = 0xEC00)
           (? (h & 0xFFE0 = 0xEC40) (h & 16 ? (all (t-wrs [rt a])) (one ['no]))
              (h & 0xFE00 = 0xEC00 || h & 0xFF00 = 0xED00) (one (h & 32 ? ['wr a] ['no]))
              (h & 0xFF10 = 0xEE10 && k & 0x10 && rt != 15) (one ['wr rt])
              (one ['no]))
          ; add and sub of an immediate, plain and modified
          (: m (h & 0xFBF0) v ((h >> 10 & 1) << 11 | (k >> 12 & 7) << 8 | i8)
             (? (m = 0xF200) (one ['addi rd a v])
                (m = 0xF2A0) (one ['addi rd a (0 - v)])
                (h & 0xF800 = 0xF000)
                 (? (rd = 15) (one ['no])
                    (m & 0xFFEF = 0xF100) (one ['addi rd a (t-mimm v)])
                    (m & 0xFFEF = 0xF1A0) (one ['addi rd a (0 - t-mimm v)])
                    (one ['wr rd]))
                (h & 0xFE00 = 0xF800)
                 (: ld (h & 16) word (h & 0x0160 = 0x0040)
                    off (? (h & 128) i12 (k & 0x0F00 = 0x0C00) (0 - i8) ())
                    up (k & 0x0900 = 0x0900 && !(h & 128) ? 1)
                    mv (k & 0x0200 ? i8 (0 - i8))
                    ac (off @ () (ld ? ['wr rt] ['no]) (? (word && a != 15) [(ld ? 'ld 'sd) rt a off] ld ['wr rt] ['no]))
                    (? (ld && rt = 15) (all (word && up && a = 13 ? (['ld 15 13 0] . [['addi 13 13 mv] ['ret]]) [['jump]]))
                       (up && word && k & 0x0400) (all [['addi a a mv] [(ld ? 'ld 'sd) rt a 0]])
                       (up && word) (all [[(ld ? 'ld 'sd) rt a 0] ['addi a a mv]])
                       up (all ((ld ? [['wr rt]] ()) + [['wr a]]))
                       (one ac)))
                (h & 0xFF80 = 0xFB80) (all (t-wrs [rt rd]))
                (one ['wr rd])))))
   (t-ehstep mp s pc st nm lo hi rl)
    (: h (s pc | s (pc + 1) << 8)
       it (h < 0xE800 ? (t-dec16 h) (t-dec32 h (s (pc + 2) | s (pc + 3) << 8)))
       (@ it [n is v]
          (: nx (pc + n < hi ? [(pc + n)] ())
             to (v = () || elem pc rl ? () (pc + v @ t (lo <= t && t < hi ? [t] ())))
             ; thumb1's far jump is a bl, its target in the function and not its start
             k (: c <(last is) (c != 'bl ? c mp = 3 && two? to && <to != lo ? 'jmp 'call))
             (ef i) (i @ (('call || 'bl) . _) ['jal 14 ()] ['br] ['br 0] _ i)
             [(foldl (\ st i (rv-ehst mp st (ef i) nm)) st is)
              (? (elem k '(ret jump trap)) () (k = 'jmp) to (k = 'br) (nx + to) nx)
              (k = 'jump ? 1 0)])))
   ; what a row shows of a state: the cfa, the saves, ra
   (o-ehvis st) [(st 0) (st 1) (st 4) (st 5)]
   ; a row's dwarf from the last one's; df the CIE's data factor, as a slot's size
   (o-ehops df a b)
    (@ a [cb co sv ra]
       (@ b [cb2 co2 sv2 ra2]
          (: cfa (? (cb != cb2) ([12 cb2] + uleb co2) (co != co2) (14 . uleb co2) ())
             rs (catmap ([r l] \ (elem [r l] sv2 ? () (r < 64 ? [(192 + r)] (6 . uleb r)))) sv)
             os (catmap ([r l] \ (elem [r l] sv ? ()
                                    (l % df != 0) (scare 'obj-eh-slot l)
                                    (r < 64 && l <= 0) ((128 + r) . uleb (l // (0 - df)))
                                    ([17] + uleb r + sleb (l // (0 - df)))))
                        sv2)
             (cfa + os + rs + (ra != ra2 ? [45] ())))))
   (o-ehadv x d) (? (d < 64) [(64 + d)] (d < 256) [2 d] (d < 65536) (3 . o-u2 x d) (4 . o-u4 x d))
   (o-u2 x n) (x = 'mips ? (be16 n) (le16 n))
   (o-u4 x n) (x = 'mips ? (be32 n) (le32 n))
   ; one step of a walk: the state after the word or instruction at pc, its successors, and
   ; whether it is an indirect jump. x: the isa
   (o-ehstep x s pc st nm lo hi rl)
    (? (x = 'x64) (x-ehstep s pc st nm lo hi rl)
       (thumb2? x && thumb-framed? x) (t-ehstep 2 s pc st nm lo hi rl)
       (x = 'thumb1) (t-ehstep 3 s pc st nm lo hi rl)
       (x = 'mips) (mips-ehstep s pc st nm lo hi rl)
       (x = 'rv64 || x = 'rv32) (rv-ehstep (x = 'rv32) s pc st nm lo hi rl)
       (: w (o-w32 s pc) [(o-ehst st w nm) (o-ehnx w pc lo hi rl) ((w & 0xFFFFFC1F) = 0xD61F0000)]))
   ; paths that meet while the cfa rides fp: sp's height is lost where they differ. past the entry's
   ; straight line a save one path lacks was restored there, its slot, above fp or sp, still the entry's: kept. else ()
   (o-ehjoin a b sp)
    (: (pk st) [(st 0) (st 1) (st 3) (st 5)]
       (past st) (: p (st 6) (p = 'body || two? p && >p = 'body))
       both (uniq (sort (a 4 + b 4)))
       low (a 2 = () || b 2 = () ? (a 3) (max (a 3) (min (a 2) (b 2))))
       sv (? (a 4 = b 4) [(a 4)]
             (past a && past b && !(any ([_ l] \ l < 0 - low) both)) [both] ())
       (a 0 != sp && pk a = pk b && two? sv ? [(a 0) (a 1) (a 2 = b 2 ? (a 2) ()) (a 3) <sv (a 5) (a 6)] ()))
   ; one function's rows: s its lane's bytes, lo..hi its code, labs the lane's labels
   (o-ehrows x s lo hi rl labs nm)
    (: sts {}
       st0 (x @ 'x64 x-st0 ('rv64 || 'rv32) rv-st0 'mips mips-st0 (_ && thumb-framed? x) t-st0 _ o-st0)
       (s6 st) (take 6 st)
       ; jst: the state at a br that is no tail call, which a table's targets share
       (walk stk jst)
        (? (atom? stk) jst
           (: pc <stk st (sts pc)
              (o-ehstep x s pc st nm lo hi rl @ [st2 nxs ind]
                 (walk (foldl (\ k t (: o (sts t)
                                         (? (o = ()) (pin sts t st2, t . k)
                                            (s6 o = s6 st2) k
                                            (o-ehjoin o st2 (st0 0) @ m
                                               (? (m = ()) (scare 'obj-eh-merge [nm t])
                                                  (s6 m = s6 o) k
                                                  (pin sts t m, t . k))))))
                              >stk nxs)
                       (ind && s6 st != s6 st0 ? st2 jst)))))
       _ (pin sts lo st0)
       jst (walk [lo] ())
       ; a label no branch reached, by address: a jump table's case, in the state of its br. -g's marks are none's target
       _ (two? jst ? (filter (t \ lo < t && t < hi && sts t = ()) (map labs (filter (k \ !(starts? (show k) ".dl")) (keys labs))) @ left
                         (foldl (\ _ t (sts t = () ? (pin sts t jst, walk [t] ()) ())) () (uniq (sort left)))) 0)
       pcs (sort (keys sts))
       (foldl (\ acc pc (@ acc [cur at bs]
                          (o-ehvis (sts pc) @ n (n = cur ? acc [n pc (bs + o-ehadv x (pc - at) + o-ehops (elem x '(x64 rv64) ? 8 4) cur n)]))))
              [(o-ehvis st0) lo ()] pcs @ r (r 2)))
   ; the .eh_frame lane for the functions uw names, () where none is laid; x: the isa.
   ; df: the same rows as .debug_frame, for -g: no augmentation, each fde's cie and pc relocated
   x-dcie [20 0 0 0 255 255 255 255 1 0 1 120 16 12 7 8 144 1 0 0 0 0 0 0]
   o-dcie [12 0 0 0 255 255 255 255 1 0 1 124 30 12 31 0]
   (o-eh lanes uw x df)
    (: (at1 l) (: lb (l 6) s (string (o-flat (l 4)))
                  rl (map cap (filter (r \ elem (r 1) (x @ 'x64 '(rel32) ('rv64 || 'rv32) '(j21 cj b13 cb pcrel) 'mips '(mj26 mb16) (_ && thumb-framed? x) '(b bcc bl b16 b8 cbz) _ '(b26 b19 b14))) (l 5)))
                  ; by address, one record where names alias
                  fs (sort (filter two? (map (nm \ (: k (name nm) e (fn-end nm)
                                                    (o-has? lb k && o-has? lb e ? [(lb k) k (lb e) s rl lb] ())))
                                             uw)))
                  (filter (f \ !(any (g \ <g = <f && g 1 != f 1 && g 1 < f 1) fs)) fs))
       fns (catall (map (l \ ((l 2 & 4) = 0 ? () (at1 l))) lanes))
       (? (atom? fns) ()
          (: (one acc f)
              (@ acc [bs rs]
                 (@ f [lo k hi s rl lb]
                    ; under -g a function whose rows refuse lays no fde, and gdb unwinds it as it can
                    (: ins (df ? (trap (_ \ o-ehrows x s lo hi rl lb k) 0 (_ \ _ \ 'none)) (o-ehrows x s lo hi rl lb k))
                       fo #bs
                       (? (ins == 'none) acc
                          df (: z (elem x '(x64 a64 rv64) ? 8 4) n (4 + 2 * z + #ins) pad ((z - (4 + n) % z) % z)
                                [(bs + o-u4 x (n + pad) + le32 0 + o-zeros z + (z = 8 ? (le64 (hi - lo)) (o-u4 x (hi - lo))) + ins + o-zeros pad)
                                 ([(fo + 8) (z = 8 ? 'abs64 'abs32) k 0 0] . [(fo + 4) 'abs32 (name ".dbg.frame") 0 0] . rs)])
                          (: n (13 + #ins) pad ((4 - n % 4) % 4)
                             [(bs + le32 (n + pad) + le32 (fo + 4) + le32 0 + le32 (hi - lo) + [0] + ins + o-zeros pad)
                              ([(fo + 8) 'secrel32 k 0 0] . rs)])))))
             r (foldl one [(? df (x @ 'x64 x-dcie 'rv64 rv-dcie 'rv32 rv32-dcie 'mips mips-dcie (_ && thumb-framed? x) t-dcie _ o-dcie) (x = 'x64 ? x-cie o-cie)) ()] fns)
             (? df [".debug_frame" 1 0 8 <r (rev <>r) {(name ".dbg.frame") 0}]
                [".eh_frame" 1 2 8 <r (rev <>r) {}]))))

   ; -g's line tables, after the lay: each mark lo laid is a label .dl.K:LINE:FILE (.dlf.K: a
   ; body's `{`), each code lane with one a sequence, and a compile unit (name, dir, the lanes
   ; as its ranges) over them, a subprogram for each function laid, at its body's `{`, its
   ; types and globals. dl: (unit dir eh? (types vars sigs)), moon's dwtys; gfn the global functions
   (o-dwarf lanes dl fnl gfn isa)
    (: ; an address's size and reloc, the words in the target's order
       asz (elem isa '(x64 a64 rv64) ? 8 4) az (o-zeros asz) ak (asz = 8 ? 'abs64 'abs32)
       u2 (o-u2 isa) u4 (o-u4 isa)
       (row k o) (show k @ s (? (starts? s ".dlf.") (s @ ".dlf.\(c):\(n):\(f)" [o 0 (read c) (read n) f] ())
                                (starts? s ".dl.") (s @ ".dl.\(c):\(n):\(f)" [o 1 (read c) (read n) f] ())
                                ()))
       ; a lane's marks, (offset kind count line file label), by its index, read once
       rws (foldl (t \ i \ (: l (lanes i) lb (l 6)
                              (pin t i (? ((l 2 & 4) = 0) () (sort (filter two? (map (k \ row k (lb k) @ r (two? r ? (r + [k]))) (keys lb)))))))) {} ^#lanes)
       ; per code lane: (index length label rows), rows (offset line file) by offset. at one
       ; offset a statement's row wins over a body's, the latest laid over the rest
       (seq i l)
        (: lb (l 6)
           fo (sort (filter charm? (map (k \ peep lb (name k) ()) fnl)))
           (snap o) (foldl (\ a f (f <= o ? f a)) o fo)
           rs (rws i)
           ; a body's row moves to its function's start when it is the function's first; an
           ; inlined copy's stays where it is
           (mv l p) (? (atom? l) ()
                       (: r <l fs (snap <r)
                          ([(r 1 = 0 && p < fs ? fs <r) (r 1) (r 2) (r 3) (r 4) (r 5)] . mv >l <r)))
           (dd l) (? (atom? l) () (atom? >l) l (<<l = <<>l) (dd >l) (<l . dd >l))
           r2 (dd (sort (mv rs -1)))
           (two? r2 ? [i (o-blen (l 4)) (<r2 5) () (map (r \ [<r (r 3) (r 4)]) r2)]))
       sqs (filter two? (o-mapi (\ i l ((l 2 & 4) = 0 ? () (seq i l))) lanes))
       files (uniq (catmap (q \ map (r \ r 2) (q 4)) sqs))
       fix (foldl (\ t f (pin t f (1 + #(keys t)))) {} files)
       (str x) (o-strbytes x + [0])
       hdr ([1 1 1 251 14 13 0 1 1 1 1 0 0 0 1 0 0 1] + [0]
            + catmap (f \ str (f = "" ? <dl f) + [0 0 0]) files + [0])
       ; a sequence from its lane's start: set_address, then per row file, line, pc and copy
       (prog acc q)
        (@ acc [bs rels]
           (@ q [i n k _ rows]
              (: a0 (peep ((lanes i) 6) k 0)
                 (step st r) (@ st [b f ln pc]
                               (: f2 (fix (r 2))
                                  [(((f2 = f ? () (4 . uleb f2)) + (r 1 = ln ? () (3 . sleb (r 1 - ln)))
                                      + (<r = pc ? () (2 . uleb (<r - pc))) + [1]) . b)
                                   f2 (r 1) <r]))
                 st (foldl step [() 1 1 0] rows)
                 [(bs + [0 (asz + 1) 2] + az + catall (rev <st) + (n = st 3 ? () (2 . uleb (n - st 3))) + [0 1 1])
                  ([(#bs + 3) ak k (0 - a0) 0] . rels)])))
       pr (foldl prog [() ()] sqs)
       body (u2 4 + u4 #hdr + hdr + <pr)
       ln [".debug_line" 1 0 1 (u4 #body + body) (map (r \ (@ r [o k l a p] [(o + 10 + #hdr) k l a p])) (rev <>pr)) {(name ".dbg.line") 0}]
       ; a v5 list section's head: its length, version, address size
       (o-v5 bs) (u4 (8 + #bs) + u2 5 + [asz 0] + u4 0 + bs)
       rg (foldl (\ a q (@ a [bs rels]
                           (: k (q 2) a0 (peep ((lanes (q 0)) 6) k 0)
                              [(bs + [7] + az + uleb (q 1)) ([(13 + #bs) ak k (0 - a0) 0] . rels)])))
                 [() ()] sqs)
       rgl [".debug_rnglists" 1 0 1 (o-v5 (<rg + [0])) (rev <>rg) {(name ".dbg.ranges") 12}]
       ; the abbrevs, by code: 1 the unit; 2..5 a function, global or static, typed or void: name,
       ; pc and length, its body's `{` as its place, the cfa its frame base, its params below it;
       ; 6 a param; 7.. the types (ty), 17 18 a variable, global or static, at its address;
       ; 23 a param at its home, 24 a variable with none, 25 a block,
       ; 26 27 a param and a variable by a location list; 28 29 an inlined function, typed or void, and
       ; 30 a copy of it: its range, and the call's place
       (sub ex ty) ([46 1 3 8 17 1 18 6 58 15 59 15] + (ty ? [73 19] ()) + [39 25] + (ex ? [63 25] ()) + [64 24 0 0])
       ab [".debug_abbrev" 1 0 1 ([1 17 1 37 8 19 11 3 8 27 8 16 23 17 1 85 23 0 0]
                                  + catall (o-mapi (\ i a ((i + 2) . a)) [(sub 1 1) (sub () 1) (sub 1 ()) (sub () ())
                                       [5 0 3 8 73 19 0 0] [36 0 3 8 62 11 11 11 0 0] [15 0 11 11 73 19 0 0] [15 0 11 11 0 0]
                                       [19 1 3 8 11 15 0 0] [23 1 3 8 11 15 0 0] [13 0 3 8 73 19 56 15 0 0]
                                       [13 0 3 8 73 19 107 15 13 15 0 0] [1 1 73 19 0 0] [33 0 47 15 0 0] [33 0 0 0]
                                       [52 0 3 8 73 19 63 25 2 24 0 0] [52 0 3 8 73 19 2 24 0 0] [19 0 3 8 60 25 0 0]
                                       [59 0 3 8 0 0] [21 0 39 25 73 19 0 0] [21 0 39 25 0 0]
                                       [5 0 3 8 73 19 2 24 0 0] [52 0 3 8 73 19 0 0] [11 1 17 1 18 6 0 0]
                                       [5 0 3 8 73 19 2 23 0 0] [52 0 3 8 73 19 2 23 0 0]
                                       [46 0 3 8 73 19 39 25 32 11 58 15 59 15 0 0] [46 0 3 8 39 25 32 11 58 15 59 15 0 0]
                                       [29 1 49 19 17 1 18 6 88 15 89 15 0 0]])
                                  + [0])
           () {(name ".dbg.abbrev") 0}]
       ; per code lane, its functions by pc: (lo label length name file line global? labels)
       (fns i l)
        (: lb (l 6) al (rws i) bl (filter (r \ r 1 = 0) al)
           (in l lo hi) (filter (r \ lo <= <r && <r < hi) l)
           (lst l) (l @ (a . b . u) (<a = <b ? (lst >l) (a . lst >l)) _ l)
           (one nm) (: k (name nm) e (fn-end nm)
                       (o-has? lb k && o-has? lb e ?
                          (: lo (lb k) hi (lb e)
                             d (in bl lo hi @ (b . _) b (in al lo hi @ (b . _) b ()))
                             [[lo k (hi - lo) nm (two? d ? [(peep fix (d 4) 1) (d 3)] [1 0]) (elem nm gfn) lb (lst (in al lo hi))]])))
           (sort (catmap one (uniq fnl))))
       fs (catmap (\ q (fns (q 0) (lanes (q 0)))) sqs)
       pre (u2 5 + [1 asz] + u4 0 + uleb 1 + str "mooncc" + [12] + str <dl + str <>dl)
       cu0 (pre + u4 0 + az + u4 0)
       dt (3 < #dl ? (dl 3) [() () {} {}])
       ; a type's die, its refs by r: each is ref4, so its size never waits on where the rest go
       (ty r e)
        (e @ ('base nm en sz) ([7] + str nm + [en sz])
             ('ptr sz j) (j = () ? [9 sz] ([8 sz] + r j))
             ('arr j n) ([14] + r j + (charm? n && 0 < n ? (15 . uleb (n - 1)) [16]) + [0])
             ('struct nm sz ms u) ([(u ? 11 10)] + str nm + uleb sz
                                    + catmap (m \ (@ m [mn j off] ([12] + str mn + r j + uleb off)
                                                       [mn j off bo bw] ([13] + str mn + r j + uleb (off * 8 + bo) + uleb bw)))
                                             (filter (m \ m 1 != ()) ms) + [0])
             ('decl nm) ([19] + str nm)
             ('fn j) (j = () ? [22] ([21] + r j))
             ('unspec nm) ([20] + str nm))
       tys (dt 0)
       tof (rev >(foldl (\ a e ((<a + #(ty (_ \ u4 0) e)) . a)) [(4 + #cu0)] tys))
       tot (foldl (t \ o \ (pin t (t 'n) o, pin t 'n (t 'n + 1))) (pin {} 'n 0) tof)
       (ref j) (u4 (tot j))
       tyb (catmap (ty ref) tys)
       ; a variable laid here, at its label
       lbs (map (l \ l 6) lanes)
       (laid? nm) (any (lb \ o-has? lb (name nm)) lbs)
       (var acc v)
        (@ acc [bs rels]
           (@ v [nm j ex] (? (j = () || !(laid? nm)) acc
                             (: b0 ([(ex ? 17 18)] + str nm + ref j + [(asz + 1) 3])
                                [(bs + b0 + az) ([(4 + #bs + #b0) ak (name nm) 0 0] . rels)]))))
       vs0 (foldl var [(cu0 + tyb) ()] (dt 1))
       ; the functions inlined, by name their dies' places
       ino {}
       (inl acc nm)
        (@ acc [n bl]
           (@ (peep (dt 2) nm [() () ()]) [rt _ at]
              (: pl (at @ [f l] [(peep fix f 1) l] [1 0])
                 b ((rt = () ? [29] [28]) + str nm + (rt = () ? () (ref rt)) + [1] + uleb <pl + uleb (pl 1))
                 (pin ino nm n, [(n + #b) (b . bl)]))))
       inb (foldl inl [(4 + #(<vs0)) ()] (uniq (catmap (f \ catmap (s \ s 3 @ (nm . _) [nm] _ ()) (<(peep (dt 3) (f 3) [() ()]))) fs)))
       vs [(<vs0 + catall (rev (inb 1))) (vs0 1)]
       ; a home's location: the cfa's offset, the address kept there, a label's
       (homed h) (h @ ('f o) (: e ([145] + sleb o) (#e . e)) ('d o) (: e ([145] + sleb o + [6]) (#e . e)) ('g _) ([(asz + 1) 3] + az) _ ())
       ; a vreg's lists by its states: ss, the function's (offset state) by address, hi its end; where
       ; a state names no home for it there is none. .debug_loclists grows in lc: (length bytes relocs), newest first
       lc (pin {} 'n 0)
       (dwreg r) (show r @ s (: i (read (snip s 1 #s))
                                (? (isa = 'rv64 || isa = 'rv32) ((s 0 = 102 ? rv-dwf rv-dwr) i)
                                   (isa = 'mips) ([2 3 4 5 6 7 8 9 16 17 18 19] i)
                                   (thumb-framed? isa) (? (s 0 = 102) (i < 16 ? (256 + i) (33 + 2 * i)) i)
                                   (s 0 = 102) (i + (isa = 'a64 ? 64 17))
                                   (isa = 'a64) i
                                   ([0 2 1 3 6 4 5 8 9 10 11 12 13 14 15] i))))
       (hexp h) (h @ ['r r] (: d (dwreg r) (? (d < 32) [(80 + d)] (144 . uleb d))) ['f o] ([145] + sleb o))
       ; a function's states by vreg: each (from to home), in order, one run joined
       (hidx ss hi)
        (: t {} (put a e b)
                 (: l (peep t <b ())
                    (pin t <b (l @ ([o p h] . u) (p = a && h = b 1 ? ([o e h] . u) ([a e (b 1)] . l)) _ [[a e (b 1)]])))
           (go l)
            (l @ ([o s] . u) (: e (u @ ([p _] . _) p _ hi)
                                (e <= o ? 0 (foldl (seen \ b \ (elem <b seen ? seen (put o e b, (<b . seen)))) () s), go u))
                 _ t)
           (go ss))
       ; -> the list's place past .debug_loclists' head, () when v has no home
       (loclist v f)
        (@ f [f0 fk lb scs ss hi _]
           (rev (peep ss v ()) @ () ()
              hs (: b ([6] + az + catmap ([a e h] \ (hexp h @ x ([4] + uleb (a - f0) + uleb (e - f0) + uleb #x + x))) hs + [0])
                    n (lc 'n)
                    (pins lc 'n (n + #b) 'b (b . lc 'b) 'r ([(n + 13) ak fk 0 0] . lc 'r), n))))
       ; a local, its label's reloc where it is a static: () for a static not laid
       ; with hd its name and type: its abbrev's code, a home's bytes and its reloc. codes: none, by
       ; expression, by list
       (homef f h hd codes)
        (h @ ['v v] (loclist v f @ () [((codes 0) . hd) ()]
                                   n (: b ((codes 2) . hd) [(b + u4 0) [[#b 'abs32 (name ".dbg.loc") n 0]]]))
             ['g l] (: b ((codes 1) . hd) [(b + homed h) [[(#b + 2) ak (name l) 0 0]]])
             () [((codes 0) . hd) ()]
             _ [((codes 1) . hd + homed h) ()])
       (loc1 f ps acc v)
        (@ acc [n bl rels]
           (@ v [nm h j]
              (? (j = () || (h @ ('g l) !(laid? l) _ ())) acc
                 (@ (homef f h (str nm + ref j) (elem nm ps ? [6 23 26] [24 18 27])) [b rs]
                    [(n + #b) (b . bl) (map (r \ ((<r + n) . >r)) rs + rels)]))))
       ; a scope's names, then the blocks in it by address, each inside its parent and past its
       ; elder; one whose mark is gone lays nothing. f: the function's start, its label, labels, scopes.
       ; acc: a length, its byte runs newest first, its relocs
       (scope acc f k lo hi)
        (@ f [f0 fk lb scs _ _ rows]
           (: own (peep (scs 0) k ())
              ; a copy's params are the callee's
              ps (own @ ([_ _ _ (nm . _)] . _) (map cap ((peep (dt 2) nm [() ()]) 1)) _ ())
              a1 (foldl (loc1 f ps) acc (catmap (s \ s 2) own))
              (at p j d) (peep lb (name "\(p).\(j)") d)
              ; a block ends at the first row past its start that another scope laid, or where its parent does
              (cut b z sp) (foldl (\ m r (b < <r && <r < m && !(sp 0 <= r 2 && r 2 < sp 1) ? <r m)) z rows)
              kids (sort (catmap (s \ (at ".dlb" <s () @ b (charm? b ? [[b (cut b hi (s 4)) <s]] ()))) (filter (s \ 0 < <s) (peep (scs 1) k ()))))
              (kid st c)
               (@ st [acc from]
                  (: b (max from <c) e (min hi (c 1))
                     (? (e <= b) st
                        (@ acc [n bl rels]
                           (: in (peep (scs 0) (c 2) () @ (s . _) (s 3) ())
                              hd (in @ (nm . _) ([30] + u4 (ino nm)) _ [25])
                              pl (in @ [_ cf cl] (uleb (peep fix cf 1) + uleb cl) _ ())
                              h2 (hd + az + u4 (e - b) + pl)
                              a2 (scope [(n + #h2) (h2 . bl) ([(n + #hd) ak fk (b - f0) 0] . rels)] f (c 2) b e)
                              [[(<a2 + 1) ([0] . a2 1) (a2 2)] e])))))
              <(foldl kid [a1 lo] kids)))
       (die acc f)
        (@ acc [bn bl rels]
           (@ f [f0 k n nm fl ex lb rows]
              (: sg (peep (dt 2) nm [() ()])
                 sl (peep (dt 3) nm [() ()])
                 scs <sl
                 (by i) (foldl (t \ s \ pin t (s i) (s . peep t (s i) ())) {} (rev scs))
                 fr [f0 k lb [(by 0) (by 1)] (sort (catmap ([i s] \ (peep lb (name ".dls.\(i)") () @ a (charm? a ? [[a i s]] ()))) (sl 1)) @ l (: k0 (foldl (\ m r (min m (r 1))) (? (two? l) (<l 1) 0) l) (hidx (map ([a i s] \ [(i = k0 ? f0 a) s]) l) (f0 + n)))) (f0 + n) rows]
                 ph (catmap (s \ <s = -1 ? (s 2) ()) scs)
                 (par acc p) (: h (filter (b \ <b = <p) ph @ (b . _) (b 1) ())
                                (@ acc [bs rs]
                                   (@ (homef fr h (str <p + ref (p 1)) [6 23 26]) [b r2]
                                      [(bs + b) (map (r \ ((<r + #bs) . >r)) r2 + rs)])))
                 hd (uleb (? (<sg = ()) (ex ? 4 5) (ex ? 2 3)) + str nm)
                 b0 (hd + az + u4 n + uleb <fl + uleb (fl 1)
                      + (<sg = () ? () (ref <sg)) + [1 156])
                 p0 (foldl par [b0 ()] (filter (p \ p 1 != ()) (sg 1)))
                 r (scope [#(<p0) [<p0] (p0 1)] fr 0 f0 (f0 + n))
                 o (4 + bn)
                 [(bn + <r + 1) ([0] . (r 1 + bl))
                  (map (r \ ((<r + o) . >r)) (r 2) + ([(o + #hd) ak k 0 0] . rels))])))
       ds (foldl die [#(<vs) [<vs] <>vs] fs)
       cu (catall (rev (ds 1)) + [0])
       inf [".debug_info" 1 0 1 (u4 #cu + cu)
              ([[8 'abs32 (name ".dbg.abbrev") 0 0] [(4 + #pre) 'abs32 (name ".dbg.line") 0 0]
                [(8 + asz + #pre) 'abs32 (name ".dbg.ranges") 0 0]] + rev (ds 2)) {}]
       lcl [".debug_loclists" 1 0 1 (o-v5 (catall (rev (lc 'b)))) (rev (lc 'r)) {(name ".dbg.loc") 12}]
       (atom? sqs ? () ([ab inf ln rgl] + (lc 'n = 0 ? () [lcl]))))

   ; -- the general object: a list of sections, each (name type flags align forms), each one
   ; lay: a branch inside resolves in place, a reference across becomes a relocation.
   ; shf_execinstr (flags & 4) picks the relaxer and rset (a64's branches resolve in any
   ; section). a NOBITS section lays its forms for labels and size but writes no bytes. ax is
   ; what an assembly text adds: its data names, typed and sized as gas does (stt_notype, size 0,
   ; unless its .type and .size say), and its absolute symbols, each (name value). uw names the
   ; functions an a64 .eh_frame describes --
   (objsecs target0 secs funcnames globnames wknames locnames) (objsecsn target0 secs funcnames globnames wknames locnames {} [() ()] ())
   (objsecsn target0 secs funcnames globnames wknames loc0 anames ax uw)
    (: target (arch-nom target0)
       ; an absolute symbol is (name value), stb_global, or (name value 0), stb_local
       adata (o-names <ax) abss (filter (p \ #p = 2) <>ax) labss (filter (p \ #p = 3) <>ax)
       szt (foldl (\ t p (pin t (name <p) <>p)) {} (2 < #ax ? (ax 2) ()))   ; a .size its text gave outright
       a64 (target = 'a64)
       ; rv32, xtensa, mips and avr lay this same RELA shape in the ELF32 class
       xt (target = 'xtensa)
       mp (target = 'mips)
       av (target = 'avr)
       w32 (target = 'rv32 || xt || mp || av)
       rv (target = 'rv64 || target = 'rv32)
       _ (target = 'x64 || a64 || rv || xt || mp || av ? 0 (scare 'obj-target target))
       esym (w32 ? elf-sym32 elf-sym)  eshdr (w32 ? elf-shdr32 elf-shdr)  erela (w32 ? o-rela32 o-rela)
       symz (w32 ? 16 24)  rlz (w32 ? 12 24)  shz (w32 ? 40 64)  wa (w32 ? 4 8)
       ; the in-place-resolvable kinds; riscv's auipc is byte pc-relative, no page math
       rset (? a64 '(b26 b19 b14 ld19 adr21) rv '(j21 pcrel b13 cj cb) xt '(j18 call0 l32r) mp '(mb16)
                av ()                                    ; every avr reach stays a relocation
                '(rel32 pc32 rel8 rel16 pc8))
       drset (a64 || target = 'x64 ? rset ())    ; a pc-relative reach inside one section moves with it
       machine (peep elf-machines target 0)
       ; a cross backend joins at runtime; unregistered, lay would lower nothing, silently
       be (backends target @ b
             (lit? b ? b (scare 'obj-no-backend target)))
       ; a weak-defined function's callers go through a relocation, so a strong override wins;
       ; the relaxer must keep them long too
       wkset (o-names wknames)
       ; ..and on x64 a reach to any global, as gas leaves it: the linker may bind it elsewhere
       gbset (target = 'x64 ? (o-names (wknames + funcnames + globnames)) wkset)
       _ (atom? secs ? (scare 'obj-no-sections target))
       (exec? s) (0 < s 2 & 4)
       ; the relaxer, for executable sections only; a holo bake without laylax is a stale
       ; binary under a fresh obj.l, and scares
       lanes0 (map (s \
                (: fm (s 4)
                   p (exec? s ?
                        (laylax @ r
                           (lit? r ? (r fm be 0 {} gbset)
                              (scare 'holo-bake-stale 'laylax)))   ; each section at org 0
                        (lay (o-dal fm) be 0 () {}))
                   w (o-walk be <p >p gbset 1 (exec? s ? rset drset))
                   [(s 0) (s 1) (s 2) (s 3) <w <>w >p]))
              secs)
       ; -g's third word: the unit's unwind tables are .eh_frame, else -g lays .debug_frame
       df (5 < #ax && two? (ax 5) && !(ax 5 2))
       lanes1 ((a64 || target = 'x64 || elem target '(rv64 rv32 mips) && df) && two? uw ? (o-eh lanes0 uw target df @ e (two? e ? (lanes0 + [e]) lanes0)) lanes0)
       lanes (5 < #ax && two? (ax 5) ? (lanes1 + o-dwarf lanes1 (ax 5) (funcnames + loc0) funcnames target) lanes1)
       nsec #lanes
       wx (o-wix lanes) lnt (o-rows lanes)
       (ln i) (lnt i)
       (ln-ty l) (l 1)  (ln-bs l) (l 4)  (ln-rl l) (l 5)
       (ln-fsz l) (ln-ty l = 8 ? 0 (o-blen (ln-bs l)))     ; a NOBITS lane owns no file bytes
       allrel (catall (map ln-rl lanes))
       ext0 (o-exts wx allrel)
       exts (ext0 + filter (u \ (nelem u ext0)) (map name (3 < #ax ? (ax 3) ())))
       vist (foldl (\ t p (pin t (name <p) <>p)) {} (4 < #ax ? (ax 4) ()))
       (o-vis nm b) (peep vist (name nm) 0 @ v (v = 0 ? b (o-putbs b (w32 ? 13 5) [v])))
       ; x64: a reach with a constant into a merging section names its label; section + constant
       ; cannot say which piece it means. those no text named locally join the locals
       (rel-c k aux) (k @ ('rel32 || 'pc32) (aux - 4) 'rel64 (aux - 8) aux)
       (mrg? r) (: w (o-where wx (r 2))
                   (two? w && 0 < ((ln (<w - 1)) 2 & 16) && !(o-has? gbset (r 2)) && rel-c (r 1) (r 3) != 0))
       mlabs (target = 'x64 ? (uniq (map (r \ show (r 2)) (filter mrg? allrel))) ())
       mset (o-names mlabs)
       loc0s (o-names loc0)
       mnew (filter (l \ !(o-has? loc0s (intern l))) mlabs)
       mnews (o-names mnew)
       locnames (loc0 + mnew)
       locidx (o-idx (map name locnames) (1 + nsec))

       ; -- symbol indices: NULL, a section symbol each, the local statics, funcs, globs,
       ; exts. every local ahead of the first global, where .symtab's sh_info points --
       nloc (#locnames + #labss) nfun #funcnames nglob #globnames nabs #abss
       fstart (1 + nsec + nloc) gstart (fstart + nfun) estart (gstart + nglob + nabs)
       extidx (o-idx exts estart)
       fnidx (o-idx (map name funcnames) fstart)   ; relocs to a global bind these
       gidx (o-idx (map name globnames) gstart)

       symnames (map (s \ peep anames s s) (locnames + map cap labss + funcnames + globnames + map cap abss + map string exts))
       str (o-strtab symnames)
       strblob <str stroffs (o-rows <>str)

       ; -- the symbol table, locals first. a symbol's section is wherever its bytes went;
       ; o-place falls back to section 1 for a name never laid --
       (o-place nm) (o-where wx (name nm) @ w (two? w ? w '(1 0)))
       dsz (o-dsizes secs)
       (o-size nm) (peep dsz (string? nm ? nm (show nm)) 0)
       ; a data name's type and size: an asm text's as its .type and .size say, else an object
       ; the extent of its data
       (o-asm? nm) (o-has? adata (name nm) || o-has? mnews (name nm))
       (o-xtype nm) (two? (o-where wx (fn-obj nm)) ? 1 (o-ftype wx nm))
       (o-dtype nm) (o-asm? nm ? (o-xtype nm) 1)
       (o-xsize w nm) (o-gsize wx (szt (name nm)) @ z (charm? z ? z (o-fsize wx w nm)))
       (o-dsize w nm) (o-asm? nm ? (o-xsize w nm) (o-size nm))
       symbytes
        (: lsyms (catall (o-mapi (\ i ls (: w (o-place ls)                ; stb_local: a func, or an object in data
                                            x (exec? (ln (<w - 1)))
                                            (esym (stroffs i) 0 (x ? (o-xtype ls) (o-dtype ls)) <w <>w (x ? (o-xsize w ls) (o-dsize w ls)))))
                                 locnames))
           fsyms (catall (o-mapi (\ i fs (o-place fs @ w
                                            (o-vis fs (esym (stroffs (nloc + i))
                                             (elem fs wknames ? 2 1)   ; stb_weak | stb_global
                                             (o-xtype fs) <w <>w (o-xsize w fs)))))
                                 funcnames))
           gsyms (catall (o-mapi (\ i gs (o-place gs @ w
                                            (o-vis gs (esym (stroffs (nloc + nfun + i))
                                                   (elem gs wknames ? 2 1) (o-dtype gs) <w <>w (o-dsize w gs)))))
                                 globnames))
           ; an absolute symbol: stt_notype, shn_abs
           lasyms (catall (o-mapi (\ i p (esym (stroffs (#locnames + i)) 0 0 65521 <>p 0)) labss))
           asyms (catall (o-mapi (\ i p (esym (stroffs (nloc + nfun + nglob + i)) 1 0 65521 <>p 0)) abss))
           ; a weak undef resolves to zero at static link
           esyms (catall (o-mapi (\ i e (o-vis e (esym (stroffs (nloc + nfun + nglob + nabs + i))
                                               (o-has? wkset e ? 2 1) 0 0 0 0)))
                                 exts))
           ; one stt_section symbol per section, in section order
           ssyms (catall (o-mapi (\ i l (esym 0 0 3 (i + 1) 0 0)) lanes))
           (catall [(esym 0 0 0 0 0 0) ssyms lsyms lasyms fsyms gsyms asyms esyms]))    ; the NULL symbol leads
       nsym (1 + nsec + nloc + nfun + nglob + nabs + #exts)

       ; -- the relocations, by the fixup's kind, never the section. --
       ; a label -> (symidx base-addend): a global binds itself (base 0), as gas does, so the
       ; linker can redirect a weak one and modpost reads an export's name; a local label
       ; its section symbol + offset, else its undef.
       (secsym lbl)
        (? (o-has? fnidx lbl) [(peep fnidx lbl 0) 0]
           (o-has? gidx lbl)  [(peep gidx lbl 0) 0]
           (o-where wx lbl @ w (two? w ? w [(peep extidx lbl 0) 0])))
       rabs (? a64 ra-abs64 rv rr-64 r-64)
       (o-rels rs)
        (catall (map (\ [off k lbl aux pv]
           (: sl (o-has? mset lbl && rel-c k aux != 0 ? [(peep locidx lbl 0) 0] (secsym lbl)) si <sl sa <>sl
              (k @
                 ['elf n] (erela off si n (sa + aux))                     ; a relocation by number, as `.reloc` gives it
                 ; aux is the constant byte offset of a &arr[i] / &s.field
                 'abs64 (erela off si rabs (sa + aux))
                 'abs32 (erela off si (? a64 ra-abs32 rv rr-32 xt xr-32 mp mr-32 av 1 r-32) (sa + aux))
                 ('abs32s || 'abs32d) (erela off si r-32s (sa + aux))      ; abs32d: a based displacement outside 64
                 'abs16 (erela off si (av ? 4 r-16) (sa + aux))
                 'abs8 (erela off si (av ? 26 r-8) (sa + aux))
                 ; an 8-byte word measured from its own start
                 'rel64 (erela off si (a64 ? ra-prel64 r-pc64) ((sa + aux) - 8))
                 ; an FDE's pc_begin: the section symbol, so a weak function's is its own
                 'secrel32 (o-where wx lbl @ w (erela off <w (a64 ? ra-prel32 r-pc32) <>w))
                 'pc32 (erela off si (? a64 ra-prel32 rv rr-pc32 r-pc32) ((sa + aux) - 4))
                 ; x64 counts from the field's end, so the -4. a weak fn binds plt32, as does a
                 ; branch (E8/E9 call/jmp, 0F 8x jcc) whatever it reaches, as llvm-mc lays it;
                 ; anything else pc32 (data has no plt stub)
                 'rel32
                  (erela off si
                          (? rv rr-pc32
                             a64 ra-prel32
                             (o-has? wkset lbl && o-has? fnidx lbl) r-plt32
                             (elem pv '(232 233) || 128 <= pv && pv <= 143) r-plt32
                             r-pc32)
                          ((sa + aux) - 4))
                 ; a64: a page delta never resolves inside a .o
                 'adrp21 (erela off si ra-pghi21 (sa + afix-ad aux))
                 'addlo12 (erela off si ra-lo12 (sa + afix-ad aux))
                 ('lo12s1 || 'lo12s2 || 'lo12s4 || 'lo12s8 || 'lo12s16) (erela off si (ra-ldst k) (sa + afix-ad aux))
                 'b26 (erela off si (afix-w aux = 2483027968 ? ra-call26 ra-jump26) (sa + afix-ad aux))   ; 0x94000000 = bl
                 'b19 (erela off si ra-condbr19 (sa + afix-ad aux))
                 'b14 (erela off si ra-tstbr14 sa)
                 'ld19 (erela off si ra-ldlo19 (sa + afix-ad aux))
                 'adr21 (erela off si ra-adrlo21 (sa + afix-ad aux))
                 'pcrel (erela off si rr-call sa)
                 'j21 (erela off si rr-jal sa)
                 ('j18 || 'call0) (erela off si xr-slot0 sa)
                 ; a branch's field counts from its delay slot, P + 4
                 'mb16 (erela off si mr-pc16 (sa - 4))
                 'mj26 (erela off si mr-26 sa) 'mhi16 (erela off si mr-hi16 sa) 'mlo16 (erela off si mr-lo16 sa)
                 (k && o-has? avr-rels k) (erela off si (avr-rels k) (sa + afix-ad aux))
                 (scare 'obj-fix k))))
           rs))
       relas (map (o-rels * ln-rl) lanes)
       rcnt (tally * ln-rl * ln)
       ; a .rela only where a section has relocations: objtool walks an empty one's first entry
       rl (filter (i \ rcnt i > 0) ^nsec)  nrel #rl

       shnames (map cap lanes
                + '(".symtab" ".strtab")
                + map (i \ ".rela" + <(ln i)) rl
                + '(".shstrtab"))
       shstr (o-strtab shnames)
       shstrblob <shstr shoffs (o-rows <>shstr)
       shname shoffs

       ; -- file layout: header, section contents packed tight (sh_addralign places them),
       ; then the sht. the indices: 0 NULL, the content sections, .symtab, .strtab, a .rela
       ; per relocated section, .shstrtab last. --
       i-sym (1 + nsec) i-str (2 + nsec)
       i-shs (nsec + nrel + 3) nsh (nsec + nrel + 4)
       h-sz (w32 ? 52 64)
       ; the content offsets, in section order; a NOBITS sh_offset is a placeholder.
       (o-offs i off acc) (nsec <= i ? [(rev acc) off]
                             (o-offs (i + 1) (off + ln-fsz (ln i)) (off . acc)))
       co (o-offs 0 h-sz ())    coffs (o-rows <co)
       sym-off <>co             sym-sz (nsym * symz)
       str-off (sym-off + sym-sz) str-sz #strblob
       (o-roffs i off acc) (nsec <= i ? [(rev acc) off]
                              (o-roffs (i + 1) (off + rcnt i * rlz) (off . acc)))
       ro (o-roffs 0 (str-off + str-sz) ())    roffs (o-rows <ro)
       shs-off <>ro             shs-sz #shstrblob
       sht-off (shs-off + shs-sz)

       ; a link-order section's sh_link: the section its first word reaches
       (o-link l) (0 < (l 2 & 128) && two? (l 5) ? (o-where wx (l 5 0 2) @ w (two? w ? <w 0)) 0)
       sht (catall ([(o-zeros shz)]                                         ; 0 NULL
              + o-mapi (\ i l (eshdr (shname i) (ln-ty l) (l 2 & 4294967295)   ; 1..nsec the content sections
                                  0 (coffs i) (o-blen (ln-bs l)) (o-link l) 0 (l 3) (l 2 >> 32)))
                       lanes
              + [(eshdr (shname nsec) 2 0 0 sym-off sym-sz i-str ((1 + nsec) + nloc) wa symz)    ; .symtab link=.strtab info=first-global
                 (eshdr (shname (nsec + 1)) 3 0 0 str-off str-sz 0 0 1 0)]                    ; .strtab
              + o-mapi (\ j i (eshdr (shname (nsec + 2 + j)) 4 0                          ; a .rela per relocated section, link=.symtab
                                  0 (roffs i) (rcnt i * rlz) i-sym (i + 1) wa rlz))
                       rl
              + [(eshdr (shname (nsec + nrel + 2)) 3 0 0 shs-off shs-sz 0 0 1 0)]))             ; .shstrtab

       hdr (catall [
             [127 69 76 70 (w32 ? 1 2) 1 1 0 0 0 0 0 0 0 0 0]              ; e_ident: \x7fELF 64-bit (rv32: 32-bit) LSB
             (le16 1) (le16 machine) (le32 1)                             ; et_rel, e_machine, version
             (w32 ? (le32 0 + le32 0 + le32 sht-off)                      ; e_entry=0, e_phoff=0, e_shoff
                 (le64 0 + le64 0 + le64 sht-off))
             (le32 (? xt 768 mp 0x70001001 av (be 'eflags) w32 1 (machine = 243) 5 0)) (le16 h-sz) (le16 0)  ; e_flags (riscv: RVC | FLOAT_ABI_DOUBLE, rv32 soft; xtensa xt_insn | xt_lit; mips32r2 o32 noreorder; avr its backend's family number, the relaxable 0x80 clear), e_ehsize, e_phentsize=0
             (le16 0) (le16 shz) (le16 nsh)                               ; e_phnum=0, e_shentsize, e_shnum
             (le16 i-shs)])                                               ; e_shstrndx
       (elf-order machine
        (catall ([hdr]
                 + map (l \ (ln-ty l = 8 ? () (ln-bs l))) lanes           ; a NOBITS lane writes nothing
                 + [symbytes strblob]
                 + relas
                 + [shstrblob sht])))))
) ; module 'holo
