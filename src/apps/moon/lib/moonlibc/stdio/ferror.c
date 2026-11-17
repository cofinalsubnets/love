#include "../impl.h"

int ferror(FILE *f) { return f->err; }
int feof(FILE *f) { return f->eof; }
void clearerr(FILE *f) { f->err = 0; f->eof = 0; }
