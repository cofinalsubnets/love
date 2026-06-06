#include "i.h"

// (intern s) -> the interned symbol named by string s; identity on any other arg.
g_vm(g_vm_intern) {
 if (strp(Sp[0])) {
  struct g_atom *y;
  Have(Width(struct g_atom));
  Pack(f), y = intern_checked(f, (struct g_str*) f->sp[0]), Unpack(f);
  Sp[0] = word(y); }
 return Ip += 1, Continue(); }

// (gensym name) -> a fresh *uninterned* symbol named after `name`: a string (the
// symbol it would intern to) or a symbol (used directly). The new symbol stores
// that naming SYMBOL as its nom, which marks it uninterned (interned syms have a
// string nom; see ini_usym). Any other arg yields an anonymous gensym (nom 0).
g_vm(g_vm_gensym) {
 Have(2 * Width(struct g_atom));               // room for the wrapper + a fresh intern
 struct g_atom *nom;
 if (strp(Sp[0]))                              // (sym "x"): intern "x" -> the symbol it names
   Pack(f), nom = intern_checked(f, (struct g_str*) f->sp[0]), Unpack(f);
 else nom = symp(Sp[0]) ? sym(Sp[0]) : 0;      // symbol arg used as-is; else anonymous
 struct g_atom *y = (struct g_atom*) Hp;
 Hp += Width(struct g_atom) - 2;               // uninterned/anonymous: no l/r subtree slots
 nom ? ini_usym(y, nom, g_clock()) : ini_anon(y, g_clock());
 return
  Sp[0] = word(y),
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
