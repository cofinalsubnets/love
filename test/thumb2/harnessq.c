/* the 64-bit divides and the leading zeros over rt.c, each pair of edges against gcc's own */
typedef unsigned long long u64; typedef long long s64;
u64 div64(u64,u64); u64 rem64(u64,u64); s64 divs64(s64,s64); s64 rems64(s64,s64); int clz64(u64);
u64 __udivdi3(u64,u64); u64 __umoddi3(u64,u64);   /* by name: an unsigned / may be laid inline */

static u64 edge(int i) {
 int b = i / 4;
 u64 p = 1ULL << (b > 63 ? 63 : b);
 switch (i % 4) { case 0: return p; case 1: return p - 1; case 2: return p + 1; default: return p * 0x9e3779b97f4a7c15ULL; } }

int run(void) {
 for (int i = 0; i < 256; i++) {
  u64 a = edge(i);
  if (a && clz64(a) != __builtin_clzll(a)) return 105;
  for (int j = 0; j < 256; j++) {
   u64 d = edge(j);
   if (!d) continue;
   if (__udivdi3(a, d) != a / d) return 106;
   if (__umoddi3(a, d) != a % d) return 107;
   if (div64(a, d) != a / d) return 101;
   if (rem64(a, d) != a % d) return 102;
   if ((s64) a == -0x7fffffffffffffffLL - 1 && d == ~0ULL) continue;
   if (divs64((s64) a, (s64) d) != (s64) a / (s64) d) return 103;
   if (rems64((s64) a, (s64) d) != (s64) a % (s64) d) return 104; } }
 return 9; }
