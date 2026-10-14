/* src/apps/moon/lib/moonlibc/cdiv.c -- C99 complex division by a complex divisor: the two
 * helpers gcc's lowering calls, libgcc's steps exactly, so a quotient's bits are gcc's. a
 * float quotient divides in double (libgcc's arm builds too, soft or single-precision); a
 * double one scales by the larger divisor part (smith). either recovers the infinities and
 * zeros a nan+nan answer lost (annex G). */
#include <stdint.h>

typedef union { double d; uint64_t u; } cdv_d;
typedef union { float f; uint32_t u; } cdv_f;
typedef union { double _Complex z; double p[2]; } cdv_dz;
typedef union { float _Complex z; float p[2]; } cdv_fz;

#define DMAG 0x7fffffffffffffffull
#define DINF 0x7ff0000000000000ull
#define FMAG 0x7fffffffu
#define FINF 0x7f800000u

static uint64_t db(double x) { cdv_d b; b.d = x; return b.u; }
static double dm(uint64_t u) { cdv_d b; b.u = u; return b.d; }
static uint32_t fb(float x) { cdv_f b; b.f = x; return b.u; }
static float fm(uint32_t u) { cdv_f b; b.u = u; return b.f; }
static double dabs(double x) { return dm(db(x) & DMAG); }
static int dnan(double x) { return (db(x) & DMAG) > DINF; }
static int dinf(double x) { return (db(x) & DMAG) == DINF; }
static int dfin(double x) { return (db(x) & DMAG) < DINF; }
static double dsign(double m, double s) { return dm((db(m) & DMAG) | (db(s) & ~DMAG)); }
static int fnan(float x) { return (fb(x) & FMAG) > FINF; }
static int finf(float x) { return (fb(x) & FMAG) == FINF; }
static int ffin(float x) { return (fb(x) & FMAG) < FINF; }
static float fsign(float m, float s) { return fm((fb(m) & FMAG) | (fb(s) & ~FMAG)); }

float _Complex __divsc3(float a, float b, float c, float d) {
  double aa = a, bb = b, cc = c, dd = d;
  double denom = (cc * cc) + (dd * dd);
  float x = (float) (((aa * cc) + (bb * dd)) / denom);
  float y = (float) (((bb * cc) - (aa * dd)) / denom);
  cdv_fz r;
  if (fnan(x) && fnan(y)) {
    if (c == 0.0f && d == 0.0f && (!fnan(a) || !fnan(b))) {
      x = fsign(fm(FINF), c) * a;
      y = fsign(fm(FINF), c) * b;
    } else if ((finf(a) || finf(b)) && ffin(c) && ffin(d)) {
      a = fsign(finf(a) ? 1.0f : 0.0f, a);
      b = fsign(finf(b) ? 1.0f : 0.0f, b);
      x = fm(FINF) * (a * c + b * d);
      y = fm(FINF) * (b * c - a * d);
    } else if ((finf(c) || finf(d)) && ffin(a) && ffin(b)) {
      c = fsign(finf(c) ? 1.0f : 0.0f, c);
      d = fsign(finf(d) ? 1.0f : 0.0f, d);
      x = 0.0f * (a * c + b * d);
      y = 0.0f * (b * c - a * d);
    }
  }
  r.p[0] = x;
  r.p[1] = y;
  return r.z;
}

#define RBIG     dm(0x7fdfffffffffffffull)          /* DBL_MAX / 2 */
#define RMIN     dm(0x0010000000000000ull)          /* DBL_MIN */
#define RMIN2    dm(0x3cb0000000000000ull)          /* DBL_EPSILON */
#define RMINSCAL dm(0x4330000000000000ull)          /* 1 / DBL_EPSILON */
#define RMAX2    dm(0x7c9fffffffffffffull)          /* RBIG * RMIN2 */

double _Complex __divdc3(double a, double b, double c, double d) {
  double denom, ratio, x, y;
  cdv_dz r;
  if (dabs(c) < dabs(d)) {
    if (dabs(d) >= RBIG) { a = a / 2; b = b / 2; c = c / 2; d = d / 2; }
    if (dabs(d) < RMIN2 ||
        (dabs(a) < RMIN && dabs(b) < RMAX2 && dabs(d) < RMAX2) ||
        (dabs(b) < RMIN && dabs(a) < RMAX2 && dabs(d) < RMAX2)) {
      a = a * RMINSCAL; b = b * RMINSCAL; c = c * RMINSCAL; d = d * RMINSCAL;
    }
    ratio = c / d;
    denom = (c * ratio) + d;
    if (dabs(ratio) > RMIN) {
      x = ((a * ratio) + b) / denom;
      y = ((b * ratio) - a) / denom;
    } else {
      x = ((c * (a / d)) + b) / denom;
      y = ((c * (b / d)) - a) / denom;
    }
  } else {
    if (dabs(c) >= RBIG) { a = a / 2; b = b / 2; c = c / 2; d = d / 2; }
    if (dabs(c) < RMIN2 ||
        (dabs(a) < RMIN && dabs(b) < RMAX2 && dabs(c) < RMAX2) ||
        (dabs(b) < RMIN && dabs(a) < RMAX2 && dabs(c) < RMAX2)) {
      a = a * RMINSCAL; b = b * RMINSCAL; c = c * RMINSCAL; d = d * RMINSCAL;
    }
    ratio = d / c;
    denom = (d * ratio) + c;
    if (dabs(ratio) > RMIN) {
      x = ((b * ratio) + a) / denom;
      y = (b - (a * ratio)) / denom;
    } else {
      x = (a + (d * (b / c))) / denom;
      y = (b - (d * (a / c))) / denom;
    }
  }
  if (dnan(x) && dnan(y)) {
    if (c == 0.0 && d == 0.0 && (!dnan(a) || !dnan(b))) {
      x = dsign(dm(DINF), c) * a;
      y = dsign(dm(DINF), c) * b;
    } else if ((dinf(a) || dinf(b)) && dfin(c) && dfin(d)) {
      a = dsign(dinf(a) ? 1.0 : 0.0, a);
      b = dsign(dinf(b) ? 1.0 : 0.0, b);
      x = dm(DINF) * (a * c + b * d);
      y = dm(DINF) * (b * c - a * d);
    } else if ((dinf(c) || dinf(d)) && dfin(a) && dfin(b)) {
      c = dsign(dinf(c) ? 1.0 : 0.0, c);
      d = dsign(dinf(d) ? 1.0 : 0.0, d);
      x = 0.0 * (a * c + b * d);
      y = 0.0 * (b * c - a * d);
    }
  }
  r.p[0] = x;
  r.p[1] = y;
  return r.z;
}
