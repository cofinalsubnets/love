// ushare.h -- a process's mappings, each a run of blocks laid past the last, and a fork's sharing
// of them till written: the same on each arch whose proc.c includes it. the includer gives
// struct k_uctx (nmm, cmm, mm, pid), k_pa, k_uwalk, k_uraw, k_umapb, k_uprot, k_usync, and k_epa,
// an entry's frame; an entry's other bits stay the includer's
#pragma once
#include <stdint.h>
#include <stdbool.h>

// a fork shares a mapping's block: n how many processes' entries point at each of its pages,
// live their sum, refs the mappings holding it. the block goes with its last page, this with
// its last mapping; u16 counts, so a page held past them is copied
struct k_ushare { void *raw; uint64_t live; uint32_t refs; uint16_t n[]; };
// a mapping's pages apart from its block, written from a shared page, a chunk at a time
struct k_uchunk { struct k_uchunk *next; void *raw; };
#define k_uchunks 32

// lo..hi, its block raw (sh's once a fork shares it), its own pages in cp
struct k_umm {
  uint64_t lo, hi;
  void *raw;
  struct k_ushare *sh;
  struct k_uchunk *cp;
  uint8_t *cnext;
  uint64_t cleft; };

// the mapping of c's holding va -> its index, or -1
static int k_umof(struct k_uctx const *c, uint64_t va) {
  for (int i = 0; i < c->nmm; i++)
    if (c->mm[i].lo <= va && va < c->mm[i].hi) return i;
  return -1; }

// e's page in m's block -> its index there; -1 for a page of its own, or a block gone
static long k_uinblk(struct k_umm const *m, uint64_t e) {
  void const *r = m->sh ? m->sh->raw : m->raw;
  if (!r) return -1;
  uint64_t pa = k_epa(e), lo = k_pa(r);
  return lo <= pa && pa < lo + (m->hi - m->lo) ? (long) ((pa - lo) >> 12) : -1; }

// is e's page in m's block held by another process too?
static bool k_uothers(struct k_umm const *m, uint64_t e) {
  long k = m->sh ? k_uinblk(m, e) : -1;
  return k >= 0 && m->sh->n[k] > 1; }

// a page of m's own, from its chunk -> it, unzeroed; NULL out of room
static uint8_t *k_upg(struct k_umm *m) {
  if (!m->cleft) {
    uint64_t n = (m->hi - m->lo) >> 12;
    n = n < k_uchunks ? n : k_uchunks;
    struct k_uchunk *k = k_grab(sizeof *k);
    if (!k) return NULL;
    if (!(k->raw = kmallocwa((uintptr_t) (n * 4096 / 8), 4096))) return k_drop(k), NULL;
    k->next = m->cp, m->cp = k, m->cnext = k->raw, m->cleft = n; }
  m->cleft--;
  return (m->cnext += 4096) - 4096; }

// m's block made shareable, a count of 1 on each page p's entry points at -> it; NULL out of room
static struct k_ushare *k_ushare(struct k_uctx const *p, struct k_umm const *m) {
  uint64_t np = (m->hi - m->lo) >> 12;
  struct k_ushare *s = k_grab(sizeof *s + np * sizeof *s->n);
  if (!s) return NULL;
  s->raw = m->raw, s->live = 0, s->refs = 1;
  for (uint64_t k = 0; k < np; k++) {
    uint64_t const *e = k_uwalk(p, m->lo + k * 4096);
    s->n[k] = e && *e & 1 && k_epa(*e) == k_pa((uint8_t*) m->raw + k * 4096);
    s->live += s->n[k]; }
  return s; }

// one process lets go of e's page of m: a shared block's count falls, the block going with its last
static void k_ulet(struct k_umm *m, uint64_t e) {
  long k;
  if (!m->sh || (k = k_uinblk(m, e)) < 0) return;
  m->sh->n[k]--;
  if (!--m->sh->live) kfree(m->sh->raw), m->sh->raw = NULL; }

// mapping m gone from one process, its entries let go: its own pages, then its block, unshared
// or with its last mapping
static void k_unmm(struct k_umm *m) {
  for (struct k_uchunk *k = m->cp, *x; k; k = x) x = k->next, kfree(k->raw), k_drop(k);
  if (!m->sh) kfree(m->raw);
  else if (!--m->sh->refs) kfree(m->sh->raw), k_drop(m->sh); }

// every mapping of c's gone, c's entries read before its tables go
static void k_unmms(struct k_uctx *c) {
  for (int i = 0; i < c->nmm; i++) {
    struct k_umm *m = &c->mm[i];
    for (uint64_t va = m->lo; m->sh && va < m->hi; va += 4096) {
      uint64_t const *e = k_uwalk(c, va);
      if (e && *e & 1) k_ulet(m, *e); }
    k_unmm(m); }
  k_drop(c->mm); }

// c's mapping of b bytes at lo for prot d, a piece at a time, each the most of the rest one
// block holds: the pages need not lie together, so a heap in pieces still answers. fd's bytes
// from g on, its offset kept, unless anon -> 0, or -errno, the pieces laid left for a munmap
static long k_umlay(struct k_uctx *c, uint64_t lo, uint64_t b, long d, bool anon, long fd, long g) {
  uint64_t const hi = lo + ((b + 4095) & ~4095ull);
  long at = anon ? 0 : k_proc_call(c->pid, NR_lseek, fd, 0, SEEK_CUR, 0, 0, 0), r = at;
  for (uint64_t va = lo, ask = hi - lo; r >= 0 && va < hi; ask = hi - va) {
    if (c->nmm == c->cmm) {
      int m = c->cmm ? 2 * c->cmm : 16;
      struct k_umm *t = k_grab((uintptr_t) m * sizeof *t);
      if (!t) { r = -ENOMEM; break; }
      for (int i = 0; i < c->nmm; i++) t[i] = c->mm[i];
      k_drop(c->mm);
      c->mm = t, c->cmm = m; }
    void *raw;
    uint8_t *k;
    while (!(k = k_uraw(ask, &raw)) && ask > 4096) ask = (ask / 2 + 4095) & ~4095ull;
    if (!k) { r = -ENOMEM; break; }
    if (!anon) {
      uint64_t o0 = va - lo, n = o0 >= b ? 0 : b - o0 < ask ? b - o0 : ask;
      r = k_proc_call(c->pid, NR_lseek, fd, g + (long) o0, SEEK_SET, 0, 0, 0);
      for (uint64_t o = 0; r >= 0 && o < n; o += (uint64_t) r)
        if (!(r = k_proc_call(c->pid, NR_read, fd, (long) (uintptr_t) (k + o), (long) (n - o), 0, 0, 0))) break;
      if (r < 0) { kfree(raw); break; } }
    if (d & PROT_EXEC) k_usync(k, ask);
    c->mm[c->nmm++] = (struct k_umm) { va, va + ask, raw, NULL, NULL, NULL, 0 };
    if ((r = k_umapb(c, va, va + ask, false, false, k))) break;
    for (uint64_t v = va; v < va + ask; v += 4096) {
      uint64_t *p = k_uwalk(c, v);
      *p = k_uprot(*p, d); }
    va += ask; }
  if (!anon && at >= 0) k_proc_call(c->pid, NR_lseek, fd, at, SEEK_SET, 0, 0, 0);
  return r < 0 ? r : 0; }
