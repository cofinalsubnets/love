// src/inle/x64/proc.c -- a process on x64: a program in an address space of its own, the lower
// half, run in ring 3. its `syscall` comes back through LSTAR (mkvec.l) to k_proc_call, as a
// wasm process's calls come through the page; the kernel's half is shared and supervisor-only.
// each has a kernel stack of its own, and runs a turn at a time from sys.c's pump: a turn ends
// at a call that must wait, at the timer, or at the end.
#include "../../apps/moon/lib/moonlibc/impl.h"
#include <stdint.h>
#include <stdbool.h>
#include <elf.h>
#include <sys/utsname.h>
#include "asmops.h"

extern uintptr_t khhdm;
extern void *kmallocwa(uintptr_t n, uintptr_t a), *k_grab(uintptr_t n);
extern void kfree(void *p), k_drop(void *p);
extern long k_proc_call(long pid, long n, long a, long b, long c, long d, long e, long f);
extern void k_kswap(uint64_t *save, uint64_t load), k_ufirst(void);
extern void **k_proc_seat(long pid);
extern uintptr_t const k_pie_base, k_pie_data;   // kmain.c, patched in by the projection
extern uintptr_t k_clock_ms(void);
extern uint64_t k_cpu[4];                  // mkvec.l: [0] the kernel stack, [2] the running process
extern uint8_t k_tss[104];                 // ..and the TSS, rsp0 at 4

#define K_RESTART -512                     // sys.c's: the call must wait, and is asked again
#define k_ustack (1u << 20)                // a process's stack
#define k_kstack (64u << 10)               // ..and the kernel's, under its calls and interrupts
#define k_utop 0x7ffffffff000ull           // the stack's top, the lower half's last page
#define k_upie 0x10000000ull               // where a position-independent program goes
#define k_slice 2                          // a turn, in timer ticks
#define k_umbase 0x100000000000ull         // where mmap lays the first mapping
#define k_xw 0xffffff8000000000ull         // k.h's image window: physical P runs at k_xw + P
#define k_ushared (1ull << 9)              // a page-table entry's own bit: the kernel's page, lent

// one process's machine: its pc and stack where k_ufirst reads them, the two kernel stacks a
// turn trades between, then what the kernel keeps -- its blocks, freed at the end, and its
// mappings, each its own block, freed when it goes. why: how its last turn ended
struct k_umm { uint64_t lo, hi; void *raw; };
struct k_uctx {
  uint64_t cr3, pc, sp, msp, psp, mnext;
  long pid;
  int why, slice;
  uint8_t *kst;
  uint64_t *pml4;
  void **blk;
  int nblk, cblk, nmm, cmm;
  struct k_umm *mm; };

// the syscall frame k_syscall_entry lays, lowest first
struct k_sysf { uint64_t nr, di, si, dx, r10, r8, r9, cx, r11, sp; };

static uint64_t k_pa(void const *p) { return (uint64_t) (uintptr_t) p - khhdm; }
static uint64_t *k_va(uint64_t pa) { return (uint64_t*) (uintptr_t) (pa + khhdm); }

// n bytes, page-aligned and zeroed -> them, *raw what frees them; NULL when the heap refuses
static void *k_uraw(uint64_t n, void **raw) {
  if (!(*raw = kmallocwa((uintptr_t) ((n + 7) / 8), 4096))) return NULL;
  memset(*raw, 0, (size_t) n);
  return *raw; }

// ..kept on c's list, freed at the end
static void *k_ublk(struct k_uctx *c, uint64_t n) {
  if (c->nblk == c->cblk) {
    int m = c->cblk ? 2 * c->cblk : 16;
    void **t = k_grab((uintptr_t) m * sizeof *t);
    if (!t) return NULL;
    for (int i = 0; i < c->nblk; i++) t[i] = c->blk[i];
    k_drop(c->blk);
    c->blk = t, c->cblk = m; }
  void *raw, *p = k_uraw(n, &raw);
  if (p) c->blk[c->nblk++] = raw;
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

// the page-table entry for va, if its tables are there -> it; NULL where they are not
static uint64_t *k_uwalk(struct k_uctx const *c, uint64_t va) {
  uint64_t *t = c->pml4;
  for (int sh = 39; sh > 12; sh -= 9) {
    uint64_t e = t[va >> sh & 511];
    if (!(e & 1)) return NULL;
    t = k_va(e & 0x000ffffffffff000ull); }
  return &t[va >> 12 & 511]; }

// lo..hi mapped, each page not yet mapped taken from b, or from one block of its own; write
// and execute laid over whatever a shared page already has -> 0, or -ENOMEM
static long k_umapb(struct k_uctx *c, uint64_t lo, uint64_t hi, bool w, bool x, uint8_t *b) {
  lo &= ~4095ull, hi = (hi + 4095) & ~4095ull;
  if (!b && !(b = k_ublk(c, hi - lo))) return -ENOMEM;
  for (uint64_t va = lo; va < hi; va += 4096) {
    uint64_t *e = k_upte(c, va);
    if (!e) return -ENOMEM;
    uint64_t f = *e & 1 ? *e : k_pa(b + (va - lo)) | 5 | 1ull << 63;
    if (w) f |= 2;
    if (x) f &= ~(1ull << 63);
    *e = f; }
  return 0; }
static long k_umap(struct k_uctx *c, uint64_t lo, uint64_t hi, bool w, bool x) {
  return k_umapb(c, lo, hi, w, x, NULL); }

// where the kernel reaches va of c's, the page mapped
static uint8_t *k_ukva(struct k_uctx *c, uint64_t va) {
  uint64_t *e = k_upte(c, va);
  return (uint8_t*) k_va(*e & 0x000ffffffffff000ull) + (va & 4095); }

static void k_ucopy(struct k_uctx *c, uint64_t va, void const *s, uint64_t n) {
  for (uint64_t i = 0; i < n; i++) *k_ukva(c, va + i) = ((uint8_t const*) s)[i]; }

// is va's page c's, for the kernel to read -- and to write, with w?
static bool k_upage(struct k_uctx const *c, uint64_t va, bool w) {
  if (va >= k_utop) return false;
  uint64_t *e = k_uwalk(c, va);
  return e && (*e & 5) == 5 && (!w || *e & 2); }

// does p..p+n lie in c's memory, and may the kernel write it with w?
static bool k_uokw(struct k_uctx const *c, uint64_t p, uint64_t n, bool w) {
  if (p + n < p) return false;
  if (!n) return true;
  for (uint64_t va = p & ~4095ull; va < p + n; va += 4096)
    if (!k_upage(c, va, w)) return false;
  return true; }
static bool k_uok(struct k_uctx const *c, uint64_t p, uint64_t n) { return k_uokw(c, p, n, false); }

// a string of c's, its NUL inside its memory
static bool k_ustr(struct k_uctx const *c, uint64_t p) {
  for (uint64_t va = p; k_upage(c, va, false); va = (va | 4095) + 1)
    if (memchr((void*) (uintptr_t) va, 0, (size_t) (4096 - (va & 4095)))) return true;
  return false; }

// the memory a call's pointers name, in the process's own, before the kernel touches it:
// 0, or -EFAULT. a call this does not know answers -ENOSYS, so nothing unchecked reaches
// k_proc_call
static long k_uargs(struct k_uctx const *c, long n, uint64_t a, uint64_t b, uint64_t d,
                    uint64_t e, uint64_t f, uint64_t g) {
  bool ok;
  switch (n) {
   case NR_read: case 17: case NR_getdents64: ok = k_uokw(c, b, d, true); break;    // pread64
   case NR_write: case 18: ok = k_uok(c, b, d); break;                               // pwrite64
   case 19: case 20:                                       // readv, writev
    ok = k_uok(c, b, d * sizeof(struct iovec));
    for (uint64_t i = 0; ok && i < d; i++) {
      struct iovec const *v = (struct iovec const*) (uintptr_t) b + i;
      ok = k_uokw(c, (uint64_t) (uintptr_t) v->iov_base, v->iov_len, n == 19); }
    break;
   case NR_getcwd: ok = k_uokw(c, a, b, true); break;
   case NR_fstat: ok = k_uokw(c, b, sizeof(struct stat), true); break;
   case NR_newfstatat: ok = k_ustr(c, b) && k_uokw(c, d, sizeof(struct stat), true); break;
   case NR_openat: case NR_unlinkat: case NR_mkdirat: case NR_fchmodat: case NR_faccessat:
    ok = k_ustr(c, b); break;
   case NR_readlinkat: ok = k_ustr(c, b) && k_uokw(c, d, e, true); break;
   case NR_renameat: ok = k_ustr(c, b) && k_ustr(c, e); break;
   case NR_chdir: ok = k_ustr(c, a); break;
   case NR_ioctl:                                          // sys.c's: TCGETS, TCSETS*, TIOC[GS]PGRP
    ok = b == 21505 ? k_uokw(c, d, sizeof(struct termios), true)
       : 21506 <= b && b <= 21508 ? k_uok(c, d, sizeof(struct termios))
       : b == TIOCGWINSZ ? k_uokw(c, d, sizeof(struct winsize), true)
       : b == TIOCSWINSZ ? k_uok(c, d, sizeof(struct winsize))
       : b == 21519 ? k_uokw(c, d, sizeof(int), true)
       : b == 21520 ? k_uok(c, d, sizeof(int))
       : true;                                             // the rest answer EINVAL untouched
    break;
   case NR_pipe2: ok = k_uokw(c, a, 2 * sizeof(int), true); break;
   case NR_wait4: ok = !b || k_uokw(c, b, sizeof(int), true); break;
   case NR_ppoll: ok = k_uokw(c, a, b * sizeof(struct pollfd), true) && k_uok(c, d, sizeof(struct timespec));
    break;
   case NR_clock_gettime: ok = k_uokw(c, b, sizeof(struct timespec), true); break;
   case NR_uname: ok = k_uokw(c, a, sizeof(struct utsname), true); break;
   case NR_inle_spawn: ok = k_uok(c, a, b) && k_uok(c, d, e) && k_uok(c, f, g); break;
   case NR_fcntl: ok = b == F_DUPFD || b == F_DUPFD_CLOEXEC || b == F_GETFD || b == F_SETFD
                       || b == F_GETFL || b == F_SETFL; break;
   case NR_exit: case NR_exit_group: case NR_getpid: case 110: case NR_kill: case NR_close:
   case NR_lseek: case NR_ftruncate: case NR_dup3: case 32: case 33:    // getppid, dup, dup2
    ok = true; break;
   default: return -ENOSYS; }
  return ok ? 0 : -EFAULT; }

// the page tables changed under the running process: its stale translations go
static void k_uflush(void) { k_wr_cr3(k_rd_cr3()); }

// a page's entry for prot: present always, the process's unless PROT_NONE, writable and
// executable as asked; a page the kernel lends keeps its mark, and is never written
static uint64_t k_uprot(uint64_t e, long prot) {
  e = (e & (0x000ffffffffff000ull | k_ushared)) | 1 | 1ull << 63;
  if (prot & (PROT_READ | PROT_WRITE | PROT_EXEC)) e |= 4;
  if (prot & PROT_WRITE) e |= 2;
  if (prot & PROT_EXEC) e &= ~(1ull << 63);
  return e; }

// the calls on the process's own memory -> their answer. a mapping is a block of its own,
// laid fresh past the last; a file's is a copy of its bytes, read through the process's fd
static long k_umem(struct k_uctx *c, long n, uint64_t a, uint64_t b, long d, long e, long f, long g) {
  uint64_t lo = a & ~4095ull, hi = (a + b + 4095) & ~4095ull;
  if (n == NR_madvise) return 0;
  if (n == NR_mmap) {
    if (e & MAP_FIXED || !b) return -EINVAL;
    lo = c->mnext, hi = lo + ((b + 4095) & ~4095ull);
    if (hi > k_utop - k_ustack - 4096) return -ENOMEM;
    if (c->nmm == c->cmm) {
      int m = c->cmm ? 2 * c->cmm : 16;
      struct k_umm *t = k_grab((uintptr_t) m * sizeof *t);
      if (!t) return -ENOMEM;
      for (int i = 0; i < c->nmm; i++) t[i] = c->mm[i];
      k_drop(c->mm);
      c->mm = t, c->cmm = m; }
    void *raw;
    uint8_t *k = k_uraw(hi - lo, &raw);
    if (!k) return -ENOMEM;
    if (!(e & MAP_ANONYMOUS)) {                    // the file's bytes from g on, its offset kept
      long at = k_proc_call(c->pid, NR_lseek, f, 0, SEEK_CUR, 0, 0, 0), r = at;
      if (r >= 0) r = k_proc_call(c->pid, NR_lseek, f, g, SEEK_SET, 0, 0, 0);
      for (uint64_t o = 0; r >= 0 && o < b; o += (uint64_t) r)
        if (!(r = k_proc_call(c->pid, NR_read, f, (long) (uintptr_t) (k + o), (long) (b - o), 0, 0, 0))) break;
      if (at >= 0) k_proc_call(c->pid, NR_lseek, f, at, SEEK_SET, 0, 0, 0);
      if (r < 0) return kfree(raw), r; }
    long r = k_umapb(c, lo, hi, false, false, k);
    for (uint64_t va = lo; !r && va < hi; va += 4096) {
      uint64_t *p = k_uwalk(c, va);
      *p = k_uprot(*p, d); }
    if (r) return kfree(raw), r;                   // its tables stay, on the block list
    c->mm[c->nmm++] = (struct k_umm) { lo, hi, raw };
    c->mnext = hi + 4096;
    return (long) lo; }
  if (a & 4095 || hi <= lo || hi > k_utop) return -EINVAL;
  for (uint64_t va = lo; n == NR_mprotect && va < hi; va += 4096) {
    uint64_t *p = k_uwalk(c, va);
    if (!p || !(*p & 1)) return -ENOMEM;
    if (*p & k_ushared && d & PROT_WRITE) return -EACCES; }
  for (uint64_t va = lo; va < hi; va += 4096) {
    uint64_t *p = k_uwalk(c, va);
    if (p && *p & 1) *p = n == NR_munmap ? 0 : k_uprot(*p, d); }
  k_uflush();
  if (n == NR_munmap)                              // a mapping wholly gone gives its block back
    for (int i = 0; i < c->nmm; i++)
      if (lo <= c->mm[i].lo && c->mm[i].hi <= hi) kfree(c->mm[i].raw), c->mm[i--] = c->mm[--c->nmm];
  return 0; }

// the turn ends: back to the pump, why saying how (k_proc_run); a process that waits comes
// back here when its next turn starts
static void k_uyield(struct k_uctx *c, int why) {
  c->why = why;
  k_kswap(&c->psp, c->msp); }

static void k_uend(struct k_uctx *c) __attribute__((noreturn));
static void k_uend(struct k_uctx *c) { for (;;) k_uyield(c, 0); }

// a call from the running process (k_syscall_entry, IF masked) -> its answer. a call that
// must wait ends the turn and is asked again at the next; a process its call ended is done
long k_syscall(struct k_sysf *f) {
  struct k_uctx *c = (struct k_uctx*) (uintptr_t) k_cpu[2];
  long n = (long) f->nr, r;
  if (n == NR_mmap || n == NR_munmap || n == NR_mprotect || n == NR_madvise)
    return k_umem(c, n, f->di, f->si, (long) f->dx, (long) f->r10, (long) f->r8, (long) f->r9);
  r = k_uargs(c, n, f->di, f->si, f->dx, f->r10, f->r8, f->r9);
  if (n == 32 || n == 33) n = NR_dup3, f->dx = 0;          // dup2's flags; dup lands anywhere
  // ppoll's timeout is kept here: sys.c's third word says only whether it may wait yet
  uint64_t until = ~0ull;
  if (!r && n == NR_ppoll && f->dx) {
    struct timespec const *t = (struct timespec const*) (uintptr_t) f->dx;
    until = k_clock_ms() + (uint64_t) t->tv_sec * 1000 + (uint64_t) (t->tv_nsec + 999999) / 1000000; }
  if (!r) while ((r = k_proc_call(c->pid, n, (long) f->di, (long) f->si,
                                  n == NR_ppoll ? k_clock_ms() < until : (long) f->dx,
                                  (long) f->r10, (long) f->r8, (long) f->r9)) == K_RESTART)
    k_uyield(c, 1);
  if (k_proc_call(c->pid, NR_getpid, 0, 0, 0, 0, 0, 0) < 0) k_uend(c);
  return r; }

// a tick in the running process (timer_isr): its turn spent, the machine goes back
void k_proc_tick(void) {
  struct k_uctx *c = (struct k_uctx*) (uintptr_t) k_cpu[2];
  if (c && --c->slice <= 0) k_uyield(c, 2); }

// a fault in the running process (k_exception, from ring 3): it ends as linux's signal would
void k_proc_fault(uint64_t vector) {
  struct k_uctx *c = (struct k_uctx*) (uintptr_t) k_cpu[2];
  long sig = vector == 6 ? SIGILL : vector == 0 || vector == 16 || vector == 19 ? SIGFPE
           : vector == 3 ? SIGTRAP : SIGSEGV;
  k_proc_call(c->pid, NR_kill, 0, sig, 0, 0, 0, 0);
  k_uend(c); }

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

// love itself, laid from the kernel's own image: each of the pie's loads shared read-only off
// the kernel's pages, but the first writable one, its own pages started from the copy the
// projection keeps as the pie has it, base 0 -> 0, the entry in c->pc; -ENOSYS with no copy
static long k_uload_love(struct k_uctx *c, uint64_t *phdr, uint64_t *phn) {
  if (!k_pie_base || !k_pie_data) return -ENOSYS;
  Elf64_Ehdr const *h = (Elf64_Ehdr const*) k_pie_base;
  Elf64_Phdr const *ph = (Elf64_Phdr const*) (k_pie_base + h->e_phoff);
  bool data = false;
  *phdr = k_upie + h->e_phoff, *phn = h->e_phnum;
  for (int i = 0; i < h->e_phnum; i++) {
    Elf64_Phdr const *p = &ph[i];
    if (p->p_type != PT_LOAD) continue;
    uint64_t lo = k_upie + p->p_vaddr, hi = lo + p->p_memsz;
    if (p->p_flags & PF_W && !data) {
      long r = k_umap(c, lo, hi, true, false);
      if (r) return r;
      k_ucopy(c, lo, (void const*) k_pie_data, p->p_filesz);
      data = true;
      continue; }
    for (uint64_t va = lo & ~4095ull; va < hi; va += 4096) {
      uint64_t *e = k_upte(c, va);
      if (!e) return -ENOMEM;
      if (!(*e & 1))
        *e = (k_pie_base + (va - k_upie) - k_xw) | 5 | k_ushared | (p->p_flags & PF_X ? 0 : 1ull << 63); } }
  c->pc = k_upie + h->e_entry;
  return 0; }

static void k_ufree(struct k_uctx *c) {
  for (int i = 0; i < c->nblk; i++) kfree(c->blk[i]);
  k_drop(c->blk);
  for (int i = 0; i < c->nmm; i++) kfree(c->mm[i].raw);
  k_drop(c->mm);
  k_drop(c); }

// the seat's door (sys.c): pid's program, the ELF in code, laid on argv av and environment ev
// and kept in pid's record, its first turn yet to come -> 0; -errno where it cannot run. a
// word without code is love's, laid from the kernel's own image
long k_proc_start(long pid, char const *av, uintptr_t an, char const *ev, uintptr_t en,
                  char const *code, uintptr_t cn) {
  void **seat = k_proc_seat(pid);
  if (!seat) return -ENOSYS;
  struct k_uctx *c = k_grab(sizeof *c);
  if (!c) return -ENOMEM;
  memset(c, 0, sizeof *c);
  c->pid = pid, c->mnext = k_umbase;
  uint64_t phdr, phn;
  long r = (c->pml4 = k_ublk(c, 4096)) ? 0 : -ENOMEM;
  if (!r) {                                       // the kernel's half, shared
    uint64_t const *k = k_va(k_rd_cr3() & 0x000ffffffffff000ull);
    for (int i = 256; i < 512; i++) c->pml4[i] = k[i];
    c->cr3 = k_pa(c->pml4);
    r = code ? k_uload(c, (uint8_t const*) code, cn, &phdr, &phn) : k_uload_love(c, &phdr, &phn); }
  if (!r) r = k_umap(c, k_utop - k_ustack, k_utop, true, false);
  if (!r && !(c->kst = k_ublk(c, k_kstack))) r = -ENOMEM;
  if (r) return k_ufree(c), r;
  c->sp = k_ustack_lay(c, av, an, ev, en, phdr, phn);
  // the first turn's stack, as k_kswap leaves one: a float file (x87 and sse at their reset
  // control words), six registers with c in r12's, flags with IF clear, the return to k_ufirst
  uint64_t *s = (uint64_t*) (c->kst + k_kstack) - 72;
  memset(s, 0, 576);
  ((uint16_t*) s)[0] = 0x37f, ((uint32_t*) s)[6] = 0x1f80;
  s[67] = (uint64_t) (uintptr_t) c, s[70] = 2, s[71] = (uint64_t) (uintptr_t) k_ufirst;
  c->psp = (uint64_t) (uintptr_t) s;
  *seat = c;
  return 0; }

// one turn of the machine m (sys.c's pump) -> how it ended: 0 the process is done, 1 a call
// waits, 2 its time ran out
long k_proc_run(void *m) {
  struct k_uctx *c = m;
  uint64_t ks = (uint64_t) (uintptr_t) (c->kst + k_kstack), kcr3 = k_rd_cr3();
  k_cpu[0] = ks, k_cpu[2] = (uint64_t) (uintptr_t) c;
  memcpy(k_tss + 4, &ks, 8);
  c->slice = k_slice;
  k_wr_cr3(c->cr3);
  k_kswap(&c->msp, c->psp);
  k_wr_cr3(kcr3);
  k_cpu[2] = 0;
  return c->why; }

// ..and once it is done, or killed between turns
void k_proc_drop(void *m) { k_ufree(m); }
