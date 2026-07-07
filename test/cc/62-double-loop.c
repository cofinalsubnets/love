/* a double accumulator across a loop, negation, ternary max */
int main() {
  double sum = 0.0;
  int i = 0;
  while (i < 4) { sum = sum + 2.5; i = i + 1; }   /* 10.0 */
  double neg = -sum;                               /* -10.0 */
  double a = 6.0, b = 9.0;
  double mx = a > b ? a : b;                       /* 9.0 */
  return (int)(sum + neg + mx);                    /* 0 + 9 = 9 */
}
