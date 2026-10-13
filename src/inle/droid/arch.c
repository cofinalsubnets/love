// droid architecture-specific C: inle as a linux process, the phone's seat (notes/plan/inle-droid.md).
// the wasm seat's contract (src/inle/wasm/arch.c) answered by a real kernel: each face below is
// one system call through __love_sys, moonlibc's raw tail, which kmain's __love_osv = -1 never
// reaches -- moonlibc's own calls take src/inle/sys.c's answers, as on every other seat. the
// serial line is fds 0 and 1, the screen the bridge's window; the reset ends the process.
#include <stdint.h>
#include <stdbool.h>
#include <errno.h>
#include "../../apps/moon/lib/moonlibc/impl.h"
#include "asmops.h"
#include "k.h"

void kq(uint8_t);
void kmain(void);
void k_kb_poll(void);
bool k_fb_reseat(unsigned w, unsigned h, unsigned pitch, unsigned scale);

#define sys(n, a, b, c, d) __love_sys(n, (long) (a), (long) (b), (long) (c), (long) (d), 0, 0)

// the terminal as it was found, put back at the end; a tty reads raw while the machine runs.
// kernel termios: four flag words, the line, the controls
struct k_tio { uint32_t i, o, c, l; uint8_t line, cc[19]; };
// the machine: the serial line, and the face -- the bridge's window (src/apps/droid/bridge.c),
// the paper shown there as the rows that changed since the last frame (was), its records
// read into r
static struct { struct k_tio was; bool tty, eof, drew, all; uint64_t tick, sent; unsigned n, rn;
                int fd; uint32_t w, h, cap, *fb, *shown; unsigned char b[2048], r[192]; } m = { .fd = -1 };

static void serial_drain(void) {
  for (unsigned at = 0; at < m.n; ) {
    long r = sys(NR_write, 1, m.b + at, m.n - at, 0);
    if (r <= 0) break;
    at += (unsigned) r; }
  m.n = 0; }

static void leave(int code) {
  serial_drain();
  if (m.tty) sys(NR_ioctl, 0, 0x5402, &m.was, 0);              // TCSETS
  for (;;) sys(NR_exit_group, code, 0, 0, 0); }

void archinit(void) { }

// stdin without waiting: raw on a tty (output keeps its newline translation), and never blocking
void serial_init(void) {
  struct k_tio t;
  if (!sys(NR_ioctl, 0, 0x5401, &m.was, 0)) {                    // TCGETS: a tty
    t = m.was, m.tty = true;
    t.i &= ~(uint32_t) (01 | 02 | 010 | 040 | 0100 | 0200 | 0400 | 02000);
    t.l &= ~(uint32_t) (010 | 0100 | 02 | 01 | 0100000);       // echo, icanon, isig, iexten
    t.cc[6] = 1, t.cc[5] = 0;                                    // vmin 1, vtime 0
    sys(NR_ioctl, 0, 0x5402, &t, 0); }
  long fl = sys(NR_fcntl, 0, 3, 0, 0);                           // F_GETFL
  if (fl >= 0) sys(NR_fcntl, 0, 4, fl | 04000, 0); }             // F_SETFL O_NONBLOCK

void serial_putc(int c) {
  m.b[m.n++] = (unsigned char) c;
  if (c == '\n' || m.n == sizeof m.b) serial_drain(); }

static uint64_t clock_ms(long which) {
  long ts[2];
  if (sys(NR_clock_gettime, which, ts, 0, 0)) return 0;
  return (uint64_t) ts[0] * 1000 + (uint64_t) ts[1] / 1000000; }

uint64_t k_rtc(void) { return clock_ms(0) / 1000; }

// ticks are caught up off the monotonic clock, 10 ms each
void k_tick_sync(void) {
  uint64_t now = clock_ms(1);
  if (!m.tick) m.tick = now;
  kticks += (now - m.tick) / 10;
  m.tick += (now - m.tick) / 10 * 10; }

// --- the face -------------------------------------------------------------------------
static void face_out(void const *p, uintptr_t n) {
  for (uintptr_t at = 0; at < n; ) {
    long r = sys(NR_write, m.fd, (char const *) p + at, n - at, 0);
    if (r <= 0) leave(0);
    at += (uintptr_t) r; } }

// the rows that changed go to the bridge, at most one frame in 30 ms unless forced: 'F' w h y n
static void face_flush(bool force) {
  uint64_t now = clock_ms(1);
  if (m.fd < 0 || !m.drew || (!force && now - m.sent < 30)) return;
  uint32_t y0 = 0, y1 = m.h, w = m.w;
  if (!m.all) {
    while (y0 < m.h && !memcmp(m.fb + y0 * w, m.shown + y0 * w, w * 4)) y0++;
    while (y1 > y0 && !memcmp(m.fb + (y1 - 1) * w, m.shown + (y1 - 1) * w, w * 4)) y1--; }
  if (y0 < y1) {
    unsigned char h[9] = { 'F', w & 255, w >> 8, m.h & 255, m.h >> 8, y0 & 255, y0 >> 8,
                           (y1 - y0) & 255, (y1 - y0) >> 8 };
    face_out(h, 9);
    face_out(m.fb + y0 * w, (uintptr_t) (y1 - y0) * w * 4);
    memcpy(m.shown + y0 * w, m.fb + y0 * w, (uintptr_t) (y1 - y0) * w * 4); }
  m.drew = m.all = false, m.sent = now; }

void k_fb_touch(void) { m.drew = true; face_flush(false); }

// a key as a terminal sends it: what android's map types, else the keys with no text
static int face_key(int32_t code, int32_t c, unsigned char *o) {
  static char const *const esc[][2] = { {"\x13", "\e[A"}, {"\x14", "\e[B"}, {"\x15", "\e[D"},
    {"\x16", "\e[C"}, {"\x7a", "\e[H"}, {"\x7b", "\e[F"}, {"\x5c", "\e[5~"}, {"\x5d", "\e[6~"},
    {"\x70", "\e[3~"}, {"\x6f", "\e"}, {"\x43", "\x7f"}, {"\x42", "\r"}, {"\x3d", "\t"} };
  for (unsigned i = 0; i < sizeof esc / sizeof *esc; i++)
    if ((unsigned char) esc[i][0][0] == code) {
      int n = 0;
      for (char const *s = esc[i][1]; *s; s++) o[n++] = (unsigned char) *s;
      return n; }
  if (c <= 0) return 0;
  if (c < 0x80) return o[0] = (unsigned char) c, 1;
  if (c < 0x800) return o[0] = 0xc0 | c >> 6, o[1] = 0x80 | (c & 63), 2;
  if (c < 0x10000) return o[0] = 0xe0 | c >> 12, o[1] = 0x80 | (c >> 6 & 63), o[2] = 0x80 | (c & 63), 3;
  return o[0] = 0xf0 | c >> 18, o[1] = 0x80 | (c >> 12 & 63), o[2] = 0x80 | (c >> 6 & 63), o[3] = 0x80 | (c & 63), 4; }

static int32_t le32(unsigned char const *p) { return (int32_t) (p[0] | p[1] << 8 | p[2] << 16 | (uint32_t) p[3] << 24); }

// the bridge's records: keys into kmain's queue while it has room, a new size re-seats the
// paper, a touch asks for the keyboard. its end is the machine's
static void face_take(int room) {
  if (m.fd < 0) return;
  if (m.rn < sizeof m.r) {
    long k = __love_sys(NR_recvfrom, m.fd, (long) (m.r + m.rn), (long) (sizeof m.r - m.rn), 0x40, 0, 0);
    if (k == 0) leave(0);
    if (k > 0) m.rn += (unsigned) k; }
  unsigned at = 0;
  for (; at + 12 <= m.rn && room >= 8; at += 12) {
    unsigned char const *r = m.r + at;
    unsigned char o[8];
    int32_t b = le32(r + 4), c = le32(r + 8);
    if (r[0] == 'K' && r[1]) {
      int n = face_key(b, c, o);
      for (int i = 0; i < n; i++) kq(o[i]);
      room -= n; }
    else if (r[0] == 'S' && b > 0 && c > 0 && (uint32_t) b * (uint32_t) c <= m.cap
             && k_fb_reseat((unsigned) b, (unsigned) c, (unsigned) b, 0))
      m.w = (uint32_t) b, m.h = (uint32_t) c, m.all = m.drew = true; }
  for (unsigned i = at; i < m.rn; i++) m.r[i - at] = m.r[i];
  m.rn -= at; }

// the bridge's socket, its first size, and the paper carved off the top of the span: the
// most it may grow to, the copy of what was shown under it. -> the span the heap keeps
static uintptr_t face_open(uintptr_t base, uintptr_t len) {
  char const *p = getenv("LOVE_FACE");
  struct { unsigned short fam; char path[108]; } u = { 1, {0} };
  if (!p || strlen(p) >= sizeof u.path) return len;
  memcpy(u.path, p, strlen(p));
  long fd = sys(NR_socket, 1, 1 | 02000000, 0, 0);               // AF_UNIX, SOCK_STREAM|CLOEXEC
  if (fd < 0 || sys(NR_connect, fd, &u, sizeof u, 0)) return len;
  unsigned char r[12];
  for (;;) {
    for (unsigned got = 0; got < 12; ) {
      long k = sys(NR_read, fd, r + got, 12 - got, 0);
      if (k <= 0) return len;
      got += (unsigned) k; }
    if (r[0] == 'S') break; }
  uint32_t w = (uint32_t) le32(r + 4), h = (uint32_t) le32(r + 8), lo = w < h ? w : h,
           side = w > h ? w : h;
  if (side < 2 * lo) side = 2 * lo;                              // a keyboard may hide half of it
  uintptr_t cap = (uintptr_t) side * side, bytes = (cap * 4 + 4095) & ~(uintptr_t) 4095;
  if (!w || !h || 2 * bytes + (64u << 20) > len) return len;
  m.fd = (int) fd, m.w = w, m.h = h, m.cap = (uint32_t) cap, m.all = true;
  m.fb = (uint32_t *) (base + len - bytes), m.shown = (uint32_t *) (base + len - 2 * bytes);
  char const *e = getenv("LOVE_FACE_SCALE");
  long sc = e ? atol(e) : 0;
  kboot.fb.base = m.fb, kboot.fb.w = (uint16_t) w, kboot.fb.h = (uint16_t) h, kboot.fb.pitch_px = w;
  if (sc < 1 || sc > 8) sc = w / 320 < 1 ? 1 : w / 320 > 8 ? 8 : w / 320;   // a phone: forty columns or more
  kboot.fb.scale = (uint8_t) sc, kboot.fb.cap_px = (uint32_t) cap;
  kboot.has_fb = true;
  face_out("I\x01", 2);                                          // the keyboard, when focus lets it
  return len - 2 * bytes; }

// the keys stdin holds, as many as kmain's queue has room for. ctrl-] leaves, as under node;
// a pipe's end stops the reading, and the machine runs on to its own end
void k_kb_sync(int room) {
  unsigned char b[16];
  face_take(room);
  if (m.eof || room <= 0) return;
  long n = sys(NR_read, 0, b, room < 16 ? room : 16, 0);
  if (!n) m.eof = true;
  for (long i = 0; i < n; i++) b[i] == 0x1d && m.tty ? leave(0) : kq(b[i]); }

// the idle: a poll on stdin for one tick, then the keys and the clock
void k_idle(void) {
  struct { int fd; short ev, rev; } p[2] = { { m.eof ? -1 : 0, 1, 0 }, { m.fd, 1, 0 } };  // POLLIN
  long ts[2] = { 0, 10 * 1000000 };
  serial_drain();
  face_flush(true);
  sys(NR_ppoll, p, 2, ts, 0);
  k_kb_poll();
  k_tick_sync(); }

bool k_nap(uintptr_t ms) {
  long ts[2] = { (long) ms / 1000, (long) (ms % 1000) * 1000000 };
  serial_drain();
  face_flush(true);
  sys(NR_ppoll, 0, 0, ts, 0);
  k_kb_poll();
  k_tick_sync();
  return true; }

void k_reset(void) { leave(0); }

void k_fault_trigger(intptr_t n) { (void) n; __builtin_trap(); }

// the entry: moonlibc's runs as for any program, and main hands over here. the machine is
// the words after argv[0] as its boot line, one anonymous span as its ram, INLE_RAM MiB, and
// under the bridge (LOVE_FACE) a framebuffer console shown in its window
int k_droid_main(int argc, char const **argv) {
  char line[sizeof kboot.cmdline];
  uintptr_t n = 0;
  for (int i = 1; i < argc; i++) {
    if (i > 1 && n + 1 < sizeof line) line[n++] = ' ';
    for (char const *s = argv[i]; *s && n + 1 < sizeof line; s++) line[n++] = *s; }
  line[n] = 0;
  char const *e = getenv("INLE_RAM");
  long mib = e ? atol(e) : 0;
  uintptr_t len = (uintptr_t) (mib >= 64 ? mib : 512) << 20;
  long base = __love_sys(NR_mmap, 0, (long) len, 7, 0x22, -1, 0); // rwx, private anonymous
  if (base < 0 && base > -4096) leave(1);
  k_ram_give((uint64_t) base, face_open((uintptr_t) base, len));
  k_cmdline(line, n);
  kmain();
  return 0; }
