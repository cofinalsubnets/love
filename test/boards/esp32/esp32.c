// the esp32 classic and the s3 from their rom loaders: code in iram, data in dram, on the rom's
// stack. the console the classic's uart0, its board's usb bridge, or the s3's USB-Serial-JTAG,
// as src/tools/espstub.c drives them. no crt0: the rom laid every segment, .bss as zeros, and
// enters _start, and its download arms no watchdog
#include <stdint.h>

#define R(a) (*(volatile uint32_t *)(uintptr_t)(a))

int main(void);

#ifdef ESP32S3
#define EP1 0x60038000u   // the byte
#define EPC 0x60038004u   // bit 0 send, bit 1 room

// a send asked while a full packet is still going out is lost: let it go first
static void sent(void) { for (uint32_t k = 0; k < 20000u; k++) (void)R(EPC); R(EPC) = 1; }

// a byte that finds no room for a while is dropped, so a program that outlives its reader keeps its pace
void serial_putc(int c) {
  for (uint32_t k = 0; !(R(EPC) & 2); k++)
    if (k > 200000u) return;
  R(EP1) = (uint32_t)(c & 0xff);
  if (c == '\n') sent(); }
#else
#define UFIFO 0x3FF40000u
#define USTAT 0x3FF4001Cu   // the tx fifo's fill in bits 16..23, of 128

void serial_putc(int c) {
  while ((R(USTAT) >> 16 & 0xffu) >= 120u) {}
  R(UFIFO) = (uint32_t)(c & 0xff); }
#endif

void _start(void) {
  main();
  for (;;) {} }
