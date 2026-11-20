// dfa.c -- module dfa, the walk lex's tables are read by (src/apps/kore/lex.l, moon's lex.l)
//   (run t s i) -> end * 65536 + rule: the longest match of t's scanner in s at i, the
//   earliest rule on a tie; 0 where no rule matches. a bignum once it passes a charm
// t: w (bytes a state or rule), K and S (2 bytes each, little-endian), the byte -> class map,
// S rules (0: none), S * K next states (0: dead); state 1 is the start
#include "love.h"

static love_inline size_t rd(unsigned char const *p, size_t w, size_t x) {
  return w == 1 ? p[x] : (size_t) p[2 * x] | (size_t) p[2 * x + 1] << 8; }

static love_inline uint64_t dfa_walk(word t, word s, word i) {
  if (!strp(t) || !strp(s) || !charmp(i) || len(t) < 261) return 0;
  unsigned char const *T = (unsigned char const *) txt(t), *cl = T + 5,
                      *u = (unsigned char const *) txt(s);
  size_t w = T[0], K = (size_t) T[1] | (size_t) T[2] << 8, S = (size_t) T[3] | (size_t) T[4] << 8, n = len(s);
  if ((w != 1 && w != 2) || len(t) != 261 + S * w + S * K * w || getcharm(i) < 0 || (size_t) getcharm(i) > n)
    return 0;
  unsigned char const *ac = cl + 256, *tr = ac + S * w;
  size_t j = (size_t) getcharm(i), st = 1, r = 0, e = j;
  for (size_t k = j; st && st < S; k++) {
    size_t a = rd(ac, w, st);
    if (a) r = a, e = k;
    if (k >= n) break;
    st = rd(tr, w, st * K + cl[u[k]]); }
  return r ? (uint64_t) e << 16 | r : 0; }

#define dfa_limbs (64 / limb_bits)
#define dfa_req b2w(sizeof(struct big) + dfa_limbs * sizeof(love_limb))
static lvm(lvm_dfa_run) {
  uint64_t m = dfa_walk(Sp[0], Sp[1], Sp[2]);
  if (m <= (uint64_t) maxcharm) Sp[2] = putcharm((intptr_t) m);
  else {
    Have(dfa_req);
    struct big *b = (struct big*) Hp;
    int n = dfa_limbs;
    for (int k = 0; k < dfa_limbs; k++) b->limb[k] = (love_limb) (m >> (limb_bits * k));
    while (n > 1 && b->limb[n-1] == 0) n--;
    ini_big(b, n);
    Hp += b2w(sizeof(struct big) + (size_t) n * sizeof(love_limb));
    Sp[2] = word(b); }
  love_musttail return Nextp(1, 2); }

LvDef("run", dfa_run, 3, "dfa");
