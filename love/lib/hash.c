// love/lib/hash.c -- digests over a string's bytes. auto-globbed and LvNif-registered,
// the fs.c discipline; value ops, so absence or misuse answers ().
//   (md5 str) (sha1 str) (sha224 str) (sha256 str) (sha384 str) (sha512 str)
//   (blake2b str) (sha3 str)  -> the lowercase hex digest (blake2b's the 64-byte one,
//                                sha3's the 256-bit one)
//   (crc32 str)               -> the IEEE crc32, a charm; (crc32-on c str) carries c on
//   (cksum str)               -> POSIX cksum's crc with the length folded in, a charm
//   (bsdsum acc str)          -> bsd sum's 16-bit checksum carried on over str
// the others stream too, the state in a cask the caller allocates (the nifs do not):
//   (X-init b) / (X-feed b str) / (X-done b), b a cask of X's width:
//   md5 89, sha1 93, sha224 106, sha256 105, sha384 202, sha512 201, cksum 12;
//   blake2b 210, its init (blake2b-init b n) for an n-byte digest; sha3 204, its init
//   (sha3-init b bits shake) for any length 8..512 (bits under 128 a shake's), shake's pad
//   when shake is truthy
// FIPS 180-4, FIPS 202, RFC 1321, RFC 7693, IEEE 802.3 and POSIX cksum, all the compact
// single-pass shape. apps/kore's checksum tools are these plus a line of output.
// they do not all stand on the same footing. crc32 shadows apps/gz.l's gz-crcwalk and
// cksum test/digest.l's hash-ckwalk -- both polynomials are stated in love and the C
// is held to the walk at every length, so a disagreement has a right answer. sha256 and
// md5 shadow nothing, yet apps/sb's blob and patch ids and apps/moon's cache key rest on
// them; only the published vectors in test/digest.l and GNU coreutils in
// test/gate/kore.sh hold them honest. the fix for that thin rope is a love sha-256.
#include "love.h"
#include <stdint.h>
#include <string.h>

// sha-512's round constants; sha-256's are their high halves (both are the cube roots
// of the first primes, to 64 and to 32 bits)
static uint64_t const K512[80] = {
 0x428a2f98d728ae22ull, 0x7137449123ef65cdull, 0xb5c0fbcfec4d3b2full, 0xe9b5dba58189dbbcull,
 0x3956c25bf348b538ull, 0x59f111f1b605d019ull, 0x923f82a4af194f9bull, 0xab1c5ed5da6d8118ull,
 0xd807aa98a3030242ull, 0x12835b0145706fbeull, 0x243185be4ee4b28cull, 0x550c7dc3d5ffb4e2ull,
 0x72be5d74f27b896full, 0x80deb1fe3b1696b1ull, 0x9bdc06a725c71235ull, 0xc19bf174cf692694ull,
 0xe49b69c19ef14ad2ull, 0xefbe4786384f25e3ull, 0x0fc19dc68b8cd5b5ull, 0x240ca1cc77ac9c65ull,
 0x2de92c6f592b0275ull, 0x4a7484aa6ea6e483ull, 0x5cb0a9dcbd41fbd4ull, 0x76f988da831153b5ull,
 0x983e5152ee66dfabull, 0xa831c66d2db43210ull, 0xb00327c898fb213full, 0xbf597fc7beef0ee4ull,
 0xc6e00bf33da88fc2ull, 0xd5a79147930aa725ull, 0x06ca6351e003826full, 0x142929670a0e6e70ull,
 0x27b70a8546d22ffcull, 0x2e1b21385c26c926ull, 0x4d2c6dfc5ac42aedull, 0x53380d139d95b3dfull,
 0x650a73548baf63deull, 0x766a0abb3c77b2a8ull, 0x81c2c92e47edaee6ull, 0x92722c851482353bull,
 0xa2bfe8a14cf10364ull, 0xa81a664bbc423001ull, 0xc24b8b70d0f89791ull, 0xc76c51a30654be30ull,
 0xd192e819d6ef5218ull, 0xd69906245565a910ull, 0xf40e35855771202aull, 0x106aa07032bbd1b8ull,
 0x19a4c116b8d2d0c8ull, 0x1e376c085141ab53ull, 0x2748774cdf8eeb99ull, 0x34b0bcb5e19b48a8ull,
 0x391c0cb3c5c95a63ull, 0x4ed8aa4ae3418acbull, 0x5b9cca4f7763e373ull, 0x682e6ff3d6b2b8a3ull,
 0x748f82ee5defb2fcull, 0x78a5636f43172f60ull, 0x84c87814a1f0ab72ull, 0x8cc702081a6439ecull,
 0x90befffa23631e28ull, 0xa4506cebde82bde9ull, 0xbef9a3f7b2c67915ull, 0xc67178f2e372532bull,
 0xca273eceea26619cull, 0xd186b8c721c0c207ull, 0xeada7dd6cde0eb1eull, 0xf57d4f7fee6ed178ull,
 0x06f067aa72176fbaull, 0x0a637dc5a2c898a6ull, 0x113f9804bef90daeull, 0x1b710b35131c471bull,
 0x28db77f523047d84ull, 0x32caab7b40c72493ull, 0x3c9ebe0a15c9bebcull, 0x431d67c49c100d4cull,
 0x4cc5d4becb3e42b6ull, 0x597f299cfc657e2aull, 0x5fcb6fab3ad6faecull, 0x6c44198c4a475817ull};

// initial states as 32-bit words, a 64-bit word high half first. sha-256's are
// sha-512's high halves and sha-224's are sha-384's low halves, so each digest names
// its table, a stride and a start; md5's are sha-1's first four. blake2b's iv is sha-512's.
static uint32_t const
 sha512_h0[16] = {
  0x6a09e667,0xf3bcc908, 0xbb67ae85,0x84caa73b, 0x3c6ef372,0xfe94f82b, 0xa54ff53a,0x5f1d36f1,
  0x510e527f,0xade682d1, 0x9b05688c,0x2b3e6c1f, 0x1f83d9ab,0xfb41bd6b, 0x5be0cd19,0x137e2179},
 sha384_h0[16] = {
  0xcbbb9d5d,0xc1059ed8, 0x629a292a,0x367cd507, 0x9159015a,0x3070dd17, 0x152fecd8,0xf70e5939,
  0x67332667,0xffc00b31, 0x8eb44a87,0x68581511, 0xdb0c2e0d,0x64f98fa7, 0x47b5481d,0xbefa4fa4},
 sha1_h0[5] = {0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476, 0xc3d2e1f0},
 MK[64] = { // md5 (rfc1321)
  0xd76aa478,0xe8c7b756,0x242070db,0xc1bdceee,0xf57c0faf,0x4787c62a,0xa8304613,0xfd469501,
  0x698098d8,0x8b44f7af,0xffff5bb1,0x895cd7be,0x6b901122,0xfd987193,0xa679438e,0x49b40821,
  0xf61e2562,0xc040b340,0x265e5a51,0xe9b6c7aa,0xd62f105d,0x02441453,0xd8a1e681,0xe7d3fbc8,
  0x21e1cde6,0xc33707d6,0xf4d50d87,0x455a14ed,0xa9e3e905,0xfcefa3f8,0x676f02d9,0x8d2a4c8a,
  0xfffa3942,0x8771f681,0x6d9d6122,0xfde5380c,0xa4beea44,0x4bdecfa9,0xf6bb4b60,0xbebfbc70,
  0x289b7ec6,0xeaa127fa,0xd4ef3085,0x04881d05,0xd9d4d039,0xe6db99e5,0x1fa27cf8,0xc4ac5665,
  0xf4292244,0x432aff97,0xab9423a7,0xfc93a039,0x655b59c3,0x8f0ccc92,0xffeff47d,0x85845dd1,
  0x6fa87e4f,0xfe2ce6e0,0xa3014314,0x4e0811a1,0xf7537e82,0xbd3af235,0x2ad7d2bb,0xeb86d391};

static uint8_t const MS[64] = {
 7,12,17,22, 7,12,17,22, 7,12,17,22, 7,12,17,22,
 5, 9,14,20, 5, 9,14,20, 5, 9,14,20, 5, 9,14,20,
 4,11,16,23, 4,11,16,23, 4,11,16,23, 4,11,16,23,
 6,10,15,21, 6,10,15,21, 6,10,15,21, 6,10,15,21};

static uint32_t rr(uint32_t x, int n) { return (x >> n) | (x << (32 - n)); }
static ai_inline uint32_t rl(uint32_t x, int n) { return (x << n) | (x >> (32 - n)); }
static ai_inline uint64_t rr64(uint64_t x, int n) { return (x >> n) | (x << (64 - n)); }

static uint32_t ld32be(const uint8_t *p) {
 return (uint32_t) p[0] << 24 | (uint32_t) p[1] << 16 | (uint32_t) p[2] << 8 | p[3]; }
static uint64_t ld64be(const uint8_t *p) { return (uint64_t) ld32be(p) << 32 | ld32be(p + 4); }
static uint64_t ld64le(const uint8_t *p) {
 uint64_t v = 0;
 for (int k = 7; k >= 0; k--) v = v << 8 | p[k];
 return v; }

static void sha_block(uint32_t h[8], const uint8_t *p) {
 uint32_t w[64];
 for (int i = 0; i < 16; i++) w[i] = ld32be(p + 4 * i);
 for (int i = 16; i < 64; i++) {
  uint32_t s0 = rr(w[i - 15], 7) ^ rr(w[i - 15], 18) ^ (w[i - 15] >> 3),
           s1 = rr(w[i - 2], 17) ^ rr(w[i - 2], 19) ^ (w[i - 2] >> 10);
  w[i] = w[i - 16] + s0 + w[i - 7] + s1; }
 uint32_t a = h[0], b = h[1], c = h[2], d = h[3],
          e = h[4], f = h[5], gg = h[6], hh = h[7];
 for (int i = 0; i < 64; i++) {
  uint32_t s1 = rr(e, 6) ^ rr(e, 11) ^ rr(e, 25),
           ch = (e & f) ^ (~e & gg),
           t1 = hh + s1 + ch + (uint32_t) (K512[i] >> 32) + w[i],
           s0 = rr(a, 2) ^ rr(a, 13) ^ rr(a, 22),
           mj = (a & b) ^ (a & c) ^ (b & c),
           t2 = s0 + mj;
  hh = gg; gg = f; f = e; e = d + t1;
  d = c; c = b; b = a; a = t1 + t2; }
 h[0] += a; h[1] += b; h[2] += c; h[3] += d;
 h[4] += e; h[5] += f; h[6] += gg; h[7] += hh; }

// sha-512 keeps its eight 64-bit words as sixteen 32-bit halves, so it rides the same
// buffering and the same state layout as the 32-bit digests
static void sha512_block(uint32_t h[16], const uint8_t *p) {
 uint64_t w[80], v[8];
 for (int i = 0; i < 16; i++) w[i] = ld64be(p + 8 * i);
 for (int i = 16; i < 80; i++) {
  uint64_t s0 = rr64(w[i - 15], 1) ^ rr64(w[i - 15], 8) ^ (w[i - 15] >> 7),
           s1 = rr64(w[i - 2], 19) ^ rr64(w[i - 2], 61) ^ (w[i - 2] >> 6);
  w[i] = w[i - 16] + s0 + w[i - 7] + s1; }
 for (int k = 0; k < 8; k++) v[k] = (uint64_t) h[2 * k] << 32 | h[2 * k + 1];
 for (int i = 0; i < 80; i++) {
  uint64_t e = v[4], a = v[0],
           t1 = v[7] + (rr64(e, 14) ^ rr64(e, 18) ^ rr64(e, 41))
              + ((e & v[5]) ^ (~e & v[6])) + K512[i] + w[i],
           t2 = (rr64(a, 28) ^ rr64(a, 34) ^ rr64(a, 39))
              + ((a & v[1]) ^ (a & v[2]) ^ (v[1] & v[2]));
  v[7] = v[6]; v[6] = v[5]; v[5] = v[4]; v[4] = v[3] + t1;
  v[3] = v[2]; v[2] = v[1]; v[1] = v[0]; v[0] = t1 + t2; }
 for (int k = 0; k < 8; k++) {
  uint64_t s = ((uint64_t) h[2 * k] << 32 | h[2 * k + 1]) + v[k];
  h[2 * k] = (uint32_t) (s >> 32); h[2 * k + 1] = (uint32_t) s; } }

static void sha1_block(uint32_t h[5], const uint8_t *p) {
 uint32_t w[80], a = h[0], b = h[1], c = h[2], d = h[3], e = h[4];
 for (int i = 0; i < 16; i++) w[i] = ld32be(p + 4 * i);
 for (int i = 16; i < 80; i++) w[i] = rl(w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16], 1);
 for (int i = 0; i < 80; i++) {
  uint32_t f, k;
  if (i < 20)      f = (b & c) | (~b & d),          k = 0x5a827999;
  else if (i < 40) f = b ^ c ^ d,                   k = 0x6ed9eba1;
  else if (i < 60) f = (b & c) | (b & d) | (c & d), k = 0x8f1bbcdc;
  else             f = b ^ c ^ d,                   k = 0xca62c1d6;
  uint32_t t = rl(a, 5) + f + e + k + w[i];
  e = d; d = c; c = rl(b, 30); b = a; a = t; }
 h[0] += a; h[1] += b; h[2] += c; h[3] += d; h[4] += e; }

static void md5_block(uint32_t h[4], const uint8_t *p) {
 uint32_t m[16], a = h[0], b = h[1], c = h[2], d = h[3];
 for (int i = 0; i < 16; i++)
  m[i] = (uint32_t) p[4*i] | (uint32_t) p[4*i+1] << 8
       | (uint32_t) p[4*i+2] << 16 | (uint32_t) p[4*i+3] << 24;
 for (int i = 0; i < 64; i++) {
  uint32_t f; int g;
  if (i < 16)      { f = (b & c) | (~b & d); g = i; }
  else if (i < 32) { f = (d & b) | (~d & c); g = (5*i + 1) & 15; }
  else if (i < 48) { f = b ^ c ^ d;          g = (3*i + 5) & 15; }
  else             { f = c ^ (b | ~d);       g = (7*i) & 15; }
  f += a + MK[i] + m[g];
  a = d; d = c; c = b; b += rl(f, MS[i]); }
 h[0] += a; h[1] += b; h[2] += c; h[3] += d; }

// --- the buffering the merkle-damgard digests share --------------------------------
// md5, sha-1 and the four sha-2s differ here only in the compression function, the
// block (64 or 128 bytes) and which way the length is laid, so the block arithmetic is
// written once and the one-shots and the streams below both go through it.
typedef void (*blkfn)(uint32_t *h, const uint8_t *p);

// the row a digest is: its state's width in a cask (the width is the type), the words
// it keeps and the words it shows, the block, the order, the compression, and where
// its initial words sit in which table
struct digspec { uintptr_t st; int words, outw; unsigned bs; int be; blkfn f;
                 const uint32_t *h0; int step, first; };

// the cask: h[words] be | count 8 be | remainder len 1 | remainder bs | a tag byte on
// the truncated two, so no two widths meet
#define DigSt(w, bs, tag) (4 * (w) + 9 + (bs) + (tag))
static const struct digspec
 dig_md5    = {DigSt(4, 64, 0),   4, 4,   64, 0, md5_block,    sha1_h0,   1, 0},
 dig_sha1   = {DigSt(5, 64, 0),   5, 5,   64, 1, sha1_block,   sha1_h0,   1, 0},
 dig_sha224 = {DigSt(8, 64, 1),   8, 7,   64, 1, sha_block,    sha384_h0, 2, 1},
 dig_sha    = {DigSt(8, 64, 0),   8, 8,   64, 1, sha_block,    sha512_h0, 2, 0},
 dig_sha384 = {DigSt(16, 128, 1), 16, 12, 128, 1, sha512_block, sha384_h0, 1, 0},
 dig_sha512 = {DigSt(16, 128, 0), 16, 16, 128, 1, sha512_block, sha512_h0, 1, 0};

static void dig_h0(uint32_t *h, const struct digspec *d) {
 for (int k = 0; k < d->words; k++) h[k] = d->h0[k * d->step + d->first]; }

// top the remainder up, run whole blocks straight off the input, keep the tail ->
// the new remainder length
static unsigned blk_feed(uint32_t *h, uint8_t *buf, unsigned rem, const struct digspec *d,
                         const uint8_t *p, uintptr_t n) {
 unsigned bs = d->bs;
 if (rem) {
  unsigned want = bs - rem;
  if (n < want) { memcpy(buf + rem, p, n); return (unsigned) (rem + n); }
  memcpy(buf + rem, p, want);
  d->f(h, buf);
  p += want; n -= want; }
 for (; n >= bs; p += bs, n -= bs) d->f(h, p);
 if (n) memcpy(buf, p, n);
 return (unsigned) n; }

// the pad: 0x80, zeros, then the bit count in the block's last eighth -- big-endian
// for the shas, little for md5; the 128-byte block's 16-byte count is high zeros
static void blk_done(uint32_t *h, const uint8_t *buf, unsigned r, uint64_t len,
                     const struct digspec *d) {
 uint8_t tail[256];
 unsigned bs = d->bs;
 memcpy(tail, buf, r);
 tail[r++] = 0x80;
 size_t pad = (r <= bs - bs / 8) ? bs : 2 * bs;
 memset(tail + r, 0, pad - 8 - r);
 uint64_t bits = len << 3;
 for (int k = 0; k < 8; k++)
  if (d->be) tail[pad - 1 - k] = (uint8_t) (bits >> (8 * k));
  else       tail[pad - 8 + k] = (uint8_t) (bits >> (8 * k));
 d->f(h, tail);
 if (pad == 2 * bs) d->f(h, tail + bs); }

static const char hexd[] = "0123456789abcdef";

// the hex face every digest wears, the digest's own order, n words wide
static void blk_hex(const uint32_t *h, int words, int be, char *out) {
 for (int k = 0; k < words; k++)
  for (int j = 0; j < 4; j++) {
   uint8_t b = (uint8_t) (h[k] >> (be ? 24 - 8 * j : 8 * j));
   out[8 * k + 2 * j] = hexd[b >> 4];
   out[8 * k + 2 * j + 1] = hexd[b & 15]; }
 out[8 * words] = 0; }

// pushes the digest's hex over the argument, the one-shots' and the streams' shared last step
static struct ai *dig_push(struct ai *g, const char *hex) {
 if (!ai_ok(g = ai_strof(g, hex))) return g;
 g->sp[1] = g->sp[0];
 g->sp += 1;
 return g; }

// (X str) -> the hex digest | ()
static ai_noinline struct ai *dig_one(struct ai *g, const struct digspec *d) {
 if (!strp(g->sp[0])) return g->sp[0] = ZeroPoint, g;
 struct ai_str *s = (struct ai_str*) g->sp[0];
 uint32_t h[16];
 uint8_t buf[128];
 char hex[129];
 dig_h0(h, d);
 unsigned r = blk_feed(h, buf, 0, d, (const uint8_t*) s->bytes, (uintptr_t) s->len);
 blk_done(h, buf, r, (uint64_t) s->len, d);
 blk_hex(h, d->outw, d->be, hex);
 return dig_push(g, hex); }

static struct ai *host_sha256(struct ai *g) { return dig_one(g, &dig_sha); }
static struct ai *host_md5(struct ai *g) { return dig_one(g, &dig_md5); }
static struct ai *host_sha1(struct ai *g) { return dig_one(g, &dig_sha1); }
static struct ai *host_sha224(struct ai *g) { return dig_one(g, &dig_sha224); }
static struct ai *host_sha384(struct ai *g) { return dig_one(g, &dig_sha384); }
static struct ai *host_sha512(struct ai *g) { return dig_one(g, &dig_sha512); }
static lvm(lvm_sha256) LvmCall(g, host_sha256)
static lvm(lvm_md5) LvmCall(g, host_md5)
static lvm(lvm_sha1) LvmCall(g, host_sha1)
static lvm(lvm_sha224) LvmCall(g, host_sha224)
static lvm(lvm_sha384) LvmCall(g, host_sha384)
static lvm(lvm_sha512) LvmCall(g, host_sha512)

// --- blake2b (rfc 7693), unkeyed, any length 1..64 bytes ---------------------------
// not merkle-damgard: no length pad, the last block compressed with a flag instead,
// so a whole block is held back until the next byte (or the end) says whether it was
// the last. its stream is a state of its own shape for that reason.
static uint8_t const B2S[10][16] = {
 { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14,15}, {14,10, 4, 8, 9,15,13, 6, 1,12, 0, 2,11, 7, 5, 3},
 {11, 8,12, 0, 5, 2,15,13,10,14, 3, 6, 7, 1, 9, 4}, { 7, 9, 3, 1,13,12,11,14, 2, 6, 5,10, 4, 0,15, 8},
 { 9, 0, 5, 7, 2, 4,10,15,14, 1,11,12, 6, 8, 3,13}, { 2,12, 6,10, 0,11, 8, 3, 4,13, 7, 5,15,14, 1, 9},
 {12, 5, 1,15,14,13, 4,10, 0, 7, 6, 3, 9, 2, 8,11}, {13,11, 7,14,12, 1, 3, 9, 5, 0,15, 4, 8, 6, 2,10},
 { 6,15,14, 9,11, 3, 0, 8,12, 2,13, 7, 1, 4,10, 5}, {10, 2, 8, 4, 7, 6, 1, 5,15,11, 9,14, 3,12,13, 0}};

static uint64_t b2iv(int k) { return (uint64_t) sha512_h0[2 * k] << 32 | sha512_h0[2 * k + 1]; }

static void b2_block(uint64_t h[8], const uint8_t *p, uint64_t t, int last) {
 uint64_t m[16], v[16];
 for (int i = 0; i < 16; i++) m[i] = ld64le(p + 8 * i);
 for (int i = 0; i < 8; i++) v[i] = h[i], v[i + 8] = b2iv(i);
 v[12] ^= t;
 if (last) v[14] = ~v[14];
 static uint8_t const G[8][4] = {{0,4,8,12},{1,5,9,13},{2,6,10,14},{3,7,11,15},
                                 {0,5,10,15},{1,6,11,12},{2,7,8,13},{3,4,9,14}};
 for (int r = 0; r < 12; r++)
  for (int j = 0; j < 8; j++) {
   int a = G[j][0], b = G[j][1], c = G[j][2], d = G[j][3];
   v[a] += v[b] + m[B2S[r % 10][2 * j]];     v[d] = rr64(v[d] ^ v[a], 32);
   v[c] += v[d];                             v[b] = rr64(v[b] ^ v[c], 24);
   v[a] += v[b] + m[B2S[r % 10][2 * j + 1]]; v[d] = rr64(v[d] ^ v[a], 16);
   v[c] += v[d];                             v[b] = rr64(v[b] ^ v[c], 63); }
 for (int i = 0; i < 8; i++) h[i] ^= v[i] ^ v[i + 8]; }

static void b2_init(uint64_t h[8], unsigned nn) {
 for (int i = 0; i < 8; i++) h[i] = b2iv(i);
 h[0] ^= 0x01010000u ^ nn; }

// -> the new held length, 1..128 once anything came: a full block waits for the next feed
static unsigned b2_feed(uint64_t h[8], uint64_t *t, uint8_t *buf, unsigned rem,
                        const uint8_t *p, uintptr_t n) {
 if (!n) return rem;
 if (rem) {
  unsigned want = 128 - rem;
  if (n <= want) { memcpy(buf + rem, p, n); return (unsigned) (rem + n); }
  memcpy(buf + rem, p, want);
  p += want; n -= want;
  *t += 128; b2_block(h, buf, *t, 0); }
 for (; n > 128; p += 128, n -= 128) { *t += 128; b2_block(h, p, *t, 0); }
 memcpy(buf, p, n);
 return (unsigned) n; }

static void b2_done(uint64_t h[8], uint64_t t, uint8_t *buf, unsigned rem, unsigned nn,
                    char *out) {
 memset(buf + rem, 0, 128 - rem);
 b2_block(h, buf, t + rem, 1);
 for (unsigned k = 0; k < nn; k++) {
  uint8_t b = (uint8_t) (h[k / 8] >> (8 * (k % 8)));
  out[2 * k] = hexd[b >> 4]; out[2 * k + 1] = hexd[b & 15]; }
 out[2 * nn] = 0; }

ai_noinline static struct ai *host_blake2b(struct ai *g) {
 if (!strp(g->sp[0])) return g->sp[0] = ZeroPoint, g;
 struct ai_str *s = (struct ai_str*) g->sp[0];
 uint64_t h[8], t = 0;
 uint8_t buf[128];
 char hex[129];
 b2_init(h, 64);
 unsigned r = b2_feed(h, &t, buf, 0, (const uint8_t*) s->bytes, (uintptr_t) s->len);
 b2_done(h, t, buf, r, 64, hex);
 return dig_push(g, hex); }
static lvm(lvm_blake2b) LvmCall(g, host_blake2b)

// --- sha-3 (fips 202): keccak-f[1600] as a sponge ---------------------------------
// no block buffer: a byte is xored straight into the state where the sponge stands,
// and the permutation runs whenever the rate fills. the rate is 200 less twice the
// digest, so any length rides one loop; past the rate the digest squeezes on.
static void keccak(uint64_t a[25]) {
 static uint8_t const rho[25] = {0,1,62,28,27,36,44,6,55,20,3,10,43,25,39,41,45,15,21,8,18,2,61,56,14},
                      pi[25] = {0,10,20,5,15,16,1,11,21,6,7,17,2,12,22,23,8,18,3,13,14,24,9,19,4};
 uint64_t rc = 1, c[5], b[25];
 for (int r = 0; r < 24; r++) {
  for (int x = 0; x < 5; x++) c[x] = a[x] ^ a[x + 5] ^ a[x + 10] ^ a[x + 15] ^ a[x + 20];
  for (int x = 0; x < 5; x++) {
   uint64_t d = c[(x + 4) % 5] ^ (c[(x + 1) % 5] << 1 | c[(x + 1) % 5] >> 63);
   for (int y = 0; y < 25; y += 5) a[y + x] ^= d; }
  for (int i = 0; i < 25; i++) b[pi[i]] = rho[i] ? (a[i] << rho[i] | a[i] >> (64 - rho[i])) : a[i];
  for (int y = 0; y < 25; y += 5)
   for (int x = 0; x < 5; x++) a[y + x] = b[y + x] ^ (~b[y + (x + 1) % 5] & b[y + (x + 2) % 5]);
  uint64_t k = 0;                              // the round constant off the lfsr, bit 2^j - 1 for j < 7
  for (int j = 0; j < 7; j++) {
   if (rc & 1) k |= (uint64_t) 1 << ((1 << j) - 1);
   rc = rc & 0x80 ? (rc << 1) ^ 0x171 : rc << 1; }
  a[0] ^= k; } }

// the state rides as 200 little-endian bytes, lane i at 8i, so byte k of the sponge is byte k
static void k_ld(const uint8_t *st, uint64_t a[25]) { for (int i = 0; i < 25; i++) a[i] = ld64le(st + 8 * i); }
static void k_st(uint8_t *st, const uint64_t a[25]) {
 for (int i = 0; i < 25; i++) for (int j = 0; j < 8; j++) st[8 * i + j] = (uint8_t) (a[i] >> (8 * j)); }
static void k_perm(uint8_t *st) { uint64_t a[25]; k_ld(st, a); keccak(a); k_st(st, a); }

// -> the new position in the rate
static unsigned k_feed(uint8_t *st, unsigned pos, unsigned rate, const uint8_t *p, uintptr_t n) {
 for (; n; p++, n--) {
  st[pos++] ^= *p;
  if (pos == rate) { k_perm(st); pos = 0; } }
 return pos; }

static void k_done(uint8_t *st, unsigned pos, unsigned rate, unsigned outn, uint8_t pad, char *out) {
 st[pos] ^= pad; st[rate - 1] ^= 0x80;
 k_perm(st);
 for (unsigned i = 0; i < outn; i++) {
  if (i && !(i % rate)) k_perm(st);
  uint8_t b = st[i % rate];
  out[2 * i] = hexd[b >> 4]; out[2 * i + 1] = hexd[b & 15]; }
 out[2 * outn] = 0; }

ai_noinline static struct ai *host_sha3(struct ai *g) {
 if (!strp(g->sp[0])) return g->sp[0] = ZeroPoint, g;
 struct ai_str *s = (struct ai_str*) g->sp[0];
 uint8_t st[200];
 char hex[65];
 memset(st, 0, sizeof st);
 unsigned pos = k_feed(st, 0, 136, (const uint8_t*) s->bytes, (uintptr_t) s->len);
 k_done(st, pos, 136, 32, 0x06, hex);
 return dig_push(g, hex); }
static lvm(lvm_sha3) LvmCall(g, host_sha3)

// --- bsd sum: a 16-bit checksum rotated right a bit before each byte ---------------
// (bsdsum acc str) -> acc with str's bytes folded in | (); a whole file is a fold from 0
static lvm(lvm_bsdsum) {
 word a = Sp[0], x = Sp[1];
 if (!charmp(a) || !strp(x)) Sp[1] = ZeroPoint;
 else {
  struct ai_str *s = (struct ai_str*) x;
  const uint8_t *p = (const uint8_t*) s->bytes;
  uint32_t c = (uint32_t) getcharm(a) & 0xffff;
  for (uintptr_t i = 0; i < (uintptr_t) s->len; i++)
   c = (((c >> 1) | ((c & 1) << 15)) + p[i]) & 0xffff;
  Sp[1] = putcharm(c); }
 ai_musttail return Nextp(1, 1); }

// --- crc32 (IEEE 802.3: reflected, polynomial 0xedb88320) -------------------------
// eight bytes at a time, and that is the whole difference: the byte-at-a-time walk
// apps/gz.l spells is a dependency chain one link per byte, where slicing spends eight
// independent lookups and lets the machine overlap them. gz.l cannot do this -- eight
// tray reads per byte would cost eight times what one does.
// the tables are built on the first call rather than laid in .rodata: 2048 entries
// off a one-line recurrence, and nothing for a reader to check against the polynomial.
// write-once and idempotent (every builder writes the same words), so the one thing a
// second thread would need is the flag landing after the table. cksum's pair below too.
static uint32_t crc_t[8][256];
static int crc_ready;

static void crc_init(void) {
 unsigned i, k;
 for (i = 0; i < 256; i++) {
  uint32_t c = i;
  for (k = 0; k < 8; k++) c = (c & 1) ? (c >> 1) ^ 0xedb88320 : c >> 1;
  crc_t[0][i] = c; }
 for (i = 0; i < 256; i++) {                    // table k is table 0 shifted k bytes on
  uint32_t c = crc_t[0][i];
  for (k = 1; k < 8; k++) { c = crc_t[0][c & 0xff] ^ (c >> 8); crc_t[k][i] = c; } }
 crc_ready = 1; }

#define LD32(p) ((uint32_t) (p)[0] | (uint32_t) (p)[1] << 8 \
               | (uint32_t) (p)[2] << 16 | (uint32_t) (p)[3] << 24)

// the register walk; c is the register, complemented on the way in and out by its callers
static uint32_t crc32_run(uint32_t c, const uint8_t *p, uintptr_t n) {
 if (!crc_ready) crc_init();
 for (; n >= 8; p += 8, n -= 8) {
  uint32_t a = c ^ LD32(p), b = LD32(p + 4);
  c = crc_t[7][a & 0xff] ^ crc_t[6][(a >> 8) & 0xff]
    ^ crc_t[5][(a >> 16) & 0xff] ^ crc_t[4][a >> 24]
    ^ crc_t[3][b & 0xff] ^ crc_t[2][(b >> 8) & 0xff]
    ^ crc_t[1][(b >> 16) & 0xff] ^ crc_t[0][b >> 24]; }
 for (; n; p++, n--) c = crc_t[0][(c ^ *p) & 0xff] ^ (c >> 8);
 return c; }

static uint32_t crc32_of(const uint8_t *p, uintptr_t n) { return ~crc32_run(0xffffffff, p, n); }

static ai_inline struct ai *host_crc32(struct ai *g) {
 if (!strp(g->sp[0])) return g->sp[0] = ZeroPoint, g;
 { struct ai_str *s = (struct ai_str*) g->sp[0];
   g->sp[0] = putcharm(crc32_of((const uint8_t*) s->bytes, (uintptr_t) s->len)); }
 return g; }
static lvm(lvm_crc32) {
 LvmCall(g, host_crc32) }

// (crc32-on c str) -> the crc32 of whatever c was the crc32 of, str's bytes after it
static lvm(lvm_crc32_on) {
 word c = Sp[0], x = Sp[1];
 if (!charmp(c) || !strp(x)) Sp[1] = ZeroPoint;
 else {
  struct ai_str *s = (struct ai_str*) x;
  Sp[1] = putcharm(~crc32_run(~(uint32_t) getcharm(c), (const uint8_t*) s->bytes, (uintptr_t) s->len)); }
 ai_musttail return Nextp(1, 1); }

// --- cksum (POSIX: not reflected, polynomial 0x04c11db7, the length folded in) -----
// a different crc from the one above in every part: the register runs the other way,
// the seed is 0, and the message does not end at the last byte -- the byte count goes
// through the same walk, low byte first, which is what makes cksum answer 4294967295
// for the empty file rather than 0. its tables are its own for that reason: crc32's
// are the reflected polynomial's and answer a different number.
// ck_bit is the statement of the polynomial, and it is the table's only source -- the
// walk below is derived from it, not a second spelling of it. the tables are worth their
// space: bit-at-a-time is 8 shifts and a branch a byte, 3.5 s of a 3.9 s run over 100 MB.
static uint32_t ck_bit(uint32_t c, uint8_t b) {
 c ^= (uint32_t) b << 24;
 for (int k = 0; k < 8; k++) c = (c & 0x80000000u) ? (c << 1) ^ 0x04c11db7u : c << 1;
 return c; }

static uint32_t ck_t[8][256];
static int ck_ready;

static ai_noinline void ck_init(void) {
 unsigned i, k;
 for (i = 0; i < 256; i++) ck_t[0][i] = ck_bit(0, (uint8_t) i);
 for (i = 0; i < 256; i++) {                    // table k is table 0 shifted k bytes on
  uint32_t c = ck_t[0][i];
  for (k = 1; k < 8; k++) {
   c = (c << 8) ^ ck_t[0][(c >> 24) & 0xff];
   ck_t[k][i] = c; } }
 ck_ready = 1; }

#define LD32BE(p) ((uint32_t) (p)[0] << 24 | (uint32_t) (p)[1] << 16 \
                 | (uint32_t) (p)[2] << 8  | (uint32_t) (p)[3])

// eight bytes at a time, the same trade crc32 takes above: eight independent lookups
// the machine can overlap, against a dependency chain one link per byte.
static uint32_t ck_run(uint32_t c, const uint8_t *p, uintptr_t n) {
 if (!ck_ready) ck_init();
 for (; n >= 8; p += 8, n -= 8) {
  uint32_t a = c ^ LD32BE(p), b = LD32BE(p + 4);
  c = ck_t[7][(a >> 24) & 0xff] ^ ck_t[6][(a >> 16) & 0xff]
    ^ ck_t[5][(a >> 8) & 0xff]  ^ ck_t[4][a & 0xff]
    ^ ck_t[3][(b >> 24) & 0xff] ^ ck_t[2][(b >> 16) & 0xff]
    ^ ck_t[1][(b >> 8) & 0xff]  ^ ck_t[0][b & 0xff]; }
 for (; n; p++, n--) c = (c << 8) ^ ck_t[0][((c >> 24) ^ *p) & 0xff];
 return c; }

// the length, low byte first, through the same walk -- eight bytes at the most, so it
// stays a byte at a time
static uint32_t ck_len(uint32_t c, uint64_t len) {
 if (!ck_ready) ck_init();
 for (; len; len >>= 8) {
  uint8_t b = (uint8_t) (len & 0xff);
  c = (c << 8) ^ ck_t[0][((c >> 24) ^ b) & 0xff]; }
 return c; }

static uint32_t cksum_of(const uint8_t *p, uintptr_t n) {
 return ~ck_len(ck_run(0, p, n), (uint64_t) n); }

static lvm(lvm_cksum) {
 if (!strp(Sp[0])) Sp[0] = ZeroPoint;
 else {
  struct ai_str *s = str(Sp[0]);
  Sp[0] = putcharm(cksum_of((unsigned char const*)s->bytes, s->len)); }
 ai_musttail return Next(1); }

// --- the same digests, resumable ---------------------------------------------------
// the one-shots want their whole message contiguous, and for a file that is the file.
// each triple below carries the state in a cask instead, so a caller feeds it a gulp
// at a time and holds nothing. the block loops above are untouched -- one spelling of
// each compression function, two ways in, so a streamed digest cannot drift from its
// one-shot, and test/digest.l holds the two together at every chunking.
//
// the layout is this file's; love allocates the cask, carries it, and never reads it.
// big-endian throughout, whatever the algorithm's own order, so the state is bytes and
// not this machine's words -- it can be written down, and an image carrying one wakes
// on any box. the block digests' is DigSt's above; the other two:
//
//   blake2b, 210:  0..63 h[8] be | 64..71 count be | 72..79 zero | 80 held len
//                  | 81 digest bytes | 82.. held block
//   sha3,    204:  0..199 the sponge | 200 position | 201 rate | 202 digest bytes | 203 pad
//   cksum,    12:  0..3 crc be   | 4..11 count be                    (no block, no rem)
//
// the size is the type. every entry point checks the width it wants -- which is what
// stops an md5 state being fed to sha256-feed and answering a number that looks like
// a digest.
#define B2St 210
#define K3St 204
#define CkSt 12

static struct ai_str *dig_cask(word x, uintptr_t want) {   // the cask's bytes, or NULL
 if (charmp(x) || ((union u*) x)->ap != lvm_cask) return NULL;
 struct ai_str *s = ((struct ai_cask*) x)->str;
 return s && s->len == want ? s : NULL; }

// h[words] then the 8-byte count, both big-endian, at the front of the state
static void dig_ld(const uint8_t *st, uint32_t *h, int words, uint64_t *len) {
 for (int k = 0; k < words; k++) h[k] = ld32be(st + 4 * k);
 *len = ld64be(st + 4 * words); }

static void dig_st(uint8_t *st, const uint32_t *h, int words, uint64_t len) {
 for (int k = 0; k < words; k++) {
  st[4*k]   = (uint8_t) (h[k] >> 24); st[4*k+1] = (uint8_t) (h[k] >> 16);
  st[4*k+2] = (uint8_t) (h[k] >> 8);  st[4*k+3] = (uint8_t)  h[k]; }
 for (int k = 0; k < 8; k++) st[4*words + k] = (uint8_t) (len >> (56 - 8*k)); }

// (X-init b) -> b, carrying the standard's initial state and nothing fed | () on
// anything that is not a cask of X's width
static word dig_init(word x, const struct digspec *d) {
 struct ai_str *s = dig_cask(x, d->st);
 if (!s) return ZeroPoint;
 uint8_t *st = (uint8_t*) s->bytes;
 uint32_t h[16];
 memset(st, 0, d->st);
 dig_h0(h, d);
 dig_st(st, h, d->words, 0);
 return x; }

// (X-feed b str) -> b, str's bytes folded in | (). any chunk size: what does not fill
// a block stays in the remainder and rides to the next feed, which is the whole point
// -- a caller reads by the gulp and never has to think in blocks.
static word dig_feed(word x, word a, const struct digspec *d) {
 struct ai_str *cs = dig_cask(x, d->st);
 if (!cs || !strp(a)) return ZeroPoint;
 struct ai_str *in = (struct ai_str*) a;
 uint8_t *st = (uint8_t*) cs->bytes;
 unsigned remoff = 4 * d->words + 8;
 uint32_t h[16];
 uint64_t len;
 dig_ld(st, h, d->words, &len);
 len += (uint64_t) in->len;
 st[remoff] = (uint8_t) blk_feed(h, st + remoff + 1, st[remoff], d,
                                 (const uint8_t*) in->bytes, (uintptr_t) in->len);
 dig_st(st, h, d->words, len);
 return x; }

// (X-done b) -> the hex digest | (). the pad is the one-shot's, over the remainder
// rather than the message tail; b is left spent, not reusable.
static ai_noinline struct ai *dig_done(struct ai *g, const struct digspec *d) {
 struct ai_str *cs = dig_cask(g->sp[0], d->st);
 if (!cs) return g->sp[0] = ZeroPoint, g;
 uint8_t *st = (uint8_t*) cs->bytes;
 unsigned remoff = 4 * d->words + 8;
 uint32_t h[16];
 uint64_t len;
 char hex[129];
 dig_ld(st, h, d->words, &len);
 blk_done(h, st + remoff + 1, st[remoff], len, d);
 blk_hex(h, d->outw, d->be, hex);
 return dig_push(g, hex); }

// one digest's three lvm entry points, told apart by the row they pass
#define DigNifs(nm, spec) \
 static struct ai *host_##nm##_done(struct ai *g) { return dig_done(g, &spec); } \
 static lvm(lvm_##nm##_done) LvmCall(g, host_##nm##_done) \
 static lvm(lvm_##nm##_init) { Sp[0] = dig_init(Sp[0], &spec); ai_musttail return Next(1); } \
 static lvm(lvm_##nm##_feed) { Sp[1] = dig_feed(Sp[0], Sp[1], &spec); ai_musttail return Nextp(1, 1); }
DigNifs(sha, dig_sha)
DigNifs(md5, dig_md5)
DigNifs(sha1, dig_sha1)
DigNifs(sha224, dig_sha224)
DigNifs(sha384, dig_sha384)
DigNifs(sha512, dig_sha512)

// blake2b's h is eight 64-bit words, laid as sixteen 32-bit halves for dig_ld/dig_st
static void b2_ld(const uint8_t *st, uint64_t h[8], uint64_t *t) {
 uint32_t w[16];
 dig_ld(st, w, 16, t);
 for (int k = 0; k < 8; k++) h[k] = (uint64_t) w[2 * k] << 32 | w[2 * k + 1]; }

static void b2_st(uint8_t *st, const uint64_t h[8], uint64_t t) {
 uint32_t w[16];
 for (int k = 0; k < 8; k++) w[2 * k] = (uint32_t) (h[k] >> 32), w[2 * k + 1] = (uint32_t) h[k];
 dig_st(st, w, 16, t); }

// (blake2b-init b n) -> b, set for an n-byte digest (1..64) | ()
static word host_b2_init(word x, word n) {
 struct ai_str *s = dig_cask(x, B2St);
 if (!s || !charmp(n) || getcharm(n) < 1 || getcharm(n) > 64) return ZeroPoint;
 uint8_t *st = (uint8_t*) s->bytes;
 uint64_t h[8];
 memset(st, 0, B2St);
 b2_init(h, (unsigned) getcharm(n));
 b2_st(st, h, 0);
 st[81] = (uint8_t) getcharm(n);
 return x; }

static word host_b2_feed(word x, word a) {
 struct ai_str *cs = dig_cask(x, B2St);
 if (!cs || !strp(a)) return ZeroPoint;
 struct ai_str *in = (struct ai_str*) a;
 uint8_t *st = (uint8_t*) cs->bytes;
 uint64_t h[8], t;
 b2_ld(st, h, &t);
 st[80] = (uint8_t) b2_feed(h, &t, st + 82, st[80], (const uint8_t*) in->bytes,
                            (uintptr_t) in->len);
 b2_st(st, h, t);
 return x; }

static ai_noinline struct ai *host_b2_done(struct ai *g) {
 struct ai_str *cs = dig_cask(g->sp[0], B2St);
 if (!cs) return g->sp[0] = ZeroPoint, g;
 uint8_t *st = (uint8_t*) cs->bytes;
 uint64_t h[8], t;
 char hex[129];
 b2_ld(st, h, &t);
 b2_done(h, t, st + 82, st[80], st[81], hex);
 return dig_push(g, hex); }

static lvm(lvm_b2_init) {
 Sp[1] = host_b2_init(Sp[0], Sp[1]);
 ai_musttail return Nextp(1, 1); }
static lvm(lvm_b2_feed) {
 Sp[1] = host_b2_feed(Sp[0], Sp[1]);
 ai_musttail return Nextp(1, 1); }
static lvm(lvm_b2_done) LvmCall(g, host_b2_done)

// (sha3-init b bits shake) -> b, set for a bits-long digest | ()
static word host_k3_init(word x, word bw, word sw) {
 struct ai_str *s = dig_cask(x, K3St);
 if (!s || !charmp(bw) || getcharm(bw) < 8 || getcharm(bw) > 512) return ZeroPoint;
 uint8_t *st = (uint8_t*) s->bytes;
 intptr_t bits = getcharm(bw);
 memset(st, 0, K3St);
 st[201] = (uint8_t) (200 - bits / 4);
 st[202] = (uint8_t) (bits / 8);
 st[203] = charmp(sw) && getcharm(sw) > 0 ? 0x1f : 0x06;
 return x; }

static word host_k3_feed(word x, word a) {
 struct ai_str *cs = dig_cask(x, K3St);
 if (!cs || !strp(a) || !((uint8_t*) cs->bytes)[201]) return ZeroPoint;
 struct ai_str *in = (struct ai_str*) a;
 uint8_t *st = (uint8_t*) cs->bytes;
 st[200] = (uint8_t) k_feed(st, st[200], st[201], (const uint8_t*) in->bytes, (uintptr_t) in->len);
 return x; }

static ai_noinline struct ai *host_k3_done(struct ai *g) {
 struct ai_str *cs = dig_cask(g->sp[0], K3St);
 if (!cs || !((uint8_t*) cs->bytes)[201]) return g->sp[0] = ZeroPoint, g;
 uint8_t *st = (uint8_t*) cs->bytes;
 char hex[129];
 k_done(st, st[200], st[201], st[202], st[203], hex);
 return dig_push(g, hex); }

static lvm(lvm_k3_init) {
 Sp[2] = host_k3_init(Sp[0], Sp[1], Sp[2]);
 ai_musttail return Nextp(1, 2); }
static lvm(lvm_k3_feed) {
 Sp[1] = host_k3_feed(Sp[0], Sp[1]);
 ai_musttail return Nextp(1, 1); }
static lvm(lvm_k3_done) LvmCall(g, host_k3_done)

ai_noinline static word host_ck_feed(word x, word a) {
 struct ai_str *cs = dig_cask(x, CkSt);
 if (!cs || !strp(a)) return ZeroPoint;
 struct ai_str *in = (struct ai_str*) a;
 uint8_t *st = (uint8_t*) cs->bytes;
 uint32_t c;
 uint64_t len;
 dig_ld(st, &c, 1, &len);
 uintptr_t n = in->len;
 len += (uint64_t) n;
 c = ck_run(c, (const uint8_t*) in->bytes, n);
 dig_st(st, &c, 1, len);
 return x; }

ai_noinline static word host_ck_done(word x) {
 struct ai_str *cs = dig_cask(x, CkSt);
 if (!cs) return ZeroPoint;
 uint8_t *st = (uint8_t*) cs->bytes;
 uint32_t c;
 uint64_t len;
 dig_ld(st, &c, 1, &len);
 return putcharm(~ck_len(c, len)); }

// cksum streams with no block and no remainder: its walk is a byte at a time, so the
// whole state is the register and the count.
static lvm(lvm_ck_init) {                      // (cksum-init b) -> b zeroed | (): the cask, never a pointer into it
 struct ai_str *s = dig_cask(Sp[0], CkSt);
 if (!s) Sp[0] = ZeroPoint; else memset(s->bytes, 0, CkSt);
 ai_musttail return Next(1); }

static lvm(lvm_ck_feed) {
 Sp[1] = host_ck_feed(Sp[0], Sp[1]);
 ai_musttail return Nextp(1, 1); }

static lvm(lvm_ck_done) {
 Sp[0] = host_ck_done(Sp[0]);
 ai_musttail return Next(1); }

#define Nif1(nm, f) static union u const nm[] = {{f}, {lvm_ret0}};
#define Nif2(nm, f) static union u const nm[] = {{lvm_cur}, {.x = putcharm(2)}, {f}, {lvm_ret0}};
#define DigBook(nm) Nif1(nif_##nm, lvm_##nm) Nif1(nif_##nm##_init, lvm_##nm##_init) \
 Nif2(nif_##nm##_feed, lvm_##nm##_feed) Nif1(nif_##nm##_done, lvm_##nm##_done)
Nif1(nif_sha, lvm_sha256)
Nif1(nif_sha_init, lvm_sha_init)
Nif2(nif_sha_feed, lvm_sha_feed)
Nif1(nif_sha_done, lvm_sha_done)
DigBook(md5)
DigBook(sha1)
DigBook(sha224)
DigBook(sha384)
DigBook(sha512)
Nif1(nif_blake2b, lvm_blake2b)
Nif2(nif_b2_init, lvm_b2_init)
Nif2(nif_b2_feed, lvm_b2_feed)
Nif1(nif_b2_done, lvm_b2_done)
Nif1(nif_sha3, lvm_sha3)
static union u const nif_k3_init[] = {{lvm_cur}, {.x = putcharm(3)}, {lvm_k3_init}, {lvm_ret0}};
Nif2(nif_k3_feed, lvm_k3_feed)
Nif1(nif_k3_done, lvm_k3_done)
Nif2(nif_bsdsum, lvm_bsdsum)
Nif1(nif_crc32, lvm_crc32)
Nif2(nif_crc32_on, lvm_crc32_on)
Nif1(nif_cksum, lvm_cksum)
Nif1(nif_ck_init, lvm_ck_init)
Nif2(nif_ck_feed, lvm_ck_feed)
Nif1(nif_ck_done, lvm_ck_done)

LvNif("sha256", nif_sha, NULL);
LvNif("sha256-init", nif_sha_init, NULL);
LvNif("sha256-feed", nif_sha_feed, NULL);
LvNif("sha256-done", nif_sha_done, NULL);
LvNif("md5", nif_md5, NULL);
LvNif("md5-init", nif_md5_init, NULL);
LvNif("md5-feed", nif_md5_feed, NULL);
LvNif("md5-done", nif_md5_done, NULL);
LvNif("sha1", nif_sha1, NULL);
LvNif("sha1-init", nif_sha1_init, NULL);
LvNif("sha1-feed", nif_sha1_feed, NULL);
LvNif("sha1-done", nif_sha1_done, NULL);
LvNif("sha224", nif_sha224, NULL);
LvNif("sha224-init", nif_sha224_init, NULL);
LvNif("sha224-feed", nif_sha224_feed, NULL);
LvNif("sha224-done", nif_sha224_done, NULL);
LvNif("sha384", nif_sha384, NULL);
LvNif("sha384-init", nif_sha384_init, NULL);
LvNif("sha384-feed", nif_sha384_feed, NULL);
LvNif("sha384-done", nif_sha384_done, NULL);
LvNif("sha512", nif_sha512, NULL);
LvNif("sha512-init", nif_sha512_init, NULL);
LvNif("sha512-feed", nif_sha512_feed, NULL);
LvNif("sha512-done", nif_sha512_done, NULL);
LvNif("blake2b", nif_blake2b, NULL);
LvNif("blake2b-init", nif_b2_init, NULL);
LvNif("blake2b-feed", nif_b2_feed, NULL);
LvNif("blake2b-done", nif_b2_done, NULL);
LvNif("sha3", nif_sha3, NULL);
LvNif("sha3-init", nif_k3_init, NULL);
LvNif("sha3-feed", nif_k3_feed, NULL);
LvNif("sha3-done", nif_k3_done, NULL);
LvNif("bsdsum", nif_bsdsum, NULL);
LvNif("crc32", nif_crc32, NULL);
LvNif("crc32-on", nif_crc32_on, NULL);
LvNif("cksum", nif_cksum, NULL);
LvNif("cksum-init", nif_ck_init, NULL);
LvNif("cksum-feed", nif_ck_feed, NULL);
LvNif("cksum-done", nif_ck_done, NULL);
