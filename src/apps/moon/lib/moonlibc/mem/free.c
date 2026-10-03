#include "../impl.h"

/* a block worth its own mapping gets one, and free hands that back whole: the
   arena list below never returns a page, so a heap that peaks through a few
   large blocks would keep every one of them resident for the run. the tag
   rides `next', which an allocated block does not otherwise use -- so malloc
   writes it on EVERY block, or free reads whatever the old payload left there.
   __MDirect names it in impl.h, where calloc reads it too. */
#define MBig ((size_t) 128 * 1024)

static __mhdr __mbase;
static __mhdr *__mfree;
/* one lock over the arena, taken only once pthread_create has made a second thread */
int __ai_threads;
static int __mlock;
static void __mtake(void) { if (__ai_threads) while (__sync_lock_test_and_set(&__mlock, 1)) sc0(NR_sched_yield); }
static void __mgive(void) { if (__ai_threads) __sync_lock_release(&__mlock); }
static void __mput(__mhdr *b) {                        /* the arena's own free, lock held */
  __mhdr *q = __mfree;
  for (; !(b > q && b < q->next); q = q->next)
    if (q >= q->next && (b > q || b < q->next)) break;   /* at the arena's wrap point */
  if (b + b->size == q->next) { b->size += q->next->size; b->next = q->next->next; }
  else b->next = q->next;
  if (q + q->size == b) { q->size += b->size; q->next = b->next; }
  else q->next = b;
  __mfree = q; }
void free(void *p) {
  if (!p) return;
  __mhdr *b = (__mhdr *) p - 1;
  if (b->next == __MDirect) { munmap(b, (long) (b->size * sizeof(__mhdr))); return; }
  __mtake(); __mput(b); __mgive(); }
static __mhdr *__mcore(size_t nu) {
  size_t need = (nu + 1) * sizeof(__mhdr);
  size_t len = need < (1UL << 20) ? (1UL << 20) : ((need + 4095UL) & ~4095UL);
  void *m = mmap(0, (long) len, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
  if (m == (void *) -1) return 0;
  __mhdr *u = m;
  u->size = len / sizeof(__mhdr);
  u->next = 0;
  __mput(u);
  return __mfree; }
static void *__mbig(size_t nu) {                        /* its own mapping, given back whole */
  size_t len = (nu * sizeof(__mhdr) + 4095UL) & ~4095UL;
  void *m = mmap(0, (long) len, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
  if (m == (void *) -1) { __errno_v = ENOMEM; return 0; }
  __mhdr *u = m;
  u->size = len / sizeof(__mhdr);
  u->next = __MDirect;
  return (void *) (u + 1); }
static void *__marena(size_t nu) {
  __mhdr *prev = __mfree;
  if (!prev) { __mbase.next = __mfree = prev = &__mbase; __mbase.size = 0; }
  for (__mhdr *q = prev->next; ; prev = q, q = q->next) {
    if (q->size >= nu) {
      if (q->size == nu) prev->next = q->next;
      else { q->size -= nu; q += q->size; q->size = nu; }
      __mfree = prev;
      q->next = 0;                                      /* the tag, written before any payload can */
      return (void *) (q + 1); }
    if (q == __mfree)
      if (!(q = __mcore(nu))) { __errno_v = ENOMEM; return 0; } } }
void *malloc(size_t n) {
  size_t nu = (n + sizeof(__mhdr) - 1) / sizeof(__mhdr) + 1;
  if (n >= MBig) return __mbig(nu);
  __mtake();
  void *p = __marena(nu);
  __mgive();
  return p; }
