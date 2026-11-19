/* o32 REL objects for holo's link, beside mipsrela.s's fields: clang or gcc -fno-pic -mno-abicalls
   -G0 lay this, its calls by R_MIPS_26 to a local, an archive member's global (mipsrelb.c) and a
   mooncc object's (mipsrelm.c), its data words by R_MIPS_32. 42 when every address agrees, 100+n
   at the first that does not */
extern int ext[8];
extern int bump(int);
extern int mo(int);
extern void *relhi(int);
extern void *relwd[32];
extern int reljal(void);
char relbig[0x20000];
__attribute__((noinline)) static int twice(int x) { return 2 * x; }
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
  relbig[0x9ff8] = 5;
  if (*(char *)relwd[2] != 5) return 137;
  return 42;
}
