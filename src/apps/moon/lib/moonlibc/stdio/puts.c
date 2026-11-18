#include "../impl.h"

int fputs(char const *s, FILE *f) { size_t n = strlen(s); return fwrite(s, 1, n, f) == n ? 0 : EOF; }
int putchar(int c) { return fputc(c, stdout); }
int puts(char const *s) { return fputs(s, stdout) == EOF || fputc('\n', stdout) == EOF ? EOF : 0; }
