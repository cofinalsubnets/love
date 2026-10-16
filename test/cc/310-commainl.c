/* a void always_inline call on either side of a comma splices as the statement it is: each
 * side runs in order, a value comma keeps its right. the exit folds the trace, 68 */
#define AI static inline __attribute__((always_inline))

static unsigned t;
AI void put(unsigned d) { t = t * 10 + d; }
AI void cp(unsigned char *o, unsigned char const *a, int n) { for (int j = 0; j < n; j++) o[j] = a[j]; }

int main(void) {
	unsigned char b[16] = { 1, 2, 3, 4 }, *o = b + 8;
	put(1), put(2);
	for (int k = 0; k < 3; k++) cp(o, b, 2), o += 2;
	int v = (put(3), t % 7);
	if (put(4), v > 2) put(5);
	return (int) ((t + b[8] + b[13] * 3 + v) % 256); }
