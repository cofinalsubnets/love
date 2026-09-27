/* gcc's __attribute__((cleanup(f))), held to gcc: f(&v) runs on every way out of v's
 * scope -- the block's end, return (after the value is taken), break and continue,
 * a goto to a label outside, an asm goto -- innermost and newest first. linux's guard()
 * and scoped_guard() are these shapes. a log of calls is the answer. */

static int log_[64], nl;
static void note(int *p) { if (nl < 64) log_[nl++] = *p; }
#define CL __attribute__((cleanup(note)))

static int same(const int *want, int n) {
  int i;
  if (nl != n) return 0;
  for (i = 0; i < n; i++) if (log_[i] != want[i]) return 0;
  return 1;
}

static void order(void) { int a CL = 1; { int b CL = 2; int c CL = 3; (void)b; (void)c; } (void)a; }

static int ret(int x) {
  int v CL = 10;
  if (x) { int w CL = 20; (void)w; return v + x; }
  v = 11;
  return v;
}

static void loops(void) {
  int i;
  for (i = 0; i < 4; i++) {
    int k CL = 100 + i;
    if (i == 1) continue;
    if (i == 2) break;
    (void)k;
  }
  while (1) { int w CL = 200; (void)w; break; }
}

struct lock { int held; };
static void unlock(struct lock **l) { (*l)->held--; note(&(*l)->held); }
static struct lock *lock(struct lock *l) { l->held++; return l; }
#define scoped(l) for (struct lock *_g __attribute__((cleanup(unlock))) = lock(l), *_d = 0; !_d; _d = (void *)1)

static int guarded(struct lock *l, int stop) {
  int i, n = 0;
  scoped(l) { n = l->held; }
  for (i = 0; i < 3; i++) {
    scoped(l) {
      if (i == stop) break;
      n += l->held;
    }
  }
  return n;
}

static int jumps(int x) {
  int r = 0;
  {
    int a CL = 7;
    if (x) goto out;
    r = a - 7;
  }
again:
  {
    int b CL = 8;
    r++;
    if (r < 3) goto again;
    (void)b;
  }
out:
  return r;
}

static int sw(int x) {
  switch (x) {
  case 1: { int s CL = 31; (void)s; break; }
  case 2: { int s CL = 32; (void)s; return 2; }
  default: break;
  }
  return 0;
}

static int sx(void) {
  int r = ({ int t CL = 41; t + 1; });
  return r;
}

static void freeit(int **p) { if (*p) { note(*p); } }
static int keep(void) {
  static int box = 55, box2 = 56;
  int *p __attribute__((cleanup(freeit))) = &box;
  int *q __attribute__((cleanup(freeit))) = &box2;
  int *out = ({ int *t = q; q = 0; t; });      /* no_free_ptr */
  (void)p;
  return *out;
}

#if defined(__x86_64__)
#define JUMP "jmp %l0"
#elif defined(__aarch64__)
#define JUMP "b %l0"
#elif defined(__riscv)
#define JUMP "j %l0"
#endif
static int agoto(void) {
  {
    int a CL = 61;
#ifdef JUMP
    asm goto(JUMP : : : : out);
#else
    goto out;
#endif
    (void)a;
    return 0;
  }
out:
  return 1;
}

int main(void) {
  int bad = 0;
  struct lock l = { 0 };

  nl = 0; order();
  { static const int w[] = { 3, 2, 1 }; if (!same(w, 3)) bad |= 1; }
  nl = 0;
  if (ret(5) != 15) bad |= 2;
  { static const int w[] = { 20, 10 }; if (!same(w, 2)) bad |= 2; }
  nl = 0;
  if (ret(0) != 11) bad |= 4;
  { static const int w[] = { 11 }; if (!same(w, 1)) bad |= 4; }
  nl = 0; loops();
  { static const int w[] = { 100, 101, 102, 200 }; if (!same(w, 4)) bad |= 8; }
  nl = 0;
  if (guarded(&l, 1) != 3 || l.held != 0) bad |= 16;     /* the break leaves scoped()'s own for */
  { static const int w[] = { 0, 0, 0, 0 }; if (!same(w, 4)) bad |= 16; }
  nl = 0;
  if (jumps(1) != 0) bad |= 32;
  { static const int w[] = { 7 }; if (!same(w, 1)) bad |= 32; }
  nl = 0;
  if (jumps(0) != 3) bad |= 64;
  { static const int w[] = { 7, 8, 8, 8 }; if (!same(w, 4)) bad |= 64; }
  nl = 0;
  if (sw(1) != 0 || sw(2) != 2 || sw(3) != 0) bad |= 128;
  { static const int w[] = { 31, 32 }; if (!same(w, 2)) bad |= 128; }
  nl = 0;
  if (sx() != 42) bad |= 256;
  { static const int w[] = { 41 }; if (!same(w, 1)) bad |= 256; }
  nl = 0;
  if (keep() != 56) bad |= 512;
  { static const int w[] = { 55 }; if (!same(w, 1)) bad |= 512; }
  nl = 0;
  if (agoto() != 1) bad |= 1024;
  { static const int w[] = { 61 }; if (!same(w, 1)) bad |= 1024; }
  return bad;
}
