#include "../impl.h"

int ioctl(int fd, unsigned long req, ...) {
  va_list ap; va_start(ap, req);
  long arg = va_arg(ap, long);
  va_end(ap);
  if (__love_osv >= 2) {
    /* the encodings part wholesale; the requests whose PAYLOAD agrees
     * translate here, and an unknown one refuses loudly rather than firing
     * a foreign encoding at the kernel. termios rides its own members
     * (another struct, not just another number). */
    unsigned long fq;
    switch (req) {
      case 21523: fq = 0x40087468UL; break;   /* TIOCGWINSZ: struct winsize agrees */
      case 21524: fq = 0x80087467UL; break;   /* TIOCSWINSZ */
      case 21518: fq = 0x20007461UL; break;   /* TIOCSCTTY: void */
      case 21519: fq = 0x40047477UL; break;   /* TIOCGPGRP: int */
      case 21520: fq = 0x80047476UL; break;   /* TIOCSPGRP: int */
      case 21531: fq = 0x4004667fUL; break;   /* FIONREAD: int */
      /* the sound doors (src/love/horn.c): OSS's ints on freebsd, where _IOWR spells
       * alike and _IOR/_IOW swap their direction bits; audio(4)'s info on netbsd,
       * which linux lacks, so its linux _IOC spelling is the canonical face */
      case 0xc0045002UL: case 0xc0045005UL: case 0xc0045006UL:   /* SNDCTL_DSP_SPEED, SETFMT, CHANNELS */
        fq = __love_osv == 2 ? req : 0; break;
      case 0x80045017UL: fq = __love_osv == 2 ? 0x40045017UL : 0; break;   /* SNDCTL_DSP_GETODELAY */
      case 0x40045010UL: fq = __love_osv == 2 ? 0x80045010UL : 0; break;   /* SNDCTL_DSP_SETTRIGGER */
      case 0x80884115UL: fq = __love_osv == 3 ? 0x40884115UL : 0; break;   /* AUDIO_GETINFO */
      case 0xc0884116UL: fq = __love_osv == 3 ? req : 0; break;            /* AUDIO_SETINFO */
      case 0x80884123UL: fq = __love_osv == 3 ? 0x40884123UL : 0; break;   /* AUDIO_GETBUFINFO */
      default: fq = 0; }
    if (!fq) { __errno_v = ENOSYS; return -1; }
    return (int) er(fb3(NR_fb_ioctl, fd, (long) fq, arg)); }
  return (int) er(sc3(NR_ioctl, fd, (long) req, arg)); }
