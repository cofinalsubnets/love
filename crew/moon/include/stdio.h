#ifndef _AI_STDIO_H
#define _AI_STDIO_H
/* glibc provides NULL from stdio/stdlib/string too (not just stddef) -- third-party
   C (the LFS ladder) leans on that; guarded so a prior stddef include is fine. */
#ifndef NULL
#define NULL ((void*)0)
#endif
typedef unsigned long size_t;
typedef struct _IO_FILE FILE;   /* opaque; glibc owns the layout */
extern FILE *stdin, *stdout, *stderr;
#define EOF (-1)
#define SEEK_SET 0
#define SEEK_CUR 1
#define SEEK_END 2
int    printf(char const*, ...);
int    fprintf(FILE*, char const*, ...);
int    snprintf(char*, size_t, char const*, ...);
int    sprintf(char*, char const*, ...);
int    puts(char const*);
int    fputs(char const*, FILE*);
int    putchar(int);
int    fputc(int, FILE*);
int    fgetc(FILE*);
int    ungetc(int, FILE*);
int    getc(FILE*);
int    getchar(void);
FILE  *fopen(char const*, char const*);
int    fclose(FILE*);
size_t fread(void*, size_t, size_t, FILE*);
size_t fwrite(void const*, size_t, size_t, FILE*);
int    fseek(FILE*, long, int);
long   ftell(FILE*);
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
#endif
