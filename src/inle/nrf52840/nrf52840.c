// xiao nrf52840 arch backend, the C half (no sdk): the crystal, the UART0 console on D6/D7,
// TIMER0's microseconds and the RGB LED. vectors, crt0 and the asm helpers are mkboot.l's
#include <stdint.h>
#include "nrf52840.h"
#include "../bput.h"

extern uint32_t __data_start__[], __data_end__[], __data_load__[];
extern uint32_t __bss_start__[], __bss_end__[];
extern void *const vectors[];

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
  for (uint32_t i = 0; i < 8; i++) REG(NVIC_ICER0 + 4u * i) = 0xFFFFFFFFu, REG(NVIC_ICPR0 + 4u * i) = 0xFFFFFFFFu;
  REG(SCB_CPACR) |= (0xFu << 20);
  arm_dsb_isb();
  for (uint32_t *s = __data_load__, *d = __data_start__; d < __data_end__; ) *d++ = *s++;
  for (uint32_t *b = __bss_start__; b < __bss_end__; b++) *b = 0;
  REG(SCB_VTOR) = (uint32_t)(uintptr_t) vectors;
  clocks_init();
  serial_init();
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

// --- UART0 console, 115200 8N1 -------------------------------------------
void serial_init(void) {
  REG(GPIO_OUTSET(P1)) = 1u << TX_PIN;              // idle high before the uart takes it
  REG(GPIO_DIRSET(P1)) = 1u << TX_PIN;
  REG(GPIO_CNF(P1, RX_PIN)) = 3u << 2;              // input, pulled up: an open pin reads idle
  REG(UART_ENABLE) = 0;
  REG(UART_PSELTXD) = PSEL_P1(TX_PIN);
  REG(UART_PSELRXD) = PSEL_P1(RX_PIN);
  REG(UART_PSELRTS) = PSEL_OFF;
  REG(UART_PSELCTS) = PSEL_OFF;
  REG(UART_BAUDRATE) = UART_BAUD_115200;
  REG(UART_CONFIG) = 0;
  REG(UART_ENABLE) = 4;
  REG(UART_TXDRDY) = 0, REG(UART_RXDRDY) = 0;
  REG(UART_STARTTX) = 1;
  REG(UART_STARTRX) = 1; }

// the first byte has no TXDRDY before it, so each waits after its own write
void serial_putc(int c) {
  REG(UART_TXD) = (uint32_t)(c & 0xff);
  for (uint32_t i = 0; i < 1000000u && !REG(UART_TXDRDY); i++) {}
  REG(UART_TXDRDY) = 0; }

int serial_rx_ready(void) {
  if (REG(UART_ERROR)) REG(UART_ERRORSRC) = REG(UART_ERRORSRC), REG(UART_ERROR) = 0;
  return REG(UART_RXDRDY) != 0; }

int serial_getc(void) {
  while (!serial_rx_ready()) {}
  REG(UART_RXDRDY) = 0;
  return (int)(REG(UART_RXD) & 0xffu); }

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

// the bootloader's drive without the reset button's double tap
void reboot_uf2(void) {
  REG(POWER_GPREGRET) = GPREGRET_UF2;
  arm_dsb_isb();
  REG(SCB_AIRCR) = 0x05FA0004u;                     // vectkey, sysresetreq
  for (;;) {} }
