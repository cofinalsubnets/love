// prefix.h -- one canonical prefix code read lsb first, rfc 1951's and vp8l's alike (gz.c, webp.c
// build and read it, and choose its lengths, the same way)
#ifndef INF_H
#define INF_H
#include <stdint.h>
#include <string.h>

// a tab entry is (symbol << 4) | length, 0 meaning walk it; sym (nsym) and tab (1 << root) are the caller's
struct inf_code { uint16_t cnt[16], *sym, *tab; unsigned root; };

static inline void inf_build(struct inf_code *c, const uint8_t *lens, unsigned nsym,
                             uint16_t *sym, uint16_t *tab, unsigned root) {
 unsigned ofs[16], l, i, code = 0, idx = 0, size = 1u << root;
 memset(c->cnt, 0, sizeof c->cnt);
 memset(sym, 0, (size_t) nsym * sizeof *sym);
 memset(tab, 0, (size_t) size * sizeof *tab);
 for (i = 0; i < nsym; i++) c->cnt[lens[i]]++;
 c->cnt[0] = 0;                                  // a zero length is no code
 ofs[1] = 0;
 for (l = 1; l < 15; l++) ofs[l + 1] = ofs[l] + c->cnt[l];
 for (i = 0; i < nsym; i++) if (lens[i]) sym[ofs[lens[i]]++] = (uint16_t) i;
 c->sym = sym; c->tab = tab; c->root = root;
 for (l = 1; l < 16; l++) {                      // canonical order, shortest first
  for (i = 0; i < c->cnt[l]; i++, code++) {
   unsigned s = sym[idx++], rev = 0, b, j;
   if (l > root) continue;
   for (b = 0; b < l; b++) rev |= ((code >> b) & 1) << (l - 1 - b);   // the code, as read
   for (j = rev; j < size; j += 1u << l)
    if (!tab[j]) tab[j] = (uint16_t) ((s << 4) | l); }
  code <<= 1; } }

// the walk for codes past the table: an entry, or -1 where none matches
static inline int inf_walk(const struct inf_code *c, uint64_t bb) {
 int code = 0, first = 0, index = 0, cnt;
 unsigned l;
 for (l = 1; l < 16; l++) {
  code |= (int) ((bb >> (l - 1)) & 1);
  cnt = c->cnt[l];
  if (code - cnt < first) return (int) c->sym[index + (code - first)] << 4 | (int) l;
  index += cnt; first = (first + cnt) << 1; code <<= 1; }
 return -1; }

// lengths for the counts in hc, nsym of them (under 4096): the leaves sorted by count, ties to
// the lower symbol, merged through a second queue; while the code is deeper than lim every
// count halves in hc, for at most 32 passes. a lone symbol gets 1 -> the deepest length.
// scratch is the caller's: keys nsym, w and pa 2 * nsym
static inline unsigned pfx_lens(uint32_t *hc, unsigned nsym, unsigned lim, uint8_t *lens,
                                uint64_t *keys, uint64_t *w, uint32_t *pa) {
 memset(lens, 0, nsym);
 for (unsigned pass = 0;; pass++) {
  unsigned nl = 0, mx = 0, i, li = 0, ii, top;
  for (i = 0; i < nsym; i++) if (hc[i]) keys[nl++] = (uint64_t) hc[i] << 12 | i;
  if (nl < 2) { if (nl) lens[keys[0] & 4095] = 1; return nl; }
  for (unsigned gap = nl / 2; gap; gap /= 2)
   for (i = gap; i < nl; i++) {
    uint64_t v = keys[i]; unsigned j = i;
    while (j >= gap && keys[j - gap] > v) keys[j] = keys[j - gap], j -= gap;
    keys[j] = v; }
  for (i = 0; i < nl; i++) w[i] = keys[i] >> 12;
  memset(pa, 0, (size_t) (2 * nl) * sizeof *pa), ii = nl;
  for (top = nl; top < 2 * nl - 1; top++) {
   unsigned a, b;
#define PFX_PICK(L, I) ((L) < nl && ((I) >= top || w[L] <= w[I]))
   if (PFX_PICK(li, ii)) a = li++; else a = ii++;
   if (PFX_PICK(li, ii)) b = li++; else b = ii++;
#undef PFX_PICK
   w[top] = w[a] + w[b], pa[a] = pa[b] = top + 1; }
  for (i = 0; i < nl; i++) {
   unsigned d = 0;
   for (uint32_t p = pa[i]; p; p = pa[p - 1]) d++;
   lens[keys[i] & 4095] = (uint8_t) d;
   if (d > mx) mx = d; }
  if (mx <= lim || pass >= 32) return mx;
  for (i = 0; i < nsym; i++) if (hc[i]) hc[i] = hc[i] >> 1 ? hc[i] >> 1 : 1; } }

#endif
