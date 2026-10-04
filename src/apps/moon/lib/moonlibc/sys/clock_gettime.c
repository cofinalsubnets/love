#include "../impl.h"

/* linux answers the clock from the vdso without entering the kernel, and love's
 * scheduler reads it every switch. the elf64 seats only; a vdso that is not there
 * or refuses leaves the call to the kernel. */
#if defined(__x86_64__) || defined(__aarch64__) || defined(__riscv)
# define LvVdso 1
typedef int (*cgtfn)(long, struct timespec *);
typedef struct { Elf64_Word name; unsigned char info, other; Elf64_Half shndx;
                 Elf64_Addr value; Elf64_Xword size; } vsym;

static cgtfn vdso_cgt(void) {
  Elf64_Ehdr const *eh = (Elf64_Ehdr const *) getauxval(33);    /* AT_SYSINFO_EHDR */
  if (!eh) return 0;
  Elf64_Phdr const *ph = (Elf64_Phdr const *) ((char const *) eh + eh->e_phoff);
  unsigned long bias = 0, dv = 0;
  for (Elf64_Half i = 0; i < eh->e_phnum; i++) {
    if (ph[i].p_type == PT_LOAD && ph[i].p_offset == 0)
      bias = (unsigned long) eh - ph[i].p_vaddr;
    if (ph[i].p_type == 2) dv = ph[i].p_vaddr; }                /* PT_DYNAMIC */
  if (!dv) return 0;
  char const *str = 0; vsym const *sym = 0; Elf64_Word const *hash = 0;
  for (long const *d = (long const *) (bias + dv); d[0]; d += 2)
    if (d[0] == 5) str = (char const *) (bias + d[1]);          /* DT_STRTAB */
    else if (d[0] == 6) sym = (vsym const *) (bias + d[1]);     /* DT_SYMTAB */
    else if (d[0] == 4) hash = (Elf64_Word const *) (bias + d[1]);   /* DT_HASH: nchain is the count */
  if (!str || !sym || !hash) return 0;
  for (Elf64_Word i = 0; i < hash[1]; i++)
    if (sym[i].shndx && (sym[i].info & 15) == 2                 /* defined STT_FUNC */
        && (!strcmp(str + sym[i].name, "__vdso_clock_gettime")
            || !strcmp(str + sym[i].name, "__kernel_clock_gettime")))
      return (cgtfn) (bias + sym[i].value);
  return 0; }
#endif

int clock_gettime(int ck, struct timespec *ts) {
#ifdef LvVdso
  static cgtfn cgt;
  static int probed;
  if (__love_osv == 1) {
    if (!probed) cgt = vdso_cgt(), probed = 1;
    if (cgt && !cgt(ck, ts)) return 0; }
#endif
  if (__love_osv == 2) {
    /* the clockids part: REALTIME 0 agrees; MONOTONIC is 4 there (1 is
     * CLOCK_VIRTUAL), PROCESS_CPUTIME_ID 15, THREAD_CPUTIME_ID 14. */
    if (ck == 1) ck = 4;
    else if (ck == 2) ck = 15;
    else if (ck == 3) ck = 14; }
  else if (__love_osv == 3) {
    /* netbsd: MONOTONIC 3; the cputime ids are flag words */
    if (ck == 1) ck = 3;
    else if (ck == 2) ck = 0x40000000;
    else if (ck == 3) ck = 0x20000000; }
  return (int) er(sc2(NR_clock_gettime, ck, (long) ts)); }
