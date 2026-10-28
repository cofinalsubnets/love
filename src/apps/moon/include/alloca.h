#pragma once
#include <stddef.h>
/* on the caller's stack, held until it returns */
#define alloca(n) __builtin_alloca(n)
