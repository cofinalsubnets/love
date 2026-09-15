/* a double-returning recursion through the xmm ABI, and a fixed-arity fan */
double ipow(double x, int n) {
  if (n == 0) return 1.0;
  return x * ipow(x, n - 1);
}
double sum6(double a, double b, double c, double d, double e, double f) {
  return a + b + c + d + e + f;
}
int main() {
  double p = ipow(2.0, 10);              /* 1024.0 */
  double s = sum6(1.0, 2.0, 3.0, 4.0, 5.0, 6.0);  /* 21.0 */
  return (int)(p / 64.0) + (int)s;       /* 16 + 21 = 37 */
}
