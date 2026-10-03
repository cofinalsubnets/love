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

// n words off the top of the first block that holds them, NULL when none does. a block with
// no room left for a header of its own after the carve goes whole, so a freed block is taken
// back at its own size
static love_inline void *ff_alloc(struct mem **fl, uintptr_t n) {
  if (!n) return NULL;
  void *p = NULL;
  struct mem *r = NULL, *t;
  while (*fl && (*fl)->len < n + Width(struct mem))
    t = *fl,
    *fl = t->next,
    t->next = r,
    r = t;
  if (*fl && (*fl)->len < n + 2 * Width(struct mem))
    t = *fl,
    *fl = t->next,
    p = t->_;
  else if (*fl)
    (*fl)->len -= n + Width(struct mem),
    t = after(*fl),
    t->len = Width(struct mem) + n,
    p = t->_;
  while (r)
    t = r,
    r = t->next,
    t->next = *fl,
    *fl = t;
  return p; }

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
