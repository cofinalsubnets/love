// proc.c -- an a64 process: the lower half under TTBR0, EL0, its svc through the vectors
// (mkvec.l) to k_proc_call; the kernel's half is TTBR1's, never touched. it runs a turn at a
// time from sys.c's pump, ending at a call that must wait, the timer, or the end
#include "../../apps/moon/lib/moonlibc/impl.h"
#include <stdint.h>
#include <stdbool.h>
#include <elf.h>
#include <sys/utsname.h>
#include "asmops.h"
#include "../k.h"

extern void *kmallocwa(uintptr_t n, uintptr_t a), *k_grab(uintptr_t n);
extern void kfree(void *p), k_drop(void *p);
extern long k_proc_call(long pid, long n, long a, long b, long c, long d, long e, long f);
extern void k_kswap(uint64_t *save, uint64_t load), a_uret(void);
extern void **k_proc_seat(long pid);
extern uintptr_t const k_pie_base, k_pie_data;   // kmain.c, patched in by the transpose
extern uintptr_t k_clock_ms(void);

#define K_RESTART -512                     // sys.c's: the call must wait, and is asked again
#define k_ustack (1u << 20)                // a process's stack
#define k_kstack (64u << 10)               // ..and the kernel's, under its calls and interrupts
#define k_utop 0x7ffffffff000ull           // the stack's top, the lower half's last page
#define k_upie 0x10000000ull               // where a position-independent program goes
#define k_slice 2                          // a turn, in timer ticks
#define k_umbase 0x100000000000ull         // where mmap lays the first mapping
#define k_ushared (1ull << 55)             // a descriptor's software bit: the kernel's page, lent
#define k_upa 0x0000fffffffff000ull        // a descriptor's frame
// a page's descriptor: valid page, AF, inner shareable, MAIR's write-back slot, EL1 never runs it
#define k_upage_bits (3ull | 1ull << 10 | 3ull << 8 | 1ull << 2 | 1ull << 53)
#define k_uel0 (1ull << 6)                 // AP[1]: EL0 reaches it
#define k_uro (1ull << 7)                  // AP[2]: read-only
#define k_uxn (1ull << 54)                 // EL0 never runs it

// a process's frame as its exception laid it, mkvec.l's a-text, lowest first
struct k_aframe { uint64_t x[31], sp, pc, pstate, tp, pad; uint8_t q[512]; uint64_t fpsr, fpcr; };
#define k_sswap 176                        // k_kswap's save under it: lr at 88, daif at 160

// one process's machine: the two kernel stacks a turn trades between, then what the kernel
// keeps -- its blocks, freed at the end, and its mappings, each its own block, freed when it
// goes. why: how its last turn ended; f: the frame of the call it is in
struct k_umm { uint64_t lo, hi; void *raw; };
struct k_uctx {
  uint64_t ttbr0, msp, psp, mnext;
  long pid;
  int why, slice;
  uint8_t *kst;
  uint64_t *l0;
  void **blk;
  int nblk, cblk, nmm, cmm;
  struct k_umm *mm;
  struct k_aframe const *f; };

static uint64_t k_pa(void const *p) { return (uint64_t) (uintptr_t) p - khhdm; }
static uint64_t *k_va(uint64_t pa) { return (uint64_t*) (uintptr_t) (pa + khhdm); }
static struct k_uctx *k_ucur(void) { return (struct k_uctx*) (uintptr_t) k_rd_tpidr_el1(); }

// n bytes written as data now to run: cleaned to the point of unification, line by line
static void k_usync(void const *p, uint64_t n) {
  uint64_t ln = 4ull << (k_rd_ctr_el0() >> 16 & 15);
  for (uintptr_t a = (uintptr_t) p & ~(ln - 1); a < (uintptr_t) p + n; a += ln) k_dc_cvau(a);
  k_ic_iallu(); }

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

// the page's descriptor for va, its tables laid on the way down -> it; NULL out of room
static uint64_t *k_upte(struct k_uctx *c, uint64_t va) {
  uint64_t *t = c->l0;
  for (int sh = 39; sh > 12; sh -= 9) {
    uint64_t *e = &t[va >> sh & 511];
    if (!(*e & 1)) {
      uint64_t *n = k_ublk(c, 4096);
      if (!n) return NULL;
      *e = k_pa(n) | 3; }                 // valid, a table
    t = k_va(*e & k_upa); }
  return &t[va >> 12 & 511]; }

// the page's descriptor for va, if its tables are there -> it; NULL where they are not
static uint64_t *k_uwalk(struct k_uctx const *c, uint64_t va) {
  uint64_t *t = c->l0;
  for (int sh = 39; sh > 12; sh -= 9) {
    uint64_t e = t[va >> sh & 511];
    if (!(e & 1)) return NULL;
    t = k_va(e & k_upa); }
  return &t[va >> 12 & 511]; }

// lo..hi mapped, each page not yet mapped taken from b, or from one block of its own; write
// and execute laid over whatever a shared page already has -> 0, or -ENOMEM
static long k_umapb(struct k_uctx *c, uint64_t lo, uint64_t hi, bool w, bool x, uint8_t *b) {
  lo &= ~4095ull, hi = (hi + 4095) & ~4095ull;
  if (!b && !(b = k_ublk(c, hi - lo))) return -ENOMEM;
  for (uint64_t va = lo; va < hi; va += 4096) {
    uint64_t *e = k_upte(c, va);
    if (!e) return -ENOMEM;
    uint64_t f = *e & 1 ? *e : k_pa(b + (va - lo)) | k_upage_bits | k_uel0 | k_uro | k_uxn;
    if (w) f &= ~k_uro;
    if (x) f &= ~k_uxn;
    *e = f; }
  return 0; }
static long k_umap(struct k_uctx *c, uint64_t lo, uint64_t hi, bool w, bool x) {
  return k_umapb(c, lo, hi, w, x, NULL); }

// where the kernel reaches va of c's, the page mapped
static uint8_t *k_ukva(struct k_uctx *c, uint64_t va) {
  uint64_t *e = k_upte(c, va);
  return (uint8_t*) k_va(*e & k_upa) + (va & 4095); }

static void k_ucopy(struct k_uctx *c, uint64_t va, void const *s, uint64_t n) {
  for (uint64_t i = 0; i < n; i++) *k_ukva(c, va + i) = ((uint8_t const*) s)[i]; }

// is va's page c's, for the kernel to read -- and to write, with w?
static bool k_upage(struct k_uctx const *c, uint64_t va, bool w) {
  if (va >= k_utop) return false;
  uint64_t *e = k_uwalk(c, va);
  return e && *e & 1 && *e & k_uel0 && (!w || !(*e & k_uro)); }

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

// a NULL-ended vector of c's strings, each in its memory
static bool k_uvec(struct k_uctx const *c, uint64_t p) {
  for (;; p += 8) {
    if (!k_uok(c, p, 8)) return false;
    uint64_t s = *(uint64_t const*) (uintptr_t) p;
    if (!s) return true;
    if (!k_ustr(c, s)) return false; } }

// a call's pointers checked against the process's memory -> 0, or -EFAULT; an unknown call
// is -ENOSYS, so nothing unchecked reaches k_proc_call
static long k_uargs(struct k_uctx const *c, long n, uint64_t a, uint64_t b, uint64_t d,
                    uint64_t e, uint64_t f, uint64_t g) {
  bool ok;
  switch (n) {
   case NR_read: case NR_pread64: case NR_getdents64: ok = k_uokw(c, b, d, true); break;
   case NR_write: case NR_pwrite64: ok = k_uok(c, b, d); break;
   case 65: case 66:                                       // readv, writev
    ok = k_uok(c, b, d * sizeof(struct iovec));
    for (uint64_t i = 0; ok && i < d; i++) {
      struct iovec const *v = (struct iovec const*) (uintptr_t) b + i;
      ok = k_uokw(c, (uint64_t) (uintptr_t) v->iov_base, v->iov_len, n == 65); }
    break;
   case NR_getcwd: ok = k_uokw(c, a, b, true); break;
   case NR_fstat: ok = k_uokw(c, b, sizeof(struct stat), true); break;
   case NR_newfstatat: ok = k_ustr(c, b) && k_uokw(c, d, sizeof(struct stat), true); break;
   case NR_openat: case NR_unlinkat: case NR_mkdirat: case NR_fchmodat: case NR_faccessat:
    ok = k_ustr(c, b); break;
   case NR_readlinkat: ok = k_ustr(c, b) && k_uokw(c, d, e, true); break;
   case NR_renameat: ok = k_ustr(c, b) && k_ustr(c, e); break;
   case NR_chdir: ok = k_ustr(c, a); break;
   case NR_execve: ok = k_ustr(c, a) && k_uvec(c, b) && (!d || k_uvec(c, d)); break;
   case NR_fchdir: ok = true; break;
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
   case NR_exit: case NR_exit_group: case NR_getpid: case NR_getppid: case NR_kill: case NR_close:
   case NR_clone:
   case NR_lseek: case NR_ftruncate: case NR_dup3: case 23:            // dup
    ok = true; break;
   default: return -ENOSYS; }
  return ok ? 0 : -EFAULT; }

// a page's descriptor for prot: valid always, the process's unless PROT_NONE, writable and
// executable as asked; a page the kernel lends keeps its mark, and is never written
static uint64_t k_uprot(uint64_t e, long prot) {
  e = (e & (k_upa | k_ushared)) | k_upage_bits | k_uro | k_uxn;
  if (prot & (PROT_READ | PROT_WRITE | PROT_EXEC)) e |= k_uel0;
  if (prot & PROT_WRITE) e &= ~k_uro;
  if (prot & PROT_EXEC) e &= ~k_uxn;
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
    if (d & PROT_EXEC) k_usync(k, hi - lo);
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
    if (p && *p & 1) {
      if (n == NR_mprotect && d & PROT_EXEC && !(*p & k_ushared)) k_usync(k_va(*p & k_upa), 4096);
      *p = n == NR_munmap ? 0 : k_uprot(*p, d); } }
  k_wr_ttbr0_el1(c->ttbr0);                        // the stale translations go
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

// a call from the running process (a_usync, interrupts masked) -> its answer. a call that
// must wait ends the turn and is asked again at the next; a process its call ended is done
long k_syscall(struct k_aframe *f) {
  struct k_uctx *c = k_ucur();
  long n = (long) f->x[8], r;
  uint64_t const *x = f->x;
  c->f = f;
  if (n == NR_mmap || n == NR_munmap || n == NR_mprotect || n == NR_madvise)
    return k_umem(c, n, x[0], x[1], (long) x[2], (long) x[3], (long) x[4], (long) x[5]);
  r = k_uargs(c, n, x[0], x[1], x[2], x[3], x[4], x[5]);
  uint64_t c2 = x[2];
  if (n == 23) n = NR_dup3, c2 = 0;                         // dup lands anywhere
  // ppoll's timeout is kept here: sys.c's third word says only whether it may wait yet
  uint64_t until = ~0ull;
  if (!r && n == NR_ppoll && x[2]) {
    struct timespec const *t = (struct timespec const*) (uintptr_t) x[2];
    until = k_clock_ms() + (uint64_t) t->tv_sec * 1000 + (uint64_t) (t->tv_nsec + 999999) / 1000000; }
  if (!r) while ((r = k_proc_call(c->pid, n, (long) x[0], (long) x[1],
                                  n == NR_ppoll ? k_clock_ms() < until : (long) c2,
                                  (long) x[3], (long) x[4], (long) x[5])) == K_RESTART)
    k_uyield(c, 1);
  if (k_proc_call(c->pid, NR_getpid, 0, 0, 0, 0, 0, 0) < 0 || (n == NR_execve && !r)) k_uend(c);
  return r; }

// a tick in the running process (a_uirq): its turn spent, the machine goes back
void k_proc_tick(void) {
  struct k_uctx *c = k_ucur();
  if (c && --c->slice <= 0) k_uyield(c, 2); }

// an ID register's value, by its CRm and op2, as EL1 reads it; one this kernel does not read is 0
static uint64_t k_uidreg(uint32_t k) {
  uint64_t v = 0;
  switch (k) {
   case 0x20: asm volatile ("mrs %0, id_aa64pfr0_el1" : "=r"(v)); break;
   case 0x21: asm volatile ("mrs %0, id_aa64pfr1_el1" : "=r"(v)); break;
   case 0x28: asm volatile ("mrs %0, id_aa64dfr0_el1" : "=r"(v)); break;
   case 0x30: asm volatile ("mrs %0, id_aa64isar0_el1" : "=r"(v)); break;
   case 0x31: asm volatile ("mrs %0, id_aa64isar1_el1" : "=r"(v)); break;
   case 0x38: asm volatile ("mrs %0, id_aa64mmfr0_el1" : "=r"(v)); break;
   case 0x39: asm volatile ("mrs %0, id_aa64mmfr1_el1" : "=r"(v)); break; }
  return v; }

// a fault in the running process (a_ufault, from EL0): an mrs of an ID register answers as
// linux's does, the process going on past it; any other ends it as linux's signal would
void k_proc_fault(uint64_t esr, struct k_aframe *f) {
  struct k_uctx *c = k_ucur();
  uint64_t ec = esr >> 26;
  uint32_t ins = (ec == 0 || ec == 0x18) && k_uok(c, f->pc, 4) ? *(uint32_t const*) (uintptr_t) f->pc : 0;
  if ((ins & 0xfff00000) == 0xd5300000 && (ins >> 12 & 0xff) == 0x80   // mrs, op0 3, op1 0, CRn 0
      && (ins >> 8 & 15) >= 4 && (ins >> 8 & 15) <= 7) {
    if ((ins & 31) != 31) f->x[ins & 31] = k_uidreg(ins >> 5 & 0x7f);
    f->pc += 4;
    return; }
  long sig = ec == 0 || ec == 0x0e ? SIGILL : ec == 0x2c ? SIGFPE
           : ec == 0x3c ? SIGTRAP : ec == 0x22 || ec == 0x26 ? SIGBUS : SIGSEGV;
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

// the program's ELF laid in c's memory -> 0, the entry in *pc; -ENOEXEC for one this
// machine cannot run
static long k_uload(struct k_uctx *c, uint8_t const *e, uintptr_t n, uint64_t *pc,
                    uint64_t *phdr, uint64_t *phn) {
  Elf64_Ehdr const *h = (Elf64_Ehdr const*) e;
  if (n < sizeof *h || memcmp(e, ELFMAG, SELFMAG) || e[EI_CLASS] != ELFCLASS64
      || e[EI_DATA] != ELFDATA2LSB || h->e_machine != EM_AARCH64
      || (h->e_type != ET_EXEC && h->e_type != ET_DYN)
      || h->e_phoff + (uint64_t) h->e_phnum * sizeof(Elf64_Phdr) > n) return -ENOEXEC;
  uint64_t base = h->e_type == ET_DYN ? k_upie : 0;
  Elf64_Phdr const *ph = (Elf64_Phdr const*) (e + h->e_phoff);
  *phdr = 0, *phn = h->e_phnum;
  for (int i = 0; i < h->e_phnum; i++) {
    Elf64_Phdr const *p = &ph[i];
    if (p->p_type != PT_LOAD) continue;
    if (p->p_offset + p->p_filesz > n || p->p_filesz > p->p_memsz) return -ENOEXEC;
    uint64_t lo = base + p->p_vaddr, hi = lo + p->p_memsz;
    if (hi < lo || hi > k_utop - k_ustack - 4096) return -ENOEXEC;
    long r = k_umap(c, lo, hi, p->p_flags & PF_W, p->p_flags & PF_X);
    if (r) return r;
    k_ucopy(c, lo, e + p->p_offset, p->p_filesz);
    if (p->p_flags & PF_X)
      for (uint64_t va = lo & ~4095ull; va < hi; va += 4096) k_usync(k_ukva(c, va), 4096);
    if (p->p_offset <= h->e_phoff && h->e_phoff < p->p_offset + p->p_filesz)
      *phdr = lo + (h->e_phoff - p->p_offset); }
  *pc = base + h->e_entry;
  return k_uok(c, *pc, 1) ? 0 : -ENOEXEC; }

// love itself from the kernel's image: its loads shared read-only, but the first writable one,
// fresh from the transpose's copy, whose door slots name the hosted bodies -> 0, the entry in
// *pc; -ENOSYS with no copy
static long k_uload_love(struct k_uctx *c, uint64_t *pc, uint64_t *phdr, uint64_t *phn) {
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
      uint64_t o = va - k_upie, from = k_pie_base + o;
      if (!(*e & 1))
        *e = (from - k_xw) | k_upage_bits | k_uel0 | k_uro | k_ushared
           | (p->p_flags & PF_X ? 0 : k_uxn); } }
  *pc = k_upie + h->e_entry;
  return 0; }

static void k_ufree(struct k_uctx *c) {
  for (int i = 0; i < c->nblk; i++) kfree(c->blk[i]);
  k_drop(c->blk);
  for (int i = 0; i < c->nmm; i++) kfree(c->mm[i].raw);
  k_drop(c->mm);
  k_drop(c); }

// the first turn's stacks: the frame a_uret erets from at the top, k_kswap's save under it
// returning there, its interrupts masked as the kernel's are across a swap
static void k_ulay(struct k_uctx *c, struct k_aframe const *f) {
  uint8_t *top = c->kst + k_kstack;
  memcpy(top - sizeof *f, f, sizeof *f);
  uint64_t *s = (uint64_t*) (top - sizeof *f - k_sswap);
  memset(s, 0, k_sswap);
  s[11] = (uint64_t) (uintptr_t) a_uret, s[20] = 0x3c0;
  c->psp = (uint64_t) (uintptr_t) s; }

// sys.c's door: pid's ELF in code laid on av and ev, its first turn to come -> 0 or -errno;
// no code is love's own image. a firmware's guest keeps its TTBR0, and runs none
long k_proc_start(long pid, char const *av, uintptr_t an, char const *ev, uintptr_t en,
                  char const *code, uintptr_t cn) {
  void **seat = k_proc_seat(pid);
  if (!seat || kboot.efi_st) return -ENOSYS;
  struct k_uctx *c = k_grab(sizeof *c);
  if (!c) return -ENOMEM;
  memset(c, 0, sizeof *c);
  c->pid = pid, c->mnext = k_umbase;
  struct k_aframe f;
  memset(&f, 0, sizeof f);
  uint64_t phdr, phn;
  long r = (c->l0 = k_ublk(c, 4096)) ? 0 : -ENOMEM;
  if (!r) {
    c->ttbr0 = k_pa(c->l0);
    r = code ? k_uload(c, (uint8_t const*) code, cn, &f.pc, &phdr, &phn)
             : k_uload_love(c, &f.pc, &phdr, &phn); }
  if (!r) r = k_umap(c, k_utop - k_ustack, k_utop, true, false);
  if (!r && !(c->kst = k_ublk(c, k_kstack))) r = -ENOMEM;
  if (r) return k_ufree(c), r;
  f.sp = k_ustack_lay(c, av, an, ev, en, phdr, phn);
  k_ulay(c, &f);
  *seat = c;
  return 0; }

// one turn of the machine m (sys.c's pump) -> how it ended: 0 the process is done, 1 a call
// waits, 2 its time ran out
long k_proc_run(void *m) {
  struct k_uctx *c = m;
  uint64_t t0 = k_rd_ttbr0_el1();
  k_wr_tpidr_el1((uint64_t) (uintptr_t) c);
  c->slice = k_slice;
  k_wr_ttbr0_el1(c->ttbr0);
  k_kswap(&c->msp, c->psp);
  k_wr_ttbr0_el1(t0);
  k_wr_tpidr_el1(0);
  return c->why; }

// ..and once it is done, or killed between turns
void k_proc_drop(void *m) { k_ufree(m); }

// the pages under p's table t, at level sh from va: counted in *n where c is NULL (those no
// mapping holds), else laid in c -- a lent page as it is, a mapping's at its place in c's copy
// of the mapping, the rest a page each from *b -> 0, or -ENOMEM
static long k_ukin(struct k_uctx const *p, struct k_uctx *c, uint64_t const *t, int sh,
                   uint64_t va, uint8_t **b, uint64_t *n) {
  for (int i = 0; i < 512; i++) {
    uint64_t e = t[i], at = va | (uint64_t) i << sh;
    if (!(e & 1)) continue;
    if (sh > 12) {
      long r = k_ukin(p, c, k_va(e & k_upa), sh - 9, at, b, n);
      if (r) return r;
      continue; }
    int j = 0;
    while (j < p->nmm && !(p->mm[j].lo <= at && at < p->mm[j].hi)) j++;
    if (!c) { *n += !(e & k_ushared) && j == p->nmm; continue; }
    uint64_t *d = k_upte(c, at);
    if (!d) return -ENOMEM;
    if (e & k_ushared) { *d = e; continue; }
    uint8_t *to = j < p->nmm ? (uint8_t*) c->mm[j].raw + (at - p->mm[j].lo) : (*b += 4096) - 4096;
    memcpy(to, k_va(e & k_upa), 4096);
    if (!(e & k_uxn)) k_usync(to, 4096);
    *d = (e & ~k_upa) | k_pa(to); }
  return 0; }

// sys.c's door: a process here forks and execs
bool k_proc_forks(void) { return true; }

// sys.c's door: pid a copy of m's process, standing in m's call -- its pages but the lent ones
// copied, its registers as the call found them, x0 the call's answer here -> 0, or -errno
long k_proc_clone(void *m, long pid) {
  struct k_uctx const *p = m;
  void **seat = k_proc_seat(pid);
  if (!seat || !p->f) return -ENOSYS;
  struct k_uctx *c = k_grab(sizeof *c);
  if (!c) return -ENOMEM;
  memset(c, 0, sizeof *c);
  c->pid = pid, c->mnext = p->mnext;
  long r = (c->l0 = k_ublk(c, 4096)) ? 0 : -ENOMEM;
  if (!r && p->nmm && !(c->mm = k_grab((uintptr_t) p->nmm * sizeof *c->mm))) r = -ENOMEM;
  for (int i = 0; !r && i < p->nmm; i++) {
    c->mm[i] = p->mm[i];
    if (!k_uraw(p->mm[i].hi - p->mm[i].lo, &c->mm[i].raw)) r = -ENOMEM;
    else c->nmm = c->cmm = i + 1; }
  uint64_t n = 0;
  uint8_t *b = NULL;
  if (!r) {
    c->ttbr0 = k_pa(c->l0);
    k_ukin(p, NULL, p->l0, 39, 0, NULL, &n);
    if (n && !(b = k_ublk(c, n * 4096))) r = -ENOMEM; }
  if (!r) r = k_ukin(p, c, p->l0, 39, 0, &b, &n);
  if (!r && !(c->kst = k_ublk(c, k_kstack))) r = -ENOMEM;
  if (r) return k_ufree(c), r;
  struct k_aframe f = *p->f;
  f.x[0] = 0;
  k_ulay(c, &f);
  *seat = c;
  return 0; }
