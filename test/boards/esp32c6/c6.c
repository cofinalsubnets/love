// esp32-c6 from its rom loader, or its rom's boot from flash (esprom's image): run from hp sram
// on the rom's stack, the console the USB-Serial-JTAG's endpoint 1 as src/tools/espstub.c
// drives it. no crt0: the rom laid every segment, .bss as zeros, and jumps to _start
#include <stdint.h>

#define R(a) (*(volatile uint32_t *)(uintptr_t)(a))
#define EP1 0x6000F000u   // the byte
#define EPC 0x6000F004u   // bit 0 send, bit 1 room, bit 2 a host byte waiting

int main(void);

// a send asked while a full packet is still going out is lost: let it go first
static void sent(void) { for (uint32_t k = 0; k < 20000u; k++) (void)R(EPC); R(EPC) = 1; }

// systimer unit 0, 16 mhz off the crystal: a value latched, then read
#define SYSTIM 0x6000A000u
uint32_t ticks(void) {
  R(SYSTIM + 0x04u) = 1u << 30;
  while (!(R(SYSTIM + 0x04u) & 1u << 29)) {}
  return R(SYSTIM + 0x44u); }

// with no reader the endpoint stays full: a byte that finds no room in 2 ms, two of the host's
// frames, is dropped, so a program that outlives its reader keeps its pace. a byte before any
// host has opened the port, its line coding still 0, is dropped at once: one written before
// the host has configured a device fresh from reset jams the endpoint for good
void serial_putc(int c) {
  if (!R(EP1 + 0x50u)) return;
  uint32_t const t = ticks();
  while (!(R(EPC) & 2))
    if (ticks() - t > 32000u) return;
  R(EP1) = (uint32_t)(c & 0xff);
  if (c == '\n') sent(); }

// a host byte, or -1: one left unread holds the host's writes, and its next open waits on them
int serial_rx(void) { return R(EPC) & 4 ? (int)(R(EP1) & 0xff) : -1; }

// a boot from flash arms timer group 0's watchdog and the lp one, and the super watchdog wants
// feeding: the first two off, the third fed by itself. a rom's ram load arms none of them
#define TIMG0 0x60008000u
#define LPWDT 0x600B1C00u
#define WKEY  0x50D83AA1u
static void unguard(void) {
  R(TIMG0 + 0x64u) = WKEY, R(TIMG0 + 0x48u) = 1u << 22, R(TIMG0 + 0x64u) = 0;   // all off, taken
  R(LPWDT + 0x18u) = WKEY, R(LPWDT) = 0, R(LPWDT + 0x18u) = 0;
  R(LPWDT + 0x20u) = WKEY, R(LPWDT + 0x1Cu) |= 1u << 18, R(LPWDT + 0x20u) = 0; }

void _start(void) {
  unguard();
  R(SYSTIM) |= 1u << 30;                                    // the timer counts, kept running
  main();
  for (;;) {} }
