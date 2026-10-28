#pragma once
/* c23 checked arithmetic, answering an int 0 or 1 */
#define ckd_add(r, a, b) ((int) __builtin_add_overflow((a), (b), (r)))
#define ckd_sub(r, a, b) ((int) __builtin_sub_overflow((a), (b), (r)))
#define ckd_mul(r, a, b) ((int) __builtin_mul_overflow((a), (b), (r)))
