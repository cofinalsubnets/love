#include "i.h"

g_vm(g_vm_gensym) {
 Have(Width(struct g_atom));
 struct g_atom *y;
 if (strp(Sp[0]))
   Pack(f),
   y = intern_checked(f, (struct g_str*) f->sp[0]),
   Unpack(f);
 else
  y = (struct g_atom*) Hp,
  Hp += Width(struct g_atom) - 2,
  ini_anon(y, g_clock());
 return
  Sp[0] = word(y),
  Ip += 1,
  Continue(); }

g_vm(g_vm_symnom) {
 intptr_t y = Sp[0];
 return
  y = symp(y) && sym(y)->nom ? word(sym(y)->nom) : nil,
  Sp[0] = y,
  Ip += 1,
  Continue(); }

struct g *intern(struct g*f) {
 if (g_ok(f = g_have(f, Width(struct g_atom))))
  f->sp[0] = (word) intern_checked(f, (struct g_str*) f->sp[0]);
 return f; }

// avail must be >= Width(struct g_atom) when this is called.
g_noinline struct g_atom *intern_checked(struct g *v, struct g_str *b) {
 uintptr_t h = rot(hash(v, word(b)));
 for (struct g_atom **y = &v->symbols, *z;;) {
  if (!(z = *y)) return *y = ini_sym(bump(v, Width(struct g_atom)), b, h);
  struct g_str *a = z->nom;
  intptr_t i = z->code < h ? -1 : z->code > h ? 1 : 0;
  if (i == 0) i = len(a) - len(b);
  if (i == 0) i = memcmp(txt(a), txt(b), len(b));
  if (i == 0) return z;
  y = i < 0 ? &z->l : &z->r; } }

op11(g_vm_symp, symp(Sp[0]) ? putnum(-1) : nil)
