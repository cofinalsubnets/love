#include "../impl.h"

/* the BSDs lay stack_t as (sp, size, flags), and their SS_DISABLE is 4 */
struct __bsd_stack { void *ss_sp; unsigned long ss_size; int ss_flags; };

static int __ss_bsd(int f) { return (f & SS_ONSTACK) | (f & SS_DISABLE ? 4 : 0); }
static int __ss_lin(int f) { return (f & SS_ONSTACK) | (f & 4 ? SS_DISABLE : 0); }

int sigaltstack(stack_t const *ss, stack_t *old) {
  if (__ai_osv < 2) return (int) er(sc2(NR_sigaltstack, (long) ss, (long) old));
  struct __bsd_stack b, o;
  if (ss) { b.ss_sp = ss->ss_sp; b.ss_size = ss->ss_size; b.ss_flags = __ss_bsd(ss->ss_flags); }
  int r = (int) er(sc2(NR_sigaltstack, ss ? (long) &b : 0, old ? (long) &o : 0));
  if (r == 0 && old) { old->ss_sp = o.ss_sp; old->ss_size = o.ss_size; old->ss_flags = __ss_lin(o.ss_flags); }
  return r; }
