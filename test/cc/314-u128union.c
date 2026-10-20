/* a 128-bit member initialized in a union lays both halves, as assignment does (the kernel
 * builds a cmpxchg128's halves so: union __u128_halves o = { .full = old }) */
union halves { unsigned __int128 full; struct { unsigned long long low, high; }; };

__attribute__((noinline)) static unsigned long long hi_init(unsigned __int128 v) { union halves o = { .full = v }; return o.high; }
__attribute__((noinline)) static unsigned long long hi_set(unsigned __int128 v) { union halves o; o.full = v; return o.high; }
__attribute__((noinline)) static unsigned long long lo_init(unsigned __int128 v) { union halves o = { .full = v }; return o.low; }

int main(void)
{
  unsigned __int128 v = ((unsigned __int128)7 << 64) | 3;
  int ok = (hi_init(v) == 7) + 2 * (hi_set(v) == 7) + 4 * (lo_init(v) == 3) + 8;
  return 40 + ok;   /* 55 */
}
