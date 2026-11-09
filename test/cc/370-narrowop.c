// unsigned arithmetic wraps at 32 bits and clears the top, in each shape an op can take
static volatile unsigned a = 0xfffffff0u, b = 0x20u, s = 4;
static volatile unsigned long w = 0x1ffffffffUL;

static unsigned long add3(unsigned x, unsigned y) { unsigned r = x + y; return r; }
static unsigned long addi(unsigned x) { x += 0x7fffffffu; x += 0x7fffffffu; return x; }
static unsigned long sub2(unsigned x, unsigned y) { x -= y; return x; }
static unsigned long sub3(unsigned x, unsigned y) { unsigned r = y - x; return r; }
static unsigned long andn(unsigned x) { x &= 0xfffffff8u; return x; }
static unsigned long orr(unsigned x, unsigned y) { unsigned r = x | ~y; return r; }
static unsigned long xorr(unsigned x, unsigned y) { unsigned r = ~x ^ y; return r; }
static unsigned long shl1(unsigned x) { x <<= 8; return x; }
static unsigned long shl31(unsigned x) { x <<= 31; return x; }
static unsigned long shlv(unsigned x, unsigned n) { x <<= n; return x; }
static unsigned long cast(unsigned long x, unsigned long y) { return (unsigned) (x + y); }
static unsigned long wid(unsigned long x) { return x + 1; }

int main(void) {
 unsigned long t = 0;
 t += add3(a, b) == 0x10 ? 1 : 0;
 t += addi(a) == 0xfffffff0u + 0xfffffffeUL - 0x100000000UL ? 2 : 0;
 t += sub2(b, a) == 0x30 ? 4 : 0;
 t += sub3(a, b) == 0x30 ? 8 : 0;
 t += andn(a | 7) == 0xfffffff0u ? 16 : 0;
 t += orr(0, 0xfffffff0u) == 0xf ? 32 : 0;
 t += xorr(0, 0xf0u) == 0xffffff0fu ? 1 : 0;
 t += shl1(a) == 0xfffff000u ? 2 : 0;
 t += shl31(3) == 0x80000000u ? 4 : 0;
 t += shlv(a, s) == 0xffffff00u ? 8 : 0;
 t += cast(w, 2) == 1 ? 16 : 0;
 t += wid(w) == 0x200000000UL ? 32 : 0;
 return (int) t;
}
