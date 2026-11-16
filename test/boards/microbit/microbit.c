// micro:bit v2 arch backend, the C half (no sdk): the crystal, the UART0 console through the
// daplink, TIMER0's microseconds and the 5x5 matrix. vectors, crt0 and the asm helpers are mkboot.l's
#include <stdint.h>
#include "microbit.h"
#include "../../../src/inle/bput.h"

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

// mkboot.l's cstartup falls in here, straight from reset: the debugger may have left
// interrupts pending, and this table has none past the system sixteen
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
  REG(GPIO_OUTSET(P0)) = 1u << TX_PIN;              // idle high before the uart takes it
  REG(GPIO_DIRSET(P0)) = 1u << TX_PIN;
  REG(GPIO_CNF(P1, RX_PIN)) = 3u << 2;              // input, pulled up: an open pin reads idle
  REG(UART_ENABLE) = 0;
  REG(UART_PSELTXD) = TX_PIN;
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

uint32_t clock_us(void) {
  REG(TIMER_CAPTURE0) = 1;
  return REG(TIMER_CC0); }

uint32_t clock_ms(void) { return clock_us() / 1000u; }

// --- the matrix: rows high, columns low ----------------------------------
static uint32_t const row_pin[LED_N] = { 21u, 22u, 15u, 24u, 19u };          // P0
static uint32_t const col_port[LED_N] = { P0, P0, P0, P1, P0 };
static uint32_t const col_pin[LED_N] = { 28u, 11u, 31u, 5u, 30u };

static void col_put(int c, int on) {
  REG(on ? GPIO_OUTCLR(col_port[c]) : GPIO_OUTSET(col_port[c])) = 1u << col_pin[c]; }

void led_init(void) {
  for (int k = 0; k < LED_N; k++) {
    REG(GPIO_OUTCLR(P0)) = 1u << row_pin[k];
    REG(GPIO_DIRSET(P0)) = 1u << row_pin[k];
    col_put(k, 0);
    REG(GPIO_DIRSET(col_port[k])) = 1u << col_pin[k]; } }

// the centre alone, before the battery runs
void led_put(int on) {
  col_put(2, 1);
  REG(on ? GPIO_OUTSET(P0) : GPIO_OUTCLR(P0)) = 1u << row_pin[2]; }

// one pass over the rows, LED_MAX slices of 250 us each: a cell at level v lights for v of
// them, so a pass is ~10 ms
void led_scan(uint8_t const *lv) {
  for (int r = 0; r < LED_N; r++) {
    REG(GPIO_OUTSET(P0)) = 1u << row_pin[r];
    for (int s = 0; s < LED_MAX; s++) {
      for (int c = 0; c < LED_N; c++) col_put(c, lv[r * LED_N + c] > s);
      for (uint32_t t = clock_us(); clock_us() - t < 250u; ) {} }
    REG(GPIO_OUTCLR(P0)) = 1u << row_pin[r]; } }
