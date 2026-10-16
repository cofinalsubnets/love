/* the float lanes of the formatter: %f %e %g %a and their upper-case twins, with the
 * precisions, flags and edges. two subjects: a case from a literal tests the compiler's
 * decimal->binary and the printer, a case from a bit pattern the printer alone.
 * every answer is exact: a double has a finite decimal form and ties round to even. */
#include <stdio.h>
#include <string.h>
#include "say.h"

static char b[1400];

/* float images laid into .data by the compiler's own single-precision encoder */
static float const f_tenth = 0.1f, f_third = 0.3f, f_tiny = 1e-40f;
static float const f_max = 3.4028234663852886e38f, f_sub = 1.4e-45f, f_one = 1.0f;

/* the format's text names the case */
#define F(fmt, v) do { snprintf(b, sizeof b, fmt, v); say_s(fmt, b); } while (0)

/* the same, off a bit pattern -- no literal, no strtod, nothing but the printer */
static double bits(unsigned long u) { double d; memcpy(&d, &u, sizeof d); return d; }
#define B(nm, fmt, u) do { snprintf(b, sizeof b, fmt, bits(u)); say_s(nm, b); } while (0)

int main(void)
{
	/* --- %f, %e, %g at the default precision --- */
	F("%f", 3.14159265358979); F("%e", 3.14159265358979); F("%g", 3.14159265358979);
	F("%f", 0.0); F("%e", 0.0); F("%g", 0.0);
	F("%f", 1.0); F("%e", 100.0); F("%g", 100000.0); F("%g", 1000000.0);
	F("%g", 1e-4); F("%g", 1e-5); F("%g", 0.5); F("%g", 123456789.0);
	F("%F", 1.5); F("%E", 1.5); F("%G", 1e-9);

	/* --- negative zero. -0.0 is not less than zero, so a sign taken by
	   comparison loses it; the sign bit is the only place it lives. --- */
	F("%g", -0.0); F("%f", -0.0); F("%e", -0.0); F("%.14g", -0.0); F("%a", -0.0);
	F("%f", -1e-30);                       /* genuinely negative, rounds to zero */

	/* --- the long precisions, where an approximate converter shows --- */
	F("%.17g", 1.0 / 3.0); F("%.17g", 0.1); F("%.17g", 3.141592653589793);
	F("%.17g", 1e300); F("%.17g", 1e-300); F("%.17e", 1.0 / 3.0);
	F("%.20f", 0.1); F("%.30g", 0.1); F("%.40f", 1.0 / 3.0);
	F("%.15g", 1.0 / 3.0); F("%.14g", 1.0 / 3.0);

	/* --- %f of a value past 2^64: every digit of it --- */
	F("%.0f", 1e300);
	F("%.0f", 18446744073709551616.0);
	F("%f", 1e20);

	/* --- ties. the value is exact, so half rounds to even. --- */
	F("%.0f", 0.5); F("%.0f", 1.5); F("%.0f", 2.5); F("%.0f", 3.5);
	F("%.0f", -0.5); F("%.0f", -2.5); F("%.0f", 9.5);
	F("%.1f", 0.25); F("%.1f", 0.75); F("%.1f", 0.125);
	F("%.2g", 0.125); F("%.1e", 0.25);

	/* --- rounding that carries into a new leading digit, which %g must see
	   before it picks between the e and f styles --- */
	F("%.4g", 999999.0); F("%.2e", 9.999); F("%.3g", 0.0009999);
	F("%.0g", 123.0); F("%.1g", 0.0);

	/* --- the flags: width, zero, left, plus, space, alt --- */
	F("%10.2f", -3.5); F("%010.2f", -3.5); F("%-10.2f|", -3.5); F("%10.2f", 3.5);
	F("%+g", 0.0); F("%+g", -0.0); F("%+.2f", 3.5); F("% .2f", 3.5); F("% .2f", -3.5);
	F("%#.0f", 1.0); F("%#g", 1.0); F("%#.3g", 1.0); F("%#e", 1.0);

	/* --- infinity and not-a-number: the zero flag does not reach them --- */
	F("%f", 1.0 / 0.0); F("%f", -1.0 / 0.0); F("%F", -1.0 / 0.0);
	F("%5.1f", 1.0 / 0.0); F("%08.1f", -1.0 / 0.0); F("%-8.1f|", 1.0 / 0.0);
	F("%+f", 1.0 / 0.0); F("%e", 1.0 / 0.0); F("%g", 1.0 / 0.0); F("%a", 1.0 / 0.0);

	/* --- %a: the bits themselves. a subnormal keeps the -1022 exponent and
	   shows a leading 0 rather than renormalising, and so does a mantissa that
	   rounds up past f -- 0.999999 at %.1a is 0x2.0p-1, not 0x1.0p+0. --- */
	F("%a", 1.0); F("%a", 0.5); F("%a", 0.0); F("%a", 2.0); F("%a", 1.5); F("%a", -1.0);
	F("%a", 3.14159); F("%A", 255.5); F("%a", 1e-300); F("%a", 1e300);
	F("%.0a", 3.14159); F("%.1a", 3.14159); F("%.3a", 3.14159); F("%.20a", 1.0);
	F("%.13a", 1.0); F("%.14a", 1.0); F("%.2a", 1.0); F("%.0a", 1.0);
	F("%.1a", 0.999999); F("%.0a", 1.9999999);
	F("%12a", 1.0); F("%-12a|", 1.0); F("%012a", 1.0); F("%012a", -1.0);
	F("%#a", 1.0); F("%5a", 1.0); F("%+a", 1.0);

	/* --- the bit patterns: the printer with no compiler in the way. one conversion per
	   call: the sink takes one double, a second would read an argument never passed --- */
	B("bit.zero.g",    "%g", 0x0000000000000000UL);
	B("bit.zero.f",    "%f", 0x0000000000000000UL);
	B("bit.zero.e",    "%e", 0x0000000000000000UL);
	B("bit.zero.a",    "%a", 0x0000000000000000UL);
	B("bit.negzero.g", "%g", 0x8000000000000000UL);
	B("bit.negzero.f", "%f", 0x8000000000000000UL);
	B("bit.negzero.e", "%e", 0x8000000000000000UL);
	B("bit.negzero.a", "%a", 0x8000000000000000UL);
	B("bit.one.g",     "%g", 0x3ff0000000000000UL);
	B("bit.one.a",     "%a", 0x3ff0000000000000UL);
	B("bit.min.sub.g", "%g",    0x0000000000000001UL);   /* 4.94e-324 */
	B("bit.min.sub.G", "%.17g", 0x0000000000000001UL);
	B("bit.min.sub.a", "%a",    0x0000000000000001UL);
	B("bit.sub2.g",    "%g",    0x0008000000000000UL);   /* half the min normal */
	B("bit.sub2.G",    "%.17g", 0x0008000000000000UL);
	B("bit.sub2.a",    "%a",    0x0008000000000000UL);
	B("bit.min.nrm.g", "%g",    0x0010000000000000UL);
	B("bit.min.nrm.G", "%.17g", 0x0010000000000000UL);
	B("bit.min.nrm.a", "%a",    0x0010000000000000UL);
	B("bit.max.g",     "%g",    0x7fefffffffffffffUL);
	B("bit.max.G",     "%.17g", 0x7fefffffffffffffUL);
	B("bit.max.a",     "%a",    0x7fefffffffffffffUL);
	B("bit.1e-310.g",  "%g",    0x000012688b70e62bUL);
	B("bit.1e-310.G",  "%.17g", 0x000012688b70e62bUL);
	B("bit.1e-310.a",  "%a",    0x000012688b70e62bUL);
	B("bit.pi.G",      "%.17g", 0x400921fb54442d18UL);
	B("bit.pi.a",      "%a",    0x400921fb54442d18UL);
	B("bit.inf.g",     "%g",    0x7ff0000000000000UL);
	B("bit.inf.a",     "%a",    0x7ff0000000000000UL);
	B("bit.neginf.g",  "%g",    0xfff0000000000000UL);
	B("bit.neginf.f",  "%f",    0xfff0000000000000UL);
	B("bit.qnan.g",    "%g",    0x7ff8000000000000UL);
	B("bit.qnan.F",    "%F",    0x7ff8000000000000UL);
	B("bit.negnan.g",  "%g",    0xfff8000000000000UL);
	/* the min subnormal to its last digit: all 1074 after the point */
	B("bit.min.sub.full", "%.1074f", 0x0000000000000001UL);
	B("bit.min.sub.400",  "%.400f",  0x0000000000000001UL);
	B("bit.min.sub.0",    "%.0f",    0x0000000000000001UL);

	/* --- the literals that reach those same bits: the compiler's half --- */
	F("%a", 4.9406564584124654e-324);
	F("%a", 2.2250738585072014e-308);
	F("%a", 1.1125369292536007e-308);
	F("%.17g", 1e-310); F("%.17g", 1e-308); F("%.17g", 1e-307);
	F("%.17g", 1.7976931348623157e308);
	F("%.17g", 2.2250738585072011e-308);   /* the strtod-killer, one ulp under */
	F("%.17g", 9007199254740993.0);        /* 2^53 + 1: ties to even, so ...92 */
	F("%.17g", 1.2345678901234567e-8);
	F("%a", 0x1p-1074); F("%a", 0x1.fffffffffffffp+1023); F("%a", 0x1p-1022);

	/* --- the float images, rounded to 24 bits at compile time, read through statics:
	   a bare `(double) 0.1f` keeps 53 bits under mooncc (the f suffix gives no float
	   type), while a float variable narrows on the store --- */
	F("%.9g", (double) f_tenth); F("%.9g", (double) f_third);
	F("%.9g", (double) f_tiny);  F("%.9g", (double) f_max);
	F("%.9g", (double) f_sub);   F("%.9g", (double) f_one);
	F("%a", (double) f_one);     F("%a", (double) f_tenth);

	return 0;
}
