// the pi's otg port as its console: the bcm2835's synopsys dwc2 held in device mode at full
// speed, its fifos moved by the core (no dma), under ../usbcdc.h's cdc-acm class. its
// interrupt takes bus resets, setups and packets out; packets in are queued by the flush
#include <stdint.h>
#include "k.h"
#include "../../mmio.h"

int k_mbox(uint32_t tag, uint32_t *v, int nv);   // arch.c
void k_reset(void);
#define UCDC_VID 0x1D6B
#define UCDC_PID 0x0104
#define UCDC_PRODUCT "inle pi"
#include "../../usbcdc.h"

#define OTG  (0x3f000000 + 0x980000)

#define GAHBCFG   0x008
#define GUSBCFG   0x00c
#define GRSTCTL   0x010
#define GINTSTS   0x014
#define GINTMSK   0x018
#define GRXSTSP   0x020
#define GRXFSIZ   0x024
#define GNPTXFSIZ 0x028
#define DIEPTXF(n) (0x100 + 4 * (n))
#define DCFG      0x800
#define DCTL      0x804
#define DIEPMSK   0x810
#define DOEPMSK   0x814
#define DAINT     0x818
#define DAINTMSK  0x81c
#define DIEPCTL(n) (0x900 + 0x20 * (n))
#define DIEPINT(n) (0x908 + 0x20 * (n))
#define DIEPTSIZ(n) (0x910 + 0x20 * (n))
#define DTXFSTS(n) (0x918 + 0x20 * (n))
#define DOEPCTL(n) (0xb00 + 0x20 * (n))
#define DOEPINT(n) (0xb08 + 0x20 * (n))
#define DOEPTSIZ(n) (0xb10 + 0x20 * (n))
#define FIFO(n)   (0x1000 * ((n) + 1))

#define RST_CORE  (1u << 0)
#define RST_RXF   (1u << 4)
#define RST_TXF   (1u << 5)
#define RST_IDLE  (1u << 31)
#define INT_RXF   (1u << 4)
#define INT_RESET (1u << 12)
#define INT_ENUM  (1u << 13)
#define INT_IEP   (1u << 18)
#define INT_OEP   (1u << 19)
#define EP_ENA    (1u << 31)
#define EP_SNAK   (1u << 27)
#define EP_CNAK   (1u << 26)
#define EP_STALL  (1u << 21)
#define EP_D0PID  (1u << 28)
#define EP_ACTIVE (1u << 15)
#define EI_DONE   (1u << 0)
#define EO_SETUP  (1u << 3)

static uint32_t setup[2], ep0n, rxn;
static uint8_t ep0buf[64], rxbuf[64];

static uint32_t usbhw_ms(void) { return (uint32_t) (kticks * 10); }
static void wait_ms(uint32_t ms) { uint32_t t = usbhw_ms(); while (usbhw_ms() - t < ms) {} }

// bytes into an in endpoint's fifo, a word at a time once it has the room
static void fifo_put(uint32_t ep, void const *src, uint32_t n) {
  uint8_t const *s = src;
  uint32_t w = (n + 3) / 4;
  for (uint32_t k = 0; (mmio_rd(OTG, DTXFSTS(ep)) & 0xffff) < w; k++) if (k > 1000000u) return;
  for (uint32_t i = 0; i < n; i += 4) {
    uint32_t v = 0;
    for (uint32_t b = 0; b < 4 && i + b < n; b++) v |= (uint32_t) s[i + b] << 8 * b;
    mmio_wr(OTG, FIFO(ep), v); } }
static void fifo_get(uint8_t *dst, uint32_t n, uint32_t cap) {
  for (uint32_t i = 0; i < n; i += 4) {
    uint32_t v = mmio_rd(OTG, FIFO(0));
    for (uint32_t b = 0; b < 4 && i + b < n; b++) if (i + b < cap) dst[i + b] = (uint8_t) (v >> 8 * b); } }

// endpoint 0 out, ready for the next setup (three back to back) and a packet of data or status
static void ep0_arm(void) {
  mmio_wr(OTG, DOEPTSIZ(0), 3u << 29 | 1u << 19 | 64);
  mmio_wr(OTG, DOEPCTL(0), mmio_rd(OTG, DOEPCTL(0)) | EP_ENA | EP_CNAK); }

static void in_send(uint32_t ep, void const *src, uint32_t n, uint32_t mps) {
  uint32_t pk = n ? (n + mps - 1) / mps : 1;
  mmio_wr(OTG, DIEPTSIZ(ep), pk << 19 | n);
  mmio_wr(OTG, DIEPCTL(ep), mmio_rd(OTG, DIEPCTL(ep)) | EP_ENA | EP_CNAK);
  if (n) fifo_put(ep, src, n); }

static void usbhw_ep0_ack(void) { in_send(0, 0, 0, 64); }

static void usbhw_ep0_in(void const *src, uint32_t n) { in_send(0, src, n, 64); ep0_arm(); }

static void usbhw_ep0_out(uint32_t n) { ep0n = n; ep0_arm(); usbhw_ep0_ack(); }

static void usbhw_ep0_stall(void) {
  mmio_wr(OTG, DIEPCTL(0), mmio_rd(OTG, DIEPCTL(0)) | EP_STALL);
  mmio_wr(OTG, DOEPCTL(0), mmio_rd(OTG, DOEPCTL(0)) | EP_STALL);
  ep0_arm(); }

// dwc2 answers the status stage at the old address, so the new one goes in at once
static void usbhw_address(uint32_t a) {
  mmio_wr(OTG, DCFG, (mmio_rd(OTG, DCFG) & ~(0x7fu << 4)) | a << 4); }

// 2 out and in bulk (2 its fifo), 3 in interrupt (3 its fifo); bulk = 2, interrupt = 3
static void usbhw_open(void) {
  mmio_wr(OTG, DOEPCTL(2), EP_ACTIVE | 2u << 18 | ucdc_pkt | EP_D0PID | EP_SNAK);
  mmio_wr(OTG, DIEPCTL(2), EP_ACTIVE | 2u << 18 | ucdc_pkt | 2u << 22 | EP_D0PID | EP_SNAK);
  mmio_wr(OTG, DIEPCTL(3), EP_ACTIVE | 3u << 18 | 16 | 3u << 22 | EP_D0PID | EP_SNAK);
  mmio_wr(OTG, DAINTMSK, mmio_rd(OTG, DAINTMSK) | 1u << 2 | 1u << 18); }

static void usbhw_clear_halt(uint32_t ep) {
  uint32_t n = ep & 0x7f, r = ep & 0x80 ? DIEPCTL(n) : DOEPCTL(n);
  if (n == 2 || n == 3) mmio_wr(OTG, r, (mmio_rd(OTG, r) & ~EP_STALL) | EP_D0PID); }

static void usbhw_rx_arm(void) {
  mmio_wr(OTG, DOEPTSIZ(2), 1u << 19 | ucdc_pkt);
  mmio_wr(OTG, DOEPCTL(2), mmio_rd(OTG, DOEPCTL(2)) | EP_ENA | EP_CNAK); }

static int usbhw_tx_busy(void) { return (mmio_rd(OTG, DIEPCTL(2)) & EP_ENA) != 0; }

static void usbhw_tx(void const *src, uint32_t n) { in_send(2, src, n, ucdc_pkt); }

// the loaders' 134 baud: the pi's loader is the firmware, so a reset is the nearest
static void usbhw_reboot(void) { k_reset(); }

static void bus_reset(void) {
  mmio_wr(OTG, GRSTCTL, RST_TXF | 0x10u << 6);
  for (uint32_t k = 0; mmio_rd(OTG, GRSTCTL) & RST_TXF; k++) if (k > 1000000u) break;
  mmio_wr(OTG, GRSTCTL, RST_RXF);
  for (uint32_t k = 0; mmio_rd(OTG, GRSTCTL) & RST_RXF; k++) if (k > 1000000u) break;
  for (int n = 0; n < 4; n++) mmio_wr(OTG, DOEPCTL(n), mmio_rd(OTG, DOEPCTL(n)) | EP_SNAK);
  mmio_wr(OTG, DAINTMSK, 1u | 1u << 16);
  mmio_wr(OTG, DCFG, mmio_rd(OTG, DCFG) & ~(0x7fu << 4));
  ucdc_reset(); }

// from k_irq on the gpu's usb line
void usb_irq(void) {
  uint32_t s = mmio_rd(OTG, GINTSTS) & mmio_rd(OTG, GINTMSK);
  if (s & INT_RESET) mmio_wr(OTG, GINTSTS, INT_RESET), bus_reset();
  if (s & INT_ENUM) {
    mmio_wr(OTG, GINTSTS, INT_ENUM);
    mmio_wr(OTG, DIEPCTL(0), mmio_rd(OTG, DIEPCTL(0)) & ~3u);   // max packet 64
    ep0_arm(); }
  // the receive fifo: a setup's eight bytes, a packet's data; the rest are markers
  for (uint32_t k = 0; (mmio_rd(OTG, GINTSTS) & INT_RXF) && k < 64; k++) {
    uint32_t r = mmio_rd(OTG, GRXSTSP), ep = r & 15, n = r >> 4 & 0x7ff, st = r >> 17 & 15;
    if (st == 6) fifo_get((uint8_t *) setup, n, 8);
    else if (st == 2 && ep == 0) fifo_get(ep0buf, n, sizeof ep0buf), ep0n = n < ep0n ? n : ep0n;
    else if (st == 2 && ep == 2) fifo_get(rxbuf, n, sizeof rxbuf), rxn = n;
    else if (st == 2) fifo_get(0, n, 0); }
  uint32_t a = mmio_rd(OTG, DAINT);
  for (uint32_t ep = 0; ep < 4; ep++) {
    if (a & 1u << ep) mmio_wr(OTG, DIEPINT(ep), mmio_rd(OTG, DIEPINT(ep)));
    if (!(a & 1u << (16 + ep))) continue;
    uint32_t o = mmio_rd(OTG, DOEPINT(ep));
    mmio_wr(OTG, DOEPINT(ep), o);
    if (ep == 0 && o & EO_SETUP) ep0n = 0, ucdc_setup(setup[0], setup[1]);
    else if (ep == 0 && o & EI_DONE) { if (ep0n) ucdc_ep0_out(ep0buf, ep0n), ep0n = 0; ep0_arm(); }
    else if (ep == 2 && o & EI_DONE) ucdc_rx(rxbuf, rxn); } }

// the timer's: staged bytes out without waiting, so a prompt with no newline still shows
void usb_tick(void) { if (ucdc_txn && ucdc_up() && !usbhw_tx_busy()) usbhw_tx(ucdc_txb, ucdc_txn), ucdc_txn = 0; }

// power from the firmware, the core reset and forced to device, the fifos laid, connect.
// 0 when the controller never came up
int usb_init(void) {
  uint32_t pw[2] = { 3, 3 };                         // the usb hcd domain: on, and wait
  if (k_mbox(0x00028001, pw, 2) || !(pw[1] & 1)) return 0;
  uint32_t k = 0;
  while (!(mmio_rd(OTG, GRSTCTL) & RST_IDLE)) if (++k > 1000000u) return 0;
  mmio_wr(OTG, GRSTCTL, RST_CORE);
  for (k = 0; mmio_rd(OTG, GRSTCTL) & RST_CORE; k++) if (k > 1000000u) return 0;
  wait_ms(10);
  // the internal utmi+ phy, 8 bits wide (turnaround 5), forced to device
  uint32_t u = mmio_rd(OTG, GUSBCFG) & ~(1u << 29 | 0xfu << 10 | 1u << 6 | 1u << 4 | 1u << 3);
  mmio_wr(OTG, GUSBCFG, u | 5u << 10 | 1u << 30);
  wait_ms(50);
  mmio_wr(OTG, DCTL, mmio_rd(OTG, DCTL) | 1u << 1);   // soft disconnect while laid out
  mmio_wr(OTG, DCFG, (mmio_rd(OTG, DCFG) & ~3u) | 1u); // full speed: 64-byte bulk is legal
  // words: rx 256, ep0 64, ep2 256, ep3 16
  mmio_wr(OTG, GRXFSIZ, 256);
  mmio_wr(OTG, GNPTXFSIZ, 64u << 16 | 256);
  mmio_wr(OTG, DIEPTXF(1), 16u << 16 | 320);
  mmio_wr(OTG, DIEPTXF(2), 256u << 16 | 336);
  mmio_wr(OTG, DIEPTXF(3), 16u << 16 | 592);
  bus_reset();
  mmio_wr(OTG, DIEPMSK, 1u | 1u << 3);
  mmio_wr(OTG, DOEPMSK, 1u | 1u << 3);
  mmio_wr(OTG, GINTSTS, 0xffffffffu);
  mmio_wr(OTG, GINTMSK, INT_RXF | INT_RESET | INT_ENUM | INT_IEP | INT_OEP);
  mmio_wr(OTG, GAHBCFG, 1u);                         // the interrupt line on, no dma
  mmio_wr(OTG, DCTL, mmio_rd(OTG, DCTL) & ~(1u << 1));
  return 1; }
