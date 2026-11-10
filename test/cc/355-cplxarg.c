#include <stdio.h>
_Complex double f(_Complex double a, _Complex double b) { return a * b + a / b; }
_Complex double h(_Complex double a, _Complex double b) { return a / b; }
_Complex double k(_Complex double a, _Complex double b) { return a * b; }
__attribute__((noinline)) _Complex float mk(void){ return 6; }
__attribute__((noinline)) void pd(_Complex double a){ double *p=(double*)&a; printf("%g %g\n",p[0],p[1]); }
int main(void){ _Complex double a = 6, b = 1; _Complex double r = f(a,b), s = h(a,b), t = k(a,b); double *p=(double*)&r,*q=(double*)&s,*u=(double*)&t; printf("%g %g %g %g %g %g\n",p[0],p[1],q[0],q[1],u[0],u[1]); r = f(6,1); printf("%g %g\n",p[0],p[1]); _Complex float z = mk(); r = f(z,1); printf("%g %g\n",p[0],p[1]); r = h(z, 1); printf("%g %g\n",p[0],p[1]); pd(z); pd(1); pd(2.5); return 0;}
