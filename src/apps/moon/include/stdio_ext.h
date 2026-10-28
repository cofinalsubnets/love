#pragma once
#include <stdio.h>
/* glibc's and musl's window onto a stream's state */
size_t __fbufsize(FILE *);
size_t __fpending(FILE *);
size_t __freadahead(FILE *);
int __freading(FILE *);
int __fwriting(FILE *);
int __freadable(FILE *);
int __fwritable(FILE *);
int __flbf(FILE *);
void __fpurge(FILE *);
void __fseterr(FILE *);
