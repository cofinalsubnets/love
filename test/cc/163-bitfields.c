/* two anonymous-bitfield shapes the kernel's headers write, held to gcc: one over
 * a TYPEDEF (linux/timex.h's `s32:32;` padding, which reads exactly like a struct
 * label), and one continuing into a comma list (asm/cpuid/types.h's
 * `u32 : 31, invalid : 1;`, where only the second member is named). */
#include <stdio.h>

typedef int s32;
typedef unsigned u32;

struct pad {
  s32 a;
  s32:32; s32:32;
  s32 b;
};

struct reg { u32 : 31, invalid : 1; };
struct reg2 { u32 lo : 4, : 8, hi : 4; };
struct al { u32 a : 3; u32 : 0; u32 b : 3; };   /* :0 forces the next unit */

int main(void)
{
  struct pad p = { 1, 2 };
  struct reg r = { 1 };
  struct reg2 q = { 5, 9 };
  struct al z = { 3, 4 };
  printf("%d %d %d %d %d %d %d %d %d\n",
         (int) sizeof(struct pad), p.a + p.b,
         (int) sizeof(struct reg), (int) r.invalid,
         (int) sizeof(struct reg2), (int) q.lo, (int) q.hi,
         (int) sizeof(struct al), (int) (z.a * 10 + z.b));
  return ((int) sizeof(struct pad) + (int) sizeof(struct al) + q.lo + q.hi) & 0x7f;
}
