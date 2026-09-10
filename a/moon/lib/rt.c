/* a/moon/lib/rt.c -- the compiler runtime: the calls mooncc's own lowering makes where
 * the machine has no instruction for the operation. ARMv6-M (the RP2040's M0+) has no FPU,
 * no umull, no clz and no variable 64-bit shift, so a double, a 64-bit multiply and a
 * leading-zero count all leave as a call; a single-precision FPU (the playdate's M7, the
 * F446's M4) keeps the 64-bit transfers and softens f64 alone. These are the names gen.l
 * emits, and gcc's libgcc answered them until this file did.
 *
 * NO FLOATING-POINT TYPE APPEARS HERE, and that is the point twice over.
 *
 *   The ABI. A helper is called with its operands in the CORE registers -- r0:r1 and r2:r3
 *   for a double, r0 for a float, and the answer back the same way. That is the AEABI's
 *   soft-float convention and it is what gen.l's soften pass stages. It is NOT what a
 *   `double` parameter means to mooncc on a seat with an FPU: thumb2sp passes one in d0/d1
 *   and answers in d0, so a helper spelled `double f(double, double)` there reads the right
 *   operands only by luck and returns in the wrong place. Spelled in uint64_t the two
 *   conventions are the same convention, on every target this file is compiled for.
 *
 *   The recursion. Nothing here may use the operation it implements: a double add inside
 *   __aeabi_dadd, a 64-bit multiply inside __aeabi_lmul, a variable 64-bit shift anywhere --
 *   each is a call back into this file, and the second one does not return. The subtlest is
 *   `float`, which has no arithmetic of its own on these seats and so rides as a double: a
 *   float-typed return narrows through __aeabi_d2f, which is a function in this file.
 *
 * So the kernel is integer-only. Every 64-bit shift goes through sl64/sr64/sa64 and those
 * are written in 32-bit halves, as are the products mul32 composes. Constant-count 64-bit
 * shifts ARE inline on v6-M (gen.l's pshiftc), which is why the halvings and the
 * (uint64_t)hi << 32 rebuilds are free.
 *
 * binary64 throughout, round-to-nearest-even, denormals and NaN in both directions. The
 * gate is test_softfp: every entry here against the hardware's own answer, on a machine
 * that has one.
 *
 * It is not the fastest shape -- a double add pays a call or two to fold its guard bits
 * where libgcc's hand-written v6-M pays none -- and no board here computes in double where
 * that shows. Correctness and one readable file were the trade. */
#include <stdint.h>

#define MANT 0x000fffffffffffffull       /* the 52 stored significand bits */
#define HID  0x0010000000000000ull       /* the hidden bit above them */
#define SGNB 0x8000000000000000ull
#define DINF 0x7ff0000000000000ull
#define DNAN 0x7ff8000000000000ull
#define DSGN(u) ((uint32_t) ((u) >> 63))
#define DEXP(u) ((int32_t) (((u) >> 52) & 0x7ff))

/* ---------------------------------------------------------------- the shifts */
static uint64_t sl64(uint64_t v, int32_t n) {
 uint32_t lo = (uint32_t) v, hi = (uint32_t) (v >> 32);
 if (n >= 32) { hi = n >= 64 ? 0 : lo << (n - 32); lo = 0; }
 else if (n > 0) { hi = (hi << n) | (lo >> (32 - n)); lo <<= n; }
 return ((uint64_t) hi << 32) | lo; }

static uint64_t sr64(uint64_t v, int32_t n) {
 uint32_t lo = (uint32_t) v, hi = (uint32_t) (v >> 32);
 if (n >= 32) { lo = n >= 64 ? 0 : hi >> (n - 32); hi = 0; }
 else if (n > 0) { lo = (lo >> n) | (hi << (32 - n)); hi >>= n; }
 return ((uint64_t) hi << 32) | lo; }

static int64_t sa64(int64_t v, int32_t n) {
 uint32_t lo = (uint32_t) v;
 int32_t hi = (int32_t) ((uint64_t) v >> 32);
 if (n >= 32) { lo = (uint32_t) (hi >> (n >= 63 ? 31 : n - 32)); hi >>= 31; }
 else if (n > 0) { lo = (lo >> n) | ((uint32_t) hi << (32 - n)); hi >>= n; }
 return (int64_t) (((uint64_t) (uint32_t) hi << 32) | lo); }

int64_t __aeabi_llsl(int64_t v, int32_t n) { return (int64_t) sl64((uint64_t) v, n); }
int64_t __aeabi_llsr(int64_t v, int32_t n) { return (int64_t) sr64((uint64_t) v, n); }
int64_t __aeabi_lasr(int64_t v, int32_t n) { return sa64(v, n); }

/* ------------------------------------------------------- leading/trailing zeros */
/* 0 answers the width: gcc leaves it undefined, and a defined answer makes clz64 below
 * one branch rather than two. */
int32_t __clzsi2(uint32_t x) {
 int32_t n = 0;
 if (x == 0) return 32;
 if (!(x & 0xffff0000u)) { n += 16; x <<= 16; }
 if (!(x & 0xff000000u)) { n += 8;  x <<= 8; }
 if (!(x & 0xf0000000u)) { n += 4;  x <<= 4; }
 if (!(x & 0xc0000000u)) { n += 2;  x <<= 2; }
 if (!(x & 0x80000000u)) { n += 1; }
 return n; }

int32_t __ctzsi2(uint32_t x) {
 int32_t n = 0;
 if (x == 0) return 32;
 if (!(x & 0x0000ffffu)) { n += 16; x >>= 16; }
 if (!(x & 0x000000ffu)) { n += 8;  x >>= 8; }
 if (!(x & 0x0000000fu)) { n += 4;  x >>= 4; }
 if (!(x & 0x00000003u)) { n += 2;  x >>= 2; }
 if (!(x & 0x00000001u)) { n += 1; }
 return n; }

static int32_t clz64(uint64_t v) {
 uint32_t hi = (uint32_t) (v >> 32);
 return hi ? __clzsi2(hi) : 32 + __clzsi2((uint32_t) v); }

/* ------------------------------------------------------------ 64-bit multiply */
/* 32x32 -> 64 out of four 16x16 products: v6-M's MULS is 32x32 -> 32 and nothing wider */
static uint64_t mul32(uint32_t a, uint32_t b) {
 uint32_t al = a & 0xffff, ah = a >> 16, bl = b & 0xffff, bh = b >> 16;
 uint32_t p0 = al * bl, t = ah * bl, mid = al * bh + t;
 uint32_t carry = mid < t ? 0x10000u : 0;         /* the mid sum sits at bit 16, its own carry at 48 */
 uint32_t lo = p0 + (mid << 16);
 uint32_t hi = ah * bh + (mid >> 16) + carry + (lo < p0);
 return ((uint64_t) hi << 32) | lo; }

int64_t __aeabi_lmul(int64_t a, int64_t b) {
 uint32_t al = (uint32_t) a, ah = (uint32_t) ((uint64_t) a >> 32);
 uint32_t bl = (uint32_t) b, bh = (uint32_t) ((uint64_t) b >> 32);
 return (int64_t) (mul32(al, bl) + ((uint64_t) (al * bh + ah * bl) << 32)); }

/* the full 128-bit product, for the double multiply */
static void mul64(uint64_t a, uint64_t b, uint64_t *hi, uint64_t *lo) {
 uint32_t al = (uint32_t) a, ah = (uint32_t) (a >> 32);
 uint32_t bl = (uint32_t) b, bh = (uint32_t) (b >> 32);
 uint64_t ll = mul32(al, bl), lh = mul32(al, bh), hl = mul32(ah, bl);
 uint64_t m = (ll >> 32) + (uint32_t) lh + (uint32_t) hl;
 *lo = (m << 32) | (uint32_t) ll;
 *hi = mul32(ah, bh) + (lh >> 32) + (hl >> 32) + (m >> 32); }

/* -------------------------------------------------------------- 64-bit divide */
/* restoring, normalized first so the loop runs only over the quotient's own bits. a zero
 * divisor is undefined upstream; answering all-ones beats faulting inside a helper. */
static uint64_t udivmod64(uint64_t n, uint64_t d, uint64_t *rem) {
 uint64_t q = 0, dd;
 int32_t sh;
 if (d == 0) { if (rem) *rem = 0; return ~(uint64_t) 0; }
 if (n < d) { if (rem) *rem = n; return 0; }
 sh = clz64(d) - clz64(n);
 dd = sl64(d, sh);
 for (; sh >= 0; sh--) {
   q <<= 1;
   if (n >= dd) { n -= dd; q |= 1; }
   dd >>= 1; }
 if (rem) *rem = n;
 return q; }

uint64_t __udivdi3(uint64_t a, uint64_t b) { return udivmod64(a, b, 0); }
uint64_t __umoddi3(uint64_t a, uint64_t b) { uint64_t r; udivmod64(a, b, &r); return r; }

int64_t __divdi3(int64_t a, int64_t b) {
 int32_t neg = (a < 0) != (b < 0);
 uint64_t q = udivmod64(a < 0 ? -(uint64_t) a : (uint64_t) a,
                        b < 0 ? -(uint64_t) b : (uint64_t) b, 0);
 return neg ? -(int64_t) q : (int64_t) q; }

int64_t __moddi3(int64_t a, int64_t b) {
 uint64_t r;
 udivmod64(a < 0 ? -(uint64_t) a : (uint64_t) a,
           b < 0 ? -(uint64_t) b : (uint64_t) b, &r);
 return a < 0 ? -(int64_t) r : (int64_t) r; }

/* ================================================================ binary64 === */
/* every double below is its BIT PATTERN, in and out -- see the head of the file.
 *
 * the shared tail. m carries the 53-bit significand with three guard bits under it, so a
 * normalized one has bit 55 set and the value is m * 2^(e-1078); e is the biased exponent
 * that significand belongs to. Denormalize if e fell off the bottom, round to nearest-even
 * on the guard bits (bit 2 is the half, bits 1..0 the sticky), encode. */
static uint64_t pack(uint32_t s, int32_t e, uint64_t m) {
 uint64_t sb = (uint64_t) s << 63;
 uint32_t r;
 if (e <= 0) {
   int32_t d = 1 - e;
   if (d > 63) m = (m != 0);
   else { uint64_t lost = m & (sl64(1, d) - 1); m = sr64(m, d) | (lost != 0); }
   e = 0; }
 r = (uint32_t) m & 7;
 m >>= 3;
 if (r > 4 || (r == 4 && (m & 1))) m++;
 if (m >> 53) { m >>= 1; e++; }                  /* the round carried out of the top */
 if (m & HID) {                                  /* normal, or a denormal that rounded up to one */
   if (e == 0) e = 1;
   if (e >= 0x7ff) return sb | DINF;
   return sb | ((uint64_t) e << 52) | (m & MANT); }
 return sb | m; }

/* left-align a nonzero significand onto bit 55, paying the exponent */
static void norm55(uint64_t *m, int32_t *e) {
 int32_t sh = clz64(*m) - 8;
 *m = sl64(*m, sh);
 *e -= sh; }

/* shift right by d, folding everything shifted out into the low bit */
static uint64_t stick(uint64_t m, int32_t d) {
 uint64_t lost;
 if (d > 63) return m != 0;
 lost = m & (sl64(1, d) - 1);
 return sr64(m, d) | (lost != 0); }

uint64_t __aeabi_dadd(uint64_t ua, uint64_t ub) {
 uint32_t sa = DSGN(ua), sb = DSGN(ub), ts;
 int32_t ea = DEXP(ua), eb = DEXP(ub), d;
 uint64_t ma = ua & MANT, mb = ub & MANT, m;
 if (ea == 0x7ff) {
   if (ma) return ua | DNAN;
   if (eb == 0x7ff) return mb ? ub | DNAN : sa == sb ? ua : DNAN;
   return ua; }
 if (eb == 0x7ff) return mb ? ub | DNAN : ub;
 if (ea == 0 && ma == 0) {
   if (eb == 0 && mb == 0) return sa == sb ? ua : 0;   /* -0 + -0 is -0, every other pair +0 */
   return ub; }
 if (eb == 0 && mb == 0) return ua;
 if (ea) ma |= HID; else ea = 1;                 /* a denormal's exponent IS 1, its hidden bit clear */
 if (eb) mb |= HID; else eb = 1;
 ma <<= 3; mb <<= 3;
 if (ea < eb || (ea == eb && ma < mb)) {         /* the larger magnitude to the left */
   m = ma; ma = mb; mb = m;
   d = ea; ea = eb; eb = d;
   ts = sa; sa = sb; sb = ts; }
 d = ea - eb;
 if (d) mb = stick(mb, d);
 if (sa == sb) {
   m = ma + mb;
   if (m >> 56) { m = (m >> 1) | (m & 1); ea++; }
   return pack(sa, ea, m); }
 m = ma - mb;
 if (m == 0) return 0;
 norm55(&m, &ea);
 return pack(sa, ea, m); }

uint64_t __aeabi_dsub(uint64_t ua, uint64_t ub) { return __aeabi_dadd(ua, ub ^ SGNB); }

uint64_t __aeabi_dmul(uint64_t ua, uint64_t ub) {
 uint32_t s = DSGN(ua) ^ DSGN(ub);
 int32_t ea = DEXP(ua), eb = DEXP(ub), sh, e;
 uint64_t ma = ua & MANT, mb = ub & MANT, hi, lo, m;
 uint64_t sgn = (uint64_t) s << 63;
 if (ea == 0x7ff) {
   if (ma) return ua | DNAN;
   if (eb == 0x7ff && mb) return ub | DNAN;
   if (eb == 0 && mb == 0) return DNAN;          /* inf * 0 */
   return sgn | DINF; }
 if (eb == 0x7ff) {
   if (mb) return ub | DNAN;
   if (ea == 0 && ma == 0) return DNAN;
   return sgn | DINF; }
 if ((ea == 0 && ma == 0) || (eb == 0 && mb == 0)) return sgn;
 if (ea) ma |= HID; else { sh = clz64(ma) - 11; ma = sl64(ma, sh); ea = 1 - sh; }
 if (eb) mb |= HID; else { sh = clz64(mb) - 11; mb = sl64(mb, sh); eb = 1 - sh; }
 mul64(ma, mb, &hi, &lo);                        /* 105 or 106 bits */
 if (hi >> 41) { e = ea + eb - 1022; m = (hi << 14) | (lo >> 50); m |= (lo << 14) != 0; }
 else          { e = ea + eb - 1023; m = (hi << 15) | (lo >> 49); m |= (lo << 15) != 0; }
 return pack(s, e, m); }

uint64_t __aeabi_ddiv(uint64_t ua, uint64_t ub) {
 uint32_t s = DSGN(ua) ^ DSGN(ub);
 int32_t ea = DEXP(ua), eb = DEXP(ub), sh, e, i;
 uint64_t ma = ua & MANT, mb = ub & MANT, n, q = 0;
 uint64_t sgn = (uint64_t) s << 63;
 if (ea == 0x7ff) {
   if (ma) return ua | DNAN;
   if (eb == 0x7ff) return mb ? ub | DNAN : DNAN;             /* inf / inf */
   return sgn | DINF; }
 if (eb == 0x7ff) return mb ? ub | DNAN : sgn;                /* x / inf is a signed zero */
 if (eb == 0 && mb == 0)
   return (ea == 0 && ma == 0) ? DNAN : sgn | DINF;           /* 0/0, else divide by zero */
 if (ea == 0 && ma == 0) return sgn;
 if (ea) ma |= HID; else { sh = clz64(ma) - 11; ma = sl64(ma, sh); ea = 1 - sh; }
 if (eb) mb |= HID; else { sh = clz64(mb) - 11; mb = sl64(mb, sh); eb = 1 - sh; }
 n = ma;                                         /* 57 restoring steps: q = floor(ma * 2^56 / mb) */
 for (i = 0; i < 57; i++) {
   q <<= 1;
   if (n >= mb) { n -= mb; q |= 1; }
   n <<= 1; }
 q |= (n != 0);
 if (q >> 56) { q = (q >> 1) | (q & 1); e = ea - eb + 1023; }
 else e = ea - eb + 1022;
 return pack(s, e, q); }

/* --------------------------------------------------------------- the compares */
/* both operands to a signed key: sign-magnitude order IS numeric order once the negatives
 * are reflected, and both zeros land on 0. */
static int32_t dord(uint64_t ua, uint64_t ub, int32_t *un) {
 int64_t ka, kb;
 if ((ua & ~SGNB) > DINF || (ub & ~SGNB) > DINF) { *un = 1; return 0; }
 *un = 0;
 ka = (ua >> 63) ? -(int64_t) (ua & ~SGNB) : (int64_t) ua;
 kb = (ub >> 63) ? -(int64_t) (ub & ~SGNB) : (int64_t) ub;
 return ka < kb ? -1 : ka > kb ? 1 : 0; }

int32_t __aeabi_dcmpeq(uint64_t a, uint64_t b) { int32_t u, c = dord(a, b, &u); return !u && c == 0; }
int32_t __aeabi_dcmplt(uint64_t a, uint64_t b) { int32_t u, c = dord(a, b, &u); return !u && c < 0; }
int32_t __aeabi_dcmple(uint64_t a, uint64_t b) { int32_t u, c = dord(a, b, &u); return !u && c <= 0; }
int32_t __aeabi_dcmpge(uint64_t a, uint64_t b) { int32_t u, c = dord(a, b, &u); return !u && c >= 0; }
int32_t __aeabi_dcmpgt(uint64_t a, uint64_t b) { int32_t u, c = dord(a, b, &u); return !u && c > 0; }
int32_t __aeabi_dcmpun(uint64_t a, uint64_t b) { int32_t u; dord(a, b, &u); return u; }

/* ------------------------------------------------------------- int <-> double */
static uint64_t u64tod(uint32_t s, uint64_t v) {
 int32_t sh;
 if (v == 0) return (uint64_t) s << 63;
 sh = clz64(v) - 8;
 if (sh >= 0) return pack(s, 1078 - sh, sl64(v, sh));
 return pack(s, 1078 - sh, stick(v, -sh)); }

uint64_t __aeabi_i2d(int32_t x)   { return x < 0 ? u64tod(1, (uint64_t) -(int64_t) x) : u64tod(0, (uint64_t) x); }
uint64_t __aeabi_ui2d(uint32_t x) { return u64tod(0, x); }
uint64_t __aeabi_l2d(int64_t x)   { return x < 0 ? u64tod(1, -(uint64_t) x) : u64tod(0, (uint64_t) x); }
uint64_t __aeabi_ul2d(uint64_t x) { return u64tod(0, x); }

/* toward zero, as a magnitude. out of range is undefined upstream (gen.l's own non-v6-M
 * lowering shifts to garbage there); saturating is the kinder garbage. */
static uint64_t dtrunc(uint64_t u) {
 int32_t e = DEXP(u);
 uint64_t m = u & MANT;
 if (e == 0) return 0;                            /* zero or denormal: |d| < 1 */
 if (e == 0x7ff) return m ? 0 : ~(uint64_t) 0;    /* a nan answers 0, an inf saturates */
 m |= HID;
 e -= 1075;                                       /* the value is m * 2^e */
 if (e >= 0) return e > 11 ? ~(uint64_t) 0 : sl64(m, e);
 return -e >= 64 ? 0 : sr64(m, -e); }

int64_t __aeabi_d2lz(uint64_t u)   { uint64_t v = dtrunc(u); return DSGN(u) ? -(int64_t) v : (int64_t) v; }
uint64_t __aeabi_d2ulz(uint64_t u) { return DSGN(u) ? 0 : dtrunc(u); }
int32_t __aeabi_d2iz(uint64_t u)   { return (int32_t) __aeabi_d2lz(u); }
uint32_t __aeabi_d2uiz(uint64_t u) { return (uint32_t) __aeabi_d2ulz(u); }

/* ----------------------------------------------------------- float <-> double */
uint64_t __aeabi_f2d(uint32_t u) {
 uint32_t m = u & 0x7fffff;
 int32_t e = (int32_t) ((u >> 23) & 0xff);
 uint64_t s = (uint64_t) (u >> 31) << 63;
 if (e == 0xff) return s | DINF | ((uint64_t) m << 29);   /* an inf, or a nan with its payload */
 if (e == 0) {
   if (m == 0) return s;
   { int32_t sh = __clzsi2(m) - 8; m = (m << sh) & 0x7fffff; e = 1 - sh; } }
 return s | ((uint64_t) (e + 896) << 52) | ((uint64_t) m << 29); }

/* pack's twin at single width: bit 26 is the normalized top */
static uint32_t packf(uint32_t s, int32_t e, uint32_t m) {
 uint32_t r;
 if (e <= 0) {
   int32_t d = 1 - e;
   if (d > 31) m = (m != 0);
   else { uint32_t lost = m & ((1u << d) - 1); m = (m >> d) | (lost != 0); }
   e = 0; }
 r = m & 7;
 m >>= 3;
 if (r > 4 || (r == 4 && (m & 1))) m++;
 if (m >> 24) { m >>= 1; e++; }
 if (m & (1u << 23)) {
   if (e == 0) e = 1;
   if (e >= 0xff) return (s << 31) | 0x7f800000u;
   return (s << 31) | ((uint32_t) e << 23) | (m & 0x7fffff); }
 return (s << 31) | m; }

uint32_t __aeabi_d2f(uint64_t u) {
 uint64_t m = u & MANT;
 uint32_t s = DSGN(u);
 int32_t e = DEXP(u);
 if (e == 0x7ff) {
   uint32_t f = (uint32_t) (m >> 29);            /* a nan whose payload all lived below bit 29 stays one */
   return (s << 31) | 0x7f800000u | f | (m && !f); }
 if (e == 0 && m == 0) return s << 31;
 if (e) m |= HID; else e = 1;
 if (!(m & HID)) { int32_t sh = clz64(m) - 11; m = sl64(m, sh); e -= sh; }
 return packf(s, e - 896, (uint32_t) (m >> 26) | ((m << 38) != 0)); }
