#include "../impl.h"
#include <setjmp.h>

void longjmp(jmp_buf b, int v) { siglongjmp(b, v); }
void _longjmp(jmp_buf b, int v) { siglongjmp(b, v); }
