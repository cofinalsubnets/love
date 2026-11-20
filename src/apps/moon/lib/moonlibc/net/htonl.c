#include "../impl.h"

#if __BYTE_ORDER__ == __ORDER_BIG_ENDIAN__
unsigned int htonl(unsigned int v) { return v; }          /* network order is the host's */
#else
unsigned int htonl(unsigned int v) {
  return (v << 24) | ((v & 65280U) << 8) | ((v >> 8) & 65280U) | (v >> 24); }
#endif
