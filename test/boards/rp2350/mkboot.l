; test/boards/rp2350/mkboot.l -- lay boot.o for the Pico 2 (RP2350, Arm): the vector table at flash
; base with the image definition behind it, crt0, the fault shim and the helpers C cannot say.
; the rom wants a block in the first 4 KB naming an Arm secure executable; with no vector table
; item it takes the table at the image's start. the rest is ../nucleo446/mkboot.l's shape. runs
; after holo/{elf,obj}.l with the thumb2 backend spliced into holo
(: (mkboot dst)
   (: (zeros n) (n < 1 ? () (0 . zeros (n - 1)))
      (wsym l) [['fix 4 'abs32 l 0]]           ; a word the linker fills: (S + A) | T

      ;; -- the ARM vector table at flash base ----------------------------------------
      vecs (wsym '__stack_top__ + wsym 'cstartup
             + wsym 'default_handler                               ; NMI
             + wsym 'isr_hardfault + wsym 'isr_hardfault           ; HardFault, MemManage
             + wsym 'isr_hardfault + wsym 'isr_hardfault           ; BusFault, UsageFault
             + wsym 'isr_hardfault                                 ; SecureFault
             + zeros 12                                            ; 8..10 reserved
             + wsym 'default_handler + wsym 'default_handler       ; SVCall, DebugMon
             + le32 0                                              ; 13 reserved
             + wsym 'default_handler + wsym 'default_handler)      ; PendSV, SysTick

      ;; -- the image definition: start marker, image type (exe, secure, arm, rp2350), the
      ;; last item (one word of items before it), a link to itself, end marker
      block (le32 0xffffded3 + le32 0x10210142 + le32 0x000001ff + le32 0 + le32 0xab123579)

      ;; -- crt0 ----------------------------------------------------------------------
      startup [['label 'cstartup]
               ['la 'r0 '__stack_top__] ['mov 'sp 'r0]
               ['jmp 'cmain]]

      ;; -- the instructions C cannot say ----------------------------------------------
      ;; HardFault: the active stack's exception frame to hardfault_report, on a fresh stack
      text [['label 'isr_hardfault]
            ['li 'r1 4] ['test 'lr 'r1] ['br 'eq 'hf-msp]
            ['mrs 'r0 'psp] ['jmp 'hf-frame]
            ['label 'hf-msp] ['mrs 'r0 'msp]
            ['label 'hf-frame]
            ['la 'r1 '__stack_top__] ['mov 'sp 'r1]
            ['jmp 'hardfault_report]
            ['label 'default_handler] ['wfi] ['jmp 'default_handler]
            ['label 'arm_dsb_isb] ['dsb 'sy] ['isb] ['ret]
            ['label 'arm_wfi] ['wfi] ['ret]]

      ;; ALLOC for the table (2), ALLOC|EXEC for the code (6)
      (write-bytes dst
       (objsecs32 'thumb2sp
        [[".vectors" 1 2 4 [['label 'vectors] ['raw (vecs + block)]]]
         [".startup" 1 6 4 startup]
         [".text"    1 6 4 text]]
        '("cstartup" "isr_hardfault" "default_handler" "arm_dsb_isb" "arm_wfi")
        '("vectors") ()))))
