// pico 2 (RP2350, Arm) firmware, all mooncc -t thumb2sp (the M33's single-precision FPU, f64
// through __aeabi_*). not love: the toolchain on silicon, ../battery.h over the chip's own usb
// serial port. the battery runs once at boot; each host that opens the port gets its report,
// and 134 baud reboots it into the rom's drive
#include <stdint.h>
#include "rp2350.h"
#include "../battery.h"

void usb_init(void);
void usb_poll(void);
void usb_putc(int c);
void usb_flush(void);
int usb_up(void);
int usb_rx_ready(void);

void serial_putc(int c) { usb_putc(c); }

// the port tended while the board waits: rx_ready takes a 134 baud ask into bootsel
static void tend(void) { usb_poll(); (void) usb_rx_ready(); }

int main(void) {
  usb_init();
  int const r = run();
  for (;;) {
    while (!usb_up()) tend();
    puts_("\n; mooncc/rp2350\n; core 150 MHz\n");
    puts_((uintptr_t) main >> 28 == 2u ? "; from sram\n" : "; from flash\n");   // where this code runs
    puts_(r <= 100 ? "; all " : "; FAILED at ");
    putu((uint32_t) (r <= 100 ? r : r - 100));
    puts_(r <= 100 ? "/28 green\n" : "\n");
    usb_flush();
    while (usb_up()) tend(); } }
