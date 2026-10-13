// droid architecture-specific C: inle as a linux process, the phone's seat (notes/plan/inle-droid.md).
// the wasm seat's contract (src/inle/wasm/arch.c) answered by a real kernel: each face below is
// one system call through __love_sys, moonlibc's raw tail, which kmain's __love_osv = -1 never
// reaches -- moonlibc's own calls take src/inle/sys.c's answers, as on every other seat. the
// serial line is fds 0 and 1; the reset ends the process, as node's terminal does.
#include <stdint.h>
#include <stdbool.h>
#include <errno.h>
#include "../../apps/moon/lib/moonlibc/impl.h"
#include "asmops.h"
#include "k.h"

void kq(uint8_t);
void kmain(void);
void k_kb_poll(void);

#define sys(n, a, b, c, d) __love_sys(n, (long) (a), (long) (b), (long) (c), (long) (d), 0, 0)

// the terminal as it was found, put back at the end; a tty reads raw while the machine runs.
// kernel termios: four flag words, the line, the controls
struct k_tio { uint32_t i, o, c, l; uint8_t line, cc[19]; };
static struct { struct k_tio was; bool tty, eof; uint64_t tick; unsigned n; unsigned char b[2048]; } m;

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

// the keys stdin holds, as many as kmain's queue has room for. ctrl-] leaves, as under node;
// a pipe's end stops the reading, and the machine runs on to its own end
void k_kb_sync(int room) {
  unsigned char b[16];
  if (m.eof || room <= 0) return;
  long n = sys(NR_read, 0, b, room < 16 ? room : 16, 0);
  if (!n) m.eof = true;
  for (long i = 0; i < n; i++) b[i] == 0x1d && m.tty ? leave(0) : kq(b[i]); }

// the idle: a poll on stdin for one tick, then the keys and the clock
void k_idle(void) {
  struct { int fd; short ev, rev; } p = { 0, 1, 0 };             // POLLIN
  long ts[2] = { 0, 10 * 1000000 };
  serial_drain();
  sys(NR_ppoll, &p, m.eof ? 0 : 1, ts, 0);
  k_kb_poll();
  k_tick_sync(); }

bool k_nap(uintptr_t ms) {
  long ts[2] = { (long) ms / 1000, (long) (ms % 1000) * 1000000 };
  serial_drain();
  sys(NR_ppoll, 0, 0, ts, 0);
  k_kb_poll();
  k_tick_sync();
  return true; }

void k_reset(void) { leave(0); }

void k_fault_trigger(intptr_t n) { (void) n; __builtin_trap(); }

// the entry: moonlibc's runs as for any program, and main hands over here. the machine is
// the words after argv[0] as its boot line and one anonymous span as its ram, INLE_RAM MiB
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
  k_ram_give((uint64_t) base, len);
  k_cmdline(line, n);
  kmain();
  return 0; }
