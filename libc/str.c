#include <stddef.h>
#include "ll.h"

size_t strlen(char const *c) {
  size_t len = 0;
  while (*c++) len++;
  return len; }

double strtod(char const *restrict s, char **restrict end) {
 char const *p = s;
 int sign = 1;
 if (*p == '-') sign = -1, p++;
 else if (*p == '+') p++;
 int any = 0;
 double v = 0;
 while ('0' <= *p && *p <= '9') v = v * 10 + (*p++ - '0'), any = 1;
 if (*p == '.') {
  p++;
  double scale = 0.1;
  while ('0' <= *p && *p <= '9') v += (*p++ - '0') * scale, scale *= 0.1, any = 1; }
 if (!any) { if (end) *end = (char*) s; return 0; }
 if (*p == 'e' || *p == 'E') {
  char const *q = p++;
  int esign = 1;
  if (*p == '-') esign = -1, p++;
  else if (*p == '+') p++;
  if (!('0' <= *p && *p <= '9')) p = q; // not a real exponent
  else {
   int e = 0;
   while ('0' <= *p && *p <= '9') e = e * 10 + (*p++ - '0');
   double scale = 1;
   while (e--) scale *= 10;
   v = esign > 0 ? v * scale : v / scale; } }
 if (end) *end = (char*) p;
 return sign * v; }

int isspace(int), tolower(int);
void *memchr(void const*, int, size_t);
static char const digits[] = g_digits;

long int strtol(const char *s, char **endptr, int base) {
 char const *p = s;
 int sign = 1;
 while (isspace(*p)) p++;
 if (*p == '-') sign = -1, p++;
 else if (*p == '+') p++;
 if (*p == '0') {
  ++p;
  if ((base == 0 || base == 16) && (*p == 'x' || *p == 'X')) {
   base = 16;
   ++p;
   if (!memchr(digits, tolower(*p), base)) p -= 2; }
  else if (base == 0) base = 8, --p;
  else --p; }
 else if (!base) base = 10;
 if ( base < 2 || base > 36 ) return 0;
 int digit = -1;
 long rc = 0;
 for (const char *x; (x = memchr(digits, tolower(*p), base)); p++)
  digit = x - digits,
  rc = rc * base + digit;
 if (digit == -1) p = NULL, rc = 0;
 if (endptr) *endptr = (char*) (p ? p : s);
 return sign * rc; }
