/* the >6-arg overflow: args 7+ ride the caller stack (arg7 shallowest, caller
   cleans, odd counts padded to keep sp 16-aligned), gp and xmm counters
   separate -- 10 integer args, and 8 xmm named + overflow doubles mixed with
   a gp arg. */
static long f8(long a, long b, long c, long d, long e, long f, long g, long h)
{ return a + 2*b + 3*c + 4*d + 5*e + 6*f + 7*g + 8*h; }
static long f10(long a, long b, long c, long d, long e, long f, long g, long h, long i, long j)
{ return f8(a,b,c,d,e,f,g,h) + 9*i + 10*j; }
static double m10(double a, double b, int k, double c, double d, double e, double f, double g, double h, double i)
{ return a+b+c+d+e+f+g+h + 2.0*i + (double)k; }
int main(void)
{
  long s = f10(1,2,3,4,5,6,7,8,9,10);              /* 385 */
  double d = m10(1,2,3,4,5,6,7,8,9,10);            /* 1+2+4+5+6+7+8+9 + 20 + 3 = 65 */
  return (int)(s - 385 + d - 65 + 42);
}
