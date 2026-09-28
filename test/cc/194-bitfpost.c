/* postfix ++ and -- on a bit-field: the old value answers, the field wraps at its width,
 * a signed field steps through its sign, and the neighbours in the unit keep their bits. */

#if __SIZEOF_POINTER__ == 8
#define WIDE 0xffffffffffULL
struct s { unsigned a : 3; int b : 4; unsigned c : 5; unsigned long long d : 40; unsigned e : 1; };
#else
#define WIDE 0xffffffU
struct s { unsigned a : 3; int b : 4; unsigned c : 5; unsigned d : 24; unsigned e : 1; };
#endif

static int walk(struct s *p, int n) {
  int acc = 0;
  for (int i = 0; i < n; i++) acc += p->b++;
  return acc;
}

int main(void) {
  int bad = 0;
  struct s x = { 7, 7, 31, 0, 1 };
  if (x.a++ != 7 || x.a != 0) bad |= 1;
  if (x.b++ != 7 || x.b != -8) bad |= 2;
  if (x.b-- != -8 || x.b != 7) bad |= 4;
  if (x.c-- != 31 || x.c != 30) bad |= 8;
  if (x.d-- != 0 || x.d != WIDE) bad |= 16;
  if (x.e++ != 1 || x.e != 0) bad |= 32;
  if (x.a != 0 || x.b != 7 || x.c != 30 || x.d != WIDE) bad |= 64;
  struct s y = { 0, -3, 0, 5, 0 };
  if (walk(&y, 6) != -3 - 2 - 1 + 0 + 1 + 2 || y.b != 3 || y.d != 5) bad |= 128;
  return bad;
}
