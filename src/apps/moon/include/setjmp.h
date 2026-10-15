#ifndef _LOVE_SETJMP_H
#define _LOVE_SETJMP_H
/* glibc jmp_buf is a 200-byte struct[1]; we mirror its SIZE (25 longs) so the
 * real libc setjmp/longjmp save/restore it correctly. sigsetjmp is a glibc
 * macro over __sigsetjmp (the exported symbol), so route through it. */
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
/* the plain pair rides the sig machinery (mksys.l's leaves: the mask slot is
 * saved either way, and restoring a mask setjmp just saved is the identity) */
#define setjmp(env) __sigsetjmp(env, 0)
#define longjmp(env, v) siglongjmp(env, v)
#endif
