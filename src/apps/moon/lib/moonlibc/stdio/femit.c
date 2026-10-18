#include "../impl.h"

void __femit(void *ctx, int c) { fputc(c, (FILE *) ctx); }
