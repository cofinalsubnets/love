/* the GNU spellings and folds the linux kernel's headers reach for, held to gcc:
 * __signed__ and the underscored qualifiers (a K&R parameter list holds NAMES, so
 * one of these opening the list is a prototype), __builtin_choose_expr,
 * __builtin_object_size, __builtin_prefetch, __auto_type -- and `case A ... B`.
 * the kernel spells __auto_type `auto`, through a macro named by a keyword, which
 * phase 4 must still expand. */
#include <stdio.h>

#define auto __auto_type

__signed__ char sc = -3;
__const int ci = 7;

static int clsfy(int c)
{
  switch (c) {
  case 'a' ... 'f': return 1;
  case '0' ... '9': return 2;
  case 'z':         return 3;
  case 200 ... 200: return 4;
  default:          return 0; } }

static long autos(int x)
{
  __auto_type a = x + 1;                /* int */
  auto b = (long) x * 3;                /* long, through the keyword-named macro */
  __auto_type p = &a;                   /* int * */
  *p += 1;
  return a + b + (sizeof(a) == 4) + (sizeof(b) == 8) * 2; }

struct s { int f; };
static int autoptr(struct s *sp) { __auto_type q = sp; return q->f; }

static int chose(void)
{
  return __builtin_choose_expr(sizeof(long) == 8, 11, 22)
       + __builtin_choose_expr(0, 100, 33); }

/* the arm not chosen is parsed and dropped, so it may name what does not exist */
extern int never_defined(void);
static int chose_dead(void) { return __builtin_choose_expr(1, 5, never_defined()); }

/* not a value differential: gcc answers the real size where it can see the object
 * (and, at the -O0 this battery runs at, nothing at all), we always answer the
 * conservative end. what must agree is that the two types order the way the
 * builtin promises -- type 0 is the maximum, type 2 the minimum */
static int obsz(char *p)
{
  return __builtin_object_size(p, 0) >= __builtin_object_size(p, 2); }

static int pref(int *p)
{
  int n = 0;
  __builtin_prefetch(&p[n++]);          /* the address is evaluated for its effects */
  __builtin_prefetch(p, 1);
  __builtin_prefetch(p, 0, 3);
  return n; }

static int kr(__const int *p, __signed__ char *q) { return *p + *q; }

int main(void)
{
  char buf[8];
  int v[4] = { 5, 6, 7, 8 };
  struct s s1 = { 9 };
  int a = clsfy('c') + clsfy('f') * 10 + clsfy('g') * 100 + clsfy('5') * 1000;
  int b = clsfy('z') + clsfy(200) * 10;
  long c = autos(4);
  int d = autoptr(&s1);
  int e = chose() + chose_dead();
  int f = obsz(buf) + pref(v);
  int g = kr(&ci, &sc);
  int h = sizeof(__signed__ char) + sizeof(sc);
  printf("%d %d %ld %d %d %d %d %d\n", a, b, c, d, e, f, g, h);
  return (a + b + (int) c + d + e + f + g + h) & 0x7f; }
