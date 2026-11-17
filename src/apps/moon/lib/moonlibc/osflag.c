/* open and mmap flags, canonical <-> the BSDs' and macos's */
#include "impl.h"

#ifndef LvOsTranslate
long __love_ofb(long f) { return f; }
long __love_ocan(long f) { return f; }
long __love_mapfb(long f) { return f; }
#else
/* open flags: the access mode rides, named bits translate, the rest drop. the BSDs agree
 * but for NOCTTY (macos 0x20000), DIRECTORY and CLOEXEC */
static long const os_odir[] = {0x20000, 0x200000, 0x100000};
static long const os_oclo[] = {0x100000, 0x400000, 0x1000000};
static long os_ok(void) { return __love_osv == 4 ? 2 : __love_osv == 3; }
long __love_ofb(long f) {
  long o = f & 3, k = os_ok();
  if (f & O_CREAT)     o |= 0x200;
  if (f & O_EXCL)      o |= 0x800;
  if (f & O_NOCTTY)    o |= k == 2 ? 0x20000 : 0x8000;
  if (f & O_TRUNC)     o |= 0x400;
  if (f & O_APPEND)    o |= 8;
  if (f & O_NONBLOCK)  o |= 4;
  if (f & O_DIRECTORY) o |= os_odir[k];
  if (f & O_NOFOLLOW)  o |= 0x100;
  if (f & O_CLOEXEC)   o |= os_oclo[k];
  return o; }
long __love_ocan(long f) {
  long o = f & 3, k = os_ok();
  if (f & 0x200)    o |= O_CREAT;
  if (f & 0x800)    o |= O_EXCL;
  if (f & (k == 2 ? 0x20000 : 0x8000)) o |= O_NOCTTY;
  if (f & 0x400)    o |= O_TRUNC;
  if (f & 8)        o |= O_APPEND;
  if (f & 4)        o |= O_NONBLOCK;
  if (f & os_odir[k]) o |= O_DIRECTORY;
  if (f & 0x100)    o |= O_NOFOLLOW;
  if (f & os_oclo[k]) o |= O_CLOEXEC;
  return o; }

/* mmap flags: SHARED 1 / PRIVATE 2 / FIXED 0x10 agree; ANON moves to 0x1000;
 * POPULATE and the other linux hints have no twin and drop. */
long __love_mapfb(long f) {
  long o = f & 0x13;
  if (f & MAP_ANON) o |= 0x1000;
  return o; }
#endif
