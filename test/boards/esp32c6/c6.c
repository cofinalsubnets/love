// esp32-c6 from its rom loader: run from hp sram on the rom's stack, the console the
// USB-Serial-JTAG's endpoint 1 as src/tools/espstub.c drives it. no crt0: the loader
// laid every segment, .bss zeroed, and jumps to _start
#include <stdint.h>

#define R(a) (*(volatile uint32_t *)(uintptr_t)(a))
#define EP1 0x6000F000u   // the byte
#define EPC 0x6000F004u   // bit 0 send, bit 1 room, bit 2 a host byte waiting

int main(void);

// a send asked while a full packet is still going out is lost: let it go first
static void sent(void) { for (uint32_t k = 0; k < 20000u; k++) (void)R(EPC); R(EPC) = 1; }

// with no reader the endpoint stays full: a byte that finds no room after a bounded wait is
// dropped, so a program that outlives its reader keeps running
void serial_putc(int c) {
  uint32_t k = 0;
  while (!(R(EPC) & 2))
    if (++k == 400000u) return;
  R(EP1) = (uint32_t)(c & 0xff);
  if (c == '\n') sent(); }

// a host byte, or -1: one left unread holds the host's writes, and its next open waits on them
int serial_rx(void) { return R(EPC) & 4 ? (int)(R(EP1) & 0xff) : -1; }

void _start(void) {
  main();
  for (;;) {} }
