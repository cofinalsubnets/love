/* the AST inliner: a call at a position its statement evaluates first becomes the callee's
 * body ahead of the statement, each param a fresh local (or the caller's own name, or *p its
 * x when the arg is &x), each return a store, a substituted expression, or -- at a return --
 * the caller's own return. every shape below is one of its lanes or one of its declines, and
 * main answers how many of them agree with the value C gives them (32). */

static int sq(int x) { return x * x; }
static char nar(int x) { return x; }                            /* a narrowing return */
static _Bool nz(int x) { return x; }                            /* ..and a truth one */
static int ab(int x) { if (x < 0) return -x; return x; }        /* branchy: a store per return */
static int cl(int x, int lo, int hi) { if (x < lo) return lo; else if (x > hi) return hi; return x; }
static void bump(int *p, int n) { *p += n; }                    /* &x arg: *p is x */
static __attribute__((noinline)) void keep(int *p) { *p += 100; }
static void setk(int *p) { *p = 3; keep(p); }                   /* ..handed on to a real call */
static int *idp(int *p) { return p; }                           /* ..or escaping: declined */
static int dec(int n) { int s = 0; while (n--) s += n; return s; }   /* a written param */
int g = 7;
static int useg(int x) { return x + g; }                        /* a free name */
static unsigned long b2w(unsigned long b) { unsigned long q = b / 8, r = b % 8; return q + (r ? 1 : 0); }
static int find(int const *a, int n, int k) { for (int i = 0; i < n; i++) if (a[i] == k) return i; return -1; }
static int fact(int n) { return n < 2 ? 1 : n * fact(n - 1); }  /* recursive: never into itself */
static int d3(int x) { return x + 3; }
static int d2(int x) { return d3(x) * 2; }
static int d1(int x) { return d2(x) - 1; }
static int d0(int x) { return d1(x) + d1(x + 1); }              /* nests past the depth cap */
static double half(double d) { return d * 0.5; }
static unsigned rot(unsigned x, int k) { return x << k | x >> (32 - k); }
static int pos(int x) { return x > 0; }
static int sw(int x) { switch (x & 3) { case 0: return 10; case 1: return 11; default: return 12; } }
static int cnt;
static int tick(void) { return ++cnt; }
static void nop(void) { }
static int sh(int x) { int t = x + 1; { int t = x * 2; x = t; } return t + x; }  /* shadowed local */
struct node { struct node *next; long v; };
static struct node pool[4];
static void *grab(unsigned long n) { static int i; return (void *) &pool[i++ + (int) (n - n)]; }

static int nar2(int x) { return nar(x); }                       /* ret-mode: char into int */
static int firstof(int const *a, int n) { return find(a, n, 5); }
static int swr(int x) { return sw(x); }

int main(void) {
  int ok = 0, s = 0, n = 5;
  for (int i = -n; i < n; i++) { s += sq(i); s += ab(i) * 3; s += cl(i, -2, 3); }
  ok += s == 160;
  ok += (nar(300) + 1) == 45;                                 /* 44 + 1 */
  ok += (nz(5) + nz(0) + nz(-2)) == 2;
  ok += nar2(300) == 44;
  int x = 4; bump(&x, 9); ok += x == 13;
  int y = 0; setk(&y); ok += y == 103;
  int z = 1; *idp(&z) = 6; ok += z == 6;
  int k = 6; ok += dec(k) == 15; ok += k == 6;
  ok += useg(n) == 12;
  { int g = 3; ok += useg(g) == 10; }                       /* a caller local shadows the free name */
  ok += ((long) b2w(8)) == 1; ok += ((long) b2w(13)) == 2;
  int arr[6] = {3, 1, 4, 1, 5, 9};
  ok += find(arr, 6, 4) == 2; ok += find(arr, 6, 7) == -1; ok += firstof(arr, 6) == 4;
  ok += fact(6) == 720;
  ok += d0(4) == 28;
  ok += ((long) (half(7.0) * 4)) == 14;
  ok += ((long) rot(0x80000001u, 4)) == 24;
  ok += (pos(3) ? 100 : 200) == 100; ok += (pos(-3) ? 100 : 200) == 200;
  if (pos(n) && ab(-n) == n) ok++;
  ok += (sw(5) + sw(8) + swr(2)) == 33;
  cnt = 0; int t1 = (tick(), tick()); ok += t1 == 2; ok += cnt == 2;
  cnt = 0; int t2 = tick() > 5 && tick() > 0; ok += t2 == 0; ok += cnt == 1;
  nop();
  ok += sh(5) == 16;
  int a = sq(3), b = a + sq(a);                      /* a decl splits around its hoists */
  ok += b == 90;
  struct node *p = grab(b2w(sizeof *p));             /* the hoisted b2w names the decl it inits */
  p->v = 42; ok += p->v == 42;
  long acc = 0; for (int j = 0; j < 100; j++) acc += cl(j * 7 % 23, 4, 17) + (long) b2w((unsigned long) j);
  ok += acc == 1735;
  return ok; }
