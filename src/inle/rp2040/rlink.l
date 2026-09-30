; src/inle/rp2040/rlink.l -- the Raspberry Pi Pico link: holo's ldbare32 (src/love/holo/link.l) in
; place of arm-none-eabi-ld + rp2040.lds. cat it after src/love/holo/{elf,obj,link}.l and run
;
;   love <cat> OUT OBJ.o..
;
; the mask ROM reads the first 256 bytes of flash (0x10000000) as a checksummed second stage
; (mkboot2.l), then jumps to the vector table at 0x10000100. both addresses are the silicon's, so
; the map names them, and .boot2 must be first or the checksum reads the wrong bytes. the stack
; tops the 264 KB SRAM; .data is stored in flash and runs in SRAM (the `copy` run).
(: sram-top 0x20042000                      ; 0x20000000 + 264 KB
   ; presence out of band: an unreadable file and an empty one are the same value,
   ; and an empty .o here would link a firmware with a silent hole in it.
   (rread p) (uread p @ r (two? r ? [p <>r] (scare 'rlink-open p)))
   (rar? p) (#p @ n (2 < n && snip p (n - 2) n = ".a"))
   (: as >argv
      out <as ins >as
      objs (filter (p \ !(rar? p)) ins)
      ars (filter rar? ins)
      _ (two? objs ? 0 (scare 'rlink-no-objects out))
      ; v6-M has no divide and no FPU, so the __aeabi_* set comes from gcc's cortex-m0
      ; libgcc -- named on the line, pulled by need through the ranlib index.
      set (map rread objs)
      lib (set + ldarch set (map rread ars) 'thumb1)
      ; flash is R|X: .vectors is const to the silicon, and nothing on the run is written
      ; once the linker has resolved the handler addresses.
      runs [['at 0x10000000 '(flags 5) (intern ".boot2")]
            ['at 0x10000100 (intern ".vectors") 'text 'rodata]
            ['copy 0x20000000 'data 'bss]]
      (ld-write out (ldbare32 'thumb1 runs lib [["__stack_top__" sram-top]] ()), 0)))
