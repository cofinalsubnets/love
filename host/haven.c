// host/haven.c -- the compositor's plumbing: a unix LISTENING socket (the
// door clients knock on), sendmsg/recvmsg with SCM_RIGHTS (wayland passes
// shared-memory fds as ancillary data), memfd + mmap (the buffers those fds
// name), and the copies between a mapping and a cask. Self-contained host
// nif file: auto-globbed + AI_NIF-registered, no core edit -- the same
// discipline as net.c/pty.c/cb.c.
//
//   (shore path)          -> a listening unix port | () ; unlinks stale first
//                            (accept/await/close ride the core port nifs)
//   (wl-recv port b)      -> (n fd..) one recvmsg into cask b, fds in order;
//                            (0) at eof; () = nothing there / misuse
//   (wl-send port b n fds)-> () | errno ; sendmsg of b's first n bytes with
//                            the fd charms in the list as SCM_RIGHTS
//   (memfd n)             -> fd charm | negative -errno (sealed-size memory)
//   (mapfd fd n)          -> ptr charm | negative -errno (mmap RW shared)
//   (unmap ptr n)         -> ()
//   (mapin  dst doff ptr soff n) -> dst : mapping -> cask (compositing)
//   (mapout ptr doff src soff n) -> () : cask/string -> mapping (a brush)
//   (fdclose fd)          -> () | -errno  (host/init.c owns the nif now)
//
// the mapping pointer is a bare charm: peek/poke-class honesty -- the app
// keeps its sizes straight, the cask side is bounds-clamped.
#define _GNU_SOURCE     // memfd_create, SCM_RIGHTS glue
#include "ai.h"
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/mman.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>

static intptr_t hv_port_fd(ai_word x) {
  if ((x & 1) == 0 && ((union u*) x)->ap == lvm_port_io)
    return getcharm(((struct ai_io*) x)->fd);
  return -1; }

static struct ai_str *hv_bytes(ai_word x) {
  if (x & 1) return 0;
  if (((union u*) x)->ap == lvm_buf) return ((struct ai_buf*) x)->str;
  return ai_strp(x) ? (struct ai_str*) x : 0; }

// (shore path): bind + listen a unix stream socket at path.
// leaves EXACTLY ONE net value above the path on every non-OOM path (the
// port, or the zero point), so lvm_shore collapses uniformly -- pty.c's law.
ai_noinline static struct ai *hv_shore(struct ai *g, ai_word pw) {
  struct ai_str *p = hv_bytes(pw);
  struct sockaddr_un a = {0};
  if (!p || p->len + 1 > sizeof a.sun_path) return ai_push(g, 1, ZeroPoint);
  a.sun_family = AF_UNIX;
  memcpy(a.sun_path, p->bytes, p->len);
  unlink(a.sun_path);
  int fd = socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0);
  if (fd < 0) return ai_push(g, 1, ZeroPoint);
  if (bind(fd, (struct sockaddr*) &a, sizeof a) || listen(fd, 8)) {
    close(fd);
    return ai_push(g, 1, ZeroPoint); }
  struct ai *r = ai_io_alloc(g, fd);
  if (!ai_ok(r)) close(fd);
  return r; }

static lvm(lvm_shore) {
  Pack(g);
  g = hv_shore(g, g->sp[0]);
  if (!ai_ok(g)) return ghelp(g);
  Unpack(g);
  Sp[1] = Sp[0];
  Sp += 1; Ip += 1; return Continue(); }

// (wl-recv port b): one nonblocking recvmsg; the byte count then the fds,
// as a list. () = EAGAIN or misuse; (0) = the peer hung up.
ai_noinline static struct ai *hv_recv(struct ai *g) {
  intptr_t fd = hv_port_fd(g->sp[0]);
  struct ai_str *b = hv_bytes(g->sp[1]);
  if (fd < 0 || !b || !b->len) { g->sp[0] = ZeroPoint; return g; }
  char cbuf[CMSG_SPACE(8 * sizeof(int))];
  struct iovec iov = { b->bytes, b->len };
  struct msghdr mh = {0};
  mh.msg_iov = &iov, mh.msg_iovlen = 1;
  mh.msg_control = cbuf, mh.msg_controllen = sizeof cbuf;
  ssize_t n = recvmsg((int) fd, &mh, MSG_DONTWAIT | MSG_CMSG_CLOEXEC);
  if (n < 0) { g->sp[0] = ZeroPoint; return g; }
  int fds[8], nf = 0;
  // glibc's CMSG_NXTHDR compares size_t with ptrdiff_t inside the macro
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wsign-compare"
  for (struct cmsghdr *c = CMSG_FIRSTHDR(&mh); c; c = CMSG_NXTHDR(&mh, c))
    if (c->cmsg_level == SOL_SOCKET && c->cmsg_type == SCM_RIGHTS
        && (size_t) c->cmsg_len > (size_t) CMSG_LEN(0)) {
      size_t k = ((size_t) c->cmsg_len - (size_t) CMSG_LEN(0)) / sizeof(int);
      for (size_t i = 0; i < k && nf < 8; i++)
        memcpy(&fds[nf++], (char*) CMSG_DATA(c) + i * sizeof(int), sizeof(int)); }
#pragma GCC diagnostic pop
  if (!ai_ok(g = ai_have(g, (uintptr_t) (nf + 1) * Width(struct ai_chain)))) return g;
  ai_word tail = ZeroPoint;
  for (int i = nf; i-- > 0;) {
    struct ai_chain *w = ini_chain((struct ai_chain*) bump(g, Width(struct ai_chain)),
                                   putcharm(fds[i]), tail);
    tail = word(w); }
  struct ai_chain *w = ini_chain((struct ai_chain*) bump(g, Width(struct ai_chain)),
                                 putcharm(n), tail);
  g->sp[0] = word(w);
  return g; }

static lvm(lvm_wlrecv) {
  Pack(g);
  g = hv_recv(g);
  if (!ai_ok(g)) return ghelp(g);
  Unpack(g);
  Sp[1] = Sp[0];
  Sp += 1; Ip += 1; return Continue(); }

// (wl-send port b n fds): sendmsg of the cask's first n bytes, the fd
// charms riding as SCM_RIGHTS. Retries partial writes without the fds
// (they travel with the first byte, per the protocol's custom).
static lvm(lvm_wlsend) {
  intptr_t fd = hv_port_fd(Sp[0]);
  struct ai_str *b = hv_bytes(Sp[1]);
  intptr_t n = (Sp[2] & 1) ? getcharm(Sp[2]) : -1;
  ai_word out = putcharm(-1);
  if (fd >= 0 && b && n >= 0 && (uintptr_t) n <= b->len) {
    int fds[8]; int nf = 0;
    for (ai_word l = Sp[3]; chainp(l) && nf < 8; l = B(l))
      if (A(l) & 1) fds[nf++] = (int) getcharm(A(l));
    char cbuf[CMSG_SPACE(8 * sizeof(int))];
    struct iovec iov = { b->bytes, (size_t) n };
    struct msghdr mh = {0};
    mh.msg_iov = &iov, mh.msg_iovlen = 1;
    if (nf) {
      mh.msg_control = cbuf, mh.msg_controllen = CMSG_SPACE((size_t) nf * sizeof(int));
      struct cmsghdr *c = CMSG_FIRSTHDR(&mh);
      c->cmsg_level = SOL_SOCKET, c->cmsg_type = SCM_RIGHTS;
      c->cmsg_len = CMSG_LEN((size_t) nf * sizeof(int));
      memcpy(CMSG_DATA(c), fds, (size_t) nf * sizeof(int)); }
    out = ZeroPoint;
    uintptr_t i = 0;
    while (i < (uintptr_t) n) {
      ssize_t k = sendmsg((int) fd, &mh, 0);
      if (k < 0) {
        if (errno == EINTR) continue;
        out = putcharm(errno);
        break; }
      i += (uintptr_t) k;
      iov.iov_base = b->bytes + i, iov.iov_len = (size_t) n - i;
      mh.msg_control = 0, mh.msg_controllen = 0; } }
  Sp[3] = out;
  Sp += 3; Ip += 1; return Continue(); }

// (memfd n): anonymous shared memory of n bytes, by fd -- what a client
// builds its pool from.
static lvm(lvm_memfd) {
  intptr_t n = (Sp[0] & 1) ? getcharm(Sp[0]) : -1;
  ai_word out = putcharm(-1);
  if (n > 0) {
    int fd = memfd_create("haven", MFD_CLOEXEC);
    if (fd < 0) out = putcharm(-errno);
    else if (ftruncate(fd, n)) { out = putcharm(-errno); close(fd); }
    else out = putcharm(fd); }
  Sp[0] = out;
  Ip += 1; return Continue(); }

// (mapfd fd n): the fd's memory, mapped shared read/write.
static lvm(lvm_mapfd) {
  intptr_t fd = (Sp[0] & 1) ? getcharm(Sp[0]) : -1,
           n = (Sp[1] & 1) ? getcharm(Sp[1]) : -1;
  ai_word out = putcharm(-1);
  if (fd >= 0 && n > 0) {
    void *p = mmap(0, (size_t) n, PROT_READ | PROT_WRITE, MAP_SHARED, (int) fd, 0);
    out = p == MAP_FAILED ? putcharm(-errno) : putcharm((intptr_t) p); }
  Sp[1] = out;
  Sp += 1; Ip += 1; return Continue(); }

static lvm(lvm_unmap) {
  intptr_t p = (Sp[0] & 1) ? getcharm(Sp[0]) : 0,
           n = (Sp[1] & 1) ? getcharm(Sp[1]) : 0;
  if (p && n > 0) munmap((void*) p, (size_t) n);
  Sp[1] = ZeroPoint;
  Sp += 1; Ip += 1; return Continue(); }

// (mapin dst doff ptr soff n): mapping -> cask, the compositing read.
static lvm(lvm_mapin) {
  struct ai_str *d = hv_bytes(Sp[0]);
  intptr_t doff = (Sp[1] & 1) ? getcharm(Sp[1]) : -1,
           p = (Sp[2] & 1) ? getcharm(Sp[2]) : 0,
           soff = (Sp[3] & 1) ? getcharm(Sp[3]) : -1,
           n = (Sp[4] & 1) ? getcharm(Sp[4]) : -1;
  if (d && !(Sp[0] & 1) && ((union u*) Sp[0])->ap == lvm_buf
      && p && doff >= 0 && soff >= 0 && n > 0
      && (uintptr_t) (doff + n) <= d->len)
    memcpy(d->bytes + doff, (char const*) p + soff, (size_t) n);
  Sp[4] = Sp[0];
  Sp += 4; Ip += 1; return Continue(); }

// (mapout ptr doff src soff n): cask/string -> mapping, the client's brush.
static lvm(lvm_mapout) {
  intptr_t p = (Sp[0] & 1) ? getcharm(Sp[0]) : 0,
           doff = (Sp[1] & 1) ? getcharm(Sp[1]) : -1;
  struct ai_str *s = hv_bytes(Sp[2]);
  intptr_t soff = (Sp[3] & 1) ? getcharm(Sp[3]) : -1,
           n = (Sp[4] & 1) ? getcharm(Sp[4]) : -1;
  if (p && s && doff >= 0 && soff >= 0 && n > 0
      && (uintptr_t) (soff + n) <= s->len)
    memcpy((char*) p + doff, s->bytes + soff, (size_t) n);
  Sp[4] = ZeroPoint;
  Sp += 4; Ip += 1; return Continue(); }

static union u const
  nif_shore[]   = {{lvm_shore}, {lvm_ret0}},
  nif_wlrecv[]  = {{lvm_cur}, {.x = putcharm(2)}, {lvm_wlrecv}, {lvm_ret0}},
  nif_wlsend[]  = {{lvm_cur}, {.x = putcharm(4)}, {lvm_wlsend}, {lvm_ret0}},
  nif_memfd[]   = {{lvm_memfd}, {lvm_ret0}},
  nif_mapfd[]   = {{lvm_cur}, {.x = putcharm(2)}, {lvm_mapfd}, {lvm_ret0}},
  nif_unmap[]   = {{lvm_cur}, {.x = putcharm(2)}, {lvm_unmap}, {lvm_ret0}},
  nif_mapin[]   = {{lvm_cur}, {.x = putcharm(5)}, {lvm_mapin}, {lvm_ret0}},
  nif_mapout[]  = {{lvm_cur}, {.x = putcharm(5)}, {lvm_mapout}, {lvm_ret0}};
AI_NIF("shore", nif_shore);
AI_NIF("wl-recv", nif_wlrecv);
AI_NIF("wl-send", nif_wlsend);
AI_NIF("memfd", nif_memfd);
AI_NIF("mapfd", nif_mapfd);
AI_NIF("unmap", nif_unmap);
AI_NIF("mapin", nif_mapin);
AI_NIF("mapout", nif_mapout);
