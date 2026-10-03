/* scanf against glibc's: a battery of formats over inputs, each reporting the count it answers
 * and what it stored -- integers in every base and width, the sign and prefix edges, overflow,
 * %c %s %[..] with widths and sets, %n, suppression, literal and white-space matching, floats in
 * each spelling, and the EOF and matching-failure returns. then fscanf over a stream, which must
 * leave the stream where glibc's does */
#include <stdio.h>
#include <string.h>
#include "say.h"

static char const *ins[] = { "", "   ", "42", "-17 x", "+5", "0x1f", "0X", "0xg", "017", "08", "  12abc", "abc",
  "9223372036854775807", "9223372036854775808", "-9223372036854775809", "18446744073709551616", "4294967296",
  "123456", "hello world", "a]b", "-", "+", "3.5", "-0.25e3", "1e", ".5", "5.", "inf", "-INFINITY", "nan", "0x1.8p1",
  "1,2,3", "x=7;y=9", "%5", "  % 6", "7 8 9 10" };

int main(void) {
  int ni = sizeof ins / sizeof *ins;
  for (int k = 0; k < ni; k++) {
    char const *in = ins[k];
    int a = -1, b = -1, n1 = -1, n2 = -1; long l = -1; unsigned u = 0; unsigned long ul = 0; short h = -1; signed char hh = -1;
    char s1[32], s2[32], c3[4] = "###"; double d = -1; float f = -1; void *p = 0;
    char line[160];
    #define R(fmt, ...) do { memset(s1, '#', sizeof s1); s1[31] = 0; memset(s2, '#', sizeof s2); s2[31] = 0; \
      int r = sscanf(in, fmt, __VA_ARGS__); snprintf(line, sizeof line, "%s|%s -> %d", in, fmt, r); say_s("case", line); } while (0)
    R("%d", &a); say_n("  a", a);
    R("%i", &a); say_n("  a", a);
    R("%x", &u); say_n("  u", u);
    R("%o", &u); say_n("  u", u);
    R("%u", &u); say_n("  u", u);
    R("%ld", &l); say_n("  l", l);
    R("%lu", &ul); say_n("  ul.hi", (long) (ul >> 32)); say_n("  ul.lo", (long) (ul & 0xffffffff));
    R("%hd", &h); say_n("  h", h);
    R("%hhd", &hh); say_n("  hh", hh);
    R("%3d%d", &a, &b); say_n("  a", a); say_n("  b", b);
    R("%2x%n", &u, &n1); say_n("  u", u); say_n("  n", n1);
    R("%s %s", s1, s2); say_s("  s1", s1); say_s("  s2", s2);
    R("%3s%n", s1, &n1); say_s("  s1", s1); say_n("  n", n1);
    R("%3c", c3); c3[3] = 0; say_s("  c3", c3);
    R("%[a-z]%n", s1, &n1); say_s("  s1", s1); say_n("  n", n1);
    R("%[^,],%[^,]", s1, s2); say_s("  s1", s1); say_s("  s2", s2);
    R("%[]a]%n", s1, &n1); say_s("  s1", s1); say_n("  n", n1);
    R("%*d %d", &a); say_n("  a", a);
    R("x=%d;y=%d", &a, &b); say_n("  a", a); say_n("  b", b);
    R("%%%d", &a); say_n("  a", a);
    R("%lf", &d); { char t[40]; snprintf(t, sizeof t, "%.6g", d); say_s("  d", t); }
    R("%f%n", &f, &n1); { char t[40]; snprintf(t, sizeof t, "%.6g", (double) f); say_s("  f", t); say_n("  n", n1); }
    R("%4lf%n", &d, &n1); { char t[40]; snprintf(t, sizeof t, "%.6g", d); say_s("  d", t); say_n("  n", n1); }
    R("%p", &p); say_n("  p", (long) p);
    R(" %n%d%n", &n1, &a, &n2); say_n("  n1", n1); say_n("  a", a); say_n("  n2", n2); }
  /* a stream: what the conversions leave unread is the next getc */
  FILE *t = tmpfile(); fputs("12 abc 0x10z rest", t); rewind(t);
  int a = 0, x = 0; char w[16];
  say_n("fscanf", fscanf(t, "%d %s %x", &a, w, &x)); say_n("  a", a); say_s("  w", w); say_n("  x", x);
  say_n("  next", fgetc(t));
  fclose(t);
  return 0; }
