/* mov to and from a segment register, a register or memory at the other end: the kernel's
 * iret_to_self (mov %ss / %cs, r) and the real-mode helpers' movw over "rm" (%ds %fs %gs).
 * a user process reads its selectors (RPL 3 on cs and ss) and writes es back with its own
 * value. the asm is x64's. held to gcc. */

#if defined(__x86_64__)
static unsigned rd_cs(void) { unsigned v; asm volatile("mov %%cs, %0" : "=r"(v)); return v & 0xffff; }
static unsigned rd_ss(void) { unsigned v; asm volatile("mov %%ss, %0" : "=r"(v)); return v & 0xffff; }
static unsigned short rdm_cs(void) { unsigned short v; asm volatile("movw %%cs, %0" : "=m"(v)); return v; }
static unsigned short rd_es(void) { unsigned short v; asm volatile("movw %%es, %0" : "=rm"(v)); return v; }
static void wr_es(unsigned short v) { asm volatile("movw %0, %%es" : : "r"(v)); }
static void wrm_es(unsigned short v) { asm volatile("movw %0, %%es" : : "m"(v)); }
#else
static unsigned rd_cs(void) { return 0x33; }
static unsigned rd_ss(void) { return 0x2b; }
static unsigned short rdm_cs(void) { return 0x33; }
static unsigned short rd_es(void) { return 0; }
static void wr_es(unsigned short v) { (void)v; }
static void wrm_es(unsigned short v) { (void)v; }
#endif

int main(void) {
  int bad = 0;
  unsigned cs = rd_cs(), ss = rd_ss();
  if ((cs & 3) != 3 || (ss & 3) != 3 || cs == ss) bad |= 1;
  if (rdm_cs() != cs) bad |= 2;
  unsigned short es = rd_es();
  wr_es(es);
  wrm_es(es);
  if (rd_es() != es) bad |= 4;
  return bad;
}
