#include "../impl.h"

/* ---- fseeko, ftello: fseek and ftell, whose long is an off_t's width here ---- */
int fseeko(FILE *f, off_t o, int w) { return fseek(f, (long) o, w); }
off_t ftello(FILE *f) { return (off_t) ftell(f); }
