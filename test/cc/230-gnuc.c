/* the GNU C a compiler claiming __GNUC__ 8 owes a header: the identity, the __has_ probes,
 * __COUNTER__, _Pragma, __VA_OPT__, gnu_inline's linkage, and the builtins taken by name.
 * exit-code only. */

#if !defined(__GNUC__) || (__GNUC__ < 8 && !defined(__clang__))   /* clang says 4.2, and is itself */
#error not GNU C 8
#endif
#if !defined(__has_attribute) || !__has_attribute(aligned) || !__has_attribute(__packed__) \
    || __has_attribute(no_such_attribute_here)
#error __has_attribute
#endif
#if !defined(__has_include) || !__has_include(<stddef.h>) || __has_include(<no/such/header.h>) \
    || !__has_include("230-gnuc.c")
#error __has_include
#endif
#ifdef __mooncc__
/* the ones mooncc would change the code by skipping say no, so a header takes its fallback */
#if __has_attribute(constructor) || __has_attribute(vector_size) || !__has_attribute(used)
#error a refused attribute claimed
#endif
#endif

static int c0 = __COUNTER__, c1 = __COUNTER__;

static int one(int a) { return a + 1; }
static int add3(int a, int b, int c) { return a + b + c; }
#define VA(f, ...) f(0 __VA_OPT__(,) __VA_ARGS__)

_Pragma("GCC diagnostic push")
_Pragma("GCC diagnostic ignored \"-Wunused-variable\"")
static int quiet;
_Pragma("GCC diagnostic pop")

/* gnu89's plain inline lays the external definition C99's does not */
inline __attribute__((gnu_inline)) int thrice(int x) { return 3 * x; }

__attribute__((used)) static int kept(void) { return 7; }

/* wasm keeps its return addresses where linear memory cannot reach them */
__attribute__((noinline)) static unsigned long ret(void)
{
#ifdef __wasm__
	return 1;
#else
	return (unsigned long)__builtin_extract_return_addr(__builtin_return_address(0));
#endif
}

int main(void)
{
	int x[4] __attribute__((aligned(16))) = { 1, 2, 3, 4 };
	int *p = __builtin_assume_aligned(x, 16);
	if (c1 - c0 != 1) return 1;
	if (VA(one) != 1 || VA(add3, 1, 2) != 3) return 2;
	if (thrice(4) != 12 || quiet) return 3;
	if (__builtin_parity(7) != 1 || __builtin_parityl(3UL) != 0 || __builtin_parityll(1ULL << 40) != 1) return 4;
	if (p != x || p[3] != 4) return 5;
	if (ret() == 0) return 6;
	return 0;
}
