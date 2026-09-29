#ifndef _AI_LINUX_FD_H
#define _AI_LINUX_FD_H
/* freestanding linux/fd.h for cc: just FDFLUSH, the one floppy ioctl tar's
   compare.c reaches for (`#ifdef FDFLUSH` guards its use). the real kernel
   header carries bitfield structs (struct floppy_fdc_state) mooncc can't yet
   parse -- this shim stops the /usr/include fallthrough from pulling them. */
#include <sys/ioctl.h>
#define FDFLUSH _IO(2, 0x4b)
#endif
