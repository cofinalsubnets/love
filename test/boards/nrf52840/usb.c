// the nrf52840's usbd as a cdc-acm console, under ../../../src/inle/usbcdc.h's class half, at
// full speed and polled. bytes move between ram and an endpoint's own buffer by easydma, one
// move at a time, each waited out where it starts, and only from ram; the controller answers
// set address itself. an out endpoint takes its first packet once its size register is written,
// and the next by itself each time one moves out, so a packet the class has no room for waits in
// the endpoint, nak'ing the rest, until the class arms for it. a size write after the first
// would drop a packet already taken
#include <stdint.h>
#include "nrf52840.h"
#define UCDC_VID 0x1209
#define UCDC_PID 0x0001
#ifdef LOADER
#define UCDC_PRODUCT "love loader"
#else
#define UCDC_PRODUCT "love board"
#endif
static char serial[17];   // the chip's 64-bit device id in hex, set by usb_init
#define UCDC_SERIAL serial
#include "../../../src/inle/usbcdc.h"

#define U(o) REG(0x40027000u + (o))
#define TASKS_STARTEPIN(n)  U(0x004u + 4u * (n))
#define TASKS_STARTEPOUT(n) U(0x028u + 4u * (n))
#define TASKS_EP0RCVOUT     U(0x04Cu)
#define TASKS_EP0STATUS     U(0x050u)
#define TASKS_EP0STALL      U(0x054u)
#define EV_USBRESET         U(0x100u)
#define EV_ENDEPIN(n)       U(0x108u + 4u * (n))
#define EV_EP0DATADONE      U(0x128u)
#define EV_ENDEPOUT(n)      U(0x130u + 4u * (n))
#define EV_USBEVENT         U(0x158u)
#define EV_EP0SETUP         U(0x15Cu)
#define EV_EPDATA           U(0x160u)
#define EVENTCAUSE          U(0x400u)
#define EPDATASTATUS        U(0x46Cu)
#define SETUPB(i)           U(0x480u + 4u * (i))   // bmrequesttype .. wlengthh, a byte a word
#define SIZE_EPOUT(n)       U(0x4A0u + 4u * (n))
#define ENABLE              U(0x500u)
#define USBPULLUP           U(0x504u)
#define DTOGGLE             U(0x50Cu)
#define EPINEN              U(0x510u)
#define EPOUTEN             U(0x514u)
#define EPSTALL             U(0x518u)
#define EPIN_PTR(n)         U(0x600u + 0x14u * (n))
#define EPIN_MAXCNT(n)      U(0x604u + 0x14u * (n))
#define EPOUT_PTR(n)        U(0x700u + 0x14u * (n))
#define EPOUT_MAXCNT(n)     U(0x704u + 0x14u * (n))
#define EPOUT_AMOUNT(n)     U(0x708u + 0x14u * (n))
#define CAUSE_READY (1u << 11)
#define ERRATA199   0x40027C1Cu      // held while easydma moves an endpoint's bytes
#define ERRATA_KEY  0x4006EC00u      // unlocks the two below
#define ERRATA171   0x4006EC14u
#define ERRATA187   0x4006ED14u

static uint8_t e0b[ucdc_pkt] __attribute__((aligned(4)));
static uint8_t rx2[ucdc_pkt] __attribute__((aligned(4)));
static uint8_t const *e0p;
static uint32_t e0n, e0dir;          // the data stage: bytes still to go in, 1 in, 2 out, 0 none
static uint32_t rx2held, rx2armed;   // a packet waits in endpoint 2 out, the class has room for it
struct tx { uint8_t b[ucdc_tx] __attribute__((aligned(4))); uint8_t const *p; uint32_t n, last, on; };
static struct tx tx2;

// an errata register: a locked block opened around the write, one left open written as it is
static void errata(uint32_t a, uint32_t v) {
  if (!REG(ERRATA_KEY)) REG(ERRATA_KEY) = 0x9375u, REG(a) = v, REG(ERRATA_KEY) = 0x9375u;
  else REG(a) = v; }

static void din(uint32_t ep, void const *src, uint32_t n) {
  EPIN_PTR(ep) = (uint32_t) (uintptr_t) src, EPIN_MAXCNT(ep) = n;
  EV_ENDEPIN(ep) = 0;
  REG(ERRATA199) = 0x82u;
  TASKS_STARTEPIN(ep) = 1;
  while (!EV_ENDEPIN(ep)) {}
  REG(ERRATA199) = 0;
  EV_ENDEPIN(ep) = 0; }

static uint32_t dout(uint32_t ep, void *dst, uint32_t n) {
  EPOUT_PTR(ep) = (uint32_t) (uintptr_t) dst, EPOUT_MAXCNT(ep) = n;
  EV_ENDEPOUT(ep) = 0;
  REG(ERRATA199) = 0x82u;
  TASKS_STARTEPOUT(ep) = 1;
  while (!EV_ENDEPOUT(ep)) {}
  REG(ERRATA199) = 0;
  EV_ENDEPOUT(ep) = 0;
  return EPOUT_AMOUNT(ep); }

// a packet of the data stage into the endpoint, there for the host's next in
static void e0next(void) {
  uint32_t const m = e0n < ucdc_pkt ? e0n : ucdc_pkt;
  for (uint32_t i = 0; i < m; i++) e0b[i] = e0p[i];
  e0p += m, e0n -= m;
  din(0, e0b, m); }

static void usbhw_ep0_in(void const *src, uint32_t n) {
  if (!n) { TASKS_EP0STATUS = 1; return; }
  e0p = src, e0n = n, e0dir = 1;
  e0next(); }

static void usbhw_ep0_ack(void) { TASKS_EP0STATUS = 1; }

static void usbhw_ep0_out(uint32_t n) { (void) n; e0dir = 2; TASKS_EP0RCVOUT = 1; }

static void usbhw_ep0_stall(void) { TASKS_EP0STALL = 1; }

static void usbhw_address(uint32_t a) { (void) a; }

// data0 on an endpoint: its number and direction first, then the value
static void data0(uint32_t ep) { DTOGGLE = ep; DTOGGLE = ep | 1u << 8; }

static void usbhw_open(void) {
  EPINEN |= 1u << 2 | 1u << 3;
  EPOUTEN |= 1u << 2;
  EPSTALL = 0x82u, EPSTALL = 0x83u, EPSTALL = 0x02u;   // unstalled
  data0(0x82u), data0(0x83u), data0(0x02u);
  rx2held = 0, rx2armed = 0, tx2.on = 0;
  SIZE_EPOUT(2) = 0; }

static void usbhw_clear_halt(uint32_t ep) {
  uint32_t const e = ep & 0x87u;
  if ((e & 7u) == 2 || (e & 7u) == 3) EPSTALL = e, data0(e); }

static void rx2move(void) {
  rx2held = 0, rx2armed = 0;
  ucdc_rx(rx2, dout(2, rx2, SIZE_EPOUT(2))); }

static void usbhw_rx_arm(void) { rx2armed = 1; if (rx2held) rx2move(); }

static void txnext(struct tx *t) {
  uint32_t const m = t->n < ucdc_pkt ? t->n : ucdc_pkt;
  din(2, t->p, m);
  t->p += m, t->n -= m, t->last = m; }

// the class fills its buffer again once this returns, so the send goes from a copy
static void usbhw_tx(void const *src, uint32_t n) {
  for (uint32_t i = 0; i < n; i++) tx2.b[i] = ((uint8_t const *) src)[i];
  tx2.p = tx2.b, tx2.n = n, tx2.on = 1;
  txnext(&tx2); }

// a packet in was taken: the rest, then a zero packet after a full one
static void txdone(struct tx *t) {
  if (t->n) txnext(t);
  else if (t->last == ucdc_pkt) t->last = 0, din(2, t->b, 0);
  else t->on = 0; }

void usb_poll(void);
static int usbhw_tx_busy(void) { usb_poll(); return (int) tx2.on; }

static uint32_t usbhw_ms(void) { return clock_ms(); }

static void usbhw_reboot(void) { usb_reboot(); }

void usb_poll(void) {
  if (EV_USBRESET) {
    EV_USBRESET = 0;
    e0n = 0, e0dir = 0, rx2held = 0, rx2armed = 0, tx2.on = 0;
    ucdc_reset(); }
  if (EV_USBEVENT) EV_USBEVENT = 0, EVENTCAUSE = EVENTCAUSE;   // suspend and resume: nothing kept
  if (EV_EP0SETUP) {
    EV_EP0SETUP = 0;
    e0n = 0, e0dir = 0;
    uint32_t s[2] = { 0, 0 };
    for (uint32_t i = 0; i < 8; i++) s[i / 4] |= (SETUPB(i) & 0xFFu) << 8 * (i & 3);
    if ((s[0] & 0xFFFFu) != 0x0500u) ucdc_setup(s[0], s[1]); }   // set address is the controller's
  if (EV_EP0DATADONE) {
    EV_EP0DATADONE = 0;
    if (e0dir == 1 && e0n) e0next();
    else if (e0dir == 1) e0dir = 0, TASKS_EP0STATUS = 1;
    else if (e0dir == 2) {
      e0dir = 0;
      ucdc_ep0_out(e0b, dout(0, e0b, ucdc_pkt));
      usbhw_ep0_ack(); } }
  if (EV_EPDATA) {
    EV_EPDATA = 0;
    uint32_t const d = EPDATASTATUS;
    EPDATASTATUS = d;
    if (d & 1u << 2 && tx2.on) txdone(&tx2);                       // 2 in was taken
    if (d & 1u << 18) { rx2held = 1; if (rx2armed) rx2move(); } } }  // 2 out landed

// the serial the chip's; a controller left on by whoever ran before goes off the bus long
// enough for the host to see it go. then the errata's enable: its two registers held while
// the controller readies, and the pullup on
void usb_init(void) {
  uint32_t const id[2] = { REG(FICR_DEVICEID0), REG(FICR_DEVICEID1) };
  for (uint32_t i = 0; i < 16; i++) serial[i] = "0123456789ABCDEF"[id[i / 8] >> (28 - 4 * (i & 7)) & 15u];
  if (ENABLE) {
    USBPULLUP = 0, ENABLE = 0;
    for (uint32_t t = clock_ms(); clock_ms() - t < 200u; ) {} }
  for (uint32_t t = clock_ms(); !(REG(POWER_USBREGSTATUS) & 2u) && clock_ms() - t < 1000u; ) {}
  errata(ERRATA187, 3u), errata(ERRATA171, 0xC0u);
  ENABLE = 1;
  while (!(EVENTCAUSE & CAUSE_READY)) {}
  EVENTCAUSE = CAUSE_READY;
  errata(ERRATA171, 0u), errata(ERRATA187, 0u);
  EV_USBRESET = 0, EV_EP0SETUP = 0, EV_EP0DATADONE = 0, EV_EPDATA = 0, EV_USBEVENT = 0;
  USBPULLUP = 1; }

// off the bus, for a reset or a jump to whatever runs next
void usb_off(void) {
  USBPULLUP = 0, ENABLE = 0;
  for (uint32_t t = clock_ms(); clock_ms() - t < 200u; ) {} }
