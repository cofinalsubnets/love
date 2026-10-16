/* no include guard: re-included, it follows NDEBUG anew */
#include <stdio.h>
#include <stdlib.h>

#undef assert
#ifdef NDEBUG
#define assert(e) ((void)0)
#else
#define assert(e) \
	((e) ? (void)0 \
	     : (fprintf(stderr, "%s:%d: assertion failed: %s\n", \
	                __FILE__, __LINE__, #e), abort()))
#endif

#ifndef _LOVE_ASSERT_H
#define _LOVE_ASSERT_H
#ifndef static_assert
#define static_assert _Static_assert
#endif
#endif
