#ifndef _AI_SYS_IOCTL_H
#define _AI_SYS_IOCTL_H
#include <sys/types.h>
struct winsize { unsigned short ws_row, ws_col, ws_xpixel, ws_ypixel; };
#define TIOCSCTTY  21518
#define TIOCGWINSZ 21523
#define TIOCSWINSZ 21524
int ioctl(int, unsigned long, ...);
#endif
