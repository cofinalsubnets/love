#include "../impl.h"

int waitpid(int pid, int *st, int opt) {
#if defined(__riscv) && defined(__ILP32__)
  /* rv32 linux has no wait4: waitid, exited ones only (4, WEXITED) unless asked, the status laid
   * back as wait4's. P_PGID 2 with 0 is the caller's group, P_ALL 0, P_PID 1 */
  siginfo_t si;
  si.si_pid = 0;
  long t = pid < -1 || pid == 0 ? 2 : pid == -1 ? 0 : 1, id = pid < -1 ? -pid : pid == -1 ? 0 : pid;
  if (er(sc5(NR_waitid, t, id, (long) &si, opt | 4, 0)) < 0) return -1;
  if (!si.si_pid) return 0;                             /* WNOHANG, none ready */
  if (st) switch (si.si_code) {
    case 1: *st = (si.si_status & 255) << 8; break;     /* CLD_EXITED */
    case 2: *st = si.si_status & 127; break;            /* CLD_KILLED */
    case 3: *st = (si.si_status & 127) | 128; break;    /* CLD_DUMPED */
    case 6: *st = 0xffff; break;                        /* CLD_CONTINUED */
    default: *st = (si.si_status & 255) << 8 | 127; }   /* CLD_TRAPPED, CLD_STOPPED */
  return si.si_pid;
#endif
  long r = er(sc4(NR_wait4, pid, (long) st, opt, 0));
  if (__love_osv >= 2 && r > 0 && st) {
    /* the status layout agrees, but the signal in it is the BSD's number */
    int s = *st;
    if ((s & 0x7f) != 0 && (s & 0x7f) != 0x7f)
      *st = (s & ~0x7f) | (int) __love_sigcan(s & 0x7f);
    else if ((s & 0xff) == 0x7f)
      *st = (s & 0xff) | ((int) __love_sigcan((s >> 8) & 0xff) << 8); }
  return (int) r; }
