// src/sock.c -- every socket nif, both address families: TCP/UDP (ain's netcat core and
// inle's oracle wire), unix-domain connect (lux's X display door) and listen (the shore
// lux moors at). auto-globbed and AiNif-registered. every stream nif mirrors main.c's
// lvm_open: produce an OS fd, hand it to ai_io_alloc -> a heap port carrying a close
// finalizer. once an fd is a port, read and write come free through fgetc/fputc.
// every nif here parks rather than blocking (love.h's nif park: leave Ip unadvanced and
// yield, so the op re-runs) -- accept and udp-recv on their fd, connect on its handshake.
// nothing in this file waits: `connect` takes a dotted quad, and a name resolves one layer
// up in love, where the lookup itself can park.
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
extern intptr_t ai_port_fd(word);   // src/seat.c: the fd under a love port, or -1

// every socket fd is close-on-exec: no child inherits one, and a server that re-execs
// does not carry its own listener across (SO_REUSEADDR does not permit two live ones).
#define cloexec(fd) do { if ((fd) >= 0) fcntl((fd), F_SETFD, FD_CLOEXEC); } while (0)

// a datagram caps at one ethernet MTU.
#define DgMax 1472

// a cask's (or string's) backing bytes, or 0 -- the wl lanes take either.
static struct ai_str *cask_bytes(word x) {
 if (charmp(x)) return 0;
 if (cell(x)->ap == lvm_cask) return cask(x)->str;
 return strp(x) ? str(x) : 0; }

// a dotted quad and nothing else -> the address in host order, or -1. all `connect`
// accepts: getaddrinfo has no nonblocking form and can burn fifteen seconds of dead vm,
// so names resolve one layer up in love, where a lookup can park -- lib/dns.l's `dial`.
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

// (connect quad port) -- TCP client, in two aps because the handshake parks and the op is
// not re-runnable there (a socket is made and a SYN sent). the first ap starts the
// handshake, the second waits for it, and the fd rides the stack between them as a charm.
// the port | 'econnrefused .. | 'badarg (a name string is a misuse; dial resolves above).
// the helper answers the fd, or a negated errno the wrapper names.
ai_noinline static int call_connect(uint32_t a, int port) {
 int fd = socket(AF_INET, SOCK_STREAM, 0);
 if (fd < 0) return -errno;
 cloexec(fd);
 // and it stays nonblocking: the handshake needs it, and a heap port toggles per call
 int fl = fcntl(fd, F_GETFL);
 if (fl >= 0) fcntl(fd, F_SETFL, fl | O_NONBLOCK);
 struct sockaddr_in sa = {0};
 sa.sin_family = AF_INET;
 sa.sin_addr.s_addr = htonl(a);
 sa.sin_port = htons((uint16_t) port);
 int r;
 do r = connect(fd, (struct sockaddr*) &sa, sizeof sa); while (r < 0 && errno == EINTR);
 // EINPROGRESS and no EALREADY: this is the first connect on a fresh socket, so "a
 // previous one is still going" cannot be the answer -- and nolibc has no EALREADY.
 if (r == 0 || errno == EINPROGRESS) return fd;   // in hand, or in flight
 int e = errno;
 close(fd);
 return -e; }

static lvm(lvm_connect) {
 uint32_t a;
 intptr_t port = oddp(Sp[1]) ? getcharm(Sp[1]) : -1;
 if (!strp(Sp[0]) || port < 0 || port > 65535 || quad(str(Sp[0]), &a) < 0)
  Sp[0] = ai_badarg(g);
 else {
  int fd = call_connect(a, (int) port);
  Sp[0] = fd < 0 ? ai_err(g, -fd) : putcharm(fd); }
 ai_musttail return Next(1); }

// the second ap: the handshake, waited on by the scheduler. SO_ERROR reads 0 on a socket
// still trying, so POLLOUT first and the error after is the one order that tells
// "connected" from "refused".
static lvm(lvm_connectw) {
 word e;
 if (!charmp(Sp[0])) { e = Sp[0]; goto fail; }   // the first ap's nom rides through
 int fd = (int) getcharm(Sp[0]);
 if (!ai_ready(fd, ai_wait_out)) {
  g->next_wait_fd = fd;
  g->next_wait_events = ai_wait_out;
  ai_musttail return Ap(lvm_yield_sw, g); }
 int err = 0;
 socklen_t el = sizeof err;
 if (getsockopt(fd, SOL_SOCKET, SO_ERROR, &err, &el) || err) {
  close(fd); e = ai_err(g, err ? err : errno); goto fail; }
 Pack(g);
 g = ai_io_alloc(g, fd);
 if (!ai_ok(g)) { close(fd); g = ai_core_of(g); e = ai_err(g, ENOMEM); goto fail; }   // fail wants g back
 Unpack(g);
 // stack: [port, fd, port#, ...] -> [port, ...]
 Sp[2] = Sp[0];
 ai_musttail return Nextp(1, 2);
 fail:                                    // [fd, port#, ret] -> [nom, ret]
 Sp[1] = e;
 ai_musttail return Nextp(1, 1); }

// (listen port) -- TCP server socket: socket()+SO_REUSEADDR+bind(INADDR_ANY,port)+listen().
// the listening port | 'eacces (a low port) | 'eaddrinuse | 'badarg. IPv4 only; `accept`
// gives the connection.
#define ai_listen_backlog 512
ai_noinline static int call_listen(int port) {
 int fd = socket(AF_INET, SOCK_STREAM, 0);
 if (fd < 0) return -errno;
 int one = 1;
 setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &one, sizeof one);
 struct sockaddr_in a = {0};
 a.sin_family = AF_INET;
 a.sin_addr.s_addr = htonl(INADDR_ANY);
 a.sin_port = htons((uint16_t) port);
 // the backlog is the accept queue, and a server that twirls a task per client is off
 // serving rather than sitting in accept. too small and the kernel drops SYNs into an
 // exponential retry that reads as our latency (1s at 25 arrivals, 30s at 100). 512 is
 // the measured floor for a flat curve at 400 simultaneous clients.
 // a constant and not an operand: `listen` is 1-ary everywhere, and a second operand
 // would make every (listen port) a truthy closure, so failures would test as successes.
 // test/host/nifpark.l's law 5 knows this number -- it fills the queue to stall a connect,
 // the only way to reach the write-direction park offline. move one and move both.
 if (bind(fd, (struct sockaddr*) &a, sizeof a) || listen(fd, ai_listen_backlog)) {
  int e = errno;
  close(fd);
  return -e; }
 cloexec(fd);
 return fd; }

static lvm(lvm_listen) {
 word e;
 intptr_t port = oddp(Sp[0]) ? getcharm(Sp[0]) : -1;
 if (port < 0 || port > 65535) { e = ai_badarg(g); goto fail; }
 int fd = call_listen((int) port);
 if (fd < 0) { e = ai_err(g, -fd); goto fail; }
 Pack(g);
 g = ai_io_alloc(g, fd);
 if (!ai_ok(g)) { close(fd); g = ai_core_of(g); e = ai_err(g, ENOMEM); goto fail; }   // fail wants g back
 Unpack(g);
 // stack: [port, port#, ...] -> [port, ...]
 Sp[1] = Sp[0];
 ai_musttail return Nextp(1, 1);
 fail:
 Sp[0] = e;
 ai_musttail return Next(1); }

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

// (accept l) -- take the next client on listener port `l` and wrap its fd as a port. an
// empty backlog parks the task on the listener's fd, so the scheduler folds it into the
// same wait as every other quiet fd; nothing is consumed, so the re-run is exact.
// 'badarg on a non-port, the errno's nom on a real accept() failure.
static lvm(lvm_accept) {
 word e;
 int lfd = (int) ai_port_fd(Sp[0]);
 if (lfd < 0) { e = ai_badarg(g); goto fail; }
 int fd = call_accept(lfd);
 if (fd == -EAGAIN) { g->next_wait_fd = lfd; ai_musttail return Ap(lvm_yield_sw, g); }
 if (fd < 0) { e = ai_err(g, -fd); goto fail; }
 cloexec(fd);
 Pack(g);
 g = ai_io_alloc(g, fd);
 if (!ai_ok(g)) { close(fd); g = ai_core_of(g); e = ai_err(g, ENOMEM); goto fail; }   // fail wants g back
 Unpack(g);
 // stack: [conn, l, ...] -> [conn, ...]
 Sp[1] = Sp[0];
 ai_musttail return Nextp(1, 1);
 fail:
 Sp[0] = e;
 ai_musttail return Next(1); }

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

// --- UDP (inle's milestone-5 oracle wire) ---------------------------------
// inle speaks UDP datagrams, each carrying its own sender address to reply to, which a
// connected byte-stream port cannot express. so UDP gets three nifs that recvfrom/sendto
// off a bound port's fd and marshal the peer as a fixnum, (ipv4 << 16) | port:
//   (udp-bind port)            -> a port on a bound UDP socket | a nom | 'badarg
//   (udp-recv p)               -> (peerfix . datagram-bytes) | a nom | 'badarg  [parks]
//   (udp-send p peerfix bytes) -> p (chainable) | a nom | 'badarg
// a quiet socket parks the task on its fd, like accept above: "nothing else to do" is the
// scheduler's judgement, not this nif's.

ai_noinline static int call_udpbind(int port) {
 int fd = socket(AF_INET, SOCK_DGRAM, 0);
 if (fd < 0) return -errno;
 int one = 1;
 setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &one, sizeof one);
 struct sockaddr_in a = {0};
 a.sin_family = AF_INET;
 a.sin_addr.s_addr = htonl(INADDR_ANY);
 a.sin_port = htons((uint16_t) port);
 if (bind(fd, (struct sockaddr*) &a, sizeof a)) { int e = errno; close(fd); return -e; }
 cloexec(fd);
 return fd; }

static lvm(lvm_udpbind) {
 word e;
 intptr_t port = oddp(Sp[0]) ? getcharm(Sp[0]) : -1;
 if (port < 0 || port > 65535) { e = ai_badarg(g); goto fail; }
 int fd = call_udpbind((int) port);
 if (fd < 0) { e = ai_err(g, -fd); goto fail; }
 Pack(g);
 g = ai_io_alloc(g, fd);
 if (!ai_ok(g)) { close(fd); g = ai_core_of(g); e = ai_err(g, ENOMEM); goto fail; }   // fail wants g back
 Unpack(g);
 // stack: [port#, ...] -> [port, ...]
 Sp[1] = Sp[0];
 ai_musttail return Nextp(1, 1);
 fail:
 Sp[0] = e;
 ai_musttail return Next(1); }

// recvfrom + peer marshaling; the &-taken sockaddr lives here so the lvm wrapper stays
// TCO-clean. the struct must stay two words: at 24 bytes the ABI returns it through memory,
// which puts an address-taken slot in an lvm_ frame and turns the tail Continue() into a
// ret (make vmret). so the would-block answer rides `n` as a negated errno rather than a
// third field -- >=0 bytes, -EAGAIN the park, any other negative the failure.
struct dgram { ssize_t n; uintptr_t peerfix; };
ai_noinline static struct dgram call_udprecv(int fd, char *buf, size_t cap) {
 struct sockaddr_in peer; memset(&peer, 0, sizeof peer);
 socklen_t plen = sizeof peer;
 ssize_t n;
 do n = recvfrom(fd, buf, cap, MSG_DONTWAIT, (struct sockaddr*) &peer, &plen);
 while (n < 0 && errno == EINTR);
 if (n < 0) n = -(errno == EWOULDBLOCK ? EAGAIN : errno);
 return (struct dgram) { n, ((uintptr_t) ntohl(peer.sin_addr.s_addr) << 16)
                          | (uintptr_t) ntohs(peer.sin_port) }; }

static lvm(lvm_udprecv) {
 word e;
 int fd = (int) ai_port_fd(Sp[0]);
 if (fd < 0) { e = ai_badarg(g); goto fail; }
 // a stack buffer is safe in an lvm_ only while its address never reaches the tail, and
 // every exit here unwinds the frame first; ai_musttail refuses at compile if one did not.
 char buf[DgMax];
 struct dgram d = call_udprecv(fd, buf, sizeof buf);
 // no datagram yet -> park on the socket, exactly as accept does. nothing has been
 // taken off the wire, so the op re-runs whole.
 if (d.n == -EAGAIN) { g->next_wait_fd = fd; ai_musttail return Ap(lvm_yield_sw, g); }
 ssize_t n = d.n;
 if (n < 0) { e = ai_err(g, (int) -n); goto fail; }
 uintptr_t peerfix = d.peerfix;
 Pack(g);                                            // bytes + chain allocate -> Pack
 if (n > 0) {                                        // datagram -> a fresh love string
  g = str0(g, (uintptr_t) n);
  if (!ai_ok(g)) ai_musttail return Ap(_lvm_ghelp, g);
  memcpy(txt(g->sp[0]), buf, (uintptr_t) n);
  len(g->sp[0]) = (uintptr_t) n;
 } else {                                            // empty datagram -> the singleton
  g = ai_push(g, 1, (uintptr_t) EmptyString);
  if (!ai_ok(g)) ai_musttail return Ap(_lvm_ghelp, g); }
 g = ai_have(g, Width(struct ai_chain));             // (peerfix . bytes)
 if (!ai_ok(g)) ai_musttail return Ap(_lvm_ghelp, g);
 struct ai_chain *w = bump(g, Width(struct ai_chain));
 ini_chain(w, putcharm(peerfix), g->sp[0]);          // read sp[0] after ai_have (may move)
 g->sp[0] = word(w);
 Unpack(g);
 // stack: [port, ...] -> [(peerfix . bytes), ...]
 Sp[1] = Sp[0];
 ai_musttail return Nextp(1, 1);
 fail:
 Sp[0] = e;
 ai_musttail return Next(1); }

// sendto with the peer unmarshaled from its fixnum; the &-taken sockaddr
// lives here so the lvm wrapper stays TCO-clean.
ai_noinline static ssize_t call_udpsend(int fd, uintptr_t peerfix, void const *p, size_t n) {
 struct sockaddr_in a; memset(&a, 0, sizeof a);
 a.sin_family = AF_INET;
 a.sin_addr.s_addr = htonl((uint32_t) (peerfix >> 16));
 a.sin_port = htons((uint16_t) (peerfix & 0xffff));
 ssize_t w;
 do w = sendto(fd, p, n, 0, (struct sockaddr*) &a, sizeof a);
 while (w < 0 && errno == EINTR);
 return w < 0 ? -errno : w; }

static lvm(lvm_udpsend) {
 word e;
 if (!oddp(Sp[1]) || !strp(Sp[2])) { e = ai_badarg(g); goto fail; }
 int fd = (int) ai_port_fd(Sp[0]);
 if (fd < 0) { e = ai_badarg(g); goto fail; }
 struct ai_str *s = str(Sp[2]);
 ssize_t w = call_udpsend(fd, getcharm(Sp[1]), txt(s), len(s));
 if (w < 0) { e = ai_err(g, (int) -w); goto fail; }
 // stack: [p, peerfix, bytes, ...] -> [p, ...]
 Sp[2] = Sp[0];
 ai_musttail return Nextp(1, 2);
 fail:
 Sp[2] = e;
 ai_musttail return Nextp(1, 2); }

static union u const
 nif_connect[]  = {{lvm_cur}, {.x = putcharm(2)}, {lvm_connect}, {lvm_connectw}, {lvm_ret0}},
 nif_listen[]   = {{lvm_listen}, {lvm_ret0}},
 nif_accept[]   = {{lvm_accept}, {lvm_ret0}},
 nif_shutdown[] = {{lvm_cur}, {.x = putcharm(2)}, {lvm_shutdown}, {lvm_ret0}},
 nif_udpbind[]  = {{lvm_udpbind}, {lvm_ret0}},
 nif_udprecv[]  = {{lvm_udprecv}, {lvm_ret0}},
 nif_udpsend[]  = {{lvm_cur}, {.x = putcharm(3)}, {lvm_udpsend}, {lvm_ret0}};
AiNif("connect",  nif_connect);
AiNif("listen",   nif_listen);
AiNif("accept",   nif_accept);
AiNif("seal", nif_shutdown);
AiNif("udp-bind", nif_udpbind);
AiNif("udp-recv", nif_udprecv);
AiNif("udp-send", nif_udpsend);
// --- unix-domain connect: lux's X display door ----------------------------------
// (connectu path) -- connect to a unix-domain stream socket and wrap the fd as a port | a
// nom | 'badarg. the load-bearing case is an X display socket (/tmp/.X11-unix/X<n>), which
// real X servers listen on and the TCP nifs cannot open.
ai_noinline static int call_connectu(struct ai_str *pv) {
 struct sockaddr_un a;
 memset(&a, 0, sizeof a);
 a.sun_family = AF_UNIX;
 memcpy(a.sun_path, pv->bytes, pv->len);
 int fd = socket(AF_UNIX, SOCK_STREAM, 0);
 if (fd < 0) return -errno;
 if (connect(fd, (struct sockaddr*) &a, sizeof a)) { int e = errno; close(fd); return -e; }
 cloexec(fd);
 return fd; }

static lvm(lvm_connectu) {
 word e;
 struct ai_str *pv = strp(Sp[0]) ? (struct ai_str*) Sp[0] : 0;
 struct sockaddr_un un;
 if (!pv || pv->len == 0 || pv->len >= sizeof un.sun_path) {
  e = ai_badarg(g); goto fail; }
 int fd = call_connectu(pv);
 if (fd < 0) { e = ai_err(g, -fd); goto fail; }
 Pack(g);
 g = ai_io_alloc(g, fd);
 if (!ai_ok(g)) { close(fd); g = ai_core_of(g); e = ai_err(g, ENOMEM); goto fail; }   // fail wants g back
 Unpack(g);
 // stack: [port, path, ...] -> [port, ...]
 Sp[1] = Sp[0];
 ai_musttail return Nextp(1, 1);
 fail:
 Sp[0] = e;
 ai_musttail return Next(1); }

static union u const nif_connectu[] = {{lvm_connectu}, {lvm_ret0}};
AiNif("connectu", nif_connectu);
// --- the unix listener ----------------------------------------------------------
//   (shore path)          -> a listening unix port | a nom | 'badarg ; unlinks
//                            stale first (accept/await/close ride the core port nifs)

// (shore path): bind + listen a unix stream socket at path. every non-oom path leaves
// exactly one net value above it -- the port or the failure's nom -- so lvm_shore
// collapses uniformly (pty.c's law).
ai_noinline static struct ai *hv_shore(struct ai *g, word pw) {
 struct ai_str *p = cask_bytes(pw);
 struct sockaddr_un a = {0};
 if (!p || p->len + 1 > sizeof a.sun_path) return ai_push(g, 1, ai_badarg(g));
 a.sun_family = AF_UNIX;
 memcpy(a.sun_path, p->bytes, p->len);
 unlink(a.sun_path);
 int fd = socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0);
 if (fd < 0) return ai_push(g, 1, ai_err(g, errno));
 if (bind(fd, (struct sockaddr*) &a, sizeof a) || listen(fd, 8)) {
  int e = errno;
  close(fd);
  return ai_push(g, 1, ai_err(g, e)); }
 g = ai_io_alloc(g, fd);
 if (!ai_ok(g)) close(fd);
 return g; }

// FIXME what is this?
static lvm(lvm_shore) {
 Pack(g);
 g = hv_shore(g, g->sp[0]);
 if (!ai_ok(g)) ai_musttail return Ap(_lvm_ghelp, g);
 Unpack(g);
 Sp[1] = Sp[0];
 ai_musttail return Nextp(1, 1); }

static union u const nif_shore[] = {{lvm_shore}, {lvm_ret0}};
AiNif("shore", nif_shore);
