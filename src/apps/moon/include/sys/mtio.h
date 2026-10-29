#pragma once
/* magnetic-tape ioctls, as tar's rmt client speaks them; linux's values */
#include <sys/ioctl.h>

struct mtop {
	short mt_op;
	int   mt_count;
};

#define MTRESET  0
#define MTFSF    1  /* forward space over file mark */
#define MTBSF    2  /* backward space over file mark */
#define MTFSR    3  /* forward space record */
#define MTBSR    4  /* backward space record */
#define MTWEOF   5
#define MTREW    6
#define MTOFFL   7  /* rewind and unload */
#define MTNOP    8  /* no-op, sets status */
#define MTRETEN  9  /* retension */
#define MTBSFM   10 /* backward space file mark, position at eof */
#define MTFSFM   11 /* forward space file mark, position at bof */
#define MTEOM    12 /* goto end of recorded media */
#define MTERASE  13
#define MTRAS1   14
#define MTRAS2   15
#define MTRAS3   16
#define MTSETBLK 20
#define MTSETDENSITY 21
#define MTSEEK   22
#define MTTELL   23

struct mtget {
	long mt_type;
	long mt_resid;
	long mt_dsreg;
	long mt_gstat;
	long mt_erreg;
	int  mt_fileno;
	int  mt_blkno;
};

struct mtpos {
	long mt_blkno;
};

#define MTIOCTOP _IOW('m', 1, struct mtop)
#define MTIOCGET _IOR('m', 2, struct mtget)
#define MTIOCPOS _IOR('m', 3, struct mtpos)
