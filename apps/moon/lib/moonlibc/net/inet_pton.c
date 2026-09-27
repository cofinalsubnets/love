#include "../impl.h"
#include <arpa/inet.h>

/* text -> network-order bytes: 1, or 0 for text that is not an address. a quad is four
 * decimal octets with no leading zeros; a v6 address is up to eight hex groups of one to
 * four digits, one :: for a run of zero groups, and a quad in its last 32 bits */
static int pton4(char const *s, unsigned char *d) {
  unsigned char q[4];
  int n = 0, digits = 0;
  unsigned v = 0;
  for (;; s++)
    if (*s >= '0' && *s <= '9') {
      if (digits && v == 0) return 0;
      v = v * 10 + (unsigned) (*s - '0'), digits++;
      if (v > 255) return 0; }
    else if ((*s == '.' || !*s) && digits && n < 4) {
      q[n++] = (unsigned char) v, v = 0, digits = 0;
      if (!*s) break; }
    else return 0;
  if (n != 4) return 0;
  memcpy(d, q, 4);
  return 1; }

static int hexv(int c) {
  return c >= '0' && c <= '9' ? c - '0' : c >= 'a' && c <= 'f' ? c - 'a' + 10
       : c >= 'A' && c <= 'F' ? c - 'A' + 10 : -1; }

static int pton6(char const *s, unsigned char *d) {
  unsigned char a[16] = {0};
  int n = 0, gap = -1, digits = 0;             /* n bytes laid; gap where :: stood */
  unsigned v = 0;
  char const *grp = s;
  if (*s == ':' && *++s != ':') return 0;      /* a lone leading colon */
  for (; *s; s++) {
    int h = hexv(*s);
    if (h >= 0) {
      if (++digits > 4) return 0;
      v = v << 4 | (unsigned) h; }
    else if (*s == ':') {
      if (!digits) {                            /* the second colon of :: */
        if (gap >= 0) return 0;
        gap = n, grp = s + 1;
        continue; }
      if (!s[1] || n + 2 > 16) return 0;
      a[n++] = (unsigned char) (v >> 8), a[n++] = (unsigned char) v;
      v = 0, digits = 0, grp = s + 1; }
    else if (*s == '.' && n + 4 <= 16) {        /* the quad ends the address */
      if (!pton4(grp, a + n)) return 0;
      n += 4, digits = 0;
      break; }
    else return 0; }
  if (digits) {
    if (n + 2 > 16) return 0;
    a[n++] = (unsigned char) (v >> 8), a[n++] = (unsigned char) v; }
  if (gap >= 0) {
    if (n == 16) return 0;
    memmove(a + 16 - (n - gap), a + gap, (size_t) (n - gap));
    memset(a + gap, 0, (size_t) (16 - n));
    n = 16; }
  if (n != 16) return 0;
  memcpy(d, a, 16);
  return 1; }

int inet_pton(int af, char const *s, void *d) {
  if (af == AF_INET) return pton4(s, d);
  if (af == AF_INET6) return pton6(s, d);
  errno = EAFNOSUPPORT;
  return -1; }
