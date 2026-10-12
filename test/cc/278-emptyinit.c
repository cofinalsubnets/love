/* a member of no size (GNU's empty struct: the uniprocessor kernel's arch_spinlock_t) inside a
 * static image takes no bytes: the members after it keep their places (init_files' .fdt laid
 * one word late and the boot read a null fd table). held to gcc. */
#include <stdio.h>

struct E { };
struct W { struct E e; long x; };
struct T { int a; struct W w; long b; int c; };
struct L { struct L *next, *prev; };
struct Q { struct E lock; struct L head; };
struct F { int count; struct Q q; struct F *self; long tail; };

struct T t1 = { 0, { { }, 5 }, 1, 2 };
struct T t2 = { .w = { .e = { }, .x = 6 }, .b = 3, .c = 4 };
struct F f = { .count = 1, .q = { .lock = { }, .head = { &f.q.head, &f.q.head } }, .self = &f, .tail = 9 };

int main(void) {
  printf("%ld %ld %d\n", t1.w.x, t1.b, t1.c);
  printf("%ld %ld %d\n", t2.w.x, t2.b, t2.c);
  printf("%d %d %ld\n", f.self == &f, f.q.head.prev == &f.q.head, f.tail);
  return (int)(t1.w.x + t1.b + t1.c + t2.w.x + t2.b + t2.c + (f.self == &f) + (f.q.head.prev == &f.q.head) + f.tail);
}
