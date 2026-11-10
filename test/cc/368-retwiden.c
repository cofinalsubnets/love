// a call's int answer is widened from its low half, whatever the callee last held in the register
static unsigned long long hash = 14695981039346656037ULL;
static void mix(unsigned long long x) { for (int i = 0; i < 8; i++, x >>= 8) hash = (hash ^ (x & 255)) * 1099511628211ULL; }
__attribute__((noinline)) static int r1(unsigned k) { return k; }
__attribute__((noinline)) static unsigned r2(int k) { return k; }
__attribute__((noinline)) static int r3(long long k) { return k; }
__attribute__((noinline)) static unsigned r4(long long k) { return k; }
__attribute__((noinline)) static short r5(int k) { return k; }
__attribute__((noinline)) static unsigned char r6(int k) { return k; }
__attribute__((noinline)) static int r7(unsigned a, unsigned b) { return a * b; }
int main(void) {
  int (*fp)(unsigned) = r1;
  mix(368);
  mix((unsigned long long) (long long) r1(-3)), mix(r2(-3)), mix((unsigned long long) (long long) r3(0x1fffffffdLL));
  mix(r4(-1LL)), mix((unsigned long long) (long long) r5(0x1fffd)), mix(r6(0x1fd));
  mix((unsigned long long) (long long) r7(0x10001, 0xffff));
  mix((unsigned long long) (long long) fp(0xfffffff0u));
  return (int) ((hash ^ hash >> 32) % 251);
}
