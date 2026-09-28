// love/lib/bcrypt.c
// (bcrypt-hash pi pass salt) -> 32 bytes   | () misuse
// openbsd's bcrypt_hash, the block bcrypt_pbkdf repeats: an eksblowfish schedule keyed by
// two 64-byte sha-512 digests, then "OxychromaticBlowfishSwatDynamite" enciphered 64 times.
// pi is blowfish's starting state, P then S, 1042 big-endian words of pi's fraction; the
// caller derives it, so no table is written here. the pbkdf around this is love's.
#include "love.h"
#include <stdint.h>
#include <string.h>

typedef struct { uint32_t p[18], s[1024]; } bf;

static uint32_t bf_f(const bf *c, uint32_t x) {
 return ((c->s[x >> 24] + c->s[256 + (x >> 16 & 255)]) ^ c->s[512 + (x >> 8 & 255)])
        + c->s[768 + (x & 255)]; }

static void bf_enc(const bf *c, uint32_t *l, uint32_t *r) {
 uint32_t xl = *l ^ c->p[0], xr = *r;
 for (int i = 1; i <= 16; i += 2)
  xr ^= bf_f(c, xl) ^ c->p[i], xl ^= bf_f(c, xr) ^ c->p[i + 1];
 *l = xr ^ c->p[17], *r = xl; }

// four bytes big-endian, the stream wrapping
static uint32_t bf_word(const uint8_t *d, int n, int *j) {
 uint32_t w = 0;
 for (int i = 0; i < 4; i++) w = w << 8 | d[*j], *j = (*j + 1) % n;
 return w; }

// the key into P, then P and S re-enciphered in place, data (when there is some) mixed
// in as it goes
static void bf_expand(bf *c, const uint8_t *data, const uint8_t *key) {
 int j = 0, k = 0;
 uint32_t l = 0, r = 0, *w = c->p;
 for (int i = 0; i < 18; i++) c->p[i] ^= bf_word(key, 64, &j);
 for (int i = 0; i < 1042; i += 2) {
  if (data) l ^= bf_word(data, 64, &k), r ^= bf_word(data, 64, &k);
  bf_enc(c, &l, &r);
  w = i < 18 ? c->p + i : c->s + (i - 18);
  w[0] = l, w[1] = r; } }

static void bc_hash(const uint8_t *pi, const uint8_t *pass, const uint8_t *salt,
                    uint8_t out[32]) {
 static char const magic[] = "OxychromaticBlowfishSwatDynamite";
 bf c;
 uint32_t d[8];
 int j = 0;
 for (int i = 0; i < 1042; i++) {
  uint32_t v = bf_word(pi, 4168, &j);
  if (i < 18) c.p[i] = v; else c.s[i - 18] = v; }
 bf_expand(&c, salt, pass);
 for (int i = 0; i < 64; i++) bf_expand(&c, 0, salt), bf_expand(&c, 0, pass);
 j = 0;
 for (int i = 0; i < 8; i++) d[i] = bf_word((const uint8_t*) magic, 32, &j);
 for (int i = 0; i < 64; i++)
  for (int b = 0; b < 8; b += 2) bf_enc(&c, d + b, d + b + 1);
 for (int i = 0; i < 8; i++)
  out[4*i] = (uint8_t) d[i], out[4*i+1] = (uint8_t) (d[i] >> 8),
  out[4*i+2] = (uint8_t) (d[i] >> 16), out[4*i+3] = (uint8_t) (d[i] >> 24); }

ai_noinline static struct ai *host_bcrypt(struct ai *g) {
 word pw = g->sp[0], kw = g->sp[1], sw = g->sp[2];
 if (!strp(pw) || !strp(kw) || !strp(sw)
     || len(pw) != 4168 || len(kw) != 64 || len(sw) != 64)
  return g->sp[2] = ZeroPoint, g->sp += 2, g;
 uint8_t h[32];
 bc_hash((const uint8_t*) txt(pw), (const uint8_t*) txt(kw), (const uint8_t*) txt(sw), h);
 if (!ai_ok(g = str0(g, 32))) return g;            // pushes: the hash over the three args
 memcpy(txt(g->sp[0]), h, 32);
 g->sp[3] = g->sp[0], g->sp += 3;
 return g; }
static lvm(lvm_bcrypt) LvmCall(g, host_bcrypt)

static union u const
  nif_bcrypt[] = {{lvm_cur}, {.x = putcharm(3)}, {lvm_bcrypt}, {lvm_ret0}};
LvNif("bcrypt-hash", nif_bcrypt, NULL);
