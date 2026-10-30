/* small local arrays named only by constant elements become scalars once their loops unroll;
 * one decayed, indexed at a run-time k, past its end, or an element's address taken stays
 * whole. a straight helper inlines */
static int mix(int h, int v) {
	int k = h * 31 + v;
	k = k < 0 ? -k : k;
	return k % 65521; }

static double step(double const *v0, double const *vx, int n) {
	double a[13], d[13];
	for (int k = 0; k < 13; k++) a[k] = v0[k] + vx[k] * 0.5, d[k] = vx[k] - (double) k;
	double s = 0;
	for (int i = 0; i < n; i++) {
		s += a[0] * a[1] - a[12] + (a[3] > a[4] ? a[5] : a[6]);
		for (int k = 0; k < 13; k++) a[k] += d[k]; }
	return s; }

static int sum(int const *p, int n) { int s = 0; for (int i = 0; i < n; i++) s += p[i]; return s; }

static int whole(int n) {
	int e[4], f[4], g[3];
	for (int k = 0; k < 4; k++) e[k] = k * n, f[k] = k + n;
	for (int k = 0; k < 3; k++) g[k] = e[k] ^ f[k + 1];
	int r = sum(e, 4) + f[n & 3];          /* e decays, f takes a run-time index */
	return mix(r, g[0] + g[1] * 3 + g[2] * 5); }

static int narrow(int x) {
	unsigned char b[8];
	short w[5];
	for (int k = 0; k < 8; k++) b[k] = (unsigned char) (x >> k);
	for (int k = 0; k < 5; k++) w[k] = (short) (b[k] * b[k + 3] - 300);
	int h = 7;
	for (int k = 0; k < 5; k++) h = mix(h, w[k]);
	return h; }

static int apart(int n) {
	long a[8];
	for (int k = 0; k < 8; k++) a[k] = k * n;
	long *p = &a[6], *q = &a[2];             /* two elements' addresses: one array still */
	return (int) ((p - q) * 10 + (q < p) + *p - *q); }

int main(void) {
	double v0[13], vx[13];
	for (int k = 0; k < 13; k++) v0[k] = k * 0.25 - 1, vx[k] = 0.125 * (k & 3);
	int h = mix(0, (int) step(v0, vx, 9));
	h = mix(h, whole(5));
	h = mix(h, whole(-3));
	h = mix(h, narrow(0x5a3c9e17));
	h = mix(h, apart(3));
	return h & 255; }
