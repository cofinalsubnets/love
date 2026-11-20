; test/boards/rp2350/rlink.l -- the Pico 2 (RP2350, Arm) link: holo's ldbare32 (src/love/holo/link.l)
; with the RP2350's flash map. cat it after src/love/holo/{elf,obj,link}.l and run
;
;   love <cat> [-ram] OUT OBJ.o..
;
; no boot2: the rom sets up flash itself and finds the image definition mkboot.l lays behind the
; vector table, both in .vectors at flash base. the stack tops the 520 KB SRAM; .data is stored in
; flash and runs in SRAM (the `copy` run). -ram lays it all in SRAM, for a uf2 the rom runs
; there: code from its base, .data copied up to 0x20040000
(: sram-top 0x20082000                      ; 0x20000000 + 520 KB
   (rread p) (uread p @ r (two? r ? [p <>r] (scare 'rlink-open p)))
   (rar? p) (#p @ n (2 < n && snip p (n - 2) n = ".a"))
   (: av >argv
      ram (<av = "-ram")
      as (ram ? >av av)
      out <as ins >as
      objs (filter (p \ !(rar? p)) ins)
      ars (filter rar? ins)
      _ (two? objs ? 0 (scare 'rlink-no-objects out))
      set (map rread objs)
      lib (set + ldarch set (map rread ars) 'thumb2sp)
      runs (ram ? [['at 0x20000000 (intern ".vectors") 'text 'rodata] ['copy 0x20040000 'data 'bss]]
                  [['at 0x10000000 (intern ".vectors") 'text 'rodata] ['copy 0x20000000 'data 'bss]])
      (ld-write out (ldbare32 'thumb2sp runs lib [["__stack_top__" sram-top]] ()), 0)))
