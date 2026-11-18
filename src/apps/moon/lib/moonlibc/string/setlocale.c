#include "../impl.h"

/* every category is C, but LC_CTYPE may be utf-8 (a name ending .UTF-8 or .utf8).
 * "" reads LC_ALL, then the category's variable, then LANG. categories that differ answer
 * LC_ALL as glibc does, CAT=name;CAT=name.., and that form is read back */
static int lc_utf8(char const *n) {
  char const *d = strrchr(n, '.');
  return d && (!strcasecmp(d + 1, "UTF-8") || !strcasecmp(d + 1, "utf8")); }
static int lc_ok(char const *n, size_t len) {
  char b[32];
  if (len >= sizeof b) return 0;
  memcpy(b, n, len), b[len] = 0;
  return !strcmp(b, "C") || !strcmp(b, "POSIX") || lc_utf8(b); }
char *setlocale(int cat, char const *loc) {
  static char names[LC_ALL][32] = {"C", "C", "C", "C", "C", "C"};
  static char all[LC_ALL * (sizeof "LC_MONETARY=;" + 32)];
  static char const *const env[LC_ALL] = {"LC_CTYPE", "LC_NUMERIC", "LC_TIME", "LC_COLLATE",
                                          "LC_MONETARY", "LC_MESSAGES"};
  if (cat < 0 || cat > LC_ALL) return 0;
  int lo = cat == LC_ALL ? 0 : cat, hi = cat == LC_ALL ? LC_ALL : cat + 1;
  if (loc) {
    char const *want[LC_ALL];
    size_t wlen[LC_ALL];
    if (cat == LC_ALL && strchr(loc, '=')) {
      /* the composite: every pair checked before any is taken; one unnamed stays */
      for (int k = 0; k < LC_ALL; k++) want[k] = names[k], wlen[k] = strlen(names[k]);
      for (char const *p = loc; *p; ) {
        char const *eq = strchr(p, '='), *end = strchr(p, ';');
        if (!end) end = p + strlen(p);
        if (!eq || eq > end) return 0;
        int k = 0;
        while (k < LC_ALL && !((size_t) (eq - p) == strlen(env[k]) && !memcmp(p, env[k], eq - p))) k++;
        if (k == LC_ALL || !lc_ok(eq + 1, end - eq - 1)) return 0;
        want[k] = eq + 1, wlen[k] = end - eq - 1;
        p = *end ? end + 1 : end; } }
    else
      for (int k = lo; k < hi; k++) {
        char const *n = loc;
        if (!*n && !((n = getenv("LC_ALL")) && *n) && !((n = getenv(env[k])) && *n) && !((n = getenv("LANG")) && *n)) n = "C";
        if (!lc_ok(n, strlen(n))) return 0;
        want[k] = n, wlen[k] = strlen(n); }
    char got[LC_ALL][32];
    for (int k = lo; k < hi; k++) memcpy(got[k], want[k], wlen[k]), got[k][wlen[k]] = 0;
    for (int k = lo; k < hi; k++) strcpy(names[k], got[k]);
    __love_utf8 = lc_utf8(names[LC_CTYPE]); }
  if (cat != LC_ALL) return names[cat];
  int same = 1;
  for (int k = 1; k < LC_ALL; k++) same = same && !strcmp(names[k], names[0]);
  if (same) return names[0];
  char *q = all;
  for (int k = 0; k < LC_ALL; k++) {
    size_t e = strlen(env[k]), n = strlen(names[k]);
    if (k) *q++ = ';';
    memcpy(q, env[k], e), q += e, *q++ = '=';
    memcpy(q, names[k], n), q += n; }
  *q = 0;
  return all; }
struct lconv *localeconv(void) {                
  static struct lconv c = { (char *) ".", (char *) "", (char *) "",
    (char *) "", (char *) "", (char *) "", (char *) "", (char *) "",
    (char *) "", (char *) "", 127, 127, 127, 127, 127, 127, 127, 127 };
  return &c; }
