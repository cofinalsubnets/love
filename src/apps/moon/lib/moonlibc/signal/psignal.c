#include "../impl.h"

/* "msg: text", or the text alone, to stderr */
void psignal(int s, char const *msg) {
  if (msg && *msg) fprintf(stderr, "%s: %s\n", msg, strsignal(s));
  else fprintf(stderr, "%s\n", strsignal(s)); }
