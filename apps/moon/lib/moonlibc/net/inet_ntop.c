#include "../impl.h"
#include <arpa/inet.h>

/* network-order bytes -> text, or 0 and ENOSPC when it does not fit n. v6 is lowercase
 * with no leading zeros, the longest run of two or more zero groups (the first of a tie)
 * as ::, and a quad for the last 32 bits after 96 zero bits or ::ffff -- glibc's text */
static char *put_dec(char *p, unsigned v) {
  if (v >= 100) *p++ = (char) ('0' + v / 100);
  if (v >= 10) *p++ = (char) ('0' + v / 10 % 10);
  *p++ = (char) ('0' + v % 10);
  return p; }

static char *put_quad(char *p, unsigned char const *b) {
  for (int i = 0; i < 4; i++) {
    if (i) *p++ = '.';
    p = put_dec(p, b[i]); }
  return p; }

static char *put_hex(char *p, unsigned v) {
  int started = 0;
  for (int k = 12; k >= 0; k -= 4) {
    unsigned h = v >> k & 15;
    if (h || started || !k) *p++ = "0123456789abcdef"[h], started = 1; }
  return p; }

static char *ntop6(unsigned char const *b, char *p) {
  unsigned w[8];
  int base = -1, len = 0;
  for (int i = 0; i < 8; i++) w[i] = (unsigned) b[2 * i] << 8 | b[2 * i + 1];
  for (int i = 0, j; i < 8; i = j + 1) {
    for (j = i; j < 8 && !w[j]; j++) ;
    if (j - i >= 2 && j - i > len) base = i, len = j - i; }
  for (int i = 0; i < 8; i++) {
    if (base >= 0 && i >= base && i < base + len) {
      if (i == base) *p++ = ':';
      continue; }
    if (i) *p++ = ':';
    if (i == 6 && base == 0 && (len == 6 || (len == 5 && w[5] == 0xffff)))
      return put_quad(p, b + 12);
    p = put_hex(p, w[i]); }
  if (base >= 0 && base + len == 8) *p++ = ':';
  return p; }

char const *inet_ntop(int af, void const *s, char *d, socklen_t n) {
  char t[INET6_ADDRSTRLEN], *e;
  if (af == AF_INET) e = put_quad(t, s);
  else if (af == AF_INET6) e = ntop6(s, t);
  else return errno = EAFNOSUPPORT, (char const*) 0;
  if ((socklen_t) (e - t) >= n) return errno = ENOSPC, (char const*) 0;
  memcpy(d, t, (size_t) (e - t));
  d[e - t] = 0;
  return d; }
