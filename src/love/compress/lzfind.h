// lzfind.h -- the match finder of xz.c's and gz.c's best coders: a binary tree over the input,
// the window its dict. a 4-byte hash roots a tree of earlier positions ordered by what follows:
// one walk finds the longest matches and re-roots. 2- and 3-byte heads find short ones.
// entries are position + 1; an includer has bytes.h
#pragma once
#include <stdint.h>

struct lzf { const uint8_t *s; uintptr_t n; uint32_t *h2, *h3, *h4, *son, wmask, dict; uintptr_t ins;
             unsigned h4bits, depth, skipdepth, nice, maxm; };  // h2 and h3 hold 1 << 16 each

static uint32_t lzf_h3(const uint8_t *s) { return ((uint32_t) s[0] << 16 ^ (uint32_t) s[1] << 8 ^ s[2]) * 2654435761u >> 16; }
static uint32_t lzf_h4(const uint8_t *s, unsigned bits) {
 return ((uint32_t) s[0] | (uint32_t) s[1] << 8 | (uint32_t) s[2] << 16 | (uint32_t) s[3] << 24) * 2654435761u >> (32 - bits); }

static unsigned lzf_mlen(const uint8_t *a, const uint8_t *b, unsigned lim) {
 unsigned k = 0;
#if wideld
 for (; k + 8 <= lim; k += 8) {                 // a word at a time: the first byte that differs
  uint64_t x = ld64(a + k) ^ ld64(b + k);       // is the lowest set one, little-endian
  if (x) return k + (unsigned) (__builtin_ctzll(x) >> 3); }
#endif
 while (k < lim && a[k] == b[k]) k++;
 return k; }

// index p; with ls, the matches longer than the nearer ones (ls rising, ds distance - 1) -> how many
static unsigned lzf_bt(struct lzf *f, uintptr_t p, unsigned lim, uint32_t *ls, uint32_t *ds) {
 const uint8_t *s = f->s, *sp = s + p;
 unsigned k = 0, best = 1;
 uintptr_t reach = f->dict < f->wmask ? f->dict : f->wmask;
 if (p + 2 > f->n) return 0;
 uint32_t h2 = (uint32_t) sp[0] | (uint32_t) sp[1] << 8, c2 = f->h2[h2];
 f->h2[h2] = (uint32_t) p + 1;
 if (ls && c2 && p - (c2 - 1) <= reach && lim >= 2 && s[c2 - 1] == sp[0] && s[c2] == sp[1])
  best = 2, ls[0] = 2, ds[0] = (uint32_t) (p - c2), k = 1;
 if (p + 3 > f->n) return k;
 uint32_t h3 = lzf_h3(sp), c3 = f->h3[h3];
 f->h3[h3] = (uint32_t) p + 1;
 if (ls && c3 && p - (c3 - 1) <= reach && lim >= 3) {
  unsigned l = lzf_mlen(s + c3 - 1, sp, lim);
  if (l >= 3) {
   if (k && ds[0] == p - c3) k = 0;               // the same match, longer
   best = l, ls[k] = l, ds[k] = (uint32_t) (p - c3), k++; } }
 if (p + 4 > f->n) return k;
 uint32_t h4 = lzf_h4(sp, f->h4bits), c = f->h4[h4];
 f->h4[h4] = (uint32_t) p + 1;
 uint32_t *lo = f->son + 2 * (p & f->wmask), *hi = lo + 1;   // the new root's two sides
 unsigned llo = 0, lhi = 0, depth = ls ? f->depth : f->skipdepth, cut = lim < f->nice ? lim : f->nice;
 for (;;) {
  uintptr_t q = c - 1;
  if (!c || p - q > reach || !depth--) { *lo = *hi = 0; break; }
  uint32_t *pair = f->son + 2 * (q & f->wmask);
  unsigned l = llo < lhi ? llo : lhi;
  l += lzf_mlen(s + q + l, sp + l, cut - l);
  if (l > best && ls && k < f->maxm) {
   if (k && ds[k - 1] == p - q - 1) k--;
   best = l, ls[k] = l, ds[k] = (uint32_t) (p - q - 1), k++; }
  if (l >= cut) { *lo = pair[0], *hi = pair[1]; break; }    // its subtrees become the root's
  if (s[q + l] < sp[l]) *lo = c, lo = pair + 1, c = *lo, llo = l;
  else *hi = c, hi = pair, c = *hi, lhi = l; }
 return k; }

// index every position below upto that is not yet, with no matches asked; max the longest match
static void lzf_ins(struct lzf *f, uintptr_t upto, unsigned max) {
 for (; f->ins < upto; f->ins++) {
  uintptr_t left = f->n - f->ins;
  lzf_bt(f, f->ins, left > max ? max : (unsigned) left, 0, 0); } }

// the matches at p -> how many; a position a plan that ran further indexed already has none
static unsigned lzf_all(struct lzf *f, uintptr_t p, unsigned avail, unsigned max, uint32_t *ls, uint32_t *ds) {
 lzf_ins(f, p, max);
 if (f->ins != p) return 0;
 f->ins = p + 1;
 return lzf_bt(f, p, avail, ls, ds); }
