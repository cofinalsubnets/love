#ifndef _AI_SYS_SYSMACROS_H
#define _AI_SYS_SYSMACROS_H
/* freestanding sys/sysmacros.h for cc: split/join a device number. the classic
 * 8:8 encoding -- enough to round-trip through mknod for a userland build. */
#define major(d)     ((int)(((d) >> 8) & 0xff))
#define minor(d)     ((int)((d) & 0xff))
#define makedev(m, n) ((((m) & 0xff) << 8) | ((n) & 0xff))
#endif
