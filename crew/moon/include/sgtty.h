#ifndef _AI_SGTTY_H
#define _AI_SGTTY_H
/* freestanding sgtty.h for cc: the old BSD v7 terminal interface. modern code
 * only reaches it through legacy guards; provide the struct + the classic
 * ioctls so a HAVE_SGTTY_H build type-checks without the glibc header. */
#include <sys/ioctl.h>

struct sgttyb {
	char  sg_ispeed; /* input speed */
	char  sg_ospeed; /* output speed */
	char  sg_erase;  /* erase character */
	char  sg_kill;   /* kill character */
	short sg_flags;  /* mode flags */
};

#define TIOCGETP _IOR('t',  8, struct sgttyb)
#define TIOCSETP _IOW('t',  9, struct sgttyb)
#define TIOCGETC _IOR('t', 18, struct sgttyb)
#define TIOCSETC _IOW('t', 17, struct sgttyb)
#endif
