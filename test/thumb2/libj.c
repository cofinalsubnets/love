/* setjmp and longjmp on a bare core, mooncc side: mksys's leaves, no kernel and no mask.
   jint runs before any fp instruction, so CONTROL.FPCA is clear and d8-d15 stay out;
   jregs holds ints and doubles in callee-saved registers across the setjmp, then jumps
   from deep inside a frame that took them all; jfp's setjmp is the gcc side's, which holds
   s16-s31 (d8-d15) across it and jumps back from a frame that wrote them */
#include <setjmp.h>
static jmp_buf b;
static int n;
static void down(int k) { n++; if (!k) longjmp(b, 7); down(k - 1); n += 100; }
int jint(void) {
  volatile int k = 0;
  int r = setjmp(b);
  if (r == 0) { k = 1; down(5); return 101; }
  if (r != 7 || k != 1 || n != 6) return 102;
  r = setjmp(b);
  if (r == 0) longjmp(b, 0);
  return r == 1 ? 1 : 103;
}
volatile int sink;
volatile double dsink;
static __attribute__((noinline)) void deep(int s) {
  int a = s * 23 + 9, c = s * 29 + 8, e = s * 31 + 7, f = s * 37 + 6, g = s * 41 + 5, h = s * 43 + 4, i = s * 47 + 3;
  double x = s * 3.5, y = s * 7.25, z = s * 9.125;
  sink = a ^ c;
  dsink = x * y;
  if (s >= 0) longjmp(b, 1);
  sink = a + c + e + f + g + h + i;
  dsink = x + y + z;
}
int jregs(int s) {
  int a = s * 3 + 1, c = s * 5 + 2, e = s * 7 + 3, f = s * 11 + 4, g = s * 13 + 5, h = s * 17 + 6, i = s * 19 + 7;
  double x = s * 0.5, y = s * 0.25 + 1.0, z = s * 0.125 + 2.0;
  if (setjmp(b)) {
    if (a + c + e + f + g + h + i != s * 75 + 28) return 104;
    return x + y + z == s * 0.875 + 3.0 ? 1 : 105;
  }
  deep(s);
  return 106;
}
#ifdef __arm__
void clob(void);
int jfp(void) {
  if (setjmp(b)) return 1;
  clob();
  return 107;
}
void jump(void) { longjmp(b, 1); }
#endif
