// the droid seat's sound card: love.h's k_horn_* as a sink that keeps time and discards, a
// quarter second deep -- the host's HORN=none, so a write waits for what has played and the
// lag drains at the rate. the phone's AAudio, through the bridge, takes its place at rung 3.
#include <stdint.h>
#include "../../apps/moon/lib/moonlibc/impl.h"

static struct { uint64_t rate, held, t; } h;          // frames queued as of t, in ns

static uint64_t now_ns(void) {
  long ts[2];
  return __love_sys(NR_clock_gettime, 1, (long) ts, 0, 0, 0, 0) ? 0
       : (uint64_t) ts[0] * 1000000000 + (uint64_t) ts[1]; }

// what has played since the last look comes off the queue
static void drain(void) {
  uint64_t t = now_ns(), gone = (t - h.t) * h.rate / 1000000000;
  if (!gone) return;
  h.held = gone < h.held ? h.held - gone : 0;
  h.t = t; }

int k_horn_open(int rate) {
  if (rate < 8000 || rate > 192000) return -1;
  h.rate = (uint64_t) rate, h.held = 0, h.t = now_ns();
  return 0; }

// 16-bit stereo bytes, as many as fit behind what has played
intptr_t k_horn_write(unsigned char const *src, uintptr_t n) {
  (void) src;
  if (!h.rate) return -1;
  drain();
  uint64_t room = h.rate / 4 - h.held, f = n / 4 < room ? n / 4 : room;
  h.held += f;
  return (intptr_t) (f * 4); }

uintptr_t k_horn_lag(void) { if (h.rate) drain(); return (uintptr_t) h.held; }

void k_horn_close(void) { h.rate = 0, h.held = 0; }
