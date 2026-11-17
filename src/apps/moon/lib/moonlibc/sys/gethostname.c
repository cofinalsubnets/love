#include "../impl.h"
#include <sys/utsname.h>

/* uname's nodename, which every kernel fills; a short buffer is ENAMETOOLONG */
int gethostname(char *b, unsigned long n) {
  struct utsname u;
  if (uname(&u)) return -1;
  unsigned long k = strlen(u.nodename) + 1;
  if (k > n) { errno = ENAMETOOLONG; return -1; }
  memcpy(b, u.nodename, k);
  return 0; }
