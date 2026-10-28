#pragma once
#include <stddef.h>

typedef int regoff_t;
typedef struct { size_t re_nsub; void *re_prog; size_t re_size; } regex_t;   /* re_prog: re_size bytes holding no pointer */
typedef struct { regoff_t rm_so, rm_eo; } regmatch_t;

#define REG_EXTENDED 1
#define REG_ICASE    2
#define REG_NEWLINE  4
#define REG_NOSUB    8
#define REG_GREP     16  /* gnu grep's reading: a repeat with nothing to repeat is skipped, a bad brace is literal */
#define REG_UTF8     32  /* by character, whatever the locale */

#define REG_NOTBOL   1
#define REG_NOTEOL   2
#define REG_STARTEND 4

enum { REG_NOERROR, REG_NOMATCH, REG_BADPAT, REG_ECOLLATE, REG_ECTYPE, REG_EESCAPE, REG_ESUBREG,
       REG_EBRACK, REG_EPAREN, REG_EBRACE, REG_BADBR, REG_ERANGE, REG_ESPACE, REG_BADRPT, REG_EEND,
       REG_ESIZE, REG_ERPAREN };

int regcomp(regex_t *, char const *, int);
int regexec(regex_t const *, char const *, size_t, regmatch_t *, int);
size_t regerror(int, regex_t const *, char *, size_t);
void regfree(regex_t *);
