#ifndef _AI_SETJMP_H
#define _AI_SETJMP_H
/* glibc jmp_buf is a 200-byte struct[1]; we mirror its SIZE (25 longs) so the
 * real libc setjmp/longjmp save/restore it correctly. sigsetjmp is a glibc
 * macro over __sigsetjmp (the exported symbol), so route through it. */
typedef long jmp_buf[25];
typedef long sigjmp_buf[25];
int setjmp(jmp_buf);
void longjmp(jmp_buf, int);
int __sigsetjmp(sigjmp_buf, int);
void siglongjmp(sigjmp_buf, int);
#define sigsetjmp(env, save) __sigsetjmp(env, save)
#endif
