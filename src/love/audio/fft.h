// fft.h -- the transform the dsp nifs share (fft.c)
#include <stdint.h>
// in place over n (a power of two) interleaved re im; tc ts: cos and sin of 2 pi k / n, k < n / 2.
// inv runs e^(+2 pi i jk / n), unscaled
void love_fft(double *z, uintptr_t n, const double *tc, const double *ts, int inv);
// love_fft's halves: the bit-reversal, then the butterflies
void love_fft_rev(double *z, uintptr_t n);
void love_fft_bf(double *z, uintptr_t n, const double *tc, const double *ts, int inv);
