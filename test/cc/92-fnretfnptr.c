/* a function returning a function pointer -- int (*g(void))(void) : g is a
   function whose RETURN type is a pointer-to-function. the parenthesized
   declarator (*g(void)) makes g a function; the trailing (void) makes the
   pointee a function; the leading * makes g return the pointer to it. the
   inner params are parsed and bound in the body (pick reads k). exit agrees
   with gcc only if the declarator, the sig's return type, and the two nested
   calls all line up. */
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
