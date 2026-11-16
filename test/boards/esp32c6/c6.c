// esp32-c6 from its rom loader: run from hp sram on the rom's stack, the console the
// USB-Serial-JTAG's endpoint 1 as src/tools/espstub.c drives it. no crt0: the loader
// laid every segment, .bss zeroed, and jumps to _start
#include <stdint.h>

#define R(a) (*(volatile uint32_t *)(uintptr_t)(a))
#define EP1 0x6000F000u   // the byte
#define EPC 0x6000F004u   // bit 0 send, bit 1 room

int main(void);

// a send asked while a full packet is still going out is lost: let it go first
static void sent(void) { for (uint32_t k = 0; k < 20000u; k++) (void)R(EPC); R(EPC) = 1; }

void serial_putc(int c) {
  while (!(R(EPC) & 2)) {}
  R(EP1) = (uint32_t)(c & 0xff);
  if (c == '\n') sent(); }

void _start(void) {
  main();
  for (;;) {} }
