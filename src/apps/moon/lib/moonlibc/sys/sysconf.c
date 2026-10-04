#include <sys/sysctl.h>
#include "../impl.h"

/* linux's struct sysinfo (112 bytes on 64-bit); the tail is slack past what it writes */
struct lx_sysinfo {
  long uptime;
  unsigned long loads[3], totalram, freeram, sharedram, bufferram, totalswap, freeswap;
  unsigned short procs, pad;
  unsigned long totalhigh, freehigh;
  unsigned int mem_unit;
  char tail[8]; };

static long num(char **p) {
  long v = 0;
  while (**p >= '0' && **p <= '9') v = v * 10 + *(*p)++ - '0';
  return v; }

/* a cpu list file, "0-3,6,8-9", counted; -1 where it cannot be read */
static long cpu_list(char const *p) {
  char b[256];
  int fd = open(p, O_RDONLY);
  if (fd < 0) return -1;
  long n = (long) read(fd, b, sizeof b - 1);
  close(fd);
  if (n <= 0) return -1;
  b[n] = 0;
  long c = 0;
  for (char *s = b; *s >= '0' && *s <= '9'; ) {
    long lo = num(&s), hi = lo;
    if (*s == '-') s++, hi = num(&s);
    c += hi - lo + 1;
    if (*s != ',') break;
    s++; }
  return c ? c : -1; }

static long bsd_long(int a, int b) {
  int mib[2] = { a, b };
  long long v = 0;
  size_t n = sizeof v;
  if (sysctl(mib, 2, &v, &n, 0, 0)) return -1;
  return n == sizeof(int) ? (long) *(int *) &v : (long) v; }

/* the kernel's page, AT_PAGESZ: 16K on a pi 5's kernel, 4K where no auxv says (inle) */
static long page_size(void) { unsigned long p = getauxval(6); return p ? (long) p : 4096; }

/* linux answers from /sys and sysinfo(2), the BSDs from hw.*; inle has no answer yet */
long sysconf(int name) {
  long v = __love_osv;
  if (!v) v = __love_osv = __love_osdetect();
  switch (name) {
  case _SC_PAGESIZE: return page_size();
  case _SC_NPROCESSORS_CONF:
  case _SC_NPROCESSORS_ONLN:
   if (v >= 2) return bsd_long(CTL_HW, HW_NCPU);
   return cpu_list(name == _SC_NPROCESSORS_CONF ? "/sys/devices/system/cpu/present"
                                               : "/sys/devices/system/cpu/online");
  case _SC_PHYS_PAGES:
  case _SC_AVPHYS_PAGES:
   if (v >= 2) {
    if (name == _SC_AVPHYS_PAGES) break;                    /* no fixed mib on either BSD */
    long m = bsd_long(CTL_HW, v == 3 ? HW_PHYSMEM64 : HW_PHYSMEM);
    return m < 0 ? -1 : m / page_size(); }
   { struct lx_sysinfo si;
     if (er(sc1(NR_sysinfo, (long) &si)) < 0) return -1;
     unsigned long u = si.mem_unit ? si.mem_unit : 1;
     return (long) ((name == _SC_PHYS_PAGES ? si.totalram : si.freeram) * u / page_size()); } }
  __errno_v = EINVAL; return -1; }
