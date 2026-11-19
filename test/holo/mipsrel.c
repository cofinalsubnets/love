/* o32 REL objects for holo's link, beside mipsrela.s's fields: clang or gcc -fno-pic -mno-abicalls
   -G0 lay this, its calls by R_MIPS_26 to a local, an archive member's global (mipsrelb.c) and a
   mooncc object's (mipsrelm.c), its data words by R_MIPS_32; laid -fpic, the same reach goes
   through the got (GOT16 a page for sq and mipsrelg.s's probes, CALL16 and JALR, pick's table by
   GPREL32). 42 when every address agrees, 100+n
   at the first that does not */
extern int ext[8];
extern int bump(int);
extern int mo(int);
extern void *relhi(int);
extern void *relwd[32];
extern int reljal(void);
#ifdef __PIC__
extern void *relgot(int);
extern void *relgwd[16];
#endif
char relbig[0x20000];
static int sq[3] = {1, 4, 9};
volatile int two = 2;
__attribute__((noinline)) static int twice(int x) { return 2 * x; }
__attribute__((noinline)) static int pick(int x) {   /* a jump table, GPREL32 words laid -fpic */
  switch (x) {
  case 0: return mo(x + 7); case 1: return bump(x); case 2: return twice(x + 9);
  case 3: return mo(x) + 1; case 4: return bump(x) - 1; case 5: return twice(x) - 3;
  case 6: return mo(x) - 1; default: return 0; }
}
int (*fns[])(int) = {twice, bump, mo};
int *pe[] = {ext + 3, (int *)((char *)ext - 4)};
int cc_main(void) {
  for (int i = 0; i < 32; i++)
    if (relhi(i) != relwd[i]) return 100 + i;
  for (int k = 0; k < 16; k++)
    if (relwd[k] != relbig + 0x1000 * k + 0x7ff8) return 132;
  if (reljal() != 26) return 133;
  if (twice(bump(3)) != 26 || fns[0](fns[1](3)) != 26) return 134;
  if (mo(ext[2]) != 6 || fns[2](2) != 6) return 135;
  if (*pe[0] != 3 || pe[1] + 1 != ext) return 136;
#ifdef __PIC__
  for (int i = 0; i < 16; i++)
    if (relgot(i) != relgwd[i]) return 140;
#endif
  sq[two] += two;
  if (sq[2] != 11) return 138;
  for (int i = 0; i < 7; i++)
    if (pick(two + i - 2) != (int[]){21, 11, 22, 10, 13, 7, 17}[i]) return 139;
  relbig[0x9ff8] = 5;
  if (*(char *)relwd[2] != 5) return 137;
  return 42;
}
