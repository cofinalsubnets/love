/* a call to a function whose body is empty, alone as an if's arm: the inliner lays only its
 * parameters, which must stay a block (an arm takes no declaration), and a parameter that
 * propagates away leaves no empty declaration behind. the kernel's disabled tracepoint and
 * userfaultfd stubs are the shape. arguments still evaluate, side effects and all. held to gcc. */

struct s { int a; long b; };

static inline void hook(struct s *p, int v, int ret) { }
static inline void none(int v) { }
static inline void two(long from, long to) { }

static int dec(struct s *p) {
  int ret = --p->a == 0;
  if (0)
    hook(p, -1, ret);
  return ret;
}

static int arms(struct s *p, int c) {
  if (c) none(p->a); else two(p->b, p->b + 1);
  if (c > 1) none(p->a++);
  return p->a;
}

int main(void) {
  int bad = 0;
  struct s x = { 2, 7 };
  if (dec(&x) != 0 || dec(&x) != 1 || x.a != 0) bad |= 1;
  x.a = 5;
  if (arms(&x, 0) != 5 || arms(&x, 1) != 5 || arms(&x, 2) != 6) bad |= 2;
  return bad;
}
