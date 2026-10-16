/* assigning a double to an integer object truncates, at every width -- the
 * separate assignment `v = d` as well as the declaring `long v = d`, side by side. */

static long g_l;
static unsigned long g_ul;
static int g_i;

static long asn_long(double d)       { long v;          v = d; return v; }
static unsigned long asn_ulong(double d) { unsigned long v; v = d; return v; }
static int asn_int(double d)         { int v;           v = d; return v; }
static short asn_short(double d)     { short v;         v = d; return v; }
static char asn_char(double d)       { char v;          v = d; return v; }

static long init_long(double d)      { long v = d;      return v; }   /* the control: always worked */

static long asn_global(double d)     { g_l = d;  return g_l; }        /* the glo lane, not loc */
static unsigned long asn_gul(double d) { g_ul = d; return g_ul; }
static int asn_gint(double d)        { g_i = d;  return g_i; }

static long asn_ptr(double d)        { long v; long *p = &v; *p = d; return v; }  /* computed address */

int main(void)
{
	int r = 0;

	/* a separated assignment, every width */
	r += asn_long(3.75) == 3L;
	r += asn_ulong(3.75) == 3UL;
	r += asn_int(3.75) == 3;
	r += asn_short(3.75) == 3;
	r += asn_char(3.75) == 3;

	/* the declaring form, which always converted -- both must agree */
	r += init_long(3.75) == 3L;
	r += init_long(3.75) == asn_long(3.75);

	/* truncation is toward zero, including negatives */
	r += asn_long(-3.75) == -3L;
	r += asn_int(-3.75) == -3;

	/* a global target takes the other half of the same lane */
	r += asn_global(3.75) == 3L;
	r += asn_gul(3.75) == 3UL;
	r += asn_gint(3.75) == 3;

	/* through a pointer: the computed-address store */
	r += asn_ptr(3.75) == 3L;

	/* larger magnitudes, still exact */
	r += asn_long(1.0e15) == 1000000000000000L;
	r += asn_ulong(1.0e19) == 10000000000000000000UL;   /* and past 2^63, cf 108-d2u.c */

	/* a zero and a value below one both land on 0, not on their bits */
	r += asn_long(0.0) == 0L;
	r += asn_long(0.5) == 0L;
	r += asn_int(0.5) == 0;

	return r;
}
