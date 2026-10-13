/* a64 asm text as the kernel spells it: the multiply-adds, zr in a logical immediate, and a load
 * into xzr (barrier.h's counter ordering) and a store of it. a target with no template here computes
 * the same in C. */
typedef unsigned long long u64;

#if defined(__aarch64__)
static u64 mla(u64 a, u64 b, u64 c, u64 *p) {
    u64 r, h, l, m;
    __asm__ volatile("madd %0, %4, %5, %6\n"
                     "umulh %1, %4, %5\n"
                     "smull %2, %w4, %w5\n"
                     "orr %3, xzr, #0xff\n"
                     "ldr xzr, [%7]\n"
                     "str xzr, [%7, #8]\n"
                     : "=&r"(r), "=&r"(h), "=&r"(l), "=&r"(m)
                     : "r"(a), "r"(b), "r"(c), "r"(p)
                     : "memory");
    return r + h + l + m;
}
#else
static u64 mulhi(u64 a, u64 b) {
    u64 al = a & 0xffffffffu, ah = a >> 32, bl = b & 0xffffffffu, bh = b >> 32;
    u64 t = ah * bl + ((al * bl) >> 32), u = al * bh + (t & 0xffffffffu);
    return ah * bh + (t >> 32) + (u >> 32);
}
static u64 mla(u64 a, u64 b, u64 c, u64 *p) {
    p[1] = 0;
    return a * b + c + mulhi(a, b) + (u64)((long long)(int)a * (int)b) + 0xff;
}
#endif

int main(void) {
    u64 q[2] = {7, 9};
    u64 v = mla(0x100000003ull, 0xfffffffeull, 5, q);
    return v == 0x1000000f9ull && q[1] == 0 ? 0 : 1;
}
