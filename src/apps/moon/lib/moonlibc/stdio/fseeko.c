#include "../impl.h"

/* ---- fseek, ftell: fseeko and ftello at a long's width (fflush.c keeps the off_t pair) ---- */
int fseek(FILE *f, long o, int w) { return fseeko(f, o, w); }
long ftell(FILE *f) { return (long) ftello(f); }
