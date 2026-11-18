#include "../impl.h"

/* _Exit is _exit; quick_exit runs at_quick_exit's handlers, last first, and no atexit
 * handler, destructor or flush */
static void (*__qex[32])(void);
static int __nqex;
void _Exit(int c) { _exit(c); }
int at_quick_exit(void (*f)(void)) {
  if (__nqex >= 32) return -1;
  __qex[__nqex++] = f;
  return 0; }
void quick_exit(int c) {
  while (__nqex > 0) __qex[--__nqex]();
  _exit(c); }
