// love/bare.c -- the null seat: what the runtime's doors answer with no inle/fd.c beside them.
// the boards link it (inle/port.mk's love_m) and so does out/front -- a hosted love, love0 and
// every kernel all carry inle/fd.c, whose bodies are the real ones.
//
// these six and no more, and every one of them is about the ABSENCE OF fd.c. a seat can
// lack fd.c and still have hardware, so the horn's refusal is love/nohorn.c's and the OS
// word is love/love.c's weak one: bundled here they made this file unlinkable by a seat
// that wanted six of eight, which is a roster this file has no business deciding.
//
// plain definitions, not weak defaults in the runtime: a seat that grows a real door
// collides here and says so, and a seat that needs one and has none fails to link. the
// old shape answered quietly in both directions.
#include "love.h"

void ai_fd_close(int fd) { }
void ai_fd_drain(int fd, void const *p, uintptr_t n) { }
// no kernel bracket to drain, so the image bakes the book it was handed
uintptr_t ai_knifs_slice(struct ai_def const **s) { return *s = NULL, 0; }
// the heap runs where it lies: no second, executable window
char *ai_code_window(char *p) { return p; }

// the fine clock degrades to the coarse one, widened; a board with a real ns source
// answers this itself.
intptr_t ai_nclock(void) { return (intptr_t) (ai_clock() * 1000000u); }
// ask one fd at a time but fill every slot, so "none ready" never reads as "nobody
// answered". ai_ready and ai_sleep are the board's, in its own main.c.
void ai_ready_fds(struct ai_wait_fd *fds, int n) {
  for (int i = 0; i < n; i++)
    fds[i].revents = ai_ready(fds[i].fd, fds[i].events) ? fds[i].events : 0; }
