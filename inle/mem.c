// inle/mem.c -- raw slots on a cask: the door between love's values and a byte buffer's own
// layout. love reads a cask a byte at a time, which is a dispatch per byte -- a loop for
// anything wider than one, and a loop per ELEMENT for anything laid in bulk.
//   (peepw c i)        -> the word at 8-byte slot i, low 4 bytes | () misuse
//   (pinw c i v)       -> lay v zero-extended into 8-byte slot i -> c | () misuse
//   (peepv c o w s n)  -> n elements of w bytes, stride s from byte o, as a Z tray
//   (pinv c o w s v)   -> the elements of tray v laid that way -> c | () misuse
// the pair carrying a width and a stride is the general one, and the stride is why: a
// stride wider than the width is an INTERLEAVE, which is what a frame of stereo PCM is
// (apps/harp/play.l's pack lays each channel with one call) and what a plane of anything
// else is. little-endian, low bytes, unsigned: a caller wanting a signed read subtracts,
// and one wanting fewer bytes says so in w. a float element truncates toward zero, the
// same answer `int` gives -- so a tray of samples goes down without a pass to round it.
// value ops, so absence/misuse answers (); flat.l binds getw/putw to the word pair, the
// byte path staying the portable twin (freestanding targets have no host glob). they are
// born in the `guts` module rather than on the book -- a raw word door has no business in
// a global read.
#include "love.h"
#include <string.h>
#include <stdint.h>

static lvm(lvm_peepw) {
 word c = Sp[0], out = ZeroPoint;
 if (!charmp(c) && cell(c)->ap == lvm_cask && charmp(Sp[1])) {
  intptr_t i = getcharm(Sp[1]);
  struct ai_str *s = cask(c)->str;
  if (i >= 0 && (uintptr_t) (i + 1) * 8 <= s->len) {
   uint64_t w;
   memcpy(&w, s->bytes + 8 * i, 8);
   out = putcharm((intptr_t) (w & 0xffffffffu)); } }
 Sp[1] = out;
 ai_musttail return Nextp(1, 1); }

static lvm(lvm_pinw) {
 word c = Sp[0], out = ZeroPoint;
 if (!charmp(c) && cell(c)->ap == lvm_cask && charmp(Sp[1]) && charmp(Sp[2])) {
  intptr_t i = getcharm(Sp[1]);
  uint64_t v = (uint64_t) getcharm(Sp[2]) & 0xffffffffu;
  struct ai_str *s = cask(c)->str;
  if (i >= 0 && (uintptr_t) (i + 1) * 8 <= s->len) {
   memcpy(s->bytes + 8 * i, &v, 8);
   out = c; } }
 Sp[2] = out;
 ai_musttail return Nextp(1, 2); }

// does a run of n elements at (o, w, s) lie inside len bytes? n = 0 is the empty run and
// asks only that the offset be in the buffer. THE LAST STEP IS A DIVISION and not the
// multiplication it reads as: n is a tray's length and s a charm, and their product is
// what would wrap -- a wrap here answers "it fits" about a run that does not, which is
// the whole buffer's bounds gone. dividing the room instead cannot leave the range.
static bool slot_fit(uintptr_t len, intptr_t o, intptr_t w, intptr_t s, uintptr_t n) {
 if (o < 0 || w < 1 || w > 8 || s < w) return false;
 if ((uintptr_t) o > len) return false;
 if (!n) return true;
 uintptr_t room = len - (uintptr_t) o;
 if (room < (uintptr_t) w) return false;
 return n - 1 <= (room - (uintptr_t) w) / (uintptr_t) s; }

// a tray the byte lane can read: the two number types. an object tray's words are
// pointers and a complex one's are pairs, so neither goes down a byte at a time.
static bool numtray(word x) {
 return trayp(x) && (tray(x)->type == ai_Z || tray(x)->type == ai_R); }

static lvm(lvm_pinv) {
 word c = Sp[0], out = ZeroPoint;
 if (!charmp(c) && cell(c)->ap == lvm_cask && charmp(Sp[1]) && charmp(Sp[2])
     && charmp(Sp[3]) && numtray(Sp[4])) {
  intptr_t o = getcharm(Sp[1]), w = getcharm(Sp[2]), s = getcharm(Sp[3]);
  struct ai_tray *v = tray(Sp[4]);
  uintptr_t n = tray_nelem(v);
  struct ai_str *st = cask(c)->str;
  if (slot_fit(st->len, o, w, s, n)) {
   unsigned char *p = (unsigned char*) st->bytes + o;
   for (uintptr_t i = 0; i < n; i++, p += s) {
    uint64_t x = (uint64_t) tray_get_int(v, i);
    for (intptr_t b = 0; b < w; b++) p[b] = (unsigned char) (x >> (8 * b)); }
   out = c; } }
 Sp[4] = out;
 ai_musttail return Nextp(1, 4); }

static lvm(lvm_peepv) {
 word c = Sp[0];
 if (charmp(c) || cell(c)->ap != lvm_cask || !charmp(Sp[1]) || !charmp(Sp[2])
     || !charmp(Sp[3]) || !charmp(Sp[4])) {
  Sp[4] = ZeroPoint; ai_musttail return Nextp(1, 4); }
 intptr_t n = getcharm(Sp[4]);
 if (n < 0 || !slot_fit(cask(c)->str->len, getcharm(Sp[1]), getcharm(Sp[2]),
                        getcharm(Sp[3]), (uintptr_t) n)) {
  Sp[4] = ZeroPoint; ai_musttail return Nextp(1, 4); }
 uintptr_t bytes = tray_bytes(ai_Z, 1, (uintptr_t) n);
 Have(b2w(bytes));
 // nothing above moved a stack slot, so the collection's restart of this instruction
 // re-reads the same operands and lands here again; what a collection DID move is the
 // cask, so every pointer is taken after the Have and none before.
 c = Sp[0];
 intptr_t o = getcharm(Sp[1]), w = getcharm(Sp[2]), s = getcharm(Sp[3]);
 struct ai_tray *v = ini_tray((struct ai_tray*) Hp, ai_Z, 1);
 Hp += b2w(bytes);
 v->shape[0] = (uintptr_t) n;
 unsigned char const *p = (unsigned char const*) cask(c)->str->bytes + o;
 for (intptr_t i = 0; i < n; i++, p += s) {
  uint64_t x = 0;
  for (intptr_t b = 0; b < w; b++) x |= (uint64_t) p[b] << (8 * b);
  tray_put_int(v, (uintptr_t) i, (intptr_t) x); }
 Sp[4] = word(v);
 ai_musttail return Nextp(1, 4); }

static union u const
  nif_peepw[]  = {{lvm_cur}, {.x = putcharm(2)}, {lvm_peepw}, {lvm_ret0}},
  nif_pinw[]   = {{lvm_cur}, {.x = putcharm(3)}, {lvm_pinw},  {lvm_ret0}},
  nif_peepv[]  = {{lvm_cur}, {.x = putcharm(5)}, {lvm_peepv}, {lvm_ret0}},
  nif_pinv[]   = {{lvm_cur}, {.x = putcharm(5)}, {lvm_pinv},  {lvm_ret0}};
LvNif("peepw", nif_peepw, "guts");
LvNif("pinw", nif_pinw, "guts");
LvNif("peepv", nif_peepv, "guts");
LvNif("pinv", nif_pinv, "guts");
