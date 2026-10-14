/* an op= reads as a constant past it only where its answer is one whatever x held: x /= 9
 * answers 0 at x = 0, 1 and -1 alike, and still depends on x (xz's lzma props). x &= 0 is 0. held to gcc. */

static __attribute__((noinline)) int props(unsigned b, int *lc, int *lp, int *pb) {
  if (b >= 225) return 0;
  *lc = b % 9; b /= 9; *lp = b % 5; *pb = b / 5;
  return 1;
}
static __attribute__((noinline)) int third(int x) { x /= 3; return x; }
static __attribute__((noinline)) int gone(int x) { x &= 0; return x + 1; }

int main(void) {
  int lc = 0, lp = 0, pb = 0;
  int ok = props(111, &lc, &lp, &pb);
  return ok + lc + 4 * lp + 16 * pb + third(10) + gone(7);   /* 1 + 3 + 8 + 32 + 3 + 1 = 48 */
}
