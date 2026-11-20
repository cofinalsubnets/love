// the pi's bluetooth: the cyw43438's hci on the pl011 (gpio 30-33 at alt3: cts, rts, txd, rxd),
// its power on gpio 42. /dev/hci carries the h4 bytes both ways; the radio runs its rom's
// firmware, no patch. powered at the first touch, the uart at 115200, the rom's own rate
#include <stdint.h>
#include "../asmops.h"
#include "k.h"
#include "../../mmio.h"

int k_mbox(uint32_t tag, uint32_t *v, int nv);   // arch.c

#define PERI    0x3f000000
#define GPIO    (PERI + 0x200000)
#define UART0   (PERI + 0x201000)
#define ARMCTL  (PERI + 0x00b200)

#define GPSET1    0x20                 // pins 32-53
#define GPCLR1    0x2c
#define GPPUD     0x94                 // the bcm2837's pull: the kind, then a clock per pin
#define GPPUDCLK0 0x98

#define DR      0x00
#define FR      0x18                   // bit 4 rx empty, 5 tx full
#define IBRD    0x24
#define FBRD    0x28
#define LCRH    0x2c
#define CR      0x30
#define IMSC    0x38
#define ICR     0x44
#define FR_RXFE (1u << 4)
#define FR_TXFF (1u << 5)
#define RXI     (1u << 4)              // a byte, or the fifo's level
#define RTI     (1u << 6)              // ..or a quiet line with bytes in the fifo

#define IRQ_EN2   0x14                 // gpu interrupts 32-63, set-enable
#define UART0_BIT (1u << 25)           // the pl011, gpu interrupt 57

#define BAUD 115200u

// the radio's bytes, taken by the interrupt; a full ring drops what comes
static volatile uint8_t ring[4096];
static volatile uint32_t rw, rr, up;

static void spin_us(uint64_t us) {
  uint64_t const f = k_rd_cntfrq_el0(), t = k_rd_cntpct_el0();
  while ((k_rd_cntpct_el0() - t) * 1000000 < us * f) {} }

static void fsel(uint32_t pin, uint32_t fn) {
  uint32_t const o = pin / 10 * 4, s = pin % 10 * 3;
  mmio_wr(GPIO, o, (mmio_rd(GPIO, o) & ~(7u << s)) | fn << s); }

// how: 0 none, 2 up
static void pull(uint32_t pin, uint32_t how) {
  mmio_wr(GPIO, GPPUD, how), spin_us(5);
  mmio_wr(GPIO, GPPUDCLK0 + pin / 32 * 4, 1u << pin % 32), spin_us(5);
  mmio_wr(GPIO, GPPUD, 0), mmio_wr(GPIO, GPPUDCLK0 + pin / 32 * 4, 0); }

// the radio off a while, its pins and uart laid, then on and given its rom's start
static void hci_up(void) {
  if (up) return;
  fsel(42, 1), mmio_wr(GPIO, GPCLR1, 1u << 10), spin_us(10000);
  for (uint32_t p = 30; p <= 33; p++) fsel(p, 7);
  pull(30, 2), pull(31, 0), pull(32, 0), pull(33, 2);
  mmio_wr(UART0, CR, 0);
  mmio_wr(UART0, LCRH, 0);                                  // the fifo flushed
  mmio_wr(UART0, ICR, 0x7ff);
  uint32_t v[2] = { 2, 0 };                                 // the uart's clock, as the firmware set it
  uint32_t const clk = !k_mbox(0x00030002, v, 2) && v[1] ? v[1] : 48000000u;
  uint32_t const d = (uint32_t) (((uint64_t) clk * 4 + BAUD / 2) / BAUD);   // 64ths of 16x the baud
  mmio_wr(UART0, IBRD, d >> 6), mmio_wr(UART0, FBRD, d & 63);
  mmio_wr(UART0, LCRH, 3u << 5 | 1u << 4);                  // 8n1, the fifos on
  mmio_wr(UART0, IMSC, RXI | RTI);
  mmio_wr(UART0, CR, 1u | 1u << 8 | 1u << 9 | 1u << 14 | 1u << 15);   // on, tx, rx, rts, cts
  mmio_wr(ARMCTL, IRQ_EN2, UART0_BIT);
  mmio_wr(GPIO, GPSET1, 1u << 10), spin_us(100000);
  up = 1; }

// the interrupts cleared, then the fifo dry: a byte landing between the two still raises one
static void drain(void) {
  mmio_wr(UART0, ICR, RXI | RTI);
  while (!(mmio_rd(UART0, FR) & FR_RXFE)) {
    uint8_t const c = (uint8_t) mmio_rd(UART0, DR);
    if (rw - rr < sizeof ring) ring[rw % sizeof ring] = c, rw++; } }

// from k_irq
void hci_irq(void) { drain(); }

// the readers drain too, the interrupt held off, so nothing waits on one that never comes
int k_hci_ready(void) {
  hci_up();
  uint64_t d = k_irq_save();
  drain();
  int const r = rw != rr;
  return k_irq_restore(d), r; }

intptr_t k_hci_read(unsigned char *dst, uintptr_t n) {
  hci_up();
  uint64_t d = k_irq_save();
  drain();
  uintptr_t k = 0;
  for (; k < n && rr != rw; k++) dst[k] = ring[rr % sizeof ring], rr++;
  return k_irq_restore(d), (intptr_t) k; }

// cts holds the uart while the radio is busy: bounded, so a dead radio can't hang a writer
intptr_t k_hci_write(unsigned char const *src, uintptr_t n) {
  hci_up();
  for (uintptr_t k = 0; k < n; k++) {
    for (int t = 0; mmio_rd(UART0, FR) & FR_TXFF; t++)
      if (t > 1000000) return k ? (intptr_t) k : -1;
    mmio_wr(UART0, DR, src[k]); }
  return (intptr_t) n; }
