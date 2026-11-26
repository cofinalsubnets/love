/* the side under test: each does something the other side watches */
#include <stdarg.h>
typedef unsigned long ul;
struct s24 { long a, b, c; };
extern long p_wreck(long, double), p_vsum(int, va_list), p_count(int, ...), p_down(long, long (*)(long)), p_aligned(long, long, long, long, long, long, long);
extern struct s24 p_big(long);
extern int p_al(int, ...);
extern double p_dvsum(int, va_list);

/* many values live across a call that ruins every register it may */
long m_live(long a, long b, long c, long d, long e, long f, double x, double y, double z) {
  long g = a ^ 0x11, h = b + 0x22, i = c * 3, j = d - 4, k = e << 2, l = f ^ a, m = a * b, n = c + d;
  double u = x + y, v = y * z, w = z - x;
  long r = p_wreck(a + f, x);
  r += p_wreck(g, u);
  return r + a + b * 2 + c * 3 + d * 4 + e * 5 + f * 6 + g + h + i + j + k + l + m + n
       + (long)x + (long)y + (long)z + (long)u + (long)v + (long)w;
}
long m_back(long n) { return n < 1 ? 0 : n + p_down(n, m_back); }
long m_tail(long a, long b) { return p_wreck(a + b, 2.0); }
/* varying frames and pushed arguments: the stack is 16 aligned at every call, on i386 too */
long m_stack(long n) {
  char pad[n % 37 + 1];
  pad[0] = (char)n;
  return p_aligned(1, 2, 3, 4, 5, 6, 7) + p_aligned(pad[0], 2, 3, 4, 5, 6, 8);
}
long m_vsum(int n, ...) { va_list a; va_start(a, n); long r = p_vsum(n, a); va_end(a); return r; }
double m_dvsum(int n, ...) { va_list a; va_start(a, n); double r = p_dvsum(n, a); va_end(a); return r; }
long m_vtake(int n, va_list a) { long r = 0; for (int i = 0; i < n; i++) r = r * 3 + va_arg(a, long); return r; }
long m_vcopy(int n, ...) {
  va_list a, b; va_start(a, n); va_copy(b, a);
  long r = p_vsum(n, a) - p_vsum(n, b); va_end(a); va_end(b); return r;
}
#ifdef __x86_64__
int m_al(int k) {
  return k == 0 ? p_al(0, 1, 2) : k == 1 ? p_al(1, 1.0) : k == 2 ? p_al(2, 1.0, 5, 2.0) : p_al(8, 1., 2., 3., 4., 5., 6., 7., 8., 9., 10.);
}
#endif
long m_big(long n) { struct s24 s = p_big(n); return s.a + s.b * 2 + s.c * 4; }
/* held though the psABI leaves it open: a narrow argument's upper bits are not trusted */
long m_narrow(signed char a, unsigned char b, short c, unsigned short d, _Bool e) { return a + b * 2L + c * 3L + d * 4L + e; }
