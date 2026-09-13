// wasm architecture-specific C: the door, the serial line, the clocks, the idle and the
// reset. this is the wasm counterpart of x64/arch.c -- same contract (archinit,
// serial_init, serial_putc, k_reset, k_rtc, k_fault_trigger), no hardware at all: the
// machine is the worker running the module (i/wasm/inle.js), and each face below is
// one hypercall through __ai_sys, the module's one import, wearing linux's number for
// the nearest thing -- write is the serial line, read the keys, nanosleep the idle,
// clock_gettime the two clocks, reboot the reset. moonlibc's own calls never reach that
// import here: kmain writes __ai_osv = -1 first, so they take i/sys.c's C answer.
#include <stdint.h>
#include <stdbool.h>
#include "asmops.h"
#include "k.h"

void kq(uint8_t);                      // kmain's input queue, one byte
void kmain(void);
bool k_fb_reseat(unsigned w, unsigned h, unsigned pitch, unsigned scale);  // kmain's paper door
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

// no keyboard interrupt either: the keys the worker queued are taken when a task asks
// after one (kmain's k_kb_poll) and after every idle -- read on fd 0 never blocks here,
// it answers what is there, and never more than kmain's queue has room for: the rest
// waits in the worker's ring, which is deep, so a pasted line arrives whole. asking is
// the one way a guest that never idles -- a frame loop the horn paces -- hears a key.
void k_kb_poll(void);
void k_kb_sync(int room) {
  unsigned char b[16];
  if (room <= 0) return;
  long n = __ai_sys(hc_read, 0, (long) b, room < (int) sizeof b ? room : (long) sizeof b, 0, 0, 0);
  for (long i = 0; i < n; i++) kq(b[i]); }

// the idle: sleep one tick or until a key, then take the keys that came while we were
// away; the worker skips the sleep while its ring holds more
void k_idle(void) {
  long ts[2] = { 0, 10 * 1000000 };
  __ai_sys(hc_nanosleep, (long) ts, 0, 0, 0, 0, 0);
  k_kb_poll();
  k_tick_sync(); }

// the reset: the worker unwinds the module and boots it again
void k_reset(void) { for (;;) __ai_sys(hc_reboot, 0, 0, 0, 0, 0, 0); }

// (fault n) backend: wasm has one trap, `unreachable`, and every n is it
void k_fault_trigger(intptr_t n) { (void) n; __builtin_trap(); }

// moonlibc's signal-return trampoline, the metal tails' one asm leaf (mksys.l); no
// signal is ever delivered on this machine, so the leaf is empty
void __ai_sigret(void) { }

// the door: the worker grows the memory, then hands over the span above the module's
// own data and shadow stack, the boot line, and the heap image it fetched, if any (laid
// above the span; kmain copies it into the heap). a page with a canvas names its size in
// REAL pixels -- the canvas backing store, device ratio included -- and the scale a glyph
// pixel gets there, which is how the page's own zoom reaches the console; rows and columns
// then fall out of the two. the framebuffer is carved off the top of that span; headless,
// the serial line is the console (kmain's own law). never returns: kmain ends in k_reset.
// `sc` carries two things in one argument, and it has to: moon's wasm convention hands a
// function EIGHT integer slots and k_start already spent them. the low byte is the scale a
// glyph pixel gets; the rest is the RESERVATION in pixels -- the most this canvas will ever
// be, which is the screen it sits on. the paper is carved at the reservation and the heap
// gets what is under it, so k_fb_reseat can move the live w/h around inside a span the heap
// was never given. a reservation under w*h (0, from a door that names none) is the live
// size, and the canvas is pinned the way it always was.
void k_start(uintptr_t lo, uintptr_t hi, uintptr_t w, uintptr_t h, uintptr_t sc,
             char const *cmd, uintptr_t img, uintptr_t imgn) {
  uintptr_t const scale = sc & 0xff, cap0 = sc >> 8;
  kboot.image = (void const *) img, kboot.image_len = imgn;
  if (w && h) {
    uintptr_t cap = cap0 < w * h ? w * h : cap0;
    uintptr_t fb = (hi - cap * 4) & ~(uintptr_t) 4095;
    kboot.fb.base = (void *) fb;
    kboot.fb.w = (uint16_t) w, kboot.fb.h = (uint16_t) h, kboot.fb.pitch_px = (uint32_t) w;
    kboot.fb.scale = (uint8_t) scale;
    kboot.fb.cap_px = (uint32_t) cap;
    kboot.has_fb = true;
    hi = fb; }
  k_ram_give(lo, hi - lo);
  k_cmdline(cmd, ~(uintptr_t) 0);
  kmain(); }

// where the worker blits from: the framebuffer's address, 0 when there is none
uintptr_t k_fb_addr(void) { return (uintptr_t) kboot.fb.base; }

// the canvas was resized under the running machine. the base does not move -- only what
// of the reservation is in use -- so the worker keeps blitting from k_fb_addr and simply
// reads a new w and h back. 0 says the machine would not take it and the page should keep
// the box it had.
bool k_fb_resize(uintptr_t w, uintptr_t h, uintptr_t scale) {
  return k_fb_reseat((unsigned) w, (unsigned) h, (unsigned) w, (unsigned) scale); }

// --- what this seat does not have ------------------------------------------------
// the horn is i/hda.c's, and there is no sound card behind a wasm module; the
// carried per-ISA runtimes are the shipped artifact's, and b/wasm/src.o brings only
// the source blob. plain definitions, so a seat that grows either one collides here
// rather than quietly keeping the empty answer.
const unsigned char ai_rtgz_x64[1] = {0};
const uintptr_t ai_rtgz_x64_len = 0;
const unsigned char ai_rtgz_a64[1] = {0};
const uintptr_t ai_rtgz_a64_len = 0;
const unsigned char ai_rtgz_rv64[1] = {0};
const uintptr_t ai_rtgz_rv64_len = 0;
const unsigned char ai_rtgz_id[1] = {0};
const uintptr_t ai_rtgz_id_len = 0;
