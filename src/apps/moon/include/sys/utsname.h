#ifndef _LOVE_SYS_UTSNAME_H
#define _LOVE_SYS_UTSNAME_H
/* linux's new_utsname, filled in place; the bsds build it from kern.* and hw.machine */
struct utsname {
  char sysname[65];
  char nodename[65];
  char release[65];
  char version[65];
  char machine[65];
  char domainname[65];
};
int uname(struct utsname *);
#endif
