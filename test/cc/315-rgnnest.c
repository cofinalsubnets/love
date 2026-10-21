/* a pointer stepped by an outer loop and read inside the inner loops its inlined helpers lay
 * keeps one seat across both: each pass reads its own stride, never the last one's. the
 * exit folds the four lanes, 17 */
#include <stdint.h>
#include <string.h>

struct st { uint64_t v[4]; uint8_t mem[32]; unsigned memn; };
static uint64_t ld8(uint8_t const *p) { uint64_t w = 0; for (int i = 7; i >= 0; i--) w = w << 8 | p[i]; return w; }
static uint64_t rd(const uint8_t *p, unsigned k) { if (k == 8) return ld8(p); uint64_t w = 0; while (k--) w = w << 8 | p[k]; return w; }
static uint64_t mix(uint64_t a, uint64_t in) { a += in * 0xc2b2ae3d27d4eb4full; return (a << 31 | a >> 33) * 0x9e3779b185ebca87ull; }

static void feed(struct st *S, const uint8_t *p, uintptr_t n) {
	if (S->memn + n < 32) { memcpy(S->mem + S->memn, p, n), S->memn += (unsigned) n; return; }
	uint64_t a = S->v[0], b = S->v[1], c = S->v[2], d = S->v[3];
	if (S->memn) {
		unsigned k = 32 - S->memn;
		memcpy(S->mem + S->memn, p, k), p += k, n -= k;
		a = mix(a, rd(S->mem, 8)), b = mix(b, rd(S->mem + 8, 8));
		c = mix(c, rd(S->mem + 16, 8)), d = mix(d, rd(S->mem + 24, 8)); }
	for (; n >= 32; p += 32, n -= 32)
		a = mix(a, rd(p, 8)), b = mix(b, rd(p + 8, 8)),
		c = mix(c, rd(p + 16, 8)), d = mix(d, rd(p + 24, 8));
	S->v[0] = a, S->v[1] = b, S->v[2] = c, S->v[3] = d;
	memcpy(S->mem, p, n), S->memn = (unsigned) n; }

int main(void) {
	static uint8_t s[200];
	for (int i = 0; i < 200; i++) s[i] = (uint8_t) (i * 7 + (i >> 5));
	struct st S = {{1, 2, 3, 4}, {0}, 0};
	feed(&S, s, 64), feed(&S, s + 64, 13), feed(&S, s + 77, 100);
	uint64_t h = S.v[0] ^ S.v[1] * 3 ^ S.v[2] * 5 ^ S.v[3] * 7 ^ S.memn;
	return (int) (h % 251); }
