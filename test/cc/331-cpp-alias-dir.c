/* an object-like macro naming a function-like one opens its call, so a directive inside
 * the arguments is read in place (the kernel's cpu_to_le64( .. #ifdef __BIG_ENDIAN ..)) */
#define in(x) ((long)(x))
#define mid in
#define out mid

int main(void)
{
	return out(
		1 |
#ifdef NOPE
		8 |
#endif
		4
		) + 2;
}
