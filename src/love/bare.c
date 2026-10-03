// src/love/bare.c -- the null seat: what the runtime's doors answer with no src/love/fd.c beside them.
// the boards link it (src/inle/port.mk's love_m) and so does out/front -- a hosted love, love0 and
// every kernel all carry src/love/fd.c, whose bodies are the real ones.
//
// these six and no more, and every one of them is about the ABSENCE OF fd.c. a seat can
// lack fd.c and still have hardware, so the horn's refusal is src/love/nohorn.c's and the OS
// word is src/love/love.c's weak one: bundled here they made this file unlinkable by a seat
// that wanted six of eight, which is a roster this file has no business deciding.
//
// plain definitions, not weak defaults in the runtime: a seat that grows a real door
// collides here and says so, and a seat that needs one and has none fails to link. the
// old shape answered quietly in both directions.
#include "love.h"

void love_fd_close(int fd) { }
void love_fd_drain(int fd, void const *p, uintptr_t n) { }
// no kernel bracket to drain, so the image bakes the book it was handed
uintptr_t knifs_slice(struct def const **s) { return *s = NULL, 0; }
// the heap runs where it lies: no second, executable window
char *code_window(char *p) { return p; }

// the fine clock degrades to the coarse one, widened; a board with a real ns source
// answers this itself.
intptr_t nclock(void) { return (intptr_t) (love_clock() * 1000000u); }
// ask one fd at a time but fill every slot, so "none ready" never reads as "nobody
// answered". ready and love_sleep are the board's, in its own main.c.
void ready_fds(struct wait_fd *fds, int n) {
  for (int i = 0; i < n; i++)
    fds[i].revents = ready(fds[i].fd, fds[i].events) ? fds[i].events : 0; }
