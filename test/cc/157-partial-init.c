// a local aggregate initialized in part: the fields the list does not reach are zero.
// a 32-bit target is where a zeroing stride of 8 bytes would miss every other word.
struct wide {
  void *p; long *a, *b;
  unsigned long u, v;
  int flag;
  unsigned long arr[6];
  int n;
  char *s;
  unsigned long x, y;
  struct inner { unsigned long i, j, k, l; } *q;
  unsigned long z;
};

int main(void) {
  long m = 1, n = 2;
  struct wide w = { .p = 0, .a = &m, .b = &n };   // designated, three of thirteen
  struct wide v = { 0 };                          // the elided form of the same question
  int t = w.flag + w.n + (int) w.u + (int) w.v + (int) w.x + (int) w.y + (int) w.z;
  for (int i = 0; i < 6; i++) t += (int) w.arr[i] + (int) v.arr[i];
  if (w.s) t += 1;
  if (w.q) t += 1;
  if (v.p || v.a || v.b || v.s || v.q) t += 1;
  t += v.flag + v.n + (int) v.u + (int) v.z;
  return t == 0 ? 42 : 1;
}
