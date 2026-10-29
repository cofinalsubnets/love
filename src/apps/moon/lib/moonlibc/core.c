/* moonlibc's floor: the entry, auxv, -pie relocation, errno, stdio handles */
#include "impl.h"

char **environ;
static long *__auxv;

int __errno_v;   /* one int: love is single-threaded */
int *__errno_location(void) { return &__errno_v; }

typedef struct __mhdr { struct __mhdr *next; size_t size; } __mhdr;   /* size in 16-byte units */

char const *__love_progname = "";   /* argv[0], for gnulib's progname */

FILE *stdin = &__stdf[0], *stdout = &__stdf[1], *stderr = &__stdf[2];

/* load bias: AT_PHDR - 64 - the p_offset==0 PT_LOAD's p_vaddr; 0 for ET_EXEC, the slide for -pie;
 * dyld's on macos. a_type reads its low word: netbsd's AuxInfo is {u32 type, pad, u64} with the pad unzeroed */
static unsigned long __love_bias(void) {
#ifdef LvMac
  if (__love_osv == 4) return __love_macslide();
#endif
  unsigned long phdr = 0; ElfW(Half) phnum = 0;
  for (long *a = __auxv; a && (unsigned int) a[0]; a += 2) {
    if ((unsigned int) a[0] == 3) phdr = (unsigned long) a[1];   /* AT_PHDR */
    if ((unsigned int) a[0] == 5) phnum = (ElfW(Half)) a[1]; }   /* AT_PHNUM */
  if (!phdr) return 0;
  ElfW(Phdr) const *ph = (ElfW(Phdr) const *) phdr;
  for (ElfW(Half) i = 0; i < phnum; i++)
    if (ph[i].p_type == PT_LOAD && ph[i].p_offset == 0)
      return phdr - sizeof(ElfW(Ehdr)) - (unsigned long) ph[i].p_vaddr;
  return 0; }

/* -pie: the linker leaves each abs64 data pointer at its base-0 offset, its sites listed
 * in love_rela; add the bias to each. ET_EXEC links an empty table */
extern long __start_love_rela[], __stop_love_rela[];
static void __love_reloc(void) {
  unsigned long bias = __love_bias();
  for (long *p = __start_love_rela; p < __stop_love_rela; p++)
    *(unsigned long *) (bias + (unsigned long) *p) += bias; }

/* x64's thread template, variant II: a thread's copy ends at its thread pointer, whose first
 * word points at itself; the template's tail past its file bytes is the .tbss, zeroed */
void __love_tlscopy(void *tp) {
  char *b = (char *) tp - __love_mt.tlsblk;
  memcpy(b, __love_mt.tlsimg, __love_mt.tlsfile);
  memset(b + __love_mt.tlsfile, 0, __love_mt.tlsblk - __love_mt.tlsfile);
  *(void **) tp = tp; }

/* a program with a pt_tls gets the main thread's copy, the thread pointer set at its end;
 * one without keeps the main thread's at 0 */
static void __love_tlsinit(void) {
#if defined(__x86_64__)
  unsigned long phdr = 0, phnum = 0;
  for (long *a = __auxv; a && (unsigned int) a[0]; a += 2) {
    if ((unsigned int) a[0] == 3) phdr = (unsigned long) a[1];   /* AT_PHDR */
    if ((unsigned int) a[0] == 5) phnum = (unsigned long) a[1]; }   /* AT_PHNUM */
  ElfW(Phdr) const *ph = (ElfW(Phdr) const *) phdr, *t = 0;
  for (unsigned long i = 0; ph && i < phnum; i++)
    if (ph[i].p_type == PT_TLS && ph[i].p_memsz) t = &ph[i];
  if (!t) return;
  unsigned long al = t->p_align > 1 ? (unsigned long) t->p_align : 1;
  __love_mt.tlsimg = (char const *) (__love_bias() + (unsigned long) t->p_vaddr);
  __love_mt.tlsfile = (unsigned long) t->p_filesz;
  __love_mt.tlsblk = ((unsigned long) t->p_memsz + al - 1) / al * al;
  __love_mt.tlsalign = al;
  char *m = mmap(0, (long) (__love_mt.tlsblk + 64), PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
  if (m == (char *) -1) { sc1(NR_exit_group, 127); }
  void *tp = m + __love_mt.tlsblk;
  __love_tlscopy(tp);
  __love_mt.mtp = tp;
  if (__love_osv == 2) fb2(165, 129, (long) &tp);             /* sysarch(AMD64_SET_FSBASE) */
  else if (__love_osv == 3) fb1(317, (long) tp);              /* _lwp_setprivate */
  else sc2(NR_arch_prctl, 0x1002, (long) tp);                 /* ARCH_SET_FS */
#endif
}

unsigned long getauxval(unsigned long t) {
  for (long *a = __auxv; a && (unsigned int) a[0]; a += 2)
    if ((unsigned int) a[0] == t) return (unsigned long) a[1];
  return 0; }

/* one callback, for the main program, carrying the load bias; macos has no phdrs */
int dl_iterate_phdr(int (*cb)(struct dl_phdr_info *, unsigned long, void *), void *data) {
  unsigned long phdr = 0, phnum = 0;
  for (long *a = __auxv; a && (unsigned int) a[0]; a += 2) {
    if ((unsigned int) a[0] == 3) phdr = (unsigned long) a[1];   /* AT_PHDR */
    if ((unsigned int) a[0] == 5) phnum = (unsigned long) a[1]; }   /* AT_PHNUM */
  if (!phdr && __love_osv != 4) return 0;
  struct dl_phdr_info in;
  memset(&in, 0, sizeof in);
  in.dlpi_addr = __love_bias();
  in.dlpi_name = "";
  in.dlpi_phdr = (ElfW(Phdr) const *) phdr;
  in.dlpi_phnum = (ElfW(Half)) phnum;
  return cb(&in, sizeof in, data); }

/* overrides crt0's weak call-main tail. sp is the arg vector (argc at [0]);
 * osv is crt0's kernel guess, 0 where it has none */
void __love_start(long *sp, long osv) {
  __love_osv = osv ? osv : __love_osdetect();
  long argc = sp[0];
  char **argv = (char **) (sp + 1);
  char **e = argv + argc + 1;
  if (argc > 0 && argv[0]) __love_progname = argv[0];
  environ = e;
  while (*e) e++;
  __auxv = osv == 4 ? 0 : (long *) (e + 1);   /* macos lays its apple strings there */
  __love_reloc();   /* before any data pointer is read */
  __love_tlsinit();
  stdout->fd = 1;
  stdout->wr = 1;
  stdout->buf = __obuf;
  stdout->cap = sizeof __obuf;
  stdout->line = isatty(1);
  stderr->fd = 2;
  stderr->wr = 1;
  stdin->rb = __ibuf;
  stdin->rcap = sizeof __ibuf;
  exit(main((int) argc, argv)); }

