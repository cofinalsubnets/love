/* a %gs: operand, held to gcc: the kernel's percpu reads and writes, `mov %gs:%[var], %[val]`
 * through an "m" operand, and get_current's `%gs:%a[var]` through an "i" address. a linux
 * process runs with a zero gs base, so the override reaches the plain address. a target
 * with no template here computes the same. */

long cell = 5, spare[2] = {7, 9};
unsigned char tiny = 200;

int main(void) {
  int bad = 0;
#if defined(__x86_64__) && defined(__linux__)
  long r, x = 11;
  unsigned char b;
  asm("movq %%gs:%1, %0" : "=r"(r) : "m"(cell));
  if (r != 5) bad |= 1;
  asm("movb %%gs:%1, %0" : "=q"(b) : "m"(tiny));
  if (b != 200) bad |= 2;
  asm volatile("movq %1, %%gs:%0" : : "m"(spare[1]), "r"(x) : "memory");
  if (spare[1] != 11) bad |= 4;
  asm("movq %%gs:%a1, %0" : "=r"(r) : "i"(&spare[0]));
  if (r != 7) bad |= 8;
#else
  if (cell != 5 || spare[0] != 7 || tiny != 200) bad |= 1;
#endif
  return bad;
}
