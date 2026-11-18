#pragma once
#include <stdio.h>
/* glibc's and musl's window onto a stream's state */
size_t __fbufsize(FILE *), __fpending(FILE *), __freadahead(FILE *);
int __freading(FILE *), __fwriting(FILE *), __freadable(FILE *), __fwritable(FILE *),
    __flbf(FILE *);
void __fpurge(FILE *), __fseterr(FILE *);
