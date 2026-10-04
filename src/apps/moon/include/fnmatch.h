#ifndef _LOVE_FNMATCH_H
#define _LOVE_FNMATCH_H
/* shell patterns against a name: * ? [..] with ranges, ! or ^ negation and [:class:]es, \ escapes */
#define FNM_PATHNAME    1    /* a / matches only a / */
#define FNM_NOESCAPE    2    /* \ is an ordinary character */
#define FNM_PERIOD      4    /* a leading . (after a / too, under PATHNAME) matches only a . */
#define FNM_LEADING_DIR 8    /* the pattern may stop at a / of the name */
#define FNM_CASEFOLD    16
#define FNM_FILE_NAME   FNM_PATHNAME
#define FNM_NOMATCH     1
int fnmatch(char const *, char const *, int);
#endif
