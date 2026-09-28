/* brace elision past a union, held to gcc: a positional initializer fills a union's first
 * member and passes the rest by (an anonymous union's members are spliced flat, so the walk
 * must know them), an anonymous struct as that first member takes its whole run, a union
 * named as a member stops at one element, and a designator into a union resumes past it.
 * bitfields ahead of a union keep their unit. static images and block scope alike. */

struct s1 { int a; int b; };
struct s2 { int a; int b; union { int c; int d; }; struct s1 s; };
struct s3 { int a; union { struct { short x, y; }; int z; }; int e; };
struct s4 { unsigned f1 : 3, f2 : 5; union { char k; long m; }; int t; };
union u { int u1; short u2; };
struct s5 { union u u; int w; };

struct s2 g2 = {1, 2, 3, {4, 5}};
struct s3 g3 = {1, 2, 3, 4};
struct s4 g4 = {5, 17, 9, 6};
struct s5 g5 = {7, 8};
struct s2 g2d = {.c = 3, 4, 5};
struct s3 g3d = {.z = 70000, 9};

int main(void) {
  int bad = 0;
  if (g2.a != 1 || g2.b != 2 || g2.c != 3 || g2.d != 3 || g2.s.a != 4 || g2.s.b != 5) bad |= 1;
  if (g3.a != 1 || g3.x != 2 || g3.y != 3 || g3.e != 4) bad |= 2;
  if (g4.f1 != 5 || g4.f2 != 17 || g4.k != 9 || g4.t != 6) bad |= 4;
  if (g5.u.u1 != 7 || g5.w != 8) bad |= 8;
  if (g2d.c != 3 || g2d.s.a != 4 || g2d.s.b != 5 || g3d.z != 70000 || g3d.e != 9) bad |= 16;
  struct s2 l2 = {1, 2, 3, {4, 5}};
  struct s3 l3 = {1, 2, 3, 4};
  struct s4 l4 = {5, 17, 9, 6};
  struct s5 l5 = {7, 8};
  struct s2 l2d = {.c = 3, 4, 5};
  if (l2.c != 3 || l2.d != 3 || l2.s.a != 4 || l2.s.b != 5) bad |= 32;
  if (l3.x != 2 || l3.y != 3 || l3.e != 4 || l4.k != 9 || l4.t != 6) bad |= 64;
  if (l5.u.u1 != 7 || l5.w != 8 || l2d.s.a != 4 || l2d.s.b != 5) bad |= 128;
  return bad;
}
