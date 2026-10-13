// src/inle/x64/proc.c -- a process on x64: a program in an address space of its own, the lower
// half, run in ring 3. its `syscall` comes back through LSTAR (mkvec.l) to k_proc_call, as a
// wasm process's calls come through the page; the kernel's half is shared and supervisor-only.
// the caller that starts one waits inside the start until the program is done.
#include "../../apps/moon/lib/moonlibc/impl.h"
#include <stdint.h>
#include <stdbool.h>
#include <elf.h>
#include <sys/utsname.h>
#include "asmops.h"

extern uintptr_t khhdm;
extern void *kmallocw(uintptr_t n), kfree(void *p);
extern long k_proc_call(long pid, long n, long a, long b, long c, long d, long e, long f);
extern void k_uenter(void *c), k_uexit(void *c) __attribute__((noreturn));
extern uint64_t k_cpu[4];                  // mkvec.l: [0] the kernel stack, [2] the running process
extern uint8_t k_tss[104];                 // ..and the TSS, rsp0 at 4

#define K_RESTART -512                     // sys.c's: the call must wait, and is asked again
#define k_ustack (1u << 20)                // a process's stack
#define k_kstack (64u << 10)               // ..and the kernel's, under its calls and interrupts
#define k_utop 0x7ffffffff000ull           // the stack's top, the lower half's last page
#define k_upie 0x10000000ull               // where a position-independent program goes

// one process's machine: the five words mkvec.l reads first, then what the kernel keeps --
// its blocks, freed at the end, and its regions, which every pointer it hands over must be in
struct k_ureg { uint64_t lo, hi; };
struct k_uctx {
  uint64_t cr3, pc, sp, ksp, kcr3;
  long pid;
  uint64_t *pml4;
  void **blk;
  int nblk, cblk, nreg;
  struct k_ureg reg[16]; };

// the syscall frame k_syscall_entry lays, lowest first
struct k_sysf { uint64_t nr, di, si, dx, r10, r8, r9, cx, r11, sp; };

static uint64_t k_pa(void const *p) { return (uint64_t) (uintptr_t) p - khhdm; }
static uint64_t *k_va(uint64_t pa) { return (uint64_t*) (uintptr_t) (pa + khhdm); }

// n bytes, page-aligned and zeroed, kept on c's list -> them; NULL when the heap refuses
static void *k_ublk(struct k_uctx *c, uint64_t n) {
  if (c->nblk == c->cblk) {
    int m = c->cblk ? 2 * c->cblk : 16;
    void **t = kmallocw((uintptr_t) m);
    if (!t) return NULL;
    for (int i = 0; i < c->nblk; i++) t[i] = c->blk[i];
    if (c->blk) kfree(c->blk);
    c->blk = t, c->cblk = m; }
  void *raw = kmallocw((uintptr_t) ((n + 4096 + 7) / 8));
  if (!raw) return NULL;
  c->blk[c->nblk++] = raw;
  uint8_t *p = (uint8_t*) (((uintptr_t) raw + 4095) & ~(uintptr_t) 4095);
  memset(p, 0, (size_t) n);
  return p; }

// the page-table entry for va, its tables laid on the way down -> it; NULL out of room
static uint64_t *k_upte(struct k_uctx *c, uint64_t va) {
  uint64_t *t = c->pml4;
  for (int sh = 39; sh > 12; sh -= 9) {
    uint64_t *e = &t[va >> sh & 511];
    if (!(*e & 1)) {
      uint64_t *n = k_ublk(c, 4096);
      if (!n) return NULL;
      *e = k_pa(n) | 7; }                 // present, writable, the process's
    t = k_va(*e & 0x000ffffffffff000ull); }
  return &t[va >> 12 & 511]; }

// lo..hi mapped, each page not yet mapped taken from one block; fl's write and execute laid
// over whatever a shared page already has -> 0, or -ENOMEM
static long k_umap(struct k_uctx *c, uint64_t lo, uint64_t hi, bool w, bool x) {
  lo &= ~4095ull, hi = (hi + 4095) & ~4095ull;
  uint8_t *b = k_ublk(c, hi - lo);
  if (!b) return -ENOMEM;
  for (uint64_t va = lo; va < hi; va += 4096) {
    uint64_t *e = k_upte(c, va);
    if (!e) return -ENOMEM;
    uint64_t f = *e & 1 ? *e : k_pa(b + (va - lo)) | 5 | 1ull << 63;
    if (w) f |= 2;
    if (x) f &= ~(1ull << 63);
    *e = f; }
  if (c->nreg < 16) c->reg[c->nreg++] = (struct k_ureg) { lo, hi };
  return 0; }

// where the kernel reaches va of c's, the page mapped
static uint8_t *k_ukva(struct k_uctx *c, uint64_t va) {
  uint64_t *e = k_upte(c, va);
  return (uint8_t*) k_va(*e & 0x000ffffffffff000ull) + (va & 4095); }

static void k_ucopy(struct k_uctx *c, uint64_t va, void const *s, uint64_t n) {
  for (uint64_t i = 0; i < n; i++) *k_ukva(c, va + i) = ((uint8_t const*) s)[i]; }

// does p..p+n lie in c's memory?
static bool k_uok(struct k_uctx const *c, uint64_t p, uint64_t n) {
  if (p + n < p) return false;
  for (int i = 0; i < c->nreg; i++)
    if (c->reg[i].lo <= p && p + n <= c->reg[i].hi) return true;
  return !n; }

// a string of c's, its NUL inside its region
static bool k_ustr(struct k_uctx const *c, uint64_t p) {
  for (int i = 0; i < c->nreg; i++)
    if (c->reg[i].lo <= p && p < c->reg[i].hi)
      return memchr((void*) (uintptr_t) p, 0, (size_t) (c->reg[i].hi - p)) != NULL;
  return false; }

// the memory a call's pointers name, in the process's own, before the kernel touches it:
// 0, or -EFAULT. a call this does not know answers -ENOSYS, so nothing unchecked reaches
// k_proc_call
static long k_uargs(struct k_uctx const *c, long n, uint64_t a, uint64_t b, uint64_t d,
                    uint64_t e, uint64_t f, uint64_t g) {
  bool ok;
  switch (n) {
   case NR_read: case NR_write: case 17: case 18:          // pread64, pwrite64
   case NR_getdents64:
    ok = k_uok(c, b, d); break;
   case 19: case 20:                                       // readv, writev
    ok = k_uok(c, b, d * sizeof(struct iovec));
    for (uint64_t i = 0; ok && i < d; i++) {
      struct iovec const *v = (struct iovec const*) (uintptr_t) b + i;
      ok = k_uok(c, (uint64_t) (uintptr_t) v->iov_base, v->iov_len); }
    break;
   case NR_getcwd: ok = k_uok(c, a, b); break;
   case NR_fstat: ok = k_uok(c, b, sizeof(struct stat)); break;
   case NR_newfstatat: ok = k_ustr(c, b) && k_uok(c, d, sizeof(struct stat)); break;
   case NR_openat: case NR_unlinkat: case NR_mkdirat: case NR_fchmodat: case NR_faccessat:
    ok = k_ustr(c, b); break;
   case NR_readlinkat: ok = k_ustr(c, b) && k_uok(c, d, e); break;
   case NR_renameat: ok = k_ustr(c, b) && k_ustr(c, e); break;
   case NR_chdir: ok = k_ustr(c, a); break;
   case NR_ioctl:                                          // sys.c's: TCGETS, TCSETS*, TIOC[GS]PGRP
    ok = 21505 <= b && b <= 21508 ? k_uok(c, d, sizeof(struct termios))
       : b == TIOCGWINSZ || b == TIOCSWINSZ ? k_uok(c, d, sizeof(struct winsize))
       : b == 21519 || b == 21520 ? k_uok(c, d, sizeof(int))
       : true;                                             // the rest answer EINVAL untouched
    break;
   case NR_pipe2: ok = k_uok(c, a, 2 * sizeof(int)); break;
   case NR_wait4: ok = !b || k_uok(c, b, sizeof(int)); break;
   case NR_ppoll: ok = k_uok(c, a, b * sizeof(struct pollfd)); break;
   case NR_clock_gettime: ok = k_uok(c, b, sizeof(struct timespec)); break;
   case NR_uname: ok = k_uok(c, a, sizeof(struct utsname)); break;
   case NR_inle_spawn: ok = k_uok(c, a, b) && k_uok(c, d, e) && k_uok(c, f, g); break;
   case NR_fcntl: ok = b == F_DUPFD || b == F_DUPFD_CLOEXEC || b == F_GETFD || b == F_SETFD
                       || b == F_GETFL || b == F_SETFL; break;
   case NR_exit: case NR_exit_group: case NR_getpid: case 110: case NR_kill: case NR_close:
   case NR_lseek: case NR_ftruncate: case NR_dup3: case 32: case 33:    // getppid, dup, dup2
    ok = true; break;
   default: return -ENOSYS; }
  return ok ? 0 : -EFAULT; }

// a call from the running process (k_syscall_entry, IF masked) -> its answer. a call that
// must wait waits here, the machine halted between interrupts; a process its call ended
// goes back to whoever started it
long k_syscall(struct k_sysf *f) {
  struct k_uctx *c = (struct k_uctx*) (uintptr_t) k_cpu[2];
  long n = (long) f->nr, r = k_uargs(c, n, f->di, f->si, f->dx, f->r10, f->r8, f->r9);
  if (n == 32 || n == 33) n = NR_dup3, f->dx = 0;          // dup2's flags; dup lands anywhere
  if (!r) while ((r = k_proc_call(c->pid, n, (long) f->di, (long) f->si, (long) f->dx,
                                  (long) f->r10, (long) f->r8, (long) f->r9)) == K_RESTART)
    k_sti(), k_wait(), k_cli();
  if (k_proc_call(c->pid, NR_getpid, 0, 0, 0, 0, 0, 0) < 0) k_uexit(c);
  return r; }

// a fault in the running process (k_exception, from ring 3): it ends as linux's signal would
void k_proc_fault(uint64_t vector) {
  struct k_uctx *c = (struct k_uctx*) (uintptr_t) k_cpu[2];
  long sig = vector == 6 ? SIGILL : vector == 0 || vector == 16 || vector == 19 ? SIGFPE
           : vector == 3 ? SIGTRAP : SIGSEGV;
  k_proc_call(c->pid, NR_kill, 0, sig, 0, 0, 0, 0);
  k_uexit(c); }

// the initial stack, linux's: argc, argv, NULL, envp, NULL, auxv, then the strings -> the
// stack pointer, 16-aligned at argc
static uint64_t k_ustack_lay(struct k_uctx *c, char const *av, uintptr_t an,
                             char const *ev, uintptr_t en, uint64_t phdr, uint64_t phn) {
  uint64_t s = k_utop - an - en, ac = 0, ec = 0;
  k_ucopy(c, s, av, an), k_ucopy(c, s + an, ev, en);
  for (uintptr_t i = 0; i < an; i++) ac += !av[i];
  for (uintptr_t i = 0; i < en; i++) ec += !ev[i];
  uint64_t aux[] = { 3, phdr, 4, sizeof(Elf64_Phdr), 5, phn, 6, 4096, 0, 0 },   // AT_PHDR,
                                                     // AT_PHENT, AT_PHNUM, AT_PAGESZ, AT_NULL
           nw = 1 + ac + 1 + ec + 1 + sizeof aux / 8,
           sp = (s - nw * 8) & ~15ull, w = sp;
  k_ucopy(c, w, &ac, 8), w += 8;
  for (uint64_t i = 0, o = s; i < ac; i++, w += 8) {
    k_ucopy(c, w, &o, 8);
    while (av[o - s]) o++;
    o++; }
  w += 8;
  for (uint64_t i = 0, o = s + an; i < ec; i++, w += 8) {
    k_ucopy(c, w, &o, 8);
    while (ev[o - s - an]) o++;
    o++; }
  w += 8;
  k_ucopy(c, w, aux, sizeof aux);
  return sp; }

// the program's ELF laid in c's memory -> 0, the entry in c->pc; -ENOEXEC for one this
// machine cannot run
static long k_uload(struct k_uctx *c, uint8_t const *e, uintptr_t n, uint64_t *phdr, uint64_t *phn) {
  Elf64_Ehdr const *h = (Elf64_Ehdr const*) e;
  if (n < sizeof *h || memcmp(e, ELFMAG, SELFMAG) || e[EI_CLASS] != ELFCLASS64
      || e[EI_DATA] != ELFDATA2LSB || h->e_machine != EM_X86_64
      || (h->e_type != ET_EXEC && h->e_type != ET_DYN)
      || h->e_phentsize != sizeof(Elf64_Phdr) || h->e_phoff > n
      || h->e_phnum > (n - h->e_phoff) / sizeof(Elf64_Phdr)) return -ENOEXEC;
  uint64_t base = h->e_type == ET_DYN ? k_upie : 0;
  Elf64_Phdr const *ph = (Elf64_Phdr const*) (e + h->e_phoff);
  *phdr = 0, *phn = h->e_phnum;
  for (int i = 0; i < h->e_phnum; i++) {
    Elf64_Phdr const *p = &ph[i];
    if (p->p_type != PT_LOAD) continue;
    uint64_t lo = base + p->p_vaddr, hi = lo + p->p_memsz;
    if (p->p_filesz > p->p_memsz || p->p_offset > n || p->p_filesz > n - p->p_offset
        || hi < lo || hi > k_utop - k_ustack) return -ENOEXEC;
    long r = k_umap(c, lo, hi, p->p_flags & PF_W, p->p_flags & PF_X);
    if (r) return r;
    k_ucopy(c, lo, e + p->p_offset, p->p_filesz);
    if (p->p_offset <= h->e_phoff && h->e_phoff < p->p_offset + p->p_filesz)
      *phdr = lo + (h->e_phoff - p->p_offset); }
  c->pc = base + h->e_entry;
  return k_uok(c, c->pc, 1) ? 0 : -ENOEXEC; }

// the seat's door (sys.c): pid's program, the ELF in code, run on argv av and environment ev
// until it is done -> 0, its status kept by its exit or its fault; -errno where it never ran.
// a word without code is love's, which runs as no x64 process yet
long k_proc_start(long pid, char const *av, uintptr_t an, char const *ev, uintptr_t en,
                  char const *code, uintptr_t cn) {
  if (!code) return -ENOSYS;
  struct k_uctx *c = kmallocw((sizeof *c + 7) / 8);
  if (!c) return -ENOMEM;
  memset(c, 0, sizeof *c);
  c->pid = pid;
  uint64_t phdr, phn, ks = 0;
  long r = (c->pml4 = k_ublk(c, 4096)) ? 0 : -ENOMEM;
  if (!r) {                                       // the kernel's half, shared
    uint64_t const *k = k_va(k_rd_cr3() & 0x000ffffffffff000ull);
    for (int i = 256; i < 512; i++) c->pml4[i] = k[i];
    c->cr3 = k_pa(c->pml4);
    r = k_uload(c, (uint8_t const*) code, cn, &phdr, &phn); }
  if (!r) r = k_umap(c, k_utop - k_ustack, k_utop, true, false);
  uint8_t *kst = r ? NULL : k_ublk(c, k_kstack);
  if (!r && !kst) r = -ENOMEM;
  if (!r) {
    c->sp = k_ustack_lay(c, av, an, ev, en, phdr, phn);
    ks = (uint64_t) (uintptr_t) (kst + k_kstack);
    uint64_t was[3] = { k_cpu[0], k_cpu[2], 0 };
    memcpy(&was[2], k_tss + 4, 8);                // a process starting a process: nested
    k_cpu[0] = ks, k_cpu[2] = (uint64_t) (uintptr_t) c;
    memcpy(k_tss + 4, &ks, 8);
    k_uenter(c);
    k_cpu[0] = was[0], k_cpu[2] = was[1];
    memcpy(k_tss + 4, &was[2], 8); }
  for (int i = 0; i < c->nblk; i++) kfree(c->blk[i]);
  if (c->blk) kfree(c->blk);
  kfree(c);
  return r; }
