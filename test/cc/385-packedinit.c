// packed members off their natural alignment, laid by an initializer, a store, a copy, a compound
// literal and a step, wide ones too, read back whole: v6-M faults on any word not on its alignment
#include <stdint.h>
#include <string.h>

struct dp { unsigned short size; unsigned long address; } __attribute__((packed));
struct q { char c; uint32_t w; uint16_t h; uint64_t d; } __attribute__((packed));
char text[16];
__attribute__((noinline)) static unsigned long id(unsigned long x) { return x; }
__attribute__((noinline)) static uint32_t sum(const struct q *p) { return p->w + p->h + (uint32_t) p->d + (uint32_t) (p->d >> 32) + (uint32_t) p->c; }
__attribute__((noinline)) static struct q mk(uint32_t w) { struct q r = { 3, w, 0x1234, 0x0102030405060708ull }; return r; }

int main(void) {
 struct dp d = { .address = id((unsigned long) text), .size = sizeof text - 1 };
 struct q a[3] = { { 1, 0x11223344, 0x5566, 0x778899aabbccddeeull }, { .w = id(9), .d = id(5) } };
 a[2] = mk(77);
 struct q b; memcpy(&b, &a[1], sizeof b);
 b.w += 1;
 uint32_t o = (uint32_t) a[0].d++ + (uint32_t) (a[2].d-- >> 32);
 a[1].d += 0xffffffffull; ++a[1].d;
 uint32_t s = (uint32_t) (d.address == (unsigned long) text) + d.size * 3u + o;
 for (int i = 0; i < 3; i++) s = s * 31 + sum(&a[i]);
 s = s * 31 + sum(&b) + sum(&(struct q) { .c = 2, .h = 7, .w = id(40) });
 return (int) (s % 251);
}
