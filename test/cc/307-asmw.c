/* a64's "w": an asm operand in a v register, seen by its scalar views (%s %h %d) -- mesa's
 * half-float conversions are the shape. an integer rides in as its bits (fmov from a gp
 * register), a float or double as its value, and both ride out again. elsewhere the same
 * answers come from plain C, so every lane agrees on the exit. */
typedef unsigned short u16;
typedef unsigned int u32;
typedef unsigned long long u64;

static u32 fbits(float f) { union { float f; u32 u; } x; x.f = f; return x.u; }

#if defined(__aarch64__)
static float h2f(u16 h) { float r; __asm__ volatile("fcvt %s0, %h1" : "=w"(r) : "w"(h)); return r; }
static u16 f2h(float f) { u16 r; __asm__ volatile("fcvt %h0, %s1" : "=w"(r) : "w"(f)); return r; }
static double add3(double a, double b) { double r; __asm__("fadd %d0, %d1, %d2" : "=w"(r) : "w"(a), "w"(b)); return r; }
static u64 viad(u64 x) { u64 r; __asm__("fmov %d0, %d1" : "=w"(r) : "w"(x)); return r; }
static float neg(float x) { __asm__("fneg %s0, %s0" : "+w"(x)); return x; }
#else
/* exact for the values below: normals and the subnormals of a half */
static float h2f(u16 h)
{
    int e = h >> 10 & 31, m = h & 1023;
    float v = e ? (float) (1024 + m) : (float) m;
    for (e = e ? e : 1; e < 25; e++) v /= 2;
    for (; e > 25; e--) v *= 2;
    return h & 0x8000 ? -v : v;
}
static u16 f2h(float f)
{
    u32 b = fbits(f), s = b >> 16 & 0x8000;
    int e = (int) (b >> 23 & 255) - 127 + 15;
    u32 m = b & 0x7fffff;
    if ((b & 0x7fffffff) == 0) return (u16) s;
    if (e <= 0) return (u16) (s | ((m | 0x800000) >> (14 - e)));
    return (u16) (s | (u32) e << 10 | m >> 13);
}
static double add3(double a, double b) { return a + b; }
static u64 viad(u64 x) { return x; }
static float neg(float x) { return -x; }
#endif

int main(void)
{
    static const u16 hs[] = { 0x3c00, 0xc000, 0x3800, 0x7bff, 0x0001, 0x0200, 0x3555, 0x0000 };
    u32 h = 0;
    for (int i = 0; i < 8; i++) {
        float f = h2f(hs[i]);
        h = h * 31 + fbits(f);
        h = h * 31 + f2h(f);
        h += f2h(f) == hs[i];                  /* each one round-trips */
    }
    h = h * 31 + (u32) (add3(1.5, 2.25) * 4);  /* 15 */
    h = h * 31 + (u32) viad(0x123456789abcdefULL);
    h = h * 31 + (u32) (viad(0x123456789abcdefULL) >> 32);
    h = h * 31 + fbits(neg(3.0f));
    return (int) ((h ^ h >> 7 ^ h >> 14 ^ h >> 21) & 127);
}
