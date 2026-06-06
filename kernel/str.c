#include "i.h"
#define MIN(p,q) ((p)<(q)?(p):(q))
#define MAX(p,q) ((p)>(q)?(p):(q))

struct g *str0(struct g *f, uintptr_t len) {
 uintptr_t req = str_type_width + b2w(len);
 if (g_ok(f = g_have(f, req + 1)))
  *--f->sp = word(ini_str(bump(f, req), len));
 return f; }

struct g *g_strof(struct g *f, char const *cs) {
 uintptr_t len = strlen(cs);
 if (g_ok(f = str0(f, len))) memcpy(txt(f->sp[0]), cs, len);
 return f; }

op11(g_vm_strp, strp(Sp[0]) ? putnum(1) : nil)
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

// buf self-quotes when applied -- its address is the kind tag, exactly like
// g_vm_port_io for ports. Body byte-identical to g_vm_port_io; g_noicf (on
// every g_vm) keeps the two distinct so bufp and iop never collide. NOT a
// data_vt sentinel, so the GC copies a buf via the generic thread path and the
// cheney scan forwards its backing-string pointer -- no bespoke evac/copy.
g_vm(g_vm_buf) {
 word x = word(Ip);
 return Ip = cell(*++Sp), *Sp = x, Continue(); }

// (bufnew n) — allocate a zeroed n-byte mutable buf (n<0 / non-numeric -> 0).
// Two heap objects under one Have (so no GC sees a half-built buf): the
// backing g_str holding the bytes, and the length-2 wrapper thread
// [g_vm_buf, str, terminator] that gives it its identity.
g_vm(g_vm_bufnew) {
 intptr_t n = nump(Sp[0]) ? getnum(Sp[0]) : 0;
 if (n < 0) n = 0;
 uintptr_t sreq = str_type_width + b2w(n),
           breq = Width(struct g_buf) + Width(struct g_tag);
 Have(sreq + breq);
 struct g_str *s = ini_str((struct g_str*) Hp, n);
 Hp += sreq;
 memset(txt(s), 0, n);
 union u *k = (union u*) Hp;
 Hp += breq;
 ((struct g_buf*) k)->ap = g_vm_buf;
 ((struct g_buf*) k)->str = s;
 tagthd(k, Width(struct g_buf));
 return Sp[0] = word(k), Ip++, Continue(); }

// (bcopy dst doff src soff n) — copy n bytes from src[soff..] into buf dst at
// doff. src may be a string or buf; dst must be a buf. Ranges are clamped to
// both backing stores -- a safety net (the caller sizes dst to fit), so an
// out-of-range request copies less rather than trampling the heap. Returns
// dst. No allocation, so no GC dance and the trailing tail call is preserved.
g_vm(g_vm_bcopy) {
 word dst = Sp[0], src = Sp[2];
 if (bufp(dst) && (strp(src) || bufp(src))) {
  struct g_str *d = buf_str(dst), *s = bytes_of(src);
  intptr_t doff = getnum(Sp[1]), soff = getnum(Sp[3]), n = getnum(Sp[4]),
           dl = len(d), sl = len(s);
  if (n < 0) n = 0;
  if (doff < 0) doff = 0;
  if (soff < 0) soff = 0;
  if (doff + n > dl) n = dl - doff;
  if (soff + n > sl) n = sl - soff;
  if (n > 0) memmove(txt(d) + doff, txt(s) + soff, n); }
 return Sp[4] = dst, Sp += 4, Ip += 1, Continue(); }

// public predicate for frontends that need to check string args
bool g_strp(g_word x) { return strp(x); }
