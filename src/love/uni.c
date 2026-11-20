// uni.c -- module ucd, doors onto moonlibc's ctype/ucd.c; a non-charm reads as past unicode
//   (width c) (in t c) (map up c) (moved c)   as ucd.h says, in module ucd
//   (case m s)  s with each character's simple case, lower (m 0) or upper (m 1); m 2 and 3
//               the same over ascii alone. a byte that starts no character stays; s itself
//               when nothing moves
#include "love.h"
#include "../apps/moon/lib/moonlibc/ctype/ucd.h"

static love_inline uint32_t uc(word c) {
  return charmp(c) && getcharm(c) >= 0 && getcharm(c) <= 0x10ffff ? (uint32_t) getcharm(c) : 0x110000; }
static love_inline word host_ucd_width(struct g *g, word c) { (void) g; return putcharm(__ucd_width(uc(c))); }
static love_inline word host_ucd_in(struct g *g, word t, word c) {
  (void) g; return putcharm(charmp(t) ? __ucd_in((int) getcharm(t), uc(c)) : 0); }
static love_inline word host_ucd_map(struct g *g, word up, word c) {
  (void) g; return uc(c) > 0x10ffff ? c : putcharm(__ucd_map(up != putcharm(0), uc(c))); }
static love_inline word host_ucd_moved(struct g *g, word c) { (void) g; return putcharm(__ucd_moved(uc(c))); }
// the character at s and its length, 0 for a byte that starts none
static int u8get(uint8_t const *s, uintptr_t n, uint32_t *c) {
  int k = s[0] >= 0xf0 ? 4 : s[0] >= 0xe0 ? 3 : s[0] >= 0xc2 ? 2 : 0;
  if (!k || s[0] > 0xf4 || (uintptr_t) k > n) return 0;
  uint32_t v = s[0] & (0x7f >> k);
  for (int j = 1; j < k; j++) {
    if ((s[j] & 0xc0) != 0x80) return 0;
    v = v << 6 | (s[j] & 0x3f); }
  if ((k > 2 && v < (k == 3 ? 0x800u : 0x10000u)) || v > 0x10ffff || (v >= 0xd800 && v < 0xe000)) return 0;
  return *c = v, k; }
static int u8len(uint32_t c) { return c < 0x80 ? 1 : c < 0x800 ? 2 : c < 0x10000 ? 3 : 4; }
static uint8_t *u8put(uint8_t *o, uint32_t c) {
  int k = u8len(c);
  if (k == 1) return *o = (uint8_t) c, o + 1;
  for (int j = k; --j; ) o[j] = (uint8_t) (0x80 | (c & 0x3f)), c >>= 6;
  o[0] = (uint8_t) ((0xf00 >> k) | c);
  return o + k; }
// one step of (case m s) at i: the character there (c) and as it comes out, its length in s;
// a byte that starts no character is 0x110000 past itself, both ways
static uint32_t casestep(uint8_t const *t, uintptr_t n, uintptr_t i, int m, int *k, uint32_t *c) {
  *c = t[i], *k = 1;
  if (*c < 128) return m & 1 ? (*c - 97 < 26 ? *c - 32 : *c) : (*c - 65 < 26 ? *c + 32 : *c);
  if (m & 2 || !(*k = u8get(t + i, n - i, c))) return *k = 1, *c = 0x110000 + t[i];
  return __ucd_map(m & 1, *c); }
static love_inline struct g *host_ucd_case(struct g *g) {
  word m = g->sp[0], s = g->sp[1];
  if (!charmp(m) || getcharm(m) & ~3 || !strp(s)) return g->sp[0] = badarg(g), g;
  int f = (int) getcharm(m), k, moved = 0;
  uintptr_t n = len(s), z = 0;
  uint8_t const *t = (uint8_t const *) txt(s);
  for (uintptr_t i = 0; i < n; i += (uintptr_t) k) {
    uint32_t c, d = casestep(t, n, i, f, &k, &c);
    z += d >= 0x110000 ? 1 : (uintptr_t) u8len(d), moved |= d != c; }
  if (!moved) return g->sp[0] = s, g;
  if (!ok(g = have(g, str_width(z)))) return g;
  s = g->sp[1], t = (uint8_t const *) txt(s);
  struct str *o = ini_str((struct str *) bump(g, str_width(z)), z);
  uint8_t *w = (uint8_t *) o->bytes;
  for (uintptr_t i = 0; i < n; i += (uintptr_t) k) {
    uint32_t c, d = casestep(t, n, i, f, &k, &c);
    w = d >= 0x110000 ? (*w = (uint8_t) (d - 0x110000), w + 1) : u8put(w, d); }
  return g->sp[0] = word(o), g; }
static lvm(lvm_ucd_case) { LvmCallp(g, 1, host_ucd_case) }
LvmWord1(ucd_width)
LvmWord2(ucd_in)
LvmWord2(ucd_map)
LvmWord1(ucd_moved)
LvDef("width", ucd_width, 1, "ucd");
LvDef("in", ucd_in, 2, "ucd");
LvDef("map", ucd_map, 2, "ucd");
LvDef("moved", ucd_moved, 1, "ucd");
LvDef("case", ucd_case, 2, "ucd");
