/* loop values live across a call taken now and then ride registers between calls and the
 * frame across them: the call scrubs every caller-saved register, reads some values as its
 * arguments, and answers one. the exit folds every value the loop carried, 62 */
#include <string.h>

__attribute__((noinline)) static unsigned long scrub(unsigned long a, unsigned long b) {
	volatile unsigned long z[24];
	unsigned long s = 0;
	for (int i = 0; i < 24; i++) z[i] = a * 31 + b + (unsigned long) i;
	for (int i = 0; i < 24; i++) s = s * 7 + z[i];
	return s;
}

int main(void) {
	unsigned char buf[64];
	unsigned long h = 1, x = 3, y = 5, z = 7, w = 11, q = 13, r = 17;
	unsigned char *p = buf;
	for (unsigned long k = 0; k < 400; k++) {
		h = h * 33 + x, x += y, y ^= z, z = z * 5 + w, w += q, q ^= r, r += k;
		if ((k & 63) == 9) h += scrub(x, k), memcpy(p, &h, 8), p += 8;
		if (p > buf + 48) p = buf;
		x ^= h >> 3, y += x, z -= y;
	}
	unsigned long s = h ^ x ^ y ^ z ^ w ^ q ^ r ^ (unsigned long) (p - buf);
	for (int i = 0; i < 64; i += 8) { unsigned long v; memcpy(&v, buf + i, 8); s += i < 48 ? v : 0; }
	return (int) (s % 251); }
