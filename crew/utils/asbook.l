; crew/utils/asbook.l -- re-leak the few asm-book names crew/holo/elf.l reads bare.
; elf.l predates the holo sweep and loads as a post-boot STREAM inside the multi-call
; `au`, where assemble/catall/le* live only in the `holo` book -- this body-less `:`
; puts the ones elf.l actually reads back on the global book, and the capture law
; does the rest (elf.l's closures fold them at their own load, right after this).
; au's cat order: .. asbook.l, crew/holo/elf.l, crew/utils/au.l.
(: catall (holo 'catall)
   le16 (holo 'le16) le32 (holo 'le32) le64 (holo 'le64)
   holo-bytes (holo 'holo-bytes) holo-bytes-at (holo 'holo-bytes-at))
