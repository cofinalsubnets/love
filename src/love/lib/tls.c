// src/love/lib/tls.c
// (chacha20 key nonce ctr txt) -> a string as long as txt   | () misuse
// (poly1305 key msg)           -> the 16-byte tag           | () misuse
// (aes-gcm-seal key iv aad pt) -> ct and tag; (aes-gcm-open key iv aad ctag) -> pt | ()
#include "love.h"
#include "bytes.h"
#include <stdint.h>
#include <string.h>

// --- chacha20 (rfc 8439 §2.3) -----------------------------------------------------
#define ROTL(x, n) (((x) << (n)) | ((x) >> (32 - (n))))
#define QR(a, b, c, d) \
 (a += b, d ^= a, d = ROTL(d, 16), c += d, b ^= c, b = ROTL(b, 12), \
  a += b, d ^= a, d = ROTL(d, 8),  c += d, b ^= c, b = ROTL(b, 7))

// one 20-round block, keystream out little-endian.
static void cc_block(const uint32_t in[16], uint8_t out[64]) {
 uint32_t x[16];
 memcpy(x, in, sizeof x);
 for (int i = 0; i < 10; i++)
  QR(x[0], x[4], x[8],  x[12]), QR(x[1], x[5], x[9],  x[13]),
  QR(x[2], x[6], x[10], x[14]), QR(x[3], x[7], x[11], x[15]),
  QR(x[0], x[5], x[10], x[15]), QR(x[1], x[6], x[11], x[12]),
  QR(x[2], x[7], x[8],  x[13]), QR(x[3], x[4], x[9],  x[14]);
 for (int i = 0; i < 16; i++) {
  uint32_t v = x[i] + in[i];
  out[4*i] = (uint8_t) v;         out[4*i+1] = (uint8_t) (v >> 8);
  out[4*i+2] = (uint8_t) (v >> 16); out[4*i+3] = (uint8_t) (v >> 24); } }

// xor txt with the keystream from block ctr on. encrypt and decrypt are one act.
static void cc_xor(const uint8_t *key, const uint8_t *nonce, uint32_t ctr,
                   const uint8_t *txt, uint8_t *out, uintptr_t n) {
 uint32_t st[16] = {0x61707865, 0x3320646e, 0x79622d32, 0x6b206574};
 uint8_t ks[64];
 for (int i = 0; i < 8; i++)  st[4 + i] = ld32le(key + 4*i);
 for (int i = 0; i < 3; i++)  st[13 + i] = ld32le(nonce + 4*i);
 for (uintptr_t o = 0; o < n; o += 64) {
  uintptr_t r = n - o < 64 ? n - o : 64;
  st[12] = ctr + (uint32_t) (o / 64);
  cc_block(st, ks);
  for (uintptr_t j = 0; j < r; j++) out[o + j] = txt[o + j] ^ ks[j]; } }

// --- poly1305 (rfc 8439 §2.5), five 26-bit limbs ----------------------------------
#define M26 0x3ffffff

// r, clamped by the masks folded into the split (§2.5.1).
static void po_r(const uint8_t *k, uint64_t r[5]) {
 uint32_t t0 = ld32le(k), t1 = ld32le(k + 4), t2 = ld32le(k + 8), t3 = ld32le(k + 12);
 r[0] = t0 & M26;
 r[1] = ((t0 >> 26) | (t1 << 6))  & 0x3ffff03;
 r[2] = ((t1 >> 20) | (t2 << 12)) & 0x3ffc0ff;
 r[3] = ((t2 >> 14) | (t3 << 18)) & 0x3f03fff;
 r[4] = (t3 >> 8) & 0x00fffff; }

// h += the 16 bytes at p; hi is the 2^128 term (2^24 for a full block, 0 for the
// padded final one, whose 0x01 already sits inside the sixteen).
static void po_absorb(uint64_t h[5], const uint8_t *p, uint64_t hi) {
 uint32_t t0 = ld32le(p), t1 = ld32le(p + 4), t2 = ld32le(p + 8), t3 = ld32le(p + 12);
 h[0] += t0 & M26;
 h[1] += ((t0 >> 26) | ((uint64_t) t1 << 6))  & M26;
 h[2] += ((t1 >> 20) | ((uint64_t) t2 << 12)) & M26;
 h[3] += ((t2 >> 14) | ((uint64_t) t3 << 18)) & M26;
 h[4] += (t3 >> 8) | hi; }

// h = h * r mod 2^130 - 5. the modulus never appears: what runs past 2^130 comes
// back at the bottom times five, which is what the s1..s4 terms are.
static void po_mul(uint64_t h[5], const uint64_t r[5]) {
 uint64_t
  h0 = h[0], h1 = h[1], h2 = h[2], h3 = h[3], h4 = h[4],
  s1 = r[1] * 5, s2 = r[2] * 5, s3 = r[3] * 5, s4 = r[4] * 5,
  d0 = h0*r[0] + h1*s4   + h2*s3   + h3*s2   + h4*s1,
  d1 = h0*r[1] + h1*r[0] + h2*s4   + h3*s3   + h4*s2,
  d2 = h0*r[2] + h1*r[1] + h2*r[0] + h3*s4   + h4*s3,
  d3 = h0*r[3] + h1*r[2] + h2*r[1] + h3*r[0] + h4*s4,
  d4 = h0*r[4] + h1*r[3] + h2*r[2] + h3*r[1] + h4*r[0],
  c;
 c = d0 >> 26; h[0] = d0 & M26;
 d1 += c; c = d1 >> 26; h[1] = d1 & M26;
 d2 += c; c = d2 >> 26; h[2] = d2 & M26;
 d3 += c; c = d3 >> 26; h[3] = d3 & M26;
 d4 += c; c = d4 >> 26; h[4] = d4 & M26;
 h[0] += c * 5; c = h[0] >> 26; h[0] &= M26; h[1] += c; }

// the conditional subtract is a mask, never an if: both h and h-p are always
// computed and one is selected, so nothing branches on the accumulator.
static void po_fin(const uint64_t h[5], const uint8_t *key, uint8_t out[16]) {
 int64_t
  h0 = (int64_t) h[0], h1 = (int64_t) h[1], h2 = (int64_t) h[2],
  h3 = (int64_t) h[3], h4 = (int64_t) h[4],
  c1 = h1 >> 26,       i1 = h1 & M26,
  a2 = h2 + c1, c2 = a2 >> 26, i2 = a2 & M26,
  a3 = h3 + c2, c3 = a3 >> 26, i3 = a3 & M26,
  a4 = h4 + c3, c4 = a4 >> 26, i4 = a4 & M26,
  a0 = h0 + c4 * 5, c0 = a0 >> 26, i0 = a0 & M26,
  j1 = i1 + c0,
  // g = h - p, as h + 5 - 2^130: the top limb goes negative exactly when h < p
  b0 = i0 + 5,  k0 = b0 >> 26, n0 = b0 & M26,
  b1 = j1 + k0, k1 = b1 >> 26, n1 = b1 & M26,
  b2 = i2 + k1, k2 = b2 >> 26, n2 = b2 & M26,
  b3 = i3 + k2, k3 = b3 >> 26, n3 = b3 & M26,
  n4 = (i4 + k3) - 0x4000000,
  keep = n4 >> 63, drop = ~keep,
  p0 = (i0 & keep) | (n0 & drop), p1 = (j1 & keep) | (n1 & drop),
  p2 = (i2 & keep) | (n2 & drop), p3 = (i3 & keep) | (n3 & drop),
  p4 = (i4 & keep) | (n4 & drop);
 uint64_t w[4], f = 0;
 w[0] = (uint64_t) (p0 | (p1 << 26)) & 0xffffffff;
 w[1] = (uint64_t) ((p1 >> 6)  | (p2 << 20)) & 0xffffffff;
 w[2] = (uint64_t) ((p2 >> 12) | (p3 << 14)) & 0xffffffff;
 w[3] = (uint64_t) ((p3 >> 18) | (p4 << 8))  & 0xffffffff;
 for (int i = 0; i < 4; i++) {
  f = w[i] + ld32le(key + 16 + 4*i) + (f >> 32);
  out[4*i] = (uint8_t) f;           out[4*i+1] = (uint8_t) (f >> 8);
  out[4*i+2] = (uint8_t) (f >> 16); out[4*i+3] = (uint8_t) (f >> 24); } }

static void po_mac(const uint8_t *key, const uint8_t *msg, uintptr_t n,
                   uint8_t out[16]) {
 uint64_t r[5], h[5] = {0, 0, 0, 0, 0};
 uintptr_t i = 0;
 po_r(key, r);
 for (; i + 16 <= n; i += 16) { po_absorb(h, msg + i, 0x1000000); po_mul(h, r); }
 if (i < n) {
  uint8_t pad[16];
  memcpy(pad, msg + i, n - i);
  pad[n - i] = 1;
  memset(pad + (n - i) + 1, 0, 16 - (n - i) - 1);
  po_absorb(h, pad, 0); po_mul(h, r); }
 po_fin(h, key, out); }

// --- aes (fips 197) and gcm (sp 800-38d) ---------------------------------------------
// the s-box is a table, so an encryption's memory reads follow its key and data: not
// constant time against a cache-watching neighbour. ghash is masks, never a branch.
static uint8_t const aes_sbox[256] = {
 0x63,0x7c,0x77,0x7b,0xf2,0x6b,0x6f,0xc5,0x30,0x01,0x67,0x2b,0xfe,0xd7,0xab,0x76,
 0xca,0x82,0xc9,0x7d,0xfa,0x59,0x47,0xf0,0xad,0xd4,0xa2,0xaf,0x9c,0xa4,0x72,0xc0,
 0xb7,0xfd,0x93,0x26,0x36,0x3f,0xf7,0xcc,0x34,0xa5,0xe5,0xf1,0x71,0xd8,0x31,0x15,
 0x04,0xc7,0x23,0xc3,0x18,0x96,0x05,0x9a,0x07,0x12,0x80,0xe2,0xeb,0x27,0xb2,0x75,
 0x09,0x83,0x2c,0x1a,0x1b,0x6e,0x5a,0xa0,0x52,0x3b,0xd6,0xb3,0x29,0xe3,0x2f,0x84,
 0x53,0xd1,0x00,0xed,0x20,0xfc,0xb1,0x5b,0x6a,0xcb,0xbe,0x39,0x4a,0x4c,0x58,0xcf,
 0xd0,0xef,0xaa,0xfb,0x43,0x4d,0x33,0x85,0x45,0xf9,0x02,0x7f,0x50,0x3c,0x9f,0xa8,
 0x51,0xa3,0x40,0x8f,0x92,0x9d,0x38,0xf5,0xbc,0xb6,0xda,0x21,0x10,0xff,0xf3,0xd2,
 0xcd,0x0c,0x13,0xec,0x5f,0x97,0x44,0x17,0xc4,0xa7,0x7e,0x3d,0x64,0x5d,0x19,0x73,
 0x60,0x81,0x4f,0xdc,0x22,0x2a,0x90,0x88,0x46,0xee,0xb8,0x14,0xde,0x5e,0x0b,0xdb,
 0xe0,0x32,0x3a,0x0a,0x49,0x06,0x24,0x5c,0xc2,0xd3,0xac,0x62,0x91,0x95,0xe4,0x79,
 0xe7,0xc8,0x37,0x6d,0x8d,0xd5,0x4e,0xa9,0x6c,0x56,0xf4,0xea,0x65,0x7a,0xae,0x08,
 0xba,0x78,0x25,0x2e,0x1c,0xa6,0xb4,0xc6,0xe8,0xdd,0x74,0x1f,0x4b,0xbd,0x8b,0x8a,
 0x70,0x3e,0xb5,0x66,0x48,0x03,0xf6,0x0e,0x61,0x35,0x57,0xb9,0x86,0xc1,0x1d,0x9e,
 0xe1,0xf8,0x98,0x11,0x69,0xd9,0x8e,0x94,0x9b,0x1e,0x87,0xe9,0xce,0x55,0x28,0xdf,
 0x8c,0xa1,0x89,0x0d,0xbf,0xe6,0x42,0x68,0x41,0x99,0x2d,0x0f,0xb0,0x54,0xbb,0x16};

// a key's schedule: 11 or 15 round keys of 16 bytes, and the round count
struct aes_ks { uint8_t rk[240]; int nr; };
static void aes_expand(struct aes_ks *s, const uint8_t *key, int kl) {
 int nk = kl / 4, nw = 4 * (nk + 7);
 uint8_t rc = 1;
 s->nr = nk + 6;
 memcpy(s->rk, key, (size_t) kl);
 for (int i = nk; i < nw; i++) {
  uint8_t t[4];
  memcpy(t, s->rk + 4 * (i - 1), 4);
  if (i % nk == 0) {
   uint8_t u = t[0];
   t[0] = aes_sbox[t[1]] ^ rc, t[1] = aes_sbox[t[2]], t[2] = aes_sbox[t[3]], t[3] = aes_sbox[u];
   rc = (uint8_t) ((rc << 1) ^ ((rc >> 7) * 0x1b)); }
  else if (nk > 6 && i % nk == 4)
   for (int j = 0; j < 4; j++) t[j] = aes_sbox[t[j]];
  for (int j = 0; j < 4; j++) s->rk[4 * i + j] = s->rk[4 * (i - nk) + j] ^ t[j]; } }

static uint8_t xt(uint8_t b) { return (uint8_t) ((b << 1) ^ ((b >> 7) * 0x1b)); }
static void aes_block(const struct aes_ks *s, const uint8_t in[16], uint8_t out[16]) {
 uint8_t a[16], b[16];
 for (int i = 0; i < 16; i++) a[i] = in[i] ^ s->rk[i];
 for (int r = 1; r <= s->nr; r++) {
  for (int c = 0; c < 4; c++)                     // sub bytes and shift rows at once
   for (int j = 0; j < 4; j++) b[4 * c + j] = aes_sbox[a[4 * ((c + j) % 4) + j]];
  if (r < s->nr)
   for (int c = 0; c < 4; c++) {                  // mix columns
    uint8_t *p = b + 4 * c, x = p[0] ^ p[1] ^ p[2] ^ p[3], p0 = p[0];
    p[0] ^= x ^ xt(p[0] ^ p[1]); p[1] ^= x ^ xt(p[1] ^ p[2]);
    p[2] ^= x ^ xt(p[2] ^ p[3]); p[3] ^= x ^ xt(p[3] ^ p0); }
  for (int i = 0; i < 16; i++) a[i] = b[i] ^ s->rk[16 * r + i]; }
 memcpy(out, a, 16); }

static void put64(uint8_t *p, uint64_t v) { for (int i = 7; i >= 0; i--) p[i] = (uint8_t) v, v >>= 8; }

// y = (y ^ x) * h in gf(2^128), gcm's bit order: shift and mask, 128 steps, no branch
static void gh_mul(uint64_t y[2], const uint8_t x[16], const uint64_t h[2]) {
 uint64_t x0 = y[0] ^ ld64be(x), x1 = y[1] ^ ld64be(x + 8), z0 = 0, z1 = 0, v0 = h[0], v1 = h[1];
 for (int i = 0; i < 128; i++) {
  uint64_t bit = i < 64 ? x0 >> (63 - i) : x1 >> (127 - i), m = 0 - (bit & 1), lsb = 0 - (v1 & 1);
  z0 ^= v0 & m, z1 ^= v1 & m;
  v1 = (v1 >> 1) | (v0 << 63), v0 = (v0 >> 1) ^ (0xe100000000000000ull & lsb); }
 y[0] = z0, y[1] = z1; }
// ghash of aad then ct, each padded to the block, then their bit lengths
static void gh_all(const uint64_t h[2], const uint8_t *aad, uintptr_t na,
                   const uint8_t *ct, uintptr_t nc, uint8_t out[16]) {
 uint64_t y[2] = {0, 0};
 uint8_t blk[16];
 for (int k = 0; k < 2; k++) {
  const uint8_t *p = k ? ct : aad;
  uintptr_t n = k ? nc : na;
  for (uintptr_t i = 0; i < n; i += 16) {
   uintptr_t r = n - i < 16 ? n - i : 16;
   memset(blk, 0, 16), memcpy(blk, p + i, r);
   gh_mul(y, blk, h); } }
 put64(blk, (uint64_t) na * 8), put64(blk + 8, (uint64_t) nc * 8);
 gh_mul(y, blk, h);
 put64(out, y[0]), put64(out + 8, y[1]); }

// the counter run from j0 + 1 over n bytes, and the tag's mask off j0 itself
static void gcm_ctr(const struct aes_ks *s, const uint8_t iv[12], const uint8_t *in,
                    uint8_t *out, uintptr_t n) {
 uint8_t cb[16], ks[16];
 memcpy(cb, iv, 12);
 for (uintptr_t i = 0; i < n; i += 16) {
  uint32_t c = (uint32_t) (i / 16 + 2);
  cb[12] = (uint8_t) (c >> 24), cb[13] = (uint8_t) (c >> 16), cb[14] = (uint8_t) (c >> 8), cb[15] = (uint8_t) c;
  aes_block(s, cb, ks);
  uintptr_t r = n - i < 16 ? n - i : 16;
  for (uintptr_t j = 0; j < r; j++) out[i + j] = in[i + j] ^ ks[j]; } }
static void gcm_tag(const struct aes_ks *s, const uint8_t iv[12], const uint8_t *aad, uintptr_t na,
                    const uint8_t *ct, uintptr_t nc, uint8_t tag[16]) {
 uint8_t z[16] = {0}, hb[16], j0[16], e[16];
 aes_block(s, z, hb);
 uint64_t h[2] = {ld64be(hb), ld64be(hb + 8)};
 memcpy(j0, iv, 12), j0[12] = j0[13] = j0[14] = 0, j0[15] = 1;
 aes_block(s, j0, e);
 gh_all(h, aad, na, ct, nc, tag);
 for (int i = 0; i < 16; i++) tag[i] ^= e[i]; }

// --- the nifs -----------------------------------------------------------------------
// str0 can collect, so the result is allocated first and the arguments re-read
// off the stack after it: the pointers a C local held are stale across the bump.
// FIXME why is this noinline?
static love_inline struct g *host_chacha20(struct g *g) {
 word kw = g->sp[0], nw = g->sp[1], cw = g->sp[2], tw = g->sp[3];
 if (!strp(kw) || !strp(nw) || !strp(tw) || !oddp(cw)
     || len(kw) != 32 || len(nw) != 12 || getcharm(cw) < 0) {
  g->sp[3] = ZeroPoint, g->sp += 3; return g; }
 uintptr_t n = len(tw);
 uint32_t ctr = (uint32_t) getcharm(cw);
 if (!ok(g = str0(g, n))) return g;             // pushes: out over the four args
 cc_xor((const uint8_t*) txt(g->sp[1]), (const uint8_t*) txt(g->sp[2]), ctr,
        (const uint8_t*) txt(g->sp[4]), (uint8_t*) txt(g->sp[0]), n);
 g->sp[4] = g->sp[0], g->sp += 4;
 return g; }

static lvm(lvm_chacha20) LvmCall(g, host_chacha20)

love_noinline static struct g *host_poly1305(struct g *g) {
 word kw = g->sp[0], mw = g->sp[1];
 if (!strp(kw) || !strp(mw) || len(kw) != 32)
  return g->sp[1] = ZeroPoint, g->sp += 1, g;
 uintptr_t n = len(mw);
 uint8_t tag[16];
 po_mac((const uint8_t*) txt(kw), (const uint8_t*) txt(mw), n, tag);
 if (!ok(g = str0(g, 16))) return g;            // pushes: tag over the two args
 memcpy(txt(g->sp[0]), tag, 16);
 g->sp[2] = g->sp[0], g->sp += 2;
 return g; }
static lvm(lvm_poly1305) LvmCall(g, host_poly1305)

// (aes-gcm-seal key iv aad pt) -> ct and its 16-byte tag; (aes-gcm-open key iv aad ctag)
// -> pt, or () when the tag does not hold -- checked before a byte is deciphered. a key
// of 16 or 32 bytes, a 12-byte iv; anything else is () too
static int gcm_args(struct g *g, int open) {
 word kw = g->sp[0], iw = g->sp[1], aw = g->sp[2], tw = g->sp[3];
 return strp(kw) && strp(iw) && strp(aw) && strp(tw) && (len(kw) == 16 || len(kw) == 32)
     && len(iw) == 12 && (!open || len(tw) >= 16); }
love_noinline static struct g *host_gcm(struct g *g, int open) {
 if (!gcm_args(g, open)) return g->sp[3] = ZeroPoint, g->sp += 3, g;
 struct aes_ks s;
 aes_expand(&s, (const uint8_t*) txt(g->sp[0]), (int) len(g->sp[0]));
 uintptr_t n = len(g->sp[3]) - (open ? 16 : 0);
 if (open) {
  uint8_t tag[16], d = 0;
  gcm_tag(&s, (const uint8_t*) txt(g->sp[1]), (const uint8_t*) txt(g->sp[2]), len(g->sp[2]),
          (const uint8_t*) txt(g->sp[3]), n, tag);
  for (int i = 0; i < 16; i++) d |= tag[i] ^ (uint8_t) txt(g->sp[3])[n + i];
  if (d) return g->sp[3] = ZeroPoint, g->sp += 3, g; }
 if (!ok(g = str0(g, n + (open ? 0 : 16)))) return g;   // pushes: out over the four args
 uint8_t *o = (uint8_t*) txt(g->sp[0]);
 const uint8_t *iv = (const uint8_t*) txt(g->sp[2]), *in = (const uint8_t*) txt(g->sp[4]);
 gcm_ctr(&s, iv, in, o, n);
 if (!open) gcm_tag(&s, iv, (const uint8_t*) txt(g->sp[3]), len(g->sp[3]), o, n, o + n);
 g->sp[4] = g->sp[0], g->sp += 4;
 return g; }
static lvm(lvm_gcm_seal) LvmCall(g, host_gcm, 0)
static lvm(lvm_gcm_open) LvmCall(g, host_gcm, 1)

static union u const
  nif_chacha20[] = {{lvm_cur}, {.x = putcharm(4)}, {lvm_chacha20}, {lvm_ret0}},
  nif_poly1305[] = {{lvm_cur}, {.x = putcharm(2)}, {lvm_poly1305}, {lvm_ret0}},
  nif_gcm_seal[] = {{lvm_cur}, {.x = putcharm(4)}, {lvm_gcm_seal}, {lvm_ret0}},
  nif_gcm_open[] = {{lvm_cur}, {.x = putcharm(4)}, {lvm_gcm_open}, {lvm_ret0}};
LvNif("chacha20", nif_chacha20, NULL);
LvNif("poly1305", nif_poly1305, NULL);
LvNif("aes-gcm-seal", nif_gcm_seal, NULL);
LvNif("aes-gcm-open", nif_gcm_open, NULL);
