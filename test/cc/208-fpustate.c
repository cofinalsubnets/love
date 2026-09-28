/* the fpu's state doors: fninit/fnclex/fwait/emms, the control and status words (fldcw,
 * fnstcw, fnstsw), mxcsr (ldmxcsr/stmxcsr), fildl onto the stack, and the whole-state saves
 * (fnsave/frstor, fxsave/fxrstor and their q forms, xsave/xrstor where the os enables them)
 * each read back through the control word they carry at offset 0. the privileged xsaves and
 * xrstors, and xsaveopt/xsavec, are laid but not run. the asm is x64's. held to gcc. */

#if defined(__x86_64__)
static unsigned short cw(void) {
  unsigned short c;
  asm volatile("fnstcw %0" : "=m"(c));
  return c;
}
static void setcw(unsigned short c) { asm volatile("fldcw %0" : : "m"(c)); }
static unsigned short sw(void) {
  unsigned short s;
  asm volatile("fnstsw %0" : "=m"(s));
  return s;
}
static unsigned csr(void) {
  unsigned m;
  asm volatile("stmxcsr %0" : "=m"(m));
  return m;
}
static void setcsr(unsigned m) { asm volatile("ldmxcsr %0" : : "m"(m)); }
static int top_after_fild(int v) {
  asm volatile("fninit\n\tfildl %0" : : "m"(v));
  int t = (sw() >> 11) & 7;
  asm volatile("fninit; fnclex; fwait; emms");
  return t;
}
static unsigned short nsave_cw(void) {
  unsigned char a[108] __attribute__((aligned(16)));
  asm volatile("fnsave %0; fwait" : "=m"(a));
  asm volatile("frstor %0" : : "m"(a));
  return a[0] | a[1] << 8;
}
static unsigned short fx_cw(int q) {
  unsigned char a[512] __attribute__((aligned(16)));
  if (q) asm volatile("fxsaveq %0" : "=m"(a));
  else asm volatile("fxsave %0" : "=m"(a));
  if (q) asm volatile("fxrstorq %0" : : "m"(a));
  else asm volatile("fxrstor %0" : : "m"(a));
  return a[0] | a[1] << 8;
}
static int osxsave(void) {
  unsigned a = 1, b, c = 0, d;
  asm("cpuid" : "+a"(a), "=b"(b), "+c"(c), "=d"(d));
  return (c >> 27) & 1;
}
static unsigned short xs_cw(unsigned short fallback) {
  static unsigned char a[4096] __attribute__((aligned(64)));
  if (!osxsave()) return fallback;
  asm volatile("xsave %0" : "+m"(a) : "a"(1), "d"(0));
  asm volatile("xrstor %0" : : "m"(a), "a"(1), "d"(0));
  asm volatile("xsaveq %0" : "+m"(a) : "a"(1), "d"(0));
  asm volatile("xrstorq %0" : : "m"(a), "a"(1), "d"(0));
  return a[0] | a[1] << 8;
}
void laid(unsigned char *a) {
  asm volatile("xsaves %0; xrstors %0; xsaveopt %0; xsavec %0" : "+m"(*a) : "a"(1), "d"(0));
  asm volatile("xsaves64 %0; xrstors64 %0; xsaveopt64 %0; xsavec64 %0" : "+m"(*a) : "a"(1), "d"(0));
}
#else
static unsigned short cwv = 0x37f;
static unsigned csrv = 0x1f80;
static unsigned short cw(void) { return cwv; }
static void setcw(unsigned short c) { cwv = c; }
static unsigned csr(void) { return csrv; }
static void setcsr(unsigned m) { csrv = m; }
static int top_after_fild(int v) { (void)v; return 7; }
static unsigned short nsave_cw(void) { return cwv; }
static unsigned short fx_cw(int q) { (void)q; return cwv; }
static unsigned short xs_cw(unsigned short f) { return f; }
#endif

int main(void) {
  int bad = 0;
  unsigned short c0 = cw();
  setcw(0x27f);
  if (cw() != 0x27f) bad |= 1;
  if (nsave_cw() != 0x27f) bad |= 2;
  setcw(0x27f);                                      /* fnsave reinitialised it */
  if (fx_cw(0) != 0x27f || fx_cw(1) != 0x27f) bad |= 4;
  if (xs_cw(0x27f) != 0x27f) bad |= 8;
  setcw(c0);
  if (cw() != c0) bad |= 16;
  unsigned m0 = csr();
  setcsr(m0 | 0x8000);                               /* flush to zero */
  if (csr() != (m0 | 0x8000)) bad |= 32;
  setcsr(m0);
  if (top_after_fild(42) != 7) bad |= 64;
  return bad;
}
