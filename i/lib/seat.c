// i/lib/seat.c -- the seat under an embedded love: what a library owes the
// runtime when the program around it owns main(), the fds and the signals.
//
// the three static ports are process globals by the runtime's own contract
// (love.h declares them extern), so a linked-in love gets ONE console however
// many sessions open. the write callback below is that console, and lv.c
// re-points it per call -- which is the one place the single-console shape
// shows, and the reason a second session in one process is a design question
// and not a switch.
#include "love.h"
#include "lv.h"

#include <stdio.h>
#include <string.h>
#include <time.h>

#ifndef EOF
#define EOF (-1)
#endif

// the live sink. NULL writes to the process's own stdio.
static lv_writer sink;
static void *sink_ud;

void lv_seat_sink(lv_writer w, void *ud) { sink = w, sink_ud = ud; }

uintptr_t ai_clock(void) {
  struct timespec ts;
  return clock_gettime(CLOCK_MONOTONIC, &ts) ? 0
       : (uintptr_t) (ts.tv_sec * 1000u + (uintptr_t) ts.tv_nsec / 1000000u); }

void ai_sleep(uintptr_t ms) {
  struct timespec t = { (time_t) (ms / 1000), (long) (ms % 1000) * 1000000L };
  nanosleep(&t, NULL); }

// an embedded love owns no fd: every port here is memory, and memory is always
// ready. a host that wants real sockets links i/fd.c instead of this file.
bool ai_ready(int fd, int events) { return 1; }
void ai_wait_fds(struct ai_wait_fd *fds, int n, uintptr_t ms) { ai_sleep(ms); }

static intptr_t fd_writen(intptr_t fd, unsigned char const *src, uintptr_t n) {
  if (sink) sink(sink_ud, (int) fd, (char const*) src, n);
  else fwrite(src, 1, n, fd == 2 ? stderr : stdout);
  return (intptr_t) n; }

// no text input: the host feeds love by argument, not by console.
static intptr_t port_readn(struct ai *g, unsigned char *dst, uintptr_t n) { return -1; }
static struct ai *port_writen(struct ai *g, unsigned char const *src, uintptr_t n) {
  return g->b = fd_writen(ai_io_fd(g->io), src, n), g; }
static struct ai *port_flush(struct ai *g) {
  if (!sink) fflush(ai_io_fd(g->io) == 2 ? stderr : stdout);
  return g; }

struct ai_port_vt const ai_fd_port_vt = { port_flush, port_writen, port_readn, NULL };

struct ai_fio ai_stdin  = { { lvm_port_io, &ai_fd_port_vt, putcharm(EOF) }, putcharm(0) };
struct ai_fio ai_stdout = { { lvm_port_io, &ai_fd_port_vt, putcharm(EOF) }, putcharm(1) };
struct ai_fio ai_stderr = { { lvm_port_io, &ai_fd_port_vt, putcharm(EOF) }, putcharm(2) };

// the raw-fd rows love's io ops owe beside the vtable (i/fdrow.h's shape, over
// this seat's one console).
intptr_t ai_fd_readn(struct ai *g, int fd, unsigned char *dst, uintptr_t n) {
  return fd ? -1 : port_readn(g, dst, n); }
uintptr_t ai_fd_say(int fd, unsigned char const *src, uintptr_t n) {
  return fd == 1 || fd == 2 ? (uintptr_t) fd_writen(fd, src, n) : 0; }
