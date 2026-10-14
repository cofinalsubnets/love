/* an always_inline callee whose returns sit inside a switch splices on the jump lane, and a for
 * step that calls one is the body's last statement; a cleanup runs at the loop's end. held to gcc. */

enum st { st_done, st_lock, st_less };
struct tmp { enum st state; int tries; int *lock; };

static int locks, unlocks, trips, bugs;
static __attribute__((noinline)) void lk(int *l) { locks += *l; }
static __attribute__((noinline)) void ulk(int *l) { unlocks += *l; }
static __attribute__((noinline)) int retry(int n) { return n < 3; }

static inline __attribute__((always_inline)) void cln(struct tmp *s) { if (s->lock) ulk(s->lock); }
static inline __attribute__((always_inline)) void nxt(struct tmp *s, int *l) {
  switch (s->state) {
  case st_done: bugs++; return;
  case st_lock: s->state = st_done; return;
  case st_less: if (!retry(s->tries++)) { s->state = st_done; return; } break;
  }
  if (s->tries > 1) { s->lock = l; lk(l); s->state = st_lock; return; }
}
static inline __attribute__((always_inline)) int pick(int x) {
  switch (x & 3) {
  case 0: return 10;
  case 1: if (x > 8) return 20; break;
  case 2: return x;
  }
  return 1;
}

static __attribute__((noinline)) void loop(int *l) {
  for (struct tmp s __attribute__((cleanup(cln))) = { .state = st_less };
       s.state != st_done; nxt(&s, l))
    trips++;
}

int main(void) {
  int l = 5, sum = 0;
  loop(&l);
  for (int i = 0; i < 12; sum += pick(i++)) ;
  return trips + 10 * locks + unlocks + 100 * bugs + sum;
}
