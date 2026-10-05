/* the multiple-include rule: a header wholly inside #ifndef G .. #endif reads as nothing
 * while G is defined, and only then -- an #else at its top, a line past its #endif or an
 * #undef of G each make the next #include read it again. */
#include "226-guard.h"
#include "226-guard.h"
#include "226-guard-else.h"
#include "226-guard-else.h"
#define K226 3
#include "226-guard-tail.h"
#undef K226
#define K226 3
#include "226-guard-tail.h"
#undef U226
#undef G226
#include "226-guard.h"

int main(void)
{
    if (ELSE226 != 2) return 1;
    if (K226 != 7) return 2;
    if (U226 != 5) return 3;
    return IN226 - 1;
}
