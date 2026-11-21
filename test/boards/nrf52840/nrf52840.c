// xiao nrf52840 arch backend, the C half (no sdk): the crystal, the console on usb.c, TIMER0's
// microseconds and the RGB LED. vectors, crt0 and the asm helpers are mkboot.l's
#include <stdint.h>
#include "nrf52840.h"
#include "../crt0.h"
#include "../../../src/inle/bput.h"

int main(void);

// isr_hardfault (mkboot.l) branches here with the frame in r0, on a fresh stack: name the
// fault, then idle
void hardfault_report(uint32_t *frame) {
  const char *tags[5] = { "\r\n; FAULT pc=", " lr=", " cfsr=", " bfar=", " mmfar=" };
  uint32_t v[5] = { frame[6], frame[5],
                    REG(0xE000ED28u), REG(0xE000ED38u), REG(0xE000ED34u) };
  for (int k = 0; k < 5; k++) {
    bput_s(serial_putc, tags[k]);
    bput_x(serial_putc, v[k], 8); }
  serial_putc('\r'); serial_putc('\n');
  for (;;) {} }

// mkboot.l's cstartup falls in here. the bootloader hands over with its usb live: its
// interrupts off and cleared first, since this table has none past the system sixteen
void cmain(void) {
  arm_irq_off();
  REG(SCB_CPACR) |= (0xFu << 20);
  arm_dsb_isb();
  crt0(8);
  clocks_init();
  timer_init();
  main();
  for (;;) arm_wfi(); }

// the crystal, bounded: a timeout stays on the internal rc, which the banner says
void clocks_init(void) {
  REG(CLOCK_HFSTARTED) = 0;
  REG(CLOCK_HFCLKSTART) = 1;
  for (uint32_t i = 0; i < 4000000u && !REG(CLOCK_HFSTARTED); i++) {} }

int clock_xtal(void) {
  uint32_t s = REG(CLOCK_HFCLKSTAT);
  return (s & HFCLKSTAT_RUNNING) && (s & HFCLKSTAT_XTAL); }

void serial_putc(int c) { usb_putc(c); }

// ms since boot off TIMER0 at 1 MHz (16 MHz / 2^4)
void timer_init(void) {
  REG(TIMER_MODE) = 0;
  REG(TIMER_BITMODE) = 3;
  REG(TIMER_PRESCALER) = 4;
  REG(TIMER_CLEAR) = 1;
  REG(TIMER_START) = 1; }

uint32_t clock_ms(void) {
  REG(TIMER_CAPTURE0) = 1;
  return REG(TIMER_CC0) / 1000u; }

// --- the RGB LED on P0, low lights it -------------------------------------
void led_init(void) {
  uint32_t m = 1u << LED_RED | 1u << LED_GREEN | 1u << LED_BLUE;
  REG(GPIO_OUTSET(P0)) = m;
  REG(GPIO_DIRSET(P0)) = m; }

void led_put(uint32_t pin, int on) { REG(on ? GPIO_OUTCLR(P0) : GPIO_OUTSET(P0)) = 1u << pin; }

// off the bus first, so the host sees the port go; the reset comes up in the flash's app
void reset(void) {
  usb_off();
  arm_dsb_isb();
  REG(SCB_AIRCR) = 0x05FA0004u;                     // vectkey, sysresetreq
  for (;;) {} }

// the bootloader's drive without the reset button's double tap
void reboot_uf2(void) {
  REG(POWER_GPREGRET) = GPREGRET_UF2;
  reset(); }
