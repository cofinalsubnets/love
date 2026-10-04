#ifndef _LOVE_ERR_H
#define _LOVE_ERR_H
/* BSD's message-and-exit calls, glibc's way: "prog: msg: strerror", the x ones without the
   strerror, and a null format leaving just the strerror */
#include <stdarg.h>
void warn(char const *, ...);
void warnx(char const *, ...);
void vwarn(char const *, va_list);
void vwarnx(char const *, va_list);
void err(int, char const *, ...) __attribute__((noreturn));
void errx(int, char const *, ...) __attribute__((noreturn));
void verr(int, char const *, va_list) __attribute__((noreturn));
void verrx(int, char const *, va_list) __attribute__((noreturn));
#endif
