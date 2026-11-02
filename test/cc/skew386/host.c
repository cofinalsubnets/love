/* mooncc's half: over-aligned locals keep their alignment at each incoming esp it is promised,
 * skews 0 to SKEWS-1 words off the ABI's (-mstack-alignment=4: all four; plain: 0 alone) */
#include <stdio.h>
#ifndef SKEWS
#define SKEWS 4
#endif

int skewcall(int (*f)(int), int k);
struct big { _Alignas(16) char b[24]; };

static int lanes(volatile char *a, volatile struct big *s, volatile long long *w)
{
    return ((unsigned) a & 15) | ((unsigned) s & 15) << 4 | ((unsigned) w & 7) << 8;
}

int probe(int k)
{
    _Alignas(16) char a[16];
    _Alignas(8) long long w = k;
    struct big s;
    a[0] = (char) k;
    s.b[0] = (char) k;
    return lanes(a, &s, &w) | (a[0] != k || s.b[0] != k || w != k) << 12;
}

int main(void)
{
    int bad = 0;
    for (int k = 0; k < SKEWS; k++) {
        int r = skewcall(probe, k);
        if (r) { printf("skew %d: %#x\n", k, r); bad = 1; }
    }
    printf("%s\n", bad ? "misaligned" : "aligned at every skew");
    return bad;
}
