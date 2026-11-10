// the Teensy's own USB as its console: USB1, the RT1062's ChipIdea device controller, held at
// full speed, under ../usbcdc.h's CDC-ACM class. its interrupt takes setup packets, bus resets
// and packets out; packets in are queued by the caller's flush
#include <stdint.h>
#include "teensy41.h"
uintptr_t love_clock(void);
#define UCDC_VID 0x16C0
#define UCDC_PID 0x0483
#define UCDC_PRODUCT "inle teensy41"
#include "../usbcdc.h"

#define USB1(o)  REG(0x402E0000u + (o))
#define USBCMD        0x140u
#define USBSTS        0x144u
#define USBINTR       0x148u
#define DEVICEADDR    0x154u
#define ENDPTLISTADDR 0x158u
#define BURSTSIZE     0x160u
#define PORTSC1       0x184u
#define USBMODE       0x1A8u
#define ENDPTSETUPSTAT 0x1ACu
#define ENDPTPRIME    0x1B0u
#define ENDPTFLUSH    0x1B4u
#define ENDPTSTAT     0x1B8u
#define ENDPTCOMPLETE 0x1BCu
#define ENDPTCTRL(n)  (0x1C0u + 4u * (n))

#define USBPHY1_PWD      0x400D9000u
#define USBPHY1_CTRL_SET 0x400D9034u
#define USBPHY1_CTRL_CLR 0x400D9038u
#define PHY_SFTRST  (1u << 31)
#define PHY_CLKGATE (1u << 30)

#define PLL_USB1     0x400D8010u
#define PLL_USB1_SET 0x400D8014u
#define PLL_USB1_CLR 0x400D8018u
#define PMU_REG_3P0  0x400D8120u
#define CCM_CCGR6    0x400FC080u

#define CMD_RS   (1u << 0)
#define CMD_RST  (1u << 1)
#define CMD_SUTW (1u << 13)
#define STS_UI   (1u << 0)
#define STS_URI  (1u << 6)
#define PORT_PFSC (1u << 24)        // full speed only

#define TD_ACTIVE (1u << 7)
#define TD_IOC    (1u << 15)
#define TD_END    1u                 // a next pointer's terminate bit

// a transfer descriptor, 32 bytes, and an endpoint's queue head, 64
struct dtd { uint32_t next, status, page[5], spare; };
struct dqh { uint32_t config, current, next, status, page[5], reserved, setup[2], pad[4]; };

// the queue heads (2048-aligned), descriptors and buffers, in an 8 KB window of a 16 KB array
// that the MPU types non-cacheable, so the controller and the core see the same bytes
static uint32_t usb_mem[4096];
static uintptr_t win;
#define QH(i)   ((volatile struct dqh *) (win + 64u * (i)))
#define TD_EP0  ((volatile struct dtd *) (win + 2048u))
#define TD_ACK  ((volatile struct dtd *) (win + 2080u))
#define TD_RX   ((volatile struct dtd *) (win + 2112u))
#define TD_TX   ((volatile struct dtd *) (win + 2144u))
#define EP0BUF  ((uint8_t *) (win + 2304u))
#define RXBUF   ((uint8_t *) (win + 2560u))
#define TXBUF   ((uint8_t *) (win + 4096u))      // one 4 KB page

// the RAM vector table: the 16 system entries and the 160 IRQs, 1024-aligned for VTOR
static uint32_t vec_mem[512];
extern void *const vectors[];
void default_handler(void);
void arm_irq_on(void);
uint32_t arm_ipsr(void);

// the window's stores ride the axi port and the register the ahb, so a prime can pass the dtd
// it names: drain first
static void prime(uint32_t bit) {
  arm_dsb();
  USB1(ENDPTPRIME) = bit;
  for (uint32_t k = 0; USB1(ENDPTPRIME) & bit; k++) if (k > 1000000u) return; }

// a descriptor queued on an idle endpoint: queue head 2 ep + in
static void queue(uint32_t qh, volatile struct dtd *t, void const *buf, uint32_t n, uint32_t ioc) {
  t->next = TD_END, t->status = n << 16 | TD_ACTIVE | ioc, t->page[0] = (uint32_t) (uintptr_t) buf;
  QH(qh)->next = (uint32_t) (uintptr_t) t, QH(qh)->status = 0;
  prime(qh & 1 ? 1u << (16 + qh / 2) : 1u << (qh / 2)); }

static void usbhw_ep0_ack(void) {
  USB1(ENDPTCOMPLETE) = 1u | 1u << 16;
  queue(1, TD_ACK, 0, 0, 0); }

static void usbhw_ep0_in(void const *src, uint32_t n) {
  if (n) {
    for (uint32_t i = 0; i < n; i++) EP0BUF[i] = ((uint8_t const *) src)[i];
    queue(1, TD_EP0, EP0BUF, n, 0); }
  USB1(ENDPTCOMPLETE) = 1u | 1u << 16;
  queue(0, TD_ACK, 0, 0, 0); }

static void usbhw_ep0_out(uint32_t n) {
  queue(0, TD_EP0, EP0BUF, n, TD_IOC);
  usbhw_ep0_ack(); }

static void usbhw_ep0_stall(void) { USB1(ENDPTCTRL(0)) = 1u << 16 | 1u; }

// takes effect after the status stage (USBADRA)
static void usbhw_address(uint32_t a) { USB1(DEVICEADDR) = a << 25 | 1u << 24; }

static void usbhw_open(void) {
  QH(4)->config = ucdc_pkt << 16;                  // 2 out
  QH(5)->config = ucdc_pkt << 16;                  // 2 in, a zero-length packet ending a full one
  QH(7)->config = 16u << 16;                       // 3 in
  // bulk = 2, interrupt = 3; an unused direction is typed bulk, never control
  USB1(ENDPTCTRL(2)) = 1u << 23 | 1u << 22 | 2u << 18 | 1u << 7 | 1u << 6 | 2u << 2;
  USB1(ENDPTCTRL(3)) = 1u << 23 | 1u << 22 | 3u << 18 | 2u << 2;
  TD_TX->status = 0; }

static void usbhw_clear_halt(uint32_t ep) {
  uint32_t n = ep & 0x7F;
  if (n == 2 || n == 3) USB1(ENDPTCTRL(n)) = (USB1(ENDPTCTRL(n)) & ~(1u << 16 | 1u)) | (ep & 0x80 ? 1u << 22 : 1u << 6); }

static void usbhw_rx_arm(void) { queue(4, TD_RX, RXBUF, ucdc_pkt, TD_IOC); }

// a descriptor the controller let go unsent (a reset, or a host that closed mid-send and
// suspended) stays active in memory with nothing primed: it is idle again, its bytes lost
static int usbhw_tx_busy(void) {
  uint32_t const b = 1u << 18;
  if (!(TD_TX->status & TD_ACTIVE)) return 0;
  if ((USB1(ENDPTSTAT) | USB1(ENDPTPRIME)) & b) return 1;
  TD_TX->status = 0;
  return 0; }

static void usbhw_tx(void const *src, uint32_t n) {
  for (uint32_t i = 0; i < n; i++) TXBUF[i] = ((uint8_t const *) src)[i];
  queue(5, TD_TX, TXBUF, n, 0); }

static uint32_t usbhw_ms(void) { return (uint32_t) love_clock(); }

// the halt the bootloader chip watches for; the monitor off, so the bkpt is not ours
void arm_halt251(void);
static void usbhw_reboot(void) {
  USB1(USBCMD) &= ~CMD_RS;
  REG(0xE000EDFCu) &= ~(1u << 16);
  arm_halt251(); }

void usb_isr(void) {
  uint32_t s = USB1(USBSTS);
  USB1(USBSTS) = s;
  if (s & STS_URI) {
    USB1(ENDPTSETUPSTAT) = USB1(ENDPTSETUPSTAT);
    USB1(ENDPTCOMPLETE) = USB1(ENDPTCOMPLETE);
    for (uint32_t k = 0; USB1(ENDPTPRIME); k++) if (k > 1000000u) break;
    USB1(ENDPTFLUSH) = 0xFFFFFFFFu;
    ucdc_reset(); }
  if (!(s & STS_UI)) return;
  while (USB1(ENDPTSETUPSTAT) & 1u) {
    uint32_t s0, s1;
    // the tripwire: a setup landing mid-read clears SUTW, and the read goes again
    do { USB1(USBCMD) |= CMD_SUTW; s0 = QH(0)->setup[0], s1 = QH(0)->setup[1]; } while (!(USB1(USBCMD) & CMD_SUTW));
    USB1(USBCMD) &= ~CMD_SUTW;
    USB1(ENDPTSETUPSTAT) = 1u;
    USB1(ENDPTFLUSH) = 1u | 1u << 16;
    for (uint32_t k = 0; USB1(ENDPTFLUSH) & (1u | 1u << 16); k++) if (k > 1000000u) break;
    ucdc_setup(s0, s1); }
  uint32_t c = USB1(ENDPTCOMPLETE);
  USB1(ENDPTCOMPLETE) = c;
  if (c & 1u) ucdc_ep0_out(EP0BUF, 7u - (TD_EP0->status >> 16 & 0x7FFFu));
  if (c & 1u << 2) ucdc_rx(RXBUF, ucdc_pkt - (TD_RX->status >> 16 & 0x7FFFu)); }

// any other irq: masked and returned from, so one left live never parks the core
static void usb_stray(void) {
  uint32_t n = arm_ipsr() - 16u;
  if (n < 160) REG(0xE000E180u + 4u * (n / 32)) = 1u << (n % 32); }

#define SCB_DCCIMVAC 0xE000EF70u
#define MPU_CTRL 0xE000ED94u
#define MPU_RBAR 0xE000ED9Cu
#define MPU_RASR 0xE000EDA0u
#define NVIC_ISER3 0xE000E10Cu
enum { irq_usb1 = 113 };

static void wait_ms(uint32_t ms) { uint32_t t = usbhw_ms(); while (usbhw_ms() - t < ms) {} }

void usb_init(void) {
  win = ((uintptr_t) usb_mem + 8191u) & ~(uintptr_t) 8191u;
  for (uint32_t i = 0; i < 8192u; i += 4) REG(win + i) = 0;
  // the window's lines out of the cache before the MPU types it, so none is evicted onto a DMA
  arm_dsb();
  for (uint32_t i = 0; i < 8192u; i += 32) REG(SCB_DCCIMVAC) = (uint32_t) (win + i);
  arm_dsb();
  REG(MPU_RBAR) = (uint32_t) win | 1u << 4;                             // region 0, valid
  REG(MPU_RASR) = 1u << 28 | 3u << 24 | 1u << 19 | 12u << 1 | 1u;       // XN, rw, normal uncached, 8 KB
  REG(MPU_CTRL) = 1u << 2 | 1u;                                         // the default map elsewhere
  arm_dsb_isb();

  // the 480 MHz PLL, stepped until it holds
  for (uint32_t k = 0; k < 1000000u; k++) {
    uint32_t n = REG(PLL_USB1);
    if (n & 1u << 1) { REG(PLL_USB1_CLR) = 0xC000u; REG(PLL_USB1_SET) = 1u << 16;
                       REG(PLL_USB1_CLR) = 1u << 12 | 1u << 1 | 1u << 13 | 1u << 6; continue; }
    if (!(n & 1u << 13)) { REG(PLL_USB1_SET) = 1u << 13; continue; }
    if (!(n & 1u << 12)) { REG(PLL_USB1_SET) = 1u << 12; continue; }
    if (!(n & 1u << 31)) continue;
    if (n & 1u << 16) { REG(PLL_USB1_CLR) = 1u << 16; continue; }
    if (!(n & 1u << 6)) { REG(PLL_USB1_SET) = 1u << 6; continue; }
    break; }
  REG(PMU_REG_3P0) = 0x0Fu << 8 | 6u << 4 | 1u;
  REG(CCM_CCGR6) |= 3u;                                                 // usboh3
  USB1(BURSTSIZE) = 0x0404u;
  // the bootloader leaves the phy and controller running: reset both
  if (REG(USBPHY1_PWD) || (USB1(USBMODE) & 3u)) {
    REG(USBPHY1_CTRL_SET) = PHY_SFTRST;
    USB1(USBCMD) |= CMD_RST;
    for (uint32_t k = 0; k < 1000000u && (USB1(USBCMD) & CMD_RST); k++) {}
    REG(USBPHY1_CTRL_CLR) = PHY_SFTRST;
    wait_ms(25); }
  REG(USBPHY1_CTRL_CLR) = PHY_CLKGATE;
  REG(USBPHY1_PWD) = 0;
  USB1(USBMODE) = 2u | 1u << 3;                                         // device, setup lockouts off
  QH(0)->config = ucdc_pkt << 16 | 1u << 15;                            // ep0 out, interrupt on setup
  QH(1)->config = ucdc_pkt << 16;
  USB1(ENDPTLISTADDR) = (uint32_t) win;
  USB1(PORTSC1) |= PORT_PFSC;

  uintptr_t vt = ((uintptr_t) vec_mem + 1023u) & ~(uintptr_t) 1023u;
  for (uint32_t i = 0; i < 16; i++) REG(vt + 4 * i) = (uint32_t) (uintptr_t) vectors[i];
  for (uint32_t i = 16; i < 176; i++) REG(vt + 4 * i) = (uint32_t) (uintptr_t) usb_stray;
  REG(vt + 4 * (16 + irq_usb1)) = (uint32_t) (uintptr_t) usb_isr;
  arm_dsb();
  REG(SCB_VTOR) = (uint32_t) vt;
  arm_dsb_isb();
  USB1(USBINTR) = STS_UI | STS_URI;
  REG(NVIC_ISER3) = 1u << (irq_usb1 - 96);
  arm_irq_on();
  USB1(USBCMD) = CMD_RS; }
