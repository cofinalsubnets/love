#ifndef _LOVE_LINUX_FD_H
#define _LOVE_LINUX_FD_H
/* just FDFLUSH, the floppy ioctl tar reaches for */
#include <sys/ioctl.h>
#define FDFLUSH _IO(2, 0x4b)
#endif
