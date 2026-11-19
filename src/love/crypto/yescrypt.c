// src/love/crypto/yescrypt.c -- yescrypt's kdf, ported from its reference implementation
//   (yescrypt-kdf scratch pw salt prm) -> 32 bytes | () misuse
//   prm (flags N r p t): flags 0 is classic scrypt (t 0), 0xb6 yescrypt's rw defaults; scratch
//   a cask of (yescrypt-room N r p) bytes or more
//   (yescrypt-room N r p) -> the bytes a kdf over N r p takes
// the $y$ string, its decoding and its last steps are crypt.l's
#include "love.h"
#include "bytes.h"
#include <stdint.h>
#include <string.h>

#define YRw 0x002u
#define YRwDefaults 0x0b6u                    // rw, 6 rounds, gather 4, simple 2, 12k sboxes
#define YPrehash 0x10000000u
#define PwxBytes 64                           // gather 4 * simple 2 * 8
#define PwxWords 16
#define SBytes 12288                          // 3 boxes of 256 pairs of words, twice
#define SWords 3072
#define SMask 4080                            // (256 - 1) * 2 * 8
#define YPmax 16

static void hmac256(uint8_t out[32], void const *k, uintptr_t kn, void const *m, uintptr_t mn) {
 uint8_t key[64] = {0}, pad[64];
 struct sha256s s;
 if (kn > 64) sha256s_init(&s), sha256s_feed(&s, k, kn), sha256s_done(&s, key);
 else memcpy(key, k, kn);
 for (int i = 0; i < 64; i++) pad[i] = key[i] ^ 0x36;
 sha256s_init(&s), sha256s_feed(&s, pad, 64), sha256s_feed(&s, m, mn), sha256s_done(&s, out);
 for (int i = 0; i < 64; i++) pad[i] = key[i] ^ 0x5c;
 sha256s_init(&s), sha256s_feed(&s, pad, 64), sha256s_feed(&s, out, 32), sha256s_done(&s, out); }

// pbkdf2-hmac-sha256 at one iteration, all yescrypt asks of it
static void pbkdf1(uint8_t const *p, uintptr_t pn, uint8_t const *s, uintptr_t sn, uint8_t *out, uintptr_t on) {
 uint8_t key[64] = {0}, ip[64], op[64], u[32], c[4];
 struct sha256s h;
 if (pn > 64) sha256s_init(&h), sha256s_feed(&h, p, pn), sha256s_done(&h, key);
 else memcpy(key, p, pn);
 for (int i = 0; i < 64; i++) ip[i] = key[i] ^ 0x36, op[i] = key[i] ^ 0x5c;
 for (uint32_t i = 1; on; i++) {
  st32be(c, i);
  sha256s_init(&h), sha256s_feed(&h, ip, 64), sha256s_feed(&h, s, sn), sha256s_feed(&h, c, 4), sha256s_done(&h, u);
  sha256s_init(&h), sha256s_feed(&h, op, 64), sha256s_feed(&h, u, 32), sha256s_done(&h, u);
  uintptr_t n = on < 32 ? on : 32;
  memcpy(out, u, n);
  out += n, on -= n; } }

static void blkcpy(uint32_t *d, uint32_t const *s, uintptr_t n) { memcpy(d, s, 4 * n); }
static void blkxor(uint32_t *d, uint32_t const *s, uintptr_t n) { for (uintptr_t i = 0; i < n; i++) d[i] ^= s[i]; }

#define R(a, b) ((a) << (b) | (a) >> (32 - (b)))
// salsa20's core over a block kept in its shuffled order (word i at i * 5 % 16)
static void salsa(uint32_t b[16], int rounds) {
 uint32_t x[16];
 for (int i = 0; i < 16; i++) x[i * 5 % 16] = b[i];
 for (int i = 0; i < rounds; i += 2) {
  x[4] ^= R(x[0] + x[12], 7), x[8] ^= R(x[4] + x[0], 9), x[12] ^= R(x[8] + x[4], 13), x[0] ^= R(x[12] + x[8], 18);
  x[9] ^= R(x[5] + x[1], 7), x[13] ^= R(x[9] + x[5], 9), x[1] ^= R(x[13] + x[9], 13), x[5] ^= R(x[1] + x[13], 18);
  x[14] ^= R(x[10] + x[6], 7), x[2] ^= R(x[14] + x[10], 9), x[6] ^= R(x[2] + x[14], 13), x[10] ^= R(x[6] + x[2], 18);
  x[3] ^= R(x[15] + x[11], 7), x[7] ^= R(x[3] + x[15], 9), x[11] ^= R(x[7] + x[3], 13), x[15] ^= R(x[11] + x[7], 18);
  x[1] ^= R(x[0] + x[3], 7), x[2] ^= R(x[1] + x[0], 9), x[3] ^= R(x[2] + x[1], 13), x[0] ^= R(x[3] + x[2], 18);
  x[6] ^= R(x[5] + x[4], 7), x[7] ^= R(x[6] + x[5], 9), x[4] ^= R(x[7] + x[6], 13), x[5] ^= R(x[4] + x[7], 18);
  x[11] ^= R(x[10] + x[9], 7), x[8] ^= R(x[11] + x[10], 9), x[9] ^= R(x[8] + x[11], 13), x[10] ^= R(x[9] + x[8], 18);
  x[12] ^= R(x[15] + x[14], 7), x[13] ^= R(x[12] + x[15], 9), x[14] ^= R(x[13] + x[12], 13), x[15] ^= R(x[14] + x[13], 18); }
 for (int i = 0; i < 16; i++) b[i] += x[i * 5 % 16]; }
#undef R

// scrypt's blockmix over salsa20/8, y the same 128r bytes as b
static void mix8(uint32_t *b, uint32_t *y, uintptr_t r) {
 uint32_t x[16];
 blkcpy(x, b + (2 * r - 1) * 16, 16);
 for (uintptr_t i = 0; i < 2 * r; i++) blkxor(x, b + i * 16, 16), salsa(x, 8), blkcpy(y + i * 16, x, 16);
 for (uintptr_t i = 0; i < r; i++) blkcpy(b + i * 16, y + 2 * i * 16, 16), blkcpy(b + (i + r) * 16, y + (2 * i + 1) * 16, 16); }

// the three sboxes as pairs of words, s0 and s1 read, s2 written at w
struct pwx { uint32_t *s, (*s0)[2], (*s1)[2], (*s2)[2]; uintptr_t w; };

static void pwxform(uint32_t *b, struct pwx *c) {
 uint32_t (*x)[2][2] = (uint32_t (*)[2][2]) b, (*s0)[2] = c->s0, (*s1)[2] = c->s1, (*s2)[2] = c->s2;
 uintptr_t w = c->w;
 for (int i = 0; i < 6; i++)
  for (int j = 0; j < 4; j++) {
   uint32_t (*p0)[2] = s0 + (x[j][0][0] & SMask) / 8, (*p1)[2] = s1 + (x[j][0][1] & SMask) / 8;
   for (int k = 0; k < 2; k++) {
    uint64_t a = (uint64_t) x[j][k][1] * x[j][k][0];
    a += (uint64_t) p0[k][1] << 32 | p0[k][0];
    a ^= (uint64_t) p1[k][1] << 32 | p1[k][0];
    x[j][k][0] = (uint32_t) a, x[j][k][1] = (uint32_t) (a >> 32);
    if (i && i != 5) s2[w][0] = (uint32_t) a, s2[w][1] = (uint32_t) (a >> 32), w++; } }
 c->s0 = s2, c->s1 = s0, c->s2 = s1;
 c->w = w & 511; }

// blockmix over pwxform, then salsa20/2 on the last 64-byte sub-block and on past it
static void mixpwx(uint32_t *b, struct pwx *c, uintptr_t r) {
 uint32_t x[PwxWords];
 uintptr_t r1 = 128 * r / PwxBytes, i;
 blkcpy(x, b + (r1 - 1) * PwxWords, PwxWords);
 for (i = 0; i < r1; i++) {
  if (r1 > 1) blkxor(x, b + i * PwxWords, PwxWords);
  pwxform(x, c);
  blkcpy(b + i * PwxWords, x, PwxWords); }
 i = (r1 - 1) * PwxBytes / 64;
 salsa(b + i * 16, 2);
 for (i++; i < 2 * r; i++) blkxor(b + i * 16, b + (i - 1) * 16, 16), salsa(b + i * 16, 2); }

static void ymix(uint32_t *x, uint32_t *y, uintptr_t r, struct pwx *c) { if (c) mixpwx(x, c, r); else mix8(x, y, r); }

// the last sub-block's words 0 and 13, low then high: its first 64 bits once unshuffled
static uint64_t integerify(uint32_t const *b, uintptr_t r) {
 uint32_t const *x = b + (2 * r - 1) * 16;
 return (uint64_t) x[13] << 32 | x[0]; }
static uint64_t p2floor(uint64_t x) { uint64_t y; while ((y = x & (x - 1))) x = y; return x; }
static uint64_t wrap(uint64_t x, uint64_t i) { uint64_t n = p2floor(i); return (x & (n - 1)) + (i - n); }

// b's bytes into x's shuffled words, and back
static void shuf_in(uint32_t *x, uint32_t const *b, uintptr_t r) {
 for (uintptr_t k = 0; k < 2 * r; k++)
  for (int i = 0; i < 16; i++) x[k * 16 + i] = ld32le((uint8_t const *) &b[k * 16 + i * 5 % 16]); }
static void shuf_out(uint32_t *b, uint32_t const *x, uintptr_t r) {
 for (uintptr_t k = 0; k < 2 * r; k++)
  for (int i = 0; i < 16; i++) {
   uint8_t *q = (uint8_t *) &b[k * 16 + i * 5 % 16];
   uint32_t v = x[k * 16 + i];
   q[0] = (uint8_t) v, q[1] = (uint8_t) (v >> 8), q[2] = (uint8_t) (v >> 16), q[3] = (uint8_t) (v >> 24); } }

static void smix1(uint32_t *b, uintptr_t r, uint64_t n, unsigned fl, uint32_t *v, uint32_t *xy, struct pwx *c) {
 uintptr_t s = 32 * r;
 uint32_t *x = xy, *y = xy + s;
 shuf_in(x, b, r);
 for (uint64_t i = 0; i < n; i++) {
  blkcpy(v + i * s, x, s);
  if ((fl & YRw) && i > 1) blkxor(x, v + wrap(integerify(x, r), i) * s, s);
  ymix(x, y, r, c); }
 shuf_out(b, x, r); }

static void smix2(uint32_t *b, uintptr_t r, uint64_t n, uint64_t loops, unsigned fl, uint32_t *v, uint32_t *xy, struct pwx *c) {
 uintptr_t s = 32 * r;
 uint32_t *x = xy, *y = xy + s;
 shuf_in(x, b, r);
 for (uint64_t i = 0; i < loops; i++) {
  uint64_t j = integerify(x, r) & (n - 1);
  blkxor(x, v + j * s, s);
  if (fl & YRw) blkcpy(v + j * s, x, s);
  ymix(x, y, r, c); }
 shuf_out(b, x, r); }

static void smix(uint32_t *b, uintptr_t r, uint64_t n, uint32_t p, uint32_t t, unsigned fl,
                 uint32_t *v, uint32_t *xy, struct pwx *c, uint8_t *pw) {
 uintptr_t s = 32 * r;
 uint64_t chunk = n / p, all = chunk, rw = 0;
 if (fl & YRw) {
  if (t <= 1) { if (t) all *= 2; all = (all + 2) / 3; }
  else all *= t - 1; }
 else if (t) { if (t == 1) all += (all + 1) / 2; all *= t; }
 if (fl & YRw) rw = all / p;
 chunk &= ~(uint64_t) 1;
 all = (all + 1) & ~(uint64_t) 1;
 rw = (rw + 1) & ~(uint64_t) 1;
 uint64_t vc = 0;
 for (uint32_t i = 0; i < p; i++, vc += chunk) {
  uint64_t np = i < p - 1 ? chunk : n - vc;
  uint32_t *bp = b + i * s, *vp = v + vc * s;
  struct pwx *ci = 0;
  if (fl & YRw) {
   ci = &c[i];
   smix1(bp, 1, SBytes / 128, 0, ci->s, xy, 0);
   ci->s2 = (uint32_t (*)[2]) ci->s, ci->s1 = ci->s2 + 512, ci->s0 = ci->s1 + 512, ci->w = 0;
   if (!i) hmac256(pw, bp + s - 16, 64, pw, 32); }
  smix1(bp, r, np, fl, vp, xy, ci);
  smix2(bp, r, p2floor(np), rw, fl, vp, xy, ci); }
 for (uint32_t i = 0; i < p; i++) smix2(b + i * s, r, n, all - rw, fl & ~YRw, v, xy, (fl & YRw) ? &c[i] : 0); }

// the bytes a body over N r p takes: V, B, XY, the sboxes, each 8-aligned by its size
static uint64_t yroom(uint64_t n, uint64_t r, uint64_t p) { return 128 * r * n + 128 * r * p + 256 * r + (uint64_t) SBytes * p; }

static int ybody(uint8_t *room, uint8_t const *pw, uintptr_t pn, uint8_t const *salt, uintptr_t sn,
                 unsigned fl, uint64_t n, uint32_t r, uint32_t p, uint32_t t, uint8_t out[32]) {
 uint32_t *v = (uint32_t *) room, *b = v + 32 * r * n, *xy = b + 32 * r * p, *sb = xy + 64 * r;
 struct pwx c[YPmax];
 uint8_t h[32], dk[32];
 uintptr_t bn = (uintptr_t) 128 * r * p;
 if (fl) hmac256(h, "yescrypt-prehash", (fl & YPrehash) ? 16 : 8, pw, pn), pw = h, pn = 32;
 pbkdf1(pw, pn, salt, sn, (uint8_t *) b, bn);
 if (fl) memcpy(h, b, 32);
 if (fl & YRw) {
  for (uint32_t i = 0; i < p; i++) c[i].s = sb + i * SWords;
  smix(b, r, n, p, t, fl, v, xy, c, h); }
 else for (uint32_t i = 0; i < p; i++) smix(b + 32 * r * i, r, n, 1, t, fl, v, xy, 0, 0);
 pbkdf1(pw, pn, (uint8_t *) b, bn, dk, 32);
 if (fl && !(fl & YPrehash)) {
  struct sha256s s;
  hmac256(h, dk, 32, "Client Key", 10);
  sha256s_init(&s), sha256s_feed(&s, h, 32), sha256s_done(&s, dk); }
 memcpy(out, dk, 32);
 return 0; }

static bool yok(unsigned fl, uint64_t n, uint32_t r, uint32_t p, uint32_t t) {
 if (fl != 0 && fl != YRwDefaults) return false;
 if (!fl && t) return false;
 if (n < 2 || (n & (n - 1)) || r < 1 || p < 1 || p > YPmax || (uint64_t) r * p >= 1u << 30) return false;
 if (n > ((uint64_t) 1 << 40) / r || (fl & YRw && n / p <= 1)) return false;
 return true; }

static bool yprm(word l, uint64_t v[5]) {
 for (int i = 0; i < 5; i++, l = B(l)) {
  if (!chainp(l) || !charmp(A(l)) || getcharm(A(l)) < 0) return false;
  v[i] = (uint64_t) getcharm(A(l)); }
 return true; }

love_noinline static struct g *host_ykdf(struct g *g) {
 word cw = g->sp[0], pw = g->sp[1], sw = g->sp[2];
 uint64_t v[5];
 uintptr_t cn;
 uint8_t *room = cask_bytes(cw, &cn), out[32], dk[32];
 if (!room || !strp(pw) || !strp(sw) || !yprm(g->sp[3], v) || v[2] > UINT32_MAX || v[3] > UINT32_MAX || v[4] > UINT32_MAX
     || !yok((unsigned) v[0], v[1], (uint32_t) v[2], (uint32_t) v[3], (uint32_t) v[4])
     || yroom(v[1], v[2], v[3]) > cn)
  return g->sp[3] = ZeroPoint, g->sp += 3, g;
 unsigned fl = (unsigned) v[0];
 uint64_t n = v[1];
 uint32_t r = (uint32_t) v[2], p = (uint32_t) v[3], t = (uint32_t) v[4];
 uint8_t const *pp = (uint8_t const *) txt(pw);
 uintptr_t pn = len(pw);
 // a big rw run first hashes the password through one 64 times smaller
 if ((fl & YRw) && n / p >= 256 && n / p * r >= 0x20000) {
  ybody(room, pp, pn, (uint8_t const *) txt(sw), len(sw), fl | YPrehash, n >> 6, r, p, 0, dk);
  pp = dk, pn = 32; }
 ybody(room, pp, pn, (uint8_t const *) txt(sw), len(sw), fl, n, r, p, t, out);
 memset(dk, 0, 32);
 if (!ok(g = str0(g, 32))) return g;
 memcpy(txt(g->sp[0]), out, 32);
 memset(out, 0, 32);
 g->sp[4] = g->sp[0], g->sp += 4;
 return g; }
static lvm(lvm_ykdf) LvmCall(g, host_ykdf)

static lvm(lvm_yroom) {
 word n = Sp[0], r = Sp[1], p = Sp[2];
 Sp[2] = charmp(n) && charmp(r) && charmp(p) && getcharm(n) > 0 && getcharm(r) > 0 && getcharm(p) > 0
         && getcharm(n) <= (int64_t) 1 << 40 && getcharm(r) < 1L << 20 && getcharm(p) <= YPmax
         ? putcharm((intptr_t) yroom((uint64_t) getcharm(n), (uint64_t) getcharm(r), (uint64_t) getcharm(p))) : ZeroPoint;
 love_musttail return Nextp(1, 2); }

LvDef("yescrypt-kdf", ykdf, 4, "crypt");
LvDef("yescrypt-room", yroom, 3, "crypt");
