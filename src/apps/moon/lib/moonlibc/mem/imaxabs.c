#include "../impl.h"
#include <inttypes.h>

intmax_t imaxabs(intmax_t v) { return v < 0 ? -v : v; }
imaxdiv_t imaxdiv(intmax_t n, intmax_t d) { imaxdiv_t r = { n / d, n % d }; return r; }
