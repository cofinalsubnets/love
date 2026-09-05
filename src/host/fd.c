// src/host/fd.c -- love's ports over OS file descriptors: ai_fd_port_vt and the ai_fd_* family
// beneath it, plus the readiness and wait primitives the scheduler parks on. the bare-board
// counterpart is src/port/fdrow.h, which this file is poll.h and signal.h deeper than.
// src/host/main.c's binary and the inle kernel both link it, so what lives here exists once
// rather than twice. the bodies bottom out in libc calls, and on inle those land in
// src/inle/sys.c's arms (__ai_call's negative-osv door), so most need no branch of their own.
#include "love.h"
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <signal.h>
#include <stddef.h>      // offsetof (the struct ai_wait_fd / struct pollfd assert)
#include <stdio.h>
#include <stdnoreturn.h>
#include <time.h>
#include <unistd.h>

// __ai_osv, "which kernel this binary stands on", rides love.h: os.c defines
// it hosted, love.c carries the weak zero for links with no nolibc at all.

// the kernel's port lanes (src/inle/kmain.c), reached on a negative osv: a protocol read(2)
// cannot carry, busy and end being distinct answers, so the vt branches here rather than
// riding the syscall door. these bodies both declare the doors and stand in for them where
// no kmain.c is linked -- love0 and the HCC build, neither of which can take the branch.
__attribute__((weak)) struct ai *k_port_flush(struct ai *g) { return g; }
__attribute__((weak)) struct ai *k_port_writen(struct ai *g, unsigned char const *src, uintptr_t n) { return g->b = -1, g; }
__attribute__((weak)) intptr_t k_port_readn(struct ai *g, unsigned char *dst, uintptr_t n) { return -1; }
// and the rows under them, which an fd spelled in love reaches without the seat.
__attribute__((weak)) intptr_t k_row_read(int fd, unsigned char *dst, uintptr_t n) { return -1; }
__attribute__((weak)) intptr_t k_row_write(int fd, unsigned char const *src, uintptr_t n) { return -1; }

// re-raise rather than exit: the wait status stays a signal death, so the shell's
// reporting and every `$?` downstream read as they always did. a heap port reports.
static noreturn void console_hangup(void) {
 signal(SIGPIPE, SIG_DFL);
 raise(SIGPIPE);
 _exit(128 + SIGPIPE); }               // unreached unless someone caught it

static struct ai *fd_flush(struct ai *g) {
 if (__ai_osv < 0) return k_port_flush(g);
 if (g->io == &ai_stdout.io && fflush(stdout) && errno == EPIPE) console_hangup();
 return g; }

// land every byte, waiting on the device as long as it takes. answers how many
// got there, so a caller can tell a full write from a dead fd. (main.c's stdin
// pumper borrows it, hence the export.)
uintptr_t ai_fd_write_all(int fd, unsigned char const *src, uintptr_t n) {
 uintptr_t i = 0;
 while (i < n) {
  ssize_t k = write(fd, src + i, n - i);
  if (k < 0) { if (errno == EINTR) continue; break; }
  i += (uintptr_t) k; }
 return i; }

// --- the raw-fd lanes: love's io ops take a charm as well as a port --------
// an fd spelled in love is an absolute row (kmain's seat law), so no seat translation.
// >0 landed, 0 busy, -1 gone is the PORT protocol, not read(2)'s: on inle busy and end
// are one answer at the door, so a reader would take an idle pipe for its end.
intptr_t ai_fd_readn(struct ai *g, int fd, unsigned char *dst, uintptr_t n) {
 if (__ai_osv < 0) return k_row_read(fd, dst, n);
 ssize_t k;
 if (fd == STDIN_FILENO && ai_core_of(g)->inflag) k = read(fd, dst, n);   // the bit is already ours
 else {
  int fl = fcntl(fd, F_GETFL), off = fl >= 0 && !(fl & O_NONBLOCK);
  if (off) fcntl(fd, F_SETFL, fl | O_NONBLOCK);
  k = read(fd, dst, n);
  if (off) fcntl(fd, F_SETFL, fl); }
 return k > 0 ? (intptr_t) k
      : k == 0 ? -1
      : (errno == EAGAIN || errno == EWOULDBLOCK) ? 0 : -1; }

intptr_t ai_fd_writen(int fd, unsigned char const *src, uintptr_t n) {
 if (__ai_osv < 0) return k_row_write(fd, src, n);
 int fl = fcntl(fd, F_GETFL), off = fl >= 0 && !(fl & O_NONBLOCK);
 if (off) fcntl(fd, F_SETFL, fl | O_NONBLOCK);
 ssize_t k;
 do k = write(fd, src, n); while (k < 0 && errno == EINTR);
 if (off) fcntl(fd, F_SETFL, fl);
 return k > 0 ? (intptr_t) k
      : (errno == EAGAIN || errno == EWOULDBLOCK) ? 0 : -1; }

// land every byte, and answer how many got there. a raw fd carries no write run
// of love's, so there is nothing to keep and come back to: a busy device is
// waited on here rather than parked behind. bounded by the device draining --
// a task that must not stall gives the fd to fdopen and writes the port.
uintptr_t ai_fd_say(int fd, unsigned char const *src, uintptr_t n) {
 uintptr_t i = 0;
 while (i < n) {
  intptr_t k = ai_fd_writen(fd, src + i, n - i);
  if (k < 0) break;                            // the device is gone: the rest drops
  if (!k) { ai_sleep(1); continue; }
  i += (uintptr_t) k; }
 return i; }

// the bulk lanes (contract in love.h). stdout rides stdio: nothing traces a static, so
// without fwrite every byte of every print would be its own write(2).
// nonblocking only where a residue can be kept -- io_wdrain re-offers what a heap port's
// door refused; a static has nowhere to park mid-shape, so it waits, bounded by a console
// that drains. the O_NONBLOCK pair is per call on any fd we merely inherited: leaving a
// terminal nonblocking at exit hands the user's shell back broken. 2.9M fcntls at 953 KB
// is why the run pays it once per 4096 and a pipe takes the bit for the session (inflag).
static struct ai *fd_writen(struct ai *g, unsigned char const *src, uintptr_t n) {
 if (__ai_osv < 0) return k_port_writen(g, src, n);
 struct ai_io *io = g->io;
 intptr_t fd = ai_io_fd(io);
 if (io == &ai_stdout.io || io == &ai_stdin.io || io == &ai_stderr.io) {
  uintptr_t k = io == &ai_stdout.io ? fwrite(src, 1, n, stdout)
                                 : ai_fd_write_all((int) fd, src, n);
  if (k < n && errno == EPIPE) console_hangup();
  return g->b = (intptr_t) k, g; }
 return g->b = ai_fd_writen((int) fd, src, n), g; }   // >0 landed, 0 busy, -1 gone

static intptr_t fd_readn(struct ai *g, unsigned char *dst, uintptr_t n) {
 if (__ai_osv < 0) return k_port_readn(g, dst, n);
 return ai_fd_readn(g, (int) ai_io_fd(g->io), dst, n); }

struct ai_port_vt const ai_fd_port_vt = { fd_flush, fd_writen, fd_readn, NULL };

struct ai_fio
 ai_stdin = { { lvm_port_io, &ai_fd_port_vt, putcharm(EOF) }, putcharm(STDIN_FILENO) },
 ai_stdout = { { lvm_port_io, &ai_fd_port_vt, putcharm(EOF) }, putcharm(STDOUT_FILENO) },
 ai_stderr = { { lvm_port_io, &ai_fd_port_vt, putcharm(EOF) }, putcharm(STDERR_FILENO) };

// the GC-context drain (a collected port's unflushed write run): raw write(2),
// no g machinery -- safe inside run_finalizers. on inle the write lands in
// k_fd_write's row, which is that port's absolute fd by the seat law.
void ai_fd_drain(int fd, void const *p, uintptr_t n) { ai_fd_write_all(fd, p, n); }

__attribute__((weak)) void k_row_close(int fd) {}
__attribute__((weak)) bool k_ready(int fd, int events) { return true; }
__attribute__((weak)) void k_wait_fds(struct ai_wait_fd *fds, int n, uintptr_t ms) {}
__attribute__((weak)) void k_sleep(uintptr_t ms) {}

// shared EINTR-retry skeleton for poll-based wait. ms=0 means infinite.
// returns only when poll succeeds (data ready / deadline elapsed) or fails
// for a non-EINTR reason.
static void poll_wait(struct pollfd *fds, nfds_t nfds, uintptr_t ms) {
 uintptr_t deadline = ms == 0 ? 0 : ai_clock() + ms;
 for (;;) {
  int t = ms == 0 ? -1 :
          ms > (uintptr_t) __INT_MAX__ ? __INT_MAX__ : (int) ms;
  if (poll(fds, nfds, t) >= 0 || errno != EINTR) return;
  if (!deadline) continue;
  uintptr_t now = ai_clock();
  if (now >= deadline) return;
  ms = deadline - now; } }

void ai_sleep(uintptr_t ms) {
 if (__ai_osv < 0) return k_sleep(ms);
 poll_wait(NULL, 0, ms); }

static ai_noinline int poll_wrap(int fd, int events) {
 struct pollfd p = { .fd = fd, .events = (short) events };
 return poll(&p, 1, 0); }

bool ai_ready(int fd, int events) {
 if (__ai_osv < 0) return k_ready(fd, events);
 return fd < 0 || poll_wrap(fd, events) > 0; }

// love.h lays the block out as poll(2)'s own struct, so there is nothing to copy
// and no vector of ours to size -- which is the whole reason the count needs no
// ceiling, and why `revents` comes back to the scheduler for free.
_Static_assert(sizeof(struct ai_wait_fd) == sizeof(struct pollfd)
            && offsetof(struct ai_wait_fd, fd) == offsetof(struct pollfd, fd)
            && offsetof(struct ai_wait_fd, events) == offsetof(struct pollfd, events),
               "struct ai_wait_fd must be this platform's struct pollfd");
// ... and the two directions must be poll's own bits, for the same reason.
_Static_assert(ai_wait_in == POLLIN && ai_wait_out == POLLOUT,
               "ai_wait_in/out must be this platform's POLLIN/POLLOUT");

// the events come in filled, per fd -- the scheduler knows each task's park
// direction and a blanket mask would wake readers on writable. poll(2) fills
// `revents` on the way back out and the scheduler reads it (love.h).
void ai_wait_fds(struct ai_wait_fd *fds, int n, uintptr_t ms) {
 if (__ai_osv < 0) return k_wait_fds(fds, n, ms);
 if (n <= 0) ai_sleep(ms);
 else poll_wait((struct pollfd*) fds, (nfds_t) n, ms); }

// the same block, asked and not waited on -- one poll(2) for the whole parked ring,
// where the weak default would spend one per fd. that is what lets the scheduler sweep
// the parked tasks on a fairness yield at all (love.c, over sweep_interval).
// no EINTR retry: a zero timeout means poll returns at once, and a signal that beats
// it is answered by leaving every revents zero -- "none ready", asked again next sweep.
// retrying would be the one thing this call must never do, which is block.
// on inle the sweep is per row (love.c's weak default's law: every slot filled,
// so "none ready" never reads as "nobody answered").
void ai_ready_fds(struct ai_wait_fd *fds, int n) {
 if (__ai_osv < 0) {
  for (int i = 0; i < n; i++)
   fds[i].revents = k_ready(fds[i].fd, fds[i].events) ? fds[i].events : 0;
  return; }
 if (n <= 0) return;
 if (poll((struct pollfd*) fds, (nfds_t) n, 0) >= 0) return;
 for (int i = 0; i < n; i++) fds[i].revents = 0; }

// override the weak g.c default with the real close. called by the finalizer
// that ai_io_alloc registers, so it runs when a heap port becomes unreachable.
// static stdin/stdout don't go through this path -- they live outside the l
// heap and the GC never visits them. on inle the row's own close method runs.
void ai_fd_close(int fd) {
 if (__ai_osv < 0) return k_row_close(fd);
 close(fd); }

// a love port -> the fd under it, or -1 for anything that is not an fd port. the fd
// port is this file's (ai_fd_port_vt below), so the question belongs here too.
intptr_t ai_port_fd(ai_word x) {
 if (!charmp(x) && ((union u*) x)->ap == lvm_port_io)
  return ai_io_fd((struct ai_io*) x);
 return -1; }
