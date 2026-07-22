/* rung 5, mooncc side: by-value composites + AAPCS32 varargs.
   struct zn is love.c's shape -- a {double,double} HFA riding d-pairs both
   directions; dd the 8-byte one-sse blob (the packed S-pair, bit-identical);
   ii the <=4-byte int one (r0's word). vsum/vnth are love.c's variadic shapes
   (ai_push / ioprintf: anonymous WORDS only), vnth2 the decayed-va_list
   helper (gvzprintf's shape), ovnamed the named-params-overflow edge. */
#include <stdarg.h>
typedef unsigned uptr;

struct zn { double re, im; };
struct dd { double d; };
struct ii { short a, b; };

struct zn zmake(double re, double im) { struct zn z; z.re = re; z.im = im; return z; }
struct zn zadd(struct zn a, struct zn b) { return zmake(a.re + b.re, a.im + b.im); }
struct zn zmul(struct zn a, struct zn b) {
  return zmake(a.re*b.re - a.im*b.im, a.re*b.im + a.im*b.re); }
double znorm(struct zn a) { return a.re*a.re + a.im*a.im; }
double zmix(double s, struct zn a, int k, struct zn b) { return s + a.re*(double)k + b.im; }
double zchain(double x) {                 /* all-internal: make/add/mul/norm chained */
  struct zn a = zmake(x, 2.0*x);
  struct zn b = zadd(a, zmake(1.0, -3.0));
  struct zn c = zmul(a, b);
  return znorm(c) + c.re; }               /* member read off a call result */

struct dd dmake(double d) { struct dd r; r.d = d; return r; }
double dget(struct dd v) { return v.d * 2.0; }
struct ii imake(int a, int b) { struct ii r; r.a = (short)a; r.b = (short)b; return r; }
int isum(struct ii v) { return v.a + v.b; }

int vsum(int n, ...) {                    /* ai_push's shape: anonymous words */
  va_list ap; int s, i;
  va_start(ap, n); s = 0;
  for (i = 0; i < n; i++) s += va_arg(ap, int);
  va_end(ap); return s; }
static int vnth2(int idx, va_list ap) {   /* the decayed-va_list helper */
  int i; uptr t;
  for (i = 0; i < idx; i++) t = va_arg(ap, uptr);
  t = va_arg(ap, uptr); return (int)t; }
int vnth(int idx, ...) {
  va_list ap; int r;
  va_start(ap, idx); r = vnth2(idx, ap); va_end(ap); return r; }
int vcall(void) {                         /* mooncc-caller -> mooncc-variadic, anon args past r0-r3 */
  return vsum(6, 1, 2, 3, 4, 5, 6)*100 + vnth(2, 7, 8, 9, 10); }
int ovnamed(int a, int b, int c, int d, int e, ...) {  /* named params OVERFLOW: e rides the caller stack, anon args follow it */
  va_list ap; int x, y;
  va_start(ap, e);
  x = va_arg(ap, int); y = va_arg(ap, int);
  va_end(ap);
  return a + b*10 + c*100 + d*1000 + e*10000 + x*100000 + y*1000000; }
