; src/inle/nrf52840/xlink.l -- the xiao nrf52840 link: holo's ldbare32 (src/love/holo/link.l),
; nucleo446's nlink.l with this board's map. cat it after src/love/holo/{elf,obj,link}.l and run
;
;   love <cat> OUT OBJ.o..
;
; the uf2 bootloader starts the app at 0x27000, above the mbr and softdevice, and reads its
; vector table there, so .vectors is named first. RAM is the 256 KB at 0x20000000, the stack
; at its top; .data is stored in flash and runs in RAM (the `copy` run)
(: sram-top 0x20040000                      ; 0x20000000 + 256 KB
   (xread p) (uread p @ r (two? r ? [p <>r] (scare 'xlink-open p)))
   (xar? p) (#p @ n (2 < n && snip p (n - 2) n = ".a"))
   (: as >argv
      out <as ins >as
      objs (filter (p \ !(xar? p)) ins)
      ars (filter xar? ins)
      _ (two? objs ? 0 (scare 'xlink-no-objects out))
      ; the soft-double set from gcc's cortex-m4 hard-float libgcc, pulled by need
      set (map xread objs)
      lib (set + ldarch set (map xread ars) 'thumb2sp)
      runs [['at 0x00027000 (intern ".vectors") 'text 'rodata]
            ['copy 0x20000000 'data 'bss]]
      (ld-write out (ldbare32 'thumb2sp runs lib [["__stack_top__" sram-top]] ()), 0)))
