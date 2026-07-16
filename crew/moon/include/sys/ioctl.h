#ifndef _AI_SYS_IOCTL_H
#define _AI_SYS_IOCTL_H
#include <sys/types.h>
struct winsize { unsigned short ws_row, ws_col, ws_xpixel, ws_ypixel; };
#define TIOCSCTTY  21518
#define TIOCGWINSZ 21523
#define TIOCSWINSZ 21524

/* the linux _IOC encoding: dir<<30 | size<<16 | type<<8 | nr. */
#define _IOC_NRBITS   8
#define _IOC_TYPEBITS 8
#define _IOC_SIZEBITS 14
#define _IOC_NONE  0U
#define _IOC_WRITE 1U
#define _IOC_READ  2U
#define _IOC(dir, type, nr, size) \
	(((dir) << 30) | ((type) << 8) | (nr) | ((size) << 16))
#define _IO(type, nr)         _IOC(_IOC_NONE, (type), (nr), 0)
#define _IOR(type, nr, sz)    _IOC(_IOC_READ, (type), (nr), sizeof(sz))
#define _IOW(type, nr, sz)    _IOC(_IOC_WRITE, (type), (nr), sizeof(sz))
#define _IOWR(type, nr, sz)   _IOC(_IOC_READ | _IOC_WRITE, (type), (nr), sizeof(sz))

int ioctl(int, unsigned long, ...);
#endif
