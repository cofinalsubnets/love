#include "i.h"
static struct g *g_pushr(struct g *f, uintptr_t m, uintptr_t n, va_list xs) {
 if (n == m) return g_please(f, m);
 word x = va_arg(xs, word);
 MM(f, &x);
 f = g_pushr(f, m, n + 1, xs);
 UM(f);
 if (g_ok(f)) *--f->sp = x;
 return f; }

struct g *g_push(struct g *f, uintptr_t m, ...) {
 if (!g_ok(f)) return f;
 va_list xs;
 va_start(xs, m);
 uintptr_t n = 0;
 if (avail(f) < m) f = g_pushr(f, m, n, xs);
 else for (f->sp -= m; n < m; f->sp[n++] = va_arg(xs, word));
 va_end(xs);
 return f; }

struct g *gxl(struct g *f) {
 if (g_ok(f = g_have(f, Width(struct g_pair)))) {
  struct g_pair *p = bump(f, Width(struct g_pair));
  ini_two(p, f->sp[0], f->sp[1]);
  *++f->sp = (word) p; }
 return f; }

struct g *gxr(struct g *f) {
 if (g_ok(f = g_have(f, Width(struct g_pair)))) {
  struct g_pair *p = bump(f, Width(struct g_pair));
  ini_two(p, f->sp[1], f->sp[0]);
  *++f->sp = (word) p; }
 return f; }
