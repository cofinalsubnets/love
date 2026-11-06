#include <stdio.h>
_Complex double f(_Complex double a, _Complex double b) { return a * b + a / b; }
_Complex float g(_Complex float a, int n) { return a * n; }
int main(void) { _Complex double r = f(1.0, 2.0); _Complex float s = g(3, 2); _Complex double t = f(s, 1); double *p = (double *)&r, *q = (double *)&t; float *u = (float *)&s; printf("%g %g %g %g %g %g\n", p[0], p[1], (double)u[0], (double)u[1], q[0], q[1]); return 0; }
