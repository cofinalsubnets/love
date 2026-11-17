#include "../impl.h"

/* O_EXCL is the test; 384 = 0600 */
int mkstemp(char *tmpl) {
  size_t n = strlen(tmpl);
  if (n < 6 || strcmp(tmpl + n - 6, "XXXXXX")) { errno = EINVAL; return -1; }
  char *x = tmpl + n - 6;
  unsigned long v = (unsigned long) getpid() * 2654435761u;
  for (int k = 0; k < 1000; k++, v += 7777) {
    unsigned long w = v;
    for (int i = 0; i < 6; i++) { x[i] = 'a' + w % 26; w /= 26; }
    int fd = open(tmpl, O_RDWR | O_CREAT | O_EXCL, 384);
    if (fd >= 0 || errno != EEXIST) return fd; }
  return -1; }
/* mkstemp's walk, a directory made (448 = 0700) in place of a file opened */
char *mkdtemp(char *tmpl) {
  size_t n = strlen(tmpl);
  if (n < 6 || strcmp(tmpl + n - 6, "XXXXXX")) { errno = EINVAL; return 0; }
  char *x = tmpl + n - 6;
  unsigned long v = (unsigned long) getpid() * 2654435761u;
  for (int k = 0; k < 1000; k++, v += 7777) {
    unsigned long w = v;
    for (int i = 0; i < 6; i++) { x[i] = 'a' + w % 26; w /= 26; }
    if (mkdir(tmpl, 448) == 0) return tmpl;
    if (errno != EEXIST) return 0; }
  return 0; }
