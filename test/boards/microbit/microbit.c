// micro:bit v2 arch backend, the C half (no sdk): the crystal, the UART0 console through the
// daplink, TIMER0's microseconds, the 5x5 matrix, the die's temperature and a ble beacon. vectors, crt0 and the asm helpers are mkboot.l's
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
  REG(GPIO_CNF(P0, BTN_A)) = 3u << 2, REG(GPIO_CNF(P0, BTN_B)) = 3u << 2;   // inputs, pulled up
  REG(GPIO_OUTCLR(P0)) = 1u << SPKR_PIN;
  REG(GPIO_DIRSET(P0)) = 1u << SPKR_PIN;
  for (int k = 0; k < LED_N; k++) {
    REG(GPIO_OUTCLR(P0)) = 1u << row_pin[k];
    REG(GPIO_DIRSET(P0)) = 1u << row_pin[k];
    col_put(k, 0);
    REG(GPIO_DIRSET(col_port[k])) = 1u << col_pin[k]; } }

// the centre alone, before the battery runs
void led_put(int on) {
  col_put(2, 1);
  REG(on ? GPIO_OUTSET(P0) : GPIO_OUTCLR(P0)) = 1u << row_pin[2]; }

// a level's share of a row's 32 slices, 32 (v / 8) ** 2.2 so the steps look even; level 1
// keeps one slice rather than rounding dark
#define LED_SLICES 32
static uint8_t const led_gamma[LED_MAX + 1] = { 0, 1, 2, 4, 7, 11, 17, 24, 32 };

// one pass over the rows, LED_SLICES slices of 62 us each, so a pass is ~10 ms. with noise,
// each slice is also a sample: the speaker's pin set to an xorshift bit, white noise at ~16 kHz
void led_scan(uint8_t const *lv, uint32_t *noise) {
  for (int r = 0; r < LED_N; r++) {
    REG(GPIO_OUTSET(P0)) = 1u << row_pin[r];
    for (int s = 0; s < LED_SLICES; s++) {
      if (noise) {
        uint32_t x = *noise;
        x ^= x << 13, x ^= x >> 17, x ^= x << 5, *noise = x;
        REG((x & 1u) ? GPIO_OUTSET(P0) : GPIO_OUTCLR(P0)) = 1u << SPKR_PIN; }
      for (int c = 0; c < LED_N; c++) col_put(c, led_gamma[lv[r * LED_N + c]] > s);
      for (uint32_t t = clock_us(); clock_us() - t < 62u; ) {} }
    REG(GPIO_OUTCLR(P0)) = 1u << row_pin[r]; }
  REG(GPIO_OUTCLR(P0)) = 1u << SPKR_PIN; }

// the buttons held: bit 0 A, bit 1 B
int buttons(void) {
  uint32_t in = REG(GPIO_IN(P0));
  return !(in >> BTN_A & 1u) | !(in >> BTN_B & 1u) << 1; }

// the logo pad, a capacitor: drained low, then released to its pull-up, the us until it reads
// high. a finger adds its capacitance and the charge takes longer; 4 ms caps a stuck pad
uint32_t logo_us(void) {
  REG(GPIO_CNF(P1, LOGO_PIN)) = 1u;                       // output, driven low
  REG(GPIO_OUTCLR(P1)) = 1u << LOGO_PIN;
  for (uint32_t t = clock_us(); clock_us() - t < 20u; ) {}
  REG(GPIO_CNF(P1, LOGO_PIN)) = 0u;                       // input, no pull
  uint32_t t = clock_us(), d = 0;
  while (!(REG(GPIO_IN(P1)) >> LOGO_PIN & 1u) && (d = clock_us() - t) < 4000u) {}
  return d; }

// --- the die's temperature, in quarter degrees ------------------------------
int32_t temp_read(void) {
  REG(TEMP_DATARDY) = 0;
  REG(TEMP_START) = 1;
  while (!REG(TEMP_DATARDY)) {}
  REG(TEMP_DATARDY) = 0;
  return (int32_t) REG(TEMP_TEMP); }

// --- a ble beacon: ADV_NONCONN_IND on the three advertising channels, transmit only ----
// the advertising access address 0x8E89BED6, crc 24 bits of 0x65B from 0x555555, whitened
// by the channel index. the radio rides the crystal clocks_init started
void ble_init(void) {
  REG(RADIO_MODE) = 3;                                     // ble 1 Mbit
  REG(RADIO_TXPOWER) = 0;                                  // 0 dBm
  REG(RADIO_PCNF0) = 8u | 1u << 8;                         // an 8-bit length after a 1-byte S0
  REG(RADIO_PCNF1) = (ADV_PDU_MAX - 2) | 3u << 16 | 1u << 25;   // maxlen, 3-byte base, whitened
  REG(RADIO_BASE0) = 0x89BED600u;
  REG(RADIO_PREFIX0) = 0x8Eu;
  REG(RADIO_TXADDRESS) = 0;
  REG(RADIO_CRCCNF) = 3u | 1u << 8;                        // 3 bytes, the address skipped
  REG(RADIO_CRCPOLY) = 0x65Bu;
  REG(RADIO_CRCINIT) = 0x555555u;
  REG(RADIO_SHORTS) = 1u | 1u << 1; }                     // ready starts, end disables

// a random static address off the factory's, its top two bits set
void ble_addr(uint8_t *a) {
  uint32_t lo = REG(FICR_DEVICEADDR0), hi = REG(FICR_DEVICEADDR1);
  for (int k = 0; k < 4; k++) a[k] = (uint8_t) (lo >> 8 * k);
  a[4] = (uint8_t) hi, a[5] = (uint8_t) (hi >> 8 | 0xC0u); }

// one advertising event: the pdu (EasyDMA reads it, so it lives in RAM) on 37, 38, 39
void ble_adv(uint8_t const *pdu) {
  static uint8_t const freq[3] = { 2, 26, 80 };
  for (int k = 0; k < 3; k++) {
    REG(RADIO_FREQUENCY) = freq[k];
    REG(RADIO_DATAWHITEIV) = 37u + (uint32_t) k;
    REG(RADIO_PACKETPTR) = (uint32_t) (uintptr_t) pdu;
    REG(RADIO_DISABLED) = 0;
    REG(RADIO_TXEN) = 1;
    while (!REG(RADIO_DISABLED)) {} } }
