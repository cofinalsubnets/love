/* add and subtract with the carry: the kernel's array_index_mask_nospec (`cmp; sbb %0,%0`,
 * all ones below the bound, 0 at or past it), a 128-bit add as add then adc, sbb and adc
 * against an immediate, and sbb into memory. every width. the asm is x64's. held to gcc. */

#if defined(__x86_64__)
static unsigned long mask(unsigned long index, unsigned long size) {
  unsigned long m;
  asm("cmp %1,%2; sbb %0,%0;" : "=r"(m) : "g"(size), "r"(index) : "cc");
  return m;
}
static void add128(unsigned long *lo, unsigned long *hi, unsigned long blo, unsigned long bhi) {
  asm("addq %2, %0\n\tadcq %3, %1" : "+r"(*lo), "+r"(*hi) : "r"(blo), "r"(bhi) : "cc");
}
static unsigned borrowimm(unsigned a, unsigned b) {
  unsigned r = 100;
  asm("cmpl %2, %1\n\tsbbl $7, %0" : "+r"(r) : "r"(a), "r"(b) : "cc");
  return r;
}
static unsigned short w16(unsigned short x) {
  asm("stc\n\tadcw $1000, %0" : "+r"(x) : : "cc");
  return x;
}
static unsigned char w8(unsigned char x) {
  asm("stc\n\tsbbb $3, %0" : "+q"(x) : : "cc");
  return x;
}
static long memsbb(long v, long k) {
  asm("stc\n\tsbbq %1, %0" : "+m"(v) : "r"(k) : "cc");
  return v;
}
#else
static unsigned long mask(unsigned long index, unsigned long size) { return index < size ? ~0UL : 0; }
static void add128(unsigned long *lo, unsigned long *hi, unsigned long blo, unsigned long bhi) {
  unsigned long l = *lo + blo; *hi += bhi + (l < blo); *lo = l;
}
static unsigned borrowimm(unsigned a, unsigned b) { return 100 - 7 - (a < b); }
static unsigned short w16(unsigned short x) { return x + 1001; }
static unsigned char w8(unsigned char x) { return x - 4; }
static long memsbb(long v, long k) { return v - k - 1; }
#endif

int main(void) {
  int bad = 0;
  if (mask(3, 10) != ~0UL || mask(10, 10) != 0 || mask(11, 10) != 0) bad |= 1;
  unsigned long lo = ~0UL, hi = 5;
  add128(&lo, &hi, 1, 2);
  if (lo != 0 || hi != 8) bad |= 2;
  if (borrowimm(1, 2) != 92 || borrowimm(2, 1) != 93) bad |= 4;
  if (w16(5) != 1006 || w8(10) != 6) bad |= 8;
  if (memsbb(50, 8) != 41) bad |= 16;
  return bad;
}
