/* a constant expression folds in C's types: operands meet at the usual arithmetic
 * conversions, so -1 < 1u is 0 and -6 / 3u divides unsigned, and each result wraps to its
 * type -- in a static, an aggregate, a local, an array bound and a case label alike. some
 * readings differ by target (-1L < 1u: long holds every uint on LP64 only); main answers a
 * checksum of them all, held to gcc on every target. */

static int s1 = -1 < 1u;
static unsigned s2 = -6 / 3u;
static long long s3 = -6 / 3u;
static int s4 = -1L < 1u;
static int s5 = -7 % 3u;
static long long s6 = 0xffffffffu + 1;
static unsigned s7 = -1u >> 1;
static int s8 = -1u >> 31;
static int s9 = 0x7fffffff + 1 < 0;              /* int arithmetic wraps as the machine does */
static int s10 = sizeof(int) - 5 < 0;           /* size_t is unsigned */
static int s11 = (1 ? -1 : 0u) > 0;             /* the arms meet at unsigned */
static int s12 = (unsigned char) 300 + (signed char) 200;
static long long arr[3] = { -1 < 1u, -6 / 3u, (int) 2.5 - 3u };
static int dim[(-1 > 0u) ? 2 : 3];
_Static_assert(-1 > 0u, "a negative int converts to a huge unsigned");

static int cs(int x) { switch (x) { case -1 < 1u: return 3; case 1: return 5; } return 7; }

int main(void) {
  unsigned lu = -6 / 3u; int li = (-1 > 0u) ? 5 : 6;
  long long v[] = { s1, s2, s3, s4, s5, s6, s7, s8, s9, s10, s11, s12, arr[0], arr[1], arr[2],
                    sizeof dim / sizeof dim[0], cs(0), cs(1), lu, li };
  unsigned long long h = 0;
  for (int i = 0; i < (int) (sizeof v / sizeof v[0]); i++) h = h * 1000003u + (unsigned long long) v[i];
  return (int) (h % 251); }
