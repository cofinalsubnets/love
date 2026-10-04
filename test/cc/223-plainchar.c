/* plain char's sign is the target's: unsigned under AAPCS64, AAPCS32 and the RISC-V psABI (wasm
 * rides riscv's), signed on x86-64. every view of it must agree -- the codegen, __CHAR_UNSIGNED__,
 * limits.h, a string literal's bytes, a char parameter -- so this answers the same on every
 * target and every compiler. freestanding, exit-code only: each disagreement sets its bit. */
#include <limits.h>

#ifdef __CHAR_UNSIGNED__
#define UNS 1
#else
#define UNS 0
#endif

__attribute__((noinline)) static int widen(char c) { return c; }
__attribute__((noinline)) static int lt0(char c) { return c < 0; }

static char tab[2] = { (char) 200, 'a' };

int main(void)
{
	volatile char c = (char) 200;
	int bad = 0;
	if ((c < 0) != !UNS) bad |= 1;                              /* the codegen's sign */
	if ((CHAR_MIN == 0) != UNS || CHAR_MAX != (UNS ? 255 : 127)) bad |= 2;
	if (("\xc8"[0] < 0) != !UNS) bad |= 4;                       /* a string literal's bytes */
	if (widen(c) != (UNS ? 200 : -56) || lt0(tab[0]) != !UNS) bad |= 8;
	if ((char) -1 != (UNS ? 255 : -1)) bad |= 16;
#if defined(__aarch64__) || defined(__arm__) || defined(__riscv) || defined(__wasm__)
	if (!UNS) bad |= 32;                                         /* these psABIs say unsigned */
#endif
	return bad;
}
