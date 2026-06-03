#include "i.h"

// Step 6 -- arbitrary-precision integers (bignums). Closes the numeric tower
// fixnum -> wide-int box -> bignum. The representation is the big_q data
// sentinel `struct g_big` (i.h): sign-magnitude, 32-bit base-2^32 limbs,
// little-endian, top limb nonzero, slen the signed limb count. Zero is never a
// bignum (it demotes to nil), so every bignum has |slen| >= 1 limbs.
//
// All multi-limb work lives in g_noinline magnitude helpers operating on raw
// uint32_t arrays (no gwen pointers, no allocation), so the VM-facing entry
// points keep their tail calls and the GC never sees a half-built object. The
// arithmetic uses 32-bit limbs with a uint64_t accumulator on every target:
// limb products fit a uint64_t and Knuth divmod's 2-limb/1-limb step needs no
// __int128 (not guaranteed on freestanding 32-bit ports). Schoolbook mul +
// Knuth Algorithm D divmod -- Karatsuba/Toom are a later speed diff.

#define LIMB_BITS 32
#define LIMB_BASE ((uint64_t) 1 << LIMB_BITS)

// |slen| of a heap bignum.
static g_inline int big_nlimbs(word x) {
 intptr_t s = ((struct g_big*) x)->slen;
 return (int) (s < 0 ? -s : s); }

uintptr_t g_big_bytes(struct g_big *b) {
 intptr_t n = b->slen < 0 ? -b->slen : b->slen;
 return sizeof(struct g_big) + (uintptr_t) n * sizeof(uint32_t); }

// --- raw magnitude primitives (little-endian uint32_t limb arrays) ----------
// Callers pass normalized inputs (no leading zero limbs) and normalize outputs
// via g_big_canon, which strips leading zeros itself.

static int mag_copy(uint32_t *dst, uint32_t const *src, int n) {
 for (int i = 0; i < n; i++) dst[i] = src[i];
 return n; }

// Compare magnitudes: -1 if a<b, 0 if equal, 1 if a>b.
static g_noinline int mag_cmp(uint32_t const *a, int na, uint32_t const *b, int nb) {
 while (na > 0 && a[na-1] == 0) na--;
 while (nb > 0 && b[nb-1] == 0) nb--;
 if (na != nb) return na < nb ? -1 : 1;
 for (int i = na - 1; i >= 0; i--) if (a[i] != b[i]) return a[i] < b[i] ? -1 : 1;
 return 0; }

// r = a + b. r distinct from a,b; capacity >= max(na,nb)+1. Returns limb count.
static g_noinline int mag_add(uint32_t *r, uint32_t const *a, int na, uint32_t const *b, int nb) {
 if (na < nb) { uint32_t const *t = a; a = b; b = t; int u = na; na = nb; nb = u; }
 uint64_t c = 0; int i = 0;
 for (; i < nb; i++) { uint64_t s = (uint64_t) a[i] + b[i] + c; r[i] = (uint32_t) s; c = s >> 32; }
 for (; i < na; i++) { uint64_t s = (uint64_t) a[i] + c;        r[i] = (uint32_t) s; c = s >> 32; }
 if (c) r[i++] = (uint32_t) c;
 return i; }

// r = a - b, requires a >= b (magnitudes). r distinct from a,b. Returns na
// (caller normalizes away any high zero limbs the subtraction produced).
static g_noinline int mag_sub(uint32_t *r, uint32_t const *a, int na, uint32_t const *b, int nb) {
 int64_t borrow = 0; int i = 0;
 for (; i < nb; i++) {
  int64_t d = (int64_t) a[i] - b[i] - borrow;
  if (d < 0) d += (int64_t) LIMB_BASE, borrow = 1; else borrow = 0;
  r[i] = (uint32_t) d; }
 for (; i < na; i++) {
  int64_t d = (int64_t) a[i] - borrow;
  if (d < 0) d += (int64_t) LIMB_BASE, borrow = 1; else borrow = 0;
  r[i] = (uint32_t) d; }
 return na; }

// r = a * b (schoolbook). r must be distinct from a,b; capacity >= na+nb.
static g_noinline void mag_mul(uint32_t *r, uint32_t const *a, int na, uint32_t const *b, int nb) {
 for (int i = 0; i < na + nb; i++) r[i] = 0;
 for (int i = 0; i < na; i++) {
  uint64_t carry = 0, ai = a[i];
  for (int j = 0; j < nb; j++) {
   uint64_t s = ai * b[j] + r[i+j] + carry;
   r[i+j] = (uint32_t) s; carry = s >> 32; }
  r[i+nb] = (uint32_t) carry; } }

// a = a*mul + add, in place (mul,add < 2^32). a capacity must allow one carry
// limb at a[n]. Returns the new limb count. Used by the decimal reader.
static g_noinline int mag_mul_add_small(uint32_t *a, int n, uint32_t mul, uint32_t add) {
 uint64_t c = add;
 for (int i = 0; i < n; i++) { uint64_t s = (uint64_t) a[i] * mul + c; a[i] = (uint32_t) s; c = s >> 32; }
 if (c) a[n++] = (uint32_t) c;
 return n; }

// a /= d in place (d != 0), returning the remainder. Used by the printer.
static g_noinline uint32_t mag_divmod_small(uint32_t *a, int n, uint32_t d) {
 uint64_t rem = 0;
 for (int i = n - 1; i >= 0; i--) { uint64_t cur = (rem << 32) | a[i]; a[i] = (uint32_t) (cur / d); rem = cur % d; }
 return (uint32_t) rem; }

// Knuth Algorithm D long division (Hacker's Delight `divmnu`). Divides u (m
// limbs) by v (n limbs, v[n-1] != 0, m >= n): q gets the m-n+1 quotient limbs,
// r the n remainder limbs. un (scratch, >= m+1) and vn (scratch, >= n) hold the
// normalized dividend/divisor. q,r,un,vn all distinct from u,v.
static g_noinline void mag_divmod(uint32_t *q, uint32_t *r,
  uint32_t const *u, int m, uint32_t const *v, int n, uint32_t *un, uint32_t *vn) {
 uint64_t const B = LIMB_BASE;
 if (n == 1) {                                  // single-limb divisor: simple
  uint64_t rem = 0;
  for (int j = m - 1; j >= 0; j--) { uint64_t cur = (rem << 32) | u[j]; q[j] = (uint32_t) (cur / v[0]); rem = cur % v[0]; }
  r[0] = (uint32_t) rem; return; }
 int s = __builtin_clz(v[n-1]);                 // normalize so v[n-1] has its top bit set
 for (int i = n - 1; i > 0; i--) vn[i] = (v[i] << s) | (s ? (uint64_t) v[i-1] >> (32 - s) : 0);
 vn[0] = v[0] << s;
 un[m] = s ? (uint64_t) u[m-1] >> (32 - s) : 0;
 for (int i = m - 1; i > 0; i--) un[i] = (u[i] << s) | (s ? (uint64_t) u[i-1] >> (32 - s) : 0);
 un[0] = u[0] << s;
 for (int j = m - n; j >= 0; j--) {
  uint64_t num = ((uint64_t) un[j+n] << 32) | un[j+n-1];
  uint64_t qhat = num / vn[n-1], rhat = num % vn[n-1];
  while (qhat >= B || qhat * vn[n-2] > ((rhat << 32) | un[j+n-2])) {
   qhat--; rhat += vn[n-1];
   if (rhat >= B) break; }
  int64_t borrow = 0;                           // multiply and subtract qhat*v
  for (int i = 0; i < n; i++) {
   uint64_t p = qhat * vn[i];
   int64_t sub = (int64_t) un[i+j] - borrow - (int64_t) (uint32_t) p;
   un[i+j] = (uint32_t) sub;
   borrow = (int64_t) (p >> 32) - (sub >> 32); }
  int64_t sub = (int64_t) un[j+n] - borrow;
  un[j+n] = (uint32_t) sub;
  q[j] = (uint32_t) qhat;
  if (sub < 0) {                                // qhat was one too big: add back
   q[j]--;
   uint64_t carry = 0;
   for (int i = 0; i < n; i++) { uint64_t t = (uint64_t) un[i+j] + vn[i] + carry; un[i+j] = (uint32_t) t; carry = t >> 32; }
   un[j+n] = (uint32_t) (un[j+n] + carry); } }
 for (int i = 0; i < n; i++) r[i] = s ? (un[i] >> s) | ((uint64_t) un[i+1] << (32 - s)) : un[i]; }

// --- operand loading + tier conversions -------------------------------------

// Load integer operand x (fixnum / wide-int box / bignum -- never a float) as a
// magnitude. A fixnum/box fills `scratch` (1-2 limbs) and points *out at it; a
// bignum points *out into its heap limbs (stable only while no GC runs). Sets
// *neg and returns the limb count (0 for the value zero).
static int load_int_mag(word x, uint32_t scratch[2], uint32_t const **out, bool *neg) {
 if (bigp(x)) { struct g_big *b = (struct g_big*) x; intptr_t s = b->slen;
  *neg = s < 0, *out = b->limb; return (int) (s < 0 ? -s : s); }
 intptr_t v = nump(x) ? (intptr_t) getnum(x) : box_get(x);
 *neg = v < 0;
 uintptr_t u = *neg ? (uintptr_t) 0 - (uintptr_t) v : (uintptr_t) v;
 scratch[0] = (uint32_t) u;
 int k;
#if WBITS == 64
 scratch[1] = (uint32_t) (u >> 32);
 k = scratch[1] ? 2 : scratch[0] ? 1 : 0;
#else
 k = scratch[0] ? 1 : 0;
#endif
 *out = scratch;
 return k; }

g_flo_t g_big_to_flo(word x) {
 struct g_big *b = (struct g_big*) x;
 intptr_t sl = b->slen; bool neg = sl < 0; int n = (int) (neg ? -sl : sl);
 double r = 0;
 for (int i = n - 1; i >= 0; i--) r = r * 4294967296.0 + (double) b->limb[i];
 return (g_flo_t) (neg ? -r : r); }

// The bignum's two's-complement value mod 2^W (its low machine word). Used when
// an integer-array elementwise op must broadcast a bignum scalar down to one
// machine-int element ("arrays win; demote the bignum by its low bits").
intptr_t g_big_low(word x) {
 struct g_big *b = (struct g_big*) x;
 intptr_t sl = b->slen; bool neg = sl < 0; int n = (int) (neg ? -sl : sl);
 uintptr_t u = b->limb[0];
#if WBITS == 64
 if (n >= 2) u |= ((uintptr_t) b->limb[1] << 16) << 16;
#endif
 return (intptr_t) (neg ? (uintptr_t) 0 - u : u); }

int g_big_cmp(word a, word b) {
 uint32_t sa[2], sb[2]; uint32_t const *la, *lb; bool na, nb;
 int nla = load_int_mag(a, sa, &la, &na), nlb = load_int_mag(b, sb, &lb, &nb);
 bool aneg = na && nla > 0, bneg = nb && nlb > 0;   // zero is non-negative
 if (aneg != bneg) return aneg ? -1 : 1;
 int c = mag_cmp(la, nla, lb, nlb);
 return aneg ? -c : c; }

// Demote a magnitude to the smallest tier. Strip leading zeros; a value in
// fixnum range -> a tagged fixnum; in intptr_t range -> a wide-int box; wider
// -> a fresh bignum. Bumps *hp for the box/bignum cases. The single sink that
// keeps the tiers disjoint, so eqv / table keys stay well defined.
word g_big_canon(g_word **hp, uint32_t const *limb, int n, bool neg) {
 while (n > 0 && limb[n-1] == 0) n--;
 if (n == 0) return nil;
 int const wlimbs = WBITS / 32;                 // 2 on 64-bit, 1 on 32-bit ports
 if (n <= wlimbs) {
  uintptr_t u = limb[0];
  if (wlimbs == 2 && n == 2) u |= ((uintptr_t) limb[1] << 16) << 16;
  uintptr_t const fixmag = (uintptr_t) 1 << (WBITS - 2);   // |FIX_MIN|  = 2^(W-2)
  uintptr_t const boxmag = (uintptr_t) 1 << (WBITS - 1);   // |INT_MIN|  = 2^(W-1)
  intptr_t val;
  if (!neg) {
   if (u <= fixmag - 1) return putnum((intptr_t) u);       // FIX_MAX = 2^(W-2)-1
   if (u > boxmag - 1) goto big;                            // > INTPTR_MAX -> bignum
   val = (intptr_t) u; }
  else {
   if (u <= fixmag) return putnum((intptr_t) ((uintptr_t) 0 - u));   // incl FIX_MIN
   if (u > boxmag) goto big;                                          // < INTPTR_MIN -> bignum
   val = (intptr_t) ((uintptr_t) 0 - u); }                            // incl INTPTR_MIN
  struct g_vec *bx = ini_scalar((struct g_vec*) *hp, G_VT_INT);
  *hp += BOX_REQ; box_put(bx->shape, val); return word(bx); }
big:;
 struct g_big *b = ini_big((struct g_big*) *hp, neg ? -n : n);
 for (int i = 0; i < n; i++) b->limb[i] = limb[i];
 *hp += b2w(sizeof(struct g_big) + (size_t) n * sizeof(uint32_t));
 return word(b); }

// --- arithmetic (sign-magnitude over the loaded operands) -------------------

// r = a +/- b (subtract flips b's sign), result magnitude + sign.
static void big_addsub(uint32_t *r, int *rn, bool *rneg,
  uint32_t const *a, int na, bool nega, uint32_t const *b, int nb, bool negb, bool subtract) {
 bool sb = subtract ? !negb : negb;             // effective sign of the b operand
 if (nega == sb) { *rn = mag_add(r, a, na, b, nb); *rneg = nega; }
 else { int c = mag_cmp(a, na, b, nb);
  if (c == 0) { *rn = 0; *rneg = false; }
  else if (c > 0) { *rn = mag_sub(r, a, na, b, nb); *rneg = nega; }
  else { *rn = mag_sub(r, b, nb, a, na); *rneg = sb; } } }

static int big_mul_mag(uint32_t *r, uint32_t const *a, int na, uint32_t const *b, int nb) {
 mag_mul(r, a, na, b, nb);
 int n = na + nb; while (n > 0 && r[n-1] == 0) n--;
 return n; }

// Packed multi-precision lane for + - * / %, reached from the arith slow paths
// when either operand is a bignum or a fixnum/box op overflowed a machine word.
// Operands at f->sp[0..1] are integers (fixnum/box/bignum); a zero divisor is
// screened off by the caller. Computes a (vop) b, leaves the canonical result
// at f->sp[1], pops one operand, and advances f->ip -- so the caller is just
// Pack(f); f = g_big_binop(f, vop); Unpack(f); Continue();  (cf. g_vm_gc).
struct g *g_big_binop(struct g *f, int vop) {
 word a = f->sp[0], b = f->sp[1];
 int na = bigp(a) ? big_nlimbs(a) : 2, nb = bigp(b) ? big_nlimbs(b) : 2;
 int bound = na + nb + 2;                        // result magnitude upper bound
 int work = 4 * (na + nb) + 16;                  // divmod scratch upper bound
 uintptr_t res_area = Width(struct g_big) + b2w((size_t) bound * 4),
           ws_words = b2w((size_t) (bound + work) * 4);
 if (!g_ok(f = g_have(f, res_area + ws_words))) return f;
 a = f->sp[0], b = f->sp[1];                     // re-fetch (g_have may have GC'd)
 uint32_t sa[2], sb[2]; uint32_t const *la, *lb; bool nega, negb;
 int nla = load_int_mag(a, sa, &la, &nega), nlb = load_int_mag(b, sb, &lb, &negb);
 uint32_t *rmag = (uint32_t*) (f->hp + res_area), *scr = rmag + bound;
 int rn = 0; bool rneg = false;
 switch (vop) {
  case VOP_ADD: big_addsub(rmag, &rn, &rneg, la, nla, nega, lb, nlb, negb, false); break;
  case VOP_SUB: big_addsub(rmag, &rn, &rneg, la, nla, nega, lb, nlb, negb, true); break;
  case VOP_MUL: rn = big_mul_mag(rmag, la, nla, lb, nlb); rneg = nega != negb; break;
  default: {                                     // VOP_QUOT / VOP_REM (truncated)
   int c = mag_cmp(la, nla, lb, nlb);
   if (c < 0) {                                  // |a| < |b|: q = 0, r = a
    if (vop == VOP_REM) rn = mag_copy(rmag, la, nla), rneg = nega; }
   else {
    uint32_t *q = scr, *rem = q + (nla - nlb + 1), *un = rem + nlb, *vn = un + (nla + 1);
    mag_divmod(q, rem, la, nla, lb, nlb, un, vn);
    if (vop == VOP_QUOT) {
     int qn = nla - nlb + 1; while (qn > 0 && q[qn-1] == 0) qn--;
     rn = mag_copy(rmag, q, qn), rneg = nega != negb; }
    else {
     int rr = nlb; while (rr > 0 && rem[rr-1] == 0) rr--;
     rn = mag_copy(rmag, rem, rr), rneg = nega; } } } }
 f->sp[1] = g_big_canon(&f->hp, rmag, rn, rneg);
 f->sp++;
 f->ip = (union u*) f->ip + 1;
 return f; }

// --- reader / printer -------------------------------------------------------

// f->sp[0] is a [+-]?[0-9]+ token string; replace it with the canonical value
// (fixnum / box / bignum). Accumulates 9 decimal digits per mul-add pass.
struct g *g_big_read_dec(struct g *f) {
 struct g_str *tok = str(f->sp[0]);
 uintptr_t n = tok->len; char const *s = tok->bytes;
 bool neg = n && s[0] == '-';
 uintptr_t i = (n && (s[0] == '-' || s[0] == '+')) ? 1 : 0, ndig = n - i;
 int cap = (int) (ndig / 9) + 3;                 // upper-bound magnitude limbs
 uintptr_t res_area = Width(struct g_big) + b2w((size_t) cap * 4);
 if (!g_ok(f = g_have(f, res_area + b2w((size_t) cap * 4)))) return f;
 tok = str(f->sp[0]), s = tok->bytes;            // re-fetch post-GC
 uint32_t *mag = (uint32_t*) (f->hp + res_area);
 int m = 0;
 while (i < n) {
  uint32_t chunk = 0, pw = 1; int k = 0;
  for (; i < n && k < 9; i++, k++) chunk = chunk * 10 + (uint32_t) (s[i] - '0'), pw *= 10;
  m = mag_mul_add_small(mag, m, pw, chunk); }
 f->sp[0] = g_big_canon(&f->hp, mag, m, neg);
 return f; }

// f->sp[0] is a bignum; replace it with its base-10 string (with sign). Builds
// the digits into a fresh g_str by repeated divide-by-10 of a heap-local copy
// of the magnitude; no allocation (hence no GC) once the single Have lands, so
// the work buffer and the string stay put through the loop.
struct g *g_big_dec(struct g *f) {
 struct g_big *a = (struct g_big*) f->sp[0];
 intptr_t sl = a->slen; bool neg = sl < 0; int n = (int) (neg ? -sl : sl);
 int cap = n * 10 + 2 + (neg ? 1 : 0);           // upper-bound bytes (1 limb ~ 9.633 digits)
 uintptr_t str_words = str_type_width + b2w((size_t) cap),
           scratch_words = b2w((size_t) n * 4);
 if (!g_ok(f = g_have(f, str_words + scratch_words))) return f;
 a = (struct g_big*) f->sp[0];                   // re-fetch post-GC
 struct g_str *st = (struct g_str*) f->hp;
 uint32_t *work = (uint32_t*) (f->hp + str_words);
 for (int i = 0; i < n; i++) work[i] = a->limb[i];
 char *out = txt(st);                            // bytes area (offset only; st not yet inited)
 int m = n, pos = cap;
 while (m > 0) {
  uint32_t r = mag_divmod_small(work, m, 10);
  while (m > 0 && work[m-1] == 0) m--;
  out[--pos] = (char) ('0' + r); }
 if (pos == cap) out[--pos] = '0';               // (a bignum is never zero; defensive)
 if (neg) out[--pos] = '-';
 int dl = cap - pos;
 for (int i = 0; i < dl; i++) out[i] = out[pos + i];   // shift digits to the front
 ini_str(st, dl);
 f->hp += str_type_width + b2w((size_t) dl);
 f->sp[0] = word(st);
 return f; }
