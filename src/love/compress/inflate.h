// inflate.h -- RFC 1951 DEFLATE decoded, for gz.c and for uefi/slot.c, which has no love.
// an includer with bytes.h gets its one-load ld64, else a byte gather
#pragma once
#include "prefix.h"
#include <stdint.h>
#include <string.h>

#ifndef inf_heap
#define inf_heap 0
#endif
#ifndef wideld
#define wideld 0
static uint64_t ld64le(uint8_t const *p) {
 uint64_t v = 0;
 for (int i = 7; i >= 0; i--) v = v << 8 | p[i];
 return v; }
#endif

static const uint16_t gz_lbase[29] = {
 3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59,
 67, 83, 99, 115, 131, 163, 195, 227, 258 };
static const uint8_t gz_lext[29] = {
 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0 };
static const uint16_t gz_dbase[30] = {
 1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769,
 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577 };
static const uint8_t gz_dext[30] = {
 0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13 };
static const uint8_t gz_clord[19] = {
 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15 };

#if wideld
#define LD64(p) ld64(p)
#else
#define LD64(p) ld64le(p)
#endif

// table roots: a longer code walks bits, so these trade 2^root fill writes against walks
#define LROOT 12
#define DROOT 9
#define CROOT 7

// one block's decode tables, 10 KB on inf_run's frame (see inf_rund): the kernel's 64 KiB boot
// stack inflates with it
struct inf_tabs {
 uint16_t ltab[1 << LROOT], dtab[1 << DROOT], ctab[1 << CROOT], lsym[288], dsym[32], csym[19];
 struct inf_code lit, dst, cl;
 const uint8_t *dic; uintptr_t nd; };            // the preset dictionary behind the output, nd 0 for none

// the fast lane: topped up below 15 bits, and to 48 before a pair. with 266 bytes of room a
// copy may overrun in whole words. a code past its root (the distance's peeked before the
// length is taken) leaves the lane, so it makes no call. 1 block end, 0 short of margin, -1 malformed
static int inf_fast_run(const uint8_t *in, uintptr_t n, uintptr_t *ipp, uint64_t *bbp,
                        unsigned *bcp, uint8_t *out, uintptr_t *opp, uintptr_t cap,
                        struct inf_tabs *t) {
 const uint8_t *ie = in + n - 8, *ip = in + *ipp;
 uint8_t *op = out + *opp, *oe = out + cap - 266;
 const uint16_t *lt = t->ltab, *dt = t->dtab;
 uint64_t bb = *bbp;                            // word-wide throughout: a narrow one is
 uintptr_t bc = *bcp, e, f, sy, x, l, d;        // a zero-extend after every step
 int r = 0;
 while (op <= oe) {
  if (bc < 15) {
   if (ip > ie) break;
   bb |= LD64(ip) << bc, ip += 7 - (bc >> 3), bc |= 56; }
  if (!(e = lt[bb & ((1u << LROOT) - 1)])) break;
  sy = e >> 4;
  if (sy < 256) { bb >>= e & 15, bc -= e & 15, *op++ = (uint8_t) sy; continue; }
  if (sy == 256) { bb >>= e & 15, bc -= e & 15, r = 1; break; }
  if (sy > 285) { r = -1; break; }
  if (bc < 48) {                                // the pair, still unread, to top up for
   if (ip > ie) break;
   bb |= LD64(ip) << bc, ip += 7 - (bc >> 3), bc |= 56; }
  x = gz_lext[sy - 257];
  if (!(f = dt[(bb >> ((e & 15) + x)) & ((1u << DROOT) - 1)])) break;
  bb >>= e & 15, bc -= e & 15;
  l = gz_lbase[sy - 257] + (uintptr_t) (bb & (((uint64_t) 1 << x) - 1)), bb >>= x, bc -= x;
  bb >>= f & 15, bc -= f & 15, sy = f >> 4;
  if (sy > 29) { r = -1; break; }
  x = gz_dext[sy];
  d = gz_dbase[sy] + (uintptr_t) (bb & (((uint64_t) 1 << x) - 1)), bb >>= x, bc -= x;
  if (d > (uintptr_t) (op - out)) {             // a reach before the start: the dictionary's, or none
   uintptr_t o = (uintptr_t) (op - out), h = d - o < l ? d - o : l, k;
   if (d > o + t->nd) { r = -1; break; }
   memcpy(op, t->dic + t->nd - (d - o), h);
   for (k = h; k < l; k++) op[k] = op[k - d];
   op += l; continue; }
  { uint8_t *dp = op, *sp = op - d, *de = op + l;
#if wideld
    if (d >= 8) for (; dp < de; dp += 8, sp += 8) st64(dp, ld64(sp));
    else if (d == 1) { uint64_t v = 0x0101010101010101ull * *sp;   // a run of one byte
     for (; dp < de; dp += 8) st64(dp, v); }
    else
#endif
    for (; dp < de; dp++, sp++) *dp = *sp; }
  op += l; }
 *ipp = (uintptr_t) (ip - in), *opp = (uintptr_t) (op - out), *bbp = bb, *bcp = (unsigned) bc;
 return r; }

// -1 where the twin answers (), -2 past cap. out NULL answers the exact inflated length;
// dic is a preset dictionary of nd bytes before the output (nd 0 for none)
static int64_t inf_rundt(const uint8_t *in, uintptr_t n, uint8_t *out, uintptr_t cap,
                         const uint8_t *dic, uintptr_t nd, struct inf_tabs *t) {
 uintptr_t ip = 0, op = 0;
 uint64_t bb = 0;
 unsigned bc = 0, last, typ, i;
 uint8_t lens[320];
 t->dic = dic, t->nd = nd;

// libdeflate's refill: step ip by the bytes that wholly landed; a spilled top is read again
#define FILL() do { \
   if (ip + 8 <= n) { bb |= LD64(in + ip) << bc; ip += 7 - (bc >> 3); bc |= 56; } \
   else while (bc <= 56 && ip < n) { bb |= (uint64_t) in[ip++] << bc; bc += 8; } } while (0)
#define TAKE(k, v) do { unsigned k_ = (k); \
   if (bc < k_) { FILL(); if (bc < k_) return -1; } \
   (v) = (unsigned) (bb & ((1u << k_) - 1)); bb >>= k_; bc -= k_; } while (0)
// a symbol off `c`: the table where it reaches, the walk where it does not
#define SYM(c, t, root, sy) do { unsigned u_; uint16_t e_; \
   FILL(); e_ = (t)[bb & ((1u << (root)) - 1)]; \
   if (e_) { (sy) = e_ >> 4; u_ = e_ & 15; } \
   else { int w_ = inf_walk(&(c), bb); if (w_ < 0) return -1; (sy) = (unsigned) w_ >> 4; u_ = w_ & 15; } \
   if (bc < u_) return -1; \
   bb >>= u_; bc -= u_; } while (0)

 do {
  TAKE(1, last); TAKE(2, typ);
  if (typ == 0) {                                // stored: to the byte, then raw
   uintptr_t pos;
   unsigned ln, nl, drop = bc & 7;
   bb >>= drop; bc -= drop;
   pos = ip - (bc >> 3);                         // what is buffered is whole bytes now
   if (pos + 4 > n) return -1;
   ln = in[pos] | ((unsigned) in[pos + 1] << 8);
   nl = in[pos + 2] | ((unsigned) in[pos + 3] << 8);
   if (((ln ^ 0xffff) & 0xffff) != nl || pos + 4 + ln > n) return -1;
   if (op + ln > cap) return -2;
   if (out) memcpy(out + op, in + pos + 4, ln);
   op += ln; ip = pos + 4 + ln; bb = 0; bc = 0;
   continue; }
  if (typ == 3) return -1;

  if (typ == 1) {                                // the fixed code, RFC 1951 §3.2.6
   for (i = 0; i < 288; i++) lens[i] = i < 144 ? 8 : i < 256 ? 9 : i < 280 ? 7 : 8;
   inf_build(&t->lit, lens, 288, t->lsym, t->ltab, LROOT);
   for (i = 0; i < 30; i++) lens[i] = 5;
   inf_build(&t->dst, lens, 30, t->dsym, t->dtab, DROOT); }
  else {                                         // the block's own, read through a third
   unsigned hlit, hdist, hclen, tot, prev = 0;
   uint8_t cl[19];
   TAKE(5, hlit); TAKE(5, hdist); TAKE(4, hclen);
   hlit += 257; hdist += 1; hclen += 4;
   memset(cl, 0, sizeof cl);
   for (i = 0; i < hclen; i++) { unsigned v; TAKE(3, v); cl[gz_clord[i]] = (uint8_t) v; }
   inf_build(&t->cl, cl, 19, t->csym, t->ctab, CROOT);
   memset(lens, 0, sizeof lens);
   tot = hlit + hdist;
   // a run may overshoot tot, as the twin's does: the write is clamped, the cursor not
   for (i = 0; i < tot; ) {
    unsigned sy, r, v, k;
    SYM(t->cl, t->ctab, CROOT, sy);
    if (sy < 16)       { r = 1; v = sy; }
    else if (sy == 16) { TAKE(2, r); r += 3; v = prev; }
    else if (sy == 17) { TAKE(3, r); r += 3; v = 0; }
    else if (sy == 18) { TAKE(7, r); r += 11; v = 0; }
    else return -1;
    for (k = 0; k < r; k++) if (i + k < sizeof lens) lens[i + k] = (uint8_t) v;
    i += r; prev = v; }
   inf_build(&t->lit, lens, hlit, t->lsym, t->ltab, LROOT);
   inf_build(&t->dst, lens + hlit, hdist, t->dsym, t->dtab, DROOT); }

  for (;;) {                                     // the symbol loop, fixed or dynamic
   unsigned sy, l, d, x;
   if (out && ip + 8 <= n && op + 266 <= cap) {
    int f = inf_fast_run(in, n, &ip, &bb, &bc, out, &op, cap, t);
    if (f < 0) return -1;
    if (f) break; }
   SYM(t->lit, t->ltab, LROOT, sy);
   if (sy < 256) {
    if (op >= cap) return -2;
    if (out) out[op] = (uint8_t) sy;
    op++; continue; }
   if (sy == 256) break;
   if (sy > 285) return -1;
   sy -= 257;
   l = gz_lbase[sy];
   if (gz_lext[sy]) { TAKE(gz_lext[sy], x); l += x; }
   SYM(t->dst, t->dtab, DROOT, sy);
   if (sy > 29) return -1;
   d = gz_dbase[sy];
   if (gz_dext[sy]) { TAKE(gz_dext[sy], x); d += x; }
   if (d > op + nd) return -1;                   // a reach before the start
   if (op + l > cap) return -2;
   if (out && d > op) {                          // into the dictionary, and maybe out again
    uintptr_t h = d - op < l ? d - op : l;
    memcpy(out + op, dic + nd - (d - op), h);
    for (uintptr_t k = h; k < l; k++) out[op + k] = out[op + k - d]; }
   else if (out) {
    // a run overlaps its source and reads itself back in order; eight or more apart,
    // no byte of a word reads back inside it, so the word move agrees
    uint8_t *dp = out + op, *sp = dp - d;
    uintptr_t k = 0;
#if wideld
    if (d >= 8) for (; k + 8 <= l; k += 8) st64(dp + k, ld64(sp + k));
#endif
    for (; k < l; k++) dp[k] = sp[k]; }
   op += l; }
 } while (!last);
 return (int64_t) op;
#undef FILL
#undef TAKE
#undef SYM
}
// one block's tables: on the frame, or with inf_heap from alloc, for a stack too small for
// them (a playdate's game task)
static int64_t inf_rund(const uint8_t *in, uintptr_t n, uint8_t *out, uintptr_t cap,
                        const uint8_t *dic, uintptr_t nd) {
#if inf_heap
 struct inf_tabs *t = alloc(NULL, sizeof *t);
 if (!t) return -1;
 int64_t r = inf_rundt(in, n, out, cap, dic, nd, t);
 return alloc(t, 0), r;
#else
 struct inf_tabs t;
 return inf_rundt(in, n, out, cap, dic, nd, &t);
#endif
}
static int64_t inf_run(const uint8_t *in, uintptr_t n, uint8_t *out, uintptr_t cap) {
 return inf_rund(in, n, out, cap, 0, 0); }

// raw DEFLATE for C callers with no g (kmain's initrd)
intptr_t inflate_raw(const unsigned char *in, uintptr_t n, unsigned char *out, uintptr_t cap) {
 return (intptr_t) inf_run(in, n, out, cap); }
intptr_t inflate_dict(const unsigned char *in, uintptr_t n, unsigned char *out, uintptr_t cap,
                         const unsigned char *dic, uintptr_t nd) {
 return (intptr_t) inf_rund(in, n, out, cap, dic, nd); }
