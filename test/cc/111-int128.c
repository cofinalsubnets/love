/* __int128 / unsigned __int128 (x64, a64, thumb2's family), one check per op: 64x64 widening and 128x128
 * products, carries, compares as values and branches, constant and variable shifts,
 * u128/u64 divide, negation, truth, casts, ++/--, compound assigns, a returned pair.
 * targets without the lane refuse this file. each check adds 1: the exit code is the pass count. */

typedef unsigned __int128 u128;
typedef __int128 s128;

static u128 mk(unsigned long long hi, unsigned long long lo) { return ((u128) hi << 64) | lo; }

int main(void) {
 int ok = 0;
 unsigned long long a = 0xdeadbeefcafebabeULL, b = 0x123456789abcdef1ULL;

 /* widening product: (u128)u64 * u64 is one widening multiply */
 u128 p = (u128) a * b;
 if ((unsigned long long) (p >> 64) == 0xfd5bdeeeb2a01d8ULL) ok++;
 if ((unsigned long long) p == 0xca165e3e6f4690deULL) ok++;

 /* general 128x128 low product (cross terms) */
 u128 m = p * (u128) 3;
 if ((unsigned long long) (m >> 64) == 0x2f8139ccc17e058aULL) ok++;
 if ((unsigned long long) m == 0x5e431abb4dd3b29aULL) ok++;

 /* add/sub carry across the boundary */
 u128 c1 = mk(0, 0xffffffffffffffffULL) + 1;
 if ((unsigned long long) (c1 >> 64) == 1 && (unsigned long long) c1 == 0) ok++;
 u128 c2 = mk(1, 0) - 1;
 if ((unsigned long long) (c2 >> 64) == 0 && (unsigned long long) c2 == 0xffffffffffffffffULL) ok++;
 if (c1 - c2 == 1) ok++;

 /* unsigned compares, value position (0/1 via c128) */
 u128 B = (u128) 1 << 64;
 if (((u128) 5 < B) == 1) ok++;
 if ((p >= B) == 1) ok++;
 if ((B <= p) == 1) ok++;
 if ((B > p - p) == 1) ok++;
 if ((B == mk(1, 0)) == 1) ok++;
 if ((B != mk(1, 1)) == 1) ok++;

 /* signed compares + negation's borrow */
 s128 n = -(s128) 7;
 if (n < 0) ok++;
 if ((long long) n == -7) ok++;
 if (-(-n) == n) ok++;
 if ((s128) B > n) ok++;
 s128 nb = -(s128) B;                            /* borrow rides the halves */
 if ((long long) (nb >> 64) == -1 && (unsigned long long) nb == 0) ok++;

 /* branch position (cbranch's wide arms), both senses, const + general */
 if (p > B) ok++; else ok--;
 if (B < (u128) 5) ok--; else ok++;
 if (n < 1) ok++; else ok--;
 u128 q9 = B;
 while (q9 >= B) { q9 = q9 - 1; break; } if (q9 == B - 1) ok++;

 /* constant shifts: below, at, and past 64 -- both directions, sar's flood */
 if (((u128) a << 13 >> 13) == a) ok++;
 if ((B >> 64) == 1) ok++;
 if ((mk(0x8000000000000000ULL, 0) >> 100) == (0x8000000000000000ULL >> 36)) ok++;
 if (((u128) 1 << 100 >> 36) == B) ok++;
 if (((s128) nb >> 64) == -1) ok++;
 if (((s128) nb >> 127) == -1) ok++;

 /* variable shifts: the v-forms */
 int sh = 13;
 u128 v = ((u128) a << sh) | ((u128) b >> (64 - sh));
 if ((unsigned long long) (v >> 64) == 0x1bd5ULL) ok++;
 if ((unsigned long long) v == 0xb7ddf95fd757c246ULL) ok++;
 sh = 64; if ((mk(0, a) << sh) == mk(a, 0)) ok++;
 sh = 99; if ((mk(a, 0) >> sh) == (u128) (a >> 35)) ok++;

 /* logicals, pairwise */
 if (((p & B) != 0) == 0) ok++;
 if (((p | B) >> 64) == (p >> 64 | 1)) ok++;
 if ((p ^ p) == 0) ok++;
 if ((~p & p) == 0) ok++;

 /* truth off either half */
 if (mk(1, 0)) ok++;
 if (mk(0, 1)) ok++;
 if (!mk(0, 0)) ok++;

 /* the two-step divide: u128 / u64 and %, checked by the division algebra */
 u128 num = mk(3, 0x8000000000000001ULL);
 u128 qq = num / 7, rr = num % 7;
 if (qq * 7 + rr == num) ok++;
 if (rr < 7) ok++;
 if (qq > B) ok++;                                /* the quotient really is wide */
 if ((mk(0, 90) / 9) == 10 && (mk(0, 90) % 9) == 0) ok++;

 /* wide ++/-- : old answers, the slot steps */
 u128 pd = B;
 pd--; if (pd == B - 1) ok++;
 pd++; if (pd == B) ok++;

 /* compound assigns ride the binop lanes */
 pd += 5; if (pd == B + 5) ok++;
 pd -= 5; if (pd == B) ok++;
 pd >>= 4; pd <<= 4; if (pd == B) ok++;

 /* casts: truncation keeps the lo, widening keeps the sign */
 if ((unsigned long long) mk(9, 42) == 42) ok++;
 if ((unsigned int) mk(9, 0x100000007ULL) == 7) ok++;
 if ((s128) (long long) -3 == -(s128) 3) ok++;
 if ((u128) (unsigned long long) a == (u128) a) ok++;

 /* the folded constant double: 2^64 exactly */
 if ((double) ((u128) 1 << 64) == 18446744073709551616.0) ok++;

 /* a function returning the pair */
 if (mk(a, b) == (((u128) a << 64) | b)) ok++;

 /* sizeof */
 if (sizeof (u128) == 16 && sizeof (s128) == 16) ok++;

 /* gcc's typedef names for the pair, the spelling the kernel's types.h uses */
 { __uint128_t x = a; __int128_t y = -1;
   if (x == (u128) a && y < 0 && sizeof x == 16 && sizeof y == 16) ok++; }

 return ok; }
