#include "../impl.h"
#include <termios.h>

void cfmakeraw(struct termios *t) {
  t->c_iflag &= ~(tcflag_t) (IGNBRK | BRKINT | PARMRK | ISTRIP | INLCR | IGNCR | ICRNL | IXON);
  t->c_oflag &= ~(tcflag_t) OPOST;
  t->c_lflag &= ~(tcflag_t) (ECHO | ECHONL | ICANON | ISIG | IEXTEN);
  t->c_cflag = (t->c_cflag & ~(tcflag_t) (CSIZE | PARENB)) | CS8;
  t->c_cc[VMIN] = 1, t->c_cc[VTIME] = 0; }
