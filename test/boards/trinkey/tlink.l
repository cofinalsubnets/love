; test/boards/trinkey/tlink.l -- the trinkey's link: holo's ldbare32 (src/love/holo/link.l) with
; its sram map, in two stages. cat it after src/love/holo/{elf,obj,link}.l and run
;
;   love <cat> OUT OBJ.o..
;
; the first stage is what the uf2 bootloader's sam-ba loads, above the bootloader's own data and
; stack (its sp starts at 0x20002de0) and below its double-tap word at the top. the second, the
; objects whose sections carry the .s2 prefix, is laid at sram's base, which the bootloader
; holds until the first stage runs, and comes over the first stage's usb console. the first
; stage's .data and .bss are copied between them, its stack under it
(: s2 0x20000000 s2end 0x20004400 s1 0x20005800
   ; presence out of band: an unreadable file and an empty one are the same value,
   ; and an empty .o here would link a firmware with a silent hole in it.
   (tread p) (uread p @ r (two? r ? [p <>r] (scare 'tlink-open p)))
   (: as >argv out <as objs >as
      _ (two? objs ? 0 (scare 'tlink-no-objects out))
      set (map tread objs)
      lib (set + ldarch set () 'thumb1)
      runs [['at s2 (intern ".s2.text") (intern ".s2.rodata") (intern ".s2.data") (intern ".s2.bss")]
            ['at s1 (intern ".vectors") 'text 'rodata]
            ['copy s2end 'data 'bss]]
      (ld-write out (ldbare32 'thumb1 runs lib [["__stack_top__" s1] ["__s2_base__" s2] ["__s2_end__" s2end]] ()), 0)))
