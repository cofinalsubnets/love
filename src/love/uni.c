// uni.c -- module ucd, doors onto moonlibc's ctype/ucd.c; a non-charm reads as past unicode
//   (width c) (in t c) (map up c) (moved c)   as ucd.h says, in module ucd
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
LvmWord1(ucd_width)
LvmWord2(ucd_in)
LvmWord2(ucd_map)
LvmWord1(ucd_moved)
LvDef("width", ucd_width, 1, "ucd");
LvDef("in", ucd_in, 2, "ucd");
LvDef("map", ucd_map, 2, "ucd");
LvDef("moved", ucd_moved, 1, "ucd");
