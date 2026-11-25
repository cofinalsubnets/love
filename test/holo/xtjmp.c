/* setjmp and longjmp on a bare xtensa link, the runtime the carried archive's: thumb's
 * checks (test/thumb2/libj.c) under call0, exit 42 when all hold, 100+n at the miss */
#include "../thumb2/libj.c"
void _start(void) {
  int r = jint();
  if (r == 1) r = jregs(5);
  r = r == 1 ? 42 : r;
  __attribute__((holo)) asm volatile("mov r4, %0\n\tli r0, 119\n\tsys" :: "r"(r) : "r0");
  for (;;) ;
}
