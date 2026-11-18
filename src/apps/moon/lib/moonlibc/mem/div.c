#include "../impl.h"

/* the quotient truncates toward zero, as / does */
div_t div(int n, int d) { div_t r = { n / d, n % d }; return r; }
ldiv_t ldiv(long n, long d) { ldiv_t r = { n / d, n % d }; return r; }
lldiv_t lldiv(long long n, long long d) { lldiv_t r = { n / d, n % d }; return r; }
