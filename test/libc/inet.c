/* inet_pton and inet_ntop, both families: every text read back out through ntop, so a
 * drift in either names its case. the refusals are the edges of the grammar -- leading
 * zeros in a quad, a fifth hex digit, a second ::, a lone colon at either end, nine
 * groups, :: standing for nothing -- and ntop's are a buffer one byte short. */
#include <arpa/inet.h>
#include <sys/socket.h>
#include <errno.h>
#include "say.h"

static char const *v4[] = {
 "0.0.0.0", "127.0.0.1", "255.255.255.255", "1.2.3.4", "10.0.0.1",
 "01.2.3.4", "256.1.1.1", "1.2.3", "1.2.3.4.5", "1..2.3", ".1.2.3", "1.2.3.", "", "a.b.c.d",
 "1.2.3.4 ", "0x1.2.3.4" };

static char const *v6[] = {
 "::", "::1", "1::", "1::2", "2001:db8::1", "2001:DB8:0:0:0:0:0:1", "fe80::1:2:3:4",
 "1:2:3:4:5:6:7:8", "1:0:0:2:0:0:0:3", "1:0:0:2:0:0:3:4", "0:0:1:0:0:0:0:0", "1:0:2:3:4:5:6:7",
 "0:1:0:1:0:1:0:1", "::ffff:1.2.3.4", "::1.2.3.4", "::0.0.0.2", "::2:3", "::ffff:0:1",
 "1:2:3:4:5:6:1.2.3.4", "::ffff:abcd", "0001:0002::0003", "000f::", "abcd:ef01:2345:6789:abcd:ef01:2345:6789",
 ":", ":::", "1:::2", "1::2::3", ":1::2", "1::2:", "1:2:3:4:5:6:7:8:9", "1:2:3:4:5:6:7::8",
 "::12345", "g::1", "1:2:3:4:5:6:7:1.2.3.4", "::1.2.3", "::01.2.3.4", "1.2.3.4::", "::1.2.3.4:5", "" };

static void one(int af, char const *s) {
 unsigned char b[16];
 char t[64];
 int r = inet_pton(af, s, b);
 s_put(af == AF_INET ? "4 " : "6 "); s_put(s[0] ? s : "(empty)"); s_put(" -> ");
 if (r != 1) { say_n("pton", r); return; }
 char const *o = inet_ntop(af, b, t, sizeof t);
 s_put(o ? o : "(null)"); putchar('\n'); }

int main(void) {
 for (unsigned i = 0; i < sizeof v4 / sizeof *v4; i++) one(AF_INET, v4[i]);
 for (unsigned i = 0; i < sizeof v6 / sizeof *v6; i++) one(AF_INET6, v6[i]);
 /* every single zero group and every run placement, walked by a counter */
 for (unsigned m = 0; m < 256; m++) {
  unsigned char b[16] = {0};
  char t[64];
  for (int k = 0; k < 8; k++) if (m >> k & 1) b[2 * k + 1] = (unsigned char) (k + 1);
  s_put(inet_ntop(AF_INET6, b, t, sizeof t)); putchar('\n'); }
 /* a buffer exactly the text's length has no room for its NUL */
 unsigned char b[16];
 char t[64];
 inet_pton(AF_INET6, "2001:db8::1", b);
 say_n("short", inet_ntop(AF_INET6, b, t, 11) == 0 && errno == ENOSPC);
 say_n("fits", inet_ntop(AF_INET6, b, t, 12) == t);
 inet_pton(AF_INET, "10.0.0.1", b);
 say_n("short4", inet_ntop(AF_INET, b, t, 8) == 0 && errno == ENOSPC);
 say_n("fits4", inet_ntop(AF_INET, b, t, 9) == t);
 errno = 0;
 say_n("badaf", inet_pton(12345, "1.2.3.4", b));
 say_n("badaf-errno", errno == EAFNOSUPPORT);
 /* --- the SOL_SOCKET names: each a distinct option the kernel answers on a fresh stream socket --- */
 int s = socket(AF_INET, SOCK_STREAM, 0), v = 0;
 int names[] = { SO_DEBUG, SO_DONTROUTE, SO_BROADCAST, SO_KEEPALIVE, SO_OOBINLINE, SO_ACCEPTCONN,
                 SO_PROTOCOL, SO_DOMAIN, SO_TYPE, SO_ERROR, SO_REUSEADDR };
 for (unsigned i = 0; i < sizeof names / sizeof *names; i++) {
   socklen_t n = sizeof v; v = -1;
   say_n("getsockopt", getsockopt(s, SOL_SOCKET, names[i], &v, &n)); say_n("  value", v); }
 v = 1; say_n("setsockopt", setsockopt(s, SOL_SOCKET, SO_BROADCAST, &v, sizeof v));
 { socklen_t n = sizeof v; getsockopt(s, SOL_SOCKET, SO_BROADCAST, &v, &n); say_n("broadcast", v); }
 return 0; }
