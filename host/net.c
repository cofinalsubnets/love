// host/net.c -- the aineko socket nifs. Host-only (links main.c), auto-globbed
// + auto-registered via AI_NIF; no ai.c/ai.h/main.c edit. Every nif mirrors
// main.c's lvm_open: produce an OS fd, hand it to ai_io_alloc (ai.c) -> a heap
// port carrying a close finalizer. Once an fd is a port, READ AND WRITE COME
// FREE through the existing fgetc/fputc machinery (the fgetc read path even
// yields cooperatively on a not-ready fd), so a socket nif only has to make the
// fd. That is the whole netcat core: connect/listen/accept give you the ports,
// the two .l pump loops (tools/aineko.l) shuttle bytes, and shutdown half-closes
// so a stdin-EOF lets the peer see EOF.
//
// Blocking is intentional here: aineko is one-shot, so a blocking getaddrinfo /
// connect / accept is acceptable (the doc's Stage 1). The fgetc/fputc traffic
// that follows is what interleaves cooperatively, not these setup calls.
#include "ai.h"
#include <unistd.h>
#include <stdio.h>
#include <string.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>

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
// connection fd as a port. Blocking is fine for one-shot aineko: there is
// nothing else to do until the first client arrives, and the pump tasks are
// only spawned afterwards. nil on misuse / accept() failure.
static lvm(lvm_accept) {
 if (!portp(Sp[0])) goto fail;
 int lfd = port_fd(Sp[0]);
 if (lfd < 0) goto fail;
 int fd = accept(lfd, NULL, NULL);
 if (fd < 0) goto fail;
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

static union u const
 nif_connect[]  = {{lvm_cur}, {.x = putcharm(2)}, {lvm_connect},  {lvm_ret0}},
 nif_listen[]   = {{lvm_listen}, {lvm_ret0}},
 nif_accept[]   = {{lvm_accept}, {lvm_ret0}},
 nif_shutdown[] = {{lvm_cur}, {.x = putcharm(2)}, {lvm_shutdown}, {lvm_ret0}};
AI_NIF("connect",  nif_connect);
AI_NIF("listen",   nif_listen);
AI_NIF("accept",   nif_accept);
AI_NIF("shutdown", nif_shutdown);
