#include <dlfcn.h>

/* a static binary loads nothing: each ask fails, and says why. a -shared object linked
   -l:libc.so.6 takes these from the system's libc instead */
void *dlopen(char const *p, int f) { (void) p, (void) f; return 0; }
void *dlsym(void *h, char const *n) { (void) h, (void) n; return 0; }
int dlclose(void *h) { (void) h; return -1; }
char *dlerror(void) { return (char *) "dlopen: a static binary loads nothing"; }
