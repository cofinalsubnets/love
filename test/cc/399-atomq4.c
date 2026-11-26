// an exclusive loop's scratch is not a register the allocator may hold a value in: nine values
// live across each atomic op, more than the callee-saved file without it
#if __GCC_HAVE_SYNC_COMPARE_AND_SWAP_4
volatile int src[9] = { 1, 2, 3, 4, 5, 6, 7, 8, 9 };
__attribute__((noinline)) static int xchg(int *p) {
  int a = src[0], b = src[1], c = src[2], d = src[3], e = src[4], f = src[5], g = src[6], h = src[7], i = src[8];
  int o = __atomic_exchange_n(p, 100, __ATOMIC_SEQ_CST);
  return o + a + 2 * b + 3 * c + 4 * d + 5 * e + 6 * f + 7 * g + 8 * h + 9 * i; }
__attribute__((noinline)) static int add(int *p) {
  int a = src[0], b = src[1], c = src[2], d = src[3], e = src[4], f = src[5], g = src[6], h = src[7], i = src[8];
  int o = __atomic_fetch_add(p, 5, __ATOMIC_SEQ_CST);
  return o + a + 2 * b + 3 * c + 4 * d + 5 * e + 6 * f + 7 * g + 8 * h + 9 * i; }
__attribute__((noinline)) static int cas(int *p) {
  int a = src[0], b = src[1], c = src[2], d = src[3], e = src[4], f = src[5], g = src[6], h = src[7], i = src[8];
  int want = 105, o = __atomic_compare_exchange_n(p, &want, 7, 0, __ATOMIC_SEQ_CST, __ATOMIC_SEQ_CST);
  return o + a + 2 * b + 3 * c + 4 * d + 5 * e + 6 * f + 7 * g + 8 * h + 9 * i; }
#if __GCC_HAVE_SYNC_COMPARE_AND_SWAP_1
__attribute__((noinline)) static int tas(char *p) {
  int a = src[0], b = src[1], c = src[2], d = src[3], e = src[4], f = src[5], g = src[6], h = src[7], i = src[8];
  int o = __atomic_test_and_set(p, __ATOMIC_SEQ_CST);
  return o + a + 2 * b + 3 * c + 4 * d + 5 * e + 6 * f + 7 * g + 8 * h + 9 * i; }
#else
static int tas(char *p) { return *p = 1, 285; }
#endif
int main(void) {
  int v = 50; char t = 0;
  if (xchg(&v) != 50 + 285 || v != 100) return 1;
  if (add(&v) != 100 + 285 || v != 105) return 2;
  if (cas(&v) != 1 + 285 || v != 7) return 3;
  if (tas(&t) != 285 || !t) return 4;
  return 0; }
#else
int main(void) { return 0; }
#endif
