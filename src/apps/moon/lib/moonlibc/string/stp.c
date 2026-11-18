#include "../impl.h"

char *stpcpy(char *d, char const *s) {
  while ((*d = *s++)) d++;
  return d; }
/* n bytes always written, nul-padded: the first nul written, or d + n */
char *stpncpy(char *d, char const *s, size_t n) {
  size_t i = 0;
  for (; i < n && s[i]; i++) d[i] = s[i];
  char *e = d + i;
  for (; i < n; i++) d[i] = 0;
  return e; }
void *memrchr(void const *p, int c, size_t n) {
  unsigned char const *b = p;
  while (n--) if (b[n] == (unsigned char) c) return (void *) (b + n);
  return 0; }
/* a store the compiler may not drop: memset reached through a volatile pointer, which no
 * compiler may see through, on every isa (xtensa has no asm) */
void explicit_bzero(void *p, size_t n) {
  static void *(*const volatile set)(void *, int, size_t) = memset;
  set(p, 0, n); }

/* glibc's: digit runs compare as numbers, a run of leading zeros as a fraction. the state is
 * what came before (none, integer, fraction, zeros), the class x, digit or 0 */
enum { VsN = 0, VsI = 3, VsF = 6, VsZ = 9, VsCmp = 2, VsLen = 3 };
static unsigned char const vsnext[] = { VsN, VsI, VsZ,  VsN, VsI, VsI,  VsN, VsF, VsF,  VsN, VsF, VsZ };
static signed char const vsres[] = {
  VsCmp, VsCmp, VsCmp, VsCmp, VsLen, VsCmp, VsCmp, VsCmp, VsCmp,
  VsCmp, -1, -1, 1, VsLen, VsLen, 1, VsLen, VsLen,
  VsCmp, VsCmp, VsCmp, VsCmp, VsCmp, VsCmp, VsCmp, VsCmp, VsCmp,
  VsCmp, 1, 1, -1, VsCmp, VsCmp, -1, VsCmp, VsCmp };
static int vscls(unsigned char c) { return (c == '0') + (c >= '0' && c <= '9'); }
int strverscmp(char const *a, char const *b) {
  unsigned char const *p = (unsigned char const *) a, *q = (unsigned char const *) b;
  if (p == q) return 0;
  unsigned char c = *p++, d = *q++;
  int st = VsN + vscls(c), df;
  while ((df = c - d) == 0) {
    if (!c) return 0;
    st = vsnext[st];
    c = *p++, d = *q++;
    st += vscls(c); }
  st = vsres[st * 3 + vscls(d)];
  if (st == VsCmp) return df;
  if (st == VsLen) {
    while (vscls(*p++)) if (!vscls(*q++)) return 1;
    return vscls(*q) ? -1 : df; }
  return st; }
