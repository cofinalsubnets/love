// FIXME merge into posix.c?
// inle/sock.c -- every socket nif. three make a socket -- connect, listen, bind, POSIX's
// three verbs -- and each takes its address as data, the family named at its head: tcp,
// udp, icmp, unix (the section below). accept, seal, recv and send work the port one made.
// auto-globbed and LvNif-registered. every nif mirrors main.c's lvm_open: produce an OS
// fd, hand it to host_port -> a heap port carrying a close finalizer. once an fd is a
// port, read and write come free through fgetc/fputc.
// every nif here parks rather than blocking (love.h's nif park: leave Ip unadvanced and
// yield, so the op re-runs) -- accept and recv on their fd, connect on its handshake.
// nothing in this file waits: an address takes a dotted quad, and a name resolves one
// layer up in love, where the lookup itself can park.
// the answers wear posix.c's convention: a port on success, the errno's nom on a failure,
// 'badarg on a call refused before any syscall. hot? is the success test.
#define _GNU_SOURCE     // SOCK_CLOEXEC
#include "love.h"
#include <unistd.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <fcntl.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>

// every socket fd is close-on-exec: no child inherits one, and a server that re-execs
// does not carry its own listener across (SO_REUSEADDR does not permit two live ones).
#define cloexec(fd) do { if ((fd) >= 0) fcntl((fd), F_SETFD, FD_CLOEXEC); } while (0)

// a datagram caps at one ethernet MTU.
#define DgMax 1472

// the fd a syscall helper answered, or its negated errno -> the port pushed, or the
// errno's nom. a refused port allocation closes the fd and hands the not-ok g up, where
// the wrapper ghelps: heap exhaustion is a scare here as everywhere.
ai_noinline static struct ai *host_port(struct ai *g, int fd) {
 if (fd < 0) return ai_push(g, 1, ai_err(g, -fd));
 cloexec(fd);
 g = ai_io_alloc(g, fd);
 if (!ai_ok(g)) close(fd);
 return g; }

// a dotted quad and nothing else -> the address in host order, or -1. all `connect`
// accepts: getaddrinfo has no nonblocking form and can burn fifteen seconds of dead vm,
// so names resolve one layer up in love, where a lookup can park -- apps/dns.l's `dial`.
static int quad(struct ai_str *hv, uint32_t *out) {
 if (hv->len < 7 || hv->len > 15) return -1;      // "0.0.0.0" .. "255.255.255.255"
 uint32_t a = 0;
 char const *p = hv->bytes;                      // NUL-terminated where it lies, so the walk stops
 for (int i = 0; i < 4; i++) {
  uint32_t b = 0, any = 0;
  while (*p >= '0' && *p <= '9') {
   b = b * 10 + (uint32_t) (*p++ - '0'), any = 1;
   if (b > 255) return -1; }
  if (!any) return -1;
  a = (a << 8) | b;
  if (i < 3 && *p++ != '.') return -1; }
 if (*p) return -1;
 return *out = a, 0; }

// the backlog is the accept queue, and a server that twirls a task per client is off
// serving rather than sitting in accept. too small and the kernel drops SYNs into an
// exponential retry that reads as our latency (1s at 25 arrivals, 30s at 100). 512 is
// the measured floor for a flat curve at 400 simultaneous clients.
// a constant and not an operand: `listen` is 1-ary everywhere, and a second operand
// would make every (listen port) a truthy closure, so failures would test as successes.
// test/host/nifpark.l's law 5 knows this number -- it fills the queue to stall a connect,
// the only way to reach the write-direction park offline. move one and move both.
#define ai_listen_backlog 512

// --- the address, as data -------------------------------------------------------
// every nif that makes a socket takes one operand: the address, a list whose head names the
// family and whose rest is what that family needs, options last. the family picks the
// socket(2) triple and the sockaddr, so a new family is a row here and not a nif.
//   connect  (tcp "1.2.3.4" 80)   (unix "/tmp/.X11-unix/X0")
//   listen   (tcp 80)  or a bare port, which is tcp   (unix "/run/x.sock")
//   bind     (udp 53)   (icmp)   (icmp6)   -- options after: (icmp ttl) asks each datagram's
//            ttl, (icmp6 ttl) its hop limit
// icmp is linux's unprivileged echo socket, or where that is refused a raw one (root's, and
// the bsds' only kind) dressed as it: recv and send answer and take the same bytes either
// way. icmp6 is the same pair over ipv6, and the only family that speaks it.
// a host is a dotted quad, or v6 text for an icmp6 peer: names resolve one layer up (apps/dns.l).
enum { FamTcp = 1, FamUdp, FamIcmp, FamIcmp6, FamUnix };
enum { HowConnect = 1, HowListen, HowBind };
struct saddr { int fam, port, ttl; uint32_t ip; struct ai_str *path; };

// is x the symbol spelled s
static int nom_is(word x, char const *s) {
 if (!x || !namep(x)) return 0;
 struct ai_str *n = str(nom(x)->name);
 size_t k = strlen(s);
 return n->len == k && !memcmp(n->bytes, s, k); }

// the next element of a list walk, or 0 past its end
static word nth_take(word *x) {
 if (!chainp(*x)) return 0;
 word v = (word) two(*x)->a;
 *x = (word) two(*x)->b;
 return v; }

static int port_of(word v) {
 intptr_t p = v && oddp(v) ? getcharm(v) : -1;
 return p >= 0 && p <= 65535 ? (int) p : -1; }

// the address operand -> a, or -1 for one this verb cannot take. read afresh on every
// call: a path points into the heap, and a collection between calls moves it
static int parse_addr(word x, int how, struct saddr *a) {
 memset(a, 0, sizeof *a);
 if (how == HowListen && oddp(x)) return a->fam = FamTcp, (a->port = port_of(x)) < 0 ? -1 : 0;
 word f = nth_take(&x), v;
 if (nom_is(f, "unix")) {
  if (how == HowBind || !(v = nth_take(&x)) || !strp(v)) return -1;
  struct sockaddr_un un;
  a->fam = FamUnix, a->path = str(v);
  if (a->path->len == 0 || a->path->len >= sizeof un.sun_path) return -1; }
 else if (nom_is(f, "tcp") || nom_is(f, "udp")) {
  a->fam = nom_is(f, "tcp") ? FamTcp : FamUdp;
  if ((a->fam == FamTcp) != (how != HowBind)) return -1;
  if (how == HowConnect && (!(v = nth_take(&x)) || !strp(v) || quad(str(v), &a->ip) < 0)) return -1;
  if ((a->port = port_of(nth_take(&x))) < 0) return -1; }
 else if (nom_is(f, "icmp") || nom_is(f, "icmp6")) {
  if (how != HowBind) return -1;
  a->fam = nom_is(f, "icmp6") ? FamIcmp6 : FamIcmp; }
 else return -1;
 while ((v = nth_take(&x)))                       // the options
  if (nom_is(v, "ttl") && (a->fam == FamIcmp || a->fam == FamIcmp6)) a->ttl = 1;
  else return -1;
 return 0; }

// the fd for a, or a negated errno: socket(2) by the family's row, then the verb's own
// steps. a connect leaves the socket nonblocking with its handshake in flight
ai_noinline static int call_sock(struct saddr const *a, int how) {
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
 in.sin_addr.s_addr = htonl(how == HowConnect ? a->ip : INADDR_ANY);
 in.sin_port = htons((uint16_t) a->port);
 if (un) ua.sun_family = AF_UNIX, memcpy(ua.sun_path, a->path->bytes, a->path->len);
 struct sockaddr *sa = un ? (struct sockaddr*) &ua : v6 ? (struct sockaddr*) &i6 : (struct sockaddr*) &in;
 socklen_t sl = un ? (socklen_t) sizeof ua : v6 ? (socklen_t) sizeof i6 : (socklen_t) sizeof in;
 int r;
 if (how == HowConnect) {
  int fl = fcntl(fd, F_GETFL);
  if (fl >= 0) fcntl(fd, F_SETFL, fl | O_NONBLOCK);
  do r = connect(fd, sa, sl); while (r < 0 && errno == EINTR);
  // EINPROGRESS and no EALREADY: this is the first connect on a fresh socket
  if (r == 0 || errno == EINPROGRESS) return fd; }
 else {
  int one = 1;
  if (un) unlink(ua.sun_path);                   // a stale socket file from a dead listener
  else setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &one, sizeof one);
  if (a->ttl && v6) setsockopt(fd, IPPROTO_IPV6, IPV6_RECVHOPLIMIT, &one, sizeof one);
  else if (a->ttl && !raw) setsockopt(fd, IPPROTO_IP, IP_RECVTTL, &one, sizeof one);   // linux's number
  r = bind(fd, sa, sl);
  if (!r && how == HowListen) r = listen(fd, ai_listen_backlog);
  if (!r) return fd; }
 int e = errno;
 close(fd);
 return -e; }

struct sock_how { int how; };
static int mk_sock(struct ai *g, void *env) {
 struct saddr a;
 int how = ((struct sock_how*) env)->how;
 return parse_addr(g->sp[0], how, &a) ? -EINVAL : call_sock(&a, how); }

// a listener or a bound socket for the address on top of the stack: pushes the port, or
// the errno's nom, or 'badarg for an address this verb cannot take
ai_noinline static struct ai *host_sock(struct ai *g, int how) {
 struct saddr a;
 if (parse_addr(g->sp[0], how, &a)) return ai_push(g, 1, ai_badarg(g));
 struct sock_how h = { how };
 int fd = mk_sock(g, &h);
 if (!ai_ok(g = ai_fd_retry(g, &fd, mk_sock, &h))) return g;
 return host_port(g, fd); }

// a connect's first half, over the address in place: its fd as a charm for the second ap,
// or the errno's nom. a unix connect to a listener whose queue is full answers EAGAIN at
// once rather than in flight; the address is left where it was, the ap's cue to park
ai_noinline static struct ai *host_conn(struct ai *g) {
 struct sock_how h = { HowConnect };
 int fd = mk_sock(g, &h);
 if (!ai_ok(g = ai_fd_retry(g, &fd, mk_sock, &h))) return g;
 if (fd == -EAGAIN) return g;
 return g->sp[0] = fd < 0 ? ai_err(g, -fd) : putcharm(fd), g; }

// (connect addr) -- a stream to a listener, in two aps because the handshake parks and the
// first is not re-runnable once it has sent a SYN. the port | the errno's nom | 'badarg
static lvm(lvm_connect) {
 struct saddr a;
 if (parse_addr(Sp[0], HowConnect, &a)) ai_musttail return Answer(ai_badarg(g));
 LvmPack(g, host_conn);
 Unpack(g);
 if (chainp(Sp[0])) { g->next_wake_at = ai_clock() + 1; ai_musttail return Ap(lvm_yield_sw, g); }
 ai_musttail return Next(1); }

// the second ap: the handshake, waited on by the scheduler. SO_ERROR reads 0 on a socket
// still trying, so POLLOUT first and the error after is the one order that tells
// "connected" from "refused".
static lvm(lvm_connectw) {
 if (!charmp(Sp[0])) ai_musttail return Next(1);   // the first ap's nom rides through
 int fd = (int) getcharm(Sp[0]);
 if (!ai_ready(fd, ai_wait_out)) {
  g->next_wait_fd = fd;
  g->next_wait_events = ai_wait_out;
  ai_musttail return Ap(lvm_yield_sw, g); }
 int err = 0;
 socklen_t el = sizeof err;
 if (getsockopt(fd, SOL_SOCKET, SO_ERROR, &err, &el) || err) {
  close(fd); ai_musttail return Answer(ai_err(g, err ? err : errno)); }
 LvmCallp(g, 1, host_port, fd) }                // [fd] -> [port]

// (listen addr) -- a stream listener; `accept` takes its clients. (bind addr) -- a datagram
// socket; `recv` and `send` carry its datagrams. each the port | the errno's nom | 'badarg
static lvm(lvm_listen) LvmCallp(g, 1, host_sock, HowListen)
static lvm(lvm_bind) LvmCallp(g, 1, host_sock, HowBind)

// accept(2) without waiting: >=0 the fd, else a negated errno -- -EAGAIN is "nobody there
// yet", the park the wrapper reads by name. the O_NONBLOCK toggle is per call for main.c's
// reason: the flags ride the open file description a forked child shares. errno is read
// before the restore, which is an fcntl and may set its own.
ai_noinline static int call_accept(int lfd) {
 int fl = fcntl(lfd, F_GETFL), off = fl >= 0 && !(fl & O_NONBLOCK);
 if (off) fcntl(lfd, F_SETFL, fl | O_NONBLOCK);
 int fd;
 do fd = accept(lfd, NULL, NULL); while (fd < 0 && errno == EINTR);
 int e = fd < 0 ? (errno == EWOULDBLOCK ? EAGAIN : errno) : 0;
 if (off) fcntl(lfd, F_SETFL, fl);
 return fd >= 0 ? fd : -e; }

static int mk_accept(struct ai *g, void *env) { (void) env; return call_accept((int) ai_port_fd(g->sp[0])); }
ai_noinline static struct ai *host_accept(struct ai *g, int fd) {
 if (!ai_ok(g = ai_fd_retry(g, &fd, mk_accept, NULL))) return g;
 return host_port(g, fd); }

// (accept l) -- take the next client on listener port `l` and wrap its fd as a port. an
// empty backlog parks the task on the listener's fd, so the scheduler folds it into the
// same wait as every other quiet fd; nothing is consumed, so the re-run is exact.
// 'badarg on a non-port, the errno's nom on a real accept() failure.
static lvm(lvm_accept) {
 int lfd = (int) ai_port_fd(Sp[0]);
 if (lfd < 0) ai_musttail return Answer(ai_badarg(g));
 int fd = call_accept(lfd);
 if (fd == -EAGAIN) { g->next_wait_fd = lfd; ai_musttail return Ap(lvm_yield_sw, g); }
 LvmCallp(g, 1, host_accept, fd) }              // [l] -> [conn]

// (shutdown s how) -- half-close a socket port. `how` is the POSIX SHUT_* fixnum: 0 read,
// 1 write, 2 both. the load-bearing case is (shutdown s 1) after a stdin-EOF, so the peer
// sees EOF instead of a hung half-open socket. answers the port; a no-op on misuse.
// shutting the write half lands the write run first, or a door that answers short
// truncates the response. kiosko's shape is `(say c body) (seal c 1) (close c)`.
static lvm(lvm_shutdown) {
 int fd = (int) ai_port_fd(Sp[0]);
 if (fd >= 0 && oddp(Sp[1])) {
  intptr_t how = getcharm(Sp[1]);
  if (how >= 1 && how <= 2) {                 // fd >= 0 already proved it a port
   struct ai_io *io = (struct ai_io*) Sp[0];
   g->io = io;
   Pack(g);
   g = ai_io_wflush(g, io);
   if (!ai_ok(g)) ai_musttail return Ap(_lvm_ghelp, g);
   if (ai_io_wpending(g, (struct ai_io*) g->sp[0])) {   // park; nothing shut yet
    Unpack(g);
    g->next_wake_at = ai_clock() + 1;
    ai_musttail return Ap(lvm_yield_sw, g); }
   Unpack(g); }
  if (how >= 0 && how <= 2) shutdown(fd, (int) how); }
 // stack: [s, how, ...] -> [s, ...]
 Sp[1] = Sp[0];
 ai_musttail return Nextp(1, 1); }


// --- datagrams ----------------------------------------------------------------------
//   (recv p)            -> (peer bytes) | (peer bytes ttl) | a nom | 'badarg   [parks]
//   (send p peer bytes) -> p | a nom | 'badarg
// a peer is ("1.2.3.4" port): the shape recv answers is the shape send takes, so a reply
// goes back to (car d). an icmp socket's port is its echo id, and send does not read it.
// the ttl rides when the socket was bound asking for it, and always off a raw one. a quiet
// socket parks the task on its fd, like accept: "nothing else to do" is the scheduler's
// judgement, not this nif's.

// the dotted quad of a, into q -> its length
static int quad_show(char *q, uint32_t a) {
 int k = 0;
 for (int i = 3; i >= 0; i--) {
  unsigned b = (a >> (8 * i)) & 255;
  if (b >= 100) q[k++] = (char) ('0' + b / 100);
  if (b >= 10) q[k++] = (char) ('0' + b / 10 % 10);
  q[k++] = (char) ('0' + b % 10);
  if (i) q[k++] = '.'; }
 return k; }

// one datagram and who sent it. the sockaddr and the control buffer are &-taken here, so
// the lvm wrapper stays TCO-clean; what it needs back rides in the caller's rbuf
struct rmeta { uint32_t ip; int port, ttl, v6; unsigned char ip6[16]; };
struct rbuf { char b[DgMax + 60]; struct rmeta m; };   // room for a raw socket's ip header
ai_noinline static ssize_t call_recv(int fd, struct rbuf *r) {
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
 r->m.ttl = -1, r->m.v6 = peer.in.sin_family == AF_INET6;
 if (r->m.v6) memcpy(r->m.ip6, &peer.in6.sin6_addr, 16), r->m.port = ntohs(peer.in6.sin6_port);
 else r->m.ip = ntohl(peer.in.sin_addr.s_addr), r->m.port = ntohs(peer.in.sin_port);
 for (struct cmsghdr *c = CMSG_FIRSTHDR(&m); c; c = CMSG_NXTHDR(&m, c))
  if ((c->cmsg_level == IPPROTO_IP && c->cmsg_type == IP_TTL)
      || (c->cmsg_level == IPPROTO_IPV6 && c->cmsg_type == IPV6_HOPLIMIT)) {
   int t;
   memcpy(&t, CMSG_DATA(c), sizeof t);
   r->m.ttl = t; }
 return n; }

// the raw icmp socket standing in for an echo socket: its id is the pid's low bits, where
// linux's kernel picks one, fills it in, and filters to the replies bearing it
static int is_raw(int fd) {
 int t = 0;
 socklen_t n = sizeof t;
 return getsockopt(fd, SOL_SOCKET, SO_TYPE, &t, &n) == 0 && t == SOCK_RAW; }
static unsigned echo_id(void) { return (unsigned) getpid() & 0xffff; }

// the next echo reply to us, its ip header off and that header's ttl kept; the rest of what
// a raw socket hears (our own requests on loopback, other pings' replies, v6's neighbour
// talk) is skipped. a v6 one brings no header, and its hop limit came as a cmsg
ai_noinline static ssize_t call_recv_raw(int fd, struct rbuf *r) {
 for (;;) {
  ssize_t n = call_recv(fd, r);
  if (n < 0) return n;
  unsigned char const *b = (unsigned char const*) r->b;
  if (r->m.v6) {
   if (n < 8 || b[0] != 129 || (unsigned) (b[4] << 8 | b[5]) != echo_id()) continue;
   return n; }
  ssize_t h = (b[0] & 15) * 4;
  if (n < h + 8 || b[h] != 0 || (unsigned) (b[h + 4] << 8 | b[h + 5]) != echo_id()) continue;
  r->m.ttl = b[8];
  memmove(r->b, r->b + h, (size_t) (n - h));
  return n - h; } }

// the datagram's bytes and its peer's address as strings, then the list over them: pushes
// (("quad" port) bytes) or (("quad" port) bytes ttl), v6 text in the quad's place
ai_noinline static struct ai *host_dgram(struct ai *g, char const *b, uintptr_t n, struct rmeta m) {
 char q[INET6_ADDRSTRLEN];
 int k = m.v6 ? (int) strlen(inet_ntop(AF_INET6, m.ip6, q, sizeof q)) : quad_show(q, m.ip);
 if (n) {
  if (!ai_ok(g = str0(g, n))) return g;
  memcpy(txt(g->sp[0]), b, n), len(g->sp[0]) = n; }
 else if (!ai_ok(g = ai_push(g, 1, EmptyString))) return g;
 if (!ai_ok(g = str0(g, (uintptr_t) k))) return g;
 memcpy(txt(g->sp[0]), q, (size_t) k), len(g->sp[0]) = (uintptr_t) k;
 if (!ai_ok(g = ai_have(g, 5 * Width(struct ai_chain)))) return g;
 struct ai_chain *c = bump(g, 5 * Width(struct ai_chain));
 word host = g->sp[0], bytes = g->sp[1];         // read after ai_have, which may move them
 ini_chain(c + 0, m.ttl >= 0 ? putcharm(m.ttl) : ZeroPoint, ZeroPoint);
 ini_chain(c + 1, bytes, m.ttl >= 0 ? word(c + 0) : ZeroPoint);
 ini_chain(c + 2, putcharm(m.port), ZeroPoint);
 ini_chain(c + 3, host, word(c + 2));
 ini_chain(c + 4, word(c + 3), word(c + 1));
 g->sp[1] = word(c + 4), g->sp += 1;
 return g; }

static lvm(lvm_recv) {
 int fd = (int) ai_port_fd(Sp[0]);
 if (fd < 0) ai_musttail return Answer(ai_badarg(g));
 // a stack buffer is safe in an lvm_ only while its address never reaches the tail, and
 // every exit here unwinds the frame first; ai_musttail refuses at compile if one did not.
 struct rbuf r;
 ssize_t n = is_raw(fd) ? call_recv_raw(fd, &r) : call_recv(fd, &r);
 // no datagram yet -> park on the socket; nothing was taken off the wire, so the op re-runs
 if (n == -EAGAIN) { g->next_wait_fd = fd; ai_musttail return Ap(lvm_yield_sw, g); }
 if (n < 0) ai_musttail return Answer(ai_err(g, (int) -n));
 LvmCallp(g, 1, host_dgram, r.b, (uintptr_t) n, r.m) }   // [p] -> [(peer bytes ..)]

// a peer's sockaddr: v6 when its text has a colon, else a dotted quad
struct peer { union { struct sockaddr_in in; struct sockaddr_in6 in6; } a; socklen_t n; int v6; };
ai_noinline static int peer_of(struct ai_str *h, int port, struct peer *pe) {
 char t[INET6_ADDRSTRLEN];
 uint32_t ip;
 memset(pe, 0, sizeof *pe);
 if (port < 0 || h->len >= sizeof t) return -1;
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

ai_noinline static ssize_t call_send(int fd, struct peer const *pe, void const *p, size_t n) {
 ssize_t w;
 do w = sendto(fd, p, n, 0, (struct sockaddr const*) &pe->a, pe->n);
 while (w < 0 && errno == EINTR);
 return w < 0 ? -errno : w; }

// an echo request through a raw socket: our id and the checksum written into a copy, the
// two things linux's echo socket fills in itself -- v6's checksum the kernel writes for
// any raw icmp6 socket. it takes only echo requests, as that does
ai_noinline static ssize_t call_send_raw(int fd, struct peer const *pe, void const *p, size_t n) {
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
 int fd = (int) ai_port_fd(Sp[0]);
 word x = Sp[1], h = nth_take(&x);
 int port = port_of(nth_take(&x));
 struct peer pe;
 if (fd < 0 || !h || !strp(h) || peer_of(str(h), port, &pe) < 0 || !strp(Sp[2]))
  ai_musttail return Answerp(2, ai_badarg(g));
 struct ai_str *s = str(Sp[2]);
 ssize_t w = is_raw(fd) ? call_send_raw(fd, &pe, txt(s), len(s)) : call_send(fd, &pe, txt(s), len(s));
 ai_musttail return Answerp(2, w < 0 ? ai_err(g, (int) -w) : Sp[0]); }   // [p, peer, bytes] -> [p]

static union u const
 nif_connect[]  = {{lvm_connect}, {lvm_connectw}, {lvm_ret0}},
 nif_listen[]   = {{lvm_listen}, {lvm_ret0}},
 nif_bind[]     = {{lvm_bind}, {lvm_ret0}},
 nif_accept[]   = {{lvm_accept}, {lvm_ret0}},
 nif_shutdown[] = {{lvm_cur}, {.x = putcharm(2)}, {lvm_shutdown}, {lvm_ret0}},
 nif_recv[]     = {{lvm_recv}, {lvm_ret0}},
 nif_send[]     = {{lvm_cur}, {.x = putcharm(3)}, {lvm_send}, {lvm_ret0}};
LvNif("connect", nif_connect, NULL);
LvNif("listen", nif_listen, NULL);
LvNif("bind", nif_bind, NULL);
LvNif("accept", nif_accept, NULL);
LvNif("seal", nif_shutdown, NULL);
LvNif("recv", nif_recv, NULL);
LvNif("send", nif_send, NULL);
