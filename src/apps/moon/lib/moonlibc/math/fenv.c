/* src/apps/moon/lib/moonlibc/math/fenv.c -- <fenv.h> */
#include "../impl.h"
#include <math.h>
#include <fenv.h>

/* ---- <fenv.h>: one rounding mode, nearest, and no flags kept ---- */
fenv_t const __fe_dfl_env = { FE_TONEAREST };
int fegetround(void) { return FE_TONEAREST; }
int fesetround(int r) { return r == FE_TONEAREST ? 0 : -1; }
int feclearexcept(int e) { (void) e; return 0; }
int feraiseexcept(int e) { (void) e; return 0; }
int fetestexcept(int e) { (void) e; return 0; }
int fegetexceptflag(fexcept_t *f, int e) { (void) e; *f = 0; return 0; }
int fesetexceptflag(fexcept_t const *f, int e) { (void) f; (void) e; return 0; }
int fegetenv(fenv_t *f) { f->__round = FE_TONEAREST; return 0; }
int fesetenv(fenv_t const *f) { return f == FE_DFL_ENV || f->__round == FE_TONEAREST ? 0 : -1; }
int feholdexcept(fenv_t *f) { return fegetenv(f); }
int feupdateenv(fenv_t const *f) { return fesetenv(f); }
