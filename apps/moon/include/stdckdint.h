#ifndef _AI_STDCKDINT_H
#define _AI_STDCKDINT_H
/* C23 7.20 checked integer arithmetic. cc has no _Bool keyword, so the
   result narrows to int (0/1) -- the same truth value. gen.l already lowers
   __builtin_{add,sub,mul}_overflow (rax op rcx + set-overflow). */
#define ckd_add(r, a, b) ((int) __builtin_add_overflow((a), (b), (r)))
#define ckd_sub(r, a, b) ((int) __builtin_sub_overflow((a), (b), (r)))
#define ckd_mul(r, a, b) ((int) __builtin_mul_overflow((a), (b), (r)))
#endif
