; elf -- a minimal static-executable LINKER: it wraps assembled bytes in a Linux x86-64 ELF so the
; kernel will load and run them. one PT_LOAD segment maps the whole file (headers included) at a
; fixed base; the entry point is the first byte of code. it is the smallest thing that turns the
; assembler's output into a file you can chmod +x and run -- the literal "probe the binary" proof.
;
; `elf64` takes a program-BUILDER (\ dataddr -> IR): the builder is handed the absolute address its
; trailing data will live at, so a program can `li` a pointer to its own string. the round trip:
; assemble once with a placeholder to measure the code (every address here is < 2^31, so each `li`
; is the stable 7-byte form and the length doesn't move), place the data just past it, then assemble
; for real. load after asm.l + x64.l.

(: elf-base 4194304                                            ; 0x400000, the classic ET_EXEC base
   elf-hdr  120                                                ; 64-byte ELF header + 56-byte phdr
   (catall ls) (foldr cat () ls)

   ;; the 120-byte header for a single R+X load segment covering the whole `filesz`-byte file.
   (elf64-hdr entry filesz)
      (catall (L
         (L 127 69 76 70 2 1 1 0 0 0 0 0 0 0 0 0)              ; e_ident: \x7fELF, 64-bit LSB SysV
         (le16 2) (le16 62) (le32 1)                           ; ET_EXEC, x86-64, version 1
         (le64 entry) (le64 64) (le64 0)                       ; e_entry, e_phoff=64, e_shoff=0
         (le32 0) (le16 64) (le16 56)                          ; e_flags, e_ehsize=64, e_phentsize=56
         (le16 1) (le16 0) (le16 0) (le16 0)                   ; e_phnum=1, no section headers
         (le32 1) (le32 5) (le64 0)                            ; PT_LOAD, flags R+X, p_offset=0
         (le64 elf-base) (le64 elf-base)                       ; p_vaddr, p_paddr
         (le64 filesz) (le64 filesz) (le64 4096)))             ; p_filesz, p_memsz, p_align

   ;; build a complete executable image. `mkprog` is (\ dataddr -> IR); `data` is the byte list
   ;; appended after the code. returns a tablet { 'bytes 'entry 'dataddr }.
   (elf64 mkprog data)
      (: probe-len (tally (asm 'x64 (mkprog (+ elf-base 65536))))  ; measure the code (length stable)
         dataddr (+ elf-base (+ elf-hdr probe-len))
         code (asm 'x64 (mkprog dataddr))
         filesz (+ elf-hdr (+ (tally code) (tally data)))
         entry (+ elf-base elf-hdr)
         img (catall (L (elf64-hdr entry filesz) code data))
         res (tablet 0)
         _ (pin res 'bytes img) _ (pin res 'entry entry) _ (pin res 'dataddr dataddr)
         res)

   ;; write a byte list to a file (length-counted, so embedded NULs survive).
   (write-bytes path bs) (: q (open path "w") _ (say q (string bs)) (close q)))
