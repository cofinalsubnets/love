#include "../impl.h"
#include <stdio_ext.h>

/* ---- stdio_ext: a stream's state, as glibc and musl answer it ---- */
size_t __fbufsize(FILE *f) { return (size_t) (f->wr ? f->cap : f->rcap); }
size_t __fpending(FILE *f) { return f->wr ? (size_t) f->len : 0; }
size_t __freadahead(FILE *f) { return (size_t) __rahead(f); }
int __freading(FILE *f) { return !f->wr; }
int __fwriting(FILE *f) { return f->wr; }
int __freadable(FILE *f) { return !f->wr; }
int __fwritable(FILE *f) { return f->wr; }
int __flbf(FILE *f) { return f->line; }
void __fpurge(FILE *f) { f->un = 0; f->rp = f->rl = 0; if (f->wr) f->len = 0; }
void __fseterr(FILE *f) { f->err = 1; }
int fpurge(FILE *f) { __fpurge(f); return 0; }
