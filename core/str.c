#include "i.h"
#define MIN(p,q) ((p)<(q)?(p):(q))
#define MAX(p,q) ((p)>(q)?(p):(q))

// Allocate a fresh struct g_str of `len` bytes, zero-filled, push on Sp.
struct g *str0(struct g *f, uintptr_t len) {
 uintptr_t req = str_type_width + b2w(len);
 if (g_ok(f = g_have(f, req + 1))) {
  struct g_str *s = bump(f, req);
  ini_str(s, len);
  memset(s->bytes, 0, len);
  *--f->sp = word(s); }
 return f; }


struct g *g_strof(struct g *f, char const *cs) {
 uintptr_t len = strlen(cs);
 f = str0(f, len);
 if (g_ok(f)) memcpy(txt(f->sp[0]), cs, len);
 return f; }

op11(g_vm_strp, strp(Sp[0]) ? putnum(-1) : nil)
g_vm(g_vm_ssub) {
 if (!strp(Sp[0])) Sp[2] = nil;
 else {
  struct g_str *s = str(Sp[0]), *t;
  intptr_t i = oddp(Sp[1]) ? getnum(Sp[1]) : 0,
           j = oddp(Sp[2]) ? getnum(Sp[2]) : 0;
  i = MAX(i, 0), i = MIN(i, (word) len(s));
  j = MAX(j, i), j = MIN(j, (word) len(s));
  if (i == j) Sp[2] = nil;
  else {
   size_t req = str_type_width + b2w(j - i);
   Have(req);
   t = (struct g_str*) Hp;
   Hp += req;
   ini_str(t, j - i);
   memcpy(txt(t), txt(s) + i, j - i);
   Sp[2] = (word) t; } }
 return Ip += 1, Sp += 2, Continue(); }

g_vm(g_vm_scat) {
 intptr_t a = Sp[0], b = Sp[1];
 if (!strp(a)) Sp += 1;
 else if (!strp(b)) Sp[1] = a, Sp += 1;
 else {
  struct g_str *x = str(a), *y = str(b), *z;
  uintptr_t
   len = len(x) + len(y),
   req = str_type_width + b2w(len);
  Have(req);
  z = (struct g_str*) Hp;
  Hp += req;
  ini_str(z, len);
  memcpy(txt(z), txt(x), len(x));
  memcpy(txt(z) + len(x), txt(y), len(y));
  *++Sp = word(z); }
 return Ip++, Continue(); }

// public predicate for frontends that need to check string args
bool g_strp(g_word x) { return strp(x); }
