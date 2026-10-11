#include "../impl.h"

ssize_t copy_file_range(int in, off_t *inoff, int out, off_t *outoff, unsigned long n, unsigned int fl) {
  return er(__love_call(NR_copy_file_range, in, (long) inoff, out, (long) outoff, (long) n, fl)); }
