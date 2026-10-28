#pragma once
#include <stddef.h>
/* glibc's flag and error numbers */
#define GLOB_ERR      1      /* stop at an unreadable directory */
#define GLOB_MARK     2      /* a / after each directory */
#define GLOB_NOSORT   4
#define GLOB_DOOFFS   8      /* gl_offs nulls ahead of the paths */
#define GLOB_NOCHECK  16     /* no match answers the pattern itself */
#define GLOB_APPEND   32
#define GLOB_NOESCAPE 64
#define GLOB_PERIOD   128    /* a leading . matches a wildcard too */
#define GLOB_NOSPACE  1
#define GLOB_ABORTED  2
#define GLOB_NOMATCH  3
#define GLOB_NOSYS    4
typedef struct {
  size_t gl_pathc;
  char **gl_pathv;
  size_t gl_offs;
  int gl_flags;
} glob_t;
int glob(char const *, int, int (*)(char const *, int), glob_t *);
void globfree(glob_t *);
