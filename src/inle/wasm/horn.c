// wasm's sound card, the page: k_horn_* as hypercalls; cpu.mjs rings the samples and an
// AudioWorklet drains them. sound has no linux call number to borrow, so 0x4000 clears the table
#include <stdint.h>

extern long __love_sys(long n, long a, long b, long c, long d, long e, long f);

#define hc_horn_open  0x4000
#define hc_horn_write 0x4001
#define hc_horn_lag   0x4002
#define hc_horn_close 0x4003

// a fresh open empties the ring; -1 for a rate the page will not take
int k_horn_open(int rate) { return (int) __love_sys(hc_horn_open, rate, 0, 0, 0, 0, 0); }

// 16-bit stereo bytes, as many as fit; a short answer is a full ring (horn.c's backpressure)
intptr_t k_horn_write(unsigned char const *src, uintptr_t n) {
  return (intptr_t) __love_sys(hc_horn_write, (long) src, (long) n, 0, 0, 0, 0); }

// frames written, not yet played: the worklet's count, or the worker's clock with nothing draining
uintptr_t k_horn_lag(void) { return (uintptr_t) __love_sys(hc_horn_lag, 0, 0, 0, 0, 0, 0); }

void k_horn_close(void) { __love_sys(hc_horn_close, 0, 0, 0, 0, 0, 0); }
