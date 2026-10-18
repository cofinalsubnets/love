#ifndef _LOVE_FENV_H
#define _LOVE_FENV_H
/* one rounding mode, nearest, and no exception flags kept: fesetround refuses the others */
typedef struct { int __round; } fenv_t;
typedef unsigned fexcept_t;
#define FE_INVALID 1
#define FE_DIVBYZERO 4
#define FE_OVERFLOW 8
#define FE_UNDERFLOW 16
#define FE_INEXACT 32
#define FE_ALL_EXCEPT 61
#define FE_TONEAREST 0
#define FE_DOWNWARD 0x400
#define FE_UPWARD 0x800
#define FE_TOWARDZERO 0xc00
extern fenv_t const __fe_dfl_env;
#define FE_DFL_ENV (&__fe_dfl_env)
int fegetround(void), fesetround(int);
int feclearexcept(int), feraiseexcept(int), fetestexcept(int);
int fegetexceptflag(fexcept_t *, int), fesetexceptflag(fexcept_t const *, int);
int fegetenv(fenv_t *), fesetenv(fenv_t const *), feholdexcept(fenv_t *), feupdateenv(fenv_t const *);
#endif
