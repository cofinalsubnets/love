#include "../impl.h"

/* the next field of *sp up to any byte of sep, which becomes a NUL; an empty field is a field */
char *strsep(char **sp, char const *sep) {
  char *s = *sp;
  if (!s) return 0;
  char *e = s + strcspn(s, sep);
  if (*e) { *e = 0; *sp = e + 1; } else *sp = 0;
  return s; }
