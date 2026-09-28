/* a declarator's name is in scope from the end of its declarator (C11 6.2.1p7), so its own
 * initializer may type it: the kernel's get_unaligned casts through typeof of the pointer it
 * declares, container_of's typeof(*p), a sizeof over the new object, and an inner name that
 * shadows an outer one of another type -- each held to gcc. container_of steps a void *, which
 * gcc steps by bytes. */

#include <stddef.h>

struct node { int key; long link; };

#define get_unaligned16(p) ({ const struct { unsigned short x; } __attribute__((__packed__)) \
  *__get_pptr = (typeof(__get_pptr))(p); __get_pptr->x; })
#define container_of(ptr, type, member) ({ void *__mptr = (void *)(ptr); \
  ((type *)(__mptr - offsetof(type, member))); })

static void *self = &self;

int main(void) {
  int bad = 0;
  _Alignas(2) unsigned char buf[6] = { 0, 0, 0x34, 0x12, 0, 0 };
  if (get_unaligned16(buf + 2) != 0x1234) bad |= 1;
  struct node n = { 7, 0 };
  long *lp = &n.link;
  struct node *np = container_of(lp, typeof(*np), link);
  if (np != &n || np->key != 7) bad |= 2;
  double *dp = (typeof(dp))0;
  unsigned long w = sizeof w + sizeof *dp;
  if (dp || w != sizeof(unsigned long) + sizeof(double)) bad |= 4;
  int x = 3;
  {
    char x = sizeof(x);
    if (x != 1) bad |= 8;
  }
  if (x != 3 || self != &self) bad |= 16;
  void *m = buf + 2, *m0 = m;
  m++, m -= 2, m += 3;
  if ((unsigned char *)(m - 1) != buf + 3 || m - m0 != 2 || sizeof(void) != 1) bad |= 32;
  return bad;
}
