/* shapes gnulib leans on: a macro parameter spelled like a keyword (its stdint.h names one
 * `signed`), a constant 0.0/0.0 in a static initializer (isnan's probe) laid as the IEEE quiet
 * nan with its sign, and a parameter of function type, which is a pointer to one */
typedef unsigned long u64;
typedef unsigned int u32;

#define MAXOF(signed, bits, zero) (((((zero) + 1) << ((bits) - 1 - (signed))) - 1) * 2 + 1)
#define STR(int) #int

static double const qn = 0.0 / 0.0, nqn = -(0.0 / 0.0), inv = 1.0 / 0.0 - 1.0 / 0.0, inf = 1.0 / 0.0;
static float const fqn = 0.0f / 0.0f;

static u64 bits(double d) { u64 u; __builtin_memcpy(&u, &d, 8); return u; }
static u32 fbits(float f) { u32 u; __builtin_memcpy(&u, &f, 4); return u; }

typedef int const *pick(char const *ctx, char const *arg);
static int const seven = 7;
static int const *first(char const *ctx, char const *arg) { return &seven; }
static int take(pick p, char *arg, u64 no) { return *p("opt", arg + no); }
static int twice(int f(int), int x) { return f(f(x)); }
static int inc(int x) { return x + 1; }

int main(void) {
  int bad = 0;
  if (MAXOF(0, 64, 0ul) != 0xffffffffffffffffull) bad |= 1;
  if (MAXOF(1, 32, 0) != 0x7fffffff) bad |= 2;
  if (STR(x)[0] != 'x') bad |= 4;
  if (bits(qn) != 0x7ff8000000000000ull || bits(nqn) != 0xfff8000000000000ull) bad |= 8;
  if (bits(inv) != 0x7ff8000000000000ull || bits(inf) != 0x7ff0000000000000ull) bad |= 16;
  if (fbits(fqn) != 0x7fc00000u || qn == qn) bad |= 32;
  if (take(first, "x", 0) != 7 || twice(inc, 1) != 3) bad |= 64;
  return bad;
}
