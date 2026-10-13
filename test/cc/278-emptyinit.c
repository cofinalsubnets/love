/* static images around members of no size: GNU's empty struct takes no bytes, a flexible
 * array's initializer lays its elements past the struct. held to gcc. */
#include <stdio.h>

struct E { };
struct W { struct E e; long x; };
struct T { int a; struct W w; long b; int c; };
struct L { struct L *next, *prev; };
struct Q { struct E lock; struct L head; };
struct F { int count; struct Q q; struct F *self; long tail; };

struct T t1 = { 0, { { }, 5 }, 1, 2 };
struct T t2 = { .w = { .e = { }, .x = 6 }, .b = 3, .c = 4 };
struct U { int nr; void *ns; };
struct P { int a; unsigned level; struct U numbers[]; };
int ns0;
struct P ip = { .a = 1, .level = 0, .numbers = { { .nr = 7, .ns = &ns0 } } };
long after = 0x400000;
struct F f = { .count = 1, .q = { .lock = { }, .head = { &f.q.head, &f.q.head } }, .self = &f, .tail = 9 };

int main(void) {
  printf("%ld %ld %d\n", t1.w.x, t1.b, t1.c);
  printf("%ld %ld %d\n", t2.w.x, t2.b, t2.c);
  printf("%d %d %ld\n", f.self == &f, f.q.head.prev == &f.q.head, f.tail);
  printf("%d %d\n", ip.numbers[0].nr, ip.numbers[0].ns == &ns0);
  return ip.numbers[0].nr + (ip.numbers[0].ns == &ns0) + (int)(t1.w.x + t1.b + t1.c + t2.w.x + t2.b + t2.c + (f.self == &f) + (f.q.head.prev == &f.q.head) + f.tail);
}
