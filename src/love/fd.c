// fd.c -- ports over os fds, and the readiness and waits the scheduler parks on; the boards'
// twin is fdrow.h. hosted and inle both link it: libc lands in inle/sys.c's arms
#include "love.h"
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <signal.h>
#include <stddef.h>      // offsetof (the struct wait_fd / struct pollfd assert)
#include <stdio.h>
#include <stdnoreturn.h>
#include <time.h>
#include <unistd.h>

// the fd table full: a dropped port holds its fd until collected, so a minor, then a major,
// and ask mk again. mk answers an fd or -errno, and rereads heap operands off g->sp
struct g *love_fd_retry(struct g *g, int *fd, int (*mk)(struct g*, void*), void *env) {
 for (int k = 0; k < 2 && (*fd == -EMFILE || *fd == -ENFILE); k++) {
  if (!ok(g = force(g, k))) return g;
  *fd = mk(g, env); }
 return g; }

// kmain.c's port lanes on a negative osv: busy and end are distinct answers read(2) cannot carry
struct g *k_port_flush(struct g *g);
struct g *k_port_writen(struct g *g, unsigned char const *src, uintptr_t n);
intptr_t k_port_readn(struct g *g, unsigned char *dst, uintptr_t n);
// the rows under them, for an fd spelled in love
intptr_t k_row_read(int fd, unsigned char *dst, uintptr_t n);
intptr_t k_row_write(int fd, unsigned char const *src, uintptr_t n);

// re-raise, not exit: the wait status stays a signal death for the shell
static noreturn void console_hangup(void) {
 signal(SIGPIPE, SIG_DFL);
 raise(SIGPIPE);
 _exit(128 + SIGPIPE); }               // unreached unless someone caught it

static struct g *fd_flush(struct g *g) {
 if (__love_osv < 0) return k_port_flush(g);
 if (g->io == &love_stdout.io && fflush(stdout) && errno == EPIPE) console_hangup();
 return g; }

// every byte, waiting as long as it takes -> how many landed; main.c's stdin pumper borrows it
uintptr_t love_fd_write_all(int fd, unsigned char const *src, uintptr_t n) {
 uintptr_t i = 0;
 while (i < n) {
  ssize_t k = write(fd, src + i, n - i);
  if (k < 0) { if (errno == EINTR) continue; break; }
  i += (uintptr_t) k; }
 return i; }

// the raw-fd lanes: an fd spelled in love is an absolute row (kmain's law). the port protocol,
// not read(2)'s: >0 landed, 0 busy, -1 gone
intptr_t love_fd_readn(struct g *g, int fd, unsigned char *dst, uintptr_t n) {
 if (__love_osv < 0) return k_row_read(fd, dst, n);
 ssize_t k;
 if (fd == STDIN_FILENO && core_of(g)->inflag) k = read(fd, dst, n);   // the bit is already ours
 else {
  int fl = fcntl(fd, F_GETFL), off = fl >= 0 && !(fl & O_NONBLOCK);
  if (off) fcntl(fd, F_SETFL, fl | O_NONBLOCK);
  k = read(fd, dst, n);
  if (off) fcntl(fd, F_SETFL, fl); }
 return k > 0 ? (intptr_t) k
      : k == 0 ? -1
      : (errno == EAGAIN || errno == EWOULDBLOCK) ? 0 : -1; }

intptr_t love_fd_writen(int fd, unsigned char const *src, uintptr_t n) {
 if (__love_osv < 0) return k_row_write(fd, src, n);
 int fl = fcntl(fd, F_GETFL), off = fl >= 0 && !(fl & O_NONBLOCK);
 if (off) fcntl(fd, F_SETFL, fl | O_NONBLOCK);
 ssize_t k;
 do k = write(fd, src, n); while (k < 0 && errno == EINTR);
 if (off) fcntl(fd, F_SETFL, fl);
 return k > 0 ? (intptr_t) k
      : (errno == EAGAIN || errno == EWOULDBLOCK) ? 0 : -1; }

// a raw fd has no write run to park behind, so a busy device is waited on here; a task that
// must not stall writes a port instead
uintptr_t love_fd_say(int fd, unsigned char const *src, uintptr_t n) {
 uintptr_t i = 0;
 while (i < n) {
  intptr_t k = love_fd_writen(fd, src + i, n - i);
  if (k < 0) break;                            // the device is gone: the rest drops
  if (!k) { love_sleep(1); continue; }
  i += (uintptr_t) k; }
 return i; }

// stdout rides stdio, else every print is its own write(2). a static port has nowhere to park
// a residue, so it blocks; a heap port is nonblocking (io_wdrain re-offers). O_NONBLOCK is per
// call on an inherited fd, or the shell gets a nonblocking terminal back
static struct g *fd_writen(struct g *g, unsigned char const *src, uintptr_t n) {
 if (__love_osv < 0) return k_port_writen(g, src, n);
 struct io *io = g->io;
 intptr_t fd = io_fd(io);
 if (io == &love_stdout.io || io == &love_stdin.io || io == &love_stderr.io) {
  uintptr_t k = io == &love_stdout.io ? fwrite(src, 1, n, stdout)
                                 : love_fd_write_all((int) fd, src, n);
  if (k < n && errno == EPIPE) console_hangup();
  return g->b = (intptr_t) k, g; }
 return g->b = love_fd_writen((int) fd, src, n), g; }   // >0 landed, 0 busy, -1 gone

static intptr_t fd_readn(struct g *g, unsigned char *dst, uintptr_t n) {
 if (__love_osv < 0) return k_port_readn(g, dst, n);
 return love_fd_readn(g, (int) io_fd(g->io), dst, n); }

struct port_vt const love_fd_port_vt = { fd_flush, fd_writen, fd_readn, NULL };

struct fio
 love_stdin = { { lvm_port_io, &love_fd_port_vt, putcharm(EOF) }, putcharm(STDIN_FILENO) },
 love_stdout = { { lvm_port_io, &love_fd_port_vt, putcharm(EOF) }, putcharm(STDOUT_FILENO) },
 love_stderr = { { lvm_port_io, &love_fd_port_vt, putcharm(EOF) }, putcharm(STDERR_FILENO) };

// a collected port's unflushed run: raw write(2), no g, safe inside run_finalizers
void love_fd_drain(int fd, void const *p, uintptr_t n) { love_fd_write_all(fd, p, n); }

void k_row_close(int fd);
bool k_ready(int fd, int events);
void k_wait_fds(struct wait_fd *fds, int n, uintptr_t ms);
void k_sleep(uintptr_t ms);

// retries EINTR to the deadline; ms 0 is forever
static void poll_wait(struct pollfd *fds, nfds_t nfds, uintptr_t ms) {
 uintptr_t deadline = ms == 0 ? 0 : love_clock() + ms;
 for (;;) {
  int t = ms == 0 ? -1 :
          ms > (uintptr_t) __INT_MAX__ ? __INT_MAX__ : (int) ms;
  if (poll(fds, nfds, t) >= 0 || errno != EINTR) return;
  if (!deadline) continue;
  uintptr_t now = love_clock();
  if (now >= deadline) return;
  ms = deadline - now; } }

void love_sleep(uintptr_t ms) {
 if (__love_osv < 0) return k_sleep(ms);
 poll_wait(NULL, 0, ms); }

static love_noinline int poll_wrap(int fd, int events) {
 struct pollfd p = { .fd = fd, .events = (short) events };
 return poll(&p, 1, 0); }

bool ready(int fd, int events) {
 if (__love_osv < 0) return k_ready(fd, events);
 return fd < 0 || poll_wrap(fd, events) > 0; }

// love.h lays wait_fd as poll(2)'s own struct: nothing copied, no ceiling on the count
_Static_assert(sizeof(struct wait_fd) == sizeof(struct pollfd)
            && offsetof(struct wait_fd, fd) == offsetof(struct pollfd, fd)
            && offsetof(struct wait_fd, events) == offsetof(struct pollfd, events),
               "struct wait_fd must be this platform's struct pollfd");
_Static_assert(wait_in == POLLIN && wait_out == POLLOUT,
               "wait_in/out must be this platform's POLLIN/POLLOUT");

// events come in per fd, each task's park direction; poll fills revents for the scheduler
void wait_fds(struct wait_fd *fds, int n, uintptr_t ms) {
 if (__love_osv < 0) return k_wait_fds(fds, n, ms);
 if (n <= 0) love_sleep(ms);
 else poll_wait((struct pollfd*) fds, (nfds_t) n, ms); }

// asked, not waited on: one poll for the parked ring. no EINTR retry, it must never block: a
// signal leaves every revents zero, none ready. on inle per row, every slot filled
void ready_fds(struct wait_fd *fds, int n) {
 if (__love_osv < 0) {
  for (int i = 0; i < n; i++)
   fds[i].revents = k_ready(fds[i].fd, fds[i].events) ? fds[i].events : 0;
  return; }
 if (n <= 0) return;
 if (poll((struct pollfd*) fds, (nfds_t) n, 0) >= 0) return;
 for (int i = 0; i < n; i++) fds[i].revents = 0; }

// overrides the weak default; io_alloc's finalizer calls it for an unreachable heap port
void love_fd_close(int fd) {
 if (__love_osv < 0) return k_row_close(fd);
 close(fd); }

// the fd under a port, -1 for anything not an fd port
intptr_t port_fd(word x) {
 if (!charmp(x) && ((union u*) x)->ap == lvm_port_io)
  return io_fd((struct io*) x);
 return -1; }
