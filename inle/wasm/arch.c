// wasm architecture-specific C: the door, the serial line, the clocks, the idle and the
// reset. this is the wasm counterpart of x64/arch.c -- same contract (archinit,
// serial_init, serial_putc, k_reset, k_rtc, k_fault_trigger), no hardware at all: the
// machine is the worker running the module (port/wasm/inle.js), and each face below is
// one hypercall through __ai_sys, the module's one import, wearing linux's number for
// the nearest thing -- write is the serial line, read the keys, nanosleep the idle,
// clock_gettime the two clocks, reboot the reset. nolibc's own calls never reach that
// import here: kmain writes __ai_osv = -1 first, so they take inle/sys.c's C answer.
#include <stdint.h>
#include <stdbool.h>
#include "asmops.h"
#include "k.h"

void kq(uint8_t);                      // kmain's input queue, one byte
void kmain(void);
extern long __ai_sys(long n, long a, long b, long c, long d, long e, long f);

#define hc_read 0
#define hc_write 1
#define hc_nanosleep 35
#define hc_reboot 169
#define hc_clock_gettime 228

void archinit(void) { }
void serial_init(void) { }

void serial_putc(int c) {
  unsigned char b = (unsigned char) c;
  __ai_sys(hc_write, 1, (long) &b, 1, 0, 0, 0); }

// the two clocks the worker keeps: 0 the wall, 1 monotonic since the page loaded
static uint64_t clock_ms(long which) {
  long ts[2];
  if (__ai_sys(hc_clock_gettime, which, (long) ts, 0, 0, 0, 0)) return 0;
  return (uint64_t) ts[0] * 1000 + (uint64_t) ts[1] / 1000000; }

uint64_t k_rtc(void) { return clock_ms(0) / 1000; }

// no timer interrupt counts ticks here: they are caught up off the monotonic clock,
// whenever kmain is about to read them (k_tick_sync) and after every idle
void k_tick_sync(void) {
  static uint64_t last;
  uint64_t now = clock_ms(1);
  if (!last) last = now;
  kticks += (now - last) / 10;
  last += (now - last) / 10 * 10; }

// the idle: sleep one tick or until a key, then drain the keys the worker queued while
// we were away -- read on fd 0 never blocks here, it answers what is there, and the
// worker skips the sleep while its ring holds more. eight at a time: kmain's queue holds
// sixteen and the reader drains it between idles, so a pasted line arrives whole where
// a uart would have dropped it.
void k_idle(void) {
  long ts[2] = { 0, 10 * 1000000 };
  unsigned char b[8];
  __ai_sys(hc_nanosleep, (long) ts, 0, 0, 0, 0, 0);
  long n = __ai_sys(hc_read, 0, (long) b, (long) sizeof b, 0, 0, 0);
  for (long i = 0; i < n; i++) kq(b[i]);
  k_tick_sync(); }

// the reset: the worker unwinds the module and boots it again
void k_reset(void) { for (;;) __ai_sys(hc_reboot, 0, 0, 0, 0, 0, 0); }

// (fault n) backend: wasm has one trap, `unreachable`, and every n is it
void k_fault_trigger(intptr_t n) { (void) n; __builtin_trap(); }

// nolibc's signal-return trampoline, the metal tails' one asm leaf (mksys.l); no
// signal is ever delivered on this machine, so the leaf is empty
void __ai_sigret(void) { }

// the door: the worker grows the memory, then hands over the span above the module's
// own data and shadow stack, and the boot line. a page with a canvas names its size, and
// the framebuffer is carved off the top of that span; headless, the serial line is the
// console (kmain's own law). never returns: kmain ends in k_reset.
void k_start(uintptr_t lo, uintptr_t hi, uintptr_t w, uintptr_t h, char const *cmd) {
  if (w && h) {
    uintptr_t fb = (hi - w * h * 4) & ~(uintptr_t) 4095;
    kboot.fb.base = (void *) fb;
    kboot.fb.w = (uint16_t) w, kboot.fb.h = (uint16_t) h, kboot.fb.pitch_px = (uint32_t) w;
    kboot.has_fb = true;
    hi = fb; }
  k_ram_give(lo, hi - lo);
  k_cmdline(cmd, ~(uintptr_t) 0);
  kmain(); }

// where the worker blits from: the framebuffer's address, 0 when there is none
uintptr_t k_fb_addr(void) { return (uintptr_t) kboot.fb.base; }
