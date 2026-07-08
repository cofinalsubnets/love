/* struct ai_zn by value, end to end: brace-init local + return by value (zn),
   param by value (nonpos), local from a call, member sums, nested call args,
   whole-struct assign from a call. */
struct zn { double re, im; };
static struct zn zn(double re, double im) { struct zn z = {re, im}; return z; }
static int nonpos(struct zn z) { return z.re < 0 || (z.re == 0 && z.im <= 0); }
static struct zn add2(struct zn a, struct zn b) { return zn(a.re + b.re, a.im + b.im); }
int main(void)
{
  struct zn s = zn(0, 0);
  struct zn e = zn(3.5, 1.5);
  s.re += e.re; s.im += e.im;                 /* (3.5, 1.5) */
  s = add2(s, zn(2.5, -1.5));                 /* (6, 0) */
  int a = nonpos(zn(-1, 5)) ? 10 : 0;         /* 10 */
  a += nonpos(zn(0, 0)) ? 20 : 0;             /* + 20 = 30 */
  a += nonpos(s) ? 100 : (int)s.re;           /* + 6 = 36 */
  a += nonpos(zn(0, 1)) ? 100 : 6;            /* + 6 = 42 */
  return a;
}
