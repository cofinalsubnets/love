// a64 on the raspberry pi zero 2 w (bcm2837, as the 3's): the mini uart console on gpio14/15,
// the bcm2836 local intc and the bcm2835 armctrl, the pm watchdog's reset, the hardware rng
// and the videocore's mailbox. stands in for a64/arch.c; the stub maps the peripherals, so
// nothing is mapped here
#include <stdint.h>
#include "../asmops.h"                 // the privileged instructions, both spellings
#include "k.h"                       // kticks, kq's queue
#include "../../mmio.h"               // mmio_rd/mmio_wr, device registers off the direct map

void kq(uint8_t);                      // kmain's input queue, one byte
void k_timer_init(void), k_timer_rearm(void);   // cpu.c
int usb_init(void), usb_up(void), usb_rx_ready(void), usb_getc(void);   // usb.c
void usb_irq(void), usb_tick(void), usb_putc(int);
uint32_t usb_hwcfg(int);

#define PERI    0x3f000000             // the peripherals, as the arm sees them
#define AUX     (PERI + 0x215000)      // the mini uart's block
#define ARMCTL  (PERI + 0x00b200)      // the gpu's interrupts, as the arm takes them
#define PM      (PERI + 0x100000)      // power management: the watchdog
#define RNG     (PERI + 0x104000)      // the hardware rng
#define MBOX    (PERI + 0x00b880)      // the videocore's mailbox 0
#define LOCAL   0x40000000             // the bcm2836 per-core block

#define AUX_ENABLES 0x04               // bit 0: the mini uart
#define MU_IO       0x40               // data
#define MU_IER      0x44               // bit 0: receive interrupt
#define MU_LCR      0x4c               // 3: 8 bits
#define MU_LSR      0x54               // line status
#define MU_CNTL     0x60               // 3: receive and transmit on
#define LSR_RX      (1u << 0)          // a byte waits
#define LSR_TXE     (1u << 5)          // room for one

#define IRQ_PEND1   0x04               // gpu interrupts 0-31, pending
#define IRQ_EN1     0x10               // ..set-enable
#define AUX_BIT     (1u << 29)         // aux is gpu interrupt 29
#define USB_BIT     (1u << 9)          // the otg controller, gpu interrupt 9

#define CORE0_TIMER 0x40               // core 0's timer interrupt control
#define CORE0_SRC   0x60               // core 0's interrupt source
#define SRC_CNTPNS  (1u << 1)          // the el1 physical timer
#define SRC_GPU     (1u << 8)          // the armctrl's, routed to core 0

// no clock on the board: kmain asks the network, or keeps 0
uint64_t k_rtc(void) { return 0; }

// the firmware laid the pins and the baud (enable_uart=1); only the fifo and the irq are ours
void serial_init(void) {
  mmio_wr(AUX, AUX_ENABLES, mmio_rd(AUX, AUX_ENABLES) | 1);
  mmio_wr(AUX, MU_LCR, 3);
  mmio_wr(AUX, MU_CNTL, 3);
  // what the line caught before us (the firmware's hand-over glitches it) is no one's keys
  for (int i = 0; i < 16 && (mmio_rd(AUX, MU_LSR) & LSR_RX); i++) (void) mmio_rd(AUX, MU_IO);
  mmio_wr(AUX, MU_IER, 1);
  mmio_wr(ARMCTL, IRQ_EN1, AUX_BIT); }

// the uart and the otg port both; the usb bytes stage for the timer's flush
void serial_putc(int c) {
  if (c == '\n') serial_putc('\r');
  // bounded, so an absent or wedged port can't hang output
  for (int i = 0; i < 100000 && !(mmio_rd(AUX, MU_LSR) & LSR_TXE); i++) {}
  mmio_wr(AUX, MU_IO, (uint8_t) c);
  uint64_t d = k_irq_save();
  usb_putc(c);
  k_irq_restore(d); }

// the otg port's bytes in, as far as kq has room; the uart's come by interrupt
void k_kb_sync(int room) {
  for (; room > 0 && usb_rx_ready(); room--) kq((uint8_t) usb_getc()); }

// reading the fifo dry clears the receive interrupt
static void k_uart(void) {
  while (mmio_rd(AUX, MU_LSR) & LSR_RX)
    kq(mmio_rd(AUX, MU_IO) & 0xff); }

// from the IRQ vector: the local block says which, the armctrl says which gpu interrupt
void k_irq(void) {
  uint32_t src = mmio_rd(LOCAL, CORE0_SRC);
  if (src & SRC_CNTPNS) kticks++, k_timer_rearm(), usb_tick();
  uint32_t p = src & SRC_GPU ? mmio_rd(ARMCTL, IRQ_PEND1) : 0;
  if (p & AUX_BIT) k_uart();
  if (p & USB_BIT) usb_irq(); }

// the rng: a warm-up count first, then a word whenever the fifo holds one
#define RNG_CTRL    0x00
#define RNG_STATUS  0x04
#define RNG_DATA    0x08
#define RNG_MASK    0x10
static void rng_init(void) {
  mmio_wr(RNG, RNG_STATUS, 0x40000);
  mmio_wr(RNG, RNG_MASK, mmio_rd(RNG, RNG_MASK) | 1);    // no interrupt: reads poll
  mmio_wr(RNG, RNG_CTRL, mmio_rd(RNG, RNG_CTRL) | 1); }

// /dev/urandom's bytes; a fifo that stays empty answers short
uintptr_t k_entropy(unsigned char *p, uintptr_t n) {
  uintptr_t k = 0;
  while (k < n) {
    for (int t = 0; !(mmio_rd(RNG, RNG_STATUS) >> 24); t++)
      if (t > 1000000) return k;
    uint32_t w = mmio_rd(RNG, RNG_DATA);
    for (int b = 0; b < 4 && k < n; b++) p[k++] = (unsigned char) (w >> 8 * b); }
  return k; }

// the property channel: one tag a call, v its words in and its answer out. the buffer is the
// caller's stack, cleaned to ram for the videocore and invalidated after; it reads ram
// through the uncached 0xc0000000 alias. -1 on a refusal or a mailbox that never answers
#define MB_READ   0x00
#define MB_STATUS 0x18
#define MB_WRITE  0x20
#define MB_FULL   0x80000000u
#define MB_EMPTY  0x40000000u
#define MB_PROP   8
static void mb_sync(uint32_t *b, uintptr_t n) {
  for (uintptr_t a = (uintptr_t) b & ~63ull; a < (uintptr_t) (b + n); a += 64) k_dc_civac(a);
  k_dsb_ish(); }
int k_mbox(uint32_t tag, uint32_t *v, int nv) {
  uint32_t b[32] __attribute__((aligned(64)));
  if (nv < 1 || nv > 24) return -1;
  b[0] = (uint32_t) (6 + nv) * 4, b[1] = 0, b[2] = tag, b[3] = (uint32_t) nv * 4, b[4] = 0;
  for (int i = 0; i < nv; i++) b[5 + i] = v[i];
  b[5 + nv] = 0;
  mb_sync(b, 32);
  uint64_t par = k_at_s1e1w_par(b);
  if (par & 1) return -1;
  uint32_t m = (uint32_t) (((par & 0xfffffffff000ull) | ((uintptr_t) b & 0xfff)) | 0xc0000000u) | MB_PROP;
  for (int t = 0; mmio_rd(MBOX, MB_STATUS) & MB_FULL; t++) if (t > 10000000) return -1;
  mmio_wr(MBOX, MB_WRITE, m);
  for (int t = 0; ; t++) {
    if (t > 10000000) return -1;
    if (mmio_rd(MBOX, MB_STATUS) & MB_EMPTY) continue;
    if (mmio_rd(MBOX, MB_READ) == m) break; }
  mb_sync(b, 32);
  if (b[1] != 0x80000000u || !(b[4] & 0x80000000u)) return -1;
  for (int i = 0; i < nv; i++) v[i] = b[5 + i];
  return 0; }

// /proc/board: the firmware's answers, a row each; a refused tag is no row
static int hexrow(char *b, int at, char const *k, uint64_t v, int digits) {
  while (*k) b[at++] = *k++;
  b[at++] = ' ', b[at++] = '0', b[at++] = 'x';
  for (int i = digits - 1; i >= 0; i--) b[at++] = "0123456789abcdef"[v >> 4 * i & 15];
  b[at++] = '\n';
  return at; }
int k_board(char *b) {
  uint32_t v[2];
  int at = 0;
  if (!k_mbox(0x00010002, (v[0] = 0, v), 1)) at = hexrow(b, at, "revision", v[0], 8);
  if (!k_mbox(0x00010004, (v[0] = v[1] = 0, v), 2)) at = hexrow(b, at, "serial", (uint64_t) v[1] << 32 | v[0], 16);
  if (!k_mbox(0x00010003, (v[0] = v[1] = 0, v), 2)) {       // six bytes, in wire order
    char const *k = "mac ";
    while (*k) b[at++] = *k++;
    for (int i = 0; i < 6; i++) {
      unsigned c = (unsigned) ((uint8_t const *) v)[i];
      b[at++] = "0123456789abcdef"[c >> 4], b[at++] = "0123456789abcdef"[c & 15];
      b[at++] = i < 5 ? ':' : '\n'; } }
  if (!k_mbox(0x00010005, (v[0] = v[1] = 0, v), 2))
    at = hexrow(b, at, "arm-base", v[0], 8), at = hexrow(b, at, "arm-size", v[1], 8);
  if (!k_mbox(0x00000001, (v[0] = 0, v), 1)) at = hexrow(b, at, "firmware", v[0], 8);
  at = hexrow(b, at, "otg-hwcfg2", usb_hwcfg(2), 8), at = hexrow(b, at, "otg-hwcfg3", usb_hwcfg(3), 8);
  at = hexrow(b, at, "otg-hwcfg4", usb_hwcfg(4), 8);
  return at; }

// archinit finds EL1 (the stub dropped from EL2), the MMU, a stack and the HHDM up
void archinit(void) {
  k_sp_to_el1h();
  k_fpen_enable();
  k_wr_vbar_el1((uintptr_t) vectors);
  mmio_wr(LOCAL, CORE0_TIMER, SRC_CNTPNS);       // the physical timer's irq to core 0
  k_timer_init();
  rng_init();
  k_daif_unmask_irq();
  if (usb_init()) mmio_wr(ARMCTL, IRQ_EN1, USB_BIT); }

// the firmware's one-shot flag: the next boot reads the [tryboot] section
void k_tryboot(void) { uint32_t f = 1; k_mbox(0x00038064, &f, 1); }

// the watchdog, a short count and a full reset; the firmware boots again
#define PM_RSTC 0x1c
#define PM_WDOG 0x24
#define PM_PW   0x5a000000u
void k_reset(void) {
  mmio_wr(PM, PM_WDOG, PM_PW | 10);
  mmio_wr(PM, PM_RSTC, PM_PW | (mmio_rd(PM, PM_RSTC) & ~0x30u) | 0x20);
  for (;;) k_wait(); }
