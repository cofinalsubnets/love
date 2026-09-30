; src/inle/teensy41/tlink.l -- the Teensy 4.1 link: holo's ldbare32 (src/love/holo/link.l) in place
; of arm-none-eabi-ld + teensy41.lds. cat it after src/love/holo/{elf,obj,link}.l and run
;
;   love <cat> OUT OBJ.o..
;
; the i.MX RT1062 boots XIP from FlexSPI NOR at 0x60000000, and its ROM reads the config block at
; flash offset 0 and the image vector table at 0x1000 before any of our code runs, so the map states
; both. the gap between the two `at` runs is file bytes: they fuse into one segment, so flash
; offsets and addresses are the same number (the .hex verify seeks by it). RAM is the 512 KB OCRAM2,
; mapped at reset whatever the FlexRAM split; .data is stored in flash and runs there (`copy`).
(: ocram2-top 0x20280000                    ; 0x20200000 + 512 KB
   ; presence out of band: an unreadable file and an empty one are the same value,
   ; and an empty .o here would link a firmware with a silent hole in it.
   (tread p) (uread p @ r (two? r ? [p <>r] (scare 'tlink-open p)))
   (tar? p) (#p @ n (2 < n && snip p (n - 2) n = ".a"))
   (: as >argv
      out <as ins >as
      objs (filter (p \ !(tar? p)) ins)
      ars (filter tar? ins)
      _ (two? objs ? 0 (scare 'tlink-no-objects out))
      set (map tread objs)
      lib (set + ldarch set (map tread ars) 'thumb2)
      runs [['at 0x60000000 (intern ".flashconfig")]
            ['at 0x60001000 (intern ".ivt") (intern ".bootdata") (intern ".vectors")
                            'text 'rodata 'image]
            ['copy 0x20200000 'data 'nifs 'bss]]
      (ld-write out (ldbare32 'thumb2 runs lib [["__stack_top__" ocram2-top]] ()), 0)))
