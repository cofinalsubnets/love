/* the other compiler's half of the wide-integer ABI check (clang on a64, gcc on x64,
 * freestanding): __int128 in and out -- AAPCS64's even register pair, its 16-aligned stack
 * pair that closes the registers; SysV's two registers -- and calls back into mooncc's half */
typedef unsigned __int128 u128;
#define W(h, l) (((u128)(h) << 64) | (unsigned long)(l))

u128 peer_w(u128 a, long k) { return a + (u128)k * 3; }
u128 peer_wodd(long k, u128 a) { return (a << 4) + k; }
long peer_whi(long k, u128 a, u128 b) { return (long)(a >> 64) * 7 + (long)b + k; }
extern u128 host_w(long k, u128 a);
extern long host_wsum(long k, u128 a, u128 b);
u128 peer_calls_w(void) { return host_w(5, W(1, 2)); }
long peer_calls_wsum(void) { return host_wsum(3, W(4, 5), W(6, 7)); }
#ifdef __aarch64__
long peer_wdeep(long r0, long r1, long r2, long r3, long r4, long r5, long r6, u128 a, long h)
{ return r0 + r6 + (long)(a >> 64) * 10 + (long)a + h * 100; }
long peer_wgap(long r0, long r1, long r2, long r3, long r4, long r5, long r6, long r7, long s0, u128 a, long s1)
{ return r7 + s0 * 10 + (long)(a >> 64) * 100 + (long)a * 1000 + s1 * 10000; }
extern long host_wdeep(long r0, long r1, long r2, long r3, long r4, long r5, long r6, u128 a, long h);
long peer_calls_wdeep(void) { return host_wdeep(1, 2, 3, 4, 5, 6, 7, W(8, 9), 10); }
#endif
