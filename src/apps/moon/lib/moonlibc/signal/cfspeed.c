#include "../impl.h"
#include <termios.h>

/* speeds are numbers, and c_cflag keeps linux's code for each in step: CBAUD the output's,
 * CIBAUD the input's, BOTHER for a rate with none */
static unsigned int const tio_rate[] = {
  0, 50, 75, 110, 134, 150, 200, 300, 600, 1200, 1800, 2400, 4800, 9600, 19200, 38400,
  57600, 115200, 230400, 460800, 500000, 576000, 921600, 1000000, 1152000, 1500000,
  2000000, 2500000, 3000000, 3500000, 4000000 };
unsigned int __love_bcode(speed_t s) {
  for (unsigned int i = 0; i < sizeof tio_rate / sizeof *tio_rate; i++)
    if (tio_rate[i] == s) return i < 16 ? i : BOTHER | (i - 15);
  return BOTHER; }
speed_t __love_bnum(unsigned int c) {             /* 0 for BOTHER: the rate is in termios2 */
  unsigned int i = c & BOTHER ? 15 + (c & 15) : c & 15;
  return c == BOTHER || i >= sizeof tio_rate / sizeof *tio_rate ? 0 : tio_rate[i]; }
speed_t cfgetospeed(struct termios const *t) { return t->c_ospeed; }
speed_t cfgetispeed(struct termios const *t) { return t->c_ispeed; }
int cfsetospeed(struct termios *t, speed_t s) {
  t->c_cflag = (t->c_cflag & ~(tcflag_t) CBAUD) | __love_bcode(s), t->c_ospeed = s;
  return 0; }
int cfsetispeed(struct termios *t, speed_t s) {     /* 0: the output's speed */
  t->c_cflag = (t->c_cflag & ~(tcflag_t) CIBAUD) | (s ? __love_bcode(s) << 16 : 0), t->c_ispeed = s;
  return 0; }
int cfsetspeed(struct termios *t, speed_t s) { cfsetispeed(t, s); return cfsetospeed(t, s); }
