; elf -- a minimal static-executable writer: assembled bytes in an ELF whose one PT_LOAD maps
; the whole file (headers included) at a fixed base, entry at the first code byte. the target
; picks the backend and e_machine.
;
; `elf64` takes a target and a program-builder (\ dataddr -> IR), handed the address its
; trailing data will live at. it assembles once with a placeholder to measure the code (every
; address is < 2^31, so the length does not move), then for real. load after holo.l + the backend(s).

(module 'holo
(borrow 'posix)

(: elf-base 4194304                                            ; 0x400000, the classic et_exec base
   elf-hdr  120                                                ; 64-byte ELF header + 56-byte phdr
   ;; Elf64_Sym (24 bytes) and Elf64_Shdr (64), and the elf32 twins (16 and 40).
   ;; Elf32_Sym puts st_value and st_size ahead of st_info/st_other/st_shndx.
   (elf-sym nameoff bind typ shndx value size)
    (catall [(le32 nameoff) [(bind << 4 | typ) 0] (le16 shndx) (le64 value) (le64 size)])
   (elf-shdr nm ty fl ad off sz lk inf al es)
    (catall [(le32 nm) (le32 ty) (le64 fl) (le64 ad) (le64 off) (le64 sz)
             (le32 lk) (le32 inf) (le64 al) (le64 es)])
   (elf-sym32 nameoff bind typ shndx value size)
    (catall [(le32 nameoff) (le32 value) (le32 size) [(bind << 4 | typ) 0] (le16 shndx)])
   (elf-shdr32 nm ty fl ad off sz lk inf al es)
    (catall [(le32 nm) (le32 ty) (le32 fl) (le32 ad) (le32 off) (le32 sz)
             (le32 lk) (le32 inf) (le32 al) (le32 es)])
   elf-machines {'x64 62 'a64 183                              ; canonical keys only (prel.l's arch-canon)
                 'thumb1 40 'thumb2 40 'thumb2sp 40 'arm 40    ; EM_ARM
                 'i386 3 'i386m16 3                            ; EM_386, the 16-bit face's code too
                 'rv64 243}                                  ; EM_RISCV

   ;; one 56-byte program header. p_paddr differs from p_vaddr only for a kernel loaded low.
   (elf64-phdr ty fl off va pa fsz msz al)
    (catall [(le32 ty) (le32 fl) (le64 off) (le64 va) (le64 pa)
             (le64 fsz) (le64 msz) (le64 al)])

   ;; the 64-byte ELF header + N elf64-phdrs. etype 2 ET_EXEC, or 3 ET_DYN (a static-pie that
   ;; self-relocates at startup). sh is () for no section headers, or (shoff shnum shstrndx):
   ;; that table lies past p_filesz, mapped by nothing, for nm/gdb.
   (elf64-hdrn etype entry machine sh phs)
    (: shoff (two? sh ? <sh 0) shnum (two? sh ? <>sh 0) shstrx (two? sh ? <>>sh 0)
       rv64? (machine = 243)
      (catall [
        '(127 69 76 70 2 1 1 0 0 0 0 0 0 0 0 0)               ; e_ident: \x7fELF, 64-bit LSB SysV
        (le16 etype) (le16 machine) (le32 1)                   ; e_type (2 EXEC / 3 DYN), e_machine, version 1
        (le64 entry) (le64 64) (le64 shoff)                    ; e_entry, e_phoff=64, e_shoff
        (le32 (rv64? ? 5 0)) (le16 64) (le16 56)                 ; e_flags (riscv: RVC | FLOAT_ABI_DOUBLE), e_ehsize=64, e_phentsize=56
        (le16 #phs) (le16 (two? sh ? 64 0)) (le16 shnum) (le16 shstrx)
        (catall phs)]))

   ;; the 120-byte header for one rwx load segment at `base` covering the whole file;
   ;; memsz past filesz is .bss, zeroed by the kernel.
   (elf64-hdr etype base entry filesz memsz machine sh)
    (elf64-hdrn etype entry machine sh
                [(elf64-phdr 1 7 0 base base filesz memsz 4096)])

   ;; an executable image for target loaded at `base`; `data` is the bytes after the code.
   ;; -> { 'bytes 'entry 'dataddr }
   (elf64-at base target mkprog data)
      (: machine (elf-machines target)
         _ (!machine ? (scare 'no-elf-machine target))
         org (base + elf-hdr)
         probe-len #(holo-bytes-at target (mkprog (base + 65536)) org)
         dataddr (base + elf-hdr + probe-len)
         ;; at org, labels carry load addresses, so an abs64 data pointer resolves outright
         code (holo-bytes-at target (mkprog dataddr) org)
         filesz (elf-hdr + #code + #data)
         entry (base + elf-hdr)
         img (catall [(elf64-hdr 2 base entry filesz filesz machine ()) code data])
         {'bytes img 'entry entry 'dataddr dataddr})
   (elf64 target mkprog data) (elf64-at elf-base target mkprog data)

   elf-hdr32 84                                                ; 52-byte ELF32 header + 32-byte phdr

   ;; -- the elf32 twins: an Elf32_Phdr keeps p_flags seventh, an Elf64_Phdr second,
   ;; so no width knob covers both.
   ;; one 32-byte program header.
   (elf32-phdr ty fl off va pa fsz msz al)
    (catall [(le32 ty) (le32 off) (le32 va) (le32 pa)
             (le32 fsz) (le32 msz) (le32 fl) (le32 al)])

   ;; the 52-byte ELF32 header + N elf32-phdrs. on EM_ARM, e_entry carries the thumb bit
   ;; (every arm backend here emits thumb) and e_flags is the caller's eflags.
   (elf32-hdrn etype entry machine eflags sh phs)
    (: shoff (two? sh ? <sh 0) shnum (two? sh ? <>sh 0) shstrx (two? sh ? <>>sh 0)
       arm? (machine = 40)
      (catall [
        '(127 69 76 70 1 1 1 0 0 0 0 0 0 0 0 0)               ; e_ident: \x7fELF, 32-bit LSB SysV
        (le16 etype) (le16 machine) (le32 1)                   ; e_type (2 EXEC / 3 DYN), e_machine, version 1
        (le32 (arm? ? (entry | 1) entry)) (le32 52) (le32 shoff)    ; e_entry, e_phoff=52, e_shoff
        (le32 (arm? ? eflags 0)) (le16 52) (le16 32)           ; e_flags (arm-eflags), e_ehsize=52, e_phentsize=32
        (le16 #phs) (le16 (two? sh ? 40 0)) (le16 shnum) (le16 shstrx)
        (catall phs)]))

   ;; the 84-byte header for one rwx load segment at `base` covering the whole file
   (elf32-hdr etype base entry filesz memsz machine eflags sh)
    (elf32-hdrn etype entry machine eflags sh
                [(elf32-phdr 1 7 0 base base filesz memsz 4096)])

   ;; e_flags for an EM_ARM executable: eabi 5 (0x05000000), plus ABI_FLOAT_HARD (0x400) for
   ;; a target with an fpu, mooncc having no softfp lane. a .o carries plain 0x05000000.
   (arm-eflags target) (elem target '(thumb2 thumb2sp arm) ? 83887104 83886080)

   ;; elf64-at's twin at 32 bits. 'entry is the even code address; the thumb bit is the header's.
   (elf32-at base target mkprog data)
      (: machine (elf-machines target)
         _ (!machine ? (scare 'no-elf-machine target))
         org (base + elf-hdr32)
         probe-len #(holo-bytes-at target (mkprog (base + 65536)) org)
         dataddr (base + elf-hdr32 + probe-len)
         code (holo-bytes-at target (mkprog dataddr) org)
         filesz (elf-hdr32 + #code + #data)
         img (catall [(elf32-hdr 2 base org filesz filesz machine (arm-eflags target) ()) code data])
         res {'bytes img 'entry org 'dataddr dataddr})
   (elf32 target mkprog data) (elf32-at elf-base target mkprog data)

   ;; write a byte list to a file, as casks; a string item (holo.l's blob) goes out whole.
   (write-bytes path bs)
    (: q (open path "w")
       ;; the runs between blobs are short, so the `rev` copy stays small
       (go l acc) (? !(two? l) (say q (cask (rev acc)))
                     (string? <l) (say q (cask (rev acc)), say q <l, go >l ())
                     (go >l (<l . acc)))
       ;; a list with no blob goes out in one cask, uncopied
       (any string? bs ? (go bs ()) (say q (cask bs)),
        close q)))
) ; module 'holo
