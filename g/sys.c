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

