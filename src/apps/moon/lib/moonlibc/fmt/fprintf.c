#include "../impl.h"

static unsigned long const bd_p10[9] = {
  1UL, 10UL, 100UL, 1000UL, 10000UL, 100000UL, 1000000UL, 10000000UL, 100000000UL };
/* the digit at index k -- BdU is the units place, larger is further right.
 * OUTSIDE the array every digit is a zero, which is what lets an arbitrary
 * precision print with no buffer and no cap. */
static unsigned bd_dig(unsigned long const *d, int k) {
  if (k < 0 || k >= BdD) return 0;
  return (unsigned) (d[k / 9] / bd_p10[8 - k % 9] % 10UL); }
/* the live range shrinks toward index 0 as the value grows and toward BdN as
 * it shrinks, so both walks carry their bound rather than sweeping the array:
 * a shift is O(digits that exist), not O(1413). */
static int bd_mul2(unsigned long *d, int lo, int hi, int s) {
  unsigned long carry = 0;
  int i;
  for (i = hi; i >= 0; i--) {
    if (i < lo && !carry) break;
    unsigned long cur = (d[i] << s) + carry;
    d[i] = cur % BdB;
    carry = cur / BdB; }
  return i + 1 < lo ? i + 1 : lo; }
static int bd_div2(unsigned long *d, int lo, int hi, int s) {
  unsigned long rem = 0, m = 1UL << s;
  int i;
  for (i = lo; i < BdN; i++) {
    if (i > hi && !rem) break;
    unsigned long cur = rem * BdB + d[i];
    d[i] = cur / m;
    rem = cur % m; }
  return i - 1 > hi ? i - 1 : hi; }
/* zero every digit after index k */
static void bd_trunc(unsigned long *d, int k) {
  int i;
  if (k >= BdD) return;
  if (k < 0) i = 0;
  else { d[k / 9] -= d[k / 9] % bd_p10[8 - k % 9]; i = k / 9 + 1; }
  for (; i < BdN; i++) d[i] = 0; }
/* add one at digit index k, carrying toward index 0. the array has 324 integer
 * digits against a largest double of 309, so the carry always lands. */
static int bd_inc(unsigned long *d, int k, int lo) {
  int i = k / 9;
  unsigned long add = bd_p10[8 - k % 9];
  while (i >= 0) {
    d[i] += add;
    if (d[i] < BdB) break;
    d[i] -= BdB; add = 1; i--; }
  return i >= 0 && i < lo ? i : lo; }
/* round to keep digits through index k. the value is exact, so a TIE is a real
 * tie and breaks to even -- %.0f of 2.5 is 2 and of 3.5 is 4. */
static int bd_round(unsigned long *d, int k, int lo) {
  unsigned n = bd_dig(d, k + 1);
  int up = n > 5;
  if (n == 5) {
    int j = k + 2, any = 0, lim = (j + 8) / 9 * 9;
    for (; j < lim && j < BdD; j++) if (bd_dig(d, j)) { any = 1; break; }
    if (!any) for (j = lim / 9; j < BdN; j++) if (d[j]) { any = 1; break; }
    up = any || (bd_dig(d, k) & 1); }
  bd_trunc(d, k);
  return up ? bd_inc(d, k, lo) : lo; }
/* the index of the most significant digit that is not a zero, or the units
 * place when the value is zero (which reads 0 and dates the exponent at 0). */
static int bd_msd(unsigned long const *d, int lo) {
  for (int i = lo; i < BdN; i++)
    if (d[i]) { int k = i * 9; while (!bd_dig(d, k)) k++; return k; }
  return BdU; }
/* the float lanes: %f %e %g %a and their upper-case twins. */
static void __fmtflo(void (*put)(void *, int), void *ctx, double v, int conv,
                     int prec, int width, int fl) {
  unsigned long bits;
  memcpy(&bits, &v, sizeof bits);
  int neg = (int) (bits >> 63);            /* from the SIGN BIT, not v < 0:
                                              -0.0 is not less than zero, and
                                              printf must still say -0 */
  int be = (int) ((bits >> 52) & 0x7ffUL);
  unsigned long man = bits & 0xfffffffffffffUL;
  int up = conv == 'E' || conv == 'G' || conv == 'F' || conv == 'A';
  if (up) conv += 32;
  int sgn = __fmtsgn(neg, fl);

  /* --- infinity and not-a-number: three letters, and the zero flag does not
     reach them -- a wide %08.1f of -inf pads with spaces. */
  if (be == 0x7ff) {
    char const *w = man ? "nan" : "inf";
    int len = 3 + (sgn ? 1 : 0);
    int pad = width > len ? width - len : 0;
    if (!(fl & FfLeft)) __pad(put, ctx, pad, 32);
    if (sgn) put(ctx, sgn);
    for (int i = 0; i < 3; i++) put(ctx, up ? w[i] - 32 : w[i]);
    if (fl & FfLeft) __pad(put, ctx, pad, 32);
    return; }

  /* --- %a: the bits themselves, four to a hex digit, so only the rounding at
     a short precision needs any care. a subnormal keeps the -1022 exponent and
     shows a leading 0 rather than renormalising, and so does a mantissa that
     rounds up past f -- 0.999999 at %.1a is 0x2.0p-1, not 0x1.0p+0. */
  if (conv == 'a') {
    int lead = be ? 1 : 0;
    int xe = be ? be - 1023 : man ? -1022 : 0;
    int nd = 13;
    if (prec >= 0 && prec < 13) {
      nd = prec;
      unsigned g = (unsigned) ((man >> (48 - 4 * nd)) & 0xfUL);
      unsigned long rest = man & ((1UL << (48 - 4 * nd)) - 1);
      int odd = nd ? (int) ((man >> (52 - 4 * nd)) & 1UL) : lead & 1;
      int rup = g > 8 || (g == 8 && (rest || odd));
      man &= ~((1UL << (52 - 4 * nd)) - 1);
      if (rup) { man += 1UL << (52 - 4 * nd);
                 if (man >> 52) { man &= 0xfffffffffffffUL; lead++; } } }
    else if (prec >= 0) nd = prec;                    /* past 13, all zeros */
    else while (nd && !((man >> (52 - 4 * nd)) & 0xfUL)) nd--;
    int pt = nd > 0 || (fl & FfAlt);
    int ax = xe < 0 ? -xe : xe;
    int nx = 1; for (int t = ax; t >= 10; t /= 10) nx++;
    int len = (sgn ? 1 : 0) + 2 + 1 + (pt ? 1 + nd : 0) + 2 + nx;
    int pad = width > len ? width - len : 0;
    if (!(fl & (FfLeft | FfZero))) __pad(put, ctx, pad, 32);
    if (sgn) put(ctx, sgn);
    put(ctx, '0'); put(ctx, up ? 'X' : 'x');
    if (!(fl & FfLeft) && (fl & FfZero)) __pad(put, ctx, pad, 48);
    put(ctx, (char) ('0' + lead));
    if (pt) {
      put(ctx, '.');
      for (int j = 0; j < nd; j++) {
        unsigned h = j < 13 ? (unsigned) ((man >> (48 - 4 * j)) & 0xfUL) : 0;
        put(ctx, h < 10 ? '0' + h : (up ? 55 : 87) + h); } }
    put(ctx, up ? 'P' : 'p');
    put(ctx, xe < 0 ? '-' : '+');
    for (int t = nx; t; t--) { int q = ax; for (int u = 1; u < t; u++) q /= 10; put(ctx, '0' + q % 10); }
    if (fl & FfLeft) __pad(put, ctx, pad, 32);
    return; }

  /* --- the decimal lanes, off the exact digits. */
  unsigned long bd[BdN];
  for (int i = 0; i < BdN; i++) bd[i] = 0;
  unsigned long m = be ? man | 0x10000000000000UL : man;
  int e2 = be ? be - 1075 : -1074;               /* the value is m * 2^e2 */
  bd[BdI - 1] = m % BdB;
  bd[BdI - 2] = m / BdB;                       /* m < 2^53, so two limbs */
  int lo = BdI - 2, hi = BdI - 1;
  for (int s = e2; s > 0; ) { int k = s > 30 ? 30 : s; lo = bd_mul2(bd, lo, hi, k); s -= k; }
  for (int s = -e2; s > 0; ) { int k = s > 30 ? 30 : s; hi = bd_div2(bd, lo, hi, k); s -= k; }

  int msd = bd_msd(bd, lo);
  int fprec, cut, strip = 0;
  if (conv == 'g') {
    int p = prec < 0 ? 6 : prec ? prec : 1;
    lo = bd_round(bd, msd + p - 1, lo);
    msd = bd_msd(bd, lo);                        /* 999 -> 1000 moves it */
    int dexp = BdU - msd;
    conv = (dexp < -4 || dexp >= p) ? 'e' : 'f';
    fprec = conv == 'e' ? p - 1 : p - 1 - dexp;
    if (fprec < 0) fprec = 0;
    strip = !(fl & FfAlt); }
  else {
    fprec = prec < 0 ? 6 : prec;
    cut = conv == 'e' ? msd + fprec : BdU + fprec;
    lo = bd_round(bd, cut, lo);
    msd = bd_msd(bd, lo); }

  /* the digits to show: one at msd for %e, or the whole integer part for %f --
     and when the value has none, the units place, which reads the 0 that C
     asks for. */
  int i0 = conv == 'e' ? msd : msd < BdU ? msd : BdU;
  int i1 = conv == 'e' ? msd : BdU;
  if (strip) while (fprec && !bd_dig(bd, i1 + fprec)) fprec--;
  int pt = fprec > 0 || (fl & FfAlt);
  int xe = BdU - msd, ax = xe < 0 ? -xe : xe, nx = 1;
  for (int t = ax; t >= 10; t /= 10) nx++;
  if (nx < 2) nx = 2;                            /* the exponent shows two */

  int len = (sgn ? 1 : 0) + (i1 - i0 + 1) + (pt ? 1 + fprec : 0)
          + (conv == 'e' ? 2 + nx : 0);
  int pad = width > len ? width - len : 0;
  if (!(fl & (FfLeft | FfZero))) __pad(put, ctx, pad, 32);
  if (sgn) put(ctx, sgn);
  if (!(fl & FfLeft) && (fl & FfZero)) __pad(put, ctx, pad, 48);
  for (int k = i0; k <= i1; k++) put(ctx, '0' + bd_dig(bd, k));
  if (pt) { put(ctx, '.');
            for (int j = 1; j <= fprec; j++) put(ctx, '0' + bd_dig(bd, i1 + j)); }
  if (conv == 'e') {
    put(ctx, up ? 'E' : 'e');
    put(ctx, xe < 0 ? '-' : '+');
    for (int t = nx; t; t--) { int q = ax; for (int u = 1; u < t; u++) q /= 10; put(ctx, '0' + q % 10); } }
  if (fl & FfLeft) __pad(put, ctx, pad, 32); }
/* one directive, parsed: its value's place (pos, 0 = the next argument), the width and the
 * precision -- or the argument each comes from (wa/pa: -1 the next, n the n-th) -- the length
 * (H hh, h, l for every word-wide one, L) and the conversion */
struct __fsp { int fl, width, prec, wa, pa, pos, len, conv; };
static char const *__fdigits(char const *f, int *n) {
  *n = 0; while (*f >= '0' && *f <= '9') *n = *n * 10 + (*f++ - 48);
  return f; }
/* an argument's number, *N$ or N$; zero when the text is not one */
static char const *__fargno(char const *f, int *n) {
  char const *q = __fdigits(f, n);
  if (*q == '$' && *n) return q + 1;
  *n = 0; return f; }
static char const *__fparse(char const *f, struct __fsp *sp) {
  int n;
  sp->fl = 0; sp->width = 0; sp->prec = -1; sp->wa = 0; sp->pa = 0; sp->len = 0;
  f = __fargno(f, &sp->pos);
  for (; ; f++) {                          /* flags: all five of them act */
    if (*f == '-') sp->fl |= FfLeft;
    else if (*f == '0') sp->fl |= FfZero;
    else if (*f == '+') sp->fl |= FfPlus;
    else if (*f == ' ') sp->fl |= FfSpc;
    else if (*f == '#') sp->fl |= FfAlt;
    else break; }
  if (*f == '*') { f = __fargno(f + 1, &n); sp->wa = n ? n : -1; }
  else f = __fdigits(f, &sp->width);
  if (*f == '.') {
    f++;
    if (*f == '*') { f = __fargno(f + 1, &n); sp->pa = n ? n : -1; }
    else f = __fdigits(f, &sp->prec); }
  if (*f == 'h') { f++; sp->len = 'h'; if (*f == 'h') { f++; sp->len = 'H'; } }
  else if (*f == 'L') { f++; sp->len = 'L'; }
  else while (*f == 'l' || *f == 'z' || *f == 'j' || *f == 't' || *f == 'q') { f++; sp->len = 'l'; }
  sp->conv = *f;
  return f; }
/* what a directive's value is read as: an int, a word (long, a pointer), or a double */
static int __fkind(struct __fsp const *sp) {
  int c = sp->conv;
  if (c == 's' || c == 'p' || c == 'n') return 'l';
  if (c == 'f' || c == 'F' || c == 'e' || c == 'E' || c == 'g' || c == 'G' || c == 'a' || c == 'A') return 'd';
  return sp->len == 'l' ? 'l' : 'i'; }
/* the arguments: off the va_list in order, or -- once a directive names one by number
 * (POSIX's %n$) -- fetched whole first, each by the kind its directives read it as */
#define FArgMax 64
union __farg { long i; double d; };
struct __fargs { va_list ap; union __farg a[FArgMax + 1]; int npos, next; };
static union __farg __fget(struct __fargs *A, int pos, int kind) {
  union __farg v;
  if (A->npos) { v = pos > 0 && pos <= FArgMax ? A->a[pos] : A->a[0]; return v; }
  if (kind == 'd') v.d = va_arg(A->ap, double);
  else if (kind == 'l') v.i = va_arg(A->ap, long);
  else v.i = va_arg(A->ap, int);
  return v; }
/* the count every directive owes (%n reads it, the call answers it), and a sticky failure */
struct __fcount { void (*put)(void *, int); void *ctx; long n; int bad; };
static void __fcput(void *c, int ch) { struct __fcount *k = c; k->n++; k->put(k->ctx, ch); }
static int __fmt(void (*put0)(void *, int), void *ctx0, char const *fmt, va_list ap0) {
  struct __fcount k = { put0, ctx0, 0, 0 };
  void (*put)(void *, int) = __fcput;
  void *ctx = &k;
  struct __fargs A;
  va_copy(A.ap, ap0);
  A.npos = 0;
  struct __fsp sp;
  /* the numbered lane: a first pass learns each argument's kind, then they are read in order */
  for (char const *f = fmt; *f; f++) {
    if (*f != '%') continue;
    if (f[1] == '%') { f++; continue; }
    f = __fparse(f + 1, &sp);
    if (!*f) break;
    if (sp.pos > 0) { A.npos = 1; break; } }
  if (A.npos) {
    int kd[FArgMax + 1], top = 0;
    for (int i = 0; i <= FArgMax; i++) { kd[i] = 0; A.a[i].i = 0; }
    for (char const *f = fmt; *f; f++) {
      if (*f != '%') continue;
      if (f[1] == '%') { f++; continue; }
      f = __fparse(f + 1, &sp);
      if (!*f) break;
      if (sp.wa > 0 && sp.wa <= FArgMax) { kd[sp.wa] = 'i'; if (sp.wa > top) top = sp.wa; }
      if (sp.pa > 0 && sp.pa <= FArgMax) { kd[sp.pa] = 'i'; if (sp.pa > top) top = sp.pa; }
      if (sp.pos > 0 && sp.pos <= FArgMax) { kd[sp.pos] = __fkind(&sp); if (sp.pos > top) top = sp.pos; } }
    for (int i = 1; i <= top; i++) {
      if (kd[i] == 'd') A.a[i].d = va_arg(A.ap, double);
      else if (kd[i] == 'i') A.a[i].i = va_arg(A.ap, int);
      else A.a[i].i = va_arg(A.ap, long); } }
  for (; *fmt; fmt++) {
    if (*fmt != '%') { put(ctx, *fmt); continue; }
    if (fmt[1] == '%') { put(ctx, 37); fmt++; continue; }
    char const *at = fmt;
    fmt = __fparse(fmt + 1, &sp);
    if (!*fmt) { for (; at < fmt; at++) put(ctx, *at); fmt--; continue; }
    int fl = sp.fl, width = sp.width, prec = sp.prec;
    if (sp.wa) { width = (int) __fget(&A, sp.wa, 'i').i; if (width < 0) { fl |= FfLeft; width = -width; } }
    if (sp.pa) { prec = (int) __fget(&A, sp.pa, 'i').i; if (prec < 0) prec = -1; }
    if (fl & FfLeft) fl &= ~FfZero;
    if (fl & FfPlus) fl &= ~FfSpc;         /* + outranks the space */
    int c = sp.conv;
    union __farg v = __fget(&A, sp.pos, __fkind(&sp));
    if (c == 's' && sp.len == 'l') {       /* a wide string in the C locale: ascii, past it EILSEQ */
      int const *w = (int const *) v.i;
      if (!w) w = (int const *) L"(null)";
      int len = 0;
      while (w[len] && (prec < 0 || len < prec)) { if ((unsigned) w[len] > 127) { k.bad = 1; break; } len++; }
      if (k.bad) break;
      int pad = width > len ? width - len : 0;
      if (!(fl & FfLeft)) __pad(put, ctx, pad, 32);
      for (int i = 0; i < len; i++) put(ctx, w[i]);
      if (fl & FfLeft) __pad(put, ctx, pad, 32); }
    else if (c == 's') {
      char const *s = (char const *) v.i;
      if (!s) s = "(null)";
      int len = 0;
      while (s[len] && (prec < 0 || len < prec)) len++;
      int pad = width > len ? width - len : 0;
      if (!(fl & FfLeft)) __pad(put, ctx, pad, 32);
      for (int i = 0; i < len; i++) put(ctx, s[i]);
      if (fl & FfLeft) __pad(put, ctx, pad, 32); }
    else if (c == 'c') {
      if (sp.len == 'l' && (unsigned long) v.i > 127) { k.bad = 1; break; }
      int pad = width > 1 ? width - 1 : 0;
      if (!(fl & FfLeft)) __pad(put, ctx, pad, 32);
      put(ctx, (unsigned char) v.i);
      if (fl & FfLeft) __pad(put, ctx, pad, 32); }
    else if (c == 'd' || c == 'i') {
      long x = sp.len == 'l' ? v.i : sp.len == 'h' ? (short) v.i : sp.len == 'H' ? (signed char) v.i : (int) v.i;
      unsigned long u = (unsigned long) x;
      int neg = x < 0;
      if (neg) u = 0UL - u;
      __fmtnum(put, ctx, u, 10, neg, prec, width, fl, 0); }
    else if (c == 'u' || c == 'x' || c == 'X' || c == 'o') {
      unsigned long u = sp.len == 'l' ? (unsigned long) v.i : sp.len == 'h' ? (unsigned short) v.i
                      : sp.len == 'H' ? (unsigned char) v.i : (unsigned int) v.i;
      __fmtnum(put, ctx, u, c == 'u' ? 10 : c == 'o' ? 8 : 16, 0, prec, width, fl & ~(c == 'u' ? FfAlt : 0), c == 'X'); }
    else if (c == 'f' || c == 'F' || c == 'e' || c == 'E' || c == 'g' || c == 'G' || c == 'a' || c == 'A')
      __fmtflo(put, ctx, v.d, c, prec, width, fl);
    else if (c == 'p') {                     /* glibc's: 0x and the hex, or (nil) */
      if (v.i) __fmtnum(put, ctx, (unsigned long) v.i, 16, 0, prec, width, fl | FfAlt, 0);
      else { int pad = width > 5 ? width - 5 : 0;
             if (!(fl & FfLeft)) __pad(put, ctx, pad, 32);
             for (char const *q = "(nil)"; *q; q++) put(ctx, *q);
             if (fl & FfLeft) __pad(put, ctx, pad, 32); } }
    else if (c == 'n') {
      void *p = (void *) v.i;
      if (sp.len == 'H') *(signed char *) p = (signed char) k.n;
      else if (sp.len == 'h') *(short *) p = (short) k.n;
      else if (sp.len == 'l') *(long *) p = k.n;
      else *(int *) p = (int) k.n; }
    else for (; at <= fmt; at++) put(ctx, *at); }   /* not a conversion: the text stands */
  va_end(A.ap);
  if (k.bad) { __errno_v = EILSEQ; return -1; }
  return (int) k.n; }
int fprintf(FILE *f, char const *fmt, ...) {
  va_list ap; va_start(ap, fmt);
  int r = __fmt(__femit, f, fmt, ap);
  va_end(ap);
  return r; }
int snprintf(char *p, size_t n, char const *fmt, ...) {
  struct __sctx s;
  s.p = p; s.n = n; s.at = 0;
  va_list ap; va_start(ap, fmt);
  int r = __fmt(__semit, &s, fmt, ap);
  va_end(ap);
  if (n) p[s.at < n ? s.at : n - 1] = 0;
  return r < 0 ? r : (int) s.at; }
int printf(char const *fmt, ...) {
  va_list ap; va_start(ap, fmt);
  int r = __fmt(__femit, stdout, fmt, ap);
  va_end(ap);
  return r; }
/* the v-variants: __fmt copies the va_list it is handed, so these just forward it. */
int vfprintf(FILE *f, char const *fmt, va_list ap) { return __fmt(__femit, f, fmt, ap); }
int vprintf(char const *fmt, va_list ap) { return __fmt(__femit, stdout, fmt, ap); }
int vsnprintf(char *p, size_t n, char const *fmt, va_list ap) {
  struct __sctx s; s.p = p; s.n = n; s.at = 0;
  int r = __fmt(__semit, &s, fmt, ap);
  if (n) p[s.at < n ? s.at : n - 1] = 0;
  return r < 0 ? r : (int) s.at; }
/* asprintf: measure with a null sink, then format into a fresh block. two
 * passes over the format rather than a growing buffer -- __fmt counts either way. */
int vasprintf(char **out, char const *fmt, va_list ap) {
  struct __sctx s; s.p = 0; s.n = 0; s.at = 0;
  va_list m;                                       /* the measuring pass takes a COPY:
                                                    * __fmt walks the list to its end */
  va_copy(m, ap);
  int r = __fmt(__semit, &s, fmt, m);
  va_end(m);
  if (r < 0) return *out = 0, -1;
  char *b = malloc(s.at + 1);
  if (!b) return *out = 0, -1;
  struct __sctx t; t.p = b; t.n = s.at + 1; t.at = 0;
  __fmt(__semit, &t, fmt, ap);
  b[t.at] = 0;
  return *out = b, (int) t.at; }
