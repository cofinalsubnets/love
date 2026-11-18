/* sockets: families, addresses, types, flags and options, canonical <-> the BSDs' and macos's */
#include "impl.h"

#ifndef LvOsTranslate
long __love_affb(long a) { return a; }
long __love_afcan(long a) { return a; }
long __love_sotype(long t) { return t; }
long __love_msgfb(long f) { return f; }
long __love_msgcan(long f) { return f; }
int __love_sofb(long *lv, long *op) { return 0; }
unsigned int __love_sain(void const *a, unsigned int n, void *out) { memcpy(out, a, n); return n; }
void __love_saout(void *a, unsigned int n) { }
#else
/* inet6 moves; the BSD sockaddr fronts a length byte where linux's 16-bit family sits */
long __love_affb(long a) { return a == 10 ? (__love_osv == 4 ? 30 : __love_osv == 3 ? 24 : 28) : a; }
long __love_afcan(long a) { return a == (__love_osv == 4 ? 30 : __love_osv == 3 ? 24 : 28) ? 10 : a; }
unsigned int __love_sain(void const *a, unsigned int n, void *out) {
  unsigned char const *s = a;
  unsigned char *b = out;
  memcpy(out, a, n);
  if (n >= 2) {
    long fam = s[0] | s[1] << 8;
    /* a unix name's length follows its path: freebsd refuses past its 106 bytes */
    if (fam == 1 && n > 2) {
      unsigned int k = 2;
      while (k < n && b[k]) k++;
      n = k + (k < n); }
    b[0] = (unsigned char) n;
    b[1] = (unsigned char) __love_affb(fam); }
  return n; }
void __love_saout(void *a, unsigned int n) {
  unsigned char *b = a;
  if (n >= 2) {
    unsigned int fam = (unsigned int) __love_afcan(b[1]);
    b[0] = (unsigned char) (fam & 255);
    b[1] = (unsigned char) (fam >> 8); } }
/* socket type: CLOEXEC and NONBLOCK move high */
long __love_sotype(long t) {
  long o = t & 0xff;
  if (__love_osv == 4) return o;        /* macos has neither: __love_macsofl sets them after */
  if (t & 0x800)   o |= 0x20000000;
  if (t & 0x80000) o |= 0x10000000;
  return o; }
/* send/recv flags: the named bits translate, the rest drop */
long __love_msgfb(long f) {
  long o = f & 3;                       /* OOB 1, PEEK 2 agree */
  if (f & 0x40)   o |= 0x80;            /* MSG_DONTWAIT */
  if (f & 0x100)  o |= 0x40;            /* MSG_WAITALL */
  if (f & 0x4000) o |= __love_osv == 4 ? 0x80000 : __love_osv == 3 ? 0x400 : 0x20000;   /* MSG_NOSIGNAL */
  return o; }
/* recvmsg's msg_flags come back the other way */
long __love_msgcan(long f) {
  long o = f & 1;                       /* MSG_OOB agrees */
  if (f & 0x8)  o |= 0x80;              /* MSG_EOR */
  if (f & 0x10) o |= 0x20;              /* MSG_TRUNC */
  if (f & 0x20) o |= 0x8;               /* MSG_CTRUNC */
  return o; }
/* sockopt: SOL_SOCKET, IP and IPV6 names permute, other levels ride. 0 ok, -1 unmapped,
 * never a different option: linux's IP_TTL is a bsd's IP_HDRINCL */
int __love_sofb(long *lv, long *op) {
  if (*lv == 0) switch (*op) {
    case 2: *op = 4; return 0;          /* IP_TTL */
    case 12: *op = __love_osv == 4 ? 24 : __love_osv == 3 ? 23 : 65; return 0;   /* IP_RECVTTL */
    default: return -1; }
  if (*lv == 41) switch (*op) {
    case 16: *op = 4; return 0;         /* IPV6_UNICAST_HOPS */
    case 26: *op = 27; return 0;        /* IPV6_V6ONLY */
    case 20: *op = 12; return 0;        /* IPV6_JOIN_GROUP */
    case 21: *op = 13; return 0;        /* IPV6_LEAVE_GROUP */
    case 51: *op = 37; return 0;        /* IPV6_RECVHOPLIMIT */
    case 52: *op = 47; return 0;        /* IPV6_HOPLIMIT */
    default: return -1; }
  if (*lv != 1) return 0;
  *lv = 0xffff;
  switch (*op) {
    case 1: *op = 1; return 0;          /* SO_DEBUG */
    case 2: *op = 4; return 0;          /* SO_REUSEADDR */
    case 3: *op = 0x1008; return 0;     /* SO_TYPE */
    case 4: *op = 0x1007; return 0;     /* SO_ERROR */
    case 5: *op = 0x10; return 0;       /* SO_DONTROUTE */
    case 6: *op = 0x20; return 0;       /* SO_BROADCAST */
    case 7: *op = 0x1001; return 0;     /* SO_SNDBUF */
    case 8: *op = 0x1002; return 0;     /* SO_RCVBUF */
    case 9: *op = 8; return 0;          /* SO_KEEPALIVE */
    case 10: *op = 0x100; return 0;     /* SO_OOBINLINE */
    case 13: *op = 0x80; return 0;      /* SO_LINGER */
    case 18: *op = 0x1004; return 0;    /* SO_RCVLOWAT */
    case 19: *op = 0x1003; return 0;    /* SO_SNDLOWAT */
    case 20: *op = __love_osv == 3 ? 0x100c : 0x1006; return 0;   /* SO_RCVTIMEO */
    case 21: *op = __love_osv == 3 ? 0x100b : 0x1005; return 0;   /* SO_SNDTIMEO */
    case 30: *op = 2; return 0;         /* SO_ACCEPTCONN */
    case 38: if (__love_osv != 2) return -1; *op = 0x1016; return 0;   /* SO_PROTOCOL: freebsd's alone */
    case 39: if (__love_osv != 2) return -1; *op = 0x1019; return 0; } /* SO_DOMAIN */
  return -1; }

#ifdef LvMac
/* the socket type's two flag bits, which xnu never took, set on the new fd */
void __love_macsofl(int fd, long t) {
  if (t & 0x80000) fcntl(fd, F_SETFD, FD_CLOEXEC);
  if (t & 0x800) fcntl(fd, F_SETFL, fcntl(fd, F_GETFL, 0) | O_NONBLOCK); }
#endif
#endif
