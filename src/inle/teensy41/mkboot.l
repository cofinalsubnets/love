; src/inle/teensy41/mkboot.l -- lay boot.o for the Teensy 4.1 (i.MX RT1062): the four ROM-facing
; blocks and the instructions C cannot say. the ROM reads the FlexSPI config block at 0x000, the
; image vector table at 0x1000 and the boot data after it, so tlink.l's map places each section.
; vectors take addend 0: obj.l sets the thumb bit on every FUNC symbol. sp arrives through r0.
; runs after src/love/holo/{elf,obj}.l with the thumb2 backend spliced into holo.
(: (mkboot dst)
   (: (zeros n) (n < 1 ? () (0 . zeros (n - 1)))
      (wsym l) [['fix 4 'abs32 l 0]]           ; a word the linker fills: (S + A) | T

      ;; -- 1. the FlexSPI configuration block at flash 0x000 (RT1060 RM 9.6.3.1) ------
      ;; 512 bytes, mostly zero: the rows carry the RM's offsets and the gaps are computed
      fcfb-size 512
      fcfb-words '((0x00 0x42464346)    ; "FCFB" tag
                   (0x04 0x56010000)    ; version V1.0
                   (0x0C 0x00020101)    ; readSampleClkSrc=1, csHold=1, csSetup=2
                   (0x44 0x00030401)    ; deviceType=1 (NOR), pads=4 (quad), 60 MHz
                   (0x50 0x00800000)    ; sflashA1Size = 8 MB (Teensy 4.1)
                   (0x80 0x0A1804EB)    ; LUT[0]: CMD 0xEB (1 pad), RADDR 24 (4 pads)
                   (0x84 0x26043206))   ; LUT[1]: DUMMY 6 cycles, READ (4 pads)
      (fcfb-lay ws pos)
         (two? ws
          ? (: w <ws  o <w
               _ (o < pos ? (scare 'fcfb-overlap o) 0)
               (zeros (o - pos) + le32 <>w + fcfb-lay >ws (o + 4)))
            (zeros (fcfb-size - pos)))

      ;; -- 2. the image vector table at flash 0x1000, and the boot data after it ------
      ;; the ROM validates the header and jumps to entry. boot_data.length, the image's
      ;; extent in flash, is __load_size__, which the link pins
      ivt (le32 0x432000D1                     ; tag 0xD1, len 0x0020, ver 0x43
            + wsym 'cstartup                   ; entry
            + le32 0 + le32 0                  ; rsv1, dcd
            + wsym 'boot_data + wsym 'image_vector_table
            + le32 0 + le32 0)                 ; csf, rsv2
      bdata (le32 0x60000000 + wsym '__load_size__ + le32 0)

      ;; -- 3. the ARM vector table (VTOR, once we run; word 0's SP is advisory).
      ;; DebugMon is isr_hardfault too: with DEMCR.MON_EN a bkpt arrives there and reports.
      vecs (wsym '__stack_top__ + wsym 'cstartup
             + wsym 'default_handler + wsym 'isr_hardfault         ; NMI, HardFault
             + wsym 'default_handler + wsym 'default_handler       ; MemManage, BusFault
             + wsym 'default_handler                               ; UsageFault
             + zeros 16                                            ; 7..10 reserved
             + wsym 'default_handler                               ; SVCall
             + wsym 'isr_hardfault                                 ; DebugMon
             + le32 0                                              ; 13 reserved
             + wsym 'default_handler + wsym 'default_handler)      ; PendSV, SysTick

      ;; -- 4. crt0: the ROM jumps here with a ROM-provided SP ------------------------
      startup [['label 'cstartup]
               ['la 'r0 '__stack_top__] ['mov 'sp 'r0]
               ['jmp 'cmain]]

      ;; -- 5. the instructions C cannot say ------------------------------------------
      ;; HardFault: the active stack's exception frame to hardfault_report. EXC_RETURN bit
      ;; 2 says which SP (clear: MSP); the 4 rides r1, already stacked. the reporter runs on
      ;; a fresh stack, so a stack overflow still reports
      text [['label 'isr_hardfault]
            ['li 'r1 4] ['test 'lr 'r1] ['br 'eq 'hf-msp]
            ['mrs 'r0 'psp] ['jmp 'hf-frame]
            ['label 'hf-msp] ['mrs 'r0 'msp]
            ['label 'hf-frame]
            ['la 'r1 '__stack_top__] ['mov 'sp 'r1]
            ['jmp 'hardfault_report]
            ['label 'default_handler] ['wfi] ['jmp 'default_handler]
             ;; the helpers teensy41.c calls in place of inline asm
            ['label 'arm_dsb_isb] ['dsb 'sy] ['isb] ['ret]
            ['label 'arm_dsb] ['dsb 'sy] ['ret]
            ['label 'arm_wfi] ['wfi] ['ret]
            ['label 'arm_bkpt] ['brk 0] ['ret]]

      ;; ALLOC (2) for the data blocks, ALLOC|EXEC (6) for code; PROGBITS throughout
      (write-bytes dst
       (objsecs32 'thumb2
        [[".flashconfig" 1 2 4 [['raw (fcfb-lay fcfb-words 0)]]]
         [".ivt"         1 2 4 [['label 'image_vector_table] ['raw ivt]]]
         [".bootdata"    1 2 4 [['label 'boot_data] ['raw bdata]]]
         [".vectors"     1 2 4 [['label 'vectors] ['raw vecs]]]
         [".startup"     1 6 4 startup]
         [".text"        1 6 4 text]]
        '("cstartup" "isr_hardfault" "default_handler"
          "arm_dsb_isb" "arm_dsb" "arm_wfi" "arm_bkpt")
        '("image_vector_table" "boot_data" "vectors") ()))))
