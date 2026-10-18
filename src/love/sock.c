// FIXME merge into posix.c?
// src/love/sock.c -- the socket nifs: connect, listen and bind take an address as data;
// accept, seal, recv, send and farend work the port. each parks, never blocks: Ip
// unadvanced and yield, so the op re-runs. answers a port, the errno's nom, or 'badarg
#define _GNU_SOURCE     // SOCK_CLOEXEC
#include "love.h"
#include <unistd.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <fcntl.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/stat.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>

// a re-exec'd server must not carry its listener across: SO_REUSEADDR allows no two live ones
#define cloexec(fd) do { if ((fd) >= 0) fcntl((fd), F_SETFD, FD_CLOEXEC); } while (0)

#define DgMax 1472   // one ethernet MTU

// fd or a negated errno -> the port or the nom pushed; a refused allocation closes the fd
love_noinline static struct g *host_port(struct g *g, int fd) {
 if (fd < 0) return push(g, 1, love_err(g, -fd));
 cloexec(fd);
 g = io_alloc(g, fd);
 if (!ok(g)) close(fd);
 return g; }

// a dotted quad only: getaddrinfo cannot park, so names resolve in love (src/apps/dns.l's dial)
static int quad(struct str *hv, uint32_t *out) {
 struct in_addr a;                               // bytes are NUL-terminated where they lie
 if ((uintptr_t) hv->len != strlen(hv->bytes) || inet_pton(AF_INET, hv->bytes, &a) != 1) return -1;
 return *out = ntohl(a.s_addr), 0; }

// smaller and dropped SYNs retry as latency under load. not an operand: a 2-ary listen
// would make (listen port) a truthy partial. test/host/nifpark.l's law 5 fills this queue
#define listen_backlog 512

// the address: a list headed by its family, options last; no quad takes every address
//   connect  (tcp "1.2.3.4" 80)   (unix "/tmp/.X11-unix/X0")
//   listen   (tcp 80) or a bare port   (tcp "127.0.0.1" 80)   (unix "/run/x.sock")
//   bind     (udp 53)   (udp "127.0.0.1" 53)   (icmp)   (icmp6)   options: ttl, errs
// icmp is linux's echo socket, or where refused a raw one dressed as it, same bytes either
// way; icmp6 is the one ipv6 family
enum { FamTcp = 1, FamUdp, FamIcmp, FamIcmp6, FamUnix };
enum { HowConnect = 1, HowListen, HowBind };
struct saddr { int fam, port, ttl, errs; uint32_t ip; struct str *path; };

static int nom_is(word x, char const *s) {
 if (!x || !namep(x)) return 0;
 struct str *n = str(nom(x)->name);
 size_t k = strlen(s);
 return n->len == k && !memcmp(n->bytes, s, k); }

static word nth_take(word *x) {
 if (!chainp(*x)) return 0;
 word v = (word) two(*x)->a;
 *x = (word) two(*x)->b;
 return v; }

static int port_of(word v) {
 intptr_t p = v && oddp(v) ? getcharm(v) : -1;
 return p >= 0 && p <= 65535 ? (int) p : -1; }

// -1 for an address this verb cannot take. read afresh per call: a path points into the heap
static int parse_addr(word x, int how, struct saddr *a) {
 memset(a, 0, sizeof *a);
 if (how == HowListen && oddp(x)) return a->fam = FamTcp, (a->port = port_of(x)) < 0 ? -1 : 0;
 word f = nth_take(&x), v;
 if (nom_is(f, "unix")) {
  if (how == HowBind || !(v = nth_take(&x)) || !cstrp(v)) return -1;
  struct sockaddr_un un;
  a->fam = FamUnix, a->path = str(v);
  if (a->path->len == 0 || a->path->len >= sizeof un.sun_path) return -1; }
 else if (nom_is(f, "tcp") || nom_is(f, "udp")) {
  a->fam = nom_is(f, "tcp") ? FamTcp : FamUdp;
  if ((a->fam == FamTcp) != (how != HowBind)) return -1;
  v = nth_take(&x);
  if (v && strp(v)) { if (quad(str(v), &a->ip) < 0) return -1; v = nth_take(&x); }
  else if (how == HowConnect) return -1;
  if ((a->port = port_of(v)) < 0) return -1; }
 else if (nom_is(f, "icmp") || nom_is(f, "icmp6")) {
  if (how != HowBind) return -1;
  a->fam = nom_is(f, "icmp6") ? FamIcmp6 : FamIcmp; }
 else return -1;
 while ((v = nth_take(&x)))                       // the options
  if (nom_is(v, "ttl") && (a->fam == FamIcmp || a->fam == FamIcmp6)) a->ttl = 1;
  else if (nom_is(v, "errs") && (a->fam == FamIcmp || a->fam == FamIcmp6)) a->errs = 1;
  else return -1;
 return 0; }

// the fd or a negated errno; a connect leaves it nonblocking, its handshake in flight
love_noinline static int call_sock(struct saddr const *a, int how) {
 int un = a->fam == FamUnix, v6 = a->fam == FamIcmp6, raw = 0;
 int type = a->fam == FamTcp || un ? SOCK_STREAM : SOCK_DGRAM;
 int dom = un ? AF_UNIX : v6 ? AF_INET6 : AF_INET;
 int proto = v6 ? IPPROTO_ICMPV6 : a->fam == FamIcmp ? IPPROTO_ICMP : 0;
 int fd = socket(dom, type, proto);
 if (fd < 0 && proto) {                          // no echo socket: a raw one, if we may
  int e = errno;
  fd = socket(dom, SOCK_RAW, proto), raw = 1;
  if (fd < 0 && e != EPROTONOSUPPORT) errno = e; }   // linux's refusal names its knob
 if (fd < 0) return -errno;
 cloexec(fd);
 struct sockaddr_in in = {0};
  struct sockaddr_un ua = {0};
 struct sockaddr_in6 i6 = {0};                   // an icmp6 bind is to any address
 i6.sin6_family = AF_INET6;
 in.sin_family = AF_INET;
 in.sin_addr.s_addr = htonl(a->ip);                // 0 is INADDR_ANY
 in.sin_port = htons((uint16_t) a->port);
 if (un) ua.sun_family = AF_UNIX, memcpy(ua.sun_path, a->path->bytes, a->path->len);
 struct sockaddr *sa = un ? (struct sockaddr*) &ua : v6 ? (struct sockaddr*) &i6 : (struct sockaddr*) &in;
 socklen_t sl = un ? (socklen_t) sizeof ua : v6 ? (socklen_t) sizeof i6 : (socklen_t) sizeof in;
 int r;
 if (how == HowConnect) {
  int fl = fcntl(fd, F_GETFL);
  if (fl >= 0) fcntl(fd, F_SETFL, fl | O_NONBLOCK);
  do r = connect(fd, sa, sl); while (r < 0 && errno == EINTR);
  if (r == 0 || errno == EINPROGRESS) return fd; }   // no EALREADY: a fresh socket
 else {
  int one = 1;
  struct stat st;
  if (un) { if (!lstat(ua.sun_path, &st) && S_ISSOCK(st.st_mode)) unlink(ua.sun_path); }  // a dead listener's; anything else stays
  else setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &one, sizeof one);
  if (a->ttl && v6) setsockopt(fd, IPPROTO_IPV6, IPV6_RECVHOPLIMIT, &one, sizeof one);
  else if (a->ttl && !raw) setsockopt(fd, IPPROTO_IP, IP_RECVTTL, &one, sizeof one);   // linux's number
  if (a->errs && !raw)                          // linux's error queue; a raw socket hears them itself
   setsockopt(fd, v6 ? IPPROTO_IPV6 : IPPROTO_IP, v6 ? IPV6_RECVERR : IP_RECVERR, &one, sizeof one);
  r = bind(fd, sa, sl);
  if (!r && how == HowListen) r = listen(fd, listen_backlog);
  if (!r) return fd; }
 int e = errno;
 close(fd);
 return -e; }

struct sock_how { int how; };
static int mk_sock(struct g *g, void *env) {
 struct saddr a;
 int how = ((struct sock_how*) env)->how;
 return parse_addr(g->sp[0], how, &a) ? -EINVAL : call_sock(&a, how); }

love_noinline static struct g *host_sock(struct g *g, int how) {
 struct saddr a;
 if (parse_addr(g->sp[0], how, &a)) return push(g, 1, badarg(g));
 struct sock_how h = { how };
 int fd = mk_sock(g, &h);
 if (!ok(g = love_fd_retry(g, &fd, mk_sock, &h))) return g;
 return host_port(g, fd); }

// a connect's first half: the fd as a charm, or the nom. a unix connect to a full queue
// answers EAGAIN at once, and the address left in place is the cue to park
love_noinline static struct g *host_conn(struct g *g) {
 struct sock_how h = { HowConnect };
 int fd = mk_sock(g, &h);
 if (!ok(g = love_fd_retry(g, &fd, mk_sock, &h))) return g;
 if (fd == -EAGAIN) return g;
 return g->sp[0] = fd < 0 ? love_err(g, -fd) : putcharm(fd), g; }

// (connect addr): two aps, since the first is not re-runnable once it sent a SYN
static lvm(lvm_connect) {
 struct saddr a;
 if (parse_addr(Sp[0], HowConnect, &a)) love_musttail return Answer(badarg(g));
 LvmPack(g, host_conn);
 Unpack(g);
 if (chainp(Sp[0])) { g->next_wake_at = love_clock() + 1; love_musttail return Ap(lvm_yield_sw, g); }
 love_musttail return Next(1); }

// SO_ERROR reads 0 while still trying: POLLOUT first, then the error, tells connected from refused
static lvm(lvm_connectw) {
 if (!charmp(Sp[0])) love_musttail return Next(1);   // the first ap's nom rides through
 int fd = (int) getcharm(Sp[0]);
 if (!ready(fd, wait_out)) {
  g->next_wait_fd = fd;
  g->next_wait_events = wait_out;
  love_musttail return Ap(lvm_yield_sw, g); }
 int err = 0;
 socklen_t el = sizeof err;
 if (getsockopt(fd, SOL_SOCKET, SO_ERROR, &err, &el) || err) {
  close(fd); love_musttail return Answer(love_err(g, err ? err : errno)); }
 LvmCallp(g, 1, host_port, fd) }                // [fd] -> [port]

static lvm(lvm_listen) LvmCallp(g, 1, host_sock, HowListen)
static lvm(lvm_bind) LvmCallp(g, 1, host_sock, HowBind)

// -EAGAIN is the park. O_NONBLOCK per call: the flags ride a description a forked child
// shares. errno is read before the restoring fcntl
love_noinline static int call_accept(int lfd) {
 int fl = fcntl(lfd, F_GETFL), off = fl >= 0 && !(fl & O_NONBLOCK);
 if (off) fcntl(lfd, F_SETFL, fl | O_NONBLOCK);
 int fd;
 do fd = accept(lfd, NULL, NULL); while (fd < 0 && errno == EINTR);
 int e = fd < 0 ? (errno == EWOULDBLOCK ? EAGAIN : errno) : 0;
 if (off) fcntl(lfd, F_SETFL, fl);
 return fd >= 0 ? fd : -e; }

static int mk_accept(struct g *g, void *env) { (void) env; return call_accept((int) port_fd(g->sp[0])); }
love_noinline static struct g *host_accept(struct g *g, int fd) {
 if (!ok(g = love_fd_retry(g, &fd, mk_accept, NULL))) return g;
 return host_port(g, fd); }

// (accept l): an empty backlog parks on l's fd; nothing is consumed, so the re-run is exact
static lvm(lvm_accept) {
 int lfd = (int) port_fd(Sp[0]);
 if (lfd < 0) love_musttail return Answer(badarg(g));
 int fd = call_accept(lfd);
 if (fd == -EAGAIN) { g->next_wait_fd = lfd; love_musttail return Ap(lvm_yield_sw, g); }
 LvmCallp(g, 1, host_accept, fd) }              // [l] -> [conn]

// (seal s how): shutdown(2), how a SHUT_* number; answers s. a write half lands its run first
static lvm(lvm_shutdown) {
 int fd = (int) port_fd(Sp[0]);
 if (fd >= 0 && oddp(Sp[1])) {
  intptr_t how = getcharm(Sp[1]);
  if (how >= 1 && how <= 2) {                 // fd >= 0 proved it a port
   struct io *io = (struct io*) Sp[0];
   g->io = io;
   Pack(g);
   g = io_wflush(g, io);
   if (!ok(g)) love_musttail return Ap(_lvm_ghelp, g);
   if (io_wpending(g, (struct io*) g->sp[0])) {   // park; nothing shut yet
    Unpack(g);
    g->next_wake_at = love_clock() + 1;
    love_musttail return Ap(lvm_yield_sw, g); }
   Unpack(g); }
  if (how >= 0 && how <= 2) shutdown(fd, (int) how); }
 Sp[1] = Sp[0];
 love_musttail return Nextp(1, 1); }

// datagrams
//   (recv p)            -> (peer bytes) | (peer bytes ttl) | a nom | 'badarg   [parks]
//   (send p peer bytes) -> p | a nom | 'badarg
// a peer is ("1.2.3.4" port), the same shape both ways; an icmp port is its echo id, unread
// by send. send's peer may add ttl N (sticky on the socket). bound with errs, a router's
// error about our echo answers (router bytes ttl (type code)), bytes the quoted echo, ttl
// maybe (). the ttl rides when bound asking for it, and always off a raw socket

static int quad_show(char *q, uint32_t a) {
 int k = 0;
 for (int i = 3; i >= 0; i--) {
  unsigned b = (a >> (8 * i)) & 255;
  if (b >= 100) q[k++] = (char) ('0' + b / 100);
  if (b >= 10) q[k++] = (char) ('0' + b / 10 % 10);
  q[k++] = (char) ('0' + b % 10);
  if (i) q[k++] = '.'; }
 return k; }

// (farend s) -> ("quad" port), v6 text in the quad's place
love_noinline static struct g *host_farend(struct g *g, int fd) {
 union { struct sockaddr_in in; struct sockaddr_in6 in6; } a;
 socklen_t n = sizeof a;
 char q[INET6_ADDRSTRLEN];
 memset(&a, 0, sizeof a);
 if (getpeername(fd, (struct sockaddr*) &a, &n)) return push(g, 1, love_err(g, errno));
 int v6 = a.in.sin_family == AF_INET6, port = ntohs(v6 ? a.in6.sin6_port : a.in.sin_port);
 int k = v6 ? (int) strlen(inet_ntop(AF_INET6, &a.in6.sin6_addr, q, sizeof q))
            : quad_show(q, ntohl(a.in.sin_addr.s_addr));
 if (!ok(g = str0(g, (uintptr_t) k))) return g;
 memcpy(txt(g->sp[0]), q, (size_t) k), len(g->sp[0]) = (uintptr_t) k;
 if (!ok(g = have(g, 2 * Width(struct chain)))) return g;
 struct chain *c = bump(g, 2 * Width(struct chain));
 ini_chain(c + 1, putcharm(port), ZeroPoint);
 ini_chain(c + 0, g->sp[0], word(c + 1));
 g->sp[0] = word(c + 0);
 return g; }

// the &-taken buffers live here, so the lvm wrapper stays TCO-clean
struct rmeta { uint32_t ip; int port, ttl, v6, err, etype, ecode; unsigned char ip6[16]; };
struct rbuf { char b[DgMax + 60]; struct rmeta m; };   // room for a raw socket's ip header
love_noinline static ssize_t call_recv(int fd, struct rbuf *r) {
 union { struct sockaddr_in in; struct sockaddr_in6 in6; } peer;
 memset(&peer, 0, sizeof peer);
 struct iovec iov = { r->b, sizeof r->b };
 union { struct cmsghdr h; char c[64]; } cb;
 struct msghdr m;
 memset(&m, 0, sizeof m);
 m.msg_name = &peer, m.msg_namelen = sizeof peer;
 m.msg_iov = &iov, m.msg_iovlen = 1;
 m.msg_control = cb.c, m.msg_controllen = sizeof cb.c;
 ssize_t n;
 do n = recvmsg(fd, &m, MSG_DONTWAIT); while (n < 0 && errno == EINTR);
 if (n < 0) return -(errno == EWOULDBLOCK ? EAGAIN : errno);
 r->m.ttl = -1, r->m.err = 0, r->m.v6 = peer.in.sin_family == AF_INET6;
 if (r->m.v6) memcpy(r->m.ip6, &peer.in6.sin6_addr, 16), r->m.port = ntohs(peer.in6.sin6_port);
 else r->m.ip = ntohl(peer.in.sin_addr.s_addr), r->m.port = ntohs(peer.in.sin_port);
 for (struct cmsghdr *c = CMSG_FIRSTHDR(&m); c; c = CMSG_NXTHDR(&m, c))
  if ((c->cmsg_level == IPPROTO_IP && c->cmsg_type == IP_TTL)
      || (c->cmsg_level == IPPROTO_IPV6 && c->cmsg_type == IPV6_HOPLIMIT)) {
   int t;
   memcpy(&t, CMSG_DATA(c), sizeof t);
   r->m.ttl = t; }
 return n; }

// linux's sock_extended_err, the error queue's cmsg; the offender's sockaddr follows it
struct eerr { uint32_t errnum; uint8_t origin, type, code, pad; uint32_t info, data; };

// 1 for v4's error queue, 2 for v6's, 0 for none (IPPROTO_IP is 0) or on the bsds
static int errq_of(int fd) {
 union { struct sockaddr_in in; struct sockaddr_in6 in6; } a;
 socklen_t n = sizeof a;
 int on = 0;
 socklen_t k = sizeof on;
 if (getsockname(fd, (struct sockaddr*) &a, &n)) return 0;
 int v6 = a.in.sin_family == AF_INET6, lv = v6 ? IPPROTO_IPV6 : IPPROTO_IP;
 return getsockopt(fd, lv, v6 ? IPV6_RECVERR : IP_RECVERR, &on, &k) == 0 && on ? 1 + v6 : 0; }

// the router in the peer's place
love_noinline static ssize_t call_recv_err(int fd, struct rbuf *r, int q) {
 int lv = q == 2 ? IPPROTO_IPV6 : IPPROTO_IP;
 union { struct sockaddr_in in; struct sockaddr_in6 in6; } peer;
 struct iovec iov = { r->b, sizeof r->b };
 union { struct cmsghdr h; char c[256]; } cb;
 struct msghdr m;
 for (;;) {
  memset(&m, 0, sizeof m);
  m.msg_name = &peer, m.msg_namelen = sizeof peer;
  m.msg_iov = &iov, m.msg_iovlen = 1;
  m.msg_control = cb.c, m.msg_controllen = sizeof cb.c;
  ssize_t n;
  do n = recvmsg(fd, &m, MSG_ERRQUEUE | MSG_DONTWAIT); while (n < 0 && errno == EINTR);
  if (n < 0) return -(errno == EWOULDBLOCK ? EAGAIN : errno);
  for (struct cmsghdr *c = CMSG_FIRSTHDR(&m); c; c = CMSG_NXTHDR(&m, c)) {
   if (c->cmsg_level != lv || c->cmsg_type != (lv == IPPROTO_IP ? IP_RECVERR : IPV6_RECVERR)) continue;
   struct eerr e;
   memcpy(&e, CMSG_DATA(c), sizeof e);
   if (e.origin != 2 && e.origin != 3) continue;   // icmp's, icmp6's: not a local error
   union { struct sockaddr_in in; struct sockaddr_in6 in6; } o;
   memcpy(&o, CMSG_DATA(c) + sizeof e, sizeof o);
   r->m.ttl = -1, r->m.err = 1, r->m.etype = e.type, r->m.ecode = e.code, r->m.port = 0;
   r->m.v6 = lv == IPPROTO_IPV6;
   if (r->m.v6) memcpy(r->m.ip6, &o.in6.sin6_addr, 16);
   else r->m.ip = ntohl(o.in.sin_addr.s_addr);
   return n; } } }

// the error queue first: a pending error fails an ordinary read once, so read again
love_noinline static ssize_t call_recv_q(int fd, struct rbuf *r) {
 int q = errq_of(fd);
 for (int tries = 0; ; tries++) {
  if (q) { ssize_t e = call_recv_err(fd, r, q); if (e != -EAGAIN) return e; }
  ssize_t n = call_recv(fd, r);
  if (n >= 0 || n == -EAGAIN || !q || tries) return n; } }

// a raw icmp socket's echo id is the pid's low bits; an echo socket's kernel picks and filters its own
static int is_raw(int fd) {
 int t = 0;
 socklen_t n = sizeof t;
 return getsockopt(fd, SOL_SOCKET, SO_TYPE, &t, &n) == 0 && t == SOCK_RAW; }
static unsigned echo_id(void) { return (unsigned) getpid() & 0xffff; }

// our next echo reply (header off, its ttl kept), or a router's error quoting our echo; all
// else a raw socket hears is skipped. v6 brings no header, its hop limit as a cmsg
static int ours(unsigned char const *b, unsigned type) {
 return b[0] == type && (unsigned) (b[4] << 8 | b[5]) == echo_id(); }
love_noinline static ssize_t call_recv_raw(int fd, struct rbuf *r) {
 for (;;) {
  ssize_t n = call_recv(fd, r);
  if (n < 0) return n;
  unsigned char const *b = (unsigned char const*) r->b;
  ssize_t h = r->m.v6 ? 0 : (b[0] & 15) * 4, q = -1;
  if (n < h + 8) continue;
  if (!r->m.v6) r->m.ttl = b[8];
  if (ours(b + h, r->m.v6 ? 129 : 0)) q = h;      // an echo reply
  else if (r->m.v6 ? b[0] == 1 || b[0] == 3 : b[h] == 3 || b[h] == 11) {
   ssize_t o = h + 8, e = r->m.v6 ? o + 40 : o + (b[o] & 15) * 4;   // the quoted header, then its icmp
   if (e + 8 <= n && (r->m.v6 ? b[o + 6] == 58 : b[o + 9] == 1) && ours(b + e, r->m.v6 ? 128 : 8))
    q = e, r->m.err = 1, r->m.etype = b[h], r->m.ecode = b[h + 1]; }
  if (q < 0) continue;
  memmove(r->b, r->b + q, (size_t) (n - q));
  return n - q; } }

// pushes the recv shapes above; an error's peer port is 0
love_noinline static struct g *host_dgram(struct g *g, char const *b, uintptr_t n, struct rmeta const *m) {
 char q[INET6_ADDRSTRLEN];
 int k = m->v6 ? (int) strlen(inet_ntop(AF_INET6, m->ip6, q, sizeof q)) : quad_show(q, m->ip);
 if (n) {
  if (!ok(g = str0(g, n))) return g;
  memcpy(txt(g->sp[0]), b, n), len(g->sp[0]) = n; }
 else if (!ok(g = push(g, 1, EmptyString))) return g;
 if (!ok(g = str0(g, (uintptr_t) k))) return g;
 memcpy(txt(g->sp[0]), q, (size_t) k), len(g->sp[0]) = (uintptr_t) k;
 if (!ok(g = have(g, 8 * Width(struct chain)))) return g;
 struct chain *c = bump(g, 8 * Width(struct chain));
 word host = g->sp[0], bytes = g->sp[1];         // after have, which may move them
 word tail = ZeroPoint;
 if (m->err) {
  ini_chain(c + 5, putcharm(m->ecode), ZeroPoint);
  ini_chain(c + 6, putcharm(m->etype), word(c + 5));
  ini_chain(c + 7, word(c + 6), ZeroPoint);
  ini_chain(c + 0, m->ttl >= 0 ? putcharm(m->ttl) : ZeroPoint, word(c + 7));
  tail = word(c + 0); }
 else if (m->ttl >= 0) ini_chain(c + 0, putcharm(m->ttl), ZeroPoint), tail = word(c + 0);
 ini_chain(c + 1, bytes, tail);
 ini_chain(c + 2, putcharm(m->port), ZeroPoint);
 ini_chain(c + 3, host, word(c + 2));
 ini_chain(c + 4, word(c + 3), word(c + 1));
 g->sp[1] = word(c + 4), g->sp += 1;
 return g; }

static lvm(lvm_recv) {
 int fd = (int) port_fd(Sp[0]);
 if (fd < 0) love_musttail return Answer(badarg(g));
 struct rbuf r;                                // safe while its address never reaches a tail call
 ssize_t n = is_raw(fd) ? call_recv_raw(fd, &r) : call_recv_q(fd, &r);
 if (n == -EAGAIN) { g->next_wait_fd = fd; love_musttail return Ap(lvm_yield_sw, g); }
 if (n < 0) love_musttail return Answer(love_err(g, (int) -n));
 LvmCallp(g, 1, host_dgram, r.b, (uintptr_t) n, &r.m) }   // [p] -> [(peer bytes ..)]

// a peer's sockaddr: v6 when its text has a colon, else a dotted quad
struct peer { union { struct sockaddr_in in; struct sockaddr_in6 in6; } a; socklen_t n; int v6, ttl; };
love_noinline static int peer_of(struct str *h, int port, struct peer *pe) {
 char t[INET6_ADDRSTRLEN];
 uint32_t ip;
 memset(pe, 0, sizeof *pe);
 if (port < 0 || h->len >= sizeof t || memchr(h->bytes, 0, h->len)) return -1;
 memcpy(t, h->bytes, h->len), t[h->len] = 0;
 if ((pe->v6 = memchr(t, ':', h->len) != 0)) {
  pe->a.in6.sin6_family = AF_INET6, pe->a.in6.sin6_port = htons((uint16_t) port);
  pe->n = (socklen_t) sizeof pe->a.in6;
  return inet_pton(AF_INET6, t, &pe->a.in6.sin6_addr) == 1 ? 0 : -1; }
 if (quad(h, &ip) < 0) return -1;
 pe->a.in.sin_family = AF_INET, pe->a.in.sin_port = htons((uint16_t) port);
 pe->a.in.sin_addr.s_addr = htonl(ip);
 pe->n = (socklen_t) sizeof pe->a.in;
 return 0; }

love_noinline static ssize_t call_send(int fd, struct peer const *pe, void const *p, size_t n) {
 ssize_t w;
 if (pe->ttl > 0 && setsockopt(fd, pe->v6 ? IPPROTO_IPV6 : IPPROTO_IP, pe->v6 ? IPV6_UNICAST_HOPS : IP_TTL,
                               &pe->ttl, sizeof pe->ttl)) return -errno;
 do w = sendto(fd, p, n, 0, (struct sockaddr const*) &pe->a, pe->n);
 while (w < 0 && errno == EINTR);
 return w < 0 ? -errno : w; }

// a raw echo request: our id and the v4 checksum into a copy, as an echo socket would fill
// in; the kernel sums any raw icmp6. echo requests only
love_noinline static ssize_t call_send_raw(int fd, struct peer const *pe, void const *p, size_t n) {
 unsigned char b[DgMax];
 if (n < 8 || n > sizeof b || *(unsigned char const*) p != (pe->v6 ? 128 : 8)) return -EINVAL;
 memcpy(b, p, n);
 unsigned id = echo_id();
 uint32_t s = 0;
 b[2] = b[3] = 0, b[4] = (unsigned char) (id >> 8), b[5] = (unsigned char) id;
 if (!pe->v6) {
  for (size_t i = 0; i < n; i += 2) s += (uint32_t) b[i] << 8 | (i + 1 < n ? b[i + 1] : 0);
  while (s >> 16) s = (s & 0xffff) + (s >> 16);
  s = ~s & 0xffff;
  b[2] = (unsigned char) (s >> 8), b[3] = (unsigned char) s; }
 return call_send(fd, pe, b, n); }

static lvm(lvm_send) {
 int fd = (int) port_fd(Sp[0]);
 word x = Sp[1], h = nth_take(&x);
 int port = port_of(nth_take(&x));
 struct peer pe;
 word o = nth_take(&x), t = nth_take(&x);       // ttl N, the one option
 intptr_t ttl = o && nom_is(o, "ttl") && t && oddp(t) ? getcharm(t) : o ? -1 : 0;
 if (fd < 0 || !h || !strp(h) || peer_of(str(h), port, &pe) < 0 || !strp(Sp[2]) || ttl < 0 || ttl > 255 || nth_take(&x))
  love_musttail return Answerp(2, badarg(g));
 pe.ttl = (int) ttl;
 struct str *s = str(Sp[2]);
 ssize_t w = is_raw(fd) ? call_send_raw(fd, &pe, txt(s), len(s)) : call_send(fd, &pe, txt(s), len(s));
 love_musttail return Answerp(2, w < 0 ? love_err(g, (int) -w) : Sp[0]); }   // [p, peer, bytes] -> [p]

static lvm(lvm_farend) {
 int fd = (int) port_fd(Sp[0]);
 if (fd < 0) love_musttail return Answer(badarg(g));
 LvmCallp(g, 1, host_farend, fd) }                // [s] -> [peer]

static union u const
  nif_connect[]  = {{lvm_connect}, {lvm_connectw}, {lvm_ret0}};
LvNif("connect", nif_connect, NULL);
LvDef("listen", listen, 1, NULL);
LvDef("bind", bind, 1, NULL);
LvDef("accept", accept, 1, NULL);
LvDef("seal", shutdown, 2, NULL);
LvDef("recv", recv, 1, NULL);
LvDef("send", send, 3, NULL);
LvDef("farend", farend, 1, NULL);
