; apps/utils/asbook.l -- re-leak the few asm-book names apps/asm/elf.l reads bare.
; elf.l predates the asm sweep and loads as a post-boot STREAM inside the multi-call
; `au`, where assemble/catall/le* live only in the `asm` book -- this body-less `:`
; puts the ones elf.l actually reads back on the global book, and the capture law
; does the rest (elf.l's closures fold them at their own load, right after this).
; au's cat order: .. asbook.l, apps/asm/elf.l, apps/utils/au.l.
(: catall (asm 'catall)
   le16 (asm 'le16) le32 (asm 'le32) le64 (asm 'le64)
   asm-bytes (asm 'asm-bytes))
