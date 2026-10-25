// the math floor: binary64 transcendentals in portable mooncc-subset c (no fma, int128, builtins).
// taylor/exact-rational coefficients; sqrt exact, exp/log <= 1 ulp, sin/cos ~0.74 ulp at every
// magnitude, atan2 asin acos correctly rounded, pow <= 2 ulp typical (~40 at 1e+-300), exact for
// y in {2, 1, -1, 1/2}
#include <stdint.h>

typedef union { double d; uint64_t u; } db;
static double mkd(uint64_t u) { db b; b.u = u; return b.d; }
static uint64_t mku(double d) { db b; b.d = d; return b.u; }

#define DNan  mkd(0x7ff8000000000000ull)
#define DInf  mkd(0x7ff0000000000000ull)

// dekker: 26+27 bit halves so products are exact
static void dsplit(double a, double *hi, double *lo) {
 double c = a * 0x8000001p0;                     // a * (2^27 + 1)
 *hi = c - (c - a);
 *lo = a - *hi; }
// exact a*b as hi+lo
static void dmul(double a, double b, double *hi, double *lo) {
 double ah, al, bh, bl;
 dsplit(a, &ah, &al); dsplit(b, &bh, &bl);
 *hi = a * b;
 *lo = ((ah * bh - *hi) + ah * bl + al * bh) + al * bl; }

// (a, b) -> s + e exactly
static void tsum(double a, double b, double *s, double *e) {
 *s = a + b;
 double bb = *s - a;
 *e = (a - (*s - bb)) + (b - bb); }

// newton from a bit-level seed, then a correct-rounding fixup: of y and its ulp
// neighbour, whichever exact square sits nearer x
double lm_sqrt(double x) {
 uint64_t ux = mku(x);
 if (x != x) return DNan;
 if (ux == 0 || ux == 0x8000000000000000ull) return x;      // +-0
 if (ux >> 63) return DNan;                                 // negative
 if ((ux >> 52) == 0x7ff) return x;                          // +inf
 int scale = 0;
 // pre-scale tiny x: the fixup's dekker products must stay normal
 if (x < 0x1p-512) { x *= 0x1p540; ux = mku(x); scale = -270; }
 // seed: halve the exponent field (a ~5-bit guess), sharpen by Newton
 uint64_t uy = ((ux >> 1) + (0x3ffull << 51)) & 0x7fffffffffffffffull;
 double y = mkd(uy);
 y = 0.5 * (y + x / y);
 y = 0.5 * (y + x / y);
 y = 0.5 * (y + x / y);
 y = 0.5 * (y + x / y);                                      // within ~1 ulp now
 // fixup: r = x - y*y exactly; step toward x if the neighbor is nearer
 double ph, pl, r, r2, yn;
 for (int i = 0; i < 4; i++) {                               // walk to the nearest-square neighbor
  dmul(y, y, &ph, &pl);
  r = (x - ph) - pl;
  if (r == 0) break;
  yn = mkd(mku(y) + (r > 0 ? 1 : (uint64_t) -1));
  dmul(yn, yn, &ph, &pl);
  r2 = (x - ph) - pl;
  double ar = r < 0 ? -r : r, ar2 = r2 < 0 ? -r2 : r2;
  if (ar2 < ar || (ar2 == ar && !(mku(yn) & 1))) y = yn;     // nearer, or the even side of a tie
  else break;
 }
 return scale ? y * 0x1p-270 : y; }

// x = k ln2 + r, |r| <= ln2/2; e^r by taylor to r^13 (tail < 2^-57), then 2^k
static const double LN2_HI = 0x1.62e42f8000000p-1, LN2_LO = 0x1.be8e7bcd5e4f2p-27,
                    LOG2E  = 0x1.71547652b82fep+0;
static double scale2k(double y, int k) {                     // y * 2^k, k in [-2098, 2098]
 while (k > 1023)  { y *= 0x1p1023;  k -= 1023; }
 while (k < -1022) { y *= 0x1p-1022; k += 1022; }
 return y * mkd((uint64_t)(k + 1023) << 52); }
double lm_exp(double x) {
 if (x != x) return x;
 if (x >  709.782712893383996) return DInf;                 // overflow
 if (x < -745.133219101941222) return 0.0;                   // underflow to 0
 int k = (int)(x * LOG2E + (x > 0 ? 0.5 : -0.5));
 double r = (x - k * LN2_HI) - k * LN2_LO;
 double z = r * r;
 double p = r + z * (0x1.0000000000000p-1
       + r * (0x1.5555555555555p-3
       + r * (0x1.5555555555555p-5
       + r * (0x1.1111111111111p-7
       + r * (0x1.6c16c16c16c17p-10
       + r * (0x1.a01a01a01a01ap-13
       + r * (0x1.a01a01a01a01ap-16
       + r * (0x1.71de3a556c734p-19
       + r * (0x1.27e4fb7789f5cp-22
       + r * (0x1.ae64567f544e4p-26
       + r * (0x1.1eed8eff8d898p-29
       + r *  0x1.6124613a86d09p-33)))))))))));
 return scale2k(1.0 + p, k); }

// x = 2^k m, m in [sqrt2/2, sqrt2); ln m = 2 atanh s, s = (m-1)/(m+1), series to s^22/23
double lm_log(double x) {
 uint64_t ux = mku(x);
 if (x != x) return x;
 if (ux == 0 || ux == 0x8000000000000000ull) return -DInf;  // +-0 -> -inf
 if (ux >> 63) return DNan;                                 // negative
 if ((ux >> 52) == 0x7ff) return x;                          // +inf
 int k = 0;
 if (ux < (1ull << 52)) { x *= 0x1p54; ux = mku(x); k = -54; }  // denormal
 k += (int)(ux >> 52) - 1023;
 double m = mkd((ux & 0xfffffffffffffull) | (0x3ffull << 52));       // m in [1, 2)
 if ((ux & 0xfffffffffffffull) > 0x6a09e667f3bcdull) { m *= 0.5; k += 1; }  // -> [sqrt2/2, sqrt2)
 double f = m - 1.0;
 double s = f / (2.0 + f);
 double slo = ((f - 2.0 * s) - s * f) / (2.0 + f);           // the division's residue
 double z = s * s;
 double p = 0x1.5555555555555p-2
      + z * (0x1.999999999999ap-3
      + z * (0x1.2492492492492p-3
      + z * (0x1.c71c71c71c71cp-4
      + z * (0x1.745d1745d1746p-4
      + z * (0x1.3b13b13b13b14p-4
      + z * (0x1.1111111111111p-4
      + z * (0x1.e1e1e1e1e1e1ep-5
      + z * (0x1.af286bca1af28p-5
      + z * (0x1.8618618618618p-5
      + z *  0x1.642c8590b2164p-5)))))))));
 double lnm = 2.0 * s + (2.0 * slo + 2.0 * s * z * p);
 return k * LN2_HI + (lnm + k * LN2_LO); }

// three-part cody-waite (33+33+rest bits) below 2^19, payne-hanek past it, r carried hi+lo;
// taylor kernels to r^17 / r^16 on |r| <= pi/4
static const double INVPIO2 = 0x1.45f306dc9c883p-1,
  PIO2_1 = 0x1.921fb54400000p+0, PIO2_2 = 0x1.0b4611a600000p-34,
  PIO2_3 = 0x1.3198a2e037073p-69;
// 64x64 -> 128 in 32-bit halves
static void mul64(uint64_t a, uint64_t b, uint64_t *hi, uint64_t *lo) {
 uint64_t ah = a >> 32, al = a & 0xffffffffull, bh = b >> 32, bl = b & 0xffffffffull;
 uint64_t p0 = al * bl, p1 = al * bh, p2 = ah * bl, p3 = ah * bh;
 uint64_t mid = p1 + (p0 >> 32);
 uint64_t c = mid < p1 ? (1ull << 32) : 0;   // a mid wrap weighs 2^96 = 2^32 in hi units
 mid += p2;
 if (mid < p2) c += 1ull << 32;
 *hi = p3 + (mid >> 32) + c;
 *lo = (mid << 32) | (p0 & 0xffffffffull); }

// payne-hanek: (|x| 2/pi) mod 4 off a 3-word window of 2/pi's bits at offset E-55, 192 fraction bits
static const uint64_t TPB[] = {          // 2/pi binary fraction, 64-bit words
 0xa2f9836e4e441529ull, 0xfc2757d1f534ddc0ull, 0xdb6295993c439041ull,
 0xfe5163abdebbc561ull, 0xb7246e3a424dd2e0ull, 0x06492eea09d1921cull,
 0xfe1deb1cb129a73eull, 0xe88235f52ebb4484ull, 0xe99c7026b45f7e41ull,
 0x3991d639835339f4ull, 0x9c845f8bbdf9283bull, 0x1ff897ffde05980full,
 0xef2f118b5a0a6d1full, 0x6d367ecf27cb09b7ull, 0x4f463f669e5fea2dull,
 0x7527bac7ebe5f17bull, 0x3d0739f78a5292eaull, 0x6bfb5fb11f8d5d08ull,
 0x56033046fc7b6babull, 0xf0cfbc209af4361dull, 0xa9e391615ee61b08ull,
 0x6599855f14a06840ull };
static const double PIO2_HI = 0x1.921fb54442d18p+0, PIO2_LO = 0x1.1a62633145c07p-54;
static uint64_t tpw(int i) { return (i < 0 || i >= (int)(sizeof TPB / sizeof *TPB)) ? 0 : TPB[i]; }
static int rbig(double ax, double *r, double *rlo) {
 uint64_t ux = mku(ax);
 uint64_t m = (ux & 0xfffffffffffffull) | (1ull << 52);      // 53-bit mantissa
 int E = (int)(ux >> 52) - 1023;
 int S = E - 55;                                             // window offset: 3 guard bits above mod-4
 int q = S >> 6, b = S & 63;                                 // word / bit split (S may be negative)
 uint64_t W0, W1, W2;
 if (b) { W0 = (tpw(q) << b) | (tpw(q + 1) >> (64 - b));
          W1 = (tpw(q + 1) << b) | (tpw(q + 2) >> (64 - b));
          W2 = (tpw(q + 2) << b) | (tpw(q + 3) >> (64 - b)); }
 else   { W0 = tpw(q); W1 = tpw(q + 1); W2 = tpw(q + 2); }
 uint64_t h0, l0, h1, l1, h2, l2;
 mul64(m, W0, &h0, &l0);
 mul64(m, W1, &h1, &l1);
 mul64(m, W2, &h2, &l2);
 uint64_t F0 = l0 + h1, cI = F0 < l0 ? 1 : 0;                // fixed point after I
 uint64_t F1 = l1 + h2, F2 = l2;
 if (F1 < l1) { F0 += 1; cI += F0 == 0; }                    // carries, in order
 uint64_t I = h0 + cI;
 // times 8 (the 3 guard bits): quadrant = top 2, fraction slides up
 int j = (int)(((I << 3) | (F0 >> 61)) & 3);
 uint64_t G0 = (F0 << 3) | (F1 >> 61), G1 = (F1 << 3) | (F2 >> 61), G2 = F2 << 3;
 int neg = 0;
 if (G0 >> 63) {                                             // frac >= 1/2: round to the NEXT multiple
  j = (j + 1) & 3; neg = 1;
  G2 = ~G2 + 1; G1 = ~G1 + (G2 == 0); G0 = ~G0 + (G1 == 0 && G2 == 0); }
 // |frac| as three 53-bit chunks, each exact as a double, summed without loss
 double fa = (double) (int64_t) (G0 >> 11) * 0x1p-53;
 double fb = (double) (int64_t) (((G0 & 0x7ff) << 42) | (G1 >> 22)) * 0x1p-106;
 double fc = (double) (int64_t) (((G1 & 0x3fffff) << 31) | (G2 >> 33)) * 0x1p-159;
 double sh, sl;
 tsum(fa, fb, &sh, &sl);
 sl += fc;
 if (neg) { sh = -sh; sl = -sl; }
 double ph, pl;                                              // r = frac * pi/2, in dd
 dmul(sh, PIO2_HI, &ph, &pl);
 *r = ph;
 *rlo = pl + sh * PIO2_LO + sl * PIO2_HI;
 double rr = *r + *rlo;                                      // renormalize
 *rlo = (*r - rr) + *rlo;
 *r = rr;
 return j; }
// reduce x to (r, rlo); answers the quadrant
static int rpio2(double x, double *r, double *rlo) {
 double ax = x < 0 ? -x : x;
 if (ax <= 0x1.921fb54442d18p-1) { *r = x; *rlo = 0; return 0; }   // |x| <= pi/4
 if (ax >= 0x1p19) {                                         // past cody-waite's bound
  int j = rbig(ax, r, rlo);
  if (x < 0) { *r = -*r; *rlo = -*rlo; j = (4 - j) & 3; }    // sin/cos symmetry: reduce |x|, flip
  return j; }
 double dj = x * INVPIO2 + (x > 0 ? 0.5 : -0.5);
 int64_t j = (int64_t) dj;
 double fj = (double) j;
 double w1 = x - fj * PIO2_1;                  // exact: j < 2^20 against 33-bit parts
 double w2, e2;
 tsum(w1, -(fj * PIO2_2), &w2, &e2);           // the product exact, the sum's residue kept
 double t  = fj * PIO2_3;
 *r = w2 - t;
 *rlo = ((w2 - *r) - t) + e2;
 return (int)(j & 3); }
// sin on the reduced (r, rlo), |r| <= ~pi/4
static double ksin(double r, double rlo) {
 double z = r * r;
 double p = 0x1.1111111111111p-7
      + z * (-0x1.a01a01a01a01ap-13
      + z * (0x1.71de3a556c734p-19
      + z * (-0x1.ae64567f544e4p-26
      + z * (0x1.6124613a86d09p-33
      + z * (-0x1.ae7f3e733b81fp-41
      + z *  0x1.952c77030ad4ap-49)))));
 return r + (z * (r * (-0x1.5555555555555p-3 + z * p)) + rlo * (1.0 - 0.5 * z)); }   // rlo cos r
// cos on the reduced (r, rlo)
static double kcos(double r, double rlo) {
 double z = r * r;
 double p = 0x1.5555555555555p-5
      + z * (-0x1.6c16c16c16c17p-10
      + z * (0x1.a01a01a01a01ap-16
      + z * (-0x1.27e4fb7789f5cp-22
      + z * (0x1.1eed8eff8d898p-29
      + z * (-0x1.93974a8c07c9dp-37
      + z *  0x1.ae7f3e733b81fp-45)))));
 double hz = 0.5 * z, w = 1.0 - hz;
 return w + (((1.0 - w) - hz) + (z * (z * p) - rlo * (r - r * z * 0x1.5555555555555p-3)));   // 1 - hz's rounding kept, rlo sin r
}
double lm_sin(double x) {
 if (x != x) return x;
 uint64_t ax = mku(x) & 0x7fffffffffffffffull;
 if (ax >= 0x7ff0000000000000ull) return DNan;              // +-inf
 if (ax < 0x3e40000000000000ull) return x;                  // below 2^-27 sin x rounds to x, sign kept
 double r, rl;
 int j = rpio2(x, &r, &rl);
 switch (j) {
  case 0: return ksin(r, rl);
  case 1: return kcos(r, rl);
  case 2: return -ksin(r, rl);
  default: return -kcos(r, rl); } }
double lm_cos(double x) {
 if (x != x) return x;
 uint64_t ax = mku(x) & 0x7fffffffffffffffull;
 if (ax >= 0x7ff0000000000000ull) return DNan;
 if (ax < 0x3e40000000000000ull) return 1.0;                // and cos x to 1
 double r, rl;
 int j = rpio2(x, &r, &rl);
 switch (j) {
  case 0: return kcos(r, rl);
  case 1: return -ksin(r, rl);
  case 2: return -kcos(r, rl);
  default: return ksin(r, rl); } }

// double-double: hi + lo, |lo| <= ulp(hi)/2; ~2^-104 a step
static void dd_add(double ah, double al, double bh, double bl, double *h, double *l) {
 double s, e;
 tsum(ah, bh, &s, &e);
 e += al + bl;
 *h = s + e; *l = e - (*h - s); }
static void dd_mul(double ah, double al, double bh, double bl, double *h, double *l) {
 double p, e;
 dmul(ah, bh, &p, &e);
 e += ah * bl + al * bh;
 *h = p + e; *l = e - (*h - p); }
static void dd_div(double ah, double al, double bh, double bl, double *h, double *l) {
 double q = ah / bh, p, e;
 dmul(q, bh, &p, &e);
 double r = (((ah - p) - e) + al - q * bl) / bh;
 *h = q + r; *l = r - (*h - q); }

// atan(i/64) as double-doubles
static const double AT64[][2] = {
  { 0.0, 0.0 }, { 0x1.fff555bbb729bp-7, -0x1.220c39d4dff50p-61 },
  { 0x1.ffd55bba97625p-6, -0x1.5ec431444912cp-60 }, { 0x1.7fb818430da2ap-5, -0x1.86ef8f794f105p-63 },
  { 0x1.ff55bb72cfdeap-5, -0x1.c934d86d23f1dp-60 }, { 0x1.3f59f0e7c559dp-4, 0x1.ac4ce285df847p-58 },
  { 0x1.7ee182602f10fp-4, -0x1.cfb654c0c3d98p-58 }, { 0x1.be39ebe6f07c3p-4, 0x1.f7b8f29a05987p-58 },
  { 0x1.fd5ba9aac2f6ep-4, -0x1.cd37686760c17p-59 }, { 0x1.1e1fafb043727p-3, -0x1.b485914dacf8cp-59 },
  { 0x1.3d6eee8c6626cp-3, 0x1.61a3b0ce9281bp-57 }, { 0x1.5c9811e3ec26ap-3, -0x1.054ab2c010f3dp-58 },
  { 0x1.7b97b4bce5b02p-3, 0x1.347b0b4f881cap-58 }, { 0x1.9a6a8e96c8626p-3, 0x1.cf601e7b4348ep-59 },
  { 0x1.b90d7529260a2p-3, 0x1.17b10d2e0e5abp-61 }, { 0x1.d77d5df205736p-3, 0x1.c648d1534597ep-57 },
  { 0x1.f5b75f92c80ddp-3, 0x1.8ab6e3cf7afbdp-57 }, { 0x1.09dc597d86362p-2, 0x1.62e47390cb865p-56 },
  { 0x1.18bf5a30bf178p-2, 0x1.30ca4748b1bf9p-57 }, { 0x1.278372057ef46p-2, -0x1.077cdd36dfc81p-56 },
  { 0x1.362773707ebccp-2, -0x1.963a544b672d8p-57 }, { 0x1.44aa436c2af0ap-2, -0x1.5d5e43c55b3bap-56 },
  { 0x1.530ad9951cd4ap-2, -0x1.2566480884082p-57 }, { 0x1.614840309cfe2p-2, -0x1.a725715711f00p-56 },
  { 0x1.6f61941e4def1p-2, -0x1.c63aae6f6e918p-56 }, { 0x1.7d5604b63b3f7p-2, 0x1.69c885c2b249ap-56 },
  { 0x1.8b24d394a1b25p-2, 0x1.b6d0ba3748fa8p-56 }, { 0x1.98cd5454d6b18p-2, 0x1.9e6c988fd0a77p-56 },
  { 0x1.a64eec3cc23fdp-2, -0x1.24dec1b50b7ffp-56 }, { 0x1.b3a911da65c6cp-2, 0x1.ae187b1ca5040p-56 },
  { 0x1.c0db4c94ec9f0p-2, -0x1.cc1ce70934c34p-56 }, { 0x1.cde53432c1351p-2, -0x1.a2cfa4418f1adp-56 },
  { 0x1.dac670561bb4fp-2, 0x1.a2b7f222f65e2p-56 }, { 0x1.e77eb7f175a34p-2, 0x1.0e53dc1bf3435p-56 },
  { 0x1.f40dd0b541418p-2, -0x1.a3992dc382a23p-57 }, { 0x1.0039c73c1a40cp-1, -0x1.b32c949c9d593p-55 },
  { 0x1.0657e94db30d0p-1, -0x1.d5b495f6349e6p-56 }, { 0x1.0c6145b5b43dap-1, 0x1.974fa13b5404fp-58 },
  { 0x1.1255d9bfbd2a9p-1, -0x1.2bdaee1c0ee35p-58 }, { 0x1.1835a88be7c13p-1, 0x1.c621cec00c301p-55 },
  { 0x1.1e00babdefeb4p-1, -0x1.928df287a668fp-58 }, { 0x1.23b71e2cc9e6ap-1, 0x1.c421c9f38224ep-57 },
  { 0x1.2958e59308e31p-1, -0x1.09e73b0c6c087p-56 }, { 0x1.2ee628406cbcap-1, 0x1.c5d5e9ff0cf8dp-55 },
  { 0x1.345f01cce37bbp-1, 0x1.1021137c71102p-55 }, { 0x1.39c391cd4171ap-1, -0x1.2304331d8bf46p-55 },
  { 0x1.3f13fb89e96f4p-1, 0x1.ecf8b492644f0p-56 }, { 0x1.445065b795b56p-1, -0x1.f76d0163f79c8p-56 },
  { 0x1.4978fa3269ee1p-1, 0x1.2419a87f2a458p-56 }, { 0x1.4e8de5bb6ec04p-1, 0x1.4a33dbeb3796cp-55 },
  { 0x1.538f57b89061fp-1, -0x1.1bb74abda520cp-55 }, { 0x1.587d81f732fbbp-1, -0x1.5e5c9d8c5a950p-56 },
  { 0x1.5d58987169b18p-1, 0x1.0028e4bc5e7cap-57 }, { 0x1.6220d115d7b8ep-1, -0x1.2b785350ee8c1p-57 },
  { 0x1.66d663923e087p-1, -0x1.6ea6febe8bbbap-56 }, { 0x1.6b798920b3d99p-1, -0x1.a80386188c50ep-55 },
  { 0x1.700a7c5784634p-1, -0x1.8c34d25aadef6p-56 }, { 0x1.748978fba8e0fp-1, 0x1.7b2a6165884a1p-59 },
  { 0x1.78f6bbd5d315ep-1, 0x1.406a089803740p-55 }, { 0x1.7d528289fa093p-1, 0x1.560821e2f3aa9p-55 },
  { 0x1.819d0b7158a4dp-1, -0x1.bf76229d3b917p-56 }, { 0x1.85d69576cc2c5p-1, 0x1.6b66e7fc8b8c3p-57 },
  { 0x1.89ff5ff57f1f8p-1, -0x1.55b9a5e177a1bp-55 }, { 0x1.8e17aa99cc05ep-1, -0x1.ec182ab042f61p-56 },
  { 0x1.921fb54442d18p-1, 0x1.1a62633145c07p-55 },
};
// atan u = u + u z (q1 + z (q2 + ..)), z = u^2, |u| <= 2^-7: the q's to 1/17
static const double ATQ[][2] = {
  { -0x1.5555555555555p-2, -0x1.5555555555555p-56 }, { 0x1.999999999999ap-3, -0x1.999999999999ap-57 },
  { -0x1.2492492492492p-3, -0x1.2492492492492p-57 }, { 0x1.c71c71c71c71cp-4, 0x1.c71c71c71c71cp-58 },
  { -0x1.745d1745d1746p-4, 0x1.745d1745d1746p-59 }, { 0x1.3b13b13b13b14p-4, -0x1.3b13b13b13b14p-58 },
  { -0x1.1111111111111p-4, -0x1.1111111111111p-60 }, { 0x1.e1e1e1e1e1e1ep-5, 0x1.e1e1e1e1e1e1ep-61 },
};
// atan t in double-double, t in [0, 1]: u = (t-c)/(1+ct) against the nearest c = i/64.
// fast takes the series past u in double, ~2^-66 of u; else all of it in double-double
static void katan(double th, double tl, int fast, double *h, double *l) {
 int i = (int) (th * 64 + 0.5);
 double c = i * 0x1p-6, uh = th, ul = tl, zh, zl, ph, pl;
 if (i) {
  double nh, nl, dh, dl;
  tsum(th - c, tl, &nh, &nl);                                // th - c exact (sterbenz)
  dmul(c, th, &ph, &pl);
  dd_add(1.0, 0.0, ph, pl + c * tl, &dh, &dl);
  dd_div(nh, nl, dh, dl, &uh, &ul); }
 if (fast) {
  double z = uh * uh, p = ATQ[7][0];
  for (int k = 6; k >= 0; k--) p = ATQ[k][0] + z * p;
  ph = uh * z * p, pl = 0.0; }
 else {
  dd_mul(uh, ul, uh, ul, &zh, &zl);
  ph = ATQ[7][0], pl = ATQ[7][1];
  for (int k = 6; k >= 0; k--) {
   dd_mul(zh, zl, ph, pl, &ph, &pl);
   dd_add(ATQ[k][0], ATQ[k][1], ph, pl, &ph, &pl); }
  dd_mul(zh, zl, ph, pl, &ph, &pl);
  dd_mul(uh, ul, ph, pl, &ph, &pl); }
 dd_add(uh, ul, ph, pl, &ph, &pl);
 dd_add(AT64[i][0], AT64[i][1], ph, pl, h, l); }
static const double PI_H = 0x1.921fb54442d18p+1, PI_L = 0x1.1a62633145c07p-53,
  PI2_H = 0x1.921fb54442d18p+0, PI2_L = 0x1.1a62633145c07p-54;
// the angle of (b, a), both double-doubles >= 0 and not both 0, b's sign sx, rounded once:
// the fast sum when 2^-60 of it cannot move the rounding, else the slow one
static double katan2(double ah, double al, double bh, double bl, int sx) {
 int sw = ah > bh;                                           // past pi/4: pi/2 - atan(b/a)
 double nh = sw ? bh : ah, nl = sw ? bl : al, dh = sw ? ah : bh, dl = sw ? al : bl;
 double th, tl, h, l, r;
 dd_div(nh, nl, dh, dl, &th, &tl);
 for (int fast = 1; ; fast = 0) {
  katan(th, tl, fast, &h, &l);
  if (sw) dd_add(PI2_H, PI2_L, -h, -l, &h, &l);
  if (sx) dd_add(PI_H, PI_L, -h, -l, &h, &l);
  r = h + l;
  if (!fast || r == 0) return r;
  double e = l - (r - h), ar = r < 0 ? -r : r;               // r + e is the sum, exactly
  double u = ar - mkd(mku(ar) - 1);                          // the smaller ulp beside r
  if ((e < 0 ? -e : e) + ar * 0x1p-60 < 0.5 * u) return r; } }
// a tiny ratio's atan is a/b to the last bit, but for an exact tie, which atan's hair below
// rounds down: a = b m, m the midpoint under q, odd parts equal. only a subnormal q can tie
static uint64_t lm_odd(double d, int *e) {                  // d > 0 as m 2^e, m odd
 uint64_t u = mku(d), m = u >> 52 ? (u & 0xfffffffffffffull) | 1ull << 52 : u;
 *e = u >> 52 ? (int) (u >> 52) - 1075 : -1074;
 while (!(m & 1)) m >>= 1, ++*e;
 return m; }
static double lm_tinyatan(double a, double b) {
 double q = a / b;
 uint64_t uq = mku(q), M = 2 * uq - 1;                      // the midpoint, M 2^-1075
 if (uq == 0 || uq >> 52) return q;
 int ea, eb;
 uint64_t oa = lm_odd(a, &ea), ob = lm_odd(b, &eb);
 return ob <= (1ull << 53) / M && oa == ob * M && ea == eb - 1075 ? mkd(uq - 1) : q; }
double lm_atan2(double y, double x) {
 if (x != x || y != y) return x + y;
 uint64_t uy = mku(y), ux = mku(x);
 int sy = (int) (uy >> 63), sx = (int) (ux >> 63);
 uint64_t ay = uy & 0x7fffffffffffffffull, ax = ux & 0x7fffffffffffffffull;
 double r;
 if (ay == 0) return sx ? (sy ? -PI_H : PI_H) : y;           // x<0: +-pi; x>=0: +-0
 if (ax == 0x7ff0000000000000ull)                            // x = +-inf
  r = ay == 0x7ff0000000000000ull ? (sx ? 0x1.2d97c7f3321d2p+1 : 0x1.921fb54442d18p-1) : (sx ? PI_H : 0.0);
 else if (ax == 0 || ay == 0x7ff0000000000000ull) r = PI2_H;
 else {
  double a = mkd(ay), b = mkd(ax);
  if (!sx && a < b && a / b < 0x1p-60) r = lm_tinyatan(a, b);
  else {
   uint64_t m = ay > ax ? ay : ax;                           // the products stay normal
   if (m < 0x20b0000000000000ull) a *= 0x1p600, b *= 0x1p600;
   else if (m > 0x5f30000000000000ull) a *= 0x1p-600, b *= 0x1p-600;
   r = katan2(a, 0.0, b, 0.0, sx); } }
 return sy ? -r : r; }
// sqrt(1 - x^2) in double-double, |x| < 1
static void lm_cosarc(double x, double *h, double *l) {
 double ah, al, bh, bl, wh, wl, ph, pl;
 tsum(1.0, -x, &ah, &al);
 tsum(1.0, x, &bh, &bl);
 dd_mul(ah, al, bh, bl, &wh, &wl);
 *h = lm_sqrt(wh);
 dmul(*h, *h, &ph, &pl);
 *l = (((wh - ph) - pl) + wl) / (2.0 * *h); }
double lm_asin(double x) {
 double ax = x < 0 ? -x : x, h, l;
 if (x != x) return x + x;
 if (ax > 1.0) return DNan;
 if (ax < 0x1p-26) return x;                                 // asin x = x to the last bit
 if (ax == 1.0) return x < 0 ? -PI2_H : PI2_H;
 lm_cosarc(ax, &h, &l);
 double r = katan2(ax, 0.0, h, l, 0);
 return x < 0 ? -r : r; }
double lm_acos(double x) {
 double ax = x < 0 ? -x : x, h, l;
 if (x != x) return x + x;
 if (ax > 1.0) return DNan;
 if (x == 1.0) return 0.0;
 if (x == -1.0) return PI_H;
 lm_cosarc(x, &h, &l);
 return katan2(h, l, ax, 0.0, x < 0); }

// |x|^y = exp(y ln|x|), the log and the product in double-double, exp taking the lo linearly
static int lm_oddint(double y) {                             // 2 even int, 1 odd int, 0 not int
 if (y != y || y - y != 0) return 0;                         // nan/inf
 double ay = y < 0 ? -y : y;
 if (ay >= 0x1p53) return 2;                                 // huge: every double there is even
 int64_t i = (int64_t) y;
 if ((double) i != y) return 0;
 return (i & 1) ? 1 : 2; }
static void dd_log(double x, double *hi, double *lo) {       // x > 0, finite: ln x as hi+lo
 uint64_t ux = mku(x);
 int k = 0;
 if (ux < (1ull << 52)) { x *= 0x1p54; ux = mku(x); k = -54; }
 k += (int)(ux >> 52) - 1023;
 double m = mkd((ux & 0xfffffffffffffull) | (0x3ffull << 52));
 if ((ux & 0xfffffffffffffull) > 0x6a09e667f3bcdull) { m *= 0.5; k += 1; }
 double f = m - 1.0;
 double s = f / (2.0 + f);
 double sfh, sfl;                                            // s*f EXACTLY: the residue below is a
 dmul(s, f, &sfh, &sfl);                                     // cancellation at s*f's rounding scale
 double slo = (((f - 2.0 * s) - sfh) - sfl) / (2.0 + f);
 double z = s * s;
 double p = 0x1.5555555555555p-2
      + z * (0x1.999999999999ap-3
      + z * (0x1.2492492492492p-3
      + z * (0x1.c71c71c71c71cp-4
      + z * (0x1.745d1745d1746p-4
      + z * (0x1.3b13b13b13b14p-4
      + z * (0x1.1111111111111p-4
      + z * (0x1.e1e1e1e1e1e1ep-5
      + z * (0x1.af286bca1af28p-5
      + z * (0x1.8618618618618p-5
      + z *  0x1.642c8590b2164p-5)))))))));
 double t = 2.0 * s, tl = 2.0 * slo + t * z * p;             // lnm = t + tl
 double h = k * LN2_HI + t;                                  // exact k ln2_hi; t <= 0.7
 double e = (k * LN2_HI - h) + t;                            // the add's residue
 *hi = h;
 *lo = e + tl + k * LN2_LO; }
double lm_pow(double x, double y) {
 if (y == 0.0) return 1.0;
 if (x == 1.0) return 1.0;
 if (x != x || y != y) return DNan;
 uint64_t ux = mku(x), uy = mku(y);
 uint64_t axb = ux & 0x7fffffffffffffffull, ayb = uy & 0x7fffffffffffffffull;
 int oi = lm_oddint(y);
 if (ayb == 0x7ff0000000000000ull) {                         // y = +-inf
  if (axb == 0x3ff0000000000000ull) return 1.0;              // |x| = 1
  int big = axb > 0x3ff0000000000000ull;
  return (uy >> 63) ? (big ? 0.0 : DInf) : (big ? DInf : 0.0); }
 if (axb == 0) {                                             // x = +-0
  double z = (uy >> 63) ? DInf : 0.0;
  return ((ux >> 63) && oi == 1) ? -z : z; }
 if (axb == 0x7ff0000000000000ull) {                         // x = +-inf
  double z = (uy >> 63) ? 0.0 : DInf;
  return ((ux >> 63) && oi == 1) ? -z : z; }
 int neg = 0;
 if (ux >> 63) {                                             // negative base: integer y only
  if (!oi) return DNan;
  neg = oi == 1;
  x = -x; }
 // the algebraic exponents answer exactly: love's ((/ 1 2) 9) = 3.0
 if (y == 2.0)  return x * x;
 if (y == 1.0)  return neg ? -x : x;
 if (y == -1.0) return neg ? -1.0 / x : 1.0 / x;
 if (y == 0.5)  return lm_sqrt(x);                           // x > 0 here
 double lh, ll;
 dd_log(x, &lh, &ll);
 double wh, wl, qh, ql;                                      // w = y * ln x, dd
 dmul(y, lh, &wh, &wl);
 dmul(y, ll, &qh, &ql);                                      // exact: the lo product matters at the rim
 wl += qh + ql;
 double w = wh + wl, we = (wh - w) + wl;                     // renormalize: |we| <= ulp(w)
 if (w >  709.782712893383996) return neg ? -DInf : DInf;
 if (w < -745.133219101941222) return neg ? -0.0 : 0.0;
 double e = lm_exp(w);
 e = e + e * we;                                             // now the linear step is honest
 return neg ? -e : e; }

// float twins: real functions, not macros, since love takes their address. sqrt exp log pow
// sin cos run in binary32 alone, for a machine whose fpu has no double; the rest round the
// double's answer
typedef union { float f; uint32_t u; } fb;
static float mkf(uint32_t u) { fb b; b.u = u; return b.f; }
static uint32_t muf(float f) { fb b; b.f = f; return b.u; }
// exact a*b as hi+lo: 12+12 bit halves
static void fsplit(float a, float *hi, float *lo) { float c = a * 4097.0f; *hi = c - (c - a); *lo = a - *hi; }
static void fmul2(float a, float b, float *hi, float *lo) {
 float ah, al, bh, bl;
 fsplit(a, &ah, &al); fsplit(b, &bh, &bl);
 *hi = a * b;
 *lo = ((ah * bh - *hi) + ah * bl + al * bh) + al * bl; }
static void fsum2(float a, float b, float *s, float *e) { *s = a + b; float bb = *s - a; *e = (a - (*s - bb)) + (b - bb); }

float lm_atan2f(float y, float x) { return (float) lm_atan2(y, x); }
float lm_asinf(float x) { return (float) lm_asin(x); }
float lm_acosf(float x) { return (float) lm_acos(x); }

// the integer root of the mantissa, rounded by its remainder (a tie cannot happen)
float lm_sqrtf(float x) {
 uint32_t u = muf(x);
 if (x != x || !(u << 1) || u == 0x7f800000u) return x;   // nan, +-0, +inf
 if (u >> 31) return mkf(0x7fc00000u);
 int e = (int) (u >> 23);
 uint32_t m = u & 0x7fffffu;
 if (e) m |= 0x800000u;
 else for (e = 1; !(m & 0x800000u); m <<= 1) e--;          // subnormal: normalize
 e -= 127;
 if (e & 1) m <<= 1, e--;
 uint64_t M = (uint64_t) m << 23, r = 0;
 for (uint64_t b = 1ull << 48; b; b >>= 2)
  if (M >= r + b) M -= r + b, r = (r >> 1) + b;
  else r >>= 1;
 return mkf((uint32_t) (e / 2 + 126) * 0x800000u + (uint32_t) r + (M > r)); }

// x = k ln2 + r, |r| <= ln2/2; e^r by taylor to r^9 (tail < 2^-27), then 2^k
static const float LN2F_HI = 0x1.62e4p-1f, LN2F_LO = 0x1.7f7d1cp-20f, LOG2EF = 0x1.715476p+0f;
static float scale2kf(float y, int k) {                      // y * 2^k, k in [-252, 254]
 if (k > 127) y *= 0x1p127f, k -= 127;
 if (k < -126) y *= 0x1p-126f, k += 126;
 return y * mkf((uint32_t) (k + 127) << 23); }
float lm_expf(float x) {
 if (x != x) return x;
 if (x > 0x1.62e42ep+6f) return mkf(0x7f800000u);           // past ln FLT_MAX
 if (x < -0x1.9fe368p+6f) return 0.0f;                       // under half the least subnormal
 if (x < 0x1p-25f && x > -0x1p-25f) return 1.0f + x;
 int k = (int) (x * LOG2EF + (x > 0 ? 0.5f : -0.5f));
 float r = (x - (float) k * LN2F_HI) - (float) k * LN2F_LO;
 float p = r + r * r * (0.5f
      + r * (0x1.555556p-3f
      + r * (0x1.555556p-5f
      + r * (0x1.111112p-7f
      + r * (0x1.6c16c2p-10f
      + r * (0x1.a01a02p-13f
      + r * (0x1.a01a02p-16f
      + r *  0x1.71de3ap-19f)))))));
 return scale2kf(1.0f + p, k); }

// x = 2^k (1 + f), 1 + f in [sqrt2/2, sqrt2); ln(1 + f) = f - hfsq + s (hfsq + R), s = f/(2 + f)
// and R = 2 atanh s - 2s's series in s^2 to s^8
float lm_logf(float x) {
 uint32_t u = muf(x);
 if (x != x) return x;
 if (!(u << 1)) return mkf(0xff800000u);                     // +-0 -> -inf
 if (u >> 31) return mkf(0x7fc00000u);
 if (u == 0x7f800000u) return x;
 int k = 0;
 if (u < 0x800000u) x *= 0x1p25f, u = muf(x), k = -25;      // subnormal
 k += (int) (u >> 23) - 127;
 float m = mkf((u & 0x7fffffu) | 0x3f800000u);
 if ((u & 0x7fffffu) > 0x3504f3u) m *= 0.5f, k++;           // past sqrt2
 float f = m - 1.0f, s = f / (2.0f + f), z = s * s, hfsq = 0.5f * f * f;
 float R = z * (0x1.555556p-1f + z * (0x1.99999ap-2f + z * (0x1.24924ap-2f + z * 0x1.c71c72p-3f)));
 return (float) k * LN2F_HI - ((hfsq - (s * (hfsq + R) + (float) k * LN2F_LO)) - f); }

// x^y = e^(y ln x), ln x carried as a float pair: 2s and the s^3 term exact to a few
// ulp of their own, the rest of 2 atanh s in plain float; specials and |y| past 2^16 go
// through the double
float lm_powf(float x, float y) {
 if (y == 1.0f) return x;
 if (y == 2.0f) return x * x;
 if (y == -1.0f) return 1.0f / x;
 if (y == 0.5f && x > 0) return lm_sqrtf(x);
 uint32_t ux = muf(x) & 0x7fffffffu, uy = muf(y) & 0x7fffffffu;
 if (!ux || ux >= 0x7f800000u || !uy || uy >= 0x47800000u) return (float) lm_pow(x, y);
 int neg = 0;
 if (x < 0) {                                                // an integer y keeps the sign's parity
  float t = (float) (int32_t) y;
  if (uy >= 0x4b000000u) t = y;                              // past 2^23 every float is even
  if (t != y) return mkf(0x7fc00000u);
  neg = uy < 0x4b800000u && ((int32_t) y & 1);
  x = -x; }
 uint32_t u = muf(x);
 int k = 0;
 if (u < 0x800000u) x *= 0x1p25f, u = muf(x), k = -25;
 k += (int) (u >> 23) - 127;
 float m = mkf((u & 0x7fffffu) | 0x3f800000u);
 if ((u & 0x7fffffu) > 0x3504f3u) m *= 0.5f, k++;
 float f = m - 1.0f, dh, dl, sh, sl, ph, pl;
 fsum2(2.0f, f, &dh, &dl);
 sh = f / dh;                                                // s = f/(2 + f) as sh + sl
 fmul2(sh, dh, &ph, &pl);
 sl = (((f - ph) - pl) - sh * dl) / dh;
 float zh, zl, ch, cl;
 fmul2(sh, sh, &zh, &zl); zl += 2.0f * sh * sl;
 fmul2(sh, zh, &ch, &cl); cl += sh * zl + sl * zh;          // s^3
 float z = zh, th, tl;
 fmul2(ch, 0x1.555556p-1f, &th, &tl);                        // (2/3) s^3, 2/3 a pair
 tl += ch * -0x1.555556p-26f + cl * 0x1.555556p-1f;
 float rest = ch * z * (0x1.99999ap-2f + z * (0x1.24924ap-2f + z * (0x1.c71c72p-3f
            + z * (0x1.745d18p-3f + z * (0x1.3b13b2p-3f + z * (0x1.111112p-3f + z * 0x1.e1e1e2p-4f))))));
 float lh, ll, kh, kl;
 fsum2(2.0f * sh, th, &lh, &ll);                             // ln m
 ll += 2.0f * sl + tl + rest;
 fmul2((float) k, LN2F_HI, &kh, &kl);                        // + k ln2, its high part exact
 kl += (float) k * LN2F_LO;
 float sh2, sl2;
 fsum2(kh, lh, &sh2, &sl2);
 sl2 += kl + ll;
 fsum2(sh2, sl2, &lh, &ll);
 float wh, wl;
 fmul2(y, lh, &wh, &wl); wl += y * ll;
 if (wh > 0x1.62e42ep+6f) return mkf(neg ? 0xff800000u : 0x7f800000u);
 if (wh < -0x1.9fe368p+6f) return neg ? -0.0f : 0.0f;
 float e = lm_expf(wh);
 e = e + e * wl;
 return neg ? -e : e; }

// x = k pi/2 + r below |k| 256, pi/2 as three parts (16+16+24 bits); taylor kernels on
// |r| <= pi/4; past that the double's reduction
static const float PIO2F_1 = 0x1.922p+0f, PIO2F_2 = -0x1.2aeep-18f, PIO2F_3 = -0x1.e973dcp-35f,
                   INVPIO2F = 0x1.45f306p-1f;
static float ksinf(float r) { float z = r * r;
 return r + r * z * (-0x1.555556p-3f + z * (0x1.111112p-7f + z * (-0x1.a01a02p-13f + z * 0x1.71de3ap-19f))); }
static float kcosf(float r) { float z = r * r, hz = 0.5f * z, w = 1.0f - hz;
 return w + (((1.0f - w) - hz) + z * z * (0x1.555556p-5f + z * (-0x1.6c16c2p-10f + z * (0x1.a01a02p-16f + z * -0x1.27e4fcp-22f)))); }
// r carried hi+lo: the first two products are exact, so only the subtractions round
static int rpio2f(float x, float *r, float *rlo) {
 int k = (int) (x * INVPIO2F + (x > 0 ? 0.5f : -0.5f));
 float w, wl, v = (float) k * PIO2F_3;
 fsum2(x - (float) k * PIO2F_1, -(float) k * PIO2F_2, &w, &wl);
 fsum2(w, -v, r, rlo);
 *rlo += wl;
 return k; }
// sin and cos of r + rlo: the low part through the other's first term
static float ksinlf(float r, float rl) { return ksinf(r) + rl * (1.0f - 0.5f * r * r); }
static float kcoslf(float r, float rl) { return kcosf(r) - rl * r; }
float lm_sinf(float x) {
 uint32_t a = muf(x) & 0x7fffffffu;
 if (a < 0x39800000u) return x;                              // below 2^-12
 if (a >= 0x43c90000u) return (float) lm_sin(x);             // 402 and past, inf, nan
 float r, rl; int k = rpio2f(x, &r, &rl);
 switch (k & 3) { case 0: return ksinlf(r, rl); case 1: return kcoslf(r, rl); case 2: return -ksinlf(r, rl); default: return -kcoslf(r, rl); } }
float lm_cosf(float x) {
 uint32_t a = muf(x) & 0x7fffffffu;
 if (a < 0x39800000u) return 1.0f;
 if (a >= 0x43c90000u) return (float) lm_cos(x);
 float r, rl; int k = rpio2f(x, &r, &rl);
 switch (k & 3) { case 0: return kcoslf(r, rl); case 1: return -ksinlf(r, rl); case 2: return -kcoslf(r, rl); default: return ksinlf(r, rl); } }


// correctly rounded decimal -> binary64: a naive seed, then step one ulp until the input
// digits, compared exactly in decimal, fall inside the candidate's rounding interval
enum { lm_dgmax = 800 };   // a boundary expansion: 17 digits + one per x5 step (<= 1076)
static void lm_dgmul(unsigned char *d, int *n, int k) {   // k = 2 or 5
 int c = 0;
 for (int i = 0; i < *n; i++) { int t = d[i] * k + c; d[i] = t % 10; c = t / 10; }
 while (c) d[(*n)++] = c % 10, c /= 10; }
static void lm_dgexp(unsigned char *d, int *n, uint64_t m, int e2) {
 *n = 0;
 if (!m) d[(*n)++] = 0;
 while (m) d[(*n)++] = m % 10, m /= 10;
 for (; e2 > 0; e2--) lm_dgmul(d, n, 2);
 for (; e2 < 0; e2++) lm_dgmul(d, n, 5); }
// input digits a (LSB first, shifted up by sh virtual zeros, sticky marking a
// truncated nonzero tail) vs boundary digits b: -1 / 0 / +1
static int lm_dgcmp(unsigned char const *a, int na, int sh, int sticky,
                    unsigned char const *b, int nb) {
 if (sh < 0) {                                   // mirrored: shift b instead
  int r = lm_dgcmp(b, nb, -sh, 0, a, na);
  return r ? -r : (sticky ? 1 : 0); }
 if (na + sh != nb) return na + sh < nb ? -1 : 1;
 for (int i = nb - 1; i >= 0; i--) {
  int da = i >= sh ? a[i - sh] : 0;
  if (da != b[i]) return da < b[i] ? -1 : 1; }
 return sticky ? 1 : 0; }
// a hex float rounds once: m keeps 60 bits, a sticky bit the rest
static double lm_hexflo(uint64_t m, int e2, int sticky, int sign) {
 if (!m) return sign > 0 ? 0.0 : -0.0;
 while (!(m >> 63)) m <<= 1, e2--;               // normalize: MSB to bit 63
 int E = e2 + 63;                                // value in [2^E, 2^(E+1))
 if (E > 1023)  return sign > 0 ? DInf : -DInf;
 if (E < -1080) return sign > 0 ? 0.0 : -0.0;    // below half the last subnormal
 int sub = E < -1022, sh = sub ? 11 + (-1022 - E) : 11;   // bits to drop
 uint64_t sig;
 if (sh > 64) sig = 0;
 else if (sh == 64) sig = (m > ((uint64_t) 1 << 63) || sticky) ? 1 : 0;
 else {
  uint64_t lost = m & (((uint64_t) 1 << sh) - 1), half = (uint64_t) 1 << (sh - 1);
  sig = m >> sh;
  if (lost > half || (lost == half && (sticky || (sig & 1)))) sig++; }
 // a subnormal rounded up to 2^52 encodes as the smallest normal on its own
 if (sub) { double d = mkd(sig); return sign > 0 ? d : -d; }
 if (sig >> 53) sig >>= 1, E++;                  // the all-ones carry
 if (E > 1023) return sign > 0 ? DInf : -DInf;
 double d = mkd(((uint64_t) (E + 1023) << 52) | (sig & (((uint64_t) 1 << 52) - 1)));
 return sign > 0 ? d : -d; }
double lm_strtod(char const *s, char **end) {
 char const *p = s;
 int sign = 1;
 if (*p == '-') sign = -1, p++;
 else if (*p == '+') p++;
 // 0x H.H [p+-D], the exponent optional; a bare 0x reads as "0"
 if (p[0] == '0' && (p[1] == 'x' || p[1] == 'X')) {
  char const *q = p + 2;
  uint64_t hm = 0;
  int he = 0, hst = 0, hany = 0, hpt = 0;
  for (;; q++) {
   int d;
   if (*q == '.' && !hpt) { hpt = 1; continue; }
   if (*q >= '0' && *q <= '9') d = *q - '0';
   else if (*q >= 'a' && *q <= 'f') d = *q - 'a' + 10;
   else if (*q >= 'A' && *q <= 'F') d = *q - 'A' + 10;
   else break;
   hany = 1;
   if (hpt) he -= 4;
   if (hm >> 60) hst |= d != 0, he += 4;         // full: the digit is scale and sticky
   else hm = (hm << 4) | (uint64_t) d; }
  if (hany) {
   if (end) *end = (char*) q;
   if (*q == 'p' || *q == 'P') {
    char const *r = q + 1;
    int es = 1, pv = 0;
    if (*r == '-') es = -1, r++;
    else if (*r == '+') r++;
    if ('0' <= *r && *r <= '9') {
     while ('0' <= *r && *r <= '9') { if (pv < 100000) pv = pv * 10 + (*r - '0'); r++; }
     he += es * pv;
     if (end) *end = (char*) r; } }
   return lm_hexflo(hm, he, hst, sign); } }
 // up to 780 significant digits kept exactly (rounding can need ~768), the rest
 // a sticky bit; fr counts post-point digits
 unsigned char din[790];
 int any = 0, pt = 0, fr = 0, nin = 0, extra = 0, sticky = 0;
 double v0 = 0;
 for (;; p++) {
  if (*p == '.' && !pt) { pt = 1; continue; }
  if (*p < '0' || *p > '9') break;
  any = 1;
  if (pt) fr++;
  if (*p == '0' && !nin) continue;               // leading zeros: scale only (fr keeps them)
  if (nin < 780) {
   din[nin++] = (unsigned char) (*p - '0');      // MSB first while collecting
   if (nin <= 19) v0 = v0 * 10 + (*p - '0'); }
  else extra++, sticky |= *p != '0'; }
 for (int i = 0, j = nin - 1; i < j; i++, j--) {  // flip to LSB first for the compares
  unsigned char t = din[i]; din[i] = din[j]; din[j] = t; }
 if (!any) { if (end) *end = (char*) s; return 0; }
 if (end) *end = (char*) p;
 int e10 = 0;
 if (*p == 'e' || *p == 'E') {
  char const *q = p++;
  int esign = 1;
  if (*p == '-') esign = -1, p++;
  else if (*p == '+') p++;
  if (!('0' <= *p && *p <= '9')) p = q;
  else {
   while ('0' <= *p && *p <= '9') { if (e10 < 100000) e10 = e10 * 10 + (*p - '0'); p++; }
   e10 *= esign;
   if (end) *end = (char*) p; } }
 if (!nin) return sign > 0 ? 0.0 : -0.0;         // all zeros
 int kk = e10 - fr + extra;                      // value = din x 10^kk exactly (+ sticky)
 int mag = nin + kk;                             // value in [10^(mag-1), 10^mag)
 if (mag > 310)  return sign * DInf;
 if (mag < -342) return sign > 0 ? 0.0 : -0.0;
 // the seed: v0 holds the top 19 digits, scaled in bounded chunks
 { int e = kk + (nin > 19 ? nin - 19 : 0);
   while (e >= 300)  v0 *= 1e300, e -= 300;
   while (e <= -300) v0 /= 1e300, e += 300;
   double sc = 1;
   for (int a = e < 0 ? -e : e; a > 0; a--) sc *= 10;
   v0 = e < 0 ? v0 / sc : v0 * sc; }
 db b; b.d = v0;
 if (b.u >= 0x7ff0000000000000ull) b.u = 0x7fefffffffffffffull;   // seed stays finite
 unsigned char dg[lm_dgmax]; int ndg;
 for (;;) {
  uint64_t mant = b.u & ((1ull << 52) - 1);
  int be = (int) (b.u >> 52);
  uint64_t m = be ? mant | (1ull << 52) : mant;
  int e2 = (be ? be : 1) - 1023 - 52;
  int lo2 = be > 1 && mant == 0;                 // binade floor: the gap below halves
  int even = !(m & 1);
  int scb = e2 - 2 < 0 ? e2 - 2 : 0, sh = kk - scb;
  int cl, ch;
  if (!m) cl = 1;                                // zero: any positive input clears its floor
  else {
   lm_dgexp(dg, &ndg, 4 * m - (lo2 ? 1 : 2), e2 - 2);
   cl = lm_dgcmp(din, nin, sh, sticky, dg, ndg); }
  lm_dgexp(dg, &ndg, m ? 4 * m + 2 : 2, e2 - 2);
  ch = lm_dgcmp(din, nin, sh, sticky, dg, ndg);
  if ((cl > 0 || (cl == 0 && even)) && (ch < 0 || (ch == 0 && even))) break;
  if (ch >= 0) {                                 // at or past the upper midpoint: up one ulp
   if (b.u >= 0x7fefffffffffffffull) { b.u = 0x7ff0000000000000ull; break; }
   b.u++; }
  else {                                         // under the lower midpoint: down one ulp
   if (!b.u) break;                              // beneath half the least denormal: zero
   b.u--; } }
 return sign * b.d; }
