#include "i.h"


op11(g_vm_car, twop(Sp[0]) ? A(Sp[0]) : Sp[0])
op11(g_vm_cdr, twop(Sp[0]) ? B(Sp[0]) : nil)
op11(g_vm_twop, twop(Sp[0]) ? putnum(-1) : nil)
g_vm(g_vm_cons) {
 Have(Width(struct g_pair));
 struct g_pair *w = (struct g_pair*) Hp;
 Hp += Width(struct g_pair);
 ini_two(w, Sp[0], Sp[1]);
 *++Sp = word(w);
 Ip++;
 return Continue(); }
