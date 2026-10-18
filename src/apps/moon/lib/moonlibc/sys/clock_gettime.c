#include "../impl.h"
#include <sys/resource.h>

/* linux answers from the vdso when it can; a 32-bit target wants the time64 name,
 * since its plain __vdso_clock_gettime fills the 32-bit record */
#if defined(__x86_64__) || defined(__aarch64__) || defined(__riscv)
# define LvVdso 1
typedef Elf64_Ehdr vehdr; typedef Elf64_Phdr vphdr; typedef Elf64_Word vword;
typedef struct { Elf64_Word st_name; unsigned char st_info, st_other; Elf64_Half st_shndx;
                 Elf64_Addr st_value; Elf64_Xword st_size; } vsym;
#elif defined(__ILP32__)
# define LvVdso 1
typedef Elf32_Ehdr vehdr; typedef Elf32_Phdr vphdr; typedef Elf32_Word vword;
typedef struct { Elf32_Word st_name; Elf32_Addr st_value; Elf32_Word st_size;
                 unsigned char st_info, st_other; Elf32_Half st_shndx; } vsym;
#endif
#ifdef LvVdso
typedef int (*cgtfn)(long, struct timespec *);

static int cgtname(char const *s) {
#ifdef __ILP32__
  return !strcmp(s, "__vdso_clock_gettime64");
#else
  return !strcmp(s, "__vdso_clock_gettime") || !strcmp(s, "__kernel_clock_gettime");
#endif
}

static cgtfn vdso_cgt(void) {
  vehdr const *eh = (vehdr const *) getauxval(33);              /* AT_SYSINFO_EHDR */
  if (!eh) return 0;
  vphdr const *ph = (vphdr const *) ((char const *) eh + eh->e_phoff);
  unsigned long bias = 0, dv = 0;
  for (unsigned i = 0; i < eh->e_phnum; i++) {
    if (ph[i].p_type == PT_LOAD && ph[i].p_offset == 0)
      bias = (unsigned long) eh - ph[i].p_vaddr;
    if (ph[i].p_type == 2) dv = ph[i].p_vaddr; }                /* PT_DYNAMIC */
  if (!dv) return 0;
  char const *str = 0; vsym const *sym = 0; vword const *hash = 0;
  for (long const *d = (long const *) (bias + dv); d[0]; d += 2)
    if (d[0] == 5) str = (char const *) (bias + d[1]);          /* DT_STRTAB */
    else if (d[0] == 6) sym = (vsym const *) (bias + d[1]);     /* DT_SYMTAB */
    else if (d[0] == 4) hash = (vword const *) (bias + d[1]);   /* DT_HASH: nchain is the count */
  if (!str || !sym || !hash) return 0;
  for (vword i = 0; i < hash[1]; i++)
    if (sym[i].st_shndx && (sym[i].st_info & 15) == 2           /* defined STT_FUNC */
        && cgtname(str + sym[i].st_name))
      return (cgtfn) (bias + sym[i].st_value);
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
#ifdef LvMac
  if (__love_osv == 4) {
    /* xnu has no clock_gettime: gettimeofday's third word is mach_absolute_time,
     * nanoseconds on intel, and the cpu clocks are the process's rusage */
    if (ck == 2 || ck == 3) {
      struct rusage u;
      if (getrusage(0, &u) < 0) return -1;
      long us = (u.ru_utime.tv_sec + u.ru_stime.tv_sec) * 1000000L + u.ru_utime.tv_usec + u.ru_stime.tv_usec;
      ts->tv_sec = us / 1000000, ts->tv_nsec = us % 1000000 * 1000;
      return 0; }
    struct timeval tv;
    unsigned long long mt = 0;
    if (er(fb3(116, (long) &tv, 0, (long) &mt)) < 0) return -1;
    if (ck == 1) ts->tv_sec = (long) (mt / 1000000000), ts->tv_nsec = (long) (mt % 1000000000);
    else ts->tv_sec = tv.tv_sec, ts->tv_nsec = tv.tv_usec * 1000;
    return 0; }
#endif
  if (__love_osv == 2) {
    /* freebsd: MONOTONIC 4 (1 is VIRTUAL), PROCESS_CPUTIME 15, THREAD_CPUTIME 14 */
    if (ck == 1) ck = 4;
    else if (ck == 2) ck = 15;
    else if (ck == 3) ck = 14; }
  else if (__love_osv == 3) {
    /* netbsd: MONOTONIC 3; the cputime ids are flag words */
    if (ck == 1) ck = 3;
    else if (ck == 2) ck = 0x40000000;
    else if (ck == 3) ck = 0x20000000; }
  return (int) er(sc2(NR_clock_gettime, ck, (long) ts)); }
