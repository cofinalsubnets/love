// i/noosv.c -- what a link with no moonlibc under it owes: the OS variant word.
// moonlibc's os.c owns __ai_osv and writes it at start, and every syscall reaches the
// right table through it; a negative one is the inle arm. a link built against the
// ambient libc instead -- love0, the HCC flavour, the all-mooncc gate -- has no os.c, so
// it says the word itself, and 0 is hosted, which all three are.
//
// its own translation unit because it is a LINK's answer and not a directory's: common.mk
// keeps it out of host_c, each link that wants it names it, and one that ends up with two
// collides rather than going quiet.
#include "love.h"

// ..and only where there is no moonlibc: mooncc sets LvNolibc (l/love.h), and a TU it
// compiled links moonlibc's os.c, which owns the word and writes it at start. love0 is
// the link that goes both ways -- the ambient cc normally, mooncc where the seed has
// poisoned every compiler -- so the guard is the compiler's, not the rule's.
#if !defined(LvNolibc)
long __ai_osv;
#endif
