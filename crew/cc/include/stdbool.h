#ifndef _AI_STDBOOL_H
#define _AI_STDBOOL_H
/* cc has no _Bool; bool is a plain int, true/false the C99 constants. */
typedef int bool;
#define bool  bool
#define true  1
#define false 0
#define __bool_true_false_are_defined 1
#endif
