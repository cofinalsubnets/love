#ifndef _LOVE_SETJMP_H
#define _LOVE_SETJMP_H
/* glibc's jmp_buf size, 25 longs; sigsetjmp is a macro over __sigsetjmp, as in glibc */
#ifdef __ARM_EABI__
typedef long long jmp_buf[16];               /* arm's: r4-r11 sp lr, d8-d15, a BSD's 16-byte mask at 104 */
typedef long long sigjmp_buf[16];
#else
typedef long jmp_buf[25];
typedef long sigjmp_buf[25];
#endif
int __sigsetjmp(sigjmp_buf, int);
void siglongjmp(sigjmp_buf, int);
#define sigsetjmp(env, save) __sigsetjmp(env, save)
/* the plain pair rides the sig pair: restoring the mask setjmp saved is the identity */
#define setjmp(env) __sigsetjmp(env, 0)
#define longjmp(env, v) siglongjmp(env, v)
#endif
