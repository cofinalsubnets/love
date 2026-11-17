#include "../impl.h"

/* unlinked at once, so it lives as long as the FILE */
FILE *tmpfile(void) {
  char buf[16];
  strcpy(buf, "/tmp/aiXXXXXX");
  mktemp(buf);
  if (!buf[0]) return 0;
  FILE *f = fopen(buf, "w+");
  if (f) unlink(buf);
  return f; }
char *tmpnam(char *s) {                         
  static char b[20];
  if (!s) s = b;
  strcpy(s, "/tmp/aiXXXXXX");
  mktemp(s);
  return s[0] ? s : 0; }
/* racy by design: the caller opens the name */
char *mktemp(char *tmpl) {
  size_t n = strlen(tmpl);
  if (n < 6 || strcmp(tmpl + n - 6, "XXXXXX")) { tmpl[0] = 0; return tmpl; }
  char *x = tmpl + n - 6;
  unsigned long v = (unsigned long) getpid();
  for (int k = 0; k < 100; k++, v += 7777) {
    unsigned long w = v;
    for (int i = 0; i < 6; i++) { x[i] = 'a' + w % 26; w /= 26; }
    if (access(tmpl, 0) < 0) return tmpl; }
  tmpl[0] = 0;
  return tmpl; }
