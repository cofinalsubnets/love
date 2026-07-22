/* mps2-an500: 4 MB ZBT SSRAM1 at 0 (code, the M7 boots from its vectors),
 * 4 MB SSRAM2/3 at 0x20000000 (data + bss + the C stack at its top). The
 * 16 MB PSRAM at 0x60000000 is the love arena -- reached by address from
 * main.c, no section here. qemu -kernel loads every segment directly. */
MEMORY
{
  CODE (rx)  : ORIGIN = 0x00000000, LENGTH = 4M
  DATA (rwx) : ORIGIN = 0x20000000, LENGTH = 4M
}
SECTIONS
{
  .text : { KEEP(*(.vectors)) *(.text*) *(.rodata*) } > CODE
  .data : { *(.data*) } > DATA
  .bss  : { *(.bss*) *(COMMON) } > DATA
  __stack_top__ = ORIGIN(DATA) + LENGTH(DATA);
}
