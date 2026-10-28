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
char  *tmpnam(char*);
int    printf(char const*, ...);
int    fprintf(FILE*, char const*, ...);
int    snprintf(char*, size_t, char const*, ...);
int    sprintf(char*, char const*, ...);
int    puts(char const*);
int    fputs(char const*, FILE*);
int    putchar(int);
int    fputc(int, FILE*);
int    putc(int, FILE*);
int    fgetc(FILE*);
int    ungetc(int, FILE*);
int    getc(FILE*);
int    getchar(void);
char  *fgets(char*, int, FILE*);
long   getline(char**, size_t*, FILE*);           /* ssize_t */
long   getdelim(char**, size_t*, int, FILE*);
/* no gets: c11 removed it */
FILE  *fopen(char const*, char const*);
FILE  *freopen(char const*, char const*, FILE*);
int    fclose(FILE*);
size_t fread(void*, size_t, size_t, FILE*);
size_t fwrite(void const*, size_t, size_t, FILE*);
int    fseek(FILE*, long, int);
long   ftell(FILE*);
#include <sys/types.h>
typedef struct { off_t pos; } fpos_t;
int    fgetpos(FILE*, fpos_t*);
int    fsetpos(FILE*, fpos_t const*);
int    fpurge(FILE*);
#include <sys/types.h>
int    fseeko(FILE*, off_t, int);
off_t  ftello(FILE*);
void   rewind(FILE*);
int    fflush(FILE*);
void   perror(char const*);
int    rename(char const*, char const*);
int    remove(char const*);
int    fileno(FILE*);
int    ferror(FILE*);
int    feof(FILE*);
void   clearerr(FILE*);
FILE  *fdopen(int, char const*);
FILE  *open_memstream(char **, size_t *);
FILE  *tmpfile(void);
void   setbuf(FILE*, char*);
int    setvbuf(FILE*, char*, int, size_t);
int    scanf(char const*, ...);
int    fscanf(FILE*, char const*, ...);
int    sscanf(char const*, char const*, ...);
FILE  *popen(char const*, char const*);
int    pclose(FILE*);
/* old sources call these with only stdio.h, and mooncc refuses implicit decls */
void   exit(int);
void   abort(void);
size_t strlen(char const*);
int    strcmp(char const*, char const*);
int    strncmp(char const*, char const*, size_t);
#include <stdarg.h>
int    vprintf(char const*, va_list);
int    vfprintf(FILE*, char const*, va_list);
int    vsprintf(char*, char const*, va_list);
int    vsnprintf(char*, size_t, char const*, va_list);
int    dprintf(int, char const*, ...);
int    vdprintf(int, char const*, va_list);
int    vscanf(char const*, va_list);
int    vfscanf(FILE*, char const*, va_list);
int    vsscanf(char const*, char const*, va_list);
/* gnu: allocate the answer */
int    asprintf(char**, char const*, ...);
int    vasprintf(char**, char const*, va_list);
