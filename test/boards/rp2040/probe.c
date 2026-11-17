// an swd probe on any rp2040 board (the xiao rp2040's d8 d9 d10, a pico's gp2 gp4 gp3), mooncc
// -t thumb1, no sdk: src/apps/swd.l's transfer-level wire, over usb.c's cdc-acm. the core
// clocks the bits on sio; the host batches commands and reads each answer at a length it
// can predict. every multi-byte field is little-endian
//   'T' rq [w32]   a transfer, w32 when rq's RnW bit is clear: answers ack, then on a read
//                  with ack 1 the w32 read and its parity bit as a byte. after an ack not 1
//                  the batch's later transfers are not clocked and answer ack 0, until 'E'
//   'N' rq w32     a write whose ack no target drives (dpv2's targetsel): answers nothing
//   'B' n16 bytes  n raw bits out, lsb first: line resets, the jtag switch, dormant wakes
//   'R' b          1 holds nrst low, 0 lets it go
//   'C' hz32       the clock: answers the rate it set
//   'Z'            every line let go, the target's alone again
//   'E'            the batch's end: answers 'e'
//   'I'            answers "lovswd1\n"
#include <stdint.h>
#include "rp2040.h"

enum { swclk = 2, nrst = 3, swdio = 4 };
enum { sys_hz = 125000000, bit_cyc = 24, loop_cyc = 4 };   // a bit's cost without delay, a delay turn's

void usb_init(void);
void usb_poll(void);
int usb_rx_ready(void);
int usb_getc(void);
void usb_putc(int c);
void usb_flush(void);

struct probe { uint32_t half, on, stop; };

static void spin(uint32_t n) { for (volatile uint32_t k = 0; k < n; k++) {} }

#define PIN(p) (1u << (p))
static void clk(int hi) { REG(hi ? SIO_GPIO_OUT_SET : SIO_GPIO_OUT_CLR) = PIN(swclk); }
static void dio_out(int on) { REG(on ? SIO_GPIO_OE_SET : SIO_GPIO_OE_CLR) = PIN(swdio); }

// the host drives swdio while the target samples it on the rising edge, and reads it just
// before the edge the target moves it on
static void wbit(struct probe *p, uint32_t b) {
  REG(b & 1u ? SIO_GPIO_OUT_SET : SIO_GPIO_OUT_CLR) = PIN(swdio);
  clk(0), spin(p->half), clk(1), spin(p->half); }

static uint32_t rbit(struct probe *p) {
  clk(0), spin(p->half);
  uint32_t const b = (REG(SIO_GPIO_IN) >> swdio) & 1u;
  clk(1), spin(p->half);
  return b; }

static void cycle(struct probe *p) { clk(0), spin(p->half), clk(1), spin(p->half); }

// swclk and swdio taken on the first bit after a 'Z', swdio parked high
static void take(struct probe *p) {
  if (p->on) return;
  REG(SIO_GPIO_OUT_SET) = PIN(swclk) | PIN(swdio);
  REG(SIO_GPIO_OE_SET) = PIN(swclk) | PIN(swdio);
  p->on = 1; }

static void release(struct probe *p) {
  REG(SIO_GPIO_OE_CLR) = PIN(swclk) | PIN(swdio) | PIN(nrst);
  p->on = 0; }

static uint32_t parity(uint32_t v) { v ^= v >> 16, v ^= v >> 8, v ^= v >> 4, v ^= v >> 2, v ^= v >> 1; return v & 1u; }

static void wword(struct probe *p, uint32_t v) {
  for (uint32_t i = 0; i < 32; i++) wbit(p, v >> i);
  wbit(p, parity(v)); }

static void request(struct probe *p, uint32_t rq) {
  take(p);
  for (uint32_t i = 0; i < 8; i++) wbit(p, rq >> i);
  dio_out(0), cycle(p); }

// a whole transfer: request, turnaround, ack, then the data phase an ok ack owes. a wait or
// fault skips it, and no answer at all clocks past where it would have been
static uint32_t xfer(struct probe *p, uint32_t rq, uint32_t w, uint32_t *r, uint32_t *par) {
  request(p, rq);
  uint32_t ack = rbit(p);
  ack |= rbit(p) << 1;
  ack |= rbit(p) << 2;
  if (ack == 1u && rq & 4u) {
    uint32_t v = 0;
    for (uint32_t i = 0; i < 32; i++) v |= rbit(p) << i;
    *r = v, *par = rbit(p);
    cycle(p), dio_out(1);
    return ack; }
  if (ack == 1u) { cycle(p), dio_out(1), wword(p, w); return ack; }
  if (ack == 2u || ack == 4u) { cycle(p), dio_out(1); return ack; }
  for (uint32_t i = 0; i < 33; i++) cycle(p);
  dio_out(1);
  return ack; }

static void noack(struct probe *p, uint32_t rq, uint32_t w) {
  request(p, rq);
  for (uint32_t i = 0; i < 3; i++) cycle(p);
  cycle(p), dio_out(1), wword(p, w); }

// the half period in delay turns for a rate, and the rate those turns make
static uint32_t rate(struct probe *p, uint32_t hz) {
  uint32_t const want = hz ? sys_hz / hz : 0xFFFFFFFFu;
  p->half = want > bit_cyc ? (want - bit_cyc) / (2u * loop_cyc) : 0;
  return sys_hz / (bit_cyc + 2u * loop_cyc * p->half); }

// the answers go out when the host has nothing more waiting
static int get(void) {
  if (!usb_rx_ready()) usb_flush();
  while (!usb_rx_ready()) usb_poll();
  return usb_getc(); }

static uint32_t get32(void) {
  uint32_t v = 0;
  for (uint32_t i = 0; i < 4; i++) v |= (uint32_t) get() << 8 * i;
  return v; }

static void put32(uint32_t v) { for (uint32_t i = 0; i < 4; i++) usb_putc((int) (v >> 8 * i & 0xFFu)); }

static void puts_(char const *s) { for (; *s; s++) usb_putc(*s); }

int main(void) {
  struct probe p = { 0, 0, 0 };
  unsigned const pins[3] = { swclk, nrst, swdio };
  // the blocks it uses from their reset, whatever the rom left them in
  uint32_t const blk = RST_IO_BANK0 | RST_PADS_BANK0 | RST_TIMER;
  REG(RESETS_RESET + REG_SET) = blk;
  REG(RESETS_RESET + REG_CLR) = blk;
  while ((REG(RESETS_RESET_DONE) & blk) != blk) {}
  for (unsigned i = 0; i < 3; i++) {
    gpio_init(pins[i]);
    REG(PADS_BANK0_GPIO(pins[i]) + REG_CLR) = PADS_PDE;
    REG(PADS_BANK0_GPIO(pins[i]) + REG_SET) = PADS_PUE; }
  REG(SIO_GPIO_OUT_CLR) = PIN(nrst);
  rate(&p, 1000000u);
  usb_init();
  for (;;) {
    int const c = get();
    if (c == 'T') {
      uint32_t const rq = (uint32_t) get(), w = rq & 4u ? 0 : get32();
      uint32_t r = 0, par = 0, ack = 0;
      if (!p.stop) ack = xfer(&p, rq, w, &r, &par), p.stop = ack != 1u;
      usb_putc((int) ack);
      if (ack == 1u && rq & 4u) put32(r), usb_putc((int) par); }
    else if (c == 'N') { uint32_t const rq = (uint32_t) get(), w = get32(); if (!p.stop) noack(&p, rq, w); }
    else if (c == 'B') {
      uint32_t n = (uint32_t) get();
    n |= (uint32_t) get() << 8;
      take(&p);
      for (uint32_t i = 0; i < n; i += 8) {
        uint32_t const b = (uint32_t) get();
        for (uint32_t k = 0; k < 8 && i + k < n; k++) wbit(&p, b >> k); } }
    else if (c == 'R') REG(get() ? SIO_GPIO_OE_SET : SIO_GPIO_OE_CLR) = PIN(nrst);
    else if (c == 'C') put32(rate(&p, get32()));
    else if (c == 'Z') release(&p);
    else if (c == 'E') p.stop = 0, usb_putc('e');
    else if (c == 'I') puts_("lovswd1\n");
    else usb_putc('?'); } }
