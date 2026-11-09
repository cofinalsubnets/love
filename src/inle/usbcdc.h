// a USB CDC-ACM console's class half, for any board's device controller: the descriptors,
// endpoint 0's requests, the line state and both byte paths. the controller includes this
// after naming UCDC_VID, UCDC_PID and UCDC_PRODUCT, defines the usbhw_ hooks, and calls
// ucdc_setup, ucdc_ep0_out, ucdc_rx and ucdc_reset from its interrupt. endpoint 2 bulk both
// ways is the data; 3 in is the notification the class asks for, never sent. bytes go out
// only while a host holds DTR, so a port nobody opened never stalls the console
#include <stdint.h>

enum { ucdc_pkt = 64, ucdc_tx = 1024 };

// the controller's: control transfers on endpoint 0, then the data endpoints
static void usbhw_ep0_in(void const *src, uint32_t n);   // n bytes in (n may be 0), status out
static void usbhw_ep0_out(uint32_t n);                   // n bytes out, then ucdc_ep0_out; status in
static void usbhw_ep0_ack(void);                         // the status stage in
static void usbhw_ep0_stall(void);
static void usbhw_address(uint32_t a);
static void usbhw_open(void);                            // endpoints 2 and 3, on set configuration
static void usbhw_clear_halt(uint32_t ep);               // 0x82 style
static void usbhw_rx_arm(void);                          // a packet out of endpoint 2, then ucdc_rx
static void usbhw_tx(void const *src, uint32_t n);       // n bytes in on endpoint 2
static int usbhw_tx_busy(void);
static uint32_t usbhw_ms(void);
static void usbhw_reboot(void);                         // into the board's bootloader

static uint8_t const ucdc_dev[18] = {
  18, 1, 0x00, 0x02, 2, 0, 0, ucdc_pkt, UCDC_VID & 0xFF, UCDC_VID >> 8, UCDC_PID & 0xFF, UCDC_PID >> 8,
  0x00, 0x01, 1, 2, 3, 1 };
static uint8_t const ucdc_cfg[67] = {
  9, 2, 67, 0, 2, 1, 0, 0x80, 50,
  9, 4, 0, 0, 1, 2, 2, 1, 0,
  5, 0x24, 0x00, 0x10, 0x01,
  5, 0x24, 0x01, 0x01, 0x01,
  4, 0x24, 0x02, 0x06,
  5, 0x24, 0x06, 0, 1,
  7, 5, 0x83, 3, 16, 0, 64,
  9, 4, 1, 0, 2, 0x0A, 0, 0, 0,
  7, 5, 0x02, 2, ucdc_pkt, 0, 0,
  7, 5, 0x82, 2, ucdc_pkt, 0, 0 };
static char const *const ucdc_str[4] = { 0, "love", UCDC_PRODUCT, "1" };

static volatile uint32_t ucdc_cfgd, ucdc_dtr, ucdc_lc_wanted, ucdc_parked, ucdc_boot;
static uint8_t ucdc_lc[7] = { 0x00, 0xC2, 0x01, 0x00, 0x00, 0x00, 0x08 };   // 115200 8N1
static uint8_t ucdc_txb[ucdc_tx];
static uint32_t ucdc_txn;
static volatile uint8_t ucdc_ring[1024];
static volatile uint32_t ucdc_w, ucdc_r;

static void ucdc_send(void const *src, uint32_t n, uint32_t want) { usbhw_ep0_in(src, n < want ? n : want); }

// a bus reset: unconfigured, nobody listening
static void ucdc_reset(void) { ucdc_cfgd = 0, ucdc_dtr = 0, ucdc_lc_wanted = 0; }

static void ucdc_setup(uint32_t s0, uint32_t s1) {
  uint32_t const req = s0 & 0xFFFFu, val = s0 >> 16, idx = s1 & 0xFFFFu, len = s1 >> 16;
  uint8_t b[64];
  ucdc_lc_wanted = 0;
  switch (req) {
  case 0x0500: usbhw_address(val & 0x7F); usbhw_ep0_ack(); return;          // set address
  case 0x0900:                                                               // set configuration
    ucdc_cfgd = 0, ucdc_dtr = 0;
    if (val == 1) usbhw_open(), ucdc_parked = 0, usbhw_rx_arm(), ucdc_cfgd = 1;
    usbhw_ep0_ack(); return;
  case 0x0880: b[0] = (uint8_t) ucdc_cfgd; ucdc_send(b, 1, len); return;
  case 0x0080: case 0x0081: case 0x0082: b[0] = b[1] = 0; ucdc_send(b, 2, len); return;
  case 0x0102: usbhw_clear_halt(idx & 0xFF); usbhw_ep0_ack(); return;       // clear halt
  case 0x0302: case 0x0100: case 0x0300: usbhw_ep0_ack(); return;
  case 0x0680: case 0x0681:
    if (val >> 8 == 1) { ucdc_send(ucdc_dev, sizeof ucdc_dev, len); return; }
    if (val >> 8 == 2) { ucdc_send(ucdc_cfg, sizeof ucdc_cfg, len); return; }
    if (val >> 8 == 3 && (val & 0xFF) < 4) {
      uint32_t i = val & 0xFF, n = 2;
      if (!i) b[2] = 0x09, b[3] = 0x04, n = 4;
      else for (char const *c = ucdc_str[i]; *c && n < 62; c++) b[n++] = (uint8_t) *c, b[n++] = 0;
      b[0] = (uint8_t) n, b[1] = 3;
      ucdc_send(b, n, len); return; }
    break;
  case 0x2021: if (len == 7) { ucdc_lc_wanted = 1; usbhw_ep0_out(7); return; } break;   // set line coding
  case 0x21A1: ucdc_send(ucdc_lc, 7, len); return;                          // get line coding
  case 0x2221: ucdc_dtr = val & 1; usbhw_ep0_ack(); return;                 // control line state
  case 0x2321: usbhw_ep0_ack(); return; }                                   // send break
  usbhw_ep0_stall(); }

// endpoint 0's data out landed: a line coding
// 134 baud is the loaders' ask for the bootloader (teensy_loader_cli -s), taken once the
// status stage is out
static void ucdc_ep0_out(uint8_t const *src, uint32_t n) {
  if (ucdc_lc_wanted && n == 7) for (int i = 0; i < 7; i++) ucdc_lc[i] = src[i];
  if (ucdc_lc_wanted && n == 7 && (ucdc_lc[0] | ucdc_lc[1] << 8 | ucdc_lc[2] << 16 | (uint32_t) ucdc_lc[3] << 24) == 134)
    ucdc_boot = usbhw_ms() | 1;
  ucdc_lc_wanted = 0; }

// a packet in; the next is armed only while the ring holds a packet's room, else the host
// waits on a NAK until the reader makes it
static void ucdc_rx(uint8_t const *src, uint32_t n) {
  for (uint32_t i = 0; i < n && ucdc_w - ucdc_r < sizeof ucdc_ring; i++) ucdc_ring[ucdc_w++ & 1023u] = src[i];
  if (sizeof ucdc_ring - (ucdc_w - ucdc_r) >= ucdc_pkt) usbhw_rx_arm();
  else ucdc_parked = 1; }

static int ucdc_up(void) { return ucdc_cfgd && ucdc_dtr; }

// the staged bytes out; a host that stops reading for 100 ms loses them, not the console
void usb_flush(void) {
  if (!ucdc_txn) return;
  uint32_t t = usbhw_ms();
  while (ucdc_up() && usbhw_tx_busy())
    if (usbhw_ms() - t > 100) { ucdc_txn = 0; return; }
  if (ucdc_up()) usbhw_tx(ucdc_txb, ucdc_txn);
  ucdc_txn = 0; }

void usb_putc(int c) {
  if (!ucdc_up()) return;
  if (ucdc_txn == ucdc_tx) usb_flush();
  ucdc_txb[ucdc_txn++] = (uint8_t) c; }

int usb_rx_ready(void) {
  if (ucdc_boot && usbhw_ms() - ucdc_boot > 50) usbhw_reboot();
  return ucdc_w != ucdc_r; }

// a parked endpoint is armed again here; the interrupt stands off it until then
int usb_getc(void) {
  while (ucdc_w == ucdc_r) {}
  int c = ucdc_ring[ucdc_r++ & 1023u];
  if (ucdc_parked && sizeof ucdc_ring - (ucdc_w - ucdc_r) >= ucdc_pkt) ucdc_parked = 0, usbhw_rx_arm();
  return c; }
