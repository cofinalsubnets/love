#pragma once
#include <sys/types.h>
typedef unsigned int  tcflag_t;
typedef unsigned char cc_t;
typedef unsigned int  speed_t;
/* glibc x86-64's 60-byte layout */
struct termios {
  tcflag_t c_iflag, c_oflag, c_cflag, c_lflag;
  cc_t c_line;
  cc_t c_cc[32];
  speed_t c_ispeed, c_ospeed;
};
/* linux's flags; ostio.c's rows respell them for the BSDs, and an unnamed one drops there */
#define IGNBRK      1
#define BRKINT      2
#define IGNPAR      4
#define PARMRK      8
#define INPCK      16
#define ISTRIP     32
#define INLCR      64
#define IGNCR     128
#define ICRNL     256
#define IXANY    2048
#define IXOFF    4096
#define IMAXBEL  8192
#define OPOST       1
#define ONLCR       4
#define OCRNL       8
#define ONOCR      16
#define ONLRET     32
#define CSIZE      48
#define CS5         0
#define CS6        16
#define CS7        32
#define CS8        48
#define CSTOPB     64
#define CREAD     128
#define PARENB    256
#define PARODD    512
#define HUPCL    1024
#define CLOCAL   2048
#define CRTSCTS  0x80000000u
#define ECHO        8
#define ECHOE      16
#define ECHOK      32
#define ECHONL     64
#define NOFLSH    128
#ifdef __mips__
#define TOSTOP    32768
#else
#define TOSTOP    256
#endif
#define ECHOCTL   512
#define ECHOPRT  1024
#define ECHOKE   2048
#ifdef __mips__
#define FLUSHO   8192
#else
#define FLUSHO   4096
#endif
#define PENDIN  16384
/* a speed is its number, as glibc and the BSDs spell it; tcsetattr lays linux's CBAUD code */
#define CBAUD   0x100f
#define CIBAUD  0x100f0000
#define BOTHER  0x1000
#define B0        0
#define B50       50
#define B75       75
#define B110      110
#define B134      134
#define B150      150
#define B200      200
#define B300      300
#define B600      600
#define B1200     1200
#define B1800     1800
#define B2400     2400
#define B4800     4800
#define B9600     9600
#define B19200    19200
#define B38400    38400
#define B57600    57600
#define B115200   115200
#define B230400   230400
#define B460800   460800
#define B500000   500000
#define B576000   576000
#define B921600   921600
#define B1000000  1000000
#define B1152000  1152000
#define B1500000  1500000
#define B2000000  2000000
#define B2500000  2500000
#define B3000000  3000000
#define B3500000  3500000
#define B4000000  4000000
#define TCSANOW   0
#define TCSADRAIN 1
#define TCSAFLUSH 2
#define IXON 1024
#define ISIG    1
#define ICANON  2
#ifdef __mips__
#define IEXTEN 256
#else
#define IEXTEN 32768
#endif
#define NCCS   32
#define VINTR   0
#define VQUIT   1
#define VERASE  2
#define VKILL   3
#ifdef __mips__
#define VEOF    16
#define VTIME   5
#define VMIN    4
#else
#define VEOF    4
#define VTIME   5
#define VMIN    6
#endif
#define VSTART  8
#define VSTOP   9
#define VSUSP  10
#ifdef __mips__
#define VEOL   17
#else
#define VEOL   11
#endif
#define VREPRINT 12
#define VDISCARD 13
#define VWERASE 14
#define VLNEXT 15
#ifdef __mips__
#define VEOL2  6
#else
#define VEOL2  16
#endif
#define TCIFLUSH  0
#define TCOFLUSH  1
#define TCIOFLUSH 2
#define TCOOFF 0
#define TCOON  1
#define TCIOFF 2
#define TCION  3
int tcgetattr(int, struct termios*), tcsetattr(int, int, struct termios const*),
    tcsendbreak(int, int), tcdrain(int), tcflush(int, int), tcflow(int, int);
pid_t tcgetpgrp(int);
speed_t cfgetispeed(struct termios const*), cfgetospeed(struct termios const*);
int cfsetispeed(struct termios*, speed_t), cfsetospeed(struct termios*, speed_t),
    cfsetspeed(struct termios*, speed_t);
void cfmakeraw(struct termios*);
int tcsetpgrp(int, pid_t);
