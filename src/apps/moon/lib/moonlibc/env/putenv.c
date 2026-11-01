#include "../impl.h"

/* the string itself joins the environment: a later write to it is the variable's */
int putenv(char *kv) {
  char *q = strchr(kv, '=');
  if (!q) return unsetenv(kv);
  return __env_put(kv, q - kv); }
