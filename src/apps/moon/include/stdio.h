#pragma once
/* NULL here too, as glibc does */
#ifndef NULL
#define NULL ((void*)0)
#endif
typedef unsigned long size_t;
typedef struct _IO_FILE FILE;   /* opaque */
extern FILE *stdin, *stdout, *stderr;
#define EOF (-1)
#define BUFSIZ 8192
#define FOPEN_MAX 16
#define FILENAME_MAX 4096
#define SEEK_SET 0
#define SEEK_CUR 1
#define SEEK_END 2
#define _IOFBF 0
#define _IOLBF 1
#define _IONBF 2
#define L_tmpnam 20
#define TMP_MAX 238328
char  *tmpnam(char*), *tmpnam_r(char*);
int printf(char const*, ...), fprintf(FILE*, char const*, ...),
    snprintf(char*, size_t, char const*, ...), sprintf(char*, char const*, ...), puts(char const*),
    fputs(char const*, FILE*), putchar(int), fputc(int, FILE*), putc(int, FILE*), fgetc(FILE*),
    ungetc(int, FILE*), getc(FILE*), getchar(void);
char  *fgets(char*, int, FILE*);
long   getline(char**, size_t*, FILE*);           /* ssize_t */
long   getdelim(char**, size_t*, int, FILE*);
/* no gets: c11 removed it */
FILE *fopen(char const*, char const*), *freopen(char const*, char const*, FILE*);
int    fclose(FILE*);
size_t fread(void*, size_t, size_t, FILE*), fwrite(void const*, size_t, size_t, FILE*);
int    fseek(FILE*, long, int);
long   ftell(FILE*);
#include <sys/types.h>
typedef struct { off_t pos; } fpos_t;
int fgetpos(FILE*, fpos_t*), fsetpos(FILE*, fpos_t const*), fpurge(FILE*);
#include <sys/types.h>
int    fseeko(FILE*, off_t, int);
off_t  ftello(FILE*);
void   rewind(FILE*);
int    fflush(FILE*);
void   perror(char const*);
int rename(char const*, char const*), remove(char const*), fileno(FILE*), ferror(FILE*),
    feof(FILE*), renameat(int, char const*, int, char const*);
void   clearerr(FILE*);
FILE *fdopen(int, char const*), *open_memstream(char **, size_t *), *tmpfile(void);
void   setbuf(FILE*, char*);
int setvbuf(FILE*, char*, int, size_t), scanf(char const*, ...), fscanf(FILE*, char const*, ...),
    sscanf(char const*, char const*, ...);
FILE  *popen(char const*, char const*);
int    pclose(FILE*);
/* old sources call these with only stdio.h, and mooncc refuses implicit decls */
void exit(int), abort(void);
size_t strlen(char const*);
int strcmp(char const*, char const*), strncmp(char const*, char const*, size_t);
#include <stdarg.h>
int vprintf(char const*, va_list), vfprintf(FILE*, char const*, va_list),
    vsprintf(char*, char const*, va_list), vsnprintf(char*, size_t, char const*, va_list),
    dprintf(int, char const*, ...), vdprintf(int, char const*, va_list),
    vscanf(char const*, va_list), vfscanf(FILE*, char const*, va_list),
    vsscanf(char const*, char const*, va_list);
/* gnu: allocate the answer */
int asprintf(char**, char const*, ...), vasprintf(char**, char const*, va_list);
