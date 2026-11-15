/* the kernel's caller and here addresses, for a mooncc build: no &&label, so here is 0 */
#ifndef _LINUX_INSTRUCTION_POINTER_H
#define _LINUX_INSTRUCTION_POINTER_H
#include <asm/linkage.h>

#define _RET_IP_ ((unsigned long) __builtin_return_address(0))
#ifndef _THIS_IP_
#define _THIS_IP_ ((unsigned long) 0)
#endif

#endif
