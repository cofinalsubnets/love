#ifndef _LOVE_SETJMP_H
#define _LOVE_SETJMP_H
/* glibc's jmp_buf size, 25 longs; sigsetjmp is a macro over __sigsetjmp, as in glibc */
typedef long jmp_buf[25];
typedef long sigjmp_buf[25];
int __sigsetjmp(sigjmp_buf, int);
void siglongjmp(sigjmp_buf, int);
#define sigsetjmp(env, save) __sigsetjmp(env, save)
/* the plain pair rides the sig pair: restoring the mask setjmp saved is the identity */
#define setjmp(env) __sigsetjmp(env, 0)
#define longjmp(env, v) siglongjmp(env, v)
#endif
