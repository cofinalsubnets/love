// mem.c -- raw slots on a cask, in the `guts` module, never the book
//   (peepw c i)        -> the word at 8-byte slot i, low 4 bytes | () misuse
//   (pinw c i v)       -> lay v zero-extended into 8-byte slot i -> c | () misuse
//   (peepv c o w s n)  -> n elements of w bytes, stride s from byte o, as a Z tray; n a list
//                         of dims lays them in that shape
//   (pinv c o w s v)   -> the elements of tray v laid that way -> c | () misuse
//   (pinf c o s v)     -> the elements of tray v as 4-byte floats, stride s from byte o -> c | () misuse
//   (pind c o v)       -> a real tray v's elements laid packed from byte o, as they are -> c | () misuse
//   (peepd c o n)      -> n such elements from byte o, as a real tray, the bits as laid; n as
//                         peepv's
// peepv and peepd read a string's bytes as well as a cask's. a stride past the width
// interleaves (harp/play.l's channels). little-endian, unsigned; a float element truncates
// toward zero, as `int` does. flat.l binds getw/putw to the word pair
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

static lvm(lvm_pinf) {
 word c = Sp[0], out = ZeroPoint;
 if (caskp(c) && charmp(Sp[1]) && charmp(Sp[2]) && numtray(Sp[3])) {
  intptr_t o = getcharm(Sp[1]), s = getcharm(Sp[2]);
  struct tray *v = tray(Sp[3]);
  uintptr_t n = tray_nelem(v);
  struct str *st = cask(c)->str;
  if (slot_fit(st->len, o, 4, s, n)) {
   unsigned char *p = (unsigned char*) st->bytes + o;
   for (uintptr_t i = 0; i < n; i++, p += s) {
    float x = (float) tray_get_flo(v, i);
    memcpy(p, &x, 4); }
   out = c; } }
 Sp[3] = out;
 love_musttail return Nextp(1, 3); }

static lvm(lvm_pind) {
 word c = Sp[0], out = ZeroPoint;
 if (caskp(c) && charmp(Sp[1]) && trayp(Sp[2]) && tray(Sp[2])->type == love_R) {
  intptr_t o = getcharm(Sp[1]);
  struct tray *v = tray(Sp[2]);
  uintptr_t n = tray_nelem(v);
  struct str *st = cask(c)->str;
  if (slot_fit(st->len, o, sizeof(flo_t), sizeof(flo_t), n)) {
   memcpy(st->bytes + o, tray_data(v), sizeof(flo_t) * n);
   out = c; } }
 Sp[2] = out;
 love_musttail return Nextp(1, 2); }

// a peep's count n, a rank 1 tray, or a list of dims, a tray of that shape: its rank and
// elements, false where it is neither
static bool peep_shape(word sh, uintptr_t *rank, uintptr_t *n) {
 if (charmp(sh)) return getcharm(sh) < 0 ? false : (*rank = 1, *n = (uintptr_t) getcharm(sh), true);
 uintptr_t r = 0, m = 1;
 for (; chainp(sh); sh = B(sh), r++) {
  if (r == maxrank || !charmp(A(sh)) || getcharm(A(sh)) < 0) return false;
  m = mulsat(m, (uintptr_t) getcharm(A(sh))); }
 return r ? (*rank = r, *n = m, true) : false; }
static void peep_dims(struct tray *v, word sh) {
 if (charmp(sh)) v->shape[0] = (uintptr_t) getcharm(sh);
 else for (uintptr_t i = 0; chainp(sh); sh = B(sh)) v->shape[i++] = (uintptr_t) getcharm(A(sh)); }

static lvm(lvm_peepd) {
 uintptr_t rank, n;
 if (!(caskp(Sp[0]) || strp(Sp[0])) || !charmp(Sp[1]) || !peep_shape(Sp[2], &rank, &n)
     || !slot_fit(bytes_of(Sp[0])->len, getcharm(Sp[1]), sizeof(flo_t), sizeof(flo_t), n)) {
  Sp[2] = ZeroPoint; love_musttail return Nextp(1, 2); }
 uintptr_t bytes = tray_bytes(love_R, rank, n);
 Have(b2w(bytes));
 struct tray *v = ini_tray((struct tray*) Hp, love_R, rank);   // ..the bytes and dims read after Have, which may move them
 Hp += b2w(bytes);
 peep_dims(v, Sp[2]);
 memcpy(tray_data(v), bytes_of(Sp[0])->bytes + getcharm(Sp[1]), sizeof(flo_t) * (size_t) n);
 Sp[2] = word(v);
 love_musttail return Nextp(1, 2); }

_Static_assert(__BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__, "peepv loads an element as the cask lays it");

static lvm(lvm_peepv) {
 word c = Sp[0];
 uintptr_t rank, un;
 if (!(caskp(c) || strp(c)) || !charmp(Sp[1]) || !charmp(Sp[2])
     || !charmp(Sp[3]) || !peep_shape(Sp[4], &rank, &un)
     || !slot_fit(bytes_of(c)->len, getcharm(Sp[1]), getcharm(Sp[2]), getcharm(Sp[3]), un)) {
  Sp[4] = ZeroPoint; love_musttail return Nextp(1, 4); }
 intptr_t n = (intptr_t) un;
 uintptr_t bytes = tray_bytes(love_Z, rank, un);
 Have(b2w(bytes));
 // a collection's restart re-reads the same operands; the cask moved, so pointers come after
 c = Sp[0];
 intptr_t o = getcharm(Sp[1]), w = getcharm(Sp[2]), s = getcharm(Sp[3]);
 struct tray *v = ini_tray((struct tray*) Hp, love_Z, rank);
 Hp += b2w(bytes);
 peep_dims(v, Sp[4]);
 unsigned char const *p = (unsigned char const*) bytes_of(c)->bytes + o;
 intptr_t *d = (intptr_t*) tray_data(v);
 // ..a width at a time, each element one load (memcpy: o and s leave it unaligned); a packed
 // run already the tray's own intptr_t elements needs no widening, so one copy
 if (w == (intptr_t) sizeof(intptr_t) && s == w) memcpy(d, p, sizeof(intptr_t) * (size_t) n);
 else if (w == 1) for (intptr_t i = 0; i < n; i++, p += s) d[i] = *p;
 else if (w == 2) for (intptr_t i = 0; i < n; i++, p += s) { uint16_t x; memcpy(&x, p, 2); d[i] = x; }
 else if (w == 4) for (intptr_t i = 0; i < n; i++, p += s) { uint32_t x; memcpy(&x, p, 4); d[i] = (intptr_t) x; }
 else if (w == 8) for (intptr_t i = 0; i < n; i++, p += s) { uint64_t x; memcpy(&x, p, 8); d[i] = (intptr_t) x; }
 else for (intptr_t i = 0; i < n; i++, p += s) {
  uint64_t x = 0;
  for (intptr_t b = 0; b < w; b++) x |= (uint64_t) p[b] << (8 * b);
  d[i] = (intptr_t) x; }
 Sp[4] = word(v);
 love_musttail return Nextp(1, 4); }

LvDef("peepw", peepw, 2, "guts");
LvDef("pinw", pinw, 3, "guts");
LvDef("peepv", peepv, 5, "guts");
LvDef("pinv", pinv, 5, "guts");
LvDef("pinf", pinf, 4, "guts");
LvDef("pind", pind, 3, "guts");
LvDef("peepd", peepd, 3, "guts");
