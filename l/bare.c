// l/bare.c -- the null seat: what the runtime's doors answer with no OS under them and
// no i/fd.c beside them. the boards link it (i/port.mk's love_m) and so does b/front,
// the test frontend, which supplies its own contract and wants exactly these eight and
// no more -- a hosted love, love0 and every kernel all carry i/fd.c, whose bodies are
// the real ones.
//
// plain definitions, not weak defaults in the runtime: a seat that grows a real door
// collides here and says so, and a seat that needs one and has none fails to link. the
// old shape answered quietly in both directions.
#include "love.h"

long __ai_osv;                    // no kernel to name; 0 is what a seat with none reads

void ai_fd_close(int fd) { }
void ai_fd_drain(int fd, void const *p, uintptr_t n) { }
// the horn wants a device; a board that grows one answers this itself
struct ai *ai_horn_writen(struct ai *g, unsigned char const *src, uintptr_t n) {
  return g->b = -1, g; }
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
