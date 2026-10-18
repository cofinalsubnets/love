#ifndef _LOVE_STDBOOL_H
#define _LOVE_STDBOOL_H
/* c23 and mooncc's dialect have these bare; an older dialect or another compiler takes them here */
#if !defined(true) && (!defined(__STDC_VERSION__) || __STDC_VERSION__ < 202311L || defined(__mooncc__))
#define bool _Bool
#define true 1
#define false 0
#endif
#define __bool_true_false_are_defined 1
#endif
