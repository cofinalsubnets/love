// src/apps/moon/lib/moonlibc/ctype/ucd.c -- the unicode floor: unicode 17 under glibc 2.44's
// rules, off src/tools/mkctype.l, mkwidth.l and mkemoji.l. compiled into love on every
// frontend, as math/lm.c is.
#include "ucd.h"
#include "ucdctype.h"
#include "ucdwidth.h"
#include "ucdemoji.h"

#define ucd_n(t) (sizeof t / sizeof *t)
static struct { uint32_t const *t; uintptr_t n; } const ucd_runs[] = {
  {uc_alpha, ucd_n(uc_alpha)}, {uc_upper, ucd_n(uc_upper)}, {uc_lower, ucd_n(uc_lower)},
  {uc_print, ucd_n(uc_print)}, {uc_space, ucd_n(uc_space)}, {uc_blank, ucd_n(uc_blank)},
  {uc_cntrl, ucd_n(uc_cntrl)}, {uc_vs, ucd_n(uc_vs)}, {uc_xp, ucd_n(uc_xp)}};

// entries open and close runs in turn: c is inside when an odd count sit at or below it
int __ucd_in(int t, uint32_t c) {
  if (t < 0 || t >= (int) ucd_n(ucd_runs)) return 0;
  uint32_t const *r = ucd_runs[t].t;
  uintptr_t lo = 0, hi = ucd_runs[t].n;
  while (lo < hi) { uintptr_t m = (lo + hi) / 2; if (r[m] <= c) lo = m + 1; else hi = m; }
  return (int) (lo & 1); }

int __ucd_width(uint32_t c) {
  if (!c) return 0;
  if (c < 32 || (c >= 127 && c < 160) || c > 0x10ffff) return -1;
  if (c < 768) return 1;
  uintptr_t lo = 0, hi = ucd_n(uc_width);
  while (hi - lo > 1) { uintptr_t m = (lo + hi) / 2; if (uc_width[m] >> 2 <= c) lo = m; else hi = m; }
  return (int) (uc_width[lo] & 3); }

// the last run opening at or below c, if c is one of its steps: [start count stride delta]
uint32_t __ucd_map(int up, uint32_t c) {
  int32_t const *t = up ? uc_tou : uc_tol;
  uintptr_t lo = 0, hi = (up ? ucd_n(uc_tou) : ucd_n(uc_tol)) / 4;
  while (hi - lo > 1) { uintptr_t m = (lo + hi) / 2; if ((uint32_t) t[4 * m] <= c) lo = m; else hi = m; }
  int32_t const *r = t + 4 * lo;
  if (c < (uint32_t) r[0]) return c;
  uint32_t j = c - (uint32_t) r[0];
  return j % (uint32_t) r[2] == 0 && j / (uint32_t) r[2] < (uint32_t) r[1] ? (uint32_t) ((int32_t) c + r[3]) : c; }

// the least step of either map's runs at or past c; 0x110000 past them all
uint32_t __ucd_moved(uint32_t c) {
  uint32_t best = 0x110000;
  for (int up = 0; up < 2; up++) {
    int32_t const *t = up ? uc_tou : uc_tol;
    uintptr_t n = (up ? ucd_n(uc_tou) : ucd_n(uc_tol)) / 4;
    for (uintptr_t k = 0; k < n; k++) {
      uint32_t s = (uint32_t) t[4 * k], cnt = (uint32_t) t[4 * k + 1], st = (uint32_t) t[4 * k + 2];
      if (s >= best) break;
      uint32_t j = c <= s ? 0 : (c - s + st - 1) / st;
      if (j < cnt && s + j * st < best) best = s + j * st; } }
  return best; }
