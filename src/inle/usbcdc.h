// a USB CDC-ACM console's class half, for any board's device controller: the descriptors,
// endpoint 0's requests, the line state and both byte paths. the controller includes this
// after naming UCDC_VID, UCDC_PID and UCDC_PRODUCT, defines the usbhw_ hooks, and calls
// ucdc_setup, ucdc_ep0_out, ucdc_rx and ucdc_reset from its interrupt. endpoint 2 bulk both
// ways is the data; 3 in is the notification the class asks for, never sent. bytes go out
// only while a host holds DTR, so a port nobody opened never stalls the console.
// UCDC_ECM adds cdc-ecm beside it, a composite: interfaces 2 and 3 an ethernet link, its
// notification on 4 in and its frames on 5 bulk both ways (see the ECM half below)
#include <stdint.h>

enum { ucdc_pkt = 64, ucdc_tx = 1024, ucdc_rxn = 4096 };   // ucdc_rxn a power of two

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
#ifdef UCDC_ECM
static void usbhw_ecm_open(void);                       // endpoints 4 and 5, on alternate setting 1
static void usbhw_ecm_rx_arm(void);                     // a packet out of endpoint 5, then ucdc_ecm_rx
static void usbhw_ecm_tx(void const *src, uint32_t n);  // n bytes in on endpoint 5
static int usbhw_ecm_tx_busy(void);
static void usbhw_ecm_notify(void const *src, uint32_t n);   // in on endpoint 4
#endif

#ifndef UCDC_ECM
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
#else
// a composite of two functions, each under an interface association
static uint8_t const ucdc_dev[18] = {
  18, 1, 0x00, 0x02, 0xEF, 2, 1, ucdc_pkt, UCDC_VID & 0xFF, UCDC_VID >> 8, UCDC_PID & 0xFF, UCDC_PID >> 8,
  0x00, 0x01, 1, 2, 3, 1 };
static uint8_t const ucdc_cfg[154] = {
  9, 2, 154, 0, 4, 1, 0, 0x80, 50,
  8, 0x0B, 0, 2, 2, 2, 1, 0,
  9, 4, 0, 0, 1, 2, 2, 1, 0,
  5, 0x24, 0x00, 0x10, 0x01,
  5, 0x24, 0x01, 0x01, 0x01,
  4, 0x24, 0x02, 0x06,
  5, 0x24, 0x06, 0, 1,
  7, 5, 0x83, 3, 16, 0, 64,
  9, 4, 1, 0, 2, 0x0A, 0, 0, 0,
  7, 5, 0x02, 2, ucdc_pkt, 0, 0,
  7, 5, 0x82, 2, ucdc_pkt, 0, 0,
  8, 0x0B, 2, 2, 2, 6, 0, 0,
  9, 4, 2, 0, 1, 2, 6, 0, 0,
  5, 0x24, 0x00, 0x10, 0x01,
  5, 0x24, 0x06, 2, 3,
  13, 0x24, 0x0F, 4, 0, 0, 0, 0, 0xEA, 0x05, 0, 0, 0,            // the host's mac string 4, 1514 a frame
  7, 5, 0x84, 3, 16, 0, 32,
  9, 4, 3, 0, 0, 0x0A, 0, 0, 0,                                  // alternate 0: no endpoints, the link down
  9, 4, 3, 1, 2, 0x0A, 0, 0, 0,
  7, 5, 0x05, 2, ucdc_pkt, 0, 0,
  7, 5, 0x85, 2, ucdc_pkt, 0, 0 };
static char ucdc_mac[13] = "020000000001";   // the host's end, twelve hex digits; the controller may set it
static char const *const ucdc_str[5] = { 0, "love", UCDC_PRODUCT, "1", ucdc_mac };
#endif

static volatile uint32_t ucdc_cfgd, ucdc_dtr, ucdc_lc_wanted, ucdc_parked, ucdc_boot;
static uint8_t ucdc_lc[7] = { 0x00, 0xC2, 0x01, 0x00, 0x00, 0x00, 0x08 };   // 115200 8N1
static uint8_t ucdc_txb[ucdc_tx];
static uint32_t ucdc_txn;
static volatile uint8_t ucdc_ring[ucdc_rxn];
static volatile uint32_t ucdc_w, ucdc_r;

static void ucdc_send(void const *src, uint32_t n, uint32_t want) { usbhw_ep0_in(src, n < want ? n : want); }

// a bus reset: unconfigured, nobody listening
static void ucdc_ecm_reset(void);
static void ucdc_reset(void) { ucdc_cfgd = 0, ucdc_dtr = 0, ucdc_lc_wanted = 0, ucdc_ecm_reset(); }
static int ucdc_ecm_setup(uint32_t req, uint32_t val, uint32_t idx, uint32_t len);

static void ucdc_setup(uint32_t s0, uint32_t s1) {
  uint32_t const req = s0 & 0xFFFFu, val = s0 >> 16, idx = s1 & 0xFFFFu, len = s1 >> 16;
  uint8_t b[64];
  ucdc_lc_wanted = 0;
  if (ucdc_ecm_setup(req, val, idx, len)) return;
  switch (req) {
  case 0x0500: usbhw_address(val & 0x7F); usbhw_ep0_ack(); return;          // set address
  case 0x0900:                                                               // set configuration
    ucdc_cfgd = 0, ucdc_dtr = 0, ucdc_ecm_reset();
    if (val == 1) usbhw_open(), ucdc_parked = 0, usbhw_rx_arm(), ucdc_cfgd = 1;
    usbhw_ep0_ack(); return;
  case 0x0880: b[0] = (uint8_t) ucdc_cfgd; ucdc_send(b, 1, len); return;
  case 0x0080: case 0x0081: case 0x0082: b[0] = b[1] = 0; ucdc_send(b, 2, len); return;
  case 0x0102: usbhw_clear_halt(idx & 0xFF); usbhw_ep0_ack(); return;       // clear halt
  case 0x0302: case 0x0100: case 0x0300: usbhw_ep0_ack(); return;
  case 0x0680: case 0x0681:
    if (val >> 8 == 1) { ucdc_send(ucdc_dev, sizeof ucdc_dev, len); return; }
    if (val >> 8 == 2) { ucdc_send(ucdc_cfg, sizeof ucdc_cfg, len); return; }
    if (val >> 8 == 3 && (val & 0xFF) < sizeof ucdc_str / sizeof *ucdc_str) {
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
  for (uint32_t i = 0; i < n && ucdc_w - ucdc_r < sizeof ucdc_ring; i++) ucdc_ring[ucdc_w++ & (ucdc_rxn - 1)] = src[i];
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

// a host has the port open: configured, DTR up
int usb_up(void) { return ucdc_up(); }

int usb_rx_ready(void) {
  if (ucdc_boot && usbhw_ms() - ucdc_boot > 50) usbhw_reboot();
  return ucdc_w != ucdc_r; }

// a parked endpoint is armed again here; the interrupt stands off it until then
int usb_getc(void) {
  while (ucdc_w == ucdc_r) {}
  int c = ucdc_ring[ucdc_r++ & (ucdc_rxn - 1)];
  if (ucdc_parked && sizeof ucdc_ring - (ucdc_w - ucdc_r) >= ucdc_pkt) ucdc_parked = 0, usbhw_rx_arm();
  return c; }

#ifndef UCDC_ECM
static void ucdc_ecm_reset(void) {}
static int ucdc_ecm_setup(uint32_t req, uint32_t val, uint32_t idx, uint32_t len) {
  (void) req, (void) val, (void) idx, (void) len; return 0; }
#else
// --- the ECM half: ethernet frames over endpoint 5, each ended by a short packet. a frame in
// lands in a ring of whole frames, read as a stream of records, two bytes of length (high
// first) then the frame; a stream written the same way goes out a record at a time. a frame
// a whole number of packets long gets a byte of pad, so no zero-length packet is owed
enum { uecm_mtu = 1536, uecm_slots = 8 };   // uecm_slots a power of two
static volatile uint32_t uecm_alt;
static uint8_t uecm_rf[uecm_slots][uecm_mtu];
static volatile uint32_t uecm_rl[uecm_slots], uecm_w, uecm_r, uecm_parked;
static uint32_t uecm_in, uecm_bad, uecm_off;       // the frame landing, a too-long one's skip, the record's read point
static uint8_t uecm_tf[2 + uecm_mtu];
static uint32_t uecm_tn;                           // bytes of the record being written
static uint8_t const uecm_up[8] = { 0xA1, 0x00, 1, 0, 2, 0, 0, 0 };   // network connection: connected

static void ucdc_ecm_reset(void) { uecm_alt = 0, uecm_in = 0, uecm_bad = 0; }

static int ucdc_ecm_setup(uint32_t req, uint32_t val, uint32_t idx, uint32_t len) {
  uint8_t b[1];
  switch (req) {
  case 0x0B01:                                                               // set interface
    if (idx != 3) return usbhw_ep0_ack(), 1;
    uecm_alt = 0;
    if (val == 1) usbhw_ecm_open(), uecm_in = 0, uecm_bad = 0, uecm_parked = 0,
                  usbhw_ecm_rx_arm(), uecm_alt = 1;
    usbhw_ep0_ack();
    if (uecm_alt) usbhw_ecm_notify(uecm_up, sizeof uecm_up);
    return 1;
  case 0x0A81: b[0] = idx == 3 ? (uint8_t) uecm_alt : 0; ucdc_send(b, 1, len); return 1;   // get interface
  case 0x4021: case 0x4121: case 0x4321: case 0x4421: usbhw_ep0_ack(); return 1; }   // the filters
  return 0; }

// a packet in on endpoint 5: a short one ends the frame
static void ucdc_ecm_rx(uint8_t const *src, uint32_t n) {
  uint8_t *f = uecm_rf[uecm_w & (uecm_slots - 1)];
  if (uecm_in + n > uecm_mtu) uecm_bad = 1;
  else for (uint32_t i = 0; i < n; i++) f[uecm_in + i] = src[i];
  uecm_in += n;
  if (n == ucdc_pkt) { usbhw_ecm_rx_arm(); return; }
  if (!uecm_bad && uecm_in >= 14) uecm_rl[uecm_w & (uecm_slots - 1)] = uecm_in, uecm_w++;
  uecm_in = 0, uecm_bad = 0;
  if (uecm_w - uecm_r < uecm_slots) usbhw_ecm_rx_arm();
  else uecm_parked = 1; }

int usb_ecm_up(void) { return ucdc_cfgd && uecm_alt; }
int usb_ecm_ready(void) { return uecm_w != uecm_r; }

// up to n bytes of the records waiting; 0 when none
uint32_t usb_ecm_read(uint8_t *dst, uint32_t n) {
  uint32_t k = 0;
  while (k < n && uecm_w != uecm_r) {
    uint32_t s = uecm_r & (uecm_slots - 1), l = uecm_rl[s];
    for (; k < n && uecm_off < 2 + l; uecm_off++)
      dst[k++] = uecm_off == 0 ? (uint8_t) (l >> 8) : uecm_off == 1 ? (uint8_t) l : uecm_rf[s][uecm_off - 2];
    if (uecm_off == 2 + l) {
      uecm_off = 0, uecm_r++;
      if (uecm_parked) uecm_parked = 0, usbhw_ecm_rx_arm(); } }
  return k; }

// a whole record out, once endpoint 5 is free; 1 sent or nothing held, 0 still held
static int uecm_send(void) {
  uint32_t l = uecm_tn < 2 ? 0 : (uint32_t) uecm_tf[0] << 8 | uecm_tf[1];
  if (uecm_tn < 2 || uecm_tn < 2 + l) return 1;
  if (!usb_ecm_up()) return uecm_tn = 0, 1;
  if (usbhw_ecm_tx_busy()) return 0;
  if (l % ucdc_pkt == 0) uecm_tf[2 + l++] = 0;
  usbhw_ecm_tx(uecm_tf + 2, l);
  uecm_tn = 0;
  return 1; }

// bytes of records taken, up to n; 0 while a whole one waits on the endpoint. a length past
// the mtu drops the stream's framing, so the record is cut there
uint32_t usb_ecm_write(uint8_t const *src, uint32_t n) {
  uint32_t k = 0;
  while (k < n) {
    if (!uecm_send()) return k;
    uecm_tf[uecm_tn++] = src[k++];
    if (uecm_tn == 2 && ((uint32_t) uecm_tf[0] << 8 | uecm_tf[1]) > uecm_mtu - 1) uecm_tn = 0; }
  uecm_send();
  return k; }

// the timer's: a record held on a busy endpoint goes once it frees
void usb_ecm_tick(void) { uecm_send(); }
#endif
