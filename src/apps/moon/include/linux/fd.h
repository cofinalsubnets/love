#pragma once
/* just FDFLUSH, the floppy ioctl tar reaches for */
#include <sys/ioctl.h>
#define FDFLUSH _IO(2, 0x4b)
