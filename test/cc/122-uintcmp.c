/* compare and divide take the common converted type (C11 6.3.1.8): uint vs long
 * is signed, int vs uint is uint at 32 bits; unsuffixed hex climbs the unsigned
 * rungs; a case label converts to the control's type. each check adds 1: the exit code is the pass count. */

unsigned gu = 5u;                 /* globals, so nothing folds at parse */
long gl = -6;
int gx = -1;
unsigned long gul = 0xffffffffffffffff;

static unsigned big(void) { return 0xffffffffu; }

int main(void)
{
	unsigned u = gu;
	long l = gl;
	int x = gx;
	unsigned v = big();
	int r = 0;

	r += l < u;                       /* uint fits in long: signed, -6 < 5 */
	r += u > l;
	r += l / u == -1;                 /* the divide takes the same law */
	r += l % u == -1;
	r += (x != 0xffffffff) == 0;      /* the 00104 shape: x converts to uint */
	r += x == 0xffffffffu;            /* its suffixed twin */
	r += v == ~0;                     /* ~0 reads int, converts to all-ones uint */
	r += u != ~0;
	r += (u > -1) == 0;               /* -1 converts to uint: nothing is above it */
	r += (v != -1) == 0;
	r += l != 0xffffffffffffffff;     /* ulong side: l sign-extends, 0xff..fa */
	r += gul == 0xffffffffffffffff;
	r += l == -6 && x == -1;          /* the signed lanes, unregressed */
	r += u / 2u == 2;
	r += sizeof(0xffffffff) == 4;     /* the ladder's types */
	r += sizeof(0xffffffffffffffff) == 8;
	switch (v) {
	case -1: r += 1; break;           /* the case converts to the control's uint */
	default: break;
	}
	return r;
}
