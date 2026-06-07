/* Linker script for the riscv64 EFI build.
 *
 * The Limine build (riscv64.lds) places the kernel in the upper 2 GiB at
 * 0xffffffff80000000, where Limine's protocol delivers it. UEFI loads the
 * image at a firmware-chosen physical address with the requested RVAs
 * (symbol values modulo ImageBase), so we lay sections out from a small
 * base address with image-relative symbol values: each value becomes its
 * own RVA, which tools/elf2efi.py uses directly when stamping out the
 * PE32+ file.
 *
 * We collect everything readable+executable into one R+X PT_LOAD and
 * everything writable into one R+W PT_LOAD; that maps cleanly onto a
 * pair of PE sections (.text, .data) plus a generated .reloc. The PE32+
 * SectionAlignment must be a multiple of 4 KiB on RISC-V, hence the
 * page-aligned section boundaries.
 *
 * .bss is laid out contiguously with .data but ld doesn't materialize
 * its zeroes in the output; elf2efi.py reads the section's sh_size,
 * sets the PE section's VirtualSize accordingly, and lets the UEFI
 * loader zero-fill the difference between SizeOfRawData and VirtualSize. */

OUTPUT_FORMAT(elf64-littleriscv)
ENTRY(efi_main)

PHDRS
{
    text PT_LOAD FLAGS(0x5);    /* R | X */
    data PT_LOAD FLAGS(0x6);    /* R | W */
}

SECTIONS
{
    /* Leave the first page free; tools/elf2efi.py builds the PE header
     * into that span when it lays the .efi file out. */
    . = 0x1000;

    .text : ALIGN(0x1000) {
        *(.text.head)
        *(.text .text.*)
        /* gwen data self-quote sentinels: kept contiguous and in enum
           order (gwen_data.NN) so g_typ() recovers a kind from an ap's
           slot index. Mirrors g/data.ld for the host link. */
        . = ALIGN(16);
        __start_gwen_data = .;
        KEEP(*(SORT_BY_NAME(gwen_data.*)))
        __stop_gwen_data = .;
    } :text

    .rodata : ALIGN(0x1000) {
        *(.rodata .rodata.*)
        *(.srodata .srodata.*)
        *(.sdata2 .sdata2.*)
    } :text

    . = ALIGN(0x1000);

    .data : ALIGN(0x1000) {
        *(.data .data.*)
        *(.sdata .sdata.*)
    } :data

    /* .bss is appended to the .data PT_LOAD: same R+W permissions, no
     * bytes in the file. ld emits a single VMA range that runs to the
     * end of .bss; elf2efi.py uses the .bss sh_size to set VirtualSize
     * larger than SizeOfRawData so the UEFI loader zeroes the tail. */
    .bss : {
        *(.bss .bss.*)
        *(.sbss .sbss.*)
        *(COMMON)
    } :data

    /* .note may carry NT_GNU_PROPERTY entries on riscv64 toolchains;
     * drop them along with anything else that doesn't belong in the
     * runtime image. We deliberately keep .rela.* sections (default
     * non-alloc) so --emit-relocs preserves them for elf2efi.py. */
    /DISCARD/ : {
        *(.eh_frame*)
        *(.note .note.*)
        *(.riscv.attributes)
        *(.comment)
    }
}
