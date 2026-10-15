// test/gate/ffalloc.c -- src/inle/ffalloc.h on the host, where a pool can be checked whole
// after every step: the free blocks and the allocated ones tile it exactly (so no word is
// lost to padding or held twice), the list runs in address order with no two blocks
// touching, every body sits on its alignment, an allocated block holds its body and at most
// one word more, small requests come off the bottom and big ones off the top, and freeing
// everything leaves the pool one block again. seeded, so a red names a step that repeats.
#include "ffalloc.h"

#include <stdio.h>
#include <stdlib.h>

#define pool_words ((uintptr_t) 3 << 20)          // 24 MiB: room for a few ff_big blocks
#define live_most 512

struct live { uintptr_t *p, n, a; };
struct span { uintptr_t lo, hi; int free; };

static uint64_t rnd(uint64_t *s) {
  *s ^= *s << 13, *s ^= *s >> 7, *s ^= *s << 17;
  return *s; }

static int span_cmp(void const *x, void const *y) {
  struct span const *a = x, *b = y;
  return a->lo < b->lo ? -1 : a->lo > b->lo; }

// every check on the pool as it stands -> 0, or a message
static char const *check(struct mem *fl, uintptr_t *base, struct live *lv, int nl, struct span *sp) {
  uintptr_t const lo = (uintptr_t) base, hi = (uintptr_t) (base + pool_words);
  int ns = 0;
  for (struct mem *m = fl; m; m = m->next) {
    if ((uintptr_t) m < lo || (uintptr_t) after(m) > hi) return "a free block outside the pool";
    if (m->len < Width(struct mem)) return "a free block shorter than its header";
    if (m->next && after(m) >= m->next) return "the list out of address order, or two blocks touching";
    sp[ns++] = (struct span) { (uintptr_t) m, (uintptr_t) after(m), 1 }; }
  for (int i = 0; i < nl; i++) {
    struct mem *h = (struct mem*) (lv[i].p - 1);
    if ((uintptr_t) lv[i].p % lv[i].a) return "a body off its alignment";
    if (h->len < lv[i].n + 1 || h->len > lv[i].n + 2) return "an allocated block padded past one word";
    sp[ns++] = (struct span) { (uintptr_t) h, (uintptr_t) after(h), 0 }; }
  qsort(sp, (size_t) ns, sizeof *sp, span_cmp);
  uintptr_t at = lo;
  for (int i = 0; i < ns; i++) {
    if (sp[i].lo != at) return sp[i].lo < at ? "two blocks overlap" : "words held by no block";
    at = sp[i].hi; }
  return at == hi ? NULL : "the pool's top held by no block"; }

int main(void) {
  // the pool starts one word past a page, so every alignment above a word leaves a gap
  uintptr_t *raw = aligned_alloc(4096, (pool_words + 512) * sizeof(uintptr_t)), *base = raw + 1;
  struct live *lv = malloc(live_most * sizeof *lv);
  struct span *sp = malloc((2 * live_most + 2) * sizeof *sp);
  if (!raw || !lv || !sp) return puts("FAIL test_ffalloc: no host memory"), 1;
  struct mem *fl = (struct mem*) base;
  fl->len = pool_words, fl->next = NULL;
  int nl = 0, fails = 0;
  char const *why;

  // the shapes, each on a fresh pool: a small block from the bottom, a big one from the top,
  // a page-aligned one with its gap below given back
  uintptr_t *s = ff_alloc(&fl, 10);
  if (s != base + 1) printf("FAIL test_ffalloc: a small block not at the pool's bottom\n"), fails++;
  uintptr_t *b = ff_alloc(&fl, ff_big);
  if (!b || b + ff_big != base + pool_words) printf("FAIL test_ffalloc: a big block not at the pool's top\n"), fails++;
  uintptr_t *pg = ff_alloc_aligned(&fl, 1024, 4096);
  if (!pg || (uintptr_t) pg % 4096 || (uintptr_t) (pg - base) > 4096 / sizeof(uintptr_t) + 2)
    printf("FAIL test_ffalloc: a page-aligned block not at the lowest page that holds it\n"), fails++;
  if (s) lv[nl++] = (struct live) { s, 10, sizeof(uintptr_t) };
  if (b) lv[nl++] = (struct live) { b, ff_big, sizeof(uintptr_t) };
  if (pg) lv[nl++] = (struct live) { pg, 1024, 4096 };
  if ((why = check(fl, base, lv, nl, sp))) printf("FAIL test_ffalloc: the shapes: %s\n", why), fails++;

  // churn: allocations of every size and alignment, frees in any order
  uint64_t seed = 0x9e3779b97f4a7c15ull;
  int steps = 60000;
  for (int i = 0; i < steps && !fails; i++) {
    uint64_t r = rnd(&seed);
    if (nl && (nl == live_most || r % 100 < 45)) {
      int k = (int) (rnd(&seed) % (uint64_t) nl);
      ff_free(&fl, lv[k].p);
      lv[k] = lv[--nl]; }
    else {
      uint64_t c = rnd(&seed) % 1000;
      uintptr_t n = c < 2 ? ff_big + rnd(&seed) % 4096
                  : c < 100 ? 1 + rnd(&seed) % 65536
                  : 1 + rnd(&seed) % 64;
      uintptr_t a = (uintptr_t) sizeof(uintptr_t) << (rnd(&seed) % 4 ? 0 : rnd(&seed) % 10);
      uintptr_t *p = ff_alloc_aligned(&fl, n, a);
      if (p) lv[nl++] = (struct live) { p, n, a }; }
    if ((why = check(fl, base, lv, nl, sp))) printf("FAIL test_ffalloc: step %d: %s\n", i, why), fails++; }

  if (fails) return 1;                             // a broken list is no place to free into
  while (nl) ff_free(&fl, lv[--nl].p);
  if (fl != (struct mem*) base || fl->len != pool_words || fl->next)
    return puts("FAIL test_ffalloc: everything freed and the pool is not one block"), 1;
  printf("test_ffalloc: %d steps, the pool tiled exactly after each; freed, one block again\n", steps);
  return 0; }
