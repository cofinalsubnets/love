/* a test x != K holds where only the test leads, and a switch on x there never takes case K;
 * every way the fact ends (a write, a label, an address, a fallthrough) still answers. held to gcc. */

enum st { st_done, st_lock, st_less };
struct tmp { enum st state; int n; };
union uv { int i; char c[4]; };

static int hits;
static __attribute__((noinline)) int id(int x) { return x; }
static __attribute__((noinline)) void touch(struct tmp *s) { s->state = st_done; }

static __attribute__((noinline)) int step(int x) {
  struct tmp s = { .state = x };
  int r = 0;
  for (; s.state != st_done; s.n++) {
    switch (s.state) {
    case st_done: r += 1000; break;               /* never: the test excludes it */
    case st_lock: r += 1; s.state = st_done; break;
    case st_less: r += 10; if (s.n > 2) s.state = st_lock; break;
    }
  }
  return r;
}

static __attribute__((noinline)) int written(int x) {
  struct tmp s = { .state = id(st_lock) };
  int r = 0;
  if (s.state != st_done) {
    s.state = id(x);                              /* the member is written: the fact ends */
    switch (s.state) { case st_done: r += 7; break; default: r += 1; }
  }
  if (s.state != st_done) {
    s = (struct tmp) { .state = id(x) };          /* the whole struct is written */
    switch (s.state) { case st_done: r += 70; break; default: r += 2; }
  }
  return r;
}

static __attribute__((noinline)) int fall(int x) {
  int r = 0;
  if (x != 0) {
    switch (x) {
    case 2: r += 1;                               /* falls into case 0: kept */
    case 0: r += 5; break;
    case 3: r += 9;
    }
  }
  return r;
}

static __attribute__((noinline)) int label(int x) {
  int r = 0, k = 0;
  if (x != 1) {
  again:
    switch (x) { case 1: r += 100; break; default: r += 1; }
    if (k++ == 0) { x = 1; goto again; }          /* the label is reached with x == 1 */
  }
  return r;
}

static __attribute__((noinline)) int addr(int x) {
  struct tmp s = { .state = x };
  int r = 0;
  if (s.state != st_done) {
    touch(&s);                                    /* written through its address */
    switch (s.state) { case st_done: r += 3; break; default: r += 4; }
  }
  return r;
}

static __attribute__((noinline)) void put0(enum st *p) { *p = st_done; }
static __attribute__((noinline)) int maddr(int x) {
  struct tmp s = { .state = x };
  int r = 0;
  if (s.state != st_done) {
    put0(&s.state);                               /* one member's address escapes */
    switch (s.state) { case st_done: r += 11; break; default: r += 12; }
  }
  return r;
}

static __attribute__((noinline)) int narrow(int x) {
  int r = 0;
  if (x != 0) switch ((char) x) { case 0: r += 6; break; default: r += 1; }
  return r;
}

static __attribute__((noinline)) int arms(int x) {
  int r = 0;
  if (x == 2) r += 1;
  else switch (x) { case 2: r += 50; break; case 1: r += 2; break; default: r += 3; }
  while (x != 0) {
    switch (x) { case 0: r += 500; break; default: r += 4; }
    x = id(x - 1);
  }
  return r;
}

static __attribute__((noinline)) int un(int x) {
  union uv u = { .i = x };
  int r = 0;
  if (u.i != 0) {
    u.c[0] = 0; u.c[1] = 0; u.c[2] = 0; u.c[3] = 0;
    switch (u.i) { case 0: r += 8; break; default: r += 1; }
  }
  return r;
}

int main(void) {
  int r = step(st_less);                          /* 10 * 4 + 1 = 41 */
  r += written(st_done) + written(st_lock);       /* 7 + 1 + 2 = 10 */
  r += fall(2) + fall(3) + fall(0);               /* 6 + 9 + 0 = 15 */
  r += label(5);                                  /* 1 + 100 = 101 */
  r += addr(st_lock) + maddr(st_lock);            /* 3 + 11 = 14 */
  r += narrow(256) + narrow(3);                   /* 6 + 1 = 7 */
  r += arms(2) + arms(1) + arms(3);               /* 9 + 6 + 15 = 30 */
  r += un(5);                                     /* 8 */
  return (r + hits) % 256;                        /* 226 */
}
