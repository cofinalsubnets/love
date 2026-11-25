; test/boards/armboot.l -- boot.o for the thumb2 boards, laid from holo IR: the vector table,
; crt0, the fault shim and the helpers C cannot say. a board's mkboot.l calls
;
;   (armboot DST SECURE TAIL TEXT NAMES)
;
; SECURE puts the v8-M SecureFault at vector 7, TAIL is bytes laid behind the table, TEXT and
; NAMES more code and its exported names. vectors take addend 0, since obj.l sets the thumb bit
; on every FUNC symbol; sp arrives through a general register (MOVW/MOVT cannot name it). runs
; after holo/{elf,obj}.l with the thumb2 backend spliced into holo
(: (armboot dst secure tail more names)
   (: (zeros n) (n < 1 ? () (0 . zeros (n - 1)))
      (wsym l) [['fix 4 'abs32 l 0]]           ; a word the linker fills: (S + A) | T

      ;; the four faults go to the reporter, the rest idle; word 0 is the initial SP
      vecs (wsym '__stack_top__ + wsym 'cstartup
             + wsym 'default_handler                               ; NMI
             + wsym 'isr_hardfault + wsym 'isr_hardfault           ; HardFault, MemManage
             + wsym 'isr_hardfault + wsym 'isr_hardfault           ; BusFault, UsageFault
             + (? secure (wsym 'isr_hardfault + zeros 12) (zeros 16))  ; SecureFault or 7, then 8..10 reserved
             + wsym 'default_handler + wsym 'default_handler       ; SVCall, DebugMon
             + le32 0                                              ; 13 reserved
             + wsym 'default_handler + wsym 'default_handler)      ; PendSV, SysTick

      startup [['label 'cstartup]
               ['la 'r0 '__stack_top__] ['mov 'sp 'r0]
               ['jmp 'cmain]]

      ;; HardFault: the active stack's exception frame to hardfault_report. EXC_RETURN bit 2
      ;; says which SP (clear: MSP); TST takes no immediate, so the 4 rides r1, already stacked.
      ;; the reporter runs on a fresh stack: a stack overflow would double-fault into lockup
      text ([['label 'isr_hardfault]
             ['li 'r1 4] ['test 'lr 'r1] ['br 'eq 'hf-msp]
             ['mrs 'r0 'psp] ['jmp 'hf-frame]
             ['label 'hf-msp] ['mrs 'r0 'msp]
             ['label 'hf-frame]
             ['la 'r1 '__stack_top__] ['mov 'sp 'r1]
             ['jmp 'hardfault_report]
             ['label 'default_handler] ['wfi] ['jmp 'default_handler]
             ['label 'arm_dsb_isb] ['dsb 'sy] ['isb] ['ret]
             ['label 'arm_wfi] ['wfi] ['ret]
             ['label 'arm_irq_off] ['raw [0x72 0xB6]] ['ret]]          ; cpsid i
            + more)

      ;; ALLOC for the table (2), ALLOC|EXEC for the code (6)
      (write-bytes dst
       (objsecs32 'thumb2sp
        [[".vectors" 1 2 4 [['label 'vectors] ['raw (vecs + tail)]]]
         [".startup" 1 6 4 startup]
         [".text"    1 6 4 text]]
        ('("cstartup" "isr_hardfault" "default_handler" "arm_dsb_isb" "arm_wfi" "arm_irq_off") + names)
        '("vectors") ()))))
