// mem.c -- raw slots on a cask, in the `guts` module, never the book
//   (peepw c i)        -> the word at 8-byte slot i, low 4 bytes | () misuse
//   (pinw c i v)       -> lay v zero-extended into 8-byte slot i -> c | () misuse
//   (peepv c o w s n)  -> n elements of w bytes, stride s from byte o, as a Z tray
//   (pinv c o w s v)   -> the elements of tray v laid that way -> c | () misuse
// a stride past the width interleaves (harp/play.l's channels). little-endian, unsigned; a
// float element truncates toward zero, as `int` does. flat.l binds getw/putw to the word pair
#include "love.h"
#include <string.h>
#include <stdint.h>

static lvm(lvm_peepw) {
 word c = Sp[0], out = ZeroPoint;
 if (caskp(c) && charmp(Sp[1])) {
  intptr_t i = getcharm(Sp[1]);
  struct str *s = cask(c)->str;
  if (i >= 0 && (uintptr_t) i < s->len / 8) {
   uint64_t w;
   memcpy(&w, s->bytes + 8 * i, 8);
   out = putcharm((intptr_t) (w & 0xffffffffu)); } }
 Sp[1] = out;
 love_musttail return Nextp(1, 1); }

static lvm(lvm_pinw) {
 word c = Sp[0], out = ZeroPoint;
 if (caskp(c) && charmp(Sp[1]) && charmp(Sp[2])) {
  intptr_t i = getcharm(Sp[1]);
  uint64_t v = (uint64_t) getcharm(Sp[2]) & 0xffffffffu;
  struct str *s = cask(c)->str;
  if (i >= 0 && (uintptr_t) i < s->len / 8) {
   memcpy(s->bytes + 8 * i, &v, 8);
   out = c; } }
 Sp[2] = out;
 love_musttail return Nextp(1, 2); }

// does a run of n at (o, w, s) lie inside len bytes? a division, never n * s, which can wrap
static bool slot_fit(uintptr_t len, intptr_t o, intptr_t w, intptr_t s, uintptr_t n) {
 if (o < 0 || w < 1 || w > 8 || s < w) return false;
 if ((uintptr_t) o > len) return false;
 if (!n) return true;
 uintptr_t room = len - (uintptr_t) o;
 if (room < (uintptr_t) w) return false;
 return n - 1 <= (room - (uintptr_t) w) / (uintptr_t) s; }

// object and complex trays never go down a byte at a time
static bool numtray(word x) {
 return trayp(x) && (tray(x)->type == love_Z || tray(x)->type == love_R); }

static lvm(lvm_pinv) {
 word c = Sp[0], out = ZeroPoint;
 if (caskp(c) && charmp(Sp[1]) && charmp(Sp[2])
     && charmp(Sp[3]) && numtray(Sp[4])) {
  intptr_t o = getcharm(Sp[1]), w = getcharm(Sp[2]), s = getcharm(Sp[3]);
  struct tray *v = tray(Sp[4]);
  uintptr_t n = tray_nelem(v);
  struct str *st = cask(c)->str;
  if (slot_fit(st->len, o, w, s, n)) {
   unsigned char *p = (unsigned char*) st->bytes + o;
   for (uintptr_t i = 0; i < n; i++, p += s) {
    uint64_t x = (uint64_t) tray_get_int(v, i);
    for (intptr_t b = 0; b < w; b++) p[b] = (unsigned char) (x >> (8 * b)); }
   out = c; } }
 Sp[4] = out;
 love_musttail return Nextp(1, 4); }

static lvm(lvm_peepv) {
 word c = Sp[0];
 if (!caskp(c) || !charmp(Sp[1]) || !charmp(Sp[2])
     || !charmp(Sp[3]) || !charmp(Sp[4])) {
  Sp[4] = ZeroPoint; love_musttail return Nextp(1, 4); }
 intptr_t n = getcharm(Sp[4]);
 if (n < 0 || !slot_fit(cask(c)->str->len, getcharm(Sp[1]), getcharm(Sp[2]),
                        getcharm(Sp[3]), (uintptr_t) n)) {
  Sp[4] = ZeroPoint; love_musttail return Nextp(1, 4); }
 uintptr_t bytes = tray_bytes(love_Z, 1, (uintptr_t) n);
 Have(b2w(bytes));
 // a collection's restart re-reads the same operands; the cask moved, so pointers come after
 c = Sp[0];
 intptr_t o = getcharm(Sp[1]), w = getcharm(Sp[2]), s = getcharm(Sp[3]);
 struct tray *v = ini_tray((struct tray*) Hp, love_Z, 1);
 Hp += b2w(bytes);
 v->shape[0] = (uintptr_t) n;
 unsigned char const *p = (unsigned char const*) cask(c)->str->bytes + o;
 for (intptr_t i = 0; i < n; i++, p += s) {
  uint64_t x = 0;
  for (intptr_t b = 0; b < w; b++) x |= (uint64_t) p[b] << (8 * b);
  tray_put_int(v, (uintptr_t) i, (intptr_t) x); }
 Sp[4] = word(v);
 love_musttail return Nextp(1, 4); }

// (push-gc n) -> n: the nth push from here collects, wherever it falls (0 none) -- a law's way
// to put a collection under a push, the may-collect a raw local held across goes stale at
static lvm(lvm_pushgc) {
 g->push_gc = charmp(Sp[0]) && getcharm(Sp[0]) > 0 ? (uintptr_t) getcharm(Sp[0]) : 0;
 love_musttail return Next(1); }

LvDef("push-gc", pushgc, 1, "guts");
LvDef("peepw", peepw, 2, "guts");
LvDef("pinw", pinw, 3, "guts");
LvDef("peepv", peepv, 5, "guts");
LvDef("pinv", pinv, 5, "guts");
