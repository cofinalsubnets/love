/* termios, canonical <-> the BSDs' and macos's */
#include "impl.h"

#ifndef LvOsTranslate
void __love_tiofb(struct termios const *t, struct __fb_termios *f) { }
void __love_tiocan(struct __fb_termios const *f, struct termios *t) { }
void __love_tiokeep(struct __fb_termios *f, struct __fb_termios const *cur) { }
#else
/* termios rows are {canonical bit, freebsd bit}; an unnamed bit drops. speeds copy verbatim */
static unsigned int const os_tio_i[][2] = {   /* c_iflag */
  {1, 1}, {2, 2}, {4, 4}, {8, 8}, {16, 16}, {32, 32}, {64, 64}, {128, 128},
  {256, 256}, {0x400, 0x200} /* IXON */, {0x1000, 0x400} /* IXOFF */,
  {0x800, 0x800}, {0x2000, 0x2000} };
static unsigned int const os_tio_o[][2] = {   /* c_oflag */
  {1, 1} /* OPOST */, {4, 2} /* ONLCR */ };
static unsigned int const os_tio_c[][2] = {   /* c_cflag: freebsd is linux<<4 */
  {0x10, 0x100}, {0x20, 0x200} /* CSIZE */, {0x40, 0x400} /* CSTOPB */,
  {0x80, 0x800} /* CREAD */, {0x100, 0x1000} /* PARENB */,
  {0x200, 0x2000} /* PARODD */, {0x400, 0x4000} /* HUPCL */,
  {0x800, 0x8000} /* CLOCAL */, {0x80000000, 0x30000} /* CRTSCTS */ };
static unsigned int const os_tio_l[][2] = {   /* c_lflag */
  {1, 0x80} /* ISIG */, {2, 0x100} /* ICANON */, {8, 8} /* ECHO */,
  {0x10, 2} /* ECHOE */, {0x20, 4} /* ECHOK */, {0x40, 0x10} /* ECHONL */,
  {0x80, 0x80000000} /* NOFLSH */, {0x100, 0x400000} /* TOSTOP */,
  {0x200, 0x40} /* ECHOCTL */, {0x400, 0x20} /* ECHOPRT */,
  {0x800, 1} /* ECHOKE */, {0x1000, 0x800000} /* FLUSHO */,
  {0x4000, 0x20000000} /* PENDIN */, {0x8000, 0x400} /* IEXTEN */ };
static signed char const os_tio_cc[17] = {    /* canonical index -> freebsd's */
  8, 9, 3, 5, 0, 17, 16, -1, 12, 13, 10, 1, 6, 15, 4, 14, 2 };
static unsigned int os_tiow(unsigned int v, unsigned int const (*row)[2], int n, int can) {
  unsigned int o = 0;
  for (int i = 0; i < n; i++)
    if (v & row[i][can ? 1 : 0]) o |= row[i][can ? 0 : 1];
  return o; }
void __love_tiofb(struct termios const *t, struct __fb_termios *f) {
  memset(f, 0, sizeof *f);
  f->c_iflag = os_tiow(t->c_iflag, os_tio_i, sizeof os_tio_i / 8, 0);
  f->c_oflag = os_tiow(t->c_oflag, os_tio_o, sizeof os_tio_o / 8, 0);
  f->c_cflag = os_tiow(t->c_cflag, os_tio_c, sizeof os_tio_c / 8, 0);
  f->c_lflag = os_tiow(t->c_lflag, os_tio_l, sizeof os_tio_l / 8, 0);
  /* a disabled slot is 0 in the canonical spelling and 0xff here; vmin and vtime
   * (5, 6) are counts, where 0 is a value. a slot linux has no name for stays off */
  memset(f->c_cc, 0xff, sizeof f->c_cc);
  for (int i = 0; i < 17; i++)
    if (os_tio_cc[i] >= 0)
      f->c_cc[(int) os_tio_cc[i]] = t->c_cc[i] || i == 5 || i == 6 ? t->c_cc[i] : 0xff;
  /* netbsd spells CRTSCTS as the low bit alone; the high one is foreign there */
  if (__love_osv == 3 && (f->c_cflag & 0x30000)) f->c_cflag = (f->c_cflag & ~0x30000u) | 0x10000;
  f->c_ispeed = t->c_ispeed; f->c_ospeed = t->c_ospeed; }
/* the slots linux has no name for (status, dsusp) kept as the terminal has them */
void __love_tiokeep(struct __fb_termios *f, struct __fb_termios const *cur) {
  unsigned char named[20] = {0};
  for (int i = 0; i < 17; i++) if (os_tio_cc[i] >= 0) named[(int) os_tio_cc[i]] = 1;
  for (int k = 0; k < 20; k++) if (!named[k]) f->c_cc[k] = cur->c_cc[k]; }
void __love_tiocan(struct __fb_termios const *f, struct termios *t) {
  memset(t, 0, sizeof *t);
  t->c_iflag = os_tiow(f->c_iflag, os_tio_i, sizeof os_tio_i / 8, 1);
  t->c_oflag = os_tiow(f->c_oflag, os_tio_o, sizeof os_tio_o / 8, 1);
  t->c_cflag = os_tiow(f->c_cflag, os_tio_c, sizeof os_tio_c / 8, 1);
  t->c_lflag = os_tiow(f->c_lflag, os_tio_l, sizeof os_tio_l / 8, 1);
  for (int i = 0; i < 17; i++)
    if (os_tio_cc[i] >= 0) {
      unsigned char c = f->c_cc[(int) os_tio_cc[i]];
      t->c_cc[i] = c == 0xff && i != 5 && i != 6 ? 0 : c; }
  t->c_ispeed = f->c_ispeed; t->c_ospeed = f->c_ospeed; }

#ifdef LvMac
/* its termios: freebsd's bits, each word a long */
void __love_tiomac(struct __fb_termios const *f, struct __mac_termios *m) {
  memset(m, 0, sizeof *m);
  m->c_iflag = f->c_iflag, m->c_oflag = f->c_oflag, m->c_cflag = f->c_cflag, m->c_lflag = f->c_lflag;
  memcpy(m->c_cc, f->c_cc, 20);
  m->c_ispeed = f->c_ispeed, m->c_ospeed = f->c_ospeed; }
void __love_tiounmac(struct __mac_termios const *m, struct __fb_termios *f) {
  memset(f, 0, sizeof *f);
  f->c_iflag = (unsigned int) m->c_iflag, f->c_oflag = (unsigned int) m->c_oflag;
  f->c_cflag = (unsigned int) m->c_cflag, f->c_lflag = (unsigned int) m->c_lflag;
  memcpy(f->c_cc, m->c_cc, 20);
  f->c_ispeed = (unsigned int) m->c_ispeed, f->c_ospeed = (unsigned int) m->c_ospeed; }
#endif
#endif
