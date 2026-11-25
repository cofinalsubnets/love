// the atsamd21's usb device controller as a cdc-acm console, under ../../../src/inle/usbcdc.h's
// class half, at full speed and polled. the controller moves each endpoint's banks by a
// descriptor table in sram: bank 0 out (and setup), bank 1 in, a packet a bank, so a longer
// transfer goes a packet at a time from the transfer-done path
#include <stdint.h>
#include "samd21.h"
#define UCDC_VID 0x1209
#define UCDC_PID 0x0001
#define UCDC_PRODUCT "love board"
static char serial[33];   // the chip's 128-bit serial in hex, set by usb_init
#define UCDC_SERIAL serial
#include "../../../src/inle/usbcdc.h"

#define UREG8(o)  REG8(0x41005000u + (o))
#define UREG16(o) REG16(0x41005000u + (o))
#define UREG(o)   REG(0x41005000u + (o))
#define CTRLA    0x00u
#define SYNCBUSY 0x02u
#define CTRLB    0x08u
#define DADD     0x0Au
#define INTFLAG  0x1Cu
#define DESCADD  0x24u
#define PADCAL   0x28u
#define EORST    (1u << 3)
// an endpoint's registers
#define EPCFG(n)       UREG8(0x100u + 0x20u * (n))
#define EPSTATUSCLR(n) UREG8(0x104u + 0x20u * (n))
#define EPSTATUSSET(n) UREG8(0x105u + 0x20u * (n))
#define EPINTFLAG(n)   UREG8(0x107u + 0x20u * (n))
#define DTGLOUT  (1u << 0)
#define DTGLIN   (1u << 1)
#define STALLRQ0 (1u << 4)
#define STALLRQ1 (1u << 5)
#define BK0RDY   (1u << 6)
#define BK1RDY   (1u << 7)
#define TRCPT0   (1u << 0)
#define TRCPT1   (1u << 1)
#define RXSTP    (1u << 4)
#define PK64     (3u << 28)

// endpoints 0 to 3, each a bank out and a bank in
struct bank { uint8_t *addr; uint32_t pck; uint16_t ext; uint8_t st; uint8_t pad[5]; };
static struct bank desc[4][2] __attribute__((aligned(4)));
static uint8_t e0o[ucdc_pkt] __attribute__((aligned(4))), e0i[ucdc_pkt] __attribute__((aligned(4)));
static uint8_t rx2[ucdc_pkt] __attribute__((aligned(4))), tx2b[ucdc_pkt] __attribute__((aligned(4)));

static uint8_t const *e0p;
static uint32_t e0n, e0addr, e0want;
struct tx { uint8_t b[ucdc_tx]; uint8_t const *p; uint32_t n, last, on; };
static struct tx tx2;

// bank 1 holds m bytes in; bank 0 waits for up to m out
static void inq(uint32_t ep, uint8_t *buf, uint32_t m) {
  desc[ep][1].addr = buf, desc[ep][1].pck = PK64 | m;
  EPSTATUSSET(ep) = BK1RDY; }
static void outq(uint32_t ep, uint8_t *buf, uint32_t m) {
  desc[ep][0].addr = buf, desc[ep][0].pck = PK64 | m << 14;
  EPSTATUSCLR(ep) = BK0RDY; }

static void e0next(void) {
  uint32_t const m = e0n < ucdc_pkt ? e0n : ucdc_pkt;
  for (uint32_t i = 0; i < m; i++) e0i[i] = e0p[i];
  e0p += m, e0n -= m;
  inq(0, e0i, m);
  if (!e0n) outq(0, e0o, 0); }

static void usbhw_ep0_in(void const *src, uint32_t n) { e0p = src, e0n = n; e0next(); }

static void usbhw_ep0_ack(void) { inq(0, e0i, 0); }

static void usbhw_ep0_out(uint32_t n) { e0want = n; outq(0, e0o, n); }

static void usbhw_ep0_stall(void) { EPSTATUSSET(0) = STALLRQ0 | STALLRQ1; }

// the address takes after its status stage goes in
static void usbhw_address(uint32_t a) { e0addr = a | 0x100u; }

static void usbhw_open(void) {
  EPCFG(2) = 3u | 3u << 4;                         // bulk out, bulk in
  EPCFG(3) = 4u << 4;                              // interrupt in
  EPSTATUSCLR(2) = DTGLOUT | DTGLIN | STALLRQ0 | STALLRQ1;
  EPSTATUSCLR(3) = DTGLIN | STALLRQ1;
  EPSTATUSCLR(2) = BK1RDY;
  tx2.on = 0; }

static void usbhw_clear_halt(uint32_t ep) {
  uint32_t const n = ep & 0x7Fu;
  if (n == 2 || n == 3) EPSTATUSCLR(n) = ep & 0x80u ? DTGLIN | STALLRQ1 : DTGLOUT | STALLRQ0; }

static void usbhw_rx_arm(void) { outq(2, rx2, ucdc_pkt); }

static void txnext(struct tx *t) {
  uint32_t const m = t->n < ucdc_pkt ? t->n : ucdc_pkt;
  for (uint32_t i = 0; i < m; i++) tx2b[i] = t->p[i];
  t->p += m, t->n -= m, t->last = m;
  inq(2, tx2b, m); }

// the class fills its buffer again once this returns, so the send goes from a copy
static void usbhw_tx(void const *src, uint32_t n) {
  for (uint32_t i = 0; i < n; i++) tx2.b[i] = ((uint8_t const *) src)[i];
  tx2.p = tx2.b, tx2.n = n, tx2.on = 1;
  txnext(&tx2); }

// a packet in landed: the rest, then a zero packet after a full one
static void txdone(struct tx *t) {
  if (t->n) txnext(t);
  else if (t->last == ucdc_pkt) t->last = 0, inq(2, tx2b, 0);
  else t->on = 0; }

void usb_poll(void);
static int usbhw_tx_busy(void) { usb_poll(); return (int) tx2.on; }

static uint32_t usbhw_ms(void) { return clock_ms(); }

static void usbhw_reboot(void) { boot_loader(); }

static void ep0_reset(void) {
  EPCFG(0) = 1u | 1u << 4;                         // control, both banks
  desc[0][0].addr = e0o, desc[0][0].pck = PK64 | 8u << 14;
  desc[0][1].addr = e0i, desc[0][1].pck = PK64;
  EPSTATUSCLR(0) = BK0RDY | BK1RDY | STALLRQ0 | STALLRQ1; }

void usb_poll(void) {
  (void) clock_ms();
  wdt_feed();
  if (UREG16(INTFLAG) & EORST) {
    UREG16(INTFLAG) = EORST;
    UREG8(DADD) = 0;
    e0n = 0, e0addr = 0, e0want = 0, tx2.on = 0;
    ep0_reset();
    ucdc_reset(); }
  uint8_t const f0 = EPINTFLAG(0);
  if (f0 & RXSTP) {
    EPINTFLAG(0) = RXSTP | TRCPT0 | TRCPT1;
    EPSTATUSCLR(0) = BK1RDY | STALLRQ0 | STALLRQ1;
    e0n = 0, e0want = 0;
    uint32_t const s0 = e0o[0] | e0o[1] << 8 | e0o[2] << 16 | (uint32_t) e0o[3] << 24;
    uint32_t const s1 = e0o[4] | e0o[5] << 8 | e0o[6] << 16 | (uint32_t) e0o[7] << 24;
    ucdc_setup(s0, s1);
    return; }
  if (f0 & TRCPT1) {                               // 0 in
    EPINTFLAG(0) = TRCPT1;
    if (e0n) e0next();
    if (e0addr & 0x100u) UREG8(DADD) = 0x80u | (e0addr & 0x7Fu), e0addr = 0; }
  if (f0 & TRCPT0) {                               // 0 out: a data stage, or a status
    EPINTFLAG(0) = TRCPT0;
    if (e0want) {
      uint32_t const n = desc[0][0].pck & 0x3FFFu;
      e0want = 0;
      ucdc_ep0_out(e0o, n);
      usbhw_ep0_ack(); } }
  uint8_t const f2 = EPINTFLAG(2);
  if (f2 & TRCPT0) EPINTFLAG(2) = TRCPT0, ucdc_rx(rx2, desc[2][0].pck & 0x3FFFu);   // 2 out
  if (f2 & TRCPT1) EPINTFLAG(2) = TRCPT1, txdone(&tx2);                              // 2 in
}

// the serial the chip's; the controller reset, which drops the bootloader's pullup, and long
// enough off the bus for the host to see it go. its pads on pa24/pa25 (function g), its
// calibration out of nvm, then attached at full speed
void usb_init(void) {
  uint32_t id[4];
  chip_uid(id);
  for (uint32_t i = 0; i < 32; i++) serial[i] = "0123456789ABCDEF"[id[i / 8] >> (28 - 4 * (i & 7)) & 15u];
  REG(PM_AHBMASK) |= AHB_USB;
  REG(PM_APBBMASK) |= APBB_USB;
  REG16(GCLK_CLKCTRL) = CLK_ID_USB | 0u << 8 | CLK_CLKEN;
  REG8(PORTA_PMUX(12)) = 0x66u;
  REG8(PORTA_PINCFG(24)) |= 1u;
  REG8(PORTA_PINCFG(25)) |= 1u;
  UREG8(CTRLA) = 1u;
  while (UREG8(SYNCBUSY) & 1u) {}
  for (uint32_t t = clock_ms(); clock_ms() - t < 200u; ) wdt_feed();
  uint32_t const c = REG(NVM_CAL1);
  uint32_t n = c >> 13 & 31u, p = c >> 18 & 31u, r = c >> 23 & 7u;
  if (n == 31u) n = 5u;
  if (p == 31u) p = 29u;
  if (r == 7u) r = 3u;
  UREG16(PADCAL) = (uint16_t) (p | n << 6 | r << 12);
  UREG(DESCADD) = (uint32_t) (uintptr_t) desc;
  UREG8(CTRLA) = 2u;                               // enable, device mode
  while (UREG8(SYNCBUSY) & 2u) {}
  ep0_reset();
  UREG16(CTRLB) = 0; }                             // full speed, attached
