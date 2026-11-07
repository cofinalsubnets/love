/* __int128 by value: registers, past them, returns, members, big literals, a wide right operand */
typedef unsigned __int128 u; typedef __int128 s;
int printf(const char *, ...);
#define P(v) do { u v_ = (v); printf("%016llx%016llx\n", (unsigned long long)(v_ >> 64), (unsigned long long)v_); } while (0)
__attribute__((noinline)) u add3(u a, u b, u c) { return a + b + c; }
__attribute__((noinline)) u afterint(int x, u a, int y) { return a + x - y; }
__attribute__((noinline)) int two(u a, int x, u b) { return (a == b) + x; }
__attribute__((noinline)) u ret(void) { return ((u)0x0123456789abcdefULL << 64) | 0xfedcba9876543210ULL; }
__attribute__((noinline)) s neg(s a) { return -a; }
__attribute__((noinline)) u cond(int c, u a, unsigned long long b) { return c ? a : b; }
struct S { char c; u v; short t; };
__attribute__((noinline)) u fld(struct S *p) { p->v += 5; return p->v++ ; }
u gl = 7; s gs = -9;
int main(void) {
  u a = ret(), b = (u)0xffffffffffffffffULL + 3;
  P(a); P(b); P(add3(a, b, 1)); P(afterint(3, a, 1)); printf("%d\n", two(a, 2, a));
  P(neg(5)); P(~a); P(a & b); P(a | b); P(a ^ b); P(a * b); P(a - b); P(cond(1, a, 3)); P(cond(0, a, 3));
  P(a << 3); P(a >> 3); P(a << 37); P(a >> 67); P((u)((s)~a >> 71)); P((u)(s)-1); P((u)(s)(int)-2); P((u)(long long)-3); P((u)3000000000u);
  P(0x123456789abcdef0ULL * (u)16); P(a / 10); P(a % 10); P(a / (u)0x100000001ULL);
  struct S x = {1, a, 2}; P(fld(&x)); P(x.v); printf("%d %d\n", x.c, x.t);
  gl *= 3; gs -= 1; P(gl); P((u)gs); gl++; ++gl; gl--; P(gl);
  u c = a; c += 1; c <<= 2; c ^= 9; P(c);
  printf("%d %d %d %d\n", a > b, (s)a < (s)b, !a, a ? 1 : 0);
  printf("%llu %u %d\n", (unsigned long long)a, (unsigned)a, (int)(a != 0));
  return (int)(a >> 120) + 1;
}
