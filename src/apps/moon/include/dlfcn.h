#pragma once
/* moonlibc's fail every ask and say why; a -shared object linked -l:libc.so.6 takes
   these from the system's libc, which has carried them since glibc 2.34 */
#define RTLD_LAZY   1
#define RTLD_NOW    2
#define RTLD_GLOBAL 0x100
#define RTLD_LOCAL  0
#define RTLD_DEFAULT ((void *) 0)
void *dlopen(const char *, int), *dlsym(void *, const char *);
int dlclose(void *);
char *dlerror(void);
