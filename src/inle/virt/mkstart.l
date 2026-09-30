; src/inle/virt/mkstart.l -- lay start.o for the qemu-virt (rv64) port, in holo IR. the mask ROM
; jumps to the DRAM base with sp garbage, the FPU off and mtvec nowhere; the driver's crt0 there
; calls __ai_start, which this object overrides strong (moonlibc's weak seam) to pin sp, open the
; FPU, and aim mtvec at a fault tail that hands mcause/mepc to main.c's fault_report. the CSR
; instructions ride 'raw, since holo carries no Zicsr rows.
; runs after src/love/holo/{elf,obj}.l in a cat with the riscv backend spliced into the sealed
; holo module (src/inle/virt/Makefile).
(: ;; csr rd rs1: the Zicsr I-form (opcode 0x73) -- f3 2 = csrrs, 1 = csrrw
   (csrw f3 rd rs1 csr) (csr << 20 | (rs1 << 15 | (f3 << 12 | (rd << 7 | 0x73))))
   (mkstart dst)
    (: fsen (le32 (csrw 2 0 5 768))     ; csrrs x0, mstatus, t0 -- FS on (0x300)
       mtv  (le32 (csrw 1 0 5 773))     ; csrrw x0, mtvec, t0   -- direct mode (0x305)
       mcz  (le32 (csrw 2 10 0 834))    ; csrrs a0, mcause, x0  (0x342)
       mez  (le32 (csrw 2 11 0 833))    ; csrrs a1, mepc, x0    (0x341)
       ir [['label '__ai_start]
           ['li 'sp 2181038080]         ; 0x82000000 -- tops out under the pool
           ['li 'r8 24576]              ; t0 = 0x6000: mstatus.FS = Dirty
           ['raw fsen]                  ; the FPU opens before any fld/fsd
           ['la 'r8 '__ai_trap]
           ['raw mtv]
           ['call 'main]
           ['label 'spin] ['jmp 'spin]
            ;; the machine-trap tail: a fresh stack (the faulting one may be
            ;; the fault), cause and pc into the argument file, then C.
           ['label '__ai_trap]
           ['li 'sp 2181038080]
           ['raw mcz]
           ['raw mez]
           ['call 'fault_report]
           ['label 'spin2] ['jmp 'spin2]]
       (write-bytes dst (objelf 'rv64 ir () '("__ai_start") () () () () () () ()))))
