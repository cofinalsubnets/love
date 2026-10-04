// src/love/inf.h -- one canonical prefix code read lsb first, rfc 1951's and vp8l's alike:
// lib/gz.c's inflate and lib/webp.c's lossless decoder build and read it the same way.
#ifndef INF_H
#define INF_H
#include <stdint.h>
#include <string.h>

// the counts and symbols the walk needs, and the table over them. an entry is
// (symbol << 4) | length, and 0 -- no code is 0 bits -- means "walk it". sym holds nsym
// symbols and tab 1 << root entries, both the caller's storage.
struct inf_code { uint16_t cnt[16], *sym, *tab; unsigned root; };

static void inf_build(struct inf_code *c, const uint8_t *lens, unsigned nsym,
                      uint16_t *sym, uint16_t *tab, unsigned root) {
 unsigned ofs[16], l, i, code = 0, idx = 0, size = 1u << root;
 memset(c->cnt, 0, sizeof c->cnt);
 memset(sym, 0, (size_t) nsym * sizeof *sym);
 memset(tab, 0, (size_t) size * sizeof *tab);
 for (i = 0; i < nsym; i++) c->cnt[lens[i]]++;
 c->cnt[0] = 0;                                  // a zero length is no code, not a code
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

// the bit walk, for the codes the table does not hold: a table entry, (symbol << 4) |
// length, or -1 where no code matches
static int inf_walk(const struct inf_code *c, uint64_t bb) {
 int code = 0, first = 0, index = 0, cnt;
 unsigned l;
 for (l = 1; l < 16; l++) {
  code |= (int) ((bb >> (l - 1)) & 1);
  cnt = c->cnt[l];
  if (code - cnt < first) return (int) c->sym[index + (code - first)] << 4 | (int) l;
  index += cnt; first = (first + cnt) << 1; code <<= 1; }
 return -1; }

#endif
