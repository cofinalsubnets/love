#pragma once
/* the v7 terminal interface, enough for a HAVE_SGTTY_H build to type-check */
#include <sys/ioctl.h>

struct sgttyb {
	char  sg_ispeed;
	char  sg_ospeed;
	char  sg_erase;
	char  sg_kill;
	short sg_flags;
};

#define TIOCGETP _IOR('t',  8, struct sgttyb)
#define TIOCSETP _IOW('t',  9, struct sgttyb)
#define TIOCGETC _IOR('t', 18, struct sgttyb)
#define TIOCSETC _IOW('t', 17, struct sgttyb)
