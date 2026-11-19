/* signals, sa flags and the siginfo head, canonical <-> the BSDs' and macos's */
#include "impl.h"

#ifndef LvOsTranslate
long __love_sigfb(long s) { return s; }
long __love_sigcan(long s) { return s; }
void __love_sicanon(void const *n, siginfo_t *o) { memcpy(o, n, sizeof *o); }
unsigned long __love_maskfb(unsigned long m) { return m; }
unsigned long __love_maskcan(unsigned long m) { return m; }
long __love_safb(long f) { return f; }
long __love_sacan(long f) { return f; }
#else
/* signals, canonical <-> freebsd; -1 has no twin. freebsd 17 is SIGSTOP, canonical
 * SIGCHLD's number: a lost translation stops a child */
static signed char const os_sigfb[32] = {
   0,  1,  2,  3,  4,  5,  6, 10,  8,  9, 30, 11, 31, 13, 14, 15,
  -1, 20, 19, 17, 18, 21, 22, 16, 24, 25, 26, 27, 28, 23, -1, 12 };
static signed char const os_sigcan[32] = {
   0,  1,  2,  3,  4,  5,  6,  7,  8,  9,  7, 11, 31, 13, 14, 15,
  23, 19, 20, 18, 17, 21, 22, 29, 24, 25, 26, 27, 28, 29, 10, 12 };
long __love_sigfb(long s) { return (s >= 0 && s < 32) ? os_sigfb[s] : -1; }
long __love_sigcan(long s) { return (s >= 0 && s < 32) ? os_sigcan[s] : s; }

/* native siginfo heads: freebsd lays the lanes flat; netbsd swaps code and errno */
struct __fb_siginfo { int signo, err, code, pid; unsigned uid; int status; void *addr; };
struct __nb_siginfo { int signo, code, err;
#ifndef __i386__
  int pad;                            /* the union holds 64-bit words: on 8, but on i386 */
#endif
  union { void *addr; struct { int pid; unsigned uid; int status; } chld; } u; };
/* the address lane: a fault signal with a kernel code; a sent one carries its sender */
static int os_faultlane(int s, long code) {
  return (s == SIGILL || s == SIGTRAP || s == SIGFPE || s == SIGBUS || s == SIGSEGV)
         && code > 0 && code < 0x80; }
/* a fault's si_code as linux numbers it: freebsd swaps FPE_INTDIV and FPE_INTOVF, macos orders
 * its FPE and ILL codes its own way; SEGV, BUS and TRAP agree on all four */
static long os_faultcode(int s, long c) {
  static signed char const fbfpe[] = {0, 2, 1}, mfpe[] = {0, 3, 4, 5, 6, 7, 8, 1, 2},
                           mill[] = {0, 1, 4, 5, 2, 3, 6, 7, 8};
  if (__love_osv == 2 && s == SIGFPE && c <= 2) return fbfpe[c];
  if (__love_osv == 4 && s == SIGFPE && c <= 8) return mfpe[c];
  if (__love_osv == 4 && s == SIGILL && c <= 8) return mill[c];
  return c; }
/* si_code's sender band, and a fault's code */
static long os_sicode(int s, long c) {
  if (os_faultlane(s, c)) return os_faultcode(s, c);
  if (__love_osv == 2 || __love_osv == 4) switch (c) {
    case 0x10001: return 0;      /* SI_USER */
    case 0x10002: return -1;     /* SI_QUEUE */
    case 0x10003: return -2;     /* SI_TIMER */
    case 0x10004: return -4;     /* SI_ASYNCIO */
    case 0x10005: return -3;     /* SI_MESGQ */
    case 0x10006: return 0x80;   /* SI_KERNEL */
    case 0x10007: return -6;     /* SI_LWP; linux's nearest is SI_TKILL */
    default: return c; }
  if (__love_osv == 3) switch (c) {
    case -3: return -4;          /* SI_ASYNCIO */
    case -4: return -3;          /* SI_MESGQ */
    case -5: return -6;          /* SI_LWP; linux's -5 is SI_SIGIO, a different thing */
    default: return c; }         /* USER, QUEUE and TIMER already agree */
  return c; }
void __love_sicanon(void const *n, siginfo_t *o) {
  memset(o, 0, sizeof *o);
  if (__love_osv == 2 || __love_osv == 4) {   /* macos keeps freebsd's head and its sender band */
    struct __fb_siginfo const *f = n;
    o->si_signo = (int) __love_sigcan(f->signo), o->si_errno = f->err;
    o->si_code = (int) os_sicode(o->si_signo, f->code);
    if (os_faultlane(o->si_signo, o->si_code)) o->si_addr = f->addr;
    else { o->si_pid = f->pid, o->si_uid = f->uid;
           if (o->si_signo == SIGCHLD) o->si_status = f->status; } }
  else if (__love_osv == 3) {
    struct __nb_siginfo const *b = n;
    o->si_signo = (int) __love_sigcan(b->signo), o->si_errno = b->err;
    o->si_code = (int) os_sicode(o->si_signo, b->code);
    if (os_faultlane(o->si_signo, o->si_code)) o->si_addr = b->u.addr;
    else { o->si_pid = b->u.chld.pid, o->si_uid = b->u.chld.uid;
           if (o->si_signo == SIGCHLD) o->si_status = b->u.chld.status; } }
  else memcpy(o, n, sizeof *o); }         /* linux: the native record IS canonical */

/* a mask, bit (sig-1), signals 1..31; the rt band has no freebsd twin and drops */
static unsigned long os_mask(unsigned long m, signed char const *to) {
  unsigned long o = 0;
  for (int s = 1; s < 32; s++)
    if (m & (1UL << (s - 1))) { long t = to[s]; if (t > 0) o |= 1UL << (t - 1); }
  return o; }
unsigned long __love_maskfb(unsigned long m) { return os_mask(m, os_sigfb); }
unsigned long __love_maskcan(unsigned long m) { return os_mask(m, os_sigcan); }

long __love_safb(long f) {
  long o = 0;
  if (f & SA_ONSTACK)   o |= 1;
  if (f & SA_RESTART)   o |= 2;
  if (f & SA_RESETHAND) o |= 4;
  if (f & SA_NOCLDSTOP) o |= 8;
  if (f & SA_NODEFER)   o |= 16;
  if (f & SA_NOCLDWAIT) o |= 32;
  if (f & SA_SIGINFO)   o |= 64;
  return o; }
long __love_sacan(long f) {
  long o = 0;
  if (f & 1)  o |= SA_ONSTACK;
  if (f & 2)  o |= SA_RESTART;
  if (f & 4)  o |= SA_RESETHAND;
  if (f & 8)  o |= SA_NOCLDSTOP;
  if (f & 16) o |= SA_NODEFER;
  if (f & 32) o |= SA_NOCLDWAIT;
  if (f & 64) o |= SA_SIGINFO;
  return o; }
#endif
