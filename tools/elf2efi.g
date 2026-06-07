#!/usr/bin/env gl
; elf2efi.g -- wrap a statically-linked ELF into a PE32+ EFI image.
;
; Port of tools/elf2efi.py (see it for the full rationale and the layout
; diagram). The riscv64 and loongarch64 EFI builds can't go through lld's
; COFF backend (no LLVM port), so they link a plain static ELF with
; --emit-relocs and this tool stamps the PE32+ wrapper around the same
; loadable bytes: copy each PT_LOAD verbatim, then append a generated .reloc
; built from the ELF's absolute-64 relocation records.
;
; Usage: gl elf2efi.g INPUT.elf OUTPUT.efi
;
; The input ELF is read whole via slurp (a plain immutable string, indexed
; byte-wise by get); the output is assembled in a mutable buf -- bufnew sizes
; it up front, wr/put back-patch header fields at absolute offsets, and bcopy
; blits the loadable segments and the .reloc blob into place.

(: (die m) (: _ (fputs err "elf2efi: ") _ (fputs err m) _ (fputs err "\n") (exit 1)))

; --- little-endian decoders over the slurped image (string s) -------
; (get 0 o s) -> byte o as an unsigned fixnum 0..255 (text_q case of get).
(: (u8 s o)   (get 0 o s)
   (rd16 s o) (| (u8 s o)   (<< (u8 s (+ o 1)) 8))
   (rd32 s o) (| (rd16 s o) (<< (rd16 s (+ o 2)) 16))
   (rd64 s o) (| (rd32 s o) (<< (rd32 s (+ o 4)) 32)))

; NUL-terminated ascii at offset o -> string.
(: (cstr s o) ((: (f i) (? (= 0 (u8 s i)) (ssub s o i) (f (+ i 1)))) o))

(: (align-up x a) (& (+ x (- a 1)) (~ (- a 1)))
   (prefix? p s) (= p (ssub s 0 (len p))))

; --- writers ---------------------------------------------------------
; (wr out o n v): store the low n bytes of v little-endian into buf out at
; offset o; return the next offset (o+n) so header fields chain naturally.
(: (wr out o n v)
   ((: (f k v) (? (< k n) (: _ (put (+ o k) (& v 255) out) (f (+ k 1) (>> v 8))) (+ o n))) 0 v))

; (pn o n v): same, but emit to a strout sink (used while the .reloc blob's
; length is still unknown); return the sink.
(: (pn o n v)
   ((: (f k v) (? (< k n) (: _ (fputc o (& v 255)) (f (+ k 1) (>> v 8))) o)) 0 v))

; --- merge sort on a list of fixnums (ascending) --------------------
; collect_relocs concatenates per-section reloc lists, so the RVAs need a
; global sort to match the .py (build-reloc groups them by page in order).
(: (merge a b)
   (? (twop a)
      (? (twop b)
         (? (<= (car a) (car b)) (cons (car a) (merge (cdr a) b)) (cons (car b) (merge a (cdr b))))
         a)
      b)
   (msort l) (? (twop (cdr l)) (: n (>> (len l) 1) (merge (msort (take n l)) (msort (drop n l)))) l))

; --- section / program-header records -------------------------------
; section record = (name type flags offset size); fields via (get 0 i rec).
(: (sec-name s) (get 0 0 s) (sec-type s) (get 0 1 s) (sec-flags s) (get 0 2 s)
   (sec-off s)  (get 0 3 s) (sec-size s) (get 0 4 s)
   (find-sec secs nm) (? (twop secs) (? (= nm (sec-name (car secs))) (car secs) (find-sec (cdr secs) nm))))

(: (sections s shoff shent shnum stroff)
   ((: (loop i)
       (? (< i shnum)
          (: o  (+ shoff (* i shent))
             (cons (L (cstr s (+ stroff (rd32 s o)))   ; sh_name -> name
                      (rd32 s (+ o 4))                 ; sh_type
                      (rd64 s (+ o 8))                 ; sh_flags
                      (rd64 s (+ o 24))                ; sh_offset
                      (rd64 s (+ o 32)))               ; sh_size
                   (loop (+ i 1))))
          0))
    0))

; PT_LOAD program headers with memsz>0 -> list of (flags offset vaddr filesz memsz).
(: (loads s phoff phent phnum)
   ((: (loop i)
       (? (< i phnum)
          (: o    (+ phoff (* i phent))
             rest (loop (+ i 1))
             (? (&& (= 1 (rd32 s o)) (< 0 (rd64 s (+ o 40))))   ; PT_LOAD && p_memsz>0
                (cons (L (rd32 s (+ o 4)) (rd64 s (+ o 8)) (rd64 s (+ o 16)) (rd64 s (+ o 32)) (rd64 s (+ o 40))) rest)
                rest))
          0))
    0))

; --- collect absolute-64 reloc RVAs ---------------------------------
; r_type = r_info & 0xffffffff is just the low 4 bytes of r_info (LE), so
; rd32 reads it directly -- no need to widen r_info. R_RISCV_64 == R_LARCH_64
; == 2, so one constant covers both supported machines.
(: (relocs-in s off n acc)
   (? (< 0 n)
      (relocs-in s (+ off 24) (- n 1)
         (? (= 2 (rd32 s (+ off 8))) (cons (rd64 s off) acc) acc))   ; abs64 -> keep r_offset
      acc))

; secs scanned for SHT_RELA(4) sections named .rela* whose target is allocated.
(: (collect s secs all)
   (? (twop secs)
      (: sec  (car secs)
         more (collect s (cdr secs) all)
         (? (&& (= 4 (sec-type sec)) (prefix? ".rela" (sec-name sec)))
            (: tgt (find-sec all (ssub (sec-name sec) 5 (len (sec-name sec))))
               (? (&& tgt (!= 0 (& (sec-flags tgt) 2)))             ; SHF_ALLOC == 2
                  (cat (relocs-in s (sec-off sec) (/ (sec-size sec) 24) 0) more)
                  more))
            more))
      0))

; --- build the PE .reloc blob (one IMAGE_REL_BASED_DIR64 per RVA) ----
; Each block: <page RVA u32><block size u32> then u16 entries (type:4|off:12),
; padded to a 4-byte multiple with a type-0 (ABSOLUTE) no-op entry.
(: (pageof r) (& r (~ 4095))
   (samepage page lst) (? (&& (twop lst) (= page (pageof (car lst)))) (cons (car lst) (samepage page (cdr lst))))
   (dropsame page lst) (? (&& (twop lst) (= page (pageof (car lst)))) (dropsame page (cdr lst)) lst))

(: (emit-blocks o rvas)
   (? (twop rvas)
      (: page    (pageof (car rvas))
         here    (samepage page rvas)
         rest    (dropsame page rvas)
         ents    (map (\ r (| (<< 10 12) (& r 4095))) here)        ; DIR64 == 10
         padded  (? (& (len ents) 1) (cat ents (L 0)) ents)        ; ABSOLUTE(0) pad if odd
         size    (+ 8 (* 2 (len padded)))
         _ (pn o 4 page)
         _ (pn o 4 size)
         _ (each padded (\ e (pn o 2 e)))
         (emit-blocks o rest))
      0))

(: (reloc-blob rvas) (: o (strout 0) _ (emit-blocks o rvas) (outstr o)))

; --- one 40-byte section table entry --------------------------------
; out is pre-zeroed, so the name's trailing bytes (up to 8) stay 0.
(: (section-entry out o name vsize vaddr rsize raddr flags)
   (: _ (bcopy out o name 0 (len name))
      o (+ o 8)
      o (wr out o 4 vsize)  o (wr out o 4 vaddr)
      o (wr out o 4 rsize)  o (wr out o 4 raddr)
      o (wr out o 4 0)      o (wr out o 4 0)        ; PointerToRelocations / Linenumbers
      o (wr out o 2 0)      o (wr out o 2 0)        ; NumberOf Relocations / Linenumbers
      (wr out o 4 flags)))

; 16 data directories; entry 5 (BaseRelocationTable) carries .reloc if present.
(: (emit-dirs out o rva rsz)
   ((: (f i o)
       (? (< i 16)
          (: o (? (&& (= i 5) (< 0 rsz)) (: o (wr out o 4 rva) (wr out o 4 rsz))
                                         (: o (wr out o 4 0)   (wr out o 4 0)))
             (f (+ i 1) o))
          o))
    0 o))

; --- driver ----------------------------------------------------------
(: args       (cdr argv)
   inpath     (? (twop args) (car args) (die "usage: elf2efi.g INPUT.elf OUTPUT.efi"))
   outpath    (? (twop (cdr args)) (car (cdr args)) (die "usage: elf2efi.g INPUT.elf OUTPUT.efi"))
   port       (open inpath "r")
   _          (? port 0 (die (scat "cannot open " inpath)))
   s          (slurp port)
   _          (? (&& (= 127 (u8 s 0)) (= 69 (u8 s 1)) (= 76 (u8 s 2)) (= 70 (u8 s 3))) 0
                 (die (scat inpath ": not an ELF file")))
   _          (? (&& (= 2 (u8 s 4)) (= 1 (u8 s 5))) 0
                 (die (scat inpath ": not ELF64 little-endian")))
   e_machine  (rd16 s 18)
   pe_machine (? (= e_machine 243) 0x5064                ; EM_RISCV     -> IMAGE_FILE_MACHINE_RISCV64
              (? (= e_machine 258) 0x6264                ; EM_LOONGARCH -> IMAGE_FILE_MACHINE_LOONGARCH64
                 (die (scat inpath ": unsupported e_machine"))))
   e_entry    (rd64 s 24)
   phoff      (rd64 s 32)
   shoff      (rd64 s 40)
   phent      (rd16 s 54)
   phnum      (rd16 s 56)
   shent      (rd16 s 58)
   shnum      (rd16 s 60)
   shstrndx   (rd16 s 62)
   stroff     (rd64 s (+ (+ shoff (* shstrndx shent)) 24))   ; shstrtab sh_offset
   secs       (sections s shoff shent shnum stroff)
   lds        (loads s phoff phent phnum)
   _          (? (= 2 (len lds)) 0 (die "expected 2 PT_LOAD program headers"))
   la         (get 0 0 lds)
   lb         (get 0 1 lds)
   loval      (< (get 0 2 la) (get 0 2 lb))                  ; la has the lower VMA?
   text-seg   (? loval la lb)
   data-seg   (? loval lb la)
   _          (? (= 0 (& (get 0 0 text-seg) 2)) 0 (die "first PT_LOAD is writable; section ordering is wrong"))
   _          (? (!= 0 (& (get 0 0 data-seg) 2)) 0 (die "second PT_LOAD is not writable; section ordering is wrong"))
   text-off   (get 0 1 text-seg)  text-va (get 0 2 text-seg)  text-fsize (get 0 3 text-seg)  text-msize (get 0 4 text-seg)
   data-off   (get 0 1 data-seg)  data-va (get 0 2 data-seg)  data-fsize (get 0 3 data-seg)  data-msize (get 0 4 data-seg)
   _          (? (>= text-va 0x1000) 0 (die "text VA overlaps PE header span"))
   _          (? (&& (= 0 (mod text-va 0x1000)) (= 0 (mod data-va 0x1000))) 0 (die "PT_LOAD VAs are not page-aligned"))
   text-raw   (align-up text-fsize 0x1000)
   data-raw   (align-up data-fsize 0x1000)
   reloc      (reloc-blob (msort (collect s secs secs)))
   reloc-size (len reloc)
   reloc-va   (align-up (+ data-va data-msize) 0x1000)
   reloc-off  (align-up (+ data-va data-raw) 0x1000)
   reloc-raw  (? (< 0 reloc-size) (align-up reloc-size 0x1000) 0)
   image-size (align-up (+ reloc-va reloc-size) 0x1000)
   outsize    (? (< 0 reloc-size) (+ reloc-off reloc-raw) (+ data-va data-raw))
   out        (bufnew outsize)
   ; --- DOS stub ---
   _ (put 0 77 out)                       ; 'M'
   _ (put 1 90 out)                       ; 'Z'
   _ (wr out 0x3c 4 0x40)                 ; e_lfanew -> PE header at 0x40
   ; --- PE signature + COFF header (contiguous from 0x40) ---
   c 0x40
   c (: _ (put c 80 out) _ (put (+ c 1) 69 out) (+ c 4))   ; "PE\0\0"
   c (wr out c 2 pe_machine)              ; Machine
   c (wr out c 2 3)                       ; NumberOfSections
   c (wr out c 4 0)                       ; TimeDateStamp
   c (wr out c 4 0)                       ; PointerToSymbolTable
   c (wr out c 4 0)                       ; NumberOfSymbols
   c (wr out c 2 240)                     ; SizeOfOptionalHeader
   c (wr out c 2 0x22e)                   ; EXECUTABLE|LINE_NUMS_STRIPPED|LOCAL_SYMS_STRIPPED|LARGE_ADDR_AWARE|DEBUG_STRIPPED
   ; --- optional header (PE32+) ---
   c (wr out c 2 0x20b)                   ; Magic
   c (wr out c 1 2)                       ; MajorLinkerVersion
   c (wr out c 1 20)                      ; MinorLinkerVersion
   c (wr out c 4 text-raw)                ; SizeOfCode
   c (wr out c 4 data-raw)                ; SizeOfInitializedData
   c (wr out c 4 (- data-msize data-fsize))  ; SizeOfUninitializedData (.bss tail)
   c (wr out c 4 e_entry)                 ; AddressOfEntryPoint
   c (wr out c 4 text-va)                 ; BaseOfCode
   c (wr out c 8 0)                       ; ImageBase
   c (wr out c 4 0x1000)                  ; SectionAlignment
   c (wr out c 4 0x1000)                  ; FileAlignment
   c (wr out c 2 0) c (wr out c 2 0)      ; Major/Minor OperatingSystemVersion
   c (wr out c 2 0) c (wr out c 2 0)      ; Major/Minor ImageVersion
   c (wr out c 2 0) c (wr out c 2 0)      ; Major/Minor SubsystemVersion
   c (wr out c 4 0)                       ; Win32VersionValue
   c (wr out c 4 image-size)              ; SizeOfImage
   c (wr out c 4 0x1000)                  ; SizeOfHeaders
   c (wr out c 4 0)                       ; CheckSum
   c (wr out c 2 10)                      ; Subsystem = EFI_APPLICATION
   c (wr out c 2 0)                       ; DllCharacteristics
   c (wr out c 8 0)                       ; SizeOfStackReserve
   c (wr out c 8 0)                       ; SizeOfStackCommit
   c (wr out c 8 0)                       ; SizeOfHeapReserve
   c (wr out c 8 0)                       ; SizeOfHeapCommit
   c (wr out c 4 0)                       ; LoaderFlags
   c (wr out c 4 16)                      ; NumberOfRvaAndSizes
   c (emit-dirs out c reloc-va reloc-size)
   ; --- section table ---
   c (section-entry out c ".text"  text-msize text-va text-raw text-va 0x60000020)  ; CODE|EXECUTE|READ
   c (section-entry out c ".data"  data-msize data-va data-raw data-va 0xc0000040)  ; INIT_DATA|READ|WRITE
   c (section-entry out c ".reloc" reloc-size reloc-va reloc-raw reloc-off 0x42000040)  ; INIT_DATA|DISCARDABLE|READ
   ; --- blit the loadable segments and the .reloc blob ---
   _ (bcopy out text-va s text-off text-fsize)
   _ (bcopy out data-va s data-off data-fsize)
   _ (? (< 0 reloc-size) (bcopy out reloc-off reloc 0 reloc-size) 0)
   ; --- write the image ---
   op (open outpath "w")
   _ (? op 0 (die (scat "cannot open " outpath)))
   (fputs op out))
