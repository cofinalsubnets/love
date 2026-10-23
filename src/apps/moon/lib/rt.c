/* the compiler runtime: helpers mooncc calls where the target lacks the instruction (v6-M, soft f64).
 * doubles and floats travel as bit patterns in core registers (the aeabi soft-float abi), and no
 * code here may use an operation that lowers back into this file: integer-only, 32-bit halves */
#include <stdint.h>

#define MANT 0x000fffffffffffffull       /* the 52 stored significand bits */
#define HID  0x0010000000000000ull       /* the hidden bit above them */
#define SGNB 0x8000000000000000ull
#define DINF 0x7ff0000000000000ull
#define DNAN 0x7ff8000000000000ull
#define DSGN(u) ((uint32_t) ((u) >> 63))
#define DEXP(u) ((int32_t) (((u) >> 52) & 0x7ff))

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

/* 0 answers the width, so clz64 takes one branch */
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

/* restoring, normalized first; a zero divisor answers all-ones */
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

/* m is the significand over 3 guard bits (normalized at bit 55), value m * 2^(e-1078):
 * denormalize, round to nearest-even on the guard bits, encode */
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

uint64_t __dadd_any(uint64_t ua, uint64_t ub) {
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

uint64_t __dmul_any(uint64_t ua, uint64_t ub) {
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

uint64_t __aeabi_dadd(uint64_t ua, uint64_t ub);
uint64_t __aeabi_dsub(uint64_t ua, uint64_t ub);
uint64_t __aeabi_dmul(uint64_t ua, uint64_t ub);

#if defined(__arm__) && !defined(__ARM_ARCH_6M__)
/* v7-M: two normals whose sum stays normal, in 32-bit words: significands at bit 62, ten guard
 * bits, the larger magnitude in r1:r0 and its exponent in r4; anything else goes to __dadd_any
 * with the arguments as they came */
asm(".text\n"
    ".globl __aeabi_dsub\n.type __aeabi_dsub, %function\n.thumb_func\n"
    "__aeabi_dsub:\n"
    "eor r3, r3, #0x80000000\n"                     /* on into dadd */
    ".globl __aeabi_dadd\n.type __aeabi_dadd, %function\n.thumb_func\n"
    "__aeabi_dadd:\n"
    "push {r0-r7, lr}\n"
    "movw r12, #0x7fe\n"
    "ubfx r4, r1, #20, #11\n"
    "ubfx r5, r3, #20, #11\n"
    "sub r6, r4, #1\n"
    "cmp r6, r12\n"
    "bhs 15f\n"
    "sub r6, r5, #1\n"
    "cmp r6, r12\n"
    "bhs 16f\n"
    "bic r6, r1, #0x80000000\n"
    "bic r7, r3, #0x80000000\n"
    "cmp r6, r7\n"
    "bhi 2f\n"
    "bne 1f\n"
    "cmp r0, r2\n"
    "bhs 2f\n"
    "1:\n"                                          /* swap */
    "mov r6, r1\nmov r1, r3\nmov r3, r6\n"
    "mov r6, r0\nmov r0, r2\nmov r2, r6\n"
    "mov r6, r4\nmov r4, r5\nmov r5, r6\n"
    "2:\n"
    "and r6, r1, #0x80000000\n"
    "eor r7, r1, r3\n"
    "orr r7, r6, r7, lsr #31\n"                     /* the sign, and bit 0 set for a subtract */
    "lsl r1, r1, #11\norr r1, r1, r0, lsr #21\norr r1, r1, #0x80000000\nlsr r1, r1, #1\nlsl r0, r0, #10\n"
    "lsl r3, r3, #11\norr r3, r3, r2, lsr #21\norr r3, r3, #0x80000000\nlsr r3, r3, #1\nlsl r2, r2, #10\n"
    "sub r5, r4, r5\n"                              /* the distance; a register shift by 32 is 0 */
    "cmp r5, #32\n"
    "bhs 3f\n"
    "rsb r6, r5, #32\n"
    "lsl lr, r2, r6\n"
    "lsr r2, r2, r5\n"
    "lsl r6, r3, r6\n"
    "orr r2, r2, r6\n"
    "lsr r3, r3, r5\n"
    "b 4f\n"
    "3:\n"
    "cmp r5, #64\n"
    "bhs 5f\n"
    "sub r5, r5, #32\n"
    "rsb r6, r5, #32\n"
    "lsl lr, r3, r6\n"
    "orr lr, lr, r2\n"
    "lsr r2, r3, r5\n"
    "mov r3, #0\n"
    "4:\n"
    "cmp lr, #0\n"                                  /* what shifted out is sticky */
    "beq 6f\n"
    "orr r2, r2, #1\n"
    "b 6f\n"
    "5:\n"                                          /* all of it sticky */
    "mov r2, #1\n"
    "mov r3, #0\n"
    "6:\n"
    "tst r7, #1\n"
    "bne 7f\n"
    "adds r0, r0, r2\n"
    "adc r1, r1, r3\n"
    "cmp r1, #0\n"
    "bge 10f\n"
    "and r6, r0, #1\n"                              /* a carry onto bit 63: back one */
    "orr r0, r6, r0, lsr #1\n"
    "orr r0, r0, r1, lsl #31\n"
    "lsr r1, r1, #1\n"
    "add r4, r4, #1\n"
    "b 10f\n"
    "7:\n"
    "subs r0, r0, r2\n"
    "sbc r1, r1, r3\n"
    "orrs r6, r0, r1\n"
    "beq 13f\n"
    "clz r6, r1\n"                                  /* the top onto bit 62 */
    "cmp r1, #0\n"
    "bne 8f\n"
    "clz r6, r0\n"
    "add r6, r6, #32\n"
    "8:\n"
    "sub r6, r6, #1\n"
    "sub r4, r4, r6\n"
    "cmp r6, #32\n"
    "bhs 11f\n"
    "rsb r5, r6, #32\n"
    "lsl r1, r1, r6\n"
    "lsr r5, r0, r5\n"
    "orr r1, r1, r5\n"
    "lsl r0, r0, r6\n"
    "b 10f\n"
    "11:\n"
    "sub r5, r6, #32\n"
    "lsl r1, r0, r5\n"
    "mov r0, #0\n"
    "10:\n"                                         /* round to nearest-even on the ten guard bits */
    "ubfx r6, r0, #0, #10\n"
    "lsr r0, r0, #10\n"
    "orr r0, r0, r1, lsl #22\n"
    "lsr r1, r1, #10\n"
    "cmp r6, #0x200\n"
    "bhi 12f\n"
    "bne 14f\n"
    "tst r0, #1\n"
    "beq 14f\n"
    "12:\n"
    "adds r0, r0, #1\n"
    "bcc 14f\n"
    "add r1, r1, #1\n"
    "cmp r1, #0x200000\n"                           /* only 2^53 carries out: its low word is 0 */
    "bne 14f\n"
    "lsr r1, r1, #1\n"
    "add r4, r4, #1\n"
    "14:\n"
    "sub r6, r4, #1\n"
    "cmp r6, r12\n"
    "bhs 9f\n"
    "bic r1, r1, #0x100000\n"
    "orr r1, r1, r4, lsl #20\n"
    "and r7, r7, #0x80000000\n"
    "orr r1, r1, r7\n"
    "add sp, sp, #16\n"
    "pop {r4-r7, pc}\n"
    "13:\n"
    "mov r0, #0\n"
    "mov r1, #0\n"
    "add sp, sp, #16\n"
    "pop {r4-r7, pc}\n"
    "15:\n"                                         /* a zero and a normal answers the normal */
    "orrs r6, r0, r1, lsl #1\n"
    "bne 9f\n"
    "sub r6, r5, #1\n"
    "cmp r6, r12\n"
    "bhs 9f\n"
    "mov r0, r2\n"
    "mov r1, r3\n"
    "add sp, sp, #16\n"
    "pop {r4-r7, pc}\n"
    "16:\n"
    "orrs r6, r2, r3, lsl #1\n"
    "bne 9f\n"
    "add sp, sp, #16\n"
    "pop {r4-r7, pc}\n"
    "9:\n"
    "pop {r0-r7, lr}\n"
    "b __dadd_any\n");

/* v7-M: two normals whose product stays normal, over umull/umlal: x = 1:mant << 11 in r6:r0, y in
 * r7:r2, the product's top 64 bits in r2:r5 and its low 64, sticky, in r1 */
asm(".text\n"
    ".globl __aeabi_dmul\n.type __aeabi_dmul, %function\n.thumb_func\n"
    "__aeabi_dmul:\n"
    "push {r0-r7, lr}\n"
    "movw r12, #0x7fe\n"
    "ubfx r4, r1, #20, #11\n"
    "ubfx r5, r3, #20, #11\n"
    "sub r6, r4, #1\n"
    "cmp r6, r12\n"
    "bhs 5f\n"
    "sub r6, r5, #1\n"
    "cmp r6, r12\n"
    "bhs 6f\n"
    "eor lr, r1, r3\n"                              /* the sign in bit 31 */
    "add r4, r4, r5\n"
    "lsl r6, r1, #11\norr r6, r6, r0, lsr #21\norr r6, r6, #0x80000000\nlsl r0, r0, #11\n"
    "lsl r7, r3, #11\norr r7, r7, r2, lsr #21\norr r7, r7, #0x80000000\nlsl r2, r2, #11\n"
    "umull r1, r3, r0, r2\n"
    "mov r5, #0\n"
    "umlal r3, r5, r0, r7\n"
    "umull r0, r2, r6, r2\n"
    "adds r3, r3, r0\n"
    "adcs r5, r5, r2\n"
    "mov r2, #0\n"
    "adc r2, r2, r2\n"
    "umlal r5, r2, r6, r7\n"
    "orr r1, r1, r3\n"
    "subw r4, r4, #1023\n"
    "cmp r2, #0\n"                                  /* the top onto bit 63 */
    "blt 1f\n"
    "adds r5, r5, r5\n"
    "adc r2, r2, r2\n"
    "b 2f\n"
    "1:\n"
    "add r4, r4, #1\n"
    "2:\n"
    "ubfx r3, r5, #0, #11\n"
    "lsr r5, r5, #11\n"
    "orr r5, r5, r2, lsl #21\n"
    "lsr r2, r2, #11\n"
    "cmp r3, #0x400\n"
    "bhi 3f\n"
    "bne 4f\n"
    "and r3, r5, #1\n"
    "orrs r3, r3, r1\n"
    "beq 4f\n"
    "3:\n"
    "adds r5, r5, #1\n"
    "bcc 4f\n"
    "add r2, r2, #1\n"
    "cmp r2, #0x200000\n"
    "bne 4f\n"
    "lsr r2, r2, #1\n"
    "add r4, r4, #1\n"
    "4:\n"
    "sub r3, r4, #1\n"
    "cmp r3, r12\n"
    "bhs 9f\n"
    "bic r2, r2, #0x100000\n"
    "orr r1, r2, r4, lsl #20\n"
    "and lr, lr, #0x80000000\n"
    "orr r1, r1, lr\n"
    "mov r0, r5\n"
    "add sp, sp, #16\n"
    "pop {r4-r7, pc}\n"
    "5:\n"                                          /* a zero by a normal is a signed zero */
    "orrs r6, r0, r1, lsl #1\n"
    "bne 9f\n"
    "sub r6, r5, #1\n"
    "cmp r6, r12\n"
    "bhs 9f\n"
    "b 7f\n"
    "6:\n"
    "orrs r6, r2, r3, lsl #1\n"
    "bne 9f\n"
    "7:\n"
    "eor r1, r1, r3\n"
    "and r1, r1, #0x80000000\n"
    "mov r0, #0\n"
    "add sp, sp, #16\n"
    "pop {r4-r7, pc}\n"
    "9:\n"
    "pop {r0-r7, lr}\n"
    "b __dmul_any\n");
#else
uint64_t __aeabi_dadd(uint64_t ua, uint64_t ub) { return __dadd_any(ua, ub); }
uint64_t __aeabi_dsub(uint64_t ua, uint64_t ub) { return __dadd_any(ua, ub ^ SGNB); }
uint64_t __aeabi_dmul(uint64_t ua, uint64_t ub) { return __dmul_any(ua, ub); }
#endif

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

#if !defined(__arm__) || defined(__ARM_ARCH_6M__)
/* -1, 0, 1 by value, 2 unordered; in 32-bit words, both zeros equal */
static int32_t dord(uint64_t ua, uint64_t ub) {
 uint32_t ah = (uint32_t) (ua >> 32), al = (uint32_t) ua, bh = (uint32_t) (ub >> 32), bl = (uint32_t) ub;
 uint32_t am = ah & 0x7fffffff, bm = bh & 0x7fffffff;
 int32_t c;
 if (am > 0x7ff00000 || (am == 0x7ff00000 && al) || bm > 0x7ff00000 || (bm == 0x7ff00000 && bl)) return 2;
 if ((am | bm | al | bl) == 0) return 0;
 if ((ah ^ bh) >> 31) return ah >> 31 ? -1 : 1;
 c = am != bm ? (am < bm ? -1 : 1) : al != bl ? (al < bl ? -1 : 1) : 0;
 return ah >> 31 ? -c : c; }
#endif

#if defined(__arm__) && !defined(__ARM_ARCH_6M__)
int32_t __aeabi_dcmpeq(uint64_t a, uint64_t b);
int32_t __aeabi_dcmplt(uint64_t a, uint64_t b);
int32_t __aeabi_dcmple(uint64_t a, uint64_t b);
int32_t __aeabi_dcmpge(uint64_t a, uint64_t b);
int32_t __aeabi_dcmpgt(uint64_t a, uint64_t b);
int32_t __aeabi_dcmpun(uint64_t a, uint64_t b);
/* v7-M: dord's order as k = ord + 1 in r6; each entry's r12 holds the k it answers 1 for, a bit each */
asm(".text\n"
    ".globl __aeabi_dcmpeq\n.type __aeabi_dcmpeq, %function\n.thumb_func\n"
    "__aeabi_dcmpeq:\nmov r12, #2\nb 1f\n"
    ".globl __aeabi_dcmplt\n.type __aeabi_dcmplt, %function\n.thumb_func\n"
    "__aeabi_dcmplt:\nmov r12, #1\nb 1f\n"
    ".globl __aeabi_dcmple\n.type __aeabi_dcmple, %function\n.thumb_func\n"
    "__aeabi_dcmple:\nmov r12, #3\nb 1f\n"
    ".globl __aeabi_dcmpge\n.type __aeabi_dcmpge, %function\n.thumb_func\n"
    "__aeabi_dcmpge:\nmov r12, #6\nb 1f\n"
    ".globl __aeabi_dcmpgt\n.type __aeabi_dcmpgt, %function\n.thumb_func\n"
    "__aeabi_dcmpgt:\nmov r12, #4\nb 1f\n"
    ".globl __aeabi_dcmpun\n.type __aeabi_dcmpun, %function\n.thumb_func\n"
    "__aeabi_dcmpun:\nmov r12, #8\n"
    "1:\n"
    "push {r4-r6}\n"
    "bic r4, r1, #0x80000000\n"
    "bic r5, r3, #0x80000000\n"
    "cmn r4, #0x100000\n"                           /* an exponent of all ones: inf or nan */
    "bmi 6f\n"
    "2:\n"
    "cmn r5, #0x100000\n"
    "bmi 7f\n"
    "3:\n"
    "orr r6, r4, r5\n"
    "orr r6, r6, r0\n"
    "orrs r6, r6, r2\n"
    "beq 10f\n"                                     /* both zeros are equal */
    "eor r6, r1, r3\n"
    "cmp r6, #0\n"
    "blt 4f\n"
    "cmp r4, r5\n"
    "bne 5f\n"
    "cmp r0, r2\n"
    "beq 10f\n"
    "5:\n"
    "bhi 4f\n"
    "eor r1, r1, #0x80000000\n"                     /* the smaller magnitude reads the other sign */
    "4:\n"
    "asr r6, r1, #31\n"                             /* a's sign: -1 -> 0, 1 -> 2 */
    "add r6, r6, #1\n"
    "lsl r6, r6, #1\n"
    "b 11f\n"
    "10:\n"
    "mov r6, #1\n"
    "b 11f\n"
    "12:\n"
    "mov r6, #3\n"
    "11:\n"
    "lsr r0, r12, r6\n"
    "and r0, r0, #1\n"
    "pop {r4-r6}\n"
    "bx lr\n"
    "6:\n"
    "orrs r6, r0, r1, lsl #12\n"
    "bne 12b\n"
    "b 2b\n"
    "7:\n"
    "orrs r6, r2, r3, lsl #12\n"
    "bne 12b\n"
    "b 3b\n");
#else
int32_t __aeabi_dcmpeq(uint64_t a, uint64_t b) { return dord(a, b) == 0; }
int32_t __aeabi_dcmplt(uint64_t a, uint64_t b) { return dord(a, b) == -1; }
int32_t __aeabi_dcmple(uint64_t a, uint64_t b) { return (uint32_t) (dord(a, b) + 1) <= 1; }
int32_t __aeabi_dcmpge(uint64_t a, uint64_t b) { return (uint32_t) dord(a, b) <= 1; }
int32_t __aeabi_dcmpgt(uint64_t a, uint64_t b) { return dord(a, b) == 1; }
int32_t __aeabi_dcmpun(uint64_t a, uint64_t b) { return dord(a, b) == 2; }
#endif

static uint64_t u64tod(uint32_t s, uint64_t v) {
 int32_t sh;
 if (v == 0) return (uint64_t) s << 63;
 sh = clz64(v) - 8;
 if (sh >= 0) return pack(s, 1078 - sh, sl64(v, sh));
 return pack(s, 1078 - sh, stick(v, -sh)); }

#if defined(__arm__) && !defined(__ARM_ARCH_6M__)
uint64_t __aeabi_i2d(int32_t x);
uint64_t __aeabi_ui2d(uint32_t x);
/* v7-M: a word is exact in a double: the sign in r2, the magnitude left-aligned past its top bit */
asm(".text\n"
    ".globl __aeabi_ui2d\n.type __aeabi_ui2d, %function\n.thumb_func\n"
    "__aeabi_ui2d:\n"
    "mov r2, #0\n"
    "b 1f\n"
    ".globl __aeabi_i2d\n.type __aeabi_i2d, %function\n.thumb_func\n"
    "__aeabi_i2d:\n"
    "and r2, r0, #0x80000000\n"
    "cmp r0, #0\n"
    "bge 1f\n"
    "rsb r0, r0, #0\n"
    "1:\n"
    "cmp r0, #0\n"
    "beq 2f\n"
    "clz r3, r0\n"
    "lsl r0, r0, r3\n"
    "lsl r0, r0, #1\n"                              /* the hidden bit shifted out */
    "movw r12, #1054\n"
    "sub r3, r12, r3\n"
    "orr r1, r2, r3, lsl #20\n"
    "orr r1, r1, r0, lsr #12\n"
    "lsl r0, r0, #20\n"
    "bx lr\n"
    "2:\n"
    "mov r1, #0\n"
    "bx lr\n");
#else
uint64_t __aeabi_i2d(int32_t x)   { return x < 0 ? u64tod(1, (uint64_t) -(int64_t) x) : u64tod(0, (uint64_t) x); }
uint64_t __aeabi_ui2d(uint32_t x) { return u64tod(0, x); }
#endif
uint64_t __aeabi_l2d(int64_t x)   { return x < 0 ? u64tod(1, -(uint64_t) x) : u64tod(0, (uint64_t) x); }
uint64_t __aeabi_ul2d(uint64_t x) { return u64tod(0, x); }

/* toward zero, as a magnitude; out of range saturates */
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
/* below one, or in a word's range, from the high word and the top of the low; past it d2lz's low word */
#if defined(__arm__) && !defined(__ARM_ARCH_6M__)
int32_t __aeabi_d2iz(uint64_t u);
uint32_t __aeabi_d2uiz(uint64_t u);
asm(".text\n"
    ".globl __aeabi_d2iz\n.type __aeabi_d2iz, %function\n.thumb_func\n"
    "__aeabi_d2iz:\n"
    "ubfx r2, r1, #20, #11\n"
    "subw r2, r2, #1023\n"
    "cmp r2, #0\n"
    "blt 2f\n"
    "cmp r2, #31\n"
    "bge 1f\n"
    "lsl r3, r1, #11\n"
    "orr r3, r3, r0, lsr #21\n"
    "orr r3, r3, #0x80000000\n"
    "rsb r2, r2, #31\n"
    "lsr r0, r3, r2\n"
    "cmp r1, #0\n"
    "bge 3f\n"
    "rsb r0, r0, #0\n"
    "3:\n"
    "bx lr\n"
    "2:\n"
    "mov r0, #0\n"
    "bx lr\n"
    "1:\n"
    "b __aeabi_d2lz\n"
    ".globl __aeabi_d2uiz\n.type __aeabi_d2uiz, %function\n.thumb_func\n"
    "__aeabi_d2uiz:\n"
    "cmp r1, #0\n"
    "blt 2f\n"
    "ubfx r2, r1, #20, #11\n"
    "subw r2, r2, #1023\n"
    "cmp r2, #0\n"
    "blt 2f\n"
    "cmp r2, #32\n"
    "bge 1f\n"
    "lsl r3, r1, #11\n"
    "orr r3, r3, r0, lsr #21\n"
    "orr r3, r3, #0x80000000\n"
    "rsb r2, r2, #31\n"
    "lsr r0, r3, r2\n"
    "bx lr\n"
    "2:\n"
    "mov r0, #0\n"
    "bx lr\n"
    "1:\n"
    "b __aeabi_d2ulz\n");
#else
int32_t __aeabi_d2iz(uint64_t u) {
 uint32_t h = (uint32_t) (u >> 32), k = ((h >> 20) & 0x7ff) - 1023, v;
 if ((int32_t) k < 0) return 0;
 if (k < 31) {
   v = (h << 11 | (uint32_t) u >> 21 | 0x80000000u) >> (31 - k);
   return h >> 31 ? -(int32_t) v : (int32_t) v; }
 return (int32_t) __aeabi_d2lz(u); }
uint32_t __aeabi_d2uiz(uint64_t u) {
 uint32_t h = (uint32_t) (u >> 32), k = ((h >> 20) & 0x7ff) - 1023;
 if (h >> 31 || (int32_t) k < 0) return 0;
 if (k < 32) return (h << 11 | (uint32_t) u >> 21 | 0x80000000u) >> (31 - k);
 return (uint32_t) __aeabi_d2ulz(u); }
#endif

uint64_t __aeabi_f2d(uint32_t u) {
 if (((u >> 23) & 0xff) - 1 < 0xfe)              /* a normal: the fields widen in place */
   return ((uint64_t) ((u & 0x80000000u) | (((u >> 23) & 0xff) + 896) << 20 | (u & 0x7fffff) >> 3) << 32) | u << 29;
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

/* binary32 through binary64: one rounding to 24 bits is the correctly rounded single */
uint32_t __aeabi_fadd(uint32_t a, uint32_t b) { return __aeabi_d2f(__aeabi_dadd(__aeabi_f2d(a), __aeabi_f2d(b))); }
uint32_t __aeabi_fsub(uint32_t a, uint32_t b) { return __aeabi_d2f(__aeabi_dsub(__aeabi_f2d(a), __aeabi_f2d(b))); }
uint32_t __aeabi_fmul(uint32_t a, uint32_t b) { return __aeabi_d2f(__aeabi_dmul(__aeabi_f2d(a), __aeabi_f2d(b))); }
uint32_t __aeabi_fdiv(uint32_t a, uint32_t b) { return __aeabi_d2f(__aeabi_ddiv(__aeabi_f2d(a), __aeabi_f2d(b))); }
uint32_t __aeabi_i2f(int32_t x)   { return __aeabi_d2f(__aeabi_i2d(x)); }
uint32_t __aeabi_ui2f(uint32_t x) { return __aeabi_d2f(__aeabi_ui2d(x)); }
int32_t __aeabi_f2iz(uint32_t u)   { return __aeabi_d2iz(__aeabi_f2d(u)); }
uint32_t __aeabi_f2uiz(uint32_t u) { return __aeabi_d2uiz(__aeabi_f2d(u)); }
/* a 64-bit integer rounds once: past 31 significant bits the rest fold into a sticky bit,
 * which binary64 holds exactly and binary32 rounds as it would the whole */
static uint32_t u64tof(uint32_t s, uint64_t v) {
 int32_t sh = 33 - clz64(v);
 if (sh > 0) v = sl64(stick(v, sh), sh);
 return __aeabi_d2f(u64tod(s, v)); }
uint32_t __aeabi_l2f(int64_t x)   { return x < 0 ? u64tof(1, -(uint64_t) x) : u64tof(0, (uint64_t) x); }
uint32_t __aeabi_ul2f(uint64_t x) { return u64tof(0, x); }
int32_t __aeabi_fcmpeq(uint32_t a, uint32_t b) { return __aeabi_dcmpeq(__aeabi_f2d(a), __aeabi_f2d(b)); }
int32_t __aeabi_fcmplt(uint32_t a, uint32_t b) { return __aeabi_dcmplt(__aeabi_f2d(a), __aeabi_f2d(b)); }
int32_t __aeabi_fcmple(uint32_t a, uint32_t b) { return __aeabi_dcmple(__aeabi_f2d(a), __aeabi_f2d(b)); }
int32_t __aeabi_fcmpge(uint32_t a, uint32_t b) { return __aeabi_dcmpge(__aeabi_f2d(a), __aeabi_f2d(b)); }
int32_t __aeabi_fcmpgt(uint32_t a, uint32_t b) { return __aeabi_dcmpgt(__aeabi_f2d(a), __aeabi_f2d(b)); }
int32_t __aeabi_fcmpun(uint32_t a, uint32_t b) { return __aeabi_dcmpun(__aeabi_f2d(a), __aeabi_f2d(b)); }

/* 128-bit ops on a 32-bit target: the right operand in r0-r3, the left the caller's 16-byte
 * cell, laid as this call's stack arguments; the answer goes back into that cell */
void __moon_m128(uint64_t rlo, uint64_t rhi, uint64_t llo, uint64_t lhi) {
  uint64_t volatile *c = &llo;
  uint64_t hi, lo;
  mul64(llo, rlo, &hi, &lo);
  c[0] = lo;
  c[1] = hi + llo * rhi + lhi * rlo; }

/* the cell's u128 by the u64 divisor in the right's low half, a bit at a time below the high
 * word's own divide: the quotient, or the remainder (its high half 0) */
static void dv128(uint64_t d, uint64_t lo, uint64_t hi, uint64_t volatile *c, int32_t rem) {
  uint64_t r, qh = udivmod64(hi, d, &r), ql = 0;
  for (int32_t i = 63; i >= 0; i--) {
    uint64_t top = r >> 63;
    r = r << 1 | (sr64(lo, i) & 1);
    if (top || r >= d) r -= d, ql |= sl64(1, i); }
  if (rem) c[0] = r, c[1] = 0;
  else c[0] = ql, c[1] = qh; }
void __moon_dv128(uint64_t d, uint64_t x, uint64_t lo, uint64_t hi) { (void) x; dv128(d, lo, hi, &lo, 0); }
void __moon_rm128(uint64_t d, uint64_t x, uint64_t lo, uint64_t hi) { (void) x; dv128(d, lo, hi, &lo, 1); }
