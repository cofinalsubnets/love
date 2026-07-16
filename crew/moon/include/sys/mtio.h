#ifndef _AI_SYS_MTIO_H
#define _AI_SYS_MTIO_H
/* freestanding sys/mtio.h for cc: magnetic-tape ioctls. the struct/op set tar's
 * rmt client speaks; values match linux <sys/mtio.h>. */
#include <sys/ioctl.h>

struct mtop {
	short mt_op;    /* operation, one of the MT* below */
	int   mt_count; /* repeat count */
};

/* mt_op operations */
#define MTRESET  0
#define MTFSF    1  /* forward space over file mark */
#define MTBSF    2  /* backward space over file mark */
#define MTFSR    3  /* forward space record */
#define MTBSR    4  /* backward space record */
#define MTWEOF   5  /* write file mark */
#define MTREW    6  /* rewind */
#define MTOFFL   7  /* rewind and unload */
#define MTNOP    8  /* no-op, sets status */
#define MTRETEN  9  /* retension */
#define MTBSFM   10 /* backward space file mark, position at eof */
#define MTFSFM   11 /* forward space file mark, position at bof */
#define MTEOM    12 /* goto end of recorded media */
#define MTERASE  13 /* erase */
#define MTRAS1   14
#define MTRAS2   15
#define MTRAS3   16
#define MTSETBLK 20 /* set block length */
#define MTSETDENSITY 21
#define MTSEEK   22
#define MTTELL   23

struct mtget {
	long mt_type;   /* type of magtape device */
	long mt_resid;  /* residual count */
	long mt_dsreg;  /* status register */
	long mt_gstat;  /* generic status */
	long mt_erreg;  /* error register */
	int  mt_fileno; /* file number of current position */
	int  mt_blkno;  /* block number of current position */
};

struct mtpos {
	long mt_blkno; /* current block number */
};

#define MTIOCTOP _IOW('m', 1, struct mtop)
#define MTIOCGET _IOR('m', 2, struct mtget)
#define MTIOCPOS _IOR('m', 3, struct mtpos)
#endif
