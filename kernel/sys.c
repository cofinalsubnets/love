#include "i.h"

op11(g_vm_clock, putnum(g_clock() - getnum(Sp[0])))

g_vm(g_vm_info) {
 size_t const req = 7 * Width(struct g_pair);
 Have(req);
 struct g_pair *si = (struct g_pair*) Hp;
 Hp += req;
 Sp[0] = word(si);
 ini_two(si + 0, putnum(f), word(si + 1));
 ini_two(si + 1, putnum(f->len), word(si + 2));
 ini_two(si + 2, putnum(Hp - ptr(f)), word(si + 3));
 ini_two(si + 3, putnum(ptr(f) + f->len - Sp), word(si + 4));
 ini_two(si + 4, putnum(f->n_gc), word(si + 5));               // gc cycles
 ini_two(si + 5, putnum(f->max_len), word(si + 6));            // peak pool len (words)
 ini_two(si + 6, putnum(f->max_heap), nil);                    // peak live heap (words)
 Ip += 1;
 return Continue(); }

// Default fd-keyed waits. Frontends override; defaults are conservative
// (all fds always-ready; multi-source wait collapses to plain sleep) so
// frontends that don't multitask (lcat, pd) link without providing impls.
__attribute__((weak)) bool g_ready(int fd) { (void) fd; return true; }
__attribute__((weak)) void g_wait_fds(int const *fds, int n, uintptr_t ticks) {
  (void) fds; (void) n; g_sleep(ticks); }

// Default fd close is a no-op. The host overrides with close(2); kernel
// and pd don't have real OS fds to release, so the no-op is correct.
__attribute__((weak)) void g_fd_close(int fd) { (void) fd; }
// default sleep is busy wait
__attribute__((weak)) g_noinline void g_sleep(uintptr_t ticks) {
  for (ticks += g_clock(); g_clock() < ticks;); }

g_vm(g_vm_key) {
 Sp[0] = (getnum(g_stdin.ungetc_buf) != EOF || g_ready(getnum(g_stdin.fd))) ? putnum(1) : nil;
 Ip += 1;
 return Continue(); }
