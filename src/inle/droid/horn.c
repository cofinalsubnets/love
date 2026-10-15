// the droid seat's sound card: love.h's k_horn_* and k_horn_in_* on the bridge's two sockets,
// HORN=sock:PATH and HORN_IN=sock:PATH, the wire src/love/horn.c's sock door speaks (the rate
// as a u32, its top byte the channels asked of the mic). with no HORN, a sink that keeps time
// and discards, a quarter second deep -- the host's HORN=none. with no HORN_IN, no mic.
#include <stdint.h>
#include "../../apps/moon/lib/moonlibc/impl.h"

#define sys(n, a, b, c, d) __love_sys(n, (long) (a), (long) (b), (long) (c), (long) (d), 0, 0)

// the sink's frames queued as of t, in ns; the sockets, and the paths the bridge named
static struct { uint64_t rate, held, t; int out, in; unsigned inch; char const *hp, *ip; } h = { .out = -1, .in = -1 };

// the bridge's paths, taken off the process's environment before the kernel runs
void k_droid_horn(char const *out, char const *in) {
  h.hp = out && !strncmp(out, "sock:", 5) ? out + 5 : 0;
  h.ip = in && !strncmp(in, "sock:", 5) ? in + 5 : 0; }

static uint64_t now_ns(void) {
  long ts[2];
  return sys(NR_clock_gettime, 1, ts, 0, 0) ? 0 : (uint64_t) ts[0] * 1000000000 + (uint64_t) ts[1]; }

// what has played since the last look comes off the queue
static void drain(void) {
  uint64_t t = now_ns(), gone = (t - h.t) * h.rate / 1000000000;
  if (!gone) return;
  h.held = gone < h.held ? h.held - gone : 0;
  h.t = t; }

static void shut(int *fd) { if (*fd >= 0) sys(NR_close, *fd, 0, 0, 0); *fd = -1; }

// a stream to the listener at path, the rate word said, then never waiting; -1 refused
static int dial(char const *path, int rate, unsigned inch) {
  struct { unsigned short fam; char path[108]; } u = { 1, {0} };
  if (strlen(path) >= sizeof u.path) return -1;
  memcpy(u.path, path, strlen(path));
  long fd = sys(NR_socket, 1, 1 | 02000000, 0, 0);               // AF_UNIX, SOCK_STREAM|CLOEXEC
  int q = 32768;                                                 // a slow frame's gap at 48k
  unsigned char r[4] = { (unsigned char) rate, (unsigned char) (rate >> 8), (unsigned char) (rate >> 16), (unsigned char) inch };
  if (fd < 0) return -1;
  if (!inch) __love_sys(NR_setsockopt, fd, 1, 7, (long) &q, 4, 0);   // SOL_SOCKET SO_SNDBUF
  if (sys(NR_connect, fd, &u, sizeof u, 0) || sys(NR_write, fd, r, 4, 0) != 4
      || sys(NR_fcntl, fd, 4, 04000, 0) < 0) {                   // F_SETFL O_NONBLOCK
    sys(NR_close, fd, 0, 0, 0);
    return -1; }
  return (int) fd; }

// the bytes a socket holds: unsent (SIOCOUTQ) or unread (SIOCINQ)
static uintptr_t queued(int fd, long op) { int q = 0; return sys(NR_ioctl, fd, op, &q, 0) < 0 ? 0 : (uintptr_t) q; }

int k_horn_open(int rate) {
  if (rate < 8000 || rate > 192000) return -1;
  shut(&h.out);
  if (h.hp) return (h.out = dial(h.hp, rate, 0)) < 0 ? -1 : 0;
  h.rate = (uint64_t) rate, h.held = 0, h.t = now_ns();
  return 0; }

// 16-bit stereo bytes, as many as fit behind what has played; a full socket takes none
intptr_t k_horn_write(unsigned char const *src, uintptr_t n) {
  if (h.out >= 0) {
    long k = sys(NR_write, h.out, src, n & ~(uintptr_t) 3, 0);
    return k == -11 ? 0 : k < 0 ? -1 : k & ~3L; }                // EAGAIN
  if (!h.rate) return -1;
  drain();
  uint64_t room = h.rate / 4 - h.held, f = n / 4 < room ? n / 4 : room;
  h.held += f;
  return (intptr_t) (f * 4); }

uintptr_t k_horn_lag(void) {
  if (h.out >= 0) return queued(h.out, 0x5411) / 4;
  if (h.rate) drain();
  return (uintptr_t) h.held; }

void k_horn_close(void) { shut(&h.out); h.rate = 0, h.held = 0; }

int k_horn_in_open(int rate, int chans) {
  shut(&h.in);
  if (!h.ip || rate < 8000 || rate > 192000 || chans < 1 || chans > 2) return -1;
  h.inch = (unsigned) chans;
  return (h.in = dial(h.ip, rate, h.inch)) < 0 ? -1 : 0; }

// what the mic has heard, in whole frames: a frame split across reads is waited out, a
// second at most; 0 when dry, -1 once the bridge is gone
intptr_t k_horn_read(unsigned char *dst, uintptr_t n) {
  uintptr_t fb = 2 * h.inch;
  if (h.in < 0 || !fb) return -1;
  n -= n % fb;
  long k = n ? sys(NR_read, h.in, dst, n, 0) : 0;
  if (k == -11) return 0;
  if (k <= 0) return n ? -1 : 0;
  for (int w = 0; (uintptr_t) k % fb; w++) {
    struct { int fd; short ev, rev; } p = { h.in, 1, 0 };
    long ts[2] = { 0, 100 * 1000000 };
    if (w == 10) return -1;
    sys(NR_ppoll, &p, 1, ts, 0);
    long j = sys(NR_read, h.in, dst + k, fb - (uintptr_t) k % fb, 0);
    if (j == 0 || (j < 0 && j != -11 && j != -4)) return -1;
    if (j > 0) k += j; }
  return k; }

uintptr_t k_horn_in_lag(void) { return h.in < 0 || !h.inch ? 0 : queued(h.in, 0x541B) / (2 * h.inch); }

void k_horn_in_close(void) { shut(&h.in); }
