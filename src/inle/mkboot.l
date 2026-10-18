; src/inle/mkboot.l -- lay boot.o, the register-exact bring-up before there is a C environment.
;   (lay-boot dst "x64")   the PVH note, the page tables + GDT, the long-mode ladder, khop
;   (lay-boot dst "a64")   the translation tables, MAIR/TCR/TTBR, the MMU switch, the hop, khop
;   (lay-boot dst "rv64")  the one sv39 root, satp, sstatus.FS, khop
; the link is flat (vaddr = paddr), so `la` answers a label; x64's image lies in the upper half.
; `lia` stays where an absolute is wanted: the first fetch after the MMU comes on (a pc-relative
; branch would ride a broken map), its stack, and x64's reach up to the image.
; runs after holo/{elf,obj}.l in a (borrow 'holo) cat with the target's backend joined.
; registers: x86 r0=rax r1=rcx r2=rdx r3=rbx r5=rsi r6=rdi; a64 rN = xN.
(:
   (b-rep n x) (n >= 1 ? (x . b-rep (n - 1) x))
   (b-zeros n) (b-rep n 0)

   (b-abs32 lbl ad) [['fix 4 'abs32 lbl ad]]     ; a 4-byte physical address
   (b-abs64 lbl ad) [['fix 8 'abs64 lbl ad]]     ; ..and its 8-byte twin
   (b-quad v) ['raw (le64 v)]

   ;; -- x86-32 helpers: the PVH stub's first instructions run in 32-bit protected mode,
   ;; where holo's x64 encodings mean other things. each checked against llvm-mc -triple=i386.
   ;; an %edi memory operand always takes disp32 (mod=10): one shape.
   i-cli            '(250)                                   ; fa           cli
   i-xor-ecx        '(49 201)                                ; 31 c9        xor %ecx, %ecx
   i-eax-ecx        '(137 200)                               ; 89 c8        mov %ecx, %eax
   i-st-edi0        '(137 7)                                 ; 89 07        mov %eax, (%edi)
   i-st-edi-idx8    '(137 4 207)                             ; 89 04 cf     mov %eax, (%edi,%ecx,8)
   i-inc-ecx        '(65)                                    ; 41           inc %ecx
   i-rdmsr          '(15 50)                                 ; 0f 32        rdmsr
   i-wrmsr          '(15 48)                                 ; 0f 30        wrmsr
   (i-edi-sym l a)  (191 . b-abs32 l a)                     ; bf id        mov $sym, %edi
   (i-eax-sym l a)  (184 . b-abs32 l a)                     ; b8 id        mov $sym, %eax
   (i-ecx-imm v)    (185 . le32 v)                          ; b9 id        mov $imm, %ecx
   (i-shl-eax n)    [193 224 n]                              ; c1 e0 ib     shl $n, %eax
   (i-or-eax v)     (13 . le32 v)                           ; 0d id        or $imm32, %eax
   (i-or-eax8 v)    [131 200 v]                              ; 83 c8 ib     or $imm8, %eax
   (i-add-eax v)    (5 . le32 v)                            ; 05 id        add $imm32, %eax
   (i-cmp-ecx v)    ([129 249] + le32 v)                     ; 81 f9 id     cmp $imm32, %ecx
   (i-jne lbl)      [15 133 ['fix 4 'rel32 lbl 0]]           ; 0f 85 cd     jne rel32
   (i-st-edi d)     ([137 135] + le32 d)                     ; 89 87 disp32 mov %eax, d(%edi)
   (i-sti-edi d l a) ([199 135] + le32 d + b-abs32 l a)         ; c7 87 disp32 id  movl $sym, d(%edi)
   (i-stimm-edi d v) ([199 135] + le32 d + le32 v)              ; c7 87 disp32 id  movl $imm, d(%edi)
   (i-lgdt l a)     ([15 1 21] + b-abs32 l a)                ; 0f 01 15 id  lgdt sym
   (i-ldcr n)       [15 32 (192 | n << 3)]                   ; 0f 20 /r     mov %crN, %eax
   (i-stcr n)       [15 34 (192 | n << 3)]                   ; 0f 22 /r     mov %eax, %crN
   (i-ljmp l a)     ((234 . b-abs32 l a) + '(8 0))          ; ea off32 sel16  ljmp $0x08, $sym
   (i32 bs) ['raw bs]                                        ; one 32-bit instruction, one form

   ;; -- x64 ------------------------------------------------------------
   ;; the PVH note `qemu -kernel` reads to find the 32-bit entry; link.l keeps it like progbits.
   x-note
    ([['raw (le32 4 + le32 4 + le32 18)]]            ; namesz 4, descsz 4, XEN_ELFNOTE_PHYS32_ENTRY
     + [['raw '(88 101 110 0)]]                      ; "Xen\0"
     + [['raw (b-abs32 'pvh32 0)]])                  ; the PHYSICAL address of the 32-bit entry

   ;; the page tables, file bytes (not .bss): one PML4, one PDPT shared by the identity and
   ;; hhdm windows, four PDs of 2 MiB entries over phys 0..4 GiB. RAM above 4 GiB is unmapped.
   x-boot
    ('((label pml4)) + [['raw (b-zeros 4096)]]
     + '((label pdpt_id)) + [['raw (b-zeros 4096)]]
     + '((label pd0)) + [['raw (b-zeros 16384)]]
     ;; the GDT: null, 64-bit code at 0x08, data at 0x10.
     + [['align 8] ['label 'gdt]]
     + [(b-quad 0) (b-quad 0x00209A0000000000) (b-quad 0x0000920000000000)]
     + [['label 'gdt_end] ['align 8] ['label 'gdtreg]]
     + [['raw (le16 23)]]                            ; gdt_end - gdt - 1
     ;; lgdt runs before paging: the base must be physical
     + [['raw (b-abs64 'gdt 0)]])

   ;; the ladder. 32-bit protected mode, paging off, ebx -> hvm_start_info.
   x-boot-text
    ([['label 'pvh32] (i32 i-cli)]
     ;; the four PDs: entry i = (i << 21) | P|RW|PS; high dwords stay zero.
     + [(i32 (i-edi-sym 'pd0 0)) (i32 i-xor-ecx) ['label 'pd_loop]
        (i32 i-eax-ecx) (i32 (i-shl-eax 21)) (i32 (i-or-eax 0x83))
        (i32 i-st-edi-idx8) (i32 i-inc-ecx) (i32 (i-cmp-ecx 0x800))
        (i32 (i-jne 'pd_loop))]
     ;; identity + hhdm PDPT: entries 0..3 -> the four PDs
     + [(i32 (i-edi-sym 'pdpt_id 0)) (i32 (i-eax-sym 'pd0 3))
        (i32 i-st-edi0)
        (i32 (i-add-eax 0x1000)) (i32 (i-st-edi 8))
        (i32 (i-add-eax 0x1000)) (i32 (i-st-edi 16))
        (i32 (i-add-eax 0x1000)) (i32 (i-st-edi 24))]
     ;; PML4: [0] identity, [256] the hhdm (NX), [511] the image window -- one PDPT thrice.
     ;; NX at the top of the hhdm covers every page the heap hands out; the image window keeps X.
     + [(i32 (i-edi-sym 'pml4 0)) (i32 (i-eax-sym 'pdpt_id 3))
        (i32 i-st-edi0) (i32 (i-st-edi (256 * 8))) (i32 (i-st-edi (511 * 8)))
        (i32 (i-stimm-edi (256 * 8 + 4) 0x80000000))]
     ;; the long-mode ladder: GDT, CR4.PAE, CR3, EFER.LME, CR0.PG|PE, far jump
     + [(i32 (i-lgdt 'gdtreg 0))
        (i32 (i-ldcr 4)) (i32 (i-or-eax8 0x20)) (i32 (i-stcr 4))      ; CR4.PAE
        (i32 (i-eax-sym 'pml4 0)) (i32 (i-stcr 3))
        (i32 (i-ecx-imm 0xC0000080)) (i32 i-rdmsr)                  ; EFER
        (i32 (i-or-eax 0x900)) (i32 i-wrmsr)                          ; LME | NXE
         ; NXE before PG: else bit 63 of an entry is reserved and the first walk faults.
        (i32 (i-ldcr 0)) (i32 (i-or-eax 0x80000001)) (i32 (i-stcr 0))]    ; PG | PE
     + [(i32 (i-ljmp 'pvh64 0))]
     ;; 64-bit: the data selectors, then an absolute hop (the first fetch after paging).
     + [['label 'pvh64]]
     + [['raw '(102 184 16 0)]                       ; 66 b8 10 00  mov $0x10, %ax
        ['raw '(142 216)]                            ; 8e d8        mov %ax, %ds
        ['raw '(142 192)]                            ; 8e c0        mov %ax, %es
        ['raw '(142 208)]]                           ; 8e d0        mov %ax, %ss
     + '((lia r0 khop) (jmpr r0)))

   ;; past the hop: a stack, SSE on before any C runs (pvh_to_kboot may vectorize), then C,
   ;; by absolute calls through the image window.
   x-text
    '((label khop)
       (lia sp kstack_top)
       (li r0 0xffffff8000000000)
       (add sp sp r0)
       (ldcr r0 0)
       (and r0 r0 -5)                                ; ~(1 << 2): CR0.EM = 0
       (or r0 r0 2)                                  ; CR0.MP = 1
       (stcr 0 r0)
       (ldcr r0 4)
       (or r0 r0 0x600)                               ; CR4.OSFXSR | OSXMMEXCPT
       (stcr 4 r0)
       ;; hvm_start_info -> arg0; zx4: the loader set only the 32-bit half.
       (mov r6 r3) (zx4 r6)
       (lia r0 pvh_to_kboot)
       (callr r0)
       (lia r0 kmain)
       (callr r0)
       (label x_park)
       (cli) (hlt) (jmp x_park))

   ;; -- a64 -----------------------------------------------------------
   ;; one L1 named twice: identity under TTBR0 and hhdm at L0[256] under TTBR1. the first gig
   ;; is a real L2 of 2 MiB Device blocks (mmio_map walks TTBR1 expecting a table there);
   ;; RAM (1..4 GiB) rides 1 GiB Normal blocks.
   a-boot
    ('((label l0_lo)) + [['raw (b-zeros 4096)]]      ; TTBR0: [0] -> l1_id
     + '((label l0_hi)) + [['raw (b-zeros 4096)]]    ; TTBR1: [256] hhdm -> l1_id
     + '((label l1_id)) + [['raw (b-zeros 4096)]]    ; [0] -> l2_dev, [1..3] 1G Normal blocks
     + '((label l2_dev)) + [['raw (b-zeros 4096)]])     ; 512 x 2M Device blocks over phys 0..1G

   a-gig 0x40000705                                 ; 0x40000000 | 0x705  valid | AttrIndx 1 | SH inner | AF
   ;; PXNTable | UXNTable (bits 59, 60 of a table descriptor): x86's NX, one level up.
   a-xntab 0x1800000000000000
   a-boot-text
    ('((label a64boot)
       ;; firmware enters with the MMU on, `qemu -kernel` with it off: read SCTLR.M.
       ;; no test-bit-branch or immediate AND in the neutral surface; x9/x10 are dead here.
       (mrs r9 sctlr_el1)
       (li r10 1) (and r10 r9 r10) (cmp r10 0)
       (br eq a64_cold)
       (jmp kmain)                                   ; already mapped: straight into C
       (label a64_cold)
       (mov r21 r0)                                  ; x0: a loader's dtb pointer, honored at khop
       (li r6 3)                                     ; valid | table; a literal, the block is quoted
       ;; l2_dev: 512 x 2 MiB Device blocks. `la` is pc-relative and we run low, so every
       ;; address written into a table is physical.
       (la r0 l2_dev)
       (li r1 0)
       (li r2 0x401)
       (label a64_dev)
       (mov r3 r1) (shl r3 21) (or r3 r3 r2)
       (stx r0 r1 8 0 r3)                            ; str x3, [x0, x1, lsl #3]
       (add r1 r1 1) (cmp r1 512) (br ne a64_dev)
       ;; l1_id: [0] table -> l2_dev, [1..3] 1 GiB Normal blocks
       (la r1 l1_id)
       (or r3 r0 r6) (st r1 0 r3))
     + [['li 'r2 a-gig] ['st 'r1 8 'r2]
        ['li 'r2 (a-gig + 0x40000000)] ['st 'r1 16 'r2]
        ['li 'r2 (a-gig + 0x80000000)] ['st 'r1 24 'r2]]
     ;; the L0s: the same L1 under both. the XN pair rides the hhdm alone, so pages reached
     ;; through it can't execute while identity keeps X for the image.
     + ['(or r3 r1 r6)
        '(la r0 l0_lo) '(st r0 0 r3)
        '(la r2 l0_hi)
        ['li 'r5 a-xntab] '(or r5 r5 r3) '(st r2 2048 r5)]     ; [256]: nothing under it runs
     + '(;; MAIR: attr0 Device-nGnRnE (what mmio_attr_index prefers), attr1 Normal WB
         (li r3 0xff00)
         (msr mair_el1 r3)
         ;; TCR: 48-bit VA both halves, 4K granules, WB WA inner-shareable walks,
         ;; 40-bit PA -- T0SZ=16 IRGN0/ORGN0=1 SH0=3 | T1SZ=16 IRGN1/ORGN1=1 SH1=3
         ;; TG1=4K | IPS=40-bit
         (li r3 0x2B5103510)
         (msr tcr_el1 r3)
         (msr ttbr0_el1 r0)
         (msr ttbr1_el1 r2)
         ;; FP/SIMD on before any C runs (dtb.c may vectorize)
         (mrs r3 cpacr_el1)
         (li r4 0x300000) (or r3 r3 r4)        ; 3 << 20
         (msr cpacr_el1 r3)
         (dsb ish)
         (tlbi vmalle1 zr)
         (dsb ish)
         (isb)
         (mrs r3 sctlr_el1)
         (li r4 0x1005) (or r3 r3 r4)          ; M | C | I = 1<<0 | 1<<2 | 1<<12
         (msr sctlr_el1 r3)
         (isb)
         ;; an absolute hop although the link is flat: a pc-relative branch would hide a broken
         ;; identity map. the align is lia's: the literal sits at the site + 8.
         (align 8)
         (lia r9 khop)
         (jmpr r9)))

   a-text
    '((label khop)
       (la r9 kstack_top)                            ; flat: pc-relative IS the linked address
       (lea sp r9 0)                                 ; mov sp, x9
       ;; qemu lays the dtb at the RAM base; a loader that passed one in x0 wins.
       (li r1 0x40000000)                             ; RAMB, virt's RAM base
       (cmp r21 0)
       (br ne a64_havedtb)
       (mov r21 r1)
       (label a64_havedtb)
       (mov r0 r21)
       (call dtb_to_kboot)
       (call kmain)
       (label a64_park)
       (wfi)
       (jmp a64_park))

   ;; -- rv64 ------------------------------------------------------------
   ;; sv39, one table: [0..3] identity gigs, [256..259] the hhdm at 0xffffffc0_00000000.
   ;; no second level: MMIO is under the first gig and a base PTE carries no memory type.
   r-boot ('((label rv_root)) + [['raw (b-zeros 4096)]])

   ;; a leaf PTE for gig i: PPN (i << 30 >> 12) at bit 10 is i << 28. V|R|W|G|A|D, X on the
   ;; identity window alone (the hhdm is non-executable, as on x86 and a64).
   (r-pte i x) (i << 28 | (x ? 0xEF 0xE7))
   r-boot-text
    ('((label rvboot)
       ;; SBI: a0 = hart id, a1 = the device tree, kept in s2.
       (mov r13 r1)
       (la r0 rv_root))
     + (foldl (\ a i (a + [['li 'r2 (r-pte i 1)] ['st 'r0 (i * 8) 'r2]
                           ['li 'r2 (r-pte i 0)] ['st 'r0 (2048 + i * 8) 'r2]]))
              () ^4)
     + '(;; satp: sv39 over the root's PPN. the pc is in the identity window, so the next
         ;; fetch tests the map; there is no literal hop.
         (shr r0 12)
         (li r2 0x8000000000000000)
         (or r0 r0 r2)
         (csrw satp r0)
         (sfence zr zr)
         ;; FP on before any C runs (sstatus.FS is Off at reset; don't depend on the firmware).
         ;; 3 << 13 is Dirty.
         (li r8 0x6000)
         (csrs sstatus r8)
         (jmp khop)))

   r-text
    '((label khop)
       (la sp kstack_top)                            ; flat: pc-relative IS the linked address
       (mov r0 r13)                                ; the tree SBI passed, straight to the door
       (call dtb_to_kboot)
       (call kmain)
       (label rv_park)
       (wfi)
       (jmp rv_park))

   ;; the boot stack, 1 MiB; kmain never returns. the boot page tables lie below it and an
   ;; overflow eats them in silence (no guard page yet). .bss, free in the file.
   b-stack [['label 'kstack] ['raw (b-zeros 1048576)] ['label 'kstack_top]]

   ;; -- the two objects ---------------------------------------------------
   ;; SHF: 2 ALLOC, 3 ALLOC|WRITE, 6 ALLOC|EXEC. types: 1 PROGBITS, 7 NOTE, 8 NOBITS.
   ;; .boot stays PROGBITS: the loader hands the whole span over.
   (lay-boot dst arch) (write-bytes dst (lay-boot-bytes arch))
   (lay-boot-bytes arch)
    (arch @ "x64"
       (objsecs 'x64
                [[".note.pvh"  7 2 4    x-note]
                 [".boot"      1 3 4096 x-boot]
                 [".boot.text" 1 6 16   x-boot-text]
                 [".text"      1 6 16   x-text]
                 [".bss"       8 3 16   b-stack]]
                ()                       ; the ELF entry is kmain's; the PVH entry rides the note
                () ()
                '("pvh32" "pvh64" "khop"))
       "a64"
       (objsecs 'a64
                [[".boot"      1 3 4096 a-boot]
                 [".boot.text" 1 6 16   a-boot-text]
                 [".text"      1 6 16   a-text]
                 [".bss"       8 3 16   b-stack]]
                '("a64boot")             ; kproject.l names it as the ELF entry
                () ()
                '("khop"))
       "rv64"
       ;; the stub before the tables: this door is entered at the load address, not a symbol,
       ;; so the first laid byte has to be rvboot.
       (objsecs 'rv64
                [[".boot.text" 1 6 16   r-boot-text]
                 [".boot"      1 3 4096 r-boot]
                 [".text"      1 6 16   r-text]
                 [".bss"       8 3 16   b-stack]]
                '("rvboot")              ; kproject.l names it as the ELF entry
                () ()
                '("khop"))
       (scare 'mkboot-arch arch)))
