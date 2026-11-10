// a local struct split into its members answers as the struct did, and one it may not split stays whole
static unsigned long long hash = 14695981039346656037ULL;
static void mix(unsigned long long x) { for (int i = 0; i < 8; i++, x >>= 8) hash = (hash ^ (x & 255)) * 1099511628211ULL; }
struct br { const unsigned char *s, *p; unsigned long long c; unsigned u; };
struct mixd { signed char c; short h; unsigned char uc; int i; long long q; float f; double d; int *ip; _Bool b; };
union un { int i; float f; unsigned char b[4]; };
struct un2 { union { int a; float b; }; int z; };
struct bf { int a : 3; int b : 5; };
struct arr { int n; int v[3]; };
struct nest { struct br in; int k; };

static int init(struct br *r, const unsigned char *p, int n) { if (n < 1) return 0; r->s = p; r->p = p + n; r->c = p[0]; r->u = n; return 1; }
static void step(struct br *r) { r->c = r->c * 31 + *--r->p; r->u--; }
static int peek(const struct br *r) { return (int) r->c & 255; }
static struct br *keep_ptr;
static void keeper(struct br *r) { keep_ptr = r; }                 // keeps it
static int *field_ptr(struct br *r) { return (int *) &r->u; }      // an interior pointer leaves
static struct br *ident(struct br *r) { return r; }                // the value leaves
static int fill(struct mixd *m, int k) { m->c = k; m->h = k * 300; m->uc = k + 250; m->i = k; m->q = (long long) k * 1099511627776LL; m->f = k / 3.0f; m->d = k / 7.0; m->ip = &m->i; m->b = k & 1; return k + 1; }
__attribute__((noinline)) static void vfill(struct br *r) { r->u += 7; }
__attribute__((noinline)) static long ret_long(struct br *r, long v) { r->u += (unsigned) v; return v * 2; }

int run_basic(void) {                          // split, a call in a condition, an update in a loop
  static const unsigned char d[] = { 3, 1, 4, 1, 5, 9, 2, 6 };
  struct br r;
  if (!init(&r, d, 8)) return -1;
  while (r.u) { step(&r); r.c ^= r.u; }
  mix(r.c), mix(r.u), mix((unsigned long long) (r.p - r.s));
  return peek(&r);
}
int run_args(void) {                           // an argument mentioning the struct: stays whole
  struct br r;
  init(&r, (const unsigned char *) "abc", 3);
  r.u = 5;
  int x = ret_long(&r, r.u++);
  mix(x), mix(r.u);
  return x;
}
int run_values(void) {                         // the call's answer, members changed either side
  struct br r;
  r.u = 1; r.c = 2;
  long a = ret_long(&r, 3);
  r.u *= 2;
  long b = ret_long(&r, a) + ret_long(&r, 1);
  vfill(&r);
  mix(a), mix(b), mix(r.u), mix(r.c);
  return (int) b;
}
int run_kept(void) {                           // a kept pointer sees the member's latest write
  struct br r;
  r.u = 1;
  keeper(&r);
  r.u = 9;
  mix(keep_ptr->u);
  keep_ptr->u = 11;
  mix(r.u);
  return r.u;
}
int run_interior(void) {                       // through an interior pointer, and through its own answer
  struct br r;
  r.u = 4;
  int *q = field_ptr(&r);
  *q = 12;
  mix(r.u);
  struct br *self = ident(&r);
  self->c = 6;
  r.c++;
  mix(self->c);
  return r.u;
}
int run_mixed(int k) {                         // every scalar width, wrapped as its member's type
  struct mixd m;
  int n = fill(&m, k);
  m.c += 120; m.h += 32000; m.uc += 10; m.q >>= 3; m.f *= 2; m.d += m.f; m.b = m.i;
  mix((unsigned long long) (long long) m.c), mix((unsigned long long) (long long) m.h), mix(m.uc), mix((unsigned long long) (long long) m.i);
  mix((unsigned long long) m.q), mix((unsigned long long) (long long) (m.f * 1000)), mix((unsigned long long) (long long) (m.d * 1000)), mix(m.b), mix(n);
  mix(*m.ip == m.i);
  return n;
}
int run_plain(int k) {                         // never &-taken, no init: members alone
  struct mixd m;
  m.c = k; m.i = m.c * 2; m.q = m.i; m.d = m.q; m.f = (float) m.d; m.b = m.f > 1;
  return (int) (m.c + m.i + m.q + (long long) m.d + (long long) m.f + m.b);
}
int run_whole(int k) {                         // copied whole, and sized: stays one object
  struct br a, b;
  a.u = k; a.c = k + 1; a.s = a.p = 0;
  b = a;
  b.u++;
  mix(a.u), mix(b.u), mix(sizeof a == sizeof b);
  return b.u;
}
int run_init(int k) {                          // with an initializer
  struct br a = { .u = k };
  a.u += 2;
  mix(a.u), mix(a.c);
  return a.u;
}
int run_overlaps(int k) {                      // members sharing bytes
  union un u; struct un2 w; struct bf f; struct arr v; struct nest n;
  u.i = 0x3f800000 + k; mix(u.b[0]); mix((unsigned long long) (long long) (u.f * 1000));
  w.a = 0x40000000; w.z = k; mix((unsigned long long) (long long) w.b), mix(w.z);
  f.a = k; f.b = k * 3; mix((unsigned long long) (long long) f.a), mix((unsigned long long) (long long) f.b);
  v.n = 2; v.v[k & 1] = k; v.v[v.n] = k + 1; mix(v.v[v.n]);
  n.k = k; n.in.u = k + 1; n.in.c = n.k; mix(n.in.u + n.in.c);
  return n.k;
}
int run_scopes(int k) {                        // a name in a loop and a shadow, one fresh each round
  int t = 0;
  for (int i = 0; i < 4; i++) {
    struct br r;
    r.u = i + k;
    { struct br r2; r2.u = r.u * 2; t += r2.u; }
    if (i & 1) { struct br r; r.u = 100; t += r.u; }
    t += r.u;
  }
  return t;
}
int run_rec(int n) {                           // the same call again, recursing
  struct br r;
  r.u = n;
  vfill(&r);
  if (n > 0) r.u += run_rec(n - 1);
  return r.u;
}
int main(void) {
  mix(run_basic()); mix(run_args()); mix(run_values()); mix(run_kept()); mix(run_interior());
  for (int k = -3; k < 9; k += 3) { mix(run_mixed(k)); mix((unsigned long long) (long long) run_plain(k)); mix(run_whole(k)); mix(run_init(k)); mix(run_overlaps(k)); mix(run_scopes(k)); }
  mix(run_rec(5));
  return (int) ((hash ^ hash >> 32) % 251);
}
