/* sizeof of a string literal as an array bound (adjacent literals paste first),
   and 1e999: +inf in .data, IEEE compares, narrowing to a float inf. */
#include <math.h>

static double big = 1e999;                 /* +inf in .data -- fbits */
static float smallinf = 1e999;             /* +inf narrowed -- fbits32 */
static double nbig = -1e999;
static char out[] = { "luac.out" };        /* the optionally-BRACED string literal (6.7.9p14) sizes AND images */
static char padded[12] = { "hi" };
static unsigned const char uc = 7;         /* a qualifier INTERLEAVED in the specifier run (zlib's gzread) */

int main(void)
{
  char buf[sizeof("hello") + 2];           /* 8 -- the parse-time fold */
  double loc = 1e999;                      /* inf materialized in code, not .data */
  int r = 0;

  buf[0] = 1;
  r += (int) sizeof buf;                   /* 8 */
  r += (int) sizeof("a" "bc");             /* 4 -- pasting first, then the fold */

  if (big > 1.7e308) r += 10;              /* inf beats any finite */
  if (nbig < -1.7e308) r += 10;
  if (smallinf > 3.4e38f) r += 5;
  if (loc == big) r += 5;
  if (HUGE_VAL == big) r += 5;
  if (-big == nbig) r += 5;
  r += buf[0];                             /* 1 */
  r += (int) sizeof out;                   /* 9 -- the string's own count, not one item */
  r += out[0];                             /* 'l' = 108 */
  r += (int) sizeof padded + padded[11];   /* 12 + 0 (zero-padded past the literal) */
  r += uc;                                 /* 7 */

  return r;                                /* 8+4+10+10+5+5+5+5+1+9+108+12+7 = 189 */
}
