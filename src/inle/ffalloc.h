// ffalloc.h -- the first-fit free list, one copy for the kernel and the boards. the list
// is kept in address order so a free coalesces with its neighbour; lengths are in words,
// header included. each seat owns its root and the region it feeds it.
#pragma once
#include "../love/love.h"

struct mem {
  struct mem *next;
  uintptr_t len;
  uintptr_t _[]; };

static love_inline struct mem *after(struct mem *r) {
  return (struct mem*) ((uintptr_t*) r + r->len); }

// a request this big comes off the top of the highest block that holds it, anything less off
// the bottom of the lowest: long-lived small blocks (files, tables, malloc's arenas) pile up
// low and the high end stays whole for the heap's pools
#define ff_big ((uintptr_t) (4u << 20) / sizeof(uintptr_t))

// n words, NULL when no block holds them. a block with no room left for a header of its own
// after the carve goes whole, so a freed block is taken back at its own size
static love_inline void *ff_alloc(struct mem **fl, uintptr_t n) {
  if (!n) return NULL;
  uintptr_t const w = n + Width(struct mem);
  struct mem **b = NULL;
  for (struct mem **q = fl; *q; q = &(*q)->next)
    if ((*q)->len >= w) { b = q; if (n < ff_big) break; }
  if (!b) return NULL;
  struct mem *t = *b;
  if (t->len < w + Width(struct mem)) return *b = t->next, t->_;
  if (n < ff_big) {                              // the bottom: the rest moves up past the carve
    struct mem *f = (struct mem*) ((uintptr_t*) t + w);
    f->len = t->len - w, f->next = t->next, *b = f;
    t->len = w;
    return t->_; }
  t->len -= w;                                   // the top
  struct mem *u = after(t);
  u->len = w;
  return u->_; }

static love_inline void ff_free(struct mem **fl, void *p) {
  if (!p) return;
  struct mem *m = (struct mem*)p - 1, *r = NULL, *t;
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
