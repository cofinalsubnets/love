// wasm's x64/arch.c: the machine is the worker (inle.js), each face one hypercall through
// __love_sys under linux's nearest number. kmain sets __love_osv = -1 first, so moonlibc's
// own calls take sys.c's answers and never reach the import
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
#define hc_proc 0x4040                      // (pid, argv, n, env, n, code): a process, its own instance
#define hc_proc_stop 0x4041                 // (pid): its worker ended where it stands
#define hc_clock_gettime 228

void archinit(void) { }
void serial_init(void) { }

// a line or a buffer per hypercall, never a byte; drained before any sleep or reset
static struct { unsigned char b[2048]; unsigned n; } ser;
static void serial_drain(void) {
  if (ser.n) __love_sys(hc_write, 1, (long) ser.b, ser.n, 0, 0, 0), ser.n = 0; }
void serial_putc(int c) {
  ser.b[ser.n++] = (unsigned char) c;
  if (c == '\n' || ser.n == sizeof ser.b) serial_drain(); }

// 0 the wall, 1 monotonic since the page loaded
static uint64_t clock_ms(long which) {
  long ts[2];
  if (__love_sys(hc_clock_gettime, which, (long) ts, 0, 0, 0, 0)) return 0;
  return (uint64_t) ts[0] * 1000 + (uint64_t) ts[1] / 1000000; }

uint64_t k_rtc(void) { return clock_ms(0) / 1000; }

// no timer interrupt: ticks catch up off the monotonic clock before a read and after an idle
void k_tick_sync(void) {
  static uint64_t last;
  uint64_t now = clock_ms(1);
  if (!last) last = now;
  kticks += (now - last) / 10;
  last += (now - last) / 10 * 10; }

// no keyboard interrupt: keys come when a task asks (k_kb_poll) and after an idle, never past
// the queue's room. a pointer record: how, button, pad, then y and x as le16. a paste is
// taken as the queue has room, its bracket's room kept back, and closed once dry
void k_kb_poll(void);
void k_pointer(uint32_t how, uint32_t b, uint32_t y, uint32_t x);
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

// machine.js's scan lane, for a game's armed tap (k_scan_put), else dropped so it never fills
void k_scan_put(uint8_t b);
bool k_scan_armed(void);
void k_scan_sync(void) {
  unsigned char b[16];
  long n = __love_sys(hc_scan, (long) b, sizeof b, 0, 0, 0, 0);
  for (long i = 0; i < n; i++) k_scan_put(b[i]); }

// one tick or until a key; the worker skips the sleep while its ring holds more
void k_idle(void) {
  long ts[2] = { 0, 10 * 1000000 };
  serial_drain();
  __love_sys(hc_nanosleep, (long) ts, 0, 0, 0, 0, 0);
  k_kb_poll();
  // the worker won't sleep while the lane holds codes, so unarmed it is emptied here
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

// the worker fetches url (the page's origin, or --origin under node) into the ramfs file at path
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

// kmain's /mnt/host: hc_host + op, answered from the page's storage or cpu.mjs's host lane
long k_host(long op, long a, long b, long c, long d, long e) {
  return __love_sys(hc_host + op, a, b, c, d, e, 0); }

// the reset: the worker unwinds the module and boots it again
void k_reset(void) { serial_drain(); for (;;) __love_sys(hc_reboot, 0, 0, 0, 0, 0, 0); }
// a process is an instance in its own worker, its calls back through sys.c's k_proc_call;
// code rides as a (code, length) pair, the call having one argument left
long k_proc_start(long pid, char const *av, uintptr_t an, char const *ev, uintptr_t en,
                  char const *code, uintptr_t cn) {
  uintptr_t c[2] = { (uintptr_t) code, cn };
  return __love_sys(hc_proc, pid, (long) av, (long) an, (long) ev, (long) en, code ? (long) c : 0); }
void k_proc_stop(long pid) { __love_sys(hc_proc_stop, pid, 0, 0, 0, 0, 0); }

// a reset into another module: path and boot line go to the lift slot
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
// a path for the page to carry out, posted at the worker's next idle
void k_lift_ask(unsigned char const *p, uintptr_t n) {
  __love_sys(hc_lift, (long) p, (long) n, 0, 0, 0, 0); }

// (fault n) backend: wasm has one trap, `unreachable`, and every n is it
void k_fault_trigger(intptr_t n) { (void) n; __builtin_trap(); }

// mksys.l's signal-return leaf: no signal is delivered here
void __love_sigret(void) { }

// the door: the span above the module's data and stack, the boot line, and a fetched image
// (above the span). w, h in device pixels; the framebuffer comes off the top. never returns.
// sc packs two (moon's wasm abi has eight int slots): the low byte the glyph scale, the rest
// the reservation in pixels, carved whole so k_fb_reseat moves w/h inside it; under w*h, pinned
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

// where the worker blits from, 0 none
uintptr_t k_fb_addr(void) { return (uintptr_t) kboot.fb.base; }

// the base stays put inside the reservation; 0: refused, the page keeps its box
bool k_fb_resize(uintptr_t w, uintptr_t h, uintptr_t scale) {
  return k_fb_reseat((unsigned) w, (unsigned) h, (unsigned) w, (unsigned) scale); }

// no carried runtimes here: plain definitions, so a seat that grows them collides
const unsigned char rtgz_x64[1] = {0};
const uintptr_t rtgz_x64_len = 0;
const unsigned char rtgz_a64[1] = {0};
const uintptr_t rtgz_a64_len = 0;
const unsigned char rtgz_rv64[1] = {0};
const uintptr_t rtgz_rv64_len = 0;
const unsigned char rtgz_i386[1] = {0};
const uintptr_t rtgz_i386_len = 0;
const unsigned char rtgz_id[1] = {0};
const uintptr_t rtgz_id_len = 0;
