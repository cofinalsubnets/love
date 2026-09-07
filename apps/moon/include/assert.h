/* freestanding assert.h for cc. no include guard by design: assert.h is meant to
 * be re-includable with NDEBUG toggling the macro. */
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

#ifndef _AI_ASSERT_H
#define _AI_ASSERT_H
/* static_assert is a keyword-level facility; expose the C11 macro spelling. */
#ifndef static_assert
#define static_assert _Static_assert
#endif
#endif
