#include "../impl.h"

unsigned short htons(unsigned short v) { return (unsigned short) ((v << 8) | (v >> 8)); }
