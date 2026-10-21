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

