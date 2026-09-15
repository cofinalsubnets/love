// inle/nokern.c -- the null seat: what a link with no kmain.c under it owes itself.
// inle/main.c dispatches to the kernel's doors on a negative __ai_osv, so the symbols have
// to stand even where that branch is unreachable; kmain.c gives the real bodies and this
// gives the ones that refuse. love0 was the only such link when these left the runtime,
// and the gate links that build the artifact's C without the kernel half are the others.
//
// plain definitions, not weak ones: a link that ends up with two of any of these says so,
// and a link with none fails to link -- which is why common.mk keeps this out of host_c
// and each link names it, the way it names main0.c.
#include "love.h"

uintptr_t ai_knifs_slice(struct ai_def const **s) { return *s = NULL, 0; }
char *ai_code_window(char *p) { return p; }

// the kernel's port lanes and the rows beneath them: a body where the linker wants one
struct ai *k_port_flush(struct ai *g) { return g; }
struct ai *k_port_writen(struct ai *g, unsigned char const *src, uintptr_t n) { return g->b = -1, g; }
intptr_t k_port_readn(struct ai *g, unsigned char *dst, uintptr_t n) { return -1; }
intptr_t k_row_read(int fd, unsigned char *dst, uintptr_t n) { return -1; }
intptr_t k_row_write(int fd, unsigned char const *src, uintptr_t n) { return -1; }
void k_row_close(int fd) {}
bool k_ready(int fd, int events) { return true; }
void k_wait_fds(struct ai_wait_fd *fds, int n, uintptr_t ms) {}
void k_sleep(uintptr_t ms) {}
int k_horn_open(int rate) { return -1; }
intptr_t k_horn_write(unsigned char const *src, uintptr_t n) { return -1; }
uintptr_t k_horn_lag(void) { return 0; }
void k_horn_close(void) { }
lvm(k_lvm_quit) { ai_musttail return Ap(_lvm_ghelp, g); }
lvm(k_lvm_getpid) { ai_musttail return Ap(_lvm_ghelp, g); }
