// nohorn.c -- the horn's refusal, for a build with no horn.c (the boards, the playdate).
// apart from bare.c: a speaker is not an fd. plain, not weak, so a real horn collides here
#include "love.h"

struct g *love_horn_writen(struct g *g, unsigned char const *src, uintptr_t n) {
  return g->b = -1, g; }

intptr_t love_horn_readn(struct g *g, unsigned char *dst, uintptr_t n) { return -1; }
