// love/nohorn.c -- the horn with no device under it. a seat that HAS one links inle/horn.c,
// which answers this itself (a card by ioctl on a hosted kernel, inle/hda.c through k_horn_*
// on inle, the sink with no card at all), so this is the refusal for a seat that carries
// no horn at all: the boards, and the playdate until it grows one -- it has a speaker,
// and inle/horn.c doorless plus an ai_horn_tap is the way in.
//
// separate from love/bare.c because the two ask different questions. bare.c is what a seat
// with no inle/fd.c owes the runtime, and having a speaker is not having an fd.
//
// plain definition, not a weak default: a seat that grows a real horn collides here and
// says so, and a seat that needs one and has none fails to link.
#include "love.h"

struct ai *ai_horn_writen(struct ai *g, unsigned char const *src, uintptr_t n) {
  return g->b = -1, g; }
