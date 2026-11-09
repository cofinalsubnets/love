// a local struct that starts as a copy from memory answers as the copy did, whatever then
// happens to the memory, and its source is named once
struct h { unsigned char s, n; };
struct w { short a; int b; long long c; float f; char *p; };
struct o { int k; struct h in; };
static struct h tab[4] = { { 1, 2 }, { 3, 4 }, { 5, 6 }, { 7, 8 } };
static int calls;
static int nx(void) { return calls++; }

static int idx(int i) { struct h e = tab[i]; return e.s * 10 + e.n; }
static int after(struct h *t) { struct h e = *t; t->s = 90; t->n = 91; return e.s + e.n * 100; }
static int once(void) { struct h e = tab[nx()]; return e.s + e.n; }
static int post(struct h **pp) { struct h e = *(*pp)++; return e.n; }
static int member(struct o *q) { struct h e = q->in; q->in.n = 0; return e.n; }
static int wide(struct w *q) { struct w e = *q; q->c = 0; q->f = 0; return (int) e.a + e.b + (int) e.c + (int) e.f + (e.p == 0); }
static int written(struct h *t) { struct h e = *t; e.s += 5; e.n = e.s + t->n; return e.s + e.n; }
static int loop(struct h *t, int n) { int r = 0; for (int i = 0; i < n; i++) { struct h e = t[i]; t[i].s = 0; r += e.s + e.n; } return r; }
static int taken(struct h *t) { struct h e = *t; struct h *q = &e; t->s = 0; return q->s; }

int main(void) {
 struct h u[2] = { { 11, 12 }, { 13, 14 } }, *m = u;
 struct o v = { 1, { 21, 22 } };
 struct w x = { -3, 40, 500, 6.5f, 0 };
 int t = idx(2) + after(&u[1]) + once() + once() + post(&m) + (m - u) + member(&v) + v.in.n + wide(&x) + (int) x.c;
 struct h y[3] = { { 1, 1 }, { 2, 2 }, { 3, 3 } };
 t += written(&y[1]) + loop(y, 3) + y[2].s + taken(&y[1]);
 return t % 251;
}
