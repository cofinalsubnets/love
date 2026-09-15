/* the xmm calling convention: double params, returns, and args */
double add(double a, double b) { return a + b; }
double scale(double x, int n) { return x * n; }   /* mixed int/double params */
double poly(double x) { return x * x + 2.0 * x + 1.0; }  /* (x+1)^2 */
int main() {
  double s = add(1.5, 2.75);      /* 4.25 */
  double t = scale(3.0, 4);       /* 12.0 -- an int arg into a double * */
  double p = poly(4.0);           /* 25.0 */
  int i = add(2, 3);              /* int args 2,3 -> promoted to double -> 5.0 -> (int)5 */
  return (int)(s + t + p) + i;    /* 4.25+12+25 = 41.25 -> 41, +5 = 46 */
}
