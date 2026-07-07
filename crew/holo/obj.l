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
   (o-strbytes s) (: (go i acc) (? (< i 0) acc (go (- i 1) (link (s i) acc)))
                     (go (- (tally s) 1) ()))       ; a string -> its byte list

   ; walk an assembled section's items (bytes + fixups) -> (bytes relocs). a fixup
   ; is resolved in place when the section may (text-internal, pc-relative to a
   ; label defined here); otherwise it becomes a relocation record (off kind label)
   ; and W zero bytes hold its place (RELA overwrites the field outright).
   (o-walk be items labels internal? off bacc racc)
    (? (! (two? items)) (L (rev bacc) (rev racc))
       (: x (cap items)
          (? ((holo 'fix?) x)
              (: lbl ((holo 'fix-l) x) w ((holo 'fix-w) x) k ((holo 'fix-k) x)
                 (? (&& (&& internal? (id? k 'rel32)) (o-has? labels lbl))
                     (: tgt (peep labels lbl 0)
                        bs ((holo 'patch-with) be k tgt off w ((holo 'fix-a) x))
                        (o-walk be (cup items) labels internal? (+ off w)
                                (cat (rev bs) bacc) racc))
                    (o-walk be (cup items) labels internal? (+ off w)
                            (cat (o-zeros w) bacc) (link (L off k lbl) racc))))
             (o-walk be (cup items) labels internal? (+ off 1) (link x bacc) racc))))
   (o-zeros n) (? (< n 1) () (link 0 (o-zeros (- n 1))))

   ; the externals: labels referenced by a relocation but defined in NEITHER
   ; section -- each needs an UNDEF symbol. unique, first-seen order.
   (o-exts trel drel tlabels dlabels)
    (: seen (tablet 0)
       (add lbl acc) (? (|| (o-has? tlabels lbl) (o-has? dlabels lbl)) acc
                        (o-has? seen lbl) acc
                        (: _ (pin seen lbl 1) (link lbl acc)))
       (go rs acc) (? (! (two? rs)) acc (go (cup rs) (add (caup (cup (cap rs))) acc)))   ; reloc = (off kind label)
       a1 (go trel ())
       (go2 rs acc) (? (! (two? rs)) acc (go2 (cup rs) (add (caup (cup (cap rs))) acc)))
       (rev (go2 drel a1)))

   ; a 24-byte symbol-table entry, and a 24-byte RELA entry.
   (o-sym nameoff bind typ shndx value)
    (catall (L (le32 nameoff) (L (| (<< bind 4) typ) 0) (le16 shndx) (le64 value) (le64 0)))
   (o-rela offset symidx typ addend)
    (catall (L (le64 offset) (le64 (+ (* symidx 4294967296) typ)) (le64 addend)))

   ; a string table from a list of names -> (blob (offset..)); leading NUL, so the
   ; k-th name's offset is where it starts. shared for .strtab and .shstrtab.
   (o-strtab names)
    (: (go ns off bacc offs)
        (? (! (two? ns)) (L (rev bacc) (rev offs))
           (: bs (cat (o-strbytes (cap ns)) (L 0))
              (go (cup ns) (+ off (tally bs)) (cat (rev bs) bacc) (link off offs))))
       (go names 1 (L 0) ()))

   ; build the whole .o image. textforms/dataforms are cgen-obj's split IR,
   ; funcnames the DEFINED functions (global FUNC symbols), globnames the global
   ; variables (global OBJECT symbols). -> a byte list.
   (objelf target textforms dataforms funcnames globnames)
    (: _ (? (id? target 'x64) 0 (scare 'obj-x64-only target))
       machine (peep elf-machines target 0)
       be (peep (holo 'backends) target ())
       tp ((holo 'lay) textforms be 0 () (tablet 0))  ; assemble each section at org 0
       dp ((holo 'lay) dataforms be 0 () (tablet 0))
       tlabels (cup tp) dlabels (cup dp)
       tw (o-walk be (cap tp) tlabels 1 0 () ())
       dw (o-walk be (cap dp) dlabels 0 0 () ())
       tbytes (cap tw) trel (caup tw)
       dbytes (cap dw) drel (caup dw)
       exts (o-exts trel drel tlabels dlabels)

       ; -- symbol indices: NULL, .text sec, .data sec, then funcs, globs, exts --
       nfun (tally funcnames) nglob (tally globnames)
       fstart 3 gstart (+ 3 nfun) estart (+ (+ 3 nfun) nglob)
       extidx (: t (tablet 0) (go es i) (? (! (two? es)) t (: _ (pin t (cap es) (+ estart i)) (go (cup es) (+ i 1))))
                  (go exts 0))

       ; -- .strtab: every symbol's name (funcs, globs, exts as spellings) --
       symnames (cat funcnames (cat globnames (map (\ s (string s)) exts)))
       str (o-strtab symnames)
       strblob (cap str) stroffs (caup str)
       (nthr l i) (? (< i 1) (cap l) (nthr (cup l) (- i 1)))

       ; -- the symbol table: locals (NULL + 2 section syms) then the globals --
       symbytes
        (: fsyms (: (go fs i acc) (? (! (two? fs)) acc
                                     (go (cup fs) (+ i 1)
                                         (cat acc (o-sym (nthr stroffs i) 1 2 1 (peep tlabels (intern (cap fs)) 0)))))
                    (go funcnames 0 ()))
           gsyms (: (go gs i acc) (? (! (two? gs)) acc
                                     (go (cup gs) (+ i 1)
                                         (cat acc (o-sym (nthr stroffs (+ nfun i)) 1 1 2 (peep dlabels (intern (cap gs)) 0)))))
                    (go globnames 0 ()))
           esyms (: (go es i acc) (? (! (two? es)) acc
                                     (go (cup es) (+ i 1)
                                         (cat acc (o-sym (nthr stroffs (+ (+ nfun nglob) i)) 1 0 0 0))))
                    (go exts 0 ()))
           (catall (L (o-sym 0 0 0 0 0)                 ; the NULL symbol
                      (o-sym 0 0 3 1 0)                  ; .text section symbol (STT_SECTION)
                      (o-sym 0 0 3 2 0)                  ; .data section symbol
                      fsyms gsyms esyms)))
       nsym (+ 3 (+ nfun (+ nglob (tally exts))))

       ; -- the relocations. text: an la into .data -> PC32 via the .data section
       ; symbol (idx 2, addend = data offset - 4); a call to an external -> PLT32.
       ; data: an abs64 pointer -> R_64 via the target's section symbol + offset,
       ; or an external symbol. --
       reltext
        (: (go rs acc)
            (? (! (two? rs)) acc
               (: r (cap rs) off (cap r) lbl (caup (cup r))
                  (? (o-has? dlabels lbl)
                      (go (cup rs) (cat acc (o-rela off 2 r-pc32 (- (peep dlabels lbl 0) 4))))
                     (go (cup rs) (cat acc (o-rela off (peep extidx lbl 0) r-plt32 -4))))))
           (go trel ()))
       reldata
        (: (go rs acc)
            (? (! (two? rs)) acc
               (: r (cap rs) off (cap r) lbl (caup (cup r))
                  (? (o-has? tlabels lbl)
                      (go (cup rs) (cat acc (o-rela off 1 r-64 (peep tlabels lbl 0))))
                     (o-has? dlabels lbl)
                      (go (cup rs) (cat acc (o-rela off 2 r-64 (peep dlabels lbl 0))))
                     (go (cup rs) (cat acc (o-rela off (peep extidx lbl 0) r-64 0))))))
           (go drel ()))
       ntrel (tally trel) ndrel (tally drel)

       ; -- the section-name string table --
       shnames (L ".text" ".data" ".symtab" ".strtab" ".rela.text" ".rela.data" ".shstrtab")
       shstr (o-strtab shnames)
       shstrblob (cap shstr) shoffs (caup shstr)
       (shname i) (nthr shoffs i)

       ; -- file layout: header, then section contents packed tight, then the SHT.
       ; the linker reads each section by (sh_offset, sh_size), so no in-file
       ; alignment padding is needed; sh_addralign drives final placement. --
       h-sz 64
       t-off h-sz               t-sz (tally tbytes)
       d-off (+ t-off t-sz)     d-sz (tally dbytes)
       sym-off (+ d-off d-sz)   sym-sz (* nsym 24)
       str-off (+ sym-off sym-sz) str-sz (tally strblob)
       rt-off (+ str-off str-sz)  rt-sz (* ntrel 24)
       rd-off (+ rt-off rt-sz)    rd-sz (* ndrel 24)
       shs-off (+ rd-off rd-sz)   shs-sz (tally shstrblob)
       sht-off (+ shs-off shs-sz)

       ; a 64-byte section header
       (sh nameoff typ flags off sz link info align entsz)
        (catall (L (le32 nameoff) (le32 typ) (le64 flags) (le64 0)
                   (le64 off) (le64 sz) (le32 link) (le32 info) (le64 align) (le64 entsz)))
       sht (catall (L
              (o-zeros 64)                                                 ; 0 NULL
              (sh (shname 0) 1 6 t-off t-sz 0 0 16 0)                      ; 1 .text  PROGBITS ALLOC|EXEC
              (sh (shname 1) 1 3 d-off d-sz 0 0 8 0)                       ; 2 .data  PROGBITS ALLOC|WRITE
              (sh (shname 2) 2 0 sym-off sym-sz 4 3 8 24)                  ; 3 .symtab link=.strtab info=first-global(3)
              (sh (shname 3) 3 0 str-off str-sz 0 0 1 0)                   ; 4 .strtab
              (sh (shname 4) 4 0 rt-off rt-sz 3 1 8 24)                    ; 5 .rela.text link=.symtab info=.text
              (sh (shname 5) 4 0 rd-off rd-sz 3 2 8 24)                    ; 6 .rela.data link=.symtab info=.data
              (sh (shname 6) 3 0 shs-off shs-sz 0 0 1 0)))                 ; 7 .shstrtab

       hdr (catall (L
              (L 127 69 76 70 2 1 1 0 0 0 0 0 0 0 0 0)                     ; e_ident: \x7fELF 64-bit LSB
              (le16 1) (le16 machine) (le32 1)                            ; ET_REL, e_machine, version
              (le64 0) (le64 0) (le64 sht-off)                            ; e_entry=0, e_phoff=0, e_shoff
              (le32 0) (le16 64) (le16 0)                                 ; e_flags, e_ehsize, e_phentsize=0
              (le16 0) (le16 64) (le16 8)                                 ; e_phnum=0, e_shentsize=64, e_shnum=8
              (le16 7)))                                                  ; e_shstrndx=7
       (catall (L hdr tbytes dbytes symbytes strblob reltext reldata shstrblob sht))))
