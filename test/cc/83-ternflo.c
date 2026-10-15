/* ?: converts its arms: one float arm makes the result float, the int arm converts
   at its edge. plus a negative float literal in a global image. */
static double R[2] = { -1.0, 0.0 };
static double re(long x) { return R[0]; }
static double im(long x) { return R[1]; }
static int Cp(long x) { return x == 2; }
static int charmp(long x) { return x & 1; }
static long getch(long x) { return x >> 1; }
int eqlane(long a, long b) {
  return (Cp(a) || charmp(a)) && (Cp(b) || charmp(b))
      && (Cp(a) ? re(a) : (double) getch(a)) == (Cp(b) ? re(b) : (double) getch(b))
      && (Cp(a) ? im(a) : 0) == (Cp(b) ? im(b) : 0);
}
int main(void) {
  long c = -1, t = 2;         /* c: a tagged -1 charm; t: the twin */
  int x = 0;
  double d = charmp(c) ? 0 : 1.5;   /* int THEN-arm taken, typed double */
  if (d == 0.0) x += 20;
  if (eqlane(c, t)) x += 11;
  if (eqlane(t, c)) x += 11;
  return x;
}
