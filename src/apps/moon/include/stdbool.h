#ifndef _LOVE_STDBOOL_H
#define _LOVE_STDBOOL_H
/* C23 and mooncc's own dialect have bool/true/false bare (the driver lays them), so this
   is a no-op there; an older iso dialect, or another compiler reading these headers under
   -nostdinc (the KCC=clang kernel lane), takes them here. bool is _Bool: one byte. */
#if !defined(true) && (!defined(__STDC_VERSION__) || __STDC_VERSION__ < 202311L || defined(__mooncc__))
#define bool _Bool
#define true 1
#define false 0
#endif
#define __bool_true_false_are_defined 1
#endif
