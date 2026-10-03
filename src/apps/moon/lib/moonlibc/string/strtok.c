#include "../impl.h"

/* the reentrant core carries its place in *nxt; strtok is it over one static place */
char *strtok_r(char *s, char const *sep, char **nxt) {
  if (!s) s = *nxt;
  if (!s) return 0;
  s += strspn(s, sep);
  if (!*s) { *nxt = 0; return 0; }
  char *e = s + strcspn(s, sep);
  if (*e) { *e = 0; *nxt = e + 1; } else *nxt = 0;
  return s; }

char *strtok(char *s, char const *sep) {
  static char *nxt;
  return strtok_r(s, sep, &nxt); }
