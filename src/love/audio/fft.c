// src/love/audio/fft.c -- the discrete fourier transform, radix 2.
// (fft x) -> x's transform, a complex tray, X[k] = sum x[j] e^(-2 pi i jk / n) | 'badarg:
//   x a rank-1 tray of numbers, real or complex, zeros past its end to n, a power of two
// (ifft x) -> the inverse, scaled by 1 / n, so (ifft (fft x)) is x
#include "love.h"
#include "fft.h"

double lm_sin(double), lm_cos(double);

void love_fft(double *z, uintptr_t n, const double *tc, const double *ts, int inv) {
 for (uintptr_t i = 1, j = 0; i < n; i++) {         // bit-reversed order
  uintptr_t b = n >> 1;
  for (; j & b; b >>= 1) j ^= b;
  j ^= b;
  if (i < j) {
   double r = z[2 * i], m = z[2 * i + 1];
   z[2 * i] = z[2 * j], z[2 * i + 1] = z[2 * j + 1], z[2 * j] = r, z[2 * j + 1] = m; } }
 double sg = inv ? 1 : -1;
 for (uintptr_t h = 1; h < n; h <<= 1)              // butterflies, twiddle e^(-+2 pi i k / 2h)
  for (uintptr_t a = 0; a < n; a += 2 * h)
   for (uintptr_t k = 0; k < h; k++) {
    uintptr_t t = k * (n / (2 * h));
    double c = tc[t], s = sg * ts[t], *u = z + 2 * (a + k), *v = z + 2 * (a + k + h),
           xr = v[0] * c - v[1] * s, xi = v[0] * s + v[1] * c;
    v[0] = u[0] - xr, v[1] = u[1] - xi, u[0] += xr, u[1] += xi; } }

static struct g *host_fft(struct g *g, int inv) {
 word x = g->sp[0];
 if (!trayp(x) || tray(x)->rank != 1 || tray(x)->type == love_O) return g->sp[0] = badarg(g), g;
 uintptr_t m = tray(x)->shape[0], n = 1;
 if (m < 1 || m > (uintptr_t) 1 << 24) return g->sp[0] = badarg(g), g;
 while (n < m) n <<= 1;
 uintptr_t bytes = tray_bytes(love_C, 1, n), nw = (2 * n + n) * sizeof(double);
 if (!ok(g = have(g, b2w(bytes) + str_width(nw)))) return g;
 struct tray *v = tray(g->sp[0]), *r = ini_tray(bump(g, b2w(bytes)), love_C, 1);
 struct str *work = ini_str(bump(g, str_width(nw)), nw);
 r->shape[0] = n;
 double *z = (double*) work->bytes, *tc = z + 2 * n, *ts = tc + n / 2;
 for (uintptr_t i = 0; i < n; i++)
  if (i >= m) z[2 * i] = z[2 * i + 1] = 0;
  else if (v->type == love_C) z[2 * i] = ((flo_t*) tray_data(v))[2 * i], z[2 * i + 1] = ((flo_t*) tray_data(v))[2 * i + 1];
  else z[2 * i] = tray_get_flo(v, i), z[2 * i + 1] = 0;
 double w = 6.283185307179586 / (double) n;
 for (uintptr_t k = 0; k < n / 2; k++) tc[k] = lm_cos(w * (double) k), ts[k] = lm_sin(w * (double) k);
 love_fft(z, n, tc, ts, inv);
 double sc = inv ? 1.0 / (double) n : 1.0;
 flo_t *o = tray_data(r);
 for (uintptr_t i = 0; i < 2 * n; i++) o[i] = (flo_t) (z[i] * sc);
 return g->sp[0] = word(r), g; }

static lvm(lvm_fft) LvmCall(g, host_fft, 0)
static lvm(lvm_ifft) LvmCall(g, host_fft, 1)
LvDef("fft", fft, 1, "dsp");
LvDef("ifft", ifft, 1, "dsp");
