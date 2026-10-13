// src/love/audio/fft.h -- the transform the dsp nifs share (fft.c).
#include <stdint.h>
// z: n complex numbers interleaved re im, n a power of two, transformed in place; tc and ts
// the cosines and sines of 2 pi k / n for k under n / 2. inv runs e^(+2 pi i jk / n), unscaled
void love_fft(double *z, uintptr_t n, const double *tc, const double *ts, int inv);
