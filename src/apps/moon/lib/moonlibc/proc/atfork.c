#include "../impl.h"
#include <pthread.h>

/* the handlers fork runs through its hook: prepare last registered first, parent and child
 * in order */
static void (*__afp[32])(void), (*__afa[32])(void), (*__afc[32])(void);
static int __naf;
static void __af_run(int ph) {
  if (!ph) { for (int i = __naf; i-- > 0; ) if (__afp[i]) __afp[i](); return; }
  for (int i = 0; i < __naf; i++) {
    void (*f)(void) = ph == 1 ? __afa[i] : __afc[i];
    if (f) f(); } }
int pthread_atfork(void (*p)(void), void (*a)(void), void (*c)(void)) {
  if (__naf >= 32) return ENOMEM;
  __afp[__naf] = p, __afa[__naf] = a, __afc[__naf] = c, __naf++;
  __love_forkhook = __af_run;
  return 0; }
