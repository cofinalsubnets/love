// l/nohorn.c -- the horn with no device under it. a seat that HAS a sound card answers
// this itself (i/horn.c on a hosted kernel, i/hda.c through k_horn_* on inle), so this is
// the refusal for a seat that has none: the boards, the playdate until it grows one, and
// b/front. separate from l/bare.c because the two ask different questions -- bare.c is
// what a seat with no i/fd.c owes the runtime, and a seat can lack fd.c and still have a
// speaker. the wasm host seat is exactly that one, which is what split them.
//
// plain definition, not a weak default: a seat that grows a real horn collides here and
// says so, and a seat that needs one and has none fails to link.
#include "love.h"

struct ai *ai_horn_writen(struct ai *g, unsigned char const *src, uintptr_t n) {
  return g->b = -1, g; }
