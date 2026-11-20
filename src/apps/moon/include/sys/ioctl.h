#pragma once
#include <sys/types.h>
struct winsize { unsigned short ws_row, ws_col, ws_xpixel, ws_ypixel; };
#ifdef __mips__               /* mips's own, the window pair by _IOR and _IOW */
#define TIOCSCTTY  0x5480
#define TIOCGWINSZ 0x40087468
#define TIOCSWINSZ 0x80087467
#define FIONREAD   0x467f
#define TIOCMGET   0x741d
#define TIOCMSET   0x741a
#else
#define TIOCSCTTY  21518
#define TIOCGWINSZ 21523
#define TIOCSWINSZ 21524
#define FIONREAD   21531
#define TIOCMGET   21525
#define TIOCMSET   21528
#endif
#define TIOCM_DTR  2
#define TIOCM_RTS  4

/* linux's _IOC encoding: dir<<30 | size<<16 | type<<8 | nr; mips's dir is 3 bits at 29, its size 13 */
#define _IOC_NRBITS   8
#define _IOC_TYPEBITS 8
#ifdef __mips__
#define _IOC_SIZEBITS 13
#define _IOC_NONE  1U
#define _IOC_WRITE 4U
#define _IOC_DIRSHIFT 29
#else
#define _IOC_SIZEBITS 14
#define _IOC_NONE  0U
#define _IOC_WRITE 1U
#define _IOC_DIRSHIFT 30
#endif
#define _IOC_READ  2U
#define _IOC(dir, type, nr, size) \
	(((dir) << _IOC_DIRSHIFT) | ((type) << 8) | (nr) | ((size) << 16))
#define _IO(type, nr)         _IOC(_IOC_NONE, (type), (nr), 0)
#define _IOR(type, nr, sz)    _IOC(_IOC_READ, (type), (nr), sizeof(sz))
#define _IOW(type, nr, sz)    _IOC(_IOC_WRITE, (type), (nr), sizeof(sz))
#define _IOWR(type, nr, sz)   _IOC(_IOC_READ | _IOC_WRITE, (type), (nr), sizeof(sz))

int ioctl(int, unsigned long, ...);
