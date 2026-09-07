#ifndef _AI_INTTYPES_H
#define _AI_INTTYPES_H
/* freestanding inttypes for cc: the fixed-width types come from stdint, plus the
 * PRI format macros and the strtoimax/strtoumax conversions programs call. */
#include <stdint.h>

/* 64-bit host: all wide formats route through the l-length modifier. */
#define PRId8   "d"
#define PRId16  "d"
#define PRId32  "d"
#define PRId64  "ld"
#define PRIi64  "li"
#define PRIu8   "u"
#define PRIu16  "u"
#define PRIu32  "u"
#define PRIu64  "lu"
#define PRIo64  "lo"
#define PRIx64  "lx"
#define PRIX64  "lX"
#define PRIdMAX "ld"
#define PRIiMAX "li"
#define PRIuMAX "lu"
#define PRIoMAX "lo"
#define PRIxMAX "lx"
#define PRIXMAX "lX"
#define PRIdPTR "ld"
#define PRIuPTR "lu"
#define PRIxPTR "lx"

typedef struct { intmax_t quot; intmax_t rem; } imaxdiv_t;

intmax_t  strtoimax(const char *, char **, int);
uintmax_t strtoumax(const char *, char **, int);
intmax_t  imaxabs(intmax_t);
imaxdiv_t imaxdiv(intmax_t, intmax_t);
#endif
