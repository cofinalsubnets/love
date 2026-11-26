/* every access here is to a packed member through a pointer: by bytes wherever the target takes no unaligned word */
struct __attribute__((packed)) S { char c; short h; int i; long long l; float f; double d; void *p; int a[2]; unsigned x : 17; int y : 11; };
struct __attribute__((packed)) N { char c; struct { int k; } in; };
struct __attribute__((packed)) B { char c; int a : 3; unsigned long long x : 45; int y : 1; unsigned short h; };
struct I { unsigned a : 5; int b : 20; };
struct __attribute__((packed)) O { char c; struct I in; };
struct B gb;
unsigned long long lbx(struct B *p) { return p->x; }
void sbx(struct B *p, unsigned long long v) { p->x = v; }
unsigned long long gbx(void) { gb.y = 1; return gb.x; }
int lob(struct O *p) { return p->in.b; }
void sob(struct O *p, int v) { p->in.b = v; }
int lh(struct S *p) { return p->h; }
int li(struct S *p) { return p->i; }
long long ll(struct S *p) { return p->l; }
float lf(struct S *p) { return p->f; }
double ld(struct S *p) { return p->d; }
void *lp(struct S *p) { return p->p; }
int la(struct S *p, int n) { return p->a[n]; }
int lx(struct S *p) { return p->x + p->y; }
int lk(struct N *p) { return p->in.k; }
void sh(struct S *p, int v) { p->h = v; }
void si(struct S *p, int v) { p->i = v; }
void sl(struct S *p, long long v) { p->l = v; }
void sf(struct S *p, float v) { p->f = v; }
void sd(struct S *p, double v) { p->d = v; }
void sp(struct S *p, void *v) { p->p = v; }
void sa(struct S *p, int n, int v) { p->a[n] = v; }
void sx(struct S *p, int v) { p->x = v; p->y = v; }
void sk(struct N *p, int v) { p->in.k = v; }
void cp(struct S *a, struct S *b) { *a = *b; }
#ifdef STRICT
void mc(char *a, char *b) { __builtin_memcpy(a, b, 16); }
#endif
void in(struct S *p) { p->i++; p->l += 3; p->h ^= 5; }
