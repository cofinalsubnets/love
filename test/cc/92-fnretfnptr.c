/* a function returning a function pointer, int (*g(void))(void): the declarator,
   the sig's return type, the inner params bound in the body, two nested calls. */
int inc(int x) { return x + 1; }
int dbl(int x) { return x * 2; }

/* g takes no args, returns a pointer to a function (int)->int */
int (*pick(int which))(int) { return which ? dbl : inc; }

/* a plain no-arg case too */
int seven(void) { return 7; }
int (*getseven(void))(void) { return seven; }

int main(void)
{
  int a = pick(0)(10);      /* inc(10) = 11 */
  int b = pick(1)(10);      /* dbl(10) = 20 */
  int c = getseven()();     /* 7 */
  return a + b + c;         /* 11 + 20 + 7 = 38 */
}
