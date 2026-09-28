/* push of an immediate and of a label's address: the kernel's iret_to_self pushes `$1f`,
 * the address it returns to. the pushed address matches a rip-relative lea of the same
 * label, and a pushed constant pops back whole, sign-extended. the asm is x64's; the label's
 * push wants a non-pie link (a sign-extended dword), which ours always is. held to gcc. */

#if defined(__x86_64__) && !defined(__PIE__)
static int same(void) {
  unsigned long a, b;
  asm volatile("pushq $1f\n\tpopq %0\n1:\n\tleaq 1b(%%rip), %1" : "=r"(a), "=r"(b));
  return a == b;
}
#else
static int same(void) { return 1; }
#endif

#if defined(__x86_64__)
static long pushed(void) {
  long a, b, c;
  asm volatile("pushq $5\n\tpushq $-2\n\tpushq $70000\n\tpopq %2\n\tpopq %1\n\tpopq %0"
               : "=r"(a), "=r"(b), "=r"(c));
  return a * 1000000 + b * 100000 + c;
}
#else
static long pushed(void) { return 5 * 1000000 - 2 * 100000 + 70000; }
#endif

int main(void) {
  int bad = 0;
  if (!same()) bad |= 1;
  if (pushed() != 5 * 1000000 - 2 * 100000 + 70000) bad |= 2;
  return bad;
}
