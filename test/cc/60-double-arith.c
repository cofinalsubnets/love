/* double locals, arithmetic, int<->double conversion, cast at return */
int main() {
  double a = 3.5;
  double b = 1.25;
  double s = a + b;      /* 4.75 */
  double d = a - b;      /* 2.25 */
  double p = a * b;      /* 4.375 */
  double q = a / b;      /* 2.8 */
  int n = 2;
  double m = a * n;      /* 7.0 -- mixed int*double */
  return (int)(s + d + p + q + m);   /* 4.75+2.25+4.375+2.8+7.0 = 21.175 -> 21 */
}
