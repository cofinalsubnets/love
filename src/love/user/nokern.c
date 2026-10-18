// src/love/user/nokern.c -- refusing bodies for kmain.c's symbols, for a link without the kernel:
// main.c reaches them even where unreachable. plain, not weak, so two or none fails the link;
// common.mk keeps this out of host_c and each link names it, as it names main0.c
#include "love.h"

uintptr_t knifs_slice(struct def const **s) { return *s = NULL, 0; }
char *code_window(char *p) { return p; }

struct g *k_port_flush(struct g *g) { return g; }
struct g *k_port_writen(struct g *g, unsigned char const *src, uintptr_t n) { return g->b = -1, g; }
intptr_t k_port_readn(struct g *g, unsigned char *dst, uintptr_t n) { return -1; }
intptr_t k_row_read(int fd, unsigned char *dst, uintptr_t n) { return -1; }
intptr_t k_row_write(int fd, unsigned char const *src, uintptr_t n) { return -1; }
void k_row_close(int fd) {}
bool k_ready(int fd, int events) { return true; }
void k_wait_fds(struct wait_fd *fds, int n, uintptr_t ms) {}
void k_sleep(uintptr_t ms) {}
int k_horn_open(int rate) { return -1; }
intptr_t k_horn_write(unsigned char const *src, uintptr_t n) { return -1; }
uintptr_t k_horn_lag(void) { return 0; }
void k_horn_close(void) { }
lvm(k_lvm_quit) { love_musttail return Ap(_lvm_ghelp, g); }
lvm(k_lvm_getpid) { love_musttail return Ap(_lvm_ghelp, g); }
