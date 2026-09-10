// i/noblob.c -- what i/src.c's carried blobs mean in a link that carries none.
// b/src.o (u/mksrc.l) lays the source archive and b/moonlibc.o (u/mkrt.l)
// the per-ISA runtimes; a link that takes neither -- love0, and the gate links that
// build the artifact's C with no laid objects under them -- names this instead.
//
// its own translation unit for the reason main0.c is: this is a LINK's answer, not a
// seat's. common.mk keeps it out of host_c and each link that wants it names it, so a
// link with two of these collides and a link with none fails to link. the length alone
// says whether anything is carried, which is why the byte arrays are one zero and not
// empty -- a zero-length array is not a definition every compiler will lay.
#include "love.h"

const unsigned char ai_srcgz[1] = {0};
const uintptr_t ai_srcgz_len = 0;
const unsigned char ai_rtgz_x64[1] = {0};
const uintptr_t ai_rtgz_x64_len = 0;
const unsigned char ai_rtgz_a64[1] = {0};
const uintptr_t ai_rtgz_a64_len = 0;
const unsigned char ai_rtgz_rv64[1] = {0};
const uintptr_t ai_rtgz_rv64_len = 0;
const unsigned char ai_rtgz_id[1] = {0};
const uintptr_t ai_rtgz_id_len = 0;
