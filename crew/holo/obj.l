; crew/holo/obj.l -- a RELOCATABLE ELF64 object emitter (cc stage 7a). where elf.l
; wraps assembled bytes in a static EXECUTABLE (one RWX segment, all labels
; resolved), this lays a `.o` the SYSTEM linker can consume: separate .text /
; .data sections, a symbol table (each function a global FUNC, each global var a
; global OBJECT, each external reference an UNDEF), and RELA relocations for every
; reference the assembler cannot resolve within a section -- an la into .data
; (R_X86_64_PC32 via the .data section symbol), a call to a symbol defined
; elsewhere (R_X86_64_PLT32), a data pointer to a label (R_X86_64_64). intra-.text
; branches and calls stay pc-relative and resolve internally (both ends ride .text
; and move together). x86-64 only for now (cc emits x64; the arm64 reloc kinds
; differ). loads after crew/holo/elf.l in the au cat -- reads elf-machines /
; write-bytes / catall / le* bare, and the assembler internals through the `holo`
; book. cc.l drives it: `aicc -c foo.c foo.o`.
(:
   ; the ELF relocation TYPES we emit (x86-64)
   r-64    1                                        ; R_X86_64_64     S + A   (an abs64 data pointer)
   r-pc32  2                                        ; R_X86_64_PC32   S + A - P (an la into .data)
   r-plt32 4                                        ; R_X86_64_PLT32  L + A - P (a call to an external fn)

   (o-has? tab k) (! (id? (peep tab k 'no) 'no))    ; is key k bound in the tablet?
   (o-strbytes s) (: (go i acc) (? (i < 0) acc (go (i - 1) (link (s i) acc)))
                     (go ((tally s) - 1) ()))       ; a string -> its byte list

   ; walk an assembled section's items (bytes + fixups) -> (bytes relocs). a fixup
   ; is resolved in place when the section may (text-internal, pc-relative to a
   ; label defined here); otherwise it becomes a relocation record (off kind label
   ; addend) and W zero bytes hold its place (RELA overwrites the field outright).
   ; the addend is the fixup's aux -- a data pointer to &arr[i]/&s.field bakes the
   ; constant byte offset there, and the RELA carries it (added to the section-sym
   ; addend below), so the linker's S+A lands on the element, not the base.
   (o-walk be items labels wkset internal? off bacc racc)
    (? (! (two? items)) `((rev bacc) (rev racc))
       (: x <items
          (? ((holo 'fix?) x)
              (: lbl ((holo 'fix-l) x) w ((holo 'fix-w) x) k ((holo 'fix-k) x)
                 (? (&& (&& internal? (id? k 'rel32))
                        (&& (o-has? labels lbl) (! (o-has? wkset lbl))))   ; a weak target stays a reloc
                     (: tgt (peep labels lbl 0)
                        bs ((holo 'patch-with) be k tgt off w ((holo 'fix-a) x))
                        (o-walk be >items labels wkset internal? (off + w)
                                ((rev bs) + bacc) racc))
                    (o-walk be >items labels wkset internal? (off + w)
                            ((o-zeros w) + bacc) (link `(off k lbl ((holo 'fix-a) x)) racc))))
             (o-walk be >items labels wkset internal? (off + 1) (link x bacc) racc))))
   (o-zeros n) (? (n < 1) () (link 0 (o-zeros (n - 1))))

   ; the externals: labels referenced by a relocation but defined in NO
   ; section -- each needs an UNDEF symbol. unique, first-seen order.
   (o-exts rels tlabels dlabels nlabels)
    (: seen (tablet 0)
       (add lbl acc) (? (|| (o-has? tlabels lbl) (|| (o-has? dlabels lbl) (o-has? nlabels lbl))) acc
                        (o-has? seen lbl) acc
                        (: _ (pin seen lbl 1) (link lbl acc)))
       (go rs acc) (? (! (two? rs)) acc (go >rs (add (caup (cup (cap rs))) acc)))   ; reloc = (off kind label)
       (rev (go rels ())))

   ; a 24-byte symbol-table entry, and a 24-byte RELA entry.
   (o-sym nameoff bind typ shndx value)
    (catall `((le32 nameoff) `((| (<< bind 4) typ) 0) (le16 shndx) (le64 value) (le64 0)))
   (o-rela offset symidx typ addend)
    (catall `((le64 offset) (le64 ((* symidx 4294967296) + typ)) (le64 addend)))

   ; a string table from a list of names -> (blob (offset..)); leading NUL, so the
   ; k-th name's offset is where it starts. shared for .strtab and .shstrtab.
   (o-strtab names)
    (: (go ns off bacc offs)
        (? (! (two? ns)) `((rev bacc) (rev offs))
           (: bs ((o-strbytes <ns) + `(0))
              (go >ns (off + (tally bs)) ((rev bs) + bacc) (link off offs))))
       (go names 1 `(0) ()))

   ; build the whole .o image. textforms/dataforms/nifforms are cgen-obj's split
   ; IR (nifforms = the AI_NIF registry entries, laid in their own `ai_nifs`
   ; section so the linker's __start_/__stop_ bracket symbols bound them),
   ; funcnames the DEFINED functions (global FUNC symbols), globnames the global
   ; variables (global OBJECT symbols); statics reach neither list and stay
   ; local labels. -> a byte list.
   (objelf target textforms dataforms funcnames globnames wknames nifforms)
    (: _ (? (id? target 'x64) 0 (scare 'obj-x64-only target))
       machine (peep elf-machines target 0)
       be (peep (holo 'backends) target ())
       tp ((holo 'lay) textforms be 0 () (tablet 0))  ; assemble each section at org 0
       dp ((holo 'lay) dataforms be 0 () (tablet 0))
       np ((holo 'lay) nifforms be 0 () (tablet 0))
       tlabels >tp dlabels >dp nlabels >np
       ; a WEAK-defined function's callers must go through a RELOCATION -- an
       ; in-place resolve would pin them to the local body, and the linker could
       ; never redirect to a strong override
       wkset (: t (tablet 0) (go ws) (? (! (two? ws)) t (: _ (pin t (intern <ws) 1) (go >ws)))
                (go wknames))
       tw (o-walk be <tp tlabels wkset 1 0 () ())
       dw (o-walk be <dp dlabels wkset 0 0 () ())
       nw (o-walk be <np nlabels wkset 0 0 () ())
       tbytes <tw trel <>tw
       dbytes <dw drel <>dw
       nbytes <nw nrel <>nw
       exts (o-exts (trel + drel + nrel) tlabels dlabels nlabels)

       ; -- symbol indices: NULL, .text/.data/ai_nifs section syms, then funcs, globs, exts --
       nfun (tally funcnames) nglob (tally globnames)
       fstart 4 gstart (4 + nfun) estart ((4 + nfun) + nglob)
       extidx (: t (tablet 0) (go es i) (? (! (two? es)) t (: _ (pin t <es (estart + i)) (go >es (i + 1))))
                  (go exts 0))
       fnidx (: t (tablet 0) (go fs i) (? (! (two? fs)) t (: _ (pin t (intern <fs) (fstart + i)) (go >fs (i + 1))))
                (go funcnames 0))                    ; interned fn name -> its symbol index (weak-target relocs bind here)

       ; -- .strtab: every symbol's name (funcs, globs, exts as spellings) --
       symnames (funcnames + globnames + (map (\ s (string s)) exts))
       str (o-strtab symnames)
       strblob <str stroffs <>str
       (nthr l i) (? (i < 1) <l (nthr >l (i - 1)))

       ; -- the symbol table: locals (NULL + 2 section syms) then the globals --
       ; (each accumulator links 24-byte entries REVERSED and catalls once --
       ; a cat per entry re-copies the whole table)
       symbytes
        (: fsyms (: (go fs i acc) (? (! (two? fs)) (catall (rev acc))
                                     (go >fs (i + 1)
                                         (link (o-sym (nthr stroffs i)
                                                      (? (member? <fs wknames) 2 1)   ; STB_WEAK: a strong def elsewhere wins
                                                      2 1 (peep tlabels (intern <fs) 0)) acc)))
                    (go funcnames 0 ()))
           gsyms (: (go gs i acc) (? (! (two? gs)) (catall (rev acc))
                                     (go >gs (i + 1)
                                         (link (o-sym (nthr stroffs (nfun + i)) 1 1 2 (peep dlabels (intern <gs) 0)) acc)))
                    (go globnames 0 ()))
           esyms (: (go es i acc) (? (! (two? es)) (catall (rev acc))
                                     (go >es (i + 1)
                                         (link (o-sym (nthr stroffs ((nfun + nglob) + i)) 1 0 0 0) acc)))
                    (go exts 0 ()))
           (catall `((o-sym 0 0 0 0 0)                 ; the NULL symbol
                      (o-sym 0 0 3 1 0)                  ; .text section symbol (STT_SECTION)
                      (o-sym 0 0 3 2 0)                  ; .data section symbol
                      (o-sym 0 0 3 3 0)                  ; ai_nifs section symbol
                      fsyms gsyms esyms)))
       nsym (4 + nfun + nglob + (tally exts))

       ; -- the relocations. text: an la into .data -> PC32 via the .data section
       ; symbol (idx 2, addend = data offset - 4); a call to an external -> PLT32.
       ; data: an abs64 pointer -> R_64 via the target's section symbol + offset,
       ; or an external symbol. --
       reltext
        (: (go rs acc)
            (? (! (two? rs)) (catall (rev acc))
               (: r <rs off <r lbl <>>r
                  (? (o-has? wkset lbl)               ; a weak-defined fn: bind its OWN symbol (overridable)
                      (go >rs (link (o-rela off (peep fnidx lbl 0) r-plt32 -4) acc))
                     (o-has? dlabels lbl)
                      (go >rs (link (o-rela off 2 r-pc32 ((peep dlabels lbl 0) - 4)) acc))
                     (o-has? nlabels lbl)
                      (go >rs (link (o-rela off 3 r-pc32 ((peep nlabels lbl 0) - 4)) acc))
                     (go >rs (link (o-rela off (peep extidx lbl 0) r-plt32 -4) acc)))))
           (go trel ()))
       ; an abs64 pointer out of a DATA-class section (.data or ai_nifs): via the
       ; target's section symbol + its offset, or an external's own symbol
       (reldat1 rs)
        (: (go rs2 acc)
            (? (! (two? rs2)) (catall (rev acc))
               (: r <rs2 off <r lbl <>>r ad <>>>r   ; ad = the constant byte offset (&arr[i])
                  (? (o-has? wkset lbl)               ; a weak fn's address in data: via its symbol too
                      (go >rs2 (link (o-rela off (peep fnidx lbl 0) r-64 ad) acc))
                     (o-has? tlabels lbl)
                      (go >rs2 (link (o-rela off 1 r-64 ((peep tlabels lbl 0) + ad)) acc))
                     (o-has? dlabels lbl)
                      (go >rs2 (link (o-rela off 2 r-64 ((peep dlabels lbl 0) + ad)) acc))
                     (o-has? nlabels lbl)
                      (go >rs2 (link (o-rela off 3 r-64 ((peep nlabels lbl 0) + ad)) acc))
                     (go >rs2 (link (o-rela off (peep extidx lbl 0) r-64 ad) acc)))))
           (go rs ()))
       reldata (reldat1 drel)
       relnif  (reldat1 nrel)
       ntrel (tally trel) ndrel (tally drel) nnrel (tally nrel)

       ; -- the section-name string table --
       shnames `(".text" ".data" "ai_nifs" ".symtab" ".strtab" ".rela.text" ".rela.data" ".rela.ai_nifs" ".shstrtab")
       shstr (o-strtab shnames)
       shstrblob <shstr shoffs <>shstr
       (shname i) (nthr shoffs i)

       ; -- file layout: header, then section contents packed tight, then the SHT.
       ; the linker reads each section by (sh_offset, sh_size), so no in-file
       ; alignment padding is needed; sh_addralign drives final placement. --
       h-sz 64
       t-off h-sz               t-sz (tally tbytes)
       d-off (t-off + t-sz)     d-sz (tally dbytes)
       n-off (d-off + d-sz)     n-sz (tally nbytes)
       sym-off (n-off + n-sz)   sym-sz (* nsym 24)
       str-off (sym-off + sym-sz) str-sz (tally strblob)
       rt-off (str-off + str-sz)  rt-sz (* ntrel 24)
       rd-off (rt-off + rt-sz)    rd-sz (* ndrel 24)
       rn-off (rd-off + rd-sz)    rn-sz (* nnrel 24)
       shs-off (rn-off + rn-sz)   shs-sz (tally shstrblob)
       sht-off (shs-off + shs-sz)

       ; a 64-byte section header
       (sh nameoff typ flags off sz link info align entsz)
        (catall `((le32 nameoff) (le32 typ) (le64 flags) (le64 0)
                   (le64 off) (le64 sz) (le32 link) (le32 info) (le64 align) (le64 entsz)))
       sht (catall `(
              (o-zeros 64)                                                 ; 0 NULL
              (sh (shname 0) 1 6 t-off t-sz 0 0 16 0)                      ; 1 .text  PROGBITS ALLOC|EXEC
              (sh (shname 1) 1 3 d-off d-sz 0 0 8 0)                       ; 2 .data  PROGBITS ALLOC|WRITE
              (sh (shname 2) 1 3 n-off n-sz 0 0 8 0)                       ; 3 ai_nifs PROGBITS ALLOC|WRITE (__start_/__stop_ bracket it)
              (sh (shname 3) 2 0 sym-off sym-sz 5 4 8 24)                  ; 4 .symtab link=.strtab info=first-global(4)
              (sh (shname 4) 3 0 str-off str-sz 0 0 1 0)                   ; 5 .strtab
              (sh (shname 5) 4 0 rt-off rt-sz 4 1 8 24)                    ; 6 .rela.text link=.symtab info=.text
              (sh (shname 6) 4 0 rd-off rd-sz 4 2 8 24)                    ; 7 .rela.data link=.symtab info=.data
              (sh (shname 7) 4 0 rn-off rn-sz 4 3 8 24)                    ; 8 .rela.ai_nifs link=.symtab info=ai_nifs
              (sh (shname 8) 3 0 shs-off shs-sz 0 0 1 0)))                 ; 9 .shstrtab

       hdr (catall `(
              `(127 69 76 70 2 1 1 0 0 0 0 0 0 0 0 0)                     ; e_ident: \x7fELF 64-bit LSB
              (le16 1) (le16 machine) (le32 1)                            ; ET_REL, e_machine, version
              (le64 0) (le64 0) (le64 sht-off)                            ; e_entry=0, e_phoff=0, e_shoff
              (le32 0) (le16 64) (le16 0)                                 ; e_flags, e_ehsize, e_phentsize=0
              (le16 0) (le16 64) (le16 10)                                ; e_phnum=0, e_shentsize=64, e_shnum=10
              (le16 9)))                                                  ; e_shstrndx=9
       (catall `(hdr tbytes dbytes nbytes symbytes strblob reltext reldata relnif shstrblob sht))))
