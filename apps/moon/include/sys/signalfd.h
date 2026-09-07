#ifndef _AI_SYS_SIGNALFD_H
#define _AI_SYS_SIGNALFD_H
#include <signal.h>
#define SFD_CLOEXEC  524288
#define SFD_NONBLOCK   2048
/* 128 bytes on the wire; the head fields + a pad to size */
struct signalfd_siginfo {
  unsigned int  ssi_signo;
  int           ssi_errno;
  int           ssi_code;
  unsigned int  ssi_pid;
  unsigned int  ssi_uid;
  int           ssi_fd;
  unsigned int  ssi_tid;
  unsigned int  ssi_band;
  unsigned int  ssi_overrun;
  unsigned int  ssi_trapno;
  int           ssi_status;
  int           ssi_int;
  unsigned long ssi_ptr;
  unsigned long ssi_utime;
  unsigned long ssi_stime;
  unsigned long ssi_addr;
  unsigned short ssi_addr_lsb;
  char __pad[46];
};
int signalfd(int, sigset_t const*, int);
#endif
