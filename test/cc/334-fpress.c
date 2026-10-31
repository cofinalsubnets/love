/* more live doubles than xmm registers, so some live in the frame: ops that take a frame or
 * constant source (the order of - and /), compares against memory, singles, and the protocol
 * pair's values across calls and branches */
static double g9 = 3.25;

static double bump(double x) { return x * 0.5 + g9; }

static int mix(int h, double v) {
	long k = (long) (v * 1000.0);
	k = k < 0 ? -k : k;
	return (int) ((h * 31 + k) % 65521); }

static double press(double const *v, int n) {
	double a0 = v[0], a1 = v[1], a2 = v[2], a3 = v[3], a4 = v[4], a5 = v[5], a6 = v[6], a7 = v[7];
	double b0 = v[8], b1 = v[9], b2 = v[10], b3 = v[11], b4 = v[12], b5 = v[13], b6 = v[14], b7 = v[15];
	double c0 = v[16], c1 = v[17], c2 = v[18], c3 = v[19];
	for (int i = 0; i < n; i++) {
		a0 = a0 - b7 / 3.0;  a1 = 2.0 - a1 * b6;  a2 = b5 / (a2 + 1.5);  a3 = a3 - c0;
		a4 = (a4 < b4 ? b3 - a4 : a4 - b3);  a5 = c1 - a5;  a6 = a6 / (c2 + 4.0);  a7 = 7.0 / (a7 + 2.0);
		b0 += a0 - a7;  b1 -= a1 * 0.25;  b2 = b2 > c3 ? b2 - c3 : c3 - b2;  b3 = 1.0 - b3 / 8.0;
		b4 = b4 * 0.75 - a3;  b5 = (b5 + a5) / 2.0;  b6 = b6 - a6;  b7 = b7 < 0.5 ? b7 + 0.125 : b7 - 0.375;
		c0 = c0 * 0.5 + a2 - b1;  c1 = c1 - b0 / 16.0;  c2 = c2 > 1.0 ? 0.5 : c2 + a4 / 64.0;  c3 = c3 - 0.0625;
	}
	return a0 + a1 - a2 + a3 - a4 + a5 - a6 + a7 + b0 - b1 + b2 - b3 + b4 - b5 + b6 - b7 + c0 - c1 + c2 - c3; }

static float single(float const *v, int n) {
	float s = 0, t = 1, u = v[0], w = v[1];
	for (int i = 0; i < n; i++) {
		s = s - v[i & 7] / 4.0f;  t = t > u ? t - w : w - t;  u = 0.5f - u * 0.75f;  w = w / (s * s + 2.0f); }
	return s - t + u * w; }

static double calls(double x, int n) {
	double acc = 0, y = x;
	for (int i = 0; i < n; i++) {
		double p = y * 1.5 - 0.25;
		y = bump(p) - y;                          /* p's value crosses no call; y's does */
		acc = acc - (y < p ? y : p) / (i + 1); }
	return acc + y; }

int main(void) {
	double v[20];
	float f[8];
	for (int k = 0; k < 20; k++) v[k] = (k * 7 % 13) * 0.375 - 1.0;
	for (int k = 0; k < 8; k++) f[k] = (float) ((k * 5 % 7) * 0.5 - 1.25);
	int h = mix(0, press(v, 9));
	h = mix(h, single(f, 11));
	h = mix(h, calls(0.75, 6));
	h = mix(h, press(v + 0, 1));
	return h & 255; }
