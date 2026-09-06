// src/host/horn.c -- the horn: PCM out as a port, on every seat (doc/misc/plan/horn.md).
//
//   (horn rate chans)   open the sound device -> a port | an errno nom | 'badarg.
//                       16-bit little-endian samples go out through the ordinary
//                       write path; 1 or 2 channels, the rate in 8000..192000.
//   (horn-lag port)     frames written and not yet played, or () for a non-horn.
//
// the port wears the fd port's shape (love.h: ai_horn_vt is a bio to io.c), so a
// full device answers 0 at the door, the write run keeps the residue and the task
// parks on the 1 ms poll every heap port already has -- backpressure, never a
// dropped frame. the device under the door is per seat:
//   - inle: the C face, k_horn_* (src/inle/hda.c)
//   - linux: /dev/snd/pcmC*D*p by ALSA's ioctls, no libasound -- plain syscalls only
//   - freebsd: /dev/dsp, the three OSS ioctls and write(2)
//   - HORN=none in the environment: a sink that keeps time and discards, so a box
//     without a card (and every gate) still sees the shape: the ring fills, refuses,
//     drains at the rate. HORN=<path> names the device instead of the first found.
// a mono port is doubled to stereo on the way down, so the device is always stereo.
#include "love.h"
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <fcntl.h>
#include <sys/ioctl.h>

// stand-ins for a link with no src/inle/hda.c under it
__attribute__((weak)) int k_horn_open(int rate) { return -1; }
__attribute__((weak)) intptr_t k_horn_write(unsigned char const *src, uintptr_t n) { return -1; }
__attribute__((weak)) uintptr_t k_horn_lag(void) { return 0; }
__attribute__((weak)) void k_horn_close(void) { }

enum { horn_sink, horn_dev, horn_seat };
// the port: the bio, then the device's words, all charms. wpos and t0 are the sink's
// clock (frames landed, and the ms the drain is reckoned from); the others hold the open.
struct ai_horn { struct ai_bio b; ai_word kind, rate, chans, wpos, t0; };

// the sink keeps a quarter second: what a small card's ring holds
#define sink_ms 250

// --- linux: ALSA by ioctl ---------------------------------------------------------
#if defined(__linux__)
// sound/asound.h's shapes, the ones the handshake needs and no more. an interval's
// four flag bits ride one word: openmin 1, openmax 2, integer 4, empty 8.
struct snd_interval { uint32_t min, max, flags; };
struct snd_mask { uint32_t bits[8]; };
struct snd_pcm_hw_params {
 uint32_t flags;
 struct snd_mask masks[3], mres[5];          // access, format, subformat
 struct snd_interval intervals[12], ires[9]; // sample_bits .. tick_time, from index 8
 uint32_t rmask, cmask, info, msbits, rate_num, rate_den;
 unsigned long fifo_size;
 unsigned char reserved[64]; };
struct snd_xferi { long result; void *buf; unsigned long frames; };
#define ALSA_HW_PARAMS   _IOWR('A', 0x11, struct snd_pcm_hw_params)
#define ALSA_DELAY       _IOR('A', 0x21, long)
#define ALSA_PREPARE     _IO('A', 0x40)
// interval rows, less the first mask-free index (8)
enum { iv_sample_bits, iv_frame_bits, iv_channels, iv_rate, iv_period_time, iv_period_size,
       iv_period_bytes, iv_periods, iv_buffer_time, iv_buffer_size };

static void iv_set(struct snd_interval *v, uint32_t lo, uint32_t hi) {
 v->min = lo, v->max = hi, v->flags = 4; }

// the handshake on an open pcm fd: interleaved s16, the rate, stereo, and a buffer of
// 4096..32768 frames (the kernel picks the least: ~85 ms at 48k, a game's lag and a
// stream's comfort both). -> 0, or the negated errno.
static int alsa_setup(int fd, int rate) {
 struct snd_pcm_hw_params p;
 memset(&p, 0, sizeof p);
 for (int i = 0; i < 3; i++) memset(p.masks[i].bits, 0xff, sizeof p.masks[i].bits);
 for (int i = 0; i < 12; i++) p.intervals[i].min = 0, p.intervals[i].max = ~0u;
 memset(p.masks[0].bits, 0, sizeof p.masks[0].bits); p.masks[0].bits[0] = 1u << 3;   // RW_INTERLEAVED
 memset(p.masks[1].bits, 0, sizeof p.masks[1].bits); p.masks[1].bits[0] = 1u << 2;   // S16_LE
 memset(p.masks[2].bits, 0, sizeof p.masks[2].bits); p.masks[2].bits[0] = 1u << 0;   // STD
 iv_set(&p.intervals[iv_sample_bits], 16, 16);
 iv_set(&p.intervals[iv_frame_bits], 32, 32);
 iv_set(&p.intervals[iv_channels], 2, 2);
 iv_set(&p.intervals[iv_rate], (uint32_t) rate, (uint32_t) rate);
 iv_set(&p.intervals[iv_period_size], 512, 4096);
 iv_set(&p.intervals[iv_buffer_size], 4096, 32768);
 p.rmask = ~0u;
 if (ioctl(fd, ALSA_HW_PARAMS, &p) < 0) return -errno;
 if (ioctl(fd, ALSA_PREPARE) < 0) return -errno;
 return 0; }

// the first playback node under /dev/snd, or the named one. the order is the card
// order and nothing wiser: a box whose first node is an HDMI port names its own in HORN.
static int dev_open(char const *name, int rate, int *err) {
 char nm[40];
 for (int c = 0; c < 8; c++)
  for (int d = 0; d < 32; d++) {
   char const *path = name;
   if (!name) {
    char *q = nm;
    memcpy(q, "/dev/snd/pcmC", 13); q += 13;
    *q++ = (char) ('0' + c);
    *q++ = 'D';
    if (d >= 10) *q++ = (char) ('0' + d / 10);
    *q++ = (char) ('0' + d % 10);
    *q++ = 'p'; *q = 0;
    path = nm; }
   int fd = open(path, O_WRONLY | O_NONBLOCK | O_CLOEXEC);
   if (fd < 0) { *err = errno; if (name) return -1; continue; }
   int e = alsa_setup(fd, rate);
   if (!e) return fd;
   close(fd);
   *err = -e;
   if (name) return -1; }
 if (!name) *err = ENODEV;
 return -1; }

// write(2) on a pcm fd is WRITEI_FRAMES by another door: whole frames land, a full
// ring is EAGAIN, an underrun is EPIPE and wants a prepare before the retry.
static intptr_t dev_land(int fd, unsigned char const *src, uintptr_t n) {
 for (int again = 0; ; again++) {
  ssize_t k = write(fd, src, n);
  if (k >= 0) return (intptr_t) k;
  if (errno == EINTR) continue;
  if (errno == EAGAIN) return 0;
  if (errno == EPIPE && !again && !ioctl(fd, ALSA_PREPARE)) continue;
  return -1; } }

static uintptr_t dev_lag(int fd) {
 long f = 0;
 return ioctl(fd, ALSA_DELAY, &f) < 0 || f < 0 ? 0 : (uintptr_t) f; }

// --- freebsd: OSS on /dev/dsp ------------------------------------------------------
#elif defined(__FreeBSD__)
// the ioctl words are BSD's encoding, not the _IOC this libc spells (linux's):
// IOC_INOUT | 4 << 16 | 'P' << 8 | n
#define OSS_SETFMT    0xc0045005u
#define OSS_SPEED     0xc0045002u
#define OSS_CHANNELS  0xc0045006u
#define OSS_GETODELAY 0x40045017u
#define OSS_S16_LE    0x10

static int dev_open(char const *name, int rate, int *err) {
 int fd = open(name ? name : "/dev/dsp", O_WRONLY | O_NONBLOCK | O_CLOEXEC);
 if (fd < 0) return *err = errno, -1;
 int v = OSS_S16_LE, ch = 2, r = rate;
 if (ioctl(fd, OSS_SETFMT, &v) < 0 || v != OSS_S16_LE || ioctl(fd, OSS_CHANNELS, &ch) < 0 || ch != 2
     || ioctl(fd, OSS_SPEED, &r) < 0 || r != rate) {
  *err = errno ? errno : EINVAL;
  return close(fd), -1; }
 return fd; }

static intptr_t dev_land(int fd, unsigned char const *src, uintptr_t n) {
 ssize_t k;
 do k = write(fd, src, n); while (k < 0 && errno == EINTR);
 return k >= 0 ? (intptr_t) k : errno == EAGAIN ? 0 : -1; }

static uintptr_t dev_lag(int fd) {
 int b = 0;
 return ioctl(fd, OSS_GETODELAY, &b) < 0 || b < 0 ? 0 : (uintptr_t) b / 4; }

// --- anywhere else: no device door, the sink alone ---------------------------------
#else
static int dev_open(char const *name, int rate, int *err) { return *err = ENODEV, -1; }
static intptr_t dev_land(int fd, unsigned char const *src, uintptr_t n) { return -1; }
static uintptr_t dev_lag(int fd) { return 0; }
#endif

// --- the sink: a ring that keeps time --------------------------------------------
// frames played since t0 at the rate; the ring is sink_ms deep. an underrun (the
// clock passed the writer) re-bases t0 so the writer starts a fresh run.
static uintptr_t sink_played(struct ai_horn *h) {
 uintptr_t now = ai_clock(), t0 = (uintptr_t) getcharm(h->t0), rate = (uintptr_t) getcharm(h->rate),
           wpos = (uintptr_t) getcharm(h->wpos);
 uintptr_t played = now > t0 ? (now - t0) * rate / 1000 : 0;
 if (played > wpos) { played = wpos; h->t0 = putcharm((intptr_t) (now - wpos * 1000 / rate)); }
 return played; }

static uintptr_t sink_land(struct ai_horn *h, uintptr_t frames) {
 uintptr_t played = sink_played(h), rate = (uintptr_t) getcharm(h->rate),
           wpos = (uintptr_t) getcharm(h->wpos), cap = rate * sink_ms / 1000, queued = wpos - played;
 uintptr_t room = cap > queued ? cap - queued : 0;
 if (frames > room) frames = room;
 h->wpos = putcharm((intptr_t) (wpos + frames));
 return frames; }

// --- the door -------------------------------------------------------------------
// a stereo run goes down as it is; a mono one is doubled through a stack frame,
// and what the device took is answered in the caller's bytes.
static intptr_t horn_land(struct ai_horn *h, unsigned char const *src, uintptr_t n) {
 int kind = (int) getcharm(h->kind), fd = (int) getcharm(h->b.f.fd);
 if (getcharm(h->chans) == 2)
  return kind == horn_dev ? dev_land(fd, src, n) : k_horn_write(src, n);
 unsigned char t[4096];
 if (n > sizeof t / 2) n = sizeof t / 2;
 for (uintptr_t i = 0; i < n; i += 2)
  t[2 * i] = t[2 * i + 2] = src[i], t[2 * i + 1] = t[2 * i + 3] = src[i + 1];
 intptr_t k = kind == horn_dev ? dev_land(fd, t, 2 * n) : k_horn_write(t, 2 * n);
 return k > 0 ? k / 2 : k; }

struct ai *ai_horn_writen(struct ai *g, unsigned char const *src, uintptr_t n) {
 struct ai_horn *h = (struct ai_horn*) g->io;
 uintptr_t fb = 2 * (uintptr_t) getcharm(h->chans);
 if (n < fb) return g->b = (intptr_t) n, g;        // a stray partial frame is noise: taken, unplayed
 n -= n % fb;
 intptr_t k = getcharm(h->kind) == horn_sink ? (intptr_t) (sink_land(h, n / fb) * fb)
            : horn_land(h, src, n);
 return g->b = k, g; }

// the finalizer, inside GC: shut the device. the fd lane's fd is io_close's too, but
// that one only runs for the fd port; this port's close is its own.
static void horn_fin(struct ai *g, void *p) {
 struct ai_horn *h = p;
 int kind = (int) getcharm(h->kind);
 intptr_t fd = getcharm(h->b.f.fd);
 if (kind == horn_dev && fd >= 0) close((int) fd);
 else if (kind == horn_seat) k_horn_close();
 h->b.f.fd = putcharm(-1);
 h->kind = putcharm(horn_sink); }

// `close` on a horn (src/host/posix.c): the same shutting, outside GC
void ai_horn_close(struct ai_io *io) { horn_fin(NULL, io); }

// (horn rate chans) -> the port at sp[2], over the two args
ai_noinline static struct ai *horn_open(struct ai *g) {
 ai_word rw = g->sp[0], cw = g->sp[1];
 intptr_t rate = (rw & 1) ? getcharm(rw) : -1, chans = (cw & 1) ? getcharm(cw) : -1;
 if (rate < 8000 || rate > 192000 || chans < 1 || chans > 2)
  return g->sp[1] = ai_badarg(g), g->sp += 1, g;
 int kind = horn_sink, fd = -1, err = 0;
 if (__ai_osv < 0) {
  if (k_horn_open((int) rate) < 0) return g->sp[1] = ai_err(g, ENODEV), g->sp += 1, g;
  kind = horn_seat; }
 else {
  char const *dev = getenv("HORN");
  if (!dev || strcmp(dev, "none")) {
   fd = dev_open(dev, (int) rate, &err);
   if (fd < 0) return g->sp[1] = ai_err(g, err), g->sp += 1, g;
   kind = horn_dev; } }
 uintptr_t const n = Width(struct ai_horn);
 if (!ai_ok(g = ai_have(g, n + Width(struct ai_tag) + Width(struct ai_fz) + 1))) {
  if (kind == horn_dev) close(fd); else if (kind == horn_seat) k_horn_close();
  return g; }
 union u *k = bump(g, n + Width(struct ai_tag));
 struct ai_horn *h = (struct ai_horn*) k;
 h->b.f.io.ap = lvm_port_io;
 h->b.f.io.vt = &ai_horn_vt;
 h->b.f.io.ungetc_buf = putcharm(EOF);
 h->b.f.fd = putcharm(fd);
 h->b.rbuf = h->b.wbuf = 0;
 h->b.rpos = h->b.rlen = h->b.wlen = putcharm(0);
 h->kind = putcharm(kind);
 h->rate = putcharm(rate);
 h->chans = putcharm(chans);
 h->wpos = putcharm(0);
 h->t0 = putcharm((intptr_t) ai_clock());
 *--g->sp = (word) tagthread(k, n);
 struct ai_fz *z = bump(g, Width(struct ai_fz));
 z->p = k, z->fn = horn_fin, z->next = g->fz, g->fz = z;
 return g->sp[2] = g->sp[0], g->sp += 2, g; }

static lvm(lvm_horn) {
 LvmCall(g, horn_open) }

// (horn-lag p) -> frames queued and unplayed | () for anything but an open horn
static lvm(lvm_horn_lag) {
 ai_word x = Sp[0];
 if (charmp(x) || cell(x)->ap != lvm_port_io || ((struct ai_io*) x)->vt != &ai_horn_vt)
  ai_musttail return Answer(ZeroPoint);
 struct ai_horn *h = (struct ai_horn*) x;
 uintptr_t lag;
 switch ((int) getcharm(h->kind)) {
  case horn_sink: lag = (uintptr_t) getcharm(h->wpos) - sink_played(h); break;
  case horn_dev: lag = dev_lag((int) getcharm(h->b.f.fd)); break;
  default: lag = k_horn_lag(); }
 ai_musttail return Answer(putcharm((intptr_t) lag)); }

static union u const
 nif_horn[] = {{lvm_cur}, {.x = putcharm(2)}, {lvm_horn}, {lvm_ret0}},
 nif_horn_lag[] = {{lvm_horn_lag}, {lvm_ret0}};
AiNif("horn", nif_horn);
AiNif("horn-lag", nif_horn_lag);
