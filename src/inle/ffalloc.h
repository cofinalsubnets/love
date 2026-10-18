// ffalloc.h -- the first-fit free list for the kernel and the boards: address order so a free
// coalesces; lengths in words, header included
#pragma once
#include "../love/love.h"

// a free block. an allocated one keeps len alone, its body starting where next sits
struct mem {
  uintptr_t len;
  struct mem *next; };

static love_inline struct mem *after(struct mem *r) {
  return (struct mem*) ((uintptr_t*) r + r->len); }

static love_inline void *ff_body(struct mem *m) { return &m->next; }

// this big or more comes off the top of the highest fit, less off the bottom of the lowest:
// small long-lived blocks pile up low, the high end stays whole for the heap's pools
#define ff_big ((uintptr_t) (4u << 20) / sizeof(uintptr_t))

// the header of an n-word body aligned to a in t, 0 if none fits; a gap below is a block, never one word
static love_inline uintptr_t ff_fit(struct mem *t, uintptr_t n, uintptr_t a, bool top) {
  uintptr_t const W = sizeof(uintptr_t), lo = (uintptr_t) t, hi = (uintptr_t) after(t);
  uintptr_t h;
  if (top) {
    if (hi - lo < (n + 1) * W) return 0;
    h = ((hi - n * W) & ~(a - 1)) - W;
    if (h - lo == W) h = a == W ? lo : h - a; }
  else {
    h = ((lo + W + a - 1) & ~(a - 1)) - W;
    if (h - lo == W) h += a; }
  return h >= lo && h <= hi && (hi - h) / W >= n + 1 ? h : 0; }

// carve h out of *b: the gap below stays as *b, the rest above follows it unless one word
static love_inline void *ff_carve(struct mem **b, uintptr_t h, uintptr_t n) {
  struct mem *t = *b, *nx = t->next, *u = (struct mem*) h;
  uintptr_t const hi = (uintptr_t) after(t), W = sizeof(uintptr_t);
  uintptr_t w = n + 1, rest = (hi - h) / W - w;
  if (rest < Width(struct mem)) w += rest, rest = 0;
  if (rest) {
    struct mem *f = (struct mem*) ((uintptr_t*) u + w);
    f->len = rest, f->next = nx, nx = f; }
  if (u == t) *b = nx;
  else t->len = (h - (uintptr_t) t) / W, t->next = nx;
  u->len = w;
  return ff_body(u); }

// a: a power of two, a word or more; the gap below goes back to the list, never padded
static love_inline void *ff_alloc_aligned(struct mem **fl, uintptr_t n, uintptr_t a) {
  if (!n) return NULL;
  bool const top = n >= ff_big;
  struct mem **b = NULL;
  uintptr_t h = 0;
  for (struct mem **q = fl; *q; q = &(*q)->next) {
    uintptr_t x = ff_fit(*q, n, a, top);
    if (x) { b = q, h = x; if (!top) break; } }
  return b ? ff_carve(b, h, n) : NULL; }

static love_inline void *ff_alloc(struct mem **fl, uintptr_t n) {
  return ff_alloc_aligned(fl, n, sizeof(uintptr_t)); }

static love_inline void ff_free(struct mem **fl, void *p) {
  if (!p) return;
  struct mem *m = (struct mem*) ((uintptr_t*) p - 1), *r = NULL, *t;
  while (*fl && *fl < m)
    t = *fl,
    *fl = t->next,
    t->next = r,
    r = t;
  for (;; m = r, r = r->next) {
    if (*fl != after(m)) m->next = *fl;
    else m->len += (*fl)->len,
         m->next = (*fl)->next;
    *fl = m;
    if (!r) return; } }
