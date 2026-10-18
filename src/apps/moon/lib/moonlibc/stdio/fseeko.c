#include "../impl.h"

int fseek(FILE *f, long o, int w) { return fseeko(f, o, w); }
long ftell(FILE *f) { return (long) ftello(f); }
