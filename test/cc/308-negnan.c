/* unary minus flips the sign bit and nothing else: a nan's sign turns, and zero's. the exit
 * packs one bit per case, 255 when every case turns */
#include <string.h>

static unsigned long long ub(double x) { unsigned long long u; memcpy(&u, &x, 8); return u; }
static unsigned uf(float x) { unsigned u; memcpy(&u, &x, 4); return u; }

int main(void) {
	volatile double z = 0.0, one = 1.0;
	volatile float zf = 0.0f;
	double qn = z / z, pn, d0 = z;
	float fn = zf / zf, f0 = zf;
	unsigned long long u = 0x7ff8000000000123ull;
	memcpy(&pn, &u, 8);
	int r = 0;
	r |= (ub(-qn) ^ ub(qn)) == 0x8000000000000000ull;
	r |= ((ub(-pn) ^ ub(pn)) == 0x8000000000000000ull) << 1;
	r |= (ub(-(-pn)) == ub(pn)) << 2;
	r |= (ub(-d0) == 0x8000000000000000ull) << 3;
	r |= ((uf(-fn) ^ uf(fn)) == 0x80000000u) << 4;
	r |= (uf(-f0) == 0x80000000u) << 5;
	r |= (-one == -1.0) << 6;
	r |= (-(float) one == -1.0f) << 7;
	return r; }
