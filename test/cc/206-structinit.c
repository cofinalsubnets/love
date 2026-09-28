/* a brace initializer's element of struct type takes an expression of that struct whole
 * (6.7.9p13): a variable, a call, a member, a deref -- no brace elision into its first field.
 * in an array, in a struct, designated, and beside a real elision run. held to gcc. */

struct pr { long a, b; };
struct tri { long a, b, c; };
struct outer { struct pr p; long z; };

__attribute__((noinline)) static struct pr mk(long x) { return (struct pr) { x, x + 1 }; }

/* a struct of two pointers answered by value, the pair the painter's glyph lookup is */
struct look { unsigned char const *bmp, *rows; };
static unsigned char const tab[4] = { 10, 20, 30, 40 };
__attribute__((noinline)) static struct look look(unsigned cp) {
  return (struct look) { cp < 4 ? tab + cp : 0, cp < 4 ? 0 : tab }; }

#define CK(k, c) do { if (!(c)) return k; } while (0)

int main(void) {
  struct pr v = mk(5), *pv = &v;
  struct outer w = { { 1, 2 }, 3 };
  struct pr a1[2] = { v };
  CK(1, a1[0].a == 5 && a1[0].b == 6 && a1[1].a == 0 && a1[1].b == 0);
  struct pr a2[3] = { mk(7), mk(9) };
  CK(2, a2[0].a == 7 && a2[0].b == 8 && a2[1].a == 9 && a2[1].b == 10 && a2[2].a == 0);
  struct tri t3 = { 3, 4, 5 };             /* a variable: three words would return through memory */
  struct tri a3[2] = { t3 };
  CK(3, a3[0].a == 3 && a3[0].b == 4 && a3[0].c == 5 && a3[1].c == 0);
  struct outer o = { mk(11), 4 };
  CK(4, o.p.a == 11 && o.p.b == 12 && o.z == 4);
  struct pr a4[2] = { [1] = mk(13) };
  CK(5, a4[0].a == 0 && a4[1].a == 13 && a4[1].b == 14);
  struct pr a5[2] = { *pv, w.p };
  CK(6, a5[0].a == 5 && a5[1].a == 1 && a5[1].b == 2);
  struct pr a6[2] = { 1, 2, v };                  /* an elided run, then a whole one */
  CK(7, a6[0].a == 1 && a6[0].b == 2 && a6[1].a == 5 && a6[1].b == 6);
  struct outer o2 = { .p = v, .z = 9 };
  CK(8, o2.p.a == 5 && o2.p.b == 6 && o2.z == 9);
  struct look l[4] = { look(1) };
  CK(9, l[0].bmp == tab + 1 && !l[0].rows && !l[1].bmp && !l[3].rows);
  l[2] = look(9);
  CK(10, !l[2].bmp && l[2].rows == tab);
  return 0;
}
