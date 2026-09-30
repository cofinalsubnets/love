; src/inle/nucleo446/nlink.l -- the Nucleo-F446RE link: holo's ldbare32 (src/love/holo/link.l) in
; place of arm-none-eabi-ld + nucleo446.lds. cat it after src/love/holo/{elf,obj,link}.l and run
;
;   love <cat> OUT OBJ.o..
;
; code lives in the 512 KB flash at 0x08000000, RAM is the 128 KB SRAM at 0x20000000, and .data is
; stored in flash but runs in SRAM (the `copy` run). .vectors is named first by hand: the core
; fetches SP and reset from flash base, and its ALLOC-only flags would file it after the code.
; .startup rides text, reached through the reset word. __stack_top__ is the top of SRAM.
(: sram-top 0x20020000                      ; 0x20000000 + 128 KB
   ; presence out of band: an unreadable file and an empty one are the same value,
   ; and an empty .o here would link a firmware with a silent hole in it.
   (nread p) (uread p @ r (two? r ? [p <>r] (scare 'nlink-open p)))
   (nar? p) (#p @ n (2 < n && snip p (n - 2) n = ".a"))
   (: as >argv
      out <as ins >as
      objs (filter (p \ !(nar? p)) ins)
      ars (filter nar? ins)
      _ (two? objs ? 0 (scare 'nlink-no-objects out))
      ; the soft-double set: mooncc's thumb2sp lane calls __aeabi_* for f64, from gcc's
      ; cortex-m4 hard-float libgcc, pulled by need through the ranlib index.
      set (map nread objs)
      lib (set + ldarch set (map nread ars) 'thumb2sp)
      runs [['at 0x08000000 (intern ".vectors") 'text 'rodata]
            ['copy 0x20000000 'data 'bss]]
      (ld-write out (ldbare32 'thumb2sp runs lib [["__stack_top__" sram-top]] ()), 0)))
