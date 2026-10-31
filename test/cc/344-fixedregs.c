/* the operations that want fixed registers (divides and remainders, variable shifts) among many
 * live values: every operand in every role, signed and unsigned, 32 and 64 bits, in loops,
 * across calls, and in a fn with a variable-length array. signed values stay bounded and left
 * shifts are unsigned, so every step is defined */
#include <stdint.h>
typedef uint64_t u64;
typedef int64_t i64;
static i64 id(i64 x) { return x; }

static i64 divs(i64 a, i64 b, i64 c, int n) {
	i64 s = 0, p = a, q = b | 1, r = c;
	for (int i = 0; i < n; i++) {
		i64 t = p / q, m = p % q;           /* both halves of one divide, both live on */
		s += t * 3 - m + r / (q | 3) - r % 7;
		p = (p * 5 + m - t) % 1000003;  q = ((q + t) & 0xfff) | 1;  r = (r - s % (i + 2)) % 99991;
		s ^= (i64) ((u64) p % (u64) (q | 5)); }
	return s + p - q + r; }

static int div32(int a, int b, int n) {
	int s = 0;
	unsigned u = (unsigned) a;
	for (int i = 1; i <= n; i++) {
		s += a / i - a % i + (int) (u / (unsigned) i % 1000) - (int) (u % (unsigned) (i + 1));
		a = (a * 3 - s) % 100003;  u = u * 7 + (unsigned) b; }
	return s; }

static u64 shifts(u64 a, i64 b, int n) {
	u64 s = 0;
	for (int k = 0; k < n; k++) {
		int c = k % 61, d = (k * 7) % 59;      /* the count is live past the shift */
		u64 x = a << c, z = a >> (c + 1);
		i64 y = b >> d;                       /* arithmetic, on a negative b too */
		s += x - (u64) y + z + (u64) (c * d);
		a ^= s >> (d & 31);  b = (b ^ (i64) (s & 0xffff)) - 40000; }
	return s; }

static i64 calls(i64 a, i64 b, int n) {
	i64 s = 0;
	for (int i = 1; i <= n; i++) {
		i64 q = a / i, m = id(a % i);      /* a divide's results across a call */
		s += q - m + id(b >> (i & 31)) + (i64) (((u64) b << (i & 15)) % 13);
		a = (a + q) % 1000000007;  b = b - m; }
	return s; }

static i64 vla(int n, i64 a) {
	i64 t[n];
	for (int i = 0; i < n; i++) t[i] = id(a / (i + 1)) - a % (i + 3);
	i64 s = 0;
	for (int i = 0; i < n; i++) s += t[i] / (t[(i + 1) % n] | 1) + (i64) (((u64) t[i] << (i & 7)) % 100000);
	return s; }

int main(void) {
	u64 u = (u64) divs(1000003, 97, -77777, 50) + (u64) div32(-123456, 789, 40) + shifts(0x1234567, -987654, 120) +
	        (u64) calls(99999999, 123456789, 40) + (u64) vla(17, 31337);
	return (int) ((u ^ u >> 23 ^ u >> 47) % 251); }
