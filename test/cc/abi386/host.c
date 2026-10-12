/* mooncc's half of the i386 register-argument check (peer.c is gcc's); built with the same
 * -mregparm=N on both sides. a wrong check prints, and main answers the count */
#include <stdarg.h>
#include <stdio.h>

struct s3 { int a, b, c; };
struct s1 { char c; };
struct s5 { char b[5]; };
struct s2 { short x; int y; };
int host_s1(struct s1 a, int k) { return a.c * 10 + k; }
int host_s5(int k, struct s5 v) { return k * 100000 + v.b[0] * 10000 + v.b[1] * 1000 + v.b[2] * 100 + v.b[3] * 10 + v.b[4]; }
int host_s2(int k, struct s2 v, int m) { return k * 10000 + v.x * 1000 + v.y * 10 + m; }
int peer_w4(int, int, int, int);
int peer_narrow(char, short, unsigned char, int);
long long peer_pfit(int, long long, int);
long long peer_pspill(int, int, long long, int);
long long peer_pp(long long, long long);
double peer_dbl(double, int, double, int);
int peer_st(struct s3, int, int);
struct s3 peer_sret(int, int, int);
struct s3 peer_sret_ll(long long, int);
char peer_retc(int);
long long peer_va(int, ...);
int peer_back(void);
int peer_s1(struct s1, int);
int peer_s5(int, struct s5);
int peer_s2(int, struct s2, int);

int host_w4(int a, int b, int c, int d) { return a * 1000 + b * 100 + c * 10 + d; }
long long host_pfit(int a, long long b, int c) { return a + b * 3 + c; }
long long host_pspill(int a, int b, long long c, int d) { return a + b * 2 + c * 5 + d * 7; }
struct s3 host_sret(int a, int b, int c) { struct s3 s = { a, b * 2, c * 3 }; return s; }
double host_dbl(double x, int a, double y, int b) { return x * a + y * b; }
int host_st(struct s3 s, int k, int m) { return s.a * k + s.b * m + s.c; }
long long host_va(int n, ...) {
  va_list ap; long long t = 0;
  va_start(ap, n);
  for (int i = 0; i < n; i++) t = t * 10 + va_arg(ap, int);
  t += va_arg(ap, long long);
  va_end(ap);
  return t; }

static int n_, bad_;
static void ck(long long got, long long want) {
  n_++;
  if (got != want) { printf("check %d: got %lld want %lld\n", n_, got, want); bad_++; } }

int main(void) {
  struct s3 q = { 7, 8, 9 }, r;
  long long (*pf)(int, long long, int) = peer_pfit;
  ck(peer_w4(1, 2, 3, 4), 1234);
  ck(peer_narrow(-1, 2, 200, 4), -1000 + 200 + 2000 + 4);
  ck(peer_pfit(1, 10000000000LL, 2), 30000000003LL);
  ck(pf(2, -5, 3), -10);
  ck(peer_pspill(1, 2, 3000000000LL, 4), 15000000033LL);
  ck(peer_pp(5000000000LL, 7), 9999999993LL);
  ck((long long) (peer_dbl(1.5, 2, 0.25, 4) * 4), 16);
  ck(peer_st(q, 10, 100), 70 + 800 + 9);
  r = peer_sret(4, 5, 6);
  ck(r.a * 10000 + r.b * 100 + r.c, 41018);
  r = peer_sret_ll(0x500000003LL, 9);
  ck(r.a * 100 + r.b * 10 + r.c, 359);
  ck(peer_retc(64), 65);
  ck(peer_va(3, 1, 2, 3, 1000000000000LL), 1000000000123LL);
  { struct s1 a = { 7 }; struct s5 v = { { 1, 2, 3, 4, 5 } }; struct s2 w = { 3, 4 };
    ck(peer_s1(a, 3), 73);
    ck(peer_s5(6, v), 612345);
    ck(peer_s2(1, w, 2), 13042); }
  ck(peer_back(), 0);
  printf("%d checks, %d bad\n", n_, bad_);
  return bad_; }
