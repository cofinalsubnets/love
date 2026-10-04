// src/love/nohorn.c -- the horn with no device under it. a seat that HAS one links src/love/horn.c,
// which answers this itself (a card by ioctl on a hosted kernel, src/inle/hda.c through k_horn_*
// on inle, the sink with no card at all), so this is the refusal for a seat that carries
// no horn at all: the boards, and the playdate until it grows one -- it has a speaker,
// and src/love/horn.c doorless plus an love_horn_tap is the way in.
//
// separate from src/love/bare.c because the two ask different questions. bare.c is what a seat
// with no src/love/fd.c owes the runtime, and having a speaker is not having an fd.
//
// plain definition, not a weak default: a seat that grows a real horn collides here and
// says so, and a seat that needs one and has none fails to link.
#include "love.h"

struct g *love_horn_writen(struct g *g, unsigned char const *src, uintptr_t n) {
  return g->b = -1, g; }
