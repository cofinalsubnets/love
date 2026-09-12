// wasm's sound card, which is the page: love.h's k_horn_* on this seat, what i/hda.c is
// on x64. no controller to walk and no ring to lay here -- the worker (i/wasm/cpu.mjs)
// copies the samples into a ring in the shared buffer and the terminal thread's
// AudioWorklet drains it, so all four faces are hypercalls through __ai_sys like every
// other face on this machine. sound has no linux call to borrow a number from, the way
// the serial line borrows write and the idle nanosleep, so this block is ours and sits
// well clear of any syscall table.
#include <stdint.h>

extern long __ai_sys(long n, long a, long b, long c, long d, long e, long f);

#define hc_horn_open  0x4000
#define hc_horn_write 0x4001
#define hc_horn_lag   0x4002
#define hc_horn_close 0x4003

// a fresh open starts the ring empty: what the last run left unplayed is not this
// one's lag. -1 for a rate the page will not take.
int k_horn_open(int rate) { return (int) __ai_sys(hc_horn_open, rate, 0, 0, 0, 0, 0); }

// 16-bit stereo bytes, as many as fit behind what has played. a short answer is the ring
// full, which i/horn.c's port turns into backpressure and never a dropped frame.
intptr_t k_horn_write(unsigned char const *src, uintptr_t n) {
  return (intptr_t) __ai_sys(hc_horn_write, (long) src, (long) n, 0, 0, 0, 0); }

// frames written and not yet played -- the worklet publishes what it has consumed, so
// this is the card's own count and not a guess. with nothing draining (node, or a page
// whose audio has not been let in yet) the worker keeps the count off its own clock.
uintptr_t k_horn_lag(void) { return (uintptr_t) __ai_sys(hc_horn_lag, 0, 0, 0, 0, 0, 0); }

void k_horn_close(void) { __ai_sys(hc_horn_close, 0, 0, 0, 0, 0, 0); }
