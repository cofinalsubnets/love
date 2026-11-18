#include "../impl.h"

double lm_strtod(char const *, char **);   /* correctly rounded; reads a bare token, no leading space */
float lm_strtof(char const *, char **);    /* ..and to binary32, rounded once from the digits */
/* inf, infinity, nan(chars) in any case after a sign, as bits so a minus signs nan too; 0 if neither */
static char const *__strtospecial(char const *p, double *v) {
  int neg = *p == '-';
  if (*p == '-' || *p == '+') p++;
  unsigned long long bits;
  if ((p[0] | 32) == 'i' && (p[1] | 32) == 'n' && (p[2] | 32) == 'f') {
    p += 3;
    if ((p[0] | 32) == 'i' && (p[1] | 32) == 'n' && (p[2] | 32) == 'i' && (p[3] | 32) == 't' && (p[4] | 32) == 'y') p += 5;
    bits = 0x7ff0000000000000ULL; }
  else if ((p[0] | 32) == 'n' && (p[1] | 32) == 'a' && (p[2] | 32) == 'n') {
    p += 3;
    if (*p == '(') {
      char const *q = p + 1;
      while ((*q | 32) >= 'a' && (*q | 32) <= 'z' || (*q >= '0' && *q <= '9') || *q == '_') q++;
      if (*q == ')') p = q + 1; }
    bits = 0x7ff8000000000000ULL; }
  else return 0;
  if (neg) bits |= 0x8000000000000000ULL;
  memcpy(v, &bits, sizeof *v);
  return p; }
/* strtod's frame; fo, when given, takes the binary32 reading */
static double __strtodf(char const *s, char **end, float *fo) {
  char const *p = s;
  while (*p == 32 || (*p >= 9 && *p <= 13)) p++;
  double sv; char const *sp = __strtospecial(p, &sv);
  if (sp) { if (end) *end = (char *) sp; if (fo) *fo = (float) sv; return sv; }
  char *e = (char *) p;
  double v = fo ? (*fo = lm_strtof(p, &e)) : lm_strtod(p, &e);
  if (e == p) { if (end) *end = (char *) s; if (fo) *fo = 0; return 0.0; }   /* no conversion: the original s */
  if (end) *end = e;
  return v; }
double strtod(char const *s, char **end) { return __strtodf(s, end, 0); }
float strtof(char const *s, char **end) { float f; __strtodf(s, end, &f); return f; }
long double strtold(char const *s, char **end) { return __strtodf(s, end, 0); }
double atof(char const *s) { return strtod(s, 0); }
