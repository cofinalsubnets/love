// horn.c -- pcm out and in as a port, on every seat
//   (horn rate chans)     the sound device -> a port | an errno nom | 'badarg: s16le written
//                         on the ordinary path, 1 or 2 channels, the rate in 8000..192000
//   (horn-in rate chans)  the capture device the same way, read; a dry one parks the reader
//   (horn-lag port)       frames unplayed (out) or unread (in), the port's pending run
//                         included; () for a non-horn
// a bio to io.c, so a full device answers 0 and the task parks: backpressure, never a drop.
// the device, by __love_osv at run time:
//   - inle: k_horn_* (inle/hda.c)
//   - linux: /dev/snd/pcmC*D*p (capture *c) by ALSA ioctls, no libasound
//   - freebsd: /dev/dsp, OSS; netbsd: /dev/sound, audio(4)
//   - HORN=sock:PATH: a unix listener (the droid bridge): a le u32 rate, then stereo frames;
//     HORN_IN=sock:PATH the same, the u32's top byte the channels
//   - HORN=none: a sink that keeps time and discards, so every gate sees the ring's shape;
//     HORN=<path> names the device. HORN_IN likewise, its none silence at the rate
//   - a board: -D love_horn_seat=1 on its roster, the seat answering k_horn_* as hda.c does
// the device is always stereo (mono doubled); capture keeps the device's count and width,
// the top 16 bits mixed or doubled to the caller's
#include "love.h"
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <fcntl.h>
#include <sys/ioctl.h>

// declared here for a link with no hda.c
int k_horn_open(int rate);
intptr_t k_horn_write(unsigned char const *src, uintptr_t n);
uintptr_t k_horn_lag(void);
void k_horn_close(void);

enum { horn_sink, horn_dev, horn_seat, horn_sock, horn_seat_in };
// all charms. wpos, t0: the sink's frames and the ms it drains from; dir 0 out, 1 in;
// dchans, dwid: the device's channels and bytes a sample
struct horn { struct bio b; word kind, rate, chans, wpos, t0, dir, dchans, dwid; };

// the sink keeps a quarter second: what a small card's ring holds
#define sink_ms 250

// the doors this build carries: moonlibc carries all and picks at run time, so the bytes never
// depend on the build box (love seed's fixpoint). a seat is freestanding, no open/ioctl: none
#ifndef love_horn_seat
#define love_horn_seat 0
#endif
#if love_horn_seat
# define horn_alsa 0
# define horn_oss  0
#elif defined(__wasm__)
# define horn_alsa 0
# define horn_oss  0
#elif defined(__moonlibc__)
# define horn_alsa 1
# define horn_oss  1
# define horn_sun  1
#elif defined(__linux__)
# define horn_alsa 1
# define horn_oss  0
#elif defined(__FreeBSD__)
# define horn_alsa 0
# define horn_oss  1
#elif defined(__NetBSD__)
# define horn_alsa 0
# define horn_oss  0
# define horn_sun  1
#else
# define horn_alsa 0
# define horn_oss  0
#endif
#ifndef horn_sun
#define horn_sun 0
#endif

// linux: ALSA by ioctl
#if horn_alsa
// sound/asound.h's shapes, only the handshake's; interval flags openmin 1, openmax 2, integer 4, empty 8
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
#define ALSA_START       _IO('A', 0x42)
// interval rows, less the first mask-free index (8)
enum { iv_sample_bits, iv_frame_bits, iv_channels, iv_rate, iv_period_time, iv_period_size,
       iv_period_bytes, iv_periods, iv_buffer_time, iv_buffer_size };

static void iv_set(struct snd_interval *v, uint32_t lo, uint32_t hi) {
 v->min = lo, v->max = hi, v->flags = 4; }

// interleaved s16 (s32 at wid 4), and a buffer of 4096..32768 frames, the kernel taking the
// least (~85 ms at 48k) -> 0 | -errno
static int alsa_setup(int fd, int rate, int chans, int wid) {
 struct snd_pcm_hw_params p;
 memset(&p, 0, sizeof p);
 for (int i = 0; i < 3; i++) memset(p.masks[i].bits, 0xff, sizeof p.masks[i].bits);
 for (int i = 0; i < 12; i++) p.intervals[i].min = 0, p.intervals[i].max = ~0u;
 memset(p.masks[0].bits, 0, sizeof p.masks[0].bits); p.masks[0].bits[0] = 1u << 3;   // RW_INTERLEAVED
 memset(p.masks[1].bits, 0, sizeof p.masks[1].bits); p.masks[1].bits[0] = 1u << (wid == 4 ? 10 : 2); // S32_LE, S16_LE
 memset(p.masks[2].bits, 0, sizeof p.masks[2].bits); p.masks[2].bits[0] = 1u << 0;   // STD
 uint32_t bits = 8 * (uint32_t) wid;
 iv_set(&p.intervals[iv_sample_bits], bits, bits);
 iv_set(&p.intervals[iv_frame_bits], bits * (uint32_t) chans, bits * (uint32_t) chans);
 iv_set(&p.intervals[iv_channels], (uint32_t) chans, (uint32_t) chans);
 iv_set(&p.intervals[iv_rate], (uint32_t) rate, (uint32_t) rate);
 iv_set(&p.intervals[iv_period_size], 512, 4096);
 iv_set(&p.intervals[iv_buffer_size], 4096, 32768);
 p.rmask = ~0u;
 if (ioctl(fd, ALSA_HW_PARAMS, &p) < 0) return -errno;
 if (ioctl(fd, ALSA_PREPARE) < 0) return -errno;
 return 0; }

// the first node in card order, or the named one. playback is s16 stereo; capture tries *chans,
// the other count, then s32, answering in *chans and *wid, and starts filling from the open
static int alsa_open(char const *name, int rate, int dir, int *chans, int *wid, int *err) {
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
    *q++ = dir ? 'c' : 'p'; *q = 0;
    path = nm; }
   int fd = open(path, (dir ? O_RDONLY : O_WRONLY) | O_NONBLOCK | O_CLOEXEC);
   if (fd < 0) { *err = errno; if (name) return -1; continue; }
   int e = alsa_setup(fd, rate, *chans, 2);
   for (int k = 1; e && dir && k < 4; k++)            // the other count, then s32 with each
    if (!alsa_setup(fd, rate, k & 1 ? 3 - *chans : *chans, k < 2 ? 2 : 4))
     e = 0, *chans = k & 1 ? 3 - *chans : *chans, *wid = k < 2 ? 2 : 4;
   if (!e && dir && ioctl(fd, ALSA_START) < 0) e = -errno;
   if (!e) return fd;
   close(fd);
   *err = -e;
   if (name) return -1; }
 if (!name) *err = ENODEV;
 return -1; }

// whole frames; full is EAGAIN, an underrun EPIPE, which wants a prepare before the retry
static intptr_t alsa_land(int fd, unsigned char const *src, uintptr_t n) {
 for (int again = 0; ; again++) {
  ssize_t k = write(fd, src, n);
  if (k >= 0) return (intptr_t) k;
  if (errno == EINTR) continue;
  if (errno == EAGAIN) return 0;
  if (errno == EPIPE && !again && !ioctl(fd, ALSA_PREPARE)) continue;
  return -1; } }

// dry is EAGAIN; an overrun (EPIPE) restarts the stream and answers nothing yet
static intptr_t alsa_take(int fd, unsigned char *dst, uintptr_t n) {
 for (;;) {
  ssize_t k = read(fd, dst, n);
  if (k >= 0) return (intptr_t) k;
  if (errno == EINTR) continue;
  if (errno == EAGAIN) return 0;
  if (errno == EPIPE && !ioctl(fd, ALSA_PREPARE) && !ioctl(fd, ALSA_START)) return 0;
  return -1; } }

// the frames the device holds either way: unplayed out, or heard and unread in
static uintptr_t alsa_lag(int fd) {
 long f = 0;
 return ioctl(fd, ALSA_DELAY, &f) < 0 || f < 0 ? 0 : (uintptr_t) f; }

#endif

// freebsd: OSS on /dev/dsp
#if horn_oss
// by this libc's _IOC: a native one lays BSD's, moonlibc linux's and its ioctl translates
#define OSS_SETFMT    _IOWR('P', 5, int)
#define OSS_SPEED     _IOWR('P', 2, int)
#define OSS_CHANNELS  _IOWR('P', 6, int)
#define OSS_GETODELAY _IOR('P', 23, int)
#define OSS_TRIGGER   _IOW('P', 16, int)
#define OSS_S16_LE    0x10
#endif

#if horn_oss
// playback is stereo; capture asks for *chans and keeps the count the device settles on
static int oss_open(char const *name, int rate, int dir, int *chans, int *err) {
 int fd = open(name ? name : "/dev/dsp", (dir ? O_RDONLY : O_WRONLY) | O_NONBLOCK | O_CLOEXEC);
 if (fd < 0) return *err = errno, -1;
 int v = OSS_S16_LE, ch = *chans, r = rate;
 errno = 0;
 if (ioctl(fd, OSS_SETFMT, &v) < 0 || v != OSS_S16_LE || ioctl(fd, OSS_CHANNELS, &ch) < 0
     || (dir ? ch < 1 || ch > 2 : ch != 2) || ioctl(fd, OSS_SPEED, &r) < 0 || r != rate) {
  *err = errno ? errno : EINVAL;
  return close(fd), -1; }
 int on = 1;                                        // PCM_ENABLE_INPUT: hear from the open
 if (dir) (void) ioctl(fd, OSS_TRIGGER, &on);
 *chans = ch;
 return fd; }

static intptr_t oss_land(int fd, unsigned char const *src, uintptr_t n) {
 ssize_t k;
 do k = write(fd, src, n); while (k < 0 && errno == EINTR);
 return k >= 0 ? (intptr_t) k : errno == EAGAIN ? 0 : -1; }

static intptr_t oss_take(int fd, unsigned char *dst, uintptr_t n) {
 ssize_t k;
 do k = read(fd, dst, n); while (k < 0 && errno == EINTR);
 return k >= 0 ? (intptr_t) k : errno == EAGAIN ? 0 : -1; }

// fb is a device frame's bytes
static uintptr_t oss_lag(int fd, int dir, uintptr_t fb) {
 int b = 0;
 return ioctl(fd, dir ? FIONREAD : OSS_GETODELAY, &b) < 0 || b < 0 ? 0 : (uintptr_t) b / fb; }

#endif

// netbsd: audio(4) on /dev/sound
#if horn_sun
// sys/audioio.h as netbsd 10 lays it: seek is a u_int whatever the man page says, the info
// 136 bytes. INITINFO's all-ones is "leave it"
struct sun_prinfo {
 uint32_t sample_rate, channels, precision, encoding, gain, port, seek, avail_ports,
          buffer_size, ispare, samples, eof;
 unsigned char pause, error, waiting, balance, cspare[2], open, active; };
struct sun_info { struct sun_prinfo play, record;
                  uint32_t monitor_gain, blocksize, hiwat, lowat, ispare1, mode; };
#define SUN_GETINFO    _IOR('A', 21, struct sun_info)
#define SUN_SETINFO    _IOWR('A', 22, struct sun_info)
#define SUN_GETBUFINFO _IOR('A', 35, struct sun_info)
#define SUN_SLINEAR_LE 6

// the kernel converts any rate and count: GETINFO's read-back is the proof, not SETINFO's answer
static int sun_open(char const *name, int rate, int dir, int *chans, int *err) {
 int fd = open(name ? name : "/dev/sound", (dir ? O_RDONLY : O_WRONLY) | O_NONBLOCK | O_CLOEXEC);
 if (fd < 0) return *err = errno, -1;
 struct sun_info a, b;
 memset(&a, 0xff, sizeof a);
 struct sun_prinfo *p = dir ? &a.record : &a.play;
 p->sample_rate = (uint32_t) rate, p->channels = (uint32_t) *chans, p->precision = 16;
 p->encoding = SUN_SLINEAR_LE;
 errno = 0;
 if (ioctl(fd, SUN_SETINFO, &a) < 0 || ioctl(fd, SUN_GETINFO, &b) < 0) {
  *err = errno ? errno : EINVAL;
  return close(fd), -1; }
 p = dir ? &b.record : &b.play;
 if (p->sample_rate != (uint32_t) rate || p->channels != (uint32_t) *chans || p->precision != 16
     || p->encoding != SUN_SLINEAR_LE) {
  *err = EINVAL;
  return close(fd), -1; }
 return fd; }

// read(2) and write(2) are the same door either way: a full or a dry track is EAGAIN
static intptr_t sun_io(int fd, int dir, unsigned char *buf, uintptr_t n) {
 ssize_t k;
 do k = dir ? read(fd, buf, n) : write(fd, buf, n); while (k < 0 && errno == EINTR);
 return k >= 0 ? (intptr_t) k : errno == EAGAIN ? 0 : -1; }

// out: the bytes the track still holds, its seek; in: the bytes ready to read
static uintptr_t sun_lag(int fd, int dir, uintptr_t fb) {
 if (dir) {
  int b = 0;
  return ioctl(fd, FIONREAD, &b) < 0 || b < 0 ? 0 : (uintptr_t) b / fb; }
 struct sun_info a;
 return ioctl(fd, SUN_GETBUFINFO, &a) < 0 ? 0 : a.play.seek / fb; }

#endif

// a socket listener: nonblocking once the rate is said, so a full socket is a full ring and
// SIOCOUTQ the lag; the rate word's top byte is capture's channels, 0 playback
#if !love_horn_seat && !defined(__wasm__)
#define horn_sockdoor 1
#include <sys/socket.h>
#include <sys/un.h>
#include <poll.h>
static int sock_open(char const *path, int rate, int inch, int *err) {
 struct sockaddr_un u = {.sun_family = AF_UNIX};
 if (strlen(path) >= sizeof u.sun_path) return *err = ENAMETOOLONG, -1;
 strcpy(u.sun_path, path);
 int fd = socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0), q = 32768;   // ~340 ms at 48k once doubled: a slow frame's gap
 if (fd >= 0) setsockopt(fd, SOL_SOCKET, SO_SNDBUF, &q, sizeof q);
 unsigned char r[4] = {(unsigned char) rate, (unsigned char) (rate >> 8), (unsigned char) (rate >> 16), (unsigned char) inch};
 if (fd < 0 || connect(fd, (struct sockaddr*) &u, sizeof u) < 0 || write(fd, r, 4) != 4
     || fcntl(fd, F_SETFL, O_NONBLOCK) < 0) {
  *err = errno;
  if (fd >= 0) close(fd);
  return -1; }
 return fd; }
static intptr_t sock_land(int fd, unsigned char const *src, uintptr_t n) {
 intptr_t k = write(fd, src, n & ~(uintptr_t) 3);
 return k < 0 && errno == EAGAIN ? 0 : k < 0 ? -1 : k & ~(intptr_t) 3; }
// the frames not yet sent out (SIOCOUTQ), or heard and not yet read in (SIOCINQ)
static uintptr_t sock_lag(int fd, int dir, uintptr_t fb) {
 int q = 0;
 return ioctl(fd, dir ? 0x541B : 0x5411, &q) < 0 ? 0 : (uintptr_t) q / fb; }
// whole frames of fb bytes: a split frame is waited out, a second at most; 0 dry, -1 gone
static intptr_t sock_take(int fd, unsigned char *dst, uintptr_t n, uintptr_t fb) {
 intptr_t k = read(fd, dst, n);
 if (k <= 0) return k < 0 && errno == EAGAIN ? 0 : -1;
 for (int w = 0; (uintptr_t) k % fb; w++) {
  struct pollfd p = {.fd = fd, .events = POLLIN};
  if (w == 10 || (poll(&p, 1, 100) < 0 && errno != EINTR)) return -1;
  intptr_t j = read(fd, dst + k, fb - (uintptr_t) k % fb);
  if (j == 0 || (j < 0 && errno != EAGAIN && errno != EINTR)) return -1;
  if (j > 0) k += j; }
 return k; }
static void sock_shut(int fd) { close(fd); }
#else
#define horn_sockdoor 0
static int sock_open(char const *path, int rate, int inch, int *err) { return *err = ENODEV, -1; }
static intptr_t sock_land(int fd, unsigned char const *src, uintptr_t n) { return -1; }
static intptr_t sock_take(int fd, unsigned char *dst, uintptr_t n, uintptr_t fb) { return -1; }
static uintptr_t sock_lag(int fd, int dir, uintptr_t fb) { return 0; }
static void sock_shut(int fd) { (void) fd; }
#endif
static int horn_sock_name(char const *dev) { return horn_sockdoor && dev && !strncmp(dev, "sock:", 5); }

// the door by the kernel we woke on, else ENODEV; land, take and lag ask as open did, since
// __love_osv never moves under a run. *chans is asked and answered, fb a device frame's bytes
#if horn_alsa || horn_oss || horn_sun
#define horn_doorless 0
static int dev_open(char const *name, int rate, int dir, int *chans, int *wid, int *err) {
#if horn_alsa
 if (__love_osv == 1) return alsa_open(name, rate, dir, chans, wid, err);
#endif
#if horn_oss
 if (__love_osv == 2) return oss_open(name, rate, dir, chans, err);
#endif
#if horn_sun
 if (__love_osv == 3) return sun_open(name, rate, dir, chans, err);
#endif
 return *err = ENODEV, -1; }

static intptr_t dev_land(int fd, unsigned char const *src, uintptr_t n) {
#if horn_alsa
 if (__love_osv == 1) return alsa_land(fd, src, n);
#endif
#if horn_oss
 if (__love_osv == 2) return oss_land(fd, src, n);
#endif
#if horn_sun
 if (__love_osv == 3) return sun_io(fd, 0, (unsigned char*) src, n);
#endif
 return -1; }

static intptr_t dev_take(int fd, unsigned char *dst, uintptr_t n) {
#if horn_alsa
 if (__love_osv == 1) return alsa_take(fd, dst, n);
#endif
#if horn_oss
 if (__love_osv == 2) return oss_take(fd, dst, n);
#endif
#if horn_sun
 if (__love_osv == 3) return sun_io(fd, 1, dst, n);
#endif
 return -1; }

static uintptr_t dev_lag(int fd, int dir, uintptr_t fb) {
#if horn_alsa
 if (__love_osv == 1) return alsa_lag(fd);
#endif
#if horn_oss
 if (__love_osv == 2) return oss_lag(fd, dir, fb);
#endif
#if horn_sun
 if (__love_osv == 3) return sun_lag(fd, dir, fb);
#endif
 return 0; }
#else
// no device door: the sink alone
// a seat with a door opens the sink only by HORN=none; a doorless one has nothing else
#define horn_doorless 1
#if !love_horn_seat
static int dev_open(char const *name, int rate, int dir, int *chans, int *wid, int *err) { return *err = ENODEV, -1; }
#endif
static intptr_t dev_land(int fd, unsigned char const *src, uintptr_t n) { return -1; }
static intptr_t dev_take(int fd, unsigned char *dst, uintptr_t n) { return -1; }
static uintptr_t dev_lag(int fd, int dir, uintptr_t fb) { return 0; }
#endif

// inle by the OS word, a board by its roster: one case below, never the word
#if love_horn_seat
#define horn_at_seat 1
#else
#define horn_at_seat (__love_osv < 0)
#endif
// a doorless build opens no fd and has no close
#if horn_doorless
static void dev_shut(int fd) { (void) fd; }
#else
static void dev_shut(int fd) { close(fd); }
#endif

// the sink: frames played since t0 at the rate, sink_ms deep; an underrun re-bases t0
static uintptr_t sink_played(struct horn *h) {
 uintptr_t now = love_clock(), t0 = (uintptr_t) getcharm(h->t0), rate = (uintptr_t) getcharm(h->rate),
           wpos = (uintptr_t) getcharm(h->wpos);
 uintptr_t played = now > t0 ? (now - t0) * rate / 1000 : 0;
 if (played > wpos) { played = wpos; h->t0 = putcharm((intptr_t) (now - wpos * 1000 / rate)); }
 return played; }

static uintptr_t sink_land(struct horn *h, uintptr_t frames) {
 uintptr_t played = sink_played(h), rate = (uintptr_t) getcharm(h->rate),
           wpos = (uintptr_t) getcharm(h->wpos), cap = rate * sink_ms / 1000, queued = wpos - played;
 uintptr_t room = cap > queued ? cap - queued : 0;
 if (frames > room) frames = room;
 h->wpos = putcharm((intptr_t) (wpos + frames));
 return frames; }

// HORN_IN=none: silence at the rate since t0, wpos the frames handed out; a reader a ring
// behind loses the oldest, as an overrun does
static uintptr_t sink_heard(struct horn *h) {
 uintptr_t now = love_clock(), t0 = (uintptr_t) getcharm(h->t0), rate = (uintptr_t) getcharm(h->rate),
           wpos = (uintptr_t) getcharm(h->wpos), cap = rate * sink_ms / 1000;
 uintptr_t heard = now > t0 ? (now - t0) * rate / 1000 : 0;
 if (heard - wpos > cap) h->wpos = putcharm((intptr_t) (wpos = heard - cap));
 return heard - wpos; }

static uintptr_t sink_take(struct horn *h, uintptr_t frames) {
 uintptr_t got = sink_heard(h);
 if (frames > got) frames = got;
 h->wpos = putcharm(getcharm(h->wpos) + (intptr_t) frames);
 return frames; }

// the C face, for a program with no heap in hand (doom's mixer): one device, kept
static int horn_c_fd = -1, horn_c_sock;

int love_horn_open(int rate) {
 if (horn_at_seat) return k_horn_open(rate);
#if !love_horn_seat
 if (horn_c_fd >= 0 && horn_c_sock) sock_shut(horn_c_fd);
 else if (horn_c_fd >= 0) dev_shut(horn_c_fd);
 char const *dev = getenv("HORN");
 if (dev && !*dev) dev = NULL;
 int err = 0, ch = 2, wid = 2;
 horn_c_sock = horn_sock_name(dev);
 horn_c_fd = horn_c_sock ? sock_open(dev + 5, rate, 0, &err)
           : dev && !strcmp(dev, "none") ? -1 : dev_open(dev, rate, 0, &ch, &wid, &err);
#endif
 return horn_c_fd < 0 ? -1 : 0; }

intptr_t love_horn_write(unsigned char const *src, uintptr_t n) {
 if (horn_at_seat) return k_horn_write(src, n);
 return horn_c_fd < 0 ? -1 : horn_c_sock ? sock_land(horn_c_fd, src, n) : dev_land(horn_c_fd, src, n & ~(uintptr_t) 3); }

uintptr_t love_horn_lag(void) {
 if (horn_at_seat) return k_horn_lag();
 return horn_c_fd < 0 ? 0 : horn_c_sock ? sock_lag(horn_c_fd, 0, 4) : dev_lag(horn_c_fd, 0, 4); }

// a seat may tap the sink's pcm (the browser's WebAudio); the default takes nothing
__attribute__((weak)) void love_horn_tap(unsigned char const *pcm, uintptr_t frames,
                                       uintptr_t chans, uintptr_t rate) {
 (void) pcm, (void) frames, (void) chans, (void) rate; }

void love_horn_close(void) {
 if (horn_at_seat) { k_horn_close(); return; }
 if (horn_c_fd >= 0 && horn_c_sock) sock_shut(horn_c_fd);
 else if (horn_c_fd >= 0) dev_shut(horn_c_fd);
 horn_c_fd = -1; }

// a mono run is doubled through a stack frame; the answer is in the caller's bytes
static intptr_t horn_land(struct horn *h, unsigned char const *src, uintptr_t n) {
 int kind = (int) getcharm(h->kind), fd = (int) getcharm(h->b.f.fd);
 if (getcharm(h->chans) == 2)
  return kind == horn_dev ? dev_land(fd, src, n) : kind == horn_sock ? sock_land(fd, src, n) : k_horn_write(src, n);
 unsigned char t[4096];
 if (n > sizeof t / 2) n = sizeof t / 2;
 for (uintptr_t i = 0; i < n; i += 2)
  t[2 * i] = t[2 * i + 2] = src[i], t[2 * i + 1] = t[2 * i + 3] = src[i + 1];
 intptr_t k = kind == horn_dev ? dev_land(fd, t, 2 * n) : kind == horn_sock ? sock_land(fd, t, 2 * n) : k_horn_write(t, 2 * n);
 return k > 0 ? k / 2 : k; }

struct g *love_horn_writen(struct g *g, unsigned char const *src, uintptr_t n) {
 struct horn *h = (struct horn*) g->io;
 if (getcharm(h->dir)) return g->b = -1, g;        // a capture port has no way out
 uintptr_t fb = 2 * (uintptr_t) getcharm(h->chans);
 if (n < fb) return g->b = (intptr_t) n, g;        // a stray partial frame is noise: taken, unplayed
 n -= n % fb;
 intptr_t k;
 if (getcharm(h->kind) == horn_sink) {
  uintptr_t got = sink_land(h, n / fb);              // frames the ring took at the rate
  love_horn_tap(src, got, (uintptr_t) getcharm(h->chans), (uintptr_t) getcharm(h->rate));
  k = (intptr_t) (got * fb); }
 else k = horn_land(h, src, n);
 return g->b = k, g; }

// whole frames: straight into dst when the device matches, else through a stack frame, the
// top 16 bits mixed (the mean) or doubled. 0 is dry, and the reader parks
intptr_t love_horn_readn(struct g *g, unsigned char *dst, uintptr_t n) {
 struct horn *h = (struct horn*) g->io;
 if (!getcharm(h->dir)) return -1;                  // a playback port reads as the end
 uintptr_t chans = (uintptr_t) getcharm(h->chans), fb = 2 * chans;
 n -= n % fb;
 if (!n) return 0;
 int kind = (int) getcharm(h->kind), fd = (int) getcharm(h->b.f.fd);
 if (kind == horn_sink) {
  uintptr_t k = sink_take(h, n / fb) * fb;
  memset(dst, 0, k);
  return (intptr_t) k; }
 if (kind == horn_sock) return sock_take(fd, dst, n, fb);
 if (kind == horn_seat_in) return k_horn_read(dst, n);
 if (kind != horn_dev) return -1;
 uintptr_t dchans = (uintptr_t) getcharm(h->dchans), dwid = (uintptr_t) getcharm(h->dwid),
           dfb = dwid * dchans;
 if (dchans == chans && dwid == 2) return dev_take(fd, dst, n);
 unsigned char t[4096];
 uintptr_t frames = n / fb < sizeof t / dfb ? n / fb : sizeof t / dfb;
 intptr_t k = dev_take(fd, t, frames * dfb);
 if (k <= 0) return k;
 frames = (uintptr_t) k / dfb;
 for (uintptr_t i = 0; i < frames; i++) {
  unsigned char const *f = t + i * dfb + dwid - 2;    // a sample's top two bytes
  int l = (int16_t) (f[0] | f[1] << 8), r = dchans == 2 ? (int16_t) (f[dwid] | f[dwid + 1] << 8) : l;
  if (chans == 1) l = (l + r) / 2;
  dst[fb * i] = (unsigned char) l, dst[fb * i + 1] = (unsigned char) (l >> 8);
  if (chans == 2) dst[4 * i + 2] = (unsigned char) r, dst[4 * i + 3] = (unsigned char) (r >> 8); }
 return (intptr_t) (frames * fb); }

// a seat that cannot listen refuses, and one that can answers these itself
__attribute__((weak)) int k_horn_in_open(int rate, int chans) { (void) rate, (void) chans; return -1; }
__attribute__((weak)) intptr_t k_horn_read(unsigned char *dst, uintptr_t n) { (void) dst, (void) n; return -1; }
__attribute__((weak)) uintptr_t k_horn_in_lag(void) { return 0; }
__attribute__((weak)) void k_horn_in_close(void) { }

// the finalizer, inside GC: io_close runs only for the fd port, so this port shuts its own
static void horn_fin(struct g *g, void *p) {
 struct horn *h = p;
 int kind = (int) getcharm(h->kind);
 intptr_t fd = getcharm(h->b.f.fd);
 if (kind == horn_dev && fd >= 0) dev_shut((int) fd);
 else if (kind == horn_sock && fd >= 0) sock_shut((int) fd);
 else if (kind == horn_seat) k_horn_close();
 else if (kind == horn_seat_in) k_horn_in_close();
 h->b.f.fd = putcharm(-1);
 h->kind = putcharm(horn_sink); }

// posix.c's close on a horn, outside GC
void love_horn_shut(struct io *io) { horn_fin(NULL, io); }

// one device each way: a newer port takes it, so an older one's close or finalizer shuts nothing
static void seat_take(struct g *g, int kind) {
 for (struct fz *z = g->fz; z; z = z->next)
  if (z->fn == horn_fin) {
   struct horn *o = (struct horn*) z->p;
   if (getcharm(o->kind) == kind) o->kind = putcharm(horn_sink); } }

// the port at sp[2]; a doorless build hears only HORN_IN=none's silence
love_noinline static struct g *horn_mk(struct g *g, int dir) {
 word rw = g->sp[0], cw = g->sp[1];
 intptr_t rate = (rw & 1) ? getcharm(rw) : -1, chans = (cw & 1) ? getcharm(cw) : -1;
 if (rate < 8000 || rate > 192000 || chans < 1 || chans > 2)
  return g->sp[1] = badarg(g), g->sp += 1, g;
 int kind = horn_sink, fd = -1, dchans = dir ? (int) chans : 2, dwid = 2;
 if (horn_at_seat) {
  kind = dir ? horn_seat_in : horn_seat;
  if ((dir ? k_horn_in_open((int) rate, (int) chans) : k_horn_open((int) rate)) < 0)
   return g->sp[1] = love_err(g, ENODEV), g->sp += 1, g;
  seat_take(g, kind); }
#if !love_horn_seat
 else {
  char const *dev = getenv(dir ? "HORN_IN" : "HORN");
  if (dev && !*dev) dev = NULL;                      // set and empty is unset
  int err = 0;
  bool none = dev && !strcmp(dev, "none");
  if (horn_sock_name(dev)) {
   fd = sock_open(dev + 5, (int) rate, dir ? (int) chans : 0, &err);
   if (fd < 0) return g->sp[1] = love_err(g, err), g->sp += 1, g;
   kind = horn_sock; }
  else if (dir && horn_doorless && !none) return g->sp[1] = love_err(g, ENODEV), g->sp += 1, g;
  else if (!horn_doorless && !none) {
   fd = dev_open(dev, (int) rate, dir, &dchans, &dwid, &err);
   if (fd < 0) return g->sp[1] = love_err(g, err), g->sp += 1, g;
   kind = horn_dev; } }
#endif
 uintptr_t const n = Width(struct horn);
 if (!ok(g = have(g, n + Width(struct tag) + Width(struct fz) + 1))) {
  if (kind == horn_dev) dev_shut(fd); else if (kind == horn_sock) sock_shut(fd); else if (kind == horn_seat) k_horn_close();
  else if (kind == horn_seat_in) k_horn_in_close();
  return g; }
 union u *k = bump(g, n + Width(struct tag));
 struct horn *h = (struct horn*) k;
 h->b.f.io.ap = lvm_port_io;
 h->b.f.io.vt = &love_horn_vt;
 h->b.f.io.ungetc_buf = putcharm(EOF);
 h->b.f.fd = putcharm(fd);
 h->b.rbuf = h->b.wbuf = 0;
 h->b.rpos = h->b.rlen = h->b.wlen = putcharm(0);
 h->kind = putcharm(kind);
 h->rate = putcharm(rate);
 h->chans = putcharm(chans);
 h->dir = putcharm(dir);
 h->dchans = putcharm(dchans);
 h->dwid = putcharm(dwid);
 h->wpos = putcharm(0);
 h->t0 = putcharm((intptr_t) love_clock());
 *--g->sp = (word) tagthread(k, n);
 struct fz *z = bump(g, Width(struct fz));
 z->p = k, z->fn = horn_fin, z->next = g->fz, g->fz = z;
 return g->sp[2] = g->sp[0], g->sp += 2, g; }

love_noinline static struct g *horn_open(struct g *g) { return horn_mk(g, 0); }
love_noinline static struct g *horn_in_open(struct g *g) { return horn_mk(g, 1); }

static lvm(lvm_horn) {
 LvmCall(g, horn_open) }

static lvm(lvm_horn_in) {
 LvmCall(g, horn_in_open) }

// the device's queue and the port's pending run both: a feeder reading only the device would
// see a full ring's lag stand still and never stop
static lvm(lvm_horn_lag) {
 word x = Sp[0];
 if (charmp(x) || cell(x)->ap != lvm_port_io || ((struct io*) x)->vt != &love_horn_vt)
  love_musttail return Answer(ZeroPoint);
 struct horn *h = (struct horn*) x;
 uintptr_t lag;
 int dir = (int) getcharm(h->dir);
 uintptr_t fb = 2 * (uintptr_t) getcharm(h->chans);
 switch ((int) getcharm(h->kind)) {
  case horn_sink: lag = dir ? sink_heard(h) : (uintptr_t) getcharm(h->wpos) - sink_played(h); break;
  case horn_dev: lag = dev_lag((int) getcharm(h->b.f.fd), dir,
                              (uintptr_t) getcharm(h->dwid) * (uintptr_t) getcharm(h->dchans)); break;
  case horn_sock: lag = sock_lag((int) getcharm(h->b.f.fd), dir, dir ? fb : 4); break;
  case horn_seat_in: lag = k_horn_in_lag(); break;
  default: lag = k_horn_lag(); }
 if (dir) lag += h->b.rbuf && !charmp(h->b.rbuf) ? (uintptr_t) (getcharm(h->b.rlen) - getcharm(h->b.rpos)) / fb : 0;
 else lag += io_wpending(g, (struct io*) h) / fb;
 love_musttail return Answer(putcharm((intptr_t) lag)); }

LvDef("horn", horn, 2, NULL);
LvDef("horn-in", horn_in, 2, NULL);
LvDef("horn-lag", horn_lag, 1, NULL);
