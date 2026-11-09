#include <stdio.h>
int vf(const char *f, ...);
int vf(const char *f, ...) { return f[0]; }
int fx(int a) { return a + 1; }
int e(void) { return 0; }
int main(void){ int (*p)(const char *, ...) = vf; printf("%d %d %d %d\n", (e(), vf)("a", 1, 2), (*vf)("b", 1), (1 ? vf : vf)("c", 3), p("d", 4)); return 0; }
