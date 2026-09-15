// inle/alloc.c -- the runtime's heap over malloc and free, for a seat whose memory already
// is those. every pool the collector takes comes through ai_alloc: the nursery that IS g,
// the major pool, the remembered set, and the image codec's scratch.
//
// a plain definition, not a weak default in the runtime. a seat with a heap of its own
// defines ai_alloc itself and does not link this; a seat that links both collides here
// and says so; a seat that links neither fails to link, which is the right answer for a
// runtime with nowhere to put its pools. the alternative -- a weak body in love.c --
// answers quietly in both directions, and which way it went is a question about one
// link's object set rather than anything the source says.
//
// separate from love/bare.c because the two ask different questions: bare.c is what a seat
// with no inle/fd.c owes the runtime's doors, and having a heap is not having an fd.
#include "love.h"

void *ai_alloc(void *p, size_t n) { return n ? malloc(n) : (free(p), NULL); }
