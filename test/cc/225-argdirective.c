/* a directive inside a function-like macro's arguments (C11 6.10.3p11 leaves it undefined;
 * gcc and clang take it, and a struct_group of conditional members leans on it): the
 * directive acts where it stands, and the call expands once its ) comes. */

#define G(n, ...) struct { __VA_ARGS__ } n
#define ADD(a, b) ((a) + (b))
#define Y 1

struct s {
    G(h,
      int a;
#ifdef NOT_DEFINED
      int b;
#endif
      int c;
#if Y
      int d;
#else
      int e;
#endif
    );
};

int main(void)
{
    struct s v;
    v.h.a = 1, v.h.c = 2, v.h.d = 3;
    if (sizeof v.h != 3 * sizeof(int)) return 1;
    if (v.h.c + v.h.d != 5) return 2;
    if (ADD(2,
#ifdef NOT_DEFINED
            100
#else
            3
#endif
            ) != 5) return 3;
    if ((2
#if Y
         + 4
#endif
         ) != 6) return 4;             /* a plain paren holds nothing, and still reads */
    return 0;
}
