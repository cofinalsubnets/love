// bare.c -- the doors' answers with no fd.c beside them (the boards, out/front). only what
// the absence of fd.c owes: hardware doors live elsewhere (nohorn.c). plain, not weak, so a
// real door collides here
#include "love.h"

void love_fd_close(int fd) { }
void love_fd_drain(int fd, void const *p, uintptr_t n) { }
// no kernel bracket to drain, so the image bakes the book it was handed
uintptr_t knifs_slice(struct def const **s) { return *s = NULL, 0; }
// the heap runs where it lies: no second, executable window
char *code_window(char *p) { return p; }

// the fine clock from the coarse one
intptr_t nclock(void) { return (intptr_t) (love_clock() * 1000000u); }
// every slot filled, so "none ready" never reads as "nobody answered". ready is the board's
void ready_fds(struct wait_fd *fds, int n) {
  for (int i = 0; i < n; i++)
    fds[i].revents = ready(fds[i].fd, fds[i].events) ? fds[i].events : 0; }
