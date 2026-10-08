// wasm architecture-specific C: the door, the serial line, the clocks, the idle and the
// reset. this is the wasm counterpart of x64/arch.c -- same contract (archinit,
// serial_init, serial_putc, k_reset, k_rtc, k_fault_trigger), no hardware at all: the
// machine is the worker running the module (src/inle/wasm/inle.js), and each face below is
// one hypercall through __love_sys, the module's one import, wearing linux's number for
// the nearest thing -- write is the serial line, read the keys, nanosleep the idle,
// clock_gettime the two clocks, reboot the reset. moonlibc's own calls never reach that
// import here: kmain writes __love_osv = -1 first, so they take src/inle/sys.c's C answer.
#include <stdint.h>
#include <stdbool.h>
#include <errno.h>
#include "asmops.h"
#include "k.h"

void kq(uint8_t);                      // kmain's input queue, one byte
void kmain(void);
bool k_fb_reseat(unsigned w, unsigned h, unsigned pitch, unsigned scale);  // kmain's paper door
extern long __love_sys(long n, long a, long b, long c, long d, long e, long f);

#define hc_read 0
#define hc_write 1
#define hc_nanosleep 35
#define hc_reboot 169
#define hc_lift 0x4010
#define hc_scan 0x4011
#define hc_drew 0x4012
#define hc_kexec 0x4013                     // ("path\\0cmd", n): what the next reset boots
#define hc_point 0x4014                     // (buf, n) -> whole 8-byte pointer records taken
#define hc_paste 0x4015                     // (buf, n) -> paste bytes taken; n 0 counts them
#define hc_copy 0x4016                      // (text, n): a selection, for the page's clipboard
#define hc_fetch_open 0x4020                // (url, n) -> the body's length, or -errno
#define hc_fetch_read 0x4021                // (buf, n) -> bytes copied, on from the last
#define hc_fetch_close 0x4022
#define hc_host 0x4030                      // +op: kmain's k_host, the seat's own files
#define hc_clock_gettime 228

void archinit(void) { }
void serial_init(void) { }

// the serial line goes to the worker a line or a buffer at a time, never a byte: each
// hypercall is a decode and a crossing, and a screenful of escapes is tens of thousands
// of bytes. what is held goes out before any sleep or reset, so nothing waits on it
static struct { unsigned char b[2048]; unsigned n; } ser;   // the arch's one held line
static void serial_drain(void) {
  if (ser.n) __love_sys(hc_write, 1, (long) ser.b, ser.n, 0, 0, 0), ser.n = 0; }
void serial_putc(int c) {
  ser.b[ser.n++] = (unsigned char) c;
  if (c == '\n' || ser.n == sizeof ser.b) serial_drain(); }

// the two clocks the worker keeps: 0 the wall, 1 monotonic since the page loaded
static uint64_t clock_ms(long which) {
  long ts[2];
  if (__love_sys(hc_clock_gettime, which, (long) ts, 0, 0, 0, 0)) return 0;
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
// the page's pointer and clipboard ride lanes of their own beside the keys: a pointer record
// is how, the button with its modifiers, a pad, then the row and the column as two
// little-endian bytes each, and kmain's k_pointer takes it; a paste is plain bytes, taken
// as the queue has room (with its bracket's room kept back) and closed once it runs dry
void k_kb_poll(void);
void k_pointer(uint32_t how, uint32_t b, uint32_t row, uint32_t col);
void k_paste_in(uint8_t const *s, long n);
void k_paste_end(void);
static void k_point_sync(void) {
  unsigned char r[8 * 8];
  long const n = __love_sys(hc_point, (long) r, sizeof r, 0, 0, 0, 0);
  for (long i = 0; i + 8 <= n; i += 8)
    k_pointer(r[i], r[i + 1], r[i + 4] | (uint32_t) r[i + 5] << 8, r[i + 6] | (uint32_t) r[i + 7] << 8); }
void k_kb_sync(int room) {
  unsigned char b[48];
  k_point_sync();
  if (room <= 0) return;
  long n = __love_sys(hc_read, 0, (long) b, room < 16 ? room : 16, 0, 0, 0);
  for (long i = 0; i < n; i++) kq(b[i]);
  room -= (int) n;
  if (!__love_sys(hc_paste, 0, 0, 0, 0, 0, 0)) { if (room >= 6) k_paste_end(); }
  else if (room > 12) {
    n = __love_sys(hc_paste, (long) b, room - 12 < (int) sizeof b ? room - 12 : (long) sizeof b, 0, 0, 0, 0);
    k_paste_in(b, n); } }

void k_copy_out(uint8_t const *s, uintptr_t n) { __love_sys(hc_copy, (long) s, (long) n, 0, 0, 0, 0); }

// the scancodes the page queued on their own lane (src/inle/wasm/machine.js's scan lane), for the tap when a
// game armed it (kmain's k_scan_put) and dropped otherwise, so the lane never fills
void k_scan_put(uint8_t b);
bool k_scan_armed(void);
void k_scan_sync(void) {
  unsigned char b[16];
  long n = __love_sys(hc_scan, (long) b, sizeof b, 0, 0, 0, 0);
  for (long i = 0; i < n; i++) k_scan_put(b[i]); }

// the idle: sleep one tick or until a key, then take the keys that came while we were
// away; the worker skips the sleep while its ring holds more
void k_idle(void) {
  long ts[2] = { 0, 10 * 1000000 };
  serial_drain();
  __love_sys(hc_nanosleep, (long) ts, 0, 0, 0, 0, 0);
  k_kb_poll();
  // the codes go out whether or not a game armed the tap, and the worker holds its sleep
  // while the lane has anything in it: unread is not the same as empty, so an unarmed tap
  // empties the lane here and k_scan_put drops what it takes. armed, the game's own pop
  // syncs and this leaves the codes where they are.
  if (!k_scan_armed()) k_scan_sync();
  k_tick_sync(); }

// a sleep under the tick, exact: kmain's k_sleep asks before it rounds to ticks
bool k_nap(uintptr_t ms) {
  long ts[2] = { 0, (long) ms * 1000000 };
  serial_drain();
  __love_sys(hc_nanosleep, (long) ts, 0, 0, 0, 0, 0);
  k_kb_poll();
  k_tick_sync();
  return true; }

// the paper was drawn on by something other than the console: the worker blits it
void k_fb_touch(void) { __love_sys(hc_drew, 0, 0, 0, 0, 0, 0); }

// the page's network (kmain's k_fetch): the worker takes URL whole -- the page's own
// origin, or a file under --origin under node -- and hands it over in pieces, laid as
// the ramfs file at PATH
int k_fs_open(char const *p, uintptr_t pn, char m);
long k_fd_write(int fd, void const *b, long n);
long k_fd_close(int fd);
long k_fetch(char const *url, uintptr_t un, char const *path, uintptr_t pn) {
  long n = __love_sys(hc_fetch_open, (long) url, (long) un, 0, 0, 0, 0), r = 0;
  if (n < 0) return n;
  int fd = k_fs_open(path, pn, 'w');
  if (fd < 0) r = fd;
  else {
    unsigned char b[4096];
    for (long got; r == 0 && (got = __love_sys(hc_fetch_read, (long) b, sizeof b, 0, 0, 0, 0)) != 0; )
      if (got < 0 || k_fd_write(fd, b, got) != got) r = got < 0 ? got : -EIO;
    k_fd_close(fd); }
  __love_sys(hc_fetch_close, 0, 0, 0, 0, 0, 0);
  return r; }

// the seat's own files (kmain's /mnt/host): each operation one hypercall, its number
// hc_host + op, answered by the worker from the page's folder or storage, or a directory
// under node (cpu.mjs's host lane)
long k_host(long op, long a, long b, long c, long d, long e) {
  return __love_sys(hc_host + op, a, b, c, d, e, 0); }

// the reset: the worker unwinds the module and boots it again
void k_reset(void) { serial_drain(); for (;;) __love_sys(hc_reboot, 0, 0, 0, 0, 0, 0); }
// ..and into another module: the path and the boot line go into the lift slot, and the
// worker reads the file at the reset the way it lifts one, then boots those bytes
long k_kexec(char const *p, uintptr_t pn, char const *cmd, uintptr_t cn) {
  unsigned char b[256];
  if (pn + 1 + cn >= sizeof b) return -ENAMETOOLONG;
  for (uintptr_t i = 0; i < pn; i++) b[i] = (unsigned char) p[i];
  b[pn] = 0;
  for (uintptr_t i = 0; i < cn; i++) b[pn + 1 + i] = (unsigned char) cmd[i];
  long r = __love_sys(hc_kexec, (long) b, (long) (pn + 1 + cn), 0, 0, 0, 0);
  if (r < 0) return r;
  k_reset();
  return 0; }
// a path for the page to carry out: it lands in the shared lift slot and the request is
// raised, and the worker's loop reads the file and posts it at its next idle
void k_lift_ask(unsigned char const *p, uintptr_t n) {
  __love_sys(hc_lift, (long) p, (long) n, 0, 0, 0, 0); }

// (fault n) backend: wasm has one trap, `unreachable`, and every n is it
void k_fault_trigger(intptr_t n) { (void) n; __builtin_trap(); }

// moonlibc's signal-return trampoline, the metal tails' one asm leaf (mksys.l); no
// signal is ever delivered on this machine, so the leaf is empty
void __love_sigret(void) { }

// the door: the worker grows the memory, then hands over the span above the module's
// own data and shadow stack, the boot line, and the heap image it fetched, if any (laid
// above the span; kmain copies it into the heap). a page with a canvas names its size in
// REAL pixels -- the canvas backing store, device ratio included -- and the scale a glyph
// pixel gets there, which is how the page's own scale reaches the console; rows and columns
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
// the horn is src/inle/hda.c's, and there is no sound card behind a wasm module; the
// carried per-ISA runtimes are the shipped artifact's, and out/wasm/src.o brings only
// the source blob. plain definitions, so a seat that grows either one collides here
// rather than quietly keeping the empty answer.
const unsigned char rtgz_x64[1] = {0};
const uintptr_t rtgz_x64_len = 0;
const unsigned char rtgz_a64[1] = {0};
const uintptr_t rtgz_a64_len = 0;
const unsigned char rtgz_rv64[1] = {0};
const uintptr_t rtgz_rv64_len = 0;
const unsigned char rtgz_id[1] = {0};
const uintptr_t rtgz_id_len = 0;
