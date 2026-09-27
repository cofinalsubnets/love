/* static initializers the kernel's lock and trace macros write, held to gcc: a compound literal
 * as the whole initializer (DEFINE_SPINLOCK) and as a member's (a mutex's wait_lock), braces
 * opening on an anonymous member -- a union of a struct and bytes (qspinlock's `{ { .val = ..
 * } }`) and a tracepoint event's `{ .tp = &x }` -- and an array member's element address
 * (srcu's `&data.ctrs[1]`). the same at block scope. */

typedef struct { int counter; } atomic_t;
typedef struct { long counter; } atomic_long_t;
typedef struct qspinlock {
  union { atomic_t val; struct { unsigned char locked, pending; }; };
} arch_spinlock_t;
typedef struct raw_spinlock { arch_spinlock_t raw_lock; } raw_spinlock_t;
typedef struct spinlock { union { struct raw_spinlock rlock; }; } spinlock_t;
struct mutex { atomic_long_t owner; raw_spinlock_t wait_lock; void *next; };
typedef struct {
  union { atomic_t cnts; struct { unsigned char wlocked; }; };
  arch_spinlock_t wait_lock;
} arch_rwlock_t;
typedef struct { arch_rwlock_t raw_lock; } rwlock_t;

spinlock_t sl = (spinlock_t){ { .rlock = { .raw_lock = { { .val = { (2) } } } } } };
struct mutex sm = { .owner = { (0) }, .wait_lock = (raw_spinlock_t){ .raw_lock = { { .val = { (3) } } } }, .next = &sm };
rwlock_t rl = (rwlock_t){ .raw_lock = { { .cnts = { 5 } }, .wait_lock = { { .val = { (6) } } } } };

struct cls { int a; };
struct tp { int b; };
struct funcs { int c; };
struct ev { struct funcs *funcs; int t; };
struct call {
  void *list;
  struct cls *class;
  union { const char *name; struct tp *tp; };
  struct ev event;
  char *print_fmt;
  int flags;
};
struct cls ec = {1};
struct tp tpx = {2};
struct funcs fx = {3};
static const char pf[] = "fmt";
struct call ev1 = { .class = &ec, { .tp = &tpx }, .event.funcs = &fx, .print_fmt = (char *)pf, .flags = 8 };

struct data { long pad; long ctrs[2]; };
struct data sd;
struct srcu { struct data *sda; long *ctrp; };
struct srcu sr = { .sda = &sd, .ctrp = &sd.ctrs[1] };

int main(void) {
  int bad = 0;
  if (sl.rlock.raw_lock.val.counter != 2) bad |= 1;
  if (sm.wait_lock.raw_lock.val.counter != 3 || sm.next != &sm) bad |= 2;
  if (rl.raw_lock.cnts.counter != 5 || rl.raw_lock.wait_lock.val.counter != 6) bad |= 4;
  if (ev1.class != &ec || ev1.tp != &tpx || ev1.event.funcs != &fx || ev1.print_fmt[0] != 'f' || ev1.flags != 8) bad |= 8;
  if (sr.sda != &sd || sr.ctrp != &sd.ctrs[1]) bad |= 16;
  struct mutex lm = { .wait_lock = (raw_spinlock_t){ .raw_lock = { { .val = { (7) } } } }, .next = &lm };
  static rwlock_t srl = (rwlock_t){ .raw_lock = { { .cnts = { 9 } } } };
  if (lm.wait_lock.raw_lock.val.counter != 7 || lm.next != &lm || srl.raw_lock.cnts.counter != 9) bad |= 32;
  return bad;
}
