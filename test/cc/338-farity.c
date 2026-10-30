/* a call reads only the float argument registers its callee takes: live doubles in the
 * others ride across the laying, with one, three and eight doubles, mixed int/double
 * structs, a double pair, a float pair and a variadic call */
#include <stdarg.h>

struct dd { double a, b; };
struct ld { long n; double x; };
struct ff { float a, b; };

__attribute__((noinline)) double one(double x) { return x * 1.5; }
__attribute__((noinline)) double three(double a, double b, double c) { return a - b * c; }
__attribute__((noinline)) double eight(double a, double b, double c, double d, double e, double f, double g, double h) {
	return a + 2 * b + 3 * c + 4 * d + 5 * e + 6 * f + 7 * g + 8 * h; }
__attribute__((noinline)) double pair(struct dd p, double y) { return p.a * y - p.b; }
__attribute__((noinline)) double mixd(struct ld p, double y) { return p.n + p.x * y; }
__attribute__((noinline)) float fpair(struct ff p, float y) { return p.a * y + p.b; }
__attribute__((noinline)) long none(long k) { return k * 3 + 1; }
__attribute__((noinline)) double vsum(int n, ...) {
	va_list ap; va_start(ap, n);
	double s = 0;
	for (int i = 0; i < n; i++) s += va_arg(ap, double) * (i + 1);
	va_end(ap);
	return s; }

static double squash(double x) { return 4.0 * x / (1.0 + (x < 0 ? -x : x)); }

static long fold(long h, double v) {
	long k = (long) (v * 64.0);
	return (h * 33 + (k < 0 ? -k : k)) % 1000003; }

int main(void) {
	double a = 0.25, b = 1.75, c = -2.5, d = 3.0;
	long h = 7;
	for (int i = 0; i < 40; i++) {
		double t = a + b, u = c * d, v = a - d;
		a = one(t) - u;
		b = three(u, v, t) + a * 0.125;
		c = eight(a, b, c, d, t, u, v, 1.0) / 64.0 + v;
		d = pair((struct dd) { t, u }, v) + mixd((struct ld) { i, a }, b) / 16.0;
		d += fpair((struct ff) { (float) t, 0.5f }, (float) v) / 8.0;
		d += none(i) * 0.001 + t - u + v;
		d += vsum(3, t, u, v) / 32.0;
		a = squash(a); b = squash(b); c = squash(c); d = squash(d);
		h = fold(fold(fold(fold(h, a), b), c), d);
	}
	return (int) (h % 251);
}
