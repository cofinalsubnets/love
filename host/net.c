// host/net.c -- the ain socket nifs. Host-only (links main.c), auto-globbed
// + auto-registered via AI_NIF; no ai.c/ai.h/main.c edit. Every nif mirrors
// main.c's lvm_open: produce an OS fd, hand it to ai_io_alloc (ai.c) -> a heap
// port carrying a close finalizer. Once an fd is a port, READ AND WRITE COME
// FREE through the existing fgetc/fputc machinery (the fgetc read path even
// yields cooperatively on a not-ready fd), so a socket nif only has to make the
// fd. That is the whole netcat core: connect/listen/accept give you the ports,
// the two .l pump loops (tools/ain.l) shuttle bytes, and shutdown half-closes
// so a stdin-EOF lets the peer see EOF.
//
// Blocking is intentional here: ain is one-shot, so a blocking getaddrinfo /
// connect / accept is acceptable (the doc's Stage 1). The fgetc/fputc traffic
// that follows is what interleaves cooperatively, not these setup calls.
#include "ai.h"
#include <unistd.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <fcntl.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>

// Every socket fd is CLOSE-ON-EXEC. A run/exec/spawn child must never inherit
// these -- and the dock (port/inle/serve.l) RE-EXECS itself on adopt: without
// CLOEXEC the old listener stays bound across the exec and the fresh dock's
// bind fails (SO_REUSEADDR does not permit two live listeners), so it can't
// re-moor. CLOEXEC releases the port at exec so the new generation binds clean.
#define cloexec(fd) do { if ((fd) >= 0) fcntl((fd), F_SETFD, FD_CLOEXEC); } while (0)

// inle's UDP wire (port/inle/x86_64/net.c) caps a datagram at one ethernet MTU.
#define DG_MAX 1472

// Is Sp-slot x a heap stream port? Same inline check main.c's lvm_close uses:
// an even (heap) word whose first slot is the lvm_port_io discriminator. A
// macro so it reads as one test at each use; lvm_port_io is declared in ai.h.
#define portp(x) (((x) & 1) == 0 && ((union u*) (x))->ap == lvm_port_io)
// the backing OS fd of a known port, as a plain int.
#define port_fd(x) ((int) getcharm(((struct ai_io*) (x))->fd))

// (connect host port) -- TCP client. Resolve `host` (a string: name or dotted
// quad) through getaddrinfo against the decimal `port` (a fixnum 0..65535),
// socket()+connect() the first address that takes, and wrap the fd as a port.
// Any failure (bad args, DNS miss, refused, all addresses tried) -> nil.
ai_noinline static int call_connect(struct ai_str *hv, int port) {
 if (hv->len >= 256 || port < 0 || port > 65535) return -1;
 char host[256], serv[8];
 memcpy(host, hv->bytes, hv->len);
 host[hv->len] = 0;
 snprintf(serv, sizeof serv, "%d", port);
 struct addrinfo hints = {0}, *res, *rp;
 hints.ai_family = AF_UNSPEC;
 hints.ai_socktype = SOCK_STREAM;
 if (getaddrinfo(host, serv, &hints, &res)) return -1;
 int fd = -1;
 for (rp = res; rp; rp = rp->ai_next) {
  fd = socket(rp->ai_family, rp->ai_socktype, rp->ai_protocol);
  if (fd < 0) continue;
  if (connect(fd, rp->ai_addr, rp->ai_addrlen) == 0) break;
  close(fd);
  fd = -1; }
 freeaddrinfo(res);
 cloexec(fd);
 return fd; }

static lvm(lvm_connect) {
 if (!ai_strp(Sp[0]) || !oddp(Sp[1])) goto fail;
 int fd = call_connect((struct ai_str*) Sp[0], (int) getcharm(Sp[1]));
 if (fd < 0) goto fail;
 Pack(g);
 struct ai *r = ai_io_alloc(g, fd);
 if (!ai_ok(r)) { close(fd); goto fail; }
 g = r;
 Unpack(g);
 // stack: [port, host, port#, ...] -> [port, ...]
 Sp[2] = Sp[0];
 Sp += 2; Ip += 1;
 return Continue();
 fail:
 Sp[1] = ai_nil;
 Sp += 1; Ip += 1;
 return Continue(); }

// (listen port) -- TCP server socket: socket()+SO_REUSEADDR+bind(INADDR_ANY,
// port)+listen(). Returns the listening port object, or nil on any failure.
// IPv4 only (enough for a loopback demo); `accept` gives the connection.
ai_noinline static int call_listen(int port) {
 if (port < 0 || port > 65535) return -1;
 int fd = socket(AF_INET, SOCK_STREAM, 0);
 if (fd < 0) return -1;
 int one = 1;
 setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &one, sizeof one);
 struct sockaddr_in a = {0};
 a.sin_family = AF_INET;
 a.sin_addr.s_addr = htonl(INADDR_ANY);
 a.sin_port = htons((uint16_t) port);
 if (bind(fd, (struct sockaddr*) &a, sizeof a) || listen(fd, 1)) {
  close(fd);
  return -1; }
 cloexec(fd);
 return fd; }

static lvm(lvm_listen) {
 if (!oddp(Sp[0])) goto fail;
 int fd = call_listen((int) getcharm(Sp[0]));
 if (fd < 0) goto fail;
 Pack(g);
 struct ai *r = ai_io_alloc(g, fd);
 if (!ai_ok(r)) { close(fd); goto fail; }
 g = r;
 Unpack(g);
 // stack: [port, port#, ...] -> [port, ...]
 Sp[1] = Sp[0];
 Sp += 1; Ip += 1;
 return Continue();
 fail:
 Sp[0] = ai_nil; Ip += 1;
 return Continue(); }

// (accept l) -- block until a client connects to listener port `l`, wrap the
// connection fd as a port. Blocking is fine for one-shot ain: there is
// nothing else to do until the first client arrives, and the pump tasks are
// only spawned afterwards. nil on misuse / accept() failure.
static lvm(lvm_accept) {
 if (!portp(Sp[0])) goto fail;
 int lfd = port_fd(Sp[0]);
 if (lfd < 0) goto fail;
 int fd = accept(lfd, NULL, NULL);
 if (fd < 0) goto fail;
 cloexec(fd);
 Pack(g);
 struct ai *r = ai_io_alloc(g, fd);
 if (!ai_ok(r)) { close(fd); goto fail; }
 g = r;
 Unpack(g);
 // stack: [conn, l, ...] -> [conn, ...]
 Sp[1] = Sp[0];
 Sp += 1; Ip += 1;
 return Continue();
 fail:
 Sp[0] = ai_nil; Ip += 1;
 return Continue(); }

// (shutdown s how) -- half-close a socket port. `how` is the POSIX SHUT_*
// fixnum: 0 = read, 1 = write, 2 = both. The load-bearing case is (shutdown s 1)
// after a stdin-EOF, so the peer sees EOF on its read instead of a hung
// half-open socket. Returns the port (chainable); a no-op on misuse.
static lvm(lvm_shutdown) {
 if (portp(Sp[0]) && oddp(Sp[1])) {
  int fd = port_fd(Sp[0]);
  intptr_t how = getcharm(Sp[1]);
  if (fd >= 0 && how >= 0 && how <= 2) shutdown(fd, (int) how); }
 // stack: [s, how, ...] -> [s, ...]
 Sp[1] = Sp[0];
 Sp += 1; Ip += 1;
 return Continue(); }

// --- UDP (inle's milestone-5 oracle wire) ---------------------------------
// The TCP nifs above can't talk to inle: inle speaks UDP DATAGRAMS, each
// carrying its own sender address to reply to, and a connected byte-stream port
// (the fgetc/fputc free-read path) can't express that. So UDP gets three nifs
// that recvfrom/sendto directly off a bound port's fd and marshal the peer as a
// fixnum -- (host-order ipv4 << 16) | port, 48 bits, comfortably inside a fixnum:
//   (udp-bind port)            -> a port on a bound UDP socket | nil
//   (udp-recv p)               -> (peerfix . datagram-bytes) | nil  [BLOCKS]
//   (udp-send p peerfix bytes) -> p (chainable) | nil
// Blocking recv is intentional, like accept above: the oracle is one-at-a-time,
// so there is nothing else to do until the next datagram arrives.

ai_noinline static int call_udpbind(int port) {
 if (port < 0 || port > 65535) return -1;
 int fd = socket(AF_INET, SOCK_DGRAM, 0);
 if (fd < 0) return -1;
 int one = 1;
 setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &one, sizeof one);
 struct sockaddr_in a = {0};
 a.sin_family = AF_INET;
 a.sin_addr.s_addr = htonl(INADDR_ANY);
 a.sin_port = htons((uint16_t) port);
 if (bind(fd, (struct sockaddr*) &a, sizeof a)) { close(fd); return -1; }
 cloexec(fd);
 return fd; }

static lvm(lvm_udpbind) {
 if (!oddp(Sp[0])) goto fail;
 int fd = call_udpbind((int) getcharm(Sp[0]));
 if (fd < 0) goto fail;
 Pack(g);
 struct ai *r = ai_io_alloc(g, fd);
 if (!ai_ok(r)) { close(fd); goto fail; }
 g = r;
 Unpack(g);
 // stack: [port#, ...] -> [port, ...]
 Sp[1] = Sp[0];
 Sp += 1; Ip += 1;
 return Continue();
 fail:
 Sp[0] = ai_nil; Ip += 1;
 return Continue(); }

static lvm(lvm_udprecv) {
 if (!portp(Sp[0])) goto fail;
 int fd = port_fd(Sp[0]);
 if (fd < 0) goto fail;
 static char buf[DG_MAX];
 struct sockaddr_in peer; memset(&peer, 0, sizeof peer);
 socklen_t plen = sizeof peer;
 ssize_t n;
 do n = recvfrom(fd, buf, sizeof buf, 0, (struct sockaddr*) &peer, &plen);
 while (n < 0 && errno == EINTR);
 if (n < 0) goto fail;
 uintptr_t peerfix = ((uintptr_t) ntohl(peer.sin_addr.s_addr) << 16)
                   | (uintptr_t) ntohs(peer.sin_port);
 Pack(g);                                            // bytes + chain allocate -> Pack
 if (n > 0) {                                        // datagram -> a fresh ai string
  g = str0(g, (uintptr_t) n);
  if (!ai_ok(g)) return ghelp(g);
  memcpy(txt(g->sp[0]), buf, (uintptr_t) n);
  len(g->sp[0]) = (uintptr_t) n;
 } else {                                            // empty datagram -> the singleton
  g = ai_push(g, 1, (uintptr_t) EmptyString);
  if (!ai_ok(g)) return ghelp(g); }
 g = ai_have(g, Width(struct ai_chain));             // (peerfix . bytes)
 if (!ai_ok(g)) return ghelp(g);
 struct ai_chain *w = bump(g, Width(struct ai_chain));
 ini_chain(w, putcharm(peerfix), g->sp[0]);          // read sp[0] AFTER ai_have (may move)
 g->sp[0] = word(w);
 Unpack(g);
 // stack: [port, ...] -> [(peerfix . bytes), ...]
 Sp[1] = Sp[0];
 Sp += 1; Ip += 1;
 return Continue();
 fail:
 Sp[0] = ai_nil; Ip += 1;
 return Continue(); }

static lvm(lvm_udpsend) {
 if (!portp(Sp[0]) || !oddp(Sp[1]) || !ai_strp(Sp[2])) goto fail;
 int fd = port_fd(Sp[0]);
 if (fd < 0) goto fail;
 uintptr_t peerfix = getcharm(Sp[1]);
 struct sockaddr_in a; memset(&a, 0, sizeof a);
 a.sin_family = AF_INET;
 a.sin_addr.s_addr = htonl((uint32_t) (peerfix >> 16));
 a.sin_port = htons((uint16_t) (peerfix & 0xffff));
 struct ai_str *s = str(Sp[2]);
 ssize_t w;
 do w = sendto(fd, txt(s), len(s), 0, (struct sockaddr*) &a, sizeof a);
 while (w < 0 && errno == EINTR);
 if (w < 0) goto fail;
 // stack: [p, peerfix, bytes, ...] -> [p, ...]
 Sp[2] = Sp[0];
 Sp += 2; Ip += 1;
 return Continue();
 fail:
 Sp[2] = ai_nil;
 Sp += 2; Ip += 1;
 return Continue(); }

static union u const
 nif_connect[]  = {{lvm_cur}, {.x = putcharm(2)}, {lvm_connect},  {lvm_ret0}},
 nif_listen[]   = {{lvm_listen}, {lvm_ret0}},
 nif_accept[]   = {{lvm_accept}, {lvm_ret0}},
 nif_shutdown[] = {{lvm_cur}, {.x = putcharm(2)}, {lvm_shutdown}, {lvm_ret0}},
 nif_udpbind[]  = {{lvm_udpbind}, {lvm_ret0}},
 nif_udprecv[]  = {{lvm_udprecv}, {lvm_ret0}},
 nif_udpsend[]  = {{lvm_cur}, {.x = putcharm(3)}, {lvm_udpsend}, {lvm_ret0}};
AI_NIF("connect",  nif_connect);
AI_NIF("listen",   nif_listen);
AI_NIF("accept",   nif_accept);
AI_NIF("seal", nif_shutdown);
AI_NIF("udp-bind", nif_udpbind);
AI_NIF("udp-recv", nif_udprecv);
AI_NIF("udp-send", nif_udpsend);
