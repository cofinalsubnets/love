; test/boards/boardld.l -- a board's link over holo's ldbare32 (src/love/holo/link.l), cat after
; src/love/holo/{elf,obj,link}.l and ahead of the board's map, which calls
;
;   (boardld ISA SRAM-TOP FLASH-RUNS RAM-RUNS SYMS)
;
; and runs as `love <cat> [-ram] OUT OBJ.o.. [LIB.a..]`. -ram, or a board with no flash runs,
; links RAM-RUNS, else FLASH-RUNS. __stack_top__ is SRAM-TOP, then SYMS' [name address] pairs
(: (boardld isa top flash ram syms)
   ; presence out of band: an unreadable file and an empty one are the same value,
   ; and an empty .o here would link a firmware with a silent hole in it
   (: (bread p) (uread p @ r (two? r ? [p <>r] (scare 'boardld-open p)))
      (bar? p) (#p @ n (2 < n && snip p (n - 2) n = ".a"))
      (: av >argv
         onram (<av = "-ram")
         as (onram ? >av av)
         out <as ins >as
         objs (filter (p \ !(bar? p)) ins)
         ars (filter bar? ins)
         _ (two? objs ? 0 (scare 'boardld-no-objects out))
         set (map bread objs)
         lib (set + ldarch set (map bread ars) isa)
         runs (two? flash && !onram ? flash ram)
         (ld-write out (ldbare32 isa runs lib ([["__stack_top__" top]] + syms) ()), 0))))
