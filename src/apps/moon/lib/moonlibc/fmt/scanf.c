#include "../impl.h"

/* the scanf family, C99 7.19.6.2: one engine over a string or a stream. a source reads a
 * character and gives one back (a stream's ungetc holds the one lookahead scanf needs); n counts
 * what the conversions consumed, for %n */
struct __ssrc { FILE *f; unsigned char const *s; long n; };
static int __sget(struct __ssrc *r) {
  int c = r->f ? getc(r->f) : (*r->s ? *r->s++ : EOF);
  if (c != EOF) r->n++;
  return c; }
static void __sunget(struct __ssrc *r, int c) {
  if (c == EOF) return;
  r->n--;
  if (r->f) ungetc(c, r->f); else r->s--; }
static int __sspace(int c) { return c == ' ' || (c >= '\t' && c <= '\r'); }
static int __sdig(int c, int base) {
  int d = c >= '0' && c <= '9' ? c - '0' : c >= 'a' && c <= 'z' ? c - 'a' + 10 : c >= 'A' && c <= 'Z' ? c - 'A' + 10 : 99;
  return d < base ? d : -1; }

/* an integer field of at most w characters: base 0 reads a C prefix. *v holds the magnitude, wrapped
 * past 64 bits as strtoul's callers see it saturated -- *over says it overflowed. 0 for no digits */
static int __sint(struct __ssrc *r, int base, int w, unsigned long *v, int *neg, int *over) {
  #define SNext (--w > 0 ? __sget(r) : EOF)            /* the width spent, nothing more is read */
  int c = __sget(r), any = 0;
  *v = 0; *neg = 0; *over = 0;
  if (c == '+' || c == '-') { *neg = c == '-'; c = SNext; }
  if (c == '0' && (base == 0 || base == 16)) {
    any = 1;
    c = SNext;
    if (c == 'x' || c == 'X') { base = 16; any = 0; c = SNext; }   /* 0x wants a digit after it */
    else if (base == 0) base = 8; }
  if (base == 0) base = 10;
  for (; __sdig(c, base) >= 0; c = SNext) {
    unsigned long d = (unsigned long) __sdig(c, base);
    if (*v > (~0UL - d) / (unsigned long) base) *over = 1;
    *v = *v * (unsigned long) base + d; any = 1; }
  #undef SNext
  __sunget(r, c);
  return any; }

/* a float field: the longest prefix strtod would take, gathered into b, then strtod */
static int __sflo(struct __ssrc *r, int w, double *out) {
  char b[512]; int n = 0, c = __sget(r);
  #define FlTake (b[n++] = (char) c, c = (--w > 0 && n < 510) ? __sget(r) : EOF)
  if (c == '+' || c == '-') FlTake;
  int lc = c | 32;
  if (lc == 'i' || lc == 'n') {                     /* inf, infinity, nan */
    char const *word = lc == 'i' ? "infinity" : "nan";
    int k = 0;
    while (w > 0 && word[k] && (c | 32) == word[k]) { FlTake; k++; }
    if (lc == 'i' && k != 3 && k != 8) { __sunget(r, c); return 0; }
    if (lc == 'n' && k != 3) { __sunget(r, c); return 0; }
    __sunget(r, c); b[n] = 0; *out = strtod(b, 0); return 1; }
  int hex = 0, digs = 0;
  if (c == '0') { FlTake; digs = 1; if ((c | 32) == 'x' && w > 0) { FlTake; hex = 1; digs = 0; } }
  while (w > 0 && (hex ? __sdig(c, 16) >= 0 : c >= '0' && c <= '9')) { FlTake; digs = 1; }
  if (w > 0 && c == '.') { FlTake; while (w > 0 && (hex ? __sdig(c, 16) >= 0 : c >= '0' && c <= '9')) { FlTake; digs = 1; } }
  if (!digs) { __sunget(r, c); return 0; }
  if (w > 0 && (c | 32) == (hex ? 'p' : 'e')) {     /* an exponent marker owes a digit */
    FlTake;
    if (w > 0 && (c == '+' || c == '-')) FlTake;
    int ed = 0;
    while (w > 0 && c >= '0' && c <= '9') { FlTake; ed = 1; }
    if (!ed) { __sunget(r, c); return 0; } }
  #undef FlTake
  __sunget(r, c);
  b[n] = 0; *out = strtod(b, 0);
  return 1; }

static int __vscan(struct __ssrc *r, char const *fmt, va_list ap) {
  int got = 0, c;
  for (; *fmt; fmt++) {
    if (__sspace((unsigned char) *fmt)) {           /* white space matches any run, even none */
      while (__sspace(c = __sget(r))) ;
      __sunget(r, c); continue; }
    if (*fmt != '%' || fmt[1] == '%') {
      if (*fmt == '%') { fmt++; while (__sspace(c = __sget(r))) ; }
      else c = __sget(r);
      if (c == (unsigned char) *fmt) continue;
      __sunget(r, c);
      return c == EOF && !got ? EOF : got; }
    fmt++;
    int skip = 0, w = 0, len = 0;
    if (*fmt == '*') { skip = 1; fmt++; }
    while (*fmt >= '0' && *fmt <= '9') w = w * 10 + (*fmt++ - '0');
    if (*fmt == 'h') { len = 'h'; if (*++fmt == 'h') { len = 'H'; fmt++; } }
    else if (*fmt == 'l') { len = 'l'; if (*++fmt == 'l') { len = 'q'; fmt++; } }
    else if (*fmt == 'L' || *fmt == 'q') { len = 'q'; fmt++; }
    else if (*fmt == 'j' || *fmt == 'z' || *fmt == 't') { len = 'l'; fmt++; }
    int cv = *fmt;
    if (!cv) break;
    if (cv == 'n') { if (!skip) {
        void *p = va_arg(ap, void *);
        if (len == 'H') *(signed char *) p = (signed char) r->n;
        else if (len == 'h') *(short *) p = (short) r->n;
        else if (len == 'l' || len == 'q') *(long *) p = r->n;
        else *(int *) p = (int) r->n; }
      continue; }
    if (cv != 'c' && cv != '[') {                   /* every other conversion skips white space first */
      while (__sspace(c = __sget(r))) ;
      if (c == EOF) return got ? got : EOF;
      __sunget(r, c); }
    if (cv == 'c') {
      if (!w) w = 1;
      char *o = skip ? 0 : va_arg(ap, char *);
      int k = 0;
      for (; k < w && (c = __sget(r)) != EOF; k++) if (o) o[k] = (char) c;
      if (k < w) return got ? got : EOF;              /* a %c the input runs out under is an input failure */
      if (o) got++; continue; }
    if (cv == 's' || cv == '[') {
      unsigned char set[256]; int inv = 0;
      if (cv == '[') {
        fmt++;
        if (*fmt == '^') { inv = 1; fmt++; }
        memset(set, 0, sizeof set);
        if (*fmt == ']') { set[']'] = 1; fmt++; }
        for (; *fmt && *fmt != ']'; fmt++)
          if (fmt[1] == '-' && fmt[2] && fmt[2] != ']') {
            for (int a = (unsigned char) fmt[0]; a <= (unsigned char) fmt[2]; a++) set[a] = 1;
            fmt += 2; }
          else set[(unsigned char) *fmt] = 1;
        if (!*fmt) return got; }
      char *o = skip ? 0 : va_arg(ap, char *);
      int k = 0;
      if (!w) w = -1;
      while (k != w && (c = __sget(r)) != EOF) {
        int in = cv == 's' ? !__sspace(c) : (set[c] ^ inv);
        if (!in) { __sunget(r, c); break; }
        if (o) o[k] = (char) c;
        k++; }
      if (!k) return c == EOF && !got ? EOF : got;
      if (o) { o[k] = 0; got++; }
      continue; }
    if (cv == 'd' || cv == 'i' || cv == 'u' || cv == 'o' || cv == 'x' || cv == 'X' || cv == 'p') {
      int base = cv == 'i' ? 0 : cv == 'o' ? 8 : (cv == 'x' || cv == 'X' || cv == 'p') ? 16 : 10;
      unsigned long v; int neg, over;
      if (!__sint(r, base, w ? w : 1 << 30, &v, &neg, &over)) return got;
      if (skip) continue;
      /* signed conversions take strtol's view (saturating), unsigned strtoul's (negation wraps) */
      long sv;
      if (cv == 'd' || cv == 'i') {
        if (over || v > (neg ? 0x8000000000000000UL : 0x7fffffffffffffffUL)) sv = neg ? LONG_MIN : LONG_MAX;
        else sv = neg ? (long) (0UL - v) : (long) v;
        v = (unsigned long) sv; }
      else { if (over) v = ~0UL; else if (neg) v = 0UL - v; }
      void *p = va_arg(ap, void *);
      if (cv == 'p') *(void **) p = (void *) v;
      else if (len == 'H') *(char *) p = (char) v;
      else if (len == 'h') *(short *) p = (short) v;
      else if (len == 'l' || len == 'q') *(long *) p = (long) v;
      else *(int *) p = (int) v;
      got++; continue; }
    if (cv == 'f' || cv == 'F' || cv == 'e' || cv == 'E' || cv == 'g' || cv == 'G' || cv == 'a' || cv == 'A') {
      double d;
      if (!__sflo(r, w ? w : 1 << 30, &d)) return got;
      if (skip) continue;
      if (len == 'l' || len == 'q') *va_arg(ap, double *) = d;
      else *va_arg(ap, float *) = (float) d;
      got++; continue; }
    return got; }                                   /* an unknown conversion ends the scan */
  return got; }

int vsscanf(char const *s, char const *fmt, va_list ap) {
  struct __ssrc r = { 0, (unsigned char const *) s, 0 };
  return __vscan(&r, fmt, ap); }
int vfscanf(FILE *f, char const *fmt, va_list ap) {
  struct __ssrc r = { f, 0, 0 };
  return __vscan(&r, fmt, ap); }
int vscanf(char const *fmt, va_list ap) { return vfscanf(stdin, fmt, ap); }
int sscanf(char const *s, char const *fmt, ...) {
  va_list ap; va_start(ap, fmt); int n = vsscanf(s, fmt, ap); va_end(ap); return n; }
int fscanf(FILE *f, char const *fmt, ...) {
  va_list ap; va_start(ap, fmt); int n = vfscanf(f, fmt, ap); va_end(ap); return n; }
int scanf(char const *fmt, ...) {
  va_list ap; va_start(ap, fmt); int n = vfscanf(stdin, fmt, ap); va_end(ap); return n; }
