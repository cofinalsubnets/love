/* a block-scope static's initializer names statics by address -- itself (the kernel's
   static DEFINE_MUTEX: a list head pointing at itself beside a spinlock compound literal)
   and one declared before it -- and a scalar compound literal stands as a static's value,
   and at file scope behind an address. the answer is the exit status: no libc, so the
   bare-metal lanes run it too */

struct list_head { struct list_head *next, *prev; };
typedef struct { int counter; } atomic_t;
typedef struct qspinlock {
    union { atomic_t val; struct { unsigned char locked, pending; }; struct { unsigned short locked_pending, tail; }; };
} arch_spinlock_t;
typedef struct raw_spinlock { arch_spinlock_t raw_lock; } raw_spinlock_t;
struct mutex { atomic_t owner; raw_spinlock_t wait_lock; atomic_t osq; struct list_head wait_list; };
#define DEFINE_MUTEX(m) struct mutex m = { .owner = { 0 }, \
    .wait_lock = (raw_spinlock_t) { .raw_lock = { { .val = { 0 } } } }, \
    .wait_list = { &(m).wait_list, &(m).wait_list } }

static int one = (int){ 7 };                          /* a scalar literal as the value */
static int *two = &(int){ 9 };                        /* ..and behind an address */

__attribute__((noinline)) static struct mutex *lock(void) {
    static DEFINE_MUTEX(hotplug);
    return &hotplug;
}

__attribute__((noinline)) static int chain(void) {
    static int base = 40;
    static int *at = &base;                           /* a static declared before it */
    static struct { int *p; int k; } s = { .p = &base, .k = (int){ 3 } };
    return *at + *s.p + s.k;
}

int main(void) {
    struct mutex *m = lock();
    int ok = m->wait_list.next == &m->wait_list && m->wait_list.prev == &m->wait_list
          && m->wait_lock.raw_lock.val.counter == 0 && m->owner.counter == 0;
    return (!ok) | (lock() != m) << 1 | (chain() != 83) << 2 | (one != 7) << 3 | (*two != 9) << 4;
}
