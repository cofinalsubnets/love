#include "../impl.h"

/* a big block gets its own mapping, handed back whole. an allocated block's `next' is
 * a tag, written on every block */
#define MBig ((size_t) 128 * 1024)

static __mhdr __mbase;
static __mhdr *__mfree;
/* thread state lives here so a link that allocates never pulls in pthread.o */
struct __love_mt __love_mt;
static void __mtake(void) { if (__love_mt.threads) while (__sync_lock_test_and_set(&__love_mt.lock, 1)) sc0(NR_sched_yield); }
static void __mgive(void) { if (__love_mt.threads) __sync_lock_release(&__love_mt.lock); }
/* a small block is a slot in a 64 KiB slab of its size class, a bit per slot held. a
 * slot's header is tagged __MSlot, its size the units | index << 16 */
#define SlabU (65536 / sizeof(__mhdr))
#define NCls 24
static unsigned char const __mcls[NCls] = {2, 3, 4, 5, 6, 7, 8, 10, 12, 14, 16, 20, 24, 28, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160};
typedef struct __mslab { struct __mslab *next, *prev; unsigned cls, n, used, at; unsigned map[SlabU / 64 + 1]; } __mslab;
#define SlabH ((sizeof(__mslab) + sizeof(__mhdr) - 1) / sizeof(__mhdr))   /* the slab's own units */
#define NMap (sizeof ((__mslab *) 0)->map / sizeof(unsigned))
static __mslab *__mslabs[NCls];                       /* each class's slabs with a slot free */
static __mslab *__mslabof(__mhdr *b) { return (__mslab *) (b - (b->size >> 16) * (b->size & 0xffff) - SlabH); }
static int __mheld(__mhdr *b) {                       /* a slot its slab holds, by the slab's own record */
  __mslab *s = __mslabof(b);
  unsigned i = (unsigned) (b->size >> 16);
  __mhdr *h = (__mhdr *) s - 1;
  return h->next == __MLive && h->size == SlabU && s->cls < NCls && __mcls[s->cls] == (b->size & 0xffff)
      && i < s->n && s->map[i / 32] >> (i % 32) & 1; }
static void __mlink(__mslab *s) {
  s->prev = 0, s->next = __mslabs[s->cls];
  if (s->next) s->next->prev = s;
  __mslabs[s->cls] = s; }
static void __munlink(__mslab *s) {
  if (s->prev) s->prev->next = s->next; else __mslabs[s->cls] = s->next;
  if (s->next) s->next->prev = s->prev;
  s->next = s->prev = 0; }
/* a pointer never handed out, or freed already, reads as no tag and aborts */
__mhdr *__mblock(void *p, char const *who) {
  __mhdr *b = (__mhdr *) p - 1;
  if (b->next == __MAlign) b = (__mhdr *) p - b->size - 1;
  if (!(b->next == __MLive || b->next == __MDirect || (b->next == __MSlot && __mheld(b)))) {
    write(2, "moonlibc: ", 10), write(2, who, (long) strlen(who));
    write(2, ": not a live block (freed already, or never malloc's)\n", 54);
    abort(); }
  return b; }
/* an arena is [header, span, sentinel], so a span filling its arena is the arena empty;
 * one empty arena is kept, the rest unmapped */
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
/* grow b in place into the free block after it */
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
static void __mrelease(__mhdr *b) {                    /* an arena block back, lock held */
  __mput(b);
  __mhdr *f = __mfree < b && b < __mfree + __mfree->size ? __mfree : b, *h = __mwhole(f);   /* b's span now */
  if (h) __mtrim(f, h); }
static void __mslotfree(__mhdr *b) {                   /* lock held */
  __mslab *s = __mslabof(b);
  unsigned i = (unsigned) (b->size >> 16);
  s->map[i / 32] &= ~(1u << (i % 32));
  if (s->used-- == s->n) __mlink(s);
  if (!s->used) { __munlink(s); __mrelease((__mhdr *) s - 1); } }
void free(void *p) {
  if (!p) return;
  __mhdr *b = __mblock(p, "free");
  if (b->next == __MDirect) { munmap(b, (long) (b->size * sizeof(__mhdr))); return; }
  __mtake();
  if (b->next == __MSlot) __mslotfree(b); else __mrelease(b);
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
static void *__mslot(unsigned c) {                     /* lock held */
  __mslab *s = __mslabs[c];
  unsigned u = __mcls[c];
  if (!s) {
    if (!(s = __marena(SlabU))) return 0;
    s->cls = c, s->n = (unsigned) ((SlabU - 1 - SlabH) / u), s->used = 0, s->at = 0;
    for (unsigned w = 0; w < NMap; w++)                /* the bits past the last slot read as held */
      s->map[w] = w * 32 + 32 <= s->n ? 0 : w * 32 >= s->n ? ~0u : ~0u << (s->n % 32);
    __mlink(s); }
  unsigned w = s->at;
  while (s->map[w] == ~0u) w = w + 1 == NMap ? 0 : w + 1;
  unsigned i = w * 32 + (unsigned) __builtin_ctz(~s->map[w]);
  s->map[w] |= 1u << (i % 32), s->at = w;
  if (++s->used == s->n) __munlink(s);
  __mhdr *b = (__mhdr *) s + SlabH + (size_t) i * u;
  b->next = __MSlot, b->size = u | (size_t) i << 16;
  return (void *) (b + 1); }
void *malloc(size_t n) {
  /* past PTRDIFF_MAX the rounding below wraps */
  if (n > ((size_t) -1 >> 1) - 65536) { __errno_v = ENOMEM; return 0; }
  size_t nu = (n + sizeof(__mhdr) - 1) / sizeof(__mhdr) + 1;
  if (n >= MBig) return __mbig(nu);
  __mtake();
  void *p;
  if (nu <= 160) { unsigned c = 0; while (__mcls[c] < nu) c++; p = __mslot(c); }
  else p = __marena(nu);
  __mgive();
  return p; }
