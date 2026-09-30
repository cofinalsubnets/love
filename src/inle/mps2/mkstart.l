; src/inle/mps2/mkstart.l -- lay start.o for the mps2-an500 board in holo IR: the vector table,
; the FPU gate and the semihosting trampoline. the M7 boots from the vectors at 0 (SP, reset, then
; NMI..SysTick), so the table leads this object's .text and this object leads the link.
; code sits in SSRAM1 at 0, .data/.bss in SSRAM2/3 at 0x20000000; .data is stored after the code,
; so _start copies it across and zeroes .bss off ldbare32's brackets, in byte loops since a
; section's size need not be a multiple of four. vectors take addend 0: obj.l sets the thumb bit on
; every FUNC symbol. CPACR must open CP10/CP11 before any VFP instruction or the core locks up, so
; it is the first thing _start does and the barriers after it are load-bearing.
; runs after src/love/holo/{elf,obj}.l in a cat with the thumb2 backend spliced into the sealed
; holo module (src/inle/mps2/Makefile).
(: (mkstart dst)
   (: cpacr 0xE000ED88  cp1011 0xF00000
      ;; the top of SSRAM2/3 (0x20000000 + 4M) -- the C stack grows down from there.
      ;; a board fact, so the board's own lay says it; the link has no memory map.
      stack-top 0x20400000
      ;; the table: SP, reset, then 14 fault vectors that all land in _fault, which exits 98.
      ;; a relocated word is a `fix` item riding the `raw` escape, the one door that takes
      ;; bytes and fixups mixed.
      (w32 l) [['fix 4 'abs32 l 0]]
      txt [['raw (le32 stack-top + w32 '_start
                  + foldl (\ a _ (a + w32 '_fault)) () ^14)]
           ['label '_start]
           ['li 'r0 cpacr] ['ld4 'r1 'r0 0]
           ['li 'r2 cp1011] ['or 'r1 'r1 'r2] ['st4 'r0 0 'r1]
           ['dsb 'sy] ['isb]
           ['la 'r0 '__data_load__] ['la 'r1 '__data_start__] ['la 'r2 '__data_end__]
           ['label 'dcopy] ['cmp 'r1 'r2] ['br 'ae 'dzero]
           ['ldu1 'r3 'r0 0] ['st1 'r1 0 'r3]
           ['add 'r0 'r0 1] ['add 'r1 'r1 1] ['jmp 'dcopy]
           ['label 'dzero] ['la 'r0 '__bss_start__] ['la 'r1 '__bss_end__] ['li 'r2 0]
           ['label 'bloop] ['cmp 'r0 'r1] ['br 'ae 'bdone]
           ['st1 'r0 0 'r2] ['add 'r0 'r0 1] ['jmp 'bloop]
           ['label 'bdone]
           ['call 'main]
           ['label 'spin] ['jmp 'spin]             ; main never returns (m7_exit leaves through qemu)
            ;; uintptr_t sh_call(uintptr_t op, uintptr_t arg) -- AAPCS already placed
            ;; op/arg in r0/r1, and the trap answers in r0.
           ['label 'sh_call] ['brk 171] ['ret]
            ;; the fault tail: hand the stacked frame to C, which prints pc/lr and exits 98
           ['label '_fault] ['mov 'r0 'sp] ['call 'fault_report]
           ['label 'spin2] ['jmp 'spin2]]
      (write-bytes dst (objsecs32 'thumb2 [[".text" 1 6 4 txt]]
                                  '("_start" "sh_call") () ()))))
