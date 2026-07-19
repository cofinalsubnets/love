// host/word.c -- 8-byte word slots on a cask, for the flat solver (crew/sat/
// flat.l): its state is casks of word slots whose LOW 4 bytes carry the value,
// and the byte-at-a-time accessors were 4 dispatches per read. Host-only,
// auto-globbed + AI_NIF-registered (no ai.c/ai.h/main.c edit), the hash.c
// discipline:
//
//   (peepw c i)   -> the word at slot i, low 4 bytes | () misuse
//   (pinw c i v)  -> lay v zero-extended into slot i -> c | () misuse
//
// flat.l binds getw/putw to these when they are in the book; the byte path
// stays the portable twin (freestanding targets have no host glob). value
// ops, so absence/misuse answers ().
#include "ai.h"
#include <stdint.h>
#include <string.h>

static lvm(lvm_peepw) {
 ai_word c = Sp[0], out = ZeroPoint;
 if (!(c & 1) && ((union u*) c)->ap == lvm_buf && (Sp[1] & 1)) {
  intptr_t i = getcharm(Sp[1]);
  struct ai_str *s = ((struct ai_buf*) c)->str;
  if (i >= 0 && (uintptr_t) (i + 1) * 8 <= s->len) {
   uint64_t w;
   memcpy(&w, s->bytes + 8 * i, 8);
   out = putcharm((intptr_t) (w & 0xffffffffu)); } }
 Sp[1] = out;
 Sp += 1; Ip += 1; return Continue(); }

static lvm(lvm_pinw) {
 ai_word c = Sp[0], out = ZeroPoint;
 if (!(c & 1) && ((union u*) c)->ap == lvm_buf && (Sp[1] & 1) && (Sp[2] & 1)) {
  intptr_t i = getcharm(Sp[1]);
  uint64_t v = (uint64_t) getcharm(Sp[2]) & 0xffffffffu;
  struct ai_str *s = ((struct ai_buf*) c)->str;
  if (i >= 0 && (uintptr_t) (i + 1) * 8 <= s->len) {
   memcpy(s->bytes + 8 * i, &v, 8);
   out = c; } }
 Sp[2] = out;
 Sp += 2; Ip += 1; return Continue(); }

static union u const
 nif_peepw[] = {{lvm_cur}, {.x = putcharm(2)}, {lvm_peepw}, {lvm_ret0}},
 nif_pinw[]  = {{lvm_cur}, {.x = putcharm(3)}, {lvm_pinw},  {lvm_ret0}};
AI_NIF("peepw", nif_peepw);
AI_NIF("pinw",  nif_pinw);
