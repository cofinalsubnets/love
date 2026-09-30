; test/gate/elf32.l -- an arm linux executable from holo's ELF32 writer, judged by a real loader
; (qemu-arm): no assembler, linker or libc. the fields worth a gate are the ones a loader refuses
; on -- Elf32_Phdr keeps p_flags seventh, and e_entry's bit 0 enters thumb. write(1,msg,n) then
; exit(42), eabi: the call number in r7, `svc #0` is holo's `sys`.
; run: cat holo.l <backend>.l elf.l elf32.l, then (elf32-write '<tgt> "<path>"). holo rides
; module 'holo, so the cat's names are not ambient: without the borrow, `;; missing elf32`.
(borrow 'holo)
(: (elf32-write tgt path)
   (: msg "love-asm speaks arm32 linux\n"
      (prog a) [['li 'r0 1] ['li 'r1 a] ['li 'r2 #msg] ['li 'r7 4] ['sys]
                ['li 'r0 42] ['li 'r7 1] ['sys]]
      e (elf32 tgt prog (map msg (jot #msg)))
      (write-bytes path (peep e 'bytes 0),
       flush out)))
