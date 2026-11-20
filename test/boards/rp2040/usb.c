// the rp2040's usb controller (and the rp2350's, the same block) as a cdc-acm device, under ../../../src/inle/usbcdc.h's class
// half, at full speed and polled: usb_poll takes setup packets, bus resets and finished
// buffers. endpoint 0 and the data endpoints move at most a packet a buffer, so a longer
// transfer goes a packet at a time from the buffer-done path. under UCDC_ACM2 the second port
// rides endpoints 4 and 5
#include <stdint.h>
#ifdef RP2350
#include "../rp2350/rp2350.h"
#else
#include "rp2040.h"
#endif
#define UCDC_VID 0x1209
#define UCDC_PID 0x0001
#ifndef UCDC_PRODUCT
#define UCDC_PRODUCT "love swd probe"
#endif
static char serial[17];   // the chip's unique id in hex, set by usb_init
#define UCDC_SERIAL serial
#include "../../../src/inle/usbcdc.h"

#define DPRAM 0x50100000u
#define UREG(o) REG(0x50110000u + (o))
#define ADDR_ENDP   0x00u
#define MAIN_CTRL   0x40u
#define SIE_CTRL    0x4cu
#define SIE_STATUS  0x50u
#define BUFF_STATUS 0x58u
#define STALL_ARM   0x68u
#define USB_MUXING  0x74u
#define USB_PWR     0x78u
#define ST_SETUP (1u << 17)
#define ST_RESET (1u << 19)

// an endpoint's control word (n >= 1) and buffer control word, in dpram
#define EP_CTRL(n, out) REG(DPRAM + 8u * (n) + ((out) ? 4u : 0u))
#define BUF_CTRL(n, out) REG(DPRAM + 0x80u + 8u * (n) + ((out) ? 4u : 0u))
#define EP_ON    (1u << 31)
#define EP_INT1  (1u << 29)
#define BC_FULL  (1u << 15)
#define BC_LAST  (1u << 14)
#define BC_PID1  (1u << 13)
#define BC_STALL (1u << 11)
#define BC_AVAIL (1u << 10)
#define EP0BUF ((uint8_t *) (DPRAM + 0x100u))
#define RXBUF  ((uint8_t *) (DPRAM + 0x180u))   // 2 out
#define TXBUF  ((uint8_t *) (DPRAM + 0x1c0u))   // 2 in
#define RX5BUF ((uint8_t *) (DPRAM + 0x280u))   // 5 out, after 3 in at 0x200 and 4 in at 0x240
#define TX5BUF ((uint8_t *) (DPRAM + 0x2c0u))   // 5 in

// the next data pid of each buffer (2 n + out), what endpoint 0 still owes in, and a bulk
// endpoint's send in flight with its copy
static uint32_t pid[12];
static uint8_t const *e0p;
static uint32_t e0n, e0addr, e0want;
struct tx { uint8_t b[ucdc_tx]; uint8_t const *p; uint32_t n, last, on; };
static struct tx tx2;
#ifdef UCDC_ACM2
static struct tx tx5;
#endif

// AVAILABLE goes in a write of its own, a few clk_usb cycles after the rest
static void arm(uint32_t n, uint32_t out, uint32_t len, uint32_t extra) {
  uint32_t const i = 2u * n + out;
  uint32_t v = len | BC_LAST | (pid[i] ? BC_PID1 : 0) | (out ? 0 : BC_FULL) | extra;
  pid[i] ^= 1u;
  BUF_CTRL(n, out) = v;
  for (volatile uint32_t k = 0; k < 12; k++) {}
  BUF_CTRL(n, out) = v | BC_AVAIL; }

static void e0next(void) {
  uint32_t const m = e0n < ucdc_pkt ? e0n : ucdc_pkt;
  for (uint32_t i = 0; i < m; i++) EP0BUF[i] = e0p[i];
  e0p += m, e0n -= m;
  arm(0, 0, m, 0);
  if (!e0n) arm(0, 1, 0, 0); }

// a data stage in, a packet at a time, the status stage out armed behind its last
static void usbhw_ep0_in(void const *src, uint32_t n) { e0p = src, e0n = n; e0next(); }

static void usbhw_ep0_ack(void) { arm(0, 0, 0, 0); }

static void usbhw_ep0_out(uint32_t n) { e0want = n; arm(0, 1, n, 0); }

static void usbhw_ep0_stall(void) {
  UREG(STALL_ARM) = 3u;
  BUF_CTRL(0, 0) = BC_STALL;
  BUF_CTRL(0, 1) = BC_STALL; }

// the address takes after its status stage goes in
static void usbhw_address(uint32_t a) { e0addr = a | 0x100u; }

static void usbhw_open(void) {
  EP_CTRL(2, 1) = EP_ON | EP_INT1 | 2u << 26 | 0x180u;
  EP_CTRL(2, 0) = EP_ON | EP_INT1 | 2u << 26 | 0x1c0u;
  EP_CTRL(3, 0) = EP_ON | EP_INT1 | 3u << 26 | 0x200u;
#ifdef UCDC_ACM2
  EP_CTRL(4, 0) = EP_ON | EP_INT1 | 3u << 26 | 0x240u;
  EP_CTRL(5, 1) = EP_ON | EP_INT1 | 2u << 26 | 0x280u;
  EP_CTRL(5, 0) = EP_ON | EP_INT1 | 2u << 26 | 0x2c0u;
  tx5.on = 0;
#endif
  for (uint32_t i = 2; i < 12; i++) pid[i] = 0;
  tx2.on = 0; }

static void usbhw_clear_halt(uint32_t ep) {
  uint32_t const n = ep & 0x7Fu, out = !(ep & 0x80u);
  if (2 <= n && n <= 5) pid[2u * n + out] = 0, BUF_CTRL(n, out) &= ~BC_STALL; }

static void usbhw_rx_arm(void) { arm(2, 1, ucdc_pkt, 0); }

static void txnext(struct tx *t, uint32_t ep, uint8_t *buf) {
  uint32_t const m = t->n < ucdc_pkt ? t->n : ucdc_pkt;
  for (uint32_t i = 0; i < m; i++) buf[i] = t->p[i];
  t->p += m, t->n -= m, t->last = m;
  arm(ep, 0, m, 0); }

// the class fills its buffer again once this returns, so the send goes from a copy
static void txstart(struct tx *t, uint32_t ep, uint8_t *buf, void const *src, uint32_t n) {
  for (uint32_t i = 0; i < n; i++) t->b[i] = ((uint8_t const *) src)[i];
  t->p = t->b, t->n = n, t->on = 1;
  txnext(t, ep, buf); }

// a packet in landed: the rest, then a zero packet after a full one
static void txdone(struct tx *t, uint32_t ep, uint8_t *buf) {
  if (t->n) txnext(t, ep, buf);
  else if (t->last == ucdc_pkt) t->last = 0, arm(ep, 0, 0, 0);
  else t->on = 0; }

void usb_poll(void);
static int usbhw_tx_busy(void) { usb_poll(); return (int) tx2.on; }
static void usbhw_tx(void const *src, uint32_t n) { txstart(&tx2, 2, TXBUF, src, n); }
#ifdef UCDC_ACM2
static void usbhw_uart_rx_arm(void) { arm(5, 1, ucdc_pkt, 0); }
static int usbhw_uart_tx_busy(void) { usb_poll(); return (int) tx5.on; }
static void usbhw_uart_tx(void const *src, uint32_t n) { txstart(&tx5, 5, TX5BUF, src, n); }
#endif

static uint32_t usbhw_ms(void) { return clock_ms(); }

static void usbhw_reboot(void) { rom_bootsel(); }

void usb_poll(void) {
  uint32_t const s = UREG(SIE_STATUS);
  if (s & ST_RESET) {
    UREG(SIE_STATUS) = ST_RESET;
    UREG(ADDR_ENDP) = 0;
    e0n = 0, e0addr = 0, e0want = 0, tx2.on = 0;
#ifdef UCDC_ACM2
    tx5.on = 0;
#endif
    ucdc_reset(); }
  if (s & ST_SETUP) {
    UREG(SIE_STATUS) = ST_SETUP;
    e0n = 0, e0want = 0;
    pid[0] = pid[1] = 1;
    ucdc_setup(REG(DPRAM), REG(DPRAM + 4u)); }
  uint32_t const b = UREG(BUFF_STATUS);
  if (!b) return;
  UREG(BUFF_STATUS) = b;
  if (b & 1u) {                                   // 0 in
    if (e0n) e0next();
    if (e0addr & 0x100u) UREG(ADDR_ENDP) = e0addr & 0x7Fu, e0addr = 0; }
  if (b & 2u && e0want) {                          // 0 out, a data stage
    uint32_t const n = BUF_CTRL(0, 1) & 0x3FFu;
    e0want = 0;
    ucdc_ep0_out(EP0BUF, n);
    usbhw_ep0_ack(); }
  if (b & 1u << 5) ucdc_rx(RXBUF, BUF_CTRL(2, 1) & 0x3FFu);   // 2 out
  if (b & 1u << 4) txdone(&tx2, 2, TXBUF);                     // 2 in
#ifdef UCDC_ACM2
  if (b & 1u << 11) ucdc_uart_rx(RX5BUF, BUF_CTRL(5, 1) & 0x3FFu);   // 5 out
  if (b & 1u << 10) txdone(&tx5, 5, TX5BUF);                         // 5 in
#endif
}

// the serial the chip's id; pll_usb 12 MHz x 120 / 6 / 5 = 48 MHz into clk_usb, then the controller on its phy, vbus taken
// as present, the pullup on. the rom's usb boot leaves the pll running and feeding clk_usb, so
// the clock stops and the pll resets before either is set
void usb_init(void) {
  uint8_t id[8];
  chip_uid(id);
  for (uint32_t i = 0; i < 16; i++) serial[i] = "0123456789ABCDEF"[id[i / 2] >> (i & 1 ? 0 : 4) & 15u];
  REG(CLK_USB_CTRL) = 0;
  for (volatile uint32_t k = 0; k < 64; k++) {}
  REG(RESETS_RESET + REG_SET) = RST_PLL_USB;
  REG(RESETS_RESET + REG_CLR) = RST_PLL_USB;
  while (!(REG(RESETS_RESET_DONE) & RST_PLL_USB)) {}
  REG(PLL_USB_BASE + 0x0u) = 1;
  REG(PLL_USB_BASE + 0x8u) = 120;
  REG(PLL_USB_BASE + 0x4u + REG_CLR) = PLL_PWR_PD | PLL_PWR_VCOPD;
  while (!(REG(PLL_USB_BASE + 0x0u) & PLL_CS_LOCK)) {}
  REG(PLL_USB_BASE + 0xcu) = (6u << 16) | (5u << 12);
  REG(PLL_USB_BASE + 0x4u + REG_CLR) = PLL_PWR_POSTDIVPD;
  REG(CLK_USB_DIV) = CLK_DIV_1;
  REG(CLK_USB_CTRL) = CLK_PERI_ENABLE;             // auxsrc 0, pll_usb
  REG(RESETS_RESET + REG_SET) = RST_USBCTRL;
  REG(RESETS_RESET + REG_CLR) = RST_USBCTRL;
  while (!(REG(RESETS_RESET_DONE) & RST_USBCTRL)) {}
  for (uint32_t i = 0; i < 4096u; i += 4) REG(DPRAM + i) = 0;
  UREG(USB_MUXING) = 1u | 1u << 3;
  UREG(USB_PWR) = 1u << 2 | 1u << 3;
  UREG(MAIN_CTRL) = 1u;
  UREG(SIE_CTRL) = 1u << 29 | 1u << 16; }
