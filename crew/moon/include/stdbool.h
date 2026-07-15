#ifndef _AI_STDBOOL_H
#define _AI_STDBOOL_H
/* bool/true/false are BUILTIN (predefined in cpp.l, C23-style) -- this header is
   a no-op kept so an explicit #include <stdbool.h> is harmless. bool is cc's int. */
#define __bool_true_false_are_defined 1
#endif
