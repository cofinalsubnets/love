#ifndef _LOVE_SYS_SYSMACROS_H
#define _LOVE_SYS_SYSMACROS_H
/* the classic 8:8 device number */
#define major(d)     ((int)(((d) >> 8) & 0xff))
#define minor(d)     ((int)((d) & 0xff))
#define makedev(m, n) ((((m) & 0xff) << 8) | ((n) & 0xff))
#endif
