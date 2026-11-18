#include "../impl.h"
#include <inttypes.h>

static int __digval(int c) {
  if (c >= 48 && c <= 57) return c - 48;
  if (c >= 97 && c <= 122) return c - 87;
  if (c >= 65 && c <= 90) return c - 55;
  return 99; }
/* every strto* integer: the magnitude accumulates unsigned and saturates at the limit,
 * as the standard asks; *neg says a minus led, *over that it saturated */
static unsigned long long __strtom(char const *s, char **endptr, int base, unsigned long long mx,
                                   unsigned long long mxneg, int *neg, int *over) {
  char const *p = s;
  *neg = 0; *over = 0;
  while (*p == 32 || (*p >= 9 && *p <= 13)) p++;
  if (*p == '-') { *neg = 1; p++; }
  else if (*p == '+') p++;
  if (*p == '0') {
    ++p;
    if ((base == 0 || base == 16) && (*p == 'x' || *p == 'X')) {
      base = 16;
      ++p;
      if (__digval(*p) >= base) p -= 2; }
    else if (base == 0) { base = 8; --p; }
    else --p; }
  else if (!base) base = 10;
  if (endptr) *endptr = (char *) s;
  if (base < 2 || base > 36) return 0;
  unsigned long long lim = *neg ? mxneg : mx, b = (unsigned long long) base,
                     cut = lim / b, cutd = lim % b, rc = 0;
  int any = 0;
  for (int d; (d = __digval(*p)) < base; p++) {
    any = 1;
    if (*over || rc > cut || (rc == cut && (unsigned long long) d > cutd)) *over = 1;
    else rc = rc * b + (unsigned long long) d; }
  if (endptr) *endptr = (char *) (any ? p : s);
  if (!any) return 0;
  if (*over) { errno = ERANGE; return lim; }
  return rc; }
/* the minus reaches one further */
static long long __strtoi(char const *s, char **endptr, int base, unsigned long long mx) {
  int neg, over;
  unsigned long long m = __strtom(s, endptr, base, mx, mx + 1, &neg, &over);
  return (long long) (neg ? 0ULL - m : m); }
/* a leading minus negates modulo the width, as the standard asks */
static unsigned long long __strtou(char const *s, char **endptr, int base, unsigned long long mx) {
  int neg, over;
  unsigned long long m = __strtom(s, endptr, base, mx, mx, &neg, &over);
  return over || !neg ? m : (0ULL - m) & mx; }
long strtol(char const *s, char **endptr, int base) { return (long) __strtoi(s, endptr, base, LONG_MAX); }
long long strtoll(char const *s, char **endptr, int base) { return __strtoi(s, endptr, base, LLONG_MAX); }
intmax_t strtoimax(char const *s, char **endptr, int base) { return __strtoi(s, endptr, base, LLONG_MAX); }
unsigned long strtoul(char const *s, char **endptr, int base) { return (unsigned long) __strtou(s, endptr, base, ULONG_MAX); }
unsigned long long strtoull(char const *s, char **endptr, int base) { return __strtou(s, endptr, base, ULLONG_MAX); }
uintmax_t strtoumax(char const *s, char **endptr, int base) { return __strtou(s, endptr, base, ULLONG_MAX); }
