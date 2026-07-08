/* gen tail: mproto siblings are callable (a comma-list proto registers EVERY
   name, not just the first), &f is a function's address (same as the bare
   use) -- in a global image, a local initializer, and an argument -- and an
   INDIRECT call knows a double result (the fn-pointer type carries its return). */
int one(int), two(int), three(int);          /* siblings: two and three have no proto form of their own */

int one(int x) { return x + 1; }
int two(int x) { return x + 2; }
int three(int x) { return x + 3; }

typedef int (*fp)(int);
static fp table[3] = { &one, two, &three };  /* &f and bare f agree in an image */

static int through(fp f, int x) { return f(x); }

static double half(double x) { return x / 2.0; }
static double fdisp(double (*f)(double), double x) { return f(x); }   /* the result rides f0, typed by the pointer */

int main(void)
{
  fp p = &two;                               /* &f as a local initializer */
  int s = 0;
  for (int i = 0; i < 3; i++) s += table[i](i);        /* 1 + 3 + 5 = 9 */
  s += p(10);                                /* + 12 = 21 */
  s += through(&one, 20);                    /* + 21 = 42 */
  s -= (int)fdisp(half, 16.0);               /* - 8 = 34 */
  s += (int)fdisp(&half, 16.0);              /* + 8 = 42 */
  return s;
}
