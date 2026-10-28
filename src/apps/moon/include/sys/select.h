#pragma once
#include <sys/types.h>
#include <sys/time.h>
/* glibc's layout: 1024 bits as 16 longs, as the kernel reads it */
#define FD_SETSIZE 1024
#define __NFDBITS (8 * (int) sizeof(unsigned long))
typedef struct { unsigned long fds_bits[FD_SETSIZE / (8 * sizeof(unsigned long))]; } fd_set;
#define __FDELT(d)  ((d) / __NFDBITS)
#define __FDMASK(d) (1UL << ((d) % __NFDBITS))
#define FD_ZERO(s) do { unsigned long *__b = (s)->fds_bits; int __i; \
  for (__i = 0; __i < FD_SETSIZE / __NFDBITS; __i++) __b[__i] = 0; } while (0)
#define FD_SET(d, s)   ((s)->fds_bits[__FDELT(d)] |= __FDMASK(d))
#define FD_CLR(d, s)   ((s)->fds_bits[__FDELT(d)] &= ~__FDMASK(d))
#define FD_ISSET(d, s) (((s)->fds_bits[__FDELT(d)] & __FDMASK(d)) != 0)
int select(int, fd_set*, fd_set*, fd_set*, struct timeval*);
