/* riscv's register width is predefined, as gcc and clang give it: __riscv_xlen agrees with a
 * long's and a pointer's bits. each disagreement sets a bit; another target passes */
int main(void)
{
	int bad = 0;
#ifdef __riscv
#ifndef __riscv_xlen
	bad |= 1;
#elif __riscv_xlen != 32 && __riscv_xlen != 64
	bad |= 2;
#else
	if (__riscv_xlen != 8 * (int) sizeof(long)) bad |= 4;
	if (__riscv_xlen != 8 * (int) sizeof(void *)) bad |= 8;
#endif
#endif
	return bad;
}
