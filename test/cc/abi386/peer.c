/* gcc's half of the i386 register-argument check (host.c is mooncc's): both halves build
 * with the same -mregparm=N, and every shape crosses both ways -- words, narrow words, a
 * long long that fits the registers left and one that does not, doubles and structs that
 * never take one, a struct returned through the hidden pointer, a variadic call */
#include <stdarg.h>

struct s3 { int a, b, c; };
struct s1 { char c; };
struct s5 { char b[5]; };
struct s2 { short x; int y; };
int peer_s1(struct s1 a, int k) { return a.c * 10 + k; }
int peer_s5(int k, struct s5 v) { return k * 100000 + v.b[0] * 10000 + v.b[1] * 1000 + v.b[2] * 100 + v.b[3] * 10 + v.b[4]; }
int peer_s2(int k, struct s2 v, int m) { return k * 10000 + v.x * 1000 + v.y * 10 + m; }
int peer_w4(int a, int b, int c, int d) { return a * 1000 + b * 100 + c * 10 + d; }
int peer_narrow(char a, short b, unsigned char c, int d) { return a * 1000 + b * 100 + c * 10 + d; }
long long peer_pfit(int a, long long b, int c) { return a + b * 3 + c; }
long long peer_pspill(int a, int b, long long c, int d) { return a + b * 2 + c * 5 + d * 7; }
long long peer_pp(long long a, long long b) { return a * 2 - b; }
double peer_dbl(double x, int a, double y, int b) { return x * a + y * b; }
int peer_st(struct s3 s, int k, int m) { return s.a * k + s.b * m + s.c; }
struct s3 peer_sret(int a, int b, int c) { struct s3 s = { a, b * 2, c * 3 }; return s; }
struct s3 peer_sret_ll(long long a, int b) { struct s3 s = { (int) a, (int) (a >> 32), b }; return s; }
char peer_retc(int x) { return (char) (x + 1); }
long long peer_va(int n, ...) {
  va_list ap; long long t = 0;
  va_start(ap, n);
  for (int i = 0; i < n; i++) t = t * 10 + va_arg(ap, int);
  t += va_arg(ap, long long);
  va_end(ap);
  return t; }

/* the way back: peer calls host's twins of the same shapes, directly and through pointers */
int host_w4(int, int, int, int);
long long host_pfit(int, long long, int);
long long host_pspill(int, int, long long, int);
struct s3 host_sret(int, int, int);
double host_dbl(double, int, double, int);
int host_st(struct s3, int, int);
long long host_va(int, ...);
int host_s1(struct s1, int);
int host_s5(int, struct s5);
int host_s2(int, struct s2, int);
int peer_back(void) {
  int bad = 0;
  int (*w4)(int, int, int, int) = host_w4;
  struct s3 s = host_sret(4, 5, 6), q = { 1, 2, 3 };
  bad += host_w4(1, 2, 3, 4) != 1234;
  bad += w4(5, 6, 7, 8) != 5678;
  bad += host_pfit(1, 10000000000LL, 2) != 30000000003LL;
  bad += host_pspill(1, 2, 3000000000LL, 4) != 15000000033LL;
  bad += s.a != 4 || s.b != 10 || s.c != 18;
  bad += host_dbl(1.5, 2, 0.25, 4) != 4.0;
  bad += host_st(q, 10, 100) != 213;
  bad += host_va(3, 1, 2, 3, 1000000000000LL) != 1000000000123LL;
  { struct s1 a = { 7 }; struct s5 v = { { 1, 2, 3, 4, 5 } }; struct s2 w = { 3, 4 };
    bad += host_s1(a, 3) != 73;
    bad += host_s5(6, v) != 612345;
    bad += host_s2(1, w, 2) != 13042; }
  return bad; }
