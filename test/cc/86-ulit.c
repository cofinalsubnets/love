/* u-suffixed literals carry their unsignedness (1ULL: neg/div/shift/compare
 * go unsigned); image-time float const expressions fold (1/DBL_EPSILON);
 * a for-init declaration takes leading qualifiers; __builtin_inf/nan.
 * The fdlibm fabs shape is the canary: -1ULL/2 as a signed division is 0
 * and fabs answers a denormal ~0 instead of |x|. */
typedef unsigned long uint64_t;

static const double toint = 1/2.22044604925031308085e-16;   /* image float fold */

static double fabs2(double x) {
  union {double f; uint64_t i;} u = {x};
  u.i &= -1ULL/2;
  return u.f; }

static const char digits[] = "0123456789";

int main(void) {
  int r = (int)fabs2(-3.5) * 4;                  /* 12; 0*4 under the signed-div bug */
  r += (-1ULL / 2) > (1ULL << 62) ? 10 : 0;      /* unsigned div + shift + compare */
  r += (int)(-1u >> 28);                         /* 15: unsigned int literal, logical shift */
  r += toint > 4.5e15 && toint < 4.6e15 ? 3 : 0; /* the folded image landed */
  double inf = __builtin_inf(), nan = __builtin_nan("");
  r += (inf > 1e308) + (nan != nan);             /* 2 */
  for (const char *p = digits; *p; p++) r += 0;  /* qualified for-init decl parses */
  return r; }                                    /* 12+10+15+3+2 = 42 */
