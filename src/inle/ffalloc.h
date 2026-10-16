// ffalloc.h -- the first-fit free list, one copy for the kernel and the boards. the list
// is kept in address order so a free coalesces with its neighbour; lengths are in words,
// header included. each seat owns its root and the region it feeds it.
#pragma once
#include "../love/love.h"

// a free block. an allocated one keeps len alone, its body starting where next sits
struct mem {
  uintptr_t len;
  struct mem *next; };

static love_inline struct mem *after(struct mem *r) {
  return (struct mem*) ((uintptr_t*) r + r->len); }

static love_inline void *ff_body(struct mem *m) { return &m->next; }

// a request this big comes off the top of the highest block that holds it, anything less off
// the bottom of the lowest: long-lived small blocks (files, tables, malloc's arenas) pile up
// low and the high end stays whole for the heap's pools
#define ff_big ((uintptr_t) (4u << 20) / sizeof(uintptr_t))

// where in t a body of n words aligned to a bytes starts its block -> that header; 0 when it
// does not fit. a gap left below is a block of its own, so never a single word
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

// carve the block at h out of *b, n words of body: the gap below stays on the list as *b,
// what is left above as the block after it, or goes with the carve when it would be one word
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

// n words whose body is aligned to a bytes (a power of two, a word or more), NULL when no
// block holds them. the fit is the same as ff_alloc's, the gap below the aligned start
// handed back to the list rather than padded over
static love_inline void *ff_alloc_aligned(struct mem **fl, uintptr_t n, uintptr_t a) {
  if (!n) return NULL;
  bool const top = n >= ff_big;
  struct mem **b = NULL;
  uintptr_t h = 0;
  for (struct mem **q = fl; *q; q = &(*q)->next) {
    uintptr_t x = ff_fit(*q, n, a, top);
    if (x) { b = q, h = x; if (!top) break; } }
  return b ? ff_carve(b, h, n) : NULL; }

// n words, NULL when no block holds them
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
