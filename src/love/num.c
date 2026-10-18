// num.c -- big, the numeric tower; the cross-TU seam is love.h
#include "love.h"
#define limb_clz(x) (__builtin_clzll((unsigned long long) (x)) - (8 * (int) sizeof(unsigned long long) - limb_bits))  // of a nonzero limb
// floor(limb_bits * log10 2), 30103 = round(1e5 log10 2)
#define limb_dec_chunk  (limb_bits * 30103 / 100000)
// the most digits that still fit a limb
#define limb_hex_chunk  ((limb_bits - 1) / 4)
#define limb_oct_chunk  ((limb_bits - 1) / 3)
#define limb_base ((dlimb) 1 << limb_bits)
// bitwise ops only on machine-word cells (spec.l's width law), else the zero point
#define vop_bitp(op) ((op) >= vop_band && (op) <= vop_bsr)
static love_inline flo_t love_floor(flo_t x) { flo_t t = love_trunc(x); return t > x ? t - 1 : t; }
static love_inline flo_t net_flo(flo_t v) { return v != v ? 0 : v; }
struct love_zn { flo_t re, im; };                     // the net: a complex value
static love_inline struct love_zn zn(flo_t re, flo_t im) {
  struct love_zn z = {re, im}; return z; }
static dlimb div128by64(love_limb hi, love_limb lo, love_limb d, love_limb *rem);
static love_limb
 div2by1(love_limb hi, love_limb lo, love_limb d, love_limb *rem),
 rdigit(char c);
static love_noinline bool vquot_needs_float(int op, word a, word b);
static love_noinline int
 mag_add(love_limb *r, love_limb const *a, int na, love_limb const *b, int nb),
 mag_cmp(love_limb const *a, int na, love_limb const *b, int nb),
 mag_mul_add_small(love_limb *a, int n, love_limb mul, love_limb add),
 mag_sub(love_limb *r, love_limb const *a, int na, love_limb const *b, int nb);
static love_noinline void
 mag_divmod(love_limb *q, love_limb *r, love_limb const *u, int m, love_limb const *v, int n,
            love_limb *un, love_limb *vn),
 vbin_fill(struct tray *r, word a, word b, int op, bool fdom),
 vmap1_fill(struct tray *r, struct tray *a, flo_t (*fn)(flo_t)),
 vmap2_fill(struct tray *r, word a, word b, flo_t (*fn)(flo_t, flo_t));
static int
 big_mul_mag(love_limb *r, love_limb const *a, int na, love_limb const *b, int nb, love_limb *t),
 big_nlimbs(word x),
 cmp_rank(struct g *g, word x),
 load_int_mag(word x, love_limb scratch[wlimbs], love_limb const **out, bool *neg),
 mag_copy(love_limb *dst, love_limb const *src, int n),
 mag_dnorm(love_limb *un, love_limb *vn, love_limb const *u, int m, love_limb const *v, int n);
static void mag_ddenorm(love_limb *r, love_limb const *un, int n, int s);
static intptr_t
 bytes_cmp(const char *pa, uintptr_t la, const char *pb, uintptr_t lb),
 galaxy_tie(struct tray *va, struct tray *vb),
 mint_cmp(struct g *g, word a, word b),
 vcmp_sign(int op, int s),
 vop_int(int op, intptr_t a, intptr_t b);
static lvm_t lvm_aextreme, lvm_bdiv, lvm_bmul, lvm_cmp_ord, lvm_kmul;
static struct g
 *bdiv_setup(struct g *g, int which),
 *bmul_setup(struct g *g),
 *kmul_setup(struct g *g),
 *big_read_radix(struct g *g, love_limb radix, int chunk, uintptr_t pfx);
static struct love_zn tray_cell_zn(struct tray *v, uintptr_t i);
static uintptr_t bdim(uintptr_t da, uintptr_t db);
static union u *as_big(word **hp, word x);
static void
 big_addsub(love_limb *r, int *rn, bool *rneg, love_limb const *a, int na, bool nega,
            love_limb const *b, int nb, bool negb, bool subtract),
 mag_add_off(love_limb *r, int rn, love_limb const *s, int sn, int off),
 mag_mul_kara(love_limb *r, love_limb const *a, love_limb const *b, int n, love_limb *t);
// big: fixnum -> sun box -> bignum. multi-limb work is noinline helpers over raw limbs that
// never allocate, so the VM keeps its tail calls; never __multi3/__udivti3, which -nostdlib lacks

static love_inline int big_nlimbs(word x) {
 intptr_t s = big(x)->slen;
 return (int) (s < 0 ? -s : s); }

uintptr_t big_bytes(struct big *b) {
 intptr_t n = b->slen < 0 ? -b->slen : b->slen;
 return sizeof(struct big) + (uintptr_t) n * sizeof(love_limb); }

// magnitudes: little-endian limbs, normalized in, big_canon'd out

static int mag_copy(love_limb *dst, love_limb const *src, int n) {
 for (int i = 0; i < n; i++) dst[i] = src[i];
 return n; }

static love_noinline int mag_cmp(love_limb const *a, int na, love_limb const *b, int nb) {
 while (na > 0 && a[na-1] == 0) na--;
 while (nb > 0 && b[nb-1] == 0) nb--;
 if (na != nb) return na < nb ? -1 : 1;
 for (int i = na - 1; i >= 0; i--) if (a[i] != b[i]) return a[i] < b[i] ? -1 : 1;
 return 0; }

// r = a + b, r distinct, capacity max(na,nb)+1 -> the limb count
static love_noinline int mag_add(love_limb *r, love_limb const *a, int na, love_limb const *b, int nb) {
 if (na < nb) { love_limb const *t = a; a = b; b = t; int u = na; na = nb; nb = u; }
 dlimb s, c = 0; int i = 0;
 for (; i < nb; i++) s = (dlimb) a[i] + b[i] + c, r[i] = (love_limb) s, c = s >> limb_bits;
 for (; i < na; i++) s = (dlimb) a[i] + c,        r[i] = (love_limb) s, c = s >> limb_bits;
 if (c) r[i++] = (love_limb) c;
 return i; }

// r = a - b, a >= b, r distinct -> na, high zeros the caller's
static love_noinline int mag_sub(love_limb *r, love_limb const *a, int na, love_limb const *b, int nb) {
 sdlimb borrow = 0; int i = 0;
 for (; i < nb; i++) {
  sdlimb d = (sdlimb) a[i] - b[i] - borrow;
  if (d < 0) d += (sdlimb) limb_base, borrow = 1; else borrow = 0;
  r[i] = (love_limb) d; }
 for (; i < na; i++) {
  sdlimb d = (sdlimb) a[i] - borrow;
  if (d < 0) d += (sdlimb) limb_base, borrow = 1; else borrow = 0;
  r[i] = (love_limb) d; }
 return na; }

// rows [i0, end) of the schoolbook r = a * b; only row 0 reads limbs no row wrote, so lvm_bmul
// can run a chunk per dispatch and yield
static love_noinline void mag_mul_rows(love_limb *r, love_limb const *a, int i0, int end, love_limb const *b, int nb) {
 if (!i0) for (int j = 0; j < nb; j++) r[j] = 0;
 for (int i = i0; i < end; i++) {
  dlimb carry = 0; love_limb ai = a[i];            // a limb, so ai*b[j] is 64x64->128, not __multi3
  for (int j = 0; j < nb; j++) {
   dlimb s = (dlimb) ai * b[j] + r[i+j] + carry;
   r[i+j] = (love_limb) s; carry = s >> limb_bits; }
  r[i+nb] = (love_limb) carry; } }

// r distinct, capacity na+nb
static love_inline void mag_mul(love_limb *r, love_limb const *a, int na, love_limb const *b, int nb) {
 mag_mul_rows(r, a, 0, na, b, nb); }

// a = a*mul + add in place, room for a carry at a[n] -> the limb count
static love_noinline int mag_mul_add_small(love_limb *a, int n, love_limb mul, love_limb add) {
 dlimb c = add;
 for (int i = 0; i < n; i++) { dlimb s = (dlimb) a[i] * mul + c; a[i] = (love_limb) s; c = s >> limb_bits; }
 if (c) a[n++] = (love_limb) c;
 return n; }

// 128/64 with hi < d, so the quotient fits a limb
static love_inline love_limb div2by1(love_limb hi, love_limb lo, love_limb d, love_limb *rem) {
#if defined(__x86_64__) && limb_bits == 64 && defined(__GNUC__) && !defined(__mooncc__)
 // mooncc emits the C face below as divq itself
 __asm__("divq %2" : "+a"(lo), "+d"(hi) : "r"(d));
 return *rem = hi, lo;
#else
 dlimb num = ((dlimb) hi << limb_bits) | lo;
 return *rem = (love_limb) (num % d), (love_limb) (num / d);
#endif
}
// the full 128/64 quotient for q-hat, as two divq-safe steps
static love_inline dlimb div128by64(love_limb hi, love_limb lo, love_limb d, love_limb *rem) {
 love_limb qhi = hi / d, r1 = hi % d;
 love_limb qlo = div2by1(r1, lo, d, rem);
 return ((dlimb) qhi << limb_bits) | qlo; }

// knuth's algorithm D (Hacker's Delight divmnu) in three pieces, shared with lvm_bdiv.
// u (m limbs) and v (n >= 2) shifted so v's top bit is set, into un (m+1) and vn -> the shift
static int mag_dnorm(love_limb *un, love_limb *vn, love_limb const *u, int m, love_limb const *v, int n) {
 int s = limb_clz(v[n-1]);
 for (int i = n - 1; i > 0; i--) vn[i] = (v[i] << s) | (s ? (dlimb) v[i-1] >> (limb_bits - s) : 0);
 vn[0] = v[0] << s;
 un[m] = s ? (dlimb) u[m-1] >> (limb_bits - s) : 0;
 for (int i = m - 1; i > 0; i--) un[i] = (u[i] << s) | (s ? (dlimb) u[i-1] >> (limb_bits - s) : 0);
 un[0] = u[0] << s;
 return s; }

// one quotient limb: q-hat from un's top three at j, qhat*vn subtracted, added back if one high
static love_inline love_limb mag_divstep(love_limb *un, love_limb const *vn, int n, int j) {
 dlimb const B = limb_base;
 love_limb rr;
 dlimb qhat = div128by64(un[j+n], un[j+n-1], vn[n-1], &rr), rhat = rr;
 while (qhat >= B || qhat * vn[n-2] > ((rhat << limb_bits) | un[j+n-2])) {
  qhat--; rhat += vn[n-1];
  if (rhat >= B) break; }
 sdlimb borrow = 0;
 for (int i = 0; i < n; i++) {
  dlimb p = (dlimb) (love_limb) qhat * vn[i];   // qhat < B: a limb, so 64x64->128
  sdlimb sub = (sdlimb) un[i+j] - borrow - (sdlimb) (love_limb) p;
  un[i+j] = (love_limb) sub;
  borrow = (sdlimb) (p >> limb_bits) - (sub >> limb_bits); }
 sdlimb sub = (sdlimb) un[j+n] - borrow;
 un[j+n] = (love_limb) sub;
 if (sub >= 0) return (love_limb) qhat;
 dlimb carry = 0;                            // one too big: add back
 for (int i = 0; i < n; i++) {
  dlimb t = (dlimb) un[i+j] + vn[i] + carry;
  un[i+j] = (love_limb) t;
  carry = t >> limb_bits; }
 un[j+n] = (love_limb) (un[j+n] + carry);
 return (love_limb) qhat - 1; }

// the remainder: un's low n limbs, shifted back
static void mag_ddenorm(love_limb *r, love_limb const *un, int n, int s) {
 for (int i = 0; i < n; i++) r[i] = s ? (un[i] >> s) | ((dlimb) un[i+1] << (limb_bits - s)) : un[i]; }

// u (m limbs) / v (n limbs, m >= n) -> q (m-n+1 limbs), r (n limbs); un/vn are scratch
static love_noinline void mag_divmod(love_limb *q, love_limb *r,
  love_limb const *u, int m, love_limb const *v, int n, love_limb *un, love_limb *vn) {
 if (n == 1) {
  love_limb rem = 0;
  for (int j = m - 1; j >= 0; j--) { love_limb rr; q[j] = div2by1(rem, u[j], v[0], &rr); rem = rr; }
  r[0] = rem; return; }
 int s = mag_dnorm(un, vn, u, m, v, n);
 for (int j = m - n; j >= 0; j--) q[j] = mag_divstep(un, vn, n, j);
 mag_ddenorm(r, un, n, s); }

// an integer x as a magnitude -> the limb count, 0 for zero. a fixnum or box fills scratch
// (wlimbs: the limbs of one word); a bignum's *out points into the heap, stable until a GC
static int load_int_mag(word x, love_limb scratch[wlimbs], love_limb const **out, bool *neg) {
 if (bigp(x)) { struct big *b = big(x); intptr_t s = b->slen;
  *neg = s < 0, *out = b->limb; return (int) (s < 0 ? -s : s); }
 intptr_t v = toint(x);
 *neg = v < 0;
 uintptr_t u = *neg ? (uintptr_t) 0 - (uintptr_t) v : (uintptr_t) v;
 int k = 0;
 for (int i = 0; i < wlimbs; i++) { scratch[i] = (love_limb) (u >> (limb_bits * i)); if (scratch[i]) k = i + 1; }
 *out = scratch;
 return k; }

flo_t big_to_flo(word x) {
 struct big *b = big(x);
 intptr_t sl = b->slen;
 bool neg = sl < 0;
 int n = (int) (neg ? -sl : sl);
 double r = 0;
 for (int i = n - 1; i >= 0; i--) r = r * (double) limb_base + (double) b->limb[i];
 return (flo_t) (neg ? -r : r); }

int big_cmp(word a, word b) {
 love_limb sa[wlimbs], sb[wlimbs]; love_limb const *la, *lb; bool na, nb;
 int nla = load_int_mag(a, sa, &la, &na), nlb = load_int_mag(b, sb, &lb, &nb);
 bool aneg = na && nla > 0, bneg = nb && nlb > 0;
 if (aneg != bneg) return aneg ? -1 : 1;
 int c = mag_cmp(la, nla, lb, nlb);
 return aneg ? -c : c; }

// the smallest tier: the one sink that keeps the tiers disjoint, so eqv and keys hold
word big_canon(word **hp, love_limb const *limb, int n, bool neg) {
 while (n > 0 && limb[n-1] == 0) n--;
 if (n == 0) return zero;
 if (n <= wlimbs) {
  uintptr_t u = 0;
  for (int i = 0; i < n; i++) u |= (uintptr_t) limb[i] << (limb_bits * i);
  uintptr_t const fixmag = (uintptr_t) 1 << (Bits - 2);   // |mincharm| = 2^(W-2)
  if (!neg) { if (u <= fixmag - 1) return putcharm((intptr_t) u); }
  else if (u <= fixmag) return putcharm((intptr_t) ((uintptr_t) 0 - u)); }   // incl mincharm
 struct big *b = ini_big(big(*hp), neg ? -n : n);
 for (int i = 0; i < n; i++) b->limb[i] = limb[i];
 *hp += b2w(sizeof(struct big) + (size_t) n * sizeof(love_limb));
 return word(b); }

// sign-magnitude r = a +/- b
static void big_addsub(love_limb *r, int *rn, bool *rneg,
  love_limb const *a, int na, bool nega, love_limb const *b, int nb, bool negb, bool subtract) {
 bool sb = subtract ? !negb : negb;
 if (nega == sb) { *rn = mag_add(r, a, na, b, nb); *rneg = nega; }
 else { int c = mag_cmp(a, na, b, nb);
  if (c == 0) { *rn = 0; *rneg = false; }
  else if (c > 0) { *rn = mag_sub(r, a, na, b, nb); *rneg = nega; }
  else { *rn = mag_sub(r, b, nb, a, na); *rneg = sb; } } }

// s into r at limb off; r sized for the whole result, so the carry settles in it
static void mag_add_off(love_limb *r, int rn, love_limb const *s, int sn, int off) {
 dlimb c = 0; int i = 0;
 for (; i < sn; i++)            { dlimb t = (dlimb) r[off+i] + s[i] + c; r[off+i] = (love_limb) t; c = t >> limb_bits; }
 for (; c && off + i < rn; i++) { dlimb t = (dlimb) r[off+i] + c;        r[off+i] = (love_limb) t; c = t >> limb_bits; } }

// karatsuba for equal lengths; t is scratch, 4n + 8 log n limbs: each level's sums and
// middle product, then the next level's
#define kara_cutoff 40   // limbs per operand, the measured crossover
static void mag_mul_kara(love_limb *r, love_limb const *a, love_limb const *b, int n, love_limb *t) {
 if (n < kara_cutoff) { mag_mul(r, a, n, b, n); return; }
 int m = n / 2, h = n - m;
 mag_mul_kara(r,       a,     b,     m, t);           // z0 -> r[0..2m)
 mag_mul_kara(r + 2*m, a + m, b + m, h, t);           // z2 -> r[2m..2n)
 int z0n = 2*m;
 while (z0n > 0 && r[z0n-1] == 0) z0n--;
 int z2n = 2*h;
 while (z2n > 0 && r[2*m + z2n-1] == 0) z2n--;
 love_limb *sa = t, *sb = sa + (h+1), *z1 = sb + (h+1);
 int nsa = mag_add(sa, a, m, a + m, h), nsb = mag_add(sb, b, m, b + m, h);
 for (int i = nsa; i <= h; i++) sa[i] = 0;
 for (int i = nsb; i <= h; i++) sb[i] = 0;
 mag_mul_kara(z1, sa, sb, h + 1, t + 4 * (h+1));     // z1 = (a0+a1)(b0+b1), zero-padded to h+1
 int nz1 = 2 * (h+1);
 while (nz1 > 0 && z1[nz1-1] == 0) nz1--;
 nz1 = mag_sub(z1, z1, nz1, r,       z0n);
 while (nz1 > 0 && z1[nz1-1] == 0) nz1--;   // z1 -= z0
 nz1 = mag_sub(z1, z1, nz1, r + 2*m, z2n);
 while (nz1 > 0 && z1[nz1-1] == 0) nz1--;   // z1 -= z2
 mag_add_off(r, 2*n, z1, nz1, m); }                  // r += z1 * B^m

static int big_mul_mag(love_limb *r, love_limb const *a, int na, love_limb const *b, int nb, love_limb *t) {
 if (na == nb) mag_mul_kara(r, a, b, na, t);
 else mag_mul(r, a, na, b, nb);
 int n = na + nb;
 while (n > 0 && r[n-1] == 0) n--;
 return n; }

// + - * / % packed, a zero divisor screened by the caller: the result at sp[1], one popped,
// ip advanced, so the caller is Pack; binop; Unpack; Continue
struct g *big_binop(struct g *g, int vop) {
 word a = g->sp[0], b = g->sp[1];
 int na = bigp(a) ? big_nlimbs(a) : 2, nb = bigp(b) ? big_nlimbs(b) : 2,
     bound = na + nb + 2,                        // the result's bound
     work = 4 * (na + nb) + 16;                  // divmod scratch's
 uintptr_t res_area = Width(struct big) + b2w((size_t) bound * sizeof(love_limb)),
           ws_words = b2w((size_t) (bound + work) * sizeof(love_limb));
 if (!ok(g = have(g, res_area + ws_words))) return g;
 a = g->sp[0], b = g->sp[1];                     // re-fetch (have may have GC'd)
 love_limb sa[wlimbs], sb[wlimbs]; love_limb const *la, *lb; bool nega, negb;
 int nla = load_int_mag(a, sa, &la, &nega), nlb = load_int_mag(b, sb, &lb, &negb);
 love_limb *rmag = (love_limb*) (g->hp + res_area), *scr = rmag + bound;
 int rn = 0;
 bool rneg = false;
 switch (vop) {
  case vop_add: big_addsub(rmag, &rn, &rneg, la, nla, nega, lb, nlb, negb, false); break;
  case vop_sub: big_addsub(rmag, &rn, &rneg, la, nla, nega, lb, nlb, negb, true); break;
  case vop_mul: rn = big_mul_mag(rmag, la, nla, lb, nlb, scr); rneg = nega != negb; break;
  default: {                                     // quot and rem, truncated
   int c = mag_cmp(la, nla, lb, nlb);
   if (c < 0) {                                  // |a| < |b|: q = 0, r = a
    if (vop == vop_rem) rn = mag_copy(rmag, la, nla), rneg = nega; }
   else {
    love_limb *q = scr, *rem = q + (nla - nlb + 1), *un = rem + nlb, *vn = un + (nla + 1);
    mag_divmod(q, rem, la, nla, lb, nlb, un, vn);
    if (vop != vop_rem) {
     int qn = nla - nlb + 1; while (qn > 0 && q[qn-1] == 0) qn--;
     rn = mag_copy(rmag, q, qn), rneg = nega != negb; }
    else {
     int rr = nlb; while (rr > 0 && rem[rr-1] == 0) rr--;
     rn = mag_copy(rmag, rem, rr), rneg = nega; } } } }
 return *++g->sp = big_canon(&g->hp, rmag, rn, rneg), ++g->ip, g; }

// bitwise over the tower, as infinite two's complement: w = max + 1 limb of sign headroom
static void twos_neg(love_limb *r, int w) {
 love_limb carry = 1;
 for (int i = 0; i < w; i++) { love_limb v = (love_limb) (~r[i] + carry); carry = carry && !v; r[i] = v; } }
static void mag_twos(love_limb *r, love_limb const *m, int n, bool neg, int w) {
 for (int i = 0; i < w; i++) r[i] = i < n ? m[i] : 0;
 if (neg) twos_neg(r, w); }
struct g *big_bitop(struct g *g, int vop) {
 word a = g->sp[0], b = g->sp[1];
 int na = bigp(a) ? big_nlimbs(a) : wlimbs, nb = bigp(b) ? big_nlimbs(b) : wlimbs,
     w = (na > nb ? na : nb) + 1;
 uintptr_t res_area = Width(struct big) + b2w((size_t) w * sizeof(love_limb)),
           ws_words = b2w((size_t) (2 * w) * sizeof(love_limb));
 if (!ok(g = have(g, res_area + ws_words))) return g;
 a = g->sp[0], b = g->sp[1];                     // re-fetch (have may have GC'd)
 love_limb sa[wlimbs], sb[wlimbs]; love_limb const *la, *lb; bool nega, negb;
 int nla = load_int_mag(a, sa, &la, &nega), nlb = load_int_mag(b, sb, &lb, &negb);
 love_limb *ra = (love_limb*) (g->hp + res_area), *rb = ra + w;
 mag_twos(ra, la, nla, nega, w);
 mag_twos(rb, lb, nlb, negb, w);
 for (int i = 0; i < w; i++)
  ra[i] = vop == vop_band ? (love_limb) (ra[i] & rb[i])
        : vop == vop_bor  ? (love_limb) (ra[i] | rb[i])
        :                   (love_limb) (ra[i] ^ rb[i]);
 bool rneg = vop == vop_band ? (nega && negb) : vop == vop_bor ? (nega || negb) : (nega != negb);
 if (rneg) twos_neg(ra, w);
 int rn = w; while (rn > 0 && ra[rn-1] == 0) rn--;
 return *++g->sp = big_canon(&g->hp, ra, rn, rneg), ++g->ip, g; }

// << and >> over the tower: left promotes, right floors (-5 >> 1 = -3, where // gives -2), a
// negative count turns round, and one past the width answers 0 or -1
struct g *big_shift(struct g *g, int vop) {
 word a = g->sp[0], b = g->sp[1];
 love_limb sb[wlimbs]; love_limb const *lb; bool negk;
 int nlb = load_int_mag(b, sb, &lb, &negk);
 // the count, saturated past an int
 uintptr_t kk = 0; bool khuge = nlb > (int) (sizeof(uintptr_t) / sizeof(love_limb));
 for (int i = 0; i < nlb && !khuge; i++) {
  if ((uintptr_t) (limb_bits * i) >= 8 * sizeof(uintptr_t)) { khuge = lb[i] != 0; break; }
  kk |= (uintptr_t) lb[i] << (limb_bits * i); }
 if (kk > (uintptr_t) INT32_MAX) khuge = true;
 bool left = (vop == vop_bsl) != negk;
 int k = khuge ? 0 : (int) kk;
 int na = bigp(a) ? big_nlimbs(a) : wlimbs;
 int ls = khuge ? 0 : k / limb_bits, bs = khuge ? 0 : k % limb_bits;
 int w = left ? na + ls + 2 : na + 2;
 if (left && khuge) return encode(g, status_scare);   // 2^huge: no heap holds it
 uintptr_t res_area = Width(struct big) + b2w((size_t) w * sizeof(love_limb)),
           ws_words = b2w((size_t) w * sizeof(love_limb));
 if (!ok(g = have(g, res_area + ws_words))) return g;
 a = g->sp[0];                                    // re-fetch past the have
 love_limb sa[wlimbs]; love_limb const *la; bool neg;
 int nla = load_int_mag(a, sa, &la, &neg);
 love_limb *r = (love_limb*) (g->hp + res_area);
 int rn = 0;
 if (left) {
  for (int i = 0; i < ls; i++) r[i] = 0;
  if (!bs) { for (int i = 0; i < nla; i++) r[ls + i] = la[i]; rn = ls + nla; }
  else { love_limb carry = 0;
   for (int i = 0; i < nla; i++) {
    r[ls + i] = (love_limb) ((la[i] << bs) | carry);
    carry = (love_limb) (la[i] >> (limb_bits - bs)); }
   r[ls + nla] = carry, rn = ls + nla + 1; } }
 else if (khuge || ls >= nla) rn = 0, r[0] = 0;   // shifted past the top: 0, or -1 once floored
 else {
  rn = nla - ls;
  if (!bs) for (int i = 0; i < rn; i++) r[i] = la[ls + i];
  else for (int i = 0; i < rn; i++)
   r[i] = (love_limb) ((la[ls + i] >> bs) | (i + 1 < rn ? (la[ls + i + 1] << (limb_bits - bs)) : 0)); }
 if (!left && neg) {                              // floor: a lost bit rounds away from zero
  bool lost = khuge || ls >= nla;
  for (int i = 0; i < ls && !lost && i < nla; i++) lost = la[i] != 0;
  if (!lost && bs) lost = (la[ls] & (love_limb) ((((love_limb) 1) << bs) - 1)) != 0;
  if (lost) { love_limb carry = 1;
   for (int i = 0; i < rn && carry; i++) { r[i] = (love_limb) (r[i] + 1); carry = !r[i]; }
   if (carry) r[rn++] = 1; } }
 while (rn > 0 && r[rn-1] == 0) rn--;
 return *++g->sp = big_canon(&g->hp, r, rn, neg && rn > 0), ++g->ip, g; }


// `/` over bignums: exact when b divides a, else a float; a zero divisor screened by the caller
struct g *big_quot_true(struct g *g) {
 word a = g->sp[0], b = g->sp[1];
 int na = bigp(a) ? big_nlimbs(a) : 2, nb = bigp(b) ? big_nlimbs(b) : 2,
     bound = na + nb + 2, work = 4 * (na + nb) + 16;
 uintptr_t res_area = Width(struct big) + b2w((size_t) bound * sizeof(love_limb)),
           ws_words = b2w((size_t) (bound + work) * sizeof(love_limb));
 if (!ok(g = have(g, res_area + ws_words + box_req))) return g;
 a = g->sp[0], b = g->sp[1];                     // re-fetch (have may have GC'd)
 love_limb sa[wlimbs], sb[wlimbs];
 love_limb const *la, *lb;
 bool nega, negb;
 int nla = load_int_mag(a, sa, &la, &nega), nlb = load_int_mag(b, sb, &lb, &negb);
 love_limb *rmag = (love_limb*) (g->hp + res_area), *scr = rmag + bound;
 bool rneg = false, exact;
 int rn = 0, c = mag_cmp(la, nla, lb, nlb);
 if (c < 0) exact = (nla == 0);                  // |a| < |b|: q = 0
 else {
  love_limb *q = scr,
          *rem = q + (nla - nlb + 1),
          *un = rem + nlb,
          *vn = un + (nla + 1);
  mag_divmod(q, rem, la, nla, lb, nlb, un, vn);
  int rr = nlb;
  while (rr > 0 && rem[rr-1] == 0) rr--;
  exact = (rr == 0);
  int qn = nla - nlb + 1;
  while (qn > 0 && q[qn-1] == 0) qn--;
  rn = mag_copy(rmag, q, qn), rneg = nega != negb; }
 if (exact) g->sp[1] = big_canon(&g->hp, rmag, rn, rneg);
 else g->sp[1] = mk_gem(&g->hp, toflo(a) / toflo(b));  // no GC since the re-fetch
 g->sp++;
 g->ip = (union u*) g->ip + 1;
 return g; }

// a yieldable schoolbook: a self-looping op folding bmul_chunk limb-mults per dispatch into a
// cask, state [i, r, ret_ip, a, b]; the operands heap bignums, no &scratch (the sibcall law)
#define bmul_chunk (1 << 14)
static union u const bmul_loop[1] = { { .ap = lvm_bmul } };

static union u *as_big(word **hp, word x) {
 if (bigp(x)) return cell(x);
 intptr_t v = toint(x);
 bool neg = v < 0;
 uintptr_t u = neg ? (uintptr_t) 0 - (uintptr_t) v : (uintptr_t) v;
 love_limb tmp[wlimbs];
 int n = 0;
 for (int i = 0; i < wlimbs; i++) {
   tmp[i] = (love_limb) (u >> (limb_bits * i));
   if (tmp[i]) n = i + 1; }
 struct big *b = ini_big(big(*hp), neg ? -n : n);
 memcpy(b->limb, tmp, (size_t) n * sizeof(love_limb));
 *hp += b2w(sizeof(struct big) + (size_t) n * sizeof(love_limb));
 return cell((word) b); }

// one have, so no half-built state is ever seen
static struct g *bmul_setup(struct g *g) {
 word a = g->sp[0], b = g->sp[1];
 int na = bigp(a) ? big_nlimbs(a) : 2, nb = bigp(b) ? big_nlimbs(b) : 2;
 uintptr_t rbytes = (uintptr_t) (na + nb) * sizeof(love_limb),
           sreq = str_width(rbytes),
           breq = Width(struct cask) + Width(struct tag),
           bigmax = Width(struct big) + b2w((size_t) wlimbs * sizeof(love_limb));
 if (!ok(g = have(g, 2 * bigmax + sreq + breq + 3))) return g;
 a = g->sp[0], b = g->sp[1];
 union u *abig = as_big(&g->hp, a), *bbig = as_big(&g->hp, b), *ret = g->ip + 1;
 struct str *s = ini_str(str(g->hp), rbytes);
 g->hp += sreq;
 memset(txt(s), 0, rbytes);
 union u *k = (union u*) g->hp;
 g->hp += breq;
 cask(k)->ap = lvm_cask;
 cask(k)->str = s;
 tagthread(k, Width(struct cask));
 g->sp -= 3;                                       // [i, r, ret_ip, abig, bbig]
 g->sp[0] = putcharm(0), g->sp[1] = word(k), g->sp[2] = word(ret);
 g->sp[3] = word(abig), g->sp[4] = word(bbig);
 g->ip = (union u*) bmul_loop;
 return g; }

// a yieldable karatsuba in one cask [hdr | job stack | A(n) | B(n) | R(2n) | scratch], read by
// offset each dispatch. a job splits (three children, LIFO) or combines; the shorter is zero-padded.
// a lopsided pair is cut instead: n the shorter's width, the longer np pieces of it, each
// piece's product laid in T and added into R by a driver job (state 2 + the next piece)
#define kmul_chunk (1 << 14)   // leaf limb-mults per dispatch
#define KmulHdr 8             // [0]=n [1]=top [2]=sign [3]=r_off [4]=R's limbs [5]=np [6]=t_off
#define KmulJw  6             // job record limbs: ar, br, n, rr, sr, state
static union u const kmul_loop[1] = { { .ap = lvm_kmul } };

static struct g *kmul_setup(struct g *g) {
 word a = g->sp[0], b = g->sp[1];
 // both bignums, n >= kara_cutoff: the longer's limbs, or a lopsided pair's shorter's
 int lo = min(big_nlimbs(a), big_nlimbs(b)), hi = max(big_nlimbs(a), big_nlimbs(b)),
     np = 2 * lo < hi ? (hi + lo - 1) / lo : 0, n = np ? lo : hi, d = 0;
 for (int t = n; t >= kara_cutoff; t = (t + 1) / 2) d++;   // karatsuba depth
 uintptr_t njob = (uintptr_t) 8 * d + 32,                 // ~3d live
           scrn = (uintptr_t) 6 * n + 16 * (uintptr_t) d + 256,
           asz = np ? (uintptr_t) np * n : (uintptr_t) n,
           rsz = np ? asz + n : 2 * (uintptr_t) n,
           jobs_off = KmulHdr,
           a_off = jobs_off + njob * KmulJw,
           b_off = a_off + asz,
           r_off = b_off + n,
           t_off = r_off + rsz,
           scr_off = t_off + (np ? 2 * (uintptr_t) n : 0),
           wslimbs = scr_off + scrn,
           sreq = str_width(wslimbs * sizeof(love_limb)),
           breq = Width(struct cask) + Width(struct tag);
 if (!ok(g = have(g, sreq + breq + 3))) return g;
 a = g->sp[0], b = g->sp[1];
 love_limb sa[wlimbs], sb[wlimbs]; love_limb const *la, *lb; bool nega, negb;
 int na = load_int_mag(a, sa, &la, &nega), nb = load_int_mag(b, sb, &lb, &negb);
 if (na < nb) { love_limb const *x = la; la = lb, lb = x; int y = na; na = nb, nb = y; }   // the longer in A
 struct str *ws_s = ini_str(str(g->hp), wslimbs * sizeof(love_limb));
 g->hp += sreq;
 love_limb *ws = (love_limb*) txt(ws_s);
 memset(ws, 0, wslimbs * sizeof(love_limb));
 memcpy(ws + a_off, la, (size_t) na * sizeof(love_limb));
 memcpy(ws + b_off, lb, (size_t) nb * sizeof(love_limb));
 ws[0] = (love_limb) n, ws[1] = 1, ws[2] = (love_limb) (nega != negb), ws[3] = r_off;
 ws[4] = rsz, ws[5] = (love_limb) np, ws[6] = t_off;
 love_limb *j0 = ws + jobs_off;                             // the root job: A x B -> R, or the driver
 j0[0] = a_off, j0[1] = b_off, j0[2] = (love_limb) n, j0[3] = np ? t_off : r_off, j0[4] = scr_off, j0[5] = np ? 2 : 0;
 union u *k = (union u*) g->hp; g->hp += breq;
 cask(k)->ap = lvm_cask;
 cask(k)->str = ws_s;
 tagthread(k, Width(struct cask));
 union u *ret = g->ip + 1;
 g->sp[0] = word(k), g->sp[1] = word(ret);                // [ws, ret_ip] over [a, b]
 g->ip = (union u*) kmul_loop;
 return g; }

// FIXME: types that need fewer casts
static lvm(lvm_kmul) {
 love_limb *ws = (love_limb*) txt(cask(Sp[0])->str);
 int top = (int) ws[1];
 love_limb *jobs = ws + KmulHdr;
 long budget = kmul_chunk;
 while (top > 0 && budget > 0) {
  ws[1] = (love_limb) top;
  YieldCheck(); // per job: once per dispatch yields too rarely
  love_limb *J = jobs + (uintptr_t) (top - 1) * KmulJw;
  uintptr_t ar = J[0], br = J[1], rr = J[3], sr = J[4];
  int jn = (int) J[2], st = (int) J[5];
  if (st >= 2) {                                          // driver: add the last piece's T, lay the next
   int k = st - 2;
   if (k > 0) mag_add_off(ws + ws[3], (int) ws[4], ws + rr, 2 * jn, (k - 1) * jn);
   if (k < (int) ws[5]) {
    J[5] = (love_limb) (st + 1);
    love_limb *P = jobs + (uintptr_t) top * KmulJw;      // piece k x B -> T
    P[0] = ar + (uintptr_t) k * (uintptr_t) jn, P[1] = br, P[2] = (love_limb) jn, P[3] = rr, P[4] = sr, P[5] = 0;
    top++; }
   else top--;
   budget -= 2 * jn; continue; }
  if (jn < kara_cutoff) {                                 // a leaf: schoolbook
   mag_mul(ws + rr, ws + ar, jn, ws + br, jn);
   budget -= (long) jn * jn; top--; continue; }
  int m = jn / 2, h = jn - m;
  if (st == 0) {                                          // split
   uintptr_t saO = sr, sbO = sr + (uintptr_t) (h + 1),
             z1O = sr + 2 * (uintptr_t) (h + 1), csr = sr + 4 * (uintptr_t) (h + 1);
   int ns = mag_add(ws + saO, ws + ar, m, ws + ar + m, h);            // sa = a_lo + a_hi
   memset(ws + saO + ns, 0, (size_t) (h + 1 - ns) * sizeof(love_limb));   // exactly h+1
   int nt = mag_add(ws + sbO, ws + br, m, ws + br + m, h);
   memset(ws + sbO + nt, 0, (size_t) (h + 1 - nt) * sizeof(love_limb));
   memset(ws + z1O, 0, (size_t) 2 * (h + 1) * sizeof(love_limb));
   J[5] = 1;                                                          // combines when it returns
   love_limb *z1J = jobs + (uintptr_t) top       * KmulJw;            // z1 = sa*sb
   z1J[0] = saO, z1J[1] = sbO, z1J[2] = (love_limb) (h + 1), z1J[3] = z1O, z1J[4] = csr, z1J[5] = 0;
   love_limb *z2J = jobs + (uintptr_t) (top + 1) * KmulJw;            // z2 = a_hi*b_hi -> r[2m..]
   z2J[0] = ar + m, z2J[1] = br + m, z2J[2] = (love_limb) h, z2J[3] = rr + 2 * (uintptr_t) m, z2J[4] = csr, z2J[5] = 0;
   love_limb *z0J = jobs + (uintptr_t) (top + 2) * KmulJw;            // z0 = a_lo*b_lo -> r[0..]
   z0J[0] = ar, z0J[1] = br, z0J[2] = (love_limb) m, z0J[3] = rr, z0J[4] = csr, z0J[5] = 0;
   top += 3; budget -= jn;                                            // pops z0, z2, z1, then this
  } else {                                                // combine
   uintptr_t z1O = sr + 2 * (uintptr_t) (h + 1);
   int z0n = 2 * m;
   while (z0n > 0 && ws[rr + (uintptr_t) z0n - 1] == 0) z0n--;
   int z2n = 2 * h;
   while (z2n > 0 && ws[rr + 2 * (uintptr_t) m + (uintptr_t) z2n - 1] == 0) z2n--;
   int nz1 = 2 * (h + 1);
   while (nz1 > 0 && ws[z1O + (uintptr_t) nz1 - 1] == 0) nz1--;
   nz1 = mag_sub(ws + z1O, ws + z1O, nz1, ws + rr, z0n);                       // z1 -= z0
   while (nz1 > 0 && ws[z1O + (uintptr_t) nz1 - 1] == 0) nz1--;
   nz1 = mag_sub(ws + z1O, ws + z1O, nz1, ws + rr + 2 * (uintptr_t) m, z2n);   // z1 -= z2
   while (nz1 > 0 && ws[z1O + (uintptr_t) nz1 - 1] == 0) nz1--;
   mag_add_off(ws + rr, 2 * jn, ws + z1O, nz1, m);                             // r += z1 * B^m
   budget -= jn; top--; } }
 ws[1] = (love_limb) top;                                   // before any yield
 if (top > 0) { YieldCheck(); love_musttail return Continue(); }
 bool neg = ws[2];
 uintptr_t r_off = ws[3], rn = ws[4];   // done: the product at ws[r_off..r_off+rn)
 Have(Width(struct big) + b2w(((size_t) rn + 1) * sizeof(love_limb)));
 ws = (love_limb*) txt(cask(Sp[0])->str);                    // re-fetch past the Have
 r_off = ws[3], rn = ws[4];
 word ret = Sp[1], res;
 Pack(g);
 res = big_canon(&g->hp, ws + r_off, (int) rn, neg);
 Unpack(g);
 Sp += 1; Sp[0] = res; Ip = cell(ret); love_musttail return Continue(); }

lvm(lvm_bmul_start) {
 // one chunk's product never yields: one-shot. na <= chunk/nb keeps na*nb off int overflow
 word a = Sp[0], b = Sp[1];
 int na = bigp(a) ? big_nlimbs(a) : 2, nb = bigp(b) ? big_nlimbs(b) : 2;
 if (na <= bmul_chunk / nb) LvmResume(g, big_binop, vop_mul)
 if (bigp(a) && bigp(b) && (2 * min(na, nb) >= max(na, nb) || min(na, nb) >= kara_cutoff)) {
  LvmResume(g, kmul_setup) }  // karatsuba, a lopsided pair in pieces of the shorter's width
 LvmResume(g, bmul_setup) }   // short, under the cutoff: chunked schoolbook

static lvm(lvm_bmul) {
 int i = (int) getcharm(Sp[0]);
 struct big *A = big(Sp[3]), *B = big(Sp[4]);
 intptr_t sla = A->slen, slb = B->slen;
 int na = sla < 0 ? -sla : sla, nb = slb < 0 ? -slb : slb;
 if (!na || !nb) {
  word ret = Sp[2]; Sp += 4; Sp[0] = zero; Ip = cell(ret); love_musttail return Continue(); }
 love_limb *la = A->limb, *lb = B->limb, *rl = (love_limb*) txt(cask(Sp[1])->str);
 int end = min(i + max(1, bmul_chunk / nb), na);
 mag_mul_rows(rl, la, i, end, lb, nb);
 i = end;
 Sp[0] = putcharm(i);                               // before any yield or GC
 if (i < na) {
   YieldCheck();
   love_musttail return Continue(); }
 bool neg = (sla < 0) != (slb < 0); word ret;
 Have(Width(struct big) + b2w((size_t) (na + nb) * sizeof(love_limb)));
 ret = Sp[2];
 love_limb *rmag = (love_limb*) txt(cask(Sp[1])->str);  // re-fetch past the Have
 Pack(g);                                          // g->hp, never &Hp: an escaping local blocks the sibcall
 word res = big_canon(&g->hp, rmag, na + nb, neg);
 Unpack(g);
 Sp += 4;
 Sp[0] = res;
 Ip = cell(ret);
 love_musttail return Continue(); }

// a yieldable long division: normalized once into a cask [hdr | vn | un | q], the D loop in
// chunks, j on the stack; the base re-read from Sp[1] at every entry. which: 0 //, 1 %
#define bdiv_chunk (1 << 14)
#define BdivHdr 6           // m, n, shift, which, nega, negb
static union u const bdiv_loop[1] = { { .ap = lvm_bdiv } };

static struct g *bdiv_setup(struct g *g, int which) {
 word a = g->sp[0], b = g->sp[1];
 int mub = bigp(a) ? big_nlimbs(a) : wlimbs, nub = bigp(b) ? big_nlimbs(b) : wlimbs;
 uintptr_t wslimbs = BdivHdr + (uintptr_t) nub + (mub + 1) + (mub - nub + 1),
           sreq = str_width(wslimbs * sizeof(love_limb)),
           breq = Width(struct cask) + Width(struct tag);
 if (!ok(g = have(g, sreq + breq + 3))) return g;
 a = g->sp[0], b = g->sp[1];                          // re-fetch (have may have GC'd)
 love_limb sa[wlimbs], sb[wlimbs]; love_limb const *la, *lb; bool nega, negb;
 int m = load_int_mag(a, sa, &la, &nega), n = load_int_mag(b, sb, &lb, &negb);
 struct str *ws_s = ini_str(str(g->hp), wslimbs * sizeof(love_limb));
 g->hp += sreq;
 love_limb *ws = (love_limb*) txt(ws_s),
         *vn = ws + BdivHdr, *un = vn + n, *q = un + (m + 1);
 int s = mag_dnorm(un, vn, la, m, lb, n);
 for (int i = 0; i < m - n + 1; i++) q[i] = 0;
 ws[0] = (love_limb) m, ws[1] = (love_limb) n, ws[2] = (love_limb) s, ws[3] = (love_limb) which;
 ws[4] = (love_limb) nega, ws[5] = (love_limb) negb;
 union u *k = (union u*) g->hp; g->hp += breq;
 cask(k)->ap = lvm_cask;
 cask(k)->str = ws_s;
 tagthread(k, Width(struct cask));
 union u *ret = g->ip + 1;
 g->sp -= 1;                                          // [j, ws, ret_ip] over [a, b]
 g->sp[0] = putcharm(m - n), g->sp[1] = word(k), g->sp[2] = word(ret);
 g->ip = (union u*) bdiv_loop;
 return g; }

lvm(lvm_bdiv_start) {
 int vop = (int) g->b;
 word a = Sp[0], b = Sp[1];
 int m = bigp(a) ? big_nlimbs(a) : wlimbs, n = bigp(b) ? big_nlimbs(b) : wlimbs;
 // one-shot: |a| < |b|, a single-limb divisor, or a short quotient
 if (m < n || n < 2 || m - n < (int) (bdiv_chunk / (uintptr_t) n)) LvmResume(g, big_binop, vop)
 LvmResume(g, bdiv_setup, vop == vop_rem) }

static lvm(lvm_bdiv) {
 love_limb *ws = (love_limb*) txt(cask(Sp[1])->str);
 int m = (int) ws[0], n = (int) ws[1], s = (int) ws[2], which = (int) ws[3];
 bool nega = ws[4], negb = ws[5];
 love_limb *vn = ws + BdivHdr, *un = vn + n, *q = un + (m + 1);
 int j = (int) getcharm(Sp[0]),
     steps = max(1, (int) (bdiv_chunk / (uintptr_t) n));
 for (int c = 0; c < steps && j >= 0; c++, j--) q[j] = mag_divstep(un, vn, n, j);
 if (j >= 0) { Sp[0] = putcharm(j); YieldCheck(); love_musttail return Continue(); }
 // done. the remainder denormalizes into the dead vn, not in place, so a GC retry of this tail
 // is idempotent; j = -1 first, so the retry skips the loop
 Sp[0] = putcharm(-1);
 int outn = which ? n : (m - n + 1);
 Have(Width(struct big) + b2w((size_t) (outn + 1) * sizeof(love_limb)));
 ws = (love_limb*) txt(cask(Sp[1])->str);                 // re-fetch past the Have
 vn = ws + BdivHdr, un = vn + n, q = un + (m + 1);
 bool rneg = which ? nega : (nega != negb);
 word ret = Sp[2], res;
 Pack(g);
 if (which) mag_ddenorm(vn, un, n, s), res = big_canon(&g->hp, vn, n, rneg);
 else res = big_canon(&g->hp, q, m - n + 1, rneg);
 Unpack(g);
 Sp += 2;
 Sp[0] = res;
 Ip = cell(ret);
 love_musttail return Continue(); }

// a digit in any radix, hex either case
static love_inline love_limb rdigit(char c) {
 return (love_limb) (c <= '9' ? c - '0' : (c | 32) - 'a' + 10); }

// slots of w limbs in x (np, a power of two) joined in pairs, hi r^(chunk w) + lo, until one
// holds the value, each level's power the square of the last. pw, pn, t, kt are scratch
static void mag_join_dec(love_limb *x, int np, love_limb *pw, love_limb *pn, love_limb *t, love_limb *kt,
                         love_limb p0) {
 pw[0] = p0;
 for (int w = 1; w < np; w *= 2) {
  for (int j = 0; j < np; j += 2 * w) {
   love_limb *lo = x + j, *hi = lo + w;
   int nh = w;
   while (nh > 0 && !hi[nh - 1]) nh--;
   if (!nh) continue;                                 // a zero top half: lo is the pair
   mag_mul_kara(t, hi, pw, w, kt);
   mag_add_off(t, 2 * w, lo, w, 0);
   memcpy(lo, t, (size_t) 2 * w * sizeof(love_limb)); }
  if (2 * w < np) { mag_mul_kara(pn, pw, pw, w, kt); love_limb *z = pw; pw = pn, pn = z; } } }

// sp0 a [+-]?<pfx><digits> token -> its value: a power of two radix packs its digits' bits;
// ten lays chunk digits a limb and joins them by halves, or for a short token mul-adds a limb
static struct g *big_read_radix(struct g *g, love_limb radix, int chunk, uintptr_t pfx) {
 struct str *tok = str(g->sp[0]);
 uintptr_t n = tok->len;
 char const *s = tok->bytes;
 bool neg = n && s[0] == '-';
 uintptr_t i = ((n && (s[0] == '-' || s[0] == '+')) ? 1 : 0) + pfx, ndig = n - i;
 int cap = (int) (ndig / (uintptr_t) chunk) + 3;
 bool halves = radix == 10 && cap > 2 * kara_cutoff;
 int np = 1;
 while (halves && np < cap) np *= 2;
 // halves: the slots, a product, two powers and karatsuba's scratch
 uintptr_t work = halves ? (uintptr_t) 9 * np + 1024 : (uintptr_t) cap,
           res_area = Width(struct big) + b2w((size_t) (halves ? np : cap) * sizeof(love_limb));
 if (!ok(g = have(g, res_area + b2w((size_t) work * sizeof(love_limb))))) return g;
 tok = str(g->sp[0]), s = tok->bytes;            // re-fetch post-GC
 love_limb *mag = (love_limb*) (g->hp + res_area);
 int m = 0;
 if (radix == 16 || radix == 8) {                 // from the last digit up, lg bits each
  int lg = radix == 16 ? 4 : 3, nb = 0; love_limb acc = 0;
  for (uintptr_t k = n; k > i; k--) {
   love_limb d = rdigit(s[k - 1]);
   acc |= d << nb, nb += lg;
   if (nb >= limb_bits) mag[m++] = acc, nb -= limb_bits, acc = nb ? d >> (lg - nb) : 0; }
  if (nb) mag[m++] = acc; }
 else if (halves) {                               // slot j: the chunk ending j chunks from the last digit
  love_limb p0 = 1;
  for (int k = 0; k < chunk; k++) p0 *= radix;
  memset(mag, 0, (size_t) np * sizeof(love_limb));
  for (uintptr_t e = n, j = 0; e > i; j++) {
   uintptr_t b = e - i > (uintptr_t) chunk ? e - (uintptr_t) chunk : i;
   love_limb acc = 0;
   for (uintptr_t k = b; k < e; k++) acc = acc * radix + rdigit(s[k]);
   mag[j] = acc, e = b; }
  love_limb *pw = mag + np, *pn = pw + np, *t = pn + np, *kt = t + 2 * np;
  mag_join_dec(mag, np, pw, pn, t, kt, p0);
  m = np; }
 else while (i < n) {
  love_limb acc = 0, pw = 1; int k = 0;
  for (; i < n && k < chunk; i++, k++) acc = acc * radix + rdigit(s[i]), pw *= radix;
  m = mag_mul_add_small(mag, m, pw, acc); }
 g->sp[0] = big_canon(&g->hp, mag, m, neg);
 return g; }
struct g *big_read_dec(struct g *g) { return big_read_radix(g, 10, limb_dec_chunk, 0); }
struct g *big_read_hex(struct g *g) { return big_read_radix(g, 16, limb_hex_chunk, 2); }
struct g *big_read_oct(struct g *g) { return big_read_radix(g,  8, limb_oct_chunk, 1); }

// (tray witness shape vals), mopped behind prel's *-tray: the witness names the tier by example,
// 0 Z, 0.0 R, ~(0 0) C, else O; vals fill row-major. a negative dim or over-rank -> zero
lvm(lvm_trayctor) {
 word t = Sp[0], shp = Sp[1];                  // vals = Sp[2]
 intptr_t ty = twinp(t) ? love_C : gemp(t) ? love_R
             : intp(t) ? love_Z : love_O;
 uintptr_t rank = 0, nelem = 1;
 for (word l = shp; chainp(l); l = B(l)) {
  word d = A(l);
  if (!charmp(d) || getcharm(d) < 0) love_musttail return Answerp(2, zero);
  rank++, nelem = mulsat(nelem, (uintptr_t) getcharm(d)); }   // saturated, for tray_bytes to refuse
 if (rank > maxrank) love_musttail return Answerp(2, zero);
 uintptr_t bytes = tray_bytes(ty, rank, nelem);
 Have(b2w(bytes));
 struct tray *v = (struct tray*) Hp;
 Hp += b2w(bytes);
 ini_tray(v, ty, rank);
 uintptr_t i = 0;                              // the lists may have moved
 for (word l = Sp[1]; chainp(l); l = B(l)) v->shape[i++] = (uintptr_t) getcharm(A(l));
 if (ty == love_O) for (i = 0; i < nelem; i++) tray_put_obj(v, i, ZeroPoint);  // O's floor is ()
 else memset(tray_data(v), 0, nelem * love_T[ty]);
 i = 0;                                        // no alloc below
 for (word l = Sp[2]; chainp(l) && i < nelem; l = B(l), i++) tray_put(v, i, A(l));
 // only rank 0 demotes to its scalar: @(5) stays a one-cell array. rooted, as the box can GC
 Sp[2] = word(v);
 if (rank == 0) {
  if (ty == love_O) love_musttail return Answerp(2, tray_get_obj(v, 0));
  if (ty == love_C) { Have(twin_req); v = tray(Sp[2]); flo_t *fp = tray_data(v);
   Sp[2] = mk_twin(&Hp, fp[0], fp[1]); love_musttail return Nextp(1, 2); }
  word _res; Have(box_req); v = tray(Sp[2]);
  if (ty >= love_R) emit_gem(_res, tray_get_flo(v, 0));
  else emit_int(_res, tray_get_int(v, 0));
  love_musttail return Answerp(2, _res); }
 love_musttail return Answerp(2, word(v)); }

// (iota mask): the flat indices of a real tray's nonzeros as a z-array, apl's iota underbar
static lvm(lvm_where) {
 struct tray *m = tray(Sp[0]);
 uintptr_t n = tray_nelem(m), k = 0;
 for (uintptr_t i = 0; i < n; i++) k += m->type == love_R ? tray_get_flo(m, i) != 0 : tray_get_int(m, i) != 0;
 uintptr_t bytes = tray_bytes(love_Z, 1, k);
 Have(b2w(bytes));
 m = tray(Sp[0]);                                   // re-read post-Have
 struct tray *v = (struct tray*) Hp;
 Hp += b2w(bytes);
 ini_tray(v, love_Z, 1);
 v->shape[0] = k;
 intptr_t *p = tray_data(v);
 for (uintptr_t i = 0, j = 0; i < n; i++)
  if (m->type == love_R ? tray_get_flo(m, i) != 0 : tray_get_int(m, i) != 0) p[j++] = (intptr_t) i;
 love_musttail return Answer(word(v)); }

// (iota n): 0..n-1, the array twin of `jot`
lvm(lvm_iota) {
 word nx = Sp[0];
 if (packp(nx) && tray(nx)->rank && tray(nx)->type <= love_R) love_musttail return Ap(lvm_where, g);
 if (!charmp(nx) || getcharm(nx) < 0) love_musttail return Answer(ZeroPoint);
 uintptr_t n = (uintptr_t) getcharm(nx),
           bytes = tray_bytes(love_Z, 1, n);
 Have(b2w(bytes));
 struct tray *v = (struct tray*) Hp;
 Hp += b2w(bytes);
 ini_tray(v, love_Z, 1);
 v->shape[0] = n;
 intptr_t *p = tray_data(v);                        // love_Z: raw words
 for (uintptr_t i = 0; i < n; i++) p[i] = (intptr_t) i;
 love_musttail return Answer(word(v)); }

// rank and element type; () for a non-tray, 0 for a scalar box
op11(lvm_rank, packp(Sp[0]) ? putcharm(tray(Sp[0])->rank) : ZeroPoint)
op11(lvm_atype, packp(Sp[0]) ? putcharm(tray(Sp[0])->type) : ZeroPoint)

// the element count, 1 for a scalar box
lvm(lvm_alen) {
 word x = Sp[0];
 if (!packp(x)) love_musttail return Answer(ZeroPoint);
 love_musttail return Answer(putcharm(tray_nelem(tray(x)))); }

// n with 2^(n-1) <= |x| < 2^n, 0 for 0
lvm(lvm_bitlen) {
 word x = Sp[0];
 if (charmp(x)) {
  intptr_t v = getcharm(x);
  uintptr_t m = v < 0 ? (uintptr_t) 0 - (uintptr_t) v : (uintptr_t) v;
  love_musttail return Answer(putcharm(m ? 64 - __builtin_clzll((unsigned long long) m) : 0)); }
 if (!bigp(x)) love_musttail return Answer(ZeroPoint);
 int n = big_nlimbs(x);                                  // canonical: the top limb nonzero
 love_musttail return Answer(putcharm((intptr_t) (n - 1) * limb_bits + limb_bits - limb_clz(big(x)->limb[n-1]))); }

// the dimensions as a list
lvm(lvm_shape) {
 word x = Sp[0];
 if (!packp(x)) love_musttail return Answer(ZeroPoint);
 uintptr_t r = tray(x)->rank;
 Have(r * Width(struct chain));
 struct tray *v = tray(Sp[0]);                 // re-read post-Have
 struct chain *p = (struct chain*) Hp;
 Hp += r * Width(struct chain);
 word list = ZeroPoint;
 for (uintptr_t i = r; i--; )
  ini_chain(p, putcharm(v->shape[i]), list), list = word(p), p++;
 love_musttail return Answer(list); }


// love_O reductions fold through the promoting scalar op, so they are exact
struct g *ored(struct g *g, int kind);   // kind: 0 sum, 1 prod, 2 max, 3 min

// reductions: identity on a scalar, so (aall (< a b)) is rank-agnostic
lvm(lvm_asum) {
 word x = Sp[0];
 if (!packp(x)) love_musttail return Next(1);
 if (tray(x)->type == love_O) LvmResume(g, ored, 0)
 if (tray(x)->type == love_C) {
  struct tray *v = tray(x); uintptr_t n = tray_nelem(v);  // K=4 accumulators, as aprod
  flo_t *fp = tray_data(v);                   // all read before the Have
  flo_t a0=0,b0=0, a1=0,b1=0, a2=0,b2=0, a3=0,b3=0; uintptr_t j = 0;
  for (; j + 4 <= n; j += 4)
   a0 += fp[2*j],   b0 += fp[2*j+1], a1 += fp[2*j+2], b1 += fp[2*j+3],
   a2 += fp[2*j+4], b2 += fp[2*j+5], a3 += fp[2*j+6], b3 += fp[2*j+7];
  for (; j < n; j++) a0 += fp[2*j], b0 += fp[2*j+1];
  flo_t sr = (a0+a1)+(a2+a3), si = (b0+b1)+(b2+b3);
  Have(twin_req);
  Sp[0] = mk_twin(&Hp, sr, si); love_musttail return Next(1); }
 struct tray *v = tray(x);
 uintptr_t n = tray_nelem(v);
 bool fdom = v->type >= love_R; word _res;
 Have(box_req);
 v = tray(Sp[0]);
 if (fdom) {
  flo_t *d = tray_data(v), a0=0,a1=0,a2=0,a3=0; uintptr_t i = 0;
  for (; i + 4 <= n; i += 4) a0 += d[i], a1 += d[i+1], a2 += d[i+2], a3 += d[i+3];
  for (; i < n; i++) a0 += d[i];
  emit_gem(_res, (a0+a1)+(a2+a3)); }
 else {                                         // mod 2^64, so the regrouping is exact
  uintptr_t *p = tray_data(v), a0=0,a1=0,a2=0,a3=0, i = 0;
  for (; i + 4 <= n; i += 4) a0 += p[i], a1 += p[i+1], a2 += p[i+2], a3 += p[i+3];
  for (; i < n; i++) a0 += p[i];
  emit_int(_res, (intptr_t) ((a0+a1)+(a2+a3))); }
 love_musttail return Answer(_res); }

lvm(lvm_aprod) {
 word x = Sp[0];
 if (!packp(x)) love_musttail return Next(1);
 if (tray(x)->type == love_O) LvmResume(g, ored, 1)
 if (tray(x)->type == love_C) {
  // K=4 accumulators break the latency chain; the regrouping moves only last-bit rounding
  struct tray *v = tray(x);
  uintptr_t n = tray_nelem(v);
  flo_t *fp = tray_data(v),
           r0=1,i0=0, r1=1,i1=0, r2=1,i2=0, r3=1,i3=0, t; uintptr_t j = 0;
  for (; j + 4 <= n; j += 4)
   t = r0*fp[2*j]  -i0*fp[2*j+1], i0 = r0*fp[2*j+1]+i0*fp[2*j],   r0 = t,
   t = r1*fp[2*j+2]-i1*fp[2*j+3], i1 = r1*fp[2*j+3]+i1*fp[2*j+2], r1 = t,
   t = r2*fp[2*j+4]-i2*fp[2*j+5], i2 = r2*fp[2*j+5]+i2*fp[2*j+4], r2 = t,
   t = r3*fp[2*j+6]-i3*fp[2*j+7], i3 = r3*fp[2*j+7]+i3*fp[2*j+6], r3 = t;
  for (; j < n; j++) t = r0*fp[2*j]-i0*fp[2*j+1], i0 = r0*fp[2*j+1]+i0*fp[2*j], r0 = t;
  flo_t ra = r0*r1-i0*i1, ia = r0*i1+i0*r1, rb = r2*r3-i2*i3, ib = r2*i3+i2*r3,
           pr = ra*rb-ia*ib, pi = ra*ib+ia*rb;
  Have(twin_req);
  Sp[0] = mk_twin(&Hp, pr, pi);
  love_musttail return Next(1); }
 struct tray *v = tray(x);
 uintptr_t n = tray_nelem(v);
 bool fdom = v->type >= love_R; word _res;
 Have(box_req); v = tray(Sp[0]);
 if (fdom) {
  flo_t a0=1,a1=1,a2=1,a3=1; uintptr_t i = 0;
  for (; i + 4 <= n; i += 4) a0*=tray_get_flo(v,i), a1*=tray_get_flo(v,i+1), a2*=tray_get_flo(v,i+2), a3*=tray_get_flo(v,i+3);
  for (; i < n; i++) a0 *= tray_get_flo(v, i);
  emit_gem(_res, (a0*a1)*(a2*a3)); }
 else {                                         // modular
  uintptr_t a0=1,a1=1,a2=1,a3=1, i = 0;
  for (; i + 4 <= n; i += 4) a0*=(uintptr_t)tray_get_int(v,i), a1*=(uintptr_t)tray_get_int(v,i+1), a2*=(uintptr_t)tray_get_int(v,i+2), a3*=(uintptr_t)tray_get_int(v,i+3);
  for (; i < n; i++) a0 *= (uintptr_t) tray_get_int(v, i);
  emit_int(_res, (intptr_t) ((a0*a1)*(a2*a3))); }
 love_musttail return Answer(_res); }

// kind 2 max, 3 min, as ored; empty -> ()
static lvm(lvm_aextreme) {
 int kind = (int) g->b;
 word x = Sp[0];
 if (!packp(x)) love_musttail return Next(1);
 if (tray(x)->type == love_O) LvmResume(g, ored, kind)
 if (tray(x)->type == love_C) love_musttail return Answer(ZeroPoint);   // complex: unordered
 struct tray *v = tray(x);
 uintptr_t n = tray_nelem(v);
 if (!n) love_musttail return Answer(ZeroPoint);
 bool fdom = v->type >= love_R, ismax = kind == 2; word _res;
 Have(box_req); v = tray(Sp[0]);
 // K=4 running extremes, exact; the kind and direction asked once, a loop each
 #define AEXT(T, P, B, M) do { T m0 = P[0], m1 = m0, m2 = m0, m3 = m0, e; uintptr_t i = 1; \
  for (; i + 4 <= n; i += 4) { \
   e = P[i];   if (e B m0) m0 = e;  e = P[i+1]; if (e B m1) m1 = e; \
   e = P[i+2]; if (e B m2) m2 = e;  e = P[i+3]; if (e B m3) m3 = e; } \
  for (; i < n; i++) { e = P[i]; if (e B m0) m0 = e; } \
  if (m1 B m0) m0 = m1; \
  if (m2 B m0) m0 = m2; \
  if (m3 B m0) m0 = m3; \
  M = m0; } while (0)
 if (fdom) { flo_t *p = tray_data(v), m;
  if (ismax) AEXT(flo_t, p, >, m); else AEXT(flo_t, p, <, m);
  emit_gem(_res, m); }
 else { intptr_t *p = tray_data(v), m;
  if (ismax) AEXT(intptr_t, p, >, m); else AEXT(intptr_t, p, <, m);
  emit_int(_res, m); }
 #undef AEXT
 love_musttail return Answer(_res); }
lvm(lvm_max) { g->b = (word) 2; love_musttail return Ap(lvm_aextreme, g); }   // amax
lvm(lvm_min) { g->b = (word) 3; love_musttail return Ap(lvm_aextreme, g); }   // amin

// aall's (g->b = 2i) and aany's (2i + 1) object lane from element i: a compound element is
// measured as [e measure land op 2i+any] over the tray, and the landing scans on
static lvm(lvm_ascan);
static lvm(lvm_ascan_land) {
 intptr_t k = getcharm(Sp[2]); bool any = k & 1;
 Ip = cell(Sp[1]);
 bool t = !leaf_nilp(Sp[0]);
 Sp += 3;                                                        // [ans op k tray] -> [tray]
 if (t == any) love_musttail return Answer(putcharm(any));
 g->b = (word) (k + 2); love_musttail return Ap(lvm_ascan, g); }
static union u const ascan_land[] = { {.ap = lvm_ascan_land} };
static lvm(lvm_ascan) {
 intptr_t k = g->b; bool any = k & 1;
 for (uintptr_t i = (uintptr_t) (k >> 1); i < tray_nelem(tray(Sp[0])); i++) {
  word e = tray_get_obj(tray(Sp[0]), i);
  if (!leafp(e)) {
   Have(5);                                                      // a collection re-runs the op from 0
   word *dst = Sp - 5;
   dst[0] = e, dst[1] = hot_hook(g->hook[hook_net]), dst[2] = word(ascan_land), dst[3] = word(Ip),
   dst[4] = putcharm((intptr_t) (i << 1) | any);
   Sp = dst; Ip = (union u*) callout_drive; love_musttail return Continue(); }
  if (!leaf_nilp(e) == any) love_musttail return Answer(putcharm(any)); }
 love_musttail return Answer(putcharm(!any)); }

// every element true by `?`'s law, a positive real part; empty is true
lvm(lvm_aall) {
 word x = Sp[0];
 if (!packp(x)) love_musttail return Next(1);
 struct tray *v = tray(x);
 uintptr_t n = tray_nelem(v);
 if (v->type == love_O) { g->b = 0; love_musttail return Ap(lvm_ascan, g); }
 if (v->type == love_C) {
  flo_t *fp = tray_data(v);
  for (uintptr_t i = 0; i < n; i++)
   if (!(fp[2*i] > 0)) love_musttail return Answer(zero);
  love_musttail return Answer(putcharm(1)); }
 bool fdom = v->type >= love_R;
 for (uintptr_t i = 0; i < n; i++)
  if (fdom ? !(tray_get_flo(v, i) > 0) : tray_get_int(v, i) <= 0)
   love_musttail return Answer(zero);
 love_musttail return Answer(putcharm(1)); }

// some element true; empty is false
lvm(lvm_aany) {
 word x = Sp[0];
 if (!packp(x)) love_musttail return Next(1);
 struct tray *v = tray(x);
 uintptr_t n = tray_nelem(v);
 if (v->type == love_O) { g->b = 1; love_musttail return Ap(lvm_ascan, g); }
 if (v->type == love_C) {
  flo_t *fp = tray_data(v);
  for (uintptr_t i = 0; i < n; i++)
   if (fp[2*i] > 0) love_musttail return Answer(putcharm(1));
  love_musttail return Answer(zero); }
 bool fdom = v->type >= love_R;
 for (uintptr_t i = 0; i < n; i++)
  if (fdom ? tray_get_flo(v, i) > 0 : tray_get_int(v, i) > 0)
   love_musttail return Answer(putcharm(1));
 love_musttail return Answer(zero); }

// (floor x): a charm saturating at the charm bounds; a float tray floors to an int tray
lvm(lvm_floor) {
 word a = Sp[0];
 if (trayp(a)) {
  if (tray(a)->type < love_R) love_musttail return Next(1);
  if (tray(a)->type != love_R) love_musttail return Answer(ZeroPoint);
  g->b = (word) (uintptr_t) (love_floor); love_musttail return Ap(lvm_vmap1z, g); }
 if (isnum(a) && !charmp(a) && !bigp(a)) {
  flo_t v = love_floor(toflo(a));
  Sp[0] = putcharm(v >= (flo_t) maxcharm ? maxcharm
                 : v <= (flo_t) mincharm ? mincharm
                 : v != v ? 0 : (intptr_t) v); }
 love_musttail return Next(1); }

// (outer a b): r[I,J] = a[I] * b[J]; complex, object or over-rank -> ()
lvm(lvm_outer) {
 word a = Sp[0], b = Sp[1];
 if (!(trayp(a) && trayp(b))) love_musttail return Push(ZeroPoint);
 struct tray *va = tray(a), *vb = tray(b);
 if (va->type > love_R || vb->type > love_R) love_musttail return Push(ZeroPoint);
 uintptr_t M = tray_nelem(va), N = tray_nelem(vb), n = mulsat(M, N), rank = va->rank + vb->rank;
 if (rank > maxrank) love_musttail return Push(ZeroPoint);
 bool fdom = va->type == love_R || vb->type == love_R;
 enum tray_type rt = fdom ? love_R : love_Z;
 uintptr_t bytes = tray_bytes(rt, rank, n);
 Have(b2w(bytes));
 va = tray(Sp[0]), vb = tray(Sp[1]);
 struct tray *r = (struct tray*) Hp; Hp += b2w(bytes);
 ini_tray(r, rt, rank);
 memcpy(r->shape, va->shape, va->rank * sizeof *r->shape);
 memcpy(r->shape + va->rank, vb->shape, vb->rank * sizeof *r->shape);
 if (fdom) { flo_t *rp = tray_data(r);
  for (uintptr_t i = 0; i < M; i++) { flo_t av = tray_get_flo(va, i);
   for (uintptr_t j = 0; j < N; j++) rp[i*N+j] = av * tray_get_flo(vb, j); } }
 else { intptr_t *rp = tray_data(r);
  for (uintptr_t i = 0; i < M; i++) { intptr_t av = tray_get_int(va, i);
   for (uintptr_t j = 0; j < N; j++) rp[i*N+j] = (intptr_t)((uintptr_t)av * (uintptr_t)tray_get_int(vb, j)); } }
 love_musttail return Push(word(r)); }   // arity 2

// (inner a b): +.×, a's last axis against b's first; ikj, so the inner j loop vectorizes
lvm(lvm_inner) {
 word a = Sp[0], b = Sp[1];
 if (!(trayp(a) && trayp(b))) love_musttail return Push(ZeroPoint);
 struct tray *va = tray(a), *vb = tray(b);
 if (va->type > love_R || vb->type > love_R || va->rank < 1 || vb->rank < 1)
  love_musttail return Push(ZeroPoint);
 uintptr_t K = va->shape[va->rank - 1];
 if (K != vb->shape[0]) love_musttail return Push(ZeroPoint);
 uintptr_t M = 1, N = 1;
 for (uintptr_t i = 0; i + 1 < va->rank; i++) M = mulsat(M, va->shape[i]);
 for (uintptr_t i = 1; i < vb->rank; i++) N = mulsat(N, vb->shape[i]);
 uintptr_t rank = (va->rank - 1) + (vb->rank - 1), n = mulsat(M, N);
 if (rank > maxrank || n > words_max) love_musttail return Push(ZeroPoint);
 bool fdom = va->type == love_R || vb->type == love_R, ar = va->type == love_R, br = vb->type == love_R;
 if (n == 1) {                                  // a 1-cell contraction is a scalar
  word _res;
  if (fdom) {
   flo_t *Ad = tray_data(va), *Bd = tray_data(vb);
   intptr_t *Ai = tray_data(va), *Bi = tray_data(vb); flo_t acc = 0;
   for (uintptr_t l = 0; l < K; l++) acc += (ar ? Ad[l] : (flo_t) Ai[l]) * (br ? Bd[l] : (flo_t) Bi[l]);
   Have(box_req); emit_gem(_res, acc); }
  else {
   intptr_t *A = tray_data(va), *B = tray_data(vb);
   uintptr_t acc = 0;
   for (uintptr_t l = 0; l < K; l++) acc += (uintptr_t) A[l] * (uintptr_t) B[l];
   Have(box_req);
   emit_int(_res, (intptr_t) acc); }
  love_musttail return Push(_res); }
 enum tray_type rt = fdom ? love_R : love_Z;
 uintptr_t bytes = tray_bytes(rt, rank, n);
 Have(b2w(bytes));
 va = tray(Sp[0]), vb = tray(Sp[1]);
 struct tray *r = (struct tray*) Hp; Hp += b2w(bytes);
 ini_tray(r, rt, rank);
 { uintptr_t s = 0;
   for (uintptr_t i = 0; i + 1 < va->rank; i++) r->shape[s++] = va->shape[i];
   for (uintptr_t i = 1; i < vb->rank; i++) r->shape[s++] = vb->shape[i]; }
 if (fdom) { flo_t *C = tray_data(r);
  flo_t *Ad = tray_data(va), *Bd = tray_data(vb);
  intptr_t *Ai = tray_data(va), *Bi = tray_data(vb);
  memset(C, 0, n * love_T[rt]);
  for (uintptr_t i = 0; i < M; i++)
   for (uintptr_t l = 0; l < K; l++) { flo_t av = ar ? Ad[i*K+l] : (flo_t) Ai[i*K+l];
    for (uintptr_t j = 0; j < N; j++) C[i*N+j] += av * (br ? Bd[l*N+j] : (flo_t) Bi[l*N+j]); } }
 else { intptr_t *C = tray_data(r), *A = tray_data(va), *B = tray_data(vb);
  memset(C, 0, n * love_T[rt]);
  for (uintptr_t i = 0; i < M; i++)
   for (uintptr_t l = 0; l < K; l++) { intptr_t av = A[i*K+l];
    for (uintptr_t j = 0; j < N; j++) C[i*N+j] = (intptr_t)((uintptr_t)C[i*N+j] + (uintptr_t)av * (uintptr_t)B[l*N+j]); } }
 love_musttail return Push(word(r)); }   // arity 2

// monadic math -> a float tray; the fill takes no &local, so the wrapper keeps its tail call
static love_noinline void vmap1_fill(struct tray *r, struct tray *a, flo_t (*fn)(flo_t)) {
 uintptr_t n = tray_nelem(r);
 flo_t *d = tray_data(r);
 if (a->type == love_R) { flo_t *s = tray_data(a); for (uintptr_t i = 0; i < n; i++) d[i] = fn(s[i]); }
 else for (uintptr_t i = 0; i < n; i++) d[i] = fn(tray_get_flo(a, i)); }

lvm(lvm_vmap1) {
 flo1 fn = (flo1) (uintptr_t) g->b;
 struct tray *a = tray(Sp[0]);
 uintptr_t rank = a->rank, n = tray_nelem(a),
           bytes = tray_bytes(love_R, rank, n);
 Have(b2w(bytes));
 a = tray(Sp[0]);                               // re-read post-Have
 struct tray *r = (struct tray*) Hp;
 Hp += b2w(bytes);
 ini_tray(r, love_R, rank);
 for (uintptr_t i = 0; i < rank; i++) r->shape[i] = a->shape[i];
 vmap1_fill(r, a, fn);
 love_musttail return Answer(word(r)); }

// into an int tray, saturating, a NaN to 0, as floor and int's scalars leave the float kind
static love_inline intptr_t flo_word(flo_t v) {
 return v >= (flo_t) INTPTR_MAX ? INTPTR_MAX : v <= (flo_t) INTPTR_MIN ? INTPTR_MIN
      : v != v ? 0 : (intptr_t) v; }
static love_noinline void vmap1z_fill(struct tray *r, struct tray *a, flo_t (*fn)(flo_t)) {
 uintptr_t n = tray_nelem(r);
 intptr_t *p = tray_data(r);
 if (a->type == love_R) { flo_t *s = tray_data(a); for (uintptr_t i = 0; i < n; i++) p[i] = flo_word(fn(s[i])); }
 else for (uintptr_t i = 0; i < n; i++) p[i] = flo_word(fn(tray_get_flo(a, i))); }

lvm(lvm_vmap1z) {
 flo1 fn = (flo1) (uintptr_t) g->b;
 struct tray *a = tray(Sp[0]);
 uintptr_t rank = a->rank, n = tray_nelem(a),
           bytes = tray_bytes(love_Z, rank, n);
 Have(b2w(bytes));
 a = tray(Sp[0]);                               // re-read post-Have
 struct tray *r = (struct tray*) Hp;
 Hp += b2w(bytes);
 ini_tray(r, love_Z, rank);
 for (uintptr_t i = 0; i < rank; i++) r->shape[i] = a->shape[i];
 vmap1z_fill(r, a, fn);
 love_musttail return Answer(word(r)); }

// dyadic, broadcasting. integer /0 and INT_MIN/-1 answer 0: one element can't change the domain
flo_t vop_flo(int op, flo_t a, flo_t b) {
 switch (op) {
  case vop_sub: return a - b; case vop_mul: return a * b;
  case vop_quot: return a / b; case vop_fquot: return love_trunc(a / b);
  case vop_rem: return b == 0 ? a : love_fmod(a, b);
  case vop_max: return a > b ? a : b; case vop_min: return a < b ? a : b;
  default: return a + b; } }                   // vop_add
static intptr_t vop_int(int op, intptr_t a, intptr_t b) {
 switch (op) {
  case vop_sub: return (intptr_t)((uintptr_t) a - (uintptr_t) b);
  case vop_mul: return (intptr_t)((uintptr_t) a * (uintptr_t) b);
  case vop_quot: case vop_fquot: return (b == 0 || (a == INTPTR_MIN && b == -1)) ? 0 : a / b;
  case vop_rem:  return b == 0 ? a : (a == INTPTR_MIN && b == -1) ? 0 : a % b;
  case vop_max:  return a > b ? a : b;
  case vop_min:  return a < b ? a : b;
  case vop_band: return a & b;
  case vop_bor:  return a | b;
  case vop_bxor: return a ^ b;
  case vop_bsl: case vop_bsr: {   // a machine word: past the width it empties, never wraps
   int lf = op == vop_bsl;
   intptr_t k = b < 0 ? (lf = !lf, b == INTPTR_MIN ? INTPTR_MAX : -b) : b;
   return k >= Bits ? (lf ? 0 : a < 0 ? -1 : 0)
                    : lf ? (intptr_t)((uintptr_t) a << k) : a >> k; }
  default: return (intptr_t)((uintptr_t) a + (uintptr_t) b); } } // vop_add
intptr_t vcmp_flo(int op, flo_t a, flo_t b) {
 switch (op) {
  case vop_lt: return a < b; case vop_le: return a <= b;   // the ordered four keep IEEE
  case vop_gt: return a > b; case vop_ge: return a >= b;
  default: return same_flo(a, b); } }        // vop_eq: a NaN equals itself
intptr_t vcmp_int(int op, intptr_t a, intptr_t b) {
 switch (op) {
  case vop_lt: return a < b; case vop_le: return a <= b;
  case vop_gt: return a > b; case vop_ge: return a >= b;
  default: return a == b; } }                   // vop_eq

// the net, complex-valued: a numeric tray sums unclamped, so phases cancel. C nets the leaves
// alone; a chain, object tray or coin is prel's `measure` (hook 8), whose walk rides the VM stack
// bytes summed as charms: a string's net, a cask's, a nom's
static flo_t bytes_net(char const *p, uintptr_t n) {
  flo_t t = 0;
  for (char const *q = p + n; p < q; t += (uint8_t) *p++);
  return t; }
// the real part of a leaf's net, what every observer reads; x leafp
flo_t net_re(word x) {
  if (charmp(x)) return (flo_t) getcharm(x);
  if (caskp(x)) return bytes_net((char const*) cask(x)->str->bytes, cask(x)->str->len);
  if (tabp(x) || !datp(x)) return 1;                                // a table, fn or port: truthy,
  switch (typ(x)) {                                                 // never its contents
    case DString: return bytes_net(txt(x), len(x));
    case DBig: return big_to_flo(x);
    case DGem: return gem_get(x);
    case DTwin: return twin_re(x);
    case DMint: return 0;
    case DNom: return bytes_net(txt(nom(x)->name), len(nom(x)->name));
    case DTray: {
      struct tray *v = tray(x);
      uintptr_t i, n = tray_nelem(v);
      flo_t s = 0;
      if (v->type == love_C) { flo_t *d = tray_data(v); for (i = 0; i < n; i++) s += net_flo(d[2 * i]); }
      else if (v->type == love_R) { flo_t *d = tray_data(v); for (i = 0; i < n; i++) s += net_flo(d[i]); }
      else { intptr_t *d = tray_data(v); for (i = 0; i < n; i++) s += (flo_t) d[i]; }   // love_Z: never a NaN
      return s; }
    default: return 1; } }
flo_t net_im(word x) {
  if (twinp(x)) return twin_im(x);
  if (!trayp(x) || tray(x)->type != love_C) return 0;
  flo_t *d = tray_data(tray(x)), s = 0;
  for (uintptr_t i = 0, n = tray_nelem(tray(x)); i < n; i++) s += net_flo(d[2 * i + 1]);
  return s; }

// a compound to prel's measure, then this same op again on the number; before the seal the
// hook traps, as the boot asks no compound's truth
lvm(lvm_measure) {
  Have(2);
  word *dst = Sp - 2;
  dst[0] = Sp[0], dst[1] = hot_hook(g->hook[hook_net]), dst[2] = word(Ip);
  Sp = dst; Ip = (union u*) callout_drive;
  love_musttail return Continue(); }
// a coin by its kind's slot g->b ('int or 'ceil), then the op again; without the slot, measured
lvm(lvm_coin_rung) {
  word f = kind_get(g, coin_kind(Sp[0]), (intptr_t) g->b);
  if (f == ZeroPoint) love_musttail return Ap(lvm_measure, g);
  Have(2);
  word *dst = Sp - 2;
  dst[0] = Sp[0], dst[1] = kind_get(g, coin_kind(Sp[0]), (intptr_t) g->b), dst[2] = word(Ip);
  Sp = dst; Ip = (union u*) callout_drive;
  love_musttail return Continue(); }
// ($ x): max(0, ceil (re (net x))), clamped to a charm
static intptr_t saturate(word x) {
  // exactness, not speed: the net is a double, rounding a charm past 2^53 (spec.l)
  if (charmp(x)) { intptr_t n = getcharm(x); return n <= 0 ? 0 : n; }
  flo_t re = net_re(x);
  if (re <= 0) return 0;
  if (re >= (flo_t) maxcharm) return maxcharm;
  intptr_t i = (intptr_t) re;
  return i + (re > (flo_t) i ? 1 : 0); }

lvm(lvm_saturate) {
 if (coinp(Sp[0])) { g->b = (word) KnCeil; love_musttail return Ap(lvm_coin_rung, g); }
 if (__builtin_expect(!leafp(Sp[0]), 0)) love_musttail return Ap(lvm_measure, g);
 Sp[0] = putcharm(saturate(Sp[0])); Ip += 1; love_musttail return Continue(); }

// (ceil x): ceil (re (net x)), clamped to a charm; $ is this floored at 0
static intptr_t ceilnet(word x) {
  if (charmp(x)) return getcharm(x);
  flo_t re = net_re(x);
  if (re >= (flo_t) maxcharm) return maxcharm;
  if (re <= (flo_t) mincharm) return mincharm;
  intptr_t i = (intptr_t) re;
  return i + (re > (flo_t) i ? 1 : 0); }

lvm(lvm_ceil) {
 if (coinp(Sp[0])) { g->b = (word) KnCeil; love_musttail return Ap(lvm_coin_rung, g); }
 if (__builtin_expect(!leafp(Sp[0]), 0)) love_musttail return Ap(lvm_measure, g);
 Sp[0] = putcharm(ceilnet(Sp[0])); Ip += 1; love_musttail return Continue(); }

// () < mint < string < number < object tray < chain < tablet < hot; numbers by value, tablets by
// serial, lambdas by repr hash -- a preorder: colliding lambdas compare equal but are not =
static love_inline int cmp_rank(struct g *g, word x) {
 if (nomp(x)) return 0;                            // before chain: a named sym is a chain
 enum q k = kind(x);
 if (k == KString) return 1;
 if (isnum(x) || twinp(x)) return 2;
 if (k == KTrayZ || k == KTrayR || k == KTrayC) return 2;  // a galaxy orders by its net
 if (k == KTrayO) return 3;
 if (k == KChain) return 4;
 if (k == KTablet) return 5;
 return 6; }                                       // KHot
static love_inline intptr_t bytes_cmp(const char *pa, uintptr_t la, const char *pb, uintptr_t lb) {
 uintptr_t n = la < lb ? la : lb;
 int c = n ? memcmp(pa, pb, n) : 0;
 return c ? (c < 0 ? -1 : 1) : la < lb ? -1 : la > lb ? 1 : 0; }
// bare mints by serial < noms by spelling (interned: no tie). () is serial 0, so least, no guard
static love_inline intptr_t mint_cmp(struct g *g, word a, word b) {
 if (a == b) return 0;
 bool na = namep(a), nb = namep(b);
 if (na != nb) return na ? 1 : -1;
 if (na) { struct str *sa = str(nom(a)->name), *sb = str(nom(b)->name);
  return bytes_cmp(txt(sa), len(sa), txt(sb), len(sb)); }
 uintptr_t ca = sym(a)->serial, cb = sym(b)->serial;
 return ca < cb ? -1 : ca > cb ? 1 : 0; }
intptr_t love_mint_cmp(struct g *g, word a, word b) { return mint_cmp(g, a, b); }  // the point order, for +'s join
// two galaxies of equal net, so cmp3 stays antisymmetric: rank, dims, then cells (re, im)
static love_inline struct love_zn tray_cell_zn(struct tray *v, uintptr_t i) {
 if (v->type == love_C) { flo_t *d = tray_data(v); return zn(d[2*i], d[2*i+1]); }
 return zn(tray_get_flo(v, i), 0); }
static intptr_t galaxy_tie(struct tray *va, struct tray *vb) {
 if (va->rank != vb->rank) return va->rank < vb->rank ? -1 : 1;
 for (uintptr_t i = 0; i < va->rank; i++)
  if (va->shape[i] != vb->shape[i]) return va->shape[i] < vb->shape[i] ? -1 : 1;
 uintptr_t n = tray_nelem(va);
 for (uintptr_t i = 0; i < n; i++) {
  struct love_zn ea = tray_cell_zn(va, i), eb = tray_cell_zn(vb, i);
  if (ea.re != eb.re) return ea.re < eb.re ? -1 : 1;
  if (ea.im != eb.im) return ea.im < eb.im ? -1 : 1; }
 return 0; }
// two kinds compare by registration
static word kind_serial(struct g *g, word x) {
 word e = mapget(g, zero, kind_get(g, coin_kind(x), KnName), core_of(g)->kreg);
 return chainp(e) ? A(e) : zero; }
// the order sort and < share, a coin by payload (its kind's '< is for cmp_ord and sortby). cdrs
// wait on a worklist in the gap; spent, cmp_torn with the room it wanted in g->walk, carried
// up for each caller's op to run again
#define cmp_torn INTPTR_MIN
enum { CmpSettled, CmpChain, CmpCoin };                    // what a step leaves the walk
static intptr_t cmp3leaf(struct g *g, word *pa, word *pb, int *go) {
 word a = *pa, b = *pb;
 *go = CmpSettled;
 int ra = cmp_rank(g, a), rb = cmp_rank(g, b);
 if (ra != rb) return ra < rb ? -1 : 1;
 // same band, by the actual kind; symbols first, or the chain lane grabs a named sym
 if (nomp(a)) return mint_cmp(g, a, b);
 if (ra == 2) {
  if (galaxyp(a) || galaxyp(b)) {                          // by net (re, im), then star < galaxy, then shape
   bool ga = galaxyp(a), gb = galaxyp(b);
   flo_t na = net_re(a), nb = net_re(b);
   if (na != nb) return na < nb ? -1 : 1;
   flo_t ia = net_im(a), ib = net_im(b);
   if (ia != ib) return ia < ib ? -1 : 1;
   if (ga != gb) return ga ? 1 : -1;
   return galaxy_tie(tray(a), tray(b)); }
  if (twinp(a) || twinp(b)) {
   flo_t ar = twinp(a) ? twin_re(a) : toflo(a), br = twinp(b) ? twin_re(b) : toflo(b);
   if (ar != br) return ar < br ? -1 : 1;
   flo_t ai = twinp(a) ? twin_im(a) : 0, bi = twinp(b) ? twin_im(b) : 0;
   return ai < bi ? -1 : ai > bi ? 1 : 0; }
  if (gemp(a) || gemp(b)) { flo_t av = toflo(a), bv = toflo(b); return av < bv ? -1 : av > bv ? 1 : 0; }
  return big_cmp(a, b); }
 if (strp(a)) return bytes_cmp(txt(a), len(a), txt(b), len(b));
 if (chainp(a)) return *go = CmpChain, 0;
 if (coinp(a) && coinp(b)) {
  if (coin_kind(a) == coin_kind(b)) return *pa = coin_load(a), *pb = coin_load(b), *go = CmpCoin, 0;   // by payload
  word sa = kind_serial(g, a), sb = kind_serial(g, b);
  if (charmp(sa) && charmp(sb) && sa != sb) return getcharm(sa) < getcharm(sb) ? -1 : 1; }
 if (tabp(a) && tabp(b)) { uintptr_t sa = map_serial(a), sb = map_serial(b);   // mutable: its identity
  return sa < sb ? -1 : sa > sb ? 1 : 0; }                                        // orders it, never its contents
 uintptr_t ha = hash(g, a), hb = hash(g, b);
 return ha < hb ? -1 : ha > hb ? 1 : 0; }

static intptr_t cmp3w(struct g *g, word a, word b) {
 word *hi, *base = gap(g, &hi), *w = base, *hp0 = g->hp;
 int go;
 for (;;) {
  g->hp = w;                                               // a hash's walk takes the gap past ours
  intptr_t c = cmp3leaf(g, &a, &b, &go);
  g->hp = hp0;
  if (g->walk) return cmp_torn;                            // a walk under it spent the gap
  if (go == CmpCoin) continue;
  if (go == CmpChain) {                                    // the cars first
   if ((uintptr_t) (hi - w) < 2) return walk_short(g, base, hi, 2), cmp_torn;
   *w++ = B(a), *w++ = B(b), a = A(a), b = A(b);
   continue; }
  if (c || w == base) return c;
  b = *--w, a = *--w; } }

// for arr.c's equality lane
bool numband(struct g *g, word x) { return cmp_rank(g, x) == 2; }
static love_inline intptr_t cmp3(struct g *g, word a, word b) { return cmp3w(g, a, b); }
intptr_t love_cmp3(struct g *g, word a, word b) { return cmp3(g, a, b); }

// (tally x): how many, never how much -- charms, links, cells, keys, a symbol's spelling
intptr_t love_count(struct g *g, word l) {
 while (coinp(l)) l = coin_load(l);
 if (strp(l)) return (intptr_t) len(l);
 if (caskp(l)) return (intptr_t) len(cask(l)->str);
 if (tabp(l)) return (intptr_t) map_len(l);
 if (trayp(l)) return (intptr_t) tray_nelem(tray(l));
 if (nomp(l)) { struct str *nm = nom_str(g, l); return nm ? (intptr_t) len(nm) : 0; }
 intptr_t n = 0;
 while (chainp(l)) n++, l = B(l);
 return n; }

lvm(lvm_tally) {
 Sp[0] = putcharm(love_count(g, Sp[0]));
 love_musttail return Next(1); }

// (long? n l): l at least n links deep, the arity question post.l's patterns ask once
lvm(lvm_longp) { word l = Sp[1];
 if (!charmp(Sp[0])) love_musttail return Push(zero);
 for (intptr_t k = getcharm(Sp[0]); k > 0; k--) {
  if (!chainp(l) || nomp(l)) love_musttail return Push(zero);
  l = B(l); }
 love_musttail return Push(putcharm(1)); }

// (sort l): a stable ascending merge, one reservation up front; cmp3 never allocates
lvm(lvm_sort) {
 word l = Sp[0];
 if (!chainp(l) || !chainp(B(l))) love_musttail return Next(1);
 uintptr_t n = 0;
 for (word p = l; chainp(p); p = B(p)) {
  if (coinp(A(p))) { *--Sp = nif_word("<="); love_musttail return Ap(lvm_sortby, g); }   // a coin: its kind's order; <= keeps ties left
  n++; }
 uintptr_t req = n * Width(struct chain) + 2 * n + 256;   // the spine, 2n scratch, a radix table
 Have(req);
 l = Sp[0];
 struct chain *spine = (struct chain*) Hp;
 Hp += n * Width(struct chain);                   // the spine only
 word *a = (word*) Hp, *b = a + n, *end = b + n;   // scratch in the uncommitted gap
 uintptr_t i = 0;
 for (word p = l; chainp(p); p = B(p)) a[i++] = A(p);
 for (i = 0; i < n; i++) if (!charmp(a[i])) break;
 bool allfix = i == n;                               // a tagged charm orders as a signed word
 if (!allfix) Pack(g), g->hp = end;                  // cmp3's walks take the gap past the scratch
 if (allfix && n >= 64) {                            // LSD radix, a byte a pass over the key span
  intptr_t lo = (intptr_t) a[0], hi = lo;
  for (i = 1; i < n; i++) { intptr_t v = (intptr_t) a[i]; if (v < lo) lo = v; if (v > hi) hi = v; }
  uintptr_t span = ((uintptr_t) hi - (uintptr_t) lo) >> 1;   // the tag bit never differs
  int bits = span ? 64 - __builtin_clzll((unsigned long long) span) : 0;
  uintptr_t *cnt = (uintptr_t*) (b + n);              // past the scratch, still in the gap
  for (int sh = 0; sh < bits; sh += 8) {
   for (uintptr_t k = 0; k < 256; k++) cnt[k] = 0;
   for (i = 0; i < n; i++) cnt[((a[i] - (uintptr_t) lo) >> (sh + 1)) & 255]++;
   for (uintptr_t k = 0, s = 0; k < 256; k++) { uintptr_t c = cnt[k]; cnt[k] = s; s += c; }
   for (i = 0; i < n; i++) b[cnt[((a[i] - (uintptr_t) lo) >> (sh + 1)) & 255]++] = a[i];
   word *t = a; a = b; b = t; } }
 else for (uintptr_t w = 1; w < n; w *= 2) {       // bottom-up stable merge
  for (uintptr_t lo = 0; lo < n; lo += 2 * w) {
   uintptr_t m = min(lo + w, n), hi = min(lo + 2 * w, n), x = lo, y = m, o = lo;
   if (allfix) while (x < m && y < hi) b[o++] = (intptr_t) a[y] < (intptr_t) a[x] ? a[y++] : a[x++];
   else        while (x < m && y < hi) {
    intptr_t c = cmp3(g, a[y], a[x]);
    if (c == cmp_torn) { Hp = (word*) spine; WalkAgain(); Pack(g); love_musttail return Ap(_lvm_ghelp, g); }   // the spine unlaid first
    b[o++] = c < 0 ? a[y++] : a[x++]; }
   while (x < m) b[o++] = a[x++];
   while (y < hi) b[o++] = a[y++]; }
  word *t = a; a = b; b = t; }
 for (i = 0; i < n; i++) ini_chain(spine + i, a[i], word(spine + i + 1));
 spine[n - 1].b = ZeroPoint;
 love_musttail return Answer(word(spine)); }

// a coin by its kind's '<, either side: ((f x) y) under numap_drive, [x f y land code ret] over
// the operands. code 0 as is, 1 negated (<= and >=), 2 the extreme (a if true, else b)
static lvm(lvm_coin_cmp_land) {
 if (__builtin_expect(!leafp(Sp[0]), 0)) love_musttail return Ap(lvm_measure, g);
 bool t = !leaf_nilp(Sp[0]); intptr_t code = getcharm(Sp[1]);
 Ip = cell(Sp[2]);
 Sp += 3;                                                    // [ans code ret a b] -> [a b]
 word r = code == 2 ? (t ? Sp[0] : Sp[1]) : putcharm(code ? !t : t);
 Sp += 1; Sp[0] = r;
 love_musttail return Continue(); }
static union u const coin_cmp_land[] = { {.ap = lvm_coin_cmp_land} };
// the coin's '<, or 0: two kinds have no order, and a kind without '< orders by payload (cmp3)
static love_inline word coin_lt(struct g *g, word a, word b) {
 if (coinp(a) && coinp(b) && coin_kind(a) != coin_kind(b)) return 0;
 word f = kind_get(g, coin_kind(coinp(a) ? a : b), KnLt);
 return f != ZeroPoint ? f : 0; }
static lvm(lvm_coin_cmp) {                                   // g->b = code << 1 | swap
 intptr_t k = g->b; bool swap = k & 1; intptr_t code = k >> 1;
 Have(6);
 word a = Sp[0], b = Sp[1], f = coin_lt(g, a, b), *dst = Sp - 6;
 dst[0] = swap ? b : a, dst[1] = f, dst[2] = swap ? a : b;
 dst[3] = word(coin_cmp_land), dst[4] = putcharm(code), dst[5] = word(Ip + 1);
 Sp = dst; Ip = (union u*) numap_drive;
 love_musttail return Continue(); }

// the four comparisons: a tray -> an elementwise mask; floats keep IEEE, (<= nan nan) is 0
static lvm(lvm_cmp_ord) {
 int op = (int) g->b;
 word a = Sp[0], b = Sp[1]; intptr_t r;
 if (trayp(a) || trayp(b)) { g->b = (word) (op); love_musttail return Ap(lvm_vbin, g); }
 if ((coinp(a) || coinp(b)) && coin_lt(g, a, b)) {
  g->b = (word) (op == vop_lt ? 0 : op == vop_gt ? 1 : op == vop_le ? 3 : 2);                // le: !(b<a), ge: !(a<b)
  love_musttail return Ap(lvm_coin_cmp, g); }
 int ra = cmp_rank(g, a), rb = cmp_rank(g, b);
 if (ra != rb) r = vcmp_int(op, ra, rb);
 else if (!(isnum(a) || twinp(a))) {
  Pack(g);                                                 // cmp3's walks take the gap
  intptr_t c = cmp3(g, a, b);
  if (c == cmp_torn) { WalkAgain(); Pack(g); love_musttail return Ap(_lvm_ghelp, g); }
  r = vcmp_int(op, c, 0); }
 else if (twinp(a) || twinp(b)) {
  flo_t ar = twinp(a) ? twin_re(a) : toflo(a), br = twinp(b) ? twin_re(b) : toflo(b);
  r = ar != br ? vcmp_flo(op, ar, br)
              : vcmp_flo(op, twinp(a) ? twin_im(a) : 0, twinp(b) ? twin_im(b) : 0); }
 else if (gemp(a) || gemp(b)) r = vcmp_flo(op, toflo(a), toflo(b));
 else if (bigp(a) || bigp(b)) r = vcmp_int(op, big_cmp(a, b), 0);
 else r = vcmp_int(op, toint(a), toint(b));
 love_musttail return Push(r ? putcharm(1) : zero); }
// each carries its own vop down every lane, never one reaching another by swapping operands:
// Have restarts the op, so a swap of Sp swaps again after a collection. lvm_cond next fuses
cmp_lt(lvm_lt, vop_lt) cmp_lt(lvm_le, vop_le)
cmp_lt(lvm_gt, vop_gt) cmp_lt(lvm_ge, vop_ge)
#undef cmp_lt

// (max a b) (min a b) by `<`'s order, the operand itself; a tray -> elementwise (amax is aextreme)
static lvm(lvm_extreme2) {
 int ismax = (int) g->b;
 word a = Sp[0], b = Sp[1];
 if (trayp(a) || trayp(b)) { g->b = (word) (ismax ? vop_max : vop_min); love_musttail return Ap(lvm_vbin, g); }
 if ((coinp(a) || coinp(b)) && coin_lt(g, a, b)) { g->b = (word) (4 | ismax); love_musttail return Ap(lvm_coin_cmp, g); }   // max asks b < a, min a < b
 Pack(g);
 intptr_t c = cmp3(g, a, b);
 if (c == cmp_torn) { WalkAgain(); Pack(g); love_musttail return Ap(_lvm_ghelp, g); }
 love_musttail return Push((ismax ? c >= 0 : c <= 0) ? a : b); }
lvm(lvm_max2) { g->b = (word) 1; love_musttail return Ap(lvm_extreme2, g); }
lvm(lvm_min2) { g->b = (word) 0; love_musttail return Ap(lvm_extreme2, g); }

// a bignum is out of machine-int range, so it orders against an int element by sign alone
static intptr_t vcmp_sign(int op, int s) {
 switch (op) {
  case vop_lt: return s < 0; case vop_le: return s <= 0;
  case vop_gt: return s > 0; case vop_ge: return s >= 0;
  default: return s == 0; } }                   // vop_eq

// a size-1 axis takes the other size, 0 included: a max would fill an empty axis
static love_inline uintptr_t bdim(uintptr_t da, uintptr_t db) {
 return da == 1 ? db : db == 1 ? da : da; }

// the broadcast walk runs twice, gate before the Have and fill after, as the operands move.
// -> the element count and the rank in *R, or -1 for non-conformance
uintptr_t bshape(word a, word b, uintptr_t *R) {
 bool atray = trayp(a), btray = trayp(b);
 uintptr_t ra = atray ? tray(a)->rank : 0, rb = btray ? tray(b)->rank : 0, n = 1;
 *R = ra > rb ? ra : rb;
 for (uintptr_t k = 0; k < *R; k++) {
  uintptr_t da = (atray && k < ra) ? tray(a)->shape[ra - 1 - k] : 1,
            db = (btray && k < rb) ? tray(b)->shape[rb - 1 - k] : 1;
  if (da != db && da != 1 && db != 1) return (uintptr_t) -1;
  n = mulsat(n, bdim(da, db)); }
 return n; }

// the broadcast shape, conformance gated by bshape
void bshape_put(uintptr_t *shape, uintptr_t R, word a, word b) {
 bool atray = trayp(a), btray = trayp(b);
 uintptr_t ra = atray ? tray(a)->rank : 0, rb = btray ? tray(b)->rank : 0;
 for (uintptr_t k = 0; k < R; k++) {
  uintptr_t da = (atray && k < ra) ? tray(a)->shape[ra - 1 - k] : 1,
            db = (btray && k < rb) ? tray(b)->shape[rb - 1 - k] : 1;
  shape[R - 1 - k] = bdim(da, db); } }

// c[j]: axis j's flat-offset stride, 0 where absent or broadcast; v == 0 is a scalar
void bstride(struct tray *v, uintptr_t R, intptr_t *c) {
 for (uintptr_t j = 0; j < R; j++) c[j] = 0;
 if (!v) return;
 intptr_t s = 1;
 for (intptr_t o = (intptr_t) v->rank - 1; o >= 0; o--) {
  intptr_t j = o + (intptr_t) R - (intptr_t) v->rank;
  c[j] = v->shape[o] == 1 ? 0 : s, s *= (intptr_t) v->shape[o]; } }

// r = a op b, broadcasting. the &-taken stack arrays live here, so the wrapper keeps its tail
// call; no allocation, so the operands stay put
static love_noinline void vbin_fill(struct tray *r, word a, word b, int op, bool fdom) {
 uintptr_t R = r->rank, n = tray_nelem(r);
 bool atray = trayp(a), btray = trayp(b);
 struct tray *va = atray ? tray(a) : 0, *vb = btray ? tray(b) : 0;
 // no broadcast and one type: raw pointers, the op hoisted, a body that vectorizes;
 // bit-identical to the general loop
 bool cmpf = op >= vop_lt,
      aok = !atray || tray_nelem(va) == n, bok = !btray || tray_nelem(vb) == n,
      nobig = !((!atray && bigp(a)) || (!btray && bigp(b)));
 // unswitched, a loop per operand shape
 #define VBL(T, A, B, SA, SB, BODY) do { \
  if (atray && btray) for (uintptr_t p = 0; p < n; p++) { T av = A[p], bv = B[p]; BODY; } \
  else if (atray) for (uintptr_t p = 0; p < n; p++) { T av = A[p], bv = SB; BODY; } \
  else if (btray) for (uintptr_t p = 0; p < n; p++) { T av = SA, bv = B[p]; BODY; } \
  else for (uintptr_t p = 0; p < n; p++) { T av = SA, bv = SB; BODY; } } while (0)
 if (aok && bok && nobig) {
  if (fdom && (!atray || va->type == love_R) && (!btray || vb->type == love_R)) {
   flo_t sa = atray ? 0 : toflo(a), sb = btray ? 0 : toflo(b);
   flo_t *ap = atray ? (flo_t*) tray_data(va) : 0, *bp = btray ? (flo_t*) tray_data(vb) : 0;
   if (cmpf) { intptr_t *rp = (intptr_t*) tray_data(r);
    #define VBF(E) VBL(flo_t, ap, bp, sa, sb, rp[p] = (E) ? 1 : 0)
    switch (op) { case vop_lt: VBF(av<bv); return; case vop_le: VBF(av<=bv); return;
      case vop_gt: VBF(av>bv); return; case vop_ge: VBF(av>=bv); return;
      case vop_eq: VBF(same_flo(av,bv)); return; }   // a NaN is (), = holds over it
    #undef VBF
   } else { flo_t *rp = (flo_t*) tray_data(r);
    #define VBF(E) VBL(flo_t, ap, bp, sa, sb, rp[p] = (E))
    switch (op) { case vop_add: VBF(av+bv); return; case vop_sub: VBF(av-bv); return;
      case vop_mul: VBF(av*bv); return; case vop_quot: VBF(av/bv); return;
      case vop_fquot: VBF(love_trunc(av/bv)); return; case vop_rem: VBF(bv==0?av:love_fmod(av,bv)); return;
      case vop_max: VBF(av>bv?av:bv); return; case vop_min: VBF(av<bv?av:bv); return; }
    #undef VBF
   }
  } else if (fdom && (!atray || va->type <= love_R) && (!btray || vb->type <= love_R)) {
   // an int tray on a side, a mask most often: widened in the loop
   bool az = atray && va->type == love_Z, bz = btray && vb->type == love_Z;
   flo_t sa = atray ? 0 : toflo(a), sb = btray ? 0 : toflo(b);
   flo_t *af = atray && !az ? (flo_t*) tray_data(va) : 0, *bf = btray && !bz ? (flo_t*) tray_data(vb) : 0;
   intptr_t *ai = az ? (intptr_t*) tray_data(va) : 0, *bi = bz ? (intptr_t*) tray_data(vb) : 0;
   #define VBX(AV, BV, BODY) for (uintptr_t p = 0; p < n; p++) { flo_t av = (AV), bv = (BV); BODY; }
   #define VBM(BODY) do { \
    if (az && bz) VBX((flo_t) ai[p], (flo_t) bi[p], BODY) \
    else if (az && bf) VBX((flo_t) ai[p], bf[p], BODY) \
    else if (az) VBX((flo_t) ai[p], sb, BODY) \
    else if (af) VBX(af[p], (flo_t) bi[p], BODY) \
    else VBX(sa, (flo_t) bi[p], BODY) } while (0)
   if (cmpf) { intptr_t *rp = (intptr_t*) tray_data(r);
    #define VBF(E) VBM(rp[p] = (E) ? 1 : 0)
    switch (op) { case vop_lt: VBF(av<bv); return; case vop_le: VBF(av<=bv); return;
      case vop_gt: VBF(av>bv); return; case vop_ge: VBF(av>=bv); return;
      case vop_eq: VBF(same_flo(av,bv)); return; }
    #undef VBF
   } else { flo_t *rp = (flo_t*) tray_data(r);
    #define VBF(E) VBM(rp[p] = (E))
    switch (op) { case vop_add: VBF(av+bv); return; case vop_sub: VBF(av-bv); return;
      case vop_mul: VBF(av*bv); return; case vop_quot: VBF(av/bv); return;
      case vop_fquot: VBF(love_trunc(av/bv)); return; case vop_rem: VBF(bv==0?av:love_fmod(av,bv)); return;
      case vop_max: VBF(av>bv?av:bv); return; case vop_min: VBF(av<bv?av:bv); return; }
    #undef VBF
   }
   #undef VBM
   #undef VBX
  } else if (!fdom && (!atray || va->type == love_Z) && (!btray || vb->type == love_Z)) {
   intptr_t sia = atray ? 0 : toint(a),
            sib = btray ? 0 : toint(b),
            *ap = atray ? (intptr_t*) tray_data(va) : 0, *bp = btray ? (intptr_t*) tray_data(vb) : 0,
            *rp = (intptr_t*) tray_data(r);   // love_Z, arithmetic or mask
   if (cmpf) {
    #define VBF(E) VBL(intptr_t, ap, bp, sia, sib, rp[p] = (E) ? 1 : 0)
    switch (op) { case vop_lt: VBF(av<bv); return; case vop_le: VBF(av<=bv); return;
      case vop_gt: VBF(av>bv); return; case vop_ge: VBF(av>=bv); return; case vop_eq: VBF(av==bv); return; }
    #undef VBF
   } else {
    #define VBF(E) VBL(intptr_t, ap, bp, sia, sib, rp[p] = (E))
    switch (op) {
      case vop_add: VBF((intptr_t)((uintptr_t)av+(uintptr_t)bv)); return;
      case vop_sub: VBF((intptr_t)((uintptr_t)av-(uintptr_t)bv)); return;
      case vop_mul: VBF((intptr_t)((uintptr_t)av*(uintptr_t)bv)); return;
      case vop_quot: case vop_fquot: VBF((bv==0||(av==INTPTR_MIN&&bv==-1))?0:av/bv); return;
      case vop_rem: VBF(bv==0?av:(av==INTPTR_MIN&&bv==-1)?0:av%bv); return;
      case vop_max: VBF(av>bv?av:bv); return; case vop_min: VBF(av<bv?av:bv); return; } } } }
    #undef VBF
 #undef VBL
 struct bcast w; bc_open(&w, va, vb, R, r->shape);
 bool cmp = op >= vop_lt;
 // a bignum scalar demotes by low bits for arithmetic, but compares exactly by its sign
 flo_t sa = atray ? 0 : toflo(a), sb = btray ? 0 : toflo(b);
 intptr_t ia = atray ? 0 : toint(a), ib = btray ? 0 : toint(b);
 bool abig = !atray && bigp(a), bbig = !btray && bigp(b);   // at most one
 int asign = abig ? (big(a)->slen < 0 ? -1 : 1) : 0,
     bsign = bbig ? (big(b)->slen < 0 ? -1 : 1) : 0;
 for (uintptr_t p = 0; p < n; p++, bc_step(&w)) {
  intptr_t oa = w.oa, ob = w.ob;
  if (fdom) {
   flo_t av = atray ? tray_get_flo(va, oa) : sa, bv = btray ? tray_get_flo(vb, ob) : sb;
   if (cmp) tray_put_int(r, p, vcmp_flo(op, av, bv) ? 1 : 0);
   else tray_put_flo(r, p, vop_flo(op, av, bv)); }
  else {
   intptr_t av = atray ? tray_get_int(va, oa) : ia, bv = btray ? tray_get_int(vb, ob) : ib;
   if (cmp) {                                    // a - b ~ asign, or -bsign
    intptr_t t = (abig || bbig) ? vcmp_sign(op, abig ? asign : -bsign) : vcmp_int(op, av, bv);
    tray_put_int(r, p, t ? 1 : 0); }
   else tray_put_int(r, p, vop_int(op, av, bv)); } } }

// `/` over ints goes float when some element divides inexactly, `//` when some divisor is 0,
// as the scalars do; only after conformance
static love_noinline bool vquot_needs_float(int op, word a, word b) {
 bool atray = trayp(a), btray = trayp(b);
 if (op == vop_fquot && !btray) return b == putcharm(0);
 if ((!atray && bigp(a)) || (!btray && bigp(b))) return true;
 struct tray *va = atray ? tray(a) : 0, *vb = btray ? tray(b) : 0;
 uintptr_t R, n = bshape(a, b, &R), shp[maxrank];
 bshape_put(shp, R, a, b);
 struct bcast w; bc_open(&w, va, vb, R, shp);
 intptr_t ia = atray ? 0 : toint(a), ib = btray ? 0 : toint(b);
 for (uintptr_t p = 0; p < n; p++, bc_step(&w)) {
  intptr_t oa = w.oa, ob = w.ob;
  intptr_t av = atray ? tray_get_int(va, oa) : ia, bv = btray ? tray_get_int(vb, ob) : ib;
  if (bv == 0 || (op == vop_quot && av % bv != 0)) return true; }
 return false; }

lvm(lvm_vbin) {
 int op = (int) g->b;
 word a = Sp[0], b = Sp[1];
 bool atray = trayp(a), btray = trayp(b);
 // complex first, as a complex scalar isn't isnum; with love_O, the love_O lane wins
 if (((atray && tray(a)->type == love_C) || (btray && tray(b)->type == love_C) || twinp(a) || twinp(b))
     && !(atray && tray(a)->type == love_O) && !(btray && tray(b)->type == love_O)) {
  if (vop_bitp(op)) love_musttail return Push(ZeroPoint);   // no bits on a complex
  g->b = (word) (op); love_musttail return Ap(lvm_cbin, g); }
 if (!(atray || isnum(a)) || !(btray || isnum(b)))
  love_musttail return Push(op == vop_eq ? zero : ZeroPoint);   // `=` is boolean: 0, not ()
 if ((atray && tray(a)->type == love_O) || (btray && tray(b)->type == love_O)) {
  // boxed cells are not the word lane: the bits refused whole, not per element
  if (vop_bitp(op)) love_musttail return Push(ZeroPoint);
  g->b = (word) (op); love_musttail return Ap(lvm_obin, g); }
 // the max element type; a scalar int never widens an int tray, a scalar float goes float
 int ta = atray ? (int) tray(a)->type : gemp(a) ? (int) love_R : (int) love_Z,
     tb = btray ? (int) tray(b)->type : gemp(b) ? (int) love_R : (int) love_Z,
     ct = ta > tb ? ta : tb;
 bool fdom = ct >= love_R, cmp = op >= vop_lt;
 if (vop_bitp(op) && fdom) love_musttail return Push(ZeroPoint);   // no bits on a gem
 uintptr_t R, n = bshape(a, b, &R);
 if (n == (uintptr_t) -1) love_musttail return Push(op == vop_eq ? zero : ZeroPoint);
 if ((op == vop_quot || op == vop_fquot) && !fdom && vquot_needs_float(op, a, b)) fdom = true, ct = love_R;
 enum tray_type rt = cmp ? love_Z : (enum tray_type) ct;   // a compare: a Z mask
 uintptr_t bytes = tray_bytes(rt, R, n);
 Have(b2w(bytes));
 a = Sp[0], b = Sp[1];                                       // re-read post-Have
 struct tray *r = ini_tray((struct tray*) Hp, rt, R); Hp += b2w(bytes);
 bshape_put(r->shape, R, a, b);
 vbin_fill(r, a, b, op, fdom);
 love_musttail return Push(word(r)); }

// pow, atan2 and the like, broadcasting: lvm_vbin's float twin
static love_noinline void vmap2_fill(struct tray *r, word a, word b, flo_t (*fn)(flo_t, flo_t)) {
 uintptr_t R = r->rank, n = tray_nelem(r);
 bool atray = trayp(a), btray = trayp(b);
 struct tray *va = atray ? tray(a) : 0, *vb = btray ? tray(b) : 0;
 struct bcast w; bc_open(&w, va, vb, R, r->shape);
 flo_t sa = atray ? 0 : toflo(a), sb = btray ? 0 : toflo(b);
 for (uintptr_t p = 0; p < n; p++, bc_step(&w)) {
  intptr_t oa = w.oa, ob = w.ob;
  flo_t av = atray ? tray_get_flo(va, oa) : sa, bv = btray ? tray_get_flo(vb, ob) : sb;
  tray_put_flo(r, p, fn(av, bv)); } }

lvm(lvm_vmap2) {
 flo2 fn = (flo2) (uintptr_t) g->b;
 word a = Sp[0], b = Sp[1];
 bool atray = trayp(a), btray = trayp(b);
 if (!(atray || isnum(a)) || !(btray || isnum(b)))
  love_musttail return Push(ZeroPoint);
 uintptr_t R, n = bshape(a, b, &R);
 if (n == (uintptr_t) -1) love_musttail return Push(ZeroPoint);
 uintptr_t bytes = tray_bytes(love_R, R, n);
 Have(b2w(bytes));
 a = Sp[0], b = Sp[1];                                       // re-read post-Have
 struct tray *r = ini_tray((struct tray*) Hp, love_R, R); Hp += b2w(bytes);
 bshape_put(r->shape, R, a, b);
 vmap2_fill(r, a, b, fn);
 love_musttail return Push(word(r)); }
