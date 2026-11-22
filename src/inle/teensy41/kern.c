// the teensy 4.1 kernel seat: kmain over the board's drivers. a polled seat, as wasm's is: the
// clock catches kticks up and the console rings fill kq while a task waits. the console is the
// usb cdc and LPUART6 together, the disk the microSD slot (sd.c), RAM the PSRAM
#include <stdint.h>
#include <stdbool.h>
#include "teensy41.h"
#include "psram.h"
#include "../k.h"
#include "../bput.h"
#include "../kface.h"

uintptr_t te_ms(void);
void kmain(void);
uint32_t sd_sectors(void);
int sd_rw(uint32_t lba, uint32_t n, void *buf, int wr);
// the baked heap image (mkimg.l), empty when no bake ran
extern unsigned char const _binary_love_img_start[], _binary_love_img_end[];

void archinit(void) { }
void serial_init(void) { }
void serial_putc(int c) {
  if (c == '\n') serial_putc('\r');
  uart_putc(c), usb_putc(c);
  if (c == '\n') usb_flush(); }

// a fault said on the usb too, then the loader (the reboot usb.c answers 134 baud with), so a
// wedged kernel still flashes without the button
void te_fault_putc(int c) { usb_putc(c); }
void arm_halt251(void);
// teensy41.c's record, kept past the reset in the 64 bytes the heap leaves at the top of the
// PSRAM, once that is up: the next boot says it
extern volatile struct fault { uint32_t r0, r1, r2, r3, r12, lr, pc, psr, sp, magic; } fault;
static volatile uint32_t *te_last;
void te_fault_end(void) {
  if (te_last) {
    te_last[0] = fault.pc, te_last[1] = fault.lr, te_last[2] = fault.sp, te_last[3] = REG(0xE000ED28u);
    te_last[4] = REG(0xE000ED38u), te_last[5] = 0xFA017EDu; }
  usb_flush();
  for (uint32_t t = te_ms(); te_ms() - t < 2000; ) {}
  REG(0xE000EDFCu) &= ~(1u << 16);
  arm_halt251();
  for (;;) {} }
uint64_t k_rtc(void) { return 0; }

#define SCB_AIRCR 0xE000ED0Cu
// half a second on the console first, so a loader's 134 baud still finds a resetting kernel
void k_reset(void) {
  usb_flush();
  for (uint32_t t = te_ms(); te_ms() - t < 500; ) usb_rx_ready();
  REG(SCB_AIRCR) = 0x05FA0004u;              // SYSRESETREQ
  for (;;) arm_wfi(); }
void k_fault_trigger(intptr_t n) { (void) n, arm_bkpt(); }

// GPT1 counts microseconds and wraps in 71 minutes: kticks takes the deltas
void k_tick_sync(void) {
  static uint32_t last, us;
  uint32_t now = REG(GPT1_CNT);
  us += now - last, last = now;
  kticks += us / 10000, us %= 10000; }

// room: what kq can still take
void k_kb_sync(int room) {
  for (; room > 0 && uart_rx_ready(); room--) kq((uint8_t) uart_getc());
  for (; room > 0 && usb_rx_ready(); room--) kq((uint8_t) usb_getc()); }

// asmops' k_wait: nothing interrupts a wait here, so it drains output and polls
void k_idle(void) { usb_flush(), k_tick_sync(), k_kb_poll(); }

// the microSD slot in blk.c's place
void k_blk_init(void *dma) { (void) dma; }
uint64_t k_blk_sectors(void) { return sd_sectors(); }
int k_blk_rw(uint64_t lba, uint32_t n, void *buf, int wr) {
  uint64_t c = sd_sectors();
  if (!c || lba + n < lba || lba + n > c) return -1;
  return sd_rw((uint32_t) lba, n, buf, wr) < 0 ? -1 : 0; }

// teensy41.c's cmain, the clocks and caches up
void te_main(void) {
  volatile uint32_t *srsr = (volatile uint32_t *) 0x400F8008u;
  uint32_t why = *srsr;
  *srsr = why;
  bput_s(uart_putc, "\r\n; inle/teensy41 kernel, reset "), bput_x(uart_putc, why, 3), bput_s(uart_putc, "\r\n");
  usb_init();
  bput_s(uart_putc, "; usb init\r\n");
  // a few seconds for a host to open the port, so the boot is seen
  for (uint32_t t = te_ms(), d = 0; !usb_up() && te_ms() - t < 8000; )
    if ((te_ms() - t) / 1000 > d) d++, uart_putc('.');
  bput_s(serial_putc, "; usb up, psram next\n");
  uint32_t mb = psram_init();
  // 64 B shy of the edge: a one-past read at a block boundary stays inside
  if (mb) {
    k_ram_give(PSRAM_BASE, ((uint64_t) mb << 20) - 64);
    te_last = (volatile uint32_t *) (PSRAM_BASE + (mb << 20) - 64);
    if (te_last[5] == 0xFA017EDu) {
      char const *tags[5] = { "; last boot faulted: pc=", " lr=", " sp=", " cfsr=", " bfar=" };
      for (int k = 0; k < 5; k++) bput_s(serial_putc, tags[k]), bput_x(serial_putc, te_last[k], 8);
      serial_putc('\n');
      te_last[5] = 0; } }
  kboot.image = _binary_love_img_start;
  kboot.image_len = (uintptr_t) (_binary_love_img_end - _binary_love_img_start);
  bput_s(serial_putc, "; psram "), bput_n(serial_putc, mb, 10), bput_s(serial_putc, " MB, kmain next\n");
  kmain(); }

// kmain's gpio words over teensy41.c's pin map, the board's own numbers
long k_gpio(int op, unsigned pin, int v) {
  if (!gpio_ok(pin)) return -1;
  switch (op) {
    case 0: gpio_init(pin); return (long) pin;
    case 1: gpio_set_dir(pin, v); return v;
    case 2: gpio_put(pin, v); return v;
    case 3: return gpio_get(pin);
    default: return -1; } }
