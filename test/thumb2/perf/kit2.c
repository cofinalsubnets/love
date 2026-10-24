/* long long locals in register pairs: loops, ++/--, compound shifts, a pair across a call; run() 0 = all held */
typedef unsigned long long u64; typedef long long s64;
__attribute__((noinline)) u64 id64(u64 x){ return x; }
u64 acc(const unsigned *a, int n){ u64 s = 0; for (int i = 0; i < n; i++) s += a[i]; return s; }
u64 bump(u64 x){ u64 y = x; y++; y++; ++y; y--; return y; }
u64 mix(u64 x, unsigned k){ u64 m = x; m >>= 3; m |= (u64) k << 40; m ^= m >> 7; m <<= 1; return m; }
s64 sgn(int a, int b){ s64 p = (s64) a * b; s64 q = p; q -= 5; return q + p; }
u64 call(u64 x){ u64 keep = x * 3; u64 r = id64(x + 1); return keep + r; }
u64 fold(u64 a, u64 b){ u64 hi = a >> 32, lo = a & 0xffffffffu, t = lo * (b & 0xffff) + hi; while (t >> 33) t >>= 1; return t; }
int run(void){ unsigned a[5] = {4000000000u, 4000000000u, 7, 8, 9};
  if (acc(a, 5) != 8000000024ull) return 1;
  if (bump(0xffffffffull) != 0x100000001ull) return 2;
  { u64 m = 0x123456789abcdefull >> 3; m |= (u64) 5 << 40; m ^= m >> 7; m <<= 1; if (mix(0x123456789abcdefull, 5) != m) return 3; }
  if (sgn(-70000, 80000) != -11200000005ll) return 4;
  if (call(10) != 41) return 5;
  { u64 aa = 0x1234567890ull, bb = 0xabcdef, t = (aa & 0xffffffffu) * (bb & 0xffff) + (aa >> 32); while (t >> 33) t >>= 1; if (fold(aa, bb) != t) return 6; }
  return 0; }
