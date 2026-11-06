// src/love/user/nokern.c -- refusing bodies for kmain.c's symbols, for a link without the kernel:
// main.c reaches them even where unreachable, and a projection patches each with a jump, so
// each stands aligned. plain, not weak, so two or none fails the link;
// common.mk keeps this out of host_c and each link names it, as it names main0.c
#include "love.h"
#define door __attribute__((aligned(16)))

door char *code_window(char *p) { return p; }

door struct g *k_port_flush(struct g *g) { return g; }
door struct g *k_port_writen(struct g *g, unsigned char const *src, uintptr_t n) { return g->b = -1, g; }
door intptr_t k_port_readn(struct g *g, unsigned char *dst, uintptr_t n) { return -1; }
door intptr_t k_row_read(int fd, unsigned char *dst, uintptr_t n) { return -1; }
door intptr_t k_row_write(int fd, unsigned char const *src, uintptr_t n) { return -1; }
door void k_row_close(int fd) {}
door bool k_ready(int fd, int events) { return true; }
door void k_wait_fds(struct wait_fd *fds, int n, uintptr_t ms) {}
door void k_sleep(uintptr_t ms) {}
door int k_horn_open(int rate) { return -1; }
door intptr_t k_horn_write(unsigned char const *src, uintptr_t n) { return -1; }
door uintptr_t k_horn_lag(void) { return 0; }
door void k_horn_close(void) { }
door lvm(k_lvm_quit) { love_musttail return Ap(_lvm_ghelp, g); }
door lvm(k_lvm_getpid) { love_musttail return Ap(_lvm_ghelp, g); }
