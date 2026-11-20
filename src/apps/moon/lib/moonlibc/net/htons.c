#include "../impl.h"

#if __BYTE_ORDER__ == __ORDER_BIG_ENDIAN__
unsigned short htons(unsigned short v) { return v; }      /* network order is the host's */
#else
unsigned short htons(unsigned short v) { return (unsigned short) ((v << 8) | (v >> 8)); }
#endif
