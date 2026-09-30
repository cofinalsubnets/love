#ifndef _AI_SYS_SYSCTL_H
#define _AI_SYS_SYSCTL_H
/* the BSDs' kernel mib walk; linux has none, and the member answers ENOSYS there.
 * the kern.* and hw.* numbers below are the same on freebsd and netbsd */
#include <stddef.h>
#define CTL_KERN            1
#define KERN_OSTYPE         1
#define KERN_OSRELEASE      2
#define KERN_VERSION        4
#define KERN_HOSTNAME      10
#define KERN_PROC          14
#define KERN_PROC_PATHNAME 12
#define CTL_HW              6
#define HW_MACHINE          1
#define HW_NCPU             3
#define HW_PHYSMEM          5     /* freebsd: an unsigned long */
#define HW_PHYSMEM64       13     /* netbsd: an int64; its HW_PHYSMEM is 32-bit */
int sysctl(int const*, unsigned int, void*, size_t*, void const*, size_t);
#endif
