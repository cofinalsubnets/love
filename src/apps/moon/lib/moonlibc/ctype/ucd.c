// src/apps/moon/lib/moonlibc/ctype/ucd.c -- the unicode floor: unicode 17 under glibc 2.44's
// rules, off src/tools/mkctype.l, mkwidth.l and mkemoji.l. compiled into love on every
// frontend, as math/lm.c is.
#include "ucd.h"
#include "ucdctype.h"
#include "ucdwidth.h"
#include "ucdemoji.h"

#define ucd_n(t) (sizeof t / sizeof *t)
static struct { uint16_t const *t, *p; } const ucd_runs[] = {
  {uc_alpha, uc_alpha_p}, {uc_upper, uc_upper_p}, {uc_lower, uc_lower_p}, {uc_print, uc_print_p},
  {uc_space, uc_space_p}, {uc_blank, uc_blank_p}, {uc_cntrl, uc_cntrl_p}, {uc_vs, uc_vs_p},
  {uc_xp, uc_xp_p}};

// how many of a table's entries sit at or below c: those of the planes before c's, then a
// search of its own plane's low halves
static uintptr_t ucd_le(uint16_t const *t, uint16_t const *p, uint32_t c) {
  uintptr_t lo = p[c >> 16], hi = p[(c >> 16) + 1];
  while (lo < hi) { uintptr_t m = (lo + hi) / 2; if (t[m] <= (c & 0xffff)) lo = m + 1; else hi = m; }
  return lo; }

// entries open and close runs in turn: c is inside when an odd count sit at or below it
int __ucd_in(int t, uint32_t c) {
  if (t < 0 || t >= (int) ucd_n(ucd_runs) || c > 0x10ffff) return 0;
  return (int) (ucd_le(ucd_runs[t].t, ucd_runs[t].p, c) & 1); }

int __ucd_width(uint32_t c) {
  if (!c) return 0;
  if (c < 32 || (c >= 127 && c < 160) || c > 0x10ffff) return -1;
  if (c < 768) return 1;
  uintptr_t k = ucd_le(uc_width, uc_width_p, c) - 1;
  return uc_widthw[k / 4] >> (2 * (k % 4)) & 3; }

// a case map's run k: start count stride, unpacked
#define ucd_s(r) ((r) & 0x1ffff)
#define ucd_c(r) ((r) >> 17 & 0x7f)
#define ucd_st(r) ((r) >> 24)

// the last run opening at or below c, if c is one of its steps
uint32_t __ucd_map(int up, uint32_t c) {
  uint32_t const *t = up ? uc_tou : uc_tol;
  uintptr_t lo = 0, hi = up ? ucd_n(uc_tou) : ucd_n(uc_tol);
  while (hi - lo > 1) { uintptr_t m = (lo + hi) / 2; if (ucd_s(t[m]) <= c) lo = m; else hi = m; }
  uint32_t r = t[lo];
  if (c < ucd_s(r)) return c;
  uint32_t j = c - ucd_s(r);
  return j % ucd_st(r) == 0 && j / ucd_st(r) < ucd_c(r) ? (uint32_t) ((int32_t) c + (up ? uc_toud : uc_told)[lo]) : c; }

// the least step of either map's runs at or past c; 0x110000 past them all
uint32_t __ucd_moved(uint32_t c) {
  uint32_t best = 0x110000;
  for (int up = 0; up < 2; up++) {
    uint32_t const *t = up ? uc_tou : uc_tol;
    uintptr_t n = up ? ucd_n(uc_tou) : ucd_n(uc_tol);
    for (uintptr_t k = 0; k < n; k++) {
      uint32_t s = ucd_s(t[k]), cnt = ucd_c(t[k]), st = ucd_st(t[k]);
      if (s >= best) break;
      uint32_t j = c <= s ? 0 : (c - s + st - 1) / st;
      if (j < cnt && s + j * st < best) best = s + j * st; } }
  return best; }
