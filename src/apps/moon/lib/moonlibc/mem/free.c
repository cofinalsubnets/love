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
/* the process's thread state, the one place threads keep any: whether a second thread exists
 * (pthread_create sets it, nothing clears it) and the arena lock that switches on with it. here
 * rather than beside pthread_create so a link that allocates never pulls the thread member */
struct __love_mt __love_mt;
static void __mtake(void) { if (__love_mt.threads) while (__sync_lock_test_and_set(&__love_mt.lock, 1)) sc0(NR_sched_yield); }
static void __mgive(void) { if (__love_mt.threads) __sync_lock_release(&__love_mt.lock); }
/* an allocated block's `next' is a tag (impl.h), never a list pointer, and the free list
   writes a pointer there; so a word free never handed out, or a block freed already, reads
   as neither tag and aborts -- a corrupted list is worse than a crash */
__mhdr *__mblock(void *p, char const *who) {
  __mhdr *b = (__mhdr *) p - 1;
  if (b->next == __MAlign) b = (__mhdr *) p - b->size - 1;
  if (b->next != __MLive && b->next != __MDirect) {
    write(2, "moonlibc: ", 10), write(2, who, (long) strlen(who));
    write(2, ": not a live block (freed already, or never malloc's)\n", 54);
    abort(); }
  return b; }
/* an arena is laid [header, its span, sentinel]: the sentinel stops a free span coalescing
   into the next arena, so a span that fills its arena whole is the arena empty again, and
   its pages go back -- but one empty arena is kept, so a program that churns does not map
   and unmap the same megabyte */
static __mhdr *__mspare;
static __mhdr *__mwhole(__mhdr *f) {                    /* f a whole arena's span: its header */
  __mhdr *h = f - 1, *e = f + f->size;
  return h->next == __MArena && h->size == f->size + 2 && e->next == __MLive && e->size == 1 ? h : 0; }
static void __mtrim(__mhdr *f, __mhdr *h) {             /* lock held */
  if (!__mspare || __mspare == h || !__mwhole(__mspare + 1)) { __mspare = h; return; }
  __mhdr *p = __mfree;
  while (p->next != f) p = p->next;
  p->next = f->next, __mfree = p;
  munmap(h, (long) (h->size * sizeof(__mhdr))); }
static void __mput(__mhdr *b) {                        /* the arena's own free, lock held */
  __mhdr *q = __mfree;
  for (; !(b > q && b < q->next); q = q->next)
    if (q >= q->next && (b > q || b < q->next)) break;   /* at the arena's wrap point */
  if (b + b->size == q->next) { b->size += q->next->size; b->next = q->next->next; }
  else b->next = q->next;
  if (q + q->size == b) { q->size += b->size; q->next = b->next; }
  else q->next = b;
  __mfree = q; }
/* the free block right after b, when there is one and it holds the rest, joins b -- split
   when it holds more. love's strings grow their buffers a great deal */
int __mgrow(__mhdr *b, size_t nu) {
  int ok = 0;
  __mtake();
  __mhdr *prev = __mfree, *nb = b + b->size;
  if (prev)
    for (__mhdr *q = prev->next; ; prev = q, q = q->next) {
      if (q == nb) {
        size_t need = nu - b->size;
        if (q->size >= need) {
          if (q->size == need) prev->next = q->next;
          else { __mhdr *r = q + need; r->size = q->size - need; r->next = q->next; prev->next = r; }
          b->size = nu, __mfree = prev, ok = 1; }
        break; }
      if (q == __mfree) break; }
  __mgive();
  return ok; }
void free(void *p) {
  if (!p) return;
  __mhdr *b = __mblock(p, "free");
  if (b->next == __MDirect) { munmap(b, (long) (b->size * sizeof(__mhdr))); return; }
  __mtake();
  __mput(b);
  __mhdr *f = __mfree < b && b < __mfree + __mfree->size ? __mfree : b, *h = __mwhole(f);   /* b's span now */
  if (h) __mtrim(f, h);
  __mgive(); }
static __mhdr *__mcore(size_t nu) {
  size_t need = (nu + 2) * sizeof(__mhdr);
  size_t len = need < (1UL << 20) ? (1UL << 20) : ((need + 4095UL) & ~4095UL);
  void *m = mmap(0, (long) len, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
  if (m == (void *) -1) return 0;
  __mhdr *h = m, *u = h + 1, *e = h + len / sizeof(__mhdr) - 1;
  h->next = __MArena, h->size = len / sizeof(__mhdr);
  e->next = __MLive, e->size = 1;
  u->size = h->size - 2;
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
      q->next = __MLive;                                /* the tag, written before any payload can */
      return (void *) (q + 1); }
    if (q == __mfree)
      if (!(q = __mcore(nu))) { __errno_v = ENOMEM; return 0; } } }
void *malloc(size_t n) {
  /* no object passes PTRDIFF_MAX, and past it the units and the page rounding below wrap
     to a small block handed back as the large one asked for */
  if (n > ((size_t) -1 >> 1) - 65536) { __errno_v = ENOMEM; return 0; }
  size_t nu = (n + sizeof(__mhdr) - 1) / sizeof(__mhdr) + 1;
  if (n >= MBig) return __mbig(nu);
  __mtake();
  void *p = __marena(nu);
  __mgive();
  return p; }
