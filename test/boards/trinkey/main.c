// adafruit neokey trinkey m0 (atsamd21e18, cortex-m0+ at 48 MHz, 32 KB sram) firmware, mooncc
// -t thumb1, from sram only, and in two stages, since the uf2 bootloader holds sram's low 12 KB
// while it loads: its sam-ba puts this first stage high and starts it, and the first host to open
// its usb serial port sends the second (bat.c and rt.o) to sram's base. the flash is never written.
// the battery then runs, each host that opens the port gets its report, and 134 baud there
// reboots it into the bootloader
#include <stdint.h>
#include "samd21.h"
#include "../battery1.h"

void usb_init(void);
void usb_poll(void);
void usb_putc(int c);
void usb_flush(void);
int usb_up(void);
int usb_rx_ready(void);
int usb_getc(void);
int battery(void);

extern uint8_t __s2_base__[], __s2_end__[];

void serial_putc(int c) { usb_putc(c); }

// the port tended while the board waits: rx_ready takes a 134 baud ask into the bootloader
static void tend(void) { usb_poll(); (void) usb_rx_ready(); }

static uint32_t byte(void) { while (!usb_rx_ready()) usb_poll(); return (uint32_t) usb_getc(); }

static uint32_t word(void) { uint32_t w = 0; for (uint32_t i = 0; i < 32; i += 8) w |= byte() << i; return w; }

// the second stage: 'L', its length, its bytes, their sum, each word little-endian. 1 when it
// filled exactly the room laid for it and summed right
static int take(void) {
  while (byte() != 'L') {}
  uint32_t const n = word(), room = (uint32_t) (__s2_end__ - __s2_base__);
  uint32_t sum = 0;
  for (uint32_t i = 0; i < n; i++) {
    uint32_t const b = byte();
    if (i < room) __s2_base__[i] = (uint8_t) b;
    sum += b; }
  return n == room && word() == sum; }

int main(void) {
  usb_init();
  int r = -1;
  for (;;) {
    while (!usb_up()) tend();
    if (r < 0) r = take() ? battery() : 0;
    puts_("\n; mooncc/trinkey (samd21, cortex-m0+, thumb1)\n; core 48 MHz\n");
    puts_((uintptr_t) main >> 28 == 2u ? "; from sram\n" : "; from flash\n");   // where this code runs
    if (!r) puts_("; the second stage came short or summed wrong\n");
    else {
      puts_(r <= 100 ? "; all " : "; FAILED at ");
      putu((uint32_t) (r <= 100 ? r : r - 100));
      if (r <= 100) puts_("/"), putu(BATTERY1_N), puts_(" green");
      puts_("\n"); }
    usb_flush();
    while (usb_up()) tend(); } }
